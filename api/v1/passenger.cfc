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
                <cfset passenger = {}>
                <cfif structKeyExists(body, "passenger")>
                    <cfset passenger = body.passenger>
                <cfelseif structKeyExists(body, "PASSENGER")>
                    <cfset passenger = body.PASSENGER>
                </cfif>

                <cfset passengerId = 0>
                <cfif structKeyExists(passenger, "PASSENGERID")>
                    <cfset passengerId = val(passenger.PASSENGERID)>
                <cfelseif structKeyExists(passenger, "passengerId")>
                    <cfset passengerId = val(passenger.passengerId)>
                </cfif>

                <cfset passengerName = structKeyExists(passenger, "PASSENGERNAME") ? trim(passenger.PASSENGERNAME) : (structKeyExists(passenger, "name") ? trim(passenger.name) : "")>
                <cfif NOT len(passengerName)>
                    <cfthrow message="Name is required.">
                </cfif>

                <cfset phone = structKeyExists(passenger, "PHONE") ? trim(passenger.PHONE) : (structKeyExists(passenger, "phone") ? trim(passenger.phone) : "")>
                <cfset age = structKeyExists(passenger, "AGE") ? trim(passenger.AGE) : (structKeyExists(passenger, "age") ? trim(passenger.age) : "")>
                <cfset gender = structKeyExists(passenger, "GENDER") ? trim(passenger.GENDER) : (structKeyExists(passenger, "gender") ? trim(passenger.gender) : "")>
                <cfset notes = structKeyExists(passenger, "NOTES") ? trim(passenger.NOTES) : (structKeyExists(passenger, "notes") ? trim(passenger.notes) : "")>

                <cfif passengerId GT 0>
                    <cfquery datasource="fpw">
                        UPDATE passengers
                        SET name = <cfqueryparam cfsqltype="cf_sql_varchar" value="#passengerName#">,
                            phone = <cfqueryparam cfsqltype="cf_sql_varchar" value="#phone#">,
                            age = <cfqueryparam cfsqltype="cf_sql_varchar" value="#age#">,
                            gender = <cfqueryparam cfsqltype="cf_sql_varchar" value="#gender#">,
                            notes = <cfqueryparam cfsqltype="cf_sql_varchar" value="#notes#">
                        WHERE passId = <cfqueryparam cfsqltype="cf_sql_integer" value="#passengerId#">
                          AND userId = <cfqueryparam cfsqltype="cf_sql_integer" value="#userId#">
                    </cfquery>
                <cfelse>
                    <cfset insertResult = {}>
                    <cfquery datasource="fpw" result="insertResult">
                        INSERT INTO passengers (userId, name, phone, age, gender, notes, pfd)
                        VALUES (
                            <cfqueryparam cfsqltype="cf_sql_integer" value="#userId#">,
                            <cfqueryparam cfsqltype="cf_sql_varchar" value="#passengerName#">,
                            <cfqueryparam cfsqltype="cf_sql_varchar" value="#phone#">,
                            <cfqueryparam cfsqltype="cf_sql_varchar" value="#age#">,
                            <cfqueryparam cfsqltype="cf_sql_varchar" value="#gender#">,
                            <cfqueryparam cfsqltype="cf_sql_varchar" value="#notes#">,
                            <cfqueryparam cfsqltype="cf_sql_bit" value="1">
                        )
                    </cfquery>
                    <cfif structKeyExists(insertResult, "generatedKey")>
                        <cfset passengerId = insertResult.generatedKey>
                    </cfif>
                </cfif>

                <cfset response = {
                    SUCCESS = true,
                    AUTH    = true,
                    PASSENGERID = passengerId
                }>
                <cfoutput>#serializeJSON(response)#</cfoutput>
                <cfsetting enablecfoutputonly="false">
                <cfabort>
            </cfif>

            <cfif action EQ "candelete">
                <cfset passengerId = 0>
                <cfif structKeyExists(body, "passengerId")>
                    <cfset passengerId = val(body.passengerId)>
                <cfelseif structKeyExists(body, "PASSENGERID")>
                    <cfset passengerId = val(body.PASSENGERID)>
                <cfelseif structKeyExists(url, "passengerId")>
                    <cfset passengerId = val(url.passengerId)>
                </cfif>

                <cfif passengerId LTE 0>
                    <cfthrow message="Passenger id is required.">
                </cfif>

                <cfquery name="qPassengerUsage" datasource="fpw">
                    SELECT fp.floatPlanName
                    FROM floatplan_passengers fpp
                    INNER JOIN floatplans fp ON fp.floatplanId = fpp.floatplanId
                    WHERE fpp.passId = <cfqueryparam cfsqltype="cf_sql_integer" value="#passengerId#">
                      AND fp.userId = <cfqueryparam cfsqltype="cf_sql_integer" value="#userId#">
                </cfquery>

                <cfif qPassengerUsage.recordCount GT 0>
                    <cfset planNames = []>
                    <cfloop query="qPassengerUsage">
                        <cfset arrayAppend(planNames, qPassengerUsage.floatPlanName)>
                    </cfloop>
                    <cfset planCount = arrayLen(planNames)>
                    <cfset planList = arrayToList(planNames, ", ")>
                    <cfset response = {
                        SUCCESS = true,
                        AUTH    = true,
                        CANDELETE = false,
                        MESSAGE = "This passenger is used in " & planCount & " float plan" & (planCount EQ 1 ? "" : "s") & ": " & planList & ". Edit the float plan to remove it before deleting."
                    }>
                <cfelse>
                    <cfset response = {
                        SUCCESS = true,
                        AUTH    = true,
                        CANDELETE = true
                    }>
                </cfif>

                <cfoutput>#serializeJSON(response)#</cfoutput>
                <cfsetting enablecfoutputonly="false">
                <cfabort>
            </cfif>

            <cfif action EQ "delete">
                <cfset passengerId = 0>
                <cfif structKeyExists(body, "passengerId")>
                    <cfset passengerId = val(body.passengerId)>
                <cfelseif structKeyExists(body, "PASSENGERID")>
                    <cfset passengerId = val(body.PASSENGERID)>
                <cfelseif structKeyExists(url, "passengerId")>
                    <cfset passengerId = val(url.passengerId)>
                </cfif>

                <cfif passengerId LTE 0>
                    <cfthrow message="Passenger id is required.">
                </cfif>

                <cfquery name="qPassengerUsage" datasource="fpw">
                    SELECT fp.floatPlanName
                    FROM floatplan_passengers fpp
                    INNER JOIN floatplans fp ON fp.floatplanId = fpp.floatplanId
                    WHERE fpp.passId = <cfqueryparam cfsqltype="cf_sql_integer" value="#passengerId#">
                      AND fp.userId = <cfqueryparam cfsqltype="cf_sql_integer" value="#userId#">
                </cfquery>

                <cfif qPassengerUsage.recordCount GT 0>
                    <cfset planNames = []>
                    <cfloop query="qPassengerUsage">
                        <cfset arrayAppend(planNames, qPassengerUsage.floatPlanName)>
                    </cfloop>
                    <cfset planCount = arrayLen(planNames)>
                    <cfset planList = arrayToList(planNames, ", ")>
                    <cfset response = {
                        SUCCESS = false,
                        AUTH    = true,
                        ERROR   = "IN_USE",
                        MESSAGE = "This passenger is used in " & planCount & " float plan" & (planCount EQ 1 ? "" : "s") & ": " & planList & ". Edit the float plan to remove it before deleting."
                    }>
                    <cfoutput>#serializeJSON(response)#</cfoutput>
                    <cfsetting enablecfoutputonly="false">
                    <cfabort>
                </cfif>

                <cfquery datasource="fpw">
                    DELETE FROM passengers
                    WHERE passId = <cfqueryparam cfsqltype="cf_sql_integer" value="#passengerId#">
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
                    MESSAGE = "Passenger API error.",
                    DETAIL  = cfcatch.message
                }>
                <cfoutput>#serializeJSON(errResponse)#</cfoutput>
            </cfcatch>

        </cftry>

        <cfsetting enablecfoutputonly="false">
    </cffunction>

</cfcomponent>
