<cfcomponent output="false">

    <cffunction name="handle" access="remote" returntype="void" output="true">
        <cfargument name="firstName" type="any" required="false">
        <cfargument name="lastName" type="any" required="false">
        <cfargument name="email" type="any" required="false">
        <cfargument name="description" type="any" required="false">
        <cfargument name="website" type="any" required="false">
        <cfsetting enablecfoutputonly="true" showdebugoutput="false">

        <cfset contactPageUrl = "/fpw/app/contact.cfm">
        <cfset firstName = structKeyExists(arguments, "firstName") ? trim(arguments.firstName) : "">
        <cfset lastName = structKeyExists(arguments, "lastName") ? trim(arguments.lastName) : "">
        <cfset email = structKeyExists(arguments, "email") ? trim(arguments.email) : "">
        <cfset description = structKeyExists(arguments, "description") ? trim(arguments.description) : "">
        <cfset website = structKeyExists(arguments, "website") ? trim(arguments.website) : "">

        <cfset status = "">
        <cfset code = "">
        <cfset redirectUrl = "">
        <cfset hasSingleAt = listLen(email, "@") EQ 2>
        <cfset localPart = hasSingleAt ? listFirst(email, "@") : "">
        <cfset domainPart = hasSingleAt ? listLast(email, "@") : "">
        <cfset isValidEmail = hasSingleAt AND len(localPart) GT 0 AND len(domainPart) GT 0 AND find(".", domainPart) GT 1 AND find(" ", email) EQ 0>

        <cfif len(website)>
            <cfset status = "success">
        <cfelseif NOT len(firstName) OR NOT len(lastName) OR NOT len(email) OR NOT len(description)>
            <cfset status = "error">
            <cfset code = "validation">
        <cfelseif NOT isValidEmail>
            <cfset status = "error">
            <cfset code = "invalid_email">
        <cfelse>
            <cftry>
                <cfmail
                    to="support@floatplanwizard.com"
                    from="no-reply@floatplanwizard.com"
                    replyto="#email#"
                    subject="Float Plan Wizard Contact Us: #firstName# #lastName#"
                    type="text">
First Name: #firstName#
Last Name: #lastName#
Email: #email#

Description:
#description#

Submitted: #dateTimeFormat(now(), "mmmm d, yyyy h:nn tt")#
                </cfmail>

                <cfset status = "success">

            <cfcatch type="any">
                <cfset status = "error">
                <cfset code = "send_failed">
            </cfcatch>
            </cftry>
        </cfif>

        <cfif status EQ "success">
            <cfset redirectUrl = contactPageUrl & "?status=success">
        <cfelse>
            <cfset redirectUrl = contactPageUrl & "?status=error&code=" & code>
        </cfif>

        <cfcontent type="text/html; charset=utf-8" reset="true">
        <cfoutput><!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta http-equiv="refresh" content="0;url=#redirectUrl#">
    <title>Redirecting...</title>
    <script>
        window.location.replace("#redirectUrl#");
    </script>
</head>
<body>
    <a href="#redirectUrl#">Continue</a>
</body>
</html></cfoutput>
        <cfsetting enablecfoutputonly="false">
        <cfreturn>
    </cffunction>

</cfcomponent>
