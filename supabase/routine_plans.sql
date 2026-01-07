-- ============================================================================
-- ROUTINE PLANS TABLE
-- ============================================================================
-- Stores workout plans that organize multiple templates
-- ============================================================================

-- Create table
CREATE TABLE IF NOT EXISTS public.routine_plans (
    id UUID NOT NULL DEFAULT extensions.uuid_generate_v4(),
    owner UUID NOT NULL DEFAULT auth.uid(),
    name TEXT NOT NULL,
    notes TEXT NULL DEFAULT ''::text,
    "clientId" UUID NULL,
    "createdAt" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    "updatedAt" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT routine_plans_pkey PRIMARY KEY (id),
    CONSTRAINT routine_plans_clientid_fkey FOREIGN KEY ("clientId") REFERENCES clients(id) ON DELETE SET NULL,
    CONSTRAINT routine_plans_owner_fkey FOREIGN KEY (owner) REFERENCES auth.users(id) ON DELETE CASCADE
) TABLESPACE pg_default;

-- Add comment
COMMENT ON TABLE public.routine_plans IS 'Workout plans that organize multiple templates';
COMMENT ON COLUMN public.routine_plans.name IS 'Plan name';
COMMENT ON COLUMN public.routine_plans.notes IS 'User notes about the plan';
COMMENT ON COLUMN public.routine_plans."clientId" IS 'Client ID (UUID) for system plans (null for user-created plans). References clients table.';

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_routine_plans_owner 
    ON public.routine_plans USING btree (owner) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_routine_plans_createdAt 
    ON public.routine_plans USING btree ("createdAt" DESC) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_routine_plans_owner_createdAt 
    ON public.routine_plans USING btree (owner, "createdAt" DESC) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_routine_plans_name 
    ON public.routine_plans USING btree (name) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS routine_plans_clientid_idx 
    ON public.routine_plans USING btree ("clientId") TABLESPACE pg_default;

-- Create updatedAt trigger
CREATE TRIGGER update_routine_plans_updatedAt 
    BEFORE UPDATE ON public.routine_plans
    FOR EACH ROW 
    EXECUTE FUNCTION update_updatedAt_column();

-- ============================================================================
-- ROW LEVEL SECURITY
-- ============================================================================

-- Enable RLS
ALTER TABLE public.routine_plans ENABLE ROW LEVEL SECURITY;

-- Users can view their own routine plans and system plans (with clientId)
CREATE POLICY "Users can view their own routine_plans"
    ON public.routine_plans
    FOR SELECT
    USING (auth.uid() = owner OR "clientId" IS NOT NULL);

-- Users can insert their own routine plans
CREATE POLICY "Users can insert their own routine_plans"
    ON public.routine_plans
    FOR INSERT
    WITH CHECK (auth.uid() = owner);

-- Users can update their own routine plans (but not system plans)
CREATE POLICY "Users can update their own routine_plans"
    ON public.routine_plans
    FOR UPDATE
    USING (auth.uid() = owner AND "clientId" IS NULL)
    WITH CHECK (auth.uid() = owner AND "clientId" IS NULL);

-- Users can delete their own routine plans (but not system plans)
CREATE POLICY "Users can delete their own routine_plans"
    ON public.routine_plans
    FOR DELETE
    USING (auth.uid() = owner AND "clientId" IS NULL);

