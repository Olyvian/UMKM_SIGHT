-- =============================================================================
-- UMKM Sight: SINKRONISASI HASIL PERAMALAN ARIMA KE DATABASE SUPABASE
-- Dihasilkan secara otomatis pada: 2026-11-16T15:18:31.524090+00:00
--
-- Skrip ini memasukkan:
--   1. Metadata Model ML: SARIMA (orde (1,0,1)(0,0,1,7), MAPE ~14-15%)
--   2. Produk-produk toko (bila belum ada)
--   3. Prediksi deret waktu 7 hari ke depan (forecasts & forecast_details)
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

  -- 2. Daftarkan / perbarui model SARIMA di tabel ml_models
  insert into public.ml_models (name, version, algorithm, mape, rmse, mae, is_active, trained_at)
  values ('SARIMA-Sembako', '1.0.0', 'SARIMA', 14.80, 1.98, 1.52, true, now())
  on conflict (name, version) do update set
    algorithm = excluded.algorithm,
    mape = excluded.mape,
    rmse = excluded.rmse,
    mae = excluded.mae,
    is_active = true,
    trained_at = now()
  returning id into v_model_id;

  -- Produk: BRS-5KG-04 (Beras Premium 5 kg)
  insert into public.products (store_id, stock_code, name, unit, current_stock, reorder_threshold, is_monitored, is_active)
  values (v_store_id, 'BRS-5KG-04', 'Beras Premium 5 kg', 'karung', 29, 15, true, true)
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
  values (v_store_id, v_prod_id, v_model_id, 7, 14.2, now())
  returning id into v_fc_id;

  -- Masukkan rincian prediksi 7 hari ke depan ke forecast_details
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-17', 12.3, 10.46, 14.14);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-18', 15.4, 13.09, 17.71);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-19', 14.5, 12.32, 16.67);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-20', 13.8, 11.73, 15.87);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-21', 16.2, 13.77, 18.63);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-22', 17.5, 14.88, 20.12);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-23', 18.1, 15.39, 20.82);
  -- Hitung otomatis kapan stok habis
  perform public.refresh_forecast_stockout(v_fc_id);

  -- Produk: MKS-2L-01 (Minyak Goreng 2L)
  insert into public.products (store_id, stock_code, name, unit, current_stock, reorder_threshold, is_monitored, is_active)
  values (v_store_id, 'MKS-2L-01', 'Minyak Goreng 2L', 'botol', 0, 12, true, true)
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
  values (v_store_id, v_prod_id, v_model_id, 7, 18.5, now())
  returning id into v_fc_id;

  -- Masukkan rincian prediksi 7 hari ke depan ke forecast_details
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-17', 16.1, 13.69, 18.52);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-18', 17.0, 14.45, 19.55);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-19', 18.2, 15.47, 20.93);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-20', 18.5, 15.72, 21.27);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-21', 20.1, 17.09, 23.11);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-22', 22.4, 19.04, 25.76);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-23', 23.0, 19.55, 26.45);
  -- Hitung otomatis kapan stok habis
  perform public.refresh_forecast_stockout(v_fc_id);

  -- Produk: GLP-1KG-02 (Gula Pasir 1 kg)
  insert into public.products (store_id, stock_code, name, unit, current_stock, reorder_threshold, is_monitored, is_active)
  values (v_store_id, 'GLP-1KG-02', 'Gula Pasir 1 kg', 'kg', 32, 20, true, true)
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
  values (v_store_id, v_prod_id, v_model_id, 7, 8.4, now())
  returning id into v_fc_id;

  -- Masukkan rincian prediksi 7 hari ke depan ke forecast_details
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-17', 7.8, 6.63, 8.97);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-18', 8.1, 6.88, 9.31);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-19', 8.5, 7.22, 9.77);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-20', 8.2, 6.97, 9.43);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-21', 9.3, 7.91, 10.7);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-22', 10.1, 8.58, 11.61);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-23', 10.5, 8.92, 12.07);
  -- Hitung otomatis kapan stok habis
  perform public.refresh_forecast_stockout(v_fc_id);

  -- Produk: TLR-1KG-05 (Telur Ayam 1 kg)
  insert into public.products (store_id, stock_code, name, unit, current_stock, reorder_threshold, is_monitored, is_active)
  values (v_store_id, 'TLR-1KG-05', 'Telur Ayam 1 kg', 'kg', 37, 25, true, true)
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
  values (v_store_id, v_prod_id, v_model_id, 7, 19.1, now())
  returning id into v_fc_id;

  -- Masukkan rincian prediksi 7 hari ke depan ke forecast_details
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-17', 17.5, 14.88, 20.12);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-18', 18.2, 15.47, 20.93);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-19', 18.9, 16.06, 21.73);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-20', 19.4, 16.49, 22.31);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-21', 21.0, 17.85, 24.15);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-22', 23.5, 19.97, 27.02);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-23', 24.1, 20.48, 27.71);
  -- Hitung otomatis kapan stok habis
  perform public.refresh_forecast_stockout(v_fc_id);

  -- Produk: LPG-3KG-16 (Gas Elpiji 3 kg)
  insert into public.products (store_id, stock_code, name, unit, current_stock, reorder_threshold, is_monitored, is_active)
  values (v_store_id, 'LPG-3KG-16', 'Gas Elpiji 3 kg', 'tabung', 22, 10, true, true)
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
  values (v_store_id, v_prod_id, v_model_id, 7, 11.2, now())
  returning id into v_fc_id;

  -- Masukkan rincian prediksi 7 hari ke depan ke forecast_details
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-17', 10.2, 8.67, 11.73);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-18', 10.8, 9.18, 12.42);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-19', 11.0, 9.35, 12.65);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-20', 11.5, 9.78, 13.22);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-21', 12.3, 10.46, 14.14);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-22', 13.1, 11.13, 15.06);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-23', 13.5, 11.47, 15.52);
  -- Hitung otomatis kapan stok habis
  perform public.refresh_forecast_stockout(v_fc_id);

  -- Produk: DTR-800-14 (Deterjen Bubuk 800g)
  insert into public.products (store_id, stock_code, name, unit, current_stock, reorder_threshold, is_monitored, is_active)
  values (v_store_id, 'DTR-800-14', 'Deterjen Bubuk 800g', 'bungkus', 16, 12, true, true)
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
  values (v_store_id, v_prod_id, v_model_id, 7, 8.1, now())
  returning id into v_fc_id;

  -- Masukkan rincian prediksi 7 hari ke depan ke forecast_details
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-17', 7.1, 6.03, 8.16);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-18', 7.5, 6.38, 8.62);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-19', 8.0, 6.8, 9.2);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-20', 8.2, 6.97, 9.43);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-21', 8.9, 7.57, 10.23);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-22', 9.8, 8.33, 11.27);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-23', 10.0, 8.5, 11.5);
  -- Hitung otomatis kapan stok habis
  perform public.refresh_forecast_stockout(v_fc_id);

  -- Produk: SKM-KLG-09 (Susu Kental Manis 370g)
  insert into public.products (store_id, stock_code, name, unit, current_stock, reorder_threshold, is_monitored, is_active)
  values (v_store_id, 'SKM-KLG-09', 'Susu Kental Manis 370g', 'kaleng', 48, 20, true, true)
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

  -- Masukkan rincian prediksi 7 hari ke depan ke forecast_details
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-17', 14.5, 12.32, 16.67);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-18', 15.2, 12.92, 17.48);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-19', 15.9, 13.52, 18.29);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-20', 16.1, 13.69, 18.52);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-21', 17.8, 15.13, 20.47);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-22', 19.2, 16.32, 22.08);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-23', 19.8, 16.83, 22.77);
  -- Hitung otomatis kapan stok habis
  perform public.refresh_forecast_stockout(v_fc_id);

  -- Produk: KPI-RTG-07 (Kopi Sachet Renceng)
  insert into public.products (store_id, stock_code, name, unit, current_stock, reorder_threshold, is_monitored, is_active)
  values (v_store_id, 'KPI-RTG-07', 'Kopi Sachet Renceng', 'renceng', 140, 30, true, true)
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
  values (v_store_id, v_prod_id, v_model_id, 7, 24.5, now())
  returning id into v_fc_id;

  -- Masukkan rincian prediksi 7 hari ke depan ke forecast_details
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-17', 22.0, 18.7, 25.3);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-18', 23.1, 19.64, 26.57);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-19', 24.0, 20.4, 27.6);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-20', 24.8, 21.08, 28.52);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-21', 27.2, 23.12, 31.28);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-22', 29.5, 25.07, 33.92);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-23', 30.1, 25.59, 34.62);
  -- Hitung otomatis kapan stok habis
  perform public.refresh_forecast_stockout(v_fc_id);

  -- Produk: MIE-GRG-11 (Mi Instan Goreng)
  insert into public.products (store_id, stock_code, name, unit, current_stock, reorder_threshold, is_monitored, is_active)
  values (v_store_id, 'MIE-GRG-11', 'Mi Instan Goreng', 'dus', 85, 20, true, true)
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
  values (v_store_id, v_prod_id, v_model_id, 7, 12.5, now())
  returning id into v_fc_id;

  -- Masukkan rincian prediksi 7 hari ke depan ke forecast_details
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-17', 11.2, 9.52, 12.88);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-18', 11.9, 10.12, 13.68);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-19', 12.4, 10.54, 14.26);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-20', 12.8, 10.88, 14.72);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-21', 14.1, 11.98, 16.21);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-22', 15.5, 13.17, 17.82);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-23', 16.0, 13.6, 18.4);
  -- Hitung otomatis kapan stok habis
  perform public.refresh_forecast_stockout(v_fc_id);

  -- Produk: TPG-1KG-03 (Tepung Terigu 1 kg)
  insert into public.products (store_id, stock_code, name, unit, current_stock, reorder_threshold, is_monitored, is_active)
  values (v_store_id, 'TPG-1KG-03', 'Tepung Terigu 1 kg', 'kg', 60, 20, true, true)
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
  values (v_store_id, v_prod_id, v_model_id, 7, 9.8, now())
  returning id into v_fc_id;

  -- Masukkan rincian prediksi 7 hari ke depan ke forecast_details
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-17', 8.9, 7.57, 10.23);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-18', 9.2, 7.82, 10.58);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-19', 9.7, 8.24, 11.15);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-20', 10.1, 8.58, 11.61);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-21', 11.2, 9.52, 12.88);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-22', 12.0, 10.2, 13.8);
  insert into public.forecast_details (forecast_id, store_id, forecast_date, predicted_qty, lower_bound, upper_bound) values (v_fc_id, v_store_id, '2026-11-23', 12.5, 10.62, 14.37);
  -- Hitung otomatis kapan stok habis
  perform public.refresh_forecast_stockout(v_fc_id);

  raise notice 'Sinkronisasi prediksi ML ke Supabase berhasil diselesaikan!';
end $$;