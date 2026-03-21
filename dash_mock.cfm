<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>FPW Dashboard Approved Mockup</title>
  <style>
    :root{
      --bg:#07111c;
      --panel:#0d1b2a;
      --panel-2:#112236;
      --panel-3:#0f2740;
      --line:rgba(255,255,255,.08);
      --line-2:rgba(120,180,255,.18);
      --text:#eaf4ff;
      --muted:#9eb3c8;
      --soft:#7f97af;
      --accent:#49b3ff;
      --accent-2:#6fe0ff;
      --green:#35d07f;
      --amber:#ffbe55;
      --red:#ff6c6c;
      --purple:#8f8cff;
      --shadow:0 16px 42px rgba(0,0,0,.35);
      --radius:20px;
      --radius-sm:14px;
      --glow:0 0 0 1px rgba(111,224,255,.08), 0 0 24px rgba(73,179,255,.08);
    }

    *{box-sizing:border-box}
    html,body{margin:0;padding:0;background:
      radial-gradient(circle at top left, rgba(73,179,255,.12), transparent 28%),
      radial-gradient(circle at top right, rgba(111,224,255,.08), transparent 22%),
      linear-gradient(180deg,#07111c 0%, #091522 100%);
      color:var(--text);
      font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Helvetica,Arial,sans-serif;
    }

    .wrap{
      width:min(1280px, calc(100% - 32px));
      margin:24px auto 42px;
    }

    .topbar{
      display:flex;
      align-items:center;
      justify-content:space-between;
      gap:16px;
      margin-bottom:20px;
    }

    .brand{
      display:flex;
      flex-direction:column;
      gap:4px;
    }

    .brand-title{
      font-size:28px;
      font-weight:800;
      letter-spacing:.02em;
    }

    .brand-sub{
      color:var(--muted);
      font-size:14px;
    }

    .top-actions{
      display:flex;
      gap:10px;
      flex-wrap:wrap;
    }

    .btn{
      border:none;
      cursor:pointer;
      border-radius:999px;
      padding:11px 16px;
      font-weight:700;
      font-size:14px;
      color:var(--text);
      background:linear-gradient(180deg, rgba(255,255,255,.07), rgba(255,255,255,.03));
      border:1px solid var(--line);
      box-shadow:var(--glow);
    }

    .btn-primary{
      background:linear-gradient(180deg, rgba(73,179,255,.28), rgba(73,179,255,.14));
      border-color:rgba(73,179,255,.32);
    }

    .btn-soft{
      color:var(--muted);
    }

    .panel{
      background:
        linear-gradient(180deg, rgba(255,255,255,.03), rgba(255,255,255,.015)),
        linear-gradient(180deg, var(--panel-2), var(--panel));
      border:1px solid var(--line);
      border-radius:var(--radius);
      box-shadow:var(--shadow);
      position:relative;
      overflow:hidden;
    }

    .panel::before{
      content:"";
      position:absolute;
      inset:0;
      background:linear-gradient(180deg, rgba(111,224,255,.03), transparent 28%);
      pointer-events:none;
    }

    .panel-inner{
      position:relative;
      padding:18px;
      z-index:1;
    }

    .section-head{
      display:flex;
      align-items:center;
      justify-content:space-between;
      gap:12px;
      margin-bottom:14px;
    }

    .section-title{
      font-size:18px;
      font-weight:800;
      letter-spacing:.01em;
    }

    .section-sub{
      font-size:13px;
      color:var(--muted);
      margin-top:4px;
    }

    .pill{
      display:inline-flex;
      align-items:center;
      gap:8px;
      padding:7px 12px;
      border-radius:999px;
      font-size:12px;
      font-weight:800;
      letter-spacing:.03em;
      text-transform:uppercase;
      border:1px solid var(--line);
      background:rgba(255,255,255,.04);
      color:var(--muted);
    }

    .pill.green{color:#c9ffe1;background:rgba(53,208,127,.12);border-color:rgba(53,208,127,.28)}
    .pill.amber{color:#ffe6bf;background:rgba(255,190,85,.12);border-color:rgba(255,190,85,.28)}
    .pill.red{color:#ffd1d1;background:rgba(255,108,108,.12);border-color:rgba(255,108,108,.28)}
    .pill.blue{color:#d6f0ff;background:rgba(73,179,255,.12);border-color:rgba(73,179,255,.28)}
    .pill.purple{color:#e4e1ff;background:rgba(143,140,255,.12);border-color:rgba(143,140,255,.28)}

    .summary-grid{
      display:grid;
      grid-template-columns:repeat(8,1fr);
      gap:12px;
      margin-bottom:18px;
    }

    .summary-tile{
      min-height:96px;
      padding:14px;
      border-radius:16px;
      background:linear-gradient(180deg, rgba(255,255,255,.04), rgba(255,255,255,.02));
      border:1px solid var(--line);
      box-shadow:var(--glow);
    }

    .summary-label{
      color:var(--muted);
      font-size:12px;
      text-transform:uppercase;
      letter-spacing:.08em;
      font-weight:800;
      margin-bottom:10px;
    }

    .summary-value{
      font-size:18px;
      font-weight:800;
      line-height:1.2;
      margin-bottom:6px;
    }

    .summary-meta{
      font-size:12px;
      color:var(--soft);
    }

    .hero-grid{
      display:grid;
      grid-template-columns:1.35fr 1fr;
      gap:16px;
      margin-bottom:16px;
    }

    .ops-grid{
      display:grid;
      grid-template-columns:1.2fr 1fr .9fr;
      gap:16px;
      margin-bottom:16px;
    }

    .setup-grid{
      display:grid;
      grid-template-columns:repeat(4,1fr);
      gap:16px;
      margin-bottom:16px;
    }

    .two-col{
      display:grid;
      grid-template-columns:1.15fr .85fr;
      gap:16px;
    }

    .route-hero{
      display:grid;
      grid-template-columns:1.1fr .9fr;
      gap:18px;
      align-items:start;
    }

    .route-title{
      font-size:28px;
      font-weight:900;
      line-height:1.1;
      margin:8px 0 10px;
    }

    .route-sub{
      color:var(--muted);
      font-size:14px;
      line-height:1.5;
      margin-bottom:18px;
    }

    .stat-row{
      display:grid;
      grid-template-columns:repeat(4,1fr);
      gap:10px;
      margin-bottom:18px;
    }

    .mini-stat{
      padding:12px;
      border-radius:14px;
      border:1px solid var(--line);
      background:rgba(255,255,255,.03);
    }

    .mini-stat-label{
      font-size:11px;
      color:var(--muted);
      text-transform:uppercase;
      letter-spacing:.08em;
      font-weight:800;
      margin-bottom:8px;
    }

    .mini-stat-value{
      font-size:18px;
      font-weight:800;
    }

    .progress-wrap{
      margin:10px 0 14px;
    }

    .progress-top{
      display:flex;
      justify-content:space-between;
      gap:10px;
      font-size:13px;
      color:var(--muted);
      margin-bottom:8px;
    }

    .progress{
      width:100%;
      height:12px;
      border-radius:999px;
      background:rgba(255,255,255,.06);
      border:1px solid var(--line);
      overflow:hidden;
    }

    .progress-bar{
      height:100%;
      width:58%;
      border-radius:999px;
      background:linear-gradient(90deg, var(--accent), var(--accent-2));
      box-shadow:0 0 20px rgba(73,179,255,.35);
    }

    .action-row{
      display:flex;
      flex-wrap:wrap;
      gap:10px;
      margin-top:16px;
    }

    .callout-list{
      display:grid;
      gap:10px;
    }

    .callout{
      border:1px solid var(--line);
      background:rgba(255,255,255,.03);
      border-radius:14px;
      padding:12px 14px;
    }

    .callout-title{
      font-size:13px;
      color:var(--muted);
      text-transform:uppercase;
      letter-spacing:.07em;
      font-weight:800;
      margin-bottom:6px;
    }

    .callout-value{
      font-size:17px;
      font-weight:800;
      margin-bottom:4px;
    }

    .callout-meta{
      font-size:12px;
      color:var(--soft);
    }

    .monitor-grid{
      display:grid;
      grid-template-columns:repeat(2,1fr);
      gap:10px;
      margin:14px 0 16px;
    }

    .monitor-tile{
      padding:13px;
      border-radius:14px;
      border:1px solid var(--line);
      background:rgba(255,255,255,.03);
    }

    .monitor-label{
      color:var(--muted);
      font-size:11px;
      text-transform:uppercase;
      letter-spacing:.08em;
      font-weight:800;
      margin-bottom:8px;
    }

    .monitor-value{
      font-size:18px;
      font-weight:800;
      margin-bottom:4px;
    }

    .monitor-meta{
      font-size:12px;
      color:var(--soft);
    }

    .weather-core{
      display:grid;
      grid-template-columns:repeat(4,1fr);
      gap:10px;
      margin-top:10px;
    }

    .weather-chip{
      min-height:102px;
      padding:14px;
      border-radius:14px;
      border:1px solid var(--line);
      background:linear-gradient(180deg, rgba(255,255,255,.04), rgba(255,255,255,.02));
    }

    .weather-label{
      color:var(--muted);
      font-size:11px;
      text-transform:uppercase;
      letter-spacing:.08em;
      font-weight:800;
      margin-bottom:10px;
    }

    .weather-value{
      font-size:26px;
      font-weight:900;
      margin-bottom:4px;
    }

    .weather-meta{
      font-size:12px;
      color:var(--soft);
    }

    .day-card-list,
    .quick-list,
    .insight-list,
    .timeline-list{
      display:grid;
      gap:10px;
    }

    .row-card{
      border:1px solid var(--line);
      background:rgba(255,255,255,.03);
      border-radius:14px;
      padding:13px 14px;
    }

    .row-label{
      color:var(--muted);
      font-size:11px;
      text-transform:uppercase;
      letter-spacing:.08em;
      font-weight:800;
      margin-bottom:7px;
    }

    .row-value{
      font-size:16px;
      font-weight:800;
      margin-bottom:4px;
    }

    .row-meta{
      font-size:12px;
      color:var(--soft);
    }

    .quick-btn{
      width:100%;
      text-align:left;
      border-radius:14px;
      border:1px solid var(--line);
      background:linear-gradient(180deg, rgba(255,255,255,.04), rgba(255,255,255,.02));
      color:var(--text);
      padding:14px 15px;
      font-size:14px;
      font-weight:800;
      cursor:pointer;
    }

    .timeline-card{
      border:1px solid var(--line);
      border-radius:16px;
      background:linear-gradient(180deg, rgba(255,255,255,.04), rgba(255,255,255,.02));
      padding:15px;
    }

    .timeline-top{
      display:flex;
      justify-content:space-between;
      gap:12px;
      align-items:flex-start;
      margin-bottom:12px;
    }

    .timeline-title{
      font-size:18px;
      font-weight:900;
      margin-bottom:6px;
    }

    .timeline-sub{
      color:var(--muted);
      font-size:13px;
    }

    .badge-row{
      display:flex;
      flex-wrap:wrap;
      gap:8px;
      margin-bottom:12px;
    }

    .metric-row{
      display:grid;
      grid-template-columns:repeat(4,1fr);
      gap:10px;
      margin-bottom:14px;
    }

    .metric{
      padding:12px;
      border-radius:12px;
      border:1px solid var(--line);
      background:rgba(255,255,255,.025);
    }

    .metric-label{
      color:var(--muted);
      font-size:11px;
      text-transform:uppercase;
      letter-spacing:.08em;
      font-weight:800;
      margin-bottom:8px;
    }

    .metric-value{
      font-size:16px;
      font-weight:800;
    }

    .timeline-preview{
      display:grid;
      grid-template-columns:repeat(3,1fr);
      gap:10px;
      margin-top:12px;
    }

    .stop-card{
      padding:12px;
      border-radius:12px;
      border:1px solid var(--line);
      background:rgba(255,255,255,.025);
    }

    .stop-step{
      color:var(--muted);
      font-size:11px;
      text-transform:uppercase;
      letter-spacing:.08em;
      font-weight:800;
      margin-bottom:7px;
    }

    .stop-name{
      font-size:15px;
      font-weight:800;
      margin-bottom:4px;
    }

    .stop-meta{
      font-size:12px;
      color:var(--soft);
    }

    .setup-card{
      min-height:170px;
      border:1px solid var(--line);
      border-radius:16px;
      background:linear-gradient(180deg, rgba(255,255,255,.04), rgba(255,255,255,.02));
      padding:16px;
    }

    .setup-title{
      font-size:16px;
      font-weight:800;
      margin-bottom:8px;
    }

    .setup-meta{
      color:var(--muted);
      font-size:13px;
      line-height:1.45;
      margin-bottom:16px;
    }

    .setup-count{
      font-size:28px;
      font-weight:900;
      margin-bottom:16px;
    }

    .insight{
      display:flex;
      justify-content:space-between;
      gap:12px;
      align-items:flex-start;
      padding:14px;
      border:1px solid var(--line);
      border-radius:14px;
      background:rgba(255,255,255,.03);
    }

    .insight-main{
      flex:1;
    }

    .insight-title{
      font-size:15px;
      font-weight:800;
      margin-bottom:5px;
    }

    .insight-meta{
      color:var(--muted);
      font-size:13px;
      line-height:1.45;
    }

    .footnote{
      margin-top:10px;
      color:var(--soft);
      font-size:12px;
    }

    @media (max-width: 1180px){
      .summary-grid{grid-template-columns:repeat(4,1fr)}
      .hero-grid{grid-template-columns:1fr}
      .ops-grid{grid-template-columns:1fr}
      .setup-grid{grid-template-columns:repeat(2,1fr)}
      .route-hero{grid-template-columns:1fr}
      .weather-core{grid-template-columns:repeat(2,1fr)}
      .metric-row{grid-template-columns:repeat(2,1fr)}
      .timeline-preview{grid-template-columns:1fr}
      .stat-row{grid-template-columns:repeat(2,1fr)}
    }

    @media (max-width: 760px){
      .wrap{width:min(100% - 20px, 1280px); margin:16px auto 28px}
      .summary-grid{grid-template-columns:repeat(2,1fr)}
      .setup-grid{grid-template-columns:1fr}
      .weather-core{grid-template-columns:1fr}
      .monitor-grid{grid-template-columns:1fr}
      .topbar{flex-direction:column; align-items:flex-start}
      .metric-row{grid-template-columns:1fr}
      .stat-row{grid-template-columns:1fr}
    }
  </style>
</head>
<body>
  <div class="wrap">

    <div class="topbar">
      <div class="brand">
        <div class="brand-title">FloatPlanWizard</div>
        <div class="brand-sub">Mission Control dashboard for Great Loopers and recreational boaters</div>
      </div>
      <div class="top-actions">
        <button class="btn btn-primary">Generate Route</button>
        <button class="btn">Open Float Plan</button>
        <button class="btn">Follower Page</button>
        <button class="btn btn-soft">Settings</button>
      </div>
    </div>

    <!-- Mission Summary -->
    <section class="panel" style="margin-bottom:16px;">
      <div class="panel-inner">
        <div class="section-head">
          <div>
            <div class="section-title">Mission Summary</div>
            <div class="section-sub">Single-glance status for your current trip, float plan, monitoring, and conditions</div>
          </div>
          <span class="pill blue">Operational Overview</span>
        </div>

        <div class="summary-grid">
          <div class="summary-tile">
            <div class="summary-label">Active Route</div>
            <div class="summary-value">Great Loop Eastbound</div>
            <div class="summary-meta">Template route · 842 nm remaining</div>
          </div>
          <div class="summary-tile">
            <div class="summary-label">Current Phase</div>
            <div class="summary-value">Planning</div>
            <div class="summary-meta">Departure window set for Apr 12</div>
          </div>
          <div class="summary-tile">
            <div class="summary-label">Float Plan</div>
            <div class="summary-value">Draft Ready</div>
            <div class="summary-meta">Last updated 2 hours ago</div>
          </div>
          <div class="summary-tile">
            <div class="summary-label">Monitoring</div>
            <div class="summary-value">Active</div>
            <div class="summary-meta">Check-ins every 6 hours</div>
          </div>
          <div class="summary-tile">
            <div class="summary-label">Follower Page</div>
            <div class="summary-value">Live</div>
            <div class="summary-meta">Public page enabled</div>
          </div>
          <div class="summary-tile">
            <div class="summary-label">Weather Risk</div>
            <div class="summary-value">Moderate</div>
            <div class="summary-meta">Front arriving in 18 hours</div>
          </div>
          <div class="summary-tile">
            <div class="summary-label">Next Milestone</div>
            <div class="summary-value">Demopolis Lock</div>
            <div class="summary-meta">ETA tomorrow 10:40 AM</div>
          </div>
          <div class="summary-tile">
            <div class="summary-label">Active Vessel</div>
            <div class="summary-value">Second Wind</div>
            <div class="summary-meta">Main vessel selected</div>
          </div>
        </div>
      </div>
    </section>

    <!-- Hero Row -->
    <div class="hero-grid">

      <!-- Expedition / Route Status -->
      <section class="panel">
        <div class="panel-inner">
          <div class="section-head">
            <div>
              <div class="section-title">Expedition / Route Status</div>
              <div class="section-sub">Lead with the trip itself so users instantly understand what journey they are managing</div>
            </div>
            <div style="display:flex; gap:8px; flex-wrap:wrap;">
              <span class="pill purple">Great Loop Template</span>
              <span class="pill green">Primary Route</span>
            </div>
          </div>

          <div class="route-hero">
            <div>
              <div class="route-title">Tarpon Springs to Demopolis via Great Loop Segment</div>
              <div class="route-sub">
                This hero panel should be the first major visual anchor. It should communicate the active route, where the boater is in the trip, and what happens next.
              </div>

              <div class="stat-row">
                <div class="mini-stat">
                  <div class="mini-stat-label">Distance</div>
                  <div class="mini-stat-value">1,284 nm</div>
                </div>
                <div class="mini-stat">
                  <div class="mini-stat-label">Remaining</div>
                  <div class="mini-stat-value">842 nm</div>
                </div>
                <div class="mini-stat">
                  <div class="mini-stat-label">Est. Days</div>
                  <div class="mini-stat-value">12.4</div>
                </div>
                <div class="mini-stat">
                  <div class="mini-stat-label">Fuel Est.</div>
                  <div class="mini-stat-value">416 gal</div>
                </div>
              </div>

              <div class="progress-wrap">
                <div class="progress-top">
                  <span>Route Progress</span>
                  <span>58% complete</span>
                </div>
                <div class="progress">
                  <div class="progress-bar"></div>
                </div>
              </div>

              <div class="action-row">
                <button class="btn btn-primary">Open Route</button>
                <button class="btn">Edit Route</button>
                <button class="btn">Route Generator</button>
              </div>
            </div>

            <div class="callout-list">
              <div class="callout">
                <div class="callout-title">Next Leg</div>
                <div class="callout-value">Mobile Bay to Tombigbee Entry</div>
                <div class="callout-meta">62 nm · favorable departure at 7:10 AM</div>
              </div>
              <div class="callout">
                <div class="callout-title">Next Destination</div>
                <div class="callout-value">Demopolis, Alabama</div>
                <div class="callout-meta">Fuel + overnight + provisioning available</div>
              </div>
              <div class="callout">
                <div class="callout-title">Upcoming Operational Point</div>
                <div class="callout-value">Demopolis Lock</div>
                <div class="callout-meta">Plan staging and lock timing</div>
              </div>
              <div class="callout">
                <div class="callout-title">Audience Guidance</div>
                <div class="callout-value">Great Loopers first, recreational boaters welcome</div>
                <div class="callout-meta">This should work for template routes and any custom trip</div>
              </div>
            </div>
          </div>
        </div>
      </section>

      <!-- Float Plan & Monitoring -->
      <section class="panel">
        <div class="panel-inner">
          <div class="section-head">
            <div>
              <div class="section-title">Float Plan & Monitoring</div>
              <div class="section-sub">Promote FPW’s safety and monitoring value much higher in the dashboard</div>
            </div>
            <span class="pill amber">Needs Review</span>
          </div>

          <div class="monitor-grid">
            <div class="monitor-tile">
              <div class="monitor-label">Float Plan Status</div>
              <div class="monitor-value">Draft Ready</div>
              <div class="monitor-meta">2 contacts assigned · not yet filed</div>
            </div>
            <div class="monitor-tile">
              <div class="monitor-label">Monitoring</div>
              <div class="monitor-value">Active</div>
              <div class="monitor-meta">Auto check-ins every 6 hours</div>
            </div>
            <div class="monitor-tile">
              <div class="monitor-label">Last Check-In</div>
              <div class="monitor-value">Today · 6:20 AM</div>
              <div class="monitor-meta">Healthy status received</div>
            </div>
            <div class="monitor-tile">
              <div class="monitor-label">Next Expected</div>
              <div class="monitor-value">12:20 PM</div>
              <div class="monitor-meta">Overdue threshold 2:20 PM</div>
            </div>
          </div>

          <div class="callout-list">
            <div class="callout">
              <div class="callout-title">Follower Page</div>
              <div class="callout-value">Public page enabled</div>
              <div class="callout-meta">Use this area to show slug/link state if already available in FPW</div>
            </div>
            <div class="callout">
              <div class="callout-title">Contacts</div>
              <div class="callout-value">2 emergency contacts configured</div>
              <div class="callout-meta">If none exist, surface a clear next step</div>
            </div>
            <div class="callout">
              <div class="callout-title">Recommended Next Step</div>
              <div class="callout-value">Review and file this float plan before departure</div>
              <div class="callout-meta">Encourage action instead of showing only passive status</div>
            </div>
          </div>

          <div class="action-row">
            <button class="btn btn-primary">Open Float Plan</button>
            <button class="btn">Build / Update</button>
            <button class="btn">Follower Page</button>
            <button class="btn">Monitoring Settings</button>
          </div>
        </div>
      </section>
    </div>

    <!-- Secondary Operational Row -->
    <div class="ops-grid">

      <!-- Weather / Marine Conditions -->
      <section class="panel">
        <div class="panel-inner">
          <div class="section-head">
            <div>
              <div class="section-title">Weather / Marine Conditions</div>
              <div class="section-sub">Still visually strong, but less dominant than route and monitoring</div>
            </div>
            <span class="pill red">1 Marine Alert</span>
          </div>

          <div class="weather-core">
            <div class="weather-chip">
              <div class="weather-label">Wind</div>
              <div class="weather-value">17 kt</div>
              <div class="weather-meta">SE gusting 23 kt</div>
            </div>
            <div class="weather-chip">
              <div class="weather-label">Waves</div>
              <div class="weather-value">2.4 ft</div>
              <div class="weather-meta">Building slightly</div>
            </div>
            <div class="weather-chip">
              <div class="weather-label">Pressure</div>
              <div class="weather-value">29.82</div>
              <div class="weather-meta">Slow fall</div>
            </div>
            <div class="weather-chip">
              <div class="weather-label">Visibility</div>
              <div class="weather-value">8 nm</div>
              <div class="weather-meta">Good</div>
            </div>
          </div>

          <div class="action-row">
            <button class="btn">View Full Marine Panel</button>
          </div>
        </div>
      </section>

      <!-- Today / Next 24 Hours -->
      <section class="panel">
        <div class="panel-inner">
          <div class="section-head">
            <div>
              <div class="section-title">Today / Next 24 Hours</div>
              <div class="section-sub">Operational guidance for immediate planning</div>
            </div>
            <span class="pill blue">Planning Window</span>
          </div>

          <div class="day-card-list">
            <div class="row-card">
              <div class="row-label">Departure Window</div>
              <div class="row-value">Best departure 6:45–8:15 AM</div>
              <div class="row-meta">Lighter wind before frontal boundary tightens</div>
            </div>
            <div class="row-card">
              <div class="row-label">Best Cruise Window</div>
              <div class="row-value">Morning favorable · afternoon caution</div>
              <div class="row-meta">Conditions degrade after 2 PM</div>
            </div>
            <div class="row-card">
              <div class="row-label">Sunrise / Sunset</div>
              <div class="row-value">6:58 AM / 7:41 PM</div>
              <div class="row-meta">Use this area only if current FPW data supports it</div>
            </div>
            <div class="row-card">
              <div class="row-label">Immediate Watch Item</div>
              <div class="row-value">Monitor frontal timing near destination</div>
              <div class="row-meta">Good candidate for a derived guidance card if supported</div>
            </div>
          </div>
        </div>
      </section>

      <!-- Quick Actions -->
      <section class="panel">
        <div class="panel-inner">
          <div class="section-head">
            <div>
              <div class="section-title">Quick Actions</div>
              <div class="section-sub">Reduce hunting around the page for common tasks</div>
            </div>
          </div>

          <div class="quick-list">
            <button class="quick-btn">Generate Route</button>
            <button class="quick-btn">New Float Plan</button>
            <button class="quick-btn">Add Waypoint</button>
            <button class="quick-btn">Add Contact</button>
            <button class="quick-btn">Add Vessel</button>
            <button class="quick-btn">Open Follower Page</button>
          </div>
        </div>
      </section>
    </div>

    <!-- Expedition Timeline -->
    <section class="panel" style="margin-bottom:16px;">
      <div class="panel-inner">
        <div class="section-head">
          <div>
            <div class="section-title">Expedition Timeline</div>
            <div class="section-sub">Keep this important, but place it below the hero row so route status and monitoring lead the story</div>
          </div>
          <span class="pill purple">Active Routes</span>
        </div>

        <div class="timeline-list">
          <div class="timeline-card">
            <div class="timeline-top">
              <div>
                <div class="timeline-title">Great Loop Eastbound · Spring Run</div>
                <div class="timeline-sub">Template-backed expedition route with float plan and follower page support</div>
              </div>
              <div style="display:flex; gap:8px; flex-wrap:wrap; justify-content:flex-end;">
                <span class="pill green">Float Plan Built</span>
                <span class="pill blue">Follower Page Live</span>
              </div>
            </div>

            <div class="badge-row">
              <span class="pill purple">Great Loop</span>
              <span class="pill blue">Primary Vessel</span>
              <span class="pill amber">Moderate Weather Factor</span>
            </div>

            <div class="metric-row">
              <div class="metric">
                <div class="metric-label">Distance</div>
                <div class="metric-value">1,284 nm</div>
              </div>
              <div class="metric">
                <div class="metric-label">Est. Duration</div>
                <div class="metric-value">12.4 days</div>
              </div>
              <div class="metric">
                <div class="metric-label">Fuel</div>
                <div class="metric-value">416 gal</div>
              </div>
              <div class="metric">
                <div class="metric-label">Remaining</div>
                <div class="metric-value">842 nm</div>
              </div>
            </div>

            <div class="action-row">
              <button class="btn btn-primary">Open Route</button>
              <button class="btn">Edit</button>
              <button class="btn">Build Float Plan</button>
              <button class="btn">Follower Page</button>
              <button class="btn btn-soft">More</button>
            </div>

            <div class="timeline-preview">
              <div class="stop-card">
                <div class="stop-step">Next Stop</div>
                <div class="stop-name">Bobby’s Fish Camp</div>
                <div class="stop-meta">Fuel / dockage / overnight</div>
              </div>
              <div class="stop-card">
                <div class="stop-step">Upcoming Lock</div>
                <div class="stop-name">Demopolis Lock</div>
                <div class="stop-meta">Plan staging and timing</div>
              </div>
              <div class="stop-card">
                <div class="stop-step">After That</div>
                <div class="stop-name">Aliceville</div>
                <div class="stop-meta">Good candidate for compact preview rows</div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>

    <!-- Boat & Trip Setup -->
    <section class="panel" style="margin-bottom:16px;">
      <div class="panel-inner">
        <div class="section-head">
          <div>
            <div class="section-title">Boat & Trip Setup</div>
            <div class="section-sub">Important support data should remain accessible but should no longer compete with core route and monitoring value</div>
          </div>
          <span class="pill blue">Support Tools</span>
        </div>

        <div class="setup-grid">
          <div class="setup-card">
            <div class="setup-title">Vessels</div>
            <div class="setup-meta">Manage the boats used for route generation, float plans, and fuel estimates.</div>
            <div class="setup-count">3</div>
            <button class="btn">Manage Vessels</button>
          </div>

          <div class="setup-card">
            <div class="setup-title">Contacts</div>
            <div class="setup-meta">Emergency and trip contacts used for notifications and float plans.</div>
            <div class="setup-count">7</div>
            <button class="btn">Manage Contacts</button>
          </div>

          <div class="setup-card">
            <div class="setup-title">Crew / Passengers</div>
            <div class="setup-meta">Passengers and crew that can be associated with active plans.</div>
            <div class="setup-count">4</div>
            <button class="btn">Manage Crew</button>
          </div>

          <div class="setup-card">
            <div class="setup-title">Waypoints</div>
            <div class="setup-meta">Saved custom waypoints and trip anchors used throughout the platform.</div>
            <div class="setup-count">28</div>
            <button class="btn">Manage Waypoints</button>
          </div>
        </div>
      </div>
    </section>

    <!-- Insights / Nudges -->
    <section class="panel">
      <div class="panel-inner">
        <div class="section-head">
          <div>
            <div class="section-title">Recommended Next Steps</div>
            <div class="section-sub">A lightweight guidance area for missing setup, safety nudges, and product activation</div>
          </div>
          <span class="pill amber">Actionable</span>
        </div>

        <div class="insight-list">
          <div class="insight">
            <div class="insight-main">
              <div class="insight-title">Review and file your float plan</div>
              <div class="insight-meta">The current route is active and monitoring is enabled, but the plan is still in draft state.</div>
            </div>
            <button class="btn btn-primary">Open Float Plan</button>
          </div>

          <div class="insight">
            <div class="insight-main">
              <div class="insight-title">Confirm your next check-in window</div>
              <div class="insight-meta">Monitoring is active. Surface the next expected check-in clearly if the current codebase already supports it.</div>
            </div>
            <button class="btn">Monitoring Settings</button>
          </div>

          <div class="insight">
            <div class="insight-main">
              <div class="insight-title">Weather conditions may tighten later today</div>
              <div class="insight-meta">Use this area for warnings or suggestions only if those signals can be safely derived from current data.</div>
            </div>
            <button class="btn">View Marine Panel</button>
          </div>
        </div>

        <div class="footnote">
          This approved mockup is intended to control layout hierarchy and emphasis. Do not invent unsupported data points or workflows when implementing it.
        </div>
      </div>
    </section>

  </div>
</body>
</html>