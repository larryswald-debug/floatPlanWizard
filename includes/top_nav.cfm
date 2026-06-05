<cfscript>
topNavBasePath = "";
topNavHost = "";
topNavIsProduction = false;
topNavActive = "";
topNavUserId = 0;
topNavIsLoggedIn = false;
topNavHasPremium = false;
topNavUserDisplayName = "";
topNavMemberDisplayInitials = "FP";
topNavFirstName = "";
topNavLastName = "";
topNavEmail = "";

if (structKeyExists(request, "fpwBase")) {
  topNavBasePath = trim(toString(request.fpwBase));
}

if (!len(topNavBasePath) AND structKeyExists(cgi, "script_name")) {
  topNavBasePath = trim(toString(cgi.script_name));
  topNavBasePath = reReplace(topNavBasePath, "[?##].*$", "");
  topNavBasePath = replace(topNavBasePath, "\\", "/", "all");
  topNavBasePath = reReplaceNoCase(topNavBasePath, "/api/v1(/.*)?$", "");
  topNavBasePath = reReplaceNoCase(topNavBasePath, "/(app|admin|assets|tests)(/.*)?$", "");
  topNavBasePath = reReplaceNoCase(topNavBasePath, "/boat-fuel-calculator/boat-fuel-calculator\.cfm$", "");
  topNavBasePath = reReplaceNoCase(topNavBasePath, "/[^/]*\.(cfm|cfc)$", "");
  topNavBasePath = reReplace(topNavBasePath, "/$", "");
}

topNavBasePath = reReplace(topNavBasePath, "/$", "");
if (topNavBasePath EQ "/") {
  topNavBasePath = "";
}
if (len(topNavBasePath) AND left(topNavBasePath, 1) NEQ "/") {
  topNavBasePath = "/" & topNavBasePath;
}

if (structKeyExists(request, "fpwTopNavActive")) {
  topNavActive = lCase(trim(toString(request.fpwTopNavActive)));
}

if (structKeyExists(session, "user") AND isStruct(session.user)) {
  if (structKeyExists(session.user, "firstName")) {
    topNavFirstName = trim(toString(session.user.firstName));
  } else if (structKeyExists(session.user, "FIRSTNAME")) {
    topNavFirstName = trim(toString(session.user.FIRSTNAME));
  } else if (structKeyExists(session.user, "fName")) {
    topNavFirstName = trim(toString(session.user.fName));
  } else if (structKeyExists(session.user, "FNAME")) {
    topNavFirstName = trim(toString(session.user.FNAME));
  }

  if (structKeyExists(session.user, "lastName")) {
    topNavLastName = trim(toString(session.user.lastName));
  } else if (structKeyExists(session.user, "LASTNAME")) {
    topNavLastName = trim(toString(session.user.LASTNAME));
  } else if (structKeyExists(session.user, "lName")) {
    topNavLastName = trim(toString(session.user.lName));
  } else if (structKeyExists(session.user, "LNAME")) {
    topNavLastName = trim(toString(session.user.LNAME));
  }

  if (structKeyExists(session.user, "email")) {
    topNavEmail = trim(toString(session.user.email));
  } else if (structKeyExists(session.user, "EMAIL")) {
    topNavEmail = trim(toString(session.user.EMAIL));
  }

  if (structKeyExists(session.user, "userId") AND isNumeric(session.user.userId)) {
    topNavUserId = val(session.user.userId);
  } else if (structKeyExists(session.user, "id") AND isNumeric(session.user.id)) {
    topNavUserId = val(session.user.id);
  } else if (structKeyExists(session.user, "USERID") AND isNumeric(session.user.USERID)) {
    topNavUserId = val(session.user.USERID);
  } else if (structKeyExists(session.user, "ID") AND isNumeric(session.user.ID)) {
    topNavUserId = val(session.user.ID);
  }

  topNavUserDisplayName = trim(topNavFirstName & " " & topNavLastName);
  if (!len(topNavUserDisplayName)) {
    topNavUserDisplayName = topNavEmail;
  }
}

topNavIsLoggedIn = topNavUserId GT 0;

if (topNavIsLoggedIn) {
  if (!len(topNavUserDisplayName)) {
    topNavUserDisplayName = "Member";
  }

  topNavInitialParts = listToArray(reReplace(topNavUserDisplayName, "\s+", " ", "all"), " ");
  topNavMemberDisplayInitials = "";
  topNavInitialLimit = arrayLen(topNavInitialParts);
  if (topNavInitialLimit GT 2) {
    topNavInitialLimit = 2;
  }
  for (topNavInitialPartIndex = 1; topNavInitialPartIndex LTE topNavInitialLimit; topNavInitialPartIndex++) {
    if (len(topNavInitialParts[topNavInitialPartIndex])) {
      topNavMemberDisplayInitials = topNavMemberDisplayInitials & left(topNavInitialParts[topNavInitialPartIndex], 1);
    }
  }
  if (!len(topNavMemberDisplayInitials)) {
    topNavMemberDisplayInitials = left(topNavUserDisplayName, 2);
  }
  topNavMemberDisplayInitials = uCase(topNavMemberDisplayInitials);

  try {
    topNavAccess = new fpw.api.v1.MemberEntitlementService().init("fpw").getCurrentAccess(topNavUserId);
    if (structKeyExists(topNavAccess, "hasPremium") AND topNavAccess.hasPremium EQ true) {
      topNavHasPremium = true;
    }
  } catch (any topNavAccessError) {
    topNavHasPremium = false;
  }
}

if (structKeyExists(cgi, "http_host")) {
  topNavHost = lcase(trim(toString(cgi.http_host)));
} else if (structKeyExists(cgi, "server_name")) {
  topNavHost = lcase(trim(toString(cgi.server_name)));
}
topNavHost = reReplace(topNavHost, ":\d+$", "");
topNavIsProduction = !len(topNavBasePath)
  AND listFindNoCase("floatplanwizard.com,www.floatplanwizard.com", topNavHost) GT 0;
topNavShowAppSubnav = topNavIsLoggedIn
  AND listFindNoCase("dashboard,active-cruise,monitoring,weather,fuel", topNavActive) GT 0;
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
  <header class="fpw-site-header<cfif topNavIsLoggedIn> fpw-site-header--logged-in</cfif><cfif topNavShowAppSubnav> fpw-site-header--app</cfif>" role="banner" data-fpw-nav>
    <cfif NOT topNavIsLoggedIn>
      <div class="fpw-prelaunch-strip">
        <a class="fpw-prelaunch-strip__link" href="#topNavBasePath#/app/join.cfm" aria-label="Launch Offer. 1 Month of Premium Free for New Members. No Credit Card Required.">
          <span class="fpw-prelaunch-strip__icon fpw-prelaunch-strip__icon--live" aria-hidden="true"></span>
          <span><strong>Launch Offer</strong> &mdash; 1 Month of Premium Free for New Members <span aria-hidden="true">&bull;</span> No Credit Card Required</span>
        </a>
      </div>
    </cfif>

    <div class="fpw-nav-shell">
      <div class="fpw-nav-inner">
        <a class="fpw-brand" href="<cfif topNavIsLoggedIn>#topNavBasePath#/app/dashboard.cfm<cfelse>#topNavBasePath#/##top</cfif>" aria-label="FloatPlanWizard home">
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

        <button
          class="fpw-mobile-toggle"
          type="button"
          aria-label="Toggle site menu"
          aria-controls="fpwPrimaryNav"
          aria-expanded="false"
          data-fpw-mobile-toggle>
          <span></span>
          <span></span>
          <span></span>
        </button>

        <div class="fpw-nav-menu" id="fpwPrimaryNav" data-fpw-nav-menu>
          <nav class="fpw-primary-nav" aria-label="Primary navigation">
            <a class="fpw-nav-link" href="#topNavBasePath#/how-it-works">
              <svg class="fpw-nav-icon" viewBox="0 0 24 24" aria-hidden="true" focusable="false"><circle cx="12" cy="12" r="9"></circle><path d="M14.5 7.5 10.8 13l-3.3 3.5 3.7-5.5z"></path></svg>
              <span>How It Works</span>
            </a>
            <a class="fpw-nav-link" href="#topNavBasePath#/##features">
              <svg class="fpw-nav-icon" viewBox="0 0 24 24" aria-hidden="true" focusable="false"><path d="m12 3 2.7 5.5 6.1.9-4.4 4.3 1 6-5.4-2.9-5.4 2.9 1-6-4.4-4.3 6.1-.9z"></path></svg>
              <span>Features</span>
            </a>
            <a class="fpw-nav-link" href="#topNavBasePath#/##great-loop">
              <svg class="fpw-nav-icon" viewBox="0 0 24 24" aria-hidden="true" focusable="false"><path d="M4 6.5 9 4l6 2.5 5-2.5v13.5L15 20l-6-2.5L4 20z"></path><path d="M9 4v13.5"></path><path d="M15 6.5V20"></path></svg>
              <span>Great Loop</span>
            </a>
            <div class="fpw-dropdown" data-fpw-dropdown>
              <button class="fpw-nav-link fpw-dropdown-toggle" type="button" aria-expanded="false" aria-haspopup="true" data-fpw-dropdown-toggle>
                <svg class="fpw-nav-icon" viewBox="0 0 24 24" aria-hidden="true" focusable="false"><path d="m14.5 5 4.5 4.5-2.8 2.8-2-2-5.9 5.9v2.5H5.8v-2.5l5.9-5.9-2-2z"></path><path d="m16 6.5 1.5-1.5 1.5 1.5"></path></svg>
                <span>Tools</span>
                <svg class="fpw-chevron" viewBox="0 0 24 24" aria-hidden="true" focusable="false"><path d="m6 9 6 6 6-6"></path></svg>
              </button>
              <div class="fpw-dropdown-menu" role="menu">
                <a href="#topNavBasePath#/boat-fuel-calculator/boat-fuel-calculator.cfm" role="menuitem">
                  <svg class="fpw-dropdown-icon" viewBox="0 0 24 24" aria-hidden="true" focusable="false"><path d="M5 20V4h9v16"></path><path d="M8 8h3"></path><path d="M14 9h2.5L19 12v6a2 2 0 0 0 4 0v-4"></path><path d="M3 20h13"></path></svg>
                  <span><strong>Fuel Calculator</strong><small>Estimate fuel and range</small></span>
                </a>
                <a href="#topNavBasePath#/app/weather.cfm" role="menuitem">
                  <svg class="fpw-dropdown-icon" viewBox="0 0 24 24" aria-hidden="true" focusable="false"><path d="M8 18h9a4 4 0 0 0 .5-8 6 6 0 0 0-11-1.7A5 5 0 0 0 8 18z"></path><path d="M8 7V4"></path><path d="M4.5 8.5 2.5 6.5"></path><path d="M3 12H1"></path></svg>
                  <span><strong>Weather</strong><small>Marine conditions and planning</small></span>
                </a>
                <a href="#topNavBasePath#/great-loop/locks/" role="menuitem">
                  <svg class="fpw-dropdown-icon" viewBox="0 0 24 24" aria-hidden="true" focusable="false"><path d="M4 6.5 9 4l6 2.5 5-2.5v13.5L15 20l-6-2.5L4 20z"></path><path d="M9 4v13.5"></path><path d="M15 6.5V20"></path></svg>
                  <span><strong>Great Loop Lock Library</strong><small>Lock locations, VHF, phone, notes, and planning reference</small></span>
                </a>
                <a href="#topNavBasePath#/why-use-a-float-plan" role="menuitem">
                  <svg class="fpw-dropdown-icon" viewBox="0 0 24 24" aria-hidden="true" focusable="false"><path d="M4 5.5A2.5 2.5 0 0 1 6.5 3H20v16H6.5A2.5 2.5 0 0 0 4 21.5z"></path><path d="M8 7h8"></path><path d="M8 11h7"></path></svg>
                  <span><strong>Float Plan Basics</strong><small>Learn how float plans work</small></span>
                </a>
              </div>
            </div>
            <a class="fpw-nav-link" href="#topNavBasePath#/app/pricing.cfm">
              <svg class="fpw-nav-icon" viewBox="0 0 24 24" aria-hidden="true" focusable="false"><path d="m20 12-8 8-8-8 8-8z"></path><path d="M12 4v16"></path></svg>
              <span>Pricing</span>
            </a>
          </nav>

          <div class="fpw-nav-actions">
            <cfif topNavIsLoggedIn>
              <cfif NOT topNavShowAppSubnav>
                <a class="fpw-nav-link fpw-dashboard-link<cfif topNavActive EQ 'dashboard'> is-active</cfif>" href="#topNavBasePath#/app/dashboard.cfm"<cfif topNavActive EQ 'dashboard'> aria-current="page"</cfif>>
                  <svg class="fpw-nav-icon" viewBox="0 0 24 24" aria-hidden="true" focusable="false"><rect x="4" y="4" width="6" height="6"></rect><rect x="14" y="4" width="6" height="6"></rect><rect x="4" y="14" width="6" height="6"></rect><rect x="14" y="14" width="6" height="6"></rect></svg>
                  <span>Dashboard</span>
                </a>
              </cfif>
              <div class="fpw-dropdown fpw-account-dropdown" data-fpw-dropdown>
                <button class="fpw-nav-link fpw-dropdown-toggle<cfif topNavActive EQ 'account'> is-active</cfif>" type="button" aria-expanded="false" aria-haspopup="true" data-fpw-dropdown-toggle>
                  <svg class="fpw-nav-icon" viewBox="0 0 24 24" aria-hidden="true" focusable="false"><circle cx="12" cy="8" r="4"></circle><path d="M4 21a8 8 0 0 1 16 0"></path></svg>
                  <span>Account</span>
                  <svg class="fpw-chevron" viewBox="0 0 24 24" aria-hidden="true" focusable="false"><path d="m6 9 6 6 6-6"></path></svg>
                </button>
                <div class="fpw-dropdown-menu fpw-dropdown-menu-right" role="menu">
                  <a href="#topNavBasePath#/app/account.cfm" role="menuitem">
                    <svg class="fpw-dropdown-icon" viewBox="0 0 24 24" aria-hidden="true" focusable="false"><circle cx="12" cy="8" r="4"></circle><path d="M4 21a8 8 0 0 1 16 0"></path></svg>
                    <span><strong>My Account</strong><small>Profile and settings</small></span>
                  </a>
                  <a href="#topNavBasePath#/index.cfm" role="menuitem" data-fpw-member-logout>
                    <svg class="fpw-dropdown-icon" viewBox="0 0 24 24" aria-hidden="true" focusable="false"><path d="M10 17 15 12 10 7"></path><path d="M15 12H3"></path><path d="M21 4v16"></path></svg>
                    <span><strong>Logout</strong><small>Sign out securely</small></span>
                  </a>
                </div>
              </div>
              <a class="fpw-nav-link fpw-logout-direct" href="#topNavBasePath#/index.cfm" data-fpw-member-logout>Logout</a>
            <cfelse>
              <a class="fpw-cta fpw-cta-primary" href="#topNavBasePath#/app/join.cfm">
                <span>Claim Your Free Month</span>
                <span class="fpw-cta-arrow" aria-hidden="true">&rarr;</span>
              </a>
              <button class="fpw-nav-link fpw-login-link" type="button" id="publicLoginToggle" aria-expanded="false" aria-controls="login">Login</button>
            </cfif>
          </div>
        </div>
      </div>
    </div>

    <cfif topNavShowAppSubnav>
      <nav class="fpw-app-subnav" aria-label="Member workspace navigation">
        <div class="fpw-app-subnav-inner">
          <a class="fpw-app-link<cfif topNavActive EQ 'dashboard'> is-active</cfif>" href="#topNavBasePath#/app/dashboard.cfm"<cfif topNavActive EQ 'dashboard'> aria-current="page"</cfif>>
            <svg class="fpw-subnav-icon" viewBox="0 0 24 24" aria-hidden="true" focusable="false"><rect x="4" y="4" width="6" height="6"></rect><rect x="14" y="4" width="6" height="6"></rect><rect x="4" y="14" width="6" height="6"></rect><rect x="14" y="14" width="6" height="6"></rect></svg>
            <span>Dashboard</span>
          </a>
          <a class="fpw-app-link<cfif topNavActive EQ 'active-cruise'> is-active</cfif>" href="#topNavBasePath#/app/active-cruise.cfm"<cfif topNavActive EQ 'active-cruise'> aria-current="page"</cfif>>
            <svg class="fpw-subnav-icon" viewBox="0 0 24 24" aria-hidden="true" focusable="false"><path d="M4 19h16"></path><path d="M7 16h8l3-4H9z"></path><path d="M9 12V5l6 7"></path></svg>
            <span>Active Cruise</span>
          </a>
          <a class="fpw-app-link<cfif topNavActive EQ 'monitoring'> is-active</cfif>" href="#topNavBasePath#/app/monitoring.cfm"<cfif topNavActive EQ 'monitoring'> aria-current="page"</cfif>>
            <svg class="fpw-subnav-icon" viewBox="0 0 24 24" aria-hidden="true" focusable="false"><path d="M4 17h16"></path><path d="M7 14l4-4 3 3 4-6"></path><path d="M6 21h12"></path></svg>
            <span>Monitor</span>
          </a>
          <a class="fpw-app-link<cfif topNavActive EQ 'weather'> is-active</cfif>" href="#topNavBasePath#/app/weather.cfm"<cfif topNavActive EQ 'weather'> aria-current="page"</cfif>>
            <svg class="fpw-subnav-icon" viewBox="0 0 24 24" aria-hidden="true" focusable="false"><path d="M8 18h9a4 4 0 0 0 .5-8 6 6 0 0 0-11-1.7A5 5 0 0 0 8 18z"></path><path d="M8 7V4"></path></svg>
            <span>Weather</span>
          </a>
          <a class="fpw-app-link<cfif topNavActive EQ 'fuel'> is-active</cfif>" href="#topNavBasePath#/boat-fuel-calculator/boat-fuel-calculator.cfm"<cfif topNavActive EQ 'fuel'> aria-current="page"</cfif>>
            <svg class="fpw-subnav-icon" viewBox="0 0 24 24" aria-hidden="true" focusable="false"><path d="M5 20V4h9v16"></path><path d="M8 8h3"></path><path d="M14 9h2.5L19 12v6a2 2 0 0 0 4 0v-4"></path></svg>
            <span>Fuel Calculator</span>
          </a>
        </div>
      </nav>
    </cfif>
  </header>

  <cfif NOT topNavIsLoggedIn>
    <section class="loginStrip fpw-prelaunch-login-strip" id="login" aria-label="Login" aria-hidden="true">
      <div class="loginInner">
        <form id="loginForm" novalidate>
          <div id="loginAlert" class="alert d-none fpwLoginAlert" role="alert"></div>
          <div class="field">
            <label class="fpw-login-label" for="email">Email</label>
            <input class="input fpwInput" type="email" id="email" name="email" required autocomplete="username" placeholder="Email">
          </div>
          <div class="field">
            <label class="fpw-login-label" for="password">Password</label>
            <input class="input fpwInput" type="password" id="password" name="password" required autocomplete="current-password" placeholder="Password">
          </div>
          <button type="submit" class="btn btnPrimary fpwBtn primary" id="loginButton">Sign In</button>
        </form>
        <a class="forgot" href="#topNavBasePath#/app/forgot-password.cfm">Forgot?</a>
      </div>
    </section>
  </cfif>

  <script>
    (function () {
      var shell = document.querySelector("[data-fpw-nav]");
      if (!shell || shell.getAttribute("data-fpw-nav-bound") === "true") {
        return;
      }
      shell.setAttribute("data-fpw-nav-bound", "true");

      var menuButton = shell.querySelector("[data-fpw-mobile-toggle]");
      var navMenu = shell.querySelector("[data-fpw-nav-menu]");
      var dropdowns = Array.prototype.slice.call(shell.querySelectorAll("[data-fpw-dropdown]"));
      var logoutLinks = shell.querySelectorAll("[data-fpw-member-logout]");
      var loginToggle = document.getElementById("publicLoginToggle");
      var loginStrip = document.getElementById("login");

      function closeDropdowns(exceptDropdown) {
        dropdowns.forEach(function (dropdown) {
          var toggle = dropdown.querySelector("[data-fpw-dropdown-toggle]");
          if (dropdown !== exceptDropdown) {
            dropdown.classList.remove("is-open");
            if (toggle) {
              toggle.setAttribute("aria-expanded", "false");
            }
          }
        });
      }

      function setMenuOpen(isOpen) {
        shell.classList.toggle("is-menu-open", isOpen);
        if (menuButton) {
          menuButton.setAttribute("aria-expanded", isOpen ? "true" : "false");
        }
        if (!isOpen) {
          closeDropdowns();
        }
      }

      function setLoginOpen(isOpen) {
        if (!loginToggle || !loginStrip) {
          return;
        }
        loginStrip.classList.toggle("is-open", isOpen);
        loginStrip.setAttribute("aria-hidden", isOpen ? "false" : "true");
        loginToggle.setAttribute("aria-expanded", isOpen ? "true" : "false");
        if (isOpen) {
          window.setTimeout(function () {
            var emailInput = document.getElementById("email");
            if (emailInput) {
              emailInput.focus();
            }
          }, 0);
        }
      }

      function redirectAfterLogout() {
        if (window.AppAuth && typeof window.AppAuth.redirectToLogin === "function") {
          window.AppAuth.redirectToLogin();
        } else {
          window.location.href = "#JSStringFormat(topNavBasePath)#/index.cfm";
        }
      }

      function postLogout() {
        if (window.Api && typeof window.Api.logout === "function") {
          return window.Api.logout();
        }
        if (window.fetch) {
          return window.fetch("#JSStringFormat(topNavBasePath)#/api/v1/auth.cfc?method=handle", {
            method: "POST",
            headers: {
              "Content-Type": "application/json"
            },
            credentials: "same-origin",
            body: JSON.stringify({ action: "logout" })
          });
        }
        return Promise.reject(new Error("Logout endpoint is not available."));
      }

      function runLogout(event) {
        event.preventDefault();
        setMenuOpen(false);
        postLogout()
          .catch(function (err) {
            console.error("Logout failed:", err);
          })
          .finally(redirectAfterLogout);
      }

      if (menuButton && navMenu) {
        menuButton.addEventListener("click", function () {
          setMenuOpen(!shell.classList.contains("is-menu-open"));
        });
      }

      dropdowns.forEach(function (dropdown) {
        var toggle = dropdown.querySelector("[data-fpw-dropdown-toggle]");
        if (!toggle) {
          return;
        }
        toggle.addEventListener("click", function (event) {
          event.preventDefault();
          var isOpen = dropdown.classList.contains("is-open");
          closeDropdowns(dropdown);
          dropdown.classList.toggle("is-open", !isOpen);
          toggle.setAttribute("aria-expanded", !isOpen ? "true" : "false");
        });
      });

      if (loginToggle && loginStrip) {
        loginToggle.addEventListener("click", function () {
          if (shell.classList.contains("is-menu-open")
            && window.matchMedia
            && window.matchMedia("(max-width: 1120px)").matches) {
            setLoginOpen(false);
            window.location.href = "#JSStringFormat(topNavBasePath)#/app/login.cfm";
            return;
          }
          setLoginOpen(!loginStrip.classList.contains("is-open"));
        });
      }

      Array.prototype.forEach.call(logoutLinks, function (logoutLink) {
        logoutLink.addEventListener("click", runLogout);
      });

      document.addEventListener("click", function (event) {
        if (!shell.contains(event.target)) {
          setMenuOpen(false);
          closeDropdowns();
        }
        if (loginStrip && loginToggle && !loginStrip.contains(event.target) && !loginToggle.contains(event.target)) {
          setLoginOpen(false);
        }
      });

      document.addEventListener("keydown", function (event) {
        if (event.key === "Escape") {
          setMenuOpen(false);
          closeDropdowns();
          setLoginOpen(false);
        }
      });

      window.addEventListener("resize", function () {
        if (window.matchMedia("(min-width: 1121px)").matches) {
          setMenuOpen(false);
        }
      });
    })();
  </script>

  <cfif NOT topNavIsLoggedIn>
    <script>
      window.FPW_BASE = "#JSStringFormat(topNavBasePath)#";
      window.FPW_API_BASE = "#JSStringFormat(topNavBasePath)#/api/v1";
    </script>
    <script src="#topNavBasePath#/assets/js/app/api.js?v=20260526-cache-bump"></script>
    <script src="#topNavBasePath#/assets/js/app/auth.js?v=20260526-cache-bump"></script>
    <script src="#topNavBasePath#/assets/js/app/core.js"></script>
  </cfif>
</cfoutput>
