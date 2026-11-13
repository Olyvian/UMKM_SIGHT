"""Entry point: jalankan pipeline dari terminal.

Contoh pemakaian:

    # 1. Pakai data simulasi bawaan
    python scripts/run_pipeline.py --regenerate

    # 2. Pakai file Excel milik sendiri
    python scripts/run_pipeline.py --data "D:/Data/penjualan_toko.xlsx"

    # 3. Atur horizon, stok, dan lead time
    python scripts/run_pipeline.py --data penjualan.xlsx --horizon 14 --stock 50 --lead-time 5

    # 4. Hanya satu produk tertentu
    python scripts/run_pipeline.py --data penjualan.xlsx --product "Kopi Sachet"
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

# Supaya `umkm_ml` bisa di-import tanpa perlu install package.
SRC_DIR = Path(__file__).resolve().parents[1] / "src"
if str(SRC_DIR) not in sys.path:
    sys.path.insert(0, str(SRC_DIR))

from umkm_ml import config  # noqa: E402
from umkm_ml.importer import DataImportError, load_user_data, summarize  # noqa: E402
from umkm_ml.pipeline import run  # noqa: E402


def _format_scores(scores: list[dict]) -> str:
    lines = []
    header = (
        f"    {'model':<16}{'MAE':>8}{'RMSE':>8}{'MAPE':>9}{'WAPE':>9}  catatan"
    )
    lines.append(header)
    lines.append("    " + "-" * (len(header) - 4))
    for score in scores:
        if not score["available"]:
            lines.append(
                f"    {score['model']:<16}{'-':>8}{'-':>8}{'-':>9}{'-':>9}  "
                f"tidak tersedia: {score['note']}"
            )
            continue
        mape = score["mape"]
        mape_text = "-" if mape is None else f"{mape * 100:.1f}%"
        wape = score.get("wape")
        wape_text = "-" if wape is None else f"{wape * 100:.1f}%"
        lines.append(
            f"    {score['model']:<16}{score['mae']:>8.2f}{score['rmse']:>8.2f}"
            f"{mape_text:>9}{wape_text:>9}  {score['description']}"
        )
    return "\n".join(lines)


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Pipeline peramalan permintaan UMKM Sight",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=(
            "Contoh:\n"
            '  python scripts/run_pipeline.py --data "data/raw/penjualan.xlsx"\n'
            "  python scripts/run_pipeline.py --horizon 14 --stock 50\n"
        ),
    )
    parser.add_argument(
        "--data",
        type=Path,
        default=None,
        help="File .xlsx/.xls/.csv milik sendiri. Kosongkan untuk data simulasi.",
    )
    parser.add_argument("--horizon", type=int, default=config.HORIZON_DAYS)
    parser.add_argument(
        "--stock",
        type=float,
        default=None,
        help=(
            "Stok saat ini. Kosongkan agar dibaca dari kolom stock_on_hand "
            "di data (bila ada), atau pakai asumsi default."
        ),
    )
    parser.add_argument(
        "--lead-time",
        type=int,
        default=None,
        help=(
            "Lead time pengadaan (hari). Kosongkan agar dibaca dari kolom "
            "lead_time_days di data (bila ada)."
        ),
    )
    parser.add_argument(
        "--eval-horizon",
        type=int,
        default=None,
        metavar="HARI",
        help=(
            "Berapa hari terakhir dipakai sebagai data uji "
            f"(default {config.EVAL_HORIZON_DAYS}). "
            "Jangan diisi 365: aplikasi hanya meramal 7 hari."
        ),
    )
    parser.add_argument(
        "--ignore-data-inventory",
        action="store_true",
        help="Abaikan kolom stok/lead time di data, pakai asumsi default.",
    )
    parser.add_argument(
        "--product",
        default=None,
        help="Hanya proses satu produk (berdasarkan ID atau nama).",
    )
    parser.add_argument(
        "--sheet",
        default=None,
        help="Nama sheet Excel yang dipakai (default: sheet pertama yang valid).",
    )
    parser.add_argument(
        "--regenerate",
        action="store_true",
        help="Buat ulang data simulasi (hanya bila --data tidak dipakai).",
    )
    parser.add_argument(
        "--inspect",
        action="store_true",
        help="Hanya tampilkan isi file data, tanpa menjalankan model.",
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=None,
        metavar="N",
        help=(
            "Proses hanya N produk dengan transaksi terbanyak. "
            "Berguna untuk file besar (mis. 70.000 baris)."
        ),
    )
    parser.add_argument(
        "--no-sarima",
        action="store_true",
        help=(
            "Lewati model SARIMA (paling lambat). Hasil kurang akurat, "
            "tapi jauh lebih cepat untuk data besar."
        ),
    )
    return parser


def main() -> int:
    parser = _build_parser()
    args = parser.parse_args()

    # --- Mode inspeksi: cek file dulu sebelum percaya hasilnya --------------
    if args.inspect:
        if args.data is None:
            print("Mode --inspect membutuhkan --data <file>.")
            return 2
        try:
            frame = load_user_data(args.data, sheet=args.sheet)
        except DataImportError as exc:
            print("GAGAL MEMBACA DATA:")
            print(exc)
            return 1
        print("=" * 78)
        print("ISI FILE DATA")
        print("=" * 78)
        print(f"File   : {args.data}")
        print(f"Sheet  : {frame.attrs.get('sheet', '-')}")
        print(f"Baris  : {len(frame)}")
        print(f"Produk : {frame['product_id'].nunique()} produk berbeda")
        if frame.attrs.get("dropped_rows"):
            print(f"Baris dibuang (tanggal/jumlah rusak): {frame.attrs['dropped_rows']}")
        print()
        print(summarize(frame))

        product_count = frame["product_id"].nunique()
        if product_count > 50:
            print()
            print(
                f"PERHATIAN: file ini punya {product_count} produk. "
                "Melatih SARIMA untuk semuanya bisa lama."
            )
            print(
                "Saran: uji dulu sebagian, mis. "
                "`--limit 10`, lalu lihat apakah kolom produk sudah benar."
            )

        print()
        print("Contoh 5 baris pertama:")
        print(frame.head(5).to_string(index=False))
        return 0

    # --- Mode normal --------------------------------------------------------
    product_ids = [args.product] if args.product else None

    def show_progress(message: str) -> None:
        print(message, flush=True)

    try:
        summary = run(
            data_path=args.data,
            regenerate_data=args.regenerate,
            horizon=args.horizon,
            current_stock=args.stock,
            lead_time_days=args.lead_time,
            product_ids=product_ids,
            sheet=args.sheet,
            limit=args.limit,
            progress=show_progress,
            skip_sarima=args.no_sarima,
            eval_horizon=args.eval_horizon,
            use_data_inventory=not args.ignore_data_inventory,
        )
    except DataImportError as exc:
        print("GAGAL MEMBACA DATA:")
        print(exc)
        print()
        print("Tips: jalankan dengan --inspect untuk melihat isi file,")
        print("atau pakai template: python scripts/make_template.py")
        return 1

    print("=" * 78)
    print("UMKM SIGHT - HASIL PIPELINE PERAMALAN")
    print("=" * 78)
    print(f"Sumber data : {summary['data_source']}")
    print(f"File        : {summary['data_file']}")
    print(
        f"Produk      : {summary['products_processed']} dari "
        f"{summary['total_products_in_file']} produk di file"
    )
    print(f"Horizon     : {summary['horizon_days']} hari")
    print(f"Uji akurasi : {summary['eval_horizon_days']} hari terakhir")
    assumptions = summary["assumptions"]
    stock_text = (
        f"{assumptions['current_stock']:.0f} unit"
        if assumptions["current_stock"] is not None
        else assumptions.get("current_stock_source", "-")
    )
    lead_text = (
        f"{assumptions['lead_time_days']} hari"
        if assumptions["lead_time_days"] is not None
        else assumptions.get("lead_time_source", "-")
    )
    print(f"Asumsi      : stok awal {stock_text}, lead time {lead_text}")
    if summary.get("dataset_summary"):
        print("Isi data    :")
        print(summary["dataset_summary"])

    age = summary.get("data_age_days")
    last = summary.get("data_last_date")
    if age is not None and age > 30:
        print()
        print("!" * 78)
        print("PERHATIAN: DATA SUDAH LAMA")
        print(f"  Transaksi terakhir di file: {last} ({age} hari lalu).")
        print("  Ramalan di bawah berlaku untuk periode SETELAH tanggal itu,")
        print("  bukan untuk hari ini. Untuk prediksi stok saat ini, pakai")
        print("  data penjualan yang terbaru.")
        print("!" * 78)

    for product in summary["products"]:
        print()
        print(f"--- Produk {product['product_id']} ---")
        if product["status"] != "ok":
            print(f"  STATUS: {product['status']}")
            print(f"  {product['message']}")
            continue

        prep = product["preprocessing"]
        print(
            f"  Praproses: {prep['raw_rows']} baris mentah -> "
            f"{prep['total_days']} hari "
            f"({prep['date_start']} s/d {prep['date_end']}); "
            f"retur dibuang {prep['dropped_returns']}, "
            f"hari kosong diisi 0 {prep['filled_zero_days']}"
        )
        print(f"  Model terbaik: {product['best_model']}")
        print(_format_scores(product["model_scores"]))

        horizon = product.get("accuracy_by_horizon") or {}
        if horizon:
            print("  Akurasi model terbaik menurut horizon:")
            for label, metrics in horizon.items():
                mape = metrics.get("mape")
                wape = metrics.get("wape")
                mape_text = "-" if mape is None else f"{mape * 100:.1f}%"
                wape_text = "-" if wape is None else f"{wape * 100:.1f}%"
                print(
                    f"    {label:<8} MAE {metrics['mae']:>7.2f}  "
                    f"MAPE {mape_text:>7}  WAPE {wape_text:>7}"
                )

        print("  Ramalan permintaan:")
        for point in product["forecast"]:
            print(f"    {point['date']}  {point['predicted_qty']:>7.2f}")

        stockout = product["stockout"]
        print(f"  Stok: {stockout['message']}")
        if stockout["should_alert"]:
            print("  >>> PERINGATAN RESTOCK: buat alert di aplikasi.")
        print(f"  Artefak: {', '.join(product['artifact_files'])}")

    print()
    print("=" * 78)
    print("Selesai. Buka folder artifacts/ untuk melihat JSON dan grafik.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
