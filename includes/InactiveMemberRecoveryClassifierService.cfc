component output="false" {

  variables.datasource = "fpw";
  variables.policyService = "";
  variables.optOutService = "";
  variables.adminService = "";

  public any function init(
    string datasource="fpw",
    any policyService="",
    any optOutService="",
    any adminService=""
  ) output=false {
    variables.datasource = len(trim(arguments.datasource)) ? trim(arguments.datasource) : "fpw";
    variables.policyService = isObject(arguments.policyService)
      ? arguments.policyService
      : createObject("component", "fpw.includes.InactiveMemberRecoveryPolicy");
    variables.optOutService = isObject(arguments.optOutService)
      ? arguments.optOutService
      : createObject("component", "fpw.api.v1.EmailOptOutService").init(datasource=variables.datasource);
    variables.adminService = isObject(arguments.adminService)
      ? arguments.adminService
      : createObject("component", "fpw.api.v1.AdminAuthorizationService").init(variables.datasource);
    return this;
  }

  // Read-only classification. Supplying enrollmentUtc is an explicit upstream
  // attestation that activity/share/recovery coverage was reviewed from enrollment.
  public struct function evaluateMember(
    required numeric userId,
    required string nowUtc,
    string enrollmentUtc="",
    string ownedClaimToken="",
    boolean evaluateFailedRetry=false
  ) output=false {
    var result = baseResult(arguments.userId);
    var member = queryNew("");
    var normalizedEmail = "";
    var duplicateEmail = queryNew("");
    var nowClock = utcClock(arguments.nowUtc);
    var enrollmentClock = utcClock(arguments.enrollmentUtc);
    var events = {};
    var live = {};
    var share = {};
    var currentStage = "";
    var currentRank = 0;
    var highestRank = 0;
    var stageEnteredUtc = "";
    var stageClockSource = "";
    var admin = {};
    var optedOut = false;
    var ledger = {};
    var policyInput = {};
    var policyDecision = {};
    var latestActivity = {};
    var lastRecovery = {};

    if (arguments.userId LTE 0 OR arguments.userId NEQ fix(arguments.userId)) {
      return finish(result, "UNCLASSIFIED", "MEMBER_NOT_FOUND", "HELD");
    }

    member = queryExecute(
      "SELECT userId,email FROM users WHERE userId=:userId LIMIT 1",
      {userId={value=fix(arguments.userId),cfsqltype="cf_sql_integer"}},
      {datasource=variables.datasource}
    );
    if (member.recordCount NEQ 1) {
      return finish(result, "UNCLASSIFIED", "MEMBER_NOT_FOUND", "HELD");
    }
    result.MEMBER_ID = fix(arguments.userId);

    normalizedEmail = lCase(trim(toString(member.email[1])));
    duplicateEmail = queryExecute(
      "SELECT COUNT(*) AS row_count FROM users WHERE LOWER(TRIM(email))=:email",
      {email={value=normalizedEmail,cfsqltype="cf_sql_varchar"}},
      {datasource=variables.datasource}
    );

    events = loadEventEvidence(fix(arguments.userId));
    live = loadLiveEvidence(fix(arguments.userId));
    share = loadShareEvidence(fix(arguments.userId));

    currentStage = live.DRAFT_COUNT GT 0
      ? "D"
      : ((live.USER_ROUTE_COUNT GT 0 OR live.PLANNED_ROUTE_COUNT GT 0)
        ? "C"
        : (live.VESSEL_COUNT GT 0 ? "B" : "A"));
    currentRank = stageRank(currentStage);
    highestRank = max(currentRank, max(events.HIGHEST_STAGE_RANK, live.HIGHEST_LIVE_HISTORY_RANK));
    stageEnteredUtc = events.ENTRY_CLOCKS[currentStage];
    stageClockSource = len(stageEnteredUtc) ? events.ENTRY_SOURCES[currentStage] : "";

    result.CURRENT_STAGE = currentStage;
    result.CLASSIFICATION = currentStage;
    result.HIGHEST_VERIFIED_STAGE = stageName(highestRank);
    result.STAGE_ENTERED_UTC = stageEnteredUtc;
    result.LATEST_QUALIFYING_ACTIVITY_UTC = events.LATEST_ACTIVITY_AT_UTC;
    result.EVIDENCE_SUMMARY = {
      STAGE_CLOCK_SOURCE=stageClockSource,
      HIGHEST_HISTORY_SOURCE=events.HIGHEST_STAGE_SOURCE,
      LIVE={
        VESSEL_EXISTS=(live.VESSEL_COUNT GT 0),
        SAVED_ROUTE_EXISTS=(live.USER_ROUTE_COUNT GT 0),
        PLANNED_ROUTE_EXISTS=(live.PLANNED_ROUTE_COUNT GT 0),
        DRAFT_EXISTS=(live.DRAFT_COUNT GT 0),
        ACTIVE_TRIP_EXISTS=(live.ACTIVE_PLAN_COUNT GT 0 OR live.ACTIVE_ROUTE_COUNT GT 0),
        ACTIVE_MONITORING_EXISTS=(live.ACTIVE_MONITORING_COUNT GT 0)
      },
      SHARE={
        BASIC_EVENT=share.BASIC_EVENT,
        PREMIUM_EVENT=share.PREMIUM_EVENT,
        BASIC_RECEIPT=share.BASIC_RECEIPT,
        PREMIUM_RECEIPT=share.PREMIUM_RECEIPT,
        INITIAL_SEND=share.INITIAL_SEND
      },
      LATEST_ACTIVITY={
        FOUND=events.HAS_LATEST_ACTIVITY,
        STATE=(events.HAS_LATEST_ACTIVITY ? "RECORDED" : "NO_QUALIFYING_ACTIVITY_EVIDENCE"),
        EVENT_NAME=events.LATEST_ACTIVITY_EVENT,
        AT_UTC=events.LATEST_ACTIVITY_AT_UTC
      },
      TEST_ACCOUNT_SUPPRESSION="REQUIRES_EXPLICIT_CONFIG_OR_INPUT",
      ENROLLMENT_SOURCE=(len(trim(arguments.enrollmentUtc)) ? "caller_supplied" : "missing")
    };

    if (live.OWNERSHIP_CONFLICT OR share.OWNERSHIP_CONFLICT OR events.OWNERSHIP_CONFLICT) {
      return finish(result, currentStage, "HOLD_CONTRADICTORY_EVIDENCE", "HELD");
    }

    if (share.HAS_SUCCESSFUL_SHARE) {
      result.CURRENT_STAGE = "";
      result.HIGHEST_VERIFIED_STAGE = "SHARED";
      return finish(result, "SHARED", "SUPPRESSED_ALREADY_SHARED", "SUPPRESSED");
    }

    if (!nowClock.VALID) {
      return finish(result, currentStage, "HOLD_CONTRADICTORY_EVIDENCE", "HELD");
    }

    if (live.LIFECYCLE_CONFLICT) {
      return finish(result, currentStage, "HOLD_CONTRADICTORY_EVIDENCE", "HELD");
    }

    if (val(duplicateEmail.row_count[1]) GT 1) {
      return finish(result, currentStage, "HOLD_DUPLICATE_EMAIL_IDENTITY", "HELD");
    }
    if (!isValid("email", normalizedEmail)) {
      return finish(result, currentStage, "SUPPRESSED_INVALID_EMAIL", "SUPPRESSED");
    }

    try {
      admin = variables.adminService.authorizeCurrentSession({userId=fix(arguments.userId)});
    } catch (any adminLookupError) {
      return finish(result, currentStage, "HOLD_ADMIN_LOOKUP_FAILED", "HELD");
    }
    result.EVIDENCE_SUMMARY.ADMIN_ENTITLEMENT_ACTIVE = (
      structKeyExists(admin, "authorized") AND admin.authorized
    );
    if (result.EVIDENCE_SUMMARY.ADMIN_ENTITLEMENT_ACTIVE) {
      return finish(result, currentStage, "SUPPRESSED_ADMIN", "SUPPRESSED");
    }

    try {
      optedOut = variables.optOutService.isOptedOut(normalizedEmail, "non_essential");
    } catch (any preferenceLookupError) {
      return finish(result, currentStage, "HOLD_PREFERENCE_LOOKUP_FAILED", "HELD");
    }
    result.EVIDENCE_SUMMARY.OPTED_OUT = optedOut;
    if (optedOut) {
      return finish(result, currentStage, "SUPPRESSED_OPTED_OUT", "SUPPRESSED");
    }

    if (live.ACTIVE_PLAN_COUNT GT 0 OR live.ACTIVE_ROUTE_COUNT GT 0 OR live.ACTIVE_MONITORING_COUNT GT 0) {
      return finish(result, currentStage, "SUPPRESSED_ACTIVE_TRIP", "SUPPRESSED");
    }

    if (highestRank GT currentRank) {
      return finish(result, currentStage, "HOLD_CONTRADICTORY_EVIDENCE", "HELD");
    }

    ledger = loadLedgerEvidence(fix(arguments.userId), currentStage, arguments.ownedClaimToken);
    result.LEDGER_STATE = ledger.CURRENT_STAGE;
    result.LATEST_RECOVERY_SENT_UTC = ledger.LATEST_SENT_AT_UTC;
    result.EVIDENCE_SUMMARY.LEDGER = {
      CURRENT_STAGE_STATUS=ledger.CURRENT_STAGE.STATUS,
      CURRENT_STAGE_ATTEMPT_COUNT=ledger.CURRENT_STAGE.ATTEMPT_COUNT,
      HAS_UNRESOLVED_CLAIM=ledger.HAS_UNRESOLVED_CLAIM,
      LATEST_SENT_STAGE=ledger.LATEST_SENT_STAGE,
      LATEST_SENT_AT_UTC=ledger.LATEST_SENT_AT_UTC
    };

    if (ledger.CURRENT_STAGE.STATUS EQ "SENT") {
      return finish(result, currentStage, "SUPPRESSED_STAGE_ALREADY_SENT", "SUPPRESSED");
    }
    if (len(arguments.ownedClaimToken) AND !ledger.OWNS_CURRENT_CLAIM) {
      return finish(result, currentStage, "HOLD_CLAIM_MISMATCH", "HELD");
    }
    if (ledger.CURRENT_STAGE.STATUS EQ "CLAIMED" AND !ledger.OWNS_CURRENT_CLAIM) {
      return finish(result, currentStage, "SUPPRESSED_UNRESOLVED_CLAIM", "SUPPRESSED");
    }
    if (ledger.CURRENT_STAGE.STATUS EQ "FAILED" AND !arguments.evaluateFailedRetry) {
      return finish(result, currentStage, "HOLD_RETRY_DECISION_REQUIRED", "HELD");
    }
    if (!listFind("NONE,SENT,CLAIMED,FAILED", ledger.CURRENT_STAGE.STATUS)) {
      return finish(result, currentStage, "HOLD_CONTRADICTORY_EVIDENCE", "HELD");
    }
    if (ledger.HAS_UNRESOLVED_CLAIM) {
      return finish(result, currentStage, "SUPPRESSED_UNRESOLVED_CLAIM", "SUPPRESSED");
    }

    if (!len(stageEnteredUtc)) {
      return finish(result, currentStage, "HOLD_INCOMPLETE_STAGE_CLOCK", "HELD");
    }
    if (!len(trim(arguments.enrollmentUtc))) {
      return finish(result, currentStage, "ENROLLMENT_EVIDENCE_REQUIRED", "HELD");
    }
    if (!enrollmentClock.VALID OR enrollmentClock.SECONDS GT nowClock.SECONDS) {
      return finish(result, currentStage, "HOLD_CONTRADICTORY_EVIDENCE", "HELD");
    }
    if (!utcClock(stageEnteredUtc).VALID OR utcClock(stageEnteredUtc).SECONDS GT nowClock.SECONDS) {
      return finish(result, currentStage, "HOLD_CONTRADICTORY_EVIDENCE", "HELD");
    }
    if (events.HAS_LATEST_ACTIVITY
      AND (!utcClock(events.LATEST_ACTIVITY_AT_UTC).VALID
        OR utcClock(events.LATEST_ACTIVITY_AT_UTC).SECONDS GT nowClock.SECONDS)) {
      return finish(result, currentStage, "HOLD_CONTRADICTORY_EVIDENCE", "HELD");
    }
    if (len(ledger.LATEST_SENT_AT_UTC)
      AND (!utcClock(ledger.LATEST_SENT_AT_UTC).VALID
        OR utcClock(ledger.LATEST_SENT_AT_UTC).SECONDS GT nowClock.SECONDS)) {
      return finish(result, currentStage, "HOLD_CONTRADICTORY_EVIDENCE", "HELD");
    }
    if (len(ledger.LATEST_SENT_STAGE) AND stageRank(ledger.LATEST_SENT_STAGE) GTE currentRank) {
      return finish(result, currentStage, "HOLD_CONTRADICTORY_EVIDENCE", "HELD");
    }

    latestActivity = events.HAS_LATEST_ACTIVITY
      ? {
          state="recorded",
          at_utc=events.LATEST_ACTIVITY_AT_UTC,
          action=activityAction(events.LATEST_ACTIVITY_EVENT)
        }
      : {state="none_verified"};
    lastRecovery = len(ledger.LATEST_SENT_AT_UTC)
      ? {state="sent",stage=ledger.LATEST_SENT_STAGE,at_utc=ledger.LATEST_SENT_AT_UTC}
      : {state="never_sent"};

    policyInput = {
      account_exists=true,
      stage=currentStage,
      highest_verified_stage=currentStage,
      has_successful_share=false,
      verification={
        stage_history=true,
        activity_coverage=true,
        sharing_history=true,
        recovery_history=true,
        ownership=true,
        lifecycle=true
      },
      exclusions={
        opt_out=false,
        administrator_or_test=false,
        invalid_recipient=false,
        active_trip_or_monitoring=false,
        contradictory_lifecycle=false,
        other=false
      },
      current_stage_recovery="never_sent",
      now_utc=trim(arguments.nowUtc),
      enrollment_utc=trim(arguments.enrollmentUtc),
      current_stage_entered_utc=stageEnteredUtc,
      latest_activity=latestActivity,
      last_recovery=lastRecovery
    };
    result.POLICY_INPUT_SUMMARY = {
      STAGE=policyInput.stage,
      STAGE_ENTERED_UTC=policyInput.current_stage_entered_utc,
      ENROLLMENT_UTC=policyInput.enrollment_utc,
      LATEST_ACTIVITY_STATE=policyInput.latest_activity.state,
      LATEST_ACTIVITY_AT_UTC=(structKeyExists(policyInput.latest_activity,"at_utc") ? policyInput.latest_activity.at_utc : ""),
      LAST_RECOVERY_STATE=policyInput.last_recovery.state,
      LAST_RECOVERY_STAGE=(structKeyExists(policyInput.last_recovery,"stage") ? policyInput.last_recovery.stage : ""),
      LAST_RECOVERY_AT_UTC=(structKeyExists(policyInput.last_recovery,"at_utc") ? policyInput.last_recovery.at_utc : "")
    };

    policyDecision = variables.policyService.evaluate(policyInput);
    result.POLICY_DECISION = duplicate(policyDecision);
    if (policyDecision.decision EQ "ELIGIBLE") {
      return finish(result, currentStage, "ELIGIBLE", "ELIGIBLE");
    }
    if (policyDecision.decision EQ "DEFERRED") {
      if (len(ledger.LATEST_SENT_AT_UTC)
        AND structKeyExists(policyDecision,"anchor_utc")
        AND compare(ledger.LATEST_SENT_AT_UTC, policyDecision.anchor_utc) EQ 0) {
        return finish(result, currentStage, "SUPPRESSED_CROSS_STAGE_SPACING", "DEFERRED");
      }
      if (events.HAS_LATEST_ACTIVITY
        AND structKeyExists(policyDecision,"anchor_utc")
        AND compare(events.LATEST_ACTIVITY_AT_UTC, policyDecision.anchor_utc) EQ 0) {
        return finish(result, currentStage, "SUPPRESSED_RECENT_ACTIVITY", "DEFERRED");
      }
      return finish(result, currentStage, "DEFERRED_WAITING_FOR_INTERVAL", "DEFERRED");
    }
    return finish(result, currentStage, mapPolicyHold(policyDecision), policyDecision.decision);
  }

  private struct function loadEventEvidence(required numeric userId) output=false {
    var result = {
      ENTRY_CLOCKS={A="",B="",C="",D=""},
      ENTRY_SOURCES={A="",B="",C="",D=""},
      HIGHEST_STAGE_RANK=0,
      HIGHEST_STAGE_SOURCE="",
      HAS_LATEST_ACTIVITY=false,
      LATEST_ACTIVITY_EVENT="",
      LATEST_ACTIVITY_AT_UTC="",
      OWNERSHIP_CONFLICT=false
    };
    var stageEvents = queryExecute(
      "SELECT event_name,entity_type,entity_id,event_source,DATE_FORMAT(occurred_at_utc,'%Y-%m-%dT%H:%i:%sZ') AS at_utc
       FROM product_events
       WHERE user_id=:userId AND (
         (event_name='sign_up' AND entity_type='user' AND event_source='member_signup') OR
         (event_name='vessel_created' AND entity_type='vessel' AND event_source='member_api') OR
         (event_name='user_route_created' AND entity_type='user_route' AND event_source='member_api') OR
         (event_name='route_created' AND entity_type='route_instance' AND event_source='member_api') OR
         (event_name='float_plan_created' AND entity_type='float_plan' AND event_source='member_api')
       ) ORDER BY occurred_at_utc,id",
      {userId={value=arguments.userId,cfsqltype="cf_sql_integer"}},
      {datasource=variables.datasource}
    );
    var index = 0;
    var stage = "";
    for (index=1; index LTE stageEvents.recordCount; index++) {
      stage = stageForCreationEvent(toString(stageEvents.event_name[index]));
      if (stage EQ "A" AND val(stageEvents.entity_id[index]) NEQ arguments.userId) {
        result.OWNERSHIP_CONFLICT = true;
      }
      if (len(stage) AND !len(result.ENTRY_CLOCKS[stage])) {
        result.ENTRY_CLOCKS[stage] = toString(stageEvents.at_utc[index]);
        result.ENTRY_SOURCES[stage] = toString(stageEvents.event_name[index]);
      }
      if (stageRank(stage) GT result.HIGHEST_STAGE_RANK) {
        result.HIGHEST_STAGE_RANK = stageRank(stage);
        result.HIGHEST_STAGE_SOURCE = toString(stageEvents.event_name[index]);
      }
    }

    var activity = queryExecute(
      "SELECT event_name,DATE_FORMAT(occurred_at_utc,'%Y-%m-%dT%H:%i:%sZ') AS at_utc
       FROM product_events
       WHERE user_id=:userId AND event_source='member_api' AND event_name IN (
         'vessel_created','vessel_updated','shore_contact_created','shore_contact_updated',
         'operator_created','operator_updated','passenger_created','passenger_updated',
         'waypoint_created','waypoint_updated','user_route_created','user_route_updated',
         'route_created','route_updated','route_segment_updated','float_plan_created','float_plan_updated'
       ) ORDER BY occurred_at_utc DESC,id DESC LIMIT 1",
      {userId={value=arguments.userId,cfsqltype="cf_sql_integer"}},
      {datasource=variables.datasource}
    );
    if (activity.recordCount EQ 1) {
      result.HAS_LATEST_ACTIVITY = true;
      result.LATEST_ACTIVITY_EVENT = toString(activity.event_name[1]);
      result.LATEST_ACTIVITY_AT_UTC = toString(activity.at_utc[1]);
    }
    result.OWNERSHIP_CONFLICT = result.OWNERSHIP_CONFLICT OR hasEventOwnershipConflict(arguments.userId);
    return result;
  }

  private struct function loadLiveEvidence(required numeric userId) output=false {
    var q = queryExecute(
      "SELECT
        (SELECT COUNT(*) FROM vessels v WHERE CAST(v.userId AS UNSIGNED)=:userId) AS vessel_count,
        (SELECT COUNT(*) FROM user_routes ur WHERE ur.user_id=:userId) AS user_route_count,
        (SELECT COUNT(*) FROM route_instances ri WHERE CAST(ri.user_id AS UNSIGNED)=:userId
          AND UPPER(TRIM(ri.status))='PLANNED' AND ri.started_at IS NULL AND ri.completed_at IS NULL) AS planned_route_count,
        (SELECT COUNT(*) FROM floatplans fp WHERE CAST(fp.userId AS UNSIGNED)=:userId
          AND UPPER(TRIM(fp.status))='DRAFT' AND fp.initialSentAt IS NULL
          AND fp.activatedAt IS NULL AND fp.closedAt IS NULL AND fp.expiredAt IS NULL
          AND COALESCE(TRIM(fp.end_reason),'')='') AS draft_count,
        (SELECT COUNT(*) FROM floatplans fp WHERE CAST(fp.userId AS UNSIGNED)=:userId
          AND UPPER(TRIM(fp.status))='ACTIVE') AS active_plan_count,
        (SELECT COUNT(*) FROM route_instances ri WHERE CAST(ri.user_id AS UNSIGNED)=:userId AND (
          UPPER(TRIM(ri.status))='ACTIVE' OR
          (ri.started_at IS NOT NULL AND ri.completed_at IS NULL) OR
          EXISTS (SELECT 1 FROM route_instance_leg_progress rilp
            WHERE rilp.route_instance_id=ri.id AND rilp.user_id=:userId
              AND UPPER(TRIM(rilp.status))='STARTED' AND rilp.completed_at IS NULL)
        )) AS active_route_count,
        (SELECT COUNT(*) FROM floatplan_monitoring fm WHERE fm.user_id=:userId
          AND fm.is_monitoring_enabled=1 AND UPPER(TRIM(fm.monitor_state)) NOT IN ('RESOLVED','CLOSED')) AS active_monitoring_count,
        (SELECT COUNT(*) FROM route_instances ri WHERE CAST(ri.user_id AS UNSIGNED)=:userId) AS all_route_count,
        (SELECT COUNT(*) FROM floatplans fp WHERE CAST(fp.userId AS UNSIGNED)=:userId) AS all_plan_count,
        (SELECT COUNT(*) FROM floatplans fp
          LEFT JOIN route_instances ri ON ri.id=fp.route_instance_id
          LEFT JOIN vessels v ON v.vesselID=fp.vesselId
          LEFT JOIN operators o ON o.opId=fp.operatorId
          WHERE CAST(fp.userId AS UNSIGNED)=:userId AND UPPER(TRIM(fp.status))='DRAFT' AND (
            fp.initialSentAt IS NOT NULL OR fp.activatedAt IS NOT NULL OR fp.closedAt IS NOT NULL
            OR fp.expiredAt IS NOT NULL OR COALESCE(TRIM(fp.end_reason),'')<>''
            OR (fp.route_instance_id IS NOT NULL AND (ri.id IS NULL OR CAST(ri.user_id AS UNSIGNED)<>:userId
              OR UPPER(TRIM(ri.status))<>'PLANNED' OR ri.started_at IS NOT NULL OR ri.completed_at IS NOT NULL))
            OR (fp.vesselId IS NOT NULL AND (v.vesselID IS NULL OR CAST(v.userId AS UNSIGNED)<>:userId))
            OR (fp.operatorId IS NOT NULL AND (o.opId IS NULL OR CAST(o.userId AS UNSIGNED)<>:userId))
          )) AS lifecycle_conflict_count,
        (SELECT COUNT(*) FROM route_instances ri WHERE CAST(ri.user_id AS UNSIGNED)=:userId
          AND UPPER(TRIM(ri.status))='PLANNED' AND (ri.started_at IS NOT NULL OR ri.completed_at IS NOT NULL)) AS route_conflict_count",
      {userId={value=arguments.userId,cfsqltype="cf_sql_integer"}},
      {datasource=variables.datasource}
    );
    var vesselCount = val(q.vessel_count[1]);
    var routeCount = val(q.all_route_count[1]) + val(q.user_route_count[1]);
    var planCount = val(q.all_plan_count[1]);
    return {
      VESSEL_COUNT=vesselCount,
      USER_ROUTE_COUNT=val(q.user_route_count[1]),
      PLANNED_ROUTE_COUNT=val(q.planned_route_count[1]),
      DRAFT_COUNT=val(q.draft_count[1]),
      ACTIVE_PLAN_COUNT=val(q.active_plan_count[1]),
      ACTIVE_ROUTE_COUNT=val(q.active_route_count[1]),
      ACTIVE_MONITORING_COUNT=val(q.active_monitoring_count[1]),
      HIGHEST_LIVE_HISTORY_RANK=(planCount GT 0 ? 4 : (routeCount GT 0 ? 3 : (vesselCount GT 0 ? 2 : 1))),
      LIFECYCLE_CONFLICT=(val(q.lifecycle_conflict_count[1]) GT 0 OR val(q.route_conflict_count[1]) GT 0),
      OWNERSHIP_CONFLICT=false
    };
  }

  private struct function loadShareEvidence(required numeric userId) output=false {
    var q = queryExecute(
      "SELECT
        EXISTS(SELECT 1 FROM product_events e WHERE e.user_id=:userId AND e.entity_type='float_plan'
          AND e.event_name='basic_send_completed' AND e.event_source IN ('basic_save_send','basic_review_send')) AS basic_event,
        EXISTS(SELECT 1 FROM product_events e WHERE e.user_id=:userId AND e.entity_type='float_plan'
          AND e.event_name='premium_send_completed' AND e.event_source='premium_save_send') AS premium_event,
        EXISTS(SELECT 1 FROM basic_review_send_receipts b WHERE b.user_id=:userId AND UPPER(TRIM(b.status))='SENT'
          AND b.completed_at_utc IS NOT NULL) AS basic_receipt,
        EXISTS(SELECT 1 FROM premium_send_receipts p WHERE p.user_id=:userId AND p.committed_at_utc IS NOT NULL
          AND p.recipient_count>0) AS premium_receipt,
        EXISTS(SELECT 1 FROM floatplans fp WHERE CAST(fp.userId AS UNSIGNED)=:userId AND fp.initialSentAt IS NOT NULL) AS initial_send",
      {userId={value=arguments.userId,cfsqltype="cf_sql_integer"}},
      {datasource=variables.datasource}
    );
    var result = {
      BASIC_EVENT=(val(q.basic_event[1]) EQ 1),
      PREMIUM_EVENT=(val(q.premium_event[1]) EQ 1),
      BASIC_RECEIPT=(val(q.basic_receipt[1]) EQ 1),
      PREMIUM_RECEIPT=(val(q.premium_receipt[1]) EQ 1),
      INITIAL_SEND=(val(q.initial_send[1]) EQ 1),
      OWNERSHIP_CONFLICT=hasShareOwnershipConflict(arguments.userId)
    };
    result.HAS_SUCCESSFUL_SHARE = result.BASIC_EVENT OR result.PREMIUM_EVENT
      OR result.BASIC_RECEIPT OR result.PREMIUM_RECEIPT OR result.INITIAL_SEND;
    return result;
  }

  private struct function loadLedgerEvidence(
    required numeric userId, required string stage, string ownedClaimToken=""
  ) output=false {
    var current = queryExecute(
      "SELECT status,attempt_count,DATE_FORMAT(claimed_at_utc,'%Y-%m-%dT%H:%i:%sZ') AS claimed_at_utc,
        DATE_FORMAT(sent_at_utc,'%Y-%m-%dT%H:%i:%sZ') AS sent_at_utc,
        DATE_FORMAT(failed_at_utc,'%Y-%m-%dT%H:%i:%sZ') AS failed_at_utc,
        (status='CLAIMED' AND claim_token=:claimToken AND :claimToken<>'') AS owns_claim
       FROM inactive_member_recovery_deliveries WHERE user_id=:userId AND recovery_stage=:stage LIMIT 1",
      {
        userId={value=arguments.userId,cfsqltype="cf_sql_integer"},
        stage={value=arguments.stage,cfsqltype="cf_sql_char"},
        claimToken={value=arguments.ownedClaimToken,cfsqltype="cf_sql_varchar"}
      },
      {datasource=variables.datasource}
    );
    var latest = queryExecute(
      "SELECT recovery_stage,DATE_FORMAT(sent_at_utc,'%Y-%m-%dT%H:%i:%sZ') AS sent_at_utc
       FROM inactive_member_recovery_deliveries WHERE user_id=:userId AND status='SENT'
       ORDER BY sent_at_utc DESC,id DESC LIMIT 1",
      {userId={value=arguments.userId,cfsqltype="cf_sql_integer"}},
      {datasource=variables.datasource}
    );
    var claimed = queryExecute(
      "SELECT COUNT(*) AS row_count FROM inactive_member_recovery_deliveries
       WHERE user_id=:userId AND status='CLAIMED'
         AND NOT (recovery_stage=:stage AND claim_token=:claimToken AND :claimToken<>'')",
      {
        userId={value=arguments.userId,cfsqltype="cf_sql_integer"},
        stage={value=arguments.stage,cfsqltype="cf_sql_char"},
        claimToken={value=arguments.ownedClaimToken,cfsqltype="cf_sql_varchar"}
      },
      {datasource=variables.datasource}
    );
    var currentState = {
      HAS_ROW=false,STATUS="NONE",ATTEMPT_COUNT=0,CLAIMED_AT_UTC="",SENT_AT_UTC="",
      FAILED_AT_UTC=""
    };
    if (current.recordCount EQ 1) {
      currentState = {
        HAS_ROW=true,
        STATUS=uCase(trim(toString(current.status[1]))),
        ATTEMPT_COUNT=val(current.attempt_count[1]),
        CLAIMED_AT_UTC=(isNull(current.claimed_at_utc[1]) ? "" : toString(current.claimed_at_utc[1])),
        SENT_AT_UTC=(isNull(current.sent_at_utc[1]) ? "" : toString(current.sent_at_utc[1])),
        FAILED_AT_UTC=(isNull(current.failed_at_utc[1]) ? "" : toString(current.failed_at_utc[1]))
      };
    }
    return {
      CURRENT_STAGE=currentState,
      OWNS_CURRENT_CLAIM=(current.recordCount EQ 1 AND val(current.owns_claim[1]) EQ 1),
      HAS_UNRESOLVED_CLAIM=(val(claimed.row_count[1]) GT 0),
      LATEST_SENT_STAGE=(latest.recordCount EQ 1 ? toString(latest.recovery_stage[1]) : ""),
      LATEST_SENT_AT_UTC=(latest.recordCount EQ 1 ? toString(latest.sent_at_utc[1]) : "")
    };
  }

  private boolean function hasEventOwnershipConflict(required numeric userId) output=false {
    var q = queryExecute(
      "SELECT COALESCE(SUM(conflict_count),0) AS conflict_count FROM (
        SELECT COUNT(*) conflict_count FROM product_events e JOIN vessels v ON v.vesselID=e.entity_id
          WHERE e.user_id=:userId AND e.entity_type='vessel' AND e.event_name IN ('vessel_created','vessel_updated')
            AND CAST(v.userId AS UNSIGNED)<>:userId
        UNION ALL SELECT COUNT(*) FROM product_events e JOIN contacts c ON c.contactId=e.entity_id
          WHERE e.user_id=:userId AND e.entity_type='shore_contact'
            AND e.event_name IN ('shore_contact_created','shore_contact_updated')
            AND CAST(c.userId AS UNSIGNED)<>:userId
        UNION ALL SELECT COUNT(*) FROM product_events e JOIN operators o ON o.opId=e.entity_id
          WHERE e.user_id=:userId AND e.entity_type='operator'
            AND e.event_name IN ('operator_created','operator_updated')
            AND CAST(o.userId AS UNSIGNED)<>:userId
        UNION ALL SELECT COUNT(*) FROM product_events e JOIN passengers p ON p.passId=e.entity_id
          WHERE e.user_id=:userId AND e.entity_type='passenger'
            AND e.event_name IN ('passenger_created','passenger_updated')
            AND CAST(p.userId AS UNSIGNED)<>:userId
        UNION ALL SELECT COUNT(*) FROM product_events e JOIN waypoints w ON w.wpId=e.entity_id
          WHERE e.user_id=:userId AND e.entity_type='waypoint'
            AND e.event_name IN ('waypoint_created','waypoint_updated')
            AND CAST(w.userId AS UNSIGNED)<>:userId
        UNION ALL SELECT COUNT(*) FROM product_events e JOIN user_routes r ON r.id=e.entity_id
          WHERE e.user_id=:userId AND e.entity_type='user_route'
            AND e.event_name IN ('user_route_created','user_route_updated')
            AND r.user_id<>:userId
        UNION ALL SELECT COUNT(*) FROM product_events e JOIN route_instances r ON r.id=e.entity_id
          WHERE e.user_id=:userId AND e.entity_type='route_instance'
            AND e.event_name IN ('route_created','route_updated')
            AND CAST(r.user_id AS UNSIGNED)<>:userId
        UNION ALL SELECT COUNT(*) FROM product_events e JOIN user_segment_overrides s ON s.id=e.entity_id
          WHERE e.user_id=:userId AND e.entity_type='user_segment_override'
            AND e.event_name='route_segment_updated' AND s.user_id<>:userId
        UNION ALL SELECT COUNT(*) FROM product_events e JOIN floatplans f ON f.floatPlanId=e.entity_id
          WHERE e.user_id=:userId AND e.entity_type='float_plan'
            AND e.event_name IN ('float_plan_created','float_plan_updated','basic_send_completed','premium_send_completed')
            AND CAST(f.userId AS UNSIGNED)<>:userId
        UNION ALL SELECT COUNT(*) FROM product_events e JOIN vessels v ON v.vesselID=e.entity_id
          WHERE e.user_id<>:userId AND e.entity_type='vessel' AND e.event_name IN ('vessel_created','vessel_updated')
            AND CAST(v.userId AS UNSIGNED)=:userId
        UNION ALL SELECT COUNT(*) FROM product_events e JOIN contacts c ON c.contactId=e.entity_id
          WHERE e.user_id<>:userId AND e.entity_type='shore_contact'
            AND e.event_name IN ('shore_contact_created','shore_contact_updated')
            AND CAST(c.userId AS UNSIGNED)=:userId
        UNION ALL SELECT COUNT(*) FROM product_events e JOIN operators o ON o.opId=e.entity_id
          WHERE e.user_id<>:userId AND e.entity_type='operator'
            AND e.event_name IN ('operator_created','operator_updated')
            AND CAST(o.userId AS UNSIGNED)=:userId
        UNION ALL SELECT COUNT(*) FROM product_events e JOIN passengers p ON p.passId=e.entity_id
          WHERE e.user_id<>:userId AND e.entity_type='passenger'
            AND e.event_name IN ('passenger_created','passenger_updated')
            AND CAST(p.userId AS UNSIGNED)=:userId
        UNION ALL SELECT COUNT(*) FROM product_events e JOIN waypoints w ON w.wpId=e.entity_id
          WHERE e.user_id<>:userId AND e.entity_type='waypoint'
            AND e.event_name IN ('waypoint_created','waypoint_updated')
            AND CAST(w.userId AS UNSIGNED)=:userId
        UNION ALL SELECT COUNT(*) FROM product_events e JOIN user_routes r ON r.id=e.entity_id
          WHERE e.user_id<>:userId AND e.entity_type='user_route'
            AND e.event_name IN ('user_route_created','user_route_updated')
            AND r.user_id=:userId
        UNION ALL SELECT COUNT(*) FROM product_events e JOIN route_instances r ON r.id=e.entity_id
          WHERE e.user_id<>:userId AND e.entity_type='route_instance'
            AND e.event_name IN ('route_created','route_updated')
            AND CAST(r.user_id AS UNSIGNED)=:userId
        UNION ALL SELECT COUNT(*) FROM product_events e JOIN user_segment_overrides s ON s.id=e.entity_id
          WHERE e.user_id<>:userId AND e.entity_type='user_segment_override'
            AND e.event_name='route_segment_updated' AND s.user_id=:userId
        UNION ALL SELECT COUNT(*) FROM product_events e JOIN floatplans f ON f.floatPlanId=e.entity_id
          WHERE e.user_id<>:userId AND e.entity_type='float_plan'
            AND e.event_name IN ('float_plan_created','float_plan_updated','basic_send_completed','premium_send_completed')
            AND CAST(f.userId AS UNSIGNED)=:userId
      ) conflicts",
      {userId={value=arguments.userId,cfsqltype="cf_sql_integer"}},
      {datasource=variables.datasource}
    );
    return val(q.conflict_count[1]) GT 0;
  }

  private boolean function hasShareOwnershipConflict(required numeric userId) output=false {
    var q = queryExecute(
      "SELECT COALESCE(SUM(conflict_count),0) AS conflict_count FROM (
        SELECT COUNT(*) conflict_count FROM basic_review_send_receipts r JOIN floatplans f ON f.floatPlanId=r.float_plan_id
          WHERE r.user_id=:userId AND CAST(f.userId AS UNSIGNED)<>:userId
        UNION ALL SELECT COUNT(*) FROM premium_send_receipts r JOIN floatplans f ON f.floatPlanId=r.float_plan_id
          WHERE r.user_id=:userId AND CAST(f.userId AS UNSIGNED)<>:userId
        UNION ALL SELECT COUNT(*) FROM basic_review_send_receipts r JOIN floatplans f ON f.floatPlanId=r.float_plan_id
          WHERE r.user_id<>:userId AND CAST(f.userId AS UNSIGNED)=:userId
        UNION ALL SELECT COUNT(*) FROM premium_send_receipts r JOIN floatplans f ON f.floatPlanId=r.float_plan_id
          WHERE r.user_id<>:userId AND CAST(f.userId AS UNSIGNED)=:userId
      ) conflicts",
      {userId={value=arguments.userId,cfsqltype="cf_sql_integer"}},
      {datasource=variables.datasource}
    );
    return val(q.conflict_count[1]) GT 0;
  }

  private struct function activityAction(required string eventName) output=false {
    var name = trim(arguments.eventName);
    var entity = "";
    if (listFind("vessel_created,vessel_updated",name)) entity="vessel";
    else if (listFind("shore_contact_created,shore_contact_updated",name)) entity="shore_contact";
    else if (listFind("operator_created,operator_updated",name)) entity="operator";
    else if (listFind("passenger_created,passenger_updated",name)) entity="passenger";
    else if (listFind("waypoint_created,waypoint_updated",name)) entity="saved_waypoint";
    else if (listFind("user_route_created,user_route_updated,route_created,route_updated",name)) entity="route";
    else if (name EQ "route_segment_updated") entity="route_leg";
    else if (listFind("float_plan_created,float_plan_updated",name)) entity="draft";
    return {
      entity=entity,
      operation=(right(name,8) EQ "_created" ? "create" : "save"),
      changed=true,
      successful=true,
      member_initiated=true,
      owned=true,
      persisted=true
    };
  }

  private string function stageForCreationEvent(required string eventName) output=false {
    if (arguments.eventName EQ "sign_up") return "A";
    if (arguments.eventName EQ "vessel_created") return "B";
    if (listFind("user_route_created,route_created",arguments.eventName)) return "C";
    if (arguments.eventName EQ "float_plan_created") return "D";
    return "";
  }

  private numeric function stageRank(required string stage) output=false {
    return listFind("A,B,C,D",uCase(trim(arguments.stage)));
  }

  private string function stageName(required numeric rank) output=false {
    return arguments.rank GTE 1 AND arguments.rank LTE 4 ? listGetAt("A,B,C,D",arguments.rank) : "";
  }

  private struct function utcClock(required string value) output=false {
    var result = {VALID=false,SECONDS=0};
    var candidate = trim(arguments.value);
    if (!reFind("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$",candidate)) return result;
    try {
      var instant = createObject("java","java.time.Instant").parse(candidate);
      if (compare(instant.toString(),candidate) NEQ 0) return result;
      result.VALID=true;
      result.SECONDS=instant.getEpochSecond();
    } catch (any invalidUtc) {
      return result;
    }
    return result;
  }

  private string function mapPolicyHold(required struct policyDecision) output=false {
    var reason = structKeyExists(arguments.policyDecision,"reason")
      ? uCase(trim(toString(arguments.policyDecision.reason))) : "";
    if (listFind("ACTIVITY_HISTORY_UNKNOWN,ACTIVITY_NOT_QUALIFYING,ACTIVITY_HISTORY_CONFLICT",reason)) {
      return "HOLD_INCOMPLETE_ACTIVITY_EVIDENCE";
    }
    if (listFind("INVALID_UTC_CLOCK,FUTURE_CLOCK,STAGE_HISTORY_CONFLICT,RECOVERY_HISTORY_CONFLICT",reason)) {
      return "HOLD_CONTRADICTORY_EVIDENCE";
    }
    return "HOLD_POLICY_" & left(reReplace(reason,"[^A-Z0-9_]","","all"),48);
  }

  private struct function baseResult(required numeric userId) output=false {
    return {
      MEMBER_ID=(arguments.userId GT 0 AND arguments.userId EQ fix(arguments.userId) ? fix(arguments.userId) : 0),
      CLASSIFICATION="UNCLASSIFIED",
      CURRENT_STAGE="",
      HIGHEST_VERIFIED_STAGE="",
      STAGE_ENTERED_UTC="",
      LATEST_QUALIFYING_ACTIVITY_UTC="",
      LATEST_RECOVERY_SENT_UTC="",
      LEDGER_STATE={HAS_ROW=false,STATUS="NONE",ATTEMPT_COUNT=0},
      POLICY_INPUT_SUMMARY={},
      POLICY_DECISION={},
      DECISION="HELD",
      DECISION_CODE="",
      ELIGIBLE=false,
      SUPPRESSION_REASONS=[],
      EVIDENCE_SUMMARY={}
    };
  }

  private struct function finish(
    required struct result,
    required string classification,
    required string code,
    required string decision
  ) output=false {
    arguments.result.CLASSIFICATION = arguments.classification;
    arguments.result.DECISION_CODE = arguments.code;
    arguments.result.DECISION = arguments.decision;
    arguments.result.ELIGIBLE = arguments.decision EQ "ELIGIBLE";
    arguments.result.SUPPRESSION_REASONS = arguments.result.ELIGIBLE ? [] : [arguments.code];
    return arguments.result;
  }
}
