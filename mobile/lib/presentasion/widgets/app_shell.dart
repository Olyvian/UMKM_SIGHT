import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/theme/app_colors.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../screens/analytics_screens.dart';
import '../screens/home_screens.dart';
import '../screens/product_screens.dart';
import '../screens/profile_screens.dart';
import '../screens/transaction_screens.dart';

// =====================================================================
// Widget bersama untuk semua halaman utama (Figma "Rapi & Padat" + Dark Mode).
// Simpan di: lib/presentasion/widgets/app_shell.dart
// =====================================================================

/// Kartu dengan garis tepi crisp (radius 6px sesuai Figma) & adaptif Dark Mode.
class SoftCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;

  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.radius = 6,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    final surfaceColor = AppColors.surfaceOf(context);
    final borderColor = AppColors.borderOf(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: r,
        border: Border.all(color: borderColor, width: 1),
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

/// Bar atas sesuai komponen `C / TopBar` di Figma:
/// Kotak logo toko, label "TOKO UMKM", nama toko, lonceng, dan avatar inisial.
class AppTopBar extends StatelessWidget {
  const AppTopBar({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.select((AuthBloc bloc) => bloc.state.user);
    final storeName = user?.store?.storeName;
    final title = (storeName == null || storeName.trim().isEmpty)
        ? 'Toko Saya'
        : storeName;
    final initial = (user?.name.trim().isNotEmpty ?? false)
        ? user!.name.trim()[0].toUpperCase()
        : 'O';

    final surfaceColor = AppColors.surfaceOf(context);
    final secondaryBg = AppColors.surfaceSecondaryOf(context);
    final textColor = AppColors.textPrimaryOf(context);
    final mutedColor = AppColors.textSecondaryOf(context);
    final borderColor = AppColors.borderOf(context);
    final primaryColor = AppColors.primaryOf(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border(bottom: BorderSide(color: borderColor, width: 1)),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: secondaryBg,
                borderRadius: BorderRadius.circular(6),
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.storefront_rounded,
                color: primaryColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'TOKO UMKM',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.8,
                      color: mutedColor,
                      height: 1.4,
                    ),
                  ),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: textColor,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.notifications_none_rounded,
                color: mutedColor,
                size: 20,
              ),
              onPressed: () {},
              tooltip: 'Notifikasi',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
            const SizedBox(width: 6),
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (_, __, ___) => const ProfileScreens(),
                    transitionDuration: Duration.zero,
                  ),
                );
              },
              borderRadius: BorderRadius.circular(6),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.center,
                child: Text(
                  initial,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Navigation Bar bawah sesuai Figma (`C / BottomNav`).
class AppBottomNav extends StatelessWidget {
  final int currentIndex;

  const AppBottomNav({
    super.key,
    int? currentIndex,
    int? current,
  }) : currentIndex = currentIndex ?? current ?? 0;

  void _onItemTapped(BuildContext context, int index) {
    if (index == currentIndex) return;

    final Widget page;
    switch (index) {
      case 0:
        page = const HomeScreens();
        break;
      case 1:
        page = const ProductScreens();
        break;
      case 2:
        page = const TransactionScreens();
        break;
      case 3:
        page = const AnalyticsScreens();
        break;
      default:
        return;
    }

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => page,
        transitionDuration: Duration.zero,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final surfaceColor = AppColors.surfaceOf(context);
    final borderColor = AppColors.borderOf(context);
    final unselectedColor = AppColors.textSecondaryOf(context);
    final activeColor = AppColors.primaryOf(context);

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border(top: BorderSide(color: borderColor, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: NavigationBar(
          height: 64,
          selectedIndex: currentIndex,
          onDestinationSelected: (i) => _onItemTapped(context, i),
          backgroundColor: Colors.transparent,
          elevation: 0,
          indicatorColor: activeColor.withValues(alpha: 0.12),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
            NavigationDestination(
              icon: Icon(Icons.home_outlined, color: unselectedColor, size: 20),
              selectedIcon:
                  Icon(Icons.home_rounded, color: activeColor, size: 20),
              label: 'Beranda',
            ),
            NavigationDestination(
              icon: Icon(Icons.inventory_2_outlined,
                  color: unselectedColor, size: 20),
              selectedIcon:
                  Icon(Icons.inventory_2_rounded, color: activeColor, size: 20),
              label: 'Produk',
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined,
                  color: unselectedColor, size: 20),
              selectedIcon: Icon(Icons.receipt_long_rounded,
                  color: activeColor, size: 20),
              label: 'Transaksi',
            ),
            NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined,
                  color: unselectedColor, size: 20),
              selectedIcon:
                  Icon(Icons.bar_chart_rounded, color: activeColor, size: 20),
              label: 'Analitik',
            ),
          ],
        ),
      ),
    );
  }
}
