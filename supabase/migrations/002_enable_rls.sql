-- ═══════════════════════════════════════════════════════════════════════
-- VOCABGAME — ROW LEVEL SECURITY (RLS) MIGRATION
-- Run this in the Supabase SQL Editor.
-- ═══════════════════════════════════════════════════════════════════════

-- STEP 1: Enable RLS on both tables
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE classes ENABLE ROW LEVEL SECURITY;

-- STEP 2: profiles policies

-- Anyone can read profiles (needed for leaderboard, rival card, class dashboard)
DROP POLICY IF EXISTS "profiles_select_public" ON profiles;
CREATE POLICY "profiles_select_public" ON profiles
  FOR SELECT USING (true);

-- Allow update (app-level validation for now — no Supabase Auth)
DROP POLICY IF EXISTS "profiles_update_own" ON profiles;
CREATE POLICY "profiles_update_own" ON profiles
  FOR UPDATE USING (true)
  WITH CHECK (true);

-- Prevent DELETE from client (deletion must go through Edge Function)
DROP POLICY IF EXISTS "profiles_no_delete" ON profiles;
CREATE POLICY "profiles_no_delete" ON profiles
  FOR DELETE USING (false);

-- Allow INSERT only for new rows (onboarding)
DROP POLICY IF EXISTS "profiles_insert" ON profiles;
CREATE POLICY "profiles_insert" ON profiles
  FOR INSERT WITH CHECK (true);

-- STEP 3: classes policies

-- Anyone can read classes (needed to validate class codes)
DROP POLICY IF EXISTS "classes_select_public" ON classes;
CREATE POLICY "classes_select_public" ON classes
  FOR SELECT USING (true);

-- Anyone can insert a class (teacher creates class during onboarding)
DROP POLICY IF EXISTS "classes_insert" ON classes;
CREATE POLICY "classes_insert" ON classes
  FOR INSERT WITH CHECK (true);

-- Nobody can delete or update classes from client
DROP POLICY IF EXISTS "classes_no_update" ON classes;
CREATE POLICY "classes_no_update" ON classes
  FOR UPDATE USING (false);

DROP POLICY IF EXISTS "classes_no_delete" ON classes;
CREATE POLICY "classes_no_delete" ON classes
  FOR DELETE USING (false);
