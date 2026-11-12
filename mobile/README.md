# UMKM Sight (Aplikasi Flutter)

Aplikasi mobile UMKM Sight: halaman **Login** dan **Register**, lalu **Dashboard** (placeholder).
Flutter terhubung **langsung ke Supabase** (PostgreSQL + Auth) tanpa server backend perantara.
Arsitektur berlapis: `go_router` + `flutter_bloc` + repository + `supabase_flutter`.

## Panduan untuk anggota tim

Project Supabase **dibuat satu kali oleh pemilik project** dan dipakai bersama. Anggota tim **tidak perlu** membuat project baru dan **tidak perlu** menjalankan `schema.sql` (sudah dijalankan pemilik). Anda hanya perlu terhubung ke project yang sama.

### A. Yang dilakukan pemilik project

1. Undang anggota tim ke project/organisasi Supabase lewat dashboard (menu **Organization → Team** atau **Project Settings → Team**, nama menu dapat berbeda antar versi). Beri peran **Developer** bila ingin anggota bisa melihat data dan menjalankan SQL; cukup bagikan URL + key bila anggota hanya menjalankan aplikasi.
2. Kirim dua nilai berikut ke anggota lewat **pesan pribadi** (jangan lewat repo, issue, atau grup publik):
   - `SUPABASE_URL` (bentuknya `https://xxxx.supabase.co`)
   - `SUPABASE_ANON_KEY` (publishable key, berawalan `sb_publishable_`)
3. Buatkan akun uji bersama (lihat bagian 1.6) dan bagikan emailnya, atau minta anggota mendaftar sendiri dari aplikasi.

> Jangan pernah membagikan key berawalan `sb_secret_` (atau `service_role`) kepada siapa pun, termasuk anggota tim. Aplikasi tidak membutuhkannya.

### B. Langkah untuk anggota tim

1. **Siapkan Flutter**: pasang Flutter SDK (stable) dan Android Studio atau emulator, lalu pastikan `flutter doctor` tidak menampilkan masalah berarti.
2. **Ambil kodenya**:
   ```bash
   git clone <url-repo-tim>
   cd umkm_sight
   ```
3. **Buat file konfigurasi** dan isi dengan nilai dari pemilik:
   ```bash
   cp env.example.json env.json      # Windows: copy env.example.json env.json
   ```
   ```json
   {
     "SUPABASE_URL": "https://kode-project.supabase.co",
     "SUPABASE_ANON_KEY": "sb_publishable_..."
   }
   ```
   `env.json` sudah di `.gitignore`. **Jangan di-commit.**
4. **Folder platform** (`android/`, `ios/`): jika sudah ada di repo, lewati langkah ini. Jika belum, **satu orang saja** yang menjalankan perintah berikut lalu meng-commit hasilnya, supaya anggota lain tidak membuat versi yang berbeda dan bentrok:
   ```bash
   flutter create . --project-name umkm_sight --org com.umkmsight --platforms android,ios
   ```
   Lalu tambahkan izin INTERNET (lihat *Catatan Android*) dan hapus `test/widget_test.dart` bawaan bila terbentuk.
5. **Jalankan**:
   ```bash
   flutter pub get
   flutter run --dart-define-from-file=env.json
   ```
6. **Masuk** dengan akun uji dari pemilik, atau daftar akun baru lewat layar Daftar.

Jika layar "Konfigurasi Supabase belum diisi" muncul atau login gagal, lihat tabel pemecahan masalah di bagian 1.7.

### C. Aturan kerja bersama

Karena database dipakai bersama, data uji semua orang bercampur.

- **Pakai email uji bernama sendiri**, mis. `budi.uji1@tokoberkah.com`, dan hapus akun ujimu setelah selesai (**Authentication → Users**).
- **Jangan menjalankan perintah `DELETE`, `DROP`, atau `TRUNCATE`** di SQL Editor project bersama tanpa memberi tahu tim. Khusus bagian pembersihan di `test_login.sql`: hanya jalankan untuk akun ujimu sendiri.
- **Jangan mematikan RLS** di tabel mana pun, bahkan sementara untuk "mencoba cepat". Bila data tidak muncul, periksa policy-nya.
- **Perubahan skema database** (tabel/kolom/policy baru): ubah `supabase/schema.sql` (tetap bisa dijalankan ulang) lewat pull request. Setelah di-merge, **satu orang** menjalankannya di SQL Editor dan mengabari tim. Jangan mengubah struktur langsung lewat Table Editor tanpa mencatatnya ke file SQL, agar skema di repo selalu sama dengan database.
- **Jangan commit rahasia**: `env.json`, key, atau kata sandi database tidak boleh masuk Git. Bila terlanjur ter-commit, anggap key bocor dan minta pemilik membuat ulang.
- **Ingin lingkungan terpisah?** Tiap anggota boleh membuat project Supabase gratis sendiri dengan mengikuti bagian 1 di bawah, lalu memakai URL dan key miliknya. Cocok untuk eksperimen yang berisiko merusak data bersama.

---

## 1. Setup Supabase (untuk pemilik project, sekali saja)

Aplikasi ini memakai Supabase sebagai database (PostgreSQL) dan sistem login. Semua langkah di bawah dikerjakan di <https://supabase.com> dan gratis untuk kebutuhan pengembangan.

### 1.1 Buat project

1. Daftar atau masuk ke <https://supabase.com>, lalu klik **New project**.
2. Isi **Name** (mis. `umkm-sight`), buat **Database Password** (simpan, tetapi tidak dipakai di aplikasi), dan pilih **Region** terdekat (mis. Singapore).
3. Klik **Create new project** dan tunggu beberapa menit sampai project siap.

### 1.2 Buat tabel dan aturan keamanan

1. Di menu kiri buka **SQL Editor**, lalu klik **New query**.
2. Buka file [`supabase/schema.sql`](supabase/schema.sql) di project ini, salin **seluruh isinya**, tempel ke editor, lalu klik **Run**.
3. Pastikan muncul **Success** tanpa error. Skrip ini membuat:
   - tabel `profiles` (data pengguna) dan `stores` (data toko),
   - trigger yang otomatis membuat profil dan toko saat ada pendaftaran,
   - aturan Row Level Security (RLS): pengguna hanya bisa melihat dan mengubah datanya sendiri.
4. Cek di **Table Editor**: tabel `profiles` dan `stores` harus sudah ada.

Skrip aman dijalankan ulang.

### 1.3 Atur login email

Buka **Authentication → Sign In / Providers** (nama menu bisa sedikit berbeda antar versi dashboard), pilih **Email**, lalu:

- Untuk **pengembangan**: matikan **Confirm email** agar pengguna yang baru mendaftar langsung masuk.
- Untuk **produksi**: biarkan aktif. Setelah daftar, aplikasi akan memberi tahu pengguna untuk memverifikasi email dulu. Email verifikasi dikirim oleh Supabase (batas pengiriman email bawaan cukup kecil, siapkan SMTP sendiri bila dipakai sungguhan).

### 1.4 Ambil URL dan key

Buka **Project Settings → API Keys** (atau **API**), lalu catat dua nilai:

| Nilai | Letaknya | Dipakai sebagai |
|---|---|---|
| **Project URL**, bentuknya `https://xxxx.supabase.co` | Project Settings → API / bagian *Connect* | `SUPABASE_URL` |
| **Publishable key** (`sb_publishable_...`), atau **anon public** pada tampilan lama | Project Settings → API Keys | `SUPABASE_ANON_KEY` |

> **PENTING: jangan memakai key rahasia di aplikasi.**
> Key berawalan `sb_secret_...` (atau `service_role` pada tampilan lama) dapat melewati semua aturan keamanan dan membaca atau menghapus seluruh data. Key ini hanya untuk server tepercaya, **tidak boleh** ada di `env.json`, kode, atau dibagikan di chat/screenshot.
> Jika key rahasia sempat bocor, segera hapus/buat ulang di halaman API Keys.
>
> Publishable/anon key memang publik dan aman dipasang di aplikasi selama RLS aktif (sudah diatur oleh `schema.sql`).

### 1.5 Isi file konfigurasi

Salin `env.example.json` menjadi `env.json` di folder yang sama dengan `pubspec.yaml`, lalu isi:

```json
{
  "SUPABASE_URL": "https://kode-project-anda.supabase.co",
  "SUPABASE_ANON_KEY": "sb_publishable_..."
}
```

Perhatikan: URL harus berbentuk `https://<kode-project>.supabase.co`, **bukan** berisi key. `env.json` sudah masuk `.gitignore` sehingga tidak ikut ter-commit.

### 1.6 Buat akun uji (opsional)

Untuk mencoba login tanpa mendaftar manual, pilih salah satu:

- **Lewat dashboard (paling mudah):** **Authentication → Users → Add user → Create new user**, isi email dan kata sandi, lalu centang **Auto Confirm User**. Profil dan toko dibuat otomatis oleh trigger.
- **Lewat SQL:** jalankan [`supabase/test_login.sql`](supabase/test_login.sql) di SQL Editor (khusus project pengembangan). Ini membuat tiga akun dengan kata sandi `Abcd#1234`:

  | Email | Keterangan |
  |---|---|
  | `budi@tokoberkah.com` | akun aktif |
  | `siti@tokoberkah.com` | akun aktif |
  | `belum.verifikasi@tokoberkah.com` | email belum diverifikasi, login harus ditolak |

  Uji RLS ada di [`supabase/test_login_rls.sql`](supabase/test_login_rls.sql); **jalankan terpisah** (di tab baru), jangan digabung dengan file di atas karena memakai `ROLLBACK`.

Sebelum dipakai pengguna sungguhan, hapus akun uji (lihat bagian pembersihan di `test_login.sql`).

### 1.7 Pemecahan masalah

| Gejala | Penyebab dan solusi |
|---|---|
| Layar "Konfigurasi Supabase belum diisi" | `env.json` belum ada/kosong, atau aplikasi dijalankan tanpa `--dart-define-from-file=env.json`. |
| Gagal terhubung / "Tidak dapat terhubung ke server" | URL salah (mis. tertukar dengan key), tidak ada internet, atau di Android release belum ada izin INTERNET (lihat *Catatan Android*). |
| "Email atau kata sandi salah" padahal benar | Akun belum ada di project ini, atau kata sandi berbeda. Cek di **Authentication → Users**. |
| "Email belum diverifikasi" | Akun belum terverifikasi. Matikan *Confirm email* (langkah 1.3) atau centang *Auto Confirm User* saat membuat akun. |
| Daftar berhasil tetapi nama/toko kosong atau profil tidak ada | `schema.sql` belum dijalankan, atau trigger gagal. Jalankan ulang `schema.sql`, lalu cek `profiles` dan `stores` di Table Editor. |
| "Terlalu banyak percobaan" | Batas permintaan Supabase tercapai (terutama pengiriman email). Tunggu beberapa saat. |
| Skrip `test_login.sql` tidak membuat akun | Jangan gabungkan dengan skrip yang memakai `ROLLBACK`. Jalankan `test_login.sql` sendiri lalu cek di **Authentication → Users**. |

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