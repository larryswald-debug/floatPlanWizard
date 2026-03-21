-- Rollback for route generator normalization phase 1 additive schema.

SET @schema_name := DATABASE();

DROP TABLE IF EXISTS route_instance_leg_progress;
DROP TABLE IF EXISTS user_segment_overrides;
DROP TABLE IF EXISTS route_instance_legs;
DROP TABLE IF EXISTS route_instance_sections;

SET @sql_drop_idx_rluo_user_route_leg := IF(
  (SELECT COUNT(*)
   FROM information_schema.statistics
   WHERE table_schema = @schema_name
     AND table_name = 'route_leg_user_overrides'
     AND index_name = 'idx_rg_norm_rluo_user_route_leg') > 0,
  'ALTER TABLE route_leg_user_overrides DROP INDEX idx_rg_norm_rluo_user_route_leg',
  'SELECT 1'
);
PREPARE stmt_drop_idx_rluo_user_route_leg FROM @sql_drop_idx_rluo_user_route_leg;
EXECUTE stmt_drop_idx_rluo_user_route_leg;
DEALLOCATE PREPARE stmt_drop_idx_rluo_user_route_leg;

SET @sql_drop_idx_user_route_progress_user_segment := IF(
  (SELECT COUNT(*)
   FROM information_schema.statistics
   WHERE table_schema = @schema_name
     AND table_name = 'user_route_progress'
     AND index_name = 'idx_rg_norm_user_route_progress_user_segment') > 0,
  'ALTER TABLE user_route_progress DROP INDEX idx_rg_norm_user_route_progress_user_segment',
  'SELECT 1'
);
PREPARE stmt_drop_idx_user_route_progress_user_segment FROM @sql_drop_idx_user_route_progress_user_segment;
EXECUTE stmt_drop_idx_user_route_progress_user_segment;
DEALLOCATE PREPARE stmt_drop_idx_user_route_progress_user_segment;

SET @sql_drop_idx_route_instances_user_generated_code := IF(
  (SELECT COUNT(*)
   FROM information_schema.statistics
   WHERE table_schema = @schema_name
     AND table_name = 'route_instances'
     AND index_name = 'idx_rg_norm_route_instances_user_generated_code') > 0,
  'ALTER TABLE route_instances DROP INDEX idx_rg_norm_route_instances_user_generated_code',
  'SELECT 1'
);
PREPARE stmt_drop_idx_route_instances_user_generated_code FROM @sql_drop_idx_route_instances_user_generated_code;
EXECUTE stmt_drop_idx_route_instances_user_generated_code;
DEALLOCATE PREPARE stmt_drop_idx_route_instances_user_generated_code;

SET @sql_drop_idx_loop_segments_section_order := IF(
  (SELECT COUNT(*)
   FROM information_schema.statistics
   WHERE table_schema = @schema_name
     AND table_name = 'loop_segments'
     AND index_name = 'idx_rg_norm_loop_segments_section_order') > 0,
  'ALTER TABLE loop_segments DROP INDEX idx_rg_norm_loop_segments_section_order',
  'SELECT 1'
);
PREPARE stmt_drop_idx_loop_segments_section_order FROM @sql_drop_idx_loop_segments_section_order;
EXECUTE stmt_drop_idx_loop_segments_section_order;
DEALLOCATE PREPARE stmt_drop_idx_loop_segments_section_order;

SET @sql_drop_idx_loop_sections_route_order := IF(
  (SELECT COUNT(*)
   FROM information_schema.statistics
   WHERE table_schema = @schema_name
     AND table_name = 'loop_sections'
     AND index_name = 'idx_rg_norm_loop_sections_route_order') > 0,
  'ALTER TABLE loop_sections DROP INDEX idx_rg_norm_loop_sections_route_order',
  'SELECT 1'
);
PREPARE stmt_drop_idx_loop_sections_route_order FROM @sql_drop_idx_loop_sections_route_order;
EXECUTE stmt_drop_idx_loop_sections_route_order;
DEALLOCATE PREPARE stmt_drop_idx_loop_sections_route_order;

SET @sql_drop_idx_loop_segments_source_segment := IF(
  (SELECT COUNT(*)
   FROM information_schema.statistics
   WHERE table_schema = @schema_name
     AND table_name = 'loop_segments'
     AND index_name = 'idx_rg_norm_loop_segments_source_segment') > 0,
  'ALTER TABLE loop_segments DROP INDEX idx_rg_norm_loop_segments_source_segment',
  'SELECT 1'
);
PREPARE stmt_drop_idx_loop_segments_source_segment FROM @sql_drop_idx_loop_segments_source_segment;
EXECUTE stmt_drop_idx_loop_segments_source_segment;
DEALLOCATE PREPARE stmt_drop_idx_loop_segments_source_segment;

SET @sql_drop_loop_segments_source_segment := IF(
  (SELECT COUNT(*)
   FROM information_schema.columns
   WHERE table_schema = @schema_name
     AND table_name = 'loop_segments'
     AND column_name = 'source_segment_id') > 0,
  'ALTER TABLE loop_segments DROP COLUMN source_segment_id',
  'SELECT 1'
);
PREPARE stmt_drop_loop_segments_source_segment FROM @sql_drop_loop_segments_source_segment;
EXECUTE stmt_drop_loop_segments_source_segment;
DEALLOCATE PREPARE stmt_drop_loop_segments_source_segment;
