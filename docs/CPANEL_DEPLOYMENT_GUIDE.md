# EagleTV CI4 Backend — cPanel Deployment Guide

> **Deployed on:** February 11, 2026  
> **Server:** techmigos.com (cPanel shared hosting)  
> **Framework:** CodeIgniter 4.7.0  
> **API Endpoint:** `https://www.techmigos.com/eagletv_api/`

---

## Table of Contents

1. [Overview](#1-overview)
2. [Server Architecture](#2-server-architecture)
3. [Prerequisites](#3-prerequisites)
4. [Deployment Package Preparation](#4-deployment-package-preparation)
5. [Step-by-Step Deployment](#5-step-by-step-deployment)
6. [Environment Configuration](#6-environment-configuration)
7. [Database Setup](#7-database-setup)
8. [API Endpoints Reference](#8-api-endpoints-reference)
9. [Verification & Testing](#9-verification--testing)
10. [Troubleshooting](#10-troubleshooting)
11. [Re-deployment / Updates](#11-re-deployment--updates)
12. [Security Notes](#12-security-notes)

---

## 1. Overview

The EagleTV backend is a CodeIgniter 4 REST API deployed on cPanel shared hosting. The architecture separates **private application code** (outside the web root) from the **public entry point** (inside `public_html`).

### Key Details

| Item               | Value                                                     |
|--------------------|-----------------------------------------------------------|
| cPanel Username    | `techmigo`                                                |
| Server             | `142.132.248.161` (techmigos.com, SSH port 7822)          |
| PHP Version        | 8.2+                                                      |
| Database           | MySQL with MySQLi driver                                  |
| Character Set      | `utf8mb4` / `utf8mb4_unicode_ci`                          |
| API Base URL       | `https://www.techmigos.com/eagletv_api/`                  |

---

## 2. Server Architecture

```
/home/techmigo/
├── eagletv_ci4/                    ← PRIVATE (CI4 app code, NOT web-accessible)
│   ├── app/
│   │   ├── Config/
│   │   │   ├── Paths.php           ← Path configuration
│   │   │   ├── Routes.php          ← API route definitions
│   │   │   └── ...
│   │   ├── Controllers/
│   │   │   ├── Api/                ← All API controllers
│   │   │   │   ├── ActivityReports.php
│   │   │   │   ├── Alerts.php
│   │   │   │   ├── BreakingNews.php
│   │   │   │   ├── Comments.php
│   │   │   │   ├── Donations.php
│   │   │   │   ├── Follows.php
│   │   │   │   ├── Interactions.php
│   │   │   │   ├── Notifications.php
│   │   │   │   ├── Partners.php
│   │   │   │   ├── Posts.php
│   │   │   │   ├── Reports.php
│   │   │   │   ├── Storage.php
│   │   │   │   ├── Upload.php
│   │   │   │   ├── Users.php
│   │   │   │   └── VerifyToken.php
│   │   │   ├── BaseApiController.php
│   │   │   ├── BaseController.php
│   │   │   ├── Home.php
│   │   │   └── Share.php
│   │   ├── Filters/
│   │   ├── Libraries/
│   │   └── Models/
│   ├── vendor/                     ← Composer dependencies
│   ├── writable/                   ← Must be 775
│   │   ├── cache/
│   │   ├── debugbar/
│   │   ├── logs/
│   │   ├── session/
│   │   └── uploads/
│   ├── firebase_service_account.json
│   └── .env                        ← Environment configuration
│
├── public_html/
│   └── eagletv_api/                ← PUBLIC (web-accessible entry point)
│       ├── index.php               ← Front controller (points to ../../eagletv_ci4/)
│       ├── .htaccess               ← Apache rewrite rules
│       └── uploads/                ← User-uploaded files (775)
│           ├── posts/
│           └── profiles/
```

### How the Path Linkage Works

The public `index.php` connects to the private CI4 code via a relative path:

```php
// public_html/eagletv_api/index.php
require FCPATH . '../../eagletv_ci4/app/Config/Paths.php';
```

This resolves to:
```
/home/techmigo/public_html/eagletv_api/../../eagletv_ci4/app/Config/Paths.php
→ /home/techmigo/eagletv_ci4/app/Config/Paths.php
```

---

## 3. Prerequisites

- **cPanel access** with SSH (Terminal) or File Manager
- **PHP 8.2+** (check: `php -v`)
- **MySQL** database support
- **mod_rewrite** enabled (standard on most shared hosts)
- **Deployment package:** `crii_backend_ci4_deploy.zip`

### Optional but Recommended
- PHP `intl` extension (enable via cPanel → Select PHP Version if missing)

---

## 4. Deployment Package Preparation

The deployment package (`crii_backend_ci4_deploy.zip`) is generated locally from the project and contains three directories:

```
crii_backend_ci4_deploy.zip
├── app_root/                      → Goes to ~/eagletv_ci4/
│   ├── app/                       (CI4 application code)
│   ├── vendor/                    (Composer dependencies)
│   ├── writable/                  (writable directories)
│   ├── firebase_service_account.json
│   ├── .env.example
│   └── .htaccess
├── public_html_eagletv_api/       → Goes to ~/public_html/eagletv_api/
│   ├── index.php                  (Front controller)
│   ├── .htaccess                  (Rewrite rules)
│   └── uploads/                   (Upload directories)
└── sql/                           → Import into MySQL
    ├── setup.sql                  (Base schema)
    ├── migrate_v2.sql
    ├── migrate_v3_notifications.sql
    ├── migrate_v4_user_details.sql
    └── migrate_v5_features.sql
```

### Building the Package Locally

From the project root:
```bash
# The deploy package is pre-built at: backend_ci4_deploy/
# To create a zip for upload:
cd /path/to/CRII_Flutter_With_Backend_CI4
zip -r crii_backend_ci4_deploy.zip backend_ci4_deploy/
```

---

## 5. Step-by-Step Deployment

### Step 1 — Upload the Deployment Package

Upload `crii_backend_ci4_deploy.zip` to the server home directory via:
- **cPanel File Manager** → Upload to `/home/techmigo/`
- **SCP:** `scp crii_backend_ci4_deploy.zip techmigo@techmigos.com:~/`

### Step 2 — Extract the Package

```bash
cd ~
unzip crii_backend_ci4_deploy.zip
```

This creates `~/backend_ci4_deploy/` with `app_root/`, `public_html_eagletv_api/`, and `sql/`.

### Step 3 — Set Up CI4 Application Directory

```bash
mkdir -p ~/eagletv_ci4
cp -r ~/backend_ci4_deploy/app_root/* ~/eagletv_ci4/
cp ~/backend_ci4_deploy/app_root/.env.example ~/eagletv_ci4/.env
cp ~/backend_ci4_deploy/app_root/.htaccess ~/eagletv_ci4/
```

### Step 4 — Copy the CI4 System (Vendor)

The `vendor/` directory is included in `app_root/` and was copied in Step 3. Verify:
```bash
ls ~/eagletv_ci4/vendor/codeigniter4/framework/system/Boot.php
```

### Step 5 — Verify PHP Version

```bash
php -v
# Must show PHP 8.2 or higher
```

### Step 6 — Create Writable Directories & Set Permissions

```bash
mkdir -p ~/eagletv_ci4/writable/{cache,logs,session,uploads,debugbar}
chmod -R 775 ~/eagletv_ci4/writable
```

### Step 7 — Set Up Public Directory

```bash
mkdir -p ~/public_html/eagletv_api
cp ~/backend_ci4_deploy/public_html_eagletv_api/index.php ~/public_html/eagletv_api/
cp ~/backend_ci4_deploy/public_html_eagletv_api/.htaccess ~/public_html/eagletv_api/
cp -r ~/backend_ci4_deploy/public_html_eagletv_api/uploads ~/public_html/eagletv_api/
chmod -R 775 ~/public_html/eagletv_api/uploads
```

### Step 8 — Verify Path Linkage

```bash
php -r "echo realpath('/home/techmigo/public_html/eagletv_api/../../eagletv_ci4/app/Config/Paths.php') . PHP_EOL;"
```

Expected output:
```
/home/techmigo/eagletv_ci4/app/Config/Paths.php
```

### Step 9 — Create MySQL Database (via cPanel)

1. Log into **cPanel** → **MySQL Databases**
2. **Create Database:** `techmigo_eagletv_db`
3. **Create User:** `techmigo_eagletv_user` with a strong password
4. **Add User to Database:** Grant `ALL PRIVILEGES`

> **Note:** cPanel prefixes database/user names with the cPanel username. So you create `eagletv_db` and it becomes `techmigo_eagletv_db`.

### Step 10 — Import SQL Migrations

First, strip any `CREATE DATABASE` / `USE` statements from `setup.sql`:
```bash
sed -i '/^CREATE DATABASE/d; /^USE /d;' ~/backend_ci4_deploy/sql/setup.sql
```

Then import all migrations in order:
```bash
mysql -u techmigo_eagletv_user -p'YOUR_PASSWORD' techmigo_eagletv_db < ~/backend_ci4_deploy/sql/setup.sql
mysql -u techmigo_eagletv_user -p'YOUR_PASSWORD' techmigo_eagletv_db < ~/backend_ci4_deploy/sql/migrate_v2.sql
mysql -u techmigo_eagletv_user -p'YOUR_PASSWORD' techmigo_eagletv_db < ~/backend_ci4_deploy/sql/migrate_v3_notifications.sql
mysql -u techmigo_eagletv_user -p'YOUR_PASSWORD' techmigo_eagletv_db < ~/backend_ci4_deploy/sql/migrate_v4_user_details.sql
mysql -u techmigo_eagletv_user -p'YOUR_PASSWORD' techmigo_eagletv_db < ~/backend_ci4_deploy/sql/migrate_v5_features.sql
```

> **Important:** Use **single quotes** around the password to avoid bash expanding special characters like `!`, `^`, `?`.

### Step 11 — Configure Environment

See [Section 6](#6-environment-configuration) below.

### Step 12 — Test the API

```bash
curl -s https://www.techmigos.com/eagletv_api/
```

Expected response:
```json
{
  "status": "ok",
  "message": "CRII API is running (CodeIgniter 4)",
  "framework": "CodeIgniter 4.7.0",
  "database": "connected"
}
```

### Step 13 — Cleanup

```bash
rm -rf ~/backend_ci4_deploy
rm -f ~/crii_backend_ci4_deploy.zip
```

---

## 6. Environment Configuration

Edit `~/eagletv_ci4/.env`:

```bash
nano ~/eagletv_ci4/.env
```

### Complete `.env` File

```ini
CI_ENVIRONMENT = production

app.baseURL = https://www.techmigos.com/eagletv_api/

#--------------------------------------------------------------------
# DATABASE
#--------------------------------------------------------------------

database.default.hostname = localhost
database.default.database = techmigo_eagletv_db
database.default.username = techmigo_eagletv_user
database.default.password = YOUR_DB_PASSWORD_HERE
database.default.DBDriver = MySQLi
database.default.DBPrefix =
database.default.port = 3306
database.default.charset = utf8mb4
database.default.DBCollat = utf8mb4_unicode_ci
```

### Important Notes

| Setting | Rule |
|---------|------|
| `CI_ENVIRONMENT` | Must be `production` on live server |
| `app.baseURL` | **No quotes** — CI4 `.env` parser includes quotes literally |
| `database.default.password` | **No quotes needed** — `.env` is not processed by bash |
| `database.default.DBPrefix` | Leave empty (no prefix used in SQL schema) |

---

## 7. Database Setup

### Database Credentials

| Item     | Value                          |
|----------|--------------------------------|
| Host     | `localhost`                    |
| Database | `techmigo_eagletv_db`          |
| Username | `techmigo_eagletv_user`        |
| Port     | `3306`                         |
| Charset  | `utf8mb4`                      |
| Collation| `utf8mb4_unicode_ci`           |

### SQL Migration Files (Import Order)

| # | File | Description |
|---|------|-------------|
| 1 | `setup.sql` | Base schema — users, posts, comments, likes, bookmarks, follows |
| 2 | `migrate_v2.sql` | Schema updates v2 |
| 3 | `migrate_v3_notifications.sql` | Notifications table |
| 4 | `migrate_v4_user_details.sql` | Extended user details fields |
| 5 | `migrate_v5_features.sql` | Breaking news, alerts, donations, partners, reports, storage config |

> **Always import in order.** Each migration builds on the previous one.

---

## 8. API Endpoints Reference

Base URL: `https://www.techmigos.com/eagletv_api/`

All API endpoints accept an `action` query parameter to specify the operation.

### Route Format

Routes work with and without `.php` extension:
- `GET /api/posts?action=feed` ✓
- `GET /api/posts.php?action=feed` ✓

### Endpoint List

| Endpoint | Methods | Controller | Description |
|----------|---------|------------|-------------|
| `/` | GET | `Home` | Health check — returns API status |
| `/share` | GET | `Share` | Shareable content page (HTML) |
| `/api/posts` | GET, POST, PUT, DELETE | `Api\Posts` | Post CRUD operations |
| `/api/users` | GET, POST, PUT | `Api\Users` | User management |
| `/api/comments` | GET, POST, DELETE | `Api\Comments` | Comment operations |
| `/api/interactions` | POST | `Api\Interactions` | Likes & bookmarks |
| `/api/follows` | GET, POST | `Api\Follows` | Follow/unfollow |
| `/api/upload` | POST | `Api\Upload` | File uploads |
| `/api/notifications` | GET, POST, PUT, DELETE | `Api\Notifications` | Push notifications |
| `/api/breaking_news` | GET, POST | `Api\BreakingNews` | Breaking news management |
| `/api/verify_token` | POST | `Api\VerifyToken` | OTP verification |
| `/api/alerts` | GET, POST, PUT, DELETE | `Api\Alerts` | Emergency alerts |
| `/api/activity_reports` | GET, POST, PUT, DELETE | `Api\ActivityReports` | Activity/analytics |
| `/api/donations` | GET, POST, PUT | `Api\Donations` | Donation management |
| `/api/partners` | GET, POST, PUT | `Api\Partners` | Partner management |
| `/api/reports` | GET, POST, PUT | `Api\Reports` | Content reports |
| `/api/storage` | GET, PUT | `Api\Storage` | Storage configuration |

### Common Actions (Posts Example)

| Action | Method | URL |
|--------|--------|-----|
| Get feed | GET | `/api/posts?action=feed&limit=50&offset=0` |
| Get by status | GET | `/api/posts?action=by_status&status=pending` |
| Get by author | GET | `/api/posts?action=by_author&author_id=123` |

---

## 9. Verification & Testing

### Quick Health Check

```bash
curl -s https://www.techmigos.com/eagletv_api/
```

### Test Specific Endpoints

```bash
# Posts feed
curl -s "https://www.techmigos.com/eagletv_api/api/posts?action=feed"

# Users list
curl -s "https://www.techmigos.com/eagletv_api/api/users?action=list"
```

### Check Error Logs

```bash
cat ~/eagletv_ci4/writable/logs/*.log
```

### Verify Database Connection

The root endpoint (`/`) returns `"database": "connected"` if the DB is accessible.

### Verify File Permissions

```bash
ls -la ~/eagletv_ci4/writable/
# All directories should show 775 (drwxrwxr-x)

ls -la ~/public_html/eagletv_api/uploads/
# Should show 775
```

---

## 10. Troubleshooting

### "Access denied" MySQL Error (ERROR 1045)

- **Cause:** Wrong password or password with special characters
- **Fix:** Use single quotes around password in bash: `-p'YourPass!word'`
- **Alternative:** Reset password in cPanel → MySQL Databases → Change Password

### "event not found" in bash

- **Cause:** Password contains `!` inside double quotes — bash interprets `!` as history expansion
- **Fix:** Use single quotes: `-p'password!here'`

### Empty Response from API

- **Cause:** Missing `?action=` parameter
- **Fix:** All endpoints require `?action=<action_name>` query parameter

### 500 Internal Server Error

1. Check PHP error logs: `cat ~/eagletv_ci4/writable/logs/*.log`
2. Check `.env` for syntax errors (no quotes around values)
3. Verify `CI_ENVIRONMENT = production`
4. Check file permissions on `writable/` (must be 775)

### "Class not found" or Autoload Errors

- Verify `vendor/` directory exists: `ls ~/eagletv_ci4/vendor/codeigniter4/`
- Re-upload `vendor/` from the deployment package if missing

### PHP `intl` Extension Missing

- Go to cPanel → **Select PHP Version**
- Enable the `intl` extension
- This may be needed for CI4's internationalization features

### .htaccess Not Working

- Ensure `mod_rewrite` is enabled
- Check that `.htaccess` file exists in `~/public_html/eagletv_api/`
- Verify `Options +FollowSymlinks` is allowed by the host

---

## 11. Re-deployment / Updates

When updating the backend code, follow these abbreviated steps:

### Quick Update (Code Only, No Schema Changes)

```bash
# 1. Upload new deployment zip
# 2. Extract
unzip -o crii_backend_ci4_deploy.zip

# 3. Update app code only (preserve .env and writable/)
cp -r ~/backend_ci4_deploy/app_root/app/* ~/eagletv_ci4/app/
cp -r ~/backend_ci4_deploy/app_root/vendor/* ~/eagletv_ci4/vendor/

# 4. Update public files if changed
cp ~/backend_ci4_deploy/public_html_eagletv_api/index.php ~/public_html/eagletv_api/
cp ~/backend_ci4_deploy/public_html_eagletv_api/.htaccess ~/public_html/eagletv_api/

# 5. Cleanup
rm -rf ~/backend_ci4_deploy ~/crii_backend_ci4_deploy.zip

# 6. Test
curl -s https://www.techmigos.com/eagletv_api/
```

### Full Update (With Schema Changes)

Follow the full deployment steps but:
- **Skip** database/user creation (Step 9)
- **Only import** the new migration SQL files (Step 10)
- **Do NOT** overwrite `.env` — it contains your live credentials

### Files to NEVER Overwrite on Server

| File | Reason |
|------|--------|
| `~/eagletv_ci4/.env` | Contains production database credentials |
| `~/eagletv_ci4/writable/*` | Contains runtime logs, cache, and session data |
| `~/eagletv_ci4/firebase_service_account.json` | May have production Firebase keys |

---

## 12. Security Notes

1. **`.env` file** is outside the web root — not directly accessible via browser
2. **CI4 app code** is in `~/eagletv_ci4/` (private) — not in `public_html`
3. **`CI_ENVIRONMENT = production`** disables debug output and detailed error pages
4. **Database credentials** should use a dedicated user with only necessary privileges
5. **Uploads directory** is the only writable folder inside `public_html`
6. **`.htaccess`** blocks directory listing (`Options -Indexes`)

### Password Handling

- Database password in `.env`: no quotes needed (raw value)
- Database password in bash/SSH: use **single quotes** to prevent special char expansion
- Avoid storing passwords in shell history (`history -c` to clear)

---

## Appendix: Flutter App Configuration

Update the Flutter app's API base URL to point to the deployed backend:

```dart
// In your API configuration
static const String baseUrl = 'https://www.techmigos.com/eagletv_api';
```

Ensure all API calls use this base URL with the correct endpoint paths (e.g., `$baseUrl/api/posts?action=feed`).

---

*Last updated: February 11, 2026*
