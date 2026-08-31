<cfsetting enablecfoutputonly="true" showdebugoutput="false" requesttimeout="120">
<cfcontent type="application/json; charset=utf-8">
<cfheader name="Cache-Control" value="no-store, no-cache, must-revalidate">
<cfscript>
response = {};
expectedToken = "";
providedToken = "";
limitValue = 100;
appDsn = "fpw";
reminderService = "";
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
    reminderService = createObject("component", "fpw.api.v1.DepartureReminderService").init(appDsn);
  } catch (any componentPathErr) {
    reminderService = createObject("component", "api.v1.DepartureReminderService").init(appDsn);
  }
  runResult = reminderService.processDueReminders(limitValue);
  response = {
    SUCCESS = structKeyExists(runResult, "SUCCESS") ? runResult.SUCCESS : false,
    examined = structKeyExists(runResult, "examined") ? val(runResult.examined) : 0,
    claimed = structKeyExists(runResult, "claimed") ? val(runResult.claimed) : 0,
    sent = structKeyExists(runResult, "sent") ? val(runResult.sent) : 0,
    failed = structKeyExists(runResult, "failed") ? val(runResult.failed) : 0,
    skipped = structKeyExists(runResult, "skipped") ? val(runResult.skipped) : 0,
    float_plan_ids = structKeyExists(runResult, "float_plan_ids") ? runResult.float_plan_ids : []
  };
  writeOutput(serializeJSON(response));
} catch (any runnerErr) {
  writeLog(
    file = "fpw-departure-reminders",
    type = "error",
    text = "DEPARTURE_REMINDER_RUNNER_FAILED code=SERVER_ERROR"
  );
  writeOutput(serializeJSON({
    SUCCESS = false,
    ERROR = "SERVER_ERROR",
    MESSAGE = "Server error."
  }));
}
</cfscript>
<cfsetting enablecfoutputonly="false">
