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
            "You can use FloatPlanWizard.com from your phone, tablet, or desktop. The site is mobile-friendly, and the companion app is not required to use the main web tools.",
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
<p style="margin:0 0 22px 0;">You can use FloatPlanWizard.com from your phone, tablet, or desktop. The site is mobile-friendly, and the companion app is not required to use the main web tools.</p>
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

        <cfset var config = getEmailConfig()>
        <cfset var mailAttrs = {
            to = arguments.toEmail,
            from = config.fromValue,
            subject = arguments.subject,
            charset = "utf-8"
        }>

        <cfif len(config.replyToEmail)>
            <cfset mailAttrs.replyto = config.replyToEmail>
        </cfif>

        <cftry>
            <cfmail attributeCollection="#mailAttrs#">
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
            </cfcatch>
        </cftry>
    </cffunction>

    <cffunction name="getEmailConfig" access="private" returntype="struct" output="false">
        <cfset var fromDisplayName = "FloatPlanWizard">
        <cfset var fromEmail = "noeply@floatplanwizard.com">
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
            replyToEmail = "",
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

    <cffunction name="cleanTextValue" access="private" returntype="string" output="false">
        <cfargument name="value" type="string" required="false" default="">

        <cfreturn reReplace(trim(arguments.value), "[\\r\\n\\t]+", " ", "all")>
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





