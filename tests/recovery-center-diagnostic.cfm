<cfsetting showdebugoutput="false" enablecfoutputonly="true">
<cfcontent type="application/json; charset=utf-8" reset="true">
<cfheader name="Cache-Control" value="no-store">
<cfscript>
localOnly=listFindNoCase("localhost,127.0.0.1,::1",cgi.server_name) GT 0
 AND reFindNoCase("^(localhost|127\.0\.0\.1|\[::1\])(:8500)?$",cgi.http_host) GT 0 AND val(cgi.server_port) EQ 8500;
if(!localOnly OR (url.confirm ?: "") NEQ "RUN_RECOVERY_CENTER_DIAGNOSTIC") {cfheader(statuscode=404);abort;}
try {
 service=new fpw.api.v1.AdminRecoveryCenterService().init();
 if(listFind("settings,dashboard,queue,runs,members,member,performance,preview",url.action ?: "")) {
  result=service.execute(url.action,duplicate(url));
  writeOutput(serializeJSON({ok=true,result=result}));
 } else writeOutput(serializeJSON({ok=true,compiled=true}));
} catch(any failure) {
 cfheader(statuscode=500);
 writeOutput(serializeJSON({ok=false,type=failure.type,message=failure.message,detail=failure.detail,tagContext=failure.tagContext}));
}
</cfscript>
