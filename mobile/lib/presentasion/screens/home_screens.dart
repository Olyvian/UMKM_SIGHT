import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/theme/app_colors.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/dashboard/data/models/home_data.dart';
import '../../features/dashboard/data/repositories/dashboard_repository.dart';
import '../../features/products/data/models/product_overview.dart';
import '../widgets/app_shell.dart';
import '../widgets/stock_in_sheet.dart';
import 'analytics_screens.dart';
import 'product_screens.dart';

// ---------- Warna tambahan khusus halaman ini ----------
const _kRestock = Color(0xFF9A3412);
const _kRedText = Color(0xFFB91C1C);
const _kRedBg = Color(0xFFFEE2E2);
const _kOrangeBg = Color(0xFFFFE0CC);
const _kInfoBar = Color(0xFFEFF2FB);
const _kGreyText = Color(0xFF334155);

const _months = [
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

// =====================================================================
class HomeScreens extends StatefulWidget {
  const HomeScreens({super.key});

  @override
  State<HomeScreens> createState() => _HomeScreensState();
}

class _HomeScreensState extends State<HomeScreens> {
  late final DashboardRepository _repository;
  late Future<HomeData> _homeFuture;

  @override
  void initState() {
    super.initState();
    _repository = context.read<DashboardRepository>();
    _homeFuture = _repository.fetchHome();
  }

  void _reload() {
    setState(() {
      _homeFuture = _repository.fetchHome();
    });
  }

  /// Dipakai RefreshIndicator: menunggu permintaan selesai agar indikator
  /// berhenti tepat saat data baru tampil.
  Future<void> _refresh() async {
    final future = _repository.fetchHome();
    setState(() => _homeFuture = future);
    try {
      await future;
    } catch (_) {
      // Pesan galat ditampilkan oleh FutureBuilder.
    }
  }

  void _openProducts() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const ProductScreens()),
    );
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
              child: FutureBuilder<HomeData>(
                future: _homeFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return _LoadError(
                      message: snapshot.error.toString(),
                      onRetry: _reload,
                    );
                  }

                  final data = snapshot.data!;
                  return RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
                      children: [
                        const _Greeting(),
                        const SizedBox(height: 22),
                        _StatRow(summary: data.summary),
                        const SizedBox(height: 22),
                        const _ActionButtons(),
                        const SizedBox(height: 32),
                        _SectionHeader(
                          title: 'Perlu Perhatian',
                          subtitle:
                              'Prioritas restock berdasarkan perkiraan habis',
                          action: 'Lihat Semua',
                          onAction: _openProducts,
                        ),
                        const SizedBox(height: 16),
                        if (data.attention.isEmpty)
                          const _EmptyHint(
                            icon: Icons.check_circle_outline,
                            message: 'Semua stok dalam kondisi aman.',
                          )
                        else
                          for (final product in data.attention)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: _ProductCard(product: product),
                            ),
                        const SizedBox(height: 16),
                        const _SectionHeader(
                          title: 'Aktivitas Terbaru',
                          action: 'Terakhir disinkronkan',
                        ),
                        const SizedBox(height: 16),
                        if (data.activities.isEmpty)
                          const _EmptyHint(
                            icon: Icons.history,
                            message: 'Belum ada aktivitas stok.',
                          )
                        else
                          for (final activity in data.activities)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: _ActivityCard(activity: activity),
                            ),
                      ],
                    ),
                  );
                },
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
  final VoidCallback? onTap;

  const _SoftCard({
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(24);
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

// ---------- Greeting ----------
class _Greeting extends StatelessWidget {
  const _Greeting();

  @override
  Widget build(BuildContext context) {
    final name = context.select((AuthBloc bloc) => bloc.state.user?.name);
    final greeting =
        (name == null || name.trim().isEmpty) ? 'Pemilik Toko' : name;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Halo, $greeting',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
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
                  Icon(Icons.bar_chart_rounded,
                      color: AppColors.primary, size: 28)
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
  const _StatRow({required this.summary});

  final HomeSummary summary;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            value: '${summary.activeItems}',
            label: 'Item aktif',
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _StatCard(
            value: '${summary.needRestock}',
            label: 'Perlu restock',
            color: _kRestock,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _StatCard(
            value: '${summary.outOfStock}',
            label: 'Stok habis',
            color: _kRedText,
          ),
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
            // TODO(langkah 5): sambungkan ke RPC record_sale.
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
            // TODO(langkah 5): ganti daftar contoh ini dengan produk dari
            // Supabase dan simpan lewat RPC record_stock_in.
            onPressed: () => showStockInSheet(
              context,
              products: const [
                StockInProduct(
                    name: 'Minyak Goreng Sania 2L',
                    unit: 'botol',
                    suggested: 24),
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
  final ProductOverview product;
  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final style = _statusStyle(product.status);
    final stockColor = product.currentStock == 0
        ? _kRedText
        : (product.status == ProductStockStatus.restock ? _kRestock : null);

    return _SoftCard(
      onTap: () => Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ProductScreens()),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 56,
                height: 56,
                color: AppColors.chip,
                child: const Icon(
                  Icons.shopping_bag_outlined,
                  color: AppColors.hint,
                ),
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
                        product.name,
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
                    _Pill(text: style.label, bg: style.bg, fg: style.fg),
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
                              text:
                                  '${product.currentStock} ${product.unit}',
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
                            Icon(
                              _etaIcon(product),
                              size: 18,
                              color: AppColors.textMuted,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                _etaText(product),
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
  final StockActivity activity;
  const _ActivityCard({required this.activity});

  @override
  Widget build(BuildContext context) {
    final isOutOfStock = activity.stockAfter == 0;

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
            child: Icon(_activityIcon(activity.movementType),
                color: AppColors.textDark),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${activity.label}: ${activity.quantity} ${activity.unit} '
                  '${activity.productName}',
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
                  _formatActivityTime(activity.createdAt),
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
            text: 'Sisa: ${activity.stockAfter} ${activity.unit}',
            bg: isOutOfStock ? _kRedBg : AppColors.chip,
            fg: isOutOfStock ? _kRedText : AppColors.textDark,
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

// ---------- Kondisi kosong & galat ----------
class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          Icon(icon, size: 40, color: AppColors.hint),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
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
              'Beranda belum dapat dimuat',
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

// ---------- Pemetaan status & prediksi ke tampilan ----------
class _StatusStyle {
  const _StatusStyle(this.label, this.bg, this.fg);

  final String label;
  final Color bg;
  final Color fg;
}

_StatusStyle _statusStyle(ProductStockStatus status) {
  switch (status) {
    case ProductStockStatus.outOfStock:
      return const _StatusStyle('Stok habis', _kRedBg, _kRedText);
    case ProductStockStatus.restock:
      return const _StatusStyle('Segera restock', _kOrangeBg, _kRestock);
    case ProductStockStatus.monitor:
      return const _StatusStyle('Perlu dipantau', AppColors.chip, _kGreyText);
    case ProductStockStatus.safe:
      return const _StatusStyle('Stok aman', AppColors.chip, _kGreyText);
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

IconData _activityIcon(String movementType) {
  return switch (movementType) {
    'OUT' => Icons.point_of_sale,
    'IN' => Icons.move_to_inbox_outlined,
    _ => Icons.tune_rounded,
  };
}

String _formatActivityTime(DateTime time) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final date = DateTime(time.year, time.month, time.day);
  final clock = '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}';

  final day = switch (today.difference(date).inDays) {
    0 => 'Hari ini',
    1 => 'Kemarin',
    _ => '${time.day} ${_months[time.month - 1]} ${time.year}',
  };

  return '$day, $clock WIB';
}
