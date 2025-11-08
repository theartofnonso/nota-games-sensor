-- ============================================================================
-- ROUTINE TEMPLATES TABLE
-- ============================================================================
-- Stores reusable workout templates
-- ============================================================================

-- Create table
CREATE TABLE IF NOT EXISTS public.routine_templates (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    owner UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    data JSONB NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Add comment
COMMENT ON TABLE public.routine_templates IS 'Reusable workout templates';
COMMENT ON COLUMN public.routine_templates.data IS 'JSON containing template details (name, exercises, sets, notes, etc.)';

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_routine_templates_owner 
    ON public.routine_templates(owner);

CREATE INDEX IF NOT EXISTS idx_routine_templates_created_at 
    ON public.routine_templates(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_routine_templates_owner_created_at 
    ON public.routine_templates(owner, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_routine_templates_data_name 
    ON public.routine_templates USING gin ((data -> 'name'));

-- Create updated_at trigger
CREATE TRIGGER update_routine_templates_updated_at 
    BEFORE UPDATE ON public.routine_templates
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

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

