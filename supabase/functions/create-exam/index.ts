// supabase/functions/create-exam/index.ts
//
// Teacher calls this to create a new exam session.
// Request body:
//   {
//     userId: "<profile-uuid>",          // teacher's profile.id
//     classCode: "ENG7B",
//     title: "Book 1, Units 3-5",
//     bookIds: ["book_1"],
//     unitIds: ["unit_3","unit_4","unit_5"],
//     questionCount: 20,
//     perQuestionSeconds: 30,
//     totalSeconds: 900,
//     words: [{ id, english, uzbek }, ...]   // the word pool the teacher picked
//   }
//
// Server picks `questionCount` words from `words`, builds MC options
// (correct + 3 distractors sampled from remaining `words`), writes
// exam_sessions + exam_questions rows, and pre-invites every student
// in `classCode` into exam_participants with status='invited'.
//
// Response: { sessionId }

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

interface Word { id: string; english: string; uzbek: string; }

interface Body {
  userId: string;
  classCode: string;
  title: string;
  bookIds: string[];
  unitIds: string[];
  questionCount: number;
  perQuestionSeconds: number;
  totalSeconds: number;
  words: Word[];
}

function shuffle<T>(arr: T[], rng: () => number): T[] {
  const copy = [...arr];
  for (let i = copy.length - 1; i > 0; i--) {
    const j = Math.floor(rng() * (i + 1));
    [copy[i], copy[j]] = [copy[j], copy[i]];
  }
  return copy;
}

serve(async (req) => {
  try {
    const url    = Deno.env.get('SUPABASE_URL')!;
    const srvKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

    const body = (await req.json()) as Body;

    // Validate required fields.
    if (
      !body.userId || !body.classCode || !body.title ||
      !Array.isArray(body.words) || body.words.length < body.questionCount ||
      body.questionCount < 1 || body.questionCount > 100 ||
      body.perQuestionSeconds < 5 || body.perQuestionSeconds > 300 ||
      body.totalSeconds < 30 || body.totalSeconds > 7200
    ) {
      return new Response('invalid payload', { status: 400 });
    }

    const teacherId = body.userId;

    // Service-role client — bypasses RLS.
    const admin = createClient(url, srvKey);

    // Verify teacher owns this class.
    const { data: cls, error: clsErr } = await admin
      .from('classes')
      .select('code')
      .eq('code', body.classCode)
      .eq('teacher_id', teacherId)
      .single();
    if (clsErr || !cls) {
      return new Response('not your class', { status: 403 });
    }

    // Pick the question set.
    const rng = Math.random;
    const picked = shuffle(body.words, rng).slice(0, body.questionCount);
    const remaining = body.words.filter((w) => !picked.includes(w));

    // Create the session.
    const { data: session, error: sessErr } = await admin
      .from('exam_sessions')
      .insert({
        teacher_id: teacherId,
        class_code: body.classCode,
        title: body.title,
        book_ids: body.bookIds,
        unit_ids: body.unitIds,
        question_count: body.questionCount,
        per_question_seconds: body.perQuestionSeconds,
        total_seconds: body.totalSeconds,
        status: 'lobby',
      })
      .select()
      .single();
    if (sessErr || !session) {
      return new Response(`session insert failed: ${sessErr?.message}`, { status: 500 });
    }

    // Build questions.
    const questionRows = picked.map((w, i) => {
      const distractorPool = remaining.length >= 3
        ? remaining
        : body.words.filter((x) => x.id !== w.id);
      const distractors = shuffle(distractorPool, rng).slice(0, 3);
      const options = shuffle([w.uzbek, ...distractors.map((d) => d.uzbek)], rng);
      return {
        session_id: session.id,
        order_index: i,
        word_id: w.id,
        prompt: w.english,
        correct_answer: w.uzbek,
        options,
      };
    });
    const { error: qErr } = await admin.from('exam_questions').insert(questionRows);
    if (qErr) {
      return new Response(`questions insert failed: ${qErr.message}`, { status: 500 });
    }

    // Pre-invite every student in the class.
    const { data: students, error: stuErr } = await admin
      .from('profiles')
      .select('id')
      .eq('class_code', body.classCode)
      .eq('is_teacher', false);
    if (stuErr) {
      return new Response(`class fetch failed: ${stuErr.message}`, { status: 500 });
    }

    if (students && students.length > 0) {
      const participantRows = students.map((s: { id: string }) => ({
        session_id: session.id,
        student_id: s.id,
        status: 'invited',
        shuffle_seed: Math.floor(Math.random() * 2_147_483_647),
      }));
      const { error: pErr } = await admin
        .from('exam_participants')
        .insert(participantRows);
      if (pErr) {
        return new Response(`invite failed: ${pErr.message}`, { status: 500 });
      }
    }

    return new Response(JSON.stringify({ sessionId: session.id }), {
      headers: { 'Content-Type': 'application/json' },
      status: 200,
    });
  } catch (e) {
    return new Response(`error: ${e instanceof Error ? e.message : String(e)}`, { status: 500 });
  }
});
