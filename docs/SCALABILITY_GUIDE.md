# CRII Backend — Scalability & Concurrent Users Guide

## Current Architecture

```
Flutter App (Mobile/Web)
    ↓ HTTP/REST
PHP Backend (Apache + mod_php)
    ↓ PDO
MySQL Database
```

## How Many Concurrent Users Can It Handle?

### Shared Hosting (cPanel Typical)
| Metric | Estimate |
|--------|----------|
| Concurrent connections | **50-100** |
| Requests/second | **20-50** |
| Suitable for | Small community (< 500 daily users) |

### VPS (2GB RAM, 2 vCPU)
| Metric | Estimate |
|--------|----------|
| Concurrent connections | **200-500** |
| Requests/second | **100-200** |
| Suitable for | Medium community (500-5,000 daily users) |

### Dedicated Server (8GB RAM, 4 vCPU)
| Metric | Estimate |
|--------|----------|
| Concurrent connections | **1,000-2,000** |
| Requests/second | **500-1,000** |
| Suitable for | Large community (5,000-50,000 daily users) |

## Scaling Strategies

### 1. Database Optimization (First Priority)

```sql
-- Add indexes for frequently queried columns
CREATE INDEX idx_posts_created ON posts(created_at DESC);
CREATE INDEX idx_posts_status ON posts(status);
CREATE INDEX idx_posts_user ON posts(user_id);
CREATE INDEX idx_notifications_user ON notifications(user_id, read_at);
CREATE INDEX idx_comments_post ON comments(post_id, created_at);
CREATE INDEX idx_follows_follower ON follows(follower_id);
CREATE INDEX idx_follows_following ON follows(following_id);
CREATE INDEX idx_donations_status ON donations(status, created_at);
```

### 2. PHP Connection Pooling

Add persistent connections in `config.php`:
```php
$pdo = new PDO(
    "mysql:host=" . DB_HOST . ";dbname=" . DB_NAME . ";charset=utf8mb4",
    DB_USER,
    DB_PASS,
    [
        PDO::ATTR_PERSISTENT => true,  // ← Connection pooling
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
    ]
);
```

### 3. Caching Layer

Add APCu or Redis caching for frequently accessed data:

```php
// In config.php — simple APCu cache helper
function cache_get(string $key, callable $fallback, int $ttl = 300) {
    if (function_exists('apcu_fetch')) {
        $cached = apcu_fetch($key, $success);
        if ($success) return $cached;
    }
    $value = $fallback();
    if (function_exists('apcu_store')) {
        apcu_store($key, $value, $ttl);
    }
    return $value;
}

// Usage in posts.php
$trending = cache_get('trending_posts', function() use ($db) {
    $stmt = $db->query("SELECT * FROM posts WHERE status='approved' ORDER BY likes DESC LIMIT 20");
    return $stmt->fetchAll();
}, 300); // Cache for 5 minutes
```

### 4. Image/Upload Optimization

- **CDN**: Move uploads to Cloudflare R2, AWS S3, or BunnyCDN
- **Image resizing**: Add server-side thumbnails (GD library)
- **Lazy loading**: Already implemented in Flutter via `CachedNetworkImage`

### 5. API Response Pagination

Ensure all list endpoints use pagination:
```php
$page = max(1, intval(param('page', 1)));
$limit = min(50, max(10, intval(param('limit', 20))));
$offset = ($page - 1) * $limit;

$stmt = $db->prepare("SELECT * FROM posts ORDER BY created_at DESC LIMIT ? OFFSET ?");
$stmt->execute([$limit, $offset]);
```

### 6. Rate Limiting

```php
// Simple rate limiter using APCu
function rate_limit(string $identifier, int $max = 60, int $window = 60): bool {
    if (!function_exists('apcu_fetch')) return true;
    
    $key = "rate:$identifier";
    $count = apcu_fetch($key, $success);
    
    if (!$success) {
        apcu_store($key, 1, $window);
        return true;
    }
    
    if ($count >= $max) {
        http_response_code(429);
        echo json_encode(['error' => 'Too many requests']);
        exit();
    }
    
    apcu_inc($key);
    return true;
}

// Usage: rate_limit($_SERVER['REMOTE_ADDR']); // 60 requests per minute per IP
```

### 7. When to Scale Beyond Shared Hosting

Migrate to a VPS when you see:
- Response times > 500ms consistently
- Database connection errors
- Upload timeouts
- 500+ daily active users

**Recommended VPS providers**: DigitalOcean ($12/mo), Hostinger VPS ($6/mo), AWS Lightsail ($5/mo)

## Flutter App Optimizations for Scale

1. **Local caching**: SharedPreferences for user data, cached_network_image for media
2. **Pagination**: Load 20 posts at a time, infinite scroll
3. **Debounced search**: Already implemented (300ms debounce)
4. **Offline queue**: Queue actions when offline, sync when connected
5. **FCM for real-time**: Push instead of polling for notifications
