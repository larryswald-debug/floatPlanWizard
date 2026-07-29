<!--- /fpw/api/v1/OverdueAlertService.cfc (FULL DROP-IN)
      MULTI-TIER ESCALATION + SEND HIGHEST DUE TIER IMMEDIATELY + RETRY LIMITS
--->
<cfcomponent output="false">

    <cfset variables.MAX_ATTEMPTS = 3>

    <cffunction name="init" access="public" returntype="any" output="false">
        <cfreturn this>
    </cffunction>

    <cffunction name="buildOverdueAlertJobs" access="public" returntype="array" output="false">
        <cfargument name="plans" type="array" required="true">

        <cfreturn []>
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

	        <!-- Basic operational one-time contact snapshot -->
	        <cftry>
	            <cfquery name="qBasicContact" datasource="fpw">
	                SELECT notification_contact_email AS email
	                  FROM floatplan_basic_details
	                 WHERE floatplan_id = <cfqueryparam value="#int(arguments.floatPlanId)#" cfsqltype="cf_sql_integer">
	                 LIMIT 1
	            </cfquery>
	            <cfif qBasicContact.recordCount EQ 1 AND len(trim(qBasicContact.email))>
	                <cfset e = lcase(trim(qBasicContact.email))>
	                <cfif isValid("email", e) AND NOT structKeyExists(seen, e)>
	                    <cfset seen[e] = true>
	                    <cfset arrayAppend(emails, e)>
	                </cfif>
	            </cfif>
	            <cfcatch></cfcatch>
	        </cftry>

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

    <cffunction name="loadFloatPlanAlertContext" access="private" returntype="struct" output="false">
        <cfargument name="floatPlanId" type="numeric" required="true">

        <cfset var context = {
            FLOATPLANID = int( arguments.floatPlanId ),
            USERID = 0,
            PLANNAME = "",
            OWNEREMAIL = ""
        }>

        <cfquery name="qPlan" datasource="fpw">
            SELECT fp.floatplanId, fp.userId, fp.floatPlanName, u.email AS ownerEmail
            FROM floatplans fp
            INNER JOIN users u ON u.userId = fp.userId
            WHERE fp.floatplanId = <cfqueryparam value="#int(arguments.floatPlanId)#" cfsqltype="cf_sql_integer">
            LIMIT 1
        </cfquery>

        <cfif qPlan.recordCount EQ 1>
            <cfset context.FLOATPLANID = int( qPlan.floatplanId )>
            <cfset context.USERID = int( qPlan.userId )>
            <cfset context.PLANNAME = trim( toString( qPlan.floatPlanName ) )>
            <cfset context.OWNEREMAIL = trim( toString( qPlan.ownerEmail ) )>
        </cfif>

        <cfreturn context>
    </cffunction>

    <cffunction name="getOwnerAlertEmails" access="private" returntype="array" output="false">
        <cfargument name="planContext" type="struct" required="true">

        <cfset var emails = []>
        <cfset var ownerEmail = lcase( trim( toString( arguments.planContext.OWNEREMAIL ) ) )>

        <cfif len( ownerEmail ) AND isValid( "email", ownerEmail )>
            <cfset arrayAppend( emails, ownerEmail )>
        </cfif>

        <cfreturn emails>
    </cffunction>

    <cffunction name="getSelectedContactEmails" access="private" returntype="array" output="false">
        <cfargument name="planContext" type="struct" required="true">

        <cfset var emails = []>
        <cfset var seen = {}>
        <cfset var e = "">

	        <cfif int( arguments.planContext.FLOATPLANID ) LTE 0 OR int( arguments.planContext.USERID ) LTE 0>
	            <cfreturn emails>
	        </cfif>

	        <cftry>
	            <cfquery name="qBasicContact" datasource="fpw">
	                SELECT notification_contact_email AS email
	                  FROM floatplan_basic_details
	                 WHERE floatplan_id = <cfqueryparam value="#int(arguments.planContext.FLOATPLANID)#" cfsqltype="cf_sql_integer">
	                 LIMIT 1
	            </cfquery>
	            <cfif qBasicContact.recordCount EQ 1 AND len( trim( qBasicContact.email ) )>
	                <cfset e = lcase( trim( qBasicContact.email ) )>
	                <cfif isValid( "email", e ) AND NOT structKeyExists( seen, e )>
	                    <cfset seen[ e ] = true>
	                    <cfset arrayAppend( emails, e )>
	                </cfif>
	            </cfif>
	            <cfcatch></cfcatch>
	        </cftry>

	        <cfquery name="qContacts" datasource="fpw">
            SELECT c.email
            FROM floatplan_contacts fc
            INNER JOIN floatplans fp ON fp.floatplanId = fc.floatplanId
            INNER JOIN contacts c ON c.contactId = fc.contactId
            WHERE fp.userId = <cfqueryparam value="#int(arguments.planContext.USERID)#" cfsqltype="cf_sql_integer">
              AND fp.floatplanId = <cfqueryparam value="#int(arguments.planContext.FLOATPLANID)#" cfsqltype="cf_sql_integer">
            ORDER BY fc.recId ASC
        </cfquery>

        <cfloop query="qContacts">
            <cfif len( trim( qContacts.email ) )>
                <cfset e = lcase( trim( qContacts.email ) )>
                <cfif isValid( "email", e ) AND NOT structKeyExists( seen, e )>
                    <cfset seen[ e ] = true>
                    <cfset arrayAppend( emails, e )>
                </cfif>
            </cfif>
        </cfloop>

        <cfreturn emails>
    </cffunction>

    <cffunction name="buildMonitoringCycleAlertType" access="private" returntype="string" output="false">
        <cfargument name="prefix" type="string" required="true">
        <cfargument name="monitoringId" type="numeric" required="true">
        <cfargument name="cycleAt" required="true">

        <cfset var normalizedPrefix = uCase( trim( arguments.prefix ) )>
        <cfset var cycleStamp = isDate( arguments.cycleAt ) ? dateTimeFormat( arguments.cycleAt, "yyyymmddHHnnss" ) : "unknown">
        <cfset var fullAlertType = normalizedPrefix & "_" & int( arguments.monitoringId ) & "_" & cycleStamp>
        <cfset var compactCycleStamp = isDate( arguments.cycleAt ) ? dateTimeFormat( arguments.cycleAt, "yymmddHHnnss" ) : "unknown">
        <cfset var compactAlertType = normalizedPrefix & "_" & compactCycleStamp>

        <cfif len( fullAlertType ) LTE 32>
            <cfreturn fullAlertType>
        </cfif>

        <cfif len( compactAlertType ) LTE 32>
            <cfreturn compactAlertType>
        </cfif>

        <cfreturn left( compactAlertType, 32 )>
    </cffunction>

    <cffunction name="buildMonitoringPlanName" access="private" returntype="string" output="false">
        <cfargument name="planContext" type="struct" required="true">

        <cfif len( trim( toString( arguments.planContext.PLANNAME ) ) )>
            <cfreturn trim( toString( arguments.planContext.PLANNAME ) )>
        </cfif>

        <cfreturn "Float Plan ##" & int( arguments.planContext.FLOATPLANID )>
    </cffunction>

    <cffunction name="buildMonitoringTimestampLabel" access="private" returntype="string" output="false">
        <cfargument name="eventAt" required="true">

        <cfif isDate( arguments.eventAt )>
            <cfreturn dateTimeFormat( arguments.eventAt, "mmm d, yyyy h:nn tt" )>
        </cfif>

        <cfreturn dateTimeFormat( now(), "mmm d, yyyy h:nn tt" )>
    </cffunction>

    <cffunction name="sendMonitoringMissedOwnerEmail" access="public" returntype="struct" output="false">
        <cfargument name="floatPlanId" type="numeric" required="true">
        <cfargument name="monitoringId" type="numeric" required="true">
        <cfargument name="missedAt" required="true">

        <cfset var context = loadFloatPlanAlertContext( arguments.floatPlanId )>
        <cfset var alertType = buildMonitoringCycleAlertType( "MISSED_OWNER", arguments.monitoringId, arguments.missedAt )>
        <cfset var recipients = []>
        <cfset var toList = "">
        <cfset var planName = buildMonitoringPlanName( context )>
        <cfset var eventLabel = buildMonitoringTimestampLabel( arguments.missedAt )>
        <cfset var subject = "FPW Automated Notice: Scheduled Check-In Not Recorded - " & planName>
        <cfset var body = "">

        <cfset ensureHistory( int( arguments.floatPlanId ), alertType )>

        <cfif int( context.USERID ) LTE 0>
            <cfset markFailed( int( arguments.floatPlanId ), alertType, "Float plan context not found for missed owner alert." )>
            <cfreturn {
                "SUCCESS" = false,
                "ERROR" = "CONTEXT_NOT_FOUND",
                "ALERTTYPE" = alertType,
                "RECIPIENT_COUNT" = 0,
                "RECIPIENTS" = []
            }>
        </cfif>

        <cfif NOT canAttempt( int( arguments.floatPlanId ), alertType )>
            <cfreturn {
                "SUCCESS" = true,
                "SKIPPED" = true,
                "ALERTTYPE" = alertType,
                "RECIPIENT_COUNT" = 0,
                "RECIPIENTS" = []
            }>
        </cfif>

        <cfset recipients = getOwnerAlertEmails( context )>
        <cfset toList = arrayToList( recipients, ", " )>
        <cfset body = "Notice Source: FPW automated check-in status" & chr(10)
            & "Status: Scheduled Check-In Not Recorded" & chr(10)
            & "Float Plan: " & planName & chr(10)
            & "Timestamp: " & eventLabel & chr(10)
            & "Float Plan ID: " & int( arguments.floatPlanId ) & chr(10)
            & "Recipients: " & toList & chr(10) & chr(10)
            & "FPW's automated system did not record the expected check-in by the scheduled time. This may reflect a missed check-in, delayed reporting, connectivity problems, or other circumstances." & chr(10)
            & "Attempt to contact the captain and follow the response plan you agreed upon." & chr(10)
            & "FPW has not independently verified an emergency and does not dispatch assistance." & chr(10)
            & "Electronic-message delivery and receipt are not guaranteed.">

        <cfif arrayLen( recipients ) EQ 0>
            <cfset markFailed( int( arguments.floatPlanId ), alertType, "No owner/captain email found for missed monitoring alert." )>
            <cfreturn {
                "SUCCESS" = false,
                "ERROR" = "NO_RECIPIENTS",
                "ALERTTYPE" = alertType,
                "RECIPIENT_COUNT" = 0,
                "RECIPIENTS" = []
            }>
        </cfif>

        <cftry>
            <cfmail
                to="#toList#"
                from="alerts@fpw.test"
                subject="#subject#"
                type="text">#body#
            </cfmail>
            <cfset markSent( int( arguments.floatPlanId ), alertType )>
            <cfreturn {
                "SUCCESS" = true,
                "ALERTTYPE" = alertType,
                "RECIPIENT_COUNT" = arrayLen( recipients ),
                "RECIPIENTS" = duplicate( recipients )
            }>
            <cfcatch>
                <cfset markFailed( int( arguments.floatPlanId ), alertType, cfcatch.message )>
                <cfreturn {
                    "SUCCESS" = false,
                    "ERROR" = "SEND_FAILED",
                    "MESSAGE" = cfcatch.message,
                    "ALERTTYPE" = alertType,
                    "RECIPIENT_COUNT" = arrayLen( recipients ),
                    "RECIPIENTS" = duplicate( recipients )
                }>
            </cfcatch>
        </cftry>
    </cffunction>

    <cffunction name="sendMonitoringEscalatedContactEmail" access="public" returntype="struct" output="false">
        <cfargument name="floatPlanId" type="numeric" required="true">
        <cfargument name="monitoringId" type="numeric" required="true">
        <cfargument name="escalatedAt" required="true">

        <cfset var context = loadFloatPlanAlertContext( arguments.floatPlanId )>
        <cfset var alertType = buildMonitoringCycleAlertType( "ESCALATED_CONTACTS", arguments.monitoringId, arguments.escalatedAt )>
        <cfset var recipients = []>
        <cfset var toList = "">
        <cfset var planName = buildMonitoringPlanName( context )>
        <cfset var eventLabel = buildMonitoringTimestampLabel( arguments.escalatedAt )>
        <cfset var subject = "FPW Automated Notice: Check-In Still Unresolved - " & planName>
        <cfset var body = "">

        <cfset ensureHistory( int( arguments.floatPlanId ), alertType )>

        <cfif int( context.USERID ) LTE 0>
            <cfset markFailed( int( arguments.floatPlanId ), alertType, "Float plan context not found for escalated contact alert." )>
            <cfreturn {
                "SUCCESS" = false,
                "ERROR" = "CONTEXT_NOT_FOUND",
                "ALERTTYPE" = alertType,
                "RECIPIENT_COUNT" = 0,
                "RECIPIENTS" = []
            }>
        </cfif>

        <cfif NOT canAttempt( int( arguments.floatPlanId ), alertType )>
            <cfreturn {
                "SUCCESS" = true,
                "SKIPPED" = true,
                "ALERTTYPE" = alertType,
                "RECIPIENT_COUNT" = 0,
                "RECIPIENTS" = []
            }>
        </cfif>

        <cfset recipients = getSelectedContactEmails( context )>
        <cfset toList = arrayToList( recipients, ", " )>
        <cfset body = "Notice Source: FPW automated check-in status" & chr(10)
            & "Status: Check-In Still Unresolved" & chr(10)
            & "Float Plan: " & planName & chr(10)
            & "Timestamp: " & eventLabel & chr(10)
            & "Float Plan ID: " & int( arguments.floatPlanId ) & chr(10)
            & "Recipients: " & toList & chr(10) & chr(10)
            & "The scheduled check-in remains unresolved after the configured monitoring delay. This is an automated trip status, not confirmation of distress or professional emergency escalation." & chr(10)
            & "Attempt to contact the captain and follow the response plan you agreed upon." & chr(10)
            & "FPW has not independently verified an emergency and does not dispatch assistance." & chr(10)
            & "Electronic-message delivery and receipt are not guaranteed.">

        <cfif arrayLen( recipients ) EQ 0>
            <cfset markFailed( int( arguments.floatPlanId ), alertType, "No selected contact emails found for escalated monitoring alert." )>
            <cfreturn {
                "SUCCESS" = false,
                "ERROR" = "NO_RECIPIENTS",
                "ALERTTYPE" = alertType,
                "RECIPIENT_COUNT" = 0,
                "RECIPIENTS" = []
            }>
        </cfif>

        <cftry>
            <cfmail
                to="#toList#"
                from="alerts@fpw.test"
                subject="#subject#"
                type="text">#body#
            </cfmail>
            <cfset markSent( int( arguments.floatPlanId ), alertType )>
            <cfreturn {
                "SUCCESS" = true,
                "ALERTTYPE" = alertType,
                "RECIPIENT_COUNT" = arrayLen( recipients ),
                "RECIPIENTS" = duplicate( recipients )
            }>
            <cfcatch>
                <cfset markFailed( int( arguments.floatPlanId ), alertType, cfcatch.message )>
                <cfreturn {
                    "SUCCESS" = false,
                    "ERROR" = "SEND_FAILED",
                    "MESSAGE" = cfcatch.message,
                    "ALERTTYPE" = alertType,
                    "RECIPIENT_COUNT" = arrayLen( recipients ),
                    "RECIPIENTS" = duplicate( recipients )
                }>
            </cfcatch>
        </cftry>
    </cffunction>

    <cffunction name="sendOverdueEmail" access="public" returntype="void" output="false">
        <cfargument name="job" type="struct" required="true">

        <cfthrow message="Legacy overdue email path is retired." detail="Use canonical monitoring-cycle alerts from floatplan_monitoring.">
    </cffunction>

    <cffunction name="sendAssistanceNeededEmail" access="public" returntype="struct" output="false">
        <cfargument name="floatPlanId" type="numeric" required="true">
        <cfargument name="planName" type="string" required="false" default="">
        <cfargument name="checkinAt" required="false">
        <cfargument name="note" type="string" required="false" default="">

        <cfset var alertType = "ASSISTANCE_NEEDED">
        <cfset var recipients = getRecipientEmails(arguments.floatPlanId)>
        <cfset var toList = arrayToList(recipients, ", ")>
        <cfset var resolvedPlanName = trim(arguments.planName)>
        <cfset var checkinLabel = dateTimeFormat(now(), "mmm d, yyyy h:nn tt")>
        <cfset var noteLine = "">
        <cfif !len(resolvedPlanName)>
            <cfset resolvedPlanName = "Float Plan ##" & int(arguments.floatPlanId)>
        </cfif>
        <cfif isDate(arguments.checkinAt)>
            <cfset checkinLabel = dateTimeFormat(arguments.checkinAt, "mmm d, yyyy h:nn tt")>
        </cfif>
        <cfif len(trim(arguments.note))>
            <cfset noteLine = "Captain Note: " & trim(arguments.note) & chr(10)>
        </cfif>
        <cfset var subject = "FPW Notice: Captain Reported Assistance May Be Needed - " & resolvedPlanName>
        <cfset var body = "Notice Source: Captain-reported status" & chr(10)
            & "Status: Assistance May Be Needed" & chr(10)
            & "Float Plan: " & resolvedPlanName & chr(10)
            & "Timestamp: " & checkinLabel & chr(10)
            & noteLine
            & "Float Plan ID: " & int(arguments.floatPlanId) & chr(10)
            & "Recipients: " & toList & chr(10) & chr(10)
            & "The captain reported a status indicating that assistance may be needed. FPW is relaying the reported information; it has not independently verified the situation and does not dispatch assistance." & chr(10)
            & "Electronic-message delivery and receipt are not guaranteed.">

        <cfset ensureHistory(int(arguments.floatPlanId), alertType)>

        <cfif arrayLen(recipients) EQ 0>
            <cfset markFailed(int(arguments.floatPlanId), alertType, "No recipients found for assistance alert.")>
            <cfthrow message="No recipients found for floatPlanId=#arguments.floatPlanId#">
        </cfif>

        <cftry>
            <cfmail
                to="#toList#"
                from="alerts@fpw.test"
                subject="#subject#"
                type="text">#body#
            </cfmail>
            <cfset markSent(int(arguments.floatPlanId), alertType)>
            <cfreturn {
                "SUCCESS" = true,
                "RECIPIENT_COUNT" = arrayLen(recipients)
            }>
            <cfcatch>
                <cfset markFailed(int(arguments.floatPlanId), alertType, cfcatch.message)>
                <cfthrow message="#cfcatch.message#" detail="#cfcatch.detail#">
            </cfcatch>
        </cftry>
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
                sentAtUTC = UTC_TIMESTAMP(),
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
