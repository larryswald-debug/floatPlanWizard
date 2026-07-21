USE `FPW`;

SET @fpw_down_20260721_001_error = NULL;

DROP PROCEDURE IF EXISTS `_fpw_down_20260721_001_membership_premium_send_credits`;
DELIMITER $$
CREATE PROCEDURE `_fpw_down_20260721_001_membership_premium_send_credits`()
BEGIN
  DECLARE v_receipt_count BIGINT UNSIGNED DEFAULT 0;
  DECLARE v_credit_count BIGINT UNSIGNED DEFAULT 0;
  DECLARE v_existing_table_count INT DEFAULT 0;

  IF DATABASE() <> 'FPW' THEN
    SET @fpw_down_20260721_001_error =
      'Refusing rollback: selected database is not FPW.';
  ELSE
    SELECT COUNT(*) INTO v_existing_table_count
    FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = 'FPW'
      AND TABLE_NAME IN ('premium_send_credits', 'premium_send_receipts');

    IF v_existing_table_count <> 2 THEN
      SET @fpw_down_20260721_001_error =
        'Refusing rollback: both Phase 2 Premium Send tables must exist.';
    ELSE
      SELECT COUNT(*) INTO v_receipt_count FROM `premium_send_receipts`;
      SELECT COUNT(*) INTO v_credit_count FROM `premium_send_credits`;

      IF v_receipt_count > 0 OR v_credit_count > 0 THEN
        SET @fpw_down_20260721_001_error =
          'Refusing rollback: Phase 2 Premium Send tables contain application data.';
      ELSE
        DROP TABLE `premium_send_receipts`;
        DROP TABLE `premium_send_credits`;
      END IF;
    END IF;
  END IF;
END$$
DELIMITER ;

CALL `_fpw_down_20260721_001_membership_premium_send_credits`();
DROP PROCEDURE `_fpw_down_20260721_001_membership_premium_send_credits`;

SELECT @fpw_down_20260721_001_error AS rollback_refusal
WHERE @fpw_down_20260721_001_error IS NOT NULL;

SET @fpw_down_20260721_001_guard_sql = IF(
  @fpw_down_20260721_001_error IS NULL,
  'DO 0',
  'SELECT `_fpw_rollback_refused_20260721_001` FROM (SELECT 1 AS `ok`) AS `_fpw_guard`'
);
PREPARE fpw_down_20260721_001_guard FROM @fpw_down_20260721_001_guard_sql;
EXECUTE fpw_down_20260721_001_guard;
DEALLOCATE PREPARE fpw_down_20260721_001_guard;

SET @fpw_down_20260721_001_error = NULL;
SET @fpw_down_20260721_001_guard_sql = NULL;
