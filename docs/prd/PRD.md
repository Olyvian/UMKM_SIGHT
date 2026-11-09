# PRODUCT REQUIREMENTS DOCUMENT (PRD)

## UMKM Sight
### Aplikasi Mobile Prediksi Kehabisan Stok dan Rekomendasi Restock UMKM Berbasis Time Series Forecasting

**Versi dokumen:** 1.0 — Draft awal untuk validasi tim dan dosen  
**Platform utama:** Android  
**Target pembelajaran:** PBL Terintegrasi TI Semester 5  
**Mata kuliah terintegrasi:** Pemrograman Mobile, Pembelajaran Mesin, Penjaminan Mutu Perangkat Lunak

---

## 1. Ringkasan Produk

UMKM Sight adalah aplikasi mobile Android untuk membantu pemilik usaha kecil memantau persediaan, memperkirakan kapan suatu produk akan habis, dan menerima peringatan restock sebelum terjadi kehabisan stok. Aplikasi menggabungkan data stok saat ini dengan perkiraan permintaan produk dari model *time series forecasting* yang mempelajari riwayat transaksi penjualan.

**Prinsip utama produk:** model machine learning (ML) memperkirakan permintaan pada periode mendatang; sistem inventaris menggunakan prediksi tersebut bersama jumlah stok yang tersedia untuk memperkirakan waktu stok habis dan menentukan kapan pengguna perlu melakukan restock.

Produk dikembangkan sebagai aplikasi mobile Flutter. Backend menyediakan REST API dan menyimpan data transaksional pada PostgreSQL. Layanan ML berbasis Python menyediakan hasil peramalan yang dipanggil oleh backend. Hasil prediksi harus terlihat di aplikasi, bukan hanya ada di notebook atau log server.

### 1.1 Masalah yang ingin diselesaikan

Pemilik UMKM bisa kesulitan memperkirakan kapan persediaan barang akan habis jika pencatatan dan keputusan restock hanya berdasarkan perkiraan manual. Akibatnya, barang dapat habis sebelum pengadaan berikutnya atau persediaan terlalu banyak. UMKM Sight membantu pengguna melihat perkiraan waktu stok habis berdasarkan data yang tersedia dan mengambil keputusan restock lebih awal.

### 1.2 Tujuan produk

1. Menyediakan pencatatan stok produk dan transaksi penjualan melalui aplikasi mobile.
2. Memperkirakan permintaan produk untuk periode mendatang menggunakan model time series forecasting.
3. Memperkirakan tanggal atau rentang waktu stok diperkirakan habis dengan menggabungkan hasil prediksi dan stok tersedia.
4. Menampilkan peringatan dan rekomendasi restock sesuai aturan yang ditetapkan.
5. Menghasilkan evaluasi model yang terukur serta dokumen QA dengan hasil pengujian aktual.

### 1.3 Indikator keberhasilan awal

- Aplikasi Android dapat dipasang dan didemonstrasikan secara langsung pada perangkat atau emulator.
- Minimal empat layar/route fungsional dengan navigasi terstruktur; target desain MVP adalah lima layar utama.
- Sedikitnya satu fitur ML terintegrasi dan menampilkan hasil prediksi pada antarmuka.
- Model memiliki baseline pembanding, pembagian data berdasarkan urutan waktu, metrik evaluasi yang sesuai, visualisasi hasil, serta analisis kesalahan.
- Minimal 15–20 test case dijalankan dengan hasil Pass/Fail tercatat.
- Minimal satu pengujian nonfungsional dilaksanakan. Target awal respons API prediksi adalah di bawah 5 detik pada lingkungan pengujian yang ditentukan; target ini perlu diukur, bukan diasumsikan tercapai.
- Logbook mingguan, bug log, laporan evaluasi ML, dan laporan QA disimpan sebagai artefak proyek.

---

## 2. Pengguna dan Batasan Penggunaan

### 2.1 Pengguna utama

**Pemilik UMKM / pemilik toko** adalah pengguna utama. Pengguna mengelola produk, memperbarui persediaan, mencatat transaksi, melihat estimasi stok habis, dan menerima peringatan restock.

### 2.2 Batasan pengguna untuk MVP

- Satu akun mewakili satu toko/outlet.
- Satu akun pemilik mengelola data toko tersebut.
- Sistem tidak ditujukan untuk pengelolaan banyak cabang atau transfer stok antargudang pada MVP.
- Akun staf dengan izin berbeda, multi-outlet, dan kontrol akses lanjutan bukan bagian dari MVP kecuali diwajibkan dosen atau diputuskan tim.

### 2.3 Asumsi produk

- Pengguna memiliki perangkat Android dan umumnya memiliki koneksi internet untuk sinkronisasi dengan server.
- Data penjualan yang tercatat cukup konsisten untuk dianalisis.
- Model hanya menghasilkan estimasi, bukan jaminan bahwa stok akan habis tepat pada tanggal tertentu.
- Pengguna tetap mengambil keputusan akhir untuk membeli atau menambah stok.

---

## 3. Ruang Lingkup

### 3.1 Termasuk dalam MVP

1. Registrasi/login dan profil toko sederhana.
2. CRUD produk dan informasi stok.
3. Pencatatan transaksi penjualan yang memperbarui stok.
4. Pencatatan stok masuk/restock dan penyesuaian stok.
5. Ringkasan stok dan status risiko produk.
6. Prediksi permintaan produk untuk horizon awal tujuh hari, jika data mencukupi.
7. Estimasi waktu stok habis berdasarkan stok tersedia dan prediksi permintaan kumulatif.
8. Riwayat prediksi dan grafik aktual vs. prediksi.
9. Peringatan restock di dalam aplikasi; push notification Android menjadi target MVP jika konfigurasi layanan notifikasi dapat diselesaikan.
10. QA Plan, 15–20 test case atau lebih, pengujian nonfungsional, bug log, dan laporan hasil pengujian.

### 3.2 Tidak termasuk dalam MVP

- Payment gateway, pembayaran digital, akuntansi kompleks, pajak, atau ERP.
- Multi-gudang dan pengelolaan banyak cabang.
- Aplikasi native iOS.
- Model deep learning kompleks atau banyak model ML sekaligus.
- Prediksi yang diklaim pasti tanpa rentang ketidakpastian.
- Integrasi langsung dengan sistem kasir pihak ketiga.
- Pengiriman/pemesanan barang otomatis ke pemasok.
- Mode offline penuh dengan sinkronisasi konflik multi-perangkat.

### 3.3 Prioritas fitur

- **P0 — wajib:** autentikasi dasar, produk, stok, transaksi, prediksi terintegrasi, estimasi stok habis, hasil terlihat pada aplikasi, pengujian dan evaluasi.
- **P1 — penting jika memungkinkan:** push notification Android, riwayat peringatan, cache data sederhana, pilihan horizon tambahan 14 atau 30 hari setelah kualitas data dinilai.
- **P2 — pengembangan selanjutnya:** multi-user/role, multi-outlet, pemasok dan purchase order, rekomendasi jumlah pemesanan yang lebih kompleks, sinkronisasi offline penuh.

---

## 4. Alur Penggunaan Utama

### 4.1 Alur pemantauan stok hingga restock

1. Pengguna login dan masuk ke dashboard.
2. Pengguna menambahkan produk beserta kode/nama, satuan, dan stok awal.
3. Pengguna mencatat transaksi penjualan atau stok masuk. Sistem memperbarui stok sesuai transaksi yang tersimpan.
4. Sistem mengirim riwayat permintaan produk yang relevan ke layanan ML.
5. Layanan ML mengembalikan prediksi permintaan per periode untuk produk yang dipilih.
6. Sistem menggabungkan prediksi dengan stok yang tersedia untuk menghitung estimasi kapan stok akan habis.
7. Dashboard menampilkan stok saat ini, grafik prediksi, perkiraan waktu stok habis, dan status risiko.
8. Jika aturan restock terpenuhi, aplikasi menampilkan peringatan. Push notification dikirim apabila layanan push telah dikonfigurasi dan izin pengguna tersedia.
9. Pengguna menambah stok setelah pengadaan dan stok diperbarui melalui pencatatan stok masuk.

### 4.2 Kondisi saat data tidak mencukupi

Jika riwayat suatu produk terlalu pendek, tidak berurutan, atau tidak layak untuk diprediksi, sistem tidak boleh menampilkan angka prediksi seolah-olah valid. Tampilkan status seperti **“Data belum cukup untuk membuat prediksi”**, jelaskan data yang dibutuhkan, dan tetap izinkan pengguna mengelola stok secara manual.

---

## 5. Kebutuhan Fungsional

| ID | Fitur | Kebutuhan | Kriteria penerimaan ringkas | Prioritas |
|---|---|---|---|---|
| FR-01 | Autentikasi | Pengguna dapat registrasi, login, dan logout. | Data tidak valid ditolak dengan pesan yang jelas; endpoint terlindungi. | P0 |
| FR-02 | Profil toko | Pengguna dapat melihat dan mengubah nama/profil toko. | Perubahan tersimpan dan tetap tampil setelah login ulang. | P0 |
| FR-03 | Produk | Pengguna dapat membuat, melihat, mengubah, dan menonaktifkan produk. | Produk memiliki nama, kode unik per toko, satuan, dan stok. | P0 |
| FR-04 | Transaksi penjualan | Pengguna dapat mencatat produk dan kuantitas terjual. | Stok berkurang secara konsisten; transaksi invalid ditolak. | P0 |
| FR-05 | Stok masuk/penyesuaian | Pengguna dapat mencatat stok masuk dan penyesuaian dengan alasan. | Perubahan stok tersimpan sebagai riwayat pergerakan stok. | P0 |
| FR-06 | Dashboard | Pengguna melihat ringkasan stok dan item berisiko. | Data ringkasan sesuai data inventaris dan transaksi. | P0 |
| FR-07 | Prediksi permintaan | Pengguna meminta/melihat prediksi untuk produk yang datanya layak. | Prediksi dan periode prediksi terlihat pada aplikasi. | P0 |
| FR-08 | Estimasi stok habis | Sistem menghitung estimasi dari stok tersedia dan permintaan prediksi kumulatif. | Sistem menampilkan perkiraan tanggal/rentang atau menyatakan stok tidak diprediksi habis dalam horizon. | P0 |
| FR-09 | Status risiko | Sistem memberi label risiko berdasarkan waktu stok habis dan parameter restock. | Ambang risiko konsisten dengan aturan yang terdokumentasi. | P0 |
| FR-10 | Notifikasi | Sistem memberi peringatan ketika aturan restock terpenuhi. | Tidak mengirim notifikasi berulang untuk peristiwa yang sama tanpa aturan pengulangan. | P1 |
| FR-11 | Riwayat prediksi | Pengguna dapat melihat prediksi sebelumnya dan waktu pembuatannya. | Riwayat memuat produk, waktu dibuat, horizon, dan hasil prediksi. | P1 |
| FR-12 | Riwayat pergerakan stok | Pengguna dapat melihat transaksi/stok masuk yang mengubah jumlah stok. | Setiap perubahan stok dapat ditelusuri ke sumbernya. | P0 |
| FR-13 | Penanganan error | Aplikasi menampilkan status loading, error, dan opsi mencoba kembali. | Error API tidak membuat aplikasi crash atau menampilkan angka palsu. | P0 |

---

## 6. Struktur Layar dan Navigasi

MVP menargetkan minimal lima layar/route fungsional.

| Layar | Konten utama | Aksi pengguna |
|---|---|---|
| 1. Login/Register | Form autentikasi dan validasi input | Masuk atau membuat akun |
| 2. Dashboard | Ringkasan jumlah produk, stok rendah, dan risiko stok habis | Membuka produk berisiko atau melihat detail |
| 3. Produk & Detail Produk | Daftar produk, stok, satuan, histori pergerakan | Tambah/edit produk, catat stok masuk |
| 4. Transaksi | Form transaksi dan riwayat transaksi | Mencatat penjualan dan memeriksa transaksi |
| 5. Analitik & Prediksi | Grafik historis, hasil forecasting, estimasi stok habis, status risiko | Memilih produk/horizon dan melihat hasil |
| 6. Notifikasi (P1) | Riwayat peringatan dan status tindak lanjut | Membuka peringatan terkait produk |

**Navigasi:** gunakan `go_router` atau pola routing terstruktur setara.  
**State management:** pilih satu pendekatan untuk seluruh aplikasi (rekomendasi awal: Riverpod).  
**HTTP client:** pilih satu library (rekomendasi awal: Dio).  
Pilihan pustaka tersebut adalah keputusan implementasi yang direkomendasikan untuk mengurangi ambiguitas saat vibe coding dan tetap perlu disepakati tim.

---

## 7. Aturan Bisnis dan Logika Prediksi

### 7.1 Pengelolaan stok

- Setiap produk memiliki jumlah stok tersedia saat ini.
- Transaksi penjualan mengurangi stok setelah transaksi berhasil divalidasi dan disimpan.
- Stok masuk menambah stok serta mencatat waktu dan sumber perubahan.
- Penyesuaian manual harus mencatat alasan.
- Secara default, sistem menolak transaksi yang membuat stok negatif. Perilaku ini hanya boleh diubah melalui keputusan produk yang eksplisit.
- Perubahan stok harus konsisten dengan riwayat pergerakan stok; jangan memperbarui angka stok tanpa jejak perubahan.

### 7.2 Input dan proses ML

1. Agregasikan kuantitas penjualan menjadi rangkaian waktu per produk pada frekuensi yang dipilih.
2. Bersihkan data invalid dan transaksi retur/pembatalan berdasarkan aturan praproses yang didokumentasikan.
3. Periksa kecukupan serta rentang waktu data sebelum pelatihan atau inferensi.
4. Pisahkan data latih dan data uji berdasarkan urutan waktu, bukan pembagian acak.
5. Latih baseline sederhana, misalnya moving average.
6. Evaluasi satu model kandidat lain yang dipilih berdasarkan kelayakan data dan waktu tim. Kandidat dapat berupa SARIMA atau Prophet; finalisasi setelah eksperimen awal.
7. Laporkan metrik pada data uji dan lakukan analisis contoh prediksi yang meleset.
8. Simpan metadata model, waktu prediksi, horizon, metrik evaluasi, dan hasil prediksi yang relevan.

### 7.3 Estimasi stok habis

Misalkan `S0` adalah stok yang tersedia ketika prediksi dibuat, dan `F(d)` adalah permintaan yang diprediksi untuk hari ke-d. Sistem menghitung permintaan prediksi kumulatif. Estimasi stok habis adalah periode pertama saat permintaan kumulatif mencapai atau melampaui `S0`.

- Jika permintaan kumulatif mencapai stok dalam horizon prediksi, tampilkan perkiraan hari/tanggal stok habis.
- Jika permintaan kumulatif belum mencapai stok sampai akhir horizon, tampilkan **“Stok diperkirakan cukup selama horizon prediksi”**, bukan tanggal habis yang dibuat-buat.
- Jika stok saat ini nol, tampilkan status **“Stok habis”** tanpa menunggu hasil model.
- Jika data tidak layak, tampilkan status **“Prediksi belum tersedia”** dan alasan yang dapat dipahami pengguna.
- Karena forecasting tidak pasti, gunakan istilah **perkiraan** dan tampilkan waktu terakhir data/prediksi diperbarui.

### 7.4 Aturan peringatan restock

Untuk MVP, sistem menandai produk sebagai berisiko ketika perkiraan stok habis berada dalam ambang waktu restock yang dikonfigurasi. Jika lead time pemasok belum diketahui, gunakan parameter awal yang dapat diubah oleh tim/pengguna dan jelaskan bahwa nilainya adalah asumsi, bukan hasil model.

Aturan yang perlu disepakati sebelum implementasi:

- Nilai default lead time (jumlah hari pengadaan).
- Apakah safety stock digunakan pada MVP.
- Berapa lama status peringatan dianggap aktif.
- Kapan peringatan boleh dikirim ulang setelah stok diperbarui.

Jangan mengklaim bahwa sistem mengoptimalkan jumlah pembelian secara akurat jika fitur MVP hanya memperkirakan waktu stok habis.

### 7.5 Evaluasi model

- Gunakan **MAE dan RMSE** sebagai metrik regresi utama.
- MAPE dapat ditambahkan apabila data aktual yang bernilai nol ditangani dengan benar; jangan membagi dengan nilai aktual nol.
- Bandingkan model kandidat dengan baseline pada periode uji yang sama.
- Laporkan rentang tanggal data latih/uji, frekuensi agregasi, jumlah data setelah praproses, dan keterbatasan dataset.
- Target MAPE ≤ 20% boleh ditulis sebagai target eksplorasi, bukan jaminan kelulusan model.

---

## 8. Data dan Rancangan Entitas Awal

Rancangan berikut adalah model awal yang bisa disesuaikan saat implementasi. Nama kolom dapat berubah, tetapi relasi dan aturan konsistensinya harus dipertahankan.

| Entitas | Kolom inti yang disarankan | Kegunaan |
|---|---|---|
| users | id, name, email, password_hash, timestamps | Akun pengguna |
| stores | id, owner_user_id, name, timestamps | Profil satu toko untuk satu akun pada MVP |
| products | id, store_id, sku, name, unit, current_stock, lead_time_days, is_active, timestamps | Katalog produk dan stok terkini |
| sales | id, store_id, transaction_date, notes, timestamps | Header transaksi penjualan |
| sale_items | id, sale_id, product_id, quantity, unit_price (opsional) | Produk dan kuantitas dalam transaksi |
| stock_movements | id, product_id, movement_type, quantity_delta, reason, source_type, source_id, created_at | Jejak perubahan stok |
| forecast_runs | id, product_id, model_version, forecast_horizon, generated_at, status, metrics_json (opsional) | Metadata proses prediksi |
| forecast_values | id, forecast_run_id, forecast_date, predicted_demand | Hasil permintaan prediksi per tanggal |
| restock_alerts | id, product_id, forecast_run_id, estimated_stockout_date (nullable), status, triggered_at, resolved_at (nullable) | Riwayat peringatan dan tindak lanjut |

**Catatan data:** dataset publik transaksi retail dapat digunakan untuk eksperimen historis model permintaan. Jika dataset tidak mengandung stok awal/aktual, gunakan stok simulasi yang diberi label jelas untuk menguji perhitungan stok habis dan alur aplikasi. Jangan menyatakan bahwa prediksi stok habis telah divalidasi pada data stok UMKM nyata kecuali tim benar-benar memiliki data tersebut.

---

## 9. Arsitektur Sistem yang Direkomendasikan

### 9.1 Komponen

- **Mobile app:** Flutter/Dart untuk antarmuka Android.
- **Backend API:** Laravel untuk autentikasi, produk, transaksi, stok, aturan peringatan, dan orkestrasi permintaan prediksi.
- **Database:** PostgreSQL untuk akun, toko, produk, transaksi, pergerakan stok, metadata prediksi, dan peringatan.
- **ML service:** Python API (misalnya FastAPI) untuk praproses dan inferensi model forecasting.
- **Push notification:** layanan push Android seperti Firebase Cloud Messaging dapat dipertimbangkan untuk P1, dengan penanganan izin, token perangkat, dan kegagalan pengiriman. Pilihan ini perlu divalidasi tim sebelum implementasi.

### 9.2 Alur permintaan prediksi

1. Flutter meminta detail prediksi ke Laravel.
2. Laravel memeriksa autentikasi, kepemilikan produk, kecukupan data, dan stok saat ini.
3. Laravel mengirim data historis yang dibutuhkan ke ML service.
4. ML service memvalidasi input dan mengembalikan prediksi serta metadata model.
5. Laravel menghitung estimasi waktu stok habis dan status restock, lalu menyimpan hasil yang diperlukan.
6. Flutter menampilkan hasil, status loading, atau pesan data tidak cukup/error.

**Prinsip keamanan:** klien mobile tidak mengakses database secara langsung dan tidak boleh dipercaya sebagai sumber kebenaran untuk jumlah stok. Validasi stok dan perubahan transaksi harus dilakukan pada backend.

---

## 10. Rancangan API Awal

Endpoint berikut adalah kontrak awal untuk membantu implementasi; format response final dapat ditetapkan tim selama konsisten dan terdokumentasi.

| Method | Endpoint | Fungsi |
|---|---|---|
| POST | `/api/register` | Membuat akun |
| POST | `/api/login` | Login dan memperoleh token |
| POST | `/api/logout` | Logout/revoke token sesuai mekanisme autentikasi |
| GET/PUT | `/api/store` | Melihat/mengubah profil toko |
| GET/POST | `/api/products` | Daftar dan tambah produk |
| GET/PUT/DELETE | `/api/products/{id}` | Detail, ubah, atau nonaktifkan produk |
| POST | `/api/sales` | Membuat transaksi penjualan dan memperbarui stok secara konsisten |
| GET | `/api/sales` | Melihat riwayat transaksi |
| POST | `/api/products/{id}/stock-movements` | Mencatat stok masuk/penyesuaian |
| GET | `/api/products/{id}/stock-movements` | Melihat riwayat pergerakan stok |
| POST | `/api/products/{id}/forecast` | Membuat atau meminta prediksi |
| GET | `/api/products/{id}/forecasts/latest` | Mendapatkan prediksi terbaru beserta estimasi stok habis |
| GET | `/api/alerts` | Melihat riwayat peringatan |
| PATCH | `/api/alerts/{id}` | Menandai peringatan sebagai ditinjau/selesai |

Setiap response API perlu memiliki format konsisten untuk keberhasilan dan error. Endpoint harus memeriksa otorisasi agar pengguna tidak dapat membaca atau mengubah data toko lain.

---

## 11. Kebutuhan Nonfungsional

### 11.1 Kinerja

- Target awal waktu respons endpoint prediksi: kurang dari 5 detik pada lingkungan dan ukuran data uji yang didefinisikan tim.
- Loading dan proses permintaan prediksi harus memiliki indikator yang jelas.
- Pengujian kinerja perlu mencatat perangkat/lingkungan, jumlah data, jumlah percobaan, dan hasil pengukuran. Jangan menyatakan target tercapai tanpa bukti pengujian.

### 11.2 Keamanan dan privasi

- Password tidak boleh disimpan sebagai teks biasa.
- Endpoint yang mengubah atau membaca data privat harus memerlukan autentikasi dan otorisasi.
- Token disimpan menggunakan mekanisme penyimpanan yang sesuai; pertimbangkan secure storage untuk token sensitif.
- Validasi input dilakukan pada aplikasi dan backend.
- Jangan memasukkan data rahasia, kredensial, token, atau file `.env` ke repository publik.

### 11.3 Reliabilitas dan penanganan error

- Aplikasi tidak crash ketika API atau ML service gagal.
- Pesan error tidak membocorkan stack trace, token, atau informasi sensitif.
- Kegagalan layanan ML tidak boleh menurunkan stok atau membuat transaksi penjualan tersimpan sebagian.
- Operasi transaksi penjualan dan perubahan stok harus konsisten dan aman dari pembaruan ganda.

### 11.4 Usability dan kompatibilitas

- Antarmuka dirancang untuk layar Android umum.
- Teks stok, tanggal prediksi, dan label risiko mudah dipahami pengguna nonteknis.
- Grafik memiliki label tanggal dan jumlah yang terbaca.
- Uji setidaknya pada satu perangkat fisik atau emulator; bila memungkinkan gunakan lebih dari satu ukuran layar.

### 11.5 Maintainability dan dokumentasi

- Kode mobile, backend, dan ML service dipisahkan sesuai tanggung jawabnya.
- Konfigurasi lingkungan melalui environment variables; jangan hardcode secret.
- Sediakan README setup, migrasi database, cara menjalankan tiap service, cara menjalankan tes, dan cara build APK.
- Semua kode/model/dataset/libraries pihak ketiga yang digunakan harus diberi atribusi sesuai ketentuan dan lisensinya.

---

## 12. QA Plan Awal dan Contoh Test Case

Setiap test case final setidaknya memuat ID, prasyarat, langkah, data uji, hasil yang diharapkan, hasil aktual, Pass/Fail, dan catatan defect bila ada.

| ID | Area | Skenario | Hasil yang diharapkan |
|---|---|---|---|
| TC-01 | Auth | Login dengan kredensial valid | Pengguna masuk ke dashboard |
| TC-02 | Auth | Login dengan password salah | Login ditolak dengan pesan yang aman |
| TC-03 | Produk | Tambah produk dengan input valid | Produk tersimpan dan tampil |
| TC-04 | Produk | Tambah produk tanpa nama/kode wajib | Validasi menolak input |
| TC-05 | Produk | SKU duplikat dalam toko yang sama | Duplikasi ditolak atau ditangani sesuai aturan yang terdokumentasi |
| TC-06 | Stok | Catat stok masuk | Stok bertambah dan riwayat movement tercatat |
| TC-07 | Transaksi | Catat penjualan valid | Transaksi tersimpan dan stok berkurang |
| TC-08 | Transaksi | Jual lebih banyak daripada stok tersedia | Sistem menolak transaksi pada MVP |
| TC-09 | Konsistensi | Ulangi pengiriman request transaksi yang sama | Tidak terjadi pengurangan stok ganda jika mekanisme idempotensi diterapkan |
| TC-10 | Forecast | Produk memiliki data cukup | Prediksi tersedia dan memiliki horizon yang jelas |
| TC-11 | Forecast | Produk memiliki data tidak cukup | Pesan data belum cukup, tidak ada prediksi palsu |
| TC-12 | Forecast | Data aktual mengandung hari tanpa transaksi | Praproses mengikuti aturan yang terdokumentasi |
| TC-13 | Stockout | Permintaan kumulatif melewati stok dalam horizon | Estimasi stok habis ditampilkan |
| TC-14 | Stockout | Prediksi kumulatif tidak melewati stok dalam horizon | Aplikasi menyatakan stok diperkirakan cukup selama horizon |
| TC-15 | Stockout | Stok saat ini nol | Status langsung menunjukkan stok habis |
| TC-16 | Alert | Estimasi stok habis berada dalam ambang restock | Peringatan dibuat sesuai aturan |
| TC-17 | Alert | Peringatan aktif yang sama dievaluasi berulang | Tidak terjadi spam duplikat tanpa aturan pengiriman ulang |
| TC-18 | Integrasi | ML service tidak dapat diakses | Aplikasi menampilkan error dan tetap menjaga data stok/transaksi |
| TC-19 | Kinerja | Ukur response time endpoint prediksi | Waktu aktual dicatat dan dibandingkan dengan target `< 5 detik` |
| TC-20 | Kompatibilitas/usability | Aplikasi dibuka pada ukuran layar Android yang berbeda | Konten utama tidak terpotong dan alur inti tetap dapat digunakan |

Tabel ini merupakan rancangan awal, bukan bukti bahwa pengujian sudah dilakukan. Tim harus menjalankan test case, menyimpan hasil aktual, mencatat bug, memperbaiki bug yang ditemukan, dan menerbitkan laporan QA final.

### 12.1 Format bug log minimum

- Bug ID dan tanggal ditemukan.
- Versi aplikasi/lingkungan uji.
- Ringkasan bug dan langkah reproduksi.
- Hasil yang diharapkan vs. hasil aktual.
- Severity/prioritas.
- Screenshot/log yang relevan tanpa rahasia.
- Penanggung jawab dan status (Open, In Progress, Resolved, Retest, Closed/Known Issue).

---

## 13. Rencana Implementasi 16 Minggu

| Periode | Fokus | Deliverable utama |
|---|---|---|
| Minggu 1–3 | Validasi masalah, calon pengguna, dataset, kelayakan model, arsitektur awal | Pernyataan masalah, profil pengguna, catatan dataset, keputusan MVP |
| Minggu 4 | Review proposal dan QA Plan awal | PRD/proposal final, rancangan arsitektur, QA Plan awal (CP-1) |
| Minggu 5–6 | Scaffolding Flutter/backend, skema database, praproses data dan baseline | Aplikasi dasar berjalan, migrasi database, baseline model |
| Minggu 7–8 | Integrasi awal forecast dan UI, evaluasi baseline | Demo Milestone 1, hasil baseline, logbook minggu 1–8 (CP-2) |
| Minggu 9–10 | Fitur inti produk dan model kandidat, perhitungan stockout | Prediksi tampil pada aplikasi, estimasi stok habis, QA Plan diperbarui |
| Minggu 11–12 | Integrasi alur utama, test case interim, bug awal | Demo produk fungsional dan laporan QA interim (CP-3) |
| Minggu 13–14 | Eksekusi test case lengkap, perbaikan bug, evaluasi model final | Hasil pass/fail, bug log, metrik final dan analisis kesalahan |
| Minggu 15 | Build APK, dokumentasi dan persiapan demo | APK rilis, laporan akhir dan QA final draf |
| Minggu 16 | Demo live/expo dan refleksi | Produk final, APK, source code/Git, laporan QA, evaluasi ML, presentasi dan peer assessment (CP-4) |

Logbook diperbarui setiap minggu berisi pekerjaan selesai, hambatan, keputusan, kontribusi anggota, dan rencana minggu berikutnya. Timeline ini harus diperbarui jika ada hasil review dosen atau perubahan ruang lingkup.

---

## 14. Risiko dan Mitigasi

| Risiko | Dampak | Mitigasi |
|---|---|---|
| Dataset publik tidak memiliki stok aktual | Tidak dapat langsung memvalidasi tanggal stok habis nyata | Pisahkan evaluasi model permintaan dari pengujian logika stockout; gunakan stok simulasi berlabel atau cari mitra/data aktual |
| Penjualan produk sangat jarang/tidak stabil | Forecast tidak andal | Tentukan kriteria data minimum, tampilkan status tidak cukup data, gunakan baseline dan analisis error |
| Ruang lingkup terlalu besar | Integrasi terlambat | Fokus pada satu model utama, satu alur inti, dan tunda fitur P1/P2 jika mengancam milestone |
| ML service gagal atau lambat | Prediksi tidak tampil | Timeout, retry terbatas, pesan error jelas, dan uji integrasi |
| Perhitungan stok tidak konsisten | Estimasi stok habis salah | Semua perubahan stok melalui backend dan dicatat di stock movements |
| Push notification memakan waktu | Fitur notifikasi terlambat | Prioritaskan status risiko di dalam aplikasi; push notification menyusul setelah alur inti stabil |
| Data uji bocor ke data latih | Evaluasi model terlalu optimistis | Gunakan pembagian kronologis dan dokumentasikan tanggal train/test |
| Perubahan kode oleh AI tidak dipahami | Bug dan kesulitan saat presentasi | Review setiap perubahan, pahami kode, jalankan tes, dokumentasikan penggunaan AI sesuai aturan akademik |

---

## 15. Keputusan yang Harus Dikunci Tim Sebelum Coding Penuh

1. **Sumber data:** apakah tim memperoleh data transaksi/stok dari UMKM nyata, atau menggunakan dataset publik ditambah stok simulasi?
2. **Definisi stok habis:** apakah yang dimaksud estimasi tanggal stok mencapai nol, atau tanggal stok tidak cukup untuk memenuhi permintaan? Untuk MVP, gunakan estimasi tanggal stok habis dan jelaskan batasannya.
3. **Horizon prediksi:** rekomendasi awal tujuh hari; 14/30 hari hanya jika data dan model mendukung.
4. **Model:** moving average sebagai baseline dan satu kandidat utama (misalnya SARIMA atau Prophet) setelah evaluasi kelayakan.
5. **Aturan peringatan:** default lead time, safety stock bila digunakan, deduplikasi peringatan, dan kondisi penutupan alert.
6. **Push notification:** apakah masuk MVP wajib atau boleh menjadi P1 setelah peringatan di dalam aplikasi berfungsi?
7. **Teknologi final:** versi Flutter/backend/Python dan pemilihan pustaka state management serta HTTP client.
8. **Lingkungan demo/deployment:** laptop/server lokal atau hosting, cara mobile app mengakses API saat demo, dan lokasi penyimpanan model.

Keputusan ini jangan dibiarkan ambigu ketika AI mulai membuat kode. Jika belum disepakati, minta AI mencatat opsi dan konsekuensinya, bukan memilih secara diam-diam.

---

## 16. Master Prompt untuk Vibe Coding

Salin prompt berikut ke AI coding tool setelah menambahkan PRD ini ke konteks proyek.

> Kamu bertindak sebagai senior software engineer dan technical mentor untuk proyek mahasiswa bernama UMKM Sight. Baca PRD lengkap sebelum menulis kode. Produk adalah aplikasi Flutter Android yang membantu pemilik UMKM mengelola stok, memprediksi permintaan per produk menggunakan time series forecasting, memperkirakan kapan stok habis dengan menggabungkan prediksi dan stok tersedia, serta memberi peringatan restock.
>
> Arsitektur yang direncanakan: Flutter mobile → Laravel REST API → PostgreSQL; Laravel berkomunikasi dengan Python ML API untuk inferensi. Jangan hubungkan Flutter langsung ke database. Backend menjadi sumber kebenaran untuk stok dan transaksi.
>
> Bekerjalah bertahap dan jangan menghasilkan seluruh aplikasi sekaligus. Tahap pertama: ringkas pemahaman PRD, daftarkan keputusan yang belum dikunci, ajukan arsitektur dan struktur folder, susun backlog implementasi, serta jelaskan risiko teknis sebelum menulis kode. Jangan mengarang data atau mengklaim fitur sudah selesai tanpa menjalankan pemeriksaan yang relevan.
>
> Setelah rencana disetujui, implementasikan satu modul pada satu waktu. Untuk setiap modul, sertakan file yang dibuat/diubah, perintah menjalankan aplikasi, konfigurasi environment yang diperlukan, validasi input, penanganan error, dan tes yang relevan. Pertahankan kontrak API yang konsisten. Gunakan migrasi database dan data seed khusus development/demo; jangan menyamakan data simulasi dengan data nyata.
>
> Untuk ML, mulai dengan baseline sederhana. Gunakan time-based train/test split, laporkan MAE/RMSE dan keterbatasan data, dan jangan menjanjikan MAPE ≤ 20% sebelum hasil evaluasi tersedia. Model menghasilkan prediksi permintaan; estimasi waktu stok habis dihitung dari stok tersedia dan prediksi kumulatif. Jika data tidak cukup atau service gagal, tampilkan keadaan error/tidak tersedia dengan jelas—jangan membuat angka prediksi palsu.
>
> Untuk QA, siapkan test case yang dapat dieksekusi, terutama konsistensi stok, transaksi, data yang tidak cukup, integrasi ML, estimasi stok habis, deduplikasi alert, dan waktu respons API. Jangan menandai test sebagai lulus sebelum dijalankan. Jangan menaruh secret di source code. Jelaskan kode dengan bahasa yang bisa dipahami mahasiswa dan pastikan saya memahami perubahan sebelum melanjutkan ke modul berikutnya.

### 16.1 Urutan prompt implementasi yang disarankan

1. **Analisis dan fondasi:** minta AI memvalidasi PRD, mengidentifikasi keputusan terbuka, menentukan struktur repository dan kontrak API. Belum perlu membuat semua fitur.
2. **Backend dan database:** buat autentikasi, migrasi, produk, pergerakan stok, dan transaksi; uji konsistensi stok sebelum integrasi ML.
3. **ML pipeline:** siapkan praproses dataset, baseline, pembagian data kronologis, evaluasi, artefak model, dan endpoint prediksi.
4. **Mobile MVP:** buat login, dashboard, produk, transaksi, serta layar analitik memakai data API yang nyata. Mock data hanya untuk development dan harus diberi label.
5. **Integrasi stockout:** hubungkan hasil prediksi dengan stok tersedia, tampilkan estimasi stok habis dan kondisi data tidak cukup.
6. **Alert dan QA:** implementasikan aturan alert, push notification bila sudah dipilih, jalankan test case, catat bug, dan perbaiki masalah.
7. **Rilis dan demo:** build APK, siapkan data demo, README, laporan hasil model, laporan QA, dan skenario demo langsung.

---

## 17. Definisi Selesai (Definition of Done)

Fitur tidak dianggap selesai hanya karena kode berhasil dibuat. Sebuah fitur dianggap selesai jika:

- Fungsinya sesuai requirement dan dapat dijalankan pada lingkungan target.
- Validasi input dan kondisi error sudah ditangani.
- Integrasi dengan data/API benar dan tidak memakai placeholder tanpa label.
- Tes terkait sudah dijalankan dan hasilnya dicatat.
- Tidak ada bug kritis terbuka yang menghalangi alur utama; bug yang belum selesai didokumentasikan sebagai known issue.
- Dokumentasi dan kontribusi pada logbook diperbarui.
- Anggota tim yang bertanggung jawab dapat menjelaskan cara kerja fitur dan alasan desainnya.

**Catatan akhir:** PRD ini adalah draft kerja berbasis ide UMKM Sight dan arah PBL TI Semester 5. Validasi kebutuhan pengguna, hasil uji dataset, keputusan arsitektur, dan ketentuan dosen tetap menjadi dasar untuk memfinalkan implementasi.
