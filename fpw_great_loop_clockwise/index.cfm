<cfprocessingdirective pageencoding="utf-8">
<cfsetting showdebugoutput="false">
<cfheader name="Cache-Control" value="no-store">
<cfinclude template="../includes/fpw_base_path.cfm">
<cfset request.fpwTopNavActive = "explore-legs">
<cfscript>
loopAvailable = true;
try {
    try {
        loopService = createObject("component", "api.v1.GreatLoopReferenceService").init();
    } catch (any componentPathError) {
        loopService = createObject("component", "fpw.api.v1.GreatLoopReferenceService").init();
    }
    loopModel = loopService.getModel();
} catch (any loopDataError) {
    loopAvailable = false;
    writeLog(file="fpw", type="error", text="FPW_ERROR Great Loop reference: " & loopDataError.message);
}
// SEO describes the rendered active template; no route counts or leg names are hardcoded.
loopCanonicalUrl = "https://floatplanwizard.com/fpw_great_loop_clockwise/";
loopPageTitle = "Great Loop Waterway Legs & Lock Times | FloatPlanWizard";
loopPageDescription = "Explore counterclockwise Great Loop waterway legs, lock names, lock counts, and estimated lock times from FPW's active route template.";
loopSocialImage = "https://floatplanwizard.com/assets/images/navigation/great-loop-trawler.png";
loopRobots = loopAvailable ? "index,follow,max-image-preview:large" : "noindex,follow";
loopJsonLdText = "";
if (loopAvailable) {
    loopSeoItems = [];
    for (loopSeoSection in loopModel.sections) {
        for (loopSeoLeg in loopSeoSection.legs) {
            arrayAppend(loopSeoItems, {
                "@type" = "ListItem",
                "position" = arrayLen(loopSeoItems) + 1,
                "name" = loopSeoLeg.title,
                "description" = loopSeoLeg.lockCount & (loopSeoLeg.lockCount EQ 1 ? " lock" : " locks")
                    & "; estimated lock time: " & loopSeoLeg.lockTimeLabel & "."
            });
        }
    }
    loopJsonLd = {
        "@context" = "https://schema.org",
        "@graph" = [
            {
                "@type" = "CollectionPage",
                "@id" = loopCanonicalUrl & "##webpage",
                "url" = loopCanonicalUrl,
                "name" = loopPageTitle,
                "description" = loopPageDescription,
                "inLanguage" = "en",
                "mainEntity" = {"@id" = loopCanonicalUrl & "##legs"},
                "breadcrumb" = {"@id" = loopCanonicalUrl & "##breadcrumb"},
                "publisher" = {"@type" = "Organization", "name" = "FloatPlanWizard", "url" = "https://floatplanwizard.com/"}
            },
            {
                "@type" = "ItemList",
                "@id" = loopCanonicalUrl & "##legs",
                "name" = "Counterclockwise Great Loop waterway legs",
                "itemListOrder" = "https://schema.org/ItemListOrderAscending",
                "numberOfItems" = loopModel.totalLegs,
                "itemListElement" = loopSeoItems
            },
            {
                "@type" = "BreadcrumbList",
                "@id" = loopCanonicalUrl & "##breadcrumb",
                "itemListElement" = [
                    {"@type" = "ListItem", "position" = 1, "name" = "FloatPlanWizard", "item" = "https://floatplanwizard.com/"},
                    {"@type" = "ListItem", "position" = 2, "name" = "Great Loop Waterway Legs", "item" = loopCanonicalUrl}
                ]
            }
        ]
    };
    loopJsonLdText = replace(serializeJSON(loopJsonLd), "</", "<\/", "all");
}
</cfscript>
<cfif NOT loopAvailable><cfheader statuscode="503"></cfif>
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width,initial-scale=1" />
  <cfoutput>
  <title>#encodeForHTML(loopPageTitle)#</title>
  <meta name="description" content="#encodeForHTMLAttribute(loopPageDescription)#">
  <meta name="robots" content="#encodeForHTMLAttribute(loopRobots)#">
  <link rel="canonical" href="#encodeForHTMLAttribute(loopCanonicalUrl)#">
  <meta property="og:type" content="website">
  <meta property="og:site_name" content="FloatPlanWizard">
  <meta property="og:url" content="#encodeForHTMLAttribute(loopCanonicalUrl)#">
  <meta property="og:title" content="#encodeForHTMLAttribute(loopPageTitle)#">
  <meta property="og:description" content="#encodeForHTMLAttribute(loopPageDescription)#">
  <meta property="og:image" content="#encodeForHTMLAttribute(loopSocialImage)#">
  <meta property="og:image:width" content="1536">
  <meta property="og:image:height" content="1024">
  <meta property="og:image:alt" content="Trawler cruising a tree-lined waterway">
  <meta name="twitter:card" content="summary_large_image">
  <meta name="twitter:title" content="#encodeForHTMLAttribute(loopPageTitle)#">
  <meta name="twitter:description" content="#encodeForHTMLAttribute(loopPageDescription)#">
  <meta name="twitter:image" content="#encodeForHTMLAttribute(loopSocialImage)#">
  <meta name="twitter:image:alt" content="Trawler cruising a tree-lined waterway">
  <cfif loopAvailable><script type="application/ld+json">#loopJsonLdText#</script></cfif>
  </cfoutput>
  <link rel="stylesheet" href="<cfoutput>#request.fpwBase#</cfoutput>/assets/css/layout.css?v=20260620-page-width">
  <link rel="stylesheet" href="<cfoutput>#request.fpwBase#</cfoutput>/assets/css/top-nav.css?v=20261028-approved-navigation">
  <link rel="stylesheet" href="assets/css/fpw_great_loop.css?v=20261028-template-locks" />
  <link rel="stylesheet" href="<cfoutput>#request.fpwBase#</cfoutput>/assets/css/cruise-timeline.css?v=20261029-shared-timeline">
  <link rel="stylesheet" href="assets/css/cruise-timeline-page.css?v=20261029-shared-timeline">
</head>
<body class="fpw-loop-page">
  <cfinclude template="../includes/top_nav.cfm">
  <main class="fpw-loop-guide" id="main-content">
    <div class="topbar">
      <div class="brand">
        <div class="badge">
          <img src="assets/img/icon_compass.svg" alt="" />
        </div>
        <div>
          <h1>THE GREAT LOOP – COUNTERCLOCKWISE LEG LIST</h1>
          <span class="sub">Explore Great Loop legs, locks, and daily cruise estimates in the Cruise Timeline.</span>
        </div>
      </div>

    </div>

    <cfif loopAvailable>
    <cfoutput>
    <div class="meta">
      <span class="pill">Total legs: <strong id="totalCount">#loopModel.totalLegs#</strong></span>
      <span class="pill">Direction: <strong>Counterclockwise</strong></span>
      <span class="pill">Locks: <strong id="totalLocks">#loopModel.totalLocks#</strong></span>
      <span class="pill">Est. lock time: <strong id="totalLockTime">#encodeForHTML(loopModel.lockTimeLabel)#</strong></span>
    </div>
    <p class="lockEstimateNote">Legs and locks follow the active Great Loop route template. Estimated lock time includes lockage plus typical waiting time; actual waits vary.</p>

    </cfoutput>
    <section id="loopCruiseTimeline" class="fpw-cruise-timeline fpw-cruise-timeline--public" aria-labelledby="loopTimelineHeading" data-endpoint="timeline.cfm">
      <div class="rg-timeline-shell">
        <div class="rg-timeline-head">
          <div class="rg-timeline-headline">
            <h2 id="loopTimelineHeading" class="rg-section-title">CRUISE TIMELINE</h2>
            <div id="loopTimelineSummary" class="rg-section-note">Plan the active Great Loop legs using FPW's daily cruise calculations.</div>
          </div>
        </div>
        <form id="loopTimelineForm" class="loop-timeline-settings" hidden>
          <div class="loop-departure-row">
            <label for="loopTimelineDeparture">Departure <input id="loopTimelineDeparture" name="departure" type="datetime-local" required></label>
            <p id="loopTimelineTimezone" class="rg-section-note"></p>
          </div>
          <p class="rg-section-note">Departure is rounded up when this page opens. Planning groups calendar days; it does not calculate clock-time departures or arrivals.</p>
          <details class="loop-planning-inputs"><summary>Planning settings</summary>
            <div class="loop-planning-grid">
              <label>Pace <select name="pace"><option value="RELAXED">Relaxed</option><option value="BALANCED">Efficient</option><option value="AGGRESSIVE">Max</option></select></label>
              <label>Maximum speed (kn) <input name="cruising_speed" type="number" min="0.1" max="100" step="0.1"></label>
              <label>Fuel burn at maximum speed (GPH) <input name="fuel_burn_gph" type="number" min="0" max="1000" step="0.1" placeholder="Unavailable until supplied"></label>
              <label>Most efficient speed (kn) <input name="vessel_most_efficient_speed_kn" type="number" min="0" max="100" step="0.1" placeholder="Optional"></label>
              <label>Fuel burn at efficient speed (GPH) <input name="vessel_gph_at_most_efficient_speed" type="number" min="0" max="1000" step="0.1" placeholder="Optional"></label>
              <label>Maximum hours per day <input name="underway_hours_per_day" type="number" min="4" max="12" step="0.5"></label>
              <label>Weather adjustment (%) <input name="weather_factor_pct" type="number" min="0" max="60" step="1"></label>
              <label>Fuel reserve <select name="reserve_mode"><option value="thirds">Rule of thirds</option><option value="percentage">Percentage</option></select></label>
              <label>Reserve (%) <input name="reserve_pct" type="number" min="0" max="100" step="1"></label>
            </div>
          </details>
          <button type="submit" class="btn">Recalculate timeline</button>
        </form>
        <p id="loopTimelineStatus" class="rg-section-note" role="status" aria-live="polite"></p>
        <noscript><p class="rg-section-note">Enable JavaScript to view the Great Loop legs, lock details, and interactive Cruise Timeline.</p></noscript>
        <div id="loopTimelineTable" hidden>
          <div class="rg-leg-columns" aria-hidden="true"><span>#</span><span>Leg</span><span>Locks</span><span>NM</span><span>Geometry</span></div>
          <div id="loopTimelineLegs" class="rg-leg-list"></div>
        </div>
      </div>
    </section>
    <cfelse>
      <p class="lockEstimateNote" role="status">The Great Loop leg list is temporarily unavailable. Please try again later.</p>
    </cfif>
  </main>
  <cfinclude template="../includes/footer.cfm">

  <cfif loopAvailable>
  <script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/app/shared/fuel-math.js?v=20260815-reserve-mode"></script>
  <script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/app/shared/cruise-timeline-view.js?v=20261029-shared-timeline"></script>
  <script src="assets/js/cruise-timeline-page.js?v=20261029-shared-timeline"></script>
  </cfif>
</body>
</html>
