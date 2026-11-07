component output=false {
 variables.datasource="fpw";
 public any function init(string datasource="fpw") { variables.datasource=arguments.datasource; return this; }
 private struct function p(required any value,string kind="cf_sql_integer") { return {value=arguments.value,cfsqltype=arguments.kind}; }
 public void function requireAdmin(required numeric adminId) {
  var access=new fpw.api.v1.AdminAuthorizationService().init(variables.datasource).authorizeCurrentSession({userId=arguments.adminId});
  if(!access.authorized) throw(type="FPW.Beta.Rejected",message="Administrative access is required.");
 }
 public query function getParticipation(required numeric userId) {
  return queryExecute("SELECT * FROM fpw_beta_participation WHERE user_id=:uid",{uid=p(arguments.userId)},{datasource=variables.datasource});
 }
 // Nonremote: only protected pages pass server-resolved identities. No access grant occurs here.
 public void function inviteMember(required numeric adminId,required numeric userId,required string source,numeric entitlementId=0) {
  requireAdmin(arguments.adminId);
  if(!listFind("existing_member,mailing_list,other",arguments.source)) throw(type="FPW.Beta.Rejected",message="Choose a recruitment source.");
  transaction {
   var owner=queryExecute("SELECT userId FROM users WHERE userId=:uid FOR UPDATE",{uid=p(arguments.userId)},{datasource=variables.datasource});
   if(owner.recordCount!=1) throw(type="FPW.Beta.Rejected",message="Member not found.");
   if(arguments.entitlementId>0) {
    var entitlement=queryExecute("SELECT id FROM member_entitlements WHERE id=:eid AND user_id=:uid AND promo_code_id IS NOT NULL",{eid=p(arguments.entitlementId,"cf_sql_bigint"),uid=p(arguments.userId)},{datasource=variables.datasource});
    if(entitlement.recordCount!=1) throw(type="FPW.Beta.Rejected",message="Select this member's existing promotional entitlement.");
   }
   var current=getParticipation(arguments.userId);
   if(current.recordCount AND current.status[1]=="WITHDRAWN") throw(type="FPW.Beta.Rejected",message="Withdrawn participation cannot be reinvited in this beta phase.");
   if(!current.recordCount) {
    queryExecute("INSERT INTO fpw_beta_participation(user_id,status,recruitment_source,invited_by_user_id,invited_at_utc,entitlement_id) VALUES(:uid,'INVITED',:source,:actor,UTC_TIMESTAMP(6),:eid)",
     {uid=p(arguments.userId),source=p(arguments.source,"cf_sql_varchar"),actor=p(arguments.adminId),eid={value=arguments.entitlementId,cfsqltype="cf_sql_bigint",null=arguments.entitlementId<=0}},{datasource=variables.datasource});
    new fpw.api.v1.AdminAuditService().init(variables.datasource).record(actorUserId=arguments.adminId,action="beta_invited",targetType="beta_participation",targetId=toString(arguments.userId),success=true,newValues={status="INVITED",recruitment_source=arguments.source},reason="Founding Beta invitation recorded; no email or entitlement granted.");
   }
  }
 }
 public void function accept(required numeric userId) {
  transaction {
   var row=queryExecute("SELECT status FROM fpw_beta_participation WHERE user_id=:uid FOR UPDATE",{uid=p(arguments.userId)},{datasource=variables.datasource});
   if(!row.recordCount OR row.status[1]=='WITHDRAWN') throw(type="FPW.Beta.Rejected",message="An active invitation is required.");
   queryExecute("UPDATE fpw_beta_participation SET status='ENROLLED',enrolled_at_utc=UTC_TIMESTAMP(6),acceptance_version='founding-beta-v1' WHERE user_id=:uid AND status='INVITED'",{uid=p(arguments.userId)},{datasource=variables.datasource});
  }
 }
 public void function withdraw(required numeric userId) {
  transaction {
   var row=queryExecute("SELECT status FROM fpw_beta_participation WHERE user_id=:uid FOR UPDATE",{uid=p(arguments.userId)},{datasource=variables.datasource});
   if(!row.recordCount OR row.status[1]=='INVITED') throw(type="FPW.Beta.Rejected",message="Only enrolled participation can be withdrawn.");
   queryExecute("UPDATE fpw_beta_participation SET status='WITHDRAWN',withdrawn_at_utc=UTC_TIMESTAMP(6) WHERE user_id=:uid AND status='ENROLLED'",{uid=p(arguments.userId)},{datasource=variables.datasource});
  }
 }
 public query function listParticipants(required numeric adminId) {
  requireAdmin(arguments.adminId);
  return queryExecute("SELECT user_id,status,recruitment_source,invited_at_utc,enrolled_at_utc,withdrawn_at_utc,entitlement_id FROM fpw_beta_participation ORDER BY user_id",{},{datasource=variables.datasource});
 }
}
