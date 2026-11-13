"""Orkestrasi pipeline end-to-end.

Satu kali jalan, pipeline melakukan:

    data mentah
      -> praproses (agregasi harian + isi hari kosong)
      -> split latih/uji berbasis waktu
      -> latih & nilai 4 model
      -> pilih model terbaik (MAE terkecil)
      -> latih ulang model terbaik pada SELURUH data
      -> ramalkan horizon (default 7 hari)
      -> hitung estimasi stok habis
      -> simpan artefak (JSON + gambar + model)

Artefak inilah yang nanti dikirim backend Laravel ke aplikasi Flutter.
"""

from __future__ import annotations

import json
import pickle
from dataclasses import asdict, dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Callable

import pandas as pd

from . import config
from .evaluate import EvaluationResult, evaluate_models, horizon_report
from .importer import load_user_data, product_row_counts, summarize
from .models import create_model, default_models
from .preprocessing import (
    InsufficientDataError,
    PreprocessReport,
    build_daily_series,
    load_sales_csv,
)
from .stockout import StockoutEstimate, estimate_stockout, no_forecast_estimate
from .synthetic_data import write_sample_csv

DATA_SOURCE_LABEL = (
    "Data simulasi (synthetic_data.py). Bukan data transaksi UMKM nyata."
)


def _rel(path: Path) -> str:
    """Path relatif terhadap root proyek (fallback ke path absolut)."""
    try:
        return str(path.relative_to(config.PROJECT_ROOT))
    except ValueError:
        return str(path)


@dataclass
class ProductResult:
    """Ringkasan hasil untuk satu produk."""

    product_id: int | str
    status: str  # "ok" | "insufficient_data"
    message: str
    preprocessing: PreprocessReport | None = None
    best_model: str | None = None
    model_scores: list[dict] = field(default_factory=list)
    accuracy_by_horizon: dict[str, dict] = field(default_factory=dict)
    forecast: list[dict] = field(default_factory=list)
    stockout: StockoutEstimate | None = None
    artifact_files: list[str] = field(default_factory=list)

    def to_dict(self) -> dict:
        return {
            "product_id": self.product_id,
            "status": self.status,
            "message": self.message,
            "preprocessing": self.preprocessing.to_dict()
            if self.preprocessing
            else None,
            "best_model": self.best_model,
            "model_scores": self.model_scores,
            "accuracy_by_horizon": self.accuracy_by_horizon,
            "forecast": self.forecast,
            "stockout": self.stockout.to_dict() if self.stockout else None,
            "artifact_files": self.artifact_files,
        }


def load_dataset(
    data_path: Path | str | None = None,
    regenerate: bool = False,
    sheet: int | str | None = None,
) -> tuple[pd.DataFrame, str]:
    """Muat data dan kembalikan (DataFrame mentah, label sumber data).

    - `data_path` diisi  -> baca file Excel/CSV milik pengguna.
    - `data_path` kosong -> pakai data simulasi bawaan.
    """
    if data_path is None:
        csv_path = config.RAW_SALES_CSV
        if regenerate or not csv_path.exists():
            write_sample_csv(csv_path)
        return load_sales_csv(csv_path), DATA_SOURCE_LABEL

    path = Path(data_path).expanduser().resolve()
    frame = load_user_data(path, sheet=sheet)
    used_sheet = frame.attrs.get("sheet")
    label = f"Data pengguna: {path.name}"
    if used_sheet not in (None, 0):
        label += f" (sheet: {used_sheet})"
    return frame, label


def _score_to_dict(score) -> dict:
    return {
        "model": score.name,
        "description": score.description,
        "available": score.available,
        "mae": None if score.mae is None else round(score.mae, 4),
        "rmse": None if score.rmse is None else round(score.rmse, 4),
        "mape": None if score.mape is None else round(score.mape, 4),
        "wape": None if score.wape is None else round(score.wape, 4),
        "zero_ratio": None
        if score.zero_ratio is None
        else round(score.zero_ratio, 4),
        "note": score.note,
    }


def _save_plot(
    path: Path,
    product_id: int | str,
    evaluation: EvaluationResult,
    future_dates: pd.DatetimeIndex,
    future_values,
    stockout: StockoutEstimate,
) -> None:
    """Gambar aktual vs prediksi + proyeksi stok. Disimpan sebagai PNG."""
    import matplotlib

    matplotlib.use("Agg")  # backend tanpa jendela, aman untuk server/CI
    import matplotlib.pyplot as plt

    fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(11, 8))

    # --- Panel 1: data aktual + prediksi tiap model pada data uji ----------
    ax1.plot(
        evaluation.train.index,
        evaluation.train.values,
        label="Aktual (latih)",
        color="#94A3B8",
        linewidth=1.2,
    )
    ax1.plot(
        evaluation.test.index,
        evaluation.test.values,
        label="Aktual (uji)",
        color="#0F172A",
        linewidth=1.6,
    )
    colors = ["#DC2626", "#2563EB", "#16A34A", "#F59E0B"]
    for color, score in zip(colors, evaluation.scores):
        if not score.available or score.predictions is None:
            continue
        ax1.plot(
            evaluation.test.index,
            score.predictions,
            linestyle="--",
            linewidth=1.3,
            color=color,
            label=f"{score.name} (MAE {score.mae:.2f})",
        )
    ax1.set_title(f"Produk {product_id} - Aktual vs Prediksi (data uji)")
    ax1.set_ylabel("Kuantitas terjual")
    ax1.legend(fontsize=8, ncol=2)
    ax1.grid(alpha=0.25)

    # --- Panel 2: proyeksi permintaan kumulatif vs stok --------------------
    cumulative = stockout.cumulative_demand
    if cumulative:
        ax2.plot(
            future_dates[: len(cumulative)],
            cumulative,
            marker="o",
            color="#2563EB",
            label="Permintaan kumulatif (prediksi)",
        )
        ax2.axhline(
            stockout.current_stock,
            color="#DC2626",
            linestyle=":",
            label=f"Stok saat ini ({stockout.current_stock:.0f})",
        )
    else:
        ax2.plot(future_dates, future_values, marker="o", color="#2563EB")
    ax2.set_title(f"Produk {product_id} - {stockout.message}")
    ax2.set_xlabel("Tanggal")
    ax2.set_ylabel("Kuantitas")
    ax2.legend(fontsize=8)
    ax2.grid(alpha=0.25)

    fig.autofmt_xdate()
    fig.tight_layout()
    fig.savefig(path, dpi=130)
    plt.close(fig)


def _safe_slug(value: object) -> str:
    """Ubah ID produk menjadi nama file yang aman (tanpa spasi/simbol)."""
    text = str(value).strip().lower()
    allowed = []
    for char in text:
        if char.isalnum():
            allowed.append(char)
        elif char in {" ", "-", "_", "/", "."}:
            allowed.append("_")
    slug = "".join(allowed).strip("_")
    while "__" in slug:
        slug = slug.replace("__", "_")
    return slug or "produk"


def run_product(
    raw: pd.DataFrame,
    product_id: int | str,
    horizon: int = config.HORIZON_DAYS,
    current_stock: float = config.DEFAULT_CURRENT_STOCK,
    lead_time_days: int = config.DEFAULT_LEAD_TIME_DAYS,
    artifact_dir: Path | None = None,
    models: list | None = None,
    eval_horizon: int | None = None,
) -> ProductResult:
    """Jalankan seluruh pipeline untuk satu produk."""
    artifact_dir = artifact_dir or config.ARTIFACT_DIR

    # --- 1. Praproses ------------------------------------------------------
    try:
        series, report = build_daily_series(raw, product_id)
    except InsufficientDataError as exc:
        estimate = no_forecast_estimate(str(exc))
        return ProductResult(
            product_id=product_id,
            status="insufficient_data",
            message=str(exc),
            stockout=estimate,
        )

    # --- 2. Evaluasi model ------------------------------------------------
    evaluation = evaluate_models(
        series, models=models, test_days=eval_horizon
    )

    # --- 3. Latih ulang model terbaik pada seluruh data -------------------
    best_model = create_model(evaluation.best_name).fit(series)
    future_values = best_model.forecast(horizon)

    last_date = series.index.max()
    future_dates = pd.date_range(
        last_date + pd.Timedelta(days=1), periods=horizon, freq="D"
    )

    # --- 4. Estimasi stok habis -------------------------------------------
    stockout = estimate_stockout(
        daily_forecast=list(future_values),
        current_stock=current_stock,
        start_date=future_dates[0].date(),
        lead_time_days=lead_time_days,
    )

    # --- 5. Simpan artefak -------------------------------------------------
    artifact_dir.mkdir(parents=True, exist_ok=True)
    prefix = artifact_dir / f"product_{_safe_slug(product_id)}"
    files: list[str] = []

    metrics_path = prefix.with_name(prefix.name + "_metrics.json")
    metrics_payload = {
        "product_id": product_id,
        "preprocessing": report.to_dict(),
        "split": {
            "train_days": len(evaluation.train),
            "test_days": len(evaluation.test),
            "train_start": evaluation.train.index.min().date().isoformat(),
            "train_end": evaluation.train.index.max().date().isoformat(),
            "test_start": evaluation.test.index.min().date().isoformat(),
            "test_end": evaluation.test.index.max().date().isoformat(),
        },
        "models": [_score_to_dict(s) for s in evaluation.scores],
        "best_model": evaluation.best_name,
        "accuracy_by_horizon": horizon_report(evaluation),
    }
    metrics_path.write_text(json.dumps(metrics_payload, indent=2), encoding="utf-8")
    files.append(_rel(metrics_path))

    forecast_path = prefix.with_name(prefix.name + "_forecast.json")
    forecast_payload = {
        "product_id": product_id,
        "model": evaluation.best_name,
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "horizon_days": horizon,
        "history_last_date": last_date.date().isoformat(),
        "predictions": [
            {"date": d.date().isoformat(), "predicted_qty": round(float(v), 3)}
            for d, v in zip(future_dates, future_values)
        ],
        "stockout": stockout.to_dict(),
    }
    forecast_path.write_text(json.dumps(forecast_payload, indent=2), encoding="utf-8")
    files.append(_rel(forecast_path))

    model_path = prefix.with_name(prefix.name + "_model.pkl")
    try:
        with model_path.open("wb") as handle:
            pickle.dump(best_model, handle)
        files.append(_rel(model_path))
    except Exception:  # noqa: BLE001 - model tidak wajib untuk demo
        pass

    plot_path = prefix.with_name(prefix.name + "_report.png")
    try:
        _save_plot(
            plot_path,
            product_id,
            evaluation,
            future_dates,
            future_values,
            stockout,
        )
        files.append(_rel(plot_path))
    except Exception:  # noqa: BLE001 - grafik hanya pelengkap
        pass

    return ProductResult(
        product_id=product_id,
        status="ok",
        message=f"Prediksi {horizon} hari dibuat dengan model {evaluation.best_name}.",
        preprocessing=report,
        best_model=evaluation.best_name,
        model_scores=[_score_to_dict(s) for s in evaluation.scores],
        accuracy_by_horizon=horizon_report(evaluation),
        forecast=[
            {"date": d.date().isoformat(), "predicted_qty": round(float(v), 3)}
            for d, v in zip(future_dates, future_values)
        ],
        stockout=stockout,
        artifact_files=files,
    )


def _data_last_date(raw: pd.DataFrame) -> str | None:
    """Tanggal transaksi terakhir di data, dalam format ISO."""
    dates = pd.to_datetime(raw["transaction_date"], errors="coerce")
    if dates.notna().any():
        return dates.max().date().isoformat()
    return None


def _data_age_days(raw: pd.DataFrame) -> int | None:
    """Berapa hari umur data terakhir dibanding hari ini.

    Data yang berakhir bertahun-tahun lalu tetap bisa diolah, tetapi
    ramalannya berlaku untuk periode SETELAH tanggal terakhir itu, bukan
    untuk hari ini. Angka ini dipakai untuk memperingatkan pengguna.
    """
    last = _data_last_date(raw)
    if last is None:
        return None
    delta = datetime.now(timezone.utc).date() - datetime.fromisoformat(last).date()
    return int(delta.days)


def _inventory_from_raw(raw: pd.DataFrame) -> dict[object, dict[str, float]]:
    """Ambil stok & lead time per produk dari kolom opsional di data.

    Beberapa file menyimpan `stock_on_hand` / `reorder_level` /
    `lead_time_days` (mis. dataset FMCG). Bila ada, lebih baik memakai angka
    nyata itu daripada asumsi default 20 unit dan 3 hari.

    Nilai diambil dari baris TERAKHIR tiap produk, karena stok berubah tiap
    transaksi dan yang relevan adalah kondisi terkini.
    """
    info: dict[object, dict[str, float]] = {}
    wanted = {
        "stock_on_hand": "stock",
        "lead_time_days": "lead_time",
        "reorder_level": "reorder_level",
    }
    present = {col: key for col, key in wanted.items() if col in raw.columns}
    if not present:
        return info

    ordered = raw.sort_values("transaction_date")
    for pid, group in ordered.groupby("product_id"):
        values: dict[str, float] = {}
        for col, key in present.items():
            series = pd.to_numeric(group[col], errors="coerce").dropna()
            if not series.empty:
                values[key] = float(series.iloc[-1])
        if values:
            info[pid] = values
    return info


def run(
    data_path: Path | str | None = None,
    regenerate_data: bool = False,
    horizon: int = config.HORIZON_DAYS,
    current_stock: float | None = None,
    lead_time_days: int | None = None,
    product_ids: list[int | str] | None = None,
    sheet: int | str | None = None,
    limit: int | None = None,
    progress: Callable[[str], None] | None = None,
    skip_sarima: bool = False,
    eval_horizon: int | None = None,
    use_data_inventory: bool = True,
) -> dict:
    """Jalankan pipeline untuk semua produk yang ada di data.

    `data_path` boleh .xlsx / .xls / .csv milik pengguna. Bila None,
    pipeline memakai data simulasi bawaan.

    `limit` membatasi jumlah produk yang diproses (diambil dari produk
    dengan transaksi terbanyak). Berguna untuk data besar: melatih SARIMA
    butuh waktu, jadi sebaiknya uji beberapa produk dulu.

    `progress` adalah callback opsional untuk menampilkan kemajuan; tanpa
    ini, pemrosesan ratusan produk akan terlihat seperti terminal macet.

    `skip_sarima` melewati model SARIMA dan hanya memakai 3 baseline.
    Hasilnya kurang akurat, tetapi jauh lebih cepat pada data besar.

    `eval_horizon` = berapa hari terakhir dipakai sebagai data uji
    (default EVAL_HORIZON_DAYS). Jangan diisi angka besar: aplikasi hanya
    meramal 7 hari, jadi menguji 365 hari tidak relevan.

    `current_stock` / `lead_time_days` boleh None. Bila None, pipeline
    mencoba memakai kolom stok & lead time dari data (lihat
    `_inventory_from_raw`), lalu jatuh ke asumsi default.
    """
    config.ensure_directories()
    raw, source_label = load_dataset(
        data_path, regenerate=regenerate_data, sheet=sheet
    )

    inventory = _inventory_from_raw(raw) if use_data_inventory else {}

    if product_ids is None:
        # Urutkan dari produk dengan transaksi terbanyak, supaya `limit`
        # mengambil produk yang paling penting lebih dulu.
        product_ids = [pid for pid, _ in product_row_counts(raw)]

    if limit is not None:
        product_ids = product_ids[: max(limit, 0)]

    total = len(product_ids)
    results = []
    for index, pid in enumerate(product_ids, start=1):
        if progress is not None:
            progress(f"[{index}/{total}] memproses produk: {pid}")
        if skip_sarima:
            # Kedua varian SARIMA jauh lebih lambat daripada 3 baseline.
            # Untuk data besar, ini opsi "cepat" agar hasil awal bisa dilihat.
            candidates = [
                m for m in default_models() if not m.name.startswith("sarima")
            ]
        else:
            candidates = None

        per_product = inventory.get(pid, {})
        stock = current_stock
        if stock is None:
            stock = per_product.get("stock", config.DEFAULT_CURRENT_STOCK)
        lead = lead_time_days
        if lead is None:
            lead = per_product.get("lead_time", config.DEFAULT_LEAD_TIME_DAYS)

        results.append(
            run_product(
                raw,
                pid,
                horizon=horizon,
                current_stock=float(stock),
                lead_time_days=int(round(lead)),
                models=candidates,
                eval_horizon=eval_horizon,
            )
        )

    stock_source = (
        "dari data (kolom stock_on_hand)"
        if current_stock is None and inventory
        else f"asumsi {config.DEFAULT_CURRENT_STOCK:.0f} unit"
    )
    lead_source = (
        "dari data (kolom lead_time_days)"
        if lead_time_days is None and any("lead_time" in v for v in inventory.values())
        else f"asumsi {config.DEFAULT_LEAD_TIME_DAYS} hari"
    )

    summary = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "data_source": source_label,
        "data_file": _rel(Path(data_path)) if data_path else _rel(config.RAW_SALES_CSV),
        "dataset_summary": summarize(raw),
        "total_products_in_file": int(raw["product_id"].nunique()),
        "products_processed": total,
        "sarima_enabled": not skip_sarima,
        "data_last_date": _data_last_date(raw),
        "data_age_days": _data_age_days(raw),
        "horizon_days": horizon,
        "eval_horizon_days": eval_horizon or config.EVAL_HORIZON_DAYS,
        "assumptions": {
            "current_stock": current_stock,
            "lead_time_days": lead_time_days,
            "current_stock_source": stock_source,
            "lead_time_source": lead_source,
        },
        "products": [r.to_dict() for r in results],
    }

    summary_path = config.ARTIFACT_DIR / "pipeline_summary.json"
    summary_path.write_text(json.dumps(summary, indent=2), encoding="utf-8")
    return summary