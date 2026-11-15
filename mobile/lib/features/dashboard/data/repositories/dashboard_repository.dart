import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../products/data/models/product_overview.dart';
import '../models/home_data.dart';

/// Kegagalan yang pesannya sudah siap ditampilkan ke pengguna.
class DashboardFailure implements Exception {
  const DashboardFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Sumber data halaman Beranda.
///
/// Semua query mengandalkan Row Level Security: data otomatis tersaring
/// ke toko milik pengguna yang login (fungsi `my_store_id()` pada
/// supabase/schema_Inventoris.sql), jadi tidak perlu filter `store_id`.
class DashboardRepository {
  DashboardRepository({required SupabaseClient client}) : _client = client;

  final SupabaseClient _client;

  /// Batas jumlah kartu yang ditampilkan di tiap bagian beranda.
  static const _maxAttention = 5;
  static const _maxActivities = 5;

  Future<HomeData> fetchHome() async {
    try {
      // 1. Ringkasan: satu baris dari view store_summary.
      final summaryRow = await _client.from('store_summary').select().single();

      // 2. Produk yang perlu perhatian (status bukan AMAN).
      final attentionRows = await _client
          .from('product_overview')
          .select()
          .eq('is_active', true)
          .neq('status', 'AMAN')
          .limit(_maxAttention);

      // 3. Mutasi stok terbaru beserta nama & satuan produknya.
      final activityRows = await _client
          .from('stock_movements')
          .select(
            'movement_type, quantity, stock_after, created_at, '
            'products(name, unit)',
          )
          .order('created_at', ascending: false)
          .limit(_maxActivities);

      final attention = attentionRows.map(ProductOverview.fromJson).toList()
        ..sort(_byPriority);

      return HomeData(
        summary: HomeSummary.fromJson(summaryRow),
        attention: attention,
        activities: activityRows.map(StockActivity.fromJson).toList(),
      );
    } on PostgrestException catch (error) {
      throw _failure(error);
    } on FormatException catch (error) {
      throw DashboardFailure('Data beranda tidak sesuai: ${error.message}');
    }
  }

  /// Urutan prioritas: HABIS -> RESTOCK -> PANTAU, lalu yang paling cepat
  /// habis lebih dulu. `ProductStockStatus` dideklarasikan dengan urutan itu,
  /// sehingga `index` bisa dipakai langsung.
  static int _byPriority(ProductOverview a, ProductOverview b) {
    final byStatus = a.status.index.compareTo(b.status.index);
    if (byStatus != 0) return byStatus;
    return (a.daysUntilStockout ?? 999).compareTo(b.daysUntilStockout ?? 999);
  }

  DashboardFailure _failure(PostgrestException error) {
    if (const {'42P01', '42883', 'PGRST202', 'PGRST205'}
        .contains(error.code)) {
      return const DashboardFailure(
        'Skema beranda belum tersedia. Jalankan schema.sql lalu '
        'schema_Inventoris.sql di Supabase SQL Editor.',
      );
    }
    if (error.code == '42501') {
      return const DashboardFailure(
        'Akses ditolak. Pastikan akun memiliki toko dan policy RLS sudah aktif.',
      );
    }
    return DashboardFailure('Gagal memuat beranda: ${error.message}');
  }
}
