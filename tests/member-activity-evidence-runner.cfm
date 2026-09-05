<cfsetting showdebugoutput="false" enablecfoutputonly="true" requesttimeout="120">
<cfparam name="url.confirm" default="">
<cfset expectedConfirmation = "RUN_MEMBER_ACTIVITY_EVIDENCE_TESTS">
<cfset serverName = structKeyExists(cgi, "server_name") ? lCase(trim(toString(cgi.server_name))) : "">
<cfset httpHost = structKeyExists(cgi, "http_host") ? lCase(trim(toString(cgi.http_host))) : "">
<cfset serverPort = structKeyExists(cgi, "server_port") ? val(cgi.server_port) : 0>
<cfset isLocal = listFindNoCase("localhost,127.0.0.1,::1", serverName) GT 0
  AND reFindNoCase("^(localhost|127\.0\.0\.1|\[::1\])(:8500)?$", httpHost) GT 0
  AND serverPort EQ 8500>

<cfif trim(toString(url.confirm)) NEQ expectedConfirmation OR NOT isLocal>
  <cfheader statuscode="404">
  <cfcontent type="application/json; charset=utf-8" reset="true">
  <cfoutput>#serializeJSON({ SUCCESS = false, ERROR = "LOCAL_TEST_CONFIRMATION_REQUIRED" })#</cfoutput>
  <cfabort>
</cfif>

<cfif NOT directoryExists(expandPath("/testbox/system"))>
  <cfheader statuscode="503">
  <cfcontent type="application/json; charset=utf-8" reset="true">
  <cfoutput>#serializeJSON({ SUCCESS = false, ERROR = "TESTBOX_NOT_INSTALLED" })#</cfoutput>
  <cfabort>
</cfif>

<cftry>
  <cfset request.memberActivityFixtureUserId = 0>
  <cfif structKeyExists(url,"fixtureEmail") AND reFind("^codex-activity-[a-z0-9-]+@example[.]test$",url.fixtureEmail)>
    <cfset activityFixture = queryExecute("SELECT userId FROM users WHERE email=:email AND created>=DATE_SUB(NOW(),INTERVAL 4 HOUR)
      AND EXISTS (SELECT 1 FROM product_events e WHERE e.user_id=users.userId AND e.event_name='sign_up' AND e.event_source='member_signup')",
      {email={value=url.fixtureEmail,cfsqltype="cf_sql_varchar"}},{datasource="fpw"})>
    <cfif activityFixture.recordCount EQ 1><cfset request.memberActivityFixtureUserId=val(activityFixture.userId[1])></cfif>
  </cfif>
  <cfset runner = createObject("component", "testbox.system.TestBox").init(
    bundles = "fpw.tests.specs.MemberActivityEvidenceSpec"
  )>
  <cfset rawResults = runner.runRaw()>
  <cfset results = rawResults.getMemento()>
  <cfset ok = val(results.totalSpecs) GT 0 AND val(results.totalFail) EQ 0 AND val(results.totalError) EQ 0>
  <cfheader statuscode="#ok ? 200 : 500#">
  <cfcontent type="application/json; charset=utf-8" reset="true">
  <cfoutput>#serializeJSON({ SUCCESS = ok, results = results })#</cfoutput>
  <cfcatch type="any">
    <cfheader statuscode="500">
    <cfcontent type="application/json; charset=utf-8" reset="true">
    <cfoutput>#serializeJSON({ SUCCESS = false, ERROR = "TEST_RUNNER_EXCEPTION", MESSAGE = cfcatch.message, TYPE = cfcatch.type })#</cfoutput>
  </cfcatch>
</cftry>
