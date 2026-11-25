/// Satu baris riwayat mutasi stok dari tabel `stock_movements` (OUT / IN).
class StockMovementItem {
  const StockMovementItem({
    required this.id,
    required this.invoiceNo,
    required this.productName,
    required this.unit,
    required this.movementType,
    required this.quantity,
    required this.stockBefore,
    required this.stockAfter,
    required this.createdAt,
    this.note,
  });

  final String id;
  final String? invoiceNo;
  final String productName;
  final String unit;
  final String movementType; // 'OUT' | 'IN' | 'ADJUSTMENT'
  final int quantity;
  final int stockBefore;
  final int stockAfter;
  final DateTime createdAt;
  final String? note;

  bool get isOut => movementType == 'OUT';
  bool get isIn => movementType == 'IN';

  /// Nomor referensi yang ramah dibaca di UI (pakai invoice_no bila ada).
  String get displayRef {
    final inv = invoiceNo?.trim();
    if (inv != null && inv.isNotEmpty) return inv;
    final short = id.length >= 8 ? id.substring(0, 8).toUpperCase() : id;
    return 'MOV-$short';
  }

  factory StockMovementItem.fromJson(Map<String, dynamic> json) {
    final product = json['products'] as Map<String, dynamic>?;
    final transaction = json['transactions'] as Map<String, dynamic>?;
    final rawDate = json['created_at'] as String?;
    final parsedDate = rawDate != null
        ? DateTime.parse(rawDate).toLocal()
        : DateTime.now();

    return StockMovementItem(
      id: (json['id'] as String?) ?? '',
      invoiceNo: transaction?['invoice_no'] as String?,
      productName: (product?['name'] as String?) ?? 'Produk tidak diketahui',
      unit: (product?['unit'] as String?) ?? 'pcs',
      movementType: (json['movement_type'] as String?) ?? 'OUT',
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      stockBefore: (json['stock_before'] as num?)?.toInt() ?? 0,
      stockAfter: (json['stock_after'] as num?)?.toInt() ?? 0,
      createdAt: parsedDate,
      note: json['note'] as String?,
    );
  }
}
