-- Minimal companion receipt identity for bearer-token check-ins.
-- Nullable so existing session-auth receipts and historical rows remain valid.

ALTER TABLE floatplan_companion_events
  ADD COLUMN companion_device_id BIGINT UNSIGNED NULL AFTER location_captured_at_utc,
  ADD KEY idx_companion_events_device_received (companion_device_id, received_at_utc);
