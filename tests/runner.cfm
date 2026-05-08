<cfscript>
setting requestTimeout=180;

reporter = trim(url.reporter ?: "text");
bundles = trim( url.bundles ?: "" );

// HARD SET: this is the web-mapped path to your specs.
specWebPath = "/fpw/tests";
// Mapping path TestBox expects (dot notation)
specMapping = "fpw.tests";

// Convert to an absolute filesystem path TestBox can scan.
specAbsPath = expandPath(specWebPath);
</cfscript>
<cfsavecontent variable="runnerOutput"><cfscript>
// Quick sanity diagnostics (you will SEE what it scans)
writeOutput("TestBox scan directory (web): " & specWebPath & chr(10));
writeOutput("TestBox scan directory (abs): " & specAbsPath & chr(10));
writeOutput("TestBox mapping (dot): " & specMapping & chr(10));

if ( !directoryExists(specAbsPath) ) {
  writeOutput("ERROR: Directory does not exist: " & specAbsPath & chr(10));
} else {
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
  runnerUserId = structKeyExists( url, "testUserId" ) && isNumeric( url.testUserId ) && val( url.testUserId ) GT 0 ? val( url.testUserId ) : 187;
  session.user.userId = runnerUserId;
  session.user.id = runnerUserId;
  session.user.USERID = runnerUserId;

  // Optional: list spec files so we KNOW they’re visible
  specFiles = directoryList(specAbsPath, true, "path", "*Spec.cfc");
  writeOutput("Found *Spec.cfc files: " & arrayLen(specFiles) & chr(10));
  for (f in specFiles) {
    writeOutput(" - " & f & chr(10));
  }
  writeOutput(chr(10) & "----- RUNNING TESTBOX -----" & chr(10));

  tbArgs = {
    recurse  = true,
    reporter = reporter
  };
  if ( len( bundles ) ) {
    tbArgs.bundles = bundles;
  } else {
    tbArgs.directory = specMapping;
  }

  try {
    tb = new testbox.system.TestBox( argumentCollection = tbArgs );
    tbRunOutput = tb.run();
    if ( isSimpleValue( tbRunOutput ) && len( trim( toString( tbRunOutput ) ) ) ) {
      writeOutput( toString( tbRunOutput ) );
    }
  } catch ( any testboxError ) {
    writeOutput( "TESTBOX_RUNNER_ERROR" & chr(10) );
    writeOutput( "MESSAGE: " & testboxError.message & chr(10) );
    if ( structKeyExists( testboxError, "detail" ) && len( trim( toString( testboxError.detail ) ) ) ) {
      writeOutput( "DETAIL: " & toString( testboxError.detail ) & chr(10) );
    }
    if ( structKeyExists( testboxError, "stacktrace" ) && len( trim( toString( testboxError.stacktrace ) ) ) ) {
      writeOutput( "STACKTRACE: " & toString( testboxError.stacktrace ) & chr(10) );
    }
  }
}
</cfscript></cfsavecontent><cfscript>
runnerPreview = left( reReplace( runnerOutput, "[\r\n\t]+", " | ", "all" ), 500 );
cfheader( name = "X-TestBox-Output-Length", value = toString( len( runnerOutput ) ) );
cfheader( name = "X-TestBox-Output-Preview", value = runnerPreview );
</cfscript><cfoutput>#runnerOutput#</cfoutput>

