import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umkm_sight/presentasion/widgets/stock_in_sheet.dart';

void main() {
  const products = [
    StockInProduct(
      id: 'p-beras',
      name: 'Beras Premium 5 kg',
      unit: 'karung',
      suggested: 15,
    ),
  ];

  Future<void> openSheet(
    WidgetTester tester,
    void Function(StockInResult?) onResult,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                onResult(
                  await showStockInSheet(context, products: products),
                );
              },
              child: const Text('Buka form'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Buka form'));
    await tester.pumpAndSettle();
  }

  testWidgets('mengembalikan produk beserta id-nya untuk disimpan',
      (tester) async {
    StockInResult? result;
    await openSheet(tester, (value) => result = value);

    // Nilai awal mengikuti saran prediksi (suggested).
    expect(find.text('15'), findsOneWidget);

    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(result?.product.id, 'p-beras');
    expect(result?.product.name, 'Beras Premium 5 kg');
    expect(result?.quantity, 15);
  });

  testWidgets('menolak jumlah nol', (tester) async {
    StockInResult? result;
    await openSheet(tester, (value) => result = value);

    await tester.enterText(find.byType(TextField), '0');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(find.text('Jumlah minimal 1'), findsOneWidget);
    expect(result, isNull);
  });
}
