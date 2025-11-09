-- ============================================================================
-- ROUTINE TEMPLATES TABLE
-- ============================================================================
-- Stores reusable workout templates
-- ============================================================================

-- Create table
CREATE TABLE IF NOT EXISTS public.routine_templates (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    owner UUID NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
    "planId" TEXT NOT NULL,
    name TEXT NOT NULL,
    notes TEXT DEFAULT '',
    exercises JSONB NOT NULL,
    "createdAt" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    "updatedAt" TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Add comment
COMMENT ON TABLE public.routine_templates IS 'Reusable workout templates';
COMMENT ON COLUMN public.routine_templates.name IS 'Template name';
COMMENT ON COLUMN public.routine_templates."planId" IS 'ID of the parent plan';
COMMENT ON COLUMN public.routine_templates.exercises IS 'JSON array of exercise templates with sets';

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_routine_templates_owner 
    ON public.routine_templates(owner);

CREATE INDEX IF NOT EXISTS idx_routine_templates_createdAt 
    ON public.routine_templates("createdAt" DESC);

CREATE INDEX IF NOT EXISTS idx_routine_templates_owner_createdAt 
    ON public.routine_templates(owner, "createdAt" DESC);

CREATE INDEX IF NOT EXISTS idx_routine_templates_planId 
    ON public.routine_templates("planId");

CREATE INDEX IF NOT EXISTS idx_routine_templates_name 
    ON public.routine_templates(name);

-- Create updatedAt trigger
CREATE TRIGGER update_routine_templates_updatedAt 
    BEFORE UPDATE ON public.routine_templates
    FOR EACH ROW 
    EXECUTE FUNCTION update_updatedAt_column();

-- ============================================================================
-- ROW LEVEL SECURITY
-- ============================================================================

-- Enable RLS
ALTER TABLE public.routine_templates ENABLE ROW LEVEL SECURITY;

-- Users can view their own routine templates
CREATE POLICY "Users can view their own routine_templates"
    ON public.routine_templates
    FOR SELECT
    USING (auth.uid() = owner);

-- Users can insert their own routine templates
CREATE POLICY "Users can insert their own routine_templates"
    ON public.routine_templates
    FOR INSERT
    WITH CHECK (auth.uid() = owner);

-- Users can update their own routine templates
CREATE POLICY "Users can update their own routine_templates"
    ON public.routine_templates
    FOR UPDATE
    USING (auth.uid() = owner)
    WITH CHECK (auth.uid() = owner);

-- Users can delete their own routine templates
CREATE POLICY "Users can delete their own routine_templates"
    ON public.routine_templates
    FOR DELETE
    USING (auth.uid() = owner);

