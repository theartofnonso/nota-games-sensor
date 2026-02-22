-- Allow coaches to update workout_sessions (e.g. coach_note) for their clients.
-- Session owners can also update their own sessions.

begin;

drop policy if exists workout_sessions_update_user_or_assigned_coach on public.workout_sessions;
create policy workout_sessions_update_user_or_assigned_coach
on public.workout_sessions
for update
to authenticated
using (
  auth.uid() = user_id
  or exists (
    select 1
    from public.coach_clients cc
    where cc.client_id = workout_sessions.user_id
      and cc.coach_id = auth.uid()
  )
)
with check (
  auth.uid() = user_id
  or exists (
    select 1
    from public.coach_clients cc
    where cc.client_id = workout_sessions.user_id
      and cc.coach_id = auth.uid()
  )
);

commit;
