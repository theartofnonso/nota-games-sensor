-- Phase 6 cleanup: remove legacy JSON workout payload columns.
-- Relational sources are now:
-- - template_exercises + template_sets
-- - workout_sessions + session_exercises + session_sets

begin;

alter table public.routine_templates
  drop column if exists exercises;

alter table if exists public.routine_logs
  drop column if exists exercises;

commit;
