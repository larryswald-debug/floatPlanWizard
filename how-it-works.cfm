<cfprocessingdirective pageencoding="utf-8">
<cfsetting showdebugoutput="false" requesttimeout="30">
<cfcontent type="text/html; charset=utf-8">

<cfscript>
fpwHowBasePath = "";
fpwHowScriptName = structKeyExists(cgi, "script_name") ? trim(toString(cgi.script_name)) : "";

if (structKeyExists(request, "fpwBase")) {
  fpwHowBasePath = trim(toString(request.fpwBase));
}

if (!len(fpwHowBasePath) AND len(fpwHowScriptName)) {
  fpwHowBasePath = reReplace(fpwHowScriptName, "/how-it-works\.cfm$", "");

  if (fpwHowBasePath EQ fpwHowScriptName) {
    fpwHowBasePath = getDirectoryFromPath(fpwHowScriptName);
    fpwHowBasePath = reReplace(fpwHowBasePath, "/$", "");
  }
}

fpwHowBasePath = reReplace(fpwHowBasePath, "/$", "");
if (fpwHowBasePath EQ "/") {
  fpwHowBasePath = "";
}
if (len(fpwHowBasePath) AND left(fpwHowBasePath, 1) NEQ "/") {
  fpwHowBasePath = "/" & fpwHowBasePath;
}

request.fpwBase = fpwHowBasePath;
fpwHowNotifyUrl = fpwHowBasePath & "/app/join.cfm" & chr(35) & "notify";
fpwHowFuelUrl = fpwHowBasePath & "/boat-fuel-calculator/boat-fuel-calculator.cfm";


fpwHowFaqItems = [
  {
    "id": "what-is-a-float-plan",
    "question": "What is a float plan?",
    "answer": [
      "A float plan is a written record of your boating trip. It usually includes your vessel information, passengers, departure point, destination, expected return time, route notes, emergency contacts, and instructions for what someone should do if you are overdue.",
      "FloatPlanWizard helps you create a more organized digital float plan that can be updated and shared with trusted family and friends."
    ]
  },
  {
    "id": "what-is-the-floatplanwizard-route-builder",
    "question": "How is FloatPlanWizard different from a navigation app?",
    "answer": [
      "FloatPlanWizard doesn’t replace your chartplotter or navigation app. It organizes your planned route, vessel and passenger information, float plan, shore-contact updates, and trip status in one place."
    ]
  },
  {
    "id": "do-my-contacts-need-an-account",
    "question": "Does my shore contact need an account?",
    "answer": [
      "No. Your shore contact does not need a FloatPlanWizard account to view the trip information you share.",
      "Only the captain or trip planner needs an account to create, manage, update, and share the float plan."
    ]
  },
  {
    "id": "can-i-use-it-for-local-trips",
    "question": "Can I use it for local trips?",
    "answer": [
      "Yes. FloatPlanWizard works well for local trips because it helps you quickly organize the basic details: where you are leaving from, where you plan to go, who is with you, when you expect to return, and who should know about the trip.",
      "Local trips are often the ones boaters take casually, which is exactly why having a simple plan can be helpful."
    ]
  },
  {
    "id": "what-if-my-plans-change",
    "question": "What if my plans change?",
    "answer": [
      "You can update your float plan as your trip changes. Adjust your route details, timing, delay information, trip notes, or check-in status so your shared plan stays current.",
      "If your plans change significantly, update the plan and let your contacts know to check the latest Trip status page."
    ]
  },
  {
    "id": "how-much-does-floatplanwizard-cost",
    "question": "How much does FloatPlanWizard cost?",
    "answer": [
      "Current access options, trial details, and membership pricing are shown on the pricing page. Because offers can change, the pricing page is the best place to confirm the latest details before signing up."
    ]
  }
];

function fpwHowFaqJoinParagraphs(required array paragraphs) {
  var joinedText = "";
  var paragraphIndex = 0;

  for (paragraphIndex = 1; paragraphIndex LTE arrayLen(arguments.paragraphs); paragraphIndex++) {
    if (len(joinedText)) {
      joinedText &= chr(10) & chr(10);
    }
    joinedText &= arguments.paragraphs[paragraphIndex];
  }

  return joinedText;
}

fpwHowFaqSchemaMainEntity = [];
for (fpwHowFaqItem in fpwHowFaqItems) {
  fpwHowFaqQuestion = structNew("ordered");
  fpwHowFaqAnswer = structNew("ordered");
  structInsert(fpwHowFaqQuestion, "@type", "Question", true);
  fpwHowFaqQuestion["name"] = fpwHowFaqItem.question;
  structInsert(fpwHowFaqAnswer, "@type", "Answer", true);
  fpwHowFaqAnswer["text"] = fpwHowFaqJoinParagraphs(fpwHowFaqItem.answer);
  fpwHowFaqQuestion["acceptedAnswer"] = fpwHowFaqAnswer;
  arrayAppend(fpwHowFaqSchemaMainEntity, fpwHowFaqQuestion);
}

fpwHowFaqSchema = structNew("ordered");
structInsert(fpwHowFaqSchema, "@context", "https://schema.org", true);
structInsert(fpwHowFaqSchema, "@type", "FAQPage", true);
fpwHowFaqSchema["mainEntity"] = fpwHowFaqSchemaMainEntity;
fpwHowFaqJsonLdText = replace(serializeJSON(fpwHowFaqSchema), "</", "<\/", "all");
</cfscript>

<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>How It Works | FloatPlanWizard</title>
  <meta name="description" content="See how FloatPlanWizard helps boaters plan routes, create float plans, share trip details, and keep trusted contacts informed.">
  <meta property="og:type" content="website">
  <meta property="og:site_name" content="FloatPlanWizard">
  <meta property="og:url" content="https://floatplanwizard.com/how-it-works/">
  <meta property="og:title" content="How It Works | FloatPlanWizard">
  <meta property="og:description" content="See how FloatPlanWizard helps boaters plan routes, create float plans, share trip details, and keep trusted contacts informed.">
  <meta property="og:image" content="https://floatplanwizard.com/assets/images/social/floatplanwizard-social-preview-20260730.png">
  <meta property="og:image:secure_url" content="https://floatplanwizard.com/assets/images/social/floatplanwizard-social-preview-20260730.png">
  <meta property="og:image:type" content="image/png">
  <meta property="og:image:width" content="1200">
  <meta property="og:image:height" content="630">
  <meta property="og:image:alt" content="FloatPlanWizard boating trip planning and monitored float plan preview image">
  <meta name="twitter:card" content="summary_large_image">
  <meta name="twitter:title" content="How It Works | FloatPlanWizard">
  <meta name="twitter:description" content="See how FloatPlanWizard helps boaters plan routes, create float plans, share trip details, and keep trusted contacts informed.">
  <meta name="twitter:image" content="https://floatplanwizard.com/assets/images/social/floatplanwizard-social-preview-20260730.png">
  <meta name="twitter:image:alt" content="FloatPlanWizard boating trip planning and monitored float plan preview image">
  
  <link rel="preconnect" href="https://cdn.jsdelivr.net" crossorigin>
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.3/font/bootstrap-icons.min.css">
  <style>
    :root {
      --fpw-how-bg: #020915;
      --fpw-how-bg-2: #041121;
      --fpw-how-card: rgba(5, 17, 31, 0.82);
      --fpw-how-card-strong: rgba(4, 14, 26, 0.94);
      --fpw-how-line: rgba(126, 205, 220, 0.28);
      --fpw-how-line-strong: rgba(126, 225, 242, 0.62);
      --fpw-how-text: #f4f8ff;
      --fpw-how-muted: #b8c5d2;
      --fpw-how-soft: #8398aa;
      --fpw-how-cyan: #23d7cf;
      --fpw-how-blue: #36bdf5;
      --fpw-how-radius: 18px;
      --fpw-public-layout-max: var(--fpw-page-max, 1200px);
    }

    * {
      box-sizing: border-box;
    }

    html {
      scroll-behavior: smooth;
    }

    body.fpw-how-body {
      margin: 0;
      min-height: 100vh;
      color: var(--fpw-how-text);
      font-family: Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      background:
        radial-gradient(circle at 18% 8%, rgba(35, 215, 207, 0.13), transparent 22rem),
        radial-gradient(circle at 82% 10%, rgba(54, 189, 245, 0.12), transparent 24rem),
        radial-gradient(circle at 48% 86%, rgba(35, 215, 207, 0.08), transparent 28rem),
        linear-gradient(180deg, #020712 0%, #03101e 48%, #020914 100%);
    }

    body.fpw-how-body a {
      color: inherit;
      text-decoration: none;
    }

    body.fpw-how-body .shell {
      margin: 0 auto;
    }

    .fpw-how-page {
      position: relative;
      width: min(var(--fpw-public-layout-max), calc(100% - (var(--fpw-page-gutter, 32px) * 2)));
      margin: 0 auto;
      padding: 42px 0 8px;
      overflow: hidden;
    }

    .fpw-how-page::before,
    .fpw-how-final-cta::before {
      content: "";
      position: absolute;
      inset: 0;
      pointer-events: none;
      background-image:
        linear-gradient(rgba(126, 205, 220, 0.035) 1px, transparent 1px),
        linear-gradient(90deg, rgba(126, 205, 220, 0.035) 1px, transparent 1px);
      background-size: 88px 88px;
      mask-image: radial-gradient(circle at 50% 8%, #000 0%, transparent 62%);
      opacity: 0.65;
    }

    .fpw-how-hero,
    .fpw-how-section,
    .fpw-how-final-cta {
      position: relative;
      z-index: 1;
    }

    .fpw-how-hero {
      display: grid;
      grid-template-columns: minmax(0, 0.88fr) minmax(520px, 1.12fr);
      gap: 52px;
      align-items: center;
      padding: 20px 0 44px;
      border-bottom: 1px solid rgba(126, 205, 220, 0.2);
    }

    .fpw-eyebrow {
      margin: 0 0 16px;
      color: var(--fpw-how-cyan);
      font-size: 0.84rem;
      font-weight: 850;
      letter-spacing: 0.16em;
      text-transform: uppercase;
    }

    .fpw-how-hero h1 {
      margin: 0;
      color: #ffffff;
      font-size: clamp(3.4rem, 6vw, 5.25rem);
      line-height: 0.95;
      letter-spacing: 0;
      text-shadow: 0 16px 34px rgba(0, 0, 0, 0.38);
    }

    .fpw-how-hero__lead {
      max-width: 570px;
      margin: 24px 0 0;
      color: rgba(233, 243, 251, 0.84);
      font-size: 1.24rem;
      line-height: 1.58;
    }

    .fpw-how-actions {
      display: flex;
      flex-wrap: wrap;
      gap: 16px;
      margin-top: 30px;
    }

    .fpw-btn {
      display: inline-flex;
      align-items: center;
      justify-content: center;
      gap: 13px;
      min-height: 56px;
      border-radius: 9px;
      padding: 0 22px;
      color: #ffffff;
      font-weight: 800;
      line-height: 1;
      border: 1px solid rgba(126, 205, 220, 0.46);
      transition: transform 0.16s ease, border-color 0.16s ease, box-shadow 0.16s ease;
    }

    .fpw-btn:hover {
      transform: translateY(-1px);
      border-color: rgba(120, 242, 255, 0.85);
    }

    .fpw-btn--primary {
      background:
        linear-gradient(135deg, rgba(22, 168, 199, 0.95), rgba(3, 71, 115, 0.96));
      box-shadow: 0 0 26px rgba(35, 215, 207, 0.34), inset 0 1px 0 rgba(255, 255, 255, 0.18);
    }

    .fpw-btn--secondary {
      color: rgba(244, 248, 255, 0.9);
      background: rgba(4, 14, 26, 0.62);
    }

    .fpw-btn__icon,
    .fpw-arrow-icon {
      width: 18px;
      height: 18px;
      flex: 0 0 auto;
    }

    .fpw-trip-preview,
    .fpw-step-card,
    .fpw-timeline-card,
    .fpw-benefit-card,
    .fpw-faq-list,
    .fpw-how-final-cta {
      border: 1px solid var(--fpw-how-line);
      background:
        linear-gradient(180deg, rgba(8, 25, 43, 0.78), rgba(3, 13, 24, 0.9));
      box-shadow: 0 18px 46px rgba(0, 0, 0, 0.34), inset 0 1px 0 rgba(255, 255, 255, 0.04);
    }

    .fpw-trip-preview {
      border-color: rgba(126, 225, 242, 0.65);
      border-radius: 18px;
      overflow: hidden;
    }

    .fpw-trip-preview__header {
      display: grid;
      grid-template-columns: minmax(0, 1fr) auto auto;
      gap: 14px;
      align-items: center;
      min-height: auto;
      padding: 10px 24px 12px;
    }

    .fpw-trip-preview__header h2 {
      margin: 0;
      color: #ffffff;
      font-size: 1.28rem;
      line-height: 1.2;
      letter-spacing: 0;
    }

    .fpw-status-pill {
      display: inline-flex;
      align-items: center;
      min-height: 28px;
      border-radius: 999px;
      padding: 0 14px;
      color: #c8fff1;
      background: rgba(25, 154, 119, 0.5);
      font-size: 0.72rem;
      font-weight: 900;
      letter-spacing: 0.08em;
    }

    .fpw-menu-dot {
      color: rgba(244, 248, 255, 0.82);
      font-size: 1.45rem;
      line-height: 1;
    }

    .fpw-trip-preview__body {
      display: grid;
      grid-template-columns: minmax(250px, 0.9fr) minmax(280px, 1.1fr);
      gap: 14px;
      padding: 0 24px 24px;
    }

    .fpw-map-card {
      min-height: 292px;
      border-radius: 8px;
      border: 1px solid rgba(126, 205, 220, 0.28);
      overflow: hidden;
      background:
        radial-gradient(circle at 64% 84%, rgba(35, 215, 207, 0.2), transparent 18%),
        radial-gradient(circle at 18% 4%, rgba(54, 189, 245, 0.16), transparent 26%),
        linear-gradient(180deg, #041627, #02101d);
    }

    .fpw-map-card__image {
      display: block;
      width: 100%;
      height: 100%;
      min-height: 292px;
      object-fit: cover;
      object-position: center;
    }

    .fpw-map-card__svg {
      width: 100%;
      height: 100%;
      min-height: 292px;
      display: block;
    }

    .fpw-map-card__coast {
      fill: none;
      stroke: rgba(20, 95, 131, 0.36);
      stroke-width: 16;
    }

    .fpw-map-card__grid {
      fill: none;
      stroke: rgba(126, 205, 220, 0.08);
      stroke-width: 1;
    }

    .fpw-map-card__route {
      fill: none;
      stroke: url(#fpwRouteGradient);
      stroke-width: 5;
      stroke-linecap: round;
    }

    .fpw-map-card__pin {
      fill: #02101d;
      stroke: #ffffff;
      stroke-width: 3;
    }

    .fpw-map-card__pin--active {
      fill: #eaffff;
      stroke: var(--fpw-how-cyan);
      filter: drop-shadow(0 0 10px rgba(35, 215, 207, 0.95));
    }

    .fpw-map-card__spark {
      fill: var(--fpw-how-cyan);
      opacity: 0.9;
    }

    .fpw-map-card__label {
      fill: #ffffff;
      font-size: 16px;
      font-weight: 700;
    }

    .fpw-trip-details {
      display: grid;
      gap: 10px;
    }

    .fpw-trip-details__times {
      display: grid;
      grid-template-columns: 1fr 1fr;
      border: 1px solid rgba(126, 205, 220, 0.22);
      border-radius: 7px;
      overflow: hidden;
      background: rgba(2, 10, 19, 0.36);
    }

    .fpw-trip-details__times > div {
      padding: 16px 18px;
    }

    .fpw-trip-details__times > div + div {
      border-left: 1px solid rgba(126, 205, 220, 0.2);
    }

    .fpw-trip-details span {
      color: rgba(233, 243, 251, 0.74);
      font-size: 0.88rem;
    }

    .fpw-trip-details strong {
      display: block;
      margin-top: 5px;
      color: #ffffff;
      font-size: 0.92rem;
      font-weight: 750;
    }

    .fpw-trip-details__row {
      display: grid;
      grid-template-columns: 26px minmax(85px, 0.7fr) minmax(0, 1fr);
      align-items: center;
      gap: 12px;
      min-height: 40px;
      padding: 0 16px;
      border: 1px solid rgba(126, 205, 220, 0.18);
      border-top: 0;
      background: rgba(2, 10, 19, 0.26);
    }

    .fpw-trip-details__row:first-of-type {
      border-top: 1px solid rgba(126, 205, 220, 0.18);
      border-radius: 7px 7px 0 0;
    }

    .fpw-trip-details__row:nth-last-of-type(1) {
      border-radius: 0 0 7px 7px;
    }

    .fpw-line-icon {
      display: inline-flex;
      color: #c5f8ff;
    }

    .fpw-line-icon svg {
      width: 18px;
      height: 18px;
      stroke: currentColor;
    }

    .fpw-trip-details__button {
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 12px;
      min-height: 44px;
      border-radius: 6px;
      color: #ffffff;
      border: 1px solid rgba(126, 225, 242, 0.64);
      background: rgba(4, 16, 28, 0.54);
      font-weight: 800;
    }

    .fpw-how-section {
      padding: 22px 0 20px;
      border-bottom: 1px solid rgba(126, 205, 220, 0.18);
    }

    .fpw-how-section h2,
    .fpw-how-final-cta h2 {
      margin: 0;
      color: #ffffff;
      font-size: clamp(1.65rem, 2.7vw, 2rem);
      line-height: 1.1;
      text-align: center;
      letter-spacing: 0;
    }

    .fpw-step-grid,
    .fpw-benefit-grid {
      display: grid;
      grid-template-columns: repeat(4, minmax(0, 1fr));
      gap: 28px;
      margin-top: 18px;
    }

    .fpw-step-card,
    .fpw-benefit-card {
      position: relative;
      min-height: 248px;
      border-radius: 10px;
      padding: 28px 24px 24px;
      text-align: center;
    }

    .fpw-step-card__badge {
      position: absolute;
      top: 14px;
      left: 14px;
      width: 34px;
      height: 34px;
      display: grid;
      place-items: center;
      border-radius: 50%;
      color: #ffffff;
      background: linear-gradient(135deg, #3ddff0, #186b8f);
      border: 1px solid rgba(180, 250, 255, 0.44);
      box-shadow: 0 0 16px rgba(35, 215, 207, 0.36);
      font-weight: 900;
    }

    .fpw-step-card__icon,
    .fpw-benefit-card__icon,
    .fpw-timeline-card__icon {
      display: grid;
      place-items: center;
      color: #90f8ff;
    }

    .fpw-step-card__icon svg {
      width: 92px;
      height: 76px;
      stroke: currentColor;
      stroke-width: 1.55;
      fill: none;
      filter: drop-shadow(0 0 8px rgba(35, 215, 207, 0.28));
    }

    .fpw-step-card h3,
    .fpw-benefit-card h3,
    .fpw-timeline-card h3 {
      margin: 20px 0 0;
      color: #ffffff;
      font-size: 1.18rem;
      line-height: 1.2;
      letter-spacing: 0;
    }

    .fpw-step-card p,
    .fpw-benefit-card p {
      margin: 12px auto 0;
      color: var(--fpw-how-muted);
      font-size: 0.98rem;
      line-height: 1.52;
    }

    .fpw-action-section {
      padding-bottom: 18px;
    }

    .fpw-timeline {
      position: relative;
      display: grid;
      grid-template-columns: repeat(5, minmax(132px, 1fr));
      gap: 54px;
      align-items: center;
      margin: 10px 50px 0;
      padding-top: 4px;
    }

    .fpw-timeline::before {
      content: "";
      position: absolute;
      left: 7%;
      right: 7%;
      top: 58%;
      height: 3px;
      transform: translateY(-50%);
      background: linear-gradient(90deg, transparent, rgba(134, 252, 255, 0.96), transparent);
      box-shadow: 0 0 14px rgba(35, 215, 207, 0.72);
    }

    .fpw-timeline-card {
      position: relative;
      z-index: 1;
      min-height: 152px;
      border-radius: 8px;
      padding: 16px 14px 14px;
      text-align: center;
      background: rgba(4, 14, 26, 0.92);
    }

    .fpw-timeline-card::before,
    .fpw-timeline-card::after {
      content: "";
      position: absolute;
      top: 50%;
      width: 15px;
      height: 15px;
      transform: translateY(-50%);
      border-radius: 50%;
      border: 2px solid rgba(145, 255, 255, 0.95);
      background: #051425;
      box-shadow: 0 0 12px rgba(35, 215, 207, 0.75);
    }

    .fpw-timeline-card::before {
      left: -34px;
    }

    .fpw-timeline-card::after {
      right: -34px;
    }

    .fpw-timeline-card:first-child::before,
    .fpw-timeline-card:last-child::after {
      display: none;
    }

    .fpw-timeline-card__icon svg {
      width: 58px;
      height: 52px;
      stroke: currentColor;
      stroke-width: 1.45;
      fill: none;
    }

    .fpw-timeline-card h3 {
      margin-top: 12px;
      font-size: 0.98rem;
    }

    .fpw-timeline-card h3 span {
      display: block;
      color: var(--fpw-how-muted);
      font-size: 0.86rem;
      font-weight: 700;
    }

    .fpw-timeline-card time {
      display: block;
      margin-top: 9px;
      color: var(--fpw-how-cyan);
      font-size: 0.9rem;
      font-weight: 800;
    }

    .fpw-benefit-grid {
      gap: 28px;
    }

    .fpw-benefit-card {
      display: grid;
      grid-template-columns: 78px 1fr;
      gap: 18px;
      min-height: 150px;
      padding: 22px 20px;
      text-align: left;
      align-items: center;
    }

    .fpw-benefit-card__icon svg {
      width: 68px;
      height: 62px;
      stroke: currentColor;
      stroke-width: 1.55;
      fill: none;
    }

    .fpw-benefit-card h3 {
      margin-top: 0;
      font-size: 1rem;
    }

    .fpw-benefit-card p {
      margin-top: 9px;
      font-size: 0.86rem;
      line-height: 1.48;
    }

    .fpw-faq-section {
      padding-top: 16px;
    }

    .fpw-faq-list {
      margin: 14px auto 0;
      border-radius: 11px;
      overflow: hidden;
    }

    .fpw-faq-item + .fpw-faq-item {
      border-top: 1px solid rgba(126, 205, 220, 0.18);
    }

    .fpw-faq-row {
      width: 100%;
      min-height: 43px;
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 20px;
      border: 0;
      padding: 0 38px;
      color: #ffffff;
      background: transparent;
      cursor: pointer;
      font: inherit;
      font-size: 1rem;
      text-align: left;
    }

    .fpw-faq-row:focus-visible {
      outline: 2px solid rgba(149, 248, 255, 0.8);
      outline-offset: -4px;
    }

    .fpw-faq-icon {
      color: #95f8ff;
      font-size: 1.65rem;
      font-weight: 300;
      line-height: 1;
      transition: color 0.16s ease, transform 0.16s ease;
    }

    .fpw-faq-row[aria-expanded="true"] .fpw-faq-icon {
      color: #ffffff;
      transform: rotate(45deg);
    }

    .fpw-faq-answer {
      padding: 0 38px 16px;
      color: rgba(233, 243, 251, 0.76);
      font-size: 0.96rem;
      line-height: 1.55;
    }

    .fpw-faq-answer p {
      max-width: 940px;
      margin: 0;
    }

    .fpw-faq-answer p + p {
      margin-top: 12px;
    }

    .fpw-faq-full-link {
      display: flex;
      justify-content: center;
      margin-top: 20px;
    }

    .fpw-faq-full-link .fpw-btn {
      min-width: 280px;
    }

    .fpw-how-final-cta {
      display: grid;
      grid-template-columns: auto minmax(0, 1fr) auto;
      gap: 36px;
      align-items: center;
      margin: 20px auto 10px;
      border-radius: 12px;
      border-color: rgba(126, 225, 242, 0.7);
      padding: 30px 56px;
      overflow: hidden;
      background:
        radial-gradient(circle at 12% 46%, rgba(35, 215, 207, 0.18), transparent 17rem),
        radial-gradient(circle at 82% 26%, rgba(54, 189, 245, 0.12), transparent 20rem),
        linear-gradient(180deg, rgba(8, 25, 43, 0.86), rgba(3, 13, 24, 0.96));
    }

    .fpw-how-final-cta::before {
      background-image:
        repeating-radial-gradient(ellipse at 50% 50%, rgba(126, 205, 220, 0.15) 0 1px, transparent 1px 16px);
      mask-image: linear-gradient(90deg, transparent, #000 16%, #000 84%, transparent);
      opacity: 0.34;
    }

    .fpw-how-final-cta__mark {
      position: relative;
      z-index: 1;
      width: 86px;
      height: 86px;
      display: grid;
      place-items: center;
      border-radius: 50%;
      color: #b9fbff;
      background:
        radial-gradient(circle, rgba(35, 215, 207, 0.26), rgba(6, 25, 41, 0.96) 64%);
      border: 1px solid rgba(126, 225, 242, 0.64);
      box-shadow: 0 0 28px rgba(35, 215, 207, 0.42);
    }

    .fpw-how-final-cta__mark svg {
      width: 58px;
      height: 58px;
      stroke: currentColor;
      fill: none;
    }

    .fpw-how-final-cta > div,
    .fpw-how-final-cta .fpw-btn {
      position: relative;
      z-index: 1;
    }

    .fpw-how-final-cta h2 {
      max-width: 470px;
      text-align: left;
      font-size: clamp(1.7rem, 3vw, 2.15rem);
      line-height: 1.12;
    }

    .fpw-how-final-cta p {
      margin: 14px 0 0;
      color: var(--fpw-how-muted);
      font-size: 1rem;
    }

    .fpw-how-final-cta .fpw-btn {
      min-width: 314px;
      min-height: 64px;
      font-size: 1.1rem;
    }

    .fpw-icon-stroke {
      stroke: currentColor;
      stroke-linecap: round;
      stroke-linejoin: round;
      fill: none;
    }

    @media (max-width: 1120px) {
      .fpw-how-hero {
        grid-template-columns: 1fr;
      }

      .fpw-step-grid,
      .fpw-benefit-grid {
        grid-template-columns: repeat(2, minmax(0, 1fr));
      }

      .fpw-timeline {
        gap: 24px;
        margin-left: 0;
        margin-right: 0;
        overflow-x: auto;
        padding: 8px 4px 12px;
      }

      .fpw-timeline-card {
        min-width: 154px;
      }

      .fpw-how-final-cta {
        grid-template-columns: auto 1fr;
      }

      .fpw-how-final-cta .fpw-btn {
        grid-column: 2;
        width: fit-content;
      }
    }

    @media (max-width: 780px) {
      .fpw-how-page {
        width: min(var(--fpw-public-layout-max), calc(100% - (var(--fpw-page-gutter, 32px) * 2)));
        padding-top: 28px;
      }

      .fpw-how-hero h1 {
        font-size: clamp(3rem, 14vw, 4.2rem);
      }

      .fpw-trip-preview__body,
      .fpw-trip-details__times,
      .fpw-step-grid,
      .fpw-benefit-grid,
      .fpw-how-final-cta {
        grid-template-columns: 1fr;
      }

      .fpw-trip-preview__body {
        padding: 0 16px 18px;
      }

      .fpw-trip-preview__header {
        padding: 10px 16px 12px;
      }

      .fpw-step-card {
        min-height: auto;
      }

      .fpw-benefit-card {
        grid-template-columns: 64px 1fr;
      }

      .fpw-faq-row {
        padding: 0 18px;
      }

      .fpw-faq-answer {
        padding: 0 18px 16px;
      }

      .fpw-how-final-cta {
        gap: 20px;
        padding: 26px 22px;
      }

      .fpw-how-final-cta .fpw-btn {
        grid-column: auto;
        min-width: 0;
        width: 100%;
      }
    }

    @media (max-width: 520px) {
      .fpw-how-actions .fpw-btn {
        width: 100%;
      }

      .fpw-trip-details__row {
        grid-template-columns: 22px 1fr;
      }

      .fpw-trip-details__row strong {
        grid-column: 2;
        margin-top: -4px;
      }
    }
  </style>
<link rel="canonical" href="https://floatplanwizard.com/how-it-works/" />
<cfoutput><link rel="stylesheet" href="#fpwHowBasePath#/assets/css/layout.css?v=20260620-page-width"></cfoutput>
<cfoutput><link rel="stylesheet" href="#fpwHowBasePath#/assets/css/top-nav.css?v=20260824-boating-safety-nav-v2"></cfoutput>
<script type="application/ld+json"><cfoutput>#fpwHowFaqJsonLdText#</cfoutput></script>
</head>
<body id="top" class="fpw-how-body">
<cfinclude template="includes/top_nav.cfm">

<main class="fpw-how-page">
  <section class="fpw-how-hero">
    <div class="fpw-how-hero__copy">
      <p class="fpw-eyebrow">FloatPlanWizard</p>
      <h1>How It Works</h1>
      <p class="fpw-how-hero__lead">
        Plan your route, create your float plan, and keep trusted contacts informed from departure through safe return.
      </p>

      <div class="fpw-how-actions">
        <a class="fpw-btn fpw-btn--primary" href="<cfoutput>#fpwHowBasePath#/app/join.cfm</cfoutput>">
          <span>Start Free</span>
          <svg class="fpw-arrow-icon" viewBox="0 0 24 24" aria-hidden="true">
            <path class="fpw-icon-stroke" d="M5 12h13M13 6l6 6-6 6" stroke-width="2"></path>
          </svg>
        </a>

        <a class="fpw-btn fpw-btn--secondary" href="<cfoutput>#fpwHowFuelUrl#</cfoutput>">
          <span>Try the Fuel Calculator</span>
          <svg class="fpw-btn__icon" viewBox="0 0 24 24" aria-hidden="true">
            <rect class="fpw-icon-stroke" x="5" y="3" width="14" height="18" rx="2" stroke-width="1.8"></rect>
            <path class="fpw-icon-stroke" d="M8 8h8M8 12h2M12 12h2M16 12h0M8 16h2M12 16h2M16 16h0" stroke-width="1.8"></path>
          </svg>
        </a>
      </div>
    </div>

    <aside class="fpw-trip-preview" aria-label="Example trip preview">
      <div class="fpw-trip-preview__header">
        <h2>My Trip to Anclote Key</h2>
        <span class="fpw-status-pill">ON TRACK</span>
        <span class="fpw-menu-dot" aria-hidden="true">&vellip;</span>
      </div>

      <div class="fpw-trip-preview__body">
        <div class="fpw-map-card" aria-hidden="true">
          <cfoutput><img class="fpw-map-card__image" src="#fpwHowBasePath#/assets/images/anclote-key-route.png" alt=""></cfoutput>
        </div>

        <div class="fpw-trip-details">
          <div class="fpw-trip-details__times">
            <div>
              <span>Depart</span>
              <strong>Today, 8:30 AM</strong>
            </div>
            <div>
              <span>Return</span>
              <strong>Today, 6:30 PM</strong>
            </div>
          </div>

          <div class="fpw-trip-details__row">
            <span class="fpw-line-icon" aria-hidden="true">
              <svg viewBox="0 0 24 24"><path class="fpw-icon-stroke" d="M12 3v11M6 8h12M5 14c2 3 5 5 7 5s5-2 7-5M8 14h8" stroke-width="1.8"></path></svg>
            </span>
            <span>Vessel</span>
            <strong>23' Center Console</strong>
          </div>
          <div class="fpw-trip-details__row">
            <span class="fpw-line-icon" aria-hidden="true">
              <svg viewBox="0 0 24 24"><path class="fpw-icon-stroke" d="M8 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8ZM16 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8ZM3 21c.6-4 2.3-6 5-6s4.4 2 5 6M11 21c.5-3.5 2.2-5.5 5-5.5 2.5 0 4.2 1.8 5 5.5" stroke-width="1.5"></path></svg>
            </span>
            <span>Passengers</span>
            <strong>2 Adults</strong>
          </div>
          <div class="fpw-trip-details__row">
            <span class="fpw-line-icon" aria-hidden="true">
              <svg viewBox="0 0 24 24"><path class="fpw-icon-stroke" d="M8 4h7l3 4v12H6V6a2 2 0 0 1 2-2ZM10 4v5h6M9 14h6" stroke-width="1.7"></path></svg>
            </span>
            <span>Est. Fuel</span>
            <strong>28 gal</strong>
          </div>
          <div class="fpw-trip-details__row">
            <span class="fpw-line-icon" aria-hidden="true">
              <svg viewBox="0 0 24 24"><path class="fpw-icon-stroke" d="M12 3l8 3v5c0 5-3.4 8.4-8 10-4.6-1.6-8-5-8-10V6l8-3ZM9 12l2 2 4-5" stroke-width="1.7"></path></svg>
            </span>
            <span>Distance</span>
            <strong>13.2 nm</strong>
          </div>

          <a class="fpw-trip-details__button" href="<cfoutput>#fpwHowNotifyUrl#</cfoutput>">
            Start Free
            <span aria-hidden="true">&nearr;</span>
          </a>
        </div>
      </div>
    </aside>
  </section>

  <section class="fpw-how-section">
    <h2>The 4-Step Workflow</h2>

    <div class="fpw-step-grid">
      <article class="fpw-step-card">
        <span class="fpw-step-card__badge">1</span>
        <div class="fpw-step-card__icon" aria-hidden="true">
          <svg viewBox="0 0 120 90"><path d="M16 58h72l-11 17H31c-7 0-12-5-15-17ZM31 58V32M31 32h31M62 32v26M78 58l13-20M30 74c10 6 21 6 31 0M67 74c8 5 17 5 25 0M24 46h54"></path></svg>
        </div>
        <h3>Build Your Trip</h3>
        <p>Add departure, destination, stops, vessel, passengers, and timing.</p>
      </article>

      <article class="fpw-step-card">
        <span class="fpw-step-card__badge">2</span>
        <div class="fpw-step-card__icon" aria-hidden="true">
          <svg viewBox="0 0 120 90"><path d="M38 18h44v58H38zM50 18v-8h20v8M50 34l6 6 12-13M50 52l6 6 12-13M50 68h24M33 24h10M33 42h10M33 60h10"></path></svg>
        </div>
        <h3>Create a Float Plan</h3>
        <p>Turn your trip details into a clear float plan your shore contact can use.</p>
      </article>

      <article class="fpw-step-card">
        <span class="fpw-step-card__badge">3</span>
        <div class="fpw-step-card__icon" aria-hidden="true">
          <svg viewBox="0 0 120 90"><circle cx="60" cy="30" r="13"></circle><circle cx="34" cy="38" r="11"></circle><circle cx="86" cy="38" r="11"></circle><path d="M36 78c1-19 9-30 24-30s23 11 24 30M15 78c1-15 7-24 19-24M86 54c12 0 18 9 19 24"></path></svg>
        </div>
        <h3>Send to Your Shore Contact</h3>
        <p>Send a simple trip-status page your family or shore contact can follow without an account.</p>
      </article>

      <article class="fpw-step-card">
        <span class="fpw-step-card__badge">4</span>
        <div class="fpw-step-card__icon" aria-hidden="true">
          <svg viewBox="0 0 120 90"><rect x="42" y="12" width="36" height="66" rx="5"></rect><path d="M54 19h12M58 71h4"></path><circle cx="60" cy="47" r="18"></circle><path d="M51 47l7 7 13-16"></path></svg>
        </div>
        <h3>Check In Underway</h3>
        <p>Check in, report delays, secure for the night, and close your float plan when you return.</p>
      </article>
    </div>
  </section>

  <section class="fpw-how-section fpw-action-section">
    <h2>See It In Action</h2>

    <div class="fpw-timeline">
      <article class="fpw-timeline-card">
        <div class="fpw-timeline-card__icon" aria-hidden="true">
          <svg viewBox="0 0 70 60"><path d="M16 39h38l-7 11H25c-4 0-7-4-9-11ZM27 39V18M27 18h18M45 18v21M14 50c7 4 14 4 21 0M39 50c6 4 12 4 17 0M11 30h8M11 24h8"></path></svg>
        </div>
        <h3>Depart Marina</h3>
        <time>9:00 AM</time>
      </article>

      <article class="fpw-timeline-card">
        <div class="fpw-timeline-card__icon" aria-hidden="true">
          <svg viewBox="0 0 70 60"><path d="M14 39h42l-8 10H24c-5 0-8-3-10-10ZM26 39V20h21v19M19 31h32M18 50c8 4 16 4 24 0M45 50c5 3 10 3 15 0"></path></svg>
        </div>
        <h3>Cruise to Anclote Key</h3>
        <time>10:15 AM</time>
      </article>

      <article class="fpw-timeline-card">
        <div class="fpw-timeline-card__icon" aria-hidden="true">
          <svg viewBox="0 0 70 60"><circle cx="35" cy="30" r="22"></circle><path d="M35 13v17l10 8M17 8l5 5M53 8l-5 5"></path><circle cx="51" cy="44" r="12"></circle><path d="M46 44h10M51 39v10"></path></svg>
        </div>
        <h3>Report Delay <span>+30 min</span></h3>
        <time>12:00 PM</time>
      </article>

      <article class="fpw-timeline-card">
        <div class="fpw-timeline-card__icon" aria-hidden="true">
          <svg viewBox="0 0 70 60"><path d="M35 8v36M19 22c8 8 24 8 32 0M12 44c9 7 37 7 46 0M24 16l11-8 11 8M19 44l16-16 16 16"></path></svg>
        </div>
        <h3>Secure for the Night</h3>
        <time>5:00 PM</time>
      </article>

      <article class="fpw-timeline-card">
        <div class="fpw-timeline-card__icon" aria-hidden="true">
          <svg viewBox="0 0 70 60"><path d="M12 32L35 10l23 22M20 30v22h30V30M30 52V38h10v14"></path></svg>
        </div>
        <h3>Arrive Home</h3>
        <time>6:30 PM</time>
      </article>
    </div>
  </section>

  <section class="fpw-how-section">
    <h2>Why It&rsquo;s Better Than Just Sending a Text</h2>

    <div class="fpw-benefit-grid">
      <article class="fpw-benefit-card">
        <div class="fpw-benefit-card__icon" aria-hidden="true">
          <svg viewBox="0 0 80 70"><path d="M16 23c0-7 5-12 12-12s12 5 12 12c0 10-12 21-12 21S16 33 16 23ZM50 18c0-6 4-10 10-10s10 4 10 10c0 8-10 18-10 18S50 26 50 18ZM28 23h.1M60 18h.1M24 55c14-14 29 7 42-10" stroke-dasharray="4 6"></path></svg>
        </div>
        <div>
          <h3>Route + Float Plan Together</h3>
          <p>Your route, timing, vessel, passengers, and safety details stay together in one plan.</p>
        </div>
      </article>

      <article class="fpw-benefit-card">
        <div class="fpw-benefit-card__icon" aria-hidden="true">
          <svg viewBox="0 0 80 70"><circle cx="40" cy="23" r="13"></circle><circle cx="22" cy="31" r="10"></circle><circle cx="58" cy="31" r="10"></circle><path d="M18 61c1-12 8-20 22-20s21 8 22 20M4 61c1-10 7-16 18-16M58 45c11 0 17 6 18 16"></path></svg>
        </div>
        <div>
          <h3>Simple for Non-Boaters</h3>
          <p>Your shore contact gets a simple trip-status page &mdash; no boating knowledge, account, or app required.</p>
        </div>
      </article>

      <article class="fpw-benefit-card">
        <div class="fpw-benefit-card__icon" aria-hidden="true">
          <svg viewBox="0 0 80 70"><path d="M40 12c-12 0-20 10-20 23v10l-7 10h54l-7-10V35c0-13-8-23-20-23ZM33 58c2 5 12 5 14 0M40 7v8"></path></svg>
        </div>
        <div>
          <h3>Live Check-Ins &amp; Delay Updates</h3>
          <p>Keep your shore contact informed when you&rsquo;re on track, delayed, or stopping for the night.</p>
        </div>
      </article>

      <article class="fpw-benefit-card">
        <div class="fpw-benefit-card__icon" aria-hidden="true">
          <svg viewBox="0 0 80 70"><rect x="14" y="16" width="52" height="42" rx="4"></rect><path d="M14 28h52M26 10v12M54 10v12M28 39h.1M40 39h.1M52 39h.1M28 49h.1M40 49h.1M52 49h.1"></path></svg>
        </div>
        <div>
          <h3>One Trip. One Record.</h3>
          <p>Plan before departure, update while underway, and close the trip when you return safely.</p>
        </div>
      </article>
    </div>
  </section>

  <section class="fpw-how-section fpw-faq-section">
    <h2>Frequently Asked Questions</h2>

    <div class="fpw-faq-list" data-fpw-faq>
      <article class="fpw-faq-item">
        <button class="fpw-faq-row" id="fpw-faq-question-what-is-a-float-plan" type="button" aria-expanded="false" aria-controls="fpw-faq-answer-what-is-a-float-plan">
          <span>What is a float plan?</span>
          <span class="fpw-faq-icon" aria-hidden="true">+</span>
        </button>
        <div class="fpw-faq-answer" id="fpw-faq-answer-what-is-a-float-plan" role="region" aria-labelledby="fpw-faq-question-what-is-a-float-plan" hidden>
          <p>A float plan is a written record of your boating trip. It usually includes your vessel information, passengers, departure point, destination, expected return time, route notes, emergency contacts, and instructions for what someone should do if you are overdue.</p>
          <p>FloatPlanWizard helps you create a more organized digital float plan that can be updated and shared with trusted family and friends.</p>
        </div>
      </article>

      <article class="fpw-faq-item">
        <button class="fpw-faq-row" id="fpw-faq-question-what-is-the-floatplanwizard-route-builder" type="button" aria-expanded="false" aria-controls="fpw-faq-answer-what-is-the-floatplanwizard-route-builder">
          <span>How is FloatPlanWizard different from a navigation app?</span>
          <span class="fpw-faq-icon" aria-hidden="true">+</span>
        </button>
        <div class="fpw-faq-answer" id="fpw-faq-answer-what-is-the-floatplanwizard-route-builder" role="region" aria-labelledby="fpw-faq-question-what-is-the-floatplanwizard-route-builder" hidden>
          <p>FloatPlanWizard doesn&rsquo;t replace your chartplotter or navigation app. It organizes your planned route, vessel and passenger information, float plan, shore-contact updates, and trip status in one place.</p>
        </div>
      </article>

      <article class="fpw-faq-item">
        <button class="fpw-faq-row" id="fpw-faq-question-do-my-contacts-need-an-account" type="button" aria-expanded="false" aria-controls="fpw-faq-answer-do-my-contacts-need-an-account">
          <span>Does my shore contact need an account?</span>
          <span class="fpw-faq-icon" aria-hidden="true">+</span>
        </button>
        <div class="fpw-faq-answer" id="fpw-faq-answer-do-my-contacts-need-an-account" role="region" aria-labelledby="fpw-faq-question-do-my-contacts-need-an-account" hidden>
          <p>No. Your shore contact does not need a FloatPlanWizard account to view the trip information you share.</p>
          <p>Only the captain or trip planner needs an account to create, manage, update, and share the float plan.</p>
        </div>
      </article>

      <article class="fpw-faq-item">
        <button class="fpw-faq-row" id="fpw-faq-question-can-i-use-it-for-local-trips" type="button" aria-expanded="false" aria-controls="fpw-faq-answer-can-i-use-it-for-local-trips">
          <span>Can I use it for local trips?</span>
          <span class="fpw-faq-icon" aria-hidden="true">+</span>
        </button>
        <div class="fpw-faq-answer" id="fpw-faq-answer-can-i-use-it-for-local-trips" role="region" aria-labelledby="fpw-faq-question-can-i-use-it-for-local-trips" hidden>
          <p>Yes. FloatPlanWizard works well for local trips because it helps you quickly organize the basic details: where you are leaving from, where you plan to go, who is with you, when you expect to return, and who should know about the trip.</p>
          <p>Local trips are often the ones boaters take casually, which is exactly why having a simple plan can be helpful.</p>
        </div>
      </article>

      <article class="fpw-faq-item">
        <button class="fpw-faq-row" id="fpw-faq-question-what-if-my-plans-change" type="button" aria-expanded="false" aria-controls="fpw-faq-answer-what-if-my-plans-change">
          <span>What if my plans change?</span>
          <span class="fpw-faq-icon" aria-hidden="true">+</span>
        </button>
        <div class="fpw-faq-answer" id="fpw-faq-answer-what-if-my-plans-change" role="region" aria-labelledby="fpw-faq-question-what-if-my-plans-change" hidden>
          <p>You can update your float plan as your trip changes. Adjust your route details, timing, delay information, trip notes, or check-in status so your shared plan stays current.</p>
          <p>If your plans change significantly, update the plan and let your contacts know to check the latest Trip status page.</p>
        </div>
      </article>

      <article class="fpw-faq-item">
        <button class="fpw-faq-row" id="fpw-faq-question-how-much-does-floatplanwizard-cost" type="button" aria-expanded="false" aria-controls="fpw-faq-answer-how-much-does-floatplanwizard-cost">
          <span>How much does FloatPlanWizard cost?</span>
          <span class="fpw-faq-icon" aria-hidden="true">+</span>
        </button>
        <div class="fpw-faq-answer" id="fpw-faq-answer-how-much-does-floatplanwizard-cost" role="region" aria-labelledby="fpw-faq-question-how-much-does-floatplanwizard-cost" hidden>
          <p>Current access options, trial details, and membership pricing are shown on the pricing page. Because offers can change, the pricing page is the best place to confirm the latest details before signing up.</p>
        </div>
      </article>
    </div>

    <div class="fpw-faq-full-link">
      <a class="fpw-btn fpw-btn--secondary" href="<cfoutput>#fpwHowBasePath#/faq/</cfoutput>">View All FAQs</a>
    </div>
  </section>

  <section class="fpw-how-final-cta">
    <div class="fpw-how-final-cta__mark" aria-hidden="true">
      <svg viewBox="0 0 72 72">
        <circle class="fpw-icon-stroke" cx="36" cy="36" r="30" stroke-width="1.4"></circle>
        <path class="fpw-icon-stroke" d="M36 8l8 20 20 8-20 8-8 20-8-20-20-8 20-8z" stroke-width="1.6"></path>
      </svg>
    </div>
    <div>
      <h2>Ready to plan your next trip?</h2>
      <p>Build your route and float plan for free.</p>
    </div>
    <a class="fpw-btn fpw-btn--primary" href="<cfoutput>#fpwHowNotifyUrl#</cfoutput>">
      <span>Start Free</span>
      <svg class="fpw-arrow-icon" viewBox="0 0 24 24" aria-hidden="true">
        <path class="fpw-icon-stroke" d="M5 12h13M13 6l6 6-6 6" stroke-width="2"></path>
      </svg>
    </a>
  </section>
</main>

<script>
  (function () {
    var faqList = document.querySelector("[data-fpw-faq]");
    if (!faqList) {
      return;
    }

    var faqButtons = Array.prototype.slice.call(faqList.querySelectorAll(".fpw-faq-row"));

    function setFaqState(button, isOpen) {
      var panelId = button.getAttribute("aria-controls");
      var panel = panelId ? document.getElementById(panelId) : null;

      button.setAttribute("aria-expanded", isOpen ? "true" : "false");
      if (panel) {
        panel.hidden = !isOpen;
      }
    }

    faqButtons.forEach(function (button) {
      button.addEventListener("click", function () {
        var shouldOpen = button.getAttribute("aria-expanded") !== "true";

        faqButtons.forEach(function (otherButton) {
          setFaqState(otherButton, false);
        });
        setFaqState(button, shouldOpen);
      });

      button.addEventListener("keydown", function (event) {
        if (event.key !== "Enter" && event.key !== " " && event.key !== "Spacebar") {
          return;
        }

        event.preventDefault();
        button.click();
      });
    });
  })();
</script>

<cfinclude template="includes/footer.cfm">
</body>
</html>
