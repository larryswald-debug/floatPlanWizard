component output=false {
  remote void function bootstrap(string destinationKey="",string context="{}",string source="{}",string intentToken="") output=true {
    cfsetting(showdebugoutput=false);
    cfcontent(type="application/json; charset=utf-8");
    cfheader(name="Cache-Control",value="no-store, no-cache, must-revalidate");
    var response={SUCCESS=false,AUTH=false,ERROR="INVALID_INTENT",MESSAGE="The requested destination is invalid."};
    try {
      if (compareNoCase(cgi.request_method,"GET") NEQ 0) {
        cfheader(statuscode=405);
      } else {
        var guard=createObject("component",componentPath("api.v1.AuthRequestGuardService"));
        var continuation=createObject("component",componentPath("includes.AuthContinuationService"));
        var userId=currentUserId();
        var entry={};
        if (len(arguments.intentToken)) {
          entry=continuation.getIntent(arguments.intentToken,userId);
          if (structIsEmpty(entry)) throw(type="FPW.Auth.IntentExpired",message="Your destination expired. Select the original link again.");
        } else if (len(arguments.destinationKey)) {
          var intentContext=deserializeJSON(arguments.context,false);
          var intentSource=deserializeJSON(arguments.source,false);
          if (!isStruct(intentContext) OR !isStruct(intentSource)) throw(type="FPW.Auth.InvalidIntent");
          entry=continuation.createIntent(arguments.destinationKey,intentContext,intentSource);
        }
        response={SUCCESS=true,AUTH=userId GT 0,USER=userId GT 0 ? session.user : {},
          CSRF_TOKEN=guard.getOrCreateCsrfToken(),DISCLOSURE=createObject("component",componentPath("api.v1.join")).getConsentDisclosure(),
          INTENT_TOKEN=structIsEmpty(entry) ? "" : entry.token,REDIRECT_URL="",LOGIN_URL=continuation.basePath() & "/app/login.cfm"};
        if (!structIsEmpty(entry)) {
          response.LOGIN_URL &= "?authIntent=" & entry.token;
          if (userId GT 0) {
            var resolved=continuation.resolve(entry.token,userId,continuation.needsOverview(userId));
            response.REDIRECT_URL=resolved.redirectUrl;
          }
        }
      }
    } catch (any failure) {
      cfheader(statuscode=400);
      response={SUCCESS=false,AUTH=false,ERROR=failure.type EQ "FPW.Auth.IntentExpired" ? "INTENT_EXPIRED" : "INVALID_INTENT",
        MESSAGE="Select the original destination again and retry."};
    }
    writeOutput(serializeJSON(response));
  }

  remote void function handle() output=true {
    cfsetting(showdebugoutput=false);
    cfcontent(type="application/json; charset=utf-8");
    cfheader(name="Cache-Control",value="no-store, no-cache, must-revalidate");
    var response={SUCCESS=false,AUTH=false,ERROR="SERVER_ERROR",MESSAGE="Account access is temporarily unavailable."};
    var ticket={};
    var creationTicket={};
    var outcome="error";
    var limiter=createObject("component",componentPath("api.v1.AuthRateLimitService")).init("fpw");
    try {
      var raw=toString(getHttpRequestData().content);
      var body=len(trim(raw)) ? deserializeJSON(raw,false) : duplicate(form);
      if (!isStruct(body)) throw(type="FPW.Auth.InvalidBody");
      var guard=createObject("component",componentPath("api.v1.AuthRequestGuardService"));
      var permission=guard.validateMutation(body);
      if (!permission.ALLOWED) {
        response=denial(permission);
      } else {
        var action=lcase(trim(toString(body.action ?: "login")));
        var continuation=createObject("component",componentPath("includes.AuthContinuationService"));
        var token=toString(body.intentToken ?: "");
        if (action EQ "logout") {
          sessionInvalidate();
          response={SUCCESS=true,AUTH=false,MESSAGE="Logged out"};
        } else if (listFind("intent-ack,intent-dismiss,intent-continue,overview-ack",action)) {
          var userId=currentUserId();
          var acknowledged=false;
          if (action EQ "overview-ack") {
            if (userId GT 0) {
              continuation.acknowledgeOverview(userId);
              acknowledged=true;
            }
          } else if (action EQ "intent-continue") {
            if (userId GT 0) acknowledged=continuation.allowContinuation(token,userId);
          } else if (action EQ "intent-dismiss" OR userId GT 0) acknowledged=continuation.discard(token,userId);
          response={SUCCESS=true,AUTH=userId GT 0,ACKNOWLEDGED=acknowledged};
        } else if (listFind("login,continue",action)) {
          var email=lcase(trim(toString(body.email ?: "")));
          var password=trim(toString(body.password ?: ""));
          var entry=len(token) ? continuation.getIntent(token,currentUserId()) : {};
          if (len(token) AND structIsEmpty(entry)) {
            response={SUCCESS=false,AUTH=false,ERROR="INTENT_EXPIRED",MESSAGE="Select your original destination again."};
          } else if (action EQ "continue" AND currentUserId() GT 0) {
            response={SUCCESS=false,AUTH=false,ERROR="SESSION_CHANGED",MESSAGE="Your sign-in state changed. Close this form and select your destination again."};
          } else if (!len(email) OR !len(password) OR len(email) GT 255 OR !isValid("email",email)) {
            response={SUCCESS=false,AUTH=false,ERROR="MISSING_CREDENTIALS",MESSAGE="Enter a valid email and password."};
          } else {
            var admission=limiter.admit("authenticate",email,guard.getClientIp());
            if (!admission.ALLOWED) response=denial(admission);
            else {
              ticket=admission.TICKET;
              if (len(trim(toString(body.website ?: "")))) {
                response={SUCCESS=true,AUTH=false,MESSAGE="Request received."};
              } else {
                var member=findMember(email);
                if (member.recordCount GT 0) {
                  response=authenticateMember(member,password);
                  outcome=response.SUCCESS ? "success" : "failure";
                } else if (action EQ "login") {
                  response=invalidLogin();
                  outcome="failure";
                } else {
                  var creation=limiter.admit("create_account",email,guard.getClientIp());
                  if (!creation.ALLOWED) response=denial(creation);
                  else {
                    creationTicket=creation.TICKET;
                    var signupBody=duplicate(body);
                    if (!structIsEmpty(entry) AND (entry.source.source_page ?: "") EQ "great_loop_trip_planning") {
                      signupBody.landing_key="great_loop_trip_planning";
                      signupBody.source_content_type="seo_guide";
                      signupBody.cta_type="plan_trip";
                    } else if (structKeyExists(body,"attribution") AND isStruct(body.attribution)) {
                      for (var attributionKey in ["landing_key","source_content_type","cta_type"])
                        if (structKeyExists(body.attribution,attributionKey)) signupBody[attributionKey]=body.attribution[attributionKey];
                    }
                    response=createObject("component",componentPath("api.v1.join")).createAccount(signupBody,true);
                    if (!response.SUCCESS AND (response.ERROR ?: "") EQ "EMAIL_EXISTS") {
                      member=findMember(email);
                      response=member.recordCount ? authenticateMember(member,password) : invalidLogin();
                      outcome=response.SUCCESS ? "success" : "failure";
                    } else if (response.SUCCESS AND (response.AUTH ?: false)) outcome="success";
                    else if ((response.ERROR ?: "") EQ "AUTH_UNAVAILABLE") cfheader(statuscode=503);
                  }
                }
                if (response.SUCCESS AND (response.AUTH ?: false)) {
                  // Session rotation or a member change can invalidate the pre-authentication entry.
                  entry=len(token) ? continuation.getIntent(token,response.USER.userId) : {};
                  if (structIsEmpty(entry)) entry=continuation.createIntent("dashboard");
                  var resolved=continuation.resolve(entry.token,response.USER.userId,(response.ACCOUNT_CREATED ?: false) OR continuation.needsOverview(response.USER.userId));
                  response.REDIRECT_URL=resolved.redirectUrl;
                  response.INTENT_TOKEN=entry.token;
                  response.CSRF_TOKEN=guard.rotateCsrfToken();
                }
              }
            }
          }
        } else response={SUCCESS=false,AUTH=false,ERROR="INVALID_ACTION",MESSAGE="Unsupported account request."};
      }
    } catch (any failure) {
      cfheader(statuscode=503);
      writeLog(file="fpw_auth",type="error",text="AUTH_REQUEST_FAILED");
      response={SUCCESS=false,AUTH=false,ERROR="AUTH_UNAVAILABLE",MESSAGE="Account access is temporarily unavailable. Please try again later."};
    } finally {
      if (!structIsEmpty(creationTicket)) limiter.finish(creationTicket,outcome EQ "success" ? "success" : "error");
      if (!structIsEmpty(ticket)) limiter.finish(ticket,outcome);
    }
    writeOutput(serializeJSON(response));
  }

  private query function findMember(required string email) {
    return queryExecute("SELECT userId,fName,lName,email,password AS dbPassword,lastLogin,mobilePhone FROM users WHERE email=:email LIMIT 1",
      {email={value=arguments.email,cfsqltype="cf_sql_varchar"}},{datasource="fpw"});
  }

  private struct function authenticateMember(required query member,required string password) {
    var checked=createObject("component",componentPath("api.v1.PasswordHashService")).verifyAndUpgrade(arguments.member.userId[1],arguments.password,arguments.member.dbPassword[1],"fpw");
    if (!checked.VERIFIED) return invalidLogin();
    var userId=val(arguments.member.userId[1]);
    queryExecute("UPDATE users SET lastLogin=:stamp WHERE userId=:userId",
      {stamp={value=now(),cfsqltype="cf_sql_timestamp"},userId={value=userId,cfsqltype="cf_sql_integer"}},{datasource="fpw"});
    sessionRotate();
    session.user={id=userId,userId=userId,USERID=userId,email=arguments.member.email[1],EMAIL=arguments.member.email[1],
      firstName=arguments.member.fName[1] ?: "",FIRSTNAME=arguments.member.fName[1] ?: "",
      lastName=arguments.member.lName[1] ?: "",LASTNAME=arguments.member.lName[1] ?: "",
      mobilePhone=arguments.member.mobilePhone[1] ?: "",MOBILEPHONE=arguments.member.mobilePhone[1] ?: "",
      lastLogin=now(),LASTLOGIN=now()};
    createObject("component",componentPath("includes.AuthContinuationService")).bindMember(userId);
    try {
      createObject("component",componentPath("includes.ProductEventService")).init("fpw").recordEvent(
        userId=userId,eventName="login",entityType="user",entityId=userId,eventSource="password_auth",
        metadata={auth_method="password"},
        idempotencyKey="login:request:" & (request.fpwRequestId ?: createUUID()),
        requestCorrelationId=request.fpwRequestId ?: "");
    } catch (any auditFailure) { writeLog(file="fpw_product_events",type="error",text="auth.cfc PRODUCT_EVENT_CALL_FAILED | event=login"); }
    return {SUCCESS=true,AUTH=true,ACCOUNT_CREATED=false,USER=session.user,USERID=userId,MESSAGE="Login successful"};
  }

  private numeric function currentUserId() {
    return structKeyExists(session,"user") AND isStruct(session.user) ? val(session.user.userId ?: session.user.id ?: 0) : 0;
  }
  private struct function invalidLogin() {
    return {SUCCESS=false,AUTH=false,ERROR="INVALID_LOGIN",MESSAGE="Invalid email or password."};
  }
  private struct function denial(required struct result) {
    cfheader(statuscode=arguments.result.STATUSCODE);
    if (structKeyExists(arguments.result,"RETRYAFTER")) cfheader(name="Retry-After",value=arguments.result.RETRYAFTER);
    return {SUCCESS=false,AUTH=false,ERROR=arguments.result.CODE,MESSAGE=arguments.result.MESSAGE};
  }

  private string function componentPath(required string relativePath) {
    var prefix=reReplaceNoCase(getMetadata(this).name,"(^|[.])api[.]v1[.][^.]+$","");
    return (len(prefix) ? prefix & "." : "") & arguments.relativePath;
  }
}

