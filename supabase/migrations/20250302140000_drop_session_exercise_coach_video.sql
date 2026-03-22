-- Coaching video lives only on template_exercises; session rows link via
-- template_exercise_id and resolve video through that FK at read time.

ALTER TABLE public.session_exercises
  DROP COLUMN IF EXISTS coach_instruction_video_path;
