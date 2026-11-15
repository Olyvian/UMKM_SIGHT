import 'package:flutter_test/flutter_test.dart';
import 'package:umkm_sight/features/products/data/models/product_overview.dart';

void main() {
  group('ProductOverview.fromJson', () {
    test('maps inventory view rows and database statuses', () {
      final product = ProductOverview.fromJson({
        'id': 'product-id',
        'stock_code': 'BRS-5KG-04',
        'name': 'Beras Premium',
        'category': 'Sembako',
        'unit': 'karung',
        'unit_price': 75000,
        'current_stock': 4,
        'reorder_threshold': 6,
        'is_monitored': true,
        'is_active': true,
        'days_until_stockout': 2,
        'status': 'RESTOCK',
        'image_path': 'user-id/product-id/image',
      });

      expect(product.id, 'product-id');
      expect(product.stockCode, 'BRS-5KG-04');
      expect(product.unitPrice, 75000);
      expect(product.currentStock, 4);
      expect(product.category, 'Sembako');
      expect(product.daysUntilStockout, 2);
      expect(product.imagePath, 'user-id/product-id/image');
      expect(product.isActive, isTrue);
      expect(product.status, ProductStockStatus.restock);
    });

    test('maps archived product state', () {
      final product = ProductOverview.fromJson({
        'id': 'product-id',
        'stock_code': 'SKU-01',
        'name': 'Produk arsip',
        'unit': 'pcs',
        'unit_price': 0,
        'current_stock': 0,
        'reorder_threshold': 0,
        'is_monitored': false,
        'is_active': false,
        'status': 'HABIS',
      });

      expect(product.isActive, isFalse);
    });

    test('keeps forecast fields nullable when no forecast exists', () {
      final product = ProductOverview.fromJson({
        'id': 'product-id',
        'stock_code': 'SKU-01',
        'name': 'Produk',
        'category': null,
        'unit': 'pcs',
        'unit_price': 0.0,
        'current_stock': 0,
        'reorder_threshold': 0,
        'is_monitored': false,
        'days_until_stockout': null,
        'status': 'HABIS',
      });

      expect(product.category, isNull);
      expect(product.daysUntilStockout, isNull);
      expect(product.imagePath, isNull);
      expect(product.status, ProductStockStatus.outOfStock);
    });
  });
}
