<cfsetting showdebugoutput="false" enablecfoutputonly="true" requesttimeout="240">
<cfparam name="url.confirm" default="">
<cfheader name="Cache-Control" value="no-store">
<cfscript>
serverName=structKeyExists(cgi,"server_name") ? lcase(trim(cgi.server_name)) : "";
httpHost=structKeyExists(cgi,"http_host") ? lcase(trim(cgi.http_host)) : "";
localRequest=listFindNoCase("localhost,127.0.0.1,::1",serverName)
  AND reFindNoCase("^(localhost|127\.0\.0\.1|\[::1\])(:8500)?$",httpHost)
  AND val(cgi.server_port) EQ 8500
  AND listFindNoCase("127.0.0.1,::1,0:0:0:0:0:0:0:1,172.19.0.1",cgi.remote_addr)
  AND structKeyExists(application,"env") AND listFindNoCase("dev,development,local",application.env);
</cfscript>
<cfif url.confirm NEQ "RUN_COMPANION_TRACKING_TESTS" OR NOT localRequest>
  <cfheader statuscode="404"><cfcontent type="application/json; charset=utf-8" reset="true">
  <cfoutput>#serializeJSON({"SUCCESS"=false,"ERROR"="LOCAL_TEST_CONFIRMATION_REQUIRED"})#</cfoutput><cfabort>
</cfif>
<cfif NOT directoryExists(expandPath("/testbox/system"))>
  <cfheader statuscode="503"><cfcontent type="application/json; charset=utf-8" reset="true">
  <cfoutput>#serializeJSON({"SUCCESS"=false,"ERROR"="TESTBOX_NOT_INSTALLED"})#</cfoutput><cfabort>
</cfif>
<cfquery name="targetDatabase" datasource="fpw">SELECT DATABASE() database_name</cfquery>
<cfif targetDatabase.recordCount NEQ 1 OR ucase(targetDatabase.database_name[1]) NEQ "FPW">
  <cfheader statuscode="409"><cfcontent type="application/json; charset=utf-8" reset="true">
  <cfoutput>#serializeJSON({"SUCCESS"=false,"ERROR"="LOCAL_FPW_DATABASE_REQUIRED"})#</cfoutput><cfabort>
</cfif>
<cftry>
  <cfscript>
    beforeUsers=queryExecute("SELECT COUNT(*) n FROM users WHERE email LIKE 'codex-tracking-%@example.test'",{},{datasource="fpw"}).n[1];
    runner=new testbox.system.TestBox(bundles="fpw.tests.specs.CompanionTrackingSpec");
    raw=runner.runRaw().getMemento();
    results={totalSpecs=raw.totalSpecs,totalPass=raw.totalPass,totalFail=raw.totalFail,totalError=raw.totalError,specs=[]};
    for(bundle in raw.bundleStats) for(suite in bundle.suiteStats) for(spec in suite.specStats)
      arrayAppend(results.specs,{name=spec.name,status=spec.status,message=spec.failMessage,detail=spec.failDetail,
        origin=isArray(spec.failOrigin) AND arrayLen(spec.failOrigin) ? spec.failOrigin[1] : {}});
    afterUsers=queryExecute("SELECT COUNT(*) n FROM users WHERE email LIKE 'codex-tracking-%@example.test'",{},{datasource="fpw"}).n[1];
    result={"SUCCESS"=raw.totalSpecs GT 0 AND raw.totalFail EQ 0 AND raw.totalError EQ 0 AND beforeUsers EQ afterUsers,
      "RESULTS"=results,"CLEANUP"={"SUCCESS"=beforeUsers EQ afterUsers,"beforeUsers"=beforeUsers,"afterUsers"=afterUsers}};
  </cfscript>
  <cfcatch>
    <cfheader statuscode="500">
    <cfset result={"SUCCESS"=false,"ERROR"="TRACKING_TEST_RUN_FAILED","MESSAGE"=cfcatch.message,"DETAIL"=cfcatch.detail}>
  </cfcatch>
</cftry>
<cfcontent type="application/json; charset=utf-8" reset="true"><cfoutput>#serializeJSON(result)#</cfoutput>
