<cfsetting showdebugoutput="false">
<cfheader name="Cache-Control" value="no-store">
<cfinclude template="../includes/fpw_base_path.cfm">
<cfscript>
if(!structKeyExists(request,"fpwAdminAuthorization") OR !request.fpwAdminAuthorization.authorized) { cfheader(statuscode=403); abort; }
betaService=new fpw.api.v1.BetaProgramService();
betaAdmin=request.fpwAdminAuthorization.userId;
betaMessage="";
if(cgi.request_method=='POST') {
 try {
  if(structKeyExists(form,"action") AND form.action=="feedback_status") {
   if(!structKeyExists(form,"feedbackId") OR !reFind("^[1-9][0-9]{0,17}$",form.feedbackId) OR !structKeyExists(form,"status")) throw(type="FPW.Beta.Rejected",message="Select a feedback record and status.");
   new fpw.api.v1.BetaFeedbackService().updateStatus(betaAdmin,val(form.feedbackId),form.status);
   betaMessage="Feedback status updated.";
  } else {
  if(!structKeyExists(form,"userId") OR !reFind("^[1-9][0-9]{0,9}$",form.userId) OR val(form.userId)>2147483647 OR !structKeyExists(form,"source")) throw(type="FPW.Beta.Rejected",message="Enter a valid member ID and source.");
  betaEntitlement=structKeyExists(form,"entitlementId") AND len(trim(form.entitlementId)) ? form.entitlementId : "0";
  if(!reFind("^[0-9]{1,18}$",betaEntitlement)) throw(type="FPW.Beta.Rejected",message="Enter a valid entitlement ID.");
  betaService.inviteMember(betaAdmin,val(form.userId),form.source,val(betaEntitlement));
  betaMessage="Invitation recorded. The member must accept on the beta page. No email or access grant was sent.";
  }
 } catch(FPW.Beta.Rejected rejected) { betaMessage=rejected.message; }
 catch(FPW.BetaFeedback.Validation rejected) { betaMessage=rejected.message; }
}
betaParticipants=betaService.listParticipants(betaAdmin);
betaReport=new fpw.api.v1.BetaReportService().getReport(betaAdmin);
betaMetrics=[{key="enrolled",label="Enrolled testers"},{key="vessels",label="Members with vessels"},{key="routes",label="Members with saved routes"},{key="floatplans",label="Members with float plans"},{key="acceptedShares",label="Members with accepted shares"},{key="activationPercent",label="Observed activation (%)"},{key="unknownMembers",label="Members with missing or unknown evidence"}];
if(structKeyExists(url,"export") AND url.export=="json") {
 cfcontent(type="application/json; charset=utf-8",reset=true);
 cfheader(name="Content-Disposition",value="attachment; filename=founding-beta-report.json");
 writeOutput(serializeJSON(betaReport));abort;
}
betaFeedback=new fpw.api.v1.BetaFeedbackService().getFeedback(betaAdmin);
</cfscript>
<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Founding Beta Administration</title><link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css"></head><body><main class="container py-4">
<cfinclude template="includes/admin_reports_nav.cfm"><h1>Founding Beta</h1>
<cfoutput><cfif len(betaMessage)><p role="status">#encodeForHTML(betaMessage)#</p></cfif>
<p>Record an invitation for an existing member, then direct them to <a href="#request.fpwBase#/app/beta.cfm">the member acceptance page</a>. New recruits must create an account first.</p>
<form method="post" class="row g-2 mb-4"><input type="hidden" name="adminCsrfToken" value="#encodeForHTMLAttribute(request.fpwAdminCsrfToken)#">
<label class="col-md-3">Member ID<input class="form-control" name="userId" type="number" min="1" required></label>
<label class="col-md-3">Recruitment source<select class="form-select" name="source"><option value="existing_member">Existing member</option><option value="mailing_list">Mailing list</option><option value="other">Other</option></select></label>
<label class="col-md-3">Existing promo entitlement ID (optional)<input class="form-control" name="entitlementId" type="number" min="1"></label><div class="col-md-3 align-self-end"><button class="btn btn-primary">Record invitation</button></div></form>
<h2>Activation report</h2><p>Cutoff (UTC): #encodeForHTML(betaReport.cutoffUtc)#. Current enrolled cohort; withdrawn members are excluded. Assets include pre-existing owned records. Accepted sends do not prove inbox delivery.</p><p><a href="?export=json">Export report (JSON, internal IDs only)</a></p>
<dl class="row"><cfloop array="#betaMetrics#" index="metric"><dt class="col-sm-6">#encodeForHTML(metric.label)#</dt><dd class="col-sm-6"><cfif metric.key EQ "activationPercent" AND betaReport.summary.enrolled EQ 0>Not available (no enrolled testers)<cfelse>#numberFormat(betaReport.summary[metric.key],metric.key EQ "activationPercent" ? "0.00" : "0")#</cfif></dd></cfloop></dl>
<ul><cfloop array="#betaReport.limitations#" index="limitation"><li>#encodeForHTML(limitation)#</li></cfloop></ul>
<h2>Participation register</h2><div class="table-responsive"><table class="table table-sm table-bordered"><thead><tr><th>Member ID</th><th>Status</th><th>Source</th><th>Enrolled (UTC)</th><th>Withdrawn (UTC)</th></tr></thead><tbody><cfloop query="betaParticipants"><tr><td>#user_id#</td><td>#encodeForHTML(status)#</td><td>#encodeForHTML(recruitment_source)#</td><td>#encodeForHTML(toString(enrolled_at_utc))#</td><td>#encodeForHTML(toString(withdrawn_at_utc))#</td></tr></cfloop></tbody></table></div></cfoutput>
<h2>Optional feedback</h2><p>Latest 200 submissions. Descriptions are private to authorized administrators and excluded from the report export.</p>
<div class="table-responsive"><table class="table table-sm table-bordered"><thead><tr><th>ID / Member</th><th>Category</th><th>Description</th><th>Submitted (UTC)</th><th>Status</th></tr></thead><tbody>
<cfoutput><cfloop query="betaFeedback"><tr><td>#id# / #user_id#</td><td>#encodeForHTML(category)#</td><td class="text-break">#encodeForHTML(description)#</td><td>#encodeForHTML(toString(submitted_at_utc))#</td><td>
<form method="post"><input type="hidden" name="adminCsrfToken" value="#encodeForHTMLAttribute(request.fpwAdminCsrfToken)#"><input type="hidden" name="action" value="feedback_status"><input type="hidden" name="feedbackId" value="#id#"><select class="form-select form-select-sm" name="status" aria-label="Feedback status"><cfloop list="NEW,REVIEWED,RESOLVED" index="feedbackState"><option value="#feedbackState#"<cfif feedbackState EQ status> selected</cfif>>#feedbackState#</option></cfloop></select><button class="btn btn-sm btn-outline-secondary">Update</button></form>
</td></tr></cfloop></cfoutput></tbody></table></div>
</main></body></html>
