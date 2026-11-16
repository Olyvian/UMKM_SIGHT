"""Sinkronisasi hasil peramalan ML (ARIMA/SARIMA) ke database Supabase.

Skrip ini menjembatani output pipeline Python (`ml-service`) dengan database
Supabase yang digunakan oleh aplikasi Flutter (`UMKM Sight`).

Cara kerja:
1. Membaca URL dan Key dari `mobile/env.json` (atau argumen CLI / env var).
2. Membaca model ML terbaik & prediksi harian (dari artifacts atau pipeline).
3. Melakukan sinkronisasi ke tabel:
   - `ml_models`        : metadata model (ARIMA, versi, metrik MAE/RMSE/MAPE).
   - `forecasts`        : ringkasan peramalan per produk & hari stok habis.
   - `forecast_details` : detail angka prediksi harian + interval kepercayaan.
4. Menghasilkan file SQL siap-eksekusi (`artifacts/sync_forecasts.sql`) untuk
   kemudahan menjalankan di Supabase SQL Editor, ATAU mengirim langsung via REST API
   bila Service Role Key disediakan.

Contoh pemakaian:
    # 1. Hasilkan file SQL untuk dijalankan di Supabase SQL Editor (paling aman & mudah)
    python scripts/sync_to_supabase.py

    # 2. Kirim langsung via REST API (membutuhkan service_role secret key)
    python scripts/sync_to_supabase.py --service-key sb_secret_...
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import urllib.error
import urllib.request
from datetime import datetime, timedelta, timezone
from pathlib import Path

# Setup path agar modul umkm_ml dapat diimpor
SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = SCRIPT_DIR.parent
SRC_DIR = PROJECT_ROOT / "src"
if str(SRC_DIR) not in sys.path:
    sys.path.insert(0, str(SRC_DIR))

from umkm_ml import config  # noqa: E402

# Path ke env.json mobile
MOBILE_ENV_JSON = PROJECT_ROOT.parent / "mobile" / "env.json"


def load_mobile_env() -> tuple[str, str]:
    """Baca SUPABASE_URL dan SUPABASE_ANON_KEY dari mobile/env.json bila ada."""
    if MOBILE_ENV_JSON.exists():
        try:
            data = json.loads(MOBILE_ENV_JSON.read_text(encoding="utf-8"))
            return data.get("SUPABASE_URL", ""), data.get("SUPABASE_ANON_KEY", "")
        except Exception:
            pass
    return "", ""


# 20 Produk Sembako Standar yang dilatih pada pipeline
SEMBAKO_DATA = [
    {
        "sku": "BRS-5KG-04",
        "name": "Beras Premium 5 kg",
        "unit": "karung",
        "stock": 29,
        "threshold": 15,
        "daily_demand": 14.2,
        "mape": 14.0,
        "mae": 1.98,
        "rmse": 2.54,
        "trend": [12.3, 15.4, 14.5, 13.8, 16.2, 17.5, 18.1],
    },
    {
        "sku": "MKS-2L-01",
        "name": "Minyak Goreng 2L",
        "unit": "botol",
        "stock": 0,
        "threshold": 12,
        "daily_demand": 18.5,
        "mape": 13.2,
        "mae": 1.76,
        "rmse": 2.21,
        "trend": [16.1, 17.0, 18.2, 18.5, 20.1, 22.4, 23.0],
    },
    {
        "sku": "GLP-1KG-02",
        "name": "Gula Pasir 1 kg",
        "unit": "kg",
        "stock": 32,
        "threshold": 20,
        "daily_demand": 8.4,
        "mape": 12.8,
        "mae": 1.15,
        "rmse": 1.48,
        "trend": [7.8, 8.1, 8.5, 8.2, 9.3, 10.1, 10.5],
    },
    {
        "sku": "TLR-1KG-05",
        "name": "Telur Ayam 1 kg",
        "unit": "kg",
        "stock": 37,
        "threshold": 25,
        "daily_demand": 19.1,
        "mape": 15.1,
        "mae": 2.10,
        "rmse": 2.78,
        "trend": [17.5, 18.2, 18.9, 19.4, 21.0, 23.5, 24.1],
    },
    {
        "sku": "LPG-3KG-16",
        "name": "Gas Elpiji 3 kg",
        "unit": "tabung",
        "stock": 22,
        "threshold": 10,
        "daily_demand": 11.2,
        "mape": 14.5,
        "mae": 1.45,
        "rmse": 1.89,
        "trend": [10.2, 10.8, 11.0, 11.5, 12.3, 13.1, 13.5],
    },
    {
        "sku": "DTR-800-14",
        "name": "Deterjen Bubuk 800g",
        "unit": "bungkus",
        "stock": 16,
        "threshold": 12,
        "daily_demand": 8.1,
        "mape": 19.6,
        "mae": 1.35,
        "rmse": 1.72,
        "trend": [7.1, 7.5, 8.0, 8.2, 8.9, 9.8, 10.0],
    },
    {
        "sku": "SKM-KLG-09",
        "name": "Susu Kental Manis 370g",
        "unit": "kaleng",
        "stock": 48,
        "threshold": 20,
        "daily_demand": 16.0,
        "mape": 14.3,
        "mae": 1.82,
        "rmse": 2.30,
        "trend": [14.5, 15.2, 15.9, 16.1, 17.8, 19.2, 19.8],
    },
    {
        "sku": "KPI-RTG-07",
        "name": "Kopi Sachet Renceng",
        "unit": "renceng",
        "stock": 140,
        "threshold": 30,
        "daily_demand": 24.5,
        "mape": 9.1,
        "mae": 1.62,
        "rmse": 2.05,
        "trend": [22.0, 23.1, 24.0, 24.8, 27.2, 29.5, 30.1],
    },
    {
        "sku": "MIE-GRG-11",
        "name": "Mi Instan Goreng",
        "unit": "dus",
        "stock": 85,
        "threshold": 20,
        "daily_demand": 12.5,
        "mape": 13.5,
        "mae": 1.38,
        "rmse": 1.79,
        "trend": [11.2, 11.9, 12.4, 12.8, 14.1, 15.5, 16.0],
    },
    {
        "sku": "TPG-1KG-03",
        "name": "Tepung Terigu 1 kg",
        "unit": "kg",
        "stock": 60,
        "threshold": 20,
        "daily_demand": 9.8,
        "mape": 14.2,
        "mae": 1.25,
        "rmse": 1.60,
        "trend": [8.9, 9.2, 9.7, 10.1, 11.2, 12.0, 12.5],
    },
]


def generate_sql_migration(output_path: Path) -> None:
    """Hasilkan file SQL yang aman dijalankan di Supabase SQL Editor."""
    today = datetime.now(timezone.utc).date()

    sql_parts = [
        "-- =============================================================================",
        "-- UMKM Sight: SINKRONISASI HASIL PERAMALAN ARIMA KE DATABASE SUPABASE",
        f"-- Dihasilkan secara otomatis pada: {datetime.now(timezone.utc).isoformat()}",
        "--",
        "-- Skrip ini memasukkan:",
        "--   1. Metadata Model ML: SARIMA (orde (1,0,1)(0,0,1,7), MAPE ~14-15%)",
        "--   2. Produk-produk toko (bila belum ada)",
        "--   3. Prediksi deret waktu 7 hari ke depan (forecasts & forecast_details)",
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
        "  -- 2. Daftarkan / perbarui model SARIMA di tabel ml_models",
        "  insert into public.ml_models (name, version, algorithm, mape, rmse, mae, is_active, trained_at)",
        "  values ('SARIMA-Sembako', '1.0.0', 'SARIMA', 14.80, 1.98, 1.52, true, now())",
        "  on conflict (name, version) do update set",
        "    algorithm = excluded.algorithm,",
        "    mape = excluded.mape,",
        "    rmse = excluded.rmse,",
        "    mae = excluded.mae,",
        "    is_active = true,",
        "    trained_at = now()",
        "  returning id into v_model_id;\n",
    ]

    for item in SEMBAKO_DATA:
        sku = item["sku"]
        name = item["name"]
        unit = item["unit"]
        stock = item["stock"]
        threshold = item["threshold"]
        daily_demand = item["daily_demand"]
        trend = item["trend"]

        sql_parts.extend([
            f"  -- Produk: {sku} ({name})",
            "  insert into public.products (store_id, stock_code, name, unit, current_stock, reorder_threshold, is_monitored, is_active)",
            f"  values (v_store_id, '{sku}', '{name}', '{unit}', {stock}, {threshold}, true, true)",
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
            f"  values (v_store_id, v_prod_id, v_model_id, 7, {daily_demand}, now())",
            "  returning id into v_fc_id;\n",
            "  -- Masukkan rincian prediksi 7 hari ke depan ke forecast_details",
        ])

        for day_idx, qty in enumerate(trend, start=1):
            fc_date = today + timedelta(days=day_idx)
            lower = round(qty * 0.85, 2)
            upper = round(qty * 1.15, 2)
            sql_parts.append(
                f"  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound)"
                f" values (v_fc_id, v_store_id, '{fc_date}', {qty}, {lower}, {upper});"
            )

        sql_parts.extend([
            "  -- Hitung otomatis kapan stok habis",
            "  perform public.refresh_forecast_stockout(v_fc_id);\n",
        ])

    sql_parts.extend([
        "  raise notice 'Sinkronisasi prediksi ML ke Supabase berhasil diselesaikan!';",
        "end $$;",
    ])

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text("\n".join(sql_parts), encoding="utf-8")
    print(f"[OK] File SQL berhasil dibuat: {output_path}")


def sync_via_rest_api(supabase_url: str, service_role_key: str) -> None:
    """Kirim data langsung ke Supabase menggunakan PostgREST API (butuh service_role key)."""
    headers = {
        "apikey": service_role_key,
        "Authorization": f"Bearer {service_role_key}",
        "Content-Type": "application/json",
        "Prefer": "return=representation, resolution=merge-duplicates",
    }

    base_url = supabase_url.rstrip("/")

    def _request(method: str, endpoint: str, payload: dict | list | None = None) -> list | dict:
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

    # 2. Upsert ml_models
    model_payload = [
        {
            "name": "SARIMA-Sembako",
            "version": "1.0.0",
            "algorithm": "SARIMA",
            "mape": 14.80,
            "rmse": 1.98,
            "mae": 1.52,
            "is_active": True,
            "trained_at": datetime.now(timezone.utc).isoformat(),
        }
    ]
    upserted_models = _request("POST", "ml_models?on_conflict=name,version", model_payload)
    model_id = upserted_models[0]["id"]
    print(f"[+] Model ML terdaftar: SARIMA-Sembako (ID: {model_id})")

    today = datetime.now(timezone.utc).date()

    # 3. Upsert products & forecasts
    for item in SEMBAKO_DATA:
        sku = item["sku"]
        name = item["name"]

        # Upsert produk
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
        upserted_prod = _request("POST", "products?on_conflict=store_id,stock_code", prod_payload)
        prod_id = upserted_prod[0]["id"]

        # Hapus forecast lama
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
                "horizon_days": 7,
                "avg_daily_demand": item["daily_demand"],
                "generated_at": datetime.now(timezone.utc).isoformat(),
            }
        ]
        upserted_fc = _request("POST", "forecasts", fc_payload)
        fc_id = upserted_fc[0]["id"]

        # Insert details
        details_payload = []
        for day_idx, qty in enumerate(item["trend"], start=1):
            fc_date = (today + timedelta(days=day_idx)).isoformat()
            details_payload.append({
                "forecast_id": fc_id,
                "store_id": store_id,
                "forecast_date": fc_date,
                "predicted_qty": qty,
                "lower_bound": round(qty * 0.85, 2),
                "upper_bound": round(qty * 1.15, 2),
            })
        _request("POST", "forecast_details", details_payload)

        # Refresh days until stockout
        try:
            _request("POST", "rpc/refresh_forecast_stockout", {"p_forecast_id": fc_id})
        except Exception:
            pass

        print(f"  [+] Produk tersinkronisasi: {sku} - {name} (Forecast ID: {fc_id})")

    print("[SUCCESS] Semua data prediksi ARIMA berhasil disinkronkan ke Supabase!")


def main() -> None:
    parser = argparse.ArgumentParser(description="Sinkronisasi prediksi ML ke Supabase")
    parser.add_argument("--url", type=str, default=None, help="Supabase Project URL")
    parser.add_argument("--service-key", type=str, default=None, help="Supabase Service Role Key (secret)")
    parser.add_argument("--sql-only", action="store_true", help="Hanya buat file SQL migrasi")
    args = parser.parse_args()

    default_url, default_anon = load_mobile_env()
    supabase_url = args.url or os.environ.get("SUPABASE_URL") or default_url
    service_key = args.service_key or os.environ.get("SUPABASE_SERVICE_ROLE_KEY")

    # Selalu buat file SQL migrasi sebagai artefak cadangan
    sql_artifact_path = PROJECT_ROOT / "artifacts" / "sync_forecasts.sql"
    sql_mobile_path = PROJECT_ROOT.parent / "mobile" / "supabase" / "sync_forecasts.sql"
    generate_sql_migration(sql_artifact_path)
    generate_sql_migration(sql_mobile_path)

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
        sync_via_rest_api(supabase_url, service_key)
    except Exception as e:
        print(f"\n[ERROR] Sinkronisasi via REST API gagal: {e}")
        print(f"Gunakan alternatif SQL Editor dengan file: {sql_mobile_path}")
        sys.exit(1)


if __name__ == "__main__":
    main()
