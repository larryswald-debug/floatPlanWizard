<cfprocessingdirective pageencoding="utf-8">
<cfsetting showdebugoutput="false" requesttimeout="30">
<cfcontent type="text/html; charset=utf-8">
<cfinclude template="../includes/fpw_base_path.cfm">

<cfscript>
request.fpwTopNavActive = "great-loop-locks";
slugValue = structKeyExists(url, "slug") ? trim(toString(url.slug)) : "";

try {
  lockSvc = createObject("component", "api.v1.GreatLoopLocksService").init();
} catch (any svcPathError) {
  lockSvc = createObject("component", "fpw.api.v1.GreatLoopLocksService").init();
}

isCleanLockRoute = structKeyExists(request, "fpwLockCleanRoute") AND request.fpwLockCleanRoute EQ true;
lockLibraryUrl = isCleanLockRoute
  ? request.fpwBase & "/great-loop/locks/"
  : request.fpwBase & "/app/great-loop-locks.cfm";
lockCanonicalBaseUrl = "https://floatplanwizard.com/great-loop/locks/";
lockDetailBaseUrl = request.fpwBase & "/great-loop/locks/";

function detailCleanLockSlug(required any value) {
  return lockSvc.normalizeSlug(arguments.value);
}

function detailLockDetailUrl(required any slugValue) {
  var slugPath = detailCleanLockSlug(arguments.slugValue);
  if (isCleanLockRoute AND len(slugPath)) {
    return lockDetailBaseUrl & slugPath & "/";
  }
  return request.fpwBase & "/app/great-loop-lock.cfm?slug=" & urlEncodedFormat(toString(arguments.slugValue));
}

function detailFilterUrl(required string keyName, required any keyValue) {
  if (!len(trim(toString(arguments.keyValue)))) {
    return lockLibraryUrl;
  }
  if (isCleanLockRoute AND compareNoCase(arguments.keyName, "state") EQ 0) {
    return lockLibraryUrl & "state/" & lockSvc.getStateSlug(arguments.keyValue) & "/";
  }
  if (isCleanLockRoute AND compareNoCase(arguments.keyName, "waterway") EQ 0) {
    return lockLibraryUrl & "waterway/" & detailCleanLockSlug(arguments.keyValue) & "/";
  }
  return lockLibraryUrl & "?" & arguments.keyName & "=" & encodeForURL(toString(arguments.keyValue));
}

detailModel = lockSvc.getLockBySlug(slugValue);
detailMapLat = "";
detailMapLng = "";
hasValidLockCoordinates = false;
lockStateDisplayName = "";
lockImage = {
  "hasImage" = false,
  "fileName" = "",
  "sourceUrl" = "",
  "thumbnailUrl" = ""
};

if (!detailModel.SUCCESS) {
  cfheader(statuscode = "404");
  lockItem = {};
  pageTitle = "Great Loop Lock Not Found | FloatPlanWizard";
  pageDescription = "The requested Great Loop lock reference page could not be found.";
  canonicalUrl = isCleanLockRoute ? "https://floatplanwizard.com/great-loop/locks/" : "https://floatplanwizard.com/app/great-loop-locks.cfm";
} else {
  lockItem = detailModel.LOCK;
  pageTitle = lockItem.lock_name & " Guide | Great Loop Lock Reference | FloatPlanWizard";
  pageDescription = "Find " & lockItem.lock_name & " location, phone, VHF channel, boater notes, approach guidance, and Great Loop trip-planning context from FloatPlanWizard.";
  canonicalUrl = isCleanLockRoute ? lockCanonicalBaseUrl & detailCleanLockSlug(lockItem.slug) & "/" : "https://floatplanwizard.com/app/great-loop-lock.cfm?slug=" & urlEncodedFormat(lockItem.slug);
  detailMapLat = trim(toString(lockItem.latitude));
  detailMapLng = trim(toString(lockItem.longitude));
  hasValidLockCoordinates = isNumeric(detailMapLat)
    AND isNumeric(detailMapLng)
    AND val(detailMapLat) GTE -90
    AND val(detailMapLat) LTE 90
    AND val(detailMapLng) GTE -180
    AND val(detailMapLng) LTE 180;
  lockStateDisplayName = len(trim(toString(lockItem.state))) ? lockSvc.getStateDisplayName(lockItem.state) : "";
}

function displayText(any value, string fallback="Not listed") {
  var txt = isNull(arguments.value) ? "" : trim(toString(arguments.value));
  return len(txt) ? txt : arguments.fallback;
}

function hasText(any value) {
  return len(trim(toString(isNull(arguments.value) ? "" : arguments.value))) GT 0;
}

if (detailModel.SUCCESS) {
  lockImage = lockSvc.getLockImageAsset(lockItem, request.fpwBase);
}

schemaAtKey = chr(64);
schemaTypeKey = schemaAtKey & "type";
schemaIdKey = schemaAtKey & "id";
schemaContextKey = schemaAtKey & "context";
schemaGraphKey = schemaAtKey & "graph";

function detailCanonicalFilterUrl(required string keyName, required any keyValue) {
  if (!len(trim(toString(arguments.keyValue)))) {
    return "https://floatplanwizard.com/great-loop/locks/";
  }
  if (compareNoCase(arguments.keyName, "state") EQ 0) {
    return "https://floatplanwizard.com/great-loop/locks/state/" & lockSvc.getStateSlug(arguments.keyValue) & "/";
  }
  if (compareNoCase(arguments.keyName, "waterway") EQ 0) {
    return "https://floatplanwizard.com/great-loop/locks/waterway/" & detailCleanLockSlug(arguments.keyValue) & "/";
  }
  return "https://floatplanwizard.com/great-loop/locks/";
}

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

detailJsonLd = {};
detailJsonLdText = "";

if (isCleanLockRoute AND detailModel.SUCCESS) {
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
  arrayAppend(detailSchemaBreadcrumb["itemListElement"], detailSchemaListItem(detailSchemaPosition++, "Great Loop Locks", "https://floatplanwizard.com/great-loop/locks/"));
  if (len(lockStateDisplayName)) {
    arrayAppend(detailSchemaBreadcrumb["itemListElement"], detailSchemaListItem(detailSchemaPosition++, lockStateDisplayName, detailCanonicalFilterUrl("state", lockItem.state)));
  }
  if (len(lockItem.waterway)) {
    arrayAppend(detailSchemaBreadcrumb["itemListElement"], detailSchemaListItem(detailSchemaPosition++, lockItem.waterway, detailCanonicalFilterUrl("waterway", lockItem.waterway)));
  }
  arrayAppend(detailSchemaBreadcrumb["itemListElement"], detailSchemaListItem(detailSchemaPosition, lockItem.lock_name, canonicalUrl));
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
  <meta property="og:type" content="article">
  <meta property="og:site_name" content="FloatPlanWizard">
  <meta property="og:url" content="<cfoutput>#encodeForHTMLAttribute(canonicalUrl)#</cfoutput>">
  <meta property="og:title" content="<cfoutput>#encodeForHTMLAttribute(pageTitle)#</cfoutput>">
  <meta property="og:description" content="<cfoutput>#encodeForHTMLAttribute(pageDescription)#</cfoutput>">
  <meta property="og:image" content="https://floatplanwizard.com/assets/images/social/floatplanwizard-social-preview-20260730.png">
  <meta property="og:image:secure_url" content="https://floatplanwizard.com/assets/images/social/floatplanwizard-social-preview-20260730.png">
  <meta property="og:image:type" content="image/png">
  <meta property="og:image:width" content="1200">
  <meta property="og:image:height" content="630">
  <meta property="og:image:alt" content="FloatPlanWizard boating trip planning and Great Loop lock reference preview image">
  <meta name="twitter:card" content="summary_large_image">
  <meta name="twitter:title" content="<cfoutput>#encodeForHTMLAttribute(pageTitle)#</cfoutput>">
  <meta name="twitter:description" content="<cfoutput>#encodeForHTMLAttribute(pageDescription)#</cfoutput>">
  <meta name="twitter:image" content="https://floatplanwizard.com/assets/images/social/floatplanwizard-social-preview-20260730.png">
  <meta name="twitter:image:alt" content="FloatPlanWizard boating trip planning and Great Loop lock reference preview image">
  <cfif len(detailJsonLdText)>
    <script type="application/ld+json"><cfoutput>#detailJsonLdText#</cfoutput></script>
  </cfif>
  <link rel="stylesheet" href="<cfoutput>#request.fpwBase#</cfoutput>/assets/css/layout.css?v=20260620-page-width">
<link rel="stylesheet" href="<cfoutput>#request.fpwBase#</cfoutput>/assets/css/top-nav.css?v=20260824-boating-safety-nav-v2">
  <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" integrity="sha256-p4NxAoJBhIIN+hmNHrzRCf9tD/miZyoHS5obTRR9BMY=" crossorigin="">
  <link rel="stylesheet" href="<cfoutput>#request.fpwBase#</cfoutput>/assets/css/great-loop-locks.css?v=20260814-detail-context-links-v3">
  <cfinclude template="../includes/analytics_ga4.cfm">
  <cfinclude template="../includes/analytics_clarity.cfm">
  <cfinclude template="../includes/trustedsite.cfm">
</head>
<body id="top" class="fpw-lock-body">
<cfinclude template="../includes/top_nav.cfm">

<main class="fpw-lock-library-page fpw-lock-detail-page">
  <section class="fpw-lock-compact-hero">
    <p class="fpw-lock-eyebrow">Great Loop Lock Reference</p>
    <h1><cfoutput>#encodeForHTML(detailModel.SUCCESS ? lockItem.lock_name : "Lock Not Found")#</cfoutput></h1>
    <p>Reviewed planning reference for lock approach, communications, and float-plan preparation.</p>
  </section>

  <cfif NOT detailModel.SUCCESS>
    <section class="fpw-lock-detail-preview">
      <div class="fpw-lock-panel fpw-lock-not-found">
        <h2>That lock page is not available.</h2>
        <p>The lock may not be published yet, or the link may be incorrect.</p>
        <a class="fpw-lock-btn fpw-lock-btn--primary" href="<cfoutput>#encodeForHTMLAttribute(lockLibraryUrl)#</cfoutput>">Back to Great Loop Locks</a>
      </div>
    </section>
  <cfelse>
    <section class="fpw-lock-detail-preview">
      <div class="fpw-lock-detail-main">
        <nav class="fpw-lock-breadcrumbs" aria-label="Breadcrumb">
          <a href="<cfoutput>#encodeForHTMLAttribute(lockLibraryUrl)#</cfoutput>">Great Loop Locks</a>
          <cfif isCleanLockRoute AND len(lockStateDisplayName)>
            <span>&rsaquo;</span>
            <a href="<cfoutput>#encodeForHTMLAttribute(detailFilterUrl("state", lockItem.state))#</cfoutput>"><cfoutput>#encodeForHTML(lockStateDisplayName)#</cfoutput></a>
          </cfif>
          <cfif len(lockItem.waterway)>
            <span>&rsaquo;</span>
            <a href="<cfoutput>#encodeForHTMLAttribute(detailFilterUrl("waterway", lockItem.waterway))#</cfoutput>"><cfoutput>#encodeForHTML(lockItem.waterway)#</cfoutput></a>
          </cfif>
          <span>&rsaquo;</span>
          <span><cfoutput>#encodeForHTML(lockItem.lock_name)#</cfoutput></span>
        </nav>

        <article class="fpw-lock-panel fpw-lock-detail-card">
          <div class="fpw-lock-detail-header">
            <cfif lockImage.hasImage>
              <cfoutput>
                <button
                  type="button"
                  class="fpw-lock-header-image-button"
                  data-lock-image-open
                  aria-controls="fpwLockImageModal"
                  aria-expanded="false"
                  aria-label="View larger image of #encodeForHTMLAttribute(lockItem.lock_name)#">
                  <img
                    src="#encodeForHTMLAttribute(lockImage.thumbnailUrl)#"
                    alt="#encodeForHTMLAttribute(lockItem.lock_name)# lock image"
                    class="fpw-lock-header-image"
                    loading="lazy"
                    decoding="async">
                  <span class="fpw-lock-image-overlay">View larger</span>
                </button>
              </cfoutput>
            <cfelse>
              <div class="fpw-lock-photo-placeholder" aria-hidden="true"></div>
            </cfif>
            <div>
              <p class="fpw-lock-eyebrow"><cfoutput>#encodeForHTML(displayText(lockItem.waterway, "Published lock reference"))#</cfoutput></p>
              <h2><cfoutput>#encodeForHTML(lockItem.lock_name)#</cfoutput></h2>
              <p><cfoutput>#encodeForHTML(lockItem.city)#<cfif len(lockItem.city) AND len(lockItem.state)>, </cfif>#encodeForHTML(lockItem.state)#<cfif len(lockItem.country)> &bull; #encodeForHTML(lockItem.country)#</cfif></cfoutput></p>
            </div>
          </div>

          <div class="fpw-lock-quick-grid">
            <div><span>Latitude / Longitude</span><strong><cfoutput>#encodeForHTML(lockItem.latitude)#<br>#encodeForHTML(lockItem.longitude)#</cfoutput></strong></div>
            <div><span>Phone</span><strong><cfoutput>#encodeForHTML(displayText(lockItem.phone))#</cfoutput></strong></div>
            <div><span>VHF Channel</span><strong><cfoutput>#encodeForHTML(displayText(lockItem.vhf))#</cfoutput></strong></div>
            <div><span>Operating Authority</span><strong><cfoutput>#encodeForHTML(displayText(lockItem.operating_authority))#</cfoutput></strong></div>
            <div><span>Last Reviewed</span><strong><cfoutput>#encodeForHTML(displayText(lockItem.last_reviewed_at))#</cfoutput></strong></div>
          </div>
        </article>

        <section class="fpw-lock-panel fpw-lock-location-map-card">
          <div class="fpw-lock-section-heading">
            <div>
              <h3>Lock Location</h3>
              <p>Zoomed-in location for this Great Loop lock reference.</p>
            </div>
          </div>

          <cfif hasValidLockCoordinates>
            <cfoutput>
              <div
                id="fpwLockDetailMap"
                class="fpw-lock-detail-map"
                data-lat="#encodeForHTMLAttribute(detailMapLat)#"
                data-lng="#encodeForHTMLAttribute(detailMapLng)#"
                data-lock-name="#encodeForHTMLAttribute(lockItem.lock_name)#"
                data-city="#encodeForHTMLAttribute(lockItem.city)#"
                data-state="#encodeForHTMLAttribute(lockItem.state)#"
                data-waterway="#encodeForHTMLAttribute(lockItem.waterway)#"
                data-phone="#encodeForHTMLAttribute(lockItem.phone)#"
                data-vhf="#encodeForHTMLAttribute(lockItem.vhf)#"></div>
            </cfoutput>
          <cfelse>
            <p>Location map is unavailable because this lock does not have valid coordinates yet.</p>
          </cfif>
        </section>

        <div class="fpw-lock-detail-grid">
          <aside class="fpw-lock-panel fpw-lock-snapshot">
            <h3>Boater Snapshot</h3>
            <dl>
              <div><dt>Waterway</dt><dd><cfoutput>#encodeForHTML(displayText(lockItem.waterway))#</cfoutput></dd></div>
              <div><dt>Lock System</dt><dd><cfoutput>#encodeForHTML(displayText(lockItem.lock_system))#</cfoutput></dd></div>
              <div><dt>City / State</dt><dd><cfoutput>#encodeForHTML(displayText(trim(lockItem.city & " " & lockItem.state)))#</cfoutput></dd></div>
              <div><dt>Postal Code</dt><dd><cfoutput>#encodeForHTML(displayText(lockItem.zip))#</cfoutput></dd></div>
            </dl>
          </aside>

          <div class="fpw-lock-detail-copy">
            <section class="fpw-lock-panel">
              <h3>About This Lock</h3>
              <p><cfoutput>#encodeForHTML(displayText(lockItem.note, "Reviewed notes are not listed for this lock yet."))#</cfoutput></p>
            </section>

            <cfif hasText(lockItem.approach_notes)>
              <section class="fpw-lock-panel"><h3>Approach Notes</h3><p><cfoutput>#encodeForHTML(lockItem.approach_notes)#</cfoutput></p></section>
            </cfif>
            <cfif hasText(lockItem.operating_notes)>
              <section class="fpw-lock-panel"><h3>Operating Notes</h3><p><cfoutput>#encodeForHTML(lockItem.operating_notes)#</cfoutput></p></section>
            </cfif>
            <cfif hasText(lockItem.special_instructions)>
              <section class="fpw-lock-panel"><h3>Special Instructions</h3><p><cfoutput>#encodeForHTML(lockItem.special_instructions)#</cfoutput></p></section>
            </cfif>

            <p class="fpw-lock-continue-planning">
              <strong>Continue planning:</strong>
              Check <a href="<cfoutput>#encodeForHTMLAttribute(request.fpwBase & '/app/weather.cfm')#</cfoutput>">Marine Weather</a>, estimate your trip with the <a href="<cfoutput>#encodeForHTMLAttribute(request.fpwBase & '/boat-fuel-calculator/')#</cfoutput>">Boat Fuel Calculator</a>, or review the <a href="<cfoutput>#encodeForHTMLAttribute(request.fpwBase & '/solo-boating-safety-guide/')#</cfoutput>">Solo Boating Safety Guide</a>.
            </p>

            <section class="fpw-lock-panel fpw-lock-nav-pager">
              <cfif structKeyExists(detailModel.PREVIOUS, "slug")>
                <a href="<cfoutput>#encodeForHTMLAttribute(detailLockDetailUrl(detailModel.PREVIOUS.slug))#</cfoutput>">&larr; <cfoutput>#encodeForHTML(detailModel.PREVIOUS.lock_name)#</cfoutput></a>
              <cfelse>
                <span></span>
              </cfif>
              <cfif structKeyExists(detailModel.NEXT, "slug")>
                <a href="<cfoutput>#encodeForHTMLAttribute(detailLockDetailUrl(detailModel.NEXT.slug))#</cfoutput>"><cfoutput>#encodeForHTML(detailModel.NEXT.lock_name)#</cfoutput> &rarr;</a>
              </cfif>
            </section>
          </div>
        </div>
      </div>

      <aside class="fpw-lock-detail-rail">
        <section class="fpw-lock-panel">
          <h3>Before You Arrive</h3>
          <ul class="fpw-lock-checklist">
            <li>Fenders ready</li>
            <li>Lines ready</li>
            <li>Crew briefed</li>
            <li>PFDs on deck</li>
            <li>Radio on correct channel</li>
            <li>Call / monitor lock</li>
            <li>Check current notices</li>
          </ul>
        </section>

        <section class="fpw-lock-panel fpw-lock-plan-panel">
          <h3>Plan With FPW</h3>
          <p>Add lock planning context to your route and account for lock delays in your float plan.</p>
          <a class="fpw-lock-btn fpw-lock-btn--primary fpw-lock-btn--full" href="<cfoutput>#request.fpwBase#</cfoutput>/app/join.cfm">Plan Your Route</a>
        </section>

        <section class="fpw-lock-panel fpw-lock-related-resources" aria-labelledby="fpwLockRelatedResourcesTitle">
          <h3 id="fpwLockRelatedResourcesTitle">Related Safety Resources</h3>
          <div class="fpw-lock-related-resource-list">
            <a class="fpw-lock-related-resource" href="<cfoutput>#encodeForHTMLAttribute(request.fpwBase & '/solo-boating-safety-guide/')#</cfoutput>">
              <span class="fpw-lock-related-resource__icon" aria-hidden="true"><cfoutput>#renderFpwNavIcon("kayak", "fpw-lock-related-resource__icon-svg")#</cfoutput></span>
              <span class="fpw-lock-related-resource__copy">
                <strong>Solo Boating Safety Guide</strong>
                <span>Running the Loop solo? Review practical preparation, communications, self-recovery, and trip-planning guidance before departure.</span>
              </span>
              <span class="fpw-lock-related-resource__arrow" aria-hidden="true">&rarr;</span>
            </a>
            <a class="fpw-lock-related-resource" href="<cfoutput>#encodeForHTMLAttribute(request.fpwBase & '/shore-contact-overdue-boater/')#</cfoutput>">
              <span class="fpw-lock-related-resource__icon" aria-hidden="true"><cfoutput>#renderFpwNavIcon("checklist", "fpw-lock-related-resource__icon-svg")#</cfoutput></span>
              <span class="fpw-lock-related-resource__copy">
                <strong>Shore Contact Guide</strong>
                <span>Leaving a float plan with someone ashore? Make sure they know what to do if you miss a check-in or become overdue.</span>
              </span>
              <span class="fpw-lock-related-resource__arrow" aria-hidden="true">&rarr;</span>
            </a>
          </div>
        </section>

        <section class="fpw-lock-panel">
          <h3>Official Source</h3>
          <cfif len(lockItem.source_url)>
            <p><cfoutput>#encodeForHTML(displayText(lockItem.source_name, "Official source"))#</cfoutput></p>
            <a href="<cfoutput>#encodeForHTMLAttribute(lockItem.source_url)#</cfoutput>" rel="nofollow noopener" target="_blank">Open official source</a>
          <cfelse>
            <p>Official source information is not listed for this reviewed row yet.</p>
          </cfif>
        </section>

        <section class="fpw-lock-panel fpw-lock-safety-note">
          <h3>Navigation Safety Note</h3>
          <p>This page is a planning reference, not a substitute for official notices, charts, lockmaster instructions, or current local conditions. Always confirm lock status, operating hours, closures, restrictions, and instructions with the official authority before arrival.</p>
        </section>
      </aside>
    </section>

    <cfif lockImage.hasImage>
      <cfoutput>
        <div class="fpw-lock-image-modal" id="fpwLockImageModal" data-lock-image-modal role="dialog" aria-modal="true" aria-labelledby="fpwLockImageModalTitle" hidden>
          <div class="fpw-lock-image-modal__backdrop" aria-hidden="true"></div>
          <div class="fpw-lock-image-modal__dialog" role="document">
            <div class="fpw-lock-image-modal__header">
              <h2 id="fpwLockImageModalTitle">#encodeForHTML(lockItem.lock_name)#</h2>
              <button type="button" class="fpw-lock-image-modal__close" data-lock-image-close aria-label="Close image preview">&times;</button>
            </div>
            <div class="fpw-lock-image-modal__body">
              <img
                src="#encodeForHTMLAttribute(lockImage.sourceUrl)#"
                alt="#encodeForHTMLAttribute(lockItem.lock_name)# lock image"
                class="fpw-lock-modal-image">
            </div>
          </div>
        </div>
      </cfoutput>
    </cfif>
  </cfif>
</main>

<cfinclude template="../includes/footer.cfm">
<cfif detailModel.SUCCESS>
  <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js" integrity="sha256-20nQCchB9co0qIjJZRGuk2/Z9VM+kNiyxNV1lvTlZBo=" crossorigin=""></script>
  <script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/maps/leaflet-noaa-waypoint-map.js?v=20260619-nautical-charts"></script>
  <script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/app/great-loop-locks.js?v=20260619-noaa-charts"></script>
</cfif>
</body>
</html>
