<cfcomponent output="false">

    <cffunction name="init" access="public" returntype="any" output="false">
        <cfreturn this>
    </cffunction>

    <cffunction name="sendWelcomeMemberEmail" access="public" returntype="struct" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="toEmail" type="string" required="true">
        <cfargument name="firstName" type="string" required="false" default="">
        <cfargument name="dashboardUrl" type="string" required="false" default="">

        <cfset var result = {
            success = false,
            messageType = "WELCOME_MEMBER",
            errorCode = "",
            message = ""
        }>
        <cfset var toAddress = lcase(trim(arguments.toEmail))>
        <cfset var emailMessage = {}>

        <cfif int(arguments.userId) LTE 0>
            <cfset result.errorCode = "INVALID_USER">
            <cfset result.message = "Welcome email user is invalid.">
            <cfreturn result>
        </cfif>

        <cfif NOT isValid("email", toAddress)>
            <cfset result.errorCode = "INVALID_RECIPIENT">
            <cfset result.message = "Welcome email recipient is invalid.">
            <cfreturn result>
        </cfif>

        <cftry>
            <cfset emailMessage = buildWelcomeMemberEmail(
                userId = arguments.userId,
                toEmail = toAddress,
                firstName = arguments.firstName,
                dashboardUrl = arguments.dashboardUrl
            )>
            <cfset sendMultipartEmail(
                toEmail = toAddress,
                subject = emailMessage.subject,
                htmlBody = emailMessage.htmlBody,
                textBody = emailMessage.textBody
            )>

            <cfset result.success = true>
            <cfset result.message = "Welcome email sent.">
            <cfreturn result>

            <cfcatch type="any">
                <cfset logSafeEmailFailure(
                    messageType = "WELCOME_MEMBER",
                    userId = arguments.userId,
                    toEmail = toAddress,
                    exceptionType = (structKeyExists(cfcatch, "type") ? cfcatch.type : "any")
                )>
                <cfset result.errorCode = "SEND_FAILED">
                <cfset result.message = "Welcome email could not be sent.">
                <cfreturn result>
            </cfcatch>
        </cftry>
    </cffunction>

    <cffunction name="sendPasswordResetEmail" access="public" returntype="struct" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="toEmail" type="string" required="true">
        <cfargument name="resetUrl" type="string" required="true">
        <cfargument name="expiresMinutes" type="numeric" required="false" default="60">

        <cfset var result = {
            success = false,
            messageType = "PASSWORD_RESET",
            errorCode = "",
            message = ""
        }>
        <cfset var toAddress = lcase(trim(arguments.toEmail))>
        <cfset var resetUrlValue = trim(arguments.resetUrl)>
        <cfset var emailMessage = {}>

        <cfif int(arguments.userId) LTE 0>
            <cfset result.errorCode = "INVALID_USER">
            <cfset result.message = "Password reset email user is invalid.">
            <cfreturn result>
        </cfif>

        <cfif NOT isValid("email", toAddress)>
            <cfset result.errorCode = "INVALID_RECIPIENT">
            <cfset result.message = "Password reset email recipient is invalid.">
            <cfreturn result>
        </cfif>

        <cfif NOT len(resetUrlValue) OR NOT reFindNoCase("^https?://", resetUrlValue)>
            <cfset result.errorCode = "INVALID_RESET_LINK">
            <cfset result.message = "Password reset URL is invalid.">
            <cfreturn result>
        </cfif>

        <cftry>
            <cfset emailMessage = buildPasswordResetEmail(
                resetUrl = resetUrlValue,
                expiresMinutes = arguments.expiresMinutes
            )>
            <cfset sendMultipartEmail(
                toEmail = toAddress,
                subject = emailMessage.subject,
                htmlBody = emailMessage.htmlBody,
                textBody = emailMessage.textBody
            )>

            <cfset result.success = true>
            <cfset result.message = "Password reset email sent.">
            <cfreturn result>

            <cfcatch type="any">
                <cfset logSafeEmailFailure(
                    messageType = "PASSWORD_RESET",
                    userId = arguments.userId,
                    toEmail = toAddress,
                    exceptionType = (structKeyExists(cfcatch, "type") ? cfcatch.type : "any")
                )>
                <cfset result.errorCode = "SEND_FAILED">
                <cfset result.message = "Password reset email could not be sent.">
                <cfreturn result>
            </cfcatch>
        </cftry>
    </cffunction>

    <cffunction name="sendBasicReviewFloatPlanEmail" access="public" returntype="struct" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="toEmail" type="string" required="true">
        <cfargument name="contactName" type="string" required="true">
        <cfargument name="floatPlanName" type="string" required="true">
        <cfargument name="captainName" type="string" required="true">
        <cfargument name="pdfPath" type="string" required="true">

        <cfset var result = {
            success = false,
            messageType = "BASIC_REVIEW_FLOAT_PLAN",
            errorCode = "",
            message = ""
        }>
        <cfset var toAddress = lcase(trim(arguments.toEmail))>
        <cfset var recipientName = cleanBasicReviewTextValue(arguments.contactName)>
        <cfset var planName = cleanBasicReviewTextValue(arguments.floatPlanName)>
        <cfset var captain = cleanBasicReviewTextValue(arguments.captainName)>
        <cfset var attachmentPath = trim(arguments.pdfPath)>
        <cfset var subject = "">
        <cfset var textBody = "">
        <cfset var htmlContent = "">
        <cfset var htmlBody = "">
        <cfset var complianceFooter = {}>

        <cfif int(arguments.userId) LTE 0>
            <cfset result.errorCode = "INVALID_USER">
            <cfset result.message = "Basic float-plan email member is invalid.">
            <cfreturn result>
        </cfif>
        <cfif NOT isValid("email", toAddress)>
            <cfset result.errorCode = "INVALID_RECIPIENT">
            <cfset result.message = "The selected contact needs a valid email address.">
            <cfreturn result>
        </cfif>
        <cfif NOT len(attachmentPath) OR NOT fileExists(attachmentPath) OR lcase(listLast(attachmentPath, ".")) NEQ "pdf">
            <cfset result.errorCode = "INVALID_PDF_ATTACHMENT">
            <cfset result.message = "The Basic float-plan PDF attachment is unavailable.">
            <cfreturn result>
        </cfif>

        <cfif NOT len(recipientName)>
            <cfset recipientName = "Float plan contact">
        </cfif>
        <cfif NOT len(planName)>
            <cfset planName = "Float Plan">
        </cfif>
        <cfif NOT len(captain)>
            <cfset captain = "FPW member">
        </cfif>

        <cfset subject = "Basic Float Plan: " & planName & " — " & captain>
        <cfset complianceFooter = buildEmailComplianceFooter(footerType = "service")>
        <cfset textBody = arrayToList([
            "Hello " & recipientName & ",",
            "",
            captain & " selected you to receive the attached Basic float plan: " & planName & ".",
            "",
            "This Basic Send includes the completed float-plan PDF and email delivery only.",
            "It does not include Active Cruise, Float Plan Monitoring, private Trip/Follow access, live check-ins, updates, photos, or comments.",
            "",
            "This float plan is precautionary trip information. Nothing in this email indicates that FPW has verified an emergency.",
            "If you believe there may be an emergency, contact the appropriate emergency authority directly. FPW does not independently verify emergencies or dispatch assistance.",
            "",
            "Email delivery is not guaranteed, and FPW does not confirm that a recipient has received or read this message.",
            "Please keep the attached PDF available with the trip information."
        ], chr(10)) & chr(10) & chr(10) & complianceFooter.textBody>

        <cfsavecontent variable="htmlContent"><cfoutput>
<p style="margin:0 0 16px 0;">Hello #encodeForHtml(recipientName)#,</p>
<p style="margin:0 0 16px 0;"><strong>#encodeForHtml(captain)#</strong> selected you to receive the attached Basic float plan: <strong>#encodeForHtml(planName)#</strong>.</p>
<p style="margin:0 0 12px 0;">This Basic Send includes the completed float-plan PDF and email delivery only.</p>
<p style="margin:0 0 16px 0;">It does not include Active Cruise, Float Plan Monitoring, private Trip/Follow access, live check-ins, updates, photos, or comments.</p>
<p style="margin:0 0 16px 0;"><strong>This float plan is precautionary trip information.</strong> Nothing in this email indicates that FPW has verified an emergency.</p>
<p style="margin:0 0 16px 0;">If you believe there may be an emergency, contact the appropriate emergency authority directly. FPW does not independently verify emergencies or dispatch assistance.</p>
<p style="margin:0 0 16px 0;">Email delivery is not guaranteed, and FPW does not confirm that a recipient has received or read this message.</p>
<p style="margin:0;">Please keep the attached PDF available with the trip information.</p>
#complianceFooter.htmlBody#
        </cfoutput></cfsavecontent>
        <cfset htmlBody = renderBaseEmailLayout(title = subject, bodyHtml = htmlContent)>

        <cftry>
            <cfset sendMultipartEmail(
                toEmail = toAddress,
                subject = subject,
                htmlBody = htmlBody,
                textBody = textBody,
                attachmentPath = attachmentPath,
                spoolEnable = false,
                rethrowOnFailure = true
            )>
            <cfset result.success = true>
            <cfset result.message = "Basic float plan emailed to " & toAddress & ".">
            <cfreturn result>

            <cfcatch type="any">
                <cfset logSafeEmailFailure(
                    messageType = "BASIC_REVIEW_FLOAT_PLAN",
                    userId = arguments.userId,
                    toEmail = toAddress,
                    exceptionType = (structKeyExists(cfcatch, "type") ? cfcatch.type : "any")
                )>
                <cfset result.errorCode = "SEND_FAILED">
                <cfset result.message = "The Basic float-plan email could not be sent.">
                <cfreturn result>
            </cfcatch>
        </cftry>
    </cffunction>

    <cffunction name="sendDepartureReminderEmail" access="public" returntype="struct" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="toEmail" type="string" required="true">
        <cfargument name="floatPlanId" type="numeric" required="true">
        <cfargument name="floatPlanName" type="string" required="false" default="">
        <cfargument name="scheduledDepartureLabel" type="string" required="true">
        <cfargument name="departureTimezone" type="string" required="true">
        <cfargument name="reminderType" type="string" required="true">

        <cfset var result = {
            success = false,
            messageType = "DEPARTURE_REMINDER",
            errorCode = "",
            message = ""
        }>
        <cfset var toAddress = lCase(trim(arguments.toEmail))>
        <cfset var reminderTypeValue = uCase(trim(arguments.reminderType))>
        <cfset var emailMessage = {}>

        <cfif int(arguments.userId) LTE 0 OR int(arguments.floatPlanId) LTE 0>
            <cfset result.errorCode = "INVALID_TRIP_OWNER">
            <cfset result.message = "Departure reminder trip ownership is invalid.">
            <cfreturn result>
        </cfif>
        <cfif NOT isValid("email", toAddress)>
            <cfset result.errorCode = "INVALID_RECIPIENT">
            <cfset result.message = "Departure reminder recipient is invalid.">
            <cfreturn result>
        </cfif>
        <cfif NOT listFindNoCase("PRE_DEPARTURE,NOT_STARTED", reminderTypeValue)>
            <cfset result.errorCode = "INVALID_REMINDER_TYPE">
            <cfset result.message = "Departure reminder type is invalid.">
            <cfreturn result>
        </cfif>
        <cfif NOT len(trim(arguments.scheduledDepartureLabel)) OR NOT len(trim(arguments.departureTimezone))>
            <cfset result.errorCode = "INVALID_DEPARTURE_TIME">
            <cfset result.message = "Departure reminder schedule is invalid.">
            <cfreturn result>
        </cfif>

        <cftry>
            <cfset emailMessage = buildDepartureReminderEmail(
                floatPlanId = arguments.floatPlanId,
                floatPlanName = arguments.floatPlanName,
                scheduledDepartureLabel = arguments.scheduledDepartureLabel,
                departureTimezone = arguments.departureTimezone,
                reminderType = reminderTypeValue
            )>
            <cfset sendMultipartEmail(
                toEmail = toAddress,
                subject = emailMessage.subject,
                htmlBody = emailMessage.htmlBody,
                textBody = emailMessage.textBody,
                spoolEnable = false,
                rethrowOnFailure = true
            )>
            <cfset result.success = true>
            <cfset result.messageType = "DEPARTURE_REMINDER_" & reminderTypeValue>
            <cfset result.message = "Departure reminder accepted for delivery.">
            <cfreturn result>

            <cfcatch type="any">
                <cfset logSafeEmailFailure(
                    messageType = "DEPARTURE_REMINDER_" & reminderTypeValue,
                    userId = arguments.userId,
                    toEmail = toAddress,
                    exceptionType = (structKeyExists(cfcatch, "type") ? cfcatch.type : "any")
                )>
                <cfset result.errorCode = "SEND_FAILED">
                <cfset result.message = "The departure reminder could not be sent.">
                <cfreturn result>
            </cfcatch>
        </cftry>
    </cffunction>

    <cffunction name="buildDepartureReminderEmail" access="private" returntype="struct" output="false">
        <cfargument name="floatPlanId" type="numeric" required="true">
        <cfargument name="floatPlanName" type="string" required="false" default="">
        <cfargument name="scheduledDepartureLabel" type="string" required="true">
        <cfargument name="departureTimezone" type="string" required="true">
        <cfargument name="reminderType" type="string" required="true">

        <cfset var config = getEmailConfig()>
        <cfset var reminderTypeValue = uCase(trim(arguments.reminderType))>
        <cfset var planName = cleanDepartureReminderTextValue(arguments.floatPlanName)>
        <cfset var departureLabel = cleanDepartureReminderTextValue(arguments.scheduledDepartureLabel)>
        <cfset var timezoneLabel = cleanDepartureReminderTextValue(arguments.departureTimezone)>
        <cfset var ctaPath = "/app/active-cruise.cfm?floatPlanId=" & int(arguments.floatPlanId)>
        <cfset var ctaUrl = reReplace(config.publicBaseUrl, "/+$", "") & ctaPath>
        <cfset var subject = "">
        <cfset var textLines = []>
        <cfset var textBody = "">
        <cfset var htmlContent = "">
        <cfset var htmlBody = "">
        <cfset var complianceFooter = buildEmailComplianceFooter(footerType = "service")>

        <cfif NOT len(planName)>
            <cfset planName = "Your FloatPlanWizard trip">
        </cfif>

        <cfif reminderTypeValue EQ "PRE_DEPARTURE">
            <cfset subject = "Your FloatPlanWizard trip is coming up">
            <cfset textLines = [
                "Hello,",
                "",
                planName & " is scheduled to depart " & departureLabel & " (" & timezoneLabel & ").",
                "",
                "This is a reminder that your scheduled departure is coming up.",
                "",
                "Open Active Cruise:",
                ctaUrl
            ]>
            <cfsavecontent variable="htmlContent"><cfoutput>
<p style="margin:0 0 16px 0;">Hello,</p>
<p style="margin:0 0 16px 0;"><strong>#encodeForHtml(planName)#</strong> is scheduled to depart <strong>#encodeForHtml(departureLabel)# (#encodeForHtml(timezoneLabel)#)</strong>.</p>
<p style="margin:0 0 22px 0;">This is a reminder that your scheduled departure is coming up.</p>
<p style="margin:0;"><a href="#encodeForHtmlAttribute(ctaUrl)#" style="display:inline-block;background:##17d8e6;color:##06243a;text-decoration:none;font-weight:700;padding:12px 20px;border-radius:8px;">Open Active Cruise</a></p>
#complianceFooter.htmlBody#
            </cfoutput></cfsavecontent>
        <cfelse>
            <cfset subject = "Your scheduled trip has not started yet">
            <cfset textLines = [
                "Hello,",
                "",
                "The scheduled departure for " & planName & " was " & departureLabel & " (" & timezoneLabel & ").",
                "",
                "FPW has not recorded an actual trip start.",
                "If your plans changed, review the trip. If you are leaving now, open Active Cruise to start or manage it.",
                "",
                "Open Active Cruise:",
                ctaUrl
            ]>
            <cfsavecontent variable="htmlContent"><cfoutput>
<p style="margin:0 0 16px 0;">Hello,</p>
<p style="margin:0 0 16px 0;">The scheduled departure for <strong>#encodeForHtml(planName)#</strong> was <strong>#encodeForHtml(departureLabel)# (#encodeForHtml(timezoneLabel)#)</strong>.</p>
<p style="margin:0 0 12px 0;">FPW has not recorded an actual trip start.</p>
<p style="margin:0 0 22px 0;">If your plans changed, review the trip. If you are leaving now, open Active Cruise to start or manage it.</p>
<p style="margin:0;"><a href="#encodeForHtmlAttribute(ctaUrl)#" style="display:inline-block;background:##17d8e6;color:##06243a;text-decoration:none;font-weight:700;padding:12px 20px;border-radius:8px;">Open Active Cruise</a></p>
#complianceFooter.htmlBody#
            </cfoutput></cfsavecontent>
        </cfif>

        <cfset textBody = arrayToList(textLines, chr(10)) & chr(10) & chr(10) & complianceFooter.textBody>
        <cfset htmlBody = renderBaseEmailLayout(title = subject, bodyHtml = htmlContent)>
        <cfreturn {
            subject = subject,
            textBody = textBody,
            htmlBody = htmlBody,
            ctaPath = ctaPath,
            ctaUrl = ctaUrl,
            reminderType = reminderTypeValue
        }>
    </cffunction>

    <cffunction name="buildWelcomeMemberEmail" access="private" returntype="struct" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="toEmail" type="string" required="true">
        <cfargument name="firstName" type="string" required="false" default="">
        <cfargument name="dashboardUrl" type="string" required="false" default="">

        <cfset var config = getEmailConfig()>
        <cfset var cleanFirstName = cleanTextValue(arguments.firstName)>
        <cfset var dashboardUrlValue = normalizeDashboardUrl(arguments.dashboardUrl, config.dashboardUrl)>
        <cfset var dashboardUrlHtml = encodeForHtmlAttribute(dashboardUrlValue)>
        <cfset var greetingText = len(cleanFirstName) ? "Hi " & cleanFirstName & "," : "Hi,">
        <cfset var greetingHtml = len(cleanFirstName) ? "Hi " & encodeForHtml(cleanFirstName) & "," : "Hi,">
        <cfset var subject = "Welcome to FloatPlanWizard.com">
        <cfset var safetyNotice = "Float Plan Wizard helps organize and share trip information, but it is not a rescue, emergency dispatch, or distress-response service. In an emergency, always use official emergency channels such as VHF Channel 16, DSC distress, 911, EPIRB/PLB, flares, or other accepted emergency methods.">
        <cfset var optOutUrl = buildWelcomeMemberOptOutUrl(
            userId = arguments.userId,
            toEmail = arguments.toEmail,
            publicBaseUrl = config.publicBaseUrl
        )>
        <cfset var complianceFooter = buildEmailComplianceFooter(
            footerType = "service",
            context = {
                optOutUrl = optOutUrl
            }
        )>
        <cfset var textBody = "">
        <cfset var htmlContent = "">
        <cfset var htmlBody = "">

        <cfset textBody = arrayToList([
            greetingText,
            "",
            "Thank you for joining FloatPlanWizard.com.",
            "",
            "FPW helps boaters plan trips, organize float plan details, and keep trusted contacts informed.",
            "",
            "Start from your dashboard to begin setting up your account and float plans.",
            "",
            "Go to Your Dashboard:",
            dashboardUrlValue,
            "",
            "You can use FloatPlanWizard.com from your phone, tablet, or desktop. The site is mobile-friendly, so you can use the main web tools from your phone, tablet, or desktop.",
            "",
            "During this launch/beta period, we would love your feedback as you use FPW.",
            "",
            safetyNotice,
            "",
            "Thank you,",
            "The FloatPlanWizard.com Team"
        ], chr(10))>
        <cfset textBody = textBody & chr(10) & chr(10) & complianceFooter.textBody>

        <cfsavecontent variable="htmlContent"><cfoutput>
<p style="margin:0 0 16px 0;">#greetingHtml#</p>
<p style="margin:0 0 16px 0;">Thank you for joining FloatPlanWizard.com.</p>
<p style="margin:0 0 16px 0;">FPW helps boaters plan trips, organize float plan details, and keep trusted contacts informed.</p>
<p style="margin:0 0 16px 0;">Start from your dashboard to begin setting up your account and float plans.</p>
<p style="margin:0 0 22px 0;">You can use FloatPlanWizard.com from your phone, tablet, or desktop. The site is mobile-friendly, so you can use the main web tools from your phone, tablet, or desktop.</p>
<p style="margin:0 0 24px 0;"><a href="#dashboardUrlHtml#" style="display:inline-block; background-color:##0d6efd; color:##ffffff; text-decoration:none; font-weight:600; padding:12px 18px; border-radius:6px;">Go to Your Dashboard</a></p>
<p style="margin:0 0 16px 0;">During this launch/beta period, we would love your feedback as you use FPW.</p>
<p style="margin:0 0 16px 0; font-size:13px; line-height:1.5; color:##495057;"><strong>Safety notice:</strong> #encodeForHtml(safetyNotice)#</p>
<p style="margin:0 0 24px 0;">Thank you,<br>The FloatPlanWizard.com Team</p>
#complianceFooter.htmlBody#
        </cfoutput></cfsavecontent>

        <cfset htmlBody = renderBaseEmailLayout(
            title = subject,
            bodyHtml = htmlContent
        )>

        <cfreturn {
            subject = subject,
            htmlBody = htmlBody,
            textBody = textBody
        }>
    </cffunction>

    <cffunction name="buildPasswordResetEmail" access="private" returntype="struct" output="false">
        <cfargument name="resetUrl" type="string" required="true">
        <cfargument name="expiresMinutes" type="numeric" required="false" default="60">

        <cfset var subject = "Reset your FloatPlanWizard password">
        <cfset var resetUrlHtml = encodeForHtmlAttribute(arguments.resetUrl)>
        <cfset var resetUrlTextHtml = encodeForHtml(arguments.resetUrl)>
        <cfset var expiresText = int(arguments.expiresMinutes)>
        <cfset var textBody = "">
        <cfset var htmlContent = "">
        <cfset var htmlBody = "">

        <cfset textBody = arrayToList([
            "Hello,",
            "",
            "We received a request to reset the password for your FloatPlanWizard account.",
            "",
            "Use the link below to choose a new password:",
            "",
            arguments.resetUrl,
            "",
            "This link expires in " & expiresText & " minutes. If you did not request a password reset, you can ignore this email and your password will remain unchanged.",
            "",
            "FloatPlanWizard"
        ], chr(10))>

        <cfsavecontent variable="htmlContent"><cfoutput>
<p style="margin:0 0 16px 0;">Hello,</p>
<p style="margin:0 0 16px 0;">We received a request to reset the password for your FloatPlanWizard account.</p>
<p style="margin:0 0 16px 0;">Use the link below to choose a new password:</p>
<p style="margin:0 0 22px 0;"><a href="#resetUrlHtml#" style="display:inline-block; background-color:##0d6efd; color:##ffffff; text-decoration:none; font-weight:600; padding:12px 18px; border-radius:6px;">Reset Your Password</a></p>
<p style="margin:0 0 18px 0; word-break:break-all;"><a href="#resetUrlHtml#" style="color:##0d6efd;">#resetUrlTextHtml#</a></p>
<p style="margin:0 0 16px 0;">This link expires in #expiresText# minutes. If you did not request a password reset, you can ignore this email and your password will remain unchanged.</p>
<p style="margin:0;">FloatPlanWizard</p>
        </cfoutput></cfsavecontent>

        <cfset htmlBody = renderBaseEmailLayout(
            title = subject,
            bodyHtml = htmlContent
        )>

        <cfreturn {
            subject = subject,
            htmlBody = htmlBody,
            textBody = textBody
        }>
    </cffunction>

    <cffunction name="buildWelcomeMemberOptOutUrl" access="private" returntype="string" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="toEmail" type="string" required="true">
        <cfargument name="publicBaseUrl" type="string" required="true">

        <cfset var optOutService = "">

        <cftry>
            <cfset optOutService = createObject("component", "api.v1.EmailOptOutService").init(
                publicBaseUrl = arguments.publicBaseUrl
            )>
            <cfcatch type="any">
                <cfset optOutService = createObject("component", "fpw.api.v1.EmailOptOutService").init(
                    publicBaseUrl = arguments.publicBaseUrl
                )>
            </cfcatch>
        </cftry>

        <cfreturn optOutService.buildOptOutUrl(
            email = arguments.toEmail,
            userId = arguments.userId,
            optOutType = "non_essential"
        )>
    </cffunction>

    <cffunction name="renderBaseEmailLayout" access="private" returntype="string" output="false">
        <cfargument name="title" type="string" required="true">
        <cfargument name="bodyHtml" type="string" required="true">

        <cfset var html = "">
        <cfsavecontent variable="html"><cfoutput><!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>#encodeForHtml(arguments.title)#</title>
</head>
<body style="margin:0; padding:0; background-color:##f5f7fa; color:##212529; font-family:Arial, Helvetica, sans-serif;">
    <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="border-collapse:collapse; background-color:##f5f7fa;">
        <tr>
            <td align="center" style="padding:28px 14px;">
                <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="border-collapse:collapse; max-width:640px; background-color:##ffffff; border:1px solid ##dee2e6;">
                    <tr>
                        <td style="padding:22px 24px; background-color:##0b2f4f; color:##ffffff; font-size:20px; font-weight:700;">
                            FloatPlanWizard.com
                        </td>
                    </tr>
                    <tr>
                        <td style="padding:24px; font-size:16px; line-height:1.55;">
                            #arguments.bodyHtml#
                        </td>
                    </tr>
                    <tr>
                        <td style="padding:18px 24px; background-color:##f8f9fa; color:##6c757d; font-size:12px; line-height:1.45;">
                            FloatPlanWizard.com
                        </td>
                    </tr>
                </table>
            </td>
        </tr>
    </table>
</body>
</html></cfoutput></cfsavecontent>

        <cfreturn html>
    </cffunction>

    <!--- Existing scattered emails are intentionally not migrated in this phase. Future email migrations should call this centralized footer renderer with either "service" or "marketing" as appropriate. --->
    <cffunction name="buildEmailComplianceFooter" access="private" returntype="struct" output="false">
        <cfargument name="footerType" type="string" required="true">
        <cfargument name="context" type="struct" required="false" default="#structNew()#">

        <cfset var config = getEmailConfig()>
        <cfset var footerTypeValue = lcase(trim(arguments.footerType))>
        <cfset var emailPreferencesUrl = config.emailPreferencesUrl>
        <cfset var unsubscribeUrl = config.unsubscribeUrl>
        <cfset var siteUrl = config.publicBaseUrl>
        <cfset var businessMailingAddress = config.businessMailingAddress>
        <cfset var emailPreferencesUrlHtml = encodeForHtmlAttribute(emailPreferencesUrl)>
        <cfset var emailPreferencesUrlTextHtml = encodeForHtml(emailPreferencesUrl)>
        <cfset var unsubscribeUrlHtml = encodeForHtmlAttribute(unsubscribeUrl)>
        <cfset var unsubscribeUrlTextHtml = encodeForHtml(unsubscribeUrl)>
        <cfset var siteUrlHtml = encodeForHtmlAttribute(siteUrl)>
        <cfset var siteUrlTextHtml = encodeForHtml(siteUrl)>
        <cfset var businessMailingAddressHtml = encodeForHtml(businessMailingAddress)>
        <cfset var htmlBody = "">
        <cfset var textBody = "">

        <cfif structKeyExists(arguments.context, "optOutUrl") AND len(trim(toString(arguments.context.optOutUrl)))>
            <cfset emailPreferencesUrl = trim(toString(arguments.context.optOutUrl))>
            <cfset emailPreferencesUrlHtml = encodeForHtmlAttribute(emailPreferencesUrl)>
            <cfset emailPreferencesUrlTextHtml = encodeForHtml(emailPreferencesUrl)>
        </cfif>

        <cfif footerTypeValue EQ "service">
            <cfset textBody = arrayToList([
                "You may opt out of non-essential emails here:",
                emailPreferencesUrl,
                "",
                "Some FloatPlanWizard.com emails are required to operate your account or complete actions you request. For example, sending a float plan requires email delivery. To stop all account-related and service-related emails, you must close your FloatPlanWizard.com account.",
                "",
                "FloatPlanWizard.com",
                businessMailingAddress,
                siteUrl
            ], chr(10))>

            <cfsavecontent variable="htmlBody"><cfoutput>
<div style="margin-top:24px; padding-top:18px; border-top:1px solid ##dee2e6; color:##6c757d; font-size:12px; line-height:1.5;">
    <p style="margin:0 0 12px 0;">You may opt out of non-essential emails here:<br><a href="#emailPreferencesUrlHtml#" style="color:##0d6efd;">#emailPreferencesUrlTextHtml#</a></p>
    <p style="margin:0 0 12px 0;">Some FloatPlanWizard.com emails are required to operate your account or complete actions you request. For example, sending a float plan requires email delivery. To stop all account-related and service-related emails, you must close your FloatPlanWizard.com account.</p>
    <p style="margin:0;">FloatPlanWizard.com<br>#businessMailingAddressHtml#<br><a href="#siteUrlHtml#" style="color:##0d6efd;">#siteUrlTextHtml#</a></p>
</div>
            </cfoutput></cfsavecontent>
        <cfelseif footerTypeValue EQ "marketing">
            <cfset textBody = arrayToList([
                "You are receiving this email because you signed up for FloatPlanWizard.com updates, created an account, or asked to receive information from Float Plan Wizard.",
                "",
                "You may opt out of marketing and promotional emails at any time:",
                unsubscribeUrl,
                "",
                "You can also manage your email preferences here:",
                emailPreferencesUrl,
                "",
                "FloatPlanWizard.com",
                businessMailingAddress,
                siteUrl
            ], chr(10))>

            <cfsavecontent variable="htmlBody"><cfoutput>
<div style="margin-top:24px; padding-top:18px; border-top:1px solid ##dee2e6; color:##6c757d; font-size:12px; line-height:1.5;">
    <p style="margin:0 0 12px 0;">You are receiving this email because you signed up for FloatPlanWizard.com updates, created an account, or asked to receive information from Float Plan Wizard.</p>
    <p style="margin:0 0 12px 0;">You may opt out of marketing and promotional emails at any time.<br><a href="#unsubscribeUrlHtml#" style="color:##0d6efd;">#unsubscribeUrlTextHtml#</a><br>or<br><a href="#emailPreferencesUrlHtml#" style="color:##0d6efd;">#emailPreferencesUrlTextHtml#</a></p>
    <p style="margin:0;">FloatPlanWizard.com<br>#businessMailingAddressHtml#<br><a href="#siteUrlHtml#" style="color:##0d6efd;">#siteUrlTextHtml#</a></p>
</div>
            </cfoutput></cfsavecontent>
        <cfelse>
            <cfthrow type="email.InvalidFooterType" message="Invalid email compliance footer type.">
        </cfif>

        <cfreturn {
            htmlBody = htmlBody,
            textBody = textBody
        }>
    </cffunction>

    <cffunction name="sendMultipartEmail" access="private" returntype="void" output="false">
        <cfargument name="toEmail" type="string" required="true">
        <cfargument name="subject" type="string" required="true">
        <cfargument name="htmlBody" type="string" required="true">
        <cfargument name="textBody" type="string" required="true">
        <cfargument name="attachmentPath" type="string" required="false" default="">
        <cfargument name="spoolEnable" type="boolean" required="false" default="true">
        <cfargument name="rethrowOnFailure" type="boolean" required="false" default="false">

        <cfset var config = getEmailConfig()>
        <cfset var mailAttrs = {
            to = arguments.toEmail,
            from = config.fromValue,
            subject = arguments.subject,
            charset = "utf-8",
            spoolenable = arguments.spoolEnable
        }>

        <cfif len(config.replyToEmail)>
            <cfset mailAttrs.replyto = config.replyToEmail>
        </cfif>

        <cftry>
            <cfmail attributeCollection="#mailAttrs#">
                <cfif len(trim(arguments.attachmentPath))>
                    <cfmailparam type="application/pdf" file="#arguments.attachmentPath#">
                </cfif>
                <cfmailpart type="text/plain" charset="utf-8">#arguments.textBody#</cfmailpart>
                <cfmailpart type="text/html" charset="utf-8">#arguments.htmlBody#</cfmailpart>
            </cfmail>

            <cftry>
                <cfset var successLogPath = getAppLogDirectory() & "/email_success.log">
                <cfset var successLogDirectory = getDirectoryFromPath(successLogPath)>
                <cfset var successReplyTo = structKeyExists(mailAttrs, "replyto") ? mailAttrs.replyto : "">
                <cfset var successLogEntry = dateTimeFormat(now(), "yyyy-mm-dd HH:nn:ss") & " sendMultipartEmail"
                    & " status=SUCCESS"
                    & " to=" & arguments.toEmail
                    & " subject=" & arguments.subject
                    & " from=" & mailAttrs.from
                    & " replyto=" & successReplyTo>
                <cfset successLogEntry = replace(replace(successLogEntry, chr(13), " ", "all"), chr(10), " ", "all")>
                <cfif NOT directoryExists(successLogDirectory)>
                    <cfdirectory action="create" directory="#successLogDirectory#">
                </cfif>
                <cffile action="append" file="#successLogPath#" output="#successLogEntry#" addnewline="true" charset="utf-8">
                <cfcatch type="any">
                </cfcatch>
            </cftry>

            <cfcatch type="any">
                <cftry>
                    <cfset var logPath = getAppLogDirectory() & "/email_error.log">
                    <cfset var logDirectory = getDirectoryFromPath(logPath)>
                    <cfset var catchType = structKeyExists(cfcatch, "type") ? cfcatch.type : "any">
                    <cfset var catchDetail = structKeyExists(cfcatch, "detail") ? cfcatch.detail : "">
                    <cfset var logEntry = dateTimeFormat(now(), "yyyy-mm-dd HH:nn:ss") & " sendMultipartEmail error"
                        & " to=" & arguments.toEmail
                        & " subject=" & arguments.subject
                        & " type=" & catchType
                        & " message=" & cfcatch.message
                        & " detail=" & left(catchDetail, 1000)>
                    <cfset logEntry = replace(replace(logEntry, chr(13), " ", "all"), chr(10), " ", "all")>
                    <cfif NOT directoryExists(logDirectory)>
                        <cfdirectory action="create" directory="#logDirectory#">
                    </cfif>
                    <cffile action="append" file="#logPath#" output="#logEntry#" addnewline="true" charset="utf-8">
                    <cfcatch type="any">
                    </cfcatch>
                </cftry>
                <cfif arguments.rethrowOnFailure>
                    <cfrethrow>
                </cfif>
            </cfcatch>
        </cftry>
    </cffunction>

    <cffunction name="getEmailConfig" access="private" returntype="struct" output="false">
        <cfset var fromDisplayName = "FloatPlanWizard">
        <cfset var fromEmail = "info@floatplanwizard.com">
        <cfset var fallbackPublicBaseUrl = "https://www.floatplanwizard.com">
        <cfset var fallbackDashboardUrl = "https://www.floatplanwizard.com/app/dashboard.cfm">
        <cfset var publicBaseUrl = resolvePublicBaseUrl(fallbackPublicBaseUrl)>
        <cfset var dashboardUrl = publicBaseUrl & "/app/dashboard.cfm">
        <cfif compareNoCase(publicBaseUrl, fallbackPublicBaseUrl) EQ 0>
            <cfset dashboardUrl = fallbackDashboardUrl>
        </cfif>
        <!--- TODO: Replace compliance footer mailing address placeholder when canonical FPW business address config exists. --->
        <cfset var config = {
            fromDisplayName = fromDisplayName,
            fromEmail = fromEmail,
            fromValue = fromDisplayName & " <" & fromEmail & ">",
            replyToEmail = "info@floatplanwizard.com",
            publicBaseUrl = publicBaseUrl,
            dashboardUrl = dashboardUrl,
            emailPreferencesUrl = publicBaseUrl & "/app/account.cfm##email-preferences",
            unsubscribeUrl = publicBaseUrl & "/unsubscribe.cfm",
            businessMailingAddress = "[FloatPlanWizard.com Mailing Address]"
        }>

        <cfreturn config>
    </cffunction>

    <cffunction name="getAppLogDirectory" access="private" returntype="string" output="false">
        <cfset var componentDir = replace(getDirectoryFromPath(getCurrentTemplatePath()), "\", "/", "all")>
        <cfset var appRoot = reReplace(componentDir, "/api/v1/?$", "/", "one")>

        <cfreturn appRoot & "logs">
    </cffunction>

    <cffunction name="resolvePublicBaseUrl" access="private" returntype="string" output="false">
        <cfargument name="fallbackBaseUrl" type="string" required="true">

        <cfset var host = "">
        <cfset var scheme = "https">
        <cfset var forwardedProto = "">
        <cfset var basePath = resolveFpwBasePath()>

        <cfif structKeyExists(cgi, "http_host")>
            <cfset host = trim(toString(cgi.http_host))>
        <cfelseif structKeyExists(cgi, "HTTP_HOST")>
            <cfset host = trim(toString(cgi.HTTP_HOST))>
        </cfif>

        <cfif NOT len(host)>
            <cfreturn reReplace(trim(arguments.fallbackBaseUrl), "/+$", "", "all")>
        </cfif>

        <cfif structKeyExists(cgi, "http_x_forwarded_proto")>
            <cfset forwardedProto = lCase(trim(listFirst(toString(cgi.http_x_forwarded_proto), ",")))>
        <cfelseif structKeyExists(cgi, "HTTP_X_FORWARDED_PROTO")>
            <cfset forwardedProto = lCase(trim(listFirst(toString(cgi.HTTP_X_FORWARDED_PROTO), ",")))>
        </cfif>

        <cfif listFindNoCase("http,https", forwardedProto)>
            <cfset scheme = forwardedProto>
        <cfelseif structKeyExists(cgi, "https") AND listFindNoCase("on,1,true", trim(toString(cgi.https)))>
            <cfset scheme = "https">
        <cfelseif structKeyExists(cgi, "HTTPS") AND listFindNoCase("on,1,true", trim(toString(cgi.HTTPS)))>
            <cfset scheme = "https">
        <cfelseif findNoCase("localhost", host) OR left(host, 4) EQ "127.">
            <cfset scheme = "http">
        </cfif>

        <cfreturn reReplace(scheme & "://" & host & basePath, "/+$", "", "all")>
    </cffunction>

    <cffunction name="resolveFpwBasePath" access="private" returntype="string" output="false">
        <cfset var basePath = "">

        <cfif structKeyExists(request, "fpwBase") AND NOT isNull(request.fpwBase)>
            <cfset basePath = trim(toString(request.fpwBase))>
        <cfelse>
            <cfif structKeyExists(cgi, "script_name")>
                <cfset basePath = trim(toString(cgi.script_name))>
            <cfelseif structKeyExists(cgi, "SCRIPT_NAME")>
                <cfset basePath = trim(toString(cgi.SCRIPT_NAME))>
            </cfif>

            <cfset basePath = reReplace(basePath, "[?##].*$", "")>
            <cfset basePath = replace(basePath, "\", "/", "all")>
            <cfset basePath = reReplaceNoCase(basePath, "/api/v1(/.*)?$", "")>
            <cfset basePath = reReplaceNoCase(basePath, "/(app|admin|assets|tests)(/.*)?$", "")>
            <cfset basePath = reReplaceNoCase(basePath, "/[^/]*\.(cfm|cfc)$", "")>
        </cfif>

        <cfset basePath = reReplace(basePath, "/$", "")>
        <cfif basePath EQ "/">
            <cfset basePath = "">
        </cfif>
        <cfif len(basePath) AND left(basePath, 1) NEQ "/">
            <cfset basePath = "/" & basePath>
        </cfif>

        <cfreturn basePath>
    </cffunction>

    <cffunction name="normalizeDashboardUrl" access="private" returntype="string" output="false">
        <cfargument name="dashboardUrl" type="string" required="false" default="">
        <cfargument name="defaultDashboardUrl" type="string" required="true">

        <cfset var urlValue = trim(arguments.dashboardUrl)>
        <cfif len(urlValue) AND reFindNoCase("^https?://", urlValue)>
            <cfreturn urlValue>
        </cfif>

        <cfreturn arguments.defaultDashboardUrl>
    </cffunction>

    <cffunction name="cleanDepartureReminderTextValue" access="private" returntype="string" output="false">
        <cfargument name="value" type="string" required="false" default="">

        <cfreturn reReplace(trim(arguments.value), "[\r\n\t]+", " ", "all")>
    </cffunction>

    <cffunction name="cleanTextValue" access="private" returntype="string" output="false">
        <cfargument name="value" type="string" required="false" default="">

        <cfreturn reReplace(trim(arguments.value), "[\\r\\n\\t]+", " ", "all")>
    </cffunction>

    <cffunction name="cleanBasicReviewTextValue" access="private" returntype="string" output="false">
        <cfargument name="value" type="string" required="false" default="">

        <cfset var cleanValue = replace(arguments.value, chr(13), " ", "all")>
        <cfset cleanValue = replace(cleanValue, chr(10), " ", "all")>
        <cfset cleanValue = replace(cleanValue, chr(9), " ", "all")>
        <cfreturn trim(cleanValue)>
    </cffunction>

    <cffunction name="logSafeEmailFailure" access="private" returntype="void" output="false">
        <cfargument name="messageType" type="string" required="true">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="toEmail" type="string" required="true">
        <cfargument name="exceptionType" type="string" required="false" default="any">

        <cfset var recipientHash = hash(lcase(trim(arguments.toEmail)), "SHA-256", "UTF-8")>
        <cflog
            file="fpw_email"
            type="error"
            text="email.cfc SEND_FAILED | messageType=#cleanTextValue(arguments.messageType)# | userId=#int(arguments.userId)# | recipientHash=#recipientHash# | exceptionType=#cleanTextValue(arguments.exceptionType)# | time=#now()#">
    </cffunction>

</cfcomponent>
