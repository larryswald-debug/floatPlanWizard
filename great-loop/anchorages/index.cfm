<cfprocessingdirective pageencoding="utf-8">
<cfsetting showdebugoutput="false" requesttimeout="30">
<cfinclude template="../../includes/fpw_base_path.cfm">

<cfscript>
request.fpwTopNavActive = "great-loop-anchorages";
request.fpwAnchorageCleanRoute = true;
request.fpwAnchorageCleanBaseUrl = request.fpwBase & "/great-loop/anchorages/";
request.fpwAnchorageCleanCanonicalBase = "https://floatplanwizard.com/great-loop/anchorages/";

function routeSlugValue(required string keyName) {
  var value = "";
  if (structKeyExists(url, arguments.keyName) AND !isNull(url[arguments.keyName])) {
    value = trim(toString(url[arguments.keyName]));
  }
  value = reReplace(value, "[?##].*$", "");
  value = reReplace(value, "^/+|/+$", "", "all");
  return value;
}

routeAnchorageSlug = routeSlugValue("slug");
routeLocationSlug = routeSlugValue("locationSlug");
routeWaterwaySlug = routeSlugValue("waterwaySlug");
routeStateSlug = routeSlugValue("stateSlug");
routeCountrySlug = routeSlugValue("countrySlug");
routeTypeSlug = routeSlugValue("typeSlug");

try {
  routeAnchorageSvc = createObject("component", "api.v1.GreatLoopAnchoragesService").init();
} catch (any routeSvcPathError) {
  routeAnchorageSvc = createObject("component", "fpw.api.v1.GreatLoopAnchoragesService").init();
}

if (len(routeAnchorageSlug)) {
  url.slug = routeAnchorageSlug;
} else if (len(routeLocationSlug)) {
  routeTaxonomyModel = routeAnchorageSvc.getLocationGroupModel(routeLocationSlug);
  if (routeTaxonomyModel.SUCCESS) {
    url.locationGroup = routeTaxonomyModel.LOCATION_GROUP;
    request.fpwAnchorageTaxonomyType = "location";
    request.fpwAnchorageTaxonomyName = routeTaxonomyModel.LOCATION_GROUP;
    request.fpwAnchorageTaxonomySlug = routeAnchorageSvc.normalizeSlug(routeTaxonomyModel.LOCATION_GROUP);
    request.fpwAnchorageTaxonomyCount = arrayLen(routeTaxonomyModel.ANCHORAGES);
    request.fpwAnchorageTaxonomyCanonicalUrl = request.fpwAnchorageCleanCanonicalBase & "location/" & request.fpwAnchorageTaxonomySlug & "/";
  } else {
    cfheader(statuscode = "404");
    request.fpwAnchorageTaxonomyType = "not-found";
    request.fpwAnchorageTaxonomyName = "Location group not found";
    request.fpwAnchorageTaxonomyCount = 0;
    request.fpwAnchorageTaxonomyCanonicalUrl = request.fpwAnchorageCleanCanonicalBase;
  }
} else if (len(routeWaterwaySlug)) {
  routeTaxonomyModel = routeAnchorageSvc.getWaterwayModel(routeWaterwaySlug);
  if (routeTaxonomyModel.SUCCESS) {
    url.waterway = routeTaxonomyModel.WATERWAY;
    request.fpwAnchorageTaxonomyType = "waterway";
    request.fpwAnchorageTaxonomyName = routeTaxonomyModel.WATERWAY;
    request.fpwAnchorageTaxonomySlug = routeAnchorageSvc.normalizeSlug(routeTaxonomyModel.WATERWAY);
    request.fpwAnchorageTaxonomyCount = arrayLen(routeTaxonomyModel.ANCHORAGES);
    request.fpwAnchorageTaxonomyCanonicalUrl = request.fpwAnchorageCleanCanonicalBase & "waterway/" & request.fpwAnchorageTaxonomySlug & "/";
  } else {
    cfheader(statuscode = "404");
    request.fpwAnchorageTaxonomyType = "not-found";
    request.fpwAnchorageTaxonomyName = "Waterway not found";
    request.fpwAnchorageTaxonomyCount = 0;
    request.fpwAnchorageTaxonomyCanonicalUrl = request.fpwAnchorageCleanCanonicalBase;
  }
} else if (len(routeStateSlug)) {
  routeTaxonomyModel = routeAnchorageSvc.getStateModel(routeStateSlug);
  if (routeTaxonomyModel.SUCCESS) {
    url.stateProvince = routeTaxonomyModel.STATE;
    request.fpwAnchorageTaxonomyType = "state";
    request.fpwAnchorageTaxonomyName = routeTaxonomyModel.STATE;
    request.fpwAnchorageTaxonomySlug = routeAnchorageSvc.normalizeSlug(routeTaxonomyModel.STATE);
    request.fpwAnchorageTaxonomyCount = arrayLen(routeTaxonomyModel.ANCHORAGES);
    request.fpwAnchorageTaxonomyCanonicalUrl = request.fpwAnchorageCleanCanonicalBase & "state/" & request.fpwAnchorageTaxonomySlug & "/";
  } else {
    cfheader(statuscode = "404");
    request.fpwAnchorageTaxonomyType = "not-found";
    request.fpwAnchorageTaxonomyName = "State or province not found";
    request.fpwAnchorageTaxonomyCount = 0;
    request.fpwAnchorageTaxonomyCanonicalUrl = request.fpwAnchorageCleanCanonicalBase;
  }
} else if (len(routeCountrySlug)) {
  routeTaxonomyModel = routeAnchorageSvc.getCountryModel(routeCountrySlug);
  if (routeTaxonomyModel.SUCCESS) {
    url.country = routeTaxonomyModel.COUNTRY;
    request.fpwAnchorageTaxonomyType = "country";
    request.fpwAnchorageTaxonomyName = routeTaxonomyModel.COUNTRY;
    request.fpwAnchorageTaxonomySlug = routeAnchorageSvc.normalizeSlug(routeTaxonomyModel.COUNTRY);
    request.fpwAnchorageTaxonomyCount = arrayLen(routeTaxonomyModel.ANCHORAGES);
    request.fpwAnchorageTaxonomyCanonicalUrl = request.fpwAnchorageCleanCanonicalBase & "country/" & request.fpwAnchorageTaxonomySlug & "/";
  } else {
    cfheader(statuscode = "404");
    request.fpwAnchorageTaxonomyType = "not-found";
    request.fpwAnchorageTaxonomyName = "Country not found";
    request.fpwAnchorageTaxonomyCount = 0;
    request.fpwAnchorageTaxonomyCanonicalUrl = request.fpwAnchorageCleanCanonicalBase;
  }
} else if (len(routeTypeSlug)) {
  routeTaxonomyModel = routeAnchorageSvc.getTypeModel(routeTypeSlug);
  if (routeTaxonomyModel.SUCCESS) {
    url.anchorageType = routeTaxonomyModel.ANCHORAGE_TYPE;
    request.fpwAnchorageTaxonomyType = "type";
    request.fpwAnchorageTaxonomyName = routeTaxonomyModel.ANCHORAGE_TYPE;
    request.fpwAnchorageTaxonomySlug = routeAnchorageSvc.normalizeSlug(routeTaxonomyModel.ANCHORAGE_TYPE);
    request.fpwAnchorageTaxonomyCount = arrayLen(routeTaxonomyModel.ANCHORAGES);
    request.fpwAnchorageTaxonomyCanonicalUrl = request.fpwAnchorageCleanCanonicalBase & "type/" & request.fpwAnchorageTaxonomySlug & "/";
  } else {
    cfheader(statuscode = "404");
    request.fpwAnchorageTaxonomyType = "not-found";
    request.fpwAnchorageTaxonomyName = "Anchorage type not found";
    request.fpwAnchorageTaxonomyCount = 0;
    request.fpwAnchorageTaxonomyCanonicalUrl = request.fpwAnchorageCleanCanonicalBase;
  }
}
</cfscript>

<cfif len(routeAnchorageSlug)>
  <cfinclude template="../../app/great-loop-anchorage.cfm">
<cfelse>
  <cfinclude template="../../app/great-loop-anchorages.cfm">
</cfif>
