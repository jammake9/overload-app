-- Overload — Phase 1 schema (cloud sync, pre-relational)
-- ============================================================================
-- Run this in the Supabase SQL editor on a fresh project.
--
-- WHAT THIS IS, AND WHY IT ISN'T schema.sql
-- ------------------------------------------
-- The full relational design lives in `schema.sql` and is the intended end
-- state (Phase 3). This file is the stepping stone: it gets real accounts and
-- real server-side storage working without rewriting the app's 48 save sites.
--
-- The existing app keeps all its data in a single `state` object and persists
-- it through exactly three functions (loadState / saveKey / deleteKeySafe),
-- one localStorage entry per top-level key. This table mirrors that shape
-- exactly — one row per (user, key) — so those three functions can be swapped
-- to Supabase while every other line of the app stays as it is.
--
-- Phase 3 replaces this with schema.sql's tables and migrates these rows over.
-- Nothing here blocks that: it is a superset of what the app currently stores.
-- ============================================================================

create table if not exists user_state (
  owner_id   uuid        not null references auth.users(id) on delete cascade,
  key        text        not null,
  -- Nullable on purpose: `activeWorkout` and `account` are legitimately null in
  -- the app's state, and a not-null column would reject them.
  value      jsonb,
  updated_at timestamptz not null default now(),
  primary key (owner_id, key)
);

-- The app's known keys, for reference (not enforced — kept flexible so adding
-- a new state slice doesn't need a migration):
--   exercises, templates, history, activeWorkout, bodyweight,
--   measurementFields, measurements, goals, dailyLogs, settings, account

-- Keep updated_at honest; it's the basis for last-write-wins conflict handling
-- when the same account is used on two devices.
create or replace function touch_user_state()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists user_state_touch on user_state;
create trigger user_state_touch
  before update on user_state
  for each row execute function touch_user_state();

-- ============================================================================
-- ROW LEVEL SECURITY
-- Without this, Supabase's public API refuses all access to the table (safe
-- default). With it, each user can read and write only their own rows.
-- ============================================================================
alter table user_state enable row level security;

-- Separate policies per operation rather than one `for all`, so that the
-- INSERT path gets a with-check clause. A bare `using` clause is not applied
-- to inserts, which would otherwise let a user write rows owned by someone else.
drop policy if exists "read own state"   on user_state;
drop policy if exists "insert own state" on user_state;
drop policy if exists "update own state" on user_state;
drop policy if exists "delete own state" on user_state;

create policy "read own state" on user_state
  for select using (auth.uid() = owner_id);

create policy "insert own state" on user_state
  for insert with check (auth.uid() = owner_id);

create policy "update own state" on user_state
  for update using (auth.uid() = owner_id)
          with check (auth.uid() = owner_id);

create policy "delete own state" on user_state
  for delete using (auth.uid() = owner_id);
