-- Development rollback / separately approved operator rollback only.
-- Quiesce all arrival writers before attempting rollback; preserve all operational history.
SET @arrival_error = CASE
  WHEN DATABASE() IS NULL OR BINARY DATABASE() NOT IN ('FPW', 'fpw') THEN 'Select the FPW or fpw database explicitly.'
  WHEN (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = BINARY DATABASE()
          AND TABLE_NAME IN ('fpw_arrival_rollout', 'fpw_arrival_watches', 'fpw_arrival_revisions', 'fpw_arrival_events') AND TABLE_TYPE='BASE TABLE') <> 4
    THEN 'Incomplete or absent arrival schema; inspect the installation before rollback.'
  ELSE NULL
END;
SELECT @arrival_error AS refusal_reason;
SET @arrival_guard_sql = IF(@arrival_error IS NULL, 'DO 0',
    'SELECT `_fpw_arrival_down_refused` FROM (SELECT 1 AS ok) AS fpw_guard');
PREPARE fpw_arrival_guard FROM @arrival_guard_sql;
EXECUTE fpw_arrival_guard;
DEALLOCATE PREPARE fpw_arrival_guard;

LOCK TABLES fpw_arrival_rollout WRITE, fpw_arrival_watches WRITE,
            fpw_arrival_revisions WRITE, fpw_arrival_events WRITE;
SET @arrival_error = CASE
  WHEN (SELECT COUNT(*) FROM fpw_arrival_rollout WHERE id=1 AND mode='OFF') <> 1
    THEN 'Arrival observation must be OFF before rollback.'
  WHEN EXISTS (SELECT 1 FROM fpw_arrival_watches)
    OR EXISTS (SELECT 1 FROM fpw_arrival_revisions)
    OR EXISTS (SELECT 1 FROM fpw_arrival_events)
    THEN 'Arrival monitoring history exists; rollback is refused.'
  ELSE NULL
END;
SELECT @arrival_error AS refusal_reason;
SET @arrival_guard_sql = IF(@arrival_error IS NULL, 'DO 0',
    'SELECT `_fpw_arrival_down_refused` FROM (SELECT 1 AS ok) AS fpw_guard');
PREPARE fpw_arrival_guard FROM @arrival_guard_sql;
EXECUTE fpw_arrival_guard;
DEALLOCATE PREPARE fpw_arrival_guard;

DROP TABLE fpw_arrival_events;
DROP TABLE fpw_arrival_revisions;
DROP TABLE fpw_arrival_watches;
DROP TABLE fpw_arrival_rollout;
UNLOCK TABLES;
