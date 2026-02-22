begin;

create table if not exists public.exercise_challenges (
  id uuid primary key default gen_random_uuid(),
  coach_id uuid not null references auth.users(id) on delete cascade,
  client_id uuid not null references auth.users(id) on delete cascade,
  title text not null check (length(trim(title)) > 0),
  exercise_id text not null references public.exercises(id),
  exercise_name text not null,
  exercise_type text not null check (exercise_type in ('WR', 'BW', 'DR', 'NO')),
  target_type text not null check (target_type in ('weight', 'reps', 'duration')),
  target_value numeric not null check (target_value > 0),
  start_date date not null,
  end_date date not null check (end_date >= start_date),
  created_at timestamptz not null default now()
);

create index if not exists idx_exercise_challenges_client_dates
  on public.exercise_challenges(client_id, start_date, end_date);

create index if not exists idx_exercise_challenges_exercise
  on public.exercise_challenges(exercise_id);

alter table public.exercise_challenges enable row level security;

drop policy if exists exercise_challenges_select_client_or_assigned_coach
  on public.exercise_challenges;
create policy exercise_challenges_select_client_or_assigned_coach
on public.exercise_challenges
for select
to authenticated
using (
  auth.uid() = client_id
  or auth.uid() = coach_id
  or exists (
    select 1
    from public.coach_clients cc
    where cc.client_id = exercise_challenges.client_id
      and cc.coach_id = auth.uid()
  )
);

drop policy if exists exercise_challenges_insert_assigned_coach_only
  on public.exercise_challenges;
create policy exercise_challenges_insert_assigned_coach_only
on public.exercise_challenges
for insert
to authenticated
with check (
  auth.uid() = coach_id
  and exists (
    select 1
    from public.coach_clients cc
    where cc.client_id = exercise_challenges.client_id
      and cc.coach_id = auth.uid()
  )
);

drop policy if exists exercise_challenges_delete_coach_only
  on public.exercise_challenges;
create policy exercise_challenges_delete_coach_only
on public.exercise_challenges
for delete
to authenticated
using (
  auth.uid() = coach_id
  and exists (
    select 1
    from public.coach_clients cc
    where cc.client_id = exercise_challenges.client_id
      and cc.coach_id = auth.uid()
  )
);

commit;
