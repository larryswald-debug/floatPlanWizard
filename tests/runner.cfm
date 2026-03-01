<cfscript>
setting requestTimeout=180;

reporter = trim(url.reporter ?: "text");

// HARD SET: this is the web-mapped path to your specs.
specWebPath = "/fpw/tests";
// Mapping path TestBox expects (dot notation)
specMapping = "fpw.tests";

// Convert to an absolute filesystem path TestBox can scan.
specAbsPath = expandPath(specWebPath);

// Quick sanity diagnostics (you will SEE what it scans)
writeOutput("TestBox scan directory (web): " & specWebPath & chr(10));
writeOutput("TestBox scan directory (abs): " & specAbsPath & chr(10));
writeOutput("TestBox mapping (dot): " & specMapping & chr(10));

if ( !directoryExists(specAbsPath) ) {
  writeOutput("ERROR: Directory does not exist: " & specAbsPath & chr(10));
  abort;
}

if ( !structKeyExists( application, "floatPlanService" ) ) {
  application.floatPlanService = {
    normalizeTime = function( required any input ) {
      return arguments.input;
    }
  };
}

// Integration specs make HTTP calls back into API endpoints and rely on
// request cookie/session scopes. Ensure this runner request has explicit
// cookie values so those calls can consistently reattach to this session.
if ( structKeyExists( session, "sessionid" ) ) {
  cookie.JSESSIONID = trim( toString( session.sessionid ) );
}
if ( isDefined( "CFID" ) ) {
  cookie.CFID = trim( toString( CFID ) );
}
if ( isDefined( "CFTOKEN" ) ) {
  cookie.CFTOKEN = trim( toString( CFTOKEN ) );
}
if ( !structKeyExists( session, "user" ) || !isStruct( session.user ) ) {
  session.user = {};
}
if ( !structKeyExists( session.user, "userId" ) || !isNumeric( session.user.userId ) || val( session.user.userId ) LTE 0 ) {
  runnerUserId = structKeyExists( url, "testUserId" ) && isNumeric( url.testUserId ) ? val( url.testUserId ) : 187;
  session.user.userId = runnerUserId;
  session.user.id = runnerUserId;
  session.user.USERID = runnerUserId;
}

// Optional: list spec files so we KNOW they’re visible
specFiles = directoryList(specAbsPath, true, "path", "*Spec.cfc");
writeOutput("Found *Spec.cfc files: " & arrayLen(specFiles) & chr(10));
for (f in specFiles) writeOutput(" - " & f & chr(10));
writeOutput(chr(10) & "----- RUNNING TESTBOX -----" & chr(10));

tb = new testbox.system.TestBox(
  directory = specMapping,
  recurse   = true,
  reporter  = reporter
);

writeOutput(tb.run());
</cfscript>
