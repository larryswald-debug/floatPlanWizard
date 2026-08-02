<cfsetting showdebugoutput="false" enablecfoutputonly="true" requesttimeout="120">
<cfparam name="url.confirm" default="">
<cfparam name="url.reporter" default="json">

<cfset expectedConfirmation = "RUN_DISPOSABLE_PREMIUM_SEND_CREDIT_TESTS">
<cfset serverName = structKeyExists(cgi, "server_name") ? lCase(trim(toString(cgi.server_name))) : "">
<cfset httpHost = structKeyExists(cgi, "http_host") ? lCase(trim(toString(cgi.http_host))) : "">
<cfset serverPort = structKeyExists(cgi, "server_port") ? val(cgi.server_port) : 0>
<cfset isLocalServerName = listFindNoCase("localhost,127.0.0.1", serverName) GT 0 OR serverName EQ "::1">
<cfset isLocalHostHeader = reFindNoCase("^(localhost|127\.0\.0\.1|\[::1\])(:8500)?$", httpHost) GT 0>
<cfset isLocalDevRequest = isLocalServerName AND isLocalHostHeader AND serverPort EQ 8500>
<cfset isJsonReporter = lCase(trim(toString(url.reporter))) EQ "json">
<cfset testboxSystemPath = expandPath("/testbox/system")>
<cfset fixtureEmailPattern = "codex-premium-send-contract-%">
<cfset lifecycleFixtureEmailPattern = "codex-premium-trip-lifecycle-%">

<cfif trim(toString(url.confirm)) NEQ expectedConfirmation>
  <cfheader statuscode="404">
  <cfcontent type="application/json; charset=utf-8" reset="true">
  <cfoutput>#serializeJSON({
    SUCCESS = false,
    ERROR = "TEST_CONFIRMATION_REQUIRED",
    message = "The local Premium Send Credit test confirmation was not supplied."
  })#</cfoutput>
  <cfabort>
</cfif>

<cfif NOT isLocalDevRequest>
  <cfheader statuscode="404">
  <cfcontent type="application/json; charset=utf-8" reset="true">
  <cfoutput>#serializeJSON({
    SUCCESS = false,
    ERROR = "LOCAL_TEST_RUNNER_ONLY",
    message = "This test runner accepts only localhost requests on the local development port."
  })#</cfoutput>
  <cfabort>
</cfif>

<cfquery name="qLifecycleColumns" datasource="fpw">
  SELECT COUNT(*) AS column_count
  FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND (
      (
        TABLE_NAME = 'premium_send_receipts'
        AND COLUMN_NAME IN (
          'member_entitlement_id',
          'membership_interval_snapshot',
          'access_started_at_utc',
          'access_expires_at_utc',
          'access_ended_at_utc',
          'access_end_reason'
        )
      )
      OR (
        TABLE_NAME = 'floatplans'
        AND COLUMN_NAME IN ('expiredAt', 'end_reason')
      )
    )
</cfquery>

<cfif qLifecycleColumns.recordCount NEQ 1 OR val(qLifecycleColumns.column_count[1]) NEQ 8>
  <cfheader statuscode="409">
  <cfcontent type="application/json; charset=utf-8" reset="true">
  <cfoutput>#serializeJSON({
    SUCCESS = false,
    ERROR = "SINGLE_TRIP_LIFECYCLE_MIGRATION_REQUIRED",
    message = "Apply and verify the approved single-trip lifecycle migration before running these contract tests."
  })#</cfoutput>
  <cfabort>
</cfif>

<cfif NOT isJsonReporter>
  <cfheader statuscode="400">
  <cfcontent type="application/json; charset=utf-8" reset="true">
  <cfoutput>#serializeJSON({
    SUCCESS = false,
    ERROR = "JSON_REPORTER_REQUIRED",
    message = "This guarded runner supports only the JSON reporter."
  })#</cfoutput>
  <cfabort>
</cfif>

<cfif NOT directoryExists(testboxSystemPath)>
  <cfheader statuscode="503">
  <cfcontent type="application/json; charset=utf-8" reset="true">
  <cfoutput>#serializeJSON({
    SUCCESS = false,
    ERROR = "TESTBOX_NOT_INSTALLED",
    message = "Install the repo-local TestBox dependency before running this test."
  })#</cfoutput>
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
  <cfoutput>#serializeJSON({
    SUCCESS = false,
    ERROR = "LOCAL_FPW_DATABASE_REQUIRED",
    message = "The guarded test runner requires the local FPW datasource."
  })#</cfoutput>
  <cfabort>
</cfif>

<cfset runnerStatus = 500>
<cfset runnerResponse = {
  SUCCESS = false,
  ERROR = "TEST_RUNNER_FAILED",
  message = "The Premium Send Credit contract test did not complete."
}>
<cfset cleanupResult = {
  SUCCESS = false,
  message = "Cleanup did not run."
}>

<cftry>
  <cfset testboxRunner = createObject("component", "testbox.system.TestBox").init(
    bundles = "fpw.tests.specs.PremiumSendCreditContractSpec,fpw.tests.specs.PremiumTripAccessLifecycleSpec"
  )>
  <cfset rawResults = testboxRunner.runRaw()>
  <cfset resultMemento = rawResults.getMemento()>
  <cfset totalSpecs = structKeyExists(resultMemento, "totalSpecs") ? val(resultMemento.totalSpecs) : 0>
  <cfset totalFailures = structKeyExists(resultMemento, "totalFail") ? val(resultMemento.totalFail) : 0>
  <cfset totalErrors = structKeyExists(resultMemento, "totalError") ? val(resultMemento.totalError) : 0>

  <cfset runnerStatus = (
    totalSpecs GT 0
    AND totalFailures EQ 0
    AND totalErrors EQ 0
  ) ? 200 : 500>
  <cfset runnerResponse = {
    SUCCESS = runnerStatus EQ 200,
    totalSpecs = totalSpecs,
    totalFailures = totalFailures,
    totalErrors = totalErrors,
    results = resultMemento
  }>

  <cfcatch type="any">
    <cfset runnerStatus = 500>
    <cfset runnerResponse = {
      SUCCESS = false,
      ERROR = "TEST_RUNNER_EXCEPTION",
      message = cfcatch.message,
      type = cfcatch.type
    }>
  </cfcatch>

  <cffinally>
    <cftry>
      <cfquery datasource="fpw">
        DELETE FROM floatplan_monitor_events
        WHERE user_id IN (
          SELECT userId FROM users
          WHERE email LIKE
            <cfqueryparam value="#lifecycleFixtureEmailPattern#" cfsqltype="cf_sql_varchar">
        )
      </cfquery>
      <cfquery datasource="fpw">
        DELETE FROM floatplan_monitoring
        WHERE user_id IN (
          SELECT userId FROM users
          WHERE email LIKE
            <cfqueryparam value="#lifecycleFixtureEmailPattern#" cfsqltype="cf_sql_varchar">
        )
      </cfquery>
      <cfquery datasource="fpw">
        DELETE FROM premium_send_receipts
        WHERE user_id IN (
          SELECT userId FROM users
          WHERE email LIKE
            <cfqueryparam value="#lifecycleFixtureEmailPattern#" cfsqltype="cf_sql_varchar">
        )
      </cfquery>
      <cfquery datasource="fpw">
        DELETE FROM premium_send_credits
        WHERE user_id IN (
          SELECT userId FROM users
          WHERE email LIKE
            <cfqueryparam value="#lifecycleFixtureEmailPattern#" cfsqltype="cf_sql_varchar">
        )
      </cfquery>
      <cfquery datasource="fpw">
        DELETE FROM member_entitlements
        WHERE user_id IN (
          SELECT userId FROM users
          WHERE email LIKE
            <cfqueryparam value="#lifecycleFixtureEmailPattern#" cfsqltype="cf_sql_varchar">
        )
      </cfquery>
      <cfquery datasource="fpw">
        DELETE FROM floatplans
        WHERE userId IN (
          SELECT CAST(userId AS CHAR) FROM users
          WHERE email LIKE
            <cfqueryparam value="#lifecycleFixtureEmailPattern#" cfsqltype="cf_sql_varchar">
        )
      </cfquery>
      <cfquery datasource="fpw">
        DELETE FROM users
        WHERE email LIKE
          <cfqueryparam value="#lifecycleFixtureEmailPattern#" cfsqltype="cf_sql_varchar">
      </cfquery>
      <cfquery datasource="fpw">
        DELETE FROM premium_send_receipts
        WHERE user_id IN (
          SELECT userId
          FROM users
          WHERE email LIKE
            <cfqueryparam value="#fixtureEmailPattern#" cfsqltype="cf_sql_varchar">
        )
      </cfquery>
      <cfquery datasource="fpw">
        DELETE FROM premium_send_credits
        WHERE user_id IN (
          SELECT userId
          FROM users
          WHERE email LIKE
            <cfqueryparam value="#fixtureEmailPattern#" cfsqltype="cf_sql_varchar">
        )
      </cfquery>
      <cfquery datasource="fpw">
        DELETE FROM member_entitlements
        WHERE user_id IN (
          SELECT userId
          FROM users
          WHERE email LIKE
            <cfqueryparam value="#fixtureEmailPattern#" cfsqltype="cf_sql_varchar">
        )
      </cfquery>
      <cfquery datasource="fpw">
        DELETE FROM user_stripe_customers
        WHERE user_id IN (
          SELECT userId
          FROM users
          WHERE email LIKE
            <cfqueryparam value="#fixtureEmailPattern#" cfsqltype="cf_sql_varchar">
        )
      </cfquery>
      <cfquery datasource="fpw">
        DELETE FROM floatplans
        WHERE userId IN (
          SELECT CAST(userId AS CHAR)
          FROM users
          WHERE email LIKE
            <cfqueryparam value="#fixtureEmailPattern#" cfsqltype="cf_sql_varchar">
        )
      </cfquery>
      <cfquery datasource="fpw">
        DELETE FROM users
        WHERE email LIKE
          <cfqueryparam value="#fixtureEmailPattern#" cfsqltype="cf_sql_varchar">
      </cfquery>
      <cfset cleanupResult = {
        SUCCESS = true,
        message = "All disposable Premium Send Credit contract fixtures were removed."
      }>

      <cfcatch type="any">
        <cfset runnerStatus = 500>
        <cfset cleanupResult = {
          SUCCESS = false,
          ERROR = "DISPOSABLE_FIXTURE_CLEANUP_FAILED",
          message = cfcatch.message,
          type = cfcatch.type
        }>
      </cfcatch>
    </cftry>
  </cffinally>
</cftry>

<cfset runnerResponse.cleanup = cleanupResult>
<cfif NOT cleanupResult.SUCCESS>
  <cfset runnerResponse.SUCCESS = false>
  <cfset runnerResponse.ERROR = "DISPOSABLE_FIXTURE_CLEANUP_FAILED">
  <cfset runnerResponse.message = cleanupResult.message>
</cfif>

<cfheader statuscode="#runnerStatus#">
<cfcontent type="application/json; charset=utf-8" reset="true">
<cfoutput>#serializeJSON(runnerResponse)#</cfoutput>
<cfsetting enablecfoutputonly="false">
