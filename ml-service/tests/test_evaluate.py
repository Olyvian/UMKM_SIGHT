"""Test untuk pembagian data berbasis waktu dan laporan multi-horizon."""

import numpy as np
import pandas as pd
import pytest

from umkm_ml.config import EVAL_HORIZON_DAYS, MIN_HISTORY_DAYS
from umkm_ml.evaluate import evaluate_models, horizon_report, time_split
from umkm_ml.preprocessing import InsufficientDataError


def _series(days: int, seed: int = 0) -> pd.Series:
    rng = np.random.default_rng(seed)
    index = pd.date_range("2024-01-01", periods=days, freq="D")
    values = 10 + 3 * np.sin(np.arange(days) * 2 * np.pi / 7) + rng.normal(0, 1, days)
    return pd.Series(np.maximum(values, 0.0), index=index)


def test_default_data_uji_memakai_horizon_evaluasi():
    """Data 5 tahun TIDAK boleh diuji untuk ratusan hari."""
    series = _series(1826)

    train, test = time_split(series)

    assert len(test) == EVAL_HORIZON_DAYS
    assert len(train) == 1826 - EVAL_HORIZON_DAYS


def test_horizon_uji_bisa_diatur():
    series = _series(500)

    _, test = time_split(series, test_days=7)

    assert len(test) == 7


def test_data_uji_tidak_melebihi_sisa_data_latih():
    """Harus tetap menyisakan MIN_HISTORY_DAYS untuk melatih."""
    series = _series(MIN_HISTORY_DAYS + 10)

    train, test = time_split(series, test_days=365)

    assert len(train) == MIN_HISTORY_DAYS
    assert len(test) == 10


def test_data_terlalu_pendek_ditolak():
    series = _series(MIN_HISTORY_DAYS + 3)

    with pytest.raises(InsufficientDataError):
        time_split(series, test_days=7)


def test_laporan_horizon_berisi_tujuh_hari():
    series = _series(200)

    evaluation = evaluate_models(series)
    report = horizon_report(evaluation)

    assert "7_hari" in report
    assert "28_hari" in report
    for metrics in report.values():
        assert metrics["mae"] >= 0
        assert metrics["wape"] is None or metrics["wape"] >= 0
