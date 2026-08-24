<cfprocessingdirective pageencoding="utf-8">
<cfsetting showdebugoutput="false" requesttimeout="30">
<cfcontent type="text/html; charset=utf-8">

<cfscript>
schemaAtKey = chr(64);
schemaTypeKey = schemaAtKey & "type";
schemaIdKey = schemaAtKey & "id";
schemaContextKey = schemaAtKey & "context";
schemaGraphKey = schemaAtKey & "graph";

function fpwSoloSchemaRef(required string idValue) {
  var out = structNew("ordered");
  structInsert(out, schemaIdKey, arguments.idValue, true);
  return out;
}

function fpwSoloSchemaListItem(required numeric position, required string name, required string urlValue) {
  var out = structNew("ordered");
  var item = structNew("ordered");
  structInsert(out, schemaTypeKey, "ListItem", true);
  out["position"] = arguments.position;
  structInsert(item, schemaIdKey, arguments.urlValue, true);
  item["name"] = arguments.name;
  out["item"] = item;
  return out;
}

fpwSoloBasePath = "";
fpwSoloScriptName = structKeyExists(cgi, "script_name") ? trim(toString(cgi.script_name)) : "";

if (structKeyExists(request, "fpwBase")) {
  fpwSoloBasePath = trim(toString(request.fpwBase));
}

if (!len(fpwSoloBasePath) AND len(fpwSoloScriptName)) {
  fpwSoloBasePath = reReplace(fpwSoloScriptName, "/solo-boating-safety-guide\.cfm$", "");
  if (fpwSoloBasePath EQ fpwSoloScriptName) {
    fpwSoloBasePath = reReplace(getDirectoryFromPath(fpwSoloScriptName), "/$", "");
  }
}

fpwSoloBasePath = reReplace(fpwSoloBasePath, "/$", "");
if (fpwSoloBasePath EQ "/") {
  fpwSoloBasePath = "";
}
if (len(fpwSoloBasePath) AND left(fpwSoloBasePath, 1) NEQ "/") {
  fpwSoloBasePath = "/" & fpwSoloBasePath;
}

request.fpwBase = fpwSoloBasePath;
request.fpwTopNavActive = "resources-solo-boating-guide";

fpwSoloCanonicalUrl = "https://floatplanwizard.com/solo-boating-safety-guide/";
fpwSoloPageTitle = "Solo Boating Safety Guide | Kayaks, Powerboats & Cruisers";
fpwSoloPageDescription = "Practical solo boating safety guidance for kayaks, powerboats, sailboats and cruisers, including float plans, communications, weather, self-rescue and a pre-departure checklist.";
fpwSoloHeadline = "Solo Boating Safety: A Practical Guide from Kayaks to Cruisers";
fpwSoloSocialImage = "https://floatplanwizard.com/assets/images/social/floatplanwizard-social-preview-20260730.png";
fpwSoloPublishedDate = "2026-08-10T11:58:52-04:00";
fpwSoloArticleId = fpwSoloCanonicalUrl & "##article";
fpwSoloWebPageId = fpwSoloCanonicalUrl & "##webpage";
fpwSoloOrganizationId = "https://floatplanwizard.com/##organization";
fpwSoloSchemaGraph = [];
fpwSoloSchemaOrg = structNew("ordered");
fpwSoloSchemaBreadcrumb = structNew("ordered");
fpwSoloSchemaPage = structNew("ordered");
fpwSoloSchemaArticle = structNew("ordered");
fpwSoloJsonLd = structNew("ordered");

structInsert(fpwSoloSchemaOrg, schemaTypeKey, "Organization", true);
structInsert(fpwSoloSchemaOrg, schemaIdKey, fpwSoloOrganizationId, true);
fpwSoloSchemaOrg["name"] = "FloatPlanWizard";
fpwSoloSchemaOrg["url"] = "https://floatplanwizard.com/";
fpwSoloSchemaOrg["logo"] = "https://floatplanwizard.com/assets/images/checkout/floatplanwizard-logo.jpg";
arrayAppend(fpwSoloSchemaGraph, fpwSoloSchemaOrg);

structInsert(fpwSoloSchemaBreadcrumb, schemaTypeKey, "BreadcrumbList", true);
structInsert(fpwSoloSchemaBreadcrumb, schemaIdKey, fpwSoloCanonicalUrl & "##breadcrumb", true);
fpwSoloSchemaBreadcrumb["itemListElement"] = [];
arrayAppend(fpwSoloSchemaBreadcrumb["itemListElement"], fpwSoloSchemaListItem(1, "FloatPlanWizard", "https://floatplanwizard.com/"));
arrayAppend(fpwSoloSchemaBreadcrumb["itemListElement"], fpwSoloSchemaListItem(2, "Solo Boating Safety Guide", fpwSoloCanonicalUrl));
arrayAppend(fpwSoloSchemaGraph, fpwSoloSchemaBreadcrumb);

structInsert(fpwSoloSchemaPage, schemaTypeKey, "WebPage", true);
structInsert(fpwSoloSchemaPage, schemaIdKey, fpwSoloWebPageId, true);
fpwSoloSchemaPage["url"] = fpwSoloCanonicalUrl;
fpwSoloSchemaPage["name"] = fpwSoloPageTitle;
fpwSoloSchemaPage["description"] = fpwSoloPageDescription;
fpwSoloSchemaPage["isPartOf"] = fpwSoloSchemaRef("https://floatplanwizard.com/##website");
fpwSoloSchemaPage["publisher"] = fpwSoloSchemaRef(fpwSoloOrganizationId);
fpwSoloSchemaPage["breadcrumb"] = fpwSoloSchemaRef(fpwSoloCanonicalUrl & "##breadcrumb");
fpwSoloSchemaPage["mainEntity"] = fpwSoloSchemaRef(fpwSoloArticleId);
arrayAppend(fpwSoloSchemaGraph, fpwSoloSchemaPage);

structInsert(fpwSoloSchemaArticle, schemaTypeKey, "Article", true);
structInsert(fpwSoloSchemaArticle, schemaIdKey, fpwSoloArticleId, true);
fpwSoloSchemaArticle["url"] = fpwSoloCanonicalUrl;
fpwSoloSchemaArticle["headline"] = fpwSoloHeadline;
fpwSoloSchemaArticle["description"] = fpwSoloPageDescription;
fpwSoloSchemaArticle["datePublished"] = fpwSoloPublishedDate;
fpwSoloSchemaArticle["dateModified"] = fpwSoloPublishedDate;
fpwSoloSchemaArticle["articleSection"] = "Boating Safety";
fpwSoloSchemaArticle["inLanguage"] = "en";
fpwSoloSchemaArticle["author"] = fpwSoloSchemaRef(fpwSoloOrganizationId);
fpwSoloSchemaArticle["publisher"] = fpwSoloSchemaRef(fpwSoloOrganizationId);
fpwSoloSchemaArticle["mainEntityOfPage"] = fpwSoloSchemaRef(fpwSoloWebPageId);
arrayAppend(fpwSoloSchemaGraph, fpwSoloSchemaArticle);

structInsert(fpwSoloJsonLd, schemaContextKey, "https://schema.org", true);
structInsert(fpwSoloJsonLd, schemaGraphKey, fpwSoloSchemaGraph, true);
fpwSoloJsonLdText = replace(serializeJSON(fpwSoloJsonLd), "</", "<\/", "all");

fpwSoloCtaUserId = 0;
if (structKeyExists(session, "user") AND isStruct(session.user)) {
  for (fpwSoloCtaUserIdKey in [ "userId", "id", "USERID", "ID" ]) {
    if (structKeyExists(session.user, fpwSoloCtaUserIdKey) AND isNumeric(session.user[fpwSoloCtaUserIdKey])) {
      fpwSoloCtaUserId = val(session.user[fpwSoloCtaUserIdKey]);
      break;
    }
  }
}
fpwSoloCtaSignedIn = fpwSoloCtaUserId GT 0;
fpwCtaConfig = {
  "id" = "solo-boating-safety-guide-cta",
  "headline" = "Give someone ashore a clear plan",
  "supportingText" = "Organize your route, timing, vessel details and shore contact before you head out alone.",
  "buttonLabel" = "Plan a Route",
  "destinationUrl" = fpwSoloCtaSignedIn ? fpwSoloBasePath & "/app/dashboard.cfm" : fpwSoloBasePath & "/app/join.cfm",
  "ctaType" = "plan_route",
  "sourcePage" = "solo_boating_safety_guide",
  "section" = "before_checklist",
  "authState" = fpwSoloCtaSignedIn ? "signed_in" : "signed_out",
  "destinationKey" = fpwSoloCtaSignedIn ? "dashboard" : "join",
  "analyticsEvent" = "solo_boating_safety_guide_plan_route_cta_click",
  "ariaLabel" = "Plan a Route with FloatPlanWizard after reading the solo boating safety guide"
};
</cfscript>

<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Solo Boating Safety Guide | Kayaks, Powerboats &amp; Cruisers</title>
  <meta name="description" content="Practical solo boating safety guidance for kayaks, powerboats, sailboats and cruisers, including float plans, communications, weather, self-rescue and a pre-departure checklist.">
  <meta name="robots" content="index,follow">
  <link rel="canonical" href="https://floatplanwizard.com/solo-boating-safety-guide/">
  <meta property="og:type" content="article">
  <meta property="og:site_name" content="FloatPlanWizard">
  <meta property="og:url" content="https://floatplanwizard.com/solo-boating-safety-guide/">
  <meta property="og:title" content="Solo Boating Safety Guide | Kayaks, Powerboats &amp; Cruisers">
  <meta property="og:description" content="Practical solo boating safety guidance for kayaks, powerboats, sailboats and cruisers, including float plans, communications, weather, self-rescue and a pre-departure checklist.">
  <meta property="og:image" content="https://floatplanwizard.com/assets/images/social/floatplanwizard-social-preview-20260730.png">
  <meta property="og:image:secure_url" content="https://floatplanwizard.com/assets/images/social/floatplanwizard-social-preview-20260730.png">
  <meta property="og:image:type" content="image/png">
  <meta property="og:image:width" content="1200">
  <meta property="og:image:height" content="630">
  <meta property="og:image:alt" content="FloatPlanWizard boating trip planning, float-plan sharing, and check-in preview">
  <meta name="twitter:card" content="summary_large_image">
  <meta name="twitter:title" content="Solo Boating Safety Guide | Kayaks, Powerboats &amp; Cruisers">
  <meta name="twitter:description" content="Practical solo boating safety guidance for kayaks, powerboats, sailboats and cruisers, including float plans, communications, weather, self-rescue and a pre-departure checklist.">
  <meta name="twitter:image" content="https://floatplanwizard.com/assets/images/social/floatplanwizard-social-preview-20260730.png">
  <meta name="twitter:image:alt" content="FloatPlanWizard boating trip planning, float-plan sharing, and check-in preview">
  <script type="application/ld+json"><cfoutput>#fpwSoloJsonLdText#</cfoutput></script>
  <cfoutput><link rel="icon" type="image/svg+xml" href="#fpwSoloBasePath#/assets/images/landing/fpw-logo.svg"></cfoutput>
  <cfoutput><link rel="stylesheet" href="#fpwSoloBasePath#/assets/css/layout.css?v=20260620-page-width"></cfoutput>
  <cfoutput><link rel="stylesheet" href="#fpwSoloBasePath#/assets/css/top-nav.css?v=20260824-boating-safety-nav-v2"></cfoutput>
  <cfoutput><link rel="stylesheet" href="#fpwSoloBasePath#/assets/css/fpw-action-cta.css?v=20260804-pilot"></cfoutput>
  <cfoutput><link rel="stylesheet" href="#fpwSoloBasePath#/assets/css/solo-boating-safety-guide.css?v=20260813-ebook"></cfoutput>
  <cfinclude template="includes/analytics_ga4.cfm">
  <cfinclude template="includes/analytics_clarity.cfm">
  <cfinclude template="includes/trustedsite.cfm">
</head>
<body class="fpw-solo-body">
<cfinclude template="includes/top_nav.cfm">

<main class="fpw-solo-page" id="main-content">
  <div class="fpw-solo-shell">
    <nav class="fpw-solo-breadcrumbs" aria-label="Breadcrumb">
      <a href="<cfoutput>#fpwSoloBasePath#</cfoutput>/">FloatPlanWizard</a>
      <span aria-hidden="true">&rsaquo;</span>
      <span aria-current="page">Solo Boating Safety Guide</span>
    </nav>

    <article class="fpw-solo-article" aria-labelledby="fpw-solo-title">
      <header class="fpw-solo-hero">
        <p class="fpw-solo-eyebrow">Boating Safety Guide</p>
        <h1 id="fpw-solo-title">Solo Boating Safety: A Practical Guide from Kayaks to Cruisers</h1>
        <p class="fpw-solo-lede">When you boat alone, there is no second person aboard to take over, call for help, explain your route, or assist with recovery. Good solo-boating preparation therefore emphasizes staying aboard, self-recovery, conservative decision-making, redundant communication, and leaving a useful plan with someone ashore.</p>
      </header>

      <section class="fpw-solo-ebook" aria-labelledby="fpw-solo-ebook-title">
        <div class="fpw-solo-ebook-copy">
          <p class="fpw-solo-eyebrow">Complete Offline Edition</p>
          <h2 id="fpw-solo-ebook-title">Download the Complete Solo Boating Safety E-Book</h2>
          <p>Take the complete guide with you for offline reading.</p>
        </div>
        <div class="fpw-solo-ebook-actions" aria-label="Complete e-book download formats">
          <a class="fpw-solo-ebook-download fpw-solo-ebook-download--primary" href="<cfoutput>#fpwSoloBasePath#</cfoutput>/downloads/floatplanwizard-solo-boating-safety-guide.pdf" download type="application/pdf" aria-label="Download PDF" data-fpw-solo-ebook-download data-fpw-track="solo_boating_ebook_download" data-fpw-track-source-page="solo_boating_safety_guide" data-fpw-track-section="ebook_download" data-fpw-track-document-key="complete_solo_boating_safety_ebook" data-fpw-track-label="Download the Complete Solo Boating Safety E-Book PDF" data-fpw-track-format="pdf"><span class="fpw-solo-ebook-badge" aria-hidden="true">PDF</span><span>Download</span></a>
          <a class="fpw-solo-ebook-download" href="<cfoutput>#fpwSoloBasePath#</cfoutput>/downloads/solo-boating-safety-a-practical-guide.epub" download type="application/epub+zip" aria-label="Download EPUB" data-fpw-solo-ebook-download data-fpw-track="solo_boating_ebook_download" data-fpw-track-source-page="solo_boating_safety_guide" data-fpw-track-section="ebook_download" data-fpw-track-document-key="complete_solo_boating_safety_ebook" data-fpw-track-label="Download the Complete Solo Boating Safety E-Book EPUB" data-fpw-track-format="epub"><span class="fpw-solo-ebook-badge" aria-hidden="true">EPUB</span><span>Download</span></a>
        </div>
      </section>

      <div class="fpw-solo-layout">
        <nav class="fpw-solo-toc" aria-labelledby="fpw-solo-toc-title">
          <h2 id="fpw-solo-toc-title">In this guide</h2>
          <ul>
            <li><a href="#why-solo-boating-is-different">Why solo boating is different</a></li>
            <li><a href="#float-plans-and-shore-contacts">Float plans and shore contacts</a></li>
            <li><a href="#staying-aboard-self-recovery">Staying aboard and self-recovery</a></li>
            <li><a href="#communications-emergency-beacons">Communications and emergency beacons</a></li>
            <li><a href="#weather-cold-water-fatigue">Weather, cold water, and fatigue</a></li>
            <li><a href="#boat-readiness">Boat readiness</a></li>
            <li><a href="#paddlecraft">Paddlecraft</a></li>
            <li><a href="#powerboats">Powerboats</a></li>
            <li><a href="#sailboats-cruisers">Sailboats and cruisers</a></li>
            <li><a href="#changing-plans-tracking">Changing plans and tracking limitations</a></li>
            <li><a href="#solo-boater-checklist">Solo Boater Checklist</a></li>
          </ul>
        </nav>

        <div class="fpw-solo-content">
          <section id="why-solo-boating-is-different" aria-labelledby="why-solo-boating-is-different-title">
            <h2 id="why-solo-boating-is-different-title">Why boating alone changes the safety equation</h2>
            <p>Boating alone can be one of the most rewarding ways to spend time on the water. A quiet paddle, a day of fishing, a solo sail, or a cruise with nobody else&rsquo;s schedule to manage can be exactly what many boaters are looking for.</p>
            <p>It also changes the safety equation.</p>
            <p>When you are alone, there is no second person aboard to:</p>
            <ul>
              <li>take the helm if you become ill or injured</li>
              <li>call for help if you cannot</li>
              <li>help you climb back aboard</li>
              <li>retrieve safety equipment</li>
              <li>handle the boat while you deal with a problem</li>
              <li>explain your intended route if you become overdue</li>
            </ul>
            <p>That does not mean solo boating is inherently unsafe. It means preparation, conservative judgment, self-recovery, communication, and a useful float plan matter even more.</p>
            <p>The goal of this guide is not to tell you whether you should boat alone. It is to help you think through the additional risks and prepare for them. The principles apply across a wide range of recreational craft, from kayaks and small fishing boats to sailboats and cruising boats.</p>
          </section>

          <section id="float-plans-and-shore-contacts" aria-labelledby="float-plans-and-shore-contacts-title">
            <h2 id="float-plans-and-shore-contacts-title">Float plans and shore contacts</h2>

            <h3>Leave a float plan every time you boat alone</h3>
            <p>A float plan is one of the most useful safety measures available to a solo boater. <a class="fpw-solo-official-link" href="https://uscgboating.org/recreational-boaters/floating-plan.php" target="_blank" rel="noopener noreferrer">U.S. Coast Guard recreational-boating guidance</a> recommends completing a float plan and leaving it with a responsible person when getting underway.</p>
            <p>For a solo boater, that person ashore may be the only person who knows:</p>
            <ul>
              <li>where you launched or departed</li>
              <li>what boat or craft you are using</li>
              <li>where you intended to go</li>
              <li>which route you expected to follow</li>
              <li>where you might stop</li>
              <li>when you expected to return</li>
              <li>when you planned to check in</li>
              <li>what communications equipment you have</li>
              <li>when a missed check-in should become a concern</li>
            </ul>
            <p>A useful solo-boating float plan should include, as applicable:</p>
            <ul class="fpw-solo-columns">
              <li>your name and contact information</li>
              <li>vessel or craft name</li>
              <li>vessel type</li>
              <li>make and model</li>
              <li>length</li>
              <li>hull color and identifying features</li>
              <li>registration or documentation number</li>
              <li>a current photo of the vessel or craft</li>
              <li>launch ramp, marina, dock, beach, or departure location</li>
              <li>vehicle and trailer information when relevant</li>
              <li>departure date and time</li>
              <li>planned route</li>
              <li>planned destinations and stops</li>
              <li>expected return or arrival time</li>
              <li>check-in expectations</li>
              <li>an agreed overdue threshold</li>
              <li>communication methods</li>
              <li>relevant safety equipment</li>
              <li>emergency contacts</li>
              <li>reasonable alternate destinations or route changes</li>
            </ul>
            <p>The Coast Guard recommends providing a vessel photo because similar-looking boats can otherwise be difficult to distinguish. Learn more about <a href="<cfoutput>#fpwSoloBasePath#</cfoutput>/why-use-a-float-plan/">why and when to use a float plan</a>.</p>

            <h4>Tell your shore contact when the trip is over</h4>
            <p>A float plan should not remain open after you are safely home. Contact the person holding your plan when:</p>
            <ul>
              <li>you return</li>
              <li>you arrive at your destination</li>
              <li>you intentionally end the trip somewhere different</li>
              <li>somebody else has taken over responsibility for your plan</li>
            </ul>
            <p>A shore contact should never have to wonder whether you forgot to close the plan or whether you are actually overdue.</p>

            <aside class="fpw-solo-callout" role="note" aria-label="Float plan reminder">
              <strong>Boating alone? Leave the plan with someone who understands the trip and knows what to do if you are overdue.</strong>
            </aside>

            <h3>Choose the right shore contact</h3>
            <p>Do not leave your float plan with someone who is unlikely to notice a missed check-in.</p>
            <p>Choose someone who:</p>
            <ul>
              <li>understands that they are your shore contact</li>
              <li>agrees to pay attention to the trip</li>
              <li>knows when you expect to check in or return</li>
              <li>understands what you want them to do if you are overdue</li>
              <li>can access the information you gave them</li>
              <li>is likely to answer the phone if authorities need additional information</li>
            </ul>
            <p>Make sure the person understands the plan before you leave. A float plan sitting unread in someone&rsquo;s inbox is not as useful as a plan held by someone who understands their role.</p>
            <p class="fpw-solo-context-link"><strong>Share this companion guide:</strong> <a href="<cfoutput>#fpwSoloBasePath#</cfoutput>/shore-contact-overdue-boater/">What a Shore Contact Should Do When a Boater Is Overdue</a>.</p>

            <h3>Agree on check-ins and what &ldquo;overdue&rdquo; means</h3>
            <p>Avoid vague instructions such as:</p>
            <blockquote>&ldquo;If I&rsquo;m not back sometime tonight, maybe start worrying.&rdquo;</blockquote>
            <p>Agree on clear expectations before departure. For example:</p>
            <div class="fpw-solo-example-grid">
              <div>
                <h4>Expected return</h4>
                <p>&ldquo;I expect to be back around 5:00 PM.&rdquo;</p>
              </div>
              <div>
                <h4>Planned check-in</h4>
                <p>&ldquo;I expect to message you when I reach the island around noon.&rdquo;</p>
              </div>
              <div>
                <h4>Overdue threshold</h4>
                <p>&ldquo;If you have not heard from me by 6:00 PM and cannot reach me, follow the overdue instructions we discussed.&rdquo;</p>
              </div>
            </div>
            <p>These are examples only. Do not establish a universal waiting period. The appropriate timing depends on:</p>
            <ul class="fpw-solo-columns">
              <li>trip type</li>
              <li>vessel</li>
              <li>environment</li>
              <li>weather</li>
              <li>remoteness</li>
              <li>communications</li>
              <li>the boater</li>
              <li>known medical considerations</li>
              <li>other circumstances</li>
            </ul>
            <p>The shore contact should also understand that an agreed overdue time does <strong>not</strong> mean they should ignore evidence of immediate danger. A distress call, emergency message, severe-weather concern, known medical emergency, or other credible indication of immediate risk may justify action before the planned overdue threshold.</p>
          </section>

          <section id="staying-aboard-self-recovery" aria-labelledby="staying-aboard-self-recovery-title">
            <h2 id="staying-aboard-self-recovery-title">Staying aboard and self-recovery</h2>

            <h3>Wear your life jacket</h3>
            <p>Carrying a life jacket and wearing one are not the same thing.</p>
            <p>Federal and state PFD requirements vary based on vessel, activity, age, location, and jurisdiction. This guide does not imply that every adult is legally required to wear a PFD at all times on every recreational vessel.</p>
            <p>However, <a class="fpw-solo-official-link" href="https://www.uscgboating.org/recreational-boaters/life-jacket-wear-wearing-your-life-jacket.php" target="_blank" rel="noopener noreferrer">U.S. Coast Guard life-jacket guidance</a> recommends wearing an approved life jacket while underway because an emergency may not leave enough time to retrieve and put one on.</p>
            <p>For someone boating alone, FPW&rsquo;s best-practice recommendation is straightforward:</p>
            <blockquote><strong>Wear an appropriate life jacket while underway when boating alone.</strong></blockquote>
            <p>If you unexpectedly enter the water, there may be no one aboard to throw you flotation or maneuver back toward you.</p>
            <p>Choose a PFD appropriate for:</p>
            <ul>
              <li>the activity</li>
              <li>water conditions</li>
              <li>expected environment</li>
              <li>clothing</li>
              <li>operating position</li>
            </ul>
            <p>For paddlecraft and cold-water use, make sure the equipment is appropriate for the activity and immersion risk.</p>

            <h3>Plan around the possibility of falling overboard</h3>
            <p>A solo boater should think seriously about one question:</p>
            <aside class="fpw-solo-callout fpw-solo-callout--overboard" role="note" aria-label="Overboard self-recovery question">
              <strong>Ask yourself before departure: If I enter the water, can I get back aboard without help?</strong>
            </aside>
            <p>Do not assume the answer is yes. Consider:</p>
            <ul class="fpw-solo-columns">
              <li>freeboard</li>
              <li>hull shape</li>
              <li>ladder placement</li>
              <li>swim platform design</li>
              <li>clothing</li>
              <li>water temperature</li>
              <li>fatigue</li>
              <li>waves</li>
              <li>wind</li>
              <li>current</li>
              <li>physical condition</li>
            </ul>
            <p>A boarding ladder is useful only if you can reach and deploy it from the water. A swim platform is useful only if you can actually climb onto it. A kayak rescue technique is useful only if you know how to perform it.</p>

            <h4>Practice self-recovery</h4>
            <p>Where practical and safe, practice the method appropriate to your boat or craft under controlled conditions.</p>
            <p>For a powerboat or cruiser, test whether:</p>
            <ul>
              <li>the ladder can be reached</li>
              <li>the ladder can be deployed from the water</li>
              <li>you can climb aboard wearing typical boating clothing</li>
              <li>safety gear or cockpit covers interfere with reboarding</li>
            </ul>
            <p>For a paddlecraft, learn and practice the relevant:</p>
            <ul>
              <li>capsize recovery</li>
              <li>self-rescue</li>
              <li>re-entry</li>
              <li>assisted rescue techniques where appropriate</li>
            </ul>
            <p>Training should match the specific craft. The first time you discover that you cannot climb back aboard should not be during an emergency.</p>

            <h3>Keep critical emergency equipment with you</h3>
            <p>Ask: <strong>If I become separated from the boat, what safety equipment will still be with me?</strong></p>
            <p>A cellphone stored inside the cabin does not help much if you are in the water beside an unmanned boat drifting away. The same applies to:</p>
            <ul>
              <li>handheld VHF</li>
              <li>PLB</li>
              <li>whistle</li>
              <li>signaling equipment</li>
              <li>waterproof light</li>
            </ul>
            <p>Not every piece of equipment must physically be worn, but a solo boater should deliberately consider what remains available after separation from the vessel.</p>
            <p>Where appropriate, keep essential personal distress and communications equipment:</p>
            <ul>
              <li>attached to your PFD</li>
              <li>on your body</li>
              <li>in a waterproof pocket</li>
              <li>otherwise immediately accessible</li>
            </ul>
            <p>Do not assume that equipment stored aboard guarantees access after an overboard event.</p>

            <h3>Prevent the boat from leaving without you</h3>
            <p>This is particularly important on powered vessels. An operator who falls from a moving boat can face two problems at once:</p>
            <ol>
              <li>being in the water</li>
              <li>watching the boat continue away under power</li>
            </ol>
            <p>Engine cut-off systems are designed to stop propulsion when the operator is displaced from the controls.</p>
            <p>Federal engine cut-off switch requirements apply to certain recreational vessels and operating situations. This is not a statement that every boat in every circumstance is legally required to use one. Review the <a class="fpw-solo-official-link" href="https://uscgboating.org/recreational-boaters/engine-cut-off-switch-faq.php" target="_blank" rel="noopener noreferrer">U.S. Coast Guard Engine Cut-Off Devices guidance</a> for the current federal scope.</p>
            <p>For boats equipped with an engine cut-off system:</p>
            <ul>
              <li>understand how it works</li>
              <li>verify it functions before departure</li>
              <li>use it where required</li>
              <li>consider it an important solo-operating precaution whenever its use is appropriate</li>
            </ul>
            <p>A stopped boat is generally much easier to recover than a runaway boat.</p>
          </section>

          <section id="communications-emergency-beacons" aria-labelledby="communications-emergency-beacons-title">
            <h2 id="communications-emergency-beacons-title">Communications and emergency beacons</h2>

            <h3>Build redundant communication</h3>
            <p>Do not depend on one communication method.</p>
            <p>Cellphones are extremely useful, but coverage can disappear quickly on the water. Battery failure, water intrusion, antenna limitations, terrain, distance from shore, or network problems can make any single system unavailable.</p>
            <p>A solo-boating communications plan might include, depending on the vessel and voyage:</p>
            <ul class="fpw-solo-columns">
              <li>waterproof cellphone</li>
              <li>fixed marine VHF</li>
              <li>waterproof handheld VHF</li>
              <li>DSC-capable marine radio</li>
              <li>PLB</li>
              <li>EPIRB</li>
              <li>whistle</li>
              <li>sound-signaling equipment</li>
              <li>visual distress signals</li>
              <li>waterproof light</li>
            </ul>
            <p>The appropriate combination depends on the trip.</p>

            <h3>Understand marine VHF and Channel 16</h3>
            <p>For boats equipped with marine VHF, the operator should understand how to use it before an emergency.</p>
            <p>VHF Channel 16 is used internationally for distress, safety, and calling. A solo boater carrying VHF should know how to:</p>
            <ul>
              <li>select Channel 16</li>
              <li>make a distress call</li>
              <li>state the vessel name</li>
              <li>state the nature of distress</li>
              <li>provide position information</li>
              <li>describe the vessel</li>
              <li>state the number of persons aboard</li>
              <li>listen for instructions</li>
            </ul>
            <p>Do not wait for an emergency to learn where the transmit button is or how the radio menus work. A handheld waterproof VHF can provide useful backup redundancy where appropriate. See the Coast Guard Navigation Center&rsquo;s <a class="fpw-solo-official-link" href="https://navcen.uscg.gov/radio-information-for-boaters" target="_blank" rel="noopener noreferrer">Radio Information for Boaters</a>.</p>

            <h3>Configure DSC correctly</h3>
            <p>Digital Selective Calling can improve distress communications on properly configured marine radios.</p>
            <p>A DSC-capable radio may be able to send identifying and position information with a distress alert. But the system is only as useful as its configuration.</p>
            <p>Where applicable:</p>
            <ul>
              <li>obtain the appropriate MMSI</li>
              <li>program it correctly</li>
              <li>connect compatible position information where required by the installation</li>
              <li>understand the distress function</li>
              <li>verify the installation</li>
            </ul>
            <p>Simply owning a DSC radio does not guarantee that responders receive complete vessel and position information.</p>

            <h3>Understand PLBs and EPIRBs</h3>
            <p>406 MHz emergency beacons can provide another layer of emergency communication.</p>
            <h4>PLB</h4>
            <p>A Personal Locator Beacon is intended to be personally carried and manually activated. For solo boaters, one of its major practical advantages is that it can remain with the person if that person becomes separated from the vessel.</p>
            <h4>EPIRB</h4>
            <p>An Emergency Position Indicating Radio Beacon is designed primarily as a maritime vessel distress beacon. Depending on the unit and installation, an EPIRB may be manually or automatically activated.</p>
            <h4>Registration matters</h4>
            <p>NOAA&rsquo;s U.S. beacon-registration system associates registered beacon information with emergency contacts and other data useful to search-and-rescue authorities. <a class="fpw-solo-official-link" href="https://beaconregistration.noaa.gov/RGDB/index" target="_blank" rel="noopener noreferrer">NOAA beacon registration</a> is free and should be kept current.</p>
            <blockquote>A beacon can greatly improve your ability to signal distress, but it does not remove the need for sound trip planning, appropriate equipment, weather judgment, or a shore contact.</blockquote>
          </section>

          <section id="weather-cold-water-fatigue" aria-labelledby="weather-cold-water-fatigue-title">
            <h2 id="weather-cold-water-fatigue-title">Weather, cold water, and fatigue</h2>

            <h3>Treat weather as a solo go/no-go decision</h3>
            <p>Weather should not be a box you check after deciding to go. It should be part of the decision about whether the trip happens at all.</p>
            <p>Before departure, review appropriate forecasts and conditions for:</p>
            <ul class="fpw-solo-columns">
              <li>wind</li>
              <li>gusts</li>
              <li>waves or seas</li>
              <li>thunderstorms</li>
              <li>visibility</li>
              <li>fog</li>
              <li>precipitation</li>
              <li>air temperature</li>
              <li>water temperature</li>
              <li>tides</li>
              <li>currents</li>
              <li>daylight</li>
              <li>marine advisories and warnings</li>
            </ul>
            <p>Look at conditions for the <strong>entire planned route and time period</strong>, not merely conditions at the launch ramp. Use <a href="<cfoutput>#fpwSoloBasePath#</cfoutput>/app/weather.cfm">FPW Marine Weather</a> alongside current official <a class="fpw-solo-official-link" href="https://www.weather.gov/marine/" target="_blank" rel="noopener noreferrer">NOAA/NWS marine forecasts and warnings</a>.</p>
            <p>A solo boater should consider using a larger safety margin than when competent crew are aboard.</p>
            <aside class="fpw-solo-callout fpw-solo-callout--weather" role="note" aria-label="Solo weather margin reminder">
              <strong>A forecast that is acceptable with experienced crew aboard may not be a forecast you choose to handle alone.</strong>
            </aside>
            <p>This is an FPW best-practice principle, not an agency regulation. This guide does not establish universal numerical limits for wind, gusts, wave height, current, or visibility. Different craft and operators have dramatically different limitations.</p>
            <p>The correct question is: <strong>Are the forecast conditions comfortably within the limits of this boat, this operator, and this solo trip?</strong></p>

            <h3>Know your personal limits before departure</h3>
            <p>Do not decide your limit after conditions deteriorate.</p>
            <p>Before leaving, determine what would cause you to:</p>
            <ul>
              <li>shorten the trip</li>
              <li>choose a protected alternative</li>
              <li>return early</li>
              <li>seek shelter</li>
              <li>cancel altogether</li>
            </ul>
            <p>Factors might include:</p>
            <ul class="fpw-solo-columns">
              <li>increasing wind</li>
              <li>thunderstorms developing sooner than expected</li>
              <li>unexpected sea conditions</li>
              <li>equipment trouble</li>
              <li>fatigue</li>
              <li>illness</li>
              <li>loss of communications</li>
              <li>navigation problems</li>
              <li>reduced visibility</li>
              <li>insufficient daylight</li>
              <li>fuel concerns</li>
            </ul>
            <p>There is no shame in turning around. A float plan is <strong>not a contract requiring you to complete the planned route</strong>. If you change the plan, tell your shore contact as soon as reasonably possible.</p>

            <h3>Cold water changes the risk</h3>
            <p>Air temperature alone does not tell you whether the water is safe.</p>
            <p>Cold-water immersion can rapidly affect:</p>
            <ul>
              <li>breathing</li>
              <li>coordination</li>
              <li>swimming ability</li>
              <li>judgment</li>
              <li>strength</li>
              <li>ability to self-rescue</li>
            </ul>
            <p>This deserves particular emphasis for kayaks, canoes, SUPs, dinghies, small open boats, shoulder-season boating, and northern waters.</p>
            <p>Consider:</p>
            <ul class="fpw-solo-columns">
              <li>water temperature</li>
              <li>exposure time</li>
              <li>distance from safe landing</li>
              <li>wind</li>
              <li>waves</li>
              <li>clothing</li>
              <li>PFD</li>
              <li>immersion protection</li>
              <li>rescue ability</li>
            </ul>
            <p>For paddling in cold water, activity-appropriate wetsuit or drysuit protection may be appropriate depending on conditions. This guide does not invent a universal water-temperature threshold. The National Park Service&rsquo;s <a class="fpw-solo-official-link" href="https://www.nps.gov/thingstodo/kayaking-and-kayak-safety.htm" target="_blank" rel="noopener noreferrer">kayaking and kayak-safety guidance</a> provides useful craft- and location-specific context.</p>

            <h3>Manage fatigue before it becomes a safety problem</h3>
            <p>Operating a boat can be tiring even when the trip does not feel physically demanding.</p>
            <p>Sun, wind, vibration, heat, cold, noise, spray, motion, concentration, and constant balance can contribute to fatigue.</p>
            <blockquote>When boating alone, there is no second helmsperson to give you a break.</blockquote>
            <p>Plan accordingly. Before and during the trip:</p>
            <ul>
              <li>start rested</li>
              <li>eat appropriately</li>
              <li>stay hydrated</li>
              <li>protect yourself from sun and weather</li>
              <li>schedule realistic breaks</li>
              <li>avoid an unnecessarily aggressive schedule</li>
              <li>shorten the trip when concentration starts to decline</li>
              <li>do not let an ETA pressure you into continuing unsafely</li>
            </ul>
            <p>Long-distance solo sailors and cruisers face additional fatigue-management challenges, but even a few hours on a small boat can produce significant fatigue.</p>

            <h3>Alcohol and solo boating do not mix well</h3>
            <p>Alcohol affects judgment, balance, coordination, and reaction time. Those impairments matter on any boat. They matter even more when there is nobody else aboard who can safely take over.</p>
            <p>FPW strongly recommends avoiding alcohol while operating a boat alone. This guide is about safe solo operation, not a comprehensive boating-under-the-influence law reference.</p>
          </section>

          <section id="boat-readiness" aria-labelledby="boat-readiness-title">
            <h2 id="boat-readiness-title">Boat or craft readiness</h2>

            <h3>Check the boat or craft before departure</h3>
            <p>A solo boater has fewer options once something goes wrong underway. Perform an appropriate pre-departure check.</p>

            <div class="fpw-solo-readiness-grid">
              <section>
                <h4>Propulsion</h4>
                <ul>
                  <li>engine</li>
                  <li>motor</li>
                  <li>paddle</li>
                  <li>sails and rigging</li>
                  <li>spare propulsion where appropriate</li>
                </ul>
              </section>
              <section>
                <h4>Fuel and power</h4>
                <ul>
                  <li>fuel quantity</li>
                  <li>reasonable fuel reserve</li>
                  <li>batteries</li>
                  <li>charging</li>
                  <li>electrical systems</li>
                </ul>
              </section>
              <section>
                <h4>Steering and control</h4>
                <ul>
                  <li>steering</li>
                  <li>throttle</li>
                  <li>shift controls</li>
                  <li>rudder</li>
                  <li>tiller</li>
                  <li>control cables</li>
                  <li>engine cut-off system</li>
                </ul>
              </section>
              <section>
                <h4>Water management</h4>
                <ul>
                  <li>bilge pumps</li>
                  <li>drain plugs</li>
                  <li>cockpit drains</li>
                  <li>scuppers</li>
                  <li>manual dewatering equipment where appropriate</li>
                </ul>
              </section>
              <section>
                <h4>Navigation</h4>
                <ul>
                  <li>chartplotter</li>
                  <li>charts</li>
                  <li>compass</li>
                  <li>backup navigation appropriate for the trip</li>
                  <li>navigation lights if they may be required</li>
                </ul>
              </section>
              <section>
                <h4>Safety</h4>
                <ul>
                  <li>PFD</li>
                  <li>fire extinguishing equipment where applicable</li>
                  <li>sound signaling</li>
                  <li>visual distress signals where required or carried</li>
                  <li>first aid</li>
                  <li>anchor and ground tackle where appropriate</li>
                  <li>communications equipment</li>
                  <li>reboarding equipment</li>
                </ul>
              </section>
            </div>
            <p>Legal equipment requirements vary by vessel, size, use, location, and jurisdiction. This is not an exhaustive regulatory chart. Review authoritative <a class="fpw-solo-official-link" href="https://www.uscgboating.org/regulations/index.php" target="_blank" rel="noopener noreferrer">U.S. Coast Guard federal and state boating requirements</a>.</p>

            <h3>Consider a Vessel Safety Check</h3>
            <p>For eligible recreational boats, the U.S. Coast Guard Auxiliary and America&rsquo;s Boating Club programs provide free Vessel Safety Checks.</p>
            <p>A Vessel Safety Check can help identify:</p>
            <ul>
              <li>missing required equipment</li>
              <li>equipment condition issues</li>
              <li>potential safety concerns</li>
              <li>areas where the operator may want additional equipment or preparation</li>
            </ul>
            <p>This is particularly useful to a solo boater because no second crewmember will compensate for missing or inaccessible equipment. Learn about the <a class="fpw-solo-official-link" href="https://www.cgaux.org/vsc/" target="_blank" rel="noopener noreferrer">U.S. Coast Guard Auxiliary Vessel Safety Check program</a>.</p>
          </section>

          <section id="paddlecraft" aria-labelledby="paddlecraft-title">
            <h2 id="paddlecraft-title">Solo kayaking, canoeing, and paddlecraft</h2>
            <p>Do not treat paddlecraft like small versions of cabin cruisers. Their risk profile is different.</p>
            <p>A solo paddler should pay particular attention to:</p>

            <h3>Wear the PFD</h3>
            <p>Wear an appropriate PFD rather than merely carrying one.</p>

            <h3>Dress for the water</h3>
            <p>Cold water can become dangerous even on a warm day. Consider appropriate immersion protection.</p>

            <h3>Practice capsize and self-rescue skills</h3>
            <p>Know what happens if the craft overturns. Practice the recovery technique appropriate to the craft and conditions.</p>

            <h3>Protect communications from water</h3>
            <p>A phone that becomes unusable after a capsize is not a reliable emergency system.</p>

            <h3>Carry signaling equipment on your person</h3>
            <p>Depending on conditions and location, this may include:</p>
            <ul>
              <li>whistle</li>
              <li>waterproof light</li>
              <li>phone</li>
              <li>PLB</li>
              <li>other appropriate signaling equipment</li>
            </ul>

            <h3>Know exactly where you launched</h3>
            <p>Give the shore contact:</p>
            <ul>
              <li>launch name</li>
              <li>access point</li>
              <li>parking area</li>
              <li>planned route</li>
              <li>destination</li>
              <li>expected return</li>
              <li>vehicle information where relevant</li>
            </ul>

            <h3>Plan escape options</h3>
            <p>Consider places along the route where you can:</p>
            <ul>
              <li>safely land</li>
              <li>get out of wind</li>
              <li>shorten the trip</li>
              <li>seek assistance</li>
            </ul>

            <h3>Understand wind and current</h3>
            <p>For paddlecraft, moderate-looking conditions can create major difficulty when paddling against:</p>
            <ul>
              <li>current</li>
              <li>tidal flow</li>
              <li>offshore wind</li>
              <li>building waves</li>
            </ul>
            <p>There is no universal numerical threshold that makes conditions safe for every solo paddler, craft, location, and route.</p>
          </section>

          <section id="powerboats" aria-labelledby="powerboats-title">
            <h2 id="powerboats-title">Solo operation of small powerboats</h2>
            <p>Small fishing boats, center consoles, skiffs, runabouts, and similar craft introduce different solo concerns.</p>

            <h3>Engine cutoff</h3>
            <p>Use the engine cut-off system where required and whenever appropriately equipped for the operating situation.</p>

            <h3>Stay aboard</h3>
            <p>Avoid unnecessary movement while underway. Arrange frequently needed equipment so you do not repeatedly leave the operating position.</p>

            <h3>Reboarding</h3>
            <p>Know whether you can climb back aboard. A high-sided boat with no usable ladder can be surprisingly difficult to enter from the water.</p>

            <h3>Communications</h3>
            <p>Keep at least one useful emergency communication method accessible if separated from the vessel.</p>

            <h3>Fuel</h3>
            <p>Plan fuel needs conservatively and maintain an appropriate reserve. FPW&rsquo;s <a href="<cfoutput>#fpwSoloBasePath#</cfoutput>/boat-fuel-calculator/">Boat Fuel Calculator</a> can help with estimates, but calculator results do not replace the captain&rsquo;s responsibility for real-world fuel planning.</p>

            <h3>Anchor readiness</h3>
            <p>On waters where anchoring is appropriate, an accessible anchor may provide another way to prevent the boat from drifting into increasing danger after propulsion problems.</p>
          </section>

          <section id="sailboats-cruisers" aria-labelledby="sailboats-cruisers-title">
            <h2 id="sailboats-cruisers-title">Solo sailing</h2>
            <p>Solo sailing combines ordinary boating risks with additional demands involving sail handling, deck movement, and workload.</p>

            <h3>Reef early</h3>
            <p>Reducing sail before conditions become difficult is generally easier and safer than waiting until the boat is already overpowered. There is no universal reefing wind speed appropriate to every vessel, rig, operator, and condition.</p>

            <h3>Minimize unnecessary deck work</h3>
            <p>Prepare systems so common tasks can be completed with the least unnecessary movement away from a secure operating position.</p>

            <h3>Prevent going overboard</h3>
            <p>Depending on the vessel, conditions, deck layout, and offshore exposure, appropriate measures may include:</p>
            <ul>
              <li>suitable PFD</li>
              <li>harness</li>
              <li>tether</li>
              <li>jacklines</li>
              <li>secure attachment points</li>
            </ul>
            <p>The <a class="fpw-solo-official-link" href="https://www.sailing.org/inside-world-sailing/rules-regulations/offshore-special-regulations/" target="_blank" rel="noopener noreferrer">World Sailing Offshore Special Regulations</a> are an offshore and racing safety reference, not universal U.S. recreational law.</p>

            <h3>Understand autopilot limitations</h3>
            <p>An autopilot is useful equipment. It is not a crewmember.</p>
            <p>It cannot:</p>
            <ul>
              <li>maintain a lookout</li>
              <li>detect every hazard</li>
              <li>respond to a medical emergency</li>
              <li>recover you from the water</li>
            </ul>
            <p>An autopilot does not make solo sailing equivalent to having another person aboard.</p>
          </section>

          <section id="solo-cruisers" aria-labelledby="solo-cruisers-title">
            <h2 id="solo-cruisers-title">Solo cruising and larger recreational boats</h2>
            <p>Larger cruisers provide more shelter and equipment, but size does not eliminate solo-operating problems. In some ways, it creates new ones.</p>
            <p>A solo cruiser may need to manage navigation, helm, engine monitoring, radios, lines, fenders, anchoring, docking, electrical systems, weather, and fatigue without assistance.</p>

            <h3>Prepare before close maneuvering</h3>
            <p>Before approaching a marina, lock, dock, or anchorage:</p>
            <ul>
              <li>prepare lines</li>
              <li>prepare fenders</li>
              <li>organize equipment</li>
              <li>identify the intended maneuver</li>
              <li>reduce unnecessary last-second deck movement</li>
            </ul>

            <h3>Consider reboarding from high freeboard</h3>
            <p>Many cruising boats are difficult to board from the water without a properly designed ladder or platform. Test the system.</p>

            <h3>Communications redundancy</h3>
            <p>Depending on the trip, a cruiser may reasonably carry combinations of:</p>
            <ul>
              <li>fixed VHF</li>
              <li>handheld VHF</li>
              <li>cellphone</li>
              <li>DSC</li>
              <li>PLB</li>
              <li>EPIRB</li>
            </ul>

            <h3>Think about propulsion failure</h3>
            <p>Depending on voyage type, preparation may include:</p>
            <ul>
              <li>anchor readiness</li>
              <li>towing information</li>
              <li>basic spare parts</li>
              <li>tools</li>
              <li>backup navigation</li>
              <li>emergency steering considerations for longer voyages</li>
            </ul>
            <p>Keep preparation proportional to recreational coastal, inland, Great Lakes, Intracoastal Waterway, river, and similar cruising.</p>
          </section>

          <section id="changing-plans-tracking" aria-labelledby="changing-plans-tracking-title">
            <h2 id="changing-plans-tracking-title">Make route changes part of the plan</h2>
            <p>Plans change on the water. Weather shifts. A marina is full. A lock closes. A paddler turns around early. An anchorage is uncomfortable. A mechanical issue forces a different destination.</p>
            <p>Changing the plan is not a failure. Failing to tell the person relying on the old plan can create confusion.</p>
            <p>When practical, notify your shore contact when you:</p>
            <ul>
              <li>substantially change route</li>
              <li>change destination</li>
              <li>stop somewhere unexpected</li>
              <li>delay your return</li>
              <li>return early</li>
              <li>abandon the trip</li>
            </ul>
            <p>The shore contact should know which information is still current.</p>
          </section>

          <section id="tracking-limitations" aria-labelledby="tracking-limitations-title">
            <h2 id="tracking-limitations-title">Do not depend on continuous tracking</h2>
            <p>Technology can provide useful information. Depending on equipment and services, a shore contact may receive:</p>
            <ul>
              <li>messages</li>
              <li>check-ins</li>
              <li>GPS-bearing reports</li>
              <li>estimated progress</li>
              <li>follow-page updates</li>
              <li>beacon information during an emergency</li>
            </ul>
            <p>None of that means a recreational trip should be treated as continuously and infallibly tracked. Coverage, devices, and batteries can fail. A projected route position is not the same as a confirmed current vessel position.</p>
            <aside class="fpw-solo-callout fpw-solo-callout--tracking" role="note" aria-labelledby="tracking-callout-title">
              <h3 id="tracking-callout-title">Tracking has limits</h3>
              <p><strong>Do not treat an estimated or last reported position as a guaranteed current location.</strong></p>
              <ul>
                <li><strong>Reported positions</strong> are reports.</li>
                <li><strong>Estimated progress</strong> is an estimate.</li>
                <li>FPW does not guarantee continuous tracking.</li>
                <li>FPW does not verify distress.</li>
                <li>FPW does not dispatch emergency assistance.</li>
              </ul>
            </aside>
            <p>The float plan and shore-contact relationship remain important even when electronic tracking tools are available.</p>
          </section>

          <section id="what-fpw-can-help-organize" aria-labelledby="what-fpw-can-help-organize-title">
            <h2 id="what-fpw-can-help-organize-title">What FloatPlanWizard can help organize</h2>
            <p>FloatPlanWizard can help a boater organize trip information before departure, including appropriate:</p>
            <ul>
              <li>vessel details</li>
              <li>operator information</li>
              <li>passenger information when applicable</li>
              <li>shore contact</li>
              <li>route</li>
              <li>departure</li>
              <li>destination</li>
              <li>planned timing</li>
              <li>stops</li>
              <li>float-plan information</li>
              <li>trip sharing</li>
            </ul>
            <blockquote>Make sure somebody ashore has enough useful information to recognize when your trip is no longer going according to plan and to provide known facts if help is needed.</blockquote>
            <p>FPW does not replace sound judgment, appropriate safety equipment, marine communications, weather planning, seamanship, or emergency authorities. See <a href="<cfoutput>#fpwSoloBasePath#</cfoutput>/how-it-works/">How FloatPlanWizard Works</a> for its planning and sharing workflow.</p>
          </section>

          <div class="fpw-solo-cta-wrap">
            <cfinclude template="partials/fpw-action-cta.cfm">
          </div>

          <section id="solo-boater-checklist" class="fpw-solo-checklist-section" aria-labelledby="solo-boater-checklist-title">
            <h2 id="solo-boater-checklist-title">Solo Boater Pre-Departure Checklist</h2>
            <p>Use these checklists before departure. The complete checklist is built into this page and does not require an account, download, or JavaScript.</p>
            <div class="fpw-solo-checklist-grid">
              <section aria-labelledby="solo-checklist-trip-plan">
                <h3 id="solo-checklist-trip-plan">Trip plan</h3>
                <p class="fpw-solo-checklist-why"><strong>Why it matters:</strong> When you boat alone, somebody ashore may be the only person who knows your intended route and return time. A clear plan gives that person useful facts if you become overdue.</p>
                <a class="fpw-solo-pdf-download" href="<cfoutput>#fpwSoloBasePath#</cfoutput>/downloads/solo-boater-trip-planning-guide.pdf" download type="application/pdf" data-fpw-solo-pdf-download data-fpw-track="solo_boating_trip_planning_pdf_download" data-fpw-track-source-page="solo_boating_safety_guide" data-fpw-track-section="trip_plan" data-fpw-track-document-key="trip_planning" data-fpw-track-label="Download the Trip Planning Reference PDF"><span class="fpw-solo-pdf-badge" aria-hidden="true">PDF</span><span>Download the Trip Planning Reference PDF</span></a>
                <ul class="fpw-solo-checklist">
                  <li><label><input type="checkbox"><span>I have identified my exact launch or departure point.</span></label></li>
                  <li><label><input type="checkbox"><span>My planned route is recorded.</span></label></li>
                  <li><label><input type="checkbox"><span>My intended destination is recorded.</span></label></li>
                  <li><label><input type="checkbox"><span>Important planned stops are recorded.</span></label></li>
                  <li><label><input type="checkbox"><span>My expected return or arrival time is recorded.</span></label></li>
                  <li><label><input type="checkbox"><span>I have identified reasonable alternate destinations or safe stopping points.</span></label></li>
                  <li><label><input type="checkbox"><span>My shore contact knows how I will report a change of plans.</span></label></li>
                  <li><label><input type="checkbox"><span>We have agreed on check-in expectations.</span></label></li>
                  <li><label><input type="checkbox"><span>We have agreed on when I should be considered overdue.</span></label></li>
                  <li><label><input type="checkbox"><span>My shore contact knows what to do if I am overdue.</span></label></li>
                  <li><label><input type="checkbox"><span>My shore contact has access to the <a href="<cfoutput>#fpwSoloBasePath#</cfoutput>/shore-contact-overdue-boater/">FPW Shore Contact Guide</a>.</span></label></li>
                  <li><label><input type="checkbox"><span>I will tell my shore contact when the trip is safely complete.</span></label></li>
                </ul>
              </section>

              <section aria-labelledby="solo-checklist-vessel">
                <h3 id="solo-checklist-vessel">Vessel or craft information</h3>
                <p class="fpw-solo-checklist-why"><strong>Why it matters:</strong> An accurate photo, identifying details, and the exact access point help a shore contact describe the right craft and where the trip began.</p>
                <a class="fpw-solo-pdf-download" href="<cfoutput>#fpwSoloBasePath#</cfoutput>/downloads/solo-boater-vessel-information-guide.pdf" download type="application/pdf" data-fpw-solo-pdf-download data-fpw-track="solo_boating_vessel_information_pdf_download" data-fpw-track-source-page="solo_boating_safety_guide" data-fpw-track-section="vessel_information" data-fpw-track-document-key="vessel_information" data-fpw-track-label="Download the Vessel Information Reference PDF"><span class="fpw-solo-pdf-badge" aria-hidden="true">PDF</span><span>Download the Vessel Information Reference PDF</span></a>
                <ul class="fpw-solo-checklist">
                  <li><label><input type="checkbox"><span>A current photo of the boat or craft is available.</span></label></li>
                  <li><label><input type="checkbox"><span>Registration or documentation information is current where applicable.</span></label></li>
                  <li><label><input type="checkbox"><span>Make, model, type, length, and primary colors are recorded.</span></label></li>
                  <li><label><input type="checkbox"><span>Important identifying features are recorded.</span></label></li>
                  <li><label><input type="checkbox"><span>Launch ramp, marina, dock, beach, or access point is recorded.</span></label></li>
                  <li><label><input type="checkbox"><span>Vehicle information is included when relevant.</span></label></li>
                  <li><label><input type="checkbox"><span>Trailer information is included when relevant.</span></label></li>
                </ul>
              </section>

              <section aria-labelledby="solo-checklist-personal">
                <h3 id="solo-checklist-personal">Personal safety</h3>
                <p class="fpw-solo-checklist-why"><strong>Why it matters:</strong> With no second person to provide flotation, take the helm, retrieve equipment, or help with reboarding, personal preparation and self-recovery planning matter more.</p>
                <a class="fpw-solo-pdf-download" href="<cfoutput>#fpwSoloBasePath#</cfoutput>/downloads/solo-boater-personal-safety-guide.pdf" download type="application/pdf" data-fpw-solo-pdf-download data-fpw-track="solo_boating_personal_safety_pdf_download" data-fpw-track-source-page="solo_boating_safety_guide" data-fpw-track-section="personal_safety" data-fpw-track-document-key="personal_safety" data-fpw-track-label="Download the Personal Safety Reference PDF"><span class="fpw-solo-pdf-badge" aria-hidden="true">PDF</span><span>Download the Personal Safety Reference PDF</span></a>
                <ul class="fpw-solo-checklist">
                  <li><label><input type="checkbox"><span>I am wearing an appropriate PFD for the activity and conditions.</span></label></li>
                  <li><label><input type="checkbox"><span>My clothing is appropriate for both air and water conditions.</span></label></li>
                  <li><label><input type="checkbox"><span>I am rested enough for the planned trip.</span></label></li>
                  <li><label><input type="checkbox"><span>I have adequate drinking water.</span></label></li>
                  <li><label><input type="checkbox"><span>I have appropriate food or snacks for the trip length.</span></label></li>
                  <li><label><input type="checkbox"><span>Necessary medications are accessible.</span></label></li>
                  <li><label><input type="checkbox"><span>First-aid supplies are appropriate for the trip.</span></label></li>
                  <li><label><input type="checkbox"><span>I know how I would get back aboard after entering the water.</span></label></li>
                  <li><label><input type="checkbox"><span>I have practiced the relevant self-rescue or reboarding method where practical.</span></label></li>
                  <li><label><input type="checkbox"><span>Essential emergency equipment will remain accessible if I become separated from the boat.</span></label></li>
                </ul>
              </section>

              <section aria-labelledby="solo-checklist-weather">
                <h3 id="solo-checklist-weather">Weather and environment</h3>
                <p class="fpw-solo-checklist-why"><strong>Why it matters:</strong> A solo operator has no one aboard to take over as conditions or fatigue worsen. Review the full route and use a wider, conservative margin before departure.</p>
                <a class="fpw-solo-pdf-download" href="<cfoutput>#fpwSoloBasePath#</cfoutput>/downloads/solo-boater-weather-guide.pdf" download type="application/pdf" data-fpw-solo-pdf-download data-fpw-track="solo_boating_weather_pdf_download" data-fpw-track-source-page="solo_boating_safety_guide" data-fpw-track-section="weather" data-fpw-track-document-key="weather" data-fpw-track-label="Download the Weather Reference PDF"><span class="fpw-solo-pdf-badge" aria-hidden="true">PDF</span><span>Download the Weather Reference PDF</span></a>
                <ul class="fpw-solo-checklist">
                  <li><label><input type="checkbox"><span>I checked the current marine or local forecast.</span></label></li>
                  <li><label><input type="checkbox"><span>I checked applicable advisories and warnings.</span></label></li>
                  <li><label><input type="checkbox"><span>I checked expected wind.</span></label></li>
                  <li><label><input type="checkbox"><span>I checked expected gusts.</span></label></li>
                  <li><label><input type="checkbox"><span>I checked waves or seas where applicable.</span></label></li>
                  <li><label><input type="checkbox"><span>I checked thunderstorm risk.</span></label></li>
                  <li><label><input type="checkbox"><span>I checked visibility and fog risk.</span></label></li>
                  <li><label><input type="checkbox"><span>I checked tide where applicable.</span></label></li>
                  <li><label><input type="checkbox"><span>I checked current where applicable.</span></label></li>
                  <li><label><input type="checkbox"><span>I considered water temperature.</span></label></li>
                  <li><label><input type="checkbox"><span>I considered air temperature and exposure.</span></label></li>
                  <li><label><input type="checkbox"><span>I have enough daylight for the planned trip or am properly prepared for darkness.</span></label></li>
                  <li><label><input type="checkbox"><span>Conditions along the entire planned route remain within my conservative solo limits.</span></label></li>
                  <li><label><input type="checkbox"><span>I have decided in advance what conditions would cause me to turn back or cancel.</span></label></li>
                </ul>
              </section>

              <section aria-labelledby="solo-checklist-communications">
                <h3 id="solo-checklist-communications">Communications</h3>
                <p class="fpw-solo-checklist-why"><strong>Why it matters:</strong> A device is of limited use if it fails or becomes unreachable after separation from the boat. Plan appropriate communication redundancy and keep critical equipment accessible.</p>
                <a class="fpw-solo-pdf-download" href="<cfoutput>#fpwSoloBasePath#</cfoutput>/downloads/solo-boater-communications-guide.pdf" download type="application/pdf" data-fpw-solo-pdf-download data-fpw-track="solo_boating_communications_pdf_download" data-fpw-track-source-page="solo_boating_safety_guide" data-fpw-track-section="communications" data-fpw-track-document-key="communications" data-fpw-track-label="Download the Communications Reference PDF"><span class="fpw-solo-pdf-badge" aria-hidden="true">PDF</span><span>Download the Communications Reference PDF</span></a>
                <ul class="fpw-solo-checklist">
                  <li><label><input type="checkbox"><span>My primary communication method works.</span></label></li>
                  <li><label><input type="checkbox"><span>A backup communication method is available where appropriate.</span></label></li>
                  <li><label><input type="checkbox"><span>My cellphone is charged if carried.</span></label></li>
                  <li><label><input type="checkbox"><span>My cellphone is protected from water where appropriate.</span></label></li>
                  <li><label><input type="checkbox"><span>My VHF works where carried.</span></label></li>
                  <li><label><input type="checkbox"><span>I know how to use VHF Channel 16 where applicable.</span></label></li>
                  <li><label><input type="checkbox"><span>DSC/MMSI information is correctly configured where applicable.</span></label></li>
                  <li><label><input type="checkbox"><span>My handheld VHF is charged where carried.</span></label></li>
                  <li><label><input type="checkbox"><span>My PLB is registered and current where carried.</span></label></li>
                  <li><label><input type="checkbox"><span>My EPIRB is registered and current where carried.</span></label></li>
                  <li><label><input type="checkbox"><span>Critical personal distress equipment is accessible if I become separated from the vessel.</span></label></li>
                  <li><label><input type="checkbox"><span>My shore contact knows which communication methods I expect to use.</span></label></li>
                </ul>
              </section>

              <section aria-labelledby="solo-checklist-readiness">
                <h3 id="solo-checklist-readiness">Boat or craft readiness</h3>
                <p class="fpw-solo-checklist-why"><strong>Why it matters:</strong> Equipment failures are harder to manage without another capable person aboard. A pre-departure check reduces avoidable surprises and confirms essential systems and equipment are ready.</p>
                <a class="fpw-solo-pdf-download" href="<cfoutput>#fpwSoloBasePath#</cfoutput>/downloads/solo-boater-boat-readiness-guide.pdf" download type="application/pdf" data-fpw-solo-pdf-download data-fpw-track="solo_boating_boat_readiness_pdf_download" data-fpw-track-source-page="solo_boating_safety_guide" data-fpw-track-section="boat_readiness" data-fpw-track-document-key="boat_readiness" data-fpw-track-label="Download the Boat Readiness Reference PDF"><span class="fpw-solo-pdf-badge" aria-hidden="true">PDF</span><span>Download the Boat Readiness Reference PDF</span></a>
                <ul class="fpw-solo-checklist">
                  <li><label><input type="checkbox"><span>Fuel quantity is adequate for the trip.</span></label></li>
                  <li><label><input type="checkbox"><span>An appropriate fuel reserve is planned.</span></label></li>
                  <li><label><input type="checkbox"><span>Batteries and charging systems are checked where applicable.</span></label></li>
                  <li><label><input type="checkbox"><span>Engine or propulsion system is checked.</span></label></li>
                  <li><label><input type="checkbox"><span>Steering is checked.</span></label></li>
                  <li><label><input type="checkbox"><span>Engine controls are checked.</span></label></li>
                  <li><label><input type="checkbox"><span>Engine cut-off system is checked where applicable.</span></label></li>
                  <li><label><input type="checkbox"><span>Bilge or dewatering equipment is checked where applicable.</span></label></li>
                  <li><label><input type="checkbox"><span>Drain plugs and drains are correct where applicable.</span></label></li>
                  <li><label><input type="checkbox"><span>Navigation lights are working if they may be needed.</span></label></li>
                  <li><label><input type="checkbox"><span>Sound-signaling equipment is available.</span></label></li>
                  <li><label><input type="checkbox"><span>Visual distress signals are checked where required or carried.</span></label></li>
                  <li><label><input type="checkbox"><span>Fire extinguishing equipment is checked where applicable.</span></label></li>
                  <li><label><input type="checkbox"><span>Anchor and ground tackle are ready where appropriate.</span></label></li>
                  <li><label><input type="checkbox"><span>Navigation equipment is working.</span></label></li>
                  <li><label><input type="checkbox"><span>An appropriate backup navigation method is available.</span></label></li>
                  <li><label><input type="checkbox"><span>Required safety equipment is aboard and accessible.</span></label></li>
                  <li><label><input type="checkbox"><span>Paddle, spare paddle, sails, rigging, or other craft-specific propulsion equipment is checked as applicable.</span></label></li>
                  <li><label><input type="checkbox"><span>Essential tools and spares are aboard where appropriate.</span></label></li>
                </ul>
              </section>

              <section aria-labelledby="solo-checklist-specific">
                <h3 id="solo-checklist-specific">Solo-specific precautions</h3>
                <p class="fpw-solo-checklist-why"><strong>Why it matters:</strong> The missing second person means you must deliberately add redundancy, set abort limits, prepare for reboarding, and keep critical equipment within reach.</p>
                <a class="fpw-solo-pdf-download" href="<cfoutput>#fpwSoloBasePath#</cfoutput>/downloads/solo-boater-precautions-guide.pdf" download type="application/pdf" data-fpw-solo-pdf-download data-fpw-track="solo_boating_precautions_pdf_download" data-fpw-track-source-page="solo_boating_safety_guide" data-fpw-track-section="solo_precautions" data-fpw-track-document-key="solo_precautions" data-fpw-track-label="Download the Solo Precautions Reference PDF"><span class="fpw-solo-pdf-badge" aria-hidden="true">PDF</span><span>Download the Solo Precautions Reference PDF</span></a>
                <ul class="fpw-solo-checklist">
                  <li><label><input type="checkbox"><span>I will use the engine cut-off system where required/applicable.</span></label></li>
                  <li><label><input type="checkbox"><span>Reboarding equipment can be reached or deployed from the water.</span></label></li>
                  <li><label><input type="checkbox"><span>I have considered what happens if I fall overboard while the boat is moving.</span></label></li>
                  <li><label><input type="checkbox"><span>Essential communications are not all stored somewhere I could lose access to after going overboard.</span></label></li>
                  <li><label><input type="checkbox"><span>The cockpit, deck, or paddling area is arranged to minimize unnecessary movement.</span></label></li>
                  <li><label><input type="checkbox"><span>Lines and fenders are prepared before close maneuvering where applicable.</span></label></li>
                  <li><label><input type="checkbox"><span>I have a clear turn-back or abort plan.</span></label></li>
                  <li><label><input type="checkbox"><span>I will not let my planned schedule pressure me into unsafe conditions.</span></label></li>
                  <li><label><input type="checkbox"><span>I will tell my shore contact about significant route or timing changes.</span></label></li>
                  <li><label><input type="checkbox"><span>I will close the float plan when the trip is safely complete.</span></label></li>
                </ul>
              </section>
            </div>
          </section>
        </div>
      </div>
    </article>
  </div>
</main>

<cfinclude template="includes/footer.cfm">
<script src="<cfoutput>#fpwSoloBasePath#</cfoutput>/assets/js/fpw-action-cta.js?v=20260804-pilot"></script>
<script src="<cfoutput>#fpwSoloBasePath#</cfoutput>/assets/js/solo-boating-safety-guide.js?v=20260813-ebook-downloads"></script>
</body>
</html>
