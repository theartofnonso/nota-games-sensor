-- Allow session owner or assigned coach to delete workout_sessions.
-- Fixes: Delete rejected or no row found for log (SELECT worked, DELETE denied)

begin;

drop policy if exists workout_sessions_delete_user_or_assigned_coach on public.workout_sessions;
create policy workout_sessions_delete_user_or_assigned_coach
on public.workout_sessions
for delete
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

commit;
