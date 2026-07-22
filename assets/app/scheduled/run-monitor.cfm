<cfsetting enablecfoutputonly="true" showdebugoutput="false">
<cfcontent type="application/json; charset=utf-8">
<cfheader name="Cache-Control" value="no-store, no-cache, must-revalidate">
<cfscript>
response = {};
expectedToken = "";
providedToken = "";
limitValue = 100;
appDsn = "fpw";
monitoringService = "";
runResult = {};

try {
  if (structKeyExists(application, "monitorToken")) {
    expectedToken = trim(toString(application.monitorToken));
  }

  if (structKeyExists(url, "token")) {
    providedToken = trim(toString(url.token));
  }

  if (!len(expectedToken) OR providedToken NEQ expectedToken) {
    response = {
      SUCCESS = false,
      ERROR = "UNAUTHORIZED",
      MESSAGE = "Unauthorized."
    };
    writeOutput(serializeJSON(response));
    return;
  }

  if (structKeyExists(url, "limit") AND isNumeric(url.limit) AND val(url.limit) GT 0) {
    limitValue = int(val(url.limit));
  }

  if (structKeyExists(application, "dsn") AND len(trim(toString(application.dsn)))) {
    appDsn = trim(toString(application.dsn));
  }

  try {
    monitoringService = createObject("component", "fpw.api.v1.monitor").init(appDsn);
  } catch (any ePath) {
    monitoringService = createObject("component", "api.v1.monitor").init(appDsn);
  }

  runResult = monitoringService.evaluateDueMonitoringRows(limitValue);
  response = {
    SUCCESS = structKeyExists(runResult, "SUCCESS") ? runResult.SUCCESS : false,
    PROCESSED_COUNT = structKeyExists(runResult, "PROCESSED_COUNT") ? runResult.PROCESSED_COUNT : 0,
    FLOAT_PLAN_IDS = structKeyExists(runResult, "FLOAT_PLAN_IDS") ? runResult.FLOAT_PLAN_IDS : []
  };
  writeOutput(serializeJSON(response));
} catch (any err) {
  writeLog(file = "fpw-monitor", type = "error", text = "scheduled run-monitor failed: " & err.message & " " & err.detail);
  response = {
    SUCCESS = false,
    ERROR = "SERVER_ERROR",
    MESSAGE = "Server error."
  };
  writeOutput(serializeJSON(response));
}
</cfscript>
<cfsetting enablecfoutputonly="false">
