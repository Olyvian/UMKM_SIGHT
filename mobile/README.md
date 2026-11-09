# UMKM Sight (Aplikasi Flutter)

Aplikasi mobile UMKM Sight: halaman **Login** dan **Register**, lalu **Dashboard** (placeholder).
Flutter terhubung **langsung ke Supabase** (PostgreSQL + Auth) tanpa server backend perantara.
Arsitektur berlapis: `go_router` + `flutter_bloc` + repository + `supabase_flutter`.

## 1. Siapkan Supabase (sekali saja)

1. Buat project di <https://supabase.com> (gratis).
2. Buka **SQL Editor > New query**, tempel isi [`supabase/schema.sql`](supabase/schema.sql), lalu **Run**.
   Ini membuat tabel `profiles` dan `stores`, trigger pendaftaran, dan aturan keamanan (RLS).
3. Untuk pengembangan, matikan verifikasi email agar daftar langsung masuk:
   **Authentication > Providers > Email > matikan "Confirm email"**.
   (Bila dibiarkan aktif, setelah daftar aplikasi meminta pengguna memverifikasi email lebih dulu.)
4. Salin **Project URL** dan **anon public key** dari **Project Settings > API**.

## 2. Jalankan aplikasi

```bash
cp env.example.json env.json        # lalu isi SUPABASE_URL dan SUPABASE_ANON_KEY
flutter create . --project-name umkm_sight --org com.umkmsight --platforms android,ios   # sekali saja
flutter pub get
flutter run --dart-define-from-file=env.json
```

`flutter create .` tidak menimpa `lib/` maupun `pubspec.yaml`. Jika ia membuat `test/widget_test.dart` bawaan, hapus file itu.

Hanya untuk menguji halaman Login (selalu mulai dari keadaan belum login):

```bash
flutter run -t lib/main_login_preview.dart --dart-define-from-file=env.json
```

> `env.json` sudah masuk `.gitignore`. Anon key memang publik dan aman di aplikasi selama RLS aktif.
> **Jangan pernah** memakai `service_role` key di aplikasi.

## Catatan Android

Setelah `flutter create`, edit `android/app/src/main/AndroidManifest.xml` dan tambahkan di atas tag `<application>`:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
```

Tanpa ini build **release** tidak bisa mengakses jaringan. Font Inter dimuat lewat `google_fonts` (butuh internet pada pemakaian pertama).

## Alur aplikasi

- Saat dibuka, Splash memeriksa sesi tersimpan.
- Belum login: hanya Login & Register yang bisa dibuka; halaman lain dialihkan ke Login.
- Sudah login: langsung ke Dashboard; Login/Register tidak bisa dibuka lagi.
- Sesi disimpan dan diperbarui otomatis oleh `supabase_flutter`.

## Struktur

```text
supabase/schema.sql           # tabel, trigger, RLS (jalankan di SQL Editor)
env.example.json              # contoh konfigurasi (salin menjadi env.json)
lib/
├── main.dart                 # entry point
├── main_login_preview.dart   # entry point sementara untuk uji Login
├── bootstrap.dart            # inisialisasi Supabase + dependensi
├── app.dart                  # MaterialApp.router
├── core/
│   ├── config/               # SupabaseConfig, layar "konfigurasi belum diisi"
│   ├── router/               # AppRouter (go_router, redirect sesuai AuthBloc)
│   ├── storage/              # SessionStorage (cache profil)
│   ├── theme/                # AppColors, AppTheme
│   └── utils/                # Validators
└── features/
    ├── auth/
    │   ├── data/             # models, AuthRepository (Supabase Auth + profiles/stores)
    │   └── presentation/     # AuthBloc, LoginPage, RegisterPage, widgets
    ├── dashboard/            # placeholder Dashboard
    └── splash/               # pemeriksaan sesi
```

## Model data

| Tabel | Isi |
|---|---|
| `auth.users` (milik Supabase) | email & kata sandi (di-hash), metadata `name`, `store_name` |
| `profiles` | `id` (UUID = auth.users.id), `name`, `role` (OWNER/ADMIN), `is_active` |
| `stores` | `id`, `user_id` (unik), `store_name`, `address`, `phone` |

## Belum dikerjakan

- Pendaftaran FCM token (notifikasi push)
- Pemulihan kata sandi (tautan "Lupa kata sandi?" masih menampilkan info singkat)
- Dashboard stok, transaksi, prediksi, dan pusat notifikasi
