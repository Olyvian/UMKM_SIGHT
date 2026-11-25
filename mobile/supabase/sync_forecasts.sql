-- =============================================================================
-- UMKM Sight: SINKRONISASI HASIL PERAMALAN ML ASLI KE DATABASE SUPABASE
-- Dihasilkan otomatis pada : 2026-11-25T04:36:58.894082+00:00
-- Sumber pipeline          : pipeline_summary.json (20 produk)
-- Rata-rata metrik model   : MAPE=14.86%, MAE=2.1888, RMSE=2.7104
--
-- Skrip ini memasukkan:
--   1. Metadata Model ML aktif di tabel ml_models
--   2. Produk-produk toko dari hasil pipeline (upsert by store_id, stock_code)
--   3. Prediksi deret waktu + interval kepercayaan (forecasts & forecast_details)
--   4. Menghitung hari stok habis via RPC refresh_forecast_stockout()
-- =============================================================================

do $$
declare
  v_store_id uuid;
  v_model_id uuid;
  v_prod_id  uuid;
  v_fc_id    uuid;
begin
  -- 1. Ambil ID toko aktif (ambil toko pertama yang terdaftar)
  select id into v_store_id from public.stores limit 1;
  if v_store_id is null then
    raise exception 'Belum ada toko yang terdaftar di database. Silakan daftar/login akun toko terlebih dahulu.';
  end if;

  -- 2. Nonaktifkan model lama lalu daftarkan / perbarui model aktif di ml_models
  update public.ml_models set is_active = false where is_active = true;
  insert into public.ml_models (name, version, algorithm, mape, rmse, mae, is_active, trained_at)
  values ('UMKM Sight Demand Forecast', '1.0.0', 'SARIMA', 14.86, 2.7104, 2.1888, true, now())
  on conflict (name, version) do update set
    algorithm = excluded.algorithm,
    mape = excluded.mape,
    rmse = excluded.rmse,
    mae = excluded.mae,
    is_active = true,
    trained_at = now()
  returning id into v_model_id;

  -- Produk: AIR-GLN-15 (Air Mineral Galon Isi Ulang 19L) | model terbaik: naive
  insert into public.products (store_id, stock_code, name, unit, current_stock, reorder_threshold, is_monitored, is_active)
  values (v_store_id, 'AIR-GLN-15', 'Air Mineral Galon Isi Ulang 19L', 'galon', 226, 57, true, true)
  on conflict (store_id, stock_code) do update set
    name = excluded.name,
    unit = excluded.unit,
    current_stock = excluded.current_stock,
    reorder_threshold = excluded.reorder_threshold,
    is_active = true
  returning id into v_prod_id;

  -- Hapus prediksi lama untuk produk ini agar tidak duplikat
  delete from public.forecasts where product_id = v_prod_id;

  -- Buat baris header prediksi di forecasts
  insert into public.forecasts (store_id, product_id, ml_model_id, horizon_days, avg_daily_demand, generated_at)
  values (v_store_id, v_prod_id, v_model_id, 7, 19.0, now())
  returning id into v_fc_id;

  -- Masukkan rincian prediksi harian ke forecast_details
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-16', 19.0, 16.43, 21.57);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-17', 19.0, 16.43, 21.57);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-18', 19.0, 16.43, 21.57);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-19', 19.0, 16.43, 21.57);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-20', 19.0, 16.43, 21.57);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-21', 19.0, 16.43, 21.57);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-22', 19.0, 16.43, 21.57);
  -- Hitung otomatis kapan stok habis
  perform public.refresh_forecast_stockout(v_fc_id);

  -- Produk: BRS-5KG-04 (Beras Premium 5 kg) | model terbaik: sarima_trend
  insert into public.products (store_id, stock_code, name, unit, current_stock, reorder_threshold, is_monitored, is_active)
  values (v_store_id, 'BRS-5KG-04', 'Beras Premium 5 kg', 'karung', 29, 51, true, true)
  on conflict (store_id, stock_code) do update set
    name = excluded.name,
    unit = excluded.unit,
    current_stock = excluded.current_stock,
    reorder_threshold = excluded.reorder_threshold,
    is_active = true
  returning id into v_prod_id;

  -- Hapus prediksi lama untuk produk ini agar tidak duplikat
  delete from public.forecasts where product_id = v_prod_id;

  -- Buat baris header prediksi di forecasts
  insert into public.forecasts (store_id, product_id, ml_model_id, horizon_days, avg_daily_demand, generated_at)
  values (v_store_id, v_prod_id, v_model_id, 7, 16.94, now())
  returning id into v_fc_id;

  -- Masukkan rincian prediksi harian ke forecast_details
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-16', 12.32, 10.31, 14.32);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-17', 15.37, 13.37, 17.38);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-18', 14.53, 12.53, 16.53);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-19', 17.97, 15.97, 19.97);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-20', 17.35, 15.35, 19.36);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-21', 19.21, 17.21, 21.22);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-22', 21.82, 19.82, 23.82);
  -- Hitung otomatis kapan stok habis
  perform public.refresh_forecast_stockout(v_fc_id);

  -- Produk: BWG-500-18 (Bawang Merah Pilihan 500g) | model terbaik: naive
  insert into public.products (store_id, stock_code, name, unit, current_stock, reorder_threshold, is_monitored, is_active)
  values (v_store_id, 'BWG-500-18', 'Bawang Merah Pilihan 500g', 'bungkus', 234, 60, true, true)
  on conflict (store_id, stock_code) do update set
    name = excluded.name,
    unit = excluded.unit,
    current_stock = excluded.current_stock,
    reorder_threshold = excluded.reorder_threshold,
    is_active = true
  returning id into v_prod_id;

  -- Hapus prediksi lama untuk produk ini agar tidak duplikat
  delete from public.forecasts where product_id = v_prod_id;

  -- Buat baris header prediksi di forecasts
  insert into public.forecasts (store_id, product_id, ml_model_id, horizon_days, avg_daily_demand, generated_at)
  values (v_store_id, v_prod_id, v_model_id, 7, 20.0, now())
  returning id into v_fc_id;

  -- Masukkan rincian prediksi harian ke forecast_details
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-16', 20.0, 17.57, 22.43);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-17', 20.0, 17.57, 22.43);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-18', 20.0, 17.57, 22.43);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-19', 20.0, 17.57, 22.43);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-20', 20.0, 17.57, 22.43);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-21', 20.0, 17.57, 22.43);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-22', 20.0, 17.57, 22.43);
  -- Hitung otomatis kapan stok habis
  perform public.refresh_forecast_stockout(v_fc_id);

  -- Produk: BWP-500-19 (Bawang Putih Kating 500g) | model terbaik: moving_average
  insert into public.products (store_id, stock_code, name, unit, current_stock, reorder_threshold, is_monitored, is_active)
  values (v_store_id, 'BWP-500-19', 'Bawang Putih Kating 500g', 'bungkus', 248, 53, true, true)
  on conflict (store_id, stock_code) do update set
    name = excluded.name,
    unit = excluded.unit,
    current_stock = excluded.current_stock,
    reorder_threshold = excluded.reorder_threshold,
    is_active = true
  returning id into v_prod_id;

  -- Hapus prediksi lama untuk produk ini agar tidak duplikat
  delete from public.forecasts where product_id = v_prod_id;

  -- Buat baris header prediksi di forecasts
  insert into public.forecasts (store_id, product_id, ml_model_id, horizon_days, avg_daily_demand, generated_at)
  values (v_store_id, v_prod_id, v_model_id, 7, 17.71, now())
  returning id into v_fc_id;

  -- Masukkan rincian prediksi harian ke forecast_details
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-16', 17.71, 14.87, 20.56);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-17', 17.71, 14.87, 20.56);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-18', 17.71, 14.87, 20.56);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-19', 17.71, 14.87, 20.56);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-20', 17.71, 14.87, 20.56);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-21', 17.71, 14.87, 20.56);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-22', 17.71, 14.87, 20.56);
  -- Hitung otomatis kapan stok habis
  perform public.refresh_forecast_stockout(v_fc_id);

  -- Produk: DTR-800-14 (Deterjen Bubuk Pakaian 800g) | model terbaik: moving_average
  insert into public.products (store_id, stock_code, name, unit, current_stock, reorder_threshold, is_monitored, is_active)
  values (v_store_id, 'DTR-800-14', 'Deterjen Bubuk Pakaian 800g', 'pak', 16, 31, true, true)
  on conflict (store_id, stock_code) do update set
    name = excluded.name,
    unit = excluded.unit,
    current_stock = excluded.current_stock,
    reorder_threshold = excluded.reorder_threshold,
    is_active = true
  returning id into v_prod_id;

  -- Hapus prediksi lama untuk produk ini agar tidak duplikat
  delete from public.forecasts where product_id = v_prod_id;

  -- Buat baris header prediksi di forecasts
  insert into public.forecasts (store_id, product_id, ml_model_id, horizon_days, avg_daily_demand, generated_at)
  values (v_store_id, v_prod_id, v_model_id, 7, 10.29, now())
  returning id into v_fc_id;

  -- Masukkan rincian prediksi harian ke forecast_details
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-16', 10.29, 8.85, 11.72);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-17', 10.29, 8.85, 11.72);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-18', 10.29, 8.85, 11.72);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-19', 10.29, 8.85, 11.72);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-20', 10.29, 8.85, 11.72);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-21', 10.29, 8.85, 11.72);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-22', 10.29, 8.85, 11.72);
  -- Hitung otomatis kapan stok habis
  perform public.refresh_forecast_stockout(v_fc_id);

  -- Produk: GLP-1KG-02 (Gula Pasir Putih 1 kg) | model terbaik: sarima_trend
  insert into public.products (store_id, stock_code, name, unit, current_stock, reorder_threshold, is_monitored, is_active)
  values (v_store_id, 'GLP-1KG-02', 'Gula Pasir Putih 1 kg', 'kg', 32, 38, true, true)
  on conflict (store_id, stock_code) do update set
    name = excluded.name,
    unit = excluded.unit,
    current_stock = excluded.current_stock,
    reorder_threshold = excluded.reorder_threshold,
    is_active = true
  returning id into v_prod_id;

  -- Hapus prediksi lama untuk produk ini agar tidak duplikat
  delete from public.forecasts where product_id = v_prod_id;

  -- Buat baris header prediksi di forecasts
  insert into public.forecasts (store_id, product_id, ml_model_id, horizon_days, avg_daily_demand, generated_at)
  values (v_store_id, v_prod_id, v_model_id, 7, 12.59, now())
  returning id into v_fc_id;

  -- Masukkan rincian prediksi harian ke forecast_details
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-16', 8.99, 7.27, 10.7);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-17', 11.4, 9.69, 13.12);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-18', 11.46, 9.74, 13.18);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-19', 12.13, 10.42, 13.85);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-20', 13.94, 12.22, 15.66);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-21', 14.46, 12.74, 16.18);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-22', 15.73, 14.01, 17.44);
  -- Hitung otomatis kapan stok habis
  perform public.refresh_forecast_stockout(v_fc_id);

  -- Produk: GRM-500-10 (Garam Meja Beryodium 500g) | model terbaik: naive
  insert into public.products (store_id, stock_code, name, unit, current_stock, reorder_threshold, is_monitored, is_active)
  values (v_store_id, 'GRM-500-10', 'Garam Meja Beryodium 500g', 'bungkus', 186, 45, true, true)
  on conflict (store_id, stock_code) do update set
    name = excluded.name,
    unit = excluded.unit,
    current_stock = excluded.current_stock,
    reorder_threshold = excluded.reorder_threshold,
    is_active = true
  returning id into v_prod_id;

  -- Hapus prediksi lama untuk produk ini agar tidak duplikat
  delete from public.forecasts where product_id = v_prod_id;

  -- Buat baris header prediksi di forecasts
  insert into public.forecasts (store_id, product_id, ml_model_id, horizon_days, avg_daily_demand, generated_at)
  values (v_store_id, v_prod_id, v_model_id, 7, 15.0, now())
  returning id into v_fc_id;

  -- Masukkan rincian prediksi harian ke forecast_details
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-16', 15.0, 13.25, 16.75);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-17', 15.0, 13.25, 16.75);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-18', 15.0, 13.25, 16.75);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-19', 15.0, 13.25, 16.75);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-20', 15.0, 13.25, 16.75);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-21', 15.0, 13.25, 16.75);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-22', 15.0, 13.25, 16.75);
  -- Hitung otomatis kapan stok habis
  perform public.refresh_forecast_stockout(v_fc_id);

  -- Produk: KCP-600-08 (Kecap Manis Botol 600 ml) | model terbaik: sarima_trend
  insert into public.products (store_id, stock_code, name, unit, current_stock, reorder_threshold, is_monitored, is_active)
  values (v_store_id, 'KCP-600-08', 'Kecap Manis Botol 600 ml', 'botol', 226, 47, true, true)
  on conflict (store_id, stock_code) do update set
    name = excluded.name,
    unit = excluded.unit,
    current_stock = excluded.current_stock,
    reorder_threshold = excluded.reorder_threshold,
    is_active = true
  returning id into v_prod_id;

  -- Hapus prediksi lama untuk produk ini agar tidak duplikat
  delete from public.forecasts where product_id = v_prod_id;

  -- Buat baris header prediksi di forecasts
  insert into public.forecasts (store_id, product_id, ml_model_id, horizon_days, avg_daily_demand, generated_at)
  values (v_store_id, v_prod_id, v_model_id, 7, 15.51, now())
  returning id into v_fc_id;

  -- Masukkan rincian prediksi harian ke forecast_details
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-16', 11.37, 9.22, 13.52);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-17', 13.71, 11.56, 15.86);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-18', 14.19, 12.05, 16.34);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-19', 14.94, 12.79, 17.08);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-20', 16.86, 14.72, 19.01);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-21', 18.08, 15.93, 20.23);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-22', 19.43, 17.28, 21.57);
  -- Hitung otomatis kapan stok habis
  perform public.refresh_forecast_stockout(v_fc_id);

  -- Produk: KPI-RTG-07 (Kopi Bubuk Sachet (Renteng 10 Sachet)) | model terbaik: naive
  insert into public.products (store_id, stock_code, name, unit, current_stock, reorder_threshold, is_monitored, is_active)
  values (v_store_id, 'KPI-RTG-07', 'Kopi Bubuk Sachet (Renteng 10 Sachet)', 'renteng', 166, 42, true, true)
  on conflict (store_id, stock_code) do update set
    name = excluded.name,
    unit = excluded.unit,
    current_stock = excluded.current_stock,
    reorder_threshold = excluded.reorder_threshold,
    is_active = true
  returning id into v_prod_id;

  -- Hapus prediksi lama untuk produk ini agar tidak duplikat
  delete from public.forecasts where product_id = v_prod_id;

  -- Buat baris header prediksi di forecasts
  insert into public.forecasts (store_id, product_id, ml_model_id, horizon_days, avg_daily_demand, generated_at)
  values (v_store_id, v_prod_id, v_model_id, 7, 14.0, now())
  returning id into v_fc_id;

  -- Masukkan rincian prediksi harian ke forecast_details
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-16', 14.0, 12.75, 15.25);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-17', 14.0, 12.75, 15.25);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-18', 14.0, 12.75, 15.25);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-19', 14.0, 12.75, 15.25);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-20', 14.0, 12.75, 15.25);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-21', 14.0, 12.75, 15.25);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-22', 14.0, 12.75, 15.25);
  -- Hitung otomatis kapan stok habis
  perform public.refresh_forecast_stockout(v_fc_id);

  -- Produk: LPG-3KG-16 (Gas Elpiji 3 kg (Tabung Hijau)) | model terbaik: naive
  insert into public.products (store_id, stock_code, name, unit, current_stock, reorder_threshold, is_monitored, is_active)
  values (v_store_id, 'LPG-3KG-16', 'Gas Elpiji 3 kg (Tabung Hijau)', 'tabung', 22, 36, true, true)
  on conflict (store_id, stock_code) do update set
    name = excluded.name,
    unit = excluded.unit,
    current_stock = excluded.current_stock,
    reorder_threshold = excluded.reorder_threshold,
    is_active = true
  returning id into v_prod_id;

  -- Hapus prediksi lama untuk produk ini agar tidak duplikat
  delete from public.forecasts where product_id = v_prod_id;

  -- Buat baris header prediksi di forecasts
  insert into public.forecasts (store_id, product_id, ml_model_id, horizon_days, avg_daily_demand, generated_at)
  values (v_store_id, v_prod_id, v_model_id, 7, 12.0, now())
  returning id into v_fc_id;

  -- Masukkan rincian prediksi harian ke forecast_details
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-16', 12.0, 10.57, 13.43);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-17', 12.0, 10.57, 13.43);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-18', 12.0, 10.57, 13.43);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-19', 12.0, 10.57, 13.43);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-20', 12.0, 10.57, 13.43);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-21', 12.0, 10.57, 13.43);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-22', 12.0, 10.57, 13.43);
  -- Hitung otomatis kapan stok habis
  perform public.refresh_forecast_stockout(v_fc_id);

  -- Produk: MIG-PAK-03 (Mi Instan Goreng (Pak 5 Bks)) | model terbaik: sarima_trend
  insert into public.products (store_id, stock_code, name, unit, current_stock, reorder_threshold, is_monitored, is_active)
  values (v_store_id, 'MIG-PAK-03', 'Mi Instan Goreng (Pak 5 Bks)', 'pak', 342, 69, true, true)
  on conflict (store_id, stock_code) do update set
    name = excluded.name,
    unit = excluded.unit,
    current_stock = excluded.current_stock,
    reorder_threshold = excluded.reorder_threshold,
    is_active = true
  returning id into v_prod_id;

  -- Hapus prediksi lama untuk produk ini agar tidak duplikat
  delete from public.forecasts where product_id = v_prod_id;

  -- Buat baris header prediksi di forecasts
  insert into public.forecasts (store_id, product_id, ml_model_id, horizon_days, avg_daily_demand, generated_at)
  values (v_store_id, v_prod_id, v_model_id, 7, 23.03, now())
  returning id into v_fc_id;

  -- Masukkan rincian prediksi harian ke forecast_details
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-16', 15.98, 12.77, 19.18);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-17', 21.42, 18.22, 24.62);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-18', 20.23, 17.03, 23.44);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-19', 23.53, 20.33, 26.73);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-20', 24.88, 21.68, 28.09);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-21', 26.87, 23.67, 30.07);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-22', 28.29, 25.08, 31.49);
  -- Hitung otomatis kapan stok habis
  perform public.refresh_forecast_stockout(v_fc_id);

  -- Produk: MKS-2L-01 (Minyak Goreng Sania 2L) | model terbaik: sarima_trend
  insert into public.products (store_id, stock_code, name, unit, current_stock, reorder_threshold, is_monitored, is_active)
  values (v_store_id, 'MKS-2L-01', 'Minyak Goreng Sania 2L', 'botol', 0, 64, true, true)
  on conflict (store_id, stock_code) do update set
    name = excluded.name,
    unit = excluded.unit,
    current_stock = excluded.current_stock,
    reorder_threshold = excluded.reorder_threshold,
    is_active = true
  returning id into v_prod_id;

  -- Hapus prediksi lama untuk produk ini agar tidak duplikat
  delete from public.forecasts where product_id = v_prod_id;

  -- Buat baris header prediksi di forecasts
  insert into public.forecasts (store_id, product_id, ml_model_id, horizon_days, avg_daily_demand, generated_at)
  values (v_store_id, v_prod_id, v_model_id, 7, 21.21, now())
  returning id into v_fc_id;

  -- Masukkan rincian prediksi harian ke forecast_details
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-16', 16.59, 14.38, 18.79);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-17', 19.16, 16.95, 21.37);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-18', 19.85, 17.64, 22.06);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-19', 21.88, 19.67, 24.09);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-20', 21.63, 19.42, 23.84);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-21', 24.18, 21.97, 26.39);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-22', 25.19, 22.98, 27.4);
  -- Hitung otomatis kapan stok habis
  perform public.refresh_forecast_stockout(v_fc_id);

  -- Produk: MRG-200-11 (Margarin Serbaguna Sachet 200g) | model terbaik: naive
  insert into public.products (store_id, stock_code, name, unit, current_stock, reorder_threshold, is_monitored, is_active)
  values (v_store_id, 'MRG-200-11', 'Margarin Serbaguna Sachet 200g', 'bungkus', 308, 78, true, true)
  on conflict (store_id, stock_code) do update set
    name = excluded.name,
    unit = excluded.unit,
    current_stock = excluded.current_stock,
    reorder_threshold = excluded.reorder_threshold,
    is_active = true
  returning id into v_prod_id;

  -- Hapus prediksi lama untuk produk ini agar tidak duplikat
  delete from public.forecasts where product_id = v_prod_id;

  -- Buat baris header prediksi di forecasts
  insert into public.forecasts (store_id, product_id, ml_model_id, horizon_days, avg_daily_demand, generated_at)
  values (v_store_id, v_prod_id, v_model_id, 7, 26.0, now())
  returning id into v_fc_id;

  -- Masukkan rincian prediksi harian ke forecast_details
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-16', 26.0, 23.39, 28.61);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-17', 26.0, 23.39, 28.61);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-18', 26.0, 23.39, 28.61);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-19', 26.0, 23.39, 28.61);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-20', 26.0, 23.39, 28.61);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-21', 26.0, 23.39, 28.61);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-22', 26.0, 23.39, 28.61);
  -- Hitung otomatis kapan stok habis
  perform public.refresh_forecast_stockout(v_fc_id);

  -- Produk: RTI-TWR-17 (Roti Tawar Kupas Spesial) | model terbaik: naive
  insert into public.products (store_id, stock_code, name, unit, current_stock, reorder_threshold, is_monitored, is_active)
  values (v_store_id, 'RTI-TWR-17', 'Roti Tawar Kupas Spesial', 'pcs', 204, 48, true, true)
  on conflict (store_id, stock_code) do update set
    name = excluded.name,
    unit = excluded.unit,
    current_stock = excluded.current_stock,
    reorder_threshold = excluded.reorder_threshold,
    is_active = true
  returning id into v_prod_id;

  -- Hapus prediksi lama untuk produk ini agar tidak duplikat
  delete from public.forecasts where product_id = v_prod_id;

  -- Buat baris header prediksi di forecasts
  insert into public.forecasts (store_id, product_id, ml_model_id, horizon_days, avg_daily_demand, generated_at)
  values (v_store_id, v_prod_id, v_model_id, 7, 16.0, now())
  returning id into v_fc_id;

  -- Masukkan rincian prediksi harian ke forecast_details
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-16', 16.0, 13.68, 18.32);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-17', 16.0, 13.68, 18.32);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-18', 16.0, 13.68, 18.32);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-19', 16.0, 13.68, 18.32);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-20', 16.0, 13.68, 18.32);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-21', 16.0, 13.68, 18.32);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-22', 16.0, 13.68, 18.32);
  -- Hitung otomatis kapan stok habis
  perform public.refresh_forecast_stockout(v_fc_id);

  -- Produk: SBN-750-13 (Sabun Cuci Piring Jeruk Nipis 750 ml) | model terbaik: naive
  insert into public.products (store_id, stock_code, name, unit, current_stock, reorder_threshold, is_monitored, is_active)
  values (v_store_id, 'SBN-750-13', 'Sabun Cuci Piring Jeruk Nipis 750 ml', 'botol', 182, 42, true, true)
  on conflict (store_id, stock_code) do update set
    name = excluded.name,
    unit = excluded.unit,
    current_stock = excluded.current_stock,
    reorder_threshold = excluded.reorder_threshold,
    is_active = true
  returning id into v_prod_id;

  -- Hapus prediksi lama untuk produk ini agar tidak duplikat
  delete from public.forecasts where product_id = v_prod_id;

  -- Buat baris header prediksi di forecasts
  insert into public.forecasts (store_id, product_id, ml_model_id, horizon_days, avg_daily_demand, generated_at)
  values (v_store_id, v_prod_id, v_model_id, 7, 14.0, now())
  returning id into v_fc_id;

  -- Masukkan rincian prediksi harian ke forecast_details
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-16', 14.0, 12.14, 15.86);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-17', 14.0, 12.14, 15.86);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-18', 14.0, 12.14, 15.86);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-19', 14.0, 12.14, 15.86);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-20', 14.0, 12.14, 15.86);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-21', 14.0, 12.14, 15.86);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-22', 14.0, 12.14, 15.86);
  -- Hitung otomatis kapan stok habis
  perform public.refresh_forecast_stockout(v_fc_id);

  -- Produk: SKM-KLG-09 (Susu Kental Manis Putih 370g) | model terbaik: naive
  insert into public.products (store_id, stock_code, name, unit, current_stock, reorder_threshold, is_monitored, is_active)
  values (v_store_id, 'SKM-KLG-09', 'Susu Kental Manis Putih 370g', 'bungkus', 48, 63, true, true)
  on conflict (store_id, stock_code) do update set
    name = excluded.name,
    unit = excluded.unit,
    current_stock = excluded.current_stock,
    reorder_threshold = excluded.reorder_threshold,
    is_active = true
  returning id into v_prod_id;

  -- Hapus prediksi lama untuk produk ini agar tidak duplikat
  delete from public.forecasts where product_id = v_prod_id;

  -- Buat baris header prediksi di forecasts
  insert into public.forecasts (store_id, product_id, ml_model_id, horizon_days, avg_daily_demand, generated_at)
  values (v_store_id, v_prod_id, v_model_id, 7, 21.0, now())
  returning id into v_fc_id;

  -- Masukkan rincian prediksi harian ke forecast_details
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-16', 21.0, 18.89, 23.11);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-17', 21.0, 18.89, 23.11);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-18', 21.0, 18.89, 23.11);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-19', 21.0, 18.89, 23.11);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-20', 21.0, 18.89, 23.11);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-21', 21.0, 18.89, 23.11);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-22', 21.0, 18.89, 23.11);
  -- Hitung otomatis kapan stok habis
  perform public.refresh_forecast_stockout(v_fc_id);

  -- Produk: SRD-425-12 (Sarden Saus Tomat Kaleng 425g) | model terbaik: naive
  insert into public.products (store_id, stock_code, name, unit, current_stock, reorder_threshold, is_monitored, is_active)
  values (v_store_id, 'SRD-425-12', 'Sarden Saus Tomat Kaleng 425g', 'kaleng', 228, 57, true, true)
  on conflict (store_id, stock_code) do update set
    name = excluded.name,
    unit = excluded.unit,
    current_stock = excluded.current_stock,
    reorder_threshold = excluded.reorder_threshold,
    is_active = true
  returning id into v_prod_id;

  -- Hapus prediksi lama untuk produk ini agar tidak duplikat
  delete from public.forecasts where product_id = v_prod_id;

  -- Buat baris header prediksi di forecasts
  insert into public.forecasts (store_id, product_id, ml_model_id, horizon_days, avg_daily_demand, generated_at)
  values (v_store_id, v_prod_id, v_model_id, 7, 19.0, now())
  returning id into v_fc_id;

  -- Masukkan rincian prediksi harian ke forecast_details
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-16', 19.0, 16.71, 21.29);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-17', 19.0, 16.71, 21.29);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-18', 19.0, 16.71, 21.29);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-19', 19.0, 16.71, 21.29);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-20', 19.0, 16.71, 21.29);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-21', 19.0, 16.71, 21.29);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-22', 19.0, 16.71, 21.29);
  -- Hitung otomatis kapan stok habis
  perform public.refresh_forecast_stockout(v_fc_id);

  -- Produk: TEH-KTK-08 (Teh Celup Melati (Kotak 25 Kantong)) | model terbaik: naive
  insert into public.products (store_id, stock_code, name, unit, current_stock, reorder_threshold, is_monitored, is_active)
  values (v_store_id, 'TEH-KTK-08', 'Teh Celup Melati (Kotak 25 Kantong)', 'kotak', 116, 33, true, true)
  on conflict (store_id, stock_code) do update set
    name = excluded.name,
    unit = excluded.unit,
    current_stock = excluded.current_stock,
    reorder_threshold = excluded.reorder_threshold,
    is_active = true
  returning id into v_prod_id;

  -- Hapus prediksi lama untuk produk ini agar tidak duplikat
  delete from public.forecasts where product_id = v_prod_id;

  -- Buat baris header prediksi di forecasts
  insert into public.forecasts (store_id, product_id, ml_model_id, horizon_days, avg_daily_demand, generated_at)
  values (v_store_id, v_prod_id, v_model_id, 7, 11.0, now())
  returning id into v_fc_id;

  -- Masukkan rincian prediksi harian ke forecast_details
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-16', 11.0, 10.11, 11.89);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-17', 11.0, 10.11, 11.89);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-18', 11.0, 10.11, 11.89);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-19', 11.0, 10.11, 11.89);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-20', 11.0, 10.11, 11.89);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-21', 11.0, 10.11, 11.89);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-22', 11.0, 10.11, 11.89);
  -- Hitung otomatis kapan stok habis
  perform public.refresh_forecast_stockout(v_fc_id);

  -- Produk: TLR-1KG-05 (Telur Ayam Negeri 1 kg) | model terbaik: sarima_trend
  insert into public.products (store_id, stock_code, name, unit, current_stock, reorder_threshold, is_monitored, is_active)
  values (v_store_id, 'TLR-1KG-05', 'Telur Ayam Negeri 1 kg', 'kg', 37, 67, true, true)
  on conflict (store_id, stock_code) do update set
    name = excluded.name,
    unit = excluded.unit,
    current_stock = excluded.current_stock,
    reorder_threshold = excluded.reorder_threshold,
    is_active = true
  returning id into v_prod_id;

  -- Hapus prediksi lama untuk produk ini agar tidak duplikat
  delete from public.forecasts where product_id = v_prod_id;

  -- Buat baris header prediksi di forecasts
  insert into public.forecasts (store_id, product_id, ml_model_id, horizon_days, avg_daily_demand, generated_at)
  values (v_store_id, v_prod_id, v_model_id, 7, 22.27, now())
  returning id into v_fc_id;

  -- Masukkan rincian prediksi harian ke forecast_details
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-16', 16.32, 12.81, 19.84);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-17', 21.04, 17.52, 24.56);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-18', 20.23, 16.72, 23.75);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-19', 21.78, 18.26, 25.29);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-20', 23.38, 19.86, 26.89);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-21', 25.17, 21.66, 28.69);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-22', 27.96, 24.44, 31.47);
  -- Hitung otomatis kapan stok habis
  perform public.refresh_forecast_stockout(v_fc_id);

  -- Produk: TPG-1KG-06 (Tepung Terigu Protein Sedang 1 kg) | model terbaik: sarima_trend
  insert into public.products (store_id, stock_code, name, unit, current_stock, reorder_threshold, is_monitored, is_active)
  values (v_store_id, 'TPG-1KG-06', 'Tepung Terigu Protein Sedang 1 kg', 'kg', 272, 58, true, true)
  on conflict (store_id, stock_code) do update set
    name = excluded.name,
    unit = excluded.unit,
    current_stock = excluded.current_stock,
    reorder_threshold = excluded.reorder_threshold,
    is_active = true
  returning id into v_prod_id;

  -- Hapus prediksi lama untuk produk ini agar tidak duplikat
  delete from public.forecasts where product_id = v_prod_id;

  -- Buat baris header prediksi di forecasts
  insert into public.forecasts (store_id, product_id, ml_model_id, horizon_days, avg_daily_demand, generated_at)
  values (v_store_id, v_prod_id, v_model_id, 7, 19.34, now())
  returning id into v_fc_id;

  -- Masukkan rincian prediksi harian ke forecast_details
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-16', 13.85, 10.65, 17.05);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-17', 17.23, 14.03, 20.44);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-18', 16.68, 13.48, 19.89);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-19', 19.6, 16.4, 22.81);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-20', 21.17, 17.97, 24.38);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-21', 22.59, 19.39, 25.8);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-22', 24.22, 21.01, 27.42);
  -- Hitung otomatis kapan stok habis
  perform public.refresh_forecast_stockout(v_fc_id);

  raise notice 'Sinkronisasi 20 produk prediksi ML ke Supabase berhasil diselesaikan!';
end $$;
