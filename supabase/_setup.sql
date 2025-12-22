-- ============================================================================
-- TRACKR APP - COMPLETE DATABASE SETUP
-- ============================================================================
-- Run this script in your Supabase SQL Editor to set up the entire database
-- ============================================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create trigger function for auto-updating timestamps
CREATE OR REPLACE FUNCTION update_updatedAt_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW."updatedAt" = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- ============================================================================
-- EXERCISES TABLE + RLS
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.exercises (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    owner UUID NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    type TEXT NOT NULL,
    notes TEXT DEFAULT '',
    "isSystem" BOOLEAN NOT NULL DEFAULT FALSE,
    "createdAt" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    "updatedAt" TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_exercises_owner ON public.exercises(owner);
CREATE INDEX IF NOT EXISTS idx_exercises_createdAt ON public.exercises("createdAt" DESC);
CREATE INDEX IF NOT EXISTS idx_exercises_owner_createdAt ON public.exercises(owner, "createdAt" DESC);
CREATE INDEX IF NOT EXISTS idx_exercises_name ON public.exercises(name);

CREATE TRIGGER update_exercises_updatedAt 
    BEFORE UPDATE ON public.exercises
    FOR EACH ROW EXECUTE FUNCTION update_updatedAt_column();

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
    owner UUID NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
    "planId" TEXT NOT NULL,
    name TEXT NOT NULL,
    notes TEXT DEFAULT '',
    exercises JSONB NOT NULL,
    "createdAt" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    "updatedAt" TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_routine_templates_owner ON public.routine_templates(owner);
CREATE INDEX IF NOT EXISTS idx_routine_templates_createdAt ON public.routine_templates("createdAt" DESC);
CREATE INDEX IF NOT EXISTS idx_routine_templates_owner_createdAt ON public.routine_templates(owner, "createdAt" DESC);
CREATE INDEX IF NOT EXISTS idx_routine_templates_planId ON public.routine_templates("planId");
CREATE INDEX IF NOT EXISTS idx_routine_templates_name ON public.routine_templates(name);

CREATE TRIGGER update_routine_templates_updatedAt 
    BEFORE UPDATE ON public.routine_templates
    FOR EACH ROW EXECUTE FUNCTION update_updatedAt_column();

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
    owner UUID NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    notes TEXT DEFAULT '',
    "createdAt" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    "updatedAt" TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_routine_plans_owner ON public.routine_plans(owner);
CREATE INDEX IF NOT EXISTS idx_routine_plans_createdAt ON public.routine_plans("createdAt" DESC);
CREATE INDEX IF NOT EXISTS idx_routine_plans_owner_createdAt ON public.routine_plans(owner, "createdAt" DESC);
CREATE INDEX IF NOT EXISTS idx_routine_plans_name ON public.routine_plans(name);

CREATE TRIGGER update_routine_plans_updatedAt 
    BEFORE UPDATE ON public.routine_plans
    FOR EACH ROW EXECUTE FUNCTION update_updatedAt_column();

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

CREATE INDEX IF NOT EXISTS idx_routine_logs_owner ON public.routine_logs(owner);
CREATE INDEX IF NOT EXISTS idx_routine_logs_createdAt ON public.routine_logs("createdAt" DESC);
CREATE INDEX IF NOT EXISTS idx_routine_logs_owner_createdAt ON public.routine_logs(owner, "createdAt" DESC);
CREATE INDEX IF NOT EXISTS idx_routine_logs_startTime ON public.routine_logs("startTime" DESC);
CREATE INDEX IF NOT EXISTS idx_routine_logs_templateId ON public.routine_logs("templateId");

CREATE TRIGGER update_routine_logs_updatedAt 
    BEFORE UPDATE ON public.routine_logs
    FOR EACH ROW EXECUTE FUNCTION update_updatedAt_column();

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

