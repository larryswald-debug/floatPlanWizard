<cfsetting showdebugoutput="false" enablecfoutputonly="true">
<cfparam name="url.confirm" default="">
<cfset localHost = listFindNoCase("localhost,127.0.0.1,::1", cgi.server_name) GT 0 AND val(cgi.server_port) EQ 8500>
<cfif NOT localHost OR url.confirm NEQ "COMPILE_MEMBER_PROFILE_NAME">
    <cfheader statuscode="404"><cfcontent type="application/json" reset="true">
    <cfoutput>#serializeJSON({SUCCESS=false,ERROR="LOCAL_TEST_CONFIRMATION_REQUIRED"})#</cfoutput><cfabort>
</cfif>
<cfscript>
results = [];
for (componentName in ["profile","floatplan","BasicReviewSendService","email","voyage"]) {
    try {
        metadata = getComponentMetadata("fpw.api.v1." & componentName);
        arrayAppend(results, {component=componentName,success=true});
    } catch (any err) {
        arrayAppend(results, {component=componentName,success=false,message=err.message,detail=err.detail});
    }
}
ok = true;
for (entry in results) if (!entry.success) ok = false;
</cfscript>
<cfheader statuscode="#ok ? 200 : 500#"><cfcontent type="application/json; charset=utf-8" reset="true">
<cfoutput>#serializeJSON({SUCCESS=ok,RESULTS=results})#</cfoutput>
