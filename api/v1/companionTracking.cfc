component output="false" {
  remote void function handle(string action="eligibility", string trackingSessionId="") output="true" {
    setting showdebugoutput=false;
    cfheader(name="Cache-Control",value="no-store, no-cache, must-revalidate");
    cfcontent(type="application/json; charset=utf-8");
    var response = {};
    var auth = {SUCCESS=false};
    try {
      var data = getHttpRequestData();
      var raw = structKeyExists(data,"content") ? toString(data.content) : "";
      var header = "";
      if (structKeyExists(data,"headers") && structKeyExists(data.headers,"Authorization")) header = trim(toString(data.headers.Authorization));
      var actionName = lCase(trim(arguments.action));
      var methodName = uCase(cgi.request_method);
      if (len(charsetDecode(raw,"UTF-8"))>65536) {
        response = fail("REQUEST_TOO_LARGE","Tracking request exceeds 64 KiB.",413,false);
      } else if (!listFind("eligibility,start,batch,status,stop,finish,latest",actionName)) {
        response = fail("INVALID_ACTION","Unsupported tracking action.",400,false);
      } else if ((listFind("eligibility,status,latest",actionName) && methodName!="GET") || (listFind("start,batch,stop,finish",actionName) && methodName!="POST")) {
        cfheader(name="Allow",value=listFind("eligibility,status,latest",actionName) ? "GET" : "POST");
        response = fail("METHOD_NOT_ALLOWED","Use the HTTP method defined for this action.",405,false);
      } else {
        // No session, cookie, query-string bearer, or alternate-origin proxy fallback.
        auth = apiComponent("CompanionAuthService").init("fpw").resolveBearerToken(header,"companion:tracking",false);
        if (!auth.SUCCESS) {
          response = auth;
          response.HTTP_STATUS = 401;
          if (structKeyExists(auth,"ERROR") && auth.ERROR=="COMPANION_SCOPE_DENIED") {
            response = fail("REPAIR_REQUIRED","Re-pair this device to enable automatic tracking.",403,false);
            response["rePairRequired"] = true;
          }
        } else {
          var payload = {};
          if (methodName=="POST") {
            if (!len(trim(raw)) || !isJSON(raw)) response = fail("INVALID_JSON","A JSON object is required.",400,true);
            else {
              var parsed = deserializeJSON(raw);
              if (isNull(parsed) || !isStruct(parsed)) response = fail("INVALID_JSON","A JSON object is required.",400,true);
              else payload = parsed;
            }
          } else if (structKeyExists(url,"trackingSessionId")) payload["trackingSessionId"] = url.trackingSessionId;
          if (structIsEmpty(response)) response = apiComponent("CompanionTrackingService").init("fpw").handle(actionName,auth,payload);
        }
      }
    } catch (any requestError) {
      writeLog(file="companion-tracking",type="error",text="TRACKING_REQUEST_FAILURE");
      response = fail("SERVER_ERROR","Tracking service is temporarily unavailable.",503,auth.SUCCESS);
    }
    var statusCode = structKeyExists(response,"HTTP_STATUS") ? response.HTTP_STATUS : 500;
    structDelete(response,"HTTP_STATUS");
    cfheader(statuscode=statusCode);
    writeOutput(serializeJSON(response));
  }
  private struct function fail(required string code,required string message,required numeric status,required boolean authenticated) {
    return {"SUCCESS"=false,"AUTH"=arguments.authenticated,"ERROR"=arguments.code,"MESSAGE"=arguments.message,"HTTP_STATUS"=arguments.status};
  }
  private any function apiComponent(required string name) {
    try { return createObject("component","fpw.api.v1." & arguments.name); }
    catch (any pathError) { return createObject("component","api.v1." & arguments.name); }
  }
}
