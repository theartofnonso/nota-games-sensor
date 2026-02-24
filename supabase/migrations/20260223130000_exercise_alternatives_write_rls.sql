-- Allow coaches (and assigned clients) to INSERT/DELETE exercise_alternatives
-- when the parent template_exercise's template is writable.

begin;

drop policy if exists exercise_alternatives_insert_via_template_exercise on public.exercise_alternatives;
create policy exercise_alternatives_insert_via_template_exercise
on public.exercise_alternatives
for insert
to authenticated
with check (
  exists (
    select 1
    from public.template_exercises te
    join public.routine_templates rt on rt.id = te.template_id
    where te.id = exercise_alternatives.template_exercise_id
      and (auth.uid() = rt.owner or auth.uid() = rt."clientId")
  )
);

drop policy if exists exercise_alternatives_delete_via_template_exercise on public.exercise_alternatives;
create policy exercise_alternatives_delete_via_template_exercise
on public.exercise_alternatives
for delete
to authenticated
using (
  exists (
    select 1
    from public.template_exercises te
    join public.routine_templates rt on rt.id = te.template_id
    where te.id = exercise_alternatives.template_exercise_id
      and (auth.uid() = rt.owner or auth.uid() = rt."clientId")
  )
);

commit;
