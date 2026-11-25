import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/theme/app_colors.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/dashboard/data/models/home_data.dart';
import '../../features/dashboard/data/repositories/dashboard_repository.dart';
import '../../features/products/data/models/product_overview.dart';
import '../../features/products/data/repositories/product_repository.dart';
import '../widgets/app_shell.dart';
import '../widgets/sale_entry_sheet.dart';
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

  /// Data terakhir yang berhasil dimuat. Dipakai sebagai `initialData`
  /// supaya saat menyegarkan, isi beranda tetap tampil (tidak berkedip
  /// menjadi spinner) sampai data baru tiba.
  HomeData? _lastData;

  @override
  void initState() {
    super.initState();
    _repository = context.read<DashboardRepository>();
    _homeFuture = _load();
  }

  Future<HomeData> _load() async {
    final data = await _repository.fetchHome();
    _lastData = data;
    return data;
  }

  void _reload() {
    setState(() {
      _homeFuture = _load();
    });
  }

  /// Dipakai RefreshIndicator: menunggu permintaan selesai agar indikator
  /// berhenti tepat saat data baru tampil.
  Future<void> _refresh() async {
    final future = _load();
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
      backgroundColor: AppColors.backgroundOf(context),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const AppTopBar(),
            Expanded(
              child: FutureBuilder<HomeData>(
                future: _homeFuture,
                initialData: _lastData,
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
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      children: [
                        const _Greeting(),
                        const SizedBox(height: 12),
                        _StatRow(summary: data.summary),
                        const SizedBox(height: 12),
                        _ActionButtons(onDataChanged: _reload),
                        const SizedBox(height: 16),
                        _SectionHeader(
                          title: 'Perlu Perhatian',
                          subtitle:
                              'Prioritas restock berdasarkan perkiraan habis',
                          action: 'Lihat Semua',
                          onAction: _openProducts,
                        ),
                        const SizedBox(height: 10),
                        if (data.attention.isEmpty)
                          const _EmptyHint(
                            icon: Icons.check_circle_outline,
                            message: 'Semua stok dalam kondisi aman.',
                          )
                        else
                          for (final product in data.attention)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _ProductCard(product: product),
                            ),
                        const SizedBox(height: 10),
                        const _SectionHeader(
                          title: 'Aktivitas Terbaru',
                          action: 'Terakhir disinkronkan',
                        ),
                        const SizedBox(height: 10),
                        if (data.activities.isEmpty)
                          const _EmptyHint(
                            icon: Icons.history,
                            message: 'Belum ada aktivitas stok.',
                          )
                        else
                          for (final activity in data.activities)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
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

// ---------- Kartu dasar (adaptif Light & Dark Mode) ----------
class _SoftCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  const _SoftCard({
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: padding,
      radius: 6,
      onTap: onTap,
      child: child,
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
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimaryOf(context),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Pantauan stok & prediksi hari ini',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: AppColors.textSecondaryOf(context),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Material(
          color: AppColors.surfaceSecondaryOf(context),
          borderRadius: BorderRadius.circular(6),
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const AnalyticsScreens()),
            ),
            child: SizedBox(
              width: 36,
              height: 36,
              child: Icon(
                Icons.bar_chart_rounded,
                color: AppColors.primaryOf(context),
                size: 20,
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
            color: AppColors.textPrimaryOf(context),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatCard(
            value: '${summary.needRestock}',
            label: 'Perlu restock',
            color: AppColors.warningOf(context),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatCard(
            value: '${summary.outOfStock}',
            label: 'Stok habis',
            color: AppColors.dangerOf(context),
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
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              height: 1.2,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondaryOf(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------- Tombol aksi ----------
class _ActionButtons extends StatefulWidget {
  const _ActionButtons({required this.onDataChanged});

  /// Dipanggil setelah penjualan/stok masuk tersimpan agar angka ringkasan
  /// dan daftar aktivitas ikut diperbarui.
  final VoidCallback onDataChanged;

  @override
  State<_ActionButtons> createState() => _ActionButtonsState();
}

class _ActionButtonsState extends State<_ActionButtons> {
  bool _busy = false;

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

  String _errorText(Object error, String fallback) {
    if (error is ProductFailure) return error.message;
    return '$fallback $error';
  }

  /// Memuat produk aktif terbaru dari Supabase.
  Future<List<ProductOverview>> _loadActiveProducts(
    ProductRepository repository,
  ) async {
    final products = await repository.fetchProducts();
    return products.where((product) => product.isActive).toList();
  }

  Future<void> _recordSale() async {
    if (_busy) return;
    final repository = context.read<ProductRepository>();
    setState(() => _busy = true);
    try {
      final products = (await _loadActiveProducts(repository))
          .where((product) => product.currentStock > 0)
          .toList();
      if (!mounted) return;
      if (products.isEmpty) {
        _showMessage(
          'Belum ada produk aktif yang stoknya tersedia.',
          isError: true,
        );
        return;
      }

      final result = await showSaleEntrySheet(
        context,
        products: [
          for (final product in products)
            SaleEntryProduct(
              id: product.id,
              name: product.name,
              unit: product.unit,
              availableStock: product.currentStock,
            ),
        ],
      );
      if (result == null || !mounted) return;

      final productId = result.product.id;
      if (productId == null) {
        _showMessage(
          'Produk tidak dikenali. Muat ulang beranda.',
          isError: true,
        );
        return;
      }

      await repository.recordSale(
        productId: productId,
        quantity: result.quantity,
        transactionDate: result.dateTime,
      );
      if (!mounted) return;

      _showMessage(
        'Penjualan ${result.quantity} ${result.product.unit} '
        '${result.product.name} tersimpan.',
      );
      widget.onDataChanged();
    } catch (error) {
      if (!mounted) return;
      _showMessage(
        _errorText(error, 'Gagal mencatat penjualan:'),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _recordStockIn() async {
    if (_busy) return;
    final repository = context.read<ProductRepository>();
    setState(() => _busy = true);
    try {
      final products = await _loadActiveProducts(repository);
      if (!mounted) return;
      if (products.isEmpty) {
        _showMessage(
          'Belum ada produk aktif. Tambahkan produk lebih dulu.',
          isError: true,
        );
        return;
      }

      final result = await showStockInSheet(
        context,
        products: [
          for (final product in products)
            StockInProduct(
              id: product.id,
              name: product.name,
              unit: product.unit,
            ),
        ],
      );
      if (result == null || !mounted) return;

      final productId = result.product.id;
      if (productId == null) {
        _showMessage(
          'Produk tidak dikenali. Muat ulang beranda.',
          isError: true,
        );
        return;
      }

      await repository.recordStockIn(
        productId: productId,
        quantity: result.quantity,
      );
      if (!mounted) return;

      _showMessage(
        'Stok masuk ${result.quantity} ${result.product.unit} '
        '${result.product.name} tersimpan.',
      );
      widget.onDataChanged();
    } catch (error) {
      if (!mounted) return;
      _showMessage(
        _errorText(error, 'Gagal mencatat stok masuk:'),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(6),
    );
    const textStyle = TextStyle(fontSize: 14, fontWeight: FontWeight.w500);
    final secondaryBg = AppColors.surfaceSecondaryOf(context);
    final textColor = AppColors.textPrimaryOf(context);
    final hintColor = AppColors.textHintOf(context);

    return Row(
      children: [
        Expanded(
          child: FilledButton(
            onPressed: _busy ? null : _recordSale,
            style: FilledButton.styleFrom(
              backgroundColor: secondaryBg,
              foregroundColor: textColor,
              disabledBackgroundColor: secondaryBg,
              disabledForegroundColor: hintColor,
              minimumSize: const Size.fromHeight(40),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              textStyle: textStyle,
              shape: shape,
              elevation: 0,
            ),
            child: const FittedBox(child: Text('Catat Penjualan')),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: FilledButton(
            onPressed: _busy ? null : _recordStockIn,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: secondaryBg,
              disabledForegroundColor: hintColor,
              minimumSize: const Size.fromHeight(40),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              textStyle: textStyle,
              shape: shape,
              elevation: 0,
            ),
            child: const FittedBox(child: Text('+ Stok Masuk')),
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
    final textPrimary = AppColors.textPrimaryOf(context);
    final textMuted = AppColors.textSecondaryOf(context);
    final primary = AppColors.primaryOf(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: textPrimary,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: 12,
                    color: textMuted,
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
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
              child: Text(
                action,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: primary,
                ),
              ),
            ),
          )
        else
          Text(
            action,
            style: TextStyle(fontSize: 12, color: textMuted),
          ),
      ],
    );
  }
}

// ---------- Kartu produk (Figma: Name + Pill, Meta, Progress Track) ----------
class _ProductCard extends StatelessWidget {
  final ProductOverview product;
  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final style = _statusStyle(context, product.status);
    final textPrimary = AppColors.textPrimaryOf(context);
    final textMuted = AppColors.textSecondaryOf(context);
    final trackBg = AppColors.surfaceSecondaryOf(context);

    // Hitung rasio bar stok terhadap ambang batas (maks 1.0)
    final threshold = product.reorderThreshold > 0 ? product.reorderThreshold : 10;
    final ratio = (product.currentStock / (threshold * 2)).clamp(0.06, 1.0);

    return _SoftCard(
      padding: const EdgeInsets.all(12),
      onTap: () => Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ProductScreens()),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _Pill(text: style.label, bg: style.bg, fg: style.fg),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Stok ${product.currentStock} ${product.unit}  •  ${_etaText(product)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: textMuted,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: product.currentStock <= 0 ? 0.04 : ratio,
              minHeight: 4,
              backgroundColor: trackBg,
              valueColor: AlwaysStoppedAnimation<Color>(style.fg),
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
    final textPrimary = AppColors.textPrimaryOf(context);
    final textMuted = AppColors.textSecondaryOf(context);
    final chipBg = AppColors.surfaceSecondaryOf(context);

    return _SoftCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: chipBg,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              _activityIcon(activity.movementType),
              color: textPrimary,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${activity.label}: ${activity.quantity} ${activity.unit} '
                  '${activity.productName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatActivityTime(activity.createdAt),
                  style: TextStyle(
                    fontSize: 12,
                    color: textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _Pill(
            text: 'Sisa: ${activity.stockAfter}',
            bg: isOutOfStock ? AppColors.dangerBgOf(context) : chipBg,
            fg: isOutOfStock ? AppColors.dangerOf(context) : textPrimary,
          ),
        ],
      ),
    );
  }
}

// ---------- Label kecil (badge Figma radius 6px) ----------
class _Pill extends StatelessWidget {
  final String text;
  final Color bg, fg;
  const _Pill({
    required this.text,
    required this.bg,
    required this.fg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.2,
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
          Icon(icon, size: 36, color: AppColors.textHintOf(context)),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondaryOf(context),
            ),
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
            Icon(
              Icons.cloud_off_outlined,
              color: AppColors.dangerOf(context),
              size: 40,
            ),
            const SizedBox(height: 12),
            Text(
              'Beranda belum dapat dimuat',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimaryOf(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondaryOf(context)),
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

_StatusStyle _statusStyle(BuildContext context, ProductStockStatus status) {
  switch (status) {
    case ProductStockStatus.outOfStock:
      return _StatusStyle(
        'Stok habis',
        AppColors.dangerBgOf(context),
        AppColors.dangerOf(context),
      );
    case ProductStockStatus.restock:
      return _StatusStyle(
        'Segera restock',
        AppColors.warningBgOf(context),
        AppColors.warningOf(context),
      );
    case ProductStockStatus.monitor:
      return _StatusStyle(
        'Perlu dipantau',
        AppColors.surfaceSecondaryOf(context),
        AppColors.textSecondaryOf(context),
      );
    case ProductStockStatus.safe:
      return _StatusStyle(
        'Stok aman',
        AppColors.successBgOf(context),
        AppColors.successOf(context),
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
