<cfprocessingdirective pageencoding="utf-8">
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width,initial-scale=1" />
  <title>FloatPlanWizard - Family and Friends</title>

  <cfinclude template="../includes/header_styles.cfm">
  <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" integrity="sha256-p4NxAoJBhIIN+hmNHrzRCf9tD/miZyoHS5obTRR9BMY=" crossorigin="" />
<link rel="stylesheet" href="<cfoutput>#request.fpwBase#</cfoutput>/assets/css/follow.css?v=20260611-follow-card-surfaces" />
  <style>
    body.follow-loading { overflow: hidden; }
    body.follow-loading .app { visibility: hidden; }
    .follow-loader {
      position: fixed;
      inset: 0;
      display: flex;
      align-items: center;
      justify-content: center;
      visibility: hidden;
      opacity: 0;
    }
    body.follow-loading .follow-loader {
      visibility: visible;
      opacity: 1;
    }
  </style>
</head>
<body class="follow-body follow-loading">
  <div class="follow-loader" id="followLoader" role="status" aria-live="polite" aria-atomic="true">
    <div class="follow-loader__card">
      <div class="follow-loader__eyebrow">FloatPlanWizard</div>
      <h2 class="follow-loader__phase" id="followLoaderPhase">Follow Page Loading</h2>
      <div class="follow-loader__percent" id="followLoaderPercent">0%</div>
      <div class="follow-loader__bar" aria-hidden="true"><span id="followLoaderBar"></span></div>
      <p class="follow-loader__message" id="followLoaderMessage">Preparing the shared trip view.</p>
    </div>
  </div>
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
          <div class="trip-title" data-fpw-field="trip-card-title" hidden>—</div>
          <span class="pill good" data-fpw-field="trip-card-status-pill" hidden>—</span>
        </div>

        <div class="trip-meta">
          <div><strong>Share link:</strong> <span class="trip-link" data-fpw-field="trip-card-share-link">—</span></div>
          <div hidden><strong>Last check-in:</strong> <span data-fpw-field="trip-card-last-checkin">—</span> &nbsp; | &nbsp; <strong>Viewers:</strong> <span data-fpw-field="trip-card-viewer-count">—</span></div>
          <div><strong>Vessel:</strong> <span data-fpw-field="trip-card-vessel">—</span> &nbsp; | &nbsp; <strong>Privacy:</strong> <span data-fpw-field="trip-card-privacy">—</span></div>
          <div hidden><strong>Monitoring:</strong> <span data-fpw-field="trip-card-monitoring">—</span></div>
        </div>

        <div class="trip-actions">
          <button class="btn primary" id="copyLinkBtn" type="button" data-fpw-field="trip-card-copy-link">Copy Link</button>
          <button class="btn secondary" type="button" data-fpw-field="trip-card-text-link">Text Link</button>
          <button class="btn ghost" id="privacyBtn" type="button" data-fpw-field="trip-card-privacy-action">Privacy</button>
        </div>

      </section>

      <section class="sidebar-note follow-track-log-card" id="followTrackLogCard" data-fpw-region="track-log-card">
        <div class="follow-track-log-header">
          <div>
            <h2>Track Log</h2>
            <p>Check-ins shared during this voyage.</p>
          </div>
          <span class="follow-track-log-count" data-fpw-field="track-log-count">0 check-ins</span>
        </div>
        <div class="follow-track-log-list" id="followTrackLogList" data-fpw-field="track-log-list" aria-live="polite">
          <div class="follow-track-log-empty">No check-ins shared yet.</div>
        </div>
      </section>

      <section class="sidebar-note follow-float-plan-card" id="followFloatPlanCard" data-fpw-region="float-plan-card">
        <div class="follow-float-plan-icon" aria-hidden="true">PDF</div>
        <div class="follow-float-plan-body">
          <h2>Float Plan</h2>
          <p>Download the filed float plan for this voyage.</p>
          <a class="follow-primary-action is-disabled" aria-disabled="true" data-fpw-field="float-plan-download-action">Float plan PDF unavailable</a>
          <p class="follow-card-meta" data-fpw-field="float-plan-meta">PDF unavailable</p>
        </div>
      </section>

      <section class="sidebar-note follow-monitoring-card" id="followMonitoringCard" data-fpw-region="monitoring-card">
        <div class="follow-monitoring-header">
          <span data-fpw-field="trip-card-monitor-state-text"><strong>—</strong><br />—</span>
          <span class="pill good" data-fpw-field="trip-card-monitor-state-pill">—</span>
        </div>
      </section>
    </aside>

    <main class="main">
      <div class="topbar" data-fpw-region="topbar">
        <div class="page-title">
          <h2 data-fpw-field="page-title">—</h2>
          <p data-fpw-field="page-subtitle">Follow the planned route, reported progress, trip updates, comments, and latest check-in.</p>
        </div>

        <div class="topbar-right">
          <div class="live-chip" data-fpw-field="live-chip">Latest check-in: —</div>
        </div>
      </div>

      <section class="journey-strip card" data-fpw-region="journey-strip">
        <div class="journey-head">
          <div>
            <div class="journey-title">Voyage Progress</div>
            <div class="journey-sub" data-fpw-field="journey-subtitle">—</div>
          </div>
          <div class="pill good" data-fpw-field="journey-status-pill">—</div>
        </div>
        <div class="progress-rail"><span data-fpw-field="journey-progress-fill"></span></div>
        <div class="journey-stops">
          <article class="card stat-card">
            <div class="stat-top"><span>Status</span><span class="status-dot"></span></div>
            <h3 data-fpw-field="card-status-title">—</h3>
            <div class="big" data-fpw-field="card-status-value">—</div>
            <p data-fpw-field="card-status-copy">—</p>
          </article>
          <div class="journey-stop">
            <div class="kicker" data-fpw-field="journey-departure-label">Scheduled Departure</div>
            <strong data-fpw-field="journey-departed-value">—</strong>
            <small data-fpw-field="journey-departed-meta">—</small>
          </div>
          <div class="journey-stop">
            <div class="kicker">Current leg</div>
            <strong data-fpw-field="journey-current-leg-value">—</strong>
            <small data-fpw-field="journey-current-leg-meta">—</small>
          </div>
          <div class="journey-stop">
            <div class="kicker">Next stop</div>
            <strong data-fpw-field="journey-next-stop-value">—</strong>
            <small data-fpw-field="journey-next-stop-meta">—</small>
          </div>
          <div class="journey-stop">
            <div class="kicker">Check-in</div>
            <strong data-fpw-field="journey-checkin-value">—</strong>
            <small data-fpw-field="journey-checkin-meta">—</small>
          </div>
          <article class="card stat-card">
            <div class="stat-top"><span>Conditions</span><span>SEA</span></div>
            <h3 data-fpw-field="card-conditions-title">—</h3>
            <div class="big" data-fpw-field="card-conditions-value">—</div>
            <p data-fpw-field="card-conditions-copy">—</p>
          </article>
        </div>
      </section>

      <section class="content-grid">
        <div class="stack">
          <article class="card map-panel" data-fpw-region="map-panel">
            <div class="panel-head">
              <div>
                <h3 data-fpw-field="map-panel-title">Map Overview</h3>
                <p data-fpw-field="map-panel-subtitle">Planned route, estimated route progress, completed legs, and destination.</p>
              </div>
              <button class="btn secondary" id="openFullMapBtn" type="button" data-fpw-field="map-open-full-map">Open Full Map</button>
            </div>
            <div class="map-wrap">
              <div id="followMap" class="map-canvas" data-fpw-field="map-shell" aria-label="Voyage route map"></div>
              <div class="map-badges" data-fpw-field="map-badges">
                <div class="map-badge">Completed leg</div>
                <div class="map-badge">Active leg</div>
                <div class="map-badge">Estimated route progress</div>
              </div>
            </div>
            <p class="follow-map-safety" data-fpw-field="map-position-note" role="note" aria-live="polite">
              No position update has been reported yet. Any route-progress marker shown is estimated. FPW is not continuous live vessel tracking.
            </p>
          </article>

          <section class="mini-grid" data-fpw-region="lower-cards">
            <article class="card mini-card">
              <h4>Today’s Progress</h4>
              <div class="metric" data-fpw-field="today-progress-metric">—</div>
              <div class="label-line" data-fpw-field="today-progress-location">—</div>
              <div class="label-line" data-fpw-field="today-progress-eta">—</div>
            </article>

            <article class="card mini-card">
              <h4>Latest Photos</h4>
              <div class="label-line"><strong data-fpw-field="latest-photos-count">—</strong></div>
              <div class="label-line" data-fpw-field="latest-photos-copy">Photos from the trip appear here for friends and family.</div>
              <div class="photo-row" data-fpw-field="latest-photos-row">
                <div class="photo"></div>
                <div class="photo"></div>
                <div class="photo"></div>
              </div>
            </article>

            <article class="card mini-card">
              <h4>Trip Summary</h4>
              <div class="metric trip-summary-metric" data-fpw-field="trip-summary-metric">—</div>
              <div class="summary-list">
                <div data-fpw-field="trip-summary-distance">—</div>
                <div data-fpw-field="trip-summary-confidence">—</div>
                <div data-fpw-field="trip-summary-mode">—</div>
                <div data-fpw-field="trip-summary-safety">—</div>
              </div>
            </article>
          </section>

          <section class="mini-grid" data-fpw-region="lower-glance-row">
            <div class="glance-item">
              <small>Hours Underway</small>
              <strong data-fpw-field="stream-glance-hours">—</strong>
              <span>Total elapsed travel time</span>
            </div>
            <div class="glance-item">
              <small>Reported Progress</small>
              <strong data-fpw-field="stream-glance-checkin">—</strong>
              <span data-fpw-field="stream-glance-checkin-meta">—</span>
            </div>
            <div class="glance-item">
              <small>Next Stop</small>
              <strong data-fpw-field="stream-glance-next-stop">—</strong>
              <span data-fpw-field="stream-glance-next-stop-meta">—</span>
            </div>
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
                <p>No missed required check-ins have been recorded at this time. This does not confirm the vessel’s latest condition or location.</p>
              </div>
              <div class="trust-card">
                <h4>Why ETA can shift</h4>
                <p>Arrival estimates can move with pace, route changes, conditions, and reported check-in timing.</p>
              </div>
              <div class="trust-card">
                <h4>If something changes</h4>
                <p>Automated monitoring status can change when an expected check-in is not recorded or the captain reports a concern. FPW does not verify emergencies or dispatch assistance.</p>
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
                  <strong>—</strong>
                  <small>—</small>
                </div>
                <div class="overlay-card" data-fpw-field="timeline-eff-speed">
                  <div class="kicker">Eff speed</div>
                  <strong>—</strong>
                  <small>—</small>
                </div>
                <div class="overlay-card" data-fpw-field="timeline-fuel-reserve">
                  <div class="kicker">Fuel + reserve</div>
                  <strong>—</strong>
                  <small>—</small>
                </div>
                <div class="overlay-card" data-fpw-field="timeline-next-update">
                  <div class="kicker">Next update</div>
                  <strong>—</strong>
                  <small>—</small>
                </div>
              </div>

              <div class="timeline" data-fpw-field="timeline-events">
                <div class="time-row">
                  <div class="time-stamp">—</div>
                  <div class="time-line"><div class="time-dot">1</div></div>
                  <div class="time-card">
                    <h4>—</h4>
                    <p>—</p>
                  </div>
                </div>

                <div class="time-row">
                  <div class="time-stamp">—</div>
                  <div class="time-line"><div class="time-dot">2</div></div>
                  <div class="time-card">
                    <h4>—</h4>
                    <p>—</p>
                  </div>
                </div>

                <div class="time-row">
                  <div class="time-stamp">—</div>
                  <div class="time-line"><div class="time-dot">3</div></div>
                  <div class="time-card">
                    <h4>—</h4>
                    <p>—</p>
                  </div>
                </div>

                <div class="time-row">
                  <div class="time-stamp">—</div>
                  <div class="time-line"><div class="time-dot">4</div></div>
                  <div class="time-card">
                    <h4>—</h4>
                    <p>—</p>
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
            </div>

            <div class="composer">
              <div class="composer-top">
                <div class="avatar" id="composerAvatar">—</div>
                <textarea placeholder="Post a quick voyage update for family and friends..." data-fpw-field="stream-composer-text"></textarea>
              </div>
              <input type="file" accept="image/*" data-fpw-field="stream-composer-photo-url" />
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

            <div class="feed" data-fpw-field="stream-feed">
              <div class="feed-card">
                <div class="feed-head">
                  <div class="feed-left">
                    <div class="avatar">FP</div>
                    <div>
                      <div class="feed-title">—</div>
                      <div class="feed-meta">—</div>
                    </div>
                  </div>
                  <div class="feed-flag">System</div>
                </div>
                <p>—</p>
              </div>

              <div class="feed-card">
                <div class="feed-head">
                  <div class="feed-left">
                    <div class="avatar">—</div>
                    <div>
                      <div class="feed-title">—</div>
                      <div class="feed-meta">—</div>
                    </div>
                  </div>
                  <div class="feed-flag">Pinned</div>
                </div>
                <p>—</p>
                <div class="reactions">
                  <span class="reaction">—</span>
                  <span class="reaction">—</span>
                  <span class="reaction">—</span>
                </div>
              </div>

              <div class="feed-card">
                <div class="feed-head">
                  <div class="feed-left">
                    <div class="avatar">FP</div>
                    <div>
                      <div class="feed-title">—</div>
                      <div class="feed-meta">—</div>
                    </div>
                  </div>
                  <div class="feed-flag">Timeline</div>
                </div>
                <p>—</p>
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
  <script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/app/follow/followMap.js?v=20260526-cache-bump"></script>
  <script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/app/follow/follow.js?v=20260802-scheduled-actual-departure"></script>
</body>
</html>
