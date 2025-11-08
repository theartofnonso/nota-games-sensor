-- ============================================================================
-- EXERCISES TABLE
-- ============================================================================
-- Stores user-created custom exercises
-- ============================================================================

-- Create table
CREATE TABLE IF NOT EXISTS public.exercises (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    owner UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    data JSONB NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Add comment
COMMENT ON TABLE public.exercises IS 'User-created custom exercises';
COMMENT ON COLUMN public.exercises.data IS 'JSON containing exercise details (name, type, muscle groups, video, etc.)';

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_exercises_owner 
    ON public.exercises(owner);

CREATE INDEX IF NOT EXISTS idx_exercises_created_at 
    ON public.exercises(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_exercises_owner_created_at 
    ON public.exercises(owner, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_exercises_data_name 
    ON public.exercises USING gin ((data -> 'name'));

-- Create updated_at trigger
CREATE TRIGGER update_exercises_updated_at 
    BEFORE UPDATE ON public.exercises
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- ROW LEVEL SECURITY
-- ============================================================================

-- Enable RLS
ALTER TABLE public.exercises ENABLE ROW LEVEL SECURITY;

-- Users can view their own exercises
CREATE POLICY "Users can view their own exercises"
    ON public.exercises
    FOR SELECT
    USING (auth.uid() = owner);

-- Users can insert their own exercises
CREATE POLICY "Users can insert their own exercises"
    ON public.exercises
    FOR INSERT
    WITH CHECK (auth.uid() = owner);

-- Users can update their own exercises
CREATE POLICY "Users can update their own exercises"
    ON public.exercises
    FOR UPDATE
    USING (auth.uid() = owner)
    WITH CHECK (auth.uid() = owner);

-- Users can delete their own exercises
CREATE POLICY "Users can delete their own exercises"
    ON public.exercises
    FOR DELETE
    USING (auth.uid() = owner);

