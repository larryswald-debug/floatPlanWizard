component output=false {
  variables.ttlSeconds=14400;
  variables.maximumIntents=8;

  public string function basePath() {
    if (structKeyExists(request,"fpwBase")) return toString(request.fpwBase);
    var script=replace(toString(cgi.script_name ?: ""),"\","/","all");
    return reReplaceNoCase(script,"/(api|app|tests|admin)/.*$","");
  }

  public struct function createIntent(required string destinationKey,struct context={},struct source={}) {
    var destination=arguments.destinationKey;
    var values={};
    if (!listFind("dashboard,account,vessel,planner,routes,plans,route,draft",destination))
      throw(type="FPW.Auth.InvalidIntent",message="Choose a supported destination.");
    if (listFind("dashboard,account",destination)) {
      if (!structIsEmpty(arguments.context)) throw(type="FPW.Auth.InvalidIntent",message="Unexpected destination context.");
    } else {
      if (structKeyExists(arguments.context,"recoveryAction")) throw(type="FPW.Auth.InvalidIntent",message="Unexpected destination context.");
      values=duplicate(arguments.context);
      values.recoveryAction=destination;
      if (!len(createObject("component",componentPath("includes.InactiveMemberRecoveryActionPathService")).buildPath(basePath(),values)))
        throw(type="FPW.Auth.InvalidIntent",message="Invalid destination context.");
    }
    var token=lCase(binaryEncode(binaryDecode(generateSecretKey("AES",256),"base64"),"hex"));
    var entry={token=token,destinationKey=destination,values=values,source=normalizeSource(arguments.source),
      createdAt=now(),expiresAt=dateAdd("s",variables.ttlSeconds,now()),waitForContinue=false,
      userId=structKeyExists(session,"user") AND isStruct(session.user) ? val(session.user.userId ?: session.user.id ?: 0) : 0};
    lock scope="session" type="exclusive" timeout="5" {
      ensureMap();
      purge();
      while (structCount(session.fpwAuthIntents) GTE variables.maximumIntents) {
        var oldest="";
        for (var key in session.fpwAuthIntents)
          if (!len(oldest) OR dateCompare(session.fpwAuthIntents[key].createdAt,session.fpwAuthIntents[oldest].createdAt) LT 0) oldest=key;
        structDelete(session.fpwAuthIntents,oldest);
      }
      session.fpwAuthIntents[token]=entry;
    }
    return duplicate(entry);
  }

  public struct function getIntent(required string token,numeric userId=0) {
    var result={};
    if (!validToken(arguments.token)) return result;
    lock scope="session" type="exclusive" timeout="5" {
      ensureMap();
      purge();
      if (structKeyExists(session.fpwAuthIntents,arguments.token)) {
        var found=session.fpwAuthIntents[arguments.token];
        if (found.userId EQ 0 OR (arguments.userId GT 0 AND found.userId EQ arguments.userId)) result=duplicate(found);
      }
    }
    return result;
  }

  // Bind all pending tabs on authentication and discard a previous member's state.
  public void function bindMember(required numeric userId) {
    if (arguments.userId LTE 0) return;
    lock scope="session" type="exclusive" timeout="5" {
      ensureMap();
      purge();
      for (var key in session.fpwAuthIntents) {
        if (session.fpwAuthIntents[key].userId GT 0 AND session.fpwAuthIntents[key].userId NEQ arguments.userId)
          structDelete(session.fpwAuthIntents,key);
        else session.fpwAuthIntents[key].userId=arguments.userId;
      }
      if (structKeyExists(session,"fpwAuthOverviewUserId") AND val(session.fpwAuthOverviewUserId) NEQ arguments.userId)
        structDelete(session,"fpwAuthOverviewUserId");
      if (structKeyExists(session,"fpwAuthCreatedNotice") AND session.fpwAuthCreatedNotice.userId NEQ arguments.userId)
        structDelete(session,"fpwAuthCreatedNotice");
    }
  }

  public boolean function bindIntent(required string token,required numeric userId) {
    var bound=false;
    if (!validToken(arguments.token) OR arguments.userId LTE 0) return false;
    lock scope="session" type="exclusive" timeout="5" {
      ensureMap();
      purge();
      for (var key in session.fpwAuthIntents)
        if (session.fpwAuthIntents[key].userId GT 0 AND session.fpwAuthIntents[key].userId NEQ arguments.userId)
          structDelete(session.fpwAuthIntents,key);
      if (structKeyExists(session.fpwAuthIntents,arguments.token)) {
        session.fpwAuthIntents[arguments.token].userId=arguments.userId;
        bound=true;
      }
    }
    return bound;
  }

  public struct function resolve(required string token,required numeric userId,boolean newAccount=false) {
    var entry=getIntent(arguments.token,arguments.userId);
    if (structIsEmpty(entry)) return {};
    if (!bindIntent(arguments.token,arguments.userId)) return {};
    entry.userId=arguments.userId;
    if (arguments.newAccount) {
      lock scope="session" type="exclusive" timeout="5" {
        if (structKeyExists(session.fpwAuthIntents,arguments.token)) session.fpwAuthIntents[arguments.token].waitForContinue=true;
      }
      entry.waitForContinue=true;
    }
    entry.recovery={action="",routeId=0,routeInstanceId=0,routeCode="",floatPlanId=0,basicDraft=false};
    if (!structIsEmpty(entry.values))
      entry.recovery=createObject("component",componentPath("includes.InactiveMemberRecoveryDestinationService")).init("fpw").resolveRequest(arguments.userId,entry.values);
    entry.redirectUrl=basePath() & "/app/"
      & (!arguments.newAccount AND !(entry.waitForContinue ?: false) AND entry.destinationKey EQ "account" ? "account" : "dashboard")
      & ".cfm?authIntent=" & entry.token;
    return entry;
  }

  public boolean function allowContinuation(required string token,required numeric userId) {
    if (arguments.userId LTE 0 OR structIsEmpty(getIntent(arguments.token,arguments.userId))) return false;
    lock scope="session" type="exclusive" timeout="5" {
      if (!structKeyExists(session.fpwAuthIntents,arguments.token)) return false;
      session.fpwAuthIntents[arguments.token].waitForContinue=false;
    }
    return true;
  }

  public boolean function discard(required string token,numeric userId=0) {
    if (structIsEmpty(getIntent(arguments.token,arguments.userId))) return false;
    lock scope="session" type="exclusive" timeout="5" {
      if (structKeyExists(session,"fpwAuthIntents")) structDelete(session.fpwAuthIntents,arguments.token);
    }
    return true;
  }

  public void function markAccountCreated(required numeric userId,required string email) {
    lock scope="session" type="exclusive" timeout="5" {
      ensureMap();
      purge();
      for (var key in session.fpwAuthIntents)
        if (session.fpwAuthIntents[key].userId EQ arguments.userId) session.fpwAuthIntents[key].waitForContinue=true;
      session.fpwAuthOverviewUserId=arguments.userId;
      session.fpwAuthCreatedNotice={userId=arguments.userId,email=arguments.email};
    }
  }

  public boolean function needsOverview(required numeric userId) {
    return structKeyExists(session,"fpwAuthOverviewUserId") AND val(session.fpwAuthOverviewUserId) EQ arguments.userId;
  }

  public void function acknowledgeOverview(required numeric userId) {
    lock scope="session" type="exclusive" timeout="5" {
      if (structKeyExists(session,"fpwAuthOverviewUserId") AND val(session.fpwAuthOverviewUserId) EQ arguments.userId)
        structDelete(session,"fpwAuthOverviewUserId");
    }
  }

  public string function takeCreatedNotice(required numeric userId) {
    var email="";
    lock scope="session" type="exclusive" timeout="5" {
      if (structKeyExists(session,"fpwAuthCreatedNotice") AND session.fpwAuthCreatedNotice.userId EQ arguments.userId) {
        email=session.fpwAuthCreatedNotice.email;
        structDelete(session,"fpwAuthCreatedNotice");
      }
    }
    return email;
  }

  public struct function normalizeSource(struct source={}) {
    var result={};
    var allowed={
      source_page="great_loop_trip_planning,boat_fuel_calculator,great_loop_locks,top_nav,footer,dedicated_login,dedicated_join",
      section="daily_decisions,after_planning_guide,top_nav,footer,account,great_loop_menu",
      cta_type="plan_trip,plan_route,account,dashboard",
      label="Start Planning,open FPW's Trip Planner workspace,Start Free,Account,Dashboard,My Account"
    };
    for (var key in allowed)
      if (structKeyExists(arguments.source,key) AND isSimpleValue(arguments.source[key])
        AND listFind(allowed[key],toString(arguments.source[key]))) result[key]=toString(arguments.source[key]);
    return result;
  }

  private boolean function validToken(required string token) {
    return len(arguments.token) EQ 64 AND reFind("^[a-f0-9]+$",arguments.token) EQ 1;
  }
  private void function ensureMap() {
    if (!structKeyExists(session,"fpwAuthIntents") OR !isStruct(session.fpwAuthIntents)) session.fpwAuthIntents={};
  }
  private void function purge() {
    for (var key in session.fpwAuthIntents)
      if (!isStruct(session.fpwAuthIntents[key]) OR !structKeyExists(session.fpwAuthIntents[key],"expiresAt")
        OR dateCompare(session.fpwAuthIntents[key].expiresAt,now()) LTE 0) structDelete(session.fpwAuthIntents,key);
  }

  private string function componentPath(required string relativePath) {
    var prefix=reReplaceNoCase(getMetadata(this).name,"(^|[.])includes[.][^.]+$","");
    return (len(prefix) ? prefix & "." : "") & arguments.relativePath;
  }
}
