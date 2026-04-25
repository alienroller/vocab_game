-- ============================================================================
-- VocabGame — Complete Supabase Schema
-- Run this in: Supabase → SQL Editor → New Query
-- Run blocks in order. Do not skip any section.
-- ============================================================================

-- ─── 1. PROFILES ────────────────────────────────────────────────────────────
CREATE TABLE profiles (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  username text UNIQUE NOT NULL,
  xp integer DEFAULT 0 NOT NULL,
  level integer DEFAULT 1 NOT NULL,
  streak_days integer DEFAULT 0 NOT NULL,
  longest_streak integer DEFAULT 0 NOT NULL,
  last_played_date date,
  class_code text,
  week_xp integer DEFAULT 0 NOT NULL,
  total_words_answered integer DEFAULT 0 NOT NULL,
  total_correct integer DEFAULT 0 NOT NULL,
  created_at timestamptz DEFAULT now() NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL
);

-- ─── 2. CLASSES ─────────────────────────────────────────────────────────────
CREATE TABLE classes (
  code text PRIMARY KEY,
  teacher_username text NOT NULL,
  class_name text NOT NULL,
  assigned_unit_id uuid,
  assigned_unit_title text,
  assignment_expires_at date,
  created_at timestamptz DEFAULT now() NOT NULL
);

-- ─── 3. COLLECTIONS ────────────────────────────────────────────────────────
CREATE TABLE collections (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  title text NOT NULL,
  short_title text NOT NULL,
  description text,
  category text NOT NULL
    CHECK (category IN ('fiction', 'esl', 'academic')),
  difficulty text NOT NULL
    CHECK (difficulty IN ('A1', 'A2', 'B1', 'B2')),
  cover_emoji text DEFAULT '📚',
  cover_color text DEFAULT '#4F46E5',
  total_units integer DEFAULT 0,
  is_published boolean DEFAULT false,
  created_at timestamptz DEFAULT now() NOT NULL
);

-- ─── 4. UNITS ───────────────────────────────────────────────────────────────
CREATE TABLE units (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  collection_id uuid REFERENCES collections(id) ON DELETE CASCADE NOT NULL,
  title text NOT NULL,
  unit_number integer NOT NULL,
  word_count integer DEFAULT 0,
  created_at timestamptz DEFAULT now() NOT NULL,
  UNIQUE(collection_id, unit_number)
);

-- ─── 5. WORDS ───────────────────────────────────────────────────────────────
CREATE TABLE words (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  unit_id uuid REFERENCES units(id) ON DELETE CASCADE NOT NULL,
  collection_id uuid REFERENCES collections(id) ON DELETE CASCADE NOT NULL,
  word text NOT NULL,
  translation text NOT NULL,
  example_sentence text NOT NULL,
  word_type text NOT NULL
    CHECK (word_type IN ('noun', 'verb', 'adjective', 'adverb', 'phrase')),
  difficulty text NOT NULL
    CHECK (difficulty IN ('A1', 'A2', 'B1', 'B2')),
  word_number integer NOT NULL,
  created_at timestamptz DEFAULT now() NOT NULL,
  UNIQUE(unit_id, word_number)
);

-- ─── 6. WORD MASTERY ────────────────────────────────────────────────────────
CREATE TABLE word_mastery (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  profile_id uuid REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  word_id uuid REFERENCES words(id) ON DELETE CASCADE NOT NULL,
  seen_count integer DEFAULT 0 NOT NULL,
  correct_count integer DEFAULT 0 NOT NULL,
  correct_days integer DEFAULT 0 NOT NULL,
  last_seen_date date,
  last_correct_date date,
  is_mastered boolean DEFAULT false NOT NULL,
  created_at timestamptz DEFAULT now() NOT NULL,
  UNIQUE(profile_id, word_id)
);

-- ─── 7. DUELS ───────────────────────────────────────────────────────────────
CREATE TABLE duels (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  challenger_id uuid REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  opponent_id uuid REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  challenger_username text NOT NULL,
  opponent_username text NOT NULL,
  challenger_score integer DEFAULT 0,
  opponent_score integer DEFAULT 0,
  challenger_xp_gain integer DEFAULT 0,
  opponent_xp_gain integer DEFAULT 0,
  status text DEFAULT 'pending' CHECK (status IN ('pending','active','settling','finished','declined')),
  word_set jsonb NOT NULL,
  winner_id uuid REFERENCES profiles(id),
  started_at timestamptz,
  settling_at timestamptz,
  finished_at timestamptz,
  challenger_done boolean DEFAULT false NOT NULL,
  opponent_done boolean DEFAULT false NOT NULL,
  created_at timestamptz DEFAULT now() NOT NULL
);

-- ─── 8. HALL OF FAME ────────────────────────────────────────────────────────
CREATE TABLE hall_of_fame (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  profile_id uuid REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  username text NOT NULL,
  rank integer NOT NULL CHECK (rank IN (1, 2, 3)),
  week_xp integer NOT NULL,
  period_label text NOT NULL,
  awarded_at timestamptz DEFAULT now() NOT NULL
);

-- ─── 9. INDEXES ─────────────────────────────────────────────────────────────
CREATE INDEX idx_profiles_xp ON profiles(xp DESC);
CREATE INDEX idx_profiles_week_xp ON profiles(week_xp DESC);
CREATE INDEX idx_profiles_class_code ON profiles(class_code);
CREATE INDEX idx_duels_challenger ON duels(challenger_id);
CREATE INDEX idx_duels_opponent ON duels(opponent_id);
CREATE INDEX idx_duels_status ON duels(status);
CREATE INDEX idx_words_unit_id ON words(unit_id);
CREATE INDEX idx_words_collection_id ON words(collection_id);
CREATE INDEX idx_word_mastery_profile ON word_mastery(profile_id);
CREATE INDEX idx_word_mastery_word ON word_mastery(word_id);
CREATE INDEX idx_word_mastery_mastered ON word_mastery(profile_id, is_mastered);
CREATE INDEX idx_units_collection ON units(collection_id, unit_number);

-- ─── 10. TRIGGERS ───────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION update_unit_word_count()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE units SET word_count = word_count + 1 WHERE id = NEW.unit_id;
    UPDATE collections SET total_units = (
      SELECT COUNT(*) FROM units WHERE collection_id = NEW.collection_id
    ) WHERE id = NEW.collection_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE units SET word_count = word_count - 1 WHERE id = OLD.unit_id;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER words_count_trigger
AFTER INSERT OR DELETE ON words
FOR EACH ROW EXECUTE FUNCTION update_unit_word_count();

-- ─── 11. INCREMENT XP FUNCTION (for duel XP awards) ────────────────────────
CREATE OR REPLACE FUNCTION increment_xp(profile_id uuid, amount integer)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  UPDATE profiles
  SET
    xp = xp + amount,
    week_xp = week_xp + amount,
    level = GREATEST(1, FLOOR(SQRT((xp + amount) / 50.0))::integer + 1)
  WHERE id = profile_id;
END;
$$;

-- ─── 11b. INSTANT DUEL FINISH ──────────────────────────────────────────────
-- See supabase/migrations/009_finish_duel_instant.sql. The first call ends
-- the duel using the caller's authoritative final score and the opponent's
-- current DB score (which may be partial — the race to finish is the duel).
-- Late callers get the cached result back so they can still navigate to
-- results. Any failure rolls the whole transaction back automatically.
CREATE OR REPLACE FUNCTION finish_duel(
  p_duel_id uuid,
  p_is_challenger boolean,
  p_my_final_score integer
) RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE
  v_row duels%ROWTYPE;
  v_winner_id uuid;
  v_challenger_xp integer;
  v_opponent_xp integer;
BEGIN
  SELECT * INTO v_row FROM duels WHERE id = p_duel_id FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('status','error','reason','duel_not_found');
  END IF;

  IF v_row.status = 'finished' THEN
    RETURN jsonb_build_object(
      'status','finished',
      'challenger_score', v_row.challenger_score,
      'opponent_score', v_row.opponent_score,
      'winner_id', v_row.winner_id,
      'challenger_xp', v_row.challenger_xp_gain,
      'opponent_xp', v_row.opponent_xp_gain,
      'challenger_username', v_row.challenger_username,
      'opponent_username', v_row.opponent_username
    );
  END IF;

  IF v_row.status NOT IN ('active','settling') THEN
    RETURN jsonb_build_object('status','error','reason', v_row.status);
  END IF;

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
    'status','finished',
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

-- Force-finish for the 30s timeout fallback when an opponent disconnects.
CREATE OR REPLACE FUNCTION force_finish_duel(p_duel_id uuid)
RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE
  v_row duels%ROWTYPE;
  v_winner_id uuid;
  v_challenger_xp integer;
  v_opponent_xp integer;
BEGIN
  SELECT * INTO v_row FROM duels WHERE id = p_duel_id FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('status','error','reason','duel_not_found');
  END IF;

  IF v_row.status = 'finished' THEN
    RETURN jsonb_build_object(
      'status','finished',
      'challenger_score', v_row.challenger_score,
      'opponent_score', v_row.opponent_score,
      'winner_id', v_row.winner_id,
      'challenger_xp', v_row.challenger_xp_gain,
      'opponent_xp', v_row.opponent_xp_gain,
      'challenger_username', v_row.challenger_username,
      'opponent_username', v_row.opponent_username
    );
  END IF;

  IF v_row.status NOT IN ('active','settling') THEN
    RETURN jsonb_build_object('status','error','reason', v_row.status);
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
    'status','finished',
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

-- ─── 12. REALTIME ───────────────────────────────────────────────────────────
ALTER TABLE profiles REPLICA IDENTITY FULL;
ALTER TABLE duels REPLICA IDENTITY FULL;

-- ─── 13. ROW LEVEL SECURITY ────────────────────────────────────────────────
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE classes ENABLE ROW LEVEL SECURITY;
ALTER TABLE collections ENABLE ROW LEVEL SECURITY;
ALTER TABLE units ENABLE ROW LEVEL SECURITY;
ALTER TABLE words ENABLE ROW LEVEL SECURITY;
ALTER TABLE word_mastery ENABLE ROW LEVEL SECURITY;
ALTER TABLE duels ENABLE ROW LEVEL SECURITY;
ALTER TABLE hall_of_fame ENABLE ROW LEVEL SECURITY;

-- Profiles: anyone can read, open write for classroom use
CREATE POLICY "profiles_read" ON profiles FOR SELECT USING (true);
CREATE POLICY "profiles_insert" ON profiles FOR INSERT WITH CHECK (true);
CREATE POLICY "profiles_update" ON profiles FOR UPDATE USING (true);

-- Classes: read for all, insert for teachers
CREATE POLICY "classes_read" ON classes FOR SELECT USING (true);
CREATE POLICY "classes_insert" ON classes FOR INSERT WITH CHECK (true);

-- Content tables: read-only for published content
CREATE POLICY "collections_read" ON collections FOR SELECT USING (is_published = true);
CREATE POLICY "units_read" ON units FOR SELECT USING (true);
CREATE POLICY "words_read" ON words FOR SELECT USING (true);

-- Word mastery: open for classroom use
CREATE POLICY "mastery_read" ON word_mastery FOR SELECT USING (true);
CREATE POLICY "mastery_insert" ON word_mastery FOR INSERT WITH CHECK (true);
CREATE POLICY "mastery_update" ON word_mastery FOR UPDATE USING (true);

-- Duels: open
CREATE POLICY "duels_read" ON duels FOR SELECT USING (true);
CREATE POLICY "duels_insert" ON duels FOR INSERT WITH CHECK (true);
CREATE POLICY "duels_update" ON duels FOR UPDATE USING (true);

-- Hall of fame: read only
CREATE POLICY "fame_read" ON hall_of_fame FOR SELECT USING (true);

-- ─── 14. WEEKLY RESET CRON JOB ─────────────────────────────────────────────
-- Enable pg_cron first: Supabase → Database → Extensions → pg_cron → Enable

CREATE EXTENSION IF NOT EXISTS pg_cron;

CREATE OR REPLACE FUNCTION award_weekly_hall_of_fame()
RETURNS void LANGUAGE plpgsql AS $$
DECLARE
  period_label text;
  rec record;
  rank_num integer := 1;
BEGIN
  period_label := to_char(now(), 'Month YYYY') || ' — Week ' || to_char(now(), 'IW');

  FOR rec IN
    SELECT id, username, week_xp
    FROM profiles
    WHERE week_xp > 0
    ORDER BY week_xp DESC
    LIMIT 3
  LOOP
    INSERT INTO hall_of_fame (profile_id, username, rank, week_xp, period_label)
    VALUES (rec.id, rec.username, rank_num, rec.week_xp, period_label);
    rank_num := rank_num + 1;
  END LOOP;

  UPDATE profiles SET week_xp = 0;
END;
$$;

-- Schedule every Monday at 00:01 UTC
SELECT cron.schedule(
  'weekly-reset',
  '1 0 * * 1',
  'SELECT award_weekly_hall_of_fame();'
);
