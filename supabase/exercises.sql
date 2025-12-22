-- ============================================================================
-- EXERCISES TABLE
-- ============================================================================
-- Stores user-created custom exercises
-- ============================================================================

-- Create table
CREATE TABLE IF NOT EXISTS public.exercises (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    owner UUID NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    type TEXT NOT NULL,
    notes TEXT DEFAULT '',
    "createdAt" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    "updatedAt" TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Add comment
COMMENT ON TABLE public.exercises IS 'User-created custom exercises';
COMMENT ON COLUMN public.exercises.name IS 'Exercise name';
COMMENT ON COLUMN public.exercises.type IS 'Exercise type: WR (Weights), BW (Bodyweight), DR (Duration)';
COMMENT ON COLUMN public.exercises.notes IS 'User notes about the exercise';

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_exercises_owner 
    ON public.exercises(owner);

CREATE INDEX IF NOT EXISTS idx_exercises_createdAt 
    ON public.exercises("createdAt" DESC);

CREATE INDEX IF NOT EXISTS idx_exercises_owner_createdAt 
    ON public.exercises(owner, "createdAt" DESC);

CREATE INDEX IF NOT EXISTS idx_exercises_name 
    ON public.exercises(name);

-- Create updatedAt trigger
CREATE TRIGGER update_exercises_updatedAt 
    BEFORE UPDATE ON public.exercises
    FOR EACH ROW 
    EXECUTE FUNCTION update_updatedAt_column();

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

