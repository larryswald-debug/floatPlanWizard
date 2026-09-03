<cfsetting showdebugoutput="false" enablecfoutputonly="true" requesttimeout="120">
<cfparam name="url.confirm" default="">
<cfparam name="url.action" default="">
<cfparam name="url.run" default="">
<cfset localOnly = listFindNoCase("localhost,127.0.0.1,::1",cgi.server_name) GT 0
  AND reFindNoCase("^(localhost|127\.0\.0\.1|\[::1\])(:8500)?$",cgi.http_host) GT 0 AND val(cgi.server_port) EQ 8500>
<cfif NOT localOnly OR url.confirm NEQ "RUN_COMPLETED_CONTACT_BROWSER_FIXTURE">
  <cfheader statuscode="404"><cfabort>
</cfif>
<cfquery name="qDatabase" datasource="fpw">SELECT DATABASE() AS db</cfquery>
<cfif qDatabase.db[1] NEQ "FPW"><cfheader statuscode="409"><cfabort></cfif>
<cftry>
  <cfscript>
    support = new fpw.tests.support.CompletedContactFixture();
    result = { SUCCESS=false };
    lock name="fpw.completed-contact-browser-fixtures" type="exclusive" timeout="30" {
      if (!structKeyExists(application,"completedContactBrowserFixtures")) application.completedContactBrowserFixtures={};
      if (url.action EQ "setup") {
        fixture=support.create();
        application.completedContactBrowserFixtures[fixture.marker]=fixture;
        result={SUCCESS=true,fixture=fixture};
      } else if (structKeyExists(application.completedContactBrowserFixtures,url.run)) {
        fixture=application.completedContactBrowserFixtures[url.run];
        if (url.action EQ "snapshot") result={SUCCESS=true,snapshot=support.snapshot(fixture)};
        else if (url.action EQ "cleanup") {
          support.cleanup(fixture);
          structDelete(application.completedContactBrowserFixtures,url.run);
          result={SUCCESS=true,CLEANED=true};
        }
      }
    }
  </cfscript>
  <cfheader name="Cache-Control" value="no-store">
  <cfcontent type="application/json; charset=utf-8" reset="true">
  <cfoutput>#serializeJSON(result)#</cfoutput>
  <cfcatch type="any">
    <cfheader statuscode="500"><cfcontent type="application/json; charset=utf-8" reset="true">
    <cfoutput>#serializeJSON({SUCCESS=false,MESSAGE=cfcatch.message,DETAIL=cfcatch.detail})#</cfoutput>
  </cfcatch>
</cftry>
