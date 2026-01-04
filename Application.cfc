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
        var publicAppPages = [
            "/app/login.cfm",
            "/app/forgot-password.cfm",
            "/app/reset-password.cfm"
        ];

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

        return true;
    }

    public void function onError( any exception, string eventName ) {
        writeOutput("<h1>Application Error</h1>");
        writeOutput("<p>#encodeForHTML(exception.message)#</p>");
        // TODO: log to file in real usage
    }
}
