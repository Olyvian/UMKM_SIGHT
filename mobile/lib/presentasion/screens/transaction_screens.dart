import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../widgets/app_shell.dart';
import '../widgets/sale_entry_sheet.dart';
import '../widgets/stock_in_sheet.dart';

// ---------- Warna tambahan khusus halaman ini ----------
const _kOutFg = Color(0xFFB91C1C);
const _kOutBg = Color(0xFFFEE2E2);
const _kInFg = Color(0xFF1D4ED8);
const _kInBg = Color(0xFFDDE5FF);
const _kChipActiveBg = Color(0xFFE0E7FF);
const _kBox = Color(0xFFEFF2FB);

// ---------- Helper tanggal ----------
const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
  'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
];
const _weekdays = [
  'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu',
];

String _fmtDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

String _fmtTime(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')} WIB';

String _groupLabel(int daysAgo, DateTime d) {
  final name = daysAgo == 0
      ? 'Hari ini'
      : daysAgo == 1
          ? 'Kemarin'
          : _weekdays[d.weekday - 1];
  return '${name.toUpperCase()}  ·  ${_fmtDate(d).toUpperCase()}';
}

// ---------- Model & data contoh (ganti dengan data API nanti) ----------
enum TxType { keluar, masuk }

class _Tx {
  final String id, product, unit;
  final int qty, stockAfter, daysAgo, hour, minute;
  final TxType type;

  const _Tx({
    required this.id,
    required this.product,
    required this.unit,
    required this.type,
    required this.qty,
    required this.stockAfter,
    required this.daysAgo,
    required this.hour,
    required this.minute,
  });

  bool get isOut => type == TxType.keluar;
  int get stockBefore => isOut ? stockAfter + qty : stockAfter - qty;

  DateTime get dateTime {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day - daysAgo, hour, minute);
  }
}

const _transactions = <_Tx>[
  _Tx(id: 'TRX-0012', product: 'Minyak Goreng Sania 2L', unit: 'botol', type: TxType.keluar, qty: 3, stockAfter: 0, daysAgo: 0, hour: 9, minute: 30),
  _Tx(id: 'TRX-0011', product: 'Beras Premium 5 kg', unit: 'karung', type: TxType.keluar, qty: 2, stockAfter: 4, daysAgo: 0, hour: 8, minute: 15),
  _Tx(id: 'TRX-0010', product: 'Gula Pasir 1 kg', unit: 'kg', type: TxType.masuk, qty: 20, stockAfter: 29, daysAgo: 1, hour: 14, minute: 15),
  _Tx(id: 'TRX-0009', product: 'Kecap Manis Botol 600 ml', unit: 'botol', type: TxType.keluar, qty: 6, stockAfter: 24, daysAgo: 1, hour: 11, minute: 0),
  _Tx(id: 'TRX-0008', product: 'Mi Instan Goreng', unit: 'bungkus', type: TxType.masuk, qty: 40, stockAfter: 38, daysAgo: 3, hour: 10, minute: 20),
  _Tx(id: 'TRX-0007', product: 'Beras Premium 5 kg', unit: 'karung', type: TxType.masuk, qty: 10, stockAfter: 8, daysAgo: 5, hour: 13, minute: 5),
  _Tx(id: 'TRX-0006', product: 'Minyak Goreng Sania 2L', unit: 'botol', type: TxType.keluar, qty: 4, stockAfter: 3, daysAgo: 45, hour: 16, minute: 40),
];

const _stockInProducts = <StockInProduct>[
  StockInProduct(name: 'Minyak Goreng Sania 2L', unit: 'botol'),
  StockInProduct(name: 'Beras Premium 5 kg', unit: 'karung'),
  StockInProduct(name: 'Gula Pasir 1 kg', unit: 'kg'),
  StockInProduct(name: 'Kecap Manis Botol 600 ml', unit: 'botol'),
  StockInProduct(name: 'Mi Instan Goreng', unit: 'bungkus'),
];

const _saleProducts = <SaleEntryProduct>[
  SaleEntryProduct(
      name: 'Minyak Goreng Sania 2L', unit: 'botol', availableStock: 0),
  SaleEntryProduct(
      name: 'Beras Premium 5 kg', unit: 'karung', availableStock: 4),
  SaleEntryProduct(name: 'Gula Pasir 1 kg', unit: 'kg', availableStock: 9),
  SaleEntryProduct(
      name: 'Kecap Manis Botol 600 ml', unit: 'botol', availableStock: 24),
  SaleEntryProduct(
      name: 'Mi Instan Goreng', unit: 'bungkus', availableStock: 38),
];

// =====================================================================
class TransactionScreens extends StatefulWidget {
  const TransactionScreens({super.key});

  @override
  State<TransactionScreens> createState() => _TransactionScreensState();
}

class _TransactionScreensState extends State<TransactionScreens> {
  final _searchCtrl = TextEditingController();
  TxType? _type; // null = semua
  bool _last30 = false;

  void _soon(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _openSaleEntry() async {
    final result = await showSaleEntrySheet(context, products: _saleProducts);
    if (result == null || !mounted) return;
    _soon(
      '${result.quantity} ${result.product.unit} ${result.product.name} '
      'valid, tetapi belum disimpan ke riwayat.',
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchCtrl.text.trim().toLowerCase();

    final todayOut = _transactions.where((t) => t.isOut && t.daysAgo == 0).length;
    final weekIn = _transactions.where((t) => !t.isOut && t.daysAgo < 7).length;

    final list = _transactions
        .where((t) =>
            (_type == null || t.type == _type) &&
            (!_last30 || t.daysAgo <= 30) &&
            t.product.toLowerCase().contains(query))
        .toList()
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime));

    // Kelompokkan per hari (urutan sudah menurun)
    final groups = <int, List<_Tx>>{};
    for (final t in list) {
      groups.putIfAbsent(t.daysAgo, () => []).add(t);
    }

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
                  _Header(
                    onExport: () => _soon('Ekspor riwayat belum tersedia'),
                  ),
                  const SizedBox(height: 18),
                  _ActionRow(
                    onSale: _openSaleEntry,
                    onStockIn: () => showStockInSheet(
                      context,
                      products: _stockInProducts,
                    ),
                  ),
                  const SizedBox(height: 16),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _SummaryCard(
                            label: 'Barang keluar hari ini',
                            value: '$todayOut',
                            unit: 'transaksi',
                            caption: 'Total barang terjual',
                            icon: Icons.north_east_rounded,
                            iconBg: _kOutBg,
                            iconFg: _kOutFg,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _SummaryCard(
                            label: 'Barang masuk minggu ini',
                            value: '$weekIn',
                            unit: 'pengiriman',
                            caption: 'Pasokan inventaris',
                            icon: Icons.south_west_rounded,
                            iconBg: _kInBg,
                            iconFg: _kInFg,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SearchField(
                    controller: _searchCtrl,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 14),
                  _FilterRow(
                    type: _type,
                    last30: _last30,
                    onType: (t) => setState(() => _type = t),
                    onLast30: () => setState(() => _last30 = !_last30),
                  ),
                  const SizedBox(height: 22),
                  if (list.isEmpty) const _EmptyState(),
                  for (final entry in groups.entries) ...[
                    _GroupHeader(
                      label: _groupLabel(
                          entry.key, entry.value.first.dateTime),
                      count: entry.value.length,
                    ),
                    const SizedBox(height: 10),
                    for (final tx in entry.value)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _TxCard(
                          tx: tx,
                          onTap: () => _showDetail(context, tx),
                        ),
                      ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNav(current: 2),
    );
  }
}

// ---------- Header ----------
class _Header extends StatelessWidget {
  final VoidCallback onExport;
  const _Header({required this.onExport});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Transaksi',
                  style: TextStyle(
                      fontSize: 32,
                      height: 1.15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark)),
              SizedBox(height: 2),
              Text('Riwayat keluar masuk persediaan barang',
                  style: TextStyle(fontSize: 14, color: AppColors.textMuted)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        SoftCard(
          onTap: onExport,
          radius: 16,
          padding: EdgeInsets.zero,
          child: const SizedBox(
            width: 50,
            height: 50,
            child: Icon(Icons.file_download_outlined,
                color: AppColors.textDark, size: 24),
          ),
        ),
      ],
    );
  }
}

// ---------- Tombol aksi ----------
class _ActionRow extends StatelessWidget {
  final VoidCallback onSale, onStockIn;
  const _ActionRow({required this.onSale, required this.onStockIn});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SoftCard(
            onTap: onSale,
            radius: 20,
            padding: const EdgeInsets.symmetric(vertical: 17),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long_outlined,
                    size: 22, color: AppColors.textDark),
                SizedBox(width: 8),
                Flexible(
                  child: FittedBox(
                    child: Text('Catat Penjualan',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark)),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Material(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              onTap: onStockIn,
              borderRadius: BorderRadius.circular(20),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 17),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_circle_outline_rounded,
                        size: 22, color: Colors.white),
                    SizedBox(width: 8),
                    Flexible(
                      child: FittedBox(
                        child: Text('Stok Masuk',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------- Kartu ringkasan ----------
class _SummaryCard extends StatelessWidget {
  final String label, value, unit, caption;
  final IconData icon;
  final Color iconBg, iconFg;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.caption,
    required this.icon,
    required this.iconBg,
    required this.iconFg,
  });

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 14, height: 1.3, color: AppColors.textMuted)),
              ),
              const SizedBox(width: 8),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: iconFg),
              ),
            ],
          ),
          const Spacer(),
          const SizedBox(height: 12),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                    text: value,
                    style: const TextStyle(
                        fontSize: 36,
                        height: 1.1,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark)),
                TextSpan(
                    text: ' $unit',
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textMuted)),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(caption,
              style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

// ---------- Pencarian ----------
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
              color: AppColors.shadow, blurRadius: 14, offset: Offset(0, 4)),
        ],
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        cursorColor: AppColors.primary,
        style: const TextStyle(fontSize: 17, color: AppColors.textDark),
        decoration: InputDecoration(
          hintText: 'Cari riwayat transaksi...',
          hintStyle: const TextStyle(fontSize: 17, color: AppColors.hint),
          prefixIcon: const Icon(Icons.search_rounded,
              color: AppColors.textMuted, size: 26),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: AppColors.textMuted, size: 22),
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

// ---------- Filter ----------
class _FilterRow extends StatelessWidget {
  final TxType? type;
  final bool last30;
  final ValueChanged<TxType?> onType;
  final VoidCallback onLast30;

  const _FilterRow({
    required this.type,
    required this.last30,
    required this.onType,
    required this.onLast30,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      clipBehavior: Clip.none,
      child: Row(
        children: [
          _Chip(label: 'Semua', active: type == null, onTap: () => onType(null)),
          const SizedBox(width: 10),
          _Chip(
              label: 'Barang keluar',
              active: type == TxType.keluar,
              onTap: () => onType(TxType.keluar)),
          const SizedBox(width: 10),
          _Chip(
              label: 'Barang masuk',
              active: type == TxType.masuk,
              onTap: () => onType(TxType.masuk)),
          const SizedBox(width: 10),
          _Chip(
              label: '30 hari terakhir',
              icon: Icons.calendar_today_outlined,
              active: last30,
              onTap: onLast30),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool active;
  final VoidCallback onTap;
  const _Chip({
    required this.label,
    required this.active,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final fg = active ? AppColors.primary : AppColors.textMuted;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: active ? _kChipActiveBg : AppColors.surface,
          borderRadius: BorderRadius.circular(30),
          boxShadow: active
              ? null
              : const [
                  BoxShadow(
                      color: AppColors.shadow,
                      blurRadius: 8,
                      offset: Offset(0, 2)),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: 6),
            ],
            Text(label,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                    color: fg)),
          ],
        ),
      ),
    );
  }
}

// ---------- Judul grup per hari ----------
class _GroupHeader extends StatelessWidget {
  final String label;
  final int count;
  const _GroupHeader({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontSize: 13,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted)),
          ),
          Text('$count aktivitas',
              style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

// ---------- Kartu transaksi ----------
class _TxCard extends StatelessWidget {
  final _Tx tx;
  final VoidCallback onTap;
  const _TxCard({required this.tx, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fg = tx.isOut ? _kOutFg : _kInFg;
    final soldOut = tx.stockAfter == 0;

    return SoftCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: tx.isOut ? AppColors.chip : _kInBg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              tx.isOut ? Icons.north_east_rounded : Icons.south_west_rounded,
              color: fg,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(tx.product,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textDark)),
                    ),
                    const SizedBox(width: 8),
                    Text('${tx.isOut ? '-' : '+'}${tx.qty} ${tx.unit}',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: fg)),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(
                        color: tx.isOut ? AppColors.chip : _kInBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                          tx.isOut ? 'Barang Keluar' : 'Barang Masuk',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: tx.isOut
                                  ? const Color(0xFF334155)
                                  : _kInFg)),
                    ),
                    const SizedBox(width: 10),
                    Text(_fmtTime(tx.dateTime),
                        style: const TextStyle(
                            fontSize: 14, color: AppColors.textMuted)),
                  ],
                ),
                const SizedBox(height: 8),
                if (soldOut)
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                            color: _kOutFg, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      Text('Sisa stok: 0 ${tx.unit} (Habis)',
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: _kOutFg)),
                    ],
                  )
                else
                  Text('Sisa stok: ${tx.stockAfter} ${tx.unit}',
                      style: const TextStyle(
                          fontSize: 14, color: AppColors.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------- Kondisi kosong ----------
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(Icons.receipt_long_outlined, size: 44, color: AppColors.hint),
          SizedBox(height: 10),
          Text('Belum ada transaksi yang cocok',
              style: TextStyle(fontSize: 16, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

// ---------- Detail transaksi (bottom sheet) ----------
void _showDetail(BuildContext context, _Tx tx) {
  final fg = tx.isOut ? _kOutFg : _kInFg;

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => SafeArea(
      child: Padding(
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
            Text(tx.product,
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark)),
            const SizedBox(height: 4),
            Text('${tx.isOut ? '-' : '+'}${tx.qty} ${tx.unit}',
                style: TextStyle(
                    fontSize: 30, fontWeight: FontWeight.w700, color: fg)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _kBox,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _DetailRow(
                      label: 'Jenis',
                      value: tx.isOut ? 'Barang keluar' : 'Barang masuk'),
                  _DetailRow(
                      label: 'Waktu',
                      value:
                          '${_fmtDate(tx.dateTime)}, ${_fmtTime(tx.dateTime)}'),
                  _DetailRow(
                      label: 'Stok sebelum',
                      value: '${tx.stockBefore} ${tx.unit}'),
                  _DetailRow(
                      label: 'Stok sesudah',
                      value: '${tx.stockAfter} ${tx.unit}'),
                  _DetailRow(label: 'No. transaksi', value: tx.id, last: true),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _DetailRow extends StatelessWidget {
  final String label, value;
  final bool last;
  const _DetailRow({required this.label, required this.value, this.last = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 14, color: AppColors.textMuted)),
          const SizedBox(width: 12),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.right,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark)),
          ),
        ],
      ),
    );
  }
}
