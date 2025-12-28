<cfcomponent output="false">

    <cffunction name="handle" access="remote" returntype="void" output="true">
        <cfsetting enablecfoutputonly="true" showdebugoutput="false">
        <cfcontent type="application/json; charset=utf-8">
        <cfheader name="Cache-Control" value="no-store, no-cache, must-revalidate">

        <cftry>

            <!-- Require authenticated session -->
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

            <!-- Optional JSON body -->
            <cfset httpData = getHttpRequestData()>
            <cfset rawBody  = toString(httpData.content)>
            <cfset body     = {}>

            <cfif len(trim(rawBody))>
                <cftry>
                    <cfset body = deserializeJSON(rawBody, false)>
                <cfcatch>
                    <cfset body = {}>
                </cfcatch>
                </cftry>
            </cfif>

            <cfset action = "">
            <cfif structKeyExists(url, "action")>
                <cfset action = lcase(trim(url.action))>
            <cfelseif structKeyExists(body, "action")>
                <cfset action = lcase(trim(body.action))>
            </cfif>

            <cfif action EQ "save">
                <cfset vessel = {}>
                <cfif structKeyExists(body, "vessel")>
                    <cfset vessel = body.vessel>
                <cfelseif structKeyExists(body, "VESSEL")>
                    <cfset vessel = body.VESSEL>
                </cfif>

                <cfset vesselId = 0>
                <cfif structKeyExists(vessel, "VESSELID")>
                    <cfset vesselId = val(vessel.VESSELID)>
                <cfelseif structKeyExists(vessel, "vesselId")>
                    <cfset vesselId = val(vessel.vesselId)>
                </cfif>

                <cfset vesselName = structKeyExists(vessel, "VESSELNAME") ? trim(vessel.VESSELNAME) : (structKeyExists(vessel, "vesselName") ? trim(vessel.vesselName) : "")>
                <cfif NOT len(vesselName)>
                    <cfthrow message="Vessel name is required.">
                </cfif>

                <cfset registration = structKeyExists(vessel, "REGISTRATION") ? trim(vessel.REGISTRATION) : (structKeyExists(vessel, "registration") ? trim(vessel.registration) : "")>
                <cfset vesselType  = structKeyExists(vessel, "TYPE") ? trim(vessel.TYPE) : (structKeyExists(vessel, "type") ? trim(vessel.type) : "")>
                <cfset make        = structKeyExists(vessel, "MAKE") ? trim(vessel.MAKE) : (structKeyExists(vessel, "make") ? trim(vessel.make) : "")>
                <cfset model       = structKeyExists(vessel, "MODEL") ? trim(vessel.MODEL) : (structKeyExists(vessel, "model") ? trim(vessel.model) : "")>
                <cfset length      = structKeyExists(vessel, "LENGTH") ? trim(vessel.LENGTH) : (structKeyExists(vessel, "length") ? trim(vessel.length) : "")>
                <cfset color       = structKeyExists(vessel, "COLOR") ? trim(vessel.COLOR) : (structKeyExists(vessel, "color") ? trim(vessel.color) : "")>
                <cfset homePort    = structKeyExists(vessel, "HOMEPORT") ? trim(vessel.HOMEPORT) : (structKeyExists(vessel, "homePort") ? trim(vessel.homePort) : "")>

                <cfif vesselId GT 0>
                    <cfquery datasource="fpw">
                        UPDATE vessels
                        SET vesselName = <cfqueryparam cfsqltype="cf_sql_varchar" value="#vesselName#">,
                            registration = <cfqueryparam cfsqltype="cf_sql_varchar" value="#registration#">,
                            typeOfVessel = <cfqueryparam cfsqltype="cf_sql_varchar" value="#vesselType#">,
                            make = <cfqueryparam cfsqltype="cf_sql_varchar" value="#make#">,
                            model = <cfqueryparam cfsqltype="cf_sql_varchar" value="#model#">,
                            lengthOfVessel = <cfqueryparam cfsqltype="cf_sql_varchar" value="#length#">,
                            hullColor = <cfqueryparam cfsqltype="cf_sql_varchar" value="#color#">,
                            hailingPort = <cfqueryparam cfsqltype="cf_sql_varchar" value="#homePort#">
                        WHERE vesselId = <cfqueryparam cfsqltype="cf_sql_integer" value="#vesselId#">
                          AND userId = <cfqueryparam cfsqltype="cf_sql_integer" value="#userId#">
                    </cfquery>
                <cfelse>
                    <cfset insertResult = {}>
                    <cfquery datasource="fpw" result="insertResult">
                        INSERT INTO vessels (userId, vesselName, registration, typeOfVessel, make, model, lengthOfVessel, hullColor, hailingPort)
                        VALUES (
                            <cfqueryparam cfsqltype="cf_sql_integer" value="#userId#">,
                            <cfqueryparam cfsqltype="cf_sql_varchar" value="#vesselName#">,
                            <cfqueryparam cfsqltype="cf_sql_varchar" value="#registration#">,
                            <cfqueryparam cfsqltype="cf_sql_varchar" value="#vesselType#">,
                            <cfqueryparam cfsqltype="cf_sql_varchar" value="#make#">,
                            <cfqueryparam cfsqltype="cf_sql_varchar" value="#model#">,
                            <cfqueryparam cfsqltype="cf_sql_varchar" value="#length#">,
                            <cfqueryparam cfsqltype="cf_sql_varchar" value="#color#">,
                            <cfqueryparam cfsqltype="cf_sql_varchar" value="#homePort#">
                        )
                    </cfquery>
                    <cfif structKeyExists(insertResult, "generatedKey")>
                        <cfset vesselId = insertResult.generatedKey>
                    </cfif>
                </cfif>

                <cfset response = {
                    SUCCESS = true,
                    AUTH    = true,
                    VESSELID = vesselId
                }>
                <cfoutput>#serializeJSON(response)#</cfoutput>
                <cfsetting enablecfoutputonly="false">
                <cfabort>
            </cfif>

            <cfif action EQ "delete">
                <cfset vesselId = 0>
                <cfif structKeyExists(body, "vesselId")>
                    <cfset vesselId = val(body.vesselId)>
                <cfelseif structKeyExists(body, "VESSELID")>
                    <cfset vesselId = val(body.VESSELID)>
                <cfelseif structKeyExists(url, "vesselId")>
                    <cfset vesselId = val(url.vesselId)>
                </cfif>

                <cfif vesselId LTE 0>
                    <cfthrow message="Vessel id is required.">
                </cfif>

                <cfquery datasource="fpw">
                    DELETE FROM vessels
                    WHERE vesselId = <cfqueryparam cfsqltype="cf_sql_integer" value="#vesselId#">
                      AND userId = <cfqueryparam cfsqltype="cf_sql_integer" value="#userId#">
                </cfquery>

                <cfset response = {
                    SUCCESS = true,
                    AUTH    = true
                }>
                <cfoutput>#serializeJSON(response)#</cfoutput>
                <cfsetting enablecfoutputonly="false">
                <cfabort>
            </cfif>

            <cfset response = {
                SUCCESS = false,
                AUTH    = true,
                ERROR   = "INVALID_ACTION",
                MESSAGE = "Unknown action."
            }>
            <cfoutput>#serializeJSON(response)#</cfoutput>

            <cfcatch type="any">
                <cfset errResponse = {
                    SUCCESS = false,
                    AUTH    = true,
                    ERROR   = "SERVER_ERROR",
                    MESSAGE = "Vessel API error.",
                    DETAIL  = cfcatch.message
                }>
                <cfoutput>#serializeJSON(errResponse)#</cfoutput>
            </cfcatch>

        </cftry>

        <cfsetting enablecfoutputonly="false">
    </cffunction>

</cfcomponent>
