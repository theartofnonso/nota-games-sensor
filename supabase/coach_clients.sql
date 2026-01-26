create table if not exists public.coach_clients (
  id uuid primary key default gen_random_uuid(),
  coach_id uuid not null,
  client_id uuid not null,
  created_at timestamptz not null default now()
);

create unique index if not exists coach_clients_unique
  on public.coach_clients (coach_id, client_id);

create index if not exists coach_clients_coach_id_idx
  on public.coach_clients (coach_id);

create index if not exists coach_clients_client_id_idx
  on public.coach_clients (client_id);

alter table public.coach_clients enable row level security;

create policy "Coach can read their clients"
  on public.coach_clients
  for select
  using (auth.uid() = coach_id);

create policy "Client can read their coach"
  on public.coach_clients
  for select
  using (auth.uid() = client_id);
