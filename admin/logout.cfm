<cfscript>
if (structKeyExists(session, "adminAuthenticated")) {
    structDelete(session, "adminAuthenticated");
}
if (structKeyExists(session, "adminUser")) {
    structDelete(session, "adminUser");
}
</cfscript>
<cflocation url="/fpw/admin/login.cfm" addToken="false">
