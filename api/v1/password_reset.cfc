<cfcomponent output="false">

    <cffunction name="sendResponse" access="private" returntype="void" output="true">
        <cfargument name="payload" type="struct" required="true">
        <cfargument name="buildStamp" type="string" required="true">
        <cfset arguments.payload.BUILD = arguments.buildStamp>
        <cfoutput>#serializeJSON(arguments.payload)#</cfoutput>
        <cfabort>
    </cffunction>

    <cffunction name="handle" access="remote" returntype="void" output="true">
        <cfsetting enablecfoutputonly="true" showdebugoutput="false">
        <cfcontent type="application/json; charset=utf-8">
        <cfheader name="Cache-Control" value="no-store, no-cache, must-revalidate">
        <cfheader name="Pragma" value="no-cache">
        <cfheader name="Expires" value="0">

        <cftry>

            <!-- Build stamp so you can confirm you're hitting THIS file -->
            <cfset buildStamp = "PWRESET_BUILD_2025-12-12_A">

            <!-- Read request body JSON -->
            <cfset httpData = getHttpRequestData()>
            <cfset rawBody  = toString(httpData.content)>
            <cfset body     = {}>

            <cfif len(trim(rawBody))>
                <cfset body = deserializeJSON(rawBody, false)>
            </cfif>

            <cfset action = lcase(trim(body.action ?: ""))>

            <cfif NOT len(action)>
                <cfset sendResponse({
                    SUCCESS = false,
                    ERROR   = "MISSING_ACTION",
                    MESSAGE = "Missing action."
                }, buildStamp)>
            </cfif>

            <!-- epoch seconds (INT) -->
            <cfset nowEpoch = int(getTickCount()/1000)>

            <!-- ===================== -->
            <!-- ACTION: REQUEST RESET -->
            <!-- ===================== -->
            <cfif action EQ "request">

                <cfset email = trim(body.email ?: "")>

                <cfif NOT len(email)>
                    <cfset sendResponse({ SUCCESS=false, ERROR="MISSING_EMAIL", MESSAGE="Email is required." }, buildStamp)>
                </cfif>

                <!-- Look up userId (case-insensitive) -->
                <cfquery name="qUser" datasource="fpw">
                    SELECT userId
                    FROM users
                    WHERE LOWER(email) = LOWER(<cfqueryparam cfsqltype="cf_sql_varchar" value="#email#">)
                    LIMIT 1
                </cfquery>

                <!-- Always respond SUCCESS to prevent user enumeration -->
                <cfset token = 0>

                <cfif qUser.recordCount EQ 1>

                    <!-- generate unique 9-digit numeric token (fits INT) -->
                    <cfset tries = 0>
                    <cfloop condition="token EQ 0 AND tries LT 20">
                        <cfset tries = tries + 1>
                        <cfset candidate = randRange(100000000, 999999999)>

                        <cfquery name="qTok" datasource="fpw">
                            SELECT userId
                            FROM users
                            WHERE resetId = <cfqueryparam cfsqltype="cf_sql_integer" value="#candidate#">
                            LIMIT 1
                        </cfquery>

                        <cfif qTok.recordCount EQ 0>
                            <cfset token = candidate>
                        </cfif>
                    </cfloop>

                    <!-- If we somehow didn't get unique token, fall back -->
                    <cfif token EQ 0>
                        <cfset token = randRange(100000000, 999999999)>
                    </cfif>

                    <!-- Store token + request time (epoch seconds) -->
                    <cfquery datasource="fpw">
                        UPDATE users
                        SET
                            requestReset = <cfqueryparam cfsqltype="cf_sql_integer" value="#nowEpoch#">,
                            resetId      = <cfqueryparam cfsqltype="cf_sql_integer" value="#token#">,
                            lastUpdate   = <cfqueryparam cfsqltype="cf_sql_timestamp" value="#now()#">
                        WHERE userId = <cfqueryparam cfsqltype="cf_sql_integer" value="#qUser.userId#">
                    </cfquery>

                </cfif>

                <!-- Dev helper: if user not found, still provide a dummy token+url -->
                <cfif token EQ 0>
                    <cfset token = randRange(100000000, 999999999)>
                </cfif>

                <cfset resetUrl = "/fpw/app/reset-password.cfm?token=" & token>

                <cfset sendResponse({
                    SUCCESS   = true,
                    MESSAGE   = "If that email exists, we sent password reset instructions.",
                    TOKEN     = token,
                    RESET_URL = resetUrl
                }, buildStamp)>

            <!-- ===================== -->
            <!-- ACTION: CONFIRM RESET -->
            <!-- ===================== -->
            <cfelseif action EQ "confirm">

                <cfset tokenStr    = trim(body.token ?: "")>
                <cfset newPassword = trim(body.newPassword ?: "")>

                <cfif NOT len(tokenStr) OR NOT len(newPassword)>
                    <cfset sendResponse({ SUCCESS=false, ERROR="MISSING_FIELDS", MESSAGE="token and newPassword are required." }, buildStamp)>
                </cfif>

                <cfif NOT isNumeric(tokenStr)>
                    <cfset sendResponse({ SUCCESS=false, ERROR="INVALID_TOKEN", MESSAGE="Reset link is invalid or expired." }, buildStamp)>
                </cfif>

                <cfif len(newPassword) LT 8>
                    <cfset sendResponse({ SUCCESS=false, ERROR="WEAK_PASSWORD", MESSAGE="Password must be at least 8 characters." }, buildStamp)>
                </cfif>

                <cfset token = int(tokenStr)>

                <!-- Find token -->
                <cfquery name="qReset" datasource="fpw">
                    SELECT userId, requestReset
                    FROM users
                    WHERE resetId = <cfqueryparam cfsqltype="cf_sql_integer" value="#token#">
                    LIMIT 1
                </cfquery>

                <cfif qReset.recordCount EQ 0>
                    <cfset sendResponse({ SUCCESS=false, ERROR="INVALID_TOKEN", MESSAGE="Reset link is invalid or expired." }, buildStamp)>
                </cfif>

                <!-- Expiration window: 2 hours -->
                <cfset expiresSeconds = 2 * 60 * 60>
                <cfset reqEpoch = val(qReset.requestReset)>

                <cfif reqEpoch LTE 0 OR (nowEpoch - reqEpoch) GT expiresSeconds>
                    <cfset sendResponse({ SUCCESS=false, ERROR="EXPIRED_TOKEN", MESSAGE="Reset link has expired. Please request a new one." }, buildStamp)>
                </cfif>

                <!-- Store new password (SHA-256 uppercase hex to match your current approach) -->
                <cfset newHash = ucase(hash(newPassword, "SHA-256", "UTF-8"))>

                <cfquery datasource="fpw">
                    UPDATE users
                    SET
                        password        = <cfqueryparam cfsqltype="cf_sql_varchar" value="#newHash#">,
                        passwordCreated = <cfqueryparam cfsqltype="cf_sql_timestamp" value="#now()#">,
                        requestReset    = NULL,
                        resetId         = NULL,
                        lastUpdate      = <cfqueryparam cfsqltype="cf_sql_timestamp" value="#now()#">
                    WHERE userId = <cfqueryparam cfsqltype="cf_sql_integer" value="#qReset.userId#">
                </cfquery>

                <cfset sendResponse({ SUCCESS=true, MESSAGE="Password updated. You can now sign in." }, buildStamp)>

            <cfelse>
                <cfset sendResponse({ SUCCESS=false, ERROR="INVALID_ACTION", MESSAGE="Invalid action." }, buildStamp)>
            </cfif>

            <cfcatch type="any">
                <cfoutput>#serializeJSON({
                    SUCCESS = false,
                    ERROR   = "SERVER_ERROR",
                    MESSAGE = "Password reset API error.",
                    DETAIL  = cfcatch.message,
                    DBDETAIL= (structKeyExists(cfcatch, "detail") ? cfcatch.detail : ""),
                    BUILD   = "PWRESET_BUILD_2025-12-12_A"
                })#</cfoutput>
            </cfcatch>

        </cftry>

        <cfsetting enablecfoutputonly="false">
    </cffunction>

</cfcomponent>
