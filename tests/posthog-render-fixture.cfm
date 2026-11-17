<cfsetting showdebugoutput="false" requesttimeout="60">
<cfheader name="Cache-Control" value="no-store">
<cfscript>
// Read-only render proof: never override CGI, application environment, session, or member data.
localPostHogFixture = structKeyExists(application, "env")
  AND listFindNoCase("dev,development,local", toString(application.env)) GT 0
  AND listFindNoCase("localhost,127.0.0.1,::1", cgi.server_name) GT 0
  AND reFindNoCase("^(localhost|127[.]0[.]0[.]1|\[::1\])(:8500)?$", cgi.http_host) GT 0
  AND val(cgi.server_port) EQ 8500
  AND cgi.request_method EQ "GET";
if (!localPostHogFixture OR !structKeyExists(url, "confirm")
    OR url.confirm NEQ "POSTHOG_LOCAL_TEST") {
  cfheader(statuscode=404);
  cfcontent(type="application/json; charset=utf-8", reset=true);
  writeOutput(serializeJSON({SUCCESS=false, error="LOCAL_TEST_ONLY"}));
  abort;
}

postHogRenderer = new fpw.includes.PostHogPageviewRenderer();
postHogCases = [
  {key="homepage", host="floatplanwizard.com", scriptPath="/index.cfm", basePath="", expected=true},
  {key="homepage_clean", host="www.floatplanwizard.com:443", scriptPath="/", basePath="", expected=true},
  {key="cruising", host="floatplanwizard.com", scriptPath="/boating-guides/index.cfm", basePath="", expected=true},
  {key="chesapeake", host="floatplanwizard.com", scriptPath="/boating-guides/chesapeake-bay/index.cfm", basePath="", expected=true},
  {key="bahamas", host="floatplanwizard.com", scriptPath="/boating-guides/bahamas/index.cfm", basePath="", expected=true},
  {key="itinerary", host="floatplanwizard.com", scriptPath="/boating-guides/bahamas/itineraries/fort-lauderdale-bimini/index.cfm", basePath="", expected=true},
  {key="locks", host="floatplanwizard.com", scriptPath="/great-loop/locks/waterway/chicago-illinois-waterway/", basePath="", expected=true},
  {key="locks_wrapper", host="floatplanwizard.com", scriptPath="/great-loop/locks/index.cfm", basePath="", expected=true},
  {key="publiclegacylocks", host="floatplanwizard.com", scriptPath="/app/great-loop-locks.cfm", basePath="", expected=true},
  {key="lock_detail", host="floatplanwizard.com", scriptPath="/app/great-loop-lock.cfm", basePath="", expected=true},
  {key="ports", host="floatplanwizard.com", scriptPath="/great-loop/ports/index.cfm", basePath="", expected=true},
  {key="port_detail", host="floatplanwizard.com", scriptPath="/app/great-loop-port.cfm", basePath="", expected=true},
  {key="anchorages", host="floatplanwizard.com", scriptPath="/great-loop/anchorages/index.cfm", basePath="", expected=true},
  {key="anchorage_detail", host="floatplanwizard.com", scriptPath="/app/great-loop-anchorage.cfm", basePath="", expected=true},
  {key="bridges", host="floatplanwizard.com", scriptPath="/great-loop/bridges.cfm", basePath="", expected=true},
  {key="bridge_detail", host="floatplanwizard.com", scriptPath="/great-loop-bridge.cfm", basePath="", expected=true},
  {key="planning", host="floatplanwizard.com", scriptPath="/great-loop/trip-planning/index.cfm", basePath="", expected=true},
  {key="www_host", host="www.floatplanwizard.com", scriptPath="/index.cfm", basePath="", expected=true},
  {key="production_port", host="floatplanwizard.com:443", scriptPath="/index.cfm", basePath="", expected=true},
  {key="locks_state", host="floatplanwizard.com", scriptPath="/great-loop/locks/state/illinois/", basePath="", expected=true},
  {key="anchorages_location", host="floatplanwizard.com", scriptPath="/great-loop/anchorages/location/chesapeake-bay/", basePath="", expected=true},
  {key="anchorages_state", host="floatplanwizard.com", scriptPath="/great-loop/anchorages/state/florida/", basePath="", expected=true},
  {key="anchorages_country", host="floatplanwizard.com", scriptPath="/great-loop/anchorages/country/united-states/", basePath="", expected=true},
  {key="anchorages_type", host="floatplanwizard.com", scriptPath="/great-loop/anchorages/type/anchorage/", basePath="", expected=true},
  {key="anchorages_waterway", host="floatplanwizard.com", scriptPath="/great-loop/anchorages/waterway/atlantic-intracoastal-waterway/", basePath="", expected=true},
  {key="bridges_state", host="floatplanwizard.com", scriptPath="/great-loop/bridges/state/illinois/", basePath="", expected=true},
  {key="bridges_waterway", host="floatplanwizard.com", scriptPath="/great-loop/bridges/waterway/chicago-illinois-waterway/", basePath="", expected=true},
  {key="bridges_route", host="floatplanwizard.com", scriptPath="/great-loop/bridges/route/great-loop/", basePath="", expected=true},
  {key="signedtool", host="floatplanwizard.com", scriptPath="/app/dashboard.cfm", basePath="", expected=false},
  {key="trip", host="floatplanwizard.com", scriptPath="/app/active-cruise.cfm", basePath="", expected=false},
  {key="completed_trip", host="floatplanwizard.com", scriptPath="/app/completed-trip.cfm", basePath="", expected=false},
  {key="follow", host="floatplanwizard.com", scriptPath="/follow/index.cfm", basePath="", expected=false},
  {key="follow_token", host="floatplanwizard.com", scriptPath="/app/follow.cfm", basePath="", expected=false},
  {key="follow_map", host="floatplanwizard.com", scriptPath="/app/follow-full-map.cfm", basePath="", expected=false},
  {key="login", host="floatplanwizard.com", scriptPath="/app/login.cfm", basePath="", expected=false},
  {key="otherpublictool", host="floatplanwizard.com", scriptPath="/boat-fuel-calculator/index.cfm", basePath="", expected=false},
  {key="local", host="localhost:8500", scriptPath="/index.cfm", basePath="", expected=false},
  {key="staging", host="staging.floatplanwizard.com", scriptPath="/index.cfm", basePath="", expected=false},
  {key="host_suffix", host="floatplanwizard.com.example.test", scriptPath="/index.cfm", basePath="", expected=false},
  {key="preview", host="floatplanwizard.com", scriptPath="/index.cfm", basePath="", tripPreview=true, expected=false},
  {key="basepath", host="floatplanwizard.com", scriptPath="/index.cfm", basePath="/fpw", expected=false},
  {key="localpath", host="floatplanwizard.com", scriptPath="/fpw/index.cfm", basePath="", expected=false},
  {key="unapproved", host="floatplanwizard.com", scriptPath="/boating-guides/member-trip/index.cfm", basePath="", expected=false}
];
postHogCaseKey = structKeyExists(url, "case") ? lCase(trim(toString(url["case"]))) : "homepage";
postHogResults = [];
postHogPass = true;
for (postHogCase in postHogCases) {
  if (postHogCaseKey NEQ "all" AND postHogCase.key NEQ postHogCaseKey) continue;
  structDelete(request, "fpwPostHogTagRendered");
  postHogContext = {
    host=postHogCase.host,
    scriptPath=postHogCase.scriptPath,
    basePath=postHogCase.basePath,
    tripPreview=structKeyExists(postHogCase, "tripPreview") AND postHogCase.tripPreview
  };
  postHogMarkup = postHogRenderer.render(argumentCollection=postHogContext);
  postHogSecondMarkup = postHogRenderer.render(argumentCollection=postHogContext);
  postHogInitializationCount = arrayLen(reMatch("posthog[.]init[(]", postHogMarkup));
  postHogResult = {
    key=postHogCase.key,
    context=postHogContext,
    expected=postHogCase.expected,
    rendered=len(trim(postHogMarkup)) GT 0,
    initializations=postHogInitializationCount,
    duplicateSuppressed=!len(trim(postHogSecondMarkup)),
    guardSet=structKeyExists(request, "fpwPostHogTagRendered")
  };
  postHogResult.passed = postHogResult.rendered EQ postHogCase.expected
    AND postHogInitializationCount EQ (postHogCase.expected ? 1 : 0)
    AND postHogResult.duplicateSuppressed
    AND postHogResult.guardSet EQ postHogCase.expected;
  if (postHogCaseKey NEQ "all") postHogResult.html = postHogMarkup;
  postHogPass = postHogPass AND postHogResult.passed;
  arrayAppend(postHogResults, postHogResult);
}
structDelete(request, "fpwPostHogTagRendered");
postHogLocalIncludeMarkup = "";
savecontent variable="postHogLocalIncludeMarkup" {
  include "../includes/analytics_posthog.cfm";
  include "../includes/analytics_posthog.cfm";
}
postHogLocalIncludeSuppressed = !len(trim(postHogLocalIncludeMarkup))
  AND !structKeyExists(request, "fpwPostHogTagRendered");
postHogPass = postHogPass AND postHogLocalIncludeSuppressed AND arrayLen(postHogResults) GT 0;
if (!arrayLen(postHogResults)) cfheader(statuscode=400);
else if (!postHogPass) cfheader(statuscode=500);
cfcontent(type="application/json; charset=utf-8", reset=true);
writeOutput(serializeJSON({
  SUCCESS=postHogPass,
  CASES=postHogResults,
  LOCAL_INCLUDE_SUPPRESSED=postHogLocalIncludeSuppressed
}));
</cfscript>
