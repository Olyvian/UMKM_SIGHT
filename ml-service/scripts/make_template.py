"""Buat template Excel kosong yang siap diisi data penjualan sendiri.

Jalankan:
    python scripts/make_template.py

Hasil: data/templates/template_transaksi.xlsx
"""

from __future__ import annotations

import sys
from datetime import date, timedelta
from pathlib import Path

SRC_DIR = Path(__file__).resolve().parents[1] / "src"
if str(SRC_DIR) not in sys.path:
    sys.path.insert(0, str(SRC_DIR))

from umkm_ml import config  # noqa: E402

INSTRUCTIONS = [
    ["PETUNJUK PENGISIAN TEMPLATE UMKM SIGHT"],
    [""],
    ["Isi data pada sheet 'Transaksi'. Jangan mengubah nama kolom."],
    [""],
    ["Kolom yang wajib ada:"],
    ["  Tanggal          : tanggal transaksi, format YYYY-MM-DD (mis. 2026-11-01)"],
    ["  Produk           : nama atau kode produk (boleh diulang)"],
    ["  Jumlah Terjual   : jumlah barang yang laku pada tanggal itu (angka bulat)"],
    [""],
    ["Aturan penting:"],
    ["  1. Satu baris = satu transaksi. Boleh beberapa baris di tanggal yang sama."],
    ["  2. JANGAN menghapus hari yang tidak ada penjualan."],
    ["     Kosongkan saja; pipeline otomatis menganggapnya 0."],
    ["  3. Minimal 28 hari riwayat per produk agar bisa diprediksi."],
    ["  4. Retur / pembatalan: tulis angka negatif. Pipeline akan membuangnya."],
    ["  5. Urutan baris bebas, pipeline akan mengurutkan sendiri."],
    [""],
    ["Cara menjalankan:"],
    ['  python scripts/run_pipeline.py --data "data/raw/file_anda.xlsx"'],
    [""],
    ["Cek dulu isi file sebelum diproses:"],
    ['  python scripts/run_pipeline.py --data "data/raw/file_anda.xlsx" --inspect'],
]

EXAMPLE_ROWS = [
    ["2026-10-01", "Kopi Sachet", 5],
    ["2026-10-02", "Kopi Sachet", 6],
    ["2026-10-03", "Kopi Sachet", 4],
    ["2026-10-01", "Gula Pasir 1kg", 3],
    ["2026-10-02", "Gula Pasir 1kg", 2],
    ["2026-10-03", "Gula Pasir 1kg", -1],  # contoh retur
]


def main() -> int:
    config.ensure_directories()
    path = config.TEMPLATE_XLSX

    try:
        import pandas as pd
        from openpyxl import Workbook
        from openpyxl.styles import Alignment, Font, PatternFill
        from openpyxl.utils import get_column_letter
    except ImportError as exc:
        print(f"Perlu pandas + openpyxl: {exc}")
        return 1

    workbook = Workbook()

    # --- Sheet petunjuk -----------------------------------------------------
    sheet = workbook.active
    sheet.title = "Petunjuk"
    for row in INSTRUCTIONS:
        sheet.append(row)
    sheet["A1"].font = Font(bold=True, size=14)
    sheet.column_dimensions["A"].width = 95
    for cell in sheet["A"]:
        cell.alignment = Alignment(wrap_text=False, vertical="center")

    # --- Sheet transaksi ----------------------------------------------------
    data_sheet = workbook.create_sheet("Transaksi")
    headers = ["Tanggal", "Produk", "Jumlah Terjual"]
    data_sheet.append(headers)

    header_fill = PatternFill("solid", fgColor="2563EB")
    for index, _ in enumerate(headers, start=1):
        cell = data_sheet.cell(row=1, column=index)
        cell.font = Font(bold=True, color="FFFFFF")
        cell.fill = header_fill
        cell.alignment = Alignment(horizontal="center")

    for row in EXAMPLE_ROWS:
        data_sheet.append(row)

    data_sheet.column_dimensions["A"].width = 16
    data_sheet.column_dimensions["B"].width = 26
    data_sheet.column_dimensions["C"].width = 18
    data_sheet.freeze_panes = "A2"

    # --- Sheet contoh terisi penuh (opsional, untuk uji cepat) --------------
    demo_sheet = workbook.create_sheet("Contoh 60 Hari")
    demo_sheet.append(headers)
    for index, _ in enumerate(headers, start=1):
        cell = demo_sheet.cell(row=1, column=index)
        cell.font = Font(bold=True, color="FFFFFF")
        cell.fill = header_fill
        cell.alignment = Alignment(horizontal="center")

    start = date(2026, 9, 1)
    import random

    rng = random.Random(7)
    for day in range(60):
        current = start + timedelta(days=day)
        for product, base in (("Kopi Sachet", 6), ("Gula Pasir 1kg", 3)):
            quantity = max(0, rng.randint(base - 2, base + 4))
            if quantity:
                demo_sheet.append([current.isoformat(), product, quantity])
    demo_sheet.column_dimensions["A"].width = 16
    demo_sheet.column_dimensions["B"].width = 26
    demo_sheet.column_dimensions["C"].width = 18
    demo_sheet.freeze_panes = "A2"

    workbook.save(path)
    print(f"Template dibuat: {path}")
    print()
    print("Langkah berikutnya:")
    print(f"  1. Buka file tersebut, isi sheet 'Transaksi' dengan data Anda.")
    print(f'  2. Cek isinya : python scripts/run_pipeline.py --data "{path}" --inspect')
    print(f'  3. Jalankan   : python scripts/run_pipeline.py --data "{path}"')
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
