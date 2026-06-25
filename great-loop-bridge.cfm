<cfprocessingdirective pageencoding="utf-8">
<cfsetting showdebugoutput="false" requesttimeout="30">
<cfcontent type="text/html; charset=utf-8">
<cfinclude template="includes/fpw_base_path.cfm">

<cfscript>
request.fpwTopNavActive = "great-loop-bridges";

try {
  bridgeSvc = createObject("component", "api.v1.GreatLoopBridgesService").init();
} catch (any svcPathError) {
  bridgeSvc = createObject("component", "fpw.api.v1.GreatLoopBridgesService").init();
}

slugValue = structKeyExists(url, "slug") ? trim(toString(url.slug)) : "";
bridgeResult = bridgeSvc.getBridgeBySlug(slugValue);

if (!bridgeResult.SUCCESS) {
  cfheader(statuscode=404);
}

bridgeItem = bridgeResult.SUCCESS ? bridgeResult.BRIDGE : {};
bridgeImage = bridgeResult.SUCCESS ? bridgeSvc.getBridgeImageAsset(bridgeItem, request.fpwBase) : {};
canonicalUrl = bridgeResult.SUCCESS
  ? "https://floatplanwizard.com/great-loop/bridges/" & bridgeSvc.normalizeSlug(bridgeItem.slug) & "/"
  : "https://floatplanwizard.com/great-loop/bridges/";
pageTitle = bridgeResult.SUCCESS
  ? bridgeItem.bridge_name & " Guide | Great Loop Bridge Planning | FloatPlanWizard"
  : "Bridge Not Found | Great Loop Bridge Library | FloatPlanWizard";
waterwayText = bridgeResult.SUCCESS AND len(trim(toString(bridgeItem.waterway))) ? bridgeItem.waterway : "its waterway";
pageDescription = bridgeResult.SUCCESS
  ? "Bridge planning details for " & bridgeItem.bridge_name & " on " & waterwayText & ", including clearance, bridge type, opening/contact notes where available, and source-backed navigation cautions."
  : "The requested Great Loop bridge planning reference could not be found.";
hasCoordinates = bridgeResult.SUCCESS AND isNumeric(bridgeItem.latitude) AND isNumeric(bridgeItem.longitude);

function displayText(any value, string fallback="Not verified") {
  var txt = isNull(arguments.value) ? "" : trim(toString(arguments.value));
  return len(txt) ? txt : arguments.fallback;
}

function statusLabel(required any value) {
  var txt = trim(toString(arguments.value));
  if (txt EQ "published") return "Published";
  if (txt EQ "planning_only") return "Planning only";
  if (txt EQ "admin_review") return "Admin review";
  if (txt EQ "do_not_publish") return "Do not publish";
  return len(txt) ? txt : "Planning only";
}

function clearanceText(any value) {
  var txt = isNull(arguments.value) ? "" : trim(toString(arguments.value));
  return len(txt) ? txt & " ft" : "Not verified";
}

schemaAtKey = chr(64);
schemaTypeKey = schemaAtKey & "type";
schemaIdKey = schemaAtKey & "id";
schemaContextKey = schemaAtKey & "context";
schemaGraphKey = schemaAtKey & "graph";

function detailSchemaRef(required string idValue) {
  var out = structNew("ordered");
  structInsert(out, schemaIdKey, arguments.idValue, true);
  return out;
}

function detailSchemaListItem(required numeric position, required string name, required string urlValue) {
  var out = structNew("ordered");
  var item = structNew("ordered");
  structInsert(out, schemaTypeKey, "ListItem", true);
  out["position"] = arguments.position;
  structInsert(item, schemaIdKey, arguments.urlValue, true);
  item["name"] = arguments.name;
  out["item"] = item;
  return out;
}

detailJsonLdText = "";
if (bridgeResult.SUCCESS) {
  detailSchemaGraph = [];
  detailSchemaOrg = structNew("ordered");
  detailSchemaWebsite = structNew("ordered");
  detailSchemaPage = structNew("ordered");
  detailSchemaBreadcrumb = structNew("ordered");
  detailSchemaPosition = 1;

  structInsert(detailSchemaOrg, schemaTypeKey, "Organization", true);
  structInsert(detailSchemaOrg, schemaIdKey, "https://floatplanwizard.com/##organization", true);
  detailSchemaOrg["name"] = "FloatPlanWizard";
  detailSchemaOrg["url"] = "https://floatplanwizard.com/";
  arrayAppend(detailSchemaGraph, detailSchemaOrg);

  structInsert(detailSchemaWebsite, schemaTypeKey, "WebSite", true);
  structInsert(detailSchemaWebsite, schemaIdKey, "https://floatplanwizard.com/##website", true);
  detailSchemaWebsite["name"] = "FloatPlanWizard";
  detailSchemaWebsite["url"] = "https://floatplanwizard.com/";
  detailSchemaWebsite["publisher"] = detailSchemaRef("https://floatplanwizard.com/##organization");
  arrayAppend(detailSchemaGraph, detailSchemaWebsite);

  structInsert(detailSchemaBreadcrumb, schemaTypeKey, "BreadcrumbList", true);
  structInsert(detailSchemaBreadcrumb, schemaIdKey, canonicalUrl & "##breadcrumb", true);
  detailSchemaBreadcrumb["itemListElement"] = [];
  arrayAppend(detailSchemaBreadcrumb["itemListElement"], detailSchemaListItem(detailSchemaPosition++, "FloatPlanWizard", "https://floatplanwizard.com/"));
  arrayAppend(detailSchemaBreadcrumb["itemListElement"], detailSchemaListItem(detailSchemaPosition++, "Great Loop Bridges", "https://floatplanwizard.com/great-loop/bridges/"));
  if (len(trim(toString(bridgeItem.state_province)))) {
    arrayAppend(detailSchemaBreadcrumb["itemListElement"], detailSchemaListItem(detailSchemaPosition++, bridgeItem.state_province, "https://floatplanwizard.com/great-loop/bridges/state/" & bridgeSvc.normalizeSlug(bridgeItem.state_province) & "/"));
  }
  if (len(trim(toString(bridgeItem.waterway)))) {
    arrayAppend(detailSchemaBreadcrumb["itemListElement"], detailSchemaListItem(detailSchemaPosition++, bridgeItem.waterway, "https://floatplanwizard.com/great-loop/bridges/waterway/" & bridgeSvc.normalizeSlug(bridgeItem.waterway) & "/"));
  }
  arrayAppend(detailSchemaBreadcrumb["itemListElement"], detailSchemaListItem(detailSchemaPosition, bridgeItem.bridge_name, canonicalUrl));
  arrayAppend(detailSchemaGraph, detailSchemaBreadcrumb);

  structInsert(detailSchemaPage, schemaTypeKey, "WebPage", true);
  structInsert(detailSchemaPage, schemaIdKey, canonicalUrl & "##webpage", true);
  detailSchemaPage["url"] = canonicalUrl;
  detailSchemaPage["name"] = pageTitle;
  detailSchemaPage["description"] = pageDescription;
  detailSchemaPage["isPartOf"] = detailSchemaRef("https://floatplanwizard.com/##website");
  detailSchemaPage["publisher"] = detailSchemaRef("https://floatplanwizard.com/##organization");
  detailSchemaPage["breadcrumb"] = detailSchemaRef(canonicalUrl & "##breadcrumb");
  arrayAppend(detailSchemaGraph, detailSchemaPage);

  detailJsonLd = structNew("ordered");
  structInsert(detailJsonLd, schemaContextKey, "https://schema.org", true);
  structInsert(detailJsonLd, schemaGraphKey, detailSchemaGraph, true);
  detailJsonLdText = replace(serializeJSON(detailJsonLd), "</", "<\/", "all");
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
  <cfif len(detailJsonLdText)>
    <script type="application/ld+json"><cfoutput>#detailJsonLdText#</cfoutput></script>
  </cfif>
  <link rel="stylesheet" href="<cfoutput>#request.fpwBase#</cfoutput>/assets/css/layout.css?v=20260620-page-width">
  <link rel="stylesheet" href="<cfoutput>#request.fpwBase#</cfoutput>/assets/css/top-nav.css?v=20260530-nav-cta">
  <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" integrity="sha256-p4NxAoJBhIIN+hmNHrzRCf9tD/miZyoHS5obTRR9BMY=" crossorigin="">
  <link rel="stylesheet" href="<cfoutput>#request.fpwBase#</cfoutput>/assets/css/great-loop-bridges.css?v=20260624-bridge-eyebrow-cascade">
  <cfinclude template="includes/analytics_ga4.cfm">
  <cfinclude template="includes/analytics_clarity.cfm">
</head>
<body class="fpw-bridge-body">
<cfinclude template="includes/top_nav.cfm">

<main class="fpw-bridge-page">
  <section class="fpw-bridge-hero fpw-bridge-hero--detail">
    <div class="fpw-bridge-shell">
      <p class="fpw-bridge-eyebrow">Great Loop bridge planning reference</p>
      <cfif bridgeResult.SUCCESS>
        <h1><cfoutput>#encodeForHTML(bridgeItem.bridge_name)#</cfoutput></h1>
        <p><cfoutput>#encodeForHTML(displayText(bridgeItem.short_description, "Bridge planning details, source notes, contact fields, and clearance fields should be verified before transit."))#</cfoutput></p>
      <cfelse>
        <h1>Bridge Not Found</h1>
        <p>The requested bridge is not currently available in the public Great Loop Bridge Library.</p>
      </cfif>
    </div>
  </section>

  <div class="fpw-bridge-shell">
    <nav class="fpw-bridge-breadcrumbs" aria-label="Breadcrumb">
      <a href="<cfoutput>#encodeForHTMLAttribute(request.fpwBase & "/great-loop/bridges/")#</cfoutput>">Great Loop Bridges</a>
      <cfif bridgeResult.SUCCESS AND len(trim(toString(bridgeItem.state_province)))>
        <span>&rsaquo;</span>
        <a href="<cfoutput>#encodeForHTMLAttribute(request.fpwBase & "/great-loop/bridges/state/" & bridgeSvc.normalizeSlug(bridgeItem.state_province) & "/")#</cfoutput>"><cfoutput>#encodeForHTML(bridgeItem.state_province)#</cfoutput></a>
      </cfif>
      <cfif bridgeResult.SUCCESS AND len(trim(toString(bridgeItem.waterway)))>
        <span>&rsaquo;</span>
        <a href="<cfoutput>#encodeForHTMLAttribute(request.fpwBase & "/great-loop/bridges/waterway/" & bridgeSvc.normalizeSlug(bridgeItem.waterway) & "/")#</cfoutput>"><cfoutput>#encodeForHTML(bridgeItem.waterway)#</cfoutput></a>
      </cfif>
      <cfif bridgeResult.SUCCESS>
        <span>&rsaquo;</span>
        <span><cfoutput>#encodeForHTML(bridgeItem.bridge_name)#</cfoutput></span>
      </cfif>
    </nav>

    <cfif NOT bridgeResult.SUCCESS>
      <section class="fpw-bridge-panel">
        <h2>Public bridge record unavailable</h2>
        <p>This slug may be missing, unpublished, or marked do not publish.</p>
      </section>
    <cfelse>
      <section class="fpw-bridge-detail-layout">
        <article class="fpw-bridge-panel fpw-bridge-detail-main">
          <cfif hasCoordinates>
            <div id="fpwBridgeDetailMap" class="fpw-bridge-map fpw-bridge-detail-map fpw-bridge-detail-map--main" data-lat="<cfoutput>#encodeForHTMLAttribute(bridgeItem.latitude)#</cfoutput>" data-lng="<cfoutput>#encodeForHTMLAttribute(bridgeItem.longitude)#</cfoutput>" data-name="<cfoutput>#encodeForHTMLAttribute(bridgeItem.bridge_name)#</cfoutput>"></div>
            <p class="fpw-bridge-detail-coordinates"><cfoutput>#encodeForHTML(bridgeItem.latitude)#, #encodeForHTML(bridgeItem.longitude)#</cfoutput></p>
          <cfelse>
            <div class="fpw-bridge-detail-map fpw-bridge-detail-map--main fpw-bridge-detail-map--empty">
              <p>Coordinates are not verified for this bridge yet.</p>
            </div>
          </cfif>

          <div class="fpw-bridge-badges fpw-bridge-detail-badges">
            <cfif val(bridgeItem.is_drawbridge) EQ 1><span class="fpw-bridge-badge fpw-bridge-badge--warn">Drawbridge / movable</span></cfif>
            <cfif val(bridgeItem.is_fixed) EQ 1><span class="fpw-bridge-badge">Fixed bridge</span></cfif>
            <cfif val(bridgeItem.is_railroad) EQ 1><span class="fpw-bridge-badge">Railroad bridge</span></cfif>
          </div>

          <div class="fpw-bridge-detail-grid">
            <div><span>Waterway</span><strong><cfoutput>#encodeForHTML(displayText(bridgeItem.waterway))#</cfoutput></strong></div>
            <div><span>Route Segment</span><strong><cfoutput>#encodeForHTML(displayText(bridgeItem.route_segment))#</cfoutput></strong></div>
            <div><span>Route Variant</span><strong><cfoutput>#encodeForHTML(displayText(bridgeItem.route_variant))#</cfoutput></strong></div>
            <div><span>State / Province</span><strong><cfoutput>#encodeForHTML(displayText(bridgeItem.state_province))#</cfoutput></strong></div>
            <div><span>Nearest City</span><strong><cfoutput>#encodeForHTML(displayText(bridgeItem.nearest_city))#</cfoutput></strong></div>
            <div><span>Mile Marker</span><strong><cfoutput>#encodeForHTML(displayText(bridgeItem.mile_marker))#</cfoutput></strong></div>
            <div><span>Bridge Type</span><strong><cfoutput>#encodeForHTML(displayText(bridgeItem.bridge_type))#</cfoutput></strong></div>
            <div><span>Source Confidence</span><strong><cfoutput>#encodeForHTML(displayText(bridgeItem.source_confidence))#</cfoutput></strong></div>
          </div>

          <h2>What Boaters Should Know</h2>
          <p><cfoutput>#encodeForHTML(displayText(bridgeItem.short_description, "Use this bridge record as a planning reference for location, clearance fields, bridge type, contact fields, and source notes. Verify current conditions before transit."))#</cfoutput></p>

          <h2>Clearance And Opening Details</h2>
          <div class="fpw-bridge-detail-grid">
            <div><span>Vertical Clearance Closed</span><strong><cfoutput>#encodeForHTML(clearanceText(bridgeItem.vertical_clearance_closed_ft))#</cfoutput></strong></div>
            <div><span>Vertical Clearance Open</span><strong><cfoutput>#encodeForHTML(clearanceText(bridgeItem.vertical_clearance_open_ft))#</cfoutput></strong></div>
            <div><span>Horizontal Clearance</span><strong><cfoutput>#encodeForHTML(clearanceText(bridgeItem.horizontal_clearance_ft))#</cfoutput></strong></div>
            <div><span>VHF Channel</span><strong><cfoutput>#encodeForHTML(displayText(bridgeItem.vhf_channel))#</cfoutput></strong></div>
            <div><span>Phone</span><strong><cfoutput>#encodeForHTML(displayText(bridgeItem.phone))#</cfoutput></strong></div>
            <div><span>Last Verified</span><strong><cfoutput>#encodeForHTML(displayText(bridgeItem.last_verified_date))#</cfoutput></strong></div>
          </div>

          <cfif val(bridgeItem.is_drawbridge) EQ 1 AND NOT len(trim(toString(bridgeItem.vhf_channel))) AND NOT len(trim(toString(bridgeItem.phone)))>
            <div class="fpw-bridge-warning">Bridge contact information has not been verified yet. Confirm current opening procedures before transit.</div>
          </cfif>
          <cfif len(trim(toString(bridgeItem.vertical_clearance_closed_ft))) OR len(trim(toString(bridgeItem.vertical_clearance_open_ft))) OR len(trim(toString(bridgeItem.horizontal_clearance_ft)))>
            <div class="fpw-bridge-warning">Verify against current water level / bridge gauge before transit.</div>
          </cfif>

          <h2>Opening / Contact Notes</h2>
          <dl class="fpw-bridge-notes">
            <dt>Opening Schedule</dt>
            <dd><cfoutput>#encodeForHTML(displayText(bridgeItem.opening_schedule))#</cfoutput></dd>
            <dt>Operator / Contact</dt>
            <dd><cfoutput>#encodeForHTML(displayText(bridgeItem.operator_contact))#</cfoutput></dd>
          </dl>

          <h2>Navigation And Regulatory Notes</h2>
          <dl class="fpw-bridge-notes">
            <dt>Air Draft Notes</dt>
            <dd><cfoutput>#encodeForHTML(displayText(bridgeItem.air_draft_notes))#</cfoutput></dd>
            <dt>Navigation Notes</dt>
            <dd><cfoutput>#encodeForHTML(displayText(bridgeItem.navigation_notes))#</cfoutput></dd>
            <dt>Regulatory Notes</dt>
            <dd><cfoutput>#encodeForHTML(displayText(bridgeItem.regulatory_notes))#</cfoutput></dd>
          </dl>

          <h2>Planning Considerations</h2>
          <p>Confirm your vessel air draft, current water levels, bridge signage, official charts, bridge schedules, Local Notices to Mariners, and any VHF or phone procedures before approaching this bridge. If the bridge is movable, build extra time into your route plan for opening windows, traffic, restrictions, weather, and communication delays.</p>
        </article>

        <aside class="fpw-bridge-panel fpw-bridge-detail-side">
          <h2>Bridge Image</h2>
          <img class="fpw-bridge-detail-image fpw-bridge-detail-side-image" src="<cfoutput>#encodeForHTMLAttribute(bridgeImage.url)#</cfoutput>" alt="" loading="lazy" decoding="async">

          <h2>Related Bridges</h2>
          <ul class="fpw-bridge-source-list">
            <cfif len(trim(toString(bridgeItem.state_province)))>
              <li><a href="<cfoutput>#request.fpwBase#/great-loop/bridges/state/#encodeForURL(bridgeSvc.normalizeSlug(bridgeItem.state_province))#/</cfoutput>"><cfoutput>#encodeForHTML(bridgeItem.state_province)#</cfoutput> bridges</a></li>
            </cfif>
            <cfif len(trim(toString(bridgeItem.waterway)))>
              <li><a href="<cfoutput>#request.fpwBase#/great-loop/bridges/waterway/#encodeForURL(bridgeSvc.normalizeSlug(bridgeItem.waterway))#/</cfoutput>"><cfoutput>#encodeForHTML(bridgeItem.waterway)#</cfoutput> bridges</a></li>
            </cfif>
            <cfif len(trim(toString(bridgeItem.route_segment)))>
              <li><a href="<cfoutput>#request.fpwBase#/great-loop/bridges/route/#encodeForURL(bridgeSvc.normalizeSlug(bridgeItem.route_segment))#/</cfoutput>"><cfoutput>#encodeForHTML(bridgeItem.route_segment)#</cfoutput> bridges</a></li>
            </cfif>
          </ul>
        </aside>
      </section>
    </cfif>
  </div>

  <section class="fpw-bridge-shell fpw-bridge-awareness fpw-bridge-awareness--detail" aria-label="Bridge planning awareness">
    <div class="fpw-bridge-disclaimer">
      <strong>Planning awareness only:</strong>
      Bridge information is provided for planning awareness only. Always verify current bridge status, clearance, water levels, bridge schedules, opening restrictions, Local Notices to Mariners, bridge signage, and official charts before transit. FloatPlanWizard is not a navigation authority.
    </div>
  </section>
</main>

<cfinclude template="includes/footer.cfm">
<script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js" integrity="sha256-20nQCchB9co0qIjJZRGuk2/Z9VM+kNiyxNV1lvTlZBo=" crossorigin=""></script>
<script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/maps/leaflet-noaa-waypoint-map.js?v=20260619-nautical-charts"></script>
<script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/app/great-loop-bridges.js?v=20260619-noaa-charts"></script>
</body>
</html>
