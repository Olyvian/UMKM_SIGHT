from datetime import date

from umkm_ml.stockout import (
    STATUS_OUT_OF_STOCK,
    STATUS_SUFFICIENT,
    STATUS_WILL_RUN_OUT,
    estimate_stockout,
)

START = date(2026, 11, 10)


def test_stok_nol_langsung_habis():
    result = estimate_stockout([5, 5, 5], current_stock=0, start_date=START)

    assert result.status == STATUS_OUT_OF_STOCK
    assert result.days_until_stockout == 0
    assert result.should_alert is True


def test_stok_habis_dalam_horizon():
    # kumulatif: 3, 6, 9, 12 -> stok 10 tercapai di hari ke-4
    result = estimate_stockout(
        [3, 3, 3, 3, 3], current_stock=10, start_date=START, lead_time_days=7
    )

    assert result.status == STATUS_WILL_RUN_OUT
    assert result.days_until_stockout == 4
    assert result.estimated_date == "2026-11-13"
    assert result.should_alert is True


def test_alert_tidak_menyala_bila_lead_time_pendek():
    result = estimate_stockout(
        [3, 3, 3, 3, 3], current_stock=10, start_date=START, lead_time_days=2
    )

    assert result.days_until_stockout == 4
    assert result.should_alert is False


def test_stok_cukup_selama_horizon_tidak_mengarang_tanggal():
    result = estimate_stockout([3, 3, 3], current_stock=100, start_date=START)

    assert result.status == STATUS_SUFFICIENT
    assert result.days_until_stockout is None
    assert result.estimated_date is None
    assert result.should_alert is False


def test_prediksi_negatif_diperlakukan_sebagai_nol():
    result = estimate_stockout([-5, 2, 2], current_stock=3, start_date=START)

    assert result.cumulative_demand == [0.0, 2.0, 4.0]
    assert result.days_until_stockout == 3
