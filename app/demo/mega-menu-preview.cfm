<cfsetting showdebugoutput="false">
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>FPW Mega Menu Preview</title>
  <link rel="stylesheet" href="/fpw/assets/css/fpw-mega-menu-preview.css">
</head>
<body class="fpw-preview-body">
  <div class="fpw-preview-app" data-fpw-preview-app>
    <header class="fpw-topbar">
      <a href="#" class="fpw-topbar__brand" aria-label="FloatPlanWizard preview home">
        <span class="fpw-brand-mark" aria-hidden="true">
          <span></span>
        </span>
        <span class="fpw-brand-text">FloatPlanWizard</span>
      </a>

      <a href="#" class="fpw-topbar__trip">
        <span class="fpw-kicker">Active Trip</span>
        <span class="fpw-topbar__trip-main">
          <strong>loop - Day 1 - Full Route</strong>
          <span>Chicago &rarr; Chicago</span>
        </span>
      </a>

      <div class="fpw-topbar__actions">
        <a href="#" class="fpw-btn fpw-btn--ghost">Saved Routes</a>
        <a href="#" class="fpw-btn fpw-btn--primary">+ Create Route</a>
        <button type="button" class="fpw-btn fpw-btn--ghost fpw-btn--account">
          <span class="fpw-account-icon" aria-hidden="true"></span>
          <span>Account</span>
          <span class="fpw-caret" aria-hidden="true"></span>
        </button>
      </div>
    </header>

    <nav class="fpw-subnav" aria-label="FPW secondary navigation" data-fpw-preview-subnav>
      <button type="button" class="fpw-subnav__item" data-menu="dashboard" aria-expanded="false">
        <span class="fpw-nav-icon fpw-nav-icon--grid" aria-hidden="true"></span>
        Dashboard
      </button>
      <button type="button" class="fpw-subnav__item is-active" data-menu="trip-planning" aria-expanded="true">
        <span class="fpw-nav-icon fpw-nav-icon--route" aria-hidden="true"></span>
        Trip Planning
        <span class="fpw-caret" aria-hidden="true"></span>
      </button>
      <button type="button" class="fpw-subnav__item" data-menu="live-trip" aria-expanded="false">
        <span class="fpw-nav-icon fpw-nav-icon--live" aria-hidden="true"></span>
        Live Trip
        <span class="fpw-caret" aria-hidden="true"></span>
      </button>
      <button type="button" class="fpw-subnav__item" data-menu="resources" aria-expanded="false">
        <span class="fpw-nav-icon fpw-nav-icon--book" aria-hidden="true"></span>
        Resources
        <span class="fpw-caret" aria-hidden="true"></span>
      </button>
      <button type="button" class="fpw-subnav__item" data-menu="tools" aria-expanded="false">
        <span class="fpw-nav-icon fpw-nav-icon--tool" aria-hidden="true"></span>
        Tools
        <span class="fpw-caret" aria-hidden="true"></span>
      </button>
    </nav>

    <div class="fpw-layout">
      <aside class="fpw-sidebar">
        <div class="fpw-sidebar__logo">
          <span class="fpw-sidebar__mark" aria-hidden="true"></span>
          <span class="fpw-sidebar__wordmark">FloatPlan Wizard</span>
        </div>

        <nav class="fpw-sidebar__nav" aria-label="Preview dashboard navigation">
          <a href="#" class="fpw-sidebar__link is-active"><span class="fpw-sidebar__icon fpw-sidebar__icon--dash"></span>Dashboard</a>
          <a href="#" class="fpw-sidebar__link"><span class="fpw-sidebar__icon fpw-sidebar__icon--route"></span>Saved Routes</a>
          <a href="#" class="fpw-sidebar__link"><span class="fpw-sidebar__icon fpw-sidebar__icon--plan"></span>Float Plans</a>
          <a href="#" class="fpw-sidebar__link"><span class="fpw-sidebar__icon fpw-sidebar__icon--bell"></span>Float Plan Monitor</a>
          <a href="#" class="fpw-sidebar__link"><span class="fpw-sidebar__icon fpw-sidebar__icon--weather"></span>Weather</a>
          <a href="#" class="fpw-sidebar__link"><span class="fpw-sidebar__icon fpw-sidebar__icon--vessel"></span>Vessels</a>
          <a href="#" class="fpw-sidebar__link"><span class="fpw-sidebar__icon fpw-sidebar__icon--people"></span>Contacts</a>
          <a href="#" class="fpw-sidebar__link"><span class="fpw-sidebar__icon fpw-sidebar__icon--pin"></span>Waypoints</a>
          <a href="#" class="fpw-sidebar__link"><span class="fpw-sidebar__icon fpw-sidebar__icon--crew"></span>Crew</a>
          <a href="#" class="fpw-sidebar__link"><span class="fpw-sidebar__icon fpw-sidebar__icon--operator"></span>Operators</a>
          <a href="#" class="fpw-sidebar__link"><span class="fpw-sidebar__icon fpw-sidebar__icon--settings"></span>Settings</a>
          <a href="#" class="fpw-sidebar__link"><span class="fpw-sidebar__icon fpw-sidebar__icon--help"></span>Help</a>
        </nav>
      </aside>

      <main class="fpw-main">
        <section class="fpw-main-backdrop" aria-label="Dashboard preview background">
          <div class="fpw-context-strip">
            <div><span>Home Port</span><strong>4347 Topsail Trail</strong></div>
            <div><span>Default Vessel</span><strong>Big Blue</strong></div>
            <div><span>Active Route</span><strong>loop</strong></div>
            <div><span>Trip Setup Readiness</span><strong>Review Setup</strong></div>
          </div>
          <div class="fpw-routes-shell">
            <div class="fpw-routes-head">
              <div>
                <h1>Routes</h1>
                <p>Create and manage your saved boating routes.</p>
              </div>
              <button type="button">+ Create Route</button>
            </div>
            <div class="fpw-routes-grid">
              <div class="fpw-route-table">
                <div class="fpw-route-row fpw-route-row--head">
                  <span>Route Name</span><span>Start / End</span><span>Distance</span><span>Status</span>
                </div>
                <div class="fpw-route-row fpw-route-row--active">
                  <span>loop</span><span>Chicago<br>Chicago</span><span>4,233.0 NM</span><span>Active</span>
                </div>
                <div class="fpw-route-row">
                  <span>New Orleans</span><span>Tarpon Springs<br>New Orleans</span><span>655.0 NM</span><span>Saved</span>
                </div>
                <div class="fpw-route-row">
                  <span>Texas</span><span>Tarpon Springs<br>Brownsville</span><span>1,510.4 NM</span><span>Saved</span>
                </div>
              </div>
              <div class="fpw-route-details">
                <span class="fpw-status-dot">Active</span>
                <h2>loop</h2>
                <p>Updated from template GL_REUSE_V2 (CCW) on 2026-06-24</p>
                <div class="fpw-detail-grid">
                  <div><span>Start</span><strong>Chicago</strong></div>
                  <div><span>Distance</span><strong>4,233.0 NM</strong></div>
                  <div><span>End</span><strong>Chicago</strong></div>
                  <div><span>Waypoints</span><strong>57</strong></div>
                  <div><span>Est. Duration</span><strong>235.2 hrs</strong></div>
                  <div><span>Fuel Needed</span><strong>1376.22 gal</strong></div>
                </div>
              </div>
            </div>
          </div>
        </section>

        <section class="fpw-mega-stage" data-fpw-preview-stage aria-live="polite">
          <article class="fpw-mega fpw-mega--trip is-visible" data-panel="trip-planning">
            <div class="fpw-mega__inner">
              <div class="fpw-mega__left">
                <span class="fpw-kicker">Trip Planning</span>
                <h2 class="fpw-mega__title">Build the route before you leave the dock.</h2>
                <p class="fpw-mega__copy">Plan smarter with better data, collaboration, and tools built for safe, efficient trips.</p>

                <div class="fpw-widget fpw-widget--readiness">
                  <div class="fpw-widget__title">Trip readiness</div>
                  <div class="fpw-readiness">
                    <div class="fpw-readiness__ring">78%</div>
                    <ul class="fpw-checklist">
                      <li class="is-complete">Route defined</li>
                      <li class="is-complete">Vessel and crew set</li>
                      <li class="is-warning">Weather reviewed</li>
                      <li>Checklist complete</li>
                    </ul>
                  </div>
                </div>

                <div class="fpw-stack">
                  <a href="#" class="fpw-btn fpw-btn--primary fpw-btn--block">+ Create Route <span class="fpw-link-arrow"></span></a>
                  <a href="#" class="fpw-btn fpw-btn--secondary fpw-btn--block">New Float Plan <span class="fpw-link-arrow"></span></a>
                </div>

                <div class="fpw-tip">
                  <div class="fpw-tip__title"><span class="fpw-spark"></span>Pro tip</div>
                  <p>Save time by reusing waypoints and templates.</p>
                  <a href="#">Learn how <span class="fpw-link-arrow"></span></a>
                </div>
              </div>

              <div class="fpw-mega__center">
                <div class="fpw-section-label">Everything you need to plan with confidence</div>
                <div class="fpw-card-list">
                  <a href="#" class="fpw-item-card">
                    <span class="fpw-card-icon fpw-card-icon--route"></span>
                    <span class="fpw-item-card__body"><h3>Plan a Trip / Route Builder</h3><p>Create and optimize routes with waypoints, legs, and routing tools.</p><small>Start from scratch or templates</small></span>
                    <span class="fpw-item-card__meta"><strong>3</strong><span>In Progress</span></span>
                    <span class="fpw-card-chevron"></span>
                  </a>
                  <a href="#" class="fpw-item-card">
                    <span class="fpw-card-icon fpw-card-icon--map"></span>
                    <span class="fpw-item-card__body"><h3>Saved Routes</h3><p>View, edit, and manage your saved routes and templates.</p><small>42 total - 6 updated this week</small></span>
                    <span class="fpw-item-card__meta"><strong>42</strong><span>Routes</span></span>
                    <span class="fpw-card-chevron"></span>
                  </a>
                  <a href="#" class="fpw-item-card">
                    <span class="fpw-card-icon fpw-card-icon--clipboard"></span>
                    <span class="fpw-item-card__body"><h3>Float Plans</h3><p>Prepare float plans tied to your routes with required details.</p><small>17 total - 4 active</small></span>
                    <span class="fpw-item-card__meta"><strong>4</strong><span>Active</span></span>
                    <span class="fpw-card-chevron"></span>
                  </a>
                  <a href="#" class="fpw-item-card">
                    <span class="fpw-card-icon fpw-card-icon--people"></span>
                    <span class="fpw-item-card__body"><h3>Vessels and Crew</h3><p>Manage vessels, crew, operators, and contact details.</p><small>12 vessels - 28 crew</small></span>
                    <span class="fpw-item-card__meta"><strong>12</strong><span>Vessels</span></span>
                    <span class="fpw-card-chevron"></span>
                  </a>
                  <a href="#" class="fpw-item-card">
                    <span class="fpw-card-icon fpw-card-icon--pin"></span>
                    <span class="fpw-item-card__body"><h3>Waypoints</h3><p>Organize saved locations and route markers for faster planning.</p><small>157 total - 12 added this week</small></span>
                    <span class="fpw-item-card__meta fpw-item-card__meta--gold"><strong>157</strong><span>Waypoints</span></span>
                    <span class="fpw-card-chevron"></span>
                  </a>
                </div>
                <div class="fpw-mega__footer-link"><a href="#">View all trip planning tools <span class="fpw-link-arrow"></span></a></div>
              </div>

              <div class="fpw-mega__right">
                <div class="fpw-rail-card">
                  <div class="fpw-rail-card__title">Recent route</div>
                  <div class="fpw-map-thumb">
                    <span></span><span></span><span></span><span></span><span></span>
                  </div>
                  <h4>loop - Day 1 - Full Route</h4>
                  <p>Chicago &rarr; Chicago</p>
                  <div class="fpw-inline-meta">4,233.0 NM - 235.2 hrs - Updated 2h ago</div>
                  <a href="#" class="fpw-btn fpw-btn--secondary fpw-btn--block">Open Route <span class="fpw-link-arrow"></span></a>
                </div>
                <div class="fpw-rail-card">
                  <div class="fpw-rail-card__title">Pre-departure checklist <span>2 / 4 complete</span></div>
                  <div class="fpw-progress"><span style="width:50%"></span></div>
                  <ul class="fpw-checklist">
                    <li class="is-complete">Route and waypoints verified</li>
                    <li class="is-complete">Vessel and crew confirmed</li>
                    <li class="is-warning">Weather reviewed</li>
                    <li>Float plan filed</li>
                  </ul>
                </div>
                <div class="fpw-rail-card">
                  <div class="fpw-rail-card__title">Suggested next steps</div>
                  <ul class="fpw-action-list">
                    <li><a href="#">Review weather along route <span class="fpw-card-chevron"></span></a></li>
                    <li><a href="#">File your float plan <span class="fpw-card-chevron"></span></a></li>
                    <li><a href="#">Share route with crew <span class="fpw-card-chevron"></span></a></li>
                  </ul>
                </div>
              </div>
            </div>
          </article>

          <article class="fpw-mega fpw-mega--live" data-panel="live-trip" hidden>
            <div class="fpw-mega__inner">
              <div class="fpw-mega__left">
                <span class="fpw-kicker">Live Trip Center</span>
                <h2 class="fpw-mega__title">Run the trip from one place.</h2>
                <p class="fpw-mega__copy">Monitor progress, check conditions, stay in touch, and keep everyone in the loop.</p>
                <a href="#" class="fpw-btn fpw-btn--primary fpw-btn--block">Open Active Cruise <span class="fpw-link-arrow"></span></a>
                <div class="fpw-summary-card">
                  <span class="fpw-kicker">Active Trip</span>
                  <h4>loop - Day 1 - Full Route</h4>
                  <p>Chicago &rarr; Chicago</p>
                  <div class="fpw-summary-card__route">Leg 9 of 11 - Grand Rivers &rarr; Paducah <strong>2.7 NM to go</strong></div>
                  <div class="fpw-progress"><span style="width:82%"></span></div>
                  <div class="fpw-inline-meta">4,233.0 NM - 235.2 hrs est. - Updated 2h ago</div>
                  <a href="#" class="fpw-inline-link">View Trip Details <span class="fpw-link-arrow"></span></a>
                </div>
                <div class="fpw-tip">
                  <div class="fpw-tip__title"><span class="fpw-spark"></span>Pro tip</div>
                  <p>Enable real-time monitoring for alerts and ETA updates.</p>
                  <a href="#">Learn how <span class="fpw-link-arrow"></span></a>
                </div>
              </div>

              <div class="fpw-mega__center fpw-grid-2">
                <a href="#" class="fpw-feature-card"><span class="fpw-card-icon fpw-card-icon--vessel"></span><h3>Active Cruise</h3><div class="fpw-status">On the water</div><p>View live progress, ETA, and leg details. Access tools to manage the trip.</p><small>Leg 9 of 11 - Grand Rivers &rarr; Paducah</small><span class="fpw-card-chevron"></span></a>
                <a href="#" class="fpw-feature-card"><span class="fpw-card-icon fpw-card-icon--clipboard"></span><h3>Float Plan Monitor</h3><div class="fpw-status">Monitoring active</div><p>Tracking your trip and alerting contacts if anything looks off.</p><small>Next check-in in 47 min - 11:30 AM CDT</small><span class="fpw-card-chevron"></span></a>
                <a href="#" class="fpw-feature-card"><span class="fpw-card-icon fpw-card-icon--weather"></span><h3>Weather</h3><div class="fpw-status">Partly cloudy</div><p>See marine forecast, wind, and precipitation along your route.</p><small>78&deg;F - Wind S 12 mph - Waves 1-2 ft</small><span class="fpw-card-chevron"></span></a>
                <a href="#" class="fpw-feature-card"><span class="fpw-card-icon fpw-card-icon--map"></span><h3>Follow Page</h3><div class="fpw-status">Live</div><p>Share your trip and let others follow your progress in real time.</p><small>Followers 12 - floatplan.app/f/AB12CD</small><span class="fpw-card-chevron"></span></a>
                <div class="fpw-mega__footer-link fpw-mega__footer-link--span2"><a href="#">View all live trip tools <span class="fpw-link-arrow"></span></a></div>
              </div>

              <div class="fpw-mega__right">
                <div class="fpw-rail-card"><div class="fpw-rail-card__title">Right Now</div><div class="fpw-status-card"><strong>Trip Status</strong><span class="fpw-pill fpw-pill--green">On Track</span></div><p>All systems normal. No alerts.</p></div>
                <div class="fpw-rail-card"><div class="fpw-rail-card__title">Next Check-in</div><div class="fpw-checkin-row"><div><strong class="fpw-big-number">47m</strong><span>11:30 AM CDT</span></div><a href="#" class="fpw-btn fpw-btn--secondary">Check In Now</a></div><div class="fpw-inline-meta fpw-inline-meta--green">Auto check-in enabled</div></div>
                <div class="fpw-rail-card"><div class="fpw-rail-card__title">Conditions at Current Location <span>10:43 AM</span></div><div class="fpw-weather-row"><span class="fpw-weather-icon"></span><strong class="fpw-weather-temp">78&deg;F</strong><span>Partly cloudy</span></div><div class="fpw-stat-row"><div><strong>S 12 mph</strong><span>Wind</span></div><div><strong>1-2 ft</strong><span>Waves</span></div><div><strong>20%</strong><span>Rain</span></div><div><strong>30.12 in</strong><span>Pressure</span></div></div></div>
                <div class="fpw-rail-card"><div class="fpw-rail-card__title">Quick Actions</div><ul class="fpw-action-list"><li><a href="#">Check In Now <span class="fpw-card-chevron"></span></a></li><li><a href="#">Add Delay / Update ETA <span class="fpw-card-chevron"></span></a></li><li><a href="#">Share Follow Link <span class="fpw-card-chevron"></span></a></li><li><a href="#">View Full Forecast <span class="fpw-card-chevron"></span></a></li><li><a href="#">Open Float Plan <span class="fpw-card-chevron"></span></a></li></ul></div>
              </div>
            </div>
          </article>

          <article class="fpw-mega fpw-mega--resources" data-panel="resources" hidden>
            <div class="fpw-mega__inner">
              <div class="fpw-mega__left">
                <span class="fpw-kicker">Boating Resources</span>
                <h2 class="fpw-mega__title">Reference guides for smarter trip planning.</h2>
                <p class="fpw-mega__copy">Curated libraries, guides, and tools with the details you need to plan with confidence on every mile of your journey.</p>
                <a href="#" class="fpw-btn fpw-btn--primary">Open Resources <span class="fpw-link-arrow"></span></a>
                <div class="fpw-stat-grid">
                  <div class="fpw-mini-stat"><span class="fpw-card-icon fpw-card-icon--book"></span><strong>5</strong><span>Libraries and Guides</span></div>
                  <div class="fpw-mini-stat"><span class="fpw-card-icon fpw-card-icon--pin"></span><strong>12,000+</strong><span>Coverage Points</span></div>
                  <div class="fpw-mini-stat"><span class="fpw-card-icon fpw-card-icon--clock"></span><strong>Daily</strong><span>Reliable updates</span></div>
                </div>
                <div class="fpw-request-link"><span>Need something else?</span><a href="#">Request a resource <span class="fpw-link-arrow"></span></a></div>
              </div>

              <div class="fpw-mega__center">
                <div class="fpw-card-list">
                  <a href="#" class="fpw-item-card"><span class="fpw-card-icon fpw-card-icon--loop"></span><span class="fpw-item-card__body"><h3>Great Loop Libraries</h3><p>Complete Great Loop route references including json, kml, gpx, and pdf float plans.</p><small>Coverage: 6,000+ NM - Updated: 2d ago - Top: Route Atlas</small></span><span class="fpw-card-chevron"></span></a>
                  <a href="#" class="fpw-item-card"><span class="fpw-card-icon fpw-card-icon--lock"></span><span class="fpw-item-card__body"><h3>Lock Library</h3><p>Lock locations, details, VHF channels, operating hours, and contact information.</p><small>Coverage: 650+ Locks - Updated: 1d ago - Top: Lock Info</small></span><span class="fpw-card-chevron"></span></a>
                  <a href="#" class="fpw-item-card"><span class="fpw-card-icon fpw-card-icon--bridge"></span><span class="fpw-item-card__body"><h3>Bridge Library</h3><p>Bridge clearances, opening schedules, contact info, and restriction details.</p><small>Coverage: 2,200+ Bridges - Updated: 1d ago - Top: Clearances</small></span><span class="fpw-card-chevron"></span></a>
                  <a href="#" class="fpw-item-card"><span class="fpw-card-icon fpw-card-icon--anchor"></span><span class="fpw-item-card__body"><h3>Anchorage Library</h3><p>Anchorage locations, depth, bottom type, amenities, and local guidance.</p><small>Coverage: 1,800+ Anchorages - Updated: 3d ago - Top: Amenities</small></span><span class="fpw-card-chevron"></span></a>
                  <a href="#" class="fpw-item-card"><span class="fpw-card-icon fpw-card-icon--clipboard"></span><span class="fpw-item-card__body"><h3>Planning Guide</h3><p>Best practices, checklists, route planning tips, and float plan guidance.</p><small>Sections: 28 - Updated: 5d ago - Top: Checklists</small></span><span class="fpw-card-chevron"></span></a>
                </div>
                <div class="fpw-mega__footer-link"><a href="#">View all resources <span class="fpw-link-arrow"></span></a></div>
              </div>

              <div class="fpw-mega__right">
                <div class="fpw-rail-card"><div class="fpw-rail-card__title">Recently viewed <a href="#">View all</a></div><ul class="fpw-action-list fpw-action-list--compact"><li><a href="#">Great Loop Route Atlas (PDF)<small>Viewed 2d ago</small><span class="fpw-card-chevron"></span></a></li><li><a href="#">Illinois Waterway Lock Guide<small>Viewed 3d ago</small><span class="fpw-card-chevron"></span></a></li><li><a href="#">Ohio River Bridge Clearances<small>Viewed 4d ago</small><span class="fpw-card-chevron"></span></a></li></ul></div>
                <div class="fpw-rail-card"><div class="fpw-rail-card__title">Recommended for this trip <span>Based on loop</span></div><ul class="fpw-action-list fpw-action-list--compact"><li><a href="#">Chicago Area Locks<small>6 locks on your route</small><span class="fpw-card-chevron"></span></a></li><li><a href="#">Des Plaines River Bridges<small>14 bridges ahead</small><span class="fpw-card-chevron"></span></a></li><li><a href="#">Great Lakes Anchorages<small>8 anchorages nearby</small><span class="fpw-card-chevron"></span></a></li></ul></div>
                <div class="fpw-rail-card"><div class="fpw-rail-card__title">Coverage at a glance <a href="#">View map</a></div><div class="fpw-progress-group"><label><span>Locks</span><b>100%</b></label><div class="fpw-progress"><span style="width:100%"></span></div><label><span>Bridges</span><b>95%</b></label><div class="fpw-progress"><span style="width:95%"></span></div><label><span>Anchorages</span><b>92%</b></label><div class="fpw-progress"><span style="width:92%"></span></div></div><a href="#" class="fpw-inline-link">How coverage works <span class="fpw-link-arrow"></span></a></div>
              </div>
            </div>
          </article>

          <article class="fpw-mega fpw-mega--tools" data-panel="tools" hidden>
            <div class="fpw-mega__inner">
              <div class="fpw-mega__left">
                <span class="fpw-kicker">Tools</span>
                <h2 class="fpw-mega__title">Quick utilities for planning and setup.</h2>
                <p class="fpw-mega__copy">Save time, reduce risk, and get accurate estimates before you run the route.</p>
                <a href="#" class="fpw-btn fpw-btn--primary fpw-btn--block">Open Fuel Calculator <span class="fpw-link-arrow"></span></a>
                <div class="fpw-divider"></div>
                <div class="fpw-rail-card"><div class="fpw-rail-card__title">Pinned tools <a href="#">Manage</a></div><ul class="fpw-action-list"><li><a href="#">Fuel Calculator <span class="fpw-pin"></span></a></li><li><a href="#">Weather <span class="fpw-pin"></span></a></li><li><a href="#">Vessels <span class="fpw-pin"></span></a></li></ul></div>
                <div class="fpw-tip"><div class="fpw-tip__title"><span class="fpw-spark"></span>Pro tip</div><p>Pin your most used tools for faster access right from here.</p><a href="#">Learn more <span class="fpw-link-arrow"></span></a></div>
              </div>

              <div class="fpw-mega__center">
                <div class="fpw-section-label">Your most important tools</div>
                <div class="fpw-card-list">
                  <a href="#" class="fpw-item-card"><span class="fpw-card-icon fpw-card-icon--calculator"></span><span class="fpw-item-card__body"><h3>Fuel Calculator</h3><p>Estimate fuel burn, required, and trip range based on vessel, load, and conditions.</p><small>Last used: Today - 9:14 AM</small></span><span class="fpw-item-card__meta"><strong>3</strong><span>Estimates</span></span><span class="fpw-card-chevron"></span></a>
                  <a href="#" class="fpw-item-card"><span class="fpw-card-icon fpw-card-icon--weather"></span><span class="fpw-item-card__body"><h3>Weather</h3><p>Check forecast and conditions before and during your trip.</p><small>Last used: Yesterday - 3:42 PM</small></span><span class="fpw-item-card__meta"><strong>4</strong><span>Locations</span></span><span class="fpw-card-chevron"></span></a>
                  <a href="#" class="fpw-item-card"><span class="fpw-card-icon fpw-card-icon--vessel"></span><span class="fpw-item-card__body"><h3>Vessels</h3><p>Manage your vessels, specifications, and default vessel settings.</p><small>Last used: Today - 8:21 AM</small></span><span class="fpw-item-card__meta"><strong>12</strong><span>Vessels</span></span><span class="fpw-card-chevron"></span></a>
                  <a href="#" class="fpw-item-card"><span class="fpw-card-icon fpw-card-icon--people"></span><span class="fpw-item-card__body"><h3>Contacts</h3><p>Manage trip contacts, notifications, and emergency details.</p><small>Last used: Apr 26 - 5:08 PM</small></span><span class="fpw-item-card__meta"><strong>28</strong><span>Contacts</span></span><span class="fpw-card-chevron"></span></a>
                  <a href="#" class="fpw-item-card"><span class="fpw-card-icon fpw-card-icon--pin"></span><span class="fpw-item-card__body"><h3>Waypoints</h3><p>Organize saved locations and route markers for faster planning.</p><small>Last used: Today - 7:55 AM</small></span><span class="fpw-item-card__meta fpw-item-card__meta--gold"><strong>157</strong><span>Waypoints</span></span><span class="fpw-card-chevron"></span></a>
                </div>
                <div class="fpw-mega__footer-link"><a href="#">View all tools <span class="fpw-link-arrow"></span></a></div>
              </div>

              <div class="fpw-mega__right">
                <div class="fpw-rail-card"><div class="fpw-rail-card__title">Quick estimate <span class="fpw-card-icon fpw-card-icon--calculator"></span></div><h4>Chicago &rarr; Chicago</h4><div class="fpw-inline-meta">4,233.0 NM - 235.2 hrs</div><div class="fpw-stat-row"><div><strong>1,376.22 gal</strong><span>Est. Fuel Needed</span></div><div><strong>235.2 hrs</strong><span>Est. Duration</span></div><div><strong>5.85 gph</strong><span>Avg. Burn</span></div></div><a href="#" class="fpw-btn fpw-btn--secondary fpw-btn--block">Open Fuel Calculator</a></div>
                <div class="fpw-rail-card"><div class="fpw-rail-card__title">Recent tools <a href="#">View all</a></div><ul class="fpw-action-list fpw-action-list--compact"><li><a href="#">Fuel Calculator<small>Today - 9:14 AM</small></a></li><li><a href="#">Weather<small>Yesterday - 3:42 PM</small></a></li><li><a href="#">Waypoints<small>Apr 26 - 7:55 AM</small></a></li><li><a href="#">Vessels<small>Apr 25 - 6:20 PM</small></a></li></ul></div>
                <div class="fpw-rail-card"><div class="fpw-rail-card__title">Setup overview</div><div class="fpw-stat-grid fpw-stat-grid--2col"><div class="fpw-mini-stat"><strong>12</strong><span>Vessels</span></div><div class="fpw-mini-stat"><strong>28</strong><span>Contacts</span></div><div class="fpw-mini-stat"><strong>16</strong><span>Crew Members</span></div><div class="fpw-mini-stat"><strong>157</strong><span>Waypoints</span></div></div><a href="#" class="fpw-inline-link">Open setup center <span class="fpw-link-arrow"></span></a></div>
              </div>
            </div>
          </article>
        </section>
      </main>
    </div>
  </div>

  <script src="/fpw/assets/js/fpw-mega-menu-preview.js"></script>
</body>
</html>
