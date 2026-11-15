-- =============================================================================
-- UMKM Sight - SKEMA LENGKAP DATABASE (Supabase / PostgreSQL)
--
-- SATU file untuk seluruh database aplikasi. Isinya, berurutan:
--   1. Profil pengguna & toko (profiles, stores) + trigger pendaftaran.
--   2. Preferensi notifikasi per toko.
--   3. Fungsi bantu (my_store_id, nomor invoice).
--   4. Cadangan tabel versi lama (dilewati pada project baru).
--   5. Inventaris: categories, suppliers, products.
--   6. Transaksi: transactions, transaction_items, stock_movements.
--   7. Prediksi: ml_models, forecasts, forecast_details.
--   8. Notifikasi: notifications, device_tokens.
--   9. Indeks, trigger, fungsi RPC, view, RLS, hak akses, bucket gambar.
--
-- Cara pakai: Supabase > SQL Editor > New query > tempel SELURUH isi file >
-- pastikan tidak ada teks yang terblok sebagian > Run.
--
-- Skrip ini:
--   * idempoten - aman dijalankan berulang;
--   * bisa dipakai untuk project BARU (semua tabel dibuat dari nol);
--   * bisa dipakai untuk project LAMA yang masih memakai skema versi
--     sebelumnya (dulu terpisah di schema.sql + forecast_schema.sql +
--     schema_Inventoris.sql): kolom yang kurang ditambahkan, store_id yang
--     masih kosong diisi, dan tabel lama dicadangkan ke schema "cadangan".
--
-- Asumsi migrasi: bila ada produk lama yang store_id-nya kosong, project
-- hanya boleh punya TEPAT SATU toko (diisi otomatis). Kalau lebih dari satu,
-- skrip berhenti dengan pesan jelas dan store_id harus diisi manual.
--
-- Catatan desain:
--   * Email & kata sandi disimpan Supabase Auth di auth.users (kata sandi
--     di-hash otomatis), jadi tidak ada kolom password di tabel kita.
--   * profiles ~ tabel USERS pada ERD; id memakai UUID yang sama dengan
--     auth.users.id (bukan bigint).
--   * stores = satu toko per akun (user_id unik).
--   * Baris profiles & stores dibuat otomatis oleh trigger saat pendaftaran,
--     dari data name & store_name yang dikirim aplikasi.
--   * Row Level Security (RLS) aktif: pengguna hanya bisa membaca/mengubah
--     datanya sendiri. Kolom role TIDAK bisa diubah dari aplikasi (admin
--     ditetapkan manual lewat SQL Editor).
--   * Penulisan forecasts/forecast_details hanya oleh service_role (pekerjaan
--     ML/Edge Function). Aplikasi hanya membaca.
--   * Perubahan stok hanya lewat RPC (record_sale, record_stock_in,
--     adjust_stock) supaya setiap perubahan selalu tercatat di stock_movements.
--
-- Pemakaian dari Flutter (supabase_flutter):
--   await supabase.rpc('record_sale', params: {
--     'p_items': [{'product_id': id, 'quantity': 2}],
--     'p_note': 'Pembeli A',
--     // opsional: tanggal transaksi sebenarnya (default now())
--     'p_transaction_date': '2026-04-15T02:30:00Z',
--   });
--   await supabase.rpc('record_stock_in',
--     params: {'p_product_id': id, 'p_quantity': 15});
--   final rows = await supabase.from('product_overview').select();
--   final summary = await supabase.from('store_summary').select().single();
--
-- Kunci service_role JANGAN pernah dimasukkan ke aplikasi Flutter.
-- =============================================================================


-- =============================================================================
-- BAGIAN 1: Profil pengguna & toko
-- =============================================================================
create table if not exists public.profiles (
  id          uuid primary key references auth.users (id) on delete cascade,
  name        text not null,
  role        text not null default 'OWNER' check (role in ('OWNER', 'ADMIN')),
  is_active   boolean not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create table if not exists public.stores (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null unique references public.profiles (id) on delete cascade,
  store_name  text not null,
  address     text,
  phone       text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);


-- =============================================================================
-- BAGIAN 2: Trigger pendaftaran & updated_at
-- =============================================================================

-- Buat profil & toko saat akun baru terdaftar.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, name)
  values (
    new.id,
    coalesce(nullif(trim(new.raw_user_meta_data ->> 'name'), ''), 'Pemilik Toko')
  );

  insert into public.stores (user_id, store_name)
  values (
    new.id,
    coalesce(nullif(trim(new.raw_user_meta_data ->> 'store_name'), ''), 'Toko Saya')
  );

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Perbarui updated_at setiap kali baris diubah.
create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

drop trigger if exists stores_set_updated_at on public.stores;
create trigger stores_set_updated_at
  before update on public.stores
  for each row execute function public.set_updated_at();


-- =============================================================================
-- BAGIAN 3: Preferensi notifikasi per toko (layar Profil & Pengaturan)
-- =============================================================================
alter table public.stores
  add column if not exists notify_low_stock      boolean not null default true,
  add column if not exists notify_out_of_stock   boolean not null default true,
  add column if not exists notify_weekly_report  boolean not null default false,
  add column if not exists alert_threshold_days  integer not null default 3
  check (alert_threshold_days between 1 and 30);


-- =============================================================================
-- BAGIAN 4: Fungsi bantu
-- =============================================================================

-- Mengembalikan id toko milik pengguna yang sedang login.
create or replace function public.my_store_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select id from public.stores where user_id = (select auth.uid());
$$;

create sequence if not exists public.invoice_seq;

create or replace function public.next_invoice_no()
returns text
language sql
volatile
set search_path = ''
as $$
  select 'TRX-'
      || to_char(now() at time zone 'Asia/Jakarta', 'YYMMDD')
      || '-'
      || lpad(nextval('public.invoice_seq')::text, 4, '0');
$$;


-- =============================================================================
-- BAGIAN 5: Cadangan tabel versi lama
--
-- Hanya berpengaruh pada database yang sudah berisi tabel dari skema lama.
-- Pada project baru semua blok di bawah ini dilewati (tabelnya belum ada).
-- =============================================================================
create schema if not exists cadangan;

-- Cadangan yang dulu dibuat di schema public (tanpa RLS, bisa terbaca lewat
-- API) dipindahkan ke schema cadangan.
do $$
declare
  t text;
begin
  foreach t in array array['products_backup', 'forecasts_backup', 'forecast_details_backup'] loop
    if to_regclass('public.' || t) is not null then
      execute format('alter table public.%I set schema cadangan', t);
    end if;
  end loop;
end $$;

-- Snapshot keadaan SEBELUM migrasi di bagian berikutnya.
do $$
begin
  if to_regclass('public.products') is not null then
    execute 'create table if not exists cadangan.products_pre_migrasi as select * from public.products';
  end if;
  if to_regclass('public.forecasts') is not null then
    execute 'create table if not exists cadangan.forecasts_pre_migrasi as select * from public.forecasts';
  end if;
  if to_regclass('public.forecast_details') is not null then
    execute 'create table if not exists cadangan.forecast_details_pre_migrasi as select * from public.forecast_details';
  end if;
end $$;


-- =============================================================================
-- BAGIAN 6: categories & suppliers
-- =============================================================================
create table if not exists public.categories (
  id           uuid primary key default gen_random_uuid(),
  store_id     uuid not null default public.my_store_id()
               references public.stores (id) on delete cascade,
  name         text not null,
  description  text,
  created_at   timestamptz not null default now(),
  unique (store_id, name)
);

create table if not exists public.suppliers (
  id              uuid primary key default gen_random_uuid(),
  store_id        uuid not null default public.my_store_id()
                  references public.stores (id) on delete cascade,
  name            text not null,
  contact_person  text,
  phone           text,
  address         text,
  created_at      timestamptz not null default now()
);


-- =============================================================================
-- BAGIAN 7: products
-- =============================================================================
create table if not exists public.products (
  id                 uuid primary key default gen_random_uuid(),
  store_id           uuid not null default public.my_store_id()
                     references public.stores (id) on delete cascade,
  category_id        uuid references public.categories (id) on delete set null,
  stock_code         text not null,                        -- SKU, mis. BRS-5KG-04
  name               text not null,
  unit               text not null default 'pcs',          -- karung, botol, kg, ...
  unit_price         numeric(14, 2) not null default 0 check (unit_price >= 0),
  current_stock      integer not null default 0 check (current_stock >= 0),
  reorder_threshold  integer not null default 0 check (reorder_threshold >= 0),
  is_monitored       boolean not null default true,
  is_active          boolean not null default true,
  image_path         text,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now()
);

-- Isi store_id untuk baris lama yang masih kosong.
do $$
declare
  v_stores integer;
  v_null   integer;
begin
  select count(*) into v_stores from public.stores;
  select count(*) into v_null from public.products where store_id is null;

  if v_null > 0 then
    if v_stores = 1 then
      update public.products
      set store_id = (select id from public.stores limit 1)
      where store_id is null;
    else
      raise exception
        'MIGRASI DIBATALKAN: % produk belum punya store_id dan jumlah toko = % (harus tepat 1 agar bisa diisi otomatis). Isi store_id manual lalu jalankan ulang.',
        v_null, v_stores;
    end if;
  end if;
end $$;

-- Kolom tambahan untuk tabel lama (tidak berpengaruh kalau sudah ada).
alter table public.products
  add column if not exists category_id   uuid references public.categories (id) on delete set null,
  add column if not exists is_monitored  boolean not null default true,
  add column if not exists is_active     boolean not null default true,
  add column if not exists image_path    text,
  add column if not exists created_at    timestamptz not null default now(),
  add column if not exists updated_at    timestamptz not null default now();

alter table public.products alter column store_id set not null;
alter table public.products alter column store_id set default public.my_store_id();

-- SKU unik per toko (gagal dengan jelas kalau ada kode ganda).
create unique index if not exists products_store_stock_code_uidx
  on public.products (store_id, stock_code);


-- =============================================================================
-- BAGIAN 8: transactions, transaction_items, stock_movements
-- =============================================================================
create table if not exists public.transactions (
  id                uuid primary key default gen_random_uuid(),
  store_id          uuid not null default public.my_store_id()
                    references public.stores (id) on delete cascade,
  supplier_id       uuid references public.suppliers (id) on delete set null,
  invoice_no        text not null,
  transaction_type  text not null check (transaction_type in ('SALE', 'PURCHASE')),
  transaction_date  timestamptz not null default now(),    -- sumber data time series
  total_amount      numeric(14, 2) not null default 0 check (total_amount >= 0),
  note              text,
  created_at        timestamptz not null default now(),
  unique (store_id, invoice_no),
  check (supplier_id is null or transaction_type = 'PURCHASE')
);

create table if not exists public.transaction_items (
  id              uuid primary key default gen_random_uuid(),
  transaction_id  uuid not null references public.transactions (id) on delete cascade,
  store_id        uuid not null references public.stores (id) on delete cascade,
  product_id      uuid not null references public.products (id) on delete restrict,
  quantity        integer not null check (quantity > 0),
  unit_price      numeric(14, 2) not null check (unit_price >= 0),
  subtotal        numeric(14, 2) generated always as (quantity * unit_price) stored
);

create table if not exists public.stock_movements (
  id              uuid primary key default gen_random_uuid(),
  store_id        uuid not null references public.stores (id) on delete cascade,
  product_id      uuid not null references public.products (id) on delete restrict,
  transaction_id  uuid references public.transactions (id) on delete set null,
  movement_type   text not null check (movement_type in ('IN', 'OUT', 'ADJUSTMENT')),
  quantity        integer not null check (quantity >= 0),
  stock_before    integer not null check (stock_before >= 0),
  stock_after     integer not null check (stock_after >= 0),
  note            text,
  created_at      timestamptz not null default now()
);


-- =============================================================================
-- BAGIAN 9: ml_models, forecasts, forecast_details
-- =============================================================================

-- Model ML yang menghasilkan prediksi. Ditulis oleh pekerjaan ML/Edge
-- Function (service_role), dibaca oleh aplikasi.
create table if not exists public.ml_models (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  version     text not null,
  algorithm   text not null
              check (algorithm in ('DUMMY', 'MOVING_AVERAGE', 'ARIMA', 'SARIMA', 'PROPHET', 'LSTM')),
  mape        numeric(6, 2),
  rmse        numeric(12, 4),
  mae         numeric(12, 4),
  is_active   boolean not null default false,
  trained_at  timestamptz,                                  -- null = belum dilatih
  created_at  timestamptz not null default now(),
  unique (name, version)
);

-- Penyesuaian untuk database yang dibuat dengan skema versi lama.
alter table public.ml_models
  add column if not exists created_at timestamptz not null default now();
alter table public.ml_models alter column trained_at drop not null;

-- Versi lama belum punya jaminan (name, version) unik.
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.ml_models'::regclass
      and conname = 'ml_models_name_version_key'
  ) then
    if exists (select 1 from public.ml_models group by name, version having count(*) > 1) then
      raise notice 'ml_models punya duplikat (name, version): indeks unik dilewati.';
    else
      create unique index if not exists ml_models_name_version_uidx
        on public.ml_models (name, version);
    end if;
  end if;
end $$;

-- Versi lama hanya mengizinkan ARIMA/SARIMA/PROPHET/LSTM/LINEAR, sehingga
-- model DUMMY & MOVING_AVERAGE tidak bisa dicatat.
do $$
begin
  alter table public.ml_models drop constraint if exists ml_models_algorithm_check;
  alter table public.ml_models add constraint ml_models_algorithm_check
    check (algorithm in ('DUMMY', 'MOVING_AVERAGE', 'ARIMA', 'SARIMA', 'PROPHET', 'LSTM'));
exception
  when check_violation then
    raise exception
      'MIGRASI DIBATALKAN: ml_models berisi nilai algorithm di luar daftar yang diizinkan. Perbaiki datanya lalu jalankan ulang.';
end $$;

create table if not exists public.forecasts (
  id                   uuid primary key default gen_random_uuid(),
  store_id             uuid not null references public.stores (id) on delete cascade,
  product_id           uuid not null references public.products (id) on delete cascade,
  ml_model_id          uuid references public.ml_models (id),
  horizon_days         integer not null check (horizon_days between 7 and 30),
  -- hari ke-N (1 = hari pertama prediksi) saat stok diperkirakan habis;
  -- 0 = sudah habis; NULL = tidak habis dalam horizon.
  days_until_stockout  integer check (days_until_stockout >= 0),
  avg_daily_demand     numeric(12, 2),
  generated_at         timestamptz not null default now()
);

alter table public.forecasts
  add column if not exists store_id         uuid references public.stores (id) on delete cascade,
  add column if not exists avg_daily_demand numeric(12, 2);

-- Isi store_id forecasts dari produk induknya.
update public.forecasts f
set store_id = p.store_id
from public.products p
where p.id = f.product_id and f.store_id is null;

do $$
declare
  v integer;
begin
  select count(*) into v from public.forecasts where store_id is null;
  if v > 0 then
    raise exception
      'MIGRASI DIBATALKAN: % baris forecasts tidak punya produk induk yang valid (store_id tetap kosong).', v;
  end if;
end $$;

alter table public.forecasts alter column store_id set not null;

create table if not exists public.forecast_details (
  id              uuid primary key default gen_random_uuid(),
  forecast_id     uuid not null references public.forecasts (id) on delete cascade,
  store_id        uuid not null references public.stores (id) on delete cascade,
  forecast_date   date not null,
  predicted_qty   numeric(12, 2) not null check (predicted_qty >= 0),
  lower_bound     numeric(12, 2),
  upper_bound     numeric(12, 2),
  unique (forecast_id, forecast_date),
  check (lower_bound is null or upper_bound is null or lower_bound <= upper_bound)
);

alter table public.forecast_details
  add column if not exists store_id uuid references public.stores (id) on delete cascade;

-- Isi store_id forecast_details dari forecasts induknya.
update public.forecast_details d
set store_id = f.store_id
from public.forecasts f
where f.id = d.forecast_id and d.store_id is null;

do $$
declare
  v integer;
begin
  select count(*) into v from public.forecast_details where store_id is null;
  if v > 0 then
    raise exception
      'MIGRASI DIBATALKAN: % baris forecast_details tidak punya forecast induk yang valid.', v;
  end if;
end $$;

alter table public.forecast_details alter column store_id set not null;

-- Jaminan satu baris per forecast per tanggal + batas bawah <= batas atas.
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.forecast_details'::regclass
      and conname = 'forecast_details_forecast_id_forecast_date_key'
  ) then
    if exists (
      select 1 from public.forecast_details
      group by forecast_id, forecast_date
      having count(*) > 1
    ) then
      raise notice 'forecast_details punya duplikat (forecast_id, forecast_date): indeks unik dilewati.';
    else
      create unique index if not exists forecast_details_forecast_date_uidx
        on public.forecast_details (forecast_id, forecast_date);
    end if;
  end if;

  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.forecast_details'::regclass
      and conname = 'forecast_details_check'
  ) then
    alter table public.forecast_details add constraint forecast_details_check
      check (lower_bound is null or upper_bound is null or lower_bound <= upper_bound);
  end if;
end $$;


-- =============================================================================
-- BAGIAN 10: notifications & device_tokens
-- =============================================================================
create table if not exists public.notifications (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references public.profiles (id) on delete cascade,
  product_id   uuid references public.products (id) on delete cascade,
  forecast_id  uuid references public.forecasts (id) on delete set null,
  type         text not null check (type in ('RESTOCK_ALERT', 'LOW_STOCK', 'OUT_OF_STOCK', 'WEEKLY_REPORT')),
  title        text not null,
  message      text not null,
  is_read      boolean not null default false,
  sent_at      timestamptz not null default now(),
  read_at      timestamptz
);

create table if not exists public.device_tokens (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null default auth.uid()
                  references public.profiles (id) on delete cascade,
  fcm_token       text not null unique,
  platform        text not null default 'android',
  last_active_at  timestamptz not null default now()
);


-- =============================================================================
-- BAGIAN 11: Indeks & trigger
-- =============================================================================
create index if not exists products_store_idx
  on public.products (store_id) where is_active;
create index if not exists transactions_store_date_idx
  on public.transactions (store_id, transaction_date desc);
create index if not exists items_transaction_idx
  on public.transaction_items (transaction_id);
create index if not exists items_product_idx
  on public.transaction_items (product_id);
create index if not exists movements_product_idx
  on public.stock_movements (product_id, created_at desc);
create index if not exists forecasts_product_idx
  on public.forecasts (product_id, generated_at desc);
create index if not exists notifications_user_idx
  on public.notifications (user_id, is_read, sent_at desc);

drop trigger if exists products_set_updated_at on public.products;
create trigger products_set_updated_at
  before update on public.products
  for each row execute function public.set_updated_at();


-- =============================================================================
-- BAGIAN 12: Fungsi prediksi
-- =============================================================================

-- Fungsi murni (tanpa tabel) agar mudah diuji dengan angka langsung.
-- Mengembalikan hari ke-N saat PEMAKAIAN KUMULATIF prediksi >= stok.
--   stok NULL                   -> NULL
--   stok <= 0                   -> 0   (sudah habis)
--   tidak habis dalam horizon   -> NULL
create or replace function public.days_until_stockout(
  p_stock         numeric,
  p_daily_demand  numeric[]
)
returns integer
language plpgsql
immutable
set search_path = ''
as $$
declare
  cum numeric := 0;
  i   integer;
begin
  if p_stock is null then
    return null;
  end if;
  if p_stock <= 0 then
    return 0;
  end if;
  if p_daily_demand is null then
    return null;
  end if;

  for i in 1 .. coalesce(array_length(p_daily_demand, 1), 0) loop
    cum := cum + coalesce(p_daily_demand[i], 0);
    if cum >= p_stock then
      return i;
    end if;
  end loop;

  return null;
end;
$$;

-- Hitung ulang & simpan days_until_stockout sebuah forecast dari
-- forecast_details + stok produk saat ini. Dipanggil oleh penghasil
-- prediksi setelah menulis forecast_details.
create or replace function public.refresh_forecast_stockout(p_forecast_id uuid)
returns integer
language plpgsql
set search_path = ''
as $$
declare
  v_stock integer;
  v_days  integer;
begin
  select p.current_stock
    into v_stock
    from public.forecasts f
    join public.products  p on p.id = f.product_id
   where f.id = p_forecast_id;

  if not found then
    raise exception 'Forecast % tidak ditemukan', p_forecast_id;
  end if;

  select public.days_until_stockout(
           v_stock,
           array_agg(d.predicted_qty order by d.forecast_date)
         )
    into v_days
    from public.forecast_details d
   where d.forecast_id = p_forecast_id;

  update public.forecasts
     set days_until_stockout = v_days
   where id = p_forecast_id;

  return v_days;
end;
$$;

-- Daftar produk beserta keputusan "perlu restock?" (dasar notifikasi).
-- Aturan (ASUMSI - konfirmasikan ke tim, lihat README):
--   needs_restock = PREDIKSI_HABIS  : prediksi TERBARU & tidak kedaluwarsa
--                                     menunjukkan stok habis dalam
--                                     <= p_alert_days hari
--                ATAU STOK_DI_BAWAH_AMBANG : current_stock <= reorder_threshold
--   Prediksi kedaluwarsa (lebih tua dari p_max_age) TIDAK memicu alert
--   berbasis prediksi karena angkanya tidak lagi bisa dipercaya.
-- Berjalan sebagai pemanggil, jadi RLS berlaku (pengguna hanya melihat
-- produk tokonya sendiri).
create or replace function public.restock_alert_candidates(
  p_alert_days  integer  default 7,
  p_max_age     interval default interval '1 day'
)
returns table (
  product_id           uuid,
  stock_code           text,
  product_name         text,
  current_stock        integer,
  reorder_threshold    integer,
  forecast_id          uuid,
  generated_at         timestamptz,
  days_until_stockout  integer,
  has_forecast         boolean,
  is_stale             boolean,
  needs_restock        boolean,
  reason               text
)
language sql
stable
set search_path = ''
as $$
  select
    p.id,
    p.stock_code,
    p.name,
    p.current_stock,
    p.reorder_threshold,
    f.id,
    f.generated_at,
    f.days_until_stockout,
    (f.id is not null),
    coalesce(f.generated_at < now() - p_max_age, false),
    (rule.by_forecast or rule.by_threshold),
    case
      when rule.by_forecast  then 'PREDIKSI_HABIS'
      when rule.by_threshold then 'STOK_DI_BAWAH_AMBANG'
    end
  from public.products p
  left join lateral (
    select ff.id, ff.generated_at, ff.days_until_stockout
      from public.forecasts ff
     where ff.product_id = p.id
     order by ff.generated_at desc
     limit 1
  ) f on true
  cross join lateral (
    select
      (f.days_until_stockout is not null
        and f.days_until_stockout <= p_alert_days
        and not coalesce(f.generated_at < now() - p_max_age, false)) as by_forecast,
      (p.current_stock <= p.reorder_threshold)                       as by_threshold
  ) rule
  where p.is_active
$$;


-- =============================================================================
-- BAGIAN 13: Fungsi RPC transaksi (atomik)
-- Semuanya security definer, tetapi selalu memfilter berdasarkan toko milik
-- pengguna yang login (my_store_id()).
-- =============================================================================

-- Membuat notifikasi stok bila perlu (internal; tidak bisa dipanggil aplikasi).
create or replace function public._notify_stock(p_product_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_p public.products;
  v_s public.stores;
begin
  select * into v_p from public.products where id = p_product_id;
  if not found or not v_p.is_monitored then
    return;
  end if;
  select * into v_s from public.stores where id = v_p.store_id;

  if v_p.current_stock = 0 and v_s.notify_out_of_stock then
    if not exists (select 1 from public.notifications n
                    where n.product_id = v_p.id and n.type = 'OUT_OF_STOCK' and not n.is_read) then
      insert into public.notifications (user_id, product_id, type, title, message)
      values (v_s.user_id, v_p.id, 'OUT_OF_STOCK', 'Stok habis',
              v_p.name || ' sudah habis. Segera lakukan restock.');
    end if;
  elsif v_p.current_stock > 0
    and v_p.current_stock <= v_p.reorder_threshold
    and v_s.notify_low_stock then
    if not exists (select 1 from public.notifications n
                    where n.product_id = v_p.id and n.type = 'LOW_STOCK' and not n.is_read) then
      insert into public.notifications (user_id, product_id, type, title, message)
      values (v_s.user_id, v_p.id, 'LOW_STOCK', 'Stok menipis',
              'Stok ' || v_p.name || ' tersisa ' || v_p.current_stock || ' ' || v_p.unit
              || ', di bawah batas minimum ' || v_p.reorder_threshold || '.');
    end if;
  end if;
end;
$$;

-- Catat penjualan. p_items: [{"product_id": "...", "quantity": 2, "unit_price": 65000}]
-- unit_price opsional (default = harga produk). Mengembalikan id transaksi.
-- p_transaction_date opsional: tanggal transaksi sebenarnya (mis. penjualan
-- kemarin yang baru dicatat sekarang). Default now().
-- Galat: EMPTY_ITEMS, INVALID_QUANTITY, PRODUCT_NOT_FOUND, INSUFFICIENT_STOCK,
--        INVALID_DATE.

-- Buang versi lama 2 parameter bila ada. Tanpa ini, PostgreSQL menyimpan
-- keduanya sebagai overload dan PostgREST menolak memanggil karena ambigu
-- ("Could not choose the best candidate function"). Lihat juga
-- supabase/migration_record_sale_date.sql.
drop function if exists public.record_sale(jsonb, text);

create or replace function public.record_sale(
  p_items            jsonb,
  p_note             text default null,
  p_transaction_date timestamptz default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_store   uuid := public.my_store_id();
  v_date    timestamptz := coalesce(p_transaction_date, now());
  v_tx      uuid;
  v_item    jsonb;
  v_prod    public.products;
  v_qty     integer;
  v_price   numeric;
  v_total   numeric := 0;
begin
  if v_store is null then
    raise exception 'NO_STORE' using errcode = '42501';
  end if;
  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'EMPTY_ITEMS' using errcode = '22023';
  end if;

  -- Toleransi 5 menit untuk selisih jam perangkat dengan jam server.
  if v_date > now() + interval '5 minutes' then
    raise exception 'INVALID_DATE' using errcode = '22023';
  end if;

  insert into public.transactions (store_id, invoice_no, transaction_type, transaction_date, note)
  values (v_store, public.next_invoice_no(), 'SALE', v_date, p_note)
  returning id into v_tx;

  for v_item in select * from jsonb_array_elements(p_items) loop
    v_qty := (v_item ->> 'quantity')::integer;
    if v_qty is null or v_qty <= 0 then
      raise exception 'INVALID_QUANTITY' using errcode = '22023';
    end if;

    select * into v_prod
    from public.products
    where id = (v_item ->> 'product_id')::uuid and store_id = v_store and is_active
    for update;                                  -- kunci baris: aman dari penjualan bersamaan
    if not found then
      raise exception 'PRODUCT_NOT_FOUND' using errcode = 'P0002';
    end if;

    if v_prod.current_stock < v_qty then
      raise exception 'INSUFFICIENT_STOCK' using errcode = 'P0001',
        detail = format('%s: sisa %s %s, diminta %s', v_prod.name, v_prod.current_stock, v_prod.unit, v_qty);
    end if;

    v_price := coalesce((v_item ->> 'unit_price')::numeric, v_prod.unit_price);

    update public.products set current_stock = current_stock - v_qty where id = v_prod.id;

    insert into public.transaction_items (transaction_id, store_id, product_id, quantity, unit_price)
    values (v_tx, v_store, v_prod.id, v_qty, v_price);

    -- created_at diisi dengan tanggal transaksi agar riwayat mutasi stok
    -- (bagian "Aktivitas Terbaru" di beranda) urut konsisten.
    insert into public.stock_movements
      (store_id, product_id, transaction_id, movement_type, quantity, stock_before, stock_after, note, created_at)
    values
      (v_store, v_prod.id, v_tx, 'OUT', v_qty, v_prod.current_stock, v_prod.current_stock - v_qty, p_note, v_date);

    v_total := v_total + v_qty * v_price;
    perform public._notify_stock(v_prod.id);
  end loop;

  update public.transactions set total_amount = v_total where id = v_tx;
  return v_tx;
end;
$$;

-- Catat barang masuk (pembelian) untuk satu produk. Mengembalikan id transaksi.
create or replace function public.record_stock_in(
  p_product_id  uuid,
  p_quantity    integer,
  p_note        text default null,
  p_supplier_id uuid default null,
  p_unit_price  numeric default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_store  uuid := public.my_store_id();
  v_prod   public.products;
  v_tx     uuid;
  v_price  numeric;
begin
  if v_store is null then
    raise exception 'NO_STORE' using errcode = '42501';
  end if;
  if p_quantity is null or p_quantity <= 0 then
    raise exception 'INVALID_QUANTITY' using errcode = '22023';
  end if;
  if p_supplier_id is not null and not exists (
    select 1 from public.suppliers where id = p_supplier_id and store_id = v_store) then
    raise exception 'SUPPLIER_NOT_FOUND' using errcode = 'P0002';
  end if;

  select * into v_prod
  from public.products
  where id = p_product_id and store_id = v_store and is_active
  for update;
  if not found then
    raise exception 'PRODUCT_NOT_FOUND' using errcode = 'P0002';
  end if;

  v_price := coalesce(p_unit_price, v_prod.unit_price);

  insert into public.transactions
    (store_id, supplier_id, invoice_no, transaction_type, total_amount, note)
  values
    (v_store, p_supplier_id, public.next_invoice_no(), 'PURCHASE', p_quantity * v_price, p_note)
  returning id into v_tx;

  update public.products set current_stock = current_stock + p_quantity where id = v_prod.id;

  insert into public.transaction_items (transaction_id, store_id, product_id, quantity, unit_price)
  values (v_tx, v_store, v_prod.id, p_quantity, v_price);

  insert into public.stock_movements
    (store_id, product_id, transaction_id, movement_type, quantity, stock_before, stock_after, note)
  values
    (v_store, v_prod.id, v_tx, 'IN', p_quantity, v_prod.current_stock, v_prod.current_stock + p_quantity, p_note);

  return v_tx;
end;
$$;

-- Koreksi stok manual / stok awal (stock opname). Mencatat mutasi ADJUSTMENT.
create or replace function public.adjust_stock(
  p_product_id uuid,
  p_new_stock  integer,
  p_note       text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_store uuid := public.my_store_id();
  v_prod  public.products;
begin
  if v_store is null then
    raise exception 'NO_STORE' using errcode = '42501';
  end if;
  if p_new_stock is null or p_new_stock < 0 then
    raise exception 'INVALID_QUANTITY' using errcode = '22023';
  end if;

  select * into v_prod
  from public.products
  where id = p_product_id and store_id = v_store and is_active
  for update;
  if not found then
    raise exception 'PRODUCT_NOT_FOUND' using errcode = 'P0002';
  end if;

  update public.products set current_stock = p_new_stock where id = v_prod.id;

  insert into public.stock_movements
    (store_id, product_id, movement_type, quantity, stock_before, stock_after, note)
  values
    (v_store, v_prod.id, 'ADJUSTMENT', abs(p_new_stock - v_prod.current_stock),
     v_prod.current_stock, p_new_stock, coalesce(p_note, 'Koreksi stok'));

  perform public._notify_stock(v_prod.id);
end;
$$;


-- =============================================================================
-- BAGIAN 14: View untuk aplikasi (security_invoker: tetap tunduk pada RLS)
-- =============================================================================
drop view if exists public.store_summary;
drop view if exists public.product_overview;

-- Daftar produk + hasil prediksi terbaru + status stok.
create view public.product_overview
with (security_invoker = true) as
select
  p.id,
  p.stock_code,
  p.name,
  p.image_path,
  c.name                   as category,
  p.unit,
  p.unit_price,
  p.current_stock,
  p.reorder_threshold,
  p.is_monitored,
  p.is_active,
  f.days_until_stockout,
  f.avg_daily_demand,
  f.generated_at           as forecast_at,
  case
    when p.current_stock = 0                                                  then 'HABIS'
    when f.days_until_stockout is not null and f.days_until_stockout <= 3     then 'RESTOCK'
    when f.days_until_stockout is not null and f.days_until_stockout <= 7     then 'PANTAU'
    when p.current_stock <= p.reorder_threshold and p.reorder_threshold > 0   then 'PANTAU'
    else 'AMAN'
  end                      as status
from public.products p
left join public.categories c on c.id = p.category_id
left join lateral (
  select days_until_stockout, avg_daily_demand, generated_at
  from public.forecasts
  where product_id = p.id
  order by generated_at desc
  limit 1
) f on true;

-- Ringkasan untuk Beranda (satu baris): item aktif, perlu restock, stok habis.
create view public.store_summary
with (security_invoker = true) as
select
  count(*)                                   as active_items,
  count(*) filter (where status <> 'AMAN')   as need_restock,
  count(*) filter (where status = 'HABIS')   as out_of_stock
from public.product_overview
where is_active;


-- =============================================================================
-- BAGIAN 15: Row Level Security
-- =============================================================================
alter table public.profiles          enable row level security;
alter table public.stores            enable row level security;
alter table public.categories        enable row level security;
alter table public.suppliers         enable row level security;
alter table public.products          enable row level security;
alter table public.transactions      enable row level security;
alter table public.transaction_items enable row level security;
alter table public.stock_movements   enable row level security;
alter table public.ml_models         enable row level security;
alter table public.forecasts         enable row level security;
alter table public.forecast_details  enable row level security;
alter table public.notifications     enable row level security;
alter table public.device_tokens     enable row level security;

-- profiles & stores: hanya data sendiri
drop policy if exists "profiles_select_own" on public.profiles;
create policy "profiles_select_own" on public.profiles
  for select to authenticated
  using (id = (select auth.uid()));

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own" on public.profiles
  for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

drop policy if exists "stores_select_own" on public.stores;
create policy "stores_select_own" on public.stores
  for select to authenticated
  using (user_id = (select auth.uid()));

drop policy if exists "stores_update_own" on public.stores;
create policy "stores_update_own" on public.stores
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

-- categories & suppliers: baca/tulis/hapus data toko sendiri
drop policy if exists "categories_own" on public.categories;
create policy "categories_own" on public.categories
  for all to authenticated
  using (store_id = (select public.my_store_id()))
  with check (store_id = (select public.my_store_id()));

drop policy if exists "suppliers_own" on public.suppliers;
create policy "suppliers_own" on public.suppliers
  for all to authenticated
  using (store_id = (select public.my_store_id()))
  with check (store_id = (select public.my_store_id()));

-- products: baca/tambah/ubah data toko sendiri (tidak ada hapus; pakai is_active)
drop policy if exists "products_select_own" on public.products;
create policy "products_select_own" on public.products
  for select to authenticated
  using (store_id = (select public.my_store_id()));

drop policy if exists "products_insert_own" on public.products;
create policy "products_insert_own" on public.products
  for insert to authenticated
  with check (store_id = (select public.my_store_id()));

drop policy if exists "products_update_own" on public.products;
create policy "products_update_own" on public.products
  for update to authenticated
  using (store_id = (select public.my_store_id()))
  with check (store_id = (select public.my_store_id()));

-- Policy hapus lama pada products dibuang: produk diarsipkan lewat is_active
-- (hak DELETE juga dicabut di bagian hak akses di bawah).
drop policy if exists "products_delete_own" on public.products;

-- transaksi, item, mutasi, prediksi: hanya baca (penulisan lewat RPC / service_role)
drop policy if exists "transactions_select_own" on public.transactions;
create policy "transactions_select_own" on public.transactions
  for select to authenticated
  using (store_id = (select public.my_store_id()));

drop policy if exists "items_select_own" on public.transaction_items;
create policy "items_select_own" on public.transaction_items
  for select to authenticated
  using (store_id = (select public.my_store_id()));

drop policy if exists "movements_select_own" on public.stock_movements;
create policy "movements_select_own" on public.stock_movements
  for select to authenticated
  using (store_id = (select public.my_store_id()));

drop policy if exists "forecasts_select_own" on public.forecasts;
create policy "forecasts_select_own" on public.forecasts
  for select to authenticated
  using (store_id = (select public.my_store_id()));

drop policy if exists "forecast_details_select_own" on public.forecast_details;
create policy "forecast_details_select_own" on public.forecast_details
  for select to authenticated
  using (store_id = (select public.my_store_id()));

-- ml_models: dibaca semua pengguna login; diubah admin lewat SQL Editor / service_role
drop policy if exists "ml_models_select_all" on public.ml_models;
create policy "ml_models_select_all" on public.ml_models
  for select to authenticated
  using (true);

-- notifications: milik sendiri; hanya boleh menandai sudah dibaca
drop policy if exists "notifications_select_own" on public.notifications;
create policy "notifications_select_own" on public.notifications
  for select to authenticated
  using (user_id = (select auth.uid()));

drop policy if exists "notifications_update_own" on public.notifications;
create policy "notifications_update_own" on public.notifications
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

-- device_tokens: token FCM milik sendiri
drop policy if exists "device_tokens_own" on public.device_tokens;
create policy "device_tokens_own" on public.device_tokens
  for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));


-- =============================================================================
-- BAGIAN 16: Hak akses tingkat tabel/kolom (lapisan keamanan di atas RLS)
-- =============================================================================

-- profiles & stores: role/is_active tidak bisa diubah dari aplikasi
revoke all on public.profiles, public.stores from anon;
revoke insert, delete, update on public.profiles, public.stores from authenticated;

grant select on public.profiles, public.stores to authenticated;
grant update (name) on public.profiles to authenticated;
grant update (store_name, address, phone,
              notify_low_stock, notify_out_of_stock, notify_weekly_report, alert_threshold_days)
  on public.stores to authenticated;

-- Tabel inventaris, prediksi, notifikasi
revoke all on
  public.categories, public.suppliers, public.products, public.transactions,
  public.transaction_items, public.stock_movements, public.ml_models,
  public.forecasts, public.forecast_details, public.notifications,
  public.device_tokens, public.product_overview, public.store_summary
from anon;

revoke insert, update, delete on
  public.categories, public.suppliers, public.products, public.transactions,
  public.transaction_items, public.stock_movements, public.ml_models,
  public.forecasts, public.forecast_details, public.notifications,
  public.device_tokens
from authenticated;

grant select on
  public.categories, public.suppliers, public.products, public.transactions,
  public.transaction_items, public.stock_movements, public.ml_models,
  public.forecasts, public.forecast_details, public.notifications,
  public.device_tokens, public.product_overview, public.store_summary
to authenticated;

-- Kategori & pemasok: bebas dikelola pemilik toko
grant insert, delete on public.categories, public.suppliers to authenticated;
grant update (name, description) on public.categories to authenticated;
grant update (name, contact_person, phone, address) on public.suppliers to authenticated;

-- Produk: current_stock TIDAK bisa diubah langsung (hanya lewat RPC)
grant insert (category_id, stock_code, name, unit, unit_price, reorder_threshold, is_monitored, image_path)
  on public.products to authenticated;
grant update (category_id, stock_code, name, unit, unit_price, reorder_threshold, is_monitored, is_active, image_path)
  on public.products to authenticated;

-- Notifikasi: hanya penanda dibaca
grant update (is_read, read_at) on public.notifications to authenticated;

-- Token FCM
grant insert (fcm_token, platform) on public.device_tokens to authenticated;
grant update (fcm_token, platform, last_active_at) on public.device_tokens to authenticated;
grant delete on public.device_tokens to authenticated;

-- Fungsi RPC: hanya pengguna login (bukan anon)
revoke all on function public.my_store_id()                                         from public, anon;
revoke all on function public.next_invoice_no()                                     from public, anon, authenticated;
revoke all on function public._notify_stock(uuid)                                   from public, anon, authenticated;
revoke all on function public.record_sale(jsonb, text, timestamptz)                 from public, anon;
revoke all on function public.record_stock_in(uuid, integer, text, uuid, numeric)   from public, anon;
revoke all on function public.adjust_stock(uuid, integer, text)                     from public, anon;
revoke execute on function public.refresh_forecast_stockout(uuid)                   from public, anon, authenticated;
revoke execute on function public.restock_alert_candidates(integer, interval)       from public, anon;

grant execute on function public.my_store_id()                                      to authenticated;
grant execute on function public.record_sale(jsonb, text, timestamptz)              to authenticated;
grant execute on function public.record_stock_in(uuid, integer, text, uuid, numeric) to authenticated;
grant execute on function public.adjust_stock(uuid, integer, text)                  to authenticated;
grant execute on function public.restock_alert_candidates(integer, interval)        to authenticated;


-- =============================================================================
-- BAGIAN 17: Penyimpanan gambar produk
-- Gambar disimpan di bucket private, bukan di kolom database.
-- =============================================================================
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'product-images',
  'product-images',
  false,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update
set public = false,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "product_images_select_own" on storage.objects;
create policy "product_images_select_own"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'product-images'
    and (storage.foldername(name))[1] = (select auth.uid()::text)
  );

drop policy if exists "product_images_insert_own" on storage.objects;
create policy "product_images_insert_own"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'product-images'
    and (storage.foldername(name))[1] = (select auth.uid()::text)
  );

drop policy if exists "product_images_update_own" on storage.objects;
create policy "product_images_update_own"
  on storage.objects for update to authenticated
  using (
    bucket_id = 'product-images'
    and (storage.foldername(name))[1] = (select auth.uid()::text)
  )
  with check (
    bucket_id = 'product-images'
    and (storage.foldername(name))[1] = (select auth.uid()::text)
  );

drop policy if exists "product_images_delete_own" on storage.objects;
create policy "product_images_delete_own"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'product-images'
    and (storage.foldername(name))[1] = (select auth.uid()::text)
  );


-- =============================================================================
-- VERIFIKASI SETELAH MENJALANKAN
--   select * from public.store_summary;
--   select * from public.product_overview;
--   select proname, pg_get_function_arguments(oid)
--     from pg_proc where pronamespace = 'public'::regnamespace
--    order by proname;
-- =============================================================================
