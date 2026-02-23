-- Add new exercise animations (Woman dumbbell variants) to canonical exercises table.

begin;

insert into public.exercises (id, name, type, lottie_path, created_at)
values
  ('ex-back-extension-db', 'Back Extension (Dumbbell)', 'WR', 'assets/lottie/Woman Doing Dumbbell Back Extension Exercise for Glute and Lower Back.json', now()),
  ('ex-lying-leg-curl-db', 'Lying Leg Curl (Dumbbell)', 'WR', 'assets/lottie/Woman Doing Dumbbell Bench Lying Leg Curl Exercise for Legs.json', now()),
  ('ex-preacher-bicep-curl-single-arm', 'Preacher Bicep Curl (Single-Arm)', 'WR', 'assets/lottie/Woman Doing Dumbbell Seated One Arm Preacher Bicep Curl Exercise for Arm.json', now()),
  ('ex-preacher-hammer-curl-single-arm', 'Preacher Hammer Curl (Single-Arm)', 'WR', 'assets/lottie/Woman Doing Dumbbell Seated One Arm Preacher Hammer Curl Exercise for Arm.json', now()),
  ('ex-stiff-leg-deadlift-single-db', 'Stiff Leg Deadlift (Single-Leg, Dumbbell)', 'WR', 'assets/lottie/Woman Doing Dumbbell Single Stiff Leg Deadlift Exercise for Legs.json', now()),
  ('ex-calf-raise-deficit-stand-db', 'Calf Raise (Deficit, Standing, Dumbbell)', 'WR', 'assets/lottie/Woman Doing Dumbbell Standing Deficit Calf Raise Exercise for Calves.json', now()),
  ('ex-calf-raise-deficit-single-leg-db', 'Calf Raise (Deficit, Single-Leg, Standing, Dumbbell)', 'WR', 'assets/lottie/Woman Doing Dumbbell Standing Single Leg Deficit Calf Raise Exercise for Calves.json', now()),
  ('ex-stiff-leg-deadlift-db', 'Stiff Leg Deadlift (Dumbbell)', 'WR', 'assets/lottie/Woman Doing Dumbbell Stiff Leg Deadlift Exercise for Legs.json', now())
on conflict (id) do update
set
  name = excluded.name,
  type = excluded.type,
  lottie_path = excluded.lottie_path;

commit;
