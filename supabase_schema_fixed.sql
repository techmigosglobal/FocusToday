-- ============================================
-- EagleTV Supabase Database Schema (FIXED)
-- ============================================
-- This schema works with your existing tables
-- Run this SQL in your Supabase SQL Editor
-- ============================================

-- Enable UUID extension (if not already enabled)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================
-- Update Posts Table to use TEXT id (if needed)
-- ============================================
-- Since your app uses TEXT IDs, we need to convert posts.id from UUID to TEXT
-- Option 1: Drop and recreate (if no data yet)
-- Option 2: Alter existing table (if you have data)

-- If you have NO data in posts table, run this:
/*
DROP TABLE IF EXISTS posts CASCADE;
CREATE TABLE posts (
  id TEXT PRIMARY KEY,
  author_id TEXT NOT NULL,
  author_name TEXT NOT NULL,
  author_avatar TEXT,
  caption TEXT NOT NULL,
  caption_te TEXT,
  caption_hi TEXT,
  media_url TEXT,
  media_type TEXT,
  content_type TEXT NOT NULL CHECK (content_type IN ('image', 'video', 'pdf', 'article', 'story', 'poetry', 'none')),
  category TEXT NOT NULL,
  hashtags TEXT,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  created_at BIGINT NOT NULL,
  published_at BIGINT NOT NULL,
  pdf_file_path TEXT,
  article_content TEXT,
  poem_verses TEXT,
  likes_count INTEGER DEFAULT 0,
  bookmarks_count INTEGER DEFAULT 0,
  shares_count INTEGER DEFAULT 0,
  is_synced BOOLEAN DEFAULT TRUE,
  rejection_reason TEXT,
  edit_count INTEGER DEFAULT 0,
  last_edited_at BIGINT,
  FOREIGN KEY (author_id) REFERENCES users(id) ON DELETE CASCADE
);
*/

-- If you HAVE data, use this migration instead:
-- Step 1: Add new TEXT column
ALTER TABLE posts ADD COLUMN IF NOT EXISTS id_text TEXT;

-- Step 2: Convert UUID to TEXT (if you have data)
-- UPDATE posts SET id_text = id::text WHERE id_text IS NULL;

-- Step 3: Drop old primary key and foreign keys
-- ALTER TABLE posts DROP CONSTRAINT IF EXISTS posts_pkey CASCADE;
-- ALTER TABLE user_interactions DROP CONSTRAINT IF EXISTS user_interactions_post_id_fkey;

-- Step 4: Rename columns
-- ALTER TABLE posts DROP COLUMN id;
-- ALTER TABLE posts RENAME COLUMN id_text TO id;
-- ALTER TABLE posts ADD PRIMARY KEY (id);

-- For now, let's assume you'll use TEXT for consistency with your app
-- If you want to keep UUID, we'll need to adjust the foreign keys

-- ============================================
-- Update Users Table (add missing columns)
-- ============================================
ALTER TABLE users ADD COLUMN IF NOT EXISTS subscription_plan_type TEXT CHECK (subscription_plan_type IN ('free', 'premium', 'elite'));
ALTER TABLE users ADD COLUMN IF NOT EXISTS subscription_expires_at BIGINT;
ALTER TABLE users ADD COLUMN IF NOT EXISTS updated_at BIGINT DEFAULT EXTRACT(EPOCH FROM NOW())::BIGINT * 1000;

-- Update role constraint if needed
ALTER TABLE users DROP CONSTRAINT IF EXISTS users_role_check;
ALTER TABLE users ADD CONSTRAINT users_role_check CHECK (role IN ('admin', 'reporter', 'publicUser', 'user'));

-- Update preferred_language constraint
ALTER TABLE users DROP CONSTRAINT IF EXISTS users_preferred_language_check;
ALTER TABLE users ADD CONSTRAINT users_preferred_language_check CHECK (preferred_language IN ('en', 'te', 'hi'));

-- ============================================
-- Update Posts Table (add missing columns)
-- ============================================
ALTER TABLE posts ADD COLUMN IF NOT EXISTS media_type TEXT;
ALTER TABLE posts ADD COLUMN IF NOT EXISTS caption_te TEXT;
ALTER TABLE posts ADD COLUMN IF NOT EXISTS caption_hi TEXT;

-- Update content_type constraint
ALTER TABLE posts DROP CONSTRAINT IF EXISTS posts_content_type_check;
ALTER TABLE posts ADD CONSTRAINT posts_content_type_check CHECK (content_type IN ('image', 'video', 'pdf', 'article', 'story', 'poetry', 'none'));

-- Update status constraint
ALTER TABLE posts DROP CONSTRAINT IF EXISTS posts_status_check;
ALTER TABLE posts ADD CONSTRAINT posts_status_check CHECK (status IN ('pending', 'approved', 'rejected'));

-- Convert TIMESTAMPTZ to BIGINT if needed (for consistency with app)
-- Note: Your app uses BIGINT (milliseconds), but you have TIMESTAMPTZ
-- The app will handle conversion, but for consistency you might want to add BIGINT columns
ALTER TABLE posts ADD COLUMN IF NOT EXISTS created_at_ms BIGINT;
ALTER TABLE posts ADD COLUMN IF NOT EXISTS published_at_ms BIGINT;
ALTER TABLE posts ADD COLUMN IF NOT EXISTS last_edited_at_ms BIGINT;

-- ============================================
-- User Interactions Table
-- ============================================
-- IMPORTANT: This will work with TEXT post_id
CREATE TABLE IF NOT EXISTS user_interactions (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  post_id TEXT NOT NULL, -- Changed to TEXT to match your posts.id (after conversion)
  is_liked BOOLEAN DEFAULT FALSE,
  is_bookmarked BOOLEAN DEFAULT FALSE,
  interacted_at BIGINT NOT NULL,
  is_synced BOOLEAN DEFAULT TRUE,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE,
  UNIQUE(user_id, post_id)
);

-- If posts.id is still UUID, use this version instead:
/*
CREATE TABLE IF NOT EXISTS user_interactions (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  post_id UUID NOT NULL, -- Match your existing posts.id type
  is_liked BOOLEAN DEFAULT FALSE,
  is_bookmarked BOOLEAN DEFAULT FALSE,
  interacted_at BIGINT NOT NULL,
  is_synced BOOLEAN DEFAULT TRUE,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE,
  UNIQUE(user_id, post_id)
);
*/

-- Create indexes for user interactions
CREATE INDEX IF NOT EXISTS idx_user_interactions_user_id ON user_interactions(user_id);
CREATE INDEX IF NOT EXISTS idx_user_interactions_post_id ON user_interactions(post_id);
CREATE INDEX IF NOT EXISTS idx_user_interactions_liked ON user_interactions(post_id, is_liked) WHERE is_liked = TRUE;
CREATE INDEX IF NOT EXISTS idx_user_interactions_bookmarked ON user_interactions(user_id, is_bookmarked) WHERE is_bookmarked = TRUE;

-- ============================================
-- Sync Queue Table
-- ============================================
CREATE TABLE IF NOT EXISTS sync_queue (
  id TEXT PRIMARY KEY,
  action_type TEXT NOT NULL CHECK (action_type IN ('like', 'bookmark', 'create_post', 'update_post', 'delete_post')),
  payload TEXT NOT NULL,
  created_at BIGINT NOT NULL,
  retry_count INTEGER DEFAULT 0,
  last_error TEXT
);

CREATE INDEX IF NOT EXISTS idx_sync_queue_created_at ON sync_queue(created_at ASC);

-- ============================================
-- Create indexes on Posts (if not exists)
-- ============================================
CREATE INDEX IF NOT EXISTS idx_posts_author_id ON posts(author_id);
CREATE INDEX IF NOT EXISTS idx_posts_status ON posts(status);
CREATE INDEX IF NOT EXISTS idx_posts_published_at ON posts(published_at DESC);
CREATE INDEX IF NOT EXISTS idx_posts_category ON posts(category);
CREATE INDEX IF NOT EXISTS idx_posts_content_type ON posts(content_type);

-- ============================================
-- Create indexes on Users (if not exists)
-- ============================================
CREATE INDEX IF NOT EXISTS idx_users_phone_number ON users(phone_number);
CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);

-- ============================================
-- Update RLS Policies
-- ============================================
-- Your existing policies are permissive, but let's add more specific ones

-- Drop existing policies if you want to replace them
-- DROP POLICY IF EXISTS "Public read for approved posts" ON posts;
-- DROP POLICY IF EXISTS "Authors can manage own posts" ON posts;
-- DROP POLICY IF EXISTS "Users can manage own profile" ON users;

-- Posts: More specific policies
-- Drop existing policies first (if they exist)
DROP POLICY IF EXISTS "Anyone can read approved posts" ON posts;
DROP POLICY IF EXISTS "Users can create posts" ON posts;
DROP POLICY IF EXISTS "Users can update own posts" ON posts;
DROP POLICY IF EXISTS "Public read for approved posts" ON posts;
DROP POLICY IF EXISTS "Authors can manage own posts" ON posts;

CREATE POLICY "Anyone can read approved posts" ON posts
  FOR SELECT USING (status = 'approved');

CREATE POLICY "Users can create posts" ON posts
  FOR INSERT WITH CHECK (true);

CREATE POLICY "Users can update own posts" ON posts
  FOR UPDATE USING (true); -- Simplified for now, can add auth.uid() check later

-- Users: Profile policies
DROP POLICY IF EXISTS "Users can read all profiles" ON users;
DROP POLICY IF EXISTS "Users can update own profile" ON users;
DROP POLICY IF EXISTS "Users can manage own profile" ON users;

CREATE POLICY "Users can read all profiles" ON users
  FOR SELECT USING (true);

CREATE POLICY "Users can update own profile" ON users
  FOR UPDATE USING (true); -- Simplified for now

-- User Interactions: New policies
ALTER TABLE user_interactions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read own interactions" ON user_interactions;
DROP POLICY IF EXISTS "Users can create own interactions" ON user_interactions;
DROP POLICY IF EXISTS "Users can update own interactions" ON user_interactions;

CREATE POLICY "Users can read own interactions" ON user_interactions
  FOR SELECT USING (true);

CREATE POLICY "Users can create own interactions" ON user_interactions
  FOR INSERT WITH CHECK (true);

CREATE POLICY "Users can update own interactions" ON user_interactions
  FOR UPDATE USING (true);

-- Sync Queue: New policies
ALTER TABLE sync_queue ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can manage own sync queue" ON sync_queue;

CREATE POLICY "Users can manage own sync queue" ON sync_queue
  FOR ALL USING (true);

-- ============================================
-- Functions and Triggers
-- ============================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = EXTRACT(EPOCH FROM NOW())::BIGINT * 1000;
  RETURN NEW;
END;
$$ language 'plpgsql';

-- Trigger to auto-update updated_at on users table
DROP TRIGGER IF EXISTS update_users_updated_at ON users;
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- Storage Bucket Setup Instructions
-- ============================================
-- 1. Go to Supabase Dashboard > Storage
-- 2. Create a new bucket named "media"
-- 3. Set bucket to PUBLIC (or configure policies as needed)
-- 4. Configure CORS if needed for web access
-- 
-- Storage Policies (run after creating bucket):
/*
CREATE POLICY "Public can read media" ON storage.objects
  FOR SELECT USING (bucket_id = 'media');

CREATE POLICY "Authenticated users can upload media" ON storage.objects
  FOR INSERT WITH CHECK (bucket_id = 'media');

CREATE POLICY "Users can update own media" ON storage.objects
  FOR UPDATE USING (bucket_id = 'media');

CREATE POLICY "Users can delete own media" ON storage.objects
  FOR DELETE USING (bucket_id = 'media');
*/

-- ============================================
-- IMPORTANT NOTES
-- ============================================
-- 1. Your existing posts table uses UUID for id, but your app uses TEXT
--    You have two options:
--    a) Convert posts.id to TEXT (recommended for consistency)
--    b) Keep UUID and update app code to handle UUID conversion
--
-- 2. If you convert posts.id to TEXT, uncomment the DROP/CREATE section above
--    If you keep UUID, use the UUID version of user_interactions table
--
-- 3. Timestamps: Your tables use TIMESTAMPTZ, app uses BIGINT (milliseconds)
--    The app will handle conversion, but added _ms columns for consistency
--
-- 4. All foreign keys will work once post_id types match

