<cfsetting showdebugoutput="false">
<cfcontent type="application/json; charset=utf-8">
<cfscript>
if (!structKeyExists(session, "user") || !isStruct(session.user)) {
  session.user = {};
}
session.user.userId = 187;
session.user.id = 187;
session.user.USERID = 187;
writeOutput(serializeJSON({"SUCCESS"=true,"USERID"=session.user.userId}));
</cfscript>
