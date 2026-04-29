-- ═══════════════════════════════════════════════════════════════════════
-- VOCABGAME — force-end exam atomically (BUG E6)
-- Run this in the Supabase SQL Editor AFTER 015_exam_questions_secure.sql.
--
-- BEFORE: ExamService.endSession just flipped exam_sessions.status to
-- 'completed'. Participants who were 'joined' or 'in_progress' stayed in
-- those statuses, so the teacher's results screen couldn't tell them
-- apart from "still going". The teacher's End-Now confirmation dialog
-- promised "students who haven't finished will be marked as timed out"
-- but nothing did the marking.
-- AFTER: a single RPC flips the session AND every non-terminal
-- participant to 'timed_out' in one transaction.
-- ═══════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.force_end_exam(p_session uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Only end sessions that are still active. No-op for already-completed
  -- sessions so re-pressing "End now" doesn't change anything.
  UPDATE exam_sessions
     SET status = 'completed',
         ended_at = NOW()
   WHERE id = p_session
     AND status IN ('lobby', 'in_progress');

  -- Anyone who hadn't reached a terminal status by the time the teacher
  -- pressed End is marked timed_out. We snapshot their per-student
  -- correct/total counts from exam_answers so the results screen can
  -- still render their partial score.
  UPDATE exam_participants p
     SET status = 'timed_out',
         finished_at = NOW(),
         correct_count = COALESCE((
           SELECT COUNT(*)::int FROM exam_answers a
            WHERE a.session_id = p.session_id
              AND a.student_id = p.student_id
              AND a.is_correct = true
         ), 0),
         total_count = COALESCE((
           SELECT COUNT(*)::int FROM exam_answers a
            WHERE a.session_id = p.session_id
              AND a.student_id = p.student_id
         ), 0)
   WHERE p.session_id = p_session
     AND p.status IN ('joined', 'in_progress', 'invited');
END;
$$;

REVOKE ALL ON FUNCTION public.force_end_exam(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.force_end_exam(uuid) TO anon, authenticated;
