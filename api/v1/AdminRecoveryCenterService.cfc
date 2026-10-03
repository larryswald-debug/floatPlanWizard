component output=false {
 variables.datasource="fpw";
 public any function init(string datasource="fpw",any emailService="") {
  variables.datasource=arguments.datasource;
  variables.settings=new fpw.includes.InactiveMemberRecoverySettingsService(datasource=variables.datasource);
  variables.state=new fpw.includes.InactiveMemberRecoveryStateService(datasource=variables.datasource);
  variables.enrollment=new fpw.includes.InactiveMemberRecoveryEnrollmentService(datasource=variables.datasource);
  variables.classifier=new fpw.includes.InactiveMemberRecoveryClassifierService(datasource=variables.datasource);
  variables.ledger=new fpw.includes.InactiveMemberRecoveryLedgerService(datasource=variables.datasource);
  variables.authorization=new fpw.api.v1.AdminAuthorizationService().init(variables.datasource);
  variables.auditService=new fpw.api.v1.AdminAuditService().init(variables.datasource);
  variables.email=isObject(arguments.emailService) ? arguments.emailService : new fpw.api.v1.email();
  variables.observation=new fpw.includes.InactiveMemberRecoveryObservabilityService(datasource=variables.datasource);
  return this;
 }
 public struct function execute(required string action,struct values={}) {
  var writes="pause,resume,exclude,remove_exclusion,refresh,settingsPreview,settingsSave,resetPreview,resetCommit,personalPreview,personalSend";
  var admin=requireAdmin(listFindNoCase(writes,arguments.action) ? "POST":"GET");
  switch(arguments.action) {
   case "settings": return settingsView(arguments.values);
   case "dashboard": return dashboard();
   case "queue": case "members": return listMembers(arguments.values);
   case "member": return memberDetail(idValue(arguments.values,"userId"),arguments.values);
   case "runs": return runs(arguments.values);
   case "performance": return performance(arguments.values);
   case "preview": return preview(arguments.values);
   case "pause": case "resume": case "exclude": case "remove_exclusion":
    return changeState(idValue(arguments.values,"userId"),arguments.action,admin.userId);
   case "refresh": return refresh(idValue(arguments.values,"userId"));
   case "settingsPreview":
    var proposed=variables.settings.validate(arguments.values);
    var impact=previewImpact(proposed);
    return {reviewToken=remember("settings",admin.userId,{proposed=proposed,fingerprint=impact.fingerprint}),impact=impact,settings=proposed};
   case "settingsSave": return saveSettings(consume("settings",admin.userId,arguments.values),admin.userId);
   case "resetPreview":
    var cohort=resetCohort(); return {count=arrayLen(cohort),reviewToken=remember("reset",admin.userId,{fingerprint=hash(serializeJSON(cohort),"SHA-256")})};
   case "resetCommit": return resetStart(consume("reset",admin.userId,arguments.values),admin.userId);
   case "personalPreview":
    var personal=personalPreparation(idValue(arguments.values,"userId"),textValue(arguments.values,"subject"),textValue(arguments.values,"body"));
    return {preview=redact(personal.message),reviewToken=remember("personal",admin.userId,personal)};
   case "personalSend": return personalSend(consume("personal",admin.userId,arguments.values),admin.userId);
   default: throw(type="FPW.Recovery.Admin",message="INVALID_ACTION");
  }
 }
 private struct function requireAdmin(required string method) {
  var admin=variables.authorization.authorizeCurrentSession(structKeyExists(session,"user") AND isStruct(session.user) ? session.user:{});
  if(!admin.authorized) throw(type="FPW.Recovery.Admin",message="ADMIN_REQUIRED");
  if(compareNoCase(cgi.request_method,arguments.method) NEQ 0) throw(type="FPW.Recovery.Admin",message="METHOD_NOT_ALLOWED");
  if(arguments.method EQ "POST" AND !variables.authorization.isValidCsrfToken(variables.authorization.resolveRequestCsrfToken()))
   throw(type="FPW.Recovery.Admin",message="CSRF_INVALID");
  return admin;
 }
 private string function clockUtc() {
  return queryExecute("SELECT DATE_FORMAT(UTC_TIMESTAMP(),'%Y-%m-%dT%H:%i:%sZ') t",{}, {datasource=variables.datasource}).t[1];
 }
 private array function cohortIds() {
  var ids=[]; var q=queryExecute("SELECT DISTINCT e.user_id FROM product_events e JOIN users u ON u.userId=e.user_id
   WHERE e.event_name='inactive_member_recovery_enrolled' ORDER BY e.user_id",{}, {datasource=variables.datasource});
  for(var r in q) arrayAppend(ids,val(r.user_id)); return ids;
 }
 private struct function evaluateRecovery(required numeric userId,struct timing={}) {
  var e=variables.classifier.evaluateMember(userId=arguments.userId,nowUtc=clockUtc(),timingSettings=arguments.timing);
  if(e.DECISION_CODE EQ "HOLD_RETRY_DECISION_REQUIRED") {
   var s=variables.ledger.getContactState(arguments.userId,e.ENROLLMENT_EVENT_ID,e.CONTACT_NUMBER);
   if(s.SUCCESS AND s.CAN_RETRY) e=variables.classifier.evaluateMember(userId=arguments.userId,nowUtc=clockUtc(),timingSettings=arguments.timing,evaluateFailedRetry=true);
  } return e;
 }
 private struct function memberRow(required numeric userId) {
  var q=queryExecute("SELECT userId,email,fName FROM users WHERE userId=:id",{id=p(arguments.userId,"integer")},{datasource=variables.datasource});
  if(!q.recordCount) throw(type="FPW.Recovery.Admin",message="MEMBER_NOT_FOUND");
  var e=evaluateRecovery(arguments.userId);
  var state={paused="Unknown",excluded="Unknown",enrollmentEventId=0,recoveryStartUtc="",revision=0,verified=false};
  var sequence={SUCCESS=false,NEXT_CONTACT_NUMBER=0,COMPLETED=false};
  try {state=variables.state.getState(arguments.userId);state.verified=true;} catch(any invalidState) {}
  try {sequence=variables.ledger.getSequenceState(arguments.userId);} catch(any invalidSequence) {}
  var last=queryExecute("SELECT contact_number,destination_stage FROM inactive_member_recovery_deliveries WHERE user_id=:id AND status='SENT' ORDER BY contact_number DESC LIMIT 1",{id=p(arguments.userId,"integer")},{datasource=variables.datasource});
  var signals=queryExecute("SELECT SUM(returned_at_utc IS NOT NULL) returned_count,SUM(engaged_at_utc IS NOT NULL) engaged_count,
   SUM((status IN('SEND_FAILED','OUTCOME_UNKNOWN') AND NOT EXISTS(
    SELECT 1 FROM inactive_member_recovery_deliveries d WHERE d.user_id=m.user_id
     AND d.recovery_enrollment_event_id=m.recovery_enrollment_event_id AND d.contact_number=m.contact_number AND d.status='SENT'))
    OR (status='PREPARED' AND prepared_at_utc < DATE_SUB(UTC_TIMESTAMP(),INTERVAL 10 MINUTE))
    OR (status='SEND_ACCEPTED' AND attribution_deadline_utc<=UTC_TIMESTAMP() AND engaged_at_utc IS NULL
      AND NOT EXISTS (SELECT 1 FROM inactive_member_recovery_messages newer WHERE newer.user_id=m.user_id AND newer.message_kind='AUTOMATED'
       AND newer.status='SEND_ACCEPTED' AND (newer.accepted_at_utc>m.accepted_at_utc OR (newer.accepted_at_utc=m.accepted_at_utc AND newer.id>m.id))))) attention_count
   FROM inactive_member_recovery_messages m WHERE user_id=:id AND message_kind='AUTOMATED'",{id=p(arguments.userId,"integer")},{datasource=variables.datasource});
  var labels={A="Add Vessel",B="Trip Planner",C="Saved/Planned Route",D="Draft Editor"};
  return {evaluatedAtUtc=clockUtc(),userId=arguments.userId,email=toString(q.email[1]),firstName=toString(q.fName[1]),
   enrollmentEventId=state.enrollmentEventId,recoveryStartUtc=state.recoveryStartUtc,
   contactNumber=sequence.SUCCESS ? sequence.NEXT_CONTACT_NUMBER : e.CONTACT_NUMBER,contactTotal=3,
   destinationStage=e.CURRENT_STAGE,destinationLabel=structKeyExists(labels,e.CURRENT_STAGE) ? labels[e.CURRENT_STAGE]:"Unclassified",
   decision=e.DECISION,reason=e.DECISION_CODE,eligibleAtUtc=structKeyExists(e.POLICY_DECISION,"eligible_at_utc") ? e.POLICY_DECISION.eligible_at_utc:"",
   stateVerified=state.verified,paused=state.paused,excluded=state.excluded,sequenceComplete=sequence.SUCCESS AND sequence.COMPLETED,
   lastAcceptedContact=last.recordCount ? val(last.contact_number[1]):0,lastAcceptedDestination=last.recordCount ? toString(last.destination_stage[1]):"",
   returned=val(signals.returned_count[1]) GT 0,engaged=val(signals.engaged_count[1]) GT 0,
   needsAttention=val(signals.attention_count[1]) GT 0 OR e.LEDGER_STATE.STATUS EQ "FAILED"};
 }
 private struct function listMembers(required struct values) {
  var rows=[]; var search=lCase(textValue(arguments.values,"search"));
  for(var id in cohortIds()) {
   var row=memberRow(id);
   if(len(search) AND !find(search,lCase(row.email & " " & row.firstName & " " & row.userId))) continue;
   if(len(textValue(arguments.values,"destinationStage")) AND compareNoCase(row.destinationStage,textValue(arguments.values,"destinationStage"))) continue;
   if(len(textValue(arguments.values,"contactNumber")) AND row.contactNumber NEQ val(textValue(arguments.values,"contactNumber"))) continue;
   if(len(textValue(arguments.values,"decision")) AND compareNoCase(row.decision,textValue(arguments.values,"decision"))) continue;
   var status=lCase(textValue(arguments.values,"status"));
   if(status EQ "paused" AND (!isBoolean(row.paused) OR !row.paused) OR status EQ "excluded" AND (!isBoolean(row.excluded) OR !row.excluded) OR status EQ "complete" AND !row.sequenceComplete OR status EQ "attention" AND !row.needsAttention) continue;
   arrayAppend(rows,row);
  } return pageRows(rows,arguments.values);
 }
 private struct function memberDetail(required numeric userId,struct values={}) {
  var params={id=p(arguments.userId,"integer")};
  var historyWhere="user_id=:id AND (event_name LIKE 'recovery_%' OR event_name='inactive_member_recovery_enrolled' OR event_source IN('member_api','password_auth','basic_save_send','basic_review_send','premium_save_send'))";
  var historyPage=reportPage(queryExecute("SELECT COUNT(*) total FROM product_events WHERE " & historyWhere,params,{datasource=variables.datasource}).total[1],arguments.values,"historyPage");
  var historyParams=duplicate(params);historyParams.pageLimit=p(historyPage.pageSize,"integer");historyParams.pageOffset=p((historyPage.page-1)*historyPage.pageSize,"integer");
  var history=queryExecute("SELECT id eventId,event_name,event_source,DATE_FORMAT(occurred_at_utc,'%Y-%m-%dT%H:%i:%sZ') occurred_at_utc,metadata_json
   FROM product_events WHERE " & historyWhere & " ORDER BY occurred_at_utc DESC,id DESC LIMIT :pageLimit OFFSET :pageOffset",historyParams,{datasource=variables.datasource});
  var evaluations=evaluationRows("e.user_id=:id",params,arguments.values);
  var messages=messageRows("m.user_id=:id",params,arguments.values);
  return {member=memberRow(arguments.userId),evaluations=evaluations.rows,evaluationsPagination=evaluations.pagination,
   messages=messages.rows,messagesPagination=messages.pagination,history=rowsOf(history),historyPagination=historyPage};
 }
 private struct function settingsView(struct values={}) {
  var s=variables.settings.getSettings();
  var where="action IN ('recovery_settings_saved','recovery_start_reset')";
  var pagination=reportPage(queryExecute("SELECT COUNT(*) total FROM fpw_admin_audit_log WHERE " & where,{}, {datasource=variables.datasource}).total[1],arguments.values,"auditPage");
  s.audit=rowsOf(queryExecute("SELECT audit_id,admin_user_id,action,previous_values_json,new_values_json,DATE_FORMAT(created_at_utc,'%Y-%m-%dT%H:%i:%sZ') created_at_utc
   FROM fpw_admin_audit_log WHERE " & where & " ORDER BY audit_id DESC LIMIT :pageLimit OFFSET :pageOffset",
   {pageLimit=p(pagination.pageSize,"integer"),pageOffset=p((pagination.page-1)*pagination.pageSize,"integer")}, {datasource=variables.datasource}));
  s.auditPagination=pagination;return s;
 }
 private struct function dashboard() {
  var all=listMembers({pageSize=100000}).rows; var metrics={enrolled=arrayLen(all),eligible=0,waiting=0,held=0,paused=0,excluded=0,sequenceComplete=0,needsAttention=0};
  var attention=[];
  for(var row in all) {
   if(row.decision EQ "ELIGIBLE") metrics.eligible++; if(row.decision EQ "DEFERRED") metrics.waiting++; if(row.decision EQ "HELD") metrics.held++;
   if(isBoolean(row.paused) AND row.paused) metrics.paused++; if(isBoolean(row.excluded) AND row.excluded) metrics.excluded++; if(row.sequenceComplete) metrics.sequenceComplete++;
   if(row.needsAttention) {metrics.needsAttention++;if(arrayLen(attention) LT 10) arrayAppend(attention,row);}
  }
  var perf=performance({}); for(var key in ["accepted","opened","clicked","returned","engaged"]) metrics[key]=perf.summary[key];
  var recent=runs({pageSize=1});
  return {metrics=metrics,funnel=perf.summary,settings=variables.settings.getSettings(),lastRun=arrayLen(recent.rows) ? recent.rows[1]:{},attention=attention};
 }
 private struct function runs(required struct values) {
  var params={}; var where="1=1";
  if(val(textValue(arguments.values,"runId")) GT 0) {
   params.id=p(idValue(arguments.values,"runId"),"bigint"); where="id=:id";
  }
  var q=queryExecute("SELECT id runId,execution_source source,IF(dry_run=1,'Dry run','Processing') mode,
   CASE WHEN status='RUNNING' AND started_at_utc<DATE_SUB(UTC_TIMESTAMP(),INTERVAL 5 MINUTE) THEN 'INCOMPLETE' ELSE status END status,
   (SELECT COUNT(*) FROM inactive_member_recovery_messages m WHERE m.run_id=inactive_member_recovery_runs.id AND m.status='OUTCOME_UNKNOWN') AS unknown,
   DATE_FORMAT(started_at_utc,'%Y-%m-%dT%H:%i:%sZ') startedAtUtc,COALESCE(DATE_FORMAT(completed_at_utc,'%Y-%m-%dT%H:%i:%sZ'),'') finishedAtUtc,
   evaluated_count evaluated,eligible_count eligible,accepted_count accepted,failed_count failed,held_count held,waiting_count waiting,suppressed_count suppressed,attempted_count attempted,error_code errorCode
   FROM inactive_member_recovery_runs WHERE " & where & " ORDER BY id DESC",params,{datasource=variables.datasource});
  if(structKeyExists(params,"id")) {
   var evaluations=evaluationRows("e.run_id=:id",params,arguments.values);
   return {run=q.recordCount ? rowsOf(q)[1]:{},evaluations=evaluations.rows,evaluationsPagination=evaluations.pagination};
  }
  return pageRows(rowsOf(q),arguments.values);
 }
 private struct function evaluationRows(required string where,required struct params,struct values={}) {
  var pagination=reportPage(queryExecute("SELECT COUNT(*) total FROM inactive_member_recovery_evaluations e WHERE " & arguments.where,arguments.params,{datasource=variables.datasource}).total[1],arguments.values,"evaluationsPage");
  var boundedParams=duplicate(arguments.params);boundedParams.pageLimit=p(pagination.pageSize,"integer");boundedParams.pageOffset=p((pagination.page-1)*pagination.pageSize,"integer");
  return {pagination=pagination,rows=rowsOf(queryExecute("SELECT e.id evaluationId,e.run_id runId,e.user_id userId,e.recovery_enrollment_event_id enrollmentEventId,
   e.contact_number contactNumber,e.contact_total contactTotal,e.destination_stage destinationStage,e.destination_type destinationType,e.destination_id destinationId,
   e.template_id templateId,e.transport_attempt_number transportAttemptNumber,e.initial_decision initialDecision,e.initial_reason initialReason,
   e.final_decision finalDecision,e.final_reason finalReason,e.initial_eligible initialEligible,DATE_FORMAT(e.evaluated_at_utc,'%Y-%m-%dT%H:%i:%sZ') evaluatedAtUtc,e.context_json contextJson
   FROM inactive_member_recovery_evaluations e WHERE " & arguments.where & " ORDER BY e.id DESC LIMIT :pageLimit OFFSET :pageOffset",boundedParams,{datasource=variables.datasource}))};
 }
 private struct function messageRows(required string where,required struct params,struct values={}) {
  // Never select signing secrets or raw rendered bodies into list/report responses.
  var pagination=reportPage(queryExecute("SELECT COUNT(*) total FROM inactive_member_recovery_messages m WHERE " & arguments.where,arguments.params,{datasource=variables.datasource}).total[1],arguments.values,"messagesPage");
  var boundedParams=duplicate(arguments.params);boundedParams.pageLimit=p(pagination.pageSize,"integer");boundedParams.pageOffset=p((pagination.page-1)*pagination.pageSize,"integer");
  return {pagination=pagination,rows=rowsOf(queryExecute("SELECT m.id messageId,m.message_kind messageKind,m.contact_number contactNumber,m.contact_total contactTotal,
   m.destination_stage destinationStage,m.destination_type destinationType,m.destination_id destinationId,m.template_id templateId,m.template_version templateVersion,
   m.transport_attempt_number transportAttemptNumber,m.administrator_id administratorId,m.status,m.subject,
   DATE_FORMAT(m.prepared_at_utc,'%Y-%m-%dT%H:%i:%sZ') preparedAtUtc,DATE_FORMAT(m.accepted_at_utc,'%Y-%m-%dT%H:%i:%sZ') acceptedAtUtc,
   m.attribution_window_hours attributionWindowHours,DATE_FORMAT(m.attribution_deadline_utc,'%Y-%m-%dT%H:%i:%sZ') attributionDeadlineUtc,
   m.open_count openCount,m.click_count clickCount,m.late_open_count lateOpens,m.late_click_count lateClicks,
   DATE_FORMAT(m.returned_at_utc,'%Y-%m-%dT%H:%i:%sZ') returnedAtUtc,DATE_FORMAT(m.engaged_at_utc,'%Y-%m-%dT%H:%i:%sZ') engagedAtUtc
   FROM inactive_member_recovery_messages m WHERE " & arguments.where & " ORDER BY m.id DESC LIMIT :pageLimit OFFSET :pageOffset",boundedParams,{datasource=variables.datasource}))};
 }
 private struct function performance(required struct values) {
  var where="message_kind='AUTOMATED'"; var params={};
  var days=textValue(arguments.values,"days");
  if(len(days) AND days NEQ "0") {
   if(!listFind("0,7,30,90",days)) throw(type="FPW.Recovery.Admin",message="INVALID_PERIOD");
   where &= " AND accepted_at_utc>=DATE_SUB(UTC_TIMESTAMP(),INTERVAL :days DAY)";params.days=p(val(days),"integer");
  }
  for(var key in ["contactNumber","destinationStage","templateId"]) {
   var col=key EQ "contactNumber" ? "contact_number":(key EQ "destinationStage" ? "destination_stage":"template_id");
   if(len(textValue(arguments.values,key))) {where &= " AND " & col & "=:" & key; params[key]=p(textValue(arguments.values,key));}
  }
  for(var key in ["dateFrom","dateTo"]) {
   var value=textValue(arguments.values,key);
   if(len(value)) {if(!reFind("^[0-9]{4}-[0-9]{2}-[0-9]{2}$",value) OR !isDate(value)) throw(type="FPW.Recovery.Admin",message="INVALID_DATE");
    where &= key EQ "dateFrom" ? " AND accepted_at_utc>=:dateFrom":" AND accepted_at_utc<DATE_ADD(:dateTo,INTERVAL 1 DAY)";params[key]=p(value);}
  }
  var aggregate="COUNT(*) attempts,SUM(status='SEND_ACCEPTED') accepted,SUM(status='SEND_ACCEPTED' AND open_count>0) opened,
   SUM(status='SEND_ACCEPTED' AND click_count>0) clicked,SUM(status='SEND_ACCEPTED' AND returned_at_utc IS NOT NULL) returned,
   SUM(status='SEND_ACCEPTED' AND engaged_at_utc IS NOT NULL) engaged,SUM(late_open_count) lateOpens,SUM(late_click_count) lateClicks,
   SUM(open_count) openSignals,SUM(click_count) clickSignals,SUM(status='SEND_FAILED') failed,SUM(status='OUTCOME_UNKNOWN') unknown,
   SUM(status='SEND_ACCEPTED' AND public_id IS NULL) missingTracking";
  var q=queryExecute("SELECT contact_number contactNumber,destination_stage destinationStage,template_id templateId," & aggregate &
   " FROM inactive_member_recovery_messages WHERE " & where & " GROUP BY contact_number,destination_stage,template_id ORDER BY contact_number,destination_stage",params,{datasource=variables.datasource});
  var summary=rowsOf(queryExecute("SELECT " & aggregate & " FROM inactive_member_recovery_messages WHERE " & where,params,{datasource=variables.datasource}))[1];
  for(var key in summary) summary[key]=val(summary[key]);
  var ledgerCount=queryExecute("SELECT COUNT(*) n FROM inactive_member_recovery_deliveries d WHERE d.status='SENT'
   AND NOT EXISTS(SELECT 1 FROM inactive_member_recovery_messages m WHERE m.delivery_id=d.id AND m.status='SEND_ACCEPTED')",{}, {datasource=variables.datasource}).n[1];
  summary.untrackedAcceptedLedgerContacts=val(ledgerCount);
  var periodWhere="message_kind='AUTOMATED' AND status='SEND_ACCEPTED'";var periodParams={};
  for(var key in ["contactNumber","destinationStage","templateId"]) if(structKeyExists(params,key)) {
   var column=key EQ "contactNumber" ? "contact_number":(key EQ "destinationStage" ? "destination_stage":"template_id");
   periodWhere &= " AND " & column & "=:" & key;periodParams[key]=params[key];
  }
  var periodSql=[];
  for(var signal in ["opened","clicked","returned","engaged"]) {
   var column=signal EQ "opened" ? "first_open_at_utc":(signal EQ "clicked" ? "first_click_at_utc":signal & "_at_utc");
   var predicate=column & " IS NOT NULL";
   if(structKeyExists(params,"days")) {predicate &= " AND " & column & ">=DATE_SUB(UTC_TIMESTAMP(),INTERVAL :days DAY)";periodParams.days=params.days;}
   if(structKeyExists(params,"dateFrom")) {predicate &= " AND " & column & ">=:dateFrom";periodParams.dateFrom=params.dateFrom;}
   if(structKeyExists(params,"dateTo")) {predicate &= " AND " & column & "<DATE_ADD(:dateTo,INTERVAL 1 DAY)";periodParams.dateTo=params.dateTo;}
   arrayAppend(periodSql,"COALESCE(SUM(" & predicate & "),0) " & signal);
  }
  var period=rowsOf(queryExecute("SELECT " & arrayToList(periodSql) & " FROM inactive_member_recovery_messages WHERE " & periodWhere,periodParams,{datasource=variables.datasource}))[1];
  period.basis="Messages first observed open/click, or attributed return/engagement, in the selected period; independent counts.";
  return {rows=rowsOf(q),summary=summary,periodActivity=period};
 }
 private struct function preview(required struct values) {
  if(val(textValue(arguments.values,"messageId")) GT 0) return variables.observation.safePreview(idValue(arguments.values,"messageId"));
  var id=idValue(arguments.values,"userId"); var e=evaluateRecovery(id);
  if(!listFind("A,B,C,D",e.CURRENT_STAGE)) throw(type="FPW.Recovery.Admin",message="DESTINATION_UNAVAILABLE");
  var member=queryExecute("SELECT email,fName FROM users WHERE userId=:id",{id=p(id,"integer")},{datasource=variables.datasource});
  var contact=len(textValue(arguments.values,"contactNumber")) ? idValue(arguments.values,"contactNumber") : max(1,e.CONTACT_NUMBER);
  if(contact GT 3) throw(type="FPW.Recovery.Admin",message="INVALID_CONTACT");
  var eligible=variables.email.checkNonEssentialEmailEligibility(email=member.email[1],userId=id);
  var path=new fpw.includes.InactiveMemberRecoveryDestinationService(datasource=variables.datasource).resolveStage(id,e.CURRENT_STAGE);
  var message=variables.email.buildInactiveMemberRecoveryEmail(stage=e.CURRENT_STAGE,contactNumber=contact,eligibility=eligible,firstName=member.fName[1],
   verifiedRouteUrl=e.CURRENT_STAGE EQ "C" AND find("?recoveryAction=route&",path) ? path:"",
   verifiedDraftUrl=e.CURRENT_STAGE EQ "D" AND find("?recoveryAction=draft&",path) ? path:"");
  if(!message.success) throw(type="FPW.Recovery.Admin",message=message.errorCode);return redact(message);
 }
 private struct function refresh(required numeric userId) {
  var settings=variables.settings.getSettings(); var run=variables.observation.beginRun("admin_refresh",true,settings);
  var e=evaluateRecovery(arguments.userId);var evaluationId=variables.observation.recordEvaluation(run,arguments.userId,e);
  variables.observation.finalizeEvaluation(evaluationId,{category="refresh",code=e.DECISION_CODE});
  variables.observation.finishRun(run,{ok=true,scanned=1,eligible=e.ELIGIBLE ? 1:0,sent=0,failed=0,held=e.DECISION EQ "HELD" ? 1:0,suppressed=e.DECISION EQ "SUPPRESSED" ? 1:0});
  return memberDetail(arguments.userId);
 }
 private struct function changeState(required numeric userId,required string action,required numeric actor) {
  transaction isolation="read_committed" {
   lockMember(arguments.userId);
   var before=variables.state.getState(arguments.userId);
   if(!before.enrollmentEventId) throw(type="FPW.Recovery.Admin",message="ENROLLMENT_REQUIRED");
   var after=duplicate(before);
   if(arguments.action EQ "pause") after.paused=true; if(arguments.action EQ "resume") after.paused=false;
   if(arguments.action EQ "exclude") after.excluded=true; if(arguments.action EQ "remove_exclusion") after.excluded=false;
   queryExecute("INSERT INTO inactive_member_recovery_member_state(user_id,recovery_enrollment_event_id,paused,excluded,updated_at_utc,updated_by)
    VALUES(:id,:event,:paused,:excluded,UTC_TIMESTAMP(6),:actor)
    ON DUPLICATE KEY UPDATE paused=:paused,excluded=:excluded,revision=revision+1,updated_at_utc=UTC_TIMESTAMP(6),updated_by=:actor",
    {id=p(arguments.userId,"integer"),event=p(before.enrollmentEventId,"bigint"),paused=p(after.paused ? 1:0,"tinyint"),excluded=p(after.excluded ? 1:0,"tinyint"),actor=p(arguments.actor,"integer")},{datasource=variables.datasource});
   audit(arguments.actor,"recovery_" & arguments.action,"user",arguments.userId,before,after);
   var eventNames={pause="recovery_paused",resume="recovery_resumed",exclude="recovery_excluded",remove_exclusion="recovery_exclusion_removed"};
   stateEvent(arguments.userId,eventNames[arguments.action],createUUID(),uCase(replace(eventNames[arguments.action],"recovery_","")));
  } return memberDetail(arguments.userId);
 }
 private struct function previewImpact(required struct proposed) {
  var old=variables.settings.getSettings();var newer=duplicate(arguments.proposed);newer.revision=old.revision;
  var impact={affected=0,earlier=0,later=0,newlyImmediate=0,earliestEligibleAtUtc="",rows=[],revision=old.revision};
  for(var id in cohortIds()) {
   var prior=evaluateRecovery(id,old);var next=evaluateRecovery(id,newer);
   var before=structKeyExists(prior.POLICY_DECISION,"eligible_at_utc") ? prior.POLICY_DECISION.eligible_at_utc:"";
   var after=structKeyExists(next.POLICY_DECISION,"eligible_at_utc") ? next.POLICY_DECISION.eligible_at_utc:"";
   if(compare(before,after)) {impact.affected++;if(len(after) AND len(before)) {if(compare(after,before) LT 0) impact.earlier++;else impact.later++;}}
   if(!prior.ELIGIBLE AND next.ELIGIBLE) impact.newlyImmediate++;
   if(len(after) AND (!len(impact.earliestEligibleAtUtc) OR compare(after,impact.earliestEligibleAtUtc) LT 0)) impact.earliestEligibleAtUtc=after;
   arrayAppend(impact.rows,{userId=id,contactNumber=next.CONTACT_NUMBER,destinationStage=next.CURRENT_STAGE,before=before,after=after,priorDecision=prior.DECISION_CODE,nextDecision=next.DECISION_CODE});
  }
  impact.fingerprint=hash(serializeJSON({revision=old.revision,rows=impact.rows}),"SHA-256");return impact;
 }
 private struct function saveSettings(required struct review,required numeric actor) {
  transaction isolation="read_committed" {
   queryExecute("SELECT id FROM inactive_member_recovery_settings WHERE id=1 FOR UPDATE",{}, {datasource=variables.datasource});
   var before=variables.settings.getSettings();var impact=previewImpact(arguments.review.proposed);
   if(compare(impact.fingerprint,arguments.review.fingerprint)) throw(type="FPW.Recovery.Admin",message="IMPACT_CHANGED_REVIEW_AGAIN");
   var s=variables.settings.validate(arguments.review.proposed);
   queryExecute("UPDATE inactive_member_recovery_settings SET first_delay_hours=:first,stage_interval_hours=:spacing,attribution_window_hours=:window,
    revision=revision+1,updated_at_utc=UTC_TIMESTAMP(6),changed_by=:actor WHERE id=1",
    {first=p(s.firstDelayHours,"integer"),spacing=p(s.stageIntervalHours,"integer"),window=p(s.attributionWindowHours,"integer"),actor=p(arguments.actor,"integer")},{datasource=variables.datasource});
   audit(arguments.actor,"recovery_settings_saved","recovery_settings","1",before,variables.settings.getSettings());
  } return settingsView();
 }
 private array function resetCohort() {
  if(len(variables.settings.getSettings().resetAtUtc)) throw(type="FPW.Recovery.Admin",message="RESET_ALREADY_COMPLETED");
  if(queryExecute("SELECT COUNT(*) n FROM inactive_member_recovery_deliveries",{}, {datasource=variables.datasource}).n[1] GT 0)
   throw(type="FPW.Recovery.Admin",message="RESET_REQUIRES_EMPTY_LEDGER");
  var cohort=[]; for(var id in cohortIds()) {var e=variables.enrollment.getEnrollment(id);if(!e.EVENT_ID) throw(type="FPW.Recovery.Admin",message="ENROLLMENT_INVALID");
   arrayAppend(cohort,{userId=id,eventId=e.EVENT_ID,enrolledAtUtc=e.ENROLLMENT_UTC});} return cohort;
 }
 private struct function resetStart(required struct review,required numeric actor) {
  transaction isolation="serializable" {
   queryExecute("SELECT id FROM inactive_member_recovery_settings WHERE id=1 FOR UPDATE",{}, {datasource=variables.datasource});
   queryExecute("SELECT id FROM inactive_member_recovery_deliveries FOR UPDATE",{}, {datasource=variables.datasource});
   var cohort=resetCohort();
   if(compare(hash(serializeJSON(cohort),"SHA-256"),arguments.review.fingerprint)) throw(type="FPW.Recovery.Admin",message="COHORT_CHANGED_REVIEW_AGAIN");
   var clock=queryExecute("SELECT DATE_FORMAT(UTC_TIMESTAMP(),'%Y-%m-%d %H:%i:%s') t,DATE_FORMAT(UTC_TIMESTAMP(),'%Y-%m-%dT%H:%i:%sZ') iso",{}, {datasource=variables.datasource});
   var operation=createUUID();
   for(var member in cohort) {
    lockMember(member.userId);var before=variables.state.getState(member.userId);
    queryExecute("INSERT INTO inactive_member_recovery_member_state(user_id,recovery_enrollment_event_id,recovery_start_at_utc,updated_at_utc,updated_by,reset_operation_id)
     VALUES(:id,:event,:t,UTC_TIMESTAMP(6),:actor,:operation)
     ON DUPLICATE KEY UPDATE recovery_start_at_utc=:t,updated_at_utc=UTC_TIMESTAMP(6),updated_by=:actor,revision=revision+1,reset_operation_id=:operation",
     {id=p(member.userId,"integer"),event=p(member.eventId,"bigint"),t=p(clock.t[1]),actor=p(arguments.actor,"integer"),operation=p(operation)},{datasource=variables.datasource});
    audit(arguments.actor,"recovery_member_start_reset","user",member.userId,before,{effectiveStartUtc=clock.iso[1],enrollmentEventId=member.eventId,operationId=operation});
    stateEvent(member.userId,"recovery_schedule_reset",operation,"START_RESET");
   }
   queryExecute("UPDATE inactive_member_recovery_settings SET reset_at_utc=:t,reset_admin_user_id=:actor,reset_cohort_count=:count,reset_operation_id=:operation WHERE id=1",
    {t=p(clock.t[1]),actor=p(arguments.actor,"integer"),count=p(arrayLen(cohort),"integer"),operation=p(operation)},{datasource=variables.datasource});
   audit(arguments.actor,"recovery_start_reset","recovery_settings","1",{},{count=arrayLen(cohort),effectiveStartUtc=clock.iso[1],operationId=operation});
  } return variables.settings.getSettings();
 }
 private struct function personalPreparation(required numeric userId,required string subject,required string body) {
  var state=variables.state.getState(arguments.userId);
  if(!state.enrollmentEventId OR state.paused OR state.excluded) throw(type="FPW.Recovery.Admin",message="PERSONAL_STATE_BLOCKED");
  var q=queryExecute("SELECT email FROM users WHERE userId=:id",{id=p(arguments.userId,"integer")},{datasource=variables.datasource});
  if(q.recordCount NEQ 1) throw(type="FPW.Recovery.Admin",message="MEMBER_NOT_FOUND");
  var eligibility=variables.email.checkNonEssentialEmailEligibility(email=q.email[1],userId=arguments.userId);
  if(!eligibility.eligible) throw(type="FPW.Recovery.Admin",message="PERSONAL_PREFERENCE_BLOCKED");
  var message=variables.email.buildRecoveryPersonalEmail(eligibility=eligibility,subject=arguments.subject,body=arguments.body);
  if(!message.success) throw(type="FPW.Recovery.Admin",message=message.errorCode);
  message.toEmail=q.email[1];
  return {userId=arguments.userId,enrollmentEventId=state.enrollmentEventId,stateRevision=state.revision,recipient=q.email[1],
   subject=arguments.subject,body=arguments.body,message=message};
 }
 private struct function personalSend(required struct review,required numeric actor) {
  var prepared={};var messageId=0;
  transaction isolation="read_committed" {
   lockMember(arguments.review.userId);
   prepared=personalPreparation(arguments.review.userId,arguments.review.subject,arguments.review.body);
   if(prepared.enrollmentEventId NEQ arguments.review.enrollmentEventId OR prepared.stateRevision NEQ arguments.review.stateRevision OR compare(prepared.recipient,arguments.review.recipient))
    throw(type="FPW.Recovery.Admin",message="PERSONAL_CONTEXT_CHANGED");
   var observed=variables.observation.prepareMessage({messageKind="PERSONAL",userId=prepared.userId,enrollmentEventId=prepared.enrollmentEventId,
    administratorId=arguments.actor,submissionIdentity=arguments.review.operationId,templateId="recovery.personal.v1",templateVersion="v1"},prepared.message);
   messageId=observed.messageId;
   audit(arguments.actor,"recovery_personal_prepared","recovery_message",messageId,{},{messageId=messageId,userId=prepared.userId,submissionIdentity=arguments.review.operationId});
  }
  // A committed message with a unique submission identity is durable replay protection.
  // Recheck preferences/state immediately before transport; never hold a database transaction over SMTP.
  try {
   var fresh=personalPreparation(prepared.userId,prepared.subject,prepared.body);
   if(fresh.enrollmentEventId NEQ prepared.enrollmentEventId OR fresh.stateRevision NEQ prepared.stateRevision OR compare(fresh.recipient,prepared.recipient))
    throw(type="FPW.Recovery.Admin",message="PERSONAL_CONTEXT_CHANGED");
  } catch(any canceledPreparation) {
   variables.observation.finalizeMessage(messageId,"CANCELED");
   audit(arguments.actor,"recovery_personal_canceled","recovery_message",messageId,{},{status="CANCELED"});
   throw(type="FPW.Recovery.Admin",message="PERSONAL_CONTEXT_CHANGED");
  }
  var status="OUTCOME_UNKNOWN";
  try {var sent=variables.email.submitRecoveryPersonalEmail(toEmail=prepared.recipient,message=prepared.message);
   if(sent.OUTCOME EQ "SUBMITTED") status="SEND_ACCEPTED";else if(sent.OUTCOME EQ "FAILED") status="SEND_FAILED";
  } catch(any unknownSubmission) {status="OUTCOME_UNKNOWN";}
  var observationGap=false;
  try {variables.observation.finalizeMessage(messageId,status,status EQ "SEND_ACCEPTED" ? clockUtc():"");}
  catch(any messageObservationFailed) {observationGap=true;}
  try {audit(arguments.actor,"recovery_personal_result","recovery_message",messageId,{},{status=status});}
  catch(any auditObservationFailed) {observationGap=true;}
  return {messageId=messageId,status=status,observationGap=observationGap};
 }
 private void function stateEvent(required numeric userId,required string eventName,required string operationId,required string reason) {
  var event=new fpw.includes.ProductEventService(datasource=variables.datasource).recordEvent(userId=arguments.userId,eventName=arguments.eventName,
   entityType="user",entityId=arguments.userId,eventSource="recovery_admin",metadata={operation_id=arguments.operationId,reason=arguments.reason},idempotencyKey="recovery-admin:" & arguments.operationId & ":" & arguments.userId);
  if(!event.SUCCESS) throw(type="FPW.Recovery.Admin",message="STATE_EVENT_FAILED");
 }
 private void function audit(required numeric actor,required string action,required string type,required string id,struct before={},struct after={}) {
  variables.auditService.record(actorUserId=arguments.actor,action=arguments.action,targetType=arguments.type,targetId=arguments.id,success=true,previousValues=arguments.before,newValues=arguments.after);
 }
 private void function lockMember(required numeric userId) {
  if(!queryExecute("SELECT userId FROM users WHERE userId=:id FOR UPDATE",{id=p(arguments.userId,"integer")},{datasource=variables.datasource}).recordCount)
   throw(type="FPW.Recovery.Admin",message="MEMBER_NOT_FOUND");
 }
 private string function remember(required string kind,required numeric actor,required struct payload) {
  var token=lCase(replace(createUUID(),"-","","all")) & lCase(replace(createUUID(),"-","","all"));
  lock scope="session" type="exclusive" timeout=10 {
   if(!structKeyExists(session,"fpwRecoveryCenterReviews")) session.fpwRecoveryCenterReviews={};
   session.fpwRecoveryCenterReviews[arguments.kind]={actor=arguments.actor,token=token,expires=dateAdd("n",15,now()),payload=duplicate(arguments.payload),operationId=createUUID()};
  } return token;
 }
 private struct function consume(required string kind,required numeric actor,required struct values) {
  var review={};
  lock scope="session" type="exclusive" timeout=10 {
   if(!structKeyExists(session,"fpwRecoveryCenterReviews") OR !structKeyExists(session.fpwRecoveryCenterReviews,arguments.kind))
    throw(type="FPW.Recovery.Admin",message="REVIEW_REQUIRED");
   var saved=session.fpwRecoveryCenterReviews[arguments.kind];
   if(saved.actor NEQ arguments.actor OR dateCompare(saved.expires,now()) LTE 0 OR compare(hash(textValue(arguments.values,"reviewToken"),"SHA-256"),hash(saved.token,"SHA-256")))
    throw(type="FPW.Recovery.Admin",message="REVIEW_INVALID");
   if(compare(textValue(arguments.values,"confirmed"),"YES")) throw(type="FPW.Recovery.Admin",message="CONFIRMATION_REQUIRED");
   review=duplicate(saved.payload);review.operationId=saved.operationId;
   structDelete(session.fpwRecoveryCenterReviews,arguments.kind);
  } return review;
 }
 private struct function redact(required struct message) {
  var result=duplicate(arguments.message);
  var tokenMatches=reMatchNoCase("[?&](t|token|fpw_return|authIntent|unsubscribeToken|key|signature|intent)=[^\s<>&""']+",toString(result.textBody ?: ""));
  for(var matched in tokenMatches) {
   var bearer=listRest(matched,"=");
   for(var key in ["htmlBody","textBody","ctaUrl","destinationUrl"]) if(structKeyExists(result,key)) {
    for(var variant in [bearer,encodeForHTML(bearer),encodeForHTMLAttribute(bearer),urlEncodedFormat(bearer)])
     result[key]=replace(result[key],variant,"[REDACTED]","all");
   }
  }
  for(var key in ["htmlBody","textBody","ctaUrl","destinationUrl"]) if(structKeyExists(result,key)) {
   result[key]=reReplaceNoCase(result[key],'([?&](t|token|key|signature|intent)=)[^&\s"<>]+','\1[REDACTED]',"all");
  }
  if(structKeyExists(result,"htmlBody")) {
   result.htmlBody=reReplaceNoCase(result.htmlBody,"<img[^>]*>","","all");
   result.htmlBody=reReplaceNoCase(result.htmlBody,'href="[^"]*"','href="##"',"all");
  } return result;
 }
 private struct function reportPage(required numeric total,struct values={},string pageKey="page") {
  var pageValue=textValue(arguments.values,arguments.pageKey);var sizeValue=textValue(arguments.values,"pageSize");
  if((len(pageValue) AND !reFind("^[1-9][0-9]{0,8}$",pageValue)) OR (len(sizeValue) AND !reFind("^[1-9][0-9]{0,8}$",sizeValue)))
   throw(type="FPW.Recovery.Admin",message="INVALID_PAGE");
  var size=len(sizeValue) ? min(100,val(sizeValue)):25;var totalPages=max(1,ceiling(arguments.total/size));
  return {total=arguments.total,page=min(totalPages,len(pageValue) ? val(pageValue):1),pageSize=size,totalPages=totalPages};
 }
 private struct function pageRows(required array rows,required struct values) {
  var page=max(1,val(textValue(arguments.values,"page")));var size=min(100,max(1,val(textValue(arguments.values,"pageSize"))));
  if(!len(textValue(arguments.values,"pageSize"))) size=25;
  // Internal dashboard requests all already evaluated rows; browser size is capped by the endpoint.
  if(textValue(arguments.values,"pageSize") EQ "100000") size=100000;
  var subset=[];for(var i=(page-1)*size+1;i LTE min(arrayLen(arguments.rows),page*size);i++) arrayAppend(subset,arguments.rows[i]);
  return {rows=subset,total=arrayLen(arguments.rows),page=page,pageSize=size,evaluatedAtUtc=clockUtc()};
 }
 private array function rowsOf(required query q) {var rows=[];for(var row in arguments.q) arrayAppend(rows,duplicate(row));return rows;}
 private struct function p(required any value,string type="varchar") {return {value=arguments.value,cfsqltype="cf_sql_" & arguments.type};}
 private string function textValue(required struct values,required string key) {return structKeyExists(arguments.values,arguments.key) AND isSimpleValue(arguments.values[arguments.key]) ? toString(arguments.values[arguments.key]):"";}
 private numeric function idValue(required struct values,required string key) {
  var value=textValue(arguments.values,arguments.key);if(!reFind("^[1-9][0-9]{0,14}$",value)) throw(type="FPW.Recovery.Admin",message="INVALID_ID");return val(value);
 }
}
