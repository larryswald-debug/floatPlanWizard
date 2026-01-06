<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Admin Login - Float Plan Wizard</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">

    <cfinclude template="../includes/header_styles.cfm">

    <style>
        body {
            min-height: 100vh;
        }
        .login-wrapper {
            min-height: 100vh;
        }
        .login-card {
            border-radius: 16px;
        }
    </style>
</head>
<body class="bg-light d-flex align-items-center justify-content-center">

<cfparam name="variables.loginError" default="">

<cfif structKeyExists(form, "adminUser") AND structKeyExists(form, "adminPass")>
    <cfset userValue = trim(form.adminUser)>
    <cfset passValue = trim(form.adminPass)>
    <cfif len(userValue) AND len(passValue)>
        <cfset session.adminAuthenticated = true>
        <cfset session.adminUser = userValue>
        <cflocation url="/fpw/admin/index.cfm" addToken="false">
    <cfelse>
        <cfset variables.loginError = "Enter any username and password to continue.">
    </cfif>
</cfif>

<div class="container login-wrapper">
    <div class="row justify-content-center">
        <div class="col-12 col-sm-10 col-md-6 col-lg-4">
            <div class="card shadow-sm login-card">
                <div class="card-body p-4">
                    <h1 class="h4 mb-2 text-center">Admin Access</h1>
                    <p class="text-muted small text-center mb-3">
                        Placeholder login. Any username and password will allow access.
                    </p>

                    <cfif len(variables.loginError)>
                        <div class="alert alert-danger" role="alert">
                            <cfoutput>#encodeForHTML(variables.loginError)#</cfoutput>
                        </div>
                    </cfif>

                    <form method="post" novalidate>
                        <div class="mb-3">
                            <label for="adminUser" class="form-label">Username</label>
                            <input
                                type="text"
                                class="form-control"
                                id="adminUser"
                                name="adminUser"
                                required
                                autocomplete="username"
                            >
                        </div>

                        <div class="mb-3">
                            <label for="adminPass" class="form-label">Password</label>
                            <input
                                type="password"
                                class="form-control"
                                id="adminPass"
                                name="adminPass"
                                required
                                autocomplete="current-password"
                            >
                        </div>

                        <button type="submit" class="btn btn-primary w-100">
                            Sign In
                        </button>
                    </form>
                </div>
            </div>

            <p class="text-center text-muted small mt-3">
                &copy; <cfoutput>#dateFormat(now(), "yyyy")#</cfoutput> Float Plan Wizard
            </p>
        </div>
    </div>
</div>

<cfinclude template="../includes/footer_scripts.cfm">
</body>
</html>
