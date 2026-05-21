<cfscript>
topNavBasePath = "";
topNavHasRequestBase = false;
topNavHost = "";
topNavIsProduction = false;

if (structKeyExists(request, "fpwBase") AND !isNull(request.fpwBase)) {
  topNavHasRequestBase = true;
  topNavBasePath = trim(toString(request.fpwBase));
}

if (!topNavHasRequestBase AND !len(topNavBasePath) AND structKeyExists(cgi, "script_name")) {
  topNavScriptName = trim(toString(cgi.script_name));
  topNavBasePath = reReplace(topNavScriptName, "/boat-fuel-calculator/boat-fuel-calculator\.cfm$", "");
  topNavBasePath = reReplace(topNavBasePath, "/index\.cfm$", "");

  if (topNavBasePath EQ topNavScriptName) {
    topNavBasePath = getDirectoryFromPath(topNavScriptName);
    topNavBasePath = reReplace(topNavBasePath, "/$", "");
  }
}

topNavBasePath = reReplace(topNavBasePath, "/$", "");
if (topNavBasePath EQ "/") {
  topNavBasePath = "";
}
if (len(topNavBasePath) AND left(topNavBasePath, 1) NEQ "/") {
  topNavBasePath = "/" & topNavBasePath;
}
topNavApiBasePath = topNavBasePath & "/api/v1";

if (structKeyExists(cgi, "http_host")) {
  topNavHost = lcase(trim(toString(cgi.http_host)));
} else if (structKeyExists(cgi, "server_name")) {
  topNavHost = lcase(trim(toString(cgi.server_name)));
}
topNavHost = reReplace(topNavHost, ":\d+$", "");
topNavIsProduction = !len(topNavBasePath)
  AND listFindNoCase("floatplanwizard.com,www.floatplanwizard.com", topNavHost) GT 0;
</cfscript>

<cfif topNavIsProduction>
  <!-- Google tag (gtag.js) -->
  <script async src="https://www.googletagmanager.com/gtag/js?id=G-JJCH1QE0LH"></script>
  <script>
    window.dataLayer = window.dataLayer || [];
    function gtag(){dataLayer.push(arguments);}
    gtag('js', new Date());

    gtag('config', 'G-JJCH1QE0LH');
  </script>
</cfif>

<cfoutput>

  <header class="fpw-site-header" role="banner">
    <div class="fpw-prelaunch-strip">
      <a class="fpw-prelaunch-strip__link" href="#topNavBasePath#/app/join.cfm" aria-label="FloatPlanWizard is now live. Start free. Premium available for advanced cruising tools.">
        <span class="fpw-prelaunch-strip__icon fpw-prelaunch-strip__icon--live" aria-hidden="true"></span>
        <span><strong>Now Live</strong> &mdash; Start Free <span aria-hidden="true">&bull;</span> Premium available for advanced cruising tools</span>
      </a>
    </div>

    <div class="fpw-nav-shell">
      <div class="fpw-nav-inner">
        <a class="fpw-brand" href="#topNavBasePath#/##top" aria-label="FloatPlanWizard home">
          <span class="fpw-brand__mark" aria-hidden="true">
            <svg class="fpw-helm-icon" viewBox="0 0 64 64" focusable="false">
              <circle cx="32" cy="32" r="17"></circle>
              <circle cx="32" cy="32" r="6"></circle>
              <path d="M32 4v12"></path>
              <path d="M32 48v12"></path>
              <path d="M4 32h12"></path>
              <path d="M48 32h12"></path>
              <path d="M12.2 12.2l8.5 8.5"></path>
              <path d="M43.3 43.3l8.5 8.5"></path>
              <path d="M51.8 12.2l-8.5 8.5"></path>
              <path d="M20.7 43.3l-8.5 8.5"></path>
              <circle cx="32" cy="4" r="2.5"></circle>
              <circle cx="32" cy="60" r="2.5"></circle>
              <circle cx="4" cy="32" r="2.5"></circle>
              <circle cx="60" cy="32" r="2.5"></circle>
            </svg>
          </span>

          <span class="fpw-brand__text">
            <span class="fpw-brand__name">FloatPlanWizard</span>
            <span class="fpw-brand__tagline">Built for serious recreational boaters</span>
          </span>
        </a>

        <nav class="fpw-primary-nav" id="fpwPrimaryNav" aria-label="Primary navigation">
          <div class="fpw-primary-nav__row">
            <a href="#topNavBasePath#/how-it-works">How It Works</a>
            <a href="#topNavBasePath#/##features">Features</a>
            <a href="#topNavBasePath#/##great-loop">Great Loop</a>
            <a href="#topNavBasePath#/##great-loop" class="fpw-nav-has-menu" hidden aria-hidden="true" data-nav-reserved="true" style="display: none;">
              Explore
              <span aria-hidden="true">&##8964;</span>
            </a>
            <details class="fpw-nav-dropdown">
              <summary class="fpw-nav-has-menu">
                Tools
                <span aria-hidden="true">&##8964;</span>
              </summary>
              <div class="fpw-nav-dropdown__menu" aria-label="Tools menu">
                <a href="#topNavBasePath#/boat-fuel-calculator/boat-fuel-calculator.cfm">
                  <span class="fpw-nav-dropdown__item-title">Fuel Calculator</span>
                  <span class="fpw-nav-dropdown__item-copy">Estimate route fuel before you leave.</span>
                </a>
                <a href="#topNavBasePath#/why-use-a-float-plan">
                  <span class="fpw-nav-dropdown__item-title">Float Plans</span>
                  <span class="fpw-nav-dropdown__item-copy">Learn why every boater should file one.</span>
                </a>
              </div>
            </details>
            <a href="#topNavBasePath#/app/pricing.cfm">Pricing</a>
          </div>

          <div class="fpw-secondary-nav" aria-label="Popular pages">
            <a href="#topNavBasePath#/##followers">Share the Trip</a>
            <span aria-hidden="true">&bull;</span>
            <a href="#topNavBasePath#/why-use-a-float-plan">Float Plans</a>
          </div>
        </nav>

        <div class="fpw-nav-actions">
          <a class="fpw-join-button fpw-start-free-button" href="#topNavBasePath#/app/join.cfm">
            <span>Start Free</span>
            <span aria-hidden="true">&rarr;</span>
          </a>

          <button class="fpw-login-toggle" type="button" id="publicLoginToggle" aria-expanded="false" aria-controls="login">
            <span>Login</span>
            <span aria-hidden="true">&##8964;</span>
          </button>

          <button class="fpw-grid-button" type="button" aria-label="Toggle site menu" aria-controls="fpwPrimaryNav" aria-expanded="false">
            <svg class="fpw-grid-icon" viewBox="0 0 24 24" aria-hidden="true" focusable="false">
              <circle cx="6" cy="6" r="1.7"></circle>
              <circle cx="12" cy="6" r="1.7"></circle>
              <circle cx="18" cy="6" r="1.7"></circle>
              <circle cx="6" cy="12" r="1.7"></circle>
              <circle cx="12" cy="12" r="1.7"></circle>
              <circle cx="18" cy="12" r="1.7"></circle>
              <circle cx="6" cy="18" r="1.7"></circle>
              <circle cx="12" cy="18" r="1.7"></circle>
              <circle cx="18" cy="18" r="1.7"></circle>
            </svg>
            <svg class="fpw-hamburger-icon" viewBox="0 0 24 24" aria-hidden="true" focusable="false">
              <path d="M4 7h16"></path>
              <path d="M4 12h16"></path>
              <path d="M4 17h16"></path>
            </svg>
          </button>
        </div>
      </div>
    </div>
  </header>

  <section class="loginStrip fpw-prelaunch-login-strip" id="login" aria-label="Login" aria-hidden="true">
    <div class="loginInner">
      <form id="loginForm" novalidate>
        <div id="loginAlert" class="alert d-none fpwLoginAlert" role="alert"></div>
        <div class="field">
          <label class="fpw-login-label" for="email">Email</label>
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
          <label class="fpw-login-label" for="password">Password</label>
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
      <a class="forgot" href="#topNavBasePath#/app/forgot-password.cfm">Forgot?</a>
    </div>
  </section>

  <script>
    (function () {
      var header = document.querySelector(".fpw-site-header");
      if (!header) {
        return;
      }

      var menuButton = header.querySelector(".fpw-grid-button");
      var primaryNav = header.querySelector(".fpw-primary-nav");
      var loginToggle = document.getElementById("publicLoginToggle");
      var loginStrip = document.getElementById("login");
      if (!menuButton || !primaryNav) {
        return;
      }

      function setMenuOpen(isOpen) {
        header.classList.toggle("is-menu-open", isOpen);
        menuButton.setAttribute("aria-expanded", isOpen ? "true" : "false");
      }

      function syncLoginStripTop() {
        if (!loginStrip) {
          return;
        }

        var rect = header.getBoundingClientRect();
        loginStrip.style.setProperty(
          "--login-open-offset",
          Math.max(0, Math.round(rect.bottom)) + "px"
        );
      }

      function setLoginOpen(isOpen) {
        if (!loginToggle || !loginStrip) {
          return;
        }

        syncLoginStripTop();
        loginStrip.classList.toggle("is-open", isOpen);
        loginStrip.setAttribute("aria-hidden", isOpen ? "false" : "true");
        loginToggle.setAttribute("aria-expanded", isOpen ? "true" : "false");

        if (isOpen) {
          setMenuOpen(false);
          var emailInput = document.getElementById("email");
          if (emailInput && typeof emailInput.focus === "function") {
            emailInput.focus();
          }
        }
      }

      menuButton.addEventListener("click", function () {
        setLoginOpen(false);
        setMenuOpen(!header.classList.contains("is-menu-open"));
      });

      if (loginToggle) {
        loginToggle.addEventListener("click", function (event) {
          event.preventDefault();
          setLoginOpen(!loginStrip.classList.contains("is-open"));
        });
      }

      primaryNav.addEventListener("click", function (event) {
        if (event.target.closest("a") && window.matchMedia("(max-width: 760px)").matches) {
          setMenuOpen(false);
        }
      });

      document.addEventListener("keydown", function (event) {
        if (event.key === "Escape") {
          setMenuOpen(false);
          setLoginOpen(false);
        }
      });

      window.addEventListener("resize", function () {
        syncLoginStripTop();
        if (window.matchMedia("(min-width: 761px)").matches) {
          setMenuOpen(false);
        }
      });

      syncLoginStripTop();
    })();
  </script>

  <script>
    window.FPW_BASE = "#topNavBasePath#";
    window.FPW_API_BASE = "#topNavApiBasePath#";
  </script>
  <script src="#topNavBasePath#/assets/js/app/api.js?v=20260423a"></script>
  <script src="#topNavBasePath#/assets/js/app/auth.js?v=20260305a"></script>
  <script src="#topNavBasePath#/assets/js/app/core.js"></script>
</cfoutput>
