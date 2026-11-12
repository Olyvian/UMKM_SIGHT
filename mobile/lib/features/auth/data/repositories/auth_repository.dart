import 'dart:io' show SocketException;

import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../../core/storage/session_storage.dart';
import '../models/user_model.dart';

/// Error yang pesannya aman ditampilkan langsung ke pengguna.
class AuthFailure implements Exception {
  const AuthFailure(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Pendaftaran berhasil, tetapi Supabase mewajibkan verifikasi email dulu
/// sehingga belum ada sesi aktif.
class AuthEmailVerificationRequired extends AuthFailure {
  const AuthEmailVerificationRequired()
      : super(
          'Pendaftaran berhasil. Kami mengirim tautan verifikasi ke email '
          'Anda. Verifikasi dulu, lalu masuk.',
        );
}

/// Autentikasi lewat Supabase Auth; profil & toko dibaca dari tabel
/// `profiles` dan `stores` (lihat supabase/schema.sql).
class AuthRepository {
  AuthRepository({
    required sb.SupabaseClient client,
    required SessionStorage sessionStorage,
  })  : _client = client,
        _storage = sessionStorage;

  final sb.SupabaseClient _client;
  final SessionStorage _storage;

  sb.GoTrueClient get _auth => _client.auth;

  static const _offlineMessage =
      'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.';

  /// Memulihkan sesi yang disimpan Supabase. Null jika belum login.
  Future<UserModel?> restoreSession() async {
    final authUser = _auth.currentUser;
    if (_auth.currentSession == null || authUser == null) {
      await _storage.clear();
      return null;
    }

    try {
      return await _loadAndCacheProfile(authUser);
    } catch (_) {
      // Profil tidak bisa diambil (mis. offline): pakai cache bila cocok.
      final cached = _storage.getUser();
      if (cached != null && cached['id'] == authUser.id) {
        try {
          return UserModel.fromJson(cached);
        } catch (_) {
          // cache rusak, lanjut ke metadata
        }
      }
      return _fromMetadata(authUser);
    }
  }

  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    try {
      final res = await _auth.signInWithPassword(
        email: email,
        password: password,
      );
      final authUser = res.user ?? res.session?.user;
      if (authUser == null) {
        throw const AuthFailure('Email atau kata sandi salah.');
      }
      return await _resolveUser(authUser);
    } catch (e) {
      throw _failure(e, fallback: 'Masuk gagal. Coba lagi.');
    }
  }

  Future<UserModel> register({
    required String name,
    required String storeName,
    required String email,
    required String password,
  }) async {
    try {
      // name & store_name dibaca oleh trigger handle_new_user di database
      // untuk membuat baris profiles dan stores.
      final res = await _auth.signUp(
        email: email,
        password: password,
        data: {'name': name, 'store_name': storeName},
      );

      final authUser = res.user;
      if (authUser == null) {
        throw const AuthFailure('Pendaftaran gagal. Coba lagi.');
      }
      // Email yang sudah terdaftar & terverifikasi: Supabase tidak melempar
      // error (demi privasi), tetapi mengembalikan identities kosong.
      if (authUser.identities != null && authUser.identities!.isEmpty) {
        throw const AuthFailure('Email sudah terdaftar.');
      }
      if (res.session == null) {
        throw const AuthEmailVerificationRequired();
      }
      return await _resolveUser(authUser);
    } catch (e) {
      throw _failure(e, fallback: 'Pendaftaran gagal. Coba lagi.');
    }
  }

  Future<void> logout() async {
    try {
      await _auth.signOut();
    } catch (_) {
      // Server tidak terjangkau: tetap hapus sesi di perangkat ini.
      try {
        await _auth.signOut(scope: sb.SignOutScope.local);
      } catch (_) {}
    }
    await _storage.clear();
  }

  // ---------------------------------------------------------------------------

  /// Profil dari database; bila gagal, jatuh ke metadata akun.
  Future<UserModel> _resolveUser(sb.User authUser) async {
    try {
      return await _loadAndCacheProfile(authUser);
    } catch (_) {
      return _fromMetadata(authUser);
    }
  }

  Future<UserModel> _loadAndCacheProfile(sb.User authUser) async {
    final row = await _client
        .from('profiles')
        .select('name, role, stores(id, store_name, address, phone)')
        .eq('id', authUser.id)
        .single();

    final stores = row['stores'];
    final store =
        stores is List ? (stores.isEmpty ? null : stores.first) : stores;

    final user = UserModel.fromJson({
      'id': authUser.id,
      'name': row['name'],
      'email': authUser.email ?? '',
      'role': row['role'] ?? 'OWNER',
      if (store is Map<String, dynamic>) 'store': store,
    });
    await _storage.saveUser(user.toJson());
    return user;
  }

  UserModel _fromMetadata(sb.User authUser) {
    final meta = authUser.userMetadata ?? const <String, dynamic>{};
    final name = (meta['name'] as String?)?.trim();
    final storeName = (meta['store_name'] as String?)?.trim();
    return UserModel.fromJson({
      'id': authUser.id,
      'name': (name == null || name.isEmpty) ? 'Pemilik Toko' : name,
      'email': authUser.email ?? '',
      'role': 'OWNER',
      if (storeName != null && storeName.isNotEmpty)
        'store': {'id': '', 'store_name': storeName},
    });
  }

  /// Mengubah error apa pun menjadi pesan yang ramah pengguna, sehingga
  /// AuthBloc selalu menerima AuthFailure (loading tidak pernah menggantung).
  AuthFailure _failure(Object error, {required String fallback}) {
    if (error is AuthFailure) return error;

    if (error is SocketException || error is sb.AuthRetryableFetchException) {
      return const AuthFailure(_offlineMessage);
    }

    if (error is sb.AuthException) {
      final code = error.code ?? '';
      final message = error.message.toLowerCase();

      if (code == 'invalid_credentials' ||
          message.contains('invalid login credentials')) {
        return const AuthFailure('Email atau kata sandi salah.');
      }
      if (code == 'email_not_confirmed' ||
          message.contains('email not confirmed')) {
        return const AuthFailure(
          'Email belum diverifikasi. Cek kotak masuk Anda.',
        );
      }
      if (code == 'user_already_exists' ||
          code == 'email_exists' ||
          message.contains('already registered')) {
        return const AuthFailure('Email sudah terdaftar.');
      }
      if (code == 'weak_password') {
        return const AuthFailure(
          'Kata sandi terlalu lemah. Gunakan kombinasi yang lebih kuat.',
        );
      }
      if (code.contains('rate_limit') || '${error.statusCode}' == '429') {
        return const AuthFailure(
          'Terlalu banyak percobaan. Coba lagi beberapa saat.',
        );
      }
    }

    return AuthFailure(fallback);
  }
}
