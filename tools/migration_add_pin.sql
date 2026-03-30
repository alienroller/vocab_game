-- ============================================================================
-- VocabGame — Account Recovery Migration
-- Run this in Supabase → SQL Editor AFTER the main schema
-- Adds pin_hash column for 6-digit PIN recovery
-- ============================================================================

-- Add pin_hash column to profiles
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS pin_hash text;

-- Add index for username + pin lookup (used during recovery)
CREATE INDEX IF NOT EXISTS idx_profiles_username ON profiles(username);
