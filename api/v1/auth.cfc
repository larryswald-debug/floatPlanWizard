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
                <cftry>
                    <cfset body = deserializeJSON( rawBody, false )>
                <cfcatch>
                    <cfset body = {}> 
                </cfcatch>
                </cftry>
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
                <cfset structDelete( session, "user", false )>
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

                <!-- Verify password -->
                <cfset dbPassword = qUser.dbPassword>
                <!-- Assume SHA-256 hex hash for stored passwords -->
                <cfset hashedInput = hash( password, "SHA-256", "UTF-8" )>

                <!-- Match either hashed (normal) or plain-text (for legacy rows like 'changeIt') -->
                <cfif NOT ( hashedInput EQ dbPassword OR password EQ dbPassword )>
                    <cfset response = {
                        SUCCESS = false,
                        MESSAGE = "Invalid email or password.",
                        ERROR   = "INVALID_LOGIN"
                    }>
                    <cfset response = serializeJSON( response )>
                    <cfreturn response>
                   
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
                    DETAIL  = cfcatch.message
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
