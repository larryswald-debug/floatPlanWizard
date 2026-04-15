<cfcomponent output="false">

    <cffunction name="init" access="public" returntype="any" output="false">
        <cfscript>
            variables.localDayStartRule = buildLocalDayStartRule("08:00:00");
            return this;
        </cfscript>
    </cffunction>

    <cffunction name="getLocalDayStartRule" access="public" returntype="struct" output="false">
        <cfargument name="localTimeValue" type="any" required="false" default="">
        <cfscript>
            if (len(trim(toString(arguments.localTimeValue)))) {
                return buildLocalDayStartRule(arguments.localTimeValue);
            }
            return duplicate(variables.localDayStartRule);
        </cfscript>
    </cffunction>

    <cffunction name="normalizeLocalDayStartTime" access="public" returntype="string" output="false">
        <cfargument name="rawValue" type="any" required="false" default="">
        <cfscript>
            var raw = trim(toString(arguments.rawValue));
            var parts = [];
            var hourVal = 0;
            var minuteVal = 0;
            var secondVal = 0;

            if (!len(raw) OR !reFind("^\d{1,2}:\d{2}(:\d{2})?$", raw)) {
                return "";
            }

            parts = listToArray(raw, ":");
            hourVal = val(parts[1]);
            minuteVal = val(parts[2]);
            secondVal = (arrayLen(parts) GTE 3 ? val(parts[3]) : 0);

            if (
                hourVal LT 0 OR hourVal GT 23
                OR minuteVal LT 0 OR minuteVal GT 59
                OR secondVal LT 0 OR secondVal GT 59
            ) {
                return "";
            }

            return numberFormat(hourVal, "00") & ":" & numberFormat(minuteVal, "00") & ":" & numberFormat(secondVal, "00");
        </cfscript>
    </cffunction>

    <cffunction name="buildLocalDayStartRule" access="private" returntype="struct" output="false">
        <cfargument name="localTimeValue" type="any" required="false" default="">
        <cfscript>
            var normalizedTime = normalizeLocalDayStartTime(arguments.localTimeValue);
            var timeSql = (len(normalizedTime) ? normalizedTime : "08:00:00");
            var parts = listToArray(timeSql, ":");
            var hourVal = val(parts[1]);
            var minuteVal = val(parts[2]);
            var secondVal = val(parts[3]);

            return {
                "local_day_start_hour"=hourVal,
                "local_day_start_minute"=minuteVal,
                "local_day_start_second"=secondVal,
                "local_day_start_millisecond"=0,
                "local_day_start_sql"=timeSql
            };
        </cfscript>
    </cffunction>

</cfcomponent>
