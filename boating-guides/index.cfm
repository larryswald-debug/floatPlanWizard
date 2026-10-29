<cfprocessingdirective pageencoding="utf-8">
<cfsetting showdebugoutput="false" requesttimeout="30">
<cfcontent type="text/html; charset=utf-8">
<cfinclude template="../includes/fpw_base_path.cfm">
<cfscript>
request.fpwTopNavActive = "explore-guides";
fpwGuidesBasePath = request.fpwBase;
fpwGuidesCanonicalUrl = "https://floatplanwizard.com/boating-guides/";
fpwGuidesPageTitle = "Cruising Guides: Chesapeake Bay & Great Loop | FloatPlanWizard";
fpwGuidesPageDescription = "Explore FPW cruising guides for Chesapeake Bay and the Great Loop, with destinations, route planning, fuel, timing and float plan preparation.";
fpwGuidesSocialImage = "https://floatplanwizard.com/assets/images/social/floatplanwizard-social-preview-20260730.png";
fpwGuidesAt = chr(64);
fpwGuidesSchemaType = fpwGuidesAt & "type";
fpwGuidesSchemaId = fpwGuidesAt & "id";
function fpwGuidesReference(required string value) {
  var reference = structNew("ordered");
  structInsert(reference, fpwGuidesSchemaId, arguments.value, true);
  return reference;
}
function fpwGuidesListItem(required numeric position, required string name, required string url) {
  var item = structNew("ordered");
  structInsert(item, fpwGuidesSchemaType, "ListItem", true);
  item["position"] = arguments.position;
  item["name"] = arguments.name;
  item["url"] = arguments.url;
  return item;
}
fpwGuidesOrganizationId = "https://floatplanwizard.com/##organization";
fpwGuidesSchemaOrganization = structNew("ordered");
structInsert(fpwGuidesSchemaOrganization, fpwGuidesSchemaType, "Organization", true);
structInsert(fpwGuidesSchemaOrganization, fpwGuidesSchemaId, fpwGuidesOrganizationId, true);
fpwGuidesSchemaOrganization["name"] = "FloatPlanWizard";
fpwGuidesSchemaOrganization["url"] = "https://floatplanwizard.com/";
fpwGuidesSchemaOrganization["logo"] = "https://floatplanwizard.com/assets/images/checkout/floatplanwizard-logo.jpg";

fpwGuidesSchemaBreadcrumb = structNew("ordered");
structInsert(fpwGuidesSchemaBreadcrumb, fpwGuidesSchemaType, "BreadcrumbList", true);
structInsert(fpwGuidesSchemaBreadcrumb, fpwGuidesSchemaId, fpwGuidesCanonicalUrl & "##breadcrumb", true);
fpwGuidesBreadcrumbHome = fpwGuidesListItem(1, "FloatPlanWizard", "https://floatplanwizard.com/");
fpwGuidesBreadcrumbHome["item"] = fpwGuidesBreadcrumbHome["url"];
structDelete(fpwGuidesBreadcrumbHome, "url");
fpwGuidesBreadcrumbPage = fpwGuidesListItem(2, "Cruising Guides", fpwGuidesCanonicalUrl);
fpwGuidesBreadcrumbPage["item"] = fpwGuidesBreadcrumbPage["url"];
structDelete(fpwGuidesBreadcrumbPage, "url");
fpwGuidesSchemaBreadcrumb["itemListElement"] = [fpwGuidesBreadcrumbHome, fpwGuidesBreadcrumbPage];

fpwGuidesSchemaList = structNew("ordered");
structInsert(fpwGuidesSchemaList, fpwGuidesSchemaType, "ItemList", true);
structInsert(fpwGuidesSchemaList, fpwGuidesSchemaId, fpwGuidesCanonicalUrl & "##guides", true);
fpwGuidesSchemaList["name"] = "FPW Cruising Guides";
fpwGuidesSchemaList["numberOfItems"] = 2;
fpwGuidesSchemaList["itemListElement"] = [
  fpwGuidesListItem(1, "Chesapeake Bay Cruising Guide", "https://floatplanwizard.com/boating-guides/chesapeake-bay/"),
  fpwGuidesListItem(2, "Great Loop Planning Guide", "https://floatplanwizard.com/great-loop/trip-planning/")
];

fpwGuidesSchemaPage = structNew("ordered");
structInsert(fpwGuidesSchemaPage, fpwGuidesSchemaType, "CollectionPage", true);
structInsert(fpwGuidesSchemaPage, fpwGuidesSchemaId, fpwGuidesCanonicalUrl & "##webpage", true);
fpwGuidesSchemaPage["url"] = fpwGuidesCanonicalUrl;
fpwGuidesSchemaPage["name"] = fpwGuidesPageTitle;
fpwGuidesSchemaPage["description"] = fpwGuidesPageDescription;
fpwGuidesSchemaPage["inLanguage"] = "en";
fpwGuidesSchemaPage["breadcrumb"] = fpwGuidesReference(fpwGuidesCanonicalUrl & "##breadcrumb");
fpwGuidesSchemaPage["mainEntity"] = fpwGuidesReference(fpwGuidesCanonicalUrl & "##guides");
fpwGuidesSchemaPage["publisher"] = fpwGuidesReference(fpwGuidesOrganizationId);

fpwGuidesJsonLd = structNew("ordered");
structInsert(fpwGuidesJsonLd, fpwGuidesAt & "context", "https://schema.org", true);
structInsert(fpwGuidesJsonLd, fpwGuidesAt & "graph", [
  fpwGuidesSchemaOrganization, fpwGuidesSchemaBreadcrumb, fpwGuidesSchemaPage, fpwGuidesSchemaList
], true);
fpwGuidesJsonLdText = replace(serializeJSON(fpwGuidesJsonLd), "</", "<\/", "all");
</cfscript>
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <cfoutput>
  <title>#encodeForHTML(fpwGuidesPageTitle)#</title>
  <meta name="description" content="#encodeForHTMLAttribute(fpwGuidesPageDescription)#">
  <meta name="robots" content="index,follow">
  <link rel="canonical" href="#encodeForHTMLAttribute(fpwGuidesCanonicalUrl)#">
  <meta property="og:type" content="website">
  <meta property="og:site_name" content="FloatPlanWizard">
  <meta property="og:url" content="#encodeForHTMLAttribute(fpwGuidesCanonicalUrl)#">
  <meta property="og:title" content="#encodeForHTMLAttribute(fpwGuidesPageTitle)#">
  <meta property="og:description" content="#encodeForHTMLAttribute(fpwGuidesPageDescription)#">
  <meta property="og:image" content="#encodeForHTMLAttribute(fpwGuidesSocialImage)#">
  <meta property="og:image:width" content="1200">
  <meta property="og:image:height" content="630">
  <meta property="og:image:alt" content="FloatPlanWizard boating trip planning, float-plan sharing, and check-in preview">
  <meta name="twitter:card" content="summary_large_image">
  <meta name="twitter:title" content="#encodeForHTMLAttribute(fpwGuidesPageTitle)#">
  <meta name="twitter:description" content="#encodeForHTMLAttribute(fpwGuidesPageDescription)#">
  <meta name="twitter:image" content="#encodeForHTMLAttribute(fpwGuidesSocialImage)#">
  <script type="application/ld+json">#fpwGuidesJsonLdText#</script>
  <link rel="icon" type="image/svg+xml" href="#fpwGuidesBasePath#/assets/images/landing/fpw-logo.svg">
  <link rel="stylesheet" href="#fpwGuidesBasePath#/assets/css/layout.css?v=20260620-page-width">
  <link rel="stylesheet" href="#fpwGuidesBasePath#/assets/css/top-nav.css?v=20261028-approved-navigation">
  <link rel="stylesheet" href="#fpwGuidesBasePath#/assets/css/cruising-guides.css?v=20261028-approved-navigation">
  </cfoutput>
  <cfinclude template="../includes/analytics_ga4.cfm">
  <cfinclude template="../includes/analytics_clarity.cfm">
  <cfinclude template="../includes/trustedsite.cfm">
</head>
<body class="fpw-cruising-index-body">
<cfinclude template="../includes/top_nav.cfm">
<main class="fpw-cruising-index" id="main-content">
  <div class="fpw-cruising-index-shell">
    <nav class="fpw-cruising-breadcrumbs" aria-label="Breadcrumb">
      <a href="<cfoutput>#fpwGuidesBasePath#</cfoutput>/">FloatPlanWizard</a>
      <span aria-hidden="true">&rsaquo;</span>
      <span aria-current="page">Cruising Guides</span>
    </nav>
    <header class="fpw-cruising-index-intro">
      <p class="fpw-cruising-eyebrow">Cruising and Trip Planning</p>
      <h1>Cruising Guides</h1>
      <p>Research destinations, shape realistic daily legs, and prepare for the details of your cruise. FPW's guides connect that research to the Route Generator and the Float Plan Wizard, helping you turn a reviewed route into a float plan to share with your shore contact.</p>
    </header>
    <div class="fpw-cruising-card-grid">
      <article class="fpw-cruising-card" aria-labelledby="fpwChesapeakeCardTitle">
        <a class="fpw-cruising-card-image" href="<cfoutput>#fpwGuidesBasePath#</cfoutput>/boating-guides/chesapeake-bay/" aria-label="Read the Chesapeake Bay Cruising Guide">
          <img src="<cfoutput>#fpwGuidesBasePath#</cfoutput>/assets/images/navigation/thumb-chesapeake.jpg" width="420" height="320" alt="Lighthouse on Chesapeake Bay at sunset" decoding="async">
        </a>
        <div class="fpw-cruising-card-copy">
          <h2 id="fpwChesapeakeCardTitle"><a href="<cfoutput>#fpwGuidesBasePath#</cfoutput>/boating-guides/chesapeake-bay/">Chesapeake Bay Cruising Guide</a></h2>
          <p>Explore destinations, illustrative itineraries, fuel estimates, and travel-time planning for a Chesapeake Bay cruise.</p>
          <a class="fpw-cruising-card-link" href="<cfoutput>#fpwGuidesBasePath#</cfoutput>/boating-guides/chesapeake-bay/">Explore the Chesapeake guide <span aria-hidden="true">&rarr;</span></a>
        </div>
      </article>
      <article class="fpw-cruising-card" aria-labelledby="fpwGreatLoopCardTitle">
        <a class="fpw-cruising-card-image" href="<cfoutput>#fpwGuidesBasePath#</cfoutput>/great-loop/trip-planning/" aria-label="Read the Great Loop Planning Guide">
          <img src="<cfoutput>#fpwGuidesBasePath#</cfoutput>/assets/images/navigation/great-loop-trawler.png" width="1536" height="1024" alt="Cruising boat on a tree-lined waterway" decoding="async">
        </a>
        <div class="fpw-cruising-card-copy">
          <h2 id="fpwGreatLoopCardTitle"><a href="<cfoutput>#fpwGuidesBasePath#</cfoutput>/great-loop/trip-planning/">Great Loop Planning Guide</a></h2>
          <p>Plan Great Loop legs with mileage, locks, bridges, fuel, and timing references, then review your route in FPW.</p>
          <a class="fpw-cruising-card-link" href="<cfoutput>#fpwGuidesBasePath#</cfoutput>/great-loop/trip-planning/">Explore the Great Loop guide <span aria-hidden="true">&rarr;</span></a>
        </div>
      </article>
    </div>
  </div>
</main>
<cfinclude template="../includes/footer.cfm">
</body>
</html>
