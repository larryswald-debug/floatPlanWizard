<cfinclude template="fpw_base_path.cfm">

<cfscript>
fpwRequireAuthUserId = 0;

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
  location(url = request.fpwBase & "/index.cfm?notice=member-required", addToken = false);
}
</cfscript>
