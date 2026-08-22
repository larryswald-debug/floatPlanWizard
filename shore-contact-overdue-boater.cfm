<cfprocessingdirective pageencoding="utf-8">
<cfsetting showdebugoutput="false" requesttimeout="30">
<cfcontent type="text/html; charset=utf-8">

<cfscript>
schemaAtKey = chr(64);
schemaTypeKey = schemaAtKey & "type";
schemaIdKey = schemaAtKey & "id";
schemaContextKey = schemaAtKey & "context";
schemaGraphKey = schemaAtKey & "graph";

function fpwOverdueSchemaRef(required string idValue) {
  var out = structNew("ordered");
  structInsert(out, schemaIdKey, arguments.idValue, true);
  return out;
}

function fpwOverdueSchemaListItem(required numeric position, required string name, required string urlValue) {
  var out = structNew("ordered");
  var item = structNew("ordered");
  structInsert(out, schemaTypeKey, "ListItem", true);
  out["position"] = arguments.position;
  structInsert(item, schemaIdKey, arguments.urlValue, true);
  item["name"] = arguments.name;
  out["item"] = item;
  return out;
}

fpwOverdueBasePath = "";
fpwOverdueScriptName = structKeyExists(cgi, "script_name") ? trim(toString(cgi.script_name)) : "";

if (structKeyExists(request, "fpwBase")) {
  fpwOverdueBasePath = trim(toString(request.fpwBase));
}

if (!len(fpwOverdueBasePath) AND len(fpwOverdueScriptName)) {
  fpwOverdueBasePath = reReplace(fpwOverdueScriptName, "/shore-contact-overdue-boater\.cfm$", "");

  if (fpwOverdueBasePath EQ fpwOverdueScriptName) {
    fpwOverdueBasePath = getDirectoryFromPath(fpwOverdueScriptName);
    fpwOverdueBasePath = reReplace(fpwOverdueBasePath, "/$", "");
  }
}

fpwOverdueBasePath = reReplace(fpwOverdueBasePath, "/$", "");
if (fpwOverdueBasePath EQ "/") {
  fpwOverdueBasePath = "";
}
if (len(fpwOverdueBasePath) AND left(fpwOverdueBasePath, 1) NEQ "/") {
  fpwOverdueBasePath = "/" & fpwOverdueBasePath;
}

request.fpwBase = fpwOverdueBasePath;

fpwOverdueCanonicalUrl = "https://floatplanwizard.com/shore-contact-overdue-boater/";
fpwOverduePageTitle = "What to Do When a Boater Is Overdue | Shore Contact Guide";
fpwOverduePageDescription = "Learn what a shore contact should do when a boater misses a check-in or expected return, what information to gather, and when to contact authorities.";
fpwOverdueHeadline = "What a Shore Contact Should Do When a Boater Is Overdue";
fpwOverdueSocialImage = "https://floatplanwizard.com/assets/images/social/floatplanwizard-social-preview-20260730.png";
fpwOverduePublishedDate = "2026-08-06T11:29:36-04:00";
fpwOverdueArticleId = fpwOverdueCanonicalUrl & "##article";
fpwOverdueWebPageId = fpwOverdueCanonicalUrl & "##webpage";
fpwOverdueOrganizationId = "https://floatplanwizard.com/##organization";
fpwOverdueJsonLdText = "";
fpwOverdueSchemaGraph = [];
fpwOverdueSchemaOrg = structNew("ordered");
fpwOverdueSchemaBreadcrumb = structNew("ordered");
fpwOverdueSchemaPage = structNew("ordered");
fpwOverdueSchemaArticle = structNew("ordered");
fpwOverdueJsonLd = structNew("ordered");

structInsert(fpwOverdueSchemaOrg, schemaTypeKey, "Organization", true);
structInsert(fpwOverdueSchemaOrg, schemaIdKey, fpwOverdueOrganizationId, true);
fpwOverdueSchemaOrg["name"] = "FloatPlanWizard";
fpwOverdueSchemaOrg["url"] = "https://floatplanwizard.com/";
fpwOverdueSchemaOrg["logo"] = "https://floatplanwizard.com/assets/images/checkout/floatplanwizard-logo.jpg";
arrayAppend(fpwOverdueSchemaGraph, fpwOverdueSchemaOrg);

structInsert(fpwOverdueSchemaBreadcrumb, schemaTypeKey, "BreadcrumbList", true);
structInsert(fpwOverdueSchemaBreadcrumb, schemaIdKey, fpwOverdueCanonicalUrl & "##breadcrumb", true);
fpwOverdueSchemaBreadcrumb["itemListElement"] = [];
arrayAppend(fpwOverdueSchemaBreadcrumb["itemListElement"], fpwOverdueSchemaListItem(1, "FloatPlanWizard", "https://floatplanwizard.com/"));
arrayAppend(fpwOverdueSchemaBreadcrumb["itemListElement"], fpwOverdueSchemaListItem(2, "Shore Contact Overdue Boater Guide", fpwOverdueCanonicalUrl));
arrayAppend(fpwOverdueSchemaGraph, fpwOverdueSchemaBreadcrumb);

structInsert(fpwOverdueSchemaPage, schemaTypeKey, "WebPage", true);
structInsert(fpwOverdueSchemaPage, schemaIdKey, fpwOverdueWebPageId, true);
fpwOverdueSchemaPage["url"] = fpwOverdueCanonicalUrl;
fpwOverdueSchemaPage["name"] = fpwOverduePageTitle;
fpwOverdueSchemaPage["description"] = fpwOverduePageDescription;
fpwOverdueSchemaPage["isPartOf"] = fpwOverdueSchemaRef("https://floatplanwizard.com/##website");
fpwOverdueSchemaPage["publisher"] = fpwOverdueSchemaRef(fpwOverdueOrganizationId);
fpwOverdueSchemaPage["breadcrumb"] = fpwOverdueSchemaRef(fpwOverdueCanonicalUrl & "##breadcrumb");
fpwOverdueSchemaPage["mainEntity"] = fpwOverdueSchemaRef(fpwOverdueArticleId);
arrayAppend(fpwOverdueSchemaGraph, fpwOverdueSchemaPage);

structInsert(fpwOverdueSchemaArticle, schemaTypeKey, "Article", true);
structInsert(fpwOverdueSchemaArticle, schemaIdKey, fpwOverdueArticleId, true);
fpwOverdueSchemaArticle["url"] = fpwOverdueCanonicalUrl;
fpwOverdueSchemaArticle["headline"] = fpwOverdueHeadline;
fpwOverdueSchemaArticle["description"] = fpwOverduePageDescription;
fpwOverdueSchemaArticle["datePublished"] = fpwOverduePublishedDate;
fpwOverdueSchemaArticle["dateModified"] = fpwOverduePublishedDate;
fpwOverdueSchemaArticle["articleSection"] = "Boating Safety";
fpwOverdueSchemaArticle["inLanguage"] = "en";
fpwOverdueSchemaArticle["author"] = fpwOverdueSchemaRef(fpwOverdueOrganizationId);
fpwOverdueSchemaArticle["publisher"] = fpwOverdueSchemaRef(fpwOverdueOrganizationId);
fpwOverdueSchemaArticle["mainEntityOfPage"] = fpwOverdueSchemaRef(fpwOverdueWebPageId);
arrayAppend(fpwOverdueSchemaGraph, fpwOverdueSchemaArticle);

structInsert(fpwOverdueJsonLd, schemaContextKey, "https://schema.org", true);
structInsert(fpwOverdueJsonLd, schemaGraphKey, fpwOverdueSchemaGraph, true);
fpwOverdueJsonLdText = replace(serializeJSON(fpwOverdueJsonLd), "</", "<\/", "all");

fpwOverdueCtaUserId = 0;
if (structKeyExists(session, "user") AND isStruct(session.user)) {
  for (fpwOverdueCtaUserIdKey in [ "userId", "id", "USERID", "ID" ]) {
    if (structKeyExists(session.user, fpwOverdueCtaUserIdKey) AND isNumeric(session.user[fpwOverdueCtaUserIdKey])) {
      fpwOverdueCtaUserId = val(session.user[fpwOverdueCtaUserIdKey]);
      break;
    }
  }
}
fpwOverdueCtaSignedIn = fpwOverdueCtaUserId GT 0;
fpwCtaConfig = {
  "id" = "shore-contact-overdue-guide-cta",
  "headline" = "Give your shore contact a clear plan",
  "supportingText" = "Create and share your trip details before leaving the dock so the person ashore knows what to expect and what information to use if you are overdue.",
  "buttonLabel" = "Plan a Trip",
  "destinationUrl" = fpwOverdueCtaSignedIn ? fpwOverdueBasePath & "/app/dashboard.cfm" : fpwOverdueBasePath & "/app/join.cfm",
  "ctaType" = "plan_trip",
  "sourcePage" = "shore_contact_overdue_guide",
  "section" = "after_safety_guide",
  "authState" = fpwOverdueCtaSignedIn ? "signed_in" : "signed_out",
  "destinationKey" = fpwOverdueCtaSignedIn ? "dashboard" : "join",
  "analyticsEvent" = "shore_contact_overdue_guide_cta_click",
  "ariaLabel" = "Plan a Trip with FloatPlanWizard after reading the shore contact overdue boater guide"
};
</cfscript>

<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>What to Do When a Boater Is Overdue | Shore Contact Guide</title>
  <meta name="description" content="Learn what a shore contact should do when a boater misses a check-in or expected return, what information to gather, and when to contact authorities.">
  <meta name="robots" content="index,follow">
  <link rel="canonical" href="https://floatplanwizard.com/shore-contact-overdue-boater/">
  <meta property="og:type" content="article">
  <meta property="og:site_name" content="FloatPlanWizard">
  <meta property="og:url" content="https://floatplanwizard.com/shore-contact-overdue-boater/">
  <meta property="og:title" content="What to Do When a Boater Is Overdue | Shore Contact Guide">
  <meta property="og:description" content="Learn what a shore contact should do when a boater misses a check-in or expected return, what information to gather, and when to contact authorities.">
  <meta property="og:image" content="https://floatplanwizard.com/assets/images/social/floatplanwizard-social-preview-20260730.png">
  <meta property="og:image:secure_url" content="https://floatplanwizard.com/assets/images/social/floatplanwizard-social-preview-20260730.png">
  <meta property="og:image:type" content="image/png">
  <meta property="og:image:width" content="1200">
  <meta property="og:image:height" content="630">
  <meta property="og:image:alt" content="FloatPlanWizard boating trip planning, float-plan sharing, and check-in preview">
  <meta name="twitter:card" content="summary_large_image">
  <meta name="twitter:title" content="What to Do When a Boater Is Overdue | Shore Contact Guide">
  <meta name="twitter:description" content="Learn what a shore contact should do when a boater misses a check-in or expected return, what information to gather, and when to contact authorities.">
  <meta name="twitter:image" content="https://floatplanwizard.com/assets/images/social/floatplanwizard-social-preview-20260730.png">
  <meta name="twitter:image:alt" content="FloatPlanWizard boating trip planning, float-plan sharing, and check-in preview">
  <script type="application/ld+json"><cfoutput>#fpwOverdueJsonLdText#</cfoutput></script>
  <cfoutput><link rel="icon" type="image/svg+xml" href="#fpwOverdueBasePath#/assets/images/landing/fpw-logo.svg"></cfoutput>
  <cfoutput><link rel="stylesheet" href="#fpwOverdueBasePath#/assets/css/layout.css?v=20260620-page-width"></cfoutput>
  <cfoutput><link rel="stylesheet" href="#fpwOverdueBasePath#/assets/css/top-nav.css?v=20260814-featured-guides-layout-v1"></cfoutput>
  <cfoutput><link rel="stylesheet" href="#fpwOverdueBasePath#/assets/css/fpw-action-cta.css?v=20260804-pilot"></cfoutput>
  <cfoutput><link rel="stylesheet" href="#fpwOverdueBasePath#/assets/css/shore-contact-overdue-guide.css?v=20260806-cta-color"></cfoutput>
  <cfinclude template="includes/analytics_ga4.cfm">
  <cfinclude template="includes/analytics_clarity.cfm">
  <cfinclude template="includes/trustedsite.cfm">
</head>
<body class="fpw-overdue-body">
<cfinclude template="includes/top_nav.cfm">

<main class="fpw-overdue-page" id="main-content">
  <div class="fpw-overdue-shell">
    <nav class="fpw-overdue-breadcrumbs" aria-label="Breadcrumb">
      <a href="<cfoutput>#fpwOverdueBasePath#</cfoutput>/">FloatPlanWizard</a>
      <span aria-hidden="true">&rsaquo;</span>
      <span aria-current="page">Shore Contact Overdue Boater Guide</span>
    </nav>

    <article class="fpw-overdue-article" aria-labelledby="fpw-overdue-title">
      <header class="fpw-overdue-hero">
        <p class="fpw-overdue-eyebrow">Boating Safety Guide</p>
        <h1 id="fpw-overdue-title">What a Shore Contact Should Do When a Boater Is Overdue</h1>
        <p class="fpw-overdue-lede">A shore contact is a trusted person ashore who receives the float plan and knows what the captain expects them to do. If a planned check-in or return is missed, review the agreed trip details, try the agreed contacts, and act sooner whenever there is a genuine safety concern. This guide supports - but does not replace - emergency judgment or official guidance.</p>
      </header>

      <aside class="fpw-overdue-emergency" role="note" aria-labelledby="fpw-overdue-emergency-title">
        <strong id="fpw-overdue-emergency-title">If you believe anyone is in immediate danger, do not wait for the planned overdue time.</strong>
        <p>Contact the appropriate emergency authority and provide the known facts.</p>
      </aside>

      <div class="fpw-overdue-layout">
        <nav class="fpw-overdue-toc" aria-labelledby="fpw-overdue-toc-title">
          <h2 id="fpw-overdue-toc-title">In this guide</h2>
          <ol>
            <li><a href="#before-the-boat-leaves">Before the boat leaves</a></li>
            <li><a href="#when-a-check-in-is-missed">When a check-in or return is missed</a></li>
            <li><a href="#information-to-gather">Information to gather</a></li>
            <li><a href="#when-to-contact-authorities">When to contact authorities</a></li>
            <li><a href="#after-reporting-concern">After reporting concern</a></li>
            <li><a href="#what-fpw-organizes">What FloatPlanWizard helps organize</a></li>
          </ol>
        </nav>

        <div class="fpw-overdue-content">
          <section id="before-the-boat-leaves" aria-labelledby="before-the-boat-leaves-title">
            <h2 id="before-the-boat-leaves-title">Before the boat leaves</h2>
            <p>A useful response begins before departure. Review <a href="<cfoutput>#fpwOverdueBasePath#</cfoutput>/why-use-a-float-plan/">what a float plan should include</a> with the captain and make sure both of you understand the same plan.</p>
            <ul>
              <li>Review the float plan and keep it where you can find it.</li>
              <li>Know the vessel description, registration or documentation number, and home port or launch point.</li>
              <li>Know who is aboard and whether the captain provided any relevant medical concerns.</li>
              <li>Understand the planned route, destinations, stops, departure time, and expected return time.</li>
              <li>Agree on check-in times and the overdue threshold for this specific trip.</li>
              <li>Understand how the captain will report delays, route changes, or a safe return.</li>
              <li>Confirm the preferred ways to contact the captain and others aboard.</li>
              <li>Know where the tow vehicle or boat trailer may be parked, when relevant.</li>
            </ul>
          </section>

          <section id="when-a-check-in-is-missed" aria-labelledby="when-a-check-in-is-missed-title">
            <h2 id="when-a-check-in-is-missed-title">When a check-in or return is missed</h2>
            <ol class="fpw-overdue-steps">
              <li><span>Check the agreed trip details, check-in time, expected return, and overdue instructions.</span></li>
              <li><span>Try the captain using the agreed contact methods.</span></li>
              <li><span>Try other people aboard using the contact information provided.</span></li>
              <li><span>Check whether another family member, marina, or trusted contact has heard from them.</span></li>
              <li><span>Review the latest available trip update, if one exists. Treat it as a reported update, not as a live or guaranteed current position.</span></li>
              <li><span>Record the missed check-in time and each contact attempt, including the time and result.</span></li>
              <li><span>Reassess weather, route conditions, darkness, medical concerns, the people aboard, and any other risk factors.</span></li>
              <li><span>Follow the captain's agreed overdue instructions when circumstances appear routine, but act sooner if there is a genuine reason to believe someone may be in danger.</span></li>
            </ol>

            <div class="fpw-overdue-risk-grid" aria-label="How to distinguish routine delay, overdue concern, and immediate danger">
              <section>
                <h3>Routine delay</h3>
                <p>No distress indication or unusual risk is known. Follow the agreed contact and overdue instructions while continuing to reassess the facts.</p>
              </section>
              <section>
                <h3>Overdue concern</h3>
                <p>The agreed threshold has passed, contact attempts have failed, or changing conditions increase concern. Gather the known facts and consider contacting the appropriate authority.</p>
              </section>
              <section>
                <h3>Immediate danger</h3>
                <p>A distress indication, severe weather, medical issue, vulnerable passenger, or other danger is known or reasonably suspected. Do not wait for the planned threshold.</p>
              </section>
            </div>
            <p class="fpw-overdue-principle"><strong>There is no universal grace period.</strong> The right response depends on the captain's agreed instructions and the actual safety concerns at that time.</p>
          </section>

          <section id="information-to-gather" aria-labelledby="information-to-gather-title">
            <h2 id="information-to-gather-title">Information to gather</h2>
            <p>Gather what is already known. When speaking with an authority, report facts and clearly identify anything you do not know. Do not speculate.</p>
            <ul class="fpw-overdue-checklist">
              <li>Captain's name</li>
              <li>Passenger names</li>
              <li>Vessel name</li>
              <li>Vessel type</li>
              <li>Vessel length</li>
              <li>Vessel color</li>
              <li>Registration or documentation number</li>
              <li>Home port or launch point</li>
              <li>Departure time</li>
              <li>Expected return time</li>
              <li>Planned route</li>
              <li>Destinations and stops</li>
              <li>Last known contact</li>
              <li>Last reported position, when available</li>
              <li>Communication equipment</li>
              <li>Safety equipment</li>
              <li>Known medical concerns, when provided</li>
              <li>Vehicle and trailer details, when relevant</li>
              <li>Emergency contacts</li>
              <li>Any route-change or delay message</li>
            </ul>
          </section>

          <section id="when-to-contact-authorities" aria-labelledby="when-to-contact-authorities-title">
            <h2 id="when-to-contact-authorities-title">When to contact authorities</h2>
            <p>A missed check-in does not automatically mean distress. Immediate action may be appropriate, however, when any known fact creates a genuine safety concern.</p>
            <ul>
              <li>A distress message was received.</li>
              <li>The captain reported needing assistance.</li>
              <li>Severe weather affects the planned route.</li>
              <li>The vessel is significantly overdue beyond the captain's agreed threshold.</li>
              <li>There is a medical concern.</li>
              <li>A child or other vulnerable passenger is aboard.</li>
              <li>The vessel failed to arrive and no one aboard can be contacted.</li>
              <li>Known trip information suggests danger.</li>
              <li>You have another genuine reason to believe someone may be at risk.</li>
            </ul>
            <p>Contact the appropriate emergency authority directly and provide the known facts. FloatPlanWizard does not determine when rescue action is required, verify an emergency, contact authorities for you, or dispatch assistance.</p>
            <p class="fpw-overdue-source-note">The site's <a href="<cfoutput>#fpwOverdueBasePath#</cfoutput>/downloads/uscg-float-plan.pdf">official U.S. Coast Guard Float Plan and Boating Emergency Guide</a> also emphasizes contacting the people listed on the plan, recording only what you know, avoiding speculation, and remaining available after a concern is reported.</p>
          </section>

          <section id="after-reporting-concern" aria-labelledby="after-reporting-concern-title">
            <h2 id="after-reporting-concern-title">What to do after reporting concern</h2>
            <ul>
              <li>Remain reachable and follow the authority's instructions.</li>
              <li>Preserve messages, the float plan, trip updates, and your contact-attempt notes.</li>
              <li>Provide new factual information to the authority handling the concern.</li>
              <li>Do not speculate about what happened or where the vessel may be.</li>
              <li>Do not independently launch an unsafe search.</li>
              <li>If the captain or someone aboard makes contact, notify the authority immediately.</li>
              <li>Record the time and content of each new communication.</li>
            </ul>
          </section>

          <section id="what-fpw-organizes" aria-labelledby="what-fpw-organizes-title">
            <h2 id="what-fpw-organizes-title">What FloatPlanWizard helps organize</h2>
            <p>FloatPlanWizard is a planning and communication tool. It can help a captain prepare trip details, record vessel and passenger information, identify a shore contact, share a float plan, and organize route and timing details. That information may help the shore contact respond more effectively.</p>
            <p>FPW does not continuously watch every trip, guarantee message delivery, confirm distress, provide professional monitoring, guarantee a vessel's current location, contact the Coast Guard automatically, or replace emergency authorities. Any available trip page or check-in should be treated as the latest reported information, not independent live vessel tracking.</p>
            <p>See <a href="<cfoutput>#fpwOverdueBasePath#</cfoutput>/how-it-works/">how trip planning and sharing work together</a>, or review FPW's <a href="<cfoutput>#fpwOverdueBasePath#</cfoutput>/faq/#safety">boating-safety limitations and guidance</a>.</p>
          </section>

          <div class="fpw-overdue-cta-wrap">
            <cfinclude template="partials/fpw-action-cta.cfm">
          </div>
        </div>
      </div>
    </article>
  </div>
</main>

<cfinclude template="includes/footer.cfm">
<script src="<cfoutput>#fpwOverdueBasePath#</cfoutput>/assets/js/fpw-action-cta.js?v=20260804-pilot"></script>
</body>
</html>
