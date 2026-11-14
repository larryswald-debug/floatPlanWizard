component output=false {
  // Test-only defense in depth. This component and all runners must also be excluded from delivery.
  public struct function validateAccess(required string environment, required string serverName,
      required string httpHost, required numeric serverPort, required numeric userId,
      required string confirmation, required string expectedConfirmation) {
    if (!listFindNoCase("dev,development,local",arguments.environment)
        OR !listFindNoCase("localhost,127.0.0.1,::1",arguments.serverName)
        OR !listFindNoCase("localhost:8500,127.0.0.1:8500,[::1]:8500",arguments.httpHost)
        OR arguments.serverPort NEQ 8500) {
      return {ALLOWED=false,STATUSCODE=404,CODE="LOCAL_TEST_ONLY"};
    }
    if (arguments.userId LTE 0) return {ALLOWED=false,STATUSCODE=401,CODE="TEST_AUTH_REQUIRED"};
    if (!len(arguments.expectedConfirmation) OR arguments.confirmation NEQ arguments.expectedConfirmation)
      return {ALLOWED=false,STATUSCODE=403,CODE="TEST_CONFIRMATION_REQUIRED"};
    return {ALLOWED=true,STATUSCODE=200,CODE=""};
  }

  public struct function validateRequest(required string expectedConfirmation) {
    var userId=0;
    if (structKeyExists(session,"user") AND isStruct(session.user)) {
      if (structKeyExists(session.user,"userId") AND isNumeric(session.user.userId)) userId=val(session.user.userId);
      else if (structKeyExists(session.user,"id") AND isNumeric(session.user.id)) userId=val(session.user.id);
    }
    var allowed=validateAccess(
      environment=structKeyExists(application,"env") ? toString(application.env) : "",
      serverName=toString(cgi.server_name),httpHost=toString(cgi.http_host),serverPort=val(cgi.server_port),
      userId=userId,confirmation=structKeyExists(url,"confirm") ? toString(url.confirm) : "",
      expectedConfirmation=arguments.expectedConfirmation);
    if (!allowed.ALLOWED) return allowed;
    return new fpw.api.v1.AuthRequestGuardService().init().validateMutation();
  }
}


