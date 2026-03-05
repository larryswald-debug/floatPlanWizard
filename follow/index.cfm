<cfscript>
request.fpwBase = getDirectoryFromPath(cgi.script_name);
request.fpwBase = reReplace(request.fpwBase, "/follow/?$", "");
request.fpwBase = reReplace(request.fpwBase, "/$", "");
if (request.fpwBase == "/") {
    request.fpwBase = "";
}
</cfscript>

<cfinclude template="../app/follow.cfm">
