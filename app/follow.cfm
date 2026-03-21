<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width,initial-scale=1" />
  <title>FloatPlanWizard - Family and Friends</title>

  <cfinclude template="../includes/header_styles.cfm">
  <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" integrity="sha256-p4NxAoJBhIIN+hmNHrzRCf9tD/miZyoHS5obTRR9BMY=" crossorigin="" />
  <link rel="stylesheet" href="<cfoutput>#request.fpwBase#</cfoutput>/assets/css/follow.css?v=20260320c" />
</head>
<body class="follow-body">
  <div class="app">
    <aside class="sidebar">
      <div class="brand">
        <div class="brand-badge"></div>
        <div>
          <h1>FloatPlanWizard</h1>
          <p>Family and Friends</p>
        </div>
      </div>

      <section class="trip-card" data-fpw-region="sidebar-trip-card">
        <div class="trip-top">
          <div class="trip-title" data-fpw-field="trip-card-title">Anclote Key · Day 1 · Route</div>
          <span class="pill good" data-fpw-field="trip-card-status-pill">All Good</span>
        </div>

        <div class="trip-meta">
          <div><strong>Share link:</strong> <span class="trip-link" data-fpw-field="trip-card-share-link">/follow/user-route-187-20260319...</span></div>
          <div><strong>Last check-in:</strong> <span data-fpw-field="trip-card-last-checkin">24 min ago</span> &nbsp; | &nbsp; <strong>Viewers:</strong> <span data-fpw-field="trip-card-viewer-count">6</span></div>
          <div><strong>Vessel:</strong> <span data-fpw-field="trip-card-vessel">Sea Mist</span> &nbsp; | &nbsp; <strong>Privacy:</strong> <span data-fpw-field="trip-card-privacy">Private share page</span></div>
          <div><strong>Monitoring:</strong> <span data-fpw-field="trip-card-monitoring">Active with missed check-in rules enabled</span></div>
        </div>

        <div class="trip-actions">
          <button class="btn primary" id="copyLinkBtn" type="button" data-fpw-field="trip-card-copy-link">Copy Link</button>
          <button class="btn secondary" type="button" data-fpw-field="trip-card-text-link">Text Link</button>
          <button class="btn ghost" id="privacyBtn" type="button" data-fpw-field="trip-card-privacy-action">Privacy</button>
        </div>

        <div class="monitor-row">
          <span data-fpw-field="trip-card-monitor-state-text"><strong>Monitoring active</strong><br />No missed check-ins on this voyage</span>
          <span class="pill good" data-fpw-field="trip-card-monitor-state-pill">Healthy</span>
        </div>
      </section>

      <nav class="side-nav" data-fpw-region="sidebar-nav">
        <a class="side-link active" href="#"><span>Overview</span><span class="pill live">Live</span></a>
        <a class="side-link" href="#"><span>Map</span><span class="pill route">Route</span></a>
        <a class="side-link" href="#"><span>Stream</span><span class="pill media">Posts</span></a>
        <a class="side-link" href="#"><span>Photos</span><span class="pill media">Media</span></a>
        <a class="side-link" href="#"><span>Trip Stats</span><span class="pill media">Summary</span></a>
        <a class="side-link" href="#"><span>Timeline</span><span class="pill media">Milestones</span></a>
      </nav>

      <div class="sidebar-note">
        This shared page turns route progress, check-ins, and updates into one clear live view for family and friends. If a required check-in is missed, designated contacts can be notified based on the monitoring rules for the trip.
      </div>
    </aside>

    <main class="main">
      <div class="topbar" data-fpw-region="topbar">
        <div class="page-title">
          <h2 data-fpw-field="page-title">Anclote Key · Day 1 · Route</h2>
          <p data-fpw-field="page-subtitle">Follow along in real time: location, progress, updates, comments, and trip confidence.</p>
        </div>

        <div class="topbar-right">
          <div class="live-chip" data-fpw-field="live-chip"><span class="pulse"></span> Live now · Updated 2 min ago</div>
          <div class="mode-tabs" data-fpw-field="mode-tabs">
            <button class="active" type="button">Family</button>
            <button type="button">Expedition</button>
            <button type="button">Kid Mode</button>
          </div>
          <button class="btn primary" id="notifyBtn" type="button" data-fpw-field="notify-action">Notify Me</button>
        </div>
      </div>

      <section class="journey-strip card" data-fpw-region="journey-strip">
        <div class="journey-head">
          <div>
            <div class="journey-title">Voyage Progress</div>
            <div class="journey-sub" data-fpw-field="journey-subtitle">Current leg is active. Distance complete: 16.1 of 38.7 nm today.</div>
          </div>
          <div class="pill good" data-fpw-field="journey-status-pill">Underway · On track</div>
        </div>
        <div class="progress-rail"><span data-fpw-field="journey-progress-fill"></span></div>
        <div class="journey-stops">
          <div class="journey-stop">
            <div class="kicker">Departed</div>
            <strong data-fpw-field="journey-departed-value">Home dock</strong>
            <small data-fpw-field="journey-departed-meta">Departed today at 8:12 AM</small>
          </div>
          <div class="journey-stop">
            <div class="kicker">Current leg</div>
            <strong data-fpw-field="journey-current-leg-value">Crossing to Anclote Key</strong>
            <small data-fpw-field="journey-current-leg-meta">Making way at 15 kn</small>
          </div>
          <div class="journey-stop">
            <div class="kicker">Next stop</div>
            <strong data-fpw-field="journey-next-stop-value">Anclote Key anchorage</strong>
            <small data-fpw-field="journey-next-stop-meta">ETA today around 4:30 PM</small>
          </div>
          <div class="journey-stop">
            <div class="kicker">Check-in</div>
            <strong data-fpw-field="journey-checkin-value">Checked in at --</strong>
            <small data-fpw-field="journey-checkin-meta">-- since last check-in</small>
          </div>
        </div>
      </section>

      <section class="summary-grid" data-fpw-region="summary-grid">
        <article class="card stat-card">
          <div class="stat-top"><span>Status</span><span class="status-dot"></span></div>
          <h3 data-fpw-field="card-status-title">All Good</h3>
          <div class="big" data-fpw-field="card-status-value">No missed check-ins</div>
          <p data-fpw-field="card-status-copy">Monitoring is active and the trip is reporting normally.</p>
        </article>

        <article class="card stat-card">
          <div class="stat-top"><span>Current Location</span><span>LOC</span></div>
          <h3 data-fpw-field="card-location-title">Off Tarpon Springs</h3>
          <div class="big" data-fpw-field="card-location-value">Underway westbound</div>
          <p data-fpw-field="card-location-copy">Heading toward Anclote Key on the active route leg.</p>
        </article>

        <article class="card stat-card">
          <div class="stat-top"><span>Next Destination</span><span>STOP</span></div>
          <h3 data-fpw-field="card-destination-title">Anclote Key</h3>
          <div class="big" data-fpw-field="card-destination-value">Anchorage arrival planned</div>
          <p data-fpw-field="card-destination-copy">Next major stop and expected overnight anchorage.</p>
        </article>

        <article class="card stat-card">
          <div class="stat-top"><span>Arrival Estimate</span><span>ETA</span></div>
          <h3 data-fpw-field="card-arrival-title">Today</h3>
          <div class="big" data-fpw-field="card-arrival-value">Around 4:30 PM</div>
          <p data-fpw-field="card-arrival-copy">Approximate based on current pace, route progress, and last update.</p>
        </article>

        <article class="card stat-card">
          <div class="stat-top"><span>Conditions</span><span>SEA</span></div>
          <h3 data-fpw-field="card-conditions-title">Favorable</h3>
          <div class="big" data-fpw-field="card-conditions-value">No active hazards reported</div>
          <p data-fpw-field="card-conditions-copy">Light wind, manageable seas, and no current caution flags.</p>
        </article>
      </section>

      <section class="content-grid">
        <div class="stack">
          <article class="card map-panel" data-fpw-region="map-panel">
            <div class="panel-head">
              <div>
                <h3 data-fpw-field="map-panel-title">Map Overview</h3>
                <p data-fpw-field="map-panel-subtitle">Live route view with current position, completed track, and destination.</p>
              </div>
              <button class="btn secondary" id="openFullMapBtn" type="button" data-fpw-field="map-open-full-map">Open Full Map</button>
            </div>
            <div class="map-wrap">
              <div id="followMap" class="map-canvas" data-fpw-field="map-shell" aria-label="Voyage route map"></div>
              <div class="map-badges" data-fpw-field="map-badges">
                <div class="map-badge">Completed leg</div>
                <div class="map-badge">Active leg</div>
                <div class="map-badge">Recenter vessel</div>
              </div>
            </div>
          </article>

          <section class="mini-grid" data-fpw-region="lower-cards">
            <article class="card mini-card">
              <h4>Today’s Progress</h4>
              <div class="metric" data-fpw-field="today-progress-metric">16.1 mi</div>
              <div class="label-line" data-fpw-field="today-progress-location">Current location: Off Tarpon Springs</div>
              <div class="label-line" data-fpw-field="today-progress-eta">Estimated arrival: Around 4:30 PM</div>
              <div class="track-bar"><span data-fpw-field="today-progress-fill"></span></div>
            </article>

            <article class="card mini-card">
              <h4>Latest Photos</h4>
              <div class="label-line"><strong data-fpw-field="latest-photos-count">3 recent moments shared</strong></div>
              <div class="label-line" data-fpw-field="latest-photos-copy">Photos from the trip appear here for friends and family.</div>
              <div class="photo-row" data-fpw-field="latest-photos-row">
                <div class="photo"></div>
                <div class="photo"></div>
                <div class="photo"></div>
              </div>
            </article>

            <article class="card mini-card">
              <h4>Trip Summary</h4>
              <div class="metric" style="font-size:30px;" data-fpw-field="trip-summary-metric">2 days</div>
              <div class="summary-list">
                <div data-fpw-field="trip-summary-distance"><strong>Distance:</strong> 16.1 nm today</div>
                <div data-fpw-field="trip-summary-confidence"><strong>Tracking confidence:</strong> High</div>
                <div data-fpw-field="trip-summary-mode"><strong>Trip mode:</strong> Route-based monitoring</div>
                <div data-fpw-field="trip-summary-safety"><strong>Safety state:</strong> Normal</div>
              </div>
            </article>
          </section>

          <article class="card trust-panel" data-fpw-region="family-confidence">
            <div class="panel-head">
              <div>
                <h3 data-fpw-field="family-confidence-title">Family Confidence</h3>
                <p data-fpw-field="family-confidence-subtitle">Built to reassure viewers with plain-language trip and safety status.</p>
              </div>
            </div>
            <div class="trust-grid">
              <div class="trust-card">
                <h4>What green means</h4>
                <p>The trip is actively reporting and there are no missed required check-ins at this time.</p>
              </div>
              <div class="trust-card">
                <h4>Why ETA can shift</h4>
                <p>Arrival estimates can move with pace, route changes, conditions, and live check-in timing.</p>
              </div>
              <div class="trust-card">
                <h4>If something changes</h4>
                <p>Monitoring rules can escalate only when the trip stops reporting as expected or the owner posts a concern.</p>
              </div>
            </div>
          </article>

          <article class="card timeline-panel" data-fpw-region="timeline">
            <div class="panel-head">
              <div>
                <h3 data-fpw-field="timeline-title">Cruise Timeline</h3>
                <p data-fpw-field="timeline-subtitle">Story-style view of today’s key milestones, check-ins, and upcoming targets.</p>
              </div>
            </div>
            <div class="timeline-wrap">
              <div class="timeline-summary">
                <div class="overlay-card" data-fpw-field="timeline-route-total">
                  <div class="kicker">Route total</div>
                  <strong>1 day planned</strong>
                  <small>38.7 nm for today’s leg</small>
                </div>
                <div class="overlay-card" data-fpw-field="timeline-eff-speed">
                  <div class="kicker">Eff speed</div>
                  <strong>15.0 kn</strong>
                  <small>Current modeled pace</small>
                </div>
                <div class="overlay-card" data-fpw-field="timeline-fuel-reserve">
                  <div class="kicker">Fuel + reserve</div>
                  <strong>1.9 + 0.6 gal</strong>
                  <small>Illustrative route summary</small>
                </div>
                <div class="overlay-card" data-fpw-field="timeline-next-update">
                  <div class="kicker">Next update</div>
                  <strong>Within 1 hr</strong>
                  <small>Expected routine post or check-in</small>
                </div>
              </div>

              <div class="timeline" data-fpw-field="timeline-events">
                <div class="time-row">
                  <div class="time-stamp">8:12 AM</div>
                  <div class="time-line"><div class="time-dot">1</div></div>
                  <div class="time-card">
                    <h4>Departed home dock</h4>
                    <p>Trip monitoring started and the route leg became active for family and friends.</p>
                  </div>
                </div>

                <div class="time-row">
                  <div class="time-stamp">10:45 AM</div>
                  <div class="time-line"><div class="time-dot">2</div></div>
                  <div class="time-card">
                    <h4>Routine check-in received</h4>
                    <p>Position, heading, and progress aligned with the planned leg. Confidence remained high.</p>
                  </div>
                </div>

                <div class="time-row">
                  <div class="time-stamp">1:05 PM</div>
                  <div class="time-line"><div class="time-dot">3</div></div>
                  <div class="time-card">
                    <h4>Current underway segment</h4>
                    <p>Making way toward Anclote Key in favorable conditions with no active alerts reported.</p>
                  </div>
                </div>

                <div class="time-row">
                  <div class="time-stamp">4:30 PM</div>
                  <div class="time-line"><div class="time-dot">4</div></div>
                  <div class="time-card">
                    <h4>Expected arrival</h4>
                    <p>Planned anchorage arrival window based on current progress and latest trip update.</p>
                  </div>
                </div>
              </div>
            </div>
          </article>
        </div>

        <div class="stack">
          <article class="card stream-panel" data-fpw-region="voyage-stream">
            <div class="panel-head">
              <div>
                <h3 data-fpw-field="stream-title">Voyage Stream</h3>
                <p data-fpw-field="stream-subtitle">Owner updates, automated milestones, photos, and family reactions.</p>
              </div>
              <span class="pill route" data-fpw-field="stream-owner-pill">Owner mode</span>
            </div>

            <div class="owner-banner">
              <span data-fpw-field="stream-owner-banner-text"><strong>Owner posting enabled.</strong> Structured updates help family understand the trip quickly.</span>
              <span class="pill route" data-fpw-field="stream-owner-banner-pill">Editable</span>
            </div>

            <div class="composer">
              <div class="composer-top">
                <div class="avatar">OW</div>
                <textarea placeholder="Post a quick voyage update for family and friends..." data-fpw-field="stream-composer-text">All good so far. Smooth water crossing this afternoon and still on track for Anclote Key.</textarea>
              </div>
              <input type="text" placeholder="Optional photo URL (MVP)" value="" data-fpw-field="stream-composer-photo-url" />
              <div class="composer-actions">
                <div class="quick-tags">
                  <span class="quick-tag">All good</span>
                  <span class="quick-tag">Underway</span>
                  <span class="quick-tag">Weather delay</span>
                  <span class="quick-tag">Anchored safely</span>
                </div>
                <button class="btn primary" type="button" data-fpw-field="stream-composer-post">Post Update</button>
              </div>
            </div>

            <div class="glance">
              <div class="glance-top">
                <h4>Pinned: Today at a glance</h4>
                <span data-fpw-field="stream-glance-updated">Updated 2 min ago</span>
              </div>
              <div class="glance-grid">
                <div class="glance-item">
                  <small>Miles Today</small>
                  <strong data-fpw-field="stream-glance-miles">16.1</strong>
                  <span>Tracked on the active leg</span>
                </div>
                <div class="glance-item">
                  <small>Hours Underway</small>
                  <strong data-fpw-field="stream-glance-hours">4.8</strong>
                  <span>Elapsed travel time today</span>
                </div>
                <div class="glance-item">
                  <small>Last Check-In</small>
                  <strong data-fpw-field="stream-glance-checkin">24m</strong>
                  <span>Fresh enough for high confidence</span>
                </div>
                <div class="glance-item">
                  <small>Next Stop</small>
                  <strong data-fpw-field="stream-glance-next-stop">AK</strong>
                  <span>Anclote Key anchorage</span>
                </div>
              </div>
            </div>

            <div class="feed" data-fpw-field="stream-feed">
              <div class="feed-card">
                <div class="feed-head">
                  <div class="feed-left">
                    <div class="avatar">FP</div>
                    <div>
                      <div class="feed-title">FloatPlanWizard milestone</div>
                      <div class="feed-meta">2 min ago · Automated route update</div>
                    </div>
                  </div>
                  <div class="feed-flag">System</div>
                </div>
                <p>Current position updated. The vessel remains on the active route leg with no missed check-ins and an arrival estimate around 4:30 PM.</p>
              </div>

              <div class="feed-card">
                <div class="feed-head">
                  <div class="feed-left">
                    <div class="avatar">OW</div>
                    <div>
                      <div class="feed-title">Captain update</div>
                      <div class="feed-meta">24 min ago · Owner post</div>
                    </div>
                  </div>
                  <div class="feed-flag">Pinned</div>
                </div>
                <p>All good out here. Light chop, easy run so far, and we should be on the hook at Anclote Key later this afternoon.</p>
                <div class="reactions">
                  <span class="reaction">👍 Following</span>
                  <span class="reaction">❤️ Glad to hear</span>
                  <span class="reaction">⛵ Looking great</span>
                </div>
              </div>

              <div class="feed-card">
                <div class="feed-head">
                  <div class="feed-left">
                    <div class="avatar">FP</div>
                    <div>
                      <div class="feed-title">Departure recorded</div>
                      <div class="feed-meta">8:12 AM · Automated event</div>
                    </div>
                  </div>
                  <div class="feed-flag">Timeline</div>
                </div>
                <p>The trip began from home dock and monitoring was activated for this shared route page.</p>
              </div>
            </div>
          </article>
        </div>
      </section>
    </main>
  </div>

  <script id="followPageContext" type="application/json"><cfoutput>{"fpwBase":"#JSStringFormat(request.fpwBase)#"}</cfoutput></script>

  <cfinclude template="../includes/footer_scripts.cfm">
  <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js" integrity="sha256-20nQCchB9co0qIjJZRGuk2/Z9VM+kNiyxNV1lvTlZBo=" crossorigin=""></script>
  <script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/app/follow/followMap.js?v=20260303c"></script>
  <script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/app/follow/follow.js?v=20260320h"></script>
</body>
</html>
