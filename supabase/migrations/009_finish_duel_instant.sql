-- ═══════════════════════════════════════════════════════════════════════
-- VOCABGAME — INSTANT DUEL FINISH (replaces "wait for opponent" model)
--
-- Migration 008 introduced a "wait for both done" model where the second
-- finisher triggered settlement. This was illogical for a competitive
-- duel — whoever locks in their last answer first should immediately
-- end the game and lock the result.
--
-- This migration replaces finish_duel so that the first call commits
-- the duel using:
--   - the caller's authoritative final score (parameter)
--   - the opponent's score as currently in the DB (their last update,
--     which may be partial if they hadn't finished yet — that's the cost
--     of being slower)
--
-- The done-flag columns from 008 stay (harmless, would require a separate
-- cleanup migration to drop). They're written to but no longer gate the
-- settlement.
-- ═══════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION finish_duel(
  p_duel_id uuid,
  p_is_challenger boolean,
  p_my_final_score integer
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

  -- Idempotent: late callers (their opponent finished first) get the
  -- cached result back so their notifier can navigate to results.
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

  -- Write caller's authoritative final score and update local view of row.
  IF p_is_challenger THEN
    v_row.challenger_score := p_my_final_score;
    UPDATE duels SET
      challenger_score = p_my_final_score,
      challenger_done = true
    WHERE id = p_duel_id;
  ELSE
    v_row.opponent_score := p_my_final_score;
    UPDATE duels SET
      opponent_score = p_my_final_score,
      opponent_done = true
    WHERE id = p_duel_id;
  END IF;

  -- Determine winner from current DB state. If the opponent hadn't
  -- finished yet, their score is whatever they had when this RPC ran —
  -- the "race to finish" is the duel.
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
