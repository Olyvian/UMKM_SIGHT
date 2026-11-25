/// Model data untuk fitur Analitik & Prediksi.
///
/// Mapping tabel Supabase:
///   ml_models       -> [MlModel]
///   forecasts       -> [Forecast]
///   forecast_details -> [ForecastDetail]
///
/// Satu [ForecastWithDetails] menggabungkan ketiganya menjadi satu objek
/// siap tampil — persis seperti [ProductOverview] menggabungkan products +
/// view product_overview.
library;

// ---------------------------------------------------------------------------
// MlModel
// ---------------------------------------------------------------------------

/// Informasi model ML yang menghasilkan prediksi.
/// Dibaca dari embed `ml_models(...)` di dalam query forecasts.
class MlModel {
  const MlModel({
    required this.id,
    required this.name,
    required this.version,
    required this.algorithm,
    this.mape,
    this.rmse,
    this.mae,
    this.trainedAt,
  });

  final String id;
  final String name;
  final String version;

  /// Nilai yang valid: 'DUMMY', 'MOVING_AVERAGE', 'ARIMA', 'SARIMA',
  /// 'PROPHET', 'LSTM' — sesuai constraint di schema.sql.
  final String algorithm;

  /// Metrik evaluasi (opsional; mungkin null bila model belum dievaluasi).
  final double? mape;
  final double? rmse;
  final double? mae;

  /// Waktu model selesai dilatih (UTC, bisa null bila belum dilatih).
  final DateTime? trainedAt;

  factory MlModel.fromJson(Map<String, dynamic> json) => MlModel(
        id: _str(json['id'], 'id'),
        name: _str(json['name'], 'name'),
        version: _str(json['version'], 'version'),
        algorithm: _str(json['algorithm'], 'algorithm'),
        mape: _nullableDouble(json['mape']),
        rmse: _nullableDouble(json['rmse']),
        mae: _nullableDouble(json['mae']),
        trainedAt: json['trained_at'] == null
            ? null
            : DateTime.parse(json['trained_at'] as String).toLocal(),
      );
}

// ---------------------------------------------------------------------------
// ForecastDetail
// ---------------------------------------------------------------------------

/// Satu titik prediksi harian — satu baris di tabel forecast_details.
class ForecastDetail {
  const ForecastDetail({
    required this.forecastDate,
    required this.predictedQty,
    this.lowerBound,
    this.upperBound,
  });

  final DateTime forecastDate;

  /// Kuantitas permintaan yang diprediksi (unit/hari).
  final double predictedQty;

  /// Batas bawah confidence interval (opsional, dari SARIMA get_forecast).
  final double? lowerBound;

  /// Batas atas confidence interval (opsional).
  final double? upperBound;

  factory ForecastDetail.fromJson(Map<String, dynamic> json) => ForecastDetail(
        forecastDate: DateTime.parse(_str(json['forecast_date'], 'forecast_date')),
        predictedQty: _double(json['predicted_qty'], 'predicted_qty'),
        lowerBound: _nullableDouble(json['lower_bound']),
        upperBound: _nullableDouble(json['upper_bound']),
      );
}

// ---------------------------------------------------------------------------
// Forecast (ringkasan)
// ---------------------------------------------------------------------------

/// Satu run prediksi — satu baris di tabel forecasts.
class Forecast {
  const Forecast({
    required this.id,
    required this.productId,
    required this.horizonDays,
    required this.generatedAt,
    this.daysUntilStockout,
    this.avgDailyDemand,
    this.mlModel,
    this.details,
  });

  final String id;
  final String productId;

  /// Jumlah hari ke depan yang diprediksi (7–30).
  final int horizonDays;

  /// Waktu pipeline ML dijalankan (waktu lokal).
  final DateTime generatedAt;

  /// Hari ke-N stok habis dihitung dari tanggal prediksi.
  /// - `0`    = stok sudah habis saat prediksi dibuat.
  /// - `null` = stok cukup sampai akhir horizon.
  final int? daysUntilStockout;

  /// Rata-rata permintaan harian dalam horizon (unit/hari).
  final double? avgDailyDemand;

  /// Metadata model yang menghasilkan prediksi ini.
  final MlModel? mlModel;

  /// Daftar titik prediksi harian, terurut dari yang paling awal.
  final List<ForecastDetail>? details;

  factory Forecast.fromJson(Map<String, dynamic> json) {
    // ml_models bisa berupa Map (bila di-embed) atau null.
    final modelJson = json['ml_models'] as Map<String, dynamic>?;

    // forecast_details berupa List<dynamic> (dari embed PostgREST).
    final detailsList = json['forecast_details'] as List<dynamic>?;

    return Forecast(
      id: _str(json['id'], 'id'),
      productId: _str(json['product_id'], 'product_id'),
      horizonDays: _int(json['horizon_days'], 'horizon_days'),
      generatedAt:
          DateTime.parse(_str(json['generated_at'], 'generated_at')).toLocal(),
      daysUntilStockout: json['days_until_stockout'] == null
          ? null
          : _int(json['days_until_stockout'], 'days_until_stockout'),
      avgDailyDemand: _nullableDouble(json['avg_daily_demand']),
      mlModel: modelJson == null ? null : MlModel.fromJson(modelJson),
      details: detailsList
          ?.map((e) => ForecastDetail.fromJson(e as Map<String, dynamic>))
          .toList()
        ?..sort((a, b) => a.forecastDate.compareTo(b.forecastDate)),
    );
  }

  // ---------------------------------------------------------------------------
  // Helper getter (dipakai langsung oleh UI tanpa kalkulasi tambahan)
  // ---------------------------------------------------------------------------

  /// Status ringkas stok: 'out_of_stock', 'will_run_out', atau 'sufficient'.
  String get stockoutStatus {
    if (daysUntilStockout == 0) return 'out_of_stock';
    if (daysUntilStockout != null) return 'will_run_out';
    return 'sufficient';
  }

  /// `true` bila prediksi ini dianggap segar (< 24 jam dari sekarang).
  bool get isFresh =>
      DateTime.now().difference(generatedAt).inHours < 24;

  /// Label status yang dapat dibaca pengguna.
  String get stockoutStatusLabel => switch (stockoutStatus) {
        'out_of_stock' => 'Stok Habis',
        'will_run_out' => 'Perlu Restock',
        _ => 'Stok Aman',
      };
}

// ---------------------------------------------------------------------------
// Private parsing helpers (konsisten dengan product_overview.dart)
// ---------------------------------------------------------------------------

String _str(Object? value, String field) {
  if (value is String) return value;
  throw FormatException('$field harus berupa teks, dapat: $value');
}

int _int(Object? value, String field) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) {
    final p = int.tryParse(value);
    if (p != null) return p;
  }
  throw FormatException('$field harus berupa bilangan bulat, dapat: $value');
}

double _double(Object? value, String field) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) {
    final p = double.tryParse(value);
    if (p != null) return p;
  }
  throw FormatException('$field harus berupa angka, dapat: $value');
}

double? _nullableDouble(Object? value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}
