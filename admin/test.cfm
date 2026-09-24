<cfsetting  showdebugoutput="true">


<cftry>
<cfschedule
 action="list"
 result="scheduledList"
 />

<cfdump var="#scheduledList#" />`
<cfcatch>
    <cfdump var="#cfcatch#" >
    

</cfcatch>
</cftry>
