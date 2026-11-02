-- Guarded rollback for a pristine Phase 3 installation only.
-- Quiesce arrival writers and dispatchers. Preserve prior activations and all notice/attempt history.
SET @delivery_error=CASE
  WHEN DATABASE() IS NULL OR BINARY DATABASE() NOT IN ('FPW', 'fpw') THEN 'Select the FPW or fpw database explicitly.'
  WHEN (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA=BINARY DATABASE()
        AND TABLE_NAME IN ('fpw_arrival_dispatch_control', 'fpw_arrival_notices', 'fpw_arrival_deliveries', 'fpw_arrival_attempts') AND TABLE_TYPE='BASE TABLE')<>4
    THEN 'Incomplete or missing Phase 3 installation; inspect before rollback.'
  ELSE NULL
END;
SELECT @delivery_error AS refusal_reason;
SET @delivery_sql = IF(@delivery_error IS NULL, 'DO 0',
    'SELECT `_fpw_delivery_down_refused` FROM (SELECT 1 AS ok) AS fpw_guard');
PREPARE fpw_delivery_guard FROM @delivery_sql;
EXECUTE fpw_delivery_guard;
DEALLOCATE PREPARE fpw_delivery_guard;

LOCK TABLES fpw_arrival_dispatch_control WRITE, fpw_arrival_notices WRITE,
            fpw_arrival_deliveries WRITE, fpw_arrival_attempts WRITE;
SET @delivery_error=CASE
  WHEN (SELECT COUNT(*) <> 1 OR COALESCE(SUM(plan_id=0 AND mode='OFF'
         AND activated_at_utc IS NULL AND generation=1),0) <> 1 FROM fpw_arrival_dispatch_control)
    THEN 'Dispatch has been configured or activated; preserve its history.'
  WHEN EXISTS(SELECT 1 FROM fpw_arrival_notices) OR EXISTS(SELECT 1 FROM fpw_arrival_deliveries)
    OR EXISTS(SELECT 1 FROM fpw_arrival_attempts)
    THEN 'Notification history exists; rollback refused.'
  ELSE NULL
END;
SELECT @delivery_error AS refusal_reason;
SET @delivery_sql = IF(@delivery_error IS NULL, 'DO 0',
    'SELECT `_fpw_delivery_down_refused` FROM (SELECT 1 AS ok) AS fpw_guard');
PREPARE fpw_delivery_guard FROM @delivery_sql;
EXECUTE fpw_delivery_guard;
DEALLOCATE PREPARE fpw_delivery_guard;

DROP TABLE fpw_arrival_attempts;
DROP TABLE fpw_arrival_deliveries;
DROP TABLE fpw_arrival_notices;
DROP TABLE fpw_arrival_dispatch_control;
UNLOCK TABLES;
