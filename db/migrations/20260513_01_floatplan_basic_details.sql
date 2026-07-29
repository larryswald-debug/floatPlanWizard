-- FPW Basic one-time float plan details.
-- Additive migration only. Keeps floatplans as lifecycle/status authority.

CREATE TABLE IF NOT EXISTS floatplan_basic_details (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  floatplan_id INT NOT NULL,
  vessel_name VARCHAR(255) NOT NULL,
  operator_name VARCHAR(255) NOT NULL,
  captain_name VARCHAR(255) NOT NULL,
  captain_email VARCHAR(255) NOT NULL,
  notification_contact_name VARCHAR(255) NOT NULL,
  notification_contact_email VARCHAR(255) NOT NULL,
  notification_contact_phone VARCHAR(45) NULL,
  launch_location VARCHAR(255) NOT NULL,
  destination_location VARCHAR(255) NOT NULL,
  authority_id INT NULL,
  authority_name_snapshot VARCHAR(255) NOT NULL,
  authority_phone_snapshot VARCHAR(45) NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_floatplan_basic_details_plan (floatplan_id),
  KEY idx_floatplan_basic_details_authority (authority_id),
  KEY idx_floatplan_basic_details_contact_email (notification_contact_email)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
