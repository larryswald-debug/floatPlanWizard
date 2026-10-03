<cfsetting showdebugoutput="false">
<cfcontent type="text/html; charset=utf-8">
<cfheader name="Cache-Control" value="no-store">
<cfif NOT structKeyExists(request,"fpwAdminAuthorization") OR NOT isStruct(request.fpwAdminAuthorization)
  OR NOT structKeyExists(request.fpwAdminAuthorization,"authorized") OR NOT request.fpwAdminAuthorization.authorized>
  <cfheader statuscode="403"><cfoutput>Administrative access is required.</cfoutput><cfabort>
</cfif>
<cfinclude template="../includes/fpw_base_path.cfm">
<cfscript>
function recoveryEnrollmentValue(required struct source,required string key) {
  if (!structKeyExists(arguments.source,arguments.key) OR !isSimpleValue(arguments.source[arguments.key])) return "";
  return toString(arguments.source[arguments.key]);
}
pageUrl=request.fpwBase & "/admin/recovery-enrollment.cfm";
csrfToken=structKeyExists(request,"fpwAdminCsrfToken") ? toString(request.fpwAdminCsrfToken) : "";
requestMethod=uCase(toString(cgi.request_method));
submittedIds="";
report={};
pageError="";
service="";
try {
  service=new fpw.api.v1.AdminRecoveryEnrollmentService().init();
  if (requestMethod EQ "POST") {
    allowedFields="action,reviewToken,confirmation,adminCsrfToken,fieldnames";
    for (key in form) {
      if (!listFindNoCase(allowedFields,key)) throw(type="FPW.RecoveryEnrollment.Input",message="INVALID_FIELDS");
    }
    if (compare(recoveryEnrollmentValue(form,"action"),"enroll") NEQ 0) {
      throw(type="FPW.RecoveryEnrollment.Input",message="INVALID_ACTION");
    }
    report=service.enroll(recoveryEnrollmentValue(form,"reviewToken"),recoveryEnrollmentValue(form,"confirmation"));
  } else if (requestMethod EQ "GET" AND len(recoveryEnrollmentValue(url,"action"))) {
    for (key in url) {
      if (!listFindNoCase("action,userIds",key)) throw(type="FPW.RecoveryEnrollment.Input",message="INVALID_FIELDS");
    }
    if (compare(recoveryEnrollmentValue(url,"action"),"preview") NEQ 0) {
      throw(type="FPW.RecoveryEnrollment.Input",message="INVALID_ACTION");
    }
    submittedIds=recoveryEnrollmentValue(url,"userIds");
    report=service.preview(submittedIds);
  }
} catch (FPW.RecoveryEnrollment.Input rejected) {
  pageError="The request contained an unsupported action or field. Submit a new preview using the form below.";
} catch (FPW.RecoveryEnrollment.Authorization denied) {
  pageError="The administrative session, request method, or request token is no longer valid. Sign in again and review the selected members.";
} catch (any unavailable) {
  pageError="The enrollment operation could not be verified. No automatic retry was attempted. Review current enrollment before retrying.";
}
hasReport=isStruct(report) AND structKeyExists(report,"rows");
recoveryTiming={};
try { recoveryTiming=new fpw.includes.InactiveMemberRecoverySettingsService().getSettings(); }
catch(any timingUnavailable) { recoveryTiming={}; }
</cfscript>
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Recovery Enrollment — FloatPlanWizard</title>
  <style>
    body{margin:24px;background:#f7f7f7;color:#172033;font-family:Arial,sans-serif;line-height:1.5}
    main{max-width:1200px;margin:auto;padding:24px;background:#fff;border:1px solid #ddd;border-radius:8px}
    h1{margin-top:0}label{display:block;font-weight:bold}textarea{box-sizing:border-box;width:100%;max-width:720px;padding:10px;font:inherit}
    button{padding:10px 16px;margin-top:10px;border:1px solid #273e5b;border-radius:5px;background:#173b64;color:#fff;font:inherit;cursor:pointer}
    .notice{padding:12px;border:1px solid #b5c7dc;background:#f1f6fc;margin:16px 0}.error{border-color:#d79999;background:#fff1f1}
    .counts{display:flex;gap:16px;flex-wrap:wrap;padding:12px 0}.counts span{white-space:nowrap}.table-wrap{overflow:auto}
    table{width:100%;border-collapse:collapse}th,td{text-align:left;vertical-align:top;padding:8px;border:1px solid #d6dce4}th{background:#f4f6f8}
    .confirmation{margin-top:18px}.confirmation label{font-weight:normal}.muted{color:#465668}.reason-list{overflow-wrap:anywhere}
    @media(max-width:640px){body{margin:8px}main{padding:14px}}
  </style>
</head>
<body>
<cfinclude template="includes/admin_reports_nav.cfm">
<main>
  <h1>Inactive-member recovery enrollment</h1>
  <p>Preview a reviewed list of member IDs, then explicitly enroll the members that qualify. This operation never sends recovery emails or changes a schedule.</p>
  <p class="muted">Each new enrollment starts its own UTC enrollment clock. <cfif structKeyExists(recoveryTiming,"firstDelayHours")><cfoutput>Current First Recovery Delay: #int(recoveryTiming.firstDelayHours)# hours; interval between numbered contacts: #int(recoveryTiming.stageIntervalHours)# hours; attribution window: #int(recoveryTiming.attributionWindowHours)# hours.</cfoutput><cfelse>Timing settings are unavailable; recovery sending remains on hold until settings can be verified.</cfif> Exactly three automated recovery contacts are independent of the member’s current A/B/C/D destination. Enrollment does not establish historical coverage; missing coverage continues to hold recovery messages.</p>
  <cfif len(pageError)><cfoutput><div id="recoveryEnrollmentMessage" class="notice error" role="alert">#encodeForHTML(pageError)#</div></cfoutput></cfif>
  <cfoutput>
  <form id="recoveryEnrollmentPreviewForm" method="get" action="#encodeForHTMLAttribute(pageUrl)#">
    <input type="hidden" name="action" value="preview">
    <label for="recoveryEnrollmentIds">Member IDs to review</label>
    <p class="muted" id="recoveryEnrollmentIdsHelp">Enter 1–100 distinct positive member IDs, separated by commas or whitespace. The operation does not select all members automatically.</p>
    <textarea id="recoveryEnrollmentIds" name="userIds" rows="4" maxlength="2000" required aria-describedby="recoveryEnrollmentIdsHelp">#encodeForHTML(submittedIds)#</textarea><br>
    <button type="submit">Preview selected members</button>
  </form>
  </cfoutput>
  <cfif hasReport>
    <cfoutput>
    <section id="recoveryEnrollmentReport" data-mode="#encodeForHTMLAttribute(report.mode)#" aria-label="Enrollment report">
      <h2><cfif report.mode EQ "preview">Preview<cfelse>Enrollment result</cfif></h2>
      <div id="recoveryEnrollmentMessage" class="notice<cfif NOT report.ok> error</cfif>" role="status">#encodeForHTML(report.message)#</div>
      <div class="counts">
        <span>Scanned: <strong id="recoveryEnrollmentScanned">#report.scanned#</strong></span>
        <span><cfif report.mode EQ "preview">Eligible<cfelse>Reviewed eligible</cfif>: <strong id="recoveryEnrollmentEligible">#report.eligible#</strong></span>
        <span>Already enrolled: <strong id="recoveryEnrollmentAlreadyEnrolled">#report.already_enrolled#</strong></span>
        <span>Newly enrolled: <strong id="recoveryEnrollmentNewlyEnrolled">#report.newly_enrolled#</strong></span>
        <span>Skipped: <strong id="recoveryEnrollmentSkipped">#report.skipped#</strong></span>
        <span>Failures: <strong id="recoveryEnrollmentFailures">#report.failures#</strong></span>
      </div>
      <cfif structCount(report.reasons)>
        <p class="reason-list"><strong>Reasons:</strong>
        <cfloop collection="#report.reasons#" item="reason"> #encodeForHTML(reason)# (#report.reasons[reason]#);</cfloop>
        </p>
      </cfif>
      <cfif report.failures GT 0>
        <p class="muted">For failures with a diagnostic reference, locate that reference in the application log file <code>/logs/fpw_recovery_enrollment.log</code> to investigate the cause.</p>
      </cfif>
      <div class="table-wrap">
        <table><thead><tr><th>Member ID</th><th>Outcome</th><th>Reason</th><th>Enrollment UTC</th><th>Coverage at review</th><th>Diagnostic reference</th></tr></thead>
          <tbody id="recoveryEnrollmentRows">
          <cfloop array="#report.rows#" index="row">
            <tr data-user-id="#row.userId#" data-code="#encodeForHTMLAttribute(row.code)#">
              <td>#row.userId#</td><td>#encodeForHTML(row.code)#</td><td>#encodeForHTML(row.reason)#</td>
              <td>#encodeForHTML(row.enrollmentUtc)#</td><td><cfif row.coverageVerified>Verified<cfelse>Unverified</cfif></td>
              <td>#encodeForHTML(structKeyExists(row,"errorReference") ? row.errorReference : "")#</td>
            </tr>
          </cfloop>
          </tbody>
        </table>
      </div>
      <cfif report.mode EQ "preview" AND report.ok AND report.eligible GT 0 AND len(report.reviewToken)>
        <form id="recoveryEnrollmentCommitForm" class="confirmation" method="post" action="#encodeForHTMLAttribute(pageUrl)#">
          <input type="hidden" name="action" value="enroll">
          <input type="hidden" name="reviewToken" value="#encodeForHTMLAttribute(report.reviewToken)#">
          <input type="hidden" name="adminCsrfToken" value="#encodeForHTMLAttribute(csrfToken)#">
          <p>This review expires at #encodeForHTML(report.reviewExpiresUtc)#. Only the #report.eligible# members marked ENROLLABLE above can be enrolled. Eligibility is checked again before each enrollment.</p>
          <label><input type="checkbox" id="recoveryEnrollmentConfirm" name="confirmation" value="ENROLL REVIEWED MEMBERS" required> I reviewed these member IDs and authorize enrollment of this eligible selection.</label>
          <button id="recoveryEnrollmentCommit" type="submit">Enroll reviewed eligible members</button>
        </form>
      </cfif>
    </section>
    </cfoutput>
  </cfif>
</main>
</body>
</html>
