<cfprocessingdirective pageencoding="utf-8">
<cfscript>
/*
 * This page lives outside /app, so resolve the application base path before
 * require_auth.cfm applies the shared path normalization rules.
 */
if (!structKeyExists(request, "fpwBase")) {
  highDetailPocScriptName = structKeyExists(cgi, "script_name")
    ? replace(trim(toString(cgi.script_name)), "\", "/", "all")
    : "/demo/noaa-high-detail-comparison-poc.cfm";
  highDetailPocBasePath = reReplaceNoCase(
    highDetailPocScriptName,
    "/demo/noaa-high-detail-comparison-poc\.cfm$",
    ""
  );
  highDetailPocBasePath = reReplace(highDetailPocBasePath, "/$", "");

  if (highDetailPocBasePath == "/") {
    highDetailPocBasePath = "";
  }
  if (len(highDetailPocBasePath) && left(highDetailPocBasePath, 1) != "/") {
    highDetailPocBasePath = "/" & highDetailPocBasePath;
  }

  request.fpwBase = highDetailPocBasePath;
}

request.highDetailPocFault = "";
highDetailPocFaultCandidate = structKeyExists(url, "pocFault")
  ? lcase(trim(toString(url.pocFault)))
  : "";
if (listFindNoCase(
  "chart-transparent,bluetopo,native,featureinfo,route,waypoints,map-init",
  highDetailPocFaultCandidate
)) {
  request.highDetailPocFault = highDetailPocFaultCandidate;
}

request.highDetailPocFocus = (
  structKeyExists(url, "pocFocus")
  && lcase(trim(toString(url.pocFocus))) == "nodata"
) ? "nodata" : "";
</cfscript>
<cfinclude template="../includes/require_auth.cfm">
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>NOAA High-Detail Seafloor Comparison - Float Plan Wizard</title>
  <meta name="viewport" content="width=device-width, initial-scale=1">

  <cfinclude template="../includes/header_styles.cfm">
  <link
    rel="stylesheet"
    href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css"
    integrity="sha256-p4NxAoJBhIIN+hmNHrzRCf9tD/miZyoHS5obTRR9BMY="
    crossorigin="">
  <link
    rel="stylesheet"
    href="<cfoutput>#request.fpwBase#</cfoutput>/assets/css/demo/noaa-high-detail-comparison-poc.css?v=20260728-poc6">
</head>
<body class="dashboard-body high-detail-poc-body" data-fpw-page="noaa-high-detail-comparison-poc">

<cfset request.fpwTopNavActive = "">
<cfinclude template="../includes/top_nav.cfm">

<main
  id="high-detail-poc-root"
  class="high-detail-poc fpw-layout-rail"
  data-fpw-base="<cfoutput>#encodeForHTMLAttribute(request.fpwBase)#</cfoutput>"
  data-poc-fault="<cfoutput>#encodeForHTMLAttribute(request.highDetailPocFault)#</cfoutput>"
  data-poc-focus="<cfoutput>#encodeForHTMLAttribute(request.highDetailPocFocus)#</cfoutput>"
  data-native-tile-template="<cfoutput>#encodeForHTMLAttribute(request.fpwBase & "/assets/maps/poc/south-tampa-high-detail/{z}/{x}/{y}.png")#</cfoutput>"
  data-native-manifest-url="<cfoutput>#encodeForHTMLAttribute(request.fpwBase & "/assets/maps/poc/south-tampa-high-detail/manifest.json")#</cfoutput>"
  data-native-min-zoom="14"
  data-native-max-zoom="17"
  data-approved-center-lat="27.7009075652856"
  data-approved-center-lng="-82.6200072680348"
  data-mobile-breakpoint="920">

  <header class="high-detail-poc-hero">
    <div>
      <div class="high-detail-poc-eyebrow">
        <span class="high-detail-poc-badge">Isolated proof of concept</span>
        <span>Southern Tampa Bay · Approved 2 km × 2 km test area</span>
      </div>
      <h1>NOAA High-Detail Seafloor Comparison</h1>
      <p>
        Compare NOAA BlueTopo with native-resolution relief derived from the 2021
        NOAA NGS Southern Tampa Bay Topobathy DEM while preserving NOAA nautical-chart
        context and an illustrative FPW planning route.
      </p>
    </div>
    <a class="high-detail-poc-back" href="<cfoutput>#request.fpwBase#</cfoutput>/app/dashboard.cfm">
      Return to Dashboard
    </a>
  </header>

  <section class="high-detail-poc-notice" aria-label="Navigation and datum warning">
    <strong>Planning visualization only — not for navigation.</strong>
    <span>Bathymetric elevation relative to NAVD88.</span>
    <span>NOAA charted depths relative to MLLW.</span>
    <span>Neither relief layer represents current water depth.</span>
  </section>

  <section class="high-detail-poc-toolbar" aria-labelledby="high-detail-poc-controls-heading">
    <div class="high-detail-poc-toolbar-intro">
      <span class="high-detail-poc-panel-kicker">Interactive comparison</span>
      <h2 id="high-detail-poc-controls-heading">Comparison controls</h2>
      <p>Switch sources without changing the approved map position or zoom.</p>
    </div>

    <fieldset class="high-detail-poc-mode-fieldset">
      <legend>Comparison mode</legend>
      <div class="high-detail-poc-mode-options" role="radiogroup" aria-label="Seafloor comparison mode">
        <label>
          <input type="radio" name="high-detail-poc-mode" value="compare" checked>
          <span>Side-by-side comparison</span>
        </label>
        <label>
          <input type="radio" name="high-detail-poc-mode" value="chart">
          <span>NOAA Chart only</span>
        </label>
        <label>
          <input type="radio" name="high-detail-poc-mode" value="bluetopo">
          <span>BlueTopo relief only</span>
        </label>
        <label>
          <input type="radio" name="high-detail-poc-mode" value="bluetopo-chart">
          <span>BlueTopo with NOAA Chart</span>
        </label>
        <label>
          <input type="radio" name="high-detail-poc-mode" value="native">
          <span>Native 1 m relief only</span>
        </label>
        <label>
          <input type="radio" name="high-detail-poc-mode" value="native-chart">
          <span>Native 1 m with NOAA Chart</span>
        </label>
        <label>
          <input type="radio" name="high-detail-poc-mode" value="native-fallback">
          <span>Native 1 m with BlueTopo fallback + NOAA Chart</span>
        </label>
      </div>
    </fieldset>

    <fieldset class="high-detail-poc-overlay-fieldset">
      <legend>Independent overlays</legend>
      <div class="high-detail-poc-toggle-options">
        <label>
          <input id="high-detail-poc-route-toggle" type="checkbox" checked>
          <span>Route</span>
        </label>
        <label>
          <input id="high-detail-poc-waypoint-toggle" type="checkbox" checked>
          <span>Waypoints</span>
        </label>
        <label>
          <input id="high-detail-poc-basemap-toggle" type="checkbox">
          <span>Neutral basemap <small>debug only</small></span>
        </label>
      </div>
    </fieldset>
  </section>

  <section class="high-detail-poc-status-grid" aria-label="Map and layer status">
    <div class="high-detail-poc-service">
      <span>NOAA Chart</span>
      <strong id="high-detail-poc-chart-status" class="high-detail-poc-status-chip" data-state="loading" role="status" aria-live="polite" aria-atomic="true">Checking…</strong>
    </div>
    <div class="high-detail-poc-service">
      <span>BlueTopo</span>
      <strong id="high-detail-poc-bluetopo-status" class="high-detail-poc-status-chip" data-state="loading" role="status" aria-live="polite" aria-atomic="true">Loading…</strong>
    </div>
    <div class="high-detail-poc-service">
      <span>Native 1 m</span>
      <strong id="high-detail-poc-native-status" class="high-detail-poc-status-chip" data-state="loading" role="status" aria-live="polite" aria-atomic="true">Loading…</strong>
    </div>
    <div class="high-detail-poc-service">
      <span>Map alignment</span>
      <strong id="high-detail-poc-sync-status" class="high-detail-poc-status-chip" data-state="loading" role="status" aria-live="polite" aria-atomic="true">Preparing…</strong>
    </div>
    <div class="high-detail-poc-service">
      <span>Current mode</span>
      <strong id="high-detail-poc-mode-status" class="high-detail-poc-status-chip" data-state="loading" role="status" aria-live="polite" aria-atomic="true">Preparing…</strong>
    </div>
    <div class="high-detail-poc-service">
      <span>Route</span>
      <strong id="high-detail-poc-route-status" class="high-detail-poc-status-chip" data-state="loading" role="status" aria-live="polite" aria-atomic="true">Preparing…</strong>
    </div>
    <div class="high-detail-poc-service">
      <span>Waypoints</span>
      <strong id="high-detail-poc-waypoint-status" class="high-detail-poc-status-chip" data-state="loading" role="status" aria-live="polite" aria-atomic="true">Preparing…</strong>
    </div>
    <div class="high-detail-poc-service">
      <span>Initial render</span>
      <strong id="high-detail-poc-performance-status" class="high-detail-poc-status-chip" data-state="loading" role="status" aria-live="polite" aria-atomic="true">Measuring…</strong>
    </div>
  </section>

  <div id="high-detail-poc-chart-warning" class="high-detail-poc-warning" role="alert" hidden>
    <strong>NOAA chart service warning.</strong>
    <span id="high-detail-poc-chart-warning-text">
      NOAA Chart Display is currently unavailable. Relief layers may still be shown,
      but the official chart context is missing.
    </span>
  </div>

  <div id="high-detail-poc-bluetopo-warning" class="high-detail-poc-warning" role="alert" hidden>
    <strong>BlueTopo service warning.</strong>
    <span id="high-detail-poc-bluetopo-warning-text">
      NOAA BlueTopo is currently unavailable. The native survey, NOAA chart, route,
      waypoints, and controls remain available.
    </span>
  </div>

  <div id="high-detail-poc-native-warning" class="high-detail-poc-warning" role="alert" hidden>
    <strong>Native survey warning.</strong>
    <span id="high-detail-poc-native-warning-text">
      The native 1 m South Tampa relief is currently unavailable or partially
      unavailable. BlueTopo and NOAA chart layers remain available.
    </span>
  </div>

  <div id="high-detail-poc-zoom-warning" class="high-detail-poc-warning" role="status" aria-live="polite" hidden>
    Native survey detail is available only at the documented tile zoom range.
    The map does not imply additional source resolution beyond native 1 metre cells.
  </div>

  <div id="high-detail-poc-fatal-error" class="high-detail-poc-fatal" role="alert" hidden>
    The high-detail comparison maps could not be initialized.
  </div>

  <section class="high-detail-poc-comparison" aria-labelledby="high-detail-poc-map-heading">
    <header class="high-detail-poc-comparison-head">
      <div>
        <span class="high-detail-poc-panel-kicker">Identical center and zoom</span>
        <h2 id="high-detail-poc-map-heading">Interactive source comparison</h2>
        <p>
          Desktop maps synchronize in both directions. Narrow screens use one map with
          the same comparison controls to preserve position and reduce tile workload.
        </p>
      </div>
      <div class="high-detail-poc-route-key" aria-label="Illustrative route legend">
        <span><i class="high-detail-poc-route-line" aria-hidden="true"></i>Illustrative planning route</span>
        <span><i class="high-detail-poc-route-start" aria-hidden="true"></i>Start</span>
        <span><i class="high-detail-poc-route-end" aria-hidden="true"></i>End</span>
      </div>
    </header>

    <div id="high-detail-poc-desktop-workspace" class="high-detail-poc-desktop-maps">
      <article class="high-detail-poc-map-card" aria-labelledby="high-detail-poc-left-heading">
        <header class="high-detail-poc-map-card-head">
          <div>
            <span class="high-detail-poc-source-label">Left source</span>
            <h3 id="high-detail-poc-left-heading">NOAA BlueTopo</h3>
          </div>
          <span id="high-detail-poc-left-mode-label" class="high-detail-poc-map-mode-label">BlueTopo + NOAA Chart</span>
        </header>
        <div class="high-detail-poc-map-wrap">
          <div
            id="high-detail-poc-left-map"
            class="high-detail-poc-map"
            role="application"
            aria-label="Left synchronized map showing NOAA BlueTopo, NOAA chart context, and an illustrative planning route">
          </div>
          <div id="high-detail-poc-left-loading" class="high-detail-poc-map-loading" role="status" aria-live="polite">
            <span class="high-detail-poc-spinner" aria-hidden="true"></span>
            <strong>Loading BlueTopo comparison…</strong>
          </div>
        </div>
      </article>

      <article class="high-detail-poc-map-card" aria-labelledby="high-detail-poc-right-heading">
        <header class="high-detail-poc-map-card-head">
          <div>
            <span class="high-detail-poc-source-label">Right source</span>
            <h3 id="high-detail-poc-right-heading">Native 1 m South Tampa relief</h3>
          </div>
          <span id="high-detail-poc-right-mode-label" class="high-detail-poc-map-mode-label">Native 1 m + NOAA Chart</span>
        </header>
        <div class="high-detail-poc-map-wrap">
          <div
            id="high-detail-poc-right-map"
            class="high-detail-poc-map"
            role="application"
            aria-label="Right synchronized map showing native one metre South Tampa relief, NOAA chart context, and an illustrative planning route">
          </div>
          <div id="high-detail-poc-right-loading" class="high-detail-poc-map-loading" role="status" aria-live="polite">
            <span class="high-detail-poc-spinner" aria-hidden="true"></span>
            <strong>Loading native 1 m comparison…</strong>
          </div>
        </div>
      </article>
    </div>

    <article id="high-detail-poc-mobile-workspace" class="high-detail-poc-mobile-workspace" aria-labelledby="high-detail-poc-mobile-heading">
      <header class="high-detail-poc-map-card-head">
        <div>
          <span class="high-detail-poc-source-label">Mobile comparison source</span>
          <h3 id="high-detail-poc-mobile-heading">Native 1 m South Tampa relief</h3>
        </div>
        <span id="high-detail-poc-mobile-mode-label" class="high-detail-poc-map-mode-label">Native 1 m + NOAA Chart</span>
      </header>
      <div class="high-detail-poc-map-wrap">
        <div
          id="high-detail-poc-mobile-map"
          class="high-detail-poc-map"
          role="application"
          aria-label="Single responsive map comparing NOAA BlueTopo and native one metre South Tampa relief">
        </div>
        <div id="high-detail-poc-mobile-loading" class="high-detail-poc-map-loading" role="status" aria-live="polite">
          <span class="high-detail-poc-spinner" aria-hidden="true"></span>
          <strong>Loading mobile comparison…</strong>
        </div>
      </div>
    </article>
  </section>

  <section class="high-detail-poc-legend" aria-labelledby="high-detail-poc-legend-heading">
    <div>
      <span class="high-detail-poc-panel-kicker">Matched bathymetric palette</span>
      <h2 id="high-detail-poc-legend-heading">Elevation and fallback legend</h2>
      <p>
        The native layer uses the official BlueTopo <code>nbs_elevation</code> palette
        and restrained multidirectional hillshade to make source detail—not styling—the
        focus of the comparison.
      </p>
    </div>
    <div class="high-detail-poc-legend-ramp">
      <img
        src="https://nowcoast.noaa.gov/geoserver/ows?service=WMS&amp;request=GetLegendGraphic&amp;version=1.1.0&amp;format=image%2Fpng&amp;width=293&amp;height=24&amp;layer=bluetopo%3Abathymetry&amp;style=nbs_elevation"
        alt="NOAA BlueTopo bathymetric elevation color legend">
      <strong>Bathymetric elevation relative to NAVD88</strong>
      <small>Transparent native nodata may reveal BlueTopo only when fallback mode is enabled.</small>
      <small>NOAA charted depths relative to MLLW use a different vertical datum.</small>
    </div>
  </section>

  <section class="high-detail-poc-information" aria-label="Source and inspection information">
    <div class="high-detail-poc-sources">
      <header>
        <span class="high-detail-poc-panel-kicker">Source transparency</span>
        <h2>Official sources and limitations</h2>
      </header>

      <div class="high-detail-poc-source-grid">
        <article>
          <h3>2021 NOAA NGS Southern Tampa Bay Topobathy DEM</h3>
          <dl class="high-detail-poc-metadata-list">
            <div><dt>Source agency</dt><dd>NOAA National Geodetic Survey</dd></div>
            <div><dt>Survey dates</dt><dd>2021-01-26 through 2021-02-27</dd></div>
            <div><dt>Native resolution</dt><dd>1 metre</dd></div>
            <div><dt>Horizontal CRS</dt><dd>NAD83(2011) / UTM Zone 17N (EPSG:6346)</dd></div>
            <div><dt>Vertical datum</dt><dd>NAVD88, Geoid18</dd></div>
            <div><dt>Units</dt><dd>metres</dd></div>
            <div><dt>Processing date</dt><dd id="high-detail-poc-processing-date">Loading tile manifest…</dd></div>
            <div><dt>Tile zoom range</dt><dd>14–17</dd></div>
            <div><dt>Valid coverage</dt><dd>99.97035%</dd></div>
          </dl>
          <p class="high-detail-poc-qa-note">
            Bathymetric RMSEz 15.5 cm; 95% confidence value 30.4 cm.
            Dataset-level values, not per-cell guarantees.
          </p>
          <p class="high-detail-poc-source-caution">Not intended for charting or navigation.</p>
        </article>

        <article>
          <h3>NOAA BlueTopo</h3>
          <dl class="high-detail-poc-metadata-list">
            <div><dt>Source agency</dt><dd>NOAA Office of Coast Survey</dd></div>
            <div><dt>Vertical datum</dt><dd>NAVD88</dd></div>
            <div><dt>Surface content</dt><dd>Measured and interpolated values; reported per selected location when available</dd></div>
            <div><dt>Source identity</dt><dd>Reported through FeatureInfo when available</dd></div>
            <div><dt>Uncertainty</dt><dd>Reported through FeatureInfo when available</dd></div>
          </dl>
          <p class="high-detail-poc-source-caution">Not for navigation.</p>
          <a href="https://nauticalcharts.noaa.gov/data/bluetopo_specs.html" target="_blank" rel="noopener noreferrer">
            BlueTopo specifications
          </a>
        </article>

        <article>
          <h3>NOAA Chart Display Service</h3>
          <dl class="high-detail-poc-metadata-list">
            <div><dt>Source agency</dt><dd>NOAA Office of Coast Survey</dd></div>
            <div><dt>Charted depths</dt><dd>Relative to MLLW</dd></div>
            <div><dt>Update behavior</dt><dd>Fetched from NOAA’s live Chart Display Service through FPW’s existing allow-listed proxy; GetMap responses are cached for 300 seconds</dd></div>
          </dl>
          <p class="high-detail-poc-source-caution">
            Relief must not be presented as authoritative chart context when this service is unavailable.
          </p>
          <a href="https://nauticalcharts.noaa.gov/data/gis-data-and-services.html" target="_blank" rel="noopener noreferrer">
            NOAA chart services documentation
          </a>
        </article>
      </div>
    </div>

    <aside class="high-detail-poc-inspect" aria-labelledby="high-detail-poc-inspect-heading">
      <header>
        <div>
          <span class="high-detail-poc-panel-kicker">Independent FeatureInfo query</span>
          <h2 id="high-detail-poc-inspect-heading">Inspect BlueTopo source data</h2>
        </div>
        <span id="high-detail-poc-inspect-status" class="high-detail-poc-status-chip" data-state="idle">Ready</span>
      </header>

      <p id="high-detail-poc-inspect-message" class="high-detail-poc-inspect-message" role="status" aria-live="polite">
        Click a water location on either visible map. FeatureInfo failure is isolated
        from chart, relief, route, waypoint, and comparison controls.
      </p>

      <dl class="high-detail-poc-inspect-grid">
        <div><dt>Selected location</dt><dd id="high-detail-poc-inspect-location">—</dd></div>
        <div><dt>BlueTopo elevation</dt><dd id="high-detail-poc-inspect-elevation">—</dd></div>
        <div><dt>Reported uncertainty</dt><dd id="high-detail-poc-inspect-uncertainty">—</dd></div>
        <div><dt>Measured / interpolated</dt><dd id="high-detail-poc-inspect-coverage">—</dd></div>
        <div><dt>Source identity</dt><dd id="high-detail-poc-inspect-source">—</dd></div>
        <div><dt>Survey date</dt><dd id="high-detail-poc-inspect-survey-date">—</dd></div>
        <div><dt>Source institution</dt><dd id="high-detail-poc-inspect-institution">—</dd></div>
      </dl>

      <div class="high-detail-poc-inspect-caution">
        A negative elevation means the seafloor is below NAVD88. It must not be
        interpreted as current water depth or a charted navigational sounding.
      </div>
    </aside>
  </section>

  <section class="high-detail-poc-disclaimer" aria-label="Proof of concept disclaimer">
    The high-detail relief and BlueTopo layers are informational visualizations derived
    from NOAA data. They do not represent current water depth and are not intended for
    navigation. NOAA charted depths use a different vertical datum. NOAA does not endorse
    or certify FloatPlanWizard. Boaters remain responsible for using current official
    charts and notices, maintaining a proper lookout, verifying conditions, and exercising
    prudent navigation.
  </section>

  <section id="high-detail-poc-attribution" class="high-detail-poc-attribution" aria-label="Data attribution">
    <strong>Attribution:</strong>
    NOAA Office of Coast Survey · NOAA National Geodetic Survey · NOAA BlueTopo ·
    Leaflet · OpenStreetMap contributors when the optional neutral basemap is enabled.
    <span>Illustrative planning route — not a validated safe route.</span>
  </section>
</main>

<cfinclude template="../includes/footer.cfm">
<cfinclude template="../includes/footer_scripts.cfm">
<script
  src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"
  integrity="sha256-20nQCchB9co0qIjJZRGuk2/Z9VM+kNiyxNV1lvTlZBo="
  crossorigin=""></script>
<script
  src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/demo/noaa-high-detail-comparison-poc.js?v=20260728-poc6"></script>
</body>
</html>
