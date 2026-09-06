<cfsetting showdebugoutput="false" enablecfoutputonly="true" requesttimeout="180">
<cfcontent type="application/json; charset=utf-8" reset="true">
<cfheader name="Cache-Control" value="no-store">
<cfscript>
localOnly=listFindNoCase("localhost,127.0.0.1,::1",cgi.server_name) GT 0
  AND reFindNoCase("^(localhost|127\.0\.0\.1|\[::1\])(:8500)?$",cgi.http_host) GT 0 AND val(cgi.server_port) EQ 8500;
if (!localOnly OR !structKeyExists(url,"confirm") OR url.confirm NEQ "RUN_RECOVERY_READINESS_TESTS") {
  cfheader(statuscode=404); writeOutput(serializeJSON({ok=false,error="LOCAL_CONFIRMATION_REQUIRED"})); abort;
}
try {
  if ((url.mode ?: "") EQ "probe") {
    for (componentName in ["fpw.includes.InactiveMemberRecoveryCoverageService","fpw.api.v1.join","fpw.api.v1.floatplan","fpw.api.v1.BasicReviewSendService"]) getComponentMetadata(componentName);
    // Read only: confirm the configured local SMTP endpoint identifies itself as MailHog.
    socket=createObject("java","java.net.Socket").init("host.docker.internal",javaCast("int",1025));
    try {
      socket.setSoTimeout(javaCast("int",3000));
      reader=createObject("java","java.io.BufferedReader").init(createObject("java","java.io.InputStreamReader").init(socket.getInputStream()));
      banner=reader.readLine();
      mailhog=findNoCase("MailHog",banner) GT 0;
    } finally { socket.close(); }
    settings=new fpw.api.v1.InactiveMemberRecoveryService().getRunnerSettings();
    writeOutput(serializeJSON({ok=true,compiled=true,mailhog=mailhog,liveEnabled=settings.liveEnabled}));
  } else {
    results=new testbox.system.TestBox(bundles="fpw.tests.specs.InactiveMemberRecoveryReadinessSpec").runRaw().getMemento();
    writeOutput(serializeJSON({SUCCESS=results.totalFail EQ 0 AND results.totalError EQ 0,RESULTS=results}));
  }
} catch (any err) {
  cfheader(statuscode=500);writeOutput(serializeJSON({ok=false,type=err.type,message=err.message,detail=err.detail}));
}
</cfscript>
