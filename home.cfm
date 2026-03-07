<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>FloatPlanWizard — Route Builder + Follower Pages for Great Loopers</title>
  <meta name="description" content="Plan your route, share a follower page, and keep your crew/family in the loop. Great Loop templates included." />

  <style>
    :root{
      --bg0:#06111d;
      --bg1:#071a2c;
      --panel:#0b1a2a;
      --panel2:#0b2034;
      --line:rgba(255,255,255,.08);
      --line2:rgba(255,255,255,.12);
      --text:rgba(255,255,255,.90);
      --muted:rgba(255,255,255,.64);
      --muted2:rgba(255,255,255,.50);
      --accent:#35d0c8;
      --accent2:#4aa3ff;
      --good:#33d6a6;
      --warn:#f7c948;
      --bad:#ff6b6b;
      --shadow: 0 20px 60px rgba(0,0,0,.40);
      --shadow2: 0 12px 30px rgba(0,0,0,.35);
      --radius:18px;
      --radius2:14px;
      --font: ui-sans-serif, system-ui, -apple-system, Segoe UI, Roboto, Helvetica, Arial, "Apple Color Emoji","Segoe UI Emoji";
    }

    *{ box-sizing:border-box; }
    html,body{ height:100%; }
    body{
      margin:0;
      font-family:var(--font);
      background:
        radial-gradient(900px 500px at 10% 0%, rgba(53,208,200,.12), transparent 55%),
        radial-gradient(900px 520px at 90% 12%, rgba(74,163,255,.10), transparent 60%),
        radial-gradient(1000px 600px at 50% 120%, rgba(53,208,200,.06), transparent 60%),
        linear-gradient(180deg, var(--bg0), var(--bg1));
      color:var(--text);
      overflow-x:hidden;
    }

    a{ color:inherit; }
    .container{ max-width:1200px; margin:0 auto; padding:0 18px; }

    /* Top nav */
    .topbar{
      position:sticky;
      top:0;
      z-index:50;
      background:
        radial-gradient(1200px 90px at 10% 0%, rgba(53,208,200,.14), transparent 55%),
        radial-gradient(900px 110px at 85% 10%, rgba(74,163,255,.12), transparent 60%),
        linear-gradient(180deg, rgba(6,17,29,.92), rgba(7,26,44,.88));
      backdrop-filter: blur(10px);
      border-bottom:1px solid var(--line);
    }

    .topbar .inner{
      display:flex; align-items:center; gap:16px;
      padding:12px 0;
    }

    .brand{
      display:flex; align-items:center; gap:10px;
      text-decoration:none; min-width:260px;
    }
    .logo{
      width:34px; height:34px; border-radius:10px;
      background:
        radial-gradient(circle at 30% 20%, rgba(255,255,255,.35), transparent 40%),
        linear-gradient(135deg, rgba(53,208,200,.95), rgba(74,163,255,.75));
      box-shadow: 0 8px 18px rgba(0,0,0,.25);
      flex:0 0 auto;
    }
    .brandTitle{ font-weight:900; letter-spacing:.2px; line-height:1.05; }
    .brandTag{ font-size:.92rem; color:var(--muted); margin-top:2px; line-height:1.15; }

    .navLinks{
      display:flex; align-items:center; gap:16px; flex-wrap:wrap;
      margin-left:auto;
    }
    .navLinks a{
      text-decoration:none;
      color:var(--muted);
      font-weight:800;
      padding:8px 10px;
      border-radius:12px;
      border:1px solid transparent;
    }
    .navLinks a:hover{
      color:var(--text);
      background:rgba(255,255,255,.05);
      border-color:rgba(255,255,255,.06);
    }

    .actions{
      display:flex; align-items:center; gap:10px;
      margin-left:12px;
    }
    .btn{
      border-radius:999px;
      padding:10px 14px;
      font-weight:900;
      font-size:.95rem;
      border:1px solid var(--line2);
      background: rgba(255,255,255,.04);
      color:var(--text);
      text-decoration:none;
      display:inline-flex; align-items:center; gap:8px;
      cursor:pointer;
      user-select:none;
      white-space:nowrap;
    }
    .btn:hover{ background: rgba(255,255,255,.07); }
    .btnPrimary{
      border-color: rgba(53,208,200,.35);
      background: linear-gradient(135deg, rgba(53,208,200,.95), rgba(74,163,255,.75));
      color:#021018;
      box-shadow: 0 18px 40px rgba(53,208,200,.10);
    }
    .btnGhost{
      background: rgba(255,255,255,.02);
      border-color: rgba(255,255,255,.10);
      color: rgba(255,255,255,.82);
    }

    .pill{
      font-size:.82rem;
      font-weight:900;
      color: rgba(255,255,255,.78);
      border:1px solid rgba(255,255,255,.10);
      background: rgba(255,255,255,.04);
      padding:6px 10px;
      border-radius:999px;
      display:inline-flex;
      align-items:center;
      gap:8px;
      white-space:nowrap;
    }
    .dot{ width:8px; height:8px; border-radius:999px; background: var(--good); box-shadow:0 0 0 3px rgba(51,214,166,.12); }

    /* Glass panels */
    .glass{
      background:
        radial-gradient(900px 300px at 15% 0%, rgba(53,208,200,.10), transparent 60%),
        radial-gradient(900px 360px at 90% 10%, rgba(74,163,255,.08), transparent 65%),
        linear-gradient(180deg, rgba(255,255,255,.06), rgba(255,255,255,.02));
      border:1px solid rgba(255,255,255,.10);
      border-radius: var(--radius);
      box-shadow: var(--shadow2);
      overflow:hidden;
    }

    /* Hero */
    .hero{ padding:46px 0 10px; }
    .heroGrid{
      display:grid;
      grid-template-columns: 1.12fr .88fr;
      gap:22px;
      align-items:stretch;
    }
    h1{
      margin:0;
      font-size: clamp(2.2rem, 4.2vw, 3.8rem);
      line-height:1.03;
      letter-spacing:-.02em;
    }
    .lead{
      margin:14px 0 0;
      color:var(--muted);
      font-weight:750;
      font-size:1.06rem;
      max-width: 58ch;
      line-height:1.45;
    }
    .heroCtas{
      display:flex;
      gap:12px;
      flex-wrap:wrap;
      margin-top:18px;
      align-items:center;
    }
    .micro{
      margin-top:12px;
      display:flex; gap:10px; flex-wrap:wrap; align-items:center;
      color: var(--muted2);
      font-weight:850;
      font-size:.92rem;
    }
    .micro .tag{
      padding:6px 10px;
      border-radius:999px;
      border:1px solid rgba(255,255,255,.08);
      background: rgba(255,255,255,.03);
    }

    /* Right hero mock */
    .mock{
      position:relative;
      padding:16px;
      min-height: 410px;
    }
    .mockTop{
      display:flex; justify-content:space-between; align-items:center;
      margin-bottom:12px;
      gap:10px;
    }
    .mockTitle{
      font-weight:950;
      letter-spacing:.2px;
      color: rgba(255,255,255,.86);
      display:flex;
      gap:10px;
      align-items:center;
    }
    .mockTitle .miniLogo{
      width:26px; height:26px; border-radius:10px;
      background: linear-gradient(135deg, rgba(53,208,200,.95), rgba(74,163,255,.75));
      opacity:.9;
    }
    .mockChipRow{ display:flex; gap:8px; flex-wrap:wrap; justify-content:flex-end; }
    .chip{
      padding:7px 10px;
      border-radius:999px;
      border:1px solid rgba(255,255,255,.10);
      background: rgba(255,255,255,.04);
      color: rgba(255,255,255,.78);
      font-weight:900;
      font-size:.86rem;
      white-space:nowrap;
    }
    .chipGood{
      border-color: rgba(51,214,166,.25);
      background: rgba(51,214,166,.10);
      color: rgba(255,255,255,.90);
    }
    .chipLoop{
      border-color: rgba(74,163,255,.22);
      background: rgba(74,163,255,.10);
      color: rgba(255,255,255,.90);
    }

    .mockCard{
      margin-top:12px;
      border-radius: var(--radius2);
      border:1px solid rgba(255,255,255,.10);
      background: rgba(0,0,0,.16);
      padding:12px;
      position:relative;
      overflow:hidden;
    }
    .mockCard h4{
      margin:0;
      font-size:.92rem;
      color: rgba(255,255,255,.78);
      font-weight:950;
      letter-spacing:.2px;
      display:flex;
      align-items:center;
      justify-content:space-between;
      gap:10px;
    }
    .mockCard .big{
      margin-top:10px;
      font-size:1.55rem;
      font-weight:1000;
      letter-spacing:-.02em;
    }
    .mockCard .sub{
      margin-top:6px;
      color: var(--muted2);
      font-weight:850;
      font-size:.88rem;
      line-height:1.35;
    }
    .miniBtn{
      padding:7px 10px;
      border-radius:999px;
      border:1px solid rgba(255,255,255,.10);
      background: rgba(255,255,255,.04);
      color: rgba(255,255,255,.82);
      font-weight:950;
      font-size:.84rem;
      text-decoration:none;
      white-space:nowrap;
    }
    .miniBtn:hover{ background: rgba(255,255,255,.07); }

    .routeList{
      margin-top:10px;
      display:grid;
      gap:10px;
    }
    .leg{
      border-radius: 14px;
      border:1px solid rgba(255,255,255,.10);
      background: rgba(0,0,0,.12);
      padding:10px;
      display:flex;
      align-items:flex-start;
      gap:10px;
    }
    .legDot{
      width:10px; height:10px; border-radius:999px;
      background: rgba(53,208,200,.95);
      margin-top:5px;
      box-shadow: 0 0 0 4px rgba(53,208,200,.10);
      flex:0 0 auto;
    }
    .legTitle{
      font-weight:950;
      color: rgba(255,255,255,.86);
      line-height:1.2;
    }
    .legMeta{
      margin-top:5px;
      color: var(--muted2);
      font-weight:850;
      font-size:.88rem;
      line-height:1.25;
    }

    /* Social proof strip */
    .proof{
      margin-top:16px;
      display:flex;
      gap:12px;
      flex-wrap:wrap;
      align-items:center;
      color: var(--muted2);
      font-weight:900;
      font-size:.92rem;
    }
    .proof .badge{
      border:1px solid rgba(255,255,255,.09);
      background: rgba(255,255,255,.03);
      padding:8px 12px;
      border-radius:999px;
      display:flex; align-items:center; gap:8px;
      white-space:nowrap;
    }
    .badge b{ color: rgba(255,255,255,.86); }

    /* Sections */
    section{ padding: 34px 0; }
    .sectionTitle{
      font-size: clamp(1.6rem, 2.4vw, 2.3rem);
      margin:0;
      letter-spacing:-.015em;
    }
    .sectionLead{
      margin-top:10px;
      color: var(--muted);
      font-weight:750;
      max-width: 78ch;
      line-height:1.45;
    }

    .grid3{
      margin-top:18px;
      display:grid;
      grid-template-columns: repeat(3, 1fr);
      gap:14px;
    }

    .feature{
      padding:14px;
      position:relative;
      min-height: 170px;
    }
    .kicker{
      display:flex; align-items:center; gap:10px;
      font-weight:950;
      letter-spacing:.2px;
    }
    .icon{
      width:34px; height:34px; border-radius:12px;
      border:1px solid rgba(255,255,255,.10);
      background: rgba(255,255,255,.04);
      display:flex; align-items:center; justify-content:center;
      box-shadow: 0 10px 22px rgba(0,0,0,.20);
    }
    .feature p{
      margin:10px 0 0;
      color: var(--muted);
      font-weight:750;
      line-height:1.4;
    }
    .feature ul{
      margin:10px 0 0;
      padding-left:18px;
      color: rgba(255,255,255,.72);
      font-weight:750;
      line-height:1.45;
    }
    .feature li{ margin:6px 0; }

    /* Great Loop callout */
    .loopPanel{
      margin-top:16px;
      padding:16px;
      display:grid;
      grid-template-columns: 1.1fr .9fr;
      gap:14px;
      align-items:center;
    }
    .loopPanel h3{
      margin:0;
      font-size:1.22rem;
      letter-spacing:-.01em;
    }
    .loopPanel p{
      margin:8px 0 0;
      color: var(--muted);
      font-weight:750;
      line-height:1.45;
    }
    .loopStats{
      display:flex;
      flex-wrap:wrap;
      gap:10px;
      justify-content:flex-end;
    }
    .stat{
      min-width: 160px;
      padding:12px 12px;
      border-radius: var(--radius2);
      border:1px solid rgba(255,255,255,.10);
      background: rgba(0,0,0,.14);
    }
    .stat .label{
      color: rgba(255,255,255,.72);
      font-weight:900;
      font-size:.88rem;
      display:flex;
      align-items:center;
      gap:8px;
    }
    .stat .value{
      margin-top:6px;
      font-weight:1000;
      letter-spacing:-.01em;
      font-size:1.12rem;
    }
    .stat .note{
      margin-top:4px;
      color: var(--muted2);
      font-weight:800;
      font-size:.86rem;
      line-height:1.25;
    }

    /* Comparison */
    .compare{
      margin-top:18px;
      display:grid;
      grid-template-columns: 1fr 1fr;
      gap:14px;
    }
    .compareCard{
      padding:16px;
      border-radius: var(--radius);
      border:1px solid rgba(255,255,255,.10);
      background: rgba(0,0,0,.12);
    }
    .compareCard h4{
      margin:0;
      font-size:1.05rem;
      letter-spacing:-.01em;
    }
    .compareCard p{
      margin:10px 0 0;
      color: var(--muted);
      font-weight:750;
      line-height:1.45;
    }
    .compareCard ul{
      margin:12px 0 0;
      padding-left:18px;
      color: rgba(255,255,255,.76);
      font-weight:750;
      line-height:1.5;
    }
    .compareCard li{ margin:6px 0; }

    /* CTA band */
    .ctaBand{
      padding:16px;
      display:flex;
      align-items:center;
      justify-content:space-between;
      gap:14px;
      flex-wrap:wrap;
    }
    .ctaBand h3{
      margin:0;
      font-size:1.2rem;
      letter-spacing:-.01em;
    }
    .ctaBand p{
      margin:8px 0 0;
      color: var(--muted);
      font-weight:750;
      line-height:1.4;
      max-width: 70ch;
    }
    .ctaBand .right{
      display:flex;
      gap:10px;
      align-items:center;
      flex-wrap:wrap;
    }

    /* FAQ */
    .faq{
      margin-top:18px;
      display:grid;
      grid-template-columns: 1fr 1fr;
      gap:14px;
    }
    details{
      border:1px solid rgba(255,255,255,.10);
      background: rgba(0,0,0,.14);
      border-radius: var(--radius2);
      padding:12px 12px;
    }
    summary{
      cursor:pointer;
      font-weight:950;
      color: rgba(255,255,255,.86);
      list-style:none;
    }
    summary::-webkit-details-marker{ display:none; }
    details p{
      margin:10px 0 0;
      color: var(--muted);
      font-weight:750;
      line-height:1.45;
    }

    /* Footer */
    footer{
      padding:30px 0 36px;
      border-top:1px solid rgba(255,255,255,.06);
      color: var(--muted2);
    }
    .footGrid{
      display:grid;
      grid-template-columns: 1.4fr 1fr 1fr;
      gap:14px;
      align-items:start;
    }
    .footLinks a{
      display:block;
      text-decoration:none;
      color: rgba(255,255,255,.72);
      font-weight:850;
      padding:6px 0;
    }
    .footLinks a:hover{ color: rgba(255,255,255,.92); }
    .small{ font-size:.92rem; line-height:1.5; color: var(--muted2); font-weight:750; }

    /* Modal */
    .modalOverlay{
      position:fixed; inset:0;
      background: rgba(0,0,0,.55);
      display:none;
      align-items:center; justify-content:center;
      padding:18px;
      z-index:100;
    }
    .modalOverlay.open{ display:flex; }
    .modal{
      width:min(760px, 100%);
      border-radius: 22px;
      border:1px solid rgba(255,255,255,.12);
      background:
        radial-gradient(900px 260px at 15% 0%, rgba(53,208,200,.12), transparent 60%),
        radial-gradient(900px 300px at 90% 10%, rgba(74,163,255,.10), transparent 65%),
        linear-gradient(180deg, rgba(11,26,42,.96), rgba(7,18,30,.92));
      box-shadow: var(--shadow);
      padding:16px;
      position:relative;
    }
    .modalHead{
      display:flex; align-items:flex-start; justify-content:space-between; gap:12px;
    }
    .modal h3{ margin:0; letter-spacing:-.01em; }
    .closeBtn{
      width:38px; height:38px;
      border-radius:12px;
      border:1px solid rgba(255,255,255,.12);
      background: rgba(255,255,255,.04);
      color: rgba(255,255,255,.90);
      cursor:pointer;
      font-weight:1000;
    }
    .closeBtn:hover{ background: rgba(255,255,255,.07); }
    .modal p{ margin:10px 0 0; color: var(--muted); font-weight:750; line-height:1.45; }
    .formRow{
      margin-top:14px;
      display:flex; gap:10px; flex-wrap:wrap;
      align-items:center;
    }
    .input{
      flex: 1 1 260px;
      min-width: 220px;
      background: rgba(255,255,255,.06);
      border:1px solid rgba(255,255,255,.12);
      color: rgba(255,255,255,.90);
      border-radius: 14px;
      padding:12px 12px;
      outline:none;
      font-weight:800;
    }
    .input::placeholder{ color: rgba(255,255,255,.45); }
    .toast{
      position:fixed;
      left:50%; transform:translateX(-50%);
      bottom:18px;
      background: rgba(11,26,42,.92);
      border:1px solid rgba(255,255,255,.12);
      border-radius:999px;
      padding:10px 14px;
      color: rgba(255,255,255,.88);
      font-weight:900;
      box-shadow: var(--shadow2);
      display:none;
      z-index:150;
    }
    .toast.show{ display:block; }

    /* Responsive */
    @media (max-width: 980px){
      .brandTag{ display:none; }
      .navLinks{ display:none; }
      .heroGrid{ grid-template-columns: 1fr; }
      .grid3{ grid-template-columns: 1fr; }
      .loopPanel{ grid-template-columns: 1fr; }
      .loopStats{ justify-content:flex-start; }
      .compare{ grid-template-columns: 1fr; }
      .faq{ grid-template-columns: 1fr; }
      .footGrid{ grid-template-columns: 1fr; }
      .mock{ min-height: unset; }
    }

    /* Float Plan Monitoring Highlight */
.monitoring{
  padding:40px 0 20px;
}

.monitorPanel{
  background: linear-gradient(180deg,var(--panel),var(--panel2));
  border:1px solid var(--line);
  border-radius:var(--radius);
  box-shadow:var(--shadow);
  padding:28px 26px;
  position:relative;
  overflow:hidden;
}

.monitorPanel::before{
  content:"";
  position:absolute;
  inset:0;
  background:
    radial-gradient(600px 200px at 20% 0%, rgba(53,208,200,.18), transparent 60%),
    radial-gradient(500px 200px at 90% 0%, rgba(74,163,255,.18), transparent 60%);
  pointer-events:none;
}

.monitorGrid{
  display:grid;
  grid-template-columns: 1fr 1fr 1fr;
  gap:18px;
  margin-top:18px;
}

.monitorCard{
  background:rgba(255,255,255,.03);
  border:1px solid var(--line);
  border-radius:var(--radius2);
  padding:18px 16px;
}

.monitorCard h4{
  margin:0 0 6px;
  font-size:1rem;
}

.monitorCard p{
  margin:0;
  color:var(--muted);
  font-size:.92rem;
  line-height:1.4;
}

.monitorTitle{
  font-size:1.6rem;
  font-weight:800;
  letter-spacing:-.01em;
}

.monitorLead{
  margin-top:8px;
  color:var(--muted);
  max-width:70ch;
  line-height:1.45;
}
  </style>
</head>

<body>
  <header class="topbar">
    <div class="container">
      <div class="inner">
        <a class="brand" href="#top">
          <span class="logo" aria-hidden="true"></span>
          <span>
            <div class="brandTitle">FloatPlanWizard</div>
            <div class="brandTag">Route builder, follower pages, and Great Loop templates — made simple.</div>
          </span>
        </a>

        <nav class="navLinks" aria-label="Primary">
          <a href="#routebuilder">Route Builder</a>
          <a href="#followers">Follower Pages</a>
          <a href="#greatloop">Great Loop</a>
          <a href="#how">How it works</a>
          <a href="#faq">FAQ</a>
        </nav>

        <div class="actions">
          <a class="btn btnGhost" href="#login" id="loginBtn">Log in</a>
          <button class="btn btnPrimary" id="startFreeBtn" type="button">Start free</button>
        </div>
      </div>
    </div>
  </header>

  <!-- HERO -->
  <main id="top" class="hero">
    <div class="container">
      <div class="heroGrid">
        <div>
          <div class="pill"><span class="dot"></span> Great Loop-ready routes • shareable follower pages • cockpit UI</div>

          <h1 style="margin-top:14px;">
            Plan your route.
            <br/>
            Share a follower page.
            <br/>
            <span style="color:rgba(255,255,255,.84)">Cruise the Great Loop with confidence.</span>
          </h1>

          <p class="lead">
            FloatPlanWizard is built for Great Loopers who want a clean Route Builder and a follower page their family can trust.
            Start from the <b>Great Loop Template</b>, customize your legs and waypoints, then share a live, readable trip view — no login required for followers.
          </p>

          <div class="heroCtas">
            <button class="btn btnPrimary" type="button" id="earlyAccessBtn">Get early access</button>
            <button class="btn" type="button" id="seeLoopBtn">See the Great Loop Template</button>
            <span class="pill"><strong>No spam</strong> <span style="opacity:.6;">•</span> <strong>1–2 emails</strong></span>
          </div>

          <div class="micro">
            <span class="tag">Designed for long routes + lots of stops</span>
            <span class="tag">Built to share with family & marinas</span>
            <span class="tag">Fast “where are they / what’s next” clarity</span>
          </div>

          <div class="proof">
            <span class="badge">🧭 <b>Route Builder</b> legs + waypoints</span>
            <span class="badge">🔗 <b>Follower Pages</b> share status link</span>
            <span class="badge">🌀 <b>Great Loop Template</b> quick start</span>
          </div>
        </div>

        <div class="glass mock" aria-label="Product preview (mock)">
          <div class="mockTop">
            <div class="mockTitle"><span class="miniLogo" aria-hidden="true"></span> Loop Mission Control</div>
            <div class="mockChipRow">
              <span class="chip chipGood">On track</span>
              <span class="chip chipLoop">Great Loop</span>
            </div>
          </div>

          <div class="mockCard">
            <h4>
              Great Loop Template
              <a class="miniBtn" href="#greatloop">View</a>
            </h4>
            <div class="big">Start with a proven loop</div>
            <div class="sub">A structured template you can customize — legs, waypoints, stops, and timing.</div>
          </div>

          <div class="mockCard">
            <h4>
              Cruise Timeline (Follower Page)
              <span class="chip">7 legs</span>
            </h4>
            <div class="routeList" aria-label="Timeline legs (mock)">
              <div class="leg">
                <div class="legDot" aria-hidden="true"></div>
                <div>
                  <div class="legTitle">Tarpon Springs → Clearwater</div>
                  <div class="legMeta">Day 1 • 22 nm • 2h 45m</div>
                </div>
              </div>
              <div class="leg">
                <div class="legDot" aria-hidden="true" style="background: rgba(74,163,255,.9); box-shadow:0 0 0 4px rgba(74,163,255,.10);"></div>
                <div>
                  <div class="legTitle">Clearwater → Egmont Key</div>
                  <div class="legMeta">Day 2 • 14 nm • 1h 50m</div>
                </div>
              </div>
              <div class="leg">
                <div class="legDot" aria-hidden="true" style="background: rgba(247,201,72,.95); box-shadow:0 0 0 4px rgba(247,201,72,.10);"></div>
                <div>
                  <div class="legTitle">Egmont → Sarasota</div>
                  <div class="legMeta">Day 3 • 28 nm • 3h 15m</div>
                </div>
              </div>
            </div>
          </div>

          <div class="mockCard">
            <h4>
              Share follower page
              <span class="chip">No login</span>
            </h4>
            <div class="sub">
              Share a single link that shows “what’s next”, timeline legs, and an easy-to-read status panel —
              built for family, friends, and marina staff.
            </div>
          </div>
        </div>
      </div>
    </div>
  </main>

  <!-- FLOAT PLAN MONITORING -->
<section class="monitoring">
  <div class="container">

    <div class="monitorPanel">

      <div class="monitorTitle">
        Float Plans + Automated Monitoring
      </div>

      <div class="monitorLead">
        FloatPlanWizard automatically creates a complete float plan for every voyage and
        monitors your trip for missed check-ins or overdue arrivals. Designed with
        <strong>Great Loop cruisers</strong> in mind — but equally valuable for
        <strong>coastal cruisers, weekend boaters, and offshore passages.</strong>
      </div>

      <div class="monitorGrid">

        <div class="monitorCard">
          <h4>Create a Complete Float Plan</h4>
          <p>
            Automatically generate float plans from your route including vessel
            information, crew, emergency contacts, and expected arrival times.
          </p>
        </div>

        <div class="monitorCard">
          <h4>Automated Safety Monitoring</h4>
          <p>
            FPW watches your route timeline and detects missed check-ins,
            delays, or overdue legs so someone knows when something may
            not be right.
          </p>
        </div>

        <div class="monitorCard">
          <h4>Keep Family & Crew Informed</h4>
          <p>
            Share your voyage with trusted contacts so they know where you
            are supposed to be and can follow your progress while you're
            underway.
          </p>
        </div>

      </div>

      <div style="margin-top:20px;color:var(--muted);font-size:.9rem;">
        Ideal for:
        <strong>Great Loop Cruisers</strong> • Coastal Cruisers • Weekend Boaters • Offshore Passages
      </div>

    </div>

  </div>
</section>

  <!-- ROUTE BUILDER -->
  <section id="routebuilder">
    <div class="container">
      <h2 class="sectionTitle">Route Builder that feels like planning — not paperwork</h2>
      <p class="sectionLead">
        The Route Builder is the front door. Build legs and waypoints, tweak the plan as you cruise, and keep everything organized for long trips with lots of stops.
      </p>

      <div class="grid3">
        <div class="glass feature">
          <div class="kicker">
            <div class="icon">🧭</div>
            <div>Legs + waypoints</div>
          </div>
          <p>Build a route that matches how you cruise: a series of legs, each with its own “what’s next.”</p>
          <ul>
            <li>Waypoint-centric planning</li>
            <li>Readable leg lists</li>
            <li>Designed for multi-day trips</li>
          </ul>
        </div>

        <div class="glass feature">
          <div class="kicker">
            <div class="icon">🗺️</div>
            <div>Great Loop-friendly structure</div>
          </div>
          <p>Long routes stay manageable. You can iterate without losing the big picture.</p>
          <ul>
            <li>Organized segments</li>
            <li>Quick edits as conditions change</li>
            <li>Shareable output</li>
          </ul>
        </div>

        <div class="glass feature">
          <div class="kicker">
            <div class="icon">⚡</div>
            <div>Fast to start</div>
          </div>
          <p>Start from the Great Loop Template or a saved route — then customize from there.</p>
          <ul>
            <li>Template-based kickoff</li>
            <li>Reusable routes</li>
            <li>Designed to reduce friction</li>
          </ul>
        </div>
      </div>
    </div>
  </section>

  <!-- FOLLOWER PAGES -->
  <section id="followers">
    <div class="container">
      <h2 class="sectionTitle">Follower Pages that family can understand in 10 seconds</h2>
      <p class="sectionLead">
        The #1 question Great Loopers hear is: “Where are you now, and what’s next?”
        FPW gives you a single share link with a clean timeline and a simple status view — no login needed.
      </p>

      <div class="grid3">
        <div class="glass feature">
          <div class="kicker">
            <div class="icon">🔗</div>
            <div>One link to share</div>
          </div>
          <p>Share a follower page with family and friends — without giving account access.</p>
          <ul>
            <li>Follower-safe public view</li>
            <li>Made for mobile</li>
            <li>Easy to forward or print</li>
          </ul>
        </div>

        <div class="glass feature">
          <div class="kicker">
            <div class="icon">🧾</div>
            <div>Cruise Timeline</div>
          </div>
          <p>A leg list that tells the story of the trip: what happened, what’s next, and how long it should take.</p>
          <ul>
            <li>Legs + day buckets</li>
            <li>Readable stop-to-stop flow</li>
            <li>Designed for clarity</li>
          </ul>
        </div>

        <div class="glass feature">
          <div class="kicker">
            <div class="icon">📣</div>
            <div>“What to do” ready</div>
          </div>
          <p>When a follower needs to act, they have the information in one place — not scattered in texts.</p>
          <ul>
            <li>Action-first presentation</li>
            <li>Clear status language</li>
            <li>Designed for non-boaters</li>
          </ul>
        </div>
      </div>

      <div class="glass ctaBand" style="margin-top:16px;">
        <div>
          <h3>Built for Great Loop sharing</h3>
          <p>
            FPW focuses on the two moments that matter most: route planning before the trip,
            and clarity for followers during the trip.
          </p>
        </div>
        <div class="right">
          <button class="btn btnPrimary" type="button" data-open="early">Get early access</button>
          <button class="btn" type="button" data-open="loop">See the Great Loop Template</button>
          <span class="pill"><strong>No spam</strong> • 1–2 emails</span>
        </div>
      </div>
    </div>
  </section>

  <!-- GREAT LOOP TEMPLATE -->
  <section id="greatloop">
    <div class="container">
      <h2 class="sectionTitle">Great Loop Template: the fastest way to get started</h2>
      <p class="sectionLead">
        Great Loopers don’t need a blank page. You need a structured starting point you can customize —
        then share with your crew and followers.
      </p>

      <div class="glass loopPanel">
        <div>
          <h3>What the Great Loop Template gives you</h3>
          <p>
            A curated foundation for Loop planning: a predictable structure, a clear leg/timeline format,
            and an easy-to-share follower view. Use it as-is or customize every part of it.
          </p>

          <div class="micro" style="margin-top:12px;">
            <span class="tag">Quick start: template → edits → share</span>
            <span class="tag">Designed for long cruises</span>
            <span class="tag">Built to iterate as you go</span>
          </div>
        </div>

        <div class="loopStats" aria-label="Template perks (mock stats)">
          <div class="stat">
            <div class="label">🌀 Template kickoff</div>
            <div class="value">Start in minutes</div>
            <div class="note">No blank-route paralysis.</div>
          </div>
          <div class="stat">
            <div class="label">🧭 Leg structure</div>
            <div class="value">Readable planning</div>
            <div class="note">Stop-to-stop clarity.</div>
          </div>
          <div class="stat">
            <div class="label">🔗 Share ready</div>
            <div class="value">Follower page</div>
            <div class="note">Family can follow easily.</div>
          </div>
          <div class="stat">
            <div class="label">⚙️ Customize</div>
            <div class="value">Your route, your pace</div>
            <div class="note">Edit legs + waypoints.</div>
          </div>
        </div>
      </div>

      <div class="compare">
        <div class="glass compareCard">
          <h4>Starting from scratch</h4>
          <p>It’s easy to get stuck when a trip has dozens of stops and months of planning.</p>
          <ul>
            <li>Hard to maintain structure</li>
            <li>Scattered notes and links</li>
            <li>Followers get inconsistent updates</li>
          </ul>
        </div>
        <div class="glass compareCard" style="border-color: rgba(74,163,255,.18);">
          <h4>Starting from the Great Loop Template</h4>
          <p>A clean baseline you can customize — with a route and follower view that stays readable.</p>
          <ul>
            <li>Clear leg/timeline format</li>
            <li>Shareable follower page built-in</li>
            <li>Easy to tweak as you cruise</li>
          </ul>
        </div>
      </div>

      <div class="heroCtas" style="margin-top:18px;">
        <button class="btn btnPrimary" type="button" id="ctaBottomBtn">Get early access</button>
        <button class="btn btnGhost" type="button" data-open="loop">Preview the template</button>
        <span class="pill"><strong>Built for Loopers</strong> • long routes • many stops</span>
      </div>
    </div>
  </section>

  <!-- HOW IT WORKS -->
  <section id="how">
    <div class="container">
      <h2 class="sectionTitle">How Loopers use FPW</h2>
      <p class="sectionLead">
        FPW’s workflow is intentionally simple: build a route, share it, and keep followers informed.
        (The float plan remains important — but the conversion focus is Route Builder + Follower Pages.)
      </p>

      <div class="compare">
        <div class="glass compareCard">
          <h4>1) Build your route</h4>
          <p>Use the Great Loop Template or a saved route. Customize legs and waypoints for your trip.</p>
          <ul>
            <li>Leg lists that stay readable</li>
            <li>Waypoint-centric planning</li>
            <li>Organized for long cruises</li>
          </ul>
        </div>

        <div class="glass compareCard">
          <h4>2) Share the follower page</h4>
          <p>Send one link to family and friends. They can see the trip flow without needing an account.</p>
          <ul>
            <li>Cruise timeline legs</li>
            <li>Status panel for clarity</li>
            <li>Mobile-friendly view</li>
          </ul>
        </div>
      </div>

      <div class="glass ctaBand" style="margin-top:16px;">
        <div>
          <h3>Want the Great Loop Template + follower pages?</h3>
          <p>Join early access and help shape the next set of Looper-focused features.</p>
        </div>
        <div class="right">
          <button class="btn btnPrimary" type="button" data-open="early">Get early access</button>
          <a class="btn" href="#faq">FAQ</a>
          <span class="pill"><strong>No spam</strong> • 1–2 emails</span>
        </div>
      </div>
    </div>
  </section>

  <!-- FAQ -->
  <section id="faq">
    <div class="container">
      <h2 class="sectionTitle">FAQ</h2>
      <p class="sectionLead">Short answers for Great Loopers before they commit to a new planning tool.</p>

      <div class="faq">
        <details open>
          <summary>Is FPW only for Great Loopers?</summary>
          <p>
            No — but Great Loopers are a primary focus because the trip structure and “many stops over months” planning
            demands a better route/timeline workflow and shareable follower view.
          </p>
        </details>

        <details>
          <summary>What’s the Great Loop Template?</summary>
          <p>
            A structured starting point for planning that avoids the blank page. It’s designed to be customized and then shared
            via a follower page so family can understand the trip flow.
          </p>
        </details>

        <details>
          <summary>What is a follower page?</summary>
          <p>
            A follower page is a shareable link that shows a readable cruise timeline (legs/days) and a simple trip status view.
            Followers don’t need an account.
          </p>
        </details>

        <details>
          <summary>Do I still need a float plan?</summary>
          <p>
            Yes — float plans are still important. FPW’s homepage emphasizes Route Builder + follower pages because they reduce friction and
            make the plan easier to use day-to-day, especially on the Loop.
          </p>
        </details>

        <details>
          <summary>How do I start?</summary>
          <p>
            Join early access. You’ll get the Great Loop Template workflow, Route Builder, and follower pages first — and you can help decide what ships next.
          </p>
        </details>

        <details>
          <summary>Is this standalone page production-ready?</summary>
          <p>
            This file is a standalone mockup for review. Once approved, the markup can be moved into your FPW CFM templates with the same style tokens.
          </p>
        </details>
      </div>
    </div>
  </section>

  <footer>
    <div class="container">
      <div class="footGrid">
        <div>
          <div style="display:flex; gap:10px; align-items:center;">
            <span class="logo" aria-hidden="true" style="width:30px;height:30px;border-radius:10px;"></span>
            <div style="font-weight:1000; letter-spacing:.2px;">FloatPlanWizard</div>
          </div>
          <p class="small" style="margin-top:10px;">
            Route Builder + follower pages built for Great Loopers — and anyone who wants shareable clarity during a trip.
          </p>
          <div class="proof" style="margin-top:10px;">
            <span class="badge">🧭 Route Builder</span>
            <span class="badge">🔗 Follower Pages</span>
            <span class="badge">🌀 Great Loop Template</span>
          </div>
        </div>

        <div class="footLinks">
          <div style="font-weight:950; color:rgba(255,255,255,.82); margin-bottom:6px;">Explore</div>
          <a href="#routebuilder">Route Builder</a>
          <a href="#followers">Follower Pages</a>
          <a href="#greatloop">Great Loop Template</a>
          <a href="#how">How it works</a>
        </div>

        <div class="footLinks">
          <div style="font-weight:950; color:rgba(255,255,255,.82); margin-bottom:6px;">Get started</div>
          <a href="#top" id="footerStart">Get early access</a>
          <a href="#faq">FAQ</a>
          <a href="#login">Log in</a>
        </div>
      </div>

      <div style="margin-top:18px; display:flex; justify-content:space-between; gap:10px; flex-wrap:wrap;">
        <div class="small">© <span id="year"></span> FloatPlanWizard</div>
        <div class="small">Standalone mockup for review.</div>
      </div>
    </div>
  </footer>

  <!-- Modal -->
  <div class="modalOverlay" id="modal">
    <div class="modal" role="dialog" aria-modal="true" aria-label="Early access">
      <div class="modalHead">
        <div>
          <h3 id="modalTitle">Get early access</h3>
          <p id="modalDesc">Join the Looper-first rollout. We’ll send 1–2 emails when new features ship.</p>
        </div>
        <button class="closeBtn" type="button" id="closeModal" aria-label="Close">✕</button>
      </div>

      <div class="formRow">
        <input class="input" id="email" type="email" placeholder="you@email.com" autocomplete="email" />
        <button class="btn btnPrimary" id="submitEmail" type="button">Request access</button>
      </div>
      <div style="margin-top:10px; display:flex; gap:10px; flex-wrap:wrap; align-items:center;">
        <span class="pill"><strong>No spam</strong> • 1–2 emails</span>
        <span class="pill"><strong>Great Loop focus</strong> • Looper-first features</span>
      </div>
    </div>
  </div>

  <div class="toast" id="toast">Saved. (Mock)</div>

  <script>
    const $ = (sel, root=document) => root.querySelector(sel);
    const $$ = (sel, root=document) => Array.from(root.querySelectorAll(sel));

    $("#year").textContent = new Date().getFullYear();

    // Smooth scroll for internal anchors
    $$(".navLinks a, footer a").forEach(a => {
      const href = a.getAttribute("href") || "";
      if(href.startsWith("#")){
        a.addEventListener("click", (e) => {
          const target = $(href);
          if(target){
            e.preventDefault();
            target.scrollIntoView({behavior:"smooth", block:"start"});
          }
        });
      }
    });

    // Modal controls
    const modal = $("#modal");
    const openModal = (mode="early") => {
      const title = $("#modalTitle");
      const desc = $("#modalDesc");
      if(mode === "loop"){
        title.textContent = "Preview: Great Loop Template";
        desc.textContent = "The template is a structured starting point for Loop planning — legs + waypoints + follower-friendly timeline.";
      }else if(mode === "start"){
        title.textContent = "Start free";
        desc.textContent = "Create your first route and generate a follower page link (early access).";
      }else{
        title.textContent = "Get early access";
        desc.textContent = "Join the Looper-first rollout. We’ll send 1–2 emails when new features ship.";
      }
      modal.classList.add("open");
      setTimeout(()=> $("#email").focus(), 50);
    };
    const closeModal = () => modal.classList.remove("open");

    $("#startFreeBtn").addEventListener("click", ()=>openModal("start"));
    $("#earlyAccessBtn").addEventListener("click", ()=>openModal("early"));
    $("#seeLoopBtn").addEventListener("click", ()=>openModal("loop"));
    $("#ctaBottomBtn").addEventListener("click", ()=>openModal("early"));
    $("#footerStart").addEventListener("click", (e)=>{ e.preventDefault(); openModal("early"); });

    $$("[data-open]").forEach(btn => btn.addEventListener("click", ()=>openModal(btn.dataset.open)));

    $("#closeModal").addEventListener("click", closeModal);
    modal.addEventListener("click", (e)=>{ if(e.target === modal) closeModal(); });
    document.addEventListener("keydown", (e)=>{ if(e.key === "Escape") closeModal(); });

    // Toast
    const toast = $("#toast");
    const showToast = (msg) => {
      toast.textContent = msg;
      toast.classList.add("show");
      setTimeout(()=>toast.classList.remove("show"), 2200);
    };

    // Mock submit
    $("#submitEmail").addEventListener("click", ()=> {
      const val = ($("#email").value || "").trim();
      if(!val || !val.includes("@")){
        showToast("Enter a valid email. (Mock)");
        $("#email").focus();
        return;
      }
      closeModal();
      showToast("Request received. (Mock)");
      $("#email").value = "";
    });

    // Login link is a placeholder for standalone mode
    $("#loginBtn").addEventListener("click", (e)=>{
      e.preventDefault();
      showToast("Login opens on your live site. (Mock)");
    });
  </script>
</body>
</html>