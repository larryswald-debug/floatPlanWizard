<cfprocessingdirective pageencoding="utf-8">
<cfsetting showdebugoutput="false" requesttimeout="30">
<cfcontent type="text/html; charset=utf-8">

<cfscript>
schemaAtKey = chr(64);
schemaTypeKey = schemaAtKey & "type";
schemaIdKey = schemaAtKey & "id";
schemaContextKey = schemaAtKey & "context";
schemaGraphKey = schemaAtKey & "graph";

function fpwEmergencySchemaRef(required string idValue) {
  var out = structNew("ordered");
  structInsert(out, schemaIdKey, arguments.idValue, true);
  return out;
}

function fpwEmergencySchemaListItem(required numeric position, required string name, required string urlValue) {
  var out = structNew("ordered");
  var item = structNew("ordered");
  structInsert(out, schemaTypeKey, "ListItem", true);
  out["position"] = arguments.position;
  structInsert(item, schemaIdKey, arguments.urlValue, true);
  item["name"] = arguments.name;
  out["item"] = item;
  return out;
}

fpwEmergencyBasePath = "";
fpwEmergencyScriptName = structKeyExists(cgi, "script_name") ? trim(toString(cgi.script_name)) : "";

if (structKeyExists(request, "fpwBase")) {
  fpwEmergencyBasePath = trim(toString(request.fpwBase));
}

if (!len(fpwEmergencyBasePath) AND len(fpwEmergencyScriptName)) {
  fpwEmergencyBasePath = reReplace(fpwEmergencyScriptName, "/common-boating-emergencies\.cfm$", "");
  if (fpwEmergencyBasePath EQ fpwEmergencyScriptName) {
    fpwEmergencyBasePath = reReplace(getDirectoryFromPath(fpwEmergencyScriptName), "/$", "");
  }
}

fpwEmergencyBasePath = reReplace(fpwEmergencyBasePath, "/$", "");
if (fpwEmergencyBasePath EQ "/") {
  fpwEmergencyBasePath = "";
}
if (len(fpwEmergencyBasePath) AND left(fpwEmergencyBasePath, 1) NEQ "/") {
  fpwEmergencyBasePath = "/" & fpwEmergencyBasePath;
}

request.fpwBase = fpwEmergencyBasePath;
request.fpwTopNavActive = "resources-common-boating-emergencies";

fpwEmergencyCanonicalUrl = "https://floatplanwizard.com/common-boating-emergencies/";
fpwEmergencyPageTitle = "Common Boating Emergencies: What to Do | FloatPlanWizard";
fpwEmergencyPageDescription = "Learn what to do if your boat loses power, takes on water, runs aground, catches fire, encounters severe weather, or has a person overboard.";
fpwEmergencyHeadline = "When Something Goes Wrong on the Water: A Practical Guide to Common Boating Emergencies";
fpwEmergencySocialTitle = "When Something Goes Wrong on the Water";
fpwEmergencySocialDescription = "Practical first actions for engine failure, flooding, grounding, fire, person overboard, severe weather, and other common boating emergencies.";
fpwEmergencySocialImage = "https://floatplanwizard.com/assets/images/boating-guides/common-boating-emergencies/common-boating-emergencies-hero.jpg";
fpwEmergencyPublishedDate = "2026-08-23";
fpwEmergencyModifiedDate = "2026-08-23";
fpwEmergencyArticleId = fpwEmergencyCanonicalUrl & "##article";
fpwEmergencyWebPageId = fpwEmergencyCanonicalUrl & "##webpage";
fpwEmergencyOrganizationId = "https://floatplanwizard.com/##organization";
fpwEmergencySchemaGraph = [];
fpwEmergencySchemaOrg = structNew("ordered");
fpwEmergencySchemaBreadcrumb = structNew("ordered");
fpwEmergencySchemaPage = structNew("ordered");
fpwEmergencySchemaArticle = structNew("ordered");
fpwEmergencyJsonLd = structNew("ordered");

structInsert(fpwEmergencySchemaOrg, schemaTypeKey, "Organization", true);
structInsert(fpwEmergencySchemaOrg, schemaIdKey, fpwEmergencyOrganizationId, true);
fpwEmergencySchemaOrg["name"] = "FloatPlanWizard";
fpwEmergencySchemaOrg["url"] = "https://floatplanwizard.com/";
fpwEmergencySchemaOrg["logo"] = "https://floatplanwizard.com/assets/images/checkout/floatplanwizard-logo.jpg";
arrayAppend(fpwEmergencySchemaGraph, fpwEmergencySchemaOrg);

structInsert(fpwEmergencySchemaBreadcrumb, schemaTypeKey, "BreadcrumbList", true);
structInsert(fpwEmergencySchemaBreadcrumb, schemaIdKey, fpwEmergencyCanonicalUrl & "##breadcrumb", true);
fpwEmergencySchemaBreadcrumb["itemListElement"] = [];
arrayAppend(fpwEmergencySchemaBreadcrumb["itemListElement"], fpwEmergencySchemaListItem(1, "FloatPlanWizard", "https://floatplanwizard.com/"));
arrayAppend(fpwEmergencySchemaBreadcrumb["itemListElement"], fpwEmergencySchemaListItem(2, "Common Boating Emergencies", fpwEmergencyCanonicalUrl));
arrayAppend(fpwEmergencySchemaGraph, fpwEmergencySchemaBreadcrumb);

structInsert(fpwEmergencySchemaPage, schemaTypeKey, "WebPage", true);
structInsert(fpwEmergencySchemaPage, schemaIdKey, fpwEmergencyWebPageId, true);
fpwEmergencySchemaPage["url"] = fpwEmergencyCanonicalUrl;
fpwEmergencySchemaPage["name"] = fpwEmergencyPageTitle;
fpwEmergencySchemaPage["description"] = fpwEmergencyPageDescription;
fpwEmergencySchemaPage["isPartOf"] = fpwEmergencySchemaRef("https://floatplanwizard.com/##website");
fpwEmergencySchemaPage["publisher"] = fpwEmergencySchemaRef(fpwEmergencyOrganizationId);
fpwEmergencySchemaPage["breadcrumb"] = fpwEmergencySchemaRef(fpwEmergencyCanonicalUrl & "##breadcrumb");
fpwEmergencySchemaPage["mainEntity"] = fpwEmergencySchemaRef(fpwEmergencyArticleId);
arrayAppend(fpwEmergencySchemaGraph, fpwEmergencySchemaPage);

structInsert(fpwEmergencySchemaArticle, schemaTypeKey, "Article", true);
structInsert(fpwEmergencySchemaArticle, schemaIdKey, fpwEmergencyArticleId, true);
fpwEmergencySchemaArticle["url"] = fpwEmergencyCanonicalUrl;
fpwEmergencySchemaArticle["headline"] = fpwEmergencyHeadline;
fpwEmergencySchemaArticle["description"] = fpwEmergencyPageDescription;
fpwEmergencySchemaArticle["image"] = [ fpwEmergencySocialImage ];
fpwEmergencySchemaArticle["datePublished"] = fpwEmergencyPublishedDate;
fpwEmergencySchemaArticle["dateModified"] = fpwEmergencyModifiedDate;
fpwEmergencySchemaArticle["articleSection"] = "Boating Safety";
fpwEmergencySchemaArticle["inLanguage"] = "en";
fpwEmergencySchemaArticle["author"] = fpwEmergencySchemaRef(fpwEmergencyOrganizationId);
fpwEmergencySchemaArticle["publisher"] = fpwEmergencySchemaRef(fpwEmergencyOrganizationId);
fpwEmergencySchemaArticle["mainEntityOfPage"] = fpwEmergencySchemaRef(fpwEmergencyWebPageId);
arrayAppend(fpwEmergencySchemaGraph, fpwEmergencySchemaArticle);

structInsert(fpwEmergencyJsonLd, schemaContextKey, "https://schema.org", true);
structInsert(fpwEmergencyJsonLd, schemaGraphKey, fpwEmergencySchemaGraph, true);
fpwEmergencyJsonLdText = replace(serializeJSON(fpwEmergencyJsonLd), "</", "<\/", "all");

fpwEmergencyCtaUserId = 0;
if (structKeyExists(session, "user") AND isStruct(session.user)) {
  for (fpwEmergencyCtaUserIdKey in [ "userId", "id", "USERID", "ID" ]) {
    if (structKeyExists(session.user, fpwEmergencyCtaUserIdKey) AND isNumeric(session.user[fpwEmergencyCtaUserIdKey])) {
      fpwEmergencyCtaUserId = val(session.user[fpwEmergencyCtaUserIdKey]);
      break;
    }
  }
}
fpwEmergencyCtaSignedIn = fpwEmergencyCtaUserId GT 0;
</cfscript>

<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Common Boating Emergencies: What to Do | FloatPlanWizard</title>
  <meta name="description" content="Learn what to do if your boat loses power, takes on water, runs aground, catches fire, encounters severe weather, or has a person overboard.">
  <meta name="robots" content="index,follow,max-image-preview:large">
  <link rel="canonical" href="https://floatplanwizard.com/common-boating-emergencies/">
  <meta property="og:type" content="article">
  <meta property="og:site_name" content="FloatPlanWizard">
  <meta property="og:url" content="https://floatplanwizard.com/common-boating-emergencies/">
  <meta property="og:title" content="When Something Goes Wrong on the Water">
  <meta property="og:description" content="Practical first actions for engine failure, flooding, grounding, fire, person overboard, severe weather, and other common boating emergencies.">
  <meta property="og:image" content="https://floatplanwizard.com/assets/images/boating-guides/common-boating-emergencies/common-boating-emergencies-hero.jpg">
  <meta property="og:image:secure_url" content="https://floatplanwizard.com/assets/images/boating-guides/common-boating-emergencies/common-boating-emergencies-hero.jpg">
  <meta property="og:image:type" content="image/jpeg">
  <meta property="og:image:width" content="1672">
  <meta property="og:image:height" content="941">
  <meta property="og:image:alt" content="A boat operator checks the VHF radio while two passengers put on life jackets after the boat loses power.">
  <meta name="twitter:card" content="summary_large_image">
  <meta name="twitter:title" content="When Something Goes Wrong on the Water">
  <meta name="twitter:description" content="Practical first actions for engine failure, flooding, grounding, fire, person overboard, severe weather, and other common boating emergencies.">
  <meta name="twitter:image" content="https://floatplanwizard.com/assets/images/boating-guides/common-boating-emergencies/common-boating-emergencies-hero.jpg">
  <meta name="twitter:image:alt" content="A boat operator checks the VHF radio while two passengers put on life jackets after the boat loses power.">
  <script type="application/ld+json"><cfoutput>#fpwEmergencyJsonLdText#</cfoutput></script>
  <cfoutput><link rel="icon" type="image/svg+xml" href="#fpwEmergencyBasePath#/assets/images/landing/fpw-logo.svg"></cfoutput>
  <cfoutput><link rel="stylesheet" href="#fpwEmergencyBasePath#/assets/css/layout.css?v=20260620-page-width"></cfoutput>
  <cfoutput><link rel="stylesheet" href="#fpwEmergencyBasePath#/assets/css/top-nav.css?v=20260814-featured-guides-layout-v1"></cfoutput>
  <cfoutput><link rel="stylesheet" href="#fpwEmergencyBasePath#/assets/css/fpw-action-cta.css?v=20260804-pilot"></cfoutput>
<cfoutput><link rel="stylesheet" href="#fpwEmergencyBasePath#/assets/css/common-boating-emergencies.css?v=20260824-individual-card-pdfs"></cfoutput>
  <cfinclude template="includes/analytics_ga4.cfm">
  <cfinclude template="includes/analytics_clarity.cfm">
  <cfinclude template="includes/trustedsite.cfm">
</head>
<body class="fpw-emergency-body">
<a class="fpw-emergency-skip-link" href="#main-content">Skip to guide content</a>
<cfinclude template="includes/top_nav.cfm">

<main class="fpw-emergency-page" id="main-content">
  <div class="fpw-emergency-shell" id="guide-top">
    <nav class="fpw-emergency-breadcrumbs" aria-label="Breadcrumb">
      <a href="<cfoutput>#fpwEmergencyBasePath#</cfoutput>/">FloatPlanWizard</a>
      <span aria-hidden="true">&rsaquo;</span>
      <span aria-current="page">Common Boating Emergencies</span>
    </nav>

    <article class="fpw-emergency-article" aria-labelledby="fpw-emergency-title">
      <header class="fpw-emergency-hero">
        <p class="fpw-emergency-eyebrow">Boating Safety Guide</p>
        <h1 id="fpw-emergency-title">When Something Goes Wrong on the Water</h1>
        <p class="fpw-emergency-deck"><strong>A practical, step-by-step guide to common boating emergencies for everyday recreational boaters.</strong></p>
        <p>Most boating problems do not begin as dramatic emergencies. An engine stops. The bilge pump runs longer than usual. A passenger slips. The wind rises faster than expected. What happens next often depends on whether the operator recognizes the danger, protects the people aboard, controls what can be controlled, and asks for help before the situation becomes critical.</p>
        <p>This guide explains the first actions to take during common problems on recreational powerboats, pontoons, fishing boats, bowriders, deck boats, and small cruisers. Read it before you need it, review the sections that apply to your boat, and keep the printable quick-reference card where the operator and passengers can reach it.</p>
        <p class="fpw-emergency-reviewed">Reviewed <time datetime="2026-08-22">August 22, 2026</time></p>
        <div class="fpw-emergency-hero-actions">
          <a class="fpw-emergency-secondary-action" href="#first-60-seconds">Start with the first 60 seconds</a>
          <button class="fpw-emergency-print-button" type="button" data-fpw-guide-print data-placement="hero">Print this guide</button>
        </div>
      </header>

      <aside class="fpw-emergency-danger" aria-labelledby="immediate-danger-title">
        <p class="fpw-emergency-label">Immediate danger</p>
        <h2 id="immediate-danger-title">If anyone is in immediate danger</h2>
        <p>Put on life jackets, address the immediate threat, and call for help without delay. Use VHF Channel 16 and make a <strong>Mayday</strong> call when a person or vessel is threatened by grave and imminent danger and needs immediate assistance. If VHF is unavailable, call 911 and be ready to give your location, boat description, number of people aboard, and the nature of the emergency.</p>
      </aside>

      <p class="fpw-emergency-supplement">This guide supplements&mdash;not replaces&mdash;a boating-safety course, the Navigation Rules, local law, your boat and engine manuals, first-aid training, or instructions from emergency responders.</p>

      <aside class="fpw-emergency-evidence" aria-label="Why organized emergency response matters">
        <p>In 2024, the U.S. Coast Guard verified 3,887 recreational boating incidents involving 556 deaths and 2,170 injuries. Collisions, groundings, swamping, and falls overboard were among the most consequential events. Where the cause of death was known, 76 percent of fatal victims drowned; where life-jacket use was known, 87 percent of those drowning victims were not wearing one.</p>
        <p>The lesson is not that every outing is dangerous. It is that ordinary problems deserve an organized response&mdash;and that life jackets, a reliable position, early communication, and practiced emergency equipment matter.</p>
      </aside>

      <nav class="fpw-emergency-toc" aria-labelledby="fpw-emergency-toc-title">
        <div class="fpw-emergency-toc-heading">
          <p class="fpw-emergency-eyebrow">Quick navigation</p>
          <h2 id="fpw-emergency-toc-title">On this page</h2>
        </div>
        <ol>
          <li><a href="#first-60-seconds" data-fpw-guide-toc data-section-id="first-60-seconds">First 60 seconds</a></li>
          <li><a href="#choose-emergency-call" data-fpw-guide-toc data-section-id="choose-emergency-call">Mayday, Pan-Pan, or routine help</a></li>
          <li><a href="#mayday-call-script" data-fpw-guide-toc data-section-id="mayday-call-script">Mayday call script</a></li>
          <li><a href="#boat-engine-failure" data-fpw-guide-toc data-section-id="boat-engine-failure">Engine failure</a></li>
          <li><a href="#boat-control-failure" data-fpw-guide-toc data-section-id="boat-control-failure">Steering, throttle, or electrical failure</a></li>
          <li><a href="#boat-taking-on-water" data-fpw-guide-toc data-section-id="boat-taking-on-water">Taking on water</a></li>
          <li><a href="#boat-fire-fuel-leak" data-fpw-guide-toc data-section-id="boat-fire-fuel-leak">Fire, smoke, or fuel</a></li>
          <li><a href="#boat-ran-aground" data-fpw-guide-toc data-section-id="boat-ran-aground">Grounding or submerged strike</a></li>
          <li><a href="#boating-collision" data-fpw-guide-toc data-section-id="boating-collision">Collision</a></li>
          <li><a href="#person-overboard" data-fpw-guide-toc data-section-id="person-overboard">Person overboard</a></li>
          <li><a href="#boat-capsize" data-fpw-guide-toc data-section-id="boat-capsize">Capsize or abandonment</a></li>
          <li><a href="#boating-weather-visibility" data-fpw-guide-toc data-section-id="boating-weather-visibility">Weather and visibility</a></li>
          <li><a href="#medical-emergency-on-boat" data-fpw-guide-toc data-section-id="medical-emergency-on-boat">Serious illness or injury</a></li>
          <li><a href="#boat-carbon-monoxide" data-fpw-guide-toc data-section-id="boat-carbon-monoxide">Carbon monoxide</a></li>
          <li><a href="#disabled-boat-immediate-hazard" data-fpw-guide-toc data-section-id="disabled-boat-immediate-hazard">Disabled near immediate hazard</a></li>
          <li><a href="#overdue-boat" data-fpw-guide-toc data-section-id="overdue-boat">Changed plan or overdue boat</a></li>
          <li><a href="#boating-emergency-communications" data-fpw-guide-toc data-section-id="boating-emergency-communications">Communication devices</a></li>
          <li><a href="#passenger-safety-briefing" data-fpw-guide-toc data-section-id="passenger-safety-briefing">Passenger briefing</a></li>
          <li><a href="#boat-emergency-equipment" data-fpw-guide-toc data-section-id="boat-emergency-equipment">Equipment checklist</a></li>
          <li><a href="#boating-accident-reporting" data-fpw-guide-toc data-section-id="boating-accident-reporting">Reporting and recovery</a></li>
          <li><a href="#printable-boating-emergency-card" data-fpw-guide-toc data-section-id="printable-boating-emergency-card">Printable emergency card</a></li>
          <li><a href="#boating-emergency-faq" data-fpw-guide-toc data-section-id="boating-emergency-faq">Frequently asked questions</a></li>
          <li><a href="#sources" data-fpw-guide-toc data-section-id="sources">Sources and official resources</a></li>
        </ol>
      </nav>

      <div class="fpw-emergency-layout">
        <aside class="fpw-emergency-rail" aria-label="Guide section groups">
          <p class="fpw-emergency-eyebrow">Section groups</p>
          <a href="#first-60-seconds">First response</a>
          <a href="#boat-engine-failure">Boat problems</a>
          <a href="#person-overboard">People</a>
          <a href="#boating-weather-visibility">Conditions</a>
          <a href="#boating-emergency-communications">Communication &amp; preparation</a>
        </aside>

        <div class="fpw-emergency-content">
          <section id="first-60-seconds" aria-labelledby="first-60-seconds-title">
            <p class="fpw-emergency-section-kicker">First response</p>
            <h2 id="first-60-seconds-title">The first 60 seconds of a boating emergency</h2>
            <p>When something goes wrong, use <strong>P.A.C.E.: People, Assess, Control, Emergency call.</strong> P.A.C.E. is a FloatPlanWizard memory aid created for this guide; it is not an official Coast Guard acronym.</p>

            <p>Illustrative sequence; equipment and safe actions depend on the vessel and emergency.</p>

            <div class="fpw-emergency-pace-grid">
              <section aria-labelledby="pace-people-title">
                <p class="fpw-emergency-pace-letter" aria-hidden="true">P</p>
                <h3 id="pace-people-title">Protect and account for people</h3>
                <ul>
                  <li>Account for everyone aboard. If someone is missing, treat it as a person-overboard emergency immediately.</li>
                  <li>Have everyone put on a properly fitted life jacket. A life jacket stored under gear cannot help during a sudden fall, collision, or capsize.</li>
                  <li>Move passengers away from fuel, smoke, fire, machinery, spinning propellers, damaged electrical equipment, open hatches, and lines under load.</li>
                  <li>Assign short, specific jobs when capable people are available: &ldquo;Watch the person in the water,&rdquo; &ldquo;Get our position,&rdquo; &ldquo;Bring the life jackets,&rdquo; or &ldquo;Make the radio call.&rdquo;</li>
                </ul>
              </section>

              <section aria-labelledby="pace-assess-title">
                <p class="fpw-emergency-pace-letter" aria-hidden="true">A</p>
                <h3 id="pace-assess-title">Assess what can hurt you next</h3>
                <ol>
                  <li>Is anyone injured, missing, trapped, or in the water?</li>
                  <li>Is the boat burning, flooding, losing stability, or unable to maneuver?</li>
                  <li>Are you drifting toward rocks, surf, shoal water, a dam, a bridge, another boat, or a busy channel?</li>
                  <li>Is weather, darkness, current, or distance from help shrinking your safety margin?</li>
                </ol>
                <p>Do not let troubleshooting distract you from a growing external danger. A minor engine problem can become an emergency if the boat is drifting into an inlet, shipping channel, surf line, or lee shore.</p>
              </section>

              <section aria-labelledby="pace-control-title">
                <p class="fpw-emergency-pace-letter" aria-hidden="true">C</p>
                <h3 id="pace-control-title">Control what you safely can</h3>
                <p>The correct action depends on the problem. You may need to reduce speed, shift to neutral, shut down the engine, maintain just enough steerage to clear traffic, anchor, start bilge pumps, close a known seacock, or prepare a throwable flotation device. Do not perform a memorized action blindly.</p>
                <p>Record your position as early as possible. Use latitude and longitude from a GPS/chartplotter or identify a reliable landmark, navigation aid, channel marker, bridge, marina, or shoreline feature. Note the direction of drift and whether the situation is stable, improving, or worsening.</p>
              </section>

              <section aria-labelledby="pace-call-title">
                <p class="fpw-emergency-pace-letter" aria-hidden="true">E</p>
                <h3 id="pace-call-title">Make the emergency call early</h3>
                <p>Call before the boat loses electrical power, communications, buoyancy, daylight, or distance from danger. If crew is available, one person can communicate while another handles the immediate physical response.</p>
              </section>
            </div>

            <aside class="fpw-emergency-danger-inline" aria-label="Do not delay an emergency call">
              <p><strong>Do not wait to complete every P.A.C.E. step before calling.</strong> A person overboard, uncontrolled fire or flooding, serious injury, collision risk, or other immediate danger requires action and communication at the same time when possible.</p>
            </aside>
          </section>

          <div class="fpw-emergency-cta-wrap">
            <cfscript>
            fpwCtaConfig = {
              "id" = "common-boating-emergencies-after-pace-cta",
              "headline" = "Prepare the information someone ashore may need",
              "supportingText" = "Create and share a float plan with your route, people, boat, contacts, timing, and safety details.",
              "buttonLabel" = "Create a Float Plan",
              "destinationUrl" = fpwEmergencyCtaSignedIn ? fpwEmergencyBasePath & "/app/dashboard.cfm" : fpwEmergencyBasePath & "/app/join.cfm",
              "ctaType" = "create_float_plan",
              "sourcePage" = "boating_emergencies",
              "section" = "after_pace",
              "authState" = fpwEmergencyCtaSignedIn ? "signed_in" : "signed_out",
              "destinationKey" = fpwEmergencyCtaSignedIn ? "dashboard" : "join",
              "analyticsEvent" = "guide_cta_select",
              "ariaLabel" = "Create a Float Plan after reviewing the first-minute emergency framework"
            };
            </cfscript>
            <cfinclude template="partials/fpw-action-cta.cfm">
          </div>

          <section id="choose-emergency-call" aria-labelledby="choose-emergency-call-title">
            <p class="fpw-emergency-section-kicker">Communication</p>
            <h2 id="choose-emergency-call-title">What kind of help do you need?</h2>

            <h3>Mayday: grave and imminent danger</h3>
            <p>Use <strong>Mayday</strong> when a person or boat faces grave and imminent danger and needs immediate assistance. Examples can include:</p>
            <ul>
              <li>A person missing in the water</li>
              <li>Uncontrolled flooding or sinking</li>
              <li>A fire that is not immediately controlled</li>
              <li>A life-threatening injury or medical emergency</li>
              <li>A collision with serious injuries or major damage</li>
              <li>A disabled boat drifting into surf, rocks, a dam, heavy traffic, or another immediate hazard</li>
            </ul>
            <p>If you are unsure whether the danger is grave and imminent, describe the facts clearly to the Coast Guard or local authority. Do not minimize a deteriorating situation because you are embarrassed or hope to fix it yourself.</p>

            <h3>Pan-Pan: urgent but not yet grave and imminent</h3>
            <p>The urgency signal is pronounced <strong>&ldquo;pahn-pahn.&rdquo;</strong> It is used when the safety of a boat or person is in jeopardy but the situation has not reached Mayday-level distress. Examples could include a controllable leak, a serious mechanical problem in a hazardous area, or a disabled boat drifting toward a channel while there is still time to respond.</p>
            <p>Conditions change. Escalate to Mayday if the danger becomes grave and imminent.</p>

            <div class="fpw-emergency-script fpw-emergency-script--pan-pan" aria-label="Pan-Pan call template">
              <p><strong>PAN-PAN, PAN-PAN, PAN-PAN</strong><br>
              <strong>ALL STATIONS, ALL STATIONS, ALL STATIONS</strong> &mdash; or the specific Coast Guard station being called<br>
              <strong>THIS IS</strong> [boat name repeated three times, then registration/call sign]<br>
              <strong>MY POSITION IS</strong> [latitude/longitude or clear location]<br>
              <strong>WE HAVE</strong> [urgent problem]<br>
              <strong>WE NEED</strong> [assistance/advice]<br>
              <strong>THERE ARE</strong> [number] <strong>PEOPLE ABOARD</strong><br>
              [Drift, injuries, boat description, and other useful facts]<br>
              <strong>OVER</strong></p>
            </div>
            <p class="fpw-emergency-pan-pan-note">This is a practical plain-language template built around the FCC urgency signal and normal marine call content; local authorities may direct a different working channel or procedure. Keep the initial Channel 16 transmission brief and follow instructions.</p>

            <h3>Routine assistance</h3>
            <p>A stable boat with no injuries, no flooding or fire, safe weather, reliable communications, and no drift toward danger may need a commercial tow, fuel delivery, or mechanical help rather than an emergency response. Continue monitoring position, weather, battery power, and the condition of everyone aboard while assistance is coming.</p>

            <h3>VHF or cellphone?</h3>
            <p>Use a marine VHF radio as the primary on-water emergency tool when available. A VHF call can be heard by the Coast Guard and nearby boats, and a properly configured DSC radio can transmit a digital distress alert. A cellphone depends on shore-based coverage, reaches only the number called, and may not automatically give marine responders a useful position.</p>
            <p>If VHF is unavailable, call 911. State that you are on a boat, give your location early, and stay available for instructions. Use every reliable means available when life is at risk.</p>
          </section>

          <section id="mayday-call-script" aria-labelledby="mayday-call-script-title">
            <p class="fpw-emergency-section-kicker">VHF Channel 16</p>
            <h2 id="mayday-call-script-title">How to make a Mayday call on VHF Channel 16</h2>
            <p>The <a class="fpw-emergency-official" href="https://www.navcen.uscg.gov/radio-information-for-boaters" target="_blank" rel="noopener noreferrer" data-fpw-guide-source data-source-org="uscg" data-section-id="mayday-call-script">U.S. Coast Guard Navigation Center<span class="fpw-emergency-new-window"> (opens in a new tab)</span></a> recommends the following information. Speak slowly and clearly:</p>
            <figure class="fpw-emergency-figure">
              <picture>
                <img src="<cfoutput>#fpwEmergencyBasePath#</cfoutput>/assets/images/boating-guides/common-boating-emergencies/marine-vhf-mayday-prepared-card.jpg" srcset="<cfoutput>#fpwEmergencyBasePath#</cfoutput>/assets/images/boating-guides/common-boating-emergencies/marine-vhf-mayday-prepared-card-640w.jpg 640w, <cfoutput>#fpwEmergencyBasePath#</cfoutput>/assets/images/boating-guides/common-boating-emergencies/marine-vhf-mayday-prepared-card-960w.jpg 960w, <cfoutput>#fpwEmergencyBasePath#</cfoutput>/assets/images/boating-guides/common-boating-emergencies/marine-vhf-mayday-prepared-card.jpg 1448w" sizes="(max-width: 480px) calc(100vw - 56px), (max-width: 1100px) calc(100vw - 96px), 760px" width="1448" height="1086" alt="Two life-jacketed boaters at the helm in rough water while the operator sends a Mayday call on a fixed VHF radio with a prepared emergency card beside the controls." loading="lazy" decoding="async">
              </picture>
              <figcaption>Give position, danger, assistance needed, and people aboard. Keep the full Mayday script in HTML and on the printable card.</figcaption>
            </figure>
            <div class="fpw-emergency-script fpw-emergency-script--mayday" aria-label="Mayday call script">
              <p><strong>MAYDAY, MAYDAY, MAYDAY</strong><br>
              <strong>THIS IS</strong> [boat name repeated three times]<br>
              [Boat name and registration number or call sign]<br>
              <strong>MAYDAY</strong> [boat name]<br>
              <strong>MY POSITION IS</strong> [latitude/longitude or clear location]<br>
              <strong>WE ARE</strong> [nature of distress]<br>
              <strong>WE NEED</strong> [assistance required]<br>
              <strong>THERE ARE</strong> [number of adults and children] <strong>PEOPLE ABOARD</strong><br>
              [Injuries, boat type/length/color, drift, and other useful information]<br>
              <strong>OVER</strong></p>
            </div>
            <p>Stay near the radio when possible. Answer questions, follow instructions, and repeat the call at intervals if no one responds. Preserve battery power, but do not turn off the only radio responders are using to reach or locate you.</p>

            <h3>If the radio has DSC</h3>
            <p>A DSC distress button can send a formatted alert to equipped rescue stations and nearby DSC radios. For the alert to identify the boat and include its position, the radio must have a properly registered Maritime Mobile Service Identity (MMSI) and current GPS position data from an internal or connected receiver.</p>
            <p>Know your radio before an emergency:</p>
            <ul>
              <li>Register and program the MMSI correctly.</li>
              <li>Confirm that current position data appears on the radio.</li>
              <li>Teach another passenger how to lift the distress cover, press and hold the button as the radio requires, and make the follow-up voice call on Channel 16.</li>
              <li>Never press the distress button for a radio check.</li>
              <li>If activated accidentally, follow the radio manual and Coast Guard procedure to cancel the false alert immediately.</li>
            </ul>
          </section>

          <section id="boat-engine-failure" aria-labelledby="boat-engine-failure-title">
            <p class="fpw-emergency-section-kicker">Boat problems</p>
            <h2 id="boat-engine-failure-title">What to do if the boat engine dies or you lose propulsion</h2>
            <p>An engine failure may be an inconvenience in open, calm water and an immediate emergency near surf, rocks, a bridge, a dam, shoal water, or heavy traffic. Deal with the boat&rsquo;s movement before diagnosing the engine.</p>
            <figure class="fpw-emergency-figure">
              <picture>
                <img src="<cfoutput>#fpwEmergencyBasePath#</cfoutput>/assets/images/boating-guides/common-boating-emergencies/boat-engine-failure-drift-anchor.jpg" srcset="<cfoutput>#fpwEmergencyBasePath#</cfoutput>/assets/images/boating-guides/common-boating-emergencies/boat-engine-failure-drift-anchor-640w.jpg 640w, <cfoutput>#fpwEmergencyBasePath#</cfoutput>/assets/images/boating-guides/common-boating-emergencies/boat-engine-failure-drift-anchor-960w.jpg 960w, <cfoutput>#fpwEmergencyBasePath#</cfoutput>/assets/images/boating-guides/common-boating-emergencies/boat-engine-failure-drift-anchor.jpg 1672w" sizes="(max-width: 480px) calc(100vw - 56px), (max-width: 1100px) calc(100vw - 96px), 760px" width="1672" height="941" alt="Three life-jacketed boaters respond to an engine failure as one checks the engine compartment, one makes a radio call, and one lowers the anchor from the bow." loading="lazy" decoding="async">
              </picture>
              <figcaption>Assess depth, bottom, traffic, wind, current, and sea room before anchoring or troubleshooting.</figcaption>
            </figure>

            <h3 class="fpw-emergency-action-heading">Do this first</h3>
            <ol>
              <li>Maintain a lookout and determine what the boat is drifting toward.</li>
              <li>Put life jackets on everyone.</li>
              <li>Record the position and observe drift direction.</li>
              <li>If anchoring is appropriate, deploy the anchor from the bow before the boat reaches danger. Confirm adequate depth, scope, bottom conditions, swinging room, current, and traffic. Do not anchor in a channel unless it is necessary for immediate safety, and warn approaching traffic.</li>
              <li>If anchoring is unsafe or impossible, make the appropriate urgency or distress call early and take the safest available action to avoid collision or grounding.</li>
            </ol>

            <h3>Then check the simple causes</h3>
            <p>Only after the boat is stable enough to troubleshoot, check items the operator can verify without opening fuel systems or exposing anyone to machinery:</p>
            <ul>
              <li>Is the throttle/shift control fully in neutral?</li>
              <li>Is the engine cut-off switch clip or wireless fob correctly engaged?</li>
              <li>Are battery switches in the intended position?</li>
              <li>Do instruments and electronics have power?</li>
              <li>Are battery terminals visibly loose or badly corroded? Do not work on electrical connections if fuel vapor is present.</li>
              <li>Is there fuel according to more than an unreliable gauge, and is the correct tank selected?</li>
              <li>Is a portable fuel-tank vent open where the design requires it?</li>
              <li>Is a fuel line visibly kinked or a primer bulb collapsed?</li>
              <li>Has a breaker tripped or a clearly labeled engine fuse failed?</li>
              <li>Is the propeller fouled or damaged? Inspect only with the engine shut down, the key removed or start controls disabled, and nobody able to start it. Do not enter the water to clear a propeller as a routine response.</li>
              <li>Did an alarm, overheating indication, low oil-pressure warning, or reduced-power mode occur? Follow the engine manual; do not repeatedly restart an engine that may be overheating, starved of lubrication, or mechanically damaged.</li>
            </ul>
            <p>Stop if the cause is not obvious and safely correctable. Repeated cranking can drain the starting battery and eliminate radio, pump, navigation-light, and electronics capacity.</p>

            <h3 class="fpw-emergency-stop-heading">Do not do this</h3>
            <ul>
              <li>Do not focus on the engine while the boat drifts into danger.</li>
              <li>Do not anchor from the stern; waves or wake over a low transom can swamp a small boat.</li>
              <li>Do not bypass safety switches, create sparks, open fuel fittings, or improvise wiring repairs around gasoline vapor.</li>
              <li>Do not assume a cellphone call means nearby boats know you need help.</li>
              <li>Do not accept an unsafe towline arrangement from an unprepared helper.</li>
            </ul>

            <h3 class="fpw-emergency-call-heading">Call for help now if&hellip;</h3>
            <ul>
              <li>The boat is drifting toward traffic, rocks, surf, a dam, bridge, shoal, or lee shore.</li>
              <li>Weather or visibility is deteriorating.</li>
              <li>Anchoring is not possible or the anchor is dragging.</li>
              <li>Anyone is injured, ill, in the water, or unable to remain safe aboard.</li>
              <li>The boat is also taking on water, losing electrical power, or becoming unstable.</li>
              <li>You cannot give a reliable position or expect communications to fail.</li>
            </ul>

            <h3 class="fpw-emergency-safe-heading">After you are safe</h3>
            <p>Cancel or update any assistance request if the engine restarts. Return at conservative speed, monitor alarms and gauges, and have the cause inspected before relying on the boat again.</p>
            <p class="fpw-emergency-related-inline">For pre-departure planning, <a href="<cfoutput>#fpwEmergencyBasePath#</cfoutput>/boat-fuel-calculator/">calculate a safer fuel reserve</a>.</p>
          </section>

          <section id="boat-control-failure" aria-labelledby="boat-control-failure-title">
            <p class="fpw-emergency-section-kicker">Boat problems</p>
            <h2 id="boat-control-failure-title">What to do if steering, throttle, or electrical controls fail</h2>
            <p>Loss of steering or throttle can remove control faster than an engine shutdown. The first priority is preventing a collision&mdash;not preserving the trip.</p>

            <h3 class="fpw-emergency-action-heading">Do this first</h3>
            <ul>
              <li>Reduce power carefully if throttle control remains available.</li>
              <li>Shift to neutral or shut down propulsion when that is the safest way to prevent injury or collision.</li>
              <li>Warn passengers, account for everyone, and put on life jackets.</li>
              <li>Sound the horn and make a safety or urgency call if other traffic may not understand your movement.</li>
              <li>Use a second engine, auxiliary steering, emergency tiller, or other manufacturer-provided system only if the operator knows how it works and can deploy it safely.</li>
              <li>Anchor when appropriate and before the boat reaches danger.</li>
            </ul>
            <p>Electrical failure may also disable navigation lights, pumps, radios, engine controls, trim systems, and electronic steering. Preserve any remaining battery-powered communications. A charged handheld VHF, waterproof flashlight, manual pump, paper chart, and compass can keep one failure from becoming several.</p>

            <h3>Limited safe checks</h3>
            <ul>
              <li>Confirm battery-switch position and visible voltage indications.</li>
              <li>Check clearly labeled main breakers and fuses once; a breaker that trips again is evidence of a fault, not an invitation to keep resetting it.</li>
              <li>Look and smell for overheating wiring, smoke, melting insulation, or fuel vapor.</li>
              <li>Check accessible steering-linkage or hydraulic-fluid indications only as described in the boat manual.</li>
            </ul>

            <h3 class="fpw-emergency-stop-heading">Do not do this</h3>
            <ul>
              <li>Do not reach into moving steering, belt, pulley, or linkage components.</li>
              <li>Do not repeatedly reset a breaker or replace a fuse with a higher rating.</li>
              <li>Do not make improvised electrical connections around gasoline fumes.</li>
              <li>Do not continue at speed with intermittent steering or throttle response.</li>
            </ul>

            <h3 class="fpw-emergency-call-heading">Call for help now if&hellip;</h3>
            <p>You cannot reliably control course or speed, the boat is in traffic or confined water, weather is worsening, navigation lights are unavailable near darkness, pumps or communications are affected, or a burning smell/smoke suggests an electrical fire.</p>
          </section>

          <section id="boat-taking-on-water" aria-labelledby="boat-taking-on-water-title">
            <p class="fpw-emergency-section-kicker">Boat problems</p>
            <h2 id="boat-taking-on-water-title">What to do if the boat is taking on water</h2>
            <p>Treat unexplained water entry seriously. Bilge pumps buy time; they do not make an uncontrolled leak safe. The rate matters: compare whether the water level is rising, steady, or falling while pumps run.</p>
            <figure class="fpw-emergency-figure">
              <picture>
                <img src="<cfoutput>#fpwEmergencyBasePath#</cfoutput>/assets/images/boating-guides/common-boating-emergencies/boat-taking-on-water-checkpoints.jpg" srcset="<cfoutput>#fpwEmergencyBasePath#</cfoutput>/assets/images/boating-guides/common-boating-emergencies/boat-taking-on-water-checkpoints-640w.jpg 640w, <cfoutput>#fpwEmergencyBasePath#</cfoutput>/assets/images/boating-guides/common-boating-emergencies/boat-taking-on-water-checkpoints-960w.jpg 960w, <cfoutput>#fpwEmergencyBasePath#</cfoutput>/assets/images/boating-guides/common-boating-emergencies/boat-taking-on-water-checkpoints.jpg 1536w" sizes="(max-width: 480px) calc(100vw - 56px), (max-width: 1100px) calc(100vw - 96px), 760px" width="1536" height="1024" alt="A cutaway view highlights several common places water can enter a recreational boat, including fittings, hoses, drains, and hull damage." loading="lazy" decoding="async">
              </picture>
              <figcaption>Boat layouts differ. Check only accessible areas you understand, and never delay a distress call while water is rising.</figcaption>
            </figure>

            <h3 class="fpw-emergency-action-heading">Do this first</h3>
            <ol>
              <li>Put life jackets on everyone and make sure children and non-swimmers remain supervised.</li>
              <li>Start all installed bilge pumps and use manual pumps or buckets if they can be used without delaying the distress call.</li>
              <li>Give the position and make a Mayday call if water is rising rapidly, the source cannot be controlled, electrical power or stability is threatened, or sinking is possible.</li>
              <li>Assign one person to monitor the water level and another to communicate if crew is available.</li>
              <li>Keep people out of the bilge and away from batteries, exposed wiring, hot machinery, and contaminated water.</li>
            </ol>

            <h3>Look for a cause only when it is safe</h3>
            <p>Common sources include:</p>
            <ul>
              <li>A missing or leaking drain plug</li>
              <li>A failed hose, clamp, through-hull fitting, seacock, transducer, livewell, washdown, or raw-water connection</li>
              <li>A damaged outdrive bellows, shaft seal, rudder port, or other underwater fitting</li>
              <li>A cooling or exhaust-system hose that leaks while the engine is running</li>
              <li>Hull damage after striking an object or running aground</li>
              <li>Water coming over a low transom because of waves, wake, overloading, or too much weight aft</li>
              <li>Rain, spray, or deck drains/scuppers that cannot clear water fast enough</li>
            </ul>
            <p>If the operator can identify a known seacock feeding a failed hose, close it. Use a properly sized soft wooden plug or other purpose-made damage-control material on an accessible opening. A towel, cushion, or other soft material pressed against a damaged area may slow water temporarily, but do not depend on an improvised patch or put someone in a position where they can be trapped.</p>
            <p>If water entry changes with the engine running, shut the engine down if doing so is safe and observe the result. A cooling or exhaust failure can pump substantial water into the boat. Balance that action against the need for steerage; tell responders exactly what is happening.</p>

            <h3>Reduce the flooding risk</h3>
            <ul>
              <li>Keep the bow oriented to waves when safe and controllable; avoid allowing following seas to board over a low transom.</li>
              <li>Move people and portable weight away from the flooded or low side without creating instability elsewhere.</li>
              <li>Do not open large compartments unnecessarily in rough water.</li>
              <li>Prepare visual distress signals and a registered beacon if carried.</li>
              <li>Bring essential communications and flotation together in case the boat must be abandoned, but remain aboard unless staying creates greater danger.</li>
            </ul>

            <h3 class="fpw-emergency-stop-heading">Do not do this</h3>
            <ul>
              <li>Do not wait for the bilge pump to &ldquo;catch up&rdquo; while the water level continues to rise.</li>
              <li>Do not send someone overboard or under the boat to find a leak.</li>
              <li>Do not work near a running engine, propeller shaft, belts, batteries, or submerged electrical equipment.</li>
              <li>Do not intentionally beach the boat without considering people on the beach, surf, rocks, hull design, pollution, and responder instructions. In a life-threatening situation, follow the safest available option and tell responders what you intend to do.</li>
            </ul>

            <h3 class="fpw-emergency-call-heading">Call for help now if&hellip;</h3>
            <ul>
              <li>Water is rising with all pumps operating.</li>
              <li>The source cannot be found or reached safely.</li>
              <li>The boat has struck something or grounded hard.</li>
              <li>Batteries, engines, pumps, or steering are being submerged.</li>
              <li>The boat is listing, settling lower, or becoming difficult to control.</li>
              <li>Fire, fuel, sewage, or electrical hazards are present.</li>
            </ul>

            <h3 class="fpw-emergency-safe-heading">After you are safe</h3>
            <p>Do not place the boat back in service merely because the water was pumped out. Find and repair the cause, inspect affected electrical and mechanical systems, and report the incident when required.</p>
          </section>

          <section id="boat-fire-fuel-leak" aria-labelledby="boat-fire-fuel-leak-title">
            <p class="fpw-emergency-section-kicker">Boat problems</p>
            <h2 id="boat-fire-fuel-leak-title">What to do if you see smoke, smell gasoline, discover a fuel leak, or have a fire</h2>
            <p>Fuel vapor, smoke, and fire demand different reactions, but all can become life-threatening quickly on a boat. Warn everyone immediately and call early if the source is not identified and controlled.</p>
            <figure class="fpw-emergency-figure">
              <picture>
                <img src="<cfoutput>#fpwEmergencyBasePath#</cfoutput>/assets/images/boating-guides/common-boating-emergencies/boat-engine-compartment-fire-response.jpg?v=20260823-owner-approved-v2" srcset="<cfoutput>#fpwEmergencyBasePath#</cfoutput>/assets/images/boating-guides/common-boating-emergencies/boat-engine-compartment-fire-response-640w.jpg?v=20260823-owner-approved-v2 640w, <cfoutput>#fpwEmergencyBasePath#</cfoutput>/assets/images/boating-guides/common-boating-emergencies/boat-engine-compartment-fire-response-960w.jpg?v=20260823-owner-approved-v2 960w, <cfoutput>#fpwEmergencyBasePath#</cfoutput>/assets/images/boating-guides/common-boating-emergencies/boat-engine-compartment-fire-response.jpg?v=20260823-owner-approved-v2 1672w" sizes="(max-width: 480px) calc(100vw - 56px), (max-width: 1100px) calc(100vw - 96px), 760px" width="1672" height="941" alt="Thirty-five-foot cabin cruiser docked at a fuel station with smoke and flames coming from the rear engine compartment and spilled fuel burning on the water near the stern." loading="lazy" decoding="async">
              </picture>
              <figcaption>Fire at a fuel dock can spread rapidly from the engine compartment to spilled fuel on the water. Stop fueling, alert everyone nearby, evacuate to a safe location and call emergency services&mdash;do not remain aboard to fight a spreading fuel fire.</figcaption>
            </figure>

            <section class="fpw-emergency-fuel-dock" id="fuel-dock-fires" aria-labelledby="fuel-dock-fires-heading">
              <h3 id="fuel-dock-fires-heading">Fuel-Dock Fires and Burning Fuel on the Water</h3>
              <p>Fueling may feel routine, but a fuel dock combines gasoline, vapors, electrical equipment, boats and people in a confined area. Even a small spill can spread across the water and underneath nearby boats or docks.</p>
              <p>The water itself does not burn. A layer of fuel floating on the surface—and the vapor above it—can ignite and carry fire rapidly across the fueling area.</p>

              <aside class="fpw-emergency-fuel-dock-experience">
                <h4>A lesson I never forgot</h4>
                <p>When I was about 10 years old, I was aboard my father’s 14-foot runabout while we stopped for fuel. A larger boat was fueling beside us. Although nothing appeared to be leaking at that moment, some fuel was already floating on the water.</p>
                <p>A man aboard the other boat was smoking a cigar. He threw it into the water, apparently intending to put it out, and the fuel on the surface ignited almost instantly.</p>
                <p>Everything happened very fast. My mother panicked and jumped into the water. Someone grabbed me and ran with me as quickly as possible to get away from the fire. Thankfully, my mother was unharmed and the fire was extinguished, but the situation could easily have ended very differently.</p>
                <p>That experience stayed with me because every part of it was preventable. Smoking should never have been permitted near the fuel dock, spilled fuel should not have been present, and no passenger—especially a child—should have remained aboard during fueling.</p>
              </aside>

              <div class="fpw-emergency-fuel-dock-panels">
                <section class="fpw-emergency-fuel-dock-panel fpw-emergency-fuel-dock-panel--before">
                  <h4>Before fueling</h4>
                  <ul>
                    <li>Put all passengers ashore before fueling begins.</li>
                    <li>Secure the boat firmly to the dock.</li>
                    <li>Shut down engines, generators and other potential ignition sources.</li>
                    <li>Extinguish cigarettes, cigars and every open flame. If anyone begins smoking nearby, stop fueling immediately and alert the dock attendant.</li>
                    <li>Close ports, hatches and doors to keep gasoline vapors out of enclosed spaces.</li>
                    <li>Keep the fuel nozzle in contact with the fill opening and attend it continuously.</li>
                    <li>Fill slowly and never top off the tank.</li>
                    <li>Watch the fuel vent, deck and surrounding water for spills or a visible sheen.</li>
                  </ul>
                  <p>After fueling, open the compartments, ventilate the boat and operate the blower for at least four minutes before starting a gasoline engine. Check carefully for fuel odors. Reboard passengers only after the engine has been started safely. These precautions follow <a class="fpw-emergency-official" href="https://boatus.org/study-guide/trip-planning-preparation/boat-transportation-trailering/" target="_blank" rel="noopener noreferrer" data-fpw-guide-source data-source-org="boatus" data-section-id="fuel-dock-fires">BoatUS Foundation fueling guidance<span class="fpw-emergency-new-window"> (opens in a new tab)</span></a>.</p>
                </section>

                <section class="fpw-emergency-fuel-dock-panel fpw-emergency-fuel-dock-panel--spill">
                  <h4>If fuel spills but has not ignited</h4>
                  <ol>
                    <li>Stop the flow of fuel and notify the marina attendant immediately.</li>
                    <li>Do not start the engine or operate electrical switches in the affected area.</li>
                    <li>Keep people away from the spill and eliminate every possible ignition source.</li>
                    <li>Allow marina personnel to deploy oil-absorbent pads or containment booms.</li>
                    <li>Never use soap or detergent to make a sheen disappear. It spreads the contamination through the water and is illegal.</li>
                    <li>Report a spill that creates a sheen to the U.S. Coast Guard National Response Center at <strong>1-800-424-8802</strong>, along with any required state or local notification.</li>
                  </ol>
                  <p class="fpw-emergency-fuel-dock-source"><a class="fpw-emergency-official" href="https://www.boatus.org/clean-boating/fueling/fuel-spill-response" target="_blank" rel="noopener noreferrer" data-fpw-guide-source data-source-org="boatus" data-section-id="fuel-dock-fires">BoatUS Foundation spill-response guidance<span class="fpw-emergency-new-window"> (opens in a new tab)</span></a></p>
                </section>

                <section class="fpw-emergency-fuel-dock-panel fpw-emergency-fuel-dock-panel--fire">
                  <h4>If the fuel ignites</h4>
                  <ul>
                    <li>Shout a warning and get everyone away from the fuel dock immediately.</li>
                    <li>Call 911 from a safe location and clearly report that fuel is burning on the water.</li>
                    <li>Activate the fuel-dock emergency shutoff only if it can be reached without approaching the flames or passing through smoke.</li>
                    <li>Use the dock as the primary escape route when it remains safe. Do not automatically jump into the water—burning fuel can spread across the surface, and marina water may also present electrical hazards.</li>
                    <li>Do not start or move a burning boat unless emergency personnel direct you to do so.</li>
                    <li>Attempt to use a properly rated fire extinguisher only when the fire is still small, you know how to use it and you have a clear escape route behind you.</li>
                    <li>Never throw water onto burning gasoline. Leave a spreading fuel or marina fire to trained responders.</li>
                  </ul>
                  <p>Boat and marina fires can spread quickly, so evacuation takes priority over saving the boat or fighting a growing fire. <a class="fpw-emergency-official" href="https://www.usfa.fema.gov/prevention/vehicle-fires/boats-and-marinas/" target="_blank" rel="noopener noreferrer" data-fpw-guide-source data-source-org="usfa" data-section-id="fuel-dock-fires">U.S. Fire Administration marina-fire guidance<span class="fpw-emergency-new-window"> (opens in a new tab)</span></a>.</p>
                </section>
              </div>

              <aside class="fpw-emergency-fuel-dock-reminder" role="note">
                <p><strong>Remember:</strong> A fuel sheen is not harmless, and a fuel dock is never an acceptable place to smoke. If you see either condition, stop fueling and notify the marina before an ignition turns a manageable spill into a life-threatening emergency.</p>
              </aside>
            </section>

            <h3>If you smell gasoline or discover a fuel leak</h3>
            <ul>
              <li>Do not start or restart an engine.</li>
              <li>Do not operate electrical switches, blowers, lights, pumps, trim, or other equipment that could create a spark unless an emergency action is necessary to protect life.</li>
              <li>Extinguish cigarettes and all flames. Do not use a flame to search for a leak.</li>
              <li>Move passengers off the boat when safely alongside a dock. If underway, put life jackets on everyone and keep people in the safest ventilated location available.</li>
              <li>Shut off fuel at a known, safely reachable valve if you can do so without entering a vapor-filled compartment.</li>
              <li>Ventilate naturally. Follow the boat manufacturer&rsquo;s procedure before operating a powered blower; a blower is preventive ventilation, not permission to energize equipment in a space already filled with fuel vapor.</li>
              <li>Request fire department, marina, towing, or Coast Guard assistance appropriate to your location and level of danger.</li>
            </ul>
            <p>Do not restart until the source has been found, repaired, spilled fuel removed, and the boat confirmed safe by a qualified person.</p>

            <h3>If there is smoke or fire</h3>
            <ol>
              <li>Put life jackets on everyone, make the appropriate distress call, and give your position.</li>
              <li>Stop the engine and generator and close fuel shutoffs when safely reachable and appropriate.</li>
              <li>Turn the boat, if it remains controllable, so smoke and flames move away from people and the safest evacuation area.</li>
              <li>Use the correct, accessible marine extinguisher while the fire is still small and an escape path remains behind you.</li>
              <li>Aim at the base of an exposed fire and sweep the extinguishing agent as instructed on the extinguisher.</li>
              <li>Watch for re-ignition. A fire that appears extinguished can restart.</li>
            </ol>

            <h3>Engine-compartment fire</h3>
            <p>Do <strong>not</strong> throw open an engine hatch to look at a suspected fire. Opening the compartment can admit oxygen and expose the operator to flame and toxic smoke. Shut down engines, generators, blowers, and fuel supply as the installed system requires. Discharge a fixed suppression system or the correct extinguisher through a designated fire port when the boat is equipped and the operator knows the procedure.</p>
            <p>Follow the installed system and boat manuals. Some suppression systems require immediate engine/blower shutdown so ventilation does not remove the extinguishing agent.</p>

            <h3 class="fpw-emergency-stop-heading">Do not do this</h3>
            <ul>
              <li>Do not let the fire get between people and their only exit.</li>
              <li>Do not open an engine compartment containing a suspected fire.</li>
              <li>Do not continue fighting a growing fire after heat, smoke, fuel, or explosion risk makes escape unsafe.</li>
              <li>Do not restart an engine or restore electrical power after a fire until the system has been professionally inspected.</li>
              <li>Do not discharge an extinguisher merely to investigate smoke; locate the safest way to identify the problem and preserve an escape route.</li>
            </ul>

            <h3 class="fpw-emergency-call-heading">Call for help now if&hellip;</h3>
            <p>There is open flame, dense or increasing smoke, gasoline vapor, an unknown burning odor, loss of power associated with smoke, a fire in a concealed compartment, an injured person, or any doubt that the fire is completely controlled.</p>

            <h3>If abandoning becomes necessary</h3>
            <p>Transmit the position and number of people, activate a registered beacon if carried, take flotation and communications that are immediately reachable, and keep everyone together. Move away from flames and fuel on the water. Do not abandon a floating boat merely because it is damaged; leave only when remaining aboard is more dangerous.</p>
          </section>

          <section id="boat-ran-aground" aria-labelledby="boat-ran-aground-title">
            <p class="fpw-emergency-section-kicker">Boat problems</p>
            <h2 id="boat-ran-aground-title">What to do if the boat runs aground or strikes a submerged object</h2>
            <p>The safest response depends on how hard the boat struck, whether the bottom is mud, sand, grass, coral, rock, or debris, whether the tide is rising or falling, and whether the hull or propulsion system is damaged.</p>
            <figure class="fpw-emergency-figure">
              <picture>
                <img src="<cfoutput>#fpwEmergencyBasePath#</cfoutput>/assets/images/boating-guides/common-boating-emergencies/boat-grounding-stop-assess.jpg" srcset="<cfoutput>#fpwEmergencyBasePath#</cfoutput>/assets/images/boating-guides/common-boating-emergencies/boat-grounding-stop-assess-640w.jpg 640w, <cfoutput>#fpwEmergencyBasePath#</cfoutput>/assets/images/boating-guides/common-boating-emergencies/boat-grounding-stop-assess-960w.jpg 960w, <cfoutput>#fpwEmergencyBasePath#</cfoutput>/assets/images/boating-guides/common-boating-emergencies/boat-grounding-stop-assess.jpg 1672w" sizes="(max-width: 480px) calc(100vw - 56px), (max-width: 1100px) calc(100vw - 96px), 760px" width="1672" height="941" alt="Two life-jacketed boaters assess a cabin cruiser grounded in shallow water as one checks depth beside the bow and the other remains at the helm." loading="lazy" decoding="async">
              </picture>
              <figcaption>Stop and assess before trying to power free; immediate throttle can worsen damage or clog cooling-water intakes.</figcaption>
            </figure>

            <h3 class="fpw-emergency-action-heading">Do this first</h3>
            <ol>
              <li>Reduce power and stop the engine when safe. Do not immediately throttle into reverse.</li>
              <li>Check every person for injury and account for everyone.</li>
              <li>Put on life jackets.</li>
              <li>Check the bilge, compartments, hull, shaft/outdrive area, and other accessible spaces for water entry or damage.</li>
              <li>Record the position. Check charted bottom, tide/current, wind, wake, and nearby traffic.</li>
              <li>If waves, wake, wind, or falling tide could push the boat farther aground or roll it, set an anchor toward safe water when that can be done without entering the water or causing another hazard.</li>
            </ol>

            <h3>Decide whether to stay put</h3>
            <p>Remain aground and call for professional help when:</p>
            <ul>
              <li>The boat struck hard, hit rock, coral, piling, or debris.</li>
              <li>The hull, propeller, shaft, rudder, outdrive, jet intake, or steering may be damaged.</li>
              <li>The boat is leaking, listing, or unstable.</li>
              <li>Backing off would place a damaged hull into deeper water.</li>
              <li>The tide is falling or weather/wake is worsening.</li>
              <li>Environmental damage could result.</li>
              <li>The route back to deeper water is uncertain.</li>
            </ul>
            <p>A hard grounding may be treated as salvage rather than a routine tow. Discuss the service and terms with a professional responder when time and safety allow.</p>

            <h3>If it appears to be a light, soft grounding</h3>
            <p>Only after confirming no injuries, leak, obvious damage, or environmental restriction, determine water depth around the boat with a boat hook, pole, sounder, or other safe method. Reduce movable weight without throwing equipment overboard or moving everyone to one side so abruptly that the boat becomes unstable.</p>
            <p>Waiting for a rising tide or professional ungrounding may cause less damage than using power. If a cautious attempt is appropriate, use the known approach path and minimum power. Monitor engine temperature because sand or mud can clog cooling-water intakes. Stop immediately if temperature rises, vibration begins, water enters, or the boat does not move easily.</p>

            <h3 class="fpw-emergency-stop-heading">Do not do this</h3>
            <ul>
              <li>Do not gun the engine in reverse before assessing damage and bottom type.</li>
              <li>Do not send a passenger into current, deep water, sharp bottom, contaminated water, or near a propeller to push.</li>
              <li>Do not let another recreational boat perform a high-load &ldquo;yank&rdquo; using unsuitable lines, attachment points, or people standing in the recoil zone.</li>
              <li>Do not damage seagrass, coral, or other protected habitat trying to power free.</li>
              <li>Do not reenter deep water with a hull that may be compromised.</li>
            </ul>

            <h3 class="fpw-emergency-call-heading">Call for help now if&hellip;</h3>
            <p>Anyone is injured; the boat is leaking, unstable, or exposed to waves; there is fuel or pollution; the grounding is in a channel or hazardous location; darkness or weather is approaching; or the propulsion/steering system may be damaged.</p>

            <h3 class="fpw-emergency-safe-heading">After you are safe</h3>
            <p>Inspect the hull, propeller, outdrive, shaft, rudder, cooling system, steering, and bilge before continuing. At low speed, monitor vibration, steering, temperature, and water entry. Arrange a haul-out or professional inspection after any significant strike.</p>
          </section>

          <section id="boating-collision" aria-labelledby="boating-collision-title">
            <p class="fpw-emergency-section-kicker">Boat problems</p>
            <h2 id="boating-collision-title">What to do after a collision</h2>
            <p>After a collision with another boat, dock, marker, bridge, or fixed object, people come before property and blame. A boat that still floats may have hidden damage below the waterline.</p>

            <h3 class="fpw-emergency-action-heading">Do this first</h3>
            <ol>
              <li>Stop or reduce propulsion as needed to prevent another impact. Do not place anyone between boats or between a boat and fixed structure.</li>
              <li>Account for everyone on your boat and ask whether anyone on the other boat is missing or injured.</li>
              <li>Put on life jackets and provide reasonable assistance without putting your own passengers in additional danger.</li>
              <li>Check both boats for flooding, fire, fuel leakage, electrical hazards, instability, and propulsion damage.</li>
              <li>Call Mayday for serious injuries, missing people, fire, uncontrolled flooding, sinking, or immediate navigational danger.</li>
              <li>Warn traffic if either boat is disabled in a channel or other dangerous location.</li>
            </ol>

            <h3>Preserve the situation safely</h3>
            <ul>
              <li>Record time, position, weather, visibility, and water conditions.</li>
              <li>Exchange operator, owner, vessel, registration, and insurance information as applicable.</li>
              <li>Photograph damage and the wider scene only after immediate safety needs are handled.</li>
              <li>Record witness names and contact information.</li>
              <li>Do not admit fault, argue, threaten, or leave without fulfilling assistance and reporting duties.</li>
              <li>Follow instructions from law enforcement, the Coast Guard, harbor patrol, or other authority.</li>
            </ul>

            <h3 class="fpw-emergency-stop-heading">Do not do this</h3>
            <ul>
              <li>Do not separate boats that are keeping a damaged hull afloat without assessing what will happen.</li>
              <li>Do not restart engines until lines, people, debris, and possible fuel leaks are clear.</li>
              <li>Do not continue the trip simply because the boat appears drivable.</li>
              <li>Do not assume federal reporting thresholds are the only applicable rules; states may require reporting at lower damage amounts or impose additional duties.</li>
            </ul>

            <h3 class="fpw-emergency-call-heading">Call for help now if&hellip;</h3>
            <p>Anyone is injured or missing; either vessel is leaking, burning, disabled, or unstable; fuel is in the water; navigation is obstructed; conditions are deteriorating; or the parties cannot safely separate.</p>

            <h3 class="fpw-emergency-safe-heading">After you are safe</h3>
            <p>Federal rules generally require a written report when a person dies, disappears under circumstances indicating death or injury, receives medical treatment beyond first aid, the vessel is completely lost, or vessel/other-property damage totals at least $2,000. Required reports involving death within 24 hours, injury beyond first aid, or disappearance generally must be made within 48 hours; other federally reportable cases generally within 10 days. State thresholds and procedures can be stricter. File with the reporting authority for the state where the incident occurred.</p>
          </section>

          <section id="person-overboard" aria-labelledby="person-overboard-title">
            <p class="fpw-emergency-section-kicker">People</p>
            <h2 id="person-overboard-title">What to do when someone falls overboard</h2>
            <p>A person overboard can disappear from view quickly, even in daylight and calm water. Continuous visual contact and stopping propeller danger are essential.</p>
            <figure class="fpw-emergency-figure fpw-emergency-figure--safety-critical">
              <picture>
                <img src="<cfoutput>#fpwEmergencyBasePath#</cfoutput>/assets/images/boating-guides/common-boating-emergencies/person-overboard-controlled-recovery.jpg?v=20260823-owner-approved" srcset="<cfoutput>#fpwEmergencyBasePath#</cfoutput>/assets/images/boating-guides/common-boating-emergencies/person-overboard-controlled-recovery-640w.jpg?v=20260823-owner-approved 640w, <cfoutput>#fpwEmergencyBasePath#</cfoutput>/assets/images/boating-guides/common-boating-emergencies/person-overboard-controlled-recovery-960w.jpg?v=20260823-owner-approved 960w, <cfoutput>#fpwEmergencyBasePath#</cfoutput>/assets/images/boating-guides/common-boating-emergencies/person-overboard-controlled-recovery.jpg?v=20260823-owner-approved 1672w" sizes="(max-width: 480px) calc(100vw - 56px), (max-width: 1100px) calc(100vw - 96px), 760px" width="1672" height="941" alt="Two life-jacketed boaters aboard a cabin cruiser respond to a person overboard as one throws a ring buoy with a retrieval line toward the life-jacketed person in the water." loading="lazy" decoding="async">
              </picture>
              <figcaption>Maintain visual contact, deploy flotation and approach under control. Shift to neutral and shut the engine off before the person is alongside or recovery begins.</figcaption>
            </figure>

            <h3 class="fpw-emergency-action-heading">Do this first</h3>
            <ol>
              <li>Shout <strong>&ldquo;Person overboard!&rdquo;</strong> so everyone knows what happened.</li>
              <li>Throw flotation immediately&mdash;even if the person is wearing a life jacket. A throwable marks the location and gives the person another aid.</li>
              <li>Assign one person to point continuously at the person in the water. That lookout does nothing else.</li>
              <li>Press the chartplotter&rsquo;s MOB button if available, but do not let electronics replace the visual lookout.</li>
              <li>Slow, turn, or stop using the practiced maneuver appropriate to the boat, speed, wind, current, traffic, and location.</li>
              <li>Make a Mayday or Pan-Pan call appropriate to the danger. Use Mayday when the person is missing from sight, injured, unconscious, in cold/rough water, near traffic or hazards, or otherwise in grave and imminent danger.</li>
            </ol>

            <h3>Approach and recovery</h3>
            <ul>
              <li>Approach at the minimum speed that preserves control.</li>
              <li>Account for wind and current so the boat does not drift over the person.</li>
              <li>Keep the person in view from the operator&rsquo;s side when possible.</li>
              <li>Shift to neutral during the final approach and shut the engine off before the person reaches the propeller/recovery area. For multiple engines, ensure all propellers that could endanger the person are stopped.</li>
              <li>Bring the person aboard using a ladder, swim platform, low freeboard area, recovery sling, lifting tackle, or other method suited to the boat.</li>
              <li>An exhausted, injured, large, or unconscious person may be impossible to lift by hand. Practice a method that works with the people who normally use the boat.</li>
            </ul>

            <h3>If the person is not visible</h3>
            <p>Transmit a Mayday immediately. Mark the last-known position, note the time, deploy flotation/markers, and follow responder instructions. Maintain a lookout and avoid running over the search area with an engaged propeller.</p>

            <h3 class="fpw-emergency-stop-heading">Do not do this</h3>
            <ul>
              <li>Do not reverse blindly toward the person.</li>
              <li>Do not allow attention to shift entirely to the chartplotter.</li>
              <li>Do not let a rescuer jump in reflexively; that can create a second person in distress. Use a boat-based recovery whenever possible. Water entry should be limited to a trained, properly equipped response suited to the exact conditions and should not be improvised from this guide.</li>
              <li>Do not leave the helm unattended while the engine is engaged.</li>
              <li>Do not assume neutral guarantees the propeller cannot move; shut down for recovery when possible.</li>
            </ul>

            <h3 class="fpw-emergency-safe-heading">After recovery</h3>
            <p>Check responsiveness and breathing. Call emergency services for loss of consciousness, breathing difficulty, significant injury, cold-water exposure, suspected aspiration, or any uncertainty. Begin CPR/AED use when indicated and within the rescuer&rsquo;s training. Remove wet clothing and rewarm gradually when hypothermia is possible. Follow current first-aid and dispatcher instructions.</p>
            <p class="fpw-emergency-back"><a href="#guide-top">Back to top</a></p>
          </section>

          <section id="boat-capsize" aria-labelledby="boat-capsize-title">
            <p class="fpw-emergency-section-kicker">People</p>
            <h2 id="boat-capsize-title">What to do if the boat capsizes or sinking makes abandonment necessary</h2>
            <p>Many small boats have flotation and remain visible even when swamped or overturned. A boat is generally easier for rescuers to see than a person in the water.</p>
            <figure class="fpw-emergency-figure">
              <picture>
                <img src="<cfoutput>#fpwEmergencyBasePath#</cfoutput>/assets/images/boating-guides/common-boating-emergencies/capsize-stay-with-boat-visibility.jpg" srcset="<cfoutput>#fpwEmergencyBasePath#</cfoutput>/assets/images/boating-guides/common-boating-emergencies/capsize-stay-with-boat-visibility-640w.jpg 640w, <cfoutput>#fpwEmergencyBasePath#</cfoutput>/assets/images/boating-guides/common-boating-emergencies/capsize-stay-with-boat-visibility-960w.jpg 960w, <cfoutput>#fpwEmergencyBasePath#</cfoutput>/assets/images/boating-guides/common-boating-emergencies/capsize-stay-with-boat-visibility.jpg 1672w" sizes="(max-width: 480px) calc(100vw - 56px), (max-width: 1100px) calc(100vw - 96px), 760px" width="1672" height="941" alt="From the air, an overturned boat and grouped survivors are much more visible than one person alone in the water." loading="lazy" decoding="async">
              </picture>
              <figcaption>Stay with the boat unless fire, fuel, surf, a dam, rocks, or another immediate hazard makes leaving safer.</figcaption>
            </figure>

            <h3 class="fpw-emergency-action-heading">Do this first</h3>
            <ul>
              <li>Account for everyone and keep the group together.</li>
              <li>Put on life jackets or hold onto flotation immediately.</li>
              <li>Stay with and, when possible, climb onto the boat to get more of the body out of the water.</li>
              <li>Make a distress call or activate a registered beacon if it can be reached safely.</li>
              <li>Use whistles, lights, mirrors, flags, flares, or other signals when they are likely to be seen.</li>
              <li>Conserve energy and protect the airway, especially after sudden cold-water immersion.</li>
            </ul>

            <h3>When to leave the boat</h3>
            <p>Leave only when staying is more dangerous&mdash;for example, because of fire, fuel on the water, breaking surf against rocks, a dam/hydraulic, or responder instructions. Do not swim for shore merely because it looks close. Distance, current, waves, clothing, injury, and water temperature can make an apparently short swim impossible.</p>

            <h3>If abandoning before the boat sinks</h3>
            <ul>
              <li>Transmit position, number of people, and intention to abandon.</li>
              <li>Activate the EPIRB/PLB and keep it with the people, not the sinking boat, as the device instructions require.</li>
              <li>Take a handheld VHF, visual signals, first-aid kit, water, and exposure protection only if immediately reachable; do not delay escape to collect gear.</li>
              <li>Enter a life raft or other survival craft dry if possible.</li>
              <li>Keep the group together and maintain a count.</li>
            </ul>

            <h3>Cold-water priorities</h3>
            <p>Control breathing, keep the head and airway clear, minimize unnecessary swimming, and get as much of the body out of the water as possible. Hypothermia can occur in water below 70&deg;F, and cold shock can impair breathing and movement before hypothermia develops.</p>
          </section>

          <section id="boating-weather-visibility" aria-labelledby="boating-weather-visibility-title">
            <p class="fpw-emergency-section-kicker">Conditions</p>
            <h2 id="boating-weather-visibility-title">What to do when weather or visibility deteriorates</h2>
            <p>The best severe-weather maneuver is often the early decision not to be there. Thunderstorms can create abrupt wind shifts, steep waves, lightning, waterspouts, and near-zero visibility. Review the <a class="fpw-emergency-official" href="https://www.weather.gov/safety/safeboating-during" target="_blank" rel="noopener noreferrer" data-fpw-guide-source data-source-org="nws" data-section-id="boating-weather-visibility">National Weather Service safe-boating guidance<span class="fpw-emergency-new-window"> (opens in a new tab)</span></a> before departure.</p>
            <figure class="fpw-emergency-figure">
              <picture>
                <img src="<cfoutput>#fpwEmergencyBasePath#</cfoutput>/assets/images/boating-guides/common-boating-emergencies/boating-storm-early-shelter-decision.jpg?v=20260823-owner-approved-v2" srcset="<cfoutput>#fpwEmergencyBasePath#</cfoutput>/assets/images/boating-guides/common-boating-emergencies/boating-storm-early-shelter-decision-640w.jpg?v=20260823-owner-approved-v2 640w, <cfoutput>#fpwEmergencyBasePath#</cfoutput>/assets/images/boating-guides/common-boating-emergencies/boating-storm-early-shelter-decision-960w.jpg?v=20260823-owner-approved-v2 960w, <cfoutput>#fpwEmergencyBasePath#</cfoutput>/assets/images/boating-guides/common-boating-emergencies/boating-storm-early-shelter-decision.jpg?v=20260823-owner-approved-v2 1672w" sizes="(max-width: 480px) calc(100vw - 56px), (max-width: 1100px) calc(100vw - 96px), 760px" width="1672" height="941" alt="Cabin cruiser moving through a marked channel toward protected water between a red marker on the left and a green marker on the right, with a dark storm and heavy rain behind the boat." loading="lazy" decoding="async">
              </picture>
              <figcaption>Storms can close in quickly. When one is heading your way, seek safe harbor while you still have time to reach it safely.</figcaption>
            </figure>

            <h3>Thunderstorms, lightning, and strong wind</h3>
            <ul>
              <li>Put life jackets on everyone before the water becomes rough.</li>
              <li>Head for a safe harbor or shelter early. Do not wait until the storm blocks the route or makes docking unsafe.</li>
              <li>Reduce speed while maintaining the control needed for the conditions.</li>
              <li>Secure loose gear, close appropriate hatches, keep weight low and centered, and keep passengers seated in safe locations.</li>
              <li>Monitor VHF weather and Coast Guard broadcasts.</li>
              <li>If the boat has a cabin, the National Weather Service advises staying inside and avoiding metal and electrical devices. In an open boat, stay as low as practical and avoid unnecessary contact with metal.</li>
              <li>A cabin is not the same as lightning-safe shelter on land. Reach shore and a substantial enclosed building or hard-topped vehicle before the storm when possible.</li>
              <li>Keep well away from waterspouts; do not approach one for photographs or video.</li>
            </ul>
            <p>There is no single &ldquo;correct&rdquo; heading for every boat in rough water. Hull design, wave direction and period, wind, current, inlet conditions, traffic, and available sea room all matter. Operate at a speed and angle that maintain control without launching, burying the bow, taking water over the transom, or exposing the beam dangerously. Follow the boat manufacturer&rsquo;s guidance and turn back before conditions exceed the operator or boat.</p>

            <h3>Fog or heavy rain</h3>
            <ul>
              <li>Slow to a speed that allows effective collision avoidance and stopping within the visible distance.</li>
              <li>Turn on required navigation lights, including during daytime reduced visibility.</li>
              <li>Post a dedicated lookout and listen for engines, horns, bells, surf, and traffic.</li>
              <li>Use radar when equipped and understood, but do not let radar/GPS replace a proper visual and auditory lookout.</li>
              <li>Use GPS, compass, and current chart together to confirm position and hazards.</li>
              <li>Make the required sound signals for restricted visibility.</li>
              <li>Stay out of channels when safe and legal to do so; do not anchor in traffic unless necessary for immediate safety.</li>
              <li>If disoriented, stop in a safe location rather than continuing without a reliable position.</li>
            </ul>

            <h3>Darkness</h3>
            <ul>
              <li>Reduce speed and preserve night vision.</li>
              <li>Confirm navigation lights are operating.</li>
              <li>Use chart, compass, depth, radar/AIS when equipped, and aids to navigation together; do not assume every hazard or small boat will appear electronically.</li>
              <li>Avoid shining a bright spotlight continuously into other operators&rsquo; vision. Use it briefly to identify hazards when necessary.</li>
              <li>If electrical failure removes required lights or reliable navigation, make a safety call and reach a safe location before continuing.</li>
            </ul>

            <h3 class="fpw-emergency-call-heading">Call for help now if&hellip;</h3>
            <p>The boat cannot maintain control, is taking water, loses navigation or propulsion, anyone is injured or in the water, lightning/fire damages equipment, the operator cannot establish position, or the route to safety is no longer clear.</p>
          </section>

          <section id="medical-emergency-on-boat" aria-labelledby="medical-emergency-on-boat-title">
            <p class="fpw-emergency-section-kicker">People</p>
            <h2 id="medical-emergency-on-boat-title">What to do for a serious illness or injury aboard</h2>
            <p>The safest first-aid response starts with scene safety and an early call for professional help. This guide is not a substitute for current CPR/AED and first-aid training.</p>

            <h3 class="fpw-emergency-action-heading">Do this first</h3>
            <ol>
              <li>Keep the boat controllable. Slow or stop in a safe place, assign a capable operator, and remove hazards such as an engaged propeller, fire, electricity, or moving gear.</li>
              <li>Check responsiveness and normal breathing. Send a Mayday for an immediate threat to life; use VHF and 911 where available, and follow dispatcher or Coast Guard instructions.</li>
              <li>Give your exact position, patient age if known, chief problem, level of responsiveness, breathing status, severe bleeding, known allergies/medications, and number of people aboard.</li>
              <li>Provide care within your training. Begin CPR and use an AED when indicated. Control life-threatening external bleeding with firm direct pressure and an appropriate dressing; use a commercial tourniquet for life-threatening limb bleeding when trained or directed.</li>
              <li>Protect the patient from heat, cold, spray, and unnecessary movement. Do not give food, drink, alcohol, or medication to a person with altered consciousness or when emergency personnel advise against it.</li>
              <li>Prepare for transfer: clear a working area, secure loose equipment, light the boat at night, ready lines and fenders, and assign someone to guide responders.</li>
            </ol>

            <h3 class="fpw-emergency-call-heading">Call immediately for</h3>
            <ul>
              <li>trouble breathing, chest pain, stroke signs, seizure, severe allergic reaction, poisoning, or altered consciousness;</li>
              <li>no normal breathing, suspected drowning/aspiration, or loss of consciousness;</li>
              <li>uncontrolled or life-threatening bleeding, amputation, major burns, head/neck/spine trauma, or a serious fall;</li>
              <li>rapidly worsening heat illness, cold-water exposure, or any condition the crew cannot safely assess.</li>
            </ul>
            <p>If the boat is far from shore, do not begin a high-speed run without coordination. Responders may direct the boat toward a rendezvous point, send another asset, or advise the safest destination.</p>

            <h3>Prepare before the trip</h3>
            <p>Carry a first-aid kit matched to crew size and trip remoteness, nitrile gloves, CPR barrier, trauma dressings, and a tourniquet that the operator knows how to use. Keep passenger medical information and personal medications accessible with consent. Maintain current CPR/AED and first-aid training.</p>
          </section>

          <section id="boat-carbon-monoxide" aria-labelledby="boat-carbon-monoxide-title">
            <p class="fpw-emergency-section-kicker">People</p>
            <h2 id="boat-carbon-monoxide-title">What to do if carbon monoxide exposure is possible</h2>
            <p>Carbon monoxide (CO) is colorless, odorless, and tasteless. On boats it can accumulate around engines, generators, cabins, canvas enclosures, and the stern. Early symptoms&mdash;headache, dizziness, weakness, nausea, vomiting, chest pain, and confusion&mdash;can look like seasickness or fatigue. See the <a class="fpw-emergency-official" href="https://www.cdc.gov/carbon-monoxide/about/boating.html" target="_blank" rel="noopener noreferrer" data-fpw-guide-source data-source-org="cdc" data-section-id="boat-carbon-monoxide">CDC&rsquo;s boating carbon-monoxide guidance<span class="fpw-emergency-new-window"> (opens in a new tab)</span></a>.</p>
            <figure class="fpw-emergency-figure">
              <picture>
                <img src="<cfoutput>#fpwEmergencyBasePath#</cfoutput>/assets/images/boating-guides/common-boating-emergencies/boat-carbon-monoxide-danger-zones.jpg" srcset="<cfoutput>#fpwEmergencyBasePath#</cfoutput>/assets/images/boating-guides/common-boating-emergencies/boat-carbon-monoxide-danger-zones-640w.jpg 640w, <cfoutput>#fpwEmergencyBasePath#</cfoutput>/assets/images/boating-guides/common-boating-emergencies/boat-carbon-monoxide-danger-zones-960w.jpg 960w, <cfoutput>#fpwEmergencyBasePath#</cfoutput>/assets/images/boating-guides/common-boating-emergencies/boat-carbon-monoxide-danger-zones.jpg 1536w" sizes="(max-width: 480px) calc(100vw - 56px), (max-width: 1100px) calc(100vw - 96px), 760px" width="1536" height="1024" alt="Recreational cabin cruiser highlighting carbon-monoxide danger zones at the stern, swim platform, canvas-enclosed cockpit and cabin, with external exhaust backdrafting forward." loading="lazy" decoding="async">
              </picture>
              <figcaption>Conceptual hazard overlay&mdash;carbon monoxide is colorless and odorless. Exhaust can collect near the stern and be drawn into cockpits or cabins by wind, speed, trim, canvas and open compartments.</figcaption>
            </figure>

            <h3>Treat clustered or unexplained symptoms as CO until ruled out</h3>
            <ul>
              <li>Shut down engines, generators, heaters, and other combustion sources if this can be done safely.</li>
              <li>Move everyone to fresh air, away from exhaust and the stern.</li>
              <li>Call for emergency medical help. State that CO exposure is suspected and report how many people have symptoms.</li>
              <li>Do not re-enter an enclosed space to retrieve gear or search without trained rescue equipment.</li>
              <li>Do not restart the suspected source until it has been inspected and the space is declared safe.</li>
            </ul>

            <h3>Prevent exposure</h3>
            <ul>
              <li>Install marine-rated CO alarms in every enclosed accommodation area as recommended by the boat and alarm manufacturers; test and replace them on schedule.</li>
              <li>Never block an exhaust outlet or run an engine/generator when exhaust can be trapped by canvas, wind, a nearby seawall, or another boat.</li>
              <li>Keep swimmers and children away from the stern, swim platform, and generator exhaust whenever machinery is running.</li>
              <li>Never sit, teak-surf, body-surf, or hold onto the swim platform while engines are operating.</li>
              <li>Remember that a nearby boat&rsquo;s exhaust can enter your cabin.</li>
            </ul>
            <p>Do not depend on smell. Exhaust odor and CO concentration are not the same thing.</p>
          </section>

          <section id="disabled-boat-immediate-hazard" aria-labelledby="disabled-boat-immediate-hazard-title">
            <p class="fpw-emergency-section-kicker">Conditions</p>
            <h2 id="disabled-boat-immediate-hazard-title">What to do if disabled near a channel, inlet, surf, dam, bridge, rocks, or other immediate hazard</h2>
            <p>A routine breakdown becomes urgent when wind, waves, current, traffic, or limited room are carrying the boat toward danger.</p>

            <h3>Act before the margin disappears</h3>
            <ul>
              <li>Put on life jackets and start P.A.C.E.</li>
              <li>Make an urgency or distress call early. State both the equipment failure and the hazard: &ldquo;disabled and drifting toward the north jetty,&rdquo; for example.</li>
              <li>Display appropriate lights, shapes, or signals and keep a lookout for traffic.</li>
              <li>Anchor only if it is safe, the depth/holding ground and gear are suitable, and doing so will not put the boat in a channel, breaking surf, or another worse position.</li>
              <li>Do not enter a hazardous inlet simply because it is the shortest path home. Conditions at the entrance may be worse than outside.</li>
              <li>Do not let a passenger attempt an improvised swim, jump to rocks, or handle a line around a propeller.</li>
            </ul>
            <p>If collision, grounding, breaking surf, a dam/hydraulic, or loss of the boat is imminent, use Mayday&mdash;not a routine towing request. Give position and drift direction first, then people aboard and the approaching hazard.</p>
          </section>

          <section id="overdue-boat" aria-labelledby="overdue-boat-title">
            <p class="fpw-emergency-section-kicker">Communication &amp; preparation</p>
            <h2 id="overdue-boat-title">What to do when plans change or the boat is overdue</h2>
            <figure class="fpw-emergency-figure">
              <picture>
                <img src="<cfoutput>#fpwEmergencyBasePath#</cfoutput>/assets/images/boating-guides/common-boating-emergencies/overdue-boater-response-information-chain.jpg?v=20260823-owner-approved" srcset="<cfoutput>#fpwEmergencyBasePath#</cfoutput>/assets/images/boating-guides/common-boating-emergencies/overdue-boater-response-information-chain-640w.jpg?v=20260823-owner-approved 640w, <cfoutput>#fpwEmergencyBasePath#</cfoutput>/assets/images/boating-guides/common-boating-emergencies/overdue-boater-response-information-chain-960w.jpg?v=20260823-owner-approved 960w, <cfoutput>#fpwEmergencyBasePath#</cfoutput>/assets/images/boating-guides/common-boating-emergencies/overdue-boater-response-information-chain.jpg?v=20260823-owner-approved 1672w" sizes="(max-width: 480px) calc(100vw - 56px), (max-width: 1100px) calc(100vw - 96px), 760px" width="1672" height="941" alt="Three-panel scene showing a boater at a marina, a shore contact reviewing the boat and route while on the phone, and a rescue coordinator viewing the same vessel and route information." loading="lazy" decoding="async">
              </picture>
              <figcaption>Conceptual information chain&mdash;not a representation of continuous live vessel tracking.</figcaption>
            </figure>

            <h3>If the boat changes route or return time</h3>
            <p>Contact the float-plan holder before the original deadline. Give the new route, destination, ETA, people aboard, and any meaningful equipment or weather change. Update the active FloatPlanWizard plan through the intended workflow; do not assume a casual text message updates the plan.</p>

            <h3>If you are the shore contact and the boat is overdue</h3>
            <ol>
              <li>Follow the plan&rsquo;s agreed grace period and contact steps; do not invent a new delay after the deadline.</li>
              <li>Try the operator and listed passengers using the planned channels.</li>
              <li>Check only the logical, pre-agreed contacts and locations. Do not spend hours independently searching while conditions worsen.</li>
              <li>If concern remains&mdash;or danger is already indicated&mdash;contact the appropriate rescue authority. In the United States, call 911 for an emergency and provide the float plan; the Coast Guard can also be reached on VHF Channel 16 by vessels in range.</li>
              <li>Provide the boat description/photo, registration, launch point, route, destination, last known contact/location, people aboard, vehicle/trailer details, communications and safety equipment, medical concerns, and weather.</li>
              <li>Remain reachable. Record times, calls, and instructions. Tell authorities immediately if the boat checks in.</li>
            </ol>
            <p>An overdue plan is decision support, not an automatic rescue dispatch unless the specific FloatPlanWizard service and plan terms explicitly provide monitoring/escalation.</p>
            <p class="fpw-emergency-related-inline">Read <a href="<cfoutput>#fpwEmergencyBasePath#</cfoutput>/shore-contact-overdue-boater/">what a shore contact should do when a boater is overdue</a>, and review the <a href="<cfoutput>#fpwEmergencyBasePath#</cfoutput>/solo-boating-safety-guide/">Solo Boating Safety Guide</a>.</p>
          </section>

          <section id="boating-emergency-communications" aria-labelledby="boating-emergency-communications-title">
            <p class="fpw-emergency-section-kicker">Communication &amp; preparation</p>
            <h2 id="boating-emergency-communications-title">Which emergency communication device should a recreational boater carry?</h2>
            <p>No single device covers every situation. Build layers appropriate to the operating area.</p>

            <div class="fpw-emergency-table-region" role="region" aria-label="Emergency communication devices comparison" tabindex="0">
              <table>
                <thead>
                  <tr>
                    <th scope="col">Device</th>
                    <th scope="col">Best use</th>
                    <th scope="col">Important limitation or setup</th>
                  </tr>
                </thead>
                <tbody>
                  <tr>
                    <th scope="row">Fixed-mount VHF with DSC</th>
                    <td>Primary marine distress and working communications; alerts nearby vessels and rescue stations</td>
                    <td>Register an MMSI, connect position data/GPS, keep antenna and backup power serviceable</td>
                  </tr>
                  <tr>
                    <th scope="row">Waterproof handheld VHF</th>
                    <td>Backup and communication after leaving the helm/boat</td>
                    <td>Shorter range and finite battery; tether it and keep it charged</td>
                  </tr>
                  <tr>
                    <th scope="row">EPIRB</th>
                    <td>Vessel distress offshore or in remote marine conditions; satellite alerting</td>
                    <td>Register the 406 MHz beacon with NOAA, mount/carry as designed, inspect battery/release dates, test only per manufacturer instructions</td>
                  </tr>
                  <tr>
                    <th scope="row">PLB</th>
                    <td>Personal satellite distress alerting carried on the body</td>
                    <td>Usually manually activated; register it and understand that it is not a two-way conversation unless the model explicitly supports messaging</td>
                  </tr>
                  <tr>
                    <th scope="row">Mobile phone</th>
                    <td>911, marina/tow contacts, weather/data where service exists</td>
                    <td>Coverage, location sharing, battery, and water resistance can fail; it does not broadcast to nearby vessels</td>
                  </tr>
                  <tr>
                    <th scope="row">Satellite messenger/phone</th>
                    <td>Two-way contact beyond cellular coverage</td>
                    <td>Subscription, sky view, battery, service region, and emergency workflow vary by device</td>
                  </tr>
                  <tr>
                    <th scope="row">Visual and sound signals</th>
                    <td>Help responders and nearby boats locate the vessel/person</td>
                    <td>Must be accessible, serviceable, legal for the operating area, and used without creating fire/injury risk</td>
                  </tr>
                </tbody>
              </table>
            </div>

            <h3>Setup that must happen before departure</h3>
            <ul>
              <li>Obtain and register the correct MMSI; enter it into the DSC radio once, carefully.</li>
              <li>Connect the fixed VHF to reliable position data and verify the displayed position/time.</li>
              <li>Register every U.S.-coded 406 MHz EPIRB or PLB with NOAA and update owner, vessel, contact, or trip-profile changes promptly.</li>
              <li>Teach passengers where distress controls are, but protect covered buttons from casual activation.</li>
              <li>Tether handheld devices, use waterproof cases where appropriate, and carry charging/backup power.</li>
              <li>Test radios, DSC, alarms, and beacons only through their approved self-test procedures. Never make a live false distress transmission as a test.</li>
            </ul>
            <p>If a beacon is activated accidentally, contact the responsible rescue authority immediately and report the false alert; do not simply switch it off and assume the alert disappeared.</p>
            <p class="fpw-emergency-back"><a href="#guide-top">Back to top</a></p>
          </section>

          <section id="passenger-safety-briefing" aria-labelledby="passenger-safety-briefing-title">
            <p class="fpw-emergency-section-kicker">Communication &amp; preparation</p>
            <h2 id="passenger-safety-briefing-title">Give passengers this two-minute safety briefing before leaving</h2>
            <p>Use plain language and physically point to each item.</p>
            <ol>
              <li><strong>Life jackets:</strong> &ldquo;This is yours; here is how it fastens. Wear it now under these conditions.&rdquo;</li>
              <li><strong>Movement:</strong> &ldquo;One hand for the boat. Stay seated while we are maneuvering; ask before moving forward or aft.&rdquo;</li>
              <li><strong>Engine cut-off:</strong> &ldquo;This stops propulsion if I leave the helm. Do not remove or bypass it.&rdquo;</li>
              <li><strong>Person overboard:</strong> &ldquo;Shout, point continuously, and throw flotation. Do not jump in.&rdquo;</li>
              <li><strong>Fire and flooding:</strong> Show extinguisher, fire port/fixed system if fitted, bilge-pump controls, seacocks/soft plugs, and the rule not to open an engine hatch into a suspected fire.</li>
              <li><strong>Calling for help:</strong> Show VHF, Channel 16, DSC distress button, boat name/registration, location display, and the written Mayday card.</li>
              <li><strong>Emergency stop/controls:</strong> Identify one capable backup operator and show throttle neutral, ignition/stop, steering, and how to read position.</li>
              <li><strong>First aid and medical needs:</strong> Show kit/AED location and privately confirm allergies, critical medicines, mobility limits, and who has current training.</li>
              <li><strong>Rules for this trip:</strong> No bow/transom riding, no swimming near running machinery, no line handling without instruction, and no alcohol/drug impairment for the operator.</li>
              <li><strong>Float plan:</strong> Name the shore contact and explain the return/check-in deadline.</li>
            </ol>
            <p>For children, non-swimmers, first-time guests, and passengers with disabilities, confirm fit and understanding individually. A nod from the group is not the same as demonstrated understanding.</p>
          </section>

          <section id="boat-emergency-equipment" aria-labelledby="boat-emergency-equipment-title">
            <p class="fpw-emergency-section-kicker">Communication &amp; preparation</p>
            <h2 id="boat-emergency-equipment-title">Emergency equipment checklist for an everyday recreational boat</h2>
            <p>Requirements vary by boat, propulsion, length, waterway, time of day, state, and voyage. Check current federal, state, local, and manufacturer requirements. This operational list complements&mdash;not replaces&mdash;required-equipment rules.</p>

            <div class="fpw-emergency-checklist-grid">
              <section aria-labelledby="equipment-wearable-title">
                <h3 id="equipment-wearable-title">Wearable and recovery</h3>
                <ul>
                  <li>Correctly sized, serviceable U.S. Coast Guard-approved life jacket for each person; appropriate wear for children and the activity</li>
                  <li>Throwable flotation immediately reachable where required and useful</li>
                  <li>Boarding ladder or practiced recovery method usable from the water</li>
                  <li>Engine cut-off device connected to the operator when required or prudent</li>
                  <li>Heaving line, boat hook, whistle, waterproof light, and thermal/exposure protection</li>
                </ul>
              </section>

              <section aria-labelledby="equipment-communications-title">
                <h3 id="equipment-communications-title">Communications and location</h3>
                <ul>
                  <li>Fixed VHF/DSC with registered MMSI and position input where appropriate</li>
                  <li>Waterproof floating/tethered handheld VHF</li>
                  <li>Charged phone in a waterproof case, plus backup power</li>
                  <li>Registered EPIRB/PLB for offshore, remote, cold-water, or otherwise delayed-rescue trips</li>
                  <li>Current chart, compass, position source, written vessel identifiers, and Mayday card</li>
                </ul>
              </section>

              <section aria-labelledby="equipment-fire-title">
                <h3 id="equipment-fire-title">Fire, flooding, and propulsion</h3>
                <ul>
                  <li>Correct number/type of accessible, serviceable fire extinguishers; fixed system/fire port where installed</li>
                  <li>Bilge pumps with tested float switches/alarms plus a manual pump or bucket</li>
                  <li>Soft wooden plugs sized for underwater fittings; basic leak-control materials</li>
                  <li>Anchor, rode, and chafe protection sized for the boat and operating area</li>
                  <li>Toolkit, spare fuses/breakers as appropriate, spare drain plug, flashlight/headlamp, and propulsion-specific spares the operator can safely use</li>
                </ul>
              </section>

              <section aria-labelledby="equipment-medical-title">
                <h3 id="equipment-medical-title">Medical and signaling</h3>
                <ul>
                  <li>First-aid/trauma kit, gloves, CPR barrier, personal medications, emergency medical information</li>
                  <li>AED when trip profile, crew risk, budget, and environment justify it</li>
                  <li>Current, accessible day/night visual distress signals and sound-producing devices required for the voyage</li>
                  <li>Drinking water, sun protection, seasickness supplies, and extra clothing appropriate to exposure</li>
                </ul>
              </section>
            </div>

            <h3>Before every departure</h3>
            <ul>
              <li>Weather, tides/current, daylight, route hazards, fuel/energy margin, bilge, drain plug, steering/throttle, cooling flow, batteries, lights, horn, radio, alarms, safety gear dates, and passenger count</li>
              <li>Float plan sent to a responsible person with a clear return time and escalation instructions</li>
            </ul>
            <p>The right kit is the one that is legal, maintained, accessible in the actual emergency, and understood by the crew. Gear buried under luggage is not ready gear.</p>
          </section>

          <section id="boating-accident-reporting" aria-labelledby="boating-accident-reporting-title">
            <p class="fpw-emergency-section-kicker">After the emergency</p>
            <h2 id="boating-accident-reporting-title">After everyone is safe: reporting, documentation, and recovery</h2>
            <p>Safety and medical care come before paperwork. Once the immediate danger is controlled:</p>
            <ol>
              <li><strong>Account for people and continuing hazards.</strong> Watch for delayed symptoms, renewed flooding/fire, fuel vapor, unstable batteries, changing weather, and traffic.</li>
              <li><strong>Follow responder instructions.</strong> Do not move, restart, tow, refloat, or enter a damaged boat if authorities or scene conditions make that unsafe.</li>
              <li><strong>Exchange and preserve facts.</strong> Record vessel/operator/contact/insurance information, names of passengers and witnesses, time, GPS position, weather, visibility, headings/speeds if known, and responder/report numbers. Photograph damage and the scene only when safe; do not interfere with rescue.</li>
              <li><strong>Report the boating accident when required.</strong> <a class="fpw-emergency-official" href="https://www.ecfr.gov/current/title-33/chapter-I/subchapter-S/part-173/subpart-C/section-173.55" target="_blank" rel="noopener noreferrer" data-fpw-guide-source data-source-org="ecfr" data-section-id="boating-accident-reporting">Federal rules<span class="fpw-emergency-new-window"> (opens in a new tab)</span></a> require a report when an occurrence results in death; disappearance indicating possible death or injury; an injury requiring medical treatment beyond first aid; property damage of $2,000 or more; or complete loss of a vessel. File within 48 hours when a person dies within 24 hours, requires treatment beyond first aid, or disappears; file within 10 days for other federally reportable cases. File with the state reporting authority where the accident occurred. State/local rules may be broader or faster.</li>
              <li><strong>Report pollution.</strong> Stop the source only if safe. Do not use detergent or other dispersants. In U.S. waters, report a discharge that causes a sheen/discoloration, sludge, or emulsion to the National Response Center at <strong>1-800-424-8802</strong> and follow Coast Guard/state instructions.</li>
              <li><strong>Notify insurer/tow/storage providers.</strong> Use verified contacts and preserve receipts. Do not authorize salvage or sign broad liability releases without understanding the terms.</li>
              <li><strong>Quarantine and inspect damaged systems.</strong> A qualified technician should inspect hull, propulsion, steering, fuel, electrical, batteries, and safety equipment after collision, grounding, flooding, overheating, fire, or lightning.</li>
              <li><strong>Debrief the trip.</strong> Update the float-plan holder, record what worked, replace used/expired gear, and correct the underlying cause before the next departure.</li>
            </ol>
            <p>Do not speculate publicly about fault while facts are incomplete. Give authorities accurate observations and distinguish what you saw from what you inferred.</p>
          </section>

          <section id="printable-boating-emergency-card" aria-labelledby="printable-boating-emergency-card-title">
            <p class="fpw-emergency-section-kicker">Quick-reference tool</p>
            <h2 id="printable-boating-emergency-card-title">Printable boating emergency card</h2>
            <p>Use the card copy below as an onboard quick reference. Print this guide and keep the first-minute sequence and Mayday script where the operator and passengers can reach them.</p>

            <div class="fpw-emergency-card" aria-label="Printable boating emergency cards">
              <section class="fpw-emergency-quick-card fpw-emergency-quick-card--pace" id="emergency-card-pace" aria-labelledby="emergency-card-front-title">
                <header class="fpw-emergency-card-header">
                  <p class="fpw-emergency-label">Front</p>
                  <a class="cbe-card-download" href="<cfoutput>#fpwEmergencyBasePath#</cfoutput>/downloads/first-60-seconds-pace.pdf" download="first-60-seconds-pace.pdf" type="application/pdf" aria-label="Download First 60 seconds — P.A.C.E. PDF" data-fpw-guide-card data-card-id="first-60-seconds-pace" data-file-name="first-60-seconds-pace.pdf" data-placement="quick_reference_card">
                    <svg viewBox="0 0 24 24" aria-hidden="true" focusable="false"><path d="M12 3v11m0 0 4-4m-4 4-4-4M5 17v3h14v-3"/></svg>
                    <span>Download PDF</span>
                  </a>
                </header>
                <h3 id="emergency-card-front-title">First 60 seconds &mdash; P.A.C.E.</h3>
                <dl>
                  <div>
                    <dt>P &mdash; People</dt>
                    <dd>Life jackets on. Count everyone. Treat immediate injury. Assign jobs.</dd>
                  </div>
                  <div>
                    <dt>A &mdash; Assess</dt>
                    <dd>Position &bull; people aboard &bull; weather/drift &bull; fire/fuel &bull; flooding &bull; propulsion/steering &bull; nearby hazards.</dd>
                  </div>
                  <div>
                    <dt>C &mdash; Control</dt>
                    <dd>Neutral/stop propulsion when needed. Stop leak/fire/fuel only if safe. Anchor only if suitable. Keep lookout.</dd>
                  </div>
                  <div>
                    <dt>E &mdash; Emergency call</dt>
                    <dd>Mayday for grave/imminent danger. Pan-Pan for urgent safety problem. VHF Ch 16; DSC first if configured. Give position early.</dd>
                  </div>
                </dl>
              </section>

              <section class="fpw-emergency-quick-card fpw-emergency-quick-card--mayday" id="emergency-card-mayday" aria-labelledby="emergency-card-back-title">
                <header class="fpw-emergency-card-header">
                  <p class="fpw-emergency-label">Back</p>
                  <a class="cbe-card-download" href="<cfoutput>#fpwEmergencyBasePath#</cfoutput>/downloads/mayday-vhf-channel-16-script.pdf" download="mayday-vhf-channel-16-script.pdf" type="application/pdf" aria-label="Download Mayday voice script — VHF Channel 16 PDF" data-fpw-guide-card data-card-id="mayday-vhf-channel-16-script" data-file-name="mayday-vhf-channel-16-script.pdf" data-placement="quick_reference_card">
                    <svg viewBox="0 0 24 24" aria-hidden="true" focusable="false"><path d="M12 3v11m0 0 4-4m-4 4-4-4M5 17v3h14v-3"/></svg>
                    <span>Download PDF</span>
                  </a>
                </header>
                <h3 id="emergency-card-back-title">Mayday voice script &mdash; VHF Channel 16</h3>
                <p><strong>MAYDAY, MAYDAY, MAYDAY</strong><br>
                THIS IS <strong>[BOAT NAME]</strong> three times<br>
                Call sign/registration <strong>[________]</strong><br>
                MAYDAY <strong>[BOAT NAME]</strong><br>
                POSITION <strong>[lat/long or clear location]</strong><br>
                WE ARE <strong>[nature of distress]</strong><br>
                WE NEED <strong>[assistance]</strong><br>
                <strong>[number]</strong> PEOPLE ABOARD; <strong>[injuries/medical]</strong><br>
                BOAT IS <strong>[length/type/color]</strong><br>
                OTHER: <strong>[drift, hazards, PFDs, beacon]</strong><br>
                OVER</p>
                <p>Stay by the radio. Repeat if no answer. Follow Coast Guard instructions. If time is critical, say position and danger before lower-priority detail.</p>
              </section>

              <section class="fpw-emergency-quick-card fpw-emergency-quick-card--pan-pan" id="emergency-card-pan-pan" aria-labelledby="emergency-card-pan-pan-title">
                <header class="fpw-emergency-card-header">
                  <p class="fpw-emergency-label">URGENT &mdash; NOT DISTRESS</p>
                  <a class="cbe-card-download" href="<cfoutput>#fpwEmergencyBasePath#</cfoutput>/downloads/pan-pan-vhf-channel-16-script.pdf" download="pan-pan-vhf-channel-16-script.pdf" type="application/pdf" aria-label="Download PAN-PAN voice script — VHF Channel 16 PDF" data-fpw-guide-card data-card-id="pan-pan-vhf-channel-16-script" data-file-name="pan-pan-vhf-channel-16-script.pdf" data-placement="quick_reference_card">
                    <svg viewBox="0 0 24 24" aria-hidden="true" focusable="false"><path d="M12 3v11m0 0 4-4m-4 4-4-4M5 17v3h14v-3"/></svg>
                    <span>Download PDF</span>
                  </a>
                </header>
                <h3 id="emergency-card-pan-pan-title">PAN-PAN voice script &mdash; VHF Channel 16</h3>
                <p><strong>PAN-PAN, PAN-PAN, PAN-PAN</strong><br>
                <strong>ALL STATIONS, ALL STATIONS, ALL STATIONS</strong><br>
                THIS IS <strong>[BOAT NAME]</strong> three times<br>
                Call sign/registration <strong>[__________]</strong><br>
                PAN-PAN <strong>[BOAT NAME]</strong><br>
                POSITION <strong>[latitude/longitude or clear location]</strong><br>
                WE HAVE <strong>[nature of urgent safety problem]</strong><br>
                WE REQUIRE <strong>[assistance requested]</strong><br>
                <strong>[number]</strong> PEOPLE ABOARD; <strong>[injuries/medical information]</strong><br>
                BOAT IS <strong>[length/type/color]</strong><br>
                OTHER: <strong>[drift, nearby hazards, PFDs, beacon]</strong><br>
                OVER</p>
                <p>Use PAN-PAN when the safety of the boat or a person is in jeopardy, but there is no grave and imminent danger. If the situation becomes grave and imminent, transmit MAYDAY instead.</p>
                <p>Stay by the radio. Repeat the call if no answer is received, and follow Coast Guard instructions.</p>
                <p>PAN-PAN is pronounced &ldquo;pahn-pahn.&rdquo;</p>
              </section>

              <section class="fpw-emergency-quick-card fpw-emergency-card-fields" id="emergency-card-boat-fields" aria-labelledby="emergency-card-fields-title">
                <header class="fpw-emergency-card-header fpw-emergency-card-header--download-only">
                  <a class="cbe-card-download" href="<cfoutput>#fpwEmergencyBasePath#</cfoutput>/downloads/boat-specific-emergency-fields.pdf" download="boat-specific-emergency-fields.pdf" type="application/pdf" aria-label="Download Boat-specific fields PDF" data-fpw-guide-card data-card-id="boat-specific-emergency-fields" data-file-name="boat-specific-emergency-fields.pdf" data-placement="quick_reference_card">
                    <svg viewBox="0 0 24 24" aria-hidden="true" focusable="false"><path d="M12 3v11m0 0 4-4m-4 4-4-4M5 17v3h14v-3"/></svg>
                    <span>Download PDF</span>
                  </a>
                </header>
                <h3 id="emergency-card-fields-title">Boat-specific fields</h3>
                <ul>
                  <li>Boat name: __________</li>
                  <li>Registration/call sign: __________</li>
                  <li>MMSI: __________</li>
                  <li>Length/type/color: __________</li>
                  <li>Emergency equipment locations: VHF ___ / EPIRB-PLB ___ / first aid ___ / extinguishers ___ / seacocks ___</li>
                  <li>Shore contact: __________ / phone: __________</li>
                </ul>
                <p>P.A.C.E. is a FloatPlanWizard quick-recall framework; follow official responder instructions.</p>
              </section>
            </div>

            <div class="fpw-emergency-card-downloads" aria-label="Download boating emergency cards">
              <a class="fpw-emergency-card-download" href="<cfoutput>#fpwEmergencyBasePath#</cfoutput>/downloads/floatplanwizard-boating-emergency-card-4x6.pdf" download="floatplanwizard-boating-emergency-card-4x6.pdf" data-fpw-guide-card data-card-id="combined-4x6" data-file-name="floatplanwizard-boating-emergency-card-4x6.pdf" data-placement="download_section">
                <strong>Download the two-sided 4&times;6 card (PDF)</strong>
                <span>Two 6&times;4-inch landscape pages for short-edge duplex printing at 100% / Actual Size.</span>
              </a>
              <a class="fpw-emergency-card-download" href="<cfoutput>#fpwEmergencyBasePath#</cfoutput>/downloads/floatplanwizard-boating-emergency-card-letter.pdf" download="floatplanwizard-boating-emergency-card-letter.pdf" data-fpw-guide-card data-card-id="combined-letter" data-file-name="floatplanwizard-boating-emergency-card-letter.pdf" data-placement="download_section">
                <strong>Download the letter-size two-up sheet (PDF)</strong>
                <span>Two full-size cards per Letter sheet for long-edge duplex printing, with alignment and cutting marks.</span>
              </a>
            </div>

            <button class="fpw-emergency-print-button" type="button" data-fpw-guide-print data-placement="download_section">Print this guide and emergency-card copy</button>
          </section>

          <section id="boating-emergency-faq" aria-labelledby="boating-emergency-faq-title">
            <p class="fpw-emergency-section-kicker">Frequently asked questions</p>
            <h2 id="boating-emergency-faq-title">Common boating emergency questions</h2>

            <div class="fpw-emergency-faq-list">
              <section>
                <h3>What is the first thing to do in a boating emergency?</h3>
                <p>Protect people first: put on life jackets, count everyone, control immediate threats, establish position, and call early when the situation is urgent or could worsen. FloatPlanWizard&rsquo;s P.A.C.E. sequence&mdash;People, Assess, Control, Emergency call&mdash;helps organize the first minute.</p>
              </section>
              <section>
                <h3>Should I call Mayday or Pan-Pan?</h3>
                <p>Use Mayday when there is grave and imminent danger requiring immediate assistance, such as sinking, fire, a person missing overboard, or a life-threatening medical emergency. Use Pan-Pan for an urgent safety problem that is serious but not immediately life-threatening, such as a disabled boat in a safe position that may need assistance. If conditions deteriorate, upgrade the call.</p>
              </section>
              <section>
                <h3>Is a phone enough for boating emergencies?</h3>
                <p>No. A phone can reach 911 or a service provider where coverage exists, but it does not broadcast to nearby boats and may lose coverage, power, or water resistance. A VHF marine radio is normally the primary on-water tool in coastal and many inland operating areas; add registered beacon or satellite capability for remote trips.</p>
              </section>
              <section>
                <h3>What channel should I use for a marine distress call?</h3>
                <p>In the United States, use VHF Channel 16 for the voice distress call. If a properly configured DSC radio is available, send the DSC distress alert and then make the voice Mayday on Channel 16.</p>
              </section>
              <section>
                <h3>Should I anchor when the engine dies?</h3>
                <p>Anchor if drift is creating danger and the depth, bottom, sea room, and equipment make anchoring safe. Do not anchor blindly in a traffic channel, breaking surf, deep water beyond the rode, or where anchoring creates a greater hazard.</p>
              </section>
              <section>
                <h3>Should I restart the engine when the boat is taking on water?</h3>
                <p>Only after identifying the likely source and confirming that restarting will not worsen flooding, fuel/fire risk, entanglement, or mechanical damage. An engine-driven pump can help on some boats, while a damaged cooling/exhaust hose can pump more water aboard. When uncertain and danger is increasing, call first and follow responder/manufacturer guidance.</p>
              </section>
              <section>
                <h3>Should I open the engine hatch if I see smoke?</h3>
                <p>Not on a suspected engine-compartment fire. Opening the hatch can feed the fire with oxygen and expose the crew to flame and toxic smoke. Stop machinery/fuel if designed to do so safely and use the fixed system or fire-discharge port as the boat manufacturer directs.</p>
              </section>
              <section>
                <h3>Should I immediately reverse off after running aground?</h3>
                <p>No. Stop, account for people, check tide/current, and inspect for flooding, hull/propulsion damage, and environmental risk. Powering off can worsen damage, stir sediment into cooling intakes, or move the boat into deeper danger. Call for professional help when the condition is uncertain.</p>
              </section>
              <section>
                <h3>When must a U.S. recreational boating accident be reported?</h3>
                <p>Federal reporting generally applies to death, qualifying disappearance, injury requiring treatment beyond first aid, property damage of at least $2,000, or complete vessel loss. Deadlines are generally 48 hours for death within 24 hours, treatment beyond first aid, or disappearance, and 10 days for other federally reportable cases. Check the state where the accident occurred because its rules may be stricter.</p>
              </section>
              <section>
                <h3>What should a float plan include?</h3>
                <p>Include the boat description and photo, registration, people aboard and emergency contacts, launch/vehicle information, route and stops, departure and return times, communications and survival equipment, and exact overdue instructions. Give it to a responsible person and update it when plans change.</p>
              </section>
            </div>
          </section>

          <section id="plan-before-emergency" aria-labelledby="plan-before-emergency-title">
            <p class="fpw-emergency-section-kicker">Preparation</p>
            <h2 id="plan-before-emergency-title">Plan before the emergency</h2>
            <p>A calm response starts ashore. Create a FloatPlanWizard plan with the route, people, boat, contacts, timing, and safety details a shore contact or responder may need.</p>
            <p>FloatPlanWizard is a planning and communication tool. It does not determine when rescue action is required, verify an emergency, contact authorities for you, dispatch assistance, guarantee message delivery, continuously track every trip, or guarantee a vessel&rsquo;s current location.</p>

            <div class="fpw-emergency-related-guides" aria-labelledby="related-guides-title">
              <h3 id="related-guides-title">Related guides and tools</h3>
              <ul>
                <li><a href="<cfoutput>#fpwEmergencyBasePath#</cfoutput>/shore-contact-overdue-boater/">Learn how shore contacts should respond to an overdue boater</a></li>
                <li><a href="<cfoutput>#fpwEmergencyBasePath#</cfoutput>/solo-boating-safety-guide/">Solo Boating Safety Guide</a></li>
                <li><a href="<cfoutput>#fpwEmergencyBasePath#</cfoutput>/boat-fuel-calculator/">Boat Fuel Calculator</a></li>
                <li><a href="<cfoutput>#fpwEmergencyBasePath#</cfoutput>/app/pricing.cfm">Compare FloatPlanWizard plans</a></li>
              </ul>
            </div>
          </section>

          <section id="sources" aria-labelledby="sources-title">
            <p class="fpw-emergency-section-kicker">Sources and limitations</p>
            <h2 id="sources-title">Sources and official resources</h2>
            <p>Reviewed August 22, 2026. Official guidance and laws can change. These sources support the safety, communication, weather, medical, and reporting guidance in this article; their inclusion does not imply endorsement of FloatPlanWizard.</p>
            <ul class="fpw-emergency-source-list">
              <li><a class="fpw-emergency-official" href="https://uscgboating.org/library/accident-statistics/Recreational-Boating-Statistics-2024.pdf" target="_blank" rel="noopener noreferrer" data-fpw-guide-source data-source-org="uscg" data-section-id="sources">U.S. Coast Guard &mdash; Recreational Boating Statistics 2024<span class="fpw-emergency-new-window"> (opens in a new tab)</span></a></li>
              <li><a class="fpw-emergency-official" href="https://uscgboating.org/assets/1/AssetManager/Boaters-Guide-to-Federal-Requirements-for-Receational-Boats-20231108.pdf" target="_blank" rel="noopener noreferrer" data-fpw-guide-source data-source-org="uscg" data-section-id="sources">U.S. Coast Guard &mdash; A Boater&rsquo;s Guide to Federal Requirements<span class="fpw-emergency-new-window"> (opens in a new tab)</span></a></li>
              <li><a class="fpw-emergency-official" href="https://www.navcen.uscg.gov/radio-information-for-boaters" target="_blank" rel="noopener noreferrer" data-fpw-guide-source data-source-org="uscg" data-section-id="sources">U.S. Coast Guard Navigation Center &mdash; Radio Information for Boaters<span class="fpw-emergency-new-window"> (opens in a new tab)</span></a></li>
              <li><a class="fpw-emergency-official" href="https://www.navcen.uscg.gov/digital-selective-calling" target="_blank" rel="noopener noreferrer" data-fpw-guide-source data-source-org="uscg" data-section-id="sources">U.S. Coast Guard Navigation Center &mdash; Digital Selective Calling<span class="fpw-emergency-new-window"> (opens in a new tab)</span></a></li>
              <li><a class="fpw-emergency-official" href="https://www.navcen.uscg.gov/navigation-rules-amalgamated" target="_blank" rel="noopener noreferrer" data-fpw-guide-source data-source-org="uscg" data-section-id="sources">U.S. Coast Guard Navigation Center &mdash; Navigation Rules<span class="fpw-emergency-new-window"> (opens in a new tab)</span></a></li>
              <li><a class="fpw-emergency-official" href="https://www.weather.gov/safety/safeboating-during" target="_blank" rel="noopener noreferrer" data-fpw-guide-source data-source-org="nws" data-section-id="sources">National Weather Service &mdash; Safe Boating During Weather<span class="fpw-emergency-new-window"> (opens in a new tab)</span></a></li>
              <li><a class="fpw-emergency-official" href="https://www.cdc.gov/carbon-monoxide/about/boating.html" target="_blank" rel="noopener noreferrer" data-fpw-guide-source data-source-org="cdc" data-section-id="sources">CDC &mdash; Carbon Monoxide Poisoning and Boating<span class="fpw-emergency-new-window"> (opens in a new tab)</span></a></li>
              <li><a class="fpw-emergency-official" href="https://www.sarsat.noaa.gov/register-your-beacon/" target="_blank" rel="noopener noreferrer" data-fpw-guide-source data-source-org="noaa" data-section-id="sources">NOAA SARSAT &mdash; Register Your Beacon<span class="fpw-emergency-new-window"> (opens in a new tab)</span></a></li>
              <li><a class="fpw-emergency-official" href="https://www.ecfr.gov/current/title-33/chapter-I/subchapter-S/part-173/subpart-C/section-173.55" target="_blank" rel="noopener noreferrer" data-fpw-guide-source data-source-org="ecfr" data-section-id="sources">33 CFR 173.55 &mdash; Boating accident reports<span class="fpw-emergency-new-window"> (opens in a new tab)</span></a></li>
              <li><a class="fpw-emergency-official" href="https://www.redcross.org/take-a-class/first-aid/performing-first-aid/first-aid-steps" target="_blank" rel="noopener noreferrer" data-fpw-guide-source data-source-org="red_cross" data-section-id="sources">American Red Cross &mdash; First Aid Steps<span class="fpw-emergency-new-window"> (opens in a new tab)</span></a></li>
              <li><a class="fpw-emergency-official" href="https://www.epa.gov/emergency-response/national-response-center" target="_blank" rel="noopener noreferrer" data-fpw-guide-source data-source-org="epa" data-section-id="sources">National Response Center<span class="fpw-emergency-new-window"> (opens in a new tab)</span></a></li>
            </ul>

            <aside class="fpw-emergency-disclaimer" aria-labelledby="editorial-disclaimer-title">
              <h3 id="editorial-disclaimer-title">Editorial disclaimer</h3>
              <p>This U.S.-focused educational guide provides general safety information, not legal, medical, navigation, weather-routing, salvage, or vessel-specific advice. Emergencies vary by boat, waterway, weather, crew, and jurisdiction. Follow current law, the boat/equipment manufacturers&rsquo; instructions, trained responders, and official forecasts/notices. Take an approved boating-safety course and current CPR/AED/first-aid training. Review this guide at least annually and whenever referenced rules or official guidance change.</p>
            </aside>
          </section>

          <div class="fpw-emergency-cta-wrap fpw-emergency-cta-wrap--final">
            <cfscript>
            fpwCtaConfig = {
              "id" = "common-boating-emergencies-final-cta",
              "headline" = "Plan before something goes wrong",
              "supportingText" = "Organize the route, people, boat, contacts, timing, and safety details a responsible person ashore may need.",
              "buttonLabel" = "Create a Float Plan",
              "destinationUrl" = fpwEmergencyCtaSignedIn ? fpwEmergencyBasePath & "/app/dashboard.cfm" : fpwEmergencyBasePath & "/app/join.cfm",
              "ctaType" = "create_float_plan",
              "sourcePage" = "boating_emergencies",
              "section" = "final_cta",
              "authState" = fpwEmergencyCtaSignedIn ? "signed_in" : "signed_out",
              "destinationKey" = fpwEmergencyCtaSignedIn ? "dashboard" : "join",
              "analyticsEvent" = "guide_cta_select",
              "ariaLabel" = "Create a Float Plan after reading the common boating emergencies guide"
            };
            </cfscript>
            <cfinclude template="partials/fpw-action-cta.cfm">
          </div>

          <p class="fpw-emergency-back fpw-emergency-back--final"><a href="#guide-top">Back to top</a></p>
        </div>
      </div>
    </article>
  </div>
</main>

<cfinclude template="includes/footer.cfm">
<script src="<cfoutput>#fpwEmergencyBasePath#</cfoutput>/assets/js/common-boating-emergencies.js?v=20260824-individual-card-pdfs"></script>
</body>
</html>
