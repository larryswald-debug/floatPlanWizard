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
    fpwFloatPlanBasePath = getDirectoryFromPath(fpwFloatPlanScriptName);
    fpwFloatPlanBasePath = reReplace(fpwFloatPlanBasePath, "/$", "");
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

fpwFloatPlanHeroImage = fpwFloatPlanBasePath & "/assets/images/float-plan/float-plan-hero-bg.png";
fpwFloatPlanPreserverImage = fpwFloatPlanBasePath & "/assets/images/float-plan/life-preserver.png";
fpwFloatPlanPdf = fpwFloatPlanBasePath & "/downloads/uscg-float-plan.pdf";
fpwFloatPlanAppUrl = fpwFloatPlanBasePath & "/" & "app" & "/";

fpwFloatPlanCanonicalUrl = "https://floatplanwizard.com/why-use-a-float-plan/";
fpwFloatPlanPageTitle = "Why Every Boater Should Use a Float Plan | FPW";
fpwFloatPlanPageDescription = "Learn what a float plan includes, when to use one, who should hold it, and how FPW helps keep trip details organized.";
fpwFloatPlanJsonLdText = "";
fpwFloatPlanSchemaGraph = [];
fpwFloatPlanSchemaOrg = structNew("ordered");
fpwFloatPlanSchemaBreadcrumb = structNew("ordered");
fpwFloatPlanSchemaPage = structNew("ordered");
fpwFloatPlanJsonLd = structNew("ordered");

structInsert(fpwFloatPlanSchemaOrg, schemaTypeKey, "Organization", true);
structInsert(fpwFloatPlanSchemaOrg, schemaIdKey, "https://floatplanwizard.com/##organization", true);
fpwFloatPlanSchemaOrg["name"] = "FloatPlanWizard";
fpwFloatPlanSchemaOrg["url"] = "https://floatplanwizard.com/";
fpwFloatPlanSchemaOrg["logo"] = "https://floatplanwizard.com/assets/images/checkout/floatplanwizard-logo.jpg";
arrayAppend(fpwFloatPlanSchemaGraph, fpwFloatPlanSchemaOrg);

structInsert(fpwFloatPlanSchemaBreadcrumb, schemaTypeKey, "BreadcrumbList", true);
structInsert(fpwFloatPlanSchemaBreadcrumb, schemaIdKey, fpwFloatPlanCanonicalUrl & "##breadcrumb", true);
fpwFloatPlanSchemaBreadcrumb["itemListElement"] = [];
arrayAppend(fpwFloatPlanSchemaBreadcrumb["itemListElement"], fpwFloatPlanSchemaListItem(1, "FloatPlanWizard", "https://floatplanwizard.com/"));
arrayAppend(fpwFloatPlanSchemaBreadcrumb["itemListElement"], fpwFloatPlanSchemaListItem(2, "Why Use a Float Plan", fpwFloatPlanCanonicalUrl));
arrayAppend(fpwFloatPlanSchemaGraph, fpwFloatPlanSchemaBreadcrumb);

structInsert(fpwFloatPlanSchemaPage, schemaTypeKey, "WebPage", true);
structInsert(fpwFloatPlanSchemaPage, schemaIdKey, fpwFloatPlanCanonicalUrl & "##webpage", true);
fpwFloatPlanSchemaPage["url"] = fpwFloatPlanCanonicalUrl;
fpwFloatPlanSchemaPage["name"] = fpwFloatPlanPageTitle;
fpwFloatPlanSchemaPage["description"] = fpwFloatPlanPageDescription;
fpwFloatPlanSchemaPage["isPartOf"] = fpwFloatPlanSchemaRef("https://floatplanwizard.com/##website");
fpwFloatPlanSchemaPage["publisher"] = fpwFloatPlanSchemaRef("https://floatplanwizard.com/##organization");
fpwFloatPlanSchemaPage["breadcrumb"] = fpwFloatPlanSchemaRef(fpwFloatPlanCanonicalUrl & "##breadcrumb");
arrayAppend(fpwFloatPlanSchemaGraph, fpwFloatPlanSchemaPage);

structInsert(fpwFloatPlanJsonLd, schemaContextKey, "https://schema.org", true);
structInsert(fpwFloatPlanJsonLd, schemaGraphKey, fpwFloatPlanSchemaGraph, true);
fpwFloatPlanJsonLdText = replace(serializeJSON(fpwFloatPlanJsonLd), "</", "<\/", "all");
</cfscript>

<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Why Every Boater Should Use a Float Plan | FPW</title>
  <meta name="description" content="Learn what a float plan includes, when to use one, who should hold it, and how FPW helps keep trip details organized.">
  <link rel="canonical" href="https://floatplanwizard.com/why-use-a-float-plan/">
  <meta property="og:type" content="article">
  <meta property="og:site_name" content="FloatPlanWizard">
  <meta property="og:url" content="https://floatplanwizard.com/why-use-a-float-plan/">
  <meta property="og:title" content="Why Every Boater Should Use a Float Plan | FPW">
  <meta property="og:description" content="Learn what a float plan includes, when to use one, who should hold it, and how FPW helps keep trip details organized.">
  <meta property="og:image" content="https://floatplanwizard.com/assets/images/social/floatplanwizard-social-preview-20260602.png">
  <meta property="og:image:secure_url" content="https://floatplanwizard.com/assets/images/social/floatplanwizard-social-preview-20260602.png">
  <meta property="og:image:type" content="image/png">
  <meta property="og:image:width" content="1200">
  <meta property="og:image:height" content="630">
  <meta property="og:image:alt" content="FloatPlanWizard boating trip planning and monitored float plan preview image">
  <meta name="twitter:card" content="summary_large_image">
  <meta name="twitter:title" content="Why Every Boater Should Use a Float Plan | FPW">
  <meta name="twitter:description" content="Learn what a float plan includes, when to use one, who should hold it, and how FPW helps keep trip details organized.">
  <meta name="twitter:image" content="https://floatplanwizard.com/assets/images/social/floatplanwizard-social-preview-20260602.png">
  <meta name="twitter:image:alt" content="FloatPlanWizard boating trip planning and monitored float plan preview image">
  <script type="application/ld+json"><cfoutput>#fpwFloatPlanJsonLdText#</cfoutput></script>
  <link rel="preconnect" href="https://cdn.jsdelivr.net" crossorigin>
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.3/font/bootstrap-icons.min.css">
  <style>
    :root {
      --fpw-bg: #020a13;
      --fpw-bg-2: #061522;
      --fpw-panel: rgba(8, 20, 33, 0.86);
      --fpw-panel-strong: rgba(6, 17, 29, 0.94);
      --fpw-line: rgba(132, 183, 216, 0.3);
      --fpw-line-soft: rgba(132, 183, 216, 0.18);
      --fpw-text: #edf5ff;
      --fpw-muted: #b6c5d3;
      --fpw-soft: #84a1b5;
      --fpw-cyan: #23d7cf;
      --fpw-blue: #2087d9;
      --fpw-dark-blue: #04172b;
      --fpw-shadow: 0 24px 64px rgba(0, 0, 0, 0.42);
      --fpw-public-layout-max: var(--fpw-wide-max, 1320px);
      --fpw-max: var(--fpw-public-layout-max);
    }

    * {
      box-sizing: border-box;
    }

    html {
      scroll-behavior: smooth;
    }

    body.fpw-floatplan-public {
      margin: 0;
      min-height: 100vh;
      color: var(--fpw-text);
      background:
        radial-gradient(circle at 16% 0%, rgba(35, 215, 207, 0.11), transparent 22rem),
        radial-gradient(circle at 88% 8%, rgba(32, 135, 217, 0.14), transparent 26rem),
        linear-gradient(180deg, #020812 0%, #04101c 42%, #03101b 100%);
      font-family: Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
    }

    body.fpw-floatplan-public a {
      color: inherit;
      text-decoration: none;
    }

    body.fpw-floatplan-public img {
      display: block;
      max-width: 100%;
    }

    body.fpw-floatplan-public .shell {
      width: min(var(--fpw-max), calc(100% - (var(--fpw-page-gutter, 32px) * 2)));
      margin: 0 auto;
    }

    body.fpw-floatplan-public .promo-strip {
      display: none;
    }

    body.fpw-floatplan-public .topbar {
      position: sticky;
      top: 0;
      z-index: 30;
      background:
        linear-gradient(180deg, rgba(4, 13, 24, 0.97), rgba(4, 14, 25, 0.9));
      border-bottom: 1px solid rgba(132, 183, 216, 0.18);
      box-shadow: 0 12px 34px rgba(0, 0, 0, 0.22);
      backdrop-filter: blur(18px);
    }

    body.fpw-floatplan-public .topbar-inner {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 28px;
      min-height: 92px;
    }

    body.fpw-floatplan-public .brand {
      display: inline-flex;
      align-items: center;
      gap: 12px;
      min-width: 0;
    }

    body.fpw-floatplan-public .brand-mark {
      width: 52px;
      height: 52px;
      display: grid;
      place-items: center;
      color: #c8faff;
      border-radius: 50%;
      border: 1px solid rgba(35, 215, 207, 0.55);
      background:
        radial-gradient(circle, rgba(35, 215, 207, 0.18), rgba(5, 17, 30, 0.9) 68%);
      box-shadow: inset 0 0 0 1px rgba(255, 255, 255, 0.05), 0 0 26px rgba(35, 215, 207, 0.2);
    }

    body.fpw-floatplan-public .brand-mark i {
      font-size: 1.55rem;
      filter: drop-shadow(0 0 10px rgba(35, 215, 207, 0.55));
    }

    body.fpw-floatplan-public .brand-name {
      color: #f1f6ff;
      font-size: clamp(1.18rem, 2vw, 1.7rem);
      font-weight: 800;
      line-height: 1;
    }

    body.fpw-floatplan-public .brand-tag {
      margin-top: 5px;
      color: var(--fpw-cyan);
      font-size: 0.75rem;
      font-weight: 800;
      letter-spacing: 0.16em;
      text-transform: uppercase;
      white-space: nowrap;
    }

    body.fpw-floatplan-public .nav {
      display: flex;
      align-items: center;
      justify-content: flex-end;
      gap: 8px;
      flex-wrap: wrap;
    }

    body.fpw-floatplan-public .nav a {
      color: rgba(237, 245, 255, 0.9);
      border-radius: 999px;
      padding: 10px 12px;
      font-size: 0.94rem;
      line-height: 1;
      transition: color 0.18s ease, background 0.18s ease, border-color 0.18s ease;
    }

    body.fpw-floatplan-public .nav a:hover {
      color: #ffffff;
      background: rgba(255, 255, 255, 0.07);
    }

    body.fpw-floatplan-public .nav .btn {
      border: 1px solid rgba(132, 183, 216, 0.28);
      background: rgba(255, 255, 255, 0.05);
      color: #ffffff;
    }

    .fpw-floatplan-page {
      min-height: calc(100vh - 92px);
      background:
        radial-gradient(circle at top right, rgba(0, 188, 212, 0.14), transparent 34rem),
        radial-gradient(circle at 12% 8%, rgba(30, 136, 229, 0.12), transparent 30rem),
        linear-gradient(180deg, #061525 0%, #07111f 48%, #04101c 100%);
      color: #eef7fb;
    }

    .fpw-floatplan-shell {
      width: min(var(--fpw-max), calc(100% - (var(--fpw-page-gutter, 32px) * 2)));
      margin: 0 auto;
      padding: 22px 0 18px;
      display: grid;
      grid-template-columns: minmax(0, 1fr) 362px;
      grid-template-areas:
        "hero sidebar"
        "main sidebar";
      gap: 16px 18px;
      align-items: start;
    }

    .fpw-floatplan-hero {
      grid-area: hero;
      position: relative;
      min-height: 354px;
      border: 1px solid var(--fpw-line);
      border-radius: 10px;
      overflow: hidden;
      background:
        linear-gradient(90deg, rgba(3, 13, 25, 0.99) 0%, rgba(5, 25, 43, 0.9) 43%, rgba(5, 25, 43, 0.23) 100%),
        var(--fpw-floatplan-hero-image) center right / cover no-repeat;
      box-shadow: var(--fpw-shadow);
    }

    .fpw-floatplan-hero::before,
    .fpw-floatplan-hero::after {
      content: "";
      position: absolute;
      pointer-events: none;
    }

    .fpw-floatplan-hero::before {
      inset: 0;
      background:
        radial-gradient(circle at 6% 20%, rgba(35, 215, 207, 0.16), transparent 4rem),
        repeating-radial-gradient(circle at 72% 0%, rgba(132, 183, 216, 0.08) 0 1px, transparent 1px 16px);
      opacity: 0.6;
    }

    .fpw-floatplan-hero::after {
      left: 22px;
      top: 14px;
      width: 104px;
      height: 104px;
      background:
        linear-gradient(0deg, transparent 45%, rgba(35, 215, 207, 0.35) 45% 55%, transparent 55%),
        linear-gradient(90deg, transparent 45%, rgba(35, 215, 207, 0.35) 45% 55%, transparent 55%);
      clip-path: polygon(50% 0, 58% 40%, 100% 50%, 58% 60%, 50% 100%, 42% 60%, 0 50%, 42% 40%);
      opacity: 0.72;
    }

    .fpw-floatplan-hero__content {
      position: relative;
      z-index: 1;
      max-width: 760px;
      padding: clamp(38px, 5vw, 56px) clamp(24px, 4vw, 52px) 30px 128px;
    }

    .fpw-floatplan-eyebrow {
      display: none;
    }

    .fpw-floatplan-hero h1 {
      max-width: 760px;
      margin: 0;
      color: #f2f5fb;
      font-size: clamp(2.05rem, 3.4vw, 3rem);
      font-weight: 850;
      line-height: 1.08;
      letter-spacing: 0;
      text-shadow: 0 3px 16px rgba(0, 0, 0, 0.45);
    }

    .fpw-floatplan-hero__lead {
      max-width: 580px;
      margin: 20px 0 0;
      color: rgba(255, 255, 255, 0.9);
      font-size: clamp(1rem, 1.4vw, 1.2rem);
      line-height: 1.5;
    }

    .fpw-floatplan-chips,
    .fpw-floatplan-actions {
      display: flex;
      flex-wrap: wrap;
      gap: 12px;
      margin-top: 18px;
    }

    .fpw-floatplan-chips span {
      display: inline-flex;
      align-items: center;
      gap: 8px;
      min-height: 38px;
      border-radius: 9px;
      padding: 8px 14px;
      background: rgba(255, 255, 255, 0.09);
      border: 1px solid rgba(255, 255, 255, 0.12);
      color: #f4fbff;
      font-weight: 750;
      box-shadow: 0 8px 24px rgba(0, 0, 0, 0.18);
    }

    .fpw-floatplan-chips i {
      color: #d8f8ff;
      font-size: 1rem;
    }

    .fpw-floatplan-btn {
      display: inline-flex;
      align-items: center;
      justify-content: center;
      gap: 10px;
      min-height: 52px;
      border-radius: 8px;
      padding: 0 20px;
      font-weight: 800;
      line-height: 1.2;
      text-decoration: none;
      transition: transform 0.15s ease, box-shadow 0.15s ease, border-color 0.15s ease, background 0.15s ease;
    }

    .fpw-floatplan-btn i {
      font-size: 1.28rem;
      line-height: 1;
    }

    .fpw-floatplan-btn:hover {
      transform: translateY(-1px);
      text-decoration: none;
    }

    .fpw-floatplan-btn--primary,
    .fpw-floatplan-btn--download {
      background: linear-gradient(135deg, rgba(8, 126, 145, 0.96), rgba(14, 160, 153, 0.92));
      color: #ffffff;
      border: 1px solid rgba(136, 245, 245, 0.58);
      box-shadow: 0 12px 28px rgba(0, 150, 160, 0.22);
    }

    .fpw-floatplan-btn--outline {
      color: #ffffff;
      background: rgba(3, 18, 33, 0.48);
      border: 1px solid rgba(211, 224, 255, 0.72);
    }

    .fpw-floatplan-layout {
      display: contents;
    }

    .fpw-floatplan-main {
      grid-area: main;
      min-width: 0;
    }

    .fpw-floatplan-card-grid {
      display: grid;
      grid-template-columns: repeat(4, minmax(0, 1fr));
      gap: 14px;
    }

    .fpw-info-card,
    .fpw-download-card,
    .fpw-compare-card {
      border-radius: 10px;
      background:
        linear-gradient(180deg, rgba(10, 25, 41, 0.96), rgba(5, 16, 29, 0.98));
      border: 1px solid var(--fpw-line);
      box-shadow: 0 16px 38px rgba(0, 0, 0, 0.27);
    }

    .fpw-info-card {
      min-height: 224px;
      padding: 17px 17px 16px;
    }

    .fpw-info-card__icon {
      width: 48px;
      height: 48px;
      display: grid;
      place-items: center;
      border-radius: 50%;
      color: var(--fpw-cyan);
      border: 3px solid rgba(35, 215, 207, 0.82);
      background: rgba(35, 215, 207, 0.08);
      box-shadow: 0 0 22px rgba(35, 215, 207, 0.2);
      margin-bottom: 12px;
    }

    .fpw-info-card__icon i {
      font-size: 1.45rem;
      line-height: 1;
    }

    .fpw-info-card h2,
    .fpw-download-card h2,
    .fpw-compare-card h2 {
      margin: 0 0 12px;
      color: #ffffff;
      font-size: 1.08rem;
      line-height: 1.18;
      letter-spacing: 0;
    }

    .fpw-download-card h2 {
      max-width: 270px;
      margin-left: auto;
      margin-right: auto;
      font-size: 1.45rem;
      line-height: 1.08;
    }

    .fpw-info-card ul {
      margin: 0;
      padding-left: 1.05rem;
      color: rgba(238, 247, 251, 0.84);
      line-height: 1.42;
      font-size: 0.94rem;
    }

    .fpw-info-card li + li {
      margin-top: 7px;
    }

    .fpw-floatplan-sidebar {
      grid-area: sidebar;
      display: grid;
      gap: 14px;
      position: sticky;
      top: 110px;
      min-width: 0;
    }

    .fpw-download-card,
    .fpw-compare-card {
      padding: 26px 24px;
    }

    .fpw-download-card {
      min-height: 394px;
      text-align: center;
    }

    .fpw-download-card__image {
      width: 168px;
      max-width: 60%;
      height: auto;
      margin: 0 auto 20px;
      filter: drop-shadow(0 14px 18px rgba(0, 0, 0, 0.32));
    }

    .fpw-download-card p {
      max-width: 270px;
      margin: 0 auto;
      color: rgba(238, 247, 251, 0.72);
      line-height: 1.48;
    }

    .fpw-download-card .fpw-floatplan-btn {
      width: 100%;
      max-width: 300px;
      min-height: 78px;
      margin: 20px auto 0;
      border-color: rgba(38, 139, 231, 0.82);
      background: linear-gradient(135deg, rgba(4, 31, 62, 0.96), rgba(6, 53, 99, 0.92));
      font-size: 1.05rem;
    }

    .fpw-download-card__source {
      display: inline-flex;
      align-items: center;
      justify-content: center;
      gap: 9px;
      margin: 18px 0 0;
      color: #82d9f7;
      font-size: 0.94rem;
    }

    .fpw-download-card__source i {
      color: var(--fpw-cyan);
    }

    .fpw-compare-card {
      color: rgba(238, 247, 251, 0.82);
    }

    .fpw-compare-card h2 {
      margin-bottom: 14px;
      font-size: 1.17rem;
    }

    .fpw-compare-table {
      overflow: hidden;
      border-radius: 8px;
      border: 1px solid rgba(126, 205, 220, 0.28);
    }

    .fpw-compare-row {
      display: grid;
      grid-template-columns: 1fr 1fr;
    }

    .fpw-compare-row > div {
      display: flex;
      align-items: flex-start;
      gap: 8px;
      min-height: 46px;
      padding: 10px 9px;
      border-bottom: 1px solid rgba(126, 205, 220, 0.16);
      font-size: 0.82rem;
      line-height: 1.25;
    }

    .fpw-compare-row:last-child > div {
      border-bottom: 0;
    }

    .fpw-compare-row > div + div {
      border-left: 1px solid rgba(126, 205, 220, 0.16);
    }

    .fpw-compare-row--head > div {
      justify-content: center;
      color: #ffffff;
      font-weight: 800;
      background: rgba(255, 255, 255, 0.06);
    }

    .fpw-compare-row--head > div:last-child {
      background: linear-gradient(135deg, rgba(10, 166, 166, 0.85), rgba(8, 123, 140, 0.85));
    }

    .fpw-compare-status {
      flex: 0 0 auto;
      width: 16px;
      height: 16px;
      display: inline-grid;
      place-items: center;
      border-radius: 50%;
      margin-top: 1px;
      border: 1px solid rgba(238, 247, 251, 0.68);
      color: rgba(238, 247, 251, 0.76);
      font-size: 0.7rem;
      line-height: 1;
    }

    .fpw-compare-status--yes {
      color: #05242a;
      border-color: rgba(35, 215, 207, 0.82);
      background: rgba(35, 215, 207, 0.82);
    }

    .fpw-compare-card__link {
      display: inline-flex;
      align-items: center;
      justify-content: center;
      gap: 10px;
      width: 100%;
      margin-top: 24px;
      color: var(--fpw-cyan);
      font-weight: 850;
      text-decoration: none;
    }

    .fpw-compare-card__link:hover {
      text-decoration: underline;
    }

    .fpw-floatplan-footer {
      padding: 0 0 12px;
      background: #04101c;
    }

    .fpw-floatplan-footer__inner {
      width: min(var(--fpw-max), calc(100% - (var(--fpw-page-gutter, 32px) * 2)));
      margin: 0 auto;
      min-height: 64px;
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 18px;
      flex-wrap: wrap;
      border-top: 1px solid rgba(132, 183, 216, 0.18);
      padding: 16px 14px 0;
      color: rgba(238, 247, 251, 0.72);
    }

    .fpw-floatplan-footer__brand {
      display: inline-flex;
      align-items: center;
      gap: 10px;
      color: #f2f7ff;
      font-weight: 800;
    }

    .fpw-floatplan-footer__brand i {
      color: var(--fpw-cyan);
      font-size: 1.75rem;
    }

    .fpw-floatplan-footer__tag {
      display: block;
      margin-top: 2px;
      color: var(--fpw-cyan);
      font-size: 0.62rem;
      font-weight: 850;
      letter-spacing: 0.14em;
      text-transform: uppercase;
    }

    .fpw-floatplan-footer__links,
    .fpw-floatplan-footer__social {
      display: flex;
      align-items: center;
      gap: 24px;
      flex-wrap: wrap;
      color: rgba(238, 247, 251, 0.78);
      font-size: 0.9rem;
    }

    .fpw-floatplan-footer__links a:hover,
    .fpw-floatplan-footer__social span {
      display: inline-flex;
      align-items: center;
    }

    .fpw-floatplan-footer__social a:hover {
      color: #ffffff;
    }

    .fpw-floatplan-footer__copy {
      color: rgba(238, 247, 251, 0.55);
      font-size: 0.84rem;
    }

    .fpw-floatplan-footer__social {
      gap: 18px;
      font-size: 1.1rem;
    }

    @media (max-width: 1180px) {
      body.fpw-floatplan-public .topbar-inner {
        align-items: flex-start;
        flex-direction: column;
        padding: 16px 0;
      }

      body.fpw-floatplan-public .nav {
        justify-content: flex-start;
      }

      .fpw-floatplan-shell {
        grid-template-columns: 1fr;
        grid-template-areas:
          "hero"
          "sidebar"
          "main";
      }

      .fpw-floatplan-sidebar {
        position: static;
        grid-template-columns: repeat(2, minmax(0, 1fr));
      }
    }

    @media (max-width: 900px) {
      body.fpw-floatplan-public .shell,
      .fpw-floatplan-shell,
      .fpw-floatplan-footer__inner {
        width: min(var(--fpw-max), calc(100% - (var(--fpw-page-gutter, 32px) * 2)));
      }

      .fpw-floatplan-card-grid {
        grid-template-columns: repeat(2, minmax(0, 1fr));
      }

      .fpw-floatplan-sidebar {
        grid-template-columns: 1fr;
      }

      .fpw-floatplan-hero {
        background:
          linear-gradient(90deg, rgba(3, 18, 33, 0.98) 0%, rgba(6, 32, 55, 0.9) 100%),
          var(--fpw-floatplan-hero-image) center right / cover no-repeat;
      }

      .fpw-floatplan-hero__content {
        padding-left: 108px;
      }
    }

    @media (max-width: 620px) {
      body.fpw-floatplan-public .shell,
      .fpw-floatplan-shell,
      .fpw-floatplan-footer__inner {
        width: min(var(--fpw-max), calc(100% - (var(--fpw-page-gutter, 32px) * 2)));
      }

      body.fpw-floatplan-public .topbar-inner {
        min-height: auto;
      }

      body.fpw-floatplan-public .brand-tag {
        white-space: normal;
      }

      body.fpw-floatplan-public .nav {
        width: 100%;
        gap: 6px;
      }

      body.fpw-floatplan-public .nav a {
        padding: 9px 10px;
        font-size: 0.88rem;
      }

      .fpw-floatplan-shell {
        padding-top: 12px;
      }

      .fpw-floatplan-card-grid {
        grid-template-columns: 1fr;
      }

      .fpw-floatplan-hero {
        min-height: auto;
      }

      .fpw-floatplan-hero::after {
        width: 72px;
        height: 72px;
      }

      .fpw-floatplan-hero__content {
        padding: 106px 20px 24px;
      }

      .fpw-floatplan-actions .fpw-floatplan-btn {
        width: 100%;
      }

      .fpw-compare-row {
        grid-template-columns: 1fr;
      }

      .fpw-compare-row > div + div {
        border-left: 0;
      }

      .fpw-compare-row--head {
        display: none;
      }

      .fpw-floatplan-footer__links,
      .fpw-floatplan-footer__social {
        gap: 14px;
      }
    }
  </style>
<cfoutput><link rel="stylesheet" href="#fpwFloatPlanBasePath#/assets/css/layout.css?v=20260620-page-width"></cfoutput>
<cfoutput><link rel="stylesheet" href="#fpwFloatPlanBasePath#/assets/css/top-nav.css?v=20260806-resources-mega-v3"></cfoutput>
<cfinclude template="includes/analytics_clarity.cfm">
<cfinclude template="includes/trustedsite.cfm">
</head>
<body class="fpw-floatplan-public">
<cfinclude template="includes/top_nav.cfm">

<section class="fpw-floatplan-page">
  <div class="fpw-floatplan-shell">

    <section class="fpw-floatplan-hero" aria-labelledby="floatplan-page-title" style="--fpw-floatplan-hero-image: url('<cfoutput>#fpwFloatPlanHeroImage#</cfoutput>');">
      <div class="fpw-floatplan-hero__content">
        <div class="fpw-floatplan-eyebrow">Boating Safety Resource</div>

        <h1 id="floatplan-page-title">Why Every Boater<br>Should Use a Float Plan</h1>

        <p class="fpw-floatplan-hero__lead">
          A float plan gives someone the information they need if you are overdue, delayed, or unreachable.
        </p>

        <div class="fpw-floatplan-chips" aria-label="Float plan benefits">
          <span><i class="bi bi-file-earmark-text" aria-hidden="true"></i>USCG PDF</span>
          <span><i class="bi bi-printer" aria-hidden="true"></i>Printable</span>
          <span><i class="bi bi-life-preserver" aria-hidden="true"></i>Boating Safety</span>
        </div>

        <div class="fpw-floatplan-actions">
          <a class="fpw-floatplan-btn fpw-floatplan-btn--outline" href="<cfoutput>#fpwFloatPlanPdf#</cfoutput>" download>
            <i class="bi bi-download" aria-hidden="true"></i>
            Download Official USCG Float Plan PDF
          </a>

          <a class="fpw-floatplan-btn fpw-floatplan-btn--primary" href="app/join.cfm">
            <i class="bi bi-plus-circle" aria-hidden="true"></i>
            Create a Smarter Float Plan
          </a>
        </div>
      </div>
    </section>

    <div class="fpw-floatplan-layout">

      <main class="fpw-floatplan-main" aria-label="Float plan safety information">
        <section class="fpw-floatplan-card-grid">

          <article class="fpw-info-card">
            <div class="fpw-info-card__icon" aria-hidden="true"><i class="bi bi-question-lg"></i></div>
            <h2>1. What Is a Float Plan?</h2>
            <ul>
              <li>A float plan outlines your trip details on the water.</li>
              <li>It is shared with someone on shore you trust.</li>
              <li>It helps rescuers understand where to start looking if needed.</li>
            </ul>
          </article>

          <article class="fpw-info-card">
            <div class="fpw-info-card__icon" aria-hidden="true"><i class="bi bi-shield"></i></div>
            <h2>2. Why It Matters</h2>
            <ul>
              <li>Boating emergencies can happen without warning.</li>
              <li>A float plan saves critical time in a search.</li>
              <li>It gives your shore contact real details instead of guesses.</li>
            </ul>
          </article>

          <article class="fpw-info-card">
            <div class="fpw-info-card__icon" aria-hidden="true"><i class="bi bi-clock"></i></div>
            <h2>3. When Should You Use One?</h2>
            <ul>
              <li>Use one any time someone would need to know where you went.</li>
              <li>Use one for day trips, overnights, fishing runs, and longer cruises.</li>
              <li>Use one when cell service, weather, distance, or timing could become a problem.</li>
            </ul>
          </article>

          <article class="fpw-info-card">
            <div class="fpw-info-card__icon" aria-hidden="true"><i class="bi bi-people"></i></div>
            <h2>4. Who Should Hold It?</h2>
            <ul>
              <li>Leave it with a trusted person on shore.</li>
              <li>Choose someone who will notice if you are late.</li>
              <li>Make sure they know when to act and who to contact.</li>
            </ul>
          </article>

          <article class="fpw-info-card">
            <div class="fpw-info-card__icon" aria-hidden="true"><i class="bi bi-clipboard-check"></i></div>
            <h2>5. What to Include</h2>
            <ul>
              <li>Your boat name, type, color, and registration.</li>
              <li>Your route, destination, departure point, and return time.</li>
              <li>Passenger names, contact details, safety gear, and emergency contacts.</li>
            </ul>
          </article>

          <article class="fpw-info-card">
            <div class="fpw-info-card__icon" aria-hidden="true"><i class="bi bi-geo-alt"></i></div>
            <h2>6. If Plans Change</h2>
            <ul>
              <li>Update your contact if your destination changes.</li>
              <li>Tell them if you are staying out later than expected.</li>
              <li>Close the loop when you return safely.</li>
            </ul>
          </article>

          <article class="fpw-info-card">
            <div class="fpw-info-card__icon" aria-hidden="true"><i class="bi bi-bell"></i></div>
            <h2>7. What Your Contact Should Do</h2>
            <ul>
              <li>Try to reach you first if you are overdue.</li>
              <li>Review the float plan before calling for help.</li>
              <li>Give the float plan details to the proper rescue authority if needed.</li>
            </ul>
          </article>

          <article class="fpw-info-card">
            <div class="fpw-info-card__icon" aria-hidden="true"><i class="bi bi-card-checklist"></i></div>
            <h2>8. Quick Pre-Departure Checklist</h2>
            <ul>
              <li>File your float plan.</li>
              <li>Check weather and tides.</li>
              <li>Review safety gear and communications.</li>
              <li>Tell someone your plan before leaving the dock.</li>
            </ul>
          </article>

        </section>
      </main>

      <aside class="fpw-floatplan-sidebar" aria-label="Float plan downloads and comparison">

        <section class="fpw-download-card">
          <img
            src="<cfoutput>#fpwFloatPlanPreserverImage#</cfoutput>"
            alt=""
            class="fpw-download-card__image"
            loading="lazy"
          >

          <h2>Download the Official USCG Float Plan</h2>

          <p>
            The official U.S. Coast Guard float plan PDF is free and printable.
          </p>

          <a class="fpw-floatplan-btn fpw-floatplan-btn--download" href="<cfoutput>#fpwFloatPlanPdf#</cfoutput>" download>
            <i class="bi bi-download" aria-hidden="true"></i>
            Download USCG Float Plan PDF
          </a>
<p/>
          <p class="fpw-download-card__source" style="padding-top: 1rem;"><i class="bi bi-shield-check" aria-hidden="true"></i>Provided by the U.S. Coast Guard</p>
        </section>

        <section class="fpw-compare-card">
          <h2>Paper Float Plan vs FloatPlanWizard</h2>

          <div class="fpw-compare-table" role="table" aria-label="Paper float plan compared to FloatPlanWizard">
            <div class="fpw-compare-row fpw-compare-row--head" role="row">
              <div role="columnheader">Paper Float Plan</div>
              <div role="columnheader">FloatPlanWizard</div>
            </div>

            <div class="fpw-compare-row" role="row">
              <div role="cell"><span class="fpw-compare-status" aria-hidden="true">-</span>Easy to lose or forget</div>
              <div role="cell"><span class="fpw-compare-status fpw-compare-status--yes" aria-hidden="true">&#10003;</span>Stored securely in your account</div>
            </div>

            <div class="fpw-compare-row" role="row">
              <div role="cell"><span class="fpw-compare-status" aria-hidden="true">-</span>Harder to update</div>
              <div role="cell"><span class="fpw-compare-status fpw-compare-status--yes" aria-hidden="true">&#10003;</span>Update anytime, from anywhere</div>
            </div>

            <div class="fpw-compare-row" role="row">
              <div role="cell"><span class="fpw-compare-status" aria-hidden="true">-</span>No automatic alerts</div>
              <div role="cell"><span class="fpw-compare-status fpw-compare-status--yes" aria-hidden="true">&#10003;</span>Overdue alerts can notify your contacts</div>
            </div>

            <div class="fpw-compare-row" role="row">
              <div role="cell"><span class="fpw-compare-status" aria-hidden="true">-</span>Can be hard to read</div>
              <div role="cell"><span class="fpw-compare-status fpw-compare-status--yes" aria-hidden="true">&#10003;</span>Clear, organized, and mobile-friendly</div>
            </div>

            <div class="fpw-compare-row" role="row">
              <div role="cell"><span class="fpw-compare-status" aria-hidden="true">-</span>One-size-fits-all</div>
              <div role="cell"><span class="fpw-compare-status fpw-compare-status--yes" aria-hidden="true">&#10003;</span>Built around your boat, route, and trip</div>
            </div>
          </div>

         <!--- <a class="fpw-compare-card__link" href="<cfoutput>#fpwFloatPlanAppUrl#</cfoutput>">See how it works <i class="bi bi-arrow-right" aria-hidden="true"></i></a>--->
        </section>

      </aside>
    </div>
  </div>
</section>

<cfinclude template="includes/footer.cfm">

</body>
</html>
