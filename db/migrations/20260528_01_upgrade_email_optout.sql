-- Upgrade existing email_optout table for signed non-essential email opt-outs.
-- Existing email_optout remains the canonical opt-out authority.

SET @schema_name := DATABASE();

SET @sql_add_user_id := IF(
  (SELECT COUNT(*)
   FROM information_schema.columns
   WHERE table_schema = @schema_name
     AND table_name = 'email_optout'
     AND column_name = 'user_id') = 0,
  'ALTER TABLE email_optout ADD COLUMN user_id INT NULL AFTER recId',
  'SELECT 1'
);
PREPARE stmt_add_user_id FROM @sql_add_user_id;
EXECUTE stmt_add_user_id;
DEALLOCATE PREPARE stmt_add_user_id;

SET @sql_add_email_hash := IF(
  (SELECT COUNT(*)
   FROM information_schema.columns
   WHERE table_schema = @schema_name
     AND table_name = 'email_optout'
     AND column_name = 'email_hash') = 0,
  'ALTER TABLE email_optout ADD COLUMN email_hash CHAR(64) NULL AFTER email',
  'SELECT 1'
);
PREPARE stmt_add_email_hash FROM @sql_add_email_hash;
EXECUTE stmt_add_email_hash;
DEALLOCATE PREPARE stmt_add_email_hash;

SET @sql_add_opt_out_type := IF(
  (SELECT COUNT(*)
   FROM information_schema.columns
   WHERE table_schema = @schema_name
     AND table_name = 'email_optout'
     AND column_name = 'opt_out_type') = 0,
  'ALTER TABLE email_optout ADD COLUMN opt_out_type VARCHAR(40) NOT NULL DEFAULT ''non_essential'' AFTER email_hash',
  'SELECT 1'
);
PREPARE stmt_add_opt_out_type FROM @sql_add_opt_out_type;
EXECUTE stmt_add_opt_out_type;
DEALLOCATE PREPARE stmt_add_opt_out_type;

SET @sql_add_source := IF(
  (SELECT COUNT(*)
   FROM information_schema.columns
   WHERE table_schema = @schema_name
     AND table_name = 'email_optout'
     AND column_name = 'source') = 0,
  'ALTER TABLE email_optout ADD COLUMN source VARCHAR(80) NULL AFTER opt_out_type',
  'SELECT 1'
);
PREPARE stmt_add_source FROM @sql_add_source;
EXECUTE stmt_add_source;
DEALLOCATE PREPARE stmt_add_source;

SET @sql_add_ip_hash := IF(
  (SELECT COUNT(*)
   FROM information_schema.columns
   WHERE table_schema = @schema_name
     AND table_name = 'email_optout'
     AND column_name = 'ip_hash') = 0,
  'ALTER TABLE email_optout ADD COLUMN ip_hash CHAR(64) NULL AFTER source',
  'SELECT 1'
);
PREPARE stmt_add_ip_hash FROM @sql_add_ip_hash;
EXECUTE stmt_add_ip_hash;
DEALLOCATE PREPARE stmt_add_ip_hash;

SET @sql_add_user_agent_hash := IF(
  (SELECT COUNT(*)
   FROM information_schema.columns
   WHERE table_schema = @schema_name
     AND table_name = 'email_optout'
     AND column_name = 'user_agent_hash') = 0,
  'ALTER TABLE email_optout ADD COLUMN user_agent_hash CHAR(64) NULL AFTER ip_hash',
  'SELECT 1'
);
PREPARE stmt_add_user_agent_hash FROM @sql_add_user_agent_hash;
EXECUTE stmt_add_user_agent_hash;
DEALLOCATE PREPARE stmt_add_user_agent_hash;

SET @sql_add_created_at := IF(
  (SELECT COUNT(*)
   FROM information_schema.columns
   WHERE table_schema = @schema_name
     AND table_name = 'email_optout'
     AND column_name = 'created_at') = 0,
  'ALTER TABLE email_optout ADD COLUMN created_at DATETIME NULL AFTER date_added',
  'SELECT 1'
);
PREPARE stmt_add_created_at FROM @sql_add_created_at;
EXECUTE stmt_add_created_at;
DEALLOCATE PREPARE stmt_add_created_at;

SET @sql_add_updated_at := IF(
  (SELECT COUNT(*)
   FROM information_schema.columns
   WHERE table_schema = @schema_name
     AND table_name = 'email_optout'
     AND column_name = 'updated_at') = 0,
  'ALTER TABLE email_optout ADD COLUMN updated_at DATETIME NULL AFTER created_at',
  'SELECT 1'
);
PREPARE stmt_add_updated_at FROM @sql_add_updated_at;
EXECUTE stmt_add_updated_at;
DEALLOCATE PREPARE stmt_add_updated_at;

UPDATE email_optout
SET email_hash = SHA2(LOWER(TRIM(email)), 256)
WHERE email_hash IS NULL
  AND email IS NOT NULL
  AND LENGTH(TRIM(email)) > 0;

UPDATE email_optout
SET opt_out_type = 'non_essential'
WHERE opt_out_type IS NULL
   OR LENGTH(TRIM(opt_out_type)) = 0;

UPDATE email_optout
SET created_at = date_added
WHERE created_at IS NULL
  AND date_added IS NOT NULL;

UPDATE email_optout
SET updated_at = lastUpdate
WHERE updated_at IS NULL
  AND lastUpdate IS NOT NULL;

SET @sql_add_email_hash_type_idx := IF(
  (SELECT COUNT(*)
   FROM information_schema.statistics
   WHERE table_schema = @schema_name
     AND table_name = 'email_optout'
     AND index_name = 'uq_email_optout_hash_type') = 0,
  'ALTER TABLE email_optout ADD UNIQUE KEY uq_email_optout_hash_type (email_hash, opt_out_type)',
  'SELECT 1'
);
PREPARE stmt_add_email_hash_type_idx FROM @sql_add_email_hash_type_idx;
EXECUTE stmt_add_email_hash_type_idx;
DEALLOCATE PREPARE stmt_add_email_hash_type_idx;

SET @sql_add_user_type_idx := IF(
  (SELECT COUNT(*)
   FROM information_schema.statistics
   WHERE table_schema = @schema_name
     AND table_name = 'email_optout'
     AND index_name = 'idx_email_optout_user_type') = 0,
  'ALTER TABLE email_optout ADD INDEX idx_email_optout_user_type (user_id, opt_out_type)',
  'SELECT 1'
);
PREPARE stmt_add_user_type_idx FROM @sql_add_user_type_idx;
EXECUTE stmt_add_user_type_idx;
DEALLOCATE PREPARE stmt_add_user_type_idx;
