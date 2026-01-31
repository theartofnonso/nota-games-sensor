-- Maps user IDs to FCM device tokens for push notifications.
-- One user can have multiple devices (tokens). Used by backend SendLoop/FCM.
create table if not exists public.user_device_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  device_id text not null,
  device_token text not null,
  platform text not null check (platform in ('android', 'ios')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, device_id)
);

create index if not exists user_device_tokens_user_id_idx
  on public.user_device_tokens (user_id);

alter table public.user_device_tokens enable row level security;

create policy "Users can manage their own device tokens"
  on public.user_device_tokens
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
