-- Select the target fpw database first. Run with a client that stops on the first SQL error; never use --force.
-- No deployment or database execution is implied by this file.
-- SELECT-only aggregate verification; does not display email addresses.
SELECT DATABASE() AS selected_database, VERSION() AS database_version;
SELECT COLUMN_NAME,COLUMN_TYPE,COLLATION_NAME FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='users' AND COLUMN_NAME='email';
SELECT INDEX_NAME,NON_UNIQUE,SEQ_IN_INDEX,COLUMN_NAME,SUB_PART FROM information_schema.STATISTICS
WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='users' AND INDEX_NAME='uq_users_email';
SELECT
 (SELECT COUNT(*) FROM users WHERE CAST(email AS BINARY) <> CAST(TRIM(email) AS BINARY)
   OR email REGEXP '^[[:space:]]|[[:space:]]$') AS nontrimmed_emails,
 (SELECT COUNT(*) FROM (SELECT email FROM users GROUP BY email HAVING COUNT(*) > 1) AS collisions) AS colliding_email_groups,
 CASE WHEN (SELECT COUNT(*) FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='users'
   AND INDEX_NAME='uq_users_email' AND NON_UNIQUE=0 AND SEQ_IN_INDEX=1 AND COLUMN_NAME='email' AND SUB_PART IS NULL)=1
   AND (SELECT COUNT(*) FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='users'
   AND INDEX_NAME='uq_users_email')=1 THEN 'PASS' ELSE 'FAIL' END AS index_status;
