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
                <cfset local.access = {} >

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

                <cfset local.access = new fpw.api.v1.MemberEntitlementService().init("fpw").getCurrentAccess(local.userId)>
                <cfset structDelete(local.access, "premiumEntitlementId", false)>

                <cfset response = structNew("ordered-casesensitive")>
                <cfset response["SUCCESS"] = true>
                <cfset response["success"] = true>
                <cfset response["AUTH"] = true>
                <cfset response["auth"] = true>
                <cfset response["USER"] = local.user>
                <cfset response["user"] = local.user>
                <cfset response["ACCESS"] = local.access>
                <cfset response["access"] = local.access>

            <cfelse>

                <cfset response = structNew("ordered-casesensitive")>
                <cfset response["SUCCESS"] = false>
                <cfset response["success"] = false>
                <cfset response["AUTH"] = false>
                <cfset response["auth"] = false>
                <cfset response["MESSAGE"] = "Not logged in.">
                <cfset response["message"] = "Not logged in.">
                <cfset response["ERROR"] = "AUTH_REQUIRED">
                <cfset response["errorCode"] = "AUTH_REQUIRED">

            </cfif>

            <cfoutput>#serializeJSON(response)#</cfoutput>

            <cfcatch type="any">
                <cfset errResponse = structNew("ordered-casesensitive")>
                <cfset errResponse["SUCCESS"] = false>
                <cfset errResponse["success"] = false>
                <cfset errResponse["AUTH"] = false>
                <cfset errResponse["auth"] = false>
                <cfset errResponse["MESSAGE"] = "Server error fetching current user.">
                <cfset errResponse["message"] = "Server error fetching current user.">
                <cfset errResponse["ERROR"] = "SERVER_ERROR">
                <cfset errResponse["errorCode"] = "SERVER_ERROR">
                <cfset errResponse["DETAIL"] = cfcatch.message>
                <cfoutput>#serializeJSON(errResponse)#</cfoutput>
            </cfcatch>

        </cftry>

        <cfsetting enablecfoutputonly="false">
    </cffunction>

</cfcomponent>
