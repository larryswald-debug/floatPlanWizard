<cfsetting enablecfoutputonly="false" showdebugoutput="false">
<cfparam name="url.status" default="">
<cfparam name="url.code" default="">

<cfset alertClass = "">
<cfset alertMessage = "">

<cfif url.status EQ "success">
    <cfset alertClass = "alert-success">
    <cfset alertMessage = "Thank you for reaching out. Your message has been sent, and we&rsquo;ll get back to you as soon as we can.">
<cfelseif url.status EQ "error">
    <cfset alertClass = "alert-danger">
    <cfif url.code EQ "send_failed">
        <cfset alertMessage = "We&rsquo;re sorry, but we were unable to send your message at this time. Please try again shortly, or contact us another way if the problem continues.">
    <cfelse>
        <cfset alertMessage = "Please complete all required fields and check that your email address is entered correctly, then try again.">
    </cfif>
</cfif>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Contact FloatPlanWizard</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="description" content="Contact FloatPlanWizard for account help, billing questions, float plan support, route planning feedback, and general boating trip-planning questions.">
    <link rel="canonical" href="https://floatplanwizard.com/app/contact.cfm">
    <meta property="og:type" content="website">
    <meta property="og:site_name" content="FloatPlanWizard">
    <meta property="og:url" content="https://floatplanwizard.com/app/contact.cfm">
    <meta property="og:title" content="Contact FloatPlanWizard">
    <meta property="og:description" content="Contact FloatPlanWizard for account help, billing questions, float plan support, route planning feedback, and general questions.">
    <meta property="og:image" content="https://floatplanwizard.com/assets/images/social/floatplanwizard-social-preview-20260730.png">
    <meta property="og:image:secure_url" content="https://floatplanwizard.com/assets/images/social/floatplanwizard-social-preview-20260730.png">
    <meta property="og:image:type" content="image/png">
    <meta property="og:image:width" content="1200">
    <meta property="og:image:height" content="630">
    <meta property="og:image:alt" content="FloatPlanWizard boating trip planning and monitored float plan preview image">
    <meta name="twitter:card" content="summary_large_image">
    <meta name="twitter:title" content="Contact FloatPlanWizard">
    <meta name="twitter:description" content="Contact FloatPlanWizard for account help, billing questions, float plan support, route planning feedback, and general questions.">
    <meta name="twitter:image" content="https://floatplanwizard.com/assets/images/social/floatplanwizard-social-preview-20260730.png">
    <meta name="twitter:image:alt" content="FloatPlanWizard boating trip planning and monitored float plan preview image">

    <cfinclude template="../includes/header_styles.cfm">
    <link rel="stylesheet" href="<cfoutput>#request.fpwBase#</cfoutput>/assets/css/auth-pages.css?v=20260628-public-form-shell">
</head>
<body class="auth-page-body fpw-public-form-page fpw-contact-page">

<section class="fpw-public-form-shell fpw-contact-shell">
    <div class="fpw-public-form-card fpw-contact-card">
        <aside class="fpw-public-form-brand-panel fpw-contact-story" aria-label="FloatPlanWizard support information">
            <div class="fpw-contact-story-overlay">
                <a class="fpw-brand fpw-contact-brand" href="<cfoutput>#request.fpwBase#</cfoutput>/" aria-label="FloatPlanWizard home">
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

                <div class="fpw-contact-story-copy">
                    <h1>Boating support, not emergency dispatch.</h1>
                    <p>
                        Use this form for account help, float plan questions, Premium support,
                        and launch feedback.
                    </p>
                </div>

                <div class="fpw-contact-benefits">
                    <div class="fpw-contact-benefit">
                        <span aria-hidden="true">&check;</span>
                        <div>
                            <strong>Account and login help</strong>
                            <small>Questions about accessing your FPW account</small>
                        </div>
                    </div>

                    <div class="fpw-contact-benefit">
                        <span aria-hidden="true">&check;</span>
                        <div>
                            <strong>Float plan and route questions</strong>
                            <small>Help with planning and using FPW tools</small>
                        </div>
                    </div>

                    <div class="fpw-contact-benefit">
                        <span aria-hidden="true">&check;</span>
                        <div>
                            <strong>Premium or billing questions</strong>
                            <small>Questions about Premium access or subscriptions</small>
                        </div>
                    </div>

                    <div class="fpw-contact-benefit">
                        <span aria-hidden="true">&check;</span>
                        <div>
                            <strong>Launch feedback</strong>
                            <small>Tell us what works and what could be better</small>
                        </div>
                    </div>
                </div>

                <div class="fpw-contact-response-note">
                    <strong>We usually respond within 1&ndash;2 business days.</strong>
                    <span>Do not use this form for emergencies or active distress situations.</span>
                </div>
            </div>
        </aside>

        <main class="fpw-public-form-content-panel fpw-contact-form-panel">
            <div class="fpw-contact-form-header">
                <div class="fpw-contact-icon" aria-hidden="true">
                    <svg viewBox="0 0 24 24" focusable="false">
                        <path d="M4 6h16v12H4z"></path>
                        <path d="m4 7 8 6 8-6"></path>
                    </svg>
                </div>
                <div>
                    <h2>Contact FloatPlanWizard</h2>
                    <p>
                        Have a question about your account, float plans, routes, Premium access, or launch feedback? Send us a message and we&rsquo;ll get back to you.
                    </p>
                </div>
            </div>

            <form id="contactForm" class="fpw-contact-form" method="post" action="<cfoutput>#request.fpwBase#</cfoutput>/api/v1/contactUs.cfc?method=handle" novalidate>
                <div class="fpw-contact-honeypot" aria-hidden="true">
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
                            <span class="fpw-input-icon" aria-hidden="true">
                                <svg viewBox="0 0 24 24" focusable="false">
                                    <path d="M20 21a8 8 0 0 0-16 0"></path>
                                    <circle cx="12" cy="8" r="4"></circle>
                                </svg>
                            </span>
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
                            <span class="fpw-input-icon" aria-hidden="true">
                                <svg viewBox="0 0 24 24" focusable="false">
                                    <path d="M20 21a8 8 0 0 0-16 0"></path>
                                    <circle cx="12" cy="8" r="4"></circle>
                                </svg>
                            </span>
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

                <div class="fpw-form-row">
                    <label for="description">Message</label>
                    <div class="fpw-input-wrap fpw-textarea-wrap">
                        <textarea
                            id="description"
                            name="description"
                            rows="7"
                            placeholder="How can we help?"
                            required
                        ></textarea>
                    </div>
                </div>

                <cfif len(alertMessage)>
                    <cfoutput><div id="contactAlert" class="alert #alertClass# fpw-contact-message" role="alert" aria-live="polite">#alertMessage#</div></cfoutput>
                <cfelse>
                    <div id="contactAlert" class="fpw-contact-message" aria-live="polite"></div>
                </cfif>

                <button type="submit" id="contactButton" class="fpw-contact-submit">Send Message</button>

                <p class="fpw-contact-safe-note">
                    Please do not include passwords, payment details, or emergency medical information.
                </p>
            </form>
        </main>

        <div class="fpw-contact-disclaimer">
            <span aria-hidden="true">!</span>
            <p>
                <strong>FloatPlan Wizard is not an emergency dispatch or rescue service.</strong>
                In an emergency, use VHF Channel 16, DSC distress, 911, EPIRB/PLB,
                or other official emergency channels.
            </p>
        </div>
    </div>

    <p class="fpw-contact-footer">
        <cfoutput>&copy; #dateFormat(now(), "yyyy")# FloatPlanWizard</cfoutput>
    </p>
</section>

<cfinclude template="../includes/footer_scripts.cfm">

</body>
</html>
