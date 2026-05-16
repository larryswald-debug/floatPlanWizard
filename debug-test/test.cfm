<cfsetting showdebugoutput="true">

<cftry>
    <cfquery name="qTest" datasource="FPW">
        SELECT 
            NOW() AS mysql_now,
            UTC_TIMESTAMP() AS mysql_utc,
            @@global.time_zone AS global_time_zone,
            @@session.time_zone AS session_time_zone
    </cfquery>

   <cfdump var="#qTest#">

    <cfcatch type="any">
        <cfcontent type="application/json; charset=utf-8" reset="true">
        <cfoutput>#serializeJSON({
            "success": false,
            "message": cfcatch.message,
            "detail": cfcatch.detail,
            "type": cfcatch.type
        })#</cfoutput>
    </cfcatch>
</cftry>