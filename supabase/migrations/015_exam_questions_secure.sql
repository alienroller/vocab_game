-- ═══════════════════════════════════════════════════════════════════════
-- VOCABGAME — close the correct_answer leak (BUG C3)
-- Run this in the Supabase SQL Editor AFTER 005_exam_rls_open.sql.
--
-- BEFORE: 005_exam_rls_open.sql opens exam_questions SELECT to everyone
-- (`USING (true)`), so anyone with the anon key could read correct_answer
-- by issuing `SELECT * FROM exam_questions`. RLS is row-level, not
-- column-level — we can't filter columns with a policy. So we REVOKE
-- direct SELECT entirely and force every read to go through SECURITY
-- DEFINER RPCs that return only the columns each role is entitled to.
-- ═══════════════════════════════════════════════════════════════════════

-- 1. Drop both the original policy and the wide-open replacement.
DROP POLICY IF EXISTS "exam_questions_participant_read" ON exam_questions;
DROP POLICY IF EXISTS exam_questions_participant_read   ON exam_questions;
DROP POLICY IF EXISTS "exam_questions_select"           ON exam_questions;
DROP POLICY IF EXISTS exam_questions_select             ON exam_questions;
DROP POLICY IF EXISTS "exam_questions_teacher_read"     ON exam_questions;
DROP POLICY IF EXISTS exam_questions_teacher_read       ON exam_questions;

-- 2. Strip the underlying SELECT grant. With no SELECT grant, even if a
--    permissive policy is recreated by accident, anon can't read rows.
--    Inserts continue to work via the create-exam Edge Function which
--    runs with service_role and bypasses RLS.
REVOKE SELECT ON exam_questions FROM anon;
REVOKE SELECT ON exam_questions FROM authenticated;

-- 2. SECURITY DEFINER RPC: returns the safe column subset for a participant.
--    The function checks that p_student has an exam_participants row for the
--    session before returning anything — this is the only path students
--    have into exam_questions.
CREATE OR REPLACE FUNCTION public.get_student_exam_questions(
  p_session uuid,
  p_student text
)
RETURNS TABLE(
  id uuid,
  order_index int,
  prompt text,
  options jsonb
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT q.id, q.order_index, q.prompt, q.options
    FROM exam_questions q
   WHERE q.session_id = p_session
     AND EXISTS (
           SELECT 1 FROM exam_participants p
            WHERE p.session_id = p_session
              AND p.student_id = p_student
              AND p.status IN ('joined','in_progress','completed')
         )
   ORDER BY q.order_index;
$$;

REVOKE ALL ON FUNCTION public.get_student_exam_questions(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_student_exam_questions(uuid, text) TO anon, authenticated;

-- 3. Post-exam review: a student is entitled to see correct_answer for the
--    questions they've already answered (so the results screen can show
--    "you said X, correct was Y"). The function returns rows ONLY for
--    questions in exam_answers belonging to this student.
CREATE OR REPLACE FUNCTION public.get_student_exam_review(
  p_session uuid,
  p_student text
)
RETURNS TABLE(
  question_id uuid,
  prompt text,
  correct_answer text,
  my_answer text,
  is_correct boolean
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT q.id            AS question_id,
         q.prompt        AS prompt,
         q.correct_answer AS correct_answer,
         a.answer        AS my_answer,
         a.is_correct    AS is_correct
    FROM exam_answers a
    JOIN exam_questions q ON q.id = a.question_id
   WHERE a.session_id = p_session
     AND a.student_id = p_student
   ORDER BY q.order_index;
$$;

REVOKE ALL ON FUNCTION public.get_student_exam_review(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_student_exam_review(uuid, text) TO anon, authenticated;

-- 4. Teacher-side full read. Returns every column for a session iff the
--    caller's profile is flagged as a teacher AND owns the session.
--    Mirrors the row-level intent of the original `exam_questions_teacher_read`
--    policy that was dropped above.
CREATE OR REPLACE FUNCTION public.get_teacher_exam_questions(
  p_session uuid,
  p_teacher text
)
RETURNS TABLE(
  id uuid,
  order_index int,
  prompt text,
  correct_answer text,
  options jsonb
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT q.id, q.order_index, q.prompt, q.correct_answer, q.options
    FROM exam_questions q
   WHERE q.session_id = p_session
     AND EXISTS (
           SELECT 1 FROM exam_sessions s
            WHERE s.id = p_session
              AND s.teacher_id = p_teacher
         )
     AND EXISTS (
           SELECT 1 FROM profiles pr
            WHERE pr.id::text = p_teacher
              AND pr.is_teacher = true
         )
   ORDER BY q.order_index;
$$;

REVOKE ALL ON FUNCTION public.get_teacher_exam_questions(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_teacher_exam_questions(uuid, text) TO anon, authenticated;
