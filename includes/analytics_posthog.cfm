<cfscript>
if (!structKeyExists(request, "fpwPostHogTagRendered")) {
  try {
    fpwPostHogRenderer = createObject("component", "includes.PostHogPageviewRenderer");
  } catch (any fpwPostHogRootComponentUnavailable) {
    fpwPostHogRenderer = createObject("component", "fpw.includes.PostHogPageviewRenderer");
  }
  writeOutput(fpwPostHogRenderer.render(
    host=structKeyExists(cgi, "http_host") ? toString(cgi.http_host) : "",
    scriptPath=structKeyExists(cgi, "script_name") ? toString(cgi.script_name) : "",
    basePath=structKeyExists(request, "fpwBase") ? toString(request.fpwBase) : "",
    tripPreview=structKeyExists(request, "fpwTripPreview") AND request.fpwTripPreview
  ));
}
</cfscript>
