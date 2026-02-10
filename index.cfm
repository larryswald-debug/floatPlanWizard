<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <title>FloatPlanWizard — Spring 2026 Relaunch</title>
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <meta name="description" content="FloatPlanWizard helps boaters create float plans, share them, and automatically monitor check-ins and overdue status. Spring 2026 relaunch." />
<cfinclude  template="includes/header_styles.cfm">

<cfinclude  template="includes/top_nav.cfm">
  <style>
    :root{
      --bg:#0b1220;
      --panel:rgba(255,255,255,.06);
      --panel2:rgba(255,255,255,.08);
      --text:rgba(255,255,255,.92);
      --muted:rgba(255,255,255,.72);
      --subtle:rgba(255,255,255,.55);
      --line:rgba(255,255,255,.12);

      --brand:#2dd4bf;
      --brand2:#60a5fa;

      --ok:#34d399;
      --warn:#fbbf24;
      --danger:#fb7185;

      --radius:18px;
      --radius2:26px;
      --shadow:0 18px 60px rgba(0,0,0,.45);

      --max:1120px;
      --font: ui-sans-serif, system-ui, -apple-system, Segoe UI, Roboto, Helvetica, Arial, "Apple Color Emoji","Segoe UI Emoji";
    }

    *{box-sizing:border-box}
    html,body{height:100%}
    body{
      margin:0;
      font-family:var(--font);
      color:var(--text);
      background:
        radial-gradient(900px 600px at 20% 10%, rgba(45,212,191,.20), transparent 55%),
        radial-gradient(900px 600px at 80% 15%, rgba(96,165,250,.22), transparent 55%),
        radial-gradient(1000px 700px at 50% 90%, rgba(251,191,36,.14), transparent 60%),
        linear-gradient(180deg, #070b14, var(--bg));
      line-height:1.35;
      overflow-x:hidden;
    }

    a{color:inherit;text-decoration:none}
    .wrap{max-width:var(--max); margin:0 auto; padding:0 20px}
    .grid{display:grid; gap:18px}

    /* Buttons / pills */
    .btn{
      display:inline-flex; align-items:center; justify-content:center;
      gap:10px;
      padding:12px 16px;
      border-radius:999px;
      border:1px solid var(--line);
      background:rgba(255,255,255,.06);
      color:var(--text);
      font-weight:650;
      letter-spacing:.2px;
      box-shadow: 0 10px 30px rgba(0,0,0,.25);
      transition:transform .15s ease, background .15s ease, border-color .15s ease;
      cursor:pointer;
      white-space:nowrap;
    }
    .btn:hover{transform: translateY(-1px); background: rgba(255,255,255,.09); border-color: rgba(255,255,255,.18);}
    .btn.primary{
      border-color: rgba(45,212,191,.45);
      background: linear-gradient(135deg, rgba(45,212,191,.18), rgba(96,165,250,.14));
    }
    .btn.primary:hover{border-color: rgba(45,212,191,.70)}
    .btn.small{padding:10px 14px; font-size:14px}

    .pill{
      display:inline-flex; align-items:center; gap:8px;
      padding:8px 12px;
      border-radius:999px;
      border:1px solid rgba(255,255,255,.14);
      background:rgba(255,255,255,.06);
      color:var(--muted);
      font-size:13px;
    }
    .dot{width:9px; height:9px; border-radius:999px; background:var(--brand); box-shadow:0 0 0 4px rgba(45,212,191,.15)}
    .kbd{
      font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, "Liberation Mono", "Courier New", monospace;
      font-size:12px;
      padding:2px 7px;
      border-radius:8px;
      border:1px solid rgba(255,255,255,.14);
      background: rgba(255,255,255,.06);
      color: rgba(255,255,255,.82);
    }

    /* Top bar */
    .topbar{
      position:sticky; top:0; z-index:50;
      backdrop-filter: blur(14px);
      background: rgba(7,11,20,.65);
      border-bottom:1px solid rgba(255,255,255,.08);
    }
    .topbar .inner{
      display:flex; align-items:center; justify-content:space-between;
      padding:14px 0;
      gap:14px;
    }
    .brand{
      display:flex; align-items:center; gap:10px;
      font-weight:800; letter-spacing:.2px;
    }
    .logo{
      width:34px; height:34px; border-radius:12px;
      background:
        radial-gradient(10px 10px at 30% 30%, rgba(255,255,255,.65), transparent 60%),
        conic-gradient(from 210deg, rgba(45,212,191,.90), rgba(96,165,250,.90), rgba(251,191,36,.75), rgba(45,212,191,.90));
      box-shadow: 0 10px 30px rgba(0,0,0,.35);
      border:1px solid rgba(255,255,255,.18);
    }
    nav{display:flex; align-items:center; gap:14px; flex-wrap:wrap}
    nav a{
      color:var(--muted);
      font-weight:650;
      font-size:14px;
      padding:8px 10px;
      border-radius:999px;
      border:1px solid transparent;
      transition: background .15s ease, border-color .15s ease, color .15s ease;
    }
    nav a:hover{
      color:var(--text);
      background: rgba(255,255,255,.06);
      border-color: rgba(255,255,255,.10);
    }

    /* Hero */
    .hero{padding:56px 0 22px}
    .heroGrid{
      display:grid;
      grid-template-columns: 1.1fr .9fr;
      gap:22px;
      align-items:stretch;
    }
    .h1{
      font-size: clamp(34px, 4.2vw, 54px);
      line-height:1.02;
      margin:14px 0 10px;
      letter-spacing:-.6px;
    }
    .lead{
      color:var(--muted);
      font-size: clamp(16px, 1.45vw, 18px);
      max-width: 60ch;
      margin: 0 0 20px;
    }
    .heroActions{display:flex; gap:12px; flex-wrap:wrap; align-items:center}
    .heroFine{
      margin-top:14px;
      color:var(--subtle);
      font-size:13px;
      display:flex; align-items:center; gap:10px; flex-wrap:wrap;
    }

    /* Cards */
    .card{
      border-radius: var(--radius2);
      border: 1px solid rgba(255,255,255,.12);
      background: linear-gradient(180deg, rgba(255,255,255,.07), rgba(255,255,255,.04));
      box-shadow: var(--shadow);
      overflow:hidden;
    }
    .cardPad{padding:18px}
    .cardTitle{font-weight:800; letter-spacing:.2px; margin:0 0 10px}
    .cardSub{color:var(--muted); margin:0 0 14px}

    .miniGrid{display:grid; grid-template-columns:1fr; gap:12px}
    .mini{
      border-radius: 16px;
      border:1px solid rgba(255,255,255,.10);
      background: rgba(255,255,255,.05);
      padding:12px;
      display:flex; gap:12px; align-items:flex-start;
    }
    .icon{
      width:36px; height:36px; border-radius:14px;
      border:1px solid rgba(255,255,255,.14);
      background:
        radial-gradient(12px 12px at 30% 30%, rgba(255,255,255,.35), transparent 60%),
        linear-gradient(135deg, rgba(45,212,191,.18), rgba(96,165,250,.10));
      display:grid; place-items:center;
      flex:0 0 auto;
    }
    .mini h4{margin:0 0 4px; font-size:14px}
    .mini p{margin:0; color:var(--muted); font-size:13px}

    /* “App preview” mock */
    .preview{
      height: 420px;
      position:relative;
      border-radius: var(--radius2);
      overflow:hidden;
      border:1px solid rgba(255,255,255,.14);
      background:
        radial-gradient(600px 360px at 35% 20%, rgba(45,212,191,.20), transparent 62%),
        radial-gradient(650px 420px at 75% 10%, rgba(96,165,250,.22), transparent 62%),
        linear-gradient(180deg, rgba(255,255,255,.06), rgba(255,255,255,.03));
      box-shadow: var(--shadow);
    }
    .previewTop{
      display:flex; align-items:center; justify-content:space-between;
      padding:14px 14px 10px;
      border-bottom:1px solid rgba(255,255,255,.10);
      background: rgba(10,16,30,.35);
      backdrop-filter: blur(10px);
    }
    .windowDots{display:flex; gap:7px}
    .windowDots span{width:10px;height:10px;border-radius:999px;background:rgba(255,255,255,.18)}
    .windowDots span:nth-child(1){background:rgba(251,113,133,.75)}
    .windowDots span:nth-child(2){background:rgba(251,191,36,.75)}
    .windowDots span:nth-child(3){background:rgba(52,211,153,.75)}
    .previewTop .meta{display:flex; gap:10px; align-items:center}
    .tag{
      font-size:12px;
      color:rgba(255,255,255,.75);
      padding:6px 10px;
      border-radius:999px;
      border:1px solid rgba(255,255,255,.14);
      background:rgba(255,255,255,.05);
    }
    .previewBody{padding:14px}
    .fakeNav{
      display:flex; gap:10px; flex-wrap:wrap;
      margin-bottom:12px;
    }
    .fakeNav .chip{
      padding:8px 10px;
      border-radius:999px;
      border:1px solid rgba(255,255,255,.12);
      background: rgba(255,255,255,.05);
      font-size:12px;
      color:rgba(255,255,255,.78);
    }
    .fakeNav .chip.active{
      border-color: rgba(45,212,191,.45);
      background: rgba(45,212,191,.12);
      color: rgba(255,255,255,.92);
    }
    .rows{display:grid; gap:10px}
    .row{
      display:grid;
      grid-template-columns: 1.3fr .7fr .7fr;
      gap:10px;
      padding:12px;
      border-radius: 16px;
      border:1px solid rgba(255,255,255,.10);
      background: rgba(255,255,255,.04);
    }
    .row strong{font-size:13px}
    .row span{color:var(--muted); font-size:12px}
    .status{
      display:inline-flex; align-items:center; gap:8px;
      font-weight:700; font-size:12px;
      padding:7px 10px; border-radius:999px;
      border:1px solid rgba(255,255,255,.14);
      background: rgba(255,255,255,.05);
      justify-content:center;
      width: fit-content;
    }
    .status.ok{border-color: rgba(52,211,153,.35); background: rgba(52,211,153,.10)}
    .status.warn{border-color: rgba(251,191,36,.35); background: rgba(251,191,36,.10)}
    .status.danger{border-color: rgba(251,113,133,.35); background: rgba(251,113,133,.10)}
    .status i{display:inline-block;width:8px;height:8px;border-radius:999px;background:rgba(255,255,255,.7)}
    .status.ok i{background:var(--ok)}
    .status.warn i{background:var(--warn)}
    .status.danger i{background:var(--danger)}
    .ghost{
      position:absolute; inset:auto 16px 16px auto;
      width: 56%;
      max-width: 300px;
      border-radius: 22px;
      border: 1px solid rgba(255,255,255,.14);
      background: rgba(7,11,20,.45);
      backdrop-filter: blur(10px);
      box-shadow: 0 16px 50px rgba(0,0,0,.40);
      padding: 14px;
    }
    .ghost h5{margin:0 0 8px; font-size:13px}
    .ghost p{margin:0; color:var(--muted); font-size:12px}
    .ghost .bar{
      height:10px; border-radius:999px; overflow:hidden;
      border:1px solid rgba(255,255,255,.12);
      background: rgba(255,255,255,.05);
      margin-top:10px;
    }
    .ghost .bar > div{
      height:100%;
      width:68%;
      background: linear-gradient(90deg, rgba(45,212,191,.85), rgba(96,165,250,.85));
    }

    /* Sections */
    section{padding:44px 0}
    .sectionHead{
      display:flex; align-items:flex-end; justify-content:space-between; gap:18px;
      margin-bottom:16px;
      flex-wrap:wrap;
    }
    .sectionHead h2{
      margin:0;
      font-size: clamp(22px, 2.6vw, 34px);
      letter-spacing:-.3px;
      line-height:1.1;
    }
    .sectionHead p{margin:0; color:var(--muted); max-width:68ch}

    .featureGrid{
      display:grid;
      grid-template-columns: repeat(3, minmax(0, 1fr));
      gap:14px;
    }
    .feature{
      padding:16px;
      border-radius: var(--radius);
      border:1px solid rgba(255,255,255,.12);
      background: rgba(255,255,255,.04);
    }
    .feature h3{margin:10px 0 8px; font-size:15px}
    .feature p{margin:0; color:var(--muted); font-size:13px}

    .howGrid{
      display:grid;
      grid-template-columns: 1fr 1fr;
      gap:14px;
    }
    .step{
      padding:16px;
      border-radius: var(--radius);
      border:1px solid rgba(255,255,255,.12);
      background: rgba(255,255,255,.04);
      display:flex; gap:12px; align-items:flex-start;
    }
    .num{
      width:34px; height:34px; border-radius: 14px;
      display:grid; place-items:center;
      border:1px solid rgba(255,255,255,.14);
      background: rgba(255,255,255,.06);
      font-weight:800;
    }
    .step h4{margin:0 0 6px; font-size:14px}
    .step p{margin:0; color:var(--muted); font-size:13px}

    .cta{
      border-radius: var(--radius2);
      border: 1px solid rgba(255,255,255,.14);
      background:
        radial-gradient(700px 380px at 20% 30%, rgba(45,212,191,.18), transparent 60%),
        radial-gradient(700px 380px at 80% 30%, rgba(96,165,250,.16), transparent 60%),
        rgba(255,255,255,.04);
      box-shadow: var(--shadow);
      padding: 22px;
      display:flex; align-items:center; justify-content:space-between; gap:18px;
      flex-wrap:wrap;
    }
    .cta h3{margin:0; font-size:18px}
    .cta p{margin:6px 0 0; color:var(--muted); font-size:13px; max-width:70ch}

    .faqGrid{
      display:grid;
      grid-template-columns: 1fr 1fr;
      gap:14px;
    }
    details{
      border-radius: var(--radius);
      border:1px solid rgba(255,255,255,.12);
      background: rgba(255,255,255,.04);
      padding:14px 16px;
    }
    summary{
      cursor:pointer;
      font-weight:800;
      list-style:none;
    }
    summary::-webkit-details-marker{display:none}
    details p{margin:10px 0 0; color:var(--muted); font-size:13px}

    /* Signup form */
    .signupRow{
      display:flex;
      gap:10px;
      flex-wrap:wrap;
      align-items:center;
      margin-top:14px;
    }
    .input{
      width:min(380px, 78vw);
      padding:12px 14px;
      border-radius:999px;
      border:1px solid rgba(255,255,255,.14);
      background: rgba(255,255,255,.06);
      color: rgba(255,255,255,.92);
      outline:none;
    }
    .input::placeholder{color:rgba(255,255,255,.45)}

    /* Footer */
    .footer{
      padding:28px 0 42px;
      border-top:1px solid rgba(255,255,255,.08);
      color:rgba(255,255,255,.65);
      font-size:13px;
    }
    .footer .cols{
      display:grid;
      grid-template-columns: 1.2fr .8fr .8fr;
      gap:16px;
      margin-top:14px;
    }
    .footer a{color:rgba(255,255,255,.72)}
    .footer a:hover{color:rgba(255,255,255,.92)}
    .tiny{color:rgba(255,255,255,.55); font-size:12px}
    .divider{height:1px; background:rgba(255,255,255,.10); margin:18px 0}

    /* Responsive */
    @media (max-width: 980px){
      .heroGrid{grid-template-columns:1fr}
      .featureGrid{grid-template-columns:1fr}
      .howGrid{grid-template-columns:1fr}
      .faqGrid{grid-template-columns:1fr}
      .preview{height: 400px}
      .footer .cols{grid-template-columns:1fr}
      nav{gap:10px}
    }
  </style>
</head>

<body>

  <!-- Top Bar -->
  

  <main>

    <!-- Hero -->
    <section class="hero">
      <div class="wrap">
        <div class="heroGrid">
          <div>
            <span class="pill"><span class="dot"></span>Official relaunch planned for <strong>Spring 2026</strong></span>
            <h1 class="h1">A float plan you can actually trust —<br/>with automated monitoring.</h1>
            <p class="lead">
              FloatPlanWizard helps you build a clear, shareable float plan in minutes — then automatically watches the clock
              for check-ins and overdue status, so your people know when to act.
            </p>

            <div class="heroActions">
              <a class="btn primary" href="#signup">Get early access</a>
              <a class="btn" href="#features">See what’s included</a>
              <span class="pill" title="No spam — just a relaunch update."><span class="kbd">No spam</span> <span class="kbd">1–2 emails</span></span>
            </div>

            <div class="heroFine">
              <span>Built for boaters who want clarity.</span>
              <span>Designed for contacts who need confidence.</span>
              <span>Made for the “if something goes wrong” moment.</span>
            </div>
          </div>

          <!-- Mock app preview -->
          <div class="preview" aria-label="App preview mockup">
            <div class="previewTop">
              <div class="windowDots" aria-hidden="true"><span></span><span></span><span></span></div>
              <div class="meta">
                <span class="tag">Dashboard</span>
                <span class="tag">Monitoring</span>
                <span class="tag">Alerts</span>
              </div>
            </div>
            <div class="previewBody">
              <div class="fakeNav" aria-hidden="true">
                <span class="chip active">Active plans</span>
                <span class="chip">Drafts</span>
                <span class="chip">Contacts</span>
                <span class="chip">Vessels</span>
                <span class="chip">History</span>
              </div>

              <div class="rows" role="presentation">
                <div class="row">
                  <div>
                    <strong>Gulf Run — Clearwater ➝ Egmont</strong><br/>
                    <span>Vessel: Sea Ray 260 • Crew: 2 • Return: 6:30 PM</span>
                  </div>
                  <div>
                    <div class="status ok"><i></i> On track</div>
                    <span>Next check-in: 4:00 PM</span>
                  </div>
                  <div>
                    <div class="status ok"><i></i> Monitoring</div>
                    <span>Last ping: 12 min ago</span>
                  </div>
                </div>

                <div class="row">
                  <div>
                    <strong>Sunset Cruise — Key West</strong><br/>
                    <span>Vessel: Center Console • Crew: 3 • Return: 9:00 PM</span>
                  </div>
                  <div>
                    <div class="status warn"><i></i> Check-in due</div>
                    <span>Reminder queued</span>
                  </div>
                  <div>
                    <div class="status ok"><i></i> Monitoring</div>
                    <span>Last ping: 38 min ago</span>
                  </div>
                </div>

                <div class="row">
                  <div>
                    <strong>Overnight — Tampa Bay</strong><br/>
                    <span>Vessel: Sailboat • Crew: 2 • Return: 10:00 AM</span>
                  </div>
                  <div>
                    <div class="status danger"><i></i> Overdue</div>
                    <span>Escalation active</span>
                  </div>
                  <div>
                    <div class="status danger"><i></i> Alerts sent</div>
                    <span>Contacts notified</span>
                  </div>
                </div>
              </div>
            </div>

            <div class="ghost" aria-hidden="true">
              <h5>Relaunch roadmap</h5>
              <p>Spring 2026: refreshed UI, improved monitoring, and a cleaner “share plan” experience.</p>
              <div class="bar"><div></div></div>
            </div>
          </div>
        </div>

        <!-- Why FPW exists (FULL-WIDTH FIX) -->
        <div class="card" style="margin-top:22px">
          <div class="cardPad">
            <h3 class="cardTitle">Why FPW exists</h3>
            <p class="cardSub">
              Most float plans are scattered across texts, notes, and half-remembered details.
              FPW turns that into one structured plan — and adds the missing piece: time-based monitoring.
            </p>
            <div class="miniGrid">
              <div class="mini">
                <div class="icon" aria-hidden="true">⛵️</div>
                <div>
                  <h4>Clear plan details</h4>
                  <p>Route, vessel, crew, contacts, expected return — organized and shareable.</p>
                </div>
              </div>
              <div class="mini">
                <div class="icon" aria-hidden="true">⏱️</div>
                <div>
                  <h4>Check-in + overdue timing</h4>
                  <p>Automated milestones so you’re not relying on memory (or luck).</p>
                </div>
              </div>
              <div class="mini">
                <div class="icon" aria-hidden="true">📣</div>
                <div>
                  <h4>Actionable notifications</h4>
                  <p>When it’s time, the right people get the right message — with the plan attached.</p>
                </div>
              </div>
            </div>
          </div>
        </div>

      </div>
    </section>

    <!-- Features -->
    <section id="features">
      <div class="wrap">
        <div class="sectionHead">
          <div>
            <h2>Designed for the real-world “float plan” moment</h2>
            <p>
              A good float plan is easy to create, easy to share, and easy to act on.
              FPW focuses on clarity first — then adds automated monitoring for peace of mind.
            </p>
          </div>
        </div>

        <div class="featureGrid">
          <div class="feature">
            <div class="icon" aria-hidden="true">🧭</div>
            <h3>Structured plan builder</h3>
            <p>Route, timing, vessel details, and crew info organized into a single plan that makes sense under pressure.</p>
          </div>
          <div class="feature">
            <div class="icon" aria-hidden="true">👥</div>
            <h3>Contacts that matter</h3>
            <p>Store trusted contacts once, reuse them across trips, and ensure the right people get the right information.</p>
          </div>
          <div class="feature">
            <div class="icon" aria-hidden="true">🛰️</div>
            <h3>Monitoring that doesn’t forget</h3>
            <p>Check-ins and overdue timing are tracked automatically so follow-up doesn’t rely on someone’s memory.</p>
          </div>

          <div class="feature">
            <div class="icon" aria-hidden="true">📨</div>
            <h3>Actionable notifications</h3>
            <p>Messages include the key plan details so recipients know what to do and who to contact.</p>
          </div>
          <div class="feature">
            <div class="icon" aria-hidden="true">🧾</div>
            <h3>History and audit trail</h3>
            <p>Track what was sent, when it was sent, and to whom — so monitoring stays calm and non-spammy.</p>
          </div>
          <div class="feature">
            <div class="icon" aria-hidden="true">🔒</div>
            <h3>Built with safety in mind</h3>
            <p>Clear presentation, predictable behavior, and minimal “fiddly” settings when it matters most.</p>
          </div>
        </div>
      </div>
    </section>

    <!-- How it works -->
    <section id="how">
      <div class="wrap">
        <div class="sectionHead">
          <div>
            <h2>How it works</h2>
            <p>Keep it simple: build the plan, share it, and let monitoring do the time-based follow-up.</p>
          </div>
        </div>

        <div class="howGrid">
          <div class="step">
            <div class="num">1</div>
            <div>
              <h4>Create a float plan</h4>
              <p>Add vessel, crew, route, and timing details. Save templates for recurring trips.</p>
            </div>
          </div>
          <div class="step">
            <div class="num">2</div>
            <div>
              <h4>Choose check-in points</h4>
              <p>Set expected check-ins and return time. Keep it realistic and easy for contacts to follow.</p>
            </div>
          </div>
          <div class="step">
            <div class="num">3</div>
            <div>
              <h4>Share the plan</h4>
              <p>Send to trusted contacts with a clear summary and instructions — no guessing required.</p>
            </div>
          </div>
          <div class="step">
            <div class="num">4</div>
            <div>
              <h4>Monitoring runs automatically</h4>
              <p>If a check-in is missed or return time passes, notifications go out according to your rules.</p>
            </div>
          </div>
        </div>

        <div class="cta" style="margin-top:16px">
          <div>
            <h3>Spring 2026 relaunch</h3>
            <p>
              FPW is being refreshed with an updated homepage, cleaner onboarding, and improved monitoring reliability.
              Join the early-access list to get the relaunch update when it’s ready.
            </p>
          </div>
          <div style="display:flex;gap:12px;flex-wrap:wrap">
            <a class="btn primary" href="#signup">Get early access</a>
            <a class="btn" href="#monitoring">See monitoring details</a>
          </div>
        </div>
      </div>
    </section>

    <!-- Monitoring details -->
    <section id="monitoring">
      <div class="wrap">
        <div class="sectionHead">
          <div>
            <h2>Monitoring that stays calm, clear, and consistent</h2>
            <p>
              FPW is designed to alert without spamming. It logs notifications and follows predictable rules
              so your contacts can trust what they receive.
            </p>
          </div>
        </div>

        <div class="featureGrid">
          <div class="feature">
            <div class="icon" aria-hidden="true">🕒</div>
            <h3>Time-based states</h3>
            <p>On track → Check-in due → Overdue — with clear thresholds you can adjust per plan.</p>
          </div>
          <div class="feature">
            <div class="icon" aria-hidden="true">🧯</div>
            <h3>Escalation-ready messaging</h3>
            <p>Overdue notifications include plan details for faster decision-making and next steps.</p>
          </div>
          <div class="feature">
            <div class="icon" aria-hidden="true">🧠</div>
            <h3>Dedupe + logging</h3>
            <p>Each message is recorded so the system doesn’t re-send the same alert over and over.</p>
          </div>
        </div>
      </div>
    </section>

    <!-- FAQ -->
    <section id="faq">
      <div class="wrap">
        <div class="sectionHead">
          <div>
            <h2>FAQ</h2>
            <p>Simple answers now. We’ll expand this as the relaunch gets closer.</p>
          </div>
        </div>

        <div class="faqGrid">
          <details>
            <summary>Is FPW live today?</summary>
            <p>FPW is actively being improved for a more official relaunch in <strong>Spring 2026</strong>.</p>
          </details>
          <details>
            <summary>Who is FPW for?</summary>
            <p>Boaters who want a clear float plan, and the people who need to know what to do if something goes wrong.</p>
          </details>
          <details>
            <summary>What does “monitoring” mean?</summary>
            <p>FPW tracks check-in timing and overdue status automatically and sends notifications based on those thresholds.</p>
          </details>
          <details>
            <summary>Will this support SMS or push notifications?</summary>
            <p>Email is the baseline. Additional notification channels can be added as the relaunch approaches.</p>
          </details>
        </div>
      </div>
    </section>

    <!-- Signup -->
    <section id="signup">
      <div class="wrap">
        <div class="card">
          <div class="cardPad" style="display:flex; gap:18px; align-items:center; justify-content:space-between; flex-wrap:wrap;">
            <div>
              <h2 style="margin:0 0 8px; font-size:22px; letter-spacing:-.2px;">Get the Spring 2026 relaunch update</h2>
              <p style="margin:0; color:var(--muted); max-width:72ch;">
                Add your email to get notified when early access opens. (This is a mockup form — wire it up later.)
              </p>
              <div class="signupRow">
                <input class="input" type="email" placeholder="you@example.com" />
                <button class="btn primary" type="button">Notify me</button>
              </div>
              <div class="tiny" style="margin-top:10px">No spam. Unsubscribe any time.</div>
            </div>

            <div class="pill" style="align-self:flex-start">
              <span class="dot"></span>
              <span><strong>Spring 2026</strong> • Relaunch timeline</span>
            </div>
          </div>
        </div>
      </div>
    </section>

    <!-- Footer -->
    <footer class="footer">
      <div class="wrap">
        <div style="display:flex; align-items:center; justify-content:space-between; gap:12px; flex-wrap:wrap;">
          <div class="brand">
            <div class="logo" aria-hidden="true"></div>
            <div>
              <div style="font-weight:800">FloatPlanWizard</div>
              <div class="tiny">Spring 2026 relaunch</div>
            </div>
          </div>
          <div class="tiny">© <span id="y"></span> FloatPlanWizard. All rights reserved.</div>
        </div>

        <div class="divider"></div>

        <div class="cols">
          <div>
            <div style="font-weight:800; margin-bottom:8px;">Product</div>
            <div class="tiny" style="display:grid; gap:6px;">
              <a href="#features">Features</a>
              <a href="#monitoring">Monitoring</a>
              <a href="#how">How it works</a>
            </div>
          </div>
          <div>
            <div style="font-weight:800; margin-bottom:8px;">Company</div>
            <div class="tiny" style="display:grid; gap:6px;">
              <a href="#signup">Early access</a>
              <a href="#faq">FAQ</a>
            </div>
          </div>
          <div>
            <div style="font-weight:800; margin-bottom:8px;">Notes</div>
            <div class="tiny" style="display:grid; gap:6px;">
              <div>Mockup: HTML + CSS only</div>
              <div>Next: wire to CFML + API</div>
              <div>Then: add screenshots + real copy</div>
            </div>
          </div>
        </div>
      </div>
    </footer>

  </main>

  <script>
    document.getElementById('y').textContent = new Date().getFullYear();
  </script>
<cfinclude template="includes/footer_scripts.cfm">
<script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/app/core.js"></script>
</body>
</html>
