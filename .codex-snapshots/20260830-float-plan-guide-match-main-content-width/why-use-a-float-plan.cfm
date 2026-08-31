<cfprocessingdirective pageencoding="utf-8">
<cfsetting showdebugoutput="false" requesttimeout="30">
<cfcontent type="text/html; charset=utf-8">

<cfscript>
schemaAtKey = chr(64);
schemaTypeKey = schemaAtKey & "type";
schemaIdKey = schemaAtKey & "id";
schemaContextKey = schemaAtKey & "context";
schemaGraphKey = schemaAtKey & "graph";

function fpwFloatPlanSchemaRef(required string idValue) {
  var out = structNew("ordered");
  structInsert(out, schemaIdKey, arguments.idValue, true);
  return out;
}

function fpwFloatPlanSchemaListItem(required numeric position, required string name, required string urlValue) {
  var out = structNew("ordered");
  var item = structNew("ordered");
  structInsert(out, schemaTypeKey, "ListItem", true);
  out["position"] = arguments.position;
  structInsert(item, schemaIdKey, arguments.urlValue, true);
  item["name"] = arguments.name;
  out["item"] = item;
  return out;
}

fpwFloatPlanBasePath = "";
fpwFloatPlanScriptName = structKeyExists(cgi, "script_name") ? trim(toString(cgi.script_name)) : "";

if (structKeyExists(request, "fpwBase")) {
  fpwFloatPlanBasePath = trim(toString(request.fpwBase));
}

if (!len(fpwFloatPlanBasePath) AND len(fpwFloatPlanScriptName)) {
  fpwFloatPlanBasePath = reReplace(fpwFloatPlanScriptName, "/why-use-a-float-plan\.cfm$", "");
  if (fpwFloatPlanBasePath EQ fpwFloatPlanScriptName) {
    fpwFloatPlanBasePath = reReplace(getDirectoryFromPath(fpwFloatPlanScriptName), "/$", "");
  }
}

fpwFloatPlanBasePath = reReplace(fpwFloatPlanBasePath, "/$", "");
if (fpwFloatPlanBasePath EQ "/") {
  fpwFloatPlanBasePath = "";
}
if (len(fpwFloatPlanBasePath) AND left(fpwFloatPlanBasePath, 1) NEQ "/") {
  fpwFloatPlanBasePath = "/" & fpwFloatPlanBasePath;
}

request.fpwBase = fpwFloatPlanBasePath;
request.fpwTopNavActive = "resources-why-float-plan";

fpwFloatPlanCanonicalUrl = "https://floatplanwizard.com/why-use-a-float-plan/";
fpwFloatPlanPageTitle = "Float Plan Guide: Why It Matters & What to Include | FPW";
fpwFloatPlanPageDescription = "Learn what a float plan is, why boaters should use one, what to include, who should hold it, when to update it, and what to do if a boater is overdue.";
fpwFloatPlanHeadline = "Float Plan Guide: What It Is, Why It Matters, and How to Use One";
fpwFloatPlanSocialTitle = "The Complete Float Plan Guide for Recreational Boaters";
fpwFloatPlanSocialDescription = "What a float plan is, what to include, who should hold it, how overdue timing works, and how to keep the plan useful when the trip changes.";
fpwFloatPlanSocialImage = "https://floatplanwizard.com/assets/images/social/floatplanwizard-social-preview-20260730.png";
fpwFloatPlanOfficialPdf = "https://floatplancentral.cgaux.org/download/USCGFloatPlan.pdf";

fpwFloatPlanCtaUserId = 0;
if (structKeyExists(session, "user") AND isStruct(session.user)) {
  for (fpwFloatPlanCtaUserIdKey in [ "userId", "id", "USERID", "ID" ]) {
    if (structKeyExists(session.user, fpwFloatPlanCtaUserIdKey) AND isNumeric(session.user[fpwFloatPlanCtaUserIdKey])) {
      fpwFloatPlanCtaUserId = val(session.user[fpwFloatPlanCtaUserIdKey]);
      break;
    }
  }
}
fpwFloatPlanCtaSignedIn = fpwFloatPlanCtaUserId GT 0;
fpwFloatPlanProductUrl = fpwFloatPlanCtaSignedIn ? fpwFloatPlanBasePath & "/app/dashboard.cfm" : fpwFloatPlanBasePath & "/app/join.cfm";
fpwFloatPlanAuthState = fpwFloatPlanCtaSignedIn ? "signed_in" : "signed_out";
fpwFloatPlanProductCtaLabel = fpwFloatPlanCtaSignedIn ? "Open Your FPW Dashboard" : "Create Your Free FPW Account";

fpwFloatPlanOrganizationId = "https://floatplanwizard.com/##organization";
fpwFloatPlanWebsiteId = "https://floatplanwizard.com/##website";
fpwFloatPlanArticleId = fpwFloatPlanCanonicalUrl & "##article";
fpwFloatPlanBreadcrumbId = fpwFloatPlanCanonicalUrl & "##breadcrumb";
fpwFloatPlanSchemaGraph = [];
fpwFloatPlanSchemaOrg = structNew("ordered");
fpwFloatPlanSchemaWebsite = structNew("ordered");
fpwFloatPlanSchemaBreadcrumb = structNew("ordered");
fpwFloatPlanSchemaPage = structNew("ordered");
fpwFloatPlanSchemaArticle = structNew("ordered");
fpwFloatPlanJsonLd = structNew("ordered");

structInsert(fpwFloatPlanSchemaOrg, schemaTypeKey, "Organization", true);
structInsert(fpwFloatPlanSchemaOrg, schemaIdKey, fpwFloatPlanOrganizationId, true);
fpwFloatPlanSchemaOrg["name"] = "FloatPlanWizard";
fpwFloatPlanSchemaOrg["url"] = "https://floatplanwizard.com/";
fpwFloatPlanSchemaOrg["logo"] = "https://floatplanwizard.com/assets/images/checkout/floatplanwizard-logo.jpg";
arrayAppend(fpwFloatPlanSchemaGraph, fpwFloatPlanSchemaOrg);

structInsert(fpwFloatPlanSchemaWebsite, schemaTypeKey, "WebSite", true);
structInsert(fpwFloatPlanSchemaWebsite, schemaIdKey, fpwFloatPlanWebsiteId, true);
fpwFloatPlanSchemaWebsite["url"] = "https://floatplanwizard.com/";
fpwFloatPlanSchemaWebsite["name"] = "FloatPlanWizard";
fpwFloatPlanSchemaWebsite["publisher"] = fpwFloatPlanSchemaRef(fpwFloatPlanOrganizationId);
arrayAppend(fpwFloatPlanSchemaGraph, fpwFloatPlanSchemaWebsite);

structInsert(fpwFloatPlanSchemaBreadcrumb, schemaTypeKey, "BreadcrumbList", true);
structInsert(fpwFloatPlanSchemaBreadcrumb, schemaIdKey, fpwFloatPlanBreadcrumbId, true);
fpwFloatPlanSchemaBreadcrumb["itemListElement"] = [];
arrayAppend(fpwFloatPlanSchemaBreadcrumb["itemListElement"], fpwFloatPlanSchemaListItem(1, "FloatPlanWizard", "https://floatplanwizard.com/"));
arrayAppend(fpwFloatPlanSchemaBreadcrumb["itemListElement"], fpwFloatPlanSchemaListItem(2, "Float Plan Guide", fpwFloatPlanCanonicalUrl));
arrayAppend(fpwFloatPlanSchemaGraph, fpwFloatPlanSchemaBreadcrumb);

structInsert(fpwFloatPlanSchemaPage, schemaTypeKey, "WebPage", true);
structInsert(fpwFloatPlanSchemaPage, schemaIdKey, fpwFloatPlanCanonicalUrl, true);
fpwFloatPlanSchemaPage["url"] = fpwFloatPlanCanonicalUrl;
fpwFloatPlanSchemaPage["name"] = fpwFloatPlanPageTitle;
fpwFloatPlanSchemaPage["description"] = fpwFloatPlanPageDescription;
fpwFloatPlanSchemaPage["isPartOf"] = fpwFloatPlanSchemaRef(fpwFloatPlanWebsiteId);
fpwFloatPlanSchemaPage["publisher"] = fpwFloatPlanSchemaRef(fpwFloatPlanOrganizationId);
fpwFloatPlanSchemaPage["breadcrumb"] = fpwFloatPlanSchemaRef(fpwFloatPlanBreadcrumbId);
fpwFloatPlanSchemaPage["mainEntity"] = fpwFloatPlanSchemaRef(fpwFloatPlanArticleId);
arrayAppend(fpwFloatPlanSchemaGraph, fpwFloatPlanSchemaPage);

structInsert(fpwFloatPlanSchemaArticle, schemaTypeKey, "Article", true);
structInsert(fpwFloatPlanSchemaArticle, schemaIdKey, fpwFloatPlanArticleId, true);
fpwFloatPlanSchemaArticle["url"] = fpwFloatPlanCanonicalUrl;
fpwFloatPlanSchemaArticle["headline"] = fpwFloatPlanHeadline;
fpwFloatPlanSchemaArticle["description"] = fpwFloatPlanPageDescription;
fpwFloatPlanSchemaArticle["dateModified"] = "2026-08-30";
fpwFloatPlanSchemaArticle["articleSection"] = "Boating Safety";
fpwFloatPlanSchemaArticle["inLanguage"] = "en-US";
fpwFloatPlanSchemaArticle["author"] = fpwFloatPlanSchemaRef(fpwFloatPlanOrganizationId);
fpwFloatPlanSchemaArticle["publisher"] = fpwFloatPlanSchemaRef(fpwFloatPlanOrganizationId);
fpwFloatPlanSchemaArticle["mainEntityOfPage"] = fpwFloatPlanSchemaRef(fpwFloatPlanCanonicalUrl);
arrayAppend(fpwFloatPlanSchemaGraph, fpwFloatPlanSchemaArticle);

structInsert(fpwFloatPlanJsonLd, schemaContextKey, "https://schema.org", true);
structInsert(fpwFloatPlanJsonLd, schemaGraphKey, fpwFloatPlanSchemaGraph, true);
fpwFloatPlanJsonLdText = replace(serializeJSON(fpwFloatPlanJsonLd), "</", "<\/", "all");
</cfscript>

<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Float Plan Guide: Why It Matters & What to Include | FPW</title>
  <meta name="description" content="Learn what a float plan is, why boaters should use one, what to include, who should hold it, when to update it, and what to do if a boater is overdue.">
  <meta name="robots" content="index,follow,max-image-preview:large">
  <link rel="canonical" href="https://floatplanwizard.com/why-use-a-float-plan/">
  <meta property="og:type" content="article">
  <meta property="og:site_name" content="FloatPlanWizard">
  <meta property="og:url" content="https://floatplanwizard.com/why-use-a-float-plan/">
  <meta property="og:title" content="The Complete Float Plan Guide for Recreational Boaters">
  <meta property="og:description" content="What a float plan is, what to include, who should hold it, how overdue timing works, and how to keep the plan useful when the trip changes.">
  <meta property="og:image" content="https://floatplanwizard.com/assets/images/social/floatplanwizard-social-preview-20260730.png">
  <meta property="og:image:secure_url" content="https://floatplanwizard.com/assets/images/social/floatplanwizard-social-preview-20260730.png">
  <meta property="og:image:type" content="image/png">
  <meta property="og:image:width" content="1200">
  <meta property="og:image:height" content="630">
  <meta property="og:image:alt" content="FloatPlanWizard boating trip planning and float-plan sharing preview">
  <meta name="twitter:card" content="summary_large_image">
  <meta name="twitter:title" content="The Complete Float Plan Guide for Recreational Boaters">
  <meta name="twitter:description" content="What a float plan is, what to include, who should hold it, how overdue timing works, and how to keep the plan useful when the trip changes.">
  <meta name="twitter:image" content="https://floatplanwizard.com/assets/images/social/floatplanwizard-social-preview-20260730.png">
  <meta name="twitter:image:alt" content="FloatPlanWizard boating trip planning and float-plan sharing preview">
  <script type="application/ld+json"><cfoutput>#fpwFloatPlanJsonLdText#</cfoutput></script>
  <cfoutput><link rel="icon" type="image/svg+xml" href="#fpwFloatPlanBasePath#/assets/images/landing/fpw-logo.svg"></cfoutput>
  <cfoutput><link rel="stylesheet" href="#fpwFloatPlanBasePath#/assets/css/layout.css?v=20260620-page-width"></cfoutput>
  <cfoutput><link rel="stylesheet" href="#fpwFloatPlanBasePath#/assets/css/top-nav.css?v=20260824-boating-safety-nav-v2"></cfoutput>
  <cfoutput><link rel="stylesheet" href="#fpwFloatPlanBasePath#/assets/css/float-plan-guide.css?v=20260830-pillar-no-hero-v1"></cfoutput>
  <cfinclude template="includes/analytics_ga4.cfm">
  <cfinclude template="includes/analytics_clarity.cfm">
  <cfinclude template="includes/trustedsite.cfm">
</head>
<body class="fpw-float-guide-body" id="top">
<a class="fpw-float-guide-skip-link" href="#main-content">Skip to guide content</a>
<cfinclude template="includes/top_nav.cfm">

<main class="fpw-float-guide-page" id="main-content">
  <div class="fpw-float-guide-shell">
    <nav class="fpw-float-guide-breadcrumbs" aria-label="Breadcrumb">
      <a href="<cfoutput>#fpwFloatPlanBasePath#</cfoutput>/">FloatPlanWizard</a>
      <span aria-hidden="true">&rsaquo;</span>
      <span aria-current="page">Float Plan Guide</span>
    </nav>

    <article class="fpw-float-guide-article" aria-labelledby="float-plan-guide-title">
      <header class="fpw-float-guide-hero">
        <div class="fpw-float-guide-hero__copy">
          <p class="fpw-float-guide-eyebrow">FLOAT PLAN EDUCATION</p>
          <h1 id="float-plan-guide-title">Float Plan Guide: What It Is, Why It Matters, and How to Use One</h1>
          <p>A float plan tells a responsible person ashore where you intend to go, who is aboard, what vessel or craft you are using, when you expect to return, and what information may be useful if concern develops.</p>
          <p>It can be as simple as a clearly written plan for a short local outing or as detailed as a multi-stop itinerary for a longer cruise. The important part is that the information is accurate, someone ashore actually has it, and that person understands what you expect them to do if you do not check in or return as planned.</p>
          <div class="fpw-float-guide-actions" aria-label="Float plan guide actions">
            <a class="fpw-float-guide-button fpw-float-guide-button--primary" href="#what-to-include" data-fpw-float-guide-toc data-section-id="what-to-include">See what a float plan should include</a>
            <a class="fpw-float-guide-button fpw-float-guide-button--secondary" href="<cfoutput>#fpwFloatPlanOfficialPdf#</cfoutput>" target="_blank" rel="noopener noreferrer" data-fpw-float-guide-source data-source-org="uscg_auxiliary" data-section-id="hero">Download the official USCG Float Plan</a>
            <a class="fpw-float-guide-button fpw-float-guide-button--quiet" href="<cfoutput>#fpwFloatPlanProductUrl#</cfoutput>" data-fpw-float-guide-cta data-cta-name="create_float_plan" data-placement="hero" data-auth-state="<cfoutput>#fpwFloatPlanAuthState#</cfoutput>"><cfoutput>#fpwFloatPlanProductCtaLabel#</cfoutput></a>
          </div>
        </div>
      </header>

      <section class="fpw-float-guide-quick-answer" id="quick-answer" aria-labelledby="quick-answer-title">
        <p class="fpw-float-guide-section-kicker">The 30-second answer</p>
        <h2 id="quick-answer-title">What is a float plan?</h2>
        <p>A <strong>float plan</strong> is a written record of an intended boating trip that describes the vessel or craft, the people aboard, the planned route or operating area, important timing, and other information that could be useful if the boater becomes overdue or unreachable.</p>
        <p>You leave the plan with a <strong>responsible person ashore</strong> who has agreed to hold it and knows what to do if concern develops.</p>
        <p><strong>You do not file a recreational float plan with the U.S. Coast Guard.</strong> The Coast Guard Auxiliary's Float Plan Central FAQ specifically states that the Coast Guard does not accept float plans. The plan belongs with the person you have chosen to hold it.</p>
        <blockquote><strong>Key point:</strong> A float plan is not useful because a form exists. It is useful because accurate trip information is in the hands of someone who will notice when something does not match the plan.</blockquote>
      </section>

      <div class="fpw-float-guide-reading-layout">
        <nav class="fpw-float-guide-toc" aria-labelledby="float-plan-toc-title">
          <p id="float-plan-toc-title">On this page</p>
          <ol>
            <li><a href="#what-is-a-float-plan" data-fpw-float-guide-toc data-section-id="what-is-a-float-plan">What a float plan is</a></li>
            <li><a href="#why-use-a-float-plan" data-fpw-float-guide-toc data-section-id="why-use-a-float-plan">Why use one</a></li>
            <li><a href="#who-should-use-a-float-plan" data-fpw-float-guide-toc data-section-id="who-should-use-a-float-plan">Who should use one</a></li>
            <li><a href="#what-to-include" data-fpw-float-guide-toc data-section-id="what-to-include">What to include</a></li>
            <li><a href="#who-should-hold-float-plan" data-fpw-float-guide-toc data-section-id="who-should-hold-float-plan">Who should hold it</a></li>
            <li><a href="#timing-and-overdue" data-fpw-float-guide-toc data-section-id="timing-and-overdue">Timing and overdue</a></li>
            <li><a href="#when-plans-change" data-fpw-float-guide-toc data-section-id="when-plans-change">When plans change</a></li>
            <li><a href="#shore-contact-overdue" data-fpw-float-guide-toc data-section-id="shore-contact-overdue">If a boater is overdue</a></li>
            <li><a href="#short-day-trip" data-fpw-float-guide-toc data-section-id="short-day-trip">Short day trips</a></li>
            <li><a href="#paper-vs-digital" data-fpw-float-guide-toc data-section-id="paper-vs-digital">Paper vs. digital</a></li>
            <li><a href="#common-float-plan-mistakes" data-fpw-float-guide-toc data-section-id="common-float-plan-mistakes">Common mistakes</a></li>
            <li><a href="#float-plan-vs-safety-tools" data-fpw-float-guide-toc data-section-id="float-plan-vs-safety-tools">Other safety tools</a></li>
            <li><a href="#day-trip-example" data-fpw-float-guide-toc data-section-id="day-trip-example">Day-trip example</a></li>
            <li><a href="#float-plan-checklist" data-fpw-float-guide-toc data-section-id="float-plan-checklist">Checklist</a></li>
            <li><a href="#float-plan-faq" data-fpw-float-guide-toc data-section-id="float-plan-faq">FAQ</a></li>
            <li><a href="#sources" data-fpw-float-guide-toc data-section-id="sources">Sources</a></li>
          </ol>
        </nav>

        <div class="fpw-float-guide-content">
          <section id="what-is-a-float-plan" aria-labelledby="what-is-a-float-plan-title">
            <p class="fpw-float-guide-section-kicker">The foundation</p>
            <h2 id="what-is-a-float-plan-title">1. What a float plan is—and what it is not</h2>
            <p>The phrase <em>float plan</em> can sound more formal than it really is. It does not have to be a government filing, a complicated navigation document, or an offshore-cruising form.</p>
            <p>At its core, a float plan answers a few practical questions:</p>
            <ul>
              <li><strong>Who is on the water?</strong></li>
              <li><strong>What boat or craft are they using?</strong></li>
              <li><strong>Where did they leave from?</strong></li>
              <li><strong>Where do they intend to go?</strong></li>
              <li><strong>When should they check in or return?</strong></li>
              <li><strong>How can they be contacted?</strong></li>
              <li><strong>What useful safety or identification information is available?</strong></li>
              <li><strong>Who ashore is holding the plan?</strong></li>
            </ul>
            <p>The U.S. Coast Guard describes the reason for preparing one in practical terms: there are many details that may need to be accurately remembered and passed to rescue personnel during an emergency. A written plan reduces dependence on someone trying to reconstruct those facts from memory.</p>
            <h3>A float plan is not a navigation plan</h3>
            <p>Your float plan may contain a route, waypoints, destinations, and expected timing, but it is not a substitute for the charts, navigation tools, local knowledge, weather information, Notices to Mariners, and judgment you use to operate the boat safely.</p>
            <h3>A float plan is not a tracking device</h3>
            <p>A float plan records <strong>intent</strong>. A tracker or GPS-bearing check-in may report a position at a particular time. Those are different types of information.</p>
            <p>Tracking can fail because of battery, hardware, coverage, installation, or device-separation problems. A float plan can still tell a shore contact what the intended trip was. Likewise, a float plan does not tell anyone the boat's guaranteed current position.</p>
            <h3>A float plan is not emergency dispatch</h3>
            <p>Creating or sharing a float plan does not itself summon help. If there is an actual emergency, use the appropriate emergency communication method immediately. Do not wait for a planned check-in or overdue time when a person or vessel is in known immediate danger.</p>

            <figure class="fpw-float-guide-figure fpw-float-guide-flow" aria-labelledby="float-plan-flow-title">
              <h3 id="float-plan-flow-title">How a Float Plan Works</h3>
              <ol class="fpw-float-guide-flow__main">
                <li>Plan the trip</li>
                <li>Record boat + people + route + timing</li>
                <li>Share with a responsible person ashore</li>
                <li>Go boating <span>Update if plans change</span></li>
                <li>Return / arrive</li>
                <li>Close the plan</li>
              </ol>
              <div class="fpw-float-guide-flow__concern"><strong>If concern develops:</strong><span>Shore contact</span><span aria-hidden="true">→</span><span>Review known facts</span><span aria-hidden="true">→</span><span>Follow agreed response</span></div>
              <figcaption>A float plan supports communication and an agreed response. It does not automatically dispatch rescue.</figcaption>
            </figure>
          </section>

          <section id="why-use-a-float-plan" aria-labelledby="why-use-a-float-plan-title">
            <p class="fpw-float-guide-section-kicker">Information continuity</p>
            <h2 id="why-use-a-float-plan-title">2. Why use a float plan?</h2>
            <p>The real value of a float plan is <strong>information continuity</strong>.</p>
            <p>A normal boating day contains details that are obvious to the people aboard and almost invisible to everyone else. You know which ramp you used, which direction you headed, whether you planned to fish near shore or cross a bay, which boat you took, who came with you, and when you expected to be back.</p>
            <p>The person at home may know only: <em>They went boating today.</em></p>
            <p>A useful float plan closes that information gap before it matters.</p>
            <h3>It tells someone where the trip began</h3>
            <p>An exact marina, ramp, dock, beach, or access point is much more useful than a vague description such as “the bay” or “the river.” For trailered boats and paddlecraft, vehicle and trailer details may also help establish where the trip began.</p>
            <h3>It describes the correct boat or craft</h3>
            <p>A current photo plus accurate identifying details can help distinguish one white center console, blue kayak, or cruising sailboat from another.</p>
            <p>Useful details can include:</p>
            <ul><li>vessel or craft name</li><li>make and model</li><li>type and length</li><li>hull and trim colors</li><li>registration or documentation number where applicable</li><li>top, enclosure, tower, sail, antenna, or other distinctive features</li><li>current photograph</li></ul>
            <p>The U.S. Coast Guard specifically recommends including a recent vessel photo.</p>
            <h3>It records the intended route and timing</h3>
            <p>Route and timing are often the heart of the plan. The plan can show where the boater intended to go, important stops, the expected destination, check-ins, and expected return.</p>
            <p>That information does <strong>not</strong> prove where the boat is now. It provides the intended trip against which later facts can be compared.</p>
            <h3>It records who is aboard</h3>
            <p>A shore contact should not have to guess whether the captain went alone or took three passengers. The plan can identify the operator and people aboard, along with appropriate emergency-contact or voluntarily provided information that could be relevant if concern develops.</p>
            <h3>It gives the shore contact an agreed job</h3>
            <p>This may be the most overlooked part of float planning.</p>
            <p>A float plan sitting in an inbox is much less useful if the recipient does not know they are the shore contact, does not know when the trip is supposed to end, or does not know what the captain expects them to do after a missed check-in.</p>
            <p>The person holding the plan should understand the role <strong>before departure</strong>.</p>
          </section>

          <section id="who-should-use-a-float-plan" aria-labelledby="who-should-use-a-float-plan-title">
            <p class="fpw-float-guide-section-kicker">Scale it to the trip</p>
            <h2 id="who-should-use-a-float-plan-title">3. Who should use a float plan?</h2>
            <p>Float plans are not only for offshore yachts or long passages.</p>
            <p>The Coast Guard's recreational-boating guidance specifically makes the point that float plans can be useful across a wide range of activities and craft, including kayaks, canoes, stand-up paddleboards, personal watercraft, fishing boats, sailboats, powerboats, and larger recreational vessels.</p>
            <h3>Local day boaters</h3><p>A short trip can still involve engine trouble, weather, an injury, an unexpected grounding, a dead phone, or simply an unplanned delay. A simple plan can be enough: departure point, activity area or destination, boat, people aboard, and return time.</p>
            <h3>Anglers</h3><p>Fishing trips often involve broad activity areas rather than one fixed destination. Record the launch point, likely fishing area or route, expected return, people aboard, communication methods, and any likely alternate area.</p>
            <h3>Kayakers, canoeists, and paddleboarders</h3><p>For paddlecraft, the exact access point, craft color/photo, route, expected return, vehicle information, weather exposure, and person-carried communication equipment can be especially useful.</p>
            <h3>Solo boaters</h3><p>For someone boating alone, the shore contact may be the only other person who knows the intended route and timing. Float planning therefore becomes an especially important part of the safety layers around the trip.</p>
            <h3>Families and groups</h3><p>A plan provides one shared record of who is actually aboard and where the trip is supposed to go, rather than leaving those details scattered across texts and conversations.</p>
            <h3>Cruisers and multi-day trips</h3><p>Longer trips benefit from more detail: planned legs, stops, check-ins, daily timing, alternate destinations, and meaningful route changes.</p>
            <blockquote><strong>Best practice:</strong> Scale the detail to the trip. Do not make a two-hour outing so burdensome that you stop using float plans, and do not reduce a multi-day cruise to “heading south, back Friday.”</blockquote>

            <figure class="fpw-float-guide-figure" aria-labelledby="trip-detail-title">
              <h3 id="trip-detail-title">How Much Detail Should a Float Plan Have?</h3>
              <div class="fpw-float-guide-table-wrap"><table class="fpw-float-guide-table fpw-float-guide-table--responsive">
                <thead><tr><th scope="col">Trip</th><th scope="col">Useful minimum</th><th scope="col">Add when applicable</th></tr></thead>
                <tbody>
                  <tr><th scope="row" data-label="Trip">Short local outing</th><td data-label="Useful minimum">craft, departure point, destination/activity area, expected return, contact</td><td data-label="Add when applicable">route notes, passenger info, comms</td></tr>
                  <tr><th scope="row" data-label="Trip">Fishing / paddle trip</th><td data-label="Useful minimum">exact launch, route/activity area, craft photo, people, return time</td><td data-label="Add when applicable">vehicle/trailer, alternate landing, person-carried comms</td></tr>
                  <tr><th scope="row" data-label="Trip">Overnight / coastal trip</th><td data-label="Useful minimum">full vessel, people, route/stops, timing, check-ins, comms/safety</td><td data-label="Add when applicable">alternates, marina/anchorage contacts</td></tr>
                  <tr><th scope="row" data-label="Trip">Multi-day cruise</th><td data-label="Useful minimum">full plan plus leg-by-leg destinations, daily timing, check-ins</td><td data-label="Add when applicable">route changes, daily-start assumptions, alternate stops</td></tr>
                </tbody>
              </table></div>
              <figcaption>The plan should scale with the trip. A two-hour outing does not need the same detail as a multi-day cruise, but someone ashore should still know the essential facts.</figcaption>
            </figure>
          </section>

          <section id="what-to-include" aria-labelledby="what-to-include-title">
            <p class="fpw-float-guide-section-kicker">The useful record</p>
            <h2 id="what-to-include-title">4. What should a float plan include?</h2>
            <p>A useful float plan gives the person ashore enough accurate information to understand the intended trip and pass known facts along if concern develops.</p>
            <h3>Vessel or craft information</h3><p>Include what makes the boat identifiable:</p>
            <ul><li>vessel/craft name where applicable</li><li>make, model, and type</li><li>length</li><li>primary colors and identifying features</li><li>registration or documentation number where applicable</li><li>propulsion information when useful</li><li>a current photograph</li></ul>
            <h3>Operator and people aboard</h3><p>Include:</p>
            <ul><li>operator name</li><li>reliable contact information</li><li>number of people aboard</li><li>passenger names where appropriate</li><li>emergency contacts</li><li>relevant information voluntarily provided for emergency use</li></ul>
            <p>Avoid collecting sensitive information merely because a field exists. Include what has a clear safety purpose.</p>
            <h3>Departure point</h3><p>Be specific:</p>
            <ul><li>marina or dock name</li><li>launch-ramp name</li><li>beach/access point for paddlecraft</li><li>city or waterway</li><li>vehicle/trailer information when relevant</li></ul>
            <h3>Route, destination, and stops</h3><p>Record the intended operating area or route:</p>
            <ul><li>destination</li><li>general track or route</li><li>planned stops</li><li>fishing/diving/activity area when there is no single destination</li><li>alternate destinations or safe stopping points when useful</li></ul>
            <h3>Timing</h3><p>Record:</p>
            <ul><li>departure date/time</li><li>expected arrival or return</li><li>planned check-ins</li><li>agreed overdue threshold or response expectation</li></ul>
            <p>These times are related, but they are <strong>not the same thing</strong>. The distinction is important enough to deserve its own section below.</p>
            <h3>Communications and safety information</h3><p>Depending on the craft and trip, useful information can include:</p>
            <ul><li>cellphone</li><li>marine VHF</li><li>DSC/MMSI information where appropriate</li><li>satellite messenger or phone</li><li>EPIRB or PLB</li><li>visual distress signals</li><li>life raft or other survival equipment for the voyage</li></ul>
            <p>This is not an equipment checklist for every boat. The purpose is to tell the shore contact and responders what communication and safety resources may actually be available.</p>
            <h3>Shore contact and response instructions</h3><p>Include:</p>
            <ul><li>name of the person holding the plan</li><li>reliable phone/email or other contact method</li><li>expected check-in/return</li><li>what the captain expects the contact to do if a check-in is missed</li><li>where the complete plan can be found</li></ul>
            <p>The holder should review these expectations before departure, not discover them after the deadline passes.</p>

            <figure class="fpw-float-guide-figure fpw-float-guide-anatomy" aria-labelledby="float-plan-anatomy-title">
              <h3 id="float-plan-anatomy-title">Anatomy of a Useful Float Plan</h3>
              <div class="fpw-float-guide-anatomy__center">USEFUL<br>FLOAT PLAN</div>
              <ul><li>Vessel / craft</li><li>Operator &amp; people aboard</li><li>Departure / access point</li><li>Route / destinations / stops</li><li>Timing / check-ins / overdue expectations</li><li>Communications &amp; safety equipment</li><li>Shore contact &amp; response instructions</li></ul>
              <figcaption>A useful plan connects the identifying, route, timing, communication, and shore-contact facts for the same trip.</figcaption>
            </figure>
          </section>

          <section id="who-should-hold-float-plan" aria-labelledby="who-should-hold-float-plan-title">
            <p class="fpw-float-guide-section-kicker">A responsible person ashore</p>
            <h2 id="who-should-hold-float-plan-title">5. Who should you leave a float plan with?</h2>
            <p>Choose a person who is <strong>reliable, reachable, and willing to act on the agreement</strong>.</p>
            <p>That may be:</p>
            <ul><li>a spouse or partner</li><li>family member</li><li>trusted friend</li><li>fellow boater</li><li>marina or yacht-club contact who has explicitly agreed to the role</li></ul>
            <p>The best shore contact is not necessarily the person you text most often. It is the person who will actually notice when the expected check-in or return does not happen and who understands what information they have.</p>
            <h3>Before you leave, make sure the person knows:</h3>
            <ol><li><strong>They are the shore contact.</strong></li><li><strong>Where the plan is.</strong></li><li><strong>When you expect to check in or return.</strong></li><li><strong>How you will report a route or timing change.</strong></li><li><strong>What you want them to do if you miss the agreed point.</strong></li><li><strong>That immediate known danger can require action sooner.</strong></li><li><strong>That you will close the plan when safely finished.</strong></li></ol>
            <blockquote><strong>Common mistake:</strong> Sending a plan to someone does not automatically make that person a prepared shore contact. Make sure they have agreed to the job.</blockquote>
          </section>

          <section id="timing-and-overdue" aria-labelledby="timing-and-overdue-title">
            <p class="fpw-float-guide-section-kicker">Three different points</p>
            <h2 id="timing-and-overdue-title">6. Check-in, expected return, and overdue threshold are different</h2>
            <p>This distinction is one of the most important parts of a practical float plan.</p>
            <h3>Planned check-in</h3><p>A <strong>check-in</strong> is a point when the captain expects to report status. It may be a particular time, destination, leg completion, or other planned checkpoint.</p>
            <p>Missing one check-in does not automatically describe the severity of the situation. Communications can fail and plans can change. The response should follow the trip-specific agreement and known facts.</p>
            <h3>Expected return or arrival</h3><p>The <strong>expected return</strong> is when the captain plans to finish the trip or reach the specified destination.</p>
            <p>It is an expectation, not a promise to continue an unsafe trip simply to stay on schedule.</p>
            <h3>Overdue threshold</h3><p>The <strong>overdue threshold</strong> is the agreed point at which the shore contact should follow the planned response if the boater has not checked in or returned.</p>
            <p>There is no universal “30-minute,” “one-hour,” or other grace period that is correct for every trip. Appropriate timing depends on the boat or craft, route, environment, weather, remoteness, communications, people aboard, and other circumstances.</p>
            <h3>Immediate danger overrides the schedule</h3><p>An agreed overdue time is not a reason to wait when credible information indicates someone may already be in immediate danger.</p>
            <p>Examples could include a distress message, known serious medical problem, severe-weather exposure, a report of a person in the water, or another specific fact indicating urgent risk.</p>
            <p>For the complete shore-contact response framework, read <a href="<cfoutput>#fpwFloatPlanBasePath#</cfoutput>/shore-contact-overdue-boater/" data-fpw-float-guide-related data-guide-key="shore_contact" data-placement="timing">What a Shore Contact Should Do When a Boater Is Overdue</a>.</p>

            <figure class="fpw-float-guide-figure fpw-float-guide-timeline" aria-labelledby="float-plan-timeline-title">
              <h3 id="float-plan-timeline-title">Check-In vs Expected Return vs Overdue Threshold</h3>
              <ol><li><strong>Departure</strong><span>trip begins</span></li><li><strong>Check-in</strong><span>planned report</span></li><li><strong>Expected return</strong><span>planned end</span></li><li><strong>Overdue threshold</strong><span>agreed response point</span></li></ol>
              <p class="fpw-float-guide-danger-note"><strong>Known immediate danger can require action before any planned threshold.</strong></p>
              <figcaption>There is no universal grace period. Timing should match the trip, and credible evidence of immediate danger overrides the schedule.</figcaption>
            </figure>
          </section>

          <section id="when-plans-change" aria-labelledby="when-plans-change-title">
            <p class="fpw-float-guide-section-kicker">Update the intent</p>
            <h2 id="when-plans-change-title">7. What if the boating plan changes?</h2>
            <p>Plans change. That is normal boating, not a failure of the float plan.</p>
            <p>Weather changes. A marina is full. A lock closes. A fishing area is unproductive. An anchorage becomes uncomfortable. Someone gets tired or seasick. The boat develops a minor problem. The captain simply decides to return early.</p>
            <p>A float plan should support good judgment—not pressure the captain to complete the original route at the expense of safety.</p>
            <p>When practical, update the shore contact after a meaningful change such as:</p>
            <ul><li>different destination</li><li>major route change</li><li>unexpected stop</li><li>substantial delay</li><li>early return</li><li>overnight stop that was not originally planned</li><li>abandonment or postponement of the trip</li></ul>
            <p>Tell the contact what changed and what timing is now current.</p>
            <h3>Close the plan</h3><p>When the trip is safely complete, tell the person holding the plan.</p>
            <p>A shore contact should not have to wonder whether the boater forgot to close the plan or is actually overdue.</p>
          </section>

          <section id="shore-contact-overdue" aria-labelledby="shore-contact-overdue-title">
            <p class="fpw-float-guide-section-kicker">Use facts, not speculation</p>
            <h2 id="shore-contact-overdue-title">8. What should a shore contact do if a boater is overdue?</h2>
            <p>The complete answer deserves its own guide, because the correct response depends on the trip and the known facts.</p>
            <p>At a high level, the shore contact should:</p>
            <ol><li>Review the actual float plan and agreed timing.</li><li>Attempt the agreed communication methods.</li><li>Check known factual updates without treating an old position or estimated progress as guaranteed current location.</li><li>Record relevant contact attempts and new information.</li><li>Reassess weather, darkness, medical concerns, route exposure, and other known risk factors.</li><li>Follow the agreed response and contact the appropriate emergency authority when warranted.</li><li>If there is reason to believe someone is in immediate danger, do not wait merely because a planned overdue threshold has not arrived.</li><li>Remain reachable and provide facts rather than speculation.</li></ol>
            <p class="fpw-float-guide-prominent-link"><a href="<cfoutput>#fpwFloatPlanBasePath#</cfoutput>/shore-contact-overdue-boater/" data-fpw-float-guide-related data-guide-key="shore_contact" data-placement="overdue_section">Read: What a Shore Contact Should Do When a Boater Is Overdue</a></p>
          </section>

          <section id="short-day-trip" aria-labelledby="short-day-trip-title">
            <p class="fpw-float-guide-section-kicker">Short trip, short plan</p>
            <h2 id="short-day-trip-title">9. Do you need a float plan for a short day trip?</h2>
            <p>A short trip can use a short plan.</p>
            <p>You do not need to turn every two-hour outing into a three-page exercise. But if someone would need to know where you went and when to expect you back, basic float-plan information can still be useful.</p>
            <p>For a simple local outing, a practical minimum may be:</p>
            <ul><li>exact departure/access point</li><li>boat/craft description or photo</li><li>operator and people aboard</li><li>destination or activity area</li><li>expected return</li><li>primary communication method</li><li>the person holding the plan</li></ul>
            <p>For a longer, remote, offshore, cold-water, paddle, or multi-stop trip, add the detail appropriate to the risk and complexity.</p>
            <p>The best plan is not the longest plan. It is the plan that contains the right information <strong>and is actually used</strong>.</p>
          </section>

          <section id="paper-vs-digital" aria-labelledby="paper-vs-digital-title">
            <p class="fpw-float-guide-section-kicker">Choose a usable format</p>
            <h2 id="paper-vs-digital-title">10. Paper float plan or digital float plan?</h2>
            <p>Both can work.</p>
            <p>The Coast Guard Auxiliary publishes a free float-plan form that remains an excellent official reference. A printed plan can be simple, durable, easy to hand to someone, and independent of a service after it is printed.</p>
            <p>A digital float-plan system can make other parts of the workflow easier:</p>
            <ul><li>reusing vessel and contact information</li><li>building route details</li><li>updating timing</li><li>sharing the plan</li><li>organizing check-ins or trip updates</li><li>keeping trip information readable on a phone</li></ul>
            <p>Digital tools also have failure modes: battery, connectivity, service availability, hardware, account access, and delivery problems. A digital float plan therefore does not replace VHF, DSC, a registered beacon where appropriate, appropriate navigation tools, or other safety equipment.</p>

            <figure class="fpw-float-guide-figure" aria-labelledby="paper-digital-table-title">
              <h3 id="paper-digital-table-title">Paper vs. Digital Float Plan</h3>
              <div class="fpw-float-guide-table-wrap"><table class="fpw-float-guide-table fpw-float-guide-table--responsive">
                <thead><tr><th scope="col">Capability</th><th scope="col">Paper / PDF</th><th scope="col">Digital system</th></tr></thead>
                <tbody>
                  <tr><th scope="row" data-label="Capability">Records trip details</th><td data-label="Paper / PDF">Yes</td><td data-label="Digital system">Yes</td></tr>
                  <tr><th scope="row" data-label="Capability">Works without an account</th><td data-label="Paper / PDF">Yes</td><td data-label="Digital system">Depends on system</td></tr>
                  <tr><th scope="row" data-label="Capability">Easy to print</th><td data-label="Paper / PDF">Yes</td><td data-label="Digital system">Usually</td></tr>
                  <tr><th scope="row" data-label="Capability">Reuse vessel/contact data</th><td data-label="Paper / PDF">Manual</td><td data-label="Digital system">Easier</td></tr>
                  <tr><th scope="row" data-label="Capability">Update changed trip details</th><td data-label="Paper / PDF">Requires new communication/document</td><td data-label="Digital system">Easier when connected</td></tr>
                  <tr><th scope="row" data-label="Capability">Share with multiple people</th><td data-label="Paper / PDF">Copy/email manually</td><td data-label="Digital system">Often easier</td></tr>
                  <tr><th scope="row" data-label="Capability">Depends on device/connectivity</th><td data-label="Paper / PDF">Less after printed</td><td data-label="Digital system">More</td></tr>
                  <tr><th scope="row" data-label="Capability">Replaces VHF/beacon/emergency services</th><td data-label="Paper / PDF">No</td><td data-label="Digital system">No</td></tr>
                </tbody>
              </table></div>
              <figcaption>The value of a digital system is convenience, organization, updates, and reuse—not that paper is unsafe.</figcaption>
            </figure>
            <h3>Where FloatPlanWizard fits</h3>
            <p>FloatPlanWizard is a boating trip-planning and communication tool. It helps recreational boaters organize the route, vessel, people, contacts, timing, and float-plan information and share selected trip information with trusted people.</p>
            <p>Depending on the trip and plan features in use, FPW can also support captain-reported check-ins, trip updates, and automated expected-check-in monitoring.</p>
            <p>FloatPlanWizard is <strong>not</strong> an emergency dispatch or rescue service. It does not guarantee continuous tracking, guarantee message delivery, determine that an emergency exists, or automatically replace official emergency communication.</p>
            <p><a class="fpw-float-guide-button fpw-float-guide-button--primary" href="<cfoutput>#fpwFloatPlanProductUrl#</cfoutput>" data-fpw-float-guide-cta data-cta-name="create_float_plan" data-placement="paper_vs_digital" data-auth-state="<cfoutput>#fpwFloatPlanAuthState#</cfoutput>"><cfoutput>#fpwFloatPlanProductCtaLabel#</cfoutput></a></p>
          </section>

          <section id="common-float-plan-mistakes" aria-labelledby="common-float-plan-mistakes-title">
            <p class="fpw-float-guide-section-kicker">Avoidable gaps</p>
            <h2 id="common-float-plan-mistakes-title">11. Common float-plan mistakes</h2>
            <div class="fpw-float-guide-mistakes">
              <section><h3>1. Keeping the only copy on the boat</h3><p>The whole point is that someone <strong>ashore</strong> has the information.</p></section>
              <section><h3>2. Sending it to someone who does not know they are responsible</h3><p>A recipient is not automatically a prepared shore contact.</p></section>
              <section><h3>3. Using a vague return time</h3><p>“Back tonight” is much less useful than a clear expected return and an agreed response point.</p></section>
              <section><h3>4. Describing the route too vaguely</h3><p>“Going fishing” can cover a huge area. Record the likely route or activity area.</p></section>
              <section><h3>5. Using a generic boat description</h3><p>A photo and distinctive details are more useful than “white boat.”</p></section>
              <section><h3>6. Forgetting who actually boarded</h3><p>Update the plan when the passenger list changes.</p></section>
              <section><h3>7. Treating a GPS dot as infallible</h3><p>A last report is a report from a particular time. It is not proof of the boat's current position.</p></section>
              <section><h3>8. Failing to update a meaningful route or timing change</h3><p>A stale plan can create confusion.</p></section>
              <section><h3>9. Failing to close the plan after returning</h3><p>Do not leave the shore contact wondering whether you are safe or overdue.</p></section>
              <section><h3>10. Treating the float plan as a replacement for emergency equipment</h3><p>It is one layer of preparation, not a substitute for life jackets, navigation, marine communications, weather judgment, distress signaling, or seamanship.</p></section>
            </div>
          </section>

          <section id="float-plan-vs-safety-tools" aria-labelledby="float-plan-vs-safety-tools-title">
            <p class="fpw-float-guide-section-kicker">Complementary layers</p>
            <h2 id="float-plan-vs-safety-tools-title">12. Float plan vs. other boating-safety tools</h2>
            <h3>Float plan vs. pre-departure checklist</h3><p>A <strong>pre-departure checklist</strong> asks: <em>Are the boat, people, equipment, weather decision, and supplies ready to leave?</em></p>
            <p>A <strong>float plan</strong> asks: <em>What does someone ashore need to know about this trip if concern develops?</em></p><p>They work together.</p>
            <h3>Float plan vs. passage or route plan</h3><p>A <strong>passage/route plan</strong> helps the operator plan and navigate the trip.</p><p>A <strong>float plan</strong> communicates the intended trip to someone ashore.</p><p>A route can be part of the float plan, but the documents have different jobs.</p>
            <h3>Float plan vs. GPS tracker</h3><p>A tracker can provide reported position information when the device, power, coverage, and service are working.</p><p>A float plan records the intended route, people, boat, timing, and other facts that a location dot alone does not explain.</p><p>Use them as complementary layers.</p>
            <h3>Float plan vs. VHF / DSC</h3><p>Marine VHF and Digital Selective Calling are emergency and marine-communication tools. A float plan does not transmit a distress call.</p>
            <h3>Float plan vs. EPIRB / PLB</h3><p>A properly registered beacon can directly alert the search-and-rescue system when activated. A float plan gives a shore contact and responders broader context about the intended trip, vessel, and people aboard.</p><p>One does not make the other unnecessary.</p>

            <figure class="fpw-float-guide-figure fpw-float-guide-layers" aria-labelledby="safety-layers-title">
              <h3 id="safety-layers-title">Safety Layers: What a Float Plan Does and Does Not Replace</h3>
              <ol><li>Prevention &amp; judgment</li><li>Life jackets / gear</li><li>VHF / DSC / beacon / phone</li><li>Float plan + shore contact</li><li>Emergency response</li></ol>
              <figcaption>A float plan is one safety layer. It does not replace seamanship, communications, life jackets, navigation, weather judgment, or emergency signaling equipment.</figcaption>
            </figure>
          </section>

          <section id="day-trip-example" aria-labelledby="day-trip-example-title">
            <p class="fpw-float-guide-section-kicker">A practical example</p>
            <h2 id="day-trip-example-title">13. Example: a useful float plan for a simple day trip</h2>
            <p>A practical example helps show that a useful plan does not have to become bureaucratic.</p>
            <article class="fpw-float-guide-sample-plan" aria-label="Example day-trip float plan">
              <section><h3>Trip</h3><dl><div><dt>Plan name</dt><dd>Saturday Bay Fishing Trip</dd></div><div><dt>Departure</dt><dd>Harbor Public Ramp, 7:30 AM</dd></div><div><dt>Activity area</dt><dd>Main channel to the north bay flats; fishing within approximately the planned bay area</dd></div><div><dt>Expected return</dt><dd>2:30 PM</dd></div><div><dt>Check-in</dt><dd>Text at lunch if plans change materially</dd></div><div><dt>Overdue expectation</dt><dd>Pre-agreed with shore contact for this trip</dd></div></dl></section>
              <section><h3>Boat</h3><dl><div><dt>Vessel</dt><dd>22-foot center console</dd></div><div><dt>Color</dt><dd>White hull, dark-blue T-top</dd></div><div><dt>Registration</dt><dd>Recorded in full plan</dd></div><div><dt>Photo</dt><dd>Current vessel photo attached</dd></div></dl></section>
              <section><h3>People</h3><dl><div><dt>Operator</dt><dd>Captain recorded in plan</dd></div><div><dt>Passengers</dt><dd>Two adults</dd></div><div><dt>Emergency contacts</dt><dd>Recorded in plan</dd></div></dl></section>
              <section><h3>Communications / equipment</h3><dl><div><dt>Primary</dt><dd>Fixed marine VHF</dd></div><div><dt>Backup</dt><dd>Charged waterproof phone</dd></div><div><dt>Other</dt><dd>Appropriate life jackets and required safety equipment aboard</dd></div></dl></section>
              <section><h3>Shore contact</h3><dl><div><dt>Holder</dt><dd>Trusted family member who has agreed to the role</dd></div><div><dt>Instructions</dt><dd>Knows expected return, knows where the full plan is, and has the FPW shore-contact guide</dd></div></dl></section>
              <section><h3>If the trip changes</h3><p>If the captain moves to a different fishing area or expects to return substantially later, the shore contact receives an updated time and location/route description.</p></section>
              <section><h3>When complete</h3><p>Captain closes the plan and tells the shore contact the boat is safely back.</p></section>
            </article>
          </section>

          <section id="float-plan-checklist" class="fpw-float-guide-checklist" aria-labelledby="float-plan-checklist-title">
            <p class="fpw-float-guide-section-kicker">Before departure</p>
            <div class="fpw-float-guide-heading-actions"><h2 id="float-plan-checklist-title">14. Float plan checklist</h2><button type="button" class="fpw-float-guide-print-button" data-fpw-float-guide-print>Print this checklist</button></div>
            <section><h3>Trip</h3><ul><li><label><input type="checkbox"> Exact departure/access point recorded</label></li><li><label><input type="checkbox"> Destination, route, or activity area recorded</label></li><li><label><input type="checkbox"> Important planned stops recorded</label></li><li><label><input type="checkbox"> Expected return/arrival recorded</label></li><li><label><input type="checkbox"> Planned check-ins recorded where applicable</label></li><li><label><input type="checkbox"> Overdue expectations agreed with shore contact</label></li><li><label><input type="checkbox"> Meaningful alternate destination/landing noted where useful</label></li></ul></section>
            <section><h3>Boat / craft</h3><ul><li><label><input type="checkbox"> Current photo available</label></li><li><label><input type="checkbox"> Make/model/type/length recorded</label></li><li><label><input type="checkbox"> Primary colors and distinctive features recorded</label></li><li><label><input type="checkbox"> Registration/documentation recorded where applicable</label></li></ul></section>
            <section><h3>People</h3><ul><li><label><input type="checkbox"> Operator recorded</label></li><li><label><input type="checkbox"> People aboard are current</label></li><li><label><input type="checkbox"> Appropriate emergency contacts available</label></li><li><label><input type="checkbox"> Relevant voluntarily provided emergency information is current</label></li></ul></section>
            <section><h3>Communication / safety</h3><ul><li><label><input type="checkbox"> Primary communication method recorded</label></li><li><label><input type="checkbox"> Backup method recorded where appropriate</label></li><li><label><input type="checkbox"> Relevant beacon/radio information recorded where appropriate</label></li><li><label><input type="checkbox"> Important safety/survival equipment recorded for the trip</label></li></ul></section>
            <section><h3>Shore contact</h3><ul><li><label><input type="checkbox"> Shore contact agreed to the role</label></li><li><label><input type="checkbox"> Shore contact has the current plan</label></li><li><label><input type="checkbox"> Contact understands check-in/return timing</label></li><li><label><input type="checkbox"> Contact understands what to do if concern develops</label></li><li><label><input type="checkbox"> Contact has access to FPW's overdue-boater guide</label></li></ul></section>
            <section><h3>When the trip changes</h3><ul><li><label><input type="checkbox"> Meaningful route/destination change communicated</label></li><li><label><input type="checkbox"> Major delay communicated</label></li><li><label><input type="checkbox"> Early return communicated where helpful</label></li></ul></section>
            <section><h3>When the trip ends</h3><ul><li><label><input type="checkbox"> Plan closed</label></li><li><label><input type="checkbox"> Shore contact told the trip is safely complete</label></li></ul></section>
          </section>

          <section id="float-plan-faq" class="fpw-float-guide-faq" aria-labelledby="float-plan-faq-title">
            <p class="fpw-float-guide-section-kicker">Questions boaters ask</p>
            <h2 id="float-plan-faq-title">15. Frequently asked questions</h2>
            <section><h3>What is a float plan?</h3><p>A float plan is a written record of a boating trip that describes the boat or craft, people aboard, intended route or operating area, timing, and other information that could be useful if the boater becomes overdue or unreachable. It is left with a responsible person ashore.</p></section>
            <section><h3>Do you file a float plan with the Coast Guard?</h3><p>No. The U.S. Coast Guard does not accept recreational float plans. Leave the plan with a reliable person ashore who has agreed to hold it and understands the expected response.</p></section>
            <section><h3>Is a float plan legally required?</h3><p>A float plan is generally a recommended recreational-boating safety practice rather than a universal federal filing requirement. Laws and requirements can vary by activity and jurisdiction, so verify current local requirements where you operate.</p></section>
            <section><h3>Who should hold my float plan?</h3><p>A reliable, reachable person ashore who understands the trip, knows when you expect to check in or return, has access to the plan, and has agreed to follow the response plan if concern develops.</p></section>
            <section><h3>Do I need a float plan for a short boating trip?</h3><p>A short outing can use a short plan. Record the essential facts—where you launched, where you intend to go, what craft you are using, who is aboard, and when to expect you back.</p></section>
            <section><h3>Can I text someone my float plan?</h3><p>For a simple trip, a written text containing the necessary information can function as a basic float plan if the recipient has agreed to be the shore contact and the information is complete enough for the trip. A structured form or digital plan makes it easier to avoid omissions and reuse information.</p></section>
            <section><h3>What should be included in a float plan?</h3><p>Include the vessel/craft description and photo, operator and people aboard, exact departure point, intended route/destination/stops, departure and expected return, check-ins and overdue expectations, communications and relevant safety equipment, shore contact, and response instructions.</p></section>
            <section><h3>Should I include medical information?</h3><p>Only when it is relevant, appropriate, and voluntarily provided. Do not collect or share sensitive information without a clear reason. The goal is to make useful emergency information available, not to create an unnecessary personal-data file.</p></section>
            <section><h3>What if my route changes?</h3><p>Update the shore contact after a meaningful route, destination, timing, or overnight change when practical. A float plan records intent; it should never pressure the operator to continue an unsafe route merely to meet the original schedule.</p></section>
            <section><h3>When should I close a float plan?</h3><p>Close it when the trip is safely complete or when responsibility for the plan has been intentionally transferred. Tell the person holding it that you are safely finished.</p></section>
            <section><h3>Does GPS tracking replace a float plan?</h3><p>No. Tracking can provide position reports when the device and service are working. A float plan records broader context—boat, people, route, timing, communications, and intent. The two can complement one another.</p></section>
            <section><h3>Does a float plan replace a VHF radio or emergency beacon?</h3><p>No. A float plan does not send a distress alert. VHF/DSC, EPIRBs/PLBs, phones, satellite devices, and visual/sound signals have different emergency-communication roles.</p></section>
            <section><h3>What is the difference between a float plan and a passage plan?</h3><p>A passage or route plan is primarily for planning and navigating the voyage aboard the boat. A float plan is primarily for communicating the intended trip to a responsible person ashore. A float plan may summarize route information from the passage plan.</p></section>
            <section><h3>What should my shore contact do if I am overdue?</h3><p>They should follow the agreed trip-specific response, review the known facts, attempt the planned communication methods, and contact the appropriate emergency authority when warranted. If there is credible evidence of immediate danger, they should not wait merely because a planned overdue time has not arrived. Read FPW's <a href="<cfoutput>#fpwFloatPlanBasePath#</cfoutput>/shore-contact-overdue-boater/" data-fpw-float-guide-related data-guide-key="shore_contact" data-placement="faq">complete shore-contact overdue guide</a>.</p></section>
          </section>

          <section id="sources" class="fpw-float-guide-sources" aria-labelledby="sources-title">
            <p class="fpw-float-guide-section-kicker">Sources and limitations</p>
            <h2 id="sources-title">16. Official sources and editorial limitations</h2>
            <p><strong>Reviewed:</strong> August 30, 2026</p>
            <p>Primary official sources for this guide:</p>
            <ul>
              <li><a href="https://uscgboating.org/recreational-boaters/floating-plan.php" target="_blank" rel="noopener noreferrer" data-fpw-float-guide-source data-source-org="uscg" data-section-id="sources">U.S. Coast Guard Boating Safety Division — Float Plan</a></li>
              <li><a href="https://floatplancentral.cgaux.org/" target="_blank" rel="noopener noreferrer" data-fpw-float-guide-source data-source-org="uscg_auxiliary" data-section-id="sources">U.S. Coast Guard Auxiliary — Float Plan Central</a></li>
              <li><a href="https://floatplancentral.cgaux.org/download/USCGFloatPlan.pdf" target="_blank" rel="noopener noreferrer" data-fpw-float-guide-source data-source-org="uscg_auxiliary" data-section-id="sources">U.S. Coast Guard Auxiliary — Official USCG Float Plan PDF</a></li>
              <li><a href="https://floatplancentral.cgaux.org/classroom/definition.htm" target="_blank" rel="noopener noreferrer" data-fpw-float-guide-source data-source-org="uscg_auxiliary" data-section-id="sources">U.S. Coast Guard Auxiliary — Official Definition</a></li>
              <li><a href="https://floatplancentral.cgaux.org/classroom/how_it_works.htm" target="_blank" rel="noopener noreferrer" data-fpw-float-guide-source data-source-org="uscg_auxiliary" data-section-id="sources">U.S. Coast Guard Auxiliary — Preparing Your Plan / How It Works</a></li>
              <li><a href="https://floatplancentral.cgaux.org/FAQ.htm" target="_blank" rel="noopener noreferrer" data-fpw-float-guide-source data-source-org="uscg_auxiliary" data-section-id="sources">U.S. Coast Guard Auxiliary — Float Plan FAQ</a></li>
              <li><a href="https://navcen.uscg.gov/radio-information-for-boaters" target="_blank" rel="noopener noreferrer" data-fpw-float-guide-source data-source-org="uscg_navcen" data-section-id="sources">U.S. Coast Guard Navigation Center — Radio Information for Boaters</a></li>
              <li><a href="https://www.sarsat.noaa.gov/register-your-beacon/" target="_blank" rel="noopener noreferrer" data-fpw-float-guide-source data-source-org="noaa_sarsat" data-section-id="sources">NOAA SARSAT — Register Your Beacon</a></li>
            </ul>
            <div class="fpw-float-guide-editorial-note"><h3>Editorial note</h3>
              <p>This U.S.-focused guide provides general recreational-boating education. It is not a substitute for current laws, seamanship training, navigation, official weather information, manufacturer guidance, marine communications training, or instructions from emergency authorities. Requirements and recommended procedures can vary by vessel, activity, location, and jurisdiction.</p>
              <p>FloatPlanWizard is a planning and communication tool. It does not guarantee continuous tracking, guarantee message delivery, verify that an emergency exists, automatically dispatch rescue, or replace appropriate emergency communications.</p>
              <p>Links to official resources identify the source of guidance and do not imply official endorsement of FloatPlanWizard.</p>
            </div>
          </section>

          <section id="related-guides" class="fpw-float-guide-related" aria-labelledby="related-guides-title">
            <p class="fpw-float-guide-section-kicker">Continue planning</p>
            <h2 id="related-guides-title">Related guides and tools</h2>
            <div class="fpw-float-guide-related__grid">
              <a href="<cfoutput>#fpwFloatPlanBasePath#</cfoutput>/shore-contact-overdue-boater/" data-fpw-float-guide-related data-guide-key="shore_contact" data-placement="related_guides"><strong>Shore Contact / Overdue Boater Guide</strong><span>Use the plan when a boater is overdue.</span></a>
              <a href="<cfoutput>#fpwFloatPlanBasePath#</cfoutput>/solo-boating-safety-guide/" data-fpw-float-guide-related data-guide-key="solo_safety" data-placement="related_guides"><strong>Solo Boating Safety Guide</strong><span>Build practical safety layers for boating alone.</span></a>
              <a href="<cfoutput>#fpwFloatPlanBasePath#</cfoutput>/common-boating-emergencies/" data-fpw-float-guide-related data-guide-key="common_emergencies" data-placement="related_guides"><strong>Common Boating Emergencies</strong><span>Review practical first actions when something goes wrong.</span></a>
              <a href="<cfoutput>#fpwFloatPlanBasePath#</cfoutput>/boat-fuel-calculator/" data-fpw-float-guide-related data-guide-key="fuel_calculator" data-placement="related_guides"><strong>Boat Fuel Calculator</strong><span>Estimate fuel, range, reserve, time, and cost.</span></a>
              <a href="<cfoutput>#fpwFloatPlanProductUrl#</cfoutput>" data-fpw-float-guide-cta data-cta-name="plan_trip" data-placement="related_guides" data-auth-state="<cfoutput>#fpwFloatPlanAuthState#</cfoutput>"><strong><cfoutput>#fpwFloatPlanProductCtaLabel#</cfoutput></strong><span>Plan the current route in FPW.</span></a>
              <a href="<cfoutput>#fpwFloatPlanBasePath#</cfoutput>/how-it-works/" data-fpw-float-guide-related data-guide-key="how_it_works" data-placement="related_guides"><strong>How It Works</strong><span>See how FPW connects planning, sharing, and trip updates.</span></a>
            </div>
          </section>

          <section id="create-your-float-plan" class="fpw-float-guide-final-cta" aria-labelledby="create-your-float-plan-title">
            <p class="fpw-float-guide-section-kicker">FloatPlanWizard</p>
            <h2 id="create-your-float-plan-title">Make the next float plan easier to use—not easier to skip</h2>
            <p>A useful float plan should be simple enough to become part of the normal boating routine and complete enough to help the person waiting ashore understand the trip.</p>
            <p>FloatPlanWizard helps organize the route, boat, people, contacts, timing, and float-plan details so you can prepare ahead of departure, reuse information you should not have to retype, and share the current plan with trusted people.</p>
            <div class="fpw-float-guide-actions"><a class="fpw-float-guide-button fpw-float-guide-button--primary" href="<cfoutput>#fpwFloatPlanProductUrl#</cfoutput>" data-fpw-float-guide-cta data-cta-name="create_float_plan" data-placement="final_cta" data-auth-state="<cfoutput>#fpwFloatPlanAuthState#</cfoutput>"><cfoutput>#fpwFloatPlanProductCtaLabel#</cfoutput></a></div>
            <p class="fpw-float-guide-supporting-links"><a href="<cfoutput>#fpwFloatPlanBasePath#</cfoutput>/shore-contact-overdue-boater/" data-fpw-float-guide-related data-guide-key="shore_contact" data-placement="final_cta">Shore Contact Guide</a><span aria-hidden="true">·</span><a href="<cfoutput>#fpwFloatPlanBasePath#</cfoutput>/solo-boating-safety-guide/" data-fpw-float-guide-related data-guide-key="solo_safety" data-placement="final_cta">Solo Boating Safety Guide</a><span aria-hidden="true">·</span><a href="<cfoutput>#fpwFloatPlanBasePath#</cfoutput>/common-boating-emergencies/" data-fpw-float-guide-related data-guide-key="common_emergencies" data-placement="final_cta">Common Boating Emergencies</a></p>
          </section>
        </div>
      </div>
    </article>
  </div>
</main>

<cfinclude template="includes/footer.cfm">
<cfoutput><script src="#fpwFloatPlanBasePath#/assets/js/float-plan-guide.js?v=20260830-pillar-v1" defer></script></cfoutput>
</body>
</html>
