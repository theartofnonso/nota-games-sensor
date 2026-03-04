-- =============================================================================
-- Demo Accounts Seed Script for App Store Review
-- =============================================================================
-- Run this script AFTER creating the demo auth users in Supabase Dashboard:
--   1. Authentication > Users > Add user
--   2. Create coach@ware.health with password: demo123456
--   3. Create client@ware.health with password: demo123456
--
-- Data is populated for the past ~40 days up to current date.
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
  session_exercise_id uuid;
  i int;
  log_date date;
  start_date date := current_date - 40;
  end_date date := current_date;
BEGIN
  -- Get user IDs
  SELECT id INTO coach_uuid FROM auth.users WHERE email = 'coach@ware.health' LIMIT 1;
  SELECT id INTO client_uuid FROM auth.users WHERE email = 'client@ware.health' LIMIT 1;

  IF coach_uuid IS NULL OR client_uuid IS NULL THEN
    RAISE EXCEPTION 'Demo users must exist first. Create coach@ware.health and client@ware.health in Supabase Dashboard > Authentication > Users.';
  END IF;

  -- Delete existing demo data (order respects foreign keys)
  DELETE FROM public.workout_sessions WHERE user_id = client_uuid;
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

  -- Canonical exercises used by seeded templates/sessions
  INSERT INTO public.exercises (id, name, type, lottie_path, created_at)
  VALUES
    ('ex-bench-press-db', 'Bench Press (Dumbbell)', 'WR', 'assets/lottie/Man Doing Dumbbell Bench Press Exercise for Chest.json', now()),
    ('ex-row-bent-over-db', 'Row (Bent-Over, Dumbbell)', 'WR', 'assets/lottie/Man Doing Dumbbell Bent Over Row Exercise for Back.json', now()),
    ('ex-squat-db', 'Squat (Dumbbell)', 'WR', 'assets/lottie/Man Doing Dumbbell Squat Exercise For Legs.json', now()),
    ('ex-deadlift-romanian-db', 'Deadlift (Romanian, Dumbbell)', 'WR', 'assets/lottie/Man Doing Romanian Dumbbell Deadlift Exercise for Legs.json', now()),
    ('ex-deadlift-db', 'Deadlift (Dumbbell)', 'WR', 'assets/lottie/Man Doing Dumbbell Deadlift Exercise for Legs.json', now())
  ON CONFLICT (id) DO UPDATE
  SET name = EXCLUDED.name,
      type = EXCLUDED.type,
      lottie_path = EXCLUDED.lottie_path;

  -- Routine templates (headers)
  INSERT INTO public.routine_templates (id, "planId", name, notes, owner, "clientId", "createdAt")
  VALUES
    (template1_id, plan1_id, 'Upper Body', '', coach_uuid, client_uuid, now()),
    (template2_id, plan1_id, 'Lower Body', '', coach_uuid, client_uuid, now()),
    (template3_id, plan2_id, 'Full Body', '', coach_uuid, NULL, now())
  ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, notes = EXCLUDED.notes;

  -- Template exercises
  INSERT INTO public.template_exercises (template_id, exercise_id, order_index, super_set_group, notes)
  VALUES
    (template1_id, 'ex-bench-press-db', 0, NULL, ''),
    (template1_id, 'ex-row-bent-over-db', 1, NULL, ''),
    (template2_id, 'ex-squat-db', 0, NULL, ''),
    (template2_id, 'ex-deadlift-romanian-db', 1, NULL, ''),
    (template3_id, 'ex-deadlift-db', 0, NULL, '')
  ON CONFLICT (template_id, order_index) DO UPDATE
  SET exercise_id = EXCLUDED.exercise_id;

  -- Template sets
  INSERT INTO public.template_sets (template_exercise_id, target_reps, target_weight, order_index)
  VALUES
    ((SELECT id FROM public.template_exercises WHERE template_id = template1_id AND order_index = 0), 10, 60, 0),
    ((SELECT id FROM public.template_exercises WHERE template_id = template1_id AND order_index = 0), 8, 60, 1),
    ((SELECT id FROM public.template_exercises WHERE template_id = template1_id AND order_index = 1), 12, 25, 0),
    ((SELECT id FROM public.template_exercises WHERE template_id = template1_id AND order_index = 1), 10, 27, 1),
    ((SELECT id FROM public.template_exercises WHERE template_id = template2_id AND order_index = 0), 8, 80, 0),
    ((SELECT id FROM public.template_exercises WHERE template_id = template2_id AND order_index = 0), 8, 80, 1),
    ((SELECT id FROM public.template_exercises WHERE template_id = template2_id AND order_index = 1), 10, 70, 0),
    ((SELECT id FROM public.template_exercises WHERE template_id = template3_id AND order_index = 0), 5, 100, 0)
  ON CONFLICT (template_exercise_id, order_index) DO UPDATE
  SET target_reps = EXCLUDED.target_reps,
      target_weight = EXCLUDED.target_weight;

  -- Workout sessions for client - spread over past ~40 days (every 2 days) up to today
  FOR i IN 1..20 LOOP
    log_date := start_date + (i * 2);
    EXIT WHEN log_date > end_date;
    log_id := gen_random_uuid();

    INSERT INTO public.workout_sessions (id, user_id, template_id, name, notes, coach_note, start_time, end_time, created_at, updated_at)
    VALUES (
      log_id,
      client_uuid,
      (CASE WHEN i % 2 = 0 THEN template1_id ELSE template2_id END),
      CASE WHEN i % 2 = 0 THEN 'Upper Body' ELSE 'Lower Body' END,
      '',
      NULL,
      (log_date + time '09:00')::timestamptz,
      (log_date + time '10:15')::timestamptz,
      now(),
      now()
    )
    ON CONFLICT (id) DO NOTHING;

    IF i % 2 = 0 THEN
      INSERT INTO public.session_exercises (session_id, exercise_id, template_exercise_id, order_index, super_set_group, notes)
      VALUES
        (log_id, 'ex-bench-press-db', NULL, 0, NULL, ''),
        (log_id, 'ex-row-bent-over-db', NULL, 1, NULL, '');

      SELECT id INTO session_exercise_id
      FROM public.session_exercises
      WHERE session_id = log_id AND order_index = 0;
      INSERT INTO public.session_sets (session_exercise_id, reps, weight, is_completed, order_index)
      VALUES
        (session_exercise_id, 10, 60, true, 0),
        (session_exercise_id, 8, 62, true, 1);

      SELECT id INTO session_exercise_id
      FROM public.session_exercises
      WHERE session_id = log_id AND order_index = 1;
      INSERT INTO public.session_sets (session_exercise_id, reps, weight, is_completed, order_index)
      VALUES
        (session_exercise_id, 12, 25, true, 0),
        (session_exercise_id, 10, 27, true, 1);
    ELSE
      INSERT INTO public.session_exercises (session_id, exercise_id, template_exercise_id, order_index, super_set_group, notes)
      VALUES
        (log_id, 'ex-squat-db', NULL, 0, NULL, ''),
        (log_id, 'ex-deadlift-romanian-db', NULL, 1, NULL, '');

      SELECT id INTO session_exercise_id
      FROM public.session_exercises
      WHERE session_id = log_id AND order_index = 0;
      INSERT INTO public.session_sets (session_exercise_id, reps, weight, is_completed, order_index)
      VALUES
        (session_exercise_id, 8, 80, true, 0),
        (session_exercise_id, 8, 82, true, 1);

      SELECT id INTO session_exercise_id
      FROM public.session_exercises
      WHERE session_id = log_id AND order_index = 1;
      INSERT INTO public.session_sets (session_exercise_id, reps, weight, is_completed, order_index)
      VALUES
        (session_exercise_id, 10, 70, true, 0);
    END IF;
  END LOOP;

  -- Nutrition template for client (macro targets set by coach)
  INSERT INTO public.nutrition_templates (id, owner, client_id, calories_kcal, protein_g, carbs_g, fats_g, created_at, updated_at)
  VALUES (nutrition_template_id, coach_uuid, client_uuid, 2200, 150, 250, 75, now(), now())
  ON CONFLICT (id) DO UPDATE SET calories_kcal = EXCLUDED.calories_kcal, protein_g = EXCLUDED.protein_g, carbs_g = EXCLUDED.carbs_g, fats_g = EXCLUDED.fats_g, updated_at = now();

  -- Nutrition logs for client - sample entries for past ~30 days up to today
  FOR i IN 0..30 LOOP
    log_date := (current_date - 30) + i;
    EXIT WHEN log_date > end_date;
    INSERT INTO public.nutrition_logs (user_id, food_name, protein_g, carbs_g, fats_g, logged_at)
    VALUES
      (client_uuid, 'Breakfast - Oatmeal & Eggs', 25, 45, 12, (log_date + time '08:30')::timestamptz),
      (client_uuid, 'Lunch - Chicken Salad', 35, 20, 15, (log_date + time '13:00')::timestamptz),
      (client_uuid, 'Dinner - Salmon & Rice', 40, 60, 18, (log_date + time '19:00')::timestamptz);
  END LOOP;

  RAISE NOTICE 'Demo seed completed. Coach: %, Client: %', coach_uuid, client_uuid;
END $$;
