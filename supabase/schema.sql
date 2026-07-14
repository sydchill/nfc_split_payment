-- Tandem backend schema. Run this in the Supabase SQL editor
-- (Dashboard → SQL Editor → New query → paste → Run).
--
-- It creates a `profiles` row per auth user, populated from the metadata the
-- app sends at sign-up (mode / name / business details), and locks every row
-- to its owner via Row Level Security.

create table if not exists public.profiles (
  id            uuid primary key references auth.users (id) on delete cascade,
  mode          text not null default 'personal' check (mode in ('personal', 'business')),
  full_name     text,
  business_name text,
  category      text,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

alter table public.profiles enable row level security;

-- A user may only see and change their own profile row.
drop policy if exists "profiles select own" on public.profiles;
create policy "profiles select own"
  on public.profiles for select
  using (auth.uid() = id);

drop policy if exists "profiles insert own" on public.profiles;
create policy "profiles insert own"
  on public.profiles for insert
  with check (auth.uid() = id);

drop policy if exists "profiles update own" on public.profiles;
create policy "profiles update own"
  on public.profiles for update
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- Copy sign-up metadata into the profile row when a new auth user is created.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, mode, full_name, business_name, category)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'mode', 'personal'),
    new.raw_user_meta_data ->> 'full_name',
    new.raw_user_meta_data ->> 'business_name',
    new.raw_user_meta_data ->> 'category'
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
