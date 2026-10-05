<cfcomponent output="false">

    <cffunction name="handle" access="remote" returntype="void" output="true">
        <cfargument name="action" type="string" required="false" default="">
        <cfsetting enablecfoutputonly="true" showdebugoutput="false">
        <cfcontent type="application/json; charset=utf-8">
        <cfheader name="Cache-Control" value="no-store, no-cache, must-revalidate">

        <cftry>

            <!-- Must be logged in -->
            <cfif NOT structKeyExists(session, "user") OR NOT isStruct(session.user)>
                <cfset response = {
                    SUCCESS = false,
                    AUTH    = false,
                    ERROR   = "NOT_LOGGED_IN",
                    MESSAGE = "Not logged in."
                }>
                <cfoutput>#serializeJSON(response)#</cfoutput>
                <cfsetting enablecfoutputonly="false">
                <cfabort>
            </cfif>

            <!-- Resolve userId from session -->
            <cfset userId = 0>
            <cfif structKeyExists(session.user, "userId")>
                <cfset userId = session.user.userId>
            <cfelseif structKeyExists(session.user, "id")>
                <cfset userId = session.user.id>
            <cfelseif structKeyExists(session.user, "USERID")>
                <cfset userId = session.user.USERID>
            </cfif>

            <cfif NOT isNumeric(userId) OR userId LTE 0>
                <cfset response = {
                    SUCCESS = false,
                    AUTH    = false,
                    ERROR   = "INVALID_SESSION",
                    MESSAGE = "Session user is invalid."
                }>
                <cfoutput>#serializeJSON(response)#</cfoutput>
                <cfsetting enablecfoutputonly="false">
                <cfabort>
            </cfif>

            <!-- Read JSON body (for POST) -->
            <cfset httpData = getHttpRequestData()>
            <cfset rawBody  = toString(httpData.content)>
            <cfset body     = {}>

            <cfif len(trim(rawBody))>
                <cfset body = deserializeJSON(rawBody, false)>
            </cfif>

            <cfif NOT isStruct(body)>
                <cfheader statuscode="400">
                <cfoutput>#serializeJSON({SUCCESS=false, AUTH=true, ERROR="INVALID_BODY", MESSAGE="A JSON object is required."})#</cfoutput>
                <cfsetting enablecfoutputonly="false">
                <cfabort>
            </cfif>

            <!-- action can come from URL or body; default = "get" -->
            <cfset action = "get">
            <cfif structKeyExists(url, "action") AND len(trim(url.action))>
                <cfset action = lcase(trim(url.action))>
            <cfelseif structKeyExists(body, "action") AND len(trim(body.action))>
                <cfset action = lcase(trim(body.action))>
            </cfif>

            <cfset requestGuard = createObject("component", reReplace(getMetadata(this).name, "\.[^.]+$", ".AuthRequestGuardService"))>
            <cfif listFindNoCase("update,update-name,changepassword,update-email-preferences", action)>
                <cfset mutationCheck = requestGuard.validateMutation(body)>
                <cfif NOT mutationCheck.ALLOWED>
                    <cfheader statuscode="#mutationCheck.STATUSCODE#">
                    <cfoutput>#serializeJSON({SUCCESS=false, AUTH=true, ERROR=mutationCheck.CODE, MESSAGE=mutationCheck.MESSAGE})#</cfoutput>
                    <cfsetting enablecfoutputonly="false">
                    <cfabort>
                </cfif>
            </cfif>

            <!-- Optional email preferences use the authenticated member's current DB address only. -->
            <cfif action EQ "email-preferences" OR action EQ "update-email-preferences">
                <cfif action EQ "update-email-preferences">
                    <cfset preferenceBodyValid = structKeyExists(body, "optionalEmailsEnabled")>
                    <cfloop collection="#body#" item="preferenceKey">
                        <cfif NOT listFindNoCase("action,csrfToken,optionalEmailsEnabled", preferenceKey)>
                            <cfset preferenceBodyValid = false>
                        </cfif>
                    </cfloop>
                    <cfif preferenceBodyValid>
                        <cfset preferenceBodyValid = isSimpleValue(body.optionalEmailsEnabled)
                            AND listFind("true,false", serializeJSON(body.optionalEmailsEnabled)) GT 0>
                    </cfif>
                    <cfif NOT preferenceBodyValid>
                        <cfheader statuscode="400">
                        <cfoutput>#serializeJSON({SUCCESS=false, AUTH=true, ERROR="INVALID_EMAIL_PREFERENCE", MESSAGE="Choose whether optional emails are on or off."})#</cfoutput>
                        <cfsetting enablecfoutputonly="false"><cfabort>
                    </cfif>
                </cfif>
                <cftry>
                    <cfset preferenceService = createObject("component", reReplace(getMetadata(this).name, "\.[^.]+$", ".EmailOptOutService")).init(datasource="fpw")>
                    <cfif action EQ "update-email-preferences">
                        <cfset preferenceResult = preferenceService.setMemberOptionalEmailPreference(
                            userId = userId, enabled = body.optionalEmailsEnabled,
                            ipAddress = requestGuard.getClientIp(),
                            userAgent = structKeyExists(cgi, "http_user_agent") ? toString(cgi.http_user_agent) : ""
                        )>
                    <cfelse>
                        <cfset preferenceResult = preferenceService.getMemberOptionalEmailPreference(userId)>
                    </cfif>
                    <cfif NOT preferenceResult.success>
                        <cfthrow type="fpw.emailOptOut.PreferenceUnavailable" message="Email preferences unavailable.">
                    </cfif>
                    <cfoutput>#serializeJSON({SUCCESS=true, AUTH=true, EMAIL_PREFERENCES={optionalEmailsEnabled=preferenceResult.optionalEmailsEnabled}})#</cfoutput>
                    <cfcatch type="any">
                        <cfheader statuscode="503">
                        <cfoutput>#serializeJSON({SUCCESS=false, AUTH=true, ERROR="EMAIL_PREFERENCES_UNAVAILABLE", MESSAGE="Unable to load or save email preferences. Please try again."})#</cfoutput>
                    </cfcatch>
                </cftry>
                <cfsetting enablecfoutputonly="false"><cfabort>
            </cfif>

            <!-- Names-only wizard updates must not erase phone or other profile/session fields. -->
            <cfif action EQ "name" OR action EQ "update-name">
                <cfif action EQ "update-name">
                    <cfif (structKeyExists(body, "fName") AND NOT isSimpleValue(body.fName)) OR (structKeyExists(body, "lName") AND NOT isSimpleValue(body.lName))>
                        <cfheader statuscode="400">
                        <cfoutput>#serializeJSON({SUCCESS=false, AUTH=true, ERROR="INVALID_NAME", MESSAGE="Name fields must contain text."})#</cfoutput>
                        <cfsetting enablecfoutputonly="false">
                        <cfabort>
                    </cfif>
                    <cfset newFName = trim(toString(body.fName ?: ""))>
                    <cfset newLName = trim(toString(body.lName ?: ""))>
                    <cfif (NOT len(newFName) AND NOT len(newLName)) OR len(newFName) GT 45 OR len(newLName) GT 45>
                        <cfheader statuscode="400">
                        <cfoutput>#serializeJSON({SUCCESS=false, AUTH=true, ERROR="PROFILE_NAME_REQUIRED", MESSAGE="Enter your first or last name, using no more than 45 characters in each field."})#</cfoutput>
                        <cfsetting enablecfoutputonly="false">
                        <cfabort>
                    </cfif>
                    <cfquery datasource="fpw">
                        UPDATE users SET
                            fName = <cfqueryparam cfsqltype="cf_sql_varchar" value="#newFName#" null="#NOT len(newFName)#">,
                            lName = <cfqueryparam cfsqltype="cf_sql_varchar" value="#newLName#" null="#NOT len(newLName)#">,
                            lastUpdate = <cfqueryparam cfsqltype="cf_sql_timestamp" value="#now()#">
                        WHERE userId = <cfqueryparam cfsqltype="cf_sql_integer" value="#userId#">
                    </cfquery>
                </cfif>
                <cfset memberName = readMemberName(userId)>
                <cfset session.user.firstName = memberName.fName>
                <cfset session.user.lastName = memberName.lName>
                <cfset session.user.fName = memberName.fName>
                <cfset session.user.lName = memberName.lName>
                <cfset session.user.displayName = memberName.displayName>
                <cfif structKeyExists(session.user, "fullName")><cfset session.user.fullName = memberName.displayName></cfif>
                <cfif structKeyExists(session.user, "name")><cfset session.user.name = memberName.displayName></cfif>
                <cfoutput>#serializeJSON({SUCCESS=true, AUTH=true, PROFILE=memberName})#</cfoutput>
                <cfsetting enablecfoutputonly="false">
                <cfabort>
            </cfif>

            <!-- ========================= -->
            <!-- ACTION: UPDATE PROFILE    -->
            <!-- ========================= -->
            <cfif action EQ "update">

                <cfset newFName = trim(body.fName ?: body.firstName ?: "")>
                <cfset newLName = trim(body.lName ?: body.lastName  ?: "")>
                <cfset newMobile = trim(body.mobilePhone ?: "")>
                <cfset phoneValidation = normalizeOptionalUsPhone(newMobile)>

                <cfif NOT phoneValidation.valid>
                    <cfset response = {
                        SUCCESS = false,
                        AUTH    = true,
                        ERROR   = "INVALID_PHONE",
                        MESSAGE = "Please enter a valid US phone number or leave the phone field blank."
                    }>
                    <cfoutput>#serializeJSON(response)#</cfoutput>
                    <cfsetting enablecfoutputonly="false">
                    <cfabort>
                </cfif>

                <cfset newMobile = phoneValidation.value>

                <!-- Update allowed fields only -->
                <cfquery datasource="fpw">
                    UPDATE users
                    SET
                        fName       = <cfqueryparam cfsqltype="cf_sql_varchar" value="#newFName#" null="#NOT len(newFName)#">,
                        lName       = <cfqueryparam cfsqltype="cf_sql_varchar" value="#newLName#" null="#NOT len(newLName)#">,
                        mobilePhone = <cfqueryparam cfsqltype="cf_sql_varchar" value="#newMobile#" null="#NOT len(newMobile)#">,
                        lastUpdate  = <cfqueryparam cfsqltype="cf_sql_timestamp" value="#now()#">
                    WHERE userId = <cfqueryparam cfsqltype="cf_sql_integer" value="#userId#">
                </cfquery>

            <!-- ========================= -->
            <!-- ACTION: CHANGE PASSWORD   -->
            <!-- ========================= -->
            <cfelseif action EQ "changepassword">

                <cfset currentPassword = trim(body.currentPassword ?: "")>
                <cfset newPassword     = trim(body.newPassword ?: "")>

                <cfif NOT len(currentPassword) OR NOT len(newPassword)>
                    <cfset response = {
                        SUCCESS = false,
                        ERROR   = "MISSING_FIELDS",
                        MESSAGE = "currentPassword and newPassword are required."
                    }>
                    <cfoutput>#serializeJSON(response)#</cfoutput>
                    <cfsetting enablecfoutputonly="false">
                    <cfabort>
                </cfif>

                <cfif len(newPassword) LT 8>
                    <cfset response = {
                        SUCCESS = false,
                        ERROR   = "WEAK_PASSWORD",
                        MESSAGE = "New password must be at least 8 characters."
                    }>
                    <cfoutput>#serializeJSON(response)#</cfoutput>
                    <cfsetting enablecfoutputonly="false">
                    <cfabort>
                </cfif>

                <cfset passwordResult = changeMemberPassword(userId, currentPassword, newPassword)>
                <cfif NOT passwordResult.SUCCESS>
                    <cfif structKeyExists(passwordResult, "STATUSCODE")><cfheader statuscode="#passwordResult.STATUSCODE#"></cfif>
                    <cfif structKeyExists(passwordResult, "RETRYAFTER")><cfheader name="Retry-After" value="#passwordResult.RETRYAFTER#"></cfif>
                    <cfoutput>#serializeJSON(passwordResult)#</cfoutput>
                    <cfsetting enablecfoutputonly="false">
                    <cfabort>
                </cfif>

            </cfif>

            <!-- ========================= -->
            <!-- ALWAYS RETURN PROFILE     -->
            <!-- ========================= -->

            <cfquery name="qUser" datasource="fpw">
                SELECT
                    userId,
                    fName,
                    lName,
                    email,
                    passwordCreated,
                    lastLogin,
                    lastUpdate,
                    mobilePhone,
                    photoFileId,
                    created
                FROM users
                WHERE userId = <cfqueryparam cfsqltype="cf_sql_integer" value="#userId#">
                LIMIT 1
            </cfquery>

            <!-- Optional: fetch "home port" address -->
            <cfquery name="qHome" datasource="fpw">
                SELECT
                    recId,
                    address,
                    city,
                    state,
                    zip,
                    phone,
                    lat,
                    lng,
                    isHomePort
                FROM users_address
                WHERE userId = <cfqueryparam cfsqltype="cf_sql_integer" value="#userId#">
                  AND isHomePort = 1
                LIMIT 1
            </cfquery>

            <cfset home = {}>

            <cfif qHome.recordCount EQ 1>
                <cfset home = {
                    recId      = qHome.recId,
                    address    = qHome.address,
                    city       = qHome.city,
                    state      = qHome.state,
                    zip        = qHome.zip,
                    phone      = qHome.phone,
                    lat        = qHome.lat,
                    lng        = qHome.lng,
                    isHomePort = qHome.isHomePort
                }>
            </cfif>

            <cfset profile = {}>

            <cfif qUser.recordCount EQ 1>
                <cfset profile = {
                    userId           = qUser.userId,
                    fName            = qUser.fName,
                    lName            = qUser.lName,
                    email            = qUser.email,
                    mobilePhone      = qUser.mobilePhone,
                    photoFileId      = qUser.photoFileId,
                    passwordCreated  = qUser.passwordCreated,
                    lastLogin        = qUser.lastLogin,
                    lastUpdate       = qUser.lastUpdate,
                    created          = qUser.created,
                    homePort         = home
                }>
            </cfif>

            <!-- Keep session.user in sync with updated profile -->
            <cfset session.user = {
                id        = profile.userId,
                userId    = profile.userId,
                USERID    = profile.userId,

                email     = profile.email,
                EMAIL     = profile.email,

                firstName = profile.fName ?: "",
                FIRSTNAME = profile.fName ?: "",

                lastName  = profile.lName ?: "",
                LASTNAME  = profile.lName ?: ""
            }>

            <cfset response = {
                SUCCESS = true,
                AUTH    = true,
                PROFILE = profile
            }>

            <cfoutput>#serializeJSON(response)#</cfoutput>

            <cfcatch type="any">
                <cfset errResponse = {
                    SUCCESS = false,
                    AUTH    = true,
                    ERROR   = "SERVER_ERROR",
                    MESSAGE = "Profile API error.",
                    DETAIL  = cfcatch.message
                }>
                <cfoutput>#serializeJSON(errResponse)#</cfoutput>
            </cfcatch>

        </cftry>

        <cfsetting enablecfoutputonly="false">
    </cffunction>

    <cffunction name="changeMemberPassword" access="private" returntype="struct" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="currentPassword" type="string" required="true">
        <cfargument name="newPassword" type="string" required="true">
        <cfscript>
            var qPassword = queryExecute("SELECT password, email FROM users WHERE userId = :userId LIMIT 1",
                {userId={value=arguments.userId,cfsqltype="cf_sql_integer"}}, {datasource="fpw"});
            if (qPassword.recordCount NEQ 1) return {SUCCESS=false,ERROR="NOT_FOUND",MESSAGE="User not found."};
            var guard = createObject("component", reReplace(getMetadata(this).name, "\.[^.]+$", ".AuthRequestGuardService"));
            var limiter = createObject("component", reReplace(getMetadata(this).name, "\.[^.]+$", ".AuthRateLimitService")).init("fpw");
            var admission = limiter.admit("change_password", lCase(trim(toString(qPassword.email[1]))), guard.getClientIp());
            if (!admission.ALLOWED) {
                return {SUCCESS=false,AUTH=true,ERROR=admission.CODE,MESSAGE=admission.MESSAGE,
                    STATUSCODE=admission.STATUSCODE,RETRYAFTER=admission.RETRYAFTER};
            }
            var outcome = "error";
            try {
                var passwords = createObject("component", reReplace(getMetadata(this).name, "\.[^.]+$", ".PasswordHashService"));
                var observed = toString(qPassword.password[1]);
                if (!passwords.verifyPassword(arguments.currentPassword, observed)) {
                    outcome = "failure";
                    return {SUCCESS=false,AUTH=true,ERROR="BAD_CURRENT_PASSWORD",MESSAGE="Current password is incorrect."};
                }
                var replacement = passwords.hashPassword(arguments.newPassword);
                var writeResult = {};
                queryExecute(
                    "UPDATE users SET password=:replacement, passwordCreated=:changedAt, lastUpdate=:changedAt
                     WHERE userId=:userId AND CAST(password AS BINARY)=CAST(:observed AS BINARY)",
                    {
                        replacement={value=replacement,cfsqltype="cf_sql_varchar"},
                        changedAt={value=now(),cfsqltype="cf_sql_timestamp"},
                        userId={value=arguments.userId,cfsqltype="cf_sql_integer"},
                        observed={value=observed,cfsqltype="cf_sql_varchar"}
                    },
                    {datasource="fpw",result="local.writeResult"}
                );
                if (!structKeyExists(writeResult,"recordCount") OR val(writeResult.recordCount) NEQ 1) {
                    return {SUCCESS=false,AUTH=true,ERROR="PASSWORD_CHANGED",MESSAGE="Your password changed during this request. Try again with your current password.",STATUSCODE=409};
                }
                outcome = "success";
                return {SUCCESS=true};
            } finally {
                limiter.finish(admission.TICKET, outcome);
            }
        </cfscript>
    </cffunction>

    <!-- Canonical member identity for wizard and delivery; never falls back to email. -->
    <cffunction name="readMemberName" access="public" returntype="struct" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="datasource" type="string" required="false" default="fpw">
        <cfscript>
            var qName = queryExecute(
                "SELECT fName, lName FROM users WHERE userId = :userId LIMIT 1",
                { userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" } },
                { datasource = arguments.datasource }
            );
            var firstName = qName.recordCount AND !isNull(qName.fName[1]) ? trim(toString(qName.fName[1])) : "";
            var lastName = qName.recordCount AND !isNull(qName.lName[1]) ? trim(toString(qName.lName[1])) : "";
            return {
                fName = firstName,
                lName = lastName,
                displayName = trim(firstName & " " & lastName),
                hasName = len(firstName) GT 0 OR len(lastName) GT 0
            };
        </cfscript>
    </cffunction>

    <cffunction name="normalizeOptionalUsPhone" access="private" returntype="struct" output="false">
        <cfargument name="phone" type="string" required="true">

        <cfset var rawValue = trim(toString(arguments.phone))>
        <cfset var digits = reReplace(rawValue, "[^0-9]", "", "all")>

        <cfif NOT len(rawValue)>
            <cfreturn { valid = true, value = "" }>
        </cfif>
        <cfif len(digits) EQ 11 AND left(digits, 1) EQ "1">
            <cfset digits = right(digits, 10)>
        </cfif>
        <cfif len(digits) NEQ 10 OR NOT reFind("^[2-9][0-9]{2}[2-9][0-9]{6}$", digits)>
            <cfreturn { valid = false, value = "" }>
        </cfif>

        <cfreturn { valid = true, value = formatUsPhoneDigits(digits) }>
    </cffunction>

    <cffunction name="formatUsPhoneDigits" access="private" returntype="string" output="false">
        <cfargument name="digits" type="string" required="true">

        <cfreturn "(" & left(arguments.digits, 3) & ") " & mid(arguments.digits, 4, 3) & "-" & right(arguments.digits, 4)>
    </cffunction>

</cfcomponent>
