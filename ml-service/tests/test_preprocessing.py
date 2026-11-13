import pandas as pd
import pytest

from umkm_ml.preprocessing import InsufficientDataError, build_daily_series


def _raw(rows):
    return pd.DataFrame(
        rows,
        columns=["product_id", "transaction_date", "quantity"],
    )


def test_hari_tanpa_transaksi_diisi_nol():
    raw = _raw(
        [
            (1, "2026-01-01", 5),
            (1, "2026-01-03", 3),
        ]
    )
    series, report = build_daily_series(raw, product_id=1, min_days=1)

    assert len(series) == 3
    assert series.tolist() == [5.0, 0.0, 3.0]
    assert report.filled_zero_days == 1
    assert report.observed_days == 2


def test_retur_dan_kuantitas_negatif_dibuang():
    raw = _raw(
        [
            (1, "2026-01-01", 5),
            (1, "2026-01-02", -2),
            (1, "2026-01-03", 4),
        ]
    )
    series, report = build_daily_series(raw, product_id=1, min_days=1)

    assert report.dropped_returns == 1
    assert series.tolist() == [5.0, 0.0, 4.0]


def test_banyak_baris_pada_tanggal_sama_dijumlahkan():
    raw = _raw(
        [
            (1, "2026-01-01", 2),
            (1, "2026-01-01", 3),
            (1, "2026-01-02", 1),
        ]
    )
    series, _ = build_daily_series(raw, product_id=1, min_days=1)

    assert series.tolist() == [5.0, 1.0]


def test_data_terlalu_pendek_ditolak():
    raw = _raw(
        [
            (1, "2026-01-01", 5),
            (1, "2026-01-02", 4),
        ]
    )
    with pytest.raises(InsufficientDataError):
        build_daily_series(raw, product_id=1, min_days=28)


def test_produk_lain_tidak_tercampur():
    raw = _raw(
        [
            (1, "2026-01-01", 5),
            (2, "2026-01-01", 99),
            (1, "2026-01-02", 4),
            (2, "2026-01-02", 98),
        ]
    )
    series, _ = build_daily_series(raw, product_id=1, min_days=1)

    assert series.tolist() == [5.0, 4.0]
