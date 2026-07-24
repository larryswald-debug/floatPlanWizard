USE `FPW`;

SET @fpw_up_20260724_001_error = NULL;
SET @fpw_up_20260724_001_add_index = 0;

DROP PROCEDURE IF EXISTS `_fpw_up_20260724_001_stripe_sub_uq`;
DELIMITER $$
CREATE PROCEDURE `_fpw_up_20260724_001_stripe_sub_uq`()
BEGIN
  DECLARE v_table_count INT DEFAULT 0;
  DECLARE v_column_count INT DEFAULT 0;
  DECLARE v_duplicate_count BIGINT UNSIGNED DEFAULT 0;
  DECLARE v_named_index_count INT DEFAULT 0;
  DECLARE v_named_index_exact_count INT DEFAULT 0;

  IF DATABASE() <> 'FPW' THEN
    SET @fpw_up_20260724_001_error =
      'Refusing migration: selected database is not FPW.';
  ELSE
    SELECT COUNT(*) INTO v_table_count
    FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = 'FPW'
      AND TABLE_NAME = 'member_entitlements'
      AND TABLE_TYPE = 'BASE TABLE';

    SELECT COUNT(*) INTO v_column_count
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = 'FPW'
      AND TABLE_NAME = 'member_entitlements'
      AND COLUMN_NAME = 'stripe_subscription_id'
      AND LOWER(COLUMN_TYPE) = 'varchar(255)'
      AND IS_NULLABLE = 'YES';

    IF v_table_count <> 1 OR v_column_count <> 1 THEN
      SET @fpw_up_20260724_001_error =
        'Refusing migration: member_entitlements.stripe_subscription_id is missing or incompatible.';
    ELSE
      SELECT COUNT(*) INTO v_duplicate_count
      FROM (
        SELECT stripe_subscription_id
        FROM member_entitlements
        WHERE stripe_subscription_id IS NOT NULL
          AND stripe_subscription_id <> ''
        GROUP BY stripe_subscription_id
        HAVING COUNT(*) > 1
      ) duplicate_subscriptions;

      IF v_duplicate_count > 0 THEN
        SET @fpw_up_20260724_001_error =
          'Refusing migration: duplicate Stripe subscription entitlement bindings exist.';
      ELSE
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

        IF v_named_index_count = 0 THEN
          SET @fpw_up_20260724_001_add_index = 1;
        ELSEIF v_named_index_exact_count <> 1 THEN
          SET @fpw_up_20260724_001_error =
            'Refusing migration: the named Stripe subscription index exists with an incompatible definition.';
        END IF;
      END IF;
    END IF;
  END IF;
END$$
DELIMITER ;

CALL `_fpw_up_20260724_001_stripe_sub_uq`();
DROP PROCEDURE `_fpw_up_20260724_001_stripe_sub_uq`;

SELECT @fpw_up_20260724_001_error AS migration_refusal
WHERE @fpw_up_20260724_001_error IS NOT NULL;

SET @fpw_up_20260724_001_guard_sql = IF(
  @fpw_up_20260724_001_error IS NULL,
  'DO 0',
  'SELECT `_fpw_migration_refused_20260724_001` FROM (SELECT 1 AS `ok`) AS `_fpw_guard`'
);
PREPARE fpw_up_20260724_001_guard FROM @fpw_up_20260724_001_guard_sql;
EXECUTE fpw_up_20260724_001_guard;
DEALLOCATE PREPARE fpw_up_20260724_001_guard;

SET @fpw_up_20260724_001_index_sql = IF(
  @fpw_up_20260724_001_add_index = 1,
  'ALTER TABLE `member_entitlements` ADD UNIQUE KEY `uq_member_entitlements_stripe_subscription` (`stripe_subscription_id`)',
  'DO 0'
);
PREPARE fpw_up_20260724_001_index FROM @fpw_up_20260724_001_index_sql;
EXECUTE fpw_up_20260724_001_index;
DEALLOCATE PREPARE fpw_up_20260724_001_index;

SET @fpw_up_20260724_001_error = NULL;
SET @fpw_up_20260724_001_add_index = NULL;
SET @fpw_up_20260724_001_guard_sql = NULL;
SET @fpw_up_20260724_001_index_sql = NULL;
