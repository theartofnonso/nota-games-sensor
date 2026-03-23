-- Bucket `coach-instruction-videos` (private) + storage.objects RLS.
-- Paths: `{client_id}/...` (sessions) or `{client_id}/templates/{template_id}/...`.

CREATE OR REPLACE FUNCTION public.coach_can_access_client_storage_prefix(client_prefix text)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.coach_clients cc
    WHERE cc.coach_id = (SELECT auth.uid())
      AND cc.client_id::text = client_prefix
  );
$$;

REVOKE ALL ON FUNCTION public.coach_can_access_client_storage_prefix(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.coach_can_access_client_storage_prefix(text) TO authenticated;

INSERT INTO storage.buckets (id, name, public)
VALUES ('coach-instruction-videos', 'coach-instruction-videos', false)
ON CONFLICT (id) DO UPDATE SET public = EXCLUDED.public;

-- Idempotent policy refresh
DROP POLICY IF EXISTS "coach_instruction_videos_select" ON storage.objects;
DROP POLICY IF EXISTS "coach_instruction_videos_insert" ON storage.objects;
DROP POLICY IF EXISTS "coach_instruction_videos_update" ON storage.objects;
DROP POLICY IF EXISTS "coach_instruction_videos_delete" ON storage.objects;

-- Clients: read own folder. Coaches: read folders of assigned clients (signed URLs / playback).
CREATE POLICY "coach_instruction_videos_select"
ON storage.objects FOR SELECT
TO authenticated
USING (
  bucket_id = 'coach-instruction-videos'
  AND (
    split_part(name, '/', 1) = auth.uid()::text
    OR public.coach_can_access_client_storage_prefix(split_part(name, '/', 1))
  )
);

-- Coaches only: upload into a client folder they are assigned to.
CREATE POLICY "coach_instruction_videos_insert"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'coach-instruction-videos'
  AND public.coach_can_access_client_storage_prefix(split_part(name, '/', 1))
);

-- Replace / metadata updates (if used)
CREATE POLICY "coach_instruction_videos_update"
ON storage.objects FOR UPDATE
TO authenticated
USING (
  bucket_id = 'coach-instruction-videos'
  AND public.coach_can_access_client_storage_prefix(split_part(name, '/', 1))
)
WITH CHECK (
  bucket_id = 'coach-instruction-videos'
  AND public.coach_can_access_client_storage_prefix(split_part(name, '/', 1))
);

CREATE POLICY "coach_instruction_videos_delete"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'coach-instruction-videos'
  AND public.coach_can_access_client_storage_prefix(split_part(name, '/', 1))
);
