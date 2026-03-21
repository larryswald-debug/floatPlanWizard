-- Activate only GL_REUSE_V2 for Great Loop templates
-- Deactivate legacy Great Loop templates from Route Builder lists
START TRANSACTION;

UPDATE loop_routes
SET is_default = CASE WHEN short_code = 'GL_REUSE_V2' THEN 1 ELSE 0 END,
    updated_at = NOW()
WHERE short_code IN ('GL_REUSE_V2', 'GL_REUSE_V1', 'GL_CW', 'GREAT_LOOP_CCW');

UPDATE loop_routes
SET is_active = CASE WHEN short_code = 'GL_REUSE_V2' THEN 1 ELSE 0 END,
    updated_at = NOW()
WHERE short_code IN ('GL_REUSE_V2', 'GL_REUSE_V1', 'GL_CW', 'GREAT_LOOP_CCW');

COMMIT;
