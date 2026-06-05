-- Roll back public-reference-library fields from great_loop_locks.

SET @schema_name := DATABASE();

SET @sql_drop_public_sort_idx := IF(
  (SELECT COUNT(*)
   FROM information_schema.statistics
   WHERE table_schema = @schema_name
     AND table_name = 'great_loop_locks'
     AND index_name = 'idx_gll_public_sort') > 0,
  'ALTER TABLE great_loop_locks DROP INDEX idx_gll_public_sort',
  'SELECT 1'
);
PREPARE stmt_drop_public_sort_idx FROM @sql_drop_public_sort_idx;
EXECUTE stmt_drop_public_sort_idx;
DEALLOCATE PREPARE stmt_drop_public_sort_idx;

SET @sql_drop_public_system_idx := IF(
  (SELECT COUNT(*)
   FROM information_schema.statistics
   WHERE table_schema = @schema_name
     AND table_name = 'great_loop_locks'
     AND index_name = 'idx_gll_public_system') > 0,
  'ALTER TABLE great_loop_locks DROP INDEX idx_gll_public_system',
  'SELECT 1'
);
PREPARE stmt_drop_public_system_idx FROM @sql_drop_public_system_idx;
EXECUTE stmt_drop_public_system_idx;
DEALLOCATE PREPARE stmt_drop_public_system_idx;

SET @sql_drop_public_waterway_idx := IF(
  (SELECT COUNT(*)
   FROM information_schema.statistics
   WHERE table_schema = @schema_name
     AND table_name = 'great_loop_locks'
     AND index_name = 'idx_gll_public_waterway') > 0,
  'ALTER TABLE great_loop_locks DROP INDEX idx_gll_public_waterway',
  'SELECT 1'
);
PREPARE stmt_drop_public_waterway_idx FROM @sql_drop_public_waterway_idx;
EXECUTE stmt_drop_public_waterway_idx;
DEALLOCATE PREPARE stmt_drop_public_waterway_idx;

SET @sql_drop_public_state_idx := IF(
  (SELECT COUNT(*)
   FROM information_schema.statistics
   WHERE table_schema = @schema_name
     AND table_name = 'great_loop_locks'
     AND index_name = 'idx_gll_public_state') > 0,
  'ALTER TABLE great_loop_locks DROP INDEX idx_gll_public_state',
  'SELECT 1'
);
PREPARE stmt_drop_public_state_idx FROM @sql_drop_public_state_idx;
EXECUTE stmt_drop_public_state_idx;
DEALLOCATE PREPARE stmt_drop_public_state_idx;

SET @sql_drop_slug_idx := IF(
  (SELECT COUNT(*)
   FROM information_schema.statistics
   WHERE table_schema = @schema_name
     AND table_name = 'great_loop_locks'
     AND index_name = 'uq_gll_slug') > 0,
  'ALTER TABLE great_loop_locks DROP INDEX uq_gll_slug',
  'SELECT 1'
);
PREPARE stmt_drop_slug_idx FROM @sql_drop_slug_idx;
EXECUTE stmt_drop_slug_idx;
DEALLOCATE PREPARE stmt_drop_slug_idx;

SET @sql_drop_sort_order := IF(
  (SELECT COUNT(*)
   FROM information_schema.columns
   WHERE table_schema = @schema_name
     AND table_name = 'great_loop_locks'
     AND column_name = 'sort_order') > 0,
  'ALTER TABLE great_loop_locks DROP COLUMN sort_order',
  'SELECT 1'
);
PREPARE stmt_drop_sort_order FROM @sql_drop_sort_order;
EXECUTE stmt_drop_sort_order;
DEALLOCATE PREPARE stmt_drop_sort_order;

SET @sql_drop_is_public := IF(
  (SELECT COUNT(*)
   FROM information_schema.columns
   WHERE table_schema = @schema_name
     AND table_name = 'great_loop_locks'
     AND column_name = 'is_public') > 0,
  'ALTER TABLE great_loop_locks DROP COLUMN is_public',
  'SELECT 1'
);
PREPARE stmt_drop_is_public FROM @sql_drop_is_public;
EXECUTE stmt_drop_is_public;
DEALLOCATE PREPARE stmt_drop_is_public;

SET @sql_drop_last_reviewed_at := IF(
  (SELECT COUNT(*)
   FROM information_schema.columns
   WHERE table_schema = @schema_name
     AND table_name = 'great_loop_locks'
     AND column_name = 'last_reviewed_at') > 0,
  'ALTER TABLE great_loop_locks DROP COLUMN last_reviewed_at',
  'SELECT 1'
);
PREPARE stmt_drop_last_reviewed_at FROM @sql_drop_last_reviewed_at;
EXECUTE stmt_drop_last_reviewed_at;
DEALLOCATE PREPARE stmt_drop_last_reviewed_at;

SET @sql_drop_source_url := IF(
  (SELECT COUNT(*)
   FROM information_schema.columns
   WHERE table_schema = @schema_name
     AND table_name = 'great_loop_locks'
     AND column_name = 'source_url') > 0,
  'ALTER TABLE great_loop_locks DROP COLUMN source_url',
  'SELECT 1'
);
PREPARE stmt_drop_source_url FROM @sql_drop_source_url;
EXECUTE stmt_drop_source_url;
DEALLOCATE PREPARE stmt_drop_source_url;

SET @sql_drop_source_name := IF(
  (SELECT COUNT(*)
   FROM information_schema.columns
   WHERE table_schema = @schema_name
     AND table_name = 'great_loop_locks'
     AND column_name = 'source_name') > 0,
  'ALTER TABLE great_loop_locks DROP COLUMN source_name',
  'SELECT 1'
);
PREPARE stmt_drop_source_name FROM @sql_drop_source_name;
EXECUTE stmt_drop_source_name;
DEALLOCATE PREPARE stmt_drop_source_name;

SET @sql_drop_special_instructions := IF(
  (SELECT COUNT(*)
   FROM information_schema.columns
   WHERE table_schema = @schema_name
     AND table_name = 'great_loop_locks'
     AND column_name = 'special_instructions') > 0,
  'ALTER TABLE great_loop_locks DROP COLUMN special_instructions',
  'SELECT 1'
);
PREPARE stmt_drop_special_instructions FROM @sql_drop_special_instructions;
EXECUTE stmt_drop_special_instructions;
DEALLOCATE PREPARE stmt_drop_special_instructions;

SET @sql_drop_operating_notes := IF(
  (SELECT COUNT(*)
   FROM information_schema.columns
   WHERE table_schema = @schema_name
     AND table_name = 'great_loop_locks'
     AND column_name = 'operating_notes') > 0,
  'ALTER TABLE great_loop_locks DROP COLUMN operating_notes',
  'SELECT 1'
);
PREPARE stmt_drop_operating_notes FROM @sql_drop_operating_notes;
EXECUTE stmt_drop_operating_notes;
DEALLOCATE PREPARE stmt_drop_operating_notes;

SET @sql_drop_approach_notes := IF(
  (SELECT COUNT(*)
   FROM information_schema.columns
   WHERE table_schema = @schema_name
     AND table_name = 'great_loop_locks'
     AND column_name = 'approach_notes') > 0,
  'ALTER TABLE great_loop_locks DROP COLUMN approach_notes',
  'SELECT 1'
);
PREPARE stmt_drop_approach_notes FROM @sql_drop_approach_notes;
EXECUTE stmt_drop_approach_notes;
DEALLOCATE PREPARE stmt_drop_approach_notes;

SET @sql_drop_country := IF(
  (SELECT COUNT(*)
   FROM information_schema.columns
   WHERE table_schema = @schema_name
     AND table_name = 'great_loop_locks'
     AND column_name = 'country') > 0,
  'ALTER TABLE great_loop_locks DROP COLUMN country',
  'SELECT 1'
);
PREPARE stmt_drop_country FROM @sql_drop_country;
EXECUTE stmt_drop_country;
DEALLOCATE PREPARE stmt_drop_country;

SET @sql_drop_operating_authority := IF(
  (SELECT COUNT(*)
   FROM information_schema.columns
   WHERE table_schema = @schema_name
     AND table_name = 'great_loop_locks'
     AND column_name = 'operating_authority') > 0,
  'ALTER TABLE great_loop_locks DROP COLUMN operating_authority',
  'SELECT 1'
);
PREPARE stmt_drop_operating_authority FROM @sql_drop_operating_authority;
EXECUTE stmt_drop_operating_authority;
DEALLOCATE PREPARE stmt_drop_operating_authority;

SET @sql_drop_lock_system := IF(
  (SELECT COUNT(*)
   FROM information_schema.columns
   WHERE table_schema = @schema_name
     AND table_name = 'great_loop_locks'
     AND column_name = 'lock_system') > 0,
  'ALTER TABLE great_loop_locks DROP COLUMN lock_system',
  'SELECT 1'
);
PREPARE stmt_drop_lock_system FROM @sql_drop_lock_system;
EXECUTE stmt_drop_lock_system;
DEALLOCATE PREPARE stmt_drop_lock_system;

SET @sql_drop_waterway := IF(
  (SELECT COUNT(*)
   FROM information_schema.columns
   WHERE table_schema = @schema_name
     AND table_name = 'great_loop_locks'
     AND column_name = 'waterway') > 0,
  'ALTER TABLE great_loop_locks DROP COLUMN waterway',
  'SELECT 1'
);
PREPARE stmt_drop_waterway FROM @sql_drop_waterway;
EXECUTE stmt_drop_waterway;
DEALLOCATE PREPARE stmt_drop_waterway;

SET @sql_drop_slug := IF(
  (SELECT COUNT(*)
   FROM information_schema.columns
   WHERE table_schema = @schema_name
     AND table_name = 'great_loop_locks'
     AND column_name = 'slug') > 0,
  'ALTER TABLE great_loop_locks DROP COLUMN slug',
  'SELECT 1'
);
PREPARE stmt_drop_slug FROM @sql_drop_slug;
EXECUTE stmt_drop_slug;
DEALLOCATE PREPARE stmt_drop_slug;
