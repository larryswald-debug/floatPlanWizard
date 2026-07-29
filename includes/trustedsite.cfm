<cfparam name="cgi.http_host" default="">
<cfparam name="cgi.script_name" default="">
<cfscript>
fpwTrustedSiteHost = lCase(trim(toString(cgi.http_host)));
fpwTrustedSitePath = lCase(trim(toString(cgi.script_name)));
fpwTrustedSiteBasePath = "";
fpwTrustedSiteIsProductionHost = false;
fpwTrustedSiteIsBlockedPath = false;

if (structKeyExists(request, "fpwBase")) {
  fpwTrustedSiteBasePath = trim(toString(request.fpwBase));
}

fpwTrustedSiteHost = reReplace(fpwTrustedSiteHost, ":\d+$", "");
fpwTrustedSitePath = replace(fpwTrustedSitePath, chr(92), "/", "all");

fpwTrustedSiteIsProductionHost = listFindNoCase("floatplanwizard.com,www.floatplanwizard.com", fpwTrustedSiteHost) GT 0;
fpwTrustedSiteIsBlockedPath = (
  len(fpwTrustedSiteBasePath) GT 0
  OR reFindNoCase("^/fpw(/|$)", fpwTrustedSitePath) GT 0
  OR reFindNoCase("^/(admin|api|tests)(/|$)", fpwTrustedSitePath) GT 0
  OR reFindNoCase("^/assets/admin(/|$)", fpwTrustedSitePath) GT 0
);
</cfscript>

<cfif fpwTrustedSiteIsProductionHost AND NOT fpwTrustedSiteIsBlockedPath AND NOT structKeyExists(request, "fpwTrustedSiteTagRendered")>
  <cfset request.fpwTrustedSiteTagRendered = true>
  <cfif CGI.HTTP_HOST EQ "floatplanwizard.com" OR CGI.HTTP_HOST EQ "www.floatplanwizard.com">
    <!-- TrustedSite -->
    <script>
      var t = document.createElement('script');
      t.setAttribute("type", "text/javascript");
      t.setAttribute("src", "https://cdn.ywxi.net/js/1.js");
      parent.document.getElementsByTagName("head")[0].appendChild(t);
    </script>
  </cfif>
</cfif>
