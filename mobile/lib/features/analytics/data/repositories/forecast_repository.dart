import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/forecast_model.dart';

/// Kegagalan yang pesannya sudah siap ditampilkan ke pengguna.
class ForecastFailure implements Exception {
  const ForecastFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Sumber data fitur Analitik & Prediksi.
///
/// Semua query mengandalkan Row Level Security (RLS): data otomatis
/// tersaring ke toko milik pengguna yang login — tidak perlu filter
/// `store_id` manual.
///
/// Konvensi yang sama dengan [ProductRepository]:
///   - Lempar [ForecastFailure] untuk semua kegagalan yang bisa ditampilkan.
///   - Kode Supabase yang penting diterjemahkan ke pesan Indonesia.
class ForecastRepository {
  ForecastRepository({required SupabaseClient client}) : _client = client;

  final SupabaseClient _client;

  // -------------------------------------------------------------------------
  // Query utama
  // -------------------------------------------------------------------------

  /// Prediksi terbaru untuk satu produk, lengkap dengan detail harian
  /// dan metadata model.
  ///
  /// Mengembalikan `null` bila belum ada prediksi untuk produk ini.
  Future<Forecast?> fetchLatestForecast(String productId) async {
    try {
      final row = await _client
          .from('forecasts')
          .select(
            'id, product_id, horizon_days, days_until_stockout, '
            'avg_daily_demand, generated_at, '
            'ml_models ( id, name, version, algorithm, mape, rmse, mae, trained_at ), '
            'forecast_details ( forecast_date, predicted_qty, lower_bound, upper_bound )',
          )
          .eq('product_id', productId)
          .order('generated_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (row == null) return null;
      return Forecast.fromJson(row);
    } on PostgrestException catch (error) {
      throw _failure(error, 'Gagal memuat prediksi.');
    } on FormatException catch (error) {
      throw ForecastFailure('Data prediksi tidak sesuai: ${error.message}');
    }
  }

  /// Prediksi terbaru untuk **semua produk aktif** milik toko.
  ///
  /// Berguna untuk halaman ringkasan / daftar status stok semua produk.
  /// Detail harian (`forecast_details`) tidak dimuat agar query ringan.
  Future<List<Forecast>> fetchAllLatestForecasts() async {
    try {
      // Ambil forecast_id terbaru per produk via subquery lateral di
      // sisi Supabase: kita filter generated_at = MAX per product_id.
      // Cara paling mudah dengan PostgREST: ambil semua, lalu deduplikasi
      // di Dart — volume kecil (≤ ratusan produk) sehingga aman.
      final rows = await _client
          .from('forecasts')
          .select(
            'id, product_id, horizon_days, days_until_stockout, '
            'avg_daily_demand, generated_at, '
            'ml_models ( id, name, version, algorithm, mape, rmse, mae, trained_at )',
          )
          .order('generated_at', ascending: false);

      final forecasts = rows
          .map((e) => Forecast.fromJson(e))
          .toList();

      // Deduplikasi: ambil hanya yang terbaru per product_id.
      final Map<String, Forecast> latest = {};
      for (final f in forecasts) {
        final existing = latest[f.productId];
        if (existing == null ||
            f.generatedAt.isAfter(existing.generatedAt)) {
          latest[f.productId] = f;
        }
      }

      return latest.values.toList();
    } on PostgrestException catch (error) {
      throw _failure(error, 'Gagal memuat daftar prediksi.');
    } on FormatException catch (error) {
      throw ForecastFailure('Data prediksi tidak sesuai: ${error.message}');
    }
  }

  /// Mengambil data penjualan aktual harian untuk N hari ke belakang (default 7 hari).
  /// Mengembalikan list double panjang `days`, urut dari H-(days-1) sampai H-0 (hari ini).
  Future<List<double>> fetchRecentDailySales(
    String productId, {
    int days = 7,
  }) async {
    try {
      final now = DateTime.now();
      final startDate = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: days - 1));

      final rows = await _client
          .from('stock_movements')
          .select('quantity, created_at')
          .eq('product_id', productId)
          .eq('movement_type', 'OUT')
          .gte('created_at', startDate.toUtc().toIso8601String());

      final Map<String, double> dailyMap = {};
      for (final r in (rows as List)) {
        final dt = DateTime.parse(r['created_at'] as String).toLocal();
        final key =
            '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
        final qty = (r['quantity'] as num).toDouble();
        dailyMap[key] = (dailyMap[key] ?? 0.0) + qty;
      }

      final result = <double>[];
      for (var i = days - 1; i >= 0; i--) {
        final d = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
        final key =
            '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
        result.add(dailyMap[key] ?? 0.0);
      }
      return result;
    } catch (_) {
      return List.filled(days, 0.0);
    }
  }

  /// Riwayat prediksi untuk satu produk (tanpa detail harian), terbaru lebih
  /// dulu. Berguna untuk menunjukkan seberapa sering pipeline ML dijalankan.
  Future<List<Forecast>> fetchForecastHistory(
    String productId, {
    int limit = 10,
  }) async {
    try {
      final rows = await _client
          .from('forecasts')
          .select(
            'id, product_id, horizon_days, days_until_stockout, '
            'avg_daily_demand, generated_at, '
            'ml_models ( id, name, version, algorithm, mape, rmse, mae, trained_at )',
          )
          .eq('product_id', productId)
          .order('generated_at', ascending: false)
          .limit(limit);

      return rows
          .map((e) => Forecast.fromJson(e))
          .toList();
    } on PostgrestException catch (error) {
      throw _failure(error, 'Gagal memuat riwayat prediksi.');
    } on FormatException catch (error) {
      throw ForecastFailure('Data prediksi tidak sesuai: ${error.message}');
    }
  }

  // -------------------------------------------------------------------------
  // Kandidat restock (wrapper RPC restock_alert_candidates)
  // -------------------------------------------------------------------------

  /// Memanggil RPC `restock_alert_candidates` yang sudah ada di schema.sql.
  ///
  /// Mengembalikan daftar produk yang perlu restock segera beserta alasannya.
  /// [alertDays]  : berapa hari ke depan sebagai ambang peringatan (default 7).
  /// [maxAgeHours]: berapa jam prediksi dianggap masih segar (default 24).
  Future<List<Map<String, dynamic>>> fetchRestockCandidates({
    int alertDays = 7,
    int maxAgeHours = 24,
  }) async {
    try {
      final rows = await _client.rpc(
        'restock_alert_candidates',
        params: {
          'p_alert_days': alertDays,
          'p_max_age': '$maxAgeHours hours',
        },
      );
      return List<Map<String, dynamic>>.from(rows as List);
    } on PostgrestException catch (error) {
      throw _failure(error, 'Gagal memuat kandidat restock.');
    }
  }

  // -------------------------------------------------------------------------
  // Error helper (pola sama persis dengan ProductRepository)
  // -------------------------------------------------------------------------

  ForecastFailure _failure(PostgrestException error, String fallback) {
    // Skema belum dijalankan / fungsi tidak ditemukan.
    if (const {'42P01', '42883', 'PGRST202', 'PGRST205'}
        .contains(error.code)) {
      return const ForecastFailure(
        'Tabel prediksi belum tersedia. Jalankan schema.sql di Supabase '
        'SQL Editor.',
      );
    }
    // Akses ditolak RLS.
    if (error.code == '42501') {
      return const ForecastFailure(
        'Akses ditolak. Pastikan akun memiliki toko dan policy RLS sudah aktif.',
      );
    }
    return ForecastFailure('$fallback ${error.message}');
  }
}
