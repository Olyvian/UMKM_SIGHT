-- =============================================================================
-- UMKM Sight - data & query untuk menguji LOGIN (jalankan di SQL Editor)
--
-- HANYA untuk project pengembangan/uji, jangan di produksi.
-- Prasyarat: supabase/schema.sql sudah dijalankan.
-- Semua akun uji memakai kata sandi:  Abcd#1234
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 1) BUAT AKUN UJI (aman dijalankan ulang; akun yang sudah ada dilewati)
--    Trigger handle_new_user otomatis membuat baris profiles & stores
--    dari raw_user_meta_data (name, store_name).
-- -----------------------------------------------------------------------------
do $$
declare
  r   record;
  uid uuid;
begin
  for r in
    select * from (values
      ('budi@tokoberkah.com',             'Budi Santoso', 'Toko Berkah Jaya',  true),
      ('siti@tokoberkah.com',             'Siti Aminah',  'Toko Siti Makmur',  true),
      ('belum.verifikasi@tokoberkah.com', 'Rani Putri',   'Toko Rani',         false)
    ) as t(email, full_name, store_name, confirmed)
  loop
    if exists (select 1 from auth.users where email = r.email) then
      continue;
    end if;

    uid := gen_random_uuid();

    insert into auth.users (
      instance_id, id, aud, role, email, encrypted_password,
      email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
      created_at, updated_at,
      confirmation_token, recovery_token, email_change, email_change_token_new
    ) values (
      '00000000-0000-0000-0000-000000000000', uid, 'authenticated', 'authenticated',
      r.email, extensions.crypt('Abcd#1234', extensions.gen_salt('bf')),
      case when r.confirmed then now() else null end,
      '{"provider":"email","providers":["email"]}'::jsonb,
      jsonb_build_object('name', r.full_name, 'store_name', r.store_name),
      now(), now(),
      '', '', '', ''          -- harus string kosong (bukan NULL) agar login tidak error
    );

    insert into auth.identities (
      id, user_id, provider_id, identity_data, provider,
      last_sign_in_at, created_at, updated_at
    ) values (
      gen_random_uuid(), uid, uid::text,
      jsonb_build_object('sub', uid::text, 'email', r.email, 'email_verified', r.confirmed),
      'email', now(), now(), now()
    );
  end loop;
end $$;


-- -----------------------------------------------------------------------------
-- 2) VERIFIKASI DATA AKUN UJI
--    Harapan: 3 baris; profiles & stores terisi; verified = false hanya
--    untuk belum.verifikasi@tokoberkah.com.
-- -----------------------------------------------------------------------------
select
  u.email,
  u.email_confirmed_at is not null as verified,
  p.name,
  p.role,
  p.is_active,
  s.store_name
from auth.users u
left join public.profiles p on p.id = u.id
left join public.stores   s on s.user_id = u.id
where u.email like '%@tokoberkah.com'
order by u.email;


-- -----------------------------------------------------------------------------
-- 3) CEK KOMPONEN YANG DIBUTUHKAN LOGIN
-- -----------------------------------------------------------------------------
-- 3a. Trigger pendaftaran ada (harapan: 1 baris on_auth_user_created)
select tgname from pg_trigger
where tgname = 'on_auth_user_created' and not tgisinternal;

-- 3b. RLS aktif di kedua tabel (harapan: rls_enabled = true)
select relname as tabel, relrowsecurity as rls_enabled
from pg_class
where oid in ('public.profiles'::regclass, 'public.stores'::regclass);

-- 3c. Daftar policy (harapan: 4 baris: profiles_select/update_own, stores_select/update_own)
select tablename, policyname, cmd
from pg_policies
where schemaname = 'public' and tablename in ('profiles', 'stores')
order by tablename, policyname;

-- 3d. Akun tanpa profil/toko (harapan: 0 baris)
select u.email
from auth.users u
left join public.profiles p on p.id = u.id
left join public.stores   s on s.user_id = u.id
where p.id is null or s.id is null;


-- -----------------------------------------------------------------------------
-- 4) UJI RLS: simulasikan pengguna "budi" yang sudah login
--    Harapan: tiap select hanya mengembalikan 1 baris (milik budi sendiri),
--    dan update role ditolak ("permission denied").
--    Dibungkus transaksi + rollback sehingga tidak mengubah data.
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

  select 'profiles terlihat' as cek, count(*) as jumlah from public.profiles;  -- 1
  select 'stores terlihat'   as cek, count(*) as jumlah from public.stores;    -- 1

  -- Percobaan menaikkan diri menjadi ADMIN harus gagal:
  -- (hapus tanda komentar untuk mencoba; transaksi akan error lalu di-rollback)
  -- update public.profiles set role = 'ADMIN';
rollback;


-- -----------------------------------------------------------------------------
-- 5) PEMBERSIHAN: hapus akun uji (profiles, stores, identities ikut terhapus)
-- -----------------------------------------------------------------------------
-- delete from auth.users where email like '%@tokoberkah.com';