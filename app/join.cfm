<cfsetting enablecfoutputonly="false" showdebugoutput="false">
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Create FloatPlan Wizard Account</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">

    <cfinclude template="../includes/header_styles.cfm">
    <link rel="stylesheet" href="<cfoutput>#request.fpwBase#</cfoutput>/assets/css/auth-pages.css?v=20260530-signup-no-benefit-line">
</head>
<body class="auth-page-body fpw-signup-page">

<section class="fpw-signup-shell">
    <div class="fpw-signup-card">
        <aside class="fpw-signup-story" aria-label="FloatPlan Wizard account benefits">
            <div class="fpw-signup-story-overlay">
                <a class="fpw-brand fpw-signup-brand" href="<cfoutput>#request.fpwBase#</cfoutput>/" aria-label="FloatPlanWizard home">
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

                <div class="fpw-signup-story-copy">
                    <h1>Plan safer days on the water.</h1>
                    <p>
                        FloatPlan Wizard helps you create and share a clear boating float plan
                        with the people who need to know where you are going and when you'll return.
                    </p>
                </div>

                <div class="fpw-signup-benefits">
                    <div class="fpw-signup-benefit">
                        <span class="fpw-signup-check" aria-hidden="true">✓</span>
                        <div>
                            <strong>Premium Route Builder included</strong>
                            <span>Plan your route with waypoints, legs, fuel and time estimates during your free month of Premium.</span>
                        </div>
                    </div>

                    <div class="fpw-signup-benefit">
                        <span class="fpw-signup-check" aria-hidden="true">✓</span>
                        <div>
                            <strong>No credit card required</strong>
                            <span>New Members get 1 month of Premium Access free</span>
                        </div>
                    </div>

                    <div class="fpw-signup-benefit">
                        <span class="fpw-signup-check" aria-hidden="true">✓</span>
                        <div>
                            <strong>Mobile-friendly</strong>
                            <span>Works on your phone — no app required</span>
                        </div>
                    </div>



                    <div class="fpw-signup-benefit">
                        <span class="fpw-signup-check" aria-hidden="true">✓</span>
                        <div>
                            <strong>Share the plan</strong>
                            <span>Let family and friends know where you are</span>
                        </div>
                    </div>

                    <div class="fpw-signup-benefit">
                        <span class="fpw-signup-check" aria-hidden="true">✓</span>
                        <div>
                            <strong>Built for boaters</strong>
                            <span>Designed by boaters, for boaters</span>
                        </div>
                    </div>

                </div>
            </div>
        </aside>

        <main class="fpw-signup-form-panel">
            <div class="fpw-signup-form-header">
                <div class="fpw-signup-user-icon" aria-hidden="true">👤</div>
                <div>
                    <h2>Get your Free Month of Premium Access</h2>
                    <p>
                        You're free month gives you access to all custom route tools, Active Cruise pages and a Follow page for frends and family to track your trip.<p>After 1 month your membership will automatically convert to the Basic plan unless you choose to upgrade.
                    </p>
                </div>
            </div>

            <form id="joinForm" class="fpw-signup-form" novalidate>
                <div style="position:absolute; left:-10000px; top:auto; width:1px; height:1px; overflow:hidden;" aria-hidden="true">
                    <label for="website">Website</label>
                    <input
                        type="text"
                        id="website"
                        name="website"
                        tabindex="-1"
                        autocomplete="off"
                    >
                </div>

                <div class="fpw-form-grid fpw-form-grid-2">
                    <div class="fpw-form-row">
                        <label for="firstName">First Name</label>
                        <div class="fpw-input-wrap">
                            <span class="fpw-input-icon" aria-hidden="true">👤</span>
                            <input
                                type="text"
                                id="firstName"
                                name="firstName"
                                autocomplete="given-name"
                                placeholder="First name"
                                required
                            >
                        </div>
                    </div>

                    <div class="fpw-form-row">
                        <label for="lastName">Last Name</label>
                        <div class="fpw-input-wrap">
                            <span class="fpw-input-icon" aria-hidden="true">👤</span>
                            <input
                                type="text"
                                id="lastName"
                                name="lastName"
                                autocomplete="family-name"
                                placeholder="Last name"
                                required
                            >
                        </div>
                    </div>
                </div>

                <div class="fpw-form-row">
                    <label for="email">Email</label>
                    <div class="fpw-input-wrap">
                        <span class="fpw-input-icon" aria-hidden="true">✉</span>
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

                <div class="fpw-form-grid fpw-form-grid-2">
                    <div class="fpw-form-row">
                        <label for="password">Password</label>
                        <div class="fpw-input-wrap">
                            <span class="fpw-input-icon" aria-hidden="true">🔒</span>
                            <input
                                type="password"
                                id="password"
                                name="password"
                                autocomplete="new-password"
                                placeholder="Create a password"
                                minlength="8"
                                required
                            >
                        </div>
                        <p class="fpw-field-help">
                            Use 8 or more characters with a mix of letters, numbers, and symbols.
                        </p>
                    </div>

                    <div class="fpw-form-row">
                        <label for="confirmPassword">Confirm Password</label>
                        <div class="fpw-input-wrap">
                            <span class="fpw-input-icon" aria-hidden="true">🔒</span>
                            <input
                                type="password"
                                id="confirmPassword"
                                name="confirmPassword"
                                autocomplete="new-password"
                                placeholder="Confirm your password"
                                minlength="8"
                                required
                            >
                        </div>
                    </div>
                </div>

                <div class="fpw-terms-row">
                    <input
                        type="checkbox"
                        id="termsAccepted"
                        name="termsAccepted"
                        value="true"
                        required
                    >
                    <label for="termsAccepted">
                        I agree to the <a href="../terms_of_service.cfm">Terms of Service</a>
                        and <a href="../privacy_policy.cfm">Privacy Policy</a>.
                    </label>
                </div>

                <div class="fpw-privacy-note">
                    <div class="fpw-privacy-icon" aria-hidden="true">🛡</div>
                    <div>
                        <strong>We respect your privacy.</strong>
                        <p>
                            Your information stays with your FPW account and is used only for
                            float plans, monitoring, and account support.
                        </p>
                    </div>
                </div>

                <div id="joinAlert" class="alert d-none fpw-signup-message" role="alert" aria-live="polite"></div>

                <button type="submit" class="fpw-signup-submit" id="joinButton">
                    <span aria-hidden="true">🔒</span>
                    <span class="fpw-submit-label">Start My Free Account</span>
                </button>

                <p class="fpw-login-link">
                    Already have an account?
                    <a href="<cfoutput>#request.fpwBase#</cfoutput>/app/login.cfm">Log in</a>
                </p>
            </form>

            <div class="fpw-signup-trust-strip" aria-label="Account trust information">
                <div>
                    <span aria-hidden="true">🛡</span>
                    <strong>Secure account</strong>
                    <small>Your data is protected</small>
                </div>
                <div>
                    <span aria-hidden="true">🔒</span>
                    <strong>No credit card required</strong>
                    <small>Free trial after signup</small>
                </div>
                <div>
                    <span aria-hidden="true">✓</span>
                    <strong>Cancel anytime</strong>
                    <small>No commitment</small>
                </div>
                <div>
                    <span aria-hidden="true">☸</span>
                    <strong>Mobile-friendly</strong>
                    <small>Works on your phone</small>
                </div>
            </div>
        </main>

        <div class="fpw-signup-disclaimer">
            <span aria-hidden="true">⚠</span>
            <p>
                <strong>FloatPlan Wizard is not an emergency dispatch or rescue service.</strong>
                In an emergency, use VHF Channel 16, DSC distress, 911, EPIRB/PLB,
                or other official emergency channels.
            </p>
        </div>
    </div>
</section>

<cfinclude template="../includes/footer_scripts.cfm">
<script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/app/auth-utils.js"></script>
<script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/app/join.js?v=20260530-signup-trust-2"></script>

</body>
</html>
