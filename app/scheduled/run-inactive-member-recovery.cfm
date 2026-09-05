<cfsetting enablecfoutputonly="true" showdebugoutput="false" requesttimeout="120">
<cfcontent type="application/json; charset=utf-8" reset="true">
<cfheader name="Cache-Control" value="no-store, no-cache, must-revalidate">
<cfheader name="Pragma" value="no-cache">
<cfscript>
httpStatus=200;
response={};
try {
  service=new fpw.api.v1.InactiveMemberRecoveryService();
  settings=service.getRunnerSettings();
  providedToken=structKeyExists(cgi,"http_x_fpw_recovery_token") ? trim(toString(cgi.http_x_fpw_recovery_token)) : "";
  if (!len(providedToken) AND structKeyExists(url,"token")) providedToken=trim(toString(url.token));
  if (!len(settings.token) OR !len(providedToken)
    OR compare(hash(providedToken,"SHA-256"),hash(settings.token,"SHA-256")) NEQ 0) {
    httpStatus=403;
    response={"ok"=false,"error"="UNAUTHORIZED"};
  } else if (cgi.request_method NEQ "GET") {
    httpStatus=405;
    response={"ok"=false,"error"="METHOD_NOT_ALLOWED"};
  } else {
    validOptions=true;
    for (key in url) if (!listFindNoCase("token,batchSize,dryRun",key)) validOptions=false;
    batchValue=structKeyExists(url,"batchSize") ? toString(url.batchSize) : "25";
    dryValue=structKeyExists(url,"dryRun") ? lCase(toString(url.dryRun)) : "true";
    if (!reFind("^[0-9]{1,3}$",batchValue) OR val(batchValue) LT 1 OR val(batchValue) GT 100
      OR !listFind("true,false",dryValue) OR !validOptions) {
      httpStatus=400;
      response={"ok"=false,"error"="INVALID_OPTIONS"};
    } else if (dryValue EQ "false" AND !settings.liveEnabled) {
      httpStatus=403;
      response={"ok"=false,"error"="LIVE_MODE_DISABLED"};
    } else {
      dsn=structKeyExists(application,"dsn") ? toString(application.dsn) : "fpw";
      service.init(datasource=dsn,liveEnabled=settings.liveEnabled);
      response=service.processBatch(batchSize=val(batchValue),dryRun=(dryValue EQ "true"));
      if (!response.ok) httpStatus=503;
    }
  }
} catch (any runnerError) {
  httpStatus=500;
  response={"ok"=false,"error"="RECOVERY_RUNNER_FAILED"};
  writeLog(file="fpw-inactive-recovery",type="error",text="RECOVERY_RUNNER_FAILED");
}
</cfscript>
<cfheader statuscode="#httpStatus#">
<cfoutput>#serializeJSON(response)#</cfoutput>
