<cftry>
  <cfset tb = createObject("component","testbox.system.TestBox")>
  <cfoutput>OK: testbox.system.TestBox is resolvable</cfoutput>
  <cfcatch>
    <cfoutput>FAIL: cannot load testbox.system.TestBox</cfoutput>
    <cfdump var="#cfcatch#">
  </cfcatch>
</cftry>
