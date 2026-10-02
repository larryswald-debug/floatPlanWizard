-- Select the target fpw database first. Run with a client that stops on the first SQL error; never use --force.
-- No deployment or database execution is implied by this file.
SET @fpw_20261001_002_error = CASE
  WHEN DATABASE() IS NULL THEN 'No database is selected.'
  WHEN CAST(LOWER(DATABASE()) AS BINARY) <> CAST('fpw' AS BINARY) THEN 'Selected database must be fpw (case-insensitive).'
  WHEN (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='users' AND ENGINE='InnoDB') <> 1
    THEN 'users must exist as an InnoDB table.'
  WHEN (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='users'
    AND COLUMN_NAME='email' AND DATA_TYPE='varchar' AND CHARACTER_MAXIMUM_LENGTH=255
    AND IS_NULLABLE='NO' AND COLLATION_NAME LIKE '%_ci') <> 1
    THEN 'users.email must be NOT NULL VARCHAR(255) with its existing case-insensitive collation.'
  WHEN (SELECT COUNT(*) FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=DATABASE()
    AND TABLE_NAME='users' AND INDEX_NAME='uq_users_email') <> 0
    THEN 'uq_users_email already exists; do not rerun this migration.'
  WHEN (SELECT COUNT(*) FROM users WHERE CAST(email AS BINARY) <> CAST(TRIM(email) AS BINARY)
    OR email REGEXP '^[[:space:]]|[[:space:]]$') <> 0
    THEN 'Nontrimmed emails exist. Stop for an explicit data decision; this migration does not repair accounts.'
  WHEN (SELECT COUNT(*) FROM (SELECT email FROM users GROUP BY email HAVING COUNT(*) > 1) AS collisions) <> 0
    THEN 'Email identities collide under the existing collation. Stop; this migration does not merge or repair accounts.'
  ELSE NULL END;
SELECT @fpw_20261001_002_error AS migration_error;
SET @fpw_20261001_002_guard_sql = IF(@fpw_20261001_002_error IS NULL, 'DO 0',
  'SELECT `_fpw_up_20261001_002_refused` FROM (SELECT 1 AS ok) AS _fpw_guard');
PREPARE fpw_20261001_002_guard FROM @fpw_20261001_002_guard_sql;
EXECUTE fpw_20261001_002_guard;
DEALLOCATE PREPARE fpw_20261001_002_guard;

-- Preserve existing email values and their current collation. New application writes normalize lower(trim(email)).
ALTER TABLE users ADD UNIQUE KEY uq_users_email (email);
