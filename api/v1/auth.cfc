<cfcomponent output="false">

    <cffunction name="handle" access="remote" returntype="string" output="true">
        <cfsetting enablecfoutputonly="true" showdebugoutput="false">
        <cfcontent type="application/json; charset=utf-8">
        <cfheader name="Cache-Control" value="no-store, no-cache, must-revalidate">

        <cftry>

            <!-- Read request body -->
            <cfset httpData = getHttpRequestData()>
            <cfset rawBody  = toString( httpData.content )>
            <cfset body     = {}>

            <cfif len( trim( rawBody ) )>
                <cfset body = deserializeJSON( rawBody, false )>
            </cfif>

            <!-- Fallback to FORM fields -->
            <cfif NOT structKeyExists( body, "email" ) AND structKeyExists( form, "email" )>
                <cfset body.email = form.email>
            </cfif>
            <cfif NOT structKeyExists( body, "password" ) AND structKeyExists( form, "password" )>
                <cfset body.password = form.password>
            </cfif>
            <cfif NOT structKeyExists( body, "action" ) AND structKeyExists( form, "action" )>
                <cfset body.action = form.action>
            </cfif>

            <cfset email    = trim( body.email    ?: "" )>
            <cfset password = trim( body.password ?: "" )>
            <cfset action   = lcase( trim( body.action ?: "" ) )>

            <cfset response = {}>

            <!-- ===================== -->
            <!-- LOGOUT                -->
            <!-- ===================== -->
            <cfif action EQ "logout">
                <cfset sessionInvalidate()>
                <cfset response = {
                    SUCCESS = true,
                    MESSAGE = "Logged out"
                }>

            <!-- ===================== -->
            <!-- LOGIN                 -->
            <!-- ===================== -->
            <cfelse>

                <!-- Basic input check -->
                <cfif NOT len( email ) OR NOT len( password )>
                    <cfset response = {
                        SUCCESS = false,
                        MESSAGE = "Email and password are required.",
                        ERROR   = "MISSING_CREDENTIALS"
                    }>
                    <cfoutput>#serializeJSON( response )#</cfoutput>
                    <cfsetting enablecfoutputonly="false">
                    <cfabort>
                </cfif>

                <!-- Look up user by email (case-insensitive) -->
                <cfquery name="qUser" datasource="fpw">
                    SELECT
                        userId,
                        fName,
                        lName,
                        email,
                        password AS dbPassword,
                        lastLogin,
                        mobilePhone
                    FROM users
                    WHERE LOWER(email) = LOWER(
                        <cfqueryparam cfsqltype="cf_sql_varchar" value="#email#">
                    )
                    LIMIT 1
                </cfquery>

                <cfif qUser.recordCount EQ 0>
                    <cfset response = {
                        SUCCESS = false,
                        MESSAGE = "Invalid email or password.",
                        ERROR   = "INVALID_LOGIN"
                    }>
                   <cfset response = serializeJSON( response )>
                    <cfreturn response>
                    
                </cfif>

                <!-- Verify password through the canonical adaptive/legacy migration contract -->
                <cfset dbPassword = qUser.dbPassword>
                <cftry>
                    <cfset passwordService = createObject("component", "fpw.api.v1.PasswordHashService").init()>
                    <cfcatch type="any">
                        <cfset passwordService = createObject("component", "api.v1.PasswordHashService").init()>
                    </cfcatch>
                </cftry>
                <cfset passwordVerified = passwordService.verifyPassword(password, dbPassword)>

                <cfif NOT passwordVerified>
                    <cfset response = {
                        SUCCESS = false,
                        MESSAGE = "Invalid email or password.",
                        ERROR   = "INVALID_LOGIN"
                    }>
                    <cfset response = serializeJSON( response )>
                    <cfreturn response>
                </cfif>

                <!-- Upgrade recognized legacy SHA-256 or outdated adaptive work factors before login completes -->
                <cfif passwordService.needsRehash(dbPassword)>
                    <cfset upgradedPassword = passwordService.hashPassword(password)>
                    <cfquery datasource="fpw" result="passwordUpgradeResult">
                        UPDATE users
                        SET
                            password = <cfqueryparam cfsqltype="cf_sql_varchar" value="#upgradedPassword#">,
                            passwordCreated = <cfqueryparam cfsqltype="cf_sql_timestamp" value="#now()#">,
                            lastUpdate = <cfqueryparam cfsqltype="cf_sql_timestamp" value="#now()#">
                        WHERE userId = <cfqueryparam cfsqltype="cf_sql_integer" value="#qUser.userId#">
                          AND password = <cfqueryparam cfsqltype="cf_sql_varchar" value="#dbPassword#">
                    </cfquery>
                    <cfif NOT structKeyExists(passwordUpgradeResult, "recordCount") OR val(passwordUpgradeResult.recordCount) NEQ 1>
                        <cfthrow
                            type="FPW.PasswordHash.UpgradeFailed"
                            message="Password hash upgrade did not update exactly one user.">
                    </cfif>
                </cfif>

                <!-- Update lastLogin -->
                <cfquery datasource="fpw">
                    UPDATE users
                    SET lastLogin = <cfqueryparam cfsqltype="cf_sql_timestamp" value="#now()#">
                    WHERE userId = <cfqueryparam cfsqltype="cf_sql_integer" value="#qUser.userId#">
                </cfquery>

                <!-- Normalize user struct for session + JSON -->
                <cfset firstNameVal = qUser.fName ?: "">
                <cfset lastNameVal  = qUser.lName ?: "">

                <cfset sessionRotate()>
                <cfset session.user = {
                    id          = qUser.userId,
                    userId      = qUser.userId,
                    USERID      = qUser.userId,

                    email       = qUser.email,
                    EMAIL       = qUser.email,

                    firstName   = firstNameVal,
                    FIRSTNAME   = firstNameVal,

                    lastName    = lastNameVal,
                    LASTNAME    = lastNameVal,

                    mobilePhone = qUser.mobilePhone,
                    MOBILEPHONE = qUser.mobilePhone,

                    lastLogin   = qUser.lastLogin,
                    LASTLOGIN   = qUser.lastLogin
                }>

                <cftry>
                    <cfset createObject("component", "fpw.includes.ProductEventService").init("fpw").recordEvent(
                        userId = qUser.userId,
                        eventName = "login",
                        entityType = "user",
                        entityId = qUser.userId,
                        eventSource = "password_auth",
                        metadata = {
                            auth_method = "password"
                        },
                        idempotencyKey = "login:request:" & (structKeyExists(request, "fpwRequestId") ? toString(request.fpwRequestId) : createUUID()),
                        requestCorrelationId = structKeyExists(request, "fpwRequestId") ? toString(request.fpwRequestId) : ""
                    )>
                <cfcatch type="any">
                    <cflog file="fpw_product_events" type="error" text="auth.cfc PRODUCT_EVENT_CALL_FAILED | event=login">
                </cfcatch>
                </cftry>

                <cfset response = {
                    SUCCESS = true,
                    MESSAGE = "Login successful",
                    USER    = session.user
                }>

            </cfif>
            <cfset response = serializeJSON( response )>
            <cfoutput>#response#</cfoutput>
            <cfsetting enablecfoutputonly="false">
            <cfabort>
            

            <cfcatch type="any">
                <cfset errResponse = {
                    SUCCESS = false,
                    MESSAGE = "Server error during login",
                    ERROR   = "SERVER_ERROR",
                    DETAIL  = "An unexpected error occurred."
                }>
                <cfset response = serializeJSON( errResponse )>
                <cfoutput>#response#</cfoutput>
                <cfsetting enablecfoutputonly="false">
                <cfabort>
            </cfcatch>

        </cftry>

        <cfsetting enablecfoutputonly="false">
    </cffunction>

</cfcomponent>
