component output=false {
  variables.datasource="fpw";
  public any function init(string datasource="fpw") { variables.datasource=arguments.datasource; return this; }

  public numeric function beginRun(required string executionSource,required boolean dryRun,struct settings={}) {
    var inserted={};
    var revision=val(arguments.settings.revision ?: 0);
    var snapshot={};
    for(var key in ["revision","firstDelayHours","stageIntervalHours","attributionWindowHours"])
      if(structKeyExists(arguments.settings,key)) snapshot[key]=arguments.settings[key];
    queryExecute("INSERT INTO inactive_member_recovery_runs
      (run_uuid,execution_source,dry_run,started_at_utc,status,settings_revision,settings_json)
      VALUES (:uuid,:source,:dry,UTC_TIMESTAMP(),'RUNNING',:revision,:settings)",
      {uuid=p(lCase(createUUID())),source=p(left(reReplace(arguments.executionSource,"[^A-Za-z0-9_-]","","all"),32)),
       dry=p(arguments.dryRun ? 1 : 0,"integer"),revision=p(revision,"integer"),settings=p(serializeJSON(snapshot),"longvarchar")},
      {datasource=variables.datasource,result="inserted"});
    return val(inserted.generatedKey);
  }

  public void function finishRun(required numeric runId,required struct result) {
    var observed=queryExecute("SELECT COUNT(*) recorded_count,SUM(initial_decision='DEFERRED') waiting_count,
      SUM(finalized_at_utc IS NULL) incomplete_count FROM inactive_member_recovery_evaluations WHERE run_id=:id",
      {id=p(arguments.runId,"bigint")},{datasource=variables.datasource});
    var gaps=val(arguments.result.observation_gaps ?: 0) GT 0
      OR val(observed.recorded_count[1]) NEQ val(arguments.result.scanned ?: 0) OR val(observed.incomplete_count[1]) GT 0;
    var params={id=p(arguments.runId,"bigint"),
      status=p(!(arguments.result.ok ?: false) ? "FAILED" : (gaps ? "COMPLETED_WITH_GAPS" : "COMPLETED")),
      error=p(code(arguments.result.error ?: (gaps ? "OBSERVATION_GAPS" : "")))};
    var mapping={evaluated_count="scanned",eligible_count="eligible",accepted_count="sent",failed_count="failed",
      held_count="held",waiting_count="skipped",suppressed_count="suppressed",attempted_count="claimed"};
    var assignments=[];
    for(var key in mapping) {
      params[key]=p(key EQ "waiting_count" ? val(observed.waiting_count[1]) : val(arguments.result[mapping[key]] ?: 0),"integer");
      arrayAppend(assignments,key & "=:" & key);
    }
    queryExecute("UPDATE inactive_member_recovery_runs SET completed_at_utc=UTC_TIMESTAMP(),status=:status,error_code=:error,"
      & arrayToList(assignments,",") & " WHERE id=:id AND status='RUNNING'",params,{datasource=variables.datasource});
  }

  public numeric function recordEvaluation(required numeric runId,required numeric userId,required struct evaluation) {
    var e=arguments.evaluation;
    var policy=isStruct(e.POLICY_DECISION ?: "") ? e.POLICY_DECISION : {};
    var path=toString(e.DESTINATION_PATH ?: e.DESTINATION_URL ?: "");
    if(!len(path) AND listFind("A,B,C,D",e.CURRENT_STAGE ?: ""))
      path=new fpw.includes.InactiveMemberRecoveryDestinationService().init(variables.datasource).resolveStage(arguments.userId,e.CURRENT_STAGE);
    var destination=destinationFields(path);
    var context={};
    // Stable, deliberately bounded context. Never persist email/compliance tokens or raw exceptions.
    for(var key in ["CURRENT_STAGE","DECISION","DECISION_CODE","CONTACT_NUMBER","CONTACT_TOTAL","ENROLLMENT_EVENT_ID",
      "TIMING_REVISION","ENROLLED_AT_UTC","EFFECTIVE_START_UTC","STAGE_ENTERED_AT_UTC","LATEST_ACTIVITY_AT_UTC",
      "STAGE_ENTERED_UTC","LATEST_QUALIFYING_ACTIVITY_UTC","LATEST_RECOVERY_SENT_UTC","RECOVERY_START_UTC","RECOVERY_STATE_REVISION"])
      if(structKeyExists(e,key) AND isSimpleValue(e[key])) context[key]=e[key];
    context.policy={};
    for(var key in ["DECISION","REASON","REASON_CODE","ELIGIBLE_AT_UTC","CLOCK_START_UTC","NOW_UTC","CONTACT_NUMBER",
      "INTERVAL_SECONDS","FIRST_DELAY_SECONDS","LAST_RECOVERY_SENT_AT_UTC","ANCHOR_UTC","SECONDS_UNTIL_ELIGIBLE"])
      if(structKeyExists(policy,key) AND isSimpleValue(policy[key])) context.policy[key]=policy[key];
    context.policyInput={};
    if(isStruct(e.POLICY_INPUT_SUMMARY ?: "")) for(var key in e.POLICY_INPUT_SUMMARY)
      if(isSimpleValue(e.POLICY_INPUT_SUMMARY[key])) context.policyInput[key]=e.POLICY_INPUT_SUMMARY[key];
    context.settings={};
    if(isStruct(e.TIMING_SETTINGS ?: "")) for(var key in ["revision","firstDelayHours","stageIntervalHours","attributionWindowHours"])
      if(structKeyExists(e.TIMING_SETTINGS,key)) context.settings[key]=e.TIMING_SETTINGS[key];
    var inserted={};
    var stage=listFind("A,B,C,D",e.CURRENT_STAGE ?: "") ? e.CURRENT_STAGE : "";
    var contact=val(e.CONTACT_NUMBER ?: 0);
    var template=contact GTE 1 AND contact LTE 3 AND len(stage) ? "recovery.contact_" & contact & ".destination_" & stage & ".v1" : "";
    queryExecute("INSERT INTO inactive_member_recovery_evaluations
      (run_id,user_id,recovery_enrollment_event_id,contact_number,contact_total,destination_stage,destination_type,destination_id,
       template_id,template_version,transport_attempt_number,initial_decision,initial_reason,initial_eligible,evaluated_at_utc,
       eligible_at_utc,context_json)
      VALUES (:run,:user,:enrollment,:contact,3,:stage,:destinationType,:destinationId,:template,'v1',:attempt,
       :decision,:reason,:eligible,UTC_TIMESTAMP(),CAST(:eligibleAt AS DATETIME),:context)",
      {run=p(arguments.runId,"bigint"),user=p(arguments.userId,"integer"),enrollment=nullableNumber(e.ENROLLMENT_EVENT_ID ?: 0),
       contact=nullableNumber(contact),stage=p(stage),destinationType=p(destination.type),destinationId=nullableNumber(destination.id),
       template=p(template),attempt=p(val(e.TRANSPORT_ATTEMPT_NUMBER ?: (isStruct(e.LEDGER_STATE ?: "") ? e.LEDGER_STATE.ATTEMPT_COUNT ?: 0 : 0)),"integer"),
       decision=p(code(e.DECISION ?: "HELD")),reason=p(code(e.DECISION_CODE ?: "EVALUATION_FAILED")),
       eligible=p((e.ELIGIBLE ?: false) ? 1 : 0,"integer"),eligibleAt=utcParam(policy.ELIGIBLE_AT_UTC ?: e.ELIGIBLE_AT_UTC ?: ""),
       context=p(serializeJSON(context),"longvarchar")},{datasource=variables.datasource,result="inserted"});
    var id=val(inserted.generatedKey);
    event(arguments.userId,"recovery_evaluated","recovery_evaluation",id,"recovery_processor","recovery_evaluated:" & id);
    return id;
  }

  public void function finalizeEvaluation(required numeric evaluationId,required struct result) {
    var category=uCase(arguments.result.category ?: arguments.result.DECISION ?: "HELD");
    if(!len(category)) category=(arguments.result.eligible ?: false) ? "ELIGIBLE" : "HELD";
    queryExecute("UPDATE inactive_member_recovery_evaluations SET final_decision=:decision,final_reason=:reason,
      finalized_at_utc=UTC_TIMESTAMP(),message_id=COALESCE(:message,
        (SELECT m.id FROM inactive_member_recovery_messages m WHERE m.evaluation_id=:id ORDER BY m.id DESC LIMIT 1))
      WHERE id=:id AND finalized_at_utc IS NULL",
      {id=p(arguments.evaluationId,"bigint"),decision=p(code(category)),reason=p(code(arguments.result.code ?: arguments.result.DECISION_CODE ?: "EVALUATED")),
       message=nullableNumber(arguments.result.messageId ?: arguments.result.message_id ?: 0)},{datasource=variables.datasource});
  }

  // Atomic preparation lets the caller safely fall back to its original untracked message.
  public struct function prepareMessage(required struct context,required struct message) {
    var c=arguments.context;
    var prepared=duplicate(arguments.message);
    var kind=uCase(c.messageKind ?: "AUTOMATED");
    var contact=val(c.contactNumber ?: 0);
    var stage=toString(c.destinationStage ?: "");
    if(!listFind("AUTOMATED,PERSONAL",kind) OR val(c.userId ?: 0) LTE 0
      OR (kind EQ "AUTOMATED" AND (contact LT 1 OR contact GT 3 OR !listFind("A,B,C,D",stage))))
      throw(type="FPW.Recovery.InvalidMessageContext",message="INVALID_MESSAGE_CONTEXT");
    if(kind EQ "PERSONAL" AND (val(c.administratorId ?: 0) LTE 0 OR !reFind("^[A-Za-z0-9_-]{16,100}$",c.submissionIdentity ?: "")))
      throw(type="FPW.Recovery.InvalidMessageContext",message="PERSONAL_SUBMISSION_IDENTITY_REQUIRED");
    if(kind EQ "AUTOMATED") {
      var enrollment=queryExecute("SELECT id FROM product_events WHERE id=:event AND user_id=:user
        AND event_name='inactive_member_recovery_enrolled' AND event_source='recovery_enrollment'
        AND entity_type='user' AND entity_id=user_id",
        {event=p(val(c.enrollmentEventId ?: 0),"bigint"),user=p(c.userId,"integer")},{datasource=variables.datasource});
      if(enrollment.recordCount NEQ 1) throw(type="FPW.Recovery.InvalidMessageContext",message="ENROLLMENT_OWNERSHIP_REQUIRED");
    }
    var hours=0;
    var publicId="";
    var secret="";
    var links={};
    if(kind EQ "AUTOMATED") {
      var settings=isStruct(c.settings ?: "") ? c.settings : new fpw.includes.InactiveMemberRecoverySettingsService().init(variables.datasource).getSettings();
      hours=val(settings.attributionWindowHours ?: 0);
      if(hours LT 1 OR hours GT 720 OR hours NEQ fix(hours)) throw(type="FPW.Recovery.InvalidSettings",message="ATTRIBUTION_SETTINGS_REQUIRED");
      publicId=randomHex(); secret=randomHex();
      links=new fpw.includes.InactiveMemberRecoveryTrackingService().init(variables.datasource).decorate(prepared,publicId,secret);
      prepared=links.message;
    }
    var destination=destinationFields(c.destinationPath ?: prepared.destinationUrl ?: "");
    var inserted={};
    var template=toString(c.templateId ?: prepared.templateId ?: (kind EQ "PERSONAL" ? "recovery.personal.v1" : "recovery.contact_" & contact & ".destination_" & stage & ".v1"));
    transaction {
      queryExecute("INSERT INTO inactive_member_recovery_messages
        (run_id,evaluation_id,delivery_id,user_id,recovery_enrollment_event_id,message_kind,contact_number,contact_total,
         destination_stage,destination_type,destination_id,destination_path,template_id,template_version,transport_attempt_number,
         administrator_id,submission_identity,subject,recipient,text_body,html_body,cta_label,status,prepared_at_utc,
         attribution_window_hours,public_id,signing_secret)
        VALUES (:run,:evaluation,:delivery,:user,:enrollment,:kind,:contact,3,:stage,:destinationType,:destinationId,:path,
         :template,'v1',:attempt,:admin,:submission,:subject,:recipient,:textBody,:htmlBody,:cta,'PREPARED',UTC_TIMESTAMP(),
         :hours,:publicId,:secret)",
        {run=nullableNumber(c.runId ?: 0),evaluation=nullableNumber(c.evaluationId ?: 0),delivery=nullableNumber(c.deliveryId ?: 0),
         user=p(c.userId,"integer"),enrollment=nullableNumber(c.enrollmentEventId ?: 0),kind=p(kind),contact=nullableNumber(contact),
         stage=p(stage),destinationType=p(destination.type),destinationId=nullableNumber(destination.id),path=p(destination.path),
         template=p(template),attempt=p(val(c.transportAttemptNumber ?: 1),"integer"),admin=nullableNumber(c.administratorId ?: 0),
         submission=p(c.submissionIdentity ?: "","varchar",!len(c.submissionIdentity ?: "")),
         subject=p(prepared.subject),recipient=p(prepared.toEmail ?: c.toEmail ?: ""),textBody=p(prepared.textBody,"longvarchar"),
         htmlBody=p(prepared.htmlBody,"longvarchar"),cta=p(prepared.ctaLabel ?: ""),hours=nullableNumber(hours),
         publicId=p(publicId,"varchar",!len(publicId)),secret=p(secret,"varchar",!len(secret))},
        {datasource=variables.datasource,result="inserted"});
    }
    return {messageId=val(inserted.generatedKey),message=prepared,openUrl=links.openUrl ?: "",clickUrl=links.clickUrl ?: ""};
  }

  public void function finalizeMessage(required numeric messageId,required string status,string acceptedAtUtc="") {
    if(!listFind("SEND_ACCEPTED,SEND_FAILED,OUTCOME_UNKNOWN,CANCELED",arguments.status))
      throw(type="FPW.Recovery.InvalidMessageStatus",message="INVALID_MESSAGE_STATUS");
    var accepted=arguments.status EQ "SEND_ACCEPTED";
    var at=utcParam(arguments.acceptedAtUtc);
    if(accepted AND at.null) {
      var clock=queryExecute("SELECT DATE_FORMAT(UTC_TIMESTAMP(),'%Y-%m-%dT%H:%i:%sZ') AS at_utc",{}, {datasource=variables.datasource});
      at=utcParam(clock.at_utc[1]);
    }
    transaction {
      queryExecute("UPDATE inactive_member_recovery_messages SET status=:status,finalized_at_utc=UTC_TIMESTAMP(),
        accepted_at_utc=CASE WHEN :accepted=1 THEN CAST(:acceptedAt AS DATETIME) ELSE NULL END,
        attribution_deadline_utc=CASE WHEN :accepted=1 AND message_kind='AUTOMATED'
          THEN DATE_ADD(CAST(:acceptedAt AS DATETIME),INTERVAL attribution_window_hours HOUR) ELSE NULL END
        WHERE id=:id AND status='PREPARED'",
        {status=p(arguments.status),accepted=p(accepted ? 1 : 0,"integer"),acceptedAt=at,id=p(arguments.messageId,"bigint")},
        {datasource=variables.datasource});
      var row=queryExecute("SELECT user_id,status FROM inactive_member_recovery_messages WHERE id=:id",
        {id=p(arguments.messageId,"bigint")},{datasource=variables.datasource});
      if(row.recordCount AND row.status[1] EQ arguments.status)
        event(row.user_id[1],"recovery_message_" & lCase(arguments.status),"recovery_message",arguments.messageId,"recovery_processor",
          "recovery_message:" & arguments.messageId & ":" & lCase(arguments.status));
    }
  }

  public struct function safePreview(required numeric messageId) {
    var row=queryExecute("SELECT id,subject,text_body,html_body,cta_label,contact_number,destination_stage,template_id,template_version,status,recipient
      FROM inactive_member_recovery_messages WHERE id=:id",{id=p(arguments.messageId,"bigint")},{datasource=variables.datasource});
    if(!row.recordCount) return {};
    var body=redactKnownTokens(toString(row.html_body[1]),toString(row.text_body[1]));
    var textBody=redactKnownTokens(toString(row.text_body[1]),toString(row.text_body[1]));
    body=reReplaceNoCase(body,"<(img|script|iframe|object|embed|link|style)\b[^>]*>([\s\S]*?</(script|iframe|object|style)>)?","","all");
    body=reReplaceNoCase(body,"\s(href|src|srcset|background|action)\s*=\s*(""[^""]*""|'[^']*'|[^\s>]+)"," href=""##""","all");
    body=reReplaceNoCase(body,"\sstyle\s*=\s*(""[^""]*""|'[^']*')","","all");
    return {messageId=val(row.id[1]),subject=redact(row.subject[1]),textBody=redact(textBody),htmlBody=redact(body),
      ctaLabel=toString(row.cta_label[1]),contactNumber=val(row.contact_number[1]),destinationStage=toString(row.destination_stage[1]),
      templateId=toString(row.template_id[1]),templateVersion=toString(row.template_version[1]),status=toString(row.status[1]),recipient=toString(row.recipient[1])};
  }

  private string function redactKnownTokens(required string value,required string plainText) {
    var result=arguments.value;
    var matches=reMatchNoCase("[?&](t|token|fpw_return|authIntent|unsubscribeToken)=[^\s<>&""']+",arguments.plainText);
    for(var match in matches) {
      var bearer=mid(match,find("=",match)+1,len(match));
      for(var variant in [bearer,encodeForHtml(bearer),encodeForHtmlAttribute(bearer),urlEncodedFormat(bearer)])
        if(len(variant)) result=replace(result,variant,"[redacted]","all");
    }
    return result;
  }
  private string function redact(required string value) {
    return reReplaceNoCase(arguments.value,"([?&](amp;)?(t|token|fpw_return|authIntent|unsubscribeToken)=)[^\s<>&""']+","\1[redacted]","all");
  }
  private struct function destinationFields(required string path) {
    var candidatePath=arguments.path;
    var at=find("/app/dashboard.cfm?",candidatePath);
    if(at GT 0) candidatePath=mid(candidatePath,at,len(candidatePath));
    var safe=new fpw.includes.InactiveMemberRecoveryActionPathService().validatePath(candidatePath);
    var result={path=safe,type="",id=0};
    if(!len(safe)) return result;
    for(var pair in listToArray(listRest(safe,"?"),"&")) {
      var key=listFirst(pair,"=");
      var value=listRest(pair,"=");
      if(key EQ "recoveryAction") result.type=value;
      else if(listFind("routeId,routeInstanceId,floatPlanId",key)) result.id=val(value);
    }
    return result;
  }
  private void function event(required numeric userId,required string name,required string entityType,required numeric entityId,required string source,required string key) {
    try {new fpw.includes.ProductEventService().init(variables.datasource).recordEvent(arguments.userId,arguments.name,
      arguments.entityType,arguments.entityId,arguments.source,{},arguments.key);} catch(any ignored) {}
  }
  private string function randomHex() {return lCase(binaryEncode(binaryDecode(generateSecretKey("AES",256),"base64"),"hex"));}
  private string function code(required any value) {
    var result=isSimpleValue(arguments.value) ? uCase(trim(toString(arguments.value))) : "";
    return reFind("^[A-Z][A-Z0-9_]{0,79}$",result) ? result : "";
  }
  private struct function p(required any value,string type="varchar",boolean nullValue=false) {
    return {value=arguments.value,cfsqltype="cf_sql_" & arguments.type,null=arguments.nullValue};
  }
  private struct function nullableNumber(required any value) {return p(val(arguments.value),"bigint",val(arguments.value) LTE 0);}
  private struct function utcParam(required any value) {
    var utcValue=isSimpleValue(arguments.value) ? toString(arguments.value) : "";
    var valid=reFind("^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$",utcValue) EQ 1;
    return p(valid ? replace(replace(utcValue,"T"," "),"Z","") : "","varchar",!valid);
  }
}
