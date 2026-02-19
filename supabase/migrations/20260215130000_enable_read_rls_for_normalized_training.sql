-- Enable read policies for normalized training tables.
-- This unblocks client/coach reads under RLS.

begin;

-- ---------------------------------------------------------------------------
-- 1) Canonical exercise catalog
-- ---------------------------------------------------------------------------
alter table public.exercises enable row level security;

drop policy if exists exercises_select_authenticated on public.exercises;
create policy exercises_select_authenticated
on public.exercises
for select
to authenticated
using (true);

-- ---------------------------------------------------------------------------
-- 2) Planning layer
-- Coaches read their owned plans/templates; clients read assigned rows.
-- ---------------------------------------------------------------------------
alter table public.routine_plans enable row level security;
drop policy if exists routine_plans_select_owner_or_client on public.routine_plans;
create policy routine_plans_select_owner_or_client
on public.routine_plans
for select
to authenticated
using (
  auth.uid() = owner
  or auth.uid() = "clientId"
);

alter table public.routine_templates enable row level security;
drop policy if exists routine_templates_select_owner_or_client on public.routine_templates;
create policy routine_templates_select_owner_or_client
on public.routine_templates
for select
to authenticated
using (
  auth.uid() = owner
  or auth.uid() = "clientId"
);

-- template_exercises: visible when parent template is visible
alter table public.template_exercises enable row level security;
drop policy if exists template_exercises_select_via_template on public.template_exercises;
create policy template_exercises_select_via_template
on public.template_exercises
for select
to authenticated
using (
  exists (
    select 1
    from public.routine_templates rt
    where rt.id = template_exercises.template_id
      and (auth.uid() = rt.owner or auth.uid() = rt."clientId")
  )
);

-- template_sets: visible when parent template_exercise is visible
alter table public.template_sets enable row level security;
drop policy if exists template_sets_select_via_template_exercise on public.template_sets;
create policy template_sets_select_via_template_exercise
on public.template_sets
for select
to authenticated
using (
  exists (
    select 1
    from public.template_exercises te
    join public.routine_templates rt on rt.id = te.template_id
    where te.id = template_sets.template_exercise_id
      and (auth.uid() = rt.owner or auth.uid() = rt."clientId")
  )
);

-- exercise_alternatives: visible when parent template_exercise is visible
alter table public.exercise_alternatives enable row level security;
drop policy if exists exercise_alternatives_select_via_template_exercise on public.exercise_alternatives;
create policy exercise_alternatives_select_via_template_exercise
on public.exercise_alternatives
for select
to authenticated
using (
  exists (
    select 1
    from public.template_exercises te
    join public.routine_templates rt on rt.id = te.template_id
    where te.id = exercise_alternatives.template_exercise_id
      and (auth.uid() = rt.owner or auth.uid() = rt."clientId")
  )
);

-- ---------------------------------------------------------------------------
-- 3) Execution + performance layer
-- Clients read own sessions; coaches read sessions of assigned clients.
-- ---------------------------------------------------------------------------
alter table public.workout_sessions enable row level security;
drop policy if exists workout_sessions_select_user_or_assigned_coach on public.workout_sessions;
create policy workout_sessions_select_user_or_assigned_coach
on public.workout_sessions
for select
to authenticated
using (
  auth.uid() = user_id
  or exists (
    select 1
    from public.coach_clients cc
    where cc.client_id = workout_sessions.user_id
      and cc.coach_id = auth.uid()
  )
);

alter table public.session_exercises enable row level security;
drop policy if exists session_exercises_select_via_session on public.session_exercises;
create policy session_exercises_select_via_session
on public.session_exercises
for select
to authenticated
using (
  exists (
    select 1
    from public.workout_sessions ws
    where ws.id = session_exercises.session_id
      and (
        auth.uid() = ws.user_id
        or exists (
          select 1
          from public.coach_clients cc
          where cc.client_id = ws.user_id
            and cc.coach_id = auth.uid()
        )
      )
  )
);

alter table public.session_sets enable row level security;
drop policy if exists session_sets_select_via_session_exercise on public.session_sets;
create policy session_sets_select_via_session_exercise
on public.session_sets
for select
to authenticated
using (
  exists (
    select 1
    from public.session_exercises se
    join public.workout_sessions ws on ws.id = se.session_id
    where se.id = session_sets.session_exercise_id
      and (
        auth.uid() = ws.user_id
        or exists (
          select 1
          from public.coach_clients cc
          where cc.client_id = ws.user_id
            and cc.coach_id = auth.uid()
        )
      )
  )
);

commit;
