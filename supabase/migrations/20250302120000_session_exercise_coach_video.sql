-- Historical: session-level video column. Superseded by template-only storage;
-- run `20250302140000_drop_session_exercise_coach_video.sql` to remove this column.
-- Optional coach-uploaded instructional video per workout exercise instance.
-- App stores the object path inside the private bucket `coach_instruction_videos`.

ALTER TABLE public.session_exercises
  ADD COLUMN IF NOT EXISTS coach_instruction_video_path text;

COMMENT ON COLUMN public.session_exercises.coach_instruction_video_path IS
  'Deprecated: use template_exercises.coach_instruction_video_path + template_exercise_id.';

-- Storage (run in Dashboard → Storage):
-- 1. Create private bucket: coach_instruction_videos
-- 2. Policies (sketch — adjust to your auth model):
--    - INSERT/UPDATE/DELETE: coach role, object name prefix matches assigned client
--    - SELECT: signed URLs only, or SELECT for session owner (client)
