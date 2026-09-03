<cfprocessingdirective pageencoding="utf-8">
<cfinclude template="../includes/require_auth.cfm">
<cfscript>
completedTripUserId = fpwRequireAuthUserId;
completedTripId = 0;
completedTripDsn = "fpw";
completedTripService = "";
completedTripModel = {
  SUCCESS = false,
  found = false,
  errorCode = "INVALID_ARGUMENTS",
  message = "A valid completed trip is required.",
  statusCode = 400,
  warnings = []
};

if (structKeyExists(application, "dsn") AND len(trim(toString(application.dsn)))) {
  completedTripDsn = trim(toString(application.dsn));
}

if (structKeyExists(url, "id") AND isNumeric(url.id)) {
  completedTripId = val(url.id);
} else if (structKeyExists(url, "floatPlanId") AND isNumeric(url.floatPlanId)) {
  completedTripId = val(url.floatPlanId);
}

function ctLoadCompletedTripService(required string datasource) {
  try {
    return createObject("component", "fpw.api.v1.CompletedTripViewModelService").init(arguments.datasource);
  } catch (any completedTripPathErr) {
    return createObject("component", "api.v1.CompletedTripViewModelService").init(arguments.datasource);
  }
}

function ctGet(required struct source, required string key, any defaultValue = "") {
  if (structKeyExists(arguments.source, arguments.key) AND !isNull(arguments.source[arguments.key])) {
    return arguments.source[arguments.key];
  }
  return arguments.defaultValue;
}

function ctText(any value = "", string fallback = "--") {
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

function ctHtml(any value = "", string fallback = "--") {
  return encodeForHTML(ctText(arguments.value, arguments.fallback));
}

function ctAttr(any value = "", string fallback = "--") {
  return encodeForHTMLAttribute(ctText(arguments.value, arguments.fallback));
}

function ctBoolLabel(any value = false) {
  if (isBoolean(arguments.value) AND arguments.value) {
    return "Yes";
  }
  if (isNumeric(arguments.value) AND val(arguments.value) NEQ 0) {
    return "Yes";
  }
  return "No";
}

function ctCountLabel(any value = 0, string singular = "item", string plural = "items") {
  var countValue = isNumeric(arguments.value) ? val(arguments.value) : 0;
  return numberFormat(countValue, "0") & " " & (countValue EQ 1 ? arguments.singular : arguments.plural);
}

function ctStatusClass(any value = "") {
  var statusValue = uCase(ctText(arguments.value, ""));
  if (statusValue EQ "COMPLETED" OR statusValue EQ "CLOSED") {
    return "is-complete";
  }
  if (!len(statusValue) OR statusValue EQ "NOT AVAILABLE") {
    return "is-muted";
  }
  return "is-info";
}

if (completedTripId GT 0 AND completedTripUserId GT 0) {
  try {
    completedTripService = ctLoadCompletedTripService(completedTripDsn);
    completedTripModel = completedTripService.getCompletedTripViewModel(
      userId = completedTripUserId,
      floatPlanId = completedTripId
    );
    if (
      isStruct(completedTripModel)
      AND structKeyExists(completedTripModel, "SUCCESS")
      AND completedTripModel.SUCCESS
      AND isObject(completedTripService)
    ) {
      completedTripModel.completedTripUrl = completedTripService.buildCompletedTripUrl(completedTripId, request.fpwBase);
    }
  } catch (any completedTripLoadErr) {
    completedTripModel = {
      SUCCESS = false,
      found = false,
      errorCode = "SERVER_ERROR",
      message = "Completed trip is not available.",
      statusCode = 500,
      warnings = []
    };
  }
}

completedTripStatusCode = 200;
completedTripStatusText = "OK";
if (!completedTripModel.SUCCESS) {
  completedTripStatusCode = (
    structKeyExists(completedTripModel, "statusCode")
    AND isNumeric(completedTripModel.statusCode)
    AND val(completedTripModel.statusCode) GTE 400
  ) ? val(completedTripModel.statusCode) : 404;
  completedTripStatusText = completedTripStatusCode EQ 400 ? "Bad Request" : (completedTripStatusCode EQ 500 ? "Server Error" : "Not Found");
}

completedTripPageTitle = completedTripModel.SUCCESS
  ? "Completed Trip - " & ctText(ctGet(completedTripModel.trip, "name"), "FloatPlanWizard")
  : "Completed Trip Unavailable";
</cfscript>
<cfif completedTripStatusCode GTE 400>
  <cfheader statuscode="#completedTripStatusCode#">
</cfif>
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title><cfoutput>#encodeForHTML(completedTripPageTitle)#</cfoutput> | FloatPlanWizard</title>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="robots" content="noindex,nofollow">
  <cfinclude template="../includes/header_styles.cfm">
  <style>
    :root {
      --ct-bg: #04101b;
      --ct-panel: rgba(8, 23, 39, 0.92);
      --ct-panel-strong: rgba(11, 32, 52, 0.96);
      --ct-line: rgba(118, 198, 221, 0.24);
      --ct-line-strong: rgba(118, 198, 221, 0.42);
      --ct-text: #f3f8fb;
      --ct-muted: #9fb2c3;
      --ct-soft: #c9d9e7;
      --ct-teal: #39ded7;
      --ct-blue: #5fa8ff;
      --ct-radius: 18px;
      --ct-max: var(--fpw-wide-max, 1320px);
    }

    .completed-trip-body {
      background:
        radial-gradient(circle at 14% 3%, rgba(55, 222, 215, 0.14), transparent 28rem),
        radial-gradient(circle at 86% 6%, rgba(74, 148, 255, 0.1), transparent 30rem),
        linear-gradient(180deg, #071a2b 0%, #030b13 48%, #020810 100%);
      color: var(--ct-text);
    }

    .completed-trip-main {
      min-height: calc(100vh - 82px);
      padding: 28px 0 52px;
    }

    .fpw-completed-trip {
      width: min(var(--ct-max), calc(100% - (var(--fpw-page-gutter, 32px) * 2)));
      margin: 0 auto;
    }

    .fpw-completed-trip *,
    .fpw-completed-trip *::before,
    .fpw-completed-trip *::after {
      box-sizing: border-box;
    }

    .fpw-completed-trip h1,
    .fpw-completed-trip h2,
    .fpw-completed-trip h3,
    .fpw-completed-trip p,
    .fpw-completed-trip dl,
    .fpw-completed-trip dd {
      margin: 0;
    }

    .fpw-completed-trip a {
      color: inherit;
    }

    .ct-hero,
    .ct-card,
    .ct-empty-state {
      border: 1px solid var(--ct-line);
      border-radius: var(--ct-radius);
      background:
        linear-gradient(135deg, rgba(13, 42, 66, 0.88), rgba(5, 15, 26, 0.94)),
        linear-gradient(90deg, rgba(58, 222, 215, 0.08), transparent);
      box-shadow: 0 18px 50px rgba(0, 0, 0, 0.25);
      overflow: hidden;
    }

    .ct-hero {
      position: relative;
      display: grid;
      grid-template-columns: minmax(0, 1fr) auto;
      gap: 22px;
      align-items: end;
      padding: clamp(24px, 4vw, 44px);
      margin-bottom: 18px;
    }

    .ct-hero::before {
      content: "";
      position: absolute;
      inset: 0;
      opacity: 0.28;
      pointer-events: none;
      background-image:
        radial-gradient(circle at 18% 32%, rgba(57, 222, 215, 0.16), transparent 18rem),
        linear-gradient(rgba(117, 200, 222, 0.05) 1px, transparent 1px),
        linear-gradient(90deg, rgba(117, 200, 222, 0.04) 1px, transparent 1px);
      background-size: auto, 64px 64px, 64px 64px;
      mask-image: linear-gradient(90deg, black, transparent 92%);
    }

    .ct-hero > * {
      position: relative;
      z-index: 1;
    }

    .ct-kicker {
      display: flex;
      align-items: center;
      gap: 10px;
      margin-bottom: 12px;
      color: var(--ct-teal);
      font-size: 0.78rem;
      font-weight: 850;
      letter-spacing: 0.16em;
      text-transform: uppercase;
    }

    .ct-kicker::before {
      content: "";
      width: 10px;
      height: 10px;
      border-radius: 50%;
      background: var(--ct-teal);
      box-shadow: 0 0 18px rgba(57, 222, 215, 0.72);
    }

    .ct-hero h1 {
      max-width: 880px;
      color: #fff;
      font-size: clamp(2.1rem, 5vw, 4rem);
      line-height: 1;
      letter-spacing: 0;
      font-weight: 850;
    }

    .ct-hero__meta {
      display: flex;
      flex-wrap: wrap;
      gap: 10px;
      margin-top: 18px;
      color: var(--ct-soft);
      font-weight: 700;
    }

    .ct-pill {
      display: inline-flex;
      align-items: center;
      gap: 8px;
      min-height: 32px;
      border: 1px solid var(--ct-line-strong);
      border-radius: 999px;
      padding: 6px 12px;
      color: var(--ct-soft);
      background: rgba(255, 255, 255, 0.05);
      font-size: 0.88rem;
    }

    .ct-pill.is-complete {
      color: #081a20;
      border-color: rgba(95, 255, 228, 0.8);
      background: linear-gradient(135deg, #6cf5e8, #3ec9cf);
      box-shadow: 0 0 24px rgba(57, 222, 215, 0.22);
    }

    .ct-pill.is-muted {
      color: var(--ct-muted);
    }

    .ct-hero__actions {
      display: flex;
      justify-content: flex-end;
      align-items: center;
    }

    .ct-link-button {
      display: inline-flex;
      align-items: center;
      justify-content: center;
      min-height: 44px;
      border: 1px solid rgba(57, 222, 215, 0.58);
      border-radius: 999px;
      padding: 0 18px;
      color: #eaffff;
      background: rgba(7, 27, 43, 0.72);
      font-weight: 800;
      text-decoration: none;
      white-space: nowrap;
      box-shadow: 0 0 20px rgba(57, 222, 215, 0.12);
    }

    .ct-link-button:hover,
    .ct-link-button:focus-visible {
      color: #fff;
      border-color: #77fff7;
      text-decoration: none;
      box-shadow: 0 0 28px rgba(57, 222, 215, 0.26);
    }

    .ct-grid {
      display: grid;
      grid-template-columns: repeat(12, minmax(0, 1fr));
      gap: 18px;
    }

    .ct-card {
      padding: 22px;
    }

    .ct-card--half {
      grid-column: span 6;
    }

    .ct-card--third {
      grid-column: span 4;
    }

    .ct-card--full {
      grid-column: 1 / -1;
    }

    .ct-card h2 {
      display: flex;
      align-items: center;
      gap: 10px;
      color: #fff;
      font-size: 1rem;
      font-weight: 850;
      letter-spacing: 0.08em;
      text-transform: uppercase;
      margin-bottom: 18px;
    }

    .ct-card h2::before {
      content: "";
      width: 18px;
      height: 2px;
      border-radius: 999px;
      background: var(--ct-teal);
      box-shadow: 0 0 16px rgba(57, 222, 215, 0.72);
    }

    .ct-field-list {
      display: grid;
      grid-template-columns: repeat(2, minmax(0, 1fr));
      gap: 14px;
    }

    .ct-field {
      min-width: 0;
      border: 1px solid rgba(118, 198, 221, 0.18);
      border-radius: 14px;
      padding: 14px;
      background: rgba(2, 10, 18, 0.28);
    }

    .ct-field dt {
      margin-bottom: 7px;
      color: var(--ct-muted);
      font-size: 0.76rem;
      font-weight: 850;
      letter-spacing: 0.08em;
      text-transform: uppercase;
    }

    .ct-field dd {
      color: #f9fcff;
      font-size: 1rem;
      font-weight: 750;
      line-height: 1.28;
      overflow-wrap: anywhere;
    }

    .ct-field p {
      margin-top: 8px;
      color: var(--ct-muted);
      font-size: 0.86rem;
      line-height: 1.45;
    }

    .ct-muted {
      color: var(--ct-muted);
    }

    .ct-inline-note {
      margin-top: 16px;
      padding: 12px 14px;
      border: 1px solid rgba(57, 222, 215, 0.24);
      border-radius: 12px;
      color: #bcd0dd;
      background: rgba(57, 222, 215, 0.06);
      font-size: 0.92rem;
      line-height: 1.45;
    }

    .ct-source-list {
      display: grid;
      gap: 10px;
      color: var(--ct-soft);
      line-height: 1.4;
    }

    .ct-source-list div {
      display: grid;
      grid-template-columns: 150px minmax(0, 1fr);
      gap: 12px;
      border-bottom: 1px solid rgba(118, 198, 221, 0.12);
      padding-bottom: 10px;
    }

    .ct-source-list div:last-child {
      border-bottom: 0;
      padding-bottom: 0;
    }

    .ct-source-list strong {
      color: #fff;
    }

    .ct-warning-list {
      display: grid;
      gap: 12px;
      padding: 0;
      margin: 0;
      list-style: none;
    }

    .ct-warning-list li {
      padding: 13px 14px;
      border: 1px solid rgba(255, 217, 102, 0.24);
      border-radius: 12px;
      background: rgba(255, 217, 102, 0.06);
      color: #f7e7b2;
      line-height: 1.45;
    }

    .ct-warning-list strong {
      display: block;
      margin-bottom: 4px;
      color: #fff4cc;
      font-size: 0.82rem;
      letter-spacing: 0.08em;
      text-transform: uppercase;
    }

    .ct-empty-state {
      max-width: 760px;
      margin: 0 auto;
      padding: clamp(24px, 5vw, 42px);
      text-align: center;
    }

    .ct-empty-state h1 {
      color: #fff;
      font-size: clamp(2rem, 4vw, 3rem);
      line-height: 1.04;
    }

    .ct-empty-state p {
      max-width: 560px;
      margin: 14px auto 0;
      color: var(--ct-soft);
      line-height: 1.55;
    }

    .ct-empty-state .ct-link-button {
      margin-top: 24px;
    }

    @media (max-width: 980px) {
      .ct-hero {
        grid-template-columns: 1fr;
        align-items: start;
      }

      .ct-hero__actions {
        justify-content: flex-start;
      }

      .ct-card--half,
      .ct-card--third {
        grid-column: 1 / -1;
      }
    }

    @media (max-width: 680px) {
      .completed-trip-main {
        padding-top: 18px;
      }

      .fpw-completed-trip {
        width: min(100% - 20px, var(--ct-max));
      }

      .ct-hero,
      .ct-card {
        border-radius: 14px;
        padding: 18px;
      }

      .ct-field-list {
        grid-template-columns: 1fr;
      }

      .ct-source-list div {
        grid-template-columns: 1fr;
        gap: 4px;
      }
    }
  </style>
</head>
<body class="dashboard-body completed-trip-body" data-fpw-page="completed-trip">

<cfset request.fpwTopNavActive = "dashboard">
<cfinclude template="../includes/top_nav.cfm">

<main class="dashboard-main completed-trip-main">
  <article class="fpw-completed-trip" aria-labelledby="completedTripTitle">
    <cfif completedTripModel.SUCCESS>
      <cfset completedTrip = completedTripModel.trip>
      <cfset completedTiming = completedTripModel.timing>
      <cfset completedRoute = completedTripModel.route>
      <cfset completedVessel = completedTripModel.vessel>
      <cfset completedShoreContact = completedTripModel.shoreContact>
      <cfset completedSummary = completedTripModel.completion>
      <cfset completedMonitoring = completedTripModel.monitoring>
      <cfset completedFollow = completedTripModel.follow>
      <cfset completedDataSources = completedTripModel.dataSources>

      <header class="ct-hero">
        <div>
          <p class="ct-kicker">Completed trip record</p>
          <h1 id="completedTripTitle"><cfoutput>#ctHtml(ctGet(completedTrip, "name"), "Completed Float Plan")#</cfoutput></h1>
          <div class="ct-hero__meta" aria-label="Completed trip summary">
            <span class="ct-pill is-complete">Completed</span>
            <span class="ct-pill"><cfoutput>#ctHtml(ctGet(completedSummary, "completedAtLocalLabel"), "Completion time unavailable")#</cfoutput></span>
            <span class="ct-pill"><cfoutput>#ctHtml(ctGet(completedTrip, "displayId"), "Float Plan")#</cfoutput></span>
          </div>
        </div>
        <div class="ct-hero__actions">
          <a class="ct-link-button" href="<cfoutput>#request.fpwBase#</cfoutput>/app/dashboard.cfm">Back to Dashboard</a>
        </div>
      </header>

      <div class="ct-grid">
        <section class="ct-card ct-card--half" aria-labelledby="completedTripIdentityTitle">
          <h2 id="completedTripIdentityTitle">Trip Identity</h2>
          <dl class="ct-field-list">
            <div class="ct-field">
              <dt>Vessel</dt>
              <dd><cfoutput>#ctHtml(ctGet(completedVessel, "name"), "Not available")#</cfoutput></dd>
              <p>Current associated vessel name only; not a historical vessel snapshot.</p>
            </div>
            <div class="ct-field">
              <dt>Trip Type</dt>
              <dd><cfoutput>#ctHtml(ctGet(completedTrip, "tripType"), "Not available")#</cfoutput></dd>
            </div>
            <div class="ct-field">
              <dt>Departure</dt>
              <dd><cfoutput>#ctHtml(ctGet(completedTrip, "departureLocation"), "Not available")#</cfoutput></dd>
            </div>
            <div class="ct-field">
              <dt>Destination</dt>
              <dd><cfoutput>#ctHtml(ctGet(completedTrip, "destination"), "Not available")#</cfoutput></dd>
            </div>
          </dl>
          <p class="ct-inline-note">This view is read-only and owner-restricted. It does not include edit, reopen, delete, route-reuse, or mutation controls.</p>
        </section>

        <section class="ct-card ct-card--half" aria-labelledby="completedTripTimingTitle">
          <h2 id="completedTripTimingTitle">Timing</h2>
          <dl class="ct-field-list">
            <div class="ct-field">
              <dt>Planned Departure</dt>
              <dd><cfoutput>#ctHtml(ctGet(ctGet(completedTiming, "plannedDeparture", {}), "localLabel"), "Not available")#</cfoutput></dd>
            </div>
            <div class="ct-field">
              <dt>Actual Departure</dt>
              <dd><cfoutput>#ctHtml(ctGet(ctGet(completedTiming, "actualDeparture", {}), "localLabel"), "Not available")#</cfoutput></dd>
            </div>
            <div class="ct-field">
              <dt>Planned Return</dt>
              <dd><cfoutput>#ctHtml(ctGet(ctGet(completedTiming, "plannedReturn", {}), "localLabel"), "Not available")#</cfoutput></dd>
            </div>
            <div class="ct-field">
              <dt>Actual Completion</dt>
              <dd><cfoutput>#ctHtml(ctGet(ctGet(completedTiming, "actualCompletion", {}), "localLabel"), "Not available")#</cfoutput></dd>
            </div>
          </dl>
          <p class="ct-inline-note">Duration is not calculated here because no existing authoritative duration field was identified for this minimum view.</p>
        </section>

        <section class="ct-card ct-card--half" aria-labelledby="completedTripRouteTitle">
          <h2 id="completedTripRouteTitle">Route Summary</h2>
          <dl class="ct-field-list">
            <div class="ct-field">
              <dt>Start</dt>
              <dd><cfoutput>#ctHtml(ctGet(completedRoute, "start"), "Not available")#</cfoutput></dd>
            </div>
            <div class="ct-field">
              <dt>Destination</dt>
              <dd><cfoutput>#ctHtml(ctGet(completedRoute, "destination"), "Not available")#</cfoutput></dd>
            </div>
            <div class="ct-field">
              <dt>Legs</dt>
              <dd><cfoutput>#ctCountLabel(ctGet(completedRoute, "legCount", 0), "leg", "legs")#</cfoutput></dd>
            </div>
            <div class="ct-field">
              <dt>Waypoints</dt>
              <dd><cfoutput>#ctCountLabel(ctGet(completedRoute, "waypointCount", 0), "waypoint", "waypoints")#</cfoutput></dd>
            </div>
            <div class="ct-field">
              <dt>Distance</dt>
              <dd><cfoutput>#ctHtml(ctGet(completedRoute, "distanceLabel"), "Not available")#</cfoutput></dd>
            </div>
            <div class="ct-field">
              <dt>Geometry Snapshot</dt>
              <dd><cfoutput>#ctBoolLabel(ctGet(ctGet(completedRoute, "geometrySnapshot", {}), "available", false))#</cfoutput></dd>
            </div>
          </dl>
        </section>

        <section class="ct-card ct-card--half" aria-labelledby="completedTripCompletionTitle">
          <h2 id="completedTripCompletionTitle">Completion Summary</h2>
          <dl class="ct-field-list">
            <div class="ct-field">
              <dt>Final Status</dt>
              <dd><span class="ct-pill <cfoutput>#ctAttr(ctStatusClass(ctGet(completedSummary, "status")))#</cfoutput>"><cfoutput>#ctHtml(ctGet(completedSummary, "status"), "Completed")#</cfoutput></span></dd>
            </div>
            <div class="ct-field">
              <dt>Route Completed</dt>
              <dd><cfoutput>#ctBoolLabel(ctGet(completedSummary, "routeCompleted", false))#</cfoutput></dd>
            </div>
            <div class="ct-field">
              <dt>Monitoring Closed</dt>
              <dd><cfoutput>#ctBoolLabel(ctGet(completedMonitoring, "closed", false))#</cfoutput></dd>
            </div>
            <div class="ct-field">
              <dt>Follow Final State</dt>
              <dd><cfoutput>#ctHtml(ctGet(completedFollow, "message"), "Not available")#</cfoutput></dd>
            </div>
          </dl>
          <p class="ct-inline-note">The completed-trip URL for safe-arrival email use is <a href="<cfoutput>#ctAttr(ctGet(completedTripModel, "completedTripUrl"))#</cfoutput>"><cfoutput>#ctHtml(ctGet(completedTripModel, "completedTripUrl"))#</cfoutput></a>.</p>
        </section>

        <section class="ct-card ct-card--half" aria-labelledby="completedTripContactTitle">
          <h2 id="completedTripContactTitle">Shore Contact</h2>
          <dl class="ct-field-list">
            <div class="ct-field">
              <dt>Associated Contacts</dt>
              <dd><cfoutput>#ctCountLabel(ctGet(completedShoreContact, "associatedCount", 0), "contact", "contacts")#</cfoutput></dd>
            </div>
            <div class="ct-field">
              <dt>Details Displayed</dt>
              <dd><cfoutput>#ctBoolLabel(ctGet(completedShoreContact, "displayed", false))#</cfoutput></dd>
            </div>
          </dl>
          <p class="ct-inline-note"><cfoutput>#ctHtml(ctGet(completedShoreContact, "message"), "Live shore-contact details are intentionally not shown as historical facts.")#</cfoutput></p>
        </section>

        <section class="ct-card ct-card--half" aria-labelledby="completedTripSourcesTitle">
          <h2 id="completedTripSourcesTitle">Data Sources</h2>
          <div class="ct-source-list">
            <div><strong>Trip</strong><span><cfoutput>#ctHtml(ctGet(completedDataSources, "trip"), "floatplans")#</cfoutput></span></div>
            <div><strong>Route</strong><span><cfoutput>#ctHtml(ctGet(completedDataSources, "route"), "route instances")#</cfoutput></span></div>
            <div><strong>Geometry</strong><span><cfoutput>#ctHtml(ctGet(completedDataSources, "routeGeometry"), "route snapshots")#</cfoutput></span></div>
            <div><strong>Vessel</strong><span><cfoutput>#ctHtml(ctGet(completedDataSources, "vesselName"), "current vessel row")#</cfoutput></span></div>
          </div>
        </section>

      </div>
    <cfelse>
      <section class="ct-empty-state" aria-labelledby="completedTripUnavailableTitle">
        <p class="ct-kicker">Completed trip unavailable</p>
        <h1 id="completedTripUnavailableTitle">Completed trip was not found.</h1>
        <p>The trip may not exist, may not belong to this member account, or may not have reached the authoritative completed state yet.</p>
        <a class="ct-link-button" href="<cfoutput>#request.fpwBase#</cfoutput>/app/dashboard.cfm">Back to Dashboard</a>
      </section>
    </cfif>
  </article>
</main>

</body>
</html>
