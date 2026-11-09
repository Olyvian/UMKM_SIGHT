import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../widgets/app_shell.dart';
import '../widgets/stock_in_sheet.dart';
import 'profile_screens.dart';

// ---------- Warna tambahan khusus halaman ini ----------
const _kRedText = Color(0xFFB91C1C);
const _kRedBg = Color(0xFFFEE2E2);
const _kBrown = Color(0xFF9A3412);
const _kOrangeBg = Color(0xFFFFEDE0);
const _kGreen = Color(0xFF15803D);
const _kGreenBg = Color(0xFFDCFCE7);
const _kGrey = Color(0xFF334155);
const _kBox = Color(0xFFEFF2FB);
const _kInBg = Color(0xFFDDE5FF);
const _kInFg = Color(0xFF1D4ED8);
const _kDivider = Color(0x12000000);

// ---------- Helper tanggal ----------
const _monthsShort = [
  'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
  'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
];
const _monthsLong = [
  'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
  'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
];
const _weekdays = [
  'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu',
];

DateTime _dayOffset(int off) {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day + off);
}

String _short(DateTime d) => '${d.day} ${_monthsShort[d.month - 1]}';
String _long(DateTime d) => '${d.day} ${_monthsLong[d.month - 1]} ${d.year}';

// ---------- Model & data contoh (ganti dengan data API nanti) ----------
enum DetailStatus { habis, restock, pantau, aman }

class StockMove {
  final bool isSale;
  final int qty, daysAgo, hour, minute, stockAfter;
  const StockMove(
      this.isSale, this.qty, this.daysAgo, this.hour, this.minute, this.stockAfter);

  DateTime get dateTime {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day - daysAgo, hour, minute);
  }
}

class ProductDetail {
  final String sku, name, category, unit, unitShort, reason;
  final int stock, threshold, restockQty, leadDays;
  final int? daysLeft; // null = prediksi belum tersedia
  final double rate; // rata-rata penjualan per hari
  final List<int> history; // stok 6 hari terakhir, terakhir = hari ini
  final List<StockMove> moves;

  const ProductDetail({
    required this.sku,
    required this.name,
    required this.category,
    required this.unit,
    required this.unitShort,
    required this.stock,
    required this.threshold,
    required this.daysLeft,
    required this.rate,
    required this.history,
    required this.restockQty,
    required this.leadDays,
    required this.reason,
    required this.moves,
  });

  DetailStatus get status {
    if (stock == 0) return DetailStatus.habis;
    final d = daysLeft;
    if (d == null) return DetailStatus.aman;
    if (d <= 3) return DetailStatus.restock;
    if (d <= 7) return DetailStatus.pantau;
    return DetailStatus.aman;
  }

  /// Cari produk berdasarkan SKU (dipakai halaman Produk dan Analitik).
      static final Map<String, ProductDetail> _edited = {};

  static ProductDetail bySku(String sku) =>
      _edited[sku] ??
      _catalog.firstWhere((e) => e.sku == sku, orElse: () => _catalog.first);

  static void save(ProductDetail d) => _edited[d.sku] = d;

  ProductDetail copyWith({
    String? name,
    String? category,
    int? threshold,
    int? restockQty,
    int? leadDays,
  }) =>
      ProductDetail(
        sku: sku,
        name: name ?? this.name,
        category: category ?? this.category,
        unit: unit,
        unitShort: unitShort,
        stock: stock,
        threshold: threshold ?? this.threshold,
        daysLeft: daysLeft,
        rate: rate,
        history: history,
        restockQty: restockQty ?? this.restockQty,
        leadDays: leadDays ?? this.leadDays,
        reason: reason,
        moves: moves,
      );
}

const _catalog = <ProductDetail>[
  ProductDetail(
    sku: 'BRS-5KG-04',
    name: 'Beras Premium 5 kg',
    category: 'Sembako',
    unit: 'karung',
    unitShort: 'krg',
    stock: 4,
    threshold: 6,
    daysLeft: 2,
    rate: 2,
    history: [9, 8, 9, 7, 6, 4],
    restockQty: 15,
    leadDays: 1,
    reason: ' agar stok tetap aman menyambut lonjakan akhir pekan',
    moves: [
      StockMove(true, 2, 0, 16, 20, 4),
      StockMove(true, 3, 1, 11, 10, 6),
      StockMove(false, 10, 3, 9, 0, 9),
    ],
  ),
  ProductDetail(
    sku: 'MKS-2L-01',
    name: 'Minyak Goreng Sania 2L',
    category: 'Sembako',
    unit: 'botol',
    unitShort: 'btl',
    stock: 0,
    threshold: 12,
    daysLeft: 0,
    rate: 3,
    history: [14, 11, 8, 6, 3, 0],
    restockQty: 24,
    leadDays: 2,
    reason: ' agar rak tidak kosong di hari ramai',
    moves: [
      StockMove(true, 3, 0, 9, 30, 0),
      StockMove(true, 3, 1, 16, 5, 3),
      StockMove(false, 10, 3, 10, 0, 6),
    ],
  ),
  ProductDetail(
    sku: 'GLP-1KG-02',
    name: 'Gula Pasir 1 kg',
    category: 'Sembako',
    unit: 'kg',
    unitShort: 'kg',
    stock: 9,
    threshold: 10,
    daysLeft: 5,
    rate: 1.8,
    history: [16, 14, 13, 12, 10, 9],
    restockQty: 25,
    leadDays: 2,
    reason: ' agar stok aman sebelum akhir pekan',
    moves: [
      StockMove(true, 2, 0, 13, 40, 9),
      StockMove(true, 3, 1, 10, 15, 11),
      StockMove(true, 2, 3, 17, 5, 14),
    ],
  ),
  ProductDetail(
    sku: 'KCP-600-08',
    name: 'Kecap Manis Botol 600 ml',
    category: 'Bumbu Dapur',
    unit: 'botol',
    unitShort: 'btl',
    stock: 24,
    threshold: 8,
    daysLeft: 18,
    rate: 1.3,
    history: [30, 29, 27, 26, 25, 24],
    restockQty: 12,
    leadDays: 3,
    reason: '',
    moves: [
      StockMove(true, 1, 0, 11, 0, 24),
      StockMove(true, 2, 1, 14, 30, 25),
      StockMove(true, 1, 2, 9, 45, 27),
    ],
  ),
  ProductDetail(
    sku: 'MIG-DUS-03',
    name: 'Mi Instan Goreng',
    category: 'Makanan Instan',
    unit: 'bungkus',
    unitShort: 'bks',
    stock: 38,
    threshold: 20,
    daysLeft: null,
    rate: 0,
    history: [42, 41, 40, 40, 39, 38],
    restockQty: 40,
    leadDays: 2,
    reason: '',
    moves: [
      StockMove(true, 4, 1, 15, 10, 38),
      StockMove(false, 40, 2, 9, 0, 42),
      StockMove(true, 5, 4, 12, 20, 2),
    ],
  ),
];

({String label, Color fg, Color bg}) _statusStyle(DetailStatus s) {
  switch (s) {
    case DetailStatus.habis:
      return (label: 'Stok habis', fg: _kRedText, bg: _kRedBg);
    case DetailStatus.restock:
      return (label: 'Segera restock', fg: _kBrown, bg: _kOrangeBg);
    case DetailStatus.pantau:
      return (label: 'Perlu dipantau', fg: _kGrey, bg: AppColors.chip);
    case DetailStatus.aman:
      return (label: 'Stok aman', fg: _kGreen, bg: _kGreenBg);
  }
}

class ProductDetailScreens extends StatefulWidget {
  final String sku;
  const ProductDetailScreens({super.key, required this.sku});

  @override
  State<ProductDetailScreens> createState() => _ProductDetailScreensState();
}

class _ProductDetailScreensState extends State<ProductDetailScreens> {
  late String _sku = widget.sku;

  Future<void> _pickProduct() async {
    final picked = await showModalBottomSheet<String>(
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
              for (final p in _catalog)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(ProductDetail.bySku(p.sku).name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark)),
                  subtitle: Text('SKU: ${p.sku}'),
                  trailing: p.sku == _sku
                      ? const Icon(Icons.check_circle_rounded,
                          color: AppColors.primary)
                      : null,
                  onTap: () => Navigator.pop(context, p.sku),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked != null) setState(() => _sku = picked);
  }

  Future<void> _edit(ProductDetail d) async {
    final updated = await showModalBottomSheet<ProductDetail>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _EditSheet(d: d),
    );
    if (updated == null || !mounted) return;
    ProductDetail.save(updated);
    setState(() {});
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Data produk diperbarui')));
  }

  @override
  Widget build(BuildContext context) {
    final d = ProductDetail.bySku(_sku);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const _DetailBar(),
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                children: [
                  _MonitorRow(onEdit: () => _edit(d)),
                  const SizedBox(height: 16),
                  _ProductPicker(onTap: _pickProduct),
                  const SizedBox(height: 16),
                  _SummaryCard(d: d),
                  const SizedBox(height: 28),
                  const _SectionTitle('Prediksi Stok Habis'),
                  const SizedBox(height: 12),
                  if (d.daysLeft == null)
                    const _NoForecast()
                  else ...[
                    _ForecastInfo(d: d),
                    const SizedBox(height: 14),
                    _ChartCard(d: d),
                  ],
                  const SizedBox(height: 28),
                  const _SectionTitle('Rekomendasi Restock'),
                  const SizedBox(height: 12),
                  _RecommendationCard(d: d),
                  const SizedBox(height: 28),
                  _SectionTitle(
                    'Pergerakan Stok Terakhir',
                    trailing: '${d.moves.length} Transaksi Terakhir',
                  ),
                  const SizedBox(height: 12),
                  _MovesCard(d: d),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------- Tombol ganti produk ----------
class _ProductPicker extends StatelessWidget {
  final VoidCallback onTap;
  const _ProductPicker({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      onTap: onTap,
      radius: 20,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: const Row(
        children: [
          Icon(Icons.swap_horiz_rounded, color: AppColors.primary),
          SizedBox(width: 12),
          Expanded(
            child: Text('Lihat produk lain',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark)),
          ),
          Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textMuted),
        ],
      ),
    );
  }
}

// ---------- Form ubah data produk ----------
class _EditSheet extends StatefulWidget {
  final ProductDetail d;
  const _EditSheet({required this.d});

  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  late final _name = TextEditingController(text: widget.d.name);
  late final _category = TextEditingController(text: widget.d.category);
  late final _threshold = TextEditingController(text: '${widget.d.threshold}');
  late final _restockQty = TextEditingController(text: '${widget.d.restockQty}');
  late final _leadDays = TextEditingController(text: '${widget.d.leadDays}');
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _category, _threshold, _restockQty, _leadDays]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    final category = _category.text.trim();
    final threshold = int.tryParse(_threshold.text.trim());
    final qty = int.tryParse(_restockQty.text.trim());
    final lead = int.tryParse(_leadDays.text.trim());

    if (name.isEmpty || category.isEmpty) {
      setState(() => _error = 'Nama dan kategori wajib diisi');
      return;
    }
    if (threshold == null ||
        threshold < 0 ||
        qty == null ||
        qty <= 0 ||
        lead == null ||
        lead < 0) {
      setState(() => _error =
          'Ambang batas, jumlah restock, dan lead time harus angka yang valid');
      return;
    }
    Navigator.pop(
      context,
      widget.d.copyWith(
        name: name,
        category: category,
        threshold: threshold,
        restockQty: qty,
        leadDays: lead,
      ),
    );
  }

  Widget _field(String label, TextEditingController c, {bool number = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted)),
          const SizedBox(height: 6),
          TextField(
            controller: c,
            keyboardType: number ? TextInputType.number : TextInputType.text,
            cursorColor: AppColors.primary,
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            style: const TextStyle(fontSize: 16, color: AppColors.textDark),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.chip,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide:
                    const BorderSide(color: AppColors.primary, width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.d;
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
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
              const Text('Ubah Data Produk',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark)),
              const SizedBox(height: 4),
              Text(
                  'SKU ${d.sku}. Sisa stok diubah lewat Stok Masuk atau Penjualan.',
                  style: const TextStyle(
                      fontSize: 14, color: AppColors.textMuted)),
              const SizedBox(height: 18),
              _field('Nama produk', _name),
              _field('Kategori', _category),
              _field('Ambang batas restock (${d.unit})', _threshold,
                  number: true),
              _field('Jumlah restock disarankan (${d.unit})', _restockQty,
                  number: true),
              _field('Lead time pemasok (hari)', _leadDays, number: true),
              if (_error != null)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: _kRedBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(_error!,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: _kRedText)),
                ),
              FilledButton(
                onPressed: _save,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  minimumSize: const Size.fromHeight(54),
                  textStyle: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18)),
                ),
                child: const Text('Simpan'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------- Bar atas ----------
class _DetailBar extends StatelessWidget {
  const _DetailBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 10, 20, 10),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
              color: AppColors.shadow, blurRadius: 10, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(Icons.arrow_back_rounded,
                color: AppColors.textDark, size: 26),
          ),
          const SizedBox(width: 4),
          const Expanded(
            child: Text('Detail Produk',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark)),
          ),
                    GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreens()),
            ),
            child: const CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.primary,
              child: Icon(Icons.person_outline_rounded, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------- Baris status pemantauan ----------
class _MonitorRow extends StatelessWidget {
  final VoidCallback onEdit;
  const _MonitorRow({required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: 4),
        Container(
          width: 10,
          height: 10,
          decoration: const BoxDecoration(
              color: AppColors.primary, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Text('STATUS PEMANTAUAN AKTIF',
              style: TextStyle(
                  fontSize: 13,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textMuted)),
        ),
        Material(
          color: AppColors.chip,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: onEdit,
            borderRadius: BorderRadius.circular(14),
            child: const SizedBox(
              width: 46,
              height: 46,
              child: Icon(Icons.edit_outlined,
                  size: 22, color: AppColors.textDark),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------- Judul seksi ----------
class _SectionTitle extends StatelessWidget {
  final String title;
  final String? trailing;
  const _SectionTitle(this.title, {this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Text(title,
                style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark)),
          ),
          if (trailing != null)
            Text(trailing!,
                style:
                    const TextStyle(fontSize: 13, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

// ---------- Kartu ringkasan produk ----------
class _SummaryCard extends StatelessWidget {
  final ProductDetail d;
  const _SummaryCard({required this.d});

  @override
  Widget build(BuildContext context) {
    final s = _statusStyle(d.status);
    final ratio = (d.stock / (d.threshold * 2)).clamp(0.0, 1.0);
    final barColor = d.status == DetailStatus.aman ? _kGreen : s.fg;

    return SoftCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(d.name,
                    style: const TextStyle(
                        fontSize: 22,
                        height: 1.2,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark)),
              ),
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: s.bg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(s.label,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: s.fg)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('SKU: ${d.sku}  •  Kategori: ${d.category}',
              style: const TextStyle(
                  fontSize: 14, height: 1.3, color: AppColors.textMuted)),
          const SizedBox(height: 20),
          const Text('Sisa Stok Saat Ini',
              style: TextStyle(fontSize: 14, color: AppColors.textMuted)),
          const SizedBox(height: 2),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                    text: '${d.stock}',
                    style: TextStyle(
                        fontSize: 44,
                        height: 1.15,
                        fontWeight: FontWeight.w700,
                        color: d.stock == 0 ? _kRedText : AppColors.textDark)),
                TextSpan(
                    text: ' ${d.unit}',
                    style: const TextStyle(
                        fontSize: 20, color: AppColors.textMuted)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: ratio.toDouble(),
              minHeight: 8,
              backgroundColor: AppColors.chip,
              valueColor: AlwaysStoppedAnimation(barColor),
            ),
          ),
          const SizedBox(height: 8),
          Text('Ambang batas restock: ${d.threshold} ${d.unit}',
              style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

// ---------- Informasi perkiraan habis ----------
class _ForecastInfo extends StatelessWidget {
  final ProductDetail d;
  const _ForecastInfo({required this.d});

  @override
  Widget build(BuildContext context) {
    final days = d.daysLeft!;
    final title = days == 0
        ? 'Stok sudah habis hari ini'
        : 'Perkiraan habis dalam $days hari (${_long(_dayOffset(days))})';
    final rate = d.rate == d.rate.roundToDouble()
        ? d.rate.toInt().toString()
        : d.rate.toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kBox,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.hourglass_bottom_rounded,
                color: _kBrown, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 17,
                        height: 1.25,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark)),
                const SizedBox(height: 4),
                Text(
                    'Berdasarkan rata-rata laju penjualan $rate ${d.unit}/hari tanpa pasokan baru.',
                    style: const TextStyle(
                        fontSize: 14,
                        height: 1.35,
                        color: AppColors.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NoForecast extends StatelessWidget {
  const _NoForecast();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _kBox,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: AppColors.textMuted),
          SizedBox(width: 12),
          Expanded(
            child: Text(
                'Prediksi belum tersedia. Data penjualan produk ini belum cukup untuk membuat perkiraan stok habis.',
                style: TextStyle(
                    fontSize: 14, height: 1.4, color: AppColors.textMuted)),
          ),
        ],
      ),
    );
  }
}

// ---------- Kartu grafik ----------
class _ChartCard extends StatelessWidget {
  final ProductDetail d;
  const _ChartCard({required this.d});

  @override
  Widget build(BuildContext context) {
    final days = d.daysLeft!;
    final horizon = math.max(4, math.min(14, days + 2));
    final pastDays = d.history.length - 1;

    final actualRange =
        '${_short(_dayOffset(-pastDays))} - ${_short(_dayOffset(0))}';
    final forecastRange =
        '${_short(_dayOffset(1))} - ${_short(_dayOffset(horizon))}';

    return SoftCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 18,
            runSpacing: 6,
            children: [
              _Legend(color: AppColors.textMuted, text: 'Aktual ($actualRange)'),
              _Legend(
                  color: AppColors.primary,
                  text: 'Prediksi ($forecastRange)',
                  bold: true),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 230,
            child: TweenAnimationBuilder<double>(
              key: ValueKey(d.sku),
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              builder: (_, progress, __) => CustomPaint(
                size: Size.infinite,
                painter: _StockChartPainter(
                  history: d.history,
                  stock: d.stock,
                  rate: d.rate,
                  daysLeft: days,
                  horizon: horizon,
                  depletionLabel: days == 0 ? 'Hari ini' : _short(_dayOffset(days)),
                  progress: progress,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
              'Prediksi dihasilkan dari riwayat penjualan 30 hari terakhir. Bukan jaminan pasti.',
              style: TextStyle(
                  fontSize: 13, height: 1.4, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String text;
  final bool bold;
  const _Legend({required this.color, required this.text, this.bold = false});

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

class _StockChartPainter extends CustomPainter {
  final List<int> history; // stok harian: hari -5 sampai hari ini
  final int stock, daysLeft, horizon;
  final double rate, progress;
  final String depletionLabel;

  const _StockChartPainter({
    required this.history,
    required this.stock,
    required this.rate,
    required this.daysLeft,
    required this.horizon,
    required this.depletionLabel,
    required this.progress,
  });

  static const _grid = Color(0x14000000);
  static const _line = Color(0xFF475569);

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

  TextPainter _tp(String t, TextStyle style) => TextPainter(
        text: TextSpan(text: t, style: style),
        textDirection: TextDirection.ltr,
      )..layout();

  @override
  void paint(Canvas canvas, Size size) {
    const top = 26.0, bottomPad = 36.0, sideL = 8.0, sideR = 12.0;
    final chartBottom = size.height - bottomPad;
    final chartH = chartBottom - top;
    final past = history.length - 1;
    final totalDays = past + horizon;
    final maxV = math.max(math.max(history.reduce(math.max), stock), 1) * 1.15;

    double xOf(num day) =>
        sideL + (size.width - sideL - sideR) * (day + past) / totalDays;
    double yOf(double v) => top + chartH * (1 - v / maxV);

    // Garis bantu
    final grid = Paint()
      ..color = _grid
      ..strokeWidth = 1;
    for (var i = 0; i < 2; i++) {
      final y = top + chartH * i / 2;
      canvas.drawLine(Offset(sideL, y), Offset(size.width - sideR, y), grid);
    }
    _dashed(
      canvas,
      Path()
        ..moveTo(sideL, chartBottom)
        ..lineTo(size.width - sideR, chartBottom),
      Paint()
        ..color = _grid
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
      dash: 3,
      gap: 4,
    );
    final habis = _tp('Habis (0)',
        const TextStyle(fontSize: 12, color: AppColors.textMuted));
    habis.paint(canvas,
        Offset(size.width - sideR - habis.width, chartBottom - habis.height - 5));

    // Data aktual
    final actualPts = [
      for (var i = 0; i <= past; i++)
        Offset(xOf(i - past), yOf(history[i].toDouble())),
    ];
    final actualLine = Path()..moveTo(actualPts.first.dx, actualPts.first.dy);
    for (final p in actualPts.skip(1)) {
      actualLine.lineTo(p.dx, p.dy);
    }
    final actualArea = Path.from(actualLine)
      ..lineTo(actualPts.last.dx, chartBottom)
      ..lineTo(actualPts.first.dx, chartBottom)
      ..close();
    canvas.drawPath(
      actualArea,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x26475569), Color(0x00475569)],
        ).createShader(Rect.fromLTRB(sideL, top, size.width, chartBottom)),
    );
    canvas.drawPath(
      actualLine,
      Paint()
        ..color = _line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    for (final p in actualPts.take(actualPts.length - 1)) {
      canvas.drawCircle(p, 3.5, Paint()..color = _line);
    }

    // Garis "hari ini"
    final tx = xOf(0);
    _dashed(
      canvas,
      Path()
        ..moveTo(tx, top - 4)
        ..lineTo(tx, chartBottom + 6),
      Paint()
        ..color = const Color(0x80475569)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
      dash: 4,
      gap: 4,
    );
    final hariIni = _tp('Hari Ini',
        const TextStyle(fontSize: 12, color: AppColors.textMuted));
    hariIni.paint(canvas, Offset(tx + 6, 0));

    // Prediksi (dianimasikan dari kiri ke kanan)
    final pts = [
      Offset(tx, yOf(stock.toDouble())),
      for (var d = 1; d <= horizon; d++)
        Offset(xOf(d), yOf(math.max(0.0, stock - rate * d))),
    ];
    final forecastLine = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      forecastLine.lineTo(p.dx, p.dy);
    }
    final forecastArea = Path.from(forecastLine)
      ..lineTo(pts.last.dx, chartBottom)
      ..lineTo(pts.first.dx, chartBottom)
      ..close();

    canvas.save();
    canvas.clipRect(Rect.fromLTRB(
        tx - 1, 0, tx + (size.width - sideR - tx) * progress + 6, size.height));
    canvas.drawPath(
      forecastArea,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x332563EB), Color(0x002563EB)],
        ).createShader(Rect.fromLTRB(tx, top, size.width, chartBottom)),
    );
    _dashed(
      canvas,
      forecastLine,
      Paint()
        ..color = AppColors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();

    // Titik hari ini
    canvas.drawCircle(pts.first, 6.5, Paint()..color = Colors.white);
    canvas.drawCircle(pts.first, 4.5, Paint()..color = AppColors.primary);

    // Titik stok habis
    if (daysLeft <= horizon && progress >= 0.999) {
      final p = Offset(xOf(daysLeft), chartBottom);
      canvas.drawCircle(p, 7, Paint()..color = Colors.white);
      canvas.drawCircle(p, 5, Paint()..color = _kBrown);
      final label = _tp(
          depletionLabel,
          const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700, color: _kBrown));
      final x = (p.dx - label.width / 2)
          .clamp(0.0, size.width - label.width)
          .toDouble();
      label.paint(canvas, Offset(x, chartBottom + 12));
    }
  }

  @override
  bool shouldRepaint(covariant _StockChartPainter old) =>
      old.progress != progress ||
      old.stock != stock ||
      old.rate != rate ||
      old.horizon != horizon;
}

// ---------- Rekomendasi restock ----------
class _RecommendationCard extends StatelessWidget {
  final ProductDetail d;
  const _RecommendationCard({required this.d});

  InlineSpan _message() {
    const base = TextStyle(fontSize: 17, height: 1.4, color: AppColors.textDark);
    final days = d.daysLeft;

    if (days == null) {
      return const TextSpan(
        style: base,
        text:
            'Belum ada rekomendasi karena data penjualan belum cukup. Catat stok masuk saat barang tiba.',
      );
    }
    if (d.status == DetailStatus.aman) {
      return TextSpan(
        style: base,
        text:
            'Belum perlu restock. Stok diperkirakan cukup sampai ${_long(_dayOffset(days))}.',
      );
    }

    final untilDeadline = days - d.leadDays;
    final when = untilDeadline <= 0
        ? ' secepatnya'
        : ' sebelum ${_weekdays[_dayOffset(untilDeadline).weekday - 1]}, ${_short(_dayOffset(untilDeadline))}';

    return TextSpan(
      style: base,
      children: [
        const TextSpan(text: 'Pesan minimum '),
        TextSpan(
            text: '${d.restockQty} ${d.unit}',
            style: const TextStyle(fontWeight: FontWeight.w700)),
        TextSpan(text: '$when${d.reason}.'),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(Icons.verified_outlined,
                    color: AppColors.primary, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(child: Text.rich(_message())),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => showStockInSheet(
                context,
                products: [
                  StockInProduct(
                    name: d.name,
                    unit: d.unit,
                    suggested: d.restockQty,
                  ),
                ],
              ),
              icon: const Icon(Icons.add_circle_outline_rounded, size: 22),
              label: const Text('Tambah Stok Masuk'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                minimumSize: const Size.fromHeight(56),
                textStyle:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
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

// ---------- Pergerakan stok terakhir ----------
class _MovesCard extends StatelessWidget {
  final ProductDetail d;
  const _MovesCard({required this.d});

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      child: Column(
        children: [
          for (var i = 0; i < d.moves.length; i++) ...[
            _MoveRow(move: d.moves[i], unit: d.unit, unitShort: d.unitShort),
            if (i != d.moves.length - 1)
              const Divider(height: 1, thickness: 1, color: _kDivider),
          ],
        ],
      ),
    );
  }
}

class _MoveRow extends StatelessWidget {
  final StockMove move;
  final String unit, unitShort;
  const _MoveRow(
      {required this.move, required this.unit, required this.unitShort});

  @override
  Widget build(BuildContext context) {
    final t = move.dateTime;
    final time =
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    final isSale = move.isSale;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: isSale ? AppColors.chip : _kInBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isSale ? Icons.shopping_bag_outlined : Icons.move_to_inbox_outlined,
              color: isSale ? AppColors.textDark : _kInFg,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  children: [
                    Text(isSale ? 'Penjualan' : 'Stok Masuk',
                        style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark)),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isSale ? _kRedBg : _kInBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                          '${isSale ? '-' : '+'}${move.qty} $unitShort',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isSale ? _kRedText : _kInFg)),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text('${_short(t)}, $time',
                    style: const TextStyle(
                        fontSize: 14, color: AppColors.textMuted)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('Sisa',
                  style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
              Text('${move.stockAfter} $unit',
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark)),
            ],
          ),
        ],
      ),
    );
  }
}