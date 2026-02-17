<cfsetting showdebugoutput="false" requesttimeout="30">

<cfscript>
/**
 * FPW Pre-Launch Early Access Modal + Signup (single-page, self-contained)
 * Compatibility:
 * - No `var` declarations outside functions
 * - No array.filter() usage
 * - No cfheader statustext
 */

dsn = "";
try {
  if (isDefined("application") && structKeyExists(application, "dsn")) {
    dsn = application.dsn;
  }
} catch(any e) {}
if (!len(dsn)) {
  dsn = "FPW"; // fallback
}

function jsonOut(required struct payload, numeric statusCode=200){
  cfheader(statuscode=statusCode);
  cfcontent(type="application/json; charset=utf-8", reset=true);
  writeOutput(serializeJSON(payload));
  abort;
}

function normalizeEmail(required string s){
  var e = trim(lcase(s));
  e = reReplace(e, "\s+", "", "all");
  return e;
}

function isValidEmailBasic(required string e){
  if (len(e) < 6 || len(e) > 254) return false;
  return reFind("^[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}$", ucase(e)) > 0;
}

// Decide whether this request is the AJAX signup POST
isAjaxSignup = (structKeyExists(cgi,"request_method") && cgi.request_method == "POST"
  && structKeyExists(form, "action") && form.action == "earlyAccessSignup");

if (isAjaxSignup) {

  // ---- Rate limiting (session-based) ----
  if (!structKeyExists(session, "eaAttempts") || !isArray(session.eaAttempts)) {
    session.eaAttempts = [];
  }

  nowTs = now(); // NOTE: no `var` at top-level

  // prune attempts older than 60 minutes
  pruned = [];
  i = 1;
  while (i <= arrayLen(session.eaAttempts)) {
    try {
      if (dateDiff("n", session.eaAttempts[i], nowTs) <= 60) {
        arrayAppend(pruned, session.eaAttempts[i]);
      }
    } catch(any ignore) {}
    i++;
  }
  session.eaAttempts = pruned;

  if (arrayLen(session.eaAttempts) >= 5) {
    jsonOut({ "success": false, "message": "Too many attempts. Please try again later." }, 429);
  }

  // ---- Honeypot ----
  hp = "";
  if (structKeyExists(form, "company")) hp = trim(form.company);
  if (len(hp)) {
    // pretend success to bots; don't store
    jsonOut({ "success": true, "message": "You're on the list. We'll be in touch soon." }, 200);
  }

  // ---- Validate email ----
  rawEmail = structKeyExists(form, "email") ? form.email : "";
  email = normalizeEmail(rawEmail);

  if (!isValidEmailBasic(email)) {
    jsonOut({ "success": false, "message": "Please enter a valid email address." }, 400);
  }

  // ---- Capture metadata ----
  source = structKeyExists(form, "source") ? left(trim(form.source), 80) : "homepage";
  referrer = left((structKeyExists(cgi,"http_referer") ? cgi.http_referer : ""), 255);
  ipAddr = left((structKeyExists(cgi,"remote_addr") ? cgi.remote_addr : ""), 45);
  ua = left((structKeyExists(cgi,"http_user_agent") ? cgi.http_user_agent : ""), 255);

  // record attempt
  arrayAppend(session.eaAttempts, nowTs);

  // ---- Insert / de-dupe ----
  try {
    queryExecute(
      "
      INSERT INTO fpw_early_access (email, source, referrer, ip_address, user_agent, status)
      VALUES (:email, :source, :referrer, :ip, :ua, 'active')
      ON DUPLICATE KEY UPDATE
        source = VALUES(source),
        referrer = VALUES(referrer),
        ip_address = VALUES(ip_address),
        user_agent = VALUES(user_agent),
        status = 'active',
        updated_at = CURRENT_TIMESTAMP
      ",
      {
        email   : { value=email, cfsqltype="cf_sql_varchar" },
        source  : { value=source, cfsqltype="cf_sql_varchar" },
        referrer: { value=referrer, cfsqltype="cf_sql_varchar" },
        ip      : { value=ipAddr, cfsqltype="cf_sql_varchar" },
        ua      : { value=ua, cfsqltype="cf_sql_varchar" }
      },
      { datasource = dsn }
    );

    jsonOut({ "success": true, "message": "You're on the early access list. We'll email you when it’s ready." }, 200);

  } catch(any e) {
    jsonOut({ "success": false, "message": "Sorry — something went wrong saving your email. Please try again." }, 500);
  }
}
</cfscript>

<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>FloatPlanWizard — Pre-Launch</title>

<style>
:root{
  --bg:#0b1220;
  --panel:rgba(255,255,255,.05);
  --panel2:rgba(255,255,255,.08);
  --line:rgba(255,255,255,.10);
  --text:rgba(255,255,255,.92);
  --muted:rgba(255,255,255,.65);
  --brand:#2dd4bf;
  --danger:#ef4444;
  --ok:#22c55e;
}

*{box-sizing:border-box;}
body{
  margin:0;
  font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Arial,sans-serif;
  background:var(--bg);
  color:var(--text);
}

.container{
  max-width:1200px;
  margin:auto;
  padding:60px 24px;
}

/* NAV */
.nav{
  display:flex;
  justify-content:space-between;
  align-items:center;
  padding:20px 24px;
  border-bottom:1px solid var(--line);
  backdrop-filter:blur(10px);
}
.nav-logo{
  font-size:20px;
  font-weight:800;
  letter-spacing:.5px;
}
.nav-cta{
  background:var(--brand);
  color:#00110e;
  padding:10px 18px;
  border-radius:12px;
  font-weight:900;
  text-decoration:none;
  border:1px solid rgba(0,0,0,.12);
}

/* HERO */
.hero{
  text-align:center;
  padding:90px 20px 70px;
}
.hero h1{
  font-size:46px;
  margin:0 0 18px;
  letter-spacing:.2px;
}
.hero p{
  font-size:20px;
  color:var(--muted);
  max-width:820px;
  margin:0 auto 26px;
  line-height:1.45;
}
.hero-buttons a{
  display:inline-block;
  margin:8px;
  padding:14px 22px;
  border-radius:12px;
  text-decoration:none;
  font-weight:900;
}
.primary{
  background:var(--brand);
  color:#00110e;
  border:1px solid rgba(0,0,0,.12);
}
.secondary{
  border:1px solid var(--line);
  color:var(--text);
  background:rgba(255,255,255,.02);
}

/* FEATURE GRID */
.grid{
  display:grid;
  grid-template-columns:repeat(auto-fit,minmax(280px,1fr));
  gap:20px;
}
.card{
  background:var(--panel);
  border:1px solid var(--line);
  border-radius:16px;
  padding:22px;
  transition:.25s ease;
}
.card:hover{
  background:var(--panel2);
  transform:translateY(-3px);
}
.card h3{
  margin:0 0 10px;
  color:var(--brand);
  font-size:18px;
}
.card p{
  margin:0;
  color:var(--muted);
  line-height:1.5;
}

.section-title{
  text-align:center;
  font-size:30px;
  margin:0 0 42px;
}

/* MISSION PANEL */
.mission{
  background:linear-gradient(145deg,var(--panel),var(--panel2));
  border:1px solid var(--line);
  border-radius:18px;
  padding:34px;
  text-align:center;
}
.mission h2{
  font-size:34px;
  margin:0 0 14px;
}
.mission p{
  color:var(--muted);
  font-size:18px;
  margin:0;
  line-height:1.55;
}

/* FOOTER */
.footer{
  text-align:center;
  padding:46px 20px;
  border-top:1px solid var(--line);
  color:var(--muted);
  font-size:14px;
}

/* -------- Modal -------- */
.fpw-modal-backdrop{
  position:fixed;
  inset:0;
  background:rgba(0,0,0,.62);
  display:none;
  align-items:center;
  justify-content:center;
  padding:24px;
  z-index:9999;
}
.fpw-modal-backdrop.is-open{ display:flex; }

.fpw-modal{
  width:min(560px, 100%);
  background:linear-gradient(180deg, rgba(255,255,255,.08), rgba(255,255,255,.04));
  border:1px solid rgba(255,255,255,.14);
  border-radius:18px;
  box-shadow:0 20px 60px rgba(0,0,0,.55);
  overflow:hidden;
}

.fpw-modal__top{
  padding:18px 18px 14px;
  border-bottom:1px solid rgba(255,255,255,.10);
  display:flex;
  align-items:flex-start;
  justify-content:space-between;
  gap:14px;
}
.fpw-modal__title{
  font-weight:900;
  font-size:18px;
  letter-spacing:.3px;
}
.fpw-modal__subtitle{
  margin-top:6px;
  color:var(--muted);
  font-size:14px;
  line-height:1.4;
}
.fpw-modal__close{
  border:1px solid rgba(255,255,255,.14);
  background:rgba(0,0,0,.18);
  color:var(--text);
  border-radius:12px;
  width:38px;
  height:38px;
  cursor:pointer;
  font-size:18px;
  line-height:36px;
  text-align:center;
}

.fpw-modal__body{
  padding:18px;
}
.fpw-field{ margin:10px 0 14px; }
.fpw-label{
  display:block;
  font-size:12px;
  color:var(--muted);
  margin-bottom:6px;
}
.fpw-input{
  width:100%;
  padding:13px 14px;
  border-radius:12px;
  border:1px solid rgba(255,255,255,.14);
  background:rgba(0,0,0,.20);
  color:var(--text);
  outline:none;
}
.fpw-input:focus{
  border-color:rgba(45,212,191,.55);
  box-shadow:0 0 0 3px rgba(45,212,191,.12);
}
.fpw-hint{
  font-size:12px;
  color:rgba(255,255,255,.55);
  margin-top:6px;
}

.fpw-modal__actions{
  display:flex;
  gap:10px;
  margin-top:14px;
}
.fpw-btn{
  flex:1;
  border-radius:12px;
  padding:12px 14px;
  cursor:pointer;
  font-weight:900;
  border:1px solid rgba(255,255,255,.14);
  background:rgba(255,255,255,.04);
  color:var(--text);
}
.fpw-btn--primary{
  background:var(--brand);
  color:#00110e;
  border-color:rgba(0,0,0,.12);
}
.fpw-btn[disabled]{ opacity:.65; cursor:not-allowed; }

.fpw-alert{
  display:none;
  margin-top:12px;
  padding:12px;
  border-radius:12px;
  border:1px solid rgba(255,255,255,.14);
  background:rgba(0,0,0,.18);
  color:var(--muted);
}
.fpw-alert.is-show{ display:block; }
.fpw-alert.is-ok{
  border-color:rgba(34,197,94,.35);
  background:rgba(34,197,94,.10);
  color:rgba(255,255,255,.92);
}
.fpw-alert.is-bad{
  border-color:rgba(239,68,68,.35);
  background:rgba(239,68,68,.10);
  color:rgba(255,255,255,.92);
}

/* honeypot hidden */
.fpw-hp{
  position:absolute !important;
  left:-9999px !important;
  width:1px !important;
  height:1px !important;
  overflow:hidden !important;
}
</style>
</head>

<body>

<div class="nav">
  <div class="nav-logo">FloatPlanWizard</div>
  <a href="##" class="nav-cta" data-ea-open data-ea-source="nav">Join Pre-Launch</a>
</div>

<section class="hero">
  <h1>Before You Leave the Dock,<br>Activate Mission Control.</h1>
  <p>
    FloatPlanWizard is a complete cruise management system for serious boaters.
    Plan routes, automate check-ins, monitor weather, and keep your family and crew informed —
    so someone always knows where you are.
  </p>
  <div class="hero-buttons">
    <a href="##" class="primary" data-ea-open data-ea-source="hero_primary">Request Early Access</a>
    <a href="##" class="secondary" data-ea-open data-ea-source="hero_secondary">See How It Works</a>
  </div>
</section>

<section class="container">
  <h2 class="section-title">Everything You Need To Cruise Smarter</h2>
  <div class="grid">
    <div class="card"><h3>Route Intelligence</h3><p>Create structured multi-leg routes in minutes. Generate a cruise plan you can edit leg-by-leg — built for real trips.</p></div>
    <div class="card"><h3>Automated Check-In Monitoring</h3><p>Schedule confirmations. Miss a check-in and your contacts are notified automatically — no more “forgot to text.”</p></div>
    <div class="card"><h3>Family “In The Loop” Dashboard</h3><p>Private access for your chosen contacts so they can see trip status, ETAs, and your latest updates.</p></div>
    <div class="card"><h3>Weather Awareness</h3><p>Marine weather built into the workflow — visibility per day and per leg so you can make safer go/no-go decisions.</p></div>
    <div class="card"><h3>Overdue Escalation Logic</h3><p>Define who gets notified and when. Escalation timing is automatic so your plan never sits ignored.</p></div>
    <div class="card"><h3>Captain Dashboard</h3><p>A cockpit-style mission console: alerts, trip timeline, route legs, and monitoring status at a glance.</p></div>
  </div>
</section>

<section class="container">
  <div class="mission">
    <h2>This Is More Than A Float Plan.</h2>
    <p>
      It’s a private cruise management platform for your boat.
      Whether you’re running the Great Loop, crossing the Gulf, or cruising your local coast —
      FloatPlanWizard keeps your people “in the loop” automatically so you can focus on the water.
    </p>
  </div>
</section>

<section class="container">
  <h2 class="section-title">Launching Spring 2026</h2>
  <div class="mission">
    <p>Join the early access list to get priority onboarding and founder pricing.</p>
    <br>
    <a href="##" class="primary" data-ea-open data-ea-source="launch_section">Get On The List</a>
  </div>
</section>

<div class="footer">
  © 2026 FloatPlanWizard · Built for boaters who cruise beyond the horizon.
</div>

<!-- Early Access Modal -->
<div class="fpw-modal-backdrop" id="eaBackdrop" role="dialog" aria-modal="true" aria-labelledby="eaTitle">
  <div class="fpw-modal">
    <div class="fpw-modal__top">
      <div>
        <div class="fpw-modal__title" id="eaTitle">Early Access — Launch Updates</div>
        <div class="fpw-modal__subtitle">Get notified when FPW opens early access. We’ll only email you about launch and onboarding.</div>
      </div>
      <button class="fpw-modal__close" type="button" id="eaCloseBtn" aria-label="Close">×</button>
    </div>
    <div class="fpw-modal__body">
      <form id="eaForm" autocomplete="on">
        <input type="hidden" name="action" value="earlyAccessSignup">
        <input type="hidden" name="source" id="eaSource" value="homepage">
        <div class="fpw-hp">
          <label>Company</label>
          <input type="text" name="company" tabindex="-1" autocomplete="off" />
        </div>

        <div class="fpw-field">
          <label class="fpw-label" for="eaEmail">Email address</label>
          <input class="fpw-input" id="eaEmail" name="email" type="email" inputmode="email" placeholder="you@example.com" required>
          <div class="fpw-hint">Use the email where you want launch + onboarding updates.</div>
        </div>

        <div class="fpw-modal__actions">
          <button class="fpw-btn" type="button" id="eaCancel">Not Now</button>
          <button class="fpw-btn fpw-btn--primary" type="submit" id="eaSubmit">Notify Me</button>
        </div>

        <div class="fpw-alert" id="eaAlert"></div>
      </form>
    </div>
  </div>
</div>

<script>
(function(){
  const backdrop = document.getElementById('eaBackdrop');
  const closeBtn = document.getElementById('eaCloseBtn');
  const cancelBtn = document.getElementById('eaCancel');
  const form = document.getElementById('eaForm');
  const emailEl = document.getElementById('eaEmail');
  const alertEl = document.getElementById('eaAlert');
  const submitBtn = document.getElementById('eaSubmit');
  const sourceEl = document.getElementById('eaSource');

  function showAlert(type, msg){
    alertEl.className = 'fpw-alert is-show ' + (type === 'ok' ? 'is-ok' : (type === 'bad' ? 'is-bad' : ''));
    alertEl.textContent = msg;
  }
  function clearAlert(){
    alertEl.className = 'fpw-alert';
    alertEl.textContent = '';
  }
  function openModal(source){
    clearAlert();
    sourceEl.value = source || 'homepage';
    backdrop.classList.add('is-open');
    setTimeout(function(){ try { emailEl.focus(); } catch(e){} }, 50);
  }
  function closeModal(){
    backdrop.classList.remove('is-open');
  }

  document.querySelectorAll('[data-ea-open]').forEach(function(el){
    el.addEventListener('click', function(ev){
      ev.preventDefault();
      openModal(el.getAttribute('data-ea-source') || 'homepage');
    });
  });

  closeBtn.addEventListener('click', closeModal);
  cancelBtn.addEventListener('click', closeModal);

  backdrop.addEventListener('click', function(ev){
    if (ev.target === backdrop) closeModal();
  });

  document.addEventListener('keydown', function(ev){
    if (ev.key === 'Escape' && backdrop.classList.contains('is-open')) closeModal();
  });

  form.addEventListener('submit', function(ev){
    ev.preventDefault();
    clearAlert();

    const email = (emailEl.value || '').trim();
    if (!email) { showAlert('bad', 'Please enter your email.'); return; }

    submitBtn.disabled = true;
    const oldText = submitBtn.textContent;
    submitBtn.textContent = 'Saving…';

    const fd = new FormData(form);

    fetch(window.location.href, {
      method: 'POST',
      headers: { 'X-Requested-With': 'XMLHttpRequest' },
      body: fd
    })
    .then(function(res){
      return res.json().then(function(data){ return { ok: res.ok, data: data }; })
      .catch(function(){ return { ok: false, data: null }; });
    })
    .then(function(r){
      if (!r.ok || !r.data) {
        showAlert('bad', 'Sorry — something went wrong. Please try again.');
      } else if (r.data.success) {
        showAlert('ok', r.data.message || "You're on the list!");
        setTimeout(function(){ closeModal(); }, 1200);
      } else {
        showAlert('bad', r.data.message || 'Please check your email and try again.');
      }
    })
    .catch(function(){
      showAlert('bad', 'Network error. Please try again.');
    })
    .finally(function(){
      submitBtn.disabled = false;
      submitBtn.textContent = oldText;
    });
  });
})();
</script>

</body>
</html>
