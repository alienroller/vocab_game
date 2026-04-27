-- ═══════════════════════════════════════════════════════════════════════
-- VOCABGAME — LONGEST STREAK COLUMN
--
-- Adds `longest_streak` to `profiles` so the user's all-time best streak
-- survives a missed day. Backfills it from the current `streak_days` value
-- (best info available at migration time — anyone whose streak is currently
-- alive gets credit for that count as their personal best).
--
-- Pairs with the client-side streak refactor that derives the live streak
-- state from `last_played_date` instead of trusting the stored count.
-- ═══════════════════════════════════════════════════════════════════════

ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS longest_streak integer NOT NULL DEFAULT 0;

-- Backfill: if a user has a streak today, that's the best record we know of.
UPDATE profiles
SET longest_streak = streak_days
WHERE longest_streak < streak_days;
