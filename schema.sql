-- Overload — Postgres schema for Supabase
-- Run this in the Supabase SQL editor on a fresh project.
-- Supabase already provides auth.users for login/registration — we reference it
-- rather than building a parallel users table.

-- ============================================================================
-- PROFILE (one row per registered user, extends Supabase's built-in auth.users)
-- ============================================================================
create table profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  name text not null,
  dob date,
  sex text,
  height_cm numeric,
  goal text,
  marketing_opt_in boolean default false,
  theme text default 'light',
  created_at timestamptz default now()
);

-- ============================================================================
-- EXERCISE LIBRARY
-- Built-in exercises are shared (owner_id null); custom ones belong to a user.
-- ============================================================================
create table exercises (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid references auth.users(id) on delete cascade,  -- null = built-in/shared
  name text not null,
  muscle_group text not null,          -- chest | back | legs | shoulders | arms | core | cardio
  type text not null,                   -- weighted | bodyweight | cardio
  default_rest_seconds int default 90,
  notes text default '',
  created_at timestamptz default now()
);

-- ============================================================================
-- TEMPLATES (reusable workout plans)
-- ============================================================================
create table templates (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  created_at timestamptz default now()
);

create table template_exercises (
  id uuid primary key default gen_random_uuid(),
  template_id uuid not null references templates(id) on delete cascade,
  exercise_id uuid not null references exercises(id),
  rest_seconds int default 90,
  order_index int not null
);

-- ============================================================================
-- WORKOUTS (completed + the one in-progress "active" workout)
-- ============================================================================
create table workouts (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  name text not null default 'Workout',
  start_time timestamptz not null,
  end_time timestamptz,                 -- null while still in progress
  duration_sec int,
  is_active boolean default false,      -- true = the current in-progress session
  is_backdated boolean default false,   -- true = retrospectively logged, no live timer
  photo_url text,
  created_at timestamptz default now()
);
-- Only one active workout per user should exist at a time — enforce in app logic
-- (or add a partial unique index: create unique index one_active_per_user
--  on workouts(owner_id) where is_active);

create table workout_exercises (
  id uuid primary key default gen_random_uuid(),
  workout_id uuid not null references workouts(id) on delete cascade,
  exercise_id uuid not null references exercises(id),
  name text not null,                   -- snapshot of the exercise name at log time
  muscle_group text not null,
  type text not null,
  notes text default '',
  order_index int not null
);

create table sets (
  id uuid primary key default gen_random_uuid(),
  workout_exercise_id uuid not null references workout_exercises(id) on delete cascade,
  weight numeric,
  reps int,
  duration_min numeric,
  distance_km numeric,
  completed boolean default false,
  note text default '',
  order_index int not null
);

-- PRs are intentionally NOT a table — compute them from `sets` + `workout_exercises`
-- joined to `workouts`, per exercise, same logic as the original app's computeSessionPRs.

-- ============================================================================
-- MEASUREMENTS
-- ============================================================================
create table measurement_fields (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  unit text not null,
  created_at timestamptz default now()
);

create table measurements (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  date date not null,
  created_at timestamptz default now()
);

create table measurement_values (
  id uuid primary key default gen_random_uuid(),
  measurement_id uuid not null references measurements(id) on delete cascade,
  field_id uuid not null references measurement_fields(id),
  value numeric not null
);

-- ============================================================================
-- GOALS / DAILY LOGS
-- ============================================================================
create table goals (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  goal_type text not null,              -- calories | protein | water | steps | supplements
  target numeric not null
);

create table daily_logs (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  date date not null,
  goal_type text not null,
  value numeric not null
);

-- ============================================================================
-- ROW LEVEL SECURITY
-- Every user-owned table needs RLS turned on, or Supabase's public API will
-- refuse all access to it by default (safe, but you must explicitly opt in).
-- Pattern is identical for each table below — shown once per table, repeat
-- for template_exercises/workout_exercises/sets/measurement_values via a join
-- back to the parent's owner_id.
-- ============================================================================
alter table profiles enable row level security;
create policy "own profile" on profiles for all using (auth.uid() = id);

alter table workouts enable row level security;
create policy "own workouts" on workouts for all using (auth.uid() = owner_id);

alter table templates enable row level security;
create policy "own templates" on templates for all using (auth.uid() = owner_id);

alter table measurement_fields enable row level security;
create policy "own measurement fields" on measurement_fields for all using (auth.uid() = owner_id);

alter table measurements enable row level security;
create policy "own measurements" on measurements for all using (auth.uid() = owner_id);

alter table goals enable row level security;
create policy "own goals" on goals for all using (auth.uid() = owner_id);

alter table daily_logs enable row level security;
create policy "own daily logs" on daily_logs for all using (auth.uid() = owner_id);

-- exercises: built-ins (owner_id is null) are readable by everyone; custom ones
-- are only visible to their owner.
alter table exercises enable row level security;
create policy "read built-ins and own custom" on exercises for select
  using (owner_id is null or auth.uid() = owner_id);
create policy "insert own custom" on exercises for insert
  with check (auth.uid() = owner_id);
