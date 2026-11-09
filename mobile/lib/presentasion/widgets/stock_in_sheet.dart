import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';

// =====================================================================
// Form "Catat Stok Masuk" dalam bentuk bottom sheet.
// Simpan di: lib/presentasion/widgets/stock_in_sheet.dart
//
// Contoh pemakaian:
//   showStockInSheet(context, products: [
//     StockInProduct(name: 'Beras Premium 5 kg', unit: 'karung', suggested: 15),
//   ]);
// =====================================================================

class StockInProduct {
  final String name, unit;
  final int? suggested; // jumlah saran dari prediksi (opsional)
  const StockInProduct({required this.name, required this.unit, this.suggested});
}

/// Menampilkan form stok masuk. Jika [products] berisi lebih dari satu,
/// pengguna bisa memilih produknya lebih dulu.
Future<void> showStockInSheet(
  BuildContext context, {
  required List<StockInProduct> products,
  int initialIndex = 0,
}) async {
  final result = await showModalBottomSheet<({StockInProduct product, int qty})>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _StockInSheet(products: products, initialIndex: initialIndex),
  );

  if (result == null || !context.mounted) return;

  // TODO: sambungkan ke POST /api/products/{id}/restock (quantity)
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
          'Stok masuk dicatat: ${result.qty} ${result.product.unit} ${result.product.name}'),
    ),
  );
}

class _StockInSheet extends StatefulWidget {
  final List<StockInProduct> products;
  final int initialIndex;
  const _StockInSheet({required this.products, required this.initialIndex});

  @override
  State<_StockInSheet> createState() => _StockInSheetState();
}

class _StockInSheetState extends State<_StockInSheet> {
  late int _index = widget.initialIndex;
  late final TextEditingController _ctrl;
  int _qty = 1;
  bool _showError = false;

  StockInProduct get _product => widget.products[_index];

  @override
  void initState() {
    super.initState();
    _qty = _product.suggested ?? 1;
    _ctrl = TextEditingController(text: '$_qty');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _setQty(int value) {
    final v = value.clamp(0, 99999);
    setState(() {
      _qty = v;
      _showError = false;
      _ctrl.value = TextEditingValue(
        text: '$v',
        selection: TextSelection.collapsed(offset: '$v'.length),
      );
    });
  }

  void _save() {
    if (_qty < 1) {
      setState(() => _showError = true);
      return;
    }
    Navigator.pop(context, (product: _product, qty: _qty));
  }

  @override
  Widget build(BuildContext context) {
    final suggested = _product.suggested;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
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
              const Text('Catat Stok Masuk',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark)),
              const SizedBox(height: 4),
              const Text('Tambahkan jumlah barang yang baru diterima.',
                  style: TextStyle(fontSize: 14, color: AppColors.textMuted)),
              const SizedBox(height: 18),

              // ----- Produk -----
              const Text('Produk',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted)),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.chip,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: widget.products.length > 1
                    ? DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: _index,
                          isExpanded: true,
                          borderRadius: BorderRadius.circular(16),
                          icon: const Icon(Icons.keyboard_arrow_down_rounded,
                              color: AppColors.textMuted),
                          items: [
                            for (var i = 0; i < widget.products.length; i++)
                              DropdownMenuItem(
                                value: i,
                                child: Text(widget.products[i].name,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textDark)),
                              ),
                          ],
                          onChanged: (i) {
                            if (i == null) return;
                            setState(() => _index = i);
                            _setQty(_product.suggested ?? 1);
                          },
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(_product.name,
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textDark)),
                      ),
              ),
              const SizedBox(height: 18),

              // ----- Jumlah -----
              const Text('Jumlah masuk',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted)),
              const SizedBox(height: 6),
              Row(
                children: [
                  _RoundButton(
                    icon: Icons.remove_rounded,
                    onTap: () => _setQty(_qty - 1),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      textAlign: TextAlign.center,
                      cursorColor: AppColors.primary,
                      style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark),
                      onChanged: (t) => setState(() {
                        _qty = int.tryParse(t) ?? 0;
                        _showError = false;
                      }),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.chip,
                        suffixText: _product.unit,
                        suffixStyle: const TextStyle(
                            fontSize: 14, color: AppColors.textMuted),
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _RoundButton(
                    icon: Icons.add_rounded,
                    onTap: () => _setQty(_qty + 1),
                  ),
                ],
              ),
              if (_showError)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('Jumlah minimal 1',
                      style: TextStyle(fontSize: 13, color: AppColors.error)),
                ),
              if (suggested != null) ...[
                const SizedBox(height: 12),
                InkWell(
                  onTap: () => _setQty(suggested),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0E7FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.auto_graph_rounded,
                            size: 16, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text('Saran prediksi: $suggested ${_product.unit}',
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary)),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 22),
              FilledButton(
                onPressed: _save,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  minimumSize: const Size.fromHeight(54),
                  textStyle: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18)),
                ),
                child: const Text('Simpan'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _RoundButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.chip,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: SizedBox(
          width: 52,
          height: 52,
          child: Icon(icon, color: AppColors.textDark),
        ),
      ),
    );
  }
}