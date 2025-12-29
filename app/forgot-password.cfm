<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Forgot Password</title>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <cfinclude template="../includes/header_styles.cfm">
</head>
<body class="bg-light">

<div class="container py-5">
  <div class="row justify-content-center">
    <div class="col-12 col-md-6 col-lg-5">
      <div class="card shadow-sm">
        <div class="card-body">
          <h1 class="h5 mb-2">Forgot your password?</h1>
          <p class="text-muted small mb-3">
            Enter your email and we’ll generate a reset link (dev mode).
          </p>

          <div id="fpAlert" class="alert d-none" role="alert"></div>

          <form id="forgotForm">
            <div class="mb-3">
              <label class="form-label" for="email">Email</label>
              <input class="form-control" id="email" type="email" autocomplete="email" required>
            </div>

            <button class="btn btn-primary w-100" id="sendBtn" type="submit">Send Reset Link</button>
          </form>

          <div class="mt-3 d-flex justify-content-between small">
            <a href="<cfoutput>#request.fpwBase#</cfoutput>/app/login.cfm">Back to Sign In</a>
          </div>

          <!-- DEV reset link area -->
          <div class="mt-3 p-2 border rounded bg-light d-none" id="devLinkWrap">
            <div class="small text-muted mb-1">Dev Reset Link</div>
            <a id="devResetLink" href="#" class="small text-break"></a>
          </div>

        </div>
      </div>
    </div>
  </div>
</div>

<script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/app/forgot-password.js"></script>
</body>
</html>
