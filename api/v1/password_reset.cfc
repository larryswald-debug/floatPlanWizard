<cfcomponent output="false">

    <cffunction name="sendResponse" access="private" returntype="void" output="true">
        <cfargument name="payload" type="struct" required="true">
        <cfif structKeyExists(request,"fpwResetRateTickets")>
            <cfloop array="#request.fpwResetRateTickets#" index="local.rateTicket">
                <cfset createObject("component",componentPath("api.v1.AuthRateLimitService")).init("fpw").finish(local.rateTicket, request.fpwResetRateOutcome ?: "error")>
            </cfloop>
            <cfset request.fpwResetRateTickets=[]>
        </cfif>
        <cfoutput>#serializeJSON(arguments.payload)#</cfoutput>
        <cfabort>
    </cffunction>

    <cffunction name="handle" access="remote" returntype="void" output="true">
        <cfsetting enablecfoutputonly="true" showdebugoutput="false">
        <cfcontent type="application/json; charset=utf-8">
        <cfheader name="Cache-Control" value="no-store, no-cache, must-revalidate">
        <cfheader name="Pragma" value="no-cache">
        <cfheader name="Expires" value="0">

        <cfset var httpData = {}>
        <cfset var rawBody = "">
        <cfset var body = {}>
        <cfset var action = "">
        <cfset var genericMessage = "If an account exists for that email, we sent a password reset link.">
        <cfset var email = "">
        <cfset var qUser = "">
        <cfset var token = "">
        <cfset var tokenHash = "">
        <cfset var resetUrl = "">
        <cfset var emailResult = {}>
        <cfset var tokenStr = "">
        <cfset var newPassword = "">
        <cfset var qReset = "">
        <cfset var newHash = "">
        <cfset request.fpwResetRateTickets=[]>
        <cfset request.fpwResetRateOutcome="error">

        <cftry>
            <cfset httpData = getHttpRequestData()>
            <cfset rawBody = toString(httpData.content)>

            <cfif len(trim(rawBody))>
                <cfset body = deserializeJSON(rawBody, false)>
            </cfif>

            <cfset action = lcase(trim(body.action ?: ""))>

            <cfset var guard = createObject("component",componentPath("api.v1.AuthRequestGuardService"))>
            <cfset var permission = guard.validateMutation(body)>
            <cfif NOT permission.ALLOWED>
                <cfheader statuscode="#permission.STATUSCODE#">
                <cfset sendResponse({SUCCESS=false,ERROR=permission.CODE,MESSAGE=permission.MESSAGE})>
            </cfif>
            <cfset var limiter = createObject("component",componentPath("api.v1.AuthRateLimitService")).init("fpw")>
            <cfif listFind("validate,confirm",action)><cfset request.fpwResetRateOutcome="failure"></cfif>
            <cfif listFind("request,validate,confirm",action)>
                <cfset var admission = limiter.admit(action EQ "request" ? "reset_request" : "reset_confirm",
                    action EQ "request" ? lcase(trim(toString(body.email ?: ""))) : "", guard.getClientIp())>
                <cfif NOT admission.ALLOWED>
                    <cfheader statuscode="#admission.STATUSCODE#">
                    <cfif structKeyExists(admission,"RETRYAFTER")><cfheader name="Retry-After" value="#admission.RETRYAFTER#"></cfif>
                    <cfset sendResponse({SUCCESS=false,ERROR=admission.CODE,MESSAGE=admission.MESSAGE})>
                </cfif>
                <cfset arrayAppend(request.fpwResetRateTickets,admission.TICKET)>
            </cfif>


            <cfif NOT len(action)>
                <cfset sendResponse({
                    SUCCESS = false,
                    ERROR = "MISSING_ACTION",
                    MESSAGE = "Missing action."
                })>
            </cfif>

            <!-- ===================== -->
            <!-- ACTION: REQUEST RESET -->
            <!-- ===================== -->
            <cfif action EQ "request">
                <cfset email = lcase(trim(body.email ?: ""))>

                <cfif NOT len(email) OR NOT isValid("email", email)>
                    <cfset sendResponse({
                        SUCCESS = true,
                        MESSAGE = genericMessage
                    })>
                </cfif>

                <cfquery name="qUser" datasource="fpw">
                    SELECT userId, email
                    FROM users
                    WHERE LOWER(email) = LOWER(<cfqueryparam cfsqltype="cf_sql_varchar" value="#email#">)
                    LIMIT 1
                </cfquery>

                <cfif qUser.recordCount EQ 1>
                    <cfset token = generatePasswordResetToken()>
                    <cfset tokenHash = hashPasswordResetToken(token)>
                    <cfset resetUrl = buildPasswordResetUrl(token)>
                    <cfset var continuationEntry=createObject("component",componentPath("includes.AuthContinuationService")).getIntent(toString(body.intentToken ?: ""))>
                    <cfif NOT structIsEmpty(continuationEntry)>
                        <cfset resetUrl &= "&continuationToken=" & continuationEntry.token>
                    </cfif>

                    <cfquery datasource="fpw">
                        UPDATE users
                        SET
                            resetTokenHash = <cfqueryparam cfsqltype="cf_sql_char" value="#tokenHash#">,
                            resetRequestedAt = <cfqueryparam cfsqltype="cf_sql_timestamp" value="#now()#">,
                            resetExpiresAt = <cfqueryparam cfsqltype="cf_sql_timestamp" value="#dateAdd('n', 60, now())#">,
                            requestReset = NULL,
                            resetId = NULL,
                            lastUpdate = <cfqueryparam cfsqltype="cf_sql_timestamp" value="#now()#">
                        WHERE userId = <cfqueryparam cfsqltype="cf_sql_integer" value="#qUser.userId#">
                    </cfquery>

                    <cfset emailResult = sendPasswordResetEmail(
                        userId = qUser.userId,
                        toEmail = qUser.email,
                        resetUrl = resetUrl
                    )>
                </cfif>

                <cfset sendResponse({
                    SUCCESS = true,
                    MESSAGE = genericMessage
                })>

            <!-- ===================== -->
            <!-- ACTION: VALIDATE RESET -->
            <!-- ===================== -->
            <cfelseif action EQ "validate">
                <cfset tokenStr = trim(body.token ?: "")>

                <cfif NOT len(tokenStr)>
                    <cfset sendResponse({
                        SUCCESS = false,
                        ERROR = "INVALID_OR_EXPIRED_LINK",
                        MESSAGE = "This reset link is invalid or has expired. Please request a new password reset."
                    })>
                </cfif>

                <cfset qReset = findActiveResetToken(tokenStr)>

                <cfif qReset.recordCount EQ 0>
                    <cfset sendResponse({
                        SUCCESS = false,
                        ERROR = "INVALID_OR_EXPIRED_LINK",
                        MESSAGE = "This reset link is invalid or has expired. Please request a new password reset."
                    })>
                </cfif>

                <cfset request.fpwResetRateOutcome="success">
                <cfset sendResponse({
                    SUCCESS = true,
                    MESSAGE = "Reset link is valid."
                })>

            <!-- ===================== -->
            <!-- ACTION: CONFIRM RESET -->
            <!-- ===================== -->
            <cfelseif action EQ "confirm">
                <cfset tokenStr = trim(body.token ?: "")>
                <cfset newPassword = trim(body.newPassword ?: "")>

                <cfif NOT len(tokenStr) OR NOT len(newPassword)>
                    <cfset sendResponse({
                        SUCCESS = false,
                        ERROR = "MISSING_FIELDS",
                        MESSAGE = "This reset link is invalid or has expired. Please request a new password reset."
                    })>
                </cfif>

                <cfif len(newPassword) LT 8>
                    <cfset sendResponse({
                        SUCCESS = false,
                        ERROR = "WEAK_PASSWORD",
                        MESSAGE = "Password must be at least 8 characters."
                    })>
                </cfif>

                <cfset qReset = findActiveResetToken(tokenStr)>

                <cfif qReset.recordCount EQ 0>
                    <cfset sendResponse({
                        SUCCESS = false,
                        ERROR = "INVALID_OR_EXPIRED_LINK",
                        MESSAGE = "This reset link is invalid or has expired. Please request a new password reset."
                    })>
                </cfif>

                <cfset var accountAdmission = limiter.admit("reset_confirm",lcase(trim(qReset.email[1])),guard.getClientIp(),false)>
                <cfif NOT accountAdmission.ALLOWED>
                    <cfheader statuscode="#accountAdmission.STATUSCODE#">
                    <cfif structKeyExists(accountAdmission,"RETRYAFTER")><cfheader name="Retry-After" value="#accountAdmission.RETRYAFTER#"></cfif>
                    <cfset sendResponse({SUCCESS=false,ERROR=accountAdmission.CODE,MESSAGE=accountAdmission.MESSAGE})>
                </cfif>
                <cfset arrayAppend(request.fpwResetRateTickets,accountAdmission.TICKET)>
                <cfset newHash = createObject("component",componentPath("api.v1.PasswordHashService")).hashPassword(newPassword)>

                <cfquery datasource="fpw" result="local.resetUpdateResult">
                    UPDATE users
                    SET
                        password = <cfqueryparam cfsqltype="cf_sql_varchar" value="#newHash#">,
                        passwordCreated = <cfqueryparam cfsqltype="cf_sql_timestamp" value="#now()#">,
                        resetTokenHash = NULL,
                        resetRequestedAt = NULL,
                        resetExpiresAt = NULL,
                        requestReset = NULL,
                        resetId = NULL,
                        lastUpdate = <cfqueryparam cfsqltype="cf_sql_timestamp" value="#now()#">
                    WHERE userId = <cfqueryparam cfsqltype="cf_sql_integer" value="#qReset.userId#">
                      AND resetTokenHash = <cfqueryparam cfsqltype="cf_sql_char" value="#hashPasswordResetToken(tokenStr)#">
                      AND resetExpiresAt >= <cfqueryparam cfsqltype="cf_sql_timestamp" value="#now()#">
                </cfquery>
                <cfif local.resetUpdateResult.recordCount NEQ 1>
                    <cfset sendResponse({SUCCESS=false,ERROR="INVALID_OR_EXPIRED_LINK",MESSAGE="This reset link is invalid or has expired. Please request a new password reset."})>
                </cfif>
                <cfset request.fpwResetRateOutcome="success">

                <cfset sendResponse({
                    SUCCESS = true,
                    MESSAGE = "Your password has been reset. You can now sign in."
                })>

            <cfelse>
                <cfset sendResponse({
                    SUCCESS = false,
                    ERROR = "INVALID_ACTION",
                    MESSAGE = "Invalid action."
                })>
            </cfif>

            <cfcatch type="any">
                <cfset request.fpwResetRateOutcome="error">
                <cflog
                    file="fpw_password_reset"
                    type="error"
                    text="password_reset.cfc SERVER_ERROR">
                <cfset sendResponse({
                    SUCCESS = false,
                    ERROR = "SERVER_ERROR",
                    MESSAGE = "We could not process that password reset request right now."
                })>
            </cfcatch>
        </cftry>

        <cfsetting enablecfoutputonly="false">
    </cffunction>

    <cffunction name="findActiveResetToken" access="private" returntype="query" output="false">
        <cfargument name="token" type="string" required="true">

        <cfset var tokenHash = hashPasswordResetToken(arguments.token)>
        <cfset var qToken = "">

        <cfquery name="qToken" datasource="fpw">
            SELECT userId, email
            FROM users
            WHERE resetTokenHash = <cfqueryparam cfsqltype="cf_sql_char" value="#tokenHash#">
              AND resetExpiresAt IS NOT NULL
              AND resetExpiresAt >= <cfqueryparam cfsqltype="cf_sql_timestamp" value="#now()#">
            LIMIT 1
        </cfquery>

        <cfreturn qToken>
    </cffunction>

    <cffunction name="generatePasswordResetToken" access="private" returntype="string" output="false">
        <cfset var tokenValue = generateSecretKey("AES", 256)>

        <cfset tokenValue = replace(tokenValue, "+", "-", "all")>
        <cfset tokenValue = replace(tokenValue, "/", "_", "all")>
        <cfset tokenValue = reReplace(tokenValue, "=+$", "", "all")>

        <cfreturn tokenValue>
    </cffunction>

    <cffunction name="hashPasswordResetToken" access="private" returntype="string" output="false">
        <cfargument name="token" type="string" required="true">

        <cfreturn ucase(hash(trim(arguments.token), "SHA-256", "UTF-8"))>
    </cffunction>

    <cffunction name="buildPasswordResetUrl" access="private" returntype="string" output="false">
        <cfargument name="token" type="string" required="true">

        <cfreturn resolvePublicBaseUrl("https://floatplanwizard.com") & "/app/reset-password.cfm?token=" & encodeForURL(arguments.token)>
    </cffunction>

    <cffunction name="resolvePublicBaseUrl" access="private" returntype="string" output="false">
        <cfargument name="fallbackBaseUrl" type="string" required="true">
        <cfset var emailService = "">
        <cftry>
            <cfset emailService = createObject("component", "api.v1.email").init()>
            <cfcatch type="any">
                <cfset emailService = createObject("component", "fpw.api.v1.email").init()>
            </cfcatch>
        </cftry>
        <cfreturn emailService.getPublicBaseUrl()>
    </cffunction>

    <cffunction name="sendPasswordResetEmail" access="private" returntype="struct" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="toEmail" type="string" required="true">
        <cfargument name="resetUrl" type="string" required="true">

        <cfset var emailService = "">

        <cftry>
            <cfset emailService = createObject("component", "api.v1.email").init()>
            <cfcatch type="any">
                <cfset emailService = createObject("component", "fpw.api.v1.email").init()>
            </cfcatch>
        </cftry>

        <cfreturn emailService.sendPasswordResetEmail(
            userId = arguments.userId,
            toEmail = arguments.toEmail,
            resetUrl = arguments.resetUrl,
            expiresMinutes = 60
        )>
    </cffunction>

    <cffunction name="cleanLogValue" access="private" returntype="string" output="false">
        <cfargument name="value" type="string" required="false" default="">

        <cfreturn left(reReplace(trim(arguments.value), "[\r\n\t]+", " ", "all"), 300)>
    </cffunction>

<cfscript>
  private string function componentPath(required string relativePath) {
    var prefix=reReplaceNoCase(getMetadata(this).name,"(^|[.])api[.]v1[.][^.]+$","");
    return (len(prefix) ? prefix & "." : "") & arguments.relativePath;
  }
</cfscript>
</cfcomponent>
