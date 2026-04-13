-- ============================================================================
-- VocabGame — Assignment Progress Fix
-- Paste this into Supabase → SQL Editor → New Query → Run
-- Fixes corrupted assignment_progress rows where total_words was
-- incorrectly hardcoded to session lengths (e.g., 6 or 10 words).
-- ============================================================================

-- Recalculate true total_words and is_completed dynamically from assignments
UPDATE assignment_progress ap
SET 
  total_words = a.word_count,
  is_completed = (ap.words_mastered >= a.word_count)
FROM assignments a
WHERE ap.assignment_id = a.id;
