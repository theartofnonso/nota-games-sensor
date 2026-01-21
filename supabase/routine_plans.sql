alter table public.routine_plans enable row level security;

create policy "Routine plans are readable by owner or client"
  on public.routine_plans
  for select
  using (auth.uid() = owner or auth.uid() = "clientId");

create policy "Routine plans are writable by owner"
  on public.routine_plans
  for insert
  with check (auth.uid() = owner);

create policy "Routine plans are updatable by owner"
  on public.routine_plans
  for update
  using (auth.uid() = owner);

create policy "Routine plans are deletable by owner"
  on public.routine_plans
  for delete
  using (auth.uid() = owner);
