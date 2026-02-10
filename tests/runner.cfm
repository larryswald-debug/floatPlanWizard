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
