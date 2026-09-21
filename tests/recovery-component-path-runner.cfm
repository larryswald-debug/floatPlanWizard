<cfsetting showdebugoutput="false" enablecfoutputonly="true" requesttimeout="60">
<cfcontent type="application/json; charset=utf-8" reset="true">
<cfheader name="Cache-Control" value="no-store">
<cfscript>
localOnly=listFindNoCase("localhost,127.0.0.1,::1",cgi.server_name) GT 0
  AND reFindNoCase("^(localhost|127\.0\.0\.1|\[::1\])(:8500)?$",cgi.http_host) GT 0
  AND val(cgi.server_port) EQ 8500;
if (!localOnly OR !structKeyExists(url,"confirm") OR url.confirm NEQ "RUN_RECOVERY_COMPONENT_PATH_TESTS") {
  cfheader(statuscode=404);writeOutput(serializeJSON({SUCCESS=false,ERROR="LOCAL_CONFIRMATION_REQUIRED"}));abort;
}
checks=[];
prefix=structKeyExists(request,"recoveryPathTestPrefix") ? request.recoveryPathTestPrefix : "fpw.";
function check(required boolean condition,required string label) {
  if (!arguments.condition) throw(type="tests.ComponentPath",message=arguments.label);
  arrayAppend(checks,arguments.label);
}
try {
  controller=createObject("component",prefix & "api.v1.floatplan");
  harness=new testbox.system.BaseSpec();
  harness.makePublic(controller,"resolveApiV1ComponentPath");
  apiPath=controller.resolveApiV1ComponentPath("InactiveMemberRecoveryCoverageService");
  check(apiPath EQ prefix & "api.v1.InactiveMemberRecoveryCoverageService","Existing resolver selects the expected mount prefix: " & apiPath);
  coveragePath=replace(apiPath,"api.v1.","includes.","one");
  coverage=createObject("component",coveragePath).init("fpw");
  check(isObject(coverage),"Coverage service and its default event dependency instantiate");
  eventService=harness.getProperty(coverage,"events","variables");
  check(compareNoCase(getMetadata(eventService).path,getDirectoryFromPath(getMetadata(coverage).path) & "ProductEventService.cfc") EQ 0,
    "Event dependency resolves to the same physical includes directory");
  controllerSource=fileRead(getMetadata(controller).path,"utf-8");
  check(find('var evidencePath=replace(resolveApiV1ComponentPath("InactiveMemberRecoveryCoverageService")',controllerSource) GT 0
    AND !find("new fpw.includes.InactiveMemberRecoveryCoverageService",controllerSource),
    "Share wrapper reuses the existing resolver instead of a fixed dev path");
  rejected=false;
  try { coverage.beginShare(0,0,"basic_save_send"); }
  catch (any invalidEvidence) { rejected=invalidEvidence.type EQ "FPW.Recovery.EvidenceFailed"; }
  check(rejected,"Invalid evidence still fails closed before persistence");

  // Zero is deliberately invalid: no fixture account, event, PDF, or mail is created.
  harness.makePublic(controller,"executeTrackedMemberShare");
  for (source in ["basic_save_send","premium_save_send"]) {
    result=controller.executeTrackedMemberShare(0,0,source);
    check(!result.SUCCESS AND result.ERROR EQ "MISSING_PLAN_ID",source & " reaches normal validation through the real wrapper");
  }
  writeOutput(serializeJSON({SUCCESS=true,MODE=len(prefix) ? "dev_subdirectory" : "root_namespace",CHECKS=checks}));
} catch (any err) {
  cfheader(statuscode=500);
  writeOutput(serializeJSON({SUCCESS=false,CHECKS=checks,ERROR=err.type,MESSAGE=err.message,DETAIL=err.detail}));
}
</cfscript>
