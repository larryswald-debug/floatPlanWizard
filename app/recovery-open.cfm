<cfsetting showdebugoutput="false" enablecfoutputonly="true">
<cfheader name="Cache-Control" value="no-store, no-cache, must-revalidate, private">
<cfheader name="Pragma" value="no-cache">
<cfheader name="Referrer-Policy" value="no-referrer">
<cftry>
  <cfif structKeyExists(url,"t") AND isSimpleValue(url.t)>
    <cfset new fpw.includes.InactiveMemberRecoveryTrackingService().init("fpw").recordOpen(toString(url.t))>
  </cfif>
  <cfcatch type="any"><!--- Every invalid/unavailable request returns the same safe pixel. ---></cfcatch>
</cftry>
<cfcontent type="image/gif" reset="true" variable="#binaryDecode('R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7','base64')#">
