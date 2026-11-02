<cfsetting showdebugoutput="false" enablecfoutputonly="true" requesttimeout="120">
<cfparam name="url.confirm" default="">

<cfset expectedConfirmation = "RUN_ARRIVAL_MONITORING_PHASE2_TESTS">
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

<cftry>
  <cfset observedService = createObject("component","fpw.api.v1.ArrivalOverdueService").init("fpw")>
  <cfset suiteCompiled = false>
  <cfif directoryExists(expandPath("/testbox/system"))>
    <cfset suiteMetadata = getComponentMetadata("fpw.tests.specs.ArrivalMonitoringPhase2Spec")>
    <cfset suiteCompiled = true>
  </cfif>
  <cfset schemaCheck = queryExecute("SELECT COUNT(*) AS installed FROM information_schema.tables
    WHERE table_schema=DATABASE() AND table_name IN
    ('fpw_arrival_rollout','fpw_arrival_watches','fpw_arrival_revisions','fpw_arrival_events')",{},{datasource="fpw"})>
  <cfset migrationReady = val(schemaCheck.installed[1]) EQ 4>
  <cfif migrationReady>
    <cfset validControl = queryExecute("SELECT COUNT(*) AS n FROM fpw_arrival_rollout
      WHERE id=1 AND cutoff_utc IS NOT NULL AND mode IN ('OFF','OBSERVE')",{},{datasource="fpw"})>
    <cfset migrationReady = val(validControl.n[1]) EQ 1>
  </cfif>
  <cfcatch type="any">
    <cfheader statuscode="500">
    <cfcontent type="application/json; charset=utf-8" reset="true">
    <cfoutput>#serializeJSON({SUCCESS=false,ERROR="TEST_PREFLIGHT_FAILED",MESSAGE=cfcatch.message})#</cfoutput>
    <cfabort>
  </cfcatch>
</cftry>
<cfif NOT migrationReady>
  <cfheader statuscode="409">
  <cfcontent type="application/json; charset=utf-8" reset="true">
  <cfoutput>#serializeJSON({SUCCESS=false,ERROR="MIGRATION_REQUIRED",serviceCompiled=true,suiteCompiled=suiteCompiled,specsExecuted=0})#</cfoutput>
  <cfabort>
</cfif>

<cfif NOT directoryExists(expandPath("/testbox/system"))>
  <cfheader statuscode="503">
  <cfcontent type="application/json; charset=utf-8" reset="true">
  <cfoutput>#serializeJSON({ SUCCESS = false, ERROR = "TESTBOX_NOT_INSTALLED" })#</cfoutput>
  <cfabort>
</cfif>

<cftry>
  <cfset request.arrivalPhase2TestAuthorized = true>
  <cfset runner = createObject("component", "testbox.system.TestBox").init(
    bundles = "fpw.tests.specs.ArrivalMonitoringPhase2Spec"
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
  <cfset ok = val(results.totalSpecs) GT 0 AND val(results.totalFail) EQ 0 AND val(results.totalError) EQ 0>
  <cfheader statuscode="#ok ? 200 : 500#">
  <cfcontent type="application/json; charset=utf-8" reset="true">
  <cfoutput>#serializeJSON({ SUCCESS = ok, results = summary })#</cfoutput>
  <cfcatch type="any">
    <cfheader statuscode="500">
    <cfcontent type="application/json; charset=utf-8" reset="true">
    <cfoutput>#serializeJSON({ SUCCESS = false, ERROR = "TEST_RUNNER_EXCEPTION", MESSAGE = cfcatch.message, TYPE = cfcatch.type })#</cfoutput>
  </cfcatch>
</cftry>
