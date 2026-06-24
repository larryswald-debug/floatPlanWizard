<cfprocessingdirective pageencoding="utf-8">
<cfsetting showdebugoutput="false" requesttimeout="30">
<cfcontent type="text/html; charset=utf-8">
<cfinclude template="../includes/fpw_base_path.cfm">

<cfscript>
try {
  anchorageSvc = createObject("component", "api.v1.GreatLoopAnchoragesService").init();
} catch (any svcPathError) {
  anchorageSvc = createObject("component", "fpw.api.v1.GreatLoopAnchoragesService").init();
}

filters = {
  "q" = structKeyExists(url, "q") ? trim(toString(url.q)) : "",
  "locationGroup" = structKeyExists(url, "locationGroup") ? trim(toString(url.locationGroup)) : "",
  "waterway" = structKeyExists(url, "waterway") ? trim(toString(url.waterway)) : "",
  "stateProvince" = structKeyExists(url, "stateProvince") ? trim(toString(url.stateProvince)) : "",
  "country" = structKeyExists(url, "country") ? trim(toString(url.country)) : "",
  "anchorageType" = structKeyExists(url, "anchorageType") ? trim(toString(url.anchorageType)) : "",
  "publicStatus" = structKeyExists(url, "publicStatus") ? trim(toString(url.publicStatus)) : "",
  "limit" = "300"
};

libraryUrl = request.fpwBase & "/great-loop/anchorages/";
canonicalBase = "https://floatplanwizard.com/great-loop/anchorages/";
taxonomyType = structKeyExists(request, "fpwAnchorageTaxonomyType") ? request.fpwAnchorageTaxonomyType : "";
taxonomyName = structKeyExists(request, "fpwAnchorageTaxonomyName") ? request.fpwAnchorageTaxonomyName : "";
taxonomyCount = structKeyExists(request, "fpwAnchorageTaxonomyCount") ? request.fpwAnchorageTaxonomyCount : 0;
canonicalUrl = structKeyExists(request, "fpwAnchorageTaxonomyCanonicalUrl") ? request.fpwAnchorageTaxonomyCanonicalUrl : canonicalBase;

model = anchorageSvc.getLibraryModel(filters);
anchorageRows = model.ANCHORAGES;
stats = model.STATS;
facets = model.FACETS;
mapRows = [];
isHubRoute = !len(taxonomyType);
isTaxonomyRoute = len(taxonomyType) AND taxonomyType NEQ "not-found";
taxonomyParentLocationGroup = "";
taxonomyParentLocationCanonicalUrl = "";
if (taxonomyType EQ "waterway" AND arrayLen(anchorageRows)) {
  taxonomyLocationGroups = [];
  taxonomyLocationGroupSeen = {};
  for (taxonomyRow in anchorageRows) {
    taxonomyRowLocationGroup = trim(toString(isNull(taxonomyRow.location_group) ? "" : taxonomyRow.location_group));
    if (len(taxonomyRowLocationGroup) AND !structKeyExists(taxonomyLocationGroupSeen, lCase(taxonomyRowLocationGroup))) {
      taxonomyLocationGroupSeen[lCase(taxonomyRowLocationGroup)] = true;
      arrayAppend(taxonomyLocationGroups, taxonomyRowLocationGroup);
    }
  }
  if (arrayLen(taxonomyLocationGroups) EQ 1) {
    taxonomyParentLocationGroup = taxonomyLocationGroups[1];
    taxonomyParentLocationCanonicalUrl = canonicalBase & "location/" & anchorageSvc.normalizeSlug(taxonomyParentLocationGroup) & "/";
  }
}
pageTitle = "Great Loop and Eastern U.S. Anchorages | FloatPlanWizard";
pageDescription = "Explore Great Loop and Eastern U.S. anchorage reference points for recreational boating trip planning, including ICW, Chesapeake, Florida, Gulf Coast, Great Lakes, and inland river anchorages. Verify current charts and local rules before anchoring.";
pageHeading = "Great Loop and Eastern U.S. Anchorages";
pageLede = "Explore public anchorage reference points along the Great Loop, Atlantic ICW, Chesapeake Bay, Florida, Gulf Coast, Great Lakes, and inland river cruising routes. Use this library for trip planning, route awareness, and float plan preparation -- then verify current charts, weather, local rules, and observed conditions before anchoring.";

if (taxonomyType EQ "location" AND len(taxonomyName)) {
  pageTitle = taxonomyName & " Anchorages | FloatPlanWizard";
  pageDescription = "Browse public anchorage reference points in " & taxonomyName & " for recreational boating trip planning. Verify current charts, weather, local rules, and conditions before anchoring.";
  pageHeading = taxonomyName & " Anchorages";
  pageLede = "Browse " & taxonomyCount & " published anchorage reference points in " & taxonomyName & " for route awareness and float plan preparation.";
} else if (taxonomyType EQ "waterway" AND len(taxonomyName)) {
  pageTitle = taxonomyName & " Anchorages | FloatPlanWizard";
  pageDescription = "Browse public anchorage reference points on " & taxonomyName & " for recreational boating trip planning. Verify current charts and local rules before anchoring.";
  pageHeading = taxonomyName & " Anchorages";
  pageLede = "Browse " & taxonomyCount & " published anchorage reference points on " & taxonomyName & " with location, type, holding, protection, and planning context where available.";
} else if (taxonomyType EQ "state" AND len(taxonomyName)) {
  pageTitle = taxonomyName & " Anchorages | FloatPlanWizard";
  pageDescription = "Browse public anchorage reference points in " & taxonomyName & " for recreational boating trip planning. Verify current charts and local rules before anchoring.";
  pageHeading = taxonomyName & " Anchorages";
  pageLede = "Browse " & taxonomyCount & " published anchorage reference points in " & taxonomyName & " for trip planning and route awareness.";
} else if (taxonomyType EQ "country" AND len(taxonomyName)) {
  pageTitle = taxonomyName & " Anchorages | FloatPlanWizard";
  pageDescription = "Browse public anchorage reference points in " & taxonomyName & " for recreational boating trip planning. Verify current charts and local rules before anchoring.";
  pageHeading = taxonomyName & " Anchorages";
  pageLede = "Browse " & taxonomyCount & " published anchorage reference points in " & taxonomyName & " for trip planning and route awareness.";
} else if (taxonomyType EQ "type" AND len(taxonomyName)) {
  pageTitle = taxonomyName & " Anchorages | FloatPlanWizard";
  pageDescription = "Browse " & taxonomyName & " anchorage reference points for recreational boating trip planning. Verify current charts and local rules before anchoring.";
  pageHeading = taxonomyName & " Anchorages";
  pageLede = "Browse " & taxonomyCount & " published " & taxonomyName & " anchorage reference points with available waterway, location, holding, and protection context.";
} else if (taxonomyType EQ "not-found") {
  pageTitle = "Anchorage Page Not Found | FloatPlanWizard";
  pageDescription = "The requested anchorage taxonomy page could not be found.";
  pageHeading = taxonomyName;
  pageLede = "The requested anchorage page could not be found. Browse the main anchorage library to find published planning references.";
  anchorageRows = [];
  mapRows = [];
}

function selectedAttr(required any leftValue, required any rightValue) {
  return compareNoCase(trim(toString(arguments.leftValue)), trim(toString(arguments.rightValue))) EQ 0 ? " selected" : "";
}

function displayText(any value, string fallback="Not listed") {
  var txt = isNull(arguments.value) ? "" : trim(toString(arguments.value));
  return len(txt) ? txt : arguments.fallback;
}

function isLocalDevHost() {
  var hostName = "";
  if (structKeyExists(cgi, "http_host")) {
    hostName = lCase(trim(toString(cgi.http_host)));
  } else if (structKeyExists(cgi, "server_name")) {
    hostName = lCase(trim(toString(cgi.server_name)));
  }
  return hostName EQ "localhost"
    OR left(hostName, 10) EQ "localhost:"
    OR hostName EQ "127.0.0.1"
    OR left(hostName, 10) EQ "127.0.0.1:"
    OR hostName EQ "[::1]"
    OR left(hostName, 6) EQ "[::1]:";
}

function detailUrl(required string slugValue) {
  var slug = anchorageSvc.normalizeSlug(arguments.slugValue);
  if (isLocalDevHost()) {
    return libraryUrl & "index.cfm?slug=" & urlEncodedFormat(slug);
  }
  return libraryUrl & slug & "/";
}

function taxonomyUrl(required string typeName, required string value) {
  var slug = anchorageSvc.normalizeSlug(arguments.value);
  var taxonomyParams = {
    "location" = "locationSlug",
    "waterway" = "waterwaySlug",
    "state" = "stateSlug",
    "country" = "countrySlug",
    "type" = "typeSlug"
  };
  var normalizedType = lCase(trim(arguments.typeName));
  if (isLocalDevHost() AND structKeyExists(taxonomyParams, normalizedType)) {
    return libraryUrl & "index.cfm?" & taxonomyParams[normalizedType] & "=" & urlEncodedFormat(slug);
  }
  return libraryUrl & normalizedType & "/" & slug & "/";
}

taxonomyParentLocationUrl = len(taxonomyParentLocationGroup) ? taxonomyUrl("location", taxonomyParentLocationGroup) : "";

function locationLine(required struct anchorageItem) {
  var pieces = [];
  if (len(trim(toString(arguments.anchorageItem.nearest_city)))) arrayAppend(pieces, trim(toString(arguments.anchorageItem.nearest_city)));
  if (len(trim(toString(arguments.anchorageItem.state_province)))) arrayAppend(pieces, trim(toString(arguments.anchorageItem.state_province)));
  if (len(trim(toString(arguments.anchorageItem.country)))) arrayAppend(pieces, trim(toString(arguments.anchorageItem.country)));
  return arrayLen(pieces) ? arrayToList(pieces, ", ") : "Location not listed";
}

for (anchorageItem in anchorageRows) {
  if (isNumeric(anchorageItem.latitude) AND isNumeric(anchorageItem.longitude)) {
    arrayAppend(mapRows, {
      "anchorage_id" = anchorageItem.anchorage_id,
      "slug" = anchorageItem.slug,
      "anchorage_name" = anchorageItem.anchorage_name,
      "nearest_city" = anchorageItem.nearest_city,
      "state_province" = anchorageItem.state_province,
      "country" = anchorageItem.country,
      "location_group" = anchorageItem.location_group,
      "waterway" = anchorageItem.waterway,
      "latitude" = anchorageItem.latitude,
      "longitude" = anchorageItem.longitude,
      "anchorage_type" = anchorageItem.anchorage_type,
      "protection" = anchorageItem.protection,
      "holding" = anchorageItem.holding,
      "public_status" = anchorageItem.public_status,
      "url" = detailUrl(anchorageItem.slug)
    });
  }
}

schemaAtKey = chr(64);
schemaTypeKey = schemaAtKey & "type";
schemaIdKey = schemaAtKey & "id";
schemaContextKey = schemaAtKey & "context";
schemaGraphKey = schemaAtKey & "graph";
schemaGraph = [];

function schemaRef(required string idValue) {
  var out = structNew("ordered");
  structInsert(out, schemaIdKey, arguments.idValue, true);
  return out;
}

orgSchema = structNew("ordered");
structInsert(orgSchema, schemaIdKey, "https://floatplanwizard.com/##organization", true);
structInsert(orgSchema, schemaTypeKey, "Organization", true);
orgSchema["name"] = "FloatPlanWizard";
orgSchema["url"] = "https://floatplanwizard.com/";
arrayAppend(schemaGraph, orgSchema);

webSiteSchema = structNew("ordered");
structInsert(webSiteSchema, schemaIdKey, "https://floatplanwizard.com/##website", true);
structInsert(webSiteSchema, schemaTypeKey, "WebSite", true);
webSiteSchema["name"] = "FloatPlanWizard";
webSiteSchema["url"] = "https://floatplanwizard.com/";
webSiteSchema["publisher"] = schemaRef("https://floatplanwizard.com/##organization");
arrayAppend(schemaGraph, webSiteSchema);

breadcrumbSchema = structNew("ordered");
structInsert(breadcrumbSchema, schemaTypeKey, "BreadcrumbList", true);
structInsert(breadcrumbSchema, schemaIdKey, canonicalUrl & "##breadcrumb", true);
breadcrumbItems = [
  { "position" = 1, "name" = "FloatPlanWizard", "item" = "https://floatplanwizard.com/" },
  { "position" = 2, "name" = "Great Loop Anchorages", "item" = canonicalBase }
];
if (isTaxonomyRoute AND len(taxonomyName)) {
  if (taxonomyType EQ "waterway" AND len(taxonomyParentLocationGroup) AND len(taxonomyParentLocationCanonicalUrl)) {
    arrayAppend(breadcrumbItems, {
      "position" = arrayLen(breadcrumbItems) + 1,
      "name" = taxonomyParentLocationGroup,
      "item" = taxonomyParentLocationCanonicalUrl
    });
  }
  arrayAppend(breadcrumbItems, { "position" = arrayLen(breadcrumbItems) + 1, "name" = taxonomyName, "item" = canonicalUrl });
}
breadcrumbSchema["itemListElement"] = [];
for (crumb in breadcrumbItems) {
  crumbItem = structNew("ordered");
  structInsert(crumbItem, schemaTypeKey, "ListItem", true);
  crumbItem["position"] = crumb.position;
  crumbItem["name"] = crumb.name;
  crumbItem["item"] = crumb.item;
  arrayAppend(breadcrumbSchema["itemListElement"], crumbItem);
}
arrayAppend(schemaGraph, breadcrumbSchema);

pageSchema = structNew("ordered");
structInsert(pageSchema, schemaIdKey, canonicalUrl & "##webpage", true);
structInsert(pageSchema, schemaTypeKey, isHubRoute ? "CollectionPage" : "WebPage", true);
pageSchema["name"] = pageTitle;
pageSchema["description"] = pageDescription;
pageSchema["url"] = canonicalUrl;
pageSchema["isPartOf"] = schemaRef("https://floatplanwizard.com/##website");
pageSchema["breadcrumb"] = schemaRef(canonicalUrl & "##breadcrumb");
arrayAppend(schemaGraph, pageSchema);

itemListSchema = structNew("ordered");
structInsert(itemListSchema, schemaTypeKey, "ItemList", true);
itemListSchema["itemListElement"] = [];
schemaSampleLimit = min(arrayLen(anchorageRows), 6);
for (schemaIndex = 1; schemaIndex LTE schemaSampleLimit; schemaIndex++) {
  listItem = structNew("ordered");
  structInsert(listItem, schemaTypeKey, "ListItem", true);
  listItem["position"] = schemaIndex;
  listItem["name"] = anchorageRows[schemaIndex].anchorage_name;
  listItem["url"] = "https://floatplanwizard.com/great-loop/anchorages/" & anchorageRows[schemaIndex].slug & "/";
  arrayAppend(itemListSchema["itemListElement"], listItem);
}
arrayAppend(schemaGraph, itemListSchema);

schemaRoot = structNew("ordered");
structInsert(schemaRoot, schemaContextKey, "https://schema.org", true);
structInsert(schemaRoot, schemaGraphKey, schemaGraph, true);
pageJsonLdText = serializeJSON(schemaRoot);
</cfscript>

<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <link rel="icon" href="data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 64 64'%3E%3Crect width='64' height='64' rx='14' fill='%2306131d'/%3E%3Cpath d='M32 10v44M10 32h44M17 17l30 30M47 17 17 47' stroke='%2321f3ee' stroke-width='5' stroke-linecap='round'/%3E%3Ccircle cx='32' cy='32' r='14' fill='none' stroke='%2367d8ff' stroke-width='5'/%3E%3Ccircle cx='32' cy='32' r='5' fill='%23ffd18a'/%3E%3C/svg%3E">
  <title><cfoutput>#encodeForHTML(pageTitle)#</cfoutput></title>
  <meta name="description" content="<cfoutput>#encodeForHTMLAttribute(pageDescription)#</cfoutput>">
  <link rel="canonical" href="<cfoutput>#encodeForHTMLAttribute(canonicalUrl)#</cfoutput>">
  <meta property="og:type" content="website">
  <meta property="og:site_name" content="FloatPlanWizard">
  <meta property="og:title" content="<cfoutput>#encodeForHTMLAttribute(pageTitle)#</cfoutput>">
  <meta property="og:description" content="<cfoutput>#encodeForHTMLAttribute(pageDescription)#</cfoutput>">
  <meta property="og:url" content="<cfoutput>#encodeForHTMLAttribute(canonicalUrl)#</cfoutput>">
  <meta name="twitter:card" content="summary_large_image">
  <meta name="twitter:title" content="<cfoutput>#encodeForHTMLAttribute(pageTitle)#</cfoutput>">
  <meta name="twitter:description" content="<cfoutput>#encodeForHTMLAttribute(pageDescription)#</cfoutput>">
  <script type="application/ld+json"><cfoutput>#pageJsonLdText#</cfoutput></script>
  <link rel="stylesheet" href="<cfoutput>#request.fpwBase#</cfoutput>/assets/css/layout.css?v=20260620-page-width">
  <link rel="stylesheet" href="<cfoutput>#request.fpwBase#</cfoutput>/assets/css/top-nav.css?v=20260530-nav-cta">
  <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" integrity="sha256-p4NxAoJBhIIN+hmNHrzRCf9tD/miZyoHS5obTRR9BMY=" crossorigin="">
  <link rel="stylesheet" href="<cfoutput>#request.fpwBase#</cfoutput>/assets/css/great-loop-anchorages.css?v=20260622-anchorages">
  <cfinclude template="../includes/analytics_ga4.cfm">
  <cfinclude template="../includes/analytics_clarity.cfm">
  <cfinclude template="../includes/trustedsite.cfm">
</head>
<body id="top" class="fpw-anchorage-body">
<cfinclude template="../includes/top_nav.cfm">

<main class="fpw-anchorage-page">
  <section class="fpw-anchorage-hero">
    <div class="fpw-anchorage-shell">
      <p class="fpw-anchorage-eyebrow">Public Anchorage Reference</p>
      <h1><cfoutput>#encodeForHTML(pageHeading)#</cfoutput></h1>
      <p><cfoutput>#encodeForHTML(pageLede)#</cfoutput></p>
      <p class="fpw-anchorage-note">This is a planning reference only and is not a navigation product.</p>
    </div>
  </section>

  <section class="fpw-anchorage-stats fpw-anchorage-shell" aria-label="Anchorage library summary">
    <div><strong><cfoutput>#encodeForHTML(stats.PUBLIC_ROWS)#</cfoutput></strong><span>Published anchorages</span></div>
    <div><strong><cfoutput>#encodeForHTML(stats.LOCATION_GROUP_COUNT)#</cfoutput></strong><span>Location groups</span></div>
    <div><strong><cfoutput>#encodeForHTML(stats.STATE_COUNT)#</cfoutput></strong><span>States / provinces</span></div>
    <div><strong><cfoutput>#encodeForHTML(stats.WATERWAY_COUNT)#</cfoutput></strong><span>Waterways</span></div>
  </section>

  <section class="fpw-anchorage-cta fpw-anchorage-panel fpw-anchorage-shell" aria-labelledby="fpwAnchorageCtaTitle">
    <div>
      <p class="fpw-anchorage-eyebrow">Plan With FPW</p>
      <h2 id="fpwAnchorageCtaTitle">Before You Leave The Dock</h2>
      <p>Before you leave the dock, build a float plan that records your route, passengers, vessel details, and return plan.</p>
    </div>
    <a class="fpw-anchorage-btn fpw-anchorage-btn--primary" href="<cfoutput>#request.fpwBase#</cfoutput>/app/join.cfm">Create a Float Plan</a>
  </section>

  <nav class="fpw-anchorage-breadcrumbs fpw-anchorage-shell" aria-label="Breadcrumb">
    <a href="<cfoutput>#encodeForHTMLAttribute(libraryUrl)#</cfoutput>">Great Loop Anchorages</a>
    <cfif isTaxonomyRoute AND len(taxonomyName)>
      <cfif taxonomyType EQ "waterway" AND len(taxonomyParentLocationGroup) AND len(taxonomyParentLocationUrl)>
        <span aria-hidden="true">&rsaquo;</span>
        <a href="<cfoutput>#encodeForHTMLAttribute(taxonomyParentLocationUrl)#</cfoutput>"><cfoutput>#encodeForHTML(taxonomyParentLocationGroup)#</cfoutput></a>
      </cfif>
      <span aria-hidden="true">&rsaquo;</span>
      <span><cfoutput>#encodeForHTML(taxonomyName)#</cfoutput></span>
    </cfif>
  </nav>

  <section class="fpw-anchorage-finder fpw-anchorage-shell" id="fpwAnchorageFinder" aria-labelledby="fpwAnchorageFinderTitle">
    <aside class="fpw-anchorage-panel fpw-anchorage-filters">
      <h2 id="fpwAnchorageFinderTitle">Find Anchorages</h2>
      <form method="get" action="<cfoutput>#encodeForHTMLAttribute(libraryUrl)#</cfoutput>" data-anchorage-filter-form data-anchorage-api-endpoint="<cfoutput>#request.fpwApiBase#</cfoutput>/greatLoopAnchorages.cfc?method=handle&returnFormat=json" data-anchorage-page-url="<cfoutput>#encodeForHTMLAttribute(libraryUrl)#</cfoutput>" data-anchorage-detail-url-base="<cfoutput>#encodeForHTMLAttribute(libraryUrl)#</cfoutput>">
        <label class="fpw-anchorage-field">
          <span>Keyword</span>
          <input type="search" name="q" value="<cfoutput>#encodeForHTMLAttribute(filters.q)#</cfoutput>" placeholder="Name, city, waterway, holding, notes" data-anchorage-search-input>
        </label>
        <label class="fpw-anchorage-field">
          <span>Location Group</span>
          <select name="locationGroup">
            <option value="">All</option>
            <cfloop array="#facets.locationGroups#" index="facet"><cfoutput><option value="#encodeForHTMLAttribute(facet.value)#"#selectedAttr(filters.locationGroup, facet.value)#>#encodeForHTML(facet.label)#</option></cfoutput></cfloop>
          </select>
        </label>
        <label class="fpw-anchorage-field">
          <span>Waterway</span>
          <select name="waterway">
            <option value="">All</option>
            <cfloop array="#facets.waterways#" index="facet"><cfoutput><option value="#encodeForHTMLAttribute(facet.value)#"#selectedAttr(filters.waterway, facet.value)#>#encodeForHTML(facet.label)#</option></cfoutput></cfloop>
          </select>
        </label>
        <label class="fpw-anchorage-field">
          <span>State / Province</span>
          <select name="stateProvince">
            <option value="">All</option>
            <cfloop array="#facets.states#" index="facet"><cfoutput><option value="#encodeForHTMLAttribute(facet.value)#"#selectedAttr(filters.stateProvince, facet.value)#>#encodeForHTML(facet.label)#</option></cfoutput></cfloop>
          </select>
        </label>
        <label class="fpw-anchorage-field">
          <span>Country</span>
          <select name="country">
            <option value="">All</option>
            <cfloop array="#facets.countries#" index="facet"><cfoutput><option value="#encodeForHTMLAttribute(facet.value)#"#selectedAttr(filters.country, facet.value)#>#encodeForHTML(facet.label)#</option></cfoutput></cfloop>
          </select>
        </label>
        <label class="fpw-anchorage-field">
          <span>Anchorage Type</span>
          <select name="anchorageType">
            <option value="">All</option>
            <cfloop array="#facets.anchorageTypes#" index="facet"><cfoutput><option value="#encodeForHTMLAttribute(facet.value)#"#selectedAttr(filters.anchorageType, facet.value)#>#encodeForHTML(facet.label)#</option></cfoutput></cfloop>
          </select>
        </label>
        <label class="fpw-anchorage-field">
          <span>Public Status</span>
          <select name="publicStatus">
            <option value="">All</option>
            <cfloop array="#facets.publicStatuses#" index="facet"><cfoutput><option value="#encodeForHTMLAttribute(facet.value)#"#selectedAttr(filters.publicStatus, facet.value)#>#encodeForHTML(facet.label)#</option></cfoutput></cfloop>
          </select>
        </label>
        <div class="fpw-anchorage-filter-actions">
          <button type="submit" class="fpw-anchorage-btn fpw-anchorage-btn--primary" data-anchorage-apply>Apply Filters</button>
          <a class="fpw-anchorage-btn" href="<cfoutput>#encodeForHTMLAttribute(libraryUrl)#</cfoutput>" data-anchorage-clear>Clear Filters</a>
        </div>
        <p class="fpw-anchorage-filter-status" data-anchorage-filter-status aria-live="polite" hidden></p>
      </form>
    </aside>

    <div class="fpw-anchorage-panel fpw-anchorage-map-card">
      <div class="fpw-anchorage-map-toolbar">
        <div>
          <h2>Anchorage Map</h2>
          <p data-anchorage-result-summary><cfoutput>#arrayLen(anchorageRows)#</cfoutput> published anchorage references match the current filters.</p>
        </div>
        <div class="fpw-anchorage-view-toggle" role="group" aria-label="View type">
          <button type="button" class="is-active" data-anchorage-view-button="map">Map</button>
          <button type="button" data-anchorage-view-button="list">List</button>
        </div>
      </div>
      <label class="fpw-anchorage-noaa-toggle">
        <input type="checkbox" data-noaa-chart-toggle>
        <span>Show NOAA nautical chart layer</span>
      </label>
      <p class="fpw-anchorage-noaa-help">NOAA chart layer is for planning context only and is not a substitute for official navigation.</p>

      <div class="fpw-anchorage-map-view" data-anchorage-view-panel="map">
        <div id="fpwAnchorageMap" class="fpw-anchorage-map" aria-label="Great Loop and Eastern U.S. anchorage map"></div>
        <p class="fpw-anchorage-empty-map" data-anchorage-empty-map<cfif arrayLen(mapRows)> hidden</cfif>>No anchorage map markers match these filters.</p>
      </div>

      <div class="fpw-anchorage-list-view" data-anchorage-view-panel="list" hidden>
        <div class="fpw-anchorage-result-list" data-anchorage-result-list<cfif NOT arrayLen(anchorageRows)> hidden</cfif>>
          <cfloop array="#anchorageRows#" index="anchorageItem">
            <cfoutput>
              <article class="fpw-anchorage-result-card" data-anchorage-card data-slug="#encodeForHTMLAttribute(anchorageItem.slug)#">
                <div>
                  <h3><a href="#encodeForHTMLAttribute(detailUrl(anchorageItem.slug))#">#encodeForHTML(anchorageItem.anchorage_name)#</a></h3>
                  <p>#encodeForHTML(locationLine(anchorageItem))#</p>
                  <p>#encodeForHTML(displayText(anchorageItem.location_group))#<cfif len(anchorageItem.waterway)> &bull; #encodeForHTML(anchorageItem.waterway)#</cfif></p>
                </div>
                <dl>
                  <div><dt>Type</dt><dd>#encodeForHTML(displayText(anchorageItem.anchorage_type))#</dd></div>
                  <div><dt>Holding</dt><dd>#encodeForHTML(displayText(anchorageItem.holding))#</dd></div>
                  <div><dt>Protection</dt><dd>#encodeForHTML(displayText(anchorageItem.protection))#</dd></div>
                  <div><dt>Status</dt><dd>#encodeForHTML(displayText(anchorageItem.public_status, "Planning reference"))#</dd></div>
                </dl>
              </article>
            </cfoutput>
          </cfloop>
        </div>
        <div class="fpw-anchorage-empty-state" data-anchorage-empty-list<cfif arrayLen(anchorageRows)> hidden</cfif>>
          <h3>No anchorages match these filters.</h3>
          <p>No anchorages match these filters. Try clearing the keyword or selecting a broader location.</p>
        </div>
      </div>
    </div>
  </section>

  <section class="fpw-anchorage-browse fpw-anchorage-shell" aria-label="Browse anchorages">
    <article class="fpw-anchorage-panel">
      <h2>Browse by Location Group</h2>
      <div class="fpw-anchorage-link-grid">
        <cfif arrayLen(facets.locationGroups)><cfloop array="#facets.locationGroups#" index="facet"><cfoutput><a href="#encodeForHTMLAttribute(taxonomyUrl("location", facet.value))#">#encodeForHTML(facet.value)# <span>#encodeForHTML(facet.count)#</span></a></cfoutput></cfloop><cfelse><p>Location group browsing appears after reviewed rows are published.</p></cfif>
      </div>
    </article>
    <article class="fpw-anchorage-panel">
      <h2>Browse by Waterway</h2>
      <div class="fpw-anchorage-link-grid">
        <cfif arrayLen(facets.waterways)><cfloop array="#facets.waterways#" index="facet"><cfoutput><a href="#encodeForHTMLAttribute(taxonomyUrl("waterway", facet.value))#">#encodeForHTML(facet.value)# <span>#encodeForHTML(facet.count)#</span></a></cfoutput></cfloop><cfelse><p>Waterway browsing appears after reviewed rows are published.</p></cfif>
      </div>
    </article>
    <article class="fpw-anchorage-panel">
      <h2>Browse by State/Province</h2>
      <div class="fpw-anchorage-link-grid">
        <cfif arrayLen(facets.states)><cfloop array="#facets.states#" index="facet"><cfoutput><a href="#encodeForHTMLAttribute(taxonomyUrl("state", facet.value))#">#encodeForHTML(facet.value)# <span>#encodeForHTML(facet.count)#</span></a></cfoutput></cfloop><cfelse><p>State browsing appears after reviewed rows are published.</p></cfif>
      </div>
    </article>
  </section>

  <cfif isTaxonomyRoute>
    <section class="fpw-anchorage-panel fpw-anchorage-taxonomy fpw-anchorage-shell" aria-labelledby="fpwAnchorageTaxonomyTitle">
      <h2 id="fpwAnchorageTaxonomyTitle"><cfoutput>Anchorages in #encodeForHTML(taxonomyName)#</cfoutput></h2>
      <p><cfoutput>#encodeForHTML(taxonomyCount)# published anchorage reference points are available for this view.</cfoutput></p>
    </section>
  </cfif>

  <section class="fpw-anchorage-learning fpw-anchorage-shell" aria-labelledby="fpwAnchorageLearningTitle">
    <div class="fpw-anchorage-section-heading">
      <h2 id="fpwAnchorageLearningTitle">Plan the stop, then verify before you anchor</h2>
      <p>Great Loop and Eastern U.S. anchorages can be useful for planning overnight stops, weather delays, staging before locks or bridges, and building safer route-backed float plans.</p>
    </div>
    <article class="fpw-anchorage-panel"><h3>Check current charts</h3><p>Anchorages, depths, no-anchor zones, mooring fields, and local restrictions can change.</p></article>
    <article class="fpw-anchorage-panel"><h3>Watch weather and exposure</h3><p>A protected anchorage in one wind direction may be uncomfortable or unsafe in another.</p></article>
    <article class="fpw-anchorage-panel"><h3>Know your exit plan</h3><p>Review nearby channels, bridges, shoals, traffic, and alternate stops before committing.</p></article>
    <article class="fpw-anchorage-panel"><h3>Leave a float plan</h3><p>If you are delayed, someone ashore should know your route, passengers, vessel details, and expected return.</p></article>
  </section>

  <section class="fpw-anchorage-panel fpw-anchorage-source fpw-anchorage-shell">
    <h2>Source and Review Basis</h2>
    <p>This library is built from reviewed FPW anchorage records and public chart/reference sources where available. It is intended for trip planning and route awareness only. Always verify current official charts, notices, weather, local rules, and conditions before anchoring.</p>
  </section>

  <section class="fpw-anchorage-safety fpw-anchorage-shell">
    <h2>Planning-Only Safety Disclaimer</h2>
    <p>This anchorage reference is for trip planning only. Always verify current charts, notices to mariners, local rules, depth, weather, tides/currents, holding, and observed conditions before anchoring.</p>
    <p>NOAA chart layers are provided for planning context and are not a substitute for official navigation.</p>
  </section>
</main>

<cfinclude template="../includes/footer.cfm">

<script id="fpwAnchorageMapData" type="application/json"><cfoutput>#serializeJSON(mapRows)#</cfoutput></script>
<script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js" integrity="sha256-20nQCchB9co0qIjJZRGuk2/Z9VM+kNiyxNV1lvTlZBo=" crossorigin=""></script>
<script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/app/great-loop-anchorages.js?v=20260622-anchorages"></script>
</body>
</html>
