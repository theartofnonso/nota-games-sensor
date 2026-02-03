-- =============================================================================
-- Demo Accounts Seed Script for App Store Review
-- =============================================================================
-- Run this script AFTER creating the demo auth users in Supabase Dashboard:
--   1. Authentication > Users > Add user
--   2. Create coach@ware.health with password: demo123456
--   3. Create client@ware.health with password: demo123456
--
-- Data is populated up to 2026-02-03 for both coach and client.
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

  -- Upsert coaches table (if exists)
  INSERT INTO public.coaches (id, email, name)
  VALUES (coach_uuid, 'coach@ware.health', 'Demo Coach')
  ON CONFLICT (id) DO UPDATE SET email = EXCLUDED.email, name = EXCLUDED.name;

  -- Upsert clients table (if exists)
  INSERT INTO public.clients (id, email, name)
  VALUES (client_uuid, 'client@ware.health', 'Demo Client')
  ON CONFLICT (id) DO UPDATE SET email = EXCLUDED.email, name = EXCLUDED.name;

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

  -- Routine templates (workouts) - sample exercise structure
  INSERT INTO public.routine_templates (id, "planId", name, notes, owner, "clientId", exercises, "createdAt")
  VALUES
    (template1_id, plan1_id, 'Upper Body', '', coach_uuid, client_uuid,
     '[
       {"superSetId":"","exercise":{"id":"ex1","name":"Bench Press","type":"WR","notes":"","isSystem":false},"notes":"","sets":[{"value1":60,"value2":10,"checked":true},{"value1":60,"value2":8,"checked":true}],"alternatives":[]},
       {"superSetId":"","exercise":{"id":"ex2","name":"Pull-ups","type":"BW","notes":"","isSystem":false},"notes":"","sets":[{"value1":0,"value2":12,"checked":true},{"value1":0,"value2":10,"checked":true}],"alternatives":[]}
     ]'::jsonb, now()),
    (template2_id, plan1_id, 'Lower Body', '', coach_uuid, client_uuid,
     '[
       {"superSetId":"","exercise":{"id":"ex3","name":"Squat","type":"WR","notes":"","isSystem":false},"notes":"","sets":[{"value1":80,"value2":8,"checked":true},{"value1":80,"value2":8,"checked":true}],"alternatives":[]},
       {"superSetId":"","exercise":{"id":"ex4","name":"Romanian Deadlift","type":"WR","notes":"","isSystem":false},"notes":"","sets":[{"value1":70,"value2":10,"checked":true}],"alternatives":[]}
     ]'::jsonb, now()),
    (template3_id, plan2_id, 'Full Body', '', coach_uuid, NULL,
     '[
       {"superSetId":"","exercise":{"id":"ex5","name":"Deadlift","type":"WR","notes":"","isSystem":false},"notes":"","sets":[{"value1":100,"value2":5,"checked":true}],"alternatives":[]}
     ]'::jsonb, now())
  ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, exercises = EXCLUDED.exercises;

  -- Routine logs for client - spread from mid-Jan 2026 to Feb 3, 2026
  FOR i IN 1..12 LOOP
    log_date := date '2026-01-15' + (i * 2);
    EXIT WHEN log_date > date '2026-02-03';
    log_id := gen_random_uuid();
    INSERT INTO public.routine_logs (id, "templateId", name, "startTime", "endTime", exercises, owner, "createdAt")
    VALUES (
      log_id,
      CASE WHEN i % 2 = 0 THEN template1_id ELSE template2_id END,
      CASE WHEN i % 2 = 0 THEN 'Upper Body' ELSE 'Lower Body' END,
      (log_date + time '09:00')::timestamptz,
      (log_date + time '10:15')::timestamptz,
      '[
        {"superSetId":"","exercise":{"id":"ex1","name":"Bench Press","type":"WR","notes":"","isSystem":false},"notes":"","sets":[{"value1":60,"value2":10,"checked":true},{"value1":62,"value2":8,"checked":true}],"alternatives":[]},
        {"superSetId":"","exercise":{"id":"ex2","name":"Pull-ups","type":"BW","notes":"","isSystem":false},"notes":"","sets":[{"value1":0,"value2":12,"checked":true},{"value1":0,"value2":10,"checked":true}],"alternatives":[]}
      ]'::jsonb,
      client_uuid,
      now()
    )
    ON CONFLICT (id) DO NOTHING;
  END LOOP;

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
