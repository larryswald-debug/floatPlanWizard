<cfsetting showdebugoutput="false" enablecfoutputonly="true" requesttimeout="120">
<cfparam name="url.confirm" default="">
<cfparam name="url.action" default="preview">
<cfparam name="url.stage" default="A">

<cfscript>
expectedConfirmation = "RUN_INACTIVE_MEMBER_RECOVERY_EMAIL_PREVIEW";
fixturePrefix = "codex-recovery-email-preview-";
datasource = "fpw";
serverName = structKeyExists(cgi,"server_name") ? lCase(trim(toString(cgi.server_name))) : "";
httpHost = structKeyExists(cgi,"http_host") ? lCase(trim(toString(cgi.http_host))) : "";
serverPort = structKeyExists(cgi,"server_port") ? val(cgi.server_port) : 0;
isLocal = listFindNoCase("localhost,127.0.0.1,::1",serverName) GT 0
  AND reFindNoCase("^(localhost|127\.0\.0\.1|\[::1\])(:8500)?$",httpHost) GT 0
  AND serverPort EQ 8500;

function cleanupPreviewFixtures() {
  var pattern = fixturePrefix & "%";
  queryExecute(
    "DELETE FROM floatplans WHERE userId IN (SELECT userId FROM users WHERE email LIKE :pattern)",
    {pattern={value=pattern,cfsqltype="cf_sql_varchar"}},
    {datasource=datasource}
  );
  queryExecute(
    "DELETE FROM email_optout WHERE email LIKE :pattern",
    {pattern={value=pattern,cfsqltype="cf_sql_varchar"}},
    {datasource=datasource}
  );
  queryExecute(
    "DELETE FROM users WHERE email LIKE :pattern",
    {pattern={value=pattern,cfsqltype="cf_sql_varchar"}},
    {datasource=datasource}
  );
}
</cfscript>

<cfif trim(toString(url.confirm)) NEQ expectedConfirmation OR NOT isLocal>
  <cfheader statuscode="404">
  <cfcontent type="application/json; charset=utf-8" reset="true">
  <cfoutput>#serializeJSON({SUCCESS=false,ERROR="LOCAL_TEST_CONFIRMATION_REQUIRED"})#</cfoutput>
  <cfabort>
</cfif>

<cftry>
  <cfset cleanupPreviewFixtures()>
  <cfif lCase(trim(toString(url.action))) EQ "cleanup">
    <cfcontent type="application/json; charset=utf-8" reset="true">
    <cfoutput>#serializeJSON({SUCCESS=true,CLEANED=true})#</cfoutput>
    <cfabort>
  </cfif>

  <cfset stageValue = uCase(trim(toString(url.stage)))>
  <cfif NOT listFind("A,B,C,D",stageValue)>
    <cfthrow type="tests.InvalidPreviewStage" message="Preview stage is invalid.">
  </cfif>
  <cfset token = lCase(replace(createUUID(),"-","","all"))>
  <cfset fixtureEmail = left(fixturePrefix & lCase(stageValue) & "-" & token & "@example.test",255)>
  <cfset userInsert = {}>
  <cfset queryExecute(
    "INSERT INTO users (fName,lName,email,password,passwordCreated,created)
     VALUES ('Taylor','Preview',:email,:password,UTC_TIMESTAMP(),UTC_TIMESTAMP())",
    {
      email={value=fixtureEmail,cfsqltype="cf_sql_varchar"},
      password={value=hash(token,"SHA-256"),cfsqltype="cf_sql_varchar"}
    },
    {datasource=datasource,result="userInsert"}
  )>
  <cfset userId = val(userInsert.generatedKey)>
  <cfset service = createObject("component","fpw.api.v1.email").init()>
  <cfset eligibility = service.checkNonEssentialEmailEligibility(email=fixtureEmail,userId=userId)>
  <cfset verifiedDraftUrl = "">

  <cfif stageValue EQ "D">
    <cfset planInsert = {}>
    <cfset queryExecute(
      "INSERT INTO floatplans (userId,floatPlanName,dateCreated,lastUpdate,status,lastUpdateStatus,route_origin,is_reusable,is_visible_in_route_library)
       VALUES (CAST(:userId AS CHAR),'Recovery Preview Draft',UTC_TIMESTAMP(),UTC_TIMESTAMP(),'DRAFT',UTC_TIMESTAMP(),'basic_manual',1,1)",
      {userId={value=userId,cfsqltype="cf_sql_integer"}},
      {datasource=datasource,result="planInsert"}
    )>
    <cfset planId = val(planInsert.generatedKey)>
    <cfset ownerCheck = queryExecute(
      "SELECT COUNT(*) AS row_count FROM floatplans WHERE floatPlanId=:planId AND CAST(userId AS UNSIGNED)=:userId AND status='DRAFT'",
      {
        planId={value=planId,cfsqltype="cf_sql_integer"},
        userId={value=userId,cfsqltype="cf_sql_integer"}
      },
      {datasource=datasource}
    )>
    <cfif val(ownerCheck.row_count[1]) NEQ 1>
      <cfthrow type="tests.PreviewDraftOwnershipFailed" message="Preview Draft ownership could not be verified.">
    </cfif>
    <cfset publicBaseUrl = reReplace(eligibility.unsubscribeUrl,"/unsubscribe\.cfm\?.*$","","one")>
    <cfset verifiedDraftUrl = publicBaseUrl & "/app/floatplan-wizard.cfm?floatPlanId=" & planId>
  </cfif>

  <cfset message = service.buildInactiveMemberRecoveryEmail(
    stage=stageValue,
    eligibility=eligibility,
    firstName="Taylor",
    verifiedDraftUrl=verifiedDraftUrl
  )>
  <cfif NOT message.success>
    <cfthrow type="tests.RecoveryEmailPreviewFailed" message="Recovery email preview did not render.">
  </cfif>

  <cfheader name="Cache-Control" value="no-store">
  <cfcontent type="text/html; charset=utf-8" reset="true">
  <cfoutput>#message.htmlBody#</cfoutput>

  <cfcatch type="any">
    <cfset cleanupPreviewFixtures()>
    <cfheader statuscode="500">
    <cfcontent type="application/json; charset=utf-8" reset="true">
    <cfoutput>#serializeJSON({SUCCESS=false,ERROR="RECOVERY_EMAIL_PREVIEW_FAILED",TYPE=cfcatch.type})#</cfoutput>
  </cfcatch>
</cftry>
