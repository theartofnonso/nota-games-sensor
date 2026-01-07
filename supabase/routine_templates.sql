-- ============================================================================
-- ROUTINE TEMPLATES TABLE
-- ============================================================================
-- Stores reusable workout templates
-- ============================================================================

-- Create table
CREATE TABLE IF NOT EXISTS public.routine_templates (
    id UUID NOT NULL DEFAULT extensions.uuid_generate_v4(),
    owner UUID NOT NULL DEFAULT auth.uid(),
    "planId" UUID NOT NULL REFERENCES public.routine_plans(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    notes TEXT NULL DEFAULT ''::text,
    "clientId" UUID NULL,
    exercises JSONB NOT NULL,
    "createdAt" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    "updatedAt" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT routine_templates_pkey PRIMARY KEY (id),
    CONSTRAINT routine_templates_clientid_fkey FOREIGN KEY ("clientId") REFERENCES clients(id) ON DELETE SET NULL,
    CONSTRAINT routine_templates_owner_fkey FOREIGN KEY (owner) REFERENCES auth.users(id) ON DELETE CASCADE
) TABLESPACE pg_default;

-- Add comment
COMMENT ON TABLE public.routine_templates IS 'Reusable workout templates';
COMMENT ON COLUMN public.routine_templates.name IS 'Template name';
COMMENT ON COLUMN public.routine_templates."planId" IS 'ID of the parent plan';
COMMENT ON COLUMN public.routine_templates.exercises IS 'JSON array of exercise templates with sets';
COMMENT ON COLUMN public.routine_templates."clientId" IS 'Client ID (UUID) for system templates (null for user-created templates). References clients table.';

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_routine_templates_owner 
    ON public.routine_templates USING btree (owner) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_routine_templates_createdAt 
    ON public.routine_templates USING btree ("createdAt" DESC) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_routine_templates_owner_createdAt 
    ON public.routine_templates USING btree (owner, "createdAt" DESC) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_routine_templates_planId 
    ON public.routine_templates USING btree ("planId") TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_routine_templates_name 
    ON public.routine_templates USING btree (name) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS routine_templates_clientid_idx 
    ON public.routine_templates USING btree ("clientId") TABLESPACE pg_default;

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

-- Users can view their own routine templates (where owner or clientId equals their user ID) and system templates (where clientId is not null and not equal to their user ID)
CREATE POLICY "Users can view their own routine_templates"
    ON public.routine_templates
    FOR SELECT
    USING (auth.uid() = owner OR auth.uid() = "clientId" OR ("clientId" IS NOT NULL AND "clientId" != auth.uid()));

-- Users can insert their own routine templates
CREATE POLICY "Users can insert their own routine_templates"
    ON public.routine_templates
    FOR INSERT
    WITH CHECK (auth.uid() = owner);

-- Users can update their own routine templates (but not system templates)
CREATE POLICY "Users can update their own routine_templates"
    ON public.routine_templates
    FOR UPDATE
    USING (auth.uid() = owner AND "clientId" IS NULL)
    WITH CHECK (auth.uid() = owner AND "clientId" IS NULL);

-- Users can delete their own routine templates (but not system templates)
CREATE POLICY "Users can delete their own routine_templates"
    ON public.routine_templates
    FOR DELETE
    USING (auth.uid() = owner AND "clientId" IS NULL);

