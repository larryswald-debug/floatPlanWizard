<cfsetting showdebugoutput="false" enablecfoutputonly="true" requesttimeout="30">
<cfheader name="Cache-Control" value="no-store">
<cfheader name="X-Robots-Tag" value="noindex, nofollow">
<cfcontent type="application/json; charset=utf-8" reset="true">
<cfscript>
status = 200;
result = {};
try {
    if (cgi.request_method NEQ "POST") {
        status = 405;
        result = {"success"=false,"message"="Use POST for planning calculations."};
    } else {
        requestBody = toString(getHttpRequestData().content);
        if (len(requestBody) GT 8192 OR !isJSON(requestBody)) {
            throw(type="GreatLoopReference.InvalidInput",message="Invalid planning request.");
        }
        body = deserializeJSON(requestBody);
        if (!isStruct(body)) throw(type="GreatLoopReference.InvalidInput",message="Invalid planning request.");
        for (field in body) {
            if (!listFindNoCase("action,startDate,inputs,legOrder",field)) {
                throw(type="GreatLoopReference.InvalidInput",message="Unsupported planning request.");
            }
        }
        try { service = createObject("component","api.v1.GreatLoopReferenceService").init(); }
        catch (any componentPathError) { service = createObject("component","fpw.api.v1.GreatLoopReferenceService").init(); }
        action = structKeyExists(body,"action") AND isSimpleValue(body.action) ? lCase(trim(body.action)) : "timeline";
        if (action EQ "locks") {
            if (!structKeyExists(body,"legOrder") OR !isNumeric(body.legOrder) OR body.legOrder LT 1 OR int(body.legOrder) NEQ body.legOrder) {
                throw(type="GreatLoopReference.InvalidInput",message="Select a valid Great Loop leg.");
            }
            result = service.getTimelineLockDetails(body.legOrder);
        } else if (action EQ "timeline") {
            if (!structKeyExists(body,"startDate") OR !isSimpleValue(body.startDate) OR !reFind("^[0-9]{4}-[0-9]{2}-[0-9]{2}$",body.startDate)) {
                throw(type="GreatLoopReference.InvalidInput",message="Choose a valid departure date.");
            }
            if (structKeyExists(body,"inputs") AND !isStruct(body.inputs)) {
                throw(type="GreatLoopReference.InvalidInput",message="Invalid planning inputs.");
            }
            result = service.getTimeline(body.startDate,structKeyExists(body,"inputs") ? body.inputs : {});
            if (!result.success) status = 400;
        } else {
            throw(type="GreatLoopReference.InvalidInput",message="Unsupported planning action.");
        }
    }
} catch (GreatLoopReference.InvalidInput invalidInput) {
    status = 400;
    result = {"success"=false,"message"=invalidInput.message};
} catch (any timelineError) {
    status = 503;
    writeLog(file="fpw",type="error",text="FPW_ERROR Great Loop public timeline: " & timelineError.message);
    result = {"success"=false,"message"="The cruise timeline is temporarily unavailable. Please try again later."};
}
</cfscript>
<cfheader statuscode="#status#">
<cfif status EQ 405><cfheader name="Allow" value="POST"></cfif>
<cfoutput>#serializeJSON(result)#</cfoutput>
