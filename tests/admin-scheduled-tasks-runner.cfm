<cfsetting showdebugoutput="false" enablecfoutputonly="true" requesttimeout="180">
<cfheader name="Cache-Control" value="no-store">
<cfcontent type="application/json; charset=utf-8" reset="true">
<cfscript>
// This runner uses the real administrator authorization and CSRF checks.
// Every scheduler operation in its fixed TestBox bundle uses an in-memory fake.
isLocal = structKeyExists(server, "coldfusion")
    AND compareNoCase(toString(server.coldfusion.productLevel), "Developer") EQ 0
    AND val(cgi.server_port) EQ 8500
    AND reFindNoCase("^(localhost|127\.0\.0\.1)(:8500)?$", toString(cgi.http_host)) GT 0;
statusCode = 404;
response = {SUCCESS=false, ERROR="LOCAL_TEST_RUNNER_ONLY"};
runnerStage = "AUTHORIZATION";
if (isLocal) {
    try {
        authService = new fpw.api.v1.AdminAuthorizationService().init("fpw");
        auth = authService.authorizeCurrentSession(structKeyExists(session, "user") AND isStruct(session.user) ? session.user : {});
        if (!auth.authorized) {
            statusCode = 403;
            response.ERROR = "ADMIN_REQUIRED";
        } else if (uCase(toString(cgi.request_method)) NEQ "POST") {
            statusCode = 405;
            response.ERROR = "POST_REQUIRED";
        } else if (!authService.isValidCsrfToken(authService.resolveRequestCsrfToken())) {
            statusCode = 403;
            response.ERROR = "CSRF_INVALID";
        } else {
            runnerStage = "TESTBOX_INITIALIZATION";
            suite = new testbox.system.TestBox(bundles="fpw.tests.specs.AdminScheduledTaskServiceSpec");
            runnerStage = "TEST_EXECUTION";
            rawResults = suite.runRaw();
            runnerStage = "TEST_RESULTS";
            results = rawResults.getMemento();
            runnerStage = "RESULT_SUMMARY";
            ok = val(results.totalSpecs) GT 0 AND val(results.totalFail) EQ 0 AND val(results.totalError) EQ 0;
            statusCode = ok ? 200 : 500;
            // Never return TestBox exception details, actual values, fixture data, or session data.
            response = {SUCCESS=ok, TOTAL=val(results.totalSpecs), PASSED=val(results.totalPass),
                FAILED=val(results.totalFail), ERRORS=val(results.totalError), FAILED_CASES=[]};
            for (bundleResult in results.bundleStats) {
                for (suiteResult in bundleResult.suiteStats) {
                    for (specResult in suiteResult.specStats) {
                        if (listFindNoCase("Failed,Error", specResult.status)) {
                            arrayAppend(response.FAILED_CASES, specResult.name);
                        }
                    }
                }
            }
        }
    } catch (any ignored) {
        statusCode = 500;
        response = {SUCCESS=false, ERROR="SCHEDULED_TASK_TEST_RUNNER_FAILED", STAGE=runnerStage};
    }
}
</cfscript>
<cfheader statuscode="#statusCode#">
<cfoutput>#serializeJSON(response)#</cfoutput>
