<cfscript>
adminAuthorized = false;
if (structKeyExists(session, "adminAuthenticated") AND session.adminAuthenticated) {
    adminAuthorized = true;
} else if (structKeyExists(session, "user") AND isStruct(session.user)) {
    if (structKeyExists(session.user, "isAdmin") AND session.user.isAdmin) {
        adminAuthorized = true;
    } else if (structKeyExists(session.user, "ISADMIN") AND session.user.ISADMIN) {
        adminAuthorized = true;
    } else if (structKeyExists(session.user, "role") AND lcase(session.user.role) EQ "admin") {
        adminAuthorized = true;
    } else if (structKeyExists(session.user, "ROLE") AND lcase(session.user.ROLE) EQ "admin") {
        adminAuthorized = true;
    }
}

if (NOT adminAuthorized) {
    location(url="/fpw/admin/login.cfm", addToken=false);
}
</cfscript>
