component {

    this.name               = "MobileAppExample_FPW";
    this.applicationTimeout = createTimeSpan(1, 0, 0, 0); // 1 day
    this.sessionManagement  = true;
    this.sessionTimeout     = createTimeSpan(0, 1, 0, 0); // 1 hour
    this.setClientCookies   = true;

    this.scriptProtect      = "all";
    this.clientManagement   = false;
    this.loginStorage       = "session";
    this.mappings["/testbox"] = expandPath("/testbox");

    public boolean function onRequestStart( string targetPage ) {
        cfsetting( showdebugoutput = false );
        var normalizedTarget = "/" & lcase( replace( targetPage, "\", "/", "all" ) );
        var isAppPage = left( normalizedTarget, len( "/app/" ) ) EQ "/app/";
        var isAdminPage = left( normalizedTarget, len( "/admin/" ) ) EQ "/admin/";
        var publicAppPages = [
            "/app/login.cfm",
            "/app/forgot-password.cfm",
            "/app/reset-password.cfm"
        ];
        var publicAdminPages = [
            "/admin/login.cfm"
        ];

        var isAdminUser = false;
        if (structKeyExists(session, "adminAuthenticated") AND session.adminAuthenticated) {
            isAdminUser = true;
        } else if (structKeyExists(session, "user") AND isStruct(session.user)) {
            if (structKeyExists(session.user, "isAdmin") AND session.user.isAdmin) {
                isAdminUser = true;
            } else if (structKeyExists(session.user, "ISADMIN") AND session.user.ISADMIN) {
                isAdminUser = true;
            } else if (structKeyExists(session.user, "role") AND lcase(session.user.role) EQ "admin") {
                isAdminUser = true;
            } else if (structKeyExists(session.user, "ROLE") AND lcase(session.user.ROLE) EQ "admin") {
                isAdminUser = true;
            }
        }

        if (
            isAppPage
            AND arrayFind( publicAppPages, normalizedTarget ) EQ 0
            AND (
                NOT structKeyExists( session, "user" )
                OR NOT structKeyExists( session.user, "userId" )
            )
        ) {
            location( url = "/fpw/app/login.cfm", addToken = false );
        }

        if (
            isAdminPage
            AND arrayFind( publicAdminPages, normalizedTarget ) EQ 0
            AND NOT isAdminUser
        ) {
            location( url = "/fpw/admin/login.cfm", addToken = false );
        }

        return true;
    }

    public void function onError( any exception, string eventName ) {
        writeOutput("<h1>Application Error</h1>");
        writeOutput("<p>#encodeForHTML(exception.message)#</p>");
        // TODO: log to file in real usage
    }
}
