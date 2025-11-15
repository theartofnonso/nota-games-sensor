-- ============================================================================
-- ROUTINE LOGS TABLE
-- ============================================================================
-- Stores completed workout sessions
-- ============================================================================

-- Create table
CREATE TABLE IF NOT EXISTS public.routine_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    owner UUID NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
    "templateId" TEXT DEFAULT '',
    name TEXT NOT NULL,
    notes TEXT DEFAULT '',
    "startTime" TIMESTAMPTZ NOT NULL,
    "endTime" TIMESTAMPTZ NOT NULL,
    exercises JSONB NOT NULL,
    "createdAt" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    "updatedAt" TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Add comment
COMMENT ON TABLE public.routine_logs IS 'Completed workout session logs';
COMMENT ON COLUMN public.routine_logs."templateId" IS 'ID of the template this log is based on (if any)';
COMMENT ON COLUMN public.routine_logs.name IS 'Workout session name';
COMMENT ON COLUMN public.routine_logs."startTime" IS 'When the workout started';
COMMENT ON COLUMN public.routine_logs."endTime" IS 'When the workout ended';
COMMENT ON COLUMN public.routine_logs.exercises IS 'JSON array of exercise logs with sets and reps';

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_routine_logs_owner 
    ON public.routine_logs(owner);

CREATE INDEX IF NOT EXISTS idx_routine_logs_createdAt 
    ON public.routine_logs("createdAt" DESC);

CREATE INDEX IF NOT EXISTS idx_routine_logs_owner_createdAt 
    ON public.routine_logs(owner, "createdAt" DESC);

CREATE INDEX IF NOT EXISTS idx_routine_logs_startTime 
    ON public.routine_logs("startTime" DESC);

CREATE INDEX IF NOT EXISTS idx_routine_logs_templateId 
    ON public.routine_logs("templateId");

-- Create updatedAt trigger
CREATE TRIGGER update_routine_logs_updatedAt 
    BEFORE UPDATE ON public.routine_logs
    FOR EACH ROW 
    EXECUTE FUNCTION update_updatedAt_column();

-- ============================================================================
-- ROW LEVEL SECURITY
-- ============================================================================

-- Enable RLS
ALTER TABLE public.routine_logs ENABLE ROW LEVEL SECURITY;

-- Users can view their own routine logs
CREATE POLICY "Users can view their own routine_logs"
    ON public.routine_logs
    FOR SELECT
    USING (auth.uid() = owner);

-- Users can insert their own routine logs
CREATE POLICY "Users can insert their own routine_logs"
    ON public.routine_logs
    FOR INSERT
    WITH CHECK (auth.uid() = owner);

-- Users can update their own routine logs
CREATE POLICY "Users can update their own routine_logs"
    ON public.routine_logs
    FOR UPDATE
    USING (auth.uid() = owner)
    WITH CHECK (auth.uid() = owner);

-- Users can delete their own routine logs
CREATE POLICY "Users can delete their own routine_logs"
    ON public.routine_logs
    FOR DELETE
    USING (auth.uid() = owner);

