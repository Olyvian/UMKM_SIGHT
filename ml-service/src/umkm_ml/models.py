"""Kumpulan model peramalan.

Semua model memakai antarmuka (interface) yang sama:
    model.fit(series)                     -> melatih
    model.forecast(horizon)               -> np.ndarray panjang `horizon`
    model.forecast_with_ci(horizon, alpha) -> (mean, lower, upper)  masing-masing ndarray

Dengan begitu pipeline bisa mengganti model tanpa mengubah kode lain.

Isi:
1. NaiveForecaster         : prediksi = nilai terakhir.
2. MovingAverageForecaster : prediksi = rata-rata N hari terakhir (BASELINE).
3. SeasonalNaiveForecaster : prediksi = nilai hari yang sama minggu lalu.
4. SarimaForecaster        : model statistik dengan trend + musim mingguan.

Penting: baseline (moving average) WAJIB ada. Tujuannya pembanding.
Kalau SARIMA tidak lebih baik dari rata-rata 7 hari, model rumit itu tidak
layak dipakai (PRD 7.2 poin 5).

Confidence Interval (CI):
    SarimaForecaster dan SarimaTrendForecaster menghasilkan CI asli dari
    statsmodels (95% default). Model baseline (Naive, MovingAverage,
    SeasonalNaive) menghasilkan CI empiris sederhana berdasarkan standar
    deviasi residual 28 hari terakhir × z-score.
"""

from __future__ import annotations

import warnings
from typing import NamedTuple

import numpy as np
import pandas as pd

from .config import MOVING_AVERAGE_WINDOW, SEASONAL_PERIOD

# Jendela untuk estimasi standar deviasi residual pada model baseline.
_RESIDUAL_WINDOW = 28
# Z-score untuk confidence interval 95%.
_Z_95 = 1.96


class ModelError(RuntimeError):
    """Model gagal dilatih atau gagal memprediksi."""


class ForecastResult(NamedTuple):
    """Hasil forecast lengkap dengan confidence interval.

    mean        : prediksi nilai tengah  (shape: horizon,)
    lower_bound : batas bawah CI 95%     (shape: horizon,)
    upper_bound : batas atas CI 95%      (shape: horizon,)
    """

    mean: np.ndarray
    lower_bound: np.ndarray
    upper_bound: np.ndarray


class BaseForecaster:
    """Kelas dasar: menyimpan data latih dan menyediakan helper."""

    name: str = "base"
    description: str = ""

    def __init__(self) -> None:
        self._y: np.ndarray | None = None

    # -- API wajib ----------------------------------------------------------
    def fit(self, series: pd.Series) -> "BaseForecaster":
        y = np.asarray(series, dtype=float).ravel()
        if y.size == 0:
            raise ModelError("Data latih kosong.")
        self._y = y
        return self

    def forecast(self, horizon: int) -> np.ndarray:
        raise NotImplementedError

    def forecast_with_ci(
        self, horizon: int, alpha: float = 0.05
    ) -> ForecastResult:
        """Kembalikan (mean, lower_bound, upper_bound) untuk `horizon` hari.

        Implementasi default menggunakan estimasi empiris sederhana:
        standar deviasi residual dari `_RESIDUAL_WINDOW` hari terakhir
        dikalikan z-score yang sesuai dengan `alpha`.

        Subclass (mis. SarimaForecaster) dapat meng-override metode ini
        dengan interval kepercayaan yang lebih akurat dari modelnya.
        """
        mean = self.forecast(horizon)
        z = float(np.abs(np.percentile(
            np.random.standard_normal(100_000), (alpha / 2) * 100
        )))
        # Fallback ke _Z_95 jika perhitungan gagal atau alpha tidak standar.
        if not (0 < z < 10):
            z = _Z_95

        y = self._require_fitted()
        window = y[-_RESIDUAL_WINDOW:] if y.size >= _RESIDUAL_WINDOW else y
        std = float(np.std(window, ddof=1)) if window.size > 1 else 0.0

        margin = z * std * np.ones(horizon)
        lower = self._clip(mean - margin)
        upper = mean + margin
        return ForecastResult(mean=mean, lower_bound=lower, upper_bound=upper)

    # -- Helper -------------------------------------------------------------
    def _require_fitted(self) -> np.ndarray:
        if self._y is None:
            raise ModelError(f"Model {self.name} belum dilatih.")
        return self._y

    @staticmethod
    def _clip(values: np.ndarray) -> np.ndarray:
        """Permintaan tidak mungkin negatif."""
        return np.maximum(np.asarray(values, dtype=float), 0.0)


class NaiveForecaster(BaseForecaster):
    """Prediksi semua hari ke depan = penjualan hari terakhir."""

    name = "naive"
    description = "Nilai terakhir diulang untuk seluruh horizon."

    def forecast(self, horizon: int) -> np.ndarray:
        y = self._require_fitted()
        return self._clip(np.repeat(y[-1], horizon))


class MovingAverageForecaster(BaseForecaster):
    """BASELINE: rata-rata `window` hari terakhir, diulang untuk horizon."""

    name = "moving_average"
    description = "Rata-rata 7 hari terakhir (baseline pembanding)."

    def __init__(self, window: int = MOVING_AVERAGE_WINDOW) -> None:
        super().__init__()
        self.window = window

    def forecast(self, horizon: int) -> np.ndarray:
        y = self._require_fitted()
        recent = y[-self.window :]
        return self._clip(np.repeat(recent.mean(), horizon))


class SeasonalNaiveForecaster(BaseForecaster):
    """Prediksi hari ke-h = nilai pada hari yang sama 7 hari sebelumnya."""

    name = "seasonal_naive"
    description = "Pola mingguan: nilai hari yang sama minggu lalu."

    def __init__(self, period: int = SEASONAL_PERIOD) -> None:
        super().__init__()
        self.period = period

    def forecast(self, horizon: int) -> np.ndarray:
        y = self._require_fitted()
        if y.size < self.period:
            raise ModelError(
                f"Butuh minimal {self.period} hari data untuk seasonal naive."
            )
        last_season = y[-self.period :]
        repeats = int(np.ceil(horizon / self.period))
        return self._clip(np.tile(last_season, repeats)[:horizon])


class SarimaForecaster(BaseForecaster):
    """SARIMA: model statistik untuk trend + musim mingguan.

    order=(p,d,q) mengatur komponen trend; seasonal_order=(P,D,Q,m) mengatur
    musim dengan m = 7 hari. Nilai dipilih sederhana agar cepat dilatih dan
    mudah dijelaskan; bisa dioptimasi nanti lewat grid search.
    """

    name = "sarima"
    description = "SARIMA(1,0,1)(0,0,1,7): trend + musim mingguan."

    def __init__(
        self,
        order: tuple[int, int, int] = (1, 0, 1),
        seasonal_order: tuple[int, int, int, int] = (0, 0, 1, SEASONAL_PERIOD),
    ) -> None:
        super().__init__()
        self.order = order
        self.seasonal_order = seasonal_order
        self._result = None
        self._last_index: pd.DatetimeIndex | None = None

    def fit(self, series: pd.Series) -> "SarimaForecaster":
        # Import di dalam fungsi agar modul lain tetap bisa dipakai walau
        # statsmodels belum terpasang.
        from statsmodels.tsa.statespace.sarimax import SARIMAX

        y = series.astype(float)
        self._last_index = pd.DatetimeIndex(series.index)

        if len(y) < 2 * SEASONAL_PERIOD:
            raise ModelError(
                f"Butuh minimal {2 * SEASONAL_PERIOD} hari data untuk SARIMA."
            )

        try:
            with warnings.catch_warnings():
                warnings.simplefilter("ignore")
                model = SARIMAX(
                    y,
                    order=self.order,
                    seasonal_order=self.seasonal_order,
                    enforce_stationarity=False,
                    enforce_invertibility=False,
                )
                self._result = model.fit(disp=False, maxiter=100)
        except Exception as exc:  # noqa: BLE001 - pesan asli diteruskan
            raise ModelError(f"SARIMA gagal dilatih: {exc}") from exc

        self._y = np.asarray(y, dtype=float)
        return self

    def forecast(self, horizon: int) -> np.ndarray:
        if self._result is None:
            raise ModelError("SARIMA belum dilatih.")
        try:
            with warnings.catch_warnings():
                warnings.simplefilter("ignore")
                values = np.asarray(self._result.forecast(steps=horizon), dtype=float)
        except Exception as exc:  # noqa: BLE001
            raise ModelError(f"SARIMA gagal memprediksi: {exc}") from exc
        return self._clip(values)

    def forecast_with_ci(
        self, horizon: int, alpha: float = 0.05
    ) -> ForecastResult:
        """Gunakan interval kepercayaan asli dari statsmodels (lebih akurat)."""
        if self._result is None:
            raise ModelError("SARIMA belum dilatih.")
        try:
            with warnings.catch_warnings():
                warnings.simplefilter("ignore")
                fc = self._result.get_forecast(steps=horizon)
                mean = self._clip(np.asarray(fc.predicted_mean, dtype=float))
                ci = fc.conf_int(alpha=alpha)
                lower = self._clip(np.asarray(ci.iloc[:, 0], dtype=float))
                upper = np.asarray(ci.iloc[:, 1], dtype=float)
        except Exception as exc:  # noqa: BLE001
            raise ModelError(f"SARIMA gagal menghasilkan CI: {exc}") from exc
        return ForecastResult(mean=mean, lower_bound=lower, upper_bound=upper)


class SarimaTrendForecaster(SarimaForecaster):
    """SARIMA dengan diferensiasi: menangani tren naik/turun.

    SARIMA biasa (d=0, D=0) menganggap data "datar" di sekitar rata-rata.
    Kalau penjualan menurun terus tiap tahun, model itu akan terus
    meramalkan angka tinggi. Diferensiasi (d=1) membuat model bekerja pada
    PERUBAHAN, bukan level, sehingga tren turun ikut terbawa ke ramalan.

    Dipakai sebagai kandidat tambahan: pipeline tetap memilih model dengan
    MAE terkecil, jadi model ini hanya menang kalau memang lebih baik.
    """

    name = "sarima_trend"
    description = "SARIMA(1,1,1)(0,1,1,7): tren + musim, untuk data naik/turun."

    def __init__(self) -> None:
        super().__init__(order=(1, 1, 1), seasonal_order=(0, 1, 1, SEASONAL_PERIOD))
    # forecast_with_ci diwarisi dari SarimaForecaster (pakai statsmodels CI).


def default_models() -> list[BaseForecaster]:
    """Daftar model yang selalu dievaluasi bersamaan."""
    return [
        NaiveForecaster(),
        MovingAverageForecaster(),
        SeasonalNaiveForecaster(),
        SarimaForecaster(),
        SarimaTrendForecaster(),
    ]


_MODEL_BY_NAME = {
    NaiveForecaster.name: NaiveForecaster,
    MovingAverageForecaster.name: MovingAverageForecaster,
    SeasonalNaiveForecaster.name: SeasonalNaiveForecaster,
    SarimaForecaster.name: SarimaForecaster,
    SarimaTrendForecaster.name: SarimaTrendForecaster,
}


def create_model(name: str) -> BaseForecaster:
    """Buat model baru berdasarkan namanya.

    Dipakai pipeline untuk melatih ulang model terbaik pada SELURUH data
    sebelum membuat ramalan akhir.
    """
    try:
        return _MODEL_BY_NAME[name]()
    except KeyError as exc:
        raise ModelError(f"Model tidak dikenal: {name}") from exc
