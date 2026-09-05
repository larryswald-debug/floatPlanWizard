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
	                <cfset memberGateResult = getMemberAccessGateService().requirePlanningAccess(userId)>
	                <cfif NOT memberGateResult.allowed>
	                    <cfoutput>#serializeJSON(memberGateResult.response)#</cfoutput>
	                    <cfsetting enablecfoutputonly="false">
	                    <cfabort>
	                </cfif>

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

                <!--- Required activity and the owned save share one commit. Projections stay in memory. --->
                <cfset local.activityWasCreate = contactId LTE 0>
                <cftransaction>
                    <cfquery name="local.activityOwner" datasource="fpw">
                        SELECT userId FROM users
                        WHERE userId = <cfqueryparam cfsqltype="cf_sql_integer" value="#userId#">
                        FOR UPDATE
                    </cfquery>
                    <cfif local.activityOwner.recordCount NEQ 1>
                        <cfthrow type="FPW.MemberActivity.Ownership" message="The saved item is unavailable.">
                    </cfif>
                    <cfquery name="local.activityBefore" datasource="fpw">
                        SELECT JSON_ARRAY(name,phone,email) AS projection
                        FROM contacts
                        WHERE contactId = <cfqueryparam cfsqltype="cf_sql_integer" value="#contactId#">
                          AND userId = <cfqueryparam cfsqltype="cf_sql_integer" value="#userId#">
                        FOR UPDATE
                    </cfquery>
                    <cfif NOT local.activityWasCreate AND local.activityBefore.recordCount NEQ 1>
                        <cfthrow type="FPW.MemberActivity.Ownership" message="The saved item is unavailable.">
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
                    <cfquery name="local.activityAfter" datasource="fpw">
                        SELECT JSON_ARRAY(name,phone,email) AS projection
                        FROM contacts
                        WHERE contactId = <cfqueryparam cfsqltype="cf_sql_integer" value="#contactId#">
                          AND userId = <cfqueryparam cfsqltype="cf_sql_integer" value="#userId#">
                        FOR UPDATE
                    </cfquery>
                    <cfif local.activityAfter.recordCount NEQ 1>
                        <cfthrow type="FPW.MemberActivity.Unconfirmed" message="Your change could not be saved.">
                    </cfif>
                    <cfif local.activityWasCreate OR compare(local.activityBefore.projection[1], local.activityAfter.projection[1]) NEQ 0>
                        <cfset getMemberActivityEventService("fpw").recordRequiredMemberActivity(
                            userId, local.activityWasCreate ? "shore_contact_created" : "shore_contact_updated", contactId
                        )>
                    </cfif>
                </cftransaction>

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

	    <cffunction name="getMemberAccessGateService" access="private" returntype="any" output="false">
	        <cftry>
	            <cfreturn createObject("component", "fpw.api.v1.MemberAccessGateService").init("fpw")>
	            <cfcatch>
	                <cfreturn createObject("component", "api.v1.MemberAccessGateService").init("fpw")>
	            </cfcatch>
	        </cftry>
	    </cffunction>

    <cffunction name="getMemberActivityEventService" access="private" returntype="any" output="false">
        <cfargument name="datasource" type="string" required="true">
        <cfreturn createObject("component","fpw.includes.ProductEventService").init(arguments.datasource)>
    </cffunction>
</cfcomponent>
