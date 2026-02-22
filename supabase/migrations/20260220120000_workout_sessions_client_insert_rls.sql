-- Allow clients to insert their own workout sessions and related rows.
-- Coaches create sessions for clients via the same tables; coach_clients
-- relationship is used for session_exercises/session_sets (session's user_id).

begin;

-- workout_sessions: user can insert rows where they are the owner
drop policy if exists workout_sessions_insert_user_owns on public.workout_sessions;
create policy workout_sessions_insert_user_owns
on public.workout_sessions
for insert
to authenticated
with check (auth.uid() = user_id);

-- session_exercises: user can insert when the session belongs to them or their coach's client
drop policy if exists session_exercises_insert_via_session on public.session_exercises;
create policy session_exercises_insert_via_session
on public.session_exercises
for insert
to authenticated
with check (
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

-- session_sets: user can insert when the session_exercise's session is accessible
drop policy if exists session_sets_insert_via_session_exercise on public.session_sets;
create policy session_sets_insert_via_session_exercise
on public.session_sets
for insert
to authenticated
with check (
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
