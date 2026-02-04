<!--- /fpw/api/v1/monitor.cfc (FULL DROP-IN) --->
<cfcomponent output="true">

    <cffunction name="runOverdueAlerts" access="remote" returntype="any" output="true">
        <cfargument name="token" type="string" required="false" default="">
        <cfargument name="send" type="numeric" required="false" default="0">

        <cfset var expected = "">
        <cfset var svc = "">
        <cfset var plans = []>
        <cfset var jobs  = []>
        <cfset var j     = {}>

        <cftry>

            <cfif structKeyExists(application,"monitorToken")>
                <cfset expected = trim(toString(application.monitorToken))>
            </cfif>

            <cfif NOT len(expected) OR trim(arguments.token) NEQ expected>
                <cfoutput>UNAUTHORIZED</cfoutput>
                <cfreturn>
            </cfif>

            <cfset var qClock = queryExecute("
                SELECT
                  UTC_TIMESTAMP() AS utcNow,
                  NOW() AS mysqlNow,
                  @@global.time_zone AS globalTZ,
                  @@session.time_zone AS sessionTZ
            ", {}, { datasource="fpw" })>

            <cfoutput>
==============================
FPW OVERDUE ALERT RUN (UTC)
CF now(): #now()#
send: #arguments.send#
==============================<br><br>

DB UTC_TIMESTAMP(): #qClock.utcNow#<br>
DB NOW(): #qClock.mysqlNow#<br>
DB global time_zone: #qClock.globalTZ#<br>
DB session time_zone: #qClock.sessionTZ#<br><br>
            </cfoutput>

            <!-- Summary counts -->
            <cfset var qCounts = queryExecute("
                SELECT
                    SUM(status='ACTIVE') AS activeTotal,
                    SUM(
                        status='ACTIVE'
                        AND returnTime IS NOT NULL
                        AND COALESCE(CONVERT_TZ(returnTime, NULLIF(returnTimezone, ''), 'UTC'), returnTime) <= UTC_TIMESTAMP()
                    ) AS activeOverdue,
                    SUM(
                        status='ACTIVE'
                        AND returnTime IS NOT NULL
                        AND COALESCE(CONVERT_TZ(returnTime, NULLIF(returnTimezone, ''), 'UTC'), returnTime) > UTC_TIMESTAMP()
                    ) AS activeNotOverdue
                FROM floatplans
            ", {}, { datasource="fpw" })>

            <cfoutput>
ACTIVE total: #qCounts.activeTotal#<br>
ACTIVE overdue: #qCounts.activeOverdue#<br>
ACTIVE NOT overdue: #qCounts.activeNotOverdue#<br><br>
            </cfoutput>

            <!-- Show NOT overdue plans -->
            <cfset var qNot = queryExecute("
                SELECT
                    floatplanId,
                    returnTime,
                    returnTimezone,
                    COALESCE(CONVERT_TZ(returnTime, NULLIF(returnTimezone, ''), 'UTC'), returnTime) AS returnUtc,
                    TIMESTAMPDIFF(
                        SECOND,
                        UTC_TIMESTAMP(),
                        COALESCE(CONVERT_TZ(returnTime, NULLIF(returnTimezone, ''), 'UTC'), returnTime)
                    ) AS secondsUntilDue
                FROM floatplans
                WHERE status='ACTIVE'
                  AND returnTime IS NOT NULL
                  AND COALESCE(CONVERT_TZ(returnTime, NULLIF(returnTimezone, ''), 'UTC'), returnTime) > UTC_TIMESTAMP()
                ORDER BY returnUtc ASC
                LIMIT 50
            ", {}, { datasource="fpw" })>

            <cfoutput>
<b>ACTIVE NOT overdue (future)</b><br>
Rows: #qNot.recordCount#<br>
            </cfoutput>

            <cfif qNot.recordCount GT 0>
                <cfoutput>
<table border="1" cellpadding="4" cellspacing="0">
<tr><th>floatplanId</th><th>returnTime</th><th>secondsUntilDue</th></tr>
                </cfoutput>
                <cfloop query="qNot">
                    <cfoutput>
<tr>
  <td>#qNot.floatplanId#</td>
  <td>#qNot.returnTime#</td>
  <td>#qNot.secondsUntilDue#</td>
</tr>
                    </cfoutput>
                </cfloop>
                <cfoutput></table><br><br></cfoutput>
            <cfelse>
                <cfoutput><i>None found.</i><br><br></cfoutput>
            </cfif>

            <!-- Overdue plans used for job building -->
            <cfset var qOver = queryExecute("
                SELECT
                    floatplanId,
                    returnTime,
                    returnTimezone,
                    COALESCE(CONVERT_TZ(returnTime, NULLIF(returnTimezone, ''), 'UTC'), returnTime) AS returnUtc,
                    TIMESTAMPDIFF(
                        SECOND,
                        COALESCE(CONVERT_TZ(returnTime, NULLIF(returnTimezone, ''), 'UTC'), returnTime),
                        UTC_TIMESTAMP()
                    ) AS overdueSeconds
                FROM floatplans
                WHERE status='ACTIVE'
                  AND returnTime IS NOT NULL
                  AND COALESCE(CONVERT_TZ(returnTime, NULLIF(returnTimezone, ''), 'UTC'), returnTime) <= UTC_TIMESTAMP()
                ORDER BY overdueSeconds DESC
                LIMIT 200
            ", {}, { datasource="fpw" })>

            <cfoutput>
<b>ACTIVE overdue (will be monitored)</b><br>
Rows (showing up to 200): #qOver.recordCount#<br><br>
            </cfoutput>

            <!-- Build plans array -->
            <cfloop query="qOver">
                <cfset arrayAppend(plans,{
                    "FLOATPLANID" = int(val(qOver.floatplanId)),
                    "OVERDUE_SECONDS" = int(val(qOver.overdueSeconds))
                })>
            </cfloop>

            <cfset svc  = createObject("component","fpw.api.v1.OverdueAlertService").init()>
            <cfset jobs = svc.buildOverdueAlertJobs(plans)>

            <cfoutput>
Jobs built: #arrayLen(jobs)#<br><br>
            </cfoutput>

            <cfloop array="#jobs#" index="j">
                <cfoutput>
JOB → plan=#j.FLOATPLANID# type=#j.ALERTTYPE# overdueSeconds=#j.OVERDUE_SECONDS#
                </cfoutput>

                <cfset queryExecute("
                    UPDATE floatplans
                    SET
                        status = :statusValue,
                        lastUpdateStatus = UTC_TIMESTAMP(),
                        lastUpdate = NOW()
                    WHERE floatplanId = :floatPlanId
                ", {
                    statusValue = { value = left(toString(j.ALERTTYPE), 50), cfsqltype = "cf_sql_varchar" },
                    floatPlanId = { value = int(val(j.FLOATPLANID)), cfsqltype = "cf_sql_integer" }
                }, { datasource = "fpw" })>
                <cfoutput> → STATUS UPDATED (#j.ALERTTYPE#)</cfoutput>

                <cfif arguments.send EQ 1>
                    <cftry>
                        <cfset svc.sendOverdueEmail(j)>
                        <cfset svc.markSent(j.FLOATPLANID, j.ALERTTYPE)>
                        <cfoutput> → EMAIL SENT + DB UPDATED</cfoutput>
                        <cfcatch>
                            <cfset svc.markFailed(j.FLOATPLANID, j.ALERTTYPE, cfcatch.message)>
                            <cfoutput> → FAILED: #htmlEditFormat(cfcatch.message)#</cfoutput>
                        </cfcatch>
                    </cftry>
                <cfelse>
                    <cfoutput> → DRY RUN</cfoutput>
                </cfif>

                <cfoutput><br></cfoutput>
            </cfloop>

            <cfcatch>
                <cfoutput>
<br><br>
==============================
MONITOR ERROR (CAUGHT)
==============================<br>
Message: #htmlEditFormat(cfcatch.message)#<br>
Detail: #htmlEditFormat(cfcatch.detail)#<br>
Type: #htmlEditFormat(cfcatch.type)#<br>
Template: #htmlEditFormat(cfcatch.template)#<br>
Line: #cfcatch.line#<br>
==============================<br>
                </cfoutput>
            </cfcatch>

        </cftry>

    </cffunction>

</cfcomponent>
