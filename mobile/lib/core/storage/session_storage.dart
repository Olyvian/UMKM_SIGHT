import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Menyimpan token sesi & profil pengguna di shared_preferences.
class SessionStorage {
  SessionStorage(this._prefs);

  final SharedPreferences _prefs;

  static const _tokenKey = 'auth_token';
  static const _userKey = 'auth_user';

  String? getToken() => _prefs.getString(_tokenKey);

  Future<void> saveToken(String token) => _prefs.setString(_tokenKey, token);

  Map<String, dynamic>? getUser() {
    final raw = _prefs.getString(_userKey);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveUser(Map<String, dynamic> user) =>
      _prefs.setString(_userKey, jsonEncode(user));

  Future<void> clear() async {
    await _prefs.remove(_tokenKey);
    await _prefs.remove(_userKey);
  }
}
