import json

import pytest

from umkm_ml.pipeline import run_product
from umkm_ml.synthetic_data import generate_sales


@pytest.fixture(scope="module")
def raw_sales():
    return generate_sales(days=120, seed=7)


def test_pipeline_end_to_end_menghasilkan_artefak(raw_sales, tmp_path):
    result = run_product(
        raw_sales,
        product_id=1,
        horizon=7,
        current_stock=20,
        artifact_dir=tmp_path,
    )

    assert result.status == "ok"
    assert result.best_model is not None
    assert len(result.forecast) == 7
    # 5 model dievaluasi (naive, moving average, seasonal naive,
    # SARIMA, dan SARIMA dengan tren)
    assert len(result.model_scores) == 5

    # File artefak benar-benar dibuat
    metrics_file = tmp_path / "product_1_metrics.json"
    forecast_file = tmp_path / "product_1_forecast.json"
    assert metrics_file.exists()
    assert forecast_file.exists()

    payload = json.loads(forecast_file.read_text(encoding="utf-8"))
    assert payload["horizon_days"] == 7
    assert len(payload["predictions"]) == 7


def test_pipeline_menolak_data_tidak_cukup(raw_sales):
    short = raw_sales[raw_sales["transaction_date"] <= "2026-01-05"]

    result = run_product(short, product_id=1, artifact_dir=None)

    assert result.status == "insufficient_data"
    assert result.stockout is not None
    assert result.stockout.status == "no_forecast"
