"""Konstanta dan konfigurasi pipeline.

Semua angka "ajaib" (magic number) dikumpulkan di sini supaya mudah diubah
dan mudah dijelaskan saat presentasi. Jangan menyebar angka seperti 28 atau 7
ke dalam banyak file.
"""

from __future__ import annotations

from pathlib import Path

# ---------------------------------------------------------------------------
# Lokasi folder
# ---------------------------------------------------------------------------
# __file__ = ml-service/src/umkm_ml/config.py
# parents[0] = umkm_ml, parents[1] = src, parents[2] = ml-service
PROJECT_ROOT = Path(__file__).resolve().parents[2]

DATA_DIR = PROJECT_ROOT / "data"
RAW_DIR = DATA_DIR / "raw"
PROCESSED_DIR = DATA_DIR / "processed"
ARTIFACT_DIR = PROJECT_ROOT / "artifacts"

TEMPLATE_DIR = DATA_DIR / "templates"
TEMPLATE_XLSX = TEMPLATE_DIR / "template_transaksi.xlsx"

# ---------------------------------------------------------------------------
# Dataset default (dipakai bila `--data` tidak diisi)
# ---------------------------------------------------------------------------
# File penjualan: satu baris = satu baris transaksi ritel.
# Kolom yang dipakai: Transaction Date, Product No, Product Description,
# Qty Sold, Is Return.
DEFAULT_SALES_CSV = RAW_DIR / "retail_sales_ml_apl.csv"

# File snapshot stok. Berisi riwayat status stok per produk per toko; yang
# relevan hanya baris yang MASIH BERLAKU (End Date = INVENTORY_OPEN_END_DATE).
DEFAULT_INVENTORY_CSV = RAW_DIR / "retail_inventory_ml_apl.csv"

# Nilai End Date yang menandai "stok berlaku sampai waktu tak terbatas".
# Baris dengan tanggal ini = stok TERKINI. Tanggal lain = riwayat masa lalu.
# Jangan diganti dengan tanggal hari ini: nilai ini sengaja dipakai sebagai
# penanda baris terbuka oleh sistem sumber data.
INVENTORY_OPEN_END_DATE = "9999-12-31"

# Data simulasi. Hanya dipakai bila diminta eksplisit lewat `--regenerate`.
SYNTHETIC_SALES_CSV = RAW_DIR / "sales_sample.csv"

# Nama lama. Dipertahankan agar notebook/script lama tidak langsung rusak,
# tetapi sekarang menunjuk ke data SIMULASI, bukan dataset default.
RAW_SALES_CSV = SYNTHETIC_SALES_CSV

# ---------------------------------------------------------------------------
# Aturan data
# ---------------------------------------------------------------------------
# Minimal jumlah hari riwayat sebelum model boleh dipakai.
# Di bawah ini -> tampilkan "Data belum cukup untuk membuat prediksi"
# (PRD bagian 4.2), JANGAN mengarang angka.
MIN_HISTORY_DAYS = 28

# Horizon prediksi default (PRD menetapkan 7 hari untuk MVP).
HORIZON_DAYS = 7

# Horizon EVALUASI: berapa hari terakhir dipakai sebagai data uji.
#
# Kenapa tidak memakai "20% data terakhir" seperti sebelumnya?
# Pada data 5 tahun (1.826 hari), 20% berarti menguji model untuk 365 hari
# ke depan. Itu bukan tugas yang realistis: aplikasi hanya butuh 7 hari.
# Meramal 1 tahun ke depan hampir selalu terlihat buruk, lalu kesimpulannya
# salah ("model gagal") padahal penyebabnya cara evaluasi.
#
# Evaluasi sekarang memakai jendela yang sama dengan kebutuhan aplikasi,
# diperpanjang sedikit (28 hari) agar angkanya tidak bergantung pada satu
# minggu yang kebetulan ramai/sepi.
EVAL_HORIZON_DAYS = 28

# Proporsi data uji. Dipertahankan untuk kompatibilitas, tetapi TIDAK lagi
# dipakai sebagai default: lihat EVAL_HORIZON_DAYS di atas.
TEST_FRACTION = 0.2

# Minimal panjang data uji agar metrik tidak "kebetulan bagus".
MIN_TEST_DAYS = 7

# Musim mingguan: pola berulang tiap 7 hari (Senin..Minggu).
SEASONAL_PERIOD = 7

# Jendela moving average baseline.
MOVING_AVERAGE_WINDOW = 7

# ---------------------------------------------------------------------------
# Aturan bisnis stok (dipakai modul stockout)
# ---------------------------------------------------------------------------
# Stok contoh saat prediksi dibuat. Di aplikasi nyata nilainya datang dari
# kolom products.current_stock di database.
DEFAULT_CURRENT_STOCK = 20

# Lead time: perkiraan lama pengadaan barang (hari).
# Ini ASUMSI bisnis, bukan hasil model (PRD bagian 7.4).
DEFAULT_LEAD_TIME_DAYS = 3


def ensure_directories() -> None:
    """Buat folder yang dibutuhkan agar pipeline bisa langsung dijalankan."""
    for directory in (RAW_DIR, PROCESSED_DIR, ARTIFACT_DIR, TEMPLATE_DIR):
        directory.mkdir(parents=True, exist_ok=True)
