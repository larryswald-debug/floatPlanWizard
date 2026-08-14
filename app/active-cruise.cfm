<cfinclude template="../includes/require_auth.cfm">
<cfscript>
  function fpwV2HookValue(required string key) {
    var raw = "";
    if (structKeyExists(url, key) AND isSimpleValue(url[key])) {
      raw = trim(url[key] & "");
    }
    return reReplace(raw, "[\r\n]+", " ", "all");
  }

  function fpwV2ResolveSessionUserId() {
    if (NOT structKeyExists(session, "user") OR NOT isStruct(session.user)) {
      return 0;
    }
    if (structKeyExists(session.user, "userId") AND isNumeric(session.user.userId)) {
      return val(session.user.userId);
    }
    if (structKeyExists(session.user, "id") AND isNumeric(session.user.id)) {
      return val(session.user.id);
    }
    if (structKeyExists(session.user, "USERID") AND isNumeric(session.user.USERID)) {
      return val(session.user.USERID);
    }
    return 0;
  }

  function fpwV2ResolveDatasource() {
    if (structKeyExists(application, "dsn")) {
      var appDsn = trim(toString(application.dsn));
      if (len(appDsn)) {
        return appDsn;
      }
    }
    return "fpw";
  }

  function fpwV2ResolveBasePath() {
    var basePath = "";
    var scriptPath = "";

    if (structKeyExists(request, "fpwBase") AND NOT isNull(request.fpwBase)) {
      basePath = trim(toString(request.fpwBase));
    } else if (structKeyExists(cgi, "script_name")) {
      scriptPath = trim(toString(cgi.script_name));
      basePath = getDirectoryFromPath(scriptPath);
      basePath = reReplace(basePath, "/app/?$", "");
      basePath = reReplace(basePath, "/$", "");
    }
    if (basePath EQ "/") {
      basePath = "";
    }
    if (len(basePath) AND left(basePath, 1) NEQ "/") {
      basePath = "/" & basePath;
    }
    return basePath;
  }

  function fpwV2ResolveCurrentActiveCruiseGroup(required numeric userId) {
    var result = {
      SUCCESS = false,
      HAS_CURRENT_GROUP = false,
      IS_ACTIVE = false,
      MESSAGE = "No active trip is available."
    };
    var floatPlanComponent = "";

    if (arguments.userId LTE 0) {
      result.MESSAGE = "A valid owner is required.";
      return result;
    }

    try {
      floatPlanComponent = createObject("component", "fpw.api.v1.floatplan");
    } catch (any floatPlanPathErr) {
      floatPlanComponent = createObject("component", "api.v1.floatplan");
    }

    result = floatPlanComponent.resolveCurrentRouteFloatPlanGroup(arguments.userId);
    if (!isStruct(result)) {
      result = {
        SUCCESS = false,
        HAS_CURRENT_GROUP = false,
        IS_ACTIVE = false,
        MESSAGE = "No active trip is available."
      };
    }
    return result;
  }

  function fpwV2LoadActiveCruiseModel(required numeric userId, required numeric floatPlanId, required string datasource) {
    try {
      return createObject("component", "fpw.api.v1.ActiveCruiseViewModelService")
        .init(arguments.datasource)
        .getActiveCruiseViewModel(arguments.userId, arguments.floatPlanId);
    } catch (any viewModelPathErr) {
      return createObject("component", "api.v1.ActiveCruiseViewModelService")
        .init(arguments.datasource)
        .getActiveCruiseViewModel(arguments.userId, arguments.floatPlanId);
    }
  }

  function fpwV2Get(required struct source, required string key, any defaultValue="") {
    if (structKeyExists(arguments.source, arguments.key) AND !isNull(arguments.source[arguments.key])) {
      return arguments.source[arguments.key];
    }
    return arguments.defaultValue;
  }

  function fpwV2Text(any value="", string fallback="--") {
    if (isNull(arguments.value)) {
      return arguments.fallback;
    }
    if (isSimpleValue(arguments.value)) {
      var textValue = trim(toString(arguments.value));
      if (len(textValue)) {
        return textValue;
      }
    }
    return arguments.fallback;
  }

  function fpwV2Number(any value="", string suffix="") {
    if (!isNumeric(arguments.value)) {
      return "--";
    }
    return numberFormat(val(arguments.value), "0.0") & arguments.suffix;
  }

  function fpwV2Minutes(any value="") {
    if (!isNumeric(arguments.value)) {
      return "--";
    }
    return numberFormat(val(arguments.value), "0") & " min";
  }

  function fpwV2Percent(any value="") {
    if (!isNumeric(arguments.value)) {
      return "--";
    }
    return numberFormat(val(arguments.value), "0.0") & "%";
  }

  function fpwV2ParseTripDateTime(any value="") {
    var raw = "";
    var normalized = "";
    if (isDate(arguments.value)) {
      raw = dateTimeFormat(arguments.value, "yyyy-mm-dd HH:nn:ss");
    } else if (!isSimpleValue(arguments.value)) {
      return "";
    } else {
      raw = trim(toString(arguments.value));
    }
    if (!len(raw)) {
      return "";
    }
    normalized = replace(raw, "T", " ", "one");
    normalized = reReplace(normalized, "Z$", "", "one");
    normalized = reReplace(normalized, "([+-][0-9]{2}:?[0-9]{2})$", "", "one");
    normalized = reReplace(normalized, "\.[0-9]+$", "", "one");
    if (reFind("^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}$", normalized)) {
      normalized &= ":00";
    }
    if (!reFind("^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$", normalized)) {
      return "";
    }
    if (!isDate(normalized)) {
      return "";
    }
    return parseDateTime(normalized);
  }

  function fpwV2TripDateTimeLabel(any value="", string timezone="UTC", string fallback="Not available", boolean compact=false) {
    var tripTime = fpwV2ParseTripDateTime(arguments.value);
    var tzId = trim(arguments.timezone);
    var timeZoneLabel = "";
    var localLabel = "";
    if (!isDate(tripTime)) {
      return arguments.fallback;
    }
    if (!len(tzId)) {
      tzId = "UTC";
    }
    try {
      timeZoneLabel = fpwV2TripTimezoneLabel(tzId, tripTime);
      if (arguments.compact) {
        return dateTimeFormat(tripTime, "HH:nn", tzId) & " " & timeZoneLabel;
      }
      localLabel = dateTimeFormat(tripTime, "mmmm d, yyyy HH:nn", tzId);
      return localLabel & " " & timeZoneLabel;
    } catch (any zonedLabelErr) {
      timeZoneLabel = fpwV2TripTimezoneLabel(tzId, tripTime);
      if (arguments.compact) {
        return timeFormat(tripTime, "HH:mm") & " " & timeZoneLabel;
      }
      return dateFormat(tripTime, "mmmm d, yyyy") & " " & timeFormat(tripTime, "HH:mm") & " " & timeZoneLabel;
    }
  }

  function fpwV2TripTimezoneLabel(string timezone="UTC", any referenceValue="") {
    var tzId = trim(arguments.timezone);
    if (!len(tzId)) {
      tzId = "UTC";
    }
    return tzId;
  }

  function fpwV2TripScheduleDateTimeLabel(any value="", string timezone="UTC", string fallback="Not available", boolean compact=false) {
    var raw = "";
    var datePart = "";
    var timePart = "";
    var dateParts = [];
    var timeParts = [];
    var monthNames = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];
    var yearValue = 0;
    var monthValue = 0;
    var dayValue = 0;
    var hourValue = 0;
    var minuteValue = 0;
    var timeLabel = "";
    var zoneLabel = fpwV2TripTimezoneLabel(arguments.timezone, "");

    if (!isSimpleValue(arguments.value)) {
      return arguments.fallback;
    }
    raw = trim(toString(arguments.value));
    if (reFind("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}", raw)) {
      raw = replace(raw, "T", " ", "one");
    }
    if (reFind("^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}$", raw)) {
      raw &= ":00";
    }
    if (!reFind("^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$", raw)) {
      return arguments.fallback;
    }

    datePart = listFirst(raw, " ");
    timePart = listGetAt(raw, 2, " ");
    dateParts = listToArray(datePart, "-");
    timeParts = listToArray(timePart, ":");
    if (arrayLen(dateParts) NEQ 3 OR arrayLen(timeParts) LT 2) {
      return arguments.fallback;
    }

    yearValue = val(dateParts[1]);
    monthValue = val(dateParts[2]);
    dayValue = val(dateParts[3]);
    hourValue = val(timeParts[1]);
    minuteValue = val(timeParts[2]);
    if (yearValue LT 1000 OR monthValue LT 1 OR monthValue GT 12 OR dayValue LT 1 OR dayValue GT 31 OR hourValue LT 0 OR hourValue GT 23 OR minuteValue LT 0 OR minuteValue GT 59) {
      return arguments.fallback;
    }

    timeLabel = numberFormat(hourValue, "00") & ":" & numberFormat(minuteValue, "00");
    if (arguments.compact) {
      return timeLabel & " " & zoneLabel;
    }
    return monthNames[monthValue] & " " & dayValue & ", " & yearValue & " " & timeLabel & " " & zoneLabel;
  }

  function fpwV2TripLocalTimeLabel(any value="", string timezone="UTC", any referenceValue="", string fallback="Not available") {
    var raw = "";
    var normalized = "";
    var parts = [];
    var hourValue = 0;
    var minuteValue = 0;
    if (isDate(arguments.value)) {
      normalized = timeFormat(arguments.value, "HH:nn:ss");
    } else if (isSimpleValue(arguments.value)) {
      raw = trim(toString(arguments.value));
      normalized = listFirst(raw, " ");
    }
    if (!len(normalized)) {
      normalized = "08:00:00";
    }
    if (!reFind("^[0-9]{1,2}:[0-9]{2}(:[0-9]{2})?$", normalized)) {
      return arguments.fallback;
    }
    parts = listToArray(normalized, ":");
    hourValue = val(parts[1]);
    minuteValue = val(parts[2]);
    if (hourValue LT 0 OR hourValue GT 23 OR minuteValue LT 0 OR minuteValue GT 59) {
      return arguments.fallback;
    }
    return numberFormat(hourValue, "00") & ":" & numberFormat(minuteValue, "00") & " " & fpwV2TripTimezoneLabel(arguments.timezone, arguments.referenceValue);
  }

  function fpwV2Json(any value={}) {
    try {
      return serializeJSON(arguments.value);
    } catch (any jsonErr) {
      return "{}";
    }
  }

  function fpwV2JsonForScript(any value={}) {
    return replace(fpwV2Json(arguments.value), "</", "<\/", "all");
  }

  function fpwV2BoolLabel(any value=false) {
    if (isBoolean(arguments.value) AND arguments.value) {
      return "enabled";
    }
    return "disabled";
  }

  function fpwV2StateClass(any value="") {
    var stateValue = lCase(trim(toString(arguments.value)));
    if (listFindNoCase("late,missed,escalated,assistance_needed,unknown_error,expired_access", stateValue)) {
      return "is-alert";
    }
    if (listFindNoCase("paused_overnight,paused_delayed", stateValue)) {
      return "is-paused";
    }
    if (listFindNoCase("underway,arrived,closed", stateValue)) {
      return "is-active";
    }
    return "is-scheduled";
  }

  function fpwV2LegClass(required struct leg) {
    var stateValue = lCase(trim(toString(fpwV2Get(arguments.leg, "state"))));
    if (stateValue EQ "current") {
      return "timeline-row-current";
    }
    if (stateValue EQ "completed") {
      return "timeline-row-completed";
    }
    return "timeline-row-future";
  }

  function fpwV2WarningCount(required struct model) {
    if (structKeyExists(arguments.model, "warnings") AND isArray(arguments.model.warnings)) {
      return arrayLen(arguments.model.warnings);
    }
    return 0;
  }

  function fpwV2ActionEnabled(required struct actionModel) {
    return structKeyExists(arguments.actionModel, "enabled") AND isBoolean(arguments.actionModel.enabled) AND arguments.actionModel.enabled;
  }

  activeCruiseV2UserId = fpwV2ResolveSessionUserId();
  activeCruiseV2Datasource = fpwV2ResolveDatasource();
  activeCruiseV2BasePath = fpwV2ResolveBasePath();
  activeCruiseV2RequestedFloatPlanId = 0;
  activeCruiseV2FloatPlanId = 0;
  activeCruiseV2RouteInstanceId = 0;
  activeCruiseV2AccessValid = false;
  activeCruiseV2ExpiredAccess = false;
  activeCruiseV2RequestedModelLoaded = false;
  activeCruiseV2AccessMessage = "Active Cruise V2 is available only for your current active route-backed float plan.";
  activeCruiseV2AccessDetail = "";
  activeCruiseV2CurrentGroup = {};
  activeCruiseV2Model = {};
  activeCruiseV2RouteProgressSummary = {};
  activeCruiseV2CurrentLegFuel = {};

  if (isNumeric(fpwV2HookValue("floatPlanId"))) {
    activeCruiseV2RequestedFloatPlanId = val(fpwV2HookValue("floatPlanId"));
  }

  if (activeCruiseV2UserId LTE 0) {
    activeCruiseV2AccessMessage = "Sign in to view Active Cruise V2.";
    activeCruiseV2AccessDetail = "The V2 shell uses the authenticated session user as its access authority.";
  } else {
    if (activeCruiseV2RequestedFloatPlanId GT 0) {
      activeCruiseV2Model = fpwV2LoadActiveCruiseModel(
        activeCruiseV2UserId,
        activeCruiseV2RequestedFloatPlanId,
        activeCruiseV2Datasource
      );
      activeCruiseV2RequestedModelLoaded = true;
      activeCruiseV2ExpiredAccess = (
        isStruct(activeCruiseV2Model)
        AND fpwV2Text(fpwV2Get(activeCruiseV2Model, "errorCode"), "") EQ "TRIP_ACCESS_EXPIRED"
      );
      if (activeCruiseV2ExpiredAccess) {
        activeCruiseV2FloatPlanId = activeCruiseV2RequestedFloatPlanId;
        activeCruiseV2AccessMessage = fpwV2Text(
          fpwV2Get(activeCruiseV2Model, "message"),
          "This Premium Trip has reached its 21-day access limit."
        );
        activeCruiseV2AccessDetail = "Active Cruise controls are unavailable because this trip's Premium operational access has ended.";
      }
    }

    if (!activeCruiseV2ExpiredAccess) {
      activeCruiseV2CurrentGroup = fpwV2ResolveCurrentActiveCruiseGroup(activeCruiseV2UserId);
      if (
        isStruct(activeCruiseV2CurrentGroup)
        AND structKeyExists(activeCruiseV2CurrentGroup, "ERROR")
        AND trim(toString(activeCruiseV2CurrentGroup.ERROR)) EQ "MULTIPLE_ACTIVE_GROUPS"
      ) {
        activeCruiseV2AccessMessage = "Active Cruise V2 is unavailable because more than one active route/float-plan group exists.";
        activeCruiseV2AccessDetail = "Resolve the extra active group before using this page.";
      } else if (!structKeyExists(activeCruiseV2CurrentGroup, "SUCCESS") OR !activeCruiseV2CurrentGroup.SUCCESS OR !activeCruiseV2CurrentGroup.IS_ACTIVE) {
        activeCruiseV2AccessMessage = "No active trip is available for this account.";
        activeCruiseV2AccessDetail = "Active Cruise V2 only loads the current active route-backed float plan.";
      } else {
        activeCruiseV2FloatPlanId = val(structKeyExists(activeCruiseV2CurrentGroup, "FLOATPLANID") ? activeCruiseV2CurrentGroup.FLOATPLANID : 0);
        activeCruiseV2RouteInstanceId = val(structKeyExists(activeCruiseV2CurrentGroup, "ROUTE_INSTANCE_ID") ? activeCruiseV2CurrentGroup.ROUTE_INSTANCE_ID : 0);

        if (activeCruiseV2RequestedFloatPlanId GT 0 AND activeCruiseV2RequestedFloatPlanId NEQ activeCruiseV2FloatPlanId) {
          activeCruiseV2AccessMessage = "This Active Cruise V2 link does not match your current active trip.";
          activeCruiseV2AccessDetail = "Open Active Cruise V2 from the canonical active float plan only.";
        } else if (activeCruiseV2RouteInstanceId LTE 0) {
          activeCruiseV2AccessMessage = "The current active float plan is missing its route link.";
          activeCruiseV2AccessDetail = "Active Cruise V2 requires a route-linked active float plan.";
        } else {
          if (!activeCruiseV2RequestedModelLoaded) {
            activeCruiseV2Model = fpwV2LoadActiveCruiseModel(
              activeCruiseV2UserId,
              activeCruiseV2FloatPlanId,
              activeCruiseV2Datasource
            );
          }
          activeCruiseV2AccessValid = (
            isStruct(activeCruiseV2Model)
            AND structKeyExists(activeCruiseV2Model, "success")
            AND activeCruiseV2Model.success EQ true
          );
          if (!activeCruiseV2AccessValid) {
            activeCruiseV2ExpiredAccess = (
              isStruct(activeCruiseV2Model)
              AND fpwV2Text(fpwV2Get(activeCruiseV2Model, "errorCode"), "") EQ "TRIP_ACCESS_EXPIRED"
            );
            activeCruiseV2AccessMessage = fpwV2Text(
              fpwV2Get(activeCruiseV2Model, "message"),
              "Active Cruise V2 could not be loaded for this trip."
            );
            activeCruiseV2AccessDetail = activeCruiseV2ExpiredAccess
              ? "Active Cruise controls are unavailable because this trip's Premium operational access has ended."
              : "Active Cruise controls remain unavailable until the active trip model can be loaded.";
          }
        }
      }
    }
  }

  if (!isStruct(activeCruiseV2Model) OR !structCount(activeCruiseV2Model)) {
    activeCruiseV2Model = {
      success = false,
      message = activeCruiseV2AccessMessage,
      errorCode = "",
      generatedAtUtc = "",
      tripState = "unknown_error",
      motionState = "unknown",
      safetyState = "normal",
      tripAccess = {},
      displayAuthority = {
        primary = "unavailable",
        routeTimeline = "unavailable",
        monitoring = "unavailable",
        warnings = []
      },
      floatPlan = {},
      route = {},
      currentLeg = {},
      routeTimeline = { available = false, legs = [], warnings = [] },
      monitoring = { available = false },
      checkIn = { allowedStatusOptions = [], validationMessages = {} },
      actions = {},
      floatPlanInfo = {},
      contacts = { items = [], passengers = [] },
      warnings = []
    };
  }

  if (
    structKeyExists(activeCruiseV2Model, "routeTimeline")
    AND isStruct(activeCruiseV2Model.routeTimeline)
    AND structKeyExists(activeCruiseV2Model.routeTimeline, "summary")
    AND isStruct(activeCruiseV2Model.routeTimeline.summary)
  ) {
    activeCruiseV2RouteProgressSummary = activeCruiseV2Model.routeTimeline.summary;
  }

  if (
    structKeyExists(activeCruiseV2Model, "currentLeg")
    AND isStruct(activeCruiseV2Model.currentLeg)
    AND structKeyExists(activeCruiseV2Model.currentLeg, "fuel")
    AND isStruct(activeCruiseV2Model.currentLeg.fuel)
  ) {
    activeCruiseV2CurrentLegFuel = activeCruiseV2Model.currentLeg.fuel;
  }
</cfscript>
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Active Cruise V2</title>
  <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" integrity="sha256-p4NxAoJBhIIN+hmNHrzRCf9tD/miZyoHS5obTRR9BMY=" crossorigin="">
<link rel="stylesheet" href="<cfoutput>#activeCruiseV2BasePath#</cfoutput>/assets/css/layout.css?v=20260620-page-width">
<link rel="stylesheet" href="<cfoutput>#activeCruiseV2BasePath#</cfoutput>/assets/css/top-nav.css?v=20260814-featured-guides-layout-v1">
  <cfinclude template="../includes/analytics_clarity.cfm">
  <style>
    :root {
      color-scheme: dark;
      --page-bg: #07151c;
      --surface: #0e2029;
      --surface-2: #132b35;
      --surface-3: #18313d;
      --line: #254653;
      --line-strong: #3b6673;
      --text: #eff7fa;
      --muted: #a7bac2;
      --quiet: #78909a;
      --teal: #2fb8a9;
      --amber: #e9b65c;
      --red: #ec7f78;
      --green: #8bcf9b;
    }
    * { box-sizing: border-box; }
    body {
      margin: 0;
      font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      background: var(--page-bg);
      color: var(--text);
      line-height: 1.45;
    }
    main {
      width: min(var(--fpw-wide-max, 1320px), calc(100% - (var(--fpw-page-gutter, 32px) * 2)));
      margin: 0 auto;
      padding: 22px 0 42px;
    }
    h1, h2, h3 { margin: 0; }
    h1 {
      font-size: clamp(1.7rem, 3vw, 2.4rem);
      line-height: 1.1;
      letter-spacing: 0;
    }
    h2 {
      color: var(--muted);
      font-size: .78rem;
      font-weight: 800;
      letter-spacing: .08em;
      text-transform: uppercase;
    }
    h3 {
      font-size: 1rem;
      line-height: 1.25;
    }
    p {
      margin: .35rem 0;
      color: var(--muted);
    }
    code {
      color: var(--text);
      background: rgba(255, 255, 255, .05);
      border: 1px solid rgba(255, 255, 255, .08);
      border-radius: 4px;
      padding: 1px 5px;
    }
    .page-top {
      display: grid;
      gap: 14px;
      margin-bottom: 16px;
      border-bottom: 1px solid var(--line);
      padding-bottom: 16px;
    }
    .identity-strip {
      display: grid;
      grid-template-columns: 1.3fr repeat(4, minmax(120px, .5fr));
      gap: 10px;
      align-items: stretch;
    }
    .identity-cell,
    .metric,
    .section,
    .timeline,
    .warning-panel {
      border: 1px solid var(--line);
      border-radius: 4px;
      background: var(--surface);
    }
    .identity-cell {
      min-height: 66px;
      padding: 10px 12px;
    }
    .identity-label,
    .metric-label,
    .field-label {
      color: var(--quiet);
      font-size: .72rem;
      font-weight: 800;
      letter-spacing: .08em;
      text-transform: uppercase;
    }
    .identity-value,
    .metric-value,
    .field-value {
      color: var(--text);
      overflow-wrap: anywhere;
    }
    .identity-value {
      margin-top: 6px;
      font-size: .95rem;
      font-weight: 700;
    }
    .layout {
      display: grid;
      grid-template-columns: minmax(0, 1.65fr) minmax(320px, .9fr);
      gap: 14px;
    }
    .supporting-grid {
      display: grid;
      grid-template-columns: minmax(0, 1fr) minmax(0, 1fr);
      gap: 14px;
      margin-top: 14px;
    }
    .left-stack,
    .right-stack,
    .supporting-stack {
      display: grid;
      gap: 14px;
    }
    .hero {
      border: 1px solid var(--line-strong);
      border-radius: 4px;
      background: var(--surface-2);
      padding: 18px;
    }
    .hero-main {
      display: grid;
      grid-template-columns: minmax(0, 1fr) auto;
      gap: 14px;
      align-items: start;
    }
    .state-pill,
    .authority-pill,
    .leg-pill {
      display: inline-flex;
      width: fit-content;
      align-items: center;
      justify-content: center;
      border: 1px solid var(--line-strong);
      border-radius: 999px;
      min-height: 30px;
      padding: 3px 11px;
      background: rgba(255, 255, 255, .04);
      font-weight: 800;
    }
    .state-pill {
      min-width: 118px;
      color: var(--text);
      text-transform: uppercase;
      letter-spacing: .06em;
      font-size: .8rem;
    }
    .state-pill.is-active { border-color: var(--teal); color: var(--teal); }
    .state-pill.is-scheduled { border-color: var(--amber); color: var(--amber); }
    .state-pill.is-paused { border-color: var(--muted); color: var(--muted); }
    .state-pill.is-alert { border-color: var(--red); color: var(--red); }
    .hero-title {
      margin-top: 8px;
      max-width: 780px;
    }
    .hero-subtitle {
      margin-top: 10px;
      max-width: 780px;
    }
    .hero-grid {
      display: grid;
      grid-template-columns: repeat(3, minmax(0, 1fr));
      gap: 10px;
      margin-top: 16px;
    }
    .metric {
      padding: 12px;
      min-height: 82px;
    }
    .metric-value {
      margin-top: 6px;
      font-size: 1.25rem;
      font-weight: 800;
    }
    .metric-note {
      color: var(--muted);
      margin-top: 4px;
      font-size: .86rem;
    }
    .section,
    .warning-panel {
      padding: 16px;
    }
    .section-header {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 12px;
      margin-bottom: 13px;
    }
    .field-grid {
      display: grid;
      grid-template-columns: repeat(2, minmax(0, 1fr));
      gap: 10px;
    }
    .field {
      border-top: 1px solid var(--line);
      padding-top: 9px;
    }
    .field-value {
      margin-top: 4px;
      font-weight: 700;
    }
    .detail-list,
    .contact-list,
    .log-list {
      display: grid;
      gap: 8px;
    }
    .detail-row {
      display: grid;
      grid-template-columns: minmax(110px, .38fr) minmax(0, 1fr);
      gap: 10px;
      border-top: 1px solid var(--line);
      padding-top: 8px;
    }
    .detail-row:first-child {
      border-top: 0;
      padding-top: 0;
    }
    .contact-item,
    .log-item,
    .panel-note {
      border: 1px solid var(--line);
      border-radius: 4px;
      background: rgba(255, 255, 255, .03);
      padding: 10px;
    }
    .panel-note.is-warning {
      border-color: rgba(233, 182, 92, .55);
      background: rgba(233, 182, 92, .06);
    }
    .panel-note.is-success {
      border-color: rgba(139, 207, 155, .55);
      color: var(--green);
    }
    .panel-note.is-error {
      border-color: rgba(236, 127, 120, .55);
      color: var(--red);
    }
    .ac-weather-command-panel {
      display: grid;
      gap: 14px;
      margin-top: 16px;
      padding: 16px;
    }
    .weather-lookup-layout,
    .ac-weather-command-header,
    .ac-weather-command-controls,
    .ac-weather-command-footer,
    .weather-choice-row {
      display: flex;
      flex-wrap: wrap;
      align-items: center;
    }
    .weather-lookup-layout {
      gap: 14px;
      justify-content: space-between;
    }
    .ac-weather-command-header {
      gap: 14px;
      justify-content: space-between;
      inline-size: 100%;
    }
    .ac-weather-command-title {
      display: inline-flex;
      align-items: center;
      gap: 10px;
      min-inline-size: 160px;
    }
    .ac-weather-command-title h3 {
      margin: 0;
    }
    .ac-weather-command-icon {
      color: var(--blue);
      font-size: 1.35rem;
      line-height: 1;
    }
    .weather-lookup-form,
    .ac-weather-command-controls {
      display: flex;
      flex-wrap: wrap;
      gap: 10px;
      align-items: center;
      justify-content: flex-end;
    }
    .ac-weather-control-label {
      color: var(--muted);
      font-size: .75rem;
      font-weight: 800;
      letter-spacing: .14em;
      text-transform: uppercase;
    }
    .weather-choice-row {
      border: 1px solid var(--line);
      border-radius: 999px;
      padding: 8px 10px;
    }
    .weather-choice,
    .ac-weather-status-chip {
      display: inline-flex;
      gap: 8px;
      align-items: center;
      font-weight: 700;
      color: var(--text);
    }
    .weather-choice input {
      inline-size: 16px;
      block-size: 16px;
    }
    .ac-weather-command-btn {
      min-height: 40px;
      padding: 9px 14px;
    }
    .ac-weather-status-chip {
      border: 1px solid var(--line);
      border-radius: 999px;
      background: rgba(255, 255, 255, .03);
      min-height: 40px;
      padding: 8px 12px;
      color: var(--muted);
      white-space: nowrap;
    }
    .ac-weather-summary-row {
      display: flex;
      flex-wrap: wrap;
      gap: 8px 16px;
      color: var(--muted);
      font-size: .9rem;
    }
    .ac-weather-panel--not-checked .ac-weather-summary-row,
    .ac-weather-panel--not-checked .weather-result,
    .ac-weather-panel--not-checked .ac-weather-command-footer,
    .ac-weather-panel--loading .ac-weather-summary-row,
    .ac-weather-panel--loading .weather-result,
    .ac-weather-panel--loading .ac-weather-command-footer,
    .ac-weather-panel--error:not(.ac-weather-panel--has-data) .ac-weather-summary-row,
    .ac-weather-panel--error:not(.ac-weather-panel--has-data) .weather-result,
    .ac-weather-panel--error:not(.ac-weather-panel--has-data) .ac-weather-command-footer {
      display: none !important;
    }
    .ac-weather-summary-row strong {
      color: var(--text);
      font-weight: 700;
    }
    .weather-result {
      display: grid;
      gap: 10px;
      grid-template-columns: repeat(6, minmax(0, 1fr));
    }
    .weather-result.is-empty .ac-weather-metric-value,
    .weather-result.is-empty .field-value {
      color: var(--muted);
    }
    .ac-weather-status-badge {
      min-height: 56px;
      display: flex;
      align-items: center;
      gap: 12px;
    }
    .ac-weather-panel--checked .ac-weather-status-badge {
      display: none;
    }
    .ac-weather-status-badge[aria-busy="true"] {
      border-color: rgba(67, 199, 255, .55);
    }
    .ac-weather-status-badge--loading {
      background:
        linear-gradient(90deg, rgba(67, 199, 255, .07), rgba(24, 242, 210, .12), rgba(67, 199, 255, .07));
      background-size: 200% 100%;
      animation: acWeatherBadgeShimmer 1.8s linear infinite;
    }
    .ac-weather-loader {
      display: none;
      inline-size: 18px;
      block-size: 18px;
      border: 2px solid rgba(210, 235, 255, .28);
      border-top-color: rgba(24, 242, 210, .95);
      border-radius: 999px;
      flex: 0 0 auto;
      animation: acWeatherSpin .9s linear infinite;
    }
    .ac-weather-status-badge--loading .ac-weather-loader {
      display: inline-block;
    }
    .ac-weather-status-text {
      color: inherit;
    }
    @keyframes acWeatherSpin {
      to { transform: rotate(360deg); }
    }
    @keyframes acWeatherBadgeShimmer {
      from { background-position: 200% 0; }
      to { background-position: -200% 0; }
    }
    .ac-weather-metric-tile {
      border: 1px solid var(--line);
      border-radius: 6px;
      background: rgba(255, 255, 255, .03);
      min-block-size: 92px;
      padding: 14px;
    }
    .ac-weather-metric-label {
      color: var(--muted);
      font-size: .72rem;
      font-weight: 800;
      letter-spacing: .12em;
      text-transform: uppercase;
    }
    .ac-weather-metric-value {
      display: block;
      margin-top: 12px;
      color: var(--text);
      font-size: .95rem;
      font-weight: 800;
      line-height: 1.2;
      letter-spacing: 0;
    }
    .ac-weather-command-footer {
      border-top: 1px solid var(--line);
      gap: 12px;
      justify-content: space-between;
      padding-top: 12px;
    }
    .ac-weather-applied-note {
      color: var(--muted);
      margin: 0;
    }
    .weather-alert-list,
    .weather-warning-list {
      display: grid;
      gap: 8px;
      margin-top: 10px;
    }
    @media (max-width: 1100px) {
      .weather-result {
        grid-template-columns: repeat(3, minmax(0, 1fr));
      }
    }
    @media (max-width: 680px) {
      .ac-weather-command-controls,
      .weather-lookup-form,
      .ac-weather-command-footer {
        align-items: stretch;
        flex-direction: column;
        inline-size: 100%;
      }
      .weather-choice-row,
      .ac-weather-command-btn,
      .ac-weather-status-chip {
        justify-content: center;
        inline-size: 100%;
      }
      .weather-result {
        grid-template-columns: repeat(2, minmax(0, 1fr));
      }
    }
    .map-overview {
      display: grid;
      gap: 10px;
    }
    .map-canvas {
      border: 1px solid var(--line);
      border-radius: 4px;
      background: #0b1c24;
      min-height: 340px;
      overflow: hidden;
      position: relative;
    }
    .map-leaflet-canvas {
      height: clamp(340px, 42vw, 520px);
    }
    #fpwActiveCruiseV2Map {
      width: 100%;
      height: 100%;
      min-height: inherit;
      background: #0b1c24;
    }
    .map-leaflet-canvas .leaflet-container {
      background: #0b1c24;
      color: #111827;
    }
    .map-leaflet-canvas .leaflet-control-layers,
    .map-leaflet-canvas .leaflet-control-zoom a,
    .map-leaflet-canvas .leaflet-control-attribution {
      color: #1f2937;
    }
    #fpwActiveCruiseV2Map .leaflet-control-layers-overlays input[type="checkbox"].leaflet-control-layers-selector,
    #fpwActiveCruiseV2FullMap .leaflet-control-layers-overlays input[type="checkbox"].leaflet-control-layers-selector {
      accent-color: #fff;
      color-scheme: light;
    }
    #fpwActiveCruiseV2Map .radar-opacity-control {
      background: rgba(255, 255, 255, 0.92);
      padding: 0.35rem 0.5rem;
      border-radius: 0.5rem;
      box-shadow: 0 4px 12px rgba(0,0,0,0.15);
      font-size: 0.7rem;
      min-width: 140px;
    }
    #fpwActiveCruiseV2Map .radar-opacity-control label {
      display: block;
      font-weight: 600;
      margin-bottom: 0.25rem;
      color: #1b1b1b;
    }
    #fpwActiveCruiseV2Map .radar-opacity-control input[type="range"] {
      width: 100%;
    }
    #fpwActiveCruiseV2Map .radar-opacity-control.is-disabled {
      opacity: 0.5;
      pointer-events: none;
    }
    .map-load-state {
      position: absolute;
      inset: 12px;
      z-index: 450;
      display: none;
      align-items: flex-start;
      justify-content: flex-start;
      pointer-events: none;
    }
    .map-load-state.is-visible {
      display: flex;
    }
    .map-load-state span {
      border: 1px solid rgba(37, 70, 83, .75);
      border-radius: 4px;
      background: rgba(7, 21, 28, .88);
      color: var(--text);
      padding: 8px 10px;
      font-size: .84rem;
      font-weight: 700;
    }
    .follow-pin,
    .follow-boat-marker {
      display: inline-flex;
      align-items: center;
      justify-content: center;
      width: 17px;
      height: 17px;
      border: 2px solid #ffffff;
      border-radius: 999px;
      box-shadow: 0 1px 4px rgba(0, 0, 0, .35);
    }
    .follow-pin.start { background: #22c55e; }
    .follow-pin.end { background: #2563eb; }
    .follow-pin.intermediate { background: #64748b; }
    .follow-boat-marker {
      background: #0ea5e9;
      border-color: #ffffff;
    }
    .map-summary-grid {
      display: grid;
      grid-template-columns: repeat(3, minmax(0, 1fr));
      gap: 8px;
    }
    .map-leg-list {
      border: 1px solid var(--line);
      border-radius: 4px;
      overflow: hidden;
    }
    .map-leg-row {
      display: grid;
      grid-template-columns: 42px minmax(0, 1fr) auto;
      gap: 8px;
      align-items: center;
      border-top: 1px solid var(--line);
      padding: 8px 10px;
    }
    .map-leg-row:first-child {
      border-top: 0;
    }
    .map-leg-order {
      color: var(--quiet);
      font-size: .78rem;
      font-weight: 800;
      letter-spacing: .06em;
      text-transform: uppercase;
    }
    .map-leg-route {
      overflow-wrap: anywhere;
      font-weight: 700;
    }
    .map-leg-meta {
      color: var(--muted);
      font-size: .82rem;
      white-space: nowrap;
    }
    .panel-subhead {
      color: var(--muted);
      font-size: .86rem;
      font-weight: 800;
      margin: 12px 0 6px;
    }
    .progress-track {
      height: 9px;
      border: 1px solid var(--line);
      background: rgba(255, 255, 255, .04);
      border-radius: 999px;
      overflow: hidden;
      margin-top: 10px;
    }
    .progress-fill {
      height: 100%;
      width: var(--progress-width, 0%);
      background: var(--teal);
    }
    .timeline {
      overflow: hidden;
    }
    .timeline-head {
      display: grid;
      grid-template-columns: minmax(0, 1fr) auto;
      gap: 12px;
      align-items: center;
      padding: 16px;
      border-bottom: 1px solid var(--line);
    }
    .timeline-body {
      overflow-x: auto;
    }
    table {
      width: 100%;
      border-collapse: collapse;
      font-size: .9rem;
    }
    th, td {
      border-bottom: 1px solid var(--line);
      padding: 10px;
      text-align: left;
      vertical-align: top;
    }
    th {
      color: var(--quiet);
      text-transform: uppercase;
      letter-spacing: .07em;
      font-size: .72rem;
    }
    tbody tr:last-child td { border-bottom: 0; }
    .timeline-row-current td {
      background: rgba(47, 184, 169, .1);
      border-top: 1px solid rgba(47, 184, 169, .35);
      border-bottom: 1px solid rgba(47, 184, 169, .35);
    }
    .timeline-row-completed td {
      color: var(--muted);
    }
    .timeline-row-future td {
      color: var(--text);
    }
    .route-pair {
      display: grid;
      gap: 2px;
    }
    .route-pair span {
      color: var(--muted);
      font-size: .82rem;
    }
    .empty-state {
      padding: 16px;
      color: var(--muted);
    }
    .status-line {
      display: flex;
      flex-wrap: wrap;
      gap: 8px;
      align-items: center;
    }
    .authority-pill {
      min-height: 26px;
      color: var(--muted);
      font-size: .78rem;
    }
    .warning-panel {
      border-color: rgba(233, 182, 92, .65);
      background: #1c1a14;
    }
    .warning-list {
      display: grid;
      gap: 9px;
      margin-top: 12px;
    }
    .warning-item {
      border: 1px solid rgba(233, 182, 92, .3);
      border-radius: 4px;
      padding: 10px;
      background: rgba(233, 182, 92, .06);
    }
    .warning-source {
      color: var(--quiet);
      margin-top: 3px;
      font-size: .82rem;
    }
    .captain-actions {
      display: grid;
      gap: 12px;
    }
    .action-group {
      display: grid;
      gap: 8px;
    }
    .action-row {
      display: grid;
      grid-template-columns: minmax(0, 1fr);
      gap: 4px;
    }
    .action-button {
      border: 1px solid var(--line);
      border-radius: 4px;
      background: var(--surface-3);
      color: var(--text);
      min-height: 38px;
      padding: 8px 10px;
      font: inherit;
      font-size: .88rem;
      font-weight: 700;
      text-align: left;
      cursor: pointer;
    }
    .action-button:hover:not(:disabled) {
      border-color: var(--teal);
      color: var(--teal);
    }
    .action-button:disabled {
      background: rgba(255, 255, 255, .03);
      color: var(--quiet);
      cursor: not-allowed;
    }
    .action-reason {
      color: var(--quiet);
      font-size: .8rem;
    }
    .checkin-note-input {
      width: 100%;
      min-height: 74px;
      resize: vertical;
      border: 1px solid var(--line);
      border-radius: 4px;
      background: #08161d;
      color: var(--text);
      padding: 8px 10px;
      font: inherit;
    }
    .action-feedback {
      border: 1px solid var(--line);
      border-radius: 4px;
      background: rgba(255, 255, 255, .04);
      color: var(--muted);
      min-height: 42px;
      padding: 10px;
      font-size: .86rem;
    }
    .action-feedback.is-success {
      border-color: rgba(139, 207, 155, .55);
      color: var(--green);
    }
    .action-feedback.is-error {
      border-color: rgba(236, 127, 120, .55);
      color: var(--red);
    }
    .timing-controls {
      display: grid;
      gap: 12px;
    }
    .timing-summary-grid,
    .timing-form-grid {
      display: grid;
      grid-template-columns: repeat(2, minmax(0, 1fr));
      gap: 10px;
    }
    .timing-form-grid {
      align-items: stretch;
    }
    .timing-control {
      border: 1px solid var(--line);
      border-radius: 4px;
      background: rgba(255, 255, 255, .03);
      padding: 12px;
    }
    .timing-control.is-wide {
      grid-column: 1 / -1;
    }
    .timing-inline {
      display: grid;
      grid-template-columns: minmax(0, 1fr) auto;
      gap: 10px;
      align-items: end;
      margin-top: 10px;
    }
    .timing-input {
      width: 100%;
      min-height: 38px;
      border: 1px solid var(--line);
      border-radius: 4px;
      background: #08161d;
      color: var(--text);
      padding: 8px 10px;
      font: inherit;
    }
    .timing-input:disabled {
      color: var(--quiet);
      background: rgba(255, 255, 255, .03);
      cursor: not-allowed;
    }
    pre {
      white-space: pre-wrap;
      overflow-wrap: anywhere;
      background: rgba(0, 0, 0, .25);
      border: 1px solid var(--line);
      border-radius: 4px;
      padding: 10px;
      color: var(--muted);
      margin: 8px 0 0;
    }
    .unavailable {
      border: 1px solid rgba(233, 182, 92, .65);
      border-radius: 4px;
      background: #1c1a14;
      padding: 18px;
    }

    /* AC-V2 visual parity: V1-derived presentation only. V2 model/actions remain the authority. */
    :root {
      --bg: #06111a;
      --bg2: #0a1824;
      --panel: rgba(11, 27, 39, 0.88);
      --panel-2: rgba(9, 22, 32, 0.96);
      --line: rgba(126, 184, 226, 0.14);
      --line-strong: rgba(126, 184, 226, 0.26);
      --text: #ebf6ff;
      --muted: #9fb9cb;
      --soft: #7e97aa;
      --accent: #43c7ff;
      --accent-2: #18f2d2;
      --accent-3: #ffc661;
      --good: #7df2b7;
      --warn: #ffc661;
      --alert: #ff7f7f;
      --shadow: 0 20px 60px rgba(0,0,0,0.38);
      --radius-xl: 28px;
      --radius-lg: 22px;
      --radius-md: 16px;
      --max: var(--fpw-wide-max, 1320px);
    }

    html { scroll-behavior: smooth; }
    body {
      font-family: Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      background:
        radial-gradient(circle at 10% 10%, rgba(24,242,210,0.06), transparent 0 22%),
        radial-gradient(circle at 90% 0%, rgba(67,199,255,0.09), transparent 0 26%),
        linear-gradient(180deg, #051018 0%, #07141e 40%, #091923 100%);
      min-height: 100vh;
    }
    a { color: inherit; text-decoration: none; }
    main.main {
      width: auto;
      margin: 0;
      padding: 22px 0 18px;
    }
    .shell {
      width: min(var(--max), calc(100% - (var(--fpw-page-gutter, 32px) * 2)));
      margin: 0 auto;
    }
    .topbar {
      position: sticky;
      top: 0;
      z-index: 50;
      backdrop-filter: blur(16px);
      background: rgba(5, 16, 24, 0.74);
      border-bottom: 1px solid rgba(126,184,226,0.1);
    }
    .topbar-inner {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 18px;
      padding: 14px 0;
    }
    .brand {
      display: flex;
      align-items: center;
      gap: 14px;
      min-width: 0;
    }
    .brand-mark {
      width: 44px;
      height: 44px;
      border-radius: 14px;
      display: grid;
      place-items: center;
      background: linear-gradient(145deg, rgba(67,199,255,0.18), rgba(24,242,210,0.14));
      border: 1px solid rgba(126,184,226,0.22);
      box-shadow: inset 0 1px 0 rgba(255,255,255,0.05), 0 10px 24px rgba(0,0,0,0.26);
      font-size: 1.2rem;
    }
    .brand-copy { min-width: 0; }
    .brand-title { font-weight: 800; letter-spacing: 0.02em; }
    .brand-sub { color: var(--muted); font-size: 0.86rem; margin-top: 2px; }
    .top-actions {
      display: flex;
      align-items: center;
      gap: 10px;
      flex-wrap: wrap;
      justify-content: flex-end;
    }
    .chip,
    .btn,
    .authority-pill,
    .state-pill,
    .leg-pill {
      border-radius: 999px;
      display: inline-flex;
      align-items: center;
      justify-content: center;
      gap: 8px;
      white-space: nowrap;
    }
    .chip {
      padding: 10px 14px;
      background: rgba(126,184,226,0.07);
      border: 1px solid rgba(126,184,226,0.14);
      color: var(--muted);
      font-size: 0.9rem;
      font-weight: 700;
    }
    .btn,
    .action-button {
      border: 0;
      cursor: pointer;
      font-weight: 800;
      font-size: 0.94rem;
      padding: 12px 18px;
      transition: 0.18s ease;
    }
    .btn:hover,
    .action-button:hover:not(:disabled) {
      transform: translateY(-1px);
    }
    .btn-primary {
      color: #041019;
      background: linear-gradient(135deg, var(--accent-2), var(--accent));
      box-shadow: 0 16px 32px rgba(67,199,255,0.18);
    }
    .btn-secondary,
    .action-button {
      color: var(--text);
      background: rgba(126,184,226,0.08);
      border: 1px solid rgba(126,184,226,0.18);
      border-radius: 999px;
      min-height: auto;
      text-align: center;
    }
    .action-button:disabled {
      background: rgba(126,184,226,0.05);
      color: var(--soft);
      cursor: not-allowed;
      opacity: .72;
    }
    .page-top { display: none; }
    .layout,
    .supporting-grid,
    .content-grid {
      display: grid;
      grid-template-columns: 1.2fr 0.8fr;
      gap: 18px;
      margin-bottom: 18px;
    }
    .left-stack,
    .right-stack,
    .supporting-stack,
    .stack {
      display: grid;
      gap: 18px;
    }
    .identity-strip {
      display: grid;
      grid-template-columns: repeat(5, minmax(0, 1fr));
      gap: 14px;
      margin-bottom: 18px;
    }
    .identity-cell,
    .metric,
    .section,
    .timeline,
    .warning-panel,
    .panel {
      background: var(--panel);
      border: 1px solid var(--line);
      border-radius: var(--radius-xl);
      box-shadow: var(--shadow);
      backdrop-filter: blur(16px);
    }
    .identity-cell,
    .metric {
      background: rgba(126,184,226,0.05);
      border: 1px solid rgba(126,184,226,0.12);
      border-radius: 18px;
      padding: 16px;
      min-height: 96px;
    }
    .identity-label,
    .metric-label,
    .field-label,
    .panel-subhead {
      display: block;
      color: var(--soft);
      font-size: 0.76rem;
      text-transform: uppercase;
      letter-spacing: 0.12em;
      margin-bottom: 8px;
      font-weight: 800;
    }
    .identity-value,
    .metric-value,
    .field-value {
      color: var(--text);
      font-weight: 800;
      line-height: 1.12;
      letter-spacing: -0.03em;
    }
    .identity-value,
    .metric-value {
      font-size: 1.35rem;
      margin-top: 0;
    }
    .metric-note {
      color: var(--muted);
      font-size: 0.88rem;
      line-height: 1.45;
      display: block;
      margin-top: 6px;
    }
    .hero {
      display: block;
      padding: 26px 26px 24px;
      position: relative;
      overflow: hidden;
      margin-bottom: 0;
      background:
        radial-gradient(circle at 0% 0%, rgba(67,199,255,0.08), transparent 0 24%),
        linear-gradient(180deg, rgba(255,255,255,0.025), rgba(255,255,255,0.01));
    }
    .hero-main {
      display: flex;
      justify-content: space-between;
      align-items: flex-start;
      gap: 18px;
    }
    .status-line {
      display: flex;
      flex-wrap: wrap;
      gap: 10px;
      align-items: center;
    }
    .state-pill {
      min-width: 170px;
      padding: 14px 18px;
      border-radius: 18px;
      background: rgba(125,242,183,0.08);
      border: 1px solid rgba(125,242,183,0.18);
      color: var(--good);
      text-align: center;
      font-size: 0.8rem;
      letter-spacing: 0.12em;
      text-transform: uppercase;
    }
    .state-pill.is-scheduled,
    .state-pill.is-paused {
      background: rgba(255,198,97,0.08);
      border-color: rgba(255,198,97,0.18);
      color: var(--warn);
    }
    .state-pill.is-alert {
      background: rgba(255,127,127,0.08);
      border-color: rgba(255,127,127,0.18);
      color: var(--alert);
    }
    .authority-pill,
    .leg-pill {
      padding: 9px 12px;
      border-radius: 999px;
      font-size: 0.78rem;
      text-transform: uppercase;
      letter-spacing: 0.1em;
      font-weight: 800;
      white-space: nowrap;
      background: rgba(67,199,255,0.1);
      color: var(--accent);
      border: 1px solid rgba(67,199,255,0.18);
    }
    .pace-header-label {
      color: var(--accent);
      font-size: 0.78rem;
      font-weight: 800;
      letter-spacing: 0.1em;
      text-transform: uppercase;
      white-space: nowrap;
    }
    .hero-title,
    h1 {
      margin: 14px 0 0;
      font-size: clamp(2rem, 4vw, 3.5rem);
      line-height: 0.96;
      letter-spacing: -0.045em;
    }
    .hero-main h1 {
      font-size: clamp(1rem, 2vw, 1.75rem);
      line-height: 1.08;
    }
    .hero-subtitle,
    .subline,
    .section-top p,
    p {
      color: var(--muted);
      font-size: 1.05rem;
      line-height: 1.65;
      margin-top: 14px;
    }
    .hero-grid,
    .header-stats {
      display: grid;
      grid-template-columns: repeat(3, minmax(0, 1fr));
      gap: 14px;
      margin-top: 18px;
      margin-bottom: 0;
    }
    .section,
    .timeline,
    .warning-panel,
    .section-card {
      padding: 22px;
      border-radius: var(--radius-xl);
    }
    .section-header,
    .section-top,
    .timeline-head {
      display: flex;
      justify-content: space-between;
      gap: 16px;
      align-items: flex-start;
      margin-bottom: 18px;
      padding: 0;
      border-bottom: 0;
    }
    h2,
    .section-header h2,
    .section-top h2 {
      margin: 0;
      color: var(--text);
      font-size: 1.28rem;
      letter-spacing: -0.03em;
      text-transform: none;
    }
    h3 {
      font-size: 1rem;
      letter-spacing: -0.02em;
    }
    .field-grid,
    .data-grid,
    .timing-summary-grid,
    .timing-form-grid,
    .map-summary-grid {
      display: grid;
      grid-template-columns: repeat(2, minmax(0, 1fr));
      gap: 12px;
    }
    .map-summary-grid { grid-template-columns: repeat(3, minmax(0, 1fr)); }
    .field,
    .data-item,
    .timing-control,
    .contact-item,
    .log-item,
    .panel-note,
    .action-row,
    .detail-row {
      padding: 14px;
      border-radius: 16px;
      background: rgba(255,255,255,0.02);
      border: 1px solid rgba(126,184,226,0.08);
    }
    .field {
      border-top: 1px solid rgba(126,184,226,0.08);
    }
    .detail-row {
      display: grid;
      grid-template-columns: minmax(140px, .38fr) minmax(0, 1fr);
      gap: 12px;
      border-top: 1px solid rgba(126,184,226,0.08);
    }
    .progress-track,
    .bar-shell {
      width: 100%;
      height: 14px;
      border-radius: 999px;
      background: rgba(126,184,226,0.1);
      overflow: hidden;
      border: 1px solid rgba(126,184,226,0.12);
      margin: 14px 0;
    }
    .progress-fill,
    .bar-fill {
      height: 100%;
      width: var(--progress-width, 0%);
      border-radius: 999px;
      background: linear-gradient(90deg, var(--accent-2), var(--accent));
      box-shadow: 0 0 18px rgba(67,199,255,0.22);
    }
    .map-canvas,
    .active-cruise-map-canvas {
      position: relative;
      min-height: 420px;
      height: clamp(360px, 42vw, 520px);
      border-radius: 18px;
      overflow: hidden;
      border: 1px solid rgba(208, 221, 233, 0.24);
      background: rgba(126,184,226,0.04);
    }
    .map-leaflet-canvas { height: clamp(360px, 42vw, 520px); }
    .weather-lookup-layout {
      display: flex;
      align-items: center;
      flex-wrap: wrap;
      gap: 14px;
      justify-content: space-between;
    }
    .weather-lookup-form {
      display: flex;
      align-items: center;
      flex-wrap: wrap;
      gap: 10px;
      justify-content: flex-end;
    }
    .weather-choice-row,
    .timing-inline {
      display: flex;
      gap: 12px;
      flex-wrap: wrap;
      align-items: center;
    }
    .weather-choice input {
      width: 18px;
      height: 18px;
      accent-color: var(--accent-2);
      margin: 0;
    }
    .timing-input,
    .checkin-note-input {
      border-radius: 10px;
      border: 1px solid rgba(126,184,226,0.18);
      background: rgba(8,18,28,0.82);
      color: var(--text);
      padding: 10px 12px;
      font: inherit;
    }
    .checkin-note-input {
      min-height: 96px;
      border-radius: var(--radius-md);
      line-height: 1.5;
      margin-top: 8px;
    }
    .captain-actions,
    .contact-list,
    .quick-actions,
    .log-list,
    .detail-list {
      display: grid;
      gap: 12px;
    }
    .action-row {
      display: grid;
      grid-template-columns: minmax(0, 1fr);
      gap: 8px;
    }
    .quick-actions .action-row {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 12px;
    }
    .action-mini {
      padding: 8px 12px;
      border-radius: 999px;
      font-size: 0.8rem;
      font-weight: 800;
      color: var(--accent);
      background: rgba(67,199,255,0.08);
      border: 1px solid rgba(67,199,255,0.16);
      white-space: nowrap;
    }
    .timeline-body {
      overflow-x: auto;
      border-radius: 20px;
      background: rgba(126,184,226,0.05);
      border: 1px solid rgba(126,184,226,0.12);
    }
    th,
    td {
      border-bottom: 1px solid rgba(126,184,226,0.1);
      padding: 12px 14px;
    }
    th {
      color: var(--soft);
      font-size: 0.72rem;
      font-weight: 800;
      letter-spacing: 0.12em;
    }
    .timeline-row-current td {
      background: rgba(67,199,255,0.08);
      border-color: rgba(67,199,255,0.38);
    }
    .timeline-row-completed td {
      color: var(--muted);
    }
    .warning-panel {
      border-color: rgba(255,198,97,0.18);
      background: rgba(255,198,97,0.06);
    }
    .warning-item {
      border-color: rgba(255,198,97,0.18);
      border-radius: 16px;
      background: rgba(255,255,255,0.025);
      padding: 14px;
    }
    .v2-placeholder-note {
      display: none;
    }
    /* AC-V2 visual best fix: structural classes copied from V1 presentation only. */
    .hero {
      display: grid;
      grid-template-columns: 1.2fr 0.8fr;
      gap: 18px;
      margin-bottom: 18px;
      padding: 0;
      background: transparent;
      border: 0;
      box-shadow: none;
      backdrop-filter: none;
      overflow: visible;
    }
    .hero > .stack:first-child,
    .hero > .stack:last-child {
      align-self: start;
    }
    .hero-main {
      display: block;
      padding: 26px 26px 24px;
      position: relative;
      overflow: hidden;
      background:
        radial-gradient(circle at 0% 0%, rgba(67,199,255,0.08), transparent 0 24%),
        linear-gradient(180deg, rgba(255,255,255,0.025), rgba(255,255,255,0.01));
    }
    .eyebrow {
      display: inline-flex;
      align-items: center;
      gap: 10px;
      padding: 8px 14px;
      border-radius: 999px;
      font-size: 0.78rem;
      letter-spacing: 0.12em;
      text-transform: uppercase;
      font-weight: 800;
      background: rgba(125,242,183,0.08);
      color: var(--good);
      border: 1px solid rgba(125,242,183,0.16);
      margin-bottom: 18px;
    }
    .title-row {
      display: flex;
      justify-content: space-between;
      align-items: flex-start;
      gap: 18px;
      margin-bottom: 18px;
    }
    .status-pill {
      padding: 14px 18px;
      border-radius: 18px;
      background: rgba(125,242,183,0.08);
      border: 1px solid rgba(125,242,183,0.18);
      min-width: 170px;
      text-align: center;
    }
    .status-pill b {
      display: block;
      color: var(--good);
      font-size: 0.8rem;
      letter-spacing: 0.12em;
      text-transform: uppercase;
      margin-bottom: 6px;
    }
    .status-pill strong {
      display: block;
      font-size: 0.95rem;
      font-weight: 800;
      line-height: 1.2;
      letter-spacing: 0;
    }
    .status-pill.status-pill--warning {
      background: rgba(255,198,97,0.08);
      border-color: rgba(255,198,97,0.18);
    }
    .status-pill.status-pill--warning b,
    .status-pill.status-pill--warning strong {
      color: var(--warn);
    }
    .status-pill.status-pill--danger {
      background: rgba(255,127,127,0.08);
      border-color: rgba(255,127,127,0.18);
    }
    .status-pill.status-pill--danger b,
    .status-pill.status-pill--danger strong {
      color: var(--alert);
    }
    .header-stats {
      display: grid;
      grid-template-columns: repeat(5, minmax(0, 1fr));
      gap: 14px;
      margin-top: 18px;
      margin-bottom: 18px;
    }
    .metric span,
    .data-item span {
      display: block;
      color: var(--soft);
      font-size: 0.78rem;
      text-transform: uppercase;
      letter-spacing: 0.12em;
      margin-bottom: 10px;
      font-weight: 800;
    }
    .metric strong {
      display: block;
      font-size: 1.5rem;
      letter-spacing: -0.045em;
      margin-bottom: 6px;
      line-height: 1;
    }
    .metric small,
    .data-item small {
      color: var(--muted);
      font-size: 0.88rem;
      line-height: 1.45;
      display: block;
      margin-top: 6px;
    }
    .data-item span {
      font-size: 0.72rem;
      font-weight: 800;
      text-transform: uppercase;
      letter-spacing: 0.12em;
    }
    .data-item strong {
      font-size: 0.95rem;
      font-weight: 800;
      line-height: 1.2;
      letter-spacing: 0;
    }
    .header-stats .metric span {
      font-size: 0.80rem;
      margin-bottom: 6px;
    }
    .header-stats .metric strong {
      font-size: 0.80rem;
      font-weight: 800;
      line-height: 1.2;
      letter-spacing: 0;
      margin-bottom: 0;
    }
    .header-stats .metric small {
      font-size: 0.80rem;
      line-height: 1.35;
      margin-top: 4px;
    }
    .mini-panel {
      border-radius: 22px;
      background: rgba(126,184,226,0.05);
      border: 1px solid rgba(126,184,226,0.12);
      padding: 18px;
    }
    .mini-panel--route-progress-flat {
      border: 0;
      border-radius: 0;
      background: transparent;
      padding-top: 5px;
      padding-bottom: 5px;
    }
    .mini-panel--route-progress-flat .mini-head h3,
    .mini-panel--route-progress-flat .mini-head span {
      font-size: 0.80rem;
    }
    .hero > .stack + .stack > .panel.section-card:first-child > .floatplan-box {
      background: transparent;
      border: 0;
      padding: 0;
    }
    .mini-head {
      display: flex;
      justify-content: space-between;
      align-items: center;
      gap: 10px;
      margin-bottom: 12px;
    }
    .mini-head h3 {
      margin: 0;
      font-size: 1rem;
      letter-spacing: -0.02em;
    }
    .mini-head span {
      color: var(--soft);
      font-size: 0.78rem;
      text-transform: uppercase;
      letter-spacing: 0.12em;
      font-weight: 800;
    }
    .active-cruise-map-panel {
      margin-bottom: 18px;
      overflow: hidden;
    }
    .active-cruise-map-head {
      display: flex;
      align-items: flex-start;
      justify-content: space-between;
      gap: 14px;
      margin-bottom: 12px;
    }
    .active-cruise-map-copy h3 {
      margin: 0;
      font-size: 1rem;
      letter-spacing: -0.02em;
    }
    .active-cruise-map-copy p {
      margin: 4px 0 0;
      color: var(--muted);
      font-size: 0.92rem;
      line-height: 1.45;
    }
    .active-cruise-map-wrap {
      position: relative;
    }
    #fpwActiveCruiseV2PositionNote {
      margin-top: 18px;
    }
    .active-cruise-map-canvas,
    .map-canvas {
      position: relative;
      height: 420px;
      min-height: 420px;
      border-radius: 18px;
      overflow: hidden;
      border: 1px solid rgba(208, 221, 233, 0.24);
      background: rgba(126,184,226,0.04);
    }
    .ac-v2-map-modal {
      position: fixed;
      inset: 0;
      z-index: 1200;
      display: none;
      align-items: center;
      justify-content: center;
      padding: 20px;
      background: rgba(1, 10, 16, 0.78);
      backdrop-filter: blur(10px);
    }
    .ac-v2-map-modal.is-open {
      display: flex;
    }
    .ac-v2-map-modal[hidden] {
      display: none;
    }
    .ac-v2-map-modal-dialog {
      width: min(100%, 1480px);
      max-height: calc(100vh - 40px);
      display: grid;
      grid-template-rows: auto minmax(0, 1fr);
      gap: 12px;
      padding: 16px;
      border: 1px solid rgba(126,184,226,0.22);
      border-radius: 20px;
      background: var(--panel);
      box-shadow: var(--shadow);
    }
    .ac-v2-map-modal-head {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 12px;
    }
    .ac-v2-map-modal-title {
      margin: 0;
      color: var(--text);
      font-size: 1rem;
      letter-spacing: -0.02em;
    }
    .ac-v2-map-modal-close {
      min-width: 40px;
      min-height: 40px;
      border: 1px solid rgba(126,184,226,0.24);
      border-radius: 999px;
      background: rgba(126,184,226,0.08);
      color: var(--text);
      font: inherit;
      font-weight: 800;
      cursor: pointer;
    }
    .ac-v2-map-modal-close:hover {
      border-color: rgba(67,199,255,0.7);
    }
    .ac-v2-map-modal-body {
      position: relative;
      min-height: min(78vh, 760px);
      border: 1px solid rgba(208, 221, 233, 0.24);
      border-radius: 16px;
      overflow: hidden;
      background: rgba(126,184,226,0.04);
    }
    .ac-v2-map-modal-canvas {
      position: absolute;
      inset: 0;
    }
    body.ac-v2-map-modal-open {
      overflow: hidden;
    }
    .progress-block {
      display: grid;
      gap: 12px;
    }
    .route-leg-estimate {
      margin-top: 12px;
      padding: 16px;
      border: 1px solid rgba(126,184,226,0.16);
      border-radius: 8px;
      background: rgba(7,24,36,0.36);
      display: grid;
      gap: 14px;
    }
    .route-leg-estimate-head {
      display: flex;
      align-items: baseline;
      justify-content: space-between;
      gap: 12px;
    }
    .route-leg-estimate-title {
      margin: 0;
      font-size: 0.80rem;
      line-height: 1.2;
      letter-spacing: 0;
    }
    .route-leg-estimate-state {
      color: var(--accent);
      font-size: 0.80rem;
      font-weight: 800;
      white-space: nowrap;
    }
    .route-leg-estimate-copy {
      margin: 0;
      color: var(--soft);
      line-height: 1.45;
      font-size: 0.80rem;
    }
    .route-leg-estimate-metrics {
      display: grid;
      grid-template-columns: repeat(5, minmax(0, 1fr));
      border-top: 1px solid rgba(126,184,226,0.14);
      border-bottom: 1px solid rgba(126,184,226,0.14);
    }
    .route-leg-estimate-metric {
      min-width: 0;
      padding: 12px 14px;
    }
    .route-leg-estimate-metric:first-child { padding-left: 0; }
    .route-leg-estimate-metric + .route-leg-estimate-metric { border-left: 1px solid rgba(126,184,226,0.16); }
    .route-leg-estimate-metric span {
      display: block;
      color: var(--muted);
      font-size: 0.80rem;
      font-weight: 800;
      letter-spacing: 0.12em;
      margin-bottom: 6px;
      text-transform: uppercase;
    }
    .route-leg-estimate-metric strong {
      display: block;
      color: var(--text);
      font-size: 0.80rem;
      font-weight: 800;
      line-height: 1.2;
      letter-spacing: 0;
      overflow-wrap: anywhere;
    }
    @media (max-width: 1040px) {
      .route-leg-estimate-metrics {
        grid-template-columns: repeat(3, minmax(0, 1fr));
      }
    }
    @media (max-width: 680px) {
      .route-leg-estimate-metrics {
        grid-template-columns: repeat(2, minmax(0, 1fr));
      }
    }
    .route-leg-estimate-progress {
      display: grid;
      gap: 8px;
    }
    .route-leg-estimate-progress-head {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 12px;
      color: var(--muted);
      font-size: 0.80rem;
      font-weight: 700;
    }
    .route-leg-estimate-foot {
      border-top: 1px solid rgba(126,184,226,0.14);
      padding-top: 12px;
      color: var(--soft);
      font-size: 0.80rem;
      line-height: 1.45;
    }
    .route-leg-estimate-foot small {
      display: block;
      margin-top: 4px;
      color: var(--muted);
      font-size: 0.80rem;
    }
    .split {
      display: flex;
      justify-content: space-between;
      gap: 12px;
      color: var(--muted);
      font-size: 0.92rem;
    }
    .contact-reference-actions {
      display: flex;
      flex-wrap: wrap;
      gap: 8px;
      margin-top: 12px;
    }
    .contact-reference-actions--empty {
      color: var(--muted);
      font-size: 0.84rem;
      line-height: 1.4;
    }
    .contact-reference-action {
      display: inline-flex;
      align-items: center;
      justify-content: center;
      gap: 6px;
      min-height: 34px;
      padding: 7px 10px;
      border-radius: 999px;
      border: 1px solid rgba(126,184,226,0.16);
      background: rgba(8,18,28,0.48);
      color: var(--text);
      font-size: 0.82rem;
      font-weight: 800;
      text-decoration: none;
    }
    .contact-reference-action:hover {
      border-color: rgba(67,199,255,0.28);
      color: var(--accent);
    }
    .leg-grid {
      display: grid;
      grid-template-columns: minmax(0, 1.05fr) minmax(320px, 0.95fr);
      gap: 16px;
    }
    .route-box,
    .detail-box,
    .list-box,
    .action-box,
    .log-box,
    .timeline-box,
    .contacts-box,
    .floatplan-box {
      border-radius: 20px;
      background: rgba(126,184,226,0.05);
      border: 1px solid rgba(126,184,226,0.12);
      padding: 18px;
    }
    .route-plan-box {
      display: flex;
      flex-direction: column;
      min-height: 680px;
      max-height: 680px;
    }
    .route-plan-departure,
    .route-plan-final,
    .route-plan-leg {
      border-radius: 16px;
      border: 1px solid rgba(126,184,226,0.11);
      background: rgba(255,255,255,0.025);
    }
    .route-plan-departure,
    .route-plan-final {
      padding: 14px;
    }
    .route-plan-departure {
      margin-bottom: 12px;
    }
    .route-plan-kicker,
    .route-plan-leg-kicker {
      color: var(--soft);
      font-size: 0.72rem;
      font-weight: 800;
      letter-spacing: 0.12em;
      text-transform: uppercase;
    }
    .route-plan-departure strong,
    .route-plan-final strong {
      display: block;
      margin-top: 6px;
      font-size: 1rem;
      line-height: 1.25;
    }
    .route-plan-departure span,
    .route-plan-final span {
      display: block;
      margin-top: 4px;
      color: var(--muted);
      font-size: 0.9rem;
    }
    .route-plan-toolbar {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 12px;
      margin: 12px 0;
    }
    .route-plan-preview-note {
      color: var(--muted);
      font-size: 0.82rem;
      line-height: 1.4;
      margin: 0;
    }
    .route-plan-scroll {
      display: flex;
      flex-direction: column;
      gap: 10px;
      flex: 1 1 auto;
      overflow-y: auto;
      min-height: 0;
      padding-right: 4px;
    }
    .route-plan-leg {
      overflow: hidden;
      flex: 0 0 auto;
      cursor: pointer;
      transition: border-color .16s ease, background .16s ease, box-shadow .16s ease;
    }
    .route-plan-leg--current {
      border-color: rgba(67,199,255,0.38);
      background: rgba(67,199,255,0.08);
      box-shadow: 0 0 0 1px rgba(67,199,255,0.08);
    }
    .route-plan-leg--completed {
      border-color: rgba(125,242,183,0.18);
    }
    .route-plan-leg.is-selected {
      border-color: rgba(67,199,255,0.58);
      background: rgba(67,199,255,0.11);
      box-shadow: 0 0 0 1px rgba(67,199,255,0.16), 0 18px 36px rgba(0,0,0,0.18);
    }
    .route-plan-leg:focus-visible {
      outline: 2px solid rgba(67,199,255,0.82);
      outline-offset: 3px;
    }
    .route-plan-leg-button {
      width: 100%;
      color: inherit;
      padding: 14px;
      display: grid;
      grid-template-columns: auto 1fr auto;
      gap: 12px;
      align-items: center;
      text-align: left;
    }
    .route-plan-leg-dot {
      width: 16px;
      height: 16px;
      border-radius: 999px;
      border: 2px solid rgba(126,184,226,0.4);
      box-shadow: none;
    }
    .route-plan-leg--completed .route-plan-leg-dot {
      border-color: var(--good);
      box-shadow: 0 0 0 5px rgba(125,242,183,0.08);
    }
    .route-plan-leg--current .route-plan-leg-dot {
      border-color: var(--accent);
      box-shadow: 0 0 0 5px rgba(67,199,255,0.1);
    }
    .route-plan-leg.is-selected .route-plan-leg-dot {
      border-color: var(--accent);
      box-shadow: 0 0 0 5px rgba(67,199,255,0.16);
    }
    .route-plan-leg-title {
      display: block;
      font-size: 0.98rem;
      font-weight: 800;
      line-height: 1.25;
    }
    .route-plan-leg-meta {
      display: block;
      color: var(--muted);
      font-size: 0.84rem;
      margin-top: 3px;
    }
    .route-plan-leg-side {
      display: grid;
      justify-items: end;
      gap: 4px;
      color: var(--soft);
      font-size: 0.82rem;
      white-space: nowrap;
    }
    .route-plan-leg-detail {
      border-top: 1px solid rgba(126,184,226,0.1);
      padding: 12px 14px 14px 42px;
      display: none;
    }
    .route-plan-leg.is-selected .route-plan-leg-detail {
      display: block;
    }
    .route-plan-detail-grid {
      display: grid;
      grid-template-columns: repeat(2, minmax(0, 1fr));
      gap: 10px;
    }
    .route-plan-detail-grid div {
      border-radius: 12px;
      background: rgba(255,255,255,0.025);
      border: 1px solid rgba(126,184,226,0.08);
      padding: 10px;
    }
    .route-plan-detail-grid span {
      display: block;
      color: var(--soft);
      font-size: 0.72rem;
      font-weight: 800;
      letter-spacing: 0.12em;
      text-transform: uppercase;
      margin-bottom: 5px;
    }
    .route-plan-detail-grid strong {
      display: block;
      font-size: 0.95rem;
      font-weight: 800;
      line-height: 1.2;
      letter-spacing: 0;
    }
    .route-plan-lock-detail {
      display: grid;
      gap: 10px;
      margin-top: 12px;
    }
    .route-plan-lock-list {
      display: grid;
      gap: 10px;
    }
    .route-plan-lock-item {
      border-radius: 12px;
      background: rgba(255,255,255,0.02);
      border: 1px solid rgba(126,184,226,0.08);
      padding: 12px;
    }
    .route-plan-lock-item h4 {
      margin: 0 0 8px;
      color: var(--text);
      font-size: 0.94rem;
      line-height: 1.3;
    }
    .route-plan-lock-meta {
      display: grid;
      grid-template-columns: repeat(2, minmax(0, 1fr));
      gap: 6px 14px;
      color: var(--soft);
      font-size: 0.8rem;
      line-height: 1.35;
    }
    .route-plan-lock-meta strong {
      color: var(--text);
      font-weight: 800;
    }
    .route-plan-lock-note {
      margin: 0;
      color: var(--muted);
      font-size: 0.84rem;
      line-height: 1.4;
    }
    .route-plan-progress-footer {
      margin-top: 16px;
      padding: 16px;
      border-radius: 18px;
      border: 1px solid rgba(126,184,226,0.12);
      background: rgba(126,184,226,0.04);
    }
    .route-plan-progress-footer--flat {
      margin-top: 14px;
      padding: 0;
      border: 0;
      border-radius: 0;
      background: transparent;
    }
    .route-plan-progress-grid {
      display: grid;
      grid-template-columns: repeat(4, minmax(0, 1fr));
      gap: 12px;
      margin-bottom: 12px;
    }
    .route-plan-progress-grid span {
      display: block;
      color: var(--soft);
      font-size: 0.80rem;
      font-weight: 800;
      letter-spacing: 0.1em;
      text-transform: uppercase;
      margin-bottom: 5px;
    }
    .route-plan-progress-grid strong {
      display: block;
      font-size: 0.80rem;
    }
    .route-plan-progress-bar {
      height: 9px;
      overflow: hidden;
      border-radius: 999px;
      background: rgba(255,255,255,0.06);
      border: 1px solid rgba(126,184,226,0.12);
    }
    .route-plan-progress-bar span {
      display: block;
      height: 100%;
      border-radius: 999px;
      background: linear-gradient(90deg, var(--accent), var(--accent-3));
    }
    .route-selected-leg-box {
      min-height: 560px;
    }
    @media (min-width: 861px) {
      #acV2RouteProgressPanel .route-plan-box {
        min-height: 899.21875px;
        max-height: 899.21875px;
      }
    }
    .timeline {
      display: grid;
      gap: 14px;
    }
    .today-checkin-history {
      max-height: 360px;
      overflow-y: auto;
      padding-right: 4px;
    }
    .timeline-row {
      display: grid;
      grid-template-columns: 84px 18px 1fr;
      gap: 14px;
      align-items: start;
    }
    .timeline-time {
      color: var(--soft);
      font-size: 0.86rem;
      font-weight: 700;
      padding-top: 2px;
    }
    .timeline-node {
      width: 18px;
      height: 18px;
      border-radius: 50%;
      border: 2px solid var(--accent);
      position: relative;
      margin-top: 1px;
    }
    .timeline-node::after {
      content: "";
      position: absolute;
      left: 6px;
      top: 18px;
      width: 2px;
      height: 34px;
      background: rgba(126,184,226,0.18);
    }
    .timeline-row:last-child .timeline-node::after { display: none; }
    .timeline-copy b {
      display: block;
      font-size: 0.95rem;
      margin-bottom: 4px;
    }
    .timeline-copy span {
      display: block;
      color: var(--muted);
      line-height: 1.55;
      font-size: 0.9rem;
    }
    .timeline-copy .timeline-source {
      margin-top: 6px;
      color: var(--soft);
      font-size: 0.76rem;
      font-weight: 800;
      letter-spacing: 0.08em;
      text-transform: uppercase;
    }
    .contact-row,
    .log-row {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 12px;
      padding: 14px 16px;
      border-radius: 16px;
      background: rgba(255,255,255,0.02);
      border: 1px solid rgba(126,184,226,0.08);
    }
    .contact-row b,
    .action-row b,
    .log-row b { display: block; font-size: 0.95rem; }
    .contact-row span,
    .action-row span,
    .log-row span { color: var(--muted); font-size: 0.88rem; display: block; margin-top: 4px; }
    .captain-quick-note-form {
      display: grid;
      gap: 10px;
      padding: 14px;
      margin-bottom: 14px;
      border-radius: 16px;
      border: 1px solid rgba(126,184,226,0.1);
      background: rgba(8,18,28,0.32);
    }
    .captain-note-label {
      display: flex;
      align-items: baseline;
      justify-content: space-between;
      gap: 10px;
      color: var(--text);
      font-weight: 800;
    }
    .captain-note-label small,
    .captain-note-help,
    .captain-note-message,
    .captain-note-meta span {
      color: var(--muted);
      font-size: 0.82rem;
    }
    .captain-note-input {
      width: 100%;
      min-height: 92px;
      resize: vertical;
      border-radius: 12px;
      border: 1px solid rgba(126,184,226,0.18);
      background: rgba(8,18,28,0.82);
      color: var(--text);
      padding: 10px 12px;
      font: inherit;
      line-height: 1.45;
    }
    .captain-note-input:focus {
      outline: 2px solid rgba(24,242,210,0.28);
      outline-offset: 2px;
    }
    .captain-note-tags {
      display: flex;
      flex-wrap: wrap;
      gap: 8px;
    }
    .captain-note-tag {
      min-height: 32px;
      border: 1px solid rgba(126,184,226,0.18);
      border-radius: 999px;
      background: rgba(126,184,226,0.05);
      color: var(--text);
      padding: 6px 10px;
      font: inherit;
      font-size: 0.82rem;
      font-weight: 800;
      cursor: pointer;
    }
    .captain-note-tag:hover:not(:disabled),
    .captain-note-tag.is-selected {
      border-color: rgba(24,242,210,0.48);
      background: rgba(24,242,210,0.1);
      color: var(--accent-2);
    }
    .captain-note-post-option {
      display: flex;
      align-items: flex-start;
      gap: 8px;
      color: var(--text);
      font-size: 0.88rem;
      line-height: 1.4;
    }
    .captain-note-post-option input {
      margin-top: 3px;
    }
    .captain-note-message {
      min-height: 20px;
      line-height: 1.4;
    }
    .captain-note-message.is-success {
      color: var(--green);
    }
    .captain-note-message.is-error {
      color: var(--red);
    }
    .captain-note-save {
      min-height: 40px;
      border: 1px solid rgba(24,242,210,0.38);
      border-radius: 10px;
      background: rgba(24,242,210,0.1);
      color: var(--accent-2);
      font: inherit;
      font-weight: 900;
      cursor: pointer;
    }
    .captain-note-save:disabled,
    .captain-note-tag:disabled,
    .captain-note-input:disabled {
      cursor: not-allowed;
      opacity: 0.58;
    }
    .captain-note-meta {
      display: grid;
      justify-items: end;
      gap: 4px;
      flex: 0 0 auto;
    }
    .captain-note-meta .action-mini {
      padding: 0;
      border: 0;
      border-radius: 0;
      background: transparent;
      font-size: 0.8rem;
    }
    .captain-note-log-list {
      max-height: 408px;
      overflow-y: auto;
      padding-right: 4px;
      scrollbar-gutter: stable;
    }
    .active-cruise-reference-card {
      padding: 18px;
    }
    .reference-card-header {
      display: flex;
      align-items: flex-start;
      justify-content: space-between;
      gap: 12px;
      margin-bottom: 14px;
    }
    .reference-card-header h2 {
      margin: 0;
      font-size: 1.12rem;
      letter-spacing: -0.03em;
    }
    .reference-card-header p {
      margin: 6px 0 0;
      color: var(--muted);
      font-size: 0.9rem;
      line-height: 1.45;
    }
    .reference-badge {
      flex: 0 0 auto;
      padding: 7px 10px;
      border-radius: 999px;
      border: 1px solid rgba(67,199,255,0.18);
      background: rgba(67,199,255,0.08);
      color: var(--accent);
      font-size: 0.68rem;
      font-weight: 800;
      letter-spacing: 0.12em;
      text-transform: uppercase;
      white-space: nowrap;
    }
    .contact-reference-stack {
      display: grid;
      gap: 12px;
    }
    .contact-reference-panel {
      padding: 14px;
      border-radius: 18px;
      border: 1px solid rgba(126,184,226,0.1);
      background: rgba(126,184,226,0.045);
    }
    .contact-reference-panel--primary {
      border-color: rgba(67,199,255,0.16);
      background: rgba(67,199,255,0.055);
    }
    .contact-reference-main {
      display: flex;
      align-items: flex-start;
      gap: 12px;
      min-width: 0;
    }
    .contact-reference-icon {
      width: 34px;
      height: 34px;
      flex: 0 0 34px;
      display: inline-flex;
      align-items: center;
      justify-content: center;
      border-radius: 12px;
      border: 1px solid rgba(126,184,226,0.18);
      background: rgba(8,18,28,0.5);
      color: var(--accent);
    }
    .contact-reference-content {
      min-width: 0;
      flex: 1 1 auto;
    }
    .contact-reference-kicker {
      color: var(--soft);
      font-size: 0.68rem;
      font-weight: 800;
      letter-spacing: 0.12em;
      text-transform: uppercase;
      margin-bottom: 5px;
    }
    .contact-reference-name {
      color: var(--text);
      font-size: 1rem;
      font-weight: 800;
      line-height: 1.2;
      overflow-wrap: anywhere;
    }
    .contact-reference-subtext {
      color: var(--muted);
      font-size: 0.86rem;
      line-height: 1.45;
      margin-top: 4px;
    }
    .contact-reference-crew-list {
      display: grid;
      gap: 8px;
      margin-top: 12px;
    }
    .contact-reference-crew-row {
      display: grid;
      grid-template-columns: auto minmax(0, 1fr) auto;
      align-items: center;
      gap: 8px;
      color: var(--muted);
      font-size: 0.86rem;
      min-width: 0;
    }
    .contact-reference-dot {
      width: 7px;
      height: 7px;
      border-radius: 50%;
      background: var(--accent);
      box-shadow: 0 0 0 4px rgba(67,199,255,0.08);
    }
    .contact-reference-crew-name {
      color: var(--text);
      font-weight: 700;
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
    }
    .contact-reference-crew-role {
      color: var(--soft);
      font-size: 0.78rem;
      white-space: nowrap;
    }
    .contact-reference-empty {
      color: var(--muted);
      font-size: 0.86rem;
      line-height: 1.45;
      margin-top: 10px;
    }
    .footer-band {
      display: grid;
      grid-template-columns: 1fr 1fr 1fr;
      gap: 18px;
      margin-top: 18px;
    }
    .foot-card {
      padding: 20px;
      border-radius: 22px;
      background: var(--panel-2);
      border: 1px solid var(--line);
      box-shadow: var(--shadow);
    }
    .foot-card h3 {
      margin: 0 0 10px;
      font-size: 1rem;
      letter-spacing: -0.02em;
    }
    .foot-card p {
      margin: 0;
      color: var(--muted);
      line-height: 1.65;
      font-size: 0.92rem;
    }
    .ac-checkin-command-panel {
      display: grid;
      gap: 14px;
      padding: 18px;
      border-radius: 20px;
      background: rgba(7, 24, 36, 0.34);
      border: 1px solid rgba(126,184,226,0.12);
    }
    .ac-panel-header {
      display: flex;
      align-items: flex-start;
      justify-content: space-between;
      gap: 14px;
    }
    .ac-panel-header h2 {
      color: var(--text);
      font-size: 1.12rem;
      letter-spacing: -0.03em;
      text-transform: none;
    }
    .ac-panel-header p {
      margin: 4px 0 0;
      color: var(--muted);
      font-size: 0.9rem;
    }
    .ac-info-button {
      width: 28px;
      height: 28px;
      border-radius: 999px;
      border: 1px solid rgba(126,184,226,0.26);
      background: rgba(126,184,226,0.06);
      color: var(--muted);
      font: inherit;
      font-weight: 800;
      line-height: 1;
    }
    .ac-command-section {
      display: grid;
      gap: 10px;
      border-top: 1px solid rgba(126,184,226,0.12);
      padding-top: 12px;
    }
    .ac-section-label {
      color: var(--soft);
      font-size: 0.72rem;
      font-weight: 800;
      letter-spacing: 0.12em;
      text-transform: uppercase;
    }
    .ac-status-grid {
      display: grid;
      grid-template-columns: repeat(2, minmax(0, 1fr));
      gap: 10px;
    }
    .ac-status-cell,
    .ac-route-action-cell {
      display: grid;
      gap: 6px;
    }
    .ac-command-btn {
      width: 100%;
      min-height: 48px;
      display: inline-flex;
      align-items: center;
      justify-content: center;
      gap: 10px;
      border-radius: 8px;
      border: 1px solid rgba(67,199,255,0.45);
      background: rgba(67,199,255,0.08);
      color: var(--text);
      padding: 10px 12px;
      font: inherit;
      font-weight: 800;
      cursor: pointer;
    }
    .ac-command-btn:hover:not(:disabled) {
      transform: translateY(-1px);
      border-color: rgba(67,199,255,0.75);
    }
    .ac-command-btn:disabled {
      cursor: not-allowed;
      opacity: .62;
      color: var(--soft);
      background: rgba(126,184,226,0.045);
      border-color: rgba(126,184,226,0.12);
      transform: none;
    }
    .ac-command-icon {
      display: inline-flex;
      align-items: center;
      justify-content: center;
      width: 24px;
      height: 24px;
      flex: 0 0 24px;
      border-radius: 999px;
      color: currentColor;
      font-weight: 900;
    }
    .ac-status-ontrack { border-color: rgba(34,149,255,0.72); color: #dff1ff; }
    .ac-status-delayed { border-color: rgba(255,170,35,0.72); color: #fff0d1; }
    .ac-status-changed { border-color: rgba(154,92,255,0.72); color: #efe6ff; }
    .ac-status-secure { border-color: rgba(24,242,210,0.54); color: #d5fff8; }
    .ac-assistance-btn {
      border-color: rgba(255,91,58,0.76);
      background: rgba(255,91,58,0.12);
      color: #ffe0d8;
    }
    .ac-checkin-note {
      width: 100%;
      min-height: 74px;
      max-height: 120px;
      resize: vertical;
      border-radius: 10px;
      border: 1px solid rgba(126,184,226,0.18);
      background: rgba(8,18,28,0.82);
      color: var(--text);
      padding: 10px 12px;
      font: inherit;
      line-height: 1.45;
    }
    .ac-note-counter {
      color: var(--muted);
      font-size: 0.8rem;
      text-align: right;
    }
    .ac-route-action-btn {
      justify-content: flex-start;
      text-align: left;
      border-color: rgba(34,149,255,0.72);
      background: rgba(34,149,255,0.1);
    }
    .ac-route-action-btn span:last-child,
    .ac-disabled-action-row span:last-child {
      display: grid;
      gap: 2px;
      min-width: 0;
    }
    .ac-route-action-btn strong,
    .ac-disabled-action-row strong {
      color: inherit;
      font-size: 0.95rem;
      line-height: 1.2;
    }
    .ac-route-action-btn small,
    .ac-disabled-action-row small {
      color: var(--muted);
      font-size: 0.82rem;
      line-height: 1.35;
    }
    .ac-disabled-action-row {
      min-height: 46px;
      display: flex;
      align-items: center;
      gap: 10px;
      border-radius: 8px;
      border: 1px solid rgba(126,184,226,0.12);
      background: rgba(126,184,226,0.04);
      color: var(--soft);
      padding: 9px 12px;
    }
    .ac-v2-compact-checkin-panel {
      gap: 10px;
      padding: 12px;
      border-radius: 18px;
    }
    .ac-v2-compact-checkin-panel .ac-panel-header {
      align-items: center;
      gap: 10px;
    }
    .ac-v2-compact-checkin-panel .ac-panel-header h2 {
      font-size: 1.02rem;
    }
    .ac-v2-compact-checkin-panel .ac-panel-header p {
      margin-top: 2px;
      font-size: 0.84rem;
    }
    .ac-v2-compact-checkin-panel .ac-command-section {
      gap: 7px;
      padding-top: 9px;
    }
    .ac-status-compact-grid {
      display: grid;
      grid-template-columns: repeat(4, minmax(0, 1fr));
      gap: 7px;
    }
    .ac-v2-compact-checkin-panel .ac-status-cell,
    .ac-v2-compact-checkin-panel .ac-route-action-cell {
      gap: 4px;
    }
    .ac-v2-compact-checkin-panel .ac-command-btn {
      min-height: 40px;
      gap: 7px;
      border-radius: 8px;
      padding: 7px 9px;
      font-size: 0.82rem;
      line-height: 1.15;
    }
    .ac-v2-compact-checkin-panel .ac-command-icon {
      width: 18px;
      height: 18px;
      flex-basis: 18px;
      font-size: 0.86rem;
    }
    .ac-v2-compact-checkin-panel .action-reason {
      font-size: 0.72rem;
      line-height: 1.25;
      overflow: hidden;
      display: -webkit-box;
      -webkit-box-orient: vertical;
      -webkit-line-clamp: 2;
    }
    .ac-assistance-compact-row .ac-assistance-btn {
      min-height: 38px;
    }
    .ac-v2-note-compact {
      gap: 7px;
    }
    .ac-v2-compact-checkin-panel .ac-v2-note-compact {
      display: none;
    }
    .ac-v2-note-toggle {
      width: 100%;
      min-height: 36px;
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 10px;
      border: 1px solid rgba(126,184,226,0.14);
      border-radius: 8px;
      background: rgba(126,184,226,0.045);
      color: var(--text);
      padding: 7px 10px;
      font: inherit;
      font-size: 0.82rem;
      font-weight: 800;
      cursor: pointer;
    }
    .ac-v2-note-toggle:hover {
      border-color: rgba(67,199,255,0.45);
    }
    .ac-v2-note-toggle .ac-note-counter {
      text-align: right;
      font-weight: 700;
    }
    .ac-v2-note-collapsible[hidden] {
      display: none;
    }
    .ac-v2-compact-checkin-panel .ac-checkin-note {
      min-height: 64px;
      max-height: 96px;
      border-radius: 8px;
      padding: 8px 10px;
      font-size: 0.86rem;
    }
    .ac-route-actions-compact {
      gap: 7px;
      grid-template-columns: repeat(3, minmax(0, 1fr));
    }
    .ac-route-actions-compact .ac-section-label {
      grid-column: 1 / -1;
    }
    .ac-v2-compact-checkin-panel .ac-route-action-btn {
      min-height: 40px;
      justify-content: center;
      text-align: center;
    }
    .ac-v2-compact-checkin-panel .ac-route-action-btn span:last-child {
      display: inline;
    }
    .ac-v2-compact-checkin-panel .ac-route-action-btn small {
      display: none;
    }
    .ac-v2-compact-checkin-panel .ac-disabled-action-row {
      min-height: 40px;
      gap: 8px;
      border-radius: 8px;
      padding: 7px 10px;
    }
    .ac-v2-compact-checkin-panel .ac-disabled-action-row strong {
      font-size: 0.82rem;
    }
    .ac-v2-compact-checkin-panel .ac-disabled-action-row small {
      font-size: 0.74rem;
      line-height: 1.25;
      overflow: hidden;
      display: -webkit-box;
      -webkit-box-orient: vertical;
      -webkit-line-clamp: 2;
    }
    .ac-status-btn,
    .ac-route-action-btn,
    #fpwV2TimingPanel .ac-command-btn,
    .ac-weather-command-btn {
      color: #fff;
      font-size: 0.95rem;
      font-weight: 800;
      line-height: 1.1;
      text-align: center;
      letter-spacing: 0;
    }
    .ac-status-btn span:last-child,
    .ac-route-action-btn strong,
    .ac-disabled-action-row strong,
    #fpwV2TimingPanel .ac-command-btn,
    .ac-weather-command-btn {
      color: #fff;
      font-size: 0.95rem;
      font-weight: 800;
      line-height: 1.1;
      letter-spacing: 0;
    }
    .ac-v2-compact-checkin-panel .ac-action-ready-message {
      padding-top: 9px;
      font-size: 0.8rem;
      line-height: 1.35;
    }
    .ac-v2-compact-checkin-panel .ac-action-ready-message::before {
      width: 18px;
      height: 18px;
      flex-basis: 18px;
    }
    .ac-v2-compact-checkin-panel #fpwV2ActionFeedback {
      display: none !important;
    }
    .ac-monitor-command-panel #fpwV2TimingFeedback {
      display: none !important;
    }
    .ac-action-ready-message {
      display: flex;
      gap: 10px;
      align-items: center;
      border-top: 1px solid rgba(126,184,226,0.12);
      padding-top: 12px;
    }
    #fpwV2DailyStartFeedback[hidden] {
      display: none;
    }
    .ac-action-ready-message::before {
      content: "";
      width: 26px;
      height: 26px;
      flex: 0 0 26px;
      border-radius: 999px;
      background: linear-gradient(135deg, var(--accent), var(--accent-2));
    }
    .ac-monitor-command-panel {
      display: grid;
      gap: 16px;
      padding: 18px;
      border-radius: 20px;
      background: rgba(7, 24, 36, 0.34);
      border: 1px solid rgba(126,184,226,0.12);
    }
    .ac-monitor-grid {
      display: grid;
      grid-template-columns: repeat(3, minmax(0, 1fr));
      gap: 7px;
    }
    .ac-monitor-tile {
      display: grid;
      gap: 7px;
      min-height: 96px;
      border-radius: 14px;
      border: 1px solid rgba(126,184,226,0.14);
      background: rgba(126,184,226,0.045);
      padding: 8px 10px;
    }
    .ac-delay-tile {
      grid-column: 1 / -1;
    }
    .ac-monitor-tile p {
      margin: 0;
      color: var(--muted);
      line-height: 1.45;
      font-size: 0.86rem;
    }
    .ac-monitor-value {
      display: block;
      color: var(--text);
      font-size: 0.95rem;
      font-weight: 800;
      line-height: 1.2;
      letter-spacing: 0;
      overflow-wrap: anywhere;
    }
    .ac-delay-tile .ac-command-btn {
      margin-top: 4px;
    }
    .ac-muted-note {
      color: var(--muted);
      font-size: 0.82rem;
    }
    .ac-inline-control-row {
      display: grid;
      grid-template-columns: minmax(0, 1fr) auto;
      gap: 12px;
      align-items: end;
      margin-top: 4px;
    }
    .ac-monitor-command-panel .timing-input {
      min-height: 48px;
      width: 100%;
      border-radius: 10px;
    }
    .ac-monitor-command-panel .ac-command-section h3 {
      margin: 0;
      color: var(--text);
      font-size: 1rem;
      letter-spacing: -0.02em;
    }
    .ac-monitor-command-panel .ac-command-section p {
      margin: 0;
      color: var(--muted);
      line-height: 1.45;
    }
    .ac-pace-command-panel {
      display: grid;
      gap: 14px;
      padding: 18px;
      border-radius: 20px;
      background: rgba(7, 24, 36, 0.34);
      border: 1px solid rgba(126,184,226,0.12);
    }
    .route-leg-estimate + .ac-pace-command-panel {
      margin-top: 16px;
    }
    .ac-pace-meter {
      display: grid;
      gap: 7px;
      border-radius: 14px;
      border: 1px solid rgba(126,184,226,0.14);
      background: rgba(126,184,226,0.045);
      padding: 10px 12px;
    }
    .ac-pace-meter p {
      margin: 0;
      color: var(--muted);
      line-height: 1.45;
      font-size: 0.86rem;
    }
    .ac-pace-slider {
      width: 100%;
      accent-color: var(--accent);
    }
    .ac-pace-label-row {
      display: grid;
      grid-template-columns: repeat(3, minmax(0, 1fr));
      gap: 8px;
      color: var(--soft);
      font-size: 0.78rem;
      font-weight: 800;
      text-align: center;
    }
    .ac-pace-selected {
      display: grid;
      gap: 4px;
      min-height: 48px;
      align-content: center;
      border-radius: 10px;
      border: 1px solid rgba(126,184,226,0.14);
      background: rgba(8,18,28,0.52);
      padding: 8px 10px;
    }
    .ac-pace-selected span {
      color: var(--muted);
      font-size: 0.72rem;
      font-weight: 800;
      letter-spacing: 0.12em;
      text-transform: uppercase;
    }
    .ac-pace-selected strong {
      color: var(--text);
      font-size: 0.94rem;
      line-height: 1.15;
    }
    @media (max-width: 780px) {
      main.main { width: auto; }
      .shell { width: min(var(--max), calc(100% - (var(--fpw-page-gutter, 32px) * 2))); }
      .identity-strip,
      .layout,
      .supporting-grid,
      .content-grid,
      .footer-band,
      .hero,
      .hero-main,
      .hero-grid,
      .field-grid,
      .detail-row,
      .weather-lookup-layout,
      .timing-summary-grid,
      .timing-form-grid,
      .timing-inline,
      .ac-monitor-header,
      .ac-inline-control-row,
      .timeline-head {
        grid-template-columns: 1fr;
      }
      table { font-size: .84rem; }
    }
    @media (max-width: 1240px) {
      .layout,
      .supporting-grid,
      .content-grid,
      .footer-band {
        grid-template-columns: 1fr;
      }
      .identity-strip {
        grid-template-columns: repeat(3, minmax(0, 1fr));
      }
    }
    @media (max-width: 860px) {
      .shell { width: min(var(--max), calc(100% - (var(--fpw-page-gutter, 32px) * 2))); }
      .topbar-inner,
      .hero-main,
      .section-header,
      .section-top,
      .timeline-head {
        flex-direction: column;
        align-items: flex-start;
      }
      .top-actions { justify-content: flex-start; }
      .identity-strip,
      .hero-grid,
      .map-summary-grid,
      .field-grid,
      .data-grid,
      .timing-summary-grid,
      .timing-form-grid {
        grid-template-columns: 1fr 1fr;
      }
      .leg-grid {
        grid-template-columns: 1fr;
      }
      .route-plan-box {
        max-height: none;
      }
      .route-plan-scroll {
        max-height: 420px;
      }
      .route-selected-leg-box {
        min-height: auto;
      }
    }
    @media (max-width: 640px) {
      .identity-strip,
      .hero-grid,
      .header-stats,
      .route-leg-estimate-metrics,
      .map-summary-grid,
      .field-grid,
      .data-grid,
      .ac-monitor-grid,
      .ac-status-grid,
      .ac-status-compact-grid,
      .timing-summary-grid,
      .timing-form-grid,
      .ac-route-actions-compact,
      .footer-band {
        grid-template-columns: 1fr;
      }
      .map-canvas,
      .active-cruise-map-canvas {
        min-height: 340px;
        height: 340px;
      }
      .ac-v2-map-modal {
        padding: 8px;
      }
      .ac-v2-map-modal-dialog {
        max-height: calc(100vh - 16px);
        padding: 10px;
        border-radius: 14px;
      }
      .ac-v2-map-modal-body {
        min-height: 70vh;
      }
    }
    .topbar :where(:not(h1):not(h2):not(h3):not(h4):not(h5):not(h6):not(h1 *):not(h2 *):not(h3 *):not(h4 *):not(h5 *):not(h6 *)),
    .main :where(:not(h1):not(h2):not(h3):not(h4):not(h5):not(h6):not(h1 *):not(h2 *):not(h3 *):not(h4 *):not(h5 *):not(h6 *)),
    .topbar :where(button:not(h1 *):not(h2 *):not(h3 *):not(h4 *):not(h5 *):not(h6 *),
      a.btn:not(h1 *):not(h2 *):not(h3 *):not(h4 *):not(h5 *):not(h6 *),
      .btn:not(h1 *):not(h2 *):not(h3 *):not(h4 *):not(h5 *):not(h6 *),
      .ac-command-btn:not(h1 *):not(h2 *):not(h3 *):not(h4 *):not(h5 *):not(h6 *),
      .ac-route-action-btn:not(h1 *):not(h2 *):not(h3 *):not(h4 *):not(h5 *):not(h6 *),
      .ac-status-btn:not(h1 *):not(h2 *):not(h3 *):not(h4 *):not(h5 *):not(h6 *)),
    .main :where(button:not(h1 *):not(h2 *):not(h3 *):not(h4 *):not(h5 *):not(h6 *),
      a.btn:not(h1 *):not(h2 *):not(h3 *):not(h4 *):not(h5 *):not(h6 *),
      .btn:not(h1 *):not(h2 *):not(h3 *):not(h4 *):not(h5 *):not(h6 *),
      .ac-command-btn:not(h1 *):not(h2 *):not(h3 *):not(h4 *):not(h5 *):not(h6 *),
      .ac-route-action-btn:not(h1 *):not(h2 *):not(h3 *):not(h4 *):not(h5 *):not(h6 *),
      .ac-status-btn:not(h1 *):not(h2 *):not(h3 *):not(h4 *):not(h5 *):not(h6 *)) {
      font-size: 0.80rem !important;
    }
  </style>
</head>
<body>
<cfset request.fpwTopNavActive = "active-cruise">
<cfinclude template="../includes/top_nav.cfm">
<cfoutput>
  <header class="topbar" aria-label="Active Cruise V2 visual shell">
    <div class="shell topbar-inner">
      <div class="brand">
        <div class="brand-mark" aria-hidden="true">&##9875;</div>
        <div class="brand-copy">
          <div class="brand-title">FloatPlanWizard &bull; Active Cruise Console</div>
          <div class="brand-sub">Private operational view for the captain and trip owner</div>
        </div>
      </div>
      <div class="top-actions" aria-label="Read-only Active Cruise V2 identity">
        <span class="chip">#encodeForHTML(fpwV2Text(fpwV2Get(activeCruiseV2Model.route, "routeName"), "No active route"))#</span>
        <span class="chip">Float Plan #encodeForHTML(fpwV2Text(fpwV2Get(activeCruiseV2Model.floatPlan, "id"), "n/a"))#</span>
        <span class="chip">#encodeForHTML(fpwV2Text(activeCruiseV2Model.tripState, "unknown"))#</span>
      </div>
    </div>
  </header>

  <main class="main">
    <div class="shell">
      <cfif !activeCruiseV2AccessValid>
        <section class="panel section-card">
          <div class="section-top">
            <div>
              <h2>#encodeForHTML(activeCruiseV2AccessMessage)#</h2>
              <p>#encodeForHTML(activeCruiseV2AccessDetail)#</p>
            </div>
            <div class="badge badge-warn">#activeCruiseV2ExpiredAccess ? "Trip Access Expired" : "Active Cruise Unavailable"#</div>
          </div>
          <div class="floatplan-box">
            <p style="margin:0; color:var(--muted); line-height:1.6;">The V2 page uses the authenticated session user as its access authority.</p>
          </div>
        </section>
      <cfelse>
        <cfset mapModel = (structKeyExists(activeCruiseV2Model, "map") AND isStruct(activeCruiseV2Model.map) ? activeCruiseV2Model.map : {})>
        <cfset weatherModel = (structKeyExists(activeCruiseV2Model, "weather") AND isStruct(activeCruiseV2Model.weather) ? activeCruiseV2Model.weather : {})>
        <cfset floatPlanInfoModel = (structKeyExists(activeCruiseV2Model, "floatPlanInfo") AND isStruct(activeCruiseV2Model.floatPlanInfo) ? activeCruiseV2Model.floatPlanInfo : {})>
        <cfset activeCruiseV2TripTimezone = fpwV2Text(fpwV2Get(activeCruiseV2Model.floatPlan, "timezone"), "UTC")>
        <cfset vesselModel = (structKeyExists(floatPlanInfoModel, "vessel") AND isStruct(floatPlanInfoModel.vessel) ? floatPlanInfoModel.vessel : {})>
        <cfset operatorModel = (structKeyExists(floatPlanInfoModel, "operator") AND isStruct(floatPlanInfoModel.operator) ? floatPlanInfoModel.operator : {})>
        <cfset contactsModel = (structKeyExists(activeCruiseV2Model, "contacts") AND isStruct(activeCruiseV2Model.contacts) ? activeCruiseV2Model.contacts : { "items" = [], "passengers" = [] })>
        <cfset floatPlanMonitorModel = (structKeyExists(activeCruiseV2Model, "floatPlanMonitor") AND isStruct(activeCruiseV2Model.floatPlanMonitor) ? activeCruiseV2Model.floatPlanMonitor : {})>
        <cfset floatPlanMonitorContact = (structKeyExists(floatPlanMonitorModel, "monitorContact") AND isStruct(floatPlanMonitorModel.monitorContact) ? floatPlanMonitorModel.monitorContact : {})>
        <cfset floatPlanMonitorPhoneHref = fpwV2Text(fpwV2Get(floatPlanMonitorContact, "phoneHref"), "")>
        <cfset floatPlanMonitorSmsHref = fpwV2Text(fpwV2Get(floatPlanMonitorContact, "smsHref"), "")>
        <cfset floatPlanMonitorEmailHref = fpwV2Text(fpwV2Get(floatPlanMonitorContact, "emailHref"), "")>
        <cfset captainLogModel = (structKeyExists(activeCruiseV2Model, "captainLog") AND isStruct(activeCruiseV2Model.captainLog) ? activeCruiseV2Model.captainLog : { "items" = [], "count" = 0 })>
        <cfset captainLogActionsModel = (structKeyExists(activeCruiseV2Model, "actions") AND isStruct(activeCruiseV2Model.actions) AND structKeyExists(activeCruiseV2Model.actions, "captainLog") AND isStruct(activeCruiseV2Model.actions.captainLog) ? activeCruiseV2Model.actions.captainLog : {})>
        <cfset captainLogSaveAction = (structKeyExists(captainLogActionsModel, "save") AND isStruct(captainLogActionsModel.save) ? captainLogActionsModel.save : {})>
        <cfset checkInHistoryModel = (structKeyExists(activeCruiseV2Model, "checkInHistory") AND isStruct(activeCruiseV2Model.checkInHistory) ? activeCruiseV2Model.checkInHistory : { "items" = [], "count" = 0 })>
        <cfset privateTimelineModel = (structKeyExists(activeCruiseV2Model, "privateTimeline") AND isStruct(activeCruiseV2Model.privateTimeline) ? activeCruiseV2Model.privateTimeline : { "items" = [], "count" = 0 })>
        <cfset mapLegs = (structKeyExists(mapModel, "legs") AND isArray(mapModel.legs) ? mapModel.legs : [])>
        <cfset mapBounds = (structKeyExists(mapModel, "bounds") AND isStruct(mapModel.bounds) ? mapModel.bounds : {})>
        <cfset mapCenter = (structKeyExists(mapModel, "center") AND isStruct(mapModel.center) ? mapModel.center : {})>
        <cfset mapWarnings = (structKeyExists(mapModel, "warnings") AND isArray(mapModel.warnings) ? mapModel.warnings : [])>
        <cfset mapAvailable = (structKeyExists(mapModel, "available") AND isBoolean(mapModel.available) AND mapModel.available)>
        <cfset mapCurrentPosition = (structKeyExists(mapModel, "currentPosition") AND isStruct(mapModel.currentPosition) ? mapModel.currentPosition : {})>
        <cfset mapCurrentPositionAvailable = (
          structKeyExists(mapCurrentPosition, "available")
          AND isBoolean(mapCurrentPosition.available)
          AND mapCurrentPosition.available
        )>
        <cfset mapCurrentPositionSourceLabel = fpwV2Text(fpwV2Get(mapCurrentPosition, "sourceLabel"), "Active Cruise GPS")>
        <cfset mapCurrentPositionUpdatedLabel = fpwV2Text(
          fpwV2Get(mapCurrentPosition, "capturedAtLocalLabel"),
          fpwV2Text(fpwV2Get(mapCurrentPosition, "occurredAtLocalLabel"), "")
        )>
        <cfset mapGeometryAuthority = fpwV2Text(fpwV2Get(mapModel, "geometryAuthority"), "Not available")>
        <cfset mapGeometryAuthorityLabel = replace(mapGeometryAuthority, "_", " ", "all")>
        <cfset weatherPoints = (structKeyExists(weatherModel, "points") AND isStruct(weatherModel.points) ? weatherModel.points : {})>
        <cfset weatherLookup = (structKeyExists(weatherModel, "lookup") AND isStruct(weatherModel.lookup) ? weatherModel.lookup : {})>
        <cfset weatherWarnings = (structKeyExists(weatherModel, "warnings") AND isArray(weatherModel.warnings) ? weatherModel.warnings : [])>
        <cfset weatherLookupAvailable = (structKeyExists(weatherLookup, "available") AND isBoolean(weatherLookup.available) AND weatherLookup.available)>
        <cfset weatherApplyRouteCode = "">
        <cfif structKeyExists(activeCruiseV2Model, "route") AND isStruct(activeCruiseV2Model.route)>
          <cfset weatherApplyRouteCode = fpwV2Text(fpwV2Get(activeCruiseV2Model.route, "routeCode"), "")>
        </cfif>
        <cfif (
          len(weatherApplyRouteCode)
          AND (
            NOT structKeyExists(weatherModel, "apply")
            OR NOT isStruct(weatherModel.apply)
            OR NOT (
              structKeyExists(weatherModel.apply, "available")
              AND isBoolean(weatherModel.apply.available)
              AND weatherModel.apply.available
            )
          )
        )>
          <cfset weatherModel.apply = {
            "available" = weatherLookup.available,
            "method" = "POST",
            "routeCode" = weatherApplyRouteCode,
            "endpoints" = {
              "editContext" = "/api/v1/routeBuilder.cfc?method=handle&action=routegen_geteditcontext&returnFormat=json",
              "generatedPreview" = "/api/v1/routeBuilder.cfc?method=handle&action=routegen_preview&returnFormat=json",
              "myRoutePreview" = "/api/v1/routeBuilder.cfc?method=handle&action=previewuserroute&returnFormat=json",
              "update" = "/api/v1/routeBuilder.cfc?method=handle&action=routegen_update&returnFormat=json"
            },
            "payload" = {
              "routeCode" = weatherApplyRouteCode
            }
          }>
        </cfif>
        <cfset weatherApply = (structKeyExists(weatherModel, "apply") AND isStruct(weatherModel.apply) ? weatherModel.apply : {})>
        <cfif structCount(weatherApply) AND structKeyExists(weatherApply, "available")>
          <cfif weatherApply.available>
            <cfset weatherModel.apply.available = true>
          <cfelse>
            <cfset weatherModel.apply.available = false>
          </cfif>
          <cfset weatherApply = weatherModel.apply>
        </cfif>
        <cfset weatherApplyAvailable = (structKeyExists(weatherApply, "available") AND isBoolean(weatherApply.available) AND weatherApply.available)>
        <cfset weatherStartPoint = (structKeyExists(weatherPoints, "start") AND isStruct(weatherPoints.start) ? weatherPoints.start : {})>
        <cfset weatherEndPoint = (structKeyExists(weatherPoints, "end") AND isStruct(weatherPoints.end) ? weatherPoints.end : {})>
        <cfset timingActionsModel = (structKeyExists(activeCruiseV2Model.actions, "timing") AND isStruct(activeCruiseV2Model.actions.timing) ? activeCruiseV2Model.actions.timing : {})>
        <cfset timingAddDelayAction = (structKeyExists(timingActionsModel, "addDelay") AND isStruct(timingActionsModel.addDelay) ? timingActionsModel.addDelay : {})>
        <cfset timingClearDelayAction = (structKeyExists(timingActionsModel, "clearDelay") AND isStruct(timingActionsModel.clearDelay) ? timingActionsModel.clearDelay : {})>
        <cfset timingDailyStartAction = (structKeyExists(timingActionsModel, "updateDailyStart") AND isStruct(timingActionsModel.updateDailyStart) ? timingActionsModel.updateDailyStart : {})>
        <cfset paceModel = (structKeyExists(activeCruiseV2Model, "pace") AND isStruct(activeCruiseV2Model.pace) ? activeCruiseV2Model.pace : {})>
        <cfset paceActionsModel = (structKeyExists(activeCruiseV2Model.actions, "pace") AND isStruct(activeCruiseV2Model.actions.pace) ? activeCruiseV2Model.actions.pace : {})>
        <cfset paceUpdateAction = (structKeyExists(paceActionsModel, "updatePace") AND isStruct(paceActionsModel.updatePace) ? paceActionsModel.updatePace : {})>
        <cfset paceOptions = (structKeyExists(paceModel, "options") AND isArray(paceModel.options) ? paceModel.options : [
          { "value" = "RELAXED", "label" = "Relaxed", "index" = 0 },
          { "value" = "BALANCED", "label" = "Efficient Speed", "index" = 1 },
          { "value" = "AGGRESSIVE", "label" = "Max Speed", "index" = 2 }
        ])>
        <cfset paceCurrentValue = uCase(fpwV2Text(fpwV2Get(paceModel, "currentValue"), "RELAXED"))>
        <cfif paceCurrentValue NEQ "BALANCED" AND paceCurrentValue NEQ "AGGRESSIVE">
          <cfset paceCurrentValue = "RELAXED">
        </cfif>
        <cfset paceCurrentIndex = fpwV2Get(paceModel, "currentIndex", 0)>
        <cfif !isNumeric(paceCurrentIndex)>
          <cfset paceCurrentIndex = 0>
        </cfif>
        <cfset paceCurrentIndex = val(paceCurrentIndex)>
        <cfif paceCurrentIndex LT 0 OR paceCurrentIndex GT 2>
          <cfset paceCurrentIndex = 0>
        </cfif>
        <cfset paceUpdateEnabled = fpwV2ActionEnabled(paceUpdateAction)>
        <cfset paceUpdateReason = fpwV2Text(fpwV2Get(paceUpdateAction, "disabledReason"), fpwV2Text(fpwV2Get(paceUpdateAction, "reason"), ""))>
        <cfif paceUpdateEnabled><cfset paceUpdateReason = ""></cfif>
        <cfset manualDelayMinutesTotal = fpwV2Get(activeCruiseV2Model.monitoring, "manualDelayMinutesTotal", 0)>
        <cfif !isNumeric(manualDelayMinutesTotal)>
          <cfset manualDelayMinutesTotal = 0>
        </cfif>
        <cfset manualDelayMinutesTotal = val(manualDelayMinutesTotal)>
        <cfset addDelayEnabled = fpwV2ActionEnabled(timingAddDelayAction)>
        <cfset clearDelayEnabled = fpwV2ActionEnabled(timingClearDelayAction) AND manualDelayMinutesTotal GT 0>
        <cfset dailyStartEnabled = fpwV2ActionEnabled(timingDailyStartAction)>
        <cfset addDelayReason = fpwV2Text(fpwV2Get(timingAddDelayAction, "disabledReason"), fpwV2Text(fpwV2Get(timingAddDelayAction, "reason"), ""))>
        <cfset clearDelayReason = fpwV2Text(fpwV2Get(timingClearDelayAction, "disabledReason"), fpwV2Text(fpwV2Get(timingClearDelayAction, "reason"), ""))>
        <cfset dailyStartReason = fpwV2Text(fpwV2Get(timingDailyStartAction, "disabledReason"), fpwV2Text(fpwV2Get(timingDailyStartAction, "reason"), ""))>
        <cfset dailyStartInputValue = fpwV2Text(fpwV2Get(activeCruiseV2Model.monitoring, "dailyStartLocalTime"), "")>
        <cfif len(dailyStartInputValue) GTE 5>
          <cfset dailyStartInputValue = left(dailyStartInputValue, 5)>
        </cfif>
        <cfif !len(trim(dailyStartInputValue))>
          <cfset dailyStartInputValue = "08:00">
        </cfif>
        <cfif addDelayEnabled><cfset addDelayReason = ""></cfif>
        <cfif fpwV2ActionEnabled(timingClearDelayAction) AND manualDelayMinutesTotal LTE 0>
          <cfset clearDelayReason = "No manual delay is currently applied.">
        <cfelseif clearDelayEnabled>
          <cfset clearDelayReason = "">
        </cfif>
        <cfif dailyStartEnabled><cfset dailyStartReason = ""></cfif>

        <section class="hero" aria-label="Active Cruise V2 operational console">
          <div class="stack">
            <div class="panel hero-main">
              <div class="title-row">
                <div>
                  <h1 data-fpw-field="hero.routeTitle">#encodeForHTML(fpwV2Text(fpwV2Get(activeCruiseV2Model.hero, "title"), fpwV2Text(fpwV2Get(activeCruiseV2Model.route, "routeName"), "Active Cruise")))#</h1>
                  <div class="subline">#encodeForHTML(fpwV2Text(fpwV2Get(activeCruiseV2Model.hero, "statusDetail"), activeCruiseV2Model.message))#</div>
                </div>
                <div class="status-pill<cfif fpwV2StateClass(activeCruiseV2Model.tripState) EQ 'is-alert'> status-pill--danger<cfelseif fpwV2StateClass(activeCruiseV2Model.tripState) EQ 'is-scheduled' OR fpwV2StateClass(activeCruiseV2Model.tripState) EQ 'is-paused'> status-pill--warning</cfif>">
                  <strong data-fpw-field="hero.voyageStatus">#encodeForHTML(fpwV2Text(fpwV2Get(activeCruiseV2Model.hero, "status"), fpwV2Text(activeCruiseV2Model.tripState, "unknown")))#</strong>
                </div>
              </div>

              <div class="mini-panel active-cruise-map-panel">
                <div class="active-cruise-map-head">
                  <div class="active-cruise-map-copy">
                    <h3>Map Overview</h3>
                    <p>Planned route, reported progress, completed legs, and destination.</p>
                  </div>
                  <button class="btn btn-secondary" id="fpwActiveCruiseV2OpenFullMapBtn" type="button"<cfif NOT mapAvailable> disabled aria-disabled="true"</cfif>>Open Full Map</button>
                </div>
                <div class="active-cruise-map-wrap" data-ac-v2-map-authority="#encodeForHTMLAttribute(mapGeometryAuthority)#">
                  <cfif mapAvailable>
                    <div class="active-cruise-map-canvas map-leaflet-canvas" aria-label="Read-only route map from Active Cruise V2 view model">
                      <div id="fpwActiveCruiseV2Map" data-ac-v2-map-canvas="true"></div>
                      <div id="fpwActiveCruiseV2MapStatus" class="map-load-state is-visible" aria-live="polite">
                        <span>Loading route map...</span>
                      </div>
                    </div>
                  <cfelse>
                    <div class="panel-note is-warning">Map geometry is not available from the V2 view model for this trip.</div>
                  </cfif>
                </div>
                <div id="fpwActiveCruiseV2PositionNote" class="panel-note<cfif NOT mapCurrentPositionAvailable> is-warning</cfif>" role="note">
                  <cfif mapCurrentPositionAvailable>
                    Latest reported position: #encodeForHTML(mapCurrentPositionSourceLabel)#<cfif len(mapCurrentPositionUpdatedLabel)> &middot; Updated #encodeForHTML(mapCurrentPositionUpdatedLabel)#</cfif>. FPW is not continuous live vessel tracking.
                  <cfelse>
                    No position update has been reported yet. This map shows the planned route; FPW is not continuous live vessel tracking.
                  </cfif>
                </div>
              </div>

              <div class="header-stats">
                <div class="metric">
                  <span>Scheduled Departure</span>
                  <strong data-fpw-field="hero.tripStart">#encodeForHTML(fpwV2TripScheduleDateTimeLabel(fpwV2Get(activeCruiseV2Model.floatPlan, "scheduledDepartureLocalRaw", fpwV2Get(activeCruiseV2Model.floatPlan, "scheduledDepartureLocal")), activeCruiseV2TripTimezone, "Not available"))#</strong>
                  <small>Planned trip start</small>
                </div>
                <div class="metric">
                  <span>Current Leg</span>
                  <strong data-fpw-field="hero.currentLegSummary">#encodeForHTML(fpwV2Text(fpwV2Get(activeCruiseV2Model.currentLeg, "order"), "Not available"))# of #encodeForHTML(fpwV2Text(fpwV2Get(activeCruiseV2Model.route, "totalLegs"), "0"))#</strong>
                  <small data-fpw-field="hero.legMeta">#encodeForHTML(fpwV2Text(fpwV2Get(activeCruiseV2Model.currentLeg, "statusLabel"), "Current route leg"))#</small>
                </div>
                <div class="metric">
                  <span>Distance Complete</span>
                  <strong data-fpw-field="hero.distanceComplete">#encodeForHTML(fpwV2Number(fpwV2Get(activeCruiseV2Model.currentLeg, "completedNm"), " nm"))#</strong>
                  <small data-fpw-field="hero.percentComplete">#encodeForHTML(fpwV2Percent(fpwV2Get(activeCruiseV2Model.currentLeg, "percentComplete")))# complete</small>
                </div>
                <div class="metric">
                  <span>Next Stop</span>
                  <strong data-fpw-field="hero.nextStop">#encodeForHTML(fpwV2Text(fpwV2Get(activeCruiseV2Model.currentLeg, "toName"), fpwV2Get(activeCruiseV2Model.route, "endLocation", "Not available")))#</strong>
                  <small data-fpw-field="hero.nextStopMeta">Upcoming planned stop</small>
                </div>
                <div class="metric">
                  <span>ETA</span>
                  <strong data-fpw-field="hero.eta">#encodeForHTML(fpwV2TripDateTimeLabel(fpwV2Get(activeCruiseV2Model.currentLeg, "etaUtc"), activeCruiseV2TripTimezone, "Not available"))#</strong>
                  <small data-fpw-field="hero.etaMeta">Active leg ETA</small>
                </div>
              </div>

              <div class="mini-panel mini-panel--route-progress-flat">
                <div class="progress-block">
                  <div class="route-plan-progress-footer route-plan-progress-footer--flat">
                    <div class="route-plan-progress-grid">
                      <div>
                        <span>Complete</span>
                        <strong data-fpw-field="routeProgress.percentComplete">#encodeForHTML(fpwV2Percent(fpwV2Get(activeCruiseV2RouteProgressSummary, "percentComplete")))#</strong>
                      </div>
                      <div>
                        <span>Total Route</span>
                        <strong data-fpw-field="routeProgress.totalLegs">#encodeForHTML(fpwV2Text(fpwV2Get(activeCruiseV2Model.route, "totalLegs"), "0"))# legs</strong>
                      </div>
                      <div>
                        <span>Remaining</span>
                        <strong data-fpw-field="routeProgress.remainingNm">#encodeForHTML(fpwV2Number(fpwV2Get(activeCruiseV2RouteProgressSummary, "remainingNm"), " nm"))#</strong>
                      </div>
                      <div>
                        <span>Final Arrival</span>
                        <strong data-fpw-field="routeProgress.finalArrival" data-route-plan-summary="finalArrivalFooter">#encodeForHTML(fpwV2TripDateTimeLabel(fpwV2Get(activeCruiseV2RouteProgressSummary, "finalArrivalUtc"), activeCruiseV2TripTimezone, fpwV2Text(fpwV2Get(activeCruiseV2Model.route, "endLocation"), "Not available")))#</strong>
                      </div>
                    </div>
                    <div class="route-plan-progress-bar" aria-hidden="true">
                      <span data-fpw-field="routeProgress.progressBar" style="width:#encodeForHTMLAttribute(fpwV2Percent(fpwV2Get(activeCruiseV2RouteProgressSummary, "percentComplete")))#;"></span>
                    </div>
                  </div>
                  <div class="route-leg-estimate" aria-label="Route leg estimate">
                    <div class="route-leg-estimate-head">
                      <h4 class="route-leg-estimate-title">Current Leg Estimate</h4>
                      <span class="route-leg-estimate-state" data-fpw-field="currentLeg.statusLabel">#encodeForHTML(fpwV2Text(fpwV2Get(activeCruiseV2Model.currentLeg, "statusLabel"), "Not available"))#</span>
                    </div>
                    <p class="route-leg-estimate-copy" data-fpw-field="currentLeg.summary">#encodeForHTML(fpwV2Text(fpwV2Get(activeCruiseV2Model.currentLeg, "fromName"), "Not available"))# to #encodeForHTML(fpwV2Text(fpwV2Get(activeCruiseV2Model.currentLeg, "toName"), "Not available"))#</p>
                    <div class="route-leg-estimate-metrics">
                      <div class="route-leg-estimate-metric">
                        <span>Distance</span>
                        <strong data-fpw-field="currentLeg.distanceNm">#encodeForHTML(fpwV2Number(fpwV2Get(activeCruiseV2Model.currentLeg, "distanceNm"), " nm"))#</strong>
                      </div>
                      <div class="route-leg-estimate-metric">
                        <span>Remaining</span>
                        <strong data-fpw-field="currentLeg.remainingNm">#encodeForHTML(fpwV2Number(fpwV2Get(activeCruiseV2Model.currentLeg, "remainingNm"), " nm"))#</strong>
                      </div>
                      <div class="route-leg-estimate-metric">
                        <span>ETA</span>
                        <strong data-fpw-field="currentLeg.etaUtc">#encodeForHTML(fpwV2TripDateTimeLabel(fpwV2Get(activeCruiseV2Model.currentLeg, "etaUtc"), activeCruiseV2TripTimezone, "Not available"))#</strong>
                      </div>
                      <div class="route-leg-estimate-metric">
                        <span>Adjusted Speed</span>
                        <strong data-fpw-field="currentLeg.adjustedSpeedLabel">#encodeForHTML(fpwV2Text(fpwV2Get(activeCruiseV2Model.currentLeg, "adjustedSpeedLabel"), "--"))#</strong>
                      </div>
                      <div class="route-leg-estimate-metric">
                        <span>Weather Factor</span>
                        <strong data-fpw-field="currentLeg.weatherFactorLabel">#encodeForHTML(fpwV2Text(fpwV2Get(activeCruiseV2Model.currentLeg, "weatherFactorLabel"), "0%"))#</strong>
                      </div>
                    </div>
                    <div class="route-leg-estimate-progress">
                      <div class="route-leg-estimate-progress-head"><span>Leg Progress</span><span data-fpw-field="currentLeg.percentComplete">#encodeForHTML(fpwV2Percent(fpwV2Get(activeCruiseV2Model.currentLeg, "percentComplete")))#</span></div>
                      <div class="route-leg-estimate-progress-row"><div class="bar-shell"><div class="bar-fill" data-fpw-field="currentLeg.progressBar" style="width:#encodeForHTMLAttribute(fpwV2Percent(fpwV2Get(activeCruiseV2Model.currentLeg, "percentComplete")))#;"></div></div></div>
                    </div>
                  </div>
                  <section class="ac-v2-panel ac-pace-command-panel" id="fpwV2PacePanel" data-fpw-base="#encodeForHTMLAttribute(activeCruiseV2BasePath)#" data-endpoint="#encodeForHTMLAttribute(fpwV2Text(fpwV2Get(paceUpdateAction, "endpoint"), ""))#" data-method="#encodeForHTMLAttribute(fpwV2Text(fpwV2Get(paceUpdateAction, "method"), "POST"))#" data-payload="#encodeForHTMLAttribute(fpwV2Json(fpwV2Get(paceUpdateAction, "payload", {})))#" data-enabled="#encodeForHTMLAttribute(paceUpdateEnabled ? "true" : "false")#" aria-label="Pace controls">
                    <div class="ac-panel-header">
                      <div>
                        <h2>Pace / Speed</h2>
                        <p>Operational pace for the active trip projection.</p>
                      </div>
                      <span class="pace-header-label">#encodeForHTML(fpwV2Text(fpwV2Get(paceModel, "currentLabel"), "Relaxed"))#</span>
                    </div>
                    <div class="ac-pace-meter">
                      <div class="ac-section-label">Current Pace</div>
                      <strong class="ac-monitor-value" data-fpw-field="pace.currentLabel">#encodeForHTML(fpwV2Text(fpwV2Get(paceModel, "currentLabel"), "Relaxed"))#</strong>
                      <p><span data-fpw-field="pace.weatherAdjustedSpeedLabel">#encodeForHTML(fpwV2Text(fpwV2Get(paceModel, "weatherAdjustedSpeedLabel"), "--"))#</span> after #encodeForHTML(fpwV2Text(fpwV2Get(paceModel, "weatherFactorLabel"), "0%"))# weather factor.</p>
                    </div>
                    <div class="ac-command-section ac-pace-section">
                      <label class="ac-section-label" for="fpwV2PaceSlider">Set Active-Trip Pace</label>
                      <input id="fpwV2PaceSlider" class="ac-pace-slider" type="range" min="0" max="2" step="1" value="#encodeForHTMLAttribute(paceCurrentIndex)#"<cfif !paceUpdateEnabled> disabled</cfif> data-current-value="#encodeForHTMLAttribute(paceCurrentValue)#">
                      <div class="ac-pace-label-row" aria-hidden="true">
                        <cfloop array="#paceOptions#" item="paceOption">
                          <span>#encodeForHTML(fpwV2Text(fpwV2Get(paceOption, "label"), "Pace"))#</span>
                        </cfloop>
                      </div>
                      <cfif len(paceUpdateReason)><p class="ac-muted-note">#encodeForHTML(paceUpdateReason)#</p></cfif>
                    </div>
                    <div class="action-feedback ac-action-ready-message" id="fpwV2PaceFeedback" role="status" aria-live="polite">Change pace to update the active trip projection.</div>
                  </section>
                </div>
              </div>

              <section class="mini-panel ac-weather-command-panel ac-weather-panel--not-checked" id="acV2WeatherPanel" aria-label="Weather lookup" data-weather-panel-state="not-checked">
                <div id="fpwV2WeatherLookup" class="weather-lookup-layout" data-fpw-base="#encodeForHTMLAttribute(activeCruiseV2BasePath)#">
                  <div class="ac-weather-command-header">
                    <div class="ac-weather-command-title">
                      <span class="ac-weather-command-icon" aria-hidden="true">WX</span>
                      <h3>Weather</h3>
                    </div>
                    <form id="fpwV2WeatherForm" class="weather-lookup-form">
                      <div class="weather-choice-row" role="group" aria-label="Current leg weather lookup point">
                        <span class="ac-weather-control-label">Current Leg</span>
                        <label class="weather-choice">
                          <input type="radio" name="fpwV2WeatherPoint" value="start"<cfif structKeyExists(weatherStartPoint, "available") AND weatherStartPoint.available EQ true> checked</cfif><cfif !structKeyExists(weatherStartPoint, "available") OR weatherStartPoint.available NEQ true> disabled</cfif>>
                          <span>#encodeForHTML(fpwV2Text(fpwV2Get(weatherStartPoint, "label"), "Start"))#</span>
                        </label>
                        <label class="weather-choice">
                          <input type="radio" name="fpwV2WeatherPoint" value="end"<cfif (!structKeyExists(weatherStartPoint, "available") OR weatherStartPoint.available NEQ true) AND structKeyExists(weatherEndPoint, "available") AND weatherEndPoint.available EQ true> checked</cfif><cfif !structKeyExists(weatherEndPoint, "available") OR weatherEndPoint.available NEQ true> disabled</cfif>>
                          <span>#encodeForHTML(fpwV2Text(fpwV2Get(weatherEndPoint, "label"), "End"))#</span>
                        </label>
                      </div>
                      <button type="submit" class="btn btn-secondary ac-weather-command-btn"<cfif !weatherLookupAvailable> disabled</cfif>>Check Conditions</button>
                      <span class="ac-weather-status-chip" data-weather-chip="alerts">No alerts</span>
                    </form>
                  </div>
                </div>
                <cfif !weatherLookupAvailable>
                  <div id="fpwV2WeatherFeedback" class="panel-note is-warning ac-weather-status-badge" aria-live="polite" aria-busy="false"><span class="ac-weather-loader" aria-hidden="true"></span><span class="ac-weather-status-text">#encodeForHTML(fpwV2Text(fpwV2Get(weatherModel, "message"), "Weather lookup is not currently available."))#</span></div>
                <cfelse>
                  <div id="fpwV2WeatherFeedback" class="panel-note ac-weather-status-badge" aria-live="polite" aria-busy="false"><span class="ac-weather-loader" aria-hidden="true"></span><span class="ac-weather-status-text">#encodeForHTML(fpwV2Text(fpwV2Get(weatherModel, "message"), "Select a current-leg point and check conditions."))#</span></div>
                </cfif>
                <div class="ac-weather-summary-row" aria-live="polite">
                  <span>Point: <strong data-weather-field="point">Not checked</strong></span>
                  <span>Temperature: <strong data-weather-field="temperature">Not checked</strong></span>
                </div>
                <div id="fpwV2WeatherResult" class="weather-result is-empty" aria-live="polite">
                  <article class="ac-weather-metric-tile">
                    <div class="ac-weather-metric-label">Wind</div>
                    <strong class="ac-weather-metric-value" data-weather-field="wind">Not checked</strong>
                  </article>
                  <article class="ac-weather-metric-tile">
                    <div class="ac-weather-metric-label">Gusts</div>
                    <strong class="ac-weather-metric-value" data-weather-field="gusts">Not checked</strong>
                  </article>
                  <article class="ac-weather-metric-tile">
                    <div class="ac-weather-metric-label">Waves</div>
                    <strong class="ac-weather-metric-value" data-weather-field="waves">Not checked</strong>
                  </article>
                  <article class="ac-weather-metric-tile">
                    <div class="ac-weather-metric-label">Visibility</div>
                    <strong class="ac-weather-metric-value" data-weather-field="visibility">Not checked</strong>
                  </article>
                  <article class="ac-weather-metric-tile">
                    <div class="ac-weather-metric-label">Weather Factor</div>
                    <strong class="ac-weather-metric-value" data-weather-field="weatherFactor">0%</strong>
                  </article>
                  <article class="ac-weather-metric-tile">
                    <div class="ac-weather-metric-label">Alerts</div>
                    <strong class="ac-weather-metric-value" data-weather-field="alerts">Not checked</strong>
                  </article>
                </div>
                <div class="ac-weather-command-footer">
                  <p class="ac-weather-applied-note" data-weather-field="weatherFactorNote"><cfif weatherApplyAvailable>Check conditions to calculate a route weather factor.<cfelse>Weather factor apply is not available in AC-V2.</cfif></p>
                  <button type="button" class="btn btn-secondary ac-weather-command-btn ac-weather-apply-btn" id="fpwV2WeatherApplyBtn" disabled aria-disabled="true">Apply Weather to Route</button>
                </div>
                <cfif arrayLen(weatherWarnings)>
                  <div class="weather-warning-list">
                    <cfloop array="#weatherWarnings#" item="weatherWarning">
                      <cfif isStruct(weatherWarning)>
                        <div class="panel-note is-warning">#encodeForHTML(fpwV2Text(fpwV2Get(weatherWarning, "message"), "Weather lookup warning."))#</div>
                      </cfif>
                    </cfloop>
                  </div>
                </cfif>
              </section>
            </div>

            <div class="panel section-card" id="acV2RouteProgressPanel">
              <cfset selectedRoutePlanLeg = {}>
              <cfset selectedRoutePlanLegIndex = 1>
              <cfif structKeyExists(activeCruiseV2Model.routeTimeline, "available") AND activeCruiseV2Model.routeTimeline.available EQ true AND structKeyExists(activeCruiseV2Model.routeTimeline, "legs") AND arrayLen(activeCruiseV2Model.routeTimeline.legs)>
                <cfset routePlanSelectionIndex = 0>
                <cfset startedRoutePlanLeg = {}>
                <cfset startedRoutePlanLegIndex = 0>
                <cfset currentRoutePlanLeg = {}>
                <cfset currentRoutePlanLegIndex = 0>
                <cfloop array="#activeCruiseV2Model.routeTimeline.legs#" item="routePlanSelectionLeg">
                  <cfset routePlanSelectionIndex = routePlanSelectionIndex + 1>
                  <cfset routePlanSelectionState = lCase(fpwV2Text(fpwV2Get(routePlanSelectionLeg, "state"), ""))>
                  <cfset routePlanSelectionStatus = uCase(fpwV2Text(fpwV2Get(routePlanSelectionLeg, "status"), ""))>
                  <cfif NOT structCount(startedRoutePlanLeg) AND routePlanSelectionStatus EQ "STARTED">
                    <cfset startedRoutePlanLeg = routePlanSelectionLeg>
                    <cfset startedRoutePlanLegIndex = routePlanSelectionIndex>
                  </cfif>
                  <cfif NOT structCount(currentRoutePlanLeg) AND ((structKeyExists(routePlanSelectionLeg, "isCurrent") AND routePlanSelectionLeg.isCurrent EQ true) OR routePlanSelectionState EQ "current")>
                    <cfset currentRoutePlanLeg = routePlanSelectionLeg>
                    <cfset currentRoutePlanLegIndex = routePlanSelectionIndex>
                  </cfif>
                </cfloop>
                <cfif structCount(startedRoutePlanLeg)>
                  <cfset selectedRoutePlanLeg = startedRoutePlanLeg>
                  <cfset selectedRoutePlanLegIndex = startedRoutePlanLegIndex>
                <cfelseif structCount(currentRoutePlanLeg)>
                  <cfset selectedRoutePlanLeg = currentRoutePlanLeg>
                  <cfset selectedRoutePlanLegIndex = currentRoutePlanLegIndex>
                </cfif>
                <cfif NOT structCount(selectedRoutePlanLeg)>
                  <cfset selectedRoutePlanLeg = activeCruiseV2Model.routeTimeline.legs[1]>
                  <cfset selectedRoutePlanLegIndex = 1>
                </cfif>
              </cfif>
              <cfset selectedRoutePlanDistanceLabel = fpwV2Number(fpwV2Get(selectedRoutePlanLeg, "distanceNm"), " nm")>
              <cfset selectedRoutePlanRemainingLabel = fpwV2Number(fpwV2Get(selectedRoutePlanLeg, "remainingNm"), " nm")>
              <cfset selectedRoutePlanCompletedLabel = fpwV2Number(fpwV2Get(selectedRoutePlanLeg, "completedNm"), " nm")>
              <cfset selectedRoutePlanProgressLabel = fpwV2Percent(fpwV2Get(selectedRoutePlanLeg, "percentComplete"))>
              <cfset selectedRoutePlanStatusLabel = fpwV2Text(fpwV2Get(selectedRoutePlanLeg, "status"), fpwV2Get(selectedRoutePlanLeg, "state", "Not available"))>
              <cfset selectedRoutePlanArrivalLabel = fpwV2TripDateTimeLabel(fpwV2Text(fpwV2Get(selectedRoutePlanLeg, "etaUtc"), fpwV2Get(selectedRoutePlanLeg, "arrivalUtc")), activeCruiseV2TripTimezone, "Not available")>
              <cfset selectedRoutePlanEstimatedDurationLabel = fpwV2Text(fpwV2Get(selectedRoutePlanLeg, "estimatedDurationLabel"), "Not available")>
              <cfset selectedRoutePlanRemainingDurationLabel = fpwV2Text(fpwV2Get(selectedRoutePlanLeg, "remainingDurationLabel"), "Not available")>
              <cfset selectedRoutePlanFuel = fpwV2Get(selectedRoutePlanLeg, "fuel", {})>
              <cfset selectedRoutePlanTotalFuelLabel = fpwV2Text(fpwV2Get(selectedRoutePlanFuel, "totalFuelLabel"), "Not available")>
              <cfset selectedRoutePlanLegFuelNeededLabel = fpwV2Text(fpwV2Get(selectedRoutePlanFuel, "legFuelNeededLabel"), "Not available")>
              <cfset selectedRoutePlanFuelReserveLabel = fpwV2Text(fpwV2Get(selectedRoutePlanFuel, "fuelWithReserveLabel"), "Not available")>
              <div class="leg-grid">
                <div class="route-box route-plan-box">
                  <div class="mini-head" style="margin-bottom:12px;">
                    <h3>Route Timeline</h3>
                    <span>#encodeForHTML(fpwV2Text(fpwV2Get(activeCruiseV2Model.route, "totalLegs"), "0"))# legs</span>
                  </div>
                  <div class="route-plan-departure">
                    <div class="route-plan-kicker">Scheduled Departure</div>
                    <strong>#encodeForHTML(fpwV2TripScheduleDateTimeLabel(fpwV2Get(activeCruiseV2Model.floatPlan, "scheduledDepartureLocalRaw", fpwV2Get(activeCruiseV2Model.floatPlan, "scheduledDepartureLocal")), activeCruiseV2TripTimezone, "Not available"))#</strong>
                  </div>
                  <div class="route-plan-scroll" id="acV2RouteLegList">
                    <cfif structKeyExists(activeCruiseV2Model.routeTimeline, "available") AND activeCruiseV2Model.routeTimeline.available EQ true AND structKeyExists(activeCruiseV2Model.routeTimeline, "legs") AND arrayLen(activeCruiseV2Model.routeTimeline.legs)>
                      <cfset routePlanLegIndex = 0>
                      <cfloop array="#activeCruiseV2Model.routeTimeline.legs#" item="routePlanLeg">
                        <cfset routePlanLegIndex = routePlanLegIndex + 1>
                        <cfset routePlanState = lCase(fpwV2Text(fpwV2Get(routePlanLeg, "state"), "future"))>
                        <cfset routePlanLegOrder = fpwV2Text(fpwV2Get(routePlanLeg, "routeLegOrder"), "")>
                        <cfset routePlanStatusLabel = fpwV2Text(fpwV2Get(routePlanLeg, "status"), fpwV2Get(routePlanLeg, "state", "Not available"))>
                        <cfset routePlanTitle = fpwV2Text(fpwV2Get(routePlanLeg, "fromName"), "Not available") & " to " & fpwV2Text(fpwV2Get(routePlanLeg, "toName"), "Not available")>
                        <cfset routePlanDistanceLabel = fpwV2Number(fpwV2Get(routePlanLeg, "distanceNm"), " nm")>
                        <cfset routePlanRemainingLabel = fpwV2Number(fpwV2Get(routePlanLeg, "remainingNm"), " nm")>
                        <cfset routePlanCompletedLabel = fpwV2Number(fpwV2Get(routePlanLeg, "completedNm"), " nm")>
                        <cfset routePlanProgressLabel = fpwV2Percent(fpwV2Get(routePlanLeg, "percentComplete"))>
                        <cfset routePlanDepartureLabel = fpwV2TripDateTimeLabel(fpwV2Get(routePlanLeg, "departureUtc"), activeCruiseV2TripTimezone, "Not available")>
                        <cfset routePlanArrivalLabel = fpwV2TripDateTimeLabel(fpwV2Text(fpwV2Get(routePlanLeg, "etaUtc"), fpwV2Get(routePlanLeg, "arrivalUtc")), activeCruiseV2TripTimezone, "Not available")>
                        <cfset routePlanEstimatedDurationLabel = fpwV2Text(fpwV2Get(routePlanLeg, "estimatedDurationLabel"), "Not available")>
                        <cfset routePlanRemainingDurationLabel = fpwV2Text(fpwV2Get(routePlanLeg, "remainingDurationLabel"), "Not available")>
                        <cfset routePlanFuel = fpwV2Get(routePlanLeg, "fuel", {})>
                        <cfset routePlanTotalFuelLabel = fpwV2Text(fpwV2Get(routePlanFuel, "totalFuelLabel"), "Not available")>
                        <cfset routePlanLegFuelNeededLabel = fpwV2Text(fpwV2Get(routePlanFuel, "legFuelNeededLabel"), "Not available")>
                        <cfset routePlanFuelReserveLabel = fpwV2Text(fpwV2Get(routePlanFuel, "fuelWithReserveLabel"), "Not available")>
                        <cfset routePlanLockSummary = fpwV2Get(routePlanLeg, "lockSummary", {})>
                        <cfset routePlanLocks = (structKeyExists(routePlanLeg, "locks") AND isArray(routePlanLeg.locks) ? routePlanLeg.locks : [])>
                        <cfset routePlanHasLocks = (structKeyExists(routePlanLockSummary, "hasLocks") AND routePlanLockSummary.hasLocks EQ true)>
                        <cfset routePlanLockCountLabel = fpwV2Text(fpwV2Get(routePlanLockSummary, "lockCount"), "0")>
                        <cfset routePlanBestDelayLabel = fpwV2Minutes(fpwV2Get(routePlanLockSummary, "bestDelayMinutes"))>
                        <cfset routePlanTypicalDelayLabel = fpwV2Minutes(fpwV2Get(routePlanLockSummary, "typicalDelayMinutes"))>
                        <cfset routePlanWorstDelayLabel = fpwV2Minutes(fpwV2Get(routePlanLockSummary, "worstDelayMinutes"))>
                        <cfset routePlanDelayLabel = fpwV2Text(fpwV2Get(routePlanLockSummary, "delayLabel"), "Delay estimate unavailable")>
                        <cfset routePlanSelectedClass = "">
                        <cfset routePlanAriaExpanded = "false">
                        <cfif routePlanLegIndex EQ selectedRoutePlanLegIndex>
                          <cfset routePlanSelectedClass = " is-selected">
                          <cfset routePlanAriaExpanded = "true">
                        </cfif>
                        <article class="route-plan-leg route-plan-leg--#encodeForHTMLAttribute(routePlanState)##routePlanSelectedClass#"
                          data-route-plan-leg
                          data-ac-v2-leg-row
                          data-leg-index="#encodeForHTMLAttribute(routePlanLegIndex)#"
                          data-leg-order="#encodeForHTMLAttribute(routePlanLegOrder)#"
                          data-leg-state="#encodeForHTMLAttribute(routePlanState)#"
                          data-leg-title="#encodeForHTMLAttribute(routePlanTitle)#"
                          data-leg-distance="#encodeForHTMLAttribute(routePlanDistanceLabel)#"
                          data-leg-remaining="#encodeForHTMLAttribute(routePlanRemainingLabel)#"
                          data-leg-completed="#encodeForHTMLAttribute(routePlanCompletedLabel)#"
                          data-leg-progress="#encodeForHTMLAttribute(routePlanProgressLabel)#"
                          data-leg-estimated-duration="#encodeForHTMLAttribute(routePlanEstimatedDurationLabel)#"
                          data-leg-remaining-duration="#encodeForHTMLAttribute(routePlanRemainingDurationLabel)#"
                          data-leg-total-fuel="#encodeForHTMLAttribute(routePlanTotalFuelLabel)#"
                          data-leg-fuel-needed="#encodeForHTMLAttribute(routePlanLegFuelNeededLabel)#"
                          data-leg-fuel-reserve="#encodeForHTMLAttribute(routePlanFuelReserveLabel)#"
                          data-leg-status="#encodeForHTMLAttribute(routePlanStatusLabel)#"
                          data-leg-status-label="#encodeForHTMLAttribute(routePlanStatusLabel)#"
                          data-leg-departure="#encodeForHTMLAttribute(routePlanDepartureLabel)#"
                          data-leg-arrival="#encodeForHTMLAttribute(routePlanArrivalLabel)#"
                          data-leg-arrival-label="#encodeForHTMLAttribute(routePlanArrivalLabel)#"
                          data-route-plan-leg-order="#encodeForHTMLAttribute(routePlanLegOrder)#"
                          data-route-plan-state="#encodeForHTMLAttribute(routePlanState)#"
                          role="button"
                          tabindex="0"
                          aria-expanded="#routePlanAriaExpanded#"
                          aria-label="Select route leg #encodeForHTMLAttribute(routePlanTitle)#">
                          <div class="route-plan-leg-button">
                            <span class="route-plan-leg-dot" aria-hidden="true"></span>
                            <span>
                              <span class="route-plan-leg-kicker">#encodeForHTML(routePlanStatusLabel)#</span>
                              <span class="route-plan-leg-title">#encodeForHTML(routePlanTitle)#</span>
                              <span class="route-plan-leg-meta">#encodeForHTML(routePlanDistanceLabel)#</span>
                            </span>
                            <span class="route-plan-leg-side">
                              <span>#encodeForHTML(routePlanArrivalLabel)#</span>
                            </span>
                          </div>
                          <div class="route-plan-leg-detail">
                            <div class="route-plan-detail-grid">
                              <div><span>Departure</span><strong>#encodeForHTML(routePlanDepartureLabel)#</strong></div>
                              <div><span>ETA / Arrival</span><strong>#encodeForHTML(routePlanArrivalLabel)#</strong></div>
                              <div><span>Distance</span><strong>#encodeForHTML(routePlanDistanceLabel)#</strong></div>
                              <div><span>Progress</span><strong>#encodeForHTML(routePlanProgressLabel)#</strong></div>
                            </div>
                            <div class="route-plan-lock-detail">
                              <div class="route-plan-kicker">Lock Navigation Details</div>
                              <div class="route-plan-detail-grid">
                                <div><span>Locks</span><strong>#encodeForHTML(routePlanLockCountLabel)#</strong></div>
                                <div><span>Best Delay</span><strong>#encodeForHTML(routePlanBestDelayLabel)#</strong></div>
                                <div><span>Typical Delay</span><strong>#encodeForHTML(routePlanTypicalDelayLabel)#</strong></div>
                                <div><span>Worst Delay</span><strong>#encodeForHTML(routePlanWorstDelayLabel)#</strong></div>
                              </div>
                              <cfif routePlanHasLocks AND arrayLen(routePlanLocks)>
                                <div class="route-plan-lock-list">
                                  <cfloop array="#routePlanLocks#" item="routePlanLock">
                                    <cfset routePlanLockTitle = fpwV2Text(fpwV2Get(routePlanLock, "name"), fpwV2Text(fpwV2Get(routePlanLock, "lockCode"), "Lock"))>
                                    <cfset routePlanLockCode = fpwV2Text(fpwV2Get(routePlanLock, "lockCode"), "")>
                                    <cfset routePlanLockWaterway = fpwV2Text(fpwV2Get(routePlanLock, "waterway"), "Waterway unavailable")>
                                    <cfset routePlanLockState = fpwV2Text(fpwV2Get(routePlanLock, "state"), "")>
                                    <cfset routePlanLockCountry = fpwV2Text(fpwV2Get(routePlanLock, "country"), "")>
                                    <cfset routePlanLockPlace = trim(routePlanLockState & (len(routePlanLockState) AND len(routePlanLockCountry) ? ", " : "") & routePlanLockCountry)>
                                    <cfset routePlanLockType = fpwV2Text(fpwV2Get(routePlanLock, "lockType"), "type unavailable")>
                                    <cfset routePlanLockChamber = "--">
                                    <cfif isNumeric(fpwV2Get(routePlanLock, "chamberLengthFt")) AND val(fpwV2Get(routePlanLock, "chamberLengthFt")) GT 0 AND isNumeric(fpwV2Get(routePlanLock, "chamberWidthFt")) AND val(fpwV2Get(routePlanLock, "chamberWidthFt")) GT 0>
                                      <cfset routePlanLockChamber = numberFormat(val(fpwV2Get(routePlanLock, "chamberLengthFt")), "0") & " x " & numberFormat(val(fpwV2Get(routePlanLock, "chamberWidthFt")), "0") & " ft">
                                    </cfif>
                                    <cfset routePlanLockLocation = "--">
                                    <cfif isNumeric(fpwV2Get(routePlanLock, "latitude")) AND isNumeric(fpwV2Get(routePlanLock, "longitude"))>
                                      <cfset routePlanLockLocation = numberFormat(val(fpwV2Get(routePlanLock, "latitude")), "0.00000") & ", " & numberFormat(val(fpwV2Get(routePlanLock, "longitude")), "0.00000")>
                                    </cfif>
                                    <cfset routePlanLockDelay = "Best/Typical/Worst: " & fpwV2Minutes(fpwV2Get(routePlanLock, "bestDelayMinutes")) & " / " & fpwV2Minutes(fpwV2Get(routePlanLock, "typicalDelayMinutes")) & " / " & fpwV2Minutes(fpwV2Get(routePlanLock, "worstDelayMinutes"))>
                                    <article class="route-plan-lock-item">
                                      <h4>###encodeForHTML(fpwV2Text(fpwV2Get(routePlanLock, "sequence"), ""))# #encodeForHTML(routePlanLockTitle)#<cfif len(routePlanLockCode)> <small>#encodeForHTML(routePlanLockCode)#</small></cfif></h4>
                                      <div class="route-plan-lock-meta">
                                        <div><strong>Waterway</strong><br>#encodeForHTML(routePlanLockWaterway)#</div>
                                        <div><strong>Place</strong><br>#encodeForHTML(fpwV2Text(routePlanLockPlace, "--"))#</div>
                                        <div><strong>Type</strong><br>#encodeForHTML(routePlanLockType)#</div>
                                        <div><strong>Chamber</strong><br>#encodeForHTML(routePlanLockChamber)#</div>
                                        <div><strong>Agency</strong><br>#encodeForHTML(fpwV2Text(fpwV2Get(routePlanLock, "agency"), "--"))#</div>
                                        <div><strong>Delay</strong><br>#encodeForHTML(routePlanLockDelay)#</div>
                                        <div><strong>Lat/Lng</strong><br>#encodeForHTML(routePlanLockLocation)#</div>
                                        <div><strong>Source</strong><br>#encodeForHTML(fpwV2Text(fpwV2Get(routePlanLock, "source"), "--"))#</div>
                                      </div>
                                      <cfif len(fpwV2Text(fpwV2Get(routePlanLock, "delayNotes"), ""))>
                                        <p class="route-plan-lock-note">Delay notes: #encodeForHTML(fpwV2Text(fpwV2Get(routePlanLock, "delayNotes"), ""))#</p>
                                      </cfif>
                                      <cfif len(fpwV2Text(fpwV2Get(routePlanLock, "notes"), ""))>
                                        <p class="route-plan-lock-note">Notes: #encodeForHTML(fpwV2Text(fpwV2Get(routePlanLock, "notes"), ""))#</p>
                                      </cfif>
                                    </article>
                                  </cfloop>
                                </div>
                              <cfelse>
                                <p class="route-plan-lock-note">#encodeForHTML(routePlanDelayLabel)#.</p>
                              </cfif>
                            </div>
                          </div>
                        </article>
                      </cfloop>
                      <div class="route-plan-final">
                        <div class="route-plan-kicker">Final Destination</div>
                        <strong>#encodeForHTML(fpwV2Text(fpwV2Get(activeCruiseV2Model.route, "endLocation"), "Not available"))#</strong>
                        <span>#encodeForHTML(fpwV2TripDateTimeLabel(fpwV2Get(activeCruiseV2Model.currentLeg, "etaUtc"), activeCruiseV2TripTimezone, "ETA unavailable"))#</span>
                      </div>
                    <cfelse>
                      <div class="route-plan-final">
                        <div class="route-plan-kicker">Route Plan</div>
                        <strong>Not available</strong>
                        <span>No canonical route timeline is available from the V2 model.</span>
                      </div>
                    </cfif>
                  </div>
                </div>

                <div class="detail-box route-selected-leg-box" id="acV2SelectedLegPanel">
                  <div class="mini-head" style="margin-bottom:16px;">
                    <h3 id="acV2SelectedLegPanelTitle">Selected Leg Data</h3>
                    <span>V2 Model</span>
                  </div>
                  <div class="data-grid">
                    <div class="data-item"><span>Distance</span><strong data-selected-leg-field="distance">#encodeForHTML(selectedRoutePlanDistanceLabel)#</strong><small>Total leg length</small></div>
                    <div class="data-item"><span>Remaining</span><strong data-selected-leg-field="remaining">#encodeForHTML(selectedRoutePlanRemainingLabel)#</strong><small>From selected leg model</small></div>
                    <div class="data-item"><span>Est. Leg Time</span><strong data-selected-leg-field="estimatedDuration">#encodeForHTML(selectedRoutePlanEstimatedDurationLabel)#</strong><small>Projected full duration</small></div>
                    <div class="data-item"><span>Time Left</span><strong data-selected-leg-field="remainingDuration">#encodeForHTML(selectedRoutePlanRemainingDurationLabel)#</strong><small>Projected remaining duration</small></div>
                    <div class="data-item"><span>Completed</span><strong data-selected-leg-field="completed">#encodeForHTML(selectedRoutePlanCompletedLabel)#</strong><small>Selected leg completed distance</small></div>
                    <div class="data-item"><span>Progress</span><strong data-selected-leg-field="progress">#encodeForHTML(selectedRoutePlanProgressLabel)#</strong><small>Selected leg progress</small></div>
                    <div class="data-item"><span>Status</span><strong data-selected-leg-field="status">#encodeForHTML(selectedRoutePlanStatusLabel)#</strong><small>Selected leg status</small></div>
                    <div class="data-item"><span>Arrival</span><strong data-selected-leg-field="arrival">#encodeForHTML(selectedRoutePlanArrivalLabel)#</strong><small>ETA / arrival</small></div>
                    <div class="data-item"><span>Total Fuel</span><strong data-selected-leg-field="totalFuel">#encodeForHTML(selectedRoutePlanTotalFuelLabel)#</strong><small>Route estimate</small></div>
                    <div class="data-item"><span>Fuel + Reserve</span><strong data-selected-leg-field="fuelReserve">#encodeForHTML(selectedRoutePlanFuelReserveLabel)#</strong><small>Route estimate with reserve</small></div>
                    <div class="data-item"><span>Leg Fuel Needed</span><strong data-selected-leg-field="legFuelNeeded">#encodeForHTML(selectedRoutePlanLegFuelNeededLabel)#</strong><small>Selected leg estimate</small></div>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <div class="stack">
            <div class="panel section-card">
              <div class="floatplan-box">
                <div class="mini-panel">
                  <div class="mini-head">
                    <h3>Shore Contact</h3>
                    <span>#encodeForHTML(fpwV2Text(fpwV2Get(floatPlanMonitorModel, "attachmentLabel"), "Attached"))#</span>
                  </div>
                  <div class="split"><span>Status</span><strong style="color:#encodeForHTMLAttribute(fpwV2Text(fpwV2Get(floatPlanMonitorModel, "statusColor"), "var(--muted)"))#;" data-fpw-field="monitor.status">#encodeForHTML(fpwV2Text(fpwV2Get(floatPlanMonitorModel, "statusLabel"), "Unknown"))#</strong></div>
                  <div class="split" style="margin-top:10px;"><span>Trip Page</span><strong style="color:var(--accent);" data-fpw-field="monitor.followerState">#encodeForHTML(fpwV2Text(fpwV2Get(floatPlanMonitorModel, "tripPageLabel"), "Not linked"))#</strong></div>
                  <div class="split" style="margin-top:10px;"><span>Contact</span><strong data-fpw-field="monitor.emergencyContact">#encodeForHTML(fpwV2Text(fpwV2Get(floatPlanMonitorContact, "name"), "Shore contact not named"))#</strong></div>
                  <cfif len(floatPlanMonitorPhoneHref) OR len(floatPlanMonitorSmsHref) OR len(floatPlanMonitorEmailHref)>
                    <div class="contact-reference-actions" aria-label="Shore contact actions">
                      <cfif len(floatPlanMonitorPhoneHref)>
                        <a class="contact-reference-action" data-fpw-field="contacts.monitor.phoneLink" href="#encodeForHTMLAttribute(floatPlanMonitorPhoneHref)#">
                          <span aria-hidden="true">&##9742;</span>
                          <span>Call</span>
                        </a>
                      </cfif>
                      <cfif len(floatPlanMonitorSmsHref)>
                        <a class="contact-reference-action" data-fpw-field="contacts.monitor.smsLink" href="#encodeForHTMLAttribute(floatPlanMonitorSmsHref)#">
                          <span aria-hidden="true">&##128172;</span>
                          <span>Text</span>
                        </a>
                      </cfif>
                      <cfif len(floatPlanMonitorEmailHref)>
                        <a class="contact-reference-action" data-fpw-field="contacts.monitor.emailLink" href="#encodeForHTMLAttribute(floatPlanMonitorEmailHref)#">
                          <span aria-hidden="true">&##9993;</span>
                          <span>Email</span>
                        </a>
                      </cfif>
                    </div>
                  </cfif>
                </div>
              </div>
            </div>

            <div class="panel section-card">
              <div class="action-box ac-checkin-command-panel ac-v2-compact-checkin-panel" id="acCheckInPanel">
                <div class="captain-actions" id="fpwV2ActionPanel" data-fpw-base="#encodeForHTMLAttribute(activeCruiseV2BasePath)#">
                  <div class="ac-panel-header">
                    <div>
                      <h2>Check-In &amp; Route Control</h2>
                      <p>Update status and route actions.</p>
                    </div>
                  </div>

                  <cfset checkAction = {}>
                  <cfif structKeyExists(activeCruiseV2Model.actions, "checkIn") AND isStruct(activeCruiseV2Model.actions.checkIn)>
                    <cfset checkAction = activeCruiseV2Model.actions.checkIn>
                  </cfif>
                  <cfset checkStatusOptions = []>
                  <cfif structKeyExists(activeCruiseV2Model.checkIn, "allowedStatusOptions") AND isArray(activeCruiseV2Model.checkIn.allowedStatusOptions)>
                    <cfset checkStatusOptions = activeCruiseV2Model.checkIn.allowedStatusOptions>
                  </cfif>

                  <div class="ac-command-section" aria-label="Check-in status actions">
                    <div class="ac-section-label">Status</div>
                    <cfif arrayLen(checkStatusOptions)>
                      <cfset routineStatusNames = [ "On Track", "Delayed", "Changed Plan", "Secure for the Night" ]>
                      <cfset renderedRoutineStatusCount = 0>
                      <div class="ac-status-grid ac-status-compact-grid">
                        <cfloop array="#routineStatusNames#" item="routineStatusName">
                          <cfset statusOption = {}>
                          <cfloop array="#checkStatusOptions#" item="candidateStatusOption">
                            <cfif compareNoCase(fpwV2Text(fpwV2Get(candidateStatusOption, "status"), ""), routineStatusName) EQ 0>
                              <cfset statusOption = candidateStatusOption>
                              <cfbreak>
                            </cfif>
                          </cfloop>
                          <cfif structCount(statusOption)>
                            <cfset renderedRoutineStatusCount++>
                            <cfset checkPayload = {}>
                            <cfif structKeyExists(checkAction, "payload") AND isStruct(checkAction.payload)>
                              <cfset checkPayload = duplicate(checkAction.payload)>
                            </cfif>
                            <cfset checkPayload.status = fpwV2Text(fpwV2Get(statusOption, "status"), "")>
                            <cfset checkEnabled = fpwV2ActionEnabled(checkAction) AND fpwV2Get(statusOption, "enabled", true) EQ true>
                            <cfset checkReason = fpwV2Text(fpwV2Get(statusOption, "disabledReason"), fpwV2Text(fpwV2Get(checkAction, "reason"), ""))>
                            <cfif checkEnabled><cfset checkReason = ""></cfif>
                            <cfset checkStatusText = fpwV2Text(fpwV2Get(statusOption, "status"), "Status")>
                            <cfset checkDisplayText = checkStatusText>
                            <cfset checkStatusClass = "ontrack">
                            <cfset checkIcon = "&##10003;">
                            <cfif compareNoCase(checkStatusText, "Delayed") EQ 0>
                              <cfset checkStatusClass = "delayed">
                              <cfset checkIcon = "&##9719;">
                            <cfelseif compareNoCase(checkStatusText, "Changed Plan") EQ 0>
                              <cfset checkStatusClass = "changed">
                              <cfset checkIcon = "&##8605;">
                            <cfelseif compareNoCase(checkStatusText, "Secure for the Night") EQ 0>
                              <cfset checkStatusClass = "secure">
                              <cfset checkIcon = "&##9790;">
                              <cfset checkDisplayText = "Secure Night">
                            </cfif>
                            <div class="ac-status-cell">
                              <button type="button" class="ac-command-btn ac-status-btn ac-status-#encodeForHTMLAttribute(checkStatusClass)#" data-ac-v2-action="checkin" data-endpoint="#encodeForHTMLAttribute(fpwV2Text(fpwV2Get(checkAction, "endpoint"), ""))#" data-payload="#encodeForHTMLAttribute(fpwV2Json(checkPayload))#" data-confirmation-required="#encodeForHTMLAttribute(toString(fpwV2Get(statusOption, "confirmationRequired", false)))#" data-confirmation-message="#encodeForHTMLAttribute(fpwV2Text(fpwV2Get(statusOption, "confirmationMessage"), ""))#"<cfif !checkEnabled> disabled aria-disabled="true"</cfif>><span class="ac-command-icon" aria-hidden="true">#checkIcon#</span><span>#encodeForHTML(checkDisplayText)#</span></button>
                              <cfif len(checkReason)><div class="action-reason" title="#encodeForHTMLAttribute(checkReason)#">#encodeForHTML(checkReason)#</div></cfif>
                            </div>
                          </cfif>
                        </cfloop>
                      </div>
                      <cfif renderedRoutineStatusCount EQ 0>
                        <p>No routine check-in status options were returned by the view model.</p>
                      </cfif>

                    <cfelse>
                      <p>No check-in status options were returned by the view model.</p>
                    </cfif>
                  </div>

                  <div class="ac-command-section ac-v2-note-compact" aria-label="Check-in note" data-ac-v2-note-shell>
                    <button type="button" class="ac-v2-note-toggle" data-ac-v2-note-toggle aria-expanded="false" aria-controls="fpwV2CheckInNoteShell">
                      <span>+ Add optional note</span>
                      <span class="ac-note-counter" id="fpwV2CheckInNoteCounter">0/500</span>
                    </button>
                    <div class="ac-v2-note-collapsible" id="fpwV2CheckInNoteShell" data-ac-v2-note-collapsible hidden>
                      <textarea id="fpwV2CheckInNote" class="ac-checkin-note checkin-note-input" maxlength="500" placeholder="Optional note for this check-in"></textarea>
                    </div>
                  </div>

                  <div class="ac-command-section ac-route-actions-compact" aria-label="Route and float plan actions">
                    <div class="ac-section-label">Route Actions</div>
                    <cfset routeActions = [
                      { "key" = "completeLeg", "label" = "Complete Current Leg / Arrived", "icon" = "&##9873;", "description" = "Mark this leg complete." },
                      { "key" = "startNextLeg", "label" = "Start Next Leg", "icon" = "&##10140;", "description" = "Start the next pending route leg." },
                      { "key" = "closeFloatPlan", "label" = "Close Float Plan", "icon" = "&##9633;", "description" = "Close this active float plan." }
                    ]>
                    <cfloop array="#routeActions#" item="routeAction">
                      <cfset routeActionModel = {}>
                      <cfif structKeyExists(activeCruiseV2Model.actions, routeAction.key) AND isStruct(activeCruiseV2Model.actions[routeAction.key])>
                        <cfset routeActionModel = activeCruiseV2Model.actions[routeAction.key]>
                      </cfif>
                      <cfset routeActionEnabled = fpwV2ActionEnabled(routeActionModel)>
                      <cfset routeActionReason = fpwV2Text(fpwV2Get(routeActionModel, "reason"), "")>
                      <cfif routeActionEnabled>
                        <div class="ac-route-action-cell">
                          <button type="button" class="ac-command-btn ac-route-action-btn" data-ac-v2-action="#encodeForHTMLAttribute(routeAction.key)#" data-endpoint="#encodeForHTMLAttribute(fpwV2Text(fpwV2Get(routeActionModel, "endpoint"), ""))#" data-payload="#encodeForHTMLAttribute(fpwV2Json(fpwV2Get(routeActionModel, "payload", {})))#" data-confirmation-required="#encodeForHTMLAttribute(toString(fpwV2Get(routeActionModel, "confirmationRequired", false)))#" data-confirmation-message="#encodeForHTMLAttribute(fpwV2Text(fpwV2Get(routeActionModel, "confirmationMessage"), ""))#"><span class="ac-command-icon" aria-hidden="true">#routeAction.icon#</span><span><strong>#encodeForHTML(routeAction.label)#</strong><small>#encodeForHTML(routeAction.description)#</small></span></button>
                        </div>
                      <cfelse>
                        <div class="ac-disabled-action-row" aria-disabled="true">
                          <span class="ac-command-icon" aria-hidden="true">#routeAction.icon#</span>
                          <span>
                            <strong>#encodeForHTML(routeAction.label)# unavailable</strong>
                            <small title="#encodeForHTMLAttribute(fpwV2Text(routeActionReason, "Unavailable from the current view model state."))#">#encodeForHTML(fpwV2Text(routeActionReason, "Unavailable from the current view model state."))#</small>
                          </span>
                        </div>
                      </cfif>
                    </cfloop>
                  </div>
                  <div class="action-feedback ac-action-ready-message" id="fpwV2ActionFeedback" role="status" aria-live="polite" hidden aria-hidden="true">Ready. Actions submit existing endpoint and payload contracts returned by the view model.</div>
                </div>
              </div>
            </div>

            <div class="panel section-card">
              <section class="ac-v2-panel ac-monitor-command-panel" id="fpwV2TimingPanel" data-fpw-base="#encodeForHTMLAttribute(activeCruiseV2BasePath)#" aria-label="Timing controls">
                <div class="ac-monitor-grid">
                  <article class="ac-monitor-tile">
                    <div class="ac-section-label">Last Check-In</div>
                    <strong class="ac-monitor-value" data-fpw-field="floatPlan.lastCheckIn">#encodeForHTML(fpwV2TripDateTimeLabel(fpwV2Get(activeCruiseV2Model.monitoring, "lastCheckinAtUtc"), activeCruiseV2TripTimezone, "Not available"))#</strong>
                    <p>Captain confirmed status</p>
                  </article>
                  <article class="ac-monitor-tile">
                    <div class="ac-section-label">Secure for Night</div>
                    <strong class="ac-monitor-value" data-fpw-field="monitor.secureForNight"><cfif fpwV2Get(activeCruiseV2Model.monitoring, "secureForNight", false) EQ true>YES<cfelse>NO</cfif></strong>
                    <p>#encodeForHTML(fpwV2TripDateTimeLabel(fpwV2Get(activeCruiseV2Model.monitoring, "secureForNightUntilUtc"), activeCruiseV2TripTimezone, "Secure-until unavailable"))#</p>
                  </article>
                  <article class="ac-monitor-tile">
                    <div class="ac-section-label">Next Expected Check-In</div>
                    <strong class="ac-monitor-value" data-fpw-field="monitor.nextExpectedCheckIn">#encodeForHTML(fpwV2TripDateTimeLabel(fpwV2Get(activeCruiseV2Model.monitoring, "expectedCheckinAtUtc"), activeCruiseV2TripTimezone, fpwV2Text(fpwV2Get(activeCruiseV2Model.monitoring, "expectedCheckinLocalLabel"), "Not available")))#</strong>
                    <p>Canonical monitoring checkpoint</p>
                  </article>
                  <article class="ac-monitor-tile ac-delay-tile">
                    <div class="ac-section-label">Current Delay</div>
                    <strong class="ac-monitor-value" data-fpw-field="delay.currentTotal">#encodeForHTML(fpwV2Text(fpwV2Get(activeCruiseV2Model.monitoring, "manualDelayLabel"), "0 minutes"))#</strong>
                    <p>Current manual delay total applied to canonical trip timing.</p>
                    <button type="button" class="ac-command-btn ac-clear-delay-btn" data-ac-v2-timing-action="clearDelay" data-endpoint="#encodeForHTMLAttribute(fpwV2Text(fpwV2Get(timingClearDelayAction, "endpoint"), ""))#" data-method="#encodeForHTMLAttribute(fpwV2Text(fpwV2Get(timingClearDelayAction, "method"), "POST"))#" data-payload="#encodeForHTMLAttribute(fpwV2Json(fpwV2Get(timingClearDelayAction, "payload", {})))#" data-confirmation-required="#encodeForHTMLAttribute(toString(fpwV2Get(timingClearDelayAction, "confirmationRequired", false)))#" data-confirmation-message="#encodeForHTMLAttribute(fpwV2Text(fpwV2Get(timingClearDelayAction, "confirmationMessage"), ""))#"<cfif !clearDelayEnabled> disabled aria-disabled="true"</cfif>>#encodeForHTML(fpwV2Text(fpwV2Get(timingClearDelayAction, "label"), "Clear Delay"))#</button>
                    <cfif len(clearDelayReason)><p class="ac-muted-note">#encodeForHTML(clearDelayReason)#</p></cfif>
                  </article>
                </div>

                <div class="ac-command-section ac-delay-section">
                  <div class="ac-section-label">Add Delay Time</div>
                  <h3>Manual timing adjustment</h3>
                  <p>Add positive minutes to the active trip timeline without changing monitoring cadence.</p>
                  <div class="ac-inline-control-row">
                    <input id="fpwV2AddDelayMinutes" class="timing-input" type="number" min="1" step="1" inputmode="numeric" placeholder="0"<cfif !addDelayEnabled> disabled</cfif>>
                    <button type="button" class="ac-command-btn" data-ac-v2-timing-action="addDelay" data-endpoint="#encodeForHTMLAttribute(fpwV2Text(fpwV2Get(timingAddDelayAction, "endpoint"), ""))#" data-method="#encodeForHTMLAttribute(fpwV2Text(fpwV2Get(timingAddDelayAction, "method"), "POST"))#" data-payload="#encodeForHTMLAttribute(fpwV2Json(fpwV2Get(timingAddDelayAction, "payload", {})))#" data-confirmation-required="#encodeForHTMLAttribute(toString(fpwV2Get(timingAddDelayAction, "confirmationRequired", false)))#" data-confirmation-message="#encodeForHTMLAttribute(fpwV2Text(fpwV2Get(timingAddDelayAction, "confirmationMessage"), ""))#"<cfif !addDelayEnabled> disabled aria-disabled="true"</cfif>>#encodeForHTML(fpwV2Text(fpwV2Get(timingAddDelayAction, "label"), "Add Delay Time"))#</button>
                  </div>
                  <cfif len(addDelayReason)><p class="ac-muted-note">#encodeForHTML(addDelayReason)#</p></cfif>
                </div>

                <div class="ac-command-section ac-daily-start-section">
                  <div class="ac-section-label">Daily Start Time</div>
                  <strong class="ac-monitor-value" data-fpw-field="monitor.dailyStartLabel">#encodeForHTML(fpwV2TripLocalTimeLabel(fpwV2Get(activeCruiseV2Model.monitoring, "dailyStartLocalTime"), activeCruiseV2TripTimezone, fpwV2Get(activeCruiseV2Model.floatPlan, "scheduledDepartureUtc"), "08:00 " & fpwV2TripTimezoneLabel(activeCruiseV2TripTimezone, fpwV2Get(activeCruiseV2Model.floatPlan, "scheduledDepartureUtc"))))#</strong>
                  <p>Applied to overnight resume and next-day monitoring.</p>
                  <div class="ac-inline-control-row">
                    <input id="fpwV2DailyStartLocalTime" class="timing-input" type="time" step="60" value="#encodeForHTMLAttribute(dailyStartInputValue)#"<cfif !dailyStartEnabled> disabled</cfif>>
                    <button type="button" class="ac-command-btn" data-ac-v2-timing-action="updateDailyStart" data-endpoint="#encodeForHTMLAttribute(fpwV2Text(fpwV2Get(timingDailyStartAction, "endpoint"), ""))#" data-method="#encodeForHTMLAttribute(fpwV2Text(fpwV2Get(timingDailyStartAction, "method"), "POST"))#" data-payload="#encodeForHTMLAttribute(fpwV2Json(fpwV2Get(timingDailyStartAction, "payload", {})))#" data-confirmation-required="#encodeForHTMLAttribute(toString(fpwV2Get(timingDailyStartAction, "confirmationRequired", false)))#" data-confirmation-message="#encodeForHTMLAttribute(fpwV2Text(fpwV2Get(timingDailyStartAction, "confirmationMessage"), ""))#"<cfif !dailyStartEnabled> disabled aria-disabled="true"</cfif>>#encodeForHTML(fpwV2Text(fpwV2Get(timingDailyStartAction, "label"), "Save Daily Start Time"))#</button>
                  </div>
                  <div class="action-feedback ac-action-ready-message" id="fpwV2DailyStartFeedback" role="status" aria-live="polite" hidden aria-hidden="true"></div>
                  <cfif len(dailyStartReason)><p class="ac-muted-note">#encodeForHTML(dailyStartReason)#</p></cfif>
                </div>

                <div class="action-feedback ac-action-ready-message" id="fpwV2TimingFeedback" role="status" aria-live="polite" hidden aria-hidden="true"></div>
              </section>
            </div>

            <div class="panel section-card">
              <div class="stack">
                <div class="timeline-box">
                  <div class="mini-head" style="margin-bottom:16px;">
                    <h3>Today's Timeline</h3>
                    <span>Newest First</span>
                  </div>
                  <cfif structKeyExists(privateTimelineModel, "items") AND isArray(privateTimelineModel.items) AND arrayLen(privateTimelineModel.items)>
                    <div class="timeline today-checkin-history">
                      <cfloop array="#privateTimelineModel.items#" item="historyItem">
                        <cfset historyDetail = fpwV2Text(fpwV2Get(historyItem, "detail"), "")>
                        <cfset historyNote = fpwV2Text(fpwV2Get(historyItem, "note"), "")>
                        <div class="timeline-row">
                          <div class="timeline-time">#encodeForHTML(fpwV2TripDateTimeLabel(fpwV2Get(historyItem, "occurredAtUtc"), activeCruiseV2TripTimezone, fpwV2Text(fpwV2Get(historyItem, "occurredLocalLabel"), "time unavailable")))#</div>
                          <div class="timeline-node"></div>
                          <div class="timeline-copy">
                            <b>#encodeForHTML(fpwV2Text(fpwV2Get(historyItem, "title"), "Operational event"))#</b>
                            <span>#encodeForHTML(len(historyDetail) ? historyDetail : "Private operational event recorded.")#</span>
                            <cfif len(historyNote)>
                              <span>#encodeForHTML(historyNote)#</span>
                            </cfif>
                            <span class="timeline-source">Private operational timeline</span>
                          </div>
                        </div>
                      </cfloop>
                    </div>
                  <cfelse>
                    <div class="captain-note-empty">Private timeline events will appear here after the next Active Cruise V2 action.</div>
                  </cfif>
                </div>
                <div class="log-box">
                  <div class="mini-head" style="margin-bottom:16px;">
                    <h3>Quick Notes</h3>
                    <span>Private by Default</span>
                  </div>
                  <cfset captainLogSaveEnabled = fpwV2ActionEnabled(captainLogSaveAction)>
                  <cfset captainLogSaveReason = fpwV2Text(fpwV2Get(captainLogSaveAction, "reason"), fpwV2Text(fpwV2Get(captainLogSaveAction, "disabledReason"), ""))>
                  <cfset captainLogTags = [ "All good", "Underway", "Weather delay", "Anchored", "Docking", "Fuel", "Mechanical", "Marina call" ]>
                  <div class="captain-quick-note-form" id="fpwV2CaptainQuickNoteForm" data-fpw-base="#encodeForHTMLAttribute(activeCruiseV2BasePath)#" data-endpoint="#encodeForHTMLAttribute(fpwV2Text(fpwV2Get(captainLogSaveAction, "endpoint"), ""))#" data-method="#encodeForHTMLAttribute(fpwV2Text(fpwV2Get(captainLogSaveAction, "method"), "POST"))#" data-payload="#encodeForHTMLAttribute(fpwV2Json(fpwV2Get(captainLogSaveAction, "payload", {})))#" data-enabled="#encodeForHTMLAttribute(captainLogSaveEnabled ? "true" : "false")#" data-trip-timezone="#encodeForHTMLAttribute(activeCruiseV2TripTimezone)#">
                    <label class="captain-note-label" for="fpwV2CaptainQuickNoteInput">
                      <span>Add captain note</span>
                      <small>Private by default</small>
                    </label>
                    <textarea id="fpwV2CaptainQuickNoteInput" class="captain-note-input" rows="3" maxlength="1200" placeholder="Write a quick captain note for this trip."<cfif !captainLogSaveEnabled> disabled</cfif>></textarea>
                    <div class="captain-note-tags" aria-label="Captain note presets">
                      <cfloop array="#captainLogTags#" item="captainLogTag">
                        <button type="button" class="captain-note-tag" data-fpw-v2-captain-note-tag="#encodeForHTMLAttribute(captainLogTag)#"<cfif !captainLogSaveEnabled> disabled</cfif>>#encodeForHTML(captainLogTag)#</button>
                      </cfloop>
                    </div>
                    <label class="captain-note-post-option">
                      <input type="checkbox" id="fpwV2CaptainQuickNotePost"<cfif !captainLogSaveEnabled> disabled</cfif>>
                      <span>Also post this note to the Trip status page voyage stream.</span>
                    </label>
                    <div class="captain-note-help">Leave unchecked for a private captain log entry only.</div>
                    <div class="captain-note-message" id="fpwV2CaptainQuickNoteMessage" role="status" aria-live="polite"><cfif captainLogSaveEnabled>Ready to save a private captain note.<cfelse>#encodeForHTML(fpwV2Text(captainLogSaveReason, "Captain note writing is not available from the current view model."))#</cfif></div>
                    <button type="button" class="captain-note-save" id="fpwV2CaptainQuickNoteSaveBtn"<cfif !captainLogSaveEnabled> disabled</cfif>>Save Note</button>
                  </div>
                  <cfif structKeyExists(captainLogModel, "items") AND isArray(captainLogModel.items) AND arrayLen(captainLogModel.items)>
                    <div class="log-list captain-note-log-list" id="fpwV2CaptainQuickNoteList">
                      <cfloop array="#captainLogModel.items#" item="logItem">
                        <cfset logPostedBadge = (val(fpwV2Get(logItem, "posted_to_stream", 0)) EQ 1 ? "POSTED" : "PRIVATE")>
                        <div class="log-row">
                          <div>
                            <b>#encodeForHTML(fpwV2Text(fpwV2Get(logItem, "note_tag"), "Captain note"))#</b>
                            <span>#encodeForHTML(fpwV2Text(fpwV2Get(logItem, "note_body"), "No note text returned."))#</span>
                          </div>
                          <div class="captain-note-meta">
                            <div class="action-mini">#encodeForHTML(logPostedBadge)#</div>
                            <span>#encodeForHTML(fpwV2TripDateTimeLabel(fpwV2Get(logItem, "created_utc"), activeCruiseV2TripTimezone, "time unavailable"))#</span>
                          </div>
                        </div>
                      </cfloop>
                    </div>
                  <cfelse>
                    <div class="log-list captain-note-log-list" id="fpwV2CaptainQuickNoteList"></div>
                    <div class="captain-note-empty" id="fpwV2CaptainQuickNoteEmpty">Private captain notes will appear here after they are saved.</div>
                  </cfif>
                </div>
              </div>
            </div>

            <section class="panel active-cruise-reference-card fpw-contact-reference-card" aria-labelledby="crew-emergency-title">
              <div class="reference-card-header">
                <div>
                  <h2 id="crew-emergency-title">Crew &amp; Passengers</h2>
                </div>
              </div>
              <div class="contact-reference-stack">
                <article class="contact-reference-panel contact-reference-panel--primary">
                  <div class="contact-reference-main">
                    <div class="contact-reference-icon" aria-hidden="true"><span class="contact-reference-icon-symbol">&##9875;</span></div>
                    <div class="contact-reference-content">
                      <div class="contact-reference-kicker">Captain / Operator</div>
                      <div class="contact-reference-name">#encodeForHTML(fpwV2Text(fpwV2Get(operatorModel, "name"), "Not available"))#</div>
                      <div class="contact-reference-subtext">#encodeForHTML(fpwV2Text(fpwV2Get(activeCruiseV2Model.floatPlan, "name"), "Float plan name unavailable"))#</div>
                    </div>
                  </div>
                </article>
                <article class="contact-reference-panel contact-reference-panel--crew">
                  <div class="contact-reference-main">
                    <div class="contact-reference-icon" aria-hidden="true"><span class="contact-reference-icon-symbol">&##128101;</span></div>
                    <div class="contact-reference-content">
                      <div class="contact-reference-kicker">Crew / Passengers</div>
                      <div class="contact-reference-name">#encodeForHTML(fpwV2Text(fpwV2Get(contactsModel, "passengerCount"), fpwV2Text(fpwV2Get(contactsModel, "count"), "0")))# listed</div>
                    </div>
                  </div>
                  <cfif structKeyExists(contactsModel, "passengers") AND isArray(contactsModel.passengers) AND arrayLen(contactsModel.passengers)>
                    <div class="contact-reference-crew-list">
                      <cfloop from="1" to="#min(2, arrayLen(contactsModel.passengers))#" index="passengerIndex">
                        <cfset passengerItem = contactsModel.passengers[passengerIndex]>
                        <div class="contact-reference-crew-row">
                          <span class="contact-reference-dot" aria-hidden="true"></span>
                          <span class="contact-reference-crew-name">#encodeForHTML(fpwV2Text(fpwV2Get(passengerItem, "name"), "Unnamed passenger"))#</span>
                          <span class="contact-reference-crew-role">Passenger</span>
                        </div>
                      </cfloop>
                    </div>
                  <cfelse>
                    <div class="contact-reference-empty">No crew/passengers listed</div>
                  </cfif>
                </article>
                <article class="contact-reference-panel">
                  <div class="contact-reference-main">
                    <div class="contact-reference-icon" aria-hidden="true"><span class="contact-reference-icon-symbol">&##9993;</span></div>
                    <div class="contact-reference-content">
                      <div class="contact-reference-kicker">Notification Contacts</div>
                      <div class="contact-reference-name">#encodeForHTML(fpwV2Text(fpwV2Get(contactsModel, "count"), "0"))# contacts</div>
                      <div class="contact-reference-subtext">Read-only from activeCruiseV2Model.contacts.</div>
                    </div>
                  </div>
                </article>
              </div>
            </section>

          </div>
        </section>

        <cfset showActiveCruiseDiagnosticsPanel = false>
        <cfif showActiveCruiseDiagnosticsPanel>
          <section class="warning-panel" aria-label="Warnings and authority diagnostics">
            <div class="section-header">
              <h2>Warnings / Diagnostics</h2>
              <span class="authority-pill">#fpwV2WarningCount(activeCruiseV2Model)# warnings</span>
            </div>
            <p>Projection, view-model consistency, missing-authority, and contradiction warnings remain visible during development.</p>
            <cfif structKeyExists(activeCruiseV2Model, "warnings") AND arrayLen(activeCruiseV2Model.warnings)>
              <div class="warning-list">
                <cfloop array="#activeCruiseV2Model.warnings#" item="warningItem">
                  <div class="warning-item">
                    <h3>#encodeForHTML(fpwV2Text(fpwV2Get(warningItem, "code"), "Warning"))#</h3>
                    <p>#encodeForHTML(fpwV2Text(fpwV2Get(warningItem, "message"), "No message returned."))#</p>
                    <div class="warning-source">Source: #encodeForHTML(fpwV2Text(fpwV2Get(warningItem, "source"), "Not available"))#</div>
                  </div>
                </cfloop>
              </div>
            <cfelse>
              <p>No warnings returned by the view model.</p>
            </cfif>
          </section>
        </cfif>
      </cfif>
    </div>
  </main>
  <cfif activeCruiseV2AccessValid>
    <div class="ac-v2-map-modal" id="fpwActiveCruiseV2FullMapModal" aria-hidden="true" hidden>
      <div class="ac-v2-map-modal-dialog" role="dialog" aria-modal="true" aria-labelledby="fpwActiveCruiseV2FullMapTitle">
        <div class="ac-v2-map-modal-head">
          <h2 class="ac-v2-map-modal-title" id="fpwActiveCruiseV2FullMapTitle">Full Route Map</h2>
          <button class="ac-v2-map-modal-close" id="fpwActiveCruiseV2FullMapClose" type="button" aria-label="Close full map">&times;</button>
        </div>
        <div class="ac-v2-map-modal-body">
          <div class="ac-v2-map-modal-canvas" id="fpwActiveCruiseV2FullMap" aria-label="Full route map from Active Cruise V2 view model"></div>
          <div id="fpwActiveCruiseV2FullMapStatus" class="map-load-state is-visible" aria-live="polite">
            <span>Loading full route map...</span>
          </div>
        </div>
      </div>
    </div>
    <script id="fpwActiveCruiseV2MapPayload" type="application/json">#fpwV2JsonForScript(mapModel)#</script>
    <script id="fpwActiveCruiseV2WeatherPayload" type="application/json">#fpwV2JsonForScript(weatherModel)#</script>
  </cfif>
  <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js" integrity="sha256-20nQCchB9co0qIjJZRGuk2/Z9VM+kNiyxNV1lvTlZBo=" crossorigin=""></script>
  <script src="#encodeForHTMLAttribute(activeCruiseV2BasePath)#/assets/js/app/follow/followMap.js?v=20260527-cache-bump"></script>
  <script src="#encodeForHTMLAttribute(activeCruiseV2BasePath)#/assets/js/app/shared/route-weather-assist.js?v=20260527-cache-bump"></script>
  <script src="#encodeForHTMLAttribute(activeCruiseV2BasePath)#/assets/js/maps/leaflet-noaa-waypoint-map.js?v=20260527-cache-bump"></script>
  <script src="#encodeForHTMLAttribute(activeCruiseV2BasePath)#/assets/js/maps/fpw-weather-overlays.js?v=20260527-cache-bump"></script>
</cfoutput>
<cfinclude template="../includes/footer.cfm">
<script>
(function() {
  const mapEl = document.getElementById('fpwActiveCruiseV2Map');
  const payloadEl = document.getElementById('fpwActiveCruiseV2MapPayload');
  const statusEl = document.getElementById('fpwActiveCruiseV2MapStatus');
  const fullMapButton = document.getElementById('fpwActiveCruiseV2OpenFullMapBtn');
  const fullMapModal = document.getElementById('fpwActiveCruiseV2FullMapModal');
  const fullMapCloseButton = document.getElementById('fpwActiveCruiseV2FullMapClose');
  const fullMapEl = document.getElementById('fpwActiveCruiseV2FullMap');
  const fullMapStatusEl = document.getElementById('fpwActiveCruiseV2FullMapStatus');
  let fullMapInstance = null;
  let fullMapRouteLayer = null;
  let fullMapPinLayer = null;
  let fullMapBoatMarker = null;
  let fullMapReturnFocusEl = null;

  function setMapStatus(message, visible) {
    const label = statusEl ? statusEl.querySelector('span') : null;
    if (!statusEl || !label) {
      return;
    }
    label.textContent = message;
    statusEl.classList.toggle('is-visible', visible === true);
  }

  function setFullMapStatus(message, visible) {
    const label = fullMapStatusEl ? fullMapStatusEl.querySelector('span') : null;
    if (!fullMapStatusEl || !label) {
      return;
    }
    label.textContent = message;
    fullMapStatusEl.classList.toggle('is-visible', visible === true);
  }

  function safeNumber(value) {
    const numberValue = parseFloat(value);
    return Number.isFinite(numberValue) ? numberValue : null;
  }

  function normalizePoint(raw) {
    if (!raw || typeof raw !== 'object' || raw.available !== true) {
      return null;
    }
    const lat = safeNumber(raw.lat);
    const lng = safeNumber(raw.lng !== undefined ? raw.lng : raw.lon);
    if (lat === null || lng === null) {
      return null;
    }
    return {
      lat: lat,
      lng: lng,
      name: String(raw.name || '').trim()
    };
  }

  function normalizeMapCoordinate(raw) {
    if (!raw || typeof raw !== 'object') {
      return null;
    }
    const lat = safeNumber(raw.lat !== undefined ? raw.lat : raw.latitude);
    const lng = safeNumber(raw.lng !== undefined ? raw.lng : (raw.lon !== undefined ? raw.lon : raw.longitude));
    if (lat === null || lng === null) {
      return null;
    }
    return {
      lat: lat,
      lng: lng,
      name: String(raw.name || raw.label || '').trim()
    };
  }

  function buildRouteGeo(mapModel) {
    const legs = Array.isArray(mapModel.legs) ? mapModel.legs : [];
    const coordinates = [];

    legs.forEach(function(leg) {
      const fromPoint = normalizePoint(leg && leg.from);
      const toPoint = normalizePoint(leg && leg.to);
      if (!fromPoint || !toPoint) {
        return;
      }
      coordinates.push([
        [fromPoint.lng, fromPoint.lat],
        [toPoint.lng, toPoint.lat]
      ]);
    });

    return {
      type: 'MultiLineString',
      coordinates: coordinates
    };
  }

  function normalizeRouteGeo(rawRouteGeo) {
    if (!rawRouteGeo || typeof rawRouteGeo !== 'object') {
      return null;
    }
    if (!Array.isArray(rawRouteGeo.coordinates)) {
      return null;
    }
    return rawRouteGeo;
  }

  function hasRouteCoordinates(routeGeo) {
    return !!(
      routeGeo &&
      typeof routeGeo === 'object' &&
      Array.isArray(routeGeo.coordinates) &&
      routeGeo.coordinates.length
    );
  }

  function buildPins(mapModel) {
    const legs = Array.isArray(mapModel.legs) ? mapModel.legs : [];
    const pins = [];

    function pointsMatch(left, right) {
      if (!left || !right) {
        return false;
      }
      return Math.abs(left.lat - right.lat) < 0.000001 && Math.abs(left.lng - right.lng) < 0.000001;
    }

    function pushPin(point, type) {
      const prior = pins.length ? pins[pins.length - 1] : null;
      if (!point) {
        return;
      }
      if (prior && pointsMatch(prior, point)) {
        if (type === 'end') {
          prior.type = 'end';
          prior.label = point.name || prior.label || 'End';
        }
        return;
      }
      pins.push({
        type: type,
        label: point.name || (type === 'start' ? 'Start' : (type === 'end' ? 'End' : 'Waypoint')),
        lat: point.lat,
        lng: point.lng,
        sequence: pins.length + 1
      });
    }

    if (legs.length) {
      pushPin(normalizePoint(legs[0] && legs[0].from), 'start');
    }
    legs.forEach(function(leg, index) {
      pushPin(normalizePoint(leg && leg.to), index === legs.length - 1 ? 'end' : 'intermediate');
    });
    if (pins.length === 1) {
      pins[0].type = 'end';
    }
    return pins;
  }

  function readMapPayload() {
    if (!payloadEl) {
      return {};
    }
    try {
      return JSON.parse(payloadEl.textContent || '{}');
    } catch (error) {
      return {};
    }
  }

  function renderMap() {
    const mapModel = readMapPayload();
    const routeGeo = normalizeRouteGeo(mapModel.routeGeo);
    const pins = (Array.isArray(mapModel.pins) && mapModel.pins.length) ? mapModel.pins : buildPins(mapModel);
    const currentPosition = normalizePoint(mapModel.currentPosition);
    const hasRouteGeometry = hasRouteCoordinates(routeGeo);
    const hasMapPins = pins.length > 0;
    let mapInstance = null;

    if (!mapEl || !payloadEl) {
      return;
    }
    if (!window.L || !window.FPWFollowMap || typeof window.FPWFollowMap.initFollowMap !== 'function') {
      setMapStatus('Leaflet map renderer is not available.', true);
      return;
    }
    if (!mapModel.available || (!hasRouteGeometry && !hasMapPins)) {
      setMapStatus('Map geometry is not available from the V2 view model.', true);
      return;
    }

    mapInstance = window.FPWFollowMap.initFollowMap('fpwActiveCruiseV2Map', {});
    if (window.FPW && typeof window.FPW.attachLeafletMarineLayers === 'function') {
      window.FPW.attachLeafletMarineLayers({
        map: mapInstance,
        includeRadar: false
      });
    }
    if (window.FPW && typeof window.FPW.attachLeafletWeatherOverlays === 'function') {
      window.FPW.attachLeafletWeatherOverlays({
        map: mapInstance,
        mode: 'activeCruise'
      });
    }
    if (hasRouteGeometry) {
      window.FPWFollowMap.renderRoute(routeGeo);
    }
    window.FPWFollowMap.renderPins(pins);
    window.FPWFollowMap.fitBoundsToRoute(routeGeo, pins);

    if (currentPosition && typeof window.FPWFollowMap.updateBoatMarker === 'function') {
      window.FPWFollowMap.updateBoatMarker(currentPosition.lat, currentPosition.lng, currentPosition.name || 'Latest reported position');
    }
    if (mapInstance && typeof mapInstance.invalidateSize === 'function') {
      window.setTimeout(function() {
        mapInstance.invalidateSize();
        window.FPWFollowMap.fitBoundsToRoute(routeGeo, pins);
      }, 100);
    }

    mapEl.setAttribute('data-ac-v2-map-rendered', 'true');
    mapEl.setAttribute('data-ac-v2-map-point-count', String(pins.length));
    setMapStatus('Route map loaded.', false);
  }

  function buildFullMapRouteLayer(mapInstance, routeGeo) {
    if (!mapInstance || !window.L || !routeGeo) {
      return null;
    }
    return window.L.geoJSON(routeGeo, {
      style: {
        color: '#5b7cfa',
        weight: 4,
        opacity: 0.92,
        lineJoin: 'round',
        lineCap: 'round'
      }
    }).addTo(mapInstance);
  }

  function makeFullMapPinIcon(type) {
    let pinType = String(type || 'intermediate').toLowerCase();
    if (pinType !== 'start' && pinType !== 'end') {
      pinType = 'intermediate';
    }
    return window.L.divIcon({
      className: 'marine-poi-icon follow-map-marker',
      html: '<span class="follow-pin ' + pinType + '"></span>',
      iconSize: [17, 17],
      iconAnchor: [8.5, 8.5]
    });
  }

  function makeFullMapBoatIcon() {
    return window.L.divIcon({
      className: 'marine-poi-icon follow-map-marker',
      html: '<span class="follow-boat-marker"></span>',
      iconSize: [17, 17],
      iconAnchor: [8.5, 8.5]
    });
  }

  function resetFullMapLayers() {
    if (!fullMapInstance) {
      return;
    }
    if (fullMapRouteLayer) {
      fullMapInstance.removeLayer(fullMapRouteLayer);
      fullMapRouteLayer = null;
    }
    if (fullMapPinLayer) {
      fullMapInstance.removeLayer(fullMapPinLayer);
      fullMapPinLayer = null;
    }
    if (fullMapBoatMarker) {
      fullMapInstance.removeLayer(fullMapBoatMarker);
      fullMapBoatMarker = null;
    }
  }

  function fitFullMapBounds() {
    const bounds = window.L.latLngBounds([]);
    if (!fullMapInstance || !window.L) {
      return;
    }
    if (fullMapRouteLayer && typeof fullMapRouteLayer.getBounds === 'function') {
      const routeBounds = fullMapRouteLayer.getBounds();
      if (routeBounds && routeBounds.isValid()) {
        bounds.extend(routeBounds);
      }
    }
    if (fullMapPinLayer && typeof fullMapPinLayer.eachLayer === 'function') {
      fullMapPinLayer.eachLayer(function(layer) {
        if (layer && typeof layer.getLatLng === 'function') {
          bounds.extend(layer.getLatLng());
        }
      });
    }
    if (fullMapBoatMarker && typeof fullMapBoatMarker.getLatLng === 'function') {
      bounds.extend(fullMapBoatMarker.getLatLng());
    }
    if (bounds.isValid()) {
      fullMapInstance.fitBounds(bounds, {
        padding: [28, 28],
        maxZoom: 11
      });
    }
  }

  function ensureFullMapInstance() {
    let baseLayer = null;
    if (fullMapInstance || !fullMapEl || !window.L) {
      return fullMapInstance;
    }
    fullMapInstance = window.L.map(fullMapEl, {
      zoomControl: true,
      preferCanvas: true
    }).setView([39.5, -95.5], 4);
    baseLayer = window.L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      maxZoom: 18,
      attribution: '&copy; OpenStreetMap'
    }).addTo(fullMapInstance);
    if (window.FPW && typeof window.FPW.attachLeafletMarineLayers === 'function') {
      window.FPW.attachLeafletMarineLayers({
        map: fullMapInstance,
        baseLayer: baseLayer,
        includeRadar: false
      });
    }
    if (window.FPW && typeof window.FPW.attachLeafletWeatherOverlays === 'function') {
      window.FPW.attachLeafletWeatherOverlays({
        map: fullMapInstance,
        mode: 'activeCruise'
      });
    }
    return fullMapInstance;
  }

  function renderFullMap() {
    const mapModel = readMapPayload();
    const routeGeo = normalizeRouteGeo(mapModel.routeGeo);
    const pins = (Array.isArray(mapModel.pins) && mapModel.pins.length) ? mapModel.pins : buildPins(mapModel);
    const currentPosition = normalizePoint(mapModel.currentPosition);
    const mapInstance = ensureFullMapInstance();
    const hasRouteGeometry = hasRouteCoordinates(routeGeo);
    const hasMapPins = pins.length > 0;

    if (!mapInstance) {
      setFullMapStatus('Leaflet map renderer is not available.', true);
      return;
    }
    if (!mapModel.available || (!hasRouteGeometry && !hasMapPins)) {
      setFullMapStatus('Map geometry is not available from the V2 view model.', true);
      return;
    }

    resetFullMapLayers();
    fullMapRouteLayer = (hasRouteGeometry ? buildFullMapRouteLayer(mapInstance, routeGeo) : null);
    fullMapPinLayer = window.L.layerGroup().addTo(mapInstance);
    pins.forEach(function(pin) {
      const point = normalizeMapCoordinate(pin);
      const sequence = safeNumber(pin && pin.sequence);
      let label = String((pin && pin.label) || 'Point').trim() || 'Point';
      let marker = null;
      if (!point) {
        return;
      }
      if (sequence !== null) {
        label += ' (#' + String(Math.round(sequence)) + ')';
      }
      marker = window.L.marker([point.lat, point.lng], {
        icon: makeFullMapPinIcon(pin && pin.type)
      }).addTo(fullMapPinLayer);
      marker.bindTooltip(label, {
        direction: 'top',
        opacity: 0.92
      });
    });
    if (currentPosition) {
      fullMapBoatMarker = window.L.marker([currentPosition.lat, currentPosition.lng], {
        icon: makeFullMapBoatIcon()
      }).addTo(mapInstance);
      fullMapBoatMarker.bindTooltip(currentPosition.name || 'Latest reported position', {
        direction: 'right',
        opacity: 0.9
      });
    }
    window.setTimeout(function() {
      mapInstance.invalidateSize();
      fitFullMapBounds();
      setFullMapStatus('Full route map loaded.', false);
    }, 100);
  }

  function openFullMapModal() {
    if (!fullMapModal || !fullMapButton) {
      return;
    }
    fullMapReturnFocusEl = document.activeElement;
    fullMapModal.hidden = false;
    fullMapModal.classList.add('is-open');
    fullMapModal.setAttribute('aria-hidden', 'false');
    document.body.classList.add('ac-v2-map-modal-open');
    setFullMapStatus('Loading full route map...', true);
    window.setTimeout(renderFullMap, 60);
    if (fullMapCloseButton) {
      fullMapCloseButton.focus();
    }
  }

  function closeFullMapModal() {
    if (!fullMapModal) {
      return;
    }
    fullMapModal.classList.remove('is-open');
    fullMapModal.setAttribute('aria-hidden', 'true');
    fullMapModal.hidden = true;
    document.body.classList.remove('ac-v2-map-modal-open');
    if (fullMapReturnFocusEl && typeof fullMapReturnFocusEl.focus === 'function') {
      fullMapReturnFocusEl.focus();
    }
    fullMapReturnFocusEl = null;
  }

  function setupFullMapModal() {
    if (!fullMapButton || !fullMapModal || !fullMapEl) {
      return;
    }
    fullMapButton.addEventListener('click', function() {
      if (fullMapButton.disabled) {
        return;
      }
      openFullMapModal();
    });
    if (fullMapCloseButton) {
      fullMapCloseButton.addEventListener('click', closeFullMapModal);
    }
    fullMapModal.addEventListener('click', function(event) {
      if (event.target === fullMapModal) {
        closeFullMapModal();
      }
    });
    document.addEventListener('keydown', function(event) {
      if (event.key === 'Escape' && fullMapModal.classList.contains('is-open')) {
        closeFullMapModal();
      }
    });
  }

  function initializeMaps() {
    renderMap();
    setupFullMapModal();
  }

  window.FPWActiveCruiseV2 = window.FPWActiveCruiseV2 || {};
  window.FPWActiveCruiseV2.refreshMapPosition = function() {
    const mapModel = readMapPayload();
    const currentPosition = normalizePoint(mapModel.currentPosition);
    if (currentPosition && window.FPWFollowMap && typeof window.FPWFollowMap.updateBoatMarker === 'function') {
      window.FPWFollowMap.updateBoatMarker(
        currentPosition.lat,
        currentPosition.lng,
        currentPosition.name || 'Latest reported position'
      );
    }
  };

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initializeMaps);
  } else {
    initializeMaps();
  }
})();

window.FPWActiveCruiseV2 = window.FPWActiveCruiseV2 || {};
window.FPWActiveCruiseV2.fieldSelectorValue = function(value) {
  return String(value || '').replace(/\\/g, '\\\\').replace(/"/g, '\\"');
};
window.FPWActiveCruiseV2.refreshFromDocument = function(sourceDoc, options) {
  const settings = options || {};
  const replaceSelectors = Array.isArray(settings.replaceSelectors) ? settings.replaceSelectors : [];
  const sourceMapPayloadEl = sourceDoc ? sourceDoc.getElementById('fpwActiveCruiseV2MapPayload') : null;
  const targetMapPayloadEl = document.getElementById('fpwActiveCruiseV2MapPayload');
  const sourcePayloadEl = sourceDoc ? sourceDoc.getElementById('fpwActiveCruiseV2WeatherPayload') : null;
  const targetPayloadEl = document.getElementById('fpwActiveCruiseV2WeatherPayload');

  if (!sourceDoc) {
    throw new Error('Active Cruise V2 refresh data unavailable.');
  }

  Array.from(sourceDoc.querySelectorAll('[data-fpw-field]')).forEach(function(sourceFieldNode) {
    const fieldName = String(sourceFieldNode.getAttribute('data-fpw-field') || '').trim();
    if (!fieldName) {
      return;
    }
    document.querySelectorAll('[data-fpw-field="' + window.FPWActiveCruiseV2.fieldSelectorValue(fieldName) + '"]').forEach(function(targetNode) {
      targetNode.textContent = sourceFieldNode.textContent;
      if (sourceFieldNode.hasAttribute('style')) {
        targetNode.setAttribute('style', sourceFieldNode.getAttribute('style'));
      } else {
        targetNode.removeAttribute('style');
      }
    });
  });

  const sourceHeroStatusField = sourceDoc.querySelector('[data-fpw-field="hero.voyageStatus"]');
  const targetHeroStatusField = document.querySelector('[data-fpw-field="hero.voyageStatus"]');
  if (sourceHeroStatusField && targetHeroStatusField) {
    const sourceStatusPill = sourceHeroStatusField.closest('.status-pill');
    const targetStatusPill = targetHeroStatusField.closest('.status-pill');
    if (sourceStatusPill && targetStatusPill) {
      targetStatusPill.className = sourceStatusPill.className;
    }
  }

  replaceSelectors.forEach(function(selector) {
    const sourceNode = sourceDoc.querySelector(selector);
    const targetNode = document.querySelector(selector);
    if (sourceNode && targetNode) {
      targetNode.replaceWith(sourceNode.cloneNode(true));
    }
  });

  if (targetPayloadEl && sourcePayloadEl) {
    targetPayloadEl.textContent = sourcePayloadEl.textContent || '{}';
  }
  if (targetMapPayloadEl && sourceMapPayloadEl) {
    targetMapPayloadEl.textContent = sourceMapPayloadEl.textContent || '{}';
  }
  if (typeof window.FPWActiveCruiseV2.refreshMapPosition === 'function') {
    window.FPWActiveCruiseV2.refreshMapPosition();
  }

  if (typeof window.FPWActiveCruiseV2.bindRouteProgressPanel === 'function') {
    window.FPWActiveCruiseV2.bindRouteProgressPanel();
  }
  if (typeof window.FPWActiveCruiseV2.bindPacePanel === 'function') {
    window.FPWActiveCruiseV2.bindPacePanel();
  }
  if (typeof window.FPWActiveCruiseV2.bindTimingPanel === 'function') {
    window.FPWActiveCruiseV2.bindTimingPanel();
  }
  if (typeof window.FPWActiveCruiseV2.bindActionPanel === 'function') {
    window.FPWActiveCruiseV2.bindActionPanel();
  }
};
window.FPWActiveCruiseV2.fetchAndRefresh = function(options) {
  return fetch(window.location.href, {
    method: 'GET',
    credentials: 'same-origin',
    cache: 'no-store',
    headers: {
      'Accept': 'text/html'
    }
  })
    .then(function(response) {
      if (!response.ok) {
        throw new Error('Active Cruise V2 refresh failed.');
      }
      return response.text();
    })
    .then(function(html) {
      const parser = new window.DOMParser();
      const refreshedDoc = parser.parseFromString(html, 'text/html');
      window.FPWActiveCruiseV2.refreshFromDocument(refreshedDoc, options || {});
    });
};

window.FPWActiveCruiseV2.bindRouteProgressPanel = function() {
  const panel = document.getElementById('acV2RouteProgressPanel');
  if (!panel) {
    return;
  }
  if (panel.getAttribute('data-ac-v2-route-progress-bound') === 'true') {
    return;
  }

  const rows = Array.from(panel.querySelectorAll('[data-ac-v2-leg-row]'));
  if (!rows.length) {
    return;
  }
  panel.setAttribute('data-ac-v2-route-progress-bound', 'true');

  const fields = {
    distance: panel.querySelector('[data-selected-leg-field="distance"]'),
    remaining: panel.querySelector('[data-selected-leg-field="remaining"]'),
    estimatedDuration: panel.querySelector('[data-selected-leg-field="estimatedDuration"]'),
    remainingDuration: panel.querySelector('[data-selected-leg-field="remainingDuration"]'),
    completed: panel.querySelector('[data-selected-leg-field="completed"]'),
    progress: panel.querySelector('[data-selected-leg-field="progress"]'),
    status: panel.querySelector('[data-selected-leg-field="status"]'),
    arrival: panel.querySelector('[data-selected-leg-field="arrival"]'),
    totalFuel: panel.querySelector('[data-selected-leg-field="totalFuel"]'),
    legFuelNeeded: panel.querySelector('[data-selected-leg-field="legFuelNeeded"]'),
    fuelReserve: panel.querySelector('[data-selected-leg-field="fuelReserve"]')
  };

  function valueFrom(row, key, fallback) {
    const value = row && row.dataset ? row.dataset[key] : '';
    return value || fallback || 'Not available';
  }

  function isStartedLeg(row) {
    const status = row && row.dataset ? String(row.dataset.legStatus || row.dataset.legStatusLabel || '').toUpperCase() : '';
    return status === 'STARTED';
  }

  function isCurrentLeg(row) {
    const state = row && row.dataset ? String(row.dataset.legState || row.dataset.routePlanState || '').toLowerCase() : '';
    return state === 'current';
  }

  function isExpandedRow(row) {
    return !!row && (row.classList.contains('is-selected') || row.getAttribute('aria-expanded') === 'true');
  }

  function collapseRow(row) {
    if (!row) {
      return;
    }
    row.classList.remove('is-selected');
    row.setAttribute('aria-expanded', 'false');
  }

  function scrollRowToTop(row) {
    const list = row ? row.closest('#acV2RouteLegList') : null;
    if (!list) {
      return;
    }

    const listRect = list.getBoundingClientRect();
    const rowRect = row.getBoundingClientRect();
    const top = list.scrollTop + rowRect.top - listRect.top;
    list.scrollTo({
      top: Math.max(0, top),
      behavior: 'smooth'
    });
  }

  function selectRow(row, options) {
    const settings = options || {};
    if (!row) {
      return;
    }

    rows.forEach(function(candidate) {
      const isSelected = candidate === row;
      candidate.classList.toggle('is-selected', isSelected);
      candidate.setAttribute('aria-expanded', isSelected ? 'true' : 'false');
    });

    if (fields.distance) fields.distance.textContent = valueFrom(row, 'legDistance');
    if (fields.remaining) fields.remaining.textContent = valueFrom(row, 'legRemaining');
    if (fields.estimatedDuration) fields.estimatedDuration.textContent = valueFrom(row, 'legEstimatedDuration');
    if (fields.remainingDuration) fields.remainingDuration.textContent = valueFrom(row, 'legRemainingDuration');
    if (fields.completed) fields.completed.textContent = valueFrom(row, 'legCompleted');
    if (fields.progress) fields.progress.textContent = valueFrom(row, 'legProgress');
    if (fields.status) fields.status.textContent = valueFrom(row, 'legStatusLabel');
    if (fields.arrival) fields.arrival.textContent = valueFrom(row, 'legArrivalLabel', valueFrom(row, 'legArrival'));
    if (fields.totalFuel) fields.totalFuel.textContent = valueFrom(row, 'legTotalFuel');
    if (fields.legFuelNeeded) fields.legFuelNeeded.textContent = valueFrom(row, 'legFuelNeeded');
    if (fields.fuelReserve) fields.fuelReserve.textContent = valueFrom(row, 'legFuelReserve');

    if (settings.focus === true && typeof row.focus === 'function') {
      try {
        row.focus({ preventScroll: true });
      } catch (focusError) {
        row.focus();
      }
    }
    if (settings.scroll === true) {
      scrollRowToTop(row);
    }
  }

  rows.forEach(function(row) {
    row.addEventListener('click', function(event) {
      const mainRow = event.target ? event.target.closest('.route-plan-leg-button') : null;
      if (!mainRow || !row.contains(mainRow)) {
        return;
      }
      if (isExpandedRow(row)) {
        collapseRow(row);
        return;
      }
      selectRow(row, { scroll: true, focus: true });
    });

    row.addEventListener('keydown', function(event) {
      if (event.key === 'Enter' || event.key === ' ') {
        event.preventDefault();
        if (isExpandedRow(row)) {
          collapseRow(row);
          return;
        }
        selectRow(row, { scroll: true });
      }
    });
  });

  selectRow(
    rows.find(isStartedLeg) ||
    rows.find(function(row) {
      return row.classList.contains('is-selected') || row.getAttribute('aria-expanded') === 'true';
    }) ||
    rows.find(isCurrentLeg) ||
    rows[0]
  );
};
window.FPWActiveCruiseV2.bindRouteProgressPanel();

(function() {
  const root = document.getElementById('fpwV2WeatherLookup');
  const form = document.getElementById('fpwV2WeatherForm');
  const feedback = document.getElementById('fpwV2WeatherFeedback');
  const result = document.getElementById('fpwV2WeatherResult');
  const payloadEl = document.getElementById('fpwActiveCruiseV2WeatherPayload');
  const weatherPanel = document.getElementById('acV2WeatherPanel') || root;
  const summaryRow = weatherPanel ? weatherPanel.querySelector('.ac-weather-summary-row') : null;
  const commandFooter = weatherPanel ? weatherPanel.querySelector('.ac-weather-command-footer') : null;
  const applyButton = document.getElementById('fpwV2WeatherApplyBtn');
  const routeWeatherAssist = (window.FPW && window.FPW.RouteWeatherAssist) ? window.FPW.RouteWeatherAssist : null;
  const weatherLoadingStages = [
    'Checking current-leg weather...',
    'Getting marine conditions...',
    'Checking wind, waves, visibility, and alerts...',
    'Calculating route weather factor...',
    'Almost done - applying conditions to this leg...'
  ];
  const WEATHER_LOOKUP_TIMEOUT_MS = 25000;
  const weatherLookupState = {
    point: '',
    data: null,
    suggestedPct: null,
    requestSeq: 0,
    hasSuccessfulData: false
  };
  let weatherLoadingTimer = null;
  let weatherLoadingStageIndex = 0;
  let weatherCheckInFlight = false;

  if (!root || !form || !result || !payloadEl) {
    return;
  }

  function readWeatherModel() {
    try {
      return JSON.parse(payloadEl.textContent || '{}');
    } catch (error) {
      return {};
    }
  }

  function getAny(source, keys, fallback) {
    if (!source || typeof source !== 'object') {
      return fallback;
    }
    for (let index = 0; index < keys.length; index += 1) {
      if (Object.prototype.hasOwnProperty.call(source, keys[index]) && source[keys[index]] !== null && source[keys[index]] !== undefined) {
        return source[keys[index]];
      }
    }
    return fallback;
  }

  function firstArrayItem(value) {
    return Array.isArray(value) && value.length && value[0] && typeof value[0] === 'object' ? value[0] : {};
  }

  function textValue(value, fallback) {
    if (value === null || value === undefined) {
      return fallback;
    }
    const text = String(value).trim();
    return text ? text : fallback;
  }

  function isTrueValue(value) {
    if (value === true) {
      return true;
    }
    if (typeof value === 'number') {
      return value > 0;
    }
    if (typeof value === 'string') {
      const text = value.trim().toLowerCase();
      return text === 'true' || text === '1' || text === 'yes';
    }
    return false;
  }

  function joinParts(parts, fallback) {
    const value = parts.map(function(part) {
      return textValue(part, '');
    }).filter(Boolean).join(' ');
    return value || fallback;
  }

  function resolveEndpoint(endpoint) {
    const basePath = root.getAttribute('data-fpw-base') || '';
    if (endpoint && endpoint.indexOf('/api/') === 0 && basePath) {
      return basePath + endpoint;
    }
    return endpoint || '';
  }

  function setFeedback(message, state) {
    if (!feedback) {
      return;
    }
    const statusText = feedback.querySelector('.ac-weather-status-text');
    if (statusText) {
      statusText.textContent = message;
    } else {
      feedback.textContent = message;
    }
    feedback.classList.remove('is-warning', 'is-success', 'is-error');
    if (state) {
      feedback.classList.add(state);
    }
  }

  function setWeatherPanelState(state, message) {
    if (!weatherPanel) {
      return;
    }
    const panelState = state || 'notChecked';
    const panelClassSuffix = panelState === 'notChecked' ? 'not-checked' : panelState;
    const hasData = weatherLookupState.hasSuccessfulData === true;
    const isLoading = panelState === 'loading';
    const hideWeatherDetails = panelState === 'notChecked' || panelState === 'loading' || (panelState === 'error' && !hasData);

    weatherPanel.classList.remove(
      'ac-weather-panel--not-checked',
      'ac-weather-panel--loading',
      'ac-weather-panel--checked',
      'ac-weather-panel--error',
      'ac-weather-panel--has-data'
    );
    weatherPanel.classList.add('ac-weather-panel--' + panelClassSuffix);
    weatherPanel.classList.toggle('ac-weather-panel--has-data', hasData);
    weatherPanel.setAttribute('data-weather-panel-state', panelState);

    if (summaryRow) {
      summaryRow.hidden = hideWeatherDetails;
    }
    if (result) {
      result.hidden = hideWeatherDetails;
    }
    if (commandFooter) {
      commandFooter.hidden = hideWeatherDetails;
    }
    if (feedback) {
      feedback.setAttribute('aria-busy', isLoading ? 'true' : 'false');
      feedback.classList.toggle('ac-weather-status-badge--loading', isLoading);
    }
    if (message !== undefined) {
      if (panelState === 'checked') {
        setFeedback(message, 'is-success');
      } else if (panelState === 'error') {
        setFeedback(message, 'is-error');
      } else {
        setFeedback(message, '');
      }
    }
  }

  function stopWeatherLoading() {
    if (weatherLoadingTimer) {
      window.clearInterval(weatherLoadingTimer);
      weatherLoadingTimer = null;
    }
  }

  function startWeatherLoading() {
    stopWeatherLoading();
    weatherLoadingStageIndex = 0;
    setWeatherPanelState('loading', weatherLoadingStages[weatherLoadingStageIndex]);
    weatherLoadingTimer = window.setInterval(function() {
      weatherLoadingStageIndex = Math.min(weatherLoadingStageIndex + 1, weatherLoadingStages.length - 1);
      setWeatherPanelState('loading', weatherLoadingStages[weatherLoadingStageIndex]);
    }, 1800);
  }

  function setField(name, value) {
    const field = weatherPanel.querySelector('[data-weather-field="' + name + '"]');
    if (field) {
      field.textContent = textValue(value, 'Not available');
    }
  }

  function setChip(name, value) {
    const chip = weatherPanel.querySelector('[data-weather-chip="' + name + '"]');
    if (chip) {
      chip.textContent = textValue(value, 'Not available');
    }
  }

  function formatPercent(value, fallback) {
    if (value === null || value === undefined || value === '') {
      return fallback;
    }
    if (Number.isFinite(Number(value))) {
      return String(Math.round(Number(value))) + '%';
    }
    return textValue(value, fallback);
  }

  function cloneData(value) {
    if (value === null || value === undefined) {
      return value;
    }
    try {
      return JSON.parse(JSON.stringify(value));
    } catch (error) {
      return value;
    }
  }

  function extractPayloadData(payload) {
    return payload && typeof payload === 'object'
      ? getAny(payload, ['DATA', 'data'], {})
      : {};
  }

  function extractApiMessage(payload, fallback) {
    const errorData = payload && typeof payload === 'object' ? getAny(payload, ['ERROR', 'error'], {}) : {};
    return textValue(
      getAny(payload, ['MESSAGE', 'message'], getAny(errorData, ['MESSAGE', 'message'], fallback)),
      fallback
    );
  }

  function postJson(endpoint, payload, fallbackMessage) {
    return fetch(endpoint, {
      method: 'POST',
      credentials: 'same-origin',
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json'
      },
      body: JSON.stringify(payload || {})
    })
      .then(function(response) {
        return response.text().then(function(text) {
          let parsed = {};
          if (text) {
            try {
              parsed = JSON.parse(text);
            } catch (parseError) {
              parsed = { SUCCESS: false, MESSAGE: text };
            }
          }
          if (!response.ok || !(parsed.SUCCESS === true || parsed.success === true)) {
            throw new Error(extractApiMessage(parsed, fallbackMessage));
          }
          return parsed;
        });
      });
  }

  function fieldSelectorValue(value) {
    return String(value || '').replace(/\\/g, '\\\\').replace(/"/g, '\\"');
  }

  function refreshActiveCruiseV2FieldsFromDocument(sourceDoc) {
    const sourcePayloadEl = sourceDoc ? sourceDoc.getElementById('fpwActiveCruiseV2WeatherPayload') : null;

    if (!sourceDoc) {
      throw new Error('Active Cruise V2 refresh data unavailable.');
    }

    Array.from(sourceDoc.querySelectorAll('[data-fpw-field]')).forEach(function(sourceFieldNode) {
      const fieldName = String(sourceFieldNode.getAttribute('data-fpw-field') || '').trim();
      if (!fieldName) {
        return;
      }
      document.querySelectorAll('[data-fpw-field="' + fieldSelectorValue(fieldName) + '"]').forEach(function(targetNode) {
        targetNode.textContent = sourceFieldNode.textContent;
        if (sourceFieldNode.hasAttribute('style')) {
          targetNode.setAttribute('style', sourceFieldNode.getAttribute('style'));
        } else {
          targetNode.removeAttribute('style');
        }
      });
    });

    if (payloadEl && sourcePayloadEl) {
      payloadEl.textContent = sourcePayloadEl.textContent || '{}';
    }
  }

  function refreshActiveCruiseV2ViewAfterWeatherApply() {
    return fetch(window.location.href, {
      method: 'GET',
      credentials: 'same-origin',
      cache: 'no-store',
      headers: {
        'Accept': 'text/html'
      }
    })
      .then(function(response) {
        if (!response.ok) {
          throw new Error('Active Cruise V2 refresh failed.');
        }
        return response.text();
      })
      .then(function(html) {
        const parser = new window.DOMParser();
        const refreshedDoc = parser.parseFromString(html, 'text/html');
        refreshActiveCruiseV2FieldsFromDocument(refreshedDoc);
      });
  }

  function getApplyContract() {
    const weatherModel = readWeatherModel();
    return weatherModel && typeof weatherModel === 'object' && weatherModel.apply && typeof weatherModel.apply === 'object'
      ? weatherModel.apply
      : {};
  }

  function getApplyEndpoint(name) {
    const apply = getApplyContract();
    const endpoints = apply && typeof apply === 'object' && apply.endpoints && typeof apply.endpoints === 'object'
      ? apply.endpoints
      : {};
    return resolveEndpoint(endpoints[name] || '');
  }

  function getApplyRouteCode() {
    const apply = getApplyContract();
    const payload = apply && typeof apply === 'object' && apply.payload && typeof apply.payload === 'object'
      ? apply.payload
      : {};
    return textValue(getAny(apply, ['routeCode', 'route_code'], getAny(payload, ['routeCode', 'route_code'], '')), '');
  }

  function isApplyAvailable() {
    const apply = getApplyContract();
    return isTrueValue(getAny(apply, ['available', 'AVAILABLE'], false));
  }

  function setWeatherApplyButtonState(options) {
    const state = options && typeof options === 'object' ? options : {};
    const disabled = state.disabled !== false;
    const label = textValue(state.label, 'Apply Weather to Route');
    if (applyButton) {
      applyButton.disabled = disabled || !isApplyAvailable();
      applyButton.setAttribute('aria-disabled', applyButton.disabled ? 'true' : 'false');
      applyButton.textContent = label;
    }
  }

  function isMyRouteType(routeType) {
    const value = String(routeType || '').trim().toLowerCase();
    return value === 'my_route' || value === 'my_routes' || value === 'custom';
  }

  function requestRouteEditContext(routeCode) {
    const endpoint = getApplyEndpoint('editContext');
    if (!endpoint) {
      return Promise.reject(new Error('The view model did not return a route edit-context endpoint.'));
    }
    return postJson(endpoint, { route_code: routeCode }, 'Unable to load route edit context.');
  }

  function requestRoutePreview(inputs) {
    const previewInputs = cloneData(inputs || {});
    const endpoint = getApplyEndpoint(isMyRouteType(previewInputs.route_type) ? 'myRoutePreview' : 'generatedPreview');
    if (!endpoint) {
      return Promise.reject(new Error('The view model did not return a route preview endpoint.'));
    }
    return postJson(endpoint, previewInputs, 'Unable to preview weather-adjusted route.');
  }

  function requestRouteUpdate(payload) {
    const endpoint = getApplyEndpoint('update');
    if (!endpoint) {
      return Promise.reject(new Error('The view model did not return a route update endpoint.'));
    }
    return postJson(endpoint, payload, 'Unable to apply weather to this route.');
  }

  function resolveWeatherSuggestionForLookup() {
    let routeCode = getApplyRouteCode();
    let editInputs = {};
    let routeName = '';

    if (!isApplyAvailable()) {
      return Promise.reject(new Error('Weather factor apply is not available for this active route.'));
    }
    if (!routeWeatherAssist) {
      return Promise.reject(new Error('Route weather helper unavailable.'));
    }
    if (!routeCode) {
      return Promise.reject(new Error('Unable to resolve the active route code.'));
    }
    if (!weatherLookupState.data || !weatherLookupState.data.available || !weatherLookupState.data.weather) {
      return Promise.reject(new Error('Check current-leg conditions before applying weather to the route.'));
    }

    return requestRouteEditContext(routeCode)
      .then(function(editContextPayload) {
        const editContextData = extractPayloadData(editContextPayload);
        editInputs = cloneData((editContextData && (editContextData.inputs || editContextData.INPUTS)) || {});
        routeName = String(
          editInputs.route_name ||
          ((editContextData.route || {}).route_name) ||
          ((editContextData.route || {}).ROUTE_NAME) ||
          ''
        ).trim();
        if (!routeName) {
          throw new Error('Route name unavailable for route update.');
        }
        editInputs.route_name = routeName;
        if (!String(editInputs.route_code || '').trim()) {
          editInputs.route_code = routeCode;
        }
        return requestRoutePreview(editInputs);
      })
      .then(function(previewPayload) {
        const previewData = extractPayloadData(previewPayload);
        const previewLegs = Array.isArray(previewData.legs) ? previewData.legs : (Array.isArray(previewData.LEGS) ? previewData.LEGS : []);
        const routeContext = routeWeatherAssist.buildRouteWeatherContextFromLegs(previewLegs);
        const weatherEnvelope = routeWeatherAssist.normalizeWeatherEnvelope(weatherLookupState.data.weather || {}, '');
        const suggestion = routeWeatherAssist.computeLiveWeatherFactorPct(weatherEnvelope, routeContext);
        const suggestedPct = parseInt(suggestion.suggestedPct, 10);
        if (!previewLegs.length) {
          throw new Error('Route preview returned no legs.');
        }
        if (!suggestion.available || !Number.isFinite(suggestedPct)) {
          throw new Error('Weather factor suggestion unavailable for this route.');
        }
        return {
          routeCode: routeCode,
          routeName: routeName,
          editInputs: editInputs,
          suggestedPct: suggestedPct,
          suggestion: suggestion
        };
      });
  }

  function renderWeatherSuggestion(resultData) {
    const pct = parseInt(resultData && resultData.suggestedPct, 10);
    if (!Number.isFinite(pct)) {
      weatherLookupState.suggestedPct = null;
      setField('weatherFactor', '0%');
      setChip('factor', '0% factor');
      setField('weatherFactorNote', 'Weather factor suggestion unavailable.');
      setWeatherApplyButtonState({ disabled: true });
      return;
    }
    weatherLookupState.suggestedPct = pct;
    setField('weatherFactor', formatPercent(pct, '0%'));
    setChip('factor', formatPercent(pct, '0%') + ' factor');
    setField('weatherFactorNote', 'Suggested ' + pct + '% weather factor. Apply to update the route.');
    setWeatherApplyButtonState({ disabled: false });
  }

  function applyWeatherToRouteFromLookup() {
    return resolveWeatherSuggestionForLookup()
      .then(function(suggestionResult) {
        const updatedPayload = cloneData(suggestionResult.editInputs);
        updatedPayload.weather_factor_pct = suggestionResult.suggestedPct;
        updatedPayload.route_code = suggestionResult.routeCode;
        updatedPayload.route_name = suggestionResult.routeName;
        return requestRouteUpdate(updatedPayload).then(function(updatePayload) {
          return {
            updatePayload: updatePayload,
            suggestedPct: suggestionResult.suggestedPct
          };
        });
      });
  }

  function renderWeatherPayload(payload) {
    const data = getAny(payload, ['data', 'DATA'], {});
    const weather = getAny(data, ['weather', 'WEATHER'], {});
    const forecast = firstArrayItem(getAny(weather, ['FORECAST', 'forecast'], []));
    const marine = getAny(weather, ['MARINE', 'marine'], {});
    const surface = getAny(weather, ['surface', 'SURFACE'], {});
    const alerts = getAny(weather, ['ALERTS', 'alerts'], []);
    const pointLabel = getAny(data, ['point_label', 'POINT_LABEL', 'label'], getAny(data, ['point', 'POINT'], 'Selected point'));
    const summary = getAny(weather, ['SUMMARY', 'summary'], getAny(forecast, ['shortForecast', 'SHORTFORECAST', 'detailedForecast'], getAny(payload, ['MESSAGE', 'message'], 'Not available')));
    const temperature = joinParts([
      getAny(forecast, ['temperature', 'TEMPERATURE'], ''),
      getAny(forecast, ['temperatureUnit', 'TEMPERATUREUNIT'], '')
    ], 'Not available');
    const wind = joinParts([
      getAny(forecast, ['windDirection', 'WINDDIRECTION'], ''),
      getAny(forecast, ['windSpeed', 'WINDSPEED'], '')
    ], 'Not available');
    const gusts = getAny(forecast, ['gustMph', 'GUSTMPH', 'windGust', 'WINDGUST'], 'Not available');
    const waves = getAny(marine, ['wave_height_ft', 'WAVE_HEIGHT_FT', 'waveHeightFt'], 'Not available');
    const visibility = getAny(surface, ['visibility_mi', 'VISIBILITY_MI', 'visibilityMi'], 'Not available');
    const alertText = Array.isArray(alerts) && alerts.length
      ? alerts.map(function(alertItem) {
          return textValue(getAny(alertItem, ['headline', 'HEADLINE', 'event', 'EVENT'], 'Alert'), 'Alert');
        }).join('; ')
      : 'No alerts';
    const weatherFactor = formatPercent(getAny(data, ['weather_factor_pct', 'WEATHER_FACTOR_PCT', 'weatherFactorPct', 'weatherFactor'], getAny(weather, ['weather_factor_pct', 'WEATHER_FACTOR_PCT', 'weatherFactorPct', 'weatherFactor'], 0)), '0%');
    const alertChip = Array.isArray(alerts) && alerts.length
      ? String(alerts.length) + ' alert' + (alerts.length === 1 ? '' : 's')
      : 'No alerts';

    result.classList.remove('is-empty');
    setField('point', pointLabel);
    setField('summary', summary);
    setField('temperature', temperature);
    setField('wind', wind);
    setField('gusts', gusts);
    setField('waves', waves);
    setField('visibility', visibility);
    setField('weatherFactor', weatherFactor);
    setField('alerts', alertText);
    setChip('alerts', alertChip);
    setChip('factor', weatherFactor + ' factor');
    return {
      data: data,
      weatherFactor: weatherFactor
    };
  }

  setWeatherApplyButtonState({ disabled: true });
  setWeatherPanelState('notChecked');

  form.addEventListener('submit', function(event) {
    event.preventDefault();

    if (weatherCheckInFlight) {
      return;
    }

    const weatherModel = readWeatherModel();
    const lookup = weatherModel && typeof weatherModel === 'object' && weatherModel.lookup && typeof weatherModel.lookup === 'object' ? weatherModel.lookup : {};
    const endpoint = resolveEndpoint(lookup.endpoint || '');
    const selectedPoint = form.querySelector('input[name="fpwV2WeatherPoint"]:checked');
    const button = form.querySelector('button[type="submit"]');
    const originalButtonLabel = button ? (button.getAttribute('data-original-label') || button.textContent || 'Check Conditions') : 'Check Conditions';
    const requestPayload = Object.assign({}, lookup.payload || {}, {
      point: selectedPoint ? selectedPoint.value : ''
    });

    if (!endpoint || !requestPayload.point) {
      setWeatherPanelState('error', 'The view model did not return an executable weather lookup contract.');
      return;
    }

    const seq = weatherLookupState.requestSeq + 1;
    const weatherFetchController = typeof AbortController === 'function' ? new AbortController() : null;
    let weatherLookupTimedOut = false;
    let weatherLookupTimeoutId = 0;
    weatherLookupState.requestSeq = seq;
    weatherCheckInFlight = true;
    if (button) {
      button.setAttribute('data-original-label', originalButtonLabel);
      button.disabled = true;
      button.textContent = 'Checking...';
    }
    startWeatherLoading();
    if (weatherFetchController) {
      weatherLookupTimeoutId = window.setTimeout(function() {
        weatherLookupTimedOut = true;
        weatherFetchController.abort();
      }, WEATHER_LOOKUP_TIMEOUT_MS);
    }

    fetch(endpoint, {
      method: lookup.method || 'POST',
      credentials: 'same-origin',
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json'
      },
      signal: weatherFetchController ? weatherFetchController.signal : undefined,
      body: JSON.stringify(requestPayload)
    })
      .then(function(response) {
        return response.text().then(function(text) {
          let payload = {};
          if (text) {
            try {
              payload = JSON.parse(text);
            } catch (parseError) {
              payload = { success: false, message: text };
            }
          }
          return { ok: response.ok, payload: payload };
        });
      })
      .then(function(resultPayload) {
        const responsePayload = resultPayload.payload || {};
        const success = resultPayload.ok && isTrueValue(getAny(responsePayload, ['success', 'SUCCESS'], false));
        const data = getAny(responsePayload, ['data', 'DATA'], {});
        const available = isTrueValue(getAny(data, ['available', 'AVAILABLE'], false));
        const message = textValue(
          getAny(responsePayload, ['MESSAGE', 'message'], getAny(data, ['message', 'MESSAGE'], 'Weather check could not be completed. Please try again.')),
          'Weather check could not be completed. Please try again.'
        );

        weatherLookupState.point = requestPayload.point;
        if (!success || !available) {
          setWeatherPanelState('error', message);
          setWeatherApplyButtonState({ disabled: weatherLookupState.suggestedPct === null });
          return;
        }

        weatherLookupState.data = data;
        weatherLookupState.suggestedPct = null;
        weatherLookupState.hasSuccessfulData = true;
        setWeatherApplyButtonState({ disabled: true });
        renderWeatherPayload(responsePayload);
        setWeatherPanelState('checked', message);

        if (success && available && isApplyAvailable()) {
          setField('weatherFactorNote', 'Calculating route weather factor...');
          resolveWeatherSuggestionForLookup()
            .then(function(suggestionResult) {
              if (seq === weatherLookupState.requestSeq) {
                renderWeatherSuggestion(suggestionResult);
              }
            })
            .catch(function(error) {
              if (seq === weatherLookupState.requestSeq) {
                weatherLookupState.suggestedPct = null;
                setWeatherApplyButtonState({ disabled: true });
                setField('weatherFactorNote', error && error.message ? error.message : 'Weather factor suggestion unavailable.');
              }
            });
        }
      })
      .catch(function(error) {
        const message = weatherLookupTimedOut || (error && error.name === 'AbortError')
          ? 'Weather check timed out. Please try again.'
          : (error && error.message ? error.message : 'Weather check could not be completed. Please try again.');
        setWeatherPanelState('error', message);
        setWeatherApplyButtonState({ disabled: weatherLookupState.suggestedPct === null });
      })
      .finally(function() {
        if (weatherLookupTimeoutId) {
          window.clearTimeout(weatherLookupTimeoutId);
        }
        stopWeatherLoading();
        weatherCheckInFlight = false;
        if (button) {
          button.disabled = false;
          button.textContent = originalButtonLabel;
        }
      });
  });

  Array.from(form.querySelectorAll('input[name="fpwV2WeatherPoint"]')).forEach(function(input) {
    input.addEventListener('change', function() {
      weatherLookupState.point = '';
      weatherLookupState.data = null;
      weatherLookupState.suggestedPct = null;
      weatherLookupState.hasSuccessfulData = false;
      weatherLookupState.requestSeq += 1;
      if (!weatherCheckInFlight) {
        stopWeatherLoading();
      }
      result.classList.add('is-empty');
      setField('point', 'Not checked');
      setField('summary', 'Not checked');
      setField('temperature', 'Not checked');
      setField('wind', 'Not checked');
      setField('gusts', 'Not checked');
      setField('waves', 'Not checked');
      setField('visibility', 'Not checked');
      setField('weatherFactor', '0%');
      setField('alerts', 'Not checked');
      setField('weatherFactorNote', isApplyAvailable() ? 'Check conditions to calculate a route weather factor.' : 'Weather factor apply is not available in AC-V2.');
      setChip('alerts', 'No alerts');
      setChip('factor', '0% factor');
      setWeatherApplyButtonState({ disabled: true });
      setWeatherPanelState('notChecked', 'Select a current-leg point and check conditions.');
    });
  });

  if (applyButton) {
    applyButton.addEventListener('click', function() {
      let appliedPctText = '';
      if (applyButton.disabled) {
        return;
      }
      setWeatherApplyButtonState({ disabled: true, label: 'Applying...' });
      setFeedback('Applying weather factor to route...', '');
      applyWeatherToRouteFromLookup()
        .then(function(resultData) {
          const pct = parseInt(resultData && resultData.suggestedPct, 10);
          const pctText = Number.isFinite(pct) ? String(pct) + '%' : 'selected';
          appliedPctText = pctText;
          setField('weatherFactor', Number.isFinite(pct) ? pctText : '0%');
          setChip('factor', Number.isFinite(pct) ? pctText + ' factor' : '0% factor');
          setField('weatherFactorNote', 'Applied ' + pctText + ' weather factor to route. Refreshing route view...');
          setFeedback('Applied ' + pctText + ' weather factor to route.', 'is-success');
          return refreshActiveCruiseV2ViewAfterWeatherApply();
        })
        .then(function() {
          if (appliedPctText) {
            setField('weatherFactorNote', 'Applied ' + appliedPctText + ' weather factor to route.');
            setFeedback('Applied ' + appliedPctText + ' weather factor to route.', 'is-success');
          }
        })
        .catch(function(error) {
          setWeatherApplyButtonState({ disabled: weatherLookupState.suggestedPct === null });
          if (appliedPctText) {
            const refreshMessage = 'Applied ' + appliedPctText + ' weather factor to route, but Active Cruise V2 refresh did not complete.';
            setField('weatherFactorNote', refreshMessage);
            setFeedback(refreshMessage, 'is-warning');
            return;
          }
          setFeedback(error && error.message ? error.message : 'Unable to apply weather to this route.', 'is-error');
        })
        .finally(function() {
          setWeatherApplyButtonState({ disabled: weatherLookupState.suggestedPct === null });
        });
    });
  }
})();

(function() {
  const form = document.getElementById('fpwV2CaptainQuickNoteForm');
  if (!form) {
    return;
  }

  const noteInput = document.getElementById('fpwV2CaptainQuickNoteInput');
  const postCheckbox = document.getElementById('fpwV2CaptainQuickNotePost');
  const saveButton = document.getElementById('fpwV2CaptainQuickNoteSaveBtn');
  const message = document.getElementById('fpwV2CaptainQuickNoteMessage');
  const noteList = document.getElementById('fpwV2CaptainQuickNoteList');
  const emptyState = document.getElementById('fpwV2CaptainQuickNoteEmpty');
  const tagButtons = Array.from(form.querySelectorAll('[data-fpw-v2-captain-note-tag]'));
  const tripTimeZone = form.getAttribute('data-trip-timezone') || 'UTC';
  let selectedTag = '';

  function setMessage(text, state) {
    if (!message) {
      return;
    }
    message.textContent = text || '';
    message.classList.remove('is-success', 'is-error');
    if (state) {
      message.classList.add(state);
    }
  }

  function resolveEndpoint(endpoint) {
    if (!endpoint) {
      return '';
    }
    const basePath = form.getAttribute('data-fpw-base') || '';
    if (endpoint.indexOf('/api/') === 0 && basePath) {
      return basePath + endpoint;
    }
    return endpoint;
  }

  function readPayload() {
    try {
      return JSON.parse(form.getAttribute('data-payload') || '{}');
    } catch (payloadError) {
      return {};
    }
  }

  function responseMessage(payload, fallback) {
    if (payload && typeof payload === 'object') {
      return payload.MESSAGE || payload.message || payload.ERROR || payload.error || fallback;
    }
    return fallback;
  }

  function parseUtcDate(value) {
    let raw = value ? String(value).trim() : '';
    if (!raw) {
      return null;
    }
    if (/^\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}/.test(raw)) {
      raw = raw.replace(/\s+/, 'T') + 'Z';
    } else if (/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}/.test(raw) && !/(Z|[+-]\d{2}:?\d{2})$/.test(raw)) {
      raw += 'Z';
    }
    const parsed = new Date(raw);
    return Number.isNaN(parsed.getTime()) ? null : parsed;
  }

  function formatTripDateTimeLabel(value, fallback) {
    const parsed = parseUtcDate(value);
    if (!parsed) {
      return formatNoteTimeFallback(fallback || 'time unavailable');
    }
    try {
      const parts = new Intl.DateTimeFormat('en-US', {
        timeZone: tripTimeZone,
        month: 'long',
        day: 'numeric',
        year: 'numeric',
        hour: '2-digit',
        minute: '2-digit',
        hourCycle: 'h23'
      }).formatToParts(parsed).reduce(function(acc, part) {
        acc[part.type] = part.value;
        return acc;
      }, {});
      return (parts.month || '')
        + ' ' + (parts.day || '')
        + ', ' + (parts.year || '')
        + ' '
        + (parts.hour || '00')
        + ':' + (parts.minute || '00')
        + ' ' + tripTimeZone;
    } catch (formatError) {
      return formatNoteTimeFallback(fallback || 'time unavailable');
    }
  }

  function formatNoteTimeFallback(value) {
    const raw = value ? String(value).trim() : '';
    const match = raw.match(/^(\d{1,2}):(\d{2})\s*(AM|PM)$/i);
    let hour = 0;
    if (!match) {
      return raw || 'time unavailable';
    }
    hour = parseInt(match[1], 10);
    if (/PM/i.test(match[3]) && hour < 12) {
      hour += 12;
    }
    if (/AM/i.test(match[3]) && hour === 12) {
      hour = 0;
    }
    return String(hour).padStart(2, '0') + ':' + match[2];
  }

  function readNotePayloadValue(notePayload, fieldNames) {
    if (!notePayload || !fieldNames || !fieldNames.length) {
      return '';
    }
    for (let i = 0; i < fieldNames.length; i += 1) {
      if (notePayload[fieldNames[i]] !== undefined && notePayload[fieldNames[i]] !== null) {
        return notePayload[fieldNames[i]];
      }
    }
    const normalizedNames = fieldNames.map(function(fieldName) {
      return String(fieldName).toLowerCase();
    });
    const payloadKeys = Object.keys(notePayload);
    for (let i = 0; i < payloadKeys.length; i += 1) {
      if (normalizedNames.indexOf(payloadKeys[i].toLowerCase()) !== -1) {
        return notePayload[payloadKeys[i]];
      }
    }
    return '';
  }

  function updateSaveLabel() {
    if (!saveButton) {
      return;
    }
    saveButton.textContent = postCheckbox && postCheckbox.checked ? 'Save & Post' : 'Save Note';
  }

  function setSelectedTag(tagValue) {
    selectedTag = tagValue || '';
    tagButtons.forEach(function(button) {
      button.classList.toggle('is-selected', (button.getAttribute('data-fpw-v2-captain-note-tag') || '') === selectedTag);
    });
  }

  function appendTagToNote(tagValue) {
    if (!noteInput || !tagValue) {
      return;
    }
    const currentValue = String(noteInput.value || '').trim();
    const appendedValue = '[' + tagValue + ']';
    if (!currentValue) {
      noteInput.value = tagValue;
      return;
    }
    if (currentValue === tagValue || currentValue.indexOf(appendedValue) !== -1) {
      return;
    }
    noteInput.value = currentValue + ' ' + appendedValue;
  }

  function buildNoteRow(notePayload, fallbackNoteBody, fallbackTag, postedToStream) {
    const row = document.createElement('div');
    const bodyWrap = document.createElement('div');
    const title = document.createElement('b');
    const body = document.createElement('span');
    const meta = document.createElement('div');
    const badge = document.createElement('div');
    const time = document.createElement('span');
    const noteBody = (notePayload && (notePayload.noteBody || notePayload.NOTEBODY || notePayload.note_body || notePayload.NOTE_BODY)) || fallbackNoteBody || 'No note text returned.';
    const noteTag = (notePayload && (notePayload.noteTag || notePayload.NOTETAG || notePayload.note_tag || notePayload.NOTE_TAG)) || fallbackTag || 'Captain note';
    const noteBadge = (notePayload && (notePayload.badge || notePayload.BADGE)) || (postedToStream ? 'POSTED' : 'PRIVATE');
    const rawNoteTime = readNotePayloadValue(notePayload, [ 'createdUtc', 'createdUTC', 'created_utc' ]);
    const fallbackNoteTime = readNotePayloadValue(notePayload, [ 'createdLabel', 'created_label' ]);
    const noteTime = formatTripDateTimeLabel(rawNoteTime, fallbackNoteTime || 'time unavailable');

    row.className = 'log-row';
    meta.className = 'captain-note-meta';
    badge.className = 'action-mini';

    title.textContent = noteTag;
    body.textContent = noteBody;
    badge.textContent = noteBadge;
    time.textContent = noteTime;

    bodyWrap.appendChild(title);
    bodyWrap.appendChild(body);
    meta.appendChild(badge);
    meta.appendChild(time);
    row.appendChild(bodyWrap);
    row.appendChild(meta);
    return row;
  }

  function prependNote(notePayload, fallbackNoteBody, fallbackTag, postedToStream) {
    if (!noteList) {
      return;
    }
    noteList.insertBefore(buildNoteRow(notePayload, fallbackNoteBody, fallbackTag, postedToStream), noteList.firstChild);
    if (emptyState) {
      emptyState.hidden = true;
    }
  }

  function setSaving(saving) {
    if (saveButton) {
      saveButton.disabled = saving;
      saveButton.textContent = saving ? 'Saving...' : (postCheckbox && postCheckbox.checked ? 'Save & Post' : 'Save Note');
    }
    tagButtons.forEach(function(button) {
      button.disabled = saving || form.getAttribute('data-enabled') !== 'true';
    });
    if (postCheckbox) {
      postCheckbox.disabled = saving || form.getAttribute('data-enabled') !== 'true';
    }
  }

  tagButtons.forEach(function(button) {
    button.addEventListener('click', function() {
      const tagValue = button.getAttribute('data-fpw-v2-captain-note-tag') || '';
      if (selectedTag === tagValue) {
        setSelectedTag('');
        return;
      }
      setSelectedTag(tagValue);
      appendTagToNote(tagValue);
      if (noteInput) {
        noteInput.focus();
      }
    });
  });

  if (postCheckbox) {
    postCheckbox.addEventListener('change', updateSaveLabel);
  }

  if (saveButton) {
    saveButton.addEventListener('click', function() {
      const enabled = form.getAttribute('data-enabled') === 'true';
      const endpoint = resolveEndpoint(form.getAttribute('data-endpoint') || '');
      const method = form.getAttribute('data-method') || 'POST';
      const noteBody = noteInput ? String(noteInput.value || '').trim() : '';
      const postToFollowStream = postCheckbox ? postCheckbox.checked : false;
      const payload = readPayload();

      if (!enabled || !endpoint) {
        setMessage('The view model did not return an executable captain note contract.', 'is-error');
        return;
      }
      if (!noteBody) {
        setMessage('A captain note is required.', 'is-error');
        if (noteInput) {
          noteInput.focus();
        }
        return;
      }

      payload.noteBody = noteBody;
      payload.noteTag = selectedTag;
      payload.postToFollowStream = postToFollowStream;

      setSaving(true);
      setMessage('Saving captain note...', '');

      fetch(endpoint, {
        method: method,
        credentials: 'same-origin',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json'
        },
        body: JSON.stringify(payload)
      })
        .then(function(response) {
          return response.text().then(function(text) {
            let responsePayload = {};
            if (text) {
              try {
                responsePayload = JSON.parse(text);
              } catch (parseError) {
                responsePayload = { success: false, message: text };
              }
            }
            return { ok: response.ok, payload: responsePayload };
          });
        })
        .then(function(result) {
          const responsePayload = result.payload || {};
          const success = result.ok && (responsePayload.success === true || responsePayload.SUCCESS === true);
          const savedNote = responsePayload.note || responsePayload.NOTE || {};
          if (!success) {
            setMessage(responseMessage(responsePayload, 'Captain note save failed.'), 'is-error');
            return;
          }
          prependNote(savedNote, noteBody, selectedTag, postToFollowStream);
          if (noteInput) {
            noteInput.value = '';
          }
          if (postCheckbox) {
            postCheckbox.checked = false;
          }
          setSelectedTag('');
          updateSaveLabel();
          setMessage(postToFollowStream ? 'Saved and posted to the Trip status page.' : 'Private captain note saved.', 'is-success');
        })
        .catch(function(error) {
          setMessage(error && error.message ? error.message : 'Captain note request failed.', 'is-error');
        })
        .finally(function() {
          setSaving(false);
        });
    });
  }

  updateSaveLabel();
})();

window.FPWActiveCruiseV2.bindPacePanel = function() {
  const panel = document.getElementById('fpwV2PacePanel');
  const slider = document.getElementById('fpwV2PaceSlider');
  const feedback = document.getElementById('fpwV2PaceFeedback');
  const initiallyDisabled = slider ? slider.disabled : true;
  let lastCommittedPaceValue = slider ? String(slider.getAttribute('data-current-value') || '').toUpperCase() : '';
  const paceByIndex = [
    { value: 'RELAXED', label: 'Relaxed' },
    { value: 'BALANCED', label: 'Efficient Speed' },
    { value: 'AGGRESSIVE', label: 'Max Speed' }
  ];

  if (!panel || !slider || !feedback) {
    return;
  }
  if (panel.getAttribute('data-ac-v2-pace-bound') === 'true') {
    return;
  }
  panel.setAttribute('data-ac-v2-pace-bound', 'true');

  function setFeedback(message, state) {
    feedback.textContent = message;
    feedback.classList.remove('is-success', 'is-error');
    if (state) {
      feedback.classList.add(state);
    }
    feedback.hidden = false;
    feedback.setAttribute('aria-hidden', 'false');
  }

  function resolveEndpoint(endpoint) {
    const basePath = panel.getAttribute('data-fpw-base') || '';
    if (endpoint && endpoint.indexOf('/api/') === 0 && basePath) {
      return basePath + endpoint;
    }
    return endpoint || '';
  }

  function readPayload() {
    const raw = panel.getAttribute('data-payload') || '{}';
    try {
      return JSON.parse(raw);
    } catch (error) {
      return {};
    }
  }

  function responseMessage(payload, fallback) {
    if (payload && typeof payload === 'object') {
      return payload.MESSAGE || payload.message || payload.ERROR || payload.error || fallback;
    }
    return fallback;
  }

  function selectedPace() {
    const index = Math.max(0, Math.min(2, parseInt(slider.value || '0', 10) || 0));
    return paceByIndex[index] || paceByIndex[0];
  }

  function paceIndexFromValue(value) {
    const paceValue = String(value || '').toUpperCase();
    for (let index = 0; index < paceByIndex.length; index += 1) {
      if (paceByIndex[index].value === paceValue) {
        return index;
      }
    }
    return 0;
  }

  function restoreCommittedPace() {
    slider.value = String(paceIndexFromValue(lastCommittedPaceValue));
  }

  function saveSelectedPace() {
    const endpoint = resolveEndpoint(panel.getAttribute('data-endpoint') || '');
    const method = panel.getAttribute('data-method') || 'POST';
    const payload = readPayload();
    const pace = selectedPace();
    const isEnabled = panel.getAttribute('data-enabled') === 'true';

    if (!isEnabled || slider.disabled) {
      return;
    }
    if (pace.value === lastCommittedPaceValue) {
      setFeedback('Change pace to update the active trip projection.', '');
      return;
    }
    if (!endpoint) {
      setFeedback('The view model did not return an executable pace endpoint.', 'is-error');
      restoreCommittedPace();
      return;
    }

    payload.pace = pace.value;
    slider.disabled = true;
    setFeedback('Saving active-trip pace...', '');

    fetch(endpoint, {
      method: method,
      credentials: 'same-origin',
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json'
      },
      body: JSON.stringify(payload)
    })
      .then(function(response) {
        return response.text().then(function(text) {
          let responsePayload = {};
          if (text) {
            try {
              responsePayload = JSON.parse(text);
            } catch (parseError) {
              responsePayload = { success: false, message: text };
            }
          }
          return { ok: response.ok, payload: responsePayload };
        });
      })
      .then(function(result) {
        const responsePayload = result.payload || {};
        const success = result.ok && (responsePayload.success === true || responsePayload.SUCCESS === true);
        if (!success) {
          throw new Error(responseMessage(responsePayload, 'Pace update failed.'));
        }
        lastCommittedPaceValue = pace.value;
        slider.setAttribute('data-current-value', lastCommittedPaceValue);
        setFeedback('Pace updated. Refreshing view model...', 'is-success');
        return window.FPWActiveCruiseV2.fetchAndRefresh({
          replaceSelectors: [
            '#fpwV2PacePanel',
            '#acV2RouteProgressPanel'
          ]
        }).then(function() {
          const refreshedFeedback = document.getElementById('fpwV2PaceFeedback');
          if (refreshedFeedback) {
            refreshedFeedback.textContent = 'Pace updated from latest view model.';
            refreshedFeedback.classList.remove('is-error');
            refreshedFeedback.classList.add('is-success');
            refreshedFeedback.hidden = false;
            refreshedFeedback.setAttribute('aria-hidden', 'false');
          }
        });
      })
      .catch(function(error) {
        setFeedback(error && error.message ? error.message : 'Pace update request failed.', 'is-error');
        restoreCommittedPace();
        slider.disabled = initiallyDisabled;
      });
  }

  if (!lastCommittedPaceValue) {
    lastCommittedPaceValue = selectedPace().value;
    slider.setAttribute('data-current-value', lastCommittedPaceValue);
  }

  slider.addEventListener('change', saveSelectedPace);
};
window.FPWActiveCruiseV2.bindPacePanel();

window.FPWActiveCruiseV2.bindTimingPanel = function() {
  const panel = document.getElementById('fpwV2TimingPanel');
  const feedback = document.getElementById('fpwV2TimingFeedback');
  if (!panel || !feedback) {
    return;
  }
  if (panel.getAttribute('data-ac-v2-timing-bound') === 'true') {
    return;
  }
  panel.setAttribute('data-ac-v2-timing-bound', 'true');

  function setFeedback(message, state) {
    feedback.textContent = message;
    feedback.classList.remove('is-success', 'is-error');
    if (state) {
      feedback.classList.add(state);
    }
    feedback.hidden = false;
    feedback.setAttribute('aria-hidden', 'false');
  }

  function setDailyStartFeedback(message, state) {
    const dailyStartFeedback = document.getElementById('fpwV2DailyStartFeedback');
    if (!dailyStartFeedback) {
      return;
    }
    dailyStartFeedback.textContent = message || '';
    dailyStartFeedback.classList.remove('is-success', 'is-error');
    if (state) {
      dailyStartFeedback.classList.add(state);
    }
    dailyStartFeedback.hidden = !message;
    dailyStartFeedback.setAttribute('aria-hidden', message ? 'false' : 'true');
  }

  function resolveEndpoint(endpoint) {
    if (!endpoint) {
      return '';
    }
    const basePath = panel.getAttribute('data-fpw-base') || '';
    if (endpoint.indexOf('/api/') === 0 && basePath) {
      return basePath + endpoint;
    }
    return endpoint;
  }

  function readPayload(button) {
    try {
      return JSON.parse(button.getAttribute('data-payload') || '{}');
    } catch (payloadError) {
      return {};
    }
  }

  function responseMessage(payload, fallback) {
    if (payload && typeof payload === 'object') {
      return payload.MESSAGE || payload.message || payload.ERROR || payload.error || fallback;
    }
    return fallback;
  }

  function confirmationRequired(button) {
    return String(button.getAttribute('data-confirmation-required') || '').toLowerCase() === 'true';
  }

  function restoreButtons(buttons, states) {
    buttons.forEach(function(actionButton, index) {
      actionButton.disabled = states[index] === true;
    });
  }

  function refreshSelectorsForAction(actionName) {
    const refreshMap = {
      addDelay: [
        '#fpwV2TimingPanel',
        '#acV2RouteProgressPanel'
      ],
      clearDelay: [
        '#fpwV2TimingPanel',
        '#acV2RouteProgressPanel'
      ],
      updateDailyStart: [
        '#fpwV2TimingPanel'
      ]
    };
    return refreshMap[actionName] || [];
  }

  function showRefreshedFeedback(message) {
    const refreshedFeedback = document.getElementById('fpwV2TimingFeedback');
    if (refreshedFeedback) {
      refreshedFeedback.textContent = message;
      refreshedFeedback.classList.remove('is-error');
      refreshedFeedback.classList.add('is-success');
      refreshedFeedback.hidden = false;
      refreshedFeedback.setAttribute('aria-hidden', 'false');
    }
  }

  panel.addEventListener('click', function(event) {
    const button = event.target.closest('[data-ac-v2-timing-action]');
    if (!button || button.disabled) {
      return;
    }

    const actionName = button.getAttribute('data-ac-v2-timing-action') || '';
    const endpoint = resolveEndpoint(button.getAttribute('data-endpoint') || '');
    const payload = readPayload(button);
    const method = button.getAttribute('data-method') || 'POST';
    const confirmationRequired = String(button.getAttribute('data-confirmation-required') || '').toLowerCase() === 'true';
    const confirmationMessage = button.getAttribute('data-confirmation-message') || 'Confirm this timing update.';
    const buttons = Array.from(panel.querySelectorAll('[data-ac-v2-timing-action]'));
    const buttonStates = buttons.map(function(actionButton) { return actionButton.disabled; });

    if (!endpoint) {
      setFeedback('The view model did not return an executable endpoint for this timing action.', 'is-error');
      return;
    }

    if (actionName === 'addDelay') {
      const minutesInput = document.getElementById('fpwV2AddDelayMinutes');
      const minutesRaw = minutesInput ? String(minutesInput.value || '').trim() : '';
      const minutesValue = parseInt(minutesRaw, 10);
      if (!minutesRaw) {
        setFeedback('Delay minutes are required.', 'is-error');
        return;
      }
      if (!/^\d+$/.test(minutesRaw) || !Number.isFinite(minutesValue) || minutesValue <= 0) {
        setFeedback('Delay minutes must be a positive whole number.', 'is-error');
        return;
      }
      payload.minutes = minutesValue;
    }

    if (actionName === 'updateDailyStart') {
      const dailyStartInput = document.getElementById('fpwV2DailyStartLocalTime');
      const dailyStartLocalTime = dailyStartInput ? String(dailyStartInput.value || '').trim() : '';
      if (!dailyStartLocalTime) {
        setFeedback('Daily start time is required.', 'is-error');
        setDailyStartFeedback('Choose a daily start time before saving.', 'is-error');
        if (dailyStartInput) {
          dailyStartInput.focus();
        }
        return;
      }
      const dailyStartMatch = dailyStartLocalTime.match(/^(\d{2}:\d{2})(?::\d{2})?$/);
      if (!dailyStartMatch) {
        setFeedback('Daily start time must use HH:mm format.', 'is-error');
        setDailyStartFeedback('Use a valid HH:mm daily start time before saving.', 'is-error');
        if (dailyStartInput) {
          dailyStartInput.focus();
        }
        return;
      }
      payload.dailyStartLocalTime = dailyStartMatch[1];
      setDailyStartFeedback('', '');
    }

    if (confirmationRequired && !window.confirm(confirmationMessage)) {
      return;
    }

    buttons.forEach(function(actionButton) {
      actionButton.disabled = true;
    });
    setFeedback('Submitting timing update...', '');

    fetch(endpoint, {
      method: method,
      credentials: 'same-origin',
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json'
      },
      body: JSON.stringify(payload)
    })
      .then(function(response) {
        return response.text().then(function(text) {
          let responsePayload = {};
          if (text) {
            try {
              responsePayload = JSON.parse(text);
            } catch (parseError) {
              responsePayload = { success: false, message: text };
            }
          }
          return { ok: response.ok, payload: responsePayload };
        });
      })
      .then(function(result) {
        const payloadResult = result.payload || {};
        const success = result.ok && (payloadResult.success === true || payloadResult.SUCCESS === true);
        const message = responseMessage(payloadResult, success ? 'Timing update completed.' : 'Timing update failed.');
        if (success) {
          setFeedback(message + ' Refreshing view model...', 'is-success');
          const refreshSelectors = refreshSelectorsForAction(actionName);
          if (refreshSelectors.length) {
            return window.FPWActiveCruiseV2.fetchAndRefresh({
              replaceSelectors: refreshSelectors
            }).then(function() { showRefreshedFeedback(message); });
          }
          window.location.reload();
          return;
        }
        setFeedback(message, 'is-error');
        restoreButtons(buttons, buttonStates);
      })
      .catch(function(error) {
        setFeedback(error && error.message ? error.message : 'Timing update request failed.', 'is-error');
        restoreButtons(buttons, buttonStates);
      });
  });
};
window.FPWActiveCruiseV2.bindTimingPanel();

(function() {
  const noteInput = document.getElementById('fpwV2CheckInNote');
  const noteCounter = document.getElementById('fpwV2CheckInNoteCounter');
  if (!noteInput || !noteCounter) {
    return;
  }

  const noteShell = document.querySelector('[data-ac-v2-note-shell]');
  const noteToggle = noteShell ? noteShell.querySelector('[data-ac-v2-note-toggle]') : null;
  const noteCollapsible = noteShell ? noteShell.querySelector('[data-ac-v2-note-collapsible]') : null;
  const maxLength = parseInt(noteInput.getAttribute('maxlength') || '500', 10) || 500;

  function setNoteExpanded(expanded, focusTextarea) {
    if (!noteToggle || !noteCollapsible) {
      return;
    }
    noteToggle.setAttribute('aria-expanded', expanded ? 'true' : 'false');
    noteCollapsible.hidden = !expanded;
    if (noteShell) {
      noteShell.classList.toggle('is-expanded', expanded);
    }
    if (expanded && focusTextarea) {
      noteInput.focus();
    }
  }

  function updateNoteCounter() {
    noteCounter.textContent = String((noteInput.value || '').length) + '/' + String(maxLength);
    if ((noteInput.value || '').trim().length > 0) {
      setNoteExpanded(true, false);
    }
  }

  if (noteToggle && noteCollapsible) {
    noteToggle.addEventListener('click', function() {
      const isExpanded = noteToggle.getAttribute('aria-expanded') === 'true';
      setNoteExpanded(!isExpanded, !isExpanded);
    });
  }
  noteInput.addEventListener('input', updateNoteCounter);
  updateNoteCounter();
})();

window.FPWActiveCruiseV2.bindActionPanel = function() {
  const panel = document.getElementById('fpwV2ActionPanel');
  const feedback = document.getElementById('fpwV2ActionFeedback');
  if (!panel || !feedback) {
    return;
  }
  if (panel.getAttribute('data-ac-v2-action-bound') === 'true') {
    return;
  }
  panel.setAttribute('data-ac-v2-action-bound', 'true');

  function setFeedback(message, state) {
    feedback.textContent = message;
    feedback.classList.remove('is-success', 'is-error');
    if (state) {
      feedback.classList.add(state);
    }
    feedback.hidden = false;
    feedback.setAttribute('aria-hidden', 'false');
  }

  function resolveEndpoint(endpoint) {
    if (!endpoint) {
      return '';
    }
    const basePath = panel.getAttribute('data-fpw-base') || '';
    if (endpoint.indexOf('/api/') === 0 && basePath) {
      return basePath + endpoint;
    }
    return endpoint;
  }

  function readPayload(button) {
    try {
      return JSON.parse(button.getAttribute('data-payload') || '{}');
    } catch (payloadError) {
      return {};
    }
  }

  function responseMessage(payload, fallback) {
    if (payload && typeof payload === 'object') {
      return payload.MESSAGE || payload.message || payload.ERROR || payload.error || fallback;
    }
    return fallback;
  }

  function actionConfirmationRequired(button) {
    return String(button.getAttribute('data-confirmation-required') || '').toLowerCase() === 'true';
  }

  function restoreButtons(buttons) {
    buttons.forEach(function(actionButton) {
      actionButton.disabled = actionButton.hasAttribute('aria-disabled');
    });
  }

  function refreshSelectorsForAction(actionName) {
    if (actionName === 'checkin') {
      return [
        '#fpwV2ActionPanel',
        '#fpwV2TimingPanel',
        '#acV2RouteProgressPanel',
        '#fpwActiveCruiseV2PositionNote'
      ];
    }
    return [];
  }

  function showRefreshedFeedback(message) {
    const refreshedFeedback = document.getElementById('fpwV2ActionFeedback');
    if (refreshedFeedback) {
      refreshedFeedback.textContent = message;
      refreshedFeedback.classList.remove('is-error');
      refreshedFeedback.classList.add('is-success');
      refreshedFeedback.hidden = false;
      refreshedFeedback.setAttribute('aria-hidden', 'false');
    }
  }

  function buildPositionLocationPayload(position) {
    const coords = position && position.coords ? position.coords : {};
    const location = {
      source: 'ACTIVE_CRUISE_WEB',
      latitude: coords.latitude,
      longitude: coords.longitude,
      capturedAtUtc: new Date(
        position && typeof position.timestamp === 'number'
          ? position.timestamp
          : Date.now()
      ).toISOString()
    };

    if (typeof coords.accuracy === 'number' && isFinite(coords.accuracy)) {
      location.accuracyMeters = coords.accuracy;
    }
    if (typeof coords.altitude === 'number' && isFinite(coords.altitude)) {
      location.altitudeMeters = coords.altitude;
    }
    if (typeof coords.speed === 'number' && isFinite(coords.speed) && coords.speed >= 0) {
      location.speedKnots = coords.speed * 1.94384449;
    }
    if (typeof coords.heading === 'number' && isFinite(coords.heading)) {
      location.headingDegrees = coords.heading;
    }
    return location;
  }

  function captureCheckInLocation() {
    return new Promise(function(resolve) {
      if (!navigator.geolocation || typeof navigator.geolocation.getCurrentPosition !== 'function') {
        resolve(null);
        return;
      }
      navigator.geolocation.getCurrentPosition(
        function(position) {
          resolve(buildPositionLocationPayload(position));
        },
        function() {
          resolve(null);
        },
        {
          enableHighAccuracy: true,
          timeout: 8000,
          maximumAge: 60000
        }
      );
    });
  }

  function submitAction(endpoint, payload, buttons, actionName) {
    const requestPayload = payload || {};
    fetch(endpoint, {
      method: 'POST',
      credentials: 'same-origin',
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json'
      },
      body: JSON.stringify(requestPayload)
    })
      .then(function(response) {
        return response.text().then(function(text) {
          let payload = {};
          if (text) {
            try {
              payload = JSON.parse(text);
            } catch (parseError) {
              payload = { success: false, message: text };
            }
          }
          return { ok: response.ok, payload: payload };
        });
      })
      .then(function(result) {
        const payload = result.payload || {};
        const success = result.ok && (payload.success === true || payload.SUCCESS === true);
        const message = responseMessage(payload, success ? 'Action completed.' : 'Action failed.');
        if (success) {
          if (actionName === 'checkin' && window.FPWAnalytics && typeof window.FPWAnalytics.track === 'function') {
            const checkInStatus = String(
              requestPayload.status || requestPayload.tripStatus || requestPayload.currentState || 'checkin'
            ).trim().toLowerCase().replace(/\s+/g, '_');
            window.FPWAnalytics.track('check_in_submitted', {
              check_in_type: checkInStatus || 'checkin',
              has_location: !!requestPayload.location,
              source: 'active_cruise'
            });
          }
          setFeedback(message + ' Refreshing view model...', 'is-success');
          const refreshSelectors = refreshSelectorsForAction(actionName);
          if (refreshSelectors.length && typeof window.FPWActiveCruiseV2.fetchAndRefresh === 'function') {
            return window.FPWActiveCruiseV2.fetchAndRefresh({
              replaceSelectors: refreshSelectors
            }).then(function() {
              showRefreshedFeedback(message);
            }).catch(function() {
              setFeedback(message + ' The check-in was submitted, but the view could not refresh. Please refresh manually to see the latest data.', 'is-error');
              restoreButtons(buttons);
            });
          }
          if (refreshSelectors.length) {
            setFeedback(message + ' The check-in was submitted, but background refresh is unavailable. Please refresh manually to see the latest data.', 'is-error');
            restoreButtons(buttons);
            return;
          }
          window.location.reload();
          return;
        }
        setFeedback(message, 'is-error');
        restoreButtons(buttons);
      })
      .catch(function(error) {
        setFeedback(error && error.message ? error.message : 'Action request failed.', 'is-error');
        restoreButtons(buttons);
      });
  }

  panel.addEventListener('click', function(event) {
    const button = event.target.closest('[data-ac-v2-action]');
    if (!button || button.disabled) {
      return;
    }

    const endpoint = resolveEndpoint(button.getAttribute('data-endpoint') || '');
    if (!endpoint) {
      setFeedback('The view model did not return an executable endpoint for this action.', 'is-error');
      return;
    }

    const actionName = button.getAttribute('data-ac-v2-action') || '';
    const payload = readPayload(button);
    if (actionName === 'checkin') {
      const noteInput = document.getElementById('fpwV2CheckInNote');
      const noteValue = noteInput ? String(noteInput.value || '') : '';
      if (noteValue.trim()) {
        payload.note = noteValue;
      } else if (Object.prototype.hasOwnProperty.call(payload, 'note')) {
        delete payload.note;
      }
    }

    if (actionConfirmationRequired(button)) {
      const confirmationMessage = button.getAttribute('data-confirmation-message') || 'Confirm this action?';
      if (!window.confirm(confirmationMessage || 'Confirm this action?')) {
        return;
      }
    }

    const buttons = panel.querySelectorAll('[data-ac-v2-action]');
    buttons.forEach(function(actionButton) {
      actionButton.disabled = true;
    });

    if (actionName === 'checkin') {
      setFeedback('Requesting GPS for this check-in...', '');
      captureCheckInLocation().then(function(location) {
        if (location) {
          payload.location = location;
          setFeedback('GPS captured with check-in. Submitting check-in...', '');
        } else {
          if (Object.prototype.hasOwnProperty.call(payload, 'location')) {
            delete payload.location;
          }
          setFeedback('GPS unavailable; submitting check-in without location.', '');
        }
        submitAction(endpoint, payload, buttons, actionName);
      });
      return;
    }

    setFeedback('Submitting action...', '');
    submitAction(endpoint, payload, buttons, actionName);
  });
};
window.FPWActiveCruiseV2.bindActionPanel();
</script>
</body>
</html>
