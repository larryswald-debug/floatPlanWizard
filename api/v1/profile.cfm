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

    <!-- action can come from URL or body; default = "get" -->
    <cfset action = "get">
    <cfif structKeyExists(url, "action") AND len(trim(url.action))>
        <cfset action = lcase(trim(url.action))>
    <cfelseif structKeyExists(body, "action") AND len(trim(body.action))>
        <cfset action = lcase(trim(body.action))>
    </cfif>

    <!-- ========================= -->
    <!-- ACTION: UPDATE PROFILE    -->
    <!-- ========================= -->
    <cfif action EQ "update">

        <cfset newFName = trim(body.fName ?: body.firstName ?: "")>
        <cfset newLName = trim(body.lName ?: body.lastName  ?: "")>
        <cfset newMobile = trim(body.mobilePhone ?: "")>

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

        <!-- Load current stored password -->
        <cfquery name="qPw" datasource="fpw">
            SELECT password
            FROM users
            WHERE userId = <cfqueryparam cfsqltype="cf_sql_integer" value="#userId#">
            LIMIT 1
        </cfquery>

        <cfif qPw.recordCount EQ 0>
            <cfset response = {
                SUCCESS = false,
                ERROR   = "NOT_FOUND",
                MESSAGE = "User not found."
            }>
            <cfoutput>#serializeJSON(response)#</cfoutput>
            <cfsetting enablecfoutputonly="false">
            <cfabort>
        </cfif>

        <cfset dbPassword = qPw.password>

        <!-- Compare: allow legacy plaintext or SHA-256 (stored often uppercase hex) -->
        <cfset currentHash = ucase(hash(currentPassword, "SHA-256", "UTF-8"))>
        <cfset dbPwUpper   = ucase(dbPassword)>

        <cfif NOT ( currentPassword EQ dbPassword OR currentHash EQ dbPwUpper )>
            <cfset response = {
                SUCCESS = false,
                ERROR   = "BAD_CURRENT_PASSWORD",
                MESSAGE = "Current password is incorrect."
            }>
            <cfoutput>#serializeJSON(response)#</cfoutput>
            <cfsetting enablecfoutputonly="false">
            <cfabort>
        </cfif>

        <!-- Store new password as SHA-256 uppercase hex -->
        <cfset newHash = ucase(hash(newPassword, "SHA-256", "UTF-8"))>

        <cfquery datasource="fpw">
            UPDATE users
            SET
                password         = <cfqueryparam cfsqltype="cf_sql_varchar" value="#newHash#">,
                passwordCreated  = <cfqueryparam cfsqltype="cf_sql_timestamp" value="#now()#">,
                lastUpdate       = <cfqueryparam cfsqltype="cf_sql_timestamp" value="#now()#">
            WHERE userId = <cfqueryparam cfsqltype="cf_sql_integer" value="#userId#">
        </cfquery>

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
