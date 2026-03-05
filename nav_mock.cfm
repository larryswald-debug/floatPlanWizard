<!--
PURE HTML MOCKUP (NO CFM) — FPW Top Nav
Includes styling. Shows BOTH states for review:
1) Pre-login marketing nav + inline login strip
2) Post-login app nav (tabs + alerts + +New + user menu)

To preview:
- Open this as a standalone .html file.
- Toggle states by adding/removing class "is-logged-in" on <body>.
-->

<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>FPW Nav Mock</title>

  <style>
    :root{
      --bg0:#07121f;
      --bg1:#0a1a2b;
      --panel:#0b1a2a;
      --line:rgba(255,255,255,.08);
      --text:rgba(255,255,255,.88);
      --muted:rgba(255,255,255,.62);
      --accent:#35d0c8;
      --accent2:#4aa3ff;
      --shadow: 0 18px 50px rgba(0,0,0,.35);
      --radius:14px;
      --radius2:12px;
      --font: ui-sans-serif, system-ui, -apple-system, Segoe UI, Roboto, Helvetica, Arial, "Apple Color Emoji","Segoe UI Emoji";
    }

    *{ box-sizing:border-box; }
    body{
      margin:0;
      font-family:var(--font);
      background:#0b1320;
      color:var(--text);
    }

    /* ===== Toggle logic =====
       body:not(.is-logged-in) shows pre-login
       body.is-logged-in shows post-login
    */
    .nav--public, .loginStrip{ display:block; }
    .nav--app{ display:none; }
    body.is-logged-in .nav--public,
    body.is-logged-in .loginStrip{ display:none; }
    body.is-logged-in .nav--app{ display:block; }

    /* ===== Shell ===== */
    .topbar{
      background:
        radial-gradient(1200px 90px at 10% 0%, rgba(53,208,200,.18), transparent 55%),
        radial-gradient(900px 110px at 85% 10%, rgba(74,163,255,.16), transparent 60%),
        linear-gradient(180deg, var(--bg0), var(--bg1));
      border-bottom:1px solid var(--line);
    }
    .inner{
      max-width:1200px;
      margin:0 auto;
      padding:12px 16px;
      display:flex;
      align-items:center;
      gap:16px;
    }

    /* ===== Brand ===== */
    .brand{
      display:flex;
      align-items:center;
      gap:10px;
      text-decoration:none;
      color:inherit;
      min-width: 300px;
    }
    .logo{
      width:34px; height:34px; border-radius:10px;
      background:
        radial-gradient(circle at 30% 20%, rgba(255,255,255,.35), transparent 40%),
        linear-gradient(135deg, rgba(53,208,200,.95), rgba(74,163,255,.75));
      box-shadow: 0 8px 18px rgba(0,0,0,.25);
      flex:0 0 auto;
    }
    .brandTitle{
      font-weight:900;
      letter-spacing:.2px;
      line-height:1.05;
    }
    .tagline{
      font-size:.92rem;
      color:var(--muted);
      margin-top:2px;
      line-height:1.15;
    }

    /* ===== Public nav ===== */
    .navLinks{
      display:flex;
      align-items:center;
      gap:14px;
      flex-wrap:wrap;
    }
    .navLinks a{
      color:var(--muted);
      text-decoration:none;
      font-weight:700;
      padding:8px 6px;
      border-radius:10px;
    }
    .navLinks a:hover{
      color:var(--text);
      background:rgba(255,255,255,.05);
    }

    /* ===== Actions / buttons ===== */
    .actions{
      margin-left:auto;
      display:flex;
      align-items:center;
      gap:10px;
    }
    .btn{
      border-radius:10px;
      padding:8px 12px;
      font-weight:800;
      font-size:.92rem;
      border:1px solid var(--line);
      background: rgba(255,255,255,.04);
      color:var(--text);
      text-decoration:none;
      display:inline-flex;
      align-items:center;
      gap:8px;
      cursor:pointer;
      user-select:none;
    }
    .btn:hover{ background: rgba(255,255,255,.07); }
    .btnPrimary{
      border-color: rgba(53,208,200,.35);
      background: linear-gradient(135deg, rgba(53,208,200,.95), rgba(74,163,255,.75));
      color:#021018;
    }
    .divider{
      width:1px; height:26px;
      background:var(--line);
      margin:0 4px;
    }

    /* ===== Login strip (pre-login) ===== */
    .loginStrip{
      background: rgba(0,0,0,.18);
      border-bottom:1px solid var(--line);
    }
    .loginInner{
      max-width:1200px;
      margin:0 auto;
      padding:10px 16px;
      display:flex;
      align-items:center;
      gap:10px;
      flex-wrap:wrap;
    }
    .field{
      display:flex;
      flex-direction:column;
      gap:6px;
    }
    .field label{
      font-size:.78rem;
      color:var(--muted);
      font-weight:700;
      display:none; /* keep clean; placeholders handle */
    }
    .input{
      background: rgba(255,255,255,.06);
      border:1px solid var(--line);
      color:var(--text);
      border-radius:10px;
      padding:8px 10px;
      min-width: 220px;
      outline:none;
    }
    .input::placeholder{ color: rgba(255,255,255,.45); }
    .forgot{
      color:var(--muted);
      text-decoration:none;
      font-weight:700;
      padding:6px 8px;
      border-radius:10px;
    }
    .forgot:hover{ color:var(--text); background:rgba(255,255,255,.05); }

    /* ===== App nav ===== */
    .brandCompact{
      min-width:auto;
    }
    .brandCompact .tagline{ display:none; }
    .brandCompact .brandTitle{ letter-spacing:.35px; }
    .tabs{
      display:flex;
      align-items:center;
      gap:8px;
      flex-wrap:wrap;
    }
    .tab{
      color:var(--muted);
      text-decoration:none;
      font-weight:900;
      padding:8px 10px;
      border-radius:12px;
      border:1px solid transparent;
    }
    .tab:hover{ color:var(--text); background:rgba(255,255,255,.05); }
    .tab.active{
      color:var(--text);
      background: rgba(53,208,200,.12);
      border-color: rgba(53,208,200,.22);
    }

    /* ===== Icon button + badge ===== */
    .iconBtn{
      position:relative;
      width:38px; height:38px;
      border-radius:12px;
      border:1px solid var(--line);
      background: rgba(255,255,255,.04);
      color:var(--text);
      display:inline-flex;
      align-items:center;
      justify-content:center;
      cursor:pointer;
    }
    .iconBtn:hover{ background: rgba(255,255,255,.07); }
    .badge{
      position:absolute;
      top:-6px; right:-6px;
      min-width:18px; height:18px;
      border-radius:999px;
      background: rgba(53,208,200,.95);
      color:#021018;
      font-size:.75rem;
      font-weight:900;
      display:flex;
      align-items:center;
      justify-content:center;
      padding:0 5px;
      box-shadow: 0 10px 18px rgba(0,0,0,.25);
    }

    /* ===== Dropdown (pure HTML/CSS via <details>) ===== */
    details.dd{
      position:relative;
    }
    details.dd > summary{
      list-style:none;
    }
    details.dd > summary::-webkit-details-marker{ display:none; }

    .menu{
      position:absolute;
      right:0;
      top: calc(100% + 10px);
      min-width: 240px;
      background: var(--panel);
      border:1px solid rgba(255,255,255,.08);
      border-radius: var(--radius);
      box-shadow: var(--shadow);
      padding:8px;
      z-index:1000;
    }
    .menu a, .menu button{
      width:100%;
      display:flex;
      align-items:center;
      gap:10px;
      padding:10px 10px;
      border-radius:12px;
      border:0;
      background: transparent;
      color: rgba(255,255,255,.86);
      text-decoration:none;
      font-weight:800;
      cursor:pointer;
      text-align:left;
      font-family:var(--font);
      font-size:.95rem;
    }
    .menu a:hover, .menu button:hover{
      background: rgba(255,255,255,.06);
      color: rgba(255,255,255,.95);
    }
    .menu hr{
      border:0;
      border-top:1px solid rgba(255,255,255,.08);
      margin:8px 0;
    }
    .hint{
      max-width:1200px;
      margin: 18px auto 0;
      padding: 0 16px;
      color: var(--muted);
      font-weight:700;
      font-size:.95rem;
    }
    .hint code{
      background: rgba(255,255,255,.06);
      border:1px solid rgba(255,255,255,.08);
      padding:2px 8px;
      border-radius:10px;
      color: rgba(255,255,255,.86);
    }

    /* Responsive: hide center links on public; you’d add hamburger later */
    @media (max-width: 980px){
      .tagline{ display:none; }
      .navLinks{ display:none; }
      .brand{ min-width:auto; }
      .input{ min-width: 180px; }
    }
  </style>
</head>

<!-- Toggle class: remove "is-logged-in" to see pre-login -->
<body class="">
  <div class="hint">
    Toggle states: add/remove <code>is-logged-in</code> on &lt;body&gt;.
  </div>

  <!-- ================= PRE-LOGIN ================= -->
  <header class="topbar nav--public" role="banner">
    <div class="inner">
      <a class="brand" href="#" aria-label="FloatPlanWizard Home">
        <span class="logo" aria-hidden="true"></span>
        <span>
          <div class="brandTitle">FloatPlanWizard</div>
          <div class="tagline">Float plans, check-ins, and overdue alerts — made simple.</div>
        </span>
      </a>

      <nav class="navLinks" aria-label="Primary">
        <a href="#features">Features</a>
        <a href="#how">How it works</a>
        <a href="#monitoring">Monitoring</a>
        <a href="#pricing">Pricing</a>
        <a href="#faq">FAQ</a>
      </nav>

      <div class="actions">
        <a class="btn" href="#login">Log in</a>
        <a class="btn btnPrimary" href="#start">Start free</a>
      </div>
    </div>
  </header>

  <section class="loginStrip" id="login" aria-label="Login">
    <div class="loginInner">
      <div class="field">
        <label>Email</label>
        <input class="input" type="email" placeholder="Email" />
      </div>
      <div class="field">
        <label>Password</label>
        <input class="input" type="password" placeholder="Password" />
      </div>
      <button class="btn btnPrimary" type="button">Sign In</button>
      <a class="forgot" href="#forgot">Forgot?</a>
    </div>
  </section>

  <!-- ================= POST-LOGIN ================= -->
  <header class="topbar nav--app" role="banner">
    <div class="inner">
      <a class="brand brandCompact" href="#" aria-label="Dashboard">
        <span class="logo" aria-hidden="true"></span>
        <span>
          <div class="brandTitle">FPW</div>
        </span>
      </a>

      <nav class="tabs" aria-label="App Primary">
        <a class="tab active" href="#dashboard">Dashboard</a>
        <a class="tab" href="#voyages">Voyages</a>
        <a class="tab" href="#routes">Routes</a>
        <a class="tab" href="#floatplans">Float Plans</a>
        <a class="tab" href="#monitoring">Monitoring</a>
        <a class="tab" href="#weather">Weather</a>
      </nav>

      <div class="actions">
        <button class="iconBtn" type="button" aria-label="Alerts" title="Alerts">
          🔔
          <span class="badge">3</span>
        </button>

        <span class="divider" aria-hidden="true"></span>

        <!-- + New -->
        <details class="dd">
          <summary class="btn btnPrimary">+ New</summary>
          <div class="menu" role="menu" aria-label="New menu">
            <a href="#new-voyage">🧭 New Voyage</a>
            <a href="#new-route">🗺️ New Route</a>
            <a href="#new-floatplan">📄 New Float Plan</a>
            <hr />
            <a href="#invite">👥 Invite Follower</a>
          </div>
        </details>

        <!-- User -->
        <details class="dd">
          <summary class="btn">Lawrence Wald</summary>
          <div class="menu" role="menu" aria-label="User menu">
            <a href="#account">👤 Account</a>
            <a href="#settings">⚙️ Settings</a>
            <hr />
            <button type="button">🚪 Log out</button>
          </div>
        </details>
      </div>
    </div>
  </header>

  <!-- Demo page content -->
  <main style="max-width:1200px; margin:26px auto; padding:0 16px; color:rgba(255,255,255,.80);">
    <h2 style="margin:0 0 8px;">Mock Page Content</h2>
    <p style="margin:0; color:rgba(255,255,255,.62); font-weight:650;">
      This is just a visual mock to review navigation layout and hierarchy.
    </p>
  </main>
</body>
</html>