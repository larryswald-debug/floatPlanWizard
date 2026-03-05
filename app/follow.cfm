<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width,initial-scale=1" />
  <title>FloatPlanWizard - Family and Friends</title>

  <cfinclude template="../includes/header_styles.cfm">
  <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" integrity="sha256-p4NxAoJBhIIN+hmNHrzRCf9tD/miZyoHS5obTRR9BMY=" crossorigin="" />
  <link rel="stylesheet" href="<cfoutput>#request.fpwBase#</cfoutput>/assets/css/follow.css?v=20260303c" />
</head>
<body class="follow-body">
  <div class="shell">
    <aside class="sidebar">
      <div class="brand">
        <div class="logo"></div>
        <div>
          <h1>FloatPlanWizard</h1>
          <small>Family and Friends</small>
        </div>
      </div>

      <div class="shareCard">
        <div class="shareRow">
          <div id="shareTitle" class="shareTitle">Voyage Stream</div>
          <span id="shareStatusPill" class="pill">LIVE</span>
        </div>
        <div class="shareMeta">
          Share link: <span id="sharePath" class="mono">/follow</span><br />
          Last check-in: <b id="shareLastCheckin">n/a</b> <span class="metaSep">|</span> Viewers: <b id="shareViewerCount">0</b>
        </div>
        <div class="shareActions">
          <button class="btn primary" id="copyLinkBtn" type="button">Copy Link</button>
          <button class="btn" id="privacyBtn" type="button">Privacy</button>
        </div>
      </div>

      <nav class="nav" aria-label="Sections">
        <a class="active" href="#" onclick="return false;">Overview <span class="badge">Live</span></a>
        <a href="#" onclick="return false;">Map <span class="badge">Route</span></a>
        <a href="#" onclick="return false;">Stream <span class="badge">Posts</span></a>
        <a href="#" onclick="return false;">Photos <span class="badge">Media</span></a>
        <a href="#" onclick="return false;">Trip Stats <span class="badge">Milestones</span></a>
      </nav>

      <div class="sidebarFooter">
        This shared page translates route progress and check-ins into one clear timeline for friends and family.
      </div>
    </aside>

    <main class="main">
      <div class="topbar">
        <div class="tripTitle">
          <h2 id="tripTitle">Voyage Overview</h2>
          <p id="tripSubtitle">Follow along in real time: location, progress, updates, and comments.</p>
        </div>

        <div class="topbarActions">
          <div class="segmented" role="tablist" aria-label="Viewer mode">
            <button class="active" type="button">Family</button>
            <button type="button">Expedition</button>
            <button type="button">Kid Mode</button>
          </div>
          <button class="btn" id="notifyBtn" type="button">Notify Me</button>
        </div>
      </div>

      <section class="cardsRow">
        <div class="card">
          <div class="label"><span>Status</span><span class="dot"></span></div>
          <div class="value" id="cardStatusValue">n/a</div>
          <div class="sub" id="cardStatusSub">Last check-in: n/a</div>
        </div>

        <div class="card">
          <div class="label"><span>Current Location</span><span class="tinyIcon">LOC</span></div>
          <div class="value" id="cardLocationValue">n/a</div>
          <div class="sub" id="cardLocationSub">Heading: n/a</div>
        </div>

        <div class="card">
          <div class="label"><span>ETA</span><span class="tinyIcon">ETA</span></div>
          <div class="value" id="cardEtaValue">n/a</div>
          <div class="sub" id="cardEtaSub">Route progress unavailable</div>
        </div>

        <div class="card">
          <div class="label"><span>Conditions</span><span class="tinyIcon">SEA</span></div>
          <div class="value" id="cardConditionsValue">n/a</div>
          <div class="sub" id="cardConditionsSub">No weather details available</div>
        </div>
      </section>

      <section class="grid">
        <div>
          <div class="mapPanel">
            <div class="panelHeader">
              <div>
                <h3>Map Overview</h3>
                <div class="hint">FPW route map with route line, leg pins, and current position</div>
              </div>
              <button class="btn tiny" id="openFullMapBtn" type="button">Open Full Map</button>
            </div>

            <div class="map" id="followMap">
              <div class="mapOverlay">
                <div class="miniCard">
                  <div class="k"><span>Today's Leg</span><span>LEG</span></div>
                  <div class="v" id="overlayLeg">n/a</div>
                </div>
                <div class="miniCard">
                  <div class="k"><span>Progress</span><span>NM</span></div>
                  <div class="v" id="overlayProgress">n/a</div>
                </div>
                <div class="miniCard">
                  <div class="k"><span>Next Check-In</span><span>ETA</span></div>
                  <div class="v" id="overlayCheckin">n/a</div>
                </div>
              </div>
            </div>
          </div>

          <div class="belowMapRow">
            <div class="card">
              <div class="label"><span>Today's Progress</span><span class="tinyIcon">LOG</span></div>
              <div class="value" id="progressHours">n/a</div>
              <div class="sub" id="progressSub">No travel progress yet.</div>
              <div class="progressBar" aria-label="Progress bar">
                <div class="fill" id="progressFill"></div>
                <div class="marker" id="progressMarker"></div>
              </div>
            </div>

            <div class="card">
              <div class="label"><span>Latest Photos</span><span class="tinyIcon">PIC</span></div>
              <div class="value" id="photoCount">0 new</div>
              <div class="sub">Recent media posts from this voyage stream</div>
              <div class="thumbs">
                <div class="thumb"></div>
                <div class="thumb"></div>
                <div class="thumb"></div>
              </div>
            </div>

            <div class="card">
              <div class="label"><span>Trip Summary</span><span class="tinyIcon">SUM</span></div>
              <div class="value" id="summaryMiles">0 mi</div>
              <div class="sub" id="summarySub">0 days | 0 locks | 0 events</div>
              <div class="summaryMeta" id="summaryMeta">Confidence: n/a</div>
            </div>
          </div>

          <section class="follow-timeline-panel" id="followTimelineSection" aria-label="Cruise timeline">
            <div class="follow-timeline-head">
              <div>
                <div class="follow-timeline-kicker">Timeline</div>
                <h3 class="follow-timeline-title">Cruise Timeline</h3>
              </div>
            </div>
            <div class="follow-timeline-summary" id="followTimelineSummary">
              <div class="follow-timeline-empty">Timeline not available yet.</div>
            </div>
            <div class="follow-timeline-leglist" id="followTimelineLegList"></div>
          </section>
        </div>

        <aside class="streamPanel">
          <div class="streamHead">
            <div>
              <h3>Voyage Stream</h3>
              <div class="meta">Updates, photos, reactions, and comments</div>
            </div>
            <button class="btn tiny primary" id="followActionBtn" type="button">Follow</button>
          </div>

          <div class="composer" id="composerBlock">
            <div class="avatar" id="composerAvatar">FP</div>
            <div class="composerBox">
              <textarea class="textarea" id="composerText" placeholder="Post a quick update for family and friends..."></textarea>
              <input class="photoUrlInput" id="composerPhotoUrl" type="url" placeholder="Optional photo URL (MVP)" />
              <div class="composerActions">
                <div class="hintRow">
                  <button class="chip" type="button" data-template="All good - on schedule.">All good</button>
                  <button class="chip" type="button" data-template="Minor weather delay.">Weather delay</button>
                  <button class="chip" type="button" data-template="Docked safely for the evening.">Docked safely</button>
                </div>
                <button class="btn primary" id="composerPostBtn" type="button">Post</button>
              </div>
              <div class="composerHelp" id="composerHelp">Owner posting enabled.</div>
            </div>
          </div>

          <div class="stream" id="stream">
            <div class="pinned" id="pinnedCard">
              <div class="pinnedTop">
                <strong>Pinned: Today at a glance</strong>
                <span id="pinnedUpdated">Updated n/a</span>
              </div>
              <div class="statsGrid">
                <div class="stat">
                  <div class="k">Miles Traveled</div>
                  <div class="v" id="pinnedMiles">0</div>
                </div>
                <div class="stat">
                  <div class="k">Days Underway</div>
                  <div class="v" id="pinnedDays">0</div>
                </div>
                <div class="stat">
                  <div class="k">Locks Completed</div>
                  <div class="v" id="pinnedLocks">0</div>
                </div>
                <div class="stat">
                  <div class="k">Wildlife</div>
                  <div class="v" id="pinnedWildlife">0</div>
                </div>
              </div>
            </div>

            <div id="postsContainer"></div>
          </div>
        </aside>
      </section>
    </main>
  </div>

  <cfinclude template="../includes/footer_scripts.cfm">
  <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js" integrity="sha256-20nQCchB9co0qIjJZRGuk2/Z9VM+kNiyxNV1lvTlZBo=" crossorigin=""></script>
  <script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/app/follow/followMap.js?v=20260303c"></script>
  <script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/app/follow/follow.js?v=20260304a"></script>
</body>
</html>
