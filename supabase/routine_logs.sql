-- ============================================================================
-- ROUTINE LOGS TABLE
-- ============================================================================
-- Stores completed workout sessions
-- ============================================================================

-- Create table
CREATE TABLE IF NOT EXISTS public.routine_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    owner UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    data JSONB NOT NULL,
    type TEXT DEFAULT 'RoutineLog',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Add comment
COMMENT ON TABLE public.routine_logs IS 'Completed workout session logs';
COMMENT ON COLUMN public.routine_logs.data IS 'JSON containing log details (exercises, sets, reps, weights, duration, etc.)';
COMMENT ON COLUMN public.routine_logs.type IS 'Type discriminator for querying (always RoutineLog)';

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_routine_logs_owner 
    ON public.routine_logs(owner);

CREATE INDEX IF NOT EXISTS idx_routine_logs_created_at 
    ON public.routine_logs(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_routine_logs_owner_created_at 
    ON public.routine_logs(owner, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_routine_logs_type_created_at 
    ON public.routine_logs(type, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_routine_logs_data_template_id 
    ON public.routine_logs USING gin ((data -> 'templateId'));

-- Create updated_at trigger
CREATE TRIGGER update_routine_logs_updated_at 
    BEFORE UPDATE ON public.routine_logs
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

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

