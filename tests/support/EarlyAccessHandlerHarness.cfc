component output="false" {
  public struct function load(required string handlerPath) {
    if (!listFind("index.cfm,assets/admin/index.cfm", arguments.handlerPath)
      OR uCase(cgi.request_method) NEQ "GET") {
      throw(type="tests.InvalidEarlyAccessHarnessRequest",message="A known template and GET are required.");
    }
    var rendered = "";
    try {
      savecontent variable="rendered" {
        include "/fpw/#arguments.handlerPath#";
      }
    } catch (MissingInclude existingPageIncludeFailure) {
      // The retained assets POST handler exits before this pre-existing GET-only navigation include.
      // Its helper and config have already loaded; no other include/compilation error is ignored.
      if (arguments.handlerPath NEQ "assets/admin/index.cfm"
        OR findNoCase("includes/prelaunch_top_nav.cfm", existingPageIncludeFailure.message) EQ 0
        OR !structKeyExists(variables, "fpwSendPrelaunchWelcomeEmail")
        OR !structKeyExists(variables, "prelaunchWelcomeEmailConfig")) {
        rethrow;
      }
    }
    return {
      send = variables.fpwSendPrelaunchWelcomeEmail,
      config = duplicate(variables.prelaunchWelcomeEmailConfig)
    };
  }
}
