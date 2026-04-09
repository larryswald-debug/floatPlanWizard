<cfcomponent output="false">

    <cffunction name="init" access="public" returntype="any" output="false">
        <cfscript>
            variables.localDayStartRule = {
                "local_day_start_hour"=8,
                "local_day_start_minute"=0,
                "local_day_start_second"=0,
                "local_day_start_millisecond"=0,
                "local_day_start_sql"="08:00:00"
            };
            return this;
        </cfscript>
    </cffunction>

    <cffunction name="getLocalDayStartRule" access="public" returntype="struct" output="false">
        <cfscript>
            return duplicate(variables.localDayStartRule);
        </cfscript>
    </cffunction>

</cfcomponent>
