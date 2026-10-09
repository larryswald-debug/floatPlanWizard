<cfsetting enablecfoutputonly="true" showdebugoutput="false" requesttimeout="120">
<cfcontent type="application/json; charset=utf-8">
<cfheader name="Cache-Control" value="no-store, no-cache, must-revalidate">
<cfscript>
expectedToken = "";
providedToken = "";
limitValue = 100;
appDsn = "fpw";
trackingService = "";

try {
  if (structKeyExists(application, "monitorToken")) {
    expectedToken = trim(toString(application.monitorToken));
  }
  if (structKeyExists(url, "token")) {
    providedToken = trim(toString(url.token));
  }
  if (!len(expectedToken) OR compare(providedToken, expectedToken) NEQ 0) {
    cfheader(statuscode=401);
    writeOutput(serializeJSON({
      SUCCESS = false,
      ERROR = "UNAUTHORIZED",
      MESSAGE = "Unauthorized."
    }));
    return;
  }

  if (structKeyExists(url, "limit")) {
    if (!reFind("^[1-9][0-9]{0,2}$", toString(url.limit)) OR val(url.limit) GT 500) {
      cfheader(statuscode=400);
      writeOutput(serializeJSON({
        SUCCESS = false,
        ERROR = "INVALID_LIMIT",
        MESSAGE = "limit must be an integer from 1 to 500."
      }));
      return;
    }
    limitValue = val(url.limit);
  }
  if (structKeyExists(application, "dsn") AND len(trim(toString(application.dsn)))) {
    appDsn = trim(toString(application.dsn));
  }

  try {
    trackingService = createObject("component", "fpw.api.v1.CompanionTrackingService").init(appDsn);
  } catch (any componentPathErr) {
    trackingService = createObject("component", "api.v1.CompanionTrackingService").init(appDsn);
  }
  // Service returns counts/reason codes only. No bearer or raw location payload is logged.
  runResult = trackingService.runMaintenance(limitValue);
  if (!structKeyExists(runResult, "SUCCESS") OR !runResult.SUCCESS) {
    cfheader(statuscode=500);
  }
  writeOutput(serializeJSON(runResult));
} catch (any runnerErr) {
  writeLog(
    file = "fpw-companion-tracking",
    type = "error",
    text = "COMPANION_TRACKING_MAINTENANCE_FAILED code=SERVER_ERROR"
  );
  cfheader(statuscode=500);
  writeOutput(serializeJSON({
    SUCCESS = false,
    ERROR = "SERVER_ERROR",
    MESSAGE = "Server error."
  }));
}
</cfscript>
<cfsetting enablecfoutputonly="false">
