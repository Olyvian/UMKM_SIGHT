"""Estimasi waktu stok habis.

Perhatikan: bagian ini BUKAN machine learning. ML hanya memberi angka
"permintaan harian". Perhitungan stok habis murni aritmatika kumulatif,
sesuai PRD 7.3:

    S0 = stok saat ini
    F(d) = prediksi permintaan hari ke-d
    stok habis pada hari pertama ketika jumlah F(1..k) >= S0
"""

from __future__ import annotations

from dataclasses import asdict, dataclass
from datetime import date, timedelta

from .config import DEFAULT_LEAD_TIME_DAYS

# Status yang mungkin dikembalikan
STATUS_OUT_OF_STOCK = "out_of_stock"
STATUS_WILL_RUN_OUT = "will_run_out"
STATUS_SUFFICIENT = "sufficient"
STATUS_NO_FORECAST = "no_forecast"


@dataclass
class StockoutEstimate:
    status: str
    days_until_stockout: int | None
    estimated_date: str | None
    current_stock: float
    lead_time_days: int
    should_alert: bool
    cumulative_demand: list[float]
    message: str

    def to_dict(self) -> dict:
        return asdict(self)


def estimate_stockout(
    daily_forecast: list[float] | tuple[float, ...],
    current_stock: float,
    start_date: date,
    lead_time_days: int = DEFAULT_LEAD_TIME_DAYS,
) -> StockoutEstimate:
    """Hitung kapan stok diperkirakan habis.

    Parameters
    ----------
    daily_forecast : prediksi permintaan per hari (hari ke-1, ke-2, ...).
    current_stock  : stok yang tersedia saat prediksi dibuat.
    start_date     : tanggal untuk prediksi hari ke-1.
    lead_time_days : ambang peringatan restock (asumsi bisnis).
    """
    forecast = [max(float(v), 0.0) for v in daily_forecast]

    # Stok sudah nol: tidak perlu menunggu model.
    if current_stock <= 0:
        return StockoutEstimate(
            status=STATUS_OUT_OF_STOCK,
            days_until_stockout=0,
            estimated_date=start_date.isoformat(),
            current_stock=current_stock,
            lead_time_days=lead_time_days,
            should_alert=True,
            cumulative_demand=[],
            message="Stok habis. Segera lakukan restock.",
        )

    cumulative: list[float] = []
    total = 0.0
    for value in forecast:
        total += value
        cumulative.append(round(total, 2))
        if total >= current_stock:
            days = len(cumulative)
            estimated = start_date + timedelta(days=days - 1)
            return StockoutEstimate(
                status=STATUS_WILL_RUN_OUT,
                days_until_stockout=days,
                estimated_date=estimated.isoformat(),
                current_stock=current_stock,
                lead_time_days=lead_time_days,
                should_alert=days <= lead_time_days,
                cumulative_demand=cumulative,
                message=(
                    f"Stok diperkirakan habis dalam {days} hari "
                    f"(sekitar {estimated.strftime('%d-%m-%Y')})."
                ),
            )

    # Permintaan kumulatif belum mencapai stok sampai akhir horizon.
    # JANGAN memaksakan tanggal habis (PRD 7.3).
    return StockoutEstimate(
        status=STATUS_SUFFICIENT,
        days_until_stockout=None,
        estimated_date=None,
        current_stock=current_stock,
        lead_time_days=lead_time_days,
        should_alert=False,
        cumulative_demand=cumulative,
        message=(
            f"Stok diperkirakan cukup selama horizon prediksi "
            f"({len(forecast)} hari ke depan)."
        ),
    )


def no_forecast_estimate(reason: str) -> StockoutEstimate:
    """Dipakai saat data tidak cukup / model gagal (PRD 4.2)."""
    return StockoutEstimate(
        status=STATUS_NO_FORECAST,
        days_until_stockout=None,
        estimated_date=None,
        current_stock=0.0,
        lead_time_days=DEFAULT_LEAD_TIME_DAYS,
        should_alert=False,
        cumulative_demand=[],
        message=f"Prediksi belum tersedia. {reason}",
    )
