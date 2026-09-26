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

if (fpwRequireAuthUserId LTE 0) {
  if (len(request.fpwRecoveryLoginUrl)) {
    location(url = request.fpwRecoveryLoginUrl, addToken = false);
  }
  location(url = request.fpwBase & "/index.cfm?notice=member-required", addToken = false);
}
</cfscript>
