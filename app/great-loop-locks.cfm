<cfprocessingdirective pageencoding="utf-8">
<cfsetting showdebugoutput="false" requesttimeout="30">
<cfcontent type="text/html; charset=utf-8">
<cfinclude template="../includes/fpw_base_path.cfm">

<cfscript>
request.fpwTopNavActive = "great-loop-locks";
filters = {
  "state" = structKeyExists(url, "state") ? trim(toString(url.state)) : "",
  "waterway" = structKeyExists(url, "waterway") ? trim(toString(url.waterway)) : "",
  "limit" = "300"
};

try {
  lockSvc = createObject("component", "api.v1.GreatLoopLocksService").init();
} catch (any svcPathError) {
  lockSvc = createObject("component", "fpw.api.v1.GreatLoopLocksService").init();
}

libraryModel = lockSvc.getLibraryModel(filters);
filterOptions = lockSvc.getFilterOptions(filters);
lockRows = libraryModel.LOCKS;
stateFacets = filterOptions.states;
waterwayFacets = filterOptions.waterways;
browseStateFacets = libraryModel.STATES;
browseWaterwayFacets = libraryModel.WATERWAYS;
stats = libraryModel.STATS;
isCleanLockRoute = structKeyExists(request, "fpwLockCleanRoute") AND request.fpwLockCleanRoute EQ true;
taxonomyType = structKeyExists(request, "fpwLockTaxonomyType") ? trim(toString(request.fpwLockTaxonomyType)) : "";
taxonomyName = structKeyExists(request, "fpwLockTaxonomyName") ? trim(toString(request.fpwLockTaxonomyName)) : "";
taxonomyCount = structKeyExists(request, "fpwLockTaxonomyCount") ? val(request.fpwLockTaxonomyCount) : arrayLen(lockRows);
isTaxonomyRoute = len(taxonomyType) AND taxonomyType NEQ "not-found";
isLockHubRoute = !len(taxonomyType);
lockLibraryUrl = isCleanLockRoute
  ? request.fpwBase & "/great-loop/locks/"
  : request.fpwBase & "/app/great-loop-locks.cfm";
lockCanonicalUrl = isCleanLockRoute
  ? "https://floatplanwizard.com/great-loop/locks/"
  : "https://floatplanwizard.com/app/great-loop-locks.cfm";
pageTitle = "Great Loop Lock Reference Library | VHF, Phone & Planning Notes";
pageDescription = "Browse Great Loop lock locations, VHF channels, phone numbers, approach notes, and planning details for safer recreational cruising.";
pageOgDescription = pageDescription;
pageHeading = "Great Loop Lock Reference Library";
pageLede = "Find lock locations, phone numbers, VHF channels, operating notes, approach details, and boater-friendly guidance for locks along the Great Loop.";

if (structKeyExists(request, "fpwLockTaxonomyCanonicalUrl") AND len(trim(toString(request.fpwLockTaxonomyCanonicalUrl)))) {
  lockCanonicalUrl = trim(toString(request.fpwLockTaxonomyCanonicalUrl));
}

if (taxonomyType EQ "state" AND len(taxonomyName)) {
  pageTitle = taxonomyName & " Great Loop Locks | Locations, VHF Channels & Notes";
  pageDescription = "Browse " & taxonomyName & " Great Loop locks with VHF channels, phone numbers, approach notes, and planning details for safer cruising.";
  pageOgDescription = pageDescription;
  pageHeading = taxonomyName & " Great Loop Locks";
  pageLede = "Explore " & taxonomyCount & " reviewed public Great Loop lock references in " & taxonomyName & ", including locations, VHF channels, phone numbers, waterways, and planning notes.";
} else if (taxonomyType EQ "waterway" AND len(taxonomyName)) {
  pageTitle = taxonomyName & " Locks | Great Loop Lock Guide";
  pageDescription = "Browse " & taxonomyName & " locks with Great Loop lock locations, VHF channels, phone numbers, approach notes, and boater planning details.";
  pageOgDescription = pageDescription;
  pageHeading = taxonomyName & " Locks";
  pageLede = "Explore " & taxonomyCount & " reviewed public lock references on the " & taxonomyName & ", including locations, VHF channels, phone numbers, and boater planning notes.";
} else if (taxonomyType EQ "not-found") {
  pageTitle = "Great Loop Lock Page Not Found | FloatPlanWizard";
  pageDescription = "The requested Great Loop lock state or waterway page could not be found.";
  pageOgDescription = pageDescription;
  pageHeading = taxonomyName;
  pageLede = "The requested Great Loop lock state or waterway page could not be found. Browse the main lock library to find reviewed public lock references.";
  lockRows = [];
}
lockDetailBaseUrl = request.fpwBase & "/great-loop/locks/";
lockDetailDataBaseUrl = isCleanLockRoute ? lockDetailBaseUrl : "";
mapRows = [];
waterwayThumbnailRows = lockSvc.searchLocks({ "limit" = "500" }).ROWS;
waterwayThumbnailMap = {};

function libraryCleanLockSlug(required any value) {
  return lockSvc.normalizeSlug(arguments.value);
}

function libraryLockDetailUrl(required any slugValue) {
  var slugPath = libraryCleanLockSlug(arguments.slugValue);
  if (isCleanLockRoute AND len(slugPath)) {
    return lockDetailBaseUrl & slugPath & "/";
  }
  return request.fpwBase & "/app/great-loop-lock.cfm?slug=" & urlEncodedFormat(toString(arguments.slugValue));
}

function libraryFilterUrl(required string keyName, required any keyValue) {
  if (!len(trim(toString(arguments.keyValue)))) {
    return lockLibraryUrl;
  }
  if (isCleanLockRoute AND compareNoCase(arguments.keyName, "state") EQ 0) {
    return lockLibraryUrl & "state/" & lockSvc.getStateSlug(arguments.keyValue) & "/";
  }
  if (isCleanLockRoute AND compareNoCase(arguments.keyName, "waterway") EQ 0) {
    return lockLibraryUrl & "waterway/" & libraryCleanLockSlug(arguments.keyValue) & "/";
  }
  return lockLibraryUrl & "?" & arguments.keyName & "=" & encodeForURL(toString(arguments.keyValue));
}

function libraryAnchorUrl(required string anchorName) {
  return lockLibraryUrl & "##" & arguments.anchorName;
}

hubSampleLimit = 6;
hubSampleLockRows = [];
finderLockRows = lockRows;
schemaLockRows = lockRows;

if (isLockHubRoute) {
  for (hubSampleIndex = 1; hubSampleIndex LTE min(hubSampleLimit, arrayLen(lockRows)); hubSampleIndex++) {
    arrayAppend(hubSampleLockRows, lockRows[hubSampleIndex]);
  }

  finderLockRows = hubSampleLockRows;
  schemaLockRows = hubSampleLockRows;
}

for (lockItem in lockRows) {
  if (isNumeric(lockItem.latitude) AND isNumeric(lockItem.longitude)) {
    arrayAppend(mapRows, {
      "name" = lockItem.lock_name,
      "slug" = lockItem.slug,
      "city" = lockItem.city,
      "state" = lockItem.state,
      "waterway" = lockItem.waterway,
      "vhf" = lockItem.vhf,
      "phone" = lockItem.phone,
      "lat" = val(lockItem.latitude),
      "lng" = val(lockItem.longitude),
      "url" = libraryLockDetailUrl(lockItem.slug)
    });
  }
}

for (waterwayLock in waterwayThumbnailRows) {
  if (!structKeyExists(waterwayLock, "waterway") OR !len(trim(toString(waterwayLock.waterway)))) {
    continue;
  }

  waterwayKey = trim(toString(waterwayLock.waterway));
  if (structKeyExists(waterwayThumbnailMap, waterwayKey)) {
    continue;
  }

  waterwayImage = lockSvc.getLockImageAsset(waterwayLock, request.fpwBase);
  if (structKeyExists(waterwayImage, "hasThumbnail") AND waterwayImage.hasThumbnail) {
    waterwayThumbnailMap[waterwayKey] = {
      "thumbnailUrl" = waterwayImage.thumbnailUrl,
      "lockName" = waterwayLock.lock_name
    };
  }
}

function selectedAttr(required string leftValue, required string rightValue) {
  return compareNoCase(trim(arguments.leftValue), trim(arguments.rightValue)) EQ 0 ? " selected" : "";
}

schemaAtKey = chr(64);
schemaTypeKey = schemaAtKey & "type";
schemaIdKey = schemaAtKey & "id";
schemaContextKey = schemaAtKey & "context";
schemaGraphKey = schemaAtKey & "graph";

function libraryCanonicalLockUrl(required any slugValue) {
  var slugPath = libraryCleanLockSlug(arguments.slugValue);
  return len(slugPath) ? "https://floatplanwizard.com/great-loop/locks/" & slugPath & "/" : lockCanonicalUrl;
}

function libraryCanonicalFilterUrl(required string keyName, required any keyValue) {
  if (!len(trim(toString(arguments.keyValue)))) {
    return "https://floatplanwizard.com/great-loop/locks/";
  }
  if (compareNoCase(arguments.keyName, "state") EQ 0) {
    return "https://floatplanwizard.com/great-loop/locks/state/" & lockSvc.getStateSlug(arguments.keyValue) & "/";
  }
  if (compareNoCase(arguments.keyName, "waterway") EQ 0) {
    return "https://floatplanwizard.com/great-loop/locks/waterway/" & libraryCleanLockSlug(arguments.keyValue) & "/";
  }
  return "https://floatplanwizard.com/great-loop/locks/";
}

function librarySchemaRef(required string idValue) {
  var out = structNew("ordered");
  structInsert(out, schemaIdKey, arguments.idValue, true);
  return out;
}

function librarySchemaListItem(required numeric position, required string name, required string urlValue) {
  var out = structNew("ordered");
  var item = structNew("ordered");
  structInsert(out, schemaTypeKey, "ListItem", true);
  out["position"] = arguments.position;
  structInsert(item, schemaIdKey, arguments.urlValue, true);
  item["name"] = arguments.name;
  out["item"] = item;
  return out;
}

pageJsonLd = {};
pageJsonLdText = "";

if (isCleanLockRoute AND taxonomyType NEQ "not-found") {
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
  schemaWebsite["publisher"] = librarySchemaRef("https://floatplanwizard.com/##organization");
  arrayAppend(schemaGraph, schemaWebsite);

  structInsert(schemaBreadcrumb, schemaTypeKey, "BreadcrumbList", true);
  structInsert(schemaBreadcrumb, schemaIdKey, lockCanonicalUrl & "##breadcrumb", true);
  schemaBreadcrumb["itemListElement"] = [];
  arrayAppend(schemaBreadcrumb["itemListElement"], librarySchemaListItem(1, "FloatPlanWizard", "https://floatplanwizard.com/"));
  arrayAppend(schemaBreadcrumb["itemListElement"], librarySchemaListItem(2, "Great Loop Locks", "https://floatplanwizard.com/great-loop/locks/"));
  if (isTaxonomyRoute AND len(taxonomyName)) {
    arrayAppend(schemaBreadcrumb["itemListElement"], librarySchemaListItem(3, pageHeading, lockCanonicalUrl));
  }
  arrayAppend(schemaGraph, schemaBreadcrumb);

  structInsert(schemaPage, schemaTypeKey, "CollectionPage", true);
  structInsert(schemaPage, schemaIdKey, lockCanonicalUrl & "##webpage", true);
  schemaPage["url"] = lockCanonicalUrl;
  schemaPage["name"] = pageTitle;
  schemaPage["description"] = pageDescription;
  schemaPage["isPartOf"] = librarySchemaRef("https://floatplanwizard.com/##website");
  schemaPage["publisher"] = librarySchemaRef("https://floatplanwizard.com/##organization");
  schemaPage["breadcrumb"] = librarySchemaRef(lockCanonicalUrl & "##breadcrumb");
  arrayAppend(schemaGraph, schemaPage);

  structInsert(schemaItemList, schemaTypeKey, "ItemList", true);
  structInsert(schemaItemList, schemaIdKey, lockCanonicalUrl & "##itemlist", true);
  schemaItemList["name"] = isTaxonomyRoute AND len(taxonomyName) ? "Locks in " & taxonomyName : "Great Loop lock references";
  schemaItemList["numberOfItems"] = arrayLen(schemaLockRows);
  schemaItemList["itemListElement"] = [];

  for (schemaLock in schemaLockRows) {
    schemaListEntry = structNew("ordered");
    schemaLockPage = structNew("ordered");
    structInsert(schemaListEntry, schemaTypeKey, "ListItem", true);
    schemaListEntry["position"] = schemaPosition;
    structInsert(schemaLockPage, schemaTypeKey, "WebPage", true);
    structInsert(schemaLockPage, schemaIdKey, libraryCanonicalLockUrl(schemaLock.slug), true);
    schemaLockPage["url"] = libraryCanonicalLockUrl(schemaLock.slug);
    schemaLockPage["name"] = schemaLock.lock_name;
    if (len(trim(toString(schemaLock.city))) OR len(trim(toString(schemaLock.state))) OR len(trim(toString(schemaLock.waterway)))) {
      schemaLockPage["description"] = trim(schemaLock.city & (len(schemaLock.city) AND len(schemaLock.state) ? ", " : " ") & schemaLock.state & (len(schemaLock.waterway) ? " - " & schemaLock.waterway : ""));
    }
    schemaListEntry["item"] = schemaLockPage;
    arrayAppend(schemaItemList["itemListElement"], schemaListEntry);
    schemaPosition++;
  }
  arrayAppend(schemaGraph, schemaItemList);

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
  <link rel="canonical" href="<cfoutput>#encodeForHTMLAttribute(lockCanonicalUrl)#</cfoutput>">
  <meta property="og:type" content="website">
  <meta property="og:site_name" content="FloatPlanWizard">
  <meta property="og:url" content="<cfoutput>#encodeForHTMLAttribute(lockCanonicalUrl)#</cfoutput>">
  <meta property="og:title" content="<cfoutput>#encodeForHTMLAttribute(pageTitle)#</cfoutput>">
  <meta property="og:description" content="<cfoutput>#encodeForHTMLAttribute(pageOgDescription)#</cfoutput>">
  <meta property="og:image" content="https://floatplanwizard.com/assets/images/social/floatplanwizard-social-preview-20260602.png">
  <meta property="og:image:secure_url" content="https://floatplanwizard.com/assets/images/social/floatplanwizard-social-preview-20260602.png">
  <meta property="og:image:type" content="image/png">
  <meta property="og:image:width" content="1200">
  <meta property="og:image:height" content="630">
  <meta property="og:image:alt" content="FloatPlanWizard boating trip planning and Great Loop lock reference preview image">
  <meta name="twitter:card" content="summary_large_image">
  <meta name="twitter:title" content="<cfoutput>#encodeForHTMLAttribute(pageTitle)#</cfoutput>">
  <meta name="twitter:description" content="<cfoutput>#encodeForHTMLAttribute(pageOgDescription)#</cfoutput>">
  <meta name="twitter:image" content="https://floatplanwizard.com/assets/images/social/floatplanwizard-social-preview-20260602.png">
  <meta name="twitter:image:alt" content="FloatPlanWizard boating trip planning and Great Loop lock reference preview image">
  <cfif len(pageJsonLdText)>
    <script type="application/ld+json"><cfoutput>#pageJsonLdText#</cfoutput></script>
  </cfif>
  <link rel="stylesheet" href="<cfoutput>#request.fpwBase#</cfoutput>/assets/css/top-nav.css?v=20260530-nav-cta">
  <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" integrity="sha256-p4NxAoJBhIIN+hmNHrzRCf9tD/miZyoHS5obTRR9BMY=" crossorigin="">
  <link rel="stylesheet" href="<cfoutput>#request.fpwBase#</cfoutput>/assets/css/great-loop-locks.css?v=20260616-bridge-header-width">
  <cfinclude template="../includes/analytics_ga4.cfm">
  <cfinclude template="../includes/analytics_clarity.cfm">
</head>
<body id="top" class="fpw-lock-body">
<cfinclude template="../includes/top_nav.cfm">

<main class="fpw-lock-library-page">
  <section class="fpw-lock-hero fpw-lock-library-hero">
    <div class="fpw-lock-hero__inner">
      <div class="fpw-lock-hero__content">
        <p class="fpw-lock-eyebrow">Great Loop Planning Resource</p>
        <h1><cfoutput>#encodeForHTML(pageHeading)#</cfoutput></h1>
        <p class="fpw-lock-hero__lede">
          <cfoutput>#encodeForHTML(pageLede)#</cfoutput>
        </p>
      </div>
    </div>
  </section>

  <section class="fpw-lock-stats" aria-label="Great Loop lock library summary">
    <div><strong><cfoutput>#encodeForHTML(stats.PUBLIC_ROWS)#</cfoutput></strong><span>Reviewed public locks</span></div>
    <div><strong><cfoutput>#encodeForHTML(stats.STATE_COUNT)#</cfoutput></strong><span>States / provinces</span></div>
    <div><strong><cfoutput>#encodeForHTML(stats.WATERWAY_COUNT)#</cfoutput></strong><span>Waterways</span></div>
    <div><strong><cfoutput>#encodeForHTML(stats.TOTAL_ROWS)#</cfoutput></strong><span>Total imported reference rows</span></div>
  </section>

  <cfif isLockHubRoute>
    <section class="fpw-lock-cta fpw-lock-panel" aria-labelledby="fpwLockCtaTitle">
      <div>
        <p class="fpw-lock-eyebrow">Plan With FPW</p>
        <h2 id="fpwLockCtaTitle">Planning a route with locks?</h2>
        <p>Add lock timing context to your route and create a free float plan before departure.</p>
      </div>
      <a class="fpw-lock-btn fpw-lock-btn--primary" href="<cfoutput>#request.fpwBase#</cfoutput>/app/join.cfm"><span>Plan Your Route</span><span class="fpw-cta-arrow" aria-hidden="true">&rarr;</span></a>
    </section>
  </cfif>

  <section class="fpw-lock-shell" id="fpwLockFinder" aria-labelledby="fpwLockFinderTitle">
    <aside class="fpw-lock-panel fpw-lock-filters">
      <h2 id="fpwLockFinderTitle">Find Locks</h2>
      <form method="get" action="<cfoutput>#encodeForHTMLAttribute(lockLibraryUrl)#</cfoutput>" data-lock-filter-form data-lock-api-endpoint="<cfoutput>#request.fpwApiBase#</cfoutput>/greatLoopLocks.cfc?method=handle&returnFormat=json" data-lock-page-url="<cfoutput>#encodeForHTMLAttribute(lockLibraryUrl)#</cfoutput>" data-lock-detail-url-base="<cfoutput>#encodeForHTMLAttribute(lockDetailDataBaseUrl)#</cfoutput>">
        <label class="fpw-lock-field">
          <span>State / Province</span>
          <select name="state" data-lock-state-select>
            <option value="">All</option>
            <cfloop array="#stateFacets#" index="facet">
              <cfoutput><option value="#encodeForHTMLAttribute(facet.value)#"#selectedAttr(filters.state, facet.value)#>#encodeForHTML(facet.label)#</option></cfoutput>
            </cfloop>
          </select>
        </label>

        <label class="fpw-lock-field">
          <span>Waterway / System</span>
          <select name="waterway" data-lock-waterway-select>
            <option value="">All</option>
            <cfloop array="#waterwayFacets#" index="facet">
              <cfoutput><option value="#encodeForHTMLAttribute(facet.value)#"#selectedAttr(filters.waterway, facet.value)#>#encodeForHTML(facet.label)#</option></cfoutput>
            </cfloop>
          </select>
        </label>

        <div class="fpw-lock-filter-actions">
          <button type="submit" class="fpw-cta fpw-cta-primary" data-lock-apply><span>Apply Filters</span></button>
          <a class="fpw-cta fpw-cta-primary" href="<cfoutput>#encodeForHTMLAttribute(lockLibraryUrl)#</cfoutput>" data-lock-clear><span>Clear Filters</span></a>
        </div>
        <p class="fpw-lock-filter-status" data-lock-filter-status aria-live="polite" hidden></p>
      </form>
    </aside>

    <div class="fpw-lock-panel fpw-lock-map-card">
      <div class="fpw-lock-map-toolbar">
        <div>
          <h2>Lock Map</h2>
          <p data-lock-result-summary>Search and browse reviewed Great Loop lock references.</p>
        </div>
        <div class="fpw-lock-view-toggle" role="group" aria-label="View type">
          <button type="button" class="is-active" data-lock-view-button="map">Map</button>
          <button type="button" data-lock-view-button="list">List</button>
        </div>
      </div>

      <div class="fpw-lock-map-view" data-lock-view-panel="map">
        <div id="fpwLockMap" class="fpw-lock-map" aria-label="Great Loop lock map"></div>
        <p class="fpw-lock-empty-map" data-lock-empty-map hidden>No reviewed lock markers match the current filters.</p>
      </div>

      <div class="fpw-lock-list-view" data-lock-view-panel="list" hidden>
        <div class="fpw-lock-result-list" data-lock-result-list<cfif NOT arrayLen(finderLockRows)> hidden</cfif>>
          <cfloop array="#finderLockRows#" index="lockItem">
            <cfoutput>
              <article class="fpw-lock-result-card">
                <div>
                  <h3><a href="#encodeForHTMLAttribute(libraryLockDetailUrl(lockItem.slug))#">#encodeForHTML(lockItem.lock_name)#</a></h3>
                  <p>#encodeForHTML(lockItem.city)#<cfif len(lockItem.city) AND len(lockItem.state)>, </cfif>#encodeForHTML(lockItem.state)#<cfif len(lockItem.waterway)> &bull; #encodeForHTML(lockItem.waterway)#</cfif></p>
                </div>
                <dl>
                  <div><dt>VHF</dt><dd>#encodeForHTML(len(lockItem.vhf) ? lockItem.vhf : "Not listed")#</dd></div>
                  <div><dt>Phone</dt><dd>#encodeForHTML(len(lockItem.phone) ? lockItem.phone : "Not listed")#</dd></div>
                </dl>
              </article>
            </cfoutput>
          </cfloop>
        </div>
        <div class="fpw-lock-empty-state" data-lock-empty-list<cfif arrayLen(finderLockRows)> hidden</cfif>>
          <h3>No reviewed public lock rows match this view yet.</h3>
          <p>The library only displays reviewed rows marked public. Imported rows remain hidden until reviewed.</p>
        </div>
      </div>
    </div>

    <aside class="fpw-lock-panel fpw-lock-waterways" aria-labelledby="fpwWaterwayTitle">
      <h2 id="fpwWaterwayTitle">Browse by Waterway</h2>
      <div class="fpw-lock-waterways-list">
        <cfif arrayLen(browseWaterwayFacets)>
          <cfloop array="#browseWaterwayFacets#" index="facet">
            <cfset waterwayThumb = structKeyExists(waterwayThumbnailMap, facet.value) ? waterwayThumbnailMap[facet.value] : {}>
            <cfoutput>
              <a class="fpw-lock-waterway-card" href="#encodeForHTMLAttribute(libraryFilterUrl("waterway", facet.value))#" data-lock-waterway-shortcut data-waterway="#encodeForHTMLAttribute(facet.value)#">
                <cfif structKeyExists(waterwayThumb, "thumbnailUrl") AND len(waterwayThumb.thumbnailUrl)>
                  <img
                    src="#encodeForHTMLAttribute(waterwayThumb.thumbnailUrl)#"
                    alt="#encodeForHTMLAttribute(waterwayThumb.lockName)# image thumbnail"
                    class="fpw-lock-waterway-thumb fpw-lock-waterway-thumb-image"
                    loading="lazy"
                    decoding="async">
                <cfelse>
                  <span class="fpw-lock-waterway-thumb" aria-hidden="true"></span>
                </cfif>
                <span><strong>#encodeForHTML(facet.value)#</strong><small>Reviewed Great Loop locks</small></span>
                <em>#encodeForHTML(facet.count)#</em>
              </a>
            </cfoutput>
          </cfloop>
        <cfelse>
          <p class="fpw-lock-muted">Waterway browsing appears after reviewed rows include waterway data.</p>
        </cfif>

        <h2>Browse by State</h2>
        <cfif arrayLen(browseStateFacets)>
          <div class="fpw-lock-state-links">
            <cfloop array="#browseStateFacets#" index="facet">
              <cfoutput><a href="#encodeForHTMLAttribute(libraryFilterUrl("state", facet.value))#">#encodeForHTML(facet.value)# <span>#encodeForHTML(facet.count)#</span></a></cfoutput>
            </cfloop>
          </div>
        <cfelse>
          <p class="fpw-lock-muted">State browsing appears after reviewed rows are published.</p>
        </cfif>
      </div>
    </aside>
  </section>

  <cfif isTaxonomyRoute>
    <section class="fpw-lock-panel fpw-lock-taxonomy-locks" aria-labelledby="fpwTaxonomyLocksTitle">
      <h2 id="fpwTaxonomyLocksTitle"><cfoutput>Locks in #encodeForHTML(taxonomyName)#</cfoutput></h2>
      <p class="fpw-lock-muted"><cfoutput>#encodeForHTML(taxonomyCount)# reviewed public lock references are available for this Great Loop view.</cfoutput></p>
      <div class="fpw-lock-result-list">
        <cfloop array="#lockRows#" index="lockItem">
          <cfoutput>
            <article class="fpw-lock-result-card">
              <div>
                <h3><a href="#encodeForHTMLAttribute(libraryLockDetailUrl(lockItem.slug))#">#encodeForHTML(lockItem.lock_name)#</a></h3>
                <p>#encodeForHTML(lockItem.city)#<cfif len(lockItem.city) AND len(lockItem.state)>, </cfif>#encodeForHTML(lockItem.state)#<cfif len(lockItem.waterway)> &bull; #encodeForHTML(lockItem.waterway)#</cfif></p>
              </div>
              <dl>
                <div><dt>VHF</dt><dd>#encodeForHTML(len(lockItem.vhf) ? lockItem.vhf : "Not listed")#</dd></div>
                <div><dt>Phone</dt><dd>#encodeForHTML(len(lockItem.phone) ? lockItem.phone : "Not listed")#</dd></div>
              </dl>
            </article>
          </cfoutput>
        </cfloop>
      </div>
    </section>
  </cfif>

  <!--- fpw-lock-guides strip intentionally removed. --->

  <section class="fpw-lock-learning">
    <article id="how-to-lock" class="fpw-lock-panel"><h2>How to Lock Through</h2><p>Approach slowly, prepare lines and fenders before arrival, monitor the published VHF channel when available, and follow lockmaster instructions.</p></article>
    <article id="vhf-scripts" class="fpw-lock-panel"><h2>VHF Call Scripts</h2><p>Use the lock name, vessel name, direction of travel, and your request. Confirm current instructions before entering.</p></article>
    <article id="lock-etiquette" class="fpw-lock-panel"><h2>Lock Etiquette</h2><p>Keep wake down near approaches, brief crew before entering, yield as directed, and avoid crowding other vessels.</p></article>
    <article id="gear-checklist" class="fpw-lock-panel"><h2>Gear Checklist</h2><p>Have fenders, lines, gloves, PFDs, boat hooks, and a working radio ready before reaching the approach.</p></article>
    <article id="common-mistakes" class="fpw-lock-panel"><h2>Common Mistakes</h2><p>Do not rely on old schedules, stale notes, or unofficial status reports. Check current notices and local lock instructions.</p></article>
  </section>

  <section class="fpw-lock-safety-note">
    <h2>Navigation Safety Note</h2>
    <p>This page is a planning reference, not a substitute for official notices, charts, lockmaster instructions, or current local conditions. Always confirm lock status, operating hours, closures, restrictions, and instructions with the official authority before arrival.</p>
  </section>
</main>

<cfinclude template="../includes/footer.cfm">

<script id="fpwLockMapData" type="application/json"><cfoutput>#serializeJSON(mapRows)#</cfoutput></script>
<script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js" integrity="sha256-20nQCchB9co0qIjJZRGuk2/Z9VM+kNiyxNV1lvTlZBo=" crossorigin=""></script>
<script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/app/great-loop-locks.js?v=20260615-lock-hub"></script>
</body>
</html>
