<cfcomponent output="false">

    <cffunction name="handle" access="remote" returntype="void" output="true">
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

            <!-- Resolve userId -->
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
                    MESSAGE = "Invalid session user."
                }>
                <cfoutput>#serializeJSON(response)#</cfoutput>
                <cfsetting enablecfoutputonly="false">
                <cfabort>
            </cfif>

            <!-- Parse JSON body -->
            <cfset httpData = getHttpRequestData()>
            <cfset rawBody  = toString(httpData.content)>
            <cfset body     = {}>

            <cfif len(trim(rawBody))>
                <cfset body = deserializeJSON(rawBody, false)>
            </cfif>

            <cfset action = "get">
            <cfif structKeyExists(url, "action") AND len(trim(url.action))>
                <cfset action = lcase(trim(url.action))>
            <cfelseif structKeyExists(body, "action") AND len(trim(body.action))>
                <cfset action = lcase(trim(body.action))>
            </cfif>

            <!-- Load existing home port record (if any) -->
            <cfquery name="qHome" datasource="fpw">
                SELECT
                    recId,
                    userId,
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

            <!-- SAVE / UPSERT -->
            <cfif action EQ "save">

                <cfset address = trim(body.address ?: body.ADDRESS ?: "")>
                <cfset city    = trim(body.city    ?: body.CITY    ?: "")>
                <cfset state   = trim(body.state   ?: body.STATE   ?: "")>
                <cfset zip     = trim(body.zip     ?: body.ZIP     ?: "")>
                <cfset phone   = trim(body.phone   ?: body.PHONE   ?: "")>
                <cfset lat     = trim(body.lat     ?: body.LAT     ?: "")>
                <cfset lng     = trim(body.lng     ?: body.LNG     ?: "")>

                <!-- Basic minimal validation -->
                <cfif NOT len(address) AND NOT len(city) AND NOT len(state) AND NOT len(zip)>
                    <cfset response = {
                        SUCCESS = false,
                        AUTH    = true,
                        ERROR   = "MISSING_FIELDS",
                        MESSAGE = "Please enter at least an address or city/state/zip."
                    }>
                    <cfoutput>#serializeJSON(response)#</cfoutput>
                    <cfsetting enablecfoutputonly="false">
                    <cfabort>
                </cfif>

                <cfif qHome.recordCount EQ 0>
                    <!-- Insert -->
                    <cfquery datasource="fpw">
                        INSERT INTO users_address (
                            userId, address, city, state, zip, phone, lat, lng, isHomePort
                        ) VALUES (
                            <cfqueryparam cfsqltype="cf_sql_integer" value="#userId#">,
                            <cfqueryparam cfsqltype="cf_sql_varchar" value="#address#" null="#NOT len(address)#">,
                            <cfqueryparam cfsqltype="cf_sql_varchar" value="#city#" null="#NOT len(city)#">,
                            <cfqueryparam cfsqltype="cf_sql_varchar" value="#state#" null="#NOT len(state)#">,
                            <cfqueryparam cfsqltype="cf_sql_varchar" value="#zip#" null="#NOT len(zip)#">,
                            <cfqueryparam cfsqltype="cf_sql_varchar" value="#phone#" null="#NOT len(phone)#">,
                            <cfqueryparam cfsqltype="cf_sql_varchar" value="#lat#" null="#NOT len(lat)#">,
                            <cfqueryparam cfsqltype="cf_sql_varchar" value="#lng#" null="#NOT len(lng)#">,
                            1
                        )
                    </cfquery>
                <cfelse>
                    <!-- Update -->
                    <cfquery datasource="fpw">
                        UPDATE users_address
                        SET
                            address    = <cfqueryparam cfsqltype="cf_sql_varchar" value="#address#" null="#NOT len(address)#">,
                            city       = <cfqueryparam cfsqltype="cf_sql_varchar" value="#city#" null="#NOT len(city)#">,
                            state      = <cfqueryparam cfsqltype="cf_sql_varchar" value="#state#" null="#NOT len(state)#">,
                            zip        = <cfqueryparam cfsqltype="cf_sql_varchar" value="#zip#" null="#NOT len(zip)#">,
                            phone      = <cfqueryparam cfsqltype="cf_sql_varchar" value="#phone#" null="#NOT len(phone)#">,
                            lat        = <cfqueryparam cfsqltype="cf_sql_varchar" value="#lat#" null="#NOT len(lat)#">,
                            lng        = <cfqueryparam cfsqltype="cf_sql_varchar" value="#lng#" null="#NOT len(lng)#">,
                            isHomePort = 1
                        WHERE recId = <cfqueryparam cfsqltype="cf_sql_integer" value="#qHome.recId#">
                          AND userId = <cfqueryparam cfsqltype="cf_sql_integer" value="#userId#">
                    </cfquery>
                </cfif>

                <!-- Touch users.lastUpdate -->
                <cfquery datasource="fpw">
                    UPDATE users
                    SET lastUpdate = <cfqueryparam cfsqltype="cf_sql_timestamp" value="#now()#">
                    WHERE userId = <cfqueryparam cfsqltype="cf_sql_integer" value="#userId#">
                </cfquery>

                <!-- Reload home port after save -->
                <cfquery name="qHome" datasource="fpw">
                    SELECT
                        recId,
                        userId,
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

            </cfif>

            <!-- Build response -->
            <cfset home = {}>

            <cfif qHome.recordCount EQ 1>
                <cfset home = {
                    RECID      = qHome.recId,
                    USERID     = qHome.userId,
                    ADDRESS    = qHome.address,
                    CITY       = qHome.city,
                    STATE      = qHome.state,
                    ZIP        = qHome.zip,
                    PHONE      = qHome.phone,
                    LAT        = qHome.lat,
                    LNG        = qHome.lng,
                    ISHOMEPORT = qHome.isHomePort
                }>
            </cfif>

            <cfset response = {
                SUCCESS = true,
                AUTH    = true,
                HOMEPORT = home
            }>

            <cfoutput>#serializeJSON(response)#</cfoutput>

            <cfcatch type="any">
                <cfset errResponse = {
                    SUCCESS = false,
                    AUTH    = true,
                    ERROR   = "SERVER_ERROR",
                    MESSAGE = "Home port API error.",
                    DETAIL  = cfcatch.message
                }>
                <cfoutput>#serializeJSON(errResponse)#</cfoutput>
            </cfcatch>

        </cftry>

        <cfsetting enablecfoutputonly="false">
    </cffunction>

</cfcomponent>
