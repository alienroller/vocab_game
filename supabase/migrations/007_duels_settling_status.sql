-- ═══════════════════════════════════════════════════════════════════════
-- VOCABGAME — DUEL SETTLING STATE
--
-- The app's DuelService.finishDuel() implements a 3-step CAS pattern:
--   active → settling → finished
-- The intermediate 'settling' state is held only while XP is being awarded
-- to both players. If the second XP RPC fails, the row is reverted to
-- 'active' so the client can retry — this prevents double-award bugs.
--
-- The original schema (supabase_schema.sql) was written before this pattern
-- existed and only permits ('pending','active','finished','declined'). The
-- mismatch causes every finishDuel() call to fail with a CHECK-constraint
-- violation, so the duel never transitions to 'finished' and both players'
-- screens hang after the last question.
--
-- This migration:
--   1. Adds 'settling' to the allowed status values.
--   2. Adds a settling_at timestamp column for observability / debugging
--      stale settling rows that got stuck between steps 1 and 3.
--
-- Run in Supabase SQL Editor.
-- ═══════════════════════════════════════════════════════════════════════

-- ── 1. Replace status CHECK constraint ───────────────────────────────
ALTER TABLE duels DROP CONSTRAINT IF EXISTS duels_status_check;
ALTER TABLE duels ADD CONSTRAINT duels_status_check
  CHECK (status IN ('pending','active','settling','finished','declined'));

-- ── 2. Add settling_at column (idempotent) ───────────────────────────
ALTER TABLE duels ADD COLUMN IF NOT EXISTS settling_at timestamptz;
