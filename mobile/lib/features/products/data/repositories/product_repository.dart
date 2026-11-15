import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/product_overview.dart';

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
        'Skema inventaris belum tersedia. Jalankan schema.sql lalu '
        'schema_Inventoris.sql di Supabase SQL Editor.',
      );
    }
    return ProductFailure('$fallback ${error.message}');
  }
}
