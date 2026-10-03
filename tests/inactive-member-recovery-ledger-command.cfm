<cfsetting showdebugoutput="false" requesttimeout="120">
<cfscript>
localHost = listFindNoCase("localhost,127.0.0.1,::1",cgi.server_name)
  AND reFindNoCase("^(localhost|127\.0\.0\.1|\[::1\])(:8500)?$",cgi.http_host)
  AND val(cgi.server_port) EQ 8500;
if (!localHost OR cgi.request_method NEQ "POST" OR (url.confirm ?: "") NEQ "RUN_INACTIVE_RECOVERY_LEDGER_TESTS"
  OR !structKeyExists(session,"user")) {cfheader(statuscode=404); abort;}
uid=val(session.user.userId ?: session.user.id ?: 0);
fixture=queryExecute("SELECT userId FROM users WHERE userId=:uid
  AND email LIKE 'codex-activity-ledger-%@example.test'
  AND created >= DATE_SUB(NOW(),INTERVAL 4 HOUR)
  AND EXISTS (SELECT 1 FROM product_events e WHERE e.user_id=users.userId
    AND e.event_name='sign_up' AND e.event_source='member_signup')",
  {uid={value=uid,cfsqltype="cf_sql_integer"}},{datasource="fpw"});
if (fixture.recordCount NEQ 1) {cfheader(statuscode=404); abort;}
body={};
raw=toString(getHttpRequestData().content);
if (len(trim(raw))) body=deserializeJSON(raw);
action=lCase(trim(body.action ?: ""));
stage=body.stage ?: "";
contact=structKeyExists(body,"contactNumber") AND isNumeric(body.contactNumber) ? val(body.contactNumber) : 1;
enrollmentId=new fpw.includes.InactiveMemberRecoveryEnrollmentService().getEnrollment(uid).EVENT_ID;
service=createObject("component","fpw.includes.InactiveMemberRecoveryLedgerService").init("fpw");
result={SUCCESS=false,CODE="INVALID_TEST_ACTION"};
switch(action) {
  case "claim": result=service.claimContact(uid,enrollmentId,contact,stage); break;
  case "retry": result=service.retryFailedContact(uid,enrollmentId,contact,stage); break;
  case "sent": result=service.markSent(uid,enrollmentId,contact,body.claim_token ?: ""); break;
  case "failed": result=service.markFailed(uid,enrollmentId,contact,body.claim_token ?: "",body.error_code ?: ""); break;
  case "state": result=service.getContactState(uid,enrollmentId,contact); break;
  case "last": result=service.getLastSuccessfulRecoveryUtc(uid); break;
  case "count":
    countRows=queryExecute("SELECT COUNT(*) AS total FROM inactive_member_recovery_deliveries WHERE user_id=:uid AND recovery_enrollment_event_id=:enrollmentId AND contact_number=:contact",
      {uid={value=uid,cfsqltype="cf_sql_integer"},enrollmentId={value=enrollmentId,cfsqltype="cf_sql_bigint"},contact={value=contact,cfsqltype="cf_sql_tinyint"}},{datasource="fpw"});
    result={SUCCESS=true,COUNT=val(countRows.total[1])};
    break;
  case "cleanup":
    before=queryExecute("SELECT COUNT(*) AS total FROM inactive_member_recovery_deliveries WHERE user_id=:uid",
      {uid={value=uid,cfsqltype="cf_sql_integer"}},{datasource="fpw"});
    for (table in ["inactive_member_recovery_messages","inactive_member_recovery_evaluations","inactive_member_recovery_deliveries","inactive_member_recovery_member_state"])
      queryExecute("DELETE FROM " & table & " WHERE user_id=:uid",{uid={value=uid,cfsqltype="cf_sql_integer"}},{datasource="fpw"});
    result=createObject("component","fpw.tests.support.MemberActivityHarness").cleanup(uid);
    remaining=queryExecute("SELECT COUNT(*) AS total FROM inactive_member_recovery_deliveries WHERE user_id=:uid",
      {uid={value=uid,cfsqltype="cf_sql_integer"}},{datasource="fpw"});
    deletedClaim=service.claimContact(uid,enrollmentId,1,"A");
    result.LEDGER_ROWS_BEFORE=val(before.total[1]);
    result.LEDGER_ROWS_AFTER=val(remaining.total[1]);
    result.DELETED_MEMBER_CLAIM_CODE=deletedClaim.CODE;
    structDelete(session,"user");
    break;
}
cfcontent(type="application/json; charset=utf-8");
writeOutput(serializeJSON(result));
</cfscript>
