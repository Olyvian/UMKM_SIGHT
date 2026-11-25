import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/theme/app_colors.dart';
import '../../features/analytics/data/models/forecast_model.dart';
import '../../features/analytics/data/repositories/forecast_repository.dart';
import '../../features/products/data/models/product_overview.dart';
import '../../features/products/data/repositories/product_repository.dart';
import '../widgets/app_shell.dart';
import 'product_detail_screens.dart';

// ---------- Warna tambahan khusus halaman ini ----------
const _kBrown = Color(0xFF9A3412);
const _kOrangeBg = Color(0xFFFFE0CC);
const _kRedText = Color(0xFFB91C1C);
const _kRedBg = Color(0xFFFEE2E2);
const _kGreen = Color(0xFF15803D);
const _kGreenBg = Color(0xFFDCFCE7);
const _kGrey = Color(0xFF334155);
const _kBox = Color(0xFFEFF2FB);
const _kBadgeBlue = Color(0xFFE0E7FF);

const _kDefaultAlgorithm = 'ARIMA (Autoregressive Integrated Moving Average)';

// ---------- Helper tanggal ----------
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

String _fmt(DateTime d, {bool year = false}) =>
    '${d.day} ${_months[d.month - 1]}${year ? ' ${d.year}' : ''}';

({String label, Color fg, Color bg}) _priority(int? daysLeft) {
  if (daysLeft == null) {
    return (label: 'Stok aman', fg: _kGreen, bg: _kGreenBg);
  }
  if (daysLeft <= 0) return (label: 'Stok habis', fg: _kRedText, bg: _kRedBg);
  if (daysLeft <= 3) {
    return (label: 'Prioritas tinggi', fg: _kBrown, bg: _kOrangeBg);
  }
  if (daysLeft <= 7) {
    return (label: 'Perlu dipantau', fg: _kGrey, bg: AppColors.chip);
  }
  return (label: 'Stok aman', fg: _kGreen, bg: _kGreenBg);
}

// =====================================================================
class AnalyticsScreens extends StatefulWidget {
  const AnalyticsScreens({super.key});

  @override
  State<AnalyticsScreens> createState() => _AnalyticsScreensState();
}

class _AnalyticsScreensState extends State<AnalyticsScreens> {
  bool _loading = true;
  String? _errorMessage;

  List<ProductOverview> _products = [];
  int _productIdx = 0;
  int _horizon = 7;

  Forecast? _currentForecast;
  List<double> _actualSales = [0, 0, 0, 0, 0, 0, 0];
  bool _loadingForecast = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final productRepo = context.read<ProductRepository>();
      final products = await productRepo.fetchProducts();

      if (!mounted) return;

      if (products.isEmpty) {
        setState(() {
          _products = [];
          _loading = false;
        });
        return;
      }

      setState(() {
        _products = products;
        if (_productIdx >= products.length) {
          _productIdx = 0;
        }
      });

      await _loadForecastForProduct(products[_productIdx]);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadForecastForProduct(ProductOverview product) async {
    setState(() {
      _loadingForecast = true;
    });

    try {
      final forecastRepo = context.read<ForecastRepository>();
      final forecast = await forecastRepo.fetchLatestForecast(product.id);
      final actual =
          await forecastRepo.fetchRecentDailySales(product.id, days: 7);

      if (!mounted) return;

      setState(() {
        _currentForecast = forecast;
        _actualSales = actual.isEmpty ? List.filled(7, 0.0) : actual;
        _loadingForecast = false;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _currentForecast = null;
        _actualSales = List.filled(7, 0.0);
        _loadingForecast = false;
        _loading = false;
      });
    }
  }

  Future<void> _pickProduct() async {
    if (_products.isEmpty) return;

    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
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
              const Text('Pilih Produk',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark)),
              const SizedBox(height: 8),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _products.length,
                  itemBuilder: (ctx, i) {
                    final p = _products[i];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(p.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textDark)),
                      subtitle: Text(
                          'SKU: ${p.stockCode} • Stok: ${p.currentStock} ${p.unit}'),
                      trailing: i == _productIdx
                          ? const Icon(Icons.check_circle_rounded,
                              color: AppColors.primary)
                          : null,
                      onTap: () => Navigator.pop(context, i),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (picked != null && picked != _productIdx) {
      setState(() => _productIdx = picked);
      await _loadForecastForProduct(_products[picked]);
    }
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
              child: _buildBody(),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNav(current: 3),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 48, color: _kRedText),
              const SizedBox(height: 12),
              const Text(
                'Terjadi kesalahan saat memuat data',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark),
              ),
              const SizedBox(height: 6),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 13, color: AppColors.textMuted),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Coba Lagi'),
                style:
                    FilledButton.styleFrom(backgroundColor: AppColors.primary),
              ),
            ],
          ),
        ),
      );
    }

    if (_products.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.chip,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.inventory_2_outlined,
                    size: 32, color: AppColors.primary),
              ),
              const SizedBox(height: 16),
              const Text(
                'Belum Ada Produk',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark),
              ),
              const SizedBox(height: 8),
              const Text(
                'Tambahkan produk di menu Produk terlebih dahulu untuk melihat analitik dan prediksi stok.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppColors.textMuted),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _loadData,
                style:
                    FilledButton.styleFrom(backgroundColor: AppColors.primary),
                child: const Text('Segarkan'),
              ),
            ],
          ),
        ),
      );
    }

    final currentProduct = _products[_productIdx];

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          const _PageHeader(),
          const SizedBox(height: 12),
          _ProductSelector(
            product: currentProduct,
            onTap: _pickProduct,
          ),
          const SizedBox(height: 12),
          _StatusCard(
            product: currentProduct,
            forecast: _currentForecast,
          ),
          const SizedBox(height: 16),
          _SectionTitle(
            title: 'Proyeksi Permintaan',
            subtitle: 'Tren aktual & peramalan ARIMA ke depan',
            trailing: _HorizonSwitch(
              value: _horizon,
              onChanged: (h) => setState(() => _horizon = h),
            ),
          ),
          const SizedBox(height: 14),
          _ChartCard(
            product: currentProduct,
            forecast: _currentForecast,
            actual: _actualSales,
            horizon: _horizon,
            isLoading: _loadingForecast,
          ),
          const SizedBox(height: 16),
          const _SectionTitle(title: 'Rekomendasi Aksi'),
          const SizedBox(height: 14),
          _RecommendationCard(
            product: currentProduct,
            forecast: _currentForecast,
          ),
          const SizedBox(height: 16),
          const _SectionTitle(
            title: 'Evaluasi Model ML',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified_outlined,
                    size: 18, color: AppColors.textMuted),
                SizedBox(width: 6),
                Text('Terkalibrasi',
                    style: TextStyle(fontSize: 14, color: AppColors.textMuted)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _ModelCard(
            forecast: _currentForecast,
            unit: currentProduct.unit,
          ),
        ],
      ),
    );
  }
}

// ---------- Header halaman ----------
class _PageHeader extends StatelessWidget {
  const _PageHeader();

  @override
  Widget build(BuildContext context) {
    final primary = AppColors.primaryOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.primaryTintOf(context),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_graph_rounded, size: 14, color: primary),
              const SizedBox(width: 6),
              Text('Kecerdasan Stok UMKM',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.2,
                      color: primary)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text('Analitik & Prediksi',
            style: TextStyle(
                fontSize: 20,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimaryOf(context))),
        const SizedBox(height: 3),
        Text('Proyeksi stok berbasis model ARIMA',
            style: TextStyle(
                fontSize: 14, color: AppColors.textSecondaryOf(context))),
      ],
    );
  }
}

// ---------- Pemilih produk ----------
class _ProductSelector extends StatelessWidget {
  final ProductOverview product;
  final VoidCallback onTap;
  const _ProductSelector({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppColors.textPrimaryOf(context);
    final textMuted = AppColors.textSecondaryOf(context);
    final primary = AppColors.primaryOf(context);

    return SoftCard(
      onTap: onTap,
      radius: 6,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.surfaceSecondaryOf(context),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(Icons.inventory_2_outlined, color: primary, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: textPrimary)),
                const SizedBox(height: 2),
                Text(
                    'SKU: ${product.stockCode}  •  ${product.category ?? "Umum"}',
                    style: TextStyle(fontSize: 12, color: textMuted)),
              ],
            ),
          ),
          Icon(Icons.keyboard_arrow_down_rounded, color: textMuted, size: 18),
        ],
      ),
    );
  }
}

// ---------- Status ketahanan stok ----------
class _StatusCard extends StatelessWidget {
  final ProductOverview product;
  final Forecast? forecast;

  const _StatusCard({required this.product, required this.forecast});

  @override
  Widget build(BuildContext context) {
    final daysLeft = forecast?.daysUntilStockout ?? product.daysUntilStockout;
    final p = _priority(daysLeft);
    final textPrimary = AppColors.textPrimaryOf(context);
    final textMuted = AppColors.textSecondaryOf(context);
    final secondaryBg = AppColors.surfaceSecondaryOf(context);

    final String daysText;
    final String captionText;
    if (daysLeft == null) {
      daysText = 'Stok Aman';
      captionText = 'Cukup selama horizon';
    } else if (daysLeft <= 0) {
      daysText = 'Hari ini';
      captionText = 'Stok habis';
    } else {
      daysText = '$daysLeft hari';
      final out = DateTime.now().add(Duration(days: daysLeft));
      captionText = 'Prediksi: ${_fmt(out, year: true)}';
    }

    return SoftCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Status Ketahanan Stok',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: textPrimary)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: p.bg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(p.label,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.2,
                        color: p.fg)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _InfoBox(
                    color: secondaryBg,
                    caption: 'Stok saat ini',
                    value: '${product.currentStock}',
                    suffix: ' ${product.unit}',
                    valueColor: textPrimary,
                    footer:
                        'Ambang: ${product.reorderThreshold} ${product.unit}',
                    footerColor: textMuted,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _InfoBox(
                    color: secondaryBg,
                    caption: 'Estimasi habis',
                    value: daysText,
                    suffix: '',
                    valueColor: p.fg,
                    footer: captionText,
                    footerColor: textMuted,
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

class _InfoBox extends StatelessWidget {
  final Color color, valueColor, footerColor;
  final String caption, value, suffix, footer;
  final bool footerBold;

  const _InfoBox({
    required this.color,
    required this.caption,
    required this.value,
    required this.suffix,
    required this.valueColor,
    required this.footer,
    required this.footerColor,
  }) : footerBold = false;

  @override
  Widget build(BuildContext context) {
    final textMuted = AppColors.textSecondaryOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(caption, style: TextStyle(fontSize: 12, color: textMuted)),
          const SizedBox(height: 2),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                    text: value,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: valueColor)),
                TextSpan(
                    text: suffix,
                    style: TextStyle(fontSize: 12, color: textMuted)),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Text(footer,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: footerBold ? FontWeight.w600 : FontWeight.w400,
                  color: footerColor)),
        ],
      ),
    );
  }
}

// ---------- Judul seksi ----------
class _SectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  const _SectionTitle({required this.title, this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimaryOf(context))),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle!,
                    style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondaryOf(context))),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
      ],
    );
  }
}

// ---------- Pilihan rentang prediksi ----------
class _HorizonSwitch extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  const _HorizonSwitch({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final secondaryBg = AppColors.surfaceSecondaryOf(context);
    final muted = AppColors.textSecondaryOf(context);

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: secondaryBg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final h in const [7, 14, 30])
            GestureDetector(
              onTap: () => onChanged(h),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: h == value ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('$h hr',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: h == value ? Colors.white : muted)),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------- Kartu grafik ----------
class _ChartCard extends StatelessWidget {
  final ProductOverview product;
  final Forecast? forecast;
  final List<double> actual;
  final int horizon;
  final bool isLoading;

  const _ChartCard({
    required this.product,
    required this.forecast,
    required this.actual,
    required this.horizon,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const SoftCard(
        padding: EdgeInsets.all(32),
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final hasForecast =
        forecast?.details != null && forecast!.details!.isNotEmpty;

    // Ambil prediksi sesuai horizon yang dipilih
    List<double> forecastValues = [];
    if (hasForecast) {
      final details = forecast!.details!;
      if (details.length >= horizon) {
        forecastValues =
            details.take(horizon).map((e) => e.predictedQty).toList();
      } else {
        forecastValues = details.map((e) => e.predictedQty).toList();
        final lastVal = forecastValues.isNotEmpty ? forecastValues.last : 0.0;
        while (forecastValues.length < horizon) {
          forecastValues.add(lastVal);
        }
      }
    } else {
      // Fallback jika belum ada forecast detail
      forecastValues = List.filled(horizon, 0.0);
    }

    final total = forecastValues.fold<double>(0, (a, b) => a + b);
    final avg = total / math.max(1, horizon);

    final now = DateTime.now();
    String d(int off) => _fmt(now.add(Duration(days: off)));
    final mid = (horizon / 2).round();
    final labels = [
      _AxisLabel(
          -6, d(-6), AppColors.textSecondaryOf(context), FontWeight.w400),
      _AxisLabel(
          0, 'Hari ini', AppColors.textPrimaryOf(context), FontWeight.w700),
      _AxisLabel(mid, d(mid), AppColors.primaryOf(context), FontWeight.w600),
      _AxisLabel(
          horizon, d(horizon), AppColors.primaryOf(context), FontWeight.w600),
    ];

    return SoftCard(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _LegendDot(
                  color: AppColors.textSecondaryOf(context),
                  text: 'Aktual (Penjualan)'),
              _LegendDot(
                  color: hasForecast ? AppColors.primary : AppColors.hint,
                  text: hasForecast
                      ? 'Prediksi Permintaan'
                      : 'Prediksi Belum Ada',
                  bold: hasForecast),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 220,
            child: TweenAnimationBuilder<double>(
              key: ValueKey('${product.id}-$horizon-$hasForecast'),
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (_, progress, __) => CustomPaint(
                size: Size.infinite,
                painter: _ChartPainter(
                  actual: actual,
                  forecast: forecastValues,
                  labels: labels,
                  progress: progress,
                  isDashedForecast: !hasForecast,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _kBox,
              borderRadius: BorderRadius.circular(12),
            ),
            child: hasForecast
                ? Text.rich(
                    TextSpan(
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textMuted),
                      children: [
                        const TextSpan(text: 'Rata-rata permintaan '),
                        TextSpan(
                          text:
                              '${avg.toStringAsFixed(1)} ${product.unit}/hari',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark),
                        ),
                        TextSpan(
                            text:
                                ', total perkiraan ${total.round()} ${product.unit} dalam $horizon hari.'),
                      ],
                    ),
                  )
                : const Row(
                    children: [
                      Icon(Icons.info_outline,
                          size: 16, color: AppColors.textMuted),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Prediksi detail belum tersedia di database. Jalankan pipeline ML untuk memperbarui.',
                          style: TextStyle(
                              fontSize: 12.5, color: AppColors.textMuted),
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

class _LegendDot extends StatelessWidget {
  final Color color;
  final String text;
  final bool bold;
  const _LegendDot(
      {required this.color, required this.text, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(text,
            style: TextStyle(
                fontSize: 13,
                fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
                color: bold ? AppColors.textDark : AppColors.textMuted)),
      ],
    );
  }
}

class _AxisLabel {
  final int offset;
  final String text;
  final Color color;
  final FontWeight weight;
  const _AxisLabel(this.offset, this.text, this.color, this.weight);
}

class _ChartPainter extends CustomPainter {
  final List<double> actual;
  final List<double> forecast;
  final List<_AxisLabel> labels;
  final double progress;
  final bool isDashedForecast;

  const _ChartPainter({
    required this.actual,
    required this.forecast,
    required this.labels,
    required this.progress,
    this.isDashedForecast = false,
  });

  static const _grid = Color(0x14000000);
  static const _todayLine = Color(0x80475569);

  void _dashed(Canvas canvas, Path path, Paint paint,
      {double dash = 7, double gap = 5}) {
    for (final m in path.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, math.min(d + dash, m.length)), paint);
        d += dash + gap;
      }
    }
  }

  void _text(Canvas canvas, String t, Offset at, TextStyle style,
      {bool centerX = false, double? maxRight}) {
    final tp = TextPainter(
      text: TextSpan(text: t, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    var x = centerX ? at.dx - tp.width / 2 : at.dx;
    if (maxRight != null) x = x.clamp(0.0, maxRight - tp.width).toDouble();
    tp.paint(canvas, Offset(x, at.dy));
  }

  @override
  void paint(Canvas canvas, Size size) {
    const top = 24.0, bottomPad = 32.0, side = 8.0;
    final chartBottom = size.height - bottomPad;
    final chartH = chartBottom - top;
    final past = actual.length - 1;
    final totalDays = past + forecast.length;

    final all = [...actual, ...forecast];
    var minV = all.isEmpty ? 0.0 : all.reduce(math.min);
    var maxV = all.isEmpty ? 10.0 : all.reduce(math.max);
    var pad = (maxV - minV) * 0.18;
    if (pad == 0) pad = 1;
    minV = math.max(0.0, minV - pad);
    maxV += pad;

    double xOf(int day) =>
        side + (size.width - 2 * side) * (day + past) / totalDays;
    double yOf(double v) => top + chartH * (1 - (v - minV) / (maxV - minV));

    // Garis bantu horizontal
    final gridPaint = Paint()
      ..color = _grid
      ..strokeWidth = 1;
    for (var i = 0; i < 3; i++) {
      final y = top + chartH * i / 2;
      canvas.drawLine(Offset(side, y), Offset(size.width - side, y), gridPaint);
    }

    // Garis aktual
    if (actual.isNotEmpty) {
      final actualPts = [
        for (var i = 0; i < actual.length; i++)
          Offset(xOf(i - past), yOf(actual[i])),
      ];
      final actualPath = Path()..moveTo(actualPts.first.dx, actualPts.first.dy);
      for (final p in actualPts.skip(1)) {
        actualPath.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(
        actualPath,
        Paint()
          ..color = AppColors.textMuted
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      for (final p in actualPts.take(actualPts.length - 1)) {
        canvas.drawCircle(p, 3.5, Paint()..color = AppColors.textMuted);
      }
    }

    // Garis "Hari Ini"
    final tx = xOf(0);
    _dashed(
      canvas,
      Path()
        ..moveTo(tx, top - 4)
        ..lineTo(tx, chartBottom),
      Paint()
        ..color = _todayLine
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
      dash: 4,
      gap: 4,
    );
    _text(
      canvas,
      'HARI INI',
      Offset(tx + 5, 0),
      const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
          color: AppColors.textMuted),
    );

    // Garis & area prediksi
    if (forecast.isNotEmpty) {
      final lastActual = actual.isNotEmpty ? actual.last : 0.0;
      final pts = [
        Offset(tx, yOf(lastActual)),
        for (var i = 0; i < forecast.length; i++)
          Offset(xOf(i + 1), yOf(forecast[i])),
      ];
      final line = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (final p in pts.skip(1)) {
        line.lineTo(p.dx, p.dy);
      }
      final area = Path.from(line)
        ..lineTo(pts.last.dx, chartBottom)
        ..lineTo(pts.first.dx, chartBottom)
        ..close();

      canvas.save();
      canvas.clipRect(Rect.fromLTRB(tx - 1, 0,
          tx + (size.width - side - tx) * progress + 1, size.height));

      final fillColor = isDashedForecast
          ? Colors.grey.withAlpha(20)
          : const Color(0x332563EB);

      canvas.drawPath(
        area,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [fillColor, const Color(0x002563EB)],
          ).createShader(Rect.fromLTRB(tx, top, size.width, chartBottom)),
      );

      final linePaint = Paint()
        ..color = isDashedForecast ? AppColors.hint : AppColors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;

      if (isDashedForecast) {
        _dashed(canvas, line, linePaint, dash: 5, gap: 5);
      } else {
        _dashed(canvas, line, linePaint);
      }

      final step = math.max(1, (forecast.length / 4).round());
      for (var i = step; i < pts.length - 1; i += step) {
        canvas.drawCircle(
            pts[i],
            3.5,
            Paint()
              ..color = isDashedForecast ? AppColors.hint : AppColors.primary);
      }
      canvas.restore();

      if (progress >= 0.999) {
        canvas.drawCircle(pts.last, 6.5, Paint()..color = Colors.white);
        canvas.drawCircle(
            pts.last,
            4.5,
            Paint()
              ..color = isDashedForecast ? AppColors.hint : AppColors.primary);
      }
      canvas.drawCircle(pts.first, 6.5, Paint()..color = Colors.white);
      canvas.drawCircle(pts.first, 4.5, Paint()..color = AppColors.textDark);
    }

    // Label tanggal
    for (final l in labels) {
      _text(
        canvas,
        l.text,
        Offset(xOf(l.offset), chartBottom + 12),
        TextStyle(fontSize: 12, fontWeight: l.weight, color: l.color),
        centerX: true,
        maxRight: size.width,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ChartPainter old) =>
      old.progress != progress ||
      old.actual != actual ||
      old.forecast != forecast ||
      old.isDashedForecast != isDashedForecast;
}

// ---------- Rekomendasi aksi ----------
class _RecommendationCard extends StatelessWidget {
  final ProductOverview product;
  final Forecast? forecast;

  const _RecommendationCard({
    required this.product,
    required this.forecast,
  });

  @override
  Widget build(BuildContext context) {
    final daysLeft = forecast?.daysUntilStockout ?? product.daysUntilStockout;
    const leadDays = 3;

    final bool isUrgent = (daysLeft != null && daysLeft <= leadDays) ||
        product.currentStock <= product.reorderThreshold;

    final daysToDeadline = daysLeft != null ? daysLeft - leadDays : 7;
    final deadline = _fmt(
        DateTime.now().add(Duration(days: math.max(daysToDeadline, 0))),
        year: true);

    final int restockQty = math.max(
      product.reorderThreshold * 2,
      (forecast?.avgDailyDemand != null)
          ? (forecast!.avgDailyDemand! * 7).round()
          : 20,
    );

    return SoftCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: isUrgent ? _kOrangeBg : _kGreenBg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  isUrgent
                      ? Icons.local_shipping_outlined
                      : Icons.check_circle_outline_rounded,
                  color: isUrgent ? _kBrown : _kGreen,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(isUrgent ? 'TINDAKAN DISARANKAN' : 'KONDISI AMAN',
                        style: TextStyle(
                            fontSize: 12,
                            letterSpacing: 1,
                            fontWeight: FontWeight.w700,
                            color: isUrgent ? _kBrown : _kGreen)),
                    const SizedBox(height: 4),
                    if (isUrgent)
                      Text.rich(
                        TextSpan(
                          style: const TextStyle(
                              fontSize: 15,
                              height: 1.35,
                              color: AppColors.textDark),
                          children: [
                            const TextSpan(text: 'Disarankan restock '),
                            TextSpan(
                              text: '$restockQty ${product.unit}',
                              style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700),
                            ),
                            TextSpan(
                                text: daysToDeadline <= 0
                                    ? ' secepatnya (stok menipis).'
                                    : ' sebelum $deadline.'),
                          ],
                        ),
                      )
                    else
                      Text(
                        daysLeft != null
                            ? 'Stok diperkirakan cukup hingga $daysLeft hari ke depan. Belum perlu restock.'
                            : 'Stok saat ini aman dan berada di atas ambang batas reorder.',
                        style: const TextStyle(
                            fontSize: 15,
                            height: 1.35,
                            color: AppColors.textDark),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ProductDetailScreens(sku: product.stockCode),
                ),
              ),
              icon: const Icon(Icons.arrow_forward_rounded, size: 22),
              label: const Text('Lihat Detail Produk'),
              iconAlignment: IconAlignment.end,
              style: FilledButton.styleFrom(
                backgroundColor: isUrgent ? AppColors.primary : AppColors.chip,
                foregroundColor: isUrgent ? Colors.white : AppColors.textDark,
                elevation: 0,
                minimumSize: const Size.fromHeight(50),
                textStyle:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------- Evaluasi model ----------
class _ModelCard extends StatelessWidget {
  final Forecast? forecast;
  final String unit;

  const _ModelCard({
    required this.forecast,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final model = forecast?.mlModel;

    final String maeText =
        model?.mae != null ? model!.mae!.toStringAsFixed(2) : '-';
    final String rmseText =
        model?.rmse != null ? model!.rmse!.toStringAsFixed(2) : '-';
    final String mapeText =
        model?.mape != null ? '${model!.mape!.toStringAsFixed(1)}%' : '-';

    final String quality;
    final Color qualityColor;
    if (model?.mape != null) {
      if (model!.mape! <= 10) {
        quality = 'akurasi tinggi';
        qualityColor = _kGreen;
      } else if (model.mape! <= 20) {
        quality = 'akurasi baik (<20%)';
        qualityColor = AppColors.primary;
      } else {
        quality = 'perlu evaluasi';
        qualityColor = _kRedText;
      }
    } else {
      quality = 'belum diukur';
      qualityColor = AppColors.textMuted;
    }

    final algorithmName = model?.algorithm ?? _kDefaultAlgorithm;

    return SoftCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              _MetricBox(
                label: 'MAE',
                value: maeText,
                unit: unit,
              ),
              const SizedBox(width: 10),
              _MetricBox(
                label: 'RMSE',
                value: rmseText,
                unit: unit,
              ),
              const SizedBox(width: 10),
              _MetricBox(
                label: 'MAPE',
                value: mapeText,
                unit: quality,
                valueColor: qualityColor,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(Icons.info_outline_rounded,
                    size: 20, color: AppColors.textMuted),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    style: const TextStyle(
                        fontSize: 13, height: 1.4, color: AppColors.textMuted),
                    children: [
                      const TextSpan(text: 'Model prediksi deret waktu: '),
                      TextSpan(
                        text: algorithmName,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark),
                      ),
                      TextSpan(
                        text: model != null
                            ? ' (versi ${model.version}, terlatih).'
                            : ' (menunggu sinkronisasi dari pipeline ML).',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricBox extends StatelessWidget {
  final String label, value, unit;
  final Color valueColor;
  const _MetricBox({
    required this.label,
    required this.value,
    required this.unit,
    this.valueColor = AppColors.textDark,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
        decoration: BoxDecoration(
          color: _kBox,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 12,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textMuted)),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value,
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: valueColor)),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(unit,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textMuted)),
            ),
          ],
        ),
      ),
    );
  }
}
