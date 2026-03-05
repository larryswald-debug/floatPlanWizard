<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width,initial-scale=1" />
  <title>FPW — Family & Friends (Voyage Stream Mockup)</title>
  <style>
    :root{
      --bg:#f5f7fb;
      --card:#ffffff;
      --ink:#0f172a;
      --muted:#64748b;
      --line:#e6ebf5;
      --accent:#5b7cfa;
      --accent2:#22c55e;
      --warn:#f59e0b;
      --bad:#ef4444;
      --shadow: 0 10px 22px rgba(15,23,42,.06);
      --radius: 18px;
      --radius2: 14px;
      --mono: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, "Liberation Mono", "Courier New", monospace;
      --sans: ui-sans-serif, system-ui, -apple-system, Segoe UI, Roboto, Helvetica, Arial, "Apple Color Emoji", "Segoe UI Emoji";
    }
    *{box-sizing:border-box}
    body{
      margin:0;
      font-family:var(--sans);
      color:var(--ink);
      background: radial-gradient(1200px 500px at 15% -10%, rgba(91,124,250,.12), transparent 60%),
                  radial-gradient(900px 480px at 95% 0%, rgba(34,197,94,.10), transparent 55%),
                  var(--bg);
    }

    /* Top app shell */
    .shell{
      min-height:100vh;
      display:grid;
      grid-template-columns: 280px 1fr;
    }

    /* Sidebar */
    .sidebar{
      background: linear-gradient(180deg, #ffffff, #fbfcff);
      border-right:1px solid var(--line);
      padding: 18px 16px;
      position:sticky;
      top:0;
      height:100vh;
      display:flex;
      flex-direction:column;
      gap:14px;
    }
    .brand{
      display:flex;
      align-items:center;
      gap:10px;
      padding:10px 10px 14px;
    }
    .logo{
      width:38px;height:38px;border-radius:12px;
      background: linear-gradient(135deg, rgba(91,124,250,1), rgba(91,124,250,.55));
      box-shadow: 0 10px 18px rgba(91,124,250,.25);
      position:relative;
    }
    .logo:after{
      content:"";
      position:absolute; inset:10px;
      border-radius:10px;
      border:2px solid rgba(255,255,255,.65);
    }
    .brand h1{
      font-size:14px; margin:0; letter-spacing:.2px;
    }
    .brand small{
      display:block;
      font-size:12px;
      color:var(--muted);
      margin-top:2px;
    }

    .shareCard{
      border:1px solid var(--line);
      border-radius: var(--radius);
      background: var(--card);
      box-shadow: var(--shadow);
      padding:14px;
    }
    .shareRow{
      display:flex; align-items:center; justify-content:space-between; gap:10px;
      margin-bottom:10px;
    }
    .pill{
      font-size:12px;
      padding:6px 10px;
      border-radius:999px;
      background: rgba(34,197,94,.12);
      color:#166534;
      border:1px solid rgba(34,197,94,.20);
      white-space:nowrap;
    }
    .shareMeta{
      font-size:12px;
      color:var(--muted);
      line-height:1.35;
    }
    .shareActions{
      display:flex; gap:8px; margin-top:12px;
    }
    .btn{
      appearance:none;
      border:1px solid var(--line);
      background:#fff;
      color:var(--ink);
      padding:10px 12px;
      border-radius: 12px;
      font-weight:600;
      font-size:13px;
      cursor:pointer;
      transition: transform .08s ease, box-shadow .15s ease, border-color .15s ease;
    }
    .btn:hover{ border-color:#d9e2f2; box-shadow:0 10px 18px rgba(15,23,42,.06); }
    .btn:active{ transform: translateY(1px); }
    .btn.primary{
      background: linear-gradient(135deg, rgba(91,124,250,1), rgba(91,124,250,.82));
      border-color: transparent;
      color:#fff;
      box-shadow: 0 10px 18px rgba(91,124,250,.22);
    }
    .btn.tiny{ padding:8px 10px; font-size:12px; border-radius: 10px; }
    .nav{
      margin-top:6px;
      display:flex;
      flex-direction:column;
      gap:4px;
    }
    .nav a{
      text-decoration:none;
      color:var(--ink);
      font-size:13px;
      padding:10px 12px;
      border-radius: 12px;
      display:flex;
      align-items:center;
      justify-content:space-between;
      border:1px solid transparent;
    }
    .nav a:hover{ background:#f3f6ff; border-color:#e7eeff; }
    .nav a.active{
      background: rgba(91,124,250,.10);
      border-color: rgba(91,124,250,.18);
      color:#1d4ed8;
    }
    .nav .badge{
      font-size:11px;
      color:var(--muted);
      background:#f1f5f9;
      border:1px solid var(--line);
      padding:3px 8px;
      border-radius:999px;
    }

    .sidebarFooter{
      margin-top:auto;
      font-size:12px;
      color:var(--muted);
      padding: 10px 10px 0;
      line-height:1.35;
    }

    /* Main content */
    .main{
      padding: 18px 20px 26px;
    }

    .topbar{
      display:flex;
      align-items:flex-end;
      justify-content:space-between;
      gap:12px;
      margin-bottom:14px;
    }
    .tripTitle h2{
      margin:0;
      font-size:18px;
      letter-spacing:.2px;
    }
    .tripTitle p{
      margin:6px 0 0;
      color:var(--muted);
      font-size:13px;
    }
    .topbarActions{
      display:flex;
      gap:10px;
      align-items:center;
    }
    .segmented{
      display:flex;
      border:1px solid var(--line);
      background:#fff;
      border-radius: 14px;
      overflow:hidden;
      box-shadow: var(--shadow);
    }
    .segmented button{
      border:none;
      background:transparent;
      padding:10px 12px;
      cursor:pointer;
      font-weight:700;
      font-size:12px;
      color:var(--muted);
    }
    .segmented button.active{
      background: rgba(91,124,250,.12);
      color:#1d4ed8;
    }

    /* Status cards row */
    .cardsRow{
      display:grid;
      grid-template-columns: repeat(4, minmax(0,1fr));
      gap:12px;
      margin-bottom:14px;
    }
    .card{
      background: var(--card);
      border:1px solid var(--line);
      border-radius: var(--radius);
      box-shadow: var(--shadow);
      padding: 14px;
      min-height: 92px;
    }
    .card .label{
      color:var(--muted);
      font-size:12px;
      display:flex;
      align-items:center;
      justify-content:space-between;
      gap:10px;
      margin-bottom:10px;
    }
    .card .value{
      font-size:18px;
      font-weight:800;
      letter-spacing:.2px;
      line-height:1.05;
    }
    .card .sub{
      margin-top:8px;
      color:var(--muted);
      font-size:12px;
      line-height:1.25;
    }
    .dot{
      width:10px;height:10px;border-radius:999px;
      display:inline-block;
      background: var(--accent2);
      box-shadow: 0 0 0 4px rgba(34,197,94,.15);
    }
    .dot.warn{ background: var(--warn); box-shadow: 0 0 0 4px rgba(245,158,11,.18); }
    .dot.bad{ background: var(--bad); box-shadow: 0 0 0 4px rgba(239,68,68,.16); }

    /* Layout below cards */
    .grid{
      display:grid;
      grid-template-columns: 1.6fr 1fr;
      gap: 12px;
      align-items:start;
    }
    .mapPanel{
      background: var(--card);
      border:1px solid var(--line);
      border-radius: var(--radius);
      box-shadow: var(--shadow);
      overflow:hidden;
    }
    .panelHeader{
      display:flex;
      align-items:center;
      justify-content:space-between;
      gap:10px;
      padding: 12px 14px;
      border-bottom:1px solid var(--line);
    }
    .panelHeader h3{
      margin:0;
      font-size:14px;
      letter-spacing:.2px;
    }
    .panelHeader .hint{
      color:var(--muted);
      font-size:12px;
    }
    .map{
      height: 380px;
      position:relative;
      background:
        radial-gradient(600px 220px at 30% 40%, rgba(91,124,250,.12), transparent 60%),
        radial-gradient(500px 220px at 70% 55%, rgba(34,197,94,.10), transparent 55%),
        linear-gradient(180deg, #f7fbff, #eef3ff);
    }
    /* Fake map grid + “route” */
    .map:before{
      content:"";
      position:absolute; inset:0;
      background-image:
        linear-gradient(to right, rgba(15,23,42,.05) 1px, transparent 1px),
        linear-gradient(to bottom, rgba(15,23,42,.05) 1px, transparent 1px);
      background-size: 36px 36px;
      opacity:.55;
      pointer-events:none;
    }
    .routeLine{
      position:absolute;
      left: 18%;
      top: 14%;
      width: 58%;
      height: 72%;
      pointer-events:none;
    }
    .routeLine path{
      fill:none;
      stroke: rgba(91,124,250,.9);
      stroke-width: 4;
      stroke-linecap: round;
      stroke-dasharray: 10 10;
      animation: dash 5s linear infinite;
    }
    @keyframes dash{
      to { stroke-dashoffset: -200; }
    }
    .boat{
      position:absolute;
      left: 57%;
      top: 56%;
      width: 14px;
      height: 14px;
      border-radius: 999px;
      background: #0ea5e9;
      box-shadow: 0 0 0 6px rgba(14,165,233,.18), 0 10px 20px rgba(15,23,42,.18);
      transform: translate(-50%, -50%);
    }
    .boat:after{
      content:"🚤";
      position:absolute;
      left: 50%;
      top: 50%;
      transform: translate(-50%, -55%);
      font-size:18px;
      filter: drop-shadow(0 8px 12px rgba(15,23,42,.18));
    }
    .mapOverlay{
      position:absolute;
      left:14px;
      bottom:14px;
      display:flex;
      gap:10px;
      flex-wrap:wrap;
    }
    .miniCard{
      background: rgba(255,255,255,.85);
      border: 1px solid rgba(230,235,245,.95);
      border-radius: 14px;
      padding: 10px 12px;
      backdrop-filter: blur(8px);
      box-shadow: 0 10px 20px rgba(15,23,42,.06);
      min-width: 160px;
    }
    .miniCard .k{
      font-size:11px;
      color: var(--muted);
      margin-bottom:6px;
      display:flex; justify-content:space-between; gap:10px;
    }
    .miniCard .v{
      font-weight:900;
      font-size:14px;
    }

    .belowMapRow{
      display:grid;
      grid-template-columns: repeat(3, minmax(0,1fr));
      gap:12px;
      margin-top:12px;
    }

    .progressBar{
      height: 10px;
      background:#f1f5ff;
      border:1px solid #e7eeff;
      border-radius:999px;
      overflow:hidden;
      margin-top:10px;
      position:relative;
    }
    .progressBar .fill{
      height:100%;
      width: 42%;
      background: linear-gradient(90deg, rgba(91,124,250,1), rgba(91,124,250,.65));
      border-radius:999px;
    }
    .progressBar .marker{
      position:absolute;
      top:50%;
      left:42%;
      transform: translate(-50%,-50%);
      width: 18px; height: 18px;
      border-radius:999px;
      background:#fff;
      border:2px solid rgba(91,124,250,.9);
      box-shadow: 0 10px 18px rgba(15,23,42,.10);
    }

    .thumbs{
      display:flex; gap:10px; margin-top:10px;
    }
    .thumb{
      flex:1;
      height: 64px;
      border-radius: 14px;
      background:
        radial-gradient(120px 50px at 30% 35%, rgba(91,124,250,.22), transparent 60%),
        radial-gradient(120px 50px at 70% 55%, rgba(34,197,94,.16), transparent 60%),
        linear-gradient(180deg, #f7fbff, #eef3ff);
      border:1px solid var(--line);
      box-shadow: 0 10px 18px rgba(15,23,42,.06);
      position:relative;
      overflow:hidden;
    }
    .thumb:after{
      content:"📸";
      position:absolute; right:10px; bottom:8px;
      font-size:16px; opacity:.85;
    }

    /* Stream */
    .streamPanel{
      background: var(--card);
      border:1px solid var(--line);
      border-radius: var(--radius);
      box-shadow: var(--shadow);
      overflow:hidden;
      max-height: calc(100vh - 180px);
      display:flex;
      flex-direction:column;
    }
    .streamHead{
      padding: 12px 14px;
      border-bottom:1px solid var(--line);
      display:flex;
      align-items:center;
      justify-content:space-between;
      gap:10px;
    }
    .streamHead h3{ margin:0; font-size:14px; letter-spacing:.2px; }
    .streamHead .meta{
      font-size:12px; color:var(--muted);
    }
    .composer{
      padding: 12px 14px;
      border-bottom:1px solid var(--line);
      display:flex;
      gap:10px;
      align-items:flex-start;
    }
    .avatar{
      width:36px;height:36px;border-radius:14px;
      background: linear-gradient(135deg, rgba(15,23,42,.10), rgba(15,23,42,.04));
      border:1px solid var(--line);
      display:flex; align-items:center; justify-content:center;
      font-weight:900;
      color:#0f172a;
    }
    .composerBox{
      flex:1;
      display:flex;
      flex-direction:column;
      gap:10px;
    }
    .textarea{
      width:100%;
      min-height: 72px;
      resize:none;
      border-radius: 14px;
      border:1px solid var(--line);
      padding:10px 12px;
      font-size:13px;
      outline:none;
      box-shadow: inset 0 1px 0 rgba(15,23,42,.03);
    }
    .composerActions{
      display:flex;
      justify-content:space-between;
      gap:10px;
      flex-wrap:wrap;
      align-items:center;
    }
    .hintRow{
      display:flex; gap:8px; align-items:center; flex-wrap:wrap;
      color:var(--muted); font-size:12px;
    }
    .chip{
      padding:6px 10px;
      border-radius:999px;
      border:1px solid var(--line);
      background:#fff;
      cursor:pointer;
      font-weight:700;
      font-size:12px;
      color:var(--muted);
    }
    .chip:hover{ border-color:#d9e2f2; }

    .stream{
      overflow:auto;
      padding: 12px 14px 16px;
      display:flex;
      flex-direction:column;
      gap: 12px;
    }
    .pinned{
      border:1px solid rgba(91,124,250,.18);
      background: rgba(91,124,250,.08);
      border-radius: var(--radius);
      padding: 12px 12px 10px;
    }
    .pinnedTop{
      display:flex; align-items:center; justify-content:space-between; gap:10px;
      margin-bottom:10px;
    }
    .pinnedTop strong{ font-size:13px; }
    .pinnedTop span{ font-size:12px; color:var(--muted); }
    .statsGrid{
      display:grid;
      grid-template-columns: repeat(4, minmax(0,1fr));
      gap:10px;
    }
    .stat{
      background: rgba(255,255,255,.75);
      border:1px solid rgba(230,235,245,.9);
      border-radius: 14px;
      padding: 10px;
    }
    .stat .k{ font-size:11px; color:var(--muted); margin-bottom:6px; }
    .stat .v{ font-weight:900; font-size:14px; }

    .post{
      border:1px solid var(--line);
      border-radius: var(--radius);
      background:#fff;
      box-shadow: 0 10px 18px rgba(15,23,42,.05);
      overflow:hidden;
    }
    .postHead{
      padding: 12px 12px 10px;
      display:flex; align-items:flex-start; justify-content:space-between; gap:10px;
    }
    .postTitle{
      display:flex; align-items:center; gap:8px; flex-wrap:wrap;
    }
    .tag{
      font-size:11px;
      font-weight:900;
      letter-spacing:.2px;
      padding:4px 8px;
      border-radius:999px;
      border:1px solid var(--line);
      color:var(--muted);
      background:#fff;
    }
    .tag.fpw{
      color:#1d4ed8;
      border-color: rgba(91,124,250,.22);
      background: rgba(91,124,250,.10);
    }
    .postTime{
      font-size:12px;
      color:var(--muted);
      white-space:nowrap;
    }
    .postBody{
      padding: 0 12px 12px;
      color:#0f172a;
      font-size:13px;
      line-height:1.45;
    }
    .postMedia{
      height: 160px;
      background:
        radial-gradient(260px 120px at 25% 40%, rgba(91,124,250,.25), transparent 60%),
        radial-gradient(260px 120px at 70% 55%, rgba(34,197,94,.16), transparent 60%),
        linear-gradient(180deg, #f7fbff, #eef3ff);
      border-top:1px solid var(--line);
      border-bottom:1px solid var(--line);
      position:relative;
    }
    .postMedia:after{
      content:"Photo";
      position:absolute; left:12px; top:12px;
      font-size:12px; color:var(--muted);
      background: rgba(255,255,255,.7);
      border:1px solid rgba(230,235,245,.9);
      padding:6px 10px;
      border-radius: 999px;
      backdrop-filter: blur(8px);
    }

    .postActions{
      padding: 10px 12px 12px;
      display:flex;
      flex-direction:column;
      gap:10px;
    }
    .reactions{
      display:flex; gap:8px; flex-wrap:wrap; align-items:center;
    }
    .reactBtn{
      border:1px solid var(--line);
      background:#fff;
      border-radius: 999px;
      padding: 7px 10px;
      font-weight:900;
      font-size:12px;
      cursor:pointer;
      color:var(--muted);
      display:flex;
      align-items:center;
      gap:8px;
    }
    .reactBtn.active{
      border-color: rgba(91,124,250,.30);
      background: rgba(91,124,250,.10);
      color:#1d4ed8;
    }
    .reactBtn .count{
      color:var(--muted);
      font-weight:900;
      font-family:var(--mono);
      font-size:12px;
    }
    .commentBox{
      display:flex;
      gap:8px;
      align-items:flex-start;
    }
    .commentInput{
      flex:1;
      border:1px solid var(--line);
      border-radius: 14px;
      padding: 9px 10px;
      font-size:13px;
      outline:none;
    }
    .comments{
      display:flex;
      flex-direction:column;
      gap:8px;
      margin-top:4px;
    }
    .comment{
      border:1px solid var(--line);
      border-radius: 14px;
      padding: 8px 10px;
      background:#fff;
    }
    .comment .who{
      font-weight:900;
      font-size:12px;
      margin-bottom:4px;
    }
    .comment .txt{
      font-size:12px;
      color:#0f172a;
      line-height:1.35;
    }

    /* Responsive */
    @media (max-width: 1160px){
      .cardsRow{ grid-template-columns: repeat(2, minmax(0,1fr)); }
      .grid{ grid-template-columns: 1fr; }
      .streamPanel{ max-height: none; }
      .shell{ grid-template-columns: 1fr; }
      .sidebar{ position:relative; height:auto; }
    }
  </style>
</head>
<body>
  <div class="shell">
    <!-- Sidebar -->
    <aside class="sidebar">
      <div class="brand">
        <div class="logo"></div>
        <div>
          <h1>FloatPlanWizard</h1>
          <small>Family & Friends</small>
        </div>
      </div>

      <div class="shareCard">
        <div class="shareRow">
          <div style="font-weight:900;font-size:13px;">Wald Great Loop 2026</div>
          <span class="pill">🟢 On Schedule</span>
        </div>
        <div class="shareMeta">
          Share link: <span style="font-family:var(--mono);">/follow/wald-loop-2026</span><br/>
          Last check-in: <b>2:18 PM</b> • Viewers: <b>12</b>
        </div>
        <div class="shareActions">
          <button class="btn primary" type="button">Copy Link</button>
          <button class="btn" type="button">Privacy</button>
        </div>
      </div>

      <nav class="nav" aria-label="Sections">
        <a class="active" href="#" onclick="return false;">Overview <span class="badge">Live</span></a>
        <a href="#" onclick="return false;">Map <span class="badge">Route</span></a>
        <a href="#" onclick="return false;">Stream <span class="badge">Posts</span></a>
        <a href="#" onclick="return false;">Photos <span class="badge">3</span></a>
        <a href="#" onclick="return false;">Kids Zone <span class="badge">Badges</span></a>
        <a href="#" onclick="return false;">Trip Stats <span class="badge">Milestones</span></a>
        <a href="#" onclick="return false;">Messages <span class="badge">2</span></a>
      </nav>

      <div class="sidebarFooter">
        <b>Tip:</b> Keep it simple for non-boaters. This page translates your
        check-ins, ETA, weather, and events into a reassuring story.
      </div>
    </aside>

    <!-- Main -->
    <main class="main">
      <div class="topbar">
        <div class="tripTitle">
          <h2>Wald Great Loop Expedition</h2>
          <p>Follow along in real time — location, safety status, photos, and the voyage stream.</p>
        </div>

        <div class="topbarActions">
          <div class="segmented" role="tablist" aria-label="Viewer mode">
            <button class="active" type="button">Family</button>
            <button type="button">Expedition</button>
            <button type="button">Kid Mode</button>
          </div>
          <button class="btn" type="button">Notify Me</button>
        </div>
      </div>

      <!-- Status cards -->
      <section class="cardsRow">
        <div class="card">
          <div class="label">
            <span>Status</span>
            <span class="dot"></span>
          </div>
          <div class="value">All Good</div>
          <div class="sub">Last check-in: Today 2:18 PM</div>
        </div>

        <div class="card">
          <div class="label">
            <span>Current Location</span>
            <span style="color:var(--muted);font-size:12px;">📍</span>
          </div>
          <div class="value">Savannah, GA</div>
          <div class="sub">Heading: Charleston, SC</div>
        </div>

        <div class="card">
          <div class="label">
            <span>ETA</span>
            <span style="color:var(--muted);font-size:12px;">⏱</span>
          </div>
          <div class="value">~2 days</div>
          <div class="sub">Today: 42 nm planned • 18 nm complete</div>
        </div>

        <div class="card">
          <div class="label">
            <span>Conditions</span>
            <span style="color:var(--muted);font-size:12px;">🌤</span>
          </div>
          <div class="value">Safe</div>
          <div class="sub">Moderate breeze • Smooth water expected</div>
        </div>
      </section>

      <section class="grid">
        <!-- Map + details -->
        <div>
          <div class="mapPanel">
            <div class="panelHeader">
              <div>
                <h3>Map Overview</h3>
                <div class="hint">Simple, non-boater map view • Route line + current marker</div>
              </div>
              <button class="btn tiny" type="button">Open Full Map</button>
            </div>

            <div class="map">
              <svg class="routeLine" viewBox="0 0 100 100" preserveAspectRatio="none" aria-hidden="true">
                <path d="M18 18 C 35 35, 42 12, 55 26 S 72 45, 78 60 S 62 74, 55 86 S 35 78, 30 65 S 20 48, 22 34" />
              </svg>
              <div class="boat" title="Current position"></div>

              <div class="mapOverlay">
                <div class="miniCard">
                  <div class="k"><span>Today’s Leg</span><span>🚤</span></div>
                  <div class="v">Savannah → Charleston</div>
                </div>
                <div class="miniCard">
                  <div class="k"><span>Progress</span><span>📈</span></div>
                  <div class="v">18 / 42 nm</div>
                </div>
                <div class="miniCard">
                  <div class="k"><span>Next Check-In</span><span>✅</span></div>
                  <div class="v">5:30 PM</div>
                </div>
              </div>
            </div>
          </div>

          <div class="belowMapRow">
            <div class="card">
              <div class="label"><span>Today’s Progress</span><span>📍</span></div>
              <div class="value">3.2 hrs</div>
              <div class="sub">Underway • 1 lock today • Smooth ride</div>
              <div class="progressBar" aria-label="Progress bar">
                <div class="fill"></div>
                <div class="marker" title="Current progress"></div>
              </div>
            </div>

            <div class="card">
              <div class="label"><span>Latest Photos</span><span>📸</span></div>
              <div class="value">3 new</div>
              <div class="sub">Tap to view the photo journal</div>
              <div class="thumbs">
                <div class="thumb" title="Photo 1"></div>
                <div class="thumb" title="Photo 2"></div>
                <div class="thumb" title="Photo 3"></div>
              </div>
            </div>

            <div class="card">
              <div class="label"><span>Trip Summary</span><span>📊</span></div>
              <div class="value">1,842 mi</div>
              <div class="sub">47 days • 9 locks • 5 states</div>
              <div style="margin-top:10px;color:var(--muted);font-size:12px;font-family:var(--mono);">
                Confidence: 0.82 • On-time: 92%
              </div>
            </div>
          </div>
        </div>

        <!-- Stream -->
        <aside class="streamPanel">
          <div class="streamHead">
            <div>
              <h3>Voyage Stream</h3>
              <div class="meta">Updates, photos, reactions, and comments</div>
            </div>
            <button class="btn tiny primary" type="button">Follow</button>
          </div>

          <div class="composer">
            <div class="avatar" title="You">LW</div>
            <div class="composerBox">
              <textarea class="textarea" id="composerText" placeholder="Post a quick update for family & friends (text + optional photo)…"></textarea>
              <div class="composerActions">
                <div class="hintRow">
                  <button class="chip" type="button" onclick="mockAttachPhoto()">📎 Add photo</button>
                  <button class="chip" type="button" onclick="insertTemplate('All good ✅')">All good ✅</button>
                  <button class="chip" type="button" onclick="insertTemplate('Delayed by weather 🌬')">Weather delay 🌬</button>
                  <button class="chip" type="button" onclick="insertTemplate('Docked safely ⚓')">Docked ⚓</button>
                </div>
                <button class="btn primary" type="button" onclick="mockPost()">Post</button>
              </div>
              <div id="attachState" style="display:none;color:var(--muted);font-size:12px;">
                Attached: <b>photo.jpg</b> (mock)
              </div>
            </div>
          </div>

          <div class="stream" id="stream">
            <!-- Pinned -->
            <div class="pinned">
              <div class="pinnedTop">
                <strong>Pinned: Today at a glance</strong>
                <span>Updated 2 minutes ago</span>
              </div>
              <div class="statsGrid">
                <div class="stat">
                  <div class="k">Miles Traveled</div>
                  <div class="v">1,842</div>
                </div>
                <div class="stat">
                  <div class="k">Days Underway</div>
                  <div class="v">47</div>
                </div>
                <div class="stat">
                  <div class="k">Locks Completed</div>
                  <div class="v">9</div>
                </div>
                <div class="stat">
                  <div class="k">Wildlife</div>
                  <div class="v">14</div>
                </div>
              </div>
            </div>

            <!-- Post 1 (system) -->
            <article class="post" data-post-id="101">
              <div class="postHead">
                <div class="postTitle">
                  <span class="tag fpw">FPW</span>
                  <b>✅ Checked in — All Good</b>
                </div>
                <div class="postTime">2:18 PM</div>
              </div>
              <div class="postBody">
                The crew checked in from <b>Savannah, GA</b>. Everything looks good and on schedule.
              </div>
              <div class="postActions">
                <div class="reactions">
                  <button class="reactBtn" onclick="toggleReact(101,'like')">👍 <span class="count" id="r101-like">12</span></button>
                  <button class="reactBtn" onclick="toggleReact(101,'love')">❤️ <span class="count" id="r101-love">9</span></button>
                  <button class="reactBtn" onclick="toggleReact(101,'boat')">🚤 <span class="count" id="r101-boat">4</span></button>
                  <button class="reactBtn" onclick="toggleReact(101,'wave')">🌊 <span class="count" id="r101-wave">2</span></button>
                </div>

                <div class="commentBox">
                  <input class="commentInput" id="c101" placeholder="Add a comment (max 500 chars)…" maxlength="500" />
                  <button class="btn tiny" onclick="addComment(101)">Comment</button>
                </div>

                <div class="comments" id="comments-101">
                  <div class="comment">
                    <div class="who">Abbe</div>
                    <div class="txt">So glad to see the check-in. Love you guys ❤️</div>
                  </div>
                  <div class="comment">
                    <div class="who">Callie Fan Club</div>
                    <div class="txt">Tell Callie we said hi!! 🐶</div>
                  </div>
                </div>
              </div>
            </article>

            <!-- Post 2 (system lock) -->
            <article class="post" data-post-id="102">
              <div class="postHead">
                <div class="postTitle">
                  <span class="tag fpw">FPW</span>
                  <b>🔒 Lock completed — #4</b>
                </div>
                <div class="postTime">11:02 AM</div>
              </div>
              <div class="postBody">
                Passed safely through a lock today. Locks can look intense, but this is a routine part of the route.
              </div>
              <div class="postActions">
                <div class="reactions">
                  <button class="reactBtn" onclick="toggleReact(102,'like')">👍 <span class="count" id="r102-like">7</span></button>
                  <button class="reactBtn" onclick="toggleReact(102,'love')">❤️ <span class="count" id="r102-love">3</span></button>
                  <button class="reactBtn" onclick="toggleReact(102,'boat')">🚤 <span class="count" id="r102-boat">6</span></button>
                  <button class="reactBtn" onclick="toggleReact(102,'wave')">🌊 <span class="count" id="r102-wave">1</span></button>
                </div>

                <div class="commentBox">
                  <input class="commentInput" id="c102" placeholder="Add a comment…" maxlength="500" />
                  <button class="btn tiny" onclick="addComment(102)">Comment</button>
                </div>

                <div class="comments" id="comments-102">
                  <div class="comment">
                    <div class="who">Grandkid #1</div>
                    <div class="txt">Locks are like water elevators!! 😲</div>
                  </div>
                </div>
              </div>
            </article>

            <!-- Post 3 (manual + photo) -->
            <article class="post" data-post-id="103">
              <div class="postHead">
                <div class="postTitle">
                  <span class="tag">Captain</span>
                  <b>🐬 Dolphins followed us!</b>
                </div>
                <div class="postTime">9:41 AM</div>
              </div>
              <div class="postMedia" aria-label="Photo placeholder"></div>
              <div class="postBody">
                Morning was glassy calm. We had dolphins alongside for about 20 minutes — everyone grinning.
              </div>
              <div class="postActions">
                <div class="reactions">
                  <button class="reactBtn" onclick="toggleReact(103,'like')">👍 <span class="count" id="r103-like">21</span></button>
                  <button class="reactBtn" onclick="toggleReact(103,'love')">❤️ <span class="count" id="r103-love">18</span></button>
                  <button class="reactBtn" onclick="toggleReact(103,'boat')">🚤 <span class="count" id="r103-boat">5</span></button>
                  <button class="reactBtn" onclick="toggleReact(103,'wave')">🌊 <span class="count" id="r103-wave">7</span></button>
                </div>

                <div class="commentBox">
                  <input class="commentInput" id="c103" placeholder="Add a comment…" maxlength="500" />
                  <button class="btn tiny" onclick="addComment(103)">Comment</button>
                </div>

                <div class="comments" id="comments-103">
                  <div class="comment">
                    <div class="who">Friend</div>
                    <div class="txt">This is the coolest. Can’t wait to see more pics!</div>
                  </div>
                  <div class="comment">
                    <div class="who">Grandkid #2</div>
                    <div class="txt">I want a dolphin badge 🐬🏆</div>
                  </div>
                </div>
              </div>
            </article>

          </div>
        </aside>
      </section>
    </main>
  </div>

  <script>
    // Mock behavior only (for the visual prototype)
    const reacted = new Set(); // key: postId|emoji
    let attachedPhoto = false;

    function key(postId, emoji){ return postId + "|" + emoji; }

    function toggleReact(postId, emoji){
      const k = key(postId, emoji);
      const countEl = document.getElementById(`r${postId}-${emoji}`);
      if(!countEl) return;

      // Find the button to toggle style
      const post = document.querySelector(`[data-post-id="${postId}"]`);
      const btn = [...post.querySelectorAll(".reactBtn")].find(b => b.textContent.includes(emojiToSymbol(emoji)));

      let count = parseInt(countEl.textContent || "0", 10);

      if(reacted.has(k)){
        reacted.delete(k);
        countEl.textContent = Math.max(0, count - 1);
        if(btn) btn.classList.remove("active");
      }else{
        reacted.add(k);
        countEl.textContent = count + 1;
        if(btn) btn.classList.add("active");
      }
    }

    function emojiToSymbol(emoji){
      return ({like:"👍", love:"❤️", boat:"🚤", wave:"🌊"})[emoji] || "";
    }

    function addComment(postId){
      const input = document.getElementById(`c${postId}`);
      const text = (input?.value || "").trim();
      if(!text) return;

      const container = document.getElementById(`comments-${postId}`);
      const wrap = document.createElement("div");
      wrap.className = "comment";
      wrap.innerHTML = `<div class="who">You</div><div class="txt"></div>`;
      wrap.querySelector(".txt").textContent = text;
      container.appendChild(wrap);

      input.value = "";
      container.scrollIntoView({behavior:"smooth", block:"nearest"});
    }

    function insertTemplate(txt){
      const ta = document.getElementById("composerText");
      ta.value = (ta.value ? (ta.value + "\n") : "") + txt;
      ta.focus();
    }

    function mockAttachPhoto(){
      attachedPhoto = true;
      document.getElementById("attachState").style.display = "block";
    }

    function mockPost(){
      const ta = document.getElementById("composerText");
      const text = (ta.value || "").trim();
      if(!text && !attachedPhoto) return;

      const stream = document.getElementById("stream");
      const postId = Math.floor(Math.random() * 9000) + 200;

      const now = new Date();
      const time = now.toLocaleTimeString([], {hour:"numeric", minute:"2-digit"});

      const article = document.createElement("article");
      article.className = "post";
      article.setAttribute("data-post-id", String(postId));

      const head = `
        <div class="postHead">
          <div class="postTitle">
            <span class="tag">Captain</span>
            <b>${escapeHtml(text.split("\n")[0]).slice(0, 80)}</b>
          </div>
          <div class="postTime">${time}</div>
        </div>
      `;

      const media = attachedPhoto ? `<div class="postMedia" aria-label="Photo placeholder"></div>` : ``;
      const body = `
        <div class="postBody">${escapeHtml(text)}</div>
        <div class="postActions">
          <div class="reactions">
            <button class="reactBtn" onclick="toggleReact(${postId},'like')">👍 <span class="count" id="r${postId}-like">0</span></button>
            <button class="reactBtn" onclick="toggleReact(${postId},'love')">❤️ <span class="count" id="r${postId}-love">0</span></button>
            <button class="reactBtn" onclick="toggleReact(${postId},'boat')">🚤 <span class="count" id="r${postId}-boat">0</span></button>
            <button class="reactBtn" onclick="toggleReact(${postId},'wave')">🌊 <span class="count" id="r${postId}-wave">0</span></button>
          </div>

          <div class="commentBox">
            <input class="commentInput" id="c${postId}" placeholder="Add a comment…" maxlength="500" />
            <button class="btn tiny" onclick="addComment(${postId})">Comment</button>
          </div>

          <div class="comments" id="comments-${postId}">
            <div class="comment">
              <div class="who">FPW Tip</div>
              <div class="txt">This is a mock post composer. In FPW, this will create a voyage_posts row + optional media.</div>
            </div>
          </div>
        </div>
      `;

      article.innerHTML = head + media + body;
      // insert after pinned card (index 1 in stream children)
      const pinned = stream.querySelector(".pinned");
      pinned.insertAdjacentElement("afterend", article);

      // reset
      ta.value = "";
      attachedPhoto = false;
      document.getElementById("attachState").style.display = "none";
      article.scrollIntoView({behavior:"smooth", block:"start"});
    }

    function escapeHtml(str){
      return String(str)
        .replaceAll("&","&amp;")
        .replaceAll("<","&lt;")
        .replaceAll(">","&gt;")
        .replaceAll('"',"&quot;")
        .replaceAll("'","&#039;")
        .replaceAll("\n","<br/>");
    }
  </script>
</body>
</html>