<cfprocessingdirective pageencoding="utf-8">
<cfsetting showdebugoutput="false" requesttimeout="30">
<cfcontent type="text/html; charset=utf-8">
<cfinclude template="../includes/fpw_base_path.cfm">

<cfscript>
slugValue = structKeyExists(url, "slug") ? trim(toString(url.slug)) : "";
slugValue = reReplace(slugValue, "[?##].*$", "");
slugValue = reReplace(slugValue, "^/+|/+$", "", "all");
portIdFromSlug = 0;
if (len(slugValue) AND listLen(slugValue, "-") GT 1 AND isNumeric(listFirst(slugValue, "-"))) {
  portIdFromSlug = val(listFirst(slugValue, "-"));
}

try {
  portsSvc = createObject("component", "api.v1.PortsLibraryService").init();
} catch (any svcPathError) {
  portsSvc = createObject("component", "fpw.api.v1.PortsLibraryService").init();
}

detailModel = {};
if (portIdFromSlug GT 0) {
  detailModel = portsSvc.getPortById(portIdFromSlug);
}
if ((!structKeyExists(detailModel, "SUCCESS") OR !detailModel.SUCCESS) AND len(slugValue)) {
  detailModel = portsSvc.getPortBySlug(slugValue);
}
if ((!structKeyExists(detailModel, "SUCCESS") OR !detailModel.SUCCESS) AND len(slugValue)) {
  redirectModel = portsSvc.getPortRedirectBySlug(slugValue);
  if (structKeyExists(redirectModel, "SUCCESS") AND redirectModel.SUCCESS AND structKeyExists(redirectModel, "REDIRECT")) {
    cfheader(statuscode = "301");
    cfheader(name = "Location", value = request.fpwBase & "/great-loop/ports/" & redirectModel.REDIRECT.CANONICAL_SLUG & "/");
    abort;
  }
}
if (!structKeyExists(detailModel, "SUCCESS") OR !detailModel.SUCCESS) {
  cfheader(statuscode = "404");
}

portItem = structKeyExists(detailModel, "SUCCESS") AND detailModel.SUCCESS ? detailModel.PORT : { "TAGS" = [], "SERVICES" = {}, "NEARBY_ASSETS" = [] };
libraryUrl = structKeyExists(request, "fpwPortsLibraryUrl") ? request.fpwPortsLibraryUrl : request.fpwBase & "/great-loop/ports/";
canonicalBase = structKeyExists(request, "fpwPortsCanonicalBase") ? request.fpwPortsCanonicalBase : "https://floatplanwizard.com/great-loop/ports/";

function safeText(any value, string fallback="") {
  var txt = "";
  if (!isNull(arguments.value)) {
    txt = trim(toString(arguments.value));
  }
  return len(txt) ? txt : arguments.fallback;
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

function isUserFacingTag(required any value) {
  var tag = lCase(trim(safeText(arguments.value)));
  if (!len(tag)) return false;
  if (left(tag, 6) EQ "state-") return false;
  if (listFindNoCase("location-seeded,loop-segment-inferred,segment-inferred", tag)) return false;
  return true;
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

function locationLine(required struct item) {
  var pieces = [];
  if (len(safeText(arguments.item.STATE))) arrayAppend(pieces, safeText(arguments.item.STATE));
  if (len(safeText(arguments.item.STATE_CODE)) AND safeText(arguments.item.STATE_CODE) NEQ safeText(arguments.item.STATE)) arrayAppend(pieces, safeText(arguments.item.STATE_CODE));
  if (len(safeText(arguments.item.COUNTRY))) arrayAppend(pieces, safeText(arguments.item.COUNTRY));
  return arrayLen(pieces) ? arrayToList(pieces, ", ") : "Location not listed";
}

function hasValidCoordinates(required struct item) {
  return structKeyExists(arguments.item, "LAT")
    AND structKeyExists(arguments.item, "LNG")
    AND !isNull(arguments.item.LAT)
    AND !isNull(arguments.item.LNG)
    AND isNumeric(arguments.item.LAT)
    AND isNumeric(arguments.item.LNG)
    AND val(arguments.item.LAT) NEQ 0
    AND val(arguments.item.LNG) NEQ 0;
}

function serviceText(any value) {
  if (isNull(arguments.value)) {
    return "";
  }
  if (isBoolean(arguments.value)) {
    return arguments.value ? "Yes" : "Verified no";
  }
  if (isNumeric(arguments.value)) {
    return val(arguments.value) NEQ 0 ? "Yes" : "Verified no";
  }
  return "";
}

function hasKnownService(required struct services, required array definitions) {
  var def = {};
  for (def in arguments.definitions) {
    if (structKeyExists(arguments.services, def.key) AND !isNull(arguments.services[def.key])) {
      return true;
    }
  }
  return false;
}

serviceDefinitions = [
  { "key" = "FUEL_AVAILABLE", "label" = "Fuel" },
  { "key" = "DIESEL_AVAILABLE", "label" = "Diesel" },
  { "key" = "GAS_AVAILABLE", "label" = "Gas" },
  { "key" = "PUMPOUT_AVAILABLE", "label" = "Pumpout" },
  { "key" = "TRANSIENT_DOCKAGE_AVAILABLE", "label" = "Transient dockage" },
  { "key" = "ANCHORAGE_AVAILABLE", "label" = "Anchorage" },
  { "key" = "MOORING_AVAILABLE", "label" = "Mooring" },
  { "key" = "PROVISIONING_AVAILABLE", "label" = "Provisioning" },
  { "key" = "RESTAURANTS_NEARBY", "label" = "Restaurants nearby" },
  { "key" = "MARINE_SUPPLY_NEARBY", "label" = "Marine supply nearby" },
  { "key" = "LAUNDRY_NEARBY", "label" = "Laundry nearby" },
  { "key" = "TRANSPORTATION_NEARBY", "label" = "Transportation nearby" }
];

detailSuccess = structKeyExists(detailModel, "SUCCESS") AND detailModel.SUCCESS;
hasMap = detailSuccess AND structKeyExists(portItem, "MAP_READY") AND portItem.MAP_READY AND hasValidCoordinates(portItem);
detailLocationText = detailSuccess ? locationLine(portItem) : "";
detailLocationPhrase = detailSuccess AND len(detailLocationText) AND detailLocationText NEQ "Location not listed" ? " in " & detailLocationText : "";
detailQualityStatus = detailSuccess AND structKeyExists(portItem, "DATA_QUALITY_STATUS") ? safeText(portItem.DATA_QUALITY_STATUS) : "";
shouldNoIndexPort = !detailSuccess OR !hasMap OR listFindNoCase("bad_coordinates,missing_coordinates", detailQualityStatus);
canonicalUrl = detailSuccess ? canonicalBase & portDetailSegment(portItem) & "/" : canonicalBase;
pageTitle = detailSuccess ? portItem.NAME & " Great Loop Port | FloatPlanWizard" : "Great Loop Port Not Found | FloatPlanWizard";
pageDescription = detailSuccess
  ? "View " & portItem.NAME & detailLocationPhrase & " in the Great Loop Ports Library, including location, route segment, coordinates, and options to add it to your custom FPW waypoints."
  : "The requested Great Loop port could not be found.";
pageHeading = detailSuccess ? portItem.NAME : "Great Loop Port Not Found";
services = detailSuccess AND structKeyExists(portItem, "SERVICES") AND isStruct(portItem.SERVICES) ? portItem.SERVICES : {};
nearbyAssets = detailSuccess AND structKeyExists(portItem, "NEARBY_ASSETS") AND isArray(portItem.NEARBY_ASSETS) ? portItem.NEARBY_ASSETS : [];
portImage = detailSuccess AND structKeyExists(portItem, "IMAGE") AND isStruct(portItem.IMAGE) ? portItem.IMAGE : { "hasImage" = false, "url" = "", "thumbnailUrl" = "", "alt" = "" };
portImageAlt = detailSuccess AND structKeyExists(portImage, "alt") ? safeText(portImage.alt) : "";
if (detailSuccess AND !len(portImageAlt)) {
  portImageAlt = portItem.NAME & " port image";
}

schemaAtKey = chr(64);
schemaTypeKey = schemaAtKey & "type";
schemaIdKey = schemaAtKey & "id";
schemaContextKey = schemaAtKey & "context";
schemaGraphKey = schemaAtKey & "graph";
schemaGraph = [];
portBreadcrumbItems = [
  { "LABEL" = "Great Loop Ports", "URL" = libraryUrl, "CANONICAL_URL" = canonicalBase, "CURRENT" = false }
];
if (detailSuccess) {
  portBreadcrumbStateCode = safeText(portItem.STATE_CODE);
  portBreadcrumbStateLabel = safeText(portItem.STATE);
  portBreadcrumbLoopSegment = safeText(portItem.LOOP_SEGMENT);

  if (len(portBreadcrumbStateCode)) {
    arrayAppend(portBreadcrumbItems, {
      "LABEL" = len(portBreadcrumbStateLabel) ? portBreadcrumbStateLabel : portBreadcrumbStateCode,
      "URL" = portFilterUrl("stateCode", portBreadcrumbStateCode),
      "CANONICAL_URL" = canonicalBase & "?stateCode=" & urlEncodedFormat(portBreadcrumbStateCode),
      "CURRENT" = false
    });
  }
  if (len(portBreadcrumbLoopSegment)) {
    arrayAppend(portBreadcrumbItems, {
      "LABEL" = portBreadcrumbLoopSegment,
      "URL" = portFilterUrl("loopSegment", portBreadcrumbLoopSegment),
      "CANONICAL_URL" = canonicalBase & "?loopSegment=" & urlEncodedFormat(portBreadcrumbLoopSegment),
      "CURRENT" = false
    });
  }
  arrayAppend(portBreadcrumbItems, { "LABEL" = safeText(portItem.NAME), "URL" = "", "CANONICAL_URL" = canonicalUrl, "CURRENT" = true });
}

function schemaRef(required string idValue) {
  var out = structNew("ordered");
  structInsert(out, schemaIdKey, arguments.idValue, true);
  return out;
}

function schemaListItem(required numeric position, required string name, required string urlValue) {
  var out = structNew("ordered");
  structInsert(out, schemaTypeKey, "ListItem", true);
  out["position"] = arguments.position;
  out["name"] = arguments.name;
  out["item"] = arguments.urlValue;
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
breadcrumbSchema["itemListElement"] = [schemaListItem(1, "FloatPlanWizard", "https://floatplanwizard.com/")];
portBreadcrumbSchemaPosition = 2;
for (portBreadcrumbItem in portBreadcrumbItems) {
  arrayAppend(breadcrumbSchema["itemListElement"], schemaListItem(portBreadcrumbSchemaPosition++, portBreadcrumbItem.LABEL, portBreadcrumbItem.CANONICAL_URL));
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

if (detailSuccess AND hasMap) {
  placeSchema = structNew("ordered");
  structInsert(placeSchema, schemaIdKey, canonicalUrl & "##place", true);
  structInsert(placeSchema, schemaTypeKey, "Place", true);
  placeSchema["name"] = portItem.NAME;
  placeSchema["description"] = pageDescription;
  placeSchema["url"] = canonicalUrl;
  placeSchema["mainEntityOfPage"] = schemaRef(canonicalUrl & "##webpage");
  placeSchema["geo"] = { "@type" = "GeoCoordinates", "latitude" = portItem.LAT, "longitude" = portItem.LNG };
  if (len(safeText(portItem.STATE_CODE)) OR len(safeText(portItem.COUNTRY))) {
    placeSchema["address"] = { "@type" = "PostalAddress", "addressRegion" = safeText(portItem.STATE_CODE), "addressCountry" = safeText(portItem.COUNTRY) };
  }
  placeSchema["additionalProperty"] = [];
  if (len(safeText(portItem.LOOP_SEGMENT))) {
    arrayAppend(placeSchema["additionalProperty"], { "@type" = "PropertyValue", "name" = "Loop segment", "value" = safeText(portItem.LOOP_SEGMENT) });
  }
  if (len(safeText(portItem.WATERWAY))) {
    arrayAppend(placeSchema["additionalProperty"], { "@type" = "PropertyValue", "name" = "Waterway", "value" = safeText(portItem.WATERWAY) });
  }
  if (len(detailQualityStatus)) {
    arrayAppend(placeSchema["additionalProperty"], { "@type" = "PropertyValue", "name" = "Data quality status", "value" = qualityLabel(detailQualityStatus) });
  }
  candidateTagLabels = [];
  if (structKeyExists(portItem, "TAGS") AND isArray(portItem.TAGS)) {
    for (schemaTagItem in portItem.TAGS) {
      if (isUserFacingTag(schemaTagItem)) {
        arrayAppend(candidateTagLabels, tagLabel(schemaTagItem));
      }
    }
  }
  if (arrayLen(candidateTagLabels)) {
    arrayAppend(placeSchema["additionalProperty"], { "@type" = "PropertyValue", "name" = "Candidate / review tags", "value" = arrayToList(candidateTagLabels, ", ") });
  }
  arrayAppend(schemaGraph, placeSchema);
}

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
  <cfif shouldNoIndexPort>
    <meta name="robots" content="noindex, follow">
  </cfif>
  <link rel="canonical" href="<cfoutput>#encodeForHTMLAttribute(canonicalUrl)#</cfoutput>">
  <meta property="og:type" content="article">
  <meta property="og:site_name" content="FloatPlanWizard">
  <meta property="og:title" content="<cfoutput>#encodeForHTMLAttribute(pageTitle)#</cfoutput>">
  <meta property="og:description" content="<cfoutput>#encodeForHTMLAttribute(pageDescription)#</cfoutput>">
  <meta property="og:url" content="<cfoutput>#encodeForHTMLAttribute(canonicalUrl)#</cfoutput>">
  <meta property="og:image" content="https://floatplanwizard.com/assets/images/social/floatplanwizard-social-preview-20260730.png">
  <meta name="twitter:card" content="summary_large_image">
  <meta name="twitter:title" content="<cfoutput>#encodeForHTMLAttribute(pageTitle)#</cfoutput>">
  <meta name="twitter:description" content="<cfoutput>#encodeForHTMLAttribute(pageDescription)#</cfoutput>">
  <meta name="twitter:image" content="https://floatplanwizard.com/assets/images/social/floatplanwizard-social-preview-20260730.png">
  <script type="application/ld+json"><cfoutput>#pageJsonLdText#</cfoutput></script>
  <link rel="stylesheet" href="<cfoutput>#request.fpwBase#</cfoutput>/assets/css/layout.css?v=20260620-page-width">
  <link rel="stylesheet" href="<cfoutput>#request.fpwBase#</cfoutput>/assets/css/top-nav.css?v=20260814-featured-guides-layout-v1">
  <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" integrity="sha256-p4NxAoJBhIIN+hmNHrzRCf9tD/miZyoHS5obTRR9BMY=" crossorigin="">
  <link rel="stylesheet" href="<cfoutput>#request.fpwBase#</cfoutput>/assets/css/great-loop-ports.css?v=20260707-noaa-charts">
  <cfinclude template="../includes/analytics_ga4.cfm">
  <cfinclude template="../includes/analytics_clarity.cfm">
  <cfinclude template="../includes/trustedsite.cfm">
</head>
<body id="top" class="fpw-ports-body">
<cfinclude template="../includes/top_nav.cfm">

<main class="fpw-ports-page">
  <section class="fpw-ports-hero fpw-ports-hero--detail">
    <div class="fpw-ports-shell fpw-ports-hero__inner">
      <div class="fpw-ports-hero__content">
        <p class="fpw-ports-eyebrow"><a href="<cfoutput>#encodeForHTMLAttribute(libraryUrl)#</cfoutput>">Ports Library</a></p>
        <h1><cfoutput>#encodeForHTML(pageHeading)#</cfoutput></h1>
        <cfif detailSuccess>
          <p><cfoutput>#encodeForHTML(locationLine(portItem))#<cfif len(safeText(portItem.LOOP_SEGMENT))> on #encodeForHTML(portItem.LOOP_SEGMENT)#</cfif></cfoutput></p>
        <cfelse>
          <p>The requested Great Loop port is not available.</p>
        </cfif>
      </div>
      <cfif detailSuccess>
        <div class="fpw-ports-hero__media">
          <cfif structKeyExists(portImage, "hasImage") AND portImage.hasImage>
            <cfoutput>
              <button
                type="button"
                class="fpw-ports-header-image-button"
                data-port-image-open
                aria-controls="fpwPortImageModal"
                aria-expanded="false"
                aria-label="View larger image of #encodeForHTMLAttribute(portItem.NAME)#">
                <img
                  src="#encodeForHTMLAttribute(portImage.thumbnailUrl)#"
                  alt="#encodeForHTMLAttribute(portImageAlt)#"
                  class="fpw-ports-header-image"
                  loading="lazy"
                  decoding="async">
                <span class="fpw-ports-image-overlay">View larger</span>
              </button>
            </cfoutput>
          <cfelse>
            <div class="fpw-ports-header-image-placeholder" aria-hidden="true"></div>
          </cfif>
        </div>
      </cfif>
    </div>
  </section>

  <nav class="fpw-ports-breadcrumbs fpw-ports-shell" aria-label="Breadcrumb">
    <cfloop from="1" to="#arrayLen(portBreadcrumbItems)#" index="portBreadcrumbIndex">
      <cfset portBreadcrumbItem = portBreadcrumbItems[portBreadcrumbIndex]>
      <cfif portBreadcrumbIndex GT 1>
        <span aria-hidden="true">&rsaquo;</span>
      </cfif>
      <cfif structKeyExists(portBreadcrumbItem, "CURRENT") AND portBreadcrumbItem.CURRENT>
        <span><cfoutput>#encodeForHTML(portBreadcrumbItem.LABEL)#</cfoutput></span>
      <cfelseif len(safeText(portBreadcrumbItem.URL))>
        <a href="<cfoutput>#encodeForHTMLAttribute(portBreadcrumbItem.URL)#</cfoutput>"><cfoutput>#encodeForHTML(portBreadcrumbItem.LABEL)#</cfoutput></a>
      <cfelse>
        <span><cfoutput>#encodeForHTML(portBreadcrumbItem.LABEL)#</cfoutput></span>
      </cfif>
    </cfloop>
  </nav>

  <cfif NOT detailSuccess>
    <section class="fpw-ports-panel fpw-ports-shell">
      <h2>Port unavailable</h2>
      <p>The requested Great Loop port could not be found. Browse the main Ports Library to search available public planning references.</p>
      <a class="fpw-ports-btn fpw-ports-btn--primary" href="<cfoutput>#encodeForHTMLAttribute(libraryUrl)#</cfoutput>">Browse Ports Library</a>
    </section>
  <cfelse>
    <section class="fpw-ports-detail fpw-ports-shell">
      <div class="fpw-ports-detail-main">
        <section class="fpw-ports-panel">
          <cfif hasMap>
            <cfoutput>
              <div
                id="fpwPortDetailMap"
                class="fpw-ports-detail-map"
                data-lat="#encodeForHTMLAttribute(portItem.LAT)#"
                data-lng="#encodeForHTMLAttribute(portItem.LNG)#"
                data-name="#encodeForHTMLAttribute(portItem.NAME)#"
                data-location="#encodeForHTMLAttribute(locationLine(portItem))#"
                data-loop-segment="#encodeForHTMLAttribute(portItem.LOOP_SEGMENT)#"
                data-waterway="#encodeForHTMLAttribute(portItem.WATERWAY)#"
                data-url="#encodeForHTMLAttribute(portDetailUrl(portItem))#"></div>
            </cfoutput>
          <cfelse>
            <p>Map is unavailable because this port is not map-ready yet.</p>
          </cfif>
        </section>

        <section class="fpw-ports-panel">
          <h2>Overview</h2>
          <p><cfoutput>#encodeForHTML(safeText(portItem.SHORT_DESCRIPTION, "Overview details have not been verified yet."))#</cfoutput></p>
          <dl class="fpw-ports-fact-grid">
            <div><dt>Loop Segment</dt><dd><cfoutput>#encodeForHTML(safeText(portItem.LOOP_SEGMENT, "Not listed"))#</cfoutput></dd></div>
            <div><dt>Waterway</dt><dd><cfoutput>#encodeForHTML(safeText(portItem.WATERWAY, "Not listed"))#</cfoutput></dd></div>
            <div><dt>Mile Marker</dt><dd><cfoutput>#encodeForHTML(safeText(portItem.MILE_MARKER, "Not listed"))#</cfoutput></dd></div>
            <div><dt>Port Type</dt><dd><cfoutput>#encodeForHTML(safeText(portItem.PORT_TYPE, "Not listed"))#</cfoutput></dd></div>
          </dl>
        </section>

        <section class="fpw-ports-panel">
          <h2>Approach Notes</h2>
          <p><cfoutput>#encodeForHTML(safeText(portItem.APPROACH_NOTES, "Approach notes have not been verified yet."))#</cfoutput></p>
        </section>

        <section class="fpw-ports-panel">
          <h2>Services</h2>
          <cfif hasKnownService(services, serviceDefinitions)>
            <dl class="fpw-ports-service-grid">
              <cfloop array="#serviceDefinitions#" index="serviceDef">
                <cfif structKeyExists(services, serviceDef.key) AND len(serviceText(services[serviceDef.key]))>
                  <cfoutput><div><dt>#encodeForHTML(serviceDef.label)#</dt><dd>#encodeForHTML(serviceText(services[serviceDef.key]))#</dd></div></cfoutput>
                </cfif>
              </cfloop>
            </dl>
          <cfelse>
            <p>Service details have not been verified yet.</p>
          </cfif>
          <cfif len(safeText(portItem.SERVICES_SUMMARY))>
            <p><cfoutput>#encodeForHTML(portItem.SERVICES_SUMMARY)#</cfoutput></p>
          </cfif>
        </section>

        <section class="fpw-ports-panel">
          <h2>Nearby Assets</h2>
          <cfif arrayLen(nearbyAssets)>
            <div class="fpw-ports-related-assets">
              <cfloop array="#nearbyAssets#" index="assetItem">
                <cfoutput>
                  <article>
                    <strong>#encodeForHTML(safeText(assetItem.ASSET_NAME, assetItem.ASSET_TYPE))#</strong>
                    <span>#encodeForHTML(safeText(assetItem.ASSET_TYPE, "Asset"))#<cfif !isNull(assetItem.DISTANCE_NM)> - #encodeForHTML(assetItem.DISTANCE_NM)# nm</cfif></span>
                  </article>
                </cfoutput>
              </cfloop>
            </div>
          <cfelse>
            <p>Nearby assets have not been added for this port yet.</p>
          </cfif>
        </section>
      </div>

      <aside class="fpw-ports-detail-rail">
        <section class="fpw-ports-panel">
          <h2>Quick Facts</h2>
          <dl class="fpw-ports-fact-list">
            <div><dt>State / Province</dt><dd><cfoutput>#encodeForHTML(safeText(portItem.STATE, "Not listed"))#</cfoutput></dd></div>
            <div><dt>State Code</dt><dd><cfoutput>#encodeForHTML(safeText(portItem.STATE_CODE, "Not listed"))#</cfoutput></dd></div>
            <div><dt>Country</dt><dd><cfoutput>#encodeForHTML(safeText(portItem.COUNTRY, "Not listed"))#</cfoutput></dd></div>
            <div><dt>Coordinates</dt><dd><cfif hasValidCoordinates(portItem)><cfoutput>#encodeForHTML(portItem.LAT)#, #encodeForHTML(portItem.LNG)#</cfoutput><cfelse>Not map-ready</cfif></dd></div>
            <div><dt>Last Reviewed</dt><dd><cfoutput>#encodeForHTML(safeText(portItem.LAST_REVIEWED_AT, "Not listed"))#</cfoutput></dd></div>
          </dl>
        </section>

        <section class="fpw-ports-panel fpw-ports-add-waypoint-panel">
          <h2>Add to My Waypoints</h2>
          <button type="button" class="fpw-ports-btn fpw-ports-btn--primary fpw-ports-btn--full fpw-ports-member-only" data-port-add data-port-id="<cfoutput>#encodeForHTMLAttribute(portItem.ID)#</cfoutput>">Add to My Waypoints</button>
          <p class="fpw-ports-anon-only">Sign in to save this port to your custom waypoints. <a href="<cfoutput>#request.fpwBase#</cfoutput>/app/login.cfm">Log in</a> or <a href="<cfoutput>#request.fpwBase#</cfoutput>/app/join.cfm">join FPW</a>.</p>
          <p class="fpw-ports-add-status" data-port-add-status="<cfoutput>#encodeForHTMLAttribute(portItem.ID)#</cfoutput>" aria-live="polite"></p>
        </section>

        <section class="fpw-ports-panel fpw-ports-plan-panel">
          <h2>Plan With FPW</h2>
          <p>Create a free float plan that records your route, passengers, vessel details, and return plan.</p>
          <a class="fpw-ports-btn fpw-ports-btn--primary fpw-ports-btn--full" href="<cfoutput>#request.fpwBase#</cfoutput>/app/join.cfm">Create a free float plan</a>
        </section>

        <section class="fpw-ports-panel">
          <h2>Related Libraries</h2>
          <div class="fpw-ports-related-links fpw-ports-related-links--stack">
            <a href="<cfoutput>#request.fpwBase#</cfoutput>/great-loop/locks/">Great Loop Locks</a>
            <a href="<cfoutput>#request.fpwBase#</cfoutput>/great-loop/bridges/">Great Loop Bridges</a>
            <a href="<cfoutput>#request.fpwBase#</cfoutput>/great-loop/anchorages/">Great Loop Anchorages</a>
          </div>
        </section>

        <section class="fpw-ports-panel fpw-ports-safety">
          <h2>Planning-Only Notice</h2>
          <p>This port reference is for trip planning only. Always verify current charts, marina details, local notices, weather, depths, restrictions, and observed conditions before departure.</p>
        </section>
      </aside>
    </section>
  </cfif>

  <cfif detailSuccess AND structKeyExists(portImage, "hasImage") AND portImage.hasImage>
    <cfoutput>
      <div class="fpw-ports-image-modal" id="fpwPortImageModal" data-port-image-modal role="dialog" aria-modal="true" aria-labelledby="fpwPortImageModalTitle" hidden>
        <div class="fpw-ports-image-modal__backdrop" aria-hidden="true"></div>
        <div class="fpw-ports-image-modal__dialog" role="document">
          <div class="fpw-ports-image-modal__header">
            <h2 id="fpwPortImageModalTitle">#encodeForHTML(portItem.NAME)#</h2>
            <button type="button" class="fpw-ports-image-modal__close" data-port-image-close aria-label="Close image preview">&times;</button>
          </div>
          <div class="fpw-ports-image-modal__body">
            <img
              src="#encodeForHTMLAttribute(portImage.sourceUrl)#"
              alt="#encodeForHTMLAttribute(portImageAlt)#"
              class="fpw-ports-modal-image">
          </div>
        </div>
      </div>
    </cfoutput>
  </cfif>
</main>

<cfinclude template="../includes/footer.cfm">

<cfif detailSuccess>
  <script id="fpwPortDetailData" type="application/json"><cfoutput>#serializeJSON(portItem)#</cfoutput></script>
</cfif>
<script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js" integrity="sha256-20nQCchB9co0qIjJZRGuk2/Z9VM+kNiyxNV1lvTlZBo=" crossorigin=""></script>
<script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/maps/leaflet-noaa-waypoint-map.js?v=20260619-nautical-charts"></script>
<script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/app/ports-library.js?v=20260707-noaa-charts"></script>
</body>
</html>
