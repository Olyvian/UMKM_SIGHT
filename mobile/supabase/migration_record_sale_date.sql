-- =============================================================================
-- UMKM Sight - MIGRASI: tanggal transaksi pada RPC record_sale
-- (Supabase / PostgreSQL)
--
-- MASALAH
--   schema_Inventoris.sql mendefinisikan
--     public.record_sale(p_items jsonb, p_note text)
--   sehingga penjualan SELALU dicatat pada waktu server (now()). Padahal
--   formulir "Catat Penjualan" di aplikasi membiarkan pengguna memilih
--   tanggal & jam transaksi (mis. penjualan kemarin yang lupa dicatat).
--
-- YANG DILAKUKAN SKRIP INI
--   1. Menghapus fungsi lama record_sale(jsonb, text).
--   2. Membuat ulang dengan parameter ketiga opsional p_transaction_date.
--   3. Menolak tanggal di masa depan (deret waktu penjualan jadi rusak
--      kalau ada transaksi bertanggal besok).
--   4. Mengatur ulang hak akses (fungsi baru = signature baru).
--
-- CATATAN
--   * Skrip ini idempoten: aman dijalankan berulang.
--   * Memanggil record_sale TANPA p_transaction_date tetap berperilaku
--     seperti sebelumnya (now()).
--   * Aplikasi versi lama yang memanggil 2 parameter tetap berfungsi,
--     karena p_transaction_date punya nilai default.
--   * KAPAN SKRIP INI DIPERLUKAN?
--       - Database yang sudah menjalankan schema_Inventoris.sql versi LAMA
--         (fungsi record_sale masih 2 parameter). Jalankan sekali saja.
--       - Untuk instalasi baru TIDAK PERLU: schema_Inventoris.sql versi
--         terbaru sudah memuat fungsi 3 parameter ini.
--   * schema_Inventoris.sql versi terbaru sudah memuat
--     "drop function if exists public.record_sale(jsonb, text);" sehingga
--     menjalankannya ulang tidak lagi memunculkan overload. Skrip ini tetap
--     disimpan untuk database yang sudah terlanjur memakai versi lama.
--
-- Cara pakai: Supabase > SQL Editor > New query > tempel seluruh isi file
-- > Run.
-- =============================================================================

-- 1. Hapus fungsi lama. Tanpa langkah ini, PostgreSQL menyimpan keduanya
--    sebagai overload dan PostgREST tidak bisa memilih mana yang dipakai
--    (error "Could not choose the best candidate function").
drop function if exists public.record_sale(jsonb, text);

-- 2. Fungsi baru.
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
  v_store uuid := public.my_store_id();
  v_date  timestamptz := coalesce(p_transaction_date, now());
  v_tx    uuid;
  v_item  jsonb;
  v_prod  public.products;
  v_qty   integer;
  v_price numeric;
  v_total numeric := 0;
begin
  if v_store is null then
    raise exception 'NO_STORE' using errcode = '42501';
  end if;

  if p_items is null
     or jsonb_typeof(p_items) <> 'array'
     or jsonb_array_length(p_items) = 0 then
    raise exception 'EMPTY_ITEMS' using errcode = '22023';
  end if;

  -- Toleransi 5 menit untuk selisih jam perangkat dengan jam server.
  if v_date > now() + interval '5 minutes' then
    raise exception 'INVALID_DATE' using errcode = '22023';
  end if;

  insert into public.transactions
    (store_id, invoice_no, transaction_type, transaction_date, note)
  values
    (v_store, public.next_invoice_no(), 'SALE', v_date, p_note)
  returning id into v_tx;

  for v_item in select * from jsonb_array_elements(p_items) loop
    v_qty := (v_item ->> 'quantity')::integer;
    if v_qty is null or v_qty <= 0 then
      raise exception 'INVALID_QUANTITY' using errcode = '22023';
    end if;

    select * into v_prod
    from public.products
    where id = (v_item ->> 'product_id')::uuid
      and store_id = v_store
      and is_active
    for update;                       -- kunci baris: aman dari penjualan bersamaan
    if not found then
      raise exception 'PRODUCT_NOT_FOUND' using errcode = 'P0002';
    end if;

    if v_prod.current_stock < v_qty then
      raise exception 'INSUFFICIENT_STOCK' using errcode = 'P0001',
        detail = format('%s: sisa %s %s, diminta %s',
                        v_prod.name, v_prod.current_stock, v_prod.unit, v_qty);
    end if;

    v_price := coalesce((v_item ->> 'unit_price')::numeric, v_prod.unit_price);

    update public.products
    set current_stock = current_stock - v_qty
    where id = v_prod.id;

    insert into public.transaction_items
      (transaction_id, store_id, product_id, quantity, unit_price)
    values
      (v_tx, v_store, v_prod.id, v_qty, v_price);

    -- created_at diisi dengan tanggal transaksi agar riwayat mutasi stok
    -- (bagian "Aktivitas Terbaru" di beranda) urut konsisten.
    insert into public.stock_movements
      (store_id, product_id, transaction_id, movement_type,
       quantity, stock_before, stock_after, note, created_at)
    values
      (v_store, v_prod.id, v_tx, 'OUT', v_qty,
       v_prod.current_stock, v_prod.current_stock - v_qty, p_note, v_date);

    v_total := v_total + v_qty * v_price;
    perform public._notify_stock(v_prod.id);
  end loop;

  update public.transactions set total_amount = v_total where id = v_tx;
  return v_tx;
end;
$$;

-- 3. Hak akses: signature berubah, jadi grant lama (yang ikut terhapus
--    bersama fungsi lama) harus dibuat ulang.
revoke all on function public.record_sale(jsonb, text, timestamptz)
  from public, anon;
grant execute on function public.record_sale(jsonb, text, timestamptz)
  to authenticated;

-- =============================================================================
-- VERIFIKASI (jalankan terpisah setelah migrasi)
-- =============================================================================
--   select p.proname, pg_get_function_arguments(p.oid) as argumen
--   from pg_proc p
--   join pg_namespace n on n.oid = p.pronamespace
--   where n.nspname = 'public' and p.proname = 'record_sale';
--   -- harus tepat SATU baris:
--   --   record_sale | p_items jsonb, p_note text DEFAULT NULL::text,
--   --                 p_transaction_date timestamp with time zone DEFAULT NULL::timestamp with time zone
-- =============================================================================
