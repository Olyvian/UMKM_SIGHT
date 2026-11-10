import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';

class SaleEntryProduct {
  const SaleEntryProduct({
    required this.name,
    required this.unit,
    required this.availableStock,
  });

  final String name;
  final String unit;
  final int availableStock;
}

class SaleEntryResult {
  const SaleEntryResult({
    required this.product,
    required this.quantity,
    required this.dateTime,
  });

  final SaleEntryProduct product;
  final int quantity;
  final DateTime dateTime;
}

Future<SaleEntryResult?> showSaleEntrySheet(
  BuildContext context, {
  required List<SaleEntryProduct> products,
}) {
  return showModalBottomSheet<SaleEntryResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _SaleEntrySheet(products: products),
  );
}

class _SaleEntrySheet extends StatefulWidget {
  const _SaleEntrySheet({required this.products});

  final List<SaleEntryProduct> products;

  @override
  State<_SaleEntrySheet> createState() => _SaleEntrySheetState();
}

class _SaleEntrySheetState extends State<_SaleEntrySheet> {
  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _quantityController;
  late int _productIndex;
  late DateTime _dateTime;

  SaleEntryProduct get _product => widget.products[_productIndex];

  @override
  void initState() {
    super.initState();
    _productIndex =
        widget.products.indexWhere((product) => product.availableStock > 0);
    if (_productIndex < 0) _productIndex = 0;
    _dateTime = DateTime.now();
    _quantityController = TextEditingController(text: '1');
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) =>
      '${date.day} ${_months[date.month - 1]} ${date.year}';

  String _formatTime(DateTime date) =>
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateTime,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year, now.month, now.day),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _dateTime = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _dateTime.hour,
        _dateTime.minute,
      );
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dateTime),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _dateTime = DateTime(
        _dateTime.year,
        _dateTime.month,
        _dateTime.day,
        picked.hour,
        picked.minute,
      );
    });
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      SaleEntryResult(
        product: _product,
        quantity: int.parse(_quantityController.text),
        dateTime: _dateTime,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomInset),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.hint,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Catat Penjualan',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Pilih produk, jumlah terjual, dan waktu transaksi.',
                style: TextStyle(fontSize: 14, color: AppColors.textMuted),
              ),
              const SizedBox(height: 20),
              const _FieldLabel('Tanggal dan waktu'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _PickerTile(
                      icon: Icons.calendar_today_outlined,
                      label: _formatDate(_dateTime),
                      onTap: _pickDate,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _PickerTile(
                      icon: Icons.access_time_rounded,
                      label: _formatTime(_dateTime),
                      onTap: _pickTime,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const _FieldLabel('Produk'),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                initialValue: _productIndex,
                isExpanded: true,
                decoration: _fieldDecoration(),
                items: [
                  for (var i = 0; i < widget.products.length; i++)
                    DropdownMenuItem(
                      value: i,
                      child: Text(
                        '${widget.products[i].name} (${widget.products[i].availableStock} ${widget.products[i].unit})',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (index) {
                  if (index == null) return;
                  setState(() => _productIndex = index);
                },
              ),
              const SizedBox(height: 18),
              const _FieldLabel('Jumlah terjual'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _quantityController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textAlign: TextAlign.center,
                decoration: _fieldDecoration(
                  suffixText: _product.unit,
                  prefix: IconButton(
                    tooltip: 'Kurangi jumlah',
                    onPressed: () {
                      final current =
                          int.tryParse(_quantityController.text) ?? 0;
                      if (current > 0) {
                        _quantityController.text = '${current - 1}';
                      }
                    },
                    icon: const Icon(Icons.remove_circle_outline_rounded),
                  ),
                  suffix: IconButton(
                    tooltip: 'Tambah jumlah',
                    onPressed: () {
                      final current =
                          int.tryParse(_quantityController.text) ?? 0;
                      _quantityController.text = '${current + 1}';
                    },
                    icon: const Icon(Icons.add_circle_outline_rounded),
                  ),
                ),
                validator: (value) {
                  final quantity = int.tryParse(value ?? '');
                  if (quantity == null || quantity < 1) {
                    return 'Jumlah harus minimal 1 ${_product.unit}.';
                  }
                  if (quantity > _product.availableStock) {
                    return 'Stok tersedia hanya ${_product.availableStock} ${_product.unit}.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              Text(
                'Stok tersedia: ${_product.availableStock} ${_product.unit}',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: const Text(
                    'Simpan & Catat Penjualan',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration({
    String? suffixText,
    Widget? prefix,
    Widget? suffix,
  }) {
    return InputDecoration(
      filled: true,
      fillColor: AppColors.chip,
      suffixText: suffixText,
      prefixIcon: prefix,
      suffixIcon: suffix,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.primary),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.danger),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textMuted,
      ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.chip,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
