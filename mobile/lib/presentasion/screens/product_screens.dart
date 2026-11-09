import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../widgets/app_shell.dart';

// ---------- Warna tambahan khusus halaman ini ----------
const _kRestock = Color(0xFF9A3412);
const _kRedText = Color(0xFFB91C1C);
const _kRedBg = Color(0xFFFEE2E2);
const _kOrangeBg = Color(0xFFFFEDE0);
const _kGreyText = Color(0xFF334155);
const _kChipActiveBg = Color(0xFFE0E7FF);
const _kCountBg = Color(0xFFC7D2FE);

enum StockStatus { habis, restock, pantau, aman }

class Product {
  final String name, sku, stock, eta;
  final StockStatus status;
  final IconData etaIcon;
  final String? imagePath; // contoh: 'assets/images/minyak.png'

  const Product({
    required this.name,
    required this.sku,
    required this.stock,
    required this.status,
    required this.eta,
    required this.etaIcon,
    this.imagePath,
  });
}

const _products = <Product>[
  Product(
    name: 'Minyak Goreng Sania 2L',
    sku: 'MKS-2L-01',
    stock: '0 botol',
    status: StockStatus.habis,
    eta: 'Habis: Hari ini',
    etaIcon: Icons.event_busy_outlined,
  ),
  Product(
    name: 'Beras Premium 5 kg',
    sku: 'BRS-5KG-04',
    stock: '4 karung',
    status: StockStatus.restock,
    eta: 'Habis dlm 2 hari',
    etaIcon: Icons.schedule,
  ),
  Product(
    name: 'Gula Pasir 1 kg',
    sku: 'GLP-1KG-02',
    stock: '9 kg',
    status: StockStatus.pantau,
    eta: 'Habis dlm 5 hari',
    etaIcon: Icons.calendar_today_outlined,
  ),
  Product(
    name: 'Kecap Manis Botol 600 ml',
    sku: 'KCP-600-08',
    stock: '24 botol',
    status: StockStatus.aman,
    eta: 'Habis dlm 18 hari',
    etaIcon: Icons.verified_outlined,
  ),
  Product(
    name: 'Mi Instan Goreng',
    sku: 'MIG-DUS-03',
    stock: '38 bungkus',
    status: StockStatus.aman,
    eta: 'Prediksi belum tersedia',
    etaIcon: Icons.info_outline,
  ),
];

// =====================================================================
class ProductScreens extends StatefulWidget {
  const ProductScreens({super.key});

  @override
  State<ProductScreens> createState() => _ProductScreensState();
}

class _ProductScreensState extends State<ProductScreens> {
  final _searchCtrl = TextEditingController();
  String _filter = 'Semua';

  static const _filters = ['Semua', 'Stok aman', 'Perlu restock', 'Stok habis'];

  bool _matchFilter(Product p) {
    switch (_filter) {
      case 'Stok aman':
        return p.status == StockStatus.aman;
      case 'Perlu restock':
        return p.status == StockStatus.restock ||
            p.status == StockStatus.pantau;
      case 'Stok habis':
        return p.status == StockStatus.habis;
      default:
        return true;
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchCtrl.text.trim().toLowerCase();
    final list = _products
        .where((p) => _matchFilter(p) && p.name.toLowerCase().contains(query))
        .toList();
    final needAction = _products
        .where(
          (p) =>
              p.status == StockStatus.habis || p.status == StockStatus.restock,
        )
        .length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const AppTopBar(),
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
                children: [
                  _Header(onAdd: () {}),
                  const SizedBox(height: 18),
                  _SearchField(
                    controller: _searchCtrl,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 16),
                  _FilterChips(
                    filters: _filters,
                    selected: _filter,
                    totalCount: _products.length,
                    onSelect: (f) => setState(() => _filter = f),
                  ),
                  const SizedBox(height: 18),
                  _SummaryCard(count: needAction, onAudit: () {}),
                  const SizedBox(height: 16),
                  if (list.isEmpty) const _EmptyState(),
                  for (final p in list)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _ProductTile(product: p, onTap: () {}),
                    ),
                  const SizedBox(height: 12),
                  const _SyncFooter(),
                ],
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
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;

  const _SoftCard({
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.radius = 24,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
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
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

// ---------- Top bar ----------
class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF0FB),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.storefront_outlined,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TOKO UMKM',
                  style: TextStyle(
                    fontSize: 12,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textMuted,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Toko Berkah Jaya',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.notifications_none_rounded,
            color: AppColors.textMuted,
            size: 28,
          ),
          const SizedBox(width: 18),
          const CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.primary,
            child: Icon(Icons.person_outline_rounded, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

// ---------- Header + tombol tambah ----------
class _Header extends StatelessWidget {
  final VoidCallback onAdd;
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
  final Product product;
  final VoidCallback onTap;
  const _ProductTile({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final s = _statusStyle(product.status);
    final placeholder = Container(
      width: 64,
      height: 64,
      color: AppColors.chip,
      child: const Icon(Icons.shopping_bag_outlined, color: AppColors.hint),
    );

    return _SoftCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: product.imagePath == null
                ? placeholder
                : Image.asset(
                    product.imagePath!,
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => placeholder,
                  ),
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
                      TextSpan(text: 'SKU: ${product.sku}  •  '),
                      TextSpan(
                        text: 'Sisa: ${product.stock}',
                        style: TextStyle(
                          fontWeight: s.stockBold
                              ? FontWeight.w500
                              : FontWeight.w600,
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
                          product.etaIcon,
                          size: 17,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          product.eta,
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
          const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
        ],
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

_Style _statusStyle(StockStatus s) {
  switch (s) {
    case StockStatus.habis:
      return const _Style(
        'Stok habis',
        _kRedBg,
        _kRedText,
        _kRedText,
        stockBold: false,
      );
    case StockStatus.restock:
      return const _Style(
        'Segera restock',
        _kOrangeBg,
        _kRestock,
        _kRestock,
        stockBold: false,
      );
    case StockStatus.pantau:
      return const _Style(
        'Perlu dipantau',
        AppColors.chip,
        _kGreyText,
        AppColors.textDark,
      );
    case StockStatus.aman:
      return const _Style(
        'Stok aman',
        AppColors.chip,
        _kGreyText,
        AppColors.textDark,
      );
  }
}

// ---------- Kondisi kosong ----------
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 36),
      child: Column(
        children: [
          Icon(Icons.search_off_rounded, size: 44, color: AppColors.hint),
          SizedBox(height: 10),
          Text(
            'Produk tidak ditemukan',
            style: TextStyle(fontSize: 16, color: AppColors.textMuted),
          ),
        ],
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
