<cfscript>
if (!structKeyExists(request, "fpwBase")) {
  request.fpwBase = getDirectoryFromPath(cgi.script_name);
  request.fpwBase = reReplace(request.fpwBase, "/app/?$", "");
  request.fpwBase = reReplace(request.fpwBase, "/$", "");
  if (request.fpwBase == "/") {
    request.fpwBase = "";
  }
}
</cfscript>

<cfoutput>
<script>
  window.FPW_BASE = "#request.fpwBase#";
  window.FPW_API_BASE = "#request.fpwBase#/api/v1";
</script>
</cfoutput>
