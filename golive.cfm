<cfsetting showdebugoutput="false">
<cfparam name="url.email" default="">

<!---
  FloatPlanWizard Go-Live Homepage Standalone CFM
  Includes: CFML configuration/data, HTML, CSS, and JavaScript in one file.

  Install suggestion:
  - Save as /app/home.cfm or /index.cfm after adapting route constants below.
  - Replace placeholder signup/login/pricing paths with your production routes.
  - Replace premiumPriceLabel once membership pricing is final.
--->

<cfscript>
pageTitle = "FloatPlanWizard | Plan Smarter. Cruise Prepared.";
pageDescription = "FloatPlanWizard helps recreational boaters create float plans, build routes, monitor active trips, and share private voyage updates with family and friends.";
siteName = "FloatPlanWizard";
siteTagline = "Built for serious recreational boaters";
launchLabel = "FloatPlanWizard is live";
currentYear = year(now());
prefillEmail = trim(url.email);

// Route constants. Update these to match your real FPW routes.
signupUrl = "/signup.cfm";
loginUrl = "/login.cfm";
pricingUrl = "/pricing.cfm";
featuresUrl = "##features";
greatLoopUrl = "##great-loop";
activeCruiseUrl = "##active-cruise";
companionUrl = "##companion-app";
howItWorksUrl = "##how-it-works";
shareTripUrl = "##share-the-trip";
subscribeUrl = "/subscribe.cfm";

// Update this once pricing is final.
premiumPriceLabel = "Premium";
premiumPriceSuffix = "membership";

navItems = [
  { label = "Features", href = featuresUrl },
  { label = "Great Loop", href = greatLoopUrl },
  { label = "Active Cruise", href = activeCruiseUrl },
  { label = "Companion App", href = companionUrl },
  { label = "Pricing", href = pricingUrl },
  { label = "How It Works", href = howItWorksUrl }
];

heroBullets = [
  "Create clear float plans with vessel, route, timing, passenger, and emergency details.",
  "Plan route legs, fuel stops, timing, overnight stops, and contingencies confidently.",
  "Keep trusted contacts informed with private shared trip pages and progress updates.",
  "Use active cruise monitoring, check-ins, and overdue alert workflows when underway."
];

heroMiniCards = [
  { icon = "◉", title = "Float Plans", body = "USCG-style float plans with organized trip details and monitoring-ready structure." },
  { icon = "⌘", title = "Route Builder", body = "Plan legs, pace, stops, timing, and fuel with tools built for real cruising." },
  { icon = "≋", title = "Share the Trip", body = "Let family and friends follow the plan, stops, and updates without scattered texts." }
];

freePlanFeatures = [
  "1 active route",
  "1 float plan",
  "Basic trip sharing",
  "Route planning tools",
  "Check-ins and monitoring basics",
  "Email support"
];

premiumPlanFeatures = [
  "Unlimited routes and float plans",
  "Advanced monitoring and alerts",
  "Companion app features",
  "Great Loop planning tools",
  "Weather and fuel planning",
  "Priority support"
];

memberFitItems = [
  { icon = "≋", body = "Cruise the ICW, inland rivers, coastal waters, or the Great Loop." },
  { icon = "⚓", body = "Plan day trips, overnights, weekend runs, and longer passages." },
  { icon = "⌬", body = "Want fuel, timing, route, stop, and check-in details organized before departure." },
  { icon = "👥", body = "Want family and friends to understand the trip without constant texting." },
  { icon = "♢", body = "Value preparation, safety, communication, and peace of mind." }
];

featureCards = [
  { icon = "◉", title = "Smart Float Plans", body = "Create organized float plans with vessel information, contacts, timing, route details, passengers, and emergency context." },
  { icon = "⌘", title = "Route Builder", body = "Build route legs, organize stops, estimate timing, plan fuel needs, and visualize your trip before leaving the dock." },
  { icon = "◎", title = "Active Cruise Monitoring", body = "Use check-ins, delays, secure-for-night status, monitoring checkpoints, and trip status updates while underway." },
  { icon = "👥", title = "Share the Trip", body = "Give family and friends a private shared trip page with the planned route, key stops, and progress updates." },
  { icon = "▯", title = "Companion App", body = "Check in from the boat, send GPS-aware updates, secure for the night, and keep monitoring data current." },
  { icon = "⌬", title = "Great Loop Tools", body = "Use planning tools for long-distance route segments, lock timing, fuel range, overnight stops, and shared progress." },
  { icon = "☼", title = "Weather-Aware Timing", body = "Plan departure timing around weather windows, fronts, wind, seas, and day-to-day cruising conditions." },
  { icon = "▣", title = "Fuel Planning", body = "Estimate distance, fuel range, refill timing, stop spacing, and leg-by-leg fuel confidence before departure." },
  { icon = "⚓", title = "Lock & Leg Organization", body = "Keep lock sequences, wait windows, bridges, marinas, anchorages, and route notes organized by leg." },
  { icon = "☾", title = "Overnight & Resume", body = "Secure for the night, preserve trip context, and resume next-day monitoring without rebuilding the voyage." },
  { icon = "✓", title = "Check-Ins & Status Updates", body = "Record on-track status, delays, assistance-needed signals, and other updates during the active trip." },
  { icon = "✉", title = "Contacts & Emergency Details", body = "Keep trusted contacts, vessel details, itinerary context, and important trip information together." }
];

greatLoopFeatures = [
  "Great Loop route templates",
  "Leg-by-leg planning with clarity",
  "Lock sequencing and wait-window notes",
  "Fuel planning and range tracking",
  "Overnight stops and secure-for-night workflows",
  "Shared progress with crew, family, and friends"
];

companionFeatures = [
  "One-tap check-ins",
  "GPS location and timestamp updates",
  "Secure-for-night updates",
  "Delay or change-plan updates",
  "Works with weak-connectivity workflows"
];

shareFeatures = [
  "Private trip page",
  "Real-time progress updates",
  "Planned route and key stops",
  "Check-in history",
  "Secure and private access",
  "No app required for followers"
];

familyItems = [
  { letter = "A", title = "Planned route and key stops", body = "Clear trip structure instead of scattered updates." },
  { letter = "B", title = "Trip context at a glance", body = "Departure, destination, timing, and important voyage information in one place." },
  { letter = "C", title = "Better confidence for loved ones", body = "A simple shareable experience designed to reduce uncertainty during the trip." },
  { letter = "D", title = "Ideal for longer journeys", body = "Especially valuable for Loopers and serious cruisers covering a lot of water." }
];

footerProductLinks = [
  { label = "Features", href = featuresUrl },
  { label = "Companion App", href = companionUrl },
  { label = "Pricing", href = pricingUrl },
  { label = "How It Works", href = howItWorksUrl }
];

footerResourceLinks = [
  { label = "Help Center", href = "/help.cfm" },
  { label = "Blog", href = "/blog.cfm" },
  { label = "Great Loop Guide", href = greatLoopUrl },
  { label = "FAQ", href = "/faq.cfm" }
];

footerCompanyLinks = [
  { label = "About Us", href = "/about.cfm" },
  { label = "Contact", href = "/contact.cfm" },
  { label = "Privacy Policy", href = "/privacy.cfm" },
  { label = "Terms of Service", href = "/terms.cfm" }
];
</cfscript>

<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <cfoutput>
    <title>#encodeForHTML(pageTitle)#</title>
    <meta name="description" content="#encodeForHTMLAttribute(pageDescription)#">
  </cfoutput>
  <meta name="theme-color" content="#06131b">

  <style>
    :root {
      --fpw-bg: #06131b;
      --fpw-bg-deep: #041018;
      --fpw-bg-soft: #0a1c29;
      --fpw-bg-card: rgba(14, 37, 52, 0.78);
      --fpw-bg-card-strong: rgba(18, 48, 67, 0.9);
      --fpw-border: rgba(114, 213, 236, 0.18);
      --fpw-border-strong: rgba(44, 236, 221, 0.42);
      --fpw-text: #f2fbff;
      --fpw-muted: #a5bdd1;
      --fpw-muted-2: #7894a9;
      --fpw-cyan: #2beee3;
      --fpw-blue: #44c7ff;
      --fpw-green: #66f2b0;
      --fpw-yellow: #ffd55c;
      --fpw-red: #ff6f7d;
      --fpw-shadow: 0 24px 70px rgba(0, 0, 0, 0.42);
      --fpw-glow: 0 0 44px rgba(43, 238, 227, 0.18);
      --fpw-radius-xs: 10px;
      --fpw-radius-sm: 14px;
      --fpw-radius-md: 20px;
      --fpw-radius-lg: 28px;
      --fpw-container: 1180px;
      --fpw-header-height: 82px;
      --fpw-font: Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
    }

    * {
      box-sizing: border-box;
    }

    html {
      scroll-behavior: smooth;
    }

    body {
      margin: 0;
      min-width: 320px;
      font-family: var(--fpw-font);
      color: var(--fpw-text);
      background:
        radial-gradient(circle at 18% 12%, rgba(43, 238, 227, 0.11), transparent 30%),
        radial-gradient(circle at 80% 8%, rgba(68, 199, 255, 0.12), transparent 27%),
        radial-gradient(circle at 42% 62%, rgba(43, 238, 227, 0.08), transparent 36%),
        linear-gradient(180deg, #05121a 0%, #06131b 42%, #041019 100%);
      line-height: 1.55;
      overflow-x: hidden;
    }

    body::before {
      content: "";
      position: fixed;
      inset: 0;
      pointer-events: none;
      background:
        linear-gradient(rgba(255, 255, 255, 0.022) 1px, transparent 1px),
        linear-gradient(90deg, rgba(255, 255, 255, 0.018) 1px, transparent 1px);
      background-size: 72px 72px;
      mask-image: linear-gradient(to bottom, rgba(0,0,0,0.7), transparent 72%);
      z-index: -1;
    }

    a {
      color: inherit;
      text-decoration: none;
    }

    a:focus-visible,
    button:focus-visible,
    input:focus-visible {
      outline: 3px solid rgba(43, 238, 227, 0.75);
      outline-offset: 3px;
    }

    img,
    svg {
      display: block;
      max-width: 100%;
    }

    button,
    input {
      font: inherit;
    }

    button {
      cursor: pointer;
    }

    .fpw-sr-only {
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

    .fpw-container {
      width: min(calc(100% - 32px), var(--fpw-container));
      margin-inline: auto;
    }

    .fpw-skip-link {
      position: absolute;
      left: 16px;
      top: 16px;
      z-index: 1000;
      transform: translateY(-140%);
      padding: 10px 14px;
      border-radius: 999px;
      background: var(--fpw-cyan);
      color: #041018;
      font-weight: 900;
      transition: transform 180ms ease;
    }

    .fpw-skip-link:focus {
      transform: translateY(0);
    }

    .fpw-top-offer {
      border-bottom: 1px solid var(--fpw-border);
      background: rgba(3, 15, 23, 0.72);
      backdrop-filter: blur(18px);
    }

    .fpw-top-offer__inner {
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 14px;
      min-height: 42px;
      font-size: 0.88rem;
      color: var(--fpw-muted);
      text-align: center;
    }

    .fpw-top-offer__eyebrow {
      display: inline-flex;
      align-items: center;
      gap: 7px;
      color: var(--fpw-green);
      font-weight: 900;
      letter-spacing: 0.08em;
      text-transform: uppercase;
    }

    .fpw-top-offer__eyebrow::before {
      content: "";
      width: 8px;
      height: 8px;
      border-radius: 999px;
      background: var(--fpw-green);
      box-shadow: 0 0 18px rgba(102, 242, 176, 0.85);
    }

    .fpw-top-offer__link {
      color: var(--fpw-cyan);
      font-weight: 800;
      white-space: nowrap;
    }

    .fpw-header {
      position: sticky;
      top: 0;
      z-index: 50;
      min-height: var(--fpw-header-height);
      border-bottom: 1px solid var(--fpw-border);
      background: rgba(4, 16, 24, 0.82);
      backdrop-filter: blur(22px);
      transition: box-shadow 200ms ease, background 200ms ease;
    }

    .fpw-header.is-scrolled {
      background: rgba(4, 16, 24, 0.94);
      box-shadow: 0 18px 50px rgba(0,0,0,0.3);
    }

    .fpw-header__inner {
      min-height: var(--fpw-header-height);
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 24px;
    }

    .fpw-brand {
      display: inline-flex;
      align-items: center;
      gap: 12px;
      min-width: max-content;
    }

    .fpw-brand__mark {
      width: 44px;
      height: 44px;
      display: grid;
      place-items: center;
      border: 1px solid rgba(43, 238, 227, 0.45);
      border-radius: 50%;
      color: var(--fpw-cyan);
      font-size: 1.8rem;
      line-height: 1;
      box-shadow: inset 0 0 18px rgba(43, 238, 227, 0.12), 0 0 24px rgba(43, 238, 227, 0.12);
    }

    .fpw-brand__text {
      display: grid;
      line-height: 1.1;
    }

    .fpw-brand__text strong {
      font-size: clamp(1.45rem, 2vw, 2.15rem);
      letter-spacing: -0.06em;
    }

    .fpw-brand__text small {
      margin-top: 4px;
      color: var(--fpw-cyan);
      font-size: 0.69rem;
      font-weight: 900;
      letter-spacing: 0.22em;
      text-transform: uppercase;
    }

    .fpw-nav {
      display: flex;
      align-items: center;
      gap: clamp(14px, 2vw, 28px);
      color: rgba(242, 251, 255, 0.86);
      font-weight: 800;
      font-size: 0.95rem;
    }

    .fpw-nav a {
      position: relative;
      padding-block: 10px;
    }

    .fpw-nav a::after {
      content: "";
      position: absolute;
      left: 0;
      right: 0;
      bottom: 4px;
      height: 2px;
      transform: scaleX(0);
      transform-origin: left;
      background: linear-gradient(90deg, var(--fpw-cyan), var(--fpw-blue));
      transition: transform 160ms ease;
    }

    .fpw-nav a:hover::after,
    .fpw-nav a:focus-visible::after {
      transform: scaleX(1);
    }

    .fpw-header__actions {
      display: flex;
      align-items: center;
      gap: 10px;
    }

    .fpw-menu-btn {
      display: none;
      width: 44px;
      height: 44px;
      align-items: center;
      justify-content: center;
      border: 1px solid var(--fpw-border);
      border-radius: 14px;
      color: var(--fpw-text);
      background: rgba(255, 255, 255, 0.04);
      font-weight: 900;
    }

    .fpw-mobile-nav {
      display: none;
      border-top: 1px solid var(--fpw-border);
      background: rgba(4, 16, 24, 0.98);
    }

    .fpw-mobile-nav__inner {
      display: grid;
      gap: 8px;
      padding: 14px 0 18px;
    }

    .fpw-mobile-nav a {
      padding: 12px 14px;
      border: 1px solid var(--fpw-border);
      border-radius: 14px;
      background: rgba(255,255,255,0.03);
      color: var(--fpw-muted);
      font-weight: 800;
    }

    .fpw-btn {
      display: inline-flex;
      align-items: center;
      justify-content: center;
      gap: 9px;
      min-height: 46px;
      padding: 0 20px;
      border: 1px solid transparent;
      border-radius: 14px;
      font-weight: 900;
      line-height: 1;
      transition: transform 160ms ease, border-color 160ms ease, background 160ms ease, box-shadow 160ms ease;
      white-space: nowrap;
    }

    .fpw-btn:hover {
      transform: translateY(-1px);
    }

    .fpw-btn--primary {
      color: #03151c;
      background: linear-gradient(135deg, var(--fpw-cyan), var(--fpw-blue));
      box-shadow: 0 16px 32px rgba(43, 238, 227, 0.18);
    }

    .fpw-btn--secondary {
      color: var(--fpw-text);
      border-color: var(--fpw-border-strong);
      background: rgba(255, 255, 255, 0.04);
    }

    .fpw-btn--secondary:hover {
      background: rgba(43, 238, 227, 0.08);
    }

    .fpw-btn--ghost {
      color: var(--fpw-text);
      border-color: var(--fpw-border);
      background: rgba(255,255,255,0.03);
    }

    .fpw-btn--accent {
      color: #07131a;
      background: linear-gradient(135deg, #ffe27d, #ffb84d);
      box-shadow: 0 16px 32px rgba(255, 213, 92, 0.14);
    }

    .fpw-btn--text {
      min-height: 44px;
      padding-inline: 0;
      color: var(--fpw-cyan);
      background: transparent;
    }

    .fpw-btn--small {
      min-height: 40px;
      padding-inline: 16px;
      border-radius: 12px;
      font-size: 0.9rem;
    }

    .fpw-btn--full {
      width: 100%;
    }

    .fpw-hero,
    .fpw-membership,
    .fpw-features,
    .fpw-great-loop,
    .fpw-live-tools,
    .fpw-family,
    .fpw-founder-cta,
    .fpw-bottom-cta {
      scroll-margin-top: 110px;
    }

    .fpw-hero {
      padding: clamp(42px, 6vw, 82px) 0 30px;
    }

    .fpw-hero__grid {
      display: grid;
      grid-template-columns: minmax(0, 0.94fr) minmax(420px, 1.06fr);
      gap: clamp(28px, 5vw, 60px);
      align-items: center;
    }

    .fpw-status-pill,
    .fpw-section-kicker {
      display: inline-flex;
      align-items: center;
      gap: 8px;
      width: fit-content;
      min-height: 34px;
      padding: 0 14px;
      border: 1px solid rgba(102, 242, 176, 0.26);
      border-radius: 999px;
      color: var(--fpw-green);
      background: rgba(102, 242, 176, 0.08);
      font-size: 0.78rem;
      font-weight: 950;
      letter-spacing: 0.13em;
      text-transform: uppercase;
    }

    .fpw-status-pill__dot {
      width: 8px;
      height: 8px;
      border-radius: 50%;
      background: var(--fpw-green);
      box-shadow: 0 0 18px rgba(102, 242, 176, 0.88);
    }

    .fpw-section-kicker {
      min-height: auto;
      padding: 0;
      border: 0;
      background: transparent;
      color: var(--fpw-cyan);
    }

    .fpw-hero h1 {
      margin: 24px 0 18px;
      font-size: clamp(3.1rem, 6.9vw, 6.5rem);
      line-height: 0.93;
      letter-spacing: -0.075em;
      text-wrap: balance;
    }

    .fpw-hero h1 span {
      color: var(--fpw-cyan);
      text-shadow: 0 0 28px rgba(43, 238, 227, 0.22);
    }

    .fpw-hero__lead {
      max-width: 660px;
      margin: 0 0 18px;
      color: var(--fpw-muted);
      font-size: 1.1rem;
    }

    .fpw-hero__bullets {
      display: grid;
      gap: 9px;
      margin: 0 0 24px;
      padding: 0;
      color: var(--fpw-muted);
      list-style: none;
      font-size: 1rem;
    }

    .fpw-hero__bullets li {
      position: relative;
      padding-left: 24px;
    }

    .fpw-hero__bullets li::before {
      content: "";
      position: absolute;
      left: 2px;
      top: 0.72em;
      width: 6px;
      height: 6px;
      border-radius: 50%;
      background: var(--fpw-blue);
      box-shadow: 0 0 12px rgba(68, 199, 255, 0.7);
    }

    .fpw-hero__cards {
      display: grid;
      grid-template-columns: repeat(3, minmax(0, 1fr));
      gap: 14px;
      margin: 24px 0;
    }

    .fpw-mini-card,
    .fpw-feature-card,
    .fpw-plan-card,
    .fpw-member-fit-card,
    .fpw-command-card,
    .fpw-loop-panel,
    .fpw-companion-panel,
    .fpw-share-panel,
    .fpw-family__copy,
    .fpw-family__details,
    .fpw-founder-cta__grid,
    .fpw-bottom-cta__inner,
    .fpw-footer {
      border: 1px solid var(--fpw-border);
      background: linear-gradient(145deg, rgba(13, 34, 49, 0.88), rgba(8, 23, 34, 0.82));
      box-shadow: var(--fpw-shadow);
    }

    .fpw-mini-card {
      padding: 18px;
      border-radius: 18px;
    }

    .fpw-mini-card__icon,
    .fpw-feature-card__icon,
    .fpw-plan-card__icon {
      width: 42px;
      height: 42px;
      display: grid;
      place-items: center;
      margin-bottom: 14px;
      border: 1px solid rgba(43, 238, 227, 0.28);
      border-radius: 14px;
      color: var(--fpw-cyan);
      background: rgba(43, 238, 227, 0.1);
      font-weight: 900;
    }

    .fpw-mini-card h2,
    .fpw-feature-card h3,
    .fpw-plan-card h3,
    .fpw-member-fit-card h3,
    .fpw-companion-panel h3,
    .fpw-share-panel h3,
    .fpw-family__details h3,
    .fpw-final-signup-card h3 {
      margin: 0 0 8px;
      font-size: 1.05rem;
      letter-spacing: -0.03em;
    }

    .fpw-mini-card p,
    .fpw-feature-card p,
    .fpw-plan-card p,
    .fpw-member-fit-card p,
    .fpw-companion-panel p,
    .fpw-share-panel p,
    .fpw-family__details p,
    .fpw-final-signup-card p {
      margin: 0;
      color: var(--fpw-muted);
    }

    .fpw-hero__cta {
      display: flex;
      flex-wrap: wrap;
      align-items: center;
      gap: 12px;
      margin-top: 22px;
    }

    .fpw-trust-row {
      display: flex;
      flex-wrap: wrap;
      gap: 14px 24px;
      margin-top: 22px;
      color: var(--fpw-muted);
      font-size: 0.92rem;
      font-weight: 750;
    }

    .fpw-trust-row span {
      display: inline-flex;
      align-items: center;
      gap: 8px;
    }

    .fpw-trust-row i {
      width: 20px;
      height: 20px;
      display: grid;
      place-items: center;
      border-radius: 50%;
      color: var(--fpw-green);
      background: rgba(102, 242, 176, 0.1);
      font-style: normal;
      font-size: 0.75rem;
    }

    .fpw-command-shell {
      position: relative;
    }

    .fpw-command-shell::before {
      content: "";
      position: absolute;
      inset: -32px;
      z-index: -1;
      background: radial-gradient(circle at 50% 42%, rgba(43, 238, 227, 0.18), transparent 62%);
      filter: blur(5px);
    }

    .fpw-command-window {
      border: 1px solid rgba(114, 213, 236, 0.22);
      border-radius: var(--fpw-radius-lg);
      overflow: hidden;
      background: linear-gradient(145deg, rgba(8, 24, 35, 0.96), rgba(4, 15, 23, 0.96));
      box-shadow: var(--fpw-shadow), var(--fpw-glow);
    }

    .fpw-command-window__top {
      min-height: 64px;
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 16px;
      padding: 18px 20px;
      border-bottom: 1px solid var(--fpw-border);
      color: var(--fpw-muted);
    }

    .fpw-window-dots {
      display: flex;
      gap: 8px;
    }

    .fpw-window-dots span {
      width: 11px;
      height: 11px;
      border-radius: 50%;
      background: rgba(165, 189, 209, 0.28);
    }

    .fpw-live-indicator {
      display: inline-flex;
      align-items: center;
      gap: 8px;
      color: var(--fpw-text);
      font-size: 0.82rem;
      font-weight: 850;
    }

    .fpw-live-indicator i {
      width: 8px;
      height: 8px;
      border-radius: 50%;
      background: var(--fpw-green);
      box-shadow: 0 0 16px rgba(102,242,176,0.85);
    }

    .fpw-command-grid {
      display: grid;
      grid-template-columns: repeat(4, minmax(0, 1fr));
      gap: 14px;
      padding: 20px;
    }

    .fpw-command-card {
      position: relative;
      min-height: 112px;
      padding: 16px;
      border-radius: 16px;
      background: rgba(14, 37, 52, 0.72);
      box-shadow: none;
    }

    .fpw-command-card--wide,
    .fpw-command-card--status {
      grid-column: span 2;
      min-height: 154px;
    }

    .fpw-command-card strong,
    .fpw-command-card b {
      display: block;
      color: var(--fpw-text);
      font-size: 1.05rem;
      letter-spacing: -0.02em;
    }

    .fpw-command-card b {
      margin-top: 4px;
      font-size: 2rem;
      line-height: 1;
    }

    .fpw-command-card span,
    .fpw-card-meta {
      color: var(--fpw-muted);
      font-size: 0.86rem;
    }

    .fpw-command-card em {
      display: inline-block;
      margin-top: 10px;
      color: var(--fpw-green);
      font-style: normal;
      font-size: 0.82rem;
      font-weight: 900;
    }

    .fpw-card-kicker {
      margin-bottom: 10px;
      color: var(--fpw-muted);
      font-size: 0.72rem;
      font-weight: 950;
      letter-spacing: 0.12em;
      text-transform: uppercase;
    }

    .fpw-progress {
      height: 8px;
      margin: 18px 0 10px;
      overflow: hidden;
      border-radius: 999px;
      background: rgba(165, 189, 209, 0.16);
    }

    .fpw-progress span {
      display: block;
      height: 100%;
      border-radius: inherit;
      background: linear-gradient(90deg, var(--fpw-cyan), var(--fpw-blue));
      box-shadow: 0 0 18px rgba(43, 238, 227, 0.28);
    }

    .fpw-card-meta {
      display: flex;
      justify-content: space-between;
      gap: 12px;
    }

    .fpw-status-value {
      color: var(--fpw-green) !important;
      text-transform: uppercase;
    }

    .fpw-radar {
      position: absolute;
      right: 22px;
      top: 34px;
      width: 86px;
      height: 86px;
      border: 1px solid rgba(43, 238, 227, 0.4);
      border-radius: 50%;
      background:
        radial-gradient(circle, rgba(43,238,227,0.24) 0 4px, transparent 5px),
        repeating-radial-gradient(circle, rgba(43,238,227,0.17) 0 1px, transparent 1px 21px);
    }

    .fpw-radar span {
      position: absolute;
      left: 50%;
      top: 50%;
      width: 50%;
      height: 2px;
      transform-origin: left center;
      background: linear-gradient(90deg, var(--fpw-cyan), transparent);
      animation: fpwRadar 4.2s linear infinite;
    }

    @keyframes fpwRadar {
      from { transform: rotate(0deg); }
      to { transform: rotate(360deg); }
    }

    .fpw-command-footer {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 14px;
      padding: 14px 20px 18px;
      border-top: 1px solid var(--fpw-border);
      color: var(--fpw-muted);
      font-size: 0.84rem;
    }

    .fpw-command-footer strong {
      color: var(--fpw-green);
    }

    section:not(.fpw-hero) {
      padding: 34px 0;
    }

    .fpw-section-header {
      max-width: 820px;
      margin-bottom: 24px;
    }

    .fpw-section-header--split {
      display: flex;
      align-items: end;
      justify-content: space-between;
      gap: 28px;
      max-width: none;
    }

    .fpw-section-header h2,
    .fpw-great-loop__copy h2,
    .fpw-family h2,
    .fpw-founder-cta h2,
    .fpw-bottom-cta h2 {
      margin: 10px 0 10px;
      font-size: clamp(2rem, 4.2vw, 4.25rem);
      line-height: 0.98;
      letter-spacing: -0.07em;
      text-wrap: balance;
    }

    .fpw-section-header p,
    .fpw-great-loop__copy p,
    .fpw-family__copy > p,
    .fpw-founder-cta p,
    .fpw-bottom-cta p {
      margin: 0;
      color: var(--fpw-muted);
      font-size: 1.05rem;
    }

    .fpw-section-note {
      color: var(--fpw-muted-2);
      font-weight: 800;
      white-space: nowrap;
    }

    .fpw-membership__grid {
      display: grid;
      grid-template-columns: minmax(0, 1fr) minmax(0, 1fr) minmax(280px, 0.9fr);
      gap: 18px;
    }

    .fpw-plan-card,
    .fpw-member-fit-card {
      min-height: 100%;
      padding: 24px;
      border-radius: var(--fpw-radius-md);
    }

    .fpw-plan-card--free {
      border-color: rgba(43, 238, 227, 0.38);
    }

    .fpw-plan-card--premium {
      border-color: rgba(255, 213, 92, 0.32);
    }

    .fpw-plan-card__top {
      display: flex;
      align-items: flex-start;
      gap: 14px;
      margin-bottom: 18px;
    }

    .fpw-plan-card__top .fpw-plan-card__icon {
      flex: 0 0 auto;
      margin: 0;
    }

    .fpw-plan-card--premium .fpw-plan-card__icon {
      color: var(--fpw-yellow);
      border-color: rgba(255, 213, 92, 0.26);
      background: rgba(255, 213, 92, 0.09);
    }

    .fpw-check-list,
    .fpw-icon-list {
      display: grid;
      gap: 10px;
      margin: 0;
      padding: 0;
      list-style: none;
      color: var(--fpw-muted);
    }

    .fpw-check-list li {
      position: relative;
      padding-left: 26px;
    }

    .fpw-check-list li::before {
      content: "✓";
      position: absolute;
      left: 0;
      top: 0.05em;
      color: var(--fpw-green);
      font-weight: 950;
    }

    .fpw-check-list--large {
      gap: 13px;
      margin: 22px 0 26px;
      font-size: 1rem;
    }

    .fpw-plan-card__price {
      display: flex;
      align-items: baseline;
      gap: 6px;
      margin: 24px 0 16px;
    }

    .fpw-plan-card__price strong {
      font-size: 2rem;
      letter-spacing: -0.05em;
    }

    .fpw-plan-card__price span {
      color: var(--fpw-muted);
    }

    .fpw-icon-list li {
      display: grid;
      grid-template-columns: 34px 1fr;
      gap: 12px;
      align-items: start;
    }

    .fpw-icon-list span {
      width: 34px;
      height: 34px;
      display: grid;
      place-items: center;
      border-radius: 12px;
      color: var(--fpw-cyan);
      background: rgba(43,238,227,0.09);
    }

    .fpw-feature-grid {
      display: grid;
      grid-template-columns: repeat(4, minmax(0, 1fr));
      gap: 16px;
    }

    .fpw-feature-card {
      min-height: 220px;
      padding: 24px;
      border-radius: var(--fpw-radius-md);
      transition: transform 160ms ease, border-color 160ms ease, background 160ms ease;
    }

    .fpw-feature-card:hover {
      transform: translateY(-3px);
      border-color: rgba(43, 238, 227, 0.34);
      background: linear-gradient(145deg, rgba(17, 45, 63, 0.94), rgba(8, 23, 34, 0.9));
    }

    .fpw-great-loop__grid,
    .fpw-family__grid,
    .fpw-founder-cta__grid {
      display: grid;
      grid-template-columns: minmax(0, 0.9fr) minmax(420px, 1.1fr);
      gap: 24px;
      align-items: stretch;
    }

    .fpw-great-loop__copy,
    .fpw-family__copy,
    .fpw-family__details {
      padding: clamp(26px, 4vw, 44px);
      border-radius: var(--fpw-radius-lg);
      border: 1px solid var(--fpw-border);
      background: linear-gradient(145deg, rgba(13, 34, 49, 0.88), rgba(8, 23, 34, 0.82));
      box-shadow: var(--fpw-shadow);
    }

    .fpw-loop-panel {
      display: grid;
      grid-template-columns: 1fr 170px;
      gap: 0;
      overflow: hidden;
      border-radius: var(--fpw-radius-lg);
    }

    .fpw-loop-map {
      min-height: 420px;
      padding: 24px;
      background: rgba(255,255,255,0.025);
    }

    .fpw-loop-map svg {
      width: 100%;
      height: 100%;
      min-height: 360px;
      border-radius: 24px;
      overflow: hidden;
      background: #0a1d2b;
    }

    .fpw-loop-map rect {
      fill: #102b3c;
    }

    .fpw-map-land {
      fill: #17364a;
      stroke: rgba(165, 189, 209, 0.14);
      stroke-width: 2;
    }

    .fpw-map-route {
      fill: none;
      stroke: url(#unused);
      stroke: var(--fpw-cyan);
      stroke-width: 7;
      stroke-linecap: round;
      stroke-linejoin: round;
      filter: drop-shadow(0 0 10px rgba(43,238,227,0.7));
      stroke-dasharray: 900;
      animation: fpwDrawRoute 9s ease-in-out infinite alternate;
    }

    @keyframes fpwDrawRoute {
      from { stroke-dashoffset: 260; }
      to { stroke-dashoffset: 0; }
    }

    .fpw-map-pins circle {
      fill: var(--fpw-cyan);
      stroke: rgba(255,255,255,0.8);
      stroke-width: 3;
    }

    .fpw-loop-map text {
      fill: rgba(242,251,255,0.86);
      font-size: 18px;
      font-weight: 800;
    }

    .fpw-loop-stats {
      display: grid;
      align-content: stretch;
      border-left: 1px solid var(--fpw-border);
    }

    .fpw-loop-stats article {
      padding: 22px;
      border-bottom: 1px solid var(--fpw-border);
    }

    .fpw-loop-stats article:last-child {
      border-bottom: 0;
    }

    .fpw-loop-stats strong {
      display: block;
      color: var(--fpw-cyan);
      font-size: 1.35rem;
      letter-spacing: -0.04em;
    }

    .fpw-loop-stats span {
      display: block;
      margin-top: 4px;
      color: var(--fpw-muted);
      font-size: 0.85rem;
    }

    .fpw-loop-feature-list {
      grid-column: 1 / -1;
      display: grid;
      grid-template-columns: repeat(2, minmax(0, 1fr));
      gap: 12px;
      padding: 20px 24px 24px;
      border-top: 1px solid var(--fpw-border);
    }

    .fpw-loop-feature-list p {
      margin: 0;
      padding: 14px;
      border: 1px solid rgba(114, 213, 236, 0.12);
      border-radius: 14px;
      color: var(--fpw-muted);
      background: rgba(255,255,255,0.025);
    }

    .fpw-loop-feature-list strong {
      color: var(--fpw-text);
    }

    .fpw-live-tools__grid {
      display: grid;
      grid-template-columns: minmax(0, 1fr) minmax(0, 1fr);
      gap: 18px;
    }

    .fpw-companion-panel,
    .fpw-share-panel {
      display: grid;
      grid-template-columns: 210px 1fr;
      gap: 26px;
      min-height: 360px;
      padding: 26px;
      border-radius: var(--fpw-radius-lg);
      align-items: center;
    }

    .fpw-share-panel {
      grid-template-columns: 1fr 260px;
    }

    .fpw-phone-preview {
      width: 190px;
      margin-inline: auto;
      padding: 12px;
      border: 1px solid rgba(242,251,255,0.18);
      border-radius: 34px;
      background: #041018;
      box-shadow: 0 22px 60px rgba(0,0,0,0.52);
    }

    .fpw-phone-preview__screen {
      min-height: 320px;
      display: grid;
      gap: 12px;
      align-content: start;
      padding: 22px 16px;
      border-radius: 24px;
      background: linear-gradient(180deg, #082337, #071824);
      text-align: center;
    }

    .fpw-phone-preview__top {
      color: var(--fpw-muted);
      font-size: 0.75rem;
      font-weight: 850;
    }

    .fpw-phone-preview__check {
      width: 76px;
      height: 76px;
      display: grid;
      place-items: center;
      margin: 16px auto 2px;
      border-radius: 50%;
      color: #06131b;
      background: linear-gradient(135deg, var(--fpw-green), var(--fpw-cyan));
      font-size: 2.3rem;
      font-weight: 950;
      box-shadow: 0 0 30px rgba(43,238,227,0.32);
    }

    .fpw-phone-preview__screen strong {
      line-height: 1.15;
    }

    .fpw-phone-preview__screen > span:not(.fpw-phone-preview__top) {
      color: var(--fpw-muted);
      font-size: 0.78rem;
    }

    .fpw-phone-preview__row {
      display: flex;
      justify-content: space-between;
      gap: 12px;
      padding: 10px 0;
      border-top: 1px solid rgba(114,213,236,0.15);
      color: var(--fpw-muted);
      font-size: 0.78rem;
    }

    .fpw-phone-preview__row strong {
      color: var(--fpw-text);
    }

    .fpw-phone-preview button {
      min-height: 42px;
      border: 1px solid rgba(43,238,227,0.52);
      border-radius: 12px;
      color: var(--fpw-cyan);
      background: rgba(43,238,227,0.06);
      font-weight: 900;
    }

    .fpw-companion-panel .fpw-check-list,
    .fpw-share-panel .fpw-check-list {
      margin: 18px 0 22px;
    }

    .fpw-shared-trip-card {
      padding: 18px;
      border: 1px solid var(--fpw-border);
      border-radius: 20px;
      background: rgba(5,17,26,0.55);
    }

    .fpw-shared-trip-card__top {
      display: flex;
      align-items: center;
      gap: 12px;
      margin-bottom: 16px;
    }

    .fpw-shared-trip-card__top > span {
      width: 42px;
      height: 42px;
      display: grid;
      place-items: center;
      border-radius: 14px;
      color: var(--fpw-cyan);
      background: rgba(43,238,227,0.1);
    }

    .fpw-shared-trip-card__top small,
    .fpw-shared-trip-card__body span {
      display: block;
      color: var(--fpw-muted);
    }

    .fpw-shared-trip-card__body {
      padding: 14px;
      margin-bottom: 16px;
      border: 1px solid rgba(114,213,236,0.12);
      border-radius: 14px;
      color: var(--fpw-muted);
      background: rgba(255,255,255,0.025);
    }

    .fpw-shared-trip-card__body p {
      margin-bottom: 6px;
    }

    .fpw-family__grid {
      grid-template-columns: minmax(0, 1.05fr) minmax(360px, 0.95fr);
    }

    .fpw-quote-grid {
      display: grid;
      grid-template-columns: repeat(3, minmax(0, 1fr));
      gap: 16px;
      margin-top: 28px;
    }

    .fpw-quote-card {
      margin: 0;
      padding: 20px;
      border: 1px solid var(--fpw-border);
      border-radius: 18px;
      background: rgba(255,255,255,0.03);
    }

    .fpw-quote-card blockquote {
      margin: 0 0 16px;
      color: var(--fpw-muted);
      font-size: 1.02rem;
    }

    .fpw-quote-card figcaption {
      color: var(--fpw-text);
      font-weight: 900;
    }

    .fpw-letter-list {
      display: grid;
      gap: 14px;
      margin: 18px 0 24px;
      padding: 0;
      list-style: none;
    }

    .fpw-letter-list li {
      display: grid;
      grid-template-columns: 42px 1fr;
      gap: 14px;
      padding: 18px;
      border: 1px solid var(--fpw-border);
      border-radius: 18px;
      background: rgba(255,255,255,0.03);
    }

    .fpw-letter-list li > span {
      width: 34px;
      height: 34px;
      display: grid;
      place-items: center;
      border-radius: 50%;
      color: var(--fpw-cyan);
      background: rgba(43,238,227,0.12);
      font-weight: 950;
    }

    .fpw-letter-list strong {
      display: block;
      margin-bottom: 4px;
      color: var(--fpw-text);
    }

    .fpw-founder-cta__grid {
      grid-template-columns: minmax(0, 1fr) minmax(320px, 0.52fr);
      padding: clamp(28px, 5vw, 52px);
      border-radius: var(--fpw-radius-lg);
      align-items: center;
    }

    .fpw-final-signup-card {
      padding: 24px;
      border: 1px solid var(--fpw-border);
      border-radius: 22px;
      background: rgba(5,17,26,0.45);
    }

    .fpw-inline-signup,
    .fpw-footer-form {
      display: flex;
      gap: 10px;
      margin: 18px 0 14px;
    }

    .fpw-inline-signup input,
    .fpw-footer-form input {
      min-width: 0;
      width: 100%;
      min-height: 48px;
      padding: 0 16px;
      border: 1px solid var(--fpw-border);
      border-radius: 14px;
      color: var(--fpw-text);
      background: rgba(255,255,255,0.045);
    }

    .fpw-inline-signup input::placeholder,
    .fpw-footer-form input::placeholder {
      color: rgba(165, 189, 209, 0.7);
    }

    .fpw-final-signup-card__notes {
      display: flex;
      flex-wrap: wrap;
      gap: 10px;
      margin: 14px 0 0;
      padding: 0;
      color: var(--fpw-muted);
      font-size: 0.86rem;
      list-style: none;
    }

    .fpw-final-signup-card__notes li {
      padding: 6px 10px;
      border: 1px solid rgba(114,213,236,0.14);
      border-radius: 999px;
      background: rgba(255,255,255,0.025);
    }

    .fpw-bottom-cta__inner {
      display: grid;
      grid-template-columns: minmax(0, 1fr) auto minmax(200px, 0.4fr);
      gap: 24px;
      align-items: center;
      padding: 30px;
      border-radius: var(--fpw-radius-lg);
    }

    .fpw-bottom-cta__actions {
      display: flex;
      gap: 12px;
      flex-wrap: wrap;
    }

    .fpw-bottom-cta__badges {
      display: grid;
      gap: 10px;
      color: var(--fpw-muted);
      font-weight: 850;
    }

    .fpw-bottom-cta__badges span {
      display: inline-flex;
      align-items: center;
      gap: 9px;
    }

    .fpw-bottom-cta__badges i {
      width: 30px;
      height: 30px;
      display: grid;
      place-items: center;
      border-radius: 11px;
      color: var(--fpw-cyan);
      background: rgba(43,238,227,0.1);
      font-style: normal;
    }

    .fpw-footer {
      margin-top: 34px;
      padding: 38px 0 24px;
      border-left: 0;
      border-right: 0;
      border-bottom: 0;
      border-radius: 0;
      background: rgba(3, 13, 20, 0.68);
      box-shadow: none;
    }

    .fpw-footer__grid {
      display: grid;
      grid-template-columns: minmax(260px, 1.3fr) repeat(3, minmax(130px, 0.55fr)) minmax(260px, 1fr);
      gap: 30px;
      align-items: start;
    }

    .fpw-footer__brand p,
    .fpw-footer__signup p,
    .fpw-footer__bottom p {
      margin: 12px 0 0;
      color: var(--fpw-muted);
    }

    .fpw-footer__nav,
    .fpw-footer__signup {
      display: grid;
      gap: 9px;
    }

    .fpw-footer__nav h3,
    .fpw-footer__signup h3 {
      margin: 0 0 4px;
      color: var(--fpw-text);
      font-size: 0.88rem;
      letter-spacing: 0.08em;
      text-transform: uppercase;
    }

    .fpw-footer__nav a {
      color: var(--fpw-muted);
      font-weight: 750;
      font-size: 0.93rem;
    }

    .fpw-footer__nav a:hover {
      color: var(--fpw-cyan);
    }

    .fpw-footer-form {
      margin: 10px 0 12px;
    }

    .fpw-social-links {
      display: flex;
      gap: 9px;
    }

    .fpw-social-links a {
      width: 34px;
      height: 34px;
      display: grid;
      place-items: center;
      border: 1px solid var(--fpw-border);
      border-radius: 50%;
      color: var(--fpw-muted);
      background: rgba(255,255,255,0.03);
      font-weight: 900;
    }

    .fpw-footer__bottom {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 18px;
      margin-top: 30px;
      padding-top: 20px;
      border-top: 1px solid var(--fpw-border);
      color: var(--fpw-muted);
      font-size: 0.92rem;
    }

    @media (max-width: 1120px) {
      .fpw-nav {
        display: none;
      }

      .fpw-menu-btn {
        display: inline-flex;
      }

      .fpw-mobile-nav.is-open {
        display: block;
      }

      .fpw-hero__grid,
      .fpw-great-loop__grid,
      .fpw-family__grid,
      .fpw-founder-cta__grid {
        grid-template-columns: 1fr;
      }

      .fpw-command-shell {
        max-width: 760px;
        width: 100%;
        margin-inline: auto;
      }

      .fpw-feature-grid {
        grid-template-columns: repeat(3, minmax(0, 1fr));
      }

      .fpw-membership__grid {
        grid-template-columns: repeat(2, minmax(0, 1fr));
      }

      .fpw-member-fit-card {
        grid-column: 1 / -1;
      }

      .fpw-live-tools__grid {
        grid-template-columns: 1fr;
      }

      .fpw-footer__grid {
        grid-template-columns: repeat(2, minmax(0, 1fr));
      }
    }

    @media (max-width: 840px) {
      .fpw-top-offer__inner {
        flex-direction: column;
        gap: 3px;
        padding: 10px 0;
      }

      .fpw-brand__text small {
        display: none;
      }

      .fpw-header__actions .fpw-btn--ghost {
        display: none;
      }

      .fpw-hero__cards,
      .fpw-feature-grid,
      .fpw-membership__grid,
      .fpw-quote-grid,
      .fpw-loop-feature-list {
        grid-template-columns: 1fr;
      }

      .fpw-command-grid {
        grid-template-columns: repeat(2, minmax(0, 1fr));
      }

      .fpw-command-card--wide,
      .fpw-command-card--status {
        grid-column: span 2;
      }

      .fpw-command-footer,
      .fpw-section-header--split,
      .fpw-footer__bottom {
        align-items: flex-start;
        flex-direction: column;
      }

      .fpw-loop-panel {
        grid-template-columns: 1fr;
      }

      .fpw-loop-stats {
        grid-template-columns: repeat(2, minmax(0, 1fr));
        border-left: 0;
        border-top: 1px solid var(--fpw-border);
      }

      .fpw-loop-stats article {
        border-right: 1px solid var(--fpw-border);
      }

      .fpw-companion-panel,
      .fpw-share-panel,
      .fpw-bottom-cta__inner {
        grid-template-columns: 1fr;
      }

      .fpw-phone-preview {
        width: 210px;
      }

      .fpw-inline-signup,
      .fpw-footer-form {
        flex-direction: column;
      }
    }

    @media (max-width: 560px) {
      :root {
        --fpw-header-height: 72px;
      }

      .fpw-container {
        width: min(calc(100% - 22px), var(--fpw-container));
      }

      .fpw-brand__mark {
        width: 38px;
        height: 38px;
        font-size: 1.45rem;
      }

      .fpw-brand__text strong {
        font-size: 1.22rem;
      }

      .fpw-header__actions .fpw-btn--primary {
        display: none;
      }

      .fpw-hero {
        padding-top: 28px;
      }

      .fpw-hero h1 {
        font-size: clamp(2.75rem, 14vw, 4.5rem);
      }

      .fpw-hero__cta {
        align-items: stretch;
        flex-direction: column;
      }

      .fpw-hero__cta .fpw-btn {
        width: 100%;
      }

      .fpw-command-window__top {
        align-items: flex-start;
        flex-direction: column;
      }

      .fpw-command-grid {
        grid-template-columns: 1fr;
        padding: 14px;
      }

      .fpw-command-card--wide,
      .fpw-command-card--status {
        grid-column: span 1;
      }

      .fpw-radar {
        opacity: 0.45;
      }

      .fpw-loop-map {
        min-height: 300px;
        padding: 14px;
      }

      .fpw-loop-map svg {
        min-height: 280px;
      }

      .fpw-loop-stats {
        grid-template-columns: 1fr;
      }

      .fpw-footer__grid {
        grid-template-columns: 1fr;
      }
    }

    @media (prefers-reduced-motion: reduce) {
      *,
      *::before,
      *::after {
        scroll-behavior: auto !important;
        animation-duration: 0.001ms !important;
        animation-iteration-count: 1 !important;
        transition-duration: 0.001ms !important;
      }
    }
  </style>
</head>

<body>
  <a class="fpw-skip-link" href="#mainContent">Skip to main content</a>

  <div class="fpw-live-home">

    <div class="fpw-top-offer" role="region" aria-label="Launch offer">
      <div class="fpw-container fpw-top-offer__inner">
        <cfoutput><span class="fpw-top-offer__eyebrow">#encodeForHTML(launchLabel)#</span></cfoutput>
        <span class="fpw-top-offer__text">Start free today. Optional Premium tools are available for longer voyages and advanced monitoring.</span>
        <cfoutput><a class="fpw-top-offer__link" href="#encodeForHTMLAttribute(pricingUrl)#">View Memberships</a></cfoutput>
      </div>
    </div>

    <header class="fpw-header" data-fpw-header>
      <div class="fpw-container fpw-header__inner">
        <cfoutput>
          <a class="fpw-brand" href="/" aria-label="#encodeForHTMLAttribute(siteName)# home">
            <span class="fpw-brand__mark" aria-hidden="true">☼</span>
            <span class="fpw-brand__text">
              <strong>#encodeForHTML(siteName)#</strong>
              <small>#encodeForHTML(siteTagline)#</small>
            </span>
          </a>
        </cfoutput>

        <nav class="fpw-nav" aria-label="Primary navigation">
          <cfloop array="#navItems#" item="navItem">
            <cfoutput><a href="#encodeForHTMLAttribute(navItem.href)#">#encodeForHTML(navItem.label)#</a></cfoutput>
          </cfloop>
        </nav>

        <div class="fpw-header__actions">
          <cfoutput>
            <a class="fpw-btn fpw-btn--primary fpw-btn--small" href="#encodeForHTMLAttribute(signupUrl)#">Start Free</a>
            <a class="fpw-btn fpw-btn--ghost fpw-btn--small" href="#encodeForHTMLAttribute(loginUrl)#">Sign In</a>
          </cfoutput>
          <button class="fpw-menu-btn" type="button" aria-label="Open menu" aria-controls="fpwMobileNav" aria-expanded="false" data-fpw-menu-toggle>
            <span aria-hidden="true">⋮⋮</span>
          </button>
        </div>
      </div>

      <nav class="fpw-mobile-nav" id="fpwMobileNav" aria-label="Mobile navigation" data-fpw-mobile-nav>
        <div class="fpw-container fpw-mobile-nav__inner">
          <cfloop array="#navItems#" item="navItem">
            <cfoutput><a href="#encodeForHTMLAttribute(navItem.href)#">#encodeForHTML(navItem.label)#</a></cfoutput>
          </cfloop>
          <cfoutput>
            <a href="#encodeForHTMLAttribute(signupUrl)#">Start Free</a>
            <a href="#encodeForHTMLAttribute(loginUrl)#">Sign In</a>
          </cfoutput>
        </div>
      </nav>
    </header>

    <main id="mainContent">

      <section class="fpw-hero" id="how-it-works" aria-labelledby="fpwHeroTitle">
        <div class="fpw-container fpw-hero__grid">

          <div class="fpw-hero__copy">
            <div class="fpw-status-pill">
              <span class="fpw-status-pill__dot" aria-hidden="true"></span>
              <cfoutput><span>#encodeForHTML(launchLabel)#</span></cfoutput>
            </div>

            <h1 id="fpwHeroTitle">
              Plan <span>smarter.</span><br>
              Cruise prepared.<br>
              Keep everyone informed.
            </h1>

            <p class="fpw-hero__lead">
              Create organized float plans, build routes, monitor active trips, and share voyage progress with family and friends from one boating-focused platform.
            </p>

            <ul class="fpw-hero__bullets">
              <cfloop array="#heroBullets#" item="heroBullet">
                <cfoutput><li>#encodeForHTML(heroBullet)#</li></cfoutput>
              </cfloop>
            </ul>

            <div class="fpw-hero__cards" aria-label="Core FloatPlanWizard capabilities">
              <cfloop array="#heroMiniCards#" item="miniCard">
                <cfoutput>
                  <article class="fpw-mini-card">
                    <div class="fpw-mini-card__icon" aria-hidden="true">#encodeForHTML(miniCard.icon)#</div>
                    <h2>#encodeForHTML(miniCard.title)#</h2>
                    <p>#encodeForHTML(miniCard.body)#</p>
                  </article>
                </cfoutput>
              </cfloop>
            </div>

            <div class="fpw-hero__cta">
              <cfoutput>
                <a class="fpw-btn fpw-btn--primary" href="#encodeForHTMLAttribute(signupUrl)#">Start Free</a>
                <a class="fpw-btn fpw-btn--secondary" href="#encodeForHTMLAttribute(howItWorksUrl)#"><span aria-hidden="true">▷</span> See How It Works</a>
                <a class="fpw-btn fpw-btn--text" href="#encodeForHTMLAttribute(greatLoopUrl)#">Explore Great Loop Features</a>
              </cfoutput>
            </div>

            <div class="fpw-trust-row" aria-label="Signup notes">
              <span><i aria-hidden="true">✓</i> Free plan available</span>
              <span><i aria-hidden="true">✓</i> No credit card required</span>
              <span><i aria-hidden="true">✓</i> Built by boaters</span>
            </div>
          </div>

          <div class="fpw-command-shell" id="active-cruise" aria-label="Voyage command center preview">
            <div class="fpw-command-window">
              <div class="fpw-command-window__top">
                <div class="fpw-window-dots" aria-hidden="true">
                  <span></span><span></span><span></span>
                </div>
                <strong>Voyage Command Center</strong>
                <span class="fpw-live-indicator">All Systems Go <i aria-hidden="true"></i></span>
              </div>

              <div class="fpw-command-grid">
                <article class="fpw-command-card fpw-command-card--wide">
                  <div class="fpw-card-kicker">Active Voyage</div>
                  <h2>Tarpon Springs → Steinhatchee</h2>
                  <div class="fpw-progress" aria-label="Voyage progress"><span style="width: 37%;"></span></div>
                  <div class="fpw-card-meta"><span>Leg 2 of 4</span><strong>37% Complete</strong></div>
                </article>

                <article class="fpw-command-card fpw-command-card--status">
                  <div class="fpw-card-kicker">Monitoring Status</div>
                  <strong class="fpw-status-value">Monitoring Active</strong>
                  <span>Next check-in due in</span>
                  <b>1h 45m</b>
                  <div class="fpw-radar" aria-hidden="true"><span></span></div>
                </article>

                <article class="fpw-command-card">
                  <div class="fpw-card-kicker">Last Check-In</div>
                  <strong>14 min ago</strong>
                  <span>Today 9:16 AM</span>
                  <em>On Track</em>
                </article>

                <article class="fpw-command-card">
                  <div class="fpw-card-kicker">Next Check-In</div>
                  <strong>Today 11:00 AM</strong>
                  <span>In 1h 45m</span>
                  <em>Expected</em>
                </article>

                <article class="fpw-command-card">
                  <div class="fpw-card-kicker">Secure for Night</div>
                  <strong>Yes</strong>
                  <span>Until tomorrow</span>
                  <em>8:00 AM</em>
                </article>

                <article class="fpw-command-card">
                  <div class="fpw-card-kicker">Current Delay</div>
                  <strong>15 min</strong>
                  <span>Total applied</span>
                  <em>Manual</em>
                </article>

                <article class="fpw-command-card">
                  <div class="fpw-card-kicker">Weather Window</div>
                  <strong>Favorable</strong>
                  <span>Light winds ahead</span>
                  <em>Checked</em>
                </article>

                <article class="fpw-command-card">
                  <div class="fpw-card-kicker">Fuel Range</div>
                  <strong>325 NM</strong>
                  <span>Good</span>
                  <em>On Plan</em>
                </article>

                <article class="fpw-command-card">
                  <div class="fpw-card-kicker">Share the Trip</div>
                  <strong>3 Followers</strong>
                  <span>Updates active</span>
                  <em>Private</em>
                </article>

                <article class="fpw-command-card">
                  <div class="fpw-card-kicker">Companion App</div>
                  <strong>Connected</strong>
                  <span>GPS check-ins</span>
                  <em>Ready</em>
                </article>
              </div>

              <div class="fpw-command-footer">
                <span>Voyage Status</span>
                <strong>On Plan</strong>
                <span>Last Updated: 9:16 AM</span>
                <span>All systems normal</span>
              </div>
            </div>
          </div>

        </div>
      </section>

      <section class="fpw-membership" id="pricing" aria-labelledby="fpwMembershipTitle">
        <div class="fpw-container">
          <div class="fpw-section-header fpw-section-header--split">
            <div>
              <span class="fpw-section-kicker">Memberships are open</span>
              <h2 id="fpwMembershipTitle">Simple membership. Powerful boating tools.</h2>
              <p>Start free, then upgrade when you need advanced monitoring, Great Loop planning, companion workflows, and expanded cruise tools.</p>
            </div>
            <p class="fpw-section-note">No credit card required for the free plan.</p>
          </div>

          <div class="fpw-membership__grid">
            <article class="fpw-plan-card fpw-plan-card--free">
              <div class="fpw-plan-card__top">
                <div class="fpw-plan-card__icon" aria-hidden="true">♙</div>
                <div>
                  <h3>Free</h3>
                  <p>Everything you need to get started.</p>
                </div>
              </div>
              <ul class="fpw-check-list">
                <cfloop array="#freePlanFeatures#" item="planFeature">
                  <cfoutput><li>#encodeForHTML(planFeature)#</li></cfoutput>
                </cfloop>
              </ul>
              <div class="fpw-plan-card__price"><strong>$0</strong><span>/ month</span></div>
              <cfoutput><a class="fpw-btn fpw-btn--primary fpw-btn--full" href="#encodeForHTMLAttribute(signupUrl)#">Start Free</a></cfoutput>
            </article>

            <article class="fpw-plan-card fpw-plan-card--premium">
              <div class="fpw-plan-card__top">
                <div class="fpw-plan-card__icon" aria-hidden="true">♛</div>
                <div>
                  <h3>Premium</h3>
                  <p>Advanced tools for serious cruisers.</p>
                </div>
              </div>
              <ul class="fpw-check-list">
                <cfloop array="#premiumPlanFeatures#" item="planFeature">
                  <cfoutput><li>#encodeForHTML(planFeature)#</li></cfoutput>
                </cfloop>
              </ul>
              <cfoutput>
                <div class="fpw-plan-card__price"><strong>#encodeForHTML(premiumPriceLabel)#</strong><span>#encodeForHTML(premiumPriceSuffix)#</span></div>
                <a class="fpw-btn fpw-btn--accent fpw-btn--full" href="#encodeForHTMLAttribute(pricingUrl)#">Upgrade to Premium</a>
              </cfoutput>
            </article>

            <aside class="fpw-member-fit-card" aria-labelledby="fpwMemberFitTitle">
              <h3 id="fpwMemberFitTitle">Built for boaters who:</h3>
              <ul class="fpw-icon-list">
                <cfloop array="#memberFitItems#" item="fitItem">
                  <cfoutput>
                    <li>
                      <span aria-hidden="true">#encodeForHTML(fitItem.icon)#</span>
                      <p>#encodeForHTML(fitItem.body)#</p>
                    </li>
                  </cfoutput>
                </cfloop>
              </ul>
            </aside>
          </div>
        </div>
      </section>

      <section class="fpw-features" id="features" aria-labelledby="fpwFeaturesTitle">
        <div class="fpw-container">
          <div class="fpw-section-header">
            <span class="fpw-section-kicker">Everything you need for a better voyage</span>
            <h2 id="fpwFeaturesTitle">Plan the trip. Monitor the voyage. Share the journey.</h2>
            <p>FloatPlanWizard combines route organization, float plans, trip monitoring, and private trip sharing in one connected workflow.</p>
          </div>

          <div class="fpw-feature-grid">
            <cfloop array="#featureCards#" item="featureCard">
              <cfoutput>
                <article class="fpw-feature-card">
                  <div class="fpw-feature-card__icon" aria-hidden="true">#encodeForHTML(featureCard.icon)#</div>
                  <h3>#encodeForHTML(featureCard.title)#</h3>
                  <p>#encodeForHTML(featureCard.body)#</p>
                </article>
              </cfoutput>
            </cfloop>
          </div>
        </div>
      </section>

      <section class="fpw-great-loop" id="great-loop" aria-labelledby="fpwGreatLoopTitle">
        <div class="fpw-container fpw-great-loop__grid">
          <div class="fpw-great-loop__copy">
            <span class="fpw-section-kicker">Built for the journey</span>
            <h2 id="fpwGreatLoopTitle">Great Loop ready.</h2>
            <p>From the Gulf to the Great Lakes and back again, FloatPlanWizard gives Loopers a structured way to plan route segments, organize stops, track fuel confidence, and keep family informed.</p>
            <ul class="fpw-check-list fpw-check-list--large">
              <cfloop array="#greatLoopFeatures#" item="greatLoopFeature">
                <cfoutput><li>#encodeForHTML(greatLoopFeature)#</li></cfoutput>
              </cfloop>
            </ul>
            <cfoutput><a class="fpw-btn fpw-btn--secondary" href="#encodeForHTMLAttribute(greatLoopUrl)#">Explore Great Loop Features</a></cfoutput>
          </div>

          <div class="fpw-loop-panel" aria-label="Great Loop route preview">
            <div class="fpw-loop-map" aria-hidden="true">
              <svg viewBox="0 0 720 420" role="img" aria-label="Stylized Great Loop route map">
                <rect x="0" y="0" width="720" height="420" rx="24"></rect>
                <path class="fpw-map-land" d="M80 70 C150 35 245 30 330 55 C420 82 510 72 610 95 C665 110 700 155 690 220 C678 300 595 350 510 355 C420 360 350 338 270 370 C190 402 95 365 60 300 C25 230 30 115 80 70 Z"></path>
                <path class="fpw-map-route" d="M370 65 C355 100 352 132 385 155 C430 188 515 160 560 185 C610 215 590 285 535 305 C470 330 430 350 410 380 C385 340 335 325 285 318 C215 308 160 268 160 220 C160 168 215 142 255 115 C300 84 330 72 370 65"></path>
                <g class="fpw-map-pins">
                  <circle cx="370" cy="65" r="7"></circle>
                  <circle cx="560" cy="185" r="7"></circle>
                  <circle cx="410" cy="380" r="7"></circle>
                  <circle cx="160" cy="220" r="7"></circle>
                </g>
                <text x="390" y="80">Great Lakes</text>
                <text x="570" y="182">Atlantic</text>
                <text x="340" y="392">Gulf</text>
                <text x="115" y="220">Inland Rivers</text>
              </svg>
            </div>

            <div class="fpw-loop-stats">
              <article><strong>~6,000 NM</strong><span>Total loop distance</span></article>
              <article><strong>15+</strong><span>States & provinces</span></article>
              <article><strong>200+</strong><span>Possible stops</span></article>
              <article><strong>1 epic journey</strong><span>Organized in FPW</span></article>
            </div>

            <div class="fpw-loop-feature-list">
              <p><strong>Route Leg Clarity:</strong> Keep each segment organized from ICW to inland rivers.</p>
              <p><strong>Lock Readiness:</strong> Plan lock sequences and wait windows.</p>
              <p><strong>Fuel Range Confidence:</strong> Track distance-to-fuel and refill timing by leg.</p>
              <p><strong>Weather-Aware Timing:</strong> Adjust departure around fronts, wind, and seas.</p>
              <p><strong>Shared Live Progress:</strong> Give family clear trip status with private updates.</p>
            </div>
          </div>
        </div>
      </section>

      <section class="fpw-live-tools" id="companion-app" aria-labelledby="fpwLiveToolsTitle">
        <div class="fpw-container">
          <div class="fpw-section-header">
            <span class="fpw-section-kicker">Connected while underway</span>
            <h2 id="fpwLiveToolsTitle">Simple check-ins from the boat. Clear updates back home.</h2>
          </div>

          <div class="fpw-live-tools__grid">
            <article class="fpw-companion-panel">
              <div class="fpw-phone-preview" aria-hidden="true">
                <div class="fpw-phone-preview__screen">
                  <span class="fpw-phone-preview__top">FPW Companion</span>
                  <div class="fpw-phone-preview__check">✓</div>
                  <strong>Check-In Successful</strong>
                  <span>Today 9:16 AM</span>
                  <div class="fpw-phone-preview__row"><span>Status</span><strong>On Track</strong></div>
                  <div class="fpw-phone-preview__row"><span>Location</span><strong>GPS Sent</strong></div>
                  <button type="button">Secure for Night</button>
                </div>
              </div>

              <div>
                <span class="fpw-section-kicker">Companion App</span>
                <h3>One-tap trip updates from the boat.</h3>
                <p>Designed for real cruising conditions where marina Wi-Fi, cellular, and satellite connectivity can vary.</p>
                <ul class="fpw-check-list">
                  <cfloop array="#companionFeatures#" item="companionFeature">
                    <cfoutput><li>#encodeForHTML(companionFeature)#</li></cfoutput>
                  </cfloop>
                </ul>
                <cfoutput><a class="fpw-btn fpw-btn--secondary" href="#encodeForHTMLAttribute(companionUrl)#">Learn More</a></cfoutput>
              </div>
            </article>

            <article class="fpw-share-panel" id="share-the-trip">
              <div>
                <span class="fpw-section-kicker">Share the Trip</span>
                <h3>Bring everyone along without constant texting.</h3>
                <p>A private shared trip page helps family, friends, and trusted contacts understand the route, plan, stops, and latest status.</p>
                <ul class="fpw-check-list">
                  <cfloop array="#shareFeatures#" item="shareFeature">
                    <cfoutput><li>#encodeForHTML(shareFeature)#</li></cfoutput>
                  </cfloop>
                </ul>
              </div>

              <div class="fpw-shared-trip-card" aria-label="Shared trip page preview">
                <div class="fpw-shared-trip-card__top">
                  <span aria-hidden="true">👥</span>
                  <div><strong>Following: Summer Loop 2026</strong><small>Tarpon Springs → Chicago</small></div>
                </div>
                <div class="fpw-progress" aria-label="Shared trip progress"><span style="width: 37%;"></span></div>
                <div class="fpw-shared-trip-card__body">
                  <p><strong>Latest Update</strong></p>
                  <p>On the way to Steinhatchee. All systems go.</p>
                  <span>14 min ago</span>
                </div>
                <cfoutput><a class="fpw-btn fpw-btn--secondary fpw-btn--full" href="#encodeForHTMLAttribute(shareTripUrl)#">View Trip Page Example</a></cfoutput>
              </div>
            </article>
          </div>
        </div>
      </section>

      <section class="fpw-family" aria-labelledby="fpwFamilyTitle">
        <div class="fpw-container fpw-family__grid">
          <div class="fpw-family__copy">
            <span class="fpw-section-kicker">Keep your family informed</span>
            <h2 id="fpwFamilyTitle">A better way to share the trip with family and friends.</h2>
            <p>One of FloatPlanWizard’s strongest selling points is simple: it helps the people back home feel informed. That matters whether you are on a day cruise, a weekend run, or a long-distance Great Loop segment.</p>

            <div class="fpw-quote-grid">
              <figure class="fpw-quote-card">
                <blockquote>“I just want an easy way to see where the trip is headed and what the plan is.”</blockquote>
                <figcaption>Family perspective</figcaption>
              </figure>
              <figure class="fpw-quote-card">
                <blockquote>“The route makes sense, the stops are clear, and I’m not guessing what’s happening.”</blockquote>
                <figcaption>Shared trip page benefit</figcaption>
              </figure>
              <figure class="fpw-quote-card">
                <blockquote>“This feels more organized than texting updates one at a time.”</blockquote>
                <figcaption>What the product promises</figcaption>
              </figure>
            </div>
          </div>

          <aside class="fpw-family__details" aria-labelledby="fpwFamilyDetailsTitle">
            <span class="fpw-section-kicker">What they see</span>
            <h3 id="fpwFamilyDetailsTitle">Trip clarity at a glance.</h3>
            <ol class="fpw-letter-list">
              <cfloop array="#familyItems#" item="familyItem">
                <cfoutput>
                  <li>
                    <span>#encodeForHTML(familyItem.letter)#</span>
                    <div>
                      <strong>#encodeForHTML(familyItem.title)#</strong>
                      <p>#encodeForHTML(familyItem.body)#</p>
                    </div>
                  </li>
                </cfoutput>
              </cfloop>
            </ol>
            <cfoutput><a class="fpw-btn fpw-btn--primary" href="#encodeForHTMLAttribute(signupUrl)#">Create Free Account</a></cfoutput>
          </aside>
        </div>
      </section>

      <section class="fpw-founder-cta" aria-labelledby="fpwFounderTitle">
        <div class="fpw-container fpw-founder-cta__grid">
          <div>
            <span class="fpw-section-kicker">Built by boaters for boaters</span>
            <h2 id="fpwFounderTitle">Built for the planning that happens before leaving the dock.</h2>
            <p>FloatPlanWizard was built by a boater who understands how much preparation matters. The goal is simple: give recreational boaters a better way to organize trips, share plans, monitor active cruises, and keep family and friends informed with confidence.</p>
            <p>Whether you are planning a day run, an overnight anchorage, a weekend cruise, or a Great Loop segment, FPW helps keep the important details in one place.</p>
          </div>

          <aside class="fpw-final-signup-card" aria-labelledby="fpwFinalSignupTitle">
            <span class="fpw-section-kicker">Start today</span>
            <h3 id="fpwFinalSignupTitle">Create your free account.</h3>
            <p>No credit card required. Upgrade anytime for Premium cruise planning and monitoring tools.</p>
            <cfoutput>
              <form class="fpw-inline-signup" action="#encodeForHTMLAttribute(signupUrl)#" method="get" data-fpw-signup-form>
                <label class="fpw-sr-only" for="fpwFinalEmail">Email address</label>
                <input id="fpwFinalEmail" name="email" type="email" placeholder="Email address" autocomplete="email" value="#encodeForHTMLAttribute(prefillEmail)#">
                <button class="fpw-btn fpw-btn--primary" type="submit">Start Free</button>
              </form>
            </cfoutput>
            <ul class="fpw-final-signup-card__notes">
              <li>Free plan available</li>
              <li>Secure and private</li>
              <li>Built for serious recreational boaters</li>
            </ul>
          </aside>
        </div>
      </section>

      <section class="fpw-bottom-cta" aria-labelledby="fpwBottomCtaTitle">
        <div class="fpw-container fpw-bottom-cta__inner">
          <div>
            <h2 id="fpwBottomCtaTitle">Start planning your next adventure today.</h2>
            <p>Join boaters who want a clearer way to plan, monitor, and share their trips.</p>
          </div>
          <div class="fpw-bottom-cta__actions">
            <cfoutput>
              <a class="fpw-btn fpw-btn--primary" href="#encodeForHTMLAttribute(signupUrl)#">Create Free Account</a>
              <a class="fpw-btn fpw-btn--secondary" href="#encodeForHTMLAttribute(featuresUrl)#">Explore Features</a>
            </cfoutput>
          </div>
          <div class="fpw-bottom-cta__badges">
            <span><i aria-hidden="true">♢</i> Secure &amp; Private</span>
            <span><i aria-hidden="true">☼</i> Built for Boaters</span>
          </div>
        </div>
      </section>
    </main>

    <footer class="fpw-footer">
      <div class="fpw-container fpw-footer__grid">
        <div class="fpw-footer__brand">
          <cfoutput>
            <a class="fpw-brand" href="/" aria-label="#encodeForHTMLAttribute(siteName)# home">
              <span class="fpw-brand__mark" aria-hidden="true">☼</span>
              <span class="fpw-brand__text"><strong>#encodeForHTML(siteName)#</strong></span>
            </a>
          </cfoutput>
          <p>Plan the voyage. Share the journey. Keep everyone informed.</p>
        </div>

        <nav class="fpw-footer__nav" aria-label="Product links">
          <h3>Product</h3>
          <cfloop array="#footerProductLinks#" item="footerLink">
            <cfoutput><a href="#encodeForHTMLAttribute(footerLink.href)#">#encodeForHTML(footerLink.label)#</a></cfoutput>
          </cfloop>
        </nav>

        <nav class="fpw-footer__nav" aria-label="Resources links">
          <h3>Resources</h3>
          <cfloop array="#footerResourceLinks#" item="footerLink">
            <cfoutput><a href="#encodeForHTMLAttribute(footerLink.href)#">#encodeForHTML(footerLink.label)#</a></cfoutput>
          </cfloop>
        </nav>

        <nav class="fpw-footer__nav" aria-label="Company links">
          <h3>Company</h3>
          <cfloop array="#footerCompanyLinks#" item="footerLink">
            <cfoutput><a href="#encodeForHTMLAttribute(footerLink.href)#">#encodeForHTML(footerLink.label)#</a></cfoutput>
          </cfloop>
        </nav>

        <div class="fpw-footer__signup">
          <h3>Stay Connected</h3>
          <p>Get trip, planning, and boating-product updates.</p>
          <cfoutput>
            <form class="fpw-footer-form" action="#encodeForHTMLAttribute(subscribeUrl)#" method="post" data-fpw-subscribe-form>
              <label class="fpw-sr-only" for="fpwFooterEmail">Email address</label>
              <input id="fpwFooterEmail" name="email" type="email" placeholder="Enter your email" autocomplete="email">
              <button class="fpw-btn fpw-btn--primary fpw-btn--small" type="submit">Subscribe</button>
            </form>
          </cfoutput>
          <div class="fpw-social-links" aria-label="Social links">
            <a href="#" aria-label="Facebook">f</a>
            <a href="#" aria-label="Instagram">◎</a>
            <a href="#" aria-label="YouTube">▶</a>
          </div>
        </div>
      </div>

      <div class="fpw-container fpw-footer__bottom">
        <cfoutput><p>© #currentYear# FloatPlanWizard. All rights reserved.</p></cfoutput>
        <p>Built for Great Loopers and serious recreational boaters.</p>
      </div>
    </footer>
  </div>

  <script>
    (function () {
      'use strict';

      var header = document.querySelector('[data-fpw-header]');
      var menuToggle = document.querySelector('[data-fpw-menu-toggle]');
      var mobileNav = document.querySelector('[data-fpw-mobile-nav]');
      var signupForms = document.querySelectorAll('[data-fpw-signup-form]');
      var subscribeForms = document.querySelectorAll('[data-fpw-subscribe-form]');

      function setHeaderState() {
        if (!header) return;
        header.classList.toggle('is-scrolled', window.scrollY > 12);
      }

      function closeMobileNav() {
        if (!menuToggle || !mobileNav) return;
        mobileNav.classList.remove('is-open');
        menuToggle.setAttribute('aria-expanded', 'false');
      }

      if (menuToggle && mobileNav) {
        menuToggle.addEventListener('click', function () {
          var isOpen = mobileNav.classList.toggle('is-open');
          menuToggle.setAttribute('aria-expanded', String(isOpen));
        });

        mobileNav.addEventListener('click', function (event) {
          if (event.target && event.target.matches('a')) {
            closeMobileNav();
          }
        });
      }

      document.addEventListener('click', function (event) {
        var link = event.target.closest('a[href^="#"]');
        if (!link) return;

        var href = link.getAttribute('href');
        if (!href || href === '#') return;

        var target = document.querySelector(href);
        if (!target) return;

        event.preventDefault();
        closeMobileNav();
        target.scrollIntoView({ behavior: 'smooth', block: 'start' });
        history.replaceState(null, '', href);
      });

      signupForms.forEach(function (form) {
        form.addEventListener('submit', function (event) {
          var emailInput = form.querySelector('input[type="email"]');
          if (!emailInput || !emailInput.value.trim()) return;

          if (!emailInput.checkValidity()) {
            event.preventDefault();
            emailInput.reportValidity();
          }
        });
      });

      subscribeForms.forEach(function (form) {
        form.addEventListener('submit', function (event) {
          var emailInput = form.querySelector('input[type="email"]');
          if (!emailInput) return;

          if (!emailInput.value.trim() || !emailInput.checkValidity()) {
            event.preventDefault();
            emailInput.reportValidity();
          }
        });
      });

      window.addEventListener('scroll', setHeaderState, { passive: true });
      window.addEventListener('resize', function () {
        if (window.innerWidth > 1120) closeMobileNav();
      });

      setHeaderState();
    }());
  </script>
</body>
</html>
