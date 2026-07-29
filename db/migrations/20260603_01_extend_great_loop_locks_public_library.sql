-- Extend Great Loop locks import table for the public reference library.
-- Rows are public by default on import unless the workbook marks them unpublished.

SET @schema_name := DATABASE();

SET @sql_add_slug := IF(
  (SELECT COUNT(*)
   FROM information_schema.columns
   WHERE table_schema = @schema_name
     AND table_name = 'great_loop_locks'
     AND column_name = 'slug') = 0,
  'ALTER TABLE great_loop_locks ADD COLUMN slug VARCHAR(180) NULL AFTER lock_name',
  'SELECT 1'
);
PREPARE stmt_add_slug FROM @sql_add_slug;
EXECUTE stmt_add_slug;
DEALLOCATE PREPARE stmt_add_slug;

SET @sql_add_waterway := IF(
  (SELECT COUNT(*)
   FROM information_schema.columns
   WHERE table_schema = @schema_name
     AND table_name = 'great_loop_locks'
     AND column_name = 'waterway') = 0,
  'ALTER TABLE great_loop_locks ADD COLUMN waterway VARCHAR(160) NULL AFTER vhf',
  'SELECT 1'
);
PREPARE stmt_add_waterway FROM @sql_add_waterway;
EXECUTE stmt_add_waterway;
DEALLOCATE PREPARE stmt_add_waterway;

SET @sql_add_lock_system := IF(
  (SELECT COUNT(*)
   FROM information_schema.columns
   WHERE table_schema = @schema_name
     AND table_name = 'great_loop_locks'
     AND column_name = 'lock_system') = 0,
  'ALTER TABLE great_loop_locks ADD COLUMN lock_system VARCHAR(160) NULL AFTER waterway',
  'SELECT 1'
);
PREPARE stmt_add_lock_system FROM @sql_add_lock_system;
EXECUTE stmt_add_lock_system;
DEALLOCATE PREPARE stmt_add_lock_system;

SET @sql_add_operating_authority := IF(
  (SELECT COUNT(*)
   FROM information_schema.columns
   WHERE table_schema = @schema_name
     AND table_name = 'great_loop_locks'
     AND column_name = 'operating_authority') = 0,
  'ALTER TABLE great_loop_locks ADD COLUMN operating_authority VARCHAR(160) NULL AFTER lock_system',
  'SELECT 1'
);
PREPARE stmt_add_operating_authority FROM @sql_add_operating_authority;
EXECUTE stmt_add_operating_authority;
DEALLOCATE PREPARE stmt_add_operating_authority;

SET @sql_add_country := IF(
  (SELECT COUNT(*)
   FROM information_schema.columns
   WHERE table_schema = @schema_name
     AND table_name = 'great_loop_locks'
     AND column_name = 'country') = 0,
  'ALTER TABLE great_loop_locks ADD COLUMN country VARCHAR(2) NULL AFTER operating_authority',
  'SELECT 1'
);
PREPARE stmt_add_country FROM @sql_add_country;
EXECUTE stmt_add_country;
DEALLOCATE PREPARE stmt_add_country;

SET @sql_add_approach_notes := IF(
  (SELECT COUNT(*)
   FROM information_schema.columns
   WHERE table_schema = @schema_name
     AND table_name = 'great_loop_locks'
     AND column_name = 'approach_notes') = 0,
  'ALTER TABLE great_loop_locks ADD COLUMN approach_notes TEXT NULL AFTER country',
  'SELECT 1'
);
PREPARE stmt_add_approach_notes FROM @sql_add_approach_notes;
EXECUTE stmt_add_approach_notes;
DEALLOCATE PREPARE stmt_add_approach_notes;

SET @sql_add_operating_notes := IF(
  (SELECT COUNT(*)
   FROM information_schema.columns
   WHERE table_schema = @schema_name
     AND table_name = 'great_loop_locks'
     AND column_name = 'operating_notes') = 0,
  'ALTER TABLE great_loop_locks ADD COLUMN operating_notes TEXT NULL AFTER approach_notes',
  'SELECT 1'
);
PREPARE stmt_add_operating_notes FROM @sql_add_operating_notes;
EXECUTE stmt_add_operating_notes;
DEALLOCATE PREPARE stmt_add_operating_notes;

SET @sql_add_special_instructions := IF(
  (SELECT COUNT(*)
   FROM information_schema.columns
   WHERE table_schema = @schema_name
     AND table_name = 'great_loop_locks'
     AND column_name = 'special_instructions') = 0,
  'ALTER TABLE great_loop_locks ADD COLUMN special_instructions TEXT NULL AFTER operating_notes',
  'SELECT 1'
);
PREPARE stmt_add_special_instructions FROM @sql_add_special_instructions;
EXECUTE stmt_add_special_instructions;
DEALLOCATE PREPARE stmt_add_special_instructions;

SET @sql_add_source_name := IF(
  (SELECT COUNT(*)
   FROM information_schema.columns
   WHERE table_schema = @schema_name
     AND table_name = 'great_loop_locks'
     AND column_name = 'source_name') = 0,
  'ALTER TABLE great_loop_locks ADD COLUMN source_name VARCHAR(160) NULL AFTER special_instructions',
  'SELECT 1'
);
PREPARE stmt_add_source_name FROM @sql_add_source_name;
EXECUTE stmt_add_source_name;
DEALLOCATE PREPARE stmt_add_source_name;

SET @sql_add_source_url := IF(
  (SELECT COUNT(*)
   FROM information_schema.columns
   WHERE table_schema = @schema_name
     AND table_name = 'great_loop_locks'
     AND column_name = 'source_url') = 0,
  'ALTER TABLE great_loop_locks ADD COLUMN source_url VARCHAR(512) NULL AFTER source_name',
  'SELECT 1'
);
PREPARE stmt_add_source_url FROM @sql_add_source_url;
EXECUTE stmt_add_source_url;
DEALLOCATE PREPARE stmt_add_source_url;

SET @sql_add_last_reviewed_at := IF(
  (SELECT COUNT(*)
   FROM information_schema.columns
   WHERE table_schema = @schema_name
     AND table_name = 'great_loop_locks'
     AND column_name = 'last_reviewed_at') = 0,
  'ALTER TABLE great_loop_locks ADD COLUMN last_reviewed_at DATE NULL AFTER source_url',
  'SELECT 1'
);
PREPARE stmt_add_last_reviewed_at FROM @sql_add_last_reviewed_at;
EXECUTE stmt_add_last_reviewed_at;
DEALLOCATE PREPARE stmt_add_last_reviewed_at;

SET @sql_add_is_public := IF(
  (SELECT COUNT(*)
   FROM information_schema.columns
   WHERE table_schema = @schema_name
     AND table_name = 'great_loop_locks'
     AND column_name = 'is_public') = 0,
  'ALTER TABLE great_loop_locks ADD COLUMN is_public TINYINT(1) NOT NULL DEFAULT 1 AFTER last_reviewed_at',
  'SELECT 1'
);
PREPARE stmt_add_is_public FROM @sql_add_is_public;
EXECUTE stmt_add_is_public;
DEALLOCATE PREPARE stmt_add_is_public;

ALTER TABLE great_loop_locks ALTER COLUMN is_public SET DEFAULT 1;

SET @sql_add_sort_order := IF(
  (SELECT COUNT(*)
   FROM information_schema.columns
   WHERE table_schema = @schema_name
     AND table_name = 'great_loop_locks'
     AND column_name = 'sort_order') = 0,
  'ALTER TABLE great_loop_locks ADD COLUMN sort_order INT NULL AFTER is_public',
  'SELECT 1'
);
PREPARE stmt_add_sort_order FROM @sql_add_sort_order;
EXECUTE stmt_add_sort_order;
DEALLOCATE PREPARE stmt_add_sort_order;

SET @sql_add_slug_idx := IF(
  (SELECT COUNT(*)
   FROM information_schema.statistics
   WHERE table_schema = @schema_name
     AND table_name = 'great_loop_locks'
     AND index_name = 'uq_gll_slug') = 0,
  'ALTER TABLE great_loop_locks ADD UNIQUE KEY uq_gll_slug (slug)',
  'SELECT 1'
);
PREPARE stmt_add_slug_idx FROM @sql_add_slug_idx;
EXECUTE stmt_add_slug_idx;
DEALLOCATE PREPARE stmt_add_slug_idx;

SET @sql_add_public_state_idx := IF(
  (SELECT COUNT(*)
   FROM information_schema.statistics
   WHERE table_schema = @schema_name
     AND table_name = 'great_loop_locks'
     AND index_name = 'idx_gll_public_state') = 0,
  'ALTER TABLE great_loop_locks ADD KEY idx_gll_public_state (is_public, state, city)',
  'SELECT 1'
);
PREPARE stmt_add_public_state_idx FROM @sql_add_public_state_idx;
EXECUTE stmt_add_public_state_idx;
DEALLOCATE PREPARE stmt_add_public_state_idx;

SET @sql_add_public_waterway_idx := IF(
  (SELECT COUNT(*)
   FROM information_schema.statistics
   WHERE table_schema = @schema_name
     AND table_name = 'great_loop_locks'
     AND index_name = 'idx_gll_public_waterway') = 0,
  'ALTER TABLE great_loop_locks ADD KEY idx_gll_public_waterway (is_public, waterway)',
  'SELECT 1'
);
PREPARE stmt_add_public_waterway_idx FROM @sql_add_public_waterway_idx;
EXECUTE stmt_add_public_waterway_idx;
DEALLOCATE PREPARE stmt_add_public_waterway_idx;

SET @sql_add_public_system_idx := IF(
  (SELECT COUNT(*)
   FROM information_schema.statistics
   WHERE table_schema = @schema_name
     AND table_name = 'great_loop_locks'
     AND index_name = 'idx_gll_public_system') = 0,
  'ALTER TABLE great_loop_locks ADD KEY idx_gll_public_system (is_public, lock_system)',
  'SELECT 1'
);
PREPARE stmt_add_public_system_idx FROM @sql_add_public_system_idx;
EXECUTE stmt_add_public_system_idx;
DEALLOCATE PREPARE stmt_add_public_system_idx;

SET @sql_add_public_sort_idx := IF(
  (SELECT COUNT(*)
   FROM information_schema.statistics
   WHERE table_schema = @schema_name
     AND table_name = 'great_loop_locks'
     AND index_name = 'idx_gll_public_sort') = 0,
  'ALTER TABLE great_loop_locks ADD KEY idx_gll_public_sort (is_public, sort_order, lock_name)',
  'SELECT 1'
);
PREPARE stmt_add_public_sort_idx FROM @sql_add_public_sort_idx;
EXECUTE stmt_add_public_sort_idx;
DEALLOCATE PREPARE stmt_add_public_sort_idx;
