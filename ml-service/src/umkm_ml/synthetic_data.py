"""Pembuat data transaksi contoh (synthetic) untuk latihan pipeline.

Kenapa perlu?
-------------
Pipeline butuh data untuk dijalankan. Saat backend Laravel belum ada, kita
membuat data tiruan yang menyerupai keluaran tabel `sales` + `sale_items`
di PRD: setiap baris = satu item transaksi.

Data tiruan ini WAJIB diberi label "simulasi" di laporan, jangan pernah
diklaim sebagai data UMKM nyata (PRD bagian 8).

Pola yang sengaja ditanamkan agar model punya sesuatu untuk dipelajari:
  - trend       : penjualan perlahan naik
  - seasonality : akhir pekan lebih ramai (pola mingguan)
  - noise       : variasi acak
  - hari tutup  : beberapa hari tanpa baris transaksi sama sekali
  - retur       : beberapa baris kuantitas negatif yang harus dibuang
"""

from __future__ import annotations

from dataclasses import dataclass

import numpy as np
import pandas as pd

# Nama hari: 0 = Senin ... 6 = Minggu
_WEEKDAY_FACTOR = np.array([0.85, 0.85, 0.9, 0.95, 1.1, 1.35, 1.3])


@dataclass(frozen=True)
class ProductProfile:
    """Karakter penjualan satu produk tiruan."""

    product_id: int
    name: str
    base_demand: float  # rata-rata penjualan per hari
    trend_per_day: float  # kenaikan permintaan per hari
    unit_price: float


DEFAULT_PRODUCTS = (
    ProductProfile(1, "Kopi Sachet", base_demand=6.0, trend_per_day=0.012, unit_price=2500),
    ProductProfile(2, "Gula Pasir 1kg", base_demand=3.0, trend_per_day=0.004, unit_price=14000),
)


def generate_sales(
    days: int = 180,
    start: str = "2026-01-01",
    seed: int = 42,
    products: tuple[ProductProfile, ...] = DEFAULT_PRODUCTS,
) -> pd.DataFrame:
    """Hasilkan data transaksi mentah (satu baris = satu item terjual).

    Returns
    -------
    DataFrame dengan kolom:
        product_id, product_name, transaction_date, quantity, unit_price
    """
    rng = np.random.default_rng(seed)
    start_date = pd.Timestamp(start)
    dates = pd.date_range(start_date, periods=days, freq="D")

    rows: list[dict[str, object]] = []

    for product in products:
        # Hari libur/tutup: sekitar 4% hari tidak ada transaksi sama sekali.
        closed = rng.random(days) < 0.04

        for i, date in enumerate(dates):
            if closed[i]:
                continue

            factor = _WEEKDAY_FACTOR[date.weekday()]
            level = product.base_demand + product.trend_per_day * i
            expected = max(level * factor, 0.1)

            # Poisson menghasilkan bilangan bulat >= 0 yang cocok untuk
            # "jumlah barang terjual".
            quantity = int(rng.poisson(expected))
            if quantity == 0:
                continue

            rows.append(
                {
                    "product_id": product.product_id,
                    "product_name": product.name,
                    "transaction_date": date,
                    "quantity": quantity,
                    "unit_price": product.unit_price,
                }
            )

    frame = pd.DataFrame(rows)

    # Sisipkan beberapa baris retur (kuantitas negatif). Baris seperti ini
    # HARUS dibuang saat praproses, bukan dijumlahkan mentah-mentah.
    if not frame.empty:
        return_idx = rng.choice(frame.index, size=6, replace=False)
        frame.loc[return_idx, "quantity"] = -frame.loc[return_idx, "quantity"]

    return frame.sort_values(["product_id", "transaction_date"]).reset_index(drop=True)


def write_sample_csv(path, days: int = 180, seed: int = 42) -> "pd.DataFrame":
    """Tulis data contoh ke CSV lalu kembalikan isinya."""
    path.parent.mkdir(parents=True, exist_ok=True)
    frame = generate_sales(days=days, seed=seed)
    frame.to_csv(path, index=False)
    return frame
