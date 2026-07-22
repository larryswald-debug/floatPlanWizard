<cfprocessingdirective pageencoding="utf-8">
<cfsetting showdebugoutput="false" requesttimeout="30">
<cfinclude template="../../includes/fpw_base_path.cfm">

<cfscript>
request.fpwTopNavActive = "great-loop-locks";
request.fpwLockCleanRoute = true;
request.fpwLockCleanBaseUrl = request.fpwBase & "/great-loop/locks/";
request.fpwLockCleanCanonicalBase = "https://floatplanwizard.com/great-loop/locks/";

routeLockSlug = "";
if (structKeyExists(url, "slug") AND !isNull(url.slug)) {
  routeLockSlug = trim(toString(url.slug));
}
routeLockSlug = reReplace(routeLockSlug, "[?##].*$", "");
routeLockSlug = reReplace(routeLockSlug, "^/+|/+$", "", "all");

routeStateSlug = "";
if (structKeyExists(url, "stateSlug") AND !isNull(url.stateSlug)) {
  routeStateSlug = trim(toString(url.stateSlug));
}
routeStateSlug = reReplace(routeStateSlug, "[?##].*$", "");
routeStateSlug = reReplace(routeStateSlug, "^/+|/+$", "", "all");

routeWaterwaySlug = "";
if (structKeyExists(url, "waterwaySlug") AND !isNull(url.waterwaySlug)) {
  routeWaterwaySlug = trim(toString(url.waterwaySlug));
}
routeWaterwaySlug = reReplace(routeWaterwaySlug, "[?##].*$", "");
routeWaterwaySlug = reReplace(routeWaterwaySlug, "^/+|/+$", "", "all");

try {
  routeLockSvc = createObject("component", "api.v1.GreatLoopLocksService").init();
} catch (any routeSvcPathError) {
  routeLockSvc = createObject("component", "fpw.api.v1.GreatLoopLocksService").init();
}

if (len(routeLockSlug)) {
  url.slug = routeLockSlug;
} else if (len(routeStateSlug)) {
  routeStateModel = routeLockSvc.getStateModel(routeStateSlug);
  if (routeStateModel.SUCCESS) {
    routeStateCode = routeStateModel.STATE;
    routeStateName = routeLockSvc.getStateDisplayName(routeStateCode);
    url.state = routeStateCode;
    request.fpwLockTaxonomyType = "state";
    request.fpwLockTaxonomyName = routeStateName;
    request.fpwLockTaxonomyCode = routeStateCode;
    request.fpwLockTaxonomySlug = routeLockSvc.getStateSlug(routeStateCode);
    request.fpwLockTaxonomyCount = arrayLen(routeStateModel.LOCKS);
    request.fpwLockTaxonomyCanonicalUrl = request.fpwLockCleanCanonicalBase & "state/" & request.fpwLockTaxonomySlug & "/";
  } else {
    cfheader(statuscode = "404");
    request.fpwLockTaxonomyType = "not-found";
    request.fpwLockTaxonomyName = "State or province not found";
    request.fpwLockTaxonomyCount = 0;
    request.fpwLockTaxonomyCanonicalUrl = request.fpwLockCleanCanonicalBase;
  }
} else if (len(routeWaterwaySlug)) {
  routeWaterwayModel = routeLockSvc.getWaterwayModel(routeWaterwaySlug);
  if (routeWaterwayModel.SUCCESS) {
    url.waterway = routeWaterwayModel.WATERWAY;
    request.fpwLockTaxonomyType = "waterway";
    request.fpwLockTaxonomyName = routeWaterwayModel.WATERWAY;
    request.fpwLockTaxonomySlug = routeLockSvc.normalizeSlug(routeWaterwayModel.WATERWAY);
    request.fpwLockTaxonomyCount = arrayLen(routeWaterwayModel.LOCKS);
    request.fpwLockTaxonomyCanonicalUrl = request.fpwLockCleanCanonicalBase & "waterway/" & request.fpwLockTaxonomySlug & "/";
  } else {
    cfheader(statuscode = "404");
    request.fpwLockTaxonomyType = "not-found";
    request.fpwLockTaxonomyName = "Waterway not found";
    request.fpwLockTaxonomyCount = 0;
    request.fpwLockTaxonomyCanonicalUrl = request.fpwLockCleanCanonicalBase;
  }
}
</cfscript>

<cfif len(routeLockSlug)>
  <cfinclude template="../../app/great-loop-lock.cfm">
<cfelse>
  <cfinclude template="../../app/great-loop-locks.cfm">
</cfif>
