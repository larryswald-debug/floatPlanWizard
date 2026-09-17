<cfcomponent output="false" hint="Internal native scheduler adapter. No remote methods.">
    <cffunction name="listTasks" access="public" returntype="query" output="false">
        <cfargument name="mode" type="string" required="true">
        <cfset var tasks = queryNew("")>
        <cfif NOT listFindNoCase("server,application", arguments.mode)>
            <cfthrow type="FPWScheduler.InvalidScope" message="Invalid scheduler scope.">
        </cfif>
        <cfschedule action="list" mode="#arguments.mode#" result="tasks">
        <cfreturn tasks>
    </cffunction>

    <cffunction name="execute" access="public" returntype="void" output="false">
        <cfargument name="attributes" type="struct" required="true">
        <cfif NOT structKeyExists(arguments.attributes, "action")
            OR NOT listFindNoCase("update,pause,resume,run,delete", arguments.attributes.action)
            OR NOT structKeyExists(arguments.attributes, "task") OR NOT len(trim(arguments.attributes.task))
            OR NOT structKeyExists(arguments.attributes, "group")
            OR NOT structKeyExists(arguments.attributes, "mode")
            OR NOT listFindNoCase("server,application", arguments.attributes.mode)>
            <cfthrow type="FPWScheduler.InvalidAction" message="A single registered task is required.">
        </cfif>
        <cfschedule attributeCollection="#arguments.attributes#">
    </cffunction>
</cfcomponent>
