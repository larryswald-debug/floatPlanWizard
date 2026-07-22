-- FPW one-user data cleanup.
--
-- Default behavior is preview-only:
--   1. Set exactly one target below by user id or email.
--   2. Run this script.
--   3. Review the reported counts.
--   4. Set @fpw_delete_execute = 1 and confirmation text only when ready.
--
-- Safer execute path:
--   scripts/delete-one-user-data.sh --email user@example.com --execute --i-understand-this-deletes-one-fpw-user

SET @fpw_delete_user_id = NULL;
SET @fpw_delete_email = '';
SET @fpw_delete_execute = 0;
SET @fpw_delete_confirmation = '';

SET @fpw_delete_confirm_required = 'I UNDERSTAND THIS DELETES ONE FPW USER';
SET @fpw_delete_user_id = NULLIF(@fpw_delete_user_id, 0);
SET @fpw_delete_email = TRIM(COALESCE(@fpw_delete_email, ''));
SET @fpw_delete_execute = COALESCE(@fpw_delete_execute, 0);
SET @fpw_delete_confirmation = COALESCE(@fpw_delete_confirmation, '');
SET @fpw_delete_email_key = LOWER(CONVERT(@fpw_delete_email USING utf8mb4)) COLLATE utf8mb4_unicode_ci;

DROP TEMPORARY TABLE IF EXISTS _fpw_delete_guard;
CREATE TEMPORARY TABLE _fpw_delete_guard (
  id INT NOT NULL PRIMARY KEY
) ENGINE=MEMORY;

INSERT INTO _fpw_delete_guard (id) VALUES (1);

DROP TEMPORARY TABLE IF EXISTS _fpw_delete_target_user;
CREATE TEMPORARY TABLE _fpw_delete_target_user (
  user_id INT NOT NULL PRIMARY KEY,
  email VARCHAR(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  hostek_user_id VARCHAR(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL
) ENGINE=MEMORY;

INSERT INTO _fpw_delete_target_user (user_id, email, hostek_user_id)
SELECT userId, email, hostek_userId
FROM users
WHERE (
    @fpw_delete_user_id IS NOT NULL
    AND userId = CAST(@fpw_delete_user_id AS UNSIGNED)
  )
  OR (
    @fpw_delete_email <> ''
    AND LOWER(CONVERT(email USING utf8mb4)) COLLATE utf8mb4_unicode_ci = @fpw_delete_email_key
  );

SET @fpw_delete_target_count = (SELECT COUNT(*) FROM _fpw_delete_target_user);
SET @fpw_delete_target_user_id = (SELECT user_id FROM _fpw_delete_target_user LIMIT 1);
SET @fpw_delete_target_email = (SELECT email FROM _fpw_delete_target_user LIMIT 1);
SET @fpw_delete_target_hostek_user_id = (SELECT hostek_user_id FROM _fpw_delete_target_user LIMIT 1);
SET @fpw_delete_target_email_key = LOWER(CONVERT(@fpw_delete_target_email USING utf8mb4)) COLLATE utf8mb4_unicode_ci;

SELECT
  'guard' AS step,
  @fpw_delete_target_count AS matching_users,
  @fpw_delete_target_user_id AS target_user_id,
  @fpw_delete_target_email AS target_email,
  @fpw_delete_execute AS execute_mode;

-- Abort unless exactly one user resolves, execute mode is 0/1, and execute mode is confirmed.
INSERT INTO _fpw_delete_guard (id)
SELECT 1 WHERE @fpw_delete_target_count <> 1;

INSERT INTO _fpw_delete_guard (id)
SELECT 1 WHERE @fpw_delete_execute NOT IN (0, 1);

INSERT INTO _fpw_delete_guard (id)
SELECT 1
WHERE @fpw_delete_execute = 1
  AND @fpw_delete_confirmation <> @fpw_delete_confirm_required;

START TRANSACTION;

SELECT userId
FROM users
WHERE userId = @fpw_delete_target_user_id
FOR UPDATE;

DROP TEMPORARY TABLE IF EXISTS _fpw_delete_floatplans;
CREATE TEMPORARY TABLE _fpw_delete_floatplans (
  floatplan_id INT NOT NULL PRIMARY KEY
) ENGINE=MEMORY;

INSERT IGNORE INTO _fpw_delete_floatplans (floatplan_id)
SELECT floatPlanId
FROM floatplans
WHERE TRIM(CAST(userId AS CHAR)) = CAST(@fpw_delete_target_user_id AS CHAR);

SELECT floatPlanId
FROM floatplans
WHERE floatPlanId IN (SELECT floatplan_id FROM _fpw_delete_floatplans)
FOR UPDATE;

SET @fpw_delete_premium_send_credit_count = (
  SELECT COUNT(*)
  FROM premium_send_credits
  WHERE user_id = @fpw_delete_target_user_id
     OR consumed_float_plan_id IN (SELECT floatplan_id FROM _fpw_delete_floatplans)
);
SET @fpw_delete_premium_send_receipt_count = (
  SELECT COUNT(*)
  FROM premium_send_receipts
  WHERE user_id = @fpw_delete_target_user_id
     OR float_plan_id IN (SELECT floatplan_id FROM _fpw_delete_floatplans)
);
SET @fpw_delete_premium_send_history_count =
  @fpw_delete_premium_send_credit_count + @fpw_delete_premium_send_receipt_count;

SELECT
  'premium_send_history_guard' AS step,
  IF(
    @fpw_delete_premium_send_history_count > 0,
    'PREMIUM_SEND_HISTORY_DELETE_BLOCKED',
    'OK'
  ) AS error_code,
  @fpw_delete_premium_send_credit_count AS premium_send_credit_count,
  @fpw_delete_premium_send_receipt_count AS premium_send_receipt_count;

-- The supported wrapper does not use mysql --force. A duplicate guard key aborts
-- before any DELETE when retained Premium Send history exists.
INSERT INTO _fpw_delete_guard (id)
SELECT 1
WHERE @fpw_delete_premium_send_history_count > 0;

DROP TEMPORARY TABLE IF EXISTS _fpw_delete_user_routes;
CREATE TEMPORARY TABLE _fpw_delete_user_routes (
  user_route_id INT NOT NULL PRIMARY KEY
) ENGINE=MEMORY;

INSERT IGNORE INTO _fpw_delete_user_routes (user_route_id)
SELECT id
FROM user_routes
WHERE user_id = @fpw_delete_target_user_id;

DROP TEMPORARY TABLE IF EXISTS _fpw_delete_waypoints;
CREATE TEMPORARY TABLE _fpw_delete_waypoints (
  waypoint_id INT NOT NULL PRIMARY KEY
) ENGINE=MEMORY;

INSERT IGNORE INTO _fpw_delete_waypoints (waypoint_id)
SELECT wpId
FROM waypoints
WHERE TRIM(CAST(userId AS CHAR)) = CAST(@fpw_delete_target_user_id AS CHAR);

DROP TEMPORARY TABLE IF EXISTS _fpw_delete_user_route_legs;
CREATE TEMPORARY TABLE _fpw_delete_user_route_legs (
  user_route_leg_id INT NOT NULL PRIMARY KEY
) ENGINE=MEMORY;

INSERT IGNORE INTO _fpw_delete_user_route_legs (user_route_leg_id)
SELECT id
FROM user_route_legs
WHERE user_route_id IN (SELECT user_route_id FROM _fpw_delete_user_routes);

INSERT IGNORE INTO _fpw_delete_user_route_legs (user_route_leg_id)
SELECT id
FROM user_route_legs
WHERE start_waypoint_id IN (SELECT waypoint_id FROM _fpw_delete_waypoints);

INSERT IGNORE INTO _fpw_delete_user_route_legs (user_route_leg_id)
SELECT id
FROM user_route_legs
WHERE end_waypoint_id IN (SELECT waypoint_id FROM _fpw_delete_waypoints);

DROP TEMPORARY TABLE IF EXISTS _fpw_delete_route_instances;
CREATE TEMPORARY TABLE _fpw_delete_route_instances (
  route_instance_id INT NOT NULL PRIMARY KEY
) ENGINE=MEMORY;

INSERT IGNORE INTO _fpw_delete_route_instances (route_instance_id)
SELECT id
FROM route_instances
WHERE TRIM(CAST(user_id AS CHAR)) = CAST(@fpw_delete_target_user_id AS CHAR);

INSERT IGNORE INTO _fpw_delete_route_instances (route_instance_id)
SELECT DISTINCT route_instance_id
FROM floatplans
WHERE route_instance_id IS NOT NULL
  AND route_instance_id > 0
  AND floatPlanId IN (SELECT floatplan_id FROM _fpw_delete_floatplans);

INSERT IGNORE INTO _fpw_delete_route_instances (route_instance_id)
SELECT DISTINCT id
FROM route_instances
WHERE generated_route_id IS NOT NULL
  AND generated_route_id IN (SELECT user_route_id FROM _fpw_delete_user_routes);

DROP TEMPORARY TABLE IF EXISTS _fpw_delete_route_instance_sections;
CREATE TEMPORARY TABLE _fpw_delete_route_instance_sections (
  route_instance_section_id INT NOT NULL PRIMARY KEY
) ENGINE=MEMORY;

INSERT IGNORE INTO _fpw_delete_route_instance_sections (route_instance_section_id)
SELECT id
FROM route_instance_sections
WHERE route_instance_id IN (SELECT route_instance_id FROM _fpw_delete_route_instances);

DROP TEMPORARY TABLE IF EXISTS _fpw_delete_companion_devices;
CREATE TEMPORARY TABLE _fpw_delete_companion_devices (
  companion_device_id BIGINT NOT NULL PRIMARY KEY
) ENGINE=MEMORY;

INSERT IGNORE INTO _fpw_delete_companion_devices (companion_device_id)
SELECT id
FROM companion_devices
WHERE user_id = @fpw_delete_target_user_id;

DROP TEMPORARY TABLE IF EXISTS _fpw_delete_voyage_streams;
CREATE TEMPORARY TABLE _fpw_delete_voyage_streams (
  stream_id INT NOT NULL PRIMARY KEY
) ENGINE=MEMORY;

INSERT IGNORE INTO _fpw_delete_voyage_streams (stream_id)
SELECT id
FROM voyage_streams
WHERE owner_user_id = @fpw_delete_target_user_id
   OR floatplan_id IN (SELECT floatplan_id FROM _fpw_delete_floatplans);

DROP TEMPORARY TABLE IF EXISTS _fpw_delete_voyage_followers;
CREATE TEMPORARY TABLE _fpw_delete_voyage_followers (
  follower_id INT NOT NULL PRIMARY KEY
) ENGINE=MEMORY;

INSERT IGNORE INTO _fpw_delete_voyage_followers (follower_id)
SELECT id
FROM voyage_followers
WHERE stream_id IN (SELECT stream_id FROM _fpw_delete_voyage_streams)
   OR LOWER(CONVERT(email USING utf8mb4)) COLLATE utf8mb4_unicode_ci = @fpw_delete_target_email_key;

DROP TEMPORARY TABLE IF EXISTS _fpw_delete_voyage_posts;
CREATE TEMPORARY TABLE _fpw_delete_voyage_posts (
  post_id INT NOT NULL PRIMARY KEY
) ENGINE=MEMORY;

INSERT IGNORE INTO _fpw_delete_voyage_posts (post_id)
SELECT id
FROM voyage_posts
WHERE stream_id IN (SELECT stream_id FROM _fpw_delete_voyage_streams)
   OR author_user_id = @fpw_delete_target_user_id
   OR follower_id IN (SELECT follower_id FROM _fpw_delete_voyage_followers);

DROP TEMPORARY TABLE IF EXISTS _fpw_delete_stripe_refs;
CREATE TEMPORARY TABLE _fpw_delete_stripe_refs (
  stripe_customer_id VARCHAR(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL,
  stripe_subscription_id VARCHAR(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL,
  stripe_checkout_session_id VARCHAR(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL,
  stripe_payment_intent_id VARCHAR(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL,
  KEY idx_customer (stripe_customer_id),
  KEY idx_subscription (stripe_subscription_id),
  KEY idx_checkout_session (stripe_checkout_session_id),
  KEY idx_payment_intent (stripe_payment_intent_id)
) ENGINE=MEMORY;

INSERT INTO _fpw_delete_stripe_refs (
  stripe_customer_id,
  stripe_subscription_id,
  stripe_checkout_session_id,
  stripe_payment_intent_id
)
SELECT stripe_customer_id, stripe_subscription_id, stripe_checkout_session_id, stripe_payment_intent_id
FROM member_entitlements
WHERE user_id = @fpw_delete_target_user_id;

INSERT INTO _fpw_delete_stripe_refs (
  stripe_customer_id,
  stripe_subscription_id,
  stripe_checkout_session_id,
  stripe_payment_intent_id
)
SELECT stripe_customer_id, stripe_subscription_id, stripe_checkout_session_id, NULL
FROM fpw_promo_redemptions
WHERE user_id = @fpw_delete_target_user_id;

DROP TEMPORARY TABLE IF EXISTS _fpw_delete_counts_before;
CREATE TEMPORARY TABLE _fpw_delete_counts_before (
  table_name VARCHAR(128) NOT NULL PRIMARY KEY,
  rows_before BIGINT NOT NULL
) ENGINE=MEMORY;

INSERT INTO _fpw_delete_counts_before VALUES
  ('backup_route_instance_legs_endpoint_norm_20260221_222027', (SELECT COUNT(*) FROM backup_route_instance_legs_endpoint_norm_20260221_222027 WHERE route_instance_id IN (SELECT route_instance_id FROM _fpw_delete_route_instances)));
INSERT INTO _fpw_delete_counts_before VALUES
  ('backup_route_instance_legs_endpoint_norm_20260221_233840', (SELECT COUNT(*) FROM backup_route_instance_legs_endpoint_norm_20260221_233840 WHERE route_instance_id IN (SELECT route_instance_id FROM _fpw_delete_route_instances)));
INSERT INTO _fpw_delete_counts_before VALUES
  ('backup_route_instance_legs_lockcount_20260221_093626', (SELECT COUNT(*) FROM backup_route_instance_legs_lockcount_20260221_093626 WHERE route_instance_id IN (SELECT route_instance_id FROM _fpw_delete_route_instances)));
INSERT INTO _fpw_delete_counts_before VALUES
  ('backup_route_instance_legs_lockcount_glreusev2_20260221_103545', (SELECT COUNT(*) FROM backup_route_instance_legs_lockcount_glreusev2_20260221_103545 WHERE route_instance_id IN (SELECT route_instance_id FROM _fpw_delete_route_instances)));
INSERT INTO _fpw_delete_counts_before VALUES
  ('companion_pairing_codes', (SELECT COUNT(*) FROM companion_pairing_codes WHERE user_id = @fpw_delete_target_user_id OR used_by_device_id IN (SELECT companion_device_id FROM _fpw_delete_companion_devices)));
INSERT INTO _fpw_delete_counts_before VALUES
  ('companion_devices', (SELECT COUNT(*) FROM companion_devices WHERE user_id = @fpw_delete_target_user_id));
INSERT INTO _fpw_delete_counts_before VALUES
  ('contacts', (SELECT COUNT(*) FROM contacts WHERE TRIM(CAST(userId AS CHAR)) = CAST(@fpw_delete_target_user_id AS CHAR)));
INSERT INTO _fpw_delete_counts_before VALUES
  ('email_optout', (SELECT COUNT(*) FROM email_optout WHERE LOWER(CONVERT(email USING utf8mb4)) COLLATE utf8mb4_unicode_ci = @fpw_delete_target_email_key));
INSERT INTO _fpw_delete_counts_before VALUES
  ('emails_sent', (SELECT COUNT(*) FROM emails_sent WHERE LOWER(CONVERT(email_address USING utf8mb4)) COLLATE utf8mb4_unicode_ci = @fpw_delete_target_email_key));
INSERT INTO _fpw_delete_counts_before VALUES
  ('floatplan_activity_segments', (SELECT COUNT(*) FROM floatplan_activity_segments WHERE user_id = @fpw_delete_target_user_id OR floatplan_id IN (SELECT floatplan_id FROM _fpw_delete_floatplans) OR route_instance_id IN (SELECT route_instance_id FROM _fpw_delete_route_instances)));
INSERT INTO _fpw_delete_counts_before VALUES
  ('floatplan_alert_history', (SELECT COUNT(*) FROM floatplan_alert_history WHERE floatPlanId IN (SELECT floatplan_id FROM _fpw_delete_floatplans)));
INSERT INTO _fpw_delete_counts_before VALUES
  ('floatplan_basic_details', (SELECT COUNT(*) FROM floatplan_basic_details WHERE floatplan_id IN (SELECT floatplan_id FROM _fpw_delete_floatplans)));
INSERT INTO _fpw_delete_counts_before VALUES
  ('floatplan_captain_log_entries', (SELECT COUNT(*) FROM floatplan_captain_log_entries WHERE user_id = @fpw_delete_target_user_id OR floatplan_id IN (SELECT floatplan_id FROM _fpw_delete_floatplans) OR route_instance_id IN (SELECT route_instance_id FROM _fpw_delete_route_instances)));
INSERT INTO _fpw_delete_counts_before VALUES
  ('floatplan_companion_events', (SELECT COUNT(*) FROM floatplan_companion_events WHERE user_id = @fpw_delete_target_user_id OR floatplan_id IN (SELECT floatplan_id FROM _fpw_delete_floatplans) OR route_instance_id IN (SELECT route_instance_id FROM _fpw_delete_route_instances) OR companion_device_id IN (SELECT companion_device_id FROM _fpw_delete_companion_devices)));
INSERT INTO _fpw_delete_counts_before VALUES
  ('floatplan_contacts', (SELECT COUNT(*) FROM floatplan_contacts WHERE floatPlanId IN (SELECT floatplan_id FROM _fpw_delete_floatplans)));
INSERT INTO _fpw_delete_counts_before VALUES
  ('floatplan_emailsent', (SELECT COUNT(*) FROM floatplan_emailsent WHERE fpId IN (SELECT floatplan_id FROM _fpw_delete_floatplans)));
INSERT INTO _fpw_delete_counts_before VALUES
  ('floatplan_events', (SELECT COUNT(*) FROM floatplan_events WHERE user_id = @fpw_delete_target_user_id OR actor_user_id = @fpw_delete_target_user_id OR floatplan_id IN (SELECT floatplan_id FROM _fpw_delete_floatplans) OR route_instance_id IN (SELECT route_instance_id FROM _fpw_delete_route_instances)));
INSERT INTO _fpw_delete_counts_before VALUES
  ('floatplan_history', (SELECT COUNT(*) FROM floatplan_history WHERE TRIM(CAST(userId AS CHAR)) = CAST(@fpw_delete_target_user_id AS CHAR) OR floatPlanId IN (SELECT floatplan_id FROM _fpw_delete_floatplans)));
INSERT INTO _fpw_delete_counts_before VALUES
  ('floatplan_monitor_events', (SELECT COUNT(*) FROM floatplan_monitor_events WHERE user_id = @fpw_delete_target_user_id OR float_plan_id IN (SELECT floatplan_id FROM _fpw_delete_floatplans)));
INSERT INTO _fpw_delete_counts_before VALUES
  ('floatplan_monitoring', (SELECT COUNT(*) FROM floatplan_monitoring WHERE user_id = @fpw_delete_target_user_id OR float_plan_id IN (SELECT floatplan_id FROM _fpw_delete_floatplans)));
INSERT INTO _fpw_delete_counts_before VALUES
  ('floatplan_notification_log', (SELECT COUNT(*) FROM floatplan_notification_log WHERE floatplanId IN (SELECT floatplan_id FROM _fpw_delete_floatplans)));
INSERT INTO _fpw_delete_counts_before VALUES
  ('floatplan_notifications', (SELECT COUNT(*) FROM floatplan_notifications WHERE floatplanId IN (SELECT floatplan_id FROM _fpw_delete_floatplans)));
INSERT INTO _fpw_delete_counts_before VALUES
  ('floatplan_operators', (SELECT COUNT(*) FROM floatplan_operators WHERE floatPlanId IN (SELECT floatplan_id FROM _fpw_delete_floatplans)));
INSERT INTO _fpw_delete_counts_before VALUES
  ('floatplan_passengers', (SELECT COUNT(*) FROM floatplan_passengers WHERE floatPlanId IN (SELECT floatplan_id FROM _fpw_delete_floatplans)));
INSERT INTO _fpw_delete_counts_before VALUES
  ('floatplan_vessels', (SELECT COUNT(*) FROM floatplan_vessels WHERE floatPlanId IN (SELECT floatplan_id FROM _fpw_delete_floatplans)));
INSERT INTO _fpw_delete_counts_before VALUES
  ('floatplan_waypoints', (SELECT COUNT(*) FROM floatplan_waypoints WHERE floatPlanId IN (SELECT floatplan_id FROM _fpw_delete_floatplans)));
INSERT INTO _fpw_delete_counts_before VALUES
  ('floatplans', (SELECT COUNT(*) FROM floatplans WHERE floatPlanId IN (SELECT floatplan_id FROM _fpw_delete_floatplans)));
INSERT INTO _fpw_delete_counts_before VALUES
  ('floatplans_sent', (SELECT COUNT(*) FROM floatplans_sent WHERE fpId IN (SELECT floatplan_id FROM _fpw_delete_floatplans)));
INSERT INTO _fpw_delete_counts_before VALUES
  ('floatplans_tosend', (SELECT COUNT(*) FROM floatplans_tosend WHERE floatPlanId IN (SELECT floatplan_id FROM _fpw_delete_floatplans)));
INSERT INTO _fpw_delete_counts_before VALUES
  ('fpw_early_access', (SELECT COUNT(*) FROM fpw_early_access WHERE LOWER(CONVERT(email USING utf8mb4)) COLLATE utf8mb4_unicode_ci = @fpw_delete_target_email_key));
INSERT INTO _fpw_delete_counts_before VALUES
  ('fpw_email_log', (SELECT COUNT(*) FROM fpw_email_log WHERE floatplan_id IN (SELECT floatplan_id FROM _fpw_delete_floatplans)));
INSERT INTO _fpw_delete_counts_before VALUES
  ('fpw_notification_log', (SELECT COUNT(*) FROM fpw_notification_log WHERE floatPlanId IN (SELECT floatplan_id FROM _fpw_delete_floatplans)));
INSERT INTO _fpw_delete_counts_before VALUES
  ('fpw_promo_redemptions', (SELECT COUNT(*) FROM fpw_promo_redemptions WHERE user_id = @fpw_delete_target_user_id));
INSERT INTO _fpw_delete_counts_before VALUES
  ('member_entitlements', (SELECT COUNT(*) FROM member_entitlements WHERE user_id = @fpw_delete_target_user_id));
INSERT INTO _fpw_delete_counts_before VALUES
  ('messages', (SELECT COUNT(*) FROM messages WHERE LOWER(CONVERT(email USING utf8mb4)) COLLATE utf8mb4_unicode_ci = @fpw_delete_target_email_key));
INSERT INTO _fpw_delete_counts_before VALUES
  ('operators', (SELECT COUNT(*) FROM operators WHERE TRIM(CAST(userId AS CHAR)) = CAST(@fpw_delete_target_user_id AS CHAR)));
INSERT INTO _fpw_delete_counts_before VALUES
  ('passengers', (SELECT COUNT(*) FROM passengers WHERE TRIM(CAST(userId AS CHAR)) = CAST(@fpw_delete_target_user_id AS CHAR)));
INSERT INTO _fpw_delete_counts_before VALUES
  ('reset_tokens', (SELECT COUNT(*) FROM reset_tokens WHERE LOWER(CONVERT(email USING utf8mb4)) COLLATE utf8mb4_unicode_ci = @fpw_delete_target_email_key));
INSERT INTO _fpw_delete_counts_before VALUES
  ('route_instance_leg_progress', (SELECT COUNT(*) FROM route_instance_leg_progress WHERE user_id = @fpw_delete_target_user_id OR route_instance_id IN (SELECT route_instance_id FROM _fpw_delete_route_instances)));
INSERT INTO _fpw_delete_counts_before VALUES
  ('route_instance_legs', (SELECT COUNT(*) FROM route_instance_legs WHERE route_instance_id IN (SELECT route_instance_id FROM _fpw_delete_route_instances) OR route_instance_section_id IN (SELECT route_instance_section_id FROM _fpw_delete_route_instance_sections)));
INSERT INTO _fpw_delete_counts_before VALUES
  ('route_instance_sections', (SELECT COUNT(*) FROM route_instance_sections WHERE id IN (SELECT route_instance_section_id FROM _fpw_delete_route_instance_sections) OR route_instance_id IN (SELECT route_instance_id FROM _fpw_delete_route_instances)));
INSERT INTO _fpw_delete_counts_before VALUES
  ('route_instances', (SELECT COUNT(*) FROM route_instances WHERE id IN (SELECT route_instance_id FROM _fpw_delete_route_instances)));
INSERT INTO _fpw_delete_counts_before VALUES
  ('route_leg_user_overrides', (SELECT COUNT(*) FROM route_leg_user_overrides WHERE user_id = @fpw_delete_target_user_id OR route_id IN (SELECT user_route_id FROM _fpw_delete_user_routes)));
INSERT INTO _fpw_delete_counts_before VALUES
  ('stripe_webhook_events', (SELECT COUNT(DISTINCT swe.id) FROM stripe_webhook_events swe LEFT JOIN _fpw_delete_stripe_refs sr ON ((sr.stripe_customer_id IS NOT NULL AND sr.stripe_customer_id <> '' AND swe.stripe_customer_id = sr.stripe_customer_id) OR (sr.stripe_subscription_id IS NOT NULL AND sr.stripe_subscription_id <> '' AND swe.stripe_subscription_id = sr.stripe_subscription_id) OR (sr.stripe_checkout_session_id IS NOT NULL AND sr.stripe_checkout_session_id <> '' AND swe.stripe_checkout_session_id = sr.stripe_checkout_session_id) OR (sr.stripe_payment_intent_id IS NOT NULL AND sr.stripe_payment_intent_id <> '' AND swe.stripe_payment_intent_id = sr.stripe_payment_intent_id)) WHERE swe.user_id = @fpw_delete_target_user_id OR sr.stripe_customer_id IS NOT NULL OR sr.stripe_subscription_id IS NOT NULL OR sr.stripe_checkout_session_id IS NOT NULL OR sr.stripe_payment_intent_id IS NOT NULL));
INSERT INTO _fpw_delete_counts_before VALUES
  ('user_route_legs', (SELECT COUNT(*) FROM user_route_legs WHERE id IN (SELECT user_route_leg_id FROM _fpw_delete_user_route_legs)));
INSERT INTO _fpw_delete_counts_before VALUES
  ('user_route_progress', (SELECT COUNT(*) FROM user_route_progress WHERE user_id = @fpw_delete_target_user_id));
INSERT INTO _fpw_delete_counts_before VALUES
  ('user_routes', (SELECT COUNT(*) FROM user_routes WHERE id IN (SELECT user_route_id FROM _fpw_delete_user_routes)));
INSERT INTO _fpw_delete_counts_before VALUES
  ('user_segment_overrides', (SELECT COUNT(*) FROM user_segment_overrides WHERE user_id = @fpw_delete_target_user_id));
INSERT INTO _fpw_delete_counts_before VALUES
  ('users_address', (SELECT COUNT(*) FROM users_address WHERE userId = @fpw_delete_target_user_id));
INSERT INTO _fpw_delete_counts_before VALUES
  ('users_hostek', (SELECT COUNT(*) FROM users_hostek WHERE TRIM(CAST(new_userId AS CHAR)) = CAST(@fpw_delete_target_user_id AS CHAR) OR LOWER(CONVERT(hostek_email USING utf8mb4)) COLLATE utf8mb4_unicode_ci = @fpw_delete_target_email_key OR (COALESCE(@fpw_delete_target_hostek_user_id, '') <> '' AND hostek_userId = @fpw_delete_target_hostek_user_id)));
INSERT INTO _fpw_delete_counts_before VALUES
  ('users', (SELECT COUNT(*) FROM users WHERE userId = @fpw_delete_target_user_id));
INSERT INTO _fpw_delete_counts_before VALUES
  ('vessels', (SELECT COUNT(*) FROM vessels WHERE TRIM(CAST(userId AS CHAR)) = CAST(@fpw_delete_target_user_id AS CHAR)));
INSERT INTO _fpw_delete_counts_before VALUES
  ('voyage_comments', (SELECT COUNT(*) FROM voyage_comments WHERE post_id IN (SELECT post_id FROM _fpw_delete_voyage_posts) OR follower_id IN (SELECT follower_id FROM _fpw_delete_voyage_followers)));
INSERT INTO _fpw_delete_counts_before VALUES
  ('voyage_reactions', (SELECT COUNT(*) FROM voyage_reactions WHERE post_id IN (SELECT post_id FROM _fpw_delete_voyage_posts) OR follower_id IN (SELECT follower_id FROM _fpw_delete_voyage_followers)));
INSERT INTO _fpw_delete_counts_before VALUES
  ('voyage_followers', (SELECT COUNT(*) FROM voyage_followers WHERE id IN (SELECT follower_id FROM _fpw_delete_voyage_followers)));
INSERT INTO _fpw_delete_counts_before VALUES
  ('voyage_posts', (SELECT COUNT(*) FROM voyage_posts WHERE id IN (SELECT post_id FROM _fpw_delete_voyage_posts)));
INSERT INTO _fpw_delete_counts_before VALUES
  ('voyage_streams', (SELECT COUNT(*) FROM voyage_streams WHERE id IN (SELECT stream_id FROM _fpw_delete_voyage_streams)));
INSERT INTO _fpw_delete_counts_before VALUES
  ('waypoints', (SELECT COUNT(*) FROM waypoints WHERE wpId IN (SELECT waypoint_id FROM _fpw_delete_waypoints)));

SELECT
  'preview_counts_before_delete' AS step,
  table_name,
  rows_before
FROM _fpw_delete_counts_before
WHERE rows_before > 0
ORDER BY table_name;

DELETE FROM voyage_comments
WHERE post_id IN (SELECT post_id FROM _fpw_delete_voyage_posts)
   OR follower_id IN (SELECT follower_id FROM _fpw_delete_voyage_followers);

DELETE FROM voyage_reactions
WHERE post_id IN (SELECT post_id FROM _fpw_delete_voyage_posts)
   OR follower_id IN (SELECT follower_id FROM _fpw_delete_voyage_followers);

DELETE FROM voyage_posts
WHERE id IN (SELECT post_id FROM _fpw_delete_voyage_posts);

DELETE FROM voyage_followers
WHERE id IN (SELECT follower_id FROM _fpw_delete_voyage_followers);

DELETE FROM voyage_streams
WHERE id IN (SELECT stream_id FROM _fpw_delete_voyage_streams);

DELETE FROM backup_route_instance_legs_endpoint_norm_20260221_222027
WHERE route_instance_id IN (SELECT route_instance_id FROM _fpw_delete_route_instances);

DELETE FROM backup_route_instance_legs_endpoint_norm_20260221_233840
WHERE route_instance_id IN (SELECT route_instance_id FROM _fpw_delete_route_instances);

DELETE FROM backup_route_instance_legs_lockcount_20260221_093626
WHERE route_instance_id IN (SELECT route_instance_id FROM _fpw_delete_route_instances);

DELETE FROM backup_route_instance_legs_lockcount_glreusev2_20260221_103545
WHERE route_instance_id IN (SELECT route_instance_id FROM _fpw_delete_route_instances);

DELETE FROM floatplan_activity_segments
WHERE user_id = @fpw_delete_target_user_id
   OR floatplan_id IN (SELECT floatplan_id FROM _fpw_delete_floatplans)
   OR route_instance_id IN (SELECT route_instance_id FROM _fpw_delete_route_instances);

DELETE FROM floatplan_alert_history
WHERE floatPlanId IN (SELECT floatplan_id FROM _fpw_delete_floatplans);

DELETE FROM floatplan_basic_details
WHERE floatplan_id IN (SELECT floatplan_id FROM _fpw_delete_floatplans);

DELETE FROM floatplan_captain_log_entries
WHERE user_id = @fpw_delete_target_user_id
   OR floatplan_id IN (SELECT floatplan_id FROM _fpw_delete_floatplans)
   OR route_instance_id IN (SELECT route_instance_id FROM _fpw_delete_route_instances);

DELETE FROM floatplan_companion_events
WHERE user_id = @fpw_delete_target_user_id
   OR floatplan_id IN (SELECT floatplan_id FROM _fpw_delete_floatplans)
   OR route_instance_id IN (SELECT route_instance_id FROM _fpw_delete_route_instances)
   OR companion_device_id IN (SELECT companion_device_id FROM _fpw_delete_companion_devices);

DELETE FROM floatplan_contacts
WHERE floatPlanId IN (SELECT floatplan_id FROM _fpw_delete_floatplans);

DELETE FROM floatplan_emailsent
WHERE fpId IN (SELECT floatplan_id FROM _fpw_delete_floatplans);

DELETE FROM floatplan_events
WHERE user_id = @fpw_delete_target_user_id
   OR actor_user_id = @fpw_delete_target_user_id
   OR floatplan_id IN (SELECT floatplan_id FROM _fpw_delete_floatplans)
   OR route_instance_id IN (SELECT route_instance_id FROM _fpw_delete_route_instances);

DELETE FROM floatplan_history
WHERE TRIM(CAST(userId AS CHAR)) = CAST(@fpw_delete_target_user_id AS CHAR)
   OR floatPlanId IN (SELECT floatplan_id FROM _fpw_delete_floatplans);

DELETE FROM floatplan_monitor_events
WHERE user_id = @fpw_delete_target_user_id
   OR float_plan_id IN (SELECT floatplan_id FROM _fpw_delete_floatplans);

DELETE FROM floatplan_monitoring
WHERE user_id = @fpw_delete_target_user_id
   OR float_plan_id IN (SELECT floatplan_id FROM _fpw_delete_floatplans);

DELETE FROM floatplan_notification_log
WHERE floatplanId IN (SELECT floatplan_id FROM _fpw_delete_floatplans);

DELETE FROM floatplan_notifications
WHERE floatplanId IN (SELECT floatplan_id FROM _fpw_delete_floatplans);

DELETE FROM floatplan_operators
WHERE floatPlanId IN (SELECT floatplan_id FROM _fpw_delete_floatplans);

DELETE FROM floatplan_passengers
WHERE floatPlanId IN (SELECT floatplan_id FROM _fpw_delete_floatplans);

DELETE FROM floatplan_vessels
WHERE floatPlanId IN (SELECT floatplan_id FROM _fpw_delete_floatplans);

DELETE FROM floatplan_waypoints
WHERE floatPlanId IN (SELECT floatplan_id FROM _fpw_delete_floatplans);

DELETE FROM floatplans_sent
WHERE fpId IN (SELECT floatplan_id FROM _fpw_delete_floatplans);

DELETE FROM floatplans_tosend
WHERE floatPlanId IN (SELECT floatplan_id FROM _fpw_delete_floatplans);

DELETE FROM fpw_email_log
WHERE floatplan_id IN (SELECT floatplan_id FROM _fpw_delete_floatplans);

DELETE FROM fpw_notification_log
WHERE floatPlanId IN (SELECT floatplan_id FROM _fpw_delete_floatplans);

DELETE FROM route_instance_leg_progress
WHERE user_id = @fpw_delete_target_user_id
   OR route_instance_id IN (SELECT route_instance_id FROM _fpw_delete_route_instances);

DELETE FROM route_instance_legs
WHERE route_instance_id IN (SELECT route_instance_id FROM _fpw_delete_route_instances)
   OR route_instance_section_id IN (SELECT route_instance_section_id FROM _fpw_delete_route_instance_sections);

DELETE FROM route_instance_sections
WHERE id IN (SELECT route_instance_section_id FROM _fpw_delete_route_instance_sections)
   OR route_instance_id IN (SELECT route_instance_id FROM _fpw_delete_route_instances);

DELETE FROM route_instances
WHERE id IN (SELECT route_instance_id FROM _fpw_delete_route_instances);

DELETE FROM route_leg_user_overrides
WHERE user_id = @fpw_delete_target_user_id
   OR route_id IN (SELECT user_route_id FROM _fpw_delete_user_routes);

DELETE FROM user_route_legs
WHERE id IN (SELECT user_route_leg_id FROM _fpw_delete_user_route_legs);

DELETE FROM user_route_progress
WHERE user_id = @fpw_delete_target_user_id;

DELETE FROM user_routes
WHERE id IN (SELECT user_route_id FROM _fpw_delete_user_routes);

DELETE FROM user_segment_overrides
WHERE user_id = @fpw_delete_target_user_id;

DELETE FROM floatplans
WHERE floatPlanId IN (SELECT floatplan_id FROM _fpw_delete_floatplans);

DELETE FROM companion_pairing_codes
WHERE user_id = @fpw_delete_target_user_id
   OR used_by_device_id IN (SELECT companion_device_id FROM _fpw_delete_companion_devices);

DELETE FROM companion_devices
WHERE user_id = @fpw_delete_target_user_id;

DELETE FROM contacts
WHERE TRIM(CAST(userId AS CHAR)) = CAST(@fpw_delete_target_user_id AS CHAR);

DELETE FROM operators
WHERE TRIM(CAST(userId AS CHAR)) = CAST(@fpw_delete_target_user_id AS CHAR);

DELETE FROM passengers
WHERE TRIM(CAST(userId AS CHAR)) = CAST(@fpw_delete_target_user_id AS CHAR);

DELETE FROM vessels
WHERE TRIM(CAST(userId AS CHAR)) = CAST(@fpw_delete_target_user_id AS CHAR);

DELETE FROM waypoints
WHERE wpId IN (SELECT waypoint_id FROM _fpw_delete_waypoints);

DELETE swe
FROM stripe_webhook_events swe
LEFT JOIN _fpw_delete_stripe_refs sr
  ON (
    (sr.stripe_customer_id IS NOT NULL AND sr.stripe_customer_id <> '' AND swe.stripe_customer_id = sr.stripe_customer_id)
    OR (sr.stripe_subscription_id IS NOT NULL AND sr.stripe_subscription_id <> '' AND swe.stripe_subscription_id = sr.stripe_subscription_id)
    OR (sr.stripe_checkout_session_id IS NOT NULL AND sr.stripe_checkout_session_id <> '' AND swe.stripe_checkout_session_id = sr.stripe_checkout_session_id)
    OR (sr.stripe_payment_intent_id IS NOT NULL AND sr.stripe_payment_intent_id <> '' AND swe.stripe_payment_intent_id = sr.stripe_payment_intent_id)
  )
WHERE swe.user_id = @fpw_delete_target_user_id
   OR sr.stripe_customer_id IS NOT NULL
   OR sr.stripe_subscription_id IS NOT NULL
   OR sr.stripe_checkout_session_id IS NOT NULL
   OR sr.stripe_payment_intent_id IS NOT NULL;

DELETE FROM fpw_promo_redemptions
WHERE user_id = @fpw_delete_target_user_id;

DELETE FROM member_entitlements
WHERE user_id = @fpw_delete_target_user_id;

DELETE FROM reset_tokens
WHERE LOWER(CONVERT(email USING utf8mb4)) COLLATE utf8mb4_unicode_ci = @fpw_delete_target_email_key;

DELETE FROM email_optout
WHERE LOWER(CONVERT(email USING utf8mb4)) COLLATE utf8mb4_unicode_ci = @fpw_delete_target_email_key;

DELETE FROM emails_sent
WHERE LOWER(CONVERT(email_address USING utf8mb4)) COLLATE utf8mb4_unicode_ci = @fpw_delete_target_email_key;

DELETE FROM messages
WHERE LOWER(CONVERT(email USING utf8mb4)) COLLATE utf8mb4_unicode_ci = @fpw_delete_target_email_key;

DELETE FROM fpw_early_access
WHERE LOWER(CONVERT(email USING utf8mb4)) COLLATE utf8mb4_unicode_ci = @fpw_delete_target_email_key;

DELETE FROM users_address
WHERE userId = @fpw_delete_target_user_id;

DELETE FROM users_hostek
WHERE TRIM(CAST(new_userId AS CHAR)) = CAST(@fpw_delete_target_user_id AS CHAR)
   OR LOWER(CONVERT(hostek_email USING utf8mb4)) COLLATE utf8mb4_unicode_ci = @fpw_delete_target_email_key
   OR (COALESCE(@fpw_delete_target_hostek_user_id, '') <> '' AND hostek_userId = @fpw_delete_target_hostek_user_id);

DELETE FROM users
WHERE userId = @fpw_delete_target_user_id;

SELECT
  'delete_statements_ran_before_transaction_end' AS step,
  IF(@fpw_delete_execute = 1, 'will_commit', 'will_rollback') AS pending_transaction_result;

SET @fpw_delete_transaction_sql = IF(@fpw_delete_execute = 1, 'COMMIT', 'ROLLBACK');
PREPARE fpw_delete_transaction_stmt FROM @fpw_delete_transaction_sql;
EXECUTE fpw_delete_transaction_stmt;
DEALLOCATE PREPARE fpw_delete_transaction_stmt;

SELECT
  IF(@fpw_delete_execute = 1, 'committed', 'rolled_back_preview_only') AS result,
  @fpw_delete_target_user_id AS target_user_id,
  @fpw_delete_target_email AS target_email;
