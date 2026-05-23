<cfinclude template="../includes/fpw_base_path.cfm">
<cfscript>
startTrialUserId = 0;
if (structKeyExists(session, "user") AND isStruct(session.user)) {
  if (structKeyExists(session.user, "userId") AND isNumeric(session.user.userId)) {
    startTrialUserId = val(session.user.userId);
  } else if (structKeyExists(session.user, "id") AND isNumeric(session.user.id)) {
    startTrialUserId = val(session.user.id);
  } else if (structKeyExists(session.user, "USERID") AND isNumeric(session.user.USERID)) {
    startTrialUserId = val(session.user.USERID);
  }
}

if (startTrialUserId LTE 0) {
  location(url = request.fpwBase & "/app/join.cfm?offer=launch_trial", addToken = false);
}
</cfscript>
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Start Premium Free</title>
  <meta name="viewport" content="width=device-width, initial-scale=1">

  <cfinclude template="../includes/header_styles.cfm">
  <link rel="stylesheet" href="<cfoutput>#request.fpwBase#</cfoutput>/assets/css/dashboard-console.css?v=2">
  <link rel="stylesheet" href="<cfoutput>#request.fpwBase#</cfoutput>/assets/css/account.css?v=20260521-site-rail">
</head>

<body class="dashboard-body account-body">

<cfinclude template="../includes/top_nav.cfm">

<main class="account-main fpw-layout-rail pb-5">
  <div class="row justify-content-center">
    <div class="col-12 col-lg-7 col-xl-6">
      <div class="card shadow-sm" id="startTrialCard">
        <div class="card-body p-4">
          <p class="small text-muted mb-2">Premium launch trial</p>
          <h1 class="h3 mb-3">Start Premium Free</h1>
          <p class="text-muted mb-4">
            Activate your Memorial Day Premium trial. No credit card is required to start, and your trial ends automatically unless you add billing before it expires.
          </p>

          <div class="small text-muted mb-4">
            <div class="mb-2">No credit card required</div>
            <div class="mb-2">One free trial per account</div>
            <div>Premium access begins only after Stripe confirms the trial.</div>
          </div>

          <div class="d-flex flex-wrap gap-2 align-items-center">
            <button class="btn btn-primary" type="button" id="activateLaunchTrialBtn" disabled>Activate Free Trial</button>
            <a class="btn btn-outline-primary" href="<cfoutput>#request.fpwBase#</cfoutput>/app/account.cfm">Go to Account</a>
          </div>

          <p class="small text-muted mt-3 mb-0" id="startTrialMessage" aria-live="polite">Checking your membership status...</p>
        </div>
      </div>
    </div>
  </div>
</main>

<cfinclude template="../includes/footer_scripts.cfm">
<script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/app/start-trial.js?v=1"></script>

</body>
</html>
