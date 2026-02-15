<cfcomponent output="false">

    <cffunction name="handle" access="remote" returntype="void" output="true">
        <cfargument name="action" type="string" required="false" default="coverage">
        <cfargument name="routeCode" type="string" required="false" default="GREAT_LOOP_CCW">
        <cfsetting enablecfoutputonly="true" showdebugoutput="false">
        <cfcontent type="application/json; charset=utf-8">
        <cfheader name="Cache-Control" value="no-store, no-cache, must-revalidate">
        <cftry>
            <cfset var userStruct = {} />
            <cfset var userId = 0 />
            <cfset var act = lCase(trim(arguments.action)) />
            <cfset var svc = "" />

            <cfif structKeyExists(session, "user") AND isStruct(session.user)>
                <cfset userStruct = session.user />
            </cfif>
            <cfif structKeyExists(userStruct, "userId")>
                <cfset userId = val(userStruct.userId) />
            <cfelseif structKeyExists(userStruct, "USERID")>
                <cfset userId = val(userStruct.USERID) />
            </cfif>

            <cfif userId LTE 0>
                <cfoutput>#serializeJSON({
                    "SUCCESS"=false,
                    "AUTH"=false,
                    "MESSAGE"="Unauthorized",
                    "ERROR"={"MESSAGE"="No logged-in user session."}
                })#</cfoutput>
                <cfreturn>
            </cfif>

            <cfset svc = createObject("component", "fpw.api.v1.MilepointService") />

            <cfif act EQ "coverage">
                <cfset var report = svc.buildCoverageReport(arguments.routeCode) />
                <cfset report.AUTH = true />
                <cfoutput>#serializeJSON(report)#</cfoutput>
                <cfreturn>
            </cfif>

            <cfoutput>#serializeJSON({
                "SUCCESS"=false,
                "AUTH"=true,
                "MESSAGE"="Unknown action",
                "ERROR"={"MESSAGE"="Unsupported action: " & arguments.action}
            })#</cfoutput>
            <cfreturn>

            <cfcatch>
                <cfoutput>#serializeJSON({
                    "SUCCESS"=false,
                    "AUTH"=true,
                    "MESSAGE"="Application error",
                    "ERROR"={"MESSAGE"=cfcatch.message, "DETAIL"=cfcatch.detail}
                })#</cfoutput>
            </cfcatch>
        </cftry>
    </cffunction>

</cfcomponent>
