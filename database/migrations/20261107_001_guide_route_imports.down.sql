-- Rollback is deliberately blocked while any member import metadata exists.
-- Export/review feature data before a separately authorized populated rollback.
SET @fpw_guide_rollback_guard = IF((SELECT COUNT(*) FROM guide_route_imports)=0, 'DO 0', 'SELECT `_fpw_guide_nonempty_rollback_requires_review`');
PREPARE fpw_guide_rollback_guard FROM @fpw_guide_rollback_guard;
EXECUTE fpw_guide_rollback_guard;
DEALLOCATE PREPARE fpw_guide_rollback_guard;
DROP TABLE guide_route_imports;

