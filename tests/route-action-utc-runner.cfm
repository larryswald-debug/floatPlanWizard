<cfsetting showdebugoutput="false" enablecfoutputonly="true" requesttimeout="120">
<cfparam name="url.confirm" default="">

<cfset expectedConfirmation = "RUN_ROUTE_ACTION_UTC_CONTRACT_TESTS">
<cfset serverName = structKeyExists(cgi, "server_name") ? lCase(trim(toString(cgi.server_name))) : "">
<cfset httpHost = structKeyExists(cgi, "http_host") ? lCase(trim(toString(cgi.http_host))) : "">
<cfset serverPort = structKeyExists(cgi, "server_port") ? val(cgi.server_port) : 0>
<cfset isLocal = listFindNoCase("localhost,127.0.0.1,::1", serverName) GT 0
  AND reFindNoCase("^(localhost|127\.0\.0\.1|\[::1\])(:8500)?$", httpHost) GT 0
  AND serverPort EQ 8500>

<cfset isDevelopment = structKeyExists(application, "env")
  AND listFindNoCase("dev,development,local", trim(toString(application.env))) GT 0>
<cfif trim(toString(url.confirm)) NEQ expectedConfirmation OR NOT isLocal OR NOT isDevelopment>
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
  <cfset runner = createObject("component", "testbox.system.TestBox").init(
    bundles = "fpw.tests.specs.RouteActionUtcContractSpec"
  )>
  <cfset rawResults = runner.runRaw()>
  <cfset results = rawResults.getMemento()>
  <cfset specResults = []>
  <cfloop array="#results.bundleStats#" index="bundle">
    <cfloop array="#bundle.suiteStats#" index="suite">
      <cfloop array="#suite.specStats#" index="spec">
        <cfset arrayAppend(specResults, { name=spec.name, status=spec.status,
          message=spec.failMessage, detail=spec.failDetail })>
      </cfloop>
    </cfloop>
  </cfloop>
  <cfset summary = { totalSpecs=results.totalSpecs, totalPass=results.totalPass,
    totalFail=results.totalFail, totalError=results.totalError, specs=specResults }>
  <cfset residue = queryExecute("SELECT
    (SELECT COUNT(*) FROM users WHERE email LIKE 'codex-route-utc-%') AS users,
    (SELECT COUNT(*) FROM floatplans WHERE floatPlanName LIKE 'codex-route-utc-%') AS plans,
    (SELECT COUNT(*) FROM loop_routes WHERE code LIKE 'codex-route-utc-%') AS routes,
    (SELECT COUNT(*) FROM route_instances WHERE generated_route_code LIKE 'codex-route-utc-%') AS instances",
    {}, {datasource="fpw"})>
  <cfset fixtureRowsRemaining = val(residue.users[1]) + val(residue.plans[1]) + val(residue.routes[1]) + val(residue.instances[1])>
  <cfset summary.fixtureRowsRemaining = fixtureRowsRemaining>
  <cfset summary.requestTimezone = getTimeZone().timezone>
  <cfset ok = fixtureRowsRemaining EQ 0 AND val(results.totalSpecs) GT 0 AND val(results.totalFail) EQ 0 AND val(results.totalError) EQ 0>
  <cfheader statuscode="#ok ? 200 : 500#">
  <cfcontent type="application/json; charset=utf-8" reset="true">
  <cfoutput>#serializeJSON({ SUCCESS = ok, results = summary })#</cfoutput>
  <cfcatch type="any">
    <cfheader statuscode="500">
    <cfcontent type="application/json; charset=utf-8" reset="true">
    <cfoutput>#serializeJSON({ SUCCESS = false, ERROR = "TEST_RUNNER_EXCEPTION", MESSAGE = cfcatch.message, TYPE = cfcatch.type })#</cfoutput>
  </cfcatch>
</cftry>
