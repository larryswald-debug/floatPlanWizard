USE `FPW`;

SET @fpw_down_20260724_001_error = NULL;
SET @fpw_down_20260724_001_drop_index = 0;

DROP PROCEDURE IF EXISTS `_fpw_down_20260724_001_stripe_sub_uq`;
DELIMITER $$
CREATE PROCEDURE `_fpw_down_20260724_001_stripe_sub_uq`()
BEGIN
  DECLARE v_table_count INT DEFAULT 0;
  DECLARE v_named_index_count INT DEFAULT 0;
  DECLARE v_named_index_exact_count INT DEFAULT 0;

  IF DATABASE() <> 'FPW' THEN
    SET @fpw_down_20260724_001_error =
      'Refusing rollback: selected database is not FPW.';
  ELSE
    SELECT COUNT(*) INTO v_table_count
    FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = 'FPW'
      AND TABLE_NAME = 'member_entitlements'
      AND TABLE_TYPE = 'BASE TABLE';

    SELECT COUNT(*) INTO v_named_index_count
    FROM information_schema.STATISTICS
    WHERE TABLE_SCHEMA = 'FPW'
      AND TABLE_NAME = 'member_entitlements'
      AND INDEX_NAME = 'uq_member_entitlements_stripe_subscription';

    SELECT COUNT(*) INTO v_named_index_exact_count
    FROM (
      SELECT INDEX_NAME
      FROM information_schema.STATISTICS
      WHERE TABLE_SCHEMA = 'FPW'
        AND TABLE_NAME = 'member_entitlements'
        AND INDEX_NAME = 'uq_member_entitlements_stripe_subscription'
      GROUP BY INDEX_NAME
      HAVING MIN(NON_UNIQUE) = 0
         AND COUNT(*) = 1
         AND MIN(SEQ_IN_INDEX) = 1
         AND MAX(SEQ_IN_INDEX) = 1
         AND MIN(COLUMN_NAME) = 'stripe_subscription_id'
         AND MAX(COLUMN_NAME) = 'stripe_subscription_id'
    ) exact_named_index;

    IF v_table_count <> 1 THEN
      SET @fpw_down_20260724_001_error =
        'Refusing rollback: member_entitlements does not exist.';
    ELSEIF v_named_index_count = 0 THEN
      SET @fpw_down_20260724_001_error =
        'Refusing rollback: the Stripe subscription uniqueness index does not exist.';
    ELSEIF v_named_index_exact_count <> 1 THEN
      SET @fpw_down_20260724_001_error =
        'Refusing rollback: the named Stripe subscription index has an incompatible definition.';
    ELSE
      SET @fpw_down_20260724_001_drop_index = 1;
    END IF;
  END IF;
END$$
DELIMITER ;

CALL `_fpw_down_20260724_001_stripe_sub_uq`();
DROP PROCEDURE `_fpw_down_20260724_001_stripe_sub_uq`;

SELECT @fpw_down_20260724_001_error AS rollback_refusal
WHERE @fpw_down_20260724_001_error IS NOT NULL;

SET @fpw_down_20260724_001_guard_sql = IF(
  @fpw_down_20260724_001_error IS NULL,
  'DO 0',
  'SELECT `_fpw_rollback_refused_20260724_001` FROM (SELECT 1 AS `ok`) AS `_fpw_guard`'
);
PREPARE fpw_down_20260724_001_guard FROM @fpw_down_20260724_001_guard_sql;
EXECUTE fpw_down_20260724_001_guard;
DEALLOCATE PREPARE fpw_down_20260724_001_guard;

SET @fpw_down_20260724_001_index_sql = IF(
  @fpw_down_20260724_001_drop_index = 1,
  'ALTER TABLE `member_entitlements` DROP INDEX `uq_member_entitlements_stripe_subscription`',
  'DO 0'
);
PREPARE fpw_down_20260724_001_index FROM @fpw_down_20260724_001_index_sql;
EXECUTE fpw_down_20260724_001_index;
DEALLOCATE PREPARE fpw_down_20260724_001_index;

SET @fpw_down_20260724_001_error = NULL;
SET @fpw_down_20260724_001_drop_index = NULL;
SET @fpw_down_20260724_001_guard_sql = NULL;
SET @fpw_down_20260724_001_index_sql = NULL;
