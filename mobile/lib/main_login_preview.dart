// ENTRY POINT SEMENTARA untuk menguji halaman Login.
//
// Jalankan dengan:
//   flutter run -t lib/main_login_preview.dart --dart-define-from-file=env.json
//
// Perbedaan dari main.dart: sesi lokal dihapus setiap aplikasi dijalankan,
// sehingga selalu mulai dari keadaan "belum login" dan halaman Masuk selalu
// tampil. Selebihnya sama (Supabase, router, tema), jadi alur Masuk ->
// Dashboard -> Keluar serta tautan ke halaman Daftar tetap bisa dicoba.
//
// Hapus file ini bila sudah tidak diperlukan.
import 'app_startup.dart';

Future<void> main() => startApp(resetSession: true);
