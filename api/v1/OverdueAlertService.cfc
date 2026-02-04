<!--- /fpw/api/v1/OverdueAlertService.cfc (FULL DROP-IN)
      MULTI-TIER ESCALATION + SEND HIGHEST DUE TIER IMMEDIATELY + RETRY LIMITS
--->
<cfcomponent output="false">

    <cfset variables.MAX_ATTEMPTS = 3>

    <cffunction name="init" access="public" returntype="any" output="false">
        <cfreturn this>
    </cffunction>

    <cffunction name="getOverdueTiers" access="private" returntype="array" output="false">
        <cfset var tiers = []>

        <cfset arrayAppend(tiers, { "thresholdSeconds"=0,     "alertType"="DUE_NOW" })>
        <cfset arrayAppend(tiers, { "thresholdSeconds"=3600,  "alertType"="OVERDUE_1H" })>
        <cfset arrayAppend(tiers, { "thresholdSeconds"=7200,  "alertType"="OVERDUE_2H" })>
        <cfset arrayAppend(tiers, { "thresholdSeconds"=10800, "alertType"="OVERDUE_3H" })>
        <cfset arrayAppend(tiers, { "thresholdSeconds"=14400, "alertType"="OVERDUE_4H" })>
        <cfset arrayAppend(tiers, { "thresholdSeconds"=43200, "alertType"="OVERDUE_12H" })>
        <cfset arrayAppend(tiers, { "thresholdSeconds"=86400, "alertType"="OVERDUE_24H" })>

        <cfreturn tiers>
    </cffunction>

    <cffunction name="buildOverdueAlertJobs" access="public" returntype="array" output="false">
        <cfargument name="plans" type="array" required="true">

        <cfset var jobs  = []>
        <cfset var p     = {}>
        <cfset var tiers = getOverdueTiers()>
        <cfset var t     = {}>
        <cfset var overdue = 0>
        <cfset var bestTierType = "">

        <cfloop array="#arguments.plans#" index="p">

            <cfset bestTierType = "">

            <cfif structKeyExists(p,"FLOATPLANID") AND structKeyExists(p,"OVERDUE_SECONDS")>
                <cfset overdue = int(val(p.OVERDUE_SECONDS))>

                <cfif overdue GTE 0>

                    <!-- Highest eligible tier wins -->
                    <cfloop array="#tiers#" index="t">
                        <cfif overdue GTE int(val(t.thresholdSeconds))>
                            <cfset bestTierType = toString(t.alertType)>
                        <cfelse>
                            <cfbreak>
                        </cfif>
                    </cfloop>

                    <cfif len(bestTierType)>
                        <cfset ensureHistory(int(val(p.FLOATPLANID)), bestTierType)>

                        <cfif canAttempt(int(val(p.FLOATPLANID)), bestTierType)>
                            <cfset arrayAppend(jobs,{
                                "FLOATPLANID"     = int(val(p.FLOATPLANID)),
                                "ALERTTYPE"       = bestTierType,
                                "OVERDUE_SECONDS" = overdue
                            })>
                        </cfif>
                    </cfif>

                </cfif>
            </cfif>

        </cfloop>

        <cfreturn jobs>
    </cffunction>

    <cffunction name="getRecipientEmails" access="public" returntype="array" output="false">
        <cfargument name="floatPlanId" type="numeric" required="true">

        <cfset var emails = []>
        <cfset var seen = {}>
        <cfset var e = "">

        <!-- Owner email -->
        <cfquery name="qOwner" datasource="fpw">
            SELECT u.email
            FROM floatplans fp
            INNER JOIN users u ON u.userId = fp.userId
            WHERE fp.floatplanId = <cfqueryparam value="#int(arguments.floatPlanId)#" cfsqltype="cf_sql_integer">
            LIMIT 1
        </cfquery>

        <cfif qOwner.recordCount EQ 1 AND len(trim(qOwner.email))>
            <cfset e = lcase(trim(qOwner.email))>
            <cfif isValid("email", e) AND NOT structKeyExists(seen, e)>
                <cfset seen[e] = true>
                <cfset arrayAppend(emails, e)>
            </cfif>
        </cfif>

        <!-- Emergency contacts (schema-flex) -->
        <cftry>
            <cfquery name="qA" datasource="fpw">
                SELECT c.email
                FROM floatplan_contacts fc
                INNER JOIN contacts c ON c.contactId = fc.contactId
                WHERE fc.floatplanId = <cfqueryparam value="#int(arguments.floatPlanId)#" cfsqltype="cf_sql_integer">
                  AND (
                        (fc.isEmergency = 1)
                        OR (UPPER(fc.contactType) = 'EMERGENCY')
                        OR (UPPER(fc.role) = 'EMERGENCY')
                      )
            </cfquery>
            <cfloop query="qA">
                <cfif len(trim(qA.email))>
                    <cfset e = lcase(trim(qA.email))>
                    <cfif isValid("email", e) AND NOT structKeyExists(seen, e)>
                        <cfset seen[e] = true>
                        <cfset arrayAppend(emails, e)>
                    </cfif>
                </cfif>
            </cfloop>
            <cfcatch></cfcatch>
        </cftry>

        <cftry>
            <cfquery name="qB" datasource="fpw">
                SELECT c.email
                FROM floatplan_emergency_contacts fec
                INNER JOIN contacts c ON c.contactId = fec.contactId
                WHERE fec.floatplanId = <cfqueryparam value="#int(arguments.floatPlanId)#" cfsqltype="cf_sql_integer">
            </cfquery>
            <cfloop query="qB">
                <cfif len(trim(qB.email))>
                    <cfset e = lcase(trim(qB.email))>
                    <cfif isValid("email", e) AND NOT structKeyExists(seen, e)>
                        <cfset seen[e] = true>
                        <cfset arrayAppend(emails, e)>
                    </cfif>
                </cfif>
            </cfloop>
            <cfcatch></cfcatch>
        </cftry>

        <cftry>
            <cfquery name="qC" datasource="fpw">
                SELECT email
                FROM floatplan_emergency_emails
                WHERE floatplanId = <cfqueryparam value="#int(arguments.floatPlanId)#" cfsqltype="cf_sql_integer">
            </cfquery>
            <cfloop query="qC">
                <cfif len(trim(qC.email))>
                    <cfset e = lcase(trim(qC.email))>
                    <cfif isValid("email", e) AND NOT structKeyExists(seen, e)>
                        <cfset seen[e] = true>
                        <cfset arrayAppend(emails, e)>
                    </cfif>
                </cfif>
            </cfloop>
            <cfcatch></cfcatch>
        </cftry>

        <cfreturn emails>
    </cffunction>

    <cffunction name="sendOverdueEmail" access="public" returntype="void" output="false">
        <cfargument name="job" type="struct" required="true">

        <cfset var recipients = getRecipientEmails(arguments.job.FLOATPLANID)>
        <cfset var toList = arrayToList(recipients, ", ")>

        <cfif arrayLen(recipients) EQ 0>
            <cfthrow message="No recipients found for floatPlanId=#arguments.job.FLOATPLANID#">
        </cfif>

        <cfmail
            to="#toList#"
            from="alerts@fpw.test"
            subject="FPW Overdue Float Plan Alert (#arguments.job.ALERTTYPE#)"
            type="text">
Float Plan ID: #arguments.job.FLOATPLANID#
Alert Type: #arguments.job.ALERTTYPE#
Overdue Seconds: #arguments.job.OVERDUE_SECONDS#
Recipients: #toList#
        </cfmail>
    </cffunction>

    <!-- History -->
    <cffunction name="ensureHistory" access="public" returntype="void" output="false">
        <cfargument name="floatPlanId" type="numeric" required="true">
        <cfargument name="alertType" type="string" required="true">

        <cfquery datasource="fpw">
            INSERT INTO floatplan_alert_history
                (floatPlanId, alertType, status, attemptCount, lastAttemptAtUTC)
            VALUES
                (
                    <cfqueryparam value="#int(arguments.floatPlanId)#" cfsqltype="cf_sql_integer">,
                    <cfqueryparam value="#left(arguments.alertType,50)#" cfsqltype="cf_sql_varchar">,
                    'PENDING',
                    0,
                    UTC_TIMESTAMP()
                )
            ON DUPLICATE KEY UPDATE
                floatPlanId = floatPlanId
        </cfquery>
    </cffunction>

    <cffunction name="getHistory" access="public" returntype="struct" output="false">
        <cfargument name="floatPlanId" type="numeric" required="true">
        <cfargument name="alertType" type="string" required="true">

        <cfset var h = { "status"="", "attemptCount"=0 }>

        <cfquery name="qH" datasource="fpw">
            SELECT status, attemptCount
            FROM floatplan_alert_history
            WHERE floatPlanId = <cfqueryparam value="#int(arguments.floatPlanId)#" cfsqltype="cf_sql_integer">
              AND alertType   = <cfqueryparam value="#left(arguments.alertType,50)#" cfsqltype="cf_sql_varchar">
            LIMIT 1
        </cfquery>

        <cfif qH.recordCount EQ 1>
            <cfset h.status = toString(qH.status)>
            <cfset h.attemptCount = int(val(qH.attemptCount))>
        </cfif>

        <cfreturn h>
    </cffunction>

    <cffunction name="canAttempt" access="public" returntype="boolean" output="false">
        <cfargument name="floatPlanId" type="numeric" required="true">
        <cfargument name="alertType" type="string" required="true">

        <cfset var h = getHistory(arguments.floatPlanId, arguments.alertType)>

        <cfif ucase(h.status) EQ "SENT">
            <cfreturn false>
        </cfif>

        <cfif ucase(h.status) EQ "FAILED" AND int(h.attemptCount) GTE int(variables.MAX_ATTEMPTS)>
            <cfreturn false>
        </cfif>

        <cfreturn true>
    </cffunction>

    <cffunction name="markSent" access="public" returntype="void" output="false">
        <cfargument name="floatPlanId" type="numeric" required="true">
        <cfargument name="alertType" type="string" required="true">

        <cfquery datasource="fpw">
            UPDATE floatplan_alert_history
            SET status = 'SENT',
                attemptCount = attemptCount + 1,
                lastAttemptAtUTC = UTC_TIMESTAMP(),
                lastSentAtUTC = UTC_TIMESTAMP(),
                lastError = NULL
            WHERE floatPlanId = <cfqueryparam value="#int(arguments.floatPlanId)#" cfsqltype="cf_sql_integer">
              AND alertType   = <cfqueryparam value="#left(arguments.alertType,50)#" cfsqltype="cf_sql_varchar">
        </cfquery>
    </cffunction>

    <cffunction name="markFailed" access="public" returntype="void" output="false">
        <cfargument name="floatPlanId" type="numeric" required="true">
        <cfargument name="alertType" type="string" required="true">
        <cfargument name="errorMessage" type="string" required="true">

        <cfquery datasource="fpw">
            UPDATE floatplan_alert_history
            SET status = 'FAILED',
                attemptCount = attemptCount + 1,
                lastAttemptAtUTC = UTC_TIMESTAMP(),
                lastError = <cfqueryparam value="#left(arguments.errorMessage, 500)#" cfsqltype="cf_sql_varchar">
            WHERE floatPlanId = <cfqueryparam value="#int(arguments.floatPlanId)#" cfsqltype="cf_sql_integer">
              AND alertType   = <cfqueryparam value="#left(arguments.alertType,50)#" cfsqltype="cf_sql_varchar">
        </cfquery>
    </cffunction>

</cfcomponent>
