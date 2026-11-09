import 'package:dio/dio.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/storage/session_storage.dart';
import '../models/user_model.dart';

/// Error yang pesannya aman ditampilkan langsung ke pengguna.
class AuthException implements Exception {
  const AuthException(this.message);
  final String message;

  @override
  String toString() => message;
}

class AuthRepository {
  AuthRepository({
    required ApiClient apiClient,
    required SessionStorage sessionStorage,
  })  : _api = apiClient,
        _storage = sessionStorage;

  final ApiClient _api;
  final SessionStorage _storage;

  /// Memulihkan sesi dari penyimpanan lokal. Null jika belum login.
  Future<UserModel?> restoreSession() async {
    if (_storage.getToken() == null) return null;
    final json = _storage.getUser();
    if (json == null) return null;
    try {
      return UserModel.fromJson(json);
    } catch (_) {
      await _storage.clear();
      return null;
    }
  }

  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    if (ApiConstants.useMock) {
      return _mockSignIn(
        name: _nameFromEmail(email),
        storeName: 'Toko Berkah Jaya',
        email: email,
      );
    }

    try {
      final response = await _api.post(
        ApiConstants.login,
        body: {'email': email, 'password': password},
      );
      return _persist(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw AuthException(
        _messageFrom(e, fallback: 'Email atau kata sandi salah.'),
      );
    }
  }

  Future<UserModel> register({
    required String name,
    required String storeName,
    required String email,
    required String password,
  }) async {
    if (ApiConstants.useMock) {
      return _mockSignIn(name: name, storeName: storeName, email: email);
    }

    try {
      final response = await _api.post(
        ApiConstants.register,
        body: {
          'name': name,
          'store_name': storeName,
          'email': email,
          'password': password,
          'password_confirmation': password,
        },
      );
      return _persist(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw AuthException(
        _messageFrom(e, fallback: 'Pendaftaran gagal. Coba lagi.'),
      );
    }
  }

  Future<void> logout() async {
    if (!ApiConstants.useMock) {
      try {
        await _api.post(ApiConstants.logout);
      } on DioException {
        // Token tetap dihapus di perangkat walau permintaan ke server gagal.
      }
    }
    await _storage.clear();
  }

  // ---------------------------------------------------------------------------

  /// Respons backend (asumsi): { token, user, store }.
  Future<UserModel> _persist(Map<String, dynamic> data) async {
    final userJson = {
      ...(data['user'] as Map<String, dynamic>),
      if (data['store'] != null) 'store': data['store'],
    };
    final user = UserModel.fromJson(userJson);
    await _storage.saveToken(data['token'] as String);
    await _storage.saveUser(user.toJson());
    return user;
  }

  Future<UserModel> _mockSignIn({
    required String name,
    required String storeName,
    required String email,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 800));
    final userJson = {
      'id': 1,
      'name': name,
      'email': email,
      'role': 'OWNER',
      'store': {'id': 1, 'store_name': storeName},
    };
    final user = UserModel.fromJson(userJson);
    await _storage.saveToken('mock-token');
    await _storage.saveUser(user.toJson());
    return user;
  }

  String _nameFromEmail(String email) {
    final local = email.split('@').first;
    if (local.isEmpty) return 'Pemilik Toko';
    return local[0].toUpperCase() + local.substring(1);
  }

  String _messageFrom(DioException e, {required String fallback}) {
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.';
    }
    final data = e.response?.data;
    if (data is Map<String, dynamic> && data['message'] is String) {
      return data['message'] as String;
    }
    return fallback;
  }
}
