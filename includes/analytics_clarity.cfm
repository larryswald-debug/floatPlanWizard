<cfparam name="cgi.http_host" default="">
<cfparam name="cgi.script_name" default="">
<cfscript>
fpwClarityHost = lCase(trim(toString(cgi.http_host)));
fpwClarityPath = lCase(trim(toString(cgi.script_name)));
fpwClarityBasePath = "";
fpwClarityIsProductionHost = false;
fpwClarityIsBlockedPath = false;

if (structKeyExists(request, "fpwBase")) {
  fpwClarityBasePath = trim(toString(request.fpwBase));
}

fpwClarityHost = reReplace(fpwClarityHost, ":\d+$", "");
fpwClarityPath = replace(fpwClarityPath, chr(92), "/", "all");

fpwClarityIsProductionHost = listFindNoCase("floatplanwizard.com,www.floatplanwizard.com", fpwClarityHost) GT 0;
fpwClarityIsBlockedPath = (
  len(fpwClarityBasePath) GT 0
  OR reFindNoCase("^/fpw(/|$)", fpwClarityPath) GT 0
  OR reFindNoCase("^/(admin|api|tests)(/|$)", fpwClarityPath) GT 0
  OR reFindNoCase("^/assets/admin(/|$)", fpwClarityPath) GT 0
);
</cfscript>

<cfif fpwClarityIsProductionHost AND NOT fpwClarityIsBlockedPath AND NOT structKeyExists(request, "fpwClarityTagRendered")>
  <cfset request.fpwClarityTagRendered = true>
  <!-- Microsoft Clarity tracking: production only, project x61nnnmu8k -->
  <script type="text/javascript">
    (function(c,l,a,r,i,t,y){
      c[a]=c[a]||function(){(c[a].q=c[a].q||[]).push(arguments)};
      t=l.createElement(r);t.async=1;t.src="https://www.clarity.ms/tag/"+i;
      y=l.getElementsByTagName(r)[0];y.parentNode.insertBefore(t,y);
    })(window, document, "clarity", "script", "x61nnnmu8k");
  </script>
</cfif>
