import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/theme/app_colors.dart';
import '../../features/products/data/models/product_overview.dart';
import '../../features/products/data/repositories/product_repository.dart';
import '../../features/products/presentation/widgets/product_form_dialog.dart';
import '../../features/products/presentation/widgets/stock_adjustment_dialog.dart';
import '../../features/products/presentation/widgets/stock_in_dialog.dart';
import '../widgets/app_shell.dart';

// ---------- Warna tambahan khusus halaman ini ----------
const _kRestock = Color(0xFF9A3412);
const _kRedText = Color(0xFFB91C1C);
const _kRedBg = Color(0xFFFEE2E2);
const _kOrangeBg = Color(0xFFFFEDE0);
const _kGreyText = Color(0xFF334155);
const _kChipActiveBg = Color(0xFFE0E7FF);
const _kCountBg = Color(0xFFC7D2FE);

// =====================================================================
class ProductScreens extends StatefulWidget {
  const ProductScreens({super.key});

  @override
  State<ProductScreens> createState() => _ProductScreensState();
}

class _ProductScreensState extends State<ProductScreens> {
  final _searchCtrl = TextEditingController();
  String _filter = 'Semua';
  late final ProductRepository _productRepository;
  late Future<List<ProductOverview>> _productsFuture;
  bool _isWorking = false;

  static const _filters = ['Semua', 'Stok aman', 'Perlu restock', 'Stok habis'];

  @override
  void initState() {
    super.initState();
    _productRepository = context.read<ProductRepository>();
    _productsFuture = _productRepository.fetchProducts();
  }

  void _refreshProducts() {
    setState(() {
      _productsFuture = _productRepository.fetchProducts();
    });
  }

  bool _matchFilter(ProductOverview product) {
    switch (_filter) {
      case 'Stok aman':
        return product.status == ProductStockStatus.safe;
      case 'Perlu restock':
        return product.status == ProductStockStatus.restock ||
            product.status == ProductStockStatus.monitor;
      case 'Stok habis':
        return product.status == ProductStockStatus.outOfStock;
      default:
        return true;
    }
  }

  Future<void> _mutate({
    required Future<void> Function() operation,
    required String successMessage,
  }) async {
    if (_isWorking) return;
    setState(() => _isWorking = true);
    try {
      await operation();
      if (!mounted) return;
      _refreshProducts();
      _showMessage(successMessage);
    } catch (error) {
      if (!mounted) return;
      final message = error is ProductFailure
          ? error.message
          : 'Operasi produk gagal: $error';
      _showMessage(message, isError: true);
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? _kRedText : null,
        ),
      );
  }

  Future<void> _editProduct([ProductOverview? product]) async {
    if (_isWorking) return;
    final form = await showProductFormDialog(context, product: product);
    if (form == null) return;

    await _mutate(
      operation: () => _saveProduct(product, form),
      successMessage: product == null
          ? 'Produk berhasil ditambahkan.'
          : 'Produk diperbarui.',
    );
  }

  Future<void> _saveProduct(
    ProductOverview? product,
    ProductFormData form,
  ) async {
    if (product == null) {
      final id = await _productRepository.createProduct(
        stockCode: form.stockCode,
        name: form.name,
        unit: form.unit,
        unitPrice: form.unitPrice,
        reorderThreshold: form.reorderThreshold,
        isMonitored: form.isMonitored,
      );
      if (form.image != null) {
        if (mounted) _refreshProducts();
        await _productRepository.uploadProductImage(
          productId: id,
          image: form.image!,
        );
      }
      return;
    }

    await _productRepository.updateProduct(
      id: product.id,
      stockCode: form.stockCode,
      name: form.name,
      unit: form.unit,
      unitPrice: form.unitPrice,
      reorderThreshold: form.reorderThreshold,
      isMonitored: form.isMonitored,
    );
    if (form.image != null) {
      if (mounted) _refreshProducts();
      await _productRepository.uploadProductImage(
        productId: product.id,
        image: form.image!,
        previousPath: product.imagePath,
      );
    }
  }

  Future<void> _recordStockIn(ProductOverview product) async {
    if (_isWorking) return;
    final form = await showStockInDialog(context, product: product);
    if (form == null) return;

    await _mutate(
      operation: () => _productRepository.recordStockIn(
        productId: product.id,
        quantity: form.quantity,
        note: form.note,
      ),
      successMessage: 'Stok masuk berhasil dicatat.',
    );
  }

  Future<void> _adjustStock(ProductOverview product) async {
    if (_isWorking) return;
    final form = await showStockAdjustmentDialog(context, product: product);
    if (form == null) return;

    await _mutate(
      operation: () => _productRepository.adjustStock(
        productId: product.id,
        newStock: form.newStock,
        note: form.note,
      ),
      successMessage: 'Stok berhasil dikoreksi.',
    );
  }

  Future<void> _archiveProduct(ProductOverview product) async {
    if (_isWorking) return;
    final shouldArchive = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Arsipkan produk?'),
        content: Text(
          '${product.name} tidak akan tampil lagi di daftar produk aktif.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Arsipkan'),
          ),
        ],
      ),
    );
    if (shouldArchive != true) return;

    await _mutate(
      operation: () => _productRepository.archiveProduct(product.id),
      successMessage: 'Produk berhasil diarsipkan.',
    );
  }

  Future<void> _restoreProduct(ProductOverview product) async {
    await _mutate(
      operation: () => _productRepository.restoreProduct(product.id),
      successMessage: 'Produk berhasil dipulihkan.',
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const AppTopBar(),
            Expanded(
              child: FutureBuilder<List<ProductOverview>>(
                future: _productsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return _LoadError(
                      message: snapshot.error.toString(),
                      onRetry: _refreshProducts,
                    );
                  }

                  final products = snapshot.data ?? const <ProductOverview>[];
                  final activeProducts =
                      products.where((product) => product.isActive).toList();
                  final archivedProducts =
                      products.where((product) => !product.isActive).toList();
                  final query = _searchCtrl.text.trim().toLowerCase();
                  final list = activeProducts
                      .where(
                        (product) =>
                            _matchFilter(product) &&
                            product.name.toLowerCase().contains(query),
                      )
                      .toList();
                  final archivedList = archivedProducts
                      .where(
                        (product) => product.name.toLowerCase().contains(query),
                      )
                      .toList();
                  final needAction = activeProducts
                      .where(
                        (product) =>
                            product.status == ProductStockStatus.outOfStock ||
                            product.status == ProductStockStatus.restock,
                      )
                      .length;

                  return ListView(
                    physics: const BouncingScrollPhysics(),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
                    children: [
                      _Header(
                        onAdd: _isWorking ? null : () => _editProduct(),
                      ),
                      const SizedBox(height: 18),
                      _SearchField(
                        controller: _searchCtrl,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 16),
                      _FilterChips(
                        filters: _filters,
                        selected: _filter,
                        totalCount: activeProducts.length,
                        onSelect: (filter) => setState(() => _filter = filter),
                      ),
                      const SizedBox(height: 18),
                      _SummaryCard(count: needAction, onAudit: () {}),
                      const SizedBox(height: 16),
                      if (list.isEmpty && archivedList.isEmpty)
                        _EmptyState(
                          isNoProducts: activeProducts.isEmpty &&
                              archivedProducts.isEmpty,
                        ),
                      for (final product in list)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _ProductTile(
                            product: product,
                            onTap: () => _editProduct(product),
                            onStockIn: () => _recordStockIn(product),
                            onAdjustStock: () => _adjustStock(product),
                            onArchive: () => _archiveProduct(product),
                          ),
                        ),
                      if (archivedList.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _ArchivedSectionHeader(count: archivedList.length),
                        const SizedBox(height: 12),
                        for (final product in archivedList)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _ArchivedProductTile(
                              product: product,
                              onRestore: () => _restoreProduct(product),
                            ),
                          ),
                      ],
                      const SizedBox(height: 12),
                      const _SyncFooter(),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNav(current: 1),
    );
  }
}

// ---------- Kartu dasar (bayangan lembut + efek tap) ----------
class _SoftCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color backgroundColor;

  const _SoftCard({
    required this.child,
    this.onTap,
    this.backgroundColor = AppColors.surface,
  });

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(24);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: r,
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: r,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: child,
          ),
        ),
      ),
    );
  }
}

// ---------- Header + tombol tambah ----------
class _Header extends StatelessWidget {
  final VoidCallback? onAdd;
  const _Header({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Produk',
                style: TextStyle(
                  fontSize: 32,
                  height: 1.15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Kelola persediaan tokomu',
                style: TextStyle(fontSize: 14, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        FilledButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add_rounded, size: 24),
          label: const Text('Tambah Produk'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            minimumSize: const Size(0, 48),
            padding: const EdgeInsets.symmetric(horizontal: 18),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------- Kolom pencarian ----------
class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  const _SearchField({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        cursorColor: AppColors.primary,
        style: const TextStyle(fontSize: 17, color: AppColors.textDark),
        decoration: InputDecoration(
          hintText: 'Cari nama produk...',
          hintStyle: const TextStyle(fontSize: 17, color: AppColors.hint),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppColors.textMuted,
            size: 26,
          ),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    color: AppColors.textMuted,
                    size: 22,
                  ),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 18),
        ),
      ),
    );
  }
}

// ---------- Filter chips ----------
class _FilterChips extends StatelessWidget {
  final List<String> filters;
  final String selected;
  final int totalCount;
  final ValueChanged<String> onSelect;

  const _FilterChips({
    required this.filters,
    required this.selected,
    required this.totalCount,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      clipBehavior: Clip.none,
      child: Row(
        children: [
          for (final f in filters) ...[
            _chip(f, f == selected),
            const SizedBox(width: 12),
          ],
        ],
      ),
    );
  }

  Widget _chip(String label, bool active) {
    return GestureDetector(
      onTap: () => onSelect(label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 13),
        decoration: BoxDecoration(
          color: active ? _kChipActiveBg : AppColors.surface,
          borderRadius: BorderRadius.circular(30),
          boxShadow: active
              ? null
              : const [
                  BoxShadow(
                    color: AppColors.shadow,
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 17,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                color: active ? AppColors.primary : AppColors.textMuted,
              ),
            ),
            if (active && label == 'Semua') ...[
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: _kCountBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$totalCount',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------- Ringkasan gudang ----------
class _SummaryCard extends StatelessWidget {
  final int count;
  final VoidCallback onAudit;
  const _SummaryCard({required this.count, required this.onAudit});

  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      onTap: onAudit,
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.chip,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.fact_check_outlined,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ringkasan Gudang',
                  style: TextStyle(fontSize: 15, color: AppColors.textMuted),
                ),
                const SizedBox(height: 2),
                Text(
                  '$count produk perlu tindakan',
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Row(
            children: [
              Text(
                'Audit',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
              SizedBox(width: 2),
              Icon(
                Icons.arrow_forward_rounded,
                size: 18,
                color: AppColors.primary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------- Item produk ----------
class _ProductTile extends StatelessWidget {
  final ProductOverview product;
  final VoidCallback onTap;
  final VoidCallback onStockIn;
  final VoidCallback onAdjustStock;
  final VoidCallback onArchive;

  const _ProductTile({
    required this.product,
    required this.onTap,
    required this.onStockIn,
    required this.onAdjustStock,
    required this.onArchive,
  });

  @override
  Widget build(BuildContext context) {
    final s = _statusStyle(product.status);

    return _SoftCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.chip,
              borderRadius: BorderRadius.circular(14),
            ),
            child: _ProductThumbnail(product: product),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text.rich(
                  TextSpan(
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textMuted,
                    ),
                    children: [
                      TextSpan(text: 'SKU: ${product.stockCode}  •  '),
                      TextSpan(
                        text: 'Sisa: ${product.currentStock} ${product.unit}',
                        style: TextStyle(
                          fontWeight:
                              s.stockBold ? FontWeight.w500 : FontWeight.w600,
                          color: s.stockColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    _StatusBadge(style: s),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _etaIcon(product),
                          size: 17,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _etaText(product),
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Edit produk',
            onPressed: onTap,
            icon: const Icon(Icons.edit_outlined, color: AppColors.textMuted),
          ),
          PopupMenuButton<_ProductAction>(
            tooltip: 'Aksi produk',
            onSelected: (action) {
              switch (action) {
                case _ProductAction.stockIn:
                  onStockIn();
                case _ProductAction.adjustStock:
                  onAdjustStock();
                case _ProductAction.archive:
                  onArchive();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: _ProductAction.stockIn,
                child: Text('Catat stok masuk'),
              ),
              PopupMenuItem(
                value: _ProductAction.adjustStock,
                child: Text('Koreksi stok'),
              ),
              PopupMenuItem(
                value: _ProductAction.archive,
                child: Text('Arsipkan produk'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ArchivedSectionHeader extends StatelessWidget {
  const _ArchivedSectionHeader({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.archive_outlined,
            color: AppColors.textMuted, size: 20),
        const SizedBox(width: 8),
        const Expanded(
          child: Text(
            'Diarsipkan',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          '$count',
          style: const TextStyle(color: AppColors.textMuted),
        ),
      ],
    );
  }
}

class _ArchivedProductTile extends StatelessWidget {
  const _ArchivedProductTile({
    required this.product,
    required this.onRestore,
  });

  final ProductOverview product;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    const archivedTextColor = Color(0xFF64748B);

    return _SoftCard(
      backgroundColor: const Color(0xFFF1F5F9),
      child: Row(
        children: [
          Opacity(
            opacity: 0.55,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: _ProductThumbnail(product: product),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: archivedTextColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'SKU: ${product.stockCode}  •  '
                  'Sisa: ${product.currentStock} ${product.unit}',
                  style: const TextStyle(
                    color: archivedTextColor,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Produk diarsipkan',
                  style: TextStyle(
                    color: archivedTextColor,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Pulihkan produk',
            onPressed: onRestore,
            icon:
                const Icon(Icons.unarchive_outlined, color: archivedTextColor),
          ),
        ],
      ),
    );
  }
}

class _ProductThumbnail extends StatelessWidget {
  const _ProductThumbnail({required this.product});

  final ProductOverview product;

  @override
  Widget build(BuildContext context) {
    final path = product.imagePath;
    if (path == null || path.isEmpty) {
      return const Icon(
        Icons.shopping_bag_outlined,
        color: AppColors.hint,
      );
    }

    final error = product.imageError ?? 'Gambar produk gagal dimuat.';
    final url = product.imageUrl;
    if (url == null) {
      return Tooltip(
        message: error,
        child: const Icon(Icons.broken_image_outlined, color: AppColors.hint),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (context, exception, stackTrace) => Tooltip(
          message: error,
          child: const Icon(Icons.broken_image_outlined, color: AppColors.hint),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final _Style style;
  const _StatusBadge({required this.style});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: style.badgeBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: style.badgeFg,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            style.label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: style.badgeFg,
            ),
          ),
        ],
      ),
    );
  }
}

class _Style {
  final String label;
  final Color badgeBg, badgeFg, stockColor;
  final bool stockBold;
  const _Style(
    this.label,
    this.badgeBg,
    this.badgeFg,
    this.stockColor, {
    this.stockBold = true,
  });
}

enum _ProductAction { stockIn, adjustStock, archive }

_Style _statusStyle(ProductStockStatus s) {
  switch (s) {
    case ProductStockStatus.outOfStock:
      return const _Style(
        'Stok habis',
        _kRedBg,
        _kRedText,
        _kRedText,
        stockBold: false,
      );
    case ProductStockStatus.restock:
      return const _Style(
        'Segera restock',
        _kOrangeBg,
        _kRestock,
        _kRestock,
        stockBold: false,
      );
    case ProductStockStatus.monitor:
      return const _Style(
        'Perlu dipantau',
        AppColors.chip,
        _kGreyText,
        AppColors.textDark,
      );
    case ProductStockStatus.safe:
      return const _Style(
        'Stok aman',
        AppColors.chip,
        _kGreyText,
        AppColors.textDark,
      );
  }
}

String _etaText(ProductOverview product) {
  final days = product.daysUntilStockout;
  if (days == null) return 'Prediksi belum tersedia';
  if (days <= 0) return 'Habis: Hari ini';
  return 'Habis dlm $days hari';
}

IconData _etaIcon(ProductOverview product) {
  final days = product.daysUntilStockout;
  if (days == null) return Icons.info_outline;
  if (days == 0) return Icons.event_busy_outlined;
  if (days <= 3) return Icons.schedule;
  if (days <= 7) return Icons.calendar_today_outlined;
  return Icons.verified_outlined;
}

// ---------- Kondisi kosong ----------
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.isNoProducts});

  final bool isNoProducts;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Column(
        children: [
          Icon(
            isNoProducts
                ? Icons.inventory_2_outlined
                : Icons.search_off_rounded,
            size: 44,
            color: AppColors.hint,
          ),
          const SizedBox(height: 10),
          Text(
            isNoProducts ? 'Belum ada produk' : 'Produk tidak ditemukan',
            style: const TextStyle(fontSize: 16, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, color: _kRedText, size: 40),
            const SizedBox(height: 12),
            const Text(
              'Produk belum dapat dimuat',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Coba lagi'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------- Footer ----------
class _SyncFooter extends StatelessWidget {
  const _SyncFooter();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        CircleAvatar(radius: 3, backgroundColor: AppColors.hint),
        SizedBox(height: 14),
        Text(
          'Semua data disinkronkan secara otomatis',
          style: TextStyle(fontSize: 15, color: AppColors.textMuted),
        ),
      ],
    );
  }
}
