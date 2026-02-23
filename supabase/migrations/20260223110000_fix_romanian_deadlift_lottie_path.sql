-- Fix ex-deadlift-romanian-db lottie_path: the file is named
-- "Man Doing Romanian Dumbbell Deadlift Exercise for Legs.json"
-- not "Man Doing Dumbbell Romanian Deadlift Exercise For Legs.json"
UPDATE public.exercises
SET lottie_path = 'assets/lottie/Man Doing Romanian Dumbbell Deadlift Exercise for Legs.json'
WHERE id = 'ex-deadlift-romanian-db'
  AND lottie_path = 'assets/lottie/Man Doing Dumbbell Romanian Deadlift Exercise For Legs.json';
