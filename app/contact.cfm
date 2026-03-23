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
    <title>Contact Us</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">

    <cfinclude template="../includes/header_styles.cfm">
    <link rel="stylesheet" href="<cfoutput>#request.fpwBase#</cfoutput>/assets/css/auth-pages.css?v=1">
</head>
<body class="auth-page-body bg-light d-flex align-items-center justify-content-center">

<div class="container join-wrapper">
    <div class="row justify-content-center">
        <div class="col-12 col-sm-10 col-md-7 col-lg-6">
            <div class="card shadow-sm">
                <div class="card-body p-4">
                    <h1 class="h4 mb-3 text-center">Contact Us</h1>

                    <cfif len(alertMessage)>
                        <cfoutput><div class="alert #alertClass#" role="alert">#alertMessage#</div></cfoutput>
                    </cfif>

	                    <form method="post" action="<cfoutput>#request.fpwBase#</cfoutput>/api/v1/contactUs.cfc?method=handle" novalidate>
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
                            <div class="col-12">
                                <label for="description" class="form-label">Description</label>
                                <textarea
                                    class="form-control"
                                    id="description"
                                    name="description"
                                    rows="5"
                                    required
                                ></textarea>
                            </div>
                        </div>

                        <button type="submit" class="btn btn-primary w-100 mt-3">Send Message</button>
                    </form>
                </div>
            </div>

            <p class="text-center text-muted small mt-3">
                <cfoutput>&copy; #dateFormat(now(), "yyyy")# Mobile App Example</cfoutput>
            </p>
        </div>
    </div>
</div>

<cfinclude template="../includes/footer_scripts.cfm">

</body>
</html>
