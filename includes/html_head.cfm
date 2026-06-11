<cfinclude template="fpw_base_path.cfm">
<cfinclude template="analytics_ga4.cfm">

<cfoutput>
<script>
  window.FPW_BASE = "#request.fpwBase#";
  window.FPW_API_BASE = "#request.fpwApiBase#";
</script>
</cfoutput>
