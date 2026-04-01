-- ═══════════════════════════════════════════════════════════════════════
-- VocabGame — Weekly Tournament Reset (pg_cron)
-- 
-- Run this in Supabase → SQL Editor → New Query.
-- This sets up the automatic weekly reset that:
--   1. Awards the top 3 players to the Hall of Fame
--   2. Resets week_xp for all players
--   3. Runs every Monday at 00:01 UTC via pg_cron
-- ═══════════════════════════════════════════════════════════════════════

-- Step 1: Enable pg_cron extension (if not already done in dashboard)
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Step 2: Create the reset function
CREATE OR REPLACE FUNCTION award_weekly_hall_of_fame()
RETURNS void LANGUAGE plpgsql AS $$
DECLARE
  period_label text;
  rec record;
  rank_num integer := 1;
BEGIN
  -- Generate label like "March 2026 — Week 13"
  period_label := trim(to_char(now(), 'Month YYYY')) || ' — Week ' || to_char(now(), 'IW');

  -- Get top 3 by week_xp (only if they have at least 1 XP this week)
  FOR rec IN
    SELECT id, username, week_xp
    FROM profiles
    WHERE week_xp > 0
    ORDER BY week_xp DESC
    LIMIT 3
  LOOP
    INSERT INTO hall_of_fame (profile_id, username, rank, week_xp, period_label)
    VALUES (rec.id, rec.username, rank_num, rec.week_xp, period_label);
    rank_num := rank_num + 1;
  END LOOP;

  -- Now reset week_xp for everyone
  UPDATE profiles SET week_xp = 0;
END;
$$;

-- Step 3: Schedule it every Monday at 00:01 UTC
SELECT cron.schedule(
  'weekly-reset',           -- job name (must be unique)
  '1 0 * * 1',             -- cron expression: 00:01 every Monday
  'SELECT award_weekly_hall_of_fame();'
);

-- ═══════════════════════════════════════════════════════════════════════
-- Verification commands (run separately to check)
-- ═══════════════════════════════════════════════════════════════════════

-- View scheduled jobs:
-- SELECT * FROM cron.job;

-- Test it manually (without waiting for Monday):
-- SELECT award_weekly_hall_of_fame();

-- View Hall of Fame entries:
-- SELECT * FROM hall_of_fame ORDER BY awarded_at DESC;
