import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../widgets/app_shell.dart';
import '../widgets/stock_in_sheet.dart';
import 'analytics_screens.dart';


// ---------- Warna tambahan khusus halaman ini ----------
const _kRestock = Color(0xFF9A3412);
const _kRedText = Color(0xFFB91C1C);
const _kRedBg = Color(0xFFFEE2E2);
const _kOrangeBg = Color(0xFFFFE0CC);
const _kInfoBar = Color(0xFFEFF2FB);
const _kGreyText = Color(0xFF334155);

// ---------- Model data sederhana (ganti dengan data API nanti) ----------
class _StockItem {
  final String name, badge, stockValue, eta;
  final Color badgeBg, badgeFg;
  final Color? stockColor;
  final IconData etaIcon;
  final String? imagePath; // contoh: 'assets/images/minyak.png'

  const _StockItem({
    required this.name,
    required this.badge,
    required this.badgeBg,
    required this.badgeFg,
    required this.stockValue,
    this.stockColor,
    required this.eta,
    required this.etaIcon,
    this.imagePath,
  });
}

class _ActivityItem {
  final IconData icon;
  final String title, time, badge;
  final Color badgeBg, badgeFg;

  const _ActivityItem({
    required this.icon,
    required this.title,
    required this.time,
    required this.badge,
    required this.badgeBg,
    required this.badgeFg,
  });
}

const _attention = <_StockItem>[
  _StockItem(
    name: 'Minyak Goreng Sania 2L',
    badge: 'Stok habis',
    badgeBg: _kRedBg,
    badgeFg: _kRedText,
    stockValue: '0 botol',
    stockColor: _kRedText,
    eta: 'Habis: Hari ini',
    etaIcon: Icons.event_busy_outlined,
    // imagePath: 'assets/images/minyak.png',
  ),
  _StockItem(
    name: 'Beras Premium 5 kg',
    badge: 'Segera restock',
    badgeBg: _kOrangeBg,
    badgeFg: _kRestock,
    stockValue: '4 karung',
    eta: 'Habis: dlm 2 hari (6 Apr)',
    etaIcon: Icons.schedule,
    // imagePath: 'assets/images/beras.png',
  ),
  _StockItem(
    name: 'Gula Pasir 1 kg',
    badge: 'Perlu dipantau',
    badgeBg: AppColors.chip,
    badgeFg: _kGreyText,
    stockValue: '9 kg',
    eta: 'Habis: dlm 5 hari (9 Apr)',
    etaIcon: Icons.trending_down,
    // imagePath: 'assets/images/gula.png',
  ),
];

const _activities = <_ActivityItem>[
  _ActivityItem(
    icon: Icons.point_of_sale,
    title: 'Penjualan: 3 botol Minyak Goreng',
    time: 'Hari ini, 09:30 WIB',
    badge: 'Sisa: 0 botol',
    badgeBg: _kRedBg,
    badgeFg: _kRedText,
  ),
  _ActivityItem(
    icon: Icons.move_to_inbox_outlined,
    title: 'Stok Masuk: 20 kg Gula Pasir',
    time: 'Kemarin, 14:15 WIB',
    badge: 'Sisa: 29 kg',
    badgeBg: AppColors.chip,
    badgeFg: AppColors.textDark,
  ),
];

// =====================================================================
class HomeScreens extends StatefulWidget {
  const HomeScreens({super.key});

  @override
  State<HomeScreens> createState() => _HomeScreensState();
}

class _HomeScreensState extends State<HomeScreens> {
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
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
                children: [
                  const _Greeting(),
                  const SizedBox(height: 22),
                  const _StatRow(),
                  const SizedBox(height: 22),
                  const _ActionButtons(),
                  const SizedBox(height: 32),
                  _SectionHeader(
                    title: 'Perlu Perhatian',
                    subtitle: 'Prioritas restock berdasarkan perkiraan habis',
                    action: 'Lihat Semua',
                    onAction: () {},
                  ),
                  const SizedBox(height: 16),
                  for (final item in _attention)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _ProductCard(item: item),
                    ),
                  const SizedBox(height: 16),
                  const _SectionHeader(
                    title: 'Aktivitas Terbaru',
                    action: 'Terakhir disinkronkan',
                  ),
                  const SizedBox(height: 16),
                  for (final item in _activities)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _ActivityCard(item: item),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNav(current: 0),
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

// ---------- Greeting ----------
class _Greeting extends StatelessWidget {
  const _Greeting();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Halo, Toko Berkah Jaya',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Pantauan stok dan prediksi pergerakan hari ini',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.3,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Material(
          color: AppColors.chip,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const AnalyticsScreens()),
              ),
            child: const SizedBox(
              width: 52,
              height: 52,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(Icons.bar_chart_rounded, color: AppColors.primary, size: 28)
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------- Kartu statistik ----------
class _StatRow extends StatelessWidget {
  const _StatRow();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(
          child: _StatCard(
            value: '48',
            label: 'Item aktif',
            color: AppColors.textDark,
          ),
        ),
        SizedBox(width: 14),
        Expanded(
          child: _StatCard(
            value: '3',
            label: 'Perlu restock',
            color: _kRestock,
          ),
        ),
        SizedBox(width: 14),
        Expanded(
          child: _StatCard(value: '1', label: 'Stok habis', color: _kRedText),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value, label;
  final Color color;
  const _StatCard({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 38,
              height: 1.1,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: const TextStyle(fontSize: 14, color: AppColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------- Tombol aksi ----------
class _ActionButtons extends StatelessWidget {
  const _ActionButtons();

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
    );
    const textStyle = TextStyle(fontSize: 17, fontWeight: FontWeight.w600);

    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.edit_note_rounded, size: 24),
            label: const FittedBox(child: Text('Catat Penjualan')),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.chip,
              foregroundColor: AppColors.textDark,
              minimumSize: const Size.fromHeight(60),
              textStyle: textStyle,
              shape: shape,
              elevation: 0,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: FilledButton.icon(
            onPressed: () => showStockInSheet(
              context,
              products: const [
                StockInProduct(
                    name: 'Minyak Goreng Sania 2L', unit: 'botol', suggested: 24),
                StockInProduct(
                    name: 'Beras Premium 5 kg', unit: 'karung', suggested: 15),
                StockInProduct(
                    name: 'Gula Pasir 1 kg', unit: 'kg', suggested: 25),
              ],
            ),
            icon: const Icon(Icons.add_box_outlined, size: 24),
            label: const FittedBox(child: Text('+ Stok Masuk')),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(60),
              textStyle: textStyle,
              shape: shape,
              elevation: 0,
            ),
          ),
        ),
      ],
    );
  }
}

// ---------- Judul seksi ----------
class _SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String action;
  final VoidCallback? onAction;

  const _SectionHeader({
    required this.title,
    this.subtitle,
    required this.action,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        if (onAction != null)
          InkWell(
            onTap: onAction,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
              child: Text(
                action,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          )
        else
          Text(
            action,
            style: const TextStyle(fontSize: 14, color: AppColors.textMuted),
          ),
      ],
    );
  }
}

// ---------- Kartu produk ----------
class _ProductCard extends StatelessWidget {
  final _StockItem item;
  const _ProductCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: 56,
      height: 56,
      color: AppColors.chip,
      child: const Icon(Icons.shopping_bag_outlined, color: AppColors.hint),
    );

    return _SoftCard(
      onTap: () {},
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: item.imagePath == null
                  ? placeholder
                  : Image.asset(
                      item.imagePath!,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => placeholder,
                    ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _Pill(text: item.badge, bg: item.badgeBg, fg: item.badgeFg),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: _kInfoBar,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text.rich(
                        TextSpan(
                          style: const TextStyle(
                            fontSize: 15,
                            color: AppColors.textMuted,
                          ),
                          children: [
                            const TextSpan(text: 'Sisa: '),
                            TextSpan(
                              text: item.stockValue,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: item.stockColor ?? AppColors.textDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              item.etaIcon,
                              size: 18,
                              color: AppColors.textMuted,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                item.eta,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------- Kartu aktivitas ----------
class _ActivityCard extends StatelessWidget {
  final _ActivityItem item;
  const _ActivityCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.chip,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(item.icon, color: AppColors.textDark),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.time,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _Pill(
            text: item.badge,
            bg: item.badgeBg,
            fg: item.badgeFg,
            bold: true,
          ),
        ],
      ),
    );
  }
}

// ---------- Label kecil (badge) ----------
class _Pill extends StatelessWidget {
  final String text;
  final Color bg, fg;
  final bool bold;
  const _Pill({
    required this.text,
    required this.bg,
    required this.fg,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          fontWeight: bold ? FontWeight.w600 : FontWeight.w500,
          color: fg,
        ),
      ),
    );
  }
}
