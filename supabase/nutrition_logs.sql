-- Nutrition logs table (macros source of truth; calories derived in app)
create table if not exists public.nutrition_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  food_name text not null,
  protein_g numeric(8,2) not null default 0,
  carbs_g numeric(8,2) not null default 0,
  fats_g numeric(8,2) not null default 0,
  logged_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists nutrition_logs_user_logged_at_idx
  on public.nutrition_logs (user_id, logged_at desc);

create or replace function public.set_nutrition_logs_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists nutrition_logs_set_updated_at on public.nutrition_logs;
create trigger nutrition_logs_set_updated_at
before update on public.nutrition_logs
for each row execute function public.set_nutrition_logs_updated_at();

alter table public.nutrition_logs enable row level security;

create policy "Nutrition logs are readable by owner"
on public.nutrition_logs
for select
using (auth.uid() = user_id);

create policy "Nutrition logs are readable by coaches"
on public.nutrition_logs
for select
using (exists (
  select 1
  from public.coaches
  where id = auth.uid()
));

create policy "Nutrition logs are insertable by owner"
on public.nutrition_logs
for insert
with check (auth.uid() = user_id);

create policy "Nutrition logs are updatable by owner"
on public.nutrition_logs
for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

create policy "Nutrition logs are deletable by owner"
on public.nutrition_logs
for delete
using (auth.uid() = user_id);
