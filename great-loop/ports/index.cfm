<cfprocessingdirective pageencoding="utf-8">
<cfsetting showdebugoutput="false" requesttimeout="30">
<cfinclude template="../../includes/fpw_base_path.cfm">

<cfscript>
request.fpwTopNavActive = "great-loop-ports";
request.fpwPortsLibraryUrl = request.fpwBase & "/great-loop/ports/";
request.fpwPortsCanonicalBase = "https://floatplanwizard.com/great-loop/ports/";

function portRouteSlugValue(required string keyName) {
  var value = "";
  if (structKeyExists(url, arguments.keyName) AND !isNull(url[arguments.keyName])) {
    value = trim(toString(url[arguments.keyName]));
  }
  value = reReplace(value, "[?##].*$", "");
  value = reReplace(value, "^/+|/+$", "", "all");
  return value;
}

routePortSlug = portRouteSlugValue("slug");

if (len(routePortSlug)) {
  url.slug = routePortSlug;
}
</cfscript>

<cfif len(routePortSlug)>
  <cfinclude template="../../app/great-loop-port.cfm">
<cfelse>
  <cfinclude template="../../app/great-loop-ports.cfm">
</cfif>
