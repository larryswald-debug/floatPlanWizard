<cfinclude template="fpw_base_path.cfm">
<cfif NOT structKeyExists(request, "fpwFaviconDeclared")>
  <cfoutput><link rel="icon" type="image/x-icon" href="#request.fpwBase#/favicon.ico"></cfoutput>
  <cfset request.fpwFaviconDeclared = true>
</cfif>
<cfinclude template="analytics_ga4.cfm">
<cfinclude template="analytics_clarity.cfm">
<cfinclude template="trustedsite.cfm">

<cfoutput>
<script>
  window.FPW_BASE = "#request.fpwBase#";
  window.FPW_API_BASE = "#request.fpwApiBase#";
</script>
</cfoutput>
