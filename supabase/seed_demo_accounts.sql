-- =============================================================================
-- Demo Accounts Seed Script for App Store Review
-- =============================================================================
-- Run this script AFTER creating the demo auth users in Supabase Dashboard:
--   1. Authentication > Users > Add user
--   2. Create coach@ware.health with password: demo123456
--   3. Create client@ware.health with password: demo123456
--
-- Data is populated up to 2026-02-03 for both coach and client.
-- Re-running this script deletes existing demo data and repopulates (full overwrite).
-- =============================================================================

DO $$
DECLARE
  coach_uuid uuid;
  client_uuid uuid;
  plan1_id uuid := gen_random_uuid();
  plan2_id uuid := gen_random_uuid();
  template1_id uuid := gen_random_uuid();
  template2_id uuid := gen_random_uuid();
  template3_id uuid := gen_random_uuid();
  nutrition_template_id uuid := gen_random_uuid();
  log_id uuid;
  i int;
  log_date date;
BEGIN
  -- Get user IDs
  SELECT id INTO coach_uuid FROM auth.users WHERE email = 'coach@ware.health' LIMIT 1;
  SELECT id INTO client_uuid FROM auth.users WHERE email = 'client@ware.health' LIMIT 1;

  IF coach_uuid IS NULL OR client_uuid IS NULL THEN
    RAISE EXCEPTION 'Demo users must exist first. Create coach@ware.health and client@ware.health in Supabase Dashboard > Authentication > Users.';
  END IF;

  -- Delete existing demo data (order respects foreign keys)
  DELETE FROM public.routine_logs WHERE owner = client_uuid;
  DELETE FROM public.routine_templates WHERE owner = coach_uuid OR "clientId" = client_uuid;
  DELETE FROM public.routine_plans WHERE owner = coach_uuid OR "clientId" = client_uuid;
  DELETE FROM public.nutrition_logs WHERE user_id = client_uuid;
  DELETE FROM public.nutrition_templates WHERE client_id = client_uuid OR owner = coach_uuid;
  DELETE FROM public.coach_clients WHERE coach_id = coach_uuid AND client_id = client_uuid;

  -- Upsert coaches table (if exists)
  INSERT INTO public.coaches (id, email, name)
  VALUES (coach_uuid, 'coach@ware.health', 'Demo Coach')
  ON CONFLICT (id) DO UPDATE SET email = EXCLUDED.email, name = EXCLUDED.name;

  -- Upsert clients table (if exists). Demo client must be active to sign in.
  INSERT INTO public.clients (id, email, name, is_active)
  VALUES (client_uuid, 'client@ware.health', 'Demo Client', true)
  ON CONFLICT (id) DO UPDATE SET email = EXCLUDED.email, name = EXCLUDED.name, is_active = true;

  -- Coach-client relationship
  INSERT INTO public.coach_clients (coach_id, client_id)
  VALUES (coach_uuid, client_uuid)
  ON CONFLICT (coach_id, client_id) DO NOTHING;

  -- Routine plans (coach owns both; plan1 assigned to client)
  INSERT INTO public.routine_plans (id, name, notes, owner, "clientId", "createdAt")
  VALUES
    (plan1_id, 'Strength Builder', 'Focus on compound lifts', coach_uuid, client_uuid, now()),
    (plan2_id, 'Hybrid Training', 'Mix of strength and cardio', coach_uuid, NULL, now())
  ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, notes = EXCLUDED.notes;

  -- Routine templates (workouts) - using real exercises from lottie_exercises.json
  INSERT INTO public.routine_templates (id, "planId", name, notes, owner, "clientId", exercises, "createdAt")
  VALUES
    (template1_id, plan1_id, 'Upper Body', '', coach_uuid, client_uuid,
     '[
       {"superSetId":"","exercise":{"id":"ex-bench-press-db","name":"Bench Press (Dumbbell)","type":"WR","notes":"","isSystem":true},"notes":"","sets":[{"weight":60,"reps":10,"checked":true},{"weight":60,"reps":8,"checked":true}],"alternatives":[]},
       {"superSetId":"","exercise":{"id":"ex-row-bent-over-db","name":"Row (Bent-Over, Dumbbell)","type":"WR","notes":"","isSystem":true},"notes":"","sets":[{"weight":25,"reps":12,"checked":true},{"weight":27,"reps":10,"checked":true}],"alternatives":[]}
     ]'::jsonb, now()),
    (template2_id, plan1_id, 'Lower Body', '', coach_uuid, client_uuid,
     '[
       {"superSetId":"","exercise":{"id":"ex-squat-db","name":"Squat (Dumbbell)","type":"WR","notes":"","isSystem":true},"notes":"","sets":[{"weight":80,"reps":8,"checked":true},{"weight":80,"reps":8,"checked":true}],"alternatives":[]},
       {"superSetId":"","exercise":{"id":"ex-deadlift-romanian-db","name":"Deadlift (Romanian, Dumbbell)","type":"WR","notes":"","isSystem":true},"notes":"","sets":[{"weight":70,"reps":10,"checked":true}],"alternatives":[]}
     ]'::jsonb, now()),
    (template3_id, plan2_id, 'Full Body', '', coach_uuid, NULL,
     '[
       {"superSetId":"","exercise":{"id":"ex-deadlift-db","name":"Deadlift (Dumbbell)","type":"WR","notes":"","isSystem":true},"notes":"","sets":[{"weight":100,"reps":5,"checked":true}],"alternatives":[]}
     ]'::jsonb, now())
  ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, exercises = EXCLUDED.exercises;

  -- Routine logs for client - spread from mid-Jan 2026 to Feb 3, 2026 (using real exercises from library)
  FOR i IN 1..12 LOOP
    log_date := date '2026-01-15' + (i * 2);
    EXIT WHEN log_date > date '2026-02-03';
    log_id := gen_random_uuid();
    INSERT INTO public.routine_logs (id, "templateId", name, notes, "startTime", "endTime", exercises, owner, "createdAt")
    VALUES (
      log_id,
      (CASE WHEN i % 2 = 0 THEN template1_id ELSE template2_id END)::text,
      CASE WHEN i % 2 = 0 THEN 'Upper Body' ELSE 'Lower Body' END,
      '',
      (log_date + time '09:00')::timestamptz,
      (log_date + time '10:15')::timestamptz,
      CASE WHEN i % 2 = 0 THEN
        '[{"superSetId":"","exercise":{"id":"ex-bench-press-db","name":"Bench Press (Dumbbell)","type":"WR","notes":"","isSystem":true},"notes":"","sets":[{"weight":60,"reps":10,"checked":true},{"weight":62,"reps":8,"checked":true}],"alternatives":[]},{"superSetId":"","exercise":{"id":"ex-row-bent-over-db","name":"Row (Bent-Over, Dumbbell)","type":"WR","notes":"","isSystem":true},"notes":"","sets":[{"weight":25,"reps":12,"checked":true},{"weight":27,"reps":10,"checked":true}],"alternatives":[]}]'
      ELSE
        '[{"superSetId":"","exercise":{"id":"ex-squat-db","name":"Squat (Dumbbell)","type":"WR","notes":"","isSystem":true},"notes":"","sets":[{"weight":80,"reps":8,"checked":true},{"weight":82,"reps":8,"checked":true}],"alternatives":[]},{"superSetId":"","exercise":{"id":"ex-deadlift-romanian-db","name":"Deadlift (Romanian, Dumbbell)","type":"WR","notes":"","isSystem":true},"notes":"","sets":[{"weight":70,"reps":10,"checked":true}],"alternatives":[]}]'
      END::jsonb,
      client_uuid,
      now()
    )
    ON CONFLICT (id) DO NOTHING;
  END LOOP;

  -- Nutrition template for client (macro targets set by coach)
  INSERT INTO public.nutrition_templates (id, owner, client_id, calories_kcal, protein_g, carbs_g, fats_g, created_at, updated_at)
  VALUES (nutrition_template_id, coach_uuid, client_uuid, 2200, 150, 250, 75, now(), now())
  ON CONFLICT (id) DO UPDATE SET calories_kcal = EXCLUDED.calories_kcal, protein_g = EXCLUDED.protein_g, carbs_g = EXCLUDED.carbs_g, fats_g = EXCLUDED.fats_g, updated_at = now();

  -- Nutrition logs for client - sample entries up to Feb 3, 2026
  FOR i IN 0..14 LOOP
    log_date := date '2026-01-20' + i;
    EXIT WHEN log_date > date '2026-02-03';
    INSERT INTO public.nutrition_logs (user_id, food_name, protein_g, carbs_g, fats_g, logged_at)
    VALUES
      (client_uuid, 'Breakfast - Oatmeal & Eggs', 25, 45, 12, (log_date + time '08:30')::timestamptz),
      (client_uuid, 'Lunch - Chicken Salad', 35, 20, 15, (log_date + time '13:00')::timestamptz),
      (client_uuid, 'Dinner - Salmon & Rice', 40, 60, 18, (log_date + time '19:00')::timestamptz);
  END LOOP;

  RAISE NOTICE 'Demo seed completed. Coach: %, Client: %', coach_uuid, client_uuid;
END $$;
