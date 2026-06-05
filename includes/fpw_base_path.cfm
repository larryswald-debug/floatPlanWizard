<cfscript>
if (!structKeyExists(request, "fpwBase") OR isNull(request.fpwBase)) {
  fpwBaseCandidate = "";

  if (structKeyExists(cgi, "script_name")) {
    fpwBaseCandidate = trim(toString(cgi.script_name));
  } else if (structKeyExists(cgi, "SCRIPT_NAME")) {
    fpwBaseCandidate = trim(toString(cgi.SCRIPT_NAME));
  }

  fpwBaseCandidate = reReplace(fpwBaseCandidate, "[?##].*$", "");
  fpwBaseCandidate = replace(fpwBaseCandidate, "\", "/", "all");
  fpwBaseCandidate = reReplaceNoCase(fpwBaseCandidate, "/api/v1(/.*)?$", "");
  fpwBaseCandidate = reReplaceNoCase(fpwBaseCandidate, "/great-loop/locks(/.*)?$", "");
  fpwBaseCandidate = reReplaceNoCase(fpwBaseCandidate, "/(app|admin|assets|tests)(/.*)?$", "");
  fpwBaseCandidate = reReplaceNoCase(fpwBaseCandidate, "/[^/]*\.(cfm|cfc)$", "");
  fpwBaseCandidate = reReplace(fpwBaseCandidate, "/$", "");

  if (fpwBaseCandidate == "/") {
    fpwBaseCandidate = "";
  }
  if (len(fpwBaseCandidate) AND left(fpwBaseCandidate, 1) NEQ "/") {
    fpwBaseCandidate = "/" & fpwBaseCandidate;
  }

  request.fpwBase = fpwBaseCandidate;
} else {
  request.fpwBase = trim(toString(request.fpwBase));
  request.fpwBase = reReplace(request.fpwBase, "/$", "");

  if (request.fpwBase == "/") {
    request.fpwBase = "";
  }
  if (len(request.fpwBase) AND left(request.fpwBase, 1) NEQ "/") {
    request.fpwBase = "/" & request.fpwBase;
  }
}

request.fpwApiBase = request.fpwBase & "/api/v1";
</cfscript>
