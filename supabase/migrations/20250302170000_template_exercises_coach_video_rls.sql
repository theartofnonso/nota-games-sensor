-- Allow updating coach_instruction_video_path on template_exercises.
-- Without this, PATCH on template_exercises returns 0 rows (RLS) while nested
-- SELECTs on routine_templates can still load data → "update blocked for id=..." in the app.

DROP POLICY IF EXISTS "template_exercises_update_for_template_access"
  ON public.template_exercises;

CREATE POLICY "template_exercises_update_for_template_access"
  ON public.template_exercises
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.routine_templates rt
      WHERE rt.id = template_exercises.template_id
        AND (
          rt.owner = (SELECT auth.uid())
          OR rt."clientId" = (SELECT auth.uid())
          OR EXISTS (
            SELECT 1
            FROM public.coach_clients cc
            WHERE cc.coach_id = (SELECT auth.uid())
              AND cc.client_id IS NOT DISTINCT FROM rt."clientId"
          )
        )
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.routine_templates rt
      WHERE rt.id = template_exercises.template_id
        AND (
          rt.owner = (SELECT auth.uid())
          OR rt."clientId" = (SELECT auth.uid())
          OR EXISTS (
            SELECT 1
            FROM public.coach_clients cc
            WHERE cc.coach_id = (SELECT auth.uid())
              AND cc.client_id IS NOT DISTINCT FROM rt."clientId"
          )
        )
    )
  );
