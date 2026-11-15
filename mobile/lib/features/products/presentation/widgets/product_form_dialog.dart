import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/models/product_overview.dart';

class ProductFormData {
  const ProductFormData({
    required this.stockCode,
    required this.name,
    required this.unit,
    required this.unitPrice,
    required this.reorderThreshold,
    required this.isMonitored,
    this.image,
  });

  final String stockCode;
  final String name;
  final String unit;
  final double unitPrice;
  final int reorderThreshold;
  final bool isMonitored;
  final XFile? image;
}

Future<ProductFormData?> showProductFormDialog(
  BuildContext context, {
  ProductOverview? product,
}) {
  return showDialog<ProductFormData>(
    context: context,
    builder: (_) => _ProductFormDialog(product: product),
  );
}

class _ProductFormDialog extends StatefulWidget {
  const _ProductFormDialog({this.product});

  final ProductOverview? product;

  @override
  State<_ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<_ProductFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _stockCodeController;
  late final TextEditingController _nameController;
  late final TextEditingController _unitController;
  late final TextEditingController _priceController;
  late final TextEditingController _thresholdController;
  late bool _isMonitored;
  XFile? _selectedImage;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    _stockCodeController = TextEditingController(text: product?.stockCode);
    _nameController = TextEditingController(text: product?.name);
    _unitController = TextEditingController(text: product?.unit);
    _priceController =
        TextEditingController(text: product?.unitPrice.toString() ?? '0');
    _thresholdController = TextEditingController(
      text: product?.reorderThreshold.toString() ?? '0',
    );
    _isMonitored = product?.isMonitored ?? true;
  }

  @override
  void dispose() {
    _stockCodeController.dispose();
    _nameController.dispose();
    _unitController.dispose();
    _priceController.dispose();
    _thresholdController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    Navigator.of(context).pop(
      ProductFormData(
        stockCode: _stockCodeController.text.trim().toUpperCase(),
        name: _nameController.text.trim(),
        unit: _unitController.text.trim(),
        unitPrice: double.parse(_priceController.text.trim()),
        reorderThreshold: int.parse(_thresholdController.text.trim()),
        isMonitored: _isMonitored,
        image: _selectedImage,
      ),
    );
  }

  Future<void> _pickImage() async {
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (image != null && mounted) {
        setState(() => _selectedImage = image);
      }
    } on PlatformException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Galeri tidak dapat dibuka: ${error.message ?? error.code}',
          ),
        ),
      );
    }
  }

  String? _required(String? value, String label) {
    if (value == null || value.trim().isEmpty) return '$label wajib diisi.';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.product != null;

    return AlertDialog(
      title: Text(isEditing ? 'Edit produk' : 'Tambah produk'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Nama produk'),
                validator: (value) => _required(value, 'Nama produk'),
              ),
              TextFormField(
                controller: _stockCodeController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(labelText: 'Kode SKU'),
                validator: (value) => _required(value, 'Kode SKU'),
              ),
              TextFormField(
                controller: _unitController,
                decoration: const InputDecoration(labelText: 'Satuan'),
                validator: (value) => _required(value, 'Satuan'),
              ),
              TextFormField(
                controller: _priceController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Harga satuan',
                  prefixText: 'Rp ',
                ),
                validator: (value) {
                  final price = double.tryParse(value?.trim() ?? '');
                  if (price == null || price < 0) {
                    return 'Masukkan harga yang valid.';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _thresholdController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration:
                    const InputDecoration(labelText: 'Batas minimum stok'),
                validator: (value) {
                  if (int.tryParse(value?.trim() ?? '') == null) {
                    return 'Masukkan batas stok yang valid.';
                  }
                  return null;
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Pantau stok produk'),
                value: _isMonitored,
                onChanged: (value) => setState(() => _isMonitored = value),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Gambar produk (maks. 5 MB)',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 72,
                      height: 72,
                      child: _selectedImage != null
                          ? Image.file(
                              File(_selectedImage!.path),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const _ImagePlaceholder(),
                            )
                          : widget.product?.imageUrl != null
                              ? Image.network(
                                  widget.product!.imageUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      const _ImagePlaceholder(),
                                )
                              : const _ImagePlaceholder(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.photo_library_outlined),
                      label: Text(
                        _selectedImage == null
                            ? 'Pilih dari galeri'
                            : 'Ganti gambar',
                      ),
                    ),
                  ),
                ],
              ),
              if (!isEditing)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Produk baru dibuat dengan stok 0. Catat stok masuk '
                    'setelah produk disimpan.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
            ],
          ),
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

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFFE2E8F0),
      child: Icon(Icons.image_outlined, color: Color(0xFF64748B)),
    );
  }
}
