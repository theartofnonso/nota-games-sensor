create table if not exists public.coach_decisions (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.clients(id) on delete cascade,
  coach_id uuid not null references auth.users(id) on delete cascade,
  summary text not null,
  created_at timestamptz not null default now()
);

create index if not exists coach_decisions_client_id_idx
  on public.coach_decisions (client_id);

create index if not exists coach_decisions_coach_id_idx
  on public.coach_decisions (coach_id);

create index if not exists coach_decisions_created_at_idx
  on public.coach_decisions (created_at);

alter table public.coach_decisions enable row level security;

create policy "Coach can view own decision logs"
  on public.coach_decisions
  for select
  using (auth.uid() = coach_id or auth.uid() = client_id);

create policy "Coach can insert own decision logs"
  on public.coach_decisions
  for insert
  with check (auth.uid() = coach_id);

create policy "Decision logs are immutable (no updates)"
  on public.coach_decisions
  for update
  using (false);

create policy "Decision logs are immutable (no deletes)"
  on public.coach_decisions
  for delete
  using (false);
