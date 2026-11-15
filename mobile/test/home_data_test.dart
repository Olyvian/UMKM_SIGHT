import 'package:flutter_test/flutter_test.dart';
import 'package:umkm_sight/features/dashboard/data/models/home_data.dart';

void main() {
  group('HomeSummary.fromJson', () {
    test('membaca kolom view store_summary', () {
      final summary = HomeSummary.fromJson(const {
        'active_items': 48,
        'need_restock': 3,
        'out_of_stock': 1,
      });

      expect(summary.activeItems, 48);
      expect(summary.needRestock, 3);
      expect(summary.outOfStock, 1);
    });

    test('menerima angka berbentuk teks (numeric dari PostgREST)', () {
      final summary = HomeSummary.fromJson(const {
        'active_items': '12',
        'need_restock': '2',
        'out_of_stock': '0',
      });

      expect(summary.activeItems, 12);
      expect(summary.needRestock, 2);
      expect(summary.outOfStock, 0);
    });

    test('menolak nilai yang bukan angka', () {
      expect(
        () => HomeSummary.fromJson(const {
          'active_items': 'banyak',
          'need_restock': 0,
          'out_of_stock': 0,
        }),
        throwsFormatException,
      );
    });
  });

  group('StockActivity.fromJson', () {
    test('memetakan mutasi keluar beserta produk yang di-embed', () {
      final activity = StockActivity.fromJson(const {
        'movement_type': 'OUT',
        'quantity': 3,
        'stock_after': 0,
        'created_at': '2026-04-06T02:30:00+00:00',
        'products': {'name': 'Minyak Goreng Sania 2L', 'unit': 'botol'},
      });

      expect(activity.label, 'Penjualan');
      expect(activity.quantity, 3);
      expect(activity.stockAfter, 0);
      expect(activity.productName, 'Minyak Goreng Sania 2L');
      expect(activity.unit, 'botol');
      expect(activity.createdAt.isUtc, isFalse);
    });

    test('memetakan mutasi masuk dan koreksi stok', () {
      StockActivity build(String type) => StockActivity.fromJson({
            'movement_type': type,
            'quantity': 20,
            'stock_after': 29,
            'created_at': '2026-04-05T07:15:00+00:00',
            'products': {'name': 'Gula Pasir 1 kg', 'unit': 'kg'},
          });

      expect(build('IN').label, 'Stok Masuk');
      expect(build('ADJUSTMENT').label, 'Koreksi stok');
    });

    test('tetap aman bila relasi produk tidak ikut terkirim', () {
      final activity = StockActivity.fromJson(const {
        'movement_type': 'IN',
        'quantity': 5,
        'stock_after': 5,
        'created_at': '2026-04-05T07:15:00+00:00',
      });

      expect(activity.productName, 'Produk');
      expect(activity.unit, '');
    });
  });
}
