<cfcomponent output="false">

    <cffunction name="handle" access="remote" returntype="void" output="true">
        <cfsetting enablecfoutputonly="true" showdebugoutput="false">
        <cfcontent type="application/json; charset=utf-8">
        <cfheader name="Cache-Control" value="no-store, no-cache, must-revalidate">

        <cftry>

            <!-- Check if user is logged in -->
            <cfif structKeyExists(session, "user") AND isStruct(session.user)>

                <cfset local.user = duplicate(session.user)>
                <cfset local.userId = 0>
                <cfset local.homePort = {} >

                <cfif structKeyExists(local.user, "userId")>
                    <cfset local.userId = int(val(local.user.userId))>
                <cfelseif structKeyExists(local.user, "id")>
                    <cfset local.userId = int(val(local.user.id))>
                <cfelseif structKeyExists(local.user, "USERID")>
                    <cfset local.userId = int(val(local.user.USERID))>
                </cfif>

                <cfif local.userId GT 0>
                    <cfquery name="qHomePort" datasource="fpw">
                        SELECT
                            address,
                            city,
                            state,
                            zip,
                            phone,
                            lat,
                            lng,
                            isHomePort
                        FROM users_address
                        WHERE userId = <cfqueryparam cfsqltype="cf_sql_integer" value="#local.userId#">
                          AND isHomePort = 1
                        LIMIT 1
                    </cfquery>

                    <cfif qHomePort.recordCount EQ 1>
                        <cfset local.homePort = {
                            "address" = qHomePort.address,
                            "city" = qHomePort.city,
                            "state" = qHomePort.state,
                            "zip" = qHomePort.zip,
                            "ZIP" = qHomePort.zip,
                            "phone" = qHomePort.phone,
                            "lat" = qHomePort.lat,
                            "LAT" = qHomePort.lat,
                            "lng" = qHomePort.lng,
                            "LNG" = qHomePort.lng,
                            "isHomePort" = qHomePort.isHomePort,
                            "ISHOMEPORT" = qHomePort.isHomePort
                        }>
                    </cfif>
                </cfif>

                <cfif NOT structKeyExists(local.user, "PROFILE") OR NOT isStruct(local.user.PROFILE)>
                    <cfset local.user.PROFILE = {} >
                </cfif>
                <cfset local.user.PROFILE.homePort = local.homePort>
                <cfset local.user.PROFILE.HOMEPORT = local.homePort>
                <cfset local.user.homePort = local.homePort>
                <cfset local.user.HOMEPORT = local.homePort>

                <cfset response = {
                    SUCCESS = true,
                    AUTH    = true,
                    USER    = local.user
                }>

            <cfelse>

                <cfset response = {
                    SUCCESS = false,
                    AUTH    = false,
                    MESSAGE = "Not logged in."
                }>

            </cfif>

            <cfoutput>#serializeJSON(response)#</cfoutput>

            <cfcatch type="any">
                <cfset errResponse = {
                    SUCCESS = false,
                    AUTH    = false,
                    MESSAGE = "Server error fetching current user.",
                    ERROR   = "SERVER_ERROR",
                    DETAIL  = cfcatch.message
                }>
                <cfoutput>#serializeJSON(errResponse)#</cfoutput>
            </cfcatch>

        </cftry>

        <cfsetting enablecfoutputonly="false">
    </cffunction>

</cfcomponent>
