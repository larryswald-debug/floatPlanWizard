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
  ? "https://floatplanwizard.com/great-loop-bridge.cfm?slug=" & urlEncodedFormat(bridgeItem.slug)
  : "https://floatplanwizard.com/great-loop/bridges.cfm";
pageTitle = bridgeResult.SUCCESS
  ? bridgeItem.bridge_name & " | Great Loop Bridge Library | FloatPlanWizard"
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
  <link rel="stylesheet" href="<cfoutput>#request.fpwBase#</cfoutput>/assets/css/top-nav.css?v=20260530-nav-cta">
  <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" integrity="sha256-p4NxAoJBhIIN+hmNHrzRCf9tD/miZyoHS5obTRR9BMY=" crossorigin="">
  <link rel="stylesheet" href="<cfoutput>#request.fpwBase#</cfoutput>/assets/css/great-loop-bridges.css?v=20260608-bridges">
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
      <div class="fpw-bridge-disclaimer">
        <strong>Planning awareness only:</strong>
        Bridge information is provided for planning awareness only. Always verify current bridge status, clearance, water levels, bridge schedules, opening restrictions, Local Notices to Mariners, bridge signage, and official charts before transit. FloatPlanWizard is not a navigation authority.
      </div>
    </div>
  </section>

  <div class="fpw-bridge-shell">
    <p class="fpw-bridge-backlink"><a href="<cfoutput>#encodeForHTMLAttribute(request.fpwBase)#</cfoutput>/great-loop/bridges.cfm">&larr; Back to Bridge Library</a></p>

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
            <span class="fpw-bridge-badge"><cfoutput>#encodeForHTML(statusLabel(bridgeItem.public_status))#</cfoutput></span>
            <cfif val(bridgeItem.is_drawbridge) EQ 1><span class="fpw-bridge-badge fpw-bridge-badge--warn">Drawbridge / movable</span></cfif>
            <cfif val(bridgeItem.is_fixed) EQ 1><span class="fpw-bridge-badge">Fixed bridge</span></cfif>
            <cfif val(bridgeItem.is_railroad) EQ 1><span class="fpw-bridge-badge">Railroad bridge</span></cfif>
            <cfif bridgeSvc.isAirDraftConcern(bridgeItem)><span class="fpw-bridge-badge fpw-bridge-badge--warn">Air draft concern</span></cfif>
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

          <h2>Planning Notes</h2>
          <dl class="fpw-bridge-notes">
            <dt>Air Draft Notes</dt>
            <dd><cfoutput>#encodeForHTML(displayText(bridgeItem.air_draft_notes))#</cfoutput></dd>
            <dt>Opening Schedule</dt>
            <dd><cfoutput>#encodeForHTML(displayText(bridgeItem.opening_schedule))#</cfoutput></dd>
            <dt>Operator / Contact</dt>
            <dd><cfoutput>#encodeForHTML(displayText(bridgeItem.operator_contact))#</cfoutput></dd>
            <dt>Navigation Notes</dt>
            <dd><cfoutput>#encodeForHTML(displayText(bridgeItem.navigation_notes))#</cfoutput></dd>
            <dt>Regulatory Notes</dt>
            <dd><cfoutput>#encodeForHTML(displayText(bridgeItem.regulatory_notes))#</cfoutput></dd>
          </dl>
        </article>

        <aside class="fpw-bridge-panel fpw-bridge-detail-side">
          <h2>Bridge Image</h2>
          <img class="fpw-bridge-detail-image fpw-bridge-detail-side-image" src="<cfoutput>#encodeForHTMLAttribute(bridgeImage.url)#</cfoutput>" alt="" loading="lazy" decoding="async">

          <h2>Sources</h2>
          <ul class="fpw-bridge-source-list">
            <cfif len(trim(toString(bridgeItem.source_primary_url)))>
              <li><a href="<cfoutput>#encodeForHTMLAttribute(bridgeItem.source_primary_url)#</cfoutput>" rel="nofollow noopener" target="_blank">Primary source</a></li>
            </cfif>
            <cfif len(trim(toString(bridgeItem.source_secondary_url)))>
              <li><a href="<cfoutput>#encodeForHTMLAttribute(bridgeItem.source_secondary_url)#</cfoutput>" rel="nofollow noopener" target="_blank">Secondary source</a></li>
            </cfif>
            <cfif NOT len(trim(toString(bridgeItem.source_primary_url))) AND NOT len(trim(toString(bridgeItem.source_secondary_url)))>
              <li>Source URL not verified.</li>
            </cfif>
          </ul>
        </aside>
      </section>
    </cfif>
  </div>
</main>

<cfinclude template="includes/footer.cfm">
<script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js" integrity="sha256-20nQCchB9co0qIjJZRGuk2/Z9VM+kNiyxNV1lvTlZBo=" crossorigin=""></script>
<script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/app/great-loop-bridges.js?v=20260608-bridges"></script>
</body>
</html>
