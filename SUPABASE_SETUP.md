# Supabase Setup Guide for EagleTV

This guide will help you set up Supabase database and storage for EagleTV.

## Prerequisites

1. A Supabase account (sign up at https://supabase.com)
2. A new Supabase project created

## Step 1: Database Setup

1. Open your Supabase project dashboard
2. Navigate to **SQL Editor**
3. Open the file `supabase_schema.sql` from this project
4. Copy and paste the entire SQL script into the SQL Editor
5. Click **Run** to execute the script

This will create:
- `users` table
- `posts` table
- `user_interactions` table
- `sync_queue` table
- All necessary indexes
- Row Level Security (RLS) policies

## Step 2: Storage Bucket Setup

1. Navigate to **Storage** in your Supabase dashboard
2. Click **New bucket**
3. Name the bucket: `media`
4. Set it to **Public bucket** (or configure policies as needed)
5. Click **Create bucket**

### Storage Policies (Optional - for fine-grained access control)

After creating the bucket, you can run these policies in SQL Editor:

```sql
-- Allow public read access
CREATE POLICY "Public can read media" ON storage.objects
  FOR SELECT USING (bucket_id = 'media');

-- Allow authenticated users to upload
CREATE POLICY "Authenticated users can upload media" ON storage.objects
  FOR INSERT WITH CHECK (bucket_id = 'media' AND auth.role() = 'authenticated');

-- Allow users to update their own media
CREATE POLICY "Users can update own media" ON storage.objects
  FOR UPDATE USING (bucket_id = 'media');

-- Allow users to delete their own media
CREATE POLICY "Users can delete own media" ON storage.objects
  FOR DELETE USING (bucket_id = 'media');
```

## Step 3: Get Your Supabase Credentials

1. Navigate to **Settings** > **API** in your Supabase dashboard
2. Copy the following:
   - **Project URL** (e.g., `https://xxxxx.supabase.co`)
   - **anon/public key** (the `anon` key, not the `service_role` key)

## Step 4: Update App Configuration

The app is already configured with Supabase credentials in `lib/main.dart`. If you need to update them:

```dart
await Supabase.initialize(
  url: 'YOUR_PROJECT_URL',
  anonKey: 'YOUR_ANON_KEY',
);
```

## Step 5: Verify Setup

1. Check that all tables are created in **Table Editor**
2. Verify the `media` bucket exists in **Storage**
3. Test by creating a user and post through the app

## Troubleshooting

### RLS Policy Issues

If you encounter permission errors, you may need to adjust Row Level Security policies based on your authentication setup. Since EagleTV uses Firebase Auth, you might need to:

1. Disable RLS temporarily for testing, OR
2. Create a custom authentication function that maps Firebase UIDs to Supabase users

### Storage Upload Issues

- Ensure the bucket is set to **Public** if you want public access
- Check CORS settings if uploading from web
- Verify storage policies allow the operations you need

### Connection Issues

- Verify your Supabase URL and anon key are correct
- Check that your project is active (not paused)
- Ensure your network allows connections to Supabase

## Additional Notes

- The schema uses BIGINT for timestamps (milliseconds since epoch)
- Foreign keys have CASCADE delete for data integrity
- Indexes are created for optimal query performance
- The sync_queue table is for offline-first functionality

