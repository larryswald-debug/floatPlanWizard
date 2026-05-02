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

  function fpwV2Percent(any value="") {
    if (!isNumeric(arguments.value)) {
      return "--";
    }
    return numberFormat(val(arguments.value), "0.0") & "%";
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
    if (listFindNoCase("late,missed,escalated,assistance_needed,unknown_error", stateValue)) {
      return "is-alert";
    }
    if (stateValue EQ "paused_overnight") {
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
  activeCruiseV2AccessMessage = "Active Cruise V2 is available only for your current active route-backed float plan.";
  activeCruiseV2AccessDetail = "";
  activeCruiseV2CurrentGroup = {};
  activeCruiseV2Model = {};

  if (isNumeric(fpwV2HookValue("floatPlanId"))) {
    activeCruiseV2RequestedFloatPlanId = val(fpwV2HookValue("floatPlanId"));
  }

  if (activeCruiseV2UserId LTE 0) {
    activeCruiseV2AccessMessage = "Sign in to view Active Cruise V2.";
    activeCruiseV2AccessDetail = "The V2 shell uses the authenticated session user as its access authority.";
  } else {
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
        try {
          activeCruiseV2Model = createObject("component", "fpw.api.v1.ActiveCruiseViewModelService")
            .init(activeCruiseV2Datasource)
            .getActiveCruiseViewModel(activeCruiseV2UserId, activeCruiseV2FloatPlanId);
        } catch (any viewModelPathErr) {
          activeCruiseV2Model = createObject("component", "api.v1.ActiveCruiseViewModelService")
            .init(activeCruiseV2Datasource)
            .getActiveCruiseViewModel(activeCruiseV2UserId, activeCruiseV2FloatPlanId);
        }
        activeCruiseV2AccessValid = true;
      }
    }
  }

  if (!isStruct(activeCruiseV2Model) OR !structCount(activeCruiseV2Model)) {
    activeCruiseV2Model = {
      success = false,
      message = activeCruiseV2AccessMessage,
      generatedAtUtc = "",
      tripState = "unknown_error",
      motionState = "unknown",
      safetyState = "normal",
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
</cfscript>
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Active Cruise V2</title>
  <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" integrity="sha256-p4NxAoJBhIIN+hmNHrzRCf9tD/miZyoHS5obTRR9BMY=" crossorigin="">
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
      width: min(1320px, calc(100% - 28px));
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
    .weather-lookup-layout {
      display: grid;
      grid-template-columns: minmax(0, 1fr) minmax(240px, .55fr);
      gap: 14px;
      align-items: start;
    }
    .weather-lookup-form {
      display: grid;
      gap: 12px;
      justify-items: end;
    }
    .weather-choice-row {
      display: flex;
      flex-wrap: wrap;
      gap: 10px;
      align-items: center;
    }
    .weather-choice {
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
    .weather-result {
      display: grid;
      gap: 8px;
      margin-top: 12px;
    }
    .weather-result.is-empty .field-value {
      color: var(--muted);
    }
    .weather-alert-list,
    .weather-warning-list {
      display: grid;
      gap: 8px;
      margin-top: 10px;
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
    .follow-pin.start { background: var(--green); }
    .follow-pin.end { background: var(--amber); }
    .follow-pin.intermediate { background: var(--quiet); }
    .follow-boat-marker {
      background: var(--teal);
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
    @media (max-width: 780px) {
      main { width: min(100% - 20px, 1320px); }
      .identity-strip,
      .layout,
      .supporting-grid,
      .hero-main,
      .hero-grid,
      .field-grid,
      .detail-row,
      .weather-lookup-layout,
      .timeline-head {
        grid-template-columns: 1fr;
      }
      table { font-size: .84rem; }
    }
  </style>
</head>
<body>
<cfoutput>
  <main>
    <header class="page-top">
      <div>
        <h1>Active Cruise V2</h1>
        <p>Operations layout powered by <code>ActiveCruiseViewModelService</code>.</p>
      </div>
    </header>

    <cfif !activeCruiseV2AccessValid>
      <section class="unavailable">
        <h2>Unavailable</h2>
        <h3>#encodeForHTML(activeCruiseV2AccessMessage)#</h3>
        <p>#encodeForHTML(activeCruiseV2AccessDetail)#</p>
      </section>
    <cfelse>
      <section class="identity-strip" aria-label="Active Cruise V2 identity">
        <div class="identity-cell">
          <div class="identity-label">Route</div>
          <div class="identity-value">#encodeForHTML(fpwV2Text(fpwV2Get(activeCruiseV2Model.route, "routeName"), "Not available"))#</div>
        </div>
        <div class="identity-cell">
          <div class="identity-label">Route Code</div>
          <div class="identity-value">#encodeForHTML(fpwV2Text(fpwV2Get(activeCruiseV2Model.route, "routeCode"), "Not available"))#</div>
        </div>
        <div class="identity-cell">
          <div class="identity-label">Float Plan</div>
          <div class="identity-value">#encodeForHTML(fpwV2Text(fpwV2Get(activeCruiseV2Model.floatPlan, "id"), "Not available"))#</div>
        </div>
        <div class="identity-cell">
          <div class="identity-label">Generated</div>
          <div class="identity-value">#encodeForHTML(fpwV2Text(activeCruiseV2Model.generatedAtUtc, "Not available"))#</div>
        </div>
        <div class="identity-cell">
          <div class="identity-label">View Model</div>
          <div class="identity-value">#encodeForHTML(toString(activeCruiseV2Model.success))#</div>
        </div>
      </section>

      <div class="layout">
        <div class="left-stack">
          <section class="hero" aria-label="Hero and trip state">
            <div class="hero-main">
              <div>
                <div class="status-line">
                  <span class="state-pill #encodeForHTMLAttribute(fpwV2StateClass(activeCruiseV2Model.tripState))#">#encodeForHTML(fpwV2Text(activeCruiseV2Model.tripState, "unknown_error"))#</span>
                  <span class="authority-pill">#encodeForHTML(fpwV2Text(fpwV2Get(activeCruiseV2Model.displayAuthority, "primary"), "unavailable"))#</span>
                </div>
                <h1 class="hero-title">#encodeForHTML(fpwV2Text(fpwV2Get(activeCruiseV2Model.hero, "title"), fpwV2Text(fpwV2Get(activeCruiseV2Model.route, "routeName"), "Active Cruise")))#</h1>
                <p class="hero-subtitle">#encodeForHTML(fpwV2Text(fpwV2Get(activeCruiseV2Model.hero, "statusDetail"), activeCruiseV2Model.message))#</p>
              </div>
              <div class="status-line">
                <span class="authority-pill">Timeline: #encodeForHTML(fpwV2Text(fpwV2Get(activeCruiseV2Model.displayAuthority, "routeTimeline"), "unavailable"))#</span>
                <span class="authority-pill">Monitoring: #encodeForHTML(fpwV2Text(fpwV2Get(activeCruiseV2Model.displayAuthority, "monitoring"), "unavailable"))#</span>
              </div>
            </div>
            <div class="hero-grid">
              <div class="metric">
                <div class="metric-label">Motion</div>
                <div class="metric-value">#encodeForHTML(fpwV2Text(activeCruiseV2Model.motionState, "unknown"))#</div>
                <div class="metric-note">Canonical motion authority</div>
              </div>
              <div class="metric">
                <div class="metric-label">Safety</div>
                <div class="metric-value">#encodeForHTML(fpwV2Text(activeCruiseV2Model.safetyState, "normal"))#</div>
                <div class="metric-note">Monitoring overlay</div>
              </div>
              <div class="metric">
                <div class="metric-label">Scheduled Departure</div>
                <div class="metric-value">#encodeForHTML(fpwV2Text(fpwV2Get(activeCruiseV2Model.floatPlan, "scheduledDepartureLocal"), "Not available"))#</div>
                <div class="metric-note">#encodeForHTML(fpwV2Text(fpwV2Get(activeCruiseV2Model.floatPlan, "timezone"), "timezone unavailable"))#</div>
              </div>
            </div>
          </section>

          <section class="section" aria-label="Current leg">
            <div class="section-header">
              <h2>Current Leg</h2>
              <span class="leg-pill">Leg #encodeForHTML(fpwV2Text(fpwV2Get(activeCruiseV2Model.currentLeg, "order"), "Not available"))#</span>
            </div>
            <h3>#encodeForHTML(fpwV2Text(fpwV2Get(activeCruiseV2Model.currentLeg, "fromName"), "Not available"))# -- #encodeForHTML(fpwV2Text(fpwV2Get(activeCruiseV2Model.currentLeg, "toName"), "Not available"))#</h3>
            <p>#encodeForHTML(fpwV2Text(fpwV2Get(activeCruiseV2Model.currentLeg, "statusLabel"), "Not available"))#</p>
            <div class="progress-track" aria-label="Current leg progress">
              <div class="progress-fill" style="--progress-width: #encodeForHTMLAttribute(fpwV2Percent(fpwV2Get(activeCruiseV2Model.currentLeg, "percentComplete")))#;"></div>
            </div>
            <div class="field-grid">
              <div class="field">
                <div class="field-label">Distance</div>
                <div class="field-value">#encodeForHTML(fpwV2Number(fpwV2Get(activeCruiseV2Model.currentLeg, "distanceNm"), " nm"))#</div>
              </div>
              <div class="field">
                <div class="field-label">Completed</div>
                <div class="field-value">#encodeForHTML(fpwV2Number(fpwV2Get(activeCruiseV2Model.currentLeg, "completedNm"), " nm"))#</div>
              </div>
              <div class="field">
                <div class="field-label">Remaining</div>
                <div class="field-value">#encodeForHTML(fpwV2Number(fpwV2Get(activeCruiseV2Model.currentLeg, "remainingNm"), " nm"))#</div>
              </div>
              <div class="field">
                <div class="field-label">Progress</div>
                <div class="field-value">#encodeForHTML(fpwV2Percent(fpwV2Get(activeCruiseV2Model.currentLeg, "percentComplete")))#</div>
              </div>
              <div class="field">
                <div class="field-label">ETA</div>
                <div class="field-value">#encodeForHTML(fpwV2Text(fpwV2Get(activeCruiseV2Model.currentLeg, "etaUtc"), "Not available"))#</div>
              </div>
              <div class="field">
                <div class="field-label">Authority</div>
                <div class="field-value">#encodeForHTML(fpwV2Text(fpwV2Get(activeCruiseV2Model.currentLeg, "authority"), "Not available"))#</div>
              </div>
            </div>
          </section>

          <section class="timeline" aria-label="Route timeline and progress">
            <div class="timeline-head">
              <div>
                <h2>Route Timeline / Progress</h2>
                <p>Authority: #encodeForHTML(fpwV2Text(fpwV2Get(activeCruiseV2Model.routeTimeline, "authority"), "unavailable"))#</p>
              </div>
              <div class="status-line">
                <span class="authority-pill">Current leg #encodeForHTML(fpwV2Text(fpwV2Get(activeCruiseV2Model.routeTimeline, "currentLegOrder"), "Not available"))#</span>
                <span class="authority-pill">#encodeForHTML(fpwV2Text(fpwV2Get(activeCruiseV2Model.route, "totalLegs"), "0"))# legs</span>
              </div>
            </div>
            <cfif structKeyExists(activeCruiseV2Model.routeTimeline, "available") AND activeCruiseV2Model.routeTimeline.available EQ true AND structKeyExists(activeCruiseV2Model.routeTimeline, "legs")>
              <div class="timeline-body">
                <table>
                  <thead>
                    <tr>
                      <th>Leg</th>
                      <th>Route</th>
                      <th>Status</th>
                      <th>Distance</th>
                      <th>Progress</th>
                      <th>Departure</th>
                      <th>ETA / Arrival</th>
                    </tr>
                  </thead>
                  <tbody>
                    <cfloop array="#activeCruiseV2Model.routeTimeline.legs#" item="leg">
                      <tr class="#encodeForHTMLAttribute(fpwV2LegClass(leg))#">
                        <td>#encodeForHTML(fpwV2Text(fpwV2Get(leg, "routeLegOrder"), "Not available"))#</td>
                        <td>
                          <div class="route-pair">
                            <strong>#encodeForHTML(fpwV2Text(fpwV2Get(leg, "fromName"), "Not available"))#</strong>
                            <span>to #encodeForHTML(fpwV2Text(fpwV2Get(leg, "toName"), "Not available"))#</span>
                          </div>
                        </td>
                        <td>
                          <div>#encodeForHTML(fpwV2Text(fpwV2Get(leg, "state"), "Not available"))#</div>
                          <p>#encodeForHTML(fpwV2Text(fpwV2Get(leg, "status"), "Not available"))#</p>
                        </td>
                        <td>#encodeForHTML(fpwV2Number(fpwV2Get(leg, "distanceNm"), " nm"))#</td>
                        <td>#encodeForHTML(fpwV2Percent(fpwV2Get(leg, "percentComplete")))#</td>
                        <td>#encodeForHTML(fpwV2Text(fpwV2Get(leg, "departureUtc"), "Not available"))#</td>
                        <td>#encodeForHTML(fpwV2Text(fpwV2Get(leg, "etaUtc"), fpwV2Text(fpwV2Get(leg, "arrivalUtc"), "Not available")))#</td>
                      </tr>
                    </cfloop>
                  </tbody>
                </table>
              </div>
            <cfelse>
              <div class="empty-state">
                <h3>Route timeline unavailable</h3>
                <p>The view model did not return an available canonical route timeline.</p>
                <pre>#encodeForHTML(fpwV2Json(activeCruiseV2Model.routeTimeline))#</pre>
              </div>
            </cfif>
          </section>
        </div>

        <aside class="right-stack">
          <section class="section" aria-label="Captain actions">
            <div class="section-header">
              <h2>Captain Actions</h2>
              <span class="authority-pill">View model controlled</span>
            </div>
            <div class="captain-actions" id="fpwV2ActionPanel" data-fpw-base="#encodeForHTMLAttribute(activeCruiseV2BasePath)#">
              <cfset checkAction = {}>
              <cfif structKeyExists(activeCruiseV2Model.actions, "checkIn") AND isStruct(activeCruiseV2Model.actions.checkIn)>
                <cfset checkAction = activeCruiseV2Model.actions.checkIn>
              </cfif>
              <div class="action-group" aria-label="Check-in status actions">
                <h3>Check-In</h3>
                <cfif structKeyExists(activeCruiseV2Model.checkIn, "allowedStatusOptions") AND isArray(activeCruiseV2Model.checkIn.allowedStatusOptions) AND arrayLen(activeCruiseV2Model.checkIn.allowedStatusOptions)>
                  <cfloop array="#activeCruiseV2Model.checkIn.allowedStatusOptions#" item="statusOption">
                    <cfset checkPayload = {}>
                    <cfif structKeyExists(checkAction, "payload") AND isStruct(checkAction.payload)>
                      <cfset checkPayload = duplicate(checkAction.payload)>
                    </cfif>
                    <cfset checkPayload.status = fpwV2Text(fpwV2Get(statusOption, "status"), "")>
                    <cfset checkEnabled = fpwV2ActionEnabled(checkAction) AND fpwV2Get(statusOption, "enabled", true) EQ true>
                    <cfset checkReason = fpwV2Text(fpwV2Get(statusOption, "disabledReason"), fpwV2Text(fpwV2Get(checkAction, "reason"), ""))>
                    <cfif checkEnabled>
                      <cfset checkReason = "">
                    </cfif>
                    <div class="action-row">
                      <button
                        type="button"
                        class="action-button"
                        data-ac-v2-action="checkin"
                        data-endpoint="#encodeForHTMLAttribute(fpwV2Text(fpwV2Get(checkAction, "endpoint"), ""))#"
                        data-payload="#encodeForHTMLAttribute(fpwV2Json(checkPayload))#"
                        <cfif !checkEnabled>disabled aria-disabled="true"</cfif>>
                        #encodeForHTML(fpwV2Text(fpwV2Get(statusOption, "status"), "Status"))#
                      </button>
                      <cfif len(checkReason)>
                        <div class="action-reason">#encodeForHTML(checkReason)#</div>
                      </cfif>
                    </div>
                  </cfloop>
                <cfelse>
                  <p>No check-in status options were returned by the view model.</p>
                </cfif>
              </div>

              <div class="action-group" aria-label="Route and float plan actions">
                <h3>Route / Float Plan</h3>
                <cfset routeActions = [
                  { "key" = "completeLeg", "label" = "Complete Current Leg / Arrived" },
                  { "key" = "startNextLeg", "label" = "Start Next Leg" },
                  { "key" = "closeFloatPlan", "label" = "Close Float Plan" }
                ]>
                <cfloop array="#routeActions#" item="routeAction">
                  <cfset routeActionModel = {}>
                  <cfif structKeyExists(activeCruiseV2Model.actions, routeAction.key) AND isStruct(activeCruiseV2Model.actions[routeAction.key])>
                    <cfset routeActionModel = activeCruiseV2Model.actions[routeAction.key]>
                  </cfif>
                  <cfset routeActionEnabled = fpwV2ActionEnabled(routeActionModel)>
                  <cfset routeActionReason = fpwV2Text(fpwV2Get(routeActionModel, "reason"), "")>
                  <div class="action-row">
                    <button
                      type="button"
                      class="action-button"
                      data-ac-v2-action="#encodeForHTMLAttribute(routeAction.key)#"
                      data-endpoint="#encodeForHTMLAttribute(fpwV2Text(fpwV2Get(routeActionModel, "endpoint"), ""))#"
                      data-payload="#encodeForHTMLAttribute(fpwV2Json(fpwV2Get(routeActionModel, "payload", {})))#"
                      <cfif !routeActionEnabled>disabled aria-disabled="true"</cfif>>
                      #encodeForHTML(routeAction.label)#
                    </button>
                    <cfif len(routeActionReason)>
                      <div class="action-reason">#encodeForHTML(routeActionReason)#</div>
                    </cfif>
                  </div>
                </cfloop>
              </div>

              <div class="action-feedback" id="fpwV2ActionFeedback" role="status" aria-live="polite">Ready. Actions submit existing endpoint and payload contracts returned by the view model.</div>
            </div>
          </section>

          <section class="section" aria-label="Monitoring and safety">
            <div class="section-header">
              <h2>Monitoring / Safety</h2>
              <span class="state-pill #encodeForHTMLAttribute(fpwV2StateClass(activeCruiseV2Model.safetyState))#">#encodeForHTML(fpwV2Text(activeCruiseV2Model.safetyState, "normal"))#</span>
            </div>
            <div class="field-grid">
              <div class="field">
                <div class="field-label">Mode</div>
                <div class="field-value">#encodeForHTML(fpwV2Text(fpwV2Get(activeCruiseV2Model.monitoring, "mode"), "Not available"))#</div>
              </div>
              <div class="field">
                <div class="field-label">State</div>
                <div class="field-value">#encodeForHTML(fpwV2Text(fpwV2Get(activeCruiseV2Model.monitoring, "state"), "Not available"))#</div>
              </div>
              <div class="field">
                <div class="field-label">Expected Check-In</div>
                <div class="field-value">#encodeForHTML(fpwV2Text(fpwV2Get(activeCruiseV2Model.monitoring, "expectedCheckinAtUtc"), "Not available"))#</div>
              </div>
              <div class="field">
                <div class="field-label">Grace Expires</div>
                <div class="field-value">#encodeForHTML(fpwV2Text(fpwV2Get(activeCruiseV2Model.monitoring, "graceExpiresAtUtc"), "Not available"))#</div>
              </div>
              <div class="field">
                <div class="field-label">Last Check-In</div>
                <div class="field-value">#encodeForHTML(fpwV2Text(fpwV2Get(activeCruiseV2Model.monitoring, "lastCheckinAtUtc"), "Not available"))#</div>
              </div>
              <div class="field">
                <div class="field-label">Last Status</div>
                <div class="field-value">#encodeForHTML(fpwV2Text(fpwV2Get(activeCruiseV2Model.monitoring, "lastCheckinStatus"), "Not available"))#</div>
              </div>
              <div class="field">
                <div class="field-label">Secure For Night</div>
                <div class="field-value">#encodeForHTML(toString(fpwV2Get(activeCruiseV2Model.monitoring, "secureForNight", false)))#</div>
              </div>
              <div class="field">
                <div class="field-label">Secure Until</div>
                <div class="field-value">#encodeForHTML(fpwV2Text(fpwV2Get(activeCruiseV2Model.monitoring, "secureForNightUntilUtc"), "Not available"))#</div>
              </div>
            </div>
          </section>

          <section class="warning-panel" aria-label="Warnings and authority diagnostics">
            <div class="section-header">
              <h2>Warnings / Diagnostics</h2>
              <span class="authority-pill">#fpwV2WarningCount(activeCruiseV2Model)# warnings</span>
            </div>
            <p>Projection, view-model consistency, missing-authority, and contradiction warnings are shown here during development.</p>
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
        </aside>
      </div>

      <cfset mapModel = (structKeyExists(activeCruiseV2Model, "map") AND isStruct(activeCruiseV2Model.map) ? activeCruiseV2Model.map : {})>
      <cfset weatherModel = (structKeyExists(activeCruiseV2Model, "weather") AND isStruct(activeCruiseV2Model.weather) ? activeCruiseV2Model.weather : {})>
      <cfset floatPlanInfoModel = (structKeyExists(activeCruiseV2Model, "floatPlanInfo") AND isStruct(activeCruiseV2Model.floatPlanInfo) ? activeCruiseV2Model.floatPlanInfo : {})>
      <cfset vesselModel = (structKeyExists(floatPlanInfoModel, "vessel") AND isStruct(floatPlanInfoModel.vessel) ? floatPlanInfoModel.vessel : {})>
      <cfset operatorModel = (structKeyExists(floatPlanInfoModel, "operator") AND isStruct(floatPlanInfoModel.operator) ? floatPlanInfoModel.operator : {})>
      <cfset contactsModel = (structKeyExists(activeCruiseV2Model, "contacts") AND isStruct(activeCruiseV2Model.contacts) ? activeCruiseV2Model.contacts : { "items" = [], "passengers" = [] })>
      <cfset captainLogModel = (structKeyExists(activeCruiseV2Model, "captainLog") AND isStruct(activeCruiseV2Model.captainLog) ? activeCruiseV2Model.captainLog : { "items" = [], "count" = 0 })>
      <cfset mapLegs = (structKeyExists(mapModel, "legs") AND isArray(mapModel.legs) ? mapModel.legs : [])>
      <cfset mapBounds = (structKeyExists(mapModel, "bounds") AND isStruct(mapModel.bounds) ? mapModel.bounds : {})>
      <cfset mapCenter = (structKeyExists(mapModel, "center") AND isStruct(mapModel.center) ? mapModel.center : {})>
      <cfset mapWarnings = (structKeyExists(mapModel, "warnings") AND isArray(mapModel.warnings) ? mapModel.warnings : [])>
      <cfset mapAvailable = (structKeyExists(mapModel, "available") AND isBoolean(mapModel.available) AND mapModel.available)>
      <cfset mapGeometryAuthority = fpwV2Text(fpwV2Get(mapModel, "geometryAuthority"), "Not available")>
      <cfset mapGeometryAuthorityLabel = replace(mapGeometryAuthority, "_", " ", "all")>
      <cfset weatherPoints = (structKeyExists(weatherModel, "points") AND isStruct(weatherModel.points) ? weatherModel.points : {})>
      <cfset weatherLookup = (structKeyExists(weatherModel, "lookup") AND isStruct(weatherModel.lookup) ? weatherModel.lookup : {})>
      <cfset weatherWarnings = (structKeyExists(weatherModel, "warnings") AND isArray(weatherModel.warnings) ? weatherModel.warnings : [])>
      <cfset weatherLookupAvailable = (structKeyExists(weatherLookup, "available") AND isBoolean(weatherLookup.available) AND weatherLookup.available)>
      <cfset weatherStartPoint = (structKeyExists(weatherPoints, "start") AND isStruct(weatherPoints.start) ? weatherPoints.start : {})>
      <cfset weatherEndPoint = (structKeyExists(weatherPoints, "end") AND isStruct(weatherPoints.end) ? weatherPoints.end : {})>

      <section class="supporting-grid" aria-label="Active Cruise V2 supporting panels">
        <div class="supporting-stack">
          <section class="section" aria-label="Map and route overview">
            <div class="section-header">
              <h2>Map / Route Overview</h2>
              <span class="authority-pill">#encodeForHTML(fpwV2Text(fpwV2Get(mapModel, "authority"), "unavailable"))#</span>
            </div>
            <div class="map-overview" data-ac-v2-map-authority="#encodeForHTMLAttribute(mapGeometryAuthority)#">
              <div class="map-summary-grid">
                <div class="metric">
                  <div class="metric-label">Geometry</div>
                  <div class="metric-value">#encodeForHTML(mapGeometryAuthorityLabel)#</div>
                  <div class="metric-note">Returned by the view model</div>
                </div>
                <div class="metric">
                  <div class="metric-label">Legs</div>
                  <div class="metric-value">#arrayLen(mapLegs)#</div>
                  <div class="metric-note">Route-instance map legs</div>
                </div>
                <div class="metric">
                  <div class="metric-label">Center</div>
                  <div class="metric-value">
                    <cfif structKeyExists(mapCenter, "available") AND mapCenter.available EQ true>
                      #encodeForHTML(numberFormat(val(fpwV2Get(mapCenter, "lat", 0)), "0.000"))#, #encodeForHTML(numberFormat(val(fpwV2Get(mapCenter, "lon", 0)), "0.000"))#
                    <cfelse>
                      Not available
                    </cfif>
                  </div>
                  <div class="metric-note">From view-model bounds</div>
                </div>
              </div>

              <cfif mapAvailable AND structKeyExists(mapBounds, "available") AND mapBounds.available EQ true AND arrayLen(mapLegs)>
                <div class="map-canvas map-leaflet-canvas" aria-label="Read-only route map from Active Cruise V2 view model">
                  <div id="fpwActiveCruiseV2Map" data-ac-v2-map-canvas="true"></div>
                  <div id="fpwActiveCruiseV2MapStatus" class="map-load-state is-visible" aria-live="polite">
                    <span>Loading route map...</span>
                  </div>
                </div>
              <cfelse>
                <div class="panel-note is-warning">
                  Map geometry is not available from the V2 view model for this trip.
                </div>
              </cfif>

              <div class="detail-list">
                <div class="detail-row">
                  <div class="field-label">Route Instance</div>
                  <div class="field-value">#encodeForHTML(fpwV2Text(fpwV2Get(mapModel, "routeInstanceId"), "Not available"))#</div>
                </div>
                <div class="detail-row">
                  <div class="field-label">Stream</div>
                  <div class="field-value">#encodeForHTML(fpwV2Text(fpwV2Get(mapModel, "streamId"), "Not available"))#</div>
                </div>
                <div class="detail-row">
                  <div class="field-label">Timeline</div>
                  <div class="field-value">#encodeForHTML(fpwV2Text(fpwV2Get(activeCruiseV2Model.routeTimeline, "authority"), "unavailable"))#</div>
                </div>
                <div class="detail-row">
                  <div class="field-label">Bounds</div>
                  <div class="field-value">
                    <cfif structKeyExists(mapBounds, "available") AND mapBounds.available EQ true>
                      S #encodeForHTML(numberFormat(val(fpwV2Get(mapBounds, "south", 0)), "0.000"))# / W #encodeForHTML(numberFormat(val(fpwV2Get(mapBounds, "west", 0)), "0.000"))# / N #encodeForHTML(numberFormat(val(fpwV2Get(mapBounds, "north", 0)), "0.000"))# / E #encodeForHTML(numberFormat(val(fpwV2Get(mapBounds, "east", 0)), "0.000"))#
                    <cfelse>
                      Not available
                    </cfif>
                  </div>
                </div>
              </div>

              <cfif arrayLen(mapLegs)>
                <div class="panel-subhead">Route Legs</div>
                <div class="map-leg-list">
                  <cfloop array="#mapLegs#" item="mapLeg">
                    <div class="map-leg-row">
                      <div class="map-leg-order">#encodeForHTML(fpwV2Text(fpwV2Get(mapLeg, "order"), "--"))#</div>
                      <div class="map-leg-route">#encodeForHTML(fpwV2Text(fpwV2Get(mapLeg, "fromName"), "Start"))# to #encodeForHTML(fpwV2Text(fpwV2Get(mapLeg, "toName"), "End"))#</div>
                      <div class="map-leg-meta">#encodeForHTML(fpwV2Number(fpwV2Get(mapLeg, "distanceNm"), " nm"))#</div>
                    </div>
                  </cfloop>
                </div>
              </cfif>

              <cfif arrayLen(mapWarnings)>
                <div class="warning-list">
                  <cfloop array="#mapWarnings#" item="mapWarning">
                    <div class="warning-item">
                      <h3>#encodeForHTML(fpwV2Text(fpwV2Get(mapWarning, "code"), "Map warning"))#</h3>
                      <p>#encodeForHTML(fpwV2Text(fpwV2Get(mapWarning, "message"), "No map warning message returned."))#</p>
                    </div>
                  </cfloop>
                </div>
              </cfif>
            </div>
          </section>

          <section class="section" aria-label="Weather lookup">
            <div class="section-header">
              <h2>Weather Lookup</h2>
              <span class="authority-pill">#encodeForHTML(fpwV2Text(fpwV2Get(weatherModel, "authority"), "unavailable"))#</span>
            </div>
            <div id="fpwV2WeatherLookup" class="weather-lookup-layout" data-fpw-base="#encodeForHTMLAttribute(activeCruiseV2BasePath)#">
              <div>
                <div class="panel-subhead">Lookup Point</div>
                <p class="metric-note">Select a current-leg point, then check conditions. Weather is not loaded until this lookup is submitted.</p>
                <div class="detail-list">
                  <div class="detail-row">
                    <div class="field-label">Route Instance</div>
                    <div class="field-value">#encodeForHTML(fpwV2Text(fpwV2Get(weatherModel, "routeInstanceId"), "Not available"))#</div>
                  </div>
                  <div class="detail-row">
                    <div class="field-label">Current Leg</div>
                    <div class="field-value">#encodeForHTML(fpwV2Text(fpwV2Get(weatherModel, "currentLegOrder"), "Not available"))#</div>
                  </div>
                  <div class="detail-row">
                    <div class="field-label">Source</div>
                    <div class="field-value">#encodeForHTML(fpwV2Text(fpwV2Get(weatherModel, "source"), "Not available"))#</div>
                  </div>
                </div>
              </div>
              <form id="fpwV2WeatherForm" class="weather-lookup-form">
                <div class="panel-subhead">Current Leg</div>
                <div class="weather-choice-row">
                  <label class="weather-choice">
                    <input type="radio" name="fpwV2WeatherPoint" value="start"<cfif structKeyExists(weatherStartPoint, "available") AND weatherStartPoint.available EQ true> checked</cfif><cfif !structKeyExists(weatherStartPoint, "available") OR weatherStartPoint.available NEQ true> disabled</cfif>>
                    <span>#encodeForHTML(fpwV2Text(fpwV2Get(weatherStartPoint, "label"), "Start"))#</span>
                  </label>
                  <label class="weather-choice">
                    <input type="radio" name="fpwV2WeatherPoint" value="end"<cfif (!structKeyExists(weatherStartPoint, "available") OR weatherStartPoint.available NEQ true) AND structKeyExists(weatherEndPoint, "available") AND weatherEndPoint.available EQ true> checked</cfif><cfif !structKeyExists(weatherEndPoint, "available") OR weatherEndPoint.available NEQ true> disabled</cfif>>
                    <span>#encodeForHTML(fpwV2Text(fpwV2Get(weatherEndPoint, "label"), "End"))#</span>
                  </label>
                </div>
                <button type="submit" class="action-button"<cfif !weatherLookupAvailable> disabled</cfif>>Check Conditions</button>
              </form>
            </div>

            <cfif !weatherLookupAvailable>
              <div class="panel-note is-warning">
                #encodeForHTML(fpwV2Text(fpwV2Get(weatherModel, "message"), "Weather lookup is not currently available."))#
              </div>
            <cfelse>
              <div id="fpwV2WeatherFeedback" class="panel-note">
                #encodeForHTML(fpwV2Text(fpwV2Get(weatherModel, "message"), "Select a current-leg point and check conditions."))#
              </div>
            </cfif>

            <div id="fpwV2WeatherResult" class="weather-result is-empty" aria-live="polite">
              <div class="detail-list">
                <div class="detail-row">
                  <div class="field-label">Point</div>
                  <div class="field-value" data-weather-field="point">Not checked</div>
                </div>
                <div class="detail-row">
                  <div class="field-label">Summary</div>
                  <div class="field-value" data-weather-field="summary">Not checked</div>
                </div>
                <div class="detail-row">
                  <div class="field-label">Temperature</div>
                  <div class="field-value" data-weather-field="temperature">Not checked</div>
                </div>
                <div class="detail-row">
                  <div class="field-label">Wind</div>
                  <div class="field-value" data-weather-field="wind">Not checked</div>
                </div>
                <div class="detail-row">
                  <div class="field-label">Gusts</div>
                  <div class="field-value" data-weather-field="gusts">Not checked</div>
                </div>
                <div class="detail-row">
                  <div class="field-label">Waves</div>
                  <div class="field-value" data-weather-field="waves">Not checked</div>
                </div>
                <div class="detail-row">
                  <div class="field-label">Visibility</div>
                  <div class="field-value" data-weather-field="visibility">Not checked</div>
                </div>
                <div class="detail-row">
                  <div class="field-label">Alerts</div>
                  <div class="field-value" data-weather-field="alerts">Not checked</div>
                </div>
              </div>
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

        <div class="supporting-stack">
          <section class="section" aria-label="Float plan information">
            <div class="section-header">
              <h2>Float Plan Info</h2>
              <span class="authority-pill">View model</span>
            </div>
            <div class="detail-list">
              <div class="detail-row">
                <div class="field-label">Name</div>
                <div class="field-value">#encodeForHTML(fpwV2Text(fpwV2Get(activeCruiseV2Model.floatPlan, "name"), "Not available"))#</div>
              </div>
              <div class="detail-row">
                <div class="field-label">Status</div>
                <div class="field-value">#encodeForHTML(fpwV2Text(fpwV2Get(activeCruiseV2Model.floatPlan, "status"), "Not available"))#</div>
              </div>
              <div class="detail-row">
                <div class="field-label">Activated</div>
                <div class="field-value">#encodeForHTML(fpwV2Text(fpwV2Get(activeCruiseV2Model.floatPlan, "activatedAtUtc"), "Not available"))#</div>
              </div>
              <div class="detail-row">
                <div class="field-label">Checked In</div>
                <div class="field-value">#encodeForHTML(fpwV2Text(fpwV2Get(activeCruiseV2Model.floatPlan, "checkedInAtUtc"), "Not available"))#</div>
              </div>
              <div class="detail-row">
                <div class="field-label">Vessel</div>
                <div class="field-value">#encodeForHTML(fpwV2Text(fpwV2Get(vesselModel, "name"), "Not available"))#</div>
              </div>
              <div class="detail-row">
                <div class="field-label">Vessel Details</div>
                <div class="field-value">#encodeForHTML(fpwV2Text(fpwV2Get(vesselModel, "type"), "Not available"))# / #encodeForHTML(fpwV2Number(fpwV2Get(vesselModel, "length"), " ft"))#</div>
              </div>
              <div class="detail-row">
                <div class="field-label">Operator</div>
                <div class="field-value">#encodeForHTML(fpwV2Text(fpwV2Get(operatorModel, "name"), "Not available"))#</div>
              </div>
              <div class="detail-row">
                <div class="field-label">Notes</div>
                <div class="field-value">#encodeForHTML(fpwV2Text(fpwV2Get(floatPlanInfoModel, "notes"), "Not available"))#</div>
              </div>
            </div>
          </section>

          <section class="section" aria-label="Contacts and notification contacts">
            <div class="section-header">
              <h2>Contacts / Notifications</h2>
              <span class="authority-pill">#encodeForHTML(fpwV2Text(fpwV2Get(contactsModel, "count"), "0"))# contacts</span>
            </div>
            <div class="panel-subhead">Notification Contacts</div>
            <cfif structKeyExists(contactsModel, "items") AND isArray(contactsModel.items) AND arrayLen(contactsModel.items)>
              <div class="contact-list">
                <cfloop array="#contactsModel.items#" item="contactItem">
                  <div class="contact-item">
                    <h3>#encodeForHTML(fpwV2Text(fpwV2Get(contactItem, "name"), "Unnamed contact"))#</h3>
                    <p>#encodeForHTML(fpwV2Text(fpwV2Get(contactItem, "phone"), "Phone not available"))#</p>
                    <p>#encodeForHTML(fpwV2Text(fpwV2Get(contactItem, "email"), "Email not available"))#</p>
                  </div>
                </cfloop>
              </div>
            <cfelse>
              <div class="panel-note">No notification contacts were returned by the view model.</div>
            </cfif>

            <div class="panel-subhead">Passengers</div>
            <cfif structKeyExists(contactsModel, "passengers") AND isArray(contactsModel.passengers) AND arrayLen(contactsModel.passengers)>
              <div class="contact-list">
                <cfloop array="#contactsModel.passengers#" item="passengerItem">
                  <div class="contact-item">
                    <h3>#encodeForHTML(fpwV2Text(fpwV2Get(passengerItem, "name"), "Unnamed passenger"))#</h3>
                    <p>#encodeForHTML(fpwV2Text(fpwV2Get(passengerItem, "phone"), "Phone not available"))#</p>
                  </div>
                </cfloop>
              </div>
            <cfelse>
              <div class="panel-note">No passengers were returned by the view model.</div>
            </cfif>
          </section>

          <section class="section" aria-label="Captain log">
            <div class="section-header">
              <h2>Captain Log</h2>
              <span class="authority-pill">Read only</span>
            </div>
            <cfif structKeyExists(captainLogModel, "items") AND isArray(captainLogModel.items) AND arrayLen(captainLogModel.items)>
              <div class="log-list">
                <cfloop array="#captainLogModel.items#" item="logItem">
                  <div class="log-item">
                    <h3>#encodeForHTML(fpwV2Text(fpwV2Get(logItem, "note_tag"), "Captain note"))#</h3>
                    <p>#encodeForHTML(fpwV2Text(fpwV2Get(logItem, "note_body"), "No note text returned."))#</p>
                    <div class="warning-source">Leg #encodeForHTML(fpwV2Text(fpwV2Get(logItem, "route_leg_order"), "n/a"))# / #encodeForHTML(fpwV2Text(fpwV2Get(logItem, "created_utc"), "time unavailable"))#</div>
                  </div>
                </cfloop>
              </div>
            <cfelse>
              <div class="panel-note">No private captain log entries were returned by the view model. Write controls are not wired in this phase.</div>
            </cfif>
          </section>
        </div>
      </section>
    </cfif>
  </main>
  <cfif activeCruiseV2AccessValid>
    <script id="fpwActiveCruiseV2MapPayload" type="application/json">#fpwV2JsonForScript(mapModel)#</script>
    <script id="fpwActiveCruiseV2WeatherPayload" type="application/json">#fpwV2JsonForScript(weatherModel)#</script>
  </cfif>
  <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js" integrity="sha256-20nQCchB9co0qIjJZRGuk2/Z9VM+kNiyxNV1lvTlZBo=" crossorigin=""></script>
  <script src="#encodeForHTMLAttribute(activeCruiseV2BasePath)#/assets/js/app/follow/followMap.js?v=20260423a"></script>
</cfoutput>
<script>
(function() {
  const mapEl = document.getElementById('fpwActiveCruiseV2Map');
  const payloadEl = document.getElementById('fpwActiveCruiseV2MapPayload');
  const statusEl = document.getElementById('fpwActiveCruiseV2MapStatus');

  function setMapStatus(message, visible) {
    const label = statusEl ? statusEl.querySelector('span') : null;
    if (!statusEl || !label) {
      return;
    }
    label.textContent = message;
    statusEl.classList.toggle('is-visible', visible === true);
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

  function buildPins(mapModel) {
    const legs = Array.isArray(mapModel.legs) ? mapModel.legs : [];
    const pins = [];
    let firstPoint = null;
    let lastPoint = null;

    if (legs.length) {
      firstPoint = normalizePoint(legs[0] && legs[0].from);
      lastPoint = normalizePoint(legs[legs.length - 1] && legs[legs.length - 1].to);
    }
    if (firstPoint) {
      pins.push({
        type: 'start',
        label: firstPoint.name || 'Start',
        lat: firstPoint.lat,
        lng: firstPoint.lng,
        sequence: 1
      });
    }
    if (lastPoint) {
      pins.push({
        type: 'end',
        label: lastPoint.name || 'End',
        lat: lastPoint.lat,
        lng: lastPoint.lng,
        sequence: legs.length || 2
      });
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
    const routeGeo = buildRouteGeo(mapModel);
    const pins = buildPins(mapModel);
    const currentPosition = normalizePoint(mapModel.currentPosition);
    let mapInstance = null;

    if (!mapEl || !payloadEl) {
      return;
    }
    if (!window.L || !window.FPWFollowMap || typeof window.FPWFollowMap.initFollowMap !== 'function') {
      setMapStatus('Leaflet map renderer is not available.', true);
      return;
    }
    if (!mapModel.available || !routeGeo.coordinates.length) {
      setMapStatus('Map geometry is not available from the V2 view model.', true);
      return;
    }

    mapInstance = window.FPWFollowMap.initFollowMap('fpwActiveCruiseV2Map', {});
    window.FPWFollowMap.renderRoute(routeGeo);
    window.FPWFollowMap.renderPins(pins);
    window.FPWFollowMap.fitBoundsToRoute(routeGeo, pins);

    if (currentPosition && typeof window.FPWFollowMap.updateBoatMarker === 'function') {
      window.FPWFollowMap.updateBoatMarker(currentPosition.lat, currentPosition.lng, currentPosition.name || 'Current position');
    }
    if (mapInstance && typeof mapInstance.invalidateSize === 'function') {
      window.setTimeout(function() {
        mapInstance.invalidateSize();
        window.FPWFollowMap.fitBoundsToRoute(routeGeo, pins);
      }, 100);
    }

    mapEl.setAttribute('data-ac-v2-map-rendered', 'true');
    mapEl.setAttribute('data-ac-v2-map-point-count', String(routeGeo.coordinates.length * 2));
    setMapStatus('Route map loaded.', false);
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', renderMap);
  } else {
    renderMap();
  }
})();

(function() {
  const root = document.getElementById('fpwV2WeatherLookup');
  const form = document.getElementById('fpwV2WeatherForm');
  const feedback = document.getElementById('fpwV2WeatherFeedback');
  const result = document.getElementById('fpwV2WeatherResult');
  const payloadEl = document.getElementById('fpwActiveCruiseV2WeatherPayload');

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
    feedback.textContent = message;
    feedback.classList.remove('is-warning', 'is-success', 'is-error');
    if (state) {
      feedback.classList.add(state);
    }
  }

  function setField(name, value) {
    const field = result.querySelector('[data-weather-field="' + name + '"]');
    if (field) {
      field.textContent = textValue(value, 'Not available');
    }
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

    result.classList.remove('is-empty');
    setField('point', pointLabel);
    setField('summary', summary);
    setField('temperature', temperature);
    setField('wind', wind);
    setField('gusts', gusts);
    setField('waves', waves);
    setField('visibility', visibility);
    setField('alerts', alertText);
  }

  form.addEventListener('submit', function(event) {
    event.preventDefault();

    const weatherModel = readWeatherModel();
    const lookup = weatherModel && typeof weatherModel === 'object' && weatherModel.lookup && typeof weatherModel.lookup === 'object' ? weatherModel.lookup : {};
    const endpoint = resolveEndpoint(lookup.endpoint || '');
    const selectedPoint = form.querySelector('input[name="fpwV2WeatherPoint"]:checked');
    const button = form.querySelector('button[type="submit"]');
    const requestPayload = Object.assign({}, lookup.payload || {}, {
      point: selectedPoint ? selectedPoint.value : ''
    });

    if (!endpoint || !requestPayload.point) {
      setFeedback('The view model did not return an executable weather lookup contract.', 'is-warning');
      return;
    }

    if (button) {
      button.disabled = true;
    }
    setFeedback('Checking conditions...', '');

    fetch(endpoint, {
      method: lookup.method || 'POST',
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
      .then(function(resultPayload) {
        const responsePayload = resultPayload.payload || {};
        const success = resultPayload.ok && (responsePayload.success === true || responsePayload.SUCCESS === true);
        const data = getAny(responsePayload, ['data', 'DATA'], {});
        const available = getAny(data, ['available', 'AVAILABLE'], false) === true;
        const message = textValue(getAny(responsePayload, ['MESSAGE', 'message'], getAny(data, ['message', 'MESSAGE'], 'Weather lookup completed.')), 'Weather lookup completed.');

        renderWeatherPayload(responsePayload);
        setFeedback(message, success && available ? 'is-success' : 'is-warning');
      })
      .catch(function(error) {
        setFeedback(error && error.message ? error.message : 'Weather lookup failed.', 'is-error');
      })
      .finally(function() {
        if (button) {
          button.disabled = false;
        }
      });
  });
})();

(function() {
  const panel = document.getElementById('fpwV2ActionPanel');
  const feedback = document.getElementById('fpwV2ActionFeedback');
  if (!panel || !feedback) {
    return;
  }

  function setFeedback(message, state) {
    feedback.textContent = message;
    feedback.classList.remove('is-success', 'is-error');
    if (state) {
      feedback.classList.add(state);
    }
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

    const buttons = panel.querySelectorAll('[data-ac-v2-action]');
    buttons.forEach(function(actionButton) {
      actionButton.disabled = true;
    });
    setFeedback('Submitting action...', '');

    fetch(endpoint, {
      method: 'POST',
      credentials: 'same-origin',
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json'
      },
      body: JSON.stringify(readPayload(button))
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
          setFeedback(message + ' Refreshing view model...', 'is-success');
          window.location.reload();
          return;
        }
        setFeedback(message, 'is-error');
        buttons.forEach(function(actionButton) {
          actionButton.disabled = actionButton.hasAttribute('aria-disabled');
        });
      })
      .catch(function(error) {
        setFeedback(error && error.message ? error.message : 'Action request failed.', 'is-error');
        buttons.forEach(function(actionButton) {
          actionButton.disabled = actionButton.hasAttribute('aria-disabled');
        });
      });
  });
})();
</script>
</body>
</html>
