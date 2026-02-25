-- Health metrics table for Apple Health / Health Connect sync.
-- Stores sleep (minutes) and steps per user per date.
CREATE TABLE IF NOT EXISTS health_metrics (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  date date NOT NULL,
  sleep_minutes int,
  steps int,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(user_id, date)
);

-- RLS
ALTER TABLE health_metrics ENABLE ROW LEVEL SECURITY;

-- Users can read/write their own data
CREATE POLICY "Users can manage own health metrics"
  ON health_metrics
  FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Coaches can read their clients' data (via coach_clients relationship)
-- Requires coach_clients table to exist. Adjust if your schema differs.
CREATE POLICY "Coaches can read client health metrics"
  ON health_metrics
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM coach_clients cc
      WHERE cc.client_id = health_metrics.user_id
        AND cc.coach_id = auth.uid()
    )
  );
