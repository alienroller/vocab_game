-- ═══════════════════════════════════════════════════════════════════════
-- VOCABGAME — DUELS REALTIME + RLS
--
-- Two problems this migration fixes:
--
-- 1. supabase_realtime publication
--    Postgres Changes subscriptions are silently dead unless the target
--    table is added to the supabase_realtime replication publication.
--    Without this, onPostgresChanges callbacks never fire.
--
-- 2. Row Level Security
--    The app uses custom auth (not Supabase JWT), so all Realtime
--    connections run as the `anon` role. If RLS is enabled without an
--    open SELECT policy, Realtime drops every event silently.
--    These policies mirror the open-access pattern already used on
--    profiles/classes (see 002_enable_rls.sql).
--
-- Run in Supabase SQL Editor.
-- ═══════════════════════════════════════════════════════════════════════

-- ── 1. Enable Realtime tracking (idempotent — skip if already a member) ──
DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE duels;
EXCEPTION WHEN duplicate_object THEN
  -- already in publication, nothing to do
END;
$$;

-- ── 2. Enable RLS ─────────────────────────────────────────────────────
ALTER TABLE duels ENABLE ROW LEVEL SECURITY;

-- ── 3. Open policies (app-level auth, no JWT) ─────────────────────────

-- Anyone can read duels (required for Realtime to deliver events to anon)
DROP POLICY IF EXISTS "duels_select_all" ON duels;
CREATE POLICY "duels_select_all" ON duels
  FOR SELECT USING (true);

-- Any client can create a duel row (challenger initiates)
DROP POLICY IF EXISTS "duels_insert" ON duels;
CREATE POLICY "duels_insert" ON duels
  FOR INSERT WITH CHECK (true);

-- Any client can update a duel row (accept / score update / finish)
DROP POLICY IF EXISTS "duels_update_participant" ON duels;
CREATE POLICY "duels_update_participant" ON duels
  FOR UPDATE USING (true) WITH CHECK (true);
