import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umkm_sight/presentasion/widgets/sale_entry_sheet.dart';

void main() {
  const products = [
    SaleEntryProduct(
      name: 'Beras Premium 5 kg',
      unit: 'karung',
      availableStock: 4,
    ),
  ];

  testWidgets('menolak jumlah nol dan jumlah melebihi stok', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showSaleEntrySheet(context, products: products),
              child: const Text('Buka form'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Buka form'));
    await tester.pumpAndSettle();

    final quantityField = find.byType(TextFormField);
    await tester.enterText(quantityField, '0');
    await tester.tap(find.text('Simpan & Catat Penjualan'));
    await tester.pumpAndSettle();
    expect(find.text('Jumlah harus minimal 1 karung.'), findsOneWidget);

    await tester.enterText(quantityField, '5');
    await tester.tap(find.text('Simpan & Catat Penjualan'));
    await tester.pumpAndSettle();
    expect(find.text('Stok tersedia hanya 4 karung.'), findsOneWidget);
  });

  testWidgets('mengembalikan detail transaksi yang sudah divalidasi',
      (tester) async {
    SaleEntryResult? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showSaleEntrySheet(context, products: products);
              },
              child: const Text('Buka form'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Buka form'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '2');
    await tester.tap(find.text('Simpan & Catat Penjualan'));
    await tester.pumpAndSettle();

    expect(result?.product.name, 'Beras Premium 5 kg');
    expect(result?.quantity, 2);
  });
}
