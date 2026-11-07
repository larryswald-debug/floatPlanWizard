-- Select FPW (development) or fpw (production) explicitly. Additive; no enrollment backfill.
-- Run with a client that stops on errors. This migration is not rerunnable.
SET @fpw_beta_guard = IF(BINARY DATABASE() IN ('FPW','fpw'), 'DO 0', 'SELECT `_fpw_beta_select_database_first`');
PREPARE fpw_beta_guard FROM @fpw_beta_guard;
EXECUTE fpw_beta_guard;
DEALLOCATE PREPARE fpw_beta_guard;
CREATE TABLE fpw_beta_participation (
 user_id INT NOT NULL PRIMARY KEY,
 status VARCHAR(12) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT 'INVITED',
 recruitment_source VARCHAR(24) NOT NULL,
 invited_by_user_id INT NOT NULL,
 invited_at_utc DATETIME(6) NOT NULL,
 enrolled_at_utc DATETIME(6) NULL,
 withdrawn_at_utc DATETIME(6) NULL,
 acceptance_version VARCHAR(40) NULL,
 entitlement_id BIGINT UNSIGNED NULL,
 CONSTRAINT ck_beta_state CHECK (
  (status='INVITED' AND enrolled_at_utc IS NULL AND withdrawn_at_utc IS NULL AND acceptance_version IS NULL) OR
  (status='ENROLLED' AND enrolled_at_utc IS NOT NULL AND withdrawn_at_utc IS NULL AND acceptance_version IS NOT NULL) OR
  (status='WITHDRAWN' AND enrolled_at_utc IS NOT NULL AND withdrawn_at_utc IS NOT NULL AND acceptance_version IS NOT NULL)),
 CONSTRAINT ck_beta_source CHECK (recruitment_source IN ('existing_member','mailing_list','other')),
 KEY ix_beta_cohort(status,enrolled_at_utc)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
