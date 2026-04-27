-- ═══════════════════════════════════════════════════════════════════════
-- VOCABGAME — FRIENDSHIPS FIXES (post-013 audit)
--
-- Three bug fixes from the audit pass:
--   1. send_friend_request crashed on the simultaneous mutual-add race
--      (both sides passed FOR UPDATE finding nothing, both INSERT, one
--      tripped the canonical-edge unique index → unhandled exception).
--      Fix: wrap INSERT in EXCEPTION WHEN unique_violation that re-reads
--      and applies the same auto-accept logic as the FOUND branch.
--
--   2. The LOWER(username) text_pattern_ops btree index didn't accelerate
--      the actual ILIKE query (ILIKE never uses text_pattern_ops). Fix:
--      drop it, install pg_trgm, create a gin gin_trgm_ops index that
--      Postgres will use for ILIKE prefix matches.
--
--   3. Realtime payloads don't include joined data, so the friend-request
--      notification handler would have shown a UUID. Fix: denormalize
--      requester_username onto the friendships row (set inside the RPC).
--
-- Run in Supabase SQL Editor. Idempotent — safe to re-run.
-- ═══════════════════════════════════════════════════════════════════════

-- ── Bug 3a: denormalize requester_username ────────────────────────────
ALTER TABLE friendships
  ADD COLUMN IF NOT EXISTS requester_username text;

-- Backfill any rows that pre-date this column.
UPDATE friendships f
SET requester_username = p.username
FROM profiles p
WHERE f.requester_id = p.id
  AND f.requester_username IS NULL;

-- ── Bug 2: replace wasted btree index with pg_trgm gin index ──────────
DROP INDEX IF EXISTS idx_profiles_username_lower;

CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE INDEX IF NOT EXISTS idx_profiles_username_trgm
  ON profiles USING gin (username gin_trgm_ops);

-- ── Bug 1 + Bug 3b: corrected RPC ─────────────────────────────────────
-- - INSERT is wrapped in EXCEPTION WHEN unique_violation that recovers
--   from the simultaneous-mutual-add race by re-reading the row the
--   other side just committed.
-- - Caches the requester's username up front and writes it on every
--   path that creates or rewrites the canonical edge (initial INSERT
--   and the declined→reopen UPDATE).
CREATE OR REPLACE FUNCTION send_friend_request(
  p_requester uuid,
  p_addressee uuid
) RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
  v_existing friendships%ROWTYPE;
  v_new_id   uuid;
  v_username text;
BEGIN
  IF p_requester = p_addressee THEN
    RETURN jsonb_build_object('status','error','reason','self');
  END IF;

  -- Cache the requester's username so we can denormalize onto the row.
  -- Realtime payloads don't include joined data; notification handlers
  -- read this directly off payload.newRecord.
  SELECT username INTO v_username FROM profiles WHERE id = p_requester;

  -- Lock any existing edge in either direction.
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
        SET requester_id       = p_requester,
            addressee_id       = p_addressee,
            requester_username = v_username,
            status             = 'pending',
            created_at         = now(),
            responded_at       = NULL
        WHERE id = v_existing.id;
      RETURN jsonb_build_object('status','pending','id',v_existing.id);
    END IF;

    -- Blocked: behave like the request silently went nowhere.
    IF v_existing.status = 'blocked' THEN
      RETURN jsonb_build_object('status','blocked');
    END IF;
  END IF;

  -- No existing edge. Insert. If the canonical-edge unique index trips,
  -- the other side just inserted between our SELECT FOR UPDATE and our
  -- INSERT — recover by re-reading and auto-accepting.
  BEGIN
    INSERT INTO friendships
      (requester_id, addressee_id, requester_username, status)
    VALUES
      (p_requester, p_addressee, v_username, 'pending')
    RETURNING id INTO v_new_id;
  EXCEPTION WHEN unique_violation THEN
    SELECT * INTO v_existing FROM friendships
    WHERE (requester_id = p_requester AND addressee_id = p_addressee)
       OR (requester_id = p_addressee AND addressee_id = p_requester)
    FOR UPDATE;

    -- The other side's row is the inverse pending request. Auto-accept.
    IF v_existing.status = 'pending'
       AND v_existing.addressee_id = p_requester THEN
      UPDATE friendships
        SET status = 'accepted', responded_at = now()
        WHERE id = v_existing.id;
      RETURN jsonb_build_object('status','accepted','id',v_existing.id);
    END IF;

    -- Defensive fallback — shouldn't really land here.
    RETURN jsonb_build_object('status', v_existing.status, 'id', v_existing.id);
  END;

  RETURN jsonb_build_object('status','pending','id',v_new_id);
END;
$$;
