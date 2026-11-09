import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../widgets/app_shell.dart';

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

const _kAlgorithm = 'Linear Time-Series Regression';

// ---------- Helper tanggal ----------
const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
  'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
];

String _fmt(DateTime d, {bool year = false}) =>
    '${d.day} ${_months[d.month - 1]}${year ? ' ${d.year}' : ''}';

// ---------- Data contoh (ganti dengan data API / hasil layanan ML nanti) ----------
class _Insight {
  final String name, sku, unit, supplier;
  final int stock, threshold, daysLeft, restockQty, leadDays;
  final double mae, rmse, mape;
  final double trend, wave; // pembangkit data prediksi contoh
  final List<double> actual; // 7 titik: H-6 sampai hari ini

  const _Insight({
    required this.name,
    required this.sku,
    required this.unit,
    required this.supplier,
    required this.stock,
    required this.threshold,
    required this.daysLeft,
    required this.restockQty,
    required this.leadDays,
    required this.mae,
    required this.rmse,
    required this.mape,
    required this.trend,
    required this.wave,
    required this.actual,
  });

  /// Prediksi permintaan harian untuk [h] hari ke depan.
  List<double> forecast(int h) => List.generate(h, (i) {
        final d = i + 1;
        return math.max(0.0, actual.last + trend * d + wave * math.sin(d * 0.9));
      });
}

const _insights = <_Insight>[
  _Insight(
    name: 'Beras Premium 5 kg',
    sku: 'BRS-5KG-04',
    unit: 'karung',
    supplier: 'CV Sumber Tani',
    stock: 4,
    threshold: 6,
    daysLeft: 2,
    restockQty: 15,
    leadDays: 1,
    mae: 0.42,
    rmse: 0.58,
    mape: 6.4,
    trend: 0.10,
    wave: 0.25,
    actual: [1.4, 1.8, 1.6, 2.1, 2.0, 2.2, 2.1],
  ),
  _Insight(
    name: 'Minyak Goreng Sania 2L',
    sku: 'MKS-2L-01',
    unit: 'botol',
    supplier: 'PT Mitra Pangan',
    stock: 0,
    threshold: 12,
    daysLeft: 0,
    restockQty: 24,
    leadDays: 2,
    mae: 0.90,
    rmse: 1.30,
    mape: 8.2,
    trend: 0.08,
    wave: 0.40,
    actual: [2, 3, 2, 3, 2, 3, 3],
  ),
  _Insight(
    name: 'Gula Pasir 1 kg',
    sku: 'GLP-1KG-02',
    unit: 'kg',
    supplier: 'UD Manis Jaya',
    stock: 9,
    threshold: 10,
    daysLeft: 5,
    restockQty: 25,
    leadDays: 2,
    mae: 0.80,
    rmse: 1.10,
    mape: 9.7,
    trend: 0.05,
    wave: 0.20,
    actual: [1.2, 1.6, 1.4, 1.9, 1.7, 1.8, 1.8],
  ),
  _Insight(
    name: 'Kecap Manis Botol 600 ml',
    sku: 'KCP-600-08',
    unit: 'botol',
    supplier: 'PT Sari Rasa',
    stock: 24,
    threshold: 8,
    daysLeft: 18,
    restockQty: 12,
    leadDays: 3,
    mae: 0.21,
    rmse: 0.30,
    mape: 12.5,
    trend: 0.02,
    wave: 0.10,
    actual: [1.0, 1.4, 1.2, 1.5, 1.3, 1.4, 1.3],
  ),
];

({String label, Color fg, Color bg}) _priority(int daysLeft) {
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
  int _productIdx = 0;
  int _horizon = 7;

  Future<void> _pickProduct() async {
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
              const Text('Pilih produk',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark)),
              const SizedBox(height: 8),
              for (var i = 0; i < _insights.length; i++)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(_insights[i].name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark)),
                  subtitle: Text('SKU: ${_insights[i].sku}'),
                  trailing: i == _productIdx
                      ? const Icon(Icons.check_circle_rounded,
                          color: AppColors.primary)
                      : null,
                  onTap: () => Navigator.pop(context, i),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked != null) setState(() => _productIdx = picked);
  }

  @override
  Widget build(BuildContext context) {
    final item = _insights[_productIdx];

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
                  const _PageHeader(),
                  const SizedBox(height: 18),
                  _ProductSelector(item: item, onTap: _pickProduct),
                  const SizedBox(height: 16),
                  _StatusCard(item: item),
                  const SizedBox(height: 30),
                  _SectionTitle(
                    title: 'Proyeksi Permintaan',
                    subtitle: 'Tren aktual & kalkulasi ke depan',
                    trailing: _HorizonSwitch(
                      value: _horizon,
                      onChanged: (h) => setState(() => _horizon = h),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _ChartCard(item: item, horizon: _horizon),
                  const SizedBox(height: 30),
                  const _SectionTitle(title: 'Rekomendasi Aksi'),
                  const SizedBox(height: 14),
                  _RecommendationCard(item: item),
                  const SizedBox(height: 30),
                  const _SectionTitle(
                    title: 'Evaluasi Model',
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified_outlined,
                            size: 18, color: AppColors.textMuted),
                        SizedBox(width: 6),
                        Text('Terkalibrasi',
                            style: TextStyle(
                                fontSize: 14, color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _ModelCard(item: item),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNav(current: 3),
    );
  }
}

// ---------- Header halaman ----------
class _PageHeader extends StatelessWidget {
  const _PageHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _kBadgeBlue,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_graph_rounded,
                  size: 16, color: AppColors.primary),
              SizedBox(width: 6),
              Text('Kecerdasan Stok',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary)),
            ],
          ),
        ),
        const SizedBox(height: 10),
        const Text('Analitik & Prediksi',
            style: TextStyle(
                fontSize: 30,
                height: 1.15,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark)),
        const SizedBox(height: 4),
        const Text('Proyeksi kebutuhan stok berbasis model time-series',
            style: TextStyle(fontSize: 14, color: AppColors.textMuted)),
      ],
    );
  }
}

// ---------- Pemilih produk ----------
class _ProductSelector extends StatelessWidget {
  final _Insight item;
  final VoidCallback onTap;
  const _ProductSelector({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      onTap: onTap,
      radius: 20,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.chip,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.inventory_2_outlined,
                color: AppColors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark)),
                const SizedBox(height: 2),
                Text('SKU: ${item.sku}',
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textMuted)),
              ],
            ),
          ),
          const Icon(Icons.keyboard_arrow_down_rounded,
              color: AppColors.textMuted),
        ],
      ),
    );
  }
}

// ---------- Status ketahanan stok ----------
class _StatusCard extends StatelessWidget {
  final _Insight item;
  const _StatusCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final p = _priority(item.daysLeft);
    final out = DateTime.now().add(Duration(days: item.daysLeft));
    final daysText = item.daysLeft == 0 ? 'Hari ini' : '${item.daysLeft} Hari';

    return SoftCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: p.fg, size: 26),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Status Ketahanan Stok',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: p.bg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(p.label,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: p.fg)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _InfoBox(
                    color: _kBox,
                    caption: 'Stok saat ini',
                    value: '${item.stock}',
                    suffix: ' ${item.unit}',
                    valueColor: AppColors.textDark,
                    footer: 'Ambang batas: ${item.threshold} ${item.unit}',
                    footerColor: AppColors.textMuted,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _InfoBox(
                    color: p.bg.withAlpha(110),
                    caption: 'Prediksi: ${_fmt(out, year: true)}',
                    value: daysText,
                    suffix: item.daysLeft == 0 ? '' : ' lagi',
                    valueColor: p.fg,
                    footer: 'Estimasi habis total',
                    footerColor: p.fg,
                    footerBold: true,
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
    this.footerBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(caption,
              style:
                  const TextStyle(fontSize: 13, color: AppColors.textMuted)),
          const SizedBox(height: 6),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                    text: value,
                    style: TextStyle(
                        fontSize: 30,
                        height: 1.1,
                        fontWeight: FontWeight.w700,
                        color: valueColor)),
                TextSpan(
                    text: suffix,
                    style: const TextStyle(
                        fontSize: 14, color: AppColors.textMuted)),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(footer,
              style: TextStyle(
                  fontSize: 13,
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
                  style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark)),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle!,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textMuted)),
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
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.chip,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final h in const [7, 14, 30])
            GestureDetector(
              onTap: () => onChanged(h),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding:
                    const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                decoration: BoxDecoration(
                  color: h == value ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('$h hr',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight:
                            h == value ? FontWeight.w600 : FontWeight.w400,
                        color:
                            h == value ? Colors.white : AppColors.textMuted)),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------- Kartu grafik ----------
class _ChartCard extends StatelessWidget {
  final _Insight item;
  final int horizon;
  const _ChartCard({required this.item, required this.horizon});

  @override
  Widget build(BuildContext context) {
    final forecast = item.forecast(horizon);
    final total = forecast.fold<double>(0, (a, b) => a + b);
    final avg = total / horizon;

    final now = DateTime.now();
    String d(int off) => _fmt(now.add(Duration(days: off)));
    final mid = (horizon / 2).round();
    final labels = [
      _AxisLabel(-6, d(-6), AppColors.textMuted, FontWeight.w400),
      const _AxisLabel(0, 'Hari ini', AppColors.textDark, FontWeight.w700),
      _AxisLabel(mid, d(mid), AppColors.primary, FontWeight.w600),
      _AxisLabel(horizon, d(horizon), AppColors.primary, FontWeight.w600),
    ];

    return SoftCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _LegendDot(color: AppColors.textMuted, text: 'Aktual (Penjualan)'),
              _LegendDot(
                  color: AppColors.primary,
                  text: 'Prediksi Kebutuhan',
                  bold: true),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 220,
            child: TweenAnimationBuilder<double>(
              key: ValueKey('${item.sku}-$horizon'),
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (_, progress, __) => CustomPaint(
                size: Size.infinite,
                painter: _ChartPainter(
                  actual: item.actual,
                  forecast: forecast,
                  labels: labels,
                  progress: progress,
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
            child: Text.rich(
              TextSpan(
                style:
                    const TextStyle(fontSize: 13, color: AppColors.textMuted),
                children: [
                  const TextSpan(text: 'Rata-rata permintaan '),
                  TextSpan(
                    text: '${avg.toStringAsFixed(1)} ${item.unit}/hari',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark),
                  ),
                  TextSpan(
                      text:
                          ', total ${total.round()} ${item.unit} dalam $horizon hari.'),
                ],
              ),
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
  const _LegendDot({required this.color, required this.text, this.bold = false});

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
  final int offset; // selisih hari dari hari ini
  final String text;
  final Color color;
  final FontWeight weight;
  const _AxisLabel(this.offset, this.text, this.color, this.weight);
}

class _ChartPainter extends CustomPainter {
  final List<double> actual; // hari -6 sampai 0
  final List<double> forecast; // hari 1 sampai horizon
  final List<_AxisLabel> labels;
  final double progress; // 0..1 untuk animasi garis prediksi

  const _ChartPainter({
    required this.actual,
    required this.forecast,
    required this.labels,
    required this.progress,
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
    var minV = all.reduce(math.min);
    var maxV = all.reduce(math.max);
    var pad = (maxV - minV) * 0.18;
    if (pad == 0) pad = 1;
    minV -= pad;
    maxV += pad;

    double xOf(int day) =>
        side + (size.width - 2 * side) * (day + past) / totalDays;
    double yOf(double v) => top + chartH * (1 - (v - minV) / (maxV - minV));

    // Garis bantu
    final gridPaint = Paint()
      ..color = _grid
      ..strokeWidth = 1;
    for (var i = 0; i < 3; i++) {
      final y = top + chartH * i / 2;
      canvas.drawLine(Offset(side, y), Offset(size.width - side, y), gridPaint);
    }

    // Garis aktual
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

    // Garis "hari ini"
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

    // Garis & area prediksi (dianimasikan dari kiri ke kanan)
    final pts = [
      Offset(tx, yOf(actual.last)),
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
    canvas.clipRect(Rect.fromLTRB(
        tx - 1, 0, tx + (size.width - side - tx) * progress + 1, size.height));

    canvas.drawPath(
      area,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x332563EB), Color(0x002563EB)],
        ).createShader(Rect.fromLTRB(tx, top, size.width, chartBottom)),
    );
    _dashed(
      canvas,
      line,
      Paint()
        ..color = AppColors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );

    final step = math.max(1, (forecast.length / 4).round());
    for (var i = step; i < pts.length - 1; i += step) {
      canvas.drawCircle(pts[i], 3.5, Paint()..color = AppColors.primary);
    }
    canvas.restore();

    // Titik akhir prediksi & titik hari ini
    if (progress >= 0.999) {
      canvas.drawCircle(pts.last, 6.5, Paint()..color = Colors.white);
      canvas.drawCircle(pts.last, 4.5, Paint()..color = AppColors.primary);
    }
    canvas.drawCircle(pts.first, 6.5, Paint()..color = Colors.white);
    canvas.drawCircle(pts.first, 4.5, Paint()..color = AppColors.textDark);

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
      old.forecast.length != forecast.length;
}

// ---------- Rekomendasi aksi ----------
class _RecommendationCard extends StatelessWidget {
  final _Insight item;
  const _RecommendationCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final safe = item.daysLeft > 7;
    final daysToDeadline = item.daysLeft - item.leadDays;
    final deadline =
        _fmt(DateTime.now().add(Duration(days: math.max(daysToDeadline, 0))),
            year: true);

    final qty = TextSpan(
      text: '${item.restockQty} ${item.unit}',
      style: const TextStyle(
          color: AppColors.primary, fontWeight: FontWeight.w600),
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
                  color: safe ? _kGreenBg : _kBadgeBlue,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  safe
                      ? Icons.check_circle_outline_rounded
                      : Icons.local_shipping_outlined,
                  color: safe ? _kGreen : AppColors.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(safe ? 'KONDISI AMAN' : 'TINDAKAN DISARANKAN',
                        style: TextStyle(
                            fontSize: 12,
                            letterSpacing: 1,
                            fontWeight: FontWeight.w700,
                            color: safe ? _kGreen : AppColors.primary)),
                    const SizedBox(height: 4),
                    if (safe)
                      Text(
                          'Belum perlu restock. Stok diperkirakan cukup ${item.daysLeft} hari ke depan.',
                          style: const TextStyle(
                              fontSize: 16,
                              height: 1.35,
                              color: AppColors.textDark))
                    else
                      Text.rich(
                        TextSpan(
                          style: const TextStyle(
                              fontSize: 16,
                              height: 1.35,
                              color: AppColors.textDark),
                          children: [
                            const TextSpan(text: 'Disarankan restock '),
                            qty,
                            TextSpan(
                                text: daysToDeadline <= 0
                                    ? ' secepatnya.'
                                    : ' sebelum $deadline.'),
                          ],
                        ),
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
              onPressed: () {
                // TODO: buka halaman detail produk (kirim item.sku / id produk)
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Halaman detail produk belum tersedia'),
                  ),
                );
              },
              icon: const Icon(Icons.arrow_forward_rounded, size: 22),
              label: const Text('Lihat Detail Produk'),
              iconAlignment: IconAlignment.end,
              style: FilledButton.styleFrom(
                backgroundColor: safe ? AppColors.chip : AppColors.primary,
                foregroundColor: safe ? AppColors.textDark : Colors.white,
                elevation: 0,
                minimumSize: const Size.fromHeight(54),
                textStyle:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18)),
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
  final _Insight item;
  const _ModelCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final String quality;
    final Color qualityColor;
    if (item.mape < 10) {
      quality = 'akurasi tinggi';
      qualityColor = AppColors.primary;
    } else if (item.mape <= 20) {
      quality = 'akurasi baik';
      qualityColor = AppColors.primary;
    } else {
      quality = 'perlu latih ulang';
      qualityColor = _kRedText;
    }

    return SoftCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              _MetricBox(
                label: 'MAE',
                value: item.mae.toStringAsFixed(2),
                unit: item.unit,
              ),
              const SizedBox(width: 10),
              _MetricBox(
                label: 'RMSE',
                value: item.rmse.toStringAsFixed(2),
                unit: item.unit,
              ),
              const SizedBox(width: 10),
              _MetricBox(
                label: 'MAPE',
                value: '${item.mape.toStringAsFixed(1)}%',
                unit: quality,
                valueColor: qualityColor,
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(Icons.info_outline_rounded,
                    size: 20, color: AppColors.textMuted),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    style: TextStyle(
                        fontSize: 13.5,
                        height: 1.4,
                        color: AppColors.textMuted),
                    children: [
                      TextSpan(
                          text: 'Dievaluasi dari riwayat 60 hari toko. Algoritma: '),
                      TextSpan(
                        text: _kAlgorithm,
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark),
                      ),
                      TextSpan(
                          text:
                              ' dengan pembobotan tren hari kerja vs akhir pekan.'),
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
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: valueColor)),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(unit,
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textMuted)),
            ),
          ],
        ),
      ),
    );
  }
}