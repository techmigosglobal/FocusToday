-- ============================================
-- Supabase Storage Policies for 'media' Bucket
-- ============================================
-- Run this AFTER creating the 'media' bucket in Supabase Dashboard
-- ============================================

-- Allow public read access to media files
CREATE POLICY "Public can read media" ON storage.objects
  FOR SELECT USING (bucket_id = 'media');

-- Allow authenticated users to upload media
CREATE POLICY "Authenticated users can upload media" ON storage.objects
  FOR INSERT WITH CHECK (bucket_id = 'media');

-- Allow users to update their own media files
CREATE POLICY "Users can update own media" ON storage.objects
  FOR UPDATE USING (bucket_id = 'media');

-- Allow users to delete their own media files
CREATE POLICY "Users can delete own media" ON storage.objects
  FOR DELETE USING (bucket_id = 'media');

-- ============================================
-- Notes
-- ============================================
-- 1. These policies are permissive for easier testing
-- 2. You can tighten them later based on your auth setup
-- 3. For Firebase Auth, you may need to adjust the policies
-- 4. The bucket must be created first in Supabase Dashboard > Storage

