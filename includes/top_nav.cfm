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
<cfif topNavIsLoggedIn>

  <header class="fpw-site-header fpw-member-site-header" role="banner" data-fpw-member-nav>
    <div class="fpw-nav-shell">
      <div class="fpw-nav-inner fpw-member-nav-inner">
        <a class="fpw-brand fpw-member-brand" href="#topNavBasePath#/index.cfm" aria-label="FloatPlanWizard home">
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
            <span class="fpw-brand__tagline">Member workspace</span>
          </span>
        </a>

        <nav class="fpw-primary-nav fpw-member-primary-nav" id="fpwMemberPrimaryNav" aria-label="Member navigation">
          <div class="fpw-primary-nav__row fpw-member-primary-nav__row">
            <a class="fpw-member-nav-link<cfif topNavActive EQ 'dashboard'> is-active</cfif>" href="#topNavBasePath#/app/dashboard.cfm"<cfif topNavActive EQ 'dashboard'> aria-current="page"</cfif>>Dashboard</a>
            <a class="fpw-member-nav-link<cfif topNavActive EQ 'weather'> is-active</cfif>" href="#topNavBasePath#/app/weather.cfm"<cfif topNavActive EQ 'weather'> aria-current="page"</cfif>>Weather</a>
            <a class="fpw-member-nav-link<cfif topNavActive EQ 'fuel'> is-active</cfif>" href="#topNavBasePath#/boat-fuel-calculator/boat-fuel-calculator.cfm"<cfif topNavActive EQ 'fuel'> aria-current="page"</cfif>>Fuel Calculator</a>
            <cfif topNavHasPremium>
              <a class="fpw-member-nav-link<cfif topNavActive EQ 'monitoring'> is-active</cfif>" href="#topNavBasePath#/app/monitoring.cfm"<cfif topNavActive EQ 'monitoring'> aria-current="page"</cfif>>Monitor</a>
            </cfif>
            <a class="fpw-member-nav-link fpw-member-mobile-only<cfif topNavActive EQ 'account'> is-active</cfif>" href="#topNavBasePath#/app/account.cfm"<cfif topNavActive EQ 'account'> aria-current="page"</cfif>>Account</a>
            <a class="fpw-member-nav-link fpw-member-mobile-only" href="#topNavBasePath#/index.cfm" data-fpw-member-logout>Logout</a>
          </div>
        </nav>

        <div class="fpw-nav-actions fpw-member-actions">
          <a class="fpw-member-action-link fpw-member-account-link<cfif topNavActive EQ 'account'> is-active</cfif>" href="#topNavBasePath#/app/account.cfm"<cfif topNavActive EQ 'account'> aria-current="page"</cfif>>
            <span class="fpw-member-avatar" aria-hidden="true">#encodeForHTML(topNavMemberDisplayInitials)#</span>
            <span>Account</span>
          </a>
          <a class="fpw-member-action-link fpw-member-logout-link" href="#topNavBasePath#/index.cfm" data-fpw-member-logout>Logout</a>

          <button class="fpw-grid-button fpw-member-grid-button" type="button" aria-label="Toggle member menu" aria-controls="fpwMemberPrimaryNav" aria-expanded="false">
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

  <script>
    (function () {
      var header = document.querySelector("[data-fpw-member-nav]");
      if (!header) {
        return;
      }

      var menuButton = header.querySelector(".fpw-grid-button");
      var primaryNav = header.querySelector(".fpw-primary-nav");
      var logoutLinks = header.querySelectorAll("[data-fpw-member-logout]");

      function setMenuOpen(isOpen) {
        header.classList.toggle("is-menu-open", isOpen);
        if (menuButton) {
          menuButton.setAttribute("aria-expanded", isOpen ? "true" : "false");
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

      if (menuButton && primaryNav) {
        menuButton.addEventListener("click", function () {
          setMenuOpen(!header.classList.contains("is-menu-open"));
        });

        primaryNav.addEventListener("click", function (event) {
          if (event.target.closest("a") && window.matchMedia("(max-width: 760px)").matches) {
            setMenuOpen(false);
          }
        });

        window.addEventListener("resize", function () {
          if (window.matchMedia("(min-width: 761px)").matches) {
            setMenuOpen(false);
          }
        });
      }

      Array.prototype.forEach.call(logoutLinks, function (logoutLink) {
        logoutLink.addEventListener("click", runLogout);
      });
    })();
  </script>
<cfelse>

  <header class="fpw-site-header" role="banner">
    <div class="fpw-prelaunch-strip">
      <a class="fpw-prelaunch-strip__link" href="#topNavBasePath#/##notify" aria-label="Join prelaunch and get 2 months of Premium free">
        <span class="fpw-prelaunch-strip__icon" aria-hidden="true">&lsaquo;</span>
        <span>Prelaunch offer &mdash; <strong>2 months</strong> of Premium free</span>
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
            <a href="#topNavBasePath#/##notify" hidden aria-hidden="true" data-nav-reserved="true">Pricing</a>
          </div>

          <div class="fpw-secondary-nav" aria-label="Popular pages">
            <a href="#topNavBasePath#/##followers">Share the Trip</a>
            <span aria-hidden="true">&bull;</span>
            <a href="#topNavBasePath#/why-use-a-float-plan">Float Plans</a>
          </div>
        </nav>

        <div class="fpw-nav-actions">
          <a class="fpw-join-button" href="#topNavBasePath#/##notify">
            <span>Join Prelaunch</span>
            <span aria-hidden="true">&rarr;</span>
          </a>

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

  <script>
    (function () {
      var header = document.querySelector(".fpw-site-header");
      if (!header) {
        return;
      }

      var menuButton = header.querySelector(".fpw-grid-button");
      var primaryNav = header.querySelector(".fpw-primary-nav");
      if (!menuButton || !primaryNav) {
        return;
      }

      function setMenuOpen(isOpen) {
        header.classList.toggle("is-menu-open", isOpen);
        menuButton.setAttribute("aria-expanded", isOpen ? "true" : "false");
      }

      menuButton.addEventListener("click", function () {
        setMenuOpen(!header.classList.contains("is-menu-open"));
      });

      primaryNav.addEventListener("click", function (event) {
        if (event.target.closest("a") && window.matchMedia("(max-width: 760px)").matches) {
          setMenuOpen(false);
        }
      });

      window.addEventListener("resize", function () {
        if (window.matchMedia("(min-width: 761px)").matches) {
          setMenuOpen(false);
        }
      });
    })();
  </script>
</cfif>
</cfoutput>
