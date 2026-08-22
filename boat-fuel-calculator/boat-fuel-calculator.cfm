<cfsetting showdebugoutput="false">
<cfcontent type="text/html; charset=utf-8">

<cfscript>
schemaAtKey = chr(64);
schemaTypeKey = schemaAtKey & "type";
schemaIdKey = schemaAtKey & "id";
schemaContextKey = schemaAtKey & "context";
schemaGraphKey = schemaAtKey & "graph";

function fpwFuelSchemaRef(required string idValue) {
  var out = structNew("ordered");
  structInsert(out, schemaIdKey, arguments.idValue, true);
  return out;
}

function fpwFuelSchemaListItem(required numeric position, required string name, required string urlValue) {
  var out = structNew("ordered");
  var item = structNew("ordered");
  structInsert(out, schemaTypeKey, "ListItem", true);
  out["position"] = arguments.position;
  structInsert(item, schemaIdKey, arguments.urlValue, true);
  item["name"] = arguments.name;
  out["item"] = item;
  return out;
}

function fpwFuelSchemaQuestion(required string questionText, required string answerText) {
  var question = structNew("ordered");
  var answer = structNew("ordered");
  structInsert(question, schemaTypeKey, "Question", true);
  question["name"] = arguments.questionText;
  structInsert(answer, schemaTypeKey, "Answer", true);
  answer["text"] = arguments.answerText;
  question["acceptedAnswer"] = answer;
  return question;
}

fpwFuelCanonicalUrl = "https://floatplanwizard.com/boat-fuel-calculator/";
fpwFuelPageTitle = "Free Boat Fuel Calculator – Fuel Needed, Range & Trip Cost";
fpwFuelPageDescription = "Free boat fuel calculator. Enter trip distance, cruising speed and fuel burn to estimate gallons needed, safe reserve, cruising range, travel time and trip cost.";
fpwFuelFaqId = fpwFuelCanonicalUrl & "##faq";
fpwFuelJsonLdText = "";
fpwFuelSchemaGraph = [];
fpwFuelSchemaOrg = structNew("ordered");
fpwFuelSchemaBreadcrumb = structNew("ordered");
fpwFuelSchemaPage = structNew("ordered");
fpwFuelSchemaFaq = structNew("ordered");
fpwFuelJsonLd = structNew("ordered");
fpwFuelFaqItems = [
  {
    "question" = "How much fuel does a boat use per hour?",
    "answer" = "Boat fuel use is measured in gallons per hour, but there is no single number that applies to all boats. GPH depends on the engine, RPM, hull, load, propeller, trim and operating conditions. For trip planning, use measured fuel-flow data or manufacturer performance data for your boat and engine whenever possible."
  },
  {
    "question" = "Can I estimate boat fuel burn from horsepower?",
    "answer" = "Horsepower alone is not enough to accurately predict cruise fuel burn. Generic horsepower formulas can produce rough theoretical estimates, especially near maximum engine output, but they do not account for hull efficiency, engine load, RPM, propeller, weight or conditions. Use actual GPH whenever possible."
  },
  {
    "question" = "Does slowing down always save fuel?",
    "answer" = "It normally lowers gallons burned per hour, but it does not automatically produce the best fuel economy per mile. The most economical cruise is the operating point that provides the best useful distance per gallon at an appropriate speed for the boat and trip."
  },
  {
    "question" = "How do I calculate how much boat fuel I need?",
    "answer" = "Divide trip distance by cruising speed to estimate running time, then multiply running time by your expected GPH. Add appropriate fuel for idling, changing conditions and reserve."
  },
  {
    "question" = "What is the best cruising speed for fuel economy?",
    "answer" = "It depends on the boat and engine combination. Compare GPH and speed at several normal operating RPM settings and look for the best distance-per-gallon result. Manufacturer performance bulletins and onboard fuel-flow data are the best places to start."
  },
  {
    "question" = "How much reserve fuel should I carry?",
    "answer" = "The U.S. Coast Guard recommends the One-Third Rule: one-third of the fuel for the outbound leg, one-third for the return and one-third held in reserve. Conditions and trip complexity may justify additional margin."
  },
  {
    "question" = "Should I use wide-open-throttle GPH in the calculator?",
    "answer" = "Only if you actually expect to operate at that fuel-burn rate. For normal trip planning, use the GPH associated with the speed and RPM you expect to cruise."
  },
  {
    "question" = "How accurate is the FloatPlanWizard fuel calculator?",
    "answer" = "The arithmetic is based on the values you enter. Its real-world accuracy therefore depends heavily on the accuracy of your speed, GPH, distance, idle-time and reserve assumptions. Weather, current, sea state, load and engine condition can change actual fuel use."
  }
];

structInsert(fpwFuelSchemaOrg, schemaTypeKey, "Organization", true);
structInsert(fpwFuelSchemaOrg, schemaIdKey, "https://floatplanwizard.com/##organization", true);
fpwFuelSchemaOrg["name"] = "FloatPlanWizard";
fpwFuelSchemaOrg["url"] = "https://floatplanwizard.com/";
fpwFuelSchemaOrg["logo"] = "https://floatplanwizard.com/assets/images/checkout/floatplanwizard-logo.jpg";
arrayAppend(fpwFuelSchemaGraph, fpwFuelSchemaOrg);

structInsert(fpwFuelSchemaBreadcrumb, schemaTypeKey, "BreadcrumbList", true);
structInsert(fpwFuelSchemaBreadcrumb, schemaIdKey, fpwFuelCanonicalUrl & "##breadcrumb", true);
fpwFuelSchemaBreadcrumb["itemListElement"] = [];
arrayAppend(fpwFuelSchemaBreadcrumb["itemListElement"], fpwFuelSchemaListItem(1, "FloatPlanWizard", "https://floatplanwizard.com/"));
arrayAppend(fpwFuelSchemaBreadcrumb["itemListElement"], fpwFuelSchemaListItem(2, "Boat Fuel Calculator", fpwFuelCanonicalUrl));
arrayAppend(fpwFuelSchemaGraph, fpwFuelSchemaBreadcrumb);

structInsert(fpwFuelSchemaPage, schemaTypeKey, "WebPage", true);
structInsert(fpwFuelSchemaPage, schemaIdKey, fpwFuelCanonicalUrl & "##webpage", true);
fpwFuelSchemaPage["url"] = fpwFuelCanonicalUrl;
fpwFuelSchemaPage["name"] = fpwFuelPageTitle;
fpwFuelSchemaPage["description"] = fpwFuelPageDescription;
fpwFuelSchemaPage["isPartOf"] = fpwFuelSchemaRef("https://floatplanwizard.com/##website");
fpwFuelSchemaPage["publisher"] = fpwFuelSchemaRef("https://floatplanwizard.com/##organization");
fpwFuelSchemaPage["breadcrumb"] = fpwFuelSchemaRef(fpwFuelCanonicalUrl & "##breadcrumb");
fpwFuelSchemaPage["mainEntity"] = fpwFuelSchemaRef(fpwFuelFaqId);
arrayAppend(fpwFuelSchemaGraph, fpwFuelSchemaPage);

structInsert(fpwFuelSchemaFaq, schemaTypeKey, "FAQPage", true);
structInsert(fpwFuelSchemaFaq, schemaIdKey, fpwFuelFaqId, true);
fpwFuelSchemaFaq["mainEntity"] = [];
for (fpwFuelFaqItem in fpwFuelFaqItems) {
  arrayAppend(
    fpwFuelSchemaFaq["mainEntity"],
    fpwFuelSchemaQuestion(fpwFuelFaqItem["question"], fpwFuelFaqItem["answer"])
  );
}
arrayAppend(fpwFuelSchemaGraph, fpwFuelSchemaFaq);

structInsert(fpwFuelJsonLd, schemaContextKey, "https://schema.org", true);
structInsert(fpwFuelJsonLd, schemaGraphKey, fpwFuelSchemaGraph, true);
fpwFuelJsonLdText = replace(serializeJSON(fpwFuelJsonLd), "</", "<\/", "all");

fpwFuelCtaUserId = 0;
if (structKeyExists(session, "user") AND isStruct(session.user)) {
  for (fpwFuelCtaUserIdKey in [ "userId", "id", "USERID", "ID" ]) {
    if (structKeyExists(session.user, fpwFuelCtaUserIdKey) AND isNumeric(session.user[fpwFuelCtaUserIdKey])) {
      fpwFuelCtaUserId = val(session.user[fpwFuelCtaUserIdKey]);
      break;
    }
  }
}
fpwFuelCtaSignedIn = fpwFuelCtaUserId GT 0;
fpwCtaConfig = {
  "id" = "boat-fuel-calculator-plan-route-cta",
  "headline" = "Turn your fuel estimate into a trip plan",
  "supportingText" = "Use FloatPlanWizard to organize your route, stops, schedule, vessel details, and shore contact.",
  "buttonLabel" = "Plan a Route",
  "destinationUrl" = fpwFuelCtaSignedIn ? "../app/dashboard.cfm" : "../app/join.cfm",
  "ctaType" = "plan_route",
  "sourcePage" = "boat_fuel_calculator",
  "section" = "calculator_results",
  "authState" = fpwFuelCtaSignedIn ? "signed_in" : "signed_out",
  "destinationKey" = fpwFuelCtaSignedIn ? "dashboard" : "join",
  "analyticsEvent" = "boat_fuel_calculator_plan_route_cta_click",
  "ariaLabel" = "Plan a Route with FloatPlanWizard from the Boat Fuel Calculator results"
};
</cfscript>

<!doctype html>
<html lang="en">
<head>

  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Free Boat Fuel Calculator – Fuel Needed, Range & Trip Cost</title>

<meta name="description" content="Free boat fuel calculator. Enter trip distance, cruising speed and fuel burn to estimate gallons needed, safe reserve, cruising range, travel time and trip cost.">

<link rel="canonical" href="https://floatplanwizard.com/boat-fuel-calculator/">
<meta property="og:type" content="website">
<meta property="og:site_name" content="FloatPlanWizard">
<meta property="og:url" content="https://floatplanwizard.com/boat-fuel-calculator/">
<meta property="og:title" content="Free Boat Fuel Calculator – Fuel Needed, Range & Trip Cost">
<meta property="og:description" content="Free boat fuel calculator. Enter trip distance, cruising speed and fuel burn to estimate gallons needed, safe reserve, cruising range, travel time and trip cost.">
<meta property="og:image" content="https://floatplanwizard.com/assets/images/social/floatplanwizard-social-preview-20260730.png">
<meta property="og:image:secure_url" content="https://floatplanwizard.com/assets/images/social/floatplanwizard-social-preview-20260730.png">
<meta property="og:image:type" content="image/png">
<meta property="og:image:width" content="1200">
<meta property="og:image:height" content="630">
<meta property="og:image:alt" content="FloatPlanWizard boating trip planning and monitored float plan preview image">
<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:title" content="Free Boat Fuel Calculator – Fuel Needed, Range & Trip Cost">
<meta name="twitter:description" content="Free boat fuel calculator. Enter trip distance, cruising speed and fuel burn to estimate gallons needed, safe reserve, cruising range, travel time and trip cost.">
<meta name="twitter:image" content="https://floatplanwizard.com/assets/images/social/floatplanwizard-social-preview-20260730.png">
<meta name="twitter:image:alt" content="FloatPlanWizard boating trip planning and monitored float plan preview image">
  <script type="application/ld+json"><cfoutput>#fpwFuelJsonLdText#</cfoutput></script>
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.3/font/bootstrap-icons.min.css">
  <style>
    :root {
      --fpw-public-layout-max: var(--fpw-wide-max, 1320px);
      --fuel-bg: #061726;
      --fuel-panel: rgba(7, 22, 38, 0.84);
      --fuel-panel-strong: rgba(4, 15, 28, 0.96);
      --fuel-line: rgba(126, 205, 220, 0.28);
      --fuel-line-strong: rgba(33, 243, 238, 0.62);
      --fuel-text: #f3f8ff;
      --fuel-muted: #b8c7d6;
      --fuel-soft: #87a0b6;
      --fuel-cyan: #23d7cf;
      --fuel-blue: #38bdf8;
      --fuel-radius: 18px;
    }

    * { box-sizing: border-box; }
    html { scroll-behavior: smooth; }
    a { color: inherit; text-decoration: none; }

    .fuelcalc-page {
      margin: 0;
      color: var(--fuel-text);
      font-family: Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      background:
        radial-gradient(circle at 15% 0%, rgba(35, 215, 207, 0.13), transparent 26rem),
        radial-gradient(circle at 85% 4%, rgba(56, 189, 248, 0.11), transparent 28rem),
        linear-gradient(180deg, #061726 0%, #082033 48%, #061726 100%);
    }

    .fuelcalc-page input,
    .fuelcalc-page select,
    .fuelcalc-page button {
      font: inherit;
    }

    .fuelcalc-page svg {
      display: block;
    }

    .fpw-fuel-page {
      position: relative;
      width: min(var(--fpw-public-layout-max), calc(100% - (var(--fpw-page-gutter, 32px) * 2)));
      margin-inline: auto;
      padding: 28px 0 34px;
      overflow: hidden;
    }

    .fpw-fuel-page::before {
      content: "";
      position: absolute;
      inset: 0;
      pointer-events: none;
      background-image:
        linear-gradient(rgba(126, 205, 220, 0.035) 1px, transparent 1px),
        linear-gradient(90deg, rgba(126, 205, 220, 0.032) 1px, transparent 1px);
      background-size: 76px 76px;
      mask-image: radial-gradient(circle at 50% 0%, black 0%, transparent 58%);
      opacity: 0.7;
    }

    .fpw-fuel-page > * {
      position: relative;
      z-index: 1;
    }

    .fpw-compact-tool-hero {
      position: relative;
      min-height: 240px;
      display: grid;
      grid-template-columns: minmax(0, 0.95fr) minmax(320px, 1.05fr);
      align-items: stretch;
      overflow: hidden;
      border: 1px solid rgba(47, 232, 226, 0.18);
      background:
        linear-gradient(90deg, rgba(1, 12, 22, 0.98) 0%, rgba(3, 22, 37, 0.94) 42%, rgba(3, 28, 48, 0.72) 100%);
    }

    .fpw-compact-tool-hero__content {
      position: relative;
      z-index: 2;
      max-width: 720px;
      padding: clamp(22px, 3vw, 34px);
    }

    .fpw-compact-tool-hero__eyebrow {
      margin: 0 0 8px;
      color: #7ffaf5;
      font-size: 0.86rem;
      font-weight: 800;
      letter-spacing: 0.18em;
      text-transform: uppercase;
    }

    .fpw-compact-tool-hero h1 {
      margin: 0;
      color: #ffffff;
      font-size: clamp(2.25rem, 3.6vw, 3.1rem);
      line-height: 0.98;
      letter-spacing: 0;
      text-shadow: 0 12px 28px rgba(0, 0, 0, 0.38);
    }

    .fpw-compact-tool-hero__supporting {
      max-width: 620px;
      margin: 12px 0 0;
      color: #7ffaf5;
      font-size: clamp(1.25rem, 1.8vw, 1.55rem);
      font-weight: 800;
      line-height: 1.2;
    }

    .fpw-compact-tool-hero__intro {
      max-width: 620px;
      margin: 10px 0 0;
      color: rgba(226, 236, 246, 0.86);
      font-size: clamp(1rem, 1.3vw, 1.16rem);
      line-height: 1.42;
    }

    .fpw-compact-tool-hero__intent {
      max-width: 620px;
      margin: 10px 0 0;
      color: rgba(226, 236, 246, 0.78);
      font-size: 0.98rem;
      line-height: 1.45;
    }

    .fpw-compact-tool-hero__accent {
      margin: 14px 0 0;
      color: #39f4ee;
      font-weight: 800;
    }

    .fpw-compact-tool-hero__image {
      position: absolute;
      inset: 0;
      z-index: 1;
      min-height: 0;
      pointer-events: none;
      background-image:
        linear-gradient(90deg,
          rgba(1, 12, 22, 1) 0%,
          rgba(1, 12, 22, 1) 32%,
          rgba(1, 12, 22, 0.88) 46%,
          rgba(1, 12, 22, 0.52) 60%,
          rgba(1, 12, 22, 0.18) 76%,
          rgba(1, 12, 22, 0) 92%
        ),
        linear-gradient(180deg, rgba(1, 12, 22, 0.22), rgba(1, 12, 22, 0) 42%, rgba(1, 12, 22, 0.22)),
        url("../assets/images/boat-fuel-calculator/Silent-voyage-on-calm-waters.png");
      background-size: cover, cover, cover;
      background-position: center right, center right, center right;
      background-repeat: no-repeat;
    }

    .fpw-mini-compass svg,
    .fpw-card-icon svg,
    .fpw-fuel-cta__icon svg {
      width: 100%;
      height: 100%;
      fill: none;
      stroke: currentColor;
      stroke-width: 2;
      stroke-linecap: round;
      stroke-linejoin: round;
    }

    .fpw-section-rule {
      display: grid;
      grid-template-columns: minmax(0, 1fr) auto minmax(0, 1fr);
      gap: 24px;
      align-items: center;
      margin: 28px 0 20px;
      text-align: center;
    }

    .fpw-section-rule span {
      height: 1px;
      background: linear-gradient(90deg, transparent, rgba(126, 205, 220, 0.48), transparent);
    }

    .fpw-section-rule h2,
    .fpw-panel-heading h2 {
      margin: 0;
      color: #7df7f0;
      font-size: 0.92rem;
      font-weight: 900;
      letter-spacing: 0.32em;
      text-transform: uppercase;
    }

    .fpw-why-grid,
    .fpw-results-grid,
    .fpw-fuel-education {
      display: grid;
      gap: 16px;
    }

    .fpw-why-grid {
      grid-template-columns: repeat(3, minmax(0, 1fr));
    }

    .fpw-why-card,
    .fpw-fuel-calculator-panel,
    .fpw-result-card,
    .fpw-info-card,
    .fpw-fuel-cta,
    .fpw-dev-output {
      border: 1px solid var(--fuel-line);
      background:
        linear-gradient(180deg, rgba(8, 26, 44, 0.84), rgba(3, 14, 26, 0.94));
      box-shadow: 0 18px 44px rgba(0, 0, 0, 0.28), inset 0 1px 0 rgba(255, 255, 255, 0.04);
    }

    .fpw-why-card {
      min-height: 110px;
      display: grid;
      grid-template-columns: 54px minmax(0, 1fr);
      gap: 18px;
      align-items: center;
      border-radius: 10px;
      padding: 20px 24px;
    }

    .fpw-card-icon {
      width: 48px;
      height: 48px;
      color: #28f3e8;
      filter: drop-shadow(0 0 16px rgba(40, 243, 232, 0.35));
    }

    .fpw-why-card h3,
    .fpw-info-card h2,
    .fpw-result-card h3 {
      margin: 0;
      color: #ffffff;
      line-height: 1.18;
      letter-spacing: 0;
    }

    .fpw-why-card h3 {
      font-size: 1.08rem;
    }

    .fpw-why-card p,
    .fpw-info-card p,
    .fpw-info-card li,
    .fpw-fuel-cta p {
      color: var(--fuel-muted);
      line-height: 1.5;
    }

    .fpw-why-card p {
      margin: 7px 0 0;
      font-size: 0.94rem;
    }

    .fpw-fuel-calculator-panel {
      margin-top: 20px;
      border-radius: var(--fuel-radius);
      padding: 24px 26px;
    }

    .fpw-panel-heading {
      display: grid;
      grid-template-columns: minmax(0, 1fr) auto;
      gap: 16px;
      align-items: center;
      margin-bottom: 20px;
    }

    .fpw-panel-heading::after {
      content: "";
      height: 1px;
      background: linear-gradient(90deg, rgba(35, 215, 207, 0.68), transparent);
    }

    .fpw-panel-heading p {
      grid-column: 2;
      grid-row: 1;
      margin: 0;
      color: var(--fuel-soft);
      font-size: 0.84rem;
      white-space: nowrap;
    }

    .fpw-fuel-form {
      display: grid;
      grid-template-columns: repeat(2, minmax(0, 1fr));
      gap: 32px;
    }

    .fpw-input-group {
      display: grid;
      gap: 14px;
      align-content: start;
    }

    .fpw-input-group h3 {
      display: flex;
      align-items: center;
      gap: 10px;
      margin: 0;
      padding-bottom: 8px;
      border-bottom: 1px solid rgba(126, 205, 220, 0.16);
      color: #7df7f0;
      font-size: 0.86rem;
      font-weight: 900;
      letter-spacing: 0.14em;
      text-transform: uppercase;
    }

    .fpw-field {
      position: relative;
      display: grid;
      grid-template-columns: minmax(140px, 0.72fr) minmax(0, 1fr);
      gap: 16px;
      align-items: center;
    }

    .fpw-field label {
      color: rgba(238, 247, 251, 0.9);
      font-size: 0.92rem;
      font-weight: 700;
      line-height: 1.25;
    }

    .fpw-label-row {
      display: inline-flex;
      align-items: flex-start;
      gap: 4px;
      width: fit-content;
    }

    .fpw-label-row label {
      margin: 0;
    }

    .fuelcalc-page .fpw-help {
      width: 10px;
      height: 10px;
      flex: 0 0 10px;
      display: inline-flex;
      align-items: center;
      justify-content: center;
      border: 1px solid rgba(69, 227, 255, 0.55);
      border-radius: 50%;
      padding: 0;
      color: #78f2ff;
      background: rgba(8, 22, 40, 0.9);
      font: inherit;
      font-size: 7px;
      font-weight: 800;
      line-height: 1;
      margin-top: 1px;
      cursor: pointer;
      transition: border-color 180ms ease, box-shadow 180ms ease, background 180ms ease, color 180ms ease;
    }

    .fuelcalc-page .fpw-help:hover,
    .fuelcalc-page .fpw-help:focus {
      outline: none;
      border-color: #45e3ff;
      color: #ffffff;
      background: rgba(10, 31, 55, 1);
      box-shadow: 0 0 0 3px rgba(69, 227, 255, 0.14), 0 0 16px rgba(69, 227, 255, 0.2);
    }

    .fpw-tooltip {
      position: absolute;
      left: 0;
      top: calc(100% + 8px);
      z-index: 50;
      width: min(320px, calc(100vw - 48px));
      border: 1px solid rgba(69, 227, 255, 0.35);
      border-radius: 12px;
      padding: 12px 14px;
      color: #d8e7f3;
      background: rgba(6, 18, 35, 0.98);
      box-shadow: 0 10px 28px rgba(0, 0, 0, 0.35), 0 0 24px rgba(35, 215, 207, 0.08);
      font-size: 0.86rem;
      line-height: 1.45;
      opacity: 0;
      visibility: hidden;
      transform: translateY(6px);
      transition: opacity 180ms ease, transform 180ms ease, visibility 180ms ease;
      pointer-events: none;
    }

    .fpw-tooltip.is-visible {
      opacity: 1;
      visibility: visible;
      transform: translateY(0);
      pointer-events: auto;
    }

    .fpw-field__control {
      position: relative;
      display: block;
    }

    .fpw-field input,
    .fpw-field select {
      width: 100%;
      min-height: 44px;
      border: 1px solid rgba(126, 205, 220, 0.28);
      border-radius: 6px;
      padding: 0 48px 0 12px;
      color: rgba(244, 248, 255, 0.96);
      background: rgba(3, 13, 26, 0.82);
      outline: none;
      transition: border-color 160ms ease, box-shadow 160ms ease, background 160ms ease;
    }

    .fpw-field select {
      padding-right: 32px;
    }

    .fpw-field input:focus-visible,
    .fpw-field select:focus-visible,
    .fpw-ghost-button:focus-visible,
    .fpw-fuel-cta__button:focus-visible,
    .fpw-info-card summary:focus-visible {
      border-color: var(--fuel-line-strong);
      box-shadow: 0 0 0 3px rgba(35, 215, 207, 0.18), 0 0 22px rgba(35, 215, 207, 0.18);
    }

    .fpw-field input[aria-invalid="true"] {
      border-color: rgba(255, 204, 92, 0.62);
    }

    .fpw-field input::placeholder {
      color: rgba(174, 194, 219, 0.72);
    }

    .fpw-field__unit {
      position: absolute;
      top: 50%;
      right: 12px;
      color: rgba(220, 234, 246, 0.88);
      font-size: 0.86rem;
      font-style: normal;
      font-weight: 800;
      transform: translateY(-50%);
      pointer-events: none;
    }

    .field-note {
      grid-column: 2;
      margin-top: -6px;
      color: var(--fuel-soft);
      font-size: 0.8rem;
      line-height: 1.45;
    }

    .field-note.fpw-field-error {
      color: #ffcc5c;
    }

    .field-note.fpw-capacity-status {
      margin-top: 0;
      color: rgba(220, 234, 246, 0.94);
      font-weight: 700;
    }

    .field-note.fpw-capacity-status[data-capacity-state="shortfall"] {
      color: #ffcc5c;
    }

    .calc-actions {
      display: flex;
      flex-wrap: wrap;
      gap: 14px;
      margin-top: 20px;
    }

    .fpw-ghost-button {
      min-height: 46px;
      display: inline-flex;
      align-items: center;
      justify-content: center;
      gap: 10px;
      border: 1px solid rgba(35, 215, 207, 0.58);
      border-radius: 7px;
      padding: 0 18px;
      color: rgba(238, 247, 251, 0.94);
      background: rgba(3, 18, 33, 0.56);
      cursor: pointer;
      transition: transform 160ms ease, border-color 160ms ease, color 160ms ease, box-shadow 160ms ease;
    }

    .fpw-ghost-button:hover {
      color: #ffffff;
      border-color: rgba(40, 243, 232, 0.82);
      transform: translateY(-1px);
    }

    .fpw-fuel-note,
    .msg.warn {
      border: 1px solid rgba(35, 215, 207, 0.58);
      border-radius: 10px;
      background: linear-gradient(135deg, rgba(8, 83, 97, 0.34), rgba(3, 18, 33, 0.74));
      color: rgba(238, 247, 251, 0.92);
    }

    .fpw-fuel-note {
      display: grid;
      grid-template-columns: 34px minmax(0, 1fr);
      gap: 16px;
      align-items: center;
      margin-top: 20px;
      padding: 14px 18px;
    }

    .fpw-fuel-note span {
      width: 30px;
      height: 30px;
      display: grid;
      place-items: center;
      border: 2px solid var(--fuel-cyan);
      border-radius: 50%;
      color: var(--fuel-cyan);
      font-weight: 900;
    }

    .fpw-fuel-note p {
      margin: 0;
      color: rgba(238, 247, 251, 0.92);
      line-height: 1.45;
    }

    .msg.warn {
      margin-top: 18px;
      padding: 14px 18px;
      color: var(--fuel-muted);
    }

    .msg.warn strong,
    .msg.warn ul {
      color: var(--fuel-text);
    }

    .msg.warn ul {
      margin: 8px 0 0 20px;
      padding: 0;
    }

    .msg.warn .msg-detail {
      margin-top: 8px;
    }

    .fpw-results-grid {
      grid-template-columns: repeat(7, minmax(0, 1fr));
    }

    .fpw-result-card {
      min-height: 142px;
      border-radius: 9px;
      padding: 18px 18px 16px;
    }

    .fpw-result-card__icon {
      display: inline-flex;
      margin-bottom: 10px;
      color: var(--fuel-cyan);
      font-size: 1.35rem;
      line-height: 1;
    }

    .fpw-result-card h3 {
      color: rgba(220, 234, 246, 0.82);
      font-size: 0.78rem;
      font-weight: 850;
      letter-spacing: 0.08em;
      text-transform: uppercase;
    }

    .fpw-result-card .value {
      display: block;
      margin-top: 14px;
      color: #ffffff;
      font-size: clamp(1.85rem, 3vw, 2.55rem);
      font-weight: 900;
      line-height: 1;
      letter-spacing: -0.02em;
    }

    .fpw-result-card .sub {
      margin-top: 10px;
      color: var(--fuel-soft);
      font-size: 0.86rem;
      line-height: 1.4;
    }

    .fpw-result-card--range .value {
      font-size: clamp(1.35rem, 2.2vw, 2rem);
      line-height: 1.1;
    }

    .fpw-result-card--cost .value {
      font-size: clamp(1.35rem, 1.8vw, 1.75rem);
      overflow-wrap: anywhere;
    }

    .fpw-fuel-education {
      grid-template-columns: 1.06fr 1fr 0.94fr;
      margin-top: 24px;
    }

    .fpw-fuel-safety-resources {
      display: grid;
      gap: 4px;
      margin: 0;
      padding: 14px 4px;
      border-block: 1px solid rgba(126, 205, 220, 0.22);
    }

    .fpw-fuel-safety-resources p {
      margin: 0;
      color: var(--fuel-muted);
      line-height: 1.6;
    }

    .fpw-fuel-safety-resources strong {
      color: var(--fuel-text);
    }

    .fpw-fuel-safety-resources a {
      padding-block: 0.15em;
      color: #7df7f0;
      font-weight: 800;
      text-decoration: underline;
      text-decoration-thickness: 1px;
      text-underline-offset: 0.18em;
    }

    .fpw-fuel-safety-resources a:hover {
      color: #ffffff;
    }

    .fpw-fuel-safety-resources a:focus-visible {
      border-radius: 2px;
      outline: 2px solid #ffffff;
      outline-offset: 3px;
    }

    .fpw-info-card {
      min-height: 210px;
      position: relative;
      overflow: hidden;
      border-radius: 10px;
      padding: 24px 26px;
    }

    .fpw-info-card::after {
      content: "";
      position: absolute;
      right: -42px;
      bottom: -56px;
      width: 190px;
      height: 150px;
      border: 1px solid rgba(35, 215, 207, 0.12);
      border-radius: 50%;
      box-shadow: inset 0 0 28px rgba(35, 215, 207, 0.08);
      pointer-events: none;
    }

    .fpw-info-card h2 {
      margin-bottom: 18px;
      color: rgba(238, 247, 251, 0.94);
      font-size: 0.94rem;
      font-weight: 900;
      letter-spacing: 0.08em;
      text-transform: uppercase;
    }

    .fpw-number-list,
    .fpw-info-card ul {
      display: grid;
      gap: 10px;
      margin: 0;
      padding: 0;
    }

    .fpw-number-list {
      list-style: none;
    }

    .fpw-number-list__item {
      display: grid;
      grid-template-columns: 24px minmax(0, 1fr);
      gap: 10px;
      align-items: start;
    }

    .fpw-number-list__badge {
      width: 20px;
      height: 20px;
      display: grid;
      place-items: center;
      border-radius: 50%;
      color: #02212a;
      background: var(--fuel-cyan);
      font-size: 0.78rem;
      font-weight: 900;
    }

    .fpw-fuel-cta--midpage {
      margin-top: 20px;
    }

    .fpw-info-card ul {
      padding-left: 1.1rem;
    }

    .fpw-faq-card {
      display: grid;
      gap: 8px;
    }

    .fpw-faq-card details {
      border: 1px solid rgba(126, 205, 220, 0.18);
      border-radius: 7px;
      background: rgba(3, 13, 26, 0.48);
    }

    .fpw-faq-card summary {
      min-height: 36px;
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 12px;
      padding: 0 12px;
      color: rgba(238, 247, 251, 0.9);
      cursor: pointer;
      font-size: 0.84rem;
      list-style: none;
    }

    .fpw-faq-card summary::-webkit-details-marker {
      display: none;
    }

    .fpw-faq-card summary::after {
      content: ">";
      color: var(--fuel-cyan);
    }

    .fpw-faq-card details[open] summary::after {
      transform: rotate(90deg);
    }

    .fpw-faq-card details p {
      margin: 0;
      padding: 0 12px 12px;
      font-size: 0.84rem;
    }

    .fpw-visually-hidden {
      position: absolute;
      width: 1px;
      height: 1px;
      padding: 0;
      margin: -1px;
      overflow: hidden;
      clip: rect(0, 0, 0, 0);
      white-space: nowrap;
      border: 0;
    }

    .fpw-fuel-guide {
      display: grid;
      gap: 20px;
      margin-top: 24px;
    }

    .fpw-guide-section {
      border: 1px solid var(--fuel-line);
      border-radius: 12px;
      padding: clamp(22px, 3vw, 32px);
      background:
        linear-gradient(180deg, rgba(8, 26, 44, 0.82), rgba(3, 14, 26, 0.94));
      box-shadow: 0 18px 44px rgba(0, 0, 0, 0.24), inset 0 1px 0 rgba(255, 255, 255, 0.035);
    }

    .fpw-guide-section h2,
    .fpw-guide-section h3,
    .fpw-guide-card h3 {
      color: #ffffff;
      letter-spacing: 0;
    }

    .fpw-guide-section h2 {
      margin: 0 0 16px;
      font-size: clamp(1.45rem, 2.4vw, 2rem);
      line-height: 1.14;
    }

    .fpw-guide-section h3,
    .fpw-guide-card h3 {
      margin: 0 0 10px;
      font-size: 1.05rem;
      line-height: 1.25;
    }

    .fpw-guide-section p,
    .fpw-guide-section li,
    .fpw-guide-card p,
    .fpw-guide-card li {
      color: var(--fuel-muted);
      line-height: 1.62;
    }

    .fpw-guide-section p {
      margin: 0;
    }

    .fpw-guide-section p + p {
      margin-top: 12px;
    }

    .fpw-guide-section strong {
      color: var(--fuel-text);
    }

    .fpw-guide-section a {
      color: #7df7f0;
      font-weight: 800;
      text-decoration: underline;
      text-decoration-thickness: 1px;
      text-underline-offset: 0.18em;
      overflow-wrap: anywhere;
    }

    .fpw-guide-section a:hover {
      color: #ffffff;
    }

    .fpw-guide-section a:focus-visible,
    .fpw-guide-faq summary:focus-visible {
      border-radius: 3px;
      outline: 2px solid #ffffff;
      outline-offset: 3px;
    }

    .fpw-guide-callout,
    .fpw-guide-note,
    .fpw-reserve-callout {
      margin-top: 20px;
      border: 1px solid rgba(35, 215, 207, 0.36);
      border-left: 4px solid var(--fuel-cyan);
      border-radius: 9px;
      padding: 20px 22px;
      background: linear-gradient(135deg, rgba(8, 83, 97, 0.24), rgba(3, 18, 33, 0.72));
    }

    .fpw-guide-callout h3,
    .fpw-reserve-callout h3 {
      color: #7df7f0;
    }

    .fpw-guide-source-note {
      margin-top: 12px !important;
      color: var(--fuel-soft) !important;
      font-size: 0.86rem;
    }

    .fpw-fuel-data-table-wrap {
      margin-top: 18px;
      border: 1px solid rgba(126, 205, 220, 0.22);
      border-radius: 9px;
      overflow: hidden;
    }

    .fpw-fuel-data-table {
      width: 100%;
      border-collapse: collapse;
      table-layout: fixed;
      font-size: 0.88rem;
    }

    .fpw-fuel-data-table th,
    .fpw-fuel-data-table td {
      border-bottom: 1px solid rgba(126, 205, 220, 0.16);
      padding: 13px 12px;
      text-align: left;
      vertical-align: top;
      overflow-wrap: anywhere;
    }

    .fpw-fuel-data-table th {
      color: #7df7f0;
      background: rgba(255, 255, 255, 0.045);
      font-size: 0.76rem;
      font-weight: 900;
      letter-spacing: 0.05em;
      text-transform: uppercase;
    }

    .fpw-fuel-data-table td {
      color: var(--fuel-muted);
      line-height: 1.45;
    }

    .fpw-fuel-data-table th:first-child {
      width: 27%;
    }

    .fpw-fuel-data-table th:last-child {
      width: 13%;
    }

    .fpw-fuel-data-table tbody tr:last-child td {
      border-bottom: 0;
    }

    .fpw-fuel-data-table strong,
    .fpw-fuel-data-table small {
      display: block;
    }

    .fpw-fuel-data-table small {
      margin-top: 4px;
      color: var(--fuel-soft);
      line-height: 1.35;
    }

    .fpw-guide-card-grid,
    .fpw-formula-grid,
    .fpw-factor-grid,
    .fpw-example-grid,
    .fpw-step-list {
      display: grid;
      gap: 14px;
      margin-top: 18px;
    }

    .fpw-formula-grid {
      grid-template-columns: repeat(3, minmax(0, 1fr));
    }

    .fpw-factor-grid,
    .fpw-step-list {
      grid-template-columns: repeat(2, minmax(0, 1fr));
    }

    .fpw-example-grid {
      grid-template-columns: repeat(2, minmax(0, 1fr));
    }

    .fpw-guide-card,
    .fpw-step-list > li,
    .fpw-example-leg {
      min-width: 0;
      border: 1px solid rgba(126, 205, 220, 0.19);
      border-radius: 9px;
      padding: 18px;
      background: rgba(3, 13, 26, 0.5);
    }

    .fpw-formula-card code,
    .fpw-example-math code {
      display: block;
      margin-top: 14px;
      border: 1px solid rgba(35, 215, 207, 0.25);
      border-radius: 6px;
      padding: 10px 12px;
      color: #7df7f0;
      background: rgba(2, 10, 20, 0.72);
      font-family: Consolas, Menlo, Monaco, monospace;
      font-size: 0.86rem;
      line-height: 1.45;
      overflow-wrap: anywhere;
      white-space: normal;
    }

    .fpw-factor-card ul,
    .fpw-reserve-callout ul,
    .fpw-source-list {
      margin: 12px 0 0;
      padding-left: 1.15rem;
    }

    .fpw-factor-card p {
      margin-top: 12px;
    }

    .fpw-step-list {
      margin-bottom: 0;
      padding: 0;
      list-style: none;
      counter-reset: fpw-fuel-step;
    }

    .fpw-step-list > li {
      counter-increment: fpw-fuel-step;
    }

    .fpw-step-list h3 {
      display: grid;
      grid-template-columns: 30px minmax(0, 1fr);
      gap: 10px;
      align-items: center;
    }

    .fpw-step-list h3::before {
      content: counter(fpw-fuel-step);
      width: 28px;
      height: 28px;
      display: grid;
      place-items: center;
      border-radius: 50%;
      color: #02212a;
      background: var(--fuel-cyan);
      font-size: 0.82rem;
      font-weight: 900;
    }

    .fpw-example-assumptions {
      display: flex;
      flex-wrap: wrap;
      gap: 8px;
      margin: 0 0 18px;
      padding: 0;
      list-style: none;
    }

    .fpw-example-assumptions li {
      border: 1px solid rgba(126, 205, 220, 0.22);
      border-radius: 999px;
      padding: 6px 10px;
      color: rgba(238, 247, 251, 0.88);
      background: rgba(3, 13, 26, 0.46);
      font-size: 0.82rem;
    }

    .fpw-example-math p + p {
      margin-top: 8px;
    }

    .fpw-example-total {
      margin-top: 16px;
      border-top: 1px solid rgba(126, 205, 220, 0.2);
      padding-top: 16px;
    }

    .fpw-guide-faq {
      display: grid;
      gap: 10px;
    }

    .fpw-guide-faq details {
      border: 1px solid rgba(126, 205, 220, 0.2);
      border-radius: 8px;
      background: rgba(3, 13, 26, 0.5);
    }

    .fpw-guide-faq summary {
      min-height: 52px;
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 16px;
      padding: 12px 16px;
      color: rgba(238, 247, 251, 0.94);
      cursor: pointer;
      font-weight: 800;
      line-height: 1.35;
      list-style: none;
    }

    .fpw-guide-faq summary::-webkit-details-marker {
      display: none;
    }

    .fpw-guide-faq summary::after {
      content: "+";
      flex: 0 0 auto;
      color: var(--fuel-cyan);
      font-size: 1.2rem;
      line-height: 1;
    }

    .fpw-guide-faq details[open] summary::after {
      content: "-";
    }

    .fpw-guide-faq details p {
      margin: 0;
      padding: 0 16px 16px;
      font-size: 0.92rem;
    }

    .fpw-source-list {
      display: grid;
      gap: 8px;
      font-size: 0.9rem;
    }

    .fpw-guide-section--sources {
      padding-block: 22px;
    }

    .fpw-guide-section--sources h2 {
      font-size: 1.3rem;
    }

    .fpw-dev-output {
      margin-top: 24px;
      border-radius: 10px;
      overflow: hidden;
    }

    .fpw-dev-output summary {
      min-height: 46px;
      display: inline-flex;
      align-items: center;
      gap: 8px;
      padding: 0 18px;
      color: rgba(238, 247, 251, 0.9);
      cursor: pointer;
      font-weight: 800;
      list-style: none;
    }

    .fpw-dev-output summary::-webkit-details-marker {
      display: none;
    }

    .fpw-dev-output summary::after {
      content: ">";
      color: var(--fuel-cyan);
      font-size: 1.1rem;
      line-height: 1;
      transition: transform 160ms ease;
    }

    .fpw-dev-output[open] summary::after {
      transform: rotate(90deg);
    }

    .fpw-dev-output table {
      width: 100%;
      border-collapse: collapse;
      font-size: 0.86rem;
    }

    .fpw-dev-output th,
    .fpw-dev-output td {
      border-top: 1px solid rgba(126, 205, 220, 0.16);
      padding: 10px 12px;
      color: rgba(226, 238, 255, 0.95);
      text-align: left;
      vertical-align: top;
    }

    .fpw-dev-output th {
      color: #ffffff;
      background: rgba(255, 255, 255, 0.04);
    }

    .fpw-dev-output td.num {
      text-align: right;
      font-family: Consolas, Menlo, Monaco, monospace;
    }

    .fpw-dev-output pre {
      margin: 0;
      padding: 14px;
      border-top: 1px solid rgba(126, 205, 220, 0.16);
      color: #eef6ff;
      background: rgba(2, 8, 17, 0.78);
      overflow: auto;
      font-size: 0.76rem;
      line-height: 1.45;
    }

    .fpw-fuel-cta {
      display: grid;
      grid-template-columns: auto minmax(0, 1fr) auto;
      gap: 28px;
      align-items: center;
      margin-top: 24px;
      border-color: rgba(35, 215, 207, 0.62);
      border-radius: 12px;
      padding: 24px 36px;
      background:
        radial-gradient(circle at 10% 50%, rgba(35, 215, 207, 0.16), transparent 13rem),
        radial-gradient(circle at 88% 48%, rgba(56, 189, 248, 0.12), transparent 15rem),
        linear-gradient(180deg, rgba(4, 21, 36, 0.96), rgba(3, 12, 24, 0.98));
    }

    .fpw-fuel-cta__icon {
      width: 74px;
      height: 74px;
      display: grid;
      place-items: center;
      border: 1px solid rgba(35, 215, 207, 0.42);
      border-radius: 50%;
      color: var(--fuel-cyan);
      box-shadow: 0 0 24px rgba(35, 215, 207, 0.22);
    }

    .fpw-fuel-cta h2 {
      margin: 0;
      color: #ffffff;
      font-size: clamp(1.5rem, 3vw, 2rem);
      line-height: 1.1;
    }

    .fpw-fuel-cta p {
      margin: 8px 0 0;
    }

    .fpw-fuel-cta__button {
      min-height: 52px;
      display: inline-flex;
      align-items: center;
      justify-content: center;
      gap: 12px;
      border: 1px solid rgba(127, 252, 246, 0.8);
      border-radius: 8px;
      padding: 0 32px;
      color: #041421;
      background: linear-gradient(135deg, #28f3e8, #0db7c9);
      box-shadow: 0 0 28px rgba(33, 243, 238, 0.34);
      font-weight: 900;
      white-space: nowrap;
    }

    .fpw-fuel-cta__small {
      grid-column: 3;
      margin: -12px 0 0;
      color: #28f3e8;
      text-align: center;
      font-size: 0.86rem;
      font-weight: 800;
    }

    @media (max-width: 1180px) {
      .fpw-results-grid {
        grid-template-columns: repeat(3, minmax(0, 1fr));
      }

      .fpw-result-card--range {
        grid-column: 1 / -1;
      }

      .fpw-fuel-education {
        grid-template-columns: 1fr;
      }
    }

    @media (max-width: 900px) {
      .fpw-fuel-page {
        width: min(var(--fpw-public-layout-max), calc(100% - (var(--fpw-page-gutter, 32px) * 2)));
      }

      .fuel-compact-hero {
        grid-template-columns: 1fr;
        min-height: 230px;
        background-image:
          linear-gradient(90deg, rgba(1, 12, 22, 0.98), rgba(1, 12, 22, 0.78)),
          url("../assets/images/boat-fuel-calculator/Silent-voyage-on-calm-waters.png");
        background-size: cover;
        background-position: center right;
      }

      .fpw-compact-tool-hero__image {
        display: none;
      }

      .fpw-compact-tool-hero__content {
        padding: 30px 24px;
      }

      .fpw-why-grid,
      .fpw-fuel-form {
        grid-template-columns: 1fr;
      }

      .fpw-formula-grid,
      .fpw-step-list,
      .fpw-example-grid {
        grid-template-columns: 1fr;
      }

      .fpw-fuel-data-table-wrap {
        border: 0;
        overflow: visible;
      }

      .fpw-fuel-data-table,
      .fpw-fuel-data-table tbody {
        display: block;
      }

      .fpw-fuel-data-table thead {
        position: absolute;
        width: 1px;
        height: 1px;
        padding: 0;
        margin: -1px;
        overflow: hidden;
        clip: rect(0, 0, 0, 0);
        white-space: nowrap;
        border: 0;
      }

      .fpw-fuel-data-table tbody {
        display: grid;
        gap: 12px;
      }

      .fpw-fuel-data-table tr {
        display: grid;
        border: 1px solid rgba(126, 205, 220, 0.2);
        border-radius: 9px;
        padding: 8px 14px;
        background: rgba(3, 13, 26, 0.5);
      }

      .fpw-fuel-data-table td {
        display: grid;
        grid-template-columns: minmax(130px, 0.42fr) minmax(0, 1fr);
        gap: 14px;
        border-bottom: 1px solid rgba(126, 205, 220, 0.14);
        padding: 10px 0;
      }

      .fpw-fuel-data-table td::before {
        content: attr(data-label);
        color: #7df7f0;
        font-size: 0.74rem;
        font-weight: 900;
        letter-spacing: 0.04em;
        text-transform: uppercase;
      }

      .fpw-fuel-data-table tr td:last-child {
        border-bottom: 0;
      }

      .fpw-panel-heading {
        grid-template-columns: 1fr;
      }

      .fpw-panel-heading::after {
        grid-row: 2;
      }

      .fpw-panel-heading p {
        grid-column: 1;
        grid-row: auto;
        white-space: normal;
      }

      .fpw-fuel-cta {
        grid-template-columns: auto minmax(0, 1fr);
      }

      .fpw-fuel-cta__button,
      .fpw-fuel-cta__small {
        grid-column: 1 / -1;
        justify-self: start;
      }
    }

    @media (max-width: 640px) {
      .fpw-fuel-page {
        width: min(var(--fpw-public-layout-max), calc(100% - (var(--fpw-page-gutter, 32px) * 2)));
        padding-top: 16px;
      }

      .fuel-compact-hero {
        min-height: 220px;
      }

      .fpw-compact-tool-hero__content {
        padding: 26px 20px;
      }

      .fpw-compact-tool-hero__eyebrow {
        font-size: 0.74rem;
        letter-spacing: 0.16em;
      }

      .fpw-compact-tool-hero h1 {
        font-size: clamp(2.125rem, 9vw, 2.625rem);
        line-height: 1;
      }

      .fpw-compact-tool-hero__intro {
        margin-top: 10px;
        font-size: 1rem;
      }

      .fpw-compact-tool-hero__supporting {
        font-size: 1.2rem;
      }

      .fpw-compact-tool-hero__intent {
        font-size: 0.94rem;
      }

      .fpw-compact-tool-hero__accent {
        margin-top: 12px;
      }

      .fpw-section-rule {
        grid-template-columns: 1fr;
        gap: 10px;
      }

      .fpw-section-rule span {
        display: none;
      }

      .fpw-why-card {
        grid-template-columns: 1fr;
      }

      .fpw-fuel-calculator-panel,
      .fpw-info-card,
      .fpw-fuel-cta,
      .fpw-guide-section {
        padding: 20px;
      }

      .fpw-factor-grid {
        grid-template-columns: 1fr;
      }

      .fpw-fuel-data-table td {
        grid-template-columns: 1fr;
        gap: 4px;
      }

      .fpw-guide-callout,
      .fpw-guide-note,
      .fpw-reserve-callout {
        padding: 18px;
      }

      .fpw-field {
        grid-template-columns: 1fr;
        gap: 8px;
      }

      .field-note {
        grid-column: 1;
      }

      .calc-actions {
        display: grid;
        grid-template-columns: 1fr;
      }

      .fpw-results-grid {
        grid-template-columns: 1fr;
      }

      .fpw-result-card--range {
        grid-column: auto;
      }

      .fpw-fuel-cta {
        grid-template-columns: 1fr;
        text-align: left;
      }

      .fpw-fuel-cta__button {
        width: 100%;
      }
    }
  </style>
<link rel="stylesheet" href="../assets/css/layout.css?v=20260620-page-width">
<link rel="stylesheet" href="../assets/css/top-nav.css?v=20260814-featured-guides-layout-v1">
<link rel="stylesheet" href="../assets/css/fpw-action-cta.css?v=20260804-pilot">
<cfinclude template="../includes/analytics_ga4.cfm">
<cfinclude template="../includes/trustedsite.cfm">
</head>
<body class="fuelcalc-page">
<cfset request.fpwTopNavActive = "fuel">
<cfinclude template="../includes/top_nav.cfm">
  <main class="fpw-fuel-page fuelcalc-main">
    <section class="fpw-compact-tool-hero fuel-compact-hero" aria-labelledby="fuel-calculator-title">
      <div class="fpw-compact-tool-hero__content">
        <p class="fpw-compact-tool-hero__eyebrow">BOAT PLANNING TOOL</p>
        <h1 id="fuel-calculator-title">Boat Fuel Calculator</h1>
        <h2 class="fpw-compact-tool-hero__supporting">How much fuel will your boat need?</h2>
        <p class="fpw-compact-tool-hero__intro">
          Calculate the fuel required for your trip, safe reserve, cruising range, travel time and estimated cost using your boat's actual fuel burn.
        </p>
        <p class="fpw-compact-tool-hero__intent">
          Use the boat fuel calculator to estimate how many gallons of fuel you'll need for a trip based on distance, cruising speed and your boat's gallons-per-hour fuel burn.
        </p>
        <p class="fpw-compact-tool-hero__accent">Free. No account required.</p>
      </div>
      <div class="fpw-compact-tool-hero__image" aria-hidden="true"></div>
    </section>

    <section class="fpw-fuel-why" aria-labelledby="why-fuel-planning-title">
      <div class="fpw-section-rule">
        <span></span>
        <h2 id="why-fuel-planning-title">Why Fuel Planning Matters</h2>
        <span></span>
      </div>

      <div class="fpw-why-grid">
        <article class="fpw-why-card">
          <div class="fpw-card-icon" aria-hidden="true">
            <svg viewBox="0 0 32 32" focusable="false">
              <path d="M16 3 27 7v8c0 7-4.7 11.8-11 14-6.3-2.2-11-7-11-14V7z"></path>
              <path d="m10.8 15.8 3.2 3.2 7.4-8"></path>
            </svg>
          </div>
          <div>
            <h3>Safety First</h3>
            <p>Running out of fuel isn&rsquo;t an option. Plan ahead and stay in control.</p>
          </div>
        </article>

        <article class="fpw-why-card">
          <div class="fpw-card-icon" aria-hidden="true">
            <svg viewBox="0 0 32 32" focusable="false">
              <path d="M10 23H8a5 5 0 0 1 0-10 8 8 0 0 1 15.5-2A6 6 0 0 1 24 23h-2"></path>
              <path d="m17 14-5 8h5l-2 6 6-10h-5z"></path>
            </svg>
          </div>
          <div>
            <h3>Weather Changes Everything</h3>
            <p>Wind, current, and sea state can significantly impact fuel burn.</p>
          </div>
        </article>

        <article class="fpw-why-card">
          <div class="fpw-card-icon" aria-hidden="true">
            <svg viewBox="0 0 32 32" focusable="false">
              <path d="M8 29V4h12a4 4 0 0 1 4 4v21"></path>
              <path d="M8 13h16"></path>
              <path d="M24 10h2l3 4v10a3 3 0 0 1-3 3h-2"></path>
              <path d="M13 7h5"></path>
            </svg>
          </div>
          <div>
            <h3>Plan With Reserve</h3>
            <p>Build in reserve so you have options when conditions or plans change.</p>
          </div>
        </article>
      </div>
    </section>

    <section class="fpw-fuel-calculator-panel" aria-labelledby="fuel-planning-inputs-title">
      <div class="fpw-panel-heading">
        <h2 id="fuel-planning-inputs-title">Fuel Planning Inputs</h2>
        <p>All units are standard for recreational boating</p>
      </div>

      <form class="fpw-fuel-form" id="qaFuelCalcForm" onsubmit="return false;">
        <div class="fpw-input-group">
          <h3>Trip &amp; Speed</h3>

          <div class="field fpw-field">
            <div class="fpw-label-row">
              <label for="totalNm">Total Distance (NM)</label>
              <button type="button" class="fpw-help" aria-label="More information about Total Distance" aria-expanded="false" aria-describedby="tip-totalNm" data-tooltip-target="tip-totalNm">?</button>
            </div>
            <span class="fpw-field__control">
              <input id="totalNm" name="totalNm" type="number" inputmode="decimal" step="0.1" min="0" value="" placeholder="Enter nautical miles">
              <em class="fpw-field__unit">NM</em>
            </span>
            <div class="fpw-tooltip" id="tip-totalNm" role="tooltip">Total trip distance used to estimate total run time and fuel needed. Greater distance increases fuel use.</div>
          </div>

          <div class="field fpw-field">
            <div class="fpw-label-row">
              <label for="mostEfficientSpeedKn">Most Efficient Speed (kn)</label>
              <button type="button" class="fpw-help" aria-label="More information about Most Efficient Speed" aria-expanded="false" aria-describedby="tip-mostEfficientSpeedKn" data-tooltip-target="tip-mostEfficientSpeedKn">?</button>
            </div>
            <span class="fpw-field__control">
              <input id="mostEfficientSpeedKn" name="mostEfficientSpeedKn" type="number" inputmode="decimal" step="0.1" min="1" max="60" value="" placeholder="Required" required aria-describedby="requiredEfficientInputsMsg">
              <em class="fpw-field__unit">kn</em>
            </span>
            <div class="fpw-tooltip" id="tip-mostEfficientSpeedKn" role="tooltip">The speed where your boat burns fuel most efficiently. Used when the selected pace favors efficiency.</div>
          </div>

          <div class="field fpw-field">
            <div class="fpw-label-row">
              <label for="maxSpeedKn">Max Speed (kn)</label>
              <button type="button" class="fpw-help" aria-label="More information about Max Speed" aria-expanded="false" aria-describedby="tip-maxSpeedKn" data-tooltip-target="tip-maxSpeedKn">?</button>
            </div>
            <span class="fpw-field__control">
              <input id="maxSpeedKn" name="maxSpeedKn" type="number" inputmode="decimal" step="0.1" min="1" max="60" value="" placeholder="Required" aria-describedby="requiredEfficientInputsMsg">
              <em class="fpw-field__unit">kn</em>
            </span>
            <div class="fpw-tooltip" id="tip-maxSpeedKn" role="tooltip">Your expected higher cruising speed. Used when pace or routing assumptions call for faster travel.</div>
          </div>

          <div class="field fpw-field">
            <div class="fpw-label-row">
              <label for="idleBurnGph">Idle Burn (GPH)</label>
              <button type="button" class="fpw-help" aria-label="More information about Idle Burn" aria-expanded="false" aria-describedby="tip-idleBurnGph" data-tooltip-target="tip-idleBurnGph">?</button>
            </div>
            <span class="fpw-field__control">
              <input id="idleBurnGph" name="idleBurnGph" type="number" inputmode="decimal" step="0.1" min="0" value="" placeholder="Optional">
              <em class="fpw-field__unit">GPH</em>
            </span>
            <div class="fpw-tooltip" id="tip-idleBurnGph" role="tooltip">Fuel burned while idling, maneuvering, or waiting. If entered, it is added into the trip estimate.</div>
          </div>

          <div class="field fpw-field">
            <div class="fpw-label-row">
              <label for="weatherPct">Weather Factor (%)</label>
              <button type="button" class="fpw-help" aria-label="More information about Weather Factor" aria-expanded="false" aria-describedby="tip-weatherPct" data-tooltip-target="tip-weatherPct">?</button>
            </div>
            <span class="fpw-field__control">
              <input id="weatherPct" name="weatherPct" type="number" inputmode="decimal" step="1" min="0" max="60" value="0">
              <em class="fpw-field__unit">%</em>
            </span>
            <div class="fpw-tooltip" id="tip-weatherPct" role="tooltip">Adds a percentage buffer to account for extra burn from wind, waves, current, or rougher conditions.</div>
          </div>

          <div class="field fpw-field">
            <div class="fpw-label-row">
              <label for="underwayHoursPerDay">Underway Hrs / Day</label>
              <button type="button" class="fpw-help" aria-label="More information about Underway Hrs / Day" aria-expanded="false" aria-describedby="tip-underwayHoursPerDay" data-tooltip-target="tip-underwayHoursPerDay">?</button>
            </div>
            <span class="fpw-field__control">
              <input id="underwayHoursPerDay" name="underwayHoursPerDay" type="number" inputmode="decimal" step="0.5" min="1" max="24" value="6.5">
              <em class="fpw-field__unit">hrs</em>
            </span>
            <div class="fpw-tooltip" id="tip-underwayHoursPerDay" role="tooltip">Used to estimate how many travel days the trip may require based on your expected daily running time.</div>
          </div>

          <div class="calc-actions">
            <button class="fpw-ghost-button" type="button" id="resetBtn">
              <span aria-hidden="true">&olarr;</span>
              Reset
            </button>

            <button class="fpw-ghost-button" type="button" id="copyJsonBtn">
              <span aria-hidden="true">[]</span>
              Copy Result JSON
            </button>
          </div>
        </div>

        <div class="fpw-input-group">
          <h3>Performance &amp; Consumption</h3>

          <div class="field fpw-field">
            <div class="fpw-label-row">
              <label for="pace">Pace</label>
              <button type="button" class="fpw-help" aria-label="More information about Pace" aria-expanded="false" aria-describedby="tip-pace" data-tooltip-target="tip-pace">?</button>
            </div>
            <span class="fpw-field__control">
              <select id="pace" name="pace">
                <option value="RELAXED">Relaxed</option>
                <option value="BALANCED">Efficient Speed</option>
                <option value="AGGRESSIVE">Max Speed</option>
              </select>
            </span>
            <div class="fpw-tooltip" id="tip-pace" role="tooltip">Changes whether the estimate leans more toward efficient-speed or max-speed consumption assumptions.</div>
          </div>

          <div class="field fpw-field">
            <div class="fpw-label-row">
              <label for="fuelBurnEfficientGph">GPH @ Efficient</label>
              <button type="button" class="fpw-help" aria-label="More information about GPH @ Efficient" aria-expanded="false" aria-describedby="tip-fuelBurnEfficientGph" data-tooltip-target="tip-fuelBurnEfficientGph">?</button>
            </div>
            <span class="fpw-field__control">
              <input id="fuelBurnEfficientGph" name="fuelBurnEfficientGph" type="number" inputmode="decimal" step="0.1" min="0" value="" placeholder="Required" required aria-describedby="requiredEfficientInputsMsg">
              <em class="fpw-field__unit">GPH</em>
            </span>
            <div class="fpw-tooltip" id="tip-fuelBurnEfficientGph" role="tooltip">Fuel burned per hour at your most efficient speed. This directly affects fuel calculations for efficient pacing.</div>
          </div>

          <div class="field fpw-field">
            <div class="fpw-label-row">
              <label for="fuelBurnGph">Fuel Burn @ Max (GPH)</label>
              <button type="button" class="fpw-help" aria-label="More information about Fuel Burn @ Max" aria-expanded="false" aria-describedby="tip-fuelBurnGph" data-tooltip-target="tip-fuelBurnGph">?</button>
            </div>
            <span class="fpw-field__control">
              <input id="fuelBurnGph" name="fuelBurnGph" type="number" inputmode="decimal" step="0.1" min="0" value="" placeholder="Required for Relaxed or Max Speed" aria-describedby="requiredEfficientInputsMsg">
              <em class="fpw-field__unit">GPH</em>
            </span>
            <div class="fpw-tooltip" id="tip-fuelBurnGph" role="tooltip">Fuel burned per hour at higher cruising speed. This is used for relaxed or max-speed estimates.</div>
            <div class="field-note">Matches the Route Generator max-speed burn input. Pace and weather adjustments are derived from this value unless Efficient Speed uses the efficient inputs instead.</div>
          </div>

          <div class="field fpw-field">
            <div class="fpw-label-row">
              <label for="idleHoursTotal">Idle Hours</label>
              <button type="button" class="fpw-help" aria-label="More information about Idle Hours" aria-expanded="false" aria-describedby="tip-idleHoursTotal" data-tooltip-target="tip-idleHoursTotal">?</button>
            </div>
            <span class="fpw-field__control">
              <input id="idleHoursTotal" name="idleHoursTotal" type="number" inputmode="decimal" step="0.1" min="0" value="" placeholder="Optional">
              <em class="fpw-field__unit">hrs</em>
            </span>
            <div class="fpw-tooltip" id="tip-idleHoursTotal" role="tooltip">Optional extra hours of idling or slow maneuvering. Increases estimated fuel use.</div>
          </div>

          <div class="field fpw-field">
            <div class="fpw-label-row">
              <label for="usableFuelCapacityGallons">Usable Fuel Capacity</label>
              <button type="button" class="fpw-help" aria-label="More information about Usable Fuel Capacity" aria-expanded="false" aria-describedby="tip-usableFuelCapacityGallons" data-tooltip-target="tip-usableFuelCapacityGallons">?</button>
            </div>
            <span class="fpw-field__control">
              <input id="usableFuelCapacityGallons" name="usableFuelCapacityGallons" type="number" inputmode="decimal" step="0.01" min="0.01" value="" placeholder="Optional" aria-describedby="usableFuelCapacityHelp usableFuelCapacityError usableFuelCapacityStatus">
              <em class="fpw-field__unit">gal</em>
            </span>
            <div class="fpw-tooltip" id="tip-usableFuelCapacityGallons" role="tooltip">Enter the amount of fuel you consider usable for trip planning before applying your reserve.</div>
            <div class="field-note" id="usableFuelCapacityHelp">Usable fuel can be less than nominal tank capacity.</div>
            <div class="field-note fpw-field-error" id="usableFuelCapacityError" role="status" hidden>Enter a usable fuel capacity of at least 0.01 gallon.</div>
            <div class="field-note fpw-capacity-status" id="usableFuelCapacityStatus" role="status" aria-live="polite" hidden></div>
          </div>

          <div class="field fpw-field">
            <div class="fpw-label-row">
              <label for="reservePct">Reserve Method</label>
              <button type="button" class="fpw-help" aria-label="More information about Reserve" aria-expanded="false" aria-describedby="tip-reservePct" data-tooltip-target="tip-reservePct">?</button>
            </div>
            <span class="fpw-field__control">
              <select id="reservePct" name="reservePct" aria-describedby="tip-reservePct">
                <option value="33" data-reserve-mode="thirds" selected>One-Third Rule</option>
                <option value="20" data-reserve-mode="percentage">Standard Reserve - 20%</option>
                <option value="15" data-reserve-mode="percentage">Minimum Reserve - 15%</option>
              </select>
            </span>
            <div class="fpw-tooltip" id="tip-reservePct" role="tooltip">A conservative fuel-management practice that plans departure fuel so expected trip consumption uses no more than two-thirds of usable fuel, leaving one-third in reserve.</div>
          </div>

          <div class="field fpw-field">
            <div class="fpw-label-row">
              <label for="fuelPricePerGal">Fuel Price ($/gal)</label>
              <button type="button" class="fpw-help" aria-label="More information about Fuel Price" aria-expanded="false" aria-describedby="tip-fuelPricePerGal" data-tooltip-target="tip-fuelPricePerGal">?</button>
            </div>
            <span class="fpw-field__control">
              <input id="fuelPricePerGal" name="fuelPricePerGal" type="number" inputmode="decimal" step="0.01" min="0" value="" placeholder="Optional">
              <em class="fpw-field__unit">$/gal</em>
            </span>
            <div class="fpw-tooltip" id="tip-fuelPricePerGal" role="tooltip">Used only to estimate fuel cost. It does not change the fuel burn calculation itself.</div>
          </div>

          <div class="fpw-fuel-note">
            <span aria-hidden="true">i</span>
            <p>Estimated range is a planning value. Actual range can vary with sea conditions, current, wind, vessel load, engine condition, throttle use, and the amount of fuel that is practically usable.</p>
          </div>
        </div>
      </form>

      <div id="requiredEfficientInputsMsg" class="msg warn" hidden></div>
    </section>

    <section class="fpw-results-section" aria-labelledby="estimated-results-title">
      <div class="fpw-section-rule">
        <span></span>
        <h2 id="estimated-results-title">Estimated Results</h2>
        <span></span>
      </div>

      <div class="fpw-results-grid cards">
        <article class="card fpw-result-card">
          <span class="fpw-result-card__icon" aria-hidden="true">~</span>
          <h3 class="label">Total Distance</h3>
          <strong class="value" id="cardTotalDistance">0.0 NM</strong>
          <p class="sub" id="cardTotalDistanceSub">Manual distance input</p>
        </article>

        <article class="card fpw-result-card">
          <span class="fpw-result-card__icon" aria-hidden="true">o</span>
          <h3 class="label">Total Travel Hours</h3>
          <strong class="value" id="cardTotalHours">-- h</strong>
          <p class="sub" id="cardTotalHoursSub">Enter distance and inputs</p>
        </article>

        <article class="card fpw-result-card">
          <span class="fpw-result-card__icon" aria-hidden="true">F</span>
          <h3 class="label">Estimated Fuel</h3>
          <strong class="value" id="cardEstimatedFuel">-- gal</strong>
          <p class="sub" id="cardEstimatedFuelSub">Required + reserve</p>
        </article>

        <article class="card fpw-result-card">
          <span class="fpw-result-card__icon" aria-hidden="true">kn</span>
          <h3 class="label">Adjusted Speed</h3>
          <strong class="value" id="cardAdjustedSpeed">-- kn</strong>
          <p class="sub" id="cardAdjustedSpeedSub">Weather adjusted</p>
        </article>

        <article class="card fpw-result-card">
          <span class="fpw-result-card__icon" aria-hidden="true">G</span>
          <h3 class="label">Expected Avg GPH</h3>
          <strong class="value" id="cardExpectedAvgGph">-- GPH</strong>
          <p class="sub" id="cardExpectedAvgGphSub">Across all running time</p>
        </article>

        <article class="card fpw-result-card fpw-result-card--range">
          <span class="fpw-result-card__icon" aria-hidden="true">NM</span>
          <h3 class="label">Estimated Range with Reserve</h3>
          <strong class="value" id="cardEstimatedRange" aria-label="Enter fuel capacity">Enter fuel capacity</strong>
          <p class="sub" id="cardEstimatedRangeSub">Optional usable-fuel estimate</p>
        </article>

        <article class="card fpw-result-card fpw-result-card--cost">
          <span class="fpw-result-card__icon" aria-hidden="true">$</span>
          <h3 class="label">Fuel Cost</h3>
          <strong class="value" id="cardFuelCost">--</strong>
          <p class="sub" id="cardFuelCostSub">Based on fuel price</p>
        </article>
      </div>

      <details class="fpw-dev-output">
        <summary>Calculation Breakdown and JSON</summary>
        <table>
          <thead>
            <tr>
              <th>Metric</th>
              <th>Value</th>
              <th>How computed</th>
            </tr>
          </thead>
          <tbody id="calcBreakdownBody"></tbody>
        </table>

        <pre id="calcJsonOut" hidden></pre>
      </details>
    </section>

    <cfinclude template="../partials/fpw-action-cta.cfm">

    <div class="fpw-fuel-guide" aria-label="Boat fuel consumption guide">
      <section class="fpw-guide-section" aria-labelledby="fuel-use-per-hour-title">
        <h2 id="fuel-use-per-hour-title">How Much Fuel Does a Boat Use Per Hour?</h2>
        <p>Boat fuel use is usually measured in gallons per hour, or GPH. There is no single GPH number that applies to every boat of a certain length or horsepower. Fuel burn changes with engine RPM and load, the hull, boat weight, propeller, trim, weather, current, sea state and other operating conditions.</p>
        <p>The best number to use for trip planning is your boat's actual fuel burn at the speed you expect to cruise. If your engine display or fuel-flow system provides real-time GPH, use that value. Manufacturer performance tests for your specific boat and engine combination are the next-best reference.</p>

        <aside class="fpw-guide-callout" aria-labelledby="fuel-burn-speed-callout-title">
          <h3 id="fuel-burn-speed-callout-title">Fuel burn can rise much faster than speed</h3>
          <p><strong>One manufacturer test example:</strong> Yamaha tested a 23-foot Sportsman Open 232 with a single 300-hp F300 outboard. At 3,500 RPM the boat ran 27.2 mph while burning 8.3 GPH, or 3.28 MPG. At 5,800 RPM it ran 48.4 mph while burning 26.4 GPH, or 1.83 MPG.</p>
          <p>In that test, speed increased about 78%, while hourly fuel consumption increased about 218%. That is why wide-open-throttle fuel burn should not be used as a substitute for actual cruising fuel burn.</p>
          <p class="fpw-guide-source-note"><a href="https://yamahaoutboards.com/outboards/350-150-hp/v6-4-2l/f300-%284-2l%29/pb_spt_open-232_f300xsb2_6-29-2023_occ" target="_blank" rel="noopener noreferrer">Yamaha test data</a>. This is one manufacturer test example, not a prediction for other boats.</p>
        </aside>
      </section>

      <section class="fpw-guide-section" aria-labelledby="real-fuel-burn-examples-title">
        <h2 id="real-fuel-burn-examples-title">Real Boat Fuel-Burn Examples</h2>
        <p>These manufacturer performance tests show how fuel burn and fuel economy vary among specific boat and engine combinations at specific test RPM settings.</p>

        <div class="fpw-fuel-data-table-wrap">
          <table class="fpw-fuel-data-table">
            <caption class="fpw-visually-hidden">Manufacturer boat fuel-burn test examples</caption>
            <thead>
              <tr>
                <th scope="col">Boat / Engine</th>
                <th scope="col">Test RPM</th>
                <th scope="col">Speed</th>
                <th scope="col">Fuel Burn</th>
                <th scope="col">Fuel Economy</th>
                <th scope="col">Source</th>
              </tr>
            </thead>
            <tbody>
              <tr>
                <td data-label="Boat / Engine"><strong>G3 Boats 15 DLX / Yamaha F40</strong><small>40 hp single outboard</small></td>
                <td data-label="Test RPM">4,000 RPM</td>
                <td data-label="Speed">18.4 MPH</td>
                <td data-label="Fuel Burn">1.5 GPH</td>
                <td data-label="Fuel Economy">12.27 MPG</td>
                <td data-label="Source"><a href="https://yamahaoutboards.com/outboards/115-30-hp/40-30-hp/f40/pb_g3b_15dlx_f40la_2017-07-14_alm" target="_blank" rel="noopener noreferrer">Yamaha test data</a></td>
              </tr>
              <tr>
                <td data-label="Boat / Engine"><strong>Crestliner 1850 Fish Hawk / Mercury 150 Pro XS</strong><small>150 hp single outboard</small></td>
                <td data-label="Test RPM">3,000 RPM</td>
                <td data-label="Speed">21.3 MPH</td>
                <td data-label="Fuel Burn">3.6 GPH</td>
                <td data-label="Fuel Economy">6.0 MPG</td>
                <td data-label="Source"><a href="https://performancedata.mercurymarine.com/performance-test/141" target="_blank" rel="noopener noreferrer">Mercury test data</a></td>
              </tr>
              <tr>
                <td data-label="Boat / Engine"><strong>Sportsman Open 232 / Yamaha F300</strong><small>300 hp single outboard</small></td>
                <td data-label="Test RPM">3,500 RPM</td>
                <td data-label="Speed">27.2 MPH</td>
                <td data-label="Fuel Burn">8.3 GPH</td>
                <td data-label="Fuel Economy">3.28 MPG</td>
                <td data-label="Source"><a href="https://yamahaoutboards.com/outboards/350-150-hp/v6-4-2l/f300-%284-2l%29/pb_spt_open-232_f300xsb2_6-29-2023_occ" target="_blank" rel="noopener noreferrer">Yamaha test data</a></td>
              </tr>
              <tr>
                <td data-label="Boat / Engine"><strong>Sea Hunt Gamefish 30 CB / Twin Yamaha F350</strong><small>Twin 350 hp outboards</small></td>
                <td data-label="Test RPM">3,500 RPM</td>
                <td data-label="Speed">35.9 MPH</td>
                <td data-label="Fuel Burn">17.2 GPH total</td>
                <td data-label="Fuel Economy">2.09 MPG</td>
                <td data-label="Source"><a href="https://yamahaoutboards.com/outboards/350-150-hp/v6-4-3l/f350/pb_sht_gamefish-30-cb_tw_f350xsa2_5-30-2024_occ" target="_blank" rel="noopener noreferrer">Yamaha test data</a></td>
              </tr>
            </tbody>
          </table>
        </div>

        <div class="fpw-guide-note"><p><strong>These are examples, not lookup values for your boat.</strong> Manufacturer performance tests are conducted with specific hulls, loads, propellers and conditions. Your boat's actual fuel burn may be different.</p></div>
      </section>

      <section class="fpw-guide-section" aria-labelledby="gph-vs-mpg-title">
        <h2 id="gph-vs-mpg-title">GPH vs. MPG: What the Numbers Mean</h2>
        <div class="fpw-formula-grid">
          <article class="fpw-guide-card fpw-formula-card">
            <h3>GPH &mdash; Gallons Per Hour</h3>
            <p>GPH tells you how quickly the engines are consuming fuel. If your boat burns 8 GPH for three hours, the trip consumes about 24 gallons before reserve or other adjustments.</p>
            <code>Fuel Used = Running Hours &times; GPH</code>
          </article>
          <article class="fpw-guide-card fpw-formula-card">
            <h3>MPG &mdash; Miles Per Gallon</h3>
            <p>MPG measures how far the boat travels for each gallon burned. A higher GPH does not automatically mean worse fuel economy if the boat is also traveling substantially faster.</p>
            <code>MPG = Speed in MPH &divide; GPH</code>
          </article>
          <article class="fpw-guide-card fpw-formula-card">
            <h3>Nautical Miles Per Gallon</h3>
            <p>When working in knots and nautical miles, the same idea can be expressed as nautical miles per gallon.</p>
            <code>NM per Gallon = Speed in Knots &divide; GPH</code>
          </article>
        </div>
        <p class="fpw-guide-source-note">For trip planning, GPH tells you the burn rate while distance-per-gallon measurements help identify the more economical cruising point.</p>
      </section>

      <section class="fpw-guide-section" aria-labelledby="fuel-consumption-speed-title">
        <h2 id="fuel-consumption-speed-title">Why Boat Fuel Consumption Changes With Speed</h2>
        <p>Boat fuel consumption does not increase in a simple one-to-one relationship with speed. As speed and engine load change, the hull's resistance through the water, running attitude and propulsion efficiency also change.</p>
        <p>On a planing boat, efficiency can change significantly as the boat transitions onto plane and then continues toward higher RPM. More throttle normally increases gallons per hour, but the most useful efficiency measurement is how much distance the boat travels for each gallon consumed.</p>
        <p>This is why the lowest GPH is not automatically the best cruising speed. Idling may burn very little fuel per hour but cover very little distance. At the other extreme, high RPM can dramatically increase GPH without providing a proportional increase in speed.</p>
      </section>

      <section class="fpw-guide-section" aria-labelledby="find-actual-gph-title">
        <h2 id="find-actual-gph-title">How to Find Your Boat's Actual GPH</h2>
        <ol class="fpw-step-list">
          <li>
            <h3>Use onboard fuel-flow data</h3>
            <p>If your engine display, multifunction display or fuel-management system reports real-time GPH, use that data while operating at your normal cruising speed.</p>
            <p>Yamaha states that its engine-management systems can continuously calculate fuel consumption and display information that lets operators evaluate fuel economy while underway.</p>
          </li>
          <li>
            <h3>Find a manufacturer performance bulletin</h3>
            <p>Search for a performance test matching your boat model, engine, horsepower and engine count. These reports commonly show RPM, speed, GPH and MPG at multiple throttle settings.</p>
            <p><a href="https://yamahaoutboards.com/owner-center/performance-bulletins" target="_blank" rel="noopener noreferrer">Yamaha Performance Bulletins</a></p>
          </li>
          <li>
            <h3>Compare with your own operating history</h3>
            <p>Fuel added, engine hours and trip records can help establish a real-world baseline when the operating profile is reasonably consistent.</p>
            <p>One mixed-use tank does not automatically produce an accurate cruising GPH number.</p>
          </li>
          <li>
            <h3>Use a conservative estimate when necessary</h3>
            <p>If measured or manufacturer data is unavailable, use a conservative planning value and maintain additional reserve until you have enough real-world data to refine it.</p>
          </li>
        </ol>
        <div class="fpw-guide-note"><p>Once you know your expected cruise GPH, enter it in the FloatPlanWizard calculator above along with distance, speed and reserve assumptions.</p></div>
      </section>

      <section class="fpw-guide-section" aria-labelledby="fuel-consumption-factors-title">
        <h2 id="fuel-consumption-factors-title">What Affects Boat Fuel Consumption?</h2>
        <div class="fpw-factor-grid">
          <article class="fpw-guide-card fpw-factor-card">
            <h3>Boat &amp; Load</h3>
            <ul>
              <li>Passengers</li>
              <li>Gear</li>
              <li>Fuel and water carried</li>
              <li>Optional equipment</li>
              <li>Overall operating weight</li>
            </ul>
            <p>More weight generally requires more power to achieve and maintain a given operating condition.</p>
          </article>
          <article class="fpw-guide-card fpw-factor-card">
            <h3>Hull &amp; Running Surface</h3>
            <ul>
              <li>Hull design</li>
              <li>Bottom condition</li>
              <li>Fouling</li>
              <li>Bottom paint</li>
              <li>Added drag</li>
            </ul>
            <p>Hull condition and drag affect how much power is required to move the boat through the water.</p>
          </article>
          <article class="fpw-guide-card fpw-factor-card">
            <h3>Engine, Propeller &amp; Trim</h3>
            <ul>
              <li>Engine RPM and load</li>
              <li>Propeller selection and condition</li>
              <li>Engine trim</li>
              <li>Trim tabs where applicable</li>
              <li>Engine condition</li>
            </ul>
            <p>Propeller setup and trim affect the boat's running attitude and how efficiently engine power is converted into forward motion.</p>
          </article>
          <article class="fpw-guide-card fpw-factor-card">
            <h3>Conditions &amp; Route</h3>
            <ul>
              <li>Wind</li>
              <li>Current</li>
              <li>Waves and sea state</li>
              <li>No-wake operation and idling</li>
              <li>Route deviations</li>
              <li>Temperature and elevation where applicable</li>
            </ul>
            <p>The same boat can produce different fuel-burn results on different days or different sections of the same trip.</p>
          </article>
        </div>
        <p class="fpw-guide-source-note">Further context: <a href="https://yamahaoutboards.com/outboards/350-150-hp/in-line-4/f200-%28i4%29/pb_ver_vp22rct_f200xsa2_02-04-23_pnt" target="_blank" rel="noopener noreferrer">Yamaha performance data</a>, <a href="https://www.mercurymarine.com/us/en/lifestyle/dockline/improving-your-boats-fuel-efficiency" target="_blank" rel="noopener noreferrer">Mercury fuel-efficiency guidance</a>, and <a href="https://www.mercurymarine.com/us/en/lifestyle/dockline/how-to-trim-your-outboard-for-optimal-performance" target="_blank" rel="noopener noreferrer">Mercury trim guidance</a>.</p>
      </section>

      <section class="fpw-guide-section" aria-labelledby="efficient-cruising-speed-title">
        <h2 id="efficient-cruising-speed-title">Finding Your Most Efficient Cruising Speed</h2>
        <p>Your most economical cruising speed is the practical operating point where the boat covers the greatest useful distance for the fuel consumed. It is not necessarily the slowest speed, and it is rarely useful to assume one RPM or one percentage of wide-open throttle for every boat.</p>
        <p>The best way to find it is to compare speed and fuel-flow data across several normal operating RPM settings. When using statute miles, divide MPH by GPH to calculate MPG. When using knots, divide knots by GPH to estimate nautical miles per gallon.</p>
        <p>Manufacturer performance bulletins can provide a useful starting point, but real fuel-flow data from your own boat is better because it reflects your hull, load, propeller and operating conditions.</p>
        <div class="fpw-guide-callout"><p><strong>Don't optimize for GPH alone.</strong> Optimize for distance per gallon at a speed that makes sense for the trip.</p></div>
        <p class="fpw-guide-source-note"><a href="https://www.mercurymarine.com/us/en/lifestyle/dockline/how-to-find-the-ideal-cruising-speed-on-your-boat" target="_blank" rel="noopener noreferrer">Mercury cruising-speed guidance</a> and <a href="https://yamahaoutboards.com/blog/boating/take-command-of-fuel-efficiency" target="_blank" rel="noopener noreferrer">Yamaha fuel-management guidance</a>.</p>
      </section>

      <section class="fpw-guide-section" aria-labelledby="boat-fuel-planning-example-title">
        <h2 id="boat-fuel-planning-example-title">Boat Fuel Planning Example</h2>
        <h3>Example: 60-Nautical-Mile Round Trip</h3>
        <ul class="fpw-example-assumptions" aria-label="Worked example assumptions">
          <li>30 NM outbound</li>
          <li>30 NM return</li>
          <li>20-knot cruise</li>
          <li>8 GPH cruise fuel burn</li>
          <li>$4.50 per gallon</li>
        </ul>
        <div class="fpw-example-grid">
          <article class="fpw-example-leg fpw-example-math">
            <h3>Outbound</h3>
            <code>30 NM &divide; 20 kn = 1.5 hours</code>
            <code>1.5 hours &times; 8 GPH = 12 gallons</code>
          </article>
          <article class="fpw-example-leg fpw-example-math">
            <h3>Return</h3>
            <code>30 NM &divide; 20 kn = 1.5 hours</code>
            <code>1.5 hours &times; 8 GPH = 12 gallons</code>
          </article>
        </div>
        <div class="fpw-example-total fpw-example-math">
          <p><strong>Expected trip consumption</strong></p>
          <code>12 + 12 = 24 gallons</code>
          <p><strong>Estimated fuel cost</strong></p>
          <code>24 &times; $4.50 = $108</code>
        </div>
        <aside class="fpw-reserve-callout" aria-label="One-Third Rule example">
          <p>In this simplified example, applying the U.S. Coast Guard's One-Third Rule would allocate approximately 12 gallons outbound, 12 gallons for the return and another 12 gallons as reserve &mdash; 36 usable gallons at departure. Real trips may require more because outbound and return conditions are rarely identical.</p>
        </aside>
      </section>

      <section class="fpw-guide-section" aria-labelledby="fuel-reserve-title">
        <h2 id="fuel-reserve-title">How Much Fuel Reserve Should You Carry?</h2>
        <p>The U.S. Coast Guard's <em>A Boater's Guide to the Federal Requirements for Recreational Boats</em> recommends practicing the <strong>One-Third Rule</strong>:</p>
        <ul>
          <li>One-third of the fuel to go out</li>
          <li>One-third to get back</li>
          <li>One-third held in reserve</li>
        </ul>
        <p>Treat the rule as a conservative fuel-management practice, not as a guarantee that a particular trip is safe. Wind, current, sea state, detours, no-wake zones and unexpected delays can increase actual consumption.</p>
        <p class="fpw-guide-source-note">Use the <a href="#reservePct">Reserve Method control in the calculator above</a> to apply the One-Third Rule or a percentage-based planning margin. Review the official <a href="https://www.uscgboating.org/assets/1/AssetManager/Boaters-Guide-to-Federal-Requirements-for-Receational-Boats-20231108.pdf" target="_blank" rel="noopener noreferrer">U.S. Coast Guard boating guide</a> for the One-Third Rule.</p>
      </section>

      <section class="fpw-guide-section" aria-labelledby="boat-fuel-faq-title">
        <h2 id="boat-fuel-faq-title">Boat Fuel Calculator FAQ</h2>
        <div class="fpw-guide-faq">
          <cfloop array="#fpwFuelFaqItems#" index="fpwFuelFaqItem">
            <details>
              <summary><cfoutput>#encodeForHTML(fpwFuelFaqItem["question"])#</cfoutput></summary>
              <p><cfoutput>#encodeForHTML(fpwFuelFaqItem["answer"])#</cfoutput></p>
            </details>
          </cfloop>
        </div>
      </section>

      <aside class="fpw-fuel-safety-resources" aria-label="Related boating safety resources">
        <p><strong>Boating alone?</strong> Review the <a href="../solo-boating-safety-guide/">Solo Boating Safety Guide</a> before departure.</p>
        <p>Make sure your <a href="../shore-contact-overdue-boater/">shore contact knows what to do if you become overdue</a>.</p>
      </aside>

      <section class="fpw-guide-section fpw-guide-section--sources" aria-labelledby="fuel-sources-title">
        <h2 id="fuel-sources-title">Sources &amp; Further Reading</h2>
        <ul class="fpw-source-list">
          <li><a href="https://www.uscgboating.org/assets/1/AssetManager/Boaters-Guide-to-Federal-Requirements-for-Receational-Boats-20231108.pdf" target="_blank" rel="noopener noreferrer">U.S. Coast Guard &mdash; A Boater's Guide to the Federal Requirements for Recreational Boats</a></li>
          <li><a href="https://yamahaoutboards.com/owner-center/performance-bulletins" target="_blank" rel="noopener noreferrer">Yamaha Outboards &mdash; Performance Bulletins</a></li>
          <li><a href="https://yamahaoutboards.com/blog/boating/take-command-of-fuel-efficiency" target="_blank" rel="noopener noreferrer">Yamaha Outboards &mdash; Take Command of Fuel Efficiency</a></li>
          <li><a href="https://performancedata.mercurymarine.com/performance-test/141" target="_blank" rel="noopener noreferrer">Mercury Marine &mdash; Performance Data</a></li>
          <li><a href="https://www.mercurymarine.com/us/en/lifestyle/dockline/how-to-find-the-ideal-cruising-speed-on-your-boat" target="_blank" rel="noopener noreferrer">Mercury Marine &mdash; Finding Your Ideal Cruising Speed</a></li>
          <li><a href="https://www.mercurymarine.com/us/en/lifestyle/dockline/improving-your-boats-fuel-efficiency" target="_blank" rel="noopener noreferrer">Mercury Marine &mdash; Improving Your Boat's Fuel Efficiency</a></li>
          <li><a href="https://www.mercurymarine.com/us/en/lifestyle/dockline/how-to-trim-your-outboard-for-optimal-performance" target="_blank" rel="noopener noreferrer">Mercury Marine &mdash; Outboard Trim Guidance</a></li>
        </ul>
      </section>
    </div>

  </main>

  <cfinclude template="../includes/footer.cfm">
  <script src="../assets/js/fpw-action-cta.js?v=20260804-pilot"></script>

  <script>
    (function () {
      var helpButtons = document.querySelectorAll(".fpw-help");
      if (!helpButtons.length) return;

      function getTooltip(button) {
        var id = button.getAttribute("data-tooltip-target");
        return id ? document.getElementById(id) : null;
      }

      function hideTooltip(button) {
        var tooltip = getTooltip(button);
        if (!tooltip) return;

        tooltip.classList.remove("is-visible");
        button.setAttribute("aria-expanded", "false");
        delete button.dataset.clickedOpen;
      }

      function hideAllTooltips(exceptButton) {
        helpButtons.forEach(function (button) {
          if (button !== exceptButton) {
            hideTooltip(button);
          }
        });
      }

      function showTooltip(button) {
        var tooltip = getTooltip(button);
        if (!tooltip) return;

        hideAllTooltips(button);
        tooltip.classList.add("is-visible");
        button.setAttribute("aria-expanded", "true");
      }

      helpButtons.forEach(function (button) {
        button.addEventListener("pointerdown", function () {
          button.dataset.pointerIntent = "true";
          window.setTimeout(function () {
            delete button.dataset.pointerIntent;
          }, 350);
        });

        button.addEventListener("mouseleave", function () {
          hideTooltip(button);
        });

        button.addEventListener("blur", function () {
          hideTooltip(button);
        });

        button.addEventListener("click", function (event) {
          event.preventDefault();
          event.stopPropagation();

          var tooltip = getTooltip(button);
          var isOpen = tooltip && tooltip.classList.contains("is-visible");
          var wasClickOpen = button.dataset.clickedOpen === "true";

          if (isOpen && wasClickOpen) {
            hideTooltip(button);
            return;
          }

          hideAllTooltips(button);
          showTooltip(button);
          button.dataset.clickedOpen = "true";
        });
      });

      document.addEventListener("click", function (event) {
        var target = event.target;
        if (!target || typeof target.closest !== "function") return;

        if (!target.closest(".fpw-help") && !target.closest(".fpw-tooltip")) {
          hideAllTooltips();
        }
      });

      document.addEventListener("keydown", function (event) {
        if (event.key === "Escape") {
          hideAllTooltips();
        }
      });
    })();
  </script>

  <script>
    (function () {
      var DEFAULT_MAX_SPEED_KN = 20;
      var DEFAULT_UNDERWAY_HOURS_PER_DAY = 6.5;
      var DEFAULT_RESERVE_PCT = 33;
      var RESERVE_MODE_THIRDS = "thirds";
      var RESERVE_MODE_PERCENTAGE = "percentage";
      var LOW_SPEED_ANCHOR_KN = 3.5;
      var PACE_PRESETS = {
        RELAXED: { key: "RELAXED", label: "Relaxed", factor: 0.25 },
        BALANCED: { key: "BALANCED", label: "Efficient Speed", factor: 0.50 },
        AGGRESSIVE: { key: "AGGRESSIVE", label: "Max Speed", factor: 1.00 }
      };
      var hasValidFuelJson = false;

      function q(id) {
        return document.getElementById(id);
      }

      function safeNum(value) {
        var n = parseFloat(value);
        return Number.isFinite(n) ? n : null;
      }

      function roundTo2(value) {
        var n = parseFloat(value);
        if (!Number.isFinite(n)) return 0;
        return Math.round(n * 100) / 100;
      }

      function roundTo1(value) {
        var n = parseFloat(value);
        if (!Number.isFinite(n)) return 0;
        return Math.round(n * 10) / 10;
      }

      function formatNum(value, decimals, fallbackText) {
        var n = safeNum(value);
        var places = (typeof decimals === "number") ? decimals : 2;
        if (n === null) return (fallbackText !== undefined ? String(fallbackText) : "--");
        return n.toLocaleString(undefined, {
          minimumFractionDigits: places,
          maximumFractionDigits: places
        });
      }

      function formatCurrency(value, fallbackText) {
        var n = safeNum(value);
        if (n === null) return (fallbackText !== undefined ? String(fallbackText) : "--");
        return "$" + n.toLocaleString(undefined, {
          minimumFractionDigits: 2,
          maximumFractionDigits: 2
        });
      }

      function formatEstimatedRangeNm(value, fallbackText) {
        var n = safeNum(value);
        if (n === null || n <= 0) return (fallbackText !== undefined ? String(fallbackText) : "--");
        return formatNum(n, n < 100 ? 1 : 0, fallbackText);
      }

      function normalizePaceKey(value) {
        var key = String(value || "").trim().toUpperCase();
        if (key === "BALANCED") return "BALANCED";
        if (key === "AGGRESSIVE") return "AGGRESSIVE";
        return "RELAXED";
      }

      function getPacePreset(value) {
        var key = normalizePaceKey(value);
        return PACE_PRESETS[key] || PACE_PRESETS.RELAXED;
      }

      function normalizeCruisingSpeed(value, defaultSpeedKn) {
        var speedVal = safeNum(value);
        var fallbackVal = safeNum(defaultSpeedKn);
        if (fallbackVal === null || fallbackVal <= 0) fallbackVal = DEFAULT_MAX_SPEED_KN;
        if (speedVal === null || speedVal <= 0) speedVal = fallbackVal;
        if (speedVal < 1) speedVal = 1;
        if (speedVal > 60) speedVal = 60;
        return roundTo2(speedVal);
      }

      function normalizePositiveSpeed(value) {
        var speedVal = safeNum(value);
        if (speedVal === null || speedVal <= 0) return 0;
        if (speedVal > 60) speedVal = 60;
        return roundTo2(speedVal);
      }

      function normalizeUnderwayHours(value) {
        var hoursVal = safeNum(value);
        if (hoursVal === null || hoursVal <= 0) hoursVal = DEFAULT_UNDERWAY_HOURS_PER_DAY;
        if (hoursVal < 1) hoursVal = 1;
        if (hoursVal > 24) hoursVal = 24;
        return roundTo2(hoursVal);
      }

      function normalizeFuelBurnGph(value) {
        var burnVal = safeNum(value);
        if (burnVal === null || burnVal <= 0) return 0;
        if (burnVal > 1000) burnVal = 1000;
        return roundTo2(burnVal);
      }

      function normalizeIdleHoursTotal(value) {
        var hoursVal = safeNum(value);
        if (hoursVal === null || hoursVal <= 0) return 0;
        if (hoursVal > 10000) hoursVal = 10000;
        return roundTo2(hoursVal);
      }

      function normalizeWeatherFactorPct(value) {
        var pctVal = safeNum(value);
        if (pctVal === null) return 0;
        if (pctVal < 0) pctVal = 0;
        if (pctVal > 60) pctVal = 60;
        return roundTo2(pctVal);
      }

      function normalizeReservePct(value, defaultPct) {
        var pctVal = safeNum(value);
        if (pctVal === null) pctVal = safeNum(defaultPct);
        if (pctVal === null) pctVal = DEFAULT_RESERVE_PCT;
        if (pctVal < 0) pctVal = 0;
        if (pctVal > 100) pctVal = 100;
        return roundTo2(pctVal);
      }

      function normalizeReserveMode(value) {
        return String(value || "").trim().toLowerCase() === RESERVE_MODE_THIRDS
          ? RESERVE_MODE_THIRDS
          : RESERVE_MODE_PERCENTAGE;
      }

      function normalizeFuelPricePerGal(value) {
        var priceVal = safeNum(value);
        if (priceVal === null || priceVal <= 0) return 0;
        if (priceVal > 1000) priceVal = 1000;
        return roundTo2(priceVal);
      }

      function paceAdjustedBurnGph(maxBurnGph, paceRatio, burnExponent) {
        var maxBurnVal = normalizeFuelBurnGph(maxBurnGph);
        var ratioVal = safeNum(paceRatio);
        var expVal = safeNum(burnExponent);
        if (maxBurnVal <= 0) return 0;
        if (expVal === null || expVal < 1) expVal = 1;
        if (expVal > 6) expVal = 6;
        if (ratioVal === null || ratioVal <= 0) ratioVal = 1;
        if (ratioVal < 0.05) ratioVal = 0.05;
        if (ratioVal > 1) ratioVal = 1;
        return roundTo2(maxBurnVal * Math.pow(ratioVal, expVal));
      }

      function anchoredBurnInputsValid(maxSpeedKn, maxBurnGph, efficientSpeedKn, efficientBurnGph) {
        var maxSpeedVal = normalizeCruisingSpeed(maxSpeedKn, DEFAULT_MAX_SPEED_KN);
        var maxBurnVal = normalizeFuelBurnGph(maxBurnGph);
        var efficientSpeedVal = normalizePositiveSpeed(efficientSpeedKn);
        var efficientBurnVal = normalizeFuelBurnGph(efficientBurnGph);
        if (maxSpeedVal <= 0) return false;
        if (maxBurnVal <= 0) return false;
        if (efficientSpeedVal <= LOW_SPEED_ANCHOR_KN) return false;
        if (efficientBurnVal <= 0) return false;
        if (maxSpeedVal < efficientSpeedVal) return false;
        return true;
      }

      function anchoredBurnAtSpeedGph(effectiveSpeedKn, maxSpeedKn, maxBurnGph, efficientSpeedKn, efficientBurnGph) {
        var speedVal = safeNum(effectiveSpeedKn);
        var maxSpeedVal = normalizeCruisingSpeed(maxSpeedKn, DEFAULT_MAX_SPEED_KN);
        var maxBurnVal = normalizeFuelBurnGph(maxBurnGph);
        var efficientSpeedVal = normalizePositiveSpeed(efficientSpeedKn);
        var efficientBurnVal = normalizeFuelBurnGph(efficientBurnGph);
        var lowBurnVal = efficientBurnVal * 0.25;
        var factorVal = 0;

        if (!anchoredBurnInputsValid(maxSpeedVal, maxBurnVal, efficientSpeedVal, efficientBurnVal)) {
          return 0;
        }

        if (speedVal === null || speedVal <= LOW_SPEED_ANCHOR_KN) {
          return roundTo2(lowBurnVal);
        }
        if (speedVal < efficientSpeedVal) {
          factorVal = (speedVal - LOW_SPEED_ANCHOR_KN) / (efficientSpeedVal - LOW_SPEED_ANCHOR_KN);
          return roundTo2(lowBurnVal + ((efficientBurnVal - lowBurnVal) * factorVal));
        }
        if (speedVal <= efficientSpeedVal) {
          return roundTo2(efficientBurnVal);
        }
        if (speedVal < maxSpeedVal) {
          factorVal = (speedVal - efficientSpeedVal) / (maxSpeedVal - efficientSpeedVal);
          return roundTo2(efficientBurnVal + ((maxBurnVal - efficientBurnVal) * factorVal));
        }
        return roundTo2(maxBurnVal);
      }

      function computeEffectiveCruisingSpeed(maxSpeedKn, pace, mostEfficientSpeedKn) {
        var pacePreset = getPacePreset(pace);
        var maxSpeedVal = normalizeCruisingSpeed(maxSpeedKn, DEFAULT_MAX_SPEED_KN);
        var mostEffVal = normalizePositiveSpeed(mostEfficientSpeedKn);
        var factorVal = safeNum(pacePreset.factor);
        var effectiveSpeed = 0;

        if (pacePreset.key === "BALANCED" && mostEffVal >= 1) {
          return roundTo2(mostEffVal);
        }
        if (factorVal === null || factorVal <= 0) factorVal = 0.25;
        effectiveSpeed = maxSpeedVal * factorVal;
        if (effectiveSpeed < 1) effectiveSpeed = 1;
        return roundTo2(effectiveSpeed);
      }

      function readInputNumber(id) {
        var el = q(id);
        if (!el) return null;
        var raw = String(el.value || "").trim();
        if (!raw.length) return null;
        return safeNum(raw);
      }

      function readUsableFuelCapacityInput() {
        var el = q("usableFuelCapacityGallons");
        var raw = el ? String(el.value || "").trim() : "";
        var value = null;

        if (!raw.length) {
          return {
            value: null,
            status: (el && el.validity && el.validity.badInput) ? "invalid" : "empty"
          };
        }

        value = Number(raw);
        if (!Number.isFinite(value) || value < 0.01) {
          return { value: null, status: "invalid" };
        }

        return { value: value, status: "valid" };
      }

      function readReserveMode() {
        var selectEl = q("reservePct");
        var selectedOption = selectEl && selectEl.options
          ? selectEl.options[selectEl.selectedIndex]
          : null;
        return normalizeReserveMode(selectedOption ? selectedOption.getAttribute("data-reserve-mode") : "");
      }

      function getInputs() {
        var usableFuelCapacityInput = readUsableFuelCapacityInput();
        return {
          distanceNm: readInputNumber("totalNm"),
          pace: normalizePaceKey(q("pace") ? q("pace").value : "RELAXED"),
          mostEfficientSpeedKn: readInputNumber("mostEfficientSpeedKn"),
          fuelBurnEfficientGph: readInputNumber("fuelBurnEfficientGph"),
          maxSpeedKn: readInputNumber("maxSpeedKn"),
          fuelBurnGph: readInputNumber("fuelBurnGph"),
          idleBurnGph: readInputNumber("idleBurnGph"),
          idleHoursTotal: readInputNumber("idleHoursTotal"),
          weatherPct: readInputNumber("weatherPct"),
          reservePct: readInputNumber("reservePct"),
          reserveMode: readReserveMode(),
          usableFuelCapacityGallons: usableFuelCapacityInput.value,
          usableFuelCapacityStatus: usableFuelCapacityInput.status,
          underwayHoursPerDay: readInputNumber("underwayHoursPerDay"),
          fuelPricePerGal: readInputNumber("fuelPricePerGal")
        };
      }

      function buildModel(inputs) {
        var pacePreset = getPacePreset(inputs.pace);
        var distanceNm = safeNum(inputs.distanceNm);
        var maxSpeedKn = (safeNum(inputs.maxSpeedKn) !== null && safeNum(inputs.maxSpeedKn) > 0)
          ? normalizeCruisingSpeed(inputs.maxSpeedKn, DEFAULT_MAX_SPEED_KN)
          : null;
        var mostEfficientSpeedKn = normalizePositiveSpeed(inputs.mostEfficientSpeedKn);
        var efficientBurnGph = normalizeFuelBurnGph(inputs.fuelBurnEfficientGph);
        var maxBurnGph = normalizeFuelBurnGph(inputs.fuelBurnGph);
        var idleBurnGph = normalizeFuelBurnGph(inputs.idleBurnGph);
        var idleHoursTotal = normalizeIdleHoursTotal(inputs.idleHoursTotal);
        var weatherPct = normalizeWeatherFactorPct(inputs.weatherPct);
        var reservePct = normalizeReservePct(inputs.reservePct, DEFAULT_RESERVE_PCT);
        var reserveMode = normalizeReserveMode(inputs.reserveMode);
        var usableFuelCapacityStatus = String(inputs.usableFuelCapacityStatus || "");
        var usableFuelCapacityGallons = safeNum(inputs.usableFuelCapacityGallons);
        var fuelPricePerGal = normalizeFuelPricePerGal(inputs.fuelPricePerGal);
        var underwayHoursPerDay = normalizeUnderwayHours(inputs.underwayHoursPerDay);
        var missingRequiredInputs = [];
        var effectiveSpeedKn = null;
        var paceRatio = null;
        var paceAdjustedBurn = null;
        var weatherAdjustedBurn = null;
        var weatherAdjustedSpeedKn = null;
        var cruiseHours = null;
        var cruiseFuelGallons = null;
        var idleFuelGallons = null;
        var baseFuelGallons = null;
        var reserveGallons = null;
        var requiredFuelGallons = null;
        var totalFuelCost = null;
        var totalTravelHours = null;
        var estimatedDays = null;
        var fuelAvailableAfterReserveGallons = null;
        var estimatedEnduranceHours = null;
        var estimatedRangeNauticalMiles = null;
        var usableCapacityMeetsRequirement = null;
        var capacityShortfallGallons = null;
        var capacityMarginGallons = null;
        var weatherAdj = weatherPct / 100;
        var hasRequiredInputs = false;
        var usesAnchoredBurn = false;
        var canEstimateFuel = false;
        var canEstimateRange = false;
        var fuelMode = "required inputs missing";

        if (!usableFuelCapacityStatus) {
          usableFuelCapacityStatus = (usableFuelCapacityGallons === null)
            ? "empty"
            : (usableFuelCapacityGallons >= 0.01 ? "valid" : "invalid");
        }
        if (usableFuelCapacityStatus !== "valid") {
          usableFuelCapacityGallons = null;
        }

        if (mostEfficientSpeedKn <= 0) missingRequiredInputs.push("Most Efficient Speed (kn)");
        if (efficientBurnGph <= 0) missingRequiredInputs.push("GPH @ Efficient");
        if (pacePreset.key !== "BALANCED" && (maxSpeedKn === null || maxSpeedKn <= 0)) {
          missingRequiredInputs.push("Max Speed (kn)");
        }
        if (pacePreset.key !== "BALANCED" && maxBurnGph <= 0) {
          missingRequiredInputs.push("Fuel Burn @ Max (GPH)");
        }
        hasRequiredInputs = (missingRequiredInputs.length === 0);

        if (hasRequiredInputs) {
          effectiveSpeedKn = computeEffectiveCruisingSpeed(maxSpeedKn, pacePreset.key, mostEfficientSpeedKn);
          usesAnchoredBurn = anchoredBurnInputsValid(maxSpeedKn, maxBurnGph, mostEfficientSpeedKn, efficientBurnGph);
          fuelMode = "unavailable";
        }

        if (hasRequiredInputs) {
          if (pacePreset.key === "BALANCED") {
            if (maxSpeedKn !== null && maxSpeedKn > 0 && effectiveSpeedKn > 0) {
              paceRatio = roundTo2(effectiveSpeedKn / maxSpeedKn);
            }
            if (efficientBurnGph > 0) {
              paceAdjustedBurn = roundTo2(efficientBurnGph);
              weatherAdjustedBurn = roundTo2(paceAdjustedBurn * (1 + weatherAdj));
              canEstimateFuel = true;
              fuelMode = "efficient";
            }
          } else {
            paceRatio = roundTo2(pacePreset.factor);
            if (usesAnchoredBurn) {
              paceAdjustedBurn = anchoredBurnAtSpeedGph(
                effectiveSpeedKn,
                maxSpeedKn,
                maxBurnGph,
                mostEfficientSpeedKn,
                efficientBurnGph
              );
              fuelMode = "anchored";
            } else {
              paceAdjustedBurn = paceAdjustedBurnGph(maxBurnGph, pacePreset.factor, 3.0);
              fuelMode = "pace_adjusted";
            }
            weatherAdjustedBurn = roundTo2(paceAdjustedBurn * (1 + weatherAdj));
            canEstimateFuel = true;
          }

          weatherAdjustedSpeedKn = roundTo2(effectiveSpeedKn * (1 - weatherAdj));
          if (weatherAdjustedSpeedKn < 0.5) weatherAdjustedSpeedKn = 0.5;

          if (
            usableFuelCapacityStatus === "valid" &&
            usableFuelCapacityGallons >= 0.01 &&
            weatherAdjustedBurn > 0 &&
            weatherAdjustedSpeedKn > 0
          ) {
            fuelAvailableAfterReserveGallons = reserveMode === RESERVE_MODE_THIRDS
              ? usableFuelCapacityGallons * (2 / 3)
              : usableFuelCapacityGallons * (1 - (reservePct / 100));
            if (fuelAvailableAfterReserveGallons > 0) {
              estimatedEnduranceHours = fuelAvailableAfterReserveGallons / weatherAdjustedBurn;
              estimatedRangeNauticalMiles = estimatedEnduranceHours * weatherAdjustedSpeedKn;
              canEstimateRange = Number.isFinite(estimatedEnduranceHours)
                && Number.isFinite(estimatedRangeNauticalMiles)
                && estimatedEnduranceHours > 0
                && estimatedRangeNauticalMiles > 0;
            }
          }

          if (distanceNm !== null && distanceNm > 0 && canEstimateFuel) {
            cruiseHours = roundTo2(distanceNm / weatherAdjustedSpeedKn);
            cruiseFuelGallons = roundTo2(cruiseHours * weatherAdjustedBurn);
          } else {
            cruiseHours = 0;
            cruiseFuelGallons = 0;
          }

          idleFuelGallons = (idleBurnGph > 0 && idleHoursTotal > 0)
            ? roundTo1(idleBurnGph * idleHoursTotal)
            : 0;

          baseFuelGallons = roundTo2(cruiseFuelGallons + idleFuelGallons);
          if (reserveMode === RESERVE_MODE_THIRDS) {
            reserveGallons = roundTo2(baseFuelGallons * 0.5);
            requiredFuelGallons = roundTo2(baseFuelGallons * 1.5);
          } else {
            reserveGallons = roundTo2(baseFuelGallons * (reservePct / 100));
            requiredFuelGallons = roundTo2(baseFuelGallons + reserveGallons);
          }

          if (
            usableFuelCapacityStatus === "valid" &&
            usableFuelCapacityGallons !== null &&
            distanceNm !== null &&
            distanceNm > 0
          ) {
            usableCapacityMeetsRequirement = usableFuelCapacityGallons >= requiredFuelGallons;
            capacityShortfallGallons = usableCapacityMeetsRequirement
              ? 0
              : roundTo2(requiredFuelGallons - usableFuelCapacityGallons);
            capacityMarginGallons = usableCapacityMeetsRequirement
              ? roundTo2(usableFuelCapacityGallons - requiredFuelGallons)
              : 0;
          }
          totalFuelCost = (fuelPricePerGal > 0)
            ? Math.round((requiredFuelGallons * fuelPricePerGal) * 100) / 100
            : 0;
          totalTravelHours = roundTo2(cruiseHours + idleHoursTotal);

          if (totalTravelHours > 0) {
            estimatedDays = Math.ceil(totalTravelHours / underwayHoursPerDay);
            if (estimatedDays < 1) estimatedDays = 1;
          } else {
            estimatedDays = 0;
          }
        }

        return {
          inputs: {
            distanceNm: distanceNm,
            pace: pacePreset.key,
            maxSpeedKn: maxSpeedKn,
            mostEfficientSpeedKn: mostEfficientSpeedKn,
            fuelBurnEfficientGph: efficientBurnGph,
            fuelBurnGph: maxBurnGph,
            idleBurnGph: idleBurnGph,
            idleHoursTotal: idleHoursTotal,
            weatherPct: weatherPct,
            reservePct: reservePct,
            reserveMode: reserveMode,
            usableFuelCapacityGallons: usableFuelCapacityGallons,
            usableFuelCapacityStatus: usableFuelCapacityStatus,
            underwayHoursPerDay: underwayHoursPerDay,
            fuelPricePerGal: fuelPricePerGal
          },
          derived: {
            paceLabel: pacePreset.label,
            paceRatio: paceRatio,
            effectiveSpeedKn: effectiveSpeedKn,
            weatherAdjustedSpeedKn: weatherAdjustedSpeedKn,
            paceAdjustedBurnGph: (paceAdjustedBurn === null ? null : roundTo2(paceAdjustedBurn)),
            weatherAdjustedBurnGph: (weatherAdjustedBurn === null ? null : roundTo2(weatherAdjustedBurn)),
            cruiseHours: cruiseHours,
            cruiseFuelGallons: cruiseFuelGallons,
            idleFuelGallons: (idleFuelGallons === null ? null : roundTo2(idleFuelGallons)),
            baseFuelGallons: baseFuelGallons,
            reserveGallons: reserveGallons,
            requiredFuelGallons: requiredFuelGallons,
            totalFuelCost: (totalFuelCost === null ? null : roundTo2(totalFuelCost)),
            totalTravelHours: totalTravelHours,
            estimatedDays: estimatedDays,
            fuelAvailableAfterReserveGallons: fuelAvailableAfterReserveGallons,
            tripUsableCapacityGallons: fuelAvailableAfterReserveGallons,
            estimatedEnduranceHours: estimatedEnduranceHours,
            estimatedRangeNauticalMiles: estimatedRangeNauticalMiles,
            usableCapacityMeetsRequirement: usableCapacityMeetsRequirement,
            capacityShortfallGallons: capacityShortfallGallons,
            capacityMarginGallons: capacityMarginGallons,
            usesAnchoredBurn: usesAnchoredBurn,
            fuelMode: fuelMode,
            canEstimateFuel: canEstimateFuel,
            canEstimateRange: canEstimateRange,
            missingRequiredInputs: missingRequiredInputs
          }
        };
      }

      function renderRequiredEfficientInputsMessage(model) {
        var derived = model.derived || {};
        var msgEl = q("requiredEfficientInputsMsg");
        var missingRequiredInputs = derived.missingRequiredInputs || [];
        if (!msgEl) return;
        if (!missingRequiredInputs.length) {
          msgEl.hidden = true;
          msgEl.innerHTML = "";
          return;
        }
        msgEl.hidden = false;
        msgEl.innerHTML = "<strong>Required Inputs</strong>"
          + "<ul>"
          + missingRequiredInputs.map(function (label) {
            return "<li>" + label + "</li>";
          }).join("")
          + "</ul>"
          + "<div class=\"msg-detail\">This standalone calculator will not estimate fuel until all required inputs for the selected pace are entered.</div>";
      }

      function renderRequiredEfficientInputState(model) {
        var derived = model.derived || {};
        var missingRequiredInputs = derived.missingRequiredInputs || [];
        var mostEfficientMissing = missingRequiredInputs.indexOf("Most Efficient Speed (kn)") !== -1;
        var efficientBurnMissing = missingRequiredInputs.indexOf("GPH @ Efficient") !== -1;
        var maxSpeedMissing = missingRequiredInputs.indexOf("Max Speed (kn)") !== -1;
        var maxBurnMissing = missingRequiredInputs.indexOf("Fuel Burn @ Max (GPH)") !== -1;
        q("mostEfficientSpeedKn").setAttribute("aria-invalid", mostEfficientMissing ? "true" : "false");
        q("fuelBurnEfficientGph").setAttribute("aria-invalid", efficientBurnMissing ? "true" : "false");
        q("maxSpeedKn").setAttribute("aria-invalid", maxSpeedMissing ? "true" : "false");
        q("fuelBurnGph").setAttribute("aria-invalid", maxBurnMissing ? "true" : "false");
      }

      function renderUsableFuelCapacityInputState(model) {
        var inputs = model.inputs || {};
        var inputEl = q("usableFuelCapacityGallons");
        var errorEl = q("usableFuelCapacityError");
        var isInvalid = inputs.usableFuelCapacityStatus === "invalid";
        if (inputEl) inputEl.setAttribute("aria-invalid", isInvalid ? "true" : "false");
        if (errorEl) errorEl.hidden = !isInvalid;
      }

      function renderUsableFuelCapacityStatus(model) {
        var inputs = model.inputs || {};
        var derived = model.derived || {};
        var statusEl = q("usableFuelCapacityStatus");
        var capacity = safeNum(inputs.usableFuelCapacityGallons);
        var required = safeNum(derived.requiredFuelGallons);
        var statusText = "";
        var statusState = "";

        if (!statusEl) return;
        if (
          inputs.usableFuelCapacityStatus !== "valid" ||
          capacity === null ||
          required === null ||
          safeNum(inputs.distanceNm) === null ||
          inputs.distanceNm <= 0 ||
          derived.usableCapacityMeetsRequirement === null
        ) {
          statusEl.hidden = true;
          statusEl.textContent = "";
          statusEl.removeAttribute("data-capacity-state");
          return;
        }

        if (!derived.usableCapacityMeetsRequirement) {
          statusState = "shortfall";
          statusText = "Capacity shortfall: " + formatNum(derived.capacityShortfallGallons, 1, "0.0")
            + " gal. The " + formatNum(capacity, 1, "0.0")
            + " gal usable capacity is below the " + formatNum(required, 1, "0.0")
            + " gal departure requirement for these planning assumptions.";
        } else if (derived.capacityMarginGallons === 0) {
          statusState = "boundary";
          statusText = "Capacity boundary: The " + formatNum(capacity, 1, "0.0")
            + " gal usable capacity exactly matches the " + formatNum(required, 1, "0.0")
            + " gal departure requirement for these planning assumptions.";
        } else {
          statusState = "margin";
          statusText = "Capacity margin: " + formatNum(derived.capacityMarginGallons, 1, "0.0")
            + " gal. The " + formatNum(capacity, 1, "0.0")
            + " gal usable capacity is above the " + formatNum(required, 1, "0.0")
            + " gal departure requirement for these planning assumptions.";
        }

        statusEl.hidden = false;
        statusEl.setAttribute("data-capacity-state", statusState);
        statusEl.textContent = statusText;
      }

      function renderCards(model) {
        var inputs = model.inputs || {};
        var derived = model.derived || {};
        var hasFuelEstimate = !!derived.canEstimateFuel;
        var hasDistance = safeNum(inputs.distanceNm) !== null && inputs.distanceNm > 0;
        var missingRequiredInputs = derived.missingRequiredInputs || [];

        q("cardTotalDistance").textContent = formatNum(inputs.distanceNm, 1, "0.0") + " NM";
        q("cardTotalDistanceSub").textContent = "Manual distance input";

        if (hasDistance && hasFuelEstimate && derived.totalTravelHours > 0) {
          q("cardTotalHours").textContent = formatNum(derived.totalTravelHours, 1, "--") + " h";
          q("cardTotalHoursSub").textContent = "Cruise " + formatNum(derived.cruiseHours, 1, "0.0")
            + "h + Idle " + formatNum(inputs.idleHoursTotal, 1, "0.0")
            + "h | " + String(derived.estimatedDays) + " day(s) @ "
            + formatNum(inputs.underwayHoursPerDay, 1, "6.5") + "h/day";
        } else {
          q("cardTotalHours").textContent = "-- h";
          q("cardTotalHoursSub").textContent = "Enter distance and fuel inputs.";
        }

        if (hasDistance && hasFuelEstimate) {
          q("cardEstimatedFuel").textContent = formatNum(derived.requiredFuelGallons, 1, "--") + " gal";
          q("cardEstimatedFuelSub").textContent = inputs.reserveMode === RESERVE_MODE_THIRDS
            ? "Base " + formatNum(derived.baseFuelGallons, 1, "0.0")
              + " + One-Third Rule Reserve " + formatNum(derived.reserveGallons, 1, "0.0")
            : "Base " + formatNum(derived.baseFuelGallons, 1, "0.0")
              + " + Reserve (" + formatNum(inputs.reservePct, 0, "0") + "%) "
              + formatNum(derived.reserveGallons, 1, "0.0");
        } else {
          q("cardEstimatedFuel").textContent = "-- gal";
          q("cardEstimatedFuelSub").textContent = "Required + reserve";
        }

        if (hasFuelEstimate) {
          q("cardAdjustedSpeed").textContent = formatNum(derived.weatherAdjustedSpeedKn, 2, "--") + " kn";
          q("cardAdjustedSpeedSub").textContent = "Pace + weather adjusted";
          q("cardExpectedAvgGph").textContent = formatNum(derived.weatherAdjustedBurnGph, 2, "--") + " GPH";
          q("cardExpectedAvgGphSub").textContent = "Current pace + weather burn";
        } else {
          q("cardAdjustedSpeed").textContent = "-- kn";
          q("cardAdjustedSpeedSub").textContent = missingRequiredInputs.length
            ? "Waiting for the required inputs for this pace"
            : "Adjusted speed unavailable";
          q("cardExpectedAvgGph").textContent = "-- GPH";
          q("cardExpectedAvgGphSub").textContent = missingRequiredInputs.length
            ? "Complete the required inputs for this pace"
            : "Provide the burn inputs for this pace";
        }

        if (inputs.usableFuelCapacityStatus === "invalid") {
          q("cardEstimatedRange").textContent = "Range unavailable";
          q("cardEstimatedRange").setAttribute("aria-label", "Estimated range unavailable because usable fuel capacity is invalid");
          q("cardEstimatedRangeSub").textContent = "Enter a usable fuel capacity of at least 0.01 gallon";
        } else if (inputs.usableFuelCapacityStatus === "empty") {
          q("cardEstimatedRange").textContent = "Enter fuel capacity";
          q("cardEstimatedRange").setAttribute("aria-label", "Enter usable fuel capacity to estimate range");
          q("cardEstimatedRangeSub").textContent = "Optional usable-fuel estimate";
        } else if (derived.canEstimateRange) {
          var displayedRange = formatEstimatedRangeNm(derived.estimatedRangeNauticalMiles, "--");
          q("cardEstimatedRange").textContent = displayedRange + " NM";
          q("cardEstimatedRange").setAttribute("aria-label", displayedRange + " nautical miles");
          q("cardEstimatedRangeSub").textContent = "Endurance with reserve: "
            + formatNum(derived.estimatedEnduranceHours, 1, "--") + " h";
        } else {
          q("cardEstimatedRange").textContent = "Range unavailable";
          q("cardEstimatedRange").setAttribute("aria-label", "Estimated range unavailable");
          q("cardEstimatedRangeSub").textContent = hasFuelEstimate
            ? "Reserve leaves no fuel available"
            : "Complete the speed and fuel-burn inputs";
        }

        if (hasDistance && hasFuelEstimate && inputs.fuelPricePerGal > 0) {
          q("cardFuelCost").textContent = formatCurrency(derived.totalFuelCost, "--");
          q("cardFuelCostSub").textContent = "Required fuel x $" + formatNum(inputs.fuelPricePerGal, 2, "0.00") + "/gal";
        } else {
          q("cardFuelCost").textContent = "--";
          q("cardFuelCostSub").textContent = "Enter fuel price to estimate";
        }
      }

      function renderBreakdown(model) {
        var inputs = model.inputs || {};
        var derived = model.derived || {};
        var isThirds = inputs.reserveMode === RESERVE_MODE_THIRDS;
        var reserveLabel = isThirds
          ? "One-Third Rule"
          : formatNum(inputs.reservePct, 0, "0") + "% reserve";
        var capacityStatus = "--";
        if (derived.usableCapacityMeetsRequirement === false) {
          capacityStatus = "Below departure requirement";
        } else if (derived.usableCapacityMeetsRequirement === true && derived.capacityMarginGallons === 0) {
          capacityStatus = "Exactly matches departure requirement";
        } else if (derived.usableCapacityMeetsRequirement === true) {
          capacityStatus = "Above departure requirement";
        }
        var rows = [
          ["Pace", String(derived.paceLabel || "--"), "Route Generator pace preset"],
          ["Pace ratio", formatNum(derived.paceRatio, 2, "--"), "Relaxed=0.25, Balanced=efficient speed / max speed, Max Speed=1.00"],
          ["Max speed (kn)", formatNum(inputs.maxSpeedKn, 2, "--"), "Normalized to the Route Generator 1-60 kn range"],
          ["Most efficient speed (kn)", formatNum(inputs.mostEfficientSpeedKn, 2, "--"), "Used directly for Balanced pace when supplied"],
          ["Effective speed (kn)", formatNum(derived.effectiveSpeedKn, 2, "--"), "Balanced uses Most Efficient Speed. Other paces use max speed x pace ratio"],
          ["Weather-adjusted speed (kn)", formatNum(derived.weatherAdjustedSpeedKn, 2, "--"), "effective speed x (1 - weather factor) with a 0.5 kn floor"],
          ["Fuel mode", String(derived.fuelMode || "--"), derived.usesAnchoredBurn ? "Anchored model uses low-speed, efficient, and max-speed anchors" : "Route Generator fuel mode"],
          ["Fuel burn @ max (GPH)", formatNum(inputs.fuelBurnGph, 2, "--"), "Required for Relaxed or Max Speed"],
          ["GPH @ efficient", formatNum(inputs.fuelBurnEfficientGph, 2, "--"), "Required on this standalone calculator"],
          ["Pace-adjusted burn (GPH)", formatNum(derived.paceAdjustedBurnGph, 2, "--"), derived.usesAnchoredBurn ? "Anchored interpolation between low, efficient, and max-speed burn anchors" : "Max burn x pace ratio^3 or Balanced efficient burn"],
          ["Weather-adjusted burn (GPH)", formatNum(derived.weatherAdjustedBurnGph, 2, "--"), "pace-adjusted burn x (1 + weather factor)"],
          ["Reserve method", reserveLabel, isThirds ? "One-Third Rule planning mode" : "percentage-based planning margin"],
          ["Usable fuel capacity (gal)", formatNum(inputs.usableFuelCapacityGallons, 2, "--"), "caller-entered usable fuel before reserve"],
          ["Trip-usable fuel for range (gal)", formatNum(derived.tripUsableCapacityGallons, 2, "--"), isThirds ? "usable fuel x 2/3 under the One-Third Rule" : "usable fuel x (1 - reserve percent)"],
          ["Capacity status", capacityStatus, "compares usable capacity with the departure requirement for the selected assumptions"],
          ["Capacity shortfall (gal)", formatNum(derived.capacityShortfallGallons, 2, "--"), "amount below the departure requirement; zero when capacity meets it"],
          ["Capacity margin (gal)", formatNum(derived.capacityMarginGallons, 2, "--"), "amount above the departure requirement; zero at or below it"],
          ["Estimated endurance with reserve (h)", formatNum(derived.estimatedEnduranceHours, 2, "--"), "fuel available after reserve / weather-adjusted burn"],
          ["Estimated range with reserve (NM)", formatNum(derived.estimatedRangeNauticalMiles, 2, "--"), "endurance with reserve x weather-adjusted speed"],
          ["Cruise hours", formatNum(derived.cruiseHours, 2, "--"), "distance / weather-adjusted speed"],
          ["Idle fuel (gal)", formatNum(derived.idleFuelGallons, 2, "--"), "idle burn x idle hours, rounded to the Route Generator preview precision"],
          ["Base fuel (gal)", formatNum(derived.baseFuelGallons, 2, "--"), "cruise fuel + idle fuel"],
          [isThirds ? "One-Third Rule Reserve (gal)" : "Reserve fuel (gal)", formatNum(derived.reserveGallons, 2, "--"), isThirds ? "base fuel x 0.5" : "base fuel x reserve percent"],
          ["Required fuel (gal)", formatNum(derived.requiredFuelGallons, 2, "--"), isThirds ? "base fuel x 1.5" : "base fuel + reserve"],
          ["Fuel cost (USD)", formatCurrency(derived.totalFuelCost, "--"), "required fuel x price per gallon"],
          ["Estimated days", (derived.estimatedDays === null || derived.estimatedDays === undefined) ? "--" : String(derived.estimatedDays), "ceil(total travel hours / underway hours per day)"]
        ];

        q("calcBreakdownBody").innerHTML = rows.map(function (row) {
          return "<tr>"
            + "<td>" + row[0] + "</td>"
            + "<td class=\"num\">" + row[1] + "</td>"
            + "<td>" + row[2] + "</td>"
            + "</tr>";
        }).join("");
      }

      function renderJson(model) {
        var output = q("calcJsonOut");
        var inputs = model.inputs || {};
        var derived = model.derived || {};
        var hasDistance = safeNum(inputs.distanceNm) !== null && inputs.distanceNm > 0;

        hasValidFuelJson = !!derived.canEstimateFuel && hasDistance;
        if (!hasValidFuelJson) {
          output.textContent = "";
          output.hidden = true;
          return;
        }

        output.hidden = false;
        output.textContent = JSON.stringify({
          reserveMode: model.inputs.reserveMode,
          route_generator_source_of_truth: {
            pace_formula: "routegenNormalizePace + routegenPaceDefaults + routegenComputeEffectiveCruisingSpeed",
            burn_formula: "calculateFuelEstimate + routegenAnchoredBurnGph",
            reserve_default_pct: DEFAULT_RESERVE_PCT
          },
          standalone_inputs: model.inputs,
          derived: model.derived,
          cards: {
            total_distance_nm: model.inputs.distanceNm,
            total_travel_hours: model.derived.totalTravelHours,
            estimated_fuel_gallons: model.derived.requiredFuelGallons,
            adjusted_speed_kn: model.derived.weatherAdjustedSpeedKn,
            expected_avg_gph: model.derived.weatherAdjustedBurnGph,
            estimated_range_with_reserve_nm: model.derived.estimatedRangeNauticalMiles,
            estimated_endurance_with_reserve_hours: model.derived.estimatedEnduranceHours,
            fuel_cost_usd: model.derived.totalFuelCost
          }
        }, null, 2);
      }

      function run() {
        var model = buildModel(getInputs());
        q("maxSpeedKn").placeholder = (model.inputs && model.inputs.pace === "BALANCED") ? "" : "Required";
        renderRequiredEfficientInputsMessage(model);
        renderRequiredEfficientInputState(model);
        renderUsableFuelCapacityInputState(model);
        renderUsableFuelCapacityStatus(model);
        renderCards(model);
        renderBreakdown(model);
        renderJson(model);
      }

      function resetInputs() {
        q("totalNm").value = "";
        q("pace").value = "RELAXED";
        q("mostEfficientSpeedKn").value = "";
        q("fuelBurnEfficientGph").value = "";
        q("maxSpeedKn").value = "";
        q("fuelBurnGph").value = "";
        q("idleBurnGph").value = "";
        q("idleHoursTotal").value = "";
        q("weatherPct").value = "0";
        q("reservePct").value = "33";
        q("usableFuelCapacityGallons").value = "";
        q("underwayHoursPerDay").value = "6.5";
        q("fuelPricePerGal").value = "";
        run();
      }

      q("resetBtn").addEventListener("click", resetInputs);
      q("copyJsonBtn").addEventListener("click", function () {
        var text = q("calcJsonOut").textContent || "";
        if (!hasValidFuelJson || !text) {
          return;
        }
        if (navigator.clipboard && navigator.clipboard.writeText) {
          navigator.clipboard.writeText(text);
        }
      });

      [
        "totalNm",
        "pace",
        "mostEfficientSpeedKn",
        "fuelBurnEfficientGph",
        "maxSpeedKn",
        "fuelBurnGph",
        "idleBurnGph",
        "idleHoursTotal",
        "weatherPct",
        "reservePct",
        "usableFuelCapacityGallons",
        "underwayHoursPerDay",
        "fuelPricePerGal"
      ].forEach(function (id) {
        var el = q(id);
        if (!el) return;
        el.addEventListener("input", run);
        el.addEventListener("change", run);
      });

      resetInputs();
    })();
</script>
</body>
</html>
