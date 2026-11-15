-- =============================================================================
-- UMKM Sight - uji RLS untuk produk & prediksi
--
-- JALANKAN TERPISAH dari file lain, SATU BLOK per eksekusi (blok tiap BEGIN
-- sampai ROLLBACK). Alasan: BEGIN ... ROLLBACK di dalam satu eksekusi SQL
-- Editor akan ikut membatalkan perubahan lain dalam eksekusi yang sama, dan
-- SQL Editor hanya menampilkan hasil query terakhir.
--
-- Prasyarat: forecast_seed_and_test.sql BAGIAN 2 sudah dijalankan, serta akun
-- budi@tokoberkah.com dan siti@tokoberkah.com ada (test_login.sql).
-- =============================================================================


-- -----------------------------------------------------------------------------
-- BLOK A: sebagai BUDI (pemilik data uji)
-- Harapan: produk UJI = 8, forecast = 7, detail = 98, perlu restock = 4
-- -----------------------------------------------------------------------------
begin;
  select set_config(
    'request.jwt.claims',
    json_build_object(
      'sub',  (select id from auth.users where email = 'budi@tokoberkah.com'),
      'role', 'authenticated'
    )::text,
    true
  );
  set local role authenticated;

  select
    (select count(*) from public.products
      where stock_code like 'UJI-%')                              as produk_uji,        -- 8
    (select count(*) from public.forecasts f
       join public.products p on p.id = f.product_id
      where p.stock_code like 'UJI-%')                            as forecast,          -- 7
    (select count(*) from public.forecast_details)                as detail,            -- 98
    (select count(*) from public.restock_alert_candidates()
      where needs_restock and stock_code like 'UJI-%')            as perlu_restock;     -- 4
rollback;


-- -----------------------------------------------------------------------------
-- BLOK B: sebagai SITI (pengguna lain) - tidak boleh melihat data budi
-- Harapan: semua angka = 0
-- -----------------------------------------------------------------------------
begin;
  select set_config(
    'request.jwt.claims',
    json_build_object(
      'sub',  (select id from auth.users where email = 'siti@tokoberkah.com'),
      'role', 'authenticated'
    )::text,
    true
  );
  set local role authenticated;

  select
    (select count(*) from public.products)                        as produk_terlihat,   -- 0
    (select count(*) from public.forecasts)                       as forecast_terlihat, -- 0
    (select count(*) from public.forecast_details)                as detail_terlihat,   -- 0
    (select count(*) from public.restock_alert_candidates())      as kandidat_terlihat; -- 0
rollback;


-- -----------------------------------------------------------------------------
-- BLOK C: pengguna tidak boleh menulis prediksi (hanya service_role)
-- Harapan: error "permission denied for table forecasts"
-- (jalankan sendirian; error di sini menggagalkan transaksi, wajar)
-- -----------------------------------------------------------------------------
-- begin;
--   select set_config(
--     'request.jwt.claims',
--     json_build_object(
--       'sub',  (select id from auth.users where email = 'budi@tokoberkah.com'),
--       'role', 'authenticated'
--     )::text,
--     true
--   );
--   set local role authenticated;
--   insert into public.forecasts (product_id, horizon_days)
--   select id, 7 from public.products limit 1;
-- rollback;
