component output="false" {
  variables.datasource="fpw";

  public any function init(string datasource="fpw") output=false {
    variables.datasource=arguments.datasource;
    return this;
  }

  // Destination selection only. The existing classifier/policy remains the send authority.
  public string function resolveStage(required numeric userId,required string stage) output=false {
    var action=arguments.stage EQ "A" ? "vessel" : (arguments.stage EQ "B" ? "planner" : (arguments.stage EQ "C" ? "routes" : "plans"));
    var target={recoveryAction=action};
    if (!validId(arguments.userId) OR !listFind("A,B,C,D",arguments.stage)) return "";
    try {
      if (arguments.stage EQ "C") {
        // Same preference as listMyRoutes: active saved work, newest update then ID.
        var saved=savedRoutes(arguments.userId);
        if (saved.recordCount) target={recoveryAction="route",routeId=val(saved.id[1])};
        else {
          // Generated Routes uses newest route, then its latest owned instance.
          var planned=plannedRoutes(arguments.userId);
          if (planned.recordCount) target={recoveryAction="route",routeInstanceId=val(planned.id[1])};
        }
      } else if (arguments.stage EQ "D") {
        // Match the product's conservative current-Draft rule: never guess among Drafts.
        var drafts=eligibleDrafts(arguments.userId);
        if (drafts.recordCount EQ 1) target={recoveryAction="draft",floatPlanId=val(drafts.floatPlanId[1])};
      }
    } catch (any unavailableTarget) {
      target={recoveryAction=action};
    }
    return new fpw.includes.InactiveMemberRecoveryActionPathService().buildPath("",target);
  }

  // Called after authentication on every click. URL IDs are selectors, never ownership proof.
  public struct function resolveRequest(required numeric userId,required struct values) output=false {
    var intent=emptyIntent();
    var path=new fpw.includes.InactiveMemberRecoveryActionPathService().buildPath("",arguments.values);
    if (!validId(arguments.userId) OR !len(path)) return intent;
    intent.action=toString(arguments.values.recoveryAction);
    try {
      if (intent.action EQ "route") {
        if (structKeyExists(arguments.values,"routeId")) {
          var saved=savedRoutes(arguments.userId,val(arguments.values.routeId));
          if (saved.recordCount EQ 1) intent.routeId=val(saved.id[1]);
          else intent.action="routes";
        } else {
          var planned=plannedRoutes(arguments.userId,val(arguments.values.routeInstanceId));
          if (planned.recordCount EQ 1) {
            intent.routeInstanceId=val(planned.id[1]);
            intent.routeCode=toString(planned.short_code[1]);
          } else intent.action="routes";
        }
      } else if (intent.action EQ "draft") {
        var drafts=eligibleDrafts(arguments.userId,val(arguments.values.floatPlanId));
        if (drafts.recordCount EQ 1) {
          intent.floatPlanId=val(drafts.floatPlanId[1]);
          intent.basicDraft=val(drafts.basic_draft[1]) EQ 1;
        } else intent.action="plans";
      }
    } catch (any unavailableTarget) {
      intent=emptyIntent();
      intent.action=arguments.values.recoveryAction EQ "draft" ? "plans" : "routes";
    }
    return intent;
  }

  private query function savedRoutes(required numeric userId,numeric routeId=0) output=false {
    var sql="SELECT id FROM user_routes WHERE user_id=:userId AND is_active=1";
    var params={userId={value=arguments.userId,cfsqltype="cf_sql_integer"}};
    if (arguments.routeId GT 0) {
      sql &= " AND id=:routeId";
      params.routeId={value=arguments.routeId,cfsqltype="cf_sql_integer"};
    }
    return queryExecute(sql & " ORDER BY updated_at DESC,id DESC LIMIT 1",params,{datasource=variables.datasource});
  }

  private query function plannedRoutes(required numeric userId,numeric routeInstanceId=0) output=false {
    var sql="SELECT ri.id,lr.short_code
      FROM route_instances ri JOIN loop_routes lr ON lr.id=ri.generated_route_id
      WHERE ri.user_id=:userId AND ri.generated_route_code=lr.short_code AND lr.is_active=1
        AND UPPER(TRIM(ri.status))='PLANNED' AND ri.started_at IS NULL AND ri.completed_at IS NULL
        AND NOT EXISTS (SELECT 1 FROM route_instance_leg_progress leg
          WHERE leg.route_instance_id=ri.id AND UPPER(TRIM(leg.status))='STARTED' AND leg.completed_at IS NULL)
        AND NOT EXISTS (SELECT 1 FROM route_instances newer
          WHERE newer.generated_route_id=ri.generated_route_id AND newer.user_id=:userId AND newer.id>ri.id)";
    var params={userId={value=toString(arguments.userId),cfsqltype="cf_sql_varchar"}};
    if (arguments.routeInstanceId GT 0) {
      sql &= " AND ri.id=:instanceId";
      params.instanceId={value=arguments.routeInstanceId,cfsqltype="cf_sql_integer"};
    }
    return queryExecute(sql & " ORDER BY lr.id DESC,ri.id DESC LIMIT 1",params,{datasource=variables.datasource});
  }

  private query function eligibleDrafts(required numeric userId,numeric floatPlanId=0) output=false {
    var sql="SELECT fp.floatPlanId,
        (fp.route_instance_id IS NULL AND fp.route_day_number IS NULL
          AND fp.route_origin='basic_float_plan' AND fp.is_reusable=0 AND fp.is_visible_in_route_library=0
          AND EXISTS (SELECT 1 FROM floatplan_basic_details bd WHERE bd.floatplan_id=fp.floatPlanId)) AS basic_draft
      FROM floatplans fp
      LEFT JOIN route_instances ri ON ri.id=fp.route_instance_id
      LEFT JOIN vessels v ON v.vesselID=fp.vesselId
      LEFT JOIN operators o ON o.opId=fp.operatorId
      WHERE fp.userId=:userId AND UPPER(TRIM(fp.status))='DRAFT'
        AND fp.initialSentAt IS NULL AND fp.activatedAt IS NULL AND fp.checkedInAt IS NULL
        AND fp.closedAt IS NULL AND fp.expiredAt IS NULL AND COALESCE(TRIM(fp.end_reason),'')=''
        AND (fp.route_instance_id IS NULL OR (ri.id IS NOT NULL AND ri.user_id=:userId
          AND UPPER(TRIM(ri.status))='PLANNED' AND ri.started_at IS NULL AND ri.completed_at IS NULL))
        AND (fp.vesselId IS NULL OR (fp.vesselId<>0 AND v.vesselID IS NOT NULL AND v.userId=:userId)
          OR (fp.vesselId=0 AND fp.route_instance_id IS NULL AND fp.route_day_number IS NULL
            AND fp.route_origin='basic_float_plan' AND fp.is_reusable=0 AND fp.is_visible_in_route_library=0
            AND fp.operatorId IS NULL
            AND EXISTS (SELECT 1 FROM floatplan_basic_details bd WHERE bd.floatplan_id=fp.floatPlanId)))
        AND (fp.operatorId IS NULL OR (o.opId IS NOT NULL AND o.userId=:userId))
        AND NOT EXISTS (SELECT 1 FROM product_events e WHERE e.user_id=:userId
          AND e.entity_type='float_plan' AND e.entity_id=fp.floatPlanId
          AND ((e.event_name='basic_send_completed' AND e.event_source IN ('basic_save_send','basic_review_send'))
            OR (e.event_name='premium_send_completed' AND e.event_source='premium_save_send')
            OR (e.event_name='recovery_share_succeeded' AND e.event_source IN ('basic_save_send','basic_review_send','premium_save_send'))))
        AND NOT EXISTS (SELECT 1 FROM basic_review_send_receipts b
          WHERE b.user_id=:userId AND b.float_plan_id=fp.floatPlanId AND UPPER(TRIM(b.status))='SENT' AND b.completed_at_utc IS NOT NULL)
        AND NOT EXISTS (SELECT 1 FROM premium_send_receipts p
          WHERE p.user_id=:userId AND p.float_plan_id=fp.floatPlanId AND p.committed_at_utc IS NOT NULL AND p.recipient_count>0)
        AND NOT EXISTS (SELECT 1 FROM floatplan_monitoring fm WHERE fm.user_id=:userId
          AND fm.float_plan_id=fp.floatPlanId AND fm.is_monitoring_enabled=1 AND UPPER(TRIM(fm.monitor_state)) NOT IN ('RESOLVED','CLOSED'))
        AND NOT EXISTS (SELECT 1 FROM route_instance_leg_progress leg WHERE leg.route_instance_id=fp.route_instance_id
          AND UPPER(TRIM(leg.status))='STARTED' AND leg.completed_at IS NULL)";
    var params={userId={value=toString(arguments.userId),cfsqltype="cf_sql_varchar"}};
    if (arguments.floatPlanId GT 0) {
      sql &= " AND fp.floatPlanId=:planId";
      params.planId={value=arguments.floatPlanId,cfsqltype="cf_sql_integer"};
    }
    return queryExecute(sql & " ORDER BY fp.floatPlanId DESC LIMIT 2",params,{datasource=variables.datasource});
  }

  private struct function emptyIntent() output=false {
    return {"action"="","routeId"=0,"routeInstanceId"=0,"routeCode"="","floatPlanId"=0,"basicDraft"=false};
  }
  private boolean function validId(required numeric userId) output=false {
    return arguments.userId GT 0 AND arguments.userId LTE 2147483647 AND arguments.userId EQ fix(arguments.userId);
  }
}
