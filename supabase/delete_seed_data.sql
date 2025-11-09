-- ============================================================================
-- TRACKR APP - DELETE SEED DATA
-- ============================================================================
-- Run this in Supabase SQL Editor to remove all seed data
-- This will delete data for owner: 72e0df29-9310-4075-b9be-e76028f9d6eb
-- ============================================================================

-- Delete routine logs (will cascade delete related data)
DELETE FROM public.routine_logs WHERE owner = '72e0df29-9310-4075-b9be-e76028f9d6eb';

-- Delete routine templates
DELETE FROM public.routine_templates WHERE owner = '72e0df29-9310-4075-b9be-e76028f9d6eb';

-- Delete routine plans
DELETE FROM public.routine_plans WHERE owner = '72e0df29-9310-4075-b9be-e76028f9d6eb';

-- Delete exercises
DELETE FROM public.exercises WHERE owner = '72e0df29-9310-4075-b9be-e76028f9d6eb';

-- ============================================================================
-- CLEANUP COMPLETE
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE '✅ All seed data deleted for current user!';
    RAISE NOTICE '🧹 Database is now clean and ready for your own data';
END $$;

