<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Reset Password</title>
  <meta name="viewport" content="width=device-width, initial-scale=1">

  <cfinclude template="../includes/header_styles.cfm">
</head>
<body class="bg-light">

<div class="container py-5">
  <div class="row justify-content-center">
    <div class="col-12 col-md-6 col-lg-5">
      <div class="card shadow-sm">
        <div class="card-body">
          <h1 class="h5 mb-2">Set a new password</h1>
          <p class="text-muted small mb-3">
            Enter a new password for your account.
          </p>

          <div id="rpAlert" class="alert d-none" role="alert"></div>

          <form id="resetForm">
            <input type="hidden" id="token" value="<cfoutput>#encodeForHTMLAttribute(url.token ?: "")#</cfoutput>">

            <div class="mb-2">
              <label class="form-label" for="newPassword">New Password</label>
              <input class="form-control" id="newPassword" type="password" required minlength="8" autocomplete="new-password">
            </div>

            <div class="mb-3">
              <label class="form-label" for="confirmPassword">Confirm New Password</label>
              <input class="form-control" id="confirmPassword" type="password" required minlength="8" autocomplete="new-password">
            </div>

            <button class="btn btn-primary w-100" id="resetBtn" type="submit">Update Password</button>
          </form>

          <div class="mt-3 small">
            <a href="<cfoutput>#request.fpwBase#</cfoutput>/index.cfm">Back to Sign In</a>
          </div>

        </div>
      </div>
    </div>
  </div>
</div>

<script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/app/auth-utils.js"></script>
<script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/app/reset-password.js"></script>
</body>
</html>
