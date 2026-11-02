<cfsetting showdebugoutput="false" enablecfoutputonly="true" requesttimeout="120">
<cfparam name="url.confirm" default="">

<cfset expectedConfirmation = "RUN_ARRIVAL_DELIVERY_PHASE3_TESTS">
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
  <cfset tableCount=queryExecute("SELECT COUNT(*) AS n FROM information_schema.tables WHERE table_schema=DATABASE()
    AND table_name IN ('fpw_arrival_dispatch_control','fpw_arrival_notices','fpw_arrival_deliveries','fpw_arrival_attempts')",
    {},{datasource="fpw"})>
  <cfset nonce = trim(toString(application.arrivalPhase3SandboxId ?: ""))>
  <cfset ready=(val(tableCount.n[1]) EQ 4 AND len(nonce) EQ 36)>
  <cfif ready>
    <cfset isolated = queryExecute("SELECT COUNT(*) AS n FROM fpw_arrival_test_sandbox WHERE run_nonce=:nonce",
      {nonce=nonce},{datasource="fpw"})>
    <cfset ready = val(isolated.n[1]) EQ 1>
  </cfif>
  <cfif ready>
    <cfset control=queryExecute("SELECT mode FROM fpw_arrival_dispatch_control WHERE plan_id=0",{},{datasource="fpw"})>
    <cfset ready=(control.recordCount EQ 1 AND control.mode[1] EQ "OFF")>
  </cfif>
  <cfcatch type="any"><cfset ready=false></cfcatch>
</cftry>
<cfif NOT ready>
  <cfheader statuscode="409">
  <cfcontent type="application/json; charset=utf-8" reset="true">
  <cfoutput>#serializeJSON({SUCCESS=false,ERROR="VERIFIED_MIGRATION_AND_GLOBAL_OFF_REQUIRED",specsExecuted=0})#</cfoutput>
  <cfabort>
</cfif>

<cfif NOT directoryExists(expandPath("/testbox/system"))>
  <cfheader statuscode="503">
  <cfcontent type="application/json; charset=utf-8" reset="true">
  <cfoutput>#serializeJSON({ SUCCESS = false, ERROR = "TESTBOX_NOT_INSTALLED" })#</cfoutput>
  <cfabort>
</cfif>

<cftry>
  <cfset request.arrivalPhase3TestAuthorized = true>
  <cfset runner = createObject("component", "testbox.system.TestBox").init(
    bundles = "fpw.tests.specs.ArrivalDeliveryPhase3Spec"
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
  <cfset summary = { cfVersion=server.coldfusion.productVersion,totalSpecs=results.totalSpecs, totalPass=results.totalPass,
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
