<cfprocessingdirective pageencoding="utf-8">
<cfscript>
/*
 * This page lives outside /app, so resolve the application base path before
 * require_auth.cfm applies the shared path normalization rules.
 */
if (!structKeyExists(request, "fpwBase")) {
  fpwPocScriptName = structKeyExists(cgi, "script_name")
    ? replace(trim(toString(cgi.script_name)), "\", "/", "all")
    : "/demo/noaa-bathymetry-poc.cfm";
  fpwPocBasePath = reReplaceNoCase(
    fpwPocScriptName,
    "/demo/noaa-bathymetry-poc\.cfm$",
    ""
  );
  fpwPocBasePath = reReplace(fpwPocBasePath, "/$", "");

  if (fpwPocBasePath == "/") {
    fpwPocBasePath = "";
  }
  if (len(fpwPocBasePath) && left(fpwPocBasePath, 1) != "/") {
    fpwPocBasePath = "/" & fpwPocBasePath;
  }

  request.fpwBase = fpwPocBasePath;
}
</cfscript>
<cfinclude template="../includes/require_auth.cfm">
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>NOAA Chart and Seafloor Relief POC - Float Plan Wizard</title>
  <meta name="viewport" content="width=device-width, initial-scale=1">

  <cfinclude template="../includes/header_styles.cfm">
  <link
    rel="stylesheet"
    href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css"
    integrity="sha256-p4NxAoJBhIIN+hmNHrzRCf9tD/miZyoHS5obTRR9BMY="
    crossorigin="">
  <link
    rel="stylesheet"
    href="<cfoutput>#request.fpwBase#</cfoutput>/assets/css/demo/noaa-bathymetry-poc.css?v=20260728-poc">
</head>
<body class="dashboard-body fpw-noaa-poc-body" data-fpw-page="noaa-bathymetry-poc">

<cfset request.fpwTopNavActive = "">
<cfinclude template="../includes/top_nav.cfm">

<main
  id="noaaBathymetryPoc"
  class="fpw-noaa-poc fpw-layout-rail"
  data-fpw-base="<cfoutput>#encodeForHTMLAttribute(request.fpwBase)#</cfoutput>">

  <header class="fpw-noaa-poc__hero">
    <div>
      <div class="fpw-noaa-poc__eyebrow">
        <span class="fpw-noaa-poc__badge">Isolated proof of concept</span>
        <span>Tampa Bay, Florida</span>
      </div>
      <h1>NOAA Chart and Seafloor Relief POC</h1>
      <p>
        Evaluate official NOAA chart context and BlueTopo-derived seafloor relief
        beneath an illustrative FPW route. This page is not connected to Route Builder
        and does not save or modify route data.
      </p>
    </div>
    <a class="fpw-noaa-poc__back" href="<cfoutput>#request.fpwBase#</cfoutput>/app/dashboard.cfm">
      Return to Dashboard
    </a>
  </header>

  <section class="fpw-noaa-poc__notice" aria-label="Navigation warning">
    <strong>Planning visualization only — not for navigation.</strong>
    BlueTopo elevation is referenced to NAVD88 and is not a charted depth, sounding,
    or real-time water depth. Use current official NOAA ENCs and appropriate navigation
    equipment for navigation.
  </section>

  <section class="fpw-noaa-poc__toolbar" aria-labelledby="pocViewModeHeading">
    <div>
      <h2 id="pocViewModeHeading">Visual mode</h2>
      <p>Choose a focused comparison or use the map layer control for a custom combination.</p>
    </div>
    <div class="fpw-noaa-poc__mode-options" role="radiogroup" aria-label="Map visual mode">
      <label>
        <input type="radio" name="pocVisualMode" value="chart">
        <span>NOAA Chart only</span>
      </label>
      <label>
        <input type="radio" name="pocVisualMode" value="relief">
        <span>Seafloor Relief only</span>
      </label>
      <label>
        <input type="radio" name="pocVisualMode" value="combined" checked>
        <span>Combined view</span>
      </label>
    </div>
  </section>

  <div class="fpw-noaa-poc__service-row" aria-label="Layer status">
    <div class="fpw-noaa-poc__service">
      <span>NOAA Chart proxy</span>
      <strong id="pocChartStatus" class="poc-status-chip" data-state="loading">Checking…</strong>
    </div>
    <div class="fpw-noaa-poc__service">
      <span>BlueTopo relief</span>
      <strong id="pocReliefStatus" class="poc-status-chip" data-state="loading">Loading…</strong>
    </div>
    <div class="fpw-noaa-poc__service">
      <span>Current mode</span>
      <strong id="pocModeStatus" class="poc-status-chip" data-state="ready">Combined</strong>
    </div>
    <div class="fpw-noaa-poc__service">
      <span>Initial render</span>
      <strong id="pocPerformanceStatus" class="poc-status-chip" data-state="loading">Measuring…</strong>
    </div>
  </div>

  <div
    id="pocChartHealthWarning"
    class="fpw-noaa-poc__warning"
    role="alert"
    hidden>
    <strong>NOAA chart service warning.</strong>
    <span id="pocChartHealthWarningText">
      The chart proxy returned transparent output. Seafloor relief, route, waypoints,
      and map controls remain available.
    </span>
  </div>

  <div
    id="pocFatalError"
    class="fpw-noaa-poc__fatal"
    role="alert"
    hidden>
    The map could not be initialized.
  </div>

  <section class="fpw-noaa-poc__workspace" aria-label="NOAA chart and BlueTopo proof of concept">
    <article class="fpw-noaa-poc__map-card">
      <div class="fpw-noaa-poc__map-head">
        <div>
          <h2>Tampa Bay map</h2>
          <p>Click BlueTopo coverage to inspect the elevation source and uncertainty.</p>
        </div>
        <div class="fpw-noaa-poc__route-key" aria-label="Sample route legend">
          <span><i class="route-line" aria-hidden="true"></i>Illustrative FPW route</span>
          <span><i class="route-start" aria-hidden="true"></i>Start</span>
          <span><i class="route-end" aria-hidden="true"></i>End</span>
        </div>
      </div>

      <div class="fpw-noaa-poc__map-wrap">
        <div
          id="pocMap"
          class="fpw-noaa-poc__map"
          role="application"
          aria-label="Interactive Tampa Bay map showing NOAA charts, BlueTopo relief, and an illustrative FPW route">
        </div>
        <div id="pocMapLoading" class="fpw-noaa-poc__map-loading" role="status" aria-live="polite">
          <span class="fpw-noaa-poc__spinner" aria-hidden="true"></span>
          <strong>Loading NOAA map layers…</strong>
        </div>
        <div class="fpw-noaa-poc__depth-legend" aria-label="BlueTopo elevation legend">
          <span>Official BlueTopo elevation rendering</span>
          <img
            src="https://nowcoast.noaa.gov/geoserver/ows?service=WMS&amp;request=GetLegendGraphic&amp;version=1.1.0&amp;format=image%2Fpng&amp;width=293&amp;height=24&amp;layer=bluetopo%3Abathymetry&amp;style=nbs_elevation"
            alt="NOAA BlueTopo elevation color legend">
          <small>Elevation in meters relative to NAVD88</small>
        </div>
      </div>
    </article>

    <aside class="fpw-noaa-poc__inspect" aria-labelledby="pocInspectHeading">
      <header>
        <div>
          <span class="fpw-noaa-poc__panel-kicker">Independent FeatureInfo query</span>
          <h2 id="pocInspectHeading">Inspect BlueTopo elevation</h2>
        </div>
        <span id="pocInspectState" class="poc-status-chip" data-state="idle">Ready</span>
      </header>

      <p id="pocInspectMessage" class="fpw-noaa-poc__inspect-message" role="status" aria-live="polite">
        Click a water location on the map. FeatureInfo failure is isolated from all map layers and controls.
      </p>

      <dl class="fpw-noaa-poc__inspect-grid">
        <div>
          <dt>Selected location</dt>
          <dd id="pocInspectLocation">—</dd>
        </div>
        <div>
          <dt>BlueTopo elevation (NAVD88)</dt>
          <dd id="pocInspectElevation">—</dd>
        </div>
        <div>
          <dt>Reported vertical uncertainty</dt>
          <dd id="pocInspectUncertainty">—</dd>
        </div>
        <div>
          <dt>Coverage classification</dt>
          <dd id="pocInspectCoverage">—</dd>
        </div>
        <div>
          <dt>Source survey</dt>
          <dd id="pocInspectSource">—</dd>
        </div>
        <div>
          <dt>Survey date</dt>
          <dd id="pocInspectSurveyDate">—</dd>
        </div>
        <div>
          <dt>Source institution</dt>
          <dd id="pocInspectInstitution">—</dd>
        </div>
      </dl>

      <div class="fpw-noaa-poc__inspect-caution">
        A negative elevation means the seafloor is below NAVD88. It must not be
        interpreted as current water depth or a charted navigational sounding.
      </div>
    </aside>
  </section>

  <section class="fpw-noaa-poc__sources" aria-labelledby="pocSourcesHeading">
    <div class="fpw-noaa-poc__sources-intro">
      <span class="fpw-noaa-poc__panel-kicker">Source transparency</span>
      <h2 id="pocSourcesHeading">Official data sources and limitations</h2>
      <p>
        Data used in this demonstration was derived from NOAA Office of Coast Survey
        BlueTopo. The FPW sample route and waypoints are disposable demonstration data.
      </p>
      <p class="fpw-noaa-poc__load-time">
        Last map load:
        <time id="pocLastMapLoadTime">Waiting for map layers…</time>
      </p>
    </div>

    <div class="fpw-noaa-poc__source-grid">
      <article>
        <h3>NOAA Chart Display Service</h3>
        <p>
          Rendered from NOAA Electronic Navigational Charts and requested through FPW’s
          existing allow-listed WMS proxy.
        </p>
        <a
          href="https://nauticalcharts.noaa.gov/data/gis-data-and-services.html"
          target="_blank"
          rel="noopener noreferrer">NOAA chart services documentation</a>
      </article>

      <article>
        <h3>NOAA BlueTopo via nowCOAST</h3>
        <p>
          Official elevation and hillshade WMTS layers. BlueTopo combines source data
          of varying age and quality and may include interpolated values. Survey dates
          are reported per selected location in the FeatureInfo panel when available.
        </p>
        <a
          href="https://nauticalcharts.noaa.gov/data/bluetopo_specs.html"
          target="_blank"
          rel="noopener noreferrer">BlueTopo specifications</a>
      </article>

      <article>
        <h3>Reference basemap</h3>
        <p>
          OpenStreetMap is used only for neutral land and place-name context beneath
          the NOAA overlays.
        </p>
        <a
          href="https://www.openstreetmap.org/copyright"
          target="_blank"
          rel="noopener noreferrer">OpenStreetMap attribution</a>
      </article>
    </div>

    <div class="fpw-noaa-poc__disclaimer">
      <strong>Not for navigation or measurement.</strong>
      BlueTopo is not on a navigational vertical datum and may contain position,
      elevation, interpolation, and other quality issues. The user assumes all risk
      associated with this planning demonstration. NOAA does not endorse or certify
      FloatPlanWizard. Seafloor relief is an informational visualization and does not
      replace current official nautical charts, notices, prudent navigation, or a
      proper lookout.
    </div>
  </section>
</main>

<cfinclude template="../includes/footer.cfm">
<cfinclude template="../includes/footer_scripts.cfm">
<script
  src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"
  integrity="sha256-20nQCchB9co0qIjJZRGuk2/Z9VM+kNiyxNV1lvTlZBo="
  crossorigin=""></script>
<script
  src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/demo/noaa-bathymetry-poc.js?v=20260728-poc"></script>
</body>
</html>
