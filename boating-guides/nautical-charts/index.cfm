<cfprocessingdirective pageencoding="utf-8">
<cfsetting showdebugoutput="false" requesttimeout="30">
<cfcontent type="text/html; charset=utf-8">
<cfinclude template="../../includes/fpw_base_path.cfm">

<cfscript>
request.fpwTopNavActive = "";

schemaAtKey = chr(64);
schemaTypeKey = schemaAtKey & "type";
schemaIdKey = schemaAtKey & "id";
schemaContextKey = schemaAtKey & "context";
schemaGraphKey = schemaAtKey & "graph";

fpwGuideCanonicalUrl = "https://floatplanwizard.com/boating-guides/nautical-charts/";
fpwGuidePageTitle = "How to Read NOAA Nautical Charts and Aids to Navigation | FloatPlanWizard";
fpwGuidePageDescription = "Learn how to read NOAA nautical charts, chart symbols, buoys, daymarks, depths, hazards, and aids to navigation before planning your next boat trip.";
fpwGuideAssetBase = request.fpwBase & "/assets/images/boating-guides/nautical-charts";
fpwGuideJoinUrl = request.fpwBase & "/app/join.cfm";
fpwGuideWhyFloatPlanUrl = request.fpwBase & "/why-use-a-float-plan/";
fpwGuideLocksUrl = request.fpwBase & "/great-loop/locks/";
fpwGuideBridgesUrl = request.fpwBase & "/great-loop/bridges/";
fpwGuideFuelUrl = request.fpwBase & "/boat-fuel-calculator/";
fpwGuideCssUrl = request.fpwBase & "/assets/css/nautical-chart-guide.css?v=20260619-cta";
fpwGuideHeroImage = fpwGuideAssetBase & "/hero-nautical-chart.svg";
fpwGuideOverviewImage = fpwGuideAssetBase & "/chart-overview.svg";

function fpwGuideSchemaRef(required string idValue) {
  var out = structNew("ordered");
  structInsert(out, schemaIdKey, arguments.idValue, true);
  return out;
}

function fpwGuideSchemaListItem(required numeric position, required string name, required string urlValue) {
  var out = structNew("ordered");
  var item = structNew("ordered");
  structInsert(out, schemaTypeKey, "ListItem", true);
  out["position"] = arguments.position;
  structInsert(item, schemaIdKey, arguments.urlValue, true);
  item["name"] = arguments.name;
  out["item"] = item;
  return out;
}

function fpwGuideSchemaNameListItem(required numeric position, required string name) {
  var out = structNew("ordered");
  structInsert(out, schemaTypeKey, "ListItem", true);
  out["position"] = arguments.position;
  out["name"] = arguments.name;
  return out;
}

function fpwGuideSchemaQuestion(required string questionText, required string answerText) {
  var question = structNew("ordered");
  var answer = structNew("ordered");
  structInsert(question, schemaTypeKey, "Question", true);
  question["name"] = arguments.questionText;
  structInsert(answer, schemaTypeKey, "Answer", true);
  answer["text"] = arguments.answerText;
  question["acceptedAnswer"] = answer;
  return question;
}

function fpwGuideIconHref(required string iconId) {
  return fpwGuideAssetBase & "/icon-set.svg" & chr(35) & arguments.iconId;
}

fpwGuideFaqItems = [
  {
    "question" = "What is a nautical chart?",
    "answer" = "A nautical chart is a detailed map of water areas that shows depths, hazards, navigation aids, shorelines, and other important information for safe navigation."
  },
  {
    "question" = "What are aids to navigation?",
    "answer" = "Aids to navigation are markers, buoys, lights, and other devices that help boaters identify safe channels, hazards, and important locations on the water."
  },
  {
    "question" = "Are NOAA electronic charts used by recreational boaters?",
    "answer" = "Yes. Many modern chartplotters and navigation systems use electronic chart data for recreational boating."
  },
  {
    "question" = "Does FloatPlanWizard replace official charts?",
    "answer" = "No. FloatPlanWizard helps organize trip planning and float plan details after boaters review official charts and current conditions."
  },
  {
    "question" = "What is U.S. Chart No. 1?",
    "answer" = "It is NOAA's reference for nautical chart symbols, abbreviations, and terms."
  },
  {
    "question" = "How does chart reading help with float plans?",
    "answer" = "It helps identify the route, checkpoints, shallow areas, bridges, locks, fuel stops, and bailout options."
  }
];

fpwGuideGraph = [];
fpwGuideOrg = structNew("ordered");
fpwGuideSite = structNew("ordered");
fpwGuideBreadcrumb = structNew("ordered");
fpwGuideCollectionPage = structNew("ordered");
fpwGuideItemList = structNew("ordered");
fpwGuideFaqPage = structNew("ordered");
fpwGuideJsonLd = structNew("ordered");

structInsert(fpwGuideOrg, schemaTypeKey, "Organization", true);
structInsert(fpwGuideOrg, schemaIdKey, "https://floatplanwizard.com/##organization", true);
fpwGuideOrg["name"] = "FloatPlanWizard";
fpwGuideOrg["url"] = "https://floatplanwizard.com/";
fpwGuideOrg["logo"] = "https://floatplanwizard.com/assets/images/checkout/floatplanwizard-logo.jpg";
arrayAppend(fpwGuideGraph, fpwGuideOrg);

structInsert(fpwGuideSite, schemaTypeKey, "WebSite", true);
structInsert(fpwGuideSite, schemaIdKey, "https://floatplanwizard.com/##website", true);
fpwGuideSite["url"] = "https://floatplanwizard.com/";
fpwGuideSite["name"] = "FloatPlanWizard";
fpwGuideSite["publisher"] = fpwGuideSchemaRef("https://floatplanwizard.com/##organization");
arrayAppend(fpwGuideGraph, fpwGuideSite);

structInsert(fpwGuideBreadcrumb, schemaTypeKey, "BreadcrumbList", true);
structInsert(fpwGuideBreadcrumb, schemaIdKey, fpwGuideCanonicalUrl & "##breadcrumb", true);
fpwGuideBreadcrumb["itemListElement"] = [
  fpwGuideSchemaListItem(1, "Home", "https://floatplanwizard.com/"),
  fpwGuideSchemaNameListItem(2, "Boating Guides"),
  fpwGuideSchemaListItem(3, "Nautical Charts", fpwGuideCanonicalUrl)
];
arrayAppend(fpwGuideGraph, fpwGuideBreadcrumb);

structInsert(fpwGuideItemList, schemaTypeKey, "ItemList", true);
structInsert(fpwGuideItemList, schemaIdKey, fpwGuideCanonicalUrl & "##guide-topics", true);
fpwGuideItemList["name"] = "Nautical Chart Guide Topics";
fpwGuideItemList["itemListElement"] = [
  fpwGuideSchemaListItem(1, "How to Read a Nautical Chart", fpwGuideCanonicalUrl & "##what-nautical-charts-show"),
  fpwGuideSchemaListItem(2, "Nautical Chart Symbols", fpwGuideCanonicalUrl & "##chart-symbol-explorer"),
  fpwGuideSchemaListItem(3, "Aids to Navigation", fpwGuideCanonicalUrl & "##aids-to-navigation"),
  fpwGuideSchemaListItem(4, "Red Right Returning", fpwGuideCanonicalUrl & "##red-right-returning"),
  fpwGuideSchemaListItem(5, "Pre-Departure Chart Checklist", fpwGuideCanonicalUrl & "##from-chart-to-float-plan"),
  fpwGuideSchemaListItem(6, "From Chart Notes to Float Plan", "https://floatplanwizard.com/why-use-a-float-plan/")
];
arrayAppend(fpwGuideGraph, fpwGuideItemList);

structInsert(fpwGuideCollectionPage, schemaTypeKey, "CollectionPage", true);
structInsert(fpwGuideCollectionPage, schemaIdKey, fpwGuideCanonicalUrl & "##collectionpage", true);
fpwGuideCollectionPage["url"] = fpwGuideCanonicalUrl;
fpwGuideCollectionPage["name"] = fpwGuidePageTitle;
fpwGuideCollectionPage["description"] = fpwGuidePageDescription;
fpwGuideCollectionPage["isPartOf"] = fpwGuideSchemaRef("https://floatplanwizard.com/##website");
fpwGuideCollectionPage["publisher"] = fpwGuideSchemaRef("https://floatplanwizard.com/##organization");
fpwGuideCollectionPage["breadcrumb"] = fpwGuideSchemaRef(fpwGuideCanonicalUrl & "##breadcrumb");
fpwGuideCollectionPage["mainEntity"] = fpwGuideSchemaRef(fpwGuideCanonicalUrl & "##guide-topics");
arrayAppend(fpwGuideGraph, fpwGuideCollectionPage);

structInsert(fpwGuideFaqPage, schemaTypeKey, "FAQPage", true);
structInsert(fpwGuideFaqPage, schemaIdKey, fpwGuideCanonicalUrl & "##faq", true);
fpwGuideFaqPage["mainEntity"] = [];
for (fpwGuideFaqItem in fpwGuideFaqItems) {
  arrayAppend(fpwGuideFaqPage["mainEntity"], fpwGuideSchemaQuestion(fpwGuideFaqItem.question, fpwGuideFaqItem.answer));
}
arrayAppend(fpwGuideGraph, fpwGuideFaqPage);

structInsert(fpwGuideJsonLd, schemaContextKey, "https://schema.org", true);
structInsert(fpwGuideJsonLd, schemaGraphKey, fpwGuideGraph, true);
fpwGuideJsonLdText = replace(serializeJSON(fpwGuideJsonLd), "</", "<\/", "all");
</cfscript>

<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title><cfoutput>#encodeForHTML(fpwGuidePageTitle)#</cfoutput></title>
  <meta name="description" content="<cfoutput>#encodeForHTMLAttribute(fpwGuidePageDescription)#</cfoutput>">
  <link rel="canonical" href="<cfoutput>#encodeForHTMLAttribute(fpwGuideCanonicalUrl)#</cfoutput>">
  <meta property="og:type" content="website">
  <meta property="og:site_name" content="FloatPlanWizard">
  <meta property="og:url" content="<cfoutput>#encodeForHTMLAttribute(fpwGuideCanonicalUrl)#</cfoutput>">
  <meta property="og:title" content="<cfoutput>#encodeForHTMLAttribute(fpwGuidePageTitle)#</cfoutput>">
  <meta property="og:description" content="<cfoutput>#encodeForHTMLAttribute(fpwGuidePageDescription)#</cfoutput>">
  <meta property="og:image" content="https://floatplanwizard.com/assets/images/social/floatplanwizard-social-preview-20260602.png">
  <meta property="og:image:secure_url" content="https://floatplanwizard.com/assets/images/social/floatplanwizard-social-preview-20260602.png">
  <meta property="og:image:type" content="image/png">
  <meta property="og:image:width" content="1200">
  <meta property="og:image:height" content="630">
  <meta property="og:image:alt" content="FloatPlanWizard boating trip planning and monitored float plan preview image">
  <meta name="twitter:card" content="summary_large_image">
  <meta name="twitter:title" content="<cfoutput>#encodeForHTMLAttribute(fpwGuidePageTitle)#</cfoutput>">
  <meta name="twitter:description" content="<cfoutput>#encodeForHTMLAttribute(fpwGuidePageDescription)#</cfoutput>">
  <meta name="twitter:image" content="https://floatplanwizard.com/assets/images/social/floatplanwizard-social-preview-20260602.png">
  <meta name="twitter:image:alt" content="FloatPlanWizard boating trip planning and monitored float plan preview image">
  <script type="application/ld+json"><cfoutput>#fpwGuideJsonLdText#</cfoutput></script>
  <cfinclude template="../../includes/header_styles.cfm">
  <link rel="stylesheet" href="<cfoutput>#encodeForHTMLAttribute(fpwGuideCssUrl)#</cfoutput>">
  <cfinclude template="../../includes/analytics_ga4.cfm">
</head>
<body id="top" class="fpw-nautical-guide-body">
  <cfinclude template="../../includes/top_nav.cfm">

  <main class="chart-guide-page">
    <nav class="fpw-guide-breadcrumb" aria-label="Breadcrumb">
      <a href="<cfoutput>#encodeForHTMLAttribute(request.fpwBase)#</cfoutput>/">Home</a>
      <span aria-hidden="true">/</span>
      <span>Boating Guides</span>
      <span aria-hidden="true">/</span>
      <strong>Nautical Charts</strong>
    </nav>

    <section class="hero surface">
      <div class="hero-copy">
        <p class="eyebrow">Boating navigation basics</p>
        <h1>How to Read Nautical Charts and Aids to Navigation</h1>
        <p class="lede">Nautical charts help boaters understand depths, hazards, channels, aids to navigation, and route planning before they leave the dock.</p>
        <div class="button-row">
          <a class="btn primary" href="<cfoutput>#encodeForHTMLAttribute(fpwGuideJoinUrl)#</cfoutput>"><span aria-hidden="true">⌖</span>Create a Float Plan</a>
          <a class="btn secondary" href="<cfoutput>#encodeForHTMLAttribute(fpwGuideJoinUrl)#</cfoutput>"><span aria-hidden="true">⤳</span>Explore Route Builder</a>
        </div>
      </div>
      <div class="hero-art" aria-label="Illustrated nautical chart route map">
        <img src="<cfoutput>#encodeForHTMLAttribute(fpwGuideHeroImage)#</cfoutput>" alt="Illustrated nautical chart with route line, buoys, bridge, lock and safe return plan card">
      </div>
    </section>

    <aside class="safety-strip" role="note">
      <svg aria-hidden="true"><use href="<cfoutput>#encodeForHTMLAttribute(fpwGuideIconHref('icon-warning'))#</cfoutput>"></use></svg>
      Planning reference only. Always verify with current official charts, local conditions, tides, weather, and prudent seamanship.
    </aside>

    <section class="overview-grid">
      <article class="info-panel surface chart-overview-panel" id="what-nautical-charts-show">
        <h2>What nautical charts show</h2>
        <div class="chart-overview-layout">
          <div class="callout-list left">
            <div class="callout"><svg aria-hidden="true"><use href="<cfoutput>#encodeForHTMLAttribute(fpwGuideIconHref('icon-depth'))#</cfoutput>"></use></svg><span><b>Depths</b>Water depth helps you plan your route.</span></div>
            <div class="callout"><svg aria-hidden="true"><use href="<cfoutput>#encodeForHTMLAttribute(fpwGuideIconHref('icon-warning'))#</cfoutput>"></use></svg><span><b>Hazards</b>Rocks, shoals, wrecks, and obstructions to avoid.</span></div>
            <div class="callout"><svg aria-hidden="true"><use href="<cfoutput>#encodeForHTMLAttribute(fpwGuideIconHref('icon-buoy'))#</cfoutput>"></use></svg><span><b>Markers</b>Buoys, beacons, and lights guide you safely.</span></div>
            <div class="callout"><span class="round-icon" aria-hidden="true">⚓</span><span><b>Landmarks</b>Visible references on shore to orient your position.</span></div>
          </div>
          <img class="overview-art" src="<cfoutput>#encodeForHTMLAttribute(fpwGuideOverviewImage)#</cfoutput>" alt="Circular nautical chart infographic">
          <div class="callout-list right">
            <div class="callout"><svg aria-hidden="true"><use href="<cfoutput>#encodeForHTMLAttribute(fpwGuideIconHref('icon-bridge'))#</cfoutput>"></use></svg><span><b>Bridges</b>Clearances are essential for safe passage.</span></div>
            <div class="callout"><svg aria-hidden="true"><use href="<cfoutput>#encodeForHTMLAttribute(fpwGuideIconHref('icon-lock'))#</cfoutput>"></use></svg><span><b>Locks</b>Locations, chamber sizes, and operating hours.</span></div>
            <div class="callout"><svg aria-hidden="true"><use href="<cfoutput>#encodeForHTMLAttribute(fpwGuideIconHref('icon-anchor'))#</cfoutput>"></use></svg><span><b>Anchorages</b>Safe places to stop and spend the night.</span></div>
            <div class="callout"><span class="round-icon" aria-hidden="true">⛽</span><span><b>Bailout Stops</b>Alternate landing or fuel stops along your route.</span></div>
          </div>
        </div>
      </article>

      <article class="guide-panel surface">
        <h2>Start with these guide topics</h2>
        <div class="topic-grid">
          <a class="topic-card" href="#what-nautical-charts-show"><span class="thumb chart"></span><b>How to Read a Nautical Chart</b><em>›</em></a>
          <a class="topic-card" href="#chart-symbol-explorer"><span class="thumb buoys"></span><b>Nautical Chart Symbols</b><em>›</em></a>
          <a class="topic-card" href="#aids-to-navigation"><span class="thumb aton"></span><b>Aids to Navigation</b><em>›</em></a>
          <a class="topic-card" href="#red-right-returning"><span class="thumb redright"></span><b>Red Right Returning</b><em>›</em></a>
          <a class="topic-card" href="#from-chart-to-float-plan"><span class="thumb checklist"></span><b>Pre-Departure Chart Checklist</b><em>›</em></a>
          <a class="topic-card" href="<cfoutput>#encodeForHTMLAttribute(fpwGuideWhyFloatPlanUrl)#</cfoutput>"><span class="thumb notes"></span><b>From Chart Notes to Float Plan</b><em>›</em></a>
        </div>
      </article>
    </section>

    <section class="symbol-explorer surface dark-panel" id="chart-symbol-explorer">
      <div class="symbol-copy">
        <h2>Chart Symbol Explorer</h2>
        <p>Tap a category to see common symbols and their meaning.</p>
      </div>
      <div class="symbol-tiles">
        <a href="#what-nautical-charts-show"><b>Depths</b><span class="depth-symbol">12.4<br>〰 32</span></a>
        <a href="#aids-to-navigation"><b>Buoys</b><span><svg aria-hidden="true"><use href="<cfoutput>#encodeForHTMLAttribute(fpwGuideIconHref('icon-buoy'))#</cfoutput>"></use></svg><svg aria-hidden="true"><use href="<cfoutput>#encodeForHTMLAttribute(fpwGuideIconHref('icon-green-buoy'))#</cfoutput>"></use></svg></span></a>
        <a href="#aids-to-navigation"><b>Lights</b><span class="light-symbol">✦ ⚑ ✦</span></a>
        <a href="#what-nautical-charts-show"><b>Hazards</b><span class="hazards">◒ ⨯ ≋</span></a>
        <a href="#what-nautical-charts-show"><b>Anchorages</b><span class="anchor-circle">⚓</span></a>
        <a href="<cfoutput>#encodeForHTMLAttribute(fpwGuideBridgesUrl)#</cfoutput>"><b>Bridges</b><svg aria-hidden="true"><use href="<cfoutput>#encodeForHTMLAttribute(fpwGuideIconHref('icon-bridge'))#</cfoutput>"></use></svg></a>
        <a href="#what-nautical-charts-show"><b>Restricted Areas</b><span class="restricted-symbol"></span></a>
      </div>
      <aside class="explorer-help">
        <h3>How to use this</h3>
        <p>Explore common chart symbols at a glance. Understanding them helps you read charts faster, avoid hazards, and navigate with confidence.</p>
        <a class="mini-btn" href="#chart-symbol-explorer">View Symbol Guide ↗</a>
      </aside>
    </section>

    <section class="aton-red-grid">
      <article class="surface aton-panel" id="aids-to-navigation">
        <h2>Aids to Navigation Basics</h2>
        <div class="aton-row">
          <div><h3>Port Hand</h3><svg aria-hidden="true"><use href="<cfoutput>#encodeForHTMLAttribute(fpwGuideIconHref('icon-buoy'))#</cfoutput>"></use></svg><p>Keep to the right when returning.</p></div>
          <div><h3>Starboard Hand</h3><svg aria-hidden="true"><use href="<cfoutput>#encodeForHTMLAttribute(fpwGuideIconHref('icon-green-buoy'))#</cfoutput>"></use></svg><p>Keep to the left when returning.</p></div>
          <div><h3>Preferred Channel</h3><span class="preferred-marker"></span><p>Indicates the best or preferred channel.</p></div>
          <div><h3>Safe Water</h3><span class="safe-marker"></span><p>Marks safe water in any direction.</p></div>
        </div>
      </article>
      <article class="surface red-panel" id="red-right-returning">
        <h2>Red Right Returning</h2>
        <p>When returning from sea or heading upstream, keep red markers on your right and green on your left.</p>
        <div class="red-diagram"><span class="shore left"></span><span class="shore right"></span><i class="boat">⌂</i><i class="red r1"></i><i class="red r2"></i><i class="green g1"></i><i class="green g2"></i><b>↑</b></div>
        <div class="legend"><span><i class="red-dot"></i>Red on Right</span><span><i class="green-dot"></i>Green on Left</span></div>
      </article>
    </section>

    <section class="flow-section" id="from-chart-to-float-plan">
      <h2>From Chart to Float Plan</h2>
      <div class="flow-row">
        <article><span aria-hidden="true">🗺️</span><b>Review Chart</b><p>Study the area, depths, markers, and notes.</p></article>
        <i aria-hidden="true">→</i><article><span aria-hidden="true">📍</span><b>Identify Route</b><p>Plot your course and waypoints.</p></article>
        <i aria-hidden="true">→</i><article><span aria-hidden="true">⚠️</span><b>Note Hazards, Bridges, Locks</b><p>Mark critical points along the way.</p></article>
        <i aria-hidden="true">→</i><article><span aria-hidden="true">☁️</span><b>Save Route</b><p>Store your route in FloatPlanWizard.</p></article>
        <i aria-hidden="true">→</i><article><span aria-hidden="true">👥</span><b>Share Float Plan</b><p>Let someone know your plan and ETA.</p></article>
      </div>
    </section>

    <section class="related-tools surface">
      <h2>Related FPW Tools</h2>
      <div class="tools-grid">
        <a href="<cfoutput>#encodeForHTMLAttribute(fpwGuideLocksUrl)#</cfoutput>"><svg aria-hidden="true"><use href="<cfoutput>#encodeForHTMLAttribute(fpwGuideIconHref('icon-lock'))#</cfoutput>"></use></svg><b>Great Loop Lock Library</b><p>Details on every lock you'll encounter on the Great Loop.</p><span>Explore Locks ›</span></a>
        <a href="<cfoutput>#encodeForHTMLAttribute(fpwGuideBridgesUrl)#</cfoutput>"><svg aria-hidden="true"><use href="<cfoutput>#encodeForHTMLAttribute(fpwGuideIconHref('icon-bridge'))#</cfoutput>"></use></svg><b>Great Loop Bridge Library</b><p>Clearance data, photos, and opening info for Great Loop bridges.</p><span>Explore Bridges ›</span></a>
        <a href="<cfoutput>#encodeForHTMLAttribute(fpwGuideFuelUrl)#</cfoutput>"><span class="gauge" aria-hidden="true">◔</span><b>Boat Fuel Calculator</b><p>Estimate fuel needs with confidence for any distance.</p><span>Calculate Fuel ›</span></a>
        <a href="<cfoutput>#encodeForHTMLAttribute(fpwGuideWhyFloatPlanUrl)#</cfoutput>"><svg aria-hidden="true"><use href="<cfoutput>#encodeForHTMLAttribute(fpwGuideIconHref('icon-shield'))#</cfoutput>"></use></svg><b>Why Use a Float Plan</b><p>Learn how a float plan protects you and your loved ones.</p><span>Learn More ›</span></a>
      </div>
    </section>

    <section class="faq surface" id="faq">
      <h2>Frequently Asked Questions</h2>
      <div class="faq-grid">
        <details open><summary>What is a nautical chart?</summary><p>A nautical chart is a detailed map of water areas that shows depths, hazards, navigation aids, shorelines, and other important information for safe navigation.</p></details>
        <details open><summary>What are aids to navigation?</summary><p>Aids to navigation are markers, buoys, lights, and other devices that help boaters identify safe channels, hazards, and important locations on the water.</p></details>
        <details><summary>Are NOAA electronic charts used by recreational boaters?</summary><p>Yes. Many modern chartplotters and navigation systems use electronic chart data for recreational boating.</p></details>
        <details><summary>Does FloatPlanWizard replace official charts?</summary><p>No. FloatPlanWizard helps organize trip planning and float plan details after boaters review official charts and current conditions.</p></details>
        <details><summary>What is U.S. Chart No. 1?</summary><p>It is NOAA's reference for nautical chart symbols, abbreviations, and terms.</p></details>
        <details><summary>How does chart reading help with float plans?</summary><p>It helps identify the route, checkpoints, shallow areas, bridges, locks, fuel stops, and bailout options.</p></details>
      </div>
    </section>

    <section class="bottom-cta">
      <div class="lighthouse" aria-hidden="true"></div>
      <div><h2>Before you leave, make sure someone knows the plan.</h2><p>A float plan is a simple step that can make all the difference.</p><div class="button-row"><a class="btn primary" href="<cfoutput>#encodeForHTMLAttribute(fpwGuideJoinUrl)#</cfoutput>">Create a Float Plan</a><a class="btn tertiary" href="<cfoutput>#encodeForHTMLAttribute(fpwGuideWhyFloatPlanUrl)#</cfoutput>">Learn Why Float Plans Matter</a></div></div>
      <aside class="bookmark-note"><b>Love this guide?</b><br>Save it for later!<small>Bookmark this page and come back anytime.</small></aside>
    </section>
  </main>

  <cfinclude template="../../includes/footer.cfm">
</body>
</html>
