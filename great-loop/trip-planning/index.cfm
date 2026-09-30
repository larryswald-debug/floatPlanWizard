<cfprocessingdirective pageencoding="utf-8">
<cfsetting showdebugoutput="false" requesttimeout="30">
<cfcontent type="text/html; charset=utf-8">
<cfinclude template="../../includes/fpw_base_path.cfm">

<cfscript>
schemaAtKey = chr(64);
schemaTypeKey = schemaAtKey & "type";
schemaIdKey = schemaAtKey & "id";
schemaContextKey = schemaAtKey & "context";
schemaGraphKey = schemaAtKey & "graph";

function fpwLoopPlanningSchemaRef(required string idValue) {
  var out = structNew("ordered");
  structInsert(out, schemaIdKey, arguments.idValue, true);
  return out;
}

function fpwLoopPlanningSchemaListItem(required numeric position, required string name, required string urlValue) {
  var out = structNew("ordered");
  var item = structNew("ordered");
  structInsert(out, schemaTypeKey, "ListItem", true);
  out["position"] = arguments.position;
  structInsert(item, schemaIdKey, arguments.urlValue, true);
  item["name"] = arguments.name;
  out["item"] = item;
  return out;
}

fpwLoopPlanningBasePath = request.fpwBase;

fpwLoopPlanningCanonicalUrl = "https://floatplanwizard.com/great-loop/trip-planning/";
fpwLoopPlanningPageTitle = "Great Loop Trip Planning: Locks, Bridges & Fuel | FPW";
fpwLoopPlanningPageDescription = "Plan Great Loop cruising days around your boat, bridges, locks, fuel and stopping areas, with a Chicago-to-Starved Rock planning example.";
fpwLoopPlanningHeadline = "Great Loop Trip Planning: How to Plan Locks, Bridges, Fuel and Daily Routes";
fpwLoopPlanningSocialImage = "https://floatplanwizard.com/assets/images/social/floatplanwizard-social-preview-20260730.png";
fpwLoopPlanningModifiedDate = "2026-09-30";
fpwLoopPlanningArticleId = fpwLoopPlanningCanonicalUrl & "##article";
fpwLoopPlanningWebPageId = fpwLoopPlanningCanonicalUrl & "##webpage";
fpwLoopPlanningOrganizationId = "https://floatplanwizard.com/##organization";
fpwLoopPlanningJsonLdText = "";
fpwLoopPlanningSchemaGraph = [];
fpwLoopPlanningSchemaOrg = structNew("ordered");
fpwLoopPlanningSchemaBreadcrumb = structNew("ordered");
fpwLoopPlanningSchemaPage = structNew("ordered");
fpwLoopPlanningSchemaArticle = structNew("ordered");
fpwLoopPlanningJsonLd = structNew("ordered");

structInsert(fpwLoopPlanningSchemaOrg, schemaTypeKey, "Organization", true);
structInsert(fpwLoopPlanningSchemaOrg, schemaIdKey, fpwLoopPlanningOrganizationId, true);
fpwLoopPlanningSchemaOrg["name"] = "FloatPlanWizard";
fpwLoopPlanningSchemaOrg["url"] = "https://floatplanwizard.com/";
fpwLoopPlanningSchemaOrg["logo"] = "https://floatplanwizard.com/assets/images/checkout/floatplanwizard-logo.jpg";
arrayAppend(fpwLoopPlanningSchemaGraph, fpwLoopPlanningSchemaOrg);

structInsert(fpwLoopPlanningSchemaBreadcrumb, schemaTypeKey, "BreadcrumbList", true);
structInsert(fpwLoopPlanningSchemaBreadcrumb, schemaIdKey, fpwLoopPlanningCanonicalUrl & "##breadcrumb", true);
fpwLoopPlanningSchemaBreadcrumb["itemListElement"] = [];
arrayAppend(fpwLoopPlanningSchemaBreadcrumb["itemListElement"], fpwLoopPlanningSchemaListItem(1, "FloatPlanWizard", "https://floatplanwizard.com/"));
arrayAppend(fpwLoopPlanningSchemaBreadcrumb["itemListElement"], fpwLoopPlanningSchemaListItem(2, "Great Loop Trip Planning", fpwLoopPlanningCanonicalUrl));
arrayAppend(fpwLoopPlanningSchemaGraph, fpwLoopPlanningSchemaBreadcrumb);

structInsert(fpwLoopPlanningSchemaPage, schemaTypeKey, "WebPage", true);
structInsert(fpwLoopPlanningSchemaPage, schemaIdKey, fpwLoopPlanningWebPageId, true);
fpwLoopPlanningSchemaPage["url"] = fpwLoopPlanningCanonicalUrl;
fpwLoopPlanningSchemaPage["name"] = fpwLoopPlanningPageTitle;
fpwLoopPlanningSchemaPage["description"] = fpwLoopPlanningPageDescription;
fpwLoopPlanningSchemaPage["isPartOf"] = fpwLoopPlanningSchemaRef("https://floatplanwizard.com/##website");
fpwLoopPlanningSchemaPage["publisher"] = fpwLoopPlanningSchemaRef(fpwLoopPlanningOrganizationId);
fpwLoopPlanningSchemaPage["breadcrumb"] = fpwLoopPlanningSchemaRef(fpwLoopPlanningCanonicalUrl & "##breadcrumb");
fpwLoopPlanningSchemaPage["mainEntity"] = fpwLoopPlanningSchemaRef(fpwLoopPlanningArticleId);
arrayAppend(fpwLoopPlanningSchemaGraph, fpwLoopPlanningSchemaPage);

structInsert(fpwLoopPlanningSchemaArticle, schemaTypeKey, "Article", true);
structInsert(fpwLoopPlanningSchemaArticle, schemaIdKey, fpwLoopPlanningArticleId, true);
fpwLoopPlanningSchemaArticle["url"] = fpwLoopPlanningCanonicalUrl;
fpwLoopPlanningSchemaArticle["headline"] = fpwLoopPlanningHeadline;
fpwLoopPlanningSchemaArticle["description"] = fpwLoopPlanningPageDescription;
fpwLoopPlanningSchemaArticle["dateModified"] = fpwLoopPlanningModifiedDate;
fpwLoopPlanningSchemaArticle["articleSection"] = "Great Loop Trip Planning";
fpwLoopPlanningSchemaArticle["inLanguage"] = "en";
fpwLoopPlanningSchemaArticle["author"] = fpwLoopPlanningSchemaRef(fpwLoopPlanningOrganizationId);
fpwLoopPlanningSchemaArticle["publisher"] = fpwLoopPlanningSchemaRef(fpwLoopPlanningOrganizationId);
fpwLoopPlanningSchemaArticle["mainEntityOfPage"] = fpwLoopPlanningSchemaRef(fpwLoopPlanningWebPageId);
arrayAppend(fpwLoopPlanningSchemaGraph, fpwLoopPlanningSchemaArticle);

structInsert(fpwLoopPlanningJsonLd, schemaContextKey, "https://schema.org", true);
structInsert(fpwLoopPlanningJsonLd, schemaGraphKey, fpwLoopPlanningSchemaGraph, true);
fpwLoopPlanningJsonLdText = replace(serializeJSON(fpwLoopPlanningJsonLd), "</", "<\/", "all");

fpwLoopPlanningCtaUserId = 0;
if (structKeyExists(session, "user") AND isStruct(session.user)) {
  for (fpwLoopPlanningCtaUserIdKey in [ "userId", "id", "USERID", "ID" ]) {
    if (structKeyExists(session.user, fpwLoopPlanningCtaUserIdKey) AND isNumeric(session.user[fpwLoopPlanningCtaUserIdKey])) {
      fpwLoopPlanningCtaUserId = val(session.user[fpwLoopPlanningCtaUserIdKey]);
      break;
    }
  }
}
fpwLoopPlanningCtaSignedIn = fpwLoopPlanningCtaUserId GT 0;
fpwLoopPlanningDestination = fpwLoopPlanningCtaSignedIn ? fpwLoopPlanningBasePath & "/app/dashboard.cfm" : fpwLoopPlanningBasePath & "/app/join.cfm";
fpwCtaConfig = {
  "id" = "great-loop-trip-planning-cta",
  "headline" = "Plan your next boating trip for free",
  "supportingText" = "Bring your boat, route and daily timing together in a trip plan you can review and share before departure.",
  "buttonLabel" = "Start Planning",
  "destinationUrl" = fpwLoopPlanningDestination,
  "ctaType" = "plan_trip",
  "sourcePage" = "great_loop_trip_planning",
  "section" = "after_planning_guide",
  "authState" = fpwLoopPlanningCtaSignedIn ? "signed_in" : "signed_out",
  "destinationKey" = fpwLoopPlanningCtaSignedIn ? "dashboard" : "join",
  "analyticsEvent" = "great_loop_trip_planning_cta_click",
  "ariaLabel" = "Start planning your next boating trip for free with FloatPlanWizard"
};
</cfscript>

<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Great Loop Trip Planning: Locks, Bridges &amp; Fuel | FPW</title>
  <meta name="description" content="Plan Great Loop cruising days around your boat, bridges, locks, fuel and stopping areas, with a Chicago-to-Starved Rock planning example.">
  <meta name="robots" content="index,follow">
  <link rel="canonical" href="https://floatplanwizard.com/great-loop/trip-planning/">
  <meta property="og:type" content="article">
  <meta property="og:site_name" content="FloatPlanWizard">
  <meta property="og:url" content="https://floatplanwizard.com/great-loop/trip-planning/">
  <meta property="og:title" content="Great Loop Trip Planning: Locks, Bridges &amp; Fuel | FPW">
  <meta property="og:description" content="Plan Great Loop cruising days around your boat, bridges, locks, fuel and stopping areas, with a Chicago-to-Starved Rock planning example.">
  <meta property="og:image" content="https://floatplanwizard.com/assets/images/social/floatplanwizard-social-preview-20260730.png">
  <meta property="og:image:secure_url" content="https://floatplanwizard.com/assets/images/social/floatplanwizard-social-preview-20260730.png">
  <meta property="og:image:type" content="image/png">
  <meta property="og:image:width" content="1200">
  <meta property="og:image:height" content="630">
  <meta property="og:image:alt" content="FloatPlanWizard boating trip planning, float-plan sharing, and check-in preview">
  <meta name="twitter:card" content="summary_large_image">
  <meta name="twitter:title" content="Great Loop Trip Planning: Locks, Bridges &amp; Fuel | FPW">
  <meta name="twitter:description" content="Plan Great Loop cruising days around your boat, bridges, locks, fuel and stopping areas, with a Chicago-to-Starved Rock planning example.">
  <meta name="twitter:image" content="https://floatplanwizard.com/assets/images/social/floatplanwizard-social-preview-20260730.png">
  <meta name="twitter:image:alt" content="FloatPlanWizard boating trip planning, float-plan sharing, and check-in preview">
  <script type="application/ld+json"><cfoutput>#fpwLoopPlanningJsonLdText#</cfoutput></script>
  <cfoutput><link rel="icon" type="image/svg+xml" href="#fpwLoopPlanningBasePath#/assets/images/landing/fpw-logo.svg"></cfoutput>
  <cfoutput><link rel="stylesheet" href="#fpwLoopPlanningBasePath#/assets/css/layout.css?v=20260620-page-width"></cfoutput>
  <cfoutput><link rel="stylesheet" href="#fpwLoopPlanningBasePath#/assets/css/top-nav.css?v=20260824-boating-safety-nav-v2"></cfoutput>
  <cfoutput><link rel="stylesheet" href="#fpwLoopPlanningBasePath#/assets/css/fpw-action-cta.css?v=20260804-pilot"></cfoutput>
  <cfoutput><link rel="stylesheet" href="#fpwLoopPlanningBasePath#/assets/css/shore-contact-overdue-guide.css?v=20260806-cta-color"></cfoutput>
  <style>
    /* Keep TOC targets below the shared sticky header at all article breakpoints. */
    #main-content .fpw-overdue-content > section { scroll-margin-top: 165px; }
    .fpw-loop-planning-figure { margin: 20px 0; }
    .fpw-loop-planning-figure img { display: block; max-width: 100%; height: auto; margin: 0 auto; border: 1px solid var(--fpw-overdue-line); border-radius: 12px; }
    .fpw-loop-planning-figure figcaption { margin-top: 10px; color: var(--fpw-overdue-muted); font-size: 0.9rem; line-height: 1.6; }
  </style>
  <cfinclude template="../../includes/analytics_ga4.cfm">
  <cfinclude template="../../includes/analytics_clarity.cfm">
  <cfinclude template="../../includes/trustedsite.cfm">
</head>
<body class="fpw-overdue-body">
<cfinclude template="../../includes/top_nav.cfm">

<main class="fpw-overdue-page" id="main-content">
  <div class="fpw-overdue-shell">
    <nav class="fpw-overdue-breadcrumbs" aria-label="Breadcrumb">
      <a href="<cfoutput>#fpwLoopPlanningBasePath#</cfoutput>/">FloatPlanWizard</a>
      <span aria-hidden="true">&rsaquo;</span>
      <span aria-current="page">Great Loop Trip Planning</span>
    </nav>

    <article class="fpw-overdue-article" aria-labelledby="fpw-loop-planning-title">
      <header class="fpw-overdue-hero">
        <p class="fpw-overdue-eyebrow">Great Loop Planning Guide</p>
        <h1 id="fpw-loop-planning-title">Great Loop Trip Planning: How to Plan Locks, Bridges, Fuel and Daily Routes</h1>
        <p class="fpw-overdue-lede">Build a Great Loop route in FloatPlanWizard, review each leg, correct its drawn path and mileage, and turn the estimates into a realistic cruising day. Follow the current planning tools from saved waypoints through bridge and lock research, fuel checks and the Float Plan, then apply the workflow to a Chicago-to-Starved Rock corridor example.</p>
      </header>

      <aside class="fpw-overdue-emergency" role="note" aria-labelledby="fpw-loop-planning-note">
        <strong id="fpw-loop-planning-note">Use reference pages to prepare; check conditions before departure.</strong>
        <p>This is a planning workflow, not a navigation route or a current operating notice. Confirm conditions, access and operating information for your selected route before relying on the plan.</p>
      </aside>

      <div class="fpw-overdue-layout">
        <nav class="fpw-overdue-toc" aria-labelledby="fpw-loop-planning-toc-title">
          <h2 id="fpw-loop-planning-toc-title">In this guide</h2>
          <ol>
            <li><a href="#daily-decisions">Plan one realistic leg</a></li>
            <li><a href="#boat-limits">Prepare boat and waypoints</a></li>
            <li><a href="#generate-route">Generate the starting route</a></li>
            <li><a href="#review-legs">Inspect each leg</a></li>
            <li><a href="#mileage-override">Correct leg mileage</a></li>
            <li><a href="#adapt-the-plan">Adjust or reuse the route</a></li>
            <li><a href="#route-constraints">Review bridge constraints</a></li>
            <li><a href="#lock-timing">Account for locks and delays</a></li>
            <li><a href="#fuel-per-leg">Check fuel with corrected NM</a></li>
            <li><a href="#distance-and-time">Build a realistic schedule</a></li>
            <li><a href="#overnight-stops">Choose a practical endpoint</a></li>
            <li><a href="#chicago-starved-rock">Chicago / Illinois walkthrough</a></li>
            <li><a href="#route-to-float-plan">Prepare and share the Float Plan</a></li>
            <li><a href="#daily-checklist">Check the finished plan</a></li>
            <li><a href="#start-planning">Turn research into a plan</a></li>
          </ol>
        </nav>

        <div class="fpw-overdue-content">
          <section id="daily-decisions" tabindex="-1" aria-labelledby="daily-decisions-title">
            <h2 id="daily-decisions-title">Plan the Great Loop one realistic leg at a time</h2>
            <p>A Great Loop route gives the trip direction; a daily leg gives the crew a workable plan. Start with where you intend to leave, the water you expect to travel, and a stopping point you can reconsider. Distance, bridges, locks, fuel and daylight belong in the same decision.</p>
            <p>You can <a href="<cfoutput>#encodeForHTMLAttribute(fpwLoopPlanningDestination)#</cfoutput>">open FPW's Trip Planner workspace</a> and use <strong>+ Create Route</strong> on the dashboard to open the <strong>FPW Route Generator</strong>. Build a route from saved waypoints, inspect the legs, correct the drawn path where needed, and review the resulting distance, timing and fuel estimates. The finished route then supports a Float Plan for the trip you actually intend to run.</p>
            <p><strong>The workflow:</strong> prepare the boat and waypoints; build the route; review each leg; adjust its geometry; check bridges, locks, time and fuel; choose a realistic daily endpoint; save the route; then review and share the Float Plan.</p>
            <p>Treat the generated result as the start of captain review. FPW organizes your planning; the captain still validates the navigable path with current charts, Notices to Mariners, official navigation information and judgment.</p>
          </section>

          <section id="boat-limits" tabindex="-1" aria-labelledby="boat-limits-title">
            <h2 id="boat-limits-title">Start with the boat FPW is actually planning for</h2>
            <p>In the dashboard, complete <strong>Getting Started</strong> before creating a route: save a vessel, a shore contact with name, phone and email, an operator, and at least two waypoints. Add passengers when others will be aboard. Use the <strong>Waypoints</strong> panel to save the start and intended destination, checking each name, latitude and longitude. Two waypoints provide the endpoints of one leg; a return journey needs its own leg.</p>
            <p>Know the boat's air draft in its intended configuration, draft under the expected load, usable fuel, normal cruise performance and the crew's realistic travel-day limit. Air draft and draft are checks you make against route constraints; the Route Generator does not certify bridge clearance or water depth.</p>
            <p>Select the correct <strong>Vessel</strong> in the Route Generator, then review its planning inputs. Do not accept a speed or burn figure just because a field is populated.</p>
            <ul>
              <li><strong>Most Efficient Speed (kn)</strong> and <strong>GPH @ Efficient</strong> describe the cruising combination you expect to use.</li>
              <li><strong>Max Speed (kn)</strong> and <strong>GPH @ max speed</strong> support the faster-speed and relaxed-pace estimates. Review the displayed <strong>Adjusted Speed</strong> after choosing <strong>Pace</strong>.</li>
              <li><strong>Idle Burn (GPH)</strong> and <strong>Idle Hours (total)</strong> let you enter an explicit allowance for time with the engine idling.</li>
              <li><strong>Weather Factor (%)</strong> is a planning allowance. It is not confirmation of the conditions you will encounter.</li>
              <li><strong>Reserve Method</strong> and <strong>Underway Hrs / Day</strong> set fuel-reserve assumptions and the timeline's daily planning budget.</li>
            </ul>
            <p>Use usable fuel rather than nominal tank size when checking range in the <a href="<cfoutput>#fpwLoopPlanningBasePath#</cfoutput>/boat-fuel-calculator/">Boat Fuel Calculator</a>. Measure and confirm your own boat's limits instead of adopting another captain's figures.</p>
          </section>

          <section id="generate-route" tabindex="-1" aria-labelledby="generate-route-title">
            <h2 id="generate-route-title">Generate your starting Great Loop route</h2>
            <p>The current member workflow is <strong>My Routes &amp; Waypoint Builder</strong>. You select saved waypoints to define the route; this screen does not offer an automatic Great Loop itinerary or a visible route-template picker.</p>
            <ol>
              <li>On the dashboard, choose <strong>+ Create Route</strong>. Enter a descriptive <strong>Route Name</strong>. The guided tour can help identify the controls.</li>
              <li>In <strong>Create Route</strong>, enter the route name and choose <strong>Create</strong>. This creates the My Route you will build; it does not send a Float Plan.</li>
              <li>Choose your departure waypoint under <strong>Route Start Waypoint</strong>, then choose <strong>Set Start</strong>.</li>
              <li>Under <strong>Add Leg by Waypoint</strong>, select the next intended waypoint and choose <strong>Add Leg</strong>. Repeat for additional legs. The next destination extends the sequence from the previous endpoint.</li>
              <li>Choose <strong>Load</strong> to populate <strong>Route Summary and Legs</strong> and the <strong>Cruise Timeline</strong>. Confirm the vessel, speed, fuel and daily-hours inputs.</li>
              <li>Review and adjust the result before using <strong>Save Route</strong>. Saving a route and sending a Float Plan are separate actions.</li>
            </ol>
            <figure class="fpw-loop-planning-figure">
              <a href="<cfoutput>#fpwLoopPlanningBasePath#</cfoutput>/assets/images/boating-guides/great-loop-trip-planning/create-waypoint-route.webp" aria-label="View larger screenshot: Route Generator controls for Create Route, Set Start, Add Leg and Load"><img src="<cfoutput>#fpwLoopPlanningBasePath#</cfoutput>/assets/images/boating-guides/great-loop-trip-planning/create-waypoint-route.webp" width="426" height="855" loading="lazy" decoding="async" alt="Route Generator controls for Create Route, Set Start, Add Leg and Load"></a>
              <figcaption>Create or select a My Route, set its start, and add each next waypoint before choosing Load. This local practice route demonstrates the controls; it is not a Great Loop itinerary. Select the image for a larger view.</figcaption>
            </figure>
            <p>A waypoint leg may begin with a straight-line distance and no saved navigable geometry. A line between two coordinates does not establish a usable channel. Use the leg review and geometry steps below before treating that distance as a cruising estimate.</p>
          </section>

          <section id="review-legs" tabindex="-1" aria-labelledby="review-legs-title">
            <h2 id="review-legs-title">Review the route one leg at a time</h2>
            <p>Under <strong>Cruise Timeline</strong>, review each leg's start and destination, <strong>Locks</strong> count, effective <strong>NM</strong> and <strong>Edit Route</strong> control. The summary above provides <strong>Total Distance</strong>, <strong>Total Travel Hours</strong>, <strong>Estimated Fuel</strong> and <strong>Adjusted Speed</strong>. These are estimates based on the route and inputs currently loaded.</p>
            <figure class="fpw-loop-planning-figure">
              <a href="<cfoutput>#fpwLoopPlanningBasePath#</cfoutput>/assets/images/boating-guides/great-loop-trip-planning/review-leg-distance.webp" aria-label="View larger screenshot: Cruise Timeline practice leg with nautical miles and Edit Route button"><img src="<cfoutput>#fpwLoopPlanningBasePath#</cfoutput>/assets/images/boating-guides/great-loop-trip-planning/review-leg-distance.webp" width="384" height="140" loading="lazy" decoding="async" alt="Cruise Timeline practice leg with nautical miles and Edit Route button"></a>
              <figcaption>Read the leg endpoints and NM, then choose Edit Route when the path needs review. The practice values demonstrate the interface, not a recommended distance or cruising schedule. Select the image for a larger view.</figcaption>
            </figure>
            <ul>
              <li>Does the path follow the waterway and approach you intend to use? Check more than the endpoint names.</li>
              <li>Does the leg's distance reflect that path, including approaches and deliberate detours?</li>
              <li>Which bridges and locks actually lie on this leg? A zero lock count on a waypoint-only leg does not establish that no locks are present.</li>
              <li>At the selected pace, does the running time leave room for waiting, maneuvering, conditions and a suitable stopping point?</li>
            </ul>
            <p>The timeline can allocate a long leg across planning days. A day boundary is a time-budget result; it is not a verified marina, anchorage or safe place to stop. Review the complete leg and the practical stopping options yourself.</p>
          </section>

          <section id="mileage-override" tabindex="-1" aria-labelledby="mileage-override-title">
            <h2 id="mileage-override-title">Generated mileage is a starting point — correct the path when necessary</h2>
            <p><strong>FPW's current mileage override is a geometry edit.</strong> There is no numeric &ldquo;actual mileage&rdquo; box in this workflow. You draw or edit the expected path and FPW calculates <strong>Computed NM</strong> from that line. This is planned distance, not a measurement of a voyage already traveled.</p>
            <p>Use this when a direct line misses the navigable channel, an approach is longer than the initial estimate, or your intended path changes because of a constraint. The line must reflect a path you have independently checked; adding points to a map does not validate safe passage.</p>
            <ol>
              <li>Choose <strong>Edit Route</strong> beside the leg in <strong>Cruise Timeline</strong> or in the My Route's <strong>Leg Sequence</strong>. The <strong>Leg Geometry</strong> panel opens.</li>
              <li>Check the leg title, its source and <strong>Computed NM</strong>. If there is no saved geometry, the panel says to draw a polyline.</li>
              <li>Use the map's <strong>Draw a polyline</strong> control to trace the expected path. Click successive points and finish the line. For an existing drawn line, use <strong>Edit layers</strong> and finish that map edit. Check the start, end and intermediate points.</li>
              <li>Review the recalculated <strong>Computed NM</strong>, then choose <strong>Save Overrides</strong>. Finishing the map drawing alone is not the same as saving the override.</li>
              <li>Close the map panel and inspect the leg's updated NM and <strong>Override</strong> indication. Choose <strong>Load</strong> for the selected My Route to review its current total, timeline and fuel estimate again before saving the route.</li>
            </ol>
            <figure class="fpw-loop-planning-figure">
              <a href="<cfoutput>#fpwLoopPlanningBasePath#</cfoutput>/assets/images/boating-guides/great-loop-trip-planning/edit-leg-geometry.webp" aria-label="View larger screenshot: Leg Geometry panel with Computed NM, drawing controls and Save Overrides"><img src="<cfoutput>#fpwLoopPlanningBasePath#</cfoutput>/assets/images/boating-guides/great-loop-trip-planning/edit-leg-geometry.webp" width="424" height="745" loading="lazy" decoding="async" alt="Leg Geometry panel with Computed NM, drawing controls and Save Overrides"></a>
              <figcaption>Use the drawing controls to describe the reviewed path, check Computed NM, and save the override. This practice screen shows a default straight-line estimate before correction; its map and values are not navigation instructions. Select the image for a larger view.</figcaption>
            </figure>
            <p><strong>What is saved:</strong> FPW stores the drawn geometry and its calculated mileage as your override. The My Route's base distance remains separate. The visible leg shows the effective distance; it does not display the original and overridden mileages side by side. Note the original value before editing if you want to compare them.</p>
            <p><strong>What changes:</strong> the effective leg distance and route total change. When the route is reloaded or its estimates are rebuilt, the adjusted distance feeds the timing and Route Generator fuel calculations. A longer expected path can therefore change the planning hours, fuel requirement and daily allocation.</p>
            <p><strong>What to check separately:</strong> an existing generated route's geometry save can update NM before its previous timeline and fuel display refresh. Save the edited route and review the refreshed estimates; do not rely on an unchanged time or fuel card immediately after a map save. This does not automatically revise an already-created Float Plan's return time or the separate public Fuel Calculator.</p>
            <p><strong>Change or remove an override:</strong> reopen <strong>Edit Route</strong>, revise the line and save again. <strong>Revert to Default</strong> removes the applicable saved override and reloads the available default; verify the resulting NM. <strong>Clear Draw</strong> clears the working drawing; saving that cleared state also removes the override. Do not treat Clear Draw as a private sketch reset once you save it. On a previously generated route, the default can be its saved base distance, so check the result rather than assuming it restores an earlier estimate. Revert to Default on an existing generated route also clears any saved segment-wide override, which can affect other routes using that saved segment geometry.</p>
          </section>

          <section id="adapt-the-plan" tabindex="-1" aria-labelledby="adapt-the-plan-title">
            <h2 id="adapt-the-plan-title">Adjust the route when reality requires it</h2>
            <p>Decide whether you are changing <em>the path between the same endpoints</em> or <em>the endpoints of the day's route</em>. A geometry override addresses the first. It does not change the leg's destination, reorder the route or discover the bridges and locks crossed by the new line.</p>
            <p>For a different endpoint, save the needed waypoint on the dashboard and return to <strong>My Routes &amp; Waypoint Builder</strong>. <strong>Add Leg</strong> extends the current route. To replace the final destination, use <strong>Remove</strong> on the final leg, select the new destination, then choose <strong>Add Leg</strong>. Removing an intermediate leg reconnects the following leg and clears that following leg's saved geometry override. Review its new endpoints and redraw the path where needed. Check every adjacent start and destination before choosing <strong>Load</strong>.</p>
            <p>This is useful when a bridge constraint changes an approach, a lock transit makes the day too long, weather suggests a shorter run, or fuel margin calls for a different stopping decision. Change the proposed route to match the plan you can defend, then check distance, references, time and fuel again.</p>
            <p><strong>Reuse deliberately:</strong> select a saved My Route to load it again. Geometry overrides are saved with their route context; do not assume one edit updates every other route using similar waters. After changing the leg sequence or regenerating a saved route, reopen each edited leg and verify that its geometry and mileage still belong to the correct endpoints. Reset is not a general undo of changes already saved.</p>
            <p>Plan these changes before departure. An active trip has additional controls and restrictions; this tutorial does not promise that rebuilding an active route will safely replace its live itinerary.</p>
          </section>

          <section id="route-constraints" tabindex="-1" aria-labelledby="route-constraints-title">
            <h2 id="route-constraints-title">Connect Great Loop bridge research to the route you drew</h2>
            <ol>
              <li>Start with the proposed route and open the <a href="<cfoutput>#fpwLoopPlanningBasePath#</cfoutput>/great-loop/bridges/">Great Loop Bridges references</a>. Identify the entries relevant to the waterways and approach you intend to use.</li>
              <li>Compare your boat's air draft with the applicable information. Distinguish fixed structures from opening bridges and closed clearance from open clearance. Confirm current conditions and operating information before depending on passage.</li>
              <li>If the approach changes, decide whether to edit a leg's geometry or rebuild the waypoint sequence. A drawn override does not perform an automatic clearance check.</li>
              <li>Load the changed route and review mileage, timing and fuel again. An approach change can affect more than the bridge crossing itself.</li>
            </ol>
            <p>For the Chicago-area example, use the <a href="<cfoutput>#fpwLoopPlanningBasePath#</cfoutput>/great-loop/bridges/route/illinois-chicago/">Illinois / Chicago bridge references</a> and the <a href="<cfoutput>#fpwLoopPlanningBasePath#</cfoutput>/great-loop/bridges/chicago-river-bridge-group-downtown-route-air-draft-control-glb-0002/">Chicago River approach reference</a>. The latter provides context for evaluating downtown Chicago and Cal-Sag alternatives. Use it to organize the comparison; it does not select a suitable approach for your vessel.</p>
          </section>

          <section id="lock-timing" tabindex="-1" aria-labelledby="lock-timing-title">
            <h2 id="lock-timing-title">Running time is only part of a lock day</h2>
            <p>A realistic day may include underway time, lock approach and maneuvering, waiting, lock passage, bridge timing, fuel or rest stops, and weather margin. Distance divided by speed covers only part of that day.</p>
            <p>Open the <a href="<cfoutput>#fpwLoopPlanningBasePath#</cfoutput>/great-loop/locks/">Great Loop Locks library</a> while reviewing the leg. Identify the facilities relevant to the selected path and use their individual pages as planning references. Confirm actual access and operating information separately; stored reference information is not a live queue or operating notice.</p>
            <p>Where a route leg has mapped lock information, its expanded <strong>Lock Navigation Details</strong> can show <strong>Best</strong>, <strong>Typical</strong> and <strong>Worst</strong> waiting estimates and notes. These are stored planning assumptions, not live waiting times. Waypoint-only legs may have no canonical lock mapping; absence of details does not mean there is no lock to research.</p>
            <p><strong>For the My Route workflow taught here, do not assume lock delays are automatically added to the timeline.</strong> A lock count or details panel is not proof that waiting and lock passage have been included. There is no per-lock delay entry in this screen.</p>
            <p>Estimate extra time separately from running time. For expected engine-idling time, enter an allowance in <strong>Idle Hours (total)</strong> and confirm <strong>Idle Burn (GPH)</strong>. That affects the summary hours and idle-fuel estimate; it does not automatically move the timeline's daily boundaries. Keep non-idling waits, bridge timing, shore stops and additional margin in your own schedule as well. Count each allowance once.</p>
          </section>

          <section id="fuel-per-leg" tabindex="-1" aria-labelledby="fuel-per-leg-title">
            <h2 id="fuel-per-leg-title">Use the corrected mileage to check fuel</h2>
            <ol>
              <li>Finish reviewing the path and reload the route. Read the effective leg NM and <strong>Total Distance</strong>. If you are checking one cruising day, use the distance you actually intend to cover that day rather than the entire multi-day route.</li>
              <li>Open the <a href="<cfoutput>#fpwLoopPlanningBasePath#</cfoutput>/boat-fuel-calculator/">Boat Fuel Calculator</a> and manually enter that value in <strong>Total Distance (NM)</strong>. Route Generator distances do not automatically transfer to this public calculator.</li>
              <li>Enter your <strong>Most Efficient Speed (kn)</strong>, <strong>GPH @ Efficient</strong>, <strong>Max Speed (kn)</strong> and applicable <strong>Fuel Burn @ Max (GPH)</strong>. Choose <strong>Pace</strong> and review the <strong>Weather Factor (%)</strong> assumption.</li>
              <li>Enter expected <strong>Idle Hours</strong> and <strong>Idle Burn (GPH)</strong> where appropriate. Use <strong>Usable Fuel Capacity</strong> and select your <strong>Reserve Method</strong>; do not substitute nominal tank size for fuel you can actually use.</li>
              <li>Review estimated fuel and range against usable fuel and the reserve you intend to preserve. Confirm practical refueling arrangements separately. If margin is uncomfortable, shorten or revise the leg and repeat the calculation.</li>
            </ol>
            <p>The Route Generator also provides its own fuel estimate using the loaded route and its inputs. The public calculator is a separate manual check, not a synchronized view of that route. Match distance, pace, burn, weather and idle assumptions deliberately, and update both tools after a material change.</p>
            <p>Neither result guarantees consumption or fuel availability. A comfortable estimate is useful only if the chosen path, boat performance and allowances are realistic.</p>
          </section>

          <section id="distance-and-time" tabindex="-1" aria-labelledby="distance-and-time-title">
            <h2 id="distance-and-time-title">Turn generated mileage into a realistic day's schedule</h2>
            <p><strong>Distance alone is not the schedule.</strong> FPW uses effective leg mileage, the selected pace and speed inputs, and weather adjustments to estimate running time. The timeline uses the daily-hours budget to group travel into planning days. It does not establish a guaranteed arrival clock time or confirm an overnight stop.</p>
            <ol>
              <li>Finalize the leg geometry and choose <strong>Load</strong> to review the current NM. Verify the displayed distance after every material route change.</li>
              <li>Confirm the selected <strong>Vessel</strong>, speed inputs and <strong>Pace</strong>. Review <strong>Adjusted Speed</strong> and <strong>Total Travel Hours</strong>. The weather allowance can affect modeled speed; it does not replace checking the forecast.</li>
              <li>Set <strong>Underway Hrs / Day</strong> to a realistic travel budget. Review the resulting allocation, particularly any leg split across planning days.</li>
              <li>Add your researched lock and bridge allowances, fuel/rest stops and margin to the day's running estimate. Treat Idle Hours as a summary allowance, not an automatic appointment scheduler.</li>
              <li>Compare the realistic total with your departure window, daylight and intended arrival. If the day is too ambitious, change the waypoint endpoint or shorten the planned run and load it again.</li>
              <li>When preparing the Float Plan, review its departure and <strong>Return Date &amp; Time</strong> in the selected timezone. Set a realistic return value; an earlier geometry or idle-time edit is not confirmation that the Float Plan's time has changed.</li>
            </ol>
            <p>The generated estimate helps compare choices. Your captain-adjusted schedule adds the constraints that the model does not know. Keep those assumptions available when you review the route and explain the plan to your shore contact.</p>
          </section>

          <section id="overnight-stops" tabindex="-1" aria-labelledby="overnight-stops-title">
            <h2 id="overnight-stops-title">Choose the daily stopping point after reviewing the estimates</h2>
            <p>Use the combined distance, running time, delays and fuel requirement to decide where the day should end. A timeline split is not a recommendation to stop at that exact point. Check whether a marina, anchorage, mooring or other stopping area is suitable, accessible and available for your boat.</p>
            <p>Save an appropriate waypoint for the endpoint you have researched and use it when building the day's route. If the current leg goes farther than the day can support, revise the waypoint sequence and review the changed geometry and NM. FPW does not confirm marina availability or make stopping arrangements for you.</p>
            <p>Identify an earlier suitable option before departure. When a meaningful delay changes remaining time, daylight or fuel margin, reconsider the endpoint while alternatives remain available. Communicate material route or timing changes to your shore contact.</p>
          </section>

          <section id="chicago-starved-rock" tabindex="-1" aria-labelledby="chicago-starved-rock-title">
            <h2 id="chicago-starved-rock-title">Worked example: Building a Chicago-area Loop leg in FPW</h2>
            <p>Use Chicago toward the Starved Rock corridor to practice the workflow. This is a <strong>planning/reference example, not a guaranteed lock sequence or prescribed itinerary</strong>. It does not assume the corridor is one day's run. Choose the actual start, approach and daily endpoint for your boat and conditions. The practice screenshots above illustrate the controls only; they do not depict this corridor.</p>
            <ol>
              <li><strong>Build the starting route.</strong> Save the waypoints for the departure and intended endpoint you are evaluating. Choose <strong>+ Create Route</strong>, name the My Route, choose <strong>Set Start</strong>, add the next waypoint with <strong>Add Leg</strong>, and choose <strong>Load</strong>. Do not assume the initial line follows the waterway.</li>
              <li><strong>Review Chicago bridge constraints.</strong> Use the <a href="<cfoutput>#fpwLoopPlanningBasePath#</cfoutput>/great-loop/bridges/route/illinois-chicago/">Illinois / Chicago references</a> to compare the selected approach with your boat's air draft. Determine which path needs further checking before accepting the route.</li>
              <li><strong>Review potentially relevant lock references.</strong> The <a href="<cfoutput>#fpwLoopPlanningBasePath#</cfoutput>/great-loop/locks/waterway/chicago-illinois-waterway/">Chicago / Illinois Waterway references</a> help organize that research. The following list is <strong>unordered and does not establish a travel sequence</strong>:<ul><li><a href="<cfoutput>#fpwLoopPlanningBasePath#</cfoutput>/great-loop/locks/brandon-road-lock/">Brandon Road Lock</a></li><li><a href="<cfoutput>#fpwLoopPlanningBasePath#</cfoutput>/great-loop/locks/dresden-island-lock/">Dresden Island Lock</a></li><li><a href="<cfoutput>#fpwLoopPlanningBasePath#</cfoutput>/great-loop/locks/lockport-lock/">Lockport Lock</a></li><li><a href="<cfoutput>#fpwLoopPlanningBasePath#</cfoutput>/great-loop/locks/marseilles-lock/">Marseilles Lock</a></li><li><a href="<cfoutput>#fpwLoopPlanningBasePath#</cfoutput>/great-loop/locks/starved-rock-lock/">Starved Rock Lock</a></li><li><a href="<cfoutput>#fpwLoopPlanningBasePath#</cfoutput>/great-loop/locks/thomas-j-o-brien-lock/">Thomas J. O'Brien Lock</a></li></ul>Relevance depends on the approach and endpoints. FPW also provides a <a href="<cfoutput>#fpwLoopPlanningBasePath#</cfoutput>/great-loop/locks/chicago-harbor-lock/">Chicago Harbor Lock reference</a> for optional downtown routing. Establish the actual facilities and order on your selected route independently.</li>
              <li><strong>Inspect every leg's mileage.</strong> Compare its endpoints and effective NM with the navigable path you intend to run. Review the approach, not just the corridor's place names.</li>
              <li><strong>Correct the expected path where needed.</strong> Choose <strong>Edit Route</strong>, draw or edit the reviewed geometry, inspect <strong>Computed NM</strong> and choose <strong>Save Overrides</strong>. This replaces the distance used for that leg with the distance calculated from your saved line; it is not a numeric mileage-entry field.</li>
              <li><strong>Reevaluate running time.</strong> Load the My Route again. Confirm speed, pace, daily hours and the refreshed estimate. Do not carry forward the first distance or timing figure after changing the path.</li>
              <li><strong>Account for locks and other delay.</strong> Use the selected lock references and current operating information to build your own allowance. The custom My Route timeline does not automatically include those lock delays. Enter expected idle time for the fuel/summary calculation and review the full schedule separately.</li>
              <li><strong>Check fuel.</strong> Enter the corrected daily distance manually in the <a href="<cfoutput>#fpwLoopPlanningBasePath#</cfoutput>/boat-fuel-calculator/">Boat Fuel Calculator</a>. Apply the boat's realistic performance, idle allowance and reserve. Revise the leg if the margin is inadequate.</li>
              <li><strong>Decide where the day should end.</strong> Evaluate a suitable endpoint against realistic time, fuel and daylight. If necessary, revise the waypoint sequence and repeat the review before saving the route and preparing the Float Plan.</li>
            </ol>
            <p>The goal is to turn the initial route into the route you actually intend to run. A useful result is a reviewed plan with room to adapt, not a promised arrival at Starved Rock.</p>
          </section>

          <section id="route-to-float-plan" tabindex="-1" aria-labelledby="route-to-float-plan-title">
            <h2 id="route-to-float-plan-title">Turn the finished route into the trip you'll actually run</h2>
            <p>After reviewing the route and choosing <strong>Save Route</strong>, return to the dashboard's <strong>Routes</strong> list. The <strong>Activate Route</strong> action prepares a draft Float Plan and opens its editor. Despite that action's name, this step alone does not send the plan or start monitoring. An existing draft can be reopened with <strong>Complete Float Plan</strong>.</p>
            <p>Work through the Float Plan editor: confirm the vessel and operator, passengers where applicable, route details, departure, return date/time and timezone. Review the itinerary instead of assuming that every earlier planning change has already updated the draft. Select the intended shore contact and check the final review.</p>
            <p><strong>Save Float Plan</strong> saves the draft without sending. The review screen presents separate send choices: <strong>Basic Save &amp; Send</strong> emails a PDF copy to one selected contact and leaves the plan as a draft; <strong>Premium Save &amp; Send</strong> uses the operational sharing path when the account qualifies. Follow the explanation shown for the action you choose rather than treating these choices as equivalent.</p>
            <p>Arrange a shore contact who agrees to receive and understand the trip details. Share the reviewed plan before departure, confirm expectations for check-ins and changes, and review <a href="<cfoutput>#fpwLoopPlanningBasePath#</cfoutput>/why-use-a-float-plan/">how a Float Plan helps your shore contact</a>. Saving or generating a route alone does not notify anyone.</p>
            <p>For a later voyage, start from the saved route and review the new trip's details and schedule. Do not reuse an old shared plan as evidence that someone has received the current plan.</p>
          </section>

          <section id="daily-checklist" tabindex="-1" aria-labelledby="daily-checklist-title">
            <h2 id="daily-checklist-title">Before accepting tomorrow's Great Loop leg</h2>
            <p>Review the tools and decisions together before departure:</p>
            <ul class="fpw-overdue-checklist">
              <li>Boat air draft, draft, loading and usable fuel reviewed</li>
              <li>Saved waypoints checked; intended route built and loaded in FPW</li>
              <li>Every leg's endpoints, navigable path and generated NM reviewed</li>
              <li>Geometry overrides saved where needed; resulting leg and route NM checked</li>
              <li>Bridge constraints and relevant lock references reviewed for the selected path</li>
              <li>Vessel, speed inputs and Pace confirmed</li>
              <li>Fresh timing estimate and Underway Hrs / Day reviewed</li>
              <li>Lock/bridge waits, idle time, stops and margin considered without double-counting</li>
              <li>Corrected daily NM entered manually in the Fuel Calculator</li>
              <li>Fuel requirement checked and intended reserve preserved</li>
              <li>Daily endpoint and earlier alternative researched for suitability and availability</li>
              <li>Weather and current operating information checked</li>
              <li>Changed routes reloaded; edited legs and totals checked again</li>
              <li>Float Plan itinerary, departure, return time and timezone reviewed</li>
              <li>Shore contact identified; final Float Plan ready to share before departure</li>
            </ul>
          </section>

          <section id="start-planning" tabindex="-1" aria-labelledby="start-planning-title">
            <h2 id="start-planning-title">Turn your Great Loop research into an actual trip plan</h2>
            <p>Bring your boat's limits, reviewed route, corrected geometry, realistic timing and fuel check into one planning workflow. Then review the Float Plan for the voyage you actually intend to run.</p>
            <div class="fpw-overdue-cta-wrap">
              <cfinclude template="../../partials/fpw-action-cta.cfm">
            </div>
            <p>Need to check your range first? <a href="<cfoutput>#fpwLoopPlanningBasePath#</cfoutput>/boat-fuel-calculator/">Use the Boat Fuel Calculator</a>.</p>
          </section>
        </div>
      </div>
    </article>
  </div>
</main>

<cfinclude template="../../includes/footer.cfm">
<script src="<cfoutput>#fpwLoopPlanningBasePath#</cfoutput>/assets/js/fpw-action-cta.js?v=20260804-pilot"></script>
</body>
</html>
