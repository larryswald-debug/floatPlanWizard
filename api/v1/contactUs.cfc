<cfcomponent output="false">

    <cffunction name="handle" access="remote" returntype="void" output="true">
        <cfargument name="firstName" type="any" required="false">
        <cfargument name="lastName" type="any" required="false">
        <cfargument name="email" type="any" required="false">
        <cfargument name="description" type="any" required="false">
        <cfargument name="website" type="any" required="false">
        <cfargument name="submit" type="any" required="false">
        <cfargument name="subject" type="any" required="false">
        <cfargument name="category" type="any" required="false">
        <cfargument name="mode" type="any" required="false">
        <cfargument name="csrfToken" type="any" required="false">
        <cfsetting enablecfoutputonly="true" showdebugoutput="false">
        <cfcontent type="text/html; charset=utf-8" reset="true">
        <cfheader name="Cache-Control" value="no-store">
        <cfset var basePath = reReplaceNoCase(cgi.script_name, "/api/v1/contactUs[.]cfc$", "")>
        <cfset var contactPageUrl = basePath & "/app/contact.cfm">
        <cfset var ticket = {}>
        <cfset var outcome = "error">
        <cfset local.mode = "contact">
        <cfset var modeLabel = "Contact Us">
        <cfset local.firstName = "">
        <cfset local.lastName = "">
        <cfset local.email = "">
        <cfset local.subject = "">
        <cfset local.category = "">
        <cfset local.description = "">
        <cfset local.website = "">
        <cfset var invalid = false>
        <cfset var limits = {firstName=80,lastName=80,email=254,subject=180,category=60,description=5000,website=200,mode=20}>
        <cfset var values = {}>
        <cfset var field = "">
        <cfset var status = "error">
        <cfset var code = "validation">
        <cfset var isValidEmail = false>
        <cfset var categories = ["Account and Login","Trip Planning","Float Plans","Active Cruise and Monitoring","Companion App","Billing and Subscriptions","Bug Report","Other"]>
        <cfif structKeyExists(form, "mode") AND isSimpleValue(form.mode) AND listFind("contact,support,feedback", trim(toString(form.mode)))>
            <cfset local.mode = trim(toString(form.mode))>
        </cfif>
        <cfset contactPageUrl &= "?mode=" & mode>
        <cfset var limiter = createObject("component", componentPath("AuthRateLimitService")).init("fpw")>
        <cftry>
            <cfset var guard = createObject("component", componentPath("AuthRequestGuardService"))>
            <cfset var permission = guard.validateMutation()>
            <cfif NOT permission.ALLOWED>
                <cfset rejectRequest(permission.STATUSCODE, permission.MESSAGE, contactPageUrl)>
                <cfreturn>
            </cfif>

            <!--- Only POST form values are authoritative; URL/remote argument values cannot override them. --->
            <cfloop collection="#limits#" item="field">
                <cfset values[field] = "">
                <cfif structKeyExists(form, field)>
                    <cfif NOT isSimpleValue(form[field])>
                        <cfset invalid = true>
                    <cfelse>
                        <cfif listFindNoCase("firstName,lastName,email,subject,category", field) AND reFind("[[:cntrl:]]", toString(form[field]))>
                            <cfset invalid = true>
                        </cfif>
                        <cfset values[field] = trim(toString(form[field]))>
                        <cfif len(values[field]) GT limits[field]>
                            <cfset invalid = true>
                        </cfif>
                    </cfif>
                </cfif>
            </cfloop>
            <cfif NOT len(values.mode)><cfset values.mode = "contact"></cfif>
            <cfif listFind("contact,support,feedback", values.mode)>
                <cfset local.mode = values.mode>
            <cfelse>
                <cfset invalid = true>
            </cfif>
            <cfset local.firstName = values.firstName>
            <cfset local.lastName = values.lastName>
            <cfset local.email = values.email>
            <cfset local.subject = values.subject>
            <cfset local.category = values.category>
            <cfset local.description = values.description>
            <cfset local.website = values.website>
            <cfset modeLabel = mode EQ "support" ? "Support Request" : (mode EQ "feedback" ? "Feature Suggestion" : "Contact Us")>
            <cfloop list="firstName,lastName,email,subject,category" index="field">
                <cfif NOT len(values[field]) OR reFind("[[:cntrl:]]", values[field])><cfset invalid = true></cfif>
            </cfloop>
            <cfif NOT len(description) OR reFind("\x00", description) OR NOT arrayFind(categories, category)>
                <cfset invalid = true>
            </cfif>
            <cfset isValidEmail = isValid("email", email) AND NOT reFind("[[:cntrl:][:space:]]", email)>
            <cfif invalid>
                <cfset code = "validation">
            <cfelseif NOT isValidEmail>
                <cfset code = "invalid_email">
            <cfelse>
                <cfset var admission = limiter.admit("support_submit", lCase(email), guard.getClientIp())>
                <cfif NOT admission.ALLOWED>
                    <cfheader name="Retry-After" value="#admission.RETRYAFTER#">
                    <cfset rejectRequest(admission.STATUSCODE, admission.STATUSCODE EQ 429 ? "Please wait before sending another message." : "Support submissions are temporarily unavailable. Please try again shortly.", contactPageUrl)>
                    <cfreturn>
                </cfif>
                <cfset ticket = admission.TICKET>
                <cfif len(website)>
                    <!--- A filled honeypot consumes admission but never sends mail. --->
                    <cfset status = "success">
                    <cfset outcome = "success">
                <cfelse>
                    <cftry>
                        <cfmail
                            to="support@floatplanwizard.com"
                            from="noreply@floatplanwizard.com"
                            replyto="#email#"
                            subject="Float Plan Wizard #modeLabel#: #subject#"
                            spoolenable="false"
                            type="text">
Request Type: #modeLabel#
First Name: #firstName#
Last Name: #lastName#
Email: #email#
Subject: #subject#
Category: #category#

Description:
#description#

Submitted: #dateTimeFormat(now(), "mmmm d, yyyy h:nn tt")#
                        </cfmail>
                        <cfset status = "success">
                        <cfset outcome = "success">
                        <cfcatch type="any">
                            <cfset code = "send_failed">
                        </cfcatch>
                    </cftry>
                </cfif>
            </cfif>
            <cflock scope="session" type="exclusive" timeout="5">
                <cfset session.fpwContactResult = {status=status,code=code,mode=mode}>
            </cflock>
            <cfset var redirectUrl = contactPageUrl & "&status=" & status>
            <cfif status NEQ "success"><cfset redirectUrl &= "&code=" & code></cfif>
            <cfheader statuscode="303">
            <cfheader name="Location" value="#redirectUrl#">
            <cfoutput><!doctype html><html lang="en"><head><meta charset="utf-8"><title>Message submitted</title></head><body><a href="#encodeForHTMLAttribute(redirectUrl)#">Continue to FloatPlanWizard support</a></body></html></cfoutput>
            <cfcatch type="any">
                <cfset rejectRequest(503, "Support submissions are temporarily unavailable. Please try again shortly.", contactPageUrl)>
            </cfcatch>
            <cffinally>
                <cfif NOT structIsEmpty(ticket)><cfset limiter.finish(ticket, outcome)></cfif>
            </cffinally>
        </cftry>
    </cffunction>

    <cffunction name="rejectRequest" access="private" returntype="void" output="true">
        <cfargument name="statusCode" type="numeric" required="true">
        <cfargument name="message" type="string" required="true">
        <cfargument name="returnUrl" type="string" required="true">
        <cfheader statuscode="#arguments.statusCode#">
        <cfif arguments.statusCode EQ 405><cfheader name="Allow" value="POST"></cfif>
        <cfoutput><!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>FloatPlanWizard Support</title></head><body><main><h1>Message not sent</h1><p role="alert">#encodeForHTML(arguments.message)#</p><a href="#encodeForHTMLAttribute(arguments.returnUrl)#">Return to the support form</a></main></body></html></cfoutput>
    </cffunction>

    <cffunction name="componentPath" access="private" returntype="string" output="false">
        <cfargument name="name" type="string" required="true">
        <cfreturn reReplace(getMetadata(this).name, "[.][^.]+$", "." & arguments.name)>
    </cffunction>
</cfcomponent>
