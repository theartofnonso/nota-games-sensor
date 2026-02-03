-- Nutrition templates (macro targets per client, set by coach)
-- Schema matches backend. Run BEFORE seed_demo_accounts.sql if the table does not exist.
create table if not exists public.nutrition_templates (
  id uuid not null default gen_random_uuid(),
  owner uuid not null references auth.users (id) on delete cascade,
  client_id uuid not null references public.clients (id) on delete cascade,
  calories_kcal numeric(8,2) not null default 0,
  protein_g numeric(8,2) not null default 0,
  carbs_g numeric(8,2) not null default 0,
  fats_g numeric(8,2) not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint nutrition_templates_pkey primary key (id)
);

create index if not exists nutrition_templates_owner_idx
  on public.nutrition_templates (owner);

create index if not exists nutrition_templates_client_id_idx
  on public.nutrition_templates (client_id);

create unique index if not exists nutrition_templates_client_id_unique
  on public.nutrition_templates (client_id);

alter table public.nutrition_templates enable row level security;

create policy "Nutrition templates readable by owner or client"
  on public.nutrition_templates for select
  using (auth.uid() = owner or auth.uid() = client_id);

create policy "Nutrition templates writable by owner"
  on public.nutrition_templates for insert
  with check (auth.uid() = owner);

create policy "Nutrition templates updatable by owner"
  on public.nutrition_templates for update
  using (auth.uid() = owner);

create policy "Nutrition templates deletable by owner"
  on public.nutrition_templates for delete
  using (auth.uid() = owner);
