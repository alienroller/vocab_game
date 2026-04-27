-- ═══════════════════════════════════════════════════════════════════════
-- VOCABGAME — FRIENDSHIPS
--
-- Adds the social graph (friend search → request → accept → duel).
-- Pattern mirrors duels: open RLS for the anon role (the app uses no
-- Supabase Auth), table added to supabase_realtime publication so
-- onPostgresChanges callbacks fire, and the "send request" path goes
-- through a plpgsql RPC that holds a row-level lock to avoid the
-- mutual-add race.
--
-- Run in Supabase SQL Editor (idempotent — safe to re-run).
-- ═══════════════════════════════════════════════════════════════════════

-- ── 1. Table ──────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS friendships (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  requester_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  addressee_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  status       text NOT NULL DEFAULT 'pending'
                 CHECK (status IN ('pending','accepted','declined','blocked')),
  created_at   timestamptz NOT NULL DEFAULT now(),
  responded_at timestamptz,
  CHECK (requester_id <> addressee_id)
);

-- Canonical-edge uniqueness: prevents both (A,B) and (B,A) rows from existing
-- simultaneously. The RPC below resolves the mutual-add race by auto-accepting
-- when the inverse pending row is found.
CREATE UNIQUE INDEX IF NOT EXISTS friendships_canonical_edge
  ON friendships (LEAST(requester_id, addressee_id),
                  GREATEST(requester_id, addressee_id));

CREATE INDEX IF NOT EXISTS friendships_addressee_status_idx
  ON friendships (addressee_id, status);
CREATE INDEX IF NOT EXISTS friendships_requester_status_idx
  ON friendships (requester_id, status);

-- Username prefix search needs a btree index on LOWER(username) to keep
-- ILIKE 'q%' off a sequential scan as the user table grows.
CREATE INDEX IF NOT EXISTS idx_profiles_username_lower
  ON profiles (LOWER(username) text_pattern_ops);

-- ── 2. Realtime publication ───────────────────────────────────────────
DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE friendships;
EXCEPTION WHEN duplicate_object THEN
  -- already in publication
END;
$$;

-- ── 3. RLS (open-anon, mirrors duels/profiles) ────────────────────────
ALTER TABLE friendships ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "friendships_select_all" ON friendships;
CREATE POLICY "friendships_select_all" ON friendships
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "friendships_insert" ON friendships;
CREATE POLICY "friendships_insert" ON friendships
  FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "friendships_update" ON friendships;
CREATE POLICY "friendships_update" ON friendships
  FOR UPDATE USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "friendships_delete" ON friendships;
CREATE POLICY "friendships_delete" ON friendships
  FOR DELETE USING (true);

-- ── 4. RPC: send_friend_request ───────────────────────────────────────
-- Returns jsonb: { status: 'pending'|'accepted'|'blocked'|'error', id?, reason? }
--
-- - If the inverse pending row exists (they sent first), auto-accepts.
-- - If a pending row from me already exists, returns 'pending' idempotently.
-- - If we're already accepted, returns 'accepted' idempotently.
-- - If a previous decline exists, re-opens as a fresh pending request from
--   the new requester (Facebook-style: declined isn't permanent unless blocked).
-- - If blocked, returns 'blocked' but takes no action.
CREATE OR REPLACE FUNCTION send_friend_request(
  p_requester uuid,
  p_addressee uuid
) RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
  v_existing friendships%ROWTYPE;
  v_new_id   uuid;
BEGIN
  IF p_requester = p_addressee THEN
    RETURN jsonb_build_object('status','error','reason','self');
  END IF;

  -- Lock any existing edge in either direction so two concurrent calls
  -- from A and B serialize cleanly (one becomes auto-accept, the other
  -- becomes idempotent return).
  SELECT * INTO v_existing FROM friendships
  WHERE (requester_id = p_requester AND addressee_id = p_addressee)
     OR (requester_id = p_addressee AND addressee_id = p_requester)
  FOR UPDATE;

  IF FOUND THEN
    -- Mutual intent: they already sent me a request → accept it.
    IF v_existing.status = 'pending' AND v_existing.addressee_id = p_requester THEN
      UPDATE friendships
        SET status = 'accepted', responded_at = now()
        WHERE id = v_existing.id;
      RETURN jsonb_build_object('status','accepted','id',v_existing.id);
    END IF;

    -- Already pending in my direction OR already friends → idempotent.
    IF v_existing.status IN ('pending','accepted') THEN
      RETURN jsonb_build_object('status', v_existing.status, 'id', v_existing.id);
    END IF;

    -- Previously declined → re-open as a new pending from the new requester.
    IF v_existing.status = 'declined' THEN
      UPDATE friendships
        SET requester_id = p_requester,
            addressee_id = p_addressee,
            status       = 'pending',
            created_at   = now(),
            responded_at = NULL
        WHERE id = v_existing.id;
      RETURN jsonb_build_object('status','pending','id',v_existing.id);
    END IF;

    -- Blocked: behave like the request silently went nowhere.
    IF v_existing.status = 'blocked' THEN
      RETURN jsonb_build_object('status','blocked');
    END IF;
  END IF;

  INSERT INTO friendships (requester_id, addressee_id, status)
  VALUES (p_requester, p_addressee, 'pending')
  RETURNING id INTO v_new_id;

  RETURN jsonb_build_object('status','pending','id',v_new_id);
END;
$$;
