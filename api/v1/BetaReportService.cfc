component output=false {
 variables.datasource="fpw";
 public any function init(string datasource="fpw") {variables.datasource=arguments.datasource;return this;}

 // A fixed number of batch reads; no recipient addresses, names, plan contents or feedback descriptions.
 public struct function getReport(required numeric adminId) {
  new fpw.api.v1.BetaProgramService().init(variables.datasource).requireAdmin(arguments.adminId);
  var options={datasource=variables.datasource};
  var cutoff="";
  var cohort=queryNew("");var basic=queryNew("");var premium=queryNew("");var events=queryNew("");
  transaction {
   cutoff=queryExecute("SELECT DATE_FORMAT(UTC_TIMESTAMP(6),'%Y-%m-%d %H:%i:%s.%f') t",{},options).t[1];
   var params={cutoff={value=cutoff,cfsqltype="cf_sql_varchar"}};
   cohort=queryExecute("SELECT b.user_id,b.status,
     DATE_FORMAT(b.enrolled_at_utc,'%Y-%m-%d %H:%i:%s.%f') enrolled_utc,
     IF(v.user_id IS NULL,0,1) has_vessel,IF(r.user_id IS NULL,0,1) has_route,
     IF(f.user_id IS NULL,0,1) has_floatplan
    FROM fpw_beta_participation b JOIN users u ON u.userId=b.user_id
    LEFT JOIN (SELECT DISTINCT userId user_id FROM vessels) v ON v.user_id=b.user_id
    LEFT JOIN (SELECT user_id FROM user_routes UNION SELECT user_id FROM route_instances) r ON r.user_id=b.user_id
    LEFT JOIN (SELECT DISTINCT userId user_id FROM floatplans) f ON TRIM(CAST(f.user_id AS CHAR))=CAST(b.user_id AS CHAR)
    WHERE b.status='ENROLLED' AND b.withdrawn_at_utc IS NULL
      AND b.enrolled_at_utc<CAST(:cutoff AS DATETIME(6))
    ORDER BY b.user_id",params,options);
   basic=queryExecute("SELECT r.id,r.user_id,r.float_plan_id,r.status,
     COALESCE(DATE_FORMAT(r.created_at_utc,'%Y-%m-%d %H:%i:%s.%f'),'') created_utc,
     COALESCE(DATE_FORMAT(r.completed_at_utc,'%Y-%m-%d %H:%i:%s.%f'),'') accepted_utc,
     IF(f.floatPlanId IS NULL OR TRIM(CAST(f.userId AS CHAR))=CAST(r.user_id AS CHAR),1,0) valid_owner
    FROM basic_review_send_receipts r JOIN fpw_beta_participation b ON b.user_id=r.user_id AND b.status='ENROLLED'
    LEFT JOIN floatplans f ON f.floatPlanId=r.float_plan_id
    WHERE b.enrolled_at_utc<CAST(:cutoff AS DATETIME(6))",params,options);
   premium=queryExecute("SELECT r.id,r.user_id,r.float_plan_id,r.recipient_count,
     COALESCE(DATE_FORMAT(r.created_at_utc,'%Y-%m-%d %H:%i:%s.%f'),'') created_utc,
     COALESCE(DATE_FORMAT(r.committed_at_utc,'%Y-%m-%d %H:%i:%s.%f'),'') accepted_utc,
     IF(f.floatPlanId IS NULL OR TRIM(CAST(f.userId AS CHAR))=CAST(r.user_id AS CHAR),1,0) valid_owner
    FROM premium_send_receipts r JOIN fpw_beta_participation b ON b.user_id=r.user_id AND b.status='ENROLLED'
    LEFT JOIN floatplans f ON f.floatPlanId=r.float_plan_id
    WHERE b.enrolled_at_utc<CAST(:cutoff AS DATETIME(6))",params,options);
   events=queryExecute("SELECT e.id,e.user_id,e.entity_id,e.entity_type,e.event_name,e.event_source,e.idempotency_key,
     COALESCE(e.request_correlation_id,'') request_correlation_id,
     DATE_FORMAT(e.occurred_at_utc,'%Y-%m-%d %H:%i:%s.%f') occurred_utc,
     DATE_FORMAT(e.created_at_utc,'%Y-%m-%d %H:%i:%s.%f') created_utc,
     COALESCE(JSON_VALID(e.metadata_json),0) metadata_valid,
     IF(JSON_TYPE(CASE WHEN JSON_VALID(e.metadata_json) THEN e.metadata_json ELSE 'null' END)='OBJECT',1,0) metadata_object,
     IF(JSON_TYPE(CASE WHEN JSON_VALID(e.metadata_json) THEN e.metadata_json ELSE 'null' END)='OBJECT'
       AND JSON_LENGTH(CASE WHEN JSON_VALID(e.metadata_json) THEN e.metadata_json ELSE 'null' END)=0,1,0) metadata_empty,
     IF(f.floatPlanId IS NULL OR TRIM(CAST(f.userId AS CHAR))=CAST(e.user_id AS CHAR),1,0) valid_owner,
     IF(br.id IS NULL OR (br.user_id=e.user_id AND br.float_plan_id=e.entity_id),1,0) review_receipt_matches
    FROM product_events e JOIN fpw_beta_participation b ON b.user_id=e.user_id AND b.status='ENROLLED'
    LEFT JOIN floatplans f ON f.floatPlanId=e.entity_id
    LEFT JOIN basic_review_send_receipts br ON e.event_source='basic_review_send'
      AND e.idempotency_key REGEXP '^basic_send_completed:basic_review_receipt:[1-9][0-9]*$'
      AND br.id=CAST(SUBSTRING_INDEX(e.idempotency_key,':',-1) AS UNSIGNED)
    WHERE e.event_name IN ('basic_send_completed','premium_send_completed','recovery_share_started','recovery_share_succeeded','recovery_share_failed')
      AND b.enrolled_at_utc<CAST(:cutoff AS DATETIME(6))
    ORDER BY e.id",params,options);
  }
  return reconcile(rows(cohort),rows(basic),rows(premium),rows(events),cutoff);
 }

 // Pure nonremote projection of source-minimized rows. Day40RetentionBaseline-v1 remains unchanged.
 // The predicates below mirror baseline.mjs:77-167; fixtures exercise agreement and beta time boundaries.
 public struct function reconcile(required array cohort,required array basic,required array premium,required array events,required string cutoffUtc) {
  var result={definitionVersion="BetaObservedActivation-v1",cutoffUtc=arguments.cutoffUtc,
   summary={enrolled=0,vessels=0,routes=0,floatplans=0,acceptedShares=0,activationPercent=0,unknownMembers=0},
   members=[],limitations=[
    "Current enrolled members only; invitations, withdrawn members and promotional access alone do not qualify.",
    "Asset counts show current owned assets, including assets created before enrollment and empty saved routes.",
    "Accepted sharing means application acceptance, not inbox delivery or human reading.",
    "Missing or uncertain evidence does not prove inactivity or technical failure; no comprehensive failure-rate denominator exists.",
    "Retained valid share evidence can survive plan deletion; current conflicting ownership is rejected.",
    "Historical completeness and actual shore-contact reading cannot be reconstructed."
   ]};
  if(!validClock(arguments.cutoffUtc)) throw(type="FPW.Beta.Report",message="Invalid report cutoff.");
  var members={};var receipts={};var groups={};
  for(var row in arguments.cohort) {
   var uid=toString(row.user_id);
   if(!positiveId(uid) OR compare(value(row,"status"),"ENROLLED")!=0
     OR !validClock(value(row,"enrolled_utc")) OR compare(row.enrolled_utc,arguments.cutoffUtc)>=0) continue;
   if(structKeyExists(members,uid)) continue;
   members[uid]={user_id=val(uid),enrolled_utc=row.enrolled_utc,
    has_vessel=flag(row,"has_vessel"),has_route=flag(row,"has_route"),has_floatplan=flag(row,"has_floatplan"),
    accepted_share=false,unknown_evidence=false,evidence_reasons=[]};
   arrayAppend(result.members,members[uid]);
  }
  for(var receipt in arguments.basic) {
   if(positiveId(value(receipt,"id"))) receipts[toString(receipt.id)]=receipt;
   var uid=value(receipt,"user_id");
   if(!structKeyExists(members,uid)) continue;
   var member=members[uid];
   if(compare(value(receipt,"status"),"SENT")==0 && flag(receipt,"valid_owner") && positiveId(value(receipt,"float_plan_id"))) {
    acceptAt(member,value(receipt,"accepted_utc"),arguments.cutoffUtc);
   } else if(inWindow(value(receipt,"created_utc"),member.enrolled_utc,arguments.cutoffUtc)
     && compare(value(receipt,"status"),"FAILED")!=0) note(member,"UNCONFIRMED_BASIC_RECEIPT");
  }
  for(var receipt in arguments.premium) {
   var uid=value(receipt,"user_id");
   if(!structKeyExists(members,uid)) continue;
   if(val(value(receipt,"recipient_count"))>0 && flag(receipt,"valid_owner") && positiveId(value(receipt,"float_plan_id")))
    acceptAt(members[uid],value(receipt,"accepted_utc"),arguments.cutoffUtc);
   else if(inWindow(value(receipt,"created_utc"),members[uid].enrolled_utc,arguments.cutoffUtc)) note(members[uid],"UNCONFIRMED_PREMIUM_RECEIPT");
  }
  for(var event in arguments.events) {
   var uid=value(event,"user_id");
   if(!structKeyExists(members,uid)) continue;
   var member=members[uid];var at=value(event,"occurred_utc");
   var name=value(event,"event_name");var source=value(event,"event_source");var key=value(event,"idempotency_key");
   var valid=validClock(at) && compare(at,value(event,"created_utc"))==0 && compare(at,arguments.cutoffUtc)<0
     && flag(event,"metadata_valid") && flag(event,"metadata_object") && flag(event,"valid_owner")
     && compare(value(event,"entity_type"),"float_plan")==0 && positiveId(value(event,"entity_id"));
   if(!valid) {
    if(!validClock(at) OR inWindow(at,member.enrolled_utc,arguments.cutoffUtc)) note(member,"INVALID_SHARE_EVENT");
    continue;
   }
   var completed=(compare(name,"premium_send_completed")==0 && compare(source,"premium_save_send")==0)
     OR (compare(name,"basic_send_completed")==0 && listFind("basic_save_send,basic_review_send",source)>0);
   var keyValid=compare(key,name & ":float_plan:" & value(event,"entity_id"))==0;
   if(compare(source,"basic_review_send")==0) {
    keyValid=reFind("^basic_send_completed:basic_review_receipt:[1-9][0-9]*$",key)>0;
    if(keyValid) {
     var rid=listLast(key,":");
     keyValid=(!structKeyExists(receipts,rid)
       OR (compare(value(receipts[rid],"user_id"),uid)==0 && compare(value(receipts[rid],"float_plan_id"),value(event,"entity_id"))==0))
       && (!structKeyExists(event,"review_receipt_matches") || flag(event,"review_receipt_matches"));
    }
   }
   if(completed) {
    if(keyValid) acceptAt(member,at,arguments.cutoffUtc);
    else if(inWindow(at,member.enrolled_utc,arguments.cutoffUtc)) note(member,"INVALID_COMPLETION_KEY");
    continue;
   }
   if(left(name,15)!="recovery_share_") {
    if(inWindow(at,member.enrolled_utc,arguments.cutoffUtc)) note(member,"INVALID_COMPLETION_SOURCE");
    continue;
   }
   var state=right(name,len(name)-15);var token=value(event,"request_correlation_id");
   if(!listFind("started,succeeded,failed",state) || !uuid(token)
      || !listFind("basic_save_send,basic_review_send,premium_save_send",source) || !flag(event,"metadata_empty")
      || compare(key,"recovery_share:" & lCase(token) & ":" & state)!=0) {
    if(inWindow(at,member.enrolled_utc,arguments.cutoffUtc)) note(member,"INVALID_TRACKED_SHARE");
    continue;
   }
   // Hex encoding preserves case-sensitive token grouping on CF's case-insensitive struct keys.
   var groupKey=uid & ":" & binaryEncode(charsetDecode(token,"utf-8"),"hex");
   if(!structKeyExists(groups,groupKey)) groups[groupKey]=[];
   arrayAppend(groups[groupKey],event);
  }
  for(var groupKey in groups) {
   var entries=groups[groupKey];var starts=[];var terminals=[];var relevant=false;
   var member=members[toString(entries[1].user_id)];
   for(var e in entries) {
    if(compare(e.event_name,"recovery_share_started")==0) arrayAppend(starts,e);else arrayAppend(terminals,e);
    if(inWindow(e.occurred_utc,member.enrolled_utc,arguments.cutoffUtc)) relevant=true;
   }
   var matched=arrayLen(starts)==1 && arrayLen(terminals)==1;
   if(matched) matched=compare(value(starts[1],"entity_id"),value(terminals[1],"entity_id"))==0
     && compare(starts[1].event_source,terminals[1].event_source)==0
     && val(starts[1].id)<val(terminals[1].id) && compare(starts[1].occurred_utc,terminals[1].occurred_utc)<=0;
   if(!matched) {if(relevant) note(member,"UNRESOLVED_OR_INVALID_SHARE_ATTEMPT");}
   else if(compare(terminals[1].event_name,"recovery_share_succeeded")==0) acceptAt(member,terminals[1].occurred_utc,arguments.cutoffUtc);
  }
  for(var member in result.members) {
   if(!member.accepted_share) note(member,"NO_VERIFIED_POST_ENROLLMENT_SHARE");
   result.summary.enrolled++;
   if(member.has_vessel) result.summary.vessels++;
   if(member.has_route) result.summary.routes++;
   if(member.has_floatplan) result.summary.floatplans++;
   if(member.accepted_share) result.summary.acceptedShares++;
   if(member.unknown_evidence) result.summary.unknownMembers++;
  }
  if(result.summary.enrolled) result.summary.activationPercent=100*result.summary.acceptedShares/result.summary.enrolled;
  return result;
 }
 private string function value(required struct row,required string key) {return structKeyExists(arguments.row,arguments.key) && !isNull(arguments.row[arguments.key]) ? toString(arguments.row[arguments.key]):"";}
 private boolean function flag(required struct row,required string key) {return val(value(arguments.row,arguments.key))==1;}
 private boolean function positiveId(required string value) {return reFind("^[1-9][0-9]*$",arguments.value)>0;}
 private boolean function uuid(required string value) {return reFindNoCase("^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-([a-f0-9]{16}|[a-f0-9]{4}-[a-f0-9]{12})$",arguments.value)>0;}
 private boolean function validClock(required string value) {
  return reFind("^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}[.][0-9]{6}$",arguments.value)>0
   && isDate(left(arguments.value,19)) && compare(arguments.value,"1970-01-01 00:00:00.000000")>0;
 }
 private boolean function inWindow(required string at,required string enrolled,required string cutoff) {return validClock(arguments.at) && compare(arguments.at,arguments.enrolled)>=0 && compare(arguments.at,arguments.cutoff)<0;}
 private void function note(required struct member,required string reason) {arguments.member.unknown_evidence=true;if(!arrayFind(arguments.member.evidence_reasons,arguments.reason)) arrayAppend(arguments.member.evidence_reasons,arguments.reason);}
 private void function acceptAt(required struct member,required string at,required string cutoff) {
  if(inWindow(arguments.at,arguments.member.enrolled_utc,arguments.cutoff)) arguments.member.accepted_share=true;
  else if(!validClock(arguments.at)) note(arguments.member,"ACCEPTED_SHARE_TIME_UNKNOWN");
 }
 private array function rows(required query records) {var result=[];for(var row in arguments.records) arrayAppend(result,row);return result;}
}
