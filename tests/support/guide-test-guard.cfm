<!--- Include before any test fixture, database operation or output. Never a public authentication entry point. --->
<cfheader name="Cache-Control" value="no-store, private">
<cfheader name="Pragma" value="no-cache">
<cfheader name="X-Robots-Tag" value="noindex, nofollow, noarchive">
<cfscript>
guideTestAccess=new fpw.tests.support.GuideLocalTestGuard().validateRequest(
  structKeyExists(request,"guideTestConfirmation") ? request.guideTestConfirmation : "");
if (!guideTestAccess.ALLOWED) {
  cfheader(statuscode=guideTestAccess.STATUSCODE);
  cfcontent(type="application/json; charset=utf-8",reset=true);
  writeOutput(serializeJSON({SUCCESS=false,ERROR=guideTestAccess.CODE}));
  abort;
}
</cfscript>

