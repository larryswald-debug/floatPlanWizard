<!-- /includes/top_nav.cfm -->
<cfscript>
userDisplayName = "";
if (structKeyExists(session, "user") && isStruct(session.user)) {
  firstName = "";
  lastName = "";
  if (structKeyExists(session.user, "firstName")) {
    firstName = session.user.firstName;
  } else if (structKeyExists(session.user, "FIRSTNAME")) {
    firstName = session.user.FIRSTNAME;
  } else if (structKeyExists(session.user, "fName")) {
    firstName = session.user.fName;
  } else if (structKeyExists(session.user, "FNAME")) {
    firstName = session.user.FNAME;
  }

  if (structKeyExists(session.user, "lastName")) {
    lastName = session.user.lastName;
  } else if (structKeyExists(session.user, "LASTNAME")) {
    lastName = session.user.LASTNAME;
  } else if (structKeyExists(session.user, "lName")) {
    lastName = session.user.lName;
  } else if (structKeyExists(session.user, "LNAME")) {
    lastName = session.user.LNAME;
  }

  userDisplayName = trim(firstName & " " & lastName);

  if (!len(userDisplayName)) {
    if (structKeyExists(session.user, "email")) {
      userDisplayName = session.user.email;
    } else if (structKeyExists(session.user, "EMAIL")) {
      userDisplayName = session.user.EMAIL;
    }
  }
}
basePath = "";
if (structKeyExists(request, "fpwBase")) {
  basePath = request.fpwBase;
}
</cfscript>

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
  .nav--public{ display:block; }
  .nav--app{ display:block; }
  body.is-logged-in .nav--public,
  body.is-logged-in .loginStrip{ display:none; }
  body.is-logged-in .nav--app{ display:block; }

  /* ===== Shell ===== */
  .topbar{
    position:sticky;
    top:0;
    z-index:1050;
    background:
      radial-gradient(1200px 90px at 10% 0%, rgba(53,208,200,.18), transparent 55%),
      radial-gradient(900px 110px at 85% 10%, rgba(74,163,255,.16), transparent 60%),
      linear-gradient(180deg, var(--bg0), var(--bg1));
    border-bottom:1px solid var(--line);
  }
  .topbar.nav--public,
  .topbar.nav--app{
    position:sticky !important;
    top:0 !important;
    z-index:1051 !important;
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
  section.loginStrip{
    position:fixed;
    left:0;
    right:0;
    top:0;
    z-index:1040;
    display:block !important;
    background:
      radial-gradient(1200px 90px at 10% 0%, rgba(53,208,200,.18), transparent 55%),
      radial-gradient(900px 110px at 85% 10%, rgba(74,163,255,.16), transparent 60%),
      linear-gradient(180deg, var(--bg0), var(--bg1));
    border-bottom:1px solid var(--line);
    padding-top:2px !important;
    padding-bottom:2px !important;
    transform:translate3d(0, calc(-100% - 8px), 0);
    pointer-events:none;
    transition:transform .4s ease;
    will-change:transform;
    backface-visibility:hidden;
  }
  section.loginStrip.is-open{
    transform:translate3d(0, var(--login-open-offset, 0px), 0);
    pointer-events:auto;
  }
  .loginInner{
    max-width:1200px;
    margin:0 auto;
    padding:2px 16px;
    display:flex;
    align-items:center;
    justify-content:flex-end;
    gap:10px;
    flex-wrap:wrap;
  }
  #loginForm{
    display:flex;
    align-items:center;
    gap:6px;
    flex-wrap:nowrap;
    margin:0;
  }
  #loginForm .field{
    margin:0;
    width:228px;
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
  #loginForm .input{
    width:100% !important;
    min-width:0 !important;
    padding:5px 6px;
    border-radius:6px;
    font-size:0.75rem;
  }
  #loginButton{
    border-color: rgba(53,208,200,.35) !important;
    background: linear-gradient(135deg, rgba(53,208,200,.95), rgba(74,163,255,.75)) !important;
    color:#021018 !important;
    padding:5px 7px !important;
    border-radius:6px !important;
    font-size:0.75rem !important;
  }
  #loginAlert{
    flex:0 0 auto;
    margin:0 8px 0 0;
    text-align:left;
    white-space:nowrap;
  }
  #loginAlert.alert{
    margin-bottom:0;
    padding:4px 8px;
    font-size:0.75rem;
    line-height:1.2;
  }
  #loginAlert.d-none{
    display:none !important;
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
  .fpwHamburger{
    display:none;
    font-size:1.05rem;
    font-weight:900;
    line-height:1;
  }
  .fpwHamburgerIcon--close{
    display:none;
  }
  .fpwHamburger[aria-expanded="true"] .fpwHamburgerIcon--open{
    display:none;
  }
  .fpwHamburger[aria-expanded="true"] .fpwHamburgerIcon--close{
    display:inline;
  }
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
  .fpwMobileBackdrop{
    display:none;
    position:fixed;
    inset:0;
    background:rgba(0,0,0,.45);
    z-index:1048;
  }
  .fpwMobileMenu{
    display:none;
    position:fixed;
    left:12px;
    right:12px;
    top:72px;
    max-height:calc(100vh - 84px);
    overflow:auto;
    background: var(--panel);
    border:1px solid rgba(255,255,255,.08);
    border-radius: var(--radius);
    box-shadow: var(--shadow);
    padding:8px;
    z-index:1049;
  }
  .fpwMobileMenu a,
  .fpwMobileMenu button{
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
  .fpwMobileMenu a:hover,
  .fpwMobileMenu button:hover{
    background: rgba(255,255,255,.06);
    color: rgba(255,255,255,.95);
  }
  .fpwMobileMenu hr{
    border:0;
    border-top:1px solid rgba(255,255,255,.08);
    margin:8px 0;
  }
  .fpwMobileSection{
    padding:6px 10px;
    color:var(--muted);
    font-size:.74rem;
    font-weight:900;
    letter-spacing:.08em;
    text-transform:uppercase;
  }
  body.fpwMobileNavOpen{
    overflow:hidden;
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
    .tabs{ display:none; }
    .brand{ min-width:auto; }
    .actions > :not(.fpwHamburger){ display:none !important; }
    .fpwHamburger{ display:inline-flex; }
    .fpwMobileBackdrop.is-open{ display:block; }
    .fpwMobileMenu.is-open{ display:block; }
    .input{ min-width: 180px; }
    #loginForm{
      flex-wrap:wrap;
      justify-content:flex-end;
    }
    #loginAlert{
      flex:0 0 100%;
      margin:4px 0 0;
      text-align:right;
    }
    #loginForm .field{ width:136px; }
  }
</style>

<cfif len(userDisplayName)>
  <header class="topbar nav--app" role="banner">
    <div class="inner">
      <a class="brand brandCompact" href="<cfoutput>#basePath#</cfoutput>/app/dashboard.cfm" aria-label="Dashboard">
        <span class="logo" aria-hidden="true"></span>
        <span>
          <div class="brandTitle">FPW</div>
        </span>
      </a>

      <nav class="tabs" aria-label="App Primary">
        <a class="tab active" href="<cfoutput>#basePath#</cfoutput>/app/dashboard.cfm">Dashboard</a>
        <a class="tab" href="#monitoring">Monitoring</a>
        <a class="tab" id="fpwNavWeatherLink" href="<cfoutput>#basePath#</cfoutput>/app/dashboard.cfm#weather">Weather</a>
      </nav>

      <div class="actions">
        <button class="iconBtn" type="button" aria-label="Alerts" title="Alerts">
          🔔
          <span class="badge">3</span>
        </button>

        <span class="divider" aria-hidden="true"></span>

        <details class="dd">
          <summary class="btn btnPrimary">+ New</summary>
          <div class="menu" role="menu" aria-label="New menu">
            <a id="fpwNavNewRouteLink" href="<cfoutput>#basePath#</cfoutput>/app/dashboard.cfm">🗺️ New Route</a>
            <a id="fpwNavNewFloatPlanLink" href="<cfoutput>#basePath#</cfoutput>/app/dashboard.cfm">📄 New Float Plan</a>
            <hr />
            <a href="#invite">👥 Invite Follower</a>
          </div>
        </details>

        <details class="dd">
          <summary class="btn"><cfoutput>#encodeForHTML(userDisplayName)#</cfoutput></summary>
          <div class="menu" role="menu" aria-label="User menu">
            <a href="<cfoutput>#basePath#</cfoutput>/app/account.cfm">👤 Account</a>
            <a href="<cfoutput>#basePath#</cfoutput>/app/account.cfm">⚙️ Settings</a>
            <hr />
            <button id="logoutButton" type="button">🚪 Log out</button>
          </div>
        </details>

        <button class="iconBtn fpwHamburger" type="button" id="fpwAppMobileToggle" aria-controls="fpwMobileMenuApp" aria-expanded="false" aria-label="Toggle menu">
          <span class="fpwHamburgerIcon fpwHamburgerIcon--open" aria-hidden="true">☰</span>
          <span class="fpwHamburgerIcon fpwHamburgerIcon--close" aria-hidden="true">✕</span>
        </button>
      </div>
    </div>
  </header>

  <div class="fpwMobileBackdrop fpwMobileBackdrop--app" id="fpwMobileBackdropApp" aria-hidden="true"></div>
  <nav class="fpwMobileMenu fpwMobileMenu--app" id="fpwMobileMenuApp" role="navigation" aria-label="Mobile app menu" aria-hidden="true">
    <a href="<cfoutput>#basePath#</cfoutput>/app/dashboard.cfm">Dashboard</a>
    <a href="#monitoring">Monitoring</a>
    <a id="fpwMobileWeatherLink" href="<cfoutput>#basePath#</cfoutput>/app/dashboard.cfm#weather">Weather</a>
    <hr />
    <div class="fpwMobileSection">+ New</div>
    <button type="button" id="fpwMobileNewRouteBtn">🗺️ New Route</button>
    <button type="button" id="fpwMobileNewFloatPlanBtn">📄 New Float Plan</button>
    <a href="#invite">👥 Invite Follower</a>
    <hr />
    <div class="fpwMobileSection">Account</div>
    <a href="<cfoutput>#basePath#</cfoutput>/app/account.cfm">👤 Account</a>
    <a href="<cfoutput>#basePath#</cfoutput>/app/account.cfm">⚙️ Settings</a>
    <button type="button" id="fpwMobileLogoutBtn">🚪 Log out</button>
  </nav>

  <script>
    (function () {
      function initNavNewRouteLink() {
        var newRouteLink = document.getElementById("fpwNavNewRouteLink");
        var newFloatPlanLink = document.getElementById("fpwNavNewFloatPlanLink");
        var weatherLinks = document.querySelectorAll("#fpwNavWeatherLink, #fpwMobileWeatherLink");
        var appMobileToggle = document.getElementById("fpwAppMobileToggle");
        var appMobileMenu = document.getElementById("fpwMobileMenuApp");
        var appMobileBackdrop = document.getElementById("fpwMobileBackdropApp");
        var mobileNewRouteBtn = document.getElementById("fpwMobileNewRouteBtn");
        var mobileNewFloatPlanBtn = document.getElementById("fpwMobileNewFloatPlanBtn");
        var mobileLogoutBtn = document.getElementById("fpwMobileLogoutBtn");
        var appTopbar = document.querySelector(".topbar.nav--app");

        function openWeatherPanel() {
          var weatherCard = document.querySelector(".fpw-card.fpw-alerts");
          var weatherCollapse = document.getElementById("alertsCollapse");
          var navHeight = appTopbar ? Math.round(appTopbar.getBoundingClientRect().height) : 0;
          var topGap = 22;

          if (weatherCollapse) {
            if (window.bootstrap && window.bootstrap.Collapse) {
              window.bootstrap.Collapse.getOrCreateInstance(weatherCollapse, { toggle: false }).show();
            } else {
              weatherCollapse.classList.add("show");
            }
          }

          if (weatherCard && typeof weatherCard.getBoundingClientRect === "function") {
            window.requestAnimationFrame(function () {
              var top = weatherCard.getBoundingClientRect().top + window.pageYOffset - navHeight - topGap;
              window.scrollTo({
                top: Math.max(0, Math.round(top)),
                behavior: "smooth"
              });
            });
          }

          return !!(weatherCard || weatherCollapse);
        }

        function syncAppMobileMenuTop() {
          if (!appTopbar || !appMobileMenu) return;
          var rect = appTopbar.getBoundingClientRect();
          var top = Math.max(0, Math.round(rect.bottom) + 8);
          appMobileMenu.style.top = top + "px";
          appMobileMenu.style.maxHeight = "calc(100vh - " + (top + 12) + "px)";
        }

        function setAppMobileOpen(isOpen) {
          if (!appMobileMenu || !appMobileBackdrop || !appMobileToggle) return;
          syncAppMobileMenuTop();
          if (isOpen) {
            appMobileMenu.classList.add("is-open");
            appMobileBackdrop.classList.add("is-open");
            appMobileMenu.setAttribute("aria-hidden", "false");
            appMobileToggle.setAttribute("aria-expanded", "true");
            document.body.classList.add("fpwMobileNavOpen");
          } else {
            appMobileMenu.classList.remove("is-open");
            appMobileBackdrop.classList.remove("is-open");
            appMobileMenu.setAttribute("aria-hidden", "true");
            appMobileToggle.setAttribute("aria-expanded", "false");
            document.body.classList.remove("fpwMobileNavOpen");
          }
        }

        if (appMobileToggle) {
          appMobileToggle.addEventListener("click", function (event) {
            event.preventDefault();
            setAppMobileOpen(!appMobileMenu || !appMobileMenu.classList.contains("is-open"));
          });
        }
        if (appMobileBackdrop) {
          appMobileBackdrop.addEventListener("click", function () {
            setAppMobileOpen(false);
          });
        }
        if (appMobileMenu) {
          appMobileMenu.addEventListener("click", function (event) {
            if (event.target.closest("a,button")) {
              setAppMobileOpen(false);
            }
          });
        }
        document.addEventListener("keydown", function (event) {
          if (event.key === "Escape") {
            setAppMobileOpen(false);
          }
        });
        window.addEventListener("resize", function () {
          syncAppMobileMenuTop();
          if (window.innerWidth > 980) {
            setAppMobileOpen(false);
          }
        });

        Array.prototype.forEach.call(weatherLinks, function (weatherLink) {
          weatherLink.addEventListener("click", function (event) {
            var didOpen = openWeatherPanel();
            setAppMobileOpen(false);
            if (didOpen) {
              event.preventDefault();
              try {
                window.sessionStorage.removeItem("fpwOpenWeatherPanel");
              } catch (e) {}
            } else {
              try {
                window.sessionStorage.setItem("fpwOpenWeatherPanel", "1");
              } catch (e2) {}
            }
          });
        });

        try {
          if (window.sessionStorage.getItem("fpwOpenWeatherPanel") === "1" && openWeatherPanel()) {
            window.sessionStorage.removeItem("fpwOpenWeatherPanel");
          }
        } catch (e3) {}

        if (!newRouteLink) return;

        newRouteLink.addEventListener("click", function (event) {
          var routeBuilderOpener = document.getElementById("openRouteBuilderBtn");
          if (!routeBuilderOpener || typeof routeBuilderOpener.click !== "function") return;

          event.preventDefault();
          setAppMobileOpen(false);
          routeBuilderOpener.click();

          var newMenu = newRouteLink.closest("details.dd");
          if (newMenu && newMenu.hasAttribute("open")) {
            newMenu.removeAttribute("open");
          }
        });

        if (!newFloatPlanLink) return;

        newFloatPlanLink.addEventListener("click", function (event) {
          var floatPlanOpener = document.getElementById("addFloatPlanBtn");
          if (!floatPlanOpener || typeof floatPlanOpener.click !== "function") return;

          event.preventDefault();
          setAppMobileOpen(false);
          floatPlanOpener.click();

          var newMenu = newFloatPlanLink.closest("details.dd");
          if (newMenu && newMenu.hasAttribute("open")) {
            newMenu.removeAttribute("open");
          }
        });

        if (mobileNewRouteBtn) {
          mobileNewRouteBtn.addEventListener("click", function (event) {
            var routeBuilderOpener = document.getElementById("openRouteBuilderBtn");
            if (!routeBuilderOpener || typeof routeBuilderOpener.click !== "function") return;
            event.preventDefault();
            setAppMobileOpen(false);
            routeBuilderOpener.click();
          });
        }

        if (mobileNewFloatPlanBtn) {
          mobileNewFloatPlanBtn.addEventListener("click", function (event) {
            var floatPlanOpener = document.getElementById("addFloatPlanBtn");
            if (!floatPlanOpener || typeof floatPlanOpener.click !== "function") return;
            event.preventDefault();
            setAppMobileOpen(false);
            floatPlanOpener.click();
          });
        }

        if (mobileLogoutBtn) {
          mobileLogoutBtn.addEventListener("click", function (event) {
            var logoutButton = document.getElementById("logoutButton");
            if (!logoutButton || typeof logoutButton.click !== "function") return;
            event.preventDefault();
            setAppMobileOpen(false);
            logoutButton.click();
          });
        }
      }

      if (document.readyState === "loading") {
        document.addEventListener("DOMContentLoaded", initNavNewRouteLink);
      } else {
        initNavNewRouteLink();
      }
    })();
  </script>
<cfelse>
  <header class="topbar nav--public" role="banner">
    <div class="inner">
      <a class="brand" href="<cfoutput>#basePath#</cfoutput>/index.cfm" aria-label="FloatPlanWizard Home">
        <span class="logo" aria-hidden="true"></span>
        <span>
          <div class="brandTitle">FloatPlanWizard</div>
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
        <a class="btn" href="#login" id="publicLoginToggle">Log in</a>
        <a class="btn btnPrimary" href="<cfoutput>#basePath#</cfoutput>/app/join.cfm">Start free</a>
        <button class="iconBtn fpwHamburger" type="button" id="fpwPublicMobileToggle" aria-controls="fpwMobileMenuPublic" aria-expanded="false" aria-label="Toggle menu">
          <span class="fpwHamburgerIcon fpwHamburgerIcon--open" aria-hidden="true">☰</span>
          <span class="fpwHamburgerIcon fpwHamburgerIcon--close" aria-hidden="true">✕</span>
        </button>
      </div>
    </div>
  </header>

  <div class="fpwMobileBackdrop fpwMobileBackdrop--public" id="fpwMobileBackdropPublic" aria-hidden="true"></div>
  <nav class="fpwMobileMenu fpwMobileMenu--public" id="fpwMobileMenuPublic" role="navigation" aria-label="Mobile public menu" aria-hidden="true">
    <a href="#features">Features</a>
    <a href="#how">How it works</a>
    <a href="#monitoring">Monitoring</a>
    <a href="#pricing">Pricing</a>
    <a href="#faq">FAQ</a>
    <hr />
    <a href="#login" id="fpwMobilePublicLoginLink">Log in</a>
    <a href="<cfoutput>#basePath#</cfoutput>/app/join.cfm">Start free</a>
  </nav>

  <section class="loginStrip" id="login" aria-label="Login">
    <div class="loginInner">
      <form id="loginForm" novalidate>
        <div id="loginAlert" class="alert d-none fpwLoginAlert" role="alert"></div>
        <div class="field">
          <label for="email">Email</label>
          <input
            class="input fpwInput"
            type="email"
            id="email"
            name="email"
            required
            autocomplete="username"
            placeholder="Email"
          >
        </div>
        <div class="field">
          <label for="password">Password</label>
          <input
            class="input fpwInput"
            type="password"
            id="password"
            name="password"
            required
            autocomplete="current-password"
            placeholder="Password"
          >
        </div>
        <button type="submit" class="btn btnPrimary fpwBtn primary" id="loginButton">Sign In</button>
      </form>
      <a class="forgot" href="<cfoutput>#basePath#</cfoutput>/app/forgot-password.cfm">Forgot?</a>
    </div>
  </section>

  <script>
    (function () {
      function initPublicLoginToggle() {
        var toggle = document.getElementById("publicLoginToggle");
        var loginStrip = document.getElementById("login");
        var publicHeader = document.querySelector(".topbar.nav--public");
        var publicMobileToggle = document.getElementById("fpwPublicMobileToggle");
        var publicMobileMenu = document.getElementById("fpwMobileMenuPublic");
        var publicMobileBackdrop = document.getElementById("fpwMobileBackdropPublic");
        var publicMobileLoginLink = document.getElementById("fpwMobilePublicLoginLink");
        if (!toggle || !loginStrip || !publicHeader) return;

        function syncLoginStripTop() {
          var rect = publicHeader.getBoundingClientRect();
          loginStrip.style.setProperty(
            "--login-open-offset",
            Math.max(0, Math.round(rect.bottom)) + "px"
          );
        }

        function openLoginStrip() {
          syncLoginStripTop();
          loginStrip.classList.add("is-open");
          var emailInput = document.getElementById("email");
          if (emailInput && typeof emailInput.focus === "function") {
            emailInput.focus();
          }
        }

        function closeLoginStrip() {
          loginStrip.classList.remove("is-open");
        }

        function syncPublicMobileMenuTop() {
          if (!publicMobileMenu) return;
          var rect = publicHeader.getBoundingClientRect();
          var top = Math.max(0, Math.round(rect.bottom) + 8);
          publicMobileMenu.style.top = top + "px";
          publicMobileMenu.style.maxHeight = "calc(100vh - " + (top + 12) + "px)";
        }

        function setPublicMobileOpen(isOpen) {
          if (!publicMobileMenu || !publicMobileBackdrop || !publicMobileToggle) return;
          syncPublicMobileMenuTop();
          if (isOpen) {
            publicMobileMenu.classList.add("is-open");
            publicMobileBackdrop.classList.add("is-open");
            publicMobileMenu.setAttribute("aria-hidden", "false");
            publicMobileToggle.setAttribute("aria-expanded", "true");
            document.body.classList.add("fpwMobileNavOpen");
          } else {
            publicMobileMenu.classList.remove("is-open");
            publicMobileBackdrop.classList.remove("is-open");
            publicMobileMenu.setAttribute("aria-hidden", "true");
            publicMobileToggle.setAttribute("aria-expanded", "false");
            document.body.classList.remove("fpwMobileNavOpen");
          }
        }

        toggle.addEventListener("click", function (event) {
          event.preventDefault();
          if (loginStrip.classList.contains("is-open")) {
            closeLoginStrip();
          } else {
            openLoginStrip();
          }
        });

        if (publicMobileToggle) {
          publicMobileToggle.addEventListener("click", function (event) {
            event.preventDefault();
            setPublicMobileOpen(!publicMobileMenu || !publicMobileMenu.classList.contains("is-open"));
          });
        }
        if (publicMobileBackdrop) {
          publicMobileBackdrop.addEventListener("click", function () {
            setPublicMobileOpen(false);
          });
        }
        if (publicMobileMenu) {
          publicMobileMenu.addEventListener("click", function (event) {
            if (event.target.closest("a,button")) {
              setPublicMobileOpen(false);
            }
          });
        }
        if (publicMobileLoginLink) {
          publicMobileLoginLink.addEventListener("click", function (event) {
            event.preventDefault();
            setPublicMobileOpen(false);
            toggle.click();
          });
        }

        document.addEventListener("keydown", function (event) {
          if (event.key === "Escape") {
            setPublicMobileOpen(false);
          }
        });

        window.addEventListener("resize", function () {
          syncLoginStripTop();
          syncPublicMobileMenuTop();
          if (window.innerWidth > 980) {
            setPublicMobileOpen(false);
          }
        });
        syncLoginStripTop();
        syncPublicMobileMenuTop();
      }

      if (document.readyState === "loading") {
        document.addEventListener("DOMContentLoaded", initPublicLoginToggle);
      } else {
        initPublicLoginToggle();
      }
    })();
  </script>
</cfif>
