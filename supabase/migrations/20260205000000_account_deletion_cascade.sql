-- Account deletion (clients only; we never delete coach accounts).
-- The Edge Function deletes only the client's auth.users(id). This migration ensures
-- ON DELETE CASCADE so all their data is removed and coach data is never touched.
--
-- CASCADE logic:
-- (A) What the client OWNS (created by them, keyed by their auth id)
--     -> FK to auth.users(id) ON DELETE CASCADE. When client's auth user is deleted,
--     these rows are removed: clients, routine_logs, user_device_tokens, exercises, nutrition_logs.
--
-- (B) What is ASSIGNED TO the client (keyed by client_id/clientId -> clients(id))
--     -> FK to clients(id) ON DELETE CASCADE. When clients row is deleted (from A),
--     these rows are removed: coach_clients, nutrition_templates, routine_plans,
--     routine_templates (and templates via planId when the plan is deleted).
--
-- (C) Coach data is never deleted: we do not add owner -> auth.users CASCADE for
--     routine_plans, routine_templates, or nutrition_templates (coaches own those).
--     We do not touch coach_id FKs.

-- (A) Client-owned: keyed by auth id ----

-- 1. clients: id = auth user id
ALTER TABLE public.clients
  DROP CONSTRAINT IF EXISTS clients_id_fkey;
ALTER TABLE public.clients
  ADD CONSTRAINT clients_id_fkey
  FOREIGN KEY (id) REFERENCES auth.users (id) ON DELETE CASCADE;

-- 2. routine_logs: owner = client (client creates logs)
ALTER TABLE public.routine_logs
  DROP CONSTRAINT IF EXISTS routine_logs_owner_fkey;
ALTER TABLE public.routine_logs
  ADD CONSTRAINT routine_logs_owner_fkey
  FOREIGN KEY (owner) REFERENCES auth.users (id) ON DELETE CASCADE;

-- 3. user_device_tokens: user_id = client
ALTER TABLE public.user_device_tokens
  DROP CONSTRAINT IF EXISTS user_device_tokens_user_id_fkey;
ALTER TABLE public.user_device_tokens
  ADD CONSTRAINT user_device_tokens_user_id_fkey
  FOREIGN KEY (user_id) REFERENCES auth.users (id) ON DELETE CASCADE;

-- 4. exercises: owner = client (client creates exercises)
ALTER TABLE public.exercises
  DROP CONSTRAINT IF EXISTS exercises_owner_fkey;
ALTER TABLE public.exercises
  ADD CONSTRAINT exercises_owner_fkey
  FOREIGN KEY (owner) REFERENCES auth.users (id) ON DELETE CASCADE;

-- 5. nutrition_logs: user_id = client (client creates logs)
ALTER TABLE public.nutrition_logs
  DROP CONSTRAINT IF EXISTS nutrition_logs_user_id_fkey;
ALTER TABLE public.nutrition_logs
  ADD CONSTRAINT nutrition_logs_user_id_fkey
  FOREIGN KEY (user_id) REFERENCES auth.users (id) ON DELETE CASCADE;

-- (B) Assigned to client: keyed by client_id/clientId -> clients(id) ----

-- 6. coach_clients: link removed when client is deleted
ALTER TABLE public.coach_clients
  DROP CONSTRAINT IF EXISTS coach_clients_client_id_fkey;
ALTER TABLE public.coach_clients
  ADD CONSTRAINT coach_clients_client_id_fkey
  FOREIGN KEY (client_id) REFERENCES public.clients (id) ON DELETE CASCADE;

-- 7. nutrition_templates: row for this client (coach-owned; removed when client is deleted)
ALTER TABLE public.nutrition_templates
  DROP CONSTRAINT IF EXISTS nutrition_templates_client_id_fkey;
ALTER TABLE public.nutrition_templates
  ADD CONSTRAINT nutrition_templates_client_id_fkey
  FOREIGN KEY (client_id) REFERENCES public.clients (id) ON DELETE CASCADE;

-- 8. routine_plans: plan assigned to this client (coach-owned; removed when client is deleted)
ALTER TABLE public.routine_plans
  DROP CONSTRAINT IF EXISTS routine_plans_clientid_fkey;
ALTER TABLE public.routine_plans
  ADD CONSTRAINT routine_plans_clientid_fkey
  FOREIGN KEY ("clientId") REFERENCES public.clients (id) ON DELETE CASCADE;

-- 9. routine_templates: template assigned to this client (coach-owned; removed when client is deleted)
ALTER TABLE public.routine_templates
  DROP CONSTRAINT IF EXISTS routine_templates_clientid_fkey;
ALTER TABLE public.routine_templates
  ADD CONSTRAINT routine_templates_clientid_fkey
  FOREIGN KEY ("clientId") REFERENCES public.clients (id) ON DELETE CASCADE;

-- 10. routine_templates: template for a plan (removed when that plan is deleted in step 8)
ALTER TABLE public.routine_templates
  DROP CONSTRAINT IF EXISTS routine_templates_planid_fkey;
ALTER TABLE public.routine_templates
  ADD CONSTRAINT routine_templates_planid_fkey
  FOREIGN KEY ("planId") REFERENCES public.routine_plans (id) ON DELETE CASCADE;
