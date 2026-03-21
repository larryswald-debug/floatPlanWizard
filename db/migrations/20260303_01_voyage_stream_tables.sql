-- FPW Voyage Stream MVP tables
-- Additive migration only. Do not auto-run in production without review.

CREATE TABLE IF NOT EXISTS voyage_streams (
  id INT NOT NULL AUTO_INCREMENT,
  floatplan_id INT NOT NULL,
  owner_user_id INT NOT NULL,
  slug VARCHAR(120) NOT NULL,
  share_token VARCHAR(96) NOT NULL,
  privacy_mode ENUM('public', 'password', 'invite') NOT NULL DEFAULT 'public',
  password_hash VARCHAR(128) NULL,
  allow_interactions TINYINT(1) NOT NULL DEFAULT 1,
  created_utc DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_utc DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_voyage_streams_slug (slug),
  KEY idx_voyage_streams_owner (owner_user_id),
  KEY idx_voyage_streams_floatplan (floatplan_id),
  KEY idx_voyage_streams_share_token (share_token)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS voyage_followers (
  id INT NOT NULL AUTO_INCREMENT,
  stream_id INT NOT NULL,
  display_name VARCHAR(120) NOT NULL,
  email VARCHAR(255) NULL,
  access_token VARCHAR(96) NOT NULL,
  is_blocked TINYINT(1) NOT NULL DEFAULT 0,
  created_utc DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  last_seen_utc DATETIME NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_voyage_followers_access_token (access_token),
  UNIQUE KEY uq_voyage_followers_stream_email (stream_id, email),
  KEY idx_voyage_followers_stream (stream_id),
  KEY idx_voyage_followers_stream_token (stream_id, access_token)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS voyage_posts (
  id INT NOT NULL AUTO_INCREMENT,
  stream_id INT NOT NULL,
  author_type ENUM('system', 'owner', 'follower') NOT NULL DEFAULT 'system',
  author_user_id INT NULL,
  follower_id INT NULL,
  title VARCHAR(255) NULL,
  body TEXT NULL,
  post_type ENUM('system_event', 'text', 'photo') NOT NULL DEFAULT 'text',
  event_type VARCHAR(64) NULL,
  location_label VARCHAR(255) NULL,
  lat DECIMAL(10,7) NULL,
  lng DECIMAL(10,7) NULL,
  media_url VARCHAR(500) NULL,
  media_thumb_url VARCHAR(500) NULL,
  created_utc DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_voyage_posts_stream_created (stream_id, created_utc),
  KEY idx_voyage_posts_stream_id (stream_id, id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS voyage_reactions (
  id INT NOT NULL AUTO_INCREMENT,
  post_id INT NOT NULL,
  follower_id INT NOT NULL,
  emoji ENUM('like', 'love', 'boat', 'wave') NOT NULL,
  created_utc DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_voyage_reactions_post_follower_emoji (post_id, follower_id, emoji),
  KEY idx_voyage_reactions_post (post_id),
  KEY idx_voyage_reactions_follower (follower_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS voyage_comments (
  id INT NOT NULL AUTO_INCREMENT,
  post_id INT NOT NULL,
  follower_id INT NOT NULL,
  body VARCHAR(500) NOT NULL,
  is_deleted TINYINT(1) NOT NULL DEFAULT 0,
  created_utc DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  deleted_utc DATETIME NULL,
  PRIMARY KEY (id),
  KEY idx_voyage_comments_post_created (post_id, created_utc),
  KEY idx_voyage_comments_follower (follower_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
