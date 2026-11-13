"""Pembaca data dari Excel / CSV milik pengguna.

Modul ini menjembatani "file Excel apa adanya" dengan format yang dibutuhkan
pipeline (`product_id`, `transaction_date`, `quantity`).

Masalah nyata di lapangan:
  - Nama kolom berbahasa Indonesia ("Tanggal", "Jumlah Terjual", "Produk").
  - Kadang satu sheet berisi beberapa produk sekaligus.
  - Kadang bentuknya tabel lebar: tanggal di kolom pertama, nama produk
    menjadi judul kolom.
  - Kadang tidak ada kolom produk sama sekali (satu file = satu produk).

Modul ini menangani ketiga bentuk tersebut secara otomatis.
"""

from __future__ import annotations

from pathlib import Path

import pandas as pd

# ---------------------------------------------------------------------------
# Kamus nama kolom. Kunci = nama baku yang dipakai pipeline,
# nilai = kemungkinan nama di file pengguna (huruf kecil, tanpa spasi ganda).
# ---------------------------------------------------------------------------
COLUMN_ALIASES: dict[str, tuple[str, ...]] = {
    "transaction_date": (
        "transaction_date",
        "tanggal",
        "tgl",
        "date",
        "waktu",
        "tanggal transaksi",
        "tanggal_transaksi",
        "tgl transaksi",
        "datetime",
        "periode",
    ),
    "quantity": (
        "quantity",
        "qty",
        "jumlah",
        "jumlah terjual",
        "jumlah_terjual",
        "kuantitas",
        "terjual",
        "total terjual",
        "total_terjual",
        "total qty",
        "total_qty",
        "jumlah penjualan",
        "penjualan",
        "unit",
        "pcs",
    ),
    "product_id": (
        "product_id",
        "produk_id",
        "id produk",
        "id_produk",
        "kode produk",
        "kode_produk",
        "sku",
        "product",
        "produk",
        "item",
        "item_id",
    ),
    "product_name": (
        "product_name",
        "nama produk",
        "nama_produk",
        "nama",
        "produk",
        "product",
        "item",
        "barang",
        "nama barang",
        "nama_barang",
    ),
    # Beberapa dataset tidak punya kolom produk tunggal, melainkan
    # kategori + merek. Keduanya digabung menjadi identitas produk.
    "category": (
        "category",
        "kategori",
        "kategori produk",
        "product_categories",
        "product_category",
        "jenis",
        "jenis produk",
    ),
    "brand": (
        "brand",
        "merek",
        "merk",
        "brand_name",
        "nama merek",
    ),
}

# Kolom opsional untuk perhitungan stok. Bila ada di file, pipeline memakai
# angka nyata ini alih-alih asumsi default.
OPTIONAL_ALIASES: dict[str, tuple[str, ...]] = {
    "stock_on_hand": (
        "stock_on_hand",
        "stok",
        "stok_tersedia",
        "sisa_stok",
        "persediaan",
        "stock",
        "inventory",
    ),
    "reorder_level": (
        "reorder_level",
        "titik_reorder",
        "stok_minimum",
        "minimum_stock",
        "rop",
    ),
    "lead_time_days": (
        "lead_time_days",
        "lead_time",
        "lead_time_hari",
        "waktu_pengiriman",
        "waktu_lead_time",
    ),
}


class DataImportError(ValueError):
    """File pengguna tidak bisa dibaca atau kolomnya tidak dikenali."""


def _normalize_header(value: object) -> str:
    """Rapikan judul kolom: huruf kecil, garis bawah, tanpa spasi berlebih."""
    text = str(value).strip().lower()
    for char in ("\n", "\r", "\t"):
        text = text.replace(char, " ")
    text = " ".join(text.split())
    return text


def _find_column(columns: list[str], target: str) -> str | None:
    """Cari kolom yang cocok untuk `target` berdasarkan kamus alias."""
    return _match_any(columns, COLUMN_ALIASES[target])


def _match_any(columns: list[str], aliases: tuple[str, ...]) -> str | None:
    """Cari kolom pertama yang cocok dengan salah satu alias."""
    # 1. Cocok persis
    for alias in aliases:
        if alias in columns:
            return alias
    # 2. Cocok sebagian (mis. "tanggal transaksi (wib)")
    for alias in aliases:
        for column in columns:
            if alias in column:
                return column
    return None


def read_table(path: Path | str, sheet_name: int | str = 0) -> pd.DataFrame:
    """Baca file .xlsx / .xls / .csv menjadi DataFrame mentah."""
    path = Path(path)
    if not path.exists():
        raise DataImportError(f"File tidak ditemukan: {path}")

    suffix = path.suffix.lower()
    try:
        if suffix in {".xlsx", ".xlsm", ".xls"}:
            frame = pd.read_excel(path, sheet_name=sheet_name)
        elif suffix == ".csv":
            # Coba UTF-8 dulu, lalu fallback ke encoding Excel Indonesia.
            try:
                frame = pd.read_csv(path, encoding="utf-8")
            except UnicodeDecodeError:
                frame = pd.read_csv(path, encoding="latin-1")
        else:
            raise DataImportError(
                f"Format '{suffix}' belum didukung. Gunakan .xlsx, .xls, atau .csv."
            )
    except DataImportError:
        raise
    except Exception as exc:  # noqa: BLE001
        raise DataImportError(f"Gagal membaca {path.name}: {exc}") from exc

    if frame.empty:
        raise DataImportError(f"File {path.name} kosong (tidak ada baris data).")

    # Buang baris & kolom yang seluruhnya kosong (sisa format Excel).
    frame = frame.dropna(how="all").dropna(axis=1, how="all")
    return frame


def list_sheets(path: Path | str) -> list[str]:
    """Daftar nama sheet pada file Excel. Kosong untuk CSV."""
    path = Path(path)
    if path.suffix.lower() not in {".xlsx", ".xlsm", ".xls"}:
        return []
    try:
        from openpyxl import load_workbook

        workbook = load_workbook(path, read_only=True)
        names = list(workbook.sheetnames)
        workbook.close()
        return names
    except Exception:  # noqa: BLE001
        return []


def _from_wide_format(frame: pd.DataFrame) -> pd.DataFrame | None:
    """Tangani tabel lebar: kolom pertama tanggal, sisanya nama produk.

    Contoh:
        Tanggal | Kopi Sachet | Gula 1kg
        2026-01-01 | 5 | 3
        2026-01-02 | 6 | 2

    Mengembalikan None bila tabel tidak berbentuk seperti ini.
    """
    if frame.shape[1] < 2:
        return None

    first = frame.columns[0]
    rest = list(frame.columns[1:])
    if not rest:
        return None

    # Semua kolom selain pertama harus numerik.
    for column in rest:
        if not pd.api.types.is_numeric_dtype(frame[column]):
            converted = pd.to_numeric(frame[column], errors="coerce")
            if converted.notna().mean() < 0.8:
                return None
            frame[column] = converted

    # Kolom pertama harus bisa dibaca sebagai tanggal.
    dates = pd.to_datetime(frame[first], errors="coerce")
    if dates.notna().mean() < 0.8:
        return None

    long = frame.melt(
        id_vars=[first],
        value_vars=rest,
        var_name="product_name",
        value_name="quantity",
    ).rename(columns={first: "transaction_date"})
    long = long.dropna(subset=["quantity"])
    long["product_id"] = long["product_name"]
    return long


def _parse_frame(
    original: pd.DataFrame,
    default_product_name: str | None = None,
) -> pd.DataFrame:
    """Ubah satu DataFrame (satu sheet) ke format baku pipeline."""
    normalized = original.copy()
    normalized.columns = [_normalize_header(c) for c in normalized.columns]

    columns = list(normalized.columns)
    date_col = _find_column(columns, "transaction_date")
    qty_col = _find_column(columns, "quantity")
    pid_col = _find_column(columns, "product_id")
    name_col = _find_column(columns, "product_name")

    if date_col is not None and qty_col is not None:
        # --- Format panjang: ada kolom tanggal DAN kolom jumlah -----------
        result = pd.DataFrame(
            {
                "transaction_date": normalized[date_col],
                "quantity": normalized[qty_col],
            }
        )
        if name_col is not None and name_col != date_col:
            result["product_name"] = normalized[name_col]
        if pid_col is not None and pid_col != date_col:
            result["product_id"] = normalized[pid_col]
        elif name_col is not None and name_col != date_col:
            result["product_id"] = normalized[name_col]
        else:
            # Beberapa dataset hanya punya kategori + merek (tanpa kolom
            # produk). Gabungkan keduanya menjadi identitas produk.
            cat_col = _find_column(columns, "category")
            brand_col = _find_column(columns, "brand")
            if cat_col is not None and brand_col is not None:
                combined = (
                    normalized[cat_col].astype(str)
                    + " | "
                    + normalized[brand_col].astype(str)
                )
                result["product_id"] = combined
                result["product_name"] = combined
            elif cat_col is not None:
                result["product_id"] = normalized[cat_col]
                result["product_name"] = normalized[cat_col]
    else:
        # --- Coba format lebar: tanggal + satu kolom per produk -----------
        # Dipakai frame asli agar nama produk tidak berubah huruf kecil.
        wide = _from_wide_format(original)
        if wide is not None:
            result = wide
        elif date_col is None:
            raise DataImportError(
                "Kolom tanggal tidak ditemukan.\n"
                f"Kolom yang terbaca: {', '.join(map(str, original.columns))}\n"
                "Beri nama kolom tanggal: Tanggal / Date / transaction_date."
            )
        else:
            raise DataImportError(
                "Kolom jumlah penjualan tidak ditemukan.\n"
                f"Kolom yang terbaca: {', '.join(map(str, original.columns))}\n"
                "Beri nama kolom jumlah: Jumlah / Qty / Quantity."
            )

    # Produk tidak disebutkan -> seluruh file dianggap satu produk.
    if "product_id" not in result.columns:
        fallback = default_product_name or "produk_1"
        result["product_id"] = fallback
        result["product_name"] = fallback
    if "product_name" not in result.columns:
        result["product_name"] = result["product_id"]

    # --- Kolom stok opsional (bila ada di file) ----------------------------
    # Disimpan apa adanya supaya pipeline bisa memakai stok & lead time nyata
    # alih-alih asumsi default.
    for target, aliases in OPTIONAL_ALIASES.items():
        column = _match_any(columns, aliases)
        if column is not None:
            result[target] = pd.to_numeric(normalized[column], errors="coerce")

    # --- Bersihkan tipe data ------------------------------------------------
    result["transaction_date"] = pd.to_datetime(
        result["transaction_date"], errors="coerce", dayfirst=False
    )
    result["quantity"] = pd.to_numeric(result["quantity"], errors="coerce")

    invalid = result["transaction_date"].isna() | result["quantity"].isna()
    dropped = int(invalid.sum())
    result = result.loc[~invalid].copy()

    if result.empty:
        raise DataImportError(
            "Tidak ada baris valid. Pastikan kolom tanggal berisi tanggal "
            "sungguhan dan kolom jumlah berisi angka."
        )

    result["product_id"] = result["product_id"].astype(str)
    result["product_name"] = result["product_name"].astype(str)
    result = result.sort_values(["product_id", "transaction_date"])
    result = result.reset_index(drop=True)
    result.attrs["dropped_rows"] = dropped
    return result


def load_user_data(
    path: Path | str,
    default_product_name: str | None = None,
    sheet: int | str | None = None,
) -> pd.DataFrame:
    """Baca file pengguna dan ubah ke format baku pipeline.

    Bila `sheet` tidak ditentukan, semua sheet dicoba berurutan dan sheet
    pertama yang kolomnya dikenali yang dipakai. Ini membuat file yang punya
    sheet "Petunjuk" di depan tetap terbaca.

    Returns
    -------
    DataFrame dengan kolom: product_id, product_name, transaction_date, quantity
    """
    path = Path(path)
    sheets = list_sheets(path)

    if sheet is not None:
        candidates: list[int | str] = [sheet]
    elif sheets:
        candidates = sheets
    else:
        candidates = [0]

    errors: list[str] = []
    for candidate in candidates:
        try:
            original = read_table(path, sheet_name=candidate)
        except DataImportError as exc:
            errors.append(f"[{candidate}] {exc}")
            continue
        try:
            frame = _parse_frame(original, default_product_name)
        except DataImportError as exc:
            errors.append(f"[{candidate}] {exc}")
            continue
        frame.attrs["sheet"] = candidate
        return frame

    if len(candidates) == 1:
        raise DataImportError(errors[0].split("] ", 1)[-1])

    detail = "\n".join(f"  - {message}" for message in errors)
    raise DataImportError(
        "Tidak ada sheet yang bisa dibaca.\n"
        f"Sheet yang dicoba: {', '.join(map(str, candidates))}\n"
        f"Alasan per sheet:\n{detail}"
    )


def summarize(frame: pd.DataFrame, max_products: int = 20) -> str:
    """Ringkasan singkat isi data pengguna, untuk ditampilkan ke terminal.

    `max_products` membatasi jumlah produk yang dicetak. Tanpa batas, file
    70.000 baris dengan ribuan produk akan membanjiri terminal (dan membuat
    file ringkasan JSON membengkak). Produk terbesar ditampilkan lebih dulu
    karena biasanya itu yang paling penting.
    """
    grouped = sorted(
        frame.groupby("product_id"), key=lambda pair: len(pair[1]), reverse=True
    )
    lines = []
    for product_id, group in grouped[:max_products]:
        name = group["product_name"].iloc[0]
        # Data simulasi (CSV) masih menyimpan tanggal sebagai teks,
        # sedangkan data pengguna sudah datetime. Samakan dulu.
        dates = pd.to_datetime(group["transaction_date"], errors="coerce")
        if dates.notna().any():
            start = dates.min().date()
            end = dates.max().date()
            span_text = f"{start} s/d {end} ({(end - start).days + 1} hari kalender)"
        else:
            span_text = "tanggal tidak terbaca"
        lines.append(
            f"  - {product_id} ({name}): {len(group)} baris transaksi, "
            f"{span_text}, "
            f"total qty {group['quantity'].sum():.0f}"
        )
    hidden = len(grouped) - len(lines)
    if hidden > 0:
        lines.append(f"  ... dan {hidden} produk lain (tidak ditampilkan).")
    return "\n".join(lines)


def product_row_counts(frame: pd.DataFrame) -> list[tuple[object, int]]:
    """Daftar (product_id, jumlah baris), terbesar dulu.

    Tipe product_id dipertahankan apa adanya: data simulasi memakai angka,
    data pengguna memakai teks. Mengubahnya menjadi teks akan membuat
    pencocokan produk gagal di tahap praproses.
    """
    counts = frame.groupby("product_id").size()
    return sorted(
        ((pid, int(n)) for pid, n in counts.items()),
        key=lambda item: item[1],
        reverse=True,
    )
