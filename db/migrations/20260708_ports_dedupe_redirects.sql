-- FPW Great Loop Ports duplicate URL preservation
-- Creates a Ports-only redirect table for duplicate public slug segments.
-- This table intentionally does not foreign-key old_port_id because the
-- duplicate port row may be removed after the redirect is recorded.

CREATE TABLE IF NOT EXISTS port_slug_redirects (
  id int NOT NULL AUTO_INCREMENT,
  old_port_id int NOT NULL,
  old_slug varchar(220) NOT NULL,
  canonical_port_id int NOT NULL,
  canonical_slug varchar(220) NOT NULL,
  reason varchar(120) DEFAULT 'ports_dedupe',
  created_at datetime DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_port_slug_redirect_old_slug (old_slug),
  KEY idx_port_slug_redirect_old_port_id (old_port_id),
  KEY idx_port_slug_redirect_canonical_port_id (canonical_port_id),
  CONSTRAINT fk_port_slug_redirects_canonical_port
    FOREIGN KEY (canonical_port_id) REFERENCES ports(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

