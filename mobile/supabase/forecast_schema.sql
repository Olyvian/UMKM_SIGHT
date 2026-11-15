-- =============================================================================
-- UMKM Sight - skema PREDIKSI STOK (produk, model ML, forecast)
--
-- Jalankan SETELAH supabase/schema.sql (butuh tabel stores & fungsi
-- set_updated_at). Aman dijalankan ulang (idempoten).
--
-- Tujuan: backend & aplikasi bisa dibangun dan diuji SEBELUM model ML selesai.
-- Kontraknya: siapa pun yang menghasilkan prediksi (model asli, skrip dummy,
-- atau data uji) cukup menulis ke forecasts + forecast_details, lalu memanggil
-- public.refresh_forecast_stockout(forecast_id).
--
-- Catatan:
--  * products di sini versi MINIMAL (tanpa category_id/supplier). Kolom itu
--    bisa ditambahkan nanti dengan ALTER TABLE.
--  * Penulisan forecasts/forecast_details hanya boleh oleh service_role
--    (pekerjaan ML/Edge Function). Aplikasi hanya membaca.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 1) TABEL
-- -----------------------------------------------------------------------------
create table if not exists public.products (
  id                 uuid primary key default gen_random_uuid(),
  store_id           uuid not null references public.stores (id) on delete cascade,
  stock_code         text not null,
  name               text not null,
  unit               text not null default 'pcs',
  unit_price         numeric(14, 2) not null default 0 check (unit_price >= 0),
  current_stock      integer not null default 0 check (current_stock >= 0),
  reorder_threshold  integer not null default 0 check (reorder_threshold >= 0),
  is_active          boolean not null default true,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  unique (store_id, stock_code)
);
create index if not exists products_store_idx on public.products (store_id);

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
  trained_at  timestamptz,
  created_at  timestamptz not null default now(),
  unique (name, version)
);

create table if not exists public.forecasts (
  id                   uuid primary key default gen_random_uuid(),
  product_id           uuid not null references public.products (id) on delete cascade,
  ml_model_id          uuid references public.ml_models (id),
  horizon_days         integer not null check (horizon_days between 7 and 30),
  -- hari ke-N (1 = hari pertama prediksi) saat stok diperkirakan habis;
  -- 0 = sudah habis; NULL = tidak habis dalam horizon.
  days_until_stockout  integer check (days_until_stockout >= 0),
  generated_at         timestamptz not null default now()
);
create index if not exists forecasts_product_generated_idx
  on public.forecasts (product_id, generated_at desc);

create table if not exists public.forecast_details (
  id             uuid primary key default gen_random_uuid(),
  forecast_id    uuid not null references public.forecasts (id) on delete cascade,
  forecast_date  date not null,
  predicted_qty  numeric(12, 2) not null check (predicted_qty >= 0),
  lower_bound    numeric(12, 2),
  upper_bound    numeric(12, 2),
  unique (forecast_id, forecast_date),
  check (lower_bound is null or upper_bound is null or lower_bound <= upper_bound)
);

drop trigger if exists products_set_updated_at on public.products;
create trigger products_set_updated_at
  before update on public.products
  for each row execute function public.set_updated_at();


-- -----------------------------------------------------------------------------
-- 2) FUNGSI
-- -----------------------------------------------------------------------------

-- 2a. Fungsi murni (tanpa tabel) agar mudah diuji dengan angka langsung.
--     Mengembalikan hari ke-N saat PEMAKAIAN KUMULATIF prediksi >= stok.
--       stok NULL                   -> NULL
--       stok <= 0                   -> 0   (sudah habis)
--       tidak habis dalam horizon   -> NULL
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

-- 2b. Hitung ulang & simpan days_until_stockout sebuah forecast dari
--     forecast_details + stok produk saat ini. Dipanggil oleh penghasil
--     prediksi setelah menulis forecast_details.
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

-- 2c. Daftar produk beserta keputusan "perlu restock?" (dasar notifikasi).
--     Aturan (ASUMSI - konfirmasikan ke tim, lihat README):
--       needs_restock = PREDIKSI_HABIS  : prediksi TERBARU & tidak kedaluwarsa
--                                         menunjukkan stok habis dalam
--                                         <= p_alert_days hari
--                    ATAU STOK_DI_BAWAH_AMBANG : current_stock <= reorder_threshold
--       Prediksi kedaluwarsa (lebih tua dari p_max_age) TIDAK memicu alert
--       berbasis prediksi karena angkanya tidak lagi bisa dipercaya.
--     Berjalan sebagai pemanggil, jadi RLS berlaku (pengguna hanya melihat
--     produk tokonya sendiri).
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


-- -----------------------------------------------------------------------------
-- 3) ROW LEVEL SECURITY
-- -----------------------------------------------------------------------------
alter table public.products         enable row level security;
alter table public.ml_models        enable row level security;
alter table public.forecasts        enable row level security;
alter table public.forecast_details enable row level security;

-- products: pemilik toko mengelola produk tokonya sendiri
drop policy if exists "products_select_own" on public.products;
create policy "products_select_own" on public.products
  for select to authenticated
  using (exists (select 1 from public.stores s
                  where s.id = products.store_id and s.user_id = (select auth.uid())));

drop policy if exists "products_insert_own" on public.products;
create policy "products_insert_own" on public.products
  for insert to authenticated
  with check (exists (select 1 from public.stores s
                       where s.id = products.store_id and s.user_id = (select auth.uid())));

drop policy if exists "products_update_own" on public.products;
create policy "products_update_own" on public.products
  for update to authenticated
  using (exists (select 1 from public.stores s
                  where s.id = products.store_id and s.user_id = (select auth.uid())))
  with check (exists (select 1 from public.stores s
                       where s.id = products.store_id and s.user_id = (select auth.uid())));

drop policy if exists "products_delete_own" on public.products;
create policy "products_delete_own" on public.products
  for delete to authenticated
  using (exists (select 1 from public.stores s
                  where s.id = products.store_id and s.user_id = (select auth.uid())));

-- ml_models: info model tidak sensitif, boleh dibaca semua pengguna login
drop policy if exists "ml_models_select_all" on public.ml_models;
create policy "ml_models_select_all" on public.ml_models
  for select to authenticated
  using (true);

-- forecasts & forecast_details: baca saja, hanya untuk produk toko sendiri
drop policy if exists "forecasts_select_own" on public.forecasts;
create policy "forecasts_select_own" on public.forecasts
  for select to authenticated
  using (exists (select 1
                   from public.products p
                   join public.stores   s on s.id = p.store_id
                  where p.id = forecasts.product_id and s.user_id = (select auth.uid())));

drop policy if exists "forecast_details_select_own" on public.forecast_details;
create policy "forecast_details_select_own" on public.forecast_details
  for select to authenticated
  using (exists (select 1
                   from public.forecasts f
                   join public.products  p on p.id = f.product_id
                   join public.stores    s on s.id = p.store_id
                  where f.id = forecast_details.forecast_id and s.user_id = (select auth.uid())));


-- -----------------------------------------------------------------------------
-- 4) HAK AKSES
-- -----------------------------------------------------------------------------
revoke all on public.products, public.ml_models, public.forecasts, public.forecast_details
  from anon, authenticated;

grant select, insert, update, delete on public.products to authenticated;
grant select on public.ml_models, public.forecasts, public.forecast_details to authenticated;

-- Fungsi: hanya penghasil prediksi (service_role) yang boleh menyimpan hasil.
revoke execute on function public.refresh_forecast_stockout(uuid) from public, anon, authenticated;
revoke execute on function public.restock_alert_candidates(integer, interval) from public, anon;
grant  execute on function public.restock_alert_candidates(integer, interval) to authenticated;
