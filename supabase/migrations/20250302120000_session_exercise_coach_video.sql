-- Historical: session-level video column. Superseded by template-only storage;
-- run `20250302140000_drop_session_exercise_coach_video.sql` to remove this column.
-- Optional coach-uploaded instructional video per workout exercise instance.

ALTER TABLE public.session_exercises
  ADD COLUMN IF NOT EXISTS coach_instruction_video_path text;

COMMENT ON COLUMN public.session_exercises.coach_instruction_video_path IS
  'Deprecated: use template_exercises.coach_instruction_video_path + template_exercise_id.';
