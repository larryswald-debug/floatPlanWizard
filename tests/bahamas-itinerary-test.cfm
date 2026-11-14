<cfprocessingdirective pageencoding="utf-8">
<cfsetting showdebugoutput="false" requesttimeout="60">
<cfcontent type="text/html; charset=utf-8">
<cfheader name="Cache-Control" value="private, no-store, no-cache, must-revalidate">
<cfheader name="Pragma" value="no-cache">
<cfheader name="X-Robots-Tag" value="noindex, nofollow, noarchive">
<cfheader name="Referrer-Policy" value="same-origin">
<cfinclude template="../includes/fpw_base_path.cfm">
<cfscript>
// Local acceptance-test entry only. Exclude all tests from deployment.
// Never use the demo fixture branch that replaces session.user.
localGuideUserId=0;
if (structKeyExists(session,"user") AND isStruct(session.user)) {
  if (structKeyExists(session.user,"userId") AND isNumeric(session.user.userId)) localGuideUserId=val(session.user.userId);
  else if (structKeyExists(session.user,"id") AND isNumeric(session.user.id)) localGuideUserId=val(session.user.id);
}
localGuideGuard=new fpw.tests.support.GuideLocalTestGuard();
localGuideAccess=localGuideGuard.validateAccess(
  environment=structKeyExists(application,"env") ? toString(application.env) : "",
  serverName=toString(cgi.server_name),httpHost=toString(cgi.http_host),serverPort=val(cgi.server_port),
  userId=localGuideUserId,confirmation="LOCAL_BAHAMAS_IMPORT",expectedConfirmation="LOCAL_BAHAMAS_IMPORT");
if (localGuideAccess.STATUSCODE EQ 404) {
  cfheader(statuscode=404); writeOutput("Not found."); abort;
}
if (!listFindNoCase("GET,POST",cgi.request_method)) {
  cfheader(statuscode=405); cfheader(name="Allow",value="GET, POST"); writeOutput("Use GET or POST."); abort;
}
localGuideError="";
if (compareNoCase(cgi.request_method,"POST") EQ 0) {
  localGuideMutation=localGuideGuard.validateRequest("LOCAL_BAHAMAS_IMPORT");
  if (!localGuideMutation.ALLOWED) {
    cfheader(statuscode=localGuideMutation.STATUSCODE);
    writeOutput(encodeForHTML(localGuideMutation.CODE & ": Sign in locally and reload the test page before retrying."));
    abort;
  }
  try {
    localGuideCopy=new fpw.tests.support.GuideTripFixtureService().init("fpw").importTrip(localGuideUserId,{
      template_key="fort-lauderdale-bimini",template_version=1,create_another=true,
      import_request_id=structKeyExists(form,"import_request_id") AND isSimpleValue(form.import_request_id) ? toString(form.import_request_id) : ""});
    // Reuse the owned-route continuation so new accounts retain their normal Continue step.
    localGuideContinuation=new fpw.includes.AuthContinuationService();
    localGuideIntent=localGuideContinuation.createIntent("route",{routeId=val(localGuideCopy.user_route_id)});
    localGuideResolved=localGuideContinuation.resolve(localGuideIntent.token,localGuideUserId);
    location(url=localGuideResolved.redirectUrl,addToken=false,statuscode=303);
  } catch (any localGuideFailure) {
    cfheader(statuscode=500);
    localGuideError="The test copy could not be opened. Retry the same form to reuse this request, or reload the page to start a new test copy.";
  }
}
localGuideRequestId=structKeyExists(form,"import_request_id") AND isSimpleValue(form.import_request_id)
  ? toString(form.import_request_id) : lCase(createObject("java","java.util.UUID").randomUUID().toString());
localGuideCsrf=localGuideUserId GT 0 ? new fpw.api.v1.AuthRequestGuardService().init().getOrCreateCsrfToken() : "";
</cfscript>
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex,nofollow,noarchive">
<title>Bahamas itinerary local test | FPW</title>
<style>
body{font:17px/1.55 system-ui,sans-serif;color:#183344;background:#f3f6f8;margin:0;padding:24px}
main{max-width:800px;margin:0 auto;padding:28px;background:#fff;border:1px solid #c8d5dc;border-radius:12px}
h1{font-size:1.8rem;line-height:1.2}h2{font-size:1.3rem}a{color:#075b82}button{font:inherit;background:#075b82;color:white;border:0;border-radius:6px;padding:12px 18px;cursor:pointer}
a:focus-visible,button:focus-visible{outline:3px solid #ad4a00;outline-offset:4px}
.notice{border-left:4px solid #075b82;padding:12px;background:#edf5f8}.error{border-left:4px solid #aa2a20;padding:12px}li{margin-bottom:10px}
@media(max-width:500px){body{padding:12px}main{padding:18px}}
</style>
</head>
<body><main>
<h1>Test the Bahamas itinerary import</h1>
<p class="notice"><strong>Local development only.</strong> The public guide remains an unpublished draft. This page creates a private editable copy in the account you are signed into on localhost.</p>
<cfoutput>
<cfif len(localGuideError)><p class="error" role="alert">#encodeForHTML(localGuideError)#</p></cfif>
<cfif localGuideUserId LTE 0>
  <h2>Sign in first</h2>
  <p><a href="#request.fpwBase#/app/login.cfm" target="_blank" rel="noopener">Sign in to your local FPW account</a> in a new tab. Complete any account Continue step, then return here and <a href="#request.fpwBase#/tests/bahamas-itinerary-test.cfm">refresh this test page</a>.</p>
<cfelse>
  <form method="post" action="#request.fpwBase#/tests/bahamas-itinerary-test.cfm?confirm=LOCAL_BAHAMAS_IMPORT">
    <input type="hidden" name="csrfToken" value="#encodeForHTMLAttribute(localGuideCsrf)#">
    <input type="hidden" name="import_request_id" value="#encodeForHTMLAttribute(localGuideRequestId)#">
    <p>Creates a new copy with two <strong>50.3 NM</strong> estimates, waypoint references, source information and notes, then opens Trip Planner (choose Continue if prompted). Existing copies and their edits are preserved.</p>
    <button type="submit">Create Bahamas test copy</button>
  </form>
</cfif>
<p><a href="#request.fpwBase#/boating-guides/bahamas/itineraries/fort-lauderdale-bimini/">Read the worked itinerary</a> · <a href="#request.fpwBase#/app/dashboard.cfm">Open Dashboard</a></p>
</cfoutput>
<h2>What to test</h2>
<ol>
<li>Confirm the imported outbound and return distances are <strong>50.3 NM each</strong>, totaling <strong>100.6 NM</strong>, and both legs initially require review.</li>
<li>For a repeatable calculation, enter <strong>20 knots</strong> and <strong>18 US gal/hour</strong>, confirm the performance checkbox, and retain the <strong>20% percentage reserve</strong>. With idle consumption at zero, expect about <strong>5 h 02 min</strong>, <strong>90.5 US gal</strong> base fuel and <strong>108.6 US gal</strong> including reserve. These are test assumptions and estimates.</li>
<li>Change the return distance to <strong>55 NM</strong>. Its source/method should clear and its label should become <strong>Member-entered estimate</strong>. Choose <strong>Save planning draft</strong>, then <strong>Reload saved planning draft</strong>. The 55 NM value, blank method and review requirement should remain.</li>
<li>Enter a source or method for the edited leg and use <strong>Confirm or replace this mileage</strong> on each leg. Choose a start date to test <strong>Save trip</strong>. At the same speed/burn, the edited total is <strong>105.3 NM</strong>, about <strong>5 h 16 min</strong> and <strong>113.7 US gal</strong> including reserve.</li>
<li>Use <strong>Print saved planning summary</strong> to check the edited attribution. Reopen the saved trip using <strong>Edit Route</strong> to check persistence. Float Plan creation requires a source/method and current review on every leg, plus the usual account/vessel requirements.</li>
</ol>
<p>Creating or saving this planning copy does not send or activate a Float Plan. Map connections remain schematic; member review does not independently verify navigation.</p>
</main></body>
</html>

