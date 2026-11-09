abstract final class ApiConstants {
  /// Alamat backend Laravel.
  /// 10.0.2.2 = localhost komputer host jika dijalankan di emulator Android.
  /// Ganti lewat: flutter run --dart-define=API_BASE_URL=https://api.contoh.com/api
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000/api',
  );

  /// Selama backend belum siap, autentikasi memakai data tiruan (mock).
  /// Matikan lewat: flutter run --dart-define=USE_MOCK=false
  static const useMock = bool.fromEnvironment('USE_MOCK', defaultValue: true);

  static const connectTimeout = Duration(seconds: 10);
  static const receiveTimeout = Duration(seconds: 15);

  static const login = '/login';
  static const register = '/register';
  static const logout = '/logout';
}
