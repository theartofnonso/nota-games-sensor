-- Allow clients to assign themselves to a coach (choose coach flow).
create policy "Client can assign themselves to a coach"
  on public.coach_clients
  for insert
  with check (auth.uid() = client_id);

-- Allow authenticated users to read coaches (for coach selection flow).
alter table public.coaches enable row level security;
create policy "Authenticated users can read coaches"
  on public.coaches
  for select
  using (auth.role() = 'authenticated');
