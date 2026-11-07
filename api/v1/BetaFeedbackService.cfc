component output=false {
 variables.datasource="fpw";
 variables.categories=["Account and Login","Trip Planning","Float Plans","Active Cruise and Monitoring","Companion App","Billing and Subscriptions","Bug Report","Other"];
 public any function init(string datasource="fpw") {variables.datasource=arguments.datasource;return this;}
 private struct function p(required any value,string kind="cf_sql_integer") {return {value=arguments.value,cfsqltype=arguments.kind};}
 // Nonremote: no caller-supplied tester ID, email or form identity is accepted.
 public struct function recordForCurrentSession(required string category,required string description,string submissionKey="") {
  var uid=new fpw.api.v1.AdminAuthorizationService().resolveUserId(structKeyExists(session,"user") AND isStruct(session.user) ? session.user : {});
  var result={stored=false,id=0,duplicate=false};
  if(uid<=0) return result;
  transaction {
   var enrolled=queryExecute("SELECT user_id FROM fpw_beta_participation WHERE user_id=:uid AND status='ENROLLED' AND withdrawn_at_utc IS NULL FOR UPDATE",{uid=p(uid)},{datasource=variables.datasource});
   if(!enrolled.recordCount) return result;
   var cleanCategory=trim(arguments.category);var cleanDescription=trim(arguments.description);
   if(!arrayFind(variables.categories,cleanCategory) OR !len(cleanDescription) OR len(cleanDescription)>5000 OR reFind("\x00",cleanDescription))
    throw(type="FPW.BetaFeedback.Validation",message="Choose a supported category and enter a message of at most 5000 characters.");
   var key=len(trim(arguments.submissionKey)) ? lCase(trim(arguments.submissionKey)) : lCase(createUUID());
   if(!reFind("^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-([a-f0-9]{16}|[a-f0-9]{4}-[a-f0-9]{12})$",key))
    throw(type="FPW.BetaFeedback.Validation",message="Refresh the support form before submitting.");
   var params={uid=p(uid),key=p(key,"cf_sql_varchar")};
   var prior=queryExecute("SELECT id FROM fpw_beta_feedback WHERE user_id=:uid AND submission_key=:key",params,{datasource=variables.datasource});
   if(prior.recordCount) return {stored=true,id=val(prior.id[1]),duplicate=true};
   params.category=p(cleanCategory,"cf_sql_varchar");params.description=p(cleanDescription,"cf_sql_longvarchar");
   var inserted={};
   queryExecute("INSERT INTO fpw_beta_feedback(user_id,category,description,submitted_at_utc,status,submission_key) VALUES(:uid,:category,:description,UTC_TIMESTAMP(6),'NEW',:key)",params,{datasource=variables.datasource,result="inserted"});
   result={stored=true,id=val(inserted.generatedKey),duplicate=false};
  }
  return result;
 }
 public query function getFeedback(required numeric adminId) {
  new fpw.api.v1.BetaProgramService().init(variables.datasource).requireAdmin(arguments.adminId);
  return queryExecute("SELECT id,user_id,category,description,submitted_at_utc,status FROM fpw_beta_feedback ORDER BY submitted_at_utc DESC,id DESC LIMIT 200",{},{datasource=variables.datasource});
 }
 public void function updateStatus(required numeric adminId,required numeric id,required string status) {
  new fpw.api.v1.BetaProgramService().init(variables.datasource).requireAdmin(arguments.adminId);
  if(arguments.id<=0 OR arguments.id!=int(arguments.id) OR !listFind("NEW,REVIEWED,RESOLVED",arguments.status))
   throw(type="FPW.BetaFeedback.Validation",message="Choose a valid feedback status.");
  transaction {
   var params={id=p(arguments.id,"cf_sql_bigint"),status=p(arguments.status,"cf_sql_varchar")};
   var previous=queryExecute("SELECT status FROM fpw_beta_feedback WHERE id=:id FOR UPDATE",{id=params.id},{datasource=variables.datasource});
   if(!previous.recordCount) throw(type="FPW.BetaFeedback.Validation",message="Feedback record not found.");
   if(compare(previous.status[1],arguments.status)==0) return;
   queryExecute("UPDATE fpw_beta_feedback SET status=:status WHERE id=:id",params,{datasource=variables.datasource});
   new fpw.api.v1.AdminAuditService().init(variables.datasource).record(actorUserId=arguments.adminId,action="beta_feedback_status",targetType="beta_feedback",targetId=toString(arguments.id),success=true,previousValues={status=previous.status[1]},newValues={status=arguments.status},reason="Beta feedback triage status updated.");
  }
 }
}
