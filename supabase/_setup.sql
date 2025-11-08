-- ============================================================================
-- TRACKR APP - COMPLETE DATABASE SETUP
-- ============================================================================
-- Run this script in your Supabase SQL Editor to set up the entire database
-- ============================================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create trigger function for auto-updating timestamps
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- ============================================================================
-- EXERCISES TABLE + RLS
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.exercises (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    owner UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    data JSONB NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_exercises_owner ON public.exercises(owner);
CREATE INDEX IF NOT EXISTS idx_exercises_created_at ON public.exercises(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_exercises_owner_created_at ON public.exercises(owner, created_at DESC);

CREATE TRIGGER update_exercises_updated_at 
    BEFORE UPDATE ON public.exercises
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

ALTER TABLE public.exercises ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own exercises" ON public.exercises FOR SELECT USING (auth.uid() = owner);
CREATE POLICY "Users can insert their own exercises" ON public.exercises FOR INSERT WITH CHECK (auth.uid() = owner);
CREATE POLICY "Users can update their own exercises" ON public.exercises FOR UPDATE USING (auth.uid() = owner) WITH CHECK (auth.uid() = owner);
CREATE POLICY "Users can delete their own exercises" ON public.exercises FOR DELETE USING (auth.uid() = owner);

-- ============================================================================
-- ROUTINE TEMPLATES TABLE + RLS
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.routine_templates (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    owner UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    data JSONB NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_routine_templates_owner ON public.routine_templates(owner);
CREATE INDEX IF NOT EXISTS idx_routine_templates_created_at ON public.routine_templates(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_routine_templates_owner_created_at ON public.routine_templates(owner, created_at DESC);

CREATE TRIGGER update_routine_templates_updated_at 
    BEFORE UPDATE ON public.routine_templates
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

ALTER TABLE public.routine_templates ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own routine_templates" ON public.routine_templates FOR SELECT USING (auth.uid() = owner);
CREATE POLICY "Users can insert their own routine_templates" ON public.routine_templates FOR INSERT WITH CHECK (auth.uid() = owner);
CREATE POLICY "Users can update their own routine_templates" ON public.routine_templates FOR UPDATE USING (auth.uid() = owner) WITH CHECK (auth.uid() = owner);
CREATE POLICY "Users can delete their own routine_templates" ON public.routine_templates FOR DELETE USING (auth.uid() = owner);

-- ============================================================================
-- ROUTINE PLANS TABLE + RLS
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.routine_plans (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    owner UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    data JSONB NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_routine_plans_owner ON public.routine_plans(owner);
CREATE INDEX IF NOT EXISTS idx_routine_plans_created_at ON public.routine_plans(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_routine_plans_owner_created_at ON public.routine_plans(owner, created_at DESC);

CREATE TRIGGER update_routine_plans_updated_at 
    BEFORE UPDATE ON public.routine_plans
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

ALTER TABLE public.routine_plans ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own routine_plans" ON public.routine_plans FOR SELECT USING (auth.uid() = owner);
CREATE POLICY "Users can insert their own routine_plans" ON public.routine_plans FOR INSERT WITH CHECK (auth.uid() = owner);
CREATE POLICY "Users can update their own routine_plans" ON public.routine_plans FOR UPDATE USING (auth.uid() = owner) WITH CHECK (auth.uid() = owner);
CREATE POLICY "Users can delete their own routine_plans" ON public.routine_plans FOR DELETE USING (auth.uid() = owner);

-- ============================================================================
-- ROUTINE LOGS TABLE + RLS
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.routine_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    owner UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    data JSONB NOT NULL,
    type TEXT DEFAULT 'RoutineLog',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_routine_logs_owner ON public.routine_logs(owner);
CREATE INDEX IF NOT EXISTS idx_routine_logs_created_at ON public.routine_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_routine_logs_owner_created_at ON public.routine_logs(owner, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_routine_logs_type_created_at ON public.routine_logs(type, created_at DESC);

CREATE TRIGGER update_routine_logs_updated_at 
    BEFORE UPDATE ON public.routine_logs
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

ALTER TABLE public.routine_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own routine_logs" ON public.routine_logs FOR SELECT USING (auth.uid() = owner);
CREATE POLICY "Users can insert their own routine_logs" ON public.routine_logs FOR INSERT WITH CHECK (auth.uid() = owner);
CREATE POLICY "Users can update their own routine_logs" ON public.routine_logs FOR UPDATE USING (auth.uid() = owner) WITH CHECK (auth.uid() = owner);
CREATE POLICY "Users can delete their own routine_logs" ON public.routine_logs FOR DELETE USING (auth.uid() = owner);

-- ============================================================================
-- SETUP COMPLETE
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE '✅ Database setup complete!';
    RAISE NOTICE 'Created 4 tables with Row Level Security';
    RAISE NOTICE 'Next: Configure lib/supabase_config.dart and run your app';
END $$;

