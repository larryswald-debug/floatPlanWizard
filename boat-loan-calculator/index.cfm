<cfprocessingdirective pageencoding="utf-8">
<cfsetting showdebugoutput="false">
<cfcontent type="text/html; charset=utf-8">
<cfheader name="Referrer-Policy" value="no-referrer">
<cfscript>
// Explicit base keeps the shared public navigation correct for this nested route.
request.fpwBase = reReplaceNoCase(cgi.script_name, "/boat-loan-calculator(/.*)?$", "");
request.fpwBase = reReplace(request.fpwBase, "/$", "");
// Tomcat supplies an empty suffix; IIS may supply the full rewritten script path.
// Check the request URI first so a suffix cannot mimic an accepted full path.
if ((structKeyExists(cgi, "request_uri")
    AND reFindNoCase("/index\.cfm(;[^/]*)?/", urlDecode(listFirst(cgi.request_uri, "?"))))
    OR (len(cgi.path_info)
    AND compareNoCase(cgi.path_info, request.fpwBase & "/boat-loan-calculator/index.cfm") NEQ 0
    AND compareNoCase(cgi.path_info, request.fpwBase & "/boat-loan-calculator/") NEQ 0)) {
  cfheader(statuscode=404);
  cfcontent(type="text/plain; charset=utf-8", reset=true);
  writeOutput("Not Found");
  abort;
}
request.fpwTopNavActive = "resources";
// Page-local exception: no automatic URL/form collection or session replay.
// The existing helper remains available; other pages retain their existing tags.
request.fpwPlausibleTagRendered = true;
request.fpwGa4TagRendered = true;
request.fpwClarityTagRendered = true;
fpwCostCanonical = "https://floatplanwizard.com/boat-loan-calculator/";
fpwCostPlannerUrl = request.fpwBase & "/app/join.cfm";
fpwCostUser = structKeyExists(session, "user") AND isStruct(session.user) ? session.user : {};
for (fpwCostUserKey in ["userId", "id", "USERID", "ID"]) {
  if (structKeyExists(fpwCostUser, fpwCostUserKey) AND isNumeric(fpwCostUser[fpwCostUserKey]) AND val(fpwCostUser[fpwCostUserKey]) GT 0) {
    fpwCostPlannerUrl = request.fpwBase & "/app/dashboard.cfm";
    break;
  }
}
</cfscript>
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="referrer" content="no-referrer">
  <title>Boat Loan &amp; Ownership Cost Calculator | FloatPlanWizard</title>
  <meta name="description" content="Estimate your boat loan payment, fuel, storage, maintenance, repair savings and first-year costs. Compare three boats or work backward from your budget. Free; no account required.">
  <link rel="canonical" href="https://floatplanwizard.com/boat-loan-calculator/">
  <meta property="og:type" content="website">
  <meta property="og:site_name" content="FloatPlanWizard">
  <meta property="og:url" content="https://floatplanwizard.com/boat-loan-calculator/">
  <meta property="og:title" content="Boat Loan &amp; Ownership Cost Calculator">
  <meta property="og:description" content="What will your boat really cost each month? Include financing, ownership expenses and repair savings in one free boating budget.">
  <meta property="og:image" content="https://floatplanwizard.com/assets/images/social/floatplanwizard-social-preview-20260730.png">
  <meta property="og:image:alt" content="FloatPlanWizard boating trip planning">
  <meta name="twitter:card" content="summary_large_image">
  <meta name="twitter:title" content="Boat Loan &amp; Ownership Cost Calculator">
  <meta name="twitter:description" content="Estimate financing, recurring ownership expenses and first-year cash needs. Free; no account required.">
  <meta name="twitter:image" content="https://floatplanwizard.com/assets/images/social/floatplanwizard-social-preview-20260730.png">
  <script type="application/ld+json">{"@context":"https://schema.org","@graph":[{"@type":"WebPage","@id":"https://floatplanwizard.com/boat-loan-calculator/#webpage","url":"https://floatplanwizard.com/boat-loan-calculator/","name":"Boat Loan and Ownership Cost Calculator","description":"A free planning calculator for boat financing, recurring ownership costs and repair savings.","inLanguage":"en-US"},{"@type":"BreadcrumbList","itemListElement":[{"@type":"ListItem","position":1,"name":"FloatPlanWizard","item":"https://floatplanwizard.com/"},{"@type":"ListItem","position":2,"name":"Boat Loan and Ownership Cost Calculator","item":"https://floatplanwizard.com/boat-loan-calculator/"}]}]}</script>
  <!-- Synchronous, first executable script: capture state and scrub URL before any tracking. -->
  <cfoutput><script src="#encodeForHTMLAttribute(request.fpwBase)#/assets/js/boat-cost-bootstrap.js?v=2"></script></cfoutput>
  <cfinclude template="../includes/analytics_ga4.cfm">
  <cfoutput>
  <link rel="stylesheet" href="#encodeForHTMLAttribute(request.fpwBase)#/assets/css/layout.css?v=20260620-page-width">
  <link rel="stylesheet" href="#encodeForHTMLAttribute(request.fpwBase)#/assets/css/top-nav.css?v=20260824-boating-safety-nav-v2">
  <link rel="stylesheet" href="#encodeForHTMLAttribute(request.fpwBase)#/assets/css/boat-cost.css?v=2">
  <script defer src="#encodeForHTMLAttribute(request.fpwBase)#/assets/js/boat-cost-engine.js?v=1"></script>
  <script defer src="#encodeForHTMLAttribute(request.fpwBase)#/assets/js/boat-cost-state.js?v=1"></script>
  <script defer src="#encodeForHTMLAttribute(request.fpwBase)#/assets/js/boat-cost-ui.js?v=2"></script>
  <script defer src="#encodeForHTMLAttribute(request.fpwBase)#/assets/js/boat-cost-analytics.js?v=1"></script>
  </cfoutput>
</head>
<body class="boat-cost-page">
<cfinclude template="../includes/top_nav.cfm">
<main class="fpw-container-wide">
  <section class="bc-hero bc-no-print" aria-labelledby="boat-cost-title">
    <p class="bc-eyebrow">BOAT PLANNING TOOL · USD</p>
    <h1 id="boat-cost-title">Boat Loan and Ownership Cost Calculator</h1>
    <h2>What will your boat really cost each month?</h2>
    <p>Estimate your boat payment, fuel, insurance, maintenance, storage, and first-year costs. Compare boats or find a price that fits your boating budget. Free. No account required.</p>
  </section>
  <noscript><p class="bc-notice">Calculation requires JavaScript. The methodology, examples and boating-budget guidance below remain available.</p></noscript>
  <cfoutput><div id="boat-cost-app" class="boat-cost" data-clarity-mask="true" data-share-verified="true" data-canonical-url="#encodeForHTMLAttribute(fpwCostCanonical)#" data-fuel-url="#encodeForHTMLAttribute(request.fpwBase)#/boat-fuel-calculator/" data-planner-url="#encodeForHTMLAttribute(fpwCostPlannerUrl)#" data-planner-note="Free account required to plan and save a trip. These figures are not transferred."></div></cfoutput>
  <div class="bc-education bc-no-print">
    <section aria-labelledby="bc-beyond-loan">
      <h2 id="bc-beyond-loan">What a boat costs beyond the loan payment</h2>
      <p>A boat payment is only one part of the budget. Add fuel, storage, insurance, routine maintenance, registration and recurring taxes, seasonal services, utilities, towing and trailer costs. Keep purchase taxes and fees separate from annual bills. Money saved for future repairs is a funding choice, not an expense or a prediction that repairs will cost that amount.</p>
      <p>Monthly figures spread annual and seasonal costs across 12 months; actual bill timing varies. A blank field means unknown. Enter zero only when zero is your assumption; exclude a category when you deliberately leave it out. Exclusions remain visible with the estimate.</p>
    </section>
    <section aria-labelledby="bc-estimating-costs">
      <h2 id="bc-estimating-costs">How to estimate your operating costs</h2>
      <p>Use insurer and marina quotes, service records and your own usage estimates. Storage can include a year-round slip and seasonal land storage; review overlapping contracts. A marina's billable length can differ from the boat's physical length. Seasonal boating does not automatically reduce insurance, loan payments or annual storage contracts.</p>
      <p>Enter annual fuel dollars, or annual boat running hours multiplied by total GPH for all propulsion engines and price per US gallon. Two engines using 8 GPH each means 16 total GPH. Generator use is separate. Unburned trip reserve fuel is not an annual consumption expense.</p>
      <cfoutput><p class="bc-no-print">Need to check the fuel cost for a specific trip? <a href="#encodeForHTMLAttribute(request.fpwBase)#/boat-fuel-calculator/" data-boat-cost-placement="fuel_help">Use the Boat Fuel Calculator</a>.</p></cfoutput>
      <cfoutput><p>Use measured consumption or appropriate performance data. Read <a href="#request.fpwBase#/boat-fuel-calculator/##find-actual-gph-title">how to find your boat's actual GPH</a>, then <a href="#request.fpwBase#/boat-fuel-calculator/" data-boat-cost-cta="fuel">check trip fuel costs</a>. FPW does not look up a model's GPH from its name, length or horsepower.</p></cfoutput>
      <p>Keep routine engine services separate from seasonal work and immediate repairs. Electric or mixed-propulsion owners can enter annual energy spending in other operating costs and explicitly exclude liquid fuel.</p>
    </section>
    <section aria-labelledby="bc-used-boats">
      <h2 id="bc-used-boats">New versus used boats and first-year preparation</h2>
      <p>A used boat can require a survey, inspection haul-out, engine inspection and catch-up work before normal use. Review delivery, immediate repairs, batteries, electronics, safety equipment, bottom work and a trailer. Some costs arise before closing; others arrive later in the first year. The upfront planning cash figure conservatively includes them all.</p>
      <p>Review sails and rigging for a sailboat; bottom work, haul-out and marina utilities for a boat kept in water; and trailer upkeep, towing and launch fees for a trailered boat. Multiple engines can mean multiple service bills. The checklist changes with the boat profile, but entered costs never receive hidden multipliers. An entered repair reserve does not establish mechanical condition or seaworthiness.</p>
    </section>
    <section aria-labelledby="bc-loan-length">
      <h2 id="bc-loan-length">How loan length changes payment and interest</h2>
      <p>For a fixed principal and positive interest rate, a longer term generally lowers each monthly payment while increasing lifetime interest. Compare the payment and interest together. Actual lender terms, rates and vessel eligibility may differ.</p>
      <p>Use the loan's contract interest rate for this amortization estimate. APR incorporates additional borrowing charges; this tool does not calculate a regulatory APR. See the <a href="https://www.consumerfinance.gov/ask-cfpb/what-is-the-difference-between-a-loan-interest-rate-and-the-apr-en-733/">CFPB explanation of interest rate and APR</a>. No live rates or lender approval are supplied.</p>
    </section>
    <section aria-labelledby="bc-budget-direction">
      <h2 id="bc-budget-direction">Start with your monthly budget and available cash</h2>
      <p>The budget direction finds the highest boat price within both your monthly limit and your available upfront cash. It holds operating expenses, preparation and repair savings fixed. Percentage down payments and percentage purchase tax change with the candidate price; fixed dollar inputs stay fixed.</p>
      <p>The budget result holds your operating assumptions fixed. A different boat may have different costs. It is not a personal financial recommendation or a loan approval. Unknown expenses must be reviewed before the solver can provide a complete result.</p>
    </section>
    <section aria-labelledby="bc-worked-examples">
      <h2 id="bc-worked-examples">Try an example: $25,000, $50,000 or $100,000</h2>
      <p>These complete examples are illustrative assumptions, not market averages, service-price guidance or lender quotes. Load one, then replace its assumptions with your own figures.</p>
      <cfinclude template="examples.cfm">
    </section>
    <section aria-labelledby="bc-faq">
      <h2 id="bc-faq">Boat ownership budget questions</h2>
      <details><summary>Can I calculate a cash purchase?</summary><p>Yes. The boat price, purchase tax and fees are cash-paid, with no loan payment. Operating expenses and repair savings still contribute to your monthly budget. Available upfront cash limits the price in budget mode.</p></details>
      <details><summary>Are repair reserves counted as repair bills?</summary><p>No. Initial repair liquidity and annual repair savings are separate from spending. Known immediate repairs belong in preparation. Reserve allocations are shown separately in projections and are excluded from resale-adjusted ownership cost; they are not forecast bank balances.</p></details>
      <details><summary>Does the calculator determine my state tax?</summary><p>No. Enter a total purchase tax amount or your own percentage of boat price. The percentage method does not model taxable fees, exemptions, trade-in credits, local or use taxes, or caps. State is optional context only. Confirm the tax with the relevant authority.</p></details>
      <details><summary>How accurate are the payment and long-term estimates?</summary><p>The loan uses monthly amortization with its first payment one month after purchase. A lender's daily-interest ledger, dates and rounding can differ slightly. Five- and ten-year projections hold annual operating costs constant and stop loan payments at payoff. No resale value is assumed unless you enter one, and selling costs must also be explicit.</p></details>
      <details><summary>Are my estimates saved or sent to a lender?</summary><p>Calculation happens in your browser. Nothing is sent to a lender. Browser saving is optional, limited to this device/browser and expires after 180 days. A share link exposes its figures to anyone who has the link and cannot be revoked. Names stay out of share links.</p></details>
      <details><summary>Does the Trip Planner receive these boat figures?</summary><p>No. The link opens FPW's existing trip-planning entry. A free account is required to plan and save a trip. This calculator does not create a vessel or transfer its assumptions into your account.</p></details>
    </section>
    <section class="bc-closing-cta bc-no-print" aria-labelledby="bc-closing-cta-title">
      <h2 id="bc-closing-cta-title">Turn your boating plans into a safer trip</h2>
      <p>Plan your route, then prepare a float plan to share with someone ashore.</p>
      <cfoutput><a class="bc-cta-button" href="#encodeForHTMLAttribute(fpwCostPlannerUrl)#" data-boat-cost-placement="after_faq">Start Planning Your Trip</a></cfoutput>
      <p class="bc-cta-note">Free account required to plan and save a trip. These figures are not transferred.</p>
    </section>
    <section aria-labelledby="bc-methodology">
      <h2 id="bc-methodology">Methodology and exclusions</h2>
      <p>Loan principal equals boat price minus down payment plus financed purchase tax and fees. Cash for purchase equals down payment plus cash-paid purchase tax and fees. Preparation is counted once. Monthly boating budget equals the loan payment plus one twelfth of annual operating expenses and annual repair savings.</p>
      <p>First-year spending adds purchase cash, preparation, the first 12 scheduled loan payments and annual operations. The first-year funding target adds initial and annual repair savings. A horizon's optional resale-adjusted cost equals cash spent plus remaining loan balance plus selling costs minus assumed resale. Do not add depreciation or the whole purchase price again.</p>
      <p>Entered monetary values and percentage-derived charges use cents with half-up rounding; amortization retains full precision until display. Independently rounded displayed rows can produce small differences from their rounded total. A display rounding adjustment reconciles the monthly rows to the headline when needed. Long-term projections exclude inflation, future cost growth, investment returns, refinancing and unplanned repairs not entered here. Adjustable-rate, balloon and interest-only loans, extra payments, trade-ins, negative equity and foreign currencies are not modeled.</p>
      <p>Planning estimate, not a loan, insurance, tax, or repair quote. Results depend on the assumptions shown. Actual costs and lender terms may differ. Repair savings are money set aside, not a prediction of repair bills. Confirm costs with lenders, insurers, marinas, tax authorities, and qualified marine professionals before buying.</p>
      <p>Category guidance: <a href="https://www.discoverboating.com/buying/costs-of-boat-ownership">Discover Boating ownership costs</a>. Borrowing terminology: <a href="https://www.consumerfinance.gov/ask-cfpb/what-is-the-difference-between-a-loan-interest-rate-and-the-apr-en-733/">CFPB interest rate and APR</a>. Model and illustrative assumptions version 1.0, September 19, 2026.</p>
    </section>
  </div>
</main>
<cfinclude template="../includes/footer.cfm">
</body>
</html>
