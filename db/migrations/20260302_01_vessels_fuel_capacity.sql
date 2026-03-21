ALTER TABLE vessels
  ADD COLUMN fuel_capacity DECIMAL(10,2) NULL AFTER gallons_per_hour;
