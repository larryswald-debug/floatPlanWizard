<!--- Test-only custom-tag transport. Never submits SMTP. --->
<cfif thisTag.executionMode EQ "end">
  <cfif NOT structKeyExists(request, "fpwDirectEmailCaptureEnabled") OR request.fpwDirectEmailCaptureEnabled NEQ true>
    <cfthrow message="Direct email capture is not enabled for this test request.">
  </cfif>
  <cfset capturedEmail = duplicate(attributes)>
  <cfset capturedEmail.replyTo = structKeyExists(attributes, "replyTo") ? toString(attributes.replyTo) : "">
  <cfset capturedEmail.htmlBody = compareNoCase(attributes.type, "html") EQ 0 ? trim(thisTag.generatedContent) : "">
  <cfset capturedEmail.textBody = compareNoCase(attributes.type, "text") EQ 0 ? trim(thisTag.generatedContent) : "">
  <cfset arrayAppend(request.fpwDirectEmailCaptures, capturedEmail)>
  <cfset thisTag.generatedContent = "">
</cfif>
