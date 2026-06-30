<cfprocessingdirective pageencoding="utf-8">
<cfsetting showdebugoutput="false" requesttimeout="30">
<cfcontent type="text/html; charset=utf-8">
<cfinclude template="../includes/fpw_base_path.cfm">
<cfabort>
<cfscript>
request.fpwTopNavActive = "great-loop-bridges";

try {
  bridgeSvc = createObject("component", "api.v1.GreatLoopBridgesService").init();
} catch (any svcPathError) {
  bridgeSvc = createObject("component", "fpw.api.v1.GreatLoopBridgesService").init();
}

filters = {
  "q" = structKeyExists(url, "q") ? trim(toString(url.q)) : "",
  "routeSegment" = structKeyExists(url, "routeSegment") ? trim(toString(url.routeSegment)) : "",
  "routeVariant" = structKeyExists(url, "routeVariant") ? trim(toString(url.routeVariant)) : "",
  "waterway" = structKeyExists(url, "waterway") ? trim(toString(url.waterway)) : "",
  "stateProvince" = structKeyExists(url, "stateProvince") ? trim(toString(url.stateProvince)) : "",
  "bridgeType" = structKeyExists(url, "bridgeType") ? trim(toString(url.bridgeType)) : "",
  "drawbridgeOnly" = structKeyExists(url, "drawbridgeOnly") ? trim(toString(url.drawbridgeOnly)) : "",
  "airDraftConcern" = structKeyExists(url, "airDraftConcern") ? trim(toString(url.airDraftConcern)) : "",
  "hasContact" = structKeyExists(url, "hasContact") ? trim(toString(url.hasContact)) : "",
  "hasCoordinates" = structKeyExists(url, "hasCoordinates") ? trim(toString(url.hasCoordinates)) : "",
  "verificationStatus" = structKeyExists(url, "verificationStatus") ? trim(toString(url.verificationStatus)) : "",
  "publicStatus" = structKeyExists(url, "publicStatus") ? trim(toString(url.publicStatus)) : "",
  "limit" = "500"
};

model = bridgeSvc.getLibraryModel(filters);
bridgeRows = model.BRIDGES;
stats = model.STATS;
facets = model.FACETS;
mapRows = [];
bridgeLibraryUrl = request.fpwBase & "/great-loop/bridges.cfm";
pageTitle = "Great Loop Bridge Library | FloatPlanWizard";
pageDescription = "Plan Great Loop bridge awareness with route segments, clearances, drawbridge contacts, schedules, and source-backed bridge notes. Always verify before transit.";
canonicalUrl = "https://floatplanwizard.com/great-loop/bridges.cfm";

function selectedAttr(required any leftValue, required any rightValue) {
  return compareNoCase(trim(toString(arguments.leftValue)), trim(toString(arguments.rightValue))) EQ 0 ? " selected" : "";
}

function checkedAttr(required any value) {
  return bridgeSvc.boolLike(arguments.value, false) ? " checked" : "";
}

function displayText(any value, string fallback="Not verified") {
  var txt = isNull(arguments.value) ? "" : trim(toString(arguments.value));
  return len(txt) ? txt : arguments.fallback;
}

function bridgeStatusLabel(required any value) {
  var txt = trim(toString(arguments.value));
  if (txt EQ "published") return "Published";
  if (txt EQ "planning_only") return "Planning only";
  return len(txt) ? txt : "Planning only";
}

for (bridgeItem in bridgeRows) {
  if (isNumeric(bridgeItem.latitude) AND isNumeric(bridgeItem.longitude)) {
    arrayAppend(mapRows, {
      "bridge_name" = bridgeItem.bridge_name,
      "slug" = bridgeItem.slug,
      "waterway" = bridgeItem.waterway,
      "route_segment" = bridgeItem.route_segment,
      "lat" = val(bridgeItem.latitude),
      "lng" = val(bridgeItem.longitude),
      "url" = bridgeSvc.buildPublicBridgeUrl(bridgeItem.slug, request.fpwBase)
    });
  }
}
</cfscript>

<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title><cfoutput>#encodeForHTML(pageTitle)#</cfoutput></title>
  <meta name="description" content="<cfoutput>#encodeForHTMLAttribute(pageDescription)#</cfoutput>">
  <link rel="canonical" href="<cfoutput>#encodeForHTMLAttribute(canonicalUrl)#</cfoutput>">
  <meta property="og:type" content="website">
  <meta property="og:site_name" content="FloatPlanWizard">
  <meta property="og:url" content="<cfoutput>#encodeForHTMLAttribute(canonicalUrl)#</cfoutput>">
  <meta property="og:title" content="<cfoutput>#encodeForHTMLAttribute(pageTitle)#</cfoutput>">
  <meta property="og:description" content="<cfoutput>#encodeForHTMLAttribute(pageDescription)#</cfoutput>">
  <meta property="og:image" content="https://floatplanwizard.com/assets/images/social/floatplanwizard-social-preview-20260602.png">
  <meta name="twitter:card" content="summary_large_image">
  <meta name="twitter:title" content="<cfoutput>#encodeForHTMLAttribute(pageTitle)#</cfoutput>">
  <meta name="twitter:description" content="<cfoutput>#encodeForHTMLAttribute(pageDescription)#</cfoutput>">
  <meta name="twitter:image" content="https://floatplanwizard.com/assets/images/social/floatplanwizard-social-preview-20260602.png">
<link rel="stylesheet" href="<cfoutput>#request.fpwBase#</cfoutput>/assets/css/top-nav.css?v=20260630-mega-weight-minus1">
  <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" integrity="sha256-p4NxAoJBhIIN+hmNHrzRCf9tD/miZyoHS5obTRR9BMY=" crossorigin="">
  <link rel="stylesheet" href="<cfoutput>#request.fpwBase#</cfoutput>/assets/css/great-loop-bridges.css?v=20260608-bridges">
  <cfinclude template="../includes/analytics_ga4.cfm">
</head>
<body class="fpw-bridge-body">
<cfinclude template="../includes/top_nav.cfm">

<main class="fpw-bridge-page">
  <section class="fpw-bridge-hero">
    <div class="fpw-bridge-shell">
      <p class="fpw-bridge-eyebrow">Great Loop planning reference</p>
      <h1>Great Loop Bridge Library</h1>
      <p>Search Great Loop bridge planning records by route segment, waterway, state, bridge type, drawbridge status, contact details, coordinates, and source-backed verification notes.</p>
      <div class="fpw-bridge-disclaimer">
        <strong>Planning awareness only:</strong>
        Bridge information is provided for planning awareness only. Always verify current bridge status, clearance, water levels, bridge schedules, opening restrictions, Local Notices to Mariners, bridge signage, and official charts before transit. FloatPlanWizard is not a navigation authority.
      </div>

      <div class="fpw-bridge-stats">
        <div class="fpw-bridge-stat"><strong><cfoutput>#numberFormat(stats.PUBLIC_ROWS)#</cfoutput></strong><span>Public planning records</span></div>
        <div class="fpw-bridge-stat"><strong><cfoutput>#numberFormat(stats.ROUTE_SEGMENT_COUNT)#</cfoutput></strong><span>Route segments</span></div>
        <div class="fpw-bridge-stat"><strong><cfoutput>#numberFormat(stats.WATERWAY_COUNT)#</cfoutput></strong><span>Waterways</span></div>
        <div class="fpw-bridge-stat"><strong><cfoutput>#numberFormat(stats.MISSING_COORDINATES_ROWS)#</cfoutput></strong><span>Rows missing coordinates</span></div>
      </div>
    </div>
  </section>

  <section class="fpw-bridge-shell fpw-bridge-layout" aria-label="Bridge library search">
    <aside class="fpw-bridge-panel">
      <h2>Find Bridges</h2>
      <form method="get" action="<cfoutput>#encodeForHTMLAttribute(bridgeLibraryUrl)#</cfoutput>" class="fpw-bridge-filter-form" data-bridge-filter-form data-bridge-api-endpoint="<cfoutput>#request.fpwApiBase#</cfoutput>/greatLoopBridges.cfc?method=handle&returnFormat=json" data-bridge-page-url="<cfoutput>#encodeForHTMLAttribute(bridgeLibraryUrl)#</cfoutput>">
        <div class="fpw-bridge-field">
          <label for="bridgeSearch">Search</label>
          <input type="search" id="bridgeSearch" name="q" value="<cfoutput>#encodeForHTMLAttribute(filters.q)#</cfoutput>" placeholder="Bridge, waterway, city, VHF, phone">
        </div>
        <div class="fpw-bridge-field">
          <label for="bridgeRouteSegment">Route Segment</label>
          <select id="bridgeRouteSegment" name="routeSegment">
            <option value="">All</option>
            <cfloop array="#facets.routeSegments#" index="opt"><cfoutput><option value="#encodeForHTMLAttribute(opt.value)#"#selectedAttr(filters.routeSegment, opt.value)#>#encodeForHTML(opt.label)#</option></cfoutput></cfloop>
          </select>
        </div>
        <div class="fpw-bridge-field">
          <label for="bridgeRouteVariant">Route Variant</label>
          <select id="bridgeRouteVariant" name="routeVariant">
            <option value="">All</option>
            <cfloop array="#facets.routeVariants#" index="opt"><cfoutput><option value="#encodeForHTMLAttribute(opt.value)#"#selectedAttr(filters.routeVariant, opt.value)#>#encodeForHTML(opt.label)#</option></cfoutput></cfloop>
          </select>
        </div>
        <div class="fpw-bridge-field">
          <label for="bridgeWaterway">Waterway</label>
          <select id="bridgeWaterway" name="waterway">
            <option value="">All</option>
            <cfloop array="#facets.waterways#" index="opt"><cfoutput><option value="#encodeForHTMLAttribute(opt.value)#"#selectedAttr(filters.waterway, opt.value)#>#encodeForHTML(opt.label)#</option></cfoutput></cfloop>
          </select>
        </div>
        <div class="fpw-bridge-field">
          <label for="bridgeState">State / Province</label>
          <select id="bridgeState" name="stateProvince">
            <option value="">All</option>
            <cfloop array="#facets.states#" index="opt"><cfoutput><option value="#encodeForHTMLAttribute(opt.value)#"#selectedAttr(filters.stateProvince, opt.value)#>#encodeForHTML(opt.label)#</option></cfoutput></cfloop>
          </select>
        </div>
        <div class="fpw-bridge-field">
          <label for="bridgeType">Bridge Type</label>
          <select id="bridgeType" name="bridgeType">
            <option value="">All</option>
            <cfloop array="#facets.bridgeTypes#" index="opt"><cfoutput><option value="#encodeForHTMLAttribute(opt.value)#"#selectedAttr(filters.bridgeType, opt.value)#>#encodeForHTML(opt.label)#</option></cfoutput></cfloop>
          </select>
        </div>
        <label class="fpw-bridge-check">Drawbridge only <input type="checkbox" name="drawbridgeOnly" value="1"<cfoutput>#checkedAttr(filters.drawbridgeOnly)#</cfoutput>></label>
        <label class="fpw-bridge-check">Air-draft concern <input type="checkbox" name="airDraftConcern" value="1"<cfoutput>#checkedAttr(filters.airDraftConcern)#</cfoutput>></label>
        <label class="fpw-bridge-check">Has VHF or phone <input type="checkbox" name="hasContact" value="1"<cfoutput>#checkedAttr(filters.hasContact)#</cfoutput>></label>
        <label class="fpw-bridge-check">Has coordinates <input type="checkbox" name="hasCoordinates" value="1"<cfoutput>#checkedAttr(filters.hasCoordinates)#</cfoutput>></label>
        <div class="fpw-bridge-actions">
          <button type="submit" class="fpw-bridge-btn fpw-bridge-btn--primary">Apply Filters</button>
          <a href="<cfoutput>#encodeForHTMLAttribute(bridgeLibraryUrl)#</cfoutput>" class="fpw-bridge-btn">Clear Filters</a>
        </div>
      </form>
      <p class="fpw-bridge-filter-status" data-bridge-filter-status aria-live="polite" hidden></p>
    </aside>

    <div class="fpw-bridge-main">
      <section class="fpw-bridge-panel" aria-label="Bridge map">
        <div class="fpw-bridge-map-toolbar">
          <div>
            <h2>Bridge Map</h2>
            <p data-bridge-result-summary><cfoutput>#arrayLen(bridgeRows)# bridge planning record#arrayLen(bridgeRows) EQ 1 ? "" : "s"# match, with #arrayLen(mapRows)# map marker#arrayLen(mapRows) EQ 1 ? "" : "s"#.</cfoutput></p>
          </div>
        </div>
        <div id="fpwBridgeMap" class="fpw-bridge-map" aria-label="Great Loop bridge map"></div>
        <p class="fpw-bridge-empty-map" data-bridge-empty-map<cfif arrayLen(mapRows)> hidden</cfif>>No bridge markers match the current filters.</p>
      </section>

      <section class="fpw-bridge-results" aria-label="Bridge results">
        <h2>Bridge Results</h2>
        <div class="fpw-bridge-result-list" data-bridge-result-list<cfif NOT arrayLen(bridgeRows)> hidden</cfif>>
          <cfloop array="#bridgeRows#" index="bridgeItem">
            <cfset bridgeImage = bridgeSvc.getBridgeImageAsset(bridgeItem, request.fpwBase)>
            <article class="fpw-bridge-card">
              <img src="<cfoutput>#encodeForHTMLAttribute(bridgeImage.url)#</cfoutput>" alt="" loading="lazy" decoding="async">
              <div>
                <h3><a href="<cfoutput>#encodeForHTMLAttribute(bridgeSvc.buildPublicBridgeUrl(bridgeItem.slug, request.fpwBase))#</cfoutput>"><cfoutput>#encodeForHTML(bridgeItem.bridge_name)#</cfoutput></a></h3>
                <p><cfoutput>#encodeForHTML(displayText(bridgeItem.waterway, "Waterway not verified"))#<cfif len(bridgeItem.route_segment)> - #encodeForHTML(bridgeItem.route_segment)#</cfif></cfoutput></p>
                <p><cfoutput>#encodeForHTML(displayText(bridgeItem.nearest_city, "Location not verified"))#<cfif len(bridgeItem.state_province)>, #encodeForHTML(bridgeItem.state_province)#</cfif><cfif len(bridgeItem.mile_marker)> - MM #encodeForHTML(bridgeItem.mile_marker)#</cfif></cfoutput></p>
                <p><cfoutput>#encodeForHTML(displayText(bridgeItem.bridge_type, "Bridge type not verified"))# - #encodeForHTML(len(trim(toString(bridgeItem.vertical_clearance_closed_ft))) ? bridgeItem.vertical_clearance_closed_ft & " ft closed" : "Clearance not verified")#</cfoutput></p>
                <div class="fpw-bridge-badges">
                  <span class="fpw-bridge-badge"><cfoutput>#encodeForHTML(bridgeStatusLabel(bridgeItem.public_status))#</cfoutput></span>
                  <cfif val(bridgeItem.is_drawbridge) EQ 1><span class="fpw-bridge-badge fpw-bridge-badge--warn">Drawbridge</span></cfif>
                  <cfif bridgeSvc.isAirDraftConcern(bridgeItem)><span class="fpw-bridge-badge fpw-bridge-badge--warn">Air draft concern</span></cfif>
                </div>
              </div>
            </article>
          </cfloop>
        </div>
        <div class="fpw-bridge-empty-state" data-bridge-empty-list<cfif arrayLen(bridgeRows)> hidden</cfif>>
          No public bridge planning records match the current filters.
        </div>
      </section>
    </div>
  </section>
</main>

<cfinclude template="../includes/footer.cfm">
<script id="fpwBridgeMapData" type="application/json"><cfoutput>#serializeJSON(mapRows)#</cfoutput></script>
<script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js" integrity="sha256-20nQCchB9co0qIjJZRGuk2/Z9VM+kNiyxNV1lvTlZBo=" crossorigin=""></script>
<script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/app/great-loop-bridges.js?v=20260608-bridges"></script>
</body>
</html>
