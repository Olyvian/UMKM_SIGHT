# ML Service — UMKM Sight

Pipeline peramalan permintaan (time series forecasting) untuk memprediksi
kapan stok produk UMKM akan habis.

> **Catatan penting:** pipeline bisa memakai data simulasi
> (`src/umkm_ml/synthetic_data.py`) **atau** file sendiri (Excel/CSV).
> Ada tiga dataset uji di repo ini, dan **asalnya berbeda** — jangan
> tertukar saat menulis laporan:
>
> | Bagian | File | Asal data | Untuk apa |
> |---|---|---|---|
> | 5b | `dataset_umkm_sembako.csv` | publik (Favorita, dipetakan ulang) | contoh data ritel nyata yang berisik |
> | 5c | `store_item_demand.csv` | publik (Store Item Demand, unduhan) | **contoh terbaik**: ada pola yang bisa dipelajari |
> | 5d | `indian_FMCG_...csv` | publik, **acak murni** | hanya untuk menguji logika stok |
>
> Tidak satu pun dari ketiganya transaksi UMKM nyata. Angka di README ini
> adalah hasil pengukuran pada file tersebut, bukan janji akurasi untuk tokomu.

## 1. Pipeline itu apa?

Pipeline = **rangkaian langkah yang selalu dijalankan berurutan**, dari data
mentah sampai hasil yang bisa ditampilkan di aplikasi. Bayangkan seperti
proses pabrik: bahan mentah masuk, melewati beberapa stasiun, keluar produk.

Pipeline di project ini punya 6 stasiun:

```
[1] Data mentah        transaksi penjualan (satu baris = satu item terjual)
        |
[2] Praproses          buang retur, jumlahkan per tanggal, isi hari kosong = 0,
        |              tolak kalau riwayat < 28 hari
[3] Split waktu        semua data kecuali 28 hari terakhir untuk latih,
        |              28 hari terakhir untuk uji (lihat bagian 8)
[4] Latih & nilai      5 model: naive, moving average, seasonal naive,
        |              SARIMA, SARIMA-trend; pilih MAE terkecil
[5] Ramalkan           model terbaik dilatih ulang pada SEMUA data, lalu
        |              memprediksi 7 hari ke depan
[6] Estimasi stok       aritmatika kumulatif: kapan prediksi permintaan
        |              melewati stok saat ini  ->  tanggal stok habis
        v
   Artefak JSON + grafik PNG + model .pkl
```

Kenapa harus satu arah dan berurutan? Karena setiap stasiun bergantung pada
hasil stasiun sebelumnya. Kalau praproses salah (misal hari kosong dihapus,
bukan diisi nol), semua hasil setelahnya ikut salah — dan itu tidak akan
kelihatan dari angka metriknya.

## 2. Yang sebenarnya dikerjakan ML di sini

Model **hanya** menjawab satu pertanyaan:

> "Untuk produk ini, kira-kira besok laku berapa buah per hari?"

Bukan memprediksi stok, bukan memutuskan restock. Perhitungan stok habis
adalah **aritmatika biasa** yang memakai angka prediksi tadi (lihat
`src/umkm_ml/stockout.py`). Ini pemisahan yang penting dan sering
ditanyakan saat presentasi.

## 3. Struktur folder

```text
ml-service/
├── requirements.txt
├── README.md                     # dokumen ini
├── scripts/
│   ├── run_pipeline.py           # entry point CLI
│   ├── download_dataset.py       # unduh dataset contoh yang layak
│   └── make_template.py          # pembuat template Excel kosong
├── src/umkm_ml/
│   ├── config.py                 # semua konstanta & asumsi
│   ├── synthetic_data.py         # pembuat data simulasi
│   ├── importer.py               # pembaca Excel/CSV milik pengguna
│   ├── preprocessing.py          # transaksi -> deret harian tanpa lubang
│   ├── metrics.py                # MAE, RMSE, MAPE, WAPE
│   ├── models.py                 # 5 model (lihat bagian 7)
│   ├── evaluate.py               # split waktu + bandingkan model
│   ├── stockout.py               # estimasi stok habis (bukan ML)
│   └── pipeline.py               # orkestrasi semuanya
├── tests/                        # 40 unit test untuk pipeline ini
├── notebooks/
│   └── 01_eksplorasi.ipynb       # eksplorasi data & metrik
├── data/
│   ├── raw/                      # data mentah (diabaikan git)
│   ├── templates/                # template Excel siap isi
│   └── processed/                # data siap pakai
└── artifacts/                    # hasil pipeline (diabaikan git)
```

## 4. Cara menjalankan

```bash
cd ml-service

# (opsional) buat virtual environment
python -m venv venv
venv\Scripts\activate          # Windows
# source venv/bin/activate     # Linux/macOS

python -m pip install -r requirements.txt

# jalankan pipeline dengan data simulasi
python scripts/run_pipeline.py --regenerate

# ubah horizon / stok / lead time
python scripts/run_pipeline.py --horizon 14 --stock 50 --lead-time 5

# uji model untuk horizon lain (default 28 hari terakhir)
python scripts/run_pipeline.py --eval-horizon 7

# jalankan test
python -m pytest tests -q
```

### 4a. Dataset contoh yang bisa diunduh

Kalau belum punya data sendiri dan ingin melihat pipeline bekerja pada data
yang **punya pola nyata** (bukan simulasi):

```bash
python scripts/download_dataset.py          # 2 toko x 15 produk
python scripts/download_dataset.py --stores 3 --items 20
```

Script ini mengunduh *Store Item Demand Forecasting* (10 toko × 50 item,
5 tahun), mengambil sebagian, lalu menyimpannya sebagai
`data/raw/store_item_demand.csv` dalam format baku pipeline. Hasilnya
langsung bisa dijalankan:

```bash
python scripts/run_pipeline.py --data "data/raw/store_item_demand.csv"
```

## 5. Cara memasukkan data Excel kamu sendiri

Ada tiga langkah. Jangan langsung percaya angka sebelum langkah 2 selesai.

**Langkah 1 — Isi template.** Buat file template kosong, lalu buka di Excel:

```bash
python scripts/make_template.py
```

File muncul di `data/templates/template_transaksi.xlsx`. Ada 3 sheet:

| Sheet | Isi |
|---|---|
| `Petunjuk` | cara pengisian (tidak dibaca pipeline) |
| `Transaksi` | tempat kamu mengisi data asli |
| `Contoh 60 Hari` | contoh data terisi, untuk uji coba cepat |

Kolom yang wajib ada di sheet `Transaksi`:

| Kolom | Contoh | Keterangan |
|---|---|---|
| `Tanggal` | `2026-10-01` | tanggal transaksi, format `YYYY-MM-DD` |
| `Produk` | `Kopi Sachet` | nama atau kode produk (boleh diulang) |
| `Jumlah Terjual` | `5` | jumlah laku hari itu (angka) |

Kolom **opsional** (kalau ada, dipakai untuk perhitungan stok):

| Kolom | Contoh | Keterangan |
|---|---|---|
| `Stok` / `Stock_On_Hand` | `120` | stok saat ini; menggantikan asumsi 20 unit |
| `Lead_Time_Days` | `7` | lama pengadaan; menggantikan asumsi 3 hari |
| `Reorder_Level` | `30` | titik reorder (belum dipakai di perhitungan, hanya dibaca) |

Kalau kolom stok tidak ada, pipeline memakai asumsi default dan
menuliskannya di output (`stok awal asumsi 20 unit`). Kalau ada, output
akan menulis `stok awal dari data (kolom stock_on_hand)`. Untuk memaksa
asumsi default walaupun kolomnya ada, pakai `--ignore-data-inventory`.

Nama kolom boleh berbahasa Indonesia atau Inggris. Pipeline mengenali
`Tanggal`/`Date`, `Jumlah`/`Qty`/`Quantity`, `Produk`/`Product`/`SKU`, dan
beberapa variasi lain (lihat `COLUMN_ALIASES` di `src/umkm_ml/importer.py`).
Bentuk tabel lebar (tanggal di kolom pertama, nama produk jadi judul kolom)
juga otomatis dikenali.

**Langkah 2 — Cek dulu isinya.** Selalu jalankan ini sebelum memproses,
supaya kamu tahu file benar-benar terbaca dan kolomnya cocok:

```bash
python scripts/run_pipeline.py --data "data/raw/data_anda.xlsx" --inspect
```

Outputnya menunjukkan sheet yang dipakai, jumlah baris, ringkasan tiap
produk (tanggal awal/akhir, total qty), dan 5 baris pertama. Kalau di sini
sudah salah, jangan lanjut.

**Langkah 3 — Jalankan pipeline:**

```bash
python scripts/run_pipeline.py --data "data/raw/data_anda.xlsx"

# kalau file punya banyak sheet dan kamu mau pilih satu:
python scripts/run_pipeline.py --data "data/raw/data_anda.xlsx" --sheet "Transaksi"

# hanya satu produk tertentu (berdasarkan nama atau ID):
python scripts/run_pipeline.py --data "data/raw/data_anda.xlsx" --product "Kopi Sachet"

# abaikan kolom stok/lead time di data, pakai asumsi default:
python scripts/run_pipeline.py --data "data/raw/data_anda.xlsx" --ignore-data-inventory
```

Aturan data yang harus dipenuhi:

- **Minimal 28 hari riwayat per produk.** Di bawah itu pipeline menjawab
  `insufficient_data` — sengaja tidak mengarang prediksi.
- Hari tanpa penjualan **jangan dihapus**; kosongkan saja, pipeline mengisi 0.
- Retur/pembatalan tulis sebagai angka **negatif**; pipeline membuangnya.
- Urutan baris bebas; pipeline mengurutkan sendiri.

> **Penting soal angka MAE.** MAE 2.79 yang disebut sebelumnya berasal dari
> **data simulasi**, bukan dari file Excel kamu. Setelah menjalankan langkah
> di atas dengan data sendiri, angka MAE akan berbeda — itulah angka yang
> benar-benar mewakili tokomu. Jangan pakai angka dari README ini untuk
> laporan tanpa menjalankan datamu sendiri.

### 5a. Kalau datamu besar (puluhan ribu baris)

File 70.000 baris **tidak masalah** — pandas menanganinya dengan ringan.
Yang menentukan lama proses bukan jumlah baris, tapi **jumlah produk**,
karena SARIMA dilatih terpisah untuk setiap produk (dua kali: sekali untuk
evaluasi, sekali untuk ramalan akhir).

Hasil pengukuran nyata di mesin ini (file uji 125.000 baris, 120 produk,
masing-masing punya riwayat 2 tahun):

| Tahap | Waktu |
|---|---|
| Membaca file `.xlsx` 125.000 baris | ± 12 detik |
| Proses 1 produk (riwayat 730 hari), dengan SARIMA | ± 2,6 detik |
| Proses 1 produk, `--no-sarima` | ± 0,4 detik |
| 120 produk lengkap, dengan SARIMA | ± 5–6 menit |
| 120 produk lengkap, `--no-sarima` | ± 1 menit |

Urutan yang disarankan untuk data besar:

```bash
# 1. Taruh file di data/raw/ (folder ini diabaikan git, jadi tidak ter-commit)
#    Contoh: ml-service/data/raw/penjualan_toko.xlsx

# 2. Cek isinya. Ini cepat (± 10 detik) dan menunjukkan jumlah produk.
python scripts/run_pipeline.py --data "data/raw/penjualan_toko.xlsx" --inspect

# 3. Uji 5 produk terbesar dulu
python scripts/run_pipeline.py --data "data/raw/penjualan_toko.xlsx" --limit 5

# 4. Kalau hasilnya masuk akal, jalankan semuanya
python scripts/run_pipeline.py --data "data/raw/penjualan_toko.xlsx"

# Opsi cepat kalau tidak sabar menunggu SARIMA:
python scripts/run_pipeline.py --data "data/raw/penjualan_toko.xlsx" --no-sarima
```

Saat dijalankan, pipeline mencetak kemajuan per produk:

```text
[1/120] memproses produk: PRD-089
[2/120] memproses produk: PRD-056
```

**Yang harus diwaspadai:** kalau `--inspect` melaporkan jumlah produk yang
tidak masuk akal (mis. 70.000 produk untuk 70.000 baris), berarti kolom
produk salah terbaca — kemungkinan ada kolom seperti nomor transaksi yang
dikira nama produk. Perbaiki dulu nama kolomnya sebelum menjalankan model.
Pipeline akan memberi peringatan otomatis bila produknya lebih dari 50.

Tips lain: file `.csv` dibaca jauh lebih cepat daripada `.xlsx`. Kalau
datanya besar dan tidak butuh format Excel, simpan sebagai CSV.

### 5b. Hasil nyata pada `dataset_umkm_sembako.csv` (44 produk)

Ini hasil pipeline pada dataset yang ada di `data/raw/`. Bukan simulasi.

| Hal | Hasil |
|---|---|
| Baris terbaca | 73.251 |
| Produk | 44 (semua berhasil diproses) |
| Rentang data | 2013-01-02 s/d 2017-08-15 |
| Waktu proses (5 model, semua produk) | ± 4,5 menit |
| Waktu proses (`--no-sarima`) | ± 1 menit |

Model terbaik per produk: `sarima_trend` 15 produk, `moving_average` 10,
`sarima` 7, `naive` 7, `seasonal_naive` 5.

Akurasi model terbaik, dipotong menurut horizon (median 44 produk):

| Horizon | WAPE median | MAPE median | WAPE ≤ 20% | WAPE ≤ 30% | WAPE ≤ 50% |
|---|---|---|---|---|---|
| 7 hari | **47,3%** | 48,0% | 1/44 | 7/44 | 22/44 |
| 14 hari | 51,3% | 52,4% | 0/44 | 6/44 | 20/44 |
| 28 hari | 53,0% | 61,6% | 0/44 | 3/44 | 20/44 |

Produk terbaik pada 7 hari mencapai WAPE 15,6%; terburuk 400% (penjualan
sangat kecil di periode uji sehingga selisih beberapa unit saja sudah
menjadi error raksasa).

**Temuan jujur: target akurasi ≤ 20% TIDAK tercapai pada dataset ini.**
Hanya 1 dari 44 produk yang di bawah WAPE 20%, dan itu pun pada horizon
7 hari.

> **Catatan metode.** Sebelumnya README ini melaporkan WAPE median 59,2%
> karena model diuji pada 337 hari terakhir (20% data). Setelah evaluasi
> diperbaiki ke 28 hari — sesuai kebutuhan aplikasi yang hanya meramal
> 7 hari — angkanya membaik menjadi 47,3% pada horizon 7 hari. Perbaikan
> ini bukan "membuat angka bagus", tetapi mengukur tugas yang benar.

Kenapa? Bukan karena kodenya salah, tapi karena sifat datanya:

1. **Penjualan harian sangat berisik.** Contoh PRD-028: 5, lalu 80, lalu 9
   buah pada hari-hari berurutan tanpa pola promo. Tidak ada model yang bisa
   menebak lonjakan seperti itu dari riwayat.
2. **Ada tren turun kuat.** Rata-rata penjualan seluruh produk turun dari
   20,1 (2013) menjadi 9,8 (2017) per hari. Model tanpa diferensiasi terus
   meramal terlalu tinggi — itulah sebabnya `sarima_trend` ditambahkan.
3. **Banyak hari bernilai sangat kecil.** Pada produk seperti PRD-023
   (median 5 buah/hari), selisih 2 buah saja sudah menjadi error 40%.
   MAPE membesar-besarkan hal ini; WAPE lebih adil.

Yang **berhasil** dilakukan model: menangkap level permintaan dan pola
mingguan (Minggu tertinggi, Rabu terendah). Yang tidak tertangkap adalah
naik-turun harian yang tidak punya pola.

> Angka lama "PRD-001 rata-rata aktual 29,5 vs ramalan 30,8 per hari" dan
> "agregasi mingguan PRD-001 40% → 24,5%" diukur pada evaluasi 337 hari
> yang sudah dibuang. Angka itu tidak dipakai lagi sebagai bukti.

**Catatan penting:** data berakhir 2017-08-15, jadi ramalan berlaku untuk
16–22 Agustus 2017 — bukan hari ini. Pipeline sekarang memberi peringatan
otomatis bila data terakhir lebih dari 30 hari yang lalu.

**Catatan tentang asal data:** kolom `item_nbr_asal`, `sedang_promo`, dan
rentang 2013-01-02 s/d 2017-08-15 sangat mirip dataset publik *Corporación
Favorita Grocery Sales* (Kaggle), yang dipetakan ulang dengan nama produk
sembako Indonesia. Kalau ini untuk laporan, sebutkan sumber aslinya —
jangan diklaim sebagai transaksi UMKM nyata.

### 5c. Hasil pada `store_item_demand.csv` (30 produk, data contoh terbaik)

Ini dataset publik *Store Item Demand Forecasting* (10 toko × 50 item,
2013–2017), diambil 2 toko × 15 item oleh `scripts/download_dataset.py`.
Bukan data UMKM, tetapi **punya pola yang benar-benar bisa dipelajari**.
Buktinya diukur pada file ini:

| Pemeriksaan | Hasil | Artinya |
|---|---|---|
| Autokorelasi lag-1 | **0,575** | hari ini benar-benar dipengaruhi kemarin |
| Rata-rata per hari (Sen→Min) | 1.469 → 2.202 | pola mingguan kuat, naik menjelang akhir pekan |
| Rata-rata per tahun | 1.544 (2013) → 2.085 (2017) | tren naik nyata |
| Rata-rata per bulan | 1.258 (Jan) … 2.371 (Jul) | musim tahunan |

Bandingkan dengan file FMCG di bagian 5d (autokorelasi −0,008). Inilah
bedanya data yang bisa diramal dan yang tidak.

| Hal | Hasil |
|---|---|
| Baris | 54.780 |
| Produk | 30 (Toko1–Toko2 × Item 01–15) |
| Rentang data | 2013-01-01 s/d 2017-12-31 (1.826 hari) |
| Rata-rata | 61,7 unit/hari per produk |
| Waktu proses (5 model, 30 produk) | ± 178 detik |

Model terbaik per produk: `naive` 11 produk, `moving_average` 10,
`sarima_trend` 9.

Akurasi model terbaik, dipotong menurut horizon (median 30 produk):

| Horizon | WAPE median | WAPE ≤ 20% | WAPE ≤ 30% |
|---|---|---|---|
| 7 hari | **20,6%** | 13/30 | 27/30 |
| 14 hari | 20,1% | 15/30 | 27/30 |
| 28 hari | 19,8% | 16/30 | 29/30 |

Produk terburuk pada 7 hari masih 33–35% (Toko2-Item03, Toko2-Item01,
Toko1-Item10). Jadi kalimat yang jujur: **median mendekati target 20%,
tetapi belum semua produk lolos.**

Kenapa `naive` (besok = hari ini) menang di 11 dari 30 produk? Karena
permintaan item di dataset ini relatif stabil; kalau hari ini 60, besok
memang sekitar 60. Itu bukan kelemahan pipeline — justru bukti baseline
dipakai sebagaimana mestinya, dan SARIMA hanya dipilih saat benar-benar
lebih baik.

Bandingkan dengan `dataset_umkm_sembako.csv` (bagian 5b): WAPE median 47,3%
pada evaluasi dan horizon yang sama (7 hari). Perbedaan besar ini
menunjukkan bahwa **kualitas data menentukan batas akurasi**, bukan
kerumitan model.

### 5d. `indian_FMCG_retail_sales_customer_inventory.csv`: acak, jangan untuk akurasi

File ini 100.000 baris, 64 kombinasi `Category × Brand`, tahun 2024. Terlihat
lengkap (harga, stok, lead time, pelanggan), tetapi **penjualannya acak
murni**. Bukti yang sudah diukur:

| Pemeriksaan | Hasil | Artinya |
|---|---|---|
| Distribusi `Units` | 1–5 masing-masing ~20% | persis Uniform(1–5), seperti dadu |
| Autokorelasi lag-1 | −0,008 | hari ini tidak berhubungan dengan kemarin |
| Autokorelasi lag-7 | −0,003 | tidak ada pola mingguan |
| Rata-rata per hari (Sen–Min) | 12,92–13,14 | tidak ada beda |
| Korelasi dengan waktu | −0,011 | tidak ada tren |

Uji langsung ke pipeline: model terbaik hanya **0,99× lebih baik** daripada
sekadar menebak rata-rata data latih. Batas teoretisnya juga sudah dihitung:
MAD 5,48 unit/hari dibagi rata-rata 13,01 unit/hari = **WAPE minimum 42,1%**.
Model apa pun tidak bisa mengalahkan angka itu karena tidak ada pola untuk
dipelajari.

Jadi jangan pakai file ini untuk mengukur akurasi. **Yang berguna** adalah
tiga kolomnya: `Stock_On_Hand`, `Reorder_Level`, `Lead_Time_Days`. Pipeline
sekarang otomatis memakainya:

```bash
python scripts/run_pipeline.py --data "data/raw/indian_FMCG_retail_sales_customer_inventory.csv" --limit 3
```

Output akan menulis `Asumsi: stok awal dari data (kolom stock_on_hand),
lead time dari data (kolom lead_time_days)` — bukan lagi asumsi 20 unit /
3 hari. Ini cara menguji logika stok habis & alert dengan angka nyata,
tanpa berpura-pura ramalannya akurat.

## 6. Keluaran

`artifacts/pipeline_summary.json` — ringkasan semua produk.

Per produk:

| File | Isi |
|---|---|
| `product_<id>_metrics.json` | hasil praproses, rentang latih/uji, skor semua model, `accuracy_by_horizon` (7/14/28 hari) |
| `product_<id>_forecast.json` | prediksi 7 hari + estimasi stok habis |
| `product_<id>_model.pkl` | model terbaik yang siap dipakai ulang |
| `product_<id>_report.png` | grafik aktual vs prediksi + proyeksi kumulatif |

`accuracy_by_horizon` menjawab pertanyaan "seberapa akurat untuk 7 hari ke
depan?" secara langsung, karena model sudah memprediksi seluruh 28 hari uji
sekaligus; angkanya hanya dipotong per horizon, tanpa pelatihan ulang.

```json
"accuracy_by_horizon": {
  "7_hari":  { "mae": 3.8571, "rmse": 5.5934, "mape": 0.3431, "wape": 0.2143 },
  "14_hari": { "mae": 3.6429, "rmse": 4.7734, "mape": 0.2842, "wape": 0.2099 },
  "28_hari": { "mae": 4.1786, "rmse": 5.5324, "mape": 0.3725, "wape": 0.2505 }
}
```

(Contoh nyata: `Toko1-Item01` dari `store_item_demand.csv`.)

Contoh `forecast.json`:

```json
{
  "product_id": 1,
  "model": "moving_average",
  "horizon_days": 7,
  "predictions": [
    { "date": "2026-06-30", "predicted_qty": 7.571 }
  ],
  "stockout": {
    "status": "will_run_out",
    "days_until_stockout": 3,
    "estimated_date": "2026-07-02",
    "current_stock": 20,
    "lead_time_days": 3,
    "should_alert": true
  }
}
```

Bentuk inilah yang nanti dikirim backend Laravel ke aplikasi Flutter.

## 7. Model yang dipakai

| Model | Peran | Ide dasar |
|---|---|---|
| `naive` | pembanding | besok = hari ini |
| `moving_average` | **baseline wajib** | besok = rata-rata 7 hari terakhir |
| `seasonal_naive` | pembanding | besok = hari yang sama minggu lalu |
| `sarima` | kandidat utama | trend + musim mingguan (SARIMA(1,0,1)(0,0,1,7)) |
| `sarima_trend` | kandidat untuk data naik/turun | SARIMA(1,1,1)(0,1,1,7), bekerja pada perubahan bukan level |

Baseline ada bukan untuk dipamerkan, tetapi untuk **membuktikan** model
rumit layak dipakai. Kalau SARIMA kalah dari moving average, jawabannya
jujur: "model kompleks tidak memberi nilai tambah pada data ini".

Pada `dataset_umkm_sembako.csv`, ini benar-benar terjadi: `moving_average`
menang di 10 dari 44 produk, dan `naive` menang di 7 produk. Pada
`store_item_demand.csv` lebih ekstrem lagi: `naive` menang di 11 dari 30
produk. Itu hasil yang sah dan justru menunjukkan evaluasinya tidak diatur
supaya SARIMA menang.

## 8. Aturan evaluasi yang tidak boleh dilanggar

1. **Split berbasis waktu**, bukan acak. Data uji harus selalu lebih baru
   dari data latih.
2. **Data uji = 28 hari terakhir, bukan 20% data.** Aplikasi hanya meramal
   7 hari. Menguji model pada 365 hari ke depan membuat hasil terlihat jauh
   lebih buruk daripada tugas sebenarnya, lalu kesimpulannya salah. Ini
   pernah terjadi di project ini: pada PRD-002 `dataset_umkm_sembako.csv`,
   WAPE 7 hari 22,1% tetapi WAPE 337 hari 49,2%. Angka 28 hari dipakai agar
   tidak bergantung pada satu minggu yang kebetulan ramai/sepi; rincian
   7/14/28 hari dilaporkan terpisah di `accuracy_by_horizon`.
3. **MAPE tidak dihitung pada hari bernilai 0** (pembagian nol). Lihat
   `zero_ratio` untuk tahu seberapa banyak hari nol.
4. **MAPE saja menyesatkan pada data ritel.** Hari dengan penjualan 1 buah
   membuat MAPE meledak walau selisihnya 1 buah. Karena itu WAPE juga
   dilaporkan: total kesalahan dibagi total penjualan. Untuk data ini,
   pakai WAPE sebagai angka utama dan MAPE sebagai pembanding.
5. **Jangan menampilkan prediksi saat data tidak cukup.** Di bawah 28 hari
   pipeline mengembalikan status `insufficient_data`.
6. **Jangan mengarang tanggal habis.** Kalau permintaan kumulatif belum
   melewati stok sampai akhir horizon, statusnya `sufficient`.
7. **Perhatikan tanggal data terakhir.** Ramalan selalu berlaku setelah
   tanggal itu. Data yang berakhir bertahun lalu tidak bisa dipakai untuk
   memprediksi stok hari ini.

## 9. Batasan yang harus ditulis di laporan

- Data yang dipakai sebagai contoh (`dataset_umkm_sembako.csv`) berakhir
  2017-08-15, jadi semua ramalan berlaku untuk Agustus 2017 — bukan kondisi
  sekarang.
- Target akurasi ≤ 20% **tidak tercapai pada `dataset_umkm_sembako.csv`**:
  WAPE median 47,3% dan MAPE median 48,0% pada horizon 7 hari (hanya 1 dari
  44 produk di bawah WAPE 20%). Pada `store_item_demand.csv` hasilnya jauh
  lebih baik (WAPE median 20,6% pada 7 hari, 13 dari 30 produk lolos), tetapi
  tetap belum semua produk. Penyebab utamanya sifat data, bukan bug — dan itu
  dibuktikan dengan angka, bukan diklaim.
- Tidak ada satu pun dataset di folder ini yang merupakan transaksi UMKM
  nyata. Semua angka adalah hasil pada data publik/simulasi. Validasi
  sesungguhnya baru terjadi setelah data tokomu sendiri dijalankan.
- Model belum mempertimbangkan hari libur, promo (`sedang_promo` tersedia di
  data tetapi belum dipakai), atau tren musiman tahunan.
- Belum ada hyperparameter tuning (grid search) untuk SARIMA.
- Estimasi stok habis memakai stok awal & lead time manual, kecuali file
  menyediakan kolom `stock_on_hand` / `lead_time_days`. Stok awal 20 unit
  adalah contoh, bukan stok toko sebenarnya.

## 10. Langkah berikutnya

Pipeline ini menghasilkan JSON, tapi backend Laravel belum bisa memanggilnya.
Tahap selanjutnya adalah membungkus `umkm_ml` dengan REST API (FastAPI):

```text
POST /predict
  body : { product_id, history[], horizon_days, current_stock, lead_time_days }
  reply: { predictions[], model, metrics, stockout }
```

Rencananya file yang ditambahkan hanya `api/main.py` dan `api/schemas.py`
yang **memanggil fungsi di `src/umkm_ml/pipeline.py`**, sehingga logika
peramalan tetap satu sumber kebenaran dan tidak diduplikasi.


