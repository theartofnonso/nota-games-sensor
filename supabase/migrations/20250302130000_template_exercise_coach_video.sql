-- Optional coach instruction video per template exercise (coach sets in template editor).
-- Clients see it during training via session_exercises.template_exercise_id → this row.

ALTER TABLE public.template_exercises
  ADD COLUMN IF NOT EXISTS coach_instruction_video_path text;

COMMENT ON COLUMN public.template_exercises.coach_instruction_video_path IS
  'Path in coach_instruction_videos bucket; canonical store for coach clips.';
