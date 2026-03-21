-- Add manual exposure override level for hybrid offshore weather modeling.
-- NULL means auto mode based on is_offshore.
-- 0=protected/inshore, 1=semi-protected, 2=partially exposed, 3=open water.
ALTER TABLE segment_library
  ADD COLUMN exposure_level TINYINT NULL AFTER is_icw;
