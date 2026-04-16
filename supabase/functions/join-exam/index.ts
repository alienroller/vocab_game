// supabase/functions/join-exam/index.ts
//
// Student calls this to join an invited or in-progress exam.
// Late-join is allowed at any time while status is lobby or in_progress.
//
// Request body: { userId: "<profile-uuid>", sessionId: "<uuid>" }
// Response:     { status: 'joined', sessionStatus, startedAt, totalSeconds, perQuestionSeconds }

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

serve(async (req) => {
  try {
    const url    = Deno.env.get('SUPABASE_URL')!;
    const srvKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

    const { userId, sessionId } = await req.json() as { userId: string; sessionId: string };
    if (!userId || !sessionId) {
      return new Response('userId and sessionId required', { status: 400 });
    }

    const admin = createClient(url, srvKey);

    // Opportunistic auto-end for stale sessions (teacher-offline case).
    await admin.rpc('maybe_end_exam', { session: sessionId });

    // Read the session.
    const { data: session, error: sessErr } = await admin
      .from('exam_sessions')
      .select('id, status, started_at, total_seconds, per_question_seconds, class_code')
      .eq('id', sessionId)
      .single();
    if (sessErr || !session) {
      return new Response('session not found', { status: 404 });
    }
    if (session.status === 'completed' || session.status === 'cancelled' || session.status === 'abandoned') {
      return new Response('session already ended', { status: 409 });
    }

    // Verify student belongs to this class.
    const { data: profile, error: profErr } = await admin
      .from('profiles')
      .select('class_code')
      .eq('id', userId)
      .single();
    if (profErr || !profile || profile.class_code !== session.class_code) {
      return new Response('not in this class', { status: 403 });
    }

    // Upsert the participant row. If it already exists as 'invited' or 'joined',
    // flip to 'joined' and stamp joined_at. Idempotent.
    const { error: upErr } = await admin
      .from('exam_participants')
      .upsert({
        session_id: sessionId,
        student_id: userId,
        status: session.status === 'in_progress' ? 'in_progress' : 'joined',
        joined_at: new Date().toISOString(),
        shuffle_seed: Math.floor(Math.random() * 2_147_483_647),
      }, { onConflict: 'session_id,student_id', ignoreDuplicates: false });

    if (upErr) {
      return new Response(`join failed: ${upErr.message}`, { status: 500 });
    }

    return new Response(JSON.stringify({
      status: 'joined',
      sessionStatus: session.status,
      startedAt: session.started_at,
      totalSeconds: session.total_seconds,
      perQuestionSeconds: session.per_question_seconds,
    }), {
      headers: { 'Content-Type': 'application/json' },
      status: 200,
    });
  } catch (e) {
    return new Response(`error: ${e instanceof Error ? e.message : String(e)}`, { status: 500 });
  }
});
