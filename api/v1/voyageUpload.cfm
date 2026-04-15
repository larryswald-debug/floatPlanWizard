<cfsetting enablecfoutputonly="true" showdebugoutput="false">
<cfcontent type="application/json; charset=utf-8">
<cfheader name="Cache-Control" value="no-store, no-cache, must-revalidate">

<cfset payload = {}>
<cfset voyageApi = "">
<cfset streamIdVal = val(structKeyExists(form, "stream_id") ? form.stream_id : 0)>
<cfset bodyTextVal = trim(toString(structKeyExists(form, "body") ? form.body : ""))>

<cftry>
    <cfset voyageApi = createObject("component", "fpw.api.v1.voyage")>
    <cfset payload = voyageApi.ownerCreatePostWithMediaFromForm(streamIdVal, bodyTextVal)>

    <cfif !structKeyExists(payload, "SUCCESS") OR !payload.SUCCESS>
        <cfheader statuscode="#(structKeyExists(payload, 'STATUS_CODE') ? val(payload.STATUS_CODE) : 400)#">
    </cfif>

    <cfoutput>#serializeJSON(payload)#</cfoutput>
    <cfcatch>
        <cfheader statuscode="500">
        <cfoutput>#serializeJSON({
            "SUCCESS"=false,
            "AUTH"=false,
            "MESSAGE"="Application error",
            "ERROR"={"MESSAGE"=cfcatch.message, "DETAIL"=cfcatch.detail}
        })#</cfoutput>
    </cfcatch>
</cftry>
