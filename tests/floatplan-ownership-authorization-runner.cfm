<cfsetting showdebugoutput="false" enablecfoutputonly="true" requesttimeout="180">
<cfparam name="url.confirm" default="">

<cfset expectedConfirmation = "RUN_DISPOSABLE_FLOATPLAN_OWNERSHIP_TESTS">
<cfset serverName = structKeyExists(cgi, "server_name") ? lCase(trim(toString(cgi.server_name))) : "">
<cfset httpHost = structKeyExists(cgi, "http_host") ? lCase(trim(toString(cgi.http_host))) : "">
<cfset serverPort = structKeyExists(cgi, "server_port") ? val(cgi.server_port) : 0>
<cfset isLocalServerName = listFindNoCase("localhost,127.0.0.1,::1", serverName) GT 0>
<cfset isLocalHostHeader = reFindNoCase("^(localhost|127\.0\.0\.1|\[::1\])(:8500)?$", httpHost) GT 0>
<cfset isLocalDevRequest = isLocalServerName AND isLocalHostHeader AND serverPort EQ 8500>

<cfif trim(toString(url.confirm)) NEQ expectedConfirmation OR NOT isLocalDevRequest>
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

<cfquery name="qTargetDatabase" datasource="fpw">
  SELECT DATABASE() AS database_name
</cfquery>
<cfif qTargetDatabase.recordCount NEQ 1 OR uCase(trim(toString(qTargetDatabase.database_name[1]))) NEQ "FPW">
  <cfheader statuscode="409">
  <cfcontent type="application/json; charset=utf-8" reset="true">
  <cfoutput>#serializeJSON({ SUCCESS = false, ERROR = "LOCAL_FPW_DATABASE_REQUIRED" })#</cfoutput>
  <cfabort>
</cfif>

<cftry>
  <cfset runner = createObject("component", "testbox.system.TestBox").init(
    bundles = "fpw.tests.specs.FloatPlanOwnershipAuthorizationSpec"
  )>
  <cfset rawResults = runner.runRaw()>
  <cfset results = rawResults.getMemento()>
  <cfquery name="qResidualFixtures" datasource="fpw">
    SELECT COUNT(*) AS fixture_count
    FROM users
    WHERE email LIKE 'codex-floatplan-ownership-%'
  </cfquery>
  <cfset cleanupResult = {
    SUCCESS = qResidualFixtures.recordCount EQ 1 AND val(qResidualFixtures.fixture_count[1]) EQ 0,
    REMAINING_FIXTURES = qResidualFixtures.recordCount EQ 1 ? val(qResidualFixtures.fixture_count[1]) : -1
  }>
  <cfset ok = val(results.totalSpecs) GT 0
    AND val(results.totalFail) EQ 0
    AND val(results.totalError) EQ 0
    AND cleanupResult.SUCCESS>
  <cfheader statuscode="#ok ? 200 : 500#">
  <cfcontent type="application/json; charset=utf-8" reset="true">
  <cfoutput>#serializeJSON({ SUCCESS = ok, RESULTS = results, CLEANUP = cleanupResult })#</cfoutput>
  <cfcatch type="any">
    <cfheader statuscode="500">
    <cfcontent type="application/json; charset=utf-8" reset="true">
    <cfoutput>#serializeJSON({ SUCCESS = false, ERROR = "TEST_RUNNER_EXCEPTION", MESSAGE = cfcatch.message, TYPE = cfcatch.type })#</cfoutput>
  </cfcatch>
</cftry>
