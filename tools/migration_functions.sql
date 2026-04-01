-- =============================================================================
-- VocabGame — Required SQL Functions & Jobs
-- Run ALL of these in Supabase → SQL Editor → New Query
-- =============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. increment_xp — Atomically awards XP to a profile (used by duel system)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION increment_xp(profile_id uuid, amount integer)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  UPDATE profiles
  SET
    xp = xp + amount,
    week_xp = week_xp + amount,
    level = GREATEST(1, FLOOR(SQRT((xp + amount) / 50.0))::integer + 1),
    updated_at = now()
  WHERE id = profile_id;
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. pg_cron extension (enable once)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. award_weekly_hall_of_fame — Snapshots top 3 into hall_of_fame, then resets
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION award_weekly_hall_of_fame()
RETURNS void LANGUAGE plpgsql AS $$
DECLARE
  period_label text;
  rec record;
  rank_num integer := 1;
BEGIN
  -- Generate label like "March 2026 — Week 13"
  period_label := to_char(now(), 'Month YYYY') || ' — Week ' || to_char(now(), 'IW');

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

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. Schedule weekly reset — every Monday at 00:01 UTC
-- ─────────────────────────────────────────────────────────────────────────────
SELECT cron.schedule(
  'weekly-reset',
  '1 0 * * 1',
  'SELECT award_weekly_hall_of_fame();'
);

-- ─────────────────────────────────────────────────────────────────────────────
-- 5. Verify the cron job is scheduled
-- ─────────────────────────────────────────────────────────────────────────────
-- Run this query to confirm:
-- SELECT * FROM cron.job;
