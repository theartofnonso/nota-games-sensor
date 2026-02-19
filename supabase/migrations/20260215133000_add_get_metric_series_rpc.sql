-- Deterministic analytics RPC over normalized training data.
-- Returns bucketed metric series for exercise/session queries.

begin;

-- Query-support indexes for metric-series workloads.
create index if not exists idx_session_exercises_session_exercise
  on public.session_exercises(session_id, exercise_id);

create index if not exists idx_session_sets_session_exercise_created_at
  on public.session_sets(session_exercise_id, created_at);

drop function if exists public.get_metric_series(
  uuid,
  text,
  text,
  text,
  date,
  date,
  text
);

create function public.get_metric_series(
  p_user_id uuid,
  p_entity_type text,
  p_entity_id text,
  p_metric text,
  p_start_date date,
  p_end_date date,
  p_group_by text
)
returns table (
  bucket_start date,
  metric_value numeric
)
language plpgsql
stable
security invoker
as $$
declare
  v_entity_type text := lower(coalesce(p_entity_type, ''));
  v_metric text := lower(coalesce(p_metric, ''));
  v_group_by text := lower(coalesce(p_group_by, ''));
begin
  if v_entity_type not in ('exercise', 'session') then
    raise exception 'Unsupported entity_type: %', p_entity_type;
  end if;

  if v_group_by not in ('day', 'week', 'month') then
    raise exception 'Unsupported group_by: %', p_group_by;
  end if;

  if p_start_date is null or p_end_date is null then
    raise exception 'start_date and end_date are required';
  end if;

  if p_start_date > p_end_date then
    raise exception 'start_date cannot be after end_date';
  end if;

  if v_entity_type = 'exercise' and nullif(trim(coalesce(p_entity_id, '')), '') is null then
    raise exception 'entity_id is required for exercise metrics';
  end if;

  if v_entity_type = 'exercise' and v_metric not in (
    'total_volume',
    'total_reps',
    'avg_load',
    'max_load',
    'set_count',
    'session_count'
  ) then
    raise exception 'Unsupported metric % for entity_type=exercise', p_metric;
  end if;

  if v_entity_type = 'session' and v_metric not in (
    'session_total_volume',
    'session_total_reps',
    'session_count'
  ) then
    raise exception 'Unsupported metric % for entity_type=session', p_metric;
  end if;

  if v_metric = 'session_count' then
    return query
    select
      date_trunc(v_group_by, ws.start_time)::date as bucket_start,
      count(distinct ws.id)::numeric as metric_value
    from public.workout_sessions ws
    where ws.user_id = p_user_id
      and ws.start_time::date between p_start_date and p_end_date
      and (
        v_entity_type <> 'session'
        or nullif(trim(coalesce(p_entity_id, '')), '') is null
        or ws.id::text = p_entity_id
      )
    group by 1
    order by 1;
    return;
  end if;

  return query
  with base as (
    select
      ws.id as session_id,
      ws.start_time,
      se.exercise_id,
      ss.reps,
      ss.weight
    from public.workout_sessions ws
    join public.session_exercises se
      on se.session_id = ws.id
    join public.session_sets ss
      on ss.session_exercise_id = se.id
    where ws.user_id = p_user_id
      and ws.start_time::date between p_start_date and p_end_date
      and coalesce(ss.is_completed, true) = true
      and (
        v_entity_type <> 'exercise'
        or se.exercise_id = p_entity_id
      )
      and (
        v_entity_type <> 'session'
        or nullif(trim(coalesce(p_entity_id, '')), '') is null
        or ws.id::text = p_entity_id
      )
  )
  select
    date_trunc(v_group_by, b.start_time)::date as bucket_start,
    case
      when v_metric = 'total_volume'
        then sum(coalesce(b.weight, 0) * coalesce(b.reps, 0))::numeric
      when v_metric = 'total_reps'
        then sum(coalesce(b.reps, 0))::numeric
      when v_metric = 'avg_load'
        then avg(b.weight)::numeric
      when v_metric = 'max_load'
        then max(b.weight)::numeric
      when v_metric = 'set_count'
        then count(*)::numeric
      when v_metric = 'session_total_volume'
        then sum(coalesce(b.weight, 0) * coalesce(b.reps, 0))::numeric
      when v_metric = 'session_total_reps'
        then sum(coalesce(b.reps, 0))::numeric
      else null::numeric
    end as metric_value
  from base b
  group by 1
  order by 1;
end;
$$;

grant execute on function public.get_metric_series(
  uuid,
  text,
  text,
  text,
  date,
  date,
  text
) to authenticated;

commit;
