-- Great Loop Ports admin image support
-- Adds a single primary image reference per port for the admin Ports manager.
-- Safe/idempotent: creates the table only if missing and does not alter existing port data.

CREATE TABLE IF NOT EXISTS port_images (
  port_id int NOT NULL,
  local_image_path varchar(500) DEFAULT NULL,
  thumbnail_image_path varchar(500) DEFAULT NULL,
  original_filename varchar(255) DEFAULT NULL,
  mime_type varchar(120) DEFAULT NULL,
  image_alt varchar(255) DEFAULT NULL,
  image_credit text,
  image_license varchar(255) DEFAULT NULL,
  image_source text,
  image_allowed_for_fpw tinyint(1) NOT NULL DEFAULT 1,
  created_at datetime DEFAULT CURRENT_TIMESTAMP,
  updated_at datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (port_id),
  KEY idx_port_images_allowed (image_allowed_for_fpw),
  CONSTRAINT fk_port_images_port
    FOREIGN KEY (port_id) REFERENCES ports(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

