-- ============================================================================
-- NOVA — Schéma Supabase (cloud sync des profils, sources, favoris, progression)
-- ============================================================================
-- À exécuter dans : Supabase Dashboard > SQL Editor > New query > Run.
-- La sécurité (RLS) fait que chaque utilisateur ne voit QUE ses données.
-- ============================================================================

-- Extension pour UUID
create extension if not exists "pgcrypto";

-- ---------------------------------------------------------------------------
-- PROFILS (plusieurs profils par compte, façon Netflix)
-- ---------------------------------------------------------------------------
create table if not exists public.profiles (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references auth.users(id) on delete cascade,
  name          text not null,
  avatar        text,                      -- id/nom de l'avatar ou URL
  is_kids       boolean not null default false,
  pin_hash      text,                      -- code PIN hashé (optionnel)
  adult_unlocked boolean not null default false,
  preferences   jsonb not null default '{}'::jsonb,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- SOURCES IPTV (Xtream Codes ou M3U) — sauvegardées dans le cloud
-- ---------------------------------------------------------------------------
create table if not exists public.sources (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references auth.users(id) on delete cascade,
  name          text not null,
  kind          text not null check (kind in ('xtream', 'm3u')),
  -- Xtream : url = http://host:port ; username ; password
  -- M3U    : url = lien .m3u/.m3u8 (username/password vides)
  url           text not null,
  username      text,
  password      text,
  epg_url       text,                      -- lien XMLTV optionnel
  is_active     boolean not null default true,
  sort_order    int not null default 0,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- FAVORIS (par profil)
-- ---------------------------------------------------------------------------
create table if not exists public.favorites (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references auth.users(id) on delete cascade,
  profile_id    uuid not null references public.profiles(id) on delete cascade,
  item_id       text not null,             -- identifiant stable du média
  item_type     text not null,             -- 'live' | 'movie' | 'series'
  title         text,
  poster        text,
  payload       jsonb not null default '{}'::jsonb,
  created_at    timestamptz not null default now(),
  unique (profile_id, item_id)
);

-- ---------------------------------------------------------------------------
-- PROGRESSION (Reprendre à regarder)
-- ---------------------------------------------------------------------------
create table if not exists public.watch_progress (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references auth.users(id) on delete cascade,
  profile_id    uuid not null references public.profiles(id) on delete cascade,
  item_id       text not null,             -- film ou episode
  item_type     text not null,             -- 'movie' | 'episode' | 'live'
  series_id     text,                      -- si episode : id de la serie
  season        int,
  episode       int,
  title         text,
  poster        text,
  position_secs int not null default 0,
  duration_secs int not null default 0,
  finished      boolean not null default false,
  updated_at    timestamptz not null default now(),
  unique (profile_id, item_id)
);

-- ---------------------------------------------------------------------------
-- Index utiles
-- ---------------------------------------------------------------------------
create index if not exists idx_profiles_user on public.profiles(user_id);
create index if not exists idx_sources_user on public.sources(user_id);
create index if not exists idx_favorites_profile on public.favorites(profile_id);
create index if not exists idx_progress_profile on public.watch_progress(profile_id);
create index if not exists idx_progress_updated on public.watch_progress(profile_id, updated_at desc);

-- ---------------------------------------------------------------------------
-- Row Level Security : chacun ne voit que SES lignes
-- ---------------------------------------------------------------------------
alter table public.profiles       enable row level security;
alter table public.sources        enable row level security;
alter table public.favorites      enable row level security;
alter table public.watch_progress enable row level security;

do $$
declare
  t text;
begin
  foreach t in array array['profiles','sources','favorites','watch_progress']
  loop
    execute format('drop policy if exists "own_select" on public.%I;', t);
    execute format('drop policy if exists "own_insert" on public.%I;', t);
    execute format('drop policy if exists "own_update" on public.%I;', t);
    execute format('drop policy if exists "own_delete" on public.%I;', t);

    execute format(
      'create policy "own_select" on public.%I for select using (auth.uid() = user_id);', t);
    execute format(
      'create policy "own_insert" on public.%I for insert with check (auth.uid() = user_id);', t);
    execute format(
      'create policy "own_update" on public.%I for update using (auth.uid() = user_id) with check (auth.uid() = user_id);', t);
    execute format(
      'create policy "own_delete" on public.%I for delete using (auth.uid() = user_id);', t);
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- Trigger updated_at automatique
-- ---------------------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

do $$
declare
  t text;
begin
  foreach t in array array['profiles','sources','watch_progress']
  loop
    execute format('drop trigger if exists trg_updated_at on public.%I;', t);
    execute format(
      'create trigger trg_updated_at before update on public.%I
       for each row execute function public.set_updated_at();', t);
  end loop;
end $$;
