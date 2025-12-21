# Migration Guide: Fixing Foreign Key Type Mismatch

## Problem
You're getting this error:
```
ERROR: 42804: foreign key constraint "user_interactions_post_id_fkey" cannot be implemented
DETAIL: Key columns "post_id" and "id" are of incompatible types: text and uuid.
```

This happens because:
- Your existing `posts.id` is **UUID**
- The schema tries to create `user_interactions.post_id` as **TEXT**
- Foreign keys require matching types

## Solution Options

### Option 1: Convert Posts ID to TEXT (Recommended)

This matches your app's expectations (app uses TEXT/String for IDs).

#### Step 1: Drop dependent tables first
```sql
DROP TABLE IF EXISTS user_interactions CASCADE;
-- Drop any other tables that reference posts.id
```

#### Step 2: Convert posts.id from UUID to TEXT
```sql
-- Add new TEXT column
ALTER TABLE posts ADD COLUMN id_text TEXT;

-- Copy UUID values as text
UPDATE posts SET id_text = id::text;

-- Drop old constraints
ALTER TABLE posts DROP CONSTRAINT posts_pkey CASCADE;

-- Drop old UUID column
ALTER TABLE posts DROP COLUMN id;

-- Rename new column
ALTER TABLE posts RENAME COLUMN id_text TO id;

-- Add primary key
ALTER TABLE posts ADD PRIMARY KEY (id);
```

#### Step 3: Run the fixed schema
Now run `supabase_schema_fixed.sql` which will create `user_interactions` with TEXT post_id.

---

### Option 2: Keep UUID and Update Foreign Keys

If you want to keep UUID for posts.id, update the schema to use UUID for post_id.

#### Step 1: Create user_interactions with UUID post_id
```sql
CREATE TABLE IF NOT EXISTS user_interactions (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  post_id UUID NOT NULL,  -- Match your posts.id type
  is_liked BOOLEAN DEFAULT FALSE,
  is_bookmarked BOOLEAN DEFAULT FALSE,
  interacted_at BIGINT NOT NULL,
  is_synced BOOLEAN DEFAULT TRUE,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE,
  UNIQUE(user_id, post_id)
);
```

#### Step 2: Update your app code
You'll need to convert between UUID and String in your app:
- When creating posts: Generate UUID, store as String
- When querying: Convert String to UUID for database queries

---

## Recommended Approach: Option 1 (TEXT IDs)

Since your Flutter app uses String/TEXT for IDs throughout, converting to TEXT is cleaner.

### Complete Migration Script

```sql
-- ============================================
-- Complete Migration: UUID to TEXT for posts.id
-- ============================================

-- Step 1: Drop dependent objects
DROP TABLE IF EXISTS user_interactions CASCADE;

-- Step 2: Convert posts.id
ALTER TABLE posts ADD COLUMN id_text TEXT;
UPDATE posts SET id_text = id::text;
ALTER TABLE posts DROP CONSTRAINT posts_pkey CASCADE;
ALTER TABLE posts DROP COLUMN id;
ALTER TABLE posts RENAME COLUMN id_text TO id;
ALTER TABLE posts ADD PRIMARY KEY (id);

-- Step 3: Now run supabase_schema_fixed.sql
-- This will create user_interactions with matching TEXT types
```

---

## After Migration

1. **Verify Foreign Keys**:
```sql
SELECT 
  tc.constraint_name, 
  tc.table_name, 
  kcu.column_name,
  ccu.table_name AS foreign_table_name,
  ccu.column_name AS foreign_column_name 
FROM information_schema.table_constraints AS tc 
JOIN information_schema.key_column_usage AS kcu
  ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage AS ccu
  ON ccu.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY';
```

2. **Test Data Insertion**:
```sql
-- Test user_interactions creation
INSERT INTO user_interactions (id, user_id, post_id, is_liked, interacted_at)
VALUES ('test_1', 'user_123', (SELECT id FROM posts LIMIT 1), true, EXTRACT(EPOCH FROM NOW())::BIGINT * 1000);
```

3. **Update App Code** (if needed):
   - If you kept UUID, update PostRepository to handle UUID conversion
   - If you converted to TEXT, no changes needed (app already uses String)

---

## Quick Fix (If You Have No Data Yet)

If your `posts` table is empty, simply:

```sql
DROP TABLE posts CASCADE;
-- Then run supabase_schema_fixed.sql
```

This is the cleanest approach if you're just setting up.

---

## Need Help?

If you're unsure which approach to take:
- **No data yet?** → Use Quick Fix (drop and recreate)
- **Have data?** → Use Option 1 (convert UUID to TEXT)
- **Want to keep UUID?** → Use Option 2 (update app code)

The recommended path is **Option 1** for consistency with your Flutter app.

