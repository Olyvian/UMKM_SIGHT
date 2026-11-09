# UMKM Sight (Aplikasi Flutter)

Setup awal aplikasi mobile UMKM Sight: halaman **Login** dan **Register**, arsitektur berlapis sesuai class diagram (`go_router` + `flutter_bloc` + repository + `dio` + `shared_preferences`).

## Menjalankan

Folder platform (`android/`, `ios/`) belum disertakan. Buat sekali dengan:

```bash
cd umkm_sight
flutter create . --project-name umkm_sight --org com.umkmsight --platforms android,ios
flutter pub get
flutter run
```

Perintah `flutter create .` tidak menimpa `lib/` maupun `pubspec.yaml` milik project ini. Jika ia membuat `test/widget_test.dart` bawaan, hapus file itu karena merujuk ke `MyApp` yang tidak ada.

Opsi saat menjalankan:

| Opsi | Fungsi |
|---|---|
| `--dart-define=USE_MOCK=false` | Memakai backend Laravel sungguhan (default `true`: login/daftar tiruan, tanpa backend) |
| `--dart-define=API_BASE_URL=https://host/api` | Mengubah alamat API (default `http://10.0.2.2:8000/api` untuk emulator Android) |

Dalam mode mock, login dengan email valid dan kata sandi apa pun akan berhasil.

## Catatan Android (saat memakai backend sungguhan)

Setelah `flutter create`, edit `android/app/src/main/AndroidManifest.xml`:

- Tambahkan `<uses-permission android:name="android.permission.INTERNET"/>` (agar build release bisa mengakses jaringan).
- Untuk API lokal `http://10.0.2.2:8000`, tambahkan `android:usesCleartextTraffic="true"` pada tag `<application>` selama pengembangan (Android 9+ memblokir HTTP biasa). Hapus untuk produksi dan pakai HTTPS.

Font Inter dimuat lewat `google_fonts` (butuh internet saat pertama dijalankan).

## Struktur

```text
lib/
├── main.dart                 # inisialisasi dependensi
├── app.dart                  # MaterialApp.router
├── core/
│   ├── constants/            # ApiConstants
│   ├── network/              # ApiClient (Dio + token interceptor)
│   ├── router/               # AppRouter (go_router, redirect sesuai AuthBloc)
│   ├── storage/              # SessionStorage (shared_preferences)
│   ├── theme/                # AppColors, AppTheme
│   └── utils/                # Validators
└── features/
    ├── auth/
    │   ├── data/             # models, AuthRepository
    │   └── presentation/     # AuthBloc, LoginPage, RegisterPage, widgets
    ├── dashboard/            # placeholder Dashboard
    └── splash/               # pemeriksaan sesi
```

## Kontrak API yang diasumsikan

- `POST /login` `{email, password}` -> `{token, user, store}`
- `POST /register` `{name, store_name, email, password, password_confirmation}` -> `{token, user, store}`
- `POST /logout`

Sesuaikan di `AuthRepository` jika respons Laravel berbeda.

## Belum dikerjakan

- Pendaftaran FCM token ke backend setelah login (`FcmService`)
- Pemulihan kata sandi (tautan "Lupa kata sandi?" masih menampilkan info singkat)
- Dasbor stok, transaksi, prediksi, dan pusat notifikasi
