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
                <cfset contact = {}>
                <cfif structKeyExists(body, "contact")>
                    <cfset contact = body.contact>
                <cfelseif structKeyExists(body, "CONTACT")>
                    <cfset contact = body.CONTACT>
                </cfif>

                <cfset contactId = 0>
                <cfif structKeyExists(contact, "CONTACTID")>
                    <cfset contactId = val(contact.CONTACTID)>
                <cfelseif structKeyExists(contact, "contactId")>
                    <cfset contactId = val(contact.contactId)>
                </cfif>

                <cfset contactName = structKeyExists(contact, "CONTACTNAME") ? trim(contact.CONTACTNAME) : (structKeyExists(contact, "name") ? trim(contact.name) : "")>
                <cfif NOT len(contactName)>
                    <cfthrow message="Contact name is required.">
                </cfif>

                <cfset phone = structKeyExists(contact, "PHONE") ? trim(contact.PHONE) : (structKeyExists(contact, "phone") ? trim(contact.phone) : "")>
                <cfset email = structKeyExists(contact, "EMAIL") ? trim(contact.EMAIL) : (structKeyExists(contact, "email") ? trim(contact.email) : "")>
                <cfif NOT len(phone)>
                    <cfthrow message="Phone is required.">
                </cfif>
                <cfif NOT len(email)>
                    <cfthrow message="Email is required.">
                </cfif>

                <cfif contactId GT 0>
                    <cfquery datasource="fpw">
                        UPDATE contacts
                        SET name = <cfqueryparam cfsqltype="cf_sql_varchar" value="#contactName#">,
                            phone = <cfqueryparam cfsqltype="cf_sql_varchar" value="#phone#">,
                            email = <cfqueryparam cfsqltype="cf_sql_varchar" value="#email#">
                        WHERE contactId = <cfqueryparam cfsqltype="cf_sql_integer" value="#contactId#">
                          AND userId = <cfqueryparam cfsqltype="cf_sql_integer" value="#userId#">
                    </cfquery>
                <cfelse>
                    <cfset insertResult = {}>
                    <cfquery datasource="fpw" result="insertResult">
                        INSERT INTO contacts (userId, name, phone, email)
                        VALUES (
                            <cfqueryparam cfsqltype="cf_sql_integer" value="#userId#">,
                            <cfqueryparam cfsqltype="cf_sql_varchar" value="#contactName#">,
                            <cfqueryparam cfsqltype="cf_sql_varchar" value="#phone#">,
                            <cfqueryparam cfsqltype="cf_sql_varchar" value="#email#">
                        )
                    </cfquery>
                    <cfif structKeyExists(insertResult, "generatedKey")>
                        <cfset contactId = insertResult.generatedKey>
                    </cfif>
                </cfif>

                <cfset response = {
                    SUCCESS = true,
                    AUTH    = true,
                    CONTACTID = contactId
                }>
                <cfoutput>#serializeJSON(response)#</cfoutput>
                <cfsetting enablecfoutputonly="false">
                <cfabort>
            </cfif>

            <cfif action EQ "candelete">
                <cfset contactId = 0>
                <cfif structKeyExists(body, "contactId")>
                    <cfset contactId = val(body.contactId)>
                <cfelseif structKeyExists(body, "CONTACTID")>
                    <cfset contactId = val(body.CONTACTID)>
                <cfelseif structKeyExists(url, "contactId")>
                    <cfset contactId = val(url.contactId)>
                </cfif>

                <cfif contactId LTE 0>
                    <cfthrow message="Contact id is required.">
                </cfif>

                <cfquery name="qContactUsage" datasource="fpw">
                    SELECT fp.floatPlanName
                    FROM floatplan_contacts fc
                    INNER JOIN floatplans fp ON fp.floatplanId = fc.floatplanId
                    WHERE fc.contactId = <cfqueryparam cfsqltype="cf_sql_integer" value="#contactId#">
                      AND fp.userId = <cfqueryparam cfsqltype="cf_sql_integer" value="#userId#">
                </cfquery>

                <cfif qContactUsage.recordCount GT 0>
                    <cfset planNames = []>
                    <cfloop query="qContactUsage">
                        <cfset arrayAppend(planNames, qContactUsage.floatPlanName)>
                    </cfloop>
                    <cfset planCount = arrayLen(planNames)>
                    <cfset planList = arrayToList(planNames, ", ")>
                    <cfset response = {
                        SUCCESS = true,
                        AUTH    = true,
                        CANDELETE = false,
                        MESSAGE = "This contact is used in " & planCount & " float plan" & (planCount EQ 1 ? "" : "s") & ": " & planList & ". Edit the float plan to remove it before deleting."
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
                <cfset contactId = 0>
                <cfif structKeyExists(body, "contactId")>
                    <cfset contactId = val(body.contactId)>
                <cfelseif structKeyExists(body, "CONTACTID")>
                    <cfset contactId = val(body.CONTACTID)>
                <cfelseif structKeyExists(url, "contactId")>
                    <cfset contactId = val(url.contactId)>
                </cfif>

                <cfif contactId LTE 0>
                    <cfthrow message="Contact id is required.">
                </cfif>

                <cfquery name="qContactUsage" datasource="fpw">
                    SELECT fp.floatPlanName
                    FROM floatplan_contacts fc
                    INNER JOIN floatplans fp ON fp.floatplanId = fc.floatplanId
                    WHERE fc.contactId = <cfqueryparam cfsqltype="cf_sql_integer" value="#contactId#">
                      AND fp.userId = <cfqueryparam cfsqltype="cf_sql_integer" value="#userId#">
                </cfquery>

                <cfif qContactUsage.recordCount GT 0>
                    <cfset planNames = []>
                    <cfloop query="qContactUsage">
                        <cfset arrayAppend(planNames, qContactUsage.floatPlanName)>
                    </cfloop>
                    <cfset planCount = arrayLen(planNames)>
                    <cfset planList = arrayToList(planNames, ", ")>
                    <cfset response = {
                        SUCCESS = false,
                        AUTH    = true,
                        ERROR   = "IN_USE",
                        MESSAGE = "This contact is used in " & planCount & " float plan" & (planCount EQ 1 ? "" : "s") & ": " & planList & ". Edit the float plan to remove it before deleting."
                    }>
                    <cfoutput>#serializeJSON(response)#</cfoutput>
                    <cfsetting enablecfoutputonly="false">
                    <cfabort>
                </cfif>

                <cfquery datasource="fpw">
                    DELETE FROM contacts
                    WHERE contactId = <cfqueryparam cfsqltype="cf_sql_integer" value="#contactId#">
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
                    MESSAGE = "Contact API error.",
                    DETAIL  = cfcatch.message
                }>
                <cfoutput>#serializeJSON(errResponse)#</cfoutput>
            </cfcatch>

        </cftry>

        <cfsetting enablecfoutputonly="false">
    </cffunction>

</cfcomponent>
