-- ============================================
-- Quick Fix: Convert posts.id from UUID to TEXT
-- ============================================
-- Run this BEFORE running supabase_schema_fixed.sql
-- This converts your existing posts table to use TEXT id
-- ============================================

-- Step 1: Drop dependent tables (if they exist)
DROP TABLE IF EXISTS user_interactions CASCADE;

-- Step 2: Convert posts.id from UUID to TEXT
-- Add new TEXT column
ALTER TABLE posts ADD COLUMN IF NOT EXISTS id_text TEXT;

-- Copy UUID values as text (if you have data)
UPDATE posts SET id_text = id::text WHERE id_text IS NULL;

-- Drop old primary key constraint
ALTER TABLE posts DROP CONSTRAINT IF EXISTS posts_pkey CASCADE;

-- Drop old UUID column
ALTER TABLE posts DROP COLUMN IF EXISTS id;

-- Rename new column to id
ALTER TABLE posts RENAME COLUMN id_text TO id;

-- Add primary key back
ALTER TABLE posts ADD PRIMARY KEY (id);

-- Step 3: Now you can run supabase_schema_fixed.sql
-- It will create user_interactions with TEXT post_id that matches

-- ============================================
-- Verify the conversion
-- ============================================
-- Check that posts.id is now TEXT
SELECT 
  column_name, 
  data_type 
FROM information_schema.columns 
WHERE table_name = 'posts' AND column_name = 'id';
-- Should show: data_type = 'text'

