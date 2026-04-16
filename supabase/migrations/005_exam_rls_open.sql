-- ═══════════════════════════════════════════════════════════════════════
-- 005_exam_rls_open.sql
--
-- Replaces the auth.uid()-based RLS policies from 004 with open policies
-- that match the rest of the app (profiles, classes, assignments all use
-- USING (true)).  The app does NOT use Supabase Auth — user identity is
-- a client-generated UUID stored in Hive.  Server-side authorization
-- happens inside the Edge Functions (create-exam, join-exam, start-exam,
-- submit-answer) which use the service_role key.
-- ═══════════════════════════════════════════════════════════════════════

-- ── Drop the auth.uid() policies ────────────────────────────────────

DROP POLICY IF EXISTS "exam_sessions_teacher_all"       ON exam_sessions;
DROP POLICY IF EXISTS "exam_sessions_class_read"        ON exam_sessions;
DROP POLICY IF EXISTS "exam_questions_teacher_read"      ON exam_questions;
DROP POLICY IF EXISTS "exam_questions_participant_read"  ON exam_questions;
DROP POLICY IF EXISTS "exam_participants_self_rw"        ON exam_participants;
DROP POLICY IF EXISTS "exam_participants_teacher_read"   ON exam_participants;
DROP POLICY IF EXISTS "exam_answers_self_write"          ON exam_answers;
DROP POLICY IF EXISTS "exam_answers_self_read"           ON exam_answers;
DROP POLICY IF EXISTS "exam_answers_teacher_read"        ON exam_answers;

-- ── Recreate with open read, open write ─────────────────────────────
-- (Matches the pattern used by assignments, word_stats, etc.)

-- exam_sessions
CREATE POLICY "exam_sessions_select" ON exam_sessions FOR SELECT USING (true);
CREATE POLICY "exam_sessions_insert" ON exam_sessions FOR INSERT WITH CHECK (true);
CREATE POLICY "exam_sessions_update" ON exam_sessions FOR UPDATE USING (true) WITH CHECK (true);

-- exam_questions (read-only from client; inserts via service_role in Edge Fn)
CREATE POLICY "exam_questions_select" ON exam_questions FOR SELECT USING (true);
CREATE POLICY "exam_questions_insert" ON exam_questions FOR INSERT WITH CHECK (true);

-- exam_participants
CREATE POLICY "exam_participants_select" ON exam_participants FOR SELECT USING (true);
CREATE POLICY "exam_participants_insert" ON exam_participants FOR INSERT WITH CHECK (true);
CREATE POLICY "exam_participants_update" ON exam_participants FOR UPDATE USING (true) WITH CHECK (true);

-- exam_answers
CREATE POLICY "exam_answers_select" ON exam_answers FOR SELECT USING (true);
CREATE POLICY "exam_answers_insert" ON exam_answers FOR INSERT WITH CHECK (true);

-- ── Also grant maybe_end_exam to anon role (no auth = anon) ─────────
GRANT EXECUTE ON FUNCTION public.maybe_end_exam(uuid) TO anon;
