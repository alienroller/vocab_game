-- ============================================================================
-- Per-user-per-unit best XP tracking
-- Used to bank only the *delta* over a user's previous best when they
-- replay a library/assignment unit, so leaderboards can't be farmed.
-- ============================================================================

CREATE TABLE IF NOT EXISTS unit_best_xp (
  profile_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  unit_id    uuid NOT NULL REFERENCES units(id)    ON DELETE CASCADE,
  best_xp    integer NOT NULL DEFAULT 0 CHECK (best_xp >= 0),
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (profile_id, unit_id)
);

CREATE INDEX IF NOT EXISTS unit_best_xp_profile_idx
  ON unit_best_xp (profile_id);

ALTER TABLE unit_best_xp ENABLE ROW LEVEL SECURITY;

-- Open policies (the app uses client-generated UUIDs without Supabase Auth,
-- matching the existing convention in profiles/word_mastery).
DROP POLICY IF EXISTS "unit_best_xp read"   ON unit_best_xp;
DROP POLICY IF EXISTS "unit_best_xp write"  ON unit_best_xp;
DROP POLICY IF EXISTS "unit_best_xp update" ON unit_best_xp;

CREATE POLICY "unit_best_xp read"   ON unit_best_xp FOR SELECT USING (true);
CREATE POLICY "unit_best_xp write"  ON unit_best_xp FOR INSERT WITH CHECK (true);
CREATE POLICY "unit_best_xp update" ON unit_best_xp FOR UPDATE USING (true) WITH CHECK (true);
