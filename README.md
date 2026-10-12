# UMKM Sight
1. Use Case Diagram
2. ERD
3. Sequence Diagram (4 skenario)
4. Activity Diagram (2 alur)
5. Class Diagram

> Catatan: Mermaid tidak punya tipe "use case" dan "activity" bawaan, jadi keduanya dibuat dengan `flowchart` yang dibentuk menyerupai notasi UML.

---

## 1. Use Case Diagram

Aktor: **Pemilik UMKM** (primer), **Layanan ML (FastAPI)** dan **Penjadwal & FCM** (sekunder/sistem).

```mermaid
flowchart LR
    Owner{{"Pemilik UMKM"}}
    ML{{"Layanan ML<br/>(Python / FastAPI)"}}
    Sched{{"Penjadwal Otomatis<br/>& Firebase Cloud Messaging"}}

    subgraph SYS["Sistem UMKM Sight"]
        direction TB

        subgraph AUTH["Autentikasi & Profil"]
            UC01(["Registrasi Akun"])
            UC02(["Login"])
            UC03(["Logout"])
            UC04(["Kelola Profil Toko"])
        end

        subgraph INV["Inventaris & Transaksi"]
            UC05(["Kelola Produk (CRUD)"])
            UC06(["Perbarui Stok"])
            UC07(["Catat Transaksi Penjualan"])
            UC08(["Lihat Riwayat Mutasi Stok"])
            UC09(["Lihat Dasbor Stok"])
        end

        subgraph FC["Analitik & Peramalan"]
            UC10(["Lihat Prediksi Kebutuhan Stok<br/>(7 - 30 hari)"])
            UC11(["Lihat Grafik Tren Penjualan"])
            UC12(["Hasilkan Peramalan"])
        end

        subgraph NTF["Notifikasi & Restock"]
            UC13(["Terima Push Notification<br/>Peringatan Restock"])
            UC14(["Lihat Riwayat Alert"])
            UC15(["Konfirmasi Restock"])
            UC16(["Cek Ambang Batas Stok"])
            UC17(["Kirim Push Notification"])
        end
    end

    %% Aktor utama
    Owner --- UC01
    Owner --- UC02
    Owner --- UC03
    Owner --- UC04
    Owner --- UC05
    Owner --- UC06
    Owner --- UC07
    Owner --- UC08
    Owner --- UC09
    Owner --- UC10
    Owner --- UC11
    Owner --- UC13
    Owner --- UC14
    Owner --- UC15

    %% Aktor sistem
    UC12 --- ML
    UC16 --- Sched
    UC17 --- Sched

    %% Relasi include / extend
    UC10 -. "«include»" .-> UC12
    UC16 -. "«include»" .-> UC12
    UC17 -. "«include»" .-> UC16
    UC07 -. "«include»" .-> UC06
    UC15 -. "«include»" .-> UC06
    UC13 -. "«extend»" .-> UC17
    UC15 -. "«extend»" .-> UC13
    UC11 -. "«extend»" .-> UC09

    classDef actor fill:#fff7d6,stroke:#b58900,stroke-width:2px,color:#000;
    classDef usecase fill:#e8f1ff,stroke:#3b6fb6,color:#000;
    classDef sysuc fill:#eaf6ea,stroke:#4a8f4a,color:#000;
    class Owner,ML,Sched actor;
    class UC01,UC02,UC03,UC04,UC05,UC06,UC07,UC08,UC09,UC10,UC11,UC13,UC14,UC15 usecase;
    class UC12,UC16,UC17 sysuc;
```

**Keterangan relasi**
- Semua use case milik Pemilik UMKM (kecuali Registrasi & Login) mensyaratkan Login terlebih dahulu.
- `UC13 «extend» UC17`: notifikasi push hanya diterima jika sistem mengirimkannya (stok diprediksi menipis).
- `UC15 «extend» UC13`: konfirmasi restock opsional, dilakukan setelah pengguna menerima notifikasi.

---

## 2. ERD (Entity Relationship Diagram)

Rancangan basis data PostgreSQL. Satu akun = satu toko (sesuai batasan "single outlet" pada proposal).

```mermaid
erDiagram
    USERS ||--|| STORES : "memiliki"
    USERS ||--o{ DEVICE_TOKENS : "mendaftarkan"
    USERS ||--o{ NOTIFICATIONS : "menerima"
    STORES ||--o{ PRODUCTS : "mengelola"
    STORES ||--o{ TRANSACTIONS : "mencatat"
    TRANSACTIONS ||--|{ TRANSACTION_ITEMS : "terdiri dari"
    PRODUCTS ||--o{ TRANSACTION_ITEMS : "tercantum di"
    PRODUCTS ||--o{ STOCK_MOVEMENTS : "mengalami"
    TRANSACTIONS |o--o{ STOCK_MOVEMENTS : "menyebabkan"
    PRODUCTS ||--o{ FORECASTS : "diramalkan"
    FORECASTS ||--|{ FORECAST_DETAILS : "memiliki"
    PRODUCTS ||--o{ NOTIFICATIONS : "menjadi subjek"
    FORECASTS |o--o{ NOTIFICATIONS : "memicu"

    USERS {
        bigint id PK
        varchar name
        varchar email UK
        varchar password
        timestamp created_at
        timestamp updated_at
    }

    STORES {
        bigint id PK
        bigint user_id FK
        varchar store_name
        varchar address
        varchar phone
        timestamp created_at
        timestamp updated_at
    }

    DEVICE_TOKENS {
        bigint id PK
        bigint user_id FK
        varchar fcm_token UK
        varchar platform "android"
        timestamp last_active_at
    }

    PRODUCTS {
        bigint id PK
        bigint store_id FK
        varchar stock_code "kode produk (StockCode)"
        varchar name
        varchar unit
        decimal unit_price
        int current_stock
        int reorder_threshold "ambang batas kritis"
        boolean is_active
        timestamp created_at
        timestamp updated_at
    }

    TRANSACTIONS {
        bigint id PK
        bigint store_id FK
        varchar invoice_no UK
        varchar transaction_type "SALE atau PURCHASE"
        timestamp transaction_date "sumber data time series"
        decimal total_amount
        varchar note
    }

    TRANSACTION_ITEMS {
        bigint id PK
        bigint transaction_id FK
        bigint product_id FK
        int quantity
        decimal unit_price
        decimal subtotal
    }

    STOCK_MOVEMENTS {
        bigint id PK
        bigint product_id FK
        bigint transaction_id FK "nullable"
        varchar movement_type "IN, OUT, ADJUSTMENT"
        int quantity
        int stock_before
        int stock_after
        varchar note
        timestamp created_at
    }

    FORECASTS {
        bigint id PK
        bigint product_id FK
        varchar model_name "ARIMA, SARIMA, Prophet, LSTM"
        int horizon_days "7 sampai 30"
        decimal mape
        decimal rmse
        decimal mae
        int days_until_stockout
        timestamp generated_at
    }

    FORECAST_DETAILS {
        bigint id PK
        bigint forecast_id FK
        date forecast_date
        decimal predicted_qty
        decimal lower_bound
        decimal upper_bound
    }

    NOTIFICATIONS {
        bigint id PK
        bigint user_id FK
        bigint product_id FK
        bigint forecast_id FK "nullable"
        varchar type "RESTOCK_ALERT"
        varchar title
        varchar message
        boolean is_read
        timestamp sent_at
        timestamp read_at
    }
```

---

## 3. Sequence Diagram

### 3.1 Login & Registrasi Token Perangkat

```mermaid
sequenceDiagram
    autonumber
    actor U as Pemilik UMKM
    participant APP as Aplikasi Flutter
    participant LS as Penyimpanan Lokal<br/>(shared_preferences)
    participant API as Backend Laravel
    participant DB as PostgreSQL

    U->>APP: Input email & password, tekan Login
    APP->>API: POST /api/login (email, password)
    API->>DB: Cari user berdasarkan email
    DB-->>API: Data user
    alt Kredensial valid
        API-->>APP: 200 OK (token autentikasi, profil toko)
        APP->>LS: Simpan token sesi
        APP->>API: POST /api/device-tokens (fcm_token)
        API->>DB: Simpan / perbarui device token
        API-->>APP: 200 OK
        APP-->>U: Tampilkan Beranda & Dasbor Stok
    else Kredensial tidak valid
        API-->>APP: 401 Unauthorized
        APP-->>U: Tampilkan pesan error login
    end
```

### 3.2 Pencatatan Transaksi Penjualan

```mermaid
sequenceDiagram
    autonumber
    actor U as Pemilik UMKM
    participant APP as Aplikasi Flutter
    participant API as Backend Laravel
    participant DB as PostgreSQL
    participant CACHE as Cache Lokal (sqflite)

    U->>APP: Pilih produk, isi jumlah, simpan transaksi
    APP->>API: POST /api/transactions (items, tanggal)
    API->>DB: BEGIN TRANSACTION
    API->>DB: Cek stok tiap produk
    alt Stok mencukupi
        API->>DB: INSERT transactions & transaction_items
        API->>DB: UPDATE products.current_stock
        API->>DB: INSERT stock_movements (OUT)
        API->>DB: COMMIT
        API-->>APP: 201 Created (transaksi, stok terbaru)
        APP->>CACHE: Perbarui cache inventaris
        APP-->>U: Tampilkan konfirmasi transaksi berhasil
    else Stok tidak mencukupi
        API->>DB: ROLLBACK
        API-->>APP: 422 Unprocessable (stok tidak cukup)
        APP-->>U: Tampilkan pesan stok tidak cukup
    end
```

### 3.3 Melihat Analitik & Prediksi Kebutuhan Stok

```mermaid
sequenceDiagram
    autonumber
    actor U as Pemilik UMKM
    participant APP as Aplikasi Flutter
    participant API as Backend Laravel
    participant DB as PostgreSQL
    participant ML as Layanan ML<br/>(FastAPI)

    U->>APP: Buka halaman Analitik, pilih produk & horizon 7 - 30 hari
    APP->>API: GET /api/products/{id}/forecast?horizon=N
    API->>DB: Ambil hasil forecast terbaru
    alt Forecast masih valid
        DB-->>API: Forecast + forecast_details
    else Forecast kedaluwarsa / belum ada
        API->>DB: Ambil riwayat penjualan harian produk
        DB-->>API: Data deret waktu
        API->>ML: POST /predict (product_id, history, horizon)
        Note over ML: Praproses, inferensi model<br/>(ARIMA/SARIMA/Prophet)
        alt ML merespons (target < 5 detik)
            ML-->>API: Prediksi harian + metrik (MAPE, RMSE, MAE)
            API->>DB: Simpan forecasts & forecast_details
        else Timeout / error
            ML-->>API: Error / timeout
            API-->>APP: 503 Layanan prediksi tidak tersedia
            APP-->>U: Tampilkan pesan error & data cache terakhir
        end
    end
    API-->>APP: 200 OK (riwayat penjualan + prediksi + estimasi hari habis)
    APP-->>U: Render grafik tren & grafik proyeksi stok
```

### 3.4 Automated Push Notification & Konfirmasi Restock

```mermaid
sequenceDiagram
    autonumber
    participant SCH as Penjadwal Laravel
    participant API as Backend Laravel
    participant DB as PostgreSQL
    participant ML as Layanan ML<br/>(FastAPI)
    participant FCM as Firebase Cloud Messaging
    participant APP as Aplikasi Flutter
    actor U as Pemilik UMKM

    loop Setiap periode terjadwal (mis. harian)
        SCH->>API: Jalankan job cek stok
        API->>DB: Ambil produk aktif + stok + ambang batas
        loop Untuk setiap produk
            API->>ML: POST /predict (history, horizon)
            ML-->>API: Prediksi permintaan harian
            API->>DB: Simpan forecasts & forecast_details
            API->>API: Hitung estimasi hari stok habis
            opt Estimasi habis kurang dari atau sama dengan ambang batas
                API->>DB: INSERT notifications (RESTOCK_ALERT)
                API->>DB: Ambil fcm_token milik user
                API->>FCM: Kirim pesan push (judul, isi, product_id)
                FCM-->>APP: Push notification
                APP-->>U: Tampilkan "Stok Barang X diprediksi habis dalam 3 hari"
            end
        end
    end

    U->>APP: Ketuk notifikasi
    APP->>API: GET /api/notifications
    API-->>APP: Daftar alert
    APP-->>U: Tampilkan Pusat Notifikasi & Riwayat Alert
    U->>APP: Konfirmasi restock (jumlah barang masuk)
    APP->>API: POST /api/products/{id}/restock (quantity)
    API->>DB: UPDATE products.current_stock
    API->>DB: INSERT stock_movements (IN)
    API->>DB: UPDATE notifications (is_read = true)
    API-->>APP: 200 OK (stok terbaru)
    APP-->>U: Tampilkan stok terbarui di dasbor
```

---

## 4. Activity Diagram

### 4.1 Alur Penggunaan Utama (Pemilik UMKM)

```mermaid
flowchart TD
    S((" ")) --> A1["Buka aplikasi UMKM Sight"]
    A1 --> D1{"Sudah punya<br/>sesi login?"}
    D1 -- "Belum" --> A2["Registrasi / Login"]
    A2 --> D2{"Kredensial<br/>valid?"}
    D2 -- "Tidak" --> A2
    D2 -- "Ya" --> A3["Simpan token & sinkronisasi data"]
    D1 -- "Sudah" --> A3
    A3 --> A4["Tampilkan Beranda & Dasbor Stok"]
    A4 --> D3{"Pilih menu"}

    D3 -- "Produk & Transaksi" --> B1["Kelola produk (tambah / ubah / hapus)<br/>atau catat transaksi"]
    B1 --> B2["Kirim data ke Backend API"]
    B2 --> B3["Perbarui stok & mutasi stok"]
    B3 --> A4

    D3 -- "Analitik Prediksi" --> C1["Pilih produk & horizon 7 - 30 hari"]
    C1 --> C2["Ambil hasil peramalan dari Backend"]
    C2 --> D4{"Prediksi<br/>berhasil?"}
    D4 -- "Ya" --> C3["Tampilkan grafik tren & proyeksi"]
    D4 -- "Tidak" --> C4["Tampilkan pesan error / data cache"]
    C3 --> A4
    C4 --> A4

    D3 -- "Pusat Notifikasi" --> N1["Lihat daftar & riwayat alert"]
    N1 --> D5{"Lakukan<br/>restock?"}
    D5 -- "Ya" --> N2["Konfirmasi restock & input jumlah"]
    N2 --> N3["Perbarui jumlah stok di inventaris"]
    N3 --> A4
    D5 -- "Tidak" --> A4

    D3 -- "Logout" --> L1["Hapus token sesi"]
    L1 --> E(((" ")))
```

### 4.2 Alur Peramalan & Automated Push Notification (Sistem)

```mermaid
flowchart TD
    subgraph SCH["Penjadwal (Laravel)"]
        S((" ")) --> P1["Pemicu terjadwal berjalan"]
        P1 --> P2["Ambil daftar produk aktif"]
        P2 --> P3{"Masih ada produk<br/>yang belum dicek?"}
        P3 -- "Tidak" --> E(((" ")))
        P3 -- "Ya" --> P4["Ambil riwayat penjualan produk<br/>dari PostgreSQL"]
    end

    subgraph MLS["Layanan ML (FastAPI)"]
        M1["Praproses: agregasi harian / mingguan,<br/>bersihkan missing value & retur"]
        M2["Inferensi model time series<br/>(ARIMA / SARIMA / Prophet)"]
        M3["Kembalikan prediksi permintaan<br/>& metrik evaluasi"]
        M1 --> M2 --> M3
    end

    subgraph BE["Backend (Laravel)"]
        B1["Simpan forecasts & forecast_details"]
        B2["Hitung estimasi hari stok habis<br/>= stok saat ini : prediksi permintaan harian"]
        B3{"Estimasi habis ≤<br/>ambang batas?"}
        B4["Buat record notifikasi RESTOCK_ALERT"]
        B5["Kirim pesan ke FCM"]
    end

    subgraph MOB["Perangkat Pengguna"]
        U1["Terima push notification"]
        U2["Pengguna membuka Pusat Notifikasi"]
        U3["Konfirmasi restock & perbarui stok"]
    end

    P4 --> M1
    M3 --> B1
    B1 --> B2 --> B3
    B3 -- "Tidak" --> P3
    B3 -- "Ya" --> B4 --> B5 --> U1
    B5 --> P3
    U1 --> U2 --> U3
    U3 --> X(((" ")))
```

---

## 5. Class Diagram

Gabungan model domain (sesuai ERD) dan kelas layanan pada backend Laravel + integrasi ML.

```mermaid
classDiagram
    direction TB

    %% ===== Enumerasi =====
    class TransactionType {
        <<enumeration>>
        SALE
        PURCHASE
    }
    class MovementType {
        <<enumeration>>
        IN
        OUT
        ADJUSTMENT
    }
    class NotificationType {
        <<enumeration>>
        RESTOCK_ALERT
    }

    %% ===== Model domain =====
    class User {
        +int id
        +String name
        +String email
        -String password
        +register() User
        +login() AuthToken
        +logout() void
    }
    class Store {
        +int id
        +int userId
        +String storeName
        +String address
        +String phone
        +updateProfile() void
    }
    class DeviceToken {
        +int id
        +int userId
        +String fcmToken
        +String platform
        +DateTime lastActiveAt
    }
    class Product {
        +int id
        +int storeId
        +String stockCode
        +String name
        +String unit
        +double unitPrice
        +int currentStock
        +int reorderThreshold
        +bool isActive
        +isBelowThreshold() bool
        +adjustStock(qty) void
    }
    class Transaction {
        +int id
        +int storeId
        +String invoiceNo
        +TransactionType type
        +DateTime transactionDate
        +double totalAmount
        +calculateTotal() double
    }
    class TransactionItem {
        +int id
        +int transactionId
        +int productId
        +int quantity
        +double unitPrice
        +double subtotal
    }
    class StockMovement {
        +int id
        +int productId
        +int transactionId
        +MovementType movementType
        +int quantity
        +int stockBefore
        +int stockAfter
        +DateTime createdAt
    }
    class Forecast {
        +int id
        +int productId
        +String modelName
        +int horizonDays
        +double mape
        +double rmse
        +double mae
        +int daysUntilStockout
        +DateTime generatedAt
        +isExpired() bool
    }
    class ForecastDetail {
        +int id
        +int forecastId
        +Date forecastDate
        +double predictedQty
        +double lowerBound
        +double upperBound
    }
    class Notification {
        +int id
        +int userId
        +int productId
        +int forecastId
        +NotificationType type
        +String title
        +String message
        +bool isRead
        +DateTime sentAt
        +markAsRead() void
    }

    %% ===== Layanan backend =====
    class AuthService {
        +register(data) User
        +login(email, password) AuthToken
        +logout(token) void
        +registerDevice(userId, fcmToken) void
    }
    class InventoryService {
        +createProduct(data) Product
        +updateProduct(id, data) Product
        +deleteProduct(id) void
        +restock(productId, qty) StockMovement
        +getStockHistory(productId) List~StockMovement~
    }
    class TransactionService {
        +recordTransaction(data) Transaction
        +getSalesHistory(productId) List~Transaction~
    }
    class ForecastService {
        +getForecast(productId, horizon) Forecast
        +generateForecast(productId, horizon) Forecast
        +estimateStockout(product, forecast) int
    }
    class MLServiceClient {
        +String baseUrl
        +int timeoutSeconds
        +predict(productId, history, horizon) PredictionResult
    }
    class NotificationService {
        +checkAllProducts() void
        +createRestockAlert(product, forecast) Notification
        +getNotifications(userId) List~Notification~
        +markAsRead(id) void
    }
    class FcmGateway {
        +send(fcmToken, title, body, data) bool
    }
    class StockCheckScheduler {
        +schedule() void
        +run() void
    }

    %% ===== Relasi domain =====
    User "1" -- "1" Store : memiliki
    User "1" -- "0..*" DeviceToken : mendaftarkan
    User "1" -- "0..*" Notification : menerima
    Store "1" -- "0..*" Product : mengelola
    Store "1" -- "0..*" Transaction : mencatat
    Transaction "1" *-- "1..*" TransactionItem : terdiri dari
    Product "1" -- "0..*" TransactionItem : tercantum di
    Product "1" -- "0..*" StockMovement : mengalami
    Transaction "0..1" -- "0..*" StockMovement : menyebabkan
    Product "1" -- "0..*" Forecast : diramalkan
    Forecast "1" *-- "1..*" ForecastDetail : memiliki
    Product "1" -- "0..*" Notification : subjek
    Forecast "0..1" -- "0..*" Notification : memicu

    Transaction ..> TransactionType
    StockMovement ..> MovementType
    Notification ..> NotificationType

    %% ===== Relasi layanan =====
    AuthService ..> User
    AuthService ..> DeviceToken
    InventoryService ..> Product
    InventoryService ..> StockMovement
    TransactionService ..> Transaction
    TransactionService ..> InventoryService
    ForecastService ..> Forecast
    ForecastService ..> MLServiceClient
    NotificationService ..> Notification
    NotificationService ..> ForecastService
    NotificationService ..> FcmGateway
    StockCheckScheduler ..> NotificationService
```

---

## Asumsi yang dipakai (silakan koreksi)

1. Aktor utama hanya **Pemilik UMKM**; tidak ada admin (proposal tidak menyebut peran admin).
2. Satu akun = satu toko → relasi `USERS 1:1 STORES`.
3. Transaksi punya tipe `SALE` (keluar) dan `PURCHASE` (masuk/restock); riwayat mutasi dicatat di `STOCK_MOVEMENTS`.
4. Hasil peramalan disimpan (`FORECASTS` + `FORECAST_DETAILS`) agar tidak dihitung ulang tiap dibuka dan bisa dipakai sebagai dasar notifikasi.
5. Notifikasi dikirim lewat Firebase Cloud Messaging (FCM) oleh scheduler Laravel; proposal hanya menyebut "push notification", belum menyebut layanan spesifiknya.
6. Autentikasi memakai token (mis. Laravel Sanctum); proposal hanya menyebut "token autentikasi".
