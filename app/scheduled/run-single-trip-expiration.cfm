<cfsetting enablecfoutputonly="true" showdebugoutput="false" requesttimeout="120">
<cfcontent type="application/json; charset=utf-8">
<cfheader name="Cache-Control" value="no-store, no-cache, must-revalidate">
<cfscript>
response = {};
expectedToken = "";
providedToken = "";
limitValue = 100;
appDsn = "fpw";
expirationService = "";
runResult = {};

try {
  if (structKeyExists(application, "monitorToken")) {
    expectedToken = trim(toString(application.monitorToken));
  }
  if (structKeyExists(url, "token")) {
    providedToken = trim(toString(url.token));
  }
  if (!len(expectedToken) OR providedToken NEQ expectedToken) {
    writeOutput(serializeJSON({
      SUCCESS = false,
      ERROR = "UNAUTHORIZED",
      MESSAGE = "Unauthorized."
    }));
    return;
  }

  if (structKeyExists(url, "limit") AND isNumeric(url.limit) AND val(url.limit) GT 0) {
    limitValue = min(500, int(val(url.limit)));
  }
  if (structKeyExists(application, "dsn") AND len(trim(toString(application.dsn)))) {
    appDsn = trim(toString(application.dsn));
  }

  try {
    expirationService = createObject("component", "fpw.api.v1.PremiumTripAccessService").init(appDsn);
  } catch (any componentPathErr) {
    expirationService = createObject("component", "api.v1.PremiumTripAccessService").init(appDsn);
  }
  runResult = expirationService.processDueExpirations(limitValue);
  response = {
    SUCCESS = structKeyExists(runResult, "SUCCESS") ? runResult.SUCCESS : false,
    examined = structKeyExists(runResult, "examined") ? val(runResult.examined) : 0,
    expired = structKeyExists(runResult, "expired") ? val(runResult.expired) : 0,
    membership_overridden = structKeyExists(runResult, "membership_overridden") ? val(runResult.membership_overridden) : 0,
    already_ended = structKeyExists(runResult, "already_ended") ? val(runResult.already_ended) : 0,
    skipped = structKeyExists(runResult, "skipped") ? val(runResult.skipped) : 0,
    failed = structKeyExists(runResult, "failed") ? val(runResult.failed) : 0
  };
  writeOutput(serializeJSON(response));
} catch (any runnerErr) {
  writeLog(
    file = "fpw-single-trip-expiration",
    type = "error",
    text = "SINGLE_TRIP_EXPIRATION_RUNNER_FAILED code=SERVER_ERROR"
  );
  writeOutput(serializeJSON({
    SUCCESS = false,
    ERROR = "SERVER_ERROR",
    MESSAGE = "Server error."
  }));
}
</cfscript>
<cfsetting enablecfoutputonly="false">
