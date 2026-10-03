<cfsetting showdebugoutput="false" enablecfoutputonly="true">
<cfinclude template="../includes/fpw_base_path.cfm">
<cfheader name="Cache-Control" value="no-store, no-cache, must-revalidate, private">
<cfheader name="Pragma" value="no-cache">
<cfheader name="Referrer-Policy" value="no-referrer">
<cfset recoveryClickDestination=request.fpwBase & "/index.cfm">
<cftry>
  <cfif structKeyExists(url,"t") AND isSimpleValue(url.t)>
    <cfset recoveryClickDestination=new fpw.includes.InactiveMemberRecoveryTrackingService().init("fpw").resolveClick(toString(url.t),request.fpwBase)>
  </cfif>
  <cfcatch type="any"><!--- Safe fixed entry point; tokens never authenticate a member. ---></cfcatch>
</cftry>
<cfheader statuscode="302">
<cfheader name="Location" value="#recoveryClickDestination#">
<cfheader name="Cache-Control" value="no-store, no-cache, must-revalidate, private">
<cfabort>
