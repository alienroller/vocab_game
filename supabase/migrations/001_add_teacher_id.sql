-- ═══════════════════════════════════════════════════════════════════════
-- VOCABGAME — ADD teacher_id TO classes TABLE
-- Run this in the Supabase SQL Editor BEFORE deploying the app update.
-- ═══════════════════════════════════════════════════════════════════════

-- Add teacher_id column
ALTER TABLE classes ADD COLUMN IF NOT EXISTS teacher_id TEXT NOT NULL DEFAULT '';

-- Backfill: set teacher_id from profiles where username matches teacher_username
UPDATE classes c
SET teacher_id = p.id
FROM profiles p
WHERE p.username = c.teacher_username;
