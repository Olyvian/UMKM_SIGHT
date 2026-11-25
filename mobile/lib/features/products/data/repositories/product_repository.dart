import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/product_overview.dart';
import '../models/stock_movement_item.dart';

class ProductFailure implements Exception {
  const ProductFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

class ProductRepository {
  ProductRepository({required SupabaseClient client}) : _client = client;

  final SupabaseClient _client;
  static const _imageBucket = 'product-images';
  static const _maxImageBytes = 5 * 1024 * 1024;

  Future<List<ProductOverview>> fetchProducts() async {
    try {
      final rows =
          await _client.from('product_overview').select().order('name');
      final products = rows.map(ProductOverview.fromJson).toList();
      return await Future.wait(products.map(_attachSignedImage));
    } on PostgrestException catch (error) {
      throw _failure(error, 'Gagal memuat produk.');
    }
  }

  Future<String> createProduct({
    required String stockCode,
    required String name,
    required String unit,
    required double unitPrice,
    required int reorderThreshold,
    required bool isMonitored,
  }) async {
    try {
      final row = await _client
          .from('products')
          .insert({
            'stock_code': stockCode,
            'name': name,
            'unit': unit,
            'unit_price': unitPrice,
            'reorder_threshold': reorderThreshold,
            'is_monitored': isMonitored,
          })
          .select('id')
          .single();
      return row['id'] as String;
    } on PostgrestException catch (error) {
      throw _failure(error, 'Gagal menambahkan produk.');
    }
  }

  Future<void> updateProduct({
    required String id,
    required String stockCode,
    required String name,
    required String unit,
    required double unitPrice,
    required int reorderThreshold,
    required bool isMonitored,
  }) async {
    try {
      final row = await _client
          .from('products')
          .update({
            'stock_code': stockCode,
            'name': name,
            'unit': unit,
            'unit_price': unitPrice,
            'reorder_threshold': reorderThreshold,
            'is_monitored': isMonitored,
          })
          .eq('id', id)
          .select('id')
          .maybeSingle();
      if (row == null) {
        throw const ProductFailure(
          'Produk tidak ditemukan atau tidak dapat diakses.',
        );
      }
    } on PostgrestException catch (error) {
      throw _failure(error, 'Gagal memperbarui produk.');
    }
  }

  Future<void> archiveProduct(String id) async {
    try {
      final row = await _client
          .from('products')
          .update({'is_active': false})
          .eq('id', id)
          .select('id')
          .maybeSingle();
      if (row == null) {
        throw const ProductFailure(
          'Produk tidak ditemukan atau tidak dapat diakses.',
        );
      }
    } on PostgrestException catch (error) {
      throw _failure(error, 'Gagal mengarsipkan produk.');
    }
  }

  Future<void> restoreProduct(String id) async {
    try {
      final row = await _client
          .from('products')
          .update({'is_active': true})
          .eq('id', id)
          .select('id')
          .maybeSingle();
      if (row == null) {
        throw const ProductFailure(
          'Produk tidak ditemukan atau tidak dapat diakses.',
        );
      }
    } on PostgrestException catch (error) {
      throw _failure(error, 'Gagal memulihkan produk.');
    }
  }

  Future<void> uploadProductImage({
    required String productId,
    required XFile image,
    String? previousPath,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const ProductFailure('Sesi login berakhir. Silakan masuk kembali.');
    }

    final extension = image.name.split('.').last.toLowerCase();
    final contentType = switch (extension) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => throw const ProductFailure(
          'Format gambar harus JPG, PNG, atau WEBP.',
        ),
    };
    final size = await image.length();
    if (size == 0) {
      throw const ProductFailure('File gambar kosong.');
    }
    if (size > _maxImageBytes) {
      throw const ProductFailure('Ukuran gambar maksimal 5 MB.');
    }
    final bytes = await image.readAsBytes();

    final path = '$userId/$productId/image';
    try {
      await _client.storage.from(_imageBucket).uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              contentType: contentType,
              upsert: true,
            ),
          );
    } on StorageException catch (error) {
      throw ProductFailure('Gagal mengunggah gambar: ${error.message}');
    }

    try {
      final row = await _client
          .from('products')
          .update({'image_path': path})
          .eq('id', productId)
          .select('id')
          .maybeSingle();
      if (row == null) {
        if (previousPath != path) await _removeUnreferencedImage(path);
        throw const ProductFailure(
          'Produk tidak ditemukan atau tidak dapat diakses.',
        );
      }
    } on PostgrestException catch (error) {
      if (previousPath != path) {
        await _removeUnreferencedImage(path);
      }
      throw _failure(error, 'Gagal menyimpan path gambar.');
    }

    if (previousPath != null && previousPath != path) {
      try {
        await _client.storage.from(_imageBucket).remove([previousPath]);
      } on StorageException catch (error) {
        throw ProductFailure(
          'Gambar baru tersimpan, tetapi gambar lama gagal dihapus: '
          '${error.message}',
        );
      }
    }
  }

  Future<void> _removeUnreferencedImage(String path) async {
    try {
      await _client.storage.from(_imageBucket).remove([path]);
    } on StorageException catch (error) {
      throw ProductFailure(
        'Path gambar gagal disimpan dan file sementara tidak dapat '
        'dibersihkan: ${error.message}',
      );
    }
  }

  Future<ProductOverview> _attachSignedImage(ProductOverview product) async {
    final path = product.imagePath;
    if (path == null || path.isEmpty) return product;

    try {
      final url =
          await _client.storage.from(_imageBucket).createSignedUrl(path, 3600);
      return product.copyWith(imageUrl: url);
    } on StorageException catch (error) {
      return product.copyWith(
        imageError: 'Gambar gagal dimuat: ${error.message}',
      );
    }
  }

  /// Mencatat satu penjualan lewat RPC `record_sale` (atomik: stok
  /// dikurangi, transaksi, item, dan mutasi stok dibuat dalam satu
  /// transaksi database).
  ///
  /// [transactionDate] opsional; bila diisi, transaksi dicatat pada waktu
  /// tersebut (bukan `now()`). Fitur ini memerlukan
  /// `supabase/migration_record_sale_date.sql` sudah dijalankan.
  Future<void> recordSale({
    required String productId,
    required int quantity,
    String? note,
    DateTime? transactionDate,
  }) async {
    try {
      await _client.rpc(
        'record_sale',
        params: {
          'p_items': [
            {'product_id': productId, 'quantity': quantity},
          ],
          'p_note': note,
          if (transactionDate != null)
            'p_transaction_date': transactionDate.toUtc().toIso8601String(),
        },
      );
    } on PostgrestException catch (error) {
      throw _saleFailure(error);
    }
  }

  Future<void> recordStockIn({
    required String productId,
    required int quantity,
    String? note,
  }) async {
    try {
      await _client.rpc(
        'record_stock_in',
        params: {
          'p_product_id': productId,
          'p_quantity': quantity,
          'p_note': note,
        },
      );
    } on PostgrestException catch (error) {
      throw _failure(error, 'Gagal mencatat stok masuk.');
    }
  }

  Future<void> adjustStock({
    required String productId,
    required int newStock,
    String? note,
  }) async {
    try {
      await _client.rpc(
        'adjust_stock',
        params: {
          'p_product_id': productId,
          'p_new_stock': newStock,
          'p_note': note,
        },
      );
    } on PostgrestException catch (error) {
      throw _failure(error, 'Gagal mengoreksi stok.');
    }
  }

  /// Mengambil riwayat mutasi stok (keluar/masuk) milik toko yang sedang login.
  /// Data otomatis tersaring oleh Row Level Security (RLS) di Supabase.
  Future<List<StockMovementItem>> fetchStockMovements({int limit = 200}) async {
    try {
      final rows = await _client
          .from('stock_movements')
          .select(
            'id, movement_type, quantity, stock_before, stock_after, note, '
            'created_at, products(name, unit), transactions(invoice_no)',
          )
          .inFilter('movement_type', const ['IN', 'OUT'])
          .order('created_at', ascending: false)
          .limit(limit);

      return rows.map(StockMovementItem.fromJson).toList();
    } on PostgrestException catch (error) {
      throw _failure(error, 'Gagal memuat riwayat transaksi.');
    } on FormatException catch (error) {
      throw ProductFailure('Data riwayat transaksi tidak sesuai: ${error.message}');
    }
  }

  ProductFailure _saleFailure(PostgrestException error) {
    final message = error.message;

    if (message.contains('INSUFFICIENT_STOCK')) {
      return ProductFailure(
        error.details == null
            ? 'Stok tidak mencukupi untuk penjualan ini.'
            : 'Stok tidak mencukupi (${error.details}).',
      );
    }
    if (message.contains('PRODUCT_NOT_FOUND')) {
      return const ProductFailure(
        'Produk tidak ditemukan atau sudah diarsipkan.',
      );
    }
    if (message.contains('INVALID_QUANTITY')) {
      return const ProductFailure('Jumlah penjualan harus lebih dari 0.');
    }
    if (message.contains('EMPTY_ITEMS')) {
      return const ProductFailure('Tidak ada produk yang dipilih.');
    }
    if (message.contains('INVALID_DATE')) {
      return const ProductFailure(
        'Tanggal transaksi tidak boleh melewati waktu sekarang.',
      );
    }
    if (message.contains('NO_STORE')) {
      return const ProductFailure(
        'Akun ini belum memiliki toko. Hubungi admin atau daftar ulang.',
      );
    }
    // RPC versi lama belum menerima p_transaction_date.
    if (error.code == 'PGRST202') {
      return const ProductFailure(
        'Fungsi record_sale belum diperbarui. Jalankan '
        'supabase/migration_record_sale_date.sql di Supabase SQL Editor.',
      );
    }
    return _failure(error, 'Gagal mencatat penjualan.');
  }

  ProductFailure _failure(PostgrestException error, String fallback) {
    if (error.code == '23505') {
      return const ProductFailure(
        'Kode SKU sudah digunakan. Gunakan SKU yang berbeda.',
      );
    }
    if (error.code == '42501') {
      return const ProductFailure(
        'Akses ditolak. Pastikan akun memiliki toko dan policy RLS sudah aktif.',
      );
    }
    if (const {'42P01', '42883', 'PGRST202', 'PGRST205'}.contains(error.code)) {
      return const ProductFailure(
        'Skema inventaris belum tersedia. Jalankan schema.sql di Supabase '
        'SQL Editor.',
      );
    }
    return ProductFailure('$fallback ${error.message}');
  }
}
