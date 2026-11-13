import numpy as np
import pandas as pd
import pytest

from umkm_ml.importer import (
    DataImportError,
    load_user_data,
    product_row_counts,
    summarize,
)


def _write_csv(tmp_path, rows, header):
    path = tmp_path / "data.csv"
    frame = pd.DataFrame(rows, columns=header)
    frame.to_csv(path, index=False)
    return path


def test_kolom_bahasa_indonesia_dikenali(tmp_path):
    path = _write_csv(
        tmp_path,
        [
            ("2026-01-01", "Kopi Sachet", 5),
            ("2026-01-02", "Kopi Sachet", 6),
        ],
        ["Tanggal", "Produk", "Jumlah Terjual"],
    )

    frame = load_user_data(path)

    assert list(frame.columns) == [
        "transaction_date",
        "quantity",
        "product_name",
        "product_id",
    ]
    assert frame["quantity"].tolist() == [5, 6]
    assert frame["product_id"].iloc[0] == "Kopi Sachet"


def test_kolom_bahasa_inggris_dikenali(tmp_path):
    path = _write_csv(
        tmp_path,
        [("2026-01-01", "A", 3)],
        ["date", "product", "qty"],
    )

    frame = load_user_data(path)
    assert frame["quantity"].iloc[0] == 3


def test_tanpa_kolom_produk_dianggap_satu_produk(tmp_path):
    path = _write_csv(
        tmp_path,
        [("2026-01-01", 5), ("2026-01-02", 6)],
        ["Tanggal", "Jumlah"],
    )

    frame = load_user_data(path, default_product_name="Toko Berkah")
    assert frame["product_id"].nunique() == 1
    assert frame["product_id"].iloc[0] == "Toko Berkah"


def test_bentuk_tabel_lebar_tangani(tmp_path):
    # Tanggal di kolom pertama, nama produk jadi judul kolom.
    path = tmp_path / "wide.csv"
    pd.DataFrame(
        {
            "Tanggal": ["2026-01-01", "2026-01-02"],
            "Kopi Sachet": [5, 6],
            "Gula 1kg": [3, 2],
        }
    ).to_csv(path, index=False)

    frame = load_user_data(path)

    assert set(frame["product_id"].unique()) == {"Kopi Sachet", "Gula 1kg"}
    assert len(frame) == 4


def test_tanpa_kolom_tanggal_ditolak(tmp_path):
    path = _write_csv(tmp_path, [("Kopi", 5)], ["Produk", "Jumlah"])

    with pytest.raises(DataImportError, match="Kolom tanggal"):
        load_user_data(path)


def test_tanpa_kolom_jumlah_ditolak(tmp_path):
    path = _write_csv(
        tmp_path, [("2026-01-01", "Kopi")], ["Tanggal", "Produk"]
    )

    with pytest.raises(DataImportError, match="Kolom jumlah"):
        load_user_data(path)


def test_file_tidak_ada(tmp_path):
    with pytest.raises(DataImportError, match="tidak ditemukan"):
        load_user_data(tmp_path / "hilang.xlsx")


def test_excel_xlsx_terbaca(tmp_path):
    path = tmp_path / "data.xlsx"
    pd.DataFrame(
        {
            "Tanggal": ["2026-01-01", "2026-01-02"],
            "Produk": ["Kopi", "Kopi"],
            "Jumlah": [4, 7],
        }
    ).to_excel(path, index=False)

    frame = load_user_data(path)

    assert frame["quantity"].tolist() == [4, 7]
    assert frame["product_id"].iloc[0] == "Kopi"


def test_baris_tanggal_rusak_dibuang(tmp_path):
    path = _write_csv(
        tmp_path,
        [
            ("2026-01-01", "Kopi", 5),
            ("bukan tanggal", "Kopi", 9),
            ("2026-01-03", "Kopi", 4),
        ],
        ["Tanggal", "Produk", "Jumlah"],
    )

    frame = load_user_data(path)
    assert len(frame) == 2
    assert frame.attrs["dropped_rows"] == 1


def test_sheet_petunjuk_di_depan_dilewati(tmp_path):
    """File Excel dengan sheet petunjuk di depan tetap harus terbaca."""
    path = tmp_path / "multi.xlsx"
    with pd.ExcelWriter(path) as writer:
        pd.DataFrame({"Petunjuk": ["Isi data di sheet Transaksi"]}).to_excel(
            writer, sheet_name="Petunjuk", index=False
        )
        pd.DataFrame(
            {
                "Tanggal": ["2026-01-01", "2026-01-02"],
                "Produk": ["Kopi", "Kopi"],
                "Jumlah": [5, 6],
            }
        ).to_excel(writer, sheet_name="Transaksi", index=False)

    frame = load_user_data(path)

    assert frame.attrs["sheet"] == "Transaksi"
    assert frame["quantity"].tolist() == [5, 6]


def test_sheet_bisa_dipilih_manual(tmp_path):
    path = tmp_path / "multi.xlsx"
    with pd.ExcelWriter(path) as writer:
        pd.DataFrame(
            {
                "Tanggal": ["2026-01-01"],
                "Produk": ["Kopi"],
                "Jumlah": [5],
            }
        ).to_excel(writer, sheet_name="A", index=False)
        pd.DataFrame(
            {
                "Tanggal": ["2026-02-01", "2026-02-02"],
                "Produk": ["Teh", "Teh"],
                "Jumlah": [1, 2],
            }
        ).to_excel(writer, sheet_name="B", index=False)

    frame = load_user_data(path, sheet="B")

    assert frame.attrs["sheet"] == "B"
    assert frame["product_id"].unique().tolist() == ["Teh"]


def test_ringkasan_dibatasi_untuk_banyak_produk(tmp_path):
    """Data dengan banyak produk tidak boleh membanjiri terminal."""
    rows = [
        ("2026-01-01", f"Produk {i:03d}", 1) for i in range(40)
    ]
    path = _write_csv(tmp_path, rows, ["Tanggal", "Produk", "Jumlah"])

    frame = load_user_data(path)
    text = summarize(frame, max_products=10)

    assert text.count("baris transaksi") == 10
    assert "dan 30 produk lain" in text


def test_urutan_produk_berdasarkan_jumlah_baris(tmp_path):
    rows = [
        ("2026-01-01", "Sedikit", 1),
        ("2026-01-01", "Banyak", 1),
        ("2026-01-02", "Banyak", 1),
        ("2026-01-03", "Banyak", 1),
    ]
    path = _write_csv(tmp_path, rows, ["Tanggal", "Produk", "Jumlah"])

    frame = load_user_data(path)
    counts = product_row_counts(frame)

    assert counts[0] == ("Banyak", 3)


def test_id_produk_angka_tidak_diubah_jadi_teks():
    """Data simulasi memakai ID angka; jangan diubah jadi teks."""
    frame = pd.DataFrame(
        {
            "product_id": [1, 1, 2],
            "product_name": ["Kopi", "Kopi", "Gula"],
            "transaction_date": pd.to_datetime(
                ["2026-01-01", "2026-01-02", "2026-01-01"]
            ),
            "quantity": [5, 6, 3],
        }
    )

    counts = product_row_counts(frame)

    assert counts[0][0] == 1
    assert isinstance(counts[0][0], (int, np.integer))


def test_kategori_dan_merek_digabung_jadi_produk(tmp_path):
    """Dataset tanpa kolom produk: pakai Category + Brand."""
    path = _write_csv(
        tmp_path,
        [
            ("2026-01-01", "Snacks", "Nestle", 3),
            ("2026-01-02", "Snacks", "Nestle", 4),
            ("2026-01-01", "Dairy", "Amul", 5),
        ],
        ["Invoice_Date", "Category", "Brand", "Units"],
    )

    frame = load_user_data(path)

    assert set(frame["product_id"].unique()) == {"Snacks | Nestle", "Dairy | Amul"}
    assert sorted(frame["quantity"].tolist()) == [3, 4, 5]


def test_kolom_stok_opsional_ikut_terbaca(tmp_path):
    path = _write_csv(
        tmp_path,
        [
            ("2026-01-01", "Kopi", 5, 120, 30, 7),
            ("2026-01-02", "Kopi", 6, 114, 30, 7),
        ],
        [
            "Tanggal",
            "Produk",
            "Jumlah",
            "Stock_On_Hand",
            "Reorder_Level",
            "Lead_Time_Days",
        ],
    )

    frame = load_user_data(path)

    assert frame["stock_on_hand"].tolist() == [120, 114]
    assert frame["reorder_level"].tolist() == [30, 30]
    assert frame["lead_time_days"].tolist() == [7, 7]
