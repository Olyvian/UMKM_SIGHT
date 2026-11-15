-- =============================================================================
-- UMKM Sight - DATA UJI & PENGUJIAN PREDIKSI STOK (tanpa model ML)
--
-- Prasyarat (berurutan):
--   1. supabase/schema.sql
--   2. supabase/test_login.sql   (membuat akun budi@tokoberkah.com + tokonya)
--
-- CARA MENJALANKAN: SQL Editor hanya menampilkan hasil query TERAKHIR dalam
-- satu eksekusi. Jalankan per BAGIAN dengan memblok teksnya lalu Run:
--   BAGIAN 1 -> uji fungsi murni (tanpa tabel)   : hasil PASS/FAIL per kasus
--   BAGIAN 2 -> isi data uji (8 skenario)        : "Success"
--   BAGIAN 3 -> verifikasi hasil data uji        : hasil PASS/FAIL per skenario
--   BAGIAN 4 -> pembersihan (dikomentari)
--
-- Seluruh data uji memakai kode produk berawalan 'UJI-' sehingga tidak
-- menyentuh data lain. Bagian 2 aman dijalankan ulang.
-- Jangan menambahkan BEGIN/ROLLBACK di file ini (lihat catatan test_login.sql).
-- =============================================================================


-- =============================================================================
-- BAGIAN 1: UJI FUNGSI public.days_until_stockout (tanpa tabel)
-- Harapan: kolom status = PASS di semua baris.
-- =============================================================================
select
  kasus,
  hasil,
  harapan,
  case when hasil is not distinct from harapan then 'PASS' else 'FAIL' end as status
from (
  select * from (values
    ('stok 10, pakai 5/hari -> habis hari ke-2',
        public.days_until_stockout(10, array[5, 5, 5]::numeric[]), 2),
    ('stok 15, pakai 5/hari -> tepat habis hari ke-3 (batas)',
        public.days_until_stockout(15, array[5, 5, 5]::numeric[]), 3),
    ('stok 12, pakai 5/hari -> terlewati di hari ke-3',
        public.days_until_stockout(12, array[5, 5, 5]::numeric[]), 3),
    ('stok 16, pakai 5/hari x3 -> tidak habis dalam horizon',
        public.days_until_stockout(16, array[5, 5, 5]::numeric[]), null),
    ('stok 0 -> sudah habis (0)',
        public.days_until_stockout(0, array[5, 5]::numeric[]), 0),
    ('stok negatif -> dianggap sudah habis (0)',
        public.days_until_stockout(-3, array[5, 5]::numeric[]), 0),
    ('stok NULL -> NULL',
        public.days_until_stockout(null, array[5, 5]::numeric[]), null),
    ('array prediksi kosong -> NULL',
        public.days_until_stockout(10, array[]::numeric[]), null),
    ('array prediksi NULL -> NULL',
        public.days_until_stockout(10, null), null),
    ('prediksi 0 semua -> tidak pernah habis',
        public.days_until_stockout(10, array[0, 0, 0]::numeric[]), null),
    ('ada nilai NULL di array dianggap 0',
        public.days_until_stockout(5, array[null, 5]::numeric[]), 2),
    ('pecahan: stok 3, pakai 1.5/hari -> hari ke-2',
        public.days_until_stockout(3, array[1.5, 1.5, 1.5]::numeric[]), 2)
  ) as v(kasus, hasil, harapan)
) t
order by status desc, kasus;


-- =============================================================================
-- BAGIAN 2: ISI DATA UJI (8 skenario) untuk toko budi@tokoberkah.com
--
--  Kode    Skenario                                   Harapan
--  UJI-01  stok 10, pakai 5/hari                      habis hari ke-2 -> ALERT (prediksi)
--  UJI-02  stok 1000, pakai 10/hari                   aman            -> tidak alert
--  UJI-03  stok 20 = ambang 20 (batas)                ALERT (stok di bawah ambang)
--  UJI-04  produk baru, TANPA prediksi                tidak alert, has_forecast = false
--  UJI-05  stok 30, pakai 5/hari, prediksi 10 hari lalu  KEDALUWARSA -> tidak alert
--  UJI-06  stok 0                                     habis (hari 0)  -> ALERT
--  UJI-07  stok 35, pakai 5/hari                      habis hari ke-7 (batas 7) -> ALERT
--  UJI-08  stok 40, pakai 5/hari                      habis hari ke-8 -> tidak alert
-- =============================================================================
do $$
declare
  v_store  uuid;
  v_model  uuid;
  v_prod   uuid;
  v_fc     uuid;
  r        record;
begin
  select s.id
    into v_store
    from public.stores s
    join auth.users    u on u.id = s.user_id
   where u.email = 'budi@tokoberkah.com';

  if v_store is null then
    raise exception
      'Akun uji budi@tokoberkah.com belum ada. Jalankan supabase/test_login.sql lebih dulu.';
  end if;

  insert into public.ml_models (name, version, algorithm, is_active, trained_at)
  values ('seed-uji', '0.0.1', 'DUMMY', false, now())
  on conflict (name, version) do update set trained_at = excluded.trained_at
  returning id into v_model;

  for r in
    select * from (values
      -- kode,    nama,                    stok, ambang, pakai/hari, horizon, umur(hari), ada prediksi?
      ('UJI-01', 'Beras 5kg [UJI]',           10,   5,    5,  14,  0, true),
      ('UJI-02', 'Minyak Goreng 1L [UJI]', 1000,  50,   10,  14,  0, true),
      ('UJI-03', 'Gula 1kg [UJI]',            20,  20,    1,  14,  0, true),
      ('UJI-04', 'Teh Celup [UJI]',           30,   5,    0,  14,  0, false),
      ('UJI-05', 'Kopi Sachet [UJI]',         30,   5,    5,  14, 10, true),
      ('UJI-06', 'Sabun Batang [UJI]',         0,   0,    3,  14,  0, true),
      ('UJI-07', 'Tepung 1kg [UJI]',          35,   5,    5,  14,  0, true),
      ('UJI-08', 'Mie Instan [UJI]',          40,   5,    5,  14,  0, true)
    ) as t(code, pname, stock, threshold, demand, horizon, age_days, has_fc)
  loop
    insert into public.products
      (store_id, stock_code, name, unit, current_stock, reorder_threshold)
    values
      (v_store, r.code, r.pname, 'pcs', r.stock, r.threshold)
    on conflict (store_id, stock_code) do update
      set name = excluded.name,
          current_stock = excluded.current_stock,
          reorder_threshold = excluded.reorder_threshold,
          is_active = true
    returning id into v_prod;

    -- bersihkan prediksi lama produk uji ini (forecast_details ikut terhapus)
    delete from public.forecasts where product_id = v_prod;

    if r.has_fc then
      insert into public.forecasts
        (store_id, product_id, ml_model_id, horizon_days, generated_at)
      values
        (v_store, v_prod, v_model, r.horizon, now() - make_interval(days => r.age_days))
      returning id into v_fc;

      -- hari ke-1 = besok; prediksi konstan per hari
      insert into public.forecast_details
        (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound)
      select v_fc,
             v_store,
             current_date + g,
             r.demand,
             round(r.demand * 0.8, 2),
             round(r.demand * 1.2, 2)
        from generate_series(1, r.horizon) as g;

      perform public.refresh_forecast_stockout(v_fc);
    end if;
  end loop;
end $$;


-- =============================================================================
-- BAGIAN 3: VERIFIKASI HASIL DATA UJI
-- Harapan: kolom status = PASS di semua 8 baris.
-- (Dijalankan sebagai admin SQL Editor sehingga RLS tidak berlaku; uji RLS ada
--  di forecast_rls_test.sql.)
-- =============================================================================
with expected (stock_code, skenario, exp_days, exp_has_forecast, exp_stale, exp_needs_restock, exp_reason) as (
  values
    ('UJI-01', 'habis hari ke-2 -> alert prediksi',          2,    true,  false, true,  'PREDIKSI_HABIS'),
    ('UJI-02', 'stok aman',                                  null, true,  false, false, null),
    ('UJI-03', 'stok tepat di ambang (batas)',               null, true,  false, true,  'STOK_DI_BAWAH_AMBANG'),
    ('UJI-04', 'produk baru tanpa prediksi',                 null, false, false, false, null),
    ('UJI-05', 'prediksi kedaluwarsa tidak memicu alert',    6,    true,  true,  false, null),
    ('UJI-06', 'stok 0',                                     0,    true,  false, true,  'PREDIKSI_HABIS'),
    ('UJI-07', 'habis hari ke-7 (batas 7 hari)',             7,    true,  false, true,  'PREDIKSI_HABIS'),
    ('UJI-08', 'habis hari ke-8 (di luar 7 hari)',           8,    true,  false, false, null)
)
select
  e.stock_code,
  e.skenario,
  a.days_until_stockout                  as hari_habis,
  a.has_forecast,
  a.is_stale,
  a.needs_restock,
  a.reason,
  case
    when a.stock_code is not null
     and a.days_until_stockout is not distinct from e.exp_days
     and a.has_forecast     = e.exp_has_forecast
     and a.is_stale         = e.exp_stale
     and a.needs_restock    = e.exp_needs_restock
     and a.reason is not distinct from e.exp_reason
    then 'PASS' else 'FAIL'
  end as status
from expected e
left join public.restock_alert_candidates(7, interval '1 day') a
       on a.stock_code = e.stock_code
order by e.stock_code;


-- =============================================================================
-- BAGIAN 4: PEMBERSIHAN (hapus data uji; forecasts & details ikut terhapus)
-- Hanya menyentuh produk berkode 'UJI-%'. Hapus tanda komentar untuk memakai.
-- =============================================================================
-- delete from public.products where stock_code like 'UJI-%';
-- delete from public.ml_models where name = 'seed-uji';
