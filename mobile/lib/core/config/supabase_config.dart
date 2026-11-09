/// Konfigurasi Supabase, dibaca saat build lewat --dart-define.
///
/// Cara paling mudah: salin env.example.json menjadi env.json, isi nilainya,
/// lalu jalankan:
///   flutter run --dart-define-from-file=env.json
///
/// Catatan: anon key memang dirancang publik (aman dipasang di aplikasi)
/// selama Row Level Security aktif. JANGAN pernah memakai service_role key
/// di aplikasi.
abstract final class SupabaseConfig {
  static const url = String.fromEnvironment('SUPABASE_URL');
  static const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
}
