// supabase/functions/start-exam/index.ts
//
// Teacher calls this to flip a session from 'lobby' to 'in_progress'.
// Sets started_at, flips all 'joined' participants to 'in_progress',
// marks non-joiners as 'absent'.
//
// Request body: { userId: "<profile-uuid>", sessionId: "<uuid>" }
// Response:     { startedAt }

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

    // Verify the teacher owns this session and it is still in lobby.
    const { data: session, error: sessErr } = await admin
      .from('exam_sessions')
      .select('id, status, teacher_id')
      .eq('id', sessionId)
      .single();
    if (sessErr || !session) {
      return new Response('session not found', { status: 404 });
    }
    if (session.teacher_id !== userId) {
      return new Response('not your session', { status: 403 });
    }
    if (session.status !== 'lobby') {
      return new Response(`cannot start from status '${session.status}'`, { status: 409 });
    }

    const startedAt = new Date().toISOString();

    // Flip session to in_progress.
    const { error: upErr } = await admin
      .from('exam_sessions')
      .update({ status: 'in_progress', started_at: startedAt })
      .eq('id', sessionId);
    if (upErr) {
      return new Response(`session update failed: ${upErr.message}`, { status: 500 });
    }

    // Mark 'joined' participants as 'in_progress'.
    await admin
      .from('exam_participants')
      .update({ status: 'in_progress' })
      .eq('session_id', sessionId)
      .eq('status', 'joined');

    // Mark non-joiners ('invited') as 'absent'.
    await admin
      .from('exam_participants')
      .update({ status: 'absent' })
      .eq('session_id', sessionId)
      .eq('status', 'invited');

    return new Response(JSON.stringify({ startedAt }), {
      headers: { 'Content-Type': 'application/json' },
      status: 200,
    });
  } catch (e) {
    return new Response(`error: ${e instanceof Error ? e.message : String(e)}`, { status: 500 });
  }
});
