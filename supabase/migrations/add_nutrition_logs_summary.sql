-- Add summary column to nutrition_logs for AI-generated meal summaries
alter table public.nutrition_logs
  add column if not exists summary text null;
