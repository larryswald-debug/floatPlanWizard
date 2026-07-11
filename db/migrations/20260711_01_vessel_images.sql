-- Vessel image support
-- Adds one public/shareable primary image record per vessel.

CREATE TABLE IF NOT EXISTS vessel_images (
  vessel_id int NOT NULL,
  local_image_path varchar(500) DEFAULT NULL,
  thumbnail_image_path varchar(500) DEFAULT NULL,
  original_filename varchar(255) DEFAULT NULL,
  mime_type varchar(120) DEFAULT NULL,
  created_at datetime DEFAULT CURRENT_TIMESTAMP,
  updated_at datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (vessel_id),
  CONSTRAINT fk_vessel_images_vessel
    FOREIGN KEY (vessel_id) REFERENCES vessels(vesselID)
    ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

