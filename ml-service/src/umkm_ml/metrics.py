"""Metrik evaluasi peramalan.

Kenapa tidak cukup satu metrik?
-------------------------------
- MAE  : rata-rata besar kesalahan, satuan sama dengan data (buah/hari).
         Paling mudah dijelaskan ke pengguna nonteknis.
- RMSE : mirip MAE tetapi menghukum kesalahan besar lebih berat.
- MAPE : kesalahan dalam persen, mudah dibandingkan antar produk.

Jebakan MAPE (PRD 7.5): rumusnya membagi dengan nilai aktual. Jika aktual = 0
(hari tanpa penjualan) terjadi pembagian nol. Karena itu di sini MAPE hanya
dihitung pada hari yang aktualnya > 0, dan kita laporkan berapa persen hari
yang dilewati supaya hasilnya jujur.

Jebakan kedua MAPE: hari dengan penjualan sangat kecil (mis. 1 buah) membuat
persentase kesalahan meledak, walaupun selisihnya cuma 1 buah. Pada data
sembako yang ramai hari sepi, MAPE bisa tampak 100% padahal modelnya wajar.
Karena itu ditambahkan WAPE: total kesalahan dibagi total penjualan. Angka
ini tidak meledak pada nilai kecil dan lebih jujur untuk data ritel.
"""

from __future__ import annotations

import numpy as np


def _as_float_arrays(actual, predicted) -> tuple[np.ndarray, np.ndarray]:
    a = np.asarray(actual, dtype=float).ravel()
    p = np.asarray(predicted, dtype=float).ravel()
    if a.shape != p.shape:
        raise ValueError(
            f"Panjang aktual ({a.size}) dan prediksi ({p.size}) harus sama."
        )
    return a, p


def mae(actual, predicted) -> float:
    """Mean Absolute Error: rata-rata |aktual - prediksi|."""
    a, p = _as_float_arrays(actual, predicted)
    return float(np.mean(np.abs(a - p)))


def rmse(actual, predicted) -> float:
    """Root Mean Squared Error: akar rata-rata kuadrat kesalahan."""
    a, p = _as_float_arrays(actual, predicted)
    return float(np.sqrt(np.mean((a - p) ** 2)))


def mape(actual, predicted) -> float | None:
    """Mean Absolute Percentage Error (0.12 = 12%).

    Mengembalikan None jika tidak ada satu pun nilai aktual > 0, karena
    metrik persen tidak bermakna pada deret yang seluruhnya nol.
    """
    a, p = _as_float_arrays(actual, predicted)
    mask = a > 0
    if not np.any(mask):
        return None
    return float(np.mean(np.abs((a[mask] - p[mask]) / a[mask])))


def wape(actual, predicted) -> float | None:
    """Weighted Absolute Percentage Error (0.12 = 12%).

    = total |selisih| / total penjualan aktual.

    Lebih stabil daripada MAPE untuk data ritel: satu hari dengan penjualan
    1 buah tidak bisa membuat angkanya meledak, karena yang dihitung adalah
    porsi kesalahan terhadap TOTAL penjualan, bukan rata-rata persentase
    per hari.
    """
    a, p = _as_float_arrays(actual, predicted)
    total = np.sum(np.abs(a))
    if total == 0:
        return None
    return float(np.sum(np.abs(a - p)) / total)


def zero_ratio(actual) -> float:
    """Proporsi hari dengan penjualan 0. Dipakai sebagai konteks MAPE."""
    a = np.asarray(actual, dtype=float).ravel()
    if a.size == 0:
        return 0.0
    return float(np.mean(a == 0))


def evaluate_all(actual, predicted) -> dict[str, float | None]:
    """Hitung semua metrik sekaligus dalam satu dict."""
    return {
        "mae": mae(actual, predicted),
        "rmse": rmse(actual, predicted),
        "mape": mape(actual, predicted),
        "wape": wape(actual, predicted),
        "zero_ratio": zero_ratio(actual),
    }
