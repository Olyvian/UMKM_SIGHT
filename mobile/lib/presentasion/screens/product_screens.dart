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
      backgroundColor: AppColors.backgroundOf(context),
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
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    children: [
                      _Header(
                        onAdd: _isWorking ? null : () => _editProduct(),
                      ),
                      const SizedBox(height: 12),
                      _SearchField(
                        controller: _searchCtrl,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 12),
                      _FilterChips(
                        filters: _filters,
                        selected: _filter,
                        totalCount: activeProducts.length,
                        onSelect: (filter) => setState(() => _filter = filter),
                      ),
                      const SizedBox(height: 12),
                      _SummaryCard(count: needAction, onAudit: () {}),
                      const SizedBox(height: 12),
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

// ---------- Kartu dasar (adaptif Light & Dark Mode) ----------
class _SoftCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color? backgroundColor;

  const _SoftCard({
    required this.child,
    this.onTap,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(6);
    final bg = backgroundColor ?? AppColors.surfaceOf(context);
    final borderColor = AppColors.borderOf(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: r,
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: r,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: const EdgeInsets.all(12), child: child),
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
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Produk',
                style: TextStyle(
                  fontSize: 20,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimaryOf(context),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Kelola persediaan tokomu',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondaryOf(context),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        FilledButton(
          onPressed: onAdd,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            minimumSize: const Size(88, 40),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          child: const Text('+ Tambah'),
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
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.borderOf(context), width: 1),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        cursorColor: AppColors.primaryOf(context),
        style: TextStyle(
          fontSize: 14,
          color: AppColors.textPrimaryOf(context),
        ),
        decoration: InputDecoration(
          hintText: 'Cari nama produk...',
          hintStyle: TextStyle(
            fontSize: 14,
            color: AppColors.textHintOf(context),
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: AppColors.textSecondaryOf(context),
            size: 18,
          ),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    color: AppColors.textSecondaryOf(context),
                    size: 18,
                  ),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                ),
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 11),
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
            _chip(context, f, f == selected),
            const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, String label, bool active) {
    final bg = active
        ? AppColors.primaryTintOf(context)
        : AppColors.surfaceSecondaryOf(context);
    final fg = active
        ? AppColors.primaryOf(context)
        : AppColors.textSecondaryOf(context);

    return GestureDetector(
      onTap: () => onSelect(label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.2,
                color: fg,
              ),
            ),
            if (active && label == 'Semua') ...[
              const SizedBox(width: 6),
              Text(
                '($totalCount)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: fg,
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
    final textPrimary = AppColors.textPrimaryOf(context);
    final textMuted = AppColors.textSecondaryOf(context);
    final primary = AppColors.primaryOf(context);

    return _SoftCard(
      onTap: onAudit,
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.surfaceSecondaryOf(context),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              Icons.fact_check_outlined,
              color: textMuted,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ringkasan Gudang',
                  style: TextStyle(fontSize: 12, color: textMuted),
                ),
                const SizedBox(height: 2),
                Text(
                  '$count produk perlu tindakan',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Row(
            children: [
              Text(
                'Audit',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: primary,
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.arrow_forward_rounded,
                size: 16,
                color: primary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------- Item produk (Figma 02 Produk: Icon box + Name/Meta + Pill + Arrow) ----------
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
    final s = _statusStyle(context, product.status);
    final textPrimary = AppColors.textPrimaryOf(context);
    final textMuted = AppColors.textSecondaryOf(context);
    final iconBg = AppColors.surfaceSecondaryOf(context);

    return _SoftCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(6),
            ),
            child: _ProductThumbnail(product: product),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text.rich(
                  TextSpan(
                    style: TextStyle(
                      fontSize: 12,
                      color: textMuted,
                    ),
                    children: [
                      TextSpan(text: 'SKU: ${product.stockCode}  •  '),
                      TextSpan(
                        text: '${product.currentStock} ${product.unit}',
                        style: TextStyle(
                          fontWeight: s.stockBold
                              ? FontWeight.w500
                              : FontWeight.w600,
                          color: s.stockColor,
                        ),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _StatusBadge(style: s),
          PopupMenuButton<_ProductAction>(
            tooltip: 'Aksi produk',
            padding: EdgeInsets.zero,
            icon: Icon(
              Icons.more_vert_rounded,
              size: 18,
              color: textMuted,
            ),
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
      backgroundColor: AppColors.surfaceSecondaryOf(context),
      child: Row(
        children: [
          Opacity(
            opacity: 0.65,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.borderOf(context),
                borderRadius: BorderRadius.circular(6),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: style.badgeBg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        style.label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.2,
          color: style.badgeFg,
        ),
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

_Style _statusStyle(BuildContext context, ProductStockStatus s) {
  switch (s) {
    case ProductStockStatus.outOfStock:
      return _Style(
        'Stok habis',
        AppColors.dangerBgOf(context),
        AppColors.dangerOf(context),
        AppColors.dangerOf(context),
        stockBold: false,
      );
    case ProductStockStatus.restock:
      return _Style(
        'Segera restock',
        AppColors.warningBgOf(context),
        AppColors.warningOf(context),
        AppColors.warningOf(context),
        stockBold: false,
      );
    case ProductStockStatus.monitor:
      return _Style(
        'Perlu dipantau',
        AppColors.surfaceSecondaryOf(context),
        AppColors.textSecondaryOf(context),
        AppColors.textPrimaryOf(context),
      );
    case ProductStockStatus.safe:
      return _Style(
        'Stok aman',
        AppColors.successBgOf(context),
        AppColors.successOf(context),
        AppColors.textPrimaryOf(context),
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
