-- ============================================================================
-- TRACKR APP - SEED DATA
-- ============================================================================
-- Run this in Supabase SQL Editor AFTER running _setup.sql
-- This will create sample data for testing (you can delete later)
-- ============================================================================

-- Using specific owner UUID for testing: 72e0df29-9310-4075-b9be-e76028f9d6eb

-- ============================================================================
-- EXERCISES
-- ============================================================================

-- Chest Exercises
INSERT INTO public.exercises (id, owner, name, type, "primaryMuscleGroup", notes) VALUES
('a1b2c3d4-0001-0001-0001-000000000001', '72e0df29-9310-4075-b9be-e76028f9d6eb', 'Bench Press', 'WR', 'chest', 'Compound movement for chest, shoulders, and triceps'),
('a1b2c3d4-0001-0001-0001-000000000002', '72e0df29-9310-4075-b9be-e76028f9d6eb', 'Incline Dumbbell Press', 'WR', 'chest', 'Targets upper chest'),
('a1b2c3d4-0001-0001-0001-000000000003', '72e0df29-9310-4075-b9be-e76028f9d6eb', 'Push-Ups', 'BW', 'chest', 'Classic bodyweight chest exercise'),
('a1b2c3d4-0001-0001-0001-000000000004', '72e0df29-9310-4075-b9be-e76028f9d6eb', 'Cable Flyes', 'WR', 'chest', 'Isolation for chest with constant tension');

-- Back Exercises
INSERT INTO public.exercises (id, owner, name, type, "primaryMuscleGroup", notes) VALUES
('a1b2c3d4-0002-0002-0002-000000000001', '72e0df29-9310-4075-b9be-e76028f9d6eb', 'Deadlift', 'WR', 'back', 'King of all exercises - full posterior chain'),
('a1b2c3d4-0002-0002-0002-000000000002', '72e0df29-9310-4075-b9be-e76028f9d6eb', 'Pull-Ups', 'BW', 'lats', 'Essential for lat development'),
('a1b2c3d4-0002-0002-0002-000000000003', '72e0df29-9310-4075-b9be-e76028f9d6eb', 'Barbell Rows', 'WR', 'back', 'Great for back thickness'),
('a1b2c3d4-0002-0002-0002-000000000004', '72e0df29-9310-4075-b9be-e76028f9d6eb', 'Lat Pulldowns', 'WR', 'lats', 'Targets lats with controlled movement');

-- Leg Exercises
INSERT INTO public.exercises (id, owner, name, type, "primaryMuscleGroup", notes) VALUES
('a1b2c3d4-0003-0003-0003-000000000001', '72e0df29-9310-4075-b9be-e76028f9d6eb', 'Squats', 'WR', 'quadriceps', 'The king of leg exercises'),
('a1b2c3d4-0003-0003-0003-000000000002', '72e0df29-9310-4075-b9be-e76028f9d6eb', 'Romanian Deadlift', 'WR', 'hamstrings', 'Perfect for hamstring development'),
('a1b2c3d4-0003-0003-0003-000000000003', '72e0df29-9310-4075-b9be-e76028f9d6eb', 'Leg Press', 'WR', 'quadriceps', 'Great for quad volume'),
('a1b2c3d4-0003-0003-0003-000000000004', '72e0df29-9310-4075-b9be-e76028f9d6eb', 'Walking Lunges', 'BW', 'quadriceps', 'Functional leg movement'),
('a1b2c3d4-0003-0003-0003-000000000005', '72e0df29-9310-4075-b9be-e76028f9d6eb', 'Calf Raises', 'WR', 'calves', 'Essential for calf development');

-- Shoulder Exercises
INSERT INTO public.exercises (id, owner, name, type, "primaryMuscleGroup", notes) VALUES
('a1b2c3d4-0004-0004-0004-000000000001', '72e0df29-9310-4075-b9be-e76028f9d6eb', 'Overhead Press', 'WR', 'shoulders', 'Best compound for shoulders'),
('a1b2c3d4-0004-0004-0004-000000000002', '72e0df29-9310-4075-b9be-e76028f9d6eb', 'Lateral Raises', 'WR', 'shoulders', 'Isolation for side delts'),
('a1b2c3d4-0004-0004-0004-000000000003', '72e0df29-9310-4075-b9be-e76028f9d6eb', 'Face Pulls', 'WR', 'backShoulder', 'Essential for rear delts and shoulder health');

-- Arm Exercises
INSERT INTO public.exercises (id, owner, name, type, "primaryMuscleGroup", notes) VALUES
('a1b2c3d4-0005-0005-0005-000000000001', '72e0df29-9310-4075-b9be-e76028f9d6eb', 'Barbell Curls', 'WR', 'biceps', 'Classic bicep builder'),
('a1b2c3d4-0005-0005-0005-000000000002', '72e0df29-9310-4075-b9be-e76028f9d6eb', 'Hammer Curls', 'WR', 'biceps', 'Targets brachialis and forearms'),
('a1b2c3d4-0005-0005-0005-000000000003', '72e0df29-9310-4075-b9be-e76028f9d6eb', 'Tricep Dips', 'BW', 'triceps', 'Compound tricep movement'),
('a1b2c3d4-0005-0005-0005-000000000004', '72e0df29-9310-4075-b9be-e76028f9d6eb', 'Skull Crushers', 'WR', 'triceps', 'Isolation for triceps');

-- Core & Duration Exercises
INSERT INTO public.exercises (id, owner, name, type, "primaryMuscleGroup", notes) VALUES
('a1b2c3d4-0006-0006-0006-000000000001', '72e0df29-9310-4075-b9be-e76028f9d6eb', 'Plank', 'DR', 'abs', 'Isometric core strengthening'),
('a1b2c3d4-0006-0006-0006-000000000002', '72e0df29-9310-4075-b9be-e76028f9d6eb', 'Side Plank', 'DR', 'abs', 'Targets obliques'),
('a1b2c3d4-0006-0006-0006-000000000003', '72e0df29-9310-4075-b9be-e76028f9d6eb', 'Hanging Leg Raises', 'BW', 'abs', 'Advanced core exercise'),
('a1b2c3d4-0006-0006-0006-000000000004', '72e0df29-9310-4075-b9be-e76028f9d6eb', 'Russian Twists', 'BW', 'abs', 'Rotational core work');

-- ============================================================================
-- ROUTINE PLAN
-- ============================================================================

-- Create a sample plan (ID will be auto-generated)
-- We'll use a fixed ID for reference: 'SAMPLE_PLAN_001'
INSERT INTO public.routine_plans (id, owner, name, notes) VALUES
('550e8400-e29b-41d4-a716-446655440000', '72e0df29-9310-4075-b9be-e76028f9d6eb', 'Push Pull Legs', 'Classic 3-day split for building strength and size');

-- ============================================================================
-- ROUTINE TEMPLATES
-- ============================================================================

-- Push Day Template
INSERT INTO public.routine_templates (id, owner, "planId", name, notes, exercises) VALUES
('b1b2c3d4-1111-1111-1111-111111111111', '72e0df29-9310-4075-b9be-e76028f9d6eb', '550e8400-e29b-41d4-a716-446655440000', 
 'Push Day', 
 'Chest, Shoulders, and Triceps',
 '[
   {
     "notes": "Warm up properly",
     "exercise": {
       "id": "a1b2c3d4-0001-0001-0001-000000000001",
       "name": "Bench Press",
       "type": "WR",
       "primaryMuscleGroup": "chest",
       "notes": ""
     },
     "sets": [
       {"value1": 60, "value2": 5, "checked": false},
       {"value1": 70, "value2": 5, "checked": false},
       {"value1": 80, "value2": 5, "checked": false},
       {"value1": 80, "value2": 5, "checked": false}
     ]
   },
   {
     "notes": "",
     "exercise": {
       "id": "a1b2c3d4-0004-0004-0004-000000000001",
       "name": "Overhead Press",
       "type": "WR",
       "primaryMuscleGroup": "shoulders",
       "notes": ""
     },
     "sets": [
       {"value1": 40, "value2": 8, "checked": false},
       {"value1": 45, "value2": 8, "checked": false},
       {"value1": 50, "value2": 8, "checked": false}
     ]
   },
   {
     "notes": "",
     "exercise": {
       "id": "a1b2c3d4-0004-0004-0004-000000000002",
       "name": "Lateral Raises",
       "type": "WR",
       "primaryMuscleGroup": "shoulders",
       "notes": ""
     },
     "sets": [
       {"value1": 10, "value2": 12, "checked": false},
       {"value1": 12, "value2": 12, "checked": false},
       {"value1": 12, "value2": 12, "checked": false}
     ]
   },
   {
     "notes": "",
     "exercise": {
       "id": "a1b2c3d4-0005-0005-0005-000000000003",
       "name": "Tricep Dips",
       "type": "BW",
       "primaryMuscleGroup": "triceps",
       "notes": ""
     },
     "sets": [
       {"value1": 0, "value2": 10, "checked": false},
       {"value1": 0, "value2": 10, "checked": false},
       {"value1": 0, "value2": 10, "checked": false}
     ]
   }
 ]'::jsonb);

-- Pull Day Template
INSERT INTO public.routine_templates (id, owner, "planId", name, notes, exercises) VALUES
('b1b2c3d4-2222-2222-2222-222222222222', '72e0df29-9310-4075-b9be-e76028f9d6eb', '550e8400-e29b-41d4-a716-446655440000',
 'Pull Day',
 'Back and Biceps',
 '[
   {
     "notes": "Focus on form",
     "exercise": {
       "id": "a1b2c3d4-0002-0002-0002-000000000001",
       "name": "Deadlift",
       "type": "WR",
       "primaryMuscleGroup": "back",
       "notes": ""
     },
     "sets": [
       {"value1": 100, "value2": 5, "checked": false},
       {"value1": 120, "value2": 5, "checked": false},
       {"value1": 140, "value2": 5, "checked": false}
     ]
   },
   {
     "notes": "",
     "exercise": {
       "id": "a1b2c3d4-0002-0002-0002-000000000002",
       "name": "Pull-Ups",
       "type": "BW",
       "primaryMuscleGroup": "lats",
       "notes": ""
     },
     "sets": [
       {"value1": 0, "value2": 8, "checked": false},
       {"value1": 0, "value2": 8, "checked": false},
       {"value1": 0, "value2": 8, "checked": false}
     ]
   },
   {
     "notes": "",
     "exercise": {
       "id": "a1b2c3d4-0002-0002-0002-000000000003",
       "name": "Barbell Rows",
       "type": "WR",
       "primaryMuscleGroup": "back",
       "notes": ""
     },
     "sets": [
       {"value1": 60, "value2": 8, "checked": false},
       {"value1": 70, "value2": 8, "checked": false},
       {"value1": 70, "value2": 8, "checked": false}
     ]
   },
   {
     "notes": "",
     "exercise": {
       "id": "a1b2c3d4-0005-0005-0005-000000000001",
       "name": "Barbell Curls",
       "type": "WR",
       "primaryMuscleGroup": "biceps",
       "notes": ""
     },
     "sets": [
       {"value1": 30, "value2": 10, "checked": false},
       {"value1": 35, "value2": 10, "checked": false},
       {"value1": 35, "value2": 10, "checked": false}
     ]
   }
 ]'::jsonb);

-- Leg Day Template
INSERT INTO public.routine_templates (id, owner, "planId", name, notes, exercises) VALUES
('b1b2c3d4-3333-3333-3333-333333333333', '72e0df29-9310-4075-b9be-e76028f9d6eb', '550e8400-e29b-41d4-a716-446655440000',
 'Leg Day',
 'Quads, Hamstrings, and Calves',
 '[
   {
     "notes": "Go deep",
     "exercise": {
       "id": "a1b2c3d4-0003-0003-0003-000000000001",
       "name": "Squats",
       "type": "WR",
       "primaryMuscleGroup": "quadriceps",
       "notes": ""
     },
     "sets": [
       {"value1": 80, "value2": 5, "checked": false},
       {"value1": 100, "value2": 5, "checked": false},
       {"value1": 120, "value2": 5, "checked": false},
       {"value1": 120, "value2": 5, "checked": false}
     ]
   },
   {
     "notes": "",
     "exercise": {
       "id": "a1b2c3d4-0003-0003-0003-000000000002",
       "name": "Romanian Deadlift",
       "type": "WR",
       "primaryMuscleGroup": "hamstrings",
       "notes": ""
     },
     "sets": [
       {"value1": 60, "value2": 8, "checked": false},
       {"value1": 70, "value2": 8, "checked": false},
       {"value1": 80, "value2": 8, "checked": false}
     ]
   },
   {
     "notes": "",
     "exercise": {
       "id": "a1b2c3d4-0003-0003-0003-000000000004",
       "name": "Walking Lunges",
       "type": "BW",
       "primaryMuscleGroup": "quadriceps",
       "notes": ""
     },
     "sets": [
       {"value1": 0, "value2": 20, "checked": false},
       {"value1": 0, "value2": 20, "checked": false},
       {"value1": 0, "value2": 20, "checked": false}
     ]
   },
   {
     "notes": "",
     "exercise": {
       "id": "a1b2c3d4-0003-0003-0003-000000000005",
       "name": "Calf Raises",
       "type": "WR",
       "primaryMuscleGroup": "calves",
       "notes": ""
     },
     "sets": [
       {"value1": 50, "value2": 15, "checked": false},
       {"value1": 60, "value2": 15, "checked": false},
       {"value1": 60, "value2": 15, "checked": false}
     ]
   }
 ]'::jsonb);

-- ============================================================================
-- ROUTINE LOGS (completed workouts)
-- ============================================================================

-- Using the template UUIDs created above:
-- Push Day: b1b2c3d4-1111-1111-1111-111111111111
-- Pull Day: b1b2c3d4-2222-2222-2222-222222222222
-- Leg Day: b1b2c3d4-3333-3333-3333-333333333333

-- Push Day Log - 3 days ago
INSERT INTO public.routine_logs (owner, "templateId", name, notes, "startTime", "endTime", exercises) VALUES
('72e0df29-9310-4075-b9be-e76028f9d6eb', 'b1b2c3d4-1111-1111-1111-111111111111',
 'Push Day',
 'Felt strong today!',
 NOW() - INTERVAL '3 days',
 NOW() - INTERVAL '3 days' + INTERVAL '1 hour 15 minutes',
 '[
   {
     "notes": "Good warm up sets",
     "exercise": {
       "id": "a1b2c3d4-0001-0001-0001-000000000001",
       "name": "Bench Press",
       "type": "WR",
       "primaryMuscleGroup": "chest",
       "notes": ""
     },
     "sets": [
       {"value1": 60, "value2": 5, "checked": true},
       {"value1": 70, "value2": 5, "checked": true},
       {"value1": 80, "value2": 5, "checked": true},
       {"value1": 80, "value2": 4, "checked": true}
     ]
   },
   {
     "notes": "",
     "exercise": {
       "id": "a1b2c3d4-0004-0004-0004-000000000001",
       "name": "Overhead Press",
       "type": "WR",
       "primaryMuscleGroup": "shoulders",
       "notes": ""
     },
     "sets": [
       {"value1": 40, "value2": 8, "checked": true},
       {"value1": 45, "value2": 8, "checked": true},
       {"value1": 50, "value2": 7, "checked": true}
     ]
   },
   {
     "notes": "",
     "exercise": {
       "id": "a1b2c3d4-0004-0004-0004-000000000002",
       "name": "Lateral Raises",
       "type": "WR",
       "primaryMuscleGroup": "shoulders",
       "notes": ""
     },
     "sets": [
       {"value1": 10, "value2": 12, "checked": true},
       {"value1": 12, "value2": 12, "checked": true},
       {"value1": 12, "value2": 10, "checked": true}
     ]
   },
   {
     "notes": "Bodyweight felt heavy",
     "exercise": {
       "id": "a1b2c3d4-0005-0005-0005-000000000003",
       "name": "Tricep Dips",
       "type": "BW",
       "primaryMuscleGroup": "triceps",
       "notes": ""
     },
     "sets": [
       {"value1": 0, "value2": 10, "checked": true},
       {"value1": 0, "value2": 9, "checked": true},
       {"value1": 0, "value2": 8, "checked": true}
     ]
   }
 ]'::jsonb);

-- Pull Day Log - 5 days ago
INSERT INTO public.routine_logs (owner, "templateId", name, notes, "startTime", "endTime", exercises) VALUES
('72e0df29-9310-4075-b9be-e76028f9d6eb', 'b1b2c3d4-2222-2222-2222-222222222222',
 'Pull Day',
 'Back was pumped!',
 NOW() - INTERVAL '5 days',
 NOW() - INTERVAL '5 days' + INTERVAL '1 hour 20 minutes',
 '[
   {
     "notes": "New PR!",
     "exercise": {
       "id": "a1b2c3d4-0002-0002-0002-000000000001",
       "name": "Deadlift",
       "type": "WR",
       "primaryMuscleGroup": "back",
       "notes": ""
     },
     "sets": [
       {"value1": 100, "value2": 5, "checked": true},
       {"value1": 120, "value2": 5, "checked": true},
       {"value1": 140, "value2": 5, "checked": true}
     ]
   },
   {
     "notes": "",
     "exercise": {
       "id": "a1b2c3d4-0002-0002-0002-000000000002",
       "name": "Pull-Ups",
       "type": "BW",
       "primaryMuscleGroup": "lats",
       "notes": ""
     },
     "sets": [
       {"value1": 0, "value2": 8, "checked": true},
       {"value1": 0, "value2": 8, "checked": true},
       {"value1": 0, "value2": 7, "checked": true}
     ]
   },
   {
     "notes": "",
     "exercise": {
       "id": "a1b2c3d4-0002-0002-0002-000000000003",
       "name": "Barbell Rows",
       "type": "WR",
       "primaryMuscleGroup": "back",
       "notes": ""
     },
     "sets": [
       {"value1": 60, "value2": 8, "checked": true},
       {"value1": 70, "value2": 8, "checked": true},
       {"value1": 70, "value2": 8, "checked": true}
     ]
   },
   {
     "notes": "",
     "exercise": {
       "id": "a1b2c3d4-0005-0005-0005-000000000001",
       "name": "Barbell Curls",
       "type": "WR",
       "primaryMuscleGroup": "biceps",
       "notes": ""
     },
     "sets": [
       {"value1": 30, "value2": 10, "checked": true},
       {"value1": 35, "value2": 10, "checked": true},
       {"value1": 35, "value2": 9, "checked": true}
     ]
   }
 ]'::jsonb);

-- Leg Day Log - 7 days ago
INSERT INTO public.routine_logs (owner, "templateId", name, notes, "startTime", "endTime", exercises) VALUES
('72e0df29-9310-4075-b9be-e76028f9d6eb', 'b1b2c3d4-3333-3333-3333-333333333333',
 'Leg Day',
 'Tough but good',
 NOW() - INTERVAL '7 days',
 NOW() - INTERVAL '7 days' + INTERVAL '1 hour 30 minutes',
 '[
   {
     "notes": "",
     "exercise": {
       "id": "a1b2c3d4-0003-0003-0003-000000000001",
       "name": "Squats",
       "type": "WR",
       "primaryMuscleGroup": "quadriceps",
       "notes": ""
     },
     "sets": [
       {"value1": 80, "value2": 5, "checked": true},
       {"value1": 100, "value2": 5, "checked": true},
       {"value1": 120, "value2": 5, "checked": true},
       {"value1": 120, "value2": 5, "checked": true}
     ]
   },
   {
     "notes": "",
     "exercise": {
       "id": "a1b2c3d4-0003-0003-0003-000000000002",
       "name": "Romanian Deadlift",
       "type": "WR",
       "primaryMuscleGroup": "hamstrings",
       "notes": ""
     },
     "sets": [
       {"value1": 60, "value2": 8, "checked": true},
       {"value1": 70, "value2": 8, "checked": true},
       {"value1": 80, "value2": 8, "checked": true}
     ]
   },
   {
     "notes": "Legs were shaking",
     "exercise": {
       "id": "a1b2c3d4-0003-0003-0003-000000000004",
       "name": "Walking Lunges",
       "type": "BW",
       "primaryMuscleGroup": "quadriceps",
       "notes": ""
     },
     "sets": [
       {"value1": 0, "value2": 20, "checked": true},
       {"value1": 0, "value2": 18, "checked": true},
       {"value1": 0, "value2": 16, "checked": true}
     ]
   },
   {
     "notes": "",
     "exercise": {
       "id": "a1b2c3d4-0003-0003-0003-000000000005",
       "name": "Calf Raises",
       "type": "WR",
       "primaryMuscleGroup": "calves",
       "notes": ""
     },
     "sets": [
       {"value1": 50, "value2": 15, "checked": true},
       {"value1": 60, "value2": 15, "checked": true},
       {"value1": 60, "value2": 15, "checked": true}
     ]
   }
 ]'::jsonb);

-- Another Push Day Log - 10 days ago (to show progression)
INSERT INTO public.routine_logs (owner, "templateId", name, notes, "startTime", "endTime", exercises) VALUES
('72e0df29-9310-4075-b9be-e76028f9d6eb', 'b1b2c3d4-1111-1111-1111-111111111111',
 'Push Day',
 'Getting stronger',
 NOW() - INTERVAL '10 days',
 NOW() - INTERVAL '10 days' + INTERVAL '1 hour 10 minutes',
 '[
   {
     "notes": "",
     "exercise": {
       "id": "a1b2c3d4-0001-0001-0001-000000000001",
       "name": "Bench Press",
       "type": "WR",
       "primaryMuscleGroup": "chest",
       "notes": ""
     },
     "sets": [
       {"value1": 55, "value2": 5, "checked": true},
       {"value1": 65, "value2": 5, "checked": true},
       {"value1": 75, "value2": 5, "checked": true},
       {"value1": 75, "value2": 5, "checked": true}
     ]
   },
   {
     "notes": "",
     "exercise": {
       "id": "a1b2c3d4-0004-0004-0004-000000000001",
       "name": "Overhead Press",
       "type": "WR",
       "primaryMuscleGroup": "shoulders",
       "notes": ""
     },
     "sets": [
       {"value1": 35, "value2": 8, "checked": true},
       {"value1": 40, "value2": 8, "checked": true},
       {"value1": 45, "value2": 7, "checked": true}
     ]
   }
 ]'::jsonb);

-- ============================================================================
-- SEED DATA COMPLETE
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE '✅ Seed data inserted successfully!';
    RAISE NOTICE '📝 Created 24 exercises';
    RAISE NOTICE '📋 Created 1 routine plan (Push Pull Legs)';
    RAISE NOTICE '🏋️ Created 3 routine templates (Push, Pull, Legs)';
    RAISE NOTICE '📊 Created 4 routine logs (completed workouts)';
    RAISE NOTICE '🗑️  You can delete this data later when ready';
END $$;

