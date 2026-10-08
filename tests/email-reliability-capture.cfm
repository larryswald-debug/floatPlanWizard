<cfsetting showdebugoutput="false" enablecfoutputonly="true" requesttimeout="120">
<cfparam name="url.confirm" default="">
<cfparam name="url.environment" default="development">
<cfif url.confirm NEQ "RUN_EMAIL_RELIABILITY_CAPTURE" OR cgi.request_method NEQ "GET"
 OR NOT listFindNoCase("localhost,127.0.0.1,::1",cgi.server_name)
 OR NOT reFindNoCase("^(localhost|127\.0\.0\.1|\[::1\])(:8500)?$",cgi.http_host)
 OR val(cgi.server_port) NEQ 8500
 OR NOT listFindNoCase("production,development",url.environment)>
 <cfheader statuscode="404"><cfabort>
</cfif>
<cftry>
 <cfset capture=new fpw.tests.support.EmailReliabilityCapture().capture(url.environment,url.environment EQ "production" ? "" : "/fpw")>
 <cfcontent type="application/json; charset=utf-8" reset="true"><cfoutput>#serializeJSON(capture)#</cfoutput>
 <cfcatch type="any"><cfheader statuscode="500"><cfcontent type="application/json; charset=utf-8" reset="true"><cfoutput>#serializeJSON({success=false,message=cfcatch.message,detail=cfcatch.detail,where=cfcatch.tagContext})#</cfoutput></cfcatch>
</cftry>
