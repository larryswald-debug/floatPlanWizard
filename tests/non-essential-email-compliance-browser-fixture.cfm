<cfsetting showdebugoutput="false" enablecfoutputonly="true" requesttimeout="120">
<cfparam name="url.confirm" default="">
<cfparam name="url.action" default="setup">

<cfscript>
expectedConfirmation = "RUN_NON_ESSENTIAL_EMAIL_BROWSER_FIXTURE";
fixturePrefix = "codex-nonessential-browser-";
datasource = "fpw";
serverName = structKeyExists(cgi, "server_name") ? lCase(trim(toString(cgi.server_name))) : "";
httpHost = structKeyExists(cgi, "http_host") ? lCase(trim(toString(cgi.http_host))) : "";
serverPort = structKeyExists(cgi, "server_port") ? val(cgi.server_port) : 0;
isLocal = listFindNoCase("localhost,127.0.0.1,::1", serverName) GT 0
  AND reFindNoCase("^(localhost|127\.0\.0\.1|\[::1\])(:8500)?$", httpHost) GT 0
  AND serverPort EQ 8500;

function cleanupBrowserFixtures() {
  var pattern = fixturePrefix & "%";
  queryExecute(
    "DELETE FROM email_optout WHERE email LIKE :pattern",
    { pattern = { value = pattern, cfsqltype = "cf_sql_varchar" } },
    { datasource = datasource }
  );
  queryExecute(
    "DELETE FROM users WHERE email LIKE :pattern",
    { pattern = { value = pattern, cfsqltype = "cf_sql_varchar" } },
    { datasource = datasource }
  );
}
</cfscript>

<cfif trim(toString(url.confirm)) NEQ expectedConfirmation OR NOT isLocal>
  <cfheader statuscode="404">
  <cfcontent type="application/json; charset=utf-8" reset="true">
  <cfoutput>#serializeJSON({ SUCCESS = false, ERROR = "LOCAL_TEST_CONFIRMATION_REQUIRED" })#</cfoutput>
  <cfabort>
</cfif>

<cftry>
  <cfset actionValue = lCase(trim(toString(url.action)))>
  <cfset cleanupBrowserFixtures()>

  <cfif actionValue EQ "cleanup">
    <cfcontent type="application/json; charset=utf-8" reset="true">
    <cfoutput>#serializeJSON({ SUCCESS = true, CLEANED = true })#</cfoutput>
    <cfabort>
  </cfif>

  <cfset token = lCase(replace(createUUID(), "-", "", "all"))>
  <cfset fixtureEmail = left(fixturePrefix & token & "@example.test", 255)>
  <cfset insertResult = {}>
  <cfset queryExecute(
    "INSERT INTO users (fName, lName, email, password, passwordCreated, created)
     VALUES ('Browser', 'Compliance', :email, :passwordValue, UTC_TIMESTAMP(), UTC_TIMESTAMP())",
    {
      email = { value = fixtureEmail, cfsqltype = "cf_sql_varchar" },
      passwordValue = { value = hash(token, "SHA-256"), cfsqltype = "cf_sql_varchar" }
    },
    { datasource = datasource, result = "insertResult" }
  )>
  <cfset emailService = createObject("component", "fpw.api.v1.email").init()>
  <cfset eligibility = emailService.checkNonEssentialEmailEligibility(
    email = fixtureEmail,
    userId = val(insertResult.generatedKey)
  )>

  <cfif NOT eligibility.eligible OR eligibility.code NEQ "ELIGIBLE">
    <cfthrow type="tests.NonEssentialEligibilityFailed" message="Disposable browser fixture was not eligible.">
  </cfif>

  <cfcontent type="application/json; charset=utf-8" reset="true">
  <cfoutput>#serializeJSON({
    SUCCESS = true,
    UNSUBSCRIBE_URL = eligibility.unsubscribeUrl
  })#</cfoutput>

  <cfcatch type="any">
    <cfset cleanupBrowserFixtures()>
    <cfheader statuscode="500">
    <cfcontent type="application/json; charset=utf-8" reset="true">
    <cfoutput>#serializeJSON({
      SUCCESS = false,
      ERROR = "BROWSER_FIXTURE_FAILED",
      TYPE = cfcatch.type
    })#</cfoutput>
  </cfcatch>
</cftry>
