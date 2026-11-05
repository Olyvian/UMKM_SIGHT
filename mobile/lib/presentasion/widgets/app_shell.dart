import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../screens/analytics_screens.dart';
import '../screens/home_screens.dart';
import '../screens/product_screens.dart';
import '../screens/transaction_screens.dart';
// =====================================================================
// Widget bersama untuk semua halaman utama.
// Simpan di: lib/presentasion/widgets/app_shell.dart
// =====================================================================

/// Kartu putih dengan bayangan lembut dan efek ripple saat disentuh.
class SoftCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;

  const SoftCard({
    super.key,
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

/// Bar atas: logo toko, nama toko, lonceng notifikasi, dan avatar.
class AppTopBar extends StatelessWidget {
  const AppTopBar({super.key});

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

/// Navigasi bawah. Cukup panggil `AppBottomNav(current: n)` di tiap halaman:
/// 0 = Beranda, 1 = Produk, 2 = Transaksi, 3 = Analitik.
class AppBottomNav extends StatelessWidget {
  final int current;
  const AppBottomNav({super.key, required this.current});

  void _go(BuildContext context, int target) {
    if (target == current) return;

    final Widget? page = switch (target) {
      0 => const HomeScreens(),
      1 => const ProductScreens(),
      2 => const TransactionScreens(),
      3 => const AnalyticsScreens(),
      _ => null, // Transaksi belum dibuat
    };

    if (page == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Halaman ini belum tersedia')),
      );
      return;
    }

    // Tanpa animasi supaya terasa seperti berpindah tab.
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => page,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: current,
        onTap: (i) => _go(context, i),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textMuted,
        selectedFontSize: 13,
        unselectedFontSize: 13,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home_rounded),
            label: 'Beranda',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2_outlined),
            activeIcon: Icon(Icons.inventory_2_rounded),
            label: 'Produk',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined),
            activeIcon: Icon(Icons.receipt_long_rounded),
            label: 'Transaksi',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.show_chart),
            activeIcon: Icon(Icons.show_chart),
            label: 'Analitik',
          ),
        ],
      ),
    );
  }
}
