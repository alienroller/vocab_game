-- ============================================================================
-- Fix doubled word_count in units table
-- 
-- PROBLEM: The seed scripts inserted units with a pre-calculated word_count,
--          but the DB trigger (update_unit_word_count) ALSO incremented
--          word_count by 1 for each word inserted. This caused word_count
--          to be approximately 2x the real count.
--
-- SOLUTION: Recalculate word_count from the actual number of words rows.
-- ============================================================================

-- Recalculate every unit's word_count from the actual words table
UPDATE units
SET word_count = (
    SELECT COUNT(*)
    FROM words
    WHERE words.unit_id = units.id
);

-- Verify the fix (optional — paste into SQL Editor to inspect)
-- SELECT u.id, u.title, u.word_count, 
--        (SELECT COUNT(*) FROM words w WHERE w.unit_id = u.id) AS actual_count
-- FROM units u
-- ORDER BY u.collection_id, u.unit_number;
