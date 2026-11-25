# Backlog — UMKM Sight

Daftar pekerjaan yang **belum selesai**, disusun agar bisa dibagi langsung ke
anggota tim. Setiap tugas punya ID, pemilik, kriteria selesai, dan perkiraan
ukuran. Gunakan ID-nya di judul commit, misalnya:
`feat(api): endpoint /predict [BE-02]`.

Terakhir diperbarui: **2026-11-15**

---

## 1. Kondisi repo saat ini (terverifikasi)

| Komponen | Status | Bukti |
|---|---|---|
| `ml-service/` | ✅ **Paling matang** | 10 modul, 1.841 baris, 40 unit test lolos, pipeline 20/20 produk |
| `backend/` | ❌ **Kosong** | hanya berisi `.gitkeep` — Laravel belum ada |
| `mobile/` | ⚠️ Baru auth | login/register masih `useMock = true`; dashboard masih placeholder |
| `qa/` | ❌ Kosong | `bug-log/`, `test-cases/`, `test-plan/` hanya `.gitkeep` |
| `.github/` | ❌ Kosong | tidak ada CI/CD |

**Kesimpulan:** bagian ML bukan lagi hambatan. Yang menghambat demo
end-to-end adalah **backend kosong** dan **mobile yang belum tersambung**.

---

## 2. Tiga celah teknis di ML yang harus ditutup

Ini bukan "model kurang pintar" — modelnya sudah jalan. Ini soal kesiapan
produksi.

### Celah 1 — Model `.pkl` ditulis tapi tidak pernah dibaca ulang

Seluruh kode hanya memakai `pickle.dump`. **Tidak ada `pickle.load`** dan tidak
ada fungsi `load_model()`. Akibatnya:

- 20 file `.pkl` = **208,1 MB** yang tidak pernah dipakai (write-only).
- API nanti harus **melatih ulang dari nol setiap request**.
- Terukur **±2,5 detik per produk** → 20 produk = **±51 detik**.
- PRD menargetkan **response time < 5 detik**. Ini akan gagal di demo.

### Celah 2 — Tidak ada prediction interval

`forecast.json` hanya berisi satu angka per hari. Untuk keputusan restock,
"stok cukup 7 hari **dengan keyakinan 80%**" jauh lebih berguna daripada satu
angka telanjang. `statsmodels` sudah menyediakannya gratis.

### Celah 3 — Tidak ada versi model

Artefak hanya berisi `product_id`, `best_model`, `models`, `preprocessing`,
`split`, `accuracy_by_horizon`. Tidak ada `trained_at`, `version`, atau hash
data — model tidak bisa diaudit atau di-rollback.

---

## 3. Arti prioritas

| Kode | Arti | Aturan |
|---|---|---|
| **P0** | Blocker | Tanpa ini demo end-to-end tidak jalan |
| **P1** | Penting | Menentukan kualitas & kejujuran laporan |
| **P2** | Pengembangan | Dikerjakan kalau P0/P1 selesai |

---

## 4. Tugas per pemilik

### Farrel Andika Chandra — ML Engineer & Arsitek Backend

Beban terberat. Tugas BE-01 s/d BE-04 **membuka jalan** bagi mobile dan QA,
jadi kerjakan lebih dulu.

| ID | Prioritas | Tugas | File | Kriteria selesai | Ukuran |
|---|---|---|---|---|---|
| **BE-01** | P0 | REST API FastAPI | `ml-service/api/main.py`, `api/schemas.py` | `GET /health` balas 200; `POST /predict` balas < 2 detik; input tidak valid → 400 dengan pesan jelas | ±200 baris |
| **BE-02** | P0 | Muat model tanpa latih ulang | `src/umkm_ml/registry.py` | `load_model(product_id)` mengembalikan model siap pakai; `/predict` tidak memanggil `evaluate_models` | ±80 baris |
| **BE-03** | P0 | Perkecil artefak model | ubah `pipeline.py` | simpan parameter saja; 1 model < 1 MB; total 20 produk < 20 MB | ±40 baris |
| **BE-04** | P0 | **Backend Laravel** | `backend/` | migrasi `users`, `stores`, `products`, `transactions`, `predictions`; auth Sanctum; `POST /api/predict` meneruskan ke ML service | besar |
| **BE-05** | P1 | Versi model | `pipeline.py` | `metrics.json` punya `trained_at`, `data_last_date`, `pipeline_version` | ±20 baris |
| **BE-06** | P1 | Prediction interval | `models.py`, `pipeline.py` | `forecast.json` punya `lower_80`, `upper_80` per hari | ±60 baris |
| **BE-07** | P1 | `Dockerfile` + `docker-compose.yml` | `ml-service/` | `docker compose up` → API siap di :8000 tanpa setup Python manual | ±60 baris |
| **BE-08** | P2 | Endpoint `POST /train` | `api/main.py` | retrain dari backend tanpa buka terminal | ±80 baris |

Catatan untuk BE-01: fungsi yang dipanggil sudah ada dan stabil —
`pipeline.run_product(raw, product_id, horizon, current_stock, lead_time_days)`.
**Jangan duplikasi logika peramalan di dalam API**; panggil fungsi itu saja
supaya tetap satu sumber kebenaran.

Kontrak yang disarankan:

```text
POST /predict
  body : { product_id, history[], horizon_days, current_stock, lead_time_days }
  reply: { predictions[], model, metrics, stockout }

GET  /products
  reply: [ { product_id, product_name, status, current_stock } ]

GET  /health
  reply: { status: "ok", version: "0.1.0" }
```

---

### Abdul Muid — Pengembang Utama Mobile Flutter

Bisa mulai **sekarang** tanpa menunggu backend, karena bentuk JSON-nya sudah
final dan tersedia di `ml-service/artifacts/product_*_forecast.json`.

| ID | Prioritas | Tugas | File | Kriteria selesai | Ukuran |
|---|---|---|---|---|---|
| **MB-01** | P0 | Dasbor stok (ganti placeholder) | `lib/features/dashboard/` | daftar produk + badge status (`sufficient` / `will_run_out` / `out_of_stock`) | ±300 baris |
| **MB-02** | P0 | Detail prediksi per produk | `lib/features/prediction/` | grafik 7 hari, tanggal stok habis, sisa stok, tombol "Catat Restock" | ±350 baris |
| **MB-03** | P0 | Sambung ke API asli | `core/constants/api_constants.dart` | `USE_MOCK=false` → login/register benar-benar hit Laravel | ±50 baris |
| **MB-04** | P1 | Halaman catat transaksi | `lib/features/transaction/` | form qty + tanggal, kirim ke backend, muncul di riwayat | ±300 baris |
| **MB-05** | P1 | Push notification FCM | `lib/features/notification/` | notifikasi muncul saat `should_alert == true` | ±200 baris |
| **MB-06** | P2 | Halaman konfirmasi restock | `lib/features/restock/` | sesuai activity diagram `04-4-activity-konfirmasi-restock` | ±250 baris |

Field yang **sudah tersedia** dan siap dipakai (tidak perlu menunggu siapa pun):

```json
{
  "product_id": "BRS-5KG-04",
  "model": "sarima_trend",
  "predictions": [ { "date": "2026-11-16", "predicted_qty": 12.316 } ],
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

Cara mulai cepat: buat model Dart dari JSON di atas, isi dengan data contoh,
bangun UI-nya. Begitu BE-01 selesai, cukup ganti sumber data dari file ke HTTP.

---

### Muhammad Christiano Olyvian Barini — Ketua & QA

| ID | Prioritas | Tugas | Kriteria selesai |
|---|---|---|---|
| **QA-01** | P0 | Isi `qa/test-plan/` | rencana uji end-to-end: login → catat transaksi → lihat prediksi → restock → notifikasi |
| **QA-02** | P0 | Isi `qa/test-cases/` | minimal 20 kasus, **termasuk kasus gagal**: data kosong, produk tanpa riwayat, API mati, stok negatif, tanggal di masa depan |
| **QA-03** | P1 | Mulai `qa/bug-log/` | format: ID, tanggal, langkah reproduksi, dugaan penyebab, status |
| **QA-04** | P1 | Audit klaim akurasi | pastikan tidak ada dokumen yang menyebut 12,8% sebagai akurasi data nyata |
| **QA-05** | P2 | CI dasar di `.github/workflows/` | `pytest` otomatis jalan di setiap PR |

Kasus uji yang **wajib** ada, karena ini yang paling mungkin gagal:

| Skenario | Yang harus terjadi |
|---|---|
| Produk dengan riwayat < 28 hari | status `insufficient_data`, **bukan** angka karangan |
| Produk tidak ada di file inventori | pakai asumsi 20 unit, dan itu **ditulis** di output |
| API mati saat mobile memanggil | mobile tampilkan pesan error, bukan layar putih |
| Stok 0 | status `out_of_stock`, `should_alert = true` |
| Data terakhir > 30 hari lalu | muncul peringatan umur data |

---

### Abelas Solihin — Sekretaris & Dokumentator

| ID | Prioritas | Tugas | Kriteria selesai |
|---|---|---|---|
| **DOC-01** | P0 | Perbaiki `README.md` baris 41 | masih menyebut "UCI Online Retail (541.909 transaksi)" — tidak cocok dengan data yang dipakai (`retail_sales_ml_apl.csv`, 13.740 baris, 20 produk sembako) |
| **DOC-02** | P0 | Dokumentasi API | OpenAPI/Swagger dari FastAPI diekspor ke `docs/api/` untuk lampiran laporan |
| **DOC-03** | P0 | Bagian "Dataset & Batasan" di laporan | **wajib** menyatakan data dibangkitkan; bukti di `ml-service/README.md` bagian 5c. PRD baris 232 & 422 mewajibkan ini |
| **DOC-04** | P1 | Logbook mingguan | `docs/logbook/` terisi tiap minggu |
| **DOC-05** | P1 | Perbarui diagram UML | `docs/uml/` sesuaikan dengan endpoint & alur final |
| **DOC-06** | P2 | Catatan atribusi lisensi | PRD baris 319: atribusi dataset & library pihak ketiga |

---

## 5. Pemetaan ke milestone PRD

Mengacu tabel jadwal di `docs/prd/PRD.md` baris 368–376.

| Milestone PRD | Yang harus selesai |
|---|---|
| **CP-2** (Minggu 7–8) | BE-01, BE-02, MB-01, MB-02 — demo bisa menampilkan prediksi |
| **CP-3** (Minggu 11–12) | BE-03, BE-04, MB-03, MB-04, QA-01, QA-02 — alur utama tersambung |
| **CP-4** (Minggu 15–16) | BE-05..BE-07, MB-05, QA-03..QA-05, DOC-01..DOC-05 — siap demo live + APK |

**Urutan dependensi (jangan dibalik):**

```
BE-02 (load model)  →  BE-01 (API)  →  MB-03 (mobile ke API)
                          ↓
BE-03 (kecilkan pkl)   BE-04 (Laravel)  →  QA-01/QA-02 (uji end-to-end)
                          ↓
                      BE-06 (interval) → DOC-02 (dokumentasi API)
```

MB-01 dan MB-02 **tidak menunggu apa pun** — bisa dikerjakan paralel hari ini.

---

## 6. Satu tugas non-kode yang paling menentukan

| ID | Prioritas | Tugas | Kenapa |
|---|---|---|---|
| **DATA-01** | **P0** | Cari data toko nyata, minimal 1 UMKM mitra, 3–6 bulan transaksi | semua angka akurasi sekarang dari data sintetis, jadi belum membuktikan apa pun tentang toko sungguhan |

Ini bukan tugas coding, tapi nilainya paling besar. Kalau dapat data nyata
walaupun hanya 5 produk, kredibilitas laporan naik jauh lebih tinggi daripada
menambah fitur apa pun.

PRD baris 386 & 399 sudah mencatat ini sebagai risiko terbuka.

---

## 7. Definition of Done

Sebuah tugas dianggap selesai bila **semua** terpenuhi:

- [ ] Kode jalan tanpa error (`python -m pytest tests -q` tetap 40+ lolos)
- [ ] Ada test baru untuk logika baru
- [ ] `README.md` atau docstring diperbarui bila perilaku berubah
- [ ] Commit memakai ID tugas, mis. `feat(api): endpoint /predict [BE-01]`
- [ ] Sudah di-push ke branch `feat/...`
- [ ] Tidak ada file sementara (`_*.py`, `_*.txt`) yang ikut ter-commit

---

## 8. Catatan risiko

| Risiko | Dampak | Mitigasi |
|---|---|---|
| Response time API > 5 detik | gagal target PRD | BE-02 + BE-03 wajib sebelum demo |
| Data sintetis dianggap data nyata | kredibilitas laporan jatuh | DOC-03, dan label sudah ada di `ml-service/README.md` 5c |
| Integrasi terlambat | demo tidak jalan | kerjakan BE-01/BE-02 lebih dulu; MB-01/MB-02 paralel |
| `backend/` masih kosong padahal CP-2 dekat | blocker terbesar | BE-04 jangan ditunda sampai akhir |
| Model `.pkl` 208 MB masuk git | repo bengkak | sudah di-`.gitignore`; jangan pernah di-commit |
