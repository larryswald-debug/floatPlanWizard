<cfprocessingdirective pageencoding="utf-8">
<cfsetting showdebugoutput="false" requesttimeout="30">
<cfcontent type="text/html; charset=utf-8">
<cfinclude template="../../includes/fpw_base_path.cfm">
<cfscript>
request.fpwTopNavActive = "resources-chesapeake-guide";
fpwChesapeakeBasePath = request.fpwBase;
fpwChesapeakeCanonicalUrl = "https://floatplanwizard.com/boating-guides/chesapeake-bay/";
fpwChesapeakePageTitle = "Chesapeake Bay Cruising Guide: Routes & Trip Planning | FPW";
fpwChesapeakePageDescription = "Plan a Chesapeake Bay cruise with destination ideas, realistic timing, fuel checks, weather sources and a step-by-step FPW route and float plan workflow.";
fpwChesapeakeHeadline = "Chesapeake Bay Cruising Guide: Routes, Destinations, Travel Times & Float Plan Planning";
fpwChesapeakeSocialImage = "https://floatplanwizard.com/assets/images/social/floatplanwizard-social-preview-20260730.png";
fpwChesapeakeModifiedDate = "2026-10-28";
schemaAtKey = chr(64);
schemaTypeKey = schemaAtKey & "type";
schemaIdKey = schemaAtKey & "id";
schemaContextKey = schemaAtKey & "context";
schemaGraphKey = schemaAtKey & "graph";
function fpwChesapeakeSchemaRef(required string idValue) {
  var out = structNew("ordered");
  structInsert(out, schemaIdKey, arguments.idValue, true);
  return out;
}
function fpwChesapeakeSchemaListItem(required numeric position, required string name, required string urlValue) {
  var out = structNew("ordered");
  var item = structNew("ordered");
  structInsert(out, schemaTypeKey, "ListItem", true);
  out["position"] = arguments.position;
  structInsert(item, schemaIdKey, arguments.urlValue, true);
  item["name"] = arguments.name;
  out["item"] = item;
  return out;
}
fpwChesapeakeOrganizationId = "https://floatplanwizard.com/##organization";
fpwChesapeakeArticleId = fpwChesapeakeCanonicalUrl & "##article";
fpwChesapeakeWebPageId = fpwChesapeakeCanonicalUrl & "##webpage";
fpwChesapeakeSchemaGraph = [];
fpwChesapeakeSchemaOrg = structNew("ordered");
structInsert(fpwChesapeakeSchemaOrg, schemaTypeKey, "Organization", true);
structInsert(fpwChesapeakeSchemaOrg, schemaIdKey, fpwChesapeakeOrganizationId, true);
fpwChesapeakeSchemaOrg["name"] = "FloatPlanWizard";
fpwChesapeakeSchemaOrg["url"] = "https://floatplanwizard.com/";
fpwChesapeakeSchemaOrg["logo"] = "https://floatplanwizard.com/assets/images/checkout/floatplanwizard-logo.jpg";
arrayAppend(fpwChesapeakeSchemaGraph, fpwChesapeakeSchemaOrg);
fpwChesapeakeSchemaBreadcrumb = structNew("ordered");
structInsert(fpwChesapeakeSchemaBreadcrumb, schemaTypeKey, "BreadcrumbList", true);
structInsert(fpwChesapeakeSchemaBreadcrumb, schemaIdKey, fpwChesapeakeCanonicalUrl & "##breadcrumb", true);
fpwChesapeakeSchemaBreadcrumb["itemListElement"] = [
  fpwChesapeakeSchemaListItem(1, "FloatPlanWizard", "https://floatplanwizard.com/"),
  fpwChesapeakeSchemaListItem(2, "Chesapeake Bay Cruising Guide", fpwChesapeakeCanonicalUrl)
];
arrayAppend(fpwChesapeakeSchemaGraph, fpwChesapeakeSchemaBreadcrumb);
fpwChesapeakeSchemaPage = structNew("ordered");
structInsert(fpwChesapeakeSchemaPage, schemaTypeKey, "WebPage", true);
structInsert(fpwChesapeakeSchemaPage, schemaIdKey, fpwChesapeakeWebPageId, true);
fpwChesapeakeSchemaPage["url"] = fpwChesapeakeCanonicalUrl;
fpwChesapeakeSchemaPage["name"] = fpwChesapeakePageTitle;
fpwChesapeakeSchemaPage["description"] = fpwChesapeakePageDescription;
fpwChesapeakeSchemaPage["breadcrumb"] = fpwChesapeakeSchemaRef(fpwChesapeakeCanonicalUrl & "##breadcrumb");
fpwChesapeakeSchemaPage["mainEntity"] = fpwChesapeakeSchemaRef(fpwChesapeakeArticleId);
fpwChesapeakeSchemaPage["publisher"] = fpwChesapeakeSchemaRef(fpwChesapeakeOrganizationId);
arrayAppend(fpwChesapeakeSchemaGraph, fpwChesapeakeSchemaPage);
fpwChesapeakeSchemaArticle = structNew("ordered");
structInsert(fpwChesapeakeSchemaArticle, schemaTypeKey, "Article", true);
structInsert(fpwChesapeakeSchemaArticle, schemaIdKey, fpwChesapeakeArticleId, true);
fpwChesapeakeSchemaArticle["url"] = fpwChesapeakeCanonicalUrl;
fpwChesapeakeSchemaArticle["headline"] = fpwChesapeakeHeadline;
fpwChesapeakeSchemaArticle["description"] = fpwChesapeakePageDescription;
fpwChesapeakeSchemaArticle["dateModified"] = fpwChesapeakeModifiedDate;
fpwChesapeakeSchemaArticle["articleSection"] = "Cruising and Trip Planning";
fpwChesapeakeSchemaArticle["inLanguage"] = "en";
fpwChesapeakeSchemaArticle["author"] = fpwChesapeakeSchemaRef(fpwChesapeakeOrganizationId);
fpwChesapeakeSchemaArticle["publisher"] = fpwChesapeakeSchemaRef(fpwChesapeakeOrganizationId);
fpwChesapeakeSchemaArticle["mainEntityOfPage"] = fpwChesapeakeSchemaRef(fpwChesapeakeWebPageId);
arrayAppend(fpwChesapeakeSchemaGraph, fpwChesapeakeSchemaArticle);
fpwChesapeakeJsonLd = structNew("ordered");
structInsert(fpwChesapeakeJsonLd, schemaContextKey, "https://schema.org", true);
structInsert(fpwChesapeakeJsonLd, schemaGraphKey, fpwChesapeakeSchemaGraph, true);
fpwChesapeakeJsonLdText = replace(serializeJSON(fpwChesapeakeJsonLd), "</", "<\/", "all");
fpwChesapeakeUserId = 0;
if (structKeyExists(session, "user") AND isStruct(session.user)) {
  for (fpwChesapeakeUserIdKey in [ "userId", "id", "USERID", "ID" ]) {
    if (structKeyExists(session.user, fpwChesapeakeUserIdKey) AND isNumeric(session.user[fpwChesapeakeUserIdKey])) {
      fpwChesapeakeUserId = val(session.user[fpwChesapeakeUserIdKey]);
      break;
    }
  }
}
fpwChesapeakePlannerDestination = fpwChesapeakeBasePath & (fpwChesapeakeUserId GT 0 ? "/app/dashboard.cfm" : "/app/join.cfm");
</cfscript>
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <cfoutput>
  <title>#encodeForHTML(fpwChesapeakePageTitle)#</title>
  <meta name="description" content="#encodeForHTMLAttribute(fpwChesapeakePageDescription)#">
  <meta name="robots" content="index,follow">
  <link rel="canonical" href="#encodeForHTMLAttribute(fpwChesapeakeCanonicalUrl)#">
  <meta property="og:type" content="article">
  <meta property="og:site_name" content="FloatPlanWizard">
  <meta property="og:url" content="#encodeForHTMLAttribute(fpwChesapeakeCanonicalUrl)#">
  <meta property="og:title" content="#encodeForHTMLAttribute(fpwChesapeakePageTitle)#">
  <meta property="og:description" content="#encodeForHTMLAttribute(fpwChesapeakePageDescription)#">
  <meta property="og:image" content="#encodeForHTMLAttribute(fpwChesapeakeSocialImage)#">
  <meta property="og:image:width" content="1200">
  <meta property="og:image:height" content="630">
  <meta property="og:image:alt" content="FloatPlanWizard boating trip planning, float-plan sharing, and check-in preview">
  <meta name="twitter:card" content="summary_large_image">
  <meta name="twitter:title" content="#encodeForHTMLAttribute(fpwChesapeakePageTitle)#">
  <meta name="twitter:description" content="#encodeForHTMLAttribute(fpwChesapeakePageDescription)#">
  <meta name="twitter:image" content="#encodeForHTMLAttribute(fpwChesapeakeSocialImage)#">
  <script type="application/ld+json">#fpwChesapeakeJsonLdText#</script>
  <link rel="icon" type="image/svg+xml" href="#fpwChesapeakeBasePath#/assets/images/landing/fpw-logo.svg">
  <link rel="stylesheet" href="#fpwChesapeakeBasePath#/assets/css/layout.css?v=20260620-page-width">
  <link rel="stylesheet" href="#fpwChesapeakeBasePath#/assets/css/top-nav.css?v=20261013-global-help">
  <link rel="stylesheet" href="#fpwChesapeakeBasePath#/assets/css/shore-contact-overdue-guide.css?v=20260806-cta-color">
  </cfoutput>
  <style>
    #main-content > .fpw-overdue-shell { width: min(var(--fpw-public-layout-max), calc(100% - (var(--fpw-page-gutter, 32px) * 2))); }
    #main-content .fpw-overdue-content > section { scroll-margin-top: 165px; }
    .fpw-chesapeake-figure { margin: 24px 0; }
    .fpw-chesapeake-figure img { display: block; max-width: 100%; height: auto; margin: 0 auto; border: 1px solid var(--fpw-overdue-line); border-radius: 12px; }
    .fpw-chesapeake-figure figcaption { margin-top: 10px; color: var(--fpw-overdue-muted); font-size: 0.9rem; line-height: 1.6; }
    .fpw-chesapeake-reviewed { margin-top: 14px; color: var(--fpw-overdue-muted); font-size: 0.9rem; }
    #main-content .fpw-overdue-content h3 { margin-top: 24px; }
    #main-content .fpw-overdue-content h3 + p { margin-top: 10px; }
    #main-content .fpw-chesapeake-action { font-weight: 700; }
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
      <a href="<cfoutput>#fpwChesapeakeBasePath#</cfoutput>/">FloatPlanWizard</a>
      <span aria-hidden="true">&rsaquo;</span>
      <span aria-current="page">Chesapeake Bay Cruising Guide</span>
    </nav>
    <article class="fpw-overdue-article" aria-labelledby="fpw-chesapeake-title">
      <header class="fpw-overdue-hero">
        <p class="fpw-overdue-eyebrow">Cruising and Trip Planning</p>
        <h1 id="fpw-chesapeake-title"><cfoutput>#encodeForHTML(fpwChesapeakeHeadline)#</cfoutput></h1>
        <p class="fpw-overdue-lede">Choose a manageable part of the Bay, research the actual harbor approaches, and turn a destination list into daily legs your boat and crew can handle. This guide connects those decisions to FPW's route builder, distance overrides, fuel estimates, timing and Float Plan workflow.</p>
        <p class="fpw-chesapeake-reviewed">Reviewed <time datetime="2026-10-28">October 28, 2026</time>. Check current conditions and operating information before departure.</p>
      </header>
      <aside class="fpw-overdue-emergency" role="note" aria-labelledby="fpw-chesapeake-planning-note">
        <strong id="fpw-chesapeake-planning-note">Plan the trip here; verify the navigable route separately.</strong>
        <p>The itineraries and screenshots are planning examples. They do not establish safe channels, depths, bridge clearances or suitable overnight stops. Use current charts, official notices, local information and the vessel's limits to verify the route.</p>
      </aside>
      <div class="fpw-overdue-layout">
        <nav class="fpw-overdue-toc" aria-labelledby="fpw-chesapeake-toc-title">
          <h2 id="fpw-chesapeake-toc-title">In this guide</h2>
          <ol>
            <li><a href="#plan-a-cruise">Plan a Chesapeake cruise</a></li>
            <li><a href="#destinations">Choose destinations</a></li>
            <li><a href="#itineraries">Weekend, 3-day and 7-day ideas</a></li>
            <li><a href="#build-a-route">Build and review an FPW route</a></li>
            <li><a href="#fuel">Calculate fuel requirements</a></li>
            <li><a href="#arrival-times">Estimate arrival times</a></li>
            <li><a href="#weather-tides-currents">Check weather, tides and currents</a></li>
            <li><a href="#overnight-alternatives">Choose overnight stops and alternatives</a></li>
            <li><a href="#float-plan">Create the Float Plan</a></li>
            <li><a href="#faq">Chesapeake cruising FAQ</a></li>
          </ol>
          <p><a href="#sources">Sources and planning references</a></p>
        </nav>
        <div class="fpw-overdue-content">
          <section id="plan-a-cruise" tabindex="-1" aria-labelledby="plan-a-cruise-title">
            <h2 id="plan-a-cruise-title">1. Planning a Chesapeake Bay cruise</h2>
            <p>Start with a cruising area, not a checklist of famous towns. Annapolis and the central Eastern Shore, the Patuxent area around Solomons, and the lower Bay around Deltaville, Yorktown and Norfolk offer different combinations of open-Bay travel and river approaches. A town can look close across land while the usable water route runs around a peninsula or well into a tributary.</p>
            <p>Choose the departure harbor, the time available and the crew's preferred daily underway limit. Then identify specific arrival points. A town name is useful for choosing a region; the entrance and berth or anchoring area determine the last part of the route. Separate the outward and return legs and keep time to revise the plan.</p>
            <p>Season changes the planning problem. NOAA describes warm-season thunderstorms and frontal storms, while winter ice can affect some tributaries. Review the actual forecast instead of treating a season or an early departure as a guarantee. Daylight, crew comfort and access to a suitable stopping place also constrain the travel day. See <a target="_blank" rel="noopener" href="https://nauticalcharts.noaa.gov/publications/coast-pilot/files/cp3/CPB3_C03_WEB.pdf">NOAA Coast Pilot 3 weather guidance</a> and its <a target="_blank" rel="noopener" href="https://nauticalcharts.noaa.gov/publications/coast-pilot/files/cp3/CPB3_C13_WEB.pdf">western Chesapeake coverage</a>.</p>
            <p>Prepare one worksheet per day: verified route distance, realistic cruising speed, expected delays, fuel requirement, arrival window and an earlier alternative. A manageable first cruise often means fewer destinations and more time to understand the boat and the approaches.</p>
          </section>

          <section id="destinations" tabindex="-1" aria-labelledby="destinations-title">
            <h2 id="destinations-title">2. Chesapeake cruising destinations</h2>
            <p>These geographic starting points help you research a stop. They do not confirm a berth, fuel supply, available depth or an anchorage. Before committing, ask the intended operator about current access, vessel suitability, reservations and arrival arrangements.</p>
            <h3>Annapolis</h3>
            <p>Plan the Severn River approach and the actual waterfront destination, including whether it lies in Spa Creek. Include the harbor approach in your mileage. The <a target="_blank" rel="noopener" href="https://annapolis.gov/177/Docking">Annapolis Harbormaster's docking information</a> is the starting point for municipal arrangements; <a target="_blank" rel="noopener" href="https://nauticalcharts.noaa.gov/publications/coast-pilot/files/cp3/CPB3_C13_WEB.pdf">NOAA chapter 13</a> provides navigation context.</p>
            <h3>St. Michaels and Oxford</h3>
            <p>St. Michaels' main waterfront is on the Miles River, approached through Eastern Bay. Oxford is on the Tred Avon River, with waterfront facilities along Town Creek. Select the intended side and facility before measuring either approach. Their proximity on a road map does not create a navigable shortcut. Research both in <a target="_blank" rel="noopener" href="https://nauticalcharts.noaa.gov/publications/coast-pilot/files/cp3/CPB3_C14_WEB.pdf">NOAA's Eastern Shore chapter</a>; the <a target="_blank" rel="noopener" href="https://www.oxfordmd.gov/DocumentCenter/View/165/Oxford-Working-Waterfront-Plan-PDF">Oxford waterfront plan</a> adds local context.</p>
            <h3>Cambridge</h3>
            <p>Cambridge is on the Choptank River. Distinguish the municipal yacht basin near the mouth of Cambridge Creek from a destination farther inside the creek. Check whether the chosen berth introduces a bridge dependency. Use the <a target="_blank" rel="noopener" href="https://choosecambridge.com/248/Marina-Parks">city's marina information</a> and current navigation references to research the actual arrival point.</p>
            <h3>Solomons</h3>
            <p>Research the Patuxent River approach and the specific creek or facility; Back Creek and Mill Creek are distinct waterfront areas. An endpoint simply called Solomons is not enough for final distance or approach planning. See <a target="_blank" rel="noopener" href="https://nauticalcharts.noaa.gov/publications/coast-pilot/files/cp3/CPB3_C13_WEB.pdf">NOAA chapter 13</a> for geographic and navigation context.</p>
            <h3>Deltaville</h3>
            <p>Deltaville lies between the Rappahannock and Piankatank rivers, with boating destinations in separate creeks and harbors. Select the harbor first, then research its entrance and the intended operator. The <a target="_blank" rel="noopener" href="https://deltavilleva.com/things-to-do/where-to-boat/">Deltaville Community Association boating directory</a> helps identify candidates; it does not verify today's access or availability.</p>
            <h3>Yorktown and Norfolk</h3>
            <p>Yorktown's waterfront is on the York River. Confirm vessel suitability and arrival arrangements with the <a target="_blank" rel="noopener" href="https://visityorktown.org/Facilities/Facility/Details/Riverwalk-Landing-Piers-24">Riverwalk Landing Dockmaster</a>, and check whether your selected route needs bridge passage. Norfolk's downtown waterfront is on the Elizabeth River. Plan to a particular marina, allow for harbor traffic and review <a target="_blank" rel="noopener" href="https://nauticalcharts.noaa.gov/publications/coast-pilot/files/cp3/CPB3_C09_WEB.pdf">NOAA's Norfolk-area navigation context</a> together with current notices.</p>
          </section>

          <section id="itineraries" tabindex="-1" aria-labelledby="itineraries-title">
            <h2 id="itineraries-title">3. Illustrative Chesapeake itineraries</h2>
            <p><strong>These are destination sequences, not calculated passages.</strong> No distances or transit times are assigned. Measure the navigable legs and test them against your vessel, forecast, daylight and daily travel limit before deciding whether an example fits.</p>
            <h3>Weekend: Oxford, Cambridge and return</h3>
            <p>Consider Oxford to Cambridge, one overnight, then return to Oxford. Check whether each reviewed leg fits comfortably, including the harbor approaches and return-day weather. Shorten the trip if either day is too demanding.</p>
            <h3>3 days: Annapolis and St. Michaels with a stay day</h3>
            <p>Consider Annapolis to St. Michaels, a stay day, then return. Keep the middle day flexible. A layover can be more useful than adding another destination merely because a day is available.</p>
            <h3>7 days: a focused central-Bay exploration</h3>
            <p>Explore the Annapolis, Eastern Bay and Choptank area, considering St. Michaels, Oxford and Cambridge as candidate stops. Assign travel days only after reviewing every leg. Reserve layover or weather time and omit stops when the verified itinerary exceeds the crew's limits.</p>
            <p>For a lower-Bay vacation, choose a departure base and investigate a smaller group of lower-Bay stops instead. Do not try to combine all eight destinations in this guide into a fixed week. A faster boat may reduce running time, but speed alone does not resolve weather, approach, fuel or stopping constraints.</p>
          </section>

          <section id="build-a-route" tabindex="-1" aria-labelledby="build-a-route-title">
            <h2 id="build-a-route-title">4. Build a Chesapeake route using FPW</h2>
            <p>Route planning requires an FPW account and the dashboard's Getting Started information. Save the vessel, operator, shore contact and at least two waypoints first. Check the waypoint coordinates and names against your intended endpoints. Add passengers when applicable.</p>
            <p><strong>Practice example:</strong> the screenshots use Annapolis, Solomons and Norfolk to demonstrate a start, an intermediate stop and a destination. Catalog city points are not verified harbor approaches. This is not a recommended itinerary, daily schedule or navigable path, and the displayed practice figures must not be used for passage planning.</p>
            <ol>
              <li><strong>Open the Route Generator.</strong> From the dashboard, choose <strong>+ Create Route</strong> and enter a descriptive <strong>Route Name</strong>. Under <strong>My Routes &amp; Waypoint Builder</strong>, enter or check the name in <strong>Create Route</strong>, then choose <strong>Create</strong>.</li>
              <li><strong>Set departure.</strong> Select the saved departure under <strong>Route Start Waypoint</strong> and choose <strong>Set Start</strong>.</li>
              <li><strong>Add the intermediate stop and destination.</strong> Under <strong>Add Leg by Waypoint</strong>, select the next saved waypoint and choose <strong>Add Leg</strong>. Repeat in travel order. Each added leg continues from the previous endpoint.</li>
              <li><strong>Choose the vessel and assumptions.</strong> Select the correct <strong>Vessel</strong>. Review speed, fuel-burn inputs, <strong>Pace</strong>, <strong>Adjusted Speed</strong> and <strong>Underway Hrs / Day</strong>. Confirm the planner speeds are in knots: the vessel editor currently labels its speed fields KPH, so do not assume a conversion.</li>
              <li><strong>Load the proposed route.</strong> Choose <strong>Load</strong> to populate <strong>Route Summary and Legs</strong> and the <strong>Cruise Timeline</strong>. Inspect each leg's endpoints and NM, then the total distance, travel hours and estimated fuel.</li>
            </ol>
            <figure class="fpw-chesapeake-figure">
              <a href="<cfoutput>#fpwChesapeakeBasePath#</cfoutput>/assets/images/boating-guides/chesapeake-bay/route-builder.webp" aria-label="View larger FPW Chesapeake practice route builder screenshot"><img src="<cfoutput>#fpwChesapeakeBasePath#</cfoutput>/assets/images/boating-guides/chesapeake-bay/route-builder.webp" width="1440" height="1000" loading="lazy" decoding="async" alt="Current FPW route builder using Annapolis, Solomons and Norfolk as practice waypoints"></a>
              <figcaption>Current application example: build a waypoint sequence, select the vessel and review the loaded route. City reference points and practice values do not define a navigable Chesapeake passage.</figcaption>
            </figure>
            <h3>Review the path before trusting the mileage</h3>
            <p>A new waypoint leg may begin with a direct line between coordinates. That distance can omit channel bends, a river entrance, the intended harbor approach or a deliberate detour. An apparently precise number does not prove the line follows navigable water.</p>
            <p><strong>FPW's mileage override is a geometry edit, not a numeric mileage box.</strong> First establish the intended navigable path using current navigation information. Then use the map to represent that reviewed path:</p>
            <ol start="6">
              <li>Choose <strong>Edit Route</strong> beside the leg to open <strong>Leg Geometry</strong>. Check the leg title, source and <strong>Computed NM</strong>.</li>
              <li>Use <strong>Draw a polyline</strong> for a new path or <strong>Edit layers</strong> for an existing line. Finish the map edit, inspect its endpoints and intermediate points, and review the recalculated <strong>Computed NM</strong>.</li>
              <li>Choose <strong>Save Overrides</strong>. Completing the drawing alone does not save it. Close the panel and inspect the leg's effective NM and override indication.</li>
              <li>Choose <strong>Load</strong> for the selected My Route again. Review the refreshed distance, timing and fuel estimates with the intended vessel and daily hours. There is no separate <strong>Recalculate Timing</strong> button in this workflow.</li>
              <li>Review the complete itinerary and choose <strong>Save Route</strong>. Check the saved route before preparing the Float Plan.</li>
            </ol>
            <figure class="fpw-chesapeake-figure">
              <a href="<cfoutput>#fpwChesapeakeBasePath#</cfoutput>/assets/images/boating-guides/chesapeake-bay/leg-geometry.webp" aria-label="View larger FPW Leg Geometry screenshot"><img src="<cfoutput>#fpwChesapeakeBasePath#</cfoutput>/assets/images/boating-guides/chesapeake-bay/leg-geometry.webp" width="1440" height="1000" loading="lazy" decoding="async" alt="FPW Leg Geometry panel with Computed NM and Save Overrides controls"></a>
              <figcaption>The geometry editor calculates mileage from the line you supply. This screenshot shows the default state before a reviewed path is saved; it does not verify a channel or provide a route to follow.</figcaption>
            </figure>
            <p>A geometry change does not move the destination or verify hazards. For different stops, revise the waypoint sequence and review the connecting legs again. Do not assume an existing Float Plan or the separate public Fuel Calculator inherits the change.</p>
            <p class="fpw-chesapeake-action"><a href="<cfoutput>#encodeForHTMLAttribute(fpwChesapeakePlannerDestination)#</cfoutput>" data-fpw-auth-intent="planner" data-fpw-auth-source-page="chesapeake_bay_guide" data-fpw-auth-section="build_route" data-fpw-auth-cta-type="plan_trip" data-fpw-auth-label="Plan This Route in FPW">Plan This Route in FPW</a></p>
            <p>This opens the planning workspace through the existing sign-in/setup flow. It does not import the example or create a Chesapeake route automatically. For broader instructions, see the <a href="<cfoutput>#fpwChesapeakeBasePath#</cfoutput>/app/user-manual.cfm">FPW User Manual</a> and <a href="<cfoutput>#fpwChesapeakeBasePath#</cfoutput>/great-loop/trip-planning/">Great Loop Trip Planning Guide</a>.</p>
          </section>

          <section id="fuel" tabindex="-1" aria-labelledby="fuel-title">
            <h2 id="fuel-title">5. Calculate fuel requirements</h2>
            <p>Use the corrected navigable distance and your vessel's realistic performance at the chosen speed. Review saved vessel specifications instead of accepting a default burn rate. Load the route again after changing distance or planning inputs, then compare its fuel estimate with the usable fuel aboard.</p>
            <p>The separate public <a href="<cfoutput>#fpwChesapeakeBasePath#</cfoutput>/boat-fuel-calculator/">Boat Fuel Calculator</a> requires you to enter the trip's distance and relevant vessel figures. It does not automatically import the route, a geometry override or your saved vessel. Transfer the reviewed values and repeat the calculation after route changes.</p>
            <p>Keep cruising consumption, any explicit idle allowance and the selected reserve method distinct. A longer route can increase required fuel and reduce your remaining margin. Higher speed may change fuel burn; use figures appropriate to that operating condition. Weather and loading can also make an optimistic performance assumption unsuitable.</p>
            <p>Reserve fuel should remain available for uncertainty and alternatives. Check the calculator's chosen method and displayed result; do not confuse an extra allowance with permission to use all usable fuel. Confirm any planned refueling stop directly and revise the day if the boat cannot reach a suitable alternative with the intended margin.</p>
            <p class="fpw-chesapeake-action"><a href="<cfoutput>#fpwChesapeakeBasePath#</cfoutput>/boat-fuel-calculator/">Estimate Fuel for Your Trip</a></p>
          </section>

          <section id="arrival-times" tabindex="-1" aria-labelledby="arrival-times-title">
            <h2 id="arrival-times-title">6. Estimate arrival times realistically</h2>
            <p>Cruising time is the time spent covering the route at the assumed speed. Elapsed travel time also includes stops, waiting, maneuvering and delays. Keep those categories visible so a plausible running-time estimate does not become an unrealistic arrival promise.</p>
            <p><strong>Hypothetical arithmetic only:</strong> 30 nautical miles divided by 6 knots equals 5 cruising hours. Those inputs do not describe a Chesapeake leg. Stops and delays would extend elapsed time, and a different speed or reviewed distance changes the result.</p>
            <p>In FPW, review <strong>Adjusted Speed</strong>, <strong>Total Travel Hours</strong>, <strong>Underway Hrs / Day</strong> and the <strong>Cruise Timeline</strong>. Reload the My Route after a geometry change. A timeline day boundary is a time-budget result, not a verified marina or safe stopping place. Choose real endpoints that fit the day.</p>
            <p>Allow separately for the stops and conditions your voyage requires. An idle-fuel input is not evidence that every delay has been scheduled. Recheck the Float Plan's departure, return time and timezone after editing the route; an earlier draft may still contain earlier expectations.</p>
            <p class="fpw-chesapeake-action"><a href="<cfoutput>#encodeForHTMLAttribute(fpwChesapeakePlannerDestination)#</cfoutput>" data-fpw-auth-intent="planner" data-fpw-auth-source-page="chesapeake_bay_guide" data-fpw-auth-section="arrival_times" data-fpw-auth-cta-type="plan_trip" data-fpw-auth-label="Adjust Your Route Timing">Adjust Your Route Timing</a></p>
            <p>Open your saved route in the planning workspace, review its assumptions and use Load to inspect the estimates.</p>
          </section>

          <section id="weather-tides-currents" tabindex="-1" aria-labelledby="weather-tides-currents-title">
            <h2 id="weather-tides-currents-title">7. Weather, tides and currents</h2>
            <p>Check each marine forecast zone crossed, including river approaches. A town forecast or a single weather icon cannot represent the whole trip. Use the National Weather Service's <a target="_blank" rel="noopener" href="https://www.weather.gov/marine/lwxmz">Baltimore/Washington marine zones</a> and <a target="_blank" rel="noopener" href="https://www.weather.gov/marine/akqmz">Wakefield marine zones</a> to locate relevant forecasts and warnings.</p>
            <p>Consider wind direction as well as strength, the exposed portions of the route, visibility and thunderstorm risk. Leave room to delay departure, stay another night or choose a shorter day. Review conditions again before leaving and as the trip develops.</p>
            <p>Tide predictions concern water level; current predictions concern flow. Do not assume slack current occurs at high or low water. Use the relevant location and time from <a target="_blank" rel="noopener" href="https://tidesandcurrents.noaa.gov/noaacurrents/index.html">NOAA current predictions</a> and read <a target="_blank" rel="noopener" href="https://oceanservice.noaa.gov/facts/tidescurrents.html">NOAA's explanation of tides and currents</a>.</p>
            <p>Astronomical tide predictions do not include all wind, pressure and river-flow effects. NOAA's <a target="_blank" rel="noopener" href="https://tidesandcurrents.noaa.gov/ofs/cbofs/cbofs.html">Chesapeake Bay Operational Forecast System</a> provides modeled water-level and current guidance. A model forecast is not an observation or a certification of clearance.</p>
            <p>Members can open <a href="<cfoutput>#fpwChesapeakeBasePath#</cfoutput>/app/weather.cfm">FPW's Marine Weather Briefing</a> after signing in. Review the location, available products and timestamps. Use official sources where information is missing or needs confirmation. A forecast does not verify channel depth, an obstruction, bridge clearance or anchoring permission; those require current navigation information.</p>
          </section>

          <section id="overnight-alternatives" tabindex="-1" aria-labelledby="overnight-alternatives-title">
            <h2 id="overnight-alternatives-title">8. Overnight stops and alternate plans</h2>
            <p>Choose the night's endpoint before accepting the day's mileage. For a marina, confirm the actual arrival point, reservation, access and vessel suitability directly. For an anchoring candidate, research charted conditions, swing room, exposure, local rules and an escape option. An online pin or library entry does not verify suitability today.</p>
            <p>Research an earlier stopping option and an alternative if the intended destination is unavailable. Compare the distance to both, the remaining daylight and fuel, and the conditions on their approaches. An alternative that requires an unfamiliar approach after dark may not solve the original problem.</p>
            <p>Keep the timetable flexible enough to stay put when conditions are unsuitable. Update the planned route and shore contact when the destination or arrival expectation changes. FPW's <a href="<cfoutput>#fpwChesapeakeBasePath#</cfoutput>/great-loop/ports/">Ports Library</a> and <a href="<cfoutput>#fpwChesapeakeBasePath#</cfoutput>/great-loop/anchorages/">Anchorage Library</a> can support research; their entries are starting points for verification.</p>
          </section>

          <section id="float-plan" tabindex="-1" aria-labelledby="float-plan-title">
            <h2 id="float-plan-title">9. Create a Chesapeake Float Plan</h2>
            <p>After saving the reviewed route, return to the dashboard's <strong>Routes</strong> list. Select the route and choose <strong>Draft Float Plan</strong> in its details, or use the route-row <strong>Activate Route</strong> action. This prepares a draft and opens the Float Plan Wizard; an existing draft can be reopened with <strong>Complete Float Plan</strong>. Preparing that draft is separate from sending a plan or beginning an operational trip.</p>
            <ol>
              <li>Complete any requested sender name, then confirm the vessel and operator. Include the passengers who will actually be aboard.</li>
              <li>Review the itinerary against the saved route, including the intended departure, destination and stopping points.</li>
              <li>Check departure and return dates, times and timezone. Resolve any mismatch with the route's latest distance and schedule.</li>
              <li>Select the intended shore contact and verify the contact details. Agree on expected check-ins, how changes will be communicated and what to do if you are overdue.</li>
              <li>Review the finished plan. <strong>Save Float Plan</strong> saves a draft; use the separate send action when ready to share and read its explanation before proceeding.</li>
            </ol>
            <figure class="fpw-chesapeake-figure">
              <a href="<cfoutput>#fpwChesapeakeBasePath#</cfoutput>/assets/images/boating-guides/chesapeake-bay/float-plan.webp" aria-label="View larger FPW Float Plan editor screenshot"><img src="<cfoutput>#fpwChesapeakeBasePath#</cfoutput>/assets/images/boating-guides/chesapeake-bay/float-plan.webp" width="770" height="693" loading="lazy" decoding="async" alt="FPW Float Plan Wizard Times and Route step with departure, return and timezone fields awaiting review"></a>
              <figcaption>The Times &amp; Route step asks for the trip's departure, return and timezone. These practice fields still need completion. Creating or saving the draft does not itself send it to a shore contact.</figcaption>
            </figure>
            <p>Saving a route, preparing a Float Plan draft, sharing it and activating or monitoring a trip are distinct steps. Available send choices can have different effects; follow the description shown for the chosen action. Do not treat a saved route or draft as proof that anyone has received the current plan.</p>
            <p>Confirm receipt with the shore contact, keep them informed when the plan changes, and close the loop when safely arrived. Read <a href="<cfoutput>#fpwChesapeakeBasePath#</cfoutput>/why-use-a-float-plan/">why a float plan helps</a> and the <a href="<cfoutput>#fpwChesapeakeBasePath#</cfoutput>/shore-contact-overdue-boater/">Shore Contact Guide</a> together.</p>
            <p class="fpw-chesapeake-action"><a href="<cfoutput>#encodeForHTMLAttribute(fpwChesapeakePlannerDestination)#</cfoutput>" data-fpw-auth-intent="planner" data-fpw-auth-source-page="chesapeake_bay_guide" data-fpw-auth-section="float_plan" data-fpw-auth-cta-type="plan_trip" data-fpw-auth-label="Create a Float Plan">Create a Float Plan</a></p>
            <p>Continue through the planning workspace and your saved route. This link does not send a plan or start monitoring.</p>
          </section>

          <section id="faq" tabindex="-1" aria-labelledby="faq-title">
            <h2 id="faq-title">10. Chesapeake cruising FAQ</h2>
            <h3>How long does a Chesapeake Bay cruise take?</h3>
            <p>There is no single duration. Choose an area, measure the navigable legs and apply the boat's realistic speed, stops and weather margin. A weekend can focus on one overnight destination; a week still requires choices.</p>
            <h3>Where should a first-time Chesapeake cruiser start?</h3>
            <p>Start with a manageable area near the departure base and a small number of researched stops. Favor a plan with clear approaches, practical alternatives and time to stay another night.</p>
            <h3>How much fuel should I plan to carry?</h3>
            <p>Calculate consumption from corrected distance and appropriate vessel performance, include relevant idle allowances, and preserve the selected reserve. Confirm usable fuel and refueling arrangements; a generic gallons-per-mile figure cannot represent every boat.</p>
            <h3>What if rough weather disrupts the itinerary?</h3>
            <p>Reconsider the exposed legs and the timing before departure. Delay, shorten the day or stay put when needed. Update the route, arrival expectation and shore contact rather than trying to recover a fixed sightseeing schedule.</p>
            <h3>What is a reasonable daily mileage?</h3>
            <p>Work backward from comfortable underway hours at a realistic speed, then allow for approaches and delays. Check that the endpoint is a suitable stop. FPW's daily hours are a planning input, not a universal cruising recommendation.</p>
            <h3>Does FPW generate a verified navigable Chesapeake route?</h3>
            <p>No. Build the waypoint sequence and review every leg. Geometry overrides describe your reviewed path and calculate its mileage; they do not certify depth, clearance or safe passage.</p>
            <h3>Does saving a route create and send my Float Plan?</h3>
            <p>No. Save and review the route, open its Float Plan workflow, check the trip details and use the appropriate separate sharing action. Confirm your shore contact has the current information.</p>
          </section>

          <section id="sources" tabindex="-1" aria-labelledby="sources-title">
            <h2 id="sources-title">Sources and planning references</h2>
            <p>Geographic and weather context was checked against the sources linked in this guide. Operational conditions can change. Return to current publications, charts, forecasts and local operators when preparing the actual trip.</p>
            <ul>
              <li><a target="_blank" rel="noopener" href="https://nauticalcharts.noaa.gov/publications/coast-pilot/index.html">NOAA United States Coast Pilot</a>: coastal geography, approaches and navigation context; the relevant chapter links appear beside the destination guidance.</li>
              <li><a target="_blank" rel="noopener" href="https://marinenavigation.noaa.gov/charts.html">NOAA nautical charts</a> and <a target="_blank" rel="noopener" href="https://www.nauticalcharts.noaa.gov/charts/chart-updates.html">chart updates</a>: current chart information for independent route verification.</li>
              <li><a target="_blank" rel="noopener" href="https://www.navcen.uscg.gov/msi">U.S. Coast Guard Maritime Safety Information</a>: current navigation notices and related safety information.</li>
              <li><a target="_blank" rel="noopener" href="https://www.weather.gov/lwx/marine">NWS Baltimore/Washington marine weather</a> and <a target="_blank" rel="noopener" href="https://www.weather.gov/marine/akqmz">NWS Wakefield marine zones</a>: official forecast coverage for the relevant waters.</li>
              <li><a target="_blank" rel="noopener" href="https://tidesandcurrents.noaa.gov/faq.html">NOAA tides and currents guidance</a> and <a target="_blank" rel="noopener" href="https://tidesandcurrents.noaa.gov/ofs/cbofs/cbofs.html">Chesapeake Bay model guidance</a>: prediction limitations and regional forecast products.</li>
            </ul>
            <p>For another detailed example of reviewing route geometry, daily timing and fuel, <a href="<cfoutput>#fpwChesapeakeBasePath#</cfoutput>/great-loop/trip-planning/">Explore the Great Loop Guide</a>.</p>
          </section>
        </div>
      </div>
    </article>
  </div>
</main>
<cfinclude template="../../includes/footer.cfm">
<script src="<cfoutput>#fpwChesapeakeBasePath#</cfoutput>/assets/js/fpw-action-cta.js?v=20261001-unified-auth"></script>
</body>
</html>
