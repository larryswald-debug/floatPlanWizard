<!-- FPW Conversion Landing Page Mockup Partial -->
<cfset landingCreditModelEnabled = (
  structKeyExists(application, "premiumSendCreditModelEnabled")
  AND listFindNoCase("1,true,yes,on", lCase(trim(toString(application.premiumSendCreditModelEnabled)))) GT 0
)>
<cfset landingOneTripDisplayAmount = structKeyExists(application, "oneTripDisplayAmount") ? trim(toString(application.oneTripDisplayAmount)) : "">
<cfset landingOneTripCheckoutAvailable = (
  landingCreditModelEnabled
  AND structKeyExists(application, "oneTripCheckoutAvailable")
  AND application.oneTripCheckoutAvailable
  AND len(landingOneTripDisplayAmount)
)>
<div class="fpw-landing-page" id="fpwConversionLanding">
  <svg aria-hidden="true" focusable="false" width="0" height="0" style="position:absolute;left:-9999px;overflow:hidden;">
    <symbol id="fpw-i-pencil" viewBox="0 0 24 24"><path d="M4 20h4.5L19.2 9.3a2.1 2.1 0 0 0 0-3L17.7 4.8a2.1 2.1 0 0 0-3 0L4 15.5V20Z" fill="none" stroke="currentColor" stroke-width="2" stroke-linejoin="round"/><path d="m13.5 6 4.5 4.5M4 15.5 8.5 20" stroke="currentColor" stroke-width="2" stroke-linecap="round"/></symbol>
    <symbol id="fpw-i-play" viewBox="0 0 24 24"><circle cx="12" cy="12" r="9" fill="none" stroke="currentColor" stroke-width="2"/><path d="m10 8 6 4-6 4V8Z" fill="currentColor"/></symbol>
    <symbol id="fpw-i-clock" viewBox="0 0 24 24"><circle cx="12" cy="12" r="8.5" fill="none" stroke="currentColor" stroke-width="2"/><path d="M12 7v5l3 2" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"/></symbol>
    <symbol id="fpw-i-route" viewBox="0 0 24 24"><path d="M6 18c3-7 9 1 12-6" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"/><circle cx="6" cy="18" r="2" fill="none" stroke="currentColor" stroke-width="2"/><circle cx="18" cy="12" r="2" fill="none" stroke="currentColor" stroke-width="2"/><circle cx="10" cy="6" r="2" fill="none" stroke="currentColor" stroke-width="2"/></symbol>
    <symbol id="fpw-i-lock" viewBox="0 0 24 24"><rect x="5" y="10" width="14" height="10" rx="2" fill="none" stroke="currentColor" stroke-width="2"/><path d="M8 10V7a4 4 0 0 1 8 0v3" fill="none" stroke="currentColor" stroke-width="2"/><path d="M12 14v3" stroke="currentColor" stroke-width="2" stroke-linecap="round"/></symbol>
    <symbol id="fpw-i-user" viewBox="0 0 24 24"><circle cx="12" cy="8" r="4" fill="none" stroke="currentColor" stroke-width="2"/><path d="M4 21a8 8 0 0 1 16 0" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"/></symbol>
    <symbol id="fpw-i-radio" viewBox="0 0 24 24"><path d="M12 18v3M8 21h8" stroke="currentColor" stroke-width="2" stroke-linecap="round"/><circle cx="12" cy="11" r="2" fill="currentColor"/><path d="M8 7a6 6 0 0 0 0 8M16 7a6 6 0 0 1 0 8M5 4a10 10 0 0 0 0 14M19 4a10 10 0 0 1 0 14" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"/></symbol>
    <symbol id="fpw-i-pin" viewBox="0 0 24 24"><path d="M12 22s7-7 7-13A7 7 0 0 0 5 9c0 6 7 13 7 13Z" fill="none" stroke="currentColor" stroke-width="2"/><circle cx="12" cy="9" r="2.5" fill="none" stroke="currentColor" stroke-width="2"/></symbol>
    <symbol id="fpw-i-boat" viewBox="0 0 24 24"><path d="M3 15h18l-3 5H6l-3-5Z" fill="none" stroke="currentColor" stroke-width="2" stroke-linejoin="round"/><path d="M7 15V9h7l3 6M9 9V5h3" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></symbol>
    <symbol id="fpw-i-wheel" viewBox="0 0 24 24"><circle cx="12" cy="12" r="6" fill="none" stroke="currentColor" stroke-width="2"/><circle cx="12" cy="12" r="2" fill="none" stroke="currentColor" stroke-width="2"/><path d="M12 2v4M12 18v4M2 12h4M18 12h4M4.9 4.9l2.8 2.8M16.3 16.3l2.8 2.8M19.1 4.9l-2.8 2.8M7.7 16.3l-2.8 2.8" stroke="currentColor" stroke-width="2" stroke-linecap="round"/></symbol>
    <symbol id="fpw-i-anchor" viewBox="0 0 24 24"><circle cx="12" cy="5" r="2.5" fill="none" stroke="currentColor" stroke-width="2"/><path d="M12 8v12M6 12h12M5 17c1.3 2 3.6 3 7 3s5.7-1 7-3M5 17l-2-2M19 17l2-2" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"/></symbol>
    <symbol id="fpw-i-shield" viewBox="0 0 24 24"><path d="M12 3 20 6v6c0 5-3.4 8-8 9-4.6-1-8-4-8-9V6l8-3Z" fill="none" stroke="currentColor" stroke-width="2"/><path d="m8.5 12 2.3 2.3L15.8 9" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></symbol>
    <symbol id="fpw-i-card" viewBox="0 0 24 24"><rect x="3" y="6" width="18" height="12" rx="2" fill="none" stroke="currentColor" stroke-width="2"/><path d="M3 10h18M7 15h4" stroke="currentColor" stroke-width="2" stroke-linecap="round"/></symbol>
    <symbol id="fpw-i-life" viewBox="0 0 24 24"><circle cx="12" cy="12" r="9" fill="none" stroke="currentColor" stroke-width="2"/><circle cx="12" cy="12" r="4" fill="none" stroke="currentColor" stroke-width="2"/><path d="M12 3v5M12 16v5M3 12h5M16 12h5" stroke="currentColor" stroke-width="2"/></symbol>
    <symbol id="fpw-i-sail" viewBox="0 0 24 24"><path d="M12 3v18" stroke="currentColor" stroke-width="2" stroke-linecap="round"/><path d="M13 4c4 3 6 7 7 12h-7V4ZM11 8C8 11 6 14 5 18h6V8Z" fill="none" stroke="currentColor" stroke-width="2" stroke-linejoin="round"/><path d="M4 21h16" stroke="currentColor" stroke-width="2" stroke-linecap="round"/></symbol>
    <symbol id="fpw-i-chevron" viewBox="0 0 24 24"><path d="m7 10 5 5 5-5" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></symbol>
    <symbol id="fpw-i-arrow" viewBox="0 0 24 24"><path d="M5 12h14M13 6l6 6-6 6" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></symbol>
  </svg>

  <main>
    <section class="fpw-hero" aria-labelledby="fpwHeroTitle">
      <div class="fpw-container fpw-hero-inner">
        <div class="fpw-hero-copy">
          <h1 id="fpwHeroTitle">Plan your cruise. Share the journey. Return safely.</h1>
          <p>Build your route, organize your vessel and crew, create a complete float plan, and give friends and family a Trip Page for planned stops, estimated progress, latest check-ins, and trip updates.</p>

          <div class="fpw-hero-actions">
            <a class="fpw-btn fpw-btn-primary" href="<cfoutput>#landingBasePath#</cfoutput>/app/join.cfm" data-fpw-track="homepage_hero_primary_cta_click" data-fpw-track-label="Plan Your Trip" data-fpw-track-section="hero"><svg class="fpw-icon" aria-hidden="true"><use href="#fpw-i-pencil"></use></svg>Plan Your Trip</a>
            <a class="fpw-btn fpw-btn-secondary" href="#fpwProductPreview" data-fpw-open-preview="follow" data-fpw-track="homepage_hero_secondary_cta_click" data-fpw-track-label="See What Family Sees" data-fpw-track-section="hero"><svg class="fpw-icon" aria-hidden="true"><use href="#fpw-i-play"></use></svg>See What Family Sees</a>
          </div>

          <div class="fpw-trust-row" aria-label="Quick trust points">
            <div class="fpw-trust-item"><span class="fpw-check-dot">✓</span><span>No credit card required</span></div>
            <div class="fpw-trust-item"><span class="fpw-check-dot">✓</span><span>Route, weather, and fuel</span></div>
            <div class="fpw-trust-item"><span class="fpw-check-dot">✓</span><span>Private Trip Page</span></div>
            <div class="fpw-trust-item"><span class="fpw-check-dot">✓</span><span>No account for followers</span></div>
          </div>

          <p class="fpw-hero-disclaimer">FloatPlanWizard organizes and shares trip information. It is not a rescue or emergency-dispatch service.</p>
        </div>

        <aside class="fpw-trip-brief" aria-label="Trip brief preview">
          <div class="fpw-trip-brief-head">
            <div class="fpw-trip-title"><svg class="fpw-icon" aria-hidden="true"><use href="#fpw-i-shield"></use></svg>TRIP OVERVIEW</div>
            <span class="fpw-status-pill">PLAN &amp; SHARE</span>
          </div>

          <div class="fpw-trip-row">
            <svg class="fpw-icon" aria-hidden="true"><use href="#fpw-i-route"></use></svg>
            <strong class="fpw-trip-label">Route</strong>
            <span class="fpw-trip-value">Plan legs, stops, and timing</span>
          </div>
          <div class="fpw-trip-row">
            <svg class="fpw-icon" aria-hidden="true"><use href="#fpw-i-user"></use></svg>
            <strong class="fpw-trip-label">Trip Page</strong>
            <span class="fpw-trip-value">Share privately with family</span>
          </div>
          <div class="fpw-trip-row">
            <svg class="fpw-icon" aria-hidden="true"><use href="#fpw-i-lock"></use></svg>
            <strong class="fpw-trip-label">Float Plan</strong>
            <span class="fpw-trip-value">Prepare details for shore</span>
          </div>
          <div class="fpw-trip-row">
            <svg class="fpw-icon" aria-hidden="true"><use href="#fpw-i-clock"></use></svg>
            <strong class="fpw-trip-label">Latest Check-In</strong>
            <span class="fpw-trip-value">Captain-reported status</span>
          </div>
          <div class="fpw-trip-row">
            <svg class="fpw-icon" aria-hidden="true"><use href="#fpw-i-radio"></use></svg>
            <strong class="fpw-trip-label">Trip Status</strong>
            <span class="fpw-trip-value">Manage while underway</span>
          </div>
          <div class="fpw-trip-row">
            <svg class="fpw-icon" aria-hidden="true"><use href="#fpw-i-shield"></use></svg>
            <strong class="fpw-trip-label">Float Plan Monitoring</strong>
            <span class="fpw-trip-value">Watches expected check-ins</span>
          </div>

          <a class="fpw-btn fpw-brief-cta" href="#fpwProductPreview" data-fpw-open-preview="follow">See What Family Sees</a>
        </aside>
      </div>
    </section>

    <section class="fpw-steps" id="fpwHowItWorks" aria-labelledby="fpwStepsTitle">
      <div class="fpw-container">
        <h2 class="fpw-section-title" id="fpwStepsTitle">Everything you need from planning to safe return.</h2>
        <div class="fpw-step-row">
          <article class="fpw-step-card">
            <div class="fpw-step-icon"><svg class="fpw-icon" aria-hidden="true"><use href="#fpw-i-pin"></use></svg></div>
            <div class="fpw-step-body"><span class="fpw-step-number">1</span><h3>Plan</h3><p>Build the route and organize your vessel, operator, passengers, stops, timing, and fuel.</p></div>
          </article>
          <div class="fpw-step-dash" aria-hidden="true"></div>
          <article class="fpw-step-card">
            <div class="fpw-step-icon"><svg class="fpw-icon" aria-hidden="true"><use href="#fpw-i-user"></use></svg></div>
            <div class="fpw-step-body"><span class="fpw-step-number">2</span><h3>Share</h3><p>Create the float plan and share a Private Trip Page with friends, family, and your shore contact.</p></div>
          </article>
          <div class="fpw-step-dash" aria-hidden="true"></div>
          <article class="fpw-step-card">
            <div class="fpw-step-icon"><svg class="fpw-icon" aria-hidden="true"><use href="#fpw-i-radio"></use></svg></div>
            <div class="fpw-step-body"><span class="fpw-step-number">3</span><h3>Manage</h3><p>Check in, update trip status, record delays or plan changes, and use Float Plan Monitoring for the expected check-in schedule while underway.</p></div>
          </article>
        </div>
      </div>
    </section>

    <section class="fpw-product-preview" id="fpwProductPreview" aria-labelledby="fpwPreviewTitle">
      <div class="fpw-container">
        <div class="fpw-preview-shell" data-preview-asset-base="<cfoutput>#landingBasePath#</cfoutput>/assets/images/home/">
          <div class="fpw-preview-head">
            <h2 class="fpw-section-title" id="fpwPreviewTitle">See how the whole trip stays connected.</h2>
            <p class="fpw-section-intro fpw-preview-intro">Plan the route, share the journey, and manage the trip underway.</p>
            <div class="fpw-tabs" role="tablist" aria-label="FloatPlanWizard product preview">
              <button class="fpw-tab" id="fpw-preview-tab-follow" type="button" role="tab" aria-selected="true" aria-controls="fpwPreviewPanel" data-preview-tab="follow" data-fpw-track="homepage_demo_tab_click" data-fpw-track-label="Trip Page" data-fpw-track-section="product_demo">Trip Page</button>
              <button class="fpw-tab" id="fpw-preview-tab-route" type="button" role="tab" aria-selected="false" aria-controls="fpwPreviewPanel" data-preview-tab="route" data-fpw-track="homepage_demo_tab_click" data-fpw-track-label="Route Generator" data-fpw-track-section="product_demo">Route Generator</button>
              <button class="fpw-tab" id="fpw-preview-tab-active" type="button" role="tab" aria-selected="false" aria-controls="fpwPreviewPanel" data-preview-tab="active" data-fpw-track="homepage_demo_tab_click" data-fpw-track-label="Active Cruise" data-fpw-track-section="product_demo">Active Cruise</button>
              <button class="fpw-tab" id="fpw-preview-tab-dashboard" type="button" role="tab" aria-selected="false" aria-controls="fpwPreviewPanel" data-preview-tab="dashboard" data-fpw-track="homepage_demo_tab_click" data-fpw-track-label="Dashboard" data-fpw-track-section="product_demo">Dashboard</button>
            </div>
          </div>

          <div class="fpw-preview-body">
            <div class="fpw-preview-visual">
              <div class="fpw-preview-browser">
                <div class="fpw-preview-browser-chrome" aria-hidden="true">
                  <span></span><span></span><span></span>
                </div>
                <img
                  src="<cfoutput>#landingBasePath#</cfoutput>/assets/images/home/preview-follow-page.png"
                  alt="Representative FloatPlanWizard private Trip Page showing a planned route, estimated trip progress, and latest check-in."
                  class="fpw-preview-image"
                  data-preview-image
                  loading="eager"
                  decoding="async"
                >
              </div>
            </div>

            <aside class="fpw-preview-copy" id="fpwPreviewPanel" role="tabpanel" aria-live="polite" aria-labelledby="fpw-preview-tab-follow">
              <h3 data-preview-title>Share the journey.</h3>
              <p data-preview-body>Friends and family can use one invitation link to see the planned route, stops, estimated trip progress, latest check-in, and trip updates.</p>
              <ul class="fpw-check-list" data-preview-list>
                <li><span class="fpw-check-dot">✓</span><span>Only people you invite can view the trip</span></li>
                <li><span class="fpw-check-dot">✓</span><span>No FPW account needed for followers</span></li>
                <li><span class="fpw-check-dot">✓</span><span>Latest check-ins, updates, photos, and comments</span></li>
              </ul>
              <a class="fpw-product-link" data-preview-link href="<cfoutput>#landingBasePath#</cfoutput>/app/join.cfm">Plan Your Trip <svg class="fpw-icon" aria-hidden="true"><use href="#fpw-i-arrow"></use></svg></a>
            </aside>
          </div>
        </div>
      </div>
    </section>

    <section class="fpw-compare fpw-audiences" id="fpwFeatures" aria-labelledby="fpwCompareTitle">
      <div class="fpw-container">
        <h2 class="fpw-section-title" id="fpwCompareTitle">Built for the captain—and everyone following from shore.</h2>
        <p class="fpw-section-intro fpw-compare-intro">One connected trip workflow helps the captain prepare and manage the cruise while giving friends, family, and shore contacts the ability to follow along and see where you are.</p>
        <div class="fpw-compare-panels" aria-label="FloatPlanWizard benefits for captains and people following from shore">
          <article class="fpw-compare-card fpw-compare-card-muted">
            <h3>For the captain</h3>
            <ul>
              <li><span class="fpw-yes">✓</span><span>Plan route legs, waypoints, stops, and timing</span></li>
              <li><span class="fpw-yes">✓</span><span>Organize the vessel, operator, passengers, weather, and fuel</span></li>
              <li><span class="fpw-yes">✓</span><span>Create the float plan and shore-contact information</span></li>
              <li><span class="fpw-yes">✓</span><span>Check in, report changes, and use Float Plan Monitoring while underway</span></li>
            </ul>
          </article>
          <article class="fpw-compare-card fpw-compare-card-strong">
            <h3>For friends and family</h3>
            <ul>
              <li><span class="fpw-yes">✓</span><span>Open the shared Trip Page without an FPW account</span></li>
              <li><span class="fpw-yes">✓</span><span>Follow the planned route, destinations, and stops</span></li>
              <li><span class="fpw-yes">✓</span><span>View estimated trip progress, the latest check-in, and whether an expected check-in was missed</span></li>
              <li><span class="fpw-yes">✓</span><span>See trip updates, comments and shared photos</span></li>
              <li><span class="fpw-yes">✓</span><span>Stay connected without repeatedly calling or texting the captain</span></li>
            </ul>
          </article>
        </div>
        <div class="fpw-audience-trust">
          <h3 class="fpw-audience-trust-title">Built-in safety from departure to safe return.</h3>
          <p>FPW connects your float plan, Private Trip Page, check-ins, and monitoring so the captain and shore contact stay informed throughout the trip.</p>
          <div class="fpw-trust-grid fpw-audience-trust-grid">
            <article class="fpw-trust-card"><svg class="fpw-icon" aria-hidden="true"><use href="#fpw-i-lock"></use></svg><div><h3>Private by default</h3><p>The Trip Page is not public. It's for freinds and family to follow you during your trip</p></div></article>
            <article class="fpw-trust-card"><svg class="fpw-icon" aria-hidden="true"><use href="#fpw-i-user"></use></svg><div><h3>Shared by invitation</h3><p>The captain chooses who receives the Trip Page link and followers do not need an account.</p></div></article>
            <article class="fpw-trust-card"><svg class="fpw-icon" aria-hidden="true"><use href="#fpw-i-shield"></use></svg><div><h3>Useful information ashore</h3><p>The float plan gives the shore contact organized trip details, and planned departure and return times.</p></div></article>
            <article class="fpw-trust-card fpw-monitoring-card"><svg class="fpw-icon" aria-hidden="true"><use href="#fpw-i-clock"></use></svg><div><h3>Float Plan Monitoring</h3><p>FPW watches the expected check-in schedule. If a check-in is missed or remains unresolved, the trip may need attention and FPW can notify the captain or selected trip contacts.</p><p class="fpw-monitoring-note">Automated schedule monitoring—not emergency dispatch or rescue monitoring.</p></div></article>
          </div>
          <p class="fpw-audience-safety-note">FloatPlanWizard organizes and shares trip information. It is not a rescue, dispatch, or emergency response service.</p>
        </div>
      </div>
    </section>

    <section class="fpw-use-cases" aria-labelledby="fpwUseTitle">
      <div class="fpw-container">
        <h2 class="fpw-section-title" id="fpwUseTitle">Built for day trips, weekends, and extended cruises.</h2>
        <p class="fpw-section-intro fpw-use-intro">From a short local run to an extended cruise, FPW connects planning, the float plan, the shared Trip Page, and underway updates.</p>
        <div class="fpw-use-grid">
          <article class="fpw-use-card"><svg class="fpw-icon" aria-hidden="true"><use href="#fpw-i-boat"></use></svg><div><h3>Local Day Trips</h3><p>Plan the route, estimate timing, share the Trip Page, and confirm safe return.</p></div></article>
          <article class="fpw-use-card"><svg class="fpw-icon" aria-hidden="true"><use href="#fpw-i-pin"></use></svg><div><h3>Fishing Trips</h3><p>Share the general route, planned fishing areas, passengers, timing, and latest check-ins.</p></div></article>
          <article class="fpw-use-card"><svg class="fpw-icon" aria-hidden="true"><use href="#fpw-i-anchor"></use></svg><div><h3>Weekend Cruising</h3><p>Plan multiple stops, overnight status, daily departures, and family updates.</p></div></article>
          <article class="fpw-use-card"><svg class="fpw-icon" aria-hidden="true"><use href="#fpw-i-wheel"></use></svg><div><h3>Great Loop &amp; Extended Cruises</h3><p>Manage multi-leg routes, changing plans, overnight stops, and shared trip progress.</p></div></article>
        </div>
      </div>
    </section>

    <section class="fpw-pricing" id="fpwPricing" aria-labelledby="fpwPricingTitle">
      <div class="fpw-container">
        <cfif landingCreditModelEnabled>
          <h2 class="fpw-section-title" id="fpwPricingTitle">Plan for free. Add Premium when the trip needs it.</h2>
          <p class="fpw-section-intro fpw-pricing-intro">Full planning and Basic sending are included. New members receive their first complete Premium trip for free, with one-trip, monthly, and annual Premium options available when needed.</p>
          <div class="fpw-price-grid">
            <article class="fpw-price-card fpw-price-card-free"><h3>Free Membership</h3><div class="fpw-price">$0</div><p>Full planning and Basic sending.</p><ul><li>Route Builder and generated routes</li><li>Saved boats, people, contacts, and waypoints</li><li>Multiple Drafts</li><li>Basic float-plan sending</li><li>First Premium trip for new members</li></ul><a class="fpw-card-link" href="<cfoutput>#landingBasePath#</cfoutput>/app/join.cfm" data-fpw-track="homepage_pricing_cta_click" data-fpw-track-label="Create Free Account" data-fpw-track-plan="Free Membership" data-fpw-track-section="pricing">Create Free Account</a></article>
            <article class="fpw-price-card"><h3>Buy One Trip</h3><div class="fpw-price"><cfif landingOneTripCheckoutAvailable><cfoutput>#encodeForHTML(landingOneTripDisplayAmount)#</cfoutput><cfelse>Unavailable</cfif></div><p class="fpw-price-note">No subscription</p><p>One complete Premium trip.</p><ul><li>Premium PDF/email delivery</li><li>Active Cruise</li><li>Float Plan Monitoring</li><li>Private Trip Page</li><li>Exact-plan operational access</li></ul><a class="fpw-card-link" href="<cfoutput>#landingBasePath#</cfoutput>/app/pricing.cfm" data-fpw-track="homepage_pricing_cta_click" data-fpw-track-label="Buy One Trip" data-fpw-track-plan="Buy One Trip" data-fpw-track-section="pricing">View One Trip</a></article>
            <article class="fpw-price-card"><h3>Premium Monthly</h3><div class="fpw-price">$9.99 <span>/ month</span></div><p class="fpw-price-note">Cancel anytime</p><p>General Premium for frequent trips.</p><ul><li>Premium Save &amp; Send</li><li>Active Cruise</li><li>Float Plan Monitoring</li><li>Private Trip Page</li></ul><a class="fpw-card-link" href="<cfoutput>#landingBasePath#</cfoutput>/app/pricing.cfm" data-fpw-track="homepage_pricing_cta_click" data-fpw-track-label="Start Monthly Premium" data-fpw-track-plan="Premium Monthly" data-fpw-track-section="pricing">View Monthly</a></article>
            <article class="fpw-price-card popular"><div class="fpw-price-ribbon">BEST VALUE</div><h3>Premium Annual</h3><div class="fpw-price">$89 <span>/ year</span></div><p class="fpw-price-note">Save about 25% vs monthly</p><p>General Premium all year.</p><ul><li>Premium Save &amp; Send</li><li>Active Cruise</li><li>Float Plan Monitoring</li><li>Private Trip Page</li></ul><a class="fpw-card-link" href="<cfoutput>#landingBasePath#</cfoutput>/app/pricing.cfm" data-fpw-track="homepage_pricing_cta_click" data-fpw-track-label="Start Annual Premium" data-fpw-track-plan="Premium Annual" data-fpw-track-section="pricing">View Annual</a></article>
          </div>
        <cfelse>
          <h2 class="fpw-section-title" id="fpwPricingTitle">Start with a free float plan. Upgrade when you want active-trip tools.</h2>
          <p class="fpw-section-intro fpw-pricing-intro">Create a simple float plan first. Add route planning, Active Cruise, shared trip updates, and monitoring tools when you need more than a printable plan.</p>
          <div class="fpw-price-grid">
            <article class="fpw-price-card fpw-price-card-free"><h3>Free</h3><div class="fpw-price">$0</div><p>For simple day trips and printable float plans.</p><ul><li>Basic float plan</li><li>Basic monitoring</li><li>NOAA/NWS Marine Weather</li><li>Same-day trip use</li></ul><a class="fpw-card-link" href="<cfoutput>#landingBasePath#</cfoutput>/app/start-trial.cfm?offer=launch_trial" data-fpw-track="homepage_pricing_cta_click" data-fpw-track-label="Create Free Plan" data-fpw-track-plan="Free" data-fpw-track-section="pricing">Create Free Plan</a></article>
            <article class="fpw-price-card"><h3>Premium Monthly</h3><div class="fpw-price">$9.99 <span>/ month</span></div><p class="fpw-price-note">Cancel anytime</p><p>For boaters who want route planning, Active Cruise, check-ins, and shared trip updates.</p><ul><li>Custom Route Generator</li><li>Active Cruise</li><li>Private Trip Page</li><li>Mobile check-ins</li><li>GPS check-in support</li> <li>Float Plan Monitoring</li><li>NOAA/NWS Marine Weather</li><li>NOAA Nautical Charts</li><li>Premium route tools</li></ul><a class="fpw-card-link" href="<cfoutput>#landingBasePath#</cfoutput>/app/start-trial.cfm?offer=launch_trial" data-fpw-track="homepage_pricing_cta_click" data-fpw-track-label="Start Monthly Premium" data-fpw-track-plan="Premium Monthly" data-fpw-track-section="pricing">Start Monthly Premium</a></article>
            <article class="fpw-price-card popular"><div class="fpw-price-ribbon">BEST VALUE</div><h3>Premium Annual</h3><div class="fpw-price">$89 <span>/ year</span></div><p class="fpw-price-note">Save about 25% vs monthly</p><p>For regular boaters who want FPW available all season.</p><ul><li>Custom Route Generator</li><li>Active Cruise</li><li>Private Trip Page</li><li>Mobile check-ins</li><li>GPS check-in support</li><li>Float Plan Monitoring</li><li>NOAA/NWS Marine Weather</li><li>NOAA Nautical Charts</li><li>Premium route tools</li></ul><a class="fpw-card-link" href="<cfoutput>#landingBasePath#</cfoutput>/app/start-trial.cfm?offer=launch_trial" data-fpw-track="homepage_pricing_cta_click" data-fpw-track-label="Start Annual Premium" data-fpw-track-plan="Premium Annual" data-fpw-track-section="pricing">Start Annual Premium</a></article>
            <article class="fpw-price-card"><h3>3-Day Pass</h3><div class="fpw-price">$4.99</div><p class="fpw-price-note">No subscription</p><p>For a short trip, weekend cruise, or one-time planned outing.</p><ul><li>Custom Route Generator</li><li>Active Cruise</li><li>Private Trip Page</li><li>Mobile check-ins</li><li>GPS check-in support</li><li>Float Plan Monitoring</li><li>NOAA/NWS Marine Weather</li><li>NOAA Nautical Charts</li><li>Premium route tools</li><li>Valid for 3 consecutive days</li></ul><a class="fpw-card-link" href="<cfoutput>#landingBasePath#</cfoutput>/app/start-trial.cfm?offer=launch_trial" data-fpw-track="homepage_pricing_cta_click" data-fpw-track-label="Get 3-Day Pass" data-fpw-track-plan="3-Day Pass" data-fpw-track-section="pricing">Get 3-Day Pass</a></article>
          </div>
        </cfif>
      </div>
    </section>

    <section class="fpw-faq" aria-labelledby="fpwFaqTitle">
      <div class="fpw-container">
        <h2 class="fpw-section-title" id="fpwFaqTitle">Questions boaters ask before using FPW.</h2>
        <p class="fpw-section-intro fpw-faq-intro">Learn how planning, the float plan, the shared Trip Page, and underway updates work together.</p>
        <div class="fpw-faq-grid">
          <div class="fpw-faq-item"><button class="fpw-faq-question" type="button" aria-expanded="false" aria-controls="fpwFaqShoreContacts" data-fpw-track-label="Do followers need an account?">Do followers need an account?<svg class="fpw-icon" aria-hidden="true"><use href="#fpw-i-chevron"></use></svg></button><div class="fpw-faq-answer" id="fpwFaqShoreContacts">No. Friends, family, and the shore contact can open a Private Trip Page without an FPW account when they use a valid shared link.</div></div>
          <div class="fpw-faq-item"><button class="fpw-faq-question" type="button" aria-expanded="false" aria-controls="fpwFaqTripPage" data-fpw-track-label="What does the Trip Page show?">What does the Trip Page show?<svg class="fpw-icon" aria-hidden="true"><use href="#fpw-i-chevron"></use></svg></button><div class="fpw-faq-answer" id="fpwFaqTripPage">It can show the planned route, destinations and stops, estimated trip progress, latest captain check-in or update, trip photos,and the latest reported position when a check-in includes one. It does not continuously track the vessel.</div></div>
          <div class="fpw-faq-item"><button class="fpw-faq-question" type="button" aria-expanded="false" aria-controls="fpwFaqEmergency" data-fpw-track-label="Is FPW an emergency response service?">Does FloatPlanWizard contact emergency services?<svg class="fpw-icon" aria-hidden="true"><use href="#fpw-i-chevron"></use></svg></button><div class="fpw-faq-answer" id="fpwFaqEmergency">No. FloatPlanWizard organizes and shares trip information, but it is not an emergency-dispatch or rescue service. In an emergency, contact 911, the U.S. Coast Guard, or the appropriate local authority directly.</div></div>
          <div class="fpw-faq-item"><button class="fpw-faq-question" type="button" aria-expanded="false" aria-controls="fpwFaqPrint" data-fpw-track-label="Can I print my float plan?">Can I print or download my float plan?<svg class="fpw-icon" aria-hidden="true"><use href="#fpw-i-chevron"></use></svg></button><div class="fpw-faq-answer" id="fpwFaqPrint">Yes. FPW provides printable or downloadable float-plan output so you can keep a copy, email it, or give it to your shore contact.</div></div>
          <div class="fpw-faq-item"><button class="fpw-faq-question" type="button" aria-expanded="false" aria-controls="fpwFaqDayTrips" data-fpw-track-label="Can I use FPW for day trips?">Can I use FPW for day trips?<svg class="fpw-icon" aria-hidden="true"><use href="#fpw-i-chevron"></use></svg></button><div class="fpw-faq-answer" id="fpwFaqDayTrips">Yes. FPW supports short local trips and fishing runs as well as weekend, multi-stop, Great Loop, and extended cruises.</div></div>
          <div class="fpw-faq-item"><button class="fpw-faq-question" type="button" aria-expanded="false" aria-controls="fpwFaqTripChanges" data-fpw-track-label="What happens if my trip changes?">What happens if my trip changes?<svg class="fpw-icon" aria-hidden="true"><use href="#fpw-i-chevron"></use></svg></button><div class="fpw-faq-answer" id="fpwFaqTripChanges">The captain can check in, report a delay or changed plan, update timing, and manage route legs underway. The Trip Page then reflects the latest reported trip information.</div></div>
          <div class="fpw-faq-item fpw-faq-item-monitoring"><button class="fpw-faq-question" type="button" aria-expanded="false" aria-controls="fpwFaqMonitoring" data-fpw-track-label="What does Float Plan Monitoring do?">What does Float Plan Monitoring do?<svg class="fpw-icon" aria-hidden="true"><use href="#fpw-i-chevron"></use></svg></button><div class="fpw-faq-answer" id="fpwFaqMonitoring">Float Plan Monitoring compares a trip's expected check-in schedule with recorded check-ins. If an expected check-in is missed, FPW can notify the captain; if it remains unresolved after the configured delay, FPW can notify selected trip contacts that the trip may need attention. Notices are automated and delivery is not guaranteed. FPW does not verify emergencies or dispatch assistance.</div></div>
        </div>
      </div>
    </section>

    <section class="fpw-final-cta" aria-labelledby="fpwFinalTitle">
      <div class="fpw-container fpw-final-inner">
        <div class="fpw-final-copy">
          <h2 id="fpwFinalTitle">Plan the trip. Bring everyone along.</h2>
          <p>Create your route, organize the details, share a Trip Page with friends and family, and build the float plan your shore contact needs.</p>
        </div>
        <div class="fpw-final-action">
          <a class="fpw-btn fpw-btn-primary" href="<cfoutput>#landingBasePath#</cfoutput>/app/join.cfm" data-fpw-track="homepage_final_cta_click" data-fpw-track-label="Plan Your Trip" data-fpw-track-section="final_cta"><svg class="fpw-icon" aria-hidden="true"><use href="#fpw-i-pencil"></use></svg>Plan Your Trip</a>
          <p>No credit card required. Takes just a few minutes.</p>
        </div>
      </div>
    </section>
  </main>
</div>
