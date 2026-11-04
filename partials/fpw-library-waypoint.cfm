<!--- Public markup stays cache-safe. The same-origin session check controls member actions. --->
<cfset fpwWaypointLocation = new fpw.api.v1.LibraryWaypointService().describe(fpwLibraryWaypointType, fpwLibraryWaypointRecord)>
<cfoutput>
<div data-library-waypoint data-library="#encodeForHTMLAttribute(fpwLibraryWaypointType)#"
     data-slug="#encodeForHTMLAttribute(fpwLibraryWaypointRecord.slug)#"
     data-record-id="#encodeForHTMLAttribute(fpwWaypointLocation.recordId)#"
     data-api="#encodeForHTMLAttribute(request.fpwApiBase)#">
    <h2>My Waypoints</h2>
    <cfif fpwWaypointLocation.eligible>
        <cfif len(fpwWaypointLocation.message)>
            <p>#encodeForHTML(fpwWaypointLocation.message)#</p>
        <cfelse>
            <p>Save this #encodeForHTML(fpwLibraryWaypointType)# as a location reference. You can select saved waypoints when building a route in your dashboard.</p>
        </cfif>
        <div data-library-waypoint-member hidden>
            <button type="button" class="fpw-#fpwLibraryWaypointType#-btn fpw-#fpwLibraryWaypointType#-btn--primary" data-library-waypoint-save>Add to My Waypoints</button>
            <a href="#encodeForHTMLAttribute(request.fpwBase)#/app/dashboard.cfm">Open dashboard</a>
        </div>
        <p data-library-waypoint-guest>Sign in to save this location to your custom waypoints. <a href="#encodeForHTMLAttribute(request.fpwBase)#/app/login.cfm">Log in</a> or <a href="#encodeForHTMLAttribute(request.fpwBase)#/app/join.cfm">join FPW</a>.</p>
        <p role="status" aria-live="polite" data-library-waypoint-status></p>
    <cfelse>
        <p>#encodeForHTML(fpwWaypointLocation.message)#</p>
    </cfif>
</div>
<cfif fpwWaypointLocation.eligible><script defer src="#encodeForHTMLAttribute(request.fpwBase)#/assets/js/app/library-waypoint.js"></script></cfif>
</cfoutput>
