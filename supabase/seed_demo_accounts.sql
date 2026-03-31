-- =============================================================================
-- Demo Accounts Seed Script for App Store Review
-- =============================================================================
-- Prereqs
--   1. Supabase Dashboard → Authentication → Users → create (or recreate):
--        coach@ware.health   password: demo123456
--        client@ware.health  password: demo123456
--   2. Email confirmation: off for these users, or mark emails confirmed.
--   3. public.coaches: demo coach row must have active = true (see INSERT below).
--
-- Run: Supabase Dashboard → SQL Editor → paste this entire file → Run.
-- Re-running deletes prior demo-linked rows for these two users and repopulates.
--
-- Subscription (client app): Access is decided by RevenueCat (sandbox purchase /
-- Test Store). This script only touches Supabase — see docs/APP_REVIEW.md for review flow.
--
-- Schema note: workout_sessions.template_id is NOT NULL (migrations).
-- session_exercises.template_exercise_id links to template_exercises for the
-- same behavior as logs created in the app (e.g. coach instruction video path).
--
-- Time data: everything is anchored to when you run this script (current_date / now()).
-- Workout and nutrition rows use per-day timestamps so lists and history look realistic.
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
  te_upper_bench uuid;
  te_upper_row uuid;
  te_lower_squat uuid;
  te_lower_rdl uuid;
  te_full_deadlift uuid;
  log_id uuid;
  -- Prefix avoids PL/pgSQL ambiguity with table column session_sets.session_exercise_id
  v_se_id uuid;
  i int;
  log_date date;
  -- ~60-day workout history ending today, one session every 2 days (30 logs).
  start_date date := current_date - 60;
  end_date date := current_date;
  session_end_ts timestamptz;
  breakfast_ts timestamptz;
  lunch_ts timestamptz;
  dinner_ts timestamptz;
BEGIN
  SELECT id INTO coach_uuid FROM auth.users WHERE lower(email) = lower('coach@ware.health') LIMIT 1;
  SELECT id INTO client_uuid FROM auth.users WHERE lower(email) = lower('client@ware.health') LIMIT 1;

  IF coach_uuid IS NULL OR client_uuid IS NULL THEN
    RAISE EXCEPTION 'Demo users must exist first. Create coach@ware.health and client@ware.health in Supabase Dashboard → Authentication → Users (password demo123456).';
  END IF;

  -- ---------------------------------------------------------------------------
  -- Remove existing demo data (FK-safe order)
  -- ---------------------------------------------------------------------------
  DELETE FROM public.session_sets ss
  WHERE ss.session_exercise_id IN (
    SELECT se.id
    FROM public.session_exercises se
    JOIN public.workout_sessions ws ON ws.id = se.session_id
    WHERE ws.user_id = client_uuid
  );

  DELETE FROM public.session_exercises
  WHERE session_id IN (SELECT id FROM public.workout_sessions WHERE user_id = client_uuid);

  DELETE FROM public.workout_sessions WHERE user_id = client_uuid;

  DELETE FROM public.exercise_alternatives
  WHERE template_exercise_id IN (
    SELECT te.id
    FROM public.template_exercises te
    JOIN public.routine_templates rt ON rt.id = te.template_id
    WHERE rt.owner = coach_uuid OR rt."clientId" = client_uuid
  );

  DELETE FROM public.template_sets
  WHERE template_exercise_id IN (
    SELECT te.id
    FROM public.template_exercises te
    JOIN public.routine_templates rt ON rt.id = te.template_id
    WHERE rt.owner = coach_uuid OR rt."clientId" = client_uuid
  );

  DELETE FROM public.template_exercises
  WHERE template_id IN (
    SELECT id FROM public.routine_templates
    WHERE owner = coach_uuid OR "clientId" = client_uuid
  );

  DELETE FROM public.routine_templates
  WHERE owner = coach_uuid OR "clientId" = client_uuid;

  DELETE FROM public.routine_plans
  WHERE owner = coach_uuid OR "clientId" = client_uuid;

  DELETE FROM public.nutrition_logs WHERE user_id = client_uuid;
  DELETE FROM public.nutrition_templates WHERE client_id = client_uuid OR owner = coach_uuid;
  DELETE FROM public.coach_clients WHERE coach_id = coach_uuid AND client_id = client_uuid;

  -- ---------------------------------------------------------------------------
  -- Core rows
  -- ---------------------------------------------------------------------------
  INSERT INTO public.coaches (id, email, name, active)
  VALUES (coach_uuid, 'coach@ware.health', 'Demo Coach', true)
  ON CONFLICT (id) DO UPDATE SET
    email = EXCLUDED.email,
    name = EXCLUDED.name,
    active = true;

  -- public.clients: id, email, name only (no is_active — see migrations).
  INSERT INTO public.clients (id, email, name)
  VALUES (client_uuid, 'client@ware.health', 'Demo Client')
  ON CONFLICT (id) DO UPDATE SET email = EXCLUDED.email, name = EXCLUDED.name;

  INSERT INTO public.coach_clients (coach_id, client_id)
  VALUES (coach_uuid, client_uuid)
  ON CONFLICT (coach_id, client_id) DO NOTHING;

  INSERT INTO public.routine_plans (id, name, notes, owner, "clientId", "createdAt")
  VALUES
    (plan1_id, 'Strength Builder', 'Focus on compound lifts', coach_uuid, client_uuid, now()),
    (plan2_id, 'Hybrid Training', 'Mix of strength and cardio', coach_uuid, NULL, now())
  ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, notes = EXCLUDED.notes;

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

  INSERT INTO public.routine_templates (id, "planId", name, notes, owner, "clientId", "createdAt", "updatedAt")
  VALUES
    (template1_id, plan1_id, 'Upper Body', '', coach_uuid, client_uuid, now(), now()),
    (template2_id, plan1_id, 'Lower Body', '', coach_uuid, client_uuid, now(), now()),
    (template3_id, plan2_id, 'Full Body', '', coach_uuid, NULL, now(), now())
  ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, notes = EXCLUDED.notes, "updatedAt" = now();

  INSERT INTO public.template_exercises (template_id, exercise_id, order_index, super_set_group, notes)
  VALUES
    (template1_id, 'ex-bench-press-db', 0, NULL, ''),
    (template1_id, 'ex-row-bent-over-db', 1, NULL, ''),
    (template2_id, 'ex-squat-db', 0, NULL, ''),
    (template2_id, 'ex-deadlift-romanian-db', 1, NULL, ''),
    (template3_id, 'ex-deadlift-db', 0, NULL, '')
  ON CONFLICT (template_id, order_index) DO UPDATE
  SET exercise_id = EXCLUDED.exercise_id,
      notes = EXCLUDED.notes;

  SELECT id INTO te_upper_bench FROM public.template_exercises WHERE template_id = template1_id AND order_index = 0;
  SELECT id INTO te_upper_row FROM public.template_exercises WHERE template_id = template1_id AND order_index = 1;
  SELECT id INTO te_lower_squat FROM public.template_exercises WHERE template_id = template2_id AND order_index = 0;
  SELECT id INTO te_lower_rdl FROM public.template_exercises WHERE template_id = template2_id AND order_index = 1;
  SELECT id INTO te_full_deadlift FROM public.template_exercises WHERE template_id = template3_id AND order_index = 0;

  INSERT INTO public.template_sets (template_exercise_id, target_reps, target_weight, order_index)
  VALUES
    (te_upper_bench, 10, 60, 0),
    (te_upper_bench, 8, 60, 1),
    (te_upper_row, 12, 25, 0),
    (te_upper_row, 10, 27, 1),
    (te_lower_squat, 8, 80, 0),
    (te_lower_squat, 8, 80, 1),
    (te_lower_rdl, 10, 70, 0),
    (te_full_deadlift, 5, 100, 0)
  ON CONFLICT (template_exercise_id, order_index) DO UPDATE
  SET target_reps = EXCLUDED.target_reps,
      target_weight = EXCLUDED.target_weight;

  -- Workout sessions (~60 days, every 2 days) with coach_note on the most recent sessions
  FOR i IN 1..30 LOOP
    log_date := start_date + (i * 2);
    EXIT WHEN log_date > end_date;
    log_id := gen_random_uuid();
    session_end_ts := (log_date + time '10:15')::timestamptz;

    INSERT INTO public.workout_sessions (id, user_id, template_id, name, notes, coach_note, start_time, end_time, created_at, updated_at)
    VALUES (
      log_id,
      client_uuid,
      (CASE WHEN i % 2 = 0 THEN template1_id ELSE template2_id END),
      CASE WHEN i % 2 = 0 THEN 'Upper Body' ELSE 'Lower Body' END,
      '',
      CASE
        WHEN log_date >= current_date - 2 THEN 'Great consistency this week. Try adding one more set on bench next session.'
        WHEN log_date >= current_date - 4 THEN 'Solid lower body work. Squat depth looked good.'
        WHEN log_date >= current_date - 6 THEN 'Nice progress on rows. Keep it up!'
        ELSE NULL
      END,
      (log_date + time '09:00')::timestamptz,
      session_end_ts,
      session_end_ts,
      session_end_ts
    )
    ON CONFLICT (id) DO NOTHING;

    IF i % 2 = 0 THEN
      INSERT INTO public.session_exercises (session_id, exercise_id, template_exercise_id, order_index, super_set_group, notes)
      VALUES
        (log_id, 'ex-bench-press-db', te_upper_bench, 0, NULL, ''),
        (log_id, 'ex-row-bent-over-db', te_upper_row, 1, NULL, '');

      SELECT id INTO v_se_id FROM public.session_exercises WHERE session_id = log_id AND order_index = 0;
      INSERT INTO public.session_sets (session_exercise_id, reps, weight, is_completed, order_index)
      VALUES
        (v_se_id, 10, 60, true, 0),
        (v_se_id, 8, 62, true, 1);

      SELECT id INTO v_se_id FROM public.session_exercises WHERE session_id = log_id AND order_index = 1;
      INSERT INTO public.session_sets (session_exercise_id, reps, weight, is_completed, order_index)
      VALUES
        (v_se_id, 12, 25, true, 0),
        (v_se_id, 10, 27, true, 1);
    ELSE
      INSERT INTO public.session_exercises (session_id, exercise_id, template_exercise_id, order_index, super_set_group, notes)
      VALUES
        (log_id, 'ex-squat-db', te_lower_squat, 0, NULL, ''),
        (log_id, 'ex-deadlift-romanian-db', te_lower_rdl, 1, NULL, '');

      SELECT id INTO v_se_id FROM public.session_exercises WHERE session_id = log_id AND order_index = 0;
      INSERT INTO public.session_sets (session_exercise_id, reps, weight, is_completed, order_index)
      VALUES
        (v_se_id, 8, 80, true, 0),
        (v_se_id, 8, 82, true, 1);

      SELECT id INTO v_se_id FROM public.session_exercises WHERE session_id = log_id AND order_index = 1;
      INSERT INTO public.session_sets (session_exercise_id, reps, weight, is_completed, order_index)
      VALUES
        (v_se_id, 10, 70, true, 0);
    END IF;
  END LOOP;

  INSERT INTO public.nutrition_templates (id, owner, client_id, calories_kcal, protein_g, carbs_g, fats_g, created_at, updated_at)
  VALUES (nutrition_template_id, coach_uuid, client_uuid, 3950, 250, 400, 150, now(), now())
  ON CONFLICT (id) DO UPDATE SET
    calories_kcal = EXCLUDED.calories_kcal,
    protein_g = EXCLUDED.protein_g,
    carbs_g = EXCLUDED.carbs_g,
    fats_g = EXCLUDED.fats_g,
    updated_at = now();

  -- Nutrition: last 46 days through today (3 meals/day), timestamps match each log
  FOR i IN 0..45 LOOP
    log_date := (current_date - 45) + i;
    EXIT WHEN log_date > end_date;
    breakfast_ts := (log_date + time '08:30')::timestamptz;
    lunch_ts := (log_date + time '13:00')::timestamptz;
    dinner_ts := (log_date + time '19:00')::timestamptz;
    INSERT INTO public.nutrition_logs (id, user_id, food_name, protein_g, carbs_g, fats_g, logged_at, created_at, updated_at)
    VALUES
      (gen_random_uuid(), client_uuid, 'Breakfast - Oatmeal & Eggs', 25, 45, 12, breakfast_ts, breakfast_ts, breakfast_ts),
      (gen_random_uuid(), client_uuid, 'Lunch - Chicken Salad', 35, 20, 15, lunch_ts, lunch_ts, lunch_ts),
      (gen_random_uuid(), client_uuid, 'Dinner - Salmon & Rice', 40, 60, 18, dinner_ts, dinner_ts, dinner_ts);
  END LOOP;

  RAISE NOTICE 'Demo seed completed. coach=%, client=%', coach_uuid, client_uuid;
END $$;
