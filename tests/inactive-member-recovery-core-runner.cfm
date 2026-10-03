<cfsetting showdebugoutput="false" enablecfoutputonly="true" requesttimeout="240">
<cfparam name="url.confirm" default=""><cfparam name="url.suite" default="all">
<cfif url.confirm NEQ "RUN_RECOVERY_CORE_TESTS" OR val(cgi.server_port) NEQ 8500
 OR NOT listFindNoCase("localhost,127.0.0.1,::1",cgi.server_name)
 OR NOT reFindNoCase("^(localhost|127\.0\.0\.1|\[::1\])(:8500)?$",cgi.http_host)>
 <cfheader statuscode="404"><cfabort>
</cfif>
<cfscript>
try {
 allowed="Policy,Ledger,Classifier,Sender,Enrollment,EnrollmentIntegration,Readiness,Signup";
 chosen=url.suite EQ "all" ? allowed : url.suite;
 bundles=[];
 for(suite in listToArray(chosen)){
  if(!listFind(allowed,suite)) throw(message="INVALID_TEST_SUITE");
  arrayAppend(bundles,"fpw.tests.specs.InactiveMemberRecovery" & suite & "Spec");
 }
 results=new testbox.system.TestBox(bundles=arrayToList(bundles)).runRaw().getMemento();
 failures=[];suiteResults=[];
 for(bundle in results.bundleStats) {
  arrayAppend(suiteResults,{name=bundle.name,total=bundle.totalSpecs,passed=bundle.totalPass,failed=bundle.totalFail,errors=bundle.totalError});
  if(isStruct(bundle.globalException) AND structCount(bundle.globalException))
   arrayAppend(failures,{bundle=bundle.name,message=bundle.globalException.message,detail=bundle.globalException.detail ?: ""});
  for(suite in bundle.suiteStats) for(spec in suite.specStats) if(spec.status NEQ "Passed")
   arrayAppend(failures,{name=spec.name,status=spec.status,message=spec.failMessage,
    detail=structKeyExists(spec.error,"detail") ? spec.error.detail : "",
    error=structKeyExists(spec.error,"message") ? spec.error.message : "",
    origin=isArray(spec.failOrigin) ? spec.failOrigin.filter(function(frame){return find("/tests/specs/",frame.TEMPLATE);}) : []});
 }
 output={total=results.totalSpecs,passed=results.totalPass,failed=results.totalFail,errors=results.totalError,failures=failures,suites=suiteResults};
} catch(any problem) {output={error=problem.message,detail=problem.detail ?: ""};}
</cfscript>
<cfheader statuscode="#structKeyExists(output,'TOTAL') AND output.TOTAL GT 0 AND output.FAILED EQ 0 AND output.ERRORS EQ 0 ? 200 : 500#"><cfcontent type="application/json" reset="true"><cfoutput>#serializeJSON(output)#</cfoutput>
