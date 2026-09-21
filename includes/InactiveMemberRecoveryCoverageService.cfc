component output="false" {
  variables.datasource="fpw";
  variables.events="";

  public any function init(string datasource="fpw", any eventService="") output=false {
    variables.datasource=arguments.datasource;
    variables.events=isObject(arguments.eventService) ? arguments.eventService
      : new ProductEventService(datasource=variables.datasource);
    return this;
  }

  // Signup-only command, inside the transaction that INSERTED this new user.
  // Never an enrollment command or a way to attest historical/legacy accounts.
  public void function recordSignupInCurrentTransaction(required numeric userId, required struct signupMetadata) output=false {
    var member=queryExecute("SELECT userId FROM users WHERE userId=:id FOR UPDATE",params(arguments.userId),{datasource=variables.datasource});
    var history=queryExecute("SELECT COUNT(*) AS n FROM product_events WHERE user_id=:id",params(arguments.userId),{datasource=variables.datasource});
    if (member.recordCount NEQ 1 OR val(history.n[1]) NEQ 0) fail();
    var binding=lCase(createUUID());
    requiredEvent(arguments.userId,"sign_up","user",arguments.userId,"member_signup",arguments.signupMetadata,
      "sign_up:user:" & arguments.userId,binding);
    requiredEvent(arguments.userId,"recovery_coverage_started","user",arguments.userId,"member_signup",{contract_version="v1"},
      "recovery_coverage_v1:user:" & arguments.userId,binding);
    if (!getCoverageVerification(arguments.userId).stage_history) fail();
  }

  // A separate read-only enrollment clock; signup does not enroll the member.
  public string function getEnrollmentUtc(required numeric userId) output=false {
    return new fpw.includes.InactiveMemberRecoveryEnrollmentService(datasource=variables.datasource).getEnrollmentUtc(arguments.userId);
  }

  public struct function getCoverageVerification(required numeric userId) output=false {
    var result={stage_history=false,activity_coverage=false,sharing_history=false,recovery_history=false};
    if (!validId(arguments.userId)) return result;
    var rows=queryExecute(
      "SELECT e.id,e.user_id,e.entity_id,e.entity_type,e.event_name,e.event_source,e.idempotency_key,
        e.request_correlation_id,e.metadata_json,e.occurred_at_utc,
        (e.occurred_at_utc>'1970-01-01' AND e.occurred_at_utc<=UTC_TIMESTAMP()
          AND e.occurred_at_utc=e.created_at_utc) AS valid_clock
       FROM product_events e JOIN users u ON u.userId=:id
       WHERE (e.user_id=:id AND e.event_name IN ('sign_up','recovery_coverage_started'))
          OR e.idempotency_key IN (:signupKey,:coverageKey)
       ORDER BY e.id",
      {id={value=arguments.userId,cfsqltype="cf_sql_integer"},
       signupKey={value="sign_up:user:" & arguments.userId,cfsqltype="cf_sql_varchar"},
       coverageKey={value="recovery_coverage_v1:user:" & arguments.userId,cfsqltype="cf_sql_varchar"}},
      {datasource=variables.datasource});
    if (rows.recordCount NEQ 2) return result;
    for (var i=1;i LTE 2;i++) {
      if (val(rows.user_id[i]) NEQ arguments.userId OR val(rows.entity_id[i]) NEQ arguments.userId
        OR compare(toString(rows.entity_type[i]),"user") OR compare(toString(rows.event_source[i]),"member_signup")
        OR !val(rows.valid_clock[i])) return result;
    }
    if (compare(toString(rows.event_name[1]),"sign_up") OR compare(toString(rows.event_name[2]),"recovery_coverage_started")
      OR compare(toString(rows.idempotency_key[1]),"sign_up:user:" & arguments.userId)
      OR compare(toString(rows.idempotency_key[2]),"recovery_coverage_v1:user:" & arguments.userId)
      OR !isValid("uuid",toString(rows.request_correlation_id[1]))
      OR compare(toString(rows.request_correlation_id[1]),toString(rows.request_correlation_id[2]))
      OR dateCompare(rows.occurred_at_utc[1],rows.occurred_at_utc[2]) GT 0) return result;
    try {
      var metadata=deserializeJSON(toString(rows.metadata_json[2]));
      if (!isStruct(metadata) OR structCount(metadata) NEQ 1 OR !structKeyExists(metadata,"contract_version")
        OR compare(toString(metadata.contract_version),"v1")) return result;
    } catch (any invalidMetadata) { return result; }
    var beforeBirth=queryExecute("SELECT COUNT(*) AS n FROM product_events WHERE user_id=:id AND (id<:birthId OR occurred_at_utc<:birthUtc)",
      {id={value=arguments.userId,cfsqltype="cf_sql_integer"},birthId={value=rows.id[1],cfsqltype="cf_sql_bigint"},
       birthUtc={value=rows.occurred_at_utc[1],cfsqltype="cf_sql_timestamp"}}, {datasource=variables.datasource});
    if (val(beforeBirth.n[1])) return result;
    // v1 attests collection from canonical signup forward, not the absence of activity.
    return {stage_history=true,activity_coverage=true,sharing_history=true,recovery_history=true};
  }

  // Call before entering any share transaction that may roll back after submission.
  // No request-supplied correlation token, metadata, timestamp, or identity is accepted.
  public string function beginShare(required numeric userId, required numeric floatPlanId, required string source) output=false {
    if (!validId(arguments.userId) OR !validId(arguments.floatPlanId)
      OR !listFind("basic_save_send,basic_review_send,premium_save_send",arguments.source)) fail();
    var token=lCase(createUUID());
    transaction isolation="read_committed" {
      var owned=queryExecute("SELECT fp.floatPlanId FROM users u JOIN floatplans fp ON TRIM(CAST(fp.userId AS CHAR))=CAST(u.userId AS CHAR)
        WHERE u.userId=:id AND fp.floatPlanId=:planId FOR UPDATE",
        {id={value=arguments.userId,cfsqltype="cf_sql_integer"},planId={value=arguments.floatPlanId,cfsqltype="cf_sql_integer"}},
        {datasource=variables.datasource});
      if (owned.recordCount NEQ 1) fail();
      requiredEvent(arguments.userId,"recovery_share_started","float_plan",arguments.floatPlanId,arguments.source,{},shareKey(token,"started"),token);
    }
    return token;
  }

  // The caller proves either accepted submission or that submission never began.
  // Unknown transport outcomes deliberately have no terminal event. Never retry here.
  public void function finishShare(required numeric userId, required string token, required string outcome) output=false {
    if (!validId(arguments.userId) OR !isValid("uuid",arguments.token) OR !listFind("succeeded,failed",arguments.outcome)) fail();
    transaction isolation="read_committed" {
      var started=queryExecute("SELECT entity_id,event_source FROM product_events
        WHERE user_id=:id AND event_name='recovery_share_started' AND entity_type='float_plan'
          AND request_correlation_id=:token AND idempotency_key=:eventKey FOR UPDATE",
        {id={value=arguments.userId,cfsqltype="cf_sql_integer"},token={value=arguments.token,cfsqltype="cf_sql_varchar"},
         eventKey={value=shareKey(arguments.token,"started"),cfsqltype="cf_sql_varchar"}}, {datasource=variables.datasource});
      if (started.recordCount NEQ 1) fail();
      var terminal=queryExecute("SELECT event_name FROM product_events WHERE request_correlation_id=:token
        AND event_name IN ('recovery_share_succeeded','recovery_share_failed')",
        {token={value=arguments.token,cfsqltype="cf_sql_varchar"}},{datasource=variables.datasource});
      if (terminal.recordCount) {
        if (terminal.recordCount NEQ 1 OR terminal.event_name[1] NEQ "recovery_share_" & arguments.outcome) fail();
      } else {
        requiredEvent(arguments.userId,"recovery_share_" & arguments.outcome,"float_plan",val(started.entity_id[1]),
          toString(started.event_source[1]),{},shareKey(arguments.token,arguments.outcome),arguments.token);
      }
    }
  }

  // Account-level retained evidence: no dependency on the continued existence of a trip/receipt.
  public struct function getShareEvidence(required numeric userId) output=false {
    var result={SUCCESSFUL=false,UNRESOLVED=false,INVALID=false,FAILED_COUNT=0};
    var rows=queryExecute("SELECT id,user_id,event_name,entity_type,entity_id,event_source,request_correlation_id,idempotency_key,metadata_json,occurred_at_utc,
      (occurred_at_utc>'1970-01-01' AND occurred_at_utc<=UTC_TIMESTAMP() AND occurred_at_utc=created_at_utc) AS valid_clock
      FROM product_events WHERE user_id=:id AND event_name IN ('recovery_share_started','recovery_share_succeeded','recovery_share_failed') ORDER BY id",
      params(arguments.userId),{datasource=variables.datasource});
    var groups={};
    for (var i=1;i LTE rows.recordCount;i++) {
      var token=toString(rows.request_correlation_id[i]);
      var state=listLast(toString(rows.event_name[i]),"_");
      var valid=isValid("uuid",token) AND val(rows.entity_id[i]) GT 0 AND rows.entity_type[i] EQ "float_plan"
        AND listFind("basic_save_send,basic_review_send,premium_save_send",toString(rows.event_source[i]))
        AND compare(toString(rows.idempotency_key[i]),shareKey(token,state)) EQ 0 AND val(rows.valid_clock[i]);
      try { var meta=deserializeJSON(toString(rows.metadata_json[i])); valid=valid AND isStruct(meta) AND structIsEmpty(meta); }
      catch (any badMetadata) { valid=false; }
      if (!valid) { result.INVALID=true; continue; }
      if (!structKeyExists(groups,token)) groups[token]={};
      if (structKeyExists(groups[token],state)) { result.INVALID=true; continue; }
      groups[token][state]={planId=val(rows.entity_id[i]),source=toString(rows.event_source[i]),id=val(rows.id[i]),at=rows.occurred_at_utc[i]};
    }
    for (var token in groups) {
      var group=groups[token];
      if (!structKeyExists(group,"started") OR (structKeyExists(group,"succeeded") AND structKeyExists(group,"failed"))) {
        result.INVALID=true; continue;
      }
      var endState=structKeyExists(group,"succeeded") ? "succeeded" : (structKeyExists(group,"failed") ? "failed" : "");
      if (!len(endState)) { result.UNRESOLVED=true; continue; }
      var start=group.started; var end=group[endState];
      if (start.planId NEQ end.planId OR compare(start.source,end.source) OR start.id GTE end.id OR dateCompare(start.at,end.at) GT 0) {
        result.INVALID=true; continue;
      }
      if (endState EQ "succeeded") result.SUCCESSFUL=true; else result.FAILED_COUNT++;
    }
    return result;
  }

  private void function requiredEvent(required numeric userId,required string name,required string entityType,required numeric entityId,
    required string source,required struct metadata,required string key,required string binding) output=false {
    var recorded=variables.events.recordEvent(userId=arguments.userId,eventName=arguments.name,entityType=arguments.entityType,
      entityId=arguments.entityId,eventSource=arguments.source,metadata=arguments.metadata,idempotencyKey=arguments.key,requestCorrelationId=arguments.binding);
    if (!recorded.SUCCESS OR !recorded.RECORDED) fail();
  }
  private struct function params(required numeric id) { return {id={value=arguments.id,cfsqltype="cf_sql_integer"}}; }
  private string function shareKey(required string token,required string state) { return "recovery_share:" & arguments.token & ":" & arguments.state; }
  private boolean function validId(required numeric id) { return arguments.id GT 0 AND arguments.id EQ fix(arguments.id); }
  private void function fail() { throw(type="FPW.Recovery.EvidenceFailed",message="Required recovery evidence could not be persisted or verified."); }
}
