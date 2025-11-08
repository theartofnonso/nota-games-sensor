-- ============================================================================
-- ROUTINE PLANS TABLE
-- ============================================================================
-- Stores workout plans that organize multiple templates
-- ============================================================================

-- Create table
CREATE TABLE IF NOT EXISTS public.routine_plans (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    owner UUID NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    notes TEXT DEFAULT '',
    "createdAt" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    "updatedAt" TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Add comment
COMMENT ON TABLE public.routine_plans IS 'Workout plans that organize multiple templates';
COMMENT ON COLUMN public.routine_plans.name IS 'Plan name';
COMMENT ON COLUMN public.routine_plans.notes IS 'User notes about the plan';

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_routine_plans_owner 
    ON public.routine_plans(owner);

CREATE INDEX IF NOT EXISTS idx_routine_plans_createdAt 
    ON public.routine_plans("createdAt" DESC);

CREATE INDEX IF NOT EXISTS idx_routine_plans_owner_createdAt 
    ON public.routine_plans(owner, "createdAt" DESC);

CREATE INDEX IF NOT EXISTS idx_routine_plans_name 
    ON public.routine_plans(name);

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

-- Users can view their own routine plans
CREATE POLICY "Users can view their own routine_plans"
    ON public.routine_plans
    FOR SELECT
    USING (auth.uid() = owner);

-- Users can insert their own routine plans
CREATE POLICY "Users can insert their own routine_plans"
    ON public.routine_plans
    FOR INSERT
    WITH CHECK (auth.uid() = owner);

-- Users can update their own routine plans
CREATE POLICY "Users can update their own routine_plans"
    ON public.routine_plans
    FOR UPDATE
    USING (auth.uid() = owner)
    WITH CHECK (auth.uid() = owner);

-- Users can delete their own routine plans
CREATE POLICY "Users can delete their own routine_plans"
    ON public.routine_plans
    FOR DELETE
    USING (auth.uid() = owner);

