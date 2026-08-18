<cfsetting showdebugoutput="false" enablecfoutputonly="true" requesttimeout="240">
<cfparam name="url.confirm" default="">
<cfparam name="url.mode" default="">

<cfset expectedConfirmation = "RUN_PASSWORD_STORAGE_SECURITY_TESTS">
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

<cfif lCase(trim(toString(url.mode))) EQ "create-legacy-browser-fixture">
  <cftry>
    <cfset fixtureRequest = getHttpRequestData()>
    <cfset fixtureBodyText = toString(fixtureRequest.content ?: "")>
    <cfset fixtureBody = len(trim(fixtureBodyText))
      ? deserializeJSON(fixtureBodyText, false)
      : {}>
    <cfset fixtureEmail = lCase(trim(toString(fixtureBody.email ?: "")))>
    <cfset fixturePassword = toString(fixtureBody.password ?: "")>

    <cfif
      NOT isValid("email", fixtureEmail)
      OR left(
        fixtureEmail,
        len("codex.qa1001.browser.")
      ) NEQ "codex.qa1001.browser."
      OR len(fixturePassword) LT 8
    >
      <cfheader statuscode="400">
      <cfcontent type="application/json; charset=utf-8" reset="true">
      <cfoutput>#serializeJSON({
        SUCCESS = false,
        ERROR = "INVALID_DISPOSABLE_FIXTURE"
      })#</cfoutput>
      <cfabort>
    </cfif>

    <cfset fixtureLegacyHash = uCase(
      hash(fixturePassword, "SHA-256", "UTF-8")
    )>
    <cfquery datasource="fpw">
      INSERT INTO users (
        fName,
        lName,
        email,
        password,
        passwordCreated,
        created,
        lastUpdate
      ) VALUES (
        'Codex',
        'QA1001 Browser Legacy',
        <cfqueryparam value="#fixtureEmail#" cfsqltype="cf_sql_varchar">,
        <cfqueryparam value="#fixtureLegacyHash#" cfsqltype="cf_sql_varchar">,
        UTC_TIMESTAMP(),
        UTC_TIMESTAMP(),
        UTC_TIMESTAMP()
      )
    </cfquery>

    <cfset fixturePassword = "">
    <cfset fixtureLegacyHash = "">
    <cfheader statuscode="201">
    <cfcontent type="application/json; charset=utf-8" reset="true">
    <cfoutput>#serializeJSON({ SUCCESS = true })#</cfoutput>
    <cfcatch type="any">
      <cfset fixturePassword = "">
      <cfset fixtureLegacyHash = "">
      <cfheader statuscode="500">
      <cfcontent type="application/json; charset=utf-8" reset="true">
      <cfoutput>#serializeJSON({
        SUCCESS = false,
        ERROR = "DISPOSABLE_FIXTURE_CREATION_FAILED"
      })#</cfoutput>
    </cfcatch>
  </cftry>
  <cfabort>
</cfif>

<cfif NOT directoryExists(expandPath("/testbox/system"))>
  <cfheader statuscode="503">
  <cfcontent type="application/json; charset=utf-8" reset="true">
  <cfoutput>#serializeJSON({ SUCCESS = false, ERROR = "TESTBOX_NOT_INSTALLED" })#</cfoutput>
  <cfabort>
</cfif>

<cftry>
  <cfset passwordService = createObject("component", "fpw.api.v1.PasswordHashService").init()>
  <cfset benchmarkPassword = "Qa1!" & replace(createUUID(), "-", "", "all")>

  <cfset startedAt = getTickCount()>
  <cfset benchmarkHash = passwordService.hashPassword(benchmarkPassword)>
  <cfset hashDurationMs = getTickCount() - startedAt>

  <cfset startedAt = getTickCount()>
  <cfset successfulVerify = passwordService.verifyPassword(benchmarkPassword, benchmarkHash)>
  <cfset successfulVerifyDurationMs = getTickCount() - startedAt>

  <cfset startedAt = getTickCount()>
  <cfset failedVerify = passwordService.verifyPassword(benchmarkPassword & "x", benchmarkHash)>
  <cfset failedVerifyDurationMs = getTickCount() - startedAt>

  <cfset runner = createObject("component", "testbox.system.TestBox").init(
    bundles = "fpw.tests.specs.PasswordStorageSecuritySpec"
  )>
  <cfset rawResults = runner.runRaw()>
  <cfset results = rawResults.getMemento()>
  <cfset ok = val(results.totalSpecs) GT 0
    AND val(results.totalFail) EQ 0
    AND val(results.totalError) EQ 0
    AND successfulVerify
    AND NOT failedVerify>
  <cfset compactSpecs = []>
  <cfloop array="#results.bundleStats#" index="bundleStat">
    <cfloop array="#bundleStat.suiteStats#" index="suiteStat">
      <cfloop array="#suiteStat.specStats#" index="specStat">
        <cfset compactDetail = "">
        <cfif structKeyExists(specStat, "failDetail") AND isSimpleValue(specStat.failDetail)>
          <cfset compactDetail = toString(specStat.failDetail)>
        <cfelseif
          structKeyExists(specStat, "error")
          AND isStruct(specStat.error)
          AND structKeyExists(specStat.error, "Detail")
          AND isSimpleValue(specStat.error.Detail)
        >
          <cfset compactDetail = toString(specStat.error.Detail)>
        </cfif>
        <cfset arrayAppend(compactSpecs, {
          name = toString(specStat.name ?: ""),
          status = toString(specStat.status ?: ""),
          message = toString(specStat.failMessage ?: ""),
          detail = compactDetail
        })>
      </cfloop>
    </cfloop>
  </cfloop>

  <cfset response = {
    SUCCESS = ok,
    results = {
      totalSpecs = val(results.totalSpecs),
      totalPass = val(results.totalPass),
      totalFail = val(results.totalFail),
      totalError = val(results.totalError),
      totalSkipped = val(results.totalSkipped),
      specs = compactSpecs
    },
    configuration = passwordService.getConfiguration(),
    benchmark = {
      hashDurationMs = hashDurationMs,
      successfulVerifyDurationMs = successfulVerifyDurationMs,
      failedVerifyDurationMs = failedVerifyDurationMs
    }
  }>

  <cfset benchmarkPassword = "">
  <cfset benchmarkHash = "">
  <cfheader statuscode="#ok ? 200 : 500#">
  <cfcontent type="application/json; charset=utf-8" reset="true">
  <cfoutput>#serializeJSON(response)#</cfoutput>
  <cfcatch type="any">
    <cfheader statuscode="500">
    <cfcontent type="application/json; charset=utf-8" reset="true">
    <cfoutput>#serializeJSON({
      SUCCESS = false,
      ERROR = "TEST_RUNNER_EXCEPTION",
      MESSAGE = "The password-storage security runner failed safely.",
      TYPE = structKeyExists(cfcatch, "type") ? cfcatch.type : "any"
    })#</cfoutput>
  </cfcatch>
</cftry>
