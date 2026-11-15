import '../../../products/data/models/product_overview.dart';

/// Angka ringkasan beranda, berasal dari view `store_summary` di Supabase.
class HomeSummary {
  const HomeSummary({
    required this.activeItems,
    required this.needRestock,
    required this.outOfStock,
  });

  /// Jumlah produk aktif (kolom `active_items`).
  final int activeItems;

  /// Produk yang perlu restock/dipantau (kolom `need_restock`).
  final int needRestock;

  /// Produk yang stoknya habis (kolom `out_of_stock`).
  final int outOfStock;

  factory HomeSummary.fromJson(Map<String, dynamic> json) => HomeSummary(
        activeItems: _intValue(json['active_items'], 'active_items'),
        needRestock: _intValue(json['need_restock'], 'need_restock'),
        outOfStock: _intValue(json['out_of_stock'], 'out_of_stock'),
      );
}

/// Satu baris mutasi stok untuk bagian "Aktivitas Terbaru".
class StockActivity {
  const StockActivity({
    required this.movementType,
    required this.quantity,
    required this.stockAfter,
    required this.createdAt,
    required this.productName,
    required this.unit,
  });

  /// "IN", "OUT", atau "ADJUSTMENT" (lihat tabel stock_movements).
  final String movementType;
  final int quantity;
  final int stockAfter;
  final DateTime createdAt;
  final String productName;
  final String unit;

  /// Label yang dibaca pengguna, mis. "Penjualan: 3 botol Minyak Goreng".
  String get label => switch (movementType) {
        'IN' => 'Stok Masuk',
        'OUT' => 'Penjualan',
        'ADJUSTMENT' => 'Koreksi stok',
        _ => movementType,
      };

  factory StockActivity.fromJson(Map<String, dynamic> json) {
    // Relasi products(...) diambil lewat embed PostgREST; bisa null bila
    // produk sudah dihapus permanen (FK stock_movements memakai RESTRICT,
    // jadi normalnya selalu ada).
    final product = json['products'] as Map<String, dynamic>?;

    return StockActivity(
      movementType: json['movement_type'] as String,
      quantity: _intValue(json['quantity'], 'quantity'),
      stockAfter: _intValue(json['stock_after'], 'stock_after'),
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      productName: (product?['name'] as String?) ?? 'Produk',
      unit: (product?['unit'] as String?) ?? '',
    );
  }
}

/// Seluruh data yang ditampilkan halaman Beranda dalam satu kali muat.
class HomeData {
  const HomeData({
    required this.summary,
    required this.attention,
    required this.activities,
  });

  final HomeSummary summary;

  /// Produk yang perlu perhatian (status selain "AMAN"), sudah diurutkan
  /// dari yang paling mendesak.
  final List<ProductOverview> attention;

  /// Mutasi stok terbaru, terbaru lebih dulu.
  final List<StockActivity> activities;
}

int _intValue(Object? value, String field) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) {
    final parsed = int.tryParse(value);
    if (parsed != null) return parsed;
  }
  throw FormatException('$field harus berupa bilangan bulat');
}
