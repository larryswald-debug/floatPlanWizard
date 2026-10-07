<cfsetting showdebugoutput="false" enablecfoutputonly="true" requesttimeout="180">
<cfparam name="url.confirm" default="">
<cfparam name="url.action" default="run">
<cfparam name="url.fixture" default="">
<cfparam name="url.member" default="owner">
<cfparam name="url.withDueTrip" default="0">
<cfparam name="url.activeScheduled" default="0">
<cfparam name="url.operations" default="0">
<cfheader name="Cache-Control" value="no-store">
<cfscript>
serverName=structKeyExists(cgi,"server_name") ? lcase(trim(toString(cgi.server_name))) : "";
httpHost=structKeyExists(cgi,"http_host") ? lcase(trim(toString(cgi.http_host))) : "";
serverPort=structKeyExists(cgi,"server_port") ? val(cgi.server_port) : 0;
isLocalDevRequest=listFindNoCase("localhost,127.0.0.1,::1",serverName) GT 0
  AND reFindNoCase("^(localhost|127\.0\.0\.1|\[::1\])(:8500)?$",httpHost) GT 0
  AND serverPort EQ 8500
  AND structKeyExists(cgi,"remote_addr") AND listFindNoCase("127.0.0.1,::1,0:0:0:0:0:0:0:1,172.19.0.1",trim(cgi.remote_addr)) GT 0
  AND structKeyExists(application,"env") AND listFindNoCase("dev,development,local",trim(toString(application.env))) GT 0;
</cfscript>
<cfif url.confirm NEQ "RUN_TRIP_PREVIEW_TESTS" OR NOT isLocalDevRequest>
  <cfheader statuscode="404"><cfcontent type="application/json; charset=utf-8" reset="true">
  <cfoutput>#serializeJSON({"SUCCESS"=false,"ERROR"="LOCAL_TEST_CONFIRMATION_REQUIRED"})#</cfoutput><cfabort>
</cfif>
<cfif NOT directoryExists(expandPath("/testbox/system"))>
  <cfheader statuscode="503"><cfcontent type="application/json; charset=utf-8" reset="true">
  <cfoutput>#serializeJSON({"SUCCESS"=false,"ERROR"="TESTBOX_NOT_INSTALLED"})#</cfoutput><cfabort>
</cfif>
<cfquery name="qTargetDatabase" datasource="fpw">SELECT DATABASE() AS database_name</cfquery>
<cfif qTargetDatabase.recordCount NEQ 1 OR ucase(trim(qTargetDatabase.database_name[1])) NEQ "FPW">
  <cfheader statuscode="409"><cfcontent type="application/json; charset=utf-8" reset="true">
  <cfoutput>#serializeJSON({"SUCCESS"=false,"ERROR"="LOCAL_FPW_DATABASE_REQUIRED"})#</cfoutput><cfabort>
</cfif>
<cftry>
<cfscript>
  action=lcase(trim(url.action));
  fixtureService=new fpw.tests.specs.TripPreviewServiceSpec();
  result={"SUCCESS"=true};
  lock scope="application" type="exclusive" timeout="5" {
    if(!structKeyExists(application,"fpwTripPreviewFixtures")) application.fpwTripPreviewFixtures={};
  }
  if(action EQ "run" OR action EQ "creditregression") {
    beforeCount=queryExecute("SELECT COUNT(*) n FROM users WHERE email LIKE 'codex-trip-preview-%'",{},{datasource="fpw"}).n[1];
    runner=new testbox.system.TestBox(bundles=action EQ "creditregression" ? "fpw.tests.specs.PremiumSendCreditContractSpec" : "fpw.tests.specs.TripPreviewServiceSpec");
    if(action EQ "creditregression") rawResults=runner.runRaw(testSpecs=[
      "treats every approved credit source as capability-equivalent",
      "summarizes credit sources without changing canonical credit rows",
      "keeps credit grants idempotent without reassigning the canonical row",
      "keeps planning and Basic send available at every pre-consumption boundary",
      "rejects Draft and ownership-tampered consumption before binding exactly once",
      "records and reloads one completed-send receipt for the consumed binding",
      "rejects invalid receipt sources and bindings without creating history",
      "keeps an AVAILABLE credit untouched for a general Premium send receipt",
      "never restores a consumed credit when its plan is closed or cancelled",
      "creates operational Follow streams as token-required invite streams"
    ]).getMemento();
    else rawResults=runner.runRaw().getMemento();
    results={totalSpecs=rawResults.totalSpecs,totalPass=rawResults.totalPass,totalFail=rawResults.totalFail,totalError=rawResults.totalError,specs=[]};
    for(bundle in rawResults.bundleStats) for(suite in bundle.suiteStats) for(spec in suite.specStats)
      arrayAppend(results.specs,{name=spec.name,status=spec.status,message=spec.failMessage,detail=spec.failDetail,
        origin=isArray(spec.failOrigin) AND arrayLen(spec.failOrigin) ? spec.failOrigin[1] : {}});
    afterCount=queryExecute("SELECT COUNT(*) n FROM users WHERE email LIKE 'codex-trip-preview-%'",{},{datasource="fpw"}).n[1];
    result={"SUCCESS"=val(results.totalSpecs) GT 0 AND val(results.totalFail) EQ 0 AND val(results.totalError) EQ 0 AND beforeCount EQ afterCount,
      "RESULTS"=results,"CLEANUP"={"SUCCESS"=beforeCount EQ afterCount,"beforeUsers"=beforeCount,"afterUsers"=afterCount}};
  } else if(action EQ "setup") {
    transaction { fixture=fixtureService.createFixture(val(url.withDueTrip) EQ 1,val(url.activeScheduled) EQ 1); }
    lock scope="application" type="exclusive" timeout="5" { application.fpwTripPreviewFixtures[fixture.fixture]=fixture; }
    structAppend(result,fixture);
  } else if(listFindNoCase("status,snapshot,login,verifyHttp,cleanup",action)) {
    token=lcase(trim(url.fixture));
    if(!reFind("^[a-f0-9]{32}$",token)) throw(type="FPW.PreviewFixture.Token",message="A fixture token is required.");
    lock scope="application" type="readonly" timeout="5" {
      if(!structKeyExists(application.fpwTripPreviewFixtures,token)) throw(type="FPW.PreviewFixture.NotFound",message="Fixture not found.");
      fixture=duplicate(application.fpwTripPreviewFixtures[token]);
    }
    if(action EQ "status") structAppend(result,fixture);
    else if(action EQ "snapshot") result["snapshot"]=fixtureService.fixtureSnapshot(fixture);
    else if(action EQ "verifyHttp") {
      member=lcase(trim(url.member));
      if(!listFindNoCase("owner,other",member)) throw(type="FPW.PreviewFixture.Member",message="Member must be owner or other.");
      beforeSnapshot=fixtureService.fixtureSnapshot(fixture);
      cfhttp(url="http://127.0.0.1:8500/fpw/tests/trip-preview-runner.cfm?confirm=RUN_TRIP_PREVIEW_TESTS&action=login&fixture="&token&"&member="&member,
        method="get",result="loginHttp",redirect=false,timeout=30) {}
      if(!isJSON(loginHttp.fileContent) OR !deserializeJSON(loginHttp.fileContent).SUCCESS)
        throw(type="FPW.PreviewFixture.HttpLogin",message="Local HTTP fixture login failed.");
      cookies=reMatchNoCase("(?:CFID|CFTOKEN|JSESSIONID)=[A-Za-z0-9._-]+",serializeJSON(loginHttp.responseHeader));
      if(!arrayLen(cookies)) throw(type="FPW.PreviewFixture.HttpCookie",message="Local HTTP login returned no session cookie.");
      requestCases=[];
      for(view in ["active-cruise","follow","active-cruise","follow"])
        arrayAppend(requestCases,{view=view,id=fixture.floatPlanId,expected=member EQ "owner" ? 200 : 404,authenticated=true,extra="",label="saved Draft"});
      if(member EQ "owner") {
        for(view in ["active-cruise","follow"]) {
          for(badId in ["0","01","-1","2147483648",fixture.floatPlanId&"bad"," "&fixture.floatPlanId,fixture.floatPlanId&chr(10),fixture.floatPlanId&chr(9)])
            arrayAppend(requestCases,{view=view,id=badId,expected=404,authenticated=true,extra="",label="malformed identifier"});
          arrayAppend(requestCases,{view=view,id=fixture.floatPlanId,expected=200,authenticated=true,
            extra="&stream_id=999999&slug=other&t=other&userId="&fixture.otherId,label="ignored query overrides"});
          arrayAppend(requestCases,{view=view,id=fixture.floatPlanId,expected=302,authenticated=false,extra="",label="anonymous"});
        }
      }
      result["responses"]=[];
      result["before"]=beforeSnapshot;
      for(requestCase in requestCases) {
        cfhttp(url="http://localhost:8500/fpw/app/"&requestCase.view&".cfm?mode=preview&floatPlanId="&urlEncodedFormat(requestCase.id)&requestCase.extra,
          method="get",result="previewHttp",redirect=false,timeout=30) {
          if(requestCase.authenticated) cfhttpparam(type="header",name="Cookie",value=arrayToList(cookies,"; "));
        }
        body=toString(previewHttp.fileContent);
        safeHeaders={};
        for(headerName in ["Cache-Control","Referrer-Policy","X-Robots-Tag","Location"])
          if(structKeyExists(previewHttp.responseHeader,headerName)) safeHeaders[headerName]=previewHttp.responseHeader[headerName];
        arrayAppend(result.responses,{"view"=requestCase.view,"case"=requestCase.label,"expectedStatus"=requestCase.expected,
          "status"=val(previewHttp.statusCode),"headers"=safeHeaders,"bytes"=len(body),
          "hasPreviewShell"=find("data-trip-preview-view",body) GT 0,
          "hasEmbeddedModel"=find('id="fpwActiveCruiseV2MapPayload"',body) GT 0 OR find('"previewBootstrap"',body) GT 0,
          "hasFixtureName"=find(fixture.floatPlanName,body) GT 0,
          "hasProviderScript"=reFindNoCase("<script[^>]+(plausible[.]io|googletagmanager[.]com|clarity[.]ms)",body) GT 0,
          "hasApplicationError"=find("Application error",body) GT 0,
          "errorSummary"=val(previewHttp.statusCode) EQ 500 ? reMatchNoCase("<h1[^>]*>[^<]*</h1>",body) : []});
      }
      result["after"]=fixtureService.fixtureSnapshot(fixture);
      result["unchanged"]=serializeJSON(result.before) EQ serializeJSON(result.after);
      result.SUCCESS=result.unchanged;
      for(observed in result.responses) {
        result.SUCCESS=result.SUCCESS AND observed.status EQ observed.expectedStatus
          AND !observed.hasApplicationError AND !observed.hasProviderScript
          AND observed.hasFixtureName EQ (observed.expectedStatus EQ 200)
          AND structKeyExists(observed.headers,"Cache-Control") AND isSimpleValue(observed.headers["Cache-Control"]) AND observed.headers["Cache-Control"] EQ "no-store"
          AND structKeyExists(observed.headers,"Referrer-Policy") AND isSimpleValue(observed.headers["Referrer-Policy"]) AND observed.headers["Referrer-Policy"] EQ "no-referrer"
          AND structKeyExists(observed.headers,"X-Robots-Tag") AND isSimpleValue(observed.headers["X-Robots-Tag"]) AND observed.headers["X-Robots-Tag"] EQ "noindex, nofollow";
        if(observed.expectedStatus EQ 200) result.SUCCESS=result.SUCCESS AND observed.hasPreviewShell AND observed.hasEmbeddedModel;
        if(observed.expectedStatus EQ 302) result.SUCCESS=result.SUCCESS AND structKeyExists(observed.headers,"Location")
          AND find("/index.cfm?notice=member-required",observed.headers.Location) GT 0;
      }
      if(val(url.operations) EQ 1 AND member EQ "owner") {
        operationBefore=fixtureService.fixtureSnapshot(fixture);
        result["operations"]=[];
        for(operation in ["checkin","completeleg","startnextleg","savecaptainlogentry","adddelay","cleardelay","updatedailystart","updateactivepace","getactivecruiseweather"]) {
          component=operation EQ "getactivecruiseweather" ? "voyage" : "floatplan";
          cfhttp(url="http://localhost:8500/fpw/api/v1/"&component&".cfc?method=handle&returnFormat=json&action="&operation,
            method="post",result="operationHttp",redirect=false,timeout=30) {
            cfhttpparam(type="header",name="Cookie",value=arrayToList(cookies,"; "));
            cfhttpparam(type="header",name="Content-Type",value="application/json");
            cfhttpparam(type="body",value=serializeJSON({floatPlanId=fixture.floatPlanId,status="Underway",expectedLegOrder=1,
              note="Preview rejection test",noteText="Preview rejection test",minutes=10,delayMinutes=10,
              dailyStartLocalTime="08:00",pace="normal",point="start",routeLegOrder=1}));
          }
          operationResponse=isJSON(operationHttp.fileContent) ? deserializeJSON(operationHttp.fileContent) : {};
          denied=structKeyExists(operationResponse,"SUCCESS") AND !operationResponse.SUCCESS
            AND structKeyExists(operationResponse,"errorCode") AND operationResponse.errorCode EQ "TRIP_ACCESS_RECORD_MISSING";
          arrayAppend(result.operations,{"action"=operation,"denied"=denied,"response"=operationResponse});
          result.SUCCESS=result.SUCCESS AND denied;
        }
        operationAfter=fixtureService.fixtureSnapshot(fixture);
        result["operationsUnchanged"]=serializeJSON(operationBefore.operational) EQ serializeJSON(operationAfter.operational)
          AND serializeJSON(operationBefore.generatedFiles) EQ serializeJSON(operationAfter.generatedFiles);
        result.SUCCESS=result.SUCCESS AND result.operationsUnchanged;
      }
    }
    else if(action EQ "login") {
      member=lcase(trim(url.member));
      if(!listFindNoCase("owner,other",member)) throw(type="FPW.PreviewFixture.Member",message="Member must be owner or other.");
      userId=fixture[member&"Id"];
      userRows=queryExecute("SELECT userId,fName,lName,email,mobilePhone,lastLogin FROM users WHERE userId=:u AND email=:e",
        {u={value=userId,cfsqltype="cf_sql_integer"},e={value=fixture[member&"Email"],cfsqltype="cf_sql_varchar"}},{datasource="fpw"});
      if(userRows.recordCount NEQ 1) throw(type="FPW.PreviewFixture.Identity",message="Fixture member identity mismatch.");
      lock scope="session" type="exclusive" timeout="5" {
        session.user={id=userId,userId=userId,email=userRows.email[1],firstName=userRows.fName[1],lastName=userRows.lName[1],
          mobilePhone=userRows.mobilePhone[1],lastLogin=userRows.lastLogin[1]};
      }
    } else {
      transaction { fixtureService.cleanupFixture(fixture); }
      lock scope="application" type="exclusive" timeout="5" { structDelete(application.fpwTripPreviewFixtures,token); }
      lock scope="session" type="exclusive" timeout="5" {
        if(structKeyExists(session,"user") AND isStruct(session.user) AND structKeyExists(session.user,"userId")
          AND listFind(fixture.ownerId&","&fixture.otherId,session.user.userId)) structDelete(session,"user");
      }
    }
  } else throw(type="FPW.PreviewFixture.Action",message="Unknown local test action.");
</cfscript>
<cfheader statuscode="#result.SUCCESS ? 200 : 500#">
<cfcontent type="application/json; charset=utf-8" reset="true"><cfoutput>#serializeJSON(result)#</cfoutput>
<cfcatch type="any">
  <cfheader statuscode="500"><cfcontent type="application/json; charset=utf-8" reset="true">
  <cfoutput>#serializeJSON({"SUCCESS"=false,"ERROR"="TRIP_PREVIEW_RUNNER_EXCEPTION","MESSAGE"=cfcatch.message,"DETAIL"=cfcatch.detail,"TYPE"=cfcatch.type,"CONTEXT"=cfcatch.tagContext})#</cfoutput>
</cfcatch>
</cftry>
