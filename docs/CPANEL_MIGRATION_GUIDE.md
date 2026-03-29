# EagleTV Backend — cPanel Migration Guide

> Migrate the local XAMPP backend to **https://www.techmigos.com/eagletv/backend** on a cPanel shared hosting environment.

---

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [cPanel Directory Structure](#2-cpanel-directory-structure)
3. [Step 1 — Create MySQL Database](#3-step-1--create-mysql-database)
4. [Step 2 — Import Database Schema](#4-step-2--import-database-schema)
5. [Step 3 — Upload Backend Files](#5-step-3--upload-backend-files)
6. [Step 4 — Update config.php](#6-step-4--update-configphp)
7. [Step 5 — .htaccess Security & Routing](#7-step-5--htaccess-security--routing)
8. [Step 6 — File Permissions](#8-step-6--file-permissions)
9. [Step 7 — SSL / HTTPS Configuration](#9-step-7--ssl--https-configuration)
10. [Step 8 — Update Flutter App API Base URL](#10-step-8--update-flutter-app-api-base-url)
11. [Step 9 — Firebase Push Notifications](#11-step-9--firebase-push-notifications)
12. [Step 10 — Testing Checklist](#12-step-10--testing-checklist)
13. [Troubleshooting](#13-troubleshooting)
14. [Complete API Reference](#14-complete-api-reference)
15. [Database Schema Reference](#15-database-schema-reference)
16. [Security Hardening Checklist](#16-security-hardening-checklist)
17. [Backup & Maintenance](#17-backup--maintenance)

---

## 1. Prerequisites

| Requirement | Details |
|---|---|
| **cPanel Hosting** | Shared or VPS hosting with cPanel access |
| **PHP Version** | PHP 8.0+ (8.1 or 8.2 recommended) |
| **PHP Extensions** | `pdo_mysql`, `json`, `mbstring`, `openssl`, `fileinfo`, `curl` |
| **MySQL** | MySQL 5.7+ or MariaDB 10.3+ |
| **SSL Certificate** | Let's Encrypt (free via cPanel) or purchased SSL |
| **Domain** | `www.techmigos.com` pointing to the hosting server |
| **Disk Space** | Minimum 2 GB (for uploads: images, videos, PDFs) |
| **Firebase Project** | `eagle-tv-crii` — service account JSON key file ready |

### Verify PHP Extensions on cPanel

1. Go to **cPanel → Software → Select PHP Version**
2. Ensure these extensions are **checked/enabled**:
   - `pdo_mysql`
   - `json`
   - `mbstring`
   - `openssl`
   - `fileinfo`
   - `curl`
3. Set PHP version to **8.1** or **8.2**

---

## 2. cPanel Directory Structure

On cPanel, the public web root is typically:

```
/home/<cpanel_user>/public_html/
```

The EagleTV backend will be at:

```
/home/<cpanel_user>/public_html/eagletv/backend/
```

This maps to the URL: `https://www.techmigos.com/eagletv/backend/`

### Target Structure on cPanel

```
public_html/
└── eagletv/
    └── backend/
        ├── config.php                 ← DB credentials & settings
        ├── index.php                  ← Router / API entry point
        ├── share.php                  ← Shareable post web page
        ├── firebase_service_account.json  ← FCM push auth (PROTECT!)
        ├── .htaccess                  ← Security & routing rules
        ├── api/
        │   ├── comments.php
        │   ├── follows.php
        │   ├── interactions.php
        │   ├── notifications.php
        │   ├── posts.php
        │   ├── reports.php
        │   ├── send_push.php
        │   ├── storage.php
        │   ├── upload.php
        │   └── users.php
        └── uploads/
            ├── posts/                ← Uploaded media files
            └── profiles/             ← Profile pictures
```

> **Note:** SQL migration files (`setup.sql`, `migrate_v2.sql`, etc.) are only needed locally for DB creation. Do NOT upload them to production.

---

## 3. Step 1 — Create MySQL Database

### Via cPanel → MySQL Databases

1. Go to **cPanel → Databases → MySQL Databases**
2. Create a new database:
   - Database Name: `techmigo_eagletv_db`  
     *(cPanel prefixes your account name, e.g. `techmigo_eagletv_db`)*
3. Create a new database user:
   - Username: `techmigo_eagletv`
   - Password: Generate a **strong** password (save it securely)
4. Add the user to the database:
   - Select the user and database
   - Grant **ALL PRIVILEGES**
   - Click "Add"

**Record these credentials — you'll need them for `config.php`:**

| Field | Value |
|---|---|
| DB Host | `localhost` |
| DB Name | `techmigo_eagletv_db` |
| DB User | `techmigo_eagletv` |
| DB Pass | *(your strong password)* |

> **Important:** cPanel typically prefixes your account username to both the database name and the database user. For example, if your cPanel username is `techmigo`, the database will be `techmigo_eagletv_db` and user will be `techmigo_eagletv`. Adjust accordingly.

---

## 4. Step 2 — Import Database Schema

### Option A: phpMyAdmin (Recommended)

1. Go to **cPanel → Databases → phpMyAdmin**
2. Select the database `techmigo_eagletv_db` from the left panel
3. Click the **Import** tab
4. Import SQL files **in this exact order**, one at a time:

| Order | File | Description |
|---|---|---|
| 1 | `setup.sql` | Core tables: users, posts, comments, post_likes, post_bookmarks + indexes |
| 2 | `migrate_v2.sql` | notifications, user_follows, content_reports tables |
| 3 | `migrate_v3_notifications.sql` | Adds `fcm_token` to users, expands notification types |
| 4 | `migrate_v4_user_details.sql` | Adds `area`, `district`, `state` to users + `storage_config` table |

> **Critical:** Before importing `setup.sql`, edit the first two lines:
> ```sql
> -- REMOVE OR COMMENT OUT these lines (cPanel already selected the DB):
> -- CREATE DATABASE IF NOT EXISTS eagletv_db ...
> -- USE eagletv_db;
> ```
> Similarly, remove or comment out the `USE eagletv_db;` line from each migration file.

### Option B: MySQL Command Line (SSH Access)

If you have SSH access:

```bash
# Connect to MySQL
mysql -u techmigo_eagletv -p techmigo_eagletv_db

# Run each migration in order (after editing out CREATE DATABASE/USE lines)
source /path/to/setup.sql
source /path/to/migrate_v2.sql
source /path/to/migrate_v3_notifications.sql
source /path/to/migrate_v4_user_details.sql
```

### Option C: Combined SQL Script

For convenience, you can combine all 4 files (removing duplicate `CREATE DATABASE` and `USE` statements) into a single `combined_schema.sql` and import once:

```sql
-- ============================================================
-- EagleTV Combined Schema — For cPanel phpMyAdmin import
-- ============================================================

-- From setup.sql (Core Tables)
CREATE TABLE IF NOT EXISTS users (
  id VARCHAR(64) PRIMARY KEY,
  phone_number VARCHAR(20) DEFAULT NULL,
  email VARCHAR(255) DEFAULT NULL,
  display_name VARCHAR(100) NOT NULL DEFAULT 'User',
  profile_picture TEXT DEFAULT NULL,
  bio TEXT DEFAULT NULL,
  role ENUM('superAdmin','admin','reporter','publicUser') NOT NULL DEFAULT 'publicUser',
  is_subscribed TINYINT(1) DEFAULT 0,
  preferred_language VARCHAR(5) DEFAULT 'en',
  subscription_plan_type ENUM('free','premium','elite') DEFAULT NULL,
  subscription_expires_at DATETIME DEFAULT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS posts (
  id VARCHAR(64) PRIMARY KEY,
  author_id VARCHAR(64) NOT NULL,
  author_name VARCHAR(100) NOT NULL,
  author_avatar TEXT DEFAULT NULL,
  caption TEXT NOT NULL,
  caption_te TEXT DEFAULT NULL,
  caption_hi TEXT DEFAULT NULL,
  media_url TEXT DEFAULT NULL,
  content_type ENUM('image','video','pdf','article','story','poetry','none') NOT NULL DEFAULT 'none',
  category VARCHAR(50) NOT NULL DEFAULT 'News',
  hashtags TEXT DEFAULT NULL,
  status ENUM('pending','approved','rejected') NOT NULL DEFAULT 'pending',
  pdf_file_path TEXT DEFAULT NULL,
  article_content LONGTEXT DEFAULT NULL,
  poem_verses TEXT DEFAULT NULL,
  likes_count INT DEFAULT 0,
  bookmarks_count INT DEFAULT 0,
  shares_count INT DEFAULT 0,
  rejection_reason TEXT DEFAULT NULL,
  edit_count INT DEFAULT 0,
  last_edited_at DATETIME DEFAULT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  published_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (author_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS comments (
  id VARCHAR(64) PRIMARY KEY,
  post_id VARCHAR(64) NOT NULL,
  author_id VARCHAR(64) NOT NULL,
  author_name VARCHAR(100) NOT NULL,
  author_avatar TEXT DEFAULT NULL,
  content TEXT NOT NULL,
  likes_count INT DEFAULT 0,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE,
  FOREIGN KEY (author_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS post_likes (
  id VARCHAR(64) PRIMARY KEY,
  post_id VARCHAR(64) NOT NULL,
  user_id VARCHAR(64) NOT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY unique_like (post_id, user_id),
  FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS post_bookmarks (
  id VARCHAR(64) PRIMARY KEY,
  post_id VARCHAR(64) NOT NULL,
  user_id VARCHAR(64) NOT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY unique_bookmark (post_id, user_id),
  FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- From migrate_v2.sql (Notifications, Follows, Reports)
CREATE TABLE IF NOT EXISTS notifications (
  id VARCHAR(64) PRIMARY KEY,
  user_id VARCHAR(64) NOT NULL,
  title VARCHAR(255) NOT NULL,
  body TEXT NOT NULL,
  type ENUM('post_approved','post_rejected','new_content','like','comment','follower','system') NOT NULL DEFAULT 'system',
  is_read TINYINT(1) DEFAULT 0,
  action_data TEXT DEFAULT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS user_follows (
  id VARCHAR(64) PRIMARY KEY,
  follower_id VARCHAR(64) NOT NULL,
  following_id VARCHAR(64) NOT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY unique_follow (follower_id, following_id),
  FOREIGN KEY (follower_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (following_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS content_reports (
  id VARCHAR(64) PRIMARY KEY,
  post_id VARCHAR(64) NOT NULL,
  reporter_id VARCHAR(64) NOT NULL,
  reason TEXT NOT NULL,
  status ENUM('pending','reviewed','dismissed') NOT NULL DEFAULT 'pending',
  reviewed_by VARCHAR(64) DEFAULT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE,
  FOREIGN KEY (reporter_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- From migrate_v3 (FCM + notification type expansion)
ALTER TABLE users ADD COLUMN IF NOT EXISTS fcm_token TEXT DEFAULT NULL AFTER preferred_language;

ALTER TABLE notifications MODIFY COLUMN type
  ENUM('post_approved','post_rejected','post_edited','new_content','new_post_pending','like','comment','follower','system')
  NOT NULL DEFAULT 'system';

-- From migrate_v4 (Location fields + storage config)
ALTER TABLE users ADD COLUMN IF NOT EXISTS area VARCHAR(100) DEFAULT NULL AFTER bio;
ALTER TABLE users ADD COLUMN IF NOT EXISTS district VARCHAR(100) DEFAULT NULL AFTER area;
ALTER TABLE users ADD COLUMN IF NOT EXISTS state VARCHAR(100) DEFAULT NULL AFTER district;

CREATE TABLE IF NOT EXISTS storage_config (
  id VARCHAR(64) PRIMARY KEY DEFAULT 'default',
  posts_limit_gb DECIMAL(10,2) NOT NULL DEFAULT 5.00,
  interactions_limit_gb DECIMAL(10,2) NOT NULL DEFAULT 2.00,
  users_limit_gb DECIMAL(10,2) NOT NULL DEFAULT 1.00,
  system_files_gb DECIMAL(10,2) NOT NULL DEFAULT 3.00,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

INSERT IGNORE INTO storage_config (id, posts_limit_gb, interactions_limit_gb, users_limit_gb, system_files_gb)
VALUES ('default', 5.00, 2.00, 1.00, 3.00);

-- All Indexes
CREATE INDEX idx_posts_author ON posts(author_id);
CREATE INDEX idx_posts_status ON posts(status);
CREATE INDEX idx_posts_created ON posts(created_at DESC);
CREATE INDEX idx_posts_category ON posts(category);
CREATE INDEX idx_comments_post ON comments(post_id);
CREATE INDEX idx_likes_post ON post_likes(post_id);
CREATE INDEX idx_likes_user ON post_likes(user_id);
CREATE INDEX idx_bookmarks_user ON post_bookmarks(user_id);
CREATE INDEX idx_users_role ON users(role);
CREATE INDEX idx_notifications_user ON notifications(user_id);
CREATE INDEX idx_notifications_read ON notifications(user_id, is_read);
CREATE INDEX idx_follows_follower ON user_follows(follower_id);
CREATE INDEX idx_follows_following ON user_follows(following_id);
CREATE INDEX idx_reports_status ON content_reports(status);
CREATE INDEX idx_reports_post ON content_reports(post_id);
CREATE INDEX idx_users_district ON users(district);
CREATE INDEX idx_users_state ON users(state);
```

### Verify Import

After importing, verify all 9 tables exist:

```sql
SHOW TABLES;
```

Expected output:
```
comments
content_reports
notifications
post_bookmarks
post_likes
posts
storage_config
user_follows
users
```

---

## 5. Step 3 — Upload Backend Files

### Via cPanel File Manager

1. Go to **cPanel → Files → File Manager**
2. Navigate to `public_html/`
3. Create the directory path: `eagletv/backend/`
4. Upload these files into `public_html/eagletv/backend/`:

| File | Upload? | Notes |
|---|---|---|
| `config.php` | ✅ | **Edit before uploading** (see Step 4) |
| `index.php` | ✅ | API router |
| `share.php` | ✅ | Shareable post pages |
| `firebase_service_account.json` | ✅ | FCM credentials (**protect this!**) |
| `.htaccess` | ✅ | Security rules (create new — see Step 5) |
| `api/` folder | ✅ | Upload entire directory with all PHP files |
| `uploads/` folder | ✅ | Create with subdirectories `posts/` and `profiles/` |
| `setup.sql` | ❌ | Only needed for DB import, do NOT upload |
| `migrate_*.sql` | ❌ | Only needed for DB import, do NOT upload |

### Via FTP/SFTP (Alternative)

Use FileZilla or similar FTP client:

```
Host: ftp.techmigos.com  (or your server IP)
Username: <cPanel username>
Password: <cPanel password>
Port: 21 (FTP) or 22 (SFTP)
Remote Path: /public_html/eagletv/backend/
```

Upload all PHP files, `api/` directory, and create empty `uploads/posts/` and `uploads/profiles/` directories.

---

## 6. Step 4 — Update config.php

### Changes Required

Open `config.php` and make these changes:

```php
<?php
/**
 * EagleTV API — Database Configuration (PRODUCTION)
 */

// === CHANGE THESE TO YOUR CPANEL MYSQL CREDENTIALS ===
define('DB_HOST', 'localhost');
define('DB_NAME', 'techmigo_eagletv_db');        // ← cPanel-prefixed DB name
define('DB_USER', 'techmigo_eagletv');            // ← cPanel-prefixed DB user
define('DB_PASS', 'YOUR_STRONG_PASSWORD_HERE');   // ← The password you set

// Upload directory (relative to this file's directory)
define('UPLOAD_DIR', __DIR__ . '/uploads/');

// Dynamic upload URL — auto-detects from request host
$_scheme = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') ? 'https' : 'http';
$_host   = $_SERVER['HTTP_HOST'] ?? 'www.techmigos.com';

// === CHANGE THIS PATH to match your cPanel directory ===
define('UPLOAD_URL_BASE', "$_scheme://$_host/eagletv/backend/uploads/");
//                                              ^^^^^^^^^^^^^^^^^^^
//   Was: /eagletv_api/uploads/  (XAMPP local path)
//   Now: /eagletv/backend/uploads/  (cPanel production path)

// CORS headers
function cors_headers() {
    // In production, restrict to your app's domain instead of '*'
    header('Access-Control-Allow-Origin: *');
    header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
    header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With');
    header('Content-Type: application/json; charset=UTF-8');
    
    if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
        http_response_code(200);
        exit();
    }
}

// ... rest of config.php remains unchanged (get_db, uuid_v4, json_response, etc.)
```

### Summary of Changes

| Setting | Local (XAMPP) | Production (cPanel) |
|---|---|---|
| `DB_HOST` | `localhost` | `localhost` *(usually same on cPanel)* |
| `DB_NAME` | `eagletv_db` | `techmigo_eagletv_db` |
| `DB_USER` | `root` | `techmigo_eagletv` |
| `DB_PASS` | *(empty)* | `YOUR_STRONG_PASSWORD` |
| `UPLOAD_URL_BASE` | `…/eagletv_api/uploads/` | `…/eagletv/backend/uploads/` |

---

## 7. Step 5 — .htaccess Security & Routing

Create a new `.htaccess` file in `public_html/eagletv/backend/`:

```apache
# ============================================================
# EagleTV Backend — .htaccess
# Place in: public_html/eagletv/backend/
# ============================================================

# === SECURITY: Deny access to sensitive files ===
<FilesMatch "\.(json|sql|log|env|md)$">
    Order Allow,Deny
    Deny from all
</FilesMatch>

# Specifically protect the Firebase service account key
<Files "firebase_service_account.json">
    Order Allow,Deny
    Deny from all
</Files>

# Protect config.php from direct browser access
<Files "config.php">
    Order Allow,Deny
    Deny from all
</Files>

# === PREVENT DIRECTORY LISTING ===
Options -Indexes

# === ALLOW UPLOADS TO BE SERVED ===
<Directory "uploads">
    Options -Indexes
    <FilesMatch "\.(jpg|jpeg|png|gif|webp|mp4|mov|avi|pdf)$">
        Order Allow,Deny
        Allow from all
    </FilesMatch>
</Directory>

# === REWRITE RULES (optional, for clean URLs) ===
RewriteEngine On

# Force HTTPS
RewriteCond %{HTTPS} off
RewriteRule ^(.*)$ https://%{HTTP_HOST}%{REQUEST_URI} [L,R=301]

# Allow direct access to existing files and directories
RewriteCond %{REQUEST_FILENAME} -f [OR]
RewriteCond %{REQUEST_FILENAME} -d
RewriteRule ^ - [L]

# Route API requests through index.php
RewriteRule ^api/(.*)$ api/$1 [L,QSA]
```

Also create `.htaccess` in the `uploads/` directory:

```apache
# Allow serving media files only — no PHP execution
<FilesMatch "\.php$">
    Order Allow,Deny
    Deny from all
</FilesMatch>

Options -Indexes
```

---

## 8. Step 6 — File Permissions

Set correct permissions via **cPanel → File Manager** (right-click → Change Permissions), or via SSH:

```bash
# Directories: 755 (rwxr-xr-x)
chmod 755 public_html/eagletv/backend/
chmod 755 public_html/eagletv/backend/api/

# PHP files: 644 (rw-r--r--)
chmod 644 public_html/eagletv/backend/*.php
chmod 644 public_html/eagletv/backend/api/*.php

# Firebase key: 600 (rw-------) — most restrictive
chmod 600 public_html/eagletv/backend/firebase_service_account.json

# Uploads directory: 755 for directories, writeable by PHP
chmod 755 public_html/eagletv/backend/uploads/
chmod 755 public_html/eagletv/backend/uploads/posts/
chmod 755 public_html/eagletv/backend/uploads/profiles/
```

> **Note:** On shared hosting, PHP usually runs as the same user as your cPanel account, so `755` for the uploads directory should be sufficient. If uploads fail, try `775`.

---

## 9. Step 7 — SSL / HTTPS Configuration

### Via cPanel → SSL/TLS

1. Go to **cPanel → Security → SSL/TLS** or **cPanel → Security → Let's Encrypt SSL**
2. If using Let's Encrypt:
   - Click "Issue" or "Install" for `www.techmigos.com`
   - Enable auto-renewal
3. Verify HTTPS is working:
   ```
   https://www.techmigos.com/eagletv/backend/api/users.php?action=list
   ```

### Force HTTPS

The `.htaccess` from Step 5 already includes HTTPS redirect rules. If your cPanel has a "Force HTTPS Redirect" toggle, you can use that instead.

---

## 10. Step 8 — Update Flutter App API Base URL

### In `lib/core/services/api_service.dart`

Update the `_defaultBaseUrl` getter to point to production:

```dart
/// Compute the correct base URL per platform
static String get _defaultBaseUrl {
  // === PRODUCTION URL ===
  return 'https://www.techmigos.com/eagletv/backend/api';
  
  // === LOCAL DEVELOPMENT (comment out for production) ===
  // if (kIsWeb) return 'http://localhost/eagletv_api/api';
  // if (Platform.isAndroid) return 'http://localhost:8080/eagletv_api/api';
  // return 'http://localhost/eagletv_api/api';
}
```

### Recommended: Use Environment Configuration

For easier switching between dev and production, consider using a config pattern:

```dart
class AppConfig {
  static const bool isProduction = true; // Toggle for builds
  
  static String get apiBaseUrl => isProduction
      ? 'https://www.techmigos.com/eagletv/backend/api'
      : _localUrl;
      
  static String get _localUrl {
    if (kIsWeb) return 'http://localhost/eagletv_api/api';
    if (Platform.isAndroid) return 'http://localhost:8080/eagletv_api/api';
    return 'http://localhost/eagletv_api/api';
  }
}
```

### Upload URL Path Note

The `UPLOAD_URL_BASE` in `config.php` is dynamically generated from the server request, so media URLs returned by the API will automatically use the correct production domain. **No changes needed in Flutter for upload URLs** — they come from the API responses.

---

## 11. Step 9 — Firebase Push Notifications

### Service Account Key

The file `firebase_service_account.json` contains the credentials for Firebase Cloud Messaging (FCM) HTTP v1 API. This file is used by `api/send_push.php` to authenticate push requests.

1. **Upload** `firebase_service_account.json` to `public_html/eagletv/backend/`
2. **Permissions**: Set to `600` (owner read/write only)
3. The `.htaccess` rules (Step 5) block direct HTTP access to this file

### Verify FCM Works

The push notification system uses:
- **Project ID**: `eagle-tv-crii`
- **Auth Method**: OAuth2 JWT from service account → FCM HTTP v1 API
- **Topic Push**: `public_users` topic for broadcast notifications

Test by calling:
```
POST https://www.techmigos.com/eagletv/backend/api/users.php
Body: { "action": "register", ... }
```
This should trigger a push notification to admin users about a new registration.

### Firebase Console Settings

Ensure the Firebase project `eagle-tv-crii` has:
1. **Cloud Messaging API (V1)** enabled in Google Cloud Console
2. The service account has **Firebase Cloud Messaging API** permissions
3. Android app registered with the correct package name

---

## 12. Step 10 — Testing Checklist

After deployment, verify each API endpoint works:

### Health Check

```bash
# Should return the API index/welcome page
curl https://www.techmigos.com/eagletv/backend/index.php
```

### User APIs

```bash
# Register a new user
curl -X POST https://www.techmigos.com/eagletv/backend/api/users.php \
  -H "Content-Type: application/json" \
  -d '{"phone_number": "+91XXXXXXXXXX", "display_name": "Test User"}'

# Get user profile
curl "https://www.techmigos.com/eagletv/backend/api/users.php?id=USER_ID"

# List all users (admin)
curl "https://www.techmigos.com/eagletv/backend/api/users.php?action=list"
```

### Post APIs

```bash
# Get approved posts
curl "https://www.techmigos.com/eagletv/backend/api/posts.php?user_id=USER_ID"

# Get pending count
curl "https://www.techmigos.com/eagletv/backend/api/posts.php?action=pending_count"

# Get pending posts for moderation
curl "https://www.techmigos.com/eagletv/backend/api/posts.php?action=moderate&status=pending"
```

### Upload Test

```bash
# Upload an image
curl -X POST https://www.techmigos.com/eagletv/backend/api/upload.php \
  -F "file=@test_image.jpg" \
  -F "type=post"
```

### Full Endpoint Checklist

| Endpoint | Method | Test | Status |
|---|---|---|---|
| `/api/users.php` (register) | POST | Register user | ☐ |
| `/api/users.php` (get) | GET | Get user by ID | ☐ |
| `/api/users.php` (update) | PUT | Update profile | ☐ |
| `/api/users.php` (list) | GET | List all users | ☐ |
| `/api/users.php` (role) | PUT | Update user role | ☐ |
| `/api/users.php` (delete) | DELETE | Delete user | ☐ |
| `/api/posts.php` (feed) | GET | Get approved posts | ☐ |
| `/api/posts.php` (create) | POST | Create new post | ☐ |
| `/api/posts.php` (moderate) | GET | Get pending posts | ☐ |
| `/api/posts.php` (approve) | PUT | Approve post | ☐ |
| `/api/posts.php` (reject) | PUT | Reject post | ☐ |
| `/api/posts.php` (pending_count) | GET | Pending count | ☐ |
| `/api/posts.php` (search) | GET | Search posts | ☐ |
| `/api/posts.php` (resubmit) | POST | Resubmit rejected | ☐ |
| `/api/comments.php` (list) | GET | Get post comments | ☐ |
| `/api/comments.php` (create) | POST | Add comment | ☐ |
| `/api/comments.php` (delete) | DELETE | Delete comment | ☐ |
| `/api/interactions.php` (like) | POST | Like/unlike post | ☐ |
| `/api/interactions.php` (bookmark) | POST | Bookmark/unbookmark | ☐ |
| `/api/interactions.php` (share) | POST | Record share | ☐ |
| `/api/follows.php` (follow) | POST | Follow user | ☐ |
| `/api/follows.php` (unfollow) | POST | Unfollow user | ☐ |
| `/api/follows.php` (status) | GET | Follow status | ☐ |
| `/api/notifications.php` (list) | GET | Get notifications | ☐ |
| `/api/notifications.php` (read) | PUT | Mark as read | ☐ |
| `/api/notifications.php` (count) | GET | Unread count | ☐ |
| `/api/reports.php` (create) | POST | Report content | ☐ |
| `/api/reports.php` (list) | GET | List reports | ☐ |
| `/api/storage.php` (get) | GET | Get storage config | ☐ |
| `/api/storage.php` (update) | PUT | Update limits | ☐ |
| `/api/upload.php` | POST | Upload file | ☐ |
| `/share.php` | GET | Share page renders | ☐ |

---

## 13. Troubleshooting

### Common Issues

#### 500 Internal Server Error
- **Check PHP error logs**: cPanel → Metrics → Errors, or `public_html/eagletv/backend/error_log`
- **Most likely cause**: Wrong DB credentials in `config.php`
- **Fix**: Verify `DB_NAME`, `DB_USER`, `DB_PASS` match exactly what you created in cPanel MySQL Databases

#### 403 Forbidden
- **Cause**: File permissions too restrictive
- **Fix**: Ensure PHP files are `644`, directories are `755`

#### Uploads Failing (Empty or Error)
- **Check**: `uploads/` directory permissions (try `775` if `755` fails)
- **Check**: PHP `upload_max_filesize` and `post_max_size` in cPanel → MultiPHP INI Editor
- **Recommended values**:
  ```
  upload_max_filesize = 100M
  post_max_size = 105M
  max_execution_time = 300
  memory_limit = 256M
  ```

#### CORS Errors
- **Symptom**: Flutter web app can't reach API
- **Fix**: Ensure `cors_headers()` is called in all API files (already implemented)
- **Production fix**: Replace `Access-Control-Allow-Origin: *` with your specific domain

#### Push Notifications Not Working
- **Check**: `firebase_service_account.json` is readable by PHP (permissions `600`)
- **Check**: cURL extension is enabled (`php -m | grep curl`)
- **Check**: Outbound HTTPS requests are not blocked by hosting firewall
- **Test**: Add error logging in `send_push.php`:
  ```php
  error_log("FCM Response: " . $response);
  ```

#### Database Connection Failed
- **Error**: `SQLSTATE[HY000] [1045] Access denied for user...`
- **Fix**: Ensure the cPanel DB user is added to the database with ALL PRIVILEGES
- **Note**: cPanel username prefix! `techmigo_eagletv` not just `eagletv`

#### share.php Not Rendering
- **Cause**: The `UPLOAD_URL_BASE` path is wrong
- **Fix**: Ensure `config.php` has the correct path: `/eagletv/backend/uploads/`

---

## 14. Complete API Reference

### User Endpoints — `/api/users.php`

| Method | Parameters | Description |
|---|---|---|
| **POST** | `phone_number`, `display_name`, `email?`, `role?` | Register / get existing user |
| **GET** | `?id={user_id}` | Get user profile |
| **GET** | `?action=list` | List all users (admin) |
| **PUT** | Body: `{ id, display_name?, bio?, profile_picture?, role?, area?, district?, state? }` | Update user profile |
| **PUT** | Body: `{ id, role, action: "update_role" }` | Update user role (admin) |
| **DELETE** | Body: `{ id }` | Delete user account |

### Post Endpoints — `/api/posts.php`

| Method | Parameters | Description |
|---|---|---|
| **GET** | `?user_id={id}` | Feed — approved + own pending posts |
| **GET** | `?action=moderate&status=pending` | Get posts by status (moderation) |
| **GET** | `?action=pending_count` | Count of pending posts |
| **GET** | `?action=user_posts&author_id={id}` | Posts by a specific author |
| **GET** | `?action=search&q={query}` | Search posts by caption |
| **POST** | FormData or JSON body with post fields | Create new post |
| **PUT** | Body: `{ id, status, rejection_reason? }` | Approve/reject post |
| **POST** | `action=resubmit`, Body: edited post data | Resubmit rejected post |
| **DELETE** | Body: `{ id }` | Delete post |

### Comment Endpoints — `/api/comments.php`

| Method | Parameters | Description |
|---|---|---|
| **GET** | `?post_id={id}` | Get comments for a post |
| **POST** | Body: `{ post_id, author_id, author_name, content }` | Add comment |
| **DELETE** | Body: `{ id }` | Delete comment |

### Interaction Endpoints — `/api/interactions.php`

| Method | Parameters | Description |
|---|---|---|
| **POST** | Body: `{ action: "like", post_id, user_id }` | Like/unlike (toggle) |
| **POST** | Body: `{ action: "bookmark", post_id, user_id }` | Bookmark/unbookmark (toggle) |
| **POST** | Body: `{ action: "share", post_id }` | Record share count |

### Follow Endpoints — `/api/follows.php`

| Method | Parameters | Description |
|---|---|---|
| **POST** | Body: `{ follower_id, following_id }` | Follow a user |
| **POST** | Body: `{ follower_id, following_id, action: "unfollow" }` | Unfollow a user |
| **GET** | `?action=status&follower_id={id}&following_id={id}` | Check follow status |
| **GET** | `?action=followers&user_id={id}` | Get user's followers |
| **GET** | `?action=following&user_id={id}` | Get who user follows |
| **GET** | `?action=counts&user_id={id}` | Get follower/following counts |

### Notification Endpoints — `/api/notifications.php`

| Method | Parameters | Description |
|---|---|---|
| **GET** | `?user_id={id}` | Get user notifications |
| **GET** | `?action=unread_count&user_id={id}` | Get unread count |
| **PUT** | Body: `{ id }` OR `{ user_id, action: "mark_all_read" }` | Mark as read |
| **DELETE** | Body: `{ id }` | Delete notification |

### Report Endpoints — `/api/reports.php`

| Method | Parameters | Description |
|---|---|---|
| **POST** | Body: `{ post_id, reporter_id, reason }` | Report a post |
| **GET** | `?status=pending` | Get reports by status |
| **PUT** | Body: `{ id, status, reviewed_by }` | Update report status |

### Storage Endpoints — `/api/storage.php`

| Method | Parameters | Description |
|---|---|---|
| **GET** | *(none)* | Get storage limits config |
| **PUT** | Body: `{ posts_limit_gb, interactions_limit_gb, users_limit_gb, system_files_gb }` | Update limits |

### Upload Endpoint — `/api/upload.php`

| Method | Parameters | Description |
|---|---|---|
| **POST** | FormData: `file` (file), `type` (post/profile) | Upload media file |

### Share Page — `/share.php`

| Method | Parameters | Description |
|---|---|---|
| **GET** | `?id={post_id}` | Renders HTML share page with OG meta tags |

---

## 15. Database Schema Reference

### Final Schema (After All Migrations)

#### `users` table
| Column | Type | Notes |
|---|---|---|
| `id` | VARCHAR(64) | PK, UUID |
| `phone_number` | VARCHAR(20) | Nullable |
| `email` | VARCHAR(255) | Nullable |
| `display_name` | VARCHAR(100) | Default: 'User' |
| `profile_picture` | TEXT | URL |
| `bio` | TEXT | |
| `area` | VARCHAR(100) | v4: Location field |
| `district` | VARCHAR(100) | v4: Location field |
| `state` | VARCHAR(100) | v4: Location field |
| `role` | ENUM | superAdmin, admin, reporter, publicUser |
| `is_subscribed` | TINYINT(1) | |
| `preferred_language` | VARCHAR(5) | Default: 'en' |
| `fcm_token` | TEXT | v3: Firebase Cloud Messaging |
| `subscription_plan_type` | ENUM | free, premium, elite |
| `subscription_expires_at` | DATETIME | |
| `created_at` | DATETIME | Auto |
| `updated_at` | DATETIME | Auto-update |

#### `posts` table
| Column | Type | Notes |
|---|---|---|
| `id` | VARCHAR(64) | PK, UUID |
| `author_id` | VARCHAR(64) | FK → users.id |
| `author_name` | VARCHAR(100) | |
| `author_avatar` | TEXT | |
| `caption` | TEXT | English |
| `caption_te` | TEXT | Telugu translation |
| `caption_hi` | TEXT | Hindi translation |
| `media_url` | TEXT | |
| `content_type` | ENUM | image, video, pdf, article, story, poetry, none |
| `category` | VARCHAR(50) | Default: 'News' |
| `hashtags` | TEXT | |
| `status` | ENUM | pending, approved, rejected |
| `pdf_file_path` | TEXT | |
| `article_content` | LONGTEXT | |
| `poem_verses` | TEXT | |
| `likes_count` | INT | |
| `bookmarks_count` | INT | |
| `shares_count` | INT | |
| `rejection_reason` | TEXT | |
| `edit_count` | INT | |
| `last_edited_at` | DATETIME | |
| `created_at` | DATETIME | Auto |
| `published_at` | DATETIME | Auto |

#### `comments` table
| Column | Type | Notes |
|---|---|---|
| `id` | VARCHAR(64) | PK |
| `post_id` | VARCHAR(64) | FK → posts.id |
| `author_id` | VARCHAR(64) | FK → users.id |
| `author_name` | VARCHAR(100) | |
| `author_avatar` | TEXT | |
| `content` | TEXT | |
| `likes_count` | INT | |
| `created_at` | DATETIME | |

#### `post_likes` table
| Column | Type | Notes |
|---|---|---|
| `id` | VARCHAR(64) | PK |
| `post_id` | VARCHAR(64) | FK, UNIQUE with user_id |
| `user_id` | VARCHAR(64) | FK |
| `created_at` | DATETIME | |

#### `post_bookmarks` table
| Column | Type | Notes |
|---|---|---|
| `id` | VARCHAR(64) | PK |
| `post_id` | VARCHAR(64) | FK, UNIQUE with user_id |
| `user_id` | VARCHAR(64) | FK |
| `created_at` | DATETIME | |

#### `notifications` table
| Column | Type | Notes |
|---|---|---|
| `id` | VARCHAR(64) | PK |
| `user_id` | VARCHAR(64) | FK → users.id |
| `title` | VARCHAR(255) | |
| `body` | TEXT | |
| `type` | ENUM | post_approved, post_rejected, post_edited, new_content, new_post_pending, like, comment, follower, system |
| `is_read` | TINYINT(1) | |
| `action_data` | TEXT | JSON |
| `created_at` | DATETIME | |

#### `user_follows` table
| Column | Type | Notes |
|---|---|---|
| `id` | VARCHAR(64) | PK |
| `follower_id` | VARCHAR(64) | FK, UNIQUE with following_id |
| `following_id` | VARCHAR(64) | FK |
| `created_at` | DATETIME | |

#### `content_reports` table
| Column | Type | Notes |
|---|---|---|
| `id` | VARCHAR(64) | PK |
| `post_id` | VARCHAR(64) | FK → posts.id |
| `reporter_id` | VARCHAR(64) | FK → users.id |
| `reason` | TEXT | |
| `status` | ENUM | pending, reviewed, dismissed |
| `reviewed_by` | VARCHAR(64) | |
| `created_at` | DATETIME | |

#### `storage_config` table
| Column | Type | Notes |
|---|---|---|
| `id` | VARCHAR(64) | PK, Default: 'default' |
| `posts_limit_gb` | DECIMAL(10,2) | Default: 5.00 |
| `interactions_limit_gb` | DECIMAL(10,2) | Default: 2.00 |
| `users_limit_gb` | DECIMAL(10,2) | Default: 1.00 |
| `system_files_gb` | DECIMAL(10,2) | Default: 3.00 |
| `updated_at` | DATETIME | Auto-update |

---

## 16. Security Hardening Checklist

### Before Going Live

- [ ] **Strong DB password** — Never use empty or simple passwords
- [ ] **`firebase_service_account.json` protected** — `.htaccess` blocks HTTP access, file permission `600`
- [ ] **No SQL files on server** — Remove `setup.sql`, migration files from production
- [ ] **HTTPS enforced** — All API requests over SSL
- [ ] **CORS restricted** — Change `Access-Control-Allow-Origin: *` to your specific domain/app
- [ ] **Directory listing disabled** — `Options -Indexes` in `.htaccess`
- [ ] **PHP errors hidden** — In `php.ini` or `.htaccess`:
  ```
  display_errors = Off
  log_errors = On
  error_log = /home/<user>/logs/eagletv_error.log
  ```
- [ ] **Upload validation** — `upload.php` already validates file types, but verify
- [ ] **No PHP execution in uploads** — `.htaccess` in `uploads/` blocks `.php` files
- [ ] **Rate limiting** — Consider adding basic rate limiting for API endpoints
- [ ] **Input sanitization** — API already uses PDO prepared statements (SQL injection safe)
- [ ] **Firebase rules** — Review Firebase Authentication rules and FCM topic subscriptions

### PHP.ini Recommendations (cPanel → MultiPHP INI Editor)

```ini
; Security
display_errors = Off
log_errors = On
expose_php = Off

; Upload limits
upload_max_filesize = 100M
post_max_size = 105M
max_file_uploads = 10

; Execution limits
max_execution_time = 300
max_input_time = 300
memory_limit = 256M

; Session security
session.cookie_httponly = 1
session.cookie_secure = 1
session.use_strict_mode = 1
```

---

## 17. Backup & Maintenance

### Database Backup

#### Via cPanel

1. **cPanel → Backup → Download a MySQL Database Backup**
2. Select `techmigo_eagletv_db`
3. Schedule regular backups via **cPanel → Backup Wizard**

#### Via phpMyAdmin

1. **phpMyAdmin → Export**
2. Format: SQL
3. Select "Custom" → check "Add DROP TABLE" for clean restores

#### Automated (Cron Job)

**cPanel → Cron Jobs** — Add a daily backup:

```bash
# Daily DB backup at 2 AM
0 2 * * * /usr/bin/mysqldump -u techmigo_eagletv -p'PASSWORD' techmigo_eagletv_db | gzip > /home/techmigo/backups/eagletv_$(date +\%Y\%m\%d).sql.gz
```

### File Backup

Regularly backup the `uploads/` directory (user-generated content):

```bash
# Weekly uploads backup
0 3 * * 0 tar -czf /home/techmigo/backups/uploads_$(date +\%Y\%m\%d).tar.gz /home/techmigo/public_html/eagletv/backend/uploads/
```

### Monitoring

- **cPanel → Metrics → Errors** — Check PHP error logs regularly
- **cPanel → Metrics → Visitors** — Monitor API traffic
- Set up uptime monitoring (e.g., UptimeRobot) for:
  ```
  https://www.techmigos.com/eagletv/backend/index.php
  ```

---

## Quick Reference: Migration Steps Summary

```
1. Create MySQL database & user in cPanel
2. Import combined SQL schema via phpMyAdmin
3. Upload backend files (PHP + api/ + uploads/)
4. Edit config.php with cPanel DB credentials & URL path
5. Create .htaccess for security
6. Set file permissions (644 PHP, 755 dirs, 600 key)
7. Enable SSL/HTTPS
8. Update Flutter app API base URL
9. Upload firebase_service_account.json
10. Test all API endpoints
```

---

*Document generated for EagleTV Backend Migration*  
*Target: https://www.techmigos.com/eagletv/backend*  
*Database: 9 tables across 4 migration files*  
*Firebase Project: eagle-tv-crii*
