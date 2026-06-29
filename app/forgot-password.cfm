<cfprocessingdirective pageencoding="utf-8">
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Reset your password</title>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <cfinclude template="../includes/header_styles.cfm">
  <link rel="stylesheet" href="<cfoutput>#request.fpwBase#</cfoutput>/assets/css/auth-pages.css?v=20260628-public-form-shell">
</head>
<body class="auth-page-body fpw-public-form-page fpw-auth-page">

<section class="fpw-public-form-shell fpw-auth-shell fpw-forgot-shell">
  <div class="fpw-public-form-card fpw-auth-card fpw-forgot-card">
    <aside class="fpw-public-form-brand-panel fpw-auth-story" aria-label="FloatPlanWizard account recovery">
      <div class="fpw-auth-story-overlay">
        <a class="fpw-brand fpw-auth-brand" href="<cfoutput>#request.fpwBase#</cfoutput>/" aria-label="FloatPlanWizard home">
          <span class="fpw-brand__mark" aria-hidden="true">
            <svg class="fpw-helm-icon" viewBox="0 0 64 64" focusable="false">
              <circle cx="32" cy="32" r="17"></circle>
              <circle cx="32" cy="32" r="6"></circle>
              <path d="M32 4v12"></path>
              <path d="M32 48v12"></path>
              <path d="M4 32h12"></path>
              <path d="M48 32h12"></path>
              <path d="M12.2 12.2l8.5 8.5"></path>
              <path d="M43.3 43.3l8.5 8.5"></path>
              <path d="M51.8 12.2l-8.5 8.5"></path>
              <path d="M20.7 43.3l-8.5 8.5"></path>
              <circle cx="32" cy="4" r="2.5"></circle>
              <circle cx="32" cy="60" r="2.5"></circle>
              <circle cx="4" cy="32" r="2.5"></circle>
              <circle cx="60" cy="32" r="2.5"></circle>
            </svg>
          </span>

          <span class="fpw-brand__text">
            <span class="fpw-brand__name">FloatPlanWizard</span>
            <span class="fpw-brand__tagline">Built for serious recreational boaters</span>
          </span>
        </a>

        <div class="fpw-auth-story-copy">
          <h1>Back on course quickly.</h1>
          <p>
            Recover access to your float plans, routes, monitoring tools, and account settings.
          </p>
        </div>

        <div class="fpw-auth-benefits">
          <div class="fpw-auth-benefit">
            <span aria-hidden="true">&check;</span>
            <div>
              <strong>Secure reset link</strong>
              <small>Sent to the email on your FPW account</small>
            </div>
          </div>

          <div class="fpw-auth-benefit">
            <span aria-hidden="true">&check;</span>
            <div>
              <strong>Account access only</strong>
              <small>Password recovery protects your boating information</small>
            </div>
          </div>

          <div class="fpw-auth-benefit">
            <span aria-hidden="true">&check;</span>
            <div>
              <strong>Built for boaters</strong>
              <small>Get back to planning safer days on the water</small>
            </div>
          </div>
        </div>
      </div>
    </aside>

    <main class="fpw-public-form-content-panel fpw-auth-form-panel">
      <div class="fpw-auth-form-header">
        <div class="fpw-auth-user-icon" aria-hidden="true">
          <svg viewBox="0 0 24 24" focusable="false">
            <rect x="5" y="10" width="14" height="10" rx="2"></rect>
            <path d="M8 10V7a4 4 0 0 1 8 0v3"></path>
          </svg>
        </div>
        <div>
          <h2>Reset your password</h2>
          <p>
            Enter your email address and we&rsquo;ll send a secure reset link if an FPW account exists for that address.
          </p>
        </div>
      </div>

      <form id="forgotForm" class="fpw-auth-form fpw-forgot-form" method="post" novalidate>
        <div class="fpw-form-row">
          <label for="email">Email address</label>
          <div class="fpw-input-wrap">
            <span class="fpw-input-icon" aria-hidden="true">@</span>
            <input
              type="email"
              id="email"
              name="email"
              autocomplete="email"
              placeholder="you@example.com"
              required
            >
          </div>
        </div>

        <div id="fpAlert" class="alert d-none fpw-auth-message" role="alert" aria-live="polite"></div>

        <button type="submit" id="sendBtn" class="fpw-auth-submit">
          Send Reset Link
        </button>

        <div class="fpw-auth-link-row">
          <a href="<cfoutput>#request.fpwBase#</cfoutput>/app/login.cfm">Back to Sign In</a>
          <span aria-hidden="true">|</span>
          <a href="<cfoutput>#request.fpwBase#</cfoutput>/app/join.cfm">Create free account</a>
        </div>
      </form>

      <div class="fpw-login-note fpw-forgot-note">
        <strong>Check your inbox.</strong>
        <p>
          For your security, reset links expire after a limited time. If you do not
          receive an email, check your spam folder or try again.
        </p>
      </div>
    </main>

    <div class="fpw-auth-disclaimer">
      <span aria-hidden="true">!</span>
      <p>
        <strong>FloatPlan Wizard is not an emergency dispatch or rescue service.</strong>
        In an emergency, use VHF Channel 16, DSC distress, 911, EPIRB/PLB,
        or other official emergency channels.
      </p>
    </div>
  </div>
</section>

<script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/app/auth-utils.js"></script>
<script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/app/forgot-password.js?v=20260530-password-reset-launch"></script>
</body>
</html>
