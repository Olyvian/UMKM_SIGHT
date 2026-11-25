import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Cache profil pengguna di shared_preferences, dipakai bila profil belum
/// bisa diambil dari database (mis. aplikasi dibuka tanpa internet).
///
/// Token sesi TIDAK disimpan di sini: dikelola dan disimpan otomatis oleh
/// supabase_flutter.
class SessionStorage {
  SessionStorage(this._prefs);

  final SharedPreferences _prefs;

  static const _userKey = 'auth_user';

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

  Future<void> clear() => _prefs.remove(_userKey);
}
