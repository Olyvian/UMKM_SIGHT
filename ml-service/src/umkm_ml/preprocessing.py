"""Praproses: dari data transaksi mentah menjadi deret waktu harian.

Ini langkah yang paling sering diremehkan, padahal paling menentukan.
Model yang bagus tetap akan salah kalau datanya salah bentuk.

Alur:
    transaksi mentah (bisa banyak baris per hari)
        -> buang retur / kuantitas tidak valid
        -> jumlahkan per tanggal          (agregasi harian)
        -> lengkapi tanggal yang bolong   (isi 0)
        -> periksa kecukupan data
        -> pd.Series siap dipakai model
"""

from __future__ import annotations

from dataclasses import asdict, dataclass
from pathlib import Path

import pandas as pd

from .config import MIN_HISTORY_DAYS

REQUIRED_COLUMNS = ("product_id", "transaction_date", "quantity")


class InsufficientDataError(ValueError):
    """Dilempar saat riwayat terlalu pendek untuk membuat prediksi.

    Dipakai untuk memenuhi PRD 4.2: sistem TIDAK boleh menampilkan angka
    prediksi seolah-olah valid ketika data belum cukup.
    """


@dataclass
class PreprocessReport:
    """Catatan apa saja yang dilakukan saat praproses.

    Disimpan bersama artefak supaya bisa ditunjukkan saat presentasi:
    "dari 300 baris mentah, 6 dibuang karena retur, 12 hari kosong diisi 0".
    """

    product_id: int | str
    raw_rows: int
    dropped_returns: int
    dropped_invalid: int
    observed_days: int
    filled_zero_days: int
    total_days: int
    date_start: str
    date_end: str

    def to_dict(self) -> dict:
        return asdict(self)


def load_sales_csv(path: Path | str) -> pd.DataFrame:
    """Baca data transaksi dari CSV."""
    frame = pd.read_csv(path)
    missing = [c for c in REQUIRED_COLUMNS if c not in frame.columns]
    if missing:
        raise ValueError(
            f"CSV tidak memiliki kolom wajib: {', '.join(missing)}. "
            f"Kolom yang ada: {', '.join(map(str, frame.columns))}"
        )
    return frame


def build_daily_series(
    raw: pd.DataFrame,
    product_id: int | str,
    min_days: int = MIN_HISTORY_DAYS,
    extend_to: str | pd.Timestamp | None = None,
) -> tuple[pd.Series, PreprocessReport]:
    """Ubah transaksi mentah satu produk menjadi deret harian tanpa lubang.

    Parameters
    ----------
    raw : DataFrame transaksi (kolom: product_id, transaction_date, quantity).
    product_id : produk yang ingin diproses.
    min_days : minimal jumlah hari riwayat yang dianggap layak.
    extend_to : opsional, perpanjang deret sampai tanggal ini (mis. hari ini)
        dengan nilai 0. Pada data simulasi kita biarkan None agar rentangnya
        sama dengan data yang benar-benar ada.

    Returns
    -------
    (series, report) dengan index DatetimeIndex harian dan nilai float.

    Raises
    ------
    InsufficientDataError bila data tidak cukup / kosong.
    """
    missing = [c for c in REQUIRED_COLUMNS if c not in raw.columns]
    if missing:
        raise ValueError(f"Kolom wajib tidak ada: {', '.join(missing)}")

    rows = raw[raw["product_id"] == product_id].copy()
    if rows.empty:
        # Jaga-jaga bila ID dikirim sebagai teks ("1") sementara data
        # menyimpan angka (1), atau sebaliknya.
        rows = raw[raw["product_id"].astype(str) == str(product_id)].copy()
    raw_rows = len(rows)

    if raw_rows == 0:
        raise InsufficientDataError(
            f"Tidak ada transaksi untuk produk {product_id}."
        )

    # --- 1. Bersihkan -------------------------------------------------------
    rows["transaction_date"] = pd.to_datetime(
        rows["transaction_date"], errors="coerce"
    )
    rows["quantity"] = pd.to_numeric(rows["quantity"], errors="coerce")

    invalid_mask = rows["transaction_date"].isna() | rows["quantity"].isna()
    dropped_invalid = int(invalid_mask.sum())
    rows = rows.loc[~invalid_mask]

    # Retur / pembatalan: kuantitas negatif. Untuk permintaan (demand) kita
    # hanya peduli barang yang benar-benar keluar, jadi baris ini dibuang.
    returns_mask = rows["quantity"] < 0
    dropped_returns = int(returns_mask.sum())
    rows = rows.loc[~returns_mask]

    # Hari dengan kuantitas 0 tidak menambah informasi; ikut dibuang lalu
    # tanggalnya akan muncul lagi sebagai 0 saat reindex di langkah 3.
    rows = rows.loc[rows["quantity"] > 0]

    if rows.empty:
        raise InsufficientDataError(
            f"Semua baris produk {product_id} tidak valid setelah dibersihkan."
        )

    # --- 2. Agregasi harian -------------------------------------------------
    daily = rows.groupby(rows["transaction_date"].dt.normalize())["quantity"].sum()
    daily = daily.sort_index()

    # --- 3. Lengkapi tanggal yang bolong -----------------------------------
    # Ini kuncinya: hari tanpa penjualan harus bernilai 0, BUKAN hilang.
    start = daily.index.min()
    end = daily.index.max()
    if extend_to is not None:
        end = max(end, pd.Timestamp(extend_to).normalize())

    full_index = pd.date_range(start, end, freq="D")
    observed_days = len(daily)
    daily = daily.reindex(full_index, fill_value=0).astype(float)
    filled_zero_days = len(full_index) - observed_days

    # --- 4. Periksa kecukupan data -----------------------------------------
    if len(daily) < min_days:
        raise InsufficientDataError(
            f"Data produk {product_id} hanya {len(daily)} hari, "
            f"minimal {min_days} hari untuk membuat prediksi."
        )

    report = PreprocessReport(
        product_id=product_id,
        raw_rows=raw_rows,
        dropped_returns=dropped_returns,
        dropped_invalid=dropped_invalid,
        observed_days=observed_days,
        filled_zero_days=filled_zero_days,
        total_days=len(daily),
        date_start=start.date().isoformat(),
        date_end=end.date().isoformat(),
    )
    daily.name = "quantity"
    return daily, report
