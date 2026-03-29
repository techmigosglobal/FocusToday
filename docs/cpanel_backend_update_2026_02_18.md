# cPanel Backend Update (2026-02-18)

## 1) Apply database update first
Run this SQL in phpMyAdmin (or MySQL CLI) for your production DB:

- `backend_nestjs/sql/2026_02_18_post_scores_and_indexes.sql`

This adds:
- `posts.discover_score`
- `posts.trend_score`
- performance indexes for `status/category/content_type` and score-based ordering
- one-time score backfill for existing posts

## 2) Optional but recommended: periodic score decay refresh
Create a cPanel Cron Job (every 30 minutes) and run:

```bash
mysql -u "$DB_USERNAME" -p"$DB_PASSWORD" "$DB_DATABASE" -e "
UPDATE posts
SET
  discover_score = ROUND(((COALESCE(likes_count, 0) * 3 + COALESCE(bookmarks_count, 0) * 2 + COALESCE(shares_count, 0) * 4) / (TIMESTAMPDIFF(HOUR, created_at, NOW()) + 2)), 4),
  trend_score = ROUND(((COALESCE(likes_count, 0) * 3 + COALESCE(bookmarks_count, 0) * 2 + COALESCE(shares_count, 0) * 5) / (TIMESTAMPDIFF(HOUR, created_at, NOW()) + 2)), 4);
"
```

Use real DB credentials from your server `.env`.

## 3) Deploy updated NestJS package
From project root:

```bash
./deploy_nestjs_cpanel.sh
```

Upload generated zip:
- `crii_backend_nestjs_deploy.zip`

Then deploy using your normal cPanel process (Node.js app restart required).

## 4) Post-deploy verification
1. Open feed endpoint and confirm faster response:
   - `GET /api/v1/posts/feed`
2. Confirm discover/trending still return sorted content:
   - `GET /api/v1/posts/discover`
   - `GET /api/v1/posts/trending`
3. Like/share a post and verify score columns update:
   - `SELECT id, discover_score, trend_score FROM posts ORDER BY created_at DESC LIMIT 5;`
