<cfinclude template="../includes/require_auth.cfm">
<cfscript>
  function fpwMonitoringHookValue(required string key) {
    var raw = "";
    if (structKeyExists(url, key) AND isSimpleValue(url[key])) {
      raw = trim(url[key] & "");
    }
    return reReplace(raw, "[\r\n]+", " ", "all");
  }

  function fpwMonitoringResolveSessionUserId() {
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

  function fpwMonitoringResolveDatasource() {
    if (structKeyExists(application, "dsn")) {
      var appDsn = trim(toString(application.dsn));
      if (len(appDsn)) {
        return appDsn;
      }
    }
    return "fpw";
  }

  function fpwMonitoringGet(required struct source, required string key, any defaultValue="") {
    if (structKeyExists(arguments.source, arguments.key) AND !isNull(arguments.source[arguments.key])) {
      return arguments.source[arguments.key];
    }
    return arguments.defaultValue;
  }

  function fpwMonitoringText(any value="", string fallback="--") {
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

  function fpwMonitoringBool(any value=false) {
    if (isBoolean(arguments.value)) {
      return arguments.value;
    }
    if (isNumeric(arguments.value)) {
      return val(arguments.value) NEQ 0;
    }
    return false;
  }

  function fpwMonitoringNumber(any value="", string fallback="--") {
    if (!isNumeric(arguments.value)) {
      return arguments.fallback;
    }
    return numberFormat(val(arguments.value), "0.######");
  }

  function fpwMonitoringCoordinate(any value="") {
    if (!isNumeric(arguments.value)) {
      return "--";
    }
    return numberFormat(val(arguments.value), "0.000000");
  }

  function fpwMonitoringList(any value=[]) {
    if (isArray(arguments.value)) {
      return arguments.value;
    }
    return [];
  }

  function fpwMonitoringStruct(any value={}) {
    if (isStruct(arguments.value)) {
      return arguments.value;
    }
    return {};
  }

  function fpwMonitoringJson(any value={}) {
    try {
      return serializeJSON(arguments.value);
    } catch (any jsonErr) {
      return "{}";
    }
  }

  function fpwMonitoringJsonForScript(any value={}) {
    return replace(fpwMonitoringJson(arguments.value), "</", "<\/", "all");
  }

  function fpwMonitoringPillClass(any value="") {
    var tone = lCase(trim(toString(arguments.value)));
    if (listFindNoCase("success,active,good,all good", tone)) {
      return "fpw-monitoring-pill--success";
    }
    if (listFindNoCase("warning,late,missed,fair", tone)) {
      return "fpw-monitoring-pill--warning";
    }
    if (listFindNoCase("danger,escalated,poor", tone)) {
      return "fpw-monitoring-pill--danger";
    }
    return "fpw-monitoring-pill--muted";
  }

  function fpwMonitoringToneClass(any value="") {
    var tone = lCase(trim(toString(arguments.value)));
    if (listFindNoCase("success,active,good,all good", tone)) {
      return "fpw-monitoring-tone--success";
    }
    if (listFindNoCase("warning,late,missed,fair", tone)) {
      return "fpw-monitoring-tone--warning";
    }
    if (listFindNoCase("danger,escalated,poor", tone)) {
      return "fpw-monitoring-tone--danger";
    }
    if (listFindNoCase("system,neutral", tone)) {
      return "fpw-monitoring-tone--system";
    }
    if (listFindNoCase("info", tone)) {
      return "fpw-monitoring-tone--info";
    }
    return "fpw-monitoring-tone--muted";
  }

  function fpwMonitoringToneLabel(any value="") {
    var tone = lCase(trim(toString(arguments.value)));
    if (listFindNoCase("success,active,good,all good", tone)) {
      return "Good";
    }
    if (listFindNoCase("warning,late,missed,fair", tone)) {
      return "Watch";
    }
    if (listFindNoCase("danger,escalated,poor", tone)) {
      return "Action";
    }
    if (listFindNoCase("system,neutral", tone)) {
      return "System";
    }
    if (listFindNoCase("info", tone)) {
      return "Info";
    }
    return "Note";
  }

  function fpwMonitoringAuditKindLabel(any value="") {
    var typeValue = uCase(trim(toString(arguments.value)));
    if (!len(typeValue)) {
      return "Monitoring event";
    }
    if (find("GPS", typeValue)) {
      return "GPS";
    }
    if (find("COMPANION", typeValue)) {
      return "Companion App";
    }
    if (find("CANONICAL", typeValue)) {
      return "Canonical event";
    }
    if (find("ALERT", typeValue)) {
      return "Alert event";
    }
    if (find("SECURE", typeValue) OR find("DELAY", typeValue) OR find("CHANGED", typeValue) OR find("MONITORING", typeValue)) {
      return "Monitoring event";
    }
    return "System event";
  }

  function fpwMonitoringSourceLabel(any value="") {
    var sourceValue = lCase(trim(toString(arguments.value)));
    if (!len(sourceValue)) {
      return "";
    }
    if (find("companion", sourceValue)) {
      return "Companion App";
    }
    if (find("monitor", sourceValue)) {
      return "Monitoring event";
    }
    if (find("floatplan_events", sourceValue) OR find("canonical", sourceValue)) {
      return "Canonical event";
    }
    return "System event";
  }

  function fpwMonitoringPositiveId(any value=0) {
    return (isNumeric(arguments.value) AND val(arguments.value) GT 0);
  }

  function fpwMonitoringBuildService(required string datasource) {
    try {
      return createObject("component", "fpw.api.v1.MonitoringConsoleViewModelService").init(arguments.datasource);
    } catch (any primaryPathErr) {
      return createObject("component", "api.v1.MonitoringConsoleViewModelService").init(arguments.datasource);
    }
  }

  monitoringUserId = fpwMonitoringResolveSessionUserId();
  monitoringDatasource = fpwMonitoringResolveDatasource();
  monitoringRequestedFloatPlanId = 0;
  monitoringModel = {};
  monitoringService = "";

  if (isNumeric(fpwMonitoringHookValue("floatPlanId"))) {
    monitoringRequestedFloatPlanId = val(fpwMonitoringHookValue("floatPlanId"));
  }

  try {
    monitoringService = fpwMonitoringBuildService(monitoringDatasource);
    monitoringModel = monitoringService.getMonitoringConsoleViewModel(monitoringUserId, monitoringRequestedFloatPlanId);
  } catch (any monitoringPageErr) {
    monitoringModel = {
      success = false,
      version = 1,
      source = "app.monitoring.cfm",
      generatedAtUtc = "",
      generatedAtLocalLabel = "",
      identity = {},
      tripState = {},
      monitoring = {},
      lastCheckinLocation = {},
      map = {},
      auditTimeline = [],
      gpsHistory = [],
      technicalSnapshot = {},
      safetyCopy = {
        notLiveTrackingMessage = "FPW shows the last check-in location shared by the captain.",
        emergencyDisclaimer = "This is not live vessel tracking and may not reflect the vessel's current position. In an emergency, use official emergency channels such as VHF Channel 16, DSC distress, 911, EPIRB/PLB, flares, or other accepted emergency methods.",
        gpsStaleMessage = "",
        noGpsMessage = "No GPS has been captured with a check-in for this monitored trip yet.",
        poorAccuracyMessage = ""
      },
      emptyState = {
        code = "SERVICE_UNAVAILABLE",
        title = "Monitoring Console unavailable",
        message = "The Monitoring Console data could not be prepared safely.",
        actionLabel = "",
        actionHref = "",
        safeForDisplay = true
      },
      warnings = []
    };
  }

  monitoringIdentity = fpwMonitoringStruct(fpwMonitoringGet(monitoringModel, "identity", {}));
  monitoringTripState = fpwMonitoringStruct(fpwMonitoringGet(monitoringModel, "tripState", {}));
  monitoringState = fpwMonitoringStruct(fpwMonitoringGet(monitoringModel, "monitoring", {}));
  monitoringLocation = fpwMonitoringStruct(fpwMonitoringGet(monitoringModel, "lastCheckinLocation", {}));
  monitoringMap = fpwMonitoringStruct(fpwMonitoringGet(monitoringModel, "map", {}));
  monitoringMapLeg = fpwMonitoringStruct(fpwMonitoringGet(monitoringMap, "currentLeg", {}));
  monitoringAuditItems = fpwMonitoringList(fpwMonitoringGet(monitoringModel, "auditTimeline", []));
  monitoringGpsHistory = fpwMonitoringList(fpwMonitoringGet(monitoringModel, "gpsHistory", []));
  monitoringTechnical = fpwMonitoringStruct(fpwMonitoringGet(monitoringModel, "technicalSnapshot", {}));
  monitoringSafety = fpwMonitoringStruct(fpwMonitoringGet(monitoringModel, "safetyCopy", {}));
  monitoringEmpty = fpwMonitoringStruct(fpwMonitoringGet(monitoringModel, "emptyState", {}));
  monitoringWarnings = fpwMonitoringList(fpwMonitoringGet(monitoringModel, "warnings", []));
  monitoringVisibleWarnings = [];
  for (monitoringWarningItem in monitoringWarnings) {
    monitoringWarningStruct = fpwMonitoringStruct(monitoringWarningItem);
    if (fpwMonitoringBool(fpwMonitoringGet(monitoringWarningStruct, "safeForDisplay", true))) {
      arrayAppend(monitoringVisibleWarnings, monitoringWarningStruct);
    }
  }
  monitoringHasLocation = fpwMonitoringBool(fpwMonitoringGet(monitoringLocation, "hasLocation", false));
  monitoringHasRouteGeometry = fpwMonitoringBool(fpwMonitoringGet(monitoringMap, "hasRouteGeometry", false));
  monitoringHasMapPins = (arrayLen(fpwMonitoringList(fpwMonitoringGet(monitoringMap, "pins", []))) GT 0);
  monitoringMapCanRender = (monitoringHasRouteGeometry OR monitoringHasLocation OR monitoringHasMapPins);
  monitoringShowConsole = (structKeyExists(monitoringModel, "success") AND monitoringModel.success EQ true);
</cfscript>
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Monitoring Console - FloatPlanWizard</title>
  <cfinclude template="../includes/header_styles.cfm">
  <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" integrity="sha256-p4NxAoJBhIIN+hmNHrzRCf9tD/miZyoHS5obTRR9BMY=" crossorigin="">
  <style>
    :root {
      color-scheme: dark;
      --fpw-monitoring-bg: #07111f;
      --fpw-monitoring-panel: rgba(13, 27, 47, .96);
      --fpw-monitoring-panel-soft: rgba(15, 23, 42, .72);
      --fpw-monitoring-border: rgba(148, 163, 184, .24);
      --fpw-monitoring-text: #f8fafc;
      --fpw-monitoring-muted: #94a3b8;
      --fpw-monitoring-blue: #38bdf8;
      --fpw-monitoring-green: #34d399;
      --fpw-monitoring-amber: #fbbf24;
      --fpw-monitoring-red: #fb7185;
    }

    body.fpw-monitoring-body {
      background:
        radial-gradient(circle at top left, rgba(14, 165, 233, .16), transparent 28rem),
        radial-gradient(circle at bottom right, rgba(34, 197, 94, .08), transparent 32rem),
        var(--fpw-monitoring-bg);
      color: var(--fpw-monitoring-text);
      min-height: 100vh;
    }

    .fpw-monitoring-shell {
      width: min(var(--fpw-wide-max, 1320px), calc(100% - (var(--fpw-page-gutter, 32px) * 2)));
      margin: 0 auto;
      padding: 1.5rem;
    }

    .fpw-monitoring-panel {
      background: linear-gradient(145deg, rgba(15, 23, 42, .96), rgba(8, 18, 33, .96));
      border: 1px solid var(--fpw-monitoring-border);
      border-radius: 1.15rem;
      box-shadow: 0 24px 60px rgba(0, 0, 0, .25);
    }

    .fpw-monitoring-soft {
      background: var(--fpw-monitoring-panel-soft);
      border: 1px solid var(--fpw-monitoring-border);
      border-radius: .95rem;
    }

    .fpw-monitoring-label {
      color: var(--fpw-monitoring-muted);
      font-size: .72rem;
      font-weight: 800;
      letter-spacing: .12em;
      text-transform: uppercase;
    }

    .fpw-monitoring-muted { color: var(--fpw-monitoring-muted); }

    .fpw-monitoring-title {
      font-size: clamp(1.8rem, 3vw, 3rem);
      font-weight: 800;
      letter-spacing: 0;
      margin: 0;
    }

    .fpw-monitoring-pill {
      display: inline-flex;
      align-items: center;
      gap: .35rem;
      border-radius: 999px;
      border: 1px solid var(--fpw-monitoring-border);
      padding: .35rem .65rem;
      font-size: .78rem;
      font-weight: 800;
      line-height: 1;
      white-space: nowrap;
    }

    .fpw-monitoring-pill--success {
      color: #bbf7d0;
      border-color: rgba(52, 211, 153, .35);
      background: rgba(52, 211, 153, .12);
    }

    .fpw-monitoring-pill--info {
      color: #bae6fd;
      border-color: rgba(56, 189, 248, .38);
      background: rgba(56, 189, 248, .12);
    }

    .fpw-monitoring-pill--warning {
      color: #fde68a;
      border-color: rgba(251, 191, 36, .35);
      background: rgba(251, 191, 36, .12);
    }

    .fpw-monitoring-pill--danger {
      color: #fecdd3;
      border-color: rgba(251, 113, 133, .38);
      background: rgba(251, 113, 133, .12);
    }

    .fpw-monitoring-pill--muted {
      color: #cbd5e1;
      background: rgba(148, 163, 184, .10);
    }

    .fpw-monitoring-stat {
      min-height: 100%;
      padding: 1rem;
      border-radius: 1rem;
      background: linear-gradient(150deg, rgba(56, 189, 248, .12), rgba(15, 23, 42, .52));
      border: 1px solid rgba(56, 189, 248, .18);
    }

    .fpw-monitoring-stat--success {
      background: linear-gradient(150deg, rgba(52, 211, 153, .12), rgba(15, 23, 42, .52));
      border-color: rgba(52, 211, 153, .2);
    }

    .fpw-monitoring-stat--warning {
      background: linear-gradient(150deg, rgba(251, 191, 36, .12), rgba(15, 23, 42, .52));
      border-color: rgba(251, 191, 36, .2);
    }

    .fpw-monitoring-stat-value {
      font-size: clamp(1.35rem, 2vw, 1.8rem);
      font-weight: 800;
      color: #fff;
      line-height: 1.15;
      word-break: break-word;
    }

    .fpw-monitoring-map-shell {
      position: relative;
      min-height: 390px;
      overflow: hidden;
      border-radius: 1.15rem;
      background: #081426;
      border: 1px solid var(--fpw-monitoring-border);
    }

    .fpw-monitoring-map {
      position: absolute;
      inset: 0;
      min-height: 390px;
      background: #081426;
      z-index: 0;
    }

    .fpw-monitoring-map .leaflet-container,
    .fpw-monitoring-map-shell .leaflet-container {
      background: #081426;
      color: #111827;
    }

    .fpw-monitoring-map-shell .leaflet-control-zoom a,
    .fpw-monitoring-map-shell .leaflet-control-attribution {
      color: #1f2937;
    }

    .fpw-monitoring-map-card {
      position: absolute;
      left: 1rem;
      right: 1rem;
      bottom: 1rem;
      z-index: 420;
      background: rgba(2, 6, 23, .84);
      border: 1px solid rgba(52, 211, 153, .32);
      border-radius: 1rem;
      padding: 1rem;
      pointer-events: none;
    }

    .fpw-monitoring-map-route {
      position: absolute;
      top: 1rem;
      left: 1rem;
      z-index: 420;
      max-width: calc(100% - 2rem);
      background: rgba(2, 6, 23, .8);
      border: 1px solid var(--fpw-monitoring-border);
      border-radius: 1rem;
      padding: .85rem 1rem;
      pointer-events: none;
    }

    .fpw-monitoring-map-state {
      position: absolute;
      inset: 12px;
      z-index: 430;
      display: none;
      align-items: flex-start;
      justify-content: flex-start;
      pointer-events: none;
    }

    .fpw-monitoring-map-state.is-visible { display: flex; }

    .fpw-monitoring-map-state span {
      border: 1px solid rgba(37, 70, 83, .75);
      border-radius: .5rem;
      background: rgba(7, 21, 28, .9);
      color: var(--fpw-monitoring-text);
      padding: .55rem .7rem;
      font-size: .84rem;
      font-weight: 800;
    }

    .fpw-monitoring-pin,
    .fpw-monitoring-last-marker {
      display: inline-flex;
      align-items: center;
      justify-content: center;
      width: 17px;
      height: 17px;
      border: 2px solid #fff;
      border-radius: 999px;
      box-shadow: 0 1px 4px rgba(0, 0, 0, .35);
    }

    .fpw-monitoring-pin.start { background: #22c55e; }
    .fpw-monitoring-pin.end { background: #2563eb; }
    .fpw-monitoring-pin.intermediate,
    .fpw-monitoring-pin.leg_end { background: #64748b; }

    .fpw-monitoring-last-marker {
      width: 20px;
      height: 20px;
      background: #10b981;
      border-width: 3px;
    }

    .fpw-monitoring-data-grid {
      display: grid;
      grid-template-columns: repeat(2, minmax(0, 1fr));
      gap: .75rem;
    }

    .fpw-monitoring-tile {
      background: rgba(2, 6, 23, .46);
      border: 1px solid rgba(148, 163, 184, .14);
      border-radius: .85rem;
      padding: .85rem;
      min-width: 0;
    }

    .fpw-monitoring-audit-item {
      display: grid;
      grid-template-columns: 7rem minmax(0, 1fr);
      gap: .85rem;
      padding: .9rem;
      border-radius: 1rem;
      background: rgba(2, 6, 23, .42);
      border: 1px solid rgba(148, 163, 184, .14);
    }

    .fpw-monitoring-notices,
    .fpw-monitoring-audit-list,
    .fpw-monitoring-history-list {
      display: grid;
      gap: .85rem;
    }

    .fpw-monitoring-notice,
    .fpw-monitoring-audit-card,
    .fpw-monitoring-history-card {
      position: relative;
      overflow: hidden;
      border: 1px solid rgba(148, 163, 184, .16);
      border-radius: 1rem;
      background: rgba(2, 6, 23, .44);
      padding: .95rem;
    }

    .fpw-monitoring-audit-card,
    .fpw-monitoring-history-card {
      display: grid;
      gap: .75rem;
    }

    .fpw-monitoring-audit-card::before,
    .fpw-monitoring-history-card::before,
    .fpw-monitoring-notice::before {
      content: "";
      position: absolute;
      inset: 0 auto 0 0;
      width: 4px;
      background: rgba(148, 163, 184, .58);
    }

    .fpw-monitoring-tone--success::before { background: var(--fpw-monitoring-green); }
    .fpw-monitoring-tone--info::before { background: var(--fpw-monitoring-blue); }
    .fpw-monitoring-tone--warning::before { background: var(--fpw-monitoring-amber); }
    .fpw-monitoring-tone--danger::before { background: var(--fpw-monitoring-red); }
    .fpw-monitoring-tone--system::before { background: #cbd5e1; }
    .fpw-monitoring-tone--muted::before { background: rgba(148, 163, 184, .58); }

    .fpw-monitoring-audit-head,
    .fpw-monitoring-history-head {
      display: flex;
      justify-content: space-between;
      align-items: flex-start;
      gap: 1rem;
    }

    .fpw-monitoring-audit-title,
    .fpw-monitoring-history-title {
      font-weight: 800;
      color: #fff;
      line-height: 1.25;
    }

    .fpw-monitoring-audit-time,
    .fpw-monitoring-history-time {
      color: var(--fpw-monitoring-muted);
      font-size: .86rem;
      font-weight: 800;
      white-space: nowrap;
    }

    .fpw-monitoring-meta-row,
    .fpw-monitoring-ref-list {
      display: flex;
      flex-wrap: wrap;
      gap: .45rem;
      align-items: center;
    }

    .fpw-monitoring-mini-pill {
      display: inline-flex;
      align-items: center;
      border: 1px solid rgba(148, 163, 184, .24);
      border-radius: 999px;
      color: #cbd5e1;
      background: rgba(148, 163, 184, .1);
      padding: .26rem .5rem;
      font-size: .72rem;
      font-weight: 800;
      line-height: 1;
      white-space: nowrap;
    }

    .fpw-monitoring-history-grid {
      display: grid;
      grid-template-columns: repeat(2, minmax(0, 1fr));
      gap: .65rem;
    }

    .fpw-monitoring-history-field {
      border: 1px solid rgba(148, 163, 184, .12);
      border-radius: .75rem;
      background: rgba(15, 23, 42, .42);
      padding: .65rem;
      min-width: 0;
    }

    .fpw-monitoring-row-details {
      border-top: 1px solid rgba(148, 163, 184, .14);
      padding-top: .65rem;
    }

    .fpw-monitoring-row-details summary {
      cursor: pointer;
      color: #bae6fd;
      font-size: .82rem;
      font-weight: 800;
    }

    .fpw-monitoring-table {
      --bs-table-bg: transparent;
      --bs-table-color: #e2e8f0;
      --bs-table-border-color: rgba(148, 163, 184, .18);
      margin-bottom: 0;
    }

    .fpw-monitoring-table thead th {
      color: var(--fpw-monitoring-muted);
      font-size: .72rem;
      letter-spacing: .12em;
      text-transform: uppercase;
      font-weight: 800;
      background: rgba(2, 6, 23, .48);
      border-bottom: 1px solid rgba(148, 163, 184, .18);
    }

    .fpw-monitoring-note {
      border-left: 3px solid var(--fpw-monitoring-amber);
      background: rgba(251, 191, 36, .08);
      color: #fde68a;
      border-radius: .8rem;
      padding: .9rem 1rem;
      font-size: .92rem;
      line-height: 1.45;
    }

    .fpw-monitoring-empty {
      padding: 3rem 1.5rem;
      text-align: center;
    }

    .fpw-monitoring-details summary {
      cursor: pointer;
      color: #bae6fd;
      font-weight: 800;
    }

    @media (max-width: 767.98px) {
      .fpw-monitoring-shell {
        width: min(var(--fpw-wide-max, 1320px), calc(100% - (var(--fpw-page-gutter, 32px) * 2)));
        padding: .85rem;
      }
      .fpw-monitoring-data-grid { grid-template-columns: 1fr; }
      .fpw-monitoring-audit-item { grid-template-columns: 1fr; }
      .fpw-monitoring-audit-head,
      .fpw-monitoring-history-head { flex-direction: column; }
      .fpw-monitoring-audit-time,
      .fpw-monitoring-history-time { white-space: normal; }
      .fpw-monitoring-history-grid { grid-template-columns: 1fr; }
      .fpw-monitoring-map-shell,
      .fpw-monitoring-map { min-height: 340px; }
      .fpw-monitoring-map-card,
      .fpw-monitoring-map-route { left: .75rem; right: .75rem; }
    }
  </style>
</head>
<body class="fpw-monitoring-body dashboard-body" data-fpw-page="monitoring">
<cfset request.fpwTopNavActive = "monitoring">
<cfinclude template="../includes/top_nav.cfm">

<main class="fpw-monitoring-shell fpw-layout-rail" id="fpwMonitoringConsole">
  <cfoutput>
  <cfif NOT monitoringShowConsole>
    <section class="fpw-monitoring-panel fpw-monitoring-empty">
      <span class="fpw-monitoring-pill fpw-monitoring-pill--muted">Captain Private View</span>
      <h1 class="fpw-monitoring-title mt-3">Monitoring Console</h1>
      <h2 class="h4 mt-4">#encodeForHTML(fpwMonitoringText(fpwMonitoringGet(monitoringEmpty, "title"), "Monitoring Console unavailable"))#</h2>
      <p class="fpw-monitoring-muted mb-0">#encodeForHTML(fpwMonitoringText(fpwMonitoringGet(monitoringEmpty, "message"), "Monitoring data is not available."))#</p>
    </section>
  <cfelse>
    <section class="fpw-monitoring-panel p-4 p-lg-5 mb-4">
      <div class="row g-4 align-items-center">
        <div class="col-lg-8">
          <div class="d-flex flex-wrap gap-2 mb-3">
            <span class="fpw-monitoring-pill fpw-monitoring-pill--info">Captain Private View</span>
            <span class="fpw-monitoring-pill #encodeForHTMLAttribute(fpwMonitoringPillClass(fpwMonitoringGet(monitoringState, "captainHealthVariant")))#">#encodeForHTML(fpwMonitoringText(fpwMonitoringGet(monitoringState, "captainHealthLabel"), "Status unavailable"))#</span>
            <span class="fpw-monitoring-pill fpw-monitoring-pill--muted">Not live vessel tracking</span>
          </div>
          <h1 class="fpw-monitoring-title">Monitoring Console</h1>
          <p class="fpw-monitoring-muted mt-2 mb-0 fs-6">
            See how FPW is monitoring <strong class="text-white">#encodeForHTML(fpwMonitoringText(fpwMonitoringGet(monitoringIdentity, "vesselName"), "your vessel"))#</strong>,
            the next expected check-in, and the last GPS location shared with a check-in.
          </p>
          <div class="mt-3 fpw-monitoring-muted small">
            <strong class="text-white">#encodeForHTML(fpwMonitoringText(fpwMonitoringGet(monitoringIdentity, "routeName"), "Active route"))#</strong>
            <span class="mx-2">/</span>
            <span>#encodeForHTML(fpwMonitoringText(fpwMonitoringGet(monitoringIdentity, "currentLegLabel"), "Current route leg unavailable"))#</span>
          </div>
        </div>
        <div class="col-lg-4">
          <div class="fpw-monitoring-soft p-3">
            <div class="d-flex justify-content-between gap-3 py-1">
              <span class="fpw-monitoring-muted">Trip State</span>
              <strong>#encodeForHTML(fpwMonitoringText(fpwMonitoringGet(monitoringTripState, "label"), "Unavailable"))#</strong>
            </div>
            <div class="d-flex justify-content-between gap-3 py-1">
              <span class="fpw-monitoring-muted">Health</span>
              <strong>#encodeForHTML(fpwMonitoringText(fpwMonitoringGet(monitoringState, "captainHealthLabel"), "Unavailable"))#</strong>
            </div>
            <div class="d-flex justify-content-between gap-3 py-1">
              <span class="fpw-monitoring-muted">Mode</span>
              <strong>#encodeForHTML(fpwMonitoringText(fpwMonitoringGet(monitoringState, "modeLabel"), fpwMonitoringText(fpwMonitoringGet(monitoringState, "mode"), "Unavailable")))#</strong>
            </div>
          </div>
        </div>
      </div>
    </section>

    <section class="row g-3 mb-4" aria-label="Monitoring summary">
      <div class="col-sm-6 col-xl-3">
        <article class="fpw-monitoring-stat fpw-monitoring-stat--success">
          <div class="fpw-monitoring-label mb-2">Monitoring Status</div>
          <div class="fpw-monitoring-stat-value">#encodeForHTML(fpwMonitoringText(fpwMonitoringGet(monitoringState, "stateLabel"), "Unavailable"))#</div>
          <div class="fpw-monitoring-muted mt-2 small">FPW is evaluating this route-backed float plan.</div>
        </article>
      </div>
      <div class="col-sm-6 col-xl-3">
        <article class="fpw-monitoring-stat fpw-monitoring-stat--warning">
          <div class="fpw-monitoring-label mb-2">Next Check-In</div>
          <div class="fpw-monitoring-stat-value">#encodeForHTML(fpwMonitoringText(fpwMonitoringGet(monitoringState, "expectedCheckinLocalLabel"), "Unavailable"))#</div>
          <div class="fpw-monitoring-muted mt-2 small">Next expected captain check-in.</div>
        </article>
      </div>
      <div class="col-sm-6 col-xl-3">
        <article class="fpw-monitoring-stat">
          <div class="fpw-monitoring-label mb-2">Last Status</div>
          <div class="fpw-monitoring-stat-value">#encodeForHTML(fpwMonitoringText(fpwMonitoringGet(monitoringLocation, "statusLabel"), fpwMonitoringText(fpwMonitoringGet(monitoringState, "lastCheckinStatusLabel"), "Unavailable")))#</div>
          <div class="fpw-monitoring-muted mt-2 small">Most recent check-in status available to the console.</div>
        </article>
      </div>
      <div class="col-sm-6 col-xl-3">
        <article class="fpw-monitoring-stat fpw-monitoring-stat--success">
          <div class="fpw-monitoring-label mb-2">GPS Quality</div>
          <div class="fpw-monitoring-stat-value">#encodeForHTML(fpwMonitoringText(fpwMonitoringGet(monitoringLocation, "accuracyLabel"), "No GPS"))#</div>
          <div class="fpw-monitoring-muted mt-2 small">#encodeForHTML(fpwMonitoringText(fpwMonitoringGet(monitoringLocation, "accuracyQualityLabel"), "GPS not captured"))#</div>
        </article>
      </div>
    </section>

    <cfif arrayLen(monitoringVisibleWarnings)>
      <section class="fpw-monitoring-panel p-3 p-lg-4 mb-4" aria-label="Monitoring Console notices">
        <h2 class="h6 mb-3">Monitoring Console Notices</h2>
        <div class="fpw-monitoring-notices">
          <cfloop array="#monitoringVisibleWarnings#" index="noticeStruct">
            <article class="fpw-monitoring-notice #encodeForHTMLAttribute(fpwMonitoringToneClass(fpwMonitoringGet(noticeStruct, "severity", "info")))#">
              <div class="fpw-monitoring-audit-head">
                <div>
                  <div class="fpw-monitoring-audit-title">#encodeForHTML(fpwMonitoringText(fpwMonitoringGet(noticeStruct, "label"), "Monitoring notice"))#</div>
                  <div class="small fpw-monitoring-muted mt-1">#encodeForHTML(fpwMonitoringText(fpwMonitoringGet(noticeStruct, "detail"), ""))#</div>
                </div>
                <span class="fpw-monitoring-mini-pill">#encodeForHTML(fpwMonitoringToneLabel(fpwMonitoringGet(noticeStruct, "severity", "info")))#</span>
              </div>
            </article>
          </cfloop>
        </div>
      </section>
    </cfif>

    <section class="row g-4 mb-4">
      <div class="col-xl-8">
        <section class="fpw-monitoring-panel p-3 p-lg-4 h-100">
          <div class="d-flex flex-column flex-md-row justify-content-between gap-3 mb-3">
            <div>
              <h2 class="h5 mb-1">Route + Last Check-In Location</h2>
              <p class="fpw-monitoring-muted mb-0 small">This read-only map shows route context and the last GPS location shared with a check-in. It is not live vessel tracking.</p>
            </div>
            <div><span class="fpw-monitoring-pill #encodeForHTMLAttribute(monitoringHasLocation ? "fpw-monitoring-pill--success" : "fpw-monitoring-pill--muted")#">#encodeForHTML(monitoringHasLocation ? "GPS Captured" : "No GPS Yet")#</span></div>
          </div>

          <cfif monitoringMapCanRender>
            <div class="fpw-monitoring-map-shell" aria-label="Read-only map with route and Last Check-In Location">
              <div id="fpwMonitoringMap" class="fpw-monitoring-map" data-fpw-monitoring-map-canvas="true"></div>
              <div id="fpwMonitoringMapStatus" class="fpw-monitoring-map-state is-visible" aria-live="polite"><span>Loading Monitoring Console map...</span></div>
              <div class="fpw-monitoring-map-route">
                <div class="fw-bold">#encodeForHTML(fpwMonitoringText(fpwMonitoringGet(monitoringIdentity, "routeName"), "Active Route"))#</div>
                <div class="fpw-monitoring-muted small">#encodeForHTML(fpwMonitoringText(fpwMonitoringGet(monitoringMapLeg, "label"), fpwMonitoringText(fpwMonitoringGet(monitoringIdentity, "currentLegLabel"), "Current leg unavailable")))#</div>
              </div>
              <div class="fpw-monitoring-map-card">
                <div class="fw-bold text-success">Last Check-In Location</div>
                <cfif monitoringHasLocation>
                  <div class="small fpw-monitoring-muted">
                    #encodeForHTML(fpwMonitoringText(fpwMonitoringGet(monitoringLocation, "statusLabel"), "Check-in"))#
                    <span class="mx-1">/</span>
                    Captured #encodeForHTML(fpwMonitoringText(fpwMonitoringGet(monitoringLocation, "capturedAtLocalLabel"), "capture time unavailable"))#
                    <span class="mx-1">/</span>
                    Accuracy #encodeForHTML(fpwMonitoringText(fpwMonitoringGet(monitoringLocation, "accuracyLabel"), "unavailable"))#
                  </div>
                <cfelse>
                  <div class="small fpw-monitoring-muted">Route geometry is available. Last Check-In Location marker will appear after a GPS-attached check-in.</div>
                </cfif>
              </div>
            </div>
          <cfelse>
            <div class="fpw-monitoring-note">#encodeForHTML(fpwMonitoringText(fpwMonitoringGet(monitoringMap, "noMapReason"), "No route geometry or GPS check-in location is available for the map yet."))#</div>
          </cfif>
        </section>
      </div>

      <div class="col-xl-4">
        <div class="d-grid gap-4">
          <section class="fpw-monitoring-panel p-3 p-lg-4">
            <h2 class="h5 mb-3">Last Check-In Location</h2>
            <cfif monitoringHasLocation>
              <div class="fpw-monitoring-soft p-3 mb-3">
                <div class="fpw-monitoring-label">GPS captured with check-in</div>
                <div class="fw-bold mt-1">#encodeForHTML(fpwMonitoringText(fpwMonitoringGet(monitoringLocation, "capturedAtLocalLabel"), "Capture time unavailable"))#</div>
                <div class="fpw-monitoring-muted small mt-1">Received: #encodeForHTML(fpwMonitoringText(fpwMonitoringGet(monitoringLocation, "receivedAtLocalLabel"), "unavailable"))#</div>
              </div>
              <div class="fpw-monitoring-data-grid mb-3">
                <div class="fpw-monitoring-tile">
                  <div class="fpw-monitoring-muted small">Latitude</div>
                  <strong>#encodeForHTML(fpwMonitoringCoordinate(fpwMonitoringGet(monitoringLocation, "latitude")))#</strong>
                </div>
                <div class="fpw-monitoring-tile">
                  <div class="fpw-monitoring-muted small">Longitude</div>
                  <strong>#encodeForHTML(fpwMonitoringCoordinate(fpwMonitoringGet(monitoringLocation, "longitude")))#</strong>
                </div>
                <div class="fpw-monitoring-tile">
                  <div class="fpw-monitoring-muted small">Accuracy</div>
                  <strong>#encodeForHTML(fpwMonitoringText(fpwMonitoringGet(monitoringLocation, "accuracyLabel"), "Unavailable"))#</strong>
                </div>
                <div class="fpw-monitoring-tile">
                  <div class="fpw-monitoring-muted small">Source</div>
                  <strong>#encodeForHTML(fpwMonitoringText(fpwMonitoringGet(monitoringLocation, "sourceLabel"), "Unavailable"))#</strong>
                </div>
                <div class="fpw-monitoring-tile">
                  <div class="fpw-monitoring-muted small">Quality</div>
                  <strong>#encodeForHTML(fpwMonitoringText(fpwMonitoringGet(monitoringLocation, "accuracyQualityLabel"), "Unknown"))#</strong>
                </div>
                <div class="fpw-monitoring-tile">
                  <div class="fpw-monitoring-muted small">Age</div>
                  <strong>#encodeForHTML(fpwMonitoringText(fpwMonitoringGet(monitoringLocation, "ageLabel"), "Unavailable"))#</strong>
                </div>
              </div>
              <cfif fpwMonitoringBool(fpwMonitoringGet(monitoringLocation, "isStale", false))>
                <div class="fpw-monitoring-note mb-3">#encodeForHTML(fpwMonitoringText(fpwMonitoringGet(monitoringLocation, "staleReason"), "The latest GPS check-in may be stale."))#</div>
              </cfif>
            <cfelse>
              <div class="fpw-monitoring-note mb-3">#encodeForHTML(fpwMonitoringText(fpwMonitoringGet(monitoringSafety, "noGpsMessage"), "No GPS has been captured with a check-in for this monitored trip yet."))#</div>
            </cfif>
            <div class="fpw-monitoring-note">
              #encodeForHTML(fpwMonitoringText(fpwMonitoringGet(monitoringSafety, "notLiveTrackingMessage"), "FPW shows the last check-in location shared by the captain."))#
            </div>
          </section>

          <section class="fpw-monitoring-panel p-3 p-lg-4">
            <h2 class="h5 mb-3">Alert Readiness</h2>
            <div class="d-grid gap-2 small">
              <div class="fpw-monitoring-tile d-flex justify-content-between gap-3">
                <span class="fpw-monitoring-muted">Expected check-in</span>
                <strong>#encodeForHTML(fpwMonitoringText(fpwMonitoringGet(monitoringState, "expectedCheckinLocalLabel"), "--"))#</strong>
              </div>
              <div class="fpw-monitoring-tile d-flex justify-content-between gap-3">
                <span class="fpw-monitoring-muted">Grace until</span>
                <strong>#encodeForHTML(fpwMonitoringText(fpwMonitoringGet(monitoringState, "graceUntilLocalLabel"), "--"))#</strong>
              </div>
              <div class="fpw-monitoring-tile d-flex justify-content-between gap-3">
                <span class="fpw-monitoring-muted">Missed at</span>
                <strong>#encodeForHTML(fpwMonitoringText(fpwMonitoringGet(monitoringState, "missedAtLocalLabel"), "--"))#</strong>
              </div>
              <div class="fpw-monitoring-tile d-flex justify-content-between gap-3">
                <span class="fpw-monitoring-muted">Escalated at</span>
                <strong>#encodeForHTML(fpwMonitoringText(fpwMonitoringGet(monitoringState, "escalatedAtLocalLabel"), "--"))#</strong>
              </div>
              <div class="fpw-monitoring-tile d-flex justify-content-between gap-3">
                <span class="fpw-monitoring-muted">Next monitor eval</span>
                <strong>#encodeForHTML(fpwMonitoringText(fpwMonitoringGet(monitoringState, "nextMonitorEvalLocalLabel"), "--"))#</strong>
              </div>
            </div>
          </section>
        </div>
      </div>
    </section>

    <section class="row g-4 mb-4">
      <div class="col-xl-6">
        <section class="fpw-monitoring-panel p-3 p-lg-4 h-100">
          <div class="d-flex justify-content-between gap-3 mb-3">
            <div>
              <h2 class="h5 mb-1">Monitoring Audit</h2>
              <p class="fpw-monitoring-muted small mb-0">A plain-English view of what FPW processed behind the scenes.</p>
            </div>
            <span class="fpw-monitoring-pill fpw-monitoring-pill--muted align-self-start">Captain Only</span>
          </div>

          <cfif arrayLen(monitoringAuditItems)>
            <div class="fpw-monitoring-audit-list">
              <cfloop array="#monitoringAuditItems#" index="auditItem">
                <cfset auditStruct = fpwMonitoringStruct(auditItem)>
                <cfset auditTone = fpwMonitoringText(fpwMonitoringGet(auditStruct, "tone"), "info")>
                <cfset auditType = fpwMonitoringText(fpwMonitoringGet(auditStruct, "type"), "")>
                <cfset auditDetail = fpwMonitoringText(fpwMonitoringGet(auditStruct, "detail"), "")>
                <cfif find("ALERT", uCase(auditType))>
                  <cfset auditDetail = "An alert-related monitoring event was recorded.">
                </cfif>
                <cfset auditCompanionId = fpwMonitoringGet(auditStruct, "relatedCompanionEventId", 0)>
                <cfset auditCanonicalId = fpwMonitoringGet(auditStruct, "relatedCanonicalEventId", 0)>
                <cfset auditMonitorId = fpwMonitoringGet(auditStruct, "relatedMonitorEventId", 0)>
                <cfset auditHasRefs = (fpwMonitoringPositiveId(auditCompanionId) OR fpwMonitoringPositiveId(auditCanonicalId) OR fpwMonitoringPositiveId(auditMonitorId))>
                <article class="fpw-monitoring-audit-card #encodeForHTMLAttribute(fpwMonitoringToneClass(auditTone))#">
                  <div class="fpw-monitoring-audit-head">
                    <div>
                      <div class="fpw-monitoring-audit-title">#encodeForHTML(fpwMonitoringText(fpwMonitoringGet(auditStruct, "title"), "Monitoring audit item"))#</div>
                      <div class="small fpw-monitoring-muted mt-1">#encodeForHTML(auditDetail)#</div>
                    </div>
                    <div class="fpw-monitoring-audit-time">#encodeForHTML(fpwMonitoringText(fpwMonitoringGet(auditStruct, "occurredAtLocalLabel"), "--"))#</div>
                  </div>
                  <div class="fpw-monitoring-meta-row">
                    <span class="fpw-monitoring-mini-pill">#encodeForHTML(fpwMonitoringAuditKindLabel(auditType))#</span>
                    <span class="fpw-monitoring-mini-pill">#encodeForHTML(fpwMonitoringToneLabel(auditTone))#</span>
                    <cfif len(fpwMonitoringSourceLabel(fpwMonitoringGet(auditStruct, "source", "")))>
                      <span class="fpw-monitoring-mini-pill">#encodeForHTML(fpwMonitoringSourceLabel(fpwMonitoringGet(auditStruct, "source", "")))#</span>
                    </cfif>
                  </div>
                  <cfif auditHasRefs>
                    <details class="fpw-monitoring-row-details">
                      <summary>Technical reference</summary>
                      <div class="fpw-monitoring-ref-list mt-2">
                        <cfif fpwMonitoringPositiveId(auditCompanionId)>
                          <span class="fpw-monitoring-mini-pill">Companion event ###encodeForHTML(fpwMonitoringText(auditCompanionId, "0"))#</span>
                        </cfif>
                        <cfif fpwMonitoringPositiveId(auditCanonicalId)>
                          <span class="fpw-monitoring-mini-pill">Canonical event ###encodeForHTML(fpwMonitoringText(auditCanonicalId, "0"))#</span>
                        </cfif>
                        <cfif fpwMonitoringPositiveId(auditMonitorId)>
                          <span class="fpw-monitoring-mini-pill">Monitoring event ###encodeForHTML(fpwMonitoringText(auditMonitorId, "0"))#</span>
                        </cfif>
                      </div>
                    </details>
                  </cfif>
                </article>
              </cfloop>
            </div>
          <cfelse>
            <div class="fpw-monitoring-note">No monitoring audit entries are available yet for this trip.</div>
          </cfif>
        </section>
      </div>

      <div class="col-xl-6">
        <section class="fpw-monitoring-panel p-3 p-lg-4 h-100">
          <h2 class="h5 mb-3">GPS Capture History</h2>
          <cfif arrayLen(monitoringGpsHistory)>
            <div class="fpw-monitoring-history-list mb-4">
              <cfloop array="#monitoringGpsHistory#" index="gpsRow">
                <cfset gpsStruct = fpwMonitoringStruct(gpsRow)>
                <cfset gpsHasGps = fpwMonitoringBool(fpwMonitoringGet(gpsStruct, "hasGps", false))>
                <cfset gpsTone = fpwMonitoringText(fpwMonitoringGet(gpsStruct, "rowTone"), (gpsHasGps ? "neutral" : "muted"))>
                <cfset gpsCompanionId = fpwMonitoringGet(gpsStruct, "companionEventId", 0)>
                <cfset gpsCanonicalId = fpwMonitoringGet(gpsStruct, "canonicalEventId", 0)>
                <cfset gpsHasRefs = (fpwMonitoringPositiveId(gpsCompanionId) OR fpwMonitoringPositiveId(gpsCanonicalId))>
                <article class="fpw-monitoring-history-card #encodeForHTMLAttribute(fpwMonitoringToneClass(gpsTone))#">
                  <div class="fpw-monitoring-history-head">
                    <div>
                      <div class="fpw-monitoring-history-title">#encodeForHTML(fpwMonitoringText(fpwMonitoringGet(gpsStruct, "statusLabel"), "Check-in"))#</div>
                      <div class="fpw-monitoring-muted small mt-1">#encodeForHTML(fpwMonitoringText(fpwMonitoringGet(gpsStruct, "sourceLabel"), fpwMonitoringText(fpwMonitoringGet(gpsStruct, "sourceCode"), "Check-in source unavailable")))#</div>
                    </div>
                    <div class="fpw-monitoring-history-time">#encodeForHTML(fpwMonitoringText(fpwMonitoringGet(gpsStruct, "checkinLocalLabel"), "--"))#</div>
                  </div>
                  <div class="fpw-monitoring-meta-row">
                    <span class="fpw-monitoring-pill #encodeForHTMLAttribute(gpsHasGps ? "fpw-monitoring-pill--success" : "fpw-monitoring-pill--muted")#">#encodeForHTML(gpsHasGps ? "GPS captured" : "No GPS with this check-in")#</span>
                    <span class="fpw-monitoring-mini-pill">#encodeForHTML(fpwMonitoringText(fpwMonitoringGet(gpsStruct, "gpsQualityLabel"), "Quality unknown"))#</span>
                  </div>
                  <div class="fpw-monitoring-history-grid">
                    <div class="fpw-monitoring-history-field">
                      <div class="fpw-monitoring-muted small">Accuracy</div>
                      <strong>#encodeForHTML(fpwMonitoringText(fpwMonitoringGet(gpsStruct, "accuracyLabel"), "--"))#</strong>
                    </div>
                    <div class="fpw-monitoring-history-field">
                      <div class="fpw-monitoring-muted small">Captured</div>
                      <strong>#encodeForHTML(fpwMonitoringText(fpwMonitoringGet(gpsStruct, "capturedAtLocalLabel"), "--"))#</strong>
                    </div>
                    <div class="fpw-monitoring-history-field">
                      <div class="fpw-monitoring-muted small">Received</div>
                      <strong>#encodeForHTML(fpwMonitoringText(fpwMonitoringGet(gpsStruct, "receivedAtLocalLabel"), "--"))#</strong>
                    </div>
                    <div class="fpw-monitoring-history-field">
                      <div class="fpw-monitoring-muted small">Event source</div>
                      <strong>#encodeForHTML(fpwMonitoringText(fpwMonitoringGet(gpsStruct, "sourceLabel"), "--"))#</strong>
                    </div>
                  </div>
                  <cfif len(fpwMonitoringText(fpwMonitoringGet(gpsStruct, "notePreview"), ""))>
                    <div class="small fpw-monitoring-muted">#encodeForHTML(fpwMonitoringText(fpwMonitoringGet(gpsStruct, "notePreview"), ""))#</div>
                  </cfif>
                  <cfif gpsHasRefs>
                    <details class="fpw-monitoring-row-details">
                      <summary>Technical reference</summary>
                      <div class="fpw-monitoring-ref-list mt-2">
                        <cfif fpwMonitoringPositiveId(gpsCompanionId)>
                          <span class="fpw-monitoring-mini-pill">Companion event ###encodeForHTML(fpwMonitoringText(gpsCompanionId, "0"))#</span>
                        </cfif>
                        <cfif fpwMonitoringPositiveId(gpsCanonicalId)>
                          <span class="fpw-monitoring-mini-pill">Canonical event ###encodeForHTML(fpwMonitoringText(gpsCanonicalId, "0"))#</span>
                        </cfif>
                      </div>
                    </details>
                  </cfif>
                </article>
              </cfloop>
            </div>
          <cfelse>
            <div class="fpw-monitoring-note mb-4">
              No check-in history is available yet.
              <cfif NOT monitoringHasLocation>
                <span class="d-block mt-2">#encodeForHTML(fpwMonitoringText(fpwMonitoringGet(monitoringSafety, "noGpsMessage"), "No GPS has been captured with a check-in for this monitored trip yet."))#</span>
              </cfif>
            </div>
          </cfif>

          <div class="fpw-monitoring-soft p-3">
            <details class="fpw-monitoring-details">
              <summary>Technical Audit Snapshot</summary>
              <div class="row g-2 small mt-3">
                <div class="col-sm-6 d-flex justify-content-between gap-3"><span class="fpw-monitoring-muted">Monitoring row</span><strong>#encodeForHTML(fpwMonitoringText(fpwMonitoringGet(monitoringTechnical, "monitoringRowId"), "0"))#</strong></div>
                <div class="col-sm-6 d-flex justify-content-between gap-3"><span class="fpw-monitoring-muted">Monitoring state</span><strong>#encodeForHTML(fpwMonitoringText(fpwMonitoringGet(monitoringTechnical, "monitoringState"), "--"))#</strong></div>
                <div class="col-sm-6 d-flex justify-content-between gap-3"><span class="fpw-monitoring-muted">Monitoring mode</span><strong>#encodeForHTML(fpwMonitoringText(fpwMonitoringGet(monitoringTechnical, "monitoringMode"), "--"))#</strong></div>
                <div class="col-sm-6 d-flex justify-content-between gap-3"><span class="fpw-monitoring-muted">Companion event</span><strong>#encodeForHTML(fpwMonitoringText(fpwMonitoringGet(monitoringTechnical, "companionEventId"), "0"))#</strong></div>
                <div class="col-sm-6 d-flex justify-content-between gap-3"><span class="fpw-monitoring-muted">Canonical event</span><strong>#encodeForHTML(fpwMonitoringText(fpwMonitoringGet(monitoringTechnical, "canonicalEventId"), "0"))#</strong></div>
                <div class="col-sm-6 d-flex justify-content-between gap-3"><span class="fpw-monitoring-muted">Processed status</span><strong>#encodeForHTML(fpwMonitoringText(fpwMonitoringGet(monitoringTechnical, "processedStatus"), "--"))#</strong></div>
                <div class="col-sm-6 d-flex justify-content-between gap-3"><span class="fpw-monitoring-muted">Duplicate replay</span><strong>#encodeForHTML(fpwMonitoringBool(fpwMonitoringGet(monitoringTechnical, "duplicateReplay", false)) ? "true" : "false")#</strong></div>
                <div class="col-sm-6 d-flex justify-content-between gap-3"><span class="fpw-monitoring-muted">Location captured UTC</span><strong>#encodeForHTML(fpwMonitoringText(fpwMonitoringGet(monitoringTechnical, "locationCapturedAtUtc"), "--"))#</strong></div>
                <div class="col-sm-6 d-flex justify-content-between gap-3"><span class="fpw-monitoring-muted">Expected check-in UTC</span><strong>#encodeForHTML(fpwMonitoringText(fpwMonitoringGet(monitoringTechnical, "expectedCheckinAtUtc"), "--"))#</strong></div>
                <div class="col-sm-6 d-flex justify-content-between gap-3"><span class="fpw-monitoring-muted">Next eval UTC</span><strong>#encodeForHTML(fpwMonitoringText(fpwMonitoringGet(monitoringTechnical, "nextMonitorEvalAtUtc"), "--"))#</strong></div>
                <div class="col-sm-6 d-flex justify-content-between gap-3"><span class="fpw-monitoring-muted">Generated UTC</span><strong>#encodeForHTML(fpwMonitoringText(fpwMonitoringGet(monitoringTechnical, "generatedAtUtc"), "--"))#</strong></div>
              </div>
            </details>
          </div>
        </section>
      </div>
    </section>

    <section class="fpw-monitoring-panel p-3 p-lg-4">
      <div class="fpw-monitoring-note mb-3">
        #encodeForHTML(fpwMonitoringText(fpwMonitoringGet(monitoringSafety, "emergencyDisclaimer"), "This is not live vessel tracking and may not reflect the vessel's current position."))#
      </div>
      <cfif len(fpwMonitoringText(fpwMonitoringGet(monitoringSafety, "gpsStaleMessage"), ""))>
        <div class="fpw-monitoring-note mb-3">#encodeForHTML(fpwMonitoringText(fpwMonitoringGet(monitoringSafety, "gpsStaleMessage"), ""))#</div>
      </cfif>
      <cfif len(fpwMonitoringText(fpwMonitoringGet(monitoringSafety, "poorAccuracyMessage"), ""))>
        <div class="fpw-monitoring-note">#encodeForHTML(fpwMonitoringText(fpwMonitoringGet(monitoringSafety, "poorAccuracyMessage"), ""))#</div>
      </cfif>
    </section>
  </cfif>
  </cfoutput>
</main>
<cfinclude template="../includes/footer.cfm">
<cfinclude template="../includes/footer_scripts.cfm">
<cfif monitoringShowConsole AND monitoringMapCanRender>
  <cfoutput>
  <script id="fpwMonitoringMapPayload" type="application/json">#fpwMonitoringJsonForScript(monitoringMap)#</script>
  <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js" integrity="sha256-20nQCchB9co0qIjJZRGuk2/Z9VM+kNiyxNV1lvTlZBo=" crossorigin=""></script>
  </cfoutput>
  <script>
    (function() {
      'use strict';

      var mapEl = document.getElementById('fpwMonitoringMap');
      var payloadEl = document.getElementById('fpwMonitoringMapPayload');
      var statusEl = document.getElementById('fpwMonitoringMapStatus');
      var routeStyle = { color: '#38bdf8', weight: 4, opacity: 0.92, lineJoin: 'round', lineCap: 'round' };
      var accuracyStyle = { color: '#10b981', weight: 2, opacity: 0.75, fillColor: '#10b981', fillOpacity: 0.14 };

      function setMapStatus(message, visible) {
        var label = statusEl ? statusEl.querySelector('span') : null;
        if (!statusEl || !label) {
          return;
        }
        label.textContent = message;
        statusEl.classList.toggle('is-visible', visible === true);
      }

      function safeNumber(value) {
        var numberValue = parseFloat(value);
        return Number.isFinite(numberValue) ? numberValue : null;
      }

      function escapeHtml(value) {
        return String(value || '').replace(/[&<>'"]/g, function(char) {
          return {
            '&': '&amp;',
            '<': '&lt;',
            '>': '&gt;',
            "'": '&#39;',
            '"': '&quot;'
          }[char];
        });
      }

      function normalizePoint(raw) {
        if (!raw || typeof raw !== 'object') {
          return null;
        }
        var lat = safeNumber(raw.lat !== undefined ? raw.lat : raw.latitude);
        var lng = safeNumber(raw.lng !== undefined ? raw.lng : (raw.lon !== undefined ? raw.lon : raw.longitude));
        if (lat === null || lng === null) {
          return null;
        }
        return {
          lat: lat,
          lng: lng,
          label: String(raw.label || raw.name || '').trim(),
          type: String(raw.type || '').trim()
        };
      }

      function normalizeSegmentCoordinates(rawSegment) {
        var coords = [];
        var i;
        var pt;
        var point;

        if (!Array.isArray(rawSegment)) {
          return coords;
        }
        for (i = 0; i < rawSegment.length; i += 1) {
          pt = rawSegment[i];
          if (Array.isArray(pt) && pt.length >= 2) {
            point = { lat: safeNumber(pt[1]), lng: safeNumber(pt[0]) };
          } else {
            point = normalizePoint(pt);
          }
          if (point && point.lat !== null && point.lng !== null) {
            coords.push([point.lat, point.lng]);
          }
        }
        return coords.length >= 2 ? coords : [];
      }

      function collectRouteLatLngs(routeGeo) {
        var points = [];
        var coordinates;
        var segment;
        var i;
        var j;

        if (!routeGeo || !Array.isArray(routeGeo.coordinates)) {
          return points;
        }
        coordinates = routeGeo.coordinates;
        if (routeGeo.type === 'LineString') {
          segment = normalizeSegmentCoordinates(coordinates);
          return segment;
        }
        for (i = 0; i < coordinates.length; i += 1) {
          segment = normalizeSegmentCoordinates(coordinates[i]);
          for (j = 0; j < segment.length; j += 1) {
            points.push(segment[j]);
          }
        }
        return points;
      }

      function hasRouteCoordinates(routeGeo) {
        return collectRouteLatLngs(routeGeo).length > 1;
      }

      function makePinIcon(type) {
        var pinType = String(type || 'intermediate').toLowerCase();
        if (pinType !== 'start' && pinType !== 'end' && pinType !== 'leg_end') {
          pinType = 'intermediate';
        }
        return window.L.divIcon({
          className: 'fpw-monitoring-marker-icon',
          html: '<span class="fpw-monitoring-pin ' + pinType + '"></span>',
          iconSize: [17, 17],
          iconAnchor: [8.5, 8.5]
        });
      }

      function makeLastCheckinIcon() {
        return window.L.divIcon({
          className: 'fpw-monitoring-marker-icon',
          html: '<span class="fpw-monitoring-last-marker"></span>',
          iconSize: [20, 20],
          iconAnchor: [10, 10]
        });
      }

      function readPayload() {
        if (!payloadEl) {
          return {};
        }
        try {
          return JSON.parse(payloadEl.textContent || '{}');
        } catch (error) {
          return {};
        }
      }

      function renderPins(map, pins, boundsPoints) {
        var list = Array.isArray(pins) ? pins : [];
        var layer = window.L.layerGroup().addTo(map);
        var i;
        var pin;
        var label;

        for (i = 0; i < list.length; i += 1) {
          pin = normalizePoint(list[i]);
          if (!pin) {
            continue;
          }
          label = pin.label || 'Route point';
          if (safeNumber(list[i].sequence) !== null) {
            label += ' (#' + String(Math.round(safeNumber(list[i].sequence))) + ')';
          }
          window.L.marker([pin.lat, pin.lng], { icon: makePinIcon(pin.type) })
            .addTo(layer)
            .bindTooltip(escapeHtml(label), { direction: 'top', opacity: 0.92 });
          boundsPoints.push([pin.lat, pin.lng]);
        }
      }

      function renderLastCheckin(map, model, boundsPoints) {
        var markerPoint = normalizePoint(model.lastCheckinMarker);
        var accuracy = model.accuracyCircle || {};
        var radius = safeNumber(accuracy.radiusMeters);
        var labelParts;
        var popupHtml;

        if (!markerPoint) {
          return;
        }
        labelParts = [
          escapeHtml(model.lastCheckinMarker.label || 'Last Check-In Location'),
          escapeHtml(model.lastCheckinMarker.statusLabel || 'Check-in'),
          escapeHtml(model.lastCheckinMarker.capturedAtLocalLabel || 'Capture time unavailable'),
          escapeHtml(model.lastCheckinMarker.sourceLabel || 'GPS captured with check-in')
        ];
        popupHtml = '<strong>' + labelParts[0] + '</strong><br>' +
          labelParts[1] + '<br>' +
          'Captured: ' + labelParts[2] + '<br>' +
          'Source: ' + labelParts[3] + '<br>' +
          '<span>Not live vessel tracking.</span>';

        window.L.marker([markerPoint.lat, markerPoint.lng], { icon: makeLastCheckinIcon() })
          .addTo(map)
          .bindTooltip('Last Check-In Location', { direction: 'top', opacity: 0.94 })
          .bindPopup(popupHtml);
        boundsPoints.push([markerPoint.lat, markerPoint.lng]);

        if (radius !== null && radius > 0) {
          window.L.circle([markerPoint.lat, markerPoint.lng], Object.assign({ radius: radius }, accuracyStyle)).addTo(map);
        }
      }

      function fitMap(map, points, fallbackCenter) {
        var center = normalizePoint(fallbackCenter);
        if (points.length > 1) {
          map.fitBounds(window.L.latLngBounds(points), { padding: [28, 28], maxZoom: 12 });
          return;
        }
        if (points.length === 1) {
          map.setView(points[0], 12);
          return;
        }
        if (center) {
          map.setView([center.lat, center.lng], 12);
          return;
        }
        map.setView([39.5, -95.5], 4);
      }

      function renderMap() {
        var model = readPayload();
        var routeGeo = model.routeGeo || {};
        var boundsPoints = [];
        var map;
        var routePoints;

        if (!mapEl || !payloadEl) {
          return;
        }
        if (!window.L || typeof window.L.map !== 'function') {
          setMapStatus('Leaflet map renderer is not available.', true);
          return;
        }

        map = window.L.map(mapEl, {
          zoomControl: true,
          preferCanvas: true,
          scrollWheelZoom: false
        }).setView([39.5, -95.5], 4);
        window.L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
          maxZoom: 18,
          attribution: '&copy; OpenStreetMap'
        }).addTo(map);

        if (hasRouteCoordinates(routeGeo)) {
          window.L.geoJSON(routeGeo, { style: routeStyle }).addTo(map);
          routePoints = collectRouteLatLngs(routeGeo);
          boundsPoints = boundsPoints.concat(routePoints);
        }

        renderPins(map, model.pins, boundsPoints);
        renderLastCheckin(map, model, boundsPoints);

        if (!boundsPoints.length) {
          setMapStatus(model.noMapReason || 'No route geometry or GPS check-in location is available for the map yet.', true);
        } else {
          fitMap(map, boundsPoints, model.mapCenter);
          setMapStatus('Monitoring Console map loaded.', false);
          mapEl.setAttribute('data-fpw-monitoring-map-rendered', 'true');
          mapEl.setAttribute('data-fpw-monitoring-map-has-route', hasRouteCoordinates(routeGeo) ? 'true' : 'false');
          mapEl.setAttribute('data-fpw-monitoring-map-has-location', normalizePoint(model.lastCheckinMarker) ? 'true' : 'false');
          window.setTimeout(function() {
            map.invalidateSize();
            fitMap(map, boundsPoints, model.mapCenter);
          }, 100);
        }
      }

      renderMap();
    })();
  </script>
</cfif>
</body>
</html>
