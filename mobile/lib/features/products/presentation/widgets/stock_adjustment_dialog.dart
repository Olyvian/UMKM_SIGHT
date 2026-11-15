import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/models/product_overview.dart';

class StockAdjustmentFormData {
  const StockAdjustmentFormData({required this.newStock, this.note});

  final int newStock;
  final String? note;
}

Future<StockAdjustmentFormData?> showStockAdjustmentDialog(
  BuildContext context, {
  required ProductOverview product,
}) {
  return showDialog<StockAdjustmentFormData>(
    context: context,
    builder: (_) => _StockAdjustmentDialog(product: product),
  );
}

class _StockAdjustmentDialog extends StatefulWidget {
  const _StockAdjustmentDialog({required this.product});

  final ProductOverview product;

  @override
  State<_StockAdjustmentDialog> createState() => _StockAdjustmentDialogState();
}

class _StockAdjustmentDialogState extends State<_StockAdjustmentDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _stockController;
  final _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _stockController =
        TextEditingController(text: widget.product.currentStock.toString());
  }

  @override
  void dispose() {
    _stockController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    Navigator.of(context).pop(
      StockAdjustmentFormData(
        newStock: int.parse(_stockController.text.trim()),
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Koreksi stok'),
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
              controller: _stockController,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: 'Stok aktual'),
              validator: (value) {
                if (int.tryParse(value?.trim() ?? '') == null) {
                  return 'Masukkan stok aktual yang valid.';
                }
                return null;
              },
            ),
            TextField(
              controller: _noteController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Alasan koreksi (opsional)',
              ),
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
