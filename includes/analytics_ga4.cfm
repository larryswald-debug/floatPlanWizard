<cfparam name="cgi.http_host" default="">
<cfparam name="cgi.script_name" default="">
<cfscript>
fpwGaHost = lCase(trim(toString(cgi.http_host)));
fpwGaPath = lCase(trim(toString(cgi.script_name)));
fpwGaBasePath = "";
fpwGaIsProductionHost = false;
fpwGaIsBlockedPath = false;

if (structKeyExists(request, "fpwBase")) {
  fpwGaBasePath = trim(toString(request.fpwBase));
}

fpwGaHost = reReplace(fpwGaHost, ":\d+$", "");
fpwGaPath = replace(fpwGaPath, chr(92), "/", "all");

fpwGaIsProductionHost = listFindNoCase("floatplanwizard.com,www.floatplanwizard.com", fpwGaHost) GT 0;
fpwGaIsBlockedPath = (
  len(fpwGaBasePath) GT 0
  OR reFindNoCase("^/fpw(/|$)", fpwGaPath) GT 0
  OR reFindNoCase("^/(admin|api|tests)(/|$)", fpwGaPath) GT 0
  OR reFindNoCase("^/assets/admin(/|$)", fpwGaPath) GT 0
);
</cfscript>

<cfif NOT structKeyExists(request, "fpwPlausibleTagRendered")>
  <cfset request.fpwPlausibleTagRendered = true>
<!-- Privacy-friendly analytics by Plausible -->
<script async src="https://plausible.io/js/pa-RzmzzpwAcdcGg_-4y94nc.js"></script>
<script>
  window.plausible=window.plausible||function(){(plausible.q=plausible.q||[]).push(arguments)},plausible.init=plausible.init||function(i){plausible.o=i||{}};
  plausible.init()
</script>
</cfif>

<cfif NOT structKeyExists(request, "fpwGa4HelperRendered")>
  <cfset request.fpwGa4HelperRendered = true>
  <script>
    window.FPWAnalytics = window.FPWAnalytics || {};
    window.FPWAnalytics.track = window.FPWAnalytics.track || function(eventName, params) {
      if (!eventName || typeof window.gtag !== "function") {
        return;
      }
      try {
        window.gtag("event", String(eventName), (params && typeof params === "object") ? params : {});
      } catch (err) {}
    };
  </script>
</cfif>

<cfif fpwGaIsProductionHost AND NOT fpwGaIsBlockedPath AND NOT structKeyExists(request, "fpwGa4TagRendered")>
  <cfset request.fpwGa4TagRendered = true>
  <!-- Google tag (gtag.js) -->
  <script async src="https://www.googletagmanager.com/gtag/js?id=G-JJCH1QE0LH"></script>
  <script>
    window.dataLayer = window.dataLayer || [];
    function gtag(){dataLayer.push(arguments);}
    gtag('js', new Date());

    gtag('config', 'G-JJCH1QE0LH');
  </script>
</cfif>
