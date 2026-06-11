CREATE TABLE IF NOT EXISTS user_stripe_customers (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id INT NOT NULL,
  stripe_customer_id VARCHAR(255) NOT NULL,
  email_snapshot VARCHAR(255) NULL,
  name_snapshot VARCHAR(255) NULL,
  source VARCHAR(80) NOT NULL DEFAULT 'fpw_signup',
  created_at_utc DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at_utc DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_user_stripe_customers_user (user_id),
  UNIQUE KEY uq_user_stripe_customers_customer (stripe_customer_id),
  KEY idx_user_stripe_customers_updated (updated_at_utc)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
