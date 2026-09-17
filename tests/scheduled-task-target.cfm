<!--- Harmless native scheduler verification target. No FPW jobs or delivery code. --->
<cfsetting showdebugoutput="false" enablecfoutputonly="true">
<cfset localServerName = structKeyExists(cgi, "server_name") ? lCase(trim(toString(cgi.server_name))) : "">
<cfset localHttpHost = structKeyExists(cgi, "http_host") ? lCase(trim(toString(cgi.http_host))) : "">
<cfif NOT structKeyExists(server, "coldfusion") OR NOT structKeyExists(server.coldfusion, "productLevel")
  OR compareNoCase(toString(server.coldfusion.productLevel), "Developer") NEQ 0
  OR NOT listFindNoCase("localhost,127.0.0.1,::1", localServerName)
  OR NOT reFindNoCase("^(localhost|127\.0\.0\.1|\[::1\])(:8500)?$", localHttpHost)
  OR val(cgi.server_port) NEQ 8500>
  <cfheader statuscode="404"><cfabort>
</cfif>
<cfheader name="Cache-Control" value="no-store">
<cfcontent type="application/json; charset=utf-8" reset="true">
<cfoutput>{"success":true,"message":"Harmless scheduler test endpoint reached."}</cfoutput>
