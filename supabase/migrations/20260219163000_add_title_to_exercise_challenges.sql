begin;

alter table public.exercise_challenges
  add column if not exists title text not null;

alter table public.exercise_challenges
  alter column title set not null;

alter table public.exercise_challenges
  drop constraint if exists exercise_challenges_title_not_blank;

alter table public.exercise_challenges
  add constraint exercise_challenges_title_not_blank
  check (length(trim(title)) > 0);

commit;
