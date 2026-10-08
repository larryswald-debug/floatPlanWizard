<cfinclude template="fpw_base_path.cfm">

<cfscript>
fpwRequireAuthUserId = 0;
request.fpwRecoveryPath = "";
request.fpwRecoveryLoginUrl = "";
if (structKeyExists(url, "recoveryAction")) {
  fpwRecoveryComponentPrefix = replace(reReplace(request.fpwBase, "^/", ""), "/", ".", "all");
  fpwRecoveryActionPaths = createObject("component",
    (len(fpwRecoveryComponentPrefix) ? fpwRecoveryComponentPrefix & "." : "")
      & "includes.InactiveMemberRecoveryActionPathService");
  request.fpwRecoveryPath = fpwRecoveryActionPaths.buildPath(request.fpwBase, url);
  if (len(request.fpwRecoveryPath)) {
    request.fpwRecoveryLoginUrl = request.fpwBase & "/app/login.cfm?"
      & listRest(request.fpwRecoveryPath, "?");
  }
}

if (structKeyExists(session, "user") AND isStruct(session.user)) {
  if (structKeyExists(session.user, "userId") AND isNumeric(session.user.userId)) {
    fpwRequireAuthUserId = val(session.user.userId);
  } else if (structKeyExists(session.user, "id") AND isNumeric(session.user.id)) {
    fpwRequireAuthUserId = val(session.user.id);
  } else if (structKeyExists(session.user, "USERID") AND isNumeric(session.user.USERID)) {
    fpwRequireAuthUserId = val(session.user.USERID);
  } else if (structKeyExists(session.user, "ID") AND isNumeric(session.user.ID)) {
    fpwRequireAuthUserId = val(session.user.ID);
  }
}

request.fpwAuthHandoff = {};
request.fpwAuthOverview = false;
request.fpwAuthCreatedEmail = "";
fpwAuthComponentPrefix=replace(reReplace(request.fpwBase,"^/",""),"/",".","all");
fpwAuthContinuations = createObject("component",(len(fpwAuthComponentPrefix) ? fpwAuthComponentPrefix & "." : "") & "includes.AuthContinuationService");
if (structKeyExists(url,"authIntent") AND isSimpleValue(url.authIntent)) {
  fpwAuthEntry = fpwAuthContinuations.getIntent(toString(url.authIntent),fpwRequireAuthUserId);
  if (!structIsEmpty(fpwAuthEntry)) {
    if (fpwRequireAuthUserId GT 0) {
      request.fpwAuthHandoff=fpwAuthContinuations.resolve(fpwAuthEntry.token,fpwRequireAuthUserId);
    } else request.fpwRecoveryLoginUrl=request.fpwBase & "/app/login.cfm?authIntent=" & fpwAuthEntry.token;
  }
}
if (fpwRequireAuthUserId GT 0) request.fpwAuthOverview=fpwAuthContinuations.needsOverview(fpwRequireAuthUserId);

if (fpwRequireAuthUserId LTE 0) {
  // Only the three email destinations below can create a typed continuation here.
  // Fragments are not sent to the server; account email links carry a fixed section marker.
  if (!len(request.fpwRecoveryLoginUrl)) {
    fpwEmailDestination="";
    fpwEmailContext={};
    fpwEmailPage=lCase(replace(toString(cgi.script_name),"\","/","all"));
    if (structCount(url) EQ 1) {
      if (fpwEmailPage EQ lCase(request.fpwBase & "/app/active-cruise.cfm") AND structKeyExists(url,"floatPlanId")) {
        fpwEmailDestination="active-cruise"; fpwEmailContext={floatPlanId=url.floatPlanId};
      } else if (fpwEmailPage EQ lCase(request.fpwBase & "/app/completed-trip.cfm") AND structKeyExists(url,"id")) {
        fpwEmailDestination="completed-trip"; fpwEmailContext={id=url.id};
      } else if (fpwEmailPage EQ lCase(request.fpwBase & "/app/account.cfm") AND structKeyExists(url,"section")
        AND isSimpleValue(url.section) AND compare(toString(url.section),"email-preferences") EQ 0) {
        fpwEmailDestination="account-preferences";
      }
    }
    if (len(fpwEmailDestination)) {
      try {
        fpwEmailEntry=fpwAuthContinuations.createIntent(fpwEmailDestination,fpwEmailContext);
        request.fpwRecoveryLoginUrl=request.fpwBase & "/app/login.cfm?authIntent=" & fpwEmailEntry.token;
      } catch (FPW.Auth.InvalidIntent invalidEmailDestination) {
        // Unsupported context retains the ordinary authentication-required response.
      }
    }
  }
  if (len(request.fpwRecoveryLoginUrl)) {
    location(url = request.fpwRecoveryLoginUrl, addToken = false);
  }
  location(url = request.fpwBase & "/index.cfm?notice=member-required", addToken = false);
}
// Keep the existing opaque Dashboard handoff and new-account overview behavior.
// After authentication/explicit Continue, the destination page repeats its normal owner checks.
if (!structIsEmpty(request.fpwAuthHandoff) AND !(request.fpwAuthHandoff.waitForContinue ?: false)
  AND len(request.fpwAuthHandoff.emailDestinationPath ?: "")) {
  fpwEmailContinuePath=request.fpwAuthHandoff.emailDestinationPath;
  fpwAuthContinuations.discard(request.fpwAuthHandoff.token,fpwRequireAuthUserId);
  location(url=fpwEmailContinuePath,addToken=false);
}
// Only a successfully authenticated member page can create a return signal.
// onRequestEnd observes this after rendering; it never counts a page view as engagement.
if (fpwRequireAuthUserId GT 0 AND compareNoCase(cgi.request_method,"GET") EQ 0)
  request.fpwRecoveryAuthenticatedPageUserId=fpwRequireAuthUserId;
</cfscript>
