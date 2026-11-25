import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/theme/app_colors.dart';
import '../../features/products/data/models/product_overview.dart';
import '../../features/products/data/models/stock_movement_item.dart';
import '../../features/products/data/repositories/product_repository.dart';
import '../widgets/app_shell.dart';
import '../widgets/sale_entry_sheet.dart';
import '../widgets/stock_in_sheet.dart';

// ---------- Warna tambahan khusus halaman ini ----------
const _kOutFg = Color(0xFFB91C1C);
const _kInFg = Color(0xFF1D4ED8);
const _kBox = Color(0xFFEFF2FB);

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
const _weekdays = [
  'Senin',
  'Selasa',
  'Rabu',
  'Kamis',
  'Jumat',
  'Sabtu',
  'Minggu',
];

String _fmtDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

String _fmtTime(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')} WIB';

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

int _daysAgoFromToday(DateTime d) {
  final today = _dateOnly(DateTime.now());
  return today.difference(_dateOnly(d)).inDays;
}

String _groupLabel(DateTime day) {
  final daysAgo = _daysAgoFromToday(day);
  final name = daysAgo == 0
      ? 'Hari ini'
      : daysAgo == 1
          ? 'Kemarin'
          : _weekdays[day.weekday - 1];
  return '${name.toUpperCase()}  ·  ${_fmtDate(day).toUpperCase()}';
}

enum TxType { keluar, masuk }

class _Tx {
  final String id, product, unit;
  final int qty, stockBefore, stockAfter;
  final DateTime dateTime;
  final TxType type;
  final String? note;

  const _Tx({
    required this.id,
    required this.product,
    required this.unit,
    required this.type,
    required this.qty,
    required this.stockBefore,
    required this.stockAfter,
    required this.dateTime,
    this.note,
  });

  factory _Tx.fromMovement(StockMovementItem item) {
    return _Tx(
      id: item.displayRef,
      product: item.productName,
      unit: item.unit,
      type: item.isOut ? TxType.keluar : TxType.masuk,
      qty: item.quantity,
      stockBefore: item.stockBefore,
      stockAfter: item.stockAfter,
      dateTime: item.createdAt,
      note: item.note,
    );
  }

  bool get isOut => type == TxType.keluar;
  int get daysAgo => _daysAgoFromToday(dateTime);
}

// =====================================================================
class TransactionScreens extends StatefulWidget {
  const TransactionScreens({super.key});

  @override
  State<TransactionScreens> createState() => _TransactionScreensState();
}

class _TransactionScreensState extends State<TransactionScreens> {
  final _searchCtrl = TextEditingController();
  late final ProductRepository _repository;
  late Future<List<_Tx>> _txFuture;
  List<_Tx>? _lastData;

  TxType? _type; // null = semua
  bool _last30 = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _repository = context.read<ProductRepository>();
    _txFuture = _load();
  }

  Future<List<_Tx>> _load() async {
    final items = await _repository.fetchStockMovements();
    final mapped = items.map(_Tx.fromMovement).toList();
    _lastData = mapped;
    return mapped;
  }

  void _reload() {
    setState(() {
      _txFuture = _load();
    });
  }

  Future<void> _refresh() async {
    final future = _load();
    setState(() => _txFuture = future);
    try {
      await future;
    } catch (_) {
      // Galat ditampilkan oleh FutureBuilder.
    }
  }

  void _showMessage(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: isError ? _kOutFg : null,
        ),
      );
  }

  String _errorText(Object error, String fallback) {
    if (error is ProductFailure) return error.message;
    return '$fallback $error';
  }

  Future<List<ProductOverview>> _loadActiveProducts() async {
    final products = await _repository.fetchProducts();
    return products.where((p) => p.isActive).toList();
  }

  Future<void> _openSaleEntry() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final products = (await _loadActiveProducts())
          .where((p) => p.currentStock > 0)
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
          for (final p in products)
            SaleEntryProduct(
              id: p.id,
              name: p.name,
              unit: p.unit,
              availableStock: p.currentStock,
            ),
        ],
      );
      if (result == null || !mounted) return;

      final productId = result.product.id;
      if (productId == null) {
        _showMessage('Produk tidak dikenali. Muat ulang halaman.',
            isError: true);
        return;
      }

      await _repository.recordSale(
        productId: productId,
        quantity: result.quantity,
        transactionDate: result.dateTime,
      );
      if (!mounted) return;

      _showMessage(
        'Penjualan ${result.quantity} ${result.product.unit} '
        '${result.product.name} tersimpan.',
      );
      _reload();
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

  Future<void> _openStockIn() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final products = await _loadActiveProducts();
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
          for (final p in products)
            StockInProduct(
              id: p.id,
              name: p.name,
              unit: p.unit,
            ),
        ],
      );
      if (result == null || !mounted) return;

      final productId = result.product.id;
      if (productId == null) {
        _showMessage('Produk tidak dikenali. Muat ulang halaman.',
            isError: true);
        return;
      }

      await _repository.recordStockIn(
        productId: productId,
        quantity: result.quantity,
      );
      if (!mounted) return;

      _showMessage(
        'Stok masuk ${result.quantity} ${result.product.unit} '
        '${result.product.name} tersimpan.',
      );
      _reload();
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
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
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
              child: FutureBuilder<List<_Tx>>(
                future: _txFuture,
                initialData: _lastData,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError && !snapshot.hasData) {
                    return _LoadError(
                      message: snapshot.error.toString(),
                      onRetry: _reload,
                    );
                  }

                  final allTx = snapshot.data ?? const <_Tx>[];
                  final query = _searchCtrl.text.trim().toLowerCase();

                  final todayOut =
                      allTx.where((t) => t.isOut && t.daysAgo == 0).length;
                  final weekIn = allTx
                      .where((t) => !t.isOut && t.daysAgo >= 0 && t.daysAgo < 7)
                      .length;

                  final list = allTx
                      .where((t) =>
                          (_type == null || t.type == _type) &&
                          (!_last30 || (t.daysAgo >= 0 && t.daysAgo <= 30)) &&
                          t.product.toLowerCase().contains(query))
                      .toList()
                    ..sort((a, b) => b.dateTime.compareTo(a.dateTime));

                  // Kelompokkan per hari kalender (urutan sudah menurun)
                  final groups = <DateTime, List<_Tx>>{};
                  for (final t in list) {
                    final day = _dateOnly(t.dateTime);
                    groups.putIfAbsent(day, () => []).add(t);
                  }

                  final hasFilter =
                      query.isNotEmpty || _type != null || _last30;

                  return RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      children: [
                        _Header(
                          onExport: () =>
                              _showMessage('Ekspor riwayat belum tersedia'),
                        ),
                        const SizedBox(height: 12),
                        _ActionRow(
                          onSale: _openSaleEntry,
                          onStockIn: _openStockIn,
                        ),
                        const SizedBox(height: 12),
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
                                  iconBg: AppColors.dangerBgOf(context),
                                  iconFg: AppColors.dangerOf(context),
                                  valueColor: AppColors.dangerOf(context),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _SummaryCard(
                                  label: 'Barang masuk minggu ini',
                                  value: '$weekIn',
                                  unit: 'pengiriman',
                                  caption: 'Pasokan inventaris',
                                  icon: Icons.south_west_rounded,
                                  iconBg: AppColors.successBgOf(context),
                                  iconFg: AppColors.successOf(context),
                                  valueColor: AppColors.successOf(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _SearchField(
                          controller: _searchCtrl,
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 12),
                        _FilterRow(
                          type: _type,
                          last30: _last30,
                          onType: (t) => setState(() => _type = t),
                          onLast30: () => setState(() => _last30 = !_last30),
                        ),
                        const SizedBox(height: 22),
                        if (list.isEmpty)
                          _EmptyState(
                            message: hasFilter
                                ? 'Belum ada transaksi yang cocok'
                                : 'Belum ada riwayat transaksi',
                          ),
                        for (final entry in groups.entries) ...[
                          _GroupHeader(
                            label: _groupLabel(entry.key),
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
                  );
                },
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
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Transaksi',
                  style: TextStyle(
                      fontSize: 20,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimaryOf(context))),
              const SizedBox(height: 2),
              Text('Riwayat keluar masuk persediaan barang',
                  style: TextStyle(
                      fontSize: 14, color: AppColors.textSecondaryOf(context))),
            ],
          ),
        ),
        const SizedBox(width: 12),
        SoftCard(
          onTap: onExport,
          radius: 6,
          padding: EdgeInsets.zero,
          child: SizedBox(
            width: 36,
            height: 36,
            child: Icon(Icons.file_download_outlined,
                color: AppColors.textPrimaryOf(context), size: 18),
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
    final secondaryBg = AppColors.surfaceSecondaryOf(context);
    final textPrimary = AppColors.textPrimaryOf(context);

    return Row(
      children: [
        Expanded(
          child: Material(
            color: secondaryBg,
            borderRadius: BorderRadius.circular(6),
            child: InkWell(
              onTap: onSale,
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Center(
                  child: Text('Catat Penjualan',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: textPrimary)),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Material(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(6),
            child: InkWell(
              onTap: onStockIn,
              borderRadius: BorderRadius.circular(6),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Center(
                  child: Text('Stok Masuk',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.white)),
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
  final Color iconBg, iconFg, valueColor;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.caption,
    required this.icon,
    required this.iconBg,
    required this.iconFg,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final textMuted = AppColors.textSecondaryOf(context);
    final hint = AppColors.textHintOf(context);

    return SoftCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(label,
                    style:
                        TextStyle(fontSize: 12, height: 1.3, color: textMuted)),
              ),
              const SizedBox(width: 6),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, size: 15, color: iconFg),
              ),
            ],
          ),
          const Spacer(),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  fontSize: 20,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                  color: valueColor)),
          const SizedBox(height: 2),
          Text(caption, style: TextStyle(fontSize: 12, color: hint)),
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
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.borderOf(context), width: 1),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        cursorColor: AppColors.primaryOf(context),
        style: TextStyle(fontSize: 14, color: AppColors.textPrimaryOf(context)),
        decoration: InputDecoration(
          hintText: 'Cari riwayat transaksi...',
          hintStyle:
              TextStyle(fontSize: 14, color: AppColors.textHintOf(context)),
          prefixIcon: Icon(Icons.search_rounded,
              color: AppColors.textSecondaryOf(context), size: 18),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  icon: Icon(Icons.close_rounded,
                      color: AppColors.textSecondaryOf(context), size: 18),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                ),
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 11),
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
          _Chip(
              label: 'Semua', active: type == null, onTap: () => onType(null)),
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
    final bg = active
        ? AppColors.primaryTintOf(context)
        : AppColors.surfaceSecondaryOf(context);
    final fg = active
        ? AppColors.primaryOf(context)
        : AppColors.textSecondaryOf(context);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: fg),
              const SizedBox(width: 5),
            ],
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
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
    final muted = AppColors.textSecondaryOf(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: 12,
                    letterSpacing: 0.6,
                    fontWeight: FontWeight.w600,
                    color: muted)),
          ),
          Text('$count aktivitas',
              style: TextStyle(fontSize: 12, color: muted)),
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
    final fg =
        tx.isOut ? AppColors.dangerOf(context) : AppColors.successOf(context);
    final iconBg = tx.isOut
        ? AppColors.dangerBgOf(context)
        : AppColors.successBgOf(context);
    final textPrimary = AppColors.textPrimaryOf(context);
    final textMuted = AppColors.textSecondaryOf(context);
    final chipBg = AppColors.surfaceSecondaryOf(context);
    final soldOut = tx.stockAfter == 0;

    return SoftCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              tx.isOut ? Icons.north_east_rounded : Icons.south_west_rounded,
              color: fg,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
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
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: textPrimary)),
                    ),
                    const SizedBox(width: 8),
                    Text('${tx.isOut ? '-' : '+'}${tx.qty} ${tx.unit}',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: fg)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: tx.isOut ? chipBg : iconBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(tx.isOut ? 'Barang Keluar' : 'Barang Masuk',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: tx.isOut ? textMuted : fg)),
                    ),
                    const SizedBox(width: 8),
                    Text(_fmtTime(tx.dateTime),
                        style: TextStyle(fontSize: 12, color: textMuted)),
                  ],
                ),
                const SizedBox(height: 4),
                if (soldOut)
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration:
                            BoxDecoration(color: fg, shape: BoxShape.circle),
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

// ---------- Kondisi kosong & galat ----------
class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          const Icon(Icons.receipt_long_outlined,
              size: 44, color: AppColors.hint),
          const SizedBox(height: 10),
          Text(message,
              style: const TextStyle(fontSize: 16, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _LoadError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 44, color: _kOutFg),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
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
  const _DetailRow(
      {required this.label, required this.value, this.last = false});

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
