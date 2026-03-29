-- ============================================================
-- CRII MySQL Schema
-- Run this in phpMyAdmin (http://localhost/phpmyadmin)
-- or via MySQL CLI: mysql -u root < setup.sql
-- ============================================================

CREATE DATABASE IF NOT EXISTS eagletv_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE eagletv_db;

-- ==================== USERS TABLE ====================
CREATE TABLE IF NOT EXISTS users (
  id VARCHAR(64) PRIMARY KEY,
  phone_number VARCHAR(20) DEFAULT NULL,
  email VARCHAR(255) DEFAULT NULL,
  display_name VARCHAR(100) NOT NULL DEFAULT 'User',
  profile_picture TEXT DEFAULT NULL,
  bio TEXT DEFAULT NULL,
  area VARCHAR(100) DEFAULT NULL,
  district VARCHAR(100) DEFAULT NULL,
  state VARCHAR(100) DEFAULT NULL,
  role ENUM('superAdmin','admin','reporter','publicUser') NOT NULL DEFAULT 'publicUser',
  is_subscribed TINYINT(1) DEFAULT 0,
  preferred_language VARCHAR(5) DEFAULT 'en',
  subscription_plan_type ENUM('free','premium','elite') DEFAULT NULL,
  subscription_expires_at DATETIME DEFAULT NULL,
  fcm_token TEXT DEFAULT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- ==================== POSTS TABLE ====================
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

-- ==================== COMMENTS TABLE ====================
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

-- ==================== LIKES TABLE ====================
CREATE TABLE IF NOT EXISTS post_likes (
  id VARCHAR(64) PRIMARY KEY,
  post_id VARCHAR(64) NOT NULL,
  user_id VARCHAR(64) NOT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY unique_like (post_id, user_id),
  FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ==================== BOOKMARKS TABLE ====================
CREATE TABLE IF NOT EXISTS post_bookmarks (
  id VARCHAR(64) PRIMARY KEY,
  post_id VARCHAR(64) NOT NULL,
  user_id VARCHAR(64) NOT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY unique_bookmark (post_id, user_id),
  FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ==================== INDEXES ====================
CREATE INDEX idx_posts_author ON posts(author_id);
CREATE INDEX idx_posts_status ON posts(status);
CREATE INDEX idx_posts_created ON posts(created_at DESC);
CREATE INDEX idx_posts_category ON posts(category);
CREATE INDEX idx_comments_post ON comments(post_id);
CREATE INDEX idx_likes_post ON post_likes(post_id);
CREATE INDEX idx_likes_user ON post_likes(user_id);
CREATE INDEX idx_bookmarks_user ON post_bookmarks(user_id);
CREATE INDEX idx_users_role ON users(role);
CREATE INDEX idx_users_district ON users(district);
CREATE INDEX idx_users_state ON users(state);

-- ==================== NOTIFICATIONS TABLE (v2) ====================
CREATE TABLE IF NOT EXISTS notifications (
  id VARCHAR(64) PRIMARY KEY,
  user_id VARCHAR(64) NOT NULL,
  title VARCHAR(255) NOT NULL,
  body TEXT NOT NULL,
  type ENUM('post_approved','post_rejected','post_edited','new_content','new_post_pending','post_resubmitted','like','comment','follower','breaking_news','system') NOT NULL DEFAULT 'system',
  is_read TINYINT(1) DEFAULT 0,
  action_data TEXT DEFAULT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE INDEX idx_notifications_user ON notifications(user_id);
CREATE INDEX idx_notifications_read ON notifications(user_id, is_read);

-- ==================== FOLLOWS TABLE (v2) ====================
CREATE TABLE IF NOT EXISTS user_follows (
  id VARCHAR(64) PRIMARY KEY,
  follower_id VARCHAR(64) NOT NULL,
  following_id VARCHAR(64) NOT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY unique_follow (follower_id, following_id),
  FOREIGN KEY (follower_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (following_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE INDEX idx_follows_follower ON user_follows(follower_id);
CREATE INDEX idx_follows_following ON user_follows(following_id);

-- ==================== CONTENT REPORTS TABLE (v2) ====================
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

CREATE INDEX idx_reports_status ON content_reports(status);
CREATE INDEX idx_reports_post ON content_reports(post_id);

-- ==================== STORAGE CONFIG TABLE (v4) ====================
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

-- ==================== PARTNERS TABLE (v5) ====================
CREATE TABLE IF NOT EXISTS partners (
  id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  phone_number VARCHAR(20) NOT NULL,
  district VARCHAR(100) NOT NULL,
  state VARCHAR(100) NOT NULL,
  profession VARCHAR(255) NOT NULL,
  institution VARCHAR(255) DEFAULT NULL,
  place_of_worship VARCHAR(255) DEFAULT NULL,
  user_id VARCHAR(255) DEFAULT NULL,
  status ENUM('pending','approved','rejected') DEFAULT 'approved',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY unique_phone (phone_number),
  INDEX idx_partner_status (status),
  INDEX idx_partner_district (district)
) ENGINE=InnoDB;

-- ==================== EMERGENCY ALERTS TABLE (v5) ====================
CREATE TABLE IF NOT EXISTS emergency_alerts (
  id INT AUTO_INCREMENT PRIMARY KEY,
  title VARCHAR(255) NOT NULL,
  title_te VARCHAR(255) DEFAULT NULL,
  title_hi VARCHAR(255) DEFAULT NULL,
  description TEXT NOT NULL,
  description_te TEXT DEFAULT NULL,
  description_hi TEXT DEFAULT NULL,
  severity ENUM('critical','high','medium') DEFAULT 'medium',
  district VARCHAR(100) DEFAULT NULL,
  state VARCHAR(100) DEFAULT NULL,
  is_active TINYINT(1) DEFAULT 1,
  created_by VARCHAR(255) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  expires_at TIMESTAMP NULL DEFAULT NULL,
  INDEX idx_alert_active (is_active),
  INDEX idx_alert_severity (severity)
) ENGINE=InnoDB;

-- ==================== DONATIONS TABLE (REMOVED) ====================
-- Donation feature has been removed from the application.

-- ==================== ACTIVITY REPORTS TABLE (v5) ====================
CREATE TABLE IF NOT EXISTS activity_reports (
  id INT AUTO_INCREMENT PRIMARY KEY,
  report_type ENUM('daily','weekly','monthly') DEFAULT 'daily',
  title VARCHAR(255) NOT NULL,
  content TEXT DEFAULT NULL,
  activities INT DEFAULT 0,
  incidents INT DEFAULT 0,
  outreach_count INT DEFAULT 0,
  period_start DATE NOT NULL,
  period_end DATE NOT NULL,
  author_id VARCHAR(255) NOT NULL,
  author_name VARCHAR(255) DEFAULT NULL,
  district VARCHAR(100) DEFAULT NULL,
  state VARCHAR(100) DEFAULT NULL,
  status ENUM('draft','published') DEFAULT 'draft',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_report_type (report_type),
  INDEX idx_report_author (author_id),
  INDEX idx_report_status (status)
) ENGINE=InnoDB;
