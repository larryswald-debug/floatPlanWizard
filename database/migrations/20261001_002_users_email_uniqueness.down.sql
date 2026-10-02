-- Select the target fpw database first. Run with a client that stops on the first SQL error; never use --force.
-- No deployment or database execution is implied by this file.
-- Disable new account creation first; application signup must fail closed without uniqueness protection.
-- PBKDF2 readers must remain deployed once any adaptive password has been written.
SET @fpw_20261001_002_down_error = CASE
  WHEN DATABASE() IS NULL THEN 'No database is selected.'
  WHEN CAST(LOWER(DATABASE()) AS BINARY) <> CAST('fpw' AS BINARY) THEN 'Selected database must be fpw (case-insensitive).'
  WHEN COALESCE(@fpw_confirm_email_unique_rollback,'') <> 'ROLLBACK_USERS_EMAIL_UNIQUENESS'
    THEN 'Set @fpw_confirm_email_unique_rollback to ROLLBACK_USERS_EMAIL_UNIQUENESS explicitly.'
  WHEN (SELECT COUNT(*) FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='users'
    AND INDEX_NAME='uq_users_email' AND NON_UNIQUE=0 AND SEQ_IN_INDEX=1 AND COLUMN_NAME='email' AND SUB_PART IS NULL) <> 1
    THEN 'Expected full-column uq_users_email unique index is absent.'
  ELSE NULL END;
SELECT @fpw_20261001_002_down_error AS migration_error;
SET @fpw_20261001_002_down_guard_sql = IF(@fpw_20261001_002_down_error IS NULL, 'DO 0',
  'SELECT `_fpw_down_20261001_002_refused` FROM (SELECT 1 AS ok) AS _fpw_guard');
PREPARE fpw_20261001_002_down_guard FROM @fpw_20261001_002_down_guard_sql;
EXECUTE fpw_20261001_002_down_guard;
DEALLOCATE PREPARE fpw_20261001_002_down_guard;
ALTER TABLE users DROP INDEX uq_users_email;
SET @fpw_confirm_email_unique_rollback=NULL;
