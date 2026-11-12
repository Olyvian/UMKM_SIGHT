"""Evaluasi model dengan pembagian data berbasis waktu (time-based split).

Aturan emas: data uji HARUS berasal dari masa depan data latih.
Jangan mengacak data (train_test_split acak), karena model akan "melihat
masa depan" dan hasil evaluasinya jadi terlalu bagus / tidak jujur.
(PRD 7.2 poin 4)

Ilustrasi:

    Jan ------------------------------------ Sep | Okt -- Des
    |-------------- data latih ----------------||--- data uji --|
                                                ^
                                     model tidak pernah melihat bagian ini

Panjang data uji = EVAL_HORIZON_DAYS (28 hari), BUKAN 20% dari seluruh data.
Alasannya: aplikasi hanya meramal 7 hari ke depan. Menguji model untuk 365
hari ke depan lalu menyimpulkan "model buruk" adalah perbandingan yang tidak
adil dan tidak relevan.
"""

from __future__ import annotations

from dataclasses import dataclass, field

import numpy as np
import pandas as pd

from .config import EVAL_HORIZON_DAYS, MIN_HISTORY_DAYS, MIN_TEST_DAYS
from .metrics import evaluate_all
from .models import BaseForecaster, ModelError, default_models
from .preprocessing import InsufficientDataError


@dataclass
class ModelScore:
    """Hasil evaluasi satu model pada data uji."""

    name: str
    description: str
    available: bool
    mae: float | None = None
    rmse: float | None = None
    mape: float | None = None
    wape: float | None = None
    zero_ratio: float | None = None
    note: str | None = None
    predictions: np.ndarray | None = field(default=None, repr=False)


@dataclass
class EvaluationResult:
    """Hasil evaluasi seluruh model."""

    train: pd.Series
    test: pd.Series
    scores: list[ModelScore]
    best_name: str | None

    @property
    def ranked(self) -> list[ModelScore]:
        """Model yang tersedia, diurutkan dari MAE terkecil."""
        return sorted(
            (s for s in self.scores if s.available),
            key=lambda s: s.mae if s.mae is not None else float("inf"),
        )


def time_split(
    series: pd.Series,
    test_days: int | None = None,
    min_test_days: int = MIN_TEST_DAYS,
    min_train_days: int = MIN_HISTORY_DAYS,
) -> tuple[pd.Series, pd.Series]:
    """Potong deret menjadi (latih, uji) berdasarkan urutan waktu.

    Parameters
    ----------
    test_days : panjang data uji dalam hari. Bila None, dipakai
        `EVAL_HORIZON_DAYS`. Nilai ini sengaja tidak memakai persentase:
        persentase membuat data panjang (5 tahun) diuji untuk ratusan hari,
        yang tidak sesuai kebutuhan aplikasi (7 hari).
    """
    n = len(series)
    requested = EVAL_HORIZON_DAYS if test_days is None else int(test_days)
    requested = max(requested, min_test_days)

    max_test = n - min_train_days
    if max_test < min_test_days:
        raise InsufficientDataError(
            f"Data hanya {n} hari, tidak cukup untuk memisahkan data uji "
            f"(butuh minimal {min_train_days + min_test_days} hari)."
        )

    n_test = min(requested, max_test)
    return series.iloc[:-n_test], series.iloc[-n_test:]


def evaluate_models(
    series: pd.Series,
    models: list[BaseForecaster] | None = None,
    test_days: int | None = None,
) -> EvaluationResult:
    """Latih setiap model pada data latih, uji pada data uji, bandingkan.

    Setiap model membuat prediksi LANGSUNG untuk seluruh periode uji
    (direct multi-step forecast) - inilah kondisi nyata saat aplikasi
    meminta ramalan 7 hari ke depan.
    """
    train, test = time_split(series, test_days=test_days)
    candidates = models if models is not None else default_models()

    scores: list[ModelScore] = []
    for model in candidates:
        try:
            model.fit(train)
            predicted = model.forecast(len(test))
        except (ModelError, ValueError) as exc:
            scores.append(
                ModelScore(
                    name=model.name,
                    description=model.description,
                    available=False,
                    note=str(exc),
                )
            )
            continue

        metrics = evaluate_all(test.to_numpy(), predicted)
        scores.append(
            ModelScore(
                name=model.name,
                description=model.description,
                available=True,
                mae=metrics["mae"],
                rmse=metrics["rmse"],
                mape=metrics["mape"],
                wape=metrics["wape"],
                zero_ratio=metrics["zero_ratio"],
                predictions=predicted,
            )
        )

    result = EvaluationResult(train=train, test=test, scores=scores, best_name=None)
    ranked = result.ranked
    if not ranked:
        raise ModelError("Tidak ada model yang berhasil dilatih pada data ini.")

    result.best_name = ranked[0].name
    return result


def horizon_report(
    evaluation: EvaluationResult,
    horizons: tuple[int, ...] = (7, 14, 28),
) -> dict[str, dict]:
    """Akurasi model terbaik pada beberapa horizon sekaligus.

    Aplikasi memakai ramalan 7 hari, jadi angka 7 hari adalah yang paling
    penting. 14 dan 28 hari ditampilkan sebagai pembanding: makin jauh
    horizon, makin besar error - itu wajar dan perlu ditunjukkan, bukan
    disembunyikan.

    Model sudah memprediksi seluruh periode uji sekaligus, jadi perhitungan
    ini hanya memotong prediksi yang sama; tidak ada pelatihan ulang.
    """
    best = next(
        (s for s in evaluation.scores if s.name == evaluation.best_name), None
    )
    if best is None or best.predictions is None:
        return {}

    actual = evaluation.test.to_numpy()
    predicted = best.predictions
    out: dict[str, dict] = {}
    for horizon in horizons:
        if len(actual) < horizon:
            continue
        metrics = evaluate_all(actual[:horizon], predicted[:horizon])
        out[f"{horizon}_hari"] = {
            "mae": round(metrics["mae"], 4),
            "rmse": round(metrics["rmse"], 4),
            "mape": None
            if metrics["mape"] is None
            else round(metrics["mape"], 4),
            "wape": None
            if metrics["wape"] is None
            else round(metrics["wape"], 4),
        }
    return out
