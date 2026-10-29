<cfsetting showdebugoutput="false" enablecfoutputonly="true" requesttimeout="120">
<cfparam name="url.confirm" default="">
<cfparam name="url.mode" default="tests">
<cfset localHost = reFindNoCase("^(localhost|127\.0\.0\.1|\[::1\])(:8500)?$", cgi.http_host) GT 0>
<cfset localServer = listFindNoCase("localhost,127.0.0.1,::1", cgi.server_name) GT 0>
<cfif NOT localHost OR NOT localServer OR val(cgi.server_port) NEQ 8500 OR url.confirm NEQ "RUN_GREAT_LOOP_REFERENCE_TESTS">
    <cfheader statuscode="404"><cfcontent type="application/json" reset="true">
    <cfoutput>#serializeJSON({SUCCESS=false,ERROR="LOCAL_TEST_CONFIRMATION_REQUIRED"})#</cfoutput><cfabort>
</cfif>
<cfset result = {SUCCESS=false}>
<cftry>
    <cfif url.mode EQ "model">
        <cfset result = {SUCCESS=true,model=new fpw.api.v1.GreatLoopReferenceService().init("fpw").getModel()}>
    <cfelse>
        <cfset runner = new testbox.system.TestBox(bundles="fpw.tests.specs.GreatLoopReferenceServiceSpec")>
        <cfset results = runner.runRaw().getMemento()>
        <cfset result = {SUCCESS=val(results.totalSpecs) GT 0 AND val(results.totalFail) EQ 0 AND val(results.totalError) EQ 0, results=results}>
    </cfif>
    <cfcatch type="any"><cfset result={SUCCESS=false,message=cfcatch.message,detail=cfcatch.detail,type=cfcatch.type}></cfcatch>
</cftry>
<cfif NOT result.SUCCESS><cfheader statuscode="500"></cfif>
<cfcontent type="application/json; charset=utf-8" reset="true">
<cfoutput>#serializeJSON(result)#</cfoutput>
