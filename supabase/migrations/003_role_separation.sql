-- ═══════════════════════════════════════════════════════════════════════
-- VOCABGAME — ROLE SEPARATION DATABASE TABLES
-- Run this in the Supabase SQL Editor AFTER 002_enable_rls.sql.
-- ═══════════════════════════════════════════════════════════════════════

-- 1. Assignments table
CREATE TABLE IF NOT EXISTS assignments (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  class_code    TEXT NOT NULL,
  teacher_id    TEXT NOT NULL,
  book_id       TEXT NOT NULL,
  book_title    TEXT NOT NULL,
  unit_id       TEXT NOT NULL,
  unit_title    TEXT NOT NULL,
  due_date      TEXT,               -- 'YYYY-MM-DD' ISO string, NULL means no deadline
  word_count    INTEGER NOT NULL,   -- total words in the unit at time of assignment
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  is_active     BOOLEAN DEFAULT true
);

CREATE INDEX IF NOT EXISTS idx_assignments_class_code ON assignments(class_code);
CREATE INDEX IF NOT EXISTS idx_assignments_teacher_id ON assignments(teacher_id);

-- 2. Assignment progress table
CREATE TABLE IF NOT EXISTS assignment_progress (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  assignment_id     UUID NOT NULL REFERENCES assignments(id) ON DELETE CASCADE,
  student_id        TEXT NOT NULL,
  class_code        TEXT NOT NULL,
  words_mastered    INTEGER DEFAULT 0,
  total_words       INTEGER NOT NULL,
  is_completed      BOOLEAN DEFAULT false,
  last_practiced_at TIMESTAMPTZ,
  created_at        TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(assignment_id, student_id)
);

CREATE INDEX IF NOT EXISTS idx_asgn_progress_assignment ON assignment_progress(assignment_id);
CREATE INDEX IF NOT EXISTS idx_asgn_progress_student ON assignment_progress(student_id);
CREATE INDEX IF NOT EXISTS idx_asgn_progress_class ON assignment_progress(class_code);

-- 3. Word stats table
CREATE TABLE IF NOT EXISTS word_stats (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id    TEXT NOT NULL,
  class_code    TEXT NOT NULL,
  word_english  TEXT NOT NULL,
  word_uzbek    TEXT NOT NULL,
  times_shown   INTEGER DEFAULT 0,
  times_correct INTEGER DEFAULT 0,
  updated_at    TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(student_id, word_english)
);

CREATE INDEX IF NOT EXISTS idx_word_stats_class ON word_stats(class_code);
CREATE INDEX IF NOT EXISTS idx_word_stats_student ON word_stats(student_id);

-- 4. Teacher messages table
CREATE TABLE IF NOT EXISTS teacher_messages (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  class_code  TEXT NOT NULL UNIQUE,  -- one active message per class
  teacher_id  TEXT NOT NULL,
  message     TEXT NOT NULL,         -- max 200 characters, enforced in Dart
  updated_at  TIMESTAMPTZ DEFAULT NOW()
);

-- ═══════════════════════════════════════════════════════════════════════
-- RLS POLICIES (open policies — no Supabase Auth used by this app)
-- ═══════════════════════════════════════════════════════════════════════

ALTER TABLE assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE assignment_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE word_stats ENABLE ROW LEVEL SECURITY;
ALTER TABLE teacher_messages ENABLE ROW LEVEL SECURITY;

-- assignments: anyone can read, insert, update (app-level validation)
DROP POLICY IF EXISTS "assignments_select" ON assignments;
CREATE POLICY "assignments_select" ON assignments FOR SELECT USING (true);

DROP POLICY IF EXISTS "assignments_insert" ON assignments;
CREATE POLICY "assignments_insert" ON assignments FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "assignments_update" ON assignments;
CREATE POLICY "assignments_update" ON assignments FOR UPDATE USING (true) WITH CHECK (true);

-- assignment_progress: anyone can read, insert, update
DROP POLICY IF EXISTS "progress_select" ON assignment_progress;
CREATE POLICY "progress_select" ON assignment_progress FOR SELECT USING (true);

DROP POLICY IF EXISTS "progress_insert" ON assignment_progress;
CREATE POLICY "progress_insert" ON assignment_progress FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "progress_update" ON assignment_progress;
CREATE POLICY "progress_update" ON assignment_progress FOR UPDATE USING (true) WITH CHECK (true);

-- word_stats: anyone can read, insert, update
DROP POLICY IF EXISTS "word_stats_select" ON word_stats;
CREATE POLICY "word_stats_select" ON word_stats FOR SELECT USING (true);

DROP POLICY IF EXISTS "word_stats_insert" ON word_stats;
CREATE POLICY "word_stats_insert" ON word_stats FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "word_stats_update" ON word_stats;
CREATE POLICY "word_stats_update" ON word_stats FOR UPDATE USING (true) WITH CHECK (true);

-- teacher_messages: anyone can read, insert, update, delete
DROP POLICY IF EXISTS "msg_select" ON teacher_messages;
CREATE POLICY "msg_select" ON teacher_messages FOR SELECT USING (true);

DROP POLICY IF EXISTS "msg_insert" ON teacher_messages;
CREATE POLICY "msg_insert" ON teacher_messages FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "msg_update" ON teacher_messages;
CREATE POLICY "msg_update" ON teacher_messages FOR UPDATE USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "msg_delete" ON teacher_messages;
CREATE POLICY "msg_delete" ON teacher_messages FOR DELETE USING (true);
