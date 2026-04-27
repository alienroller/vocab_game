// supabase/functions/submit-answer/index.ts
//
// Student calls this for each question. Server grades the answer and
// writes the exam_answers row. Also stamps the participant's
// current_question_served_at for the next question's per-question timer.
//
// Request body:
//   {
//     userId: "<profile-uuid>",
//     sessionId: "<uuid>",
//     questionId: "<uuid>",
//     answer: "kitob",
//     secondsTaken: 12
//   }
//
// Response:
//   {
//     isCorrect: true,
//     correctAnswer: "kitob",
//     questionsRemaining: 7,
//     finished: false
//   }

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

serve(async (req) => {
  try {
    const url    = Deno.env.get('SUPABASE_URL')!;
    const srvKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

    const body = await req.json() as {
      userId: string;
      sessionId: string;
      questionId: string;
      answer: string;
      secondsTaken: number;
    };
    if (!body.userId || !body.sessionId || !body.questionId || body.answer == null) {
      return new Response('missing fields', { status: 400 });
    }

    const studentId = body.userId;
    const admin = createClient(url, srvKey);

    // ── Validate session is in_progress and not expired ──────────────

    const { data: session, error: sessErr } = await admin
      .from('exam_sessions')
      .select('id, status, started_at, total_seconds, per_question_seconds, question_count')
      .eq('id', body.sessionId)
      .single();

    if (sessErr || !session) {
      return new Response('session not found', { status: 404 });
    }
    if (session.status !== 'in_progress') {
      return new Response('session is not in progress', { status: 409 });
    }

    // Auto-end check.
    const startedAt = new Date(session.started_at).getTime();
    const now = Date.now();
    if (now > startedAt + session.total_seconds * 1000) {
      // Session time expired — end it.
      await admin.from('exam_sessions')
        .update({ status: 'completed', ended_at: new Date().toISOString() })
        .eq('id', body.sessionId);
      return new Response('session time expired', { status: 409 });
    }

    // ── Validate participant ─────────────────────────────────────────

    const { data: participant, error: partErr } = await admin
      .from('exam_participants')
      .select('status, current_question_served_at, current_order_index')
      .eq('session_id', body.sessionId)
      .eq('student_id', studentId)
      .single();

    if (partErr || !participant) {
      return new Response('you are not a participant', { status: 403 });
    }
    if (participant.status === 'completed' || participant.status === 'timed_out') {
      return new Response('you already finished', { status: 409 });
    }

    // ── Validate question ────────────────────────────────────────────

    const { data: question, error: qErr } = await admin
      .from('exam_questions')
      .select('id, order_index, correct_answer')
      .eq('id', body.questionId)
      .eq('session_id', body.sessionId)
      .single();

    if (qErr || !question) {
      return new Response('question not found', { status: 404 });
    }

    // Note: we intentionally do NOT enforce a monotonic order_index check
    // here. The client shuffles question order per student (anti-cheating),
    // so students legitimately submit in a non-monotonic order. Duplicate
    // submissions are still blocked below by the `existing` row lookup.

    // Per-question timer enforcement (allow 2s grace for network).
    if (participant.current_question_served_at) {
      const served = new Date(participant.current_question_served_at).getTime();
      const deadline = served + (session.per_question_seconds + 2) * 1000;
      if (now > deadline) {
        // Over time — still record the answer but mark wrong.
        body.answer = '__timed_out__';
      }
    }

    // ── Grade ────────────────────────────────────────────────────────

    const isCorrect = body.answer.trim().toLowerCase() ===
      question.correct_answer.trim().toLowerCase();

    // Prevent duplicate answers.
    const { data: existing } = await admin
      .from('exam_answers')
      .select('id')
      .eq('session_id', body.sessionId)
      .eq('student_id', studentId)
      .eq('question_id', body.questionId)
      .maybeSingle();

    if (existing) {
      return new Response('already answered', { status: 409 });
    }

    // Write the answer.
    const { error: ansErr } = await admin.from('exam_answers').insert({
      session_id: body.sessionId,
      student_id: studentId,
      question_id: body.questionId,
      order_index: question.order_index,
      answer: body.answer,
      is_correct: isCorrect,
      seconds_taken: Math.max(0, Math.min(body.secondsTaken ?? 0, session.per_question_seconds + 2)),
    });
    if (ansErr) {
      return new Response(`answer insert failed: ${ansErr.message}`, { status: 500 });
    }

    // ── Advance participant pointer ──────────────────────────────────

    // Count how many this student got correct/answered so far (includes the
    // answer we just inserted). We use the answered count — not order_index —
    // to decide whether this was the final question, because the client
    // shuffles question order per student.
    const { count: correctSoFar } = await admin
      .from('exam_answers')
      .select('id', { count: 'exact', head: true })
      .eq('session_id', body.sessionId)
      .eq('student_id', studentId)
      .eq('is_correct', true);

    const { count: answeredSoFar } = await admin
      .from('exam_answers')
      .select('id', { count: 'exact', head: true })
      .eq('session_id', body.sessionId)
      .eq('student_id', studentId);

    const nextIndex = question.order_index + 1;
    const isLast = (answeredSoFar ?? 0) >= session.question_count;

    if (isLast) {
      // Student finished the exam.
      await admin.from('exam_participants').update({
        status: 'completed',
        finished_at: new Date().toISOString(),
        current_order_index: nextIndex,
        score: correctSoFar ?? 0,
        correct_count: correctSoFar ?? 0,
        total_count: answeredSoFar ?? 0,
      })
        .eq('session_id', body.sessionId)
        .eq('student_id', studentId);

      // Check if everyone is done — auto-end session.
      const { count: remaining } = await admin
        .from('exam_participants')
        .select('student_id', { count: 'exact', head: true })
        .eq('session_id', body.sessionId)
        .in('status', ['joined', 'in_progress']);

      if ((remaining ?? 0) === 0) {
        await admin.from('exam_sessions')
          .update({ status: 'completed', ended_at: new Date().toISOString() })
          .eq('id', body.sessionId)
          .eq('status', 'in_progress');
      }
    } else {
      // Stamp next question's serve time for per-question timer.
      await admin.from('exam_participants').update({
        current_order_index: nextIndex,
        current_question_served_at: new Date().toISOString(),
        status: 'in_progress',
      })
        .eq('session_id', body.sessionId)
        .eq('student_id', studentId);
    }

    return new Response(JSON.stringify({
      isCorrect,
      correctAnswer: question.correct_answer,
      questionsRemaining: session.question_count - nextIndex,
      finished: isLast,
      correctSoFar: correctSoFar ?? 0,
      answeredSoFar: answeredSoFar ?? 0,
    }), {
      headers: { 'Content-Type': 'application/json' },
      status: 200,
    });
  } catch (e) {
    return new Response(`error: ${e instanceof Error ? e.message : String(e)}`, { status: 500 });
  }
});
