component output="false" {
  variables.datasource = "fpw";

  private any function sql(required string statement, struct params = {}) {
    return queryExecute(arguments.statement, arguments.params, { datasource = variables.datasource });
  }

  private numeric function insertRow(required string statement, struct params = {}) {
    var result = {};
    queryExecute(arguments.statement, arguments.params, { datasource = variables.datasource, result = "local.result" });
    return val(result.generatedKey);
  }

  public struct function create(string accessSource = "general_premium", any membershipExpiresAt = "") {
    var marker = "ccv-" & lCase(replace(createUUID(), "-", "", "all"));
    var f = { marker = marker, email = marker & "@example.test", password = "Dev!" & marker,
      contactEmail = marker & "-shore@example.test", token = hash(createUUID() & marker, "SHA-256"),
      slug = "trip-" & lCase(hash(marker, "MD5")), creditId = 0, entitlementId = 0 };
    var credits = new fpw.api.v1.PremiumSendCreditService().init("fpw");
    var entitlements = new fpw.api.v1.MemberEntitlementService().init("fpw");
    var accessResult = {};
    transaction {
      f.userId = insertRow("INSERT INTO users (fName,lName,email,password,passwordCreated,created)
        VALUES ('Completed','Contact Test',:email,:password,UTC_TIMESTAMP(),UTC_TIMESTAMP())",
        { email = f.email, password = uCase(hash(f.password, "SHA-256", "UTF-8")) });
      f.vesselId = insertRow("INSERT INTO vessels (userId,vesselName,hailingPort,isDefaultVessel,timezone)
        VALUES (:owner,'Contact Test Vessel','Test Marina',1,'America/New_York')", { owner = f.userId });
      f.contactId = insertRow("INSERT INTO contacts (name,phone,userId,email)
        VALUES ('Test Shore Contact','5550100100',:owner,:email)", { owner = f.userId, email = f.contactEmail });
      f.routeCode = "CCV_" & left(hash(marker, "MD5"), 24);
      f.loopRouteId = insertRow("INSERT INTO loop_routes (code,name,short_code,description,is_active,total_nm,total_locks)
        VALUES (:code,:name,:code,:name,1,1.0,0)", { code = f.routeCode, name = marker });
      f.routeId = insertRow("INSERT INTO route_instances
        (user_id,template_route_code,generated_route_id,generated_route_code,direction,trip_type,
         start_location,end_location,status,started_at,routegen_inputs_json)
        VALUES (:owner,:code,:route,:code,'CCW','POINT_TO_POINT','Test Marina','Test Anchorage','ACTIVE',
         UTC_TIMESTAMP(),:inputs)",
        { owner = f.userId, code = f.routeCode, route = f.loopRouteId,
          inputs = serializeJSON({ fixture_marker = marker, cruising_speed = 5 }) });
      f.sectionId = insertRow("INSERT INTO route_instance_sections (route_instance_id,section_order,name,phase_num)
        VALUES (:route,1,'Contact test leg',1)", { route = f.routeId });
      insertRow("INSERT INTO route_instance_legs
        (route_instance_id,route_instance_section_id,leg_order,start_name,end_name,start_lat,start_lng,end_lat,end_lng,base_dist_nm,lock_count)
        VALUES (:route,:section,1,'Test Marina','Test Anchorage',41.38,-72.1,41.39,-72.11,1.0,0)",
        { route = f.routeId, section = f.sectionId });
      insertRow("INSERT INTO route_instance_leg_progress (user_id,route_instance_id,leg_order,status,leg_started_at)
        VALUES (:owner,:route,1,'IN_PROGRESS',UTC_TIMESTAMP())", { owner = f.userId, route = f.routeId });
      f.planId = insertRow("INSERT INTO floatplans
        (userId,floatPlanName,vesselId,dateCreated,lastUpdate,status,lastUpdateStatus,route_instance_id,
         route_day_number,activatedAt,departing,`returning`,departureTime,departureTimeUTC,departureTZ,departTimezone,
         returnTime,returnTimeUTC,returnTZ,returnTimezone)
        VALUES (:owner,:name,:vessel,UTC_TIMESTAMP(),UTC_TIMESTAMP(),'ACTIVE',UTC_TIMESTAMP(),:route,1,
         UTC_TIMESTAMP(),'Test Marina','Test Anchorage',UTC_TIMESTAMP(),UTC_TIMESTAMP(),'America/New_York',
         'America/New_York',DATE_ADD(UTC_TIMESTAMP(),INTERVAL 4 HOUR),DATE_ADD(UTC_TIMESTAMP(),INTERVAL 4 HOUR),
         'America/New_York','America/New_York')",
        { owner = f.userId, name = marker, vessel = f.vesselId, route = f.routeId });
      insertRow("INSERT INTO floatplan_contacts (contactId,floatPlanId) VALUES (:contact,:plan)",
        { contact = f.contactId, plan = f.planId });
      f.streamId = insertRow("INSERT INTO voyage_streams
        (floatplan_id,owner_user_id,slug,share_token,privacy_mode,allow_interactions,created_utc,updated_utc)
        VALUES (:plan,:owner,:slug,:token,'invite',1,UTC_TIMESTAMP(),UTC_TIMESTAMP())",
        { plan = f.planId, owner = f.userId, slug = f.slug, token = f.token });
      insertRow("INSERT INTO floatplan_monitoring
        (float_plan_id,user_id,monitoring_mode,monitor_state,is_monitoring_enabled,expected_checkin_at,grace_expires_at,next_monitor_eval_at)
        VALUES (:plan,:owner,'active_route','ACTIVE',1,DATE_ADD(UTC_TIMESTAMP(),INTERVAL 4 HOUR),
         DATE_ADD(UTC_TIMESTAMP(),INTERVAL 5 HOUR),DATE_ADD(UTC_TIMESTAMP(),INTERVAL 4 HOUR))",
        { plan = f.planId, owner = f.userId });
      if (arguments.accessSource EQ "premium_send_credit") {
        accessResult = credits.grantCreditInCurrentTransaction(f.userId, "complimentary_signup", marker);
        f.creditId = accessResult.creditId;
        accessResult = credits.consumeLockedCredit(f.creditId, f.userId, f.planId);
      } else {
        accessResult = entitlements.createAdminCompEntitlement(f.userId, arguments.membershipExpiresAt);
        f.entitlementId = entitlements.getCurrentAccess(f.userId).premiumEntitlementId;
      }
      f.receipt = credits.recordCompletedReceipt(userId=f.userId, floatPlanId=f.planId, creditId=f.creditId,
        accessSource=arguments.accessSource, recipientCount=1, response={ SUCCESS=true });
      if (!structKeyExists(f.receipt, "receiptId") OR f.receipt.receiptId LTE 0) {
        throw(message="Canonical fixture receipt creation failed", detail=serializeJSON(f.receipt));
      }
    }
    return f;
  }

  // Synthetic authorization fixtures only. Browser proof must close via floatplan.handle(checkin).
  public void function completeForContractTest(required struct f) {
    // Receipt starts have microseconds; canonical float-plan close timestamps have whole seconds.
    sleep(1100);
    sql("UPDATE route_instances SET status='COMPLETED',completed_at=UTC_TIMESTAMP() WHERE id=:id", { id=f.routeId });
    sql("UPDATE route_instance_leg_progress SET status='COMPLETED',completed_at=UTC_TIMESTAMP() WHERE route_instance_id=:id", { id=f.routeId });
    sql("UPDATE floatplans SET status='CLOSED',closedAt=UTC_TIMESTAMP(),checkedInAt=UTC_TIMESTAMP() WHERE floatPlanId=:id", { id=f.planId });
    new fpw.api.v1.PremiumTripAccessService().init("fpw").endAccessForPlan(f.planId, "CLOSED");
    sql("UPDATE floatplan_monitoring SET monitor_state='CLOSED',is_monitoring_enabled=0,closed_at=UTC_TIMESTAMP(),next_monitor_eval_at=NULL WHERE float_plan_id=:id", { id=f.planId });
  }

  public struct function snapshot(required struct f) {
    var q = sql("SELECT fp.status,fp.closedAt,ri.status AS route_status,ri.completed_at,
      r.access_end_reason,r.access_ended_at_utc,m.monitor_state,m.is_monitoring_enabled,
      (SELECT COUNT(*) FROM voyage_posts WHERE stream_id=:stream) AS posts,
      (SELECT COUNT(*) FROM voyage_followers WHERE stream_id=:stream) AS followers,
      (SELECT COUNT(*) FROM floatplan_alert_history WHERE floatPlanId=:plan AND status='SENT') AS sent
      FROM floatplans fp JOIN route_instances ri ON ri.id=fp.route_instance_id
      JOIN premium_send_receipts r ON r.float_plan_id=fp.floatPlanId
      LEFT JOIN floatplan_monitoring m ON m.float_plan_id=fp.floatPlanId WHERE fp.floatPlanId=:plan",
      { stream=f.streamId, plan=f.planId });
    var result = {};
    if (q.recordCount) {
      for (var columnName in listToArray(q.columnList)) result[columnName] = isNull(q[columnName][1]) ? "" : q[columnName][1];
    }
    return result;
  }

  public void function cleanup(required struct f) {
    var p = { owner=f.userId, plan=f.planId, route=f.routeId, loopRoute=f.loopRouteId, stream=f.streamId, email=f.email };
    var owned = sql("SELECT userId FROM users WHERE userId=:owner AND email=:email AND email LIKE 'ccv-%@example.test'", p);
    if (owned.recordCount NEQ 1) throw(message="Refusing cleanup of non-fixture owner");
    transaction {
      sql("DELETE FROM voyage_comments WHERE post_id IN (SELECT id FROM voyage_posts WHERE stream_id=:stream)", p);
      sql("DELETE FROM voyage_reactions WHERE post_id IN (SELECT id FROM voyage_posts WHERE stream_id=:stream)", p);
      sql("DELETE FROM voyage_posts WHERE stream_id=:stream", p);
      sql("DELETE FROM voyage_followers WHERE stream_id=:stream", p);
      sql("DELETE FROM voyage_streams WHERE id=:stream AND owner_user_id=:owner", p);
      sql("DELETE FROM floatplan_alert_history WHERE floatPlanId=:plan", p);
      sql("DELETE FROM floatplan_activity_segments WHERE floatplan_id=:plan AND user_id=:owner", p);
      sql("DELETE FROM floatplan_events WHERE floatplan_id=:plan AND user_id=:owner", p);
      sql("DELETE FROM floatplan_monitor_events WHERE float_plan_id=:plan", p);
      sql("DELETE FROM floatplan_monitoring WHERE float_plan_id=:plan", p);
      sql("DELETE FROM floatplan_notifications WHERE floatplanId=:plan", p);
      sql("DELETE FROM floatplan_notification_log WHERE floatplanId=:plan", p);
      sql("DELETE FROM fpw_notification_log WHERE floatPlanId=:plan", p);
      sql("DELETE FROM floatplan_contacts WHERE floatPlanId=:plan", p);
      sql("DELETE FROM fpw_admin_audit_log WHERE admin_user_id=:owner", p);
      sql("DELETE FROM premium_send_receipts WHERE user_id=:owner", p);
      sql("DELETE FROM premium_send_credits WHERE user_id=:owner", p);
      sql("DELETE FROM member_entitlements WHERE user_id=:owner", p);
      sql("DELETE FROM floatplans WHERE floatPlanId=:plan AND userId=:owner", p);
      sql("DELETE FROM route_instance_leg_progress WHERE route_instance_id=:route", p);
      sql("DELETE FROM route_instance_legs WHERE route_instance_id=:route", p);
      sql("DELETE FROM route_instance_sections WHERE route_instance_id=:route", p);
      sql("DELETE FROM route_instance_geometry_snapshots WHERE route_instance_id=:route", p);
      sql("DELETE FROM route_instances WHERE id=:route AND user_id=:owner", p);
      sql("DELETE FROM loop_routes WHERE id=:loopRoute", p);
      sql("DELETE FROM contacts WHERE userId=:owner", p);
      sql("DELETE FROM vessels WHERE userId=:owner", p);
      sql("DELETE FROM users WHERE userId=:owner AND email=:email", p);
    }
  }
}
