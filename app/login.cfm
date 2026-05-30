<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Sign in to FloatPlanWizard</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">

    <cfinclude template="../includes/header_styles.cfm">
    <link rel="stylesheet" href="<cfoutput>#request.fpwBase#</cfoutput>/assets/css/auth-pages.css?v=20260530-login-boat-scale-plus-50">

    <cfif structKeyExists(session, "authenticated") AND NOT isLoggedIn()>
        <cfset structClear(session)>
    </cfif>

</head>
<body class="auth-page-body fpw-auth-page">

<section class="fpw-auth-shell fpw-login-shell">
    <div class="fpw-auth-card fpw-login-card">
        <aside class="fpw-auth-story" aria-label="FloatPlanWizard account benefits">
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
                    <h1>Plan safer days on the water.</h1>
                    <p>
                        Create, manage, and monitor boating float plans from your FPW account.
                    </p>
                </div>

                <div class="fpw-auth-benefits">
                    <div class="fpw-auth-benefit">
                        <span aria-hidden="true">&check;</span>
                        <div>
                            <strong>Mobile-friendly</strong>
                            <small>No app required</small>
                        </div>
                    </div>

                    <div class="fpw-auth-benefit">
                        <span aria-hidden="true">&check;</span>
                        <div>
                            <strong>Built for boaters</strong>
                            <small>Designed for serious recreational boating</small>
                        </div>
                    </div>

                    <div class="fpw-auth-benefit">
                        <span aria-hidden="true">&check;</span>
                        <div>
                            <strong>Float plans in one place</strong>
                            <small>Routes, contacts, vessels, and trip tools</small>
                        </div>
                    </div>
                </div>
            </div>
        </aside>

        <main class="fpw-auth-form-panel">
            <div class="fpw-auth-form-header">
                <div class="fpw-auth-user-icon" aria-hidden="true">
                    <svg viewBox="0 0 24 24" focusable="false">
                        <circle cx="12" cy="8" r="4"></circle>
                        <path d="M4 21a8 8 0 0 1 16 0"></path>
                    </svg>
                </div>
                <div>
                    <h2>Sign in to FloatPlanWizard</h2>
                    <p>
                        Access your float plans, routes, monitoring tools, and account settings.
                    </p>
                </div>
            </div>

            <form id="loginForm" class="fpw-auth-form fpw-login-form" novalidate>
                <div class="fpw-form-row">
                    <label for="email">Email address</label>
                    <div class="fpw-input-wrap">
                        <span class="fpw-input-icon" aria-hidden="true">@</span>
                        <input
                            type="email"
                            id="email"
                            name="email"
                            required
                            autocomplete="username"
                            placeholder="you@example.com"
                        >
                    </div>
                </div>

                <div class="fpw-form-row">
                    <label for="password">Password</label>
                    <div class="fpw-input-wrap">
                        <span class="fpw-input-icon" aria-hidden="true">
                            <svg viewBox="0 0 24 24" focusable="false">
                                <rect x="5" y="10" width="14" height="10" rx="2"></rect>
                                <path d="M8 10V7a4 4 0 0 1 8 0v3"></path>
                            </svg>
                        </span>
                        <input
                            type="password"
                            id="password"
                            name="password"
                            required
                            autocomplete="current-password"
                            placeholder="Enter your password"
                        >
                    </div>
                </div>

                <div id="loginAlert" class="alert d-none fpw-auth-message" role="alert" aria-live="polite"></div>

                <button type="submit" class="fpw-auth-submit" id="loginButton">
                    Sign In
                </button>

                <div class="fpw-auth-link-row">
                    <a href="<cfoutput>#request.fpwBase#</cfoutput>/app/forgot-password.cfm">Forgot password?</a>
                    <span aria-hidden="true">|</span>
                    <a href="<cfoutput>#request.fpwBase#</cfoutput>/app/join.cfm">Create free account</a>
                    <span aria-hidden="true">|</span>
                    <a href="<cfoutput>#request.fpwBase#</cfoutput>/app/contact.cfm">Contact Us</a>
                </div>
            </form>

            <div class="fpw-login-note">
                <strong>New to FloatPlanWizard?</strong>
                <p>
                    Create a free account to start a basic float plan. Premium tools are available
                    for advanced cruising and route-based planning.
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

<cfinclude template="../includes/footer_scripts.cfm">
<script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/app/core.js"></script>

</body>
</html>
