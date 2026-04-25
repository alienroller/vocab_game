-- ═══════════════════════════════════════════════════════════════════════
-- VOCABGAME — ATOMIC DUEL FINISH RPC
--
-- Replaces the 3-step client-side CAS pattern in DuelService.finishDuel()
-- with a single server-side plpgsql function. Failure of any step now
-- auto-rolls back the whole transaction (Postgres guarantees). Eliminates
-- the "stuck in settling" zombie state and the partial-XP-award failure
-- mode.
--
-- Flow:
--   1. Client calls finish_duel(duel_id, is_challenger, my_final_score)
--      when they answer the last question.
--   2. Function locks the row, writes the caller's final score, sets
--      the caller's `done` flag, and checks whether the opponent is done.
--   3. If opponent isn't done yet: returns {"status":"waiting"} and the
--      client waits for a Postgres Changes 'finished' event.
--   4. If opponent is done: determines winner, awards XP, commits
--      status='finished', returns the full result.
--   5. Late callers (already finished) get the cached result back
--      immediately — idempotent.
--
-- Run in Supabase SQL Editor.
-- ═══════════════════════════════════════════════════════════════════════

-- ── 1. Add per-player done flags ───────────────────────────────────────
ALTER TABLE duels ADD COLUMN IF NOT EXISTS challenger_done boolean DEFAULT false NOT NULL;
ALTER TABLE duels ADD COLUMN IF NOT EXISTS opponent_done boolean DEFAULT false NOT NULL;

-- ── 2. Atomic finish function ──────────────────────────────────────────
CREATE OR REPLACE FUNCTION finish_duel(
  p_duel_id uuid,
  p_is_challenger boolean,
  p_my_final_score integer
) RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
  v_row duels%ROWTYPE;
  v_other_done boolean;
  v_winner_id uuid;
  v_challenger_xp integer;
  v_opponent_xp integer;
BEGIN
  -- Row-level lock serializes concurrent finish_duel calls on the same duel.
  SELECT * INTO v_row FROM duels WHERE id = p_duel_id FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('status', 'error', 'reason', 'duel_not_found');
  END IF;

  -- Idempotent: if already finished, return the cached result.
  IF v_row.status = 'finished' THEN
    RETURN jsonb_build_object(
      'status', 'finished',
      'challenger_score', v_row.challenger_score,
      'opponent_score', v_row.opponent_score,
      'winner_id', v_row.winner_id,
      'challenger_xp', v_row.challenger_xp_gain,
      'opponent_xp', v_row.opponent_xp_gain,
      'challenger_username', v_row.challenger_username,
      'opponent_username', v_row.opponent_username
    );
  END IF;

  IF v_row.status NOT IN ('active', 'settling') THEN
    RETURN jsonb_build_object('status', 'error', 'reason', v_row.status);
  END IF;

  -- Write caller's authoritative final score + done flag.
  IF p_is_challenger THEN
    UPDATE duels SET
      challenger_score = p_my_final_score,
      challenger_done = true,
      status = 'settling',
      settling_at = COALESCE(settling_at, now())
    WHERE id = p_duel_id;
    v_other_done := v_row.opponent_done;
  ELSE
    UPDATE duels SET
      opponent_score = p_my_final_score,
      opponent_done = true,
      status = 'settling',
      settling_at = COALESCE(settling_at, now())
    WHERE id = p_duel_id;
    v_other_done := v_row.challenger_done;
  END IF;

  IF NOT v_other_done THEN
    -- Opponent hasn't finished yet. Lock releases on return; they'll get
    -- the lock next and trigger the finalization.
    RETURN jsonb_build_object('status', 'waiting');
  END IF;

  -- Both players have posted their final score. Re-read to get the
  -- freshly-written caller score.
  SELECT * INTO v_row FROM duels WHERE id = p_duel_id;

  IF v_row.challenger_score > v_row.opponent_score THEN
    v_winner_id := v_row.challenger_id;
    v_challenger_xp := 50;  -- duelWinnerXp
    v_opponent_xp := 20;    -- duelLoserXp
  ELSIF v_row.opponent_score > v_row.challenger_score THEN
    v_winner_id := v_row.opponent_id;
    v_challenger_xp := 20;
    v_opponent_xp := 50;
  ELSE
    v_winner_id := NULL;
    v_challenger_xp := 30;  -- duelDrawXp
    v_opponent_xp := 30;
  END IF;

  -- Award XP atomically (both updates in this transaction — either both
  -- land or neither does, because any exception aborts the function).
  PERFORM increment_xp(v_row.challenger_id, v_challenger_xp);
  PERFORM increment_xp(v_row.opponent_id, v_opponent_xp);

  -- Commit.
  UPDATE duels SET
    status = 'finished',
    winner_id = v_winner_id,
    challenger_xp_gain = v_challenger_xp,
    opponent_xp_gain = v_opponent_xp,
    finished_at = now()
  WHERE id = p_duel_id;

  RETURN jsonb_build_object(
    'status', 'finished',
    'challenger_score', v_row.challenger_score,
    'opponent_score', v_row.opponent_score,
    'winner_id', v_winner_id,
    'challenger_xp', v_challenger_xp,
    'opponent_xp', v_opponent_xp,
    'challenger_username', v_row.challenger_username,
    'opponent_username', v_row.opponent_username
  );
END;
$$;

-- ── 3. Safety net: force-finish an abandoned duel ──────────────────────
-- If one player disconnects and never posts their final score, the other
-- is stuck on 'waiting'. After a client-side timeout, they can call this
-- to force-settle using whatever the DB has. The abandoner gets loser XP.
CREATE OR REPLACE FUNCTION force_finish_duel(
  p_duel_id uuid
) RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
  v_row duels%ROWTYPE;
  v_winner_id uuid;
  v_challenger_xp integer;
  v_opponent_xp integer;
BEGIN
  SELECT * INTO v_row FROM duels WHERE id = p_duel_id FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('status', 'error', 'reason', 'duel_not_found');
  END IF;

  IF v_row.status = 'finished' THEN
    RETURN jsonb_build_object(
      'status', 'finished',
      'challenger_score', v_row.challenger_score,
      'opponent_score', v_row.opponent_score,
      'winner_id', v_row.winner_id,
      'challenger_xp', v_row.challenger_xp_gain,
      'opponent_xp', v_row.opponent_xp_gain,
      'challenger_username', v_row.challenger_username,
      'opponent_username', v_row.opponent_username
    );
  END IF;

  IF v_row.status NOT IN ('active', 'settling') THEN
    RETURN jsonb_build_object('status', 'error', 'reason', v_row.status);
  END IF;

  IF v_row.challenger_score > v_row.opponent_score THEN
    v_winner_id := v_row.challenger_id;
    v_challenger_xp := 50;
    v_opponent_xp := 20;
  ELSIF v_row.opponent_score > v_row.challenger_score THEN
    v_winner_id := v_row.opponent_id;
    v_challenger_xp := 20;
    v_opponent_xp := 50;
  ELSE
    v_winner_id := NULL;
    v_challenger_xp := 30;
    v_opponent_xp := 30;
  END IF;

  PERFORM increment_xp(v_row.challenger_id, v_challenger_xp);
  PERFORM increment_xp(v_row.opponent_id, v_opponent_xp);

  UPDATE duels SET
    status = 'finished',
    winner_id = v_winner_id,
    challenger_xp_gain = v_challenger_xp,
    opponent_xp_gain = v_opponent_xp,
    finished_at = now()
  WHERE id = p_duel_id;

  RETURN jsonb_build_object(
    'status', 'finished',
    'challenger_score', v_row.challenger_score,
    'opponent_score', v_row.opponent_score,
    'winner_id', v_winner_id,
    'challenger_xp', v_challenger_xp,
    'opponent_xp', v_opponent_xp,
    'challenger_username', v_row.challenger_username,
    'opponent_username', v_row.opponent_username
  );
END;
$$;
