<cfsetting showdebugoutput="false" enablecfoutputonly="true" requesttimeout="30">
<cfcontent type="application/json; charset=utf-8" reset="true">
<cfheader name="Cache-Control" value="no-store">
<cfscript>
localOnly=listFindNoCase("localhost,127.0.0.1,::1",cgi.server_name) GT 0
  AND reFindNoCase("^(localhost|127\.0\.0\.1|\[::1\])(:8500)?$",cgi.http_host) GT 0 AND val(cgi.server_port) EQ 8500;
if (!localOnly OR (url.confirm ?: "") NEQ "READ_AUTH_MAIL_SAFETY") {
  cfheader(statuscode=404);writeOutput(serializeJSON({SUCCESS=false,ERROR="LOCAL_CONFIRMATION_REQUIRED"}));abort;
}
try {
  // Only allow-listed local host/port metadata is returned; never serialize configuration values.
  service=createObject("java","coldfusion.server.ServiceFactory").getMailSpoolService();
  configuredServer=trim(toString(service.getServer()));
  configuredPort=val(service.getPort());
  localServer=listFindNoCase("host.docker.internal,mailhog,cfdev-mailhog,localhost,127.0.0.1",configuredServer) GT 0;
  sameAdminServer=compareNoCase(trim(toString(service.getServerFromAdministrator())),configuredServer) EQ 0;
  bannerLocal=false;
  if (localServer AND configuredPort EQ 1025) {
    socket=createObject("java","java.net.Socket").init(configuredServer,javaCast("int",configuredPort));
    try {
      socket.setSoTimeout(javaCast("int",3000));
      reader=createObject("java","java.io.BufferedReader").init(createObject("java","java.io.InputStreamReader").init(socket.getInputStream()));
      bannerLocal=findNoCase("MailHog",reader.readLine()) GT 0;
    } finally {socket.close();}
  }
  writeOutput(serializeJSON({SUCCESS=true,SERVER=localServer ? configuredServer : "[nonlocal server withheld]",
    PORT=configuredPort,LOCAL_SERVER=localServer,MAILHOG_BANNER=bannerLocal,ADMIN_SERVER_MATCH=sameAdminServer,
    SAFE_LOCAL_MAIL=localServer AND configuredPort EQ 1025 AND bannerLocal AND sameAdminServer}));
} catch (any err) {
  cfheader(statuscode=500);writeOutput(serializeJSON({SUCCESS=false,ERROR="MAIL_SETTINGS_PROBE_UNAVAILABLE",TYPE=err.type}));
}
</cfscript>
