-- Allow coaches (and clients for their assigned templates) to write
-- routine_templates, template_exercises, and template_sets.
-- Fixes: new row violates row-level security policy for table "template_exercises"

begin;

-- ---------------------------------------------------------------------------
-- routine_templates: INSERT, UPDATE, DELETE when owner or assigned client
-- ---------------------------------------------------------------------------
drop policy if exists routine_templates_insert_owner_or_client on public.routine_templates;
create policy routine_templates_insert_owner_or_client
on public.routine_templates
for insert
to authenticated
with check (
  auth.uid() = owner
  or auth.uid() = "clientId"
);

drop policy if exists routine_templates_update_owner_or_client on public.routine_templates;
create policy routine_templates_update_owner_or_client
on public.routine_templates
for update
to authenticated
using (
  auth.uid() = owner
  or auth.uid() = "clientId"
)
with check (
  auth.uid() = owner
  or auth.uid() = "clientId"
);

drop policy if exists routine_templates_delete_owner_or_client on public.routine_templates;
create policy routine_templates_delete_owner_or_client
on public.routine_templates
for delete
to authenticated
using (
  auth.uid() = owner
  or auth.uid() = "clientId"
);

-- ---------------------------------------------------------------------------
-- template_exercises: INSERT, DELETE when parent template is writable
-- ---------------------------------------------------------------------------
drop policy if exists template_exercises_insert_via_template on public.template_exercises;
create policy template_exercises_insert_via_template
on public.template_exercises
for insert
to authenticated
with check (
  exists (
    select 1
    from public.routine_templates rt
    where rt.id = template_exercises.template_id
      and (auth.uid() = rt.owner or auth.uid() = rt."clientId")
  )
);

drop policy if exists template_exercises_delete_via_template on public.template_exercises;
create policy template_exercises_delete_via_template
on public.template_exercises
for delete
to authenticated
using (
  exists (
    select 1
    from public.routine_templates rt
    where rt.id = template_exercises.template_id
      and (auth.uid() = rt.owner or auth.uid() = rt."clientId")
  )
);

-- ---------------------------------------------------------------------------
-- template_sets: INSERT when parent template_exercise's template is writable
-- ---------------------------------------------------------------------------
drop policy if exists template_sets_insert_via_template_exercise on public.template_sets;
create policy template_sets_insert_via_template_exercise
on public.template_sets
for insert
to authenticated
with check (
  exists (
    select 1
    from public.template_exercises te
    join public.routine_templates rt on rt.id = te.template_id
    where te.id = template_sets.template_exercise_id
      and (auth.uid() = rt.owner or auth.uid() = rt."clientId")
  )
);

commit;
