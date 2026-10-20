import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'product_screens.dart';

// Warna tambahan khusus halaman ini (tidak ada di AppColors)
const _kRestock = Color(0xFF9A3412);
const _kRedText = Color(0xFFB91C1C);
const _kRedBg = Color(0xFFFEE2E2);
const _kOrangeBg = Color(0xFFFFE0CC);
const _kInfoBar = Color(0xFFEFF2FB);

class HomeScreens extends StatefulWidget {
  const HomeScreens({super.key});

  @override
  State<HomeScreens> createState() => _HomeScreensState();
}

class _HomeScreensState extends State<HomeScreens> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const _TopBar(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                children: [
                  const _Greeting(),
                  const SizedBox(height: 20),
                  const _StatRow(),
                  const SizedBox(height: 20),
                  const _ActionButtons(),
                  const SizedBox(height: 28),
                  _SectionHeader(
                    title: 'Perlu Perhatian',
                    subtitle: 'Prioritas restock berdasarkan perkiraan habis',
                    action: 'Lihat Semua',
                    onAction: () {},
                  ),
                  const SizedBox(height: 14),
                  const _ProductCard(
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
                  const _ProductCard(
                    name: 'Beras Premium 5 kg',
                    badge: 'Segera restock',
                    badgeBg: _kOrangeBg,
                    badgeFg: _kRestock,
                    stockValue: '4 karung',
                    eta: 'Habis: dlm 2 hari (6 Apr)',
                    etaIcon: Icons.schedule,
                    // imagePath: 'assets/images/beras.png',
                  ),
                  const _ProductCard(
                    name: 'Gula Pasir 1 kg',
                    badge: 'Perlu dipantau',
                    badgeBg: AppColors.chip,
                    badgeFg: Color(0xFF334155),
                    stockValue: '9 kg',
                    eta: 'Habis: dlm 5 hari (9 Apr)',
                    etaIcon: Icons.trending_down,
                    // imagePath: 'assets/images/gula.png',
                  ),
                  const SizedBox(height: 12),
                  const _SectionHeader(
                    title: 'Aktivitas Terbaru',
                    action: 'Terakhir disinkronkan',
                  ),
                  const SizedBox(height: 14),
                  const _ActivityCard(
                    icon: Icons.point_of_sale,
                    title: 'Penjualan: 3 botol Minyak Goreng',
                    time: 'Hari ini, 09:30 WIB',
                    badge: 'Sisa: 0 botol',
                    badgeBg: _kRedBg,
                    badgeFg: _kRedText,
                  ),
                  const _ActivityCard(
                    icon: Icons.move_to_inbox_outlined,
                    title: 'Stok Masuk: 20 kg Gula Pasir',
                    time: 'Kemarin, 14:15 WIB',
                    badge: 'Sisa: 29 kg',
                    badgeBg: AppColors.chip,
                    badgeFg: AppColors.textDark,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tab,
            onTap: (i) {
      if (i == 1) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ProductScreens()),
        );
      } else {
        setState(() => _tab = i);
      }
    },
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textMuted,
        selectedFontSize: 13,
        unselectedFontSize: 13,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Beranda'),
          BottomNavigationBarItem(
              icon: Icon(Icons.inventory_2_outlined), label: 'Produk'),
          BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long_outlined), label: 'Transaksi'),
          BottomNavigationBarItem(
              icon: Icon(Icons.show_chart), label: 'Analitik'),
        ],
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
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF0FB),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.storefront_outlined,
                color: AppColors.primary),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('TOKO UMKM',
                    style: TextStyle(
                        fontSize: 13,
                        letterSpacing: 1.2,
                        color: AppColors.textMuted)),
                Text('Toko Berkah Jaya',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark)),
              ],
            ),
          ),
          const Icon(Icons.notifications_none,
              color: AppColors.textMuted, size: 28),
          const SizedBox(width: 20),
          const CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.primary,
            child: Icon(Icons.person_outline, color: Colors.white),
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
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Flexible(
                    child: Text('Halo, Toko Berkah Jaya',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark)),
                  ),
                  const SizedBox(width: 6),
                ],
              ),
              const SizedBox(height: 4),
              const Text('Pantauan stok dan prediksi pergerakan hari ini',
                  style: TextStyle(fontSize: 14, color: AppColors.textMuted)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.chip,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.notifications_none,
                  color: AppColors.textDark),
            ),
            Positioned(
              right: 12,
              top: 10,
              child: Container(
                width: 11,
                height: 11,
                decoration: const BoxDecoration(
                    color: AppColors.error, shape: BoxShape.circle),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ---------- Stat cards ----------
class _StatRow extends StatelessWidget {
  const _StatRow();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(
            child: _StatCard(
                value: '48', label: 'Item aktif', color: AppColors.textDark)),
        SizedBox(width: 14),
        Expanded(
            child: _StatCard(
                value: '3', label: 'Perlu restock', color: _kRestock)),
        SizedBox(width: 14),
        Expanded(
            child:
                _StatCard(value: '1', label: 'Stok habis', color: _kRedText)),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value, label;
  final Color color;
  const _StatCard(
      {required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 38, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(label,
                style:
                    const TextStyle(fontSize: 14, color: AppColors.textMuted)),
          ),
        ],
      ),
    );
  }
}

// ---------- Action buttons ----------
class _ActionButtons extends StatelessWidget {
  const _ActionButtons();

  @override
  Widget build(BuildContext context) {
    final shape =
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(20));
    const textStyle = TextStyle(fontSize: 17, fontWeight: FontWeight.w600);

    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.edit_note, size: 24),
            label: const FittedBox(child: Text('Catat Penjualan')),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.chip,
              foregroundColor: AppColors.textDark,
              minimumSize: const Size.fromHeight(60),
              textStyle: textStyle,
              shape: shape,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: FilledButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.add_box_outlined, size: 24),
            label: const FittedBox(child: Text('+ Stok Masuk')),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(60),
              textStyle: textStyle,
              shape: shape,
            ),
          ),
        ),
      ],
    );
  }
}

// ---------- Section header ----------
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
              Text(title,
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark)),
              if (subtitle != null)
                Text(subtitle!,
                    style: const TextStyle(
                        fontSize: 14, color: AppColors.textMuted)),
            ],
          ),
        ),
        onAction != null
            ? GestureDetector(
                onTap: onAction,
                child: Text(action,
                    style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary)),
              )
            : Text(action,
                style:
                    const TextStyle(fontSize: 15, color: AppColors.textMuted)),
      ],
    );
  }
}

// ---------- Product card ----------
class _ProductCard extends StatelessWidget {
  final String name, badge, stockValue, eta;
  final Color badgeBg, badgeFg;
  final Color? stockColor;
  final IconData etaIcon;
  final String? imagePath; // contoh: 'assets/images/minyak.png'

  const _ProductCard({
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

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: 56,
      height: 56,
      color: AppColors.chip,
      child: const Icon(Icons.shopping_bag_outlined, color: AppColors.hint),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: imagePath == null
                  ? placeholder
                  : Image.asset(
                      imagePath!,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => placeholder,
                    ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textDark)),
                    ),
                    const SizedBox(width: 8),
                    _Pill(text: badge, bg: badgeBg, fg: badgeFg),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                              fontSize: 15, color: AppColors.textMuted),
                          children: [
                            const TextSpan(text: 'Sisa: '),
                            TextSpan(
                              text: stockValue,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: stockColor ?? AppColors.textDark,
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
                            Icon(etaIcon, size: 18, color: AppColors.textMuted),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(eta,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 15,
                                      color: AppColors.textMuted)),
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

// ---------- Activity card ----------
class _ActivityCard extends StatelessWidget {
  final IconData icon;
  final String title, time, badge;
  final Color badgeBg, badgeFg;

  const _ActivityCard({
    required this.icon,
    required this.title,
    required this.time,
    required this.badge,
    required this.badgeBg,
    required this.badgeFg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.chip,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: AppColors.textDark),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark)),
                const SizedBox(height: 2),
                Text(time,
                    style: const TextStyle(
                        fontSize: 15, color: AppColors.textMuted)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _Pill(text: badge, bg: badgeBg, fg: badgeFg, bold: true),
        ],
      ),
    );
  }
}

// ---------- Helpers ----------
class _Pill extends StatelessWidget {
  final String text;
  final Color bg, fg;
  final bool bold;
  const _Pill(
      {required this.text,
      required this.bg,
      required this.fg,
      this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(text,
          style: TextStyle(
              fontSize: 14,
              fontWeight: bold ? FontWeight.w600 : FontWeight.w500,
              color: fg)),
    );
  }
}

BoxDecoration _cardDecoration() => BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(24),
      boxShadow: const [
        BoxShadow(color: AppColors.shadow, blurRadius: 12, offset: Offset(0, 3)),
      ],
    );