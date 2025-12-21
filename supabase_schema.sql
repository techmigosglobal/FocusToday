-- ============================================
-- EagleTV Supabase Database Schema
-- ============================================
-- Run this SQL in your Supabase SQL Editor to create the required tables
-- ============================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================
-- Users Table
-- ============================================
CREATE TABLE IF NOT EXISTS users (
  id TEXT PRIMARY KEY,
  phone_number TEXT UNIQUE NOT NULL,
  display_name TEXT NOT NULL,
  profile_picture TEXT,
  bio TEXT,
  role TEXT NOT NULL CHECK (role IN ('admin', 'reporter', 'publicUser')),
  is_subscribed BOOLEAN DEFAULT FALSE,
  preferred_language TEXT DEFAULT 'en' CHECK (preferred_language IN ('en', 'te', 'hi')),
  subscription_plan_type TEXT CHECK (subscription_plan_type IN ('free', 'premium', 'elite')),
  subscription_expires_at BIGINT,
  created_at BIGINT NOT NULL,
  updated_at BIGINT DEFAULT EXTRACT(EPOCH FROM NOW())::BIGINT * 1000
);

-- Create index on phone_number for faster lookups
CREATE INDEX IF NOT EXISTS idx_users_phone_number ON users(phone_number);

-- Create index on role for filtering
CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);

-- ============================================
-- Posts Table
-- ============================================
CREATE TABLE IF NOT EXISTS posts (
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
  hashtags TEXT, -- Comma-separated list
  status TEXT DEFAULT 'approved' CHECK (status IN ('pending', 'approved', 'rejected')),
  created_at BIGINT NOT NULL,
  published_at BIGINT NOT NULL,
  pdf_file_path TEXT,
  article_content TEXT,
  poem_verses TEXT, -- JSON or special separator format
  likes_count INTEGER DEFAULT 0,
  bookmarks_count INTEGER DEFAULT 0,
  shares_count INTEGER DEFAULT 0,
  is_synced BOOLEAN DEFAULT TRUE,
  rejection_reason TEXT,
  edit_count INTEGER DEFAULT 0,
  last_edited_at BIGINT,
  FOREIGN KEY (author_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_posts_author_id ON posts(author_id);
CREATE INDEX IF NOT EXISTS idx_posts_status ON posts(status);
CREATE INDEX IF NOT EXISTS idx_posts_published_at ON posts(published_at DESC);
CREATE INDEX IF NOT EXISTS idx_posts_category ON posts(category);
CREATE INDEX IF NOT EXISTS idx_posts_content_type ON posts(content_type);

-- ============================================
-- User Interactions Table
-- ============================================
CREATE TABLE IF NOT EXISTS user_interactions (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  post_id TEXT NOT NULL,
  is_liked BOOLEAN DEFAULT FALSE,
  is_bookmarked BOOLEAN DEFAULT FALSE,
  interacted_at BIGINT NOT NULL,
  is_synced BOOLEAN DEFAULT TRUE,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE,
  UNIQUE(user_id, post_id) -- One interaction per user per post
);

-- Create indexes for user interactions
CREATE INDEX IF NOT EXISTS idx_user_interactions_user_id ON user_interactions(user_id);
CREATE INDEX IF NOT EXISTS idx_user_interactions_post_id ON user_interactions(post_id);
CREATE INDEX IF NOT EXISTS idx_user_interactions_liked ON user_interactions(post_id, is_liked) WHERE is_liked = TRUE;
CREATE INDEX IF NOT EXISTS idx_user_interactions_bookmarked ON user_interactions(user_id, is_bookmarked) WHERE is_bookmarked = TRUE;

-- ============================================
-- Sync Queue Table (for offline sync)
-- ============================================
CREATE TABLE IF NOT EXISTS sync_queue (
  id TEXT PRIMARY KEY,
  action_type TEXT NOT NULL CHECK (action_type IN ('like', 'bookmark', 'create_post', 'update_post', 'delete_post')),
  payload TEXT NOT NULL, -- JSON data
  created_at BIGINT NOT NULL,
  retry_count INTEGER DEFAULT 0,
  last_error TEXT
);

-- Create index for sync queue processing
CREATE INDEX IF NOT EXISTS idx_sync_queue_created_at ON sync_queue(created_at ASC);

-- ============================================
-- Row Level Security (RLS) Policies
-- ============================================
-- Enable RLS on all tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_interactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE sync_queue ENABLE ROW LEVEL SECURITY;

-- Users: Allow read access to all authenticated users, write access to own record
CREATE POLICY "Users can read all profiles" ON users
  FOR SELECT USING (true);

CREATE POLICY "Users can update own profile" ON users
  FOR UPDATE USING (auth.uid()::text = id);

-- Posts: Allow read access to approved posts, write access to own posts
CREATE POLICY "Anyone can read approved posts" ON posts
  FOR SELECT USING (status = 'approved');

CREATE POLICY "Users can create posts" ON posts
  FOR INSERT WITH CHECK (true);

CREATE POLICY "Users can update own posts" ON posts
  FOR UPDATE USING (auth.uid()::text = author_id);

-- User Interactions: Users can manage their own interactions
CREATE POLICY "Users can read own interactions" ON user_interactions
  FOR SELECT USING (auth.uid()::text = user_id);

CREATE POLICY "Users can create own interactions" ON user_interactions
  FOR INSERT WITH CHECK (auth.uid()::text = user_id);

CREATE POLICY "Users can update own interactions" ON user_interactions
  FOR UPDATE USING (auth.uid()::text = user_id);

-- Sync Queue: Users can manage their own sync queue items
CREATE POLICY "Users can manage own sync queue" ON sync_queue
  FOR ALL USING (true); -- Adjust based on your auth setup

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
-- CREATE POLICY "Public can read media" ON storage.objects
--   FOR SELECT USING (bucket_id = 'media');
-- 
-- CREATE POLICY "Authenticated users can upload media" ON storage.objects
--   FOR INSERT WITH CHECK (bucket_id = 'media' AND auth.role() = 'authenticated');
-- 
-- CREATE POLICY "Users can update own media" ON storage.objects
--   FOR UPDATE USING (bucket_id = 'media' AND auth.uid()::text = (storage.foldername(name))[1]);
-- 
-- CREATE POLICY "Users can delete own media" ON storage.objects
--   FOR DELETE USING (bucket_id = 'media' AND auth.uid()::text = (storage.foldername(name))[1]);

-- ============================================
-- Notes
-- ============================================
-- 1. All timestamp fields use BIGINT (milliseconds since epoch)
-- 2. Foreign keys have ON DELETE CASCADE for data integrity
-- 3. RLS policies can be adjusted based on your authentication setup
-- 4. If using Firebase Auth, you may need to adjust RLS policies to work with Firebase UIDs
-- 5. Storage bucket "media" should be created manually in Supabase Dashboard

