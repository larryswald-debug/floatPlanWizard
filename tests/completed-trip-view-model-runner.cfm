<cfsetting showdebugoutput="false" enablecfoutputonly="true" requesttimeout="180">
<cfparam name="url.confirm" default="">

<cfset expectedConfirmation = "RUN_DISPOSABLE_COMPLETED_TRIP_VIEW_TESTS">
<cfset fixturePattern = "codex-completed-trip-view-%">
<cfset serverName = structKeyExists(cgi, "server_name") ? lCase(trim(toString(cgi.server_name))) : "">
<cfset httpHost = structKeyExists(cgi, "http_host") ? lCase(trim(toString(cgi.http_host))) : "">
<cfset serverPort = structKeyExists(cgi, "server_port") ? val(cgi.server_port) : 0>
<cfset isLocalServerName = listFindNoCase("localhost,127.0.0.1,::1", serverName) GT 0>
<cfset isLocalHostHeader = reFindNoCase("^(localhost|127\.0\.0\.1|\[::1\])(:8500)?$", httpHost) GT 0>
<cfset isLocalDevRequest = isLocalServerName AND isLocalHostHeader AND serverPort EQ 8500>

<cfif trim(toString(url.confirm)) NEQ expectedConfirmation OR NOT isLocalDevRequest>
  <cfheader statuscode="404">
  <cfcontent type="application/json; charset=utf-8" reset="true">
  <cfoutput>#serializeJSON({
    SUCCESS = false,
    ERROR = "LOCAL_TEST_CONFIRMATION_REQUIRED"
  })#</cfoutput>
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
<cfif
  qTargetDatabase.recordCount NEQ 1
  OR uCase(trim(toString(qTargetDatabase.database_name[1]))) NEQ "FPW"
>
  <cfheader statuscode="409">
  <cfcontent type="application/json; charset=utf-8" reset="true">
  <cfoutput>#serializeJSON({ SUCCESS = false, ERROR = "LOCAL_FPW_DATABASE_REQUIRED" })#</cfoutput>
  <cfabort>
</cfif>

<cfset runnerStatus = 500>
<cfset runnerResponse = {
  SUCCESS = false,
  ERROR = "TEST_RUNNER_FAILED"
}>
<cfset cleanupResult = {
  SUCCESS = false,
  ERROR = "CLEANUP_NOT_RUN"
}>

<cftry>
  <cfset runner = createObject("component", "testbox.system.TestBox").init(
    bundles = "fpw.tests.specs.CompletedTripViewModelServiceSpec"
  )>
  <cfset rawResults = runner.runRaw()>
  <cfset results = rawResults.getMemento()>
  <cfset ok = val(results.totalSpecs) GT 0
    AND val(results.totalFail) EQ 0
    AND val(results.totalError) EQ 0>
  <cfset runnerStatus = ok ? 200 : 500>
  <cfset runnerResponse = {
    SUCCESS = ok,
    results = results
  }>

  <cfcatch type="any">
    <cfset runnerStatus = 500>
    <cfset runnerResponse = {
      SUCCESS = false,
      ERROR = "TEST_RUNNER_EXCEPTION",
      MESSAGE = cfcatch.message,
      TYPE = cfcatch.type
    }>
  </cfcatch>

  <cffinally>
    <cftry>
      <cfquery datasource="fpw">
        DELETE FROM floatplan_monitor_events
        WHERE float_plan_id IN (
          SELECT floatPlanId FROM floatplans
          WHERE CAST(userId AS UNSIGNED) IN (
            SELECT userId FROM users
            WHERE email LIKE <cfqueryparam value="#fixturePattern#" cfsqltype="cf_sql_varchar">
          )
        )
      </cfquery>
      <cfquery datasource="fpw">
        DELETE FROM floatplan_monitoring
        WHERE float_plan_id IN (
          SELECT floatPlanId FROM floatplans
          WHERE CAST(userId AS UNSIGNED) IN (
            SELECT userId FROM users
            WHERE email LIKE <cfqueryparam value="#fixturePattern#" cfsqltype="cf_sql_varchar">
          )
        )
      </cfquery>
      <cfquery datasource="fpw">
        DELETE FROM floatplan_events
        WHERE floatplan_id IN (
          SELECT floatPlanId FROM floatplans
          WHERE CAST(userId AS UNSIGNED) IN (
            SELECT userId FROM users
            WHERE email LIKE <cfqueryparam value="#fixturePattern#" cfsqltype="cf_sql_varchar">
          )
        )
      </cfquery>
      <cfquery datasource="fpw">
        DELETE FROM floatplan_contacts
        WHERE floatPlanId IN (
          SELECT floatPlanId FROM floatplans
          WHERE CAST(userId AS UNSIGNED) IN (
            SELECT userId FROM users
            WHERE email LIKE <cfqueryparam value="#fixturePattern#" cfsqltype="cf_sql_varchar">
          )
        )
      </cfquery>
      <cfquery datasource="fpw">
        DELETE FROM floatplan_vessels
        WHERE floatPlanId IN (
          SELECT floatPlanId FROM floatplans
          WHERE CAST(userId AS UNSIGNED) IN (
            SELECT userId FROM users
            WHERE email LIKE <cfqueryparam value="#fixturePattern#" cfsqltype="cf_sql_varchar">
          )
        )
      </cfquery>
      <cfquery datasource="fpw">
        DELETE FROM floatplans
        WHERE CAST(userId AS UNSIGNED) IN (
          SELECT userId FROM users
          WHERE email LIKE <cfqueryparam value="#fixturePattern#" cfsqltype="cf_sql_varchar">
        )
      </cfquery>
      <cfquery datasource="fpw">
        DELETE FROM route_instance_geometry_snapshots
        WHERE route_instance_id IN (
          SELECT id FROM route_instances
          WHERE CAST(user_id AS UNSIGNED) IN (
            SELECT userId FROM users
            WHERE email LIKE <cfqueryparam value="#fixturePattern#" cfsqltype="cf_sql_varchar">
          )
        )
      </cfquery>
      <cfquery datasource="fpw">
        DELETE FROM route_instance_leg_progress
        WHERE route_instance_id IN (
          SELECT id FROM route_instances
          WHERE CAST(user_id AS UNSIGNED) IN (
            SELECT userId FROM users
            WHERE email LIKE <cfqueryparam value="#fixturePattern#" cfsqltype="cf_sql_varchar">
          )
        )
      </cfquery>
      <cfquery datasource="fpw">
        DELETE FROM route_instance_legs
        WHERE route_instance_id IN (
          SELECT id FROM route_instances
          WHERE CAST(user_id AS UNSIGNED) IN (
            SELECT userId FROM users
            WHERE email LIKE <cfqueryparam value="#fixturePattern#" cfsqltype="cf_sql_varchar">
          )
        )
      </cfquery>
      <cfquery datasource="fpw">
        DELETE FROM route_instance_sections
        WHERE route_instance_id IN (
          SELECT id FROM route_instances
          WHERE CAST(user_id AS UNSIGNED) IN (
            SELECT userId FROM users
            WHERE email LIKE <cfqueryparam value="#fixturePattern#" cfsqltype="cf_sql_varchar">
          )
        )
      </cfquery>
      <cfquery datasource="fpw">
        DELETE FROM route_instances
        WHERE CAST(user_id AS UNSIGNED) IN (
          SELECT userId FROM users
          WHERE email LIKE <cfqueryparam value="#fixturePattern#" cfsqltype="cf_sql_varchar">
        )
      </cfquery>
      <cfquery datasource="fpw">
        DELETE FROM loop_routes
        WHERE description LIKE <cfqueryparam value="#fixturePattern#" cfsqltype="cf_sql_varchar">
      </cfquery>
      <cfquery datasource="fpw">
        DELETE FROM contacts
        WHERE CAST(userId AS UNSIGNED) IN (
          SELECT userId FROM users
          WHERE email LIKE <cfqueryparam value="#fixturePattern#" cfsqltype="cf_sql_varchar">
        )
      </cfquery>
      <cfquery datasource="fpw">
        DELETE FROM vessels
        WHERE CAST(userId AS UNSIGNED) IN (
          SELECT userId FROM users
          WHERE email LIKE <cfqueryparam value="#fixturePattern#" cfsqltype="cf_sql_varchar">
        )
      </cfquery>
      <cfquery datasource="fpw">
        DELETE FROM users
        WHERE email LIKE <cfqueryparam value="#fixturePattern#" cfsqltype="cf_sql_varchar">
      </cfquery>
      <cfset cleanupResult = { SUCCESS = true }>

      <cfcatch type="any">
        <cfset runnerStatus = 500>
        <cfset cleanupResult = {
          SUCCESS = false,
          ERROR = "DISPOSABLE_FIXTURE_CLEANUP_FAILED",
          MESSAGE = cfcatch.message,
          TYPE = cfcatch.type
        }>
      </cfcatch>
    </cftry>
  </cffinally>
</cftry>

<cfset runnerResponse.cleanup = cleanupResult>
<cfif NOT cleanupResult.SUCCESS>
  <cfset runnerResponse.SUCCESS = false>
  <cfset runnerResponse.ERROR = "DISPOSABLE_FIXTURE_CLEANUP_FAILED">
</cfif>

<cfheader statuscode="#runnerStatus#">
<cfcontent type="application/json; charset=utf-8" reset="true">
<cfoutput>#serializeJSON(runnerResponse)#</cfoutput>
