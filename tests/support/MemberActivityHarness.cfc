component extends="testbox.system.BaseSpec" output="false" {
  public any function controller(required string family, required string mode) {
    var target=createObject("component","fpw.api.v1." & arguments.family);
    if (listFind("before,after",arguments.mode)) {
      prepareMock(target);
      target.$("getMemberActivityEventService",createObject("component","fpw.tests.support.MemberActivityFailureStub").init(arguments.mode));
    }
    return target;
  }
  public struct function cleanup(required numeric userId) {
    var p={uid={value=arguments.userId,cfsqltype="cf_sql_integer"}};
    var options={datasource="fpw"};
    var owned=queryExecute("SELECT userId FROM users WHERE userId=:uid AND email LIKE 'codex-activity-%@example.test'
      AND created>=DATE_SUB(NOW(),INTERVAL 4 HOUR)",p,options);
    if (owned.recordCount NEQ 1) throw(message="Refusing non-fixture cleanup.");
    var vessels=queryExecute("SELECT vesselID FROM vessels WHERE userId=:uid",p,options);
    var routes=queryExecute("SELECT generated_route_id FROM route_instances WHERE user_id=:uid",p,options);
    var images=createObject("component","fpw.api.v1.VesselImageService").init("fpw");
    for (var vessel in vessels) images.removeVesselImage(vessel.vesselID,arguments.userId,false);
    transaction {
      for (var table in ["floatplan_contacts","floatplan_passengers","floatplan_waypoints","floatplan_notifications","floatplan_notification_log","fpw_notification_log","floatplan_alert_history"]) {
        queryExecute("DELETE FROM " & table & " WHERE floatPlanId IN (SELECT floatPlanId FROM floatplans WHERE userId=:uid)",p,options);
      }
      queryExecute("DELETE FROM floatplan_basic_details WHERE floatplan_id IN (SELECT floatPlanId FROM floatplans WHERE userId=:uid)",p,options);
      for (var table in ["floatplan_activity_segments","floatplan_events","floatplan_monitor_events","floatplan_monitoring","route_leg_user_overrides","user_segment_overrides","premium_trip_creation_sessions","premium_trip_entitlement_events","member_premium_trip_entitlements","premium_send_receipts","premium_send_credits","member_entitlements","product_events"]) {
        queryExecute("DELETE FROM " & table & " WHERE user_id=:uid",p,options);
      }
      queryExecute("DELETE FROM floatplans WHERE userId=:uid",p,options);
      queryExecute("DELETE FROM route_instances WHERE user_id=:uid",p,options);
      for (var route in routes) {
        var rp={rid={value=route.generated_route_id,cfsqltype="cf_sql_integer"}};
        queryExecute("DELETE FROM loop_segments WHERE section_id IN (SELECT id FROM loop_sections WHERE route_id=:rid)",rp,options);
        queryExecute("DELETE FROM loop_sections WHERE route_id=:rid",rp,options);
        queryExecute("DELETE FROM loop_routes WHERE id=:rid",rp,options);
      }
      queryExecute("DELETE FROM user_route_legs WHERE user_route_id IN (SELECT id FROM user_routes WHERE user_id=:uid)",p,options);
      queryExecute("DELETE FROM user_routes WHERE user_id=:uid",p,options);
      for (var table in ["contacts","operators","passengers","waypoints","vessels","users_address"]) queryExecute("DELETE FROM " & table & " WHERE userId=:uid",p,options);
      queryExecute("DELETE FROM users WHERE userId=:uid",p,options);
    }
    for (var vessel in vessels) images.deleteVesselImageFiles(vessel.vesselID,arguments.userId);
    var uploadRoot=expandPath("/fpw/assets/uploads/vessels/" & arguments.userId);
    if (directoryExists(uploadRoot)) {
      var remainingFiles=directoryList(uploadRoot,true,"query");
      for (var item in remainingFiles) if (item.type EQ "File") throw(message="Fixture upload files remain.");
      directoryDelete(uploadRoot,true);
    }
    return {SUCCESS=true,deleted_user_id=arguments.userId,remaining_users=queryExecute("SELECT COUNT(*) AS n FROM users WHERE userId=:uid",p,options).n[1]};
  }
}
