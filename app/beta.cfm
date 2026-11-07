<cfsetting showdebugoutput="false">
<cfheader name="Cache-Control" value="no-store">
<cfinclude template="../includes/fpw_base_path.cfm">
<cfscript>
betaAuth=new fpw.api.v1.AdminAuthorizationService();
betaUser=betaAuth.resolveUserId(structKeyExists(session,"user") AND isStruct(session.user) ? session.user : {});
if(betaUser<=0) { location(url=request.fpwBase & "/app/login.cfm",addtoken=false); abort; }
betaService=new fpw.api.v1.BetaProgramService();
betaGuard=new fpw.api.v1.AuthRequestGuardService();
betaMessage="";
if(cgi.request_method=='POST') {
 permission=betaGuard.validateMutation();
 if(!permission.ALLOWED) { cfheader(statuscode=permission.STATUSCODE); writeOutput(encodeForHTML(permission.MESSAGE)); abort; }
 try {
  if(structKeyExists(form,"action") AND form.action=='accept' AND structKeyExists(form,"acceptance") AND form.acceptance=='yes') betaService.accept(betaUser);
  else if(structKeyExists(form,"action") AND form.action=='withdraw') betaService.withdraw(betaUser);
  else throw(type="FPW.Beta.Rejected",message="Confirm your participation before accepting.");
  location(url=request.fpwBase & "/app/beta.cfm",addtoken=false,statuscode=303);
 } catch(FPW.Beta.Rejected rejected) { betaMessage=rejected.message; }
}
betaRow=betaService.getParticipation(betaUser);
betaCsrf=betaGuard.getOrCreateCsrfToken();
</cfscript>
<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Founding Beta | FloatPlanWizard</title><cfinclude template="../includes/header_styles.cfm"></head><body>
<cfinclude template="../includes/top_nav.cfm">
<main class="container py-5"><h1>Founding Beta Program</h1>
<cfoutput><cfif len(betaMessage)><p role="alert">#encodeForHTML(betaMessage)#</p></cfif>
<cfif !betaRow.recordCount><p>You do not have a Founding Beta invitation.</p>
<cfelseif betaRow.status[1]=='INVITED'>
<p>Participation lets FPW associate your existing planning, accepted sharing and explicit error evidence with the beta program. Support messages you choose to send may be retained for administrator review. Feedback is optional. Participation does not change your subscription or grant Premium access.</p>
<p>You may withdraw here. Withdrawal ends future participation; existing evidence is retained under the <a href="#request.fpwBase#/privacy_policy.cfm">privacy policy</a>.</p>
<form method="post"><input type="hidden" name="csrfToken" value="#encodeForHTMLAttribute(betaCsrf)#"><input type="hidden" name="action" value="accept"><label><input type="checkbox" name="acceptance" value="yes" required> I agree to participate in the Founding Beta Program.</label><button class="btn btn-primary" type="submit">Accept invitation</button></form>
<cfelseif betaRow.status[1]=='ENROLLED'><p>You are enrolled. Feedback is optional.</p><p><a href="#request.fpwBase#/app/contact.cfm?mode=support">Send feedback or report a problem</a></p>
<form method="post"><input type="hidden" name="csrfToken" value="#encodeForHTMLAttribute(betaCsrf)#"><button class="btn btn-outline-secondary" name="action" value="withdraw">Withdraw from beta</button></form>
<cfelse><p>You have withdrawn. Your membership access is unchanged.</p></cfif></cfoutput>
</main></body></html>
