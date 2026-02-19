-- Final legacy cleanup: routine_logs replaced by workout_sessions +
-- session_exercises + session_sets.

begin;

drop table if exists public.routine_logs cascade;

commit;
