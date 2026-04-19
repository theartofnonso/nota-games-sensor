-- Coach-defined display order of workouts (templates) within a plan.
ALTER TABLE public.routine_templates
  ADD COLUMN IF NOT EXISTS "planOrderIndex" integer;

COMMENT ON COLUMN public.routine_templates."planOrderIndex" IS
  'Sort order within the plan (0-based). NULL = legacy rows; tie-break by createdAt in the app.';
