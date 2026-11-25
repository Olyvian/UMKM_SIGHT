import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/models/product_overview.dart';

class StockInFormData {
  const StockInFormData({required this.quantity, this.note});

  final int quantity;
  final String? note;
}

Future<StockInFormData?> showStockInDialog(
  BuildContext context, {
  required ProductOverview product,
}) {
  return showDialog<StockInFormData>(
    context: context,
    builder: (_) => _StockInDialog(product: product),
  );
}

class _StockInDialog extends StatefulWidget {
  const _StockInDialog({required this.product});

  final ProductOverview product;

  @override
  State<_StockInDialog> createState() => _StockInDialogState();
}

class _StockInDialogState extends State<_StockInDialog> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _quantityController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    Navigator.of(context).pop(
      StockInFormData(
        quantity: int.parse(_quantityController.text.trim()),
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Catat stok masuk'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text('${widget.product.name} (${widget.product.unit})'),
            ),
            TextFormField(
              controller: _quantityController,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: 'Jumlah masuk'),
              validator: (value) {
                final quantity = int.tryParse(value?.trim() ?? '');
                if (quantity == null || quantity <= 0) {
                  return 'Jumlah harus lebih dari 0.';
                }
                return null;
              },
            ),
            TextField(
              controller: _noteController,
              textCapitalization: TextCapitalization.sentences,
              decoration:
                  const InputDecoration(labelText: 'Catatan (opsional)'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}
