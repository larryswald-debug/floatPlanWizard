component output="false" {

  // Page eligibility is explicit: public library templates under /app are not member tools.
  public boolean function isEligible(
    required string host,
    required string scriptPath,
    required string basePath,
    boolean tripPreview=false
  ) {
    var productionHost = reReplace(lCase(trim(arguments.host)), ":\d+$", "");
    var pagePath = lCase(trim(replace(arguments.scriptPath, chr(92), "/", "all")));
    var publicPages = [
      "/", "/index.cfm",
      "/boating-guides/", "/boating-guides/index.cfm",
      "/boating-guides/chesapeake-bay/", "/boating-guides/chesapeake-bay/index.cfm",
      "/boating-guides/bahamas/", "/boating-guides/bahamas/index.cfm",
      "/boating-guides/bahamas/itineraries/fort-lauderdale-bimini/",
      "/boating-guides/bahamas/itineraries/fort-lauderdale-bimini/index.cfm",
      "/great-loop/trip-planning/", "/great-loop/trip-planning/index.cfm",
      "/great-loop/locks/", "/great-loop/locks/index.cfm",
      "/great-loop/ports/", "/great-loop/ports/index.cfm",
      "/great-loop/anchorages/", "/great-loop/anchorages/index.cfm",
      "/great-loop/bridges/", "/great-loop/bridges.cfm", "/great-loop-bridge.cfm",
      "/app/great-loop-locks.cfm", "/app/great-loop-lock.cfm",
      "/app/great-loop-ports.cfm", "/app/great-loop-port.cfm",
      "/app/great-loop-anchorages.cfm", "/app/great-loop-anchorage.cfm"
    ];
    var page = "";
    var slug = "[a-z0-9]+(?:-[a-z0-9]+)*";

    if (arguments.tripPreview
        OR !listFindNoCase("floatplanwizard.com,www.floatplanwizard.com", productionHost)
        OR len(trim(arguments.basePath))
        OR reFindNoCase("^/fpw(/|$)", pagePath)) return false;

    for (page in publicPages) {
      if (compare(pagePath, page) EQ 0) return true;
    }

    return reFind("^/great-loop/(locks|ports|anchorages|bridges)/" & slug & "/$", pagePath) GT 0
      OR reFind("^/great-loop/locks/(state|waterway)/" & slug & "/$", pagePath) GT 0
      OR reFind("^/great-loop/anchorages/(location|waterway|state|country|type)/" & slug & "/$", pagePath) GT 0
      OR reFind("^/great-loop/bridges/(state|waterway|route)/" & slug & "/$", pagePath) GT 0;
  }

  public string function render(
    required string host,
    required string scriptPath,
    required string basePath,
    boolean tripPreview=false
  ) {
    var markup = "";
    if (structKeyExists(request, "fpwPostHogTagRendered")
        OR !isEligible(argumentCollection=arguments)) return "";

    savecontent variable="markup" {
      include "analytics_posthog_snippet.cfm";
    }
    if (len(trim(markup))) request.fpwPostHogTagRendered = true;
    return markup;
  }
}
