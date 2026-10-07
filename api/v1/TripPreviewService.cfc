component output="false" {
  public any function init(string datasource="fpw") output=false {
    variables.datasource=arguments.datasource;
    return this;
  }

  // Preview admission is deliberately SELECT-only. Never resolve or repair operational state here.
  public struct function getContext(required any userId, required any floatPlanId) output=false {
    var context={
      "eligible"=false, "reasonCode"="PREVIEW_NOT_READY",
      "message"="This trip is not ready to preview.",
      "userId"=0, "floatPlanId"=0, "routeInstanceId"=0
    };
    if (!validId(arguments.userId)) {
      context.reasonCode="AUTH_REQUIRED";
      context.message="Sign in to preview your trip.";
      return context;
    }
    if (!validId(arguments.floatPlanId)) {
      context.reasonCode="INVALID_FLOAT_PLAN_ID";
      context.message="A valid Draft Float Plan is required.";
      return context;
    }
    context.userId=val(arguments.userId);
    context.floatPlanId=val(arguments.floatPlanId);
    var params={
      userId={value=toString(context.userId),cfsqltype="cf_sql_varchar"},
      userIdNumber={value=context.userId,cfsqltype="cf_sql_integer"},
      planId={value=context.floatPlanId,cfsqltype="cf_sql_integer"}
    };
    var plan=queryExecute(
      "SELECT fp.floatPlanId, fp.vesselId, fp.operatorId, UPPER(TRIM(fp.status)) AS plan_status,
              fp.activatedAt, fp.initialSentAt, fp.checkedInAt, fp.closedAt, fp.expiredAt,
              fp.overdueNotifiedAt, fp.escalation1SentAt, fp.escalation2SentAt,
              fp.lastMonitoredAt, fp.monitorLockUntil,
              fp.manual_delay_minutes_total, fp.overnight_pause_minutes_total,
              ri.id AS owned_route_id, ri.generated_route_id,
              UPPER(TRIM(ri.status)) AS route_status, ri.started_at, ri.completed_at,
              v.vesselID AS owned_vessel_id, lr.id AS saved_route_id
       FROM floatplans fp
       LEFT JOIN route_instances ri ON ri.id=fp.route_instance_id AND ri.user_id=:userId
       LEFT JOIN loop_routes lr ON lr.id=ri.generated_route_id
       LEFT JOIN vessels v ON v.vesselID=fp.vesselId AND v.userId=:userId
       WHERE fp.floatPlanId=:planId AND fp.userId=:userId
       LIMIT 1",
      params,{datasource=variables.datasource});
    if (!plan.recordCount) {
      context.reasonCode="PREVIEW_NOT_FOUND";
      context.message="This Draft Float Plan is unavailable.";
      return context;
    }
    if (plan.plan_status[1] NEQ "DRAFT") {
      context.reasonCode="PREVIEW_REQUIRES_DRAFT";
      context.message="Preview is available before this Float Plan is shared or started.";
      return context;
    }
    for (var field in ["activatedAt","initialSentAt","checkedInAt","closedAt","expiredAt",
      "overdueNotifiedAt","escalation1SentAt","escalation2SentAt","lastMonitoredAt","monitorLockUntil"]) {
      if (!isNull(plan[field][1]) AND len(trim(toString(plan[field][1])))) return operationalHistory(context);
    }
    if (val(plan.manual_delay_minutes_total[1]) NEQ 0 OR val(plan.overnight_pause_minutes_total[1]) NEQ 0)
      return operationalHistory(context);
    if (isNull(plan.owned_route_id[1]) OR val(plan.owned_route_id[1]) LTE 0
      OR isNull(plan.saved_route_id[1]) OR val(plan.saved_route_id[1]) LTE 0) {
      context.reasonCode="PREVIEW_ROUTE_REQUIRED";
      context.message="Create a route-backed Draft Float Plan to preview this experience.";
      return context;
    }
    context.routeInstanceId=val(plan.owned_route_id[1]);
    if (plan.route_status[1] NEQ "PLANNED"
      OR (!isNull(plan.started_at[1]) AND len(trim(toString(plan.started_at[1]))))
      OR (!isNull(plan.completed_at[1]) AND len(trim(toString(plan.completed_at[1])))))
      return operationalHistory(context);
    if (isNull(plan.owned_vessel_id[1]) OR val(plan.owned_vessel_id[1]) LTE 0) {
      context.reasonCode="PREVIEW_VESSEL_REQUIRED";
      context.message="Select one of your vessels before previewing this trip.";
      return context;
    }

    params.routeId={value=context.routeInstanceId,cfsqltype="cf_sql_integer"};
    var legs=queryExecute(
      "SELECT leg_order,start_name,end_name FROM route_instance_legs
       WHERE route_instance_id=:routeId ORDER BY leg_order,id",
      params,{datasource=variables.datasource});
    if (!legs.recordCount) {
      context.reasonCode="PREVIEW_LEGS_REQUIRED";
      context.message="Save at least one route leg before previewing this trip.";
      return context;
    }
    if (!meaningfulLabel(isNull(legs.start_name[1]) ? "" : legs.start_name[1])
      OR !meaningfulLabel(isNull(legs.end_name[legs.recordCount]) ? "" : legs.end_name[legs.recordCount])) {
      context.reasonCode="PREVIEW_ENDPOINTS_REQUIRED";
      context.message="Set the route departure and destination before previewing this trip.";
      return context;
    }

    // Optional saved resources are not eligibility requirements, but may never cross owner boundaries.
    var resources=queryExecute(
      "SELECT
       (SELECT COUNT(*) FROM floatplans p LEFT JOIN operators o
          ON o.opId=p.operatorId AND o.userId=:userId
        WHERE p.floatPlanId=:planId AND COALESCE(p.operatorId,0)>0 AND o.opId IS NULL) AS invalid_operator,
       (SELECT COUNT(*) FROM floatplan_contacts pc LEFT JOIN contacts c
          ON c.contactId=pc.contactId AND c.userId=:userId
        WHERE pc.floatPlanId=:planId AND c.contactId IS NULL) AS invalid_contacts,
       (SELECT COUNT(*) FROM floatplan_passengers pp LEFT JOIN passengers p
          ON p.passId=pp.passId AND p.userId=:userId
        WHERE pp.floatPlanId=:planId AND p.passId IS NULL) AS invalid_passengers",
      params,{datasource=variables.datasource});
    if (val(resources.invalid_operator[1])+val(resources.invalid_contacts[1])+val(resources.invalid_passengers[1]) GT 0) {
      context.reasonCode="PREVIEW_RESOURCE_OWNERSHIP_INVALID";
      context.message="A saved trip resource is unavailable for this member.";
      return context;
    }

    var history=queryExecute(
      "SELECT
       (SELECT COUNT(*) FROM route_instance_leg_progress p
        WHERE p.route_instance_id=:routeId
          AND (p.user_id<>:userIdNumber OR UPPER(TRIM(COALESCE(p.status,'')))<>'NOT_STARTED'
               OR p.leg_started_at IS NOT NULL OR p.completed_at IS NOT NULL)) AS progress_count,
       (SELECT COUNT(*) FROM floatplan_monitoring m INNER JOIN floatplans p ON p.floatPlanId=m.float_plan_id
        WHERE p.floatPlanId=:planId OR p.route_instance_id=:routeId) AS monitoring_count,
       (SELECT COUNT(*) FROM floatplan_events e
        WHERE e.floatplan_id=:planId OR e.route_instance_id=:routeId) AS event_count,
       (SELECT COUNT(*) FROM floatplan_activity_segments s
        WHERE s.floatplan_id=:planId OR s.route_instance_id=:routeId) AS segment_count,
       (SELECT COUNT(*) FROM floatplan_monitor_events e INNER JOIN floatplans p ON p.floatPlanId=e.float_plan_id
        WHERE p.floatPlanId=:planId OR p.route_instance_id=:routeId) AS monitor_event_count,
       (SELECT COUNT(*) FROM floatplan_captain_log_entries l
        WHERE l.floatplan_id=:planId OR l.route_instance_id=:routeId) AS captain_log_count,
       (SELECT COUNT(*) FROM voyage_streams v INNER JOIN floatplans p ON p.floatPlanId=v.floatplan_id
        WHERE p.floatPlanId=:planId OR p.route_instance_id=:routeId) AS stream_count,
       (SELECT COUNT(*) FROM floatplan_alert_history h INNER JOIN floatplans p ON p.floatPlanId=h.floatPlanId
        WHERE p.floatPlanId=:planId OR p.route_instance_id=:routeId) AS alert_count,
       (SELECT COUNT(*) FROM floatplan_companion_events e
        WHERE e.floatplan_id=:planId OR e.route_instance_id=:routeId) AS companion_event_count,
       (SELECT COUNT(*) FROM premium_send_receipts r WHERE r.float_plan_id=:planId) AS receipt_count,
       (SELECT COUNT(*) FROM premium_send_credits c WHERE c.consumed_float_plan_id=:planId) AS consumed_credit_count,
       (SELECT COUNT(*) FROM floatplans p WHERE p.route_instance_id=:routeId AND p.floatPlanId<>:planId
          AND (p.activatedAt IS NOT NULL OR p.initialSentAt IS NOT NULL OR p.checkedInAt IS NOT NULL
               OR p.closedAt IS NOT NULL OR p.expiredAt IS NOT NULL
               OR UPPER(TRIM(p.status)) IN ('ACTIVE','CLOSED','CANCELLED','CANCELED','EXPIRED'))) AS prior_plan_count",
      params,{datasource=variables.datasource});
    for (var field in listToArray(history.columnList)) {
      if (val(history[field][1]) GT 0) return operationalHistory(context);
    }
    context.eligible=true;
    context.reasonCode="PREVIEW_READY";
    context.message="Your trip is ready to preview.";
    return context;
  }

  private boolean function validId(required any value) output=false {
    return isSimpleValue(arguments.value)
      AND reFind("^[1-9][0-9]{0,9}$",toString(arguments.value)) EQ 1
      AND !reFind("[^0-9]",toString(arguments.value))
      AND val(arguments.value) LTE 2147483647;
  }

  private boolean function meaningfulLabel(required string value) output=false {
    var label=trim(arguments.value);
    return len(label) GT 0 AND !listFindNoCase("Unknown Start,Unknown End",label);
  }

  private struct function operationalHistory(required struct context) output=false {
    arguments.context.reasonCode="PREVIEW_OPERATIONAL_HISTORY";
    arguments.context.message="This trip has operational history and is unavailable for pre-trip preview.";
    return arguments.context;
  }
}
