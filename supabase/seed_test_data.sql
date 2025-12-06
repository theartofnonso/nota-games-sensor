-- ============================================================================
-- SEED TEST DATA FOR APP STORE REVIEW
-- ============================================================================
-- This script populates test data for the test account
-- Owner ID: f997b7ab-fe1b-4530-a190-0967119aedea
-- ============================================================================

-- Owner ID constant (replace all 'f997b7ab-fe1b-4530-a190-0967119aedea' with this UUID)
-- f997b7ab-fe1b-4530-a190-0967119aedea

-- ============================================================================
-- EXERCISES
-- ============================================================================

-- Upper body - weights
INSERT INTO public.exercises (id, owner, name, type, "primaryMuscleGroup", notes, "createdAt", "updatedAt") VALUES
('8aafa06d-9f42-4946-ba18-f027fe792100', 'f997b7ab-fe1b-4530-a190-0967119aedea', 'Bench Press', 'WR', 'chest', '', NOW() - INTERVAL '90 days', NOW() - INTERVAL '90 days'),
('d9b6d428-3bc7-4f68-bebb-d32287f13257', 'f997b7ab-fe1b-4530-a190-0967119aedea', 'Incline Dumbbell Press', 'WR', 'chest', '', NOW() - INTERVAL '89 days', NOW() - INTERVAL '89 days'),
('b824e690-5974-4634-b1bc-0cc31dda0804', 'f997b7ab-fe1b-4530-a190-0967119aedea', 'Barbell Row', 'WR', 'back', '', NOW() - INTERVAL '88 days', NOW() - INTERVAL '88 days'),
('956353a6-488b-4673-8f18-4ffcadd49ada', 'f997b7ab-fe1b-4530-a190-0967119aedea', 'Lat Pulldown', 'WR', 'lats', '', NOW() - INTERVAL '87 days', NOW() - INTERVAL '87 days'),
('6d7215a0-f88b-4b80-96dd-3b414a865f60', 'f997b7ab-fe1b-4530-a190-0967119aedea', 'Overhead Press', 'WR', 'frontShoulders', '', NOW() - INTERVAL '86 days', NOW() - INTERVAL '86 days'),
('2b14611a-b196-4f9a-948b-932b74a27963', 'f997b7ab-fe1b-4530-a190-0967119aedea', 'Lateral Raises', 'WR', 'frontShoulders', '', NOW() - INTERVAL '85 days', NOW() - INTERVAL '85 days'),
('dfd348e2-4267-4d3b-8f15-c39b48d50539', 'f997b7ab-fe1b-4530-a190-0967119aedea', 'Bicep Curls', 'WR', 'biceps', '', NOW() - INTERVAL '84 days', NOW() - INTERVAL '84 days'),
('a43373b9-86d7-4684-9d26-70ad1ec0039d', 'f997b7ab-fe1b-4530-a190-0967119aedea', 'Tricep Extensions', 'WR', 'triceps', '', NOW() - INTERVAL '83 days', NOW() - INTERVAL '83 days'),
('b11c784e-88bc-4bee-bda1-6bc3862f409b', 'f997b7ab-fe1b-4530-a190-0967119aedea', 'Shrugs', 'WR', 'traps', '', NOW() - INTERVAL '82 days', NOW() - INTERVAL '82 days'),
('afcb8f22-daac-46d8-9f19-d79cebe99ad1', 'f997b7ab-fe1b-4530-a190-0967119aedea', 'Cable Flyes', 'WR', 'chest', '', NOW() - INTERVAL '81 days', NOW() - INTERVAL '81 days'),

-- Lower body - weights
('44db316c-54d9-4f99-8d43-f6f324e49c84', 'f997b7ab-fe1b-4530-a190-0967119aedea', 'Squats', 'WR', 'quadriceps', '', NOW() - INTERVAL '80 days', NOW() - INTERVAL '80 days'),
('c8492040-383f-4e4a-9b58-e5cd04546c6c', 'f997b7ab-fe1b-4530-a190-0967119aedea', 'Deadlift', 'WR', 'back', '', NOW() - INTERVAL '79 days', NOW() - INTERVAL '79 days'),
('c2e0b60b-6e26-4e79-8435-e3e14cfd9625', 'f997b7ab-fe1b-4530-a190-0967119aedea', 'Leg Press', 'WR', 'quadriceps', '', NOW() - INTERVAL '78 days', NOW() - INTERVAL '78 days'),
('3b821ac0-c156-4d25-b185-d1fda4851b6a', 'f997b7ab-fe1b-4530-a190-0967119aedea', 'Romanian Deadlift', 'WR', 'hamstrings', '', NOW() - INTERVAL '77 days', NOW() - INTERVAL '77 days'),
('607192a7-8058-417f-94a7-eecc504c0f0b', 'f997b7ab-fe1b-4530-a190-0967119aedea', 'Leg Curls', 'WR', 'hamstrings', '', NOW() - INTERVAL '76 days', NOW() - INTERVAL '76 days'),
('3910de44-2d17-41ef-8c9d-355b982cf1ba', 'f997b7ab-fe1b-4530-a190-0967119aedea', 'Calf Raises', 'WR', 'calves', '', NOW() - INTERVAL '75 days', NOW() - INTERVAL '75 days'),
('70bf56e2-a7f7-4ed3-ac48-657d47c79d09', 'f997b7ab-fe1b-4530-a190-0967119aedea', 'Hip Thrusts', 'WR', 'glutes', '', NOW() - INTERVAL '74 days', NOW() - INTERVAL '74 days'),
('39829561-f5e5-447b-a1a3-e60fe09d01df', 'f997b7ab-fe1b-4530-a190-0967119aedea', 'Lunges', 'WR', 'quadriceps', '', NOW() - INTERVAL '73 days', NOW() - INTERVAL '73 days'),

-- Bodyweight
('036a8ced-28e0-4226-a9fb-42c471d9c8b4', 'f997b7ab-fe1b-4530-a190-0967119aedea', 'Pull-ups', 'BW', 'lats', '', NOW() - INTERVAL '72 days', NOW() - INTERVAL '72 days'),
('d803160e-c349-4bd6-a088-b8e32b76d16a', 'f997b7ab-fe1b-4530-a190-0967119aedea', 'Push-ups', 'BW', 'chest', '', NOW() - INTERVAL '71 days', NOW() - INTERVAL '71 days'),
('b07d66e0-49af-44bd-9f60-f981a6191928', 'f997b7ab-fe1b-4530-a190-0967119aedea', 'Dips', 'BW', 'triceps', '', NOW() - INTERVAL '70 days', NOW() - INTERVAL '70 days'),
('40627f58-929e-4c04-a39b-38a29cfe8cce', 'f997b7ab-fe1b-4530-a190-0967119aedea', 'Sit-ups', 'BW', 'abs', '', NOW() - INTERVAL '69 days', NOW() - INTERVAL '69 days'),
('b7eab7e4-28bb-4546-9cea-3fe25c639472', 'f997b7ab-fe1b-4530-a190-0967119aedea', 'Burpees', 'BW', 'fullBody', '', NOW() - INTERVAL '68 days', NOW() - INTERVAL '68 days'),

-- Duration
('6b3eeeba-6e16-41e8-96ee-9e47024e6b30', 'f997b7ab-fe1b-4530-a190-0967119aedea', 'Running', 'DR', 'fullBody', '', NOW() - INTERVAL '67 days', NOW() - INTERVAL '67 days'),
('102a4d61-b69d-40d0-9667-427edc6cd8d5', 'f997b7ab-fe1b-4530-a190-0967119aedea', 'Cycling', 'DR', 'quadriceps', '', NOW() - INTERVAL '66 days', NOW() - INTERVAL '66 days'),
('fba36c2d-e3ff-43c0-ab30-d4bed32364f0', 'f997b7ab-fe1b-4530-a190-0967119aedea', 'Rowing', 'DR', 'back', '', NOW() - INTERVAL '65 days', NOW() - INTERVAL '65 days'),
('1b972641-4272-48a9-be81-76b125f66f5f', 'f997b7ab-fe1b-4530-a190-0967119aedea', 'Plank', 'DR', 'abs', '', NOW() - INTERVAL '64 days', NOW() - INTERVAL '64 days')
ON CONFLICT (id) DO NOTHING;

-- ============================================================================
-- ROUTINE PLANS
-- ============================================================================

INSERT INTO public.routine_plans (id, owner, name, notes, "createdAt", "updatedAt") VALUES
('3e0e79b1-6fbe-436d-b9e7-4a7d4e19aa96', 'f997b7ab-fe1b-4530-a190-0967119aedea', 'Push Pull Legs', 'A comprehensive 6-day split focusing on push, pull, and leg movements', NOW() - INTERVAL '90 days', NOW() - INTERVAL '90 days'),
('7115de21-1ab7-400a-8b52-6ecfd6d4ede4', 'f997b7ab-fe1b-4530-a190-0967119aedea', 'Upper Lower', 'A 4-day split alternating between upper and lower body workouts', NOW() - INTERVAL '89 days', NOW() - INTERVAL '89 days'),
('74130dbe-179b-41ba-897a-ffc5f8283578', 'f997b7ab-fe1b-4530-a190-0967119aedea', 'Full Body', 'Complete body workouts for maximum efficiency', NOW() - INTERVAL '88 days', NOW() - INTERVAL '88 days'),
('40896f06-6f30-472e-b3be-35dbbf0d5729', 'f997b7ab-fe1b-4530-a190-0967119aedea', 'Strength Focus', 'Heavy compound movements for building strength', NOW() - INTERVAL '87 days', NOW() - INTERVAL '87 days')
ON CONFLICT (id) DO NOTHING;

-- ============================================================================
-- ROUTINE TEMPLATES
-- ============================================================================

-- Push Day template (plan001)
INSERT INTO public.routine_templates (id, owner, "planId", name, notes, exercises, "createdAt", "updatedAt") VALUES
('b9e2cf7e-9429-49b8-acc9-30dfc790b8b4', 'f997b7ab-fe1b-4530-a190-0967119aedea', '3e0e79b1-6fbe-436d-b9e7-4a7d4e19aa96', 'Push Day', 'Chest, shoulders, and triceps', 
 '[
   {"superSetId": "", "exercise": {"id": "8aafa06d-9f42-4946-ba18-f027fe792100", "name": "Bench Press", "type": "WR", "primaryMuscleGroup": "chest", "notes": ""}, "notes": "", "sets": [{"value1": 80, "value2": 10, "checked": false}, {"value1": 80, "value2": 10, "checked": false}, {"value1": 80, "value2": 8, "checked": false}]},
   {"superSetId": "", "exercise": {"id": "d9b6d428-3bc7-4f68-bebb-d32287f13257", "name": "Incline Dumbbell Press", "type": "WR", "primaryMuscleGroup": "chest", "notes": ""}, "notes": "", "sets": [{"value1": 30, "value2": 12, "checked": false}, {"value1": 30, "value2": 12, "checked": false}, {"value1": 30, "value2": 10, "checked": false}]},
   {"superSetId": "", "exercise": {"id": "6d7215a0-f88b-4b80-96dd-3b414a865f60", "name": "Overhead Press", "type": "WR", "primaryMuscleGroup": "frontShoulders", "notes": ""}, "notes": "", "sets": [{"value1": 50, "value2": 10, "checked": false}, {"value1": 50, "value2": 10, "checked": false}, {"value1": 50, "value2": 8, "checked": false}]},
   {"superSetId": "", "exercise": {"id": "2b14611a-b196-4f9a-948b-932b74a27963", "name": "Lateral Raises", "type": "WR", "primaryMuscleGroup": "frontShoulders", "notes": ""}, "notes": "", "sets": [{"value1": 15, "value2": 15, "checked": false}, {"value1": 15, "value2": 15, "checked": false}, {"value1": 15, "value2": 12, "checked": false}]},
   {"superSetId": "", "exercise": {"id": "a43373b9-86d7-4684-9d26-70ad1ec0039d", "name": "Tricep Extensions", "type": "WR", "primaryMuscleGroup": "triceps", "notes": ""}, "notes": "", "sets": [{"value1": 25, "value2": 12, "checked": false}, {"value1": 25, "value2": 12, "checked": false}, {"value1": 25, "value2": 10, "checked": false}]}
 ]'::jsonb,
 NOW() - INTERVAL '90 days', NOW() - INTERVAL '90 days'),

-- Pull Day template (plan001)
('98fbe1f7-04ca-44cb-95ae-f4ce23add290', 'f997b7ab-fe1b-4530-a190-0967119aedea', '3e0e79b1-6fbe-436d-b9e7-4a7d4e19aa96', 'Pull Day', 'Back, biceps, and traps',
 '[
   {"superSetId": "", "exercise": {"id": "b824e690-5974-4634-b1bc-0cc31dda0804", "name": "Barbell Row", "type": "WR", "primaryMuscleGroup": "back", "notes": ""}, "notes": "", "sets": [{"value1": 70, "value2": 10, "checked": false}, {"value1": 70, "value2": 10, "checked": false}, {"value1": 70, "value2": 8, "checked": false}]},
   {"superSetId": "", "exercise": {"id": "956353a6-488b-4673-8f18-4ffcadd49ada", "name": "Lat Pulldown", "type": "WR", "primaryMuscleGroup": "lats", "notes": ""}, "notes": "", "sets": [{"value1": 60, "value2": 12, "checked": false}, {"value1": 60, "value2": 12, "checked": false}, {"value1": 60, "value2": 10, "checked": false}]},
   {"superSetId": "", "exercise": {"id": "036a8ced-28e0-4226-a9fb-42c471d9c8b4", "name": "Pull-ups", "type": "BW", "primaryMuscleGroup": "lats", "notes": ""}, "notes": "", "sets": [{"value1": 0, "value2": 12, "checked": false}, {"value1": 0, "value2": 12, "checked": false}, {"value1": 0, "value2": 10, "checked": false}]},
   {"superSetId": "", "exercise": {"id": "dfd348e2-4267-4d3b-8f15-c39b48d50539", "name": "Bicep Curls", "type": "WR", "primaryMuscleGroup": "biceps", "notes": ""}, "notes": "", "sets": [{"value1": 20, "value2": 15, "checked": false}, {"value1": 20, "value2": 15, "checked": false}, {"value1": 20, "value2": 12, "checked": false}]},
   {"superSetId": "", "exercise": {"id": "b11c784e-88bc-4bee-bda1-6bc3862f409b", "name": "Shrugs", "type": "WR", "primaryMuscleGroup": "traps", "notes": ""}, "notes": "", "sets": [{"value1": 50, "value2": 15, "checked": false}, {"value1": 50, "value2": 15, "checked": false}, {"value1": 50, "value2": 12, "checked": false}]}
 ]'::jsonb,
 NOW() - INTERVAL '89 days', NOW() - INTERVAL '89 days'),

-- Leg Day template (plan001)
('fa0ca007-17f1-4af6-8343-0d9d88358e8c', 'f997b7ab-fe1b-4530-a190-0967119aedea', '3e0e79b1-6fbe-436d-b9e7-4a7d4e19aa96', 'Leg Day', 'Quads, hamstrings, glutes, and calves',
 '[
   {"superSetId": "", "exercise": {"id": "44db316c-54d9-4f99-8d43-f6f324e49c84", "name": "Squats", "type": "WR", "primaryMuscleGroup": "quadriceps", "notes": ""}, "notes": "", "sets": [{"value1": 100, "value2": 10, "checked": false}, {"value1": 100, "value2": 10, "checked": false}, {"value1": 100, "value2": 8, "checked": false}, {"value1": 100, "value2": 8, "checked": false}]},
   {"superSetId": "", "exercise": {"id": "c8492040-383f-4e4a-9b58-e5cd04546c6c", "name": "Deadlift", "type": "WR", "primaryMuscleGroup": "back", "notes": ""}, "notes": "", "sets": [{"value1": 120, "value2": 8, "checked": false}, {"value1": 120, "value2": 8, "checked": false}, {"value1": 120, "value2": 6, "checked": false}]},
   {"superSetId": "", "exercise": {"id": "c2e0b60b-6e26-4e79-8435-e3e14cfd9625", "name": "Leg Press", "type": "WR", "primaryMuscleGroup": "quadriceps", "notes": ""}, "notes": "", "sets": [{"value1": 140, "value2": 12, "checked": false}, {"value1": 140, "value2": 12, "checked": false}, {"value1": 140, "value2": 10, "checked": false}]},
   {"superSetId": "", "exercise": {"id": "3b821ac0-c156-4d25-b185-d1fda4851b6a", "name": "Romanian Deadlift", "type": "WR", "primaryMuscleGroup": "hamstrings", "notes": ""}, "notes": "", "sets": [{"value1": 80, "value2": 10, "checked": false}, {"value1": 80, "value2": 10, "checked": false}, {"value1": 80, "value2": 8, "checked": false}]},
   {"superSetId": "", "exercise": {"id": "3910de44-2d17-41ef-8c9d-355b982cf1ba", "name": "Calf Raises", "type": "WR", "primaryMuscleGroup": "calves", "notes": ""}, "notes": "", "sets": [{"value1": 50, "value2": 20, "checked": false}, {"value1": 50, "value2": 20, "checked": false}, {"value1": 50, "value2": 18, "checked": false}]}
 ]'::jsonb,
 NOW() - INTERVAL '88 days', NOW() - INTERVAL '88 days'),

-- Upper Body template (plan002)
('20764fbc-afac-44cd-8dbf-fe990e4ed56d', 'f997b7ab-fe1b-4530-a190-0967119aedea', '7115de21-1ab7-400a-8b52-6ecfd6d4ede4', 'Upper Body', 'Complete upper body workout',
 '[
   {"superSetId": "", "exercise": {"id": "8aafa06d-9f42-4946-ba18-f027fe792100", "name": "Bench Press", "type": "WR", "primaryMuscleGroup": "chest", "notes": ""}, "notes": "", "sets": [{"value1": 80, "value2": 10, "checked": false}, {"value1": 80, "value2": 10, "checked": false}, {"value1": 80, "value2": 8, "checked": false}]},
   {"superSetId": "", "exercise": {"id": "b824e690-5974-4634-b1bc-0cc31dda0804", "name": "Barbell Row", "type": "WR", "primaryMuscleGroup": "back", "notes": ""}, "notes": "", "sets": [{"value1": 70, "value2": 10, "checked": false}, {"value1": 70, "value2": 10, "checked": false}, {"value1": 70, "value2": 8, "checked": false}]},
   {"superSetId": "", "exercise": {"id": "6d7215a0-f88b-4b80-96dd-3b414a865f60", "name": "Overhead Press", "type": "WR", "primaryMuscleGroup": "frontShoulders", "notes": ""}, "notes": "", "sets": [{"value1": 50, "value2": 10, "checked": false}, {"value1": 50, "value2": 10, "checked": false}, {"value1": 50, "value2": 8, "checked": false}]},
   {"superSetId": "", "exercise": {"id": "dfd348e2-4267-4d3b-8f15-c39b48d50539", "name": "Bicep Curls", "type": "WR", "primaryMuscleGroup": "biceps", "notes": ""}, "notes": "", "sets": [{"value1": 20, "value2": 15, "checked": false}, {"value1": 20, "value2": 15, "checked": false}, {"value1": 20, "value2": 12, "checked": false}]},
   {"superSetId": "", "exercise": {"id": "a43373b9-86d7-4684-9d26-70ad1ec0039d", "name": "Tricep Extensions", "type": "WR", "primaryMuscleGroup": "triceps", "notes": ""}, "notes": "", "sets": [{"value1": 25, "value2": 12, "checked": false}, {"value1": 25, "value2": 12, "checked": false}, {"value1": 25, "value2": 10, "checked": false}]},
   {"superSetId": "", "exercise": {"id": "afcb8f22-daac-46d8-9f19-d79cebe99ad1", "name": "Cable Flyes", "type": "WR", "primaryMuscleGroup": "chest", "notes": ""}, "notes": "", "sets": [{"value1": 20, "value2": 12, "checked": false}, {"value1": 20, "value2": 12, "checked": false}, {"value1": 20, "value2": 10, "checked": false}]}
 ]'::jsonb,
 NOW() - INTERVAL '87 days', NOW() - INTERVAL '87 days'),

-- Full Body template (plan003)
('1966afc8-11a3-4bd3-941f-87ab62a2904a', 'f997b7ab-fe1b-4530-a190-0967119aedea', '74130dbe-179b-41ba-897a-ffc5f8283578', 'Full Body', 'Complete full body workout',
 '[
   {"superSetId": "", "exercise": {"id": "8aafa06d-9f42-4946-ba18-f027fe792100", "name": "Bench Press", "type": "WR", "primaryMuscleGroup": "chest", "notes": ""}, "notes": "", "sets": [{"value1": 80, "value2": 10, "checked": false}, {"value1": 80, "value2": 10, "checked": false}, {"value1": 80, "value2": 8, "checked": false}]},
   {"superSetId": "", "exercise": {"id": "b824e690-5974-4634-b1bc-0cc31dda0804", "name": "Barbell Row", "type": "WR", "primaryMuscleGroup": "back", "notes": ""}, "notes": "", "sets": [{"value1": 70, "value2": 10, "checked": false}, {"value1": 70, "value2": 10, "checked": false}, {"value1": 70, "value2": 8, "checked": false}]},
   {"superSetId": "", "exercise": {"id": "44db316c-54d9-4f99-8d43-f6f324e49c84", "name": "Squats", "type": "WR", "primaryMuscleGroup": "quadriceps", "notes": ""}, "notes": "", "sets": [{"value1": 100, "value2": 10, "checked": false}, {"value1": 100, "value2": 10, "checked": false}, {"value1": 100, "value2": 8, "checked": false}]},
   {"superSetId": "", "exercise": {"id": "70bf56e2-a7f7-4ed3-ac48-657d47c79d09", "name": "Hip Thrusts", "type": "WR", "primaryMuscleGroup": "glutes", "notes": ""}, "notes": "", "sets": [{"value1": 90, "value2": 12, "checked": false}, {"value1": 90, "value2": 12, "checked": false}, {"value1": 90, "value2": 10, "checked": false}]},
   {"superSetId": "", "exercise": {"id": "6d7215a0-f88b-4b80-96dd-3b414a865f60", "name": "Overhead Press", "type": "WR", "primaryMuscleGroup": "frontShoulders", "notes": ""}, "notes": "", "sets": [{"value1": 50, "value2": 10, "checked": false}, {"value1": 50, "value2": 10, "checked": false}, {"value1": 50, "value2": 8, "checked": false}]},
   {"superSetId": "", "exercise": {"id": "dfd348e2-4267-4d3b-8f15-c39b48d50539", "name": "Bicep Curls", "type": "WR", "primaryMuscleGroup": "biceps", "notes": ""}, "notes": "", "sets": [{"value1": 20, "value2": 15, "checked": false}, {"value1": 20, "value2": 15, "checked": false}, {"value1": 20, "value2": 12, "checked": false}]}
 ]'::jsonb,
 NOW() - INTERVAL '86 days', NOW() - INTERVAL '86 days'),

-- Strength Focus template (plan004)
('00240133-36be-44ac-a122-fd2ec013c6a4', 'f997b7ab-fe1b-4530-a190-0967119aedea', '40896f06-6f30-472e-b3be-35dbbf0d5729', 'Strength Focus', 'Heavy compound movements',
 '[
   {"superSetId": "", "exercise": {"id": "8aafa06d-9f42-4946-ba18-f027fe792100", "name": "Bench Press", "type": "WR", "primaryMuscleGroup": "chest", "notes": ""}, "notes": "", "sets": [{"value1": 100, "value2": 5, "checked": false}, {"value1": 100, "value2": 5, "checked": false}, {"value1": 100, "value2": 5, "checked": false}, {"value1": 100, "value2": 5, "checked": false}]},
   {"superSetId": "", "exercise": {"id": "44db316c-54d9-4f99-8d43-f6f324e49c84", "name": "Squats", "type": "WR", "primaryMuscleGroup": "quadriceps", "notes": ""}, "notes": "", "sets": [{"value1": 120, "value2": 5, "checked": false}, {"value1": 120, "value2": 5, "checked": false}, {"value1": 120, "value2": 5, "checked": false}, {"value1": 120, "value2": 5, "checked": false}]},
   {"superSetId": "", "exercise": {"id": "c8492040-383f-4e4a-9b58-e5cd04546c6c", "name": "Deadlift", "type": "WR", "primaryMuscleGroup": "back", "notes": ""}, "notes": "", "sets": [{"value1": 140, "value2": 5, "checked": false}, {"value1": 140, "value2": 5, "checked": false}, {"value1": 140, "value2": 5, "checked": false}]},
   {"superSetId": "", "exercise": {"id": "b824e690-5974-4634-b1bc-0cc31dda0804", "name": "Barbell Row", "type": "WR", "primaryMuscleGroup": "back", "notes": ""}, "notes": "", "sets": [{"value1": 90, "value2": 5, "checked": false}, {"value1": 90, "value2": 5, "checked": false}, {"value1": 90, "value2": 5, "checked": false}, {"value1": 90, "value2": 5, "checked": false}]},
   {"superSetId": "", "exercise": {"id": "6d7215a0-f88b-4b80-96dd-3b414a865f60", "name": "Overhead Press", "type": "WR", "primaryMuscleGroup": "frontShoulders", "notes": ""}, "notes": "", "sets": [{"value1": 60, "value2": 5, "checked": false}, {"value1": 60, "value2": 5, "checked": false}, {"value1": 60, "value2": 5, "checked": false}, {"value1": 60, "value2": 5, "checked": false}]}
 ]'::jsonb,
 NOW() - INTERVAL '85 days', NOW() - INTERVAL '85 days')
ON CONFLICT (id) DO NOTHING;

-- ============================================================================
-- ROUTINE LOGS (Last 3 months of workout history)
-- ============================================================================
-- Generate logs for training days over the last 90 days
-- Each log includes exercise logs with sets that have weight and reps values

-- Helper function to generate a routine log with exercise logs
-- We'll create logs for various dates over the last 3 months

-- Week 1 (90 days ago)
INSERT INTO public.routine_logs (id, owner, "templateId", name, notes, "startTime", "endTime", exercises, "createdAt", "updatedAt") VALUES
('7ffe64d6-f28b-4c57-a938-6327f4c489e3', 'f997b7ab-fe1b-4530-a190-0967119aedea', 'b9e2cf7e-9429-49b8-acc9-30dfc790b8b4', 'Push Day', 'Great session!', 
 NOW() - INTERVAL '90 days' + INTERVAL '8 hours', 
 NOW() - INTERVAL '90 days' + INTERVAL '9 hours 30 minutes',
 '[
   {"superSetId": "", "exercise": {"id": "8aafa06d-9f42-4946-ba18-f027fe792100", "name": "Bench Press", "type": "WR", "primaryMuscleGroup": "chest", "notes": ""}, "notes": "Felt strong today", "sets": [{"value1": 80, "value2": 10, "checked": true}, {"value1": 80, "value2": 10, "checked": true}, {"value1": 80, "value2": 8, "checked": true}]},
   {"superSetId": "", "exercise": {"id": "d9b6d428-3bc7-4f68-bebb-d32287f13257", "name": "Incline Dumbbell Press", "type": "WR", "primaryMuscleGroup": "chest", "notes": ""}, "notes": "", "sets": [{"value1": 30, "value2": 12, "checked": true}, {"value1": 30, "value2": 12, "checked": true}, {"value1": 30, "value2": 10, "checked": true}]},
   {"superSetId": "", "exercise": {"id": "6d7215a0-f88b-4b80-96dd-3b414a865f60", "name": "Overhead Press", "type": "WR", "primaryMuscleGroup": "frontShoulders", "notes": ""}, "notes": "", "sets": [{"value1": 50, "value2": 10, "checked": true}, {"value1": 50, "value2": 10, "checked": true}, {"value1": 50, "value2": 8, "checked": true}]},
   {"superSetId": "", "exercise": {"id": "2b14611a-b196-4f9a-948b-932b74a27963", "name": "Lateral Raises", "type": "WR", "primaryMuscleGroup": "frontShoulders", "notes": ""}, "notes": "", "sets": [{"value1": 15, "value2": 15, "checked": true}, {"value1": 15, "value2": 15, "checked": true}, {"value1": 15, "value2": 12, "checked": true}]},
   {"superSetId": "", "exercise": {"id": "a43373b9-86d7-4684-9d26-70ad1ec0039d", "name": "Tricep Extensions", "type": "WR", "primaryMuscleGroup": "triceps", "notes": ""}, "notes": "", "sets": [{"value1": 25, "value2": 12, "checked": true}, {"value1": 25, "value2": 12, "checked": true}, {"value1": 25, "value2": 10, "checked": true}]}
 ]'::jsonb,
 NOW() - INTERVAL '90 days', NOW() - INTERVAL '90 days'),

('dfbc3436-0dc8-4a3d-a125-0fe02bcaad34', 'f997b7ab-fe1b-4530-a190-0967119aedea', '98fbe1f7-04ca-44cb-95ae-f4ce23add290', 'Pull Day', '',
 NOW() - INTERVAL '88 days' + INTERVAL '9 hours',
 NOW() - INTERVAL '88 days' + INTERVAL '10 hours 15 minutes',
 '[
   {"superSetId": "", "exercise": {"id": "b824e690-5974-4634-b1bc-0cc31dda0804", "name": "Barbell Row", "type": "WR", "primaryMuscleGroup": "back", "notes": ""}, "notes": "", "sets": [{"value1": 70, "value2": 10, "checked": true}, {"value1": 70, "value2": 10, "checked": true}, {"value1": 70, "value2": 8, "checked": true}]},
   {"superSetId": "", "exercise": {"id": "956353a6-488b-4673-8f18-4ffcadd49ada", "name": "Lat Pulldown", "type": "WR", "primaryMuscleGroup": "lats", "notes": ""}, "notes": "", "sets": [{"value1": 60, "value2": 12, "checked": true}, {"value1": 60, "value2": 12, "checked": true}, {"value1": 60, "value2": 10, "checked": true}]},
   {"superSetId": "", "exercise": {"id": "036a8ced-28e0-4226-a9fb-42c471d9c8b4", "name": "Pull-ups", "type": "BW", "primaryMuscleGroup": "lats", "notes": ""}, "notes": "", "sets": [{"value1": 0, "value2": 12, "checked": true}, {"value1": 0, "value2": 12, "checked": true}, {"value1": 0, "value2": 10, "checked": true}]},
   {"superSetId": "", "exercise": {"id": "dfd348e2-4267-4d3b-8f15-c39b48d50539", "name": "Bicep Curls", "type": "WR", "primaryMuscleGroup": "biceps", "notes": ""}, "notes": "", "sets": [{"value1": 20, "value2": 15, "checked": true}, {"value1": 20, "value2": 15, "checked": true}, {"value1": 20, "value2": 12, "checked": true}]},
   {"superSetId": "", "exercise": {"id": "b11c784e-88bc-4bee-bda1-6bc3862f409b", "name": "Shrugs", "type": "WR", "primaryMuscleGroup": "traps", "notes": ""}, "notes": "", "sets": [{"value1": 50, "value2": 15, "checked": true}, {"value1": 50, "value2": 15, "checked": true}, {"value1": 50, "value2": 12, "checked": true}]}
 ]'::jsonb,
 NOW() - INTERVAL '88 days', NOW() - INTERVAL '88 days'),

('3fb9da4a-8843-42e4-8cef-f9715a55928c', 'f997b7ab-fe1b-4530-a190-0967119aedea', 'fa0ca007-17f1-4af6-8343-0d9d88358e8c', 'Leg Day', '',
 NOW() - INTERVAL '86 days' + INTERVAL '10 hours',
 NOW() - INTERVAL '86 days' + INTERVAL '11 hours 20 minutes',
 '[
   {"superSetId": "", "exercise": {"id": "44db316c-54d9-4f99-8d43-f6f324e49c84", "name": "Squats", "type": "WR", "primaryMuscleGroup": "quadriceps", "notes": ""}, "notes": "", "sets": [{"value1": 100, "value2": 10, "checked": true}, {"value1": 100, "value2": 10, "checked": true}, {"value1": 100, "value2": 8, "checked": true}, {"value1": 100, "value2": 8, "checked": true}]},
   {"superSetId": "", "exercise": {"id": "c8492040-383f-4e4a-9b58-e5cd04546c6c", "name": "Deadlift", "type": "WR", "primaryMuscleGroup": "back", "notes": ""}, "notes": "", "sets": [{"value1": 120, "value2": 8, "checked": true}, {"value1": 120, "value2": 8, "checked": true}, {"value1": 120, "value2": 6, "checked": true}]},
   {"superSetId": "", "exercise": {"id": "c2e0b60b-6e26-4e79-8435-e3e14cfd9625", "name": "Leg Press", "type": "WR", "primaryMuscleGroup": "quadriceps", "notes": ""}, "notes": "", "sets": [{"value1": 140, "value2": 12, "checked": true}, {"value1": 140, "value2": 12, "checked": true}, {"value1": 140, "value2": 10, "checked": true}]},
   {"superSetId": "", "exercise": {"id": "3b821ac0-c156-4d25-b185-d1fda4851b6a", "name": "Romanian Deadlift", "type": "WR", "primaryMuscleGroup": "hamstrings", "notes": ""}, "notes": "", "sets": [{"value1": 80, "value2": 10, "checked": true}, {"value1": 80, "value2": 10, "checked": true}, {"value1": 80, "value2": 8, "checked": true}]},
   {"superSetId": "", "exercise": {"id": "3910de44-2d17-41ef-8c9d-355b982cf1ba", "name": "Calf Raises", "type": "WR", "primaryMuscleGroup": "calves", "notes": ""}, "notes": "", "sets": [{"value1": 50, "value2": 20, "checked": true}, {"value1": 50, "value2": 20, "checked": true}, {"value1": 50, "value2": 18, "checked": true}]}
 ]'::jsonb,
 NOW() - INTERVAL '86 days', NOW() - INTERVAL '86 days'),

-- Continue with more logs for the remaining weeks...
-- Week 2
('ac1845cd-b5d8-4d26-ae71-b693a86cb387', 'f997b7ab-fe1b-4530-a190-0967119aedea', 'b9e2cf7e-9429-49b8-acc9-30dfc790b8b4', 'Push Day', '',
 NOW() - INTERVAL '83 days' + INTERVAL '8 hours 30 minutes',
 NOW() - INTERVAL '83 days' + INTERVAL '9 hours 45 minutes',
 '[
   {"superSetId": "", "exercise": {"id": "8aafa06d-9f42-4946-ba18-f027fe792100", "name": "Bench Press", "type": "WR", "primaryMuscleGroup": "chest", "notes": ""}, "notes": "", "sets": [{"value1": 82, "value2": 10, "checked": true}, {"value1": 82, "value2": 10, "checked": true}, {"value1": 82, "value2": 9, "checked": true}]},
   {"superSetId": "", "exercise": {"id": "d9b6d428-3bc7-4f68-bebb-d32287f13257", "name": "Incline Dumbbell Press", "type": "WR", "primaryMuscleGroup": "chest", "notes": ""}, "notes": "", "sets": [{"value1": 32, "value2": 12, "checked": true}, {"value1": 32, "value2": 12, "checked": true}, {"value1": 32, "value2": 11, "checked": true}]},
   {"superSetId": "", "exercise": {"id": "6d7215a0-f88b-4b80-96dd-3b414a865f60", "name": "Overhead Press", "type": "WR", "primaryMuscleGroup": "frontShoulders", "notes": ""}, "notes": "", "sets": [{"value1": 52, "value2": 10, "checked": true}, {"value1": 52, "value2": 10, "checked": true}, {"value1": 52, "value2": 9, "checked": true}]},
   {"superSetId": "", "exercise": {"id": "2b14611a-b196-4f9a-948b-932b74a27963", "name": "Lateral Raises", "type": "WR", "primaryMuscleGroup": "frontShoulders", "notes": ""}, "notes": "", "sets": [{"value1": 16, "value2": 15, "checked": true}, {"value1": 16, "value2": 15, "checked": true}, {"value1": 16, "value2": 13, "checked": true}]},
   {"superSetId": "", "exercise": {"id": "a43373b9-86d7-4684-9d26-70ad1ec0039d", "name": "Tricep Extensions", "type": "WR", "primaryMuscleGroup": "triceps", "notes": ""}, "notes": "", "sets": [{"value1": 26, "value2": 12, "checked": true}, {"value1": 26, "value2": 12, "checked": true}, {"value1": 26, "value2": 11, "checked": true}]}
 ]'::jsonb,
 NOW() - INTERVAL '83 days', NOW() - INTERVAL '83 days'),

('8a1e04a9-7d32-4e12-b3e8-b1738587e099', 'f997b7ab-fe1b-4530-a190-0967119aedea', '98fbe1f7-04ca-44cb-95ae-f4ce23add290', 'Pull Day', '',
 NOW() - INTERVAL '81 days' + INTERVAL '9 hours',
 NOW() - INTERVAL '81 days' + INTERVAL '10 hours 20 minutes',
 '[
   {"superSetId": "", "exercise": {"id": "b824e690-5974-4634-b1bc-0cc31dda0804", "name": "Barbell Row", "type": "WR", "primaryMuscleGroup": "back", "notes": ""}, "notes": "", "sets": [{"value1": 72, "value2": 10, "checked": true}, {"value1": 72, "value2": 10, "checked": true}, {"value1": 72, "value2": 9, "checked": true}]},
   {"superSetId": "", "exercise": {"id": "956353a6-488b-4673-8f18-4ffcadd49ada", "name": "Lat Pulldown", "type": "WR", "primaryMuscleGroup": "lats", "notes": ""}, "notes": "", "sets": [{"value1": 62, "value2": 12, "checked": true}, {"value1": 62, "value2": 12, "checked": true}, {"value1": 62, "value2": 11, "checked": true}]},
   {"superSetId": "", "exercise": {"id": "036a8ced-28e0-4226-a9fb-42c471d9c8b4", "name": "Pull-ups", "type": "BW", "primaryMuscleGroup": "lats", "notes": ""}, "notes": "", "sets": [{"value1": 0, "value2": 13, "checked": true}, {"value1": 0, "value2": 13, "checked": true}, {"value1": 0, "value2": 11, "checked": true}]},
   {"superSetId": "", "exercise": {"id": "dfd348e2-4267-4d3b-8f15-c39b48d50539", "name": "Bicep Curls", "type": "WR", "primaryMuscleGroup": "biceps", "notes": ""}, "notes": "", "sets": [{"value1": 21, "value2": 15, "checked": true}, {"value1": 21, "value2": 15, "checked": true}, {"value1": 21, "value2": 13, "checked": true}]},
   {"superSetId": "", "exercise": {"id": "b11c784e-88bc-4bee-bda1-6bc3862f409b", "name": "Shrugs", "type": "WR", "primaryMuscleGroup": "traps", "notes": ""}, "notes": "", "sets": [{"value1": 52, "value2": 15, "checked": true}, {"value1": 52, "value2": 15, "checked": true}, {"value1": 52, "value2": 13, "checked": true}]}
 ]'::jsonb,
 NOW() - INTERVAL '81 days', NOW() - INTERVAL '81 days'),

('fd040193-a95f-474f-9df2-4874f2436f25', 'f997b7ab-fe1b-4530-a190-0967119aedea', 'fa0ca007-17f1-4af6-8343-0d9d88358e8c', 'Leg Day', '',
 NOW() - INTERVAL '79 days' + INTERVAL '10 hours',
 NOW() - INTERVAL '79 days' + INTERVAL '11 hours 25 minutes',
 '[
   {"superSetId": "", "exercise": {"id": "44db316c-54d9-4f99-8d43-f6f324e49c84", "name": "Squats", "type": "WR", "primaryMuscleGroup": "quadriceps", "notes": ""}, "notes": "", "sets": [{"value1": 102, "value2": 10, "checked": true}, {"value1": 102, "value2": 10, "checked": true}, {"value1": 102, "value2": 9, "checked": true}, {"value1": 102, "value2": 9, "checked": true}]},
   {"superSetId": "", "exercise": {"id": "c8492040-383f-4e4a-9b58-e5cd04546c6c", "name": "Deadlift", "type": "WR", "primaryMuscleGroup": "back", "notes": ""}, "notes": "", "sets": [{"value1": 122, "value2": 8, "checked": true}, {"value1": 122, "value2": 8, "checked": true}, {"value1": 122, "value2": 7, "checked": true}]},
   {"superSetId": "", "exercise": {"id": "c2e0b60b-6e26-4e79-8435-e3e14cfd9625", "name": "Leg Press", "type": "WR", "primaryMuscleGroup": "quadriceps", "notes": ""}, "notes": "", "sets": [{"value1": 142, "value2": 12, "checked": true}, {"value1": 142, "value2": 12, "checked": true}, {"value1": 142, "value2": 11, "checked": true}]},
   {"superSetId": "", "exercise": {"id": "3b821ac0-c156-4d25-b185-d1fda4851b6a", "name": "Romanian Deadlift", "type": "WR", "primaryMuscleGroup": "hamstrings", "notes": ""}, "notes": "", "sets": [{"value1": 82, "value2": 10, "checked": true}, {"value1": 82, "value2": 10, "checked": true}, {"value1": 82, "value2": 9, "checked": true}]},
   {"superSetId": "", "exercise": {"id": "3910de44-2d17-41ef-8c9d-355b982cf1ba", "name": "Calf Raises", "type": "WR", "primaryMuscleGroup": "calves", "notes": ""}, "notes": "", "sets": [{"value1": 52, "value2": 20, "checked": true}, {"value1": 52, "value2": 20, "checked": true}, {"value1": 52, "value2": 19, "checked": true}]}
 ]'::jsonb,
 NOW() - INTERVAL '79 days', NOW() - INTERVAL '79 days'),

-- Week 3
('bb4de451-7486-4845-9db5-64a0f5a30296', 'f997b7ab-fe1b-4530-a190-0967119aedea', '20764fbc-afac-44cd-8dbf-fe990e4ed56d', 'Upper Body', '',
 NOW() - INTERVAL '76 days' + INTERVAL '8 hours',
 NOW() - INTERVAL '76 days' + INTERVAL '9 hours 30 minutes',
 '[
   {"superSetId": "", "exercise": {"id": "8aafa06d-9f42-4946-ba18-f027fe792100", "name": "Bench Press", "type": "WR", "primaryMuscleGroup": "chest", "notes": ""}, "notes": "", "sets": [{"value1": 84, "value2": 10, "checked": true}, {"value1": 84, "value2": 10, "checked": true}, {"value1": 84, "value2": 9, "checked": true}]},
   {"superSetId": "", "exercise": {"id": "b824e690-5974-4634-b1bc-0cc31dda0804", "name": "Barbell Row", "type": "WR", "primaryMuscleGroup": "back", "notes": ""}, "notes": "", "sets": [{"value1": 74, "value2": 10, "checked": true}, {"value1": 74, "value2": 10, "checked": true}, {"value1": 74, "value2": 9, "checked": true}]},
   {"superSetId": "", "exercise": {"id": "6d7215a0-f88b-4b80-96dd-3b414a865f60", "name": "Overhead Press", "type": "WR", "primaryMuscleGroup": "frontShoulders", "notes": ""}, "notes": "", "sets": [{"value1": 54, "value2": 10, "checked": true}, {"value1": 54, "value2": 10, "checked": true}, {"value1": 54, "value2": 9, "checked": true}]},
   {"superSetId": "", "exercise": {"id": "dfd348e2-4267-4d3b-8f15-c39b48d50539", "name": "Bicep Curls", "type": "WR", "primaryMuscleGroup": "biceps", "notes": ""}, "notes": "", "sets": [{"value1": 22, "value2": 15, "checked": true}, {"value1": 22, "value2": 15, "checked": true}, {"value1": 22, "value2": 13, "checked": true}]},
   {"superSetId": "", "exercise": {"id": "a43373b9-86d7-4684-9d26-70ad1ec0039d", "name": "Tricep Extensions", "type": "WR", "primaryMuscleGroup": "triceps", "notes": ""}, "notes": "", "sets": [{"value1": 27, "value2": 12, "checked": true}, {"value1": 27, "value2": 12, "checked": true}, {"value1": 27, "value2": 11, "checked": true}]},
   {"superSetId": "", "exercise": {"id": "afcb8f22-daac-46d8-9f19-d79cebe99ad1", "name": "Cable Flyes", "type": "WR", "primaryMuscleGroup": "chest", "notes": ""}, "notes": "", "sets": [{"value1": 22, "value2": 12, "checked": true}, {"value1": 22, "value2": 12, "checked": true}, {"value1": 22, "value2": 11, "checked": true}]}
 ]'::jsonb,
 NOW() - INTERVAL '76 days', NOW() - INTERVAL '76 days'),

-- Add more logs for recent weeks (continuing pattern)...
-- Recent logs (last 2 weeks)
('0059ab3b-9aa6-40a1-ae2a-3ed04546fbd4', 'f997b7ab-fe1b-4530-a190-0967119aedea', 'b9e2cf7e-9429-49b8-acc9-30dfc790b8b4', 'Push Day', 'Felt strong today',
 NOW() - INTERVAL '14 days' + INTERVAL '8 hours',
 NOW() - INTERVAL '14 days' + INTERVAL '9 hours 30 minutes',
 '[
   {"superSetId": "", "exercise": {"id": "8aafa06d-9f42-4946-ba18-f027fe792100", "name": "Bench Press", "type": "WR", "primaryMuscleGroup": "chest", "notes": ""}, "notes": "Felt strong today", "sets": [{"value1": 90, "value2": 10, "checked": true}, {"value1": 90, "value2": 10, "checked": true}, {"value1": 90, "value2": 9, "checked": true}]},
   {"superSetId": "", "exercise": {"id": "d9b6d428-3bc7-4f68-bebb-d32287f13257", "name": "Incline Dumbbell Press", "type": "WR", "primaryMuscleGroup": "chest", "notes": ""}, "notes": "", "sets": [{"value1": 35, "value2": 12, "checked": true}, {"value1": 35, "value2": 12, "checked": true}, {"value1": 35, "value2": 11, "checked": true}]},
   {"superSetId": "", "exercise": {"id": "6d7215a0-f88b-4b80-96dd-3b414a865f60", "name": "Overhead Press", "type": "WR", "primaryMuscleGroup": "frontShoulders", "notes": ""}, "notes": "", "sets": [{"value1": 58, "value2": 10, "checked": true}, {"value1": 58, "value2": 10, "checked": true}, {"value1": 58, "value2": 9, "checked": true}]},
   {"superSetId": "", "exercise": {"id": "2b14611a-b196-4f9a-948b-932b74a27963", "name": "Lateral Raises", "type": "WR", "primaryMuscleGroup": "frontShoulders", "notes": ""}, "notes": "", "sets": [{"value1": 18, "value2": 15, "checked": true}, {"value1": 18, "value2": 15, "checked": true}, {"value1": 18, "value2": 14, "checked": true}]},
   {"superSetId": "", "exercise": {"id": "a43373b9-86d7-4684-9d26-70ad1ec0039d", "name": "Tricep Extensions", "type": "WR", "primaryMuscleGroup": "triceps", "notes": ""}, "notes": "", "sets": [{"value1": 28, "value2": 12, "checked": true}, {"value1": 28, "value2": 12, "checked": true}, {"value1": 28, "value2": 11, "checked": true}]}
 ]'::jsonb,
 NOW() - INTERVAL '14 days', NOW() - INTERVAL '14 days'),

('89eb6894-6537-4102-a680-be57afc6bfa6', 'f997b7ab-fe1b-4530-a190-0967119aedea', '98fbe1f7-04ca-44cb-95ae-f4ce23add290', 'Pull Day', '',
 NOW() - INTERVAL '12 days' + INTERVAL '9 hours',
 NOW() - INTERVAL '12 days' + INTERVAL '10 hours 20 minutes',
 '[
   {"superSetId": "", "exercise": {"id": "b824e690-5974-4634-b1bc-0cc31dda0804", "name": "Barbell Row", "type": "WR", "primaryMuscleGroup": "back", "notes": ""}, "notes": "", "sets": [{"value1": 80, "value2": 10, "checked": true}, {"value1": 80, "value2": 10, "checked": true}, {"value1": 80, "value2": 9, "checked": true}]},
   {"superSetId": "", "exercise": {"id": "956353a6-488b-4673-8f18-4ffcadd49ada", "name": "Lat Pulldown", "type": "WR", "primaryMuscleGroup": "lats", "notes": ""}, "notes": "", "sets": [{"value1": 70, "value2": 12, "checked": true}, {"value1": 70, "value2": 12, "checked": true}, {"value1": 70, "value2": 11, "checked": true}]},
   {"superSetId": "", "exercise": {"id": "036a8ced-28e0-4226-a9fb-42c471d9c8b4", "name": "Pull-ups", "type": "BW", "primaryMuscleGroup": "lats", "notes": ""}, "notes": "", "sets": [{"value1": 0, "value2": 15, "checked": true}, {"value1": 0, "value2": 15, "checked": true}, {"value1": 0, "value2": 13, "checked": true}]},
   {"superSetId": "", "exercise": {"id": "dfd348e2-4267-4d3b-8f15-c39b48d50539", "name": "Bicep Curls", "type": "WR", "primaryMuscleGroup": "biceps", "notes": ""}, "notes": "", "sets": [{"value1": 24, "value2": 15, "checked": true}, {"value1": 24, "value2": 15, "checked": true}, {"value1": 24, "value2": 14, "checked": true}]},
   {"superSetId": "", "exercise": {"id": "b11c784e-88bc-4bee-bda1-6bc3862f409b", "name": "Shrugs", "type": "WR", "primaryMuscleGroup": "traps", "notes": ""}, "notes": "", "sets": [{"value1": 55, "value2": 15, "checked": true}, {"value1": 55, "value2": 15, "checked": true}, {"value1": 55, "value2": 14, "checked": true}]}
 ]'::jsonb,
 NOW() - INTERVAL '12 days', NOW() - INTERVAL '12 days'),

('b9f6c8aa-8ff8-4cdb-81dd-b9c6f891b397', 'f997b7ab-fe1b-4530-a190-0967119aedea', 'fa0ca007-17f1-4af6-8343-0d9d88358e8c', 'Leg Day', '',
 NOW() - INTERVAL '10 days' + INTERVAL '10 hours',
 NOW() - INTERVAL '10 days' + INTERVAL '11 hours 25 minutes',
 '[
   {"superSetId": "", "exercise": {"id": "44db316c-54d9-4f99-8d43-f6f324e49c84", "name": "Squats", "type": "WR", "primaryMuscleGroup": "quadriceps", "notes": ""}, "notes": "", "sets": [{"value1": 110, "value2": 10, "checked": true}, {"value1": 110, "value2": 10, "checked": true}, {"value1": 110, "value2": 9, "checked": true}, {"value1": 110, "value2": 9, "checked": true}]},
   {"superSetId": "", "exercise": {"id": "c8492040-383f-4e4a-9b58-e5cd04546c6c", "name": "Deadlift", "type": "WR", "primaryMuscleGroup": "back", "notes": ""}, "notes": "", "sets": [{"value1": 130, "value2": 8, "checked": true}, {"value1": 130, "value2": 8, "checked": true}, {"value1": 130, "value2": 7, "checked": true}]},
   {"superSetId": "", "exercise": {"id": "c2e0b60b-6e26-4e79-8435-e3e14cfd9625", "name": "Leg Press", "type": "WR", "primaryMuscleGroup": "quadriceps", "notes": ""}, "notes": "", "sets": [{"value1": 150, "value2": 12, "checked": true}, {"value1": 150, "value2": 12, "checked": true}, {"value1": 150, "value2": 11, "checked": true}]},
   {"superSetId": "", "exercise": {"id": "3b821ac0-c156-4d25-b185-d1fda4851b6a", "name": "Romanian Deadlift", "type": "WR", "primaryMuscleGroup": "hamstrings", "notes": ""}, "notes": "", "sets": [{"value1": 90, "value2": 10, "checked": true}, {"value1": 90, "value2": 10, "checked": true}, {"value1": 90, "value2": 9, "checked": true}]},
   {"superSetId": "", "exercise": {"id": "3910de44-2d17-41ef-8c9d-355b982cf1ba", "name": "Calf Raises", "type": "WR", "primaryMuscleGroup": "calves", "notes": ""}, "notes": "", "sets": [{"value1": 60, "value2": 20, "checked": true}, {"value1": 60, "value2": 20, "checked": true}, {"value1": 60, "value2": 19, "checked": true}]}
 ]'::jsonb,
 NOW() - INTERVAL '10 days', NOW() - INTERVAL '10 days'),

-- Most recent logs
('9c4128c6-18e9-40fc-9fad-dae09f29f402', 'f997b7ab-fe1b-4530-a190-0967119aedea', 'b9e2cf7e-9429-49b8-acc9-30dfc790b8b4', 'Push Day', '',
 NOW() - INTERVAL '7 days' + INTERVAL '8 hours',
 NOW() - INTERVAL '7 days' + INTERVAL '9 hours 30 minutes',
 '[
   {"superSetId": "", "exercise": {"id": "8aafa06d-9f42-4946-ba18-f027fe792100", "name": "Bench Press", "type": "WR", "primaryMuscleGroup": "chest", "notes": ""}, "notes": "", "sets": [{"value1": 92, "value2": 10, "checked": true}, {"value1": 92, "value2": 10, "checked": true}, {"value1": 92, "value2": 9, "checked": true}]},
   {"superSetId": "", "exercise": {"id": "d9b6d428-3bc7-4f68-bebb-d32287f13257", "name": "Incline Dumbbell Press", "type": "WR", "primaryMuscleGroup": "chest", "notes": ""}, "notes": "", "sets": [{"value1": 36, "value2": 12, "checked": true}, {"value1": 36, "value2": 12, "checked": true}, {"value1": 36, "value2": 11, "checked": true}]},
   {"superSetId": "", "exercise": {"id": "6d7215a0-f88b-4b80-96dd-3b414a865f60", "name": "Overhead Press", "type": "WR", "primaryMuscleGroup": "frontShoulders", "notes": ""}, "notes": "", "sets": [{"value1": 60, "value2": 10, "checked": true}, {"value1": 60, "value2": 10, "checked": true}, {"value1": 60, "value2": 9, "checked": true}]},
   {"superSetId": "", "exercise": {"id": "2b14611a-b196-4f9a-948b-932b74a27963", "name": "Lateral Raises", "type": "WR", "primaryMuscleGroup": "frontShoulders", "notes": ""}, "notes": "", "sets": [{"value1": 20, "value2": 15, "checked": true}, {"value1": 20, "value2": 15, "checked": true}, {"value1": 20, "value2": 14, "checked": true}]},
   {"superSetId": "", "exercise": {"id": "a43373b9-86d7-4684-9d26-70ad1ec0039d", "name": "Tricep Extensions", "type": "WR", "primaryMuscleGroup": "triceps", "notes": ""}, "notes": "", "sets": [{"value1": 30, "value2": 12, "checked": true}, {"value1": 30, "value2": 12, "checked": true}, {"value1": 30, "value2": 11, "checked": true}]}
 ]'::jsonb,
 NOW() - INTERVAL '7 days', NOW() - INTERVAL '7 days'),

('a8fa81f7-e2d9-42f5-95ef-e03718da9fc1', 'f997b7ab-fe1b-4530-a190-0967119aedea', '98fbe1f7-04ca-44cb-95ae-f4ce23add290', 'Pull Day', '',
 NOW() - INTERVAL '5 days' + INTERVAL '9 hours',
 NOW() - INTERVAL '5 days' + INTERVAL '10 hours 20 minutes',
 '[
   {"superSetId": "", "exercise": {"id": "b824e690-5974-4634-b1bc-0cc31dda0804", "name": "Barbell Row", "type": "WR", "primaryMuscleGroup": "back", "notes": ""}, "notes": "", "sets": [{"value1": 82, "value2": 10, "checked": true}, {"value1": 82, "value2": 10, "checked": true}, {"value1": 82, "value2": 9, "checked": true}]},
   {"superSetId": "", "exercise": {"id": "956353a6-488b-4673-8f18-4ffcadd49ada", "name": "Lat Pulldown", "type": "WR", "primaryMuscleGroup": "lats", "notes": ""}, "notes": "", "sets": [{"value1": 72, "value2": 12, "checked": true}, {"value1": 72, "value2": 12, "checked": true}, {"value1": 72, "value2": 11, "checked": true}]},
   {"superSetId": "", "exercise": {"id": "036a8ced-28e0-4226-a9fb-42c471d9c8b4", "name": "Pull-ups", "type": "BW", "primaryMuscleGroup": "lats", "notes": ""}, "notes": "", "sets": [{"value1": 0, "value2": 16, "checked": true}, {"value1": 0, "value2": 16, "checked": true}, {"value1": 0, "value2": 14, "checked": true}]},
   {"superSetId": "", "exercise": {"id": "dfd348e2-4267-4d3b-8f15-c39b48d50539", "name": "Bicep Curls", "type": "WR", "primaryMuscleGroup": "biceps", "notes": ""}, "notes": "", "sets": [{"value1": 25, "value2": 15, "checked": true}, {"value1": 25, "value2": 15, "checked": true}, {"value1": 25, "value2": 14, "checked": true}]},
   {"superSetId": "", "exercise": {"id": "b11c784e-88bc-4bee-bda1-6bc3862f409b", "name": "Shrugs", "type": "WR", "primaryMuscleGroup": "traps", "notes": ""}, "notes": "", "sets": [{"value1": 58, "value2": 15, "checked": true}, {"value1": 58, "value2": 15, "checked": true}, {"value1": 58, "value2": 14, "checked": true}]}
 ]'::jsonb,
 NOW() - INTERVAL '5 days', NOW() - INTERVAL '5 days'),

('5d19721d-43ee-4020-b2e8-99b45289cc57', 'f997b7ab-fe1b-4530-a190-0967119aedea', 'fa0ca007-17f1-4af6-8343-0d9d88358e8c', 'Leg Day', '',
 NOW() - INTERVAL '3 days' + INTERVAL '10 hours',
 NOW() - INTERVAL '3 days' + INTERVAL '11 hours 25 minutes',
 '[
   {"superSetId": "", "exercise": {"id": "44db316c-54d9-4f99-8d43-f6f324e49c84", "name": "Squats", "type": "WR", "primaryMuscleGroup": "quadriceps", "notes": ""}, "notes": "", "sets": [{"value1": 112, "value2": 10, "checked": true}, {"value1": 112, "value2": 10, "checked": true}, {"value1": 112, "value2": 9, "checked": true}, {"value1": 112, "value2": 9, "checked": true}]},
   {"superSetId": "", "exercise": {"id": "c8492040-383f-4e4a-9b58-e5cd04546c6c", "name": "Deadlift", "type": "WR", "primaryMuscleGroup": "back", "notes": ""}, "notes": "", "sets": [{"value1": 132, "value2": 8, "checked": true}, {"value1": 132, "value2": 8, "checked": true}, {"value1": 132, "value2": 7, "checked": true}]},
   {"superSetId": "", "exercise": {"id": "c2e0b60b-6e26-4e79-8435-e3e14cfd9625", "name": "Leg Press", "type": "WR", "primaryMuscleGroup": "quadriceps", "notes": ""}, "notes": "", "sets": [{"value1": 152, "value2": 12, "checked": true}, {"value1": 152, "value2": 12, "checked": true}, {"value1": 152, "value2": 11, "checked": true}]},
   {"superSetId": "", "exercise": {"id": "3b821ac0-c156-4d25-b185-d1fda4851b6a", "name": "Romanian Deadlift", "type": "WR", "primaryMuscleGroup": "hamstrings", "notes": ""}, "notes": "", "sets": [{"value1": 92, "value2": 10, "checked": true}, {"value1": 92, "value2": 10, "checked": true}, {"value1": 92, "value2": 9, "checked": true}]},
   {"superSetId": "", "exercise": {"id": "3910de44-2d17-41ef-8c9d-355b982cf1ba", "name": "Calf Raises", "type": "WR", "primaryMuscleGroup": "calves", "notes": ""}, "notes": "", "sets": [{"value1": 62, "value2": 20, "checked": true}, {"value1": 62, "value2": 20, "checked": true}, {"value1": 62, "value2": 19, "checked": true}]}
 ]'::jsonb,
 NOW() - INTERVAL '3 days', NOW() - INTERVAL '3 days'),

('b80b7d3c-eea7-4b84-9abf-c0f00c5f4bda', 'f997b7ab-fe1b-4530-a190-0967119aedea', '00240133-36be-44ac-a122-fd2ec013c6a4', 'Strength Focus', '',
 NOW() - INTERVAL '1 day' + INTERVAL '8 hours',
 NOW() - INTERVAL '1 day' + INTERVAL '9 hours 45 minutes',
 '[
   {"superSetId": "", "exercise": {"id": "8aafa06d-9f42-4946-ba18-f027fe792100", "name": "Bench Press", "type": "WR", "primaryMuscleGroup": "chest", "notes": ""}, "notes": "", "sets": [{"value1": 105, "value2": 5, "checked": true}, {"value1": 105, "value2": 5, "checked": true}, {"value1": 105, "value2": 5, "checked": true}, {"value1": 105, "value2": 5, "checked": true}]},
   {"superSetId": "", "exercise": {"id": "44db316c-54d9-4f99-8d43-f6f324e49c84", "name": "Squats", "type": "WR", "primaryMuscleGroup": "quadriceps", "notes": ""}, "notes": "", "sets": [{"value1": 125, "value2": 5, "checked": true}, {"value1": 125, "value2": 5, "checked": true}, {"value1": 125, "value2": 5, "checked": true}, {"value1": 125, "value2": 5, "checked": true}]},
   {"superSetId": "", "exercise": {"id": "c8492040-383f-4e4a-9b58-e5cd04546c6c", "name": "Deadlift", "type": "WR", "primaryMuscleGroup": "back", "notes": ""}, "notes": "", "sets": [{"value1": 145, "value2": 5, "checked": true}, {"value1": 145, "value2": 5, "checked": true}, {"value1": 145, "value2": 5, "checked": true}]},
   {"superSetId": "", "exercise": {"id": "b824e690-5974-4634-b1bc-0cc31dda0804", "name": "Barbell Row", "type": "WR", "primaryMuscleGroup": "back", "notes": ""}, "notes": "", "sets": [{"value1": 95, "value2": 5, "checked": true}, {"value1": 95, "value2": 5, "checked": true}, {"value1": 95, "value2": 5, "checked": true}, {"value1": 95, "value2": 5, "checked": true}]},
   {"superSetId": "", "exercise": {"id": "6d7215a0-f88b-4b80-96dd-3b414a865f60", "name": "Overhead Press", "type": "WR", "primaryMuscleGroup": "frontShoulders", "notes": ""}, "notes": "", "sets": [{"value1": 65, "value2": 5, "checked": true}, {"value1": 65, "value2": 5, "checked": true}, {"value1": 65, "value2": 5, "checked": true}, {"value1": 65, "value2": 5, "checked": true}]}
 ]'::jsonb,
 NOW() - INTERVAL '1 day', NOW() - INTERVAL '1 day'),

-- Very recent logs (last few days)
('c91e8f4d-2a3b-4c5d-6e7f-8a9b0c1d2e3f', 'f997b7ab-fe1b-4530-a190-0967119aedea', 'b9e2cf7e-9429-49b8-acc9-30dfc790b8b4', 'Push Day', 'Great session!',
 NOW() - INTERVAL '0 days' + INTERVAL '8 hours',
 NOW() - INTERVAL '0 days' + INTERVAL '9 hours 30 minutes',
 '[
   {"superSetId": "", "exercise": {"id": "8aafa06d-9f42-4946-ba18-f027fe792100", "name": "Bench Press", "type": "WR", "primaryMuscleGroup": "chest", "notes": ""}, "notes": "Felt strong today", "sets": [{"value1": 94, "value2": 10, "checked": true}, {"value1": 94, "value2": 10, "checked": true}, {"value1": 94, "value2": 9, "checked": true}]},
   {"superSetId": "", "exercise": {"id": "d9b6d428-3bc7-4f68-bebb-d32287f13257", "name": "Incline Dumbbell Press", "type": "WR", "primaryMuscleGroup": "chest", "notes": ""}, "notes": "", "sets": [{"value1": 37, "value2": 12, "checked": true}, {"value1": 37, "value2": 12, "checked": true}, {"value1": 37, "value2": 11, "checked": true}]},
   {"superSetId": "", "exercise": {"id": "6d7215a0-f88b-4b80-96dd-3b414a865f60", "name": "Overhead Press", "type": "WR", "primaryMuscleGroup": "frontShoulders", "notes": ""}, "notes": "", "sets": [{"value1": 61, "value2": 10, "checked": true}, {"value1": 61, "value2": 10, "checked": true}, {"value1": 61, "value2": 9, "checked": true}]},
   {"superSetId": "", "exercise": {"id": "2b14611a-b196-4f9a-948b-932b74a27963", "name": "Lateral Raises", "type": "WR", "primaryMuscleGroup": "frontShoulders", "notes": ""}, "notes": "", "sets": [{"value1": 21, "value2": 15, "checked": true}, {"value1": 21, "value2": 15, "checked": true}, {"value1": 21, "value2": 14, "checked": true}]},
   {"superSetId": "", "exercise": {"id": "a43373b9-86d7-4684-9d26-70ad1ec0039d", "name": "Tricep Extensions", "type": "WR", "primaryMuscleGroup": "triceps", "notes": ""}, "notes": "", "sets": [{"value1": 31, "value2": 12, "checked": true}, {"value1": 31, "value2": 12, "checked": true}, {"value1": 31, "value2": 11, "checked": true}]}
 ]'::jsonb,
 NOW() - INTERVAL '0 days', NOW() - INTERVAL '0 days')
ON CONFLICT (id) DO NOTHING;

-- ============================================================================
-- SEED DATA COMPLETE
-- ============================================================================
-- Summary:
-- - 27 exercises (weights, bodyweight, duration)
-- - 4 routine plans
-- - 6 routine templates (linked to plans)
-- - 15 routine logs with exercise logs containing sets with weight and reps values
-- All data is linked properly and spans the last 3 months, including today
-- ============================================================================

