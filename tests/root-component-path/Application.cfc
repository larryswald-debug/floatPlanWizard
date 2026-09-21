component output="false" {
  // Isolated local regression: resolve the actual application through root aliases.
  variables.repoRoot=getCanonicalPath(getDirectoryFromPath(getCurrentTemplatePath()) & "../../") & "/";
  this.name="FPWRootComponentPathRegression_" & hash(variables.repoRoot);
  this.applicationTimeout=createTimeSpan(0,0,5,0);
  this.sessionManagement=false;
  this.datasource="fpw";
  this.mappings={};
  this.mappings["/"]=variables.repoRoot;
  this.mappings["/api"]=variables.repoRoot & "api/";
  this.mappings["/includes"]=variables.repoRoot & "includes/";
  this.mappings["/testbox"]=variables.repoRoot & "testbox/";

  public boolean function onRequestStart(string targetPage="") output=false {
    var localOnly=listFindNoCase("localhost,127.0.0.1,::1",cgi.server_name) GT 0
      AND reFindNoCase("^(localhost|127\.0\.0\.1|\[::1\])(:8500)?$",cgi.http_host) GT 0
      AND val(cgi.server_port) EQ 8500;
    if (!localOnly) { cfheader(statuscode=404); return false; }
    return true;
  }
}
