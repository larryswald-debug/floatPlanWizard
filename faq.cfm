<cfprocessingdirective pageencoding="utf-8">
<cfsetting showdebugoutput="false">

<cfscript>
fpwFaqRedirectBasePath = "";
fpwFaqRedirectScriptName = structKeyExists(cgi, "script_name") ? trim(toString(cgi.script_name)) : "";

if (structKeyExists(request, "fpwBase")) {
  fpwFaqRedirectBasePath = trim(toString(request.fpwBase));
}

if (!len(fpwFaqRedirectBasePath) AND len(fpwFaqRedirectScriptName)) {
  fpwFaqRedirectBasePath = replace(fpwFaqRedirectScriptName, "\", "/", "all");
  fpwFaqRedirectBasePath = reReplaceNoCase(fpwFaqRedirectBasePath, "/faq\.cfm$", "");
}

fpwFaqRedirectBasePath = reReplace(fpwFaqRedirectBasePath, "/$", "");
if (fpwFaqRedirectBasePath EQ "/") {
  fpwFaqRedirectBasePath = "";
}
if (len(fpwFaqRedirectBasePath) AND left(fpwFaqRedirectBasePath, 1) NEQ "/") {
  fpwFaqRedirectBasePath = "/" & fpwFaqRedirectBasePath;
}
</cfscript>

<cflocation url="#fpwFaqRedirectBasePath#/faq/" addtoken="false" statuscode="301">
