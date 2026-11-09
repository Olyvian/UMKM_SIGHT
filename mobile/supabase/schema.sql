-- =============================================================================
-- UMKM Sight - skema awal autentikasi & profil toko (Supabase / PostgreSQL)
--
-- Cara pakai: buka dashboard Supabase > SQL Editor > New query, tempel seluruh
-- isi file ini, lalu Run. Aman dijalankan ulang (idempoten).
--
-- Catatan desain:
--  * Email & kata sandi disimpan oleh Supabase Auth di auth.users (kata sandi
--    di-hash otomatis), jadi tidak ada kolom password di tabel kita.
--  * profiles ~ tabel USERS pada ERD; id memakai UUID yang sama dengan
--    auth.users.id (bukan bigint).
--  * stores = satu toko per akun (user_id unik), sesuai asumsi README.
--  * Baris profiles & stores dibuat otomatis oleh trigger saat pendaftaran,
--    dari data name & store_name yang dikirim aplikasi.
--  * Row Level Security (RLS) aktif: pengguna hanya bisa membaca/mengubah
--    datanya sendiri. Kolom role TIDAK bisa diubah dari aplikasi (admin
--    ditetapkan manual lewat SQL Editor).
-- =============================================================================

-- ---------- Tabel ----------
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

-- ---------- Trigger: buat profil & toko saat akun baru terdaftar ----------
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

-- ---------- Trigger: perbarui updated_at ----------
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

-- ---------- Row Level Security ----------
alter table public.profiles enable row level security;
alter table public.stores   enable row level security;

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

-- ---------- Hak akses tingkat kolom (lapisan keamanan tambahan) ----------
revoke all on public.profiles, public.stores from anon;
revoke insert, delete, update on public.profiles, public.stores from authenticated;

grant select on public.profiles, public.stores to authenticated;
grant update (name) on public.profiles to authenticated;                    -- role/is_active tidak bisa diubah
grant update (store_name, address, phone) on public.stores to authenticated;
