<cfscript>
topNavBasePath = "";
topNavHasRequestBase = false;
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
topNavHowHref = "";
topNavRequestPath = "";
topNavResourcesActive = false;
topNavSoloBoatingGuideActive = false;
topNavShoreContactGuideActive = false;
topNavWhyFloatPlanActive = false;
topNavFaqActive = false;
topNavFuelActive = false;
topNavWeatherActive = false;
topNavCreditModelEnabled = (
  structKeyExists(application, "premiumSendCreditModelEnabled")
  AND listFindNoCase("1,true,yes,on", lCase(trim(toString(application.premiumSendCreditModelEnabled)))) GT 0
);

if (structKeyExists(request, "fpwBase")) {
  topNavHasRequestBase = true;
  topNavBasePath = trim(toString(request.fpwBase));
}

if (!topNavHasRequestBase AND !len(topNavBasePath) AND structKeyExists(cgi, "script_name")) {
  topNavBasePath = trim(toString(cgi.script_name));
  topNavBasePath = reReplace(topNavBasePath, "[?##].*$", "");
  topNavBasePath = replace(topNavBasePath, "\\", "/", "all");
  topNavBasePath = reReplaceNoCase(topNavBasePath, "/api/v1(/.*)?$", "");
  topNavBasePath = reReplaceNoCase(topNavBasePath, "/great-loop(/.*)?$", "");
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

if (structKeyExists(cgi, "request_uri")) {
  topNavRequestPath = toString(cgi.request_uri);
} else if (structKeyExists(cgi, "script_name")) {
  topNavRequestPath = toString(cgi.script_name);
}
topNavRequestPath = lCase(replace(trim(topNavRequestPath), "\", "/", "all"));
topNavRequestPath = reReplace(topNavRequestPath, "[?##].*$", "");

topNavResourceRouteMap = [
  { "pattern" = "/solo-boating-safety-guide", "active" = "resources-solo-boating-guide" },
  { "pattern" = "/shore-contact-overdue-boater", "active" = "resources-shore-contact-guide" },
  { "pattern" = "/why-use-a-float-plan", "active" = "resources-why-float-plan" },
  { "pattern" = "/faq/", "active" = "resources-faq" }
];

if (!len(topNavActive)) {
  for (topNavResourceRouteIndex = 1; topNavResourceRouteIndex LTE arrayLen(topNavResourceRouteMap); topNavResourceRouteIndex++) {
    if (findNoCase(topNavResourceRouteMap[topNavResourceRouteIndex].pattern, topNavRequestPath)) {
      topNavActive = topNavResourceRouteMap[topNavResourceRouteIndex].active;
      break;
    }
  }
}

topNavResourcesActive = listFindNoCase(
  "resources,resources-solo-boating-guide,resources-shore-contact-guide,resources-why-float-plan,resources-faq,fuel,weather",
  topNavActive
) GT 0;
topNavSoloBoatingGuideActive = topNavActive EQ "resources-solo-boating-guide";
topNavShoreContactGuideActive = topNavActive EQ "resources-shore-contact-guide";
topNavWhyFloatPlanActive = topNavActive EQ "resources-why-float-plan";
topNavFaqActive = topNavActive EQ "resources-faq";
topNavFuelActive = topNavActive EQ "fuel";
topNavWeatherActive = topNavActive EQ "weather";

topNavHowHref = topNavBasePath & "/how-it-works/";

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

function renderFpwNavIcon(required string name, string extraClass = "") output=false {
  var iconName = lCase(trim(arguments.name));
  var iconClass = "fpw-svg-icon";
  var iconViewBox = "0 0 48 48";
  var iconPaths = "";

  if (len(trim(arguments.extraClass))) {
    iconClass = iconClass & " " & trim(arguments.extraClass);
  }

  switch (iconName) {
    case "brand-wheel":
      iconClass = iconClass & " fpw-icon-brand-wheel";
      iconViewBox = "0 0 64 64";
      iconPaths = '<circle cx="32" cy="32" r="13"></circle><circle cx="32" cy="32" r="5"></circle><path d="M32 4v10"></path><path d="M32 50v10"></path><path d="M4 32h10"></path><path d="M50 32h10"></path><path d="M12.2 12.2l7.1 7.1"></path><path d="M44.7 44.7l7.1 7.1"></path><path d="M51.8 12.2l-7.1 7.1"></path><path d="M19.3 44.7l-7.1 7.1"></path><circle cx="32" cy="4" r="2.6"></circle><circle cx="32" cy="60" r="2.6"></circle><circle cx="4" cy="32" r="2.6"></circle><circle cx="60" cy="32" r="2.6"></circle><circle cx="12.2" cy="12.2" r="2.3"></circle><circle cx="51.8" cy="12.2" r="2.3"></circle><circle cx="12.2" cy="51.8" r="2.3"></circle><circle cx="51.8" cy="51.8" r="2.3"></circle>';
      break;
    case "how":
      iconClass = iconClass & " fpw-icon-how";
      iconPaths = '<circle cx="24" cy="24" r="15"></circle><path d="M14 34L34 14"></path><path d="M19 16h7"></path><path d="M22 32h7"></path>';
      break;
    case "help":
      iconClass = iconClass & " fpw-icon-help";
      iconPaths = '<circle cx="24" cy="24" r="18"></circle><path d="M18 18a6 6 0 1 1 9 5c-2 1-3 2-3 5"></path><circle cx="24" cy="35" r="1"></circle>';
      break;
    case "route":
      iconClass = iconClass & " fpw-icon-route";
      iconPaths = '<path d="M14 38c8-8 13 6 22-3"></path><path d="M16 13c0 5-6 8-6 8s-6-3-6-8a6 6 0 0 1 12 0z"></path><circle cx="10" cy="13" r="2"></circle><path d="M44 17c0 5-6 8-6 8s-6-3-6-8a6 6 0 0 1 12 0z"></path><circle cx="38" cy="17" r="2"></circle><path d="M18 25h5"></path><path d="M27 25h3"></path>';
      break;
    case "map":
      iconClass = iconClass & " fpw-icon-map";
      iconPaths = '<path d="M7 12l10-4 14 4 10-4v28l-10 4-14-4-10 4z"></path><path d="M17 8v28"></path><path d="M31 12v28"></path>';
      break;
    case "tools":
      iconClass = iconClass & " fpw-icon-tools";
      iconPaths = '<path d="M31 6a10 10 0 0 0 11 13L20 41a6 6 0 0 1-8-8l22-22A10 10 0 0 0 31 6z"></path><circle cx="16" cy="36" r="2"></circle>';
      break;
    case "pricing":
      iconClass = iconClass & " fpw-icon-pricing";
      iconPaths = '<path d="M8 21L21 8h17v17L25 38z"></path><circle cx="32" cy="16" r="3"></circle>';
      break;
    case "user":
      iconClass = iconClass & " fpw-icon-user";
      iconPaths = '<circle cx="24" cy="24" r="18"></circle><circle cx="24" cy="18" r="6"></circle><path d="M13 36c3-7 19-7 22 0"></path>';
      break;
    case "lock":
      iconClass = iconClass & " fpw-icon-lock-library";
      iconViewBox = "0 0 64 64";
      iconPaths = '<path d="M22 30v-8a10 10 0 0 1 20 0v8"></path><path d="M16 30h32v18H16z"></path><path d="M24 30v-8"></path><path d="M40 30v-8"></path><path d="M12 48c4 0 4 3 8 3s4-3 8-3 4 3 8 3 4-3 8-3 4 3 8 3"></path><path d="M12 56c4 0 4 3 8 3s4-3 8-3 4 3 8 3 4-3 8-3 4 3 8 3"></path>';
      break;
    case "bridge":
      iconClass = iconClass & " fpw-icon-bridge-library";
      iconViewBox = "0 0 64 64";
      iconPaths = '<path d="M10 42h44"></path><path d="M16 42c5-14 27-14 32 0"></path><path d="M20 42V28"></path><path d="M32 42V22"></path><path d="M44 42V28"></path><path d="M14 34h36"></path><path d="M8 50c4 0 4 3 8 3s4-3 8-3 4 3 8 3 4-3 8-3 4 3 8 3 4-3 8-3"></path>';
      break;
    case "anchor":
      iconClass = iconClass & " fpw-icon-anchor-library";
      iconViewBox = "0 0 64 64";
      iconPaths = '<circle cx="32" cy="12" r="5"></circle><path d="M32 17v32"></path><path d="M22 25h20"></path><path d="M16 38c0 10 7 18 16 18s16-8 16-18"></path><path d="M10 42l6-4 5 6"></path><path d="M54 42l-6-4-5 6"></path>';
      break;
    case "compass":
      iconClass = iconClass & " fpw-icon-compass";
      iconViewBox = "0 0 64 64";
      iconPaths = '<circle cx="32" cy="32" r="24"></circle><path d="M40 20l-6 18-18 6 6-18z"></path><circle cx="32" cy="32" r="2"></circle>';
      break;
    case "fuel":
      iconClass = iconClass & " fpw-icon-fuel";
      iconViewBox = "0 0 64 64";
      iconPaths = '<path d="M16 10h24v44H16z"></path><path d="M22 16h12v12H22z"></path><path d="M40 20h5l7 7v20a5 5 0 0 1-10 0v-9h-2"></path><path d="M45 20v10h7"></path><path d="M12 54h32"></path>';
      break;
    case "weather":
      iconClass = iconClass & " fpw-icon-weather";
      iconViewBox = "0 0 64 64";
      iconPaths = '<path d="M20 42h28a9 9 0 0 0 0-18 14 14 0 0 0-27-4A11 11 0 0 0 20 42z"></path><path d="M16 16l-4-4"></path><path d="M28 10V4"></path><path d="M8 28H2"></path><path d="M12 44l-4 4"></path>';
      break;
    case "checklist":
      iconClass = iconClass & " fpw-icon-checklist";
      iconViewBox = "0 0 64 64";
      iconPaths = '<path d="M18 12h28v44H18z"></path><path d="M26 12a6 6 0 0 1 12 0"></path><path d="M24 26l4 4 8-9"></path><path d="M24 40h16"></path><path d="M24 48h12"></path>';
      break;
    case "kayak":
      iconClass = iconClass & " fpw-icon-kayak";
      iconViewBox = "0 0 64 64";
      iconPaths = '<circle cx="25" cy="14" r="4"></circle><path d="M25 18l5 9 10 3"></path><path d="M29 23l-8 8 11 6"></path><path d="M42 20L25 40"></path><path d="M43 17l5 4-4 5-5-4z"></path><path d="M22 39l-4 6-5-4 5-5z"></path><path d="M8 40h48c-5 8-13 12-24 12S13 48 8 40z"></path><path d="M6 57c4 0 4-3 8-3s4 3 8 3 4-3 8-3 4 3 8 3 4-3 8-3 4 3 8 3"></path>';
      break;
    case "route-cta":
      iconClass = iconClass & " fpw-icon-route-cta";
      iconViewBox = "0 0 64 64";
      iconPaths = '<path d="M14 44c12-14 22 10 36-8"></path><path d="M18 18c0 7-8 12-8 12s-8-5-8-12a8 8 0 0 1 16 0z"></path><circle cx="10" cy="18" r="2.5"></circle><path d="M60 24c0 7-8 12-8 12s-8-5-8-12a8 8 0 0 1 16 0z"></path><circle cx="52" cy="24" r="2.5"></circle><path d="M24 34h6"></path><path d="M36 34h3"></path>';
      break;
    case "launch":
      iconClass = iconClass & " fpw-icon-launch";
      iconPaths = '<path d="M29 5c6 2 11 7 14 14L30 32 16 18z"></path><path d="M16 18l-8 3-4 9 10-4"></path><path d="M30 32l-3 8-9 4 4-10"></path><circle cx="31" cy="17" r="3"></circle><path d="M12 34l-6 6"></path><path d="M18 38l-4 4"></path>';
      break;
    default:
      return "";
  }

  return '<svg class="' & iconClass & '" viewBox="' & iconViewBox & '" aria-hidden="true" focusable="false">' & iconPaths & '</svg>';
}

topNavShowAppSubnav = topNavIsLoggedIn
  AND listFindNoCase("dashboard,active-cruise,monitoring,weather,fuel", topNavActive) GT 0;
</cfscript>

<cfoutput>
  <header class="fpw-site-header<cfif topNavIsLoggedIn> fpw-site-header--logged-in</cfif><cfif topNavShowAppSubnav> fpw-site-header--app</cfif>" role="banner" data-fpw-nav>
    <cfif NOT topNavIsLoggedIn>
      <div class="fpw-launch-strip">
        <div class="fpw-launch-inner">
          <span class="fpw-launch-icon" aria-hidden="true">#renderFpwNavIcon("launch", "fpw-launch-svg")#</span>
          <cfif topNavCreditModelEnabled>
            <span class="fpw-launch-copy"><strong>Free Membership</strong> &mdash; Full planning and Basic sending included <span aria-hidden="true">&bull;</span> First complete Premium trip included for new members</span>
          <cfelse>
            <span class="fpw-launch-copy"><strong>FloatPlanWizard</strong> &mdash; Plan routes, create float plans, and organize trip details <span aria-hidden="true">&bull;</span> No Credit Card Required</span>
          </cfif>
          <a class="fpw-launch-link" href="#topNavBasePath#/app/join.cfm">Learn More <span aria-hidden="true">&rarr;</span></a>
        </div>
      </div>
    </cfif>

    <div class="fpw-nav-shell">
      <div class="fpw-nav-inner">
        <a class="fpw-brand" href="<cfif topNavIsLoggedIn>#topNavBasePath#/app/dashboard.cfm<cfelse>#topNavBasePath#/##top</cfif>" aria-label="FloatPlanWizard home">
          <span class="fpw-brand__mark" aria-hidden="true">
            #renderFpwNavIcon("brand-wheel", "fpw-helm-icon")#
          </span>

          <span class="fpw-brand__text">
            <span class="fpw-brand__name">FloatPlanWizard</span>
            <span class="fpw-brand__tagline">Built for serious recreational boaters</span>
          </span>
        </a>

        <button
          class="fpw-mobile-toggle"
          type="button"
          aria-label="Open menu"
          aria-controls="fpwPrimaryNav"
          aria-expanded="false"
          data-fpw-mobile-toggle>
          <span></span>
          <span></span>
          <span></span>
        </button>

        <div class="fpw-nav-menu" id="fpwPrimaryNav" data-fpw-nav-menu>
          <div class="fpw-mobile-drawer-head">
            <a class="fpw-mobile-brand" href="<cfif topNavIsLoggedIn>#topNavBasePath#/app/dashboard.cfm<cfelse>#topNavBasePath#/##top</cfif>" aria-label="FloatPlanWizard home">
              <span class="fpw-brand__mark" aria-hidden="true">
                #renderFpwNavIcon("brand-wheel", "fpw-helm-icon")#
              </span>
              <span>FPW</span>
            </a>
            <button class="fpw-mobile-close" type="button" aria-label="Close menu" data-fpw-mobile-close>&times;</button>
          </div>

          <nav class="fpw-primary-nav<cfif topNavIsLoggedIn> fpw-primary-nav--member</cfif>" aria-label="Primary navigation">
            <cfif NOT topNavIsLoggedIn>
              <a class="fpw-nav-link" href="#topNavHowHref#">
                #renderFpwNavIcon("how", "fpw-nav-icon")#
                <span>How It Works</span>
              </a>
              <a class="fpw-nav-link" href="#topNavBasePath#/##fpwProductPreview">
                #renderFpwNavIcon("route", "fpw-nav-icon")#
                <span>Features</span>
              </a>
            </cfif>
            <div class="fpw-dropdown fpw-dropdown--mega" data-fpw-dropdown>
              <button class="fpw-nav-link fpw-dropdown-toggle" type="button" aria-expanded="false" aria-controls="fpwGreatLoopMenu" data-fpw-dropdown-toggle>
                #renderFpwNavIcon("map", "fpw-nav-icon")#
                <span class="fpw-nav-label-desktop">Great Loop</span>
                <span class="fpw-nav-label-mobile">Great Loop Libraries</span>
                <svg class="fpw-chevron" viewBox="0 0 24 24" aria-hidden="true" focusable="false"><path d="m6 9 6 6 6-6"></path></svg>
              </button>
              <div class="fpw-dropdown-menu fpw-mega-menu" id="fpwGreatLoopMenu" role="menu">
                <div class="fpw-menu-header">
                  #renderFpwNavIcon("map", "fpw-menu-header-icon")#
                  <div>
                    <h2>Great Loop Libraries</h2>
                    <p>Essential information for planning your Great Loop adventure</p>
                  </div>
                </div>
                <div class="fpw-library-grid">
                  <a class="fpw-library-card" href="#topNavBasePath#/great-loop/locks/" role="menuitem">
                    #renderFpwNavIcon("lock", "fpw-card-icon")#
                    <strong>Lock Library</strong>
                    <span>Lock locations, VHF channels, phone numbers, and notes for 275+ locks.</span>
                    <em aria-hidden="true">&rarr;</em>
                  </a>
                  <a class="fpw-library-card" href="#topNavBasePath#/great-loop/bridges/" role="menuitem">
                    #renderFpwNavIcon("bridge", "fpw-card-icon")#
                    <strong>Bridge Library</strong>
                    <span>Bridge clearances, drawbridge schedules, contacts, and restrictions.</span>
                    <em aria-hidden="true">&rarr;</em>
                  </a>
                  <a class="fpw-library-card" href="#topNavBasePath#/great-loop/ports/" role="menuitem">
                    #renderFpwNavIcon("compass", "fpw-card-icon")#
                    <strong>Ports Library</strong>
                    <span>Great Loop ports, stopping points, maps, filters, and waypoint actions.</span>
                    <em aria-hidden="true">&rarr;</em>
                  </a>
                  <a class="fpw-library-card" href="#topNavBasePath#/great-loop/anchorages/" role="menuitem">
                    #renderFpwNavIcon("anchor", "fpw-card-icon")#
                    <strong>Anchorage Library</strong>
                    <span>Published anchorages, maps, filters, and planning notes.</span>
                    <em aria-hidden="true">&rarr;</em>
                  </a>
                </div>
                <div class="fpw-mega-cta">
                  #renderFpwNavIcon("route-cta", "fpw-cta-icon")#
                  <div>
                    <strong>Planning your Great Loop?</strong>
                    <span>Use our Route Builder</span>
                  </div>
                  <a class="fpw-secondary-cta" href="#topNavBasePath#/app/join.cfm">Start Free <span aria-hidden="true">&rarr;</span></a>
                </div>
              </div>
            </div>
            <div class="fpw-dropdown fpw-dropdown--resources" data-fpw-dropdown>
                <button class="fpw-nav-link fpw-dropdown-toggle<cfif topNavResourcesActive> is-active</cfif>" type="button" aria-expanded="false" aria-haspopup="true" aria-controls="fpwResourcesMenu" data-fpw-dropdown-toggle>
                  #renderFpwNavIcon("checklist", "fpw-nav-icon")#
                  <span>Resources</span>
                  <svg class="fpw-chevron" viewBox="0 0 24 24" aria-hidden="true" focusable="false"><path d="m6 9 6 6 6-6"></path></svg>
                </button>
                <div class="fpw-dropdown-menu fpw-resources-menu" id="fpwResourcesMenu" role="menu">
                  <div class="fpw-resources-grid">
                    <section class="fpw-resource-feature fpw-resource-featured" aria-labelledby="fpwResourceFeaturedTitle">
                      <h2 class="fpw-resource-section-label fpw-resource-featured__heading" id="fpwResourceFeaturedTitle">Featured Guides</h2>
                      <article class="fpw-resource-feature-card fpw-featured-guide">
                        <div class="fpw-resource-feature-summary fpw-featured-guide__main">
                          <div class="fpw-featured-guide__icon">
                            #renderFpwNavIcon("checklist", "fpw-resource-feature-icon")#
                          </div>
                          <div class="fpw-resource-feature-copy fpw-featured-guide__content">
                            <h3 class="fpw-featured-guide__title">Shore Contact Guide</h3>
                            <p class="fpw-featured-guide__description">What to do when a boater misses a check-in or expected return.</p>
                          </div>
                        </div>
                        <a
                          class="fpw-resource-feature-link fpw-featured-guide__button<cfif topNavShoreContactGuideActive> is-active</cfif>"
                          href="#topNavBasePath#/shore-contact-overdue-boater/"
                          role="menuitem"
                          aria-label="Read the Shore Contact Guide"
                          <cfif topNavShoreContactGuideActive>aria-current="page"</cfif>
                          <cfif NOT topNavIsLoggedIn>
                            data-fpw-nav-track="public_nav_shore_contact_guide_click"
                            data-fpw-nav-track-location="public_header"
                            data-fpw-nav-track-menu-group="resources"
                            data-fpw-nav-track-label="Shore Contact Guide"
                            data-fpw-nav-track-destination-key="shore_contact_overdue_boater"
                            data-fpw-nav-track-auth-state="signed_out"
                          </cfif>>
                          <span>Read the Guide</span><b aria-hidden="true">&rarr;</b>
                        </a>
                      </article>

                      <div class="fpw-featured-guide__divider" aria-hidden="true"></div>

                      <article class="fpw-resource-feature-card fpw-featured-guide">
                        <div class="fpw-resource-feature-summary fpw-featured-guide__main">
                          <div class="fpw-featured-guide__icon">
                            #renderFpwNavIcon("kayak", "fpw-resource-feature-icon")#
                          </div>
                          <div class="fpw-resource-feature-copy fpw-featured-guide__content">
                            <h3 class="fpw-featured-guide__title">Solo Boating Safety Guide</h3>
                            <p class="fpw-featured-guide__description">Practical solo boating safety guidance from kayaks to cruisers, with preparation tips and checklists.</p>
                          </div>
                        </div>
                        <a
                          class="fpw-resource-feature-link fpw-featured-guide__button<cfif topNavSoloBoatingGuideActive> is-active</cfif>"
                          href="#topNavBasePath#/solo-boating-safety-guide/"
                          role="menuitem"
                          aria-label="Read the Solo Boating Safety Guide"
                          <cfif topNavSoloBoatingGuideActive>aria-current="page"</cfif>
                          <cfif NOT topNavIsLoggedIn>
                            data-fpw-nav-track="public_nav_solo_boating_safety_guide_click"
                            data-fpw-nav-track-location="public_header"
                            data-fpw-nav-track-menu-group="resources"
                            data-fpw-nav-track-label="Solo Boating Safety Guide"
                            data-fpw-nav-track-destination-key="solo_boating_safety_guide"
                            data-fpw-nav-track-auth-state="signed_out"
                          </cfif>>
                          <span>Read the Guide</span><b aria-hidden="true">&rarr;</b>
                        </a>
                      </article>
                    </section>

                    <div class="fpw-resource-groups">
                      <div class="fpw-resource-group" role="group" aria-labelledby="fpwPlanningToolsTitle">
                        <h2 id="fpwPlanningToolsTitle">Planning Tools</h2>
                        <div class="fpw-resource-items">
                          <a class="fpw-tool-row<cfif topNavFuelActive> is-active</cfif>" href="#topNavBasePath#/boat-fuel-calculator/boat-fuel-calculator.cfm" role="menuitem"<cfif topNavFuelActive> aria-current="page"</cfif>>
                            #renderFpwNavIcon("fuel", "fpw-tool-icon")#
                            <span><strong>Fuel Calculator</strong><em>Estimate fuel usage, range, and costs.</em></span>
                            <b aria-hidden="true">&rarr;</b>
                          </a>
                          <a class="fpw-tool-row<cfif topNavWeatherActive> is-active</cfif>" href="#topNavBasePath#/app/weather.cfm" role="menuitem"<cfif topNavWeatherActive> aria-current="page"</cfif>>
                            #renderFpwNavIcon("weather", "fpw-tool-icon")#
                            <span><strong>Marine Weather</strong><em>Current conditions and extended forecasts.</em></span>
                            <b aria-hidden="true">&rarr;</b>
                          </a>
                        </div>
                      </div>

                      <div class="fpw-resource-group" role="group" aria-labelledby="fpwBoatingResourcesTitle">
                        <h2 id="fpwBoatingResourcesTitle">Boating Resources</h2>
                        <div class="fpw-resource-items">
                          <a class="fpw-resource-link<cfif topNavWhyFloatPlanActive> is-active</cfif>" href="#topNavBasePath#/why-use-a-float-plan.cfm" role="menuitem"<cfif topNavWhyFloatPlanActive> aria-current="page"</cfif>>
                            #renderFpwNavIcon("checklist", "fpw-tool-icon")#
                            <span>Why Use a Float Plan</span><b aria-hidden="true">&rarr;</b>
                          </a>
                          <a class="fpw-resource-link" href="#topNavHowHref#" role="menuitem">
                            #renderFpwNavIcon("how", "fpw-tool-icon")#
                            <span>How It Works</span><b aria-hidden="true">&rarr;</b>
                          </a>
                          <a class="fpw-resource-link<cfif topNavFaqActive> is-active</cfif>" href="#topNavBasePath#/faq/" role="menuitem"<cfif topNavFaqActive> aria-current="page"</cfif>>
                            #renderFpwNavIcon("help", "fpw-tool-icon")#
                            <span>FAQ</span><b aria-hidden="true">&rarr;</b>
                          </a>
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
            </div>
            <cfif NOT topNavIsLoggedIn>
              <a class="fpw-nav-link" href="#topNavBasePath#/app/pricing.cfm">
                #renderFpwNavIcon("pricing", "fpw-nav-icon")#
                <span>Pricing</span>
              </a>
            </cfif>
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
                  #renderFpwNavIcon("user", "fpw-nav-icon")#
                  <span>Account</span>
                  <svg class="fpw-chevron" viewBox="0 0 24 24" aria-hidden="true" focusable="false"><path d="m6 9 6 6 6-6"></path></svg>
                </button>
                <div class="fpw-dropdown-menu fpw-dropdown-menu-right" role="menu">
                  <a href="#topNavBasePath#/app/account.cfm" role="menuitem">
                    #renderFpwNavIcon("user", "fpw-dropdown-icon")#
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
                <span>Start Free</span>
                <span class="fpw-cta-arrow" aria-hidden="true">&rarr;</span>
              </a>
              <a class="fpw-nav-link fpw-login-link" href="#topNavBasePath#/app/login.cfm">
                #renderFpwNavIcon("user", "fpw-nav-icon")#
                <span>Login</span>
              </a>
            </cfif>
          </div>
        </div>
      </div>
    </div>

    <div class="fpw-mobile-backdrop" data-fpw-mobile-backdrop hidden></div>

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

  <script>
    (function () {
      var shell = document.querySelector("[data-fpw-nav]");
      if (!shell || shell.getAttribute("data-fpw-nav-bound") === "true") {
        return;
      }
      shell.setAttribute("data-fpw-nav-bound", "true");

      var menuButton = shell.querySelector("[data-fpw-mobile-toggle]");
      var closeButton = shell.querySelector("[data-fpw-mobile-close]");
      var backdrop = shell.querySelector("[data-fpw-mobile-backdrop]");
      var navMenu = shell.querySelector("[data-fpw-nav-menu]");
      var dropdowns = Array.prototype.slice.call(shell.querySelectorAll("[data-fpw-dropdown]"));
      var logoutLinks = shell.querySelectorAll("[data-fpw-member-logout]");
      var trackedNavLinks = shell.querySelectorAll("[data-fpw-nav-track]");
      var mobileQuery = window.matchMedia("(max-width: 1050px)");
      var previousBodyOverflow = "";

      function isMobileNav() {
        return mobileQuery.matches;
      }

      function setBodyLock(isOpen) {
        if (!document.body) {
          return;
        }
        document.body.classList.toggle("fpw-nav-open", isOpen);
        if (isOpen) {
          if (!previousBodyOverflow) {
            previousBodyOverflow = document.body.style.overflow || "";
          }
          document.body.style.overflow = "hidden";
        } else {
          document.body.style.overflow = previousBodyOverflow;
          previousBodyOverflow = "";
        }
      }

      function setDropdownOpen(dropdown, isOpen, source) {
        var toggle = dropdown ? dropdown.querySelector("[data-fpw-dropdown-toggle]") : null;
        if (!dropdown || !toggle) {
          return;
        }
        dropdown.classList.toggle("is-open", isOpen);
        toggle.setAttribute("aria-expanded", isOpen ? "true" : "false");
        if (isOpen && source === "click") {
          dropdown.setAttribute("data-fpw-click-open", "true");
        } else if (!isOpen) {
          dropdown.removeAttribute("data-fpw-click-open");
        }
      }

      function closeDropdowns(exceptDropdown) {
        dropdowns.forEach(function (dropdown) {
          if (dropdown !== exceptDropdown) {
            setDropdownOpen(dropdown, false);
          }
        });
      }

      function openDropdown(dropdown) {
        closeDropdowns(dropdown);
        setDropdownOpen(dropdown, true);
      }

      function setMenuOpen(isOpen) {
        shell.classList.toggle("is-menu-open", isOpen);
        if (menuButton) {
          menuButton.setAttribute("aria-expanded", isOpen ? "true" : "false");
          menuButton.setAttribute("aria-label", isOpen ? "Close menu" : "Open menu");
        }
        if (backdrop) {
          backdrop.hidden = !isOpen;
        }
        setBodyLock(isOpen);
        if (!isOpen) {
          closeDropdowns();
        }
      }

      function blurActiveNavElement() {
        var activeElement = document.activeElement;
        if (activeElement && shell.contains(activeElement) && typeof activeElement.blur === "function") {
          activeElement.blur();
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

      function trackPublicNavClick(link) {
        var eventName = link ? link.getAttribute("data-fpw-nav-track") : "";
        if (!eventName) {
          return;
        }

        try {
          var fields = {
            source_page: window.location.pathname || "",
            nav_location: link.getAttribute("data-fpw-nav-track-location") || "",
            menu_group: link.getAttribute("data-fpw-nav-track-menu-group") || "",
            label: link.getAttribute("data-fpw-nav-track-label") || "",
            destination_key: link.getAttribute("data-fpw-nav-track-destination-key") || "",
            auth_state: link.getAttribute("data-fpw-nav-track-auth-state") || ""
          };

          if (window.FPWAnalytics && typeof window.FPWAnalytics.track === "function") {
            window.FPWAnalytics.track(eventName, fields);
          } else if (typeof window.gtag === "function") {
            window.gtag("event", eventName, fields);
          } else if (Array.isArray(window.dataLayer)) {
            fields.event = eventName;
            window.dataLayer.push(fields);
          }
        } catch (error) {}
      }

      if (menuButton && navMenu) {
        menuButton.addEventListener("click", function () {
          setMenuOpen(!shell.classList.contains("is-menu-open"));
        });
      }

      if (closeButton) {
        closeButton.addEventListener("click", function () {
          setMenuOpen(false);
        });
      }

      if (backdrop) {
        backdrop.addEventListener("click", function () {
          setMenuOpen(false);
        });
      }

      dropdowns.forEach(function (dropdown) {
        var toggle = dropdown.querySelector("[data-fpw-dropdown-toggle]");
        if (!toggle) {
          return;
        }

        dropdown.addEventListener("mouseenter", function () {
          if (!isMobileNav()) {
            openDropdown(dropdown);
          }
        });

        dropdown.addEventListener("mouseleave", function () {
          if (!isMobileNav()) {
            setDropdownOpen(dropdown, false);
          }
        });

        dropdown.addEventListener("focusin", function () {
          if (!isMobileNav()) {
            openDropdown(dropdown);
          }
        });

        dropdown.addEventListener("focusout", function () {
          window.setTimeout(function () {
            if (!isMobileNav() && !dropdown.contains(document.activeElement)) {
              setDropdownOpen(dropdown, false);
            }
          }, 0);
        });

        toggle.addEventListener("click", function (event) {
          event.preventDefault();
          var isOpen = dropdown.classList.contains("is-open");
          var isClickOpen = dropdown.getAttribute("data-fpw-click-open") === "true";
          if (isMobileNav()) {
            setDropdownOpen(dropdown, !isOpen, "click");
          } else {
            closeDropdowns(dropdown);
            setDropdownOpen(dropdown, !isClickOpen, "click");
          }
        });
      });

      if (navMenu) {
        Array.prototype.forEach.call(navMenu.querySelectorAll("a"), function (link) {
          link.addEventListener("click", function () {
            if (isMobileNav()) {
              setMenuOpen(false);
            }
          });
        });
      }

      Array.prototype.forEach.call(logoutLinks, function (logoutLink) {
        logoutLink.addEventListener("click", runLogout);
      });

      Array.prototype.forEach.call(trackedNavLinks, function (trackedNavLink) {
        trackedNavLink.addEventListener("click", function () {
          trackPublicNavClick(trackedNavLink);
        });
      });

      document.addEventListener("click", function (event) {
        if (!shell.contains(event.target)) {
          setMenuOpen(false);
          closeDropdowns();
        }
      });

      document.addEventListener("keydown", function (event) {
        if (event.key === "Escape") {
          setMenuOpen(false);
          closeDropdowns();
          blurActiveNavElement();
        }
      });

      window.addEventListener("resize", function () {
        if (!isMobileNav()) {
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
    <script src="#topNavBasePath#/assets/js/app/api.js?v=20260722-phase3-cutover-pdf"></script>
    <script src="#topNavBasePath#/assets/js/app/auth.js?v=20260526-cache-bump"></script>
    <script src="#topNavBasePath#/assets/js/app/core.js"></script>
  </cfif>
</cfoutput>
