<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Mobile App Login</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">

    <cfinclude template="../includes/header_styles.cfm">

    <style>
        body {
            min-height: 100vh;
        }
        .login-wrapper {
            min-height: 100vh;
        }
    </style>

    <cfif structKeyExists(session, "authenticated") AND NOT isLoggedIn()>
        <cfset structClear(session)>
    </cfif>

</head>
<body class="bg-light d-flex align-items-center justify-content-center">

<div class="container login-wrapper">
    <div class="row justify-content-center">
        <div class="col-12 col-sm-10 col-md-6 col-lg-4">
            <div class="card shadow-sm">
                <div class="card-body p-4">
                    <h1 class="h4 mb-3 text-center">Mobile App Login</h1>
                    <p class="text-muted small text-center mb-3">
                        This form logs in via the <code><cfoutput>#request.fpwBase#</cfoutput>/api/v1/auth.cfc?method=handle</code> endpoint.
                    </p>

                    <div id="loginAlert" class="alert d-none" role="alert"></div>

                    <form id="loginForm" novalidate>
                        <div class="mb-3">
                            <label for="email" class="form-label">Email address</label>
                            <input
                                type="email"
                                class="form-control"
                                id="email"
                                name="email"
                                required
                                autocomplete="username"
                            >
                        </div>

                        <div class="mb-3">
                            <label for="password" class="form-label">Password</label>
                            <input
                                type="password"
                                class="form-control"
                                id="password"
                                name="password"
                                required
                                autocomplete="current-password"
                            >
                        </div>

                        <button type="submit" class="btn btn-primary w-100" id="loginButton">
                            Sign In
                        </button>
                    </form>
                </div>
            </div>

            <div class="mt-3 small">
  <a href="<cfoutput>#request.fpwBase#</cfoutput>/app/forgot-password.cfm">Forgot password?</a>
</div>

            <p class="text-center text-muted small mt-3">
                &copy; #dateFormat(now(), "yyyy")# Mobile App Example
            </p>
        </div>
    </div>
</div>

<cfinclude template="../includes/footer_scripts.cfm">
<script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/app/core.js"></script>

</body>
</html>
