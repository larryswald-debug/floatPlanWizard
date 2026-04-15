<cfcomponent output="false">

    <cffunction name="echoRequest" access="remote" returntype="void" output="true">
        <cfset var probeValue = "">
        <cfset var payload = {}>

        <cfif structKeyExists(form, "probe")>
            <cfset probeValue = toString(form.probe)>
        <cfelseif structKeyExists(url, "probe")>
            <cfset probeValue = toString(url.probe)>
        </cfif>

        <cfset payload = {
            "SUCCESS"=true,
            "request_method"=(structKeyExists(cgi, "request_method") ? toString(cgi.request_method) : ""),
            "content_type"=(structKeyExists(cgi, "content_type") ? toString(cgi.content_type) : ""),
            "query_string"=(structKeyExists(cgi, "query_string") ? toString(cgi.query_string) : ""),
            "form_has_probe"=structKeyExists(form, "probe"),
            "probe_value"=probeValue
        }>

        <cfcontent type="application/json; charset=utf-8">
        <cfheader name="Cache-Control" value="no-store, no-cache, must-revalidate">
        <cfoutput>#serializeJSON(payload)#</cfoutput>
    </cffunction>

</cfcomponent>
