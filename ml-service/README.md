# ML Service — UMKM Sight

Pipeline peramalan permintaan (time series forecasting) untuk memprediksi
kapan stok produk UMKM akan habis.

## Dataset yang dipakai

Pipeline ini memakai **dua file** di `data/raw/`:

| File | Peran | Isi |
|---|---|---|
| `retail_sales_ml_apl.csv` | **sumber penjualan** | 13.740 baris, 17 kolom, 20 produk, 1 toko, 2025-01-01 s/d 2026-11-15 |
| `retail_inventory_ml_apl.csv` | **sumber stok** | 40 baris, 18 kolom; 20 produk × 2 periode; 20 baris berstatus terkini |

Produknya adalah **sembako** (beras, telur, minyak goreng, gula, tepung,
mi instan, gas elpiji, dan sejenisnya) dari satu toko: `STR-001 Toko Berkah Jaya`.

Kolom yang dibaca dari file penjualan:

| Kolom | Dipakai sebagai |
|---|---|
| `Transaction Date` | tanggal transaksi |
| `Product No` | identitas produk (mis. `BRS-5KG-04`) |
| `Product Description` | nama produk (untuk tampilan) |
| `Qty Sold` | jumlah terjual |
| `Is Return` | penanda retur (1 = retur, dibuang) |

Kolom yang dibaca dari file inventori:

| Kolom | Dipakai sebagai |
|---|---|
| `Product No` | identitas produk |
| `Qty on hand` | jumlah stok |
| `End Date` | **filter**: hanya baris `9999-12-31` yang dianggap stok terkini |

### Kenapa stok diambil dari file terpisah

File penjualan **tidak** menyimpan stok. Stok ada di file inventori yang
bentuknya berbeda: setiap produk punya **dua baris periode**:

```
Start Date    End Date      Qty on hand
2025-01-01    2026-10-31    179      <- periode lama, sudah berakhir
2026-11-01    9999-12-31     29      <- periode BERLAKU, ini yang dipakai
```

Aturannya:

1. Ambil hanya baris dengan `End Date == "9999-12-31"`. Tanggal ini adalah
   penanda "stok masih berlaku". Kalau kedua periode ikut dijumlahkan,
   stoknya akan terlipat salah (179 + 29 = 208, padahal stok nyata 29).
2. Jumlahkan `Qty on hand` per produk. Dataset ini hanya punya 1 toko, tetapi
   penjumlahan lintas toko tetap benar untuk data multi-toko.
3. Stok negatif dijadikan 0 (pada dataset ini tidak ada yang negatif).

Hasilnya: **20 dari 20 produk** punya stok terkini di file. Rentang stoknya
0 s/d 342 unit, median 184 unit. Produk yang tidak ada di file inventori akan
memakai asumsi default 20 unit, dan hal itu ditulis di output supaya tidak
tersembunyi.

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
│   ├── download_dataset.py       # unduh dataset pembanding publik (opsional)
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
│   └── templates/                # template Excel siap isi
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

# jalankan semua 20 produk (±51 detik)
python scripts/run_pipeline.py

# ubah horizon / stok / lead time
python scripts/run_pipeline.py --horizon 14 --stock 50 --lead-time 5

# abaikan stok dari file inventori, pakai asumsi default 20 unit
python scripts/run_pipeline.py --ignore-data-inventory

# jalankan test (40 unit test, ±5 detik)
python -m pytest tests -q
```

Untuk melihat perilaku pipeline tanpa menyentuh data asli, pakai data
simulasi:

```bash
python scripts/run_pipeline.py --regenerate
```

### 4a. Berapa lama?

Diukur di mesin ini, 5 model lengkap dengan SARIMA:

| Tahap | Waktu |
|---|---|
| `--inspect` (13.740 baris) | ±5 detik |
| **Semua 20 produk** | **±51 detik** |
| 1 produk (684 hari riwayat) | ±2,5 detik |

Lama proses ditentukan oleh **jumlah produk × panjang riwayat**, karena
SARIMA dilatih terpisah untuk setiap produk (dua kali: sekali untuk evaluasi,
sekali untuk ramalan akhir).

## 5. Hasil nyata pada dataset ini (20 produk)

Ini hasil pengukuran, bukan perkiraan. Semua produk dijalankan dengan 5 model
lengkap.

| Hal | Hasil |
|---|---|
| Baris mentah diproses | 13.740 |
| Retur dibuang | 60 baris (0,44%) |
| Hari kosong diisi 0 | **0 hari** |
| Produk berhasil | 20 dari 20 |
| Waktu proses | 51 detik |
| Produk yang punya stok di file inventori | 20 dari 20 |
| Tanggal data terakhir | 2026-11-15 (hari ini) |

Model terbaik per produk: `naive` **11**, `sarima_trend` **7**,
`moving_average` **2**.

### 5a. Akurasi — target ≤20% tercapai

| Horizon | WAPE median | MAE median | MAPE median | Lolos ≤10% | Lolos ≤20% |
|---|---|---|---|---|---|
| **7 hari** | **12,8%** | 1,98 | 14,0% | 4/20 | **20/20** |
| 14 hari | 13,4% | 2,11 | 15,2% | 2/20 | 20/20 |
| 28 hari | 13,6% | 2,18 | 14,8% | 0/20 | 20/20 |

WAPE 7 hari terbaik **9,1%** (KPI-RTG-07), terburuk **19,6%** (DTR-800-14).
**Semua 20 produk lolos target ≤20%**, dan hasilnya stabil di ketiga horizon
(12,8% → 13,4% → 13,6%) — artinya model tidak hanya kebetulan bagus pada
satu minggu tertentu.

### 5b. Kenapa kali ini bisa bagus: permintaannya padat

Perbedaan utama dibanding dataset sebelumnya adalah **kepadatan data**:

| Pemeriksaan | Dataset ini | Dataset retail sebelumnya |
|---|---|---|
| Produk | 20 | 2.326 |
| Rata-rata penjualan/hari | median **21,2 unit** | median 0,77 unit |
| Proporsi hari tanpa penjualan | **0%** | 56% |
| Riwayat per produk | **684 hari penuh** | 277–328 hari |
| Autokorelasi lag-1 | 0,535 | 0,322 |
| Autokorelasi lag-7 (mingguan) | **0,749** | rendah |

Setiap produk laku **setiap hari** selama 684 hari, dengan rata-rata
10,5–31,6 unit/hari. Ada pola mingguan yang kuat dan konsisten:

| Hari | Sen | Sel | Rab | Kam | Jum | Sab | Min |
|---|---|---|---|---|---|---|---|
| Permintaan relatif | 0,79 | 0,93 | 0,92 | 0,99 | 1,06 | 1,12 | **1,18** |

Akhir pekan naik ±50% dibanding Senin. Pola inilah yang ditangkap SARIMA dan
`seasonal_naive`, sehingga error turun jauh.

### 5c. ⚠️ Peringatan penting: dataset ini dibangkitkan, bukan transaksi nyata

Saya memeriksa datanya, dan ada beberapa ciri yang **tidak mungkin muncul pada
transaksi ritel sungguhan**:

| Ciri | Nilai pada dataset ini | Yang seharusnya pada data nyata |
|---|---|---|
| Hari tanpa penjualan | **0%** dari 684 hari × 20 produk | selalu ada hari sepi |
| Pola mingguan antar produk | **identik** (selisih hanya 0,8%) | beda per produk |
| Jumlah retur | **tepat 3** untuk setiap produk | acak, tidak seragam |
| Harga per produk | **1 harga** selama 684 hari | berubah (promo, inflasi) |
| `Sales Type` | hanya `Full Price` | ada promo/markdown/clearance |
| Toko & kanal | 1 toko, 1 kanal | beberapa |
| Sebaran noise (`varians/rata-rata`) | 0,64–0,98 | > 1 (data cacah biasanya overdispersi) |
| Autokorelasi sisa noise | 0,54–0,75 | ≈ 0 (noise antar hari independen) |

Artinya dataset ini **dibangkitkan dengan rumus** kira-kira
`dasar × faktor_hari × noise_yang_dihaluskan`. Noise yang dihaluskan inilah
yang membuat error bisa di bawah 15%.

**Konsekuensi untuk laporan:** angka 12,8% adalah hasil yang **benar untuk
dataset ini**, tetapi **bukan** bukti akurasi di toko nyata. Yang dibuktikan
adalah: **pipeline berjalan benar dari ujung ke ujung** dan mampu menemukan
pola mingguan yang memang ada di data. Uji pada data nyata ada di bagian 5d.

### 5d. Bandingkan dengan data nyata

Untuk menguji pipeline pada data yang **benar-benar transaksi nyata**, kode
yang sama dijalankan pada *Store Item Demand Forecasting* (data publik Kaggle,
2 toko × 15 item, 2013–2017, 54.780 baris):

| Dataset | Sifat data | Volume | WAPE median 7 hari | Lolos ≤20% |
|---|---|---|---|---|
| Dataset ini (sembako) | dibangkitkan, sangat teratur | 21,2 unit/hari | **12,8%** | **20/20** |
| Store Item Demand | **nyata** (Kaggle), padat | 61,7 unit/hari | **20,6%** | 13/30 |
| Dataset retail sebelumnya | sangat jarang (56% hari nol) | 0,77 unit/hari | 100% | 0/82 |

Tiga baris itu menunjukkan pola yang konsisten:

- Data **nyata dan padat** → WAPE ±20%. Ini perkiraan yang paling realistis
  untuk toko sungguhan.
- Data **dibangkitkan** → lebih baik (12,8%) karena noise-nya dihaluskan.
- Data **sangat jarang** → 100%, karena sinyalnya terlalu tipis.

**Perkiraan jujur untuk presentasi:** pada data toko nyata, sasaran yang wajar
adalah **WAPE 15–25%**, bukan 12,8%. Angka 12,8% dipakai untuk menunjukkan
bahwa pipeline bekerja, bukan sebagai janji akurasi.

> Untuk mengulangi pengukuran Store Item Demand:
> `python scripts/download_dataset.py` lalu ukur dengan `evaluate_models()`.
> Unduhannya ±6 detik dan hasilnya sudah terverifikasi pada 2026-11-15.

## 6. Keluaran

`artifacts/pipeline_summary.json` — ringkasan semua produk. Field penting:

```json
{
  "data_source": "Data default: retail_sales_ml_apl.csv",
  "data_file": "data\\raw\\retail_sales_ml_apl.csv",
  "inventory_file": "data\\raw\\retail_inventory_ml_apl.csv",
  "inventory_products": 20,
  "inventory_open_end_date": "9999-12-31",
  "data_last_date": "2026-11-15",
  "data_age_days": 0
}
```

Per produk:

| File | Isi |
|---|---|
| `product_<id>_metrics.json` | hasil praproses, rentang latih/uji, skor semua model, `accuracy_by_horizon` (7/14/28 hari) |
| `product_<id>_forecast.json` | prediksi 7 hari + estimasi stok habis |
| `product_<id>_model.pkl` | model terbaik yang siap dipakai ulang |
| `product_<id>_report.png` | grafik aktual vs prediksi + proyeksi kumulatif |

Contoh `forecast.json` (nyata, produk `BRS-5KG-04`, beras premium 5 kg):

```json
{
  "product_id": "BRS-5KG-04",
  "model": "sarima_trend",
  "horizon_days": 7,
  "predictions": [
    { "date": "2026-11-16", "predicted_qty": 12.316 },
    { "date": "2026-11-17", "predicted_qty": 15.373 },
    { "date": "2026-11-18", "predicted_qty": 14.531 }
  ],
  "stockout": {
    "status": "will_run_out",
    "days_until_stockout": 3,
    "estimated_date": "2026-11-18",
    "current_stock": 29.0,
    "lead_time_days": 3,
    "should_alert": true,
    "message": "Stok diperkirakan habis dalam 3 hari (sekitar 18-11-2026)."
  }
}
```

Contoh ini bagus untuk demo: stok beras tinggal **29 unit**, permintaan
±12–15 unit/hari, jadi **habis 18 November** — dan karena lead time 3 hari,
`should_alert` bernilai `true`. Inilah bentuk data yang nanti dikirim backend
Laravel ke aplikasi Flutter.

### Status stockout pada 20 produk

| Status | Jumlah | Arti |
|---|---|---|
| `sufficient` | 13 | stok cukup selama horizon |
| `will_run_out` | 6 | stok habis dalam horizon |
| `out_of_stock` | 1 | stok sudah 0 |
| **Alert dikirim** | **6** | habis dalam ≤ lead time (3 hari) |

Produk yang perlu segera di-restock:

| Produk | Status | Stok | Habis |
|---|---|---|---|
| MKS-2L-01 (Minyak Goreng 2L) | `out_of_stock` | 0 | sekarang |
| DTR-800-14 (Deterjen 800g) | `will_run_out` | 16 | 2 hari |
| LPG-3KG-16 (Gas Elpiji 3 kg) | `will_run_out` | 22 | 2 hari |
| TLR-1KG-05 (Telur 1 kg) | `will_run_out` | 37 | 2 hari |
| BRS-5KG-04 (Beras 5 kg) | `will_run_out` | 29 | 3 hari |
| SKM-KLG-09 (Susu Kental Manis) | `will_run_out` | 48 | 3 hari |
| GLP-1KG-02 (Gula Pasir 1 kg) | `will_run_out` | 32 | 4 hari |

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

Pada dataset ini `naive` menang di **11 dari 20 produk**, `sarima_trend` di 7,
`moving_average` di 2. Itu wajar: pola mingguannya sangat stabil, sehingga
"besok = hari ini" sudah cukup dekat. Justru ini temuan yang layak
dipresentasikan — pada data yang sangat teratur, model sederhana sulit
dikalahkan, dan itu bukan kegagalan.

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

## 9. Batasan yang harus ditulis di laporan

- **Dataset ini dibangkitkan, bukan transaksi nyata** (bukti di bagian 5c).
  Angka 12,8% sah untuk dataset ini, tetapi belum membuktikan akurasi di toko
  sungguhan. Perkiraan realistis untuk data nyata: **WAPE 15–25%**.
- Hanya **1 toko, 1 kanal, 20 produk**. Belum diuji pada data multi-toko.
- Data berakhir **2026-11-15** (hari ini), jadi ramalan berlaku untuk
  16–22 November 2026. Pipeline memberi peringatan otomatis bila data
  terakhir lebih dari 30 hari yang lalu.
- `Sales Type` hanya berisi `Full Price` — **tidak ada promo** di dataset ini,
  sehingga efek promo terhadap lonjakan permintaan belum bisa diuji.
- Harga per produk konstan, jadi elastisitas harga tidak dimodelkan.
- Belum ada hyperparameter tuning (grid search) untuk SARIMA.
- Lead time masih asumsi 3 hari untuk semua produk; file inventori tidak
  menyediakan kolom lead time.
- Model `.pkl` berukuran besar (±10 MB per produk) karena menyimpan objek
  hasil SARIMA lengkap. Untuk 20 produk totalnya ±208 MB.

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

### Kandidat perbaikan, berurutan menurut bukti

1. **Uji dengan data toko sungguhan.** Ini yang paling menentukan. Selama
   datanya dibangkitkan, semua angka akurasi bersifat optimistis.
2. **Tambahkan data promo.** `Sales Type` sudah ada kolomnya; begitu ada baris
   `Promo`/`Markdown`, lonjakan permintaan bisa dipelajari sebagai fitur
   alih-alih dianggap noise.
3. **Tuning SARIMA** (grid search orde p,d,q) — sekarang masih memakai orde
   tetap.
4. **Kurangi ukuran model `.pkl`** dengan menyimpan parameter saja, bukan
   objek hasil lengkap.
