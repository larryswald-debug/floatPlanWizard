-- FPW canonical trip activity/progress authority foundation - Phase 1 rollback.
-- Review before running. These tables are additive and should only be dropped
-- if no approved future write paths have begun using them.

DROP TABLE IF EXISTS floatplan_activity_segments;
DROP TABLE IF EXISTS floatplan_events;
