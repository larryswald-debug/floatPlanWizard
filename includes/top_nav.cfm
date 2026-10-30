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
topNavBoatingSafetyActive = false;
topNavSoloBoatingGuideActive = false;
topNavCommonBoatingEmergenciesActive = false;
topNavShoreContactGuideActive = false;
topNavUserManualActive = false;
topNavWhyFloatPlanActive = false;
topNavFaqActive = false;
topNavFuelActive = false;
topNavBoatLoanActive = false;
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
  { "pattern" = "/boat-loan-calculator", "active" = "resources-boat-loan-calculator" },
  { "pattern" = "/solo-boating-safety-guide", "active" = "resources-solo-boating-guide" },
  { "pattern" = "/common-boating-emergencies", "active" = "resources-common-boating-emergencies" },
  { "pattern" = "/shore-contact-overdue-boater", "active" = "resources-shore-contact-guide" },
  { "pattern" = "/why-use-a-float-plan", "active" = "resources-why-float-plan" },
  { "pattern" = "/boating-guides/chesapeake-bay", "active" = "resources-chesapeake-guide" },
  { "pattern" = "/faq/", "active" = "resources-faq" }
];

if (!len(topNavActive) OR topNavActive EQ "resources") {
  for (topNavResourceRouteIndex = 1; topNavResourceRouteIndex LTE arrayLen(topNavResourceRouteMap); topNavResourceRouteIndex++) {
    if (findNoCase(topNavResourceRouteMap[topNavResourceRouteIndex].pattern, topNavRequestPath)) {
      topNavActive = topNavResourceRouteMap[topNavResourceRouteIndex].active;
      break;
    }
  }
}

topNavUserManualActive = reFindNoCase("/app/user-manual\.cfm$", topNavRequestPath) GT 0;

topNavResourcesActive = listFindNoCase(
  "resources,resources-boat-loan-calculator,resources-solo-boating-guide,resources-common-boating-emergencies,resources-shore-contact-guide,resources-why-float-plan,resources-chesapeake-guide,resources-faq,fuel,weather",
  topNavActive
) GT 0;
topNavSoloBoatingGuideActive = topNavActive EQ "resources-solo-boating-guide";
topNavCommonBoatingEmergenciesActive = topNavActive EQ "resources-common-boating-emergencies";
topNavShoreContactGuideActive = topNavActive EQ "resources-shore-contact-guide";
topNavBoatingSafetyActive = topNavSoloBoatingGuideActive OR topNavCommonBoatingEmergenciesActive OR topNavShoreContactGuideActive;
topNavWhyFloatPlanActive = topNavActive EQ "resources-why-float-plan";
topNavChesapeakeGuideActive = topNavActive EQ "resources-chesapeake-guide";
topNavFaqActive = topNavActive EQ "resources-faq";
topNavFuelActive = topNavActive EQ "fuel";
topNavBoatLoanActive = topNavActive EQ "resources-boat-loan-calculator";
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

  if (!(structKeyExists(request, "fpwTripPreview") AND request.fpwTripPreview)) {
    try {
      topNavAccess = new fpw.api.v1.MemberEntitlementService().init("fpw").getCurrentAccess(topNavUserId);
      if (structKeyExists(topNavAccess, "hasPremium") AND topNavAccess.hasPremium EQ true) {
        topNavHasPremium = true;
      }
    } catch (any topNavAccessError) {
      topNavHasPremium = false;
    }
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
    case "message-circle":
      iconPaths = '<path d="M42 23a18 18 0 0 1-18 18c-3 0-6-.7-8.5-2L5 43l4-10.5A18 18 0 1 1 42 23z"></path>';
      break;
    case "mail":
      iconPaths = '<rect x="6" y="11" width="36" height="27" rx="3"></rect><path d="m7 13 17 13 17-13"></path><path d="m7 36 12-12M41 36 29 24"></path>';
      break;
    case "lightbulb":
      iconPaths = '<path d="M17 32c0-6-7-8-7-16a14 14 0 1 1 28 0c0 8-7 10-7 16z"></path><path d="M17 38h14M20 44h8"></path>';
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
    case "calculator":
      iconClass = iconClass & " fpw-icon-calculator";
      iconViewBox = "0 0 64 64";
      iconPaths = '<rect x="14" y="6" width="36" height="52" rx="4"></rect><rect x="21" y="13" width="22" height="12" rx="1"></rect><path d="M22 34h2M31 34h2M40 34h2M22 42h2M31 42h2M40 42h2M22 50h2M31 50h2M40 50h2"></path>';
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
    case "book-open":
      iconClass = iconClass & " fpw-icon-book-open";
      iconViewBox = "0 0 64 64";
      iconPaths = '<path d="M32 16C24 10 15 9 6 12v38c9-3 18-2 26 4 8-6 17-7 26-4V12c-9-3-18-2-26 4z"></path><path d="M32 16v38"></path><path d="M13 22c4-1 8 0 12 2M13 30c4-1 8 0 12 2M13 38c4-1 8 0 12 2M39 24c4-2 8-3 12-2M39 32c4-2 8-3 12-2M39 40c4-2 8-3 12-2"></path>';
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


// Approved navigation asset paths; color and rendered stroke weight are supplied by the header CSS.
function renderFpwApprovedNavIcon(required string name, string className = "") {
  var viewBox = "0 0 64 64";
  var paths = "";
  switch (arguments.name) {
    case "plan":
      viewBox = "0 0 64 64";
      paths = '<path d="m5 10 10-4 12 5 12-5 12 5 8-4v43l-10 4-12-5-12 5-10-5zM15 6v43M39 6v43"/>';
      break;
    case "explore":
      viewBox = "0 0 64 64";
      paths = '<path d="m5 9 16-5 21 8 17-6v49l-17 6-21-8-16 5zM21 4v49M42 12v49"/>';
      break;
    case "learn":
      viewBox = "0 0 64 64";
      paths = '<path d="M21 47v-6c-11-7-16-17-12-27 5-15 29-17 39-4 9 13 1 25-8 31v6zM22 55h18M25 61h12"/>';
      break;
    case "tools":
      viewBox = "0 0 64 64";
      paths = '<path d="M13 7c-1 9 5 13 13 12l25 28a7 7 0 0 1-10 10L18 29C10 30 4 22 7 13l7 7 8-2zM52 6l6 6-18 18-7-7zM8 57l21-21"/>';
      break;
    case "help":
      viewBox = "0 0 64 64";
      paths = '<circle cx="32" cy="32" r="26"/><path d="M23 22c0-14 22-15 22-1 0 11-13 10-13 20M32 49v2"/>';
      break;
    case "user":
      viewBox = "0 0 64 64";
      paths = '<circle cx="32" cy="18" r="11"/><path d="M10 57v-8c0-13 12-20 22-20s22 7 22 20v8z"/>';
      break;
    case "ship":
      viewBox = "0 0 64 64";
      paths = '<path d="M14 28h36l8 13-26 13L6 41zM23 28V15h18v13M32 15V6M6 58c8 4 15 4 23 0 8 4 16 4 29 0"/>';
      break;
    case "anchor":
      viewBox = "0 0 64 64";
      paths = '<circle cx="32" cy="9" r="6"/><path d="M32 15v42M20 25h24M9 39c-1 15 11 22 23 18 12 4 24-3 23-18M9 39l-5 7M55 39l5 7"/>';
      break;
    case "bridge":
      viewBox = "0 0 64 64";
      paths = '<path d="M5 40h54M11 40V18M53 40V18M11 24h42M16 40c2-15 7-20 16-20s14 5 16 20M5 51h54"/>';
      break;
    case "lock":
      viewBox = "0 0 64 64";
      paths = '<rect x="13" y="29" width="38" height="30" rx="4"/><path d="M20 29V20a12 12 0 0 1 24 0v9M32 40v10"/>';
      break;
    case "pin":
      viewBox = "0 0 64 64";
      paths = '<path d="M32 61s-21-23-21-39a21 21 0 0 1 42 0c0 16-21 39-21 39z"/><circle cx="32" cy="23" r="7"/>';
      break;
    case "waves":
      viewBox = "0 0 64 64";
      paths = '<path d="M4 17c8 0 8 7 16 7s8-7 16-7 8 7 16 7 8-7 8-7M4 32c8 0 8 7 16 7s8-7 16-7 8 7 16 7 8-7 8-7M4 47c8 0 8 7 16 7s8-7 16-7 8 7 16 7 8-7 8-7"/>';
      break;
    case "search":
      viewBox = "0 0 64 64";
      paths = '<circle cx="27" cy="27" r="18"/><path d="m41 41 17 17"/>';
      break;
    case "document":
      viewBox = "0 0 64 64";
      paths = '<path d="M16 5h24l11 11v43H16zM40 5v13h11M23 29h19M23 38h19M23 47h12"/>';
      break;
    case "route-planning":
      viewBox = "0 0 24 24";
      paths = '<circle cx="4.5" cy="5" r="2"/><circle cx="19" cy="18" r="2"/><path d="M6.5 5H16a3 3 0 0 1 0 6H8a3.5 3.5 0 1 0 0 7h9"/><path d="m13 2 3 3-3 3"/>';
      break;
    case "float-plan":
      viewBox = "0 0 24 24";
      paths = '<rect x="5" y="4" width="14" height="18" rx="2"/><path d="M9 4V2h6v2M8.5 10l1.5 1.5 3-3M8.5 16h7M8.5 19h5"/>';
      break;
    case "boat-vessel":
      viewBox = "0 0 24 24";
      paths = '<path d="M4 15 12 20l8-5-2-7H6z"/><path d="M12 8V2m0 2 4 4m-4-4L8 8M2 22c2 0 3-2 5-2s3 2 5 2 3-2 5-2 3 2 5 2"/>';
      break;
    case "mileage-override":
      viewBox = "0 0 24 24";
      paths = '<path d="M3 17.5 8 13l3 2 6-7 4 3"/><path d="M15 4h6v6M4 21h16"/><path d="M3 7h7M3 10h4"/>';
      break;
    case "fuel-pump":
      viewBox = "0 0 24 24";
      paths = '<path d="M5 21V5a2 2 0 0 1 2-2h8a2 2 0 0 1 2 2v16M3 21h16M7 7h8v6H7z"/><path d="M17 9h2l2 3v6a2 2 0 0 1-4 0v-2"/><path d="m19 9 2 3"/>';
      break;
    case "calculator":
      viewBox = "0 0 24 24";
      paths = '<rect x="5" y="2.5" width="14" height="19" rx="2"/><rect x="8" y="5.5" width="8" height="4" rx=".5"/><path d="M8.5 13h1m4 0h1m-6 3.5h1m4 0h1M8.5 20h1m4 0h1" stroke-width="2.4"/>';
      break;
    case "marine-weather":
      viewBox = "0 0 24 24";
      paths = '<path d="M7.2 18.5H17a4 4 0 1 0-.8-7.9 6 6 0 0 0-11.1 2.6A3 3 0 0 0 7.2 18.5Z"/><path d="M4 5.5 2.7 4M11 2v2M3 9H1M17 3.5l-1.2 1.2"/><path d="M7 21h9"/>';
      break;
    case "clock":
      viewBox = "0 0 24 24";
      paths = '<circle cx="12" cy="12" r="9"/><path d="M12 6.5V12l4 2.5"/>';
      break;
    default:
      return "";
  }
  return '<svg class="fpw-approved-icon ' & encodeForHTMLAttribute(arguments.className) & '" data-fpw-approved-icon="' & encodeForHTMLAttribute(arguments.name) & '" viewBox="' & viewBox & '" fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" focusable="false">' & paths & '</svg>';
}

topNavPlanActive = listFindNoCase("dashboard,active-cruise", topNavActive) GT 0;
topNavExploreActive = topNavChesapeakeGuideActive OR listFindNoCase("explore-guides,explore-legs", topNavActive) GT 0 OR findNoCase("/great-loop/", topNavRequestPath) GT 0 OR findNoCase("/great-loop-", topNavRequestPath) GT 0;
topNavLearnActive = topNavBoatingSafetyActive OR topNavWhyFloatPlanActive OR findNoCase("/how-it-works", topNavRequestPath) GT 0;
topNavToolsActive = topNavFuelActive OR topNavBoatLoanActive OR topNavWeatherActive;

topNavHelpActive = listFindNoCase("help,help-contact,help-support,help-feedback", topNavActive) GT 0 OR topNavUserManualActive OR topNavFaqActive;
topNavHelpPage = topNavActive;
if (structKeyExists(request, "fpwTopNavHelpPage")) {
  topNavHelpPage = lCase(trim(toString(request.fpwTopNavHelpPage)));
}
topNavHelpSections = {
  "dashboard" = "1-find-your-way-around-fpw",
  "completed-trip" = "23-view-the-completed-trip-record",
  "active-cruise" = "18-read-active-cruise",
  "monitoring" = "19-check-in-and-understand-monitoring",
  "weather" = "13-use-weather-in-planning-and-underway",
  "fuel" = "14-use-the-linked-fuel-and-range-calculator"
};

topNavShowAppSubnav = topNavIsLoggedIn
  AND listFindNoCase("dashboard,active-cruise,monitoring,weather,fuel", topNavActive) GT 0;
</cfscript>

<cfoutput>
  <header class="fpw-site-header fpw-nav-v2<cfif topNavIsLoggedIn> fpw-site-header--logged-in</cfif><cfif topNavShowAppSubnav> fpw-site-header--app</cfif>" role="banner" data-fpw-nav>
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
              <span>FloatPlanWizard</span>
            </a>
            <button class="fpw-mobile-close" type="button" aria-label="Close menu" data-fpw-mobile-close>&times;</button>
          </div>

          <nav class="fpw-primary-nav<cfif topNavIsLoggedIn> fpw-primary-nav--member</cfif>" aria-label="Primary navigation">
            <div class="fpw-dropdown fpw-dropdown--plan" data-fpw-dropdown><button class="fpw-nav-link fpw-dropdown-toggle<cfif topNavPlanActive> is-active</cfif>" id="fpwPlanToggle" type="button" aria-expanded="false" aria-controls="fpwPlanMenu" data-fpw-dropdown-toggle>#renderFpwApprovedNavIcon("plan", "fpw-nav-icon")#<span>Plan a Trip</span><svg class="fpw-chevron" viewBox="0 0 24 24" aria-hidden="true" focusable="false"><path d="m6 9 6 6 6-6"></path></svg></button><div class="fpw-dropdown-menu fpw-plan-menu" id="fpwPlanMenu" aria-labelledby="fpwPlanToggle" hidden><div class="fpw-menu-scroll"><div class="fpw-menu-heading">#renderFpwApprovedNavIcon("route-planning", "")#<div><h2>Plan a Trip</h2><p>Everything you need to prepare and share a boating trip.</p></div></div>
            <a class="fpw-menu-row" href="#topNavBasePath#/app/dashboard.cfm?recoveryAction=planner">#renderFpwApprovedNavIcon("route-planning", "fpw-menu-row-icon fpw-icon--yellow")#<span><strong>Route &amp; Trip Generator</strong><small>Build and customize your route.</small></span><span class="fpw-menu-arrow" aria-hidden="true">&rarr;</span></a>
            <a class="fpw-menu-row" href="#topNavBasePath#/app/dashboard.cfm?recoveryAction=routes">#renderFpwApprovedNavIcon("route-planning", "fpw-menu-row-icon fpw-icon--yellow")#<span><strong>My Routes</strong><small>View and manage saved routes.</small></span><span class="fpw-menu-arrow" aria-hidden="true">&rarr;</span></a>
            <a class="fpw-menu-row" href="<cfif topNavIsLoggedIn>#topNavBasePath#/app/dashboard.cfm##vesselsPanel<cfelse>#topNavBasePath#/app/dashboard.cfm</cfif>" <cfif NOT topNavIsLoggedIn>data-fpw-auth-intent="dashboard" data-fpw-auth-source-page="top_nav" data-fpw-auth-section="top_nav" data-fpw-auth-cta-type="account" data-fpw-auth-label="My Vessels"</cfif>>#renderFpwApprovedNavIcon("ship", "fpw-menu-row-icon fpw-icon--yellow")#<span><strong>My Vessels</strong><small>Manage vessel specs.</small></span><span class="fpw-menu-arrow" aria-hidden="true">&rarr;</span></a>
            <a class="fpw-menu-row fpw-menu-row--separator" href="#topNavBasePath#/app/dashboard.cfm?recoveryAction=plans">#renderFpwApprovedNavIcon("float-plan", "fpw-menu-row-icon fpw-icon--orange")#<span><strong>Float Plan Workspace</strong><small>View and continue your float plans.</small></span><span class="fpw-menu-arrow" aria-hidden="true">&rarr;</span></a>
            <a class="fpw-menu-row" href="#topNavBasePath#/app/active-cruise.cfm" <cfif topNavActive EQ 'active-cruise'>aria-current="page"</cfif>>#renderFpwApprovedNavIcon("boat-vessel", "fpw-menu-row-icon")#<span><strong>Active Cruise</strong><small>Monitor your trip in real time.</small></span><span class="fpw-menu-arrow" aria-hidden="true">&rarr;</span></a>
            <a class="fpw-menu-row" href="#topNavBasePath#/help/##follow">#renderFpwApprovedNavIcon("pin", "fpw-menu-row-icon")#<span><strong>How to Follow a Trip</strong><small>Learn how to view a shared trip.</small></span><span class="fpw-menu-arrow" aria-hidden="true">&rarr;</span></a>
            </div></div></div>
            <div class="fpw-dropdown fpw-dropdown--explore" data-fpw-dropdown><button class="fpw-nav-link fpw-dropdown-toggle<cfif topNavExploreActive> is-active</cfif>" id="fpwExploreToggle" type="button" aria-expanded="false" aria-controls="fpwExploreMenu" data-fpw-dropdown-toggle>#renderFpwApprovedNavIcon("explore", "fpw-nav-icon")#<span>Explore</span><svg class="fpw-chevron" viewBox="0 0 24 24" aria-hidden="true" focusable="false"><path d="m6 9 6 6 6-6"></path></svg></button><div class="fpw-dropdown-menu fpw-explore-menu" id="fpwExploreMenu" aria-labelledby="fpwExploreToggle" hidden><div class="fpw-menu-scroll"><div class="fpw-explore-grid"><section class="fpw-explore-guides" aria-labelledby="fpwCruisingGuidesTitle"><h2 id="fpwCruisingGuidesTitle">#renderFpwApprovedNavIcon("explore", "")#Cruising Guides</h2>
            <a class="fpw-guide-menu-card" href="#topNavBasePath#/boating-guides/chesapeake-bay/" <cfif topNavChesapeakeGuideActive>aria-current="page"</cfif>><img src="#topNavBasePath#/assets/images/navigation/thumb-chesapeake.jpg" width="116" height="92" alt=""><span><strong>Chesapeake Bay Cruising Guide</strong><small>Routes, destinations, travel times and more.</small></span></a>
            <a class="fpw-guide-menu-card" href="#topNavBasePath#/great-loop/trip-planning/" <cfif findNoCase('/great-loop/trip-planning', topNavRequestPath) GT 0>aria-current="page"</cfif>><img src="#topNavBasePath#/assets/images/navigation/thumb-greatloop.jpg" width="116" height="92" alt=""><span><strong>Great Loop Planning Guide</strong><small>Plan your entire loop with FPW.</small></span></a>
            <a class="fpw-menu-row fpw-menu-row--separator" href="#topNavBasePath#/boating-guides/" <cfif topNavActive EQ 'explore-guides'>aria-current="page"</cfif>>#renderFpwApprovedNavIcon("document", "fpw-menu-row-icon")#<span><strong>All Cruising Guides</strong></span><span class="fpw-menu-arrow" aria-hidden="true">&rarr;</span></a></section><section class="fpw-explore-libraries" aria-labelledby="fpwLoopLibrariesTitle"><h2 id="fpwLoopLibrariesTitle">#renderFpwApprovedNavIcon("pin", "")#Great Loop Libraries</h2>
            <a class="fpw-menu-row" href="#topNavBasePath#/great-loop/ports/" <cfif findNoCase('/great-loop/ports/', topNavRequestPath) GT 0>aria-current="page"</cfif>>#renderFpwApprovedNavIcon("ship", "fpw-menu-row-icon")#<span><strong>Ports</strong></span><span class="fpw-menu-arrow" aria-hidden="true">&rarr;</span></a>
            <a class="fpw-menu-row" href="#topNavBasePath#/great-loop/anchorages/" <cfif findNoCase('/great-loop/anchorages/', topNavRequestPath) GT 0>aria-current="page"</cfif>>#renderFpwApprovedNavIcon("anchor", "fpw-menu-row-icon")#<span><strong>Anchorages</strong></span><span class="fpw-menu-arrow" aria-hidden="true">&rarr;</span></a>
            <a class="fpw-menu-row" href="#topNavBasePath#/great-loop/bridges/" <cfif findNoCase('/great-loop/bridges/', topNavRequestPath) GT 0>aria-current="page"</cfif>>#renderFpwApprovedNavIcon("bridge", "fpw-menu-row-icon")#<span><strong>Bridges</strong></span><span class="fpw-menu-arrow" aria-hidden="true">&rarr;</span></a>
            <a class="fpw-menu-row" href="#topNavBasePath#/great-loop/locks/" <cfif findNoCase('/great-loop/locks/', topNavRequestPath) GT 0>aria-current="page"</cfif>>#renderFpwApprovedNavIcon("lock", "fpw-menu-row-icon")#<span><strong>Locks</strong></span><span class="fpw-menu-arrow" aria-hidden="true">&rarr;</span></a>
            <a class="fpw-menu-row" href="#topNavBasePath#/fpw_great_loop_clockwise/"<cfif topNavActive EQ "explore-legs"> aria-current="page"</cfif>>#renderFpwApprovedNavIcon("waves", "fpw-menu-row-icon")#<span><strong>Great Loop Waterway Legs</strong></span><span class="fpw-menu-arrow" aria-hidden="true">&rarr;</span></a>
            </section></div></div></div></div>
            <div class="fpw-dropdown fpw-dropdown--learn" data-fpw-dropdown><button class="fpw-nav-link fpw-dropdown-toggle<cfif topNavLearnActive> is-active</cfif>" id="fpwLearnToggle" type="button" aria-expanded="false" aria-controls="fpwLearnMenu" data-fpw-dropdown-toggle>#renderFpwApprovedNavIcon("learn", "fpw-nav-icon")#<span>Learn</span><svg class="fpw-chevron" viewBox="0 0 24 24" aria-hidden="true" focusable="false"><path d="m6 9 6 6 6-6"></path></svg></button><div class="fpw-dropdown-menu fpw-learn-menu" id="fpwLearnMenu" aria-labelledby="fpwLearnToggle" hidden><div class="fpw-menu-scroll"><div class="fpw-menu-columns"><section aria-labelledby="fpwBoatingSafetyTitle"><h2 id="fpwBoatingSafetyTitle"><a class="fpw-resource-section-link" href="#topNavBasePath#/solo-boating-safety-guide/" <cfif NOT topNavIsLoggedIn>data-fpw-nav-track="public_nav_boating_safety_click" data-fpw-nav-track-location="public_header" data-fpw-nav-track-menu-group="resources" data-fpw-nav-track-label="Boating Safety" data-fpw-nav-track-destination-key="solo_boating_safety_guide" data-fpw-nav-track-auth-state="signed_out"</cfif>>Boating Safety</a></h2>
            <a class="fpw-menu-row" href="#topNavBasePath#/solo-boating-safety-guide/" <cfif topNavSoloBoatingGuideActive>aria-current="page"</cfif> <cfif NOT topNavIsLoggedIn>data-fpw-nav-track="public_nav_solo_boating_safety_guide_click" data-fpw-nav-track-location="public_header" data-fpw-nav-track-menu-group="resources" data-fpw-nav-track-label="Solo Boating Safety Guide" data-fpw-nav-track-destination-key="solo_boating_safety_guide" data-fpw-nav-track-auth-state="signed_out"</cfif>>#renderFpwApprovedNavIcon("ship", "fpw-menu-row-icon")#<span><strong>Solo Boating Safety</strong><small>Prepare for a safer solo trip.</small></span><span class="fpw-menu-arrow" aria-hidden="true">&rarr;</span></a>
            <a class="fpw-menu-row" href="#topNavBasePath#/shore-contact-overdue-boater/" <cfif topNavShoreContactGuideActive>aria-current="page"</cfif> <cfif NOT topNavIsLoggedIn>data-fpw-nav-track="public_nav_shore_contact_guide_click" data-fpw-nav-track-location="public_header" data-fpw-nav-track-menu-group="resources" data-fpw-nav-track-label="Shore Contact Guide" data-fpw-nav-track-destination-key="shore_contact_overdue_boater" data-fpw-nav-track-auth-state="signed_out"</cfif>>#renderFpwApprovedNavIcon("document", "fpw-menu-row-icon")#<span><strong>Shore Contact Guide</strong><small>What to do when a boater misses a check-in or expected return.</small></span><span class="fpw-menu-arrow" aria-hidden="true">&rarr;</span></a>
            <a class="fpw-menu-row" href="#topNavBasePath#/common-boating-emergencies/" <cfif topNavCommonBoatingEmergenciesActive>aria-current="page"</cfif> <cfif NOT topNavIsLoggedIn>data-fpw-nav-track="public_nav_common_boating_emergencies_click" data-fpw-nav-track-location="public_header" data-fpw-nav-track-menu-group="resources" data-fpw-nav-track-label="Common Boating Emergencies" data-fpw-nav-track-destination-key="common_boating_emergencies" data-fpw-nav-track-auth-state="signed_out"</cfif>>#renderFpwApprovedNavIcon("help", "fpw-menu-row-icon")#<span><strong>Boating Emergencies</strong><small>Prepare for common situations afloat.</small></span><span class="fpw-menu-arrow" aria-hidden="true">&rarr;</span></a>
            </section><section aria-labelledby="fpwUsingFpwTitle"><h2 id="fpwUsingFpwTitle">Using FPW</h2>
            <a class="fpw-menu-row" href="#topNavBasePath#/why-use-a-float-plan/" <cfif topNavWhyFloatPlanActive>aria-current="page"</cfif>>#renderFpwApprovedNavIcon("document", "fpw-menu-row-icon")#<span><strong>Why Use a Float Plan</strong><small>Understand the purpose of a float plan.</small></span><span class="fpw-menu-arrow" aria-hidden="true">&rarr;</span></a>
            <a class="fpw-menu-row" href="#topNavHowHref#">#renderFpwApprovedNavIcon("plan", "fpw-menu-row-icon")#<span><strong>How FPW Works</strong><small>Plan, share, and manage your trip.</small></span><span class="fpw-menu-arrow" aria-hidden="true">&rarr;</span></a>
            <a class="fpw-menu-row" href="#topNavBasePath#/##fpwProductPreview">#renderFpwApprovedNavIcon("tools", "fpw-menu-row-icon")#<span><strong>Features</strong><small>Explore FloatPlanWizard.</small></span><span class="fpw-menu-arrow" aria-hidden="true">&rarr;</span></a>
            </section></div></div></div></div>
            <div class="fpw-dropdown fpw-dropdown--tools" data-fpw-dropdown><button class="fpw-nav-link fpw-dropdown-toggle<cfif topNavToolsActive> is-active</cfif>" id="fpwToolsToggle" type="button" aria-expanded="false" aria-controls="fpwToolsMenu" data-fpw-dropdown-toggle>#renderFpwApprovedNavIcon("tools", "fpw-nav-icon")#<span>Tools</span><svg class="fpw-chevron" viewBox="0 0 24 24" aria-hidden="true" focusable="false"><path d="m6 9 6 6 6-6"></path></svg></button><div class="fpw-dropdown-menu fpw-tools-menu" id="fpwToolsMenu" aria-labelledby="fpwToolsToggle" hidden><div class="fpw-menu-scroll"><div class="fpw-menu-heading">#renderFpwApprovedNavIcon("tools", "")#<div><h2>Tools</h2><p>Calculators and information to help make planning decisions.</p></div></div>
            <a class="fpw-menu-row" href="#topNavBasePath#/boat-fuel-calculator/" <cfif topNavFuelActive>aria-current="page"</cfif>>#renderFpwApprovedNavIcon("fuel-pump", "fpw-menu-row-icon fpw-icon--yellow")#<span><strong>Fuel Calculator</strong><small>Estimate fuel usage, range and costs.</small></span><span class="fpw-menu-arrow" aria-hidden="true">&rarr;</span></a>
            <a class="fpw-menu-row" href="#topNavBasePath#/boat-loan-calculator/" <cfif topNavBoatLoanActive>aria-current="page"</cfif>>#renderFpwApprovedNavIcon("calculator", "fpw-menu-row-icon")#<span><strong>Boat Loan &amp; Ownership Calculator</strong><small>Estimate payments and costs.</small></span><span class="fpw-menu-arrow" aria-hidden="true">&rarr;</span></a>
            <a class="fpw-menu-row fpw-menu-row--separator" href="#topNavBasePath#/app/weather.cfm" <cfif topNavWeatherActive>aria-current="page"</cfif>>#renderFpwApprovedNavIcon("marine-weather", "fpw-menu-row-icon")#<span><strong>Marine Weather</strong><small>Current conditions and forecasts.</small></span><span class="fpw-menu-arrow" aria-hidden="true">&rarr;</span></a>
            <a class="fpw-menu-row" href="#topNavBasePath#/app/user-manual.cfm##12-understand-the-cruise-timeline-time-and-fuel-estimates">#renderFpwApprovedNavIcon("clock", "fpw-menu-row-icon")#<span><strong>Route Timing Guide</strong><small>Understand travel time and daily legs.</small></span><span class="fpw-menu-arrow" aria-hidden="true">&rarr;</span></a>
            <a class="fpw-menu-row" href="#topNavBasePath#/great-loop/trip-planning/##mileage-override">#renderFpwApprovedNavIcon("mileage-override", "fpw-menu-row-icon")#<span><strong>Mileage Override Guide</strong><small>When and how to adjust distances.</small></span><span class="fpw-menu-arrow" aria-hidden="true">&rarr;</span></a>
            </div></div></div>
            <div class="fpw-dropdown fpw-dropdown--help fpw-help-dropdown" data-fpw-dropdown data-fpw-help-dropdown><button class="fpw-nav-link fpw-dropdown-toggle<cfif topNavHelpActive> is-active</cfif>" id="fpwHelpToggle" type="button" aria-expanded="false" aria-controls="fpwHelpMenu" data-fpw-dropdown-toggle>#renderFpwApprovedNavIcon("help", "fpw-nav-icon")#<span>Help</span><svg class="fpw-chevron" viewBox="0 0 24 24" aria-hidden="true" focusable="false"><path d="m6 9 6 6 6-6"></path></svg></button><div class="fpw-dropdown-menu fpw-help-menu" id="fpwHelpMenu" aria-labelledby="fpwHelpToggle" hidden><div class="fpw-menu-scroll"><div class="fpw-menu-heading">#renderFpwApprovedNavIcon("help", "")#<div><h2>Help</h2><p>Guidance and support for your planning.</p></div></div>
            <a class="fpw-menu-row" href="#topNavBasePath#/help/" <cfif topNavActive EQ 'help' AND NOT topNavUserManualActive>aria-current="page"</cfif>>#renderFpwApprovedNavIcon("explore", "fpw-menu-row-icon")#<span><strong>Help Center</strong><small>Guides, tutorials, and frequently asked questions.</small></span><span class="fpw-menu-arrow" aria-hidden="true">&rarr;</span></a>
            <a class="fpw-menu-row" href="#topNavBasePath#/app/user-manual.cfm" <cfif topNavUserManualActive>aria-current="page"</cfif>>#renderFpwApprovedNavIcon("document", "fpw-menu-row-icon")#<span><strong>User Manual</strong><small>Step-by-step instructions for FloatPlanWizard.</small></span><span class="fpw-menu-arrow" aria-hidden="true">&rarr;</span></a>
            <a class="fpw-menu-row fpw-menu-row--separator" href="#topNavBasePath#/faq/" <cfif topNavFaqActive>aria-current="page"</cfif>>#renderFpwApprovedNavIcon("help", "fpw-menu-row-icon")#<span><strong>FAQ</strong><small>Answers to common questions.</small></span><span class="fpw-menu-arrow" aria-hidden="true">&rarr;</span></a>
            <a class="fpw-menu-row" href="#topNavBasePath#/app/contact.cfm" <cfif topNavActive EQ 'help-contact'>aria-current="page"</cfif>>#renderFpwApprovedNavIcon("help", "fpw-menu-row-icon")#<span><strong>Contact Support</strong><small>Contact the FloatPlanWizard team.</small></span><span class="fpw-menu-arrow" aria-hidden="true">&rarr;</span></a>
            <a class="fpw-menu-row fpw-menu-row--separator" href="#topNavBasePath#/app/contact.cfm?mode=support##contactForm" <cfif topNavActive EQ 'help-support'>aria-current="page"</cfif>>#renderFpwApprovedNavIcon("document", "fpw-menu-row-icon")#<span><strong>Submit a Support Request</strong><small>Report a problem or request assistance.</small></span><span class="fpw-menu-arrow" aria-hidden="true">&rarr;</span></a>
            <a class="fpw-menu-row" href="#topNavBasePath#/app/contact.cfm?mode=feedback##contactForm" <cfif topNavActive EQ 'help-feedback'>aria-current="page"</cfif>>#renderFpwApprovedNavIcon("learn", "fpw-menu-row-icon")#<span><strong>Suggest a Feature</strong><small>Share ideas to improve FloatPlanWizard.</small></span><span class="fpw-menu-arrow" aria-hidden="true">&rarr;</span></a>
            </div></div></div>
          </nav>

          <div class="fpw-nav-actions">
            <cfif NOT topNavIsLoggedIn><a class="fpw-nav-link fpw-pricing-link" href="#topNavBasePath#/app/pricing.cfm">#renderFpwNavIcon("pricing", "fpw-nav-icon")#<span>Pricing</span></a></cfif>
            <cfif topNavIsLoggedIn>
              <cfif NOT topNavShowAppSubnav>
                <a class="fpw-nav-link fpw-dashboard-link<cfif topNavActive EQ 'dashboard'> is-active</cfif>" href="#topNavBasePath#/app/dashboard.cfm"<cfif topNavActive EQ 'dashboard'> aria-current="page"</cfif>>
                  <svg class="fpw-nav-icon" viewBox="0 0 24 24" aria-hidden="true" focusable="false"><rect x="4" y="4" width="6" height="6"></rect><rect x="14" y="4" width="6" height="6"></rect><rect x="4" y="14" width="6" height="6"></rect><rect x="14" y="14" width="6" height="6"></rect></svg>
                  <span>Dashboard</span>
                </a>
              </cfif>
              <div class="fpw-dropdown fpw-account-dropdown" data-fpw-dropdown>
                <button class="fpw-nav-link fpw-dropdown-toggle<cfif topNavActive EQ 'account'> is-active</cfif>" type="button" aria-expanded="false" aria-controls="fpwAccountMenu" data-fpw-dropdown-toggle>
                  #renderFpwApprovedNavIcon("user", "fpw-nav-icon")#
                  <span class="fpw-member-identity" data-fpw-member-identity data-fpw-member-email="#encodeForHTMLAttribute(topNavEmail)#" data-clarity-mask="True">#encodeForHTML(topNavUserDisplayName)#</span>
                  <svg class="fpw-chevron" viewBox="0 0 24 24" aria-hidden="true" focusable="false"><path d="m6 9 6 6 6-6"></path></svg>
                </button>
                <div class="fpw-dropdown-menu fpw-dropdown-menu-right" id="fpwAccountMenu" hidden><div class="fpw-menu-scroll">
                  <a href="#topNavBasePath#/app/account.cfm">
                    #renderFpwNavIcon("user", "fpw-dropdown-icon")#
                    <span><strong>My Account</strong><small>Profile and settings</small></span>
                  </a>
                  <a href="#topNavBasePath#/index.cfm" data-fpw-member-logout>
                    <svg class="fpw-dropdown-icon" viewBox="0 0 24 24" aria-hidden="true" focusable="false"><path d="M10 17 15 12 10 7"></path><path d="M15 12H3"></path><path d="M21 4v16"></path></svg>
                    <span><strong>Logout</strong><small>Sign out securely</small></span>
                  </a>
                </div></div>
              </div>
              <a class="fpw-nav-link fpw-logout-direct" href="#topNavBasePath#/index.cfm" data-fpw-member-logout>Logout</a>
            <cfelse>
              <a class="fpw-cta fpw-cta-primary" href="#topNavBasePath#/app/join.cfm">
                <span>Start Free</span>
                <span class="fpw-cta-arrow" aria-hidden="true">&rarr;</span>
              </a>
              <a class="fpw-nav-link fpw-login-link" href="#topNavBasePath#/app/login.cfm" data-fpw-auth-intent="dashboard" data-fpw-auth-source-page="top_nav" data-fpw-auth-section="top_nav" data-fpw-auth-cta-type="account" data-fpw-auth-label="Account">
                #renderFpwApprovedNavIcon("user", "fpw-nav-icon")#
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
          <a class="fpw-app-link<cfif topNavActive EQ 'fuel'> is-active</cfif>" href="#topNavBasePath#/boat-fuel-calculator/"<cfif topNavActive EQ 'fuel'> aria-current="page"</cfif>>
            <svg class="fpw-subnav-icon" viewBox="0 0 24 24" aria-hidden="true" focusable="false"><path d="M5 20V4h9v16"></path><path d="M8 8h3"></path><path d="M14 9h2.5L19 12v6a2 2 0 0 0 4 0v-4"></path></svg>
            <span>Fuel Calculator</span>
          </a>
          <cfif structKeyExists(topNavHelpSections, topNavHelpPage)>
            <a class="fpw-app-link fpw-context-help" href="#topNavBasePath#/app/user-manual.cfm###topNavHelpSections[topNavHelpPage]#">
              #renderFpwNavIcon("help", "fpw-subnav-icon")#<span>Help for this page</span>
            </a>
          </cfif>
        </div>
      </nav>
    </cfif>
  </header>


  <script>
    (function () {
      var shell = document.querySelector("[data-fpw-nav]");
      if (!shell || shell.getAttribute("data-fpw-nav-bound") === "true") return;
      shell.setAttribute("data-fpw-nav-bound", "true");
      var menuButton = shell.querySelector("[data-fpw-mobile-toggle]");
      var closeButton = shell.querySelector("[data-fpw-mobile-close]");
      var backdrop = shell.querySelector("[data-fpw-mobile-backdrop]");
      var navMenu = shell.querySelector("[data-fpw-nav-menu]");
      var dropdowns = Array.prototype.slice.call(shell.querySelectorAll("[data-fpw-dropdown]"));
      var logoutLinks = shell.querySelectorAll("[data-fpw-member-logout]");
      var trackedNavLinks = shell.querySelectorAll("[data-fpw-nav-track]");
      var mobileQuery = window.matchMedia("(max-width: 1040px)");
      var previousBodyOverflow = "";
      var bodyLocked = false;
      var inertElements = [];
      var measureFrame = 0;

      function isMobileNav() { return mobileQuery.matches; }
      function dropdownPanel(dropdown) { return dropdown.querySelector(".fpw-dropdown-menu"); }
      function measureMenu(dropdown) {
        var panel = dropdownPanel(dropdown);
        if (!panel || panel.hidden || isMobileNav()) return;
        panel.style.setProperty("--fpw-menu-shift", "0px");
        var bounds = panel.getBoundingClientRect();
        var shift = Math.max(0, 16 - bounds.left) - Math.max(0, bounds.right - document.documentElement.clientWidth + 16);
        panel.style.setProperty("--fpw-menu-shift", shift + "px");
        var toggleBounds = dropdown.querySelector("[data-fpw-dropdown-toggle]").getBoundingClientRect();
        panel.style.setProperty("--fpw-pointer-left", Math.max(18, Math.min(bounds.width - 18, toggleBounds.left + toggleBounds.width / 2 - bounds.left - shift)) + "px");
        var scroll = panel.querySelector(".fpw-menu-scroll");
        var style = window.getComputedStyle(panel);
        var edges = parseFloat(style.paddingTop) + parseFloat(style.paddingBottom) + 2;
        if (scroll) scroll.style.maxHeight = Math.max(80, document.documentElement.clientHeight - bounds.top - edges - 16) + "px";
      }
      function scheduleMeasurements() {
        if (measureFrame) return;
        measureFrame = window.requestAnimationFrame(function () {
          measureFrame = 0;
          dropdowns.forEach(measureMenu);
          document.documentElement.style.setProperty("--fpw-header-height", Math.ceil(shell.getBoundingClientRect().height) + "px");
        });
      }
      function setDropdownOpen(dropdown, isOpen) {
        var toggle = dropdown.querySelector("[data-fpw-dropdown-toggle]");
        var panel = dropdownPanel(dropdown);
        if (!toggle || !panel) return;
        dropdown.classList.toggle("is-open", isOpen);
        toggle.setAttribute("aria-expanded", isOpen ? "true" : "false");
        panel.hidden = !isOpen;
        if (!isOpen) {
          var scroll = panel.querySelector(".fpw-menu-scroll");
          if (scroll) scroll.style.maxHeight = "";
          panel.style.removeProperty("--fpw-menu-shift");
        } else measureMenu(dropdown);
      }
      function closeDropdowns(except) {
        dropdowns.forEach(function (dropdown) { if (dropdown !== except) setDropdownOpen(dropdown, false); });
      }
      function setBackgroundInert(isOpen) {
        if (!isOpen) {
          inertElements.forEach(function (item) { item.element.inert = item.inert; });
          inertElements = [];
          return;
        }
        // Inert sibling branches up to body, including the header outside the modal drawer.
        var branch = navMenu;
        while (branch && branch !== document.body) {
          Array.prototype.forEach.call(branch.parentElement.children, function (element) {
            if (element === branch || element === backdrop || /^(SCRIPT|STYLE|LINK)$/.test(element.tagName)) return;
            inertElements.push({ element: element, inert: element.inert });
            element.inert = true;
          });
          branch = branch.parentElement;
        }
      }
      function setMenuOpen(isOpen, restoreFocus) {
        isOpen = !!isOpen && isMobileNav();
        var wasOpen = shell.classList.contains("is-menu-open");
        shell.classList.toggle("is-menu-open", isOpen);
        menuButton.setAttribute("aria-expanded", isOpen ? "true" : "false");
        menuButton.setAttribute("aria-label", isOpen ? "Close menu" : "Open menu");
        backdrop.hidden = !isOpen;
        if (isOpen && !wasOpen) {
          previousBodyOverflow = document.body.style.overflow;
          bodyLocked = true;
          document.body.style.overflow = "hidden";
          document.body.classList.add("fpw-nav-open");
          navMenu.setAttribute("role", "dialog");
          navMenu.setAttribute("aria-modal", "true");
          navMenu.setAttribute("aria-label", "Site navigation");
          navMenu.removeAttribute("aria-hidden");
          closeButton.focus();
          setBackgroundInert(true);
        } else if (!isOpen) {
          setBackgroundInert(false);
          if (bodyLocked) {
            document.body.style.overflow = previousBodyOverflow;
            document.body.classList.remove("fpw-nav-open");
            bodyLocked = false;
          }
          navMenu.removeAttribute("role");
          navMenu.removeAttribute("aria-modal");
          navMenu.removeAttribute("aria-label");
          if (isMobileNav()) navMenu.setAttribute("aria-hidden", "true");
          else navMenu.removeAttribute("aria-hidden");
          closeDropdowns();
          if (wasOpen && restoreFocus !== false) {
            var returnTarget = isMobileNav() ? menuButton : shell.querySelector(".fpw-brand");
            if (returnTarget) returnTarget.focus({ preventScroll: true });
          }
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


      menuButton.addEventListener("click", function () { setMenuOpen(!shell.classList.contains("is-menu-open")); });
      closeButton.addEventListener("click", function () { setMenuOpen(false); });
      backdrop.addEventListener("click", function () { setMenuOpen(false); });
      dropdowns.forEach(function (dropdown) {
        var toggle = dropdown.querySelector("[data-fpw-dropdown-toggle]");
        var panel = dropdownPanel(dropdown);
        toggle.addEventListener("click", function (event) {
          event.preventDefault();
          var opening = !dropdown.classList.contains("is-open");
          closeDropdowns(dropdown);
          setDropdownOpen(dropdown, opening);
        });
        dropdown.addEventListener("keydown", function (event) {
          var items = Array.prototype.slice.call(panel.querySelectorAll("a[href], button:not([disabled])"));
          var index = items.indexOf(document.activeElement);
          var next = -1;
          if (event.key === "ArrowDown") next = (index + 1) % items.length;
          if (event.key === "ArrowUp") next = index <= 0 ? items.length - 1 : index - 1;
          if (event.key === "Home") next = 0;
          if (event.key === "End") next = items.length - 1;
          if (next < 0 || !items.length) return;
          event.preventDefault();
          closeDropdowns(dropdown);
          setDropdownOpen(dropdown, true);
          items[next].focus();
        });
        dropdown.addEventListener("focusout", function () {
          window.setTimeout(function () {
            if (!isMobileNav() && !dropdown.contains(document.activeElement)) setDropdownOpen(dropdown, false);
          }, 0);
        });
      });
      Array.prototype.forEach.call(navMenu.querySelectorAll("a"), function (link) {
        link.addEventListener("click", function () {
          if (isMobileNav()) setMenuOpen(false);
          else closeDropdowns();
        });
      });
      Array.prototype.forEach.call(logoutLinks, function (link) { link.addEventListener("click", runLogout); });
      Array.prototype.forEach.call(trackedNavLinks, function (link) {
        link.addEventListener("click", function () { trackPublicNavClick(link); });
      });
      document.addEventListener("click", function (event) {
        if (!shell.contains(event.target)) {
          if (shell.classList.contains("is-menu-open")) setMenuOpen(false);
          else closeDropdowns();
        } else if (!event.target.closest("[data-fpw-dropdown]")) closeDropdowns();
      });
      document.addEventListener("keydown", function (event) {
        if (event.key === "Escape") {
          if (shell.classList.contains("is-menu-open")) {
            event.preventDefault(); setMenuOpen(false); return;
          }
          var open = dropdowns.filter(function (dropdown) { return dropdown.classList.contains("is-open"); })[0];
          if (open) {
            event.preventDefault(); setDropdownOpen(open, false);
            open.querySelector("[data-fpw-dropdown-toggle]").focus();
          }
        }
        if (event.key === "Tab" && shell.classList.contains("is-menu-open")) {
          var focusable = Array.prototype.slice.call(navMenu.querySelectorAll('a[href], button:not([disabled]), [tabindex="0"]')).filter(function (element) { return element.getClientRects().length && !element.closest("[hidden]"); });
          var first = focusable[0]; var last = focusable[focusable.length - 1];
          if (event.shiftKey && (document.activeElement === first || !navMenu.contains(document.activeElement))) { event.preventDefault(); last.focus(); }
          else if (!event.shiftKey && (document.activeElement === last || !navMenu.contains(document.activeElement))) { event.preventDefault(); first.focus(); }
        }
      });
      function updateCompactHeader() {
        // Hysteresis avoids toggling as the sticky header changes height near the threshold.
        var compact = shell.classList.contains("is-compact");
        var next = compact ? window.scrollY > 40 : window.scrollY > 120;
        // Keep modal scroll locks stable without interrupting native anchor scrolling.
        if (document.querySelector("dialog[open]") || shell.classList.contains("is-menu-open")) return;
        if (compact !== next) shell.classList.toggle("is-compact", next);
        scheduleMeasurements();
      }
      function syncActionOrder() {
        var pricing = shell.querySelector(".fpw-pricing-link");
        var signup = shell.querySelector(".fpw-nav-actions > .fpw-cta-primary");
        if (!pricing || !signup) return;
        // Move the existing nodes so keyboard and reading order match each visual layout.
        if (isMobileNav()) pricing.parentElement.insertBefore(signup, pricing);
        else signup.parentElement.insertBefore(pricing, signup);
      }
      function handleBreakpoint() { setMenuOpen(false); syncActionOrder(); scheduleMeasurements(); }
      if (mobileQuery.addEventListener) mobileQuery.addEventListener("change", handleBreakpoint);
      else mobileQuery.addListener(handleBreakpoint);
      window.addEventListener("resize", scheduleMeasurements);
      window.addEventListener("scroll", updateCompactHeader, { passive: true });
      if (window.ResizeObserver) new ResizeObserver(scheduleMeasurements).observe(shell);
      syncActionOrder();
      setMenuOpen(false, false);
      updateCompactHeader();
    })();
  </script>

  <script>
    window.FPW_BASE = "#JSStringFormat(topNavBasePath)#";
    window.FPW_API_BASE = "#JSStringFormat(topNavBasePath)#/api/v1";
  </script>
  <cfif NOT structKeyExists(request, "fpwApiScriptRendered")>
    <cfset request.fpwApiScriptRendered = true>
    <script src="#topNavBasePath#/assets/js/app/api.js?v=20261001-unified-auth"></script>
  </cfif>
  <cfif NOT structKeyExists(request, "fpwAuthScriptRendered")>
    <cfset request.fpwAuthScriptRendered = true>
    <script src="#topNavBasePath#/assets/js/app/auth.js?v=20261001-unified-auth"></script>
  </cfif>
  <cfif NOT topNavIsLoggedIn>
    <script src="#topNavBasePath#/assets/js/app/core.js?v=20261001-unified-auth"></script>
  </cfif>
</cfoutput>
<cfinclude template="../partials/fpw-auth-modal.cfm">
<cfif topNavShowAppSubnav AND NOT reFindNoCase("/app/fuel-calculator\.cfm$", topNavRequestPath)>
  <cfinclude template="../partials/help-drawer.cfm">
</cfif>
