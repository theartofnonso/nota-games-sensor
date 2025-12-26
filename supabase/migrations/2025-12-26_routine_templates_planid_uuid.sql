-- Migration: enforce UUID planId on routine_templates
BEGIN;

-- Drop any existing foreign key to avoid conflicts
ALTER TABLE public.routine_templates
  DROP CONSTRAINT IF EXISTS routine_templates_planId_fkey;

-- Drop existing index so we can recreate on the new type
DROP INDEX IF EXISTS idx_routine_templates_planId;

-- Drop any default to allow type change
ALTER TABLE public.routine_templates
  ALTER COLUMN "planId" DROP DEFAULT;

-- Cast planId to UUID and enforce NOT NULL
ALTER TABLE public.routine_templates
  ALTER COLUMN "planId" TYPE UUID USING "planId"::UUID,
  ALTER COLUMN "planId" SET NOT NULL;

-- Add FK to routine_plans
ALTER TABLE public.routine_templates
  ADD CONSTRAINT routine_templates_planId_fkey
  FOREIGN KEY ("planId") REFERENCES public.routine_plans(id) ON DELETE CASCADE;

-- Recreate index on planId
CREATE INDEX IF NOT EXISTS idx_routine_templates_planId
  ON public.routine_templates("planId");

COMMIT;

