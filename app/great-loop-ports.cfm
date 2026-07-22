<cfprocessingdirective pageencoding="utf-8">
<cfsetting showdebugoutput="false" requesttimeout="30">
<cfcontent type="text/html; charset=utf-8">
<cfinclude template="../includes/fpw_base_path.cfm">

<cfscript>
try {
  portsSvc = createObject("component", "api.v1.PortsLibraryService").init();
} catch (any svcPathError) {
  portsSvc = createObject("component", "fpw.api.v1.PortsLibraryService").init();
}

function safeText(any value, string fallback="") {
  var txt = "";
  if (!isNull(arguments.value)) {
    txt = trim(toString(arguments.value));
  }
  return len(txt) ? txt : arguments.fallback;
}

function selectedAttr(required any leftValue, required any rightValue) {
  return compareNoCase(trim(toString(arguments.leftValue)), trim(toString(arguments.rightValue))) EQ 0 ? " selected" : "";
}

function checkedAttr(required any value) {
  var txt = lCase(trim(toString(isNull(arguments.value) ? "" : arguments.value)));
  return listFindNoCase("1,true,yes,y,on", txt) ? " checked" : "";
}

function normalizePortSlug(required any value) {
  var slug = lCase(trim(safeText(arguments.value)));
  slug = reReplace(slug, "[^a-z0-9]+", "-", "all");
  slug = reReplace(slug, "^-+|-+$", "", "all");
  return left(slug, 220);
}

function portDetailSegment(required struct item) {
  var portId = structKeyExists(arguments.item, "ID") ? val(arguments.item.ID) : 0;
  var slug = structKeyExists(arguments.item, "SLUG") ? normalizePortSlug(arguments.item.SLUG) : "";
  var idPrefix = portId & "-";
  var fallback = "";

  if (portId LTE 0) {
    return slug;
  }
  if (len(slug) AND left(slug, len(idPrefix)) EQ idPrefix) {
    return slug;
  }
  if (len(slug)) {
    return idPrefix & slug;
  }
  fallback = safeText(arguments.item.NAME) & " " & safeText(arguments.item.STATE_CODE);
  return idPrefix & normalizePortSlug(fallback);
}

function portDetailUrl(required struct item) {
  return libraryUrl & portDetailSegment(arguments.item) & "/";
}

function portFilterUrl(required string filterName, required any filterValue) {
  return libraryUrl & "?" & arguments.filterName & "=" & urlEncodedFormat(safeText(arguments.filterValue));
}

function tagLabel(required any value) {
  var tag = lCase(trim(safeText(arguments.value)));
  var label = "";
  if (tag EQ "major-stop-candidate") return "Major stop candidate";
  if (tag EQ "route-gateway-candidate") return "Route gateway candidate";
  if (tag EQ "needs-review") return "Needs review";
  if (tag EQ "bad-coordinates") return "Bad coordinates";
  if (tag EQ "coordinate-state-mismatch") return "Coordinate/state review";
  if (tag EQ "duplicate-name-review") return "Duplicate name review";
  if (tag EQ "duplicate-name-state-review") return "Duplicate name/state review";
  if (tag EQ "needs-route-segment-review") return "Route segment review";
  if (tag EQ "non-loop-or-side-route-review") return "Side-route review";
  label = replace(tag, "-", " ", "all");
  return len(label) ? uCase(left(label, 1)) & right(label, len(label) - 1) : "";
}

function qualityLabel(required any value) {
  var status = lCase(trim(safeText(arguments.value)));
  if (status EQ "verified") return "Verified";
  if (status EQ "derived_unverified") return "Derived, not verified";
  if (status EQ "needs_review") return "Needs review";
  if (status EQ "bad_coordinates") return "Coordinate review needed";
  if (status EQ "missing_coordinates") return "Coordinates missing";
  if (status EQ "duplicate_name_review") return "Duplicate name review";
  return len(status) ? tagLabel(replace(status, "_", "-", "all")) : "Needs review";
}

function isUserFacingTag(required any value) {
  var tag = lCase(trim(safeText(arguments.value)));
  if (!len(tag)) return false;
  if (left(tag, 6) EQ "state-") return false;
  if (listFindNoCase("location-seeded,loop-segment-inferred,segment-inferred,major-stop-candidate", tag)) return false;
  return true;
}

function arrayHasValue(required array values, required string expectedValue) {
  var item = "";
  for (item in arguments.values) {
    if (compareNoCase(trim(toString(item)), arguments.expectedValue) EQ 0) {
      return true;
    }
  }
  return false;
}

function locationLine(required struct item) {
  var pieces = [];
  if (len(safeText(arguments.item.STATE))) arrayAppend(pieces, safeText(arguments.item.STATE));
  if (len(safeText(arguments.item.STATE_CODE)) AND safeText(arguments.item.STATE_CODE) NEQ safeText(arguments.item.STATE)) arrayAppend(pieces, safeText(arguments.item.STATE_CODE));
  if (len(safeText(arguments.item.COUNTRY))) arrayAppend(pieces, safeText(arguments.item.COUNTRY));
  return arrayLen(pieces) ? arrayToList(pieces, ", ") : "Location not listed";
}

function getRandomInitialPorts(required array sourceRows, numeric limitRows = 10) {
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

filters = {
  "q" = structKeyExists(url, "q") ? trim(toString(url.q)) : "",
  "stateCode" = structKeyExists(url, "stateCode") ? trim(toString(url.stateCode)) : "",
  "loopSegment" = structKeyExists(url, "loopSegment") ? trim(toString(url.loopSegment)) : "",
  "tag" = structKeyExists(url, "tag") ? trim(toString(url.tag)) : "",
  "majorStop" = structKeyExists(url, "majorStop") ? trim(toString(url.majorStop)) : "",
  "mapReady" = "1"
};
if (listFindNoCase("1,true,yes,y,on", filters.majorStop)) {
  filters.tag = "major-stop-candidate";
}

libraryUrl = structKeyExists(request, "fpwPortsLibraryUrl") ? request.fpwPortsLibraryUrl : request.fpwBase & "/great-loop/ports/";
canonicalBase = structKeyExists(request, "fpwPortsCanonicalBase") ? request.fpwPortsCanonicalBase : "https://floatplanwizard.com/great-loop/ports/";
canonicalUrl = canonicalBase;
pageTitle = "Great Loop Ports Library | FloatPlanWizard";
pageDescription = "Explore Great Loop ports and stopping points on an interactive map. View port locations, route segments, and add ports to your custom FPW waypoints.";
pageHeading = "Great Loop Ports Library";
pageLede = "Explore Great Loop ports and stopping points on an interactive map. Find useful route-planning locations, view port details, and add ports to your custom FPW waypoints.";

libraryModel = portsSvc.getLibraryModel(filters);
portRows = libraryModel.SUCCESS ? libraryModel.PORTS : [];
facets = libraryModel.SUCCESS ? libraryModel.FACETS : {};
quality = libraryModel.SUCCESS ? libraryModel.QUALITY : {};
stateCodes = structKeyExists(facets, "STATE_CODES") ? facets.STATE_CODES : [];
loopSegments = structKeyExists(facets, "LOOP_SEGMENTS") ? facets.LOOP_SEGMENTS : [];
tags = structKeyExists(facets, "TAGS") ? facets.TAGS : [];
userFacingTags = [];
mapRows = [];
featuredPortRows = [];
displayPortRows = [];
mapSourcePortRows = [];
schemaPortRows = [];
schemaGraph = [];
isDefaultPortsLibraryView = !len(filters.q)
  AND !len(filters.stateCode)
  AND !len(filters.loopSegment)
  AND !len(filters.tag)
  AND !len(filters.majorStop);

for (tagItem in tags) {
  if (isUserFacingTag(tagItem)) {
    arrayAppend(userFacingTags, tagItem);
  }
}

featuredPortLimit = 10;
displayPortRows = portRows;
mapSourcePortRows = portRows;
schemaPortRows = portRows;
if (isDefaultPortsLibraryView) {
  featuredPortRows = getRandomInitialPorts(portRows, featuredPortLimit);
  displayPortRows = featuredPortRows;
  mapSourcePortRows = featuredPortRows;
}

for (portItem in mapSourcePortRows) {
  if (structKeyExists(portItem, "MAP_READY") AND portItem.MAP_READY
      AND !isNull(portItem.LAT) AND !isNull(portItem.LNG)
      AND isNumeric(portItem.LAT) AND isNumeric(portItem.LNG)) {
    arrayAppend(mapRows, {
      "ID" = portItem.ID,
      "NAME" = portItem.NAME,
      "STATE" = portItem.STATE,
      "STATE_CODE" = portItem.STATE_CODE,
      "COUNTRY" = portItem.COUNTRY,
      "LAT" = portItem.LAT,
      "LNG" = portItem.LNG,
      "LOOP_SEGMENT" = portItem.LOOP_SEGMENT,
      "WATERWAY" = portItem.WATERWAY,
      "SLUG" = portItem.SLUG,
      "URL" = portDetailUrl(portItem),
      "DATA_QUALITY_STATUS" = portItem.DATA_QUALITY_STATUS,
      "MAP_READY" = portItem.MAP_READY,
      "TAGS" = portItem.TAGS,
      "SERVICES" = portItem.SERVICES
    });
  }
}

schemaAtKey = chr(64);
schemaTypeKey = schemaAtKey & "type";
schemaIdKey = schemaAtKey & "id";
schemaContextKey = schemaAtKey & "context";
schemaGraphKey = schemaAtKey & "graph";

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
breadcrumbSchema["itemListElement"] = [
  { "@type" = "ListItem", "position" = 1, "name" = "FloatPlanWizard", "item" = "https://floatplanwizard.com/" },
  { "@type" = "ListItem", "position" = 2, "name" = "Great Loop Ports", "item" = canonicalBase }
];
arrayAppend(schemaGraph, breadcrumbSchema);

pageSchema = structNew("ordered");
structInsert(pageSchema, schemaIdKey, canonicalUrl & "##webpage", true);
structInsert(pageSchema, schemaTypeKey, "CollectionPage", true);
pageSchema["name"] = pageTitle;
pageSchema["description"] = pageDescription;
pageSchema["url"] = canonicalUrl;
pageSchema["isPartOf"] = schemaRef("https://floatplanwizard.com/##website");
pageSchema["breadcrumb"] = schemaRef(canonicalUrl & "##breadcrumb");
pageSchema["mainEntity"] = schemaRef(canonicalUrl & "##itemlist");
arrayAppend(schemaGraph, pageSchema);

itemListSchema = structNew("ordered");
structInsert(itemListSchema, schemaIdKey, canonicalUrl & "##itemlist", true);
structInsert(itemListSchema, schemaTypeKey, "ItemList", true);
itemListSchema["name"] = "Map-ready Great Loop ports";
itemListSchema["itemListOrder"] = "https://schema.org/ItemListOrderAscending";
itemListSchema["numberOfItems"] = arrayLen(schemaPortRows);
itemListSchema["itemListElement"] = [];
schemaSampleLimit = min(arrayLen(schemaPortRows), 20);
for (schemaIndex = 1; schemaIndex LTE schemaSampleLimit; schemaIndex++) {
  listItem = structNew("ordered");
  structInsert(listItem, schemaTypeKey, "ListItem", true);
  listItem["position"] = schemaIndex;
  listItem["name"] = schemaPortRows[schemaIndex].NAME;
  listItem["url"] = "https://floatplanwizard.com/great-loop/ports/" & portDetailSegment(schemaPortRows[schemaIndex]) & "/";
  arrayAppend(itemListSchema["itemListElement"], listItem);
}
arrayAppend(schemaGraph, itemListSchema);

schemaRoot = structNew("ordered");
structInsert(schemaRoot, schemaContextKey, "https://schema.org", true);
structInsert(schemaRoot, schemaGraphKey, schemaGraph, true);
pageJsonLdText = replace(serializeJSON(schemaRoot), "</", "<\/", "all");
</cfscript>

<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title><cfoutput>#encodeForHTML(pageTitle)#</cfoutput></title>
  <meta name="description" content="<cfoutput>#encodeForHTMLAttribute(pageDescription)#</cfoutput>">
  <link rel="canonical" href="<cfoutput>#encodeForHTMLAttribute(canonicalUrl)#</cfoutput>">
  <meta property="og:type" content="website">
  <meta property="og:site_name" content="FloatPlanWizard">
  <meta property="og:title" content="<cfoutput>#encodeForHTMLAttribute(pageTitle)#</cfoutput>">
  <meta property="og:description" content="<cfoutput>#encodeForHTMLAttribute(pageDescription)#</cfoutput>">
  <meta property="og:url" content="<cfoutput>#encodeForHTMLAttribute(canonicalUrl)#</cfoutput>">
  <meta property="og:image" content="https://floatplanwizard.com/assets/images/social/floatplanwizard-social-preview-20260602.png">
  <meta name="twitter:card" content="summary_large_image">
  <meta name="twitter:title" content="<cfoutput>#encodeForHTMLAttribute(pageTitle)#</cfoutput>">
  <meta name="twitter:description" content="<cfoutput>#encodeForHTMLAttribute(pageDescription)#</cfoutput>">
  <meta name="twitter:image" content="https://floatplanwizard.com/assets/images/social/floatplanwizard-social-preview-20260602.png">
  <script type="application/ld+json"><cfoutput>#pageJsonLdText#</cfoutput></script>
  <link rel="stylesheet" href="<cfoutput>#request.fpwBase#</cfoutput>/assets/css/layout.css?v=20260620-page-width">
  <link rel="stylesheet" href="<cfoutput>#request.fpwBase#</cfoutput>/assets/css/top-nav.css?v=20260630-mega-weight-minus1">
  <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" integrity="sha256-p4NxAoJBhIIN+hmNHrzRCf9tD/miZyoHS5obTRR9BMY=" crossorigin="">
  <link rel="stylesheet" href="<cfoutput>#request.fpwBase#</cfoutput>/assets/css/great-loop-ports.css?v=20260707-noaa-charts">
  <cfinclude template="../includes/analytics_ga4.cfm">
  <cfinclude template="../includes/analytics_clarity.cfm">
  <cfinclude template="../includes/trustedsite.cfm">
</head>
<body id="top" class="fpw-ports-body">
<cfinclude template="../includes/top_nav.cfm">

<main class="fpw-ports-page">
  <section class="fpw-ports-hero fpw-ports-hero--library">
    <div class="fpw-ports-shell">
      <p class="fpw-ports-eyebrow">Great Loop planning reference</p>
      <h1><cfoutput>#encodeForHTML(pageHeading)#</cfoutput></h1>
      <p><cfoutput>#encodeForHTML(pageLede)#</cfoutput></p>
    </div>
  </section>

  <section class="fpw-ports-stats fpw-ports-shell" aria-label="Ports library summary">
    <div><strong data-ports-total-count><cfoutput>#encodeForHTML(structKeyExists(quality, "MAP_READY_PORTS") ? quality.MAP_READY_PORTS : arrayLen(mapRows))#</cfoutput></strong><span>Map-ready ports</span></div>
    <div><strong><cfoutput>#encodeForHTML(structKeyExists(quality, "TOTAL_PORTS") ? quality.TOTAL_PORTS : arrayLen(portRows))#</cfoutput></strong><span>Total port records</span></div>
    <div><strong><cfoutput>#encodeForHTML(arrayLen(stateCodes))#</cfoutput></strong><span>States / provinces</span></div>
    <div><strong><cfoutput>#encodeForHTML(arrayLen(loopSegments))#</cfoutput></strong><span>Loop segments</span></div>
  </section>

  <section class="fpw-ports-cta fpw-ports-panel fpw-ports-shell" aria-labelledby="fpwPortsCtaTitle">
    <div>
      <p class="fpw-ports-eyebrow">Plan With FPW</p>
      <h2 id="fpwPortsCtaTitle">Add useful stops to your plan</h2>
      <p>Use the Ports Library to identify route-planning stops, then create a float plan that records your route, vessel, passengers, and return plan.</p>
    </div>
    <div class="fpw-ports-cta-actions">
      <a class="fpw-ports-btn fpw-ports-btn--primary" href="<cfoutput>#request.fpwBase#</cfoutput>/app/join.cfm">Create a free float plan</a>
    </div>
  </section>

  <nav class="fpw-ports-breadcrumbs fpw-ports-shell" aria-label="Breadcrumb">
    <a href="<cfoutput>#encodeForHTMLAttribute(libraryUrl)#</cfoutput>">Great Loop Ports</a>
  </nav>

  <section class="fpw-ports-finder fpw-ports-shell" id="fpwPortsFinder" aria-labelledby="fpwPortsFinderTitle">
    <aside class="fpw-ports-panel fpw-ports-filters">
      <h2 id="fpwPortsFinderTitle">Find Ports</h2>
      <form
        method="get"
        action="<cfoutput>#encodeForHTMLAttribute(libraryUrl)#</cfoutput>"
        data-ports-filter-form
        data-ports-api-endpoint="<cfoutput>#request.fpwApiBase#</cfoutput>/ports.cfc?method=handle&returnFormat=json"
        data-ports-page-url="<cfoutput>#encodeForHTMLAttribute(libraryUrl)#</cfoutput>"
        data-ports-detail-base="<cfoutput>#encodeForHTMLAttribute(libraryUrl)#</cfoutput>"
        data-ports-login-url="<cfoutput>#request.fpwBase#</cfoutput>/app/login.cfm"
        data-ports-join-url="<cfoutput>#request.fpwBase#</cfoutput>/app/join.cfm">
        <label class="fpw-ports-field">
          <span>Search</span>
          <input type="search" name="q" value="<cfoutput>#encodeForHTMLAttribute(filters.q)#</cfoutput>" placeholder="Port, state, waterway, route segment">
        </label>

        <label class="fpw-ports-field">
          <span>State / Province</span>
          <select name="stateCode">
            <option value="">All</option>
            <cfloop array="#stateCodes#" index="facet"><cfoutput><option value="#encodeForHTMLAttribute(facet)#"#selectedAttr(filters.stateCode, facet)#>#encodeForHTML(facet)#</option></cfoutput></cfloop>
          </select>
        </label>

        <label class="fpw-ports-field">
          <span>Loop Segment</span>
          <select name="loopSegment">
            <option value="">All</option>
            <cfloop array="#loopSegments#" index="facet"><cfoutput><option value="#encodeForHTMLAttribute(facet)#"#selectedAttr(filters.loopSegment, facet)#>#encodeForHTML(facet)#</option></cfoutput></cfloop>
          </select>
        </label>

        <input type="hidden" name="tag" value="<cfoutput>#encodeForHTMLAttribute(filters.tag)#</cfoutput>">

        <label class="fpw-ports-check">
          <input type="checkbox" name="majorStop" value="1"<cfoutput>#checkedAttr(filters.majorStop)#</cfoutput>>
          <span>Major stop candidates</span>
        </label>

        <div class="fpw-ports-filter-actions">
          <button type="submit" class="fpw-ports-btn fpw-ports-btn--primary" data-ports-apply>Apply Filters</button>
          <a class="fpw-ports-btn" href="<cfoutput>#encodeForHTMLAttribute(libraryUrl)#</cfoutput>" data-ports-clear>Reset</a>
        </div>
        <p class="fpw-ports-filter-status" data-ports-filter-status aria-live="polite" hidden></p>
      </form>
    </aside>

    <div class="fpw-ports-panel fpw-ports-map-card">
      <div class="fpw-ports-map-toolbar">
        <div>
          <h2>Ports Map</h2>
          <p data-ports-result-summary><cfif isDefaultPortsLibraryView><cfoutput>Showing #encodeForHTML(arrayLen(displayPortRows))# featured ports. Use search or filters to explore the full library.</cfoutput><cfelse><cfoutput>#arrayLen(portRows)# ports match, with #arrayLen(mapRows)# map markers.</cfoutput></cfif></p>
        </div>
        <div class="fpw-ports-view-toggle" role="group" aria-label="View type">
          <button type="button" class="is-active" data-ports-view-button="map">Map</button>
          <button type="button" data-ports-view-button="list">List</button>
        </div>
      </div>

      <div class="fpw-ports-map-view" data-ports-view-panel="map">
        <div id="fpwPortsMap" class="fpw-ports-map" aria-label="Great Loop ports map"></div>
        <p class="fpw-ports-empty-map" data-ports-empty-map<cfif arrayLen(mapRows)> hidden</cfif>>No map-ready ports match these filters.</p>
      </div>

      <div class="fpw-ports-list-view" data-ports-view-panel="list" hidden>
        <div class="fpw-ports-result-list" data-ports-result-list<cfif NOT arrayLen(displayPortRows)> hidden</cfif>>
          <cfloop array="#displayPortRows#" index="portItem">
            <cfoutput>
              <article class="fpw-ports-result-card" data-port-card data-port-id="#encodeForHTMLAttribute(portItem.ID)#">
                <div>
                  <h3><a href="#encodeForHTMLAttribute(portDetailUrl(portItem))#">#encodeForHTML(portItem.NAME)#</a></h3>
                  <p>#encodeForHTML(locationLine(portItem))#</p>
                  <p>#encodeForHTML(len(safeText(portItem.LOOP_SEGMENT)) ? portItem.LOOP_SEGMENT : "Loop segment not listed")#<cfif len(safeText(portItem.WATERWAY))> &bull; #encodeForHTML(portItem.WATERWAY)#</cfif></p>
                  <div class="fpw-ports-badges">
                    <cfset visibleTagCount = 0>
                    <cfif arrayHasValue(portItem.TAGS, "major-stop-candidate")>
                      <span class="fpw-ports-badge fpw-ports-badge--accent">Major stop candidate</span>
                      <cfset visibleTagCount = visibleTagCount + 1>
                    </cfif>
                    <cfloop array="#portItem.TAGS#" index="tagItem">
                      <cfif visibleTagCount LT 3 AND isUserFacingTag(tagItem)>
                        <span class="fpw-ports-badge">#encodeForHTML(tagLabel(tagItem))#</span>
                        <cfset visibleTagCount = visibleTagCount + 1>
                      </cfif>
                    </cfloop>
                    <span class="fpw-ports-badge fpw-ports-badge--muted">#encodeForHTML(qualityLabel(portItem.DATA_QUALITY_STATUS))#</span>
                  </div>
                </div>
                <div class="fpw-ports-card-actions">
                  <a class="fpw-ports-btn fpw-ports-btn--small" href="#encodeForHTMLAttribute(portDetailUrl(portItem))#">View Details</a>
                  <button type="button" class="fpw-ports-btn fpw-ports-btn--small fpw-ports-member-only" data-port-add data-port-id="#encodeForHTMLAttribute(portItem.ID)#">Add to My Waypoints</button>
                  <p class="fpw-ports-anon-only">Sign in to add this port to your custom waypoints. <a href="#request.fpwBase#/app/login.cfm">Log in</a> or <a href="#request.fpwBase#/app/join.cfm">join FPW</a>.</p>
                  <p class="fpw-ports-add-status" data-port-add-status="#encodeForHTMLAttribute(portItem.ID)#" aria-live="polite"></p>
                </div>
              </article>
            </cfoutput>
          </cfloop>
        </div>
        <div class="fpw-ports-empty-state" data-ports-empty-list<cfif arrayLen(displayPortRows)> hidden</cfif>>
          <h3>No ports match these filters.</h3>
          <p>Try a broader search, clear the tag filter, or reset all filters.</p>
        </div>
      </div>
    </div>
  </section>

  <section class="fpw-ports-browse fpw-ports-shell" aria-label="Browse Great Loop ports and related libraries">
    <article class="fpw-ports-panel">
      <h2>Browse Ports by State / Province</h2>
      <div class="fpw-ports-related-links">
        <cfloop array="#stateCodes#" index="stateFacet">
          <cfoutput><a href="#encodeForHTMLAttribute(portFilterUrl('stateCode', stateFacet))#">#encodeForHTML(stateFacet)# ports</a></cfoutput>
        </cfloop>
      </div>
    </article>
    <article class="fpw-ports-panel">
      <h2>Browse Ports by Loop Segment</h2>
      <div class="fpw-ports-related-links">
        <cfloop array="#loopSegments#" index="segmentFacet">
          <cfoutput><a href="#encodeForHTMLAttribute(portFilterUrl('loopSegment', segmentFacet))#">#encodeForHTML(segmentFacet)#</a></cfoutput>
        </cfloop>
      </div>
    </article>
    <article class="fpw-ports-panel fpw-ports-related-libraries-panel">
      <h2>Related Great Loop Libraries</h2>
      <div class="fpw-ports-related-links">
        <a href="<cfoutput>#request.fpwBase#</cfoutput>/great-loop/locks/">Great Loop Locks</a>
        <a href="<cfoutput>#request.fpwBase#</cfoutput>/great-loop/bridges/">Great Loop Bridges</a>
        <a href="<cfoutput>#request.fpwBase#</cfoutput>/great-loop/anchorages/">Great Loop Anchorages</a>
      </div>
    </article>
    <article class="fpw-ports-panel fpw-ports-planning-notice">
      <h2>Planning-Only Notice</h2>
      <p>Port information is provided for trip-planning awareness only. Always verify current charts, marina details, local conditions, and official notices before departure.</p>
    </article>
  </section>
</main>

<cfinclude template="../includes/footer.cfm">

<script id="fpwPortsMapData" type="application/json"><cfoutput>#serializeJSON(mapRows)#</cfoutput></script>
<script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js" integrity="sha256-20nQCchB9co0qIjJZRGuk2/Z9VM+kNiyxNV1lvTlZBo=" crossorigin=""></script>
<script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/maps/leaflet-noaa-waypoint-map.js?v=20260619-nautical-charts"></script>
<script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/app/ports-library.js?v=20260707-remove-tag-filter"></script>
</body>
</html>
