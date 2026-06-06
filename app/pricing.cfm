<cfprocessingdirective pageencoding="utf-8">
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Membership Plans | FloatPlanWizard</title>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="description" content="Compare FloatPlanWizard membership options for creating float plans, planning boat routes, sharing trip updates, and using premium boating tools.">
  <link rel="canonical" href="https://floatplanwizard.com/app/pricing.cfm">
  <meta property="og:type" content="website">
  <meta property="og:site_name" content="FloatPlanWizard">
  <meta property="og:url" content="https://floatplanwizard.com/app/pricing.cfm">
  <meta property="og:title" content="Membership Plans | FloatPlanWizard">
  <meta property="og:description" content="Compare FloatPlanWizard membership options for float plans, route planning, shared trip updates, and premium boating tools.">
  <meta property="og:image" content="https://floatplanwizard.com/assets/images/social/floatplanwizard-social-preview-20260602.png">
  <meta property="og:image:secure_url" content="https://floatplanwizard.com/assets/images/social/floatplanwizard-social-preview-20260602.png">
  <meta property="og:image:type" content="image/png">
  <meta property="og:image:width" content="1200">
  <meta property="og:image:height" content="630">
  <meta property="og:image:alt" content="FloatPlanWizard boating trip planning and monitored float plan preview image">
  <meta name="twitter:card" content="summary_large_image">
  <meta name="twitter:title" content="Membership Plans | FloatPlanWizard">
  <meta name="twitter:description" content="Compare FloatPlanWizard membership options for float plans, route planning, shared trip updates, and premium boating tools.">
  <meta name="twitter:image" content="https://floatplanwizard.com/assets/images/social/floatplanwizard-social-preview-20260602.png">
  <meta name="twitter:image:alt" content="FloatPlanWizard boating trip planning and monitored float plan preview image">

  <cfinclude template="../includes/fpw_base_path.cfm">
  <cfinclude template="../includes/header_styles.cfm">
  <link rel="stylesheet" href="<cfoutput>#request.fpwBase#</cfoutput>/assets/css/pricing.css?v=20260526-cache-bump">
</head>
<body>

<cfinclude template="../includes/prelaunch_top_nav.cfm">

<main class="fpw-pricing-page">
  <svg aria-hidden="true" class="fpw-pricing-icons" width="0" height="0" style="position:absolute">
    <symbol id="fpw-icon-users" viewBox="0 0 24 24">
      <path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
      <circle cx="9" cy="7" r="4" fill="none" stroke="currentColor" stroke-width="2"/>
      <path d="M22 21v-2a4 4 0 0 0-3-3.87" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
      <path d="M16 3.13a4 4 0 0 1 0 7.75" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
    </symbol>

    <symbol id="fpw-icon-calendar" viewBox="0 0 24 24">
      <rect x="3" y="4" width="18" height="18" rx="2" fill="none" stroke="currentColor" stroke-width="2"/>
      <path d="M16 2v4M8 2v4M3 10h18" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
    </symbol>

    <symbol id="fpw-icon-star" viewBox="0 0 24 24">
      <path d="m12 2 3.09 6.26L22 9.27l-5 4.87L18.18 21 12 17.77 5.82 21 7 14.14l-5-4.87 6.91-1.01L12 2Z" fill="none" stroke="currentColor" stroke-width="2" stroke-linejoin="round"/>
    </symbol>

    <symbol id="fpw-icon-clock" viewBox="0 0 24 24">
      <circle cx="12" cy="12" r="10" fill="none" stroke="currentColor" stroke-width="2"/>
      <path d="M12 6v6l4 2" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
    </symbol>

    <symbol id="fpw-icon-route" viewBox="0 0 24 24">
      <circle cx="6" cy="19" r="3" fill="none" stroke="currentColor" stroke-width="2"/>
      <circle cx="18" cy="5" r="3" fill="none" stroke="currentColor" stroke-width="2"/>
      <path d="M9 19h3a4 4 0 0 0 0-8h-1a4 4 0 0 1 0-8h4" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
    </symbol>

    <symbol id="fpw-icon-waves" viewBox="0 0 24 24">
      <path d="M2 8c2 0 2-2 4-2s2 2 4 2 2-2 4-2 2 2 4 2 2-2 4-2" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
      <path d="M2 14c2 0 2-2 4-2s2 2 4 2 2-2 4-2 2 2 4 2 2-2 4-2" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
      <path d="M2 20c2 0 2-2 4-2s2 2 4 2 2-2 4-2 2 2 4 2 2-2 4-2" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
    </symbol>

    <symbol id="fpw-icon-follow" viewBox="0 0 24 24">
      <circle cx="9" cy="7" r="4" fill="none" stroke="currentColor" stroke-width="2"/>
      <path d="M3 21v-2a4 4 0 0 1 4-4h4" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
      <path d="M17 11l2 2 3-5" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
      <path d="M17 21v-5" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
    </symbol>

    <symbol id="fpw-icon-phone" viewBox="0 0 24 24">
      <rect x="7" y="2" width="10" height="20" rx="2" fill="none" stroke="currentColor" stroke-width="2"/>
      <path d="M11 18h2" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
    </symbol>

    <symbol id="fpw-icon-pin" viewBox="0 0 24 24">
      <path d="M12 22s7-5.2 7-12a7 7 0 1 0-14 0c0 6.8 7 12 7 12Z" fill="none" stroke="currentColor" stroke-width="2"/>
      <circle cx="12" cy="10" r="2.5" fill="none" stroke="currentColor" stroke-width="2"/>
    </symbol>

    <symbol id="fpw-icon-tools" viewBox="0 0 24 24">
      <path d="M14.7 6.3a4 4 0 0 0 5 5L11 20l-4-4 8.7-8.7Z" fill="none" stroke="currentColor" stroke-width="2" stroke-linejoin="round"/>
      <path d="M5 8 2 5l3-3 3 3" fill="none" stroke="currentColor" stroke-width="2" stroke-linejoin="round"/>
      <path d="m7 6 4 4" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
    </symbol>

    <symbol id="fpw-icon-pdf" viewBox="0 0 24 24">
      <path d="M6 2h8l4 4v16H6Z" fill="none" stroke="currentColor" stroke-width="2" stroke-linejoin="round"/>
      <path d="M14 2v5h5" fill="none" stroke="currentColor" stroke-width="2" stroke-linejoin="round"/>
      <path d="M8 15h8M8 18h5M8 12h8" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
    </symbol>

    <symbol id="fpw-icon-check" viewBox="0 0 24 24">
      <path d="M20 6 9 17l-5-5" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/>
    </symbol>

    <symbol id="fpw-icon-x" viewBox="0 0 24 24">
      <path d="M18 6 6 18M6 6l12 12" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round"/>
    </symbol>
  </svg>

  <section class="pricing-hero">
    <div class="pricing-hero-bg" aria-hidden="true"></div>
    <div class="pricing-container pricing-hero-content">
      <h1>Membership Plans</h1>
      <p class="pricing-subtitle">Free for simple same-day trips. Premium for route-based planning, Active Cruise, Follow pages, and companion check-ins.</p>
      <p class="pricing-subnote">All paid plans include the same Premium features. Choose Monthly, Annual, or a 3-Day Pass based on how you boat.</p>
    </div>
  </section>

  <section class="pricing-container pricing-plans" aria-label="Membership plans">
    <article class="pricing-card pricing-card-free">
      <div class="pricing-card-icon"><svg class="pricing-icon"><use href="#fpw-icon-users"></use></svg></div>
      <h2>Free</h2>
      <div class="pricing-price">$0</div>
      <p class="pricing-kicker">Basic Float Plan</p>
      <p class="pricing-desc">For simple local same-day boating trips.</p>
      <ul class="pricing-feature-list">
        <li><span class="pricing-check"></span>Basic float plan</li>
        <li><span class="pricing-check"></span>Up to 2 waypoints</li>
        <li><span class="pricing-check"></span>Basic monitoring</li>
        <li><span class="pricing-check"></span>NOOA/NWS Marine Weather</li>
        <li><span class="pricing-check"></span>Same-day trip use</li>
      </ul>
      <a class="pricing-btn pricing-btn-outline" href="<cfoutput>#request.fpwBase#</cfoutput>/app/start-trial.cfm?offer=launch_trial">Create Free Account</a>
    </article>

    <article class="pricing-card">
      <div class="pricing-card-icon"><svg class="pricing-icon"><use href="#fpw-icon-calendar"></use></svg></div>
      <h2>Premium Monthly</h2>
      <div class="pricing-price">$9.99 <span>/ month</span></div>
      <p class="pricing-kicker">Cancel anytime</p>
      <p class="pricing-desc">For regular boating season use.</p>
      <ul class="pricing-feature-list">
        <li><span class="pricing-check"></span>Route-based float plans</li>
        <li><span class="pricing-check"></span>Active Cruise</li>
        <li><span class="pricing-check"></span>Shareable Trip page</li>
        <li><span class="pricing-check"></span>Companion check-ins</li>
        <li><span class="pricing-check"></span>GPS check-in support</li>
        <li><span class="pricing-check"></span>NOOA/NWS Marine Weather</li>
        <li><span class="pricing-check"></span>Premium route tools</li>
      </ul>
      <a class="pricing-btn pricing-btn-primary" href="<cfoutput>#request.fpwBase#</cfoutput>/app/start-trial.cfm?offer=launch_trial">Start Monthly Premium</a>
    </article>

    <article class="pricing-card pricing-card-featured">
      <div class="pricing-badge">Best Value</div>
      <div class="pricing-card-icon"><svg class="pricing-icon"><use href="#fpw-icon-star"></use></svg></div>
      <h2>Premium Annual</h2>
      <div class="pricing-price">$89 <span>/ year</span></div>
      <p class="pricing-kicker">Save about 25% vs monthly</p>
      <p class="pricing-desc">For frequent boaters who want Premium all year.</p>
      <ul class="pricing-feature-list">
        <li><span class="pricing-check"></span>Route-based float plans</li>
        <li><span class="pricing-check"></span>Active Cruise</li>
        <li><span class="pricing-check"></span>Shareable Trip page</li>
        <li><span class="pricing-check"></span>Companion check-ins</li>
        <li><span class="pricing-check"></span>GPS check-in support</li>
        <li><span class="pricing-check"></span>NOOA/NWS Marine Weather</li>
        <li><span class="pricing-check"></span>Premium route tools</li>
      </ul>
      <a class="pricing-btn pricing-btn-primary" href="<cfoutput>#request.fpwBase#</cfoutput>/app/start-trial.cfm?offer=launch_trial">Start Annual Premium</a>
    </article>

    <article class="pricing-card">
      <div class="pricing-card-icon"><svg class="pricing-icon"><use href="#fpw-icon-clock"></use></svg></div>
      <h2>3-Day Pass</h2>
      <div class="pricing-price">$4.99</div>
      <p class="pricing-kicker pricing-pill">No subscription</p>
      <p class="pricing-desc">Full Premium access for a weekend or short trip.</p>
      <ul class="pricing-feature-list">
        <li><span class="pricing-check"></span>Route-based float plans</li>
        <li><span class="pricing-check"></span>Active Cruise</li>
        <li><span class="pricing-check"></span>Shareable Trip page</li>
        <li><span class="pricing-check"></span>Companion check-ins</li>
        <li><span class="pricing-check"></span>GPS check-in support</li>
        <li><span class="pricing-check"></span>NOOA/NWS Marine Weather</li>
        <li><span class="pricing-check"></span>Premium route tools</li>
        <li><span class="pricing-muted-check"></span>Valid for 3 consecutive days</li>
      </ul>
      <a class="pricing-btn pricing-btn-primary" href="<cfoutput>#request.fpwBase#</cfoutput>/app/start-trial.cfm?offer=launch_trial">Get 3-Day Pass</a>
    </article>
  </section>

  <section class="pricing-container pricing-plan-note">
    <strong>All paid plans include the same Premium features.</strong>
    <span>Premium Monthly and Annual renew automatically. Cancel anytime. The 3-Day Pass does not renew.</span>
  </section>

  <section class="pricing-container pricing-premium-strip">
    <div class="premium-strip-title">All Premium plans include</div>
    <div class="premium-strip-item"><svg><use href="#fpw-icon-route"></use></svg><span>Route-based<br>float plans</span></div>
    <div class="premium-strip-item"><svg><use href="#fpw-icon-waves"></use></svg><span>Active<br>Cruise</span></div>
    <div class="premium-strip-item"><svg><use href="#fpw-icon-follow"></use></svg><span>Public<br>Follow page</span></div>
    <div class="premium-strip-item"><svg><use href="#fpw-icon-phone"></use></svg><span>Companion<br>check-ins</span></div>
    <div class="premium-strip-item"><svg><use href="#fpw-icon-pin"></use></svg><span>GPS check-in<br>support</span></div>
    <div class="premium-strip-item"><svg><use href="#fpw-icon-tools"></use></svg><span>Premium<br>route tools</span></div>
    <div class="premium-strip-item"><svg><use href="#fpw-icon-pdf"></use></svg><span>PDF float plan<br>access</span></div>
  </section>

  <section class="pricing-container pricing-lower-grid">
    <article class="pricing-panel pricing-premium-includes">
      <h2>Premium includes</h2>
      <ul>
        <li><svg><use href="#fpw-icon-route"></use></svg>Route-based float plans</li>
        <li><svg><use href="#fpw-icon-waves"></use></svg>Active Cruise trip dashboard</li>
        <li><svg><use href="#fpw-icon-follow"></use></svg>Shareable Trip page for family and friends</li>
        <li><svg><use href="#fpw-icon-phone"></use></svg>Companion app check-ins</li>
        <li><svg><use href="#fpw-icon-pin"></use></svg>GPS coordinates on check-ins</li>
        <li><svg><use href="#fpw-icon-route"></use></svg>Route progress and trip status</li>
        <li><svg><use href="#fpw-icon-waves"></use></svg>Weather-aware trip context</li>
        <li><svg><use href="#fpw-icon-pdf"></use></svg>PDF float plan access</li>
      </ul>
    </article>

    <article class="pricing-panel pricing-comparison">
      <h2>Free vs Premium</h2>
      <table>
        <thead>
          <tr>
            <th>Feature</th>
            <th>Free</th>
            <th>Premium</th>
          </tr>
        </thead>
        <tbody>
          <tr><td>Basic float plan</td><td class="yes">✓</td><td class="yes">✓</td></tr>
          <tr><td>Same-day simple trip</td><td class="yes">✓</td><td class="yes">✓</td></tr>
          <tr><td>Route-based float plans</td><td class="no">×</td><td class="yes">✓</td></tr>
          <tr><td>Active Cruise</td><td class="no">×</td><td class="yes">✓</td></tr>
          <tr><td>Shareable Trip page</td><td class="no">×</td><td class="yes">✓</td></tr>
          <tr><td>Companion check-ins</td><td class="no">×</td><td class="yes">✓</td></tr>
          <tr><td>GPS check-in coordinates</td><td class="limited">Limited</td><td class="yes">✓</td></tr>
          <tr><td>PDF float plan</td><td class="yes">✓</td><td class="yes">✓</td></tr>
          <tr><td>Saved route tools</td><td class="no">×</td><td class="yes">✓</td></tr>
        </tbody>
      </table>
    </article>

    <article class="pricing-panel pricing-faq">
      <h2>FAQ</h2>
      <details open>
        <summary>Do all paid plans include the same features?</summary>
        <p>Yes. Monthly, Annual, and the 3-Day Pass all include Premium features. The only difference is how long access lasts and whether it renews.</p>
      </details>
      <details>
        <summary>Can I cancel Premium Monthly or Annual?</summary>
        <p>Yes. Premium Monthly and Premium Annual can be canceled anytime. There is no annual contract beyond the annual billing term you choose.</p>
      </details>
      <details>
        <summary>Does the 3-Day Pass renew?</summary>
        <p>No. The 3-Day Pass is short-term Premium access and does not renew.</p>
      </details>
      <details>
        <summary>Can I start free?</summary>
        <p>Yes. You can create a free account and use a Basic Float Plan for simple same-day trips.</p>
      </details>
    </article>
  </section>
</main>

<cfinclude template="../includes/footer_scripts.cfm">
<script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/app/pricing.js?v=20260526-cache-bump"></script>

</body>
</html>
