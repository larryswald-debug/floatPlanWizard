-- Select FPW (development) or fpw (production) explicitly. Additive; no feedback backfill.
-- Requires 20261105_001_beta_participation. Run with a client that stops on errors.
-- Not rerunnable; inspect a partially installed table before retrying.
SET @fpw_feedback_reason = CASE
 WHEN BINARY DATABASE() NOT IN ('FPW','fpw') OR DATABASE() IS NULL THEN 'Select FPW or fpw explicitly.'
 WHEN NOT EXISTS (SELECT 1 FROM information_schema.TABLES WHERE TABLE_SCHEMA=BINARY DATABASE() AND TABLE_NAME='fpw_beta_participation' AND ENGINE='InnoDB') THEN 'Install beta participation first.'
 ELSE NULL END;
SELECT @fpw_feedback_reason AS refusal_reason;
SET @fpw_feedback_guard=IF(@fpw_feedback_reason IS NULL,'DO 0','SELECT `_fpw_beta_feedback_preflight_refused`');
PREPARE fpw_feedback_guard FROM @fpw_feedback_guard;
EXECUTE fpw_feedback_guard;
DEALLOCATE PREPARE fpw_feedback_guard;
CREATE TABLE fpw_beta_feedback (
 id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
 user_id INT NOT NULL,
 category VARCHAR(60) NOT NULL,
 description TEXT NOT NULL,
 submitted_at_utc DATETIME(6) NOT NULL,
 status VARCHAR(10) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT 'NEW',
 submission_key VARCHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
 UNIQUE KEY uq_beta_feedback_submission(user_id,submission_key),
 KEY ix_beta_feedback_status(status,submitted_at_utc),
 CONSTRAINT ck_beta_feedback_status CHECK(status IN ('NEW','REVIEWED','RESOLVED')),
 CONSTRAINT ck_beta_feedback_description CHECK(CHAR_LENGTH(description) BETWEEN 1 AND 5000)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
