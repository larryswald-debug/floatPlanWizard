<cfcomponent output="false">

    <!--- ==============================
         INIT
         ============================== --->
    <cffunction name="init" access="public" returntype="any" output="true">
        <cfset variables.timeZoneClass  = createObject("java", "java.util.TimeZone")>
        <cfset variables.calendarClass  = createObject("java", "java.util.Calendar")>
        <cfset variables.dateClass      = createObject("java", "java.util.Date")>

        <cfreturn this>
    </cffunction>


    <!--- ==============================
         CHECK OVERDUE FLOAT PLANS
         ============================== --->


<cffunction name="checkOverdueFloatPlansMonitor" access="remote" returntype="any" output="true">
    <cfsetting enablecfoutputonly="true" showdebugoutput="false">
    <cfcontent type="application/json; charset=utf-8">

    <cfset var result = { "SUCCESS"=true, "COUNT"=0, "PLANS"=[], "ERROR"="", "GENERATED_AT_UTC"="" }>
    <cfset var plans = []>
    <cfset var row = {}>

    <cftry>
        <!--- Query overdue plans (same logic, but return structured data) --->
        <cfquery name="qOverdue" datasource="fpw">
            SELECT
                floatplanId,
                userId,
                floatPlanName,
                status,
                returnTime,
                returnTimezone,
                checkedInAt,
                CONVERT_TZ(returnTime, NULLIF(returnTimezone, ''), @@session.time_zone) AS returnTimeLocal,
                @@session.time_zone AS sessionTimeZone,
                NOW() AS nowLocal,
                CASE
                    WHEN returnTimezone IS NULL OR TRIM(returnTimezone) = '' THEN 1
                    WHEN CONVERT_TZ(returnTime, NULLIF(returnTimezone, ''), @@session.time_zone) IS NULL THEN 1
                    ELSE 0
                END AS tzConvertFailed
            FROM floatplans
            WHERE UPPER(TRIM(status)) = 'ACTIVE'
              AND returnTime IS NOT NULL
              AND COALESCE(
                    CONVERT_TZ(returnTime, NULLIF(returnTimezone, ''), @@session.time_zone),
                    returnTime
              ) < NOW()
            ORDER BY returnTime ASC
        </cfquery>

        <cfset result["COUNT"] = qOverdue.recordCount>

        <!--- Generated time in UTC string for monitoring logs --->
        <cfset result["GENERATED_AT_UTC"] = dateTimeFormat(dateConvert("local2Utc", now()), "yyyy-mm-dd HH:nn:ss") & "Z">

        <!--- Build array payload --->
        <cfloop query="qOverdue">
            <!--- Choose the effective return time used for overdue calc --->
            <cfset var effectiveReturn = qOverdue.returnTimeLocal>
            <cfif NOT isDate(effectiveReturn)>
                <cfset effectiveReturn = qOverdue.returnTime>
            </cfif>

            <cfset var overdueSeconds = 0>
            <cfif isDate(effectiveReturn)>
                <cfset overdueSeconds = dateDiff("s", effectiveReturn, now())>
                <cfif overdueSeconds LT 0>
                    <cfset overdueSeconds = 0>
                </cfif>
            </cfif>

            <cfset row = {
                "FLOATPLANID" = qOverdue.floatplanId,
                "USERID" = qOverdue.userId,
                "NAME" = toString(qOverdue.floatPlanName),
                "STATUS" = toString(qOverdue.status),
                "RETURNTIME_RAW" = (isDate(qOverdue.returnTime) ? dateTimeFormat(qOverdue.returnTime, "yyyy-mm-dd HH:nn:ss") : toString(qOverdue.returnTime)),
                "RETURNTIME_CONVERTED" = (isDate(qOverdue.returnTimeLocal) ? dateTimeFormat(qOverdue.returnTimeLocal, "yyyy-mm-dd HH:nn:ss") : ""),
                "RETURNTZ" = toString(qOverdue.returnTimezone),
                "TZCONVERTFAILED" = (val(qOverdue.tzConvertFailed) EQ 1),
                "OVERDUE_SECONDS" = overdueSeconds
            }>

            <cfset arrayAppend(plans, row)>
        </cfloop>

        <cfset result["PLANS"] = plans>

        <cfoutput>#serializeJSON(result)#</cfoutput>

        <cfcatch type="any">
            <cfset result["SUCCESS"] = false>
            <cfset result["ERROR"] = toString(cfcatch.message) & " | " & toString(cfcatch.detail)>
            <cfoutput>#serializeJSON(result)#</cfoutput>
        </cfcatch>
    </cftry>

    <cfsetting enablecfoutputonly="true">
</cffunction>








    <cffunction name="checkOverdueFloatPlans" access="remote" returntype="any" output="true">
    <cfsetting enablecfoutputonly="true" showdebugoutput="false">
    <cfcontent type="text/html; charset=utf-8">

    <cftry>
        <cfquery name="qOverdue" datasource="fpw">
            SELECT
                floatplanId,
                userId,
                floatPlanName,
                status,
                returnTime,
                returnTimezone,
                checkedInAt,

                CONVERT_TZ(returnTime, NULLIF(returnTimezone, ''), @@session.time_zone) AS returnTimeLocal,
                @@session.time_zone AS sessionTimeZone,
                NOW() AS nowLocal,

                CASE
                    WHEN returnTimezone IS NULL OR TRIM(returnTimezone) = '' THEN 1
                    WHEN CONVERT_TZ(returnTime, NULLIF(returnTimezone, ''), @@session.time_zone) IS NULL THEN 1
                    ELSE 0
                END AS tzConvertFailed

            FROM floatplans
            WHERE UPPER(TRIM(status)) = 'ACTIVE'
              AND returnTime IS NOT NULL
              AND COALESCE(
                    CONVERT_TZ(returnTime, NULLIF(returnTimezone, ''), @@session.time_zone),
                    returnTime
              ) < NOW()
            ORDER BY returnTime ASC
        </cfquery>

        <cfset nowTs = now()>

        <cfoutput>
            <h3>Overdue float plans: #qOverdue.recordCount#</h3>

            <p style="margin:0 0 12px 0;">
                DB session TZ: <b>#encodeForHTML(toString(qOverdue.sessionTimeZone))#</b>
                &nbsp; | &nbsp;
                DB NOW(): <b>#dateTimeFormat(qOverdue.nowLocal, "yyyy-mm-dd HH:nn:ss")#</b>
                &nbsp; | &nbsp;
                CF NOW(): <b>#dateTimeFormat(nowTs, "yyyy-mm-dd HH:nn:ss")#</b>
            </p>

            <table border="1" cellpadding="6" cellspacing="0">
                <tr>
                    <th>FloatPlanId</th>
                    <th>UserId</th>
                    <th>Name</th>
                    <th>ReturnTime (raw)</th>
                    <th>ReturnTime (converted)</th>
                    <th>Return TZ</th>
                    <th>TZ Convert Failed?</th>
                    <th>Overdue By</th>
                </tr>

                <cfloop query="qOverdue">
                    <cfset overdueSeconds = 0>
                    <cfset overdueText = "n/a">
                    <cfset days = 0>
                    <cfset hours = 0>
                    <cfset minutes = 0>

                    <!--- Use converted time if available; otherwise raw --->
                    <cfset effectiveReturn = qOverdue.returnTimeLocal>
                    <cfif NOT isDate(effectiveReturn)>
                        <cfset effectiveReturn = qOverdue.returnTime>
                    </cfif>

                    <cfif isDate(effectiveReturn)>
                        <cfset overdueSeconds = dateDiff("s", effectiveReturn, nowTs)>
                        <cfif overdueSeconds LT 0>
                            <cfset overdueSeconds = 0>
                        </cfif>

                        <cfset days = int(overdueSeconds / 86400)>
                        <cfset hours = int((overdueSeconds mod 86400) / 3600)>
                        <cfset minutes = int((overdueSeconds mod 3600) / 60)>

                        <cfset overdueText = days & "d " & hours & "h " & minutes & "m">
                    </cfif>

                    <tr>
                        <td>#qOverdue.floatplanId#</td>
                        <td>#qOverdue.userId#</td>
                        <td>#encodeForHTML(toString(qOverdue.floatPlanName))#</td>

                        <td>
                            <cfif isDate(qOverdue.returnTime)>
                                #dateTimeFormat(qOverdue.returnTime, "yyyy-mm-dd HH:nn:ss")#
                            <cfelse>
                                #encodeForHTML(toString(qOverdue.returnTime))#
                            </cfif>
                        </td>

                        <td>
                            <cfif isDate(qOverdue.returnTimeLocal)>
                                #dateTimeFormat(qOverdue.returnTimeLocal, "yyyy-mm-dd HH:nn:ss")#
                            <cfelse>
                                <i>n/a</i>
                            </cfif>
                        </td>

                        <td>#encodeForHTML(toString(qOverdue.returnTimezone))#</td>

                        <td style="text-align:center;">
                            <cfif val(qOverdue.tzConvertFailed) EQ 1>
                                <b>YES</b>
                            <cfelse>
                                NO
                            </cfif>
                        </td>

                        <td>#encodeForHTML(toString(overdueText))#</td>
                    </tr>
                </cfloop>
            </table>
        </cfoutput>

        <cfcatch type="any">
            <cfoutput>
                <pre>ERROR: #encodeForHTML(toString(cfcatch.message))#</pre>
                <pre>DETAIL: #encodeForHTML(toString(cfcatch.detail))#</pre>
            </cfoutput>
        </cfcatch>
    </cftry>

    <cfsetting enablecfoutputonly="false">
</cffunction>






    <!--- ==============================
         LOCAL → UTC CONVERSION
         ============================== --->

<cffunction name="utcToLocalString" access="remote" returntype="string" output="true">
    <cfargument name="utcTime"  type="string" required="true">
    <cfargument name="timeZone" type="string" required="true">

    <cfsetting enablecfoutputonly="true" showdebugoutput="false">
    <cfcontent type="text/plain; charset=utf-8">

    <cfset var tzLocal  = createObject("java","java.util.TimeZone").getTimeZone(arguments.timeZone)>
    <cfset var tzUTC    = createObject("java","java.util.TimeZone").getTimeZone("UTC")>
    <cfset var calUTC   = createObject("java","java.util.Calendar").getInstance(tzUTC)>
    <cfset var sdf      = createObject("java","java.text.SimpleDateFormat").init("yyyy-MM-dd HH:mm:ss")>
    <cfset var parsed   = 0>
    <cfset var millis   = 0>
    <cfset var jDate    = 0>
    <cfset var result   = "">

    <cftry>
        <!--- Parse the incoming string to a CF date/time --->
        <cfset parsed = parseDateTime(arguments.utcTime)>

        <!--- Convert CF date/time into a Java instant (millis) using a UTC calendar --->
        <cfset calUTC.setTime(parsed)>
        <cfset millis = calUTC.getTimeInMillis()>

        <!--- Build a real java.util.Date from millis --->
        <cfset jDate = createObject("java","java.util.Date").init(millis)>

        <!--- Format that instant in the requested LOCAL timezone --->
        <cfset sdf.setTimeZone(tzLocal)>
        <cfset result = sdf.format(jDate)>

        <cfoutput>#result#</cfoutput>
        <cfreturn result>

        <cfcatch type="any">
    <cfoutput>ERROR: #htmlCodeFormat(cfcatch.message)#</cfoutput>
    <cfreturn "ERROR: " & cfcatch.message>
</cfcatch>
    </cftry>

    <cfsetting enablecfoutputonly="false">
</cffunction>




</cfcomponent>
