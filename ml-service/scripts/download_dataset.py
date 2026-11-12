"""Unduh dataset contoh yang layak untuk peramalan, lalu ubah ke format pipeline.

Kenapa dataset ini?
-------------------
Banyak dataset publik penjualan ritel ternyata **acak** (tidak ada pola),
sehingga model apa pun tidak bisa lebih baik daripada menebak rata-rata.
Dataset "Store Item Demand" punya pola yang benar-benar bisa dipelajari:
tren naik, musim mingguan, dan musim tahunan. Karena itu cocok untuk
mendemonstrasikan pipeline dan mengukur akurasi secara jujur.

Pemakaian
---------
    # unduh 2 toko x 15 produk (default, cukup cepat)
    python scripts/download_dataset.py

    # lebih banyak data (lebih lama karena SARIMA dilatih per produk)
    python scripts/download_dataset.py --stores 3 --items 20

Hasil: data/raw/store_item_demand.csv
"""

from __future__ import annotations

import argparse
import sys
import urllib.request
from pathlib import Path

SRC_DIR = Path(__file__).resolve().parents[1] / "src"
if str(SRC_DIR) not in sys.path:
    sys.path.insert(0, str(SRC_DIR))

from umkm_ml import config  # noqa: E402

# Salinan publik dari dataset "Store Item Demand Forecasting Challenge".
# Aslinya di Kaggle; URL ini hanya cermin agar bisa diunduh tanpa login.
URLS = (
    "https://raw.githubusercontent.com/bikramdutta/"
    "store_item_demand_forecasting/HEAD/data/train.csv",
    "https://raw.githubusercontent.com/bikramdutta/"
    "store_item_demand_forecasting/main/data/train.csv",
)

OUTPUT = config.RAW_DIR / "store_item_demand.csv"
CACHE = config.RAW_DIR / "_store_item_demand_raw.csv"


def download(urls: tuple[str, ...], target: Path) -> Path:
    """Unduh file pertama yang berhasil. Lewati bila sudah ada."""
    if target.exists() and target.stat().st_size > 1_000_000:
        print(f"Menggunakan file yang sudah ada: {target}")
        return target

    last_error: Exception | None = None
    for url in urls:
        try:
            print(f"Mengunduh: {url}")
            urllib.request.urlretrieve(url, target)
            size_mb = target.stat().st_size / 1024 / 1024
            print(f"Selesai ({size_mb:.1f} MB)")
            return target
        except Exception as exc:  # noqa: BLE001
            last_error = exc
            print(f"  gagal: {exc}")

    raise RuntimeError(
        "Tidak bisa mengunduh dataset. Periksa koneksi internet.\n"
        f"Error terakhir: {last_error}"
    )


def convert(raw_path: Path, stores: int, items: int) -> "object":
    """Ubah ke format pipeline dan ambil sebagian toko/produk."""
    import pandas as pd

    frame = pd.read_csv(raw_path, parse_dates=["date"])

    selected_stores = sorted(frame["store"].unique())[:stores]
    selected_items = sorted(frame["item"].unique())[:items]
    subset = frame[
        frame["store"].isin(selected_stores) & frame["item"].isin(selected_items)
    ].copy()

    subset["product_id"] = (
        "Toko" + subset["store"].astype(str)
        + "-Item" + subset["item"].astype(str).str.zfill(2)
    )
    subset["product_name"] = (
        "Item " + subset["item"].astype(str).str.zfill(2)
        + " (toko " + subset["store"].astype(str) + ")"
    )

    result = subset.rename(
        columns={"date": "transaction_date", "sales": "quantity"}
    )[["transaction_date", "product_id", "product_name", "quantity"]]
    result = result.sort_values(["product_id", "transaction_date"])
    return result.reset_index(drop=True)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Unduh dataset Store Item Demand dan siapkan untuk pipeline"
    )
    parser.add_argument(
        "--stores", type=int, default=2, help="Jumlah toko (default 2)"
    )
    parser.add_argument(
        "--items", type=int, default=15, help="Jumlah produk per toko (default 15)"
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Unduh ulang walau file mentah sudah ada.",
    )
    args = parser.parse_args()

    config.ensure_directories()
    if args.force and CACHE.exists():
        CACHE.unlink()

    raw_path = download(URLS, CACHE)
    frame = convert(raw_path, args.stores, args.items)
    frame.to_csv(OUTPUT, index=False)

    span = frame["transaction_date"]
    print()
    print(f"Dataset siap: {OUTPUT}")
    print(f"  Baris      : {len(frame):,}")
    print(f"  Produk     : {frame['product_id'].nunique()}")
    print(
        f"  Rentang    : {span.min().date()} s/d {span.max().date()} "
        f"({span.dt.normalize().nunique()} hari)"
    )
    print(f"  Rata-rata  : {frame['quantity'].mean():.1f} unit/hari per produk")
    print()
    print("Langkah berikutnya:")
    print(
        f'  python scripts/run_pipeline.py --data "{OUTPUT.relative_to(config.PROJECT_ROOT)}"'
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
