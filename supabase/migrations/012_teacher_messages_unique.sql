-- ═══════════════════════════════════════════════════════════════════════
-- VOCABGAME — ENSURE teacher_messages.class_code UNIQUE
-- Run this in the Supabase SQL Editor.
--
-- Some databases were created before the `class_code UNIQUE` constraint
-- was added to migration 003. `CREATE TABLE IF NOT EXISTS` does not add
-- the constraint to a pre-existing table, so the upsert / pin-message
-- flow could fail with "no unique constraint matching ON CONFLICT".
--
-- This migration:
--   1. De-duplicates any existing rows (keeps the most recently updated
--      row per class_code).
--   2. Adds the UNIQUE constraint if it is missing.
-- ═══════════════════════════════════════════════════════════════════════

-- 1. De-duplicate (keep newest per class_code)
DELETE FROM teacher_messages tm
WHERE tm.id NOT IN (
  SELECT DISTINCT ON (class_code) id
  FROM teacher_messages
  ORDER BY class_code, updated_at DESC NULLS LAST, id
);

-- 2. Add UNIQUE constraint if missing
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'teacher_messages'::regclass
      AND contype  = 'u'
      AND conname  = 'teacher_messages_class_code_key'
  ) THEN
    ALTER TABLE teacher_messages
      ADD CONSTRAINT teacher_messages_class_code_key UNIQUE (class_code);
  END IF;
END $$;
