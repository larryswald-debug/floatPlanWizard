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
loopPageTitle = "Great Loop Distances, Legs & Lock Times | FloatPlanWizard";
loopPageDescription = "Explore Great Loop cruising legs, nautical mileages, locks and estimated travel times. Review an interactive cruise timeline and plan your route with FPW.";
loopSocialImage = "https://floatplanwizard.com/assets/images/navigation/great-loop-trawler.png";
function loopTracking(required string eventName, required string placement, required string ctaType, required string label, required string destinationKey) {
    return 'data-fpw-action-cta data-fpw-track="' & encodeForHTMLAttribute(arguments.eventName)
        & '" data-fpw-track-source-page="great_loop_legs" data-fpw-track-section="' & encodeForHTMLAttribute(arguments.placement)
        & '" data-fpw-track-cta-type="' & encodeForHTMLAttribute(arguments.ctaType)
        & '" data-fpw-track-label="' & encodeForHTMLAttribute(arguments.label)
        & '" data-fpw-track-auth-state="' & loopAuthState
        & '" data-fpw-track-destination-key="' & encodeForHTMLAttribute(arguments.destinationKey) & '"';
}
loopPlannerUrl = request.fpwBase & "/app/dashboard.cfm?recoveryAction=planner";
loopGuideUrl = request.fpwBase & "/great-loop/trip-planning/";
loopResources = [
    {slug="ports", icon="ship", title="Ports & Marinas", description="Explore destinations and places to stop"},
    {slug="anchorages", icon="anchor", title="Anchorages", description="Research potential overnight stops"},
    {slug="bridges", icon="bridge", title="Bridges", description="Review bridge and clearance references"},
    {slug="locks", icon="lock", title="Locks", description="Explore lock locations and planning information"}
];
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
  <link rel="stylesheet" href="<cfoutput>#request.fpwBase#</cfoutput>/assets/css/fpw-action-cta.css">
  <link rel="stylesheet" href="assets/css/fpw_great_loop.css?v=20261104-leg-waypoints" />
  <link rel="stylesheet" href="<cfoutput>#request.fpwBase#</cfoutput>/assets/css/cruise-timeline.css?v=20261029-shared-timeline">
  <link rel="stylesheet" href="assets/css/cruise-timeline-page.css?v=20261029-shared-timeline">
  <cfinclude template="../includes/analytics_ga4.cfm">
</head>
<body class="fpw-loop-page">
  <cfinclude template="../includes/top_nav.cfm">
  <cfset loopAuthState = topNavIsLoggedIn ? "signed_in" : "signed_out">
  <cfset loopStartUrl = topNavIsLoggedIn ? loopPlannerUrl : request.fpwBase & "/app/join.cfm">
  <cfset loopStartDestination = topNavIsLoggedIn ? "planner" : "join">
  <main class="fpw-loop-guide" id="main-content">
    <header class="loop-intro">
      <p class="loop-eyebrow">GREAT LOOP CRUISE PLANNING</p>
      <h1>Great Loop Waterway Legs, Distances &amp; Lock Times</h1>
      <p class="loop-direction">Counterclockwise Great Loop Route</p>
      <p class="loop-intro-text">Explore the Great Loop by individual cruising leg. Review nautical miles, lock locations, estimated cruising times, and a sample daily itinerary. Then use FloatPlanWizard to build a route tailored to your boat and schedule.</p>
      <cfif loopAvailable>
        <div class="meta">
          <span class="pill"><strong id="totalCount"><cfoutput>#loopModel.totalLegs#</cfoutput></strong> published cruising legs</span>
          <span class="pill">Lock planning</span>
          <a class="pill" href="#loopCruiseTimeline">Interactive cruise timeline</a>
        </div>
      </cfif>
    </header>

    <cfif loopAvailable>
    <cfoutput>
    <section class="fpw-action-cta loop-cta" aria-labelledby="loopPrimaryTitle">
      <div class="fpw-action-cta__content">
        <h2 id="loopPrimaryTitle">Ready to Plan Your Great Loop?</h2>
        <p>Use FPW's Trip Planner to build your route, organize daily legs, estimate travel times and fuel, and prepare your float plan.</p>
      </div>
      <div class="loop-cta-actions">
        <a class="fpw-cta fpw-cta-primary" href="#loopPlannerUrl#" #loopTracking("great_loop_planner_cta_clicked","intro","plan_route","Plan My Great Loop","planner")#>Plan My Great Loop</a>
        <a class="fpw-cta loop-secondary" href="#loopGuideUrl#" #loopTracking("great_loop_guide_clicked","intro","guide","Read Planning Guide","great_loop_trip_planning")#>Read Planning Guide</a>
      </div>
    </section>

    <section class="loop-how" aria-labelledby="loopHowTitle">
      <h2 class="loop-section-title" id="loopHowTitle">How to Use the Great Loop Leg List</h2>
      <ol class="loop-steps">
        <li><h3>Step 1 — Explore the legs</h3><p>Browse the counterclockwise Great Loop leg list. Expand a leg to review its published nautical mileage, lock references, and available planning details.</p></li>
        <li><h3>Step 2 — Explore the cruise timeline</h3><p>Adjust the available timeline settings to see how cruising duration and lock-delay assumptions affect the estimated schedule.</p></li>
        <li><h3>Step 3 — Build your own route</h3><p>Open FPW's Trip Planner to create a route using your vessel information, selected stops, and preferred schedule. Review individual route legs and verify mileage before preparing your float plan.</p></li>
      </ol>
    </section>

    <div class="loop-tool-intro">
      <h2 class="loop-section-title">Great Loop Legs and Interactive Cruise Timeline</h2>
      <p>Review counterclockwise Great Loop legs, published distances, and lock references. Expand individual legs to examine planning details and explore how the estimated cruise timeline changes with the available settings.</p>
      <p class="lockEstimateNote"><strong id="totalLocks">#loopModel.totalLocks#</strong> locks along this route. Estimated lock time: <strong id="totalLockTime">#encodeForHTML(loopModel.lockTimeLabel)#</strong>. This allowance includes lockage and typical waiting time. Actual waits vary.</p>
    </div>

    <template id="loopLegPlannerPrompt">
      <div class="loop-leg-prompt">
        <div><h3>Add This Leg's Stops to Your Waypoints</h3><p>Save both endpoints of this Great Loop leg to My Waypoints. You can then use them when building your route in FPW's Trip Planner.</p><p id="loopWaypointStatus" role="status" aria-live="polite" aria-atomic="true"></p></div>
        <button type="button" class="fpw-cta loop-secondary" data-leg-action="save-waypoints" aria-describedby="loopWaypointStatus">Add to Waypoints</button>
      </div>
    </template>
    <dialog id="loopWaypointAuthDialog" class="fpw-auth-modal" aria-labelledby="loopWaypointAuthTitle" aria-describedby="loopWaypointAuthDescription">
      <div class="fpw-auth-modal__content">
        <button type="button" class="fpw-auth-modal__close" data-loop-auth-close aria-label="Close sign-in message">&times;</button>
        <h2 id="loopWaypointAuthTitle">Sign In to Save Waypoints</h2>
        <p id="loopWaypointAuthDescription">Create a free FloatPlanWizard account or sign in to save Great Loop locations to My Waypoints. Once saved, you can use them to build your own cruising routes.</p>
        <div class="loop-cta-actions">
          <a class="fpw-cta loop-secondary" href="#request.fpwBase#/app/login.cfm">Sign In</a>
          <a class="fpw-cta loop-secondary" href="#request.fpwBase#/app/join.cfm">Start Free</a>
        </div>
      </div>
    </dialog>

    </cfoutput>
    <section id="loopCruiseTimeline" class="fpw-cruise-timeline fpw-cruise-timeline--public" aria-labelledby="loopTimelineHeading" data-endpoint="timeline.cfm" data-waypoint-endpoint="<cfoutput>#encodeForHTMLAttribute(request.fpwApiBase)#</cfoutput>/waypoint.cfc?method=handle&amp;returnFormat=json">
      <div class="rg-timeline-shell">
        <div class="rg-timeline-head">
          <div class="rg-timeline-headline">
            <h3 id="loopTimelineHeading" class="rg-section-title">CRUISE TIMELINE</h3>
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
    <cfoutput>
    <div class="loop-reading">
      <section aria-labelledby="loopDistanceTitle">
        <h2 class="loop-section-title" id="loopDistanceTitle">Understanding Great Loop Cruising Distances</h2>
        <p>Charts measure distance in nautical miles (NM), and a speed of one knot covers one nautical mile per hour. Dividing a leg’s NM by your expected cruising speed in knots gives an estimate of time underway.</p>
        <p>A published leg gives you a reference distance between stops. Check the channel and approaches you intend to use against current charts. An alternate channel or a fuel stop can add miles. Current, weather and operating restrictions can change how long those miles take.</p>
        <p>When you <a href="#loopGuideUrl###generate-route" #loopTracking("great_loop_guide_clicked","distances","guide","Build a route from your waypoints","generate_route")#>build a route from your waypoints</a>, review each leg’s mileage. If its line skips a bend or takes a different approach, use the mileage override to draw the reviewed path and recalculate the distance.</p>
      </section>
      <section aria-labelledby="loopLockTitle">
        <h2 class="loop-section-title" id="loopLockTitle">Planning Lock Delays Along the Great Loop</h2>
        <p>Two days with the same mileage can finish at different times when one includes several locks. Traffic, lock cycles, operating hours and closures can all affect when your boat gets through.</p>
        <p>Expand a leg to see its mapped locks and any published delay estimates. The timeline uses the available lockage and typical wait allowance when grouping legs into days. Change pace or maximum hours per day to see how much cruising fits around that allowance. The lock allowance itself is fixed.</p>
        <p>Check the operator’s current information and navigation notices before departure. The guide explains <a href="#loopGuideUrl###lock-timing" #loopTracking("great_loop_guide_clicked","lock_delays","guide","How to budget time for locks","lock_timing")#>how to budget time for locks</a>.</p>
      </section>
      <section aria-labelledby="loopWorkflowTitle">
        <h2 class="loop-section-title" id="loopWorkflowTitle">How to Plan Your Great Loop in FloatPlanWizard</h2>
        <p>Anyone can explore this directory. Sign in to save stops, build your own route and share a float plan.</p>
        <ol>
          <li>Create or select your vessel profile. Review potential stops in the Great Loop libraries and save the locations you want to <strong>My Waypoints</strong>.</li>
          <li><a href="#loopPlannerUrl#" #loopTracking("great_loop_planner_cta_clicked","workflow","plan_route","Open the Trip Planner","planner")#>Open the Trip Planner</a>, set a starting waypoint and add your next stops in cruising order.</li>
          <li>Review the path and mileage of each leg. If the planned course differs, <a href="#loopGuideUrl###mileage-override" #loopTracking("great_loop_guide_clicked","workflow","guide","Edit the leg geometry to override its mileage","mileage_override")#>edit the leg geometry to override its mileage</a>.</li>
          <li>Review daily timing and fuel at your vessel’s expected speed and burn rate. Use the <a href="#request.fpwBase#/boat-fuel-calculator/">Boat Fuel Calculator</a> to compare fuel assumptions.</li>
          <li>Save your reviewed route, prepare a float plan from it, and share the plan with the shore contacts you’ve selected.</li>
        </ol>
        <p>Follow the <a href="#loopGuideUrl#" #loopTracking("great_loop_guide_clicked","workflow","guide","Great Loop Trip Planning Guide","great_loop_trip_planning")#>Great Loop Trip Planning Guide</a> for the full workflow.</p>
      </section>
      <section class="loop-faq" aria-labelledby="loopQuestionsTitle">
        <h2 class="loop-section-title" id="loopQuestionsTitle">Great Loop Planning Questions</h2>
        <details><summary>How many legs are in the Great Loop directory?</summary><p>The published directory divides the counterclockwise route into #loopModel.totalLegs# reference legs. A leg connects two named points. Your cruising day may cover part of a leg or several legs.</p></details>
        <details><summary>Does the directory calculate actual travel time?</summary><p>It estimates cruising hours and groups mileage into planning days using the reference legs, your settings and available lock allowances. Weather, stops and traffic affect your actual arrival.</p></details>
        <details><summary>Are lock waiting times live?</summary><p>No. The displayed delays are planning allowances. Check with the lock operator for current traffic, hours and restrictions.</p></details>
        <details><summary>Can I create my own Great Loop route?</summary><p>Yes. Sign in to FPW’s Trip Planner, choose your starting waypoint and add the stops you want. Expanding a directory leg only displays its reference information.</p></details>
        <details><summary>Can I save Great Loop locations as waypoints?</summary><p>Yes. On a Port, Anchorage, Bridge or Lock detail page with stored waypoint coordinates, sign in and choose <strong>Add to My Waypoints</strong>. You can then select that location when building a route.</p></details>
      </section>
    </div>

    <section class="loop-resources" aria-labelledby="loopResourcesTitle">
      <h2 class="loop-section-title" id="loopResourcesTitle">Explore Great Loop Planning Resources</h2>
      <ul class="loop-resources-list">
        <cfloop array="#loopResources#" index="loopResource">
          <li><a href="#request.fpwBase#/great-loop/#loopResource.slug#/" #loopTracking("great_loop_library_clicked","resources","library",loopResource.title,"great_loop_" & loopResource.slug)#>
            #renderFpwApprovedNavIcon(loopResource.icon)#
            <span><strong>#encodeForHTML(loopResource.title)#</strong><small>#encodeForHTML(loopResource.description)#</small></span>
          </a></li>
        </cfloop>
      </ul>
    </section>

    <section class="fpw-action-cta loop-cta" aria-labelledby="loopClosingTitle">
      <div class="fpw-action-cta__content">
        <h2 id="loopClosingTitle">Turn Your Great Loop Research Into a Trip Plan</h2>
        <p>Use FloatPlanWizard to organize waypoints, build your route, estimate travel times and fuel, and prepare a float plan to share with someone ashore.</p>
      </div>
      <div class="loop-cta-actions">
        <a class="fpw-cta fpw-cta-primary" href="#loopStartUrl#" #loopTracking("great_loop_planner_cta_clicked","footer","plan_route","Start Planning Free",loopStartDestination)#>Start Planning Free</a>
        <a class="fpw-cta loop-secondary" href="#loopGuideUrl#" #loopTracking("great_loop_guide_clicked","footer","guide","Explore the Great Loop Planning Guide","great_loop_trip_planning")#>Explore the Great Loop Planning Guide</a>
      </div>
    </section>
    </cfoutput>
    <cfelse>
      <p class="lockEstimateNote" role="status">The Great Loop leg list is temporarily unavailable. Please try again later.</p>
    </cfif>
  </main>
  <cfinclude template="../includes/footer.cfm">

  <cfif loopAvailable>
  <script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/app/shared/fuel-math.js?v=20260815-reserve-mode"></script>
  <script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/app/shared/cruise-timeline-view.js?v=20261029-shared-timeline"></script>
  <script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/fpw-action-cta.js?v=20261001-unified-auth"></script>
  <script src="assets/js/cruise-timeline-page.js?v=20261104-leg-waypoints"></script>
  </cfif>
</body>
</html>
