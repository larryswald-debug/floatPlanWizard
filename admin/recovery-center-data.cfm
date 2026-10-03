<cfsetting showdebugoutput="false" enablecfoutputonly="true" requesttimeout="120">
<cfcontent type="application/json; charset=utf-8" reset="true">
<cfheader name="Cache-Control" value="no-store">
<cfscript>
try {
 if(!structKeyExists(request,"fpwAdminAuthorization") OR !request.fpwAdminAuthorization.authorized) throw(type="FPW.Recovery.Admin",message="ADMIN_REQUIRED");
 values=cgi.request_method EQ "POST" ? duplicate(form):duplicate(url);
 for(key in values) {
  if(!listFindNoCase("action,userId,runId,messageId,contactNumber,destinationStage,templateId,dateFrom,dateTo,days,revision,search,decision,status,page,pageSize,historyPage,evaluationsPage,messagesPage,auditPage,firstDelayHours,stageIntervalHours,attributionWindowHours,subject,body,reviewToken,confirmed,adminCsrfToken,fieldnames",key))
   throw(type="FPW.Recovery.Admin",message="INVALID_FIELDS");
  if(!isSimpleValue(values[key])) throw(type="FPW.Recovery.Admin",message="INVALID_FIELDS");
 }
 if(structKeyExists(values,"pageSize")) values.pageSize=min(100,max(1,val(values.pageSize)));
 action=structKeyExists(values,"action") ? toString(values.action):"dashboard";
 result=new fpw.api.v1.AdminRecoveryCenterService().init().execute(action,values);
 writeOutput(serializeJSON({SUCCESS=true,DATA=result}));
} catch(FPW.Recovery.Settings invalidSettings) {
 cfheader(statuscode=400);
 writeOutput(serializeJSON({SUCCESS=false,CODE="INVALID_TIMING_HOURS",MESSAGE="Enter whole hours from 1 through 720 for each timing setting."}));
} catch(FPW.Recovery.Admin rejected) {
 cfheader(statuscode=400);
 writeOutput(serializeJSON({SUCCESS=false,CODE=rejected.message,MESSAGE="The request could not be confirmed. Refresh the current view and review again."}));
} catch(any unavailable) {
 cfheader(statuscode=500);
 writeOutput(serializeJSON({SUCCESS=false,CODE="RECOVERY_CENTER_UNAVAILABLE",MESSAGE="The operation could not be verified. Refresh current history before retrying."}));
}
</cfscript>
