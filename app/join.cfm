<cfsetting enablecfoutputonly="false" showdebugoutput="false">
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Create FloatPlan Wizard Account</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">

    <cfinclude template="../includes/header_styles.cfm">
    <link rel="stylesheet" href="<cfoutput>#request.fpwBase#</cfoutput>/assets/css/auth-pages.css?v=1">
</head>
<body class="auth-page-body bg-light d-flex align-items-center justify-content-center">

<div class="container fpw-layout-rail join-wrapper">
    <div class="row justify-content-center">
        <div class="col-12 col-sm-10 col-md-7 col-lg-6">
            <div class="card shadow-sm">
                <div class="card-body p-4">
                    <h1 class="h4 mb-2 text-center">Create your Free FloatPlan Wizard account</h1>
                    <p class="text-muted small text-center mb-3">
                        You can activate the Free 1 month Premium trial after signup. <br>No credit card is required for the free trial.
                    </p>

                    <div id="joinAlert" class="alert d-none" role="alert"></div>

                    <form id="joinForm" novalidate>
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
                        <div class="row g-3">
                            <div class="col-md-6">
                                <label for="firstName" class="form-label">First Name</label>
                                <input
                                    type="text"
                                    class="form-control"
                                    id="firstName"
                                    name="firstName"
                                    required
                                    autocomplete="given-name"
                                >
                            </div>
                            <div class="col-md-6">
                                <label for="lastName" class="form-label">Last Name</label>
                                <input
                                    type="text"
                                    class="form-control"
                                    id="lastName"
                                    name="lastName"
                                    required
                                    autocomplete="family-name"
                                >
                            </div>
                            <div class="col-12">
                                <label for="email" class="form-label">Email</label>
                                <input
                                    type="email"
                                    class="form-control"
                                    id="email"
                                    name="email"
                                    required
                                    autocomplete="email"
                                >
                            </div>
                            <div class="col-md-6">
                                <label for="password" class="form-label">Password</label>
                                <input
                                    type="password"
                                    class="form-control"
                                    id="password"
                                    name="password"
                                    required
                                    minlength="8"
                                    autocomplete="new-password"
                                >
                            </div>
                            <div class="col-md-6">
                                <label for="confirmPassword" class="form-label">Confirm Password</label>
                                <input
                                    type="password"
                                    class="form-control"
                                    id="confirmPassword"
                                    name="confirmPassword"
                                    required
                                    minlength="8"
                                    autocomplete="new-password"
                                >
                            </div>
                            <div class="col-12">
                                <label for="address" class="form-label">Address (optional)</label>
                                <input
                                    type="text"
                                    class="form-control"
                                    id="address"
                                    name="address"
                                    autocomplete="street-address"
                                >
                            </div>
                            <div class="col-md-6">
                                <label for="city" class="form-label">City (optional)</label>
                                <input
                                    type="text"
                                    class="form-control"
                                    id="city"
                                    name="city"
                                    autocomplete="address-level2"
                                >
                            </div>
                            <div class="col-md-3">
                                <label for="state" class="form-label">State (optional)</label>
                                <input
                                    type="text"
                                    class="form-control"
                                    id="state"
                                    name="state"
                                    maxlength="2"
                                    autocomplete="address-level1"
                                >
                            </div>
                            <div class="col-md-3">
                                <label for="zip" class="form-label">ZIP (optional)</label>
                                <input
                                    type="text"
                                    class="form-control"
                                    id="zip"
                                    name="zip"
                                    autocomplete="postal-code"
                                >
                            </div>
                            <div class="col-12">
                                <label for="phone" class="form-label">Phone (optional)</label>
                                <input
                                    type="tel"
                                    class="form-control"
                                    id="phone"
                                    name="phone"
                                    autocomplete="tel"
                                >
                            </div>
                            <div class="col-12">
                                <div class="form-check">
                                    <input
                                        class="form-check-input"
                                        type="checkbox"
                                        id="termsAccepted"
                                        name="termsAccepted"
                                        value="true"
                                        required
                                    >
                                    <label class="form-check-label small" for="termsAccepted">
                                        I agree to the <a href="../terms_of_service.cfm">Terms of Service</a> and <a href="../privacy_policy.cfm">Privacy Policy</a>.
                                    </label>
                                </div>
                            </div>
                        </div>

                        <button type="submit" class="btn btn-primary w-100 mt-3" id="joinButton">
                            Create Account
                        </button>
                    </form>
                </div>
            </div>

            <p class="text-center text-muted small mt-3">
                <cfoutput>&copy; #dateFormat(now(), "yyyy")# FloatPlan Wizard</cfoutput>
            </p>
        </div>
    </div>
</div>

<cfinclude template="../includes/footer_scripts.cfm">
<script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/app/auth-utils.js"></script>
<script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/app/join.js?v=3"></script>

</body>
</html>
