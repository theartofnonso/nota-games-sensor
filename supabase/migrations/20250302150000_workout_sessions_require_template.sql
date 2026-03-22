-- Every saved workout session must belong to a routine template.
-- Orphan sessions (no template) are removed; adjust if you need to backfill instead.

DELETE FROM public.session_sets
WHERE session_exercise_id IN (
  SELECT id FROM public.session_exercises
  WHERE session_id IN (
    SELECT id FROM public.workout_sessions WHERE template_id IS NULL
  )
);

DELETE FROM public.session_exercises
WHERE session_id IN (
  SELECT id FROM public.workout_sessions WHERE template_id IS NULL
);

DELETE FROM public.workout_sessions WHERE template_id IS NULL;

ALTER TABLE public.workout_sessions
  ALTER COLUMN template_id SET NOT NULL;

COMMENT ON COLUMN public.workout_sessions.template_id IS
  'Required FK to routine_templates; sessions are always started from a template.';
