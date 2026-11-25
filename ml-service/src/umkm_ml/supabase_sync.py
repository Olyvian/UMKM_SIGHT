"""Sinkronisasi hasil pipeline ML ke Supabase.

Modul ini membaca hasil yang sudah dihitung oleh pipeline (artefak JSON di
``artifacts/``) dan menyuntikkannya ke tabel Supabase yang sudah ada:

    ml_models        -- model aktif beserta metriknya
    forecasts        -- satu baris per produk per run
    forecast_details -- prediksi harian (+ lower/upper bound)

Setelah semua baris ditulis, modul memanggil stored procedure
``public.refresh_forecast_stockout(forecast_id)`` agar kolom
``days_until_stockout`` di tabel ``forecasts`` terisi otomatis.

Cara pakai (sekali jalan, setelah pipeline selesai):

    from umkm_ml.supabase_sync import SupabaseSync

    sync = SupabaseSync.from_env()          # baca SUPABASE_URL & SERVICE_KEY dari env
    sync.push_summary("artifacts/pipeline_summary.json")

Atau lewat CLI (dari folder ml-service):

    python -m umkm_ml.supabase_sync --summary artifacts/pipeline_summary.json

Dependensi tambahan (pasang sekali):
    pip install supabase>=2.0

Variabel lingkungan yang dibutuhkan:
    SUPABASE_URL         -- mis. https://xxxx.supabase.co
    SUPABASE_SERVICE_KEY -- key berawalan sb_secret_ / service_role
                           (JANGAN gunakan anon key: perlu hak tulis ke
                           forecasts & forecast_details)
"""

from __future__ import annotations

import json
import logging
import os
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

logger = logging.getLogger(__name__)

# Versi model yang di-push (ganti tiap retrain signifikan).
_MODEL_VERSION = "1.0"
_ALGORITHM = "SARIMA"
_MODEL_NAME = "UMKM Sight Demand Forecast"


# ---------------------------------------------------------------------------
# Helper
# ---------------------------------------------------------------------------

def _require_env(key: str) -> str:
    val = os.environ.get(key, "").strip()
    if not val:
        raise EnvironmentError(
            f"Variabel lingkungan '{key}' tidak diisi. "
            "Tambahkan ke .env atau export sebelum menjalankan skrip ini."
        )
    return val


def _extract_predictions(prod: dict[str, Any]) -> list[dict[str, Any]]:
    """Ambil daftar prediksi harian dari pipeline_summary.json ('forecast')
    maupun product_*_forecast.json ('predictions')."""
    preds = prod.get("predictions")
    if preds:
        return list(preds)
    fc = prod.get("forecast")
    if fc:
        return list(fc)
    return []


def _extract_best_metrics(prod: dict[str, Any]) -> dict[str, float | None]:
    """Ambil metrik (mape, mae, rmse) untuk model terbaik suatu produk."""
    best = prod.get("best_model") or prod.get("model")
    for score in prod.get("model_scores", []):
        score_name = score.get("model") or score.get("name")
        if score_name == best and score.get("available"):
            return {
                "mape": score.get("mape"),
                "mae": score.get("mae"),
                "rmse": score.get("rmse"),
            }

    # Fallback ke accuracy_by_horizon 7_hari bila model_scores tidak ada.
    h7 = prod.get("accuracy_by_horizon", {}).get("7_hari")
    if isinstance(h7, dict):
        return {
            "mape": h7.get("mape"),
            "mae": h7.get("mae"),
            "rmse": h7.get("rmse"),
        }
    return {"mape": None, "mae": None, "rmse": None}


def _compute_bounds(
    qty: float,
    mae: float | None,
    lower: Any = None,
    upper: Any = None,
) -> tuple[float, float]:
    """Hitung batas bawah & atas prediksi (numeric(12, 2), lower <= upper)."""
    if lower is not None and upper is not None:
        lo, hi = round(max(0.0, float(lower)), 2), round(max(0.0, float(upper)), 2)
    elif mae is not None and mae >= 0:
        lo = round(max(0.0, qty - float(mae)), 2)
        hi = round(max(0.0, qty + float(mae)), 2)
    else:
        lo = round(max(0.0, qty * 0.85), 2)
        hi = round(max(0.0, qty * 1.15), 2)
    if lo > hi:
        lo, hi = hi, lo
    return lo, hi


# ---------------------------------------------------------------------------
# Kelas utama
# ---------------------------------------------------------------------------

class SupabaseSync:
    """Push hasil pipeline ML ke Supabase.

    Parameters
    ----------
    url : str
        URL project Supabase, mis. ``https://xxxx.supabase.co``.
    service_key : str
        ``service_role`` key (berawalan ``sb_secret_`` atau ``service_role``).
        Key ini diperlukan karena RLS hanya mengizinkan ``service_role``
        menulis ke tabel ``forecasts`` dan ``forecast_details``.
    dry_run : bool
        Jika ``True``, cetak data yang akan dikirim tanpa benar-benar
        menulis ke Supabase. Berguna untuk debugging.
    """

    def __init__(
        self,
        url: str,
        service_key: str,
        dry_run: bool = False,
    ) -> None:
        self.url = url.rstrip("/")
        self.dry_run = dry_run

        try:
            from supabase import create_client  # type: ignore[import]
        except ImportError as exc:
            raise ImportError(
                "Package 'supabase' belum terpasang.\n"
                "Pasang dengan:  pip install supabase>=2.0"
            ) from exc

        self._client = create_client(url, service_key)
        logger.info("SupabaseSync terhubung ke %s (dry_run=%s)", url, dry_run)

    @classmethod
    def from_env(cls, dry_run: bool = False) -> "SupabaseSync":
        """Buat instance dari variabel lingkungan SUPABASE_URL dan
        SUPABASE_SERVICE_KEY."""
        return cls(
            url=_require_env("SUPABASE_URL"),
            service_key=_require_env("SUPABASE_SERVICE_KEY"),
            dry_run=dry_run,
        )

    # ------------------------------------------------------------------
    # API publik
    # ------------------------------------------------------------------

    def push_summary(self, summary_path: str | Path) -> dict[str, Any]:
        """Baca ``pipeline_summary.json`` dan push semua produk ke Supabase.

        Returns
        -------
        dict dengan kunci ``ok`` (jumlah produk berhasil) dan ``failed``
        (daftar product_id yang gagal beserta alasannya).
        """
        path = Path(summary_path)
        if not path.exists():
            raise FileNotFoundError(f"File tidak ditemukan: {path}")

        summary = json.loads(path.read_text(encoding="utf-8"))
        products = summary.get("products", [])
        if not products:
            logger.warning("Tidak ada produk di summary. Tidak ada yang di-push.")
            return {"ok": 0, "failed": []}

        # --- 1. Upsert model aktif ----------------------------------------
        model_id = self._upsert_ml_model(summary)

        # --- 2. Push tiap produk ------------------------------------------
        ok = 0
        failed: list[dict] = []
        for prod in products:
            pid = prod.get("product_id", "unknown")
            if prod.get("status") != "ok":
                logger.debug("Lewati produk %s (status: %s)", pid, prod.get("status"))
                continue
            try:
                self._push_product(prod, model_id)
                ok += 1
                logger.info("✓ Produk %s berhasil di-push", pid)
            except Exception as exc:  # noqa: BLE001
                logger.error("✗ Produk %s gagal: %s", pid, exc)
                failed.append({"product_id": pid, "error": str(exc)})

        logger.info("Selesai: %d berhasil, %d gagal", ok, len(failed))
        return {"ok": ok, "failed": failed}

    def push_product_json(
        self, forecast_json_path: str | Path, model_id: str | None = None
    ) -> None:
        """Push satu file ``product_<id>_forecast.json`` ke Supabase.

        Berguna bila Anda hanya ingin mengupdate satu produk tanpa
        menjalankan ulang seluruh pipeline.
        """
        path = Path(forecast_json_path)
        data = json.loads(path.read_text(encoding="utf-8"))
        if model_id is None:
            model_id = self._upsert_ml_model({})
        self._push_product(data, model_id)

    # ------------------------------------------------------------------
    # Metode privat
    # ------------------------------------------------------------------

    def _upsert_ml_model(self, summary: dict) -> str:
        """Pastikan baris model ada di tabel ml_models, kembalikan UUID-nya."""
        # Ambil metrik rata-rata dari semua produk yang statusnya 'ok'.
        mape_vals: list[float] = []
        mae_vals: list[float] = []
        rmse_vals: list[float] = []
        for prod in summary.get("products", []):
            if prod.get("status") != "ok":
                continue
            m = _extract_best_metrics(prod)
            if m["mape"] is not None:
                mape_vals.append(float(m["mape"]) * 100.0)  # simpan sbg persentase
            if m["mae"] is not None:
                mae_vals.append(float(m["mae"]))
            if m["rmse"] is not None:
                rmse_vals.append(float(m["rmse"]))

        def _avg(lst: list[float], ndigits: int) -> float | None:
            return round(sum(lst) / len(lst), ndigits) if lst else None

        payload = {
            "name": _MODEL_NAME,
            "version": _MODEL_VERSION,
            "algorithm": _ALGORITHM,
            "mape": _avg(mape_vals, 2),
            "mae": _avg(mae_vals, 4),
            "rmse": _avg(rmse_vals, 4),
            "is_active": True,
            "trained_at": datetime.now(timezone.utc).isoformat(),
        }

        if self.dry_run:
            logger.info("[DRY RUN] ml_models upsert: %s", payload)
            return "dry-run-model-id"

        # Nonaktifkan model lama terlebih dahulu.
        (
            self._client.table("ml_models")
            .update({"is_active": False})
            .eq("is_active", True)
            .execute()
        )

        # Insert / upsert model baru.
        resp = (
            self._client.table("ml_models")
            .upsert(payload, on_conflict="name,version")
            .execute()
        )
        rows = resp.data
        if not rows:
            raise RuntimeError("ml_models upsert tidak mengembalikan data.")
        model_id: str = rows[0]["id"]
        logger.info("ml_model id=%s (mape=%.2f%%)", model_id, payload["mape"] or 0.0)
        return model_id

    def _push_product(self, prod: dict, model_id: str) -> None:
        """Insert forecast + detail + panggil refresh_forecast_stockout."""
        pid_raw = prod.get("product_id")

        # --- Cari UUID produk & store_id dari stock_code -----------------
        product_uuid, store_id = self._resolve_product(str(pid_raw))

        predictions = _extract_predictions(prod)
        stockout: dict = prod.get("stockout") or {}
        days_until = stockout.get("days_until_stockout")

        horizon = len(predictions)
        if horizon == 0:
            raise ValueError(f"Produk {pid_raw}: tidak ada prediksi untuk di-push.")

        qtys = [max(0.0, float(p["predicted_qty"])) for p in predictions]
        avg_daily_demand = round(sum(qtys) / len(qtys), 2)
        best_mae = _extract_best_metrics(prod).get("mae")

        # --- Insert ke forecasts -----------------------------------------
        forecast_payload = {
            "store_id": store_id,
            "product_id": product_uuid,
            "ml_model_id": model_id,
            "horizon_days": min(max(horizon, 7), 30),
            "days_until_stockout": days_until,
            "avg_daily_demand": avg_daily_demand,
            "generated_at": prod.get(
                "generated_at", datetime.now(timezone.utc).isoformat()
            ),
        }

        if self.dry_run:
            logger.info("[DRY RUN] forecasts insert: %s", forecast_payload)
            logger.info(
                "[DRY RUN] forecast_details: %d baris untuk produk %s",
                len(predictions),
                pid_raw,
            )
            return

        fc_resp = (
            self._client.table("forecasts").insert(forecast_payload).execute()
        )
        fc_rows = fc_resp.data
        if not fc_rows:
            raise RuntimeError(f"Produk {pid_raw}: forecasts insert gagal (tidak ada data kembali).")
        forecast_id: str = fc_rows[0]["id"]

        # --- Insert ke forecast_details -----------------------------------
        detail_rows = []
        for p, qty in zip(predictions, qtys):
            lo, hi = _compute_bounds(
                qty, best_mae, p.get("lower_bound"), p.get("upper_bound")
            )
            detail_rows.append(
                {
                    "forecast_id": forecast_id,
                    "store_id": store_id,
                    "forecast_date": p["date"],
                    "predicted_qty": round(qty, 2),
                    "lower_bound": lo,
                    "upper_bound": hi,
                }
            )
        self._client.table("forecast_details").insert(detail_rows).execute()

        # --- Panggil stored procedure refresh_forecast_stockout -----------
        # Ini menghitung ulang days_until_stockout dari detail yang baru
        # diinsert dan memperbarui kolom di tabel forecasts.
        self._client.rpc(
            "refresh_forecast_stockout", {"p_forecast_id": forecast_id}
        ).execute()

    def _resolve_product(self, stock_code: str) -> tuple[str, str]:
        """Cari (product_id, store_id) berdasarkan stock_code di tabel products."""
        if self.dry_run:
            return f"dry-run-product-{stock_code}", "dry-run-store-id"

        resp = (
            self._client.table("products")
            .select("id, store_id")
            .eq("stock_code", stock_code)
            .limit(1)
            .execute()
        )
        rows = resp.data
        if not rows:
            raise ValueError(
                f"stock_code '{stock_code}' tidak ditemukan di tabel products. "
                "Pastikan produk sudah didaftarkan sebelum menjalankan sync."
            )
        return rows[0]["id"], rows[0]["store_id"]

    def _resolve_product_uuid(self, stock_code: str) -> str:
        """Kompatibilitas lama: kembalikan hanya product_id."""
        product_id, _ = self._resolve_product(stock_code)
        return product_id


# ---------------------------------------------------------------------------
# Entry point CLI
# ---------------------------------------------------------------------------

def _main() -> None:
    import argparse

    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(message)s",
        datefmt="%H:%M:%S",
    )

    parser = argparse.ArgumentParser(
        description="Push hasil pipeline ML UMKM Sight ke Supabase."
    )
    parser.add_argument(
        "--summary",
        default="artifacts/pipeline_summary.json",
        help="Path ke pipeline_summary.json (default: artifacts/pipeline_summary.json)",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Tampilkan data yang akan dikirim tanpa benar-benar menulis ke Supabase.",
    )
    args = parser.parse_args()

    try:
        sync = SupabaseSync.from_env(dry_run=args.dry_run)
    except EnvironmentError as exc:
        print(f"[ERROR] {exc}", file=sys.stderr)
        sys.exit(1)

    result = sync.push_summary(args.summary)
    print(
        f"\n✓ Selesai: {result['ok']} produk berhasil, "
        f"{len(result['failed'])} gagal."
    )
    if result["failed"]:
        print("Produk yang gagal:")
        for f in result["failed"]:
            print(f"  - {f['product_id']}: {f['error']}")
        sys.exit(1)


if __name__ == "__main__":
    _main()
