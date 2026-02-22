begin;

alter table public.exercise_challenges
  add column if not exists template_id uuid references public.routine_templates(id) on delete cascade,
  add column if not exists template_exercise_id text,
  add column if not exists target_weight numeric,
  add column if not exists target_reps integer,
  add column if not exists target_duration_seconds integer;

alter table public.exercise_challenges
  alter column template_id set not null,
  alter column template_exercise_id set not null;

alter table public.exercise_challenges
  drop constraint if exists exercise_challenges_target_config_valid;

alter table public.exercise_challenges
  add constraint exercise_challenges_target_config_valid
  check (
    (
      exercise_type = 'WR'
      and target_weight is not null and target_weight > 0
      and target_reps is not null and target_reps > 0
      and target_duration_seconds is null
    )
    or (
      exercise_type = 'BW'
      and target_weight is null
      and target_reps is not null and target_reps > 0
      and target_duration_seconds is null
    )
    or (
      exercise_type = 'DR'
      and target_weight is null
      and target_reps is null
      and target_duration_seconds is not null and target_duration_seconds > 0
    )
  );

create unique index if not exists idx_exercise_challenges_template_exercise_unique
  on public.exercise_challenges(client_id, template_id, template_exercise_id);

commit;
