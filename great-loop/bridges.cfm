<cfprocessingdirective pageencoding="utf-8">
<cfsetting showdebugoutput="false" requesttimeout="30">
<cfcontent type="text/html; charset=utf-8">
<cfinclude template="../includes/fpw_base_path.cfm">

<cfscript>
request.fpwTopNavActive = "great-loop-bridges";

try {
  bridgeSvc = createObject("component", "api.v1.GreatLoopBridgesService").init();
} catch (any svcPathError) {
  bridgeSvc = createObject("component", "fpw.api.v1.GreatLoopBridgesService").init();
}

routeStateSlug = "";
if (structKeyExists(url, "stateSlug") AND !isNull(url.stateSlug)) {
  routeStateSlug = trim(toString(url.stateSlug));
}
routeStateSlug = reReplace(routeStateSlug, "[?##].*$", "");
routeStateSlug = reReplace(routeStateSlug, "^/+|/+$", "", "all");

routeWaterwaySlug = "";
if (structKeyExists(url, "waterwaySlug") AND !isNull(url.waterwaySlug)) {
  routeWaterwaySlug = trim(toString(url.waterwaySlug));
}
routeWaterwaySlug = reReplace(routeWaterwaySlug, "[?##].*$", "");
routeWaterwaySlug = reReplace(routeWaterwaySlug, "^/+|/+$", "", "all");

routeSegmentSlug = "";
if (structKeyExists(url, "routeSlug") AND !isNull(url.routeSlug)) {
  routeSegmentSlug = trim(toString(url.routeSlug));
}
routeSegmentSlug = reReplace(routeSegmentSlug, "[?##].*$", "");
routeSegmentSlug = reReplace(routeSegmentSlug, "^/+|/+$", "", "all");

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

bridgeLibraryUrl = request.fpwBase & "/great-loop/bridges/";
bridgeCanonicalUrl = "https://floatplanwizard.com/great-loop/bridges/";
taxonomyType = "";
taxonomyName = "";
taxonomyCount = 0;
taxonomyNotFound = false;

if (len(routeStateSlug)) {
  routeStateModel = bridgeSvc.getStateModel(routeStateSlug);
  if (routeStateModel.SUCCESS) {
    taxonomyType = "state";
    taxonomyName = routeStateModel.STATE;
    taxonomyCount = arrayLen(routeStateModel.BRIDGES);
    filters.stateProvince = routeStateModel.STATE;
    bridgeCanonicalUrl &= "state/" & bridgeSvc.normalizeSlug(routeStateModel.STATE) & "/";
  } else {
    cfheader(statuscode = "404");
    taxonomyType = "not-found";
    taxonomyName = "State or province not found";
    taxonomyNotFound = true;
  }
} else if (len(routeWaterwaySlug)) {
  routeWaterwayModel = bridgeSvc.getWaterwayModel(routeWaterwaySlug);
  if (routeWaterwayModel.SUCCESS) {
    taxonomyType = "waterway";
    taxonomyName = routeWaterwayModel.WATERWAY;
    taxonomyCount = arrayLen(routeWaterwayModel.BRIDGES);
    filters.waterway = routeWaterwayModel.WATERWAY;
    bridgeCanonicalUrl &= "waterway/" & bridgeSvc.normalizeSlug(routeWaterwayModel.WATERWAY) & "/";
  } else {
    cfheader(statuscode = "404");
    taxonomyType = "not-found";
    taxonomyName = "Waterway not found";
    taxonomyNotFound = true;
  }
} else if (len(routeSegmentSlug)) {
  routeSegmentModel = bridgeSvc.getRouteSegmentModel(routeSegmentSlug);
  if (routeSegmentModel.SUCCESS) {
    taxonomyType = "route";
    taxonomyName = routeSegmentModel.ROUTE_SEGMENT;
    taxonomyCount = arrayLen(routeSegmentModel.BRIDGES);
    filters.routeSegment = routeSegmentModel.ROUTE_SEGMENT;
    bridgeCanonicalUrl &= "route/" & bridgeSvc.normalizeSlug(routeSegmentModel.ROUTE_SEGMENT) & "/";
  } else {
    cfheader(statuscode = "404");
    taxonomyType = "not-found";
    taxonomyName = "Route segment not found";
    taxonomyNotFound = true;
  }
}

model = bridgeSvc.getLibraryModel(filters);
bridgeRows = model.BRIDGES;
stats = model.STATS;
facets = model.FACETS;
mapRows = [];
featuredBridgeRows = [];
displayBridgeRows = [];
schemaBridgeRows = [];
pageTitle = "Great Loop Bridges | Clearances, Drawbridges & Route Planning";
pageDescription = "Plan Great Loop bridge awareness with clearances, drawbridges, route segments, waterways, contact fields, and source-backed bridge notes. Always verify before transit.";
pageHeading = "Great Loop Bridge Library";
pageLede = "Search Great Loop bridge planning records by route segment, waterway, state, bridge type, drawbridge status, contact details, coordinates, and source-backed verification notes.";
canonicalUrl = bridgeCanonicalUrl;
isBridgeHubPage = taxonomyType EQ "";
isDefaultBridgeHubView = isBridgeHubPage
  AND !len(filters.q)
  AND !len(filters.routeSegment)
  AND !len(filters.routeVariant)
  AND !len(filters.waterway)
  AND !len(filters.stateProvince)
  AND !len(filters.bridgeType)
  AND !len(filters.drawbridgeOnly)
  AND !len(filters.airDraftConcern)
  AND !len(filters.hasContact)
  AND !len(filters.hasCoordinates)
  AND !len(filters.verificationStatus)
  AND !len(filters.publicStatus);

if (taxonomyType EQ "state" AND len(taxonomyName)) {
  pageTitle = taxonomyName & " Great Loop Bridges | Clearances, Drawbridges & Route Planning";
  pageDescription = "Browse " & taxonomyName & " Great Loop bridges with clearance fields, drawbridge planning notes, waterways, route segments, and source-backed bridge details.";
  pageHeading = taxonomyName & " Great Loop Bridges";
  pageLede = "Explore " & taxonomyCount & " public Great Loop bridge planning records in " & taxonomyName & ", including waterway, route segment, bridge type, clearance fields, and verification notes.";
} else if (taxonomyType EQ "waterway" AND len(taxonomyName)) {
  pageTitle = taxonomyName & " Bridges | Great Loop Bridge Guide";
  pageDescription = "Browse " & taxonomyName & " Great Loop bridges with clearance fields, drawbridge contacts, opening notes, and boater planning context.";
  pageHeading = taxonomyName & " Bridges";
  pageLede = "Explore " & taxonomyCount & " public bridge planning records on the " & taxonomyName & ", including clearance fields, bridge type, drawbridge status, and source-backed notes.";
} else if (taxonomyType EQ "route" AND len(taxonomyName)) {
  pageTitle = taxonomyName & " Bridges | Great Loop Route Planning";
  pageDescription = "Browse Great Loop bridges on the " & taxonomyName & " route segment with clearances, drawbridge details, waterways, and planning notes.";
  pageHeading = taxonomyName & " Bridges";
  pageLede = "Explore " & taxonomyCount & " public bridge planning records for the " & taxonomyName & " route segment, including clearances, drawbridge status, waterways, and verification notes.";
} else if (taxonomyType EQ "not-found") {
  pageTitle = "Great Loop Bridge Page Not Found | FloatPlanWizard";
  pageDescription = "The requested Great Loop bridge state, waterway, or route page could not be found.";
  pageHeading = taxonomyName;
  pageLede = "The requested Great Loop bridge taxonomy page could not be found. Browse the main bridge library to find public bridge planning references.";
  bridgeRows = [];
  mapRows = [];
}

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

function bridgeLocationLine(required struct bridgeItem) {
  var pieces = [];
  if (len(trim(toString(arguments.bridgeItem.nearest_city)))) {
    arrayAppend(pieces, trim(toString(arguments.bridgeItem.nearest_city)));
  }
  if (len(trim(toString(arguments.bridgeItem.state_province)))) {
    arrayAppend(pieces, trim(toString(arguments.bridgeItem.state_province)));
  }
  return arrayLen(pieces) ? arrayToList(pieces, ", ") : "Location not verified";
}

function bridgeRouteLine(required struct bridgeItem) {
  var pieces = [];
  if (len(trim(toString(arguments.bridgeItem.waterway)))) {
    arrayAppend(pieces, trim(toString(arguments.bridgeItem.waterway)));
  }
  if (len(trim(toString(arguments.bridgeItem.route_segment)))) {
    arrayAppend(pieces, trim(toString(arguments.bridgeItem.route_segment)));
  }
  return arrayLen(pieces) ? arrayToList(pieces, " - ") : "Waterway not verified";
}

function getRandomInitialBridges(required array sourceRows, numeric limitRows = 10) {
  var rows = [];
  var out = [];
  var i = 0;
  var maxRows = min(max(0, val(arguments.limitRows)), arrayLen(arguments.sourceRows));
  var swapIndex = 0;
  var tempRow = {};

  for (i = 1; i LTE arrayLen(arguments.sourceRows); i++) {
    arrayAppend(rows, arguments.sourceRows[i]);
  }

  for (i = arrayLen(rows); i GT 1; i--) {
    swapIndex = randRange(1, i);
    tempRow = rows[i];
    rows[i] = rows[swapIndex];
    rows[swapIndex] = tempRow;
  }

  for (i = 1; i LTE maxRows; i++) {
    arrayAppend(out, rows[i]);
  }

  return out;
}

hubSampleLimit = 10;
hubSchemaLimit = 6;
mapSourceBridgeRows = bridgeRows;

if (taxonomyType NEQ "not-found") {
  if (isDefaultBridgeHubView) {
    featuredBridgeRows = getRandomInitialBridges(bridgeRows, hubSampleLimit);
    displayBridgeRows = featuredBridgeRows;
    mapSourceBridgeRows = featuredBridgeRows;

    for (hubSchemaIndex = 1; hubSchemaIndex LTE min(hubSchemaLimit, arrayLen(bridgeRows)); hubSchemaIndex++) {
      arrayAppend(schemaBridgeRows, bridgeRows[hubSchemaIndex]);
    }
  } else if (isBridgeHubPage) {
    displayBridgeRows = [];
    schemaBridgeRows = [];
  } else {
    displayBridgeRows = bridgeRows;
    schemaBridgeRows = bridgeRows;
  }
}

for (bridgeItem in mapSourceBridgeRows) {
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

schemaAtKey = chr(64);
schemaTypeKey = schemaAtKey & "type";
schemaIdKey = schemaAtKey & "id";
schemaContextKey = schemaAtKey & "context";
schemaGraphKey = schemaAtKey & "graph";

function bridgeSchemaRef(required string idValue) {
  var out = structNew("ordered");
  structInsert(out, schemaIdKey, arguments.idValue, true);
  return out;
}

function bridgeSchemaListItem(required numeric position, required string name, required string urlValue) {
  var out = structNew("ordered");
  var item = structNew("ordered");
  structInsert(out, schemaTypeKey, "ListItem", true);
  out["position"] = arguments.position;
  structInsert(item, schemaIdKey, arguments.urlValue, true);
  item["name"] = arguments.name;
  out["item"] = item;
  return out;
}

pageJsonLdText = "";
if (taxonomyType NEQ "not-found") {
  schemaGraph = [];
  schemaOrg = structNew("ordered");
  schemaWebsite = structNew("ordered");
  schemaPage = structNew("ordered");
  schemaBreadcrumb = structNew("ordered");
  schemaItemList = structNew("ordered");
  schemaPosition = 1;

  structInsert(schemaOrg, schemaTypeKey, "Organization", true);
  structInsert(schemaOrg, schemaIdKey, "https://floatplanwizard.com/##organization", true);
  schemaOrg["name"] = "FloatPlanWizard";
  schemaOrg["url"] = "https://floatplanwizard.com/";
  arrayAppend(schemaGraph, schemaOrg);

  structInsert(schemaWebsite, schemaTypeKey, "WebSite", true);
  structInsert(schemaWebsite, schemaIdKey, "https://floatplanwizard.com/##website", true);
  schemaWebsite["name"] = "FloatPlanWizard";
  schemaWebsite["url"] = "https://floatplanwizard.com/";
  schemaWebsite["publisher"] = bridgeSchemaRef("https://floatplanwizard.com/##organization");
  arrayAppend(schemaGraph, schemaWebsite);

  structInsert(schemaBreadcrumb, schemaTypeKey, "BreadcrumbList", true);
  structInsert(schemaBreadcrumb, schemaIdKey, canonicalUrl & "##breadcrumb", true);
  schemaBreadcrumb["itemListElement"] = [];
  arrayAppend(schemaBreadcrumb["itemListElement"], bridgeSchemaListItem(schemaPosition++, "FloatPlanWizard", "https://floatplanwizard.com/"));
  arrayAppend(schemaBreadcrumb["itemListElement"], bridgeSchemaListItem(schemaPosition++, "Great Loop Bridges", "https://floatplanwizard.com/great-loop/bridges/"));
  if (len(taxonomyType) AND len(taxonomyName)) {
    arrayAppend(schemaBreadcrumb["itemListElement"], bridgeSchemaListItem(schemaPosition, pageHeading, canonicalUrl));
  }
  arrayAppend(schemaGraph, schemaBreadcrumb);

  structInsert(schemaPage, schemaTypeKey, "CollectionPage", true);
  structInsert(schemaPage, schemaIdKey, canonicalUrl & "##webpage", true);
  schemaPage["url"] = canonicalUrl;
  schemaPage["name"] = pageTitle;
  schemaPage["description"] = pageDescription;
  schemaPage["isPartOf"] = bridgeSchemaRef("https://floatplanwizard.com/##website");
  schemaPage["publisher"] = bridgeSchemaRef("https://floatplanwizard.com/##organization");
  schemaPage["breadcrumb"] = bridgeSchemaRef(canonicalUrl & "##breadcrumb");
  arrayAppend(schemaGraph, schemaPage);

  if (arrayLen(schemaBridgeRows)) {
    structInsert(schemaItemList, schemaTypeKey, "ItemList", true);
    structInsert(schemaItemList, schemaIdKey, canonicalUrl & "##bridges", true);
    schemaItemList["name"] = pageHeading;
    schemaItemList["itemListOrder"] = "https://schema.org/ItemListOrderAscending";
    schemaItemList["itemListElement"] = [];
    for (schemaBridgeIndex = 1; schemaBridgeIndex LTE arrayLen(schemaBridgeRows); schemaBridgeIndex++) {
      arrayAppend(schemaItemList["itemListElement"], bridgeSchemaListItem(
        schemaBridgeIndex,
        schemaBridgeRows[schemaBridgeIndex].bridge_name,
        "https://floatplanwizard.com/great-loop/bridges/" & bridgeSvc.normalizeSlug(schemaBridgeRows[schemaBridgeIndex].slug) & "/"
      ));
    }
    arrayAppend(schemaGraph, schemaItemList);
  }

  pageJsonLd = structNew("ordered");
  structInsert(pageJsonLd, schemaContextKey, "https://schema.org", true);
  structInsert(pageJsonLd, schemaGraphKey, schemaGraph, true);
  pageJsonLdText = replace(serializeJSON(pageJsonLd), "</", "<\/", "all");
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
  <cfif len(pageJsonLdText)>
    <script type="application/ld+json"><cfoutput>#pageJsonLdText#</cfoutput></script>
  </cfif>
  <link rel="stylesheet" href="<cfoutput>#request.fpwBase#</cfoutput>/assets/css/layout.css?v=20260620-page-width">
<link rel="stylesheet" href="<cfoutput>#request.fpwBase#</cfoutput>/assets/css/top-nav.css?v=20260814-featured-guides-layout-v1">
  <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" integrity="sha256-p4NxAoJBhIIN+hmNHrzRCf9tD/miZyoHS5obTRR9BMY=" crossorigin="">
  <link rel="stylesheet" href="<cfoutput>#request.fpwBase#</cfoutput>/assets/css/great-loop-bridges.css?v=20260707-nav-map-zindex">
  <cfinclude template="../includes/analytics_ga4.cfm">
  <cfinclude template="../includes/analytics_clarity.cfm">
  <cfinclude template="../includes/trustedsite.cfm">
</head>
<body class="fpw-bridge-body">
<cfinclude template="../includes/top_nav.cfm">

<main class="fpw-bridge-page">
  <section class="fpw-bridge-hero fpw-bridge-hero--library">
    <div class="fpw-bridge-shell">
      <p class="fpw-bridge-eyebrow">Great Loop planning reference</p>
      <h1><cfoutput>#encodeForHTML(pageHeading)#</cfoutput></h1>
      <p><cfoutput>#encodeForHTML(pageLede)#</cfoutput></p>
    </div>
  </section>

  <section class="fpw-bridge-shell fpw-bridge-stats" aria-label="Bridge library counts">
    <div class="fpw-bridge-stat"><strong><cfoutput>#numberFormat(stats.PUBLIC_ROWS)#</cfoutput></strong><span>Public planning records</span></div>
    <div class="fpw-bridge-stat"><strong><cfoutput>#numberFormat(stats.ROUTE_SEGMENT_COUNT)#</cfoutput></strong><span>Route segments</span></div>
    <div class="fpw-bridge-stat"><strong><cfoutput>#numberFormat(stats.WATERWAY_COUNT)#</cfoutput></strong><span>Waterways</span></div>
    <div class="fpw-bridge-stat"><strong><cfoutput>#numberFormat(stats.MISSING_COORDINATES_ROWS)#</cfoutput></strong><span>Rows missing coordinates</span></div>
  </section>

  <section class="fpw-bridge-shell fpw-bridge-cta" aria-label="Create a free float plan">
    <div>
      <h2>Planning a route with bridges?</h2>
      <p>Check bridge clearance, drawbridge details, and route timing before departure. Create a free float plan for your trip.</p>
      <div class="fpw-bridge-helper-links" aria-label="Bridge planning links">
        <a href="<cfoutput>#request.fpwBase#</cfoutput>/great-loop/locks/">Great Loop Locks</a>
        <a href="<cfoutput>#request.fpwBase#</cfoutput>/boat-fuel-calculator/">Boat Fuel Calculator</a>
        <a href="<cfoutput>#request.fpwBase#</cfoutput>/why-use-a-float-plan/">Why use a float plan?</a>
        <a href="#clearance-air-draft">Clearance basics</a>
        <a href="#fixed-vs-drawbridges">Drawbridge planning</a>
      </div>
    </div>
    <a class="fpw-cta fpw-cta-primary" href="<cfoutput>#request.fpwBase#</cfoutput>/app/join.cfm"><span>Plan Your Route</span><span class="fpw-cta-arrow" aria-hidden="true">&rarr;</span></a>
  </section>

  <nav class="fpw-bridge-shell fpw-bridge-breadcrumbs" aria-label="Breadcrumb">
    <a href="<cfoutput>#encodeForHTMLAttribute(bridgeLibraryUrl)#</cfoutput>">Great Loop Bridges</a>
    <cfif listFindNoCase("state,waterway,route", taxonomyType) AND len(taxonomyName)>
      <span>&rsaquo;</span>
      <span><cfoutput>#encodeForHTML(taxonomyName)#</cfoutput></span>
    </cfif>
  </nav>

  <section class="fpw-bridge-shell fpw-bridge-layout fpw-bridge-search-layout" aria-label="Bridge library search">
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
          <button type="submit" class="fpw-cta fpw-cta-primary"><span>Apply Filters</span></button>
          <a href="<cfoutput>#encodeForHTMLAttribute(bridgeLibraryUrl)#</cfoutput>" class="fpw-cta fpw-cta-primary"><span>Clear Filters</span></a>
        </div>
      </form>
      <p class="fpw-bridge-filter-status" data-bridge-filter-status aria-live="polite" hidden></p>
    </aside>

    <div class="fpw-bridge-main">
      <section class="fpw-bridge-panel" aria-label="Bridge map">
        <div class="fpw-bridge-map-toolbar">
          <div>
            <h2>Bridge Map</h2>
            <p data-bridge-result-summary><cfif isDefaultBridgeHubView><cfoutput>Showing #encodeForHTML(arrayLen(displayBridgeRows))# featured bridges. Use search or filters to explore the full library.</cfoutput><cfelse><cfoutput>#arrayLen(bridgeRows)# bridge planning record#arrayLen(bridgeRows) EQ 1 ? "" : "s"# match, with #arrayLen(mapRows)# map marker#arrayLen(mapRows) EQ 1 ? "" : "s"#.</cfoutput></cfif></p>
          </div>
        </div>
        <div id="fpwBridgeMap" class="fpw-bridge-map" aria-label="Great Loop bridge map"></div>
        <p class="fpw-bridge-empty-map" data-bridge-empty-map<cfif arrayLen(bridgeRows)> hidden</cfif>>No reviewed bridge records match the current filters.</p>
      </section>
    </div>
  </section>

  <section class="fpw-bridge-shell fpw-bridge-results" aria-label="Bridge results" data-bridge-results-shell<cfif isBridgeHubPage AND !isDefaultBridgeHubView> hidden</cfif>>
    <cfif !isBridgeHubPage>
      <div class="fpw-bridge-section-heading">
        <div>
          <h2><cfoutput>#pageHeading#</cfoutput></h2>
          <p>Full filtered bridge references for this taxonomy page.</p>
        </div>
      </div>
    </cfif>
    <div class="fpw-bridge-result-list" data-bridge-result-list<cfif !arrayLen(displayBridgeRows)> hidden</cfif>>
      <cfloop array="#displayBridgeRows#" index="bridgeItem">
        <cfset bridgeImage = bridgeSvc.getBridgeImageAsset(bridgeItem, request.fpwBase)>
        <cfset bridgeUrl = bridgeSvc.buildPublicBridgeUrl(bridgeItem.slug, request.fpwBase)>
        <cfset bridgeLocation = bridgeLocationLine(bridgeItem)>
        <cfset bridgeRoute = bridgeRouteLine(bridgeItem)>
        <cfset bridgeClearance = len(trim(toString(bridgeItem.vertical_clearance_closed_ft))) ? bridgeItem.vertical_clearance_closed_ft & " ft closed" : "Clearance not verified">
        <article class="fpw-bridge-card">
          <cfif bridgeImage.hasImage>
            <img src="<cfoutput>#encodeForHTMLAttribute(bridgeImage.thumbnailUrl)#</cfoutput>" alt="" loading="lazy" decoding="async">
          <cfelse>
            <img src="<cfoutput>#encodeForHTMLAttribute(bridgeImage.url)#</cfoutput>" alt="" loading="lazy" decoding="async">
          </cfif>
          <div>
            <h3><a href="<cfoutput>#encodeForHTMLAttribute(bridgeUrl)#</cfoutput>"><cfoutput>#encodeForHTML(bridgeItem.bridge_name)#</cfoutput></a></h3>
            <p><cfoutput>#encodeForHTML(bridgeRoute)#</cfoutput></p>
            <p><cfoutput>#encodeForHTML(bridgeLocation)#</cfoutput><cfif len(trim(toString(bridgeItem.mile_marker)))> - MM <cfoutput>#encodeForHTML(bridgeItem.mile_marker)#</cfoutput></cfif></p>
            <p><cfoutput>#encodeForHTML(displayText(bridgeItem.bridge_type, "Bridge type not verified"))#</cfoutput> - <cfoutput>#encodeForHTML(bridgeClearance)#</cfoutput></p>
            <div class="fpw-bridge-badges">
              <cfif bridgeSvc.boolLike(bridgeItem.is_drawbridge, false)>
                <span class="fpw-bridge-badge fpw-bridge-badge--warn">Drawbridge</span>
              </cfif>
              <cfif bridgeSvc.boolLike(bridgeItem.is_fixed, false)>
                <span class="fpw-bridge-badge">Fixed bridge</span>
              </cfif>
            </div>
          </div>
        </article>
      </cfloop>
    </div>
    <p class="fpw-bridge-empty-state" data-bridge-empty-list<cfif arrayLen(displayBridgeRows) OR isBridgeHubPage> hidden</cfif>>No reviewed bridge records match the current filters.</p>
  </section>

  <cfif isBridgeHubPage>
    <section class="fpw-bridge-shell fpw-bridge-browse" aria-label="Browse Great Loop bridges">
      <article class="fpw-bridge-browse-card">
        <h2>Browse by State / Province</h2>
        <div class="fpw-bridge-link-grid">
          <cfloop array="#facets.states#" index="opt">
            <a href="<cfoutput>#encodeForHTMLAttribute(bridgeLibraryUrl & "state/" & bridgeSvc.normalizeSlug(opt.value) & "/")#</cfoutput>"><cfoutput>#encodeForHTML(opt.label)#</cfoutput></a>
          </cfloop>
        </div>
      </article>
      <article class="fpw-bridge-browse-card">
        <h2>Browse by Waterway</h2>
        <div class="fpw-bridge-link-grid">
          <cfloop array="#facets.waterways#" index="opt">
            <a href="<cfoutput>#encodeForHTMLAttribute(bridgeLibraryUrl & "waterway/" & bridgeSvc.normalizeSlug(opt.value) & "/")#</cfoutput>"><cfoutput>#encodeForHTML(opt.label)#</cfoutput></a>
          </cfloop>
        </div>
      </article>
      <article class="fpw-bridge-browse-card">
        <h2>Browse by Route Segment</h2>
        <div class="fpw-bridge-link-grid">
          <cfloop array="#facets.routeSegments#" index="opt">
            <a href="<cfoutput>#encodeForHTMLAttribute(bridgeLibraryUrl & "route/" & bridgeSvc.normalizeSlug(opt.value) & "/")#</cfoutput>"><cfoutput>#encodeForHTML(opt.label)#</cfoutput></a>
          </cfloop>
        </div>
      </article>
    </section>
  </cfif>

  <section class="fpw-bridge-shell fpw-bridge-guide-cards" aria-label="Great Loop bridge planning guide">
    <article class="fpw-bridge-guide-card" id="why-bridge-planning">
      <span class="fpw-bridge-guide-icon" aria-hidden="true">
        <svg viewBox="0 0 48 48" focusable="false">
          <path d="M24 7 36 12v9c0 8.2-4.8 15.4-12 20-7.2-4.6-12-11.8-12-20v-9z"></path>
        </svg>
      </span>
      <h2>1. Why Bridge Planning Matters</h2>
      <ul>
        <li>Avoid delays, groundings, and unsafe transits.</li>
        <li>Save time and stress with verified information.</li>
        <li>Plan with confidence using current data.</li>
      </ul>
    </article>

    <article class="fpw-bridge-guide-card" id="fixed-vs-drawbridges">
      <span class="fpw-bridge-guide-icon" aria-hidden="true">
        <svg viewBox="0 0 48 48" focusable="false">
          <path d="M9 31h30"></path>
          <path d="M13 31c2.5-6 6.2-10 11-15 4.8 5 8.5 9 11 15"></path>
          <path d="M18 31v-7"></path>
          <path d="M30 31v-7"></path>
          <path d="M10 36c2.5 0 2.5 2 5 2s2.5-2 5-2 2.5 2 5 2 2.5-2 5-2 2.5 2 5 2 2.5-2 5-2"></path>
        </svg>
      </span>
      <h2>2. Fixed Bridges vs Drawbridges</h2>
      <ul>
        <li>Fixed bridges have set clearances.</li>
        <li>Drawbridges open on schedules or on request.</li>
        <li>Verify status and requirements before arrival.</li>
      </ul>
    </article>

    <article class="fpw-bridge-guide-card" id="clearance-air-draft">
      <span class="fpw-bridge-guide-icon" aria-hidden="true">
        <svg viewBox="0 0 48 48" focusable="false">
          <path d="M17 9v30"></path>
          <path d="m10 16 7-7 7 7"></path>
          <path d="m10 32 7 7 7-7"></path>
          <path d="M31 9v30"></path>
          <path d="m24 16 7-7 7 7"></path>
          <path d="m24 32 7 7 7-7"></path>
        </svg>
      </span>
      <h2>3. Clearance &amp; Air Draft</h2>
      <ul>
        <li>Clearance can change with water levels and conditions.</li>
        <li>Compare your vessel air draft to current clearances.</li>
        <li>Closed fields are planning references only.</li>
      </ul>
    </article>

    <article class="fpw-bridge-guide-card" id="verify-openings">
      <span class="fpw-bridge-guide-icon" aria-hidden="true">
        <svg viewBox="0 0 48 48" focusable="false">
          <path d="M15 10h18a3 3 0 0 1 3 3v25a3 3 0 0 1-3 3H15a3 3 0 0 1-3-3V13a3 3 0 0 1 3-3z"></path>
          <path d="M19 8h10v6H19z"></path>
          <path d="m18 27 4 4 8-10"></path>
        </svg>
      </span>
      <h2>4. Verify Openings Before Transit</h2>
      <ul>
        <li>Check opening schedules, restrictions, and notices.</li>
        <li>Confirm with official charts, signage, and local updates.</li>
        <li>Treat phone/VHF info as starting points, not final.</li>
      </ul>
    </article>

    <article class="fpw-bridge-guide-card" id="contact-vhf-planning">
      <span class="fpw-bridge-guide-icon" aria-hidden="true">
        <svg viewBox="0 0 48 48" focusable="false">
          <rect x="16" y="8" width="16" height="32" rx="3"></rect>
          <path d="M20 14h8"></path>
          <path d="M20 20h8"></path>
          <circle cx="24" cy="31" r="5"></circle>
          <path d="M24 26v5l3 2"></path>
        </svg>
      </span>
      <h2>5. Contact &amp; VHF Planning</h2>
      <ul>
        <li>Note bridge tenders and operator contacts.</li>
        <li>Use VHF channels for requests and updates.</li>
        <li>Have backups in case phone service is unavailable.</li>
      </ul>
    </article>

    <article class="fpw-bridge-guide-card" id="timing-restrictions">
      <span class="fpw-bridge-guide-icon" aria-hidden="true">
        <svg viewBox="0 0 48 48" focusable="false">
          <circle cx="24" cy="24" r="16"></circle>
          <path d="M24 14v11l8 5"></path>
        </svg>
      </span>
      <h2>6. Timing, Water Levels &amp; Restrictions</h2>
      <ul>
        <li>Water levels affect clearance and bridge operation.</li>
        <li>Consider tides, currents, traffic, and daylight.</li>
        <li>Watch for maintenance, weather, and local restrictions.</li>
      </ul>
    </article>

    <article class="fpw-bridge-guide-card" id="bridge-planning-checklist">
      <span class="fpw-bridge-guide-icon" aria-hidden="true">
        <svg viewBox="0 0 48 48" focusable="false">
          <circle cx="16" cy="15" r="3"></circle>
          <path d="M22 15h12"></path>
          <circle cx="16" cy="24" r="3"></circle>
          <path d="M22 24h12"></path>
          <circle cx="16" cy="33" r="3"></circle>
          <path d="M22 33h12"></path>
        </svg>
      </span>
      <h2>7. Bridge Planning Checklist</h2>
      <ul class="fpw-bridge-checklist">
        <li>Compare air draft vs clearance</li>
        <li>Verify bridge status &amp; type</li>
        <li>Check water levels &amp; trends</li>
        <li>Confirm schedules &amp; openings</li>
        <li>Note contacts &amp; VHF channels</li>
        <li>Plan timing &amp; backup options</li>
      </ul>
    </article>

    <article class="fpw-bridge-guide-card" id="quick-bridge-faqs">
      <span class="fpw-bridge-guide-icon" aria-hidden="true">
        <svg viewBox="0 0 48 48" focusable="false">
          <circle cx="24" cy="24" r="16"></circle>
          <path d="M19 20a5 5 0 0 1 10 1c0 4-5 4-5 8"></path>
          <path d="M24 35h.01"></path>
        </svg>
      </span>
      <h2>8. Quick Bridge FAQs</h2>
      <ul>
        <li>Can I rely on listed clearances? No, always verify current data.</li>
        <li>What is an air-draft concern? When clearance is close to your vessel height.</li>
        <li>Do schedules change? Yes, confirm before arrival.</li>
      </ul>
    </article>
  </section>

  <section class="fpw-bridge-shell fpw-bridge-awareness" aria-label="Bridge planning awareness">
    <div class="fpw-bridge-disclaimer">
      <strong>Planning awareness only:</strong>
      Bridge information is provided for planning awareness only. Always verify current bridge status, clearance, water levels, bridge schedules, opening restrictions, Local Notices to Mariners, bridge signage, and official charts before transit. FloatPlanWizard is not a navigation authority.
    </div>
  </section>

</main>

<cfinclude template="../includes/footer.cfm">
<script id="fpwBridgeMapData" type="application/json"><cfoutput>#serializeJSON(mapRows)#</cfoutput></script>
<script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js" integrity="sha256-20nQCchB9co0qIjJZRGuk2/Z9VM+kNiyxNV1lvTlZBo=" crossorigin=""></script>
<script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/maps/leaflet-noaa-waypoint-map.js?v=20260619-nautical-charts"></script>
<script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/app/great-loop-bridges.js?v=20260619-noaa-charts"></script>
</body>
</html>
