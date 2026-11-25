"""Sinkronisasi hasil peramalan ML asli (artifacts/pipeline_summary.json) ke Supabase.

Skrip ini menjembatani output pipeline Python (`ml-service`) dengan database
Supabase yang digunakan oleh aplikasi Flutter (`UMKM Sight`), tanpa angka
hardcoded.

Cara kerja:
1. Membaca `artifacts/pipeline_summary.json` hasil `scripts/run_pipeline.py`.
2. Mengambil metrik model aktual (MAPE, MAE, RMSE) serta prediksi harian dan
   interval kepercayaan (`lower_bound`, `upper_bound`) dari setiap produk.
3. Menghasilkan file SQL siap-eksekusi (`artifacts/sync_forecasts.sql` dan
   `mobile/supabase/sync_forecasts.sql`) untuk dijalankan di Supabase SQL Editor,
   ATAU mengirim langsung via REST API bila Service Role Key disediakan.

Contoh pemakaian:
    # 1. Hasilkan file SQL dari pipeline_summary.json (paling aman & mudah)
    python scripts/sync_to_supabase.py

    # 2. Geser tanggal prediksi mulai besok (opsional untuk demo UI hari ini)
    python scripts/sync_to_supabase.py --shift-dates

    # 3. Kirim langsung via REST API (membutuhkan service_role secret key)
    python scripts/sync_to_supabase.py --service-key sb_secret_...
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import urllib.error
import urllib.request
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any

# Setup path agar modul umkm_ml dapat diimpor
SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = SCRIPT_DIR.parent
SRC_DIR = PROJECT_ROOT / "src"
if str(SRC_DIR) not in sys.path:
    sys.path.insert(0, str(SRC_DIR))

from umkm_ml import config  # noqa: E402
from umkm_ml.supabase_sync import (  # noqa: E402
    _compute_bounds,
    _extract_best_metrics,
    _extract_predictions,
)

# Path ke env.json mobile
MOBILE_ENV_JSON = PROJECT_ROOT.parent / "mobile" / "env.json"

_DATASET_LINE_RE = re.compile(r"^\s*-\s+([^\s(]+)\s+\((.+)\):\s+\d+\s+baris")


def load_mobile_env() -> tuple[str, str]:
    """Baca SUPABASE_URL dan SUPABASE_ANON_KEY dari mobile/env.json bila ada."""
    if MOBILE_ENV_JSON.exists():
        try:
            data = json.loads(MOBILE_ENV_JSON.read_text(encoding="utf-8"))
            return data.get("SUPABASE_URL", ""), data.get("SUPABASE_ANON_KEY", "")
        except Exception:
            pass
    return "", ""


def parse_product_names(dataset_summary: str) -> dict[str, str]:
    """Ekstrak peta product_id -> nama produk dari ringkasan dataset."""
    names: dict[str, str] = {}
    for line in dataset_summary.splitlines():
        match = _DATASET_LINE_RE.match(line)
        if match:
            names[match.group(1).strip()] = match.group(2).strip()
    return names


def infer_unit(name: str) -> str:
    """Tebak satuan produk yang wajar dari nama produk."""
    low = name.lower()
    if "galon" in low:
        return "galon"
    if "tabung" in low or "elpiji" in low or "lpg" in low:
        return "tabung"
    if "beras" in low and "5 kg" in low:
        return "karung"
    if "botol" in low or "2l" in low or "750 ml" in low or "600 ml" in low:
        return "botol"
    if "kaleng" in low:
        return "kaleng"
    if "renteng" in low:
        return "renteng"
    if "kotak" in low:
        return "kotak"
    if "pak" in low:
        return "pak"
    if "kg" in low:
        return "kg"
    if "sachet" in low or "g)" in low or low.endswith("g"):
        return "bungkus"
    return "pcs"


def _sql_escape(text: str) -> str:
    return text.replace("'", "''")


def load_sync_records(
    summary_path: Path,
    shift_dates: bool = False,
) -> tuple[dict[str, Any], list[dict[str, Any]]]:
    """Baca pipeline_summary.json dan siapkan metadata model + daftar produk."""
    if not summary_path.exists():
        raise FileNotFoundError(
            f"File summary tidak ditemukan: {summary_path}\n"
            "Jalankan dulu: python scripts/run_pipeline.py"
        )

    summary = json.loads(summary_path.read_text(encoding="utf-8"))
    products = summary.get("products", [])
    names_map = parse_product_names(summary.get("dataset_summary", ""))

    mape_vals: list[float] = []
    mae_vals: list[float] = []
    rmse_vals: list[float] = []
    records: list[dict[str, Any]] = []

    today = datetime.now(timezone.utc).date()

    for prod in products:
        if prod.get("status") != "ok":
            continue

        sku = str(prod["product_id"])
        preds = _extract_predictions(prod)
        if not preds:
            continue

        metrics = _extract_best_metrics(prod)
        if metrics["mape"] is not None:
            mape_vals.append(float(metrics["mape"]) * 100.0)
        if metrics["mae"] is not None:
            mae_vals.append(float(metrics["mae"]))
        if metrics["rmse"] is not None:
            rmse_vals.append(float(metrics["rmse"]))

        qtys = [max(0.0, float(p["predicted_qty"])) for p in preds]
        avg_daily = round(sum(qtys) / len(qtys), 2)

        stockout = prod.get("stockout") or {}
        raw_stock = stockout.get("current_stock")
        stock = max(0, int(round(float(raw_stock)))) if raw_stock is not None else 0
        lead_time = int(stockout.get("lead_time_days") or config.DEFAULT_LEAD_TIME_DAYS)
        threshold = max(5, int(round(avg_daily * lead_time)))

        details: list[dict[str, Any]] = []
        for idx, (p, qty) in enumerate(zip(preds, qtys), start=1):
            fc_date = (
                (today + timedelta(days=idx)).isoformat()
                if shift_dates
                else str(p["date"])
            )
            lo, hi = _compute_bounds(
                qty, metrics["mae"], p.get("lower_bound"), p.get("upper_bound")
            )
            details.append(
                {
                    "forecast_date": fc_date,
                    "predicted_qty": round(qty, 2),
                    "lower_bound": lo,
                    "upper_bound": hi,
                }
            )

        name = names_map.get(sku, sku)
        records.append(
            {
                "sku": sku,
                "name": name,
                "unit": infer_unit(name),
                "stock": stock,
                "threshold": threshold,
                "best_model": prod.get("best_model") or "unknown",
                "horizon_days": min(max(len(details), 7), 30),
                "avg_daily_demand": avg_daily,
                "details": details,
            }
        )

    def _avg(lst: list[float], ndigits: int) -> float:
        return round(sum(lst) / len(lst), ndigits) if lst else 0.0

    model_meta = {
        "name": "UMKM Sight Demand Forecast",
        "version": "1.0.0",
        "algorithm": "SARIMA",
        "mape": _avg(mape_vals, 2),
        "mae": _avg(mae_vals, 4),
        "rmse": _avg(rmse_vals, 4),
        "generated_at": summary.get(
            "generated_at", datetime.now(timezone.utc).isoformat()
        ),
        "source_file": summary.get("data_file", str(summary_path)),
    }
    return model_meta, records


def generate_sql_migration(
    summary_path: Path,
    output_path: Path,
    shift_dates: bool = False,
) -> tuple[dict[str, Any], list[dict[str, Any]]]:
    """Hasilkan file SQL dari pipeline_summary.json untuk Supabase SQL Editor."""
    model_meta, records = load_sync_records(summary_path, shift_dates=shift_dates)
    if not records:
        raise RuntimeError(
            f"Tidak ada produk berstatus 'ok' di {summary_path}. Tidak ada SQL yang dibuat."
        )

    sql_parts = [
        "-- =============================================================================",
        "-- UMKM Sight: SINKRONISASI HASIL PERAMALAN ML ASLI KE DATABASE SUPABASE",
        f"-- Dihasilkan otomatis pada : {datetime.now(timezone.utc).isoformat()}",
        f"-- Sumber pipeline          : {summary_path.name} ({len(records)} produk)",
        f"-- Rata-rata metrik model   : MAPE={model_meta['mape']}%, MAE={model_meta['mae']}, RMSE={model_meta['rmse']}",
        "--",
        "-- Skrip ini memasukkan:",
        "--   1. Metadata Model ML aktif di tabel ml_models",
        "--   2. Produk-produk toko dari hasil pipeline (upsert by store_id, stock_code)",
        "--   3. Prediksi deret waktu + interval kepercayaan (forecasts & forecast_details)",
        "--   4. Menghitung hari stok habis via RPC refresh_forecast_stockout()",
        "-- =============================================================================\n",
        "do $$",
        "declare",
        "  v_store_id uuid;",
        "  v_model_id uuid;",
        "  v_prod_id  uuid;",
        "  v_fc_id    uuid;",
        "begin",
        "  -- 1. Ambil ID toko aktif (ambil toko pertama yang terdaftar)",
        "  select id into v_store_id from public.stores limit 1;",
        "  if v_store_id is null then",
        "    raise exception 'Belum ada toko yang terdaftar di database. Silakan daftar/login akun toko terlebih dahulu.';",
        "  end if;\n",
        "  -- 2. Nonaktifkan model lama lalu daftarkan / perbarui model aktif di ml_models",
        "  update public.ml_models set is_active = false where is_active = true;",
        "  insert into public.ml_models (name, version, algorithm, mape, rmse, mae, is_active, trained_at)",
        f"  values ('{_sql_escape(model_meta['name'])}', '{_sql_escape(model_meta['version'])}', "
        f"'{model_meta['algorithm']}', {model_meta['mape']}, {model_meta['rmse']}, {model_meta['mae']}, true, now())",
        "  on conflict (name, version) do update set",
        "    algorithm = excluded.algorithm,",
        "    mape = excluded.mape,",
        "    rmse = excluded.rmse,",
        "    mae = excluded.mae,",
        "    is_active = true,",
        "    trained_at = now()",
        "  returning id into v_model_id;\n",
    ]

    for item in records:
        sku = _sql_escape(item["sku"])
        name = _sql_escape(item["name"])
        unit = _sql_escape(item["unit"])

        sql_parts.extend(
            [
                f"  -- Produk: {item['sku']} ({item['name']}) | model terbaik: {item['best_model']}",
                "  insert into public.products (store_id, stock_code, name, unit, current_stock, reorder_threshold, is_monitored, is_active)",
                f"  values (v_store_id, '{sku}', '{name}', '{unit}', {item['stock']}, {item['threshold']}, true, true)",
                "  on conflict (store_id, stock_code) do update set",
                "    name = excluded.name,",
                "    unit = excluded.unit,",
                "    current_stock = excluded.current_stock,",
                "    reorder_threshold = excluded.reorder_threshold,",
                "    is_active = true",
                "  returning id into v_prod_id;\n",
                "  -- Hapus prediksi lama untuk produk ini agar tidak duplikat",
                "  delete from public.forecasts where product_id = v_prod_id;\n",
                "  -- Buat baris header prediksi di forecasts",
                "  insert into public.forecasts (store_id, product_id, ml_model_id, horizon_days, avg_daily_demand, generated_at)",
                f"  values (v_store_id, v_prod_id, v_model_id, {item['horizon_days']}, {item['avg_daily_demand']}, now())",
                "  returning id into v_fc_id;\n",
                "  -- Masukkan rincian prediksi harian ke forecast_details",
            ]
        )

        for d in item["details"]:
            sql_parts.append(
                "  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound)"
                f" values (v_fc_id, v_store_id, '{d['forecast_date']}', {d['predicted_qty']}, {d['lower_bound']}, {d['upper_bound']});"
            )

        sql_parts.extend(
            [
                "  -- Hitung otomatis kapan stok habis",
                "  perform public.refresh_forecast_stockout(v_fc_id);\n",
            ]
        )

    sql_parts.extend(
        [
            f"  raise notice 'Sinkronisasi {len(records)} produk prediksi ML ke Supabase berhasil diselesaikan!';",
            "end $$;",
        ]
    )

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text("\n".join(sql_parts) + "\n", encoding="utf-8")
    print(f"[OK] File SQL berhasil dibuat ({len(records)} produk): {output_path}")
    return model_meta, records


def sync_via_rest_api(
    supabase_url: str,
    service_role_key: str,
    summary_path: Path,
    shift_dates: bool = False,
) -> None:
    """Kirim data hasil pipeline asli ke Supabase via PostgREST API."""
    model_meta, records = load_sync_records(summary_path, shift_dates=shift_dates)
    if not records:
        raise RuntimeError(f"Tidak ada produk berstatus 'ok' di {summary_path}.")

    headers = {
        "apikey": service_role_key,
        "Authorization": f"Bearer {service_role_key}",
        "Content-Type": "application/json",
        "Prefer": "return=representation, resolution=merge-duplicates",
    }

    base_url = supabase_url.rstrip("/")

    def _request(
        method: str, endpoint: str, payload: dict | list | None = None
    ) -> list | dict:
        url = f"{base_url}/rest/v1/{endpoint}"
        body = json.dumps(payload).encode("utf-8") if payload is not None else None
        req = urllib.request.Request(url, data=body, headers=headers, method=method)
        try:
            with urllib.request.urlopen(req) as resp:
                resp_text = resp.read().decode("utf-8")
                return json.loads(resp_text) if resp_text else []
        except urllib.error.HTTPError as err:
            err_msg = err.read().decode("utf-8")
            raise RuntimeError(f"HTTP {err.code} saat {method} {endpoint}: {err_msg}") from err

    print(f"[*] Menghubungi Supabase di: {base_url}")

    # 1. Ambil toko
    stores = _request("GET", "stores?select=id,store_name&limit=1")
    if not stores:
        raise RuntimeError("Tidak ada toko ditemukan di database Supabase!")
    store_id = stores[0]["id"]
    store_name = stores[0].get("store_name", "Toko UMKM")
    print(f"[+] Toko target: {store_name} ({store_id})")

    # 2. Nonaktifkan model lama & upsert model aktif
    _request("PATCH", "ml_models?is_active=eq.true", {"is_active": False})
    model_payload = [
        {
            "name": model_meta["name"],
            "version": model_meta["version"],
            "algorithm": model_meta["algorithm"],
            "mape": model_meta["mape"],
            "rmse": model_meta["rmse"],
            "mae": model_meta["mae"],
            "is_active": True,
            "trained_at": datetime.now(timezone.utc).isoformat(),
        }
    ]
    upserted_models = _request("POST", "ml_models?on_conflict=name,version", model_payload)
    model_id = upserted_models[0]["id"]
    print(
        f"[+] Model ML terdaftar: {model_meta['name']} "
        f"(MAPE={model_meta['mape']}%, ID: {model_id})"
    )

    # 3. Upsert products & forecasts dari hasil pipeline asli
    for item in records:
        sku = item["sku"]
        name = item["name"]

        prod_payload = [
            {
                "store_id": store_id,
                "stock_code": sku,
                "name": name,
                "unit": item["unit"],
                "current_stock": item["stock"],
                "reorder_threshold": item["threshold"],
                "is_monitored": True,
                "is_active": True,
            }
        ]
        upserted_prod = _request(
            "POST", "products?on_conflict=store_id,stock_code", prod_payload
        )
        prod_id = upserted_prod[0]["id"]

        # Hapus forecast lama produk ini agar bersih
        try:
            _request("DELETE", f"forecasts?product_id=eq.{prod_id}")
        except Exception:
            pass

        # Insert forecast baru
        fc_payload = [
            {
                "store_id": store_id,
                "product_id": prod_id,
                "ml_model_id": model_id,
                "horizon_days": item["horizon_days"],
                "avg_daily_demand": item["avg_daily_demand"],
                "generated_at": datetime.now(timezone.utc).isoformat(),
            }
        ]
        upserted_fc = _request("POST", "forecasts", fc_payload)
        fc_id = upserted_fc[0]["id"]

        # Insert details
        details_payload = [
            {
                "forecast_id": fc_id,
                "store_id": store_id,
                "forecast_date": d["forecast_date"],
                "predicted_qty": d["predicted_qty"],
                "lower_bound": d["lower_bound"],
                "upper_bound": d["upper_bound"],
            }
            for d in item["details"]
        ]
        _request("POST", "forecast_details", details_payload)

        # Refresh days until stockout
        _request("POST", "rpc/refresh_forecast_stockout", {"p_forecast_id": fc_id})
        print(f"  [+] Tersinkronisasi: {sku} - {name} (model={item['best_model']}, fc={fc_id})")

    print(f"[SUCCESS] {len(records)} produk hasil pipeline ML berhasil disinkronkan ke Supabase!")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Sinkronisasi hasil pipeline ML asli (pipeline_summary.json) ke Supabase"
    )
    parser.add_argument(
        "--summary",
        type=Path,
        default=config.ARTIFACT_DIR / "pipeline_summary.json",
        help="Path ke pipeline_summary.json (default: artifacts/pipeline_summary.json)",
    )
    parser.add_argument(
        "--shift-dates",
        action="store_true",
        help="Geser tanggal prediksi mulai besok (berguna bila data latih berakhir di masa lalu)",
    )
    parser.add_argument("--url", type=str, default=None, help="Supabase Project URL")
    parser.add_argument(
        "--service-key", type=str, default=None, help="Supabase Service Role Key (secret)"
    )
    parser.add_argument(
        "--sql-only", action="store_true", help="Hanya buat file SQL migrasi"
    )
    args = parser.parse_args()

    default_url, _ = load_mobile_env()
    supabase_url = args.url or os.environ.get("SUPABASE_URL") or default_url
    service_key = (
        args.service_key
        or os.environ.get("SUPABASE_SERVICE_ROLE_KEY")
        or os.environ.get("SUPABASE_SERVICE_KEY")
    )

    sql_artifact_path = config.ARTIFACT_DIR / "sync_forecasts.sql"
    sql_mobile_path = PROJECT_ROOT.parent / "mobile" / "supabase" / "sync_forecasts.sql"
    generate_sql_migration(args.summary, sql_artifact_path, shift_dates=args.shift_dates)
    generate_sql_migration(args.summary, sql_mobile_path, shift_dates=args.shift_dates)

    if args.sql_only or not service_key:
        print("\n" + "=" * 70)
        print("PANDUAN EKSEKUSI DI SUPABASE:")
        print("=" * 70)
        print("Karena penulisan ke tabel 'forecasts' dilindungi RLS (hanya boleh ditulis")
        print("oleh service_role/admin), cara paling cepat dan aman adalah:")
        print(f"1. Buka file: {sql_mobile_path}")
        print("2. Buka https://supabase.com > SQL Editor > New query")
        print("3. Tempel seluruh isi file tersebut, lalu klik 'Run'.")
        print("\nBila ingin kirim langsung dari terminal tanpa membuka browser:")
        print("Jalankan: python scripts/sync_to_supabase.py --service-key <SERVICE_ROLE_KEY>")
        print("=" * 70)
        return

    try:
        sync_via_rest_api(
            supabase_url,
            service_key,
            args.summary,
            shift_dates=args.shift_dates,
        )
    except Exception as e:
        print(f"\n[ERROR] Sinkronisasi via REST API gagal: {e}")
        print(f"Gunakan alternatif SQL Editor dengan file: {sql_mobile_path}")
        sys.exit(1)


if __name__ == "__main__":
    main()
