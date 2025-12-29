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
                <cfset operator = {}>
                <cfif structKeyExists(body, "operator")>
                    <cfset operator = body.operator>
                <cfelseif structKeyExists(body, "OPERATOR")>
                    <cfset operator = body.OPERATOR>
                </cfif>

                <cfset operatorId = 0>
                <cfif structKeyExists(operator, "OPERATORID")>
                    <cfset operatorId = val(operator.OPERATORID)>
                <cfelseif structKeyExists(operator, "operatorId")>
                    <cfset operatorId = val(operator.operatorId)>
                </cfif>

                <cfset operatorName = structKeyExists(operator, "OPERATORNAME") ? trim(operator.OPERATORNAME) : (structKeyExists(operator, "name") ? trim(operator.name) : "")>
                <cfif NOT len(operatorName)>
                    <cfthrow message="Name is required.">
                </cfif>

                <cfset phone = structKeyExists(operator, "PHONE") ? trim(operator.PHONE) : (structKeyExists(operator, "phone") ? trim(operator.phone) : "")>
                <cfset notes = structKeyExists(operator, "NOTES") ? trim(operator.NOTES) : (structKeyExists(operator, "notes") ? trim(operator.notes) : "")>

                <cfif operatorId GT 0>
                    <cfquery datasource="fpw">
                        UPDATE operators
                        SET name = <cfqueryparam cfsqltype="cf_sql_varchar" value="#operatorName#">,
                            homePhone = <cfqueryparam cfsqltype="cf_sql_varchar" value="#phone#">,
                            notes = <cfqueryparam cfsqltype="cf_sql_varchar" value="#notes#">
                        WHERE opId = <cfqueryparam cfsqltype="cf_sql_integer" value="#operatorId#">
                          AND userId = <cfqueryparam cfsqltype="cf_sql_integer" value="#userId#">
                    </cfquery>
                <cfelse>
                    <cfset insertResult = {}>
                    <cfquery datasource="fpw" result="insertResult">
                        INSERT INTO operators (userId, name, homePhone, notes)
                        VALUES (
                            <cfqueryparam cfsqltype="cf_sql_integer" value="#userId#">,
                            <cfqueryparam cfsqltype="cf_sql_varchar" value="#operatorName#">,
                            <cfqueryparam cfsqltype="cf_sql_varchar" value="#phone#">,
                            <cfqueryparam cfsqltype="cf_sql_varchar" value="#notes#">
                        )
                    </cfquery>
                    <cfif structKeyExists(insertResult, "generatedKey")>
                        <cfset operatorId = insertResult.generatedKey>
                    </cfif>
                </cfif>

                <cfset response = {
                    SUCCESS = true,
                    AUTH    = true,
                    OPERATORID = operatorId
                }>
                <cfoutput>#serializeJSON(response)#</cfoutput>
                <cfsetting enablecfoutputonly="false">
                <cfabort>
            </cfif>

            <cfif action EQ "delete">
                <cfset operatorId = 0>
                <cfif structKeyExists(body, "operatorId")>
                    <cfset operatorId = val(body.operatorId)>
                <cfelseif structKeyExists(body, "OPERATORID")>
                    <cfset operatorId = val(body.OPERATORID)>
                <cfelseif structKeyExists(url, "operatorId")>
                    <cfset operatorId = val(url.operatorId)>
                </cfif>

                <cfif operatorId LTE 0>
                    <cfthrow message="Operator id is required.">
                </cfif>

                <cfquery name="qOperatorUsage" datasource="fpw">
                    SELECT floatPlanName
                    FROM floatplans
                    WHERE operatorId = <cfqueryparam cfsqltype="cf_sql_integer" value="#operatorId#">
                      AND userId = <cfqueryparam cfsqltype="cf_sql_integer" value="#userId#">
                </cfquery>

                <cfif qOperatorUsage.recordCount GT 0>
                    <cfset planNames = []>
                    <cfloop query="qOperatorUsage">
                        <cfset arrayAppend(planNames, qOperatorUsage.floatPlanName)>
                    </cfloop>
                    <cfset planCount = arrayLen(planNames)>
                    <cfset planList = arrayToList(planNames, ", ")>
                    <cfset response = {
                        SUCCESS = false,
                        AUTH    = true,
                        ERROR   = "IN_USE",
                        MESSAGE = "This operator is used in " & planCount & " float plan" & (planCount EQ 1 ? "" : "s") & ": " & planList & ". Edit the float plan to remove it before deleting."
                    }>
                    <cfoutput>#serializeJSON(response)#</cfoutput>
                    <cfsetting enablecfoutputonly="false">
                    <cfabort>
                </cfif>

                <cfquery datasource="fpw">
                    DELETE FROM operators
                    WHERE opId = <cfqueryparam cfsqltype="cf_sql_integer" value="#operatorId#">
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

            <cfif action EQ "candelete">
                <cfset operatorId = 0>
                <cfif structKeyExists(body, "operatorId")>
                    <cfset operatorId = val(body.operatorId)>
                <cfelseif structKeyExists(body, "OPERATORID")>
                    <cfset operatorId = val(body.OPERATORID)>
                <cfelseif structKeyExists(url, "operatorId")>
                    <cfset operatorId = val(url.operatorId)>
                </cfif>

                <cfif operatorId LTE 0>
                    <cfthrow message="Operator id is required.">
                </cfif>

                <cfquery name="qOperatorUsage" datasource="fpw">
                    SELECT floatPlanName
                    FROM floatplans
                    WHERE operatorId = <cfqueryparam cfsqltype="cf_sql_integer" value="#operatorId#">
                      AND userId = <cfqueryparam cfsqltype="cf_sql_integer" value="#userId#">
                </cfquery>

                <cfif qOperatorUsage.recordCount GT 0>
                    <cfset planNames = []>
                    <cfloop query="qOperatorUsage">
                        <cfset arrayAppend(planNames, qOperatorUsage.floatPlanName)>
                    </cfloop>
                    <cfset planCount = arrayLen(planNames)>
                    <cfset planList = arrayToList(planNames, ", ")>
                    <cfset response = {
                        SUCCESS = true,
                        AUTH    = true,
                        CANDELETE = false,
                        MESSAGE = "This operator is used in " & planCount & " float plan" & (planCount EQ 1 ? "" : "s") & ": " & planList & ". Edit the float plan to remove it before deleting."
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
                    MESSAGE = "Operator API error.",
                    DETAIL  = cfcatch.message
                }>
                <cfoutput>#serializeJSON(errResponse)#</cfoutput>
            </cfcatch>

        </cftry>

        <cfsetting enablecfoutputonly="false">
    </cffunction>

</cfcomponent>
