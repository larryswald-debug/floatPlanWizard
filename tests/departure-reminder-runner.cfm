<cfsetting showdebugoutput="false" enablecfoutputonly="true" requesttimeout="120">
<cfparam name="url.confirm" default="">

<cfset expectedConfirmation = "RUN_DEPARTURE_REMINDER_CONTRACT_TESTS">
<cfset serverName = structKeyExists(cgi, "server_name") ? lCase(trim(toString(cgi.server_name))) : "">
<cfset httpHost = structKeyExists(cgi, "http_host") ? lCase(trim(toString(cgi.http_host))) : "">
<cfset serverPort = structKeyExists(cgi, "server_port") ? val(cgi.server_port) : 0>
<cfset isLocalServerName = listFindNoCase("localhost,127.0.0.1,::1", serverName) GT 0>
<cfset isLocalHostHeader = reFindNoCase("^(localhost|127\.0\.0\.1|\[::1\])(:8500)?$", httpHost) GT 0>
<cfset isLocalDevRequest = isLocalServerName AND isLocalHostHeader AND serverPort EQ 8500>

<cfif trim(toString(url.confirm)) NEQ expectedConfirmation OR NOT isLocalDevRequest>
  <cfheader statuscode="404">
  <cfcontent type="application/json; charset=utf-8" reset="true">
  <cfoutput>#serializeJSON({ SUCCESS=false, ERROR="LOCAL_TEST_CONFIRMATION_REQUIRED" })#</cfoutput>
  <cfabort>
</cfif>

<cfif NOT directoryExists(expandPath("/testbox/system"))>
  <cfheader statuscode="503">
  <cfcontent type="application/json; charset=utf-8" reset="true">
  <cfoutput>#serializeJSON({ SUCCESS=false, ERROR="TESTBOX_NOT_INSTALLED" })#</cfoutput>
  <cfabort>
</cfif>

<cfset runnerStatus = 500>
<cfset runnerResponse = { SUCCESS=false, ERROR="TEST_RUNNER_FAILED" }>

<cftry>
  <cfset runner = createObject("component", "testbox.system.TestBox").init(
    bundles="fpw.tests.specs.DepartureReminderContractSpec"
  )>
  <cfset rawResults = runner.runRaw()>
  <cfset results = rawResults.getMemento()>
  <cfset ok = val(results.totalSpecs) GT 0
    AND val(results.totalFail) EQ 0
    AND val(results.totalError) EQ 0>
  <cfset runnerStatus = ok ? 200 : 500>
  <cfset runnerResponse = { SUCCESS=ok, results=results }>

  <cfcatch type="any">
    <cfset runnerStatus = 500>
    <cfset runnerResponse = {
      SUCCESS=false,
      ERROR="TEST_RUNNER_EXCEPTION",
      MESSAGE=cfcatch.message,
      DETAIL=cfcatch.detail,
      TYPE=cfcatch.type
    }>
  </cfcatch>
</cftry>

<cfheader statuscode="#runnerStatus#">
<cfcontent type="application/json; charset=utf-8" reset="true">
<cfoutput>#serializeJSON(runnerResponse)#</cfoutput>
