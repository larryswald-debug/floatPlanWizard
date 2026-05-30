-- Add hashed password-reset token storage to users.
-- Legacy requestReset/resetId columns are preserved for compatibility.

SET @schema_name := DATABASE();

SET @sql_add_reset_token_hash := IF(
  (SELECT COUNT(*)
   FROM information_schema.columns
   WHERE table_schema = @schema_name
     AND table_name = 'users'
     AND column_name = 'resetTokenHash') = 0,
  'ALTER TABLE users ADD COLUMN resetTokenHash CHAR(64) NULL AFTER resetId',
  'SELECT 1'
);
PREPARE stmt_add_reset_token_hash FROM @sql_add_reset_token_hash;
EXECUTE stmt_add_reset_token_hash;
DEALLOCATE PREPARE stmt_add_reset_token_hash;

SET @sql_add_reset_requested_at := IF(
  (SELECT COUNT(*)
   FROM information_schema.columns
   WHERE table_schema = @schema_name
     AND table_name = 'users'
     AND column_name = 'resetRequestedAt') = 0,
  'ALTER TABLE users ADD COLUMN resetRequestedAt DATETIME NULL AFTER resetTokenHash',
  'SELECT 1'
);
PREPARE stmt_add_reset_requested_at FROM @sql_add_reset_requested_at;
EXECUTE stmt_add_reset_requested_at;
DEALLOCATE PREPARE stmt_add_reset_requested_at;

SET @sql_add_reset_expires_at := IF(
  (SELECT COUNT(*)
   FROM information_schema.columns
   WHERE table_schema = @schema_name
     AND table_name = 'users'
     AND column_name = 'resetExpiresAt') = 0,
  'ALTER TABLE users ADD COLUMN resetExpiresAt DATETIME NULL AFTER resetRequestedAt',
  'SELECT 1'
);
PREPARE stmt_add_reset_expires_at FROM @sql_add_reset_expires_at;
EXECUTE stmt_add_reset_expires_at;
DEALLOCATE PREPARE stmt_add_reset_expires_at;

SET @sql_add_reset_token_hash_idx := IF(
  (SELECT COUNT(*)
   FROM information_schema.statistics
   WHERE table_schema = @schema_name
     AND table_name = 'users'
     AND index_name = 'idx_users_reset_token_hash') = 0,
  'ALTER TABLE users ADD INDEX idx_users_reset_token_hash (resetTokenHash)',
  'SELECT 1'
);
PREPARE stmt_add_reset_token_hash_idx FROM @sql_add_reset_token_hash_idx;
EXECUTE stmt_add_reset_token_hash_idx;
DEALLOCATE PREPARE stmt_add_reset_token_hash_idx;
