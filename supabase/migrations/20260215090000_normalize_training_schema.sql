-- Normalize training data from JSON blobs into relational tables.
-- Phase 1-4 only: create + backfill + validate helpers.
-- Old JSON columns remain in place until app reads are fully switched.

begin;

-- ---------------------------------------------------------------------------
-- 2) Canonical exercises table
-- We intentionally reset legacy custom-user exercises table and replace it
-- with canonical system exercise registry (text ids).
-- ---------------------------------------------------------------------------
drop table if exists public.exercises cascade;

create table public.exercises (
  id text primary key,
  name text not null,
  type text,
  created_at timestamptz default now()
);

-- ---------------------------------------------------------------------------
-- 3) New planning layer tables
-- ---------------------------------------------------------------------------
create table if not exists public.template_exercises (
  id uuid primary key default gen_random_uuid(),
  template_id uuid not null references public.routine_templates(id) on delete cascade,
  exercise_id text not null references public.exercises(id),
  order_index int not null,
  super_set_group text,
  notes text,
  created_at timestamptz default now(),
  unique (template_id, order_index)
);

create table if not exists public.template_sets (
  id uuid primary key default gen_random_uuid(),
  template_exercise_id uuid not null references public.template_exercises(id) on delete cascade,
  target_reps int,
  target_weight numeric,
  target_duration_seconds int,
  order_index int not null,
  unique (template_exercise_id, order_index)
);

-- Optional substitution graph for planned alternatives.
create table if not exists public.exercise_alternatives (
  id uuid primary key default gen_random_uuid(),
  template_exercise_id uuid not null references public.template_exercises(id) on delete cascade,
  alternative_exercise_id text not null references public.exercises(id),
  order_index int not null default 0,
  created_at timestamptz default now(),
  unique (template_exercise_id, alternative_exercise_id)
);

-- ---------------------------------------------------------------------------
-- 4) New execution + performance layer tables
-- ---------------------------------------------------------------------------
create table if not exists public.workout_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  template_id uuid references public.routine_templates(id) on delete set null,
  name text not null,
  notes text,
  coach_note text,
  start_time timestamptz not null,
  end_time timestamptz not null,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table if not exists public.session_exercises (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.workout_sessions(id) on delete cascade,
  exercise_id text not null references public.exercises(id),
  template_exercise_id uuid references public.template_exercises(id),
  order_index int not null,
  super_set_group text,
  notes text,
  created_at timestamptz default now(),
  unique (session_id, order_index)
);

create table if not exists public.session_sets (
  id uuid primary key default gen_random_uuid(),
  session_exercise_id uuid not null references public.session_exercises(id) on delete cascade,
  reps int,
  weight numeric,
  duration_seconds int,
  rpe numeric,
  is_completed boolean default true,
  order_index int not null,
  created_at timestamptz default now(),
  unique (session_exercise_id, order_index)
);

-- ---------------------------------------------------------------------------
-- 5) Indexes for aggregation/query performance
-- ---------------------------------------------------------------------------
create index if not exists idx_session_sets_session_exercise
  on public.session_sets(session_exercise_id);
create index if not exists idx_session_exercises_session
  on public.session_exercises(session_id);
create index if not exists idx_session_exercises_exercise
  on public.session_exercises(exercise_id);
create index if not exists idx_workout_sessions_user_time
  on public.workout_sessions(user_id, start_time);
create index if not exists idx_exercise_alternatives_template
  on public.exercise_alternatives(template_exercise_id);

-- ---------------------------------------------------------------------------
-- 6) Strictness checks for legacy JSON payloads
-- ---------------------------------------------------------------------------
do $$
declare
  missing_template_ids int;
  missing_log_ids int;
begin
  select count(*)
    into missing_template_ids
  from public.routine_templates rt
  cross join lateral jsonb_array_elements(coalesce(rt.exercises, '[]'::jsonb)) ex
  where ex->'exercise'->>'id' is not null
    and (
      ex->'exercise'->>'name' is null
      or ex->'exercise'->>'type' is null
    );

  select count(*)
    into missing_log_ids
  from public.routine_logs rl
  cross join lateral jsonb_array_elements(coalesce(rl.exercises, '[]'::jsonb)) ex
  where ex->'exercise'->>'id' is not null
    and (
      ex->'exercise'->>'name' is null
      or ex->'exercise'->>'type' is null
    );

  if missing_template_ids > 0 or missing_log_ids > 0 then
    raise exception
      'Invalid exercise JSON (missing required name/type). templates=%, logs=%',
      missing_template_ids, missing_log_ids;
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 7) Backfill canonical exercises from template/log JSON payloads
-- ---------------------------------------------------------------------------
with extracted as (
  select
    ex->'exercise'->>'id' as exercise_id,
    ex->'exercise'->>'name' as exercise_name,
    ex->'exercise'->>'type' as exercise_type
  from public.routine_templates rt
  cross join lateral jsonb_array_elements(coalesce(rt.exercises, '[]'::jsonb)) ex
  union all
  select
    ex->'exercise'->>'id' as exercise_id,
    ex->'exercise'->>'name' as exercise_name,
    ex->'exercise'->>'type' as exercise_type
  from public.routine_logs rl
  cross join lateral jsonb_array_elements(coalesce(rl.exercises, '[]'::jsonb)) ex
),
deduped as (
  select distinct on (exercise_id)
    exercise_id,
    exercise_name,
    exercise_type
  from extracted
  where exercise_id is not null
  order by exercise_id
)
insert into public.exercises (
  id,
  name,
  type,
  created_at
)
select
  d.exercise_id,
  d.exercise_name,
  d.exercise_type,
  now()
from deduped d
on conflict (id) do update
set
  name = excluded.name,
  type = excluded.type;

-- ---------------------------------------------------------------------------
-- 8) Backfill template_exercises + template_sets from routine_templates.exercises
-- ---------------------------------------------------------------------------
with expanded as (
  select
    rt.id as template_id,
    ex.value as exercise_blob,
    (ex.ordinality - 1)::int as exercise_order_index
  from public.routine_templates rt
  cross join lateral jsonb_array_elements(coalesce(rt.exercises, '[]'::jsonb))
    with ordinality as ex(value, ordinality)
)
insert into public.template_exercises (
  template_id,
  exercise_id,
  order_index,
  super_set_group,
  notes
)
select
  e.template_id,
  exref.id as exercise_id,
  e.exercise_order_index,
  nullif(e.exercise_blob->>'superSetId', ''),
  nullif(e.exercise_blob->>'notes', '')
from expanded e
join public.exercises exref
  on exref.id = e.exercise_blob->'exercise'->>'id'
where e.exercise_blob->'exercise'->>'id' is not null
on conflict (template_id, order_index) do update
set
  exercise_id = excluded.exercise_id,
  super_set_group = excluded.super_set_group,
  notes = excluded.notes;

with expanded as (
  select
    rt.id as template_id,
    ex.value as exercise_blob,
    (ex.ordinality - 1)::int as exercise_order_index
  from public.routine_templates rt
  cross join lateral jsonb_array_elements(coalesce(rt.exercises, '[]'::jsonb))
    with ordinality as ex(value, ordinality)
),
expanded_sets as (
  select
    te.id as template_exercise_id,
    te.exercise_id,
    set_item.value as set_blob,
    (set_item.ordinality - 1)::int as set_order_index
  from expanded e
  join public.template_exercises te
    on te.template_id = e.template_id
   and te.order_index = e.exercise_order_index
  cross join lateral jsonb_array_elements(coalesce(e.exercise_blob->'sets', '[]'::jsonb))
    with ordinality as set_item(value, ordinality)
)
insert into public.template_sets (
  template_exercise_id,
  target_reps,
  target_weight,
  target_duration_seconds,
  order_index
)
select
  es.template_exercise_id,
  case
    when es.set_blob ? 'reps' then (es.set_blob->>'reps')::int
    when es.set_blob ? 'value2'
         and coalesce(es.set_blob ? 'duration', false) = false
         and exists (
           select 1
           from public.exercises ex
           where ex.id = es.exercise_id
             and ex.type in ('WR', 'BW')
         )
      then (es.set_blob->>'value2')::int
    else null
  end as target_reps,
  case
    when es.set_blob ? 'weight' then (es.set_blob->>'weight')::numeric
    when es.set_blob ? 'value1' then (es.set_blob->>'value1')::numeric
    else null
  end as target_weight,
  case
    when es.set_blob ? 'duration' then ((es.set_blob->>'duration')::numeric / 1000)::int
    when es.set_blob ? 'value2'
         and exists (
           select 1
           from public.exercises ex
           where ex.id = es.exercise_id
             and ex.type = 'DR'
         )
      then ((es.set_blob->>'value2')::numeric / 1000)::int
    else null
  end as target_duration_seconds,
  es.set_order_index
from expanded_sets es
on conflict (template_exercise_id, order_index) do update
set
  target_reps = excluded.target_reps,
  target_weight = excluded.target_weight,
  target_duration_seconds = excluded.target_duration_seconds;

-- ---------------------------------------------------------------------------
-- 9) Backfill workout_sessions + session_exercises + session_sets from routine_logs
-- ---------------------------------------------------------------------------
insert into public.workout_sessions (
  id,
  user_id,
  template_id,
  name,
  notes,
  coach_note,
  start_time,
  end_time,
  created_at,
  updated_at
)
select
  rl.id,
  rl.owner as user_id,
  case
    when rl."templateId" ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
      and exists (
        select 1
        from public.routine_templates rt
        where rt.id = rl."templateId"::uuid
      )
      then rl."templateId"::uuid
    else null
  end as template_id,
  coalesce(rl.name, ''),
  nullif(rl.notes, ''),
  rl.coach_note,
  rl."startTime",
  rl."endTime",
  coalesce(rl."createdAt", now()),
  coalesce(rl."createdAt", now())
from public.routine_logs rl
on conflict (id) do update
set
  user_id = excluded.user_id,
  template_id = excluded.template_id,
  name = excluded.name,
  notes = excluded.notes,
  coach_note = excluded.coach_note,
  start_time = excluded.start_time,
  end_time = excluded.end_time,
  updated_at = excluded.updated_at;

with expanded as (
  select
    rl.id as session_id,
    case
      when rl."templateId" ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
        and exists (
          select 1
          from public.routine_templates rt
          where rt.id = rl."templateId"::uuid
        )
        then rl."templateId"::uuid
      else null
    end as template_id,
    ex.value as exercise_blob,
    (ex.ordinality - 1)::int as exercise_order_index
  from public.routine_logs rl
  cross join lateral jsonb_array_elements(coalesce(rl.exercises, '[]'::jsonb))
    with ordinality as ex(value, ordinality)
)
insert into public.session_exercises (
  session_id,
  exercise_id,
  template_exercise_id,
  order_index,
  super_set_group,
  notes
)
select
  e.session_id,
  exref.id as exercise_id,
  te.id as template_exercise_id,
  e.exercise_order_index,
  nullif(e.exercise_blob->>'superSetId', ''),
  nullif(e.exercise_blob->>'notes', '')
from expanded e
join public.exercises exref
  on exref.id = e.exercise_blob->'exercise'->>'id'
left join public.template_exercises te
  on te.template_id = e.template_id
 and te.order_index = e.exercise_order_index
where e.exercise_blob->'exercise'->>'id' is not null
on conflict (session_id, order_index) do update
set
  exercise_id = excluded.exercise_id,
  template_exercise_id = excluded.template_exercise_id,
  super_set_group = excluded.super_set_group,
  notes = excluded.notes;

with expanded as (
  select
    rl.id as session_id,
    ex.value as exercise_blob,
    (ex.ordinality - 1)::int as exercise_order_index
  from public.routine_logs rl
  cross join lateral jsonb_array_elements(coalesce(rl.exercises, '[]'::jsonb))
    with ordinality as ex(value, ordinality)
),
expanded_sets as (
  select
    se.id as session_exercise_id,
    se.exercise_id,
    set_item.value as set_blob,
    (set_item.ordinality - 1)::int as set_order_index
  from expanded e
  join public.session_exercises se
    on se.session_id = e.session_id
   and se.order_index = e.exercise_order_index
  cross join lateral jsonb_array_elements(coalesce(e.exercise_blob->'sets', '[]'::jsonb))
    with ordinality as set_item(value, ordinality)
)
insert into public.session_sets (
  session_exercise_id,
  reps,
  weight,
  duration_seconds,
  is_completed,
  order_index
)
select
  es.session_exercise_id,
  case
    when es.set_blob ? 'reps' then (es.set_blob->>'reps')::int
    when es.set_blob ? 'value2'
         and exists (
           select 1
           from public.exercises ex
           where ex.id = es.exercise_id
             and ex.type in ('WR', 'BW')
         )
      then (es.set_blob->>'value2')::int
    else null
  end as reps,
  case
    when es.set_blob ? 'weight' then (es.set_blob->>'weight')::numeric
    when es.set_blob ? 'value1' then (es.set_blob->>'value1')::numeric
    else null
  end as weight,
  case
    when es.set_blob ? 'duration' then ((es.set_blob->>'duration')::numeric / 1000)::int
    when es.set_blob ? 'value2'
         and exists (
           select 1
           from public.exercises ex
           where ex.id = es.exercise_id
             and ex.type = 'DR'
         )
      then ((es.set_blob->>'value2')::numeric / 1000)::int
    else null
  end as duration_seconds,
  true as is_completed,
  es.set_order_index
from expanded_sets es
where coalesce(
  (es.set_blob->>'checked')::boolean,
  (es.set_blob->>'isChecked')::boolean,
  false
) = true
on conflict (session_exercise_id, order_index) do update
set
  reps = excluded.reps,
  weight = excluded.weight,
  duration_seconds = excluded.duration_seconds,
  is_completed = excluded.is_completed;

commit;

-- Validation snippets (run manually after migration):
-- 1) select count(*) from public.routine_logs;
--    select count(*) from public.workout_sessions;
--
-- 2) select count(*) from public.routine_templates;
--    select count(distinct template_id) from public.template_exercises;
--
-- 3) old completed sets count:
--    select count(*)
--    from public.routine_logs rl
--    cross join lateral jsonb_array_elements(coalesce(rl.exercises, '[]'::jsonb)) ex
--    cross join lateral jsonb_array_elements(coalesce(ex->'sets', '[]'::jsonb)) s
--    where coalesce((s->>'checked')::boolean, (s->>'isChecked')::boolean, false) = true;
--    new:
--    select count(*) from public.session_sets;
