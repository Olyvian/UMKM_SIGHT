enum ProductStockStatus { outOfStock, restock, monitor, safe }

class ProductOverview {
  const ProductOverview({
    required this.id,
    required this.stockCode,
    required this.name,
    required this.unit,
    required this.unitPrice,
    required this.currentStock,
    required this.reorderThreshold,
    required this.isMonitored,
    required this.isActive,
    required this.status,
    this.category,
    this.daysUntilStockout,
    this.imagePath,
    this.imageUrl,
    this.imageError,
  });

  final String id;
  final String stockCode;
  final String name;
  final String unit;
  final double unitPrice;
  final int currentStock;
  final int reorderThreshold;
  final bool isMonitored;
  final bool isActive;
  final ProductStockStatus status;
  final String? category;
  final int? daysUntilStockout;
  final String? imagePath;
  final String? imageUrl;
  final String? imageError;

  ProductOverview copyWith({
    String? imageUrl,
    String? imageError,
  }) {
    return ProductOverview(
      id: id,
      stockCode: stockCode,
      name: name,
      unit: unit,
      unitPrice: unitPrice,
      currentStock: currentStock,
      reorderThreshold: reorderThreshold,
      isMonitored: isMonitored,
      isActive: isActive,
      status: status,
      category: category,
      daysUntilStockout: daysUntilStockout,
      imagePath: imagePath,
      imageUrl: imageUrl ?? this.imageUrl,
      imageError: imageError ?? this.imageError,
    );
  }

  factory ProductOverview.fromJson(Map<String, dynamic> json) {
    final status = switch (json['status']) {
      'HABIS' => ProductStockStatus.outOfStock,
      'RESTOCK' => ProductStockStatus.restock,
      'PANTAU' => ProductStockStatus.monitor,
      'AMAN' => ProductStockStatus.safe,
      final value => throw FormatException('Status produk tidak valid: $value'),
    };

    return ProductOverview(
      id: _stringValue(json['id'], 'id'),
      stockCode: _stringValue(json['stock_code'], 'stock_code'),
      name: _stringValue(json['name'], 'name'),
      unit: _stringValue(json['unit'], 'unit'),
      unitPrice: _numberValue(json['unit_price'], 'unit_price').toDouble(),
      currentStock: _intValue(json['current_stock'], 'current_stock'),
      reorderThreshold:
          _intValue(json['reorder_threshold'], 'reorder_threshold'),
      isMonitored: json['is_monitored'] is bool
          ? json['is_monitored'] as bool
          : throw const FormatException('is_monitored harus berupa boolean'),
      isActive: json['is_active'] is bool ? json['is_active'] as bool : true,
      status: status,
      category: _nullableStringValue(json['category'], 'category'),
      daysUntilStockout: json['days_until_stockout'] == null
          ? null
          : _intValue(json['days_until_stockout'], 'days_until_stockout'),
      imagePath: _nullableStringValue(json['image_path'], 'image_path'),
    );
  }
}

String _stringValue(Object? value, String field) {
  if (value is String) return value;
  throw FormatException('$field harus berupa teks');
}

String? _nullableStringValue(Object? value, String field) {
  if (value == null) return null;
  if (value is String) return value;
  throw FormatException('$field harus berupa teks atau null');
}

num _numberValue(Object? value, String field) {
  if (value is num) return value;
  if (value is String) {
    final parsed = num.tryParse(value);
    if (parsed != null) return parsed;
  }
  throw FormatException('$field harus berupa angka');
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
