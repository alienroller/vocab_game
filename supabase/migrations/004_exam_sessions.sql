-- ═══════════════════════════════════════════════════════════════════════
-- VOCABGAME — TEACHER-LED LIVE EXAM SESSIONS
-- Run this in the Supabase SQL Editor AFTER 003_role_separation.sql.
-- Depends on: profiles, classes (from 001/002/003).
-- ═══════════════════════════════════════════════════════════════════════

-- 1. Exam session header
CREATE TABLE IF NOT EXISTS exam_sessions (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  teacher_id            TEXT NOT NULL,
  class_code            TEXT NOT NULL,
  title                 TEXT NOT NULL,
  book_ids              TEXT[] NOT NULL,
  unit_ids              TEXT[] NOT NULL,
  question_count        INTEGER NOT NULL CHECK (question_count BETWEEN 1 AND 100),
  per_question_seconds  INTEGER NOT NULL CHECK (per_question_seconds BETWEEN 5 AND 300),
  total_seconds         INTEGER NOT NULL CHECK (total_seconds BETWEEN 30 AND 7200),
  status                TEXT NOT NULL DEFAULT 'lobby'
                        CHECK (status IN ('lobby','in_progress','completed','cancelled','abandoned')),
  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  started_at            TIMESTAMPTZ,
  ended_at              TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_exam_sessions_class_code ON exam_sessions(class_code);
CREATE INDEX IF NOT EXISTS idx_exam_sessions_teacher_id ON exam_sessions(teacher_id);
CREATE INDEX IF NOT EXISTS idx_exam_sessions_status    ON exam_sessions(status);

-- 2. Immutable question set for a session (populated by create-exam Edge Function)
CREATE TABLE IF NOT EXISTS exam_questions (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id      UUID NOT NULL REFERENCES exam_sessions(id) ON DELETE CASCADE,
  order_index     INTEGER NOT NULL,
  word_id         TEXT NOT NULL,
  prompt          TEXT NOT NULL,         -- the English word shown to the student
  correct_answer  TEXT NOT NULL,         -- the Uzbek translation
  options         JSONB NOT NULL,        -- 4-element array: [correct + 3 distractors] pre-shuffled by server
  UNIQUE (session_id, order_index)
);

CREATE INDEX IF NOT EXISTS idx_exam_questions_session ON exam_questions(session_id);

-- 3. Per-student participation row
CREATE TABLE IF NOT EXISTS exam_participants (
  session_id          UUID NOT NULL REFERENCES exam_sessions(id) ON DELETE CASCADE,
  student_id          TEXT NOT NULL,
  status              TEXT NOT NULL DEFAULT 'invited'
                      CHECK (status IN ('invited','joined','in_progress','completed','absent','timed_out')),
  shuffle_seed        INTEGER NOT NULL,   -- deterministic per-student question order
  joined_at           TIMESTAMPTZ,
  finished_at         TIMESTAMPTZ,
  score               INTEGER,
  correct_count       INTEGER,
  total_count         INTEGER,
  backgrounded_count  INTEGER NOT NULL DEFAULT 0,
  current_question_served_at TIMESTAMPTZ, -- server-stamped for per-question deadline
  current_order_index INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (session_id, student_id)
);

CREATE INDEX IF NOT EXISTS idx_exam_participants_student ON exam_participants(student_id);
CREATE INDEX IF NOT EXISTS idx_exam_participants_status  ON exam_participants(status);

-- 4. One row per (student × question) answer — server writes after grading
CREATE TABLE IF NOT EXISTS exam_answers (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id      UUID NOT NULL REFERENCES exam_sessions(id) ON DELETE CASCADE,
  student_id      TEXT NOT NULL,
  question_id     UUID NOT NULL REFERENCES exam_questions(id) ON DELETE CASCADE,
  order_index     INTEGER NOT NULL,
  answer          TEXT NOT NULL,
  is_correct      BOOLEAN NOT NULL,
  seconds_taken   INTEGER NOT NULL,
  submitted_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (session_id, student_id, question_id)
);

CREATE INDEX IF NOT EXISTS idx_exam_answers_session_student
  ON exam_answers(session_id, student_id);

-- ═══════════════════════════════════════════════════════════════════════
-- ROW-LEVEL SECURITY
-- (Harmonises with the auth.uid() policies from WALKTHROUGH §1b/§1c.)
-- ═══════════════════════════════════════════════════════════════════════

ALTER TABLE exam_sessions      ENABLE ROW LEVEL SECURITY;
ALTER TABLE exam_questions     ENABLE ROW LEVEL SECURITY;
ALTER TABLE exam_participants  ENABLE ROW LEVEL SECURITY;
ALTER TABLE exam_answers       ENABLE ROW LEVEL SECURITY;

-- exam_sessions: teacher manages their own sessions; students read sessions for their class.
CREATE POLICY "exam_sessions_teacher_all"
  ON exam_sessions FOR ALL
  USING  (teacher_id = auth.uid()::text)
  WITH CHECK (teacher_id = auth.uid()::text);

CREATE POLICY "exam_sessions_class_read"
  ON exam_sessions FOR SELECT
  USING (
    class_code IN (
      SELECT class_code FROM profiles WHERE id::text = auth.uid()::text
    )
  );

-- exam_questions: readable by teacher of the session, and by joined participants once started.
CREATE POLICY "exam_questions_teacher_read"
  ON exam_questions FOR SELECT
  USING (
    session_id IN (
      SELECT id FROM exam_sessions WHERE teacher_id = auth.uid()::text
    )
  );

CREATE POLICY "exam_questions_participant_read"
  ON exam_questions FOR SELECT
  USING (
    session_id IN (
      SELECT session_id FROM exam_participants
      WHERE student_id = auth.uid()::text
        AND status IN ('joined','in_progress','completed')
    )
  );

-- Direct inserts into exam_questions are blocked — only the create-exam
-- Edge Function (security definer / service role) writes here.

-- exam_participants: student manages their own row; teacher of the session reads all.
CREATE POLICY "exam_participants_self_rw"
  ON exam_participants FOR ALL
  USING  (student_id = auth.uid()::text)
  WITH CHECK (student_id = auth.uid()::text);

CREATE POLICY "exam_participants_teacher_read"
  ON exam_participants FOR SELECT
  USING (
    session_id IN (
      SELECT id FROM exam_sessions WHERE teacher_id = auth.uid()::text
    )
  );

-- exam_answers: student inserts their own; teacher of the session reads all.
-- (Clients should call the submit-answer Edge Function — direct inserts are
-- allowed here only as a fallback; the function handles grading server-side.)
CREATE POLICY "exam_answers_self_write"
  ON exam_answers FOR INSERT
  WITH CHECK (student_id = auth.uid()::text);

CREATE POLICY "exam_answers_self_read"
  ON exam_answers FOR SELECT
  USING (student_id = auth.uid()::text);

CREATE POLICY "exam_answers_teacher_read"
  ON exam_answers FOR SELECT
  USING (
    session_id IN (
      SELECT id FROM exam_sessions WHERE teacher_id = auth.uid()::text
    )
  );

-- ═══════════════════════════════════════════════════════════════════════
-- LAZY AUTO-END: any SELECT that encounters an in_progress session whose
-- total_seconds has elapsed will flip it to 'completed'. This covers the
-- teacher-goes-offline case without needing pg_cron.
-- ═══════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.maybe_end_exam(session uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE exam_sessions
     SET status   = 'completed',
         ended_at = NOW()
   WHERE id = session
     AND status = 'in_progress'
     AND started_at IS NOT NULL
     AND NOW() > started_at + (total_seconds * INTERVAL '1 second');
END;
$$;

REVOKE ALL ON FUNCTION public.maybe_end_exam(uuid) FROM public;
GRANT EXECUTE ON FUNCTION public.maybe_end_exam(uuid) TO authenticated;
