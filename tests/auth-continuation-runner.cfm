<cfsetting showdebugoutput="false" enablecfoutputonly="true" requesttimeout="120">
<cfparam name="url.confirm" default="">
<cfif cgi.server_name NEQ "localhost" OR val(cgi.server_port) NEQ 8500 OR url.confirm NEQ "RUN_AUTH_CONTINUATION_TESTS">
  <cfheader statuscode="404"><cfcontent type="application/json" reset="true"><cfoutput>{"SUCCESS":false}</cfoutput><cfabort>
</cfif>
<cftry>
  <cfset adminMetadata=getComponentMetadata("fpw.api.v1.adminUsers")>
  <cfset result=new testbox.system.TestBox(bundles="fpw.tests.specs.AuthContinuationSpec,fpw.tests.specs.InactiveMemberRecoveryActionPathSpec").runRaw().getMemento()>
  <cfset ok=result.totalFail EQ 0 AND result.totalError EQ 0 AND result.totalSpecs GT 0>
  <cfheader statuscode="#ok ? 200 : 500#"><cfcontent type="application/json; charset=utf-8" reset="true">
  <cfoutput>#serializeJSON({SUCCESS=ok,RESULTS=result})#</cfoutput>
  <cfcatch type="any">
    <cfheader statuscode="500"><cfcontent type="application/json; charset=utf-8" reset="true">
    <cfoutput>#serializeJSON({SUCCESS=false,ERROR=cfcatch.message,FILE=cfcatch.tagContext[1].template,LINE=cfcatch.tagContext[1].line})#</cfoutput>
  </cfcatch>
</cftry>
