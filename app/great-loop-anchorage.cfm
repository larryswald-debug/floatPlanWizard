<cfprocessingdirective pageencoding="utf-8">
<cfsetting showdebugoutput="false" requesttimeout="30">
<cfcontent type="text/html; charset=utf-8">
<cfinclude template="../includes/fpw_base_path.cfm">

<cfscript>
slugValue = structKeyExists(url, "slug") ? trim(toString(url.slug)) : "";
slugValue = reReplace(slugValue, "[?##].*$", "");
slugValue = reReplace(slugValue, "^/+|/+$", "", "all");

try {
  anchorageSvc = createObject("component", "api.v1.GreatLoopAnchoragesService").init();
} catch (any svcPathError) {
  anchorageSvc = createObject("component", "fpw.api.v1.GreatLoopAnchoragesService").init();
}

detailModel = anchorageSvc.getAnchorageBySlug(slugValue);
if (!detailModel.SUCCESS) {
  cfheader(statuscode = "404");
}

anchorageItem = detailModel.SUCCESS ? detailModel.ANCHORAGE : {};
libraryUrl = request.fpwBase & "/great-loop/anchorages/";
canonicalBase = "https://floatplanwizard.com/great-loop/anchorages/";
canonicalUrl = detailModel.SUCCESS ? canonicalBase & anchorageItem.slug & "/" : canonicalBase;
pageTitle = detailModel.SUCCESS ? anchorageItem.anchorage_name & " Anchorage Guide | FloatPlanWizard" : "Anchorage Guide Not Found | FloatPlanWizard";
pageDescription = detailModel.SUCCESS
  ? "Plan around " & anchorageItem.anchorage_name & " near " & anchorageItem.nearest_city & ", " & anchorageItem.state_province & ". View location, waterway, anchorage type, holding, protection, planning notes, and map reference. Always verify current charts and local rules before anchoring."
  : "The requested anchorage guide could not be found.";
pageHeading = detailModel.SUCCESS ? anchorageItem.anchorage_name & " Anchorage" : "Anchorage Guide Not Found";
hasValidCoordinates = detailModel.SUCCESS AND isNumeric(anchorageItem.latitude) AND isNumeric(anchorageItem.longitude);

function displayText(any value, string fallback="Not listed") {
  var txt = isNull(arguments.value) ? "" : trim(toString(arguments.value));
  return len(txt) ? txt : arguments.fallback;
}

function hasText(any value) {
  return len(trim(toString(isNull(arguments.value) ? "" : arguments.value))) GT 0;
}

function locationLine(required struct item) {
  var pieces = [];
  if (hasText(arguments.item.nearest_city)) arrayAppend(pieces, arguments.item.nearest_city);
  if (hasText(arguments.item.state_province)) arrayAppend(pieces, arguments.item.state_province);
  if (hasText(arguments.item.country)) arrayAppend(pieces, arguments.item.country);
  return arrayLen(pieces) ? arrayToList(pieces, ", ") : "Location not listed";
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
    "waterway" = "waterwaySlug"
  };
  var normalizedType = lCase(trim(arguments.typeName));
  if (!len(slug)) {
    return libraryUrl;
  }
  if (isLocalDevHost() AND structKeyExists(taxonomyParams, normalizedType)) {
    return libraryUrl & "index.cfm?" & taxonomyParams[normalizedType] & "=" & urlEncodedFormat(slug);
  }
  return libraryUrl & normalizedType & "/" & slug & "/";
}

detailLocationUrl = detailModel.SUCCESS AND hasText(anchorageItem.location_group) ? taxonomyUrl("location", anchorageItem.location_group) : "";
detailWaterwayUrl = detailModel.SUCCESS AND hasText(anchorageItem.waterway) ? taxonomyUrl("waterway", anchorageItem.waterway) : "";

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
  { "name" = "FloatPlanWizard", "item" = "https://floatplanwizard.com/" },
  { "name" = "Great Loop Anchorages", "item" = canonicalBase }
];
if (detailModel.SUCCESS) {
  if (hasText(anchorageItem.location_group)) {
    arrayAppend(breadcrumbItems, {
      "name" = anchorageItem.location_group,
      "item" = canonicalBase & "location/" & anchorageSvc.normalizeSlug(anchorageItem.location_group) & "/"
    });
  }
  if (hasText(anchorageItem.waterway)) {
    arrayAppend(breadcrumbItems, {
      "name" = anchorageItem.waterway,
      "item" = canonicalBase & "waterway/" & anchorageSvc.normalizeSlug(anchorageItem.waterway) & "/"
    });
  }
  arrayAppend(breadcrumbItems, { "name" = anchorageItem.anchorage_name, "item" = canonicalUrl });
}
breadcrumbSchema["itemListElement"] = [];
for (crumbIndex = 1; crumbIndex LTE arrayLen(breadcrumbItems); crumbIndex++) {
  crumb = breadcrumbItems[crumbIndex];
  crumbItem = structNew("ordered");
  structInsert(crumbItem, schemaTypeKey, "ListItem", true);
  crumbItem["position"] = crumbIndex;
  crumbItem["name"] = crumb.name;
  crumbItem["item"] = crumb.item;
  arrayAppend(breadcrumbSchema["itemListElement"], crumbItem);
}
arrayAppend(schemaGraph, breadcrumbSchema);

pageSchema = structNew("ordered");
structInsert(pageSchema, schemaIdKey, canonicalUrl & "##webpage", true);
structInsert(pageSchema, schemaTypeKey, "WebPage", true);
pageSchema["name"] = pageTitle;
pageSchema["description"] = pageDescription;
pageSchema["url"] = canonicalUrl;
pageSchema["isPartOf"] = schemaRef("https://floatplanwizard.com/##website");
pageSchema["breadcrumb"] = schemaRef(canonicalUrl & "##breadcrumb");
arrayAppend(schemaGraph, pageSchema);

if (detailModel.SUCCESS AND hasValidCoordinates) {
  placeSchema = structNew("ordered");
  structInsert(placeSchema, schemaTypeKey, "Place", true);
  placeSchema["name"] = anchorageItem.anchorage_name;
  placeSchema["url"] = canonicalUrl;
  placeSchema["geo"] = { "@type" = "GeoCoordinates", "latitude" = anchorageItem.latitude, "longitude" = anchorageItem.longitude };
  placeSchema["address"] = { "@type" = "PostalAddress", "addressLocality" = anchorageItem.nearest_city, "addressRegion" = anchorageItem.state_province, "addressCountry" = anchorageItem.country };
  arrayAppend(schemaGraph, placeSchema);
}

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
  <meta property="og:type" content="article">
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
  <section class="fpw-anchorage-hero fpw-anchorage-hero--detail">
    <div class="fpw-anchorage-shell">
      <p class="fpw-anchorage-eyebrow"><a href="<cfoutput>#encodeForHTMLAttribute(libraryUrl)#</cfoutput>">Anchorage Library</a></p>
      <h1><cfoutput>#encodeForHTML(pageHeading)#</cfoutput></h1>
      <cfif detailModel.SUCCESS>
        <p><cfoutput>#encodeForHTML(locationLine(anchorageItem))#<cfif hasText(anchorageItem.waterway)> on #encodeForHTML(anchorageItem.waterway)#</cfif></cfoutput></p>
        <p class="fpw-anchorage-note">This is a planning reference only and is not a navigation product.</p>
      <cfelse>
        <p>The requested anchorage guide is not available as a published public reference.</p>
      </cfif>
    </div>
  </section>

  <nav class="fpw-anchorage-breadcrumbs fpw-anchorage-shell" aria-label="Breadcrumb">
    <a href="<cfoutput>#encodeForHTMLAttribute(libraryUrl)#</cfoutput>">Great Loop Anchorages</a>
    <cfif detailModel.SUCCESS>
      <cfif hasText(anchorageItem.location_group)>
        <span aria-hidden="true">&rsaquo;</span>
        <a href="<cfoutput>#encodeForHTMLAttribute(detailLocationUrl)#</cfoutput>"><cfoutput>#encodeForHTML(anchorageItem.location_group)#</cfoutput></a>
      </cfif>
      <cfif hasText(anchorageItem.waterway)>
        <span aria-hidden="true">&rsaquo;</span>
        <a href="<cfoutput>#encodeForHTMLAttribute(detailWaterwayUrl)#</cfoutput>"><cfoutput>#encodeForHTML(anchorageItem.waterway)#</cfoutput></a>
      </cfif>
      <span aria-hidden="true">&rsaquo;</span>
      <span><cfoutput>#encodeForHTML(anchorageItem.anchorage_name)#</cfoutput></span>
    </cfif>
  </nav>

  <cfif NOT detailModel.SUCCESS>
    <section class="fpw-anchorage-panel fpw-anchorage-shell">
      <h2>Guide unavailable</h2>
      <p>Only reviewed anchorages marked as published are available in the public library.</p>
      <a class="fpw-anchorage-btn fpw-anchorage-btn--primary" href="<cfoutput>#encodeForHTMLAttribute(libraryUrl)#</cfoutput>">Browse Anchorages</a>
    </section>
  <cfelse>
    <section class="fpw-anchorage-detail fpw-anchorage-shell">
      <div class="fpw-anchorage-detail-main">
        <section class="fpw-anchorage-panel">
          <h2>Map Reference</h2>
          <cfif hasValidCoordinates>
            <label class="fpw-anchorage-noaa-toggle">
              <input type="checkbox" data-noaa-chart-toggle>
              <span>Show NOAA nautical chart layer</span>
            </label>
            <p class="fpw-anchorage-noaa-help">NOAA chart layer is for planning context only and is not a substitute for official navigation.</p>
            <cfoutput>
              <div
                id="fpwAnchorageDetailMap"
                class="fpw-anchorage-detail-map"
                data-lat="#encodeForHTMLAttribute(anchorageItem.latitude)#"
                data-lng="#encodeForHTMLAttribute(anchorageItem.longitude)#"
                data-name="#encodeForHTMLAttribute(anchorageItem.anchorage_name)#"
                data-location="#encodeForHTMLAttribute(locationLine(anchorageItem))#"
                data-waterway="#encodeForHTMLAttribute(anchorageItem.waterway)#"
                data-location-group="#encodeForHTMLAttribute(anchorageItem.location_group)#"
                data-type="#encodeForHTMLAttribute(anchorageItem.anchorage_type)#"
                data-protection="#encodeForHTMLAttribute(anchorageItem.protection)#"
                data-holding="#encodeForHTMLAttribute(anchorageItem.holding)#"
                data-public-status="#encodeForHTMLAttribute(anchorageItem.public_status)#"></div>
            </cfoutput>
          <cfelse>
            <p>Location map is unavailable because this anchorage does not have valid coordinates yet.</p>
          </cfif>
        </section>

        <section class="fpw-anchorage-panel">
          <h2>Planning Notes</h2>
          <p><cfoutput>#encodeForHTML(displayText(anchorageItem.notes, "Planning notes are not listed for this published anchorage yet."))#</cfoutput></p>
          <cfif hasText(anchorageItem.nav_warning)>
            <p class="fpw-anchorage-warning"><cfoutput>#encodeForHTML(anchorageItem.nav_warning)#</cfoutput></p>
          </cfif>
        </section>

        <section class="fpw-anchorage-panel">
          <h2>Anchorage Details</h2>
          <dl class="fpw-anchorage-fact-grid">
            <div><dt>Holding</dt><dd><cfoutput>#encodeForHTML(displayText(anchorageItem.holding))#</cfoutput></dd></div>
            <div><dt>Protection</dt><dd><cfoutput>#encodeForHTML(displayText(anchorageItem.protection))#</cfoutput></dd></div>
            <div><dt>Shore Access</dt><dd><cfoutput>#encodeForHTML(displayText(anchorageItem.shore_access))#</cfoutput></dd></div>
            <div><dt>Great Loop Relevance</dt><dd><cfoutput>#encodeForHTML(displayText(anchorageItem.great_loop_relevance))#</cfoutput></dd></div>
          </dl>
        </section>

        <section class="fpw-anchorage-panel">
          <h2>Nearby / Related Anchorages</h2>
          <cfif arrayLen(detailModel.NEARBY)>
            <div class="fpw-anchorage-related">
              <cfloop array="#detailModel.NEARBY#" index="nearbyItem">
                <cfoutput><a href="#encodeForHTMLAttribute(detailUrl(nearbyItem.slug))#"><strong>#encodeForHTML(nearbyItem.anchorage_name)#</strong><span>#encodeForHTML(locationLine(nearbyItem))#</span></a></cfoutput>
              </cfloop>
            </div>
          <cfelse>
            <p>Nearby published anchorage references will appear as more reviewed rows are published.</p>
          </cfif>
        </section>
      </div>

      <aside class="fpw-anchorage-detail-rail">
        <section class="fpw-anchorage-panel">
          <h2>Quick Facts</h2>
          <dl class="fpw-anchorage-fact-list">
            <div><dt>Nearest City</dt><dd><cfoutput>#encodeForHTML(displayText(anchorageItem.nearest_city))#</cfoutput></dd></div>
            <div><dt>State / Province</dt><dd><cfoutput>#encodeForHTML(displayText(anchorageItem.state_province))#</cfoutput></dd></div>
            <div><dt>Country</dt><dd><cfoutput>#encodeForHTML(displayText(anchorageItem.country))#</cfoutput></dd></div>
            <div><dt>Location Group</dt><dd><cfoutput>#encodeForHTML(displayText(anchorageItem.location_group))#</cfoutput></dd></div>
            <div><dt>Waterway</dt><dd><cfoutput>#encodeForHTML(displayText(anchorageItem.waterway))#</cfoutput></dd></div>
            <div><dt>Type</dt><dd><cfoutput>#encodeForHTML(displayText(anchorageItem.anchorage_type))#</cfoutput></dd></div>
            <div><dt>Public Status</dt><dd><cfoutput>#encodeForHTML(displayText(anchorageItem.public_status))#</cfoutput></dd></div>
            <div><dt>Verification</dt><dd><cfoutput>#encodeForHTML(displayText(anchorageItem.verification_status))#</cfoutput></dd></div>
            <div><dt>Last Reviewed</dt><dd><cfoutput>#encodeForHTML(displayText(anchorageItem.last_reviewed))#</cfoutput></dd></div>
          </dl>
        </section>

        <section class="fpw-anchorage-panel">
          <h2>Plan With FPW</h2>
          <p>Before you leave the dock, build a float plan that records your route, passengers, vessel details, and return plan.</p>
          <a class="fpw-anchorage-btn fpw-anchorage-btn--primary fpw-anchorage-btn--full" href="<cfoutput>#request.fpwBase#</cfoutput>/app/join.cfm">Create a Float Plan</a>
        </section>

        <section class="fpw-anchorage-panel">
          <h2>Source / Review Basis</h2>
          <cfif hasText(anchorageItem.source_url)>
            <p><cfoutput>#encodeForHTML(displayText(anchorageItem.source_name, "Public source"))#</cfoutput></p>
            <a href="<cfoutput>#encodeForHTMLAttribute(anchorageItem.source_url)#</cfoutput>" rel="nofollow noopener" target="_blank">Open source reference</a>
          <cfelse>
            <p>Source information is not listed for this published anchorage yet.</p>
          </cfif>
        </section>

        <section class="fpw-anchorage-panel fpw-anchorage-safety">
          <h2>Planning-Only Disclaimer</h2>
          <p>This anchorage reference is for trip planning only. Always verify current charts, notices to mariners, local rules, depth, weather, tides/currents, holding, and observed conditions before anchoring.</p>
          <p>NOAA chart layers are provided for planning context and are not a substitute for official navigation.</p>
        </section>
      </aside>
    </section>
  </cfif>
</main>

<cfinclude template="../includes/footer.cfm">
<script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js" integrity="sha256-20nQCchB9co0qIjJZRGuk2/Z9VM+kNiyxNV1lvTlZBo=" crossorigin=""></script>
<script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/app/great-loop-anchorages.js?v=20260622-anchorages"></script>
</body>
</html>
