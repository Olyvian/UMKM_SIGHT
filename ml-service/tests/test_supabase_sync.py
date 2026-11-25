"""Unit test untuk modul sinkronisasi Supabase (supabase_sync & sync_to_supabase)."""

from __future__ import annotations

import json
from pathlib import Path
from types import SimpleNamespace

import pytest

from umkm_ml.supabase_sync import (
    SupabaseSync,
    _compute_bounds,
    _extract_best_metrics,
    _extract_predictions,
)


class _FakeQuery:
    def __init__(self, table: str, log: list, response_data: list | None = None):
        self.table = table
        self.log = log
        self.response_data = response_data if response_data is not None else []
        self.op = None
        self.payload = None
        self.filters: dict = {}

    def select(self, cols: str):
        self.op = ("select", cols)
        return self

    def eq(self, col: str, val):
        self.filters[col] = val
        return self

    def limit(self, n: int):
        return self

    def update(self, payload: dict):
        self.op = ("update", payload)
        self.payload = payload
        return self

    def upsert(self, payload: dict, on_conflict: str | None = None):
        self.op = ("upsert", payload, on_conflict)
        self.payload = payload
        return self

    def insert(self, payload):
        self.op = ("insert", payload)
        self.payload = payload
        return self

    def execute(self):
        self.log.append((self.table, self.op, self.filters))
        return SimpleNamespace(data=self.response_data)


class _FakeClient:
    def __init__(self):
        self.log: list = []

    def table(self, name: str):
        if name == "ml_models":
            return _FakeQuery(name, self.log, [{"id": "model-uuid-1"}])
        if name == "products":
            return _FakeQuery(
                name, self.log, [{"id": "prod-uuid-1", "store_id": "store-uuid-1"}]
            )
        if name == "forecasts":
            return _FakeQuery(name, self.log, [{"id": "fc-uuid-1"}])
        return _FakeQuery(name, self.log, [])

    def rpc(self, fn_name: str, params: dict):
        self.log.append(("rpc", fn_name, params))
        return SimpleNamespace(execute=lambda: SimpleNamespace(data=3))


def _sample_summary() -> dict:
    return {
        "generated_at": "2026-11-15T07:45:20+00:00",
        "data_file": "data/raw/retail_sales_ml_apl.csv",
        "dataset_summary": "  - BRS-5KG-04 (Beras Premium 5 kg): 687 baris transaksi, 2025-01-01 s/d 2026-11-15",
        "products": [
            {
                "product_id": "BRS-5KG-04",
                "status": "ok",
                "best_model": "sarima_trend",
                "model_scores": [
                    {
                        "model": "sarima_trend",
                        "available": True,
                        "mae": 2.0,
                        "rmse": 2.5,
                        "mape": 0.14,
                        "wape": 0.13,
                    }
                ],
                "forecast": [
                    {"date": "2026-11-16", "predicted_qty": 12.0},
                    {"date": "2026-11-17", "predicted_qty": 14.0},
                    {"date": "2026-11-18", "predicted_qty": 16.0},
                    {"date": "2026-11-19", "predicted_qty": 14.0},
                    {"date": "2026-11-20", "predicted_qty": 15.0},
                    {"date": "2026-11-21", "predicted_qty": 17.0},
                    {"date": "2026-11-22", "predicted_qty": 17.0},
                ],
                "stockout": {
                    "status": "will_run_out",
                    "days_until_stockout": 3,
                    "current_stock": 29.0,
                    "lead_time_days": 3,
                },
            }
        ],
    }


def test_extract_predictions_mendukung_forecast_dan_predictions():
    assert len(_extract_predictions({"forecast": [{"date": "2026-11-16", "predicted_qty": 5}]})) == 1
    assert len(_extract_predictions({"predictions": [{"date": "2026-11-16", "predicted_qty": 5}]})) == 1
    assert _extract_predictions({}) == []


def test_extract_best_metrics_membaca_key_model():
    prod = _sample_summary()["products"][0]
    m = _extract_best_metrics(prod)
    assert m["mae"] == pytest.approx(2.0)
    assert m["rmse"] == pytest.approx(2.5)
    assert m["mape"] == pytest.approx(0.14)


def test_compute_bounds_valid_dan_tidak_negatif():
    lo, hi = _compute_bounds(1.0, mae=2.5)
    assert lo == 0.0
    assert hi == 3.5
    assert lo <= hi


def test_push_summary_mengisi_store_id_metrik_dan_bounds(tmp_path: Path):
    summary_file = tmp_path / "pipeline_summary.json"
    summary_file.write_text(json.dumps(_sample_summary()), encoding="utf-8")

    # Bypass __init__ agar tidak perlu package supabase saat unit test
    sync = SupabaseSync.__new__(SupabaseSync)
    sync.url = "https://example.supabase.co"
    sync.dry_run = False
    fake = _FakeClient()
    sync._client = fake

    res = sync.push_summary(summary_file)
    assert res["ok"] == 1
    assert res["failed"] == []

    # Verifikasi ml_models menerima mape=14.0 (bukan None)
    ml_upserts = [op for tbl, op, _ in fake.log if tbl == "ml_models" and op[0] == "upsert"]
    assert len(ml_upserts) == 1
    assert ml_upserts[0][1]["mape"] == pytest.approx(14.0)
    assert ml_upserts[0][1]["mae"] == pytest.approx(2.0)

    # Verifikasi forecasts menyertakan store_id dan avg_daily_demand
    fc_inserts = [op for tbl, op, _ in fake.log if tbl == "forecasts" and op[0] == "insert"]
    assert len(fc_inserts) == 1
    assert fc_inserts[0][1]["store_id"] == "store-uuid-1"
    assert fc_inserts[0][1]["avg_daily_demand"] == pytest.approx(15.0)

    # Verifikasi forecast_details menyertakan store_id + lower_bound/upper_bound
    dt_inserts = [op for tbl, op, _ in fake.log if tbl == "forecast_details" and op[0] == "insert"]
    assert len(dt_inserts) == 1
    rows = dt_inserts[0][1]
    assert len(rows) == 7
    assert rows[0]["store_id"] == "store-uuid-1"
    assert rows[0]["lower_bound"] == pytest.approx(10.0)
    assert rows[0]["upper_bound"] == pytest.approx(14.0)

    # Verifikasi RPC refresh_forecast_stockout dipanggil
    rpcs = [item for item in fake.log if item[0] == "rpc"]
    assert rpcs == [("rpc", "refresh_forecast_stockout", {"p_forecast_id": "fc-uuid-1"})]
