component {

    this.name               = "MobileAppExample_FPW";
    this.applicationTimeout = createTimeSpan(1, 0, 0, 0); // 1 day
    this.sessionManagement  = true;
    this.sessionTimeout     = createTimeSpan(0, 1, 0, 0); // 1 hour
    this.setClientCookies   = true;

    this.scriptProtect      = "all";
    this.clientManagement   = false;
    this.loginStorage       = "session";

    public boolean function onRequestStart( string targetPage ) {
        cfsetting( showdebugoutput = true );
        return true;
    }

    public void function onError( any exception, string eventName ) {
        writeOutput("<h1>Application Error</h1>");
        writeOutput("<p>#encodeForHTML(exception.message)#</p>");
        // TODO: log to file in real usage
    }
}
