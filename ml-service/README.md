# ML Service — UMKM Sight

Pipeline peramalan permintaan (time series forecasting) untuk memprediksi
kapan stok produk UMKM akan habis.

## Dataset yang dipakai

Pipeline ini memakai **dua file** di `data/raw/`:

| File | Peran | Isi |
|---|---|---|
| `retail_sales_ml_apl.csv` | **sumber penjualan** | 125.751 baris, 2.326 produk, 40 toko, 2025-06-01 s/d 2026-04-24 |
| `retail_inventory_ml_apl.csv` | **sumber stok** | 284.755 baris riwayat stok; 22.701 baris berstatus terkini |

Kolom yang dibaca dari file penjualan:

| Kolom | Dipakai sebagai |
|---|---|
| `Transaction Date` | tanggal transaksi |
| `Product No` | identitas produk |
| `Product Description` | nama produk (untuk tampilan) |
| `Qty Sold` | jumlah terjual |
| `Is Return` | penanda retur (1 = retur, dibuang) |

Kolom yang dibaca dari file inventori:

| Kolom | Dipakai sebagai |
|---|---|
| `Product No` | identitas produk |
| `Qty on hand` | jumlah stok |
| `End Date` | **filter**: hanya baris `9999-12-31` yang dianggap stok terkini |

> **Penting soal asal data.** Kedua file ini bukan transaksi UMKM nyata.
> Semua angka di README ini adalah hasil pengukuran pada file tersebut, bukan
> janji akurasi untuk tokomu. Validasi sesungguhnya baru terjadi setelah data
> toko sendiri dijalankan.

### Kenapa stok diambil dari file terpisah

File penjualan **tidak** menyimpan stok. Stok ada di file inventori yang
bentuknya berbeda: satu produk muncul berkali-kali, sekali untuk setiap toko,
dan beberapa kali untuk periode yang berbeda.

Aturannya:

1. Ambil hanya baris dengan `End Date == "9999-12-31"`. Tanggal ini adalah
   penanda "stok masih berlaku". Tanggal lain adalah riwayat periode yang
   sudah berakhir — kalau ikut dijumlahkan, stoknya akan berlipat salah.
2. Jumlahkan `Qty on hand` per produk lintas toko. Ini konsisten dengan data
   penjualan yang juga dijumlahkan lintas toko untuk produk yang sama.
3. Stok negatif dijadikan 0. Di data ini ada 321 baris negatif — itu
   ketidakcocokan pencatatan, bukan stok minus yang nyata.

Hasilnya: **1.965 produk** punya stok terkini. Produk yang tidak ada di file
inventori memakai asumsi default 20 unit, dan hal itu ditulis di output
supaya tidak tersembunyi.

## 1. Pipeline itu apa?

Pipeline = **rangkaian langkah yang selalu dijalankan berurutan**, dari data
mentah sampai hasil yang bisa ditampilkan di aplikasi. Bayangkan seperti
proses pabrik: bahan mentah masuk, melewati beberapa stasiun, keluar produk.

Pipeline di project ini punya 6 stasiun:

```
[1] Data mentah        transaksi penjualan (satu baris = satu item terjual)
        |
[2] Praproses          buang retur (Qty Sold negatif ATAU Is Return = 1),
        |              jumlahkan per tanggal, isi hari kosong = 0,
        |              tolak kalau riwayat < 28 hari
[3] Split waktu        semua data kecuali 28 hari terakhir untuk latih,
        |              28 hari terakhir untuk uji (lihat bagian 8)
[4] Latih & nilai      5 model: naive, moving average, seasonal naive,
        |              SARIMA, SARIMA-trend; pilih MAE terkecil
[5] Ramalkan           model terbaik dilatih ulang pada SEMUA data, lalu
        |              memprediksi 7 hari ke depan
[6] Estimasi stok      aritmatika kumulatif: kapan prediksi permintaan
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

| Bagian | Dikerjakan oleh | File |
|---|---|---|
| Prediksi permintaan harian | Model ML | `models.py`, `evaluate.py` |
| Hitung kapan stok habis | Aritmatika | `stockout.py` |
| Tentukan perlu alert | Aturan bisnis (lead time) | `stockout.py` |

## 3. Struktur folder

```text
ml-service/
├── requirements.txt
├── README.md                     # dokumen ini
├── scripts/
│   ├── run_pipeline.py           # entry point CLI
│   ├── download_dataset.py       # unduh dataset contoh publik (opsional)
│   └── make_template.py          # pembuat template Excel kosong
├── src/umkm_ml/
│   ├── config.py                 # semua konstanta, asumsi & lokasi dataset
│   ├── synthetic_data.py         # pembuat data simulasi (untuk --regenerate)
│   ├── importer.py               # pembaca Excel/CSV + pembaca snapshot stok
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
```

Perintah utama. **Tanpa argumen, pipeline memakai dataset default**
(`retail_sales_ml_apl.csv` + `retail_inventory_ml_apl.csv`):

```bash
# cek dulu isi file (cepat, ±5 detik)
python scripts/run_pipeline.py --inspect

# uji 10 produk teratas (±18 detik)
python scripts/run_pipeline.py --limit 10

# jalankan 100 produk (±3 menit)
python scripts/run_pipeline.py --limit 100

# ubah horizon / stok / lead time
python scripts/run_pipeline.py --limit 10 --horizon 14 --stock 50 --lead-time 5

# abaikan stok dari file inventori, pakai asumsi default 20 unit
python scripts/run_pipeline.py --limit 10 --ignore-data-inventory

# jalankan test (40 unit test, ±5 detik)
python -m pytest tests -q
```

Untuk melihat perilaku pipeline tanpa menyentuh data asli, pakai data
simulasi:

```bash
python scripts/run_pipeline.py --regenerate --limit 1
```

### 4a. Berapa lama?

Diukur di mesin ini, 5 model lengkap dengan SARIMA:

| Tahap | Waktu |
|---|---|
| `--inspect` (125.751 baris) | ±5 detik |
| 10 produk | ±18 detik |
| 100 produk | ±3,2 menit |
| 1 produk | ±1,9 detik |
| **2.326 produk (semua)** | **±75 menit** |

Lama proses ditentukan oleh **jumlah produk**, bukan jumlah baris, karena
SARIMA dilatih terpisah untuk setiap produk (dua kali: sekali untuk evaluasi,
sekali untuk ramalan akhir).

**Saran urutan untuk data besar:** `--inspect` → `--limit 5` → `--limit 30`
→ baru semuanya. Jangan langsung menjalankan 2.326 produk.

## 5. Hasil nyata pada dataset ini (100 produk)

Ini hasil pengukuran, bukan perkiraan. 100 produk dengan transaksi terbanyak,
dijalankan dengan 5 model lengkap.

| Hal | Hasil |
|---|---|
| Baris mentah diproses | 27.160 |
| Retur dibuang | 1.531 baris |
| Hari kosong diisi 0 | 15.110 hari |
| Produk berhasil | 100 dari 100 |
| Waktu proses | 191,7 detik |
| Produk yang punya stok di file inventori | 93 dari 100 |

Model terbaik per produk: `naive` **49**, `sarima` **25**, `sarima_trend` **11**,
`seasonal_naive` **11**, `moving_average` **4**.

### 5a. Akurasi — dan kenapa angkanya buruk

| Horizon | WAPE median | MAE median | Lolos ≤20% | Lolos ≤50% |
|---|---|---|---|---|
| 7 hari | **100,0%** | 0,57 | 0/82 | 5/82 |
| 14 hari | 100,0% | 0,57 | 0/90 | 2/90 |
| 28 hari | 100,0% | 0,52 | 0/100 | 2/100 |

**48 dari 82 produk WAPE-nya persis 100%.** Angka yang seragam seperti itu
bukan kebetulan: artinya model memprediksi **0 unit untuk semua hari**, dan
memang begitu adanya — bukan bug.

Perhatikan anomali yang mencolok: **MAE median hanya 0,57 unit**, tetapi WAPE
100%. Keduanya benar sekaligus. MAE 0,57 berarti model meleset kurang dari
satu unit per hari — sangat baik. Tetapi kalau penjualan aktualnya juga hanya
0,5 unit per hari, maka `total_error / total_aktual = 1` alias 100%.

### 5b. Penyebabnya: permintaan terlalu jarang

Diukur pada 100 produk dengan transaksi terbanyak:

| Pemeriksaan | Hasil |
|---|---|
| Rata-rata penjualan per hari | median **0,77 unit** |
| Proporsi hari tanpa penjualan | median **56%** |
| Produk dengan rata-rata < 1 unit/hari | **66 dari 100** |
| Produk dengan rata-rata < 2 unit/hari | **93 dari 100** |
| Transaksi per produk (seluruh 2.326) | median **38 baris** |
| Produk dengan ≤ 50 transaksi | 1.527 dari 2.326 |

Kalau sebuah produk laku 0,77 unit per hari dan 56% harinya nol, maka
prediksi yang paling masuk akal secara statistik **memang 0**. Model tidak
sedang rusak; dia sedang mengatakan hal yang benar tentang data yang sangat
jarang.

### 5c. Yang berhasil: akurasi ikut volume

Ini temuan paling berguna dari dataset ini. Saya agregasi penjualan ke level
**Product Subcategory** (51 unit), lalu ukur akurasi menurut volume:

| Volume | Jumlah unit | WAPE median |
|---|---|---|
| < 2 unit/hari | 22 | 100,0% |
| 2–5 unit/hari | 8 | 74,2% |
| 5–10 unit/hari | 7 | 50,4% |
| 10–20 unit/hari | 10 | **39,5%** |
| ≥ 20 unit/hari | 4 | **32,2%** |

Korelasi `log(volume)` vs WAPE = **−0,751**. Semakin ramai permintaannya,
semakin akurat ramalannya. Ini hubungan yang kuat dan masuk akal: produk yang
laku 1 unit/hari punya sinyal terlalu tipis untuk dipelajari.

Contoh unit terbaik (level subkategori):

| Unit | Rata-rata | WAPE 7 hari |
|---|---|---|
| Scholar Footwear Modern Legend Summit | 35,1 u/h | **25,0%** |
| Scholar Footwear Flight Classic Zephyr | 28,7 u/h | **27,1%** |
| Femme Footwear Court Casual Trident | 9,6 u/h | 30,1% |
| Scholar Footwear Court Casual Trident | 11,2 u/h | 31,7% |

Dari 51 subkategori: **2 lolos ≤30%**, **14 lolos ≤50%**, median 67,1%.
Kalau diambil 10 subkategori bervolume tertinggi, median WAPE-nya **37,9%**.

**Kesimpulan yang jujur: target ≤20% TIDAK tercapai pada dataset ini, bahkan
setelah agregasi.** Yang bisa diklaim hanya: pada unit bervolume tinggi,
error turun ke kisaran 25–40%.

### 5d. Bandingkan dengan data yang punya pola

Untuk menunjukkan bahwa masalahnya ada di data dan bukan di kode, kode yang
**sama persis** dijalankan pada *Store Item Demand Forecasting* (data publik
Kaggle, diambil 2 toko × 15 item, 2013–2017, 54.780 baris):

| Dataset | Volume | Autokorelasi lag-1 (median) | WAPE median 7 hari | Lolos ≤20% |
|---|---|---|---|---|
| Store Item Demand (punya pola) | **61,7 unit/hari** | **0,595** | **20,6%** | **13/30** |
| Dataset retail sekarang | 0,77 unit/hari | 0,322 | 100% | 0/82 |
| Kontrol negatif: acak Poisson, volume disamakan dengan retail | 0,78 unit/hari | 0,007 | 85,7% | 0/97 |

Tiga baris itu dibaca begini:

- Pada data yang **padat** (61,7 unit/hari), pipeline mencapai WAPE 20,6% dan
  13 dari 30 produk lolos target. Jadi kodenya bisa akurat — syaratnya
  permintaannya cukup padat.
- Pada dataset retail sekarang (0,77 unit/hari), hasilnya 100%.
- **Baris ketiga adalah bukti terpentingnya.** Saya buat deret **acak murni**
  (Poisson, tanpa pola apa pun) dengan volume dan panjang yang sama seperti
  data retail. Hasilnya WAPE median **85,7%**, dan 43 dari 97 deret acak itu
  juga persis 100%. Artinya: pada volume 0,77 unit/hari, deret yang **tidak
  mengandung pola apa pun** pun menghasilkan error di kisaran yang sama
  dengan data asli.

Kesimpulannya bukan "modelnya bagus" atau "modelnya rusak", melainkan:
**pada tingkat kepadatan ini, akurasi sudah dibatasi oleh datanya, bukan oleh
algoritmanya.** Inilah alasan agregasi (bagian 5c) adalah jalan keluar yang
masuk akal — bukan mengganti model dengan yang lebih rumit.

> Angka di tabel ini diukur ulang pada 2026-11-15 memakai
> `scripts/download_dataset.py` (unduh 6,1 detik) + `evaluate_models()`,
> sehingga bisa direproduksi sendiri.

## 6. Keluaran

`artifacts/pipeline_summary.json` — ringkasan semua produk. Field penting:

```json
{
  "data_source": "Data default: retail_sales_ml_apl.csv",
  "data_file": "data\\raw\\retail_sales_ml_apl.csv",
  "inventory_file": "data\\raw\\retail_inventory_ml_apl.csv",
  "inventory_products": 1965,
  "inventory_open_end_date": "9999-12-31",
  "data_last_date": "2026-04-24",
  "data_age_days": 205,
  "assumptions": {
    "current_stock_source": "dari retail_inventory_ml_apl.csv (End Date 9999-12-31, Qty on hand dijumlahkan per produk); 93/100 produk punya stok di file, sisanya asumsi 20 unit"
  }
}
```

Per produk:

| File | Isi |
|---|---|
| `product_<id>_metrics.json` | hasil praproses, rentang latih/uji, skor semua model, `accuracy_by_horizon` (7/14/28 hari) |
| `product_<id>_forecast.json` | prediksi 7 hari + estimasi stok habis |
| `product_<id>_model.pkl` | model terbaik yang siap dipakai ulang |
| `product_<id>_report.png` | grafik aktual vs prediksi + proyeksi kumulatif |

Contoh `forecast.json` (nyata, produk `PROD-100805`, stok 177 unit):

```json
{
  "product_id": "PROD-100805",
  "model": "sarima_trend",
  "horizon_days": 7,
  "predictions": [
    { "date": "2026-04-25", "predicted_qty": 14.28 },
    { "date": "2026-04-26", "predicted_qty": 4.04 }
  ],
  "stockout": {
    "status": "sufficient",
    "current_stock": 177.0,
    "lead_time_days": 3,
    "should_alert": false,
    "message": "Stok diperkirakan cukup selama horizon prediksi (7 hari ke depan)."
  }
}
```

Bentuk inilah yang nanti dikirim backend Laravel ke aplikasi Flutter.

### Status stockout pada 100 produk

| Status | Jumlah | Arti |
|---|---|---|
| `sufficient` | 89 | stok cukup selama horizon |
| `will_run_out` | 10 | stok habis dalam horizon |
| `out_of_stock` | 1 | stok sudah 0 |
| **Alert dikirim** | **6** | habis dalam ≤ lead time (3 hari) |

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

Pada dataset ini hal itu benar-benar terjadi: `naive` menang di **49 dari 100
produk**. Itu bukan kelemahan pipeline — justru bukti baseline dipakai
sebagaimana mestinya, dan bahwa permintaan produk-produk ini memang terlalu
datar untuk dimodelkan lebih rumit.

## 8. Aturan evaluasi yang tidak boleh dilanggar

1. **Split berbasis waktu**, bukan acak. Data uji harus selalu lebih baru
   dari data latih.
2. **Data uji = 28 hari terakhir, bukan 20% data.** Aplikasi hanya meramal
   7 hari. Menguji model pada 365 hari ke depan membuat hasil terlihat jauh
   lebih buruk daripada tugas sebenarnya, lalu kesimpulannya salah.
3. **MAPE tidak dihitung pada hari bernilai 0** (pembagian nol). Lihat
   `zero_ratio` untuk tahu seberapa banyak hari nol.
4. **MAPE saja menyesatkan pada data ritel.** Hari dengan penjualan 1 buah
   membuat MAPE meledak walau selisihnya 1 buah. Karena itu WAPE juga
   dilaporkan: total kesalahan dibagi total penjualan.
5. **Jangan menampilkan prediksi saat data tidak cukup.** Di bawah 28 hari
   pipeline mengembalikan status `insufficient_data`.
6. **Jangan mengarang tanggal habis.** Kalau permintaan kumulatif belum
   melewati stok sampai akhir horizon, statusnya `sufficient`.
7. **Perhatikan tanggal data terakhir.** Ramalan selalu berlaku setelah
   tanggal itu. Data yang berakhir bertahun lalu tidak bisa dipakai untuk
   memprediksi stok hari ini.

> **Catatan WAPE 100%.** Nilai ini muncul saat model memprediksi 0 sementara
> aktualnya juga sangat kecil. Jangan menyimpulkan "model gagal" dari angka
> ini tanpa melihat MAE dan volume permintaannya. Lihat bagian 5a dan 5c.

## 9. Batasan yang harus ditulis di laporan

- Data berakhir **2026-04-24**, jadi semua ramalan berlaku untuk periode
  setelah tanggal itu — bukan kondisi hari ini. Pipeline memberi peringatan
  otomatis bila data terakhir lebih dari 30 hari yang lalu.
- Target akurasi ≤20% **tidak tercapai** pada dataset ini: WAPE median 100%
  di level produk, 67,1% di level subkategori. Penyebab utamanya kepadatan
  data (median 0,77 unit/hari, 56% hari nol), bukan bug. Bukti paling kuat
  ada di bagian 5d: deret **acak murni** dengan volume sama pun menghasilkan
  WAPE median 85,7%, jadi batas akurasi di sini ditentukan volume data.
- Pada unit bervolume tinggi (≥20 unit/hari), error turun ke kisaran
  25–40%. Belum ada satu pun unit yang mencapai ≤20% di dataset ini.
- **Belum ada agregasi resmi di pipeline.** Analisis subkategori di bagian
  5c dilakukan di luar pipeline. Pipeline masih memproses per produk.
- Kedua dataset **bukan transaksi UMKM nyata**. Validasi sesungguhnya baru
  terjadi setelah data toko sendiri dijalankan.
- Model belum mempertimbangkan `Sales Type` (Promo, Markdown, Clearance)
  walaupun kolom itu tersedia dan 23.651 baris berstatus Promo. Efek promo
  terhadap lonjakan permintaan belum ditangkap.
- Belum ada hyperparameter tuning (grid search) untuk SARIMA.
- Lead time masih asumsi 3 hari untuk semua produk; file inventori tidak
  menyediakan kolom lead time.

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

### Kandidat perbaikan akurasi, berurutan menurut bukti

1. **Agregasi ke level subkategori.** Bagian 5c menunjukkan ini menaikkan
   akurasi paling banyak (100% → 67,1% median, dan 25–40% pada unit
   bervolume tinggi). Ini juga lebih masuk akal untuk keputusan restock:
   pemilik toko berpikir per jenis barang, bukan per SKU yang laku 0,7 buah
   sehari.
2. **Pakai kolom `Sales Type`.** 23.651 baris berstatus Promo. Lonjakan saat
   promo saat ini dianggap noise padahal bisa dipelajari sebagai fitur.
3. **Saring produk yang layak diramal.** Tolak produk dengan riwayat terlalu
   jarang, dan tampilkan status "data belum cukup berpola" alih-alih angka
   0 yang menyesatkan.
4. **Hyperparameter tuning SARIMA** setelah tiga langkah di atas.
