<cfsetting enablecfoutputonly="true" showdebugoutput="false">
<cfcontent type="application/json; charset=utf-8">
<cfheader name="Cache-Control" value="no-store, no-cache, must-revalidate">

<cfset response = { "SUCCESS" = false, "AUTH" = false, "MESSAGE" = "Unable to upload vessel image." }>
<cfset statusCode = 400>
<cfset userId = 0>
<cfset vesselId = 0>
<cfif structKeyExists(url, "vessel_id")>
  <cfset vesselId = val(url.vessel_id)>
<cfelseif structKeyExists(form, "vessel_id")>
  <cfset vesselId = val(form.vessel_id)>
</cfif>
<cfset uploadPath = "">
<cfset originalName = "">
<cfset uploadSize = 0>
<cfset fileExtension = "">
<cfset mimeType = "">
<cfset gateResult = {}>
<cfset saveResult = {}>

<cftry>
  <cfif structKeyExists(session, "user") AND isStruct(session.user)>
    <cfif structKeyExists(session.user, "userId")>
      <cfset userId = val(session.user.userId)>
    <cfelseif structKeyExists(session.user, "id")>
      <cfset userId = val(session.user.id)>
    <cfelseif structKeyExists(session.user, "USERID")>
      <cfset userId = val(session.user.USERID)>
    </cfif>
  </cfif>

  <cfif userId LTE 0>
    <cfset response = { "SUCCESS" = false, "AUTH" = false, "MESSAGE" = "Not logged in.", "ERROR" = "NOT_LOGGED_IN" }>
    <cfset statusCode = 401>
  <cfelseif vesselId LTE 0>
    <cfset response = { "SUCCESS" = false, "AUTH" = true, "MESSAGE" = "Vessel id is required.", "ERROR" = "INVALID_VESSEL" }>
    <cfset statusCode = 400>
  <cfelse>
    <cftry>
      <cfset gateResult = createObject("component", "fpw.api.v1.MemberAccessGateService").init("fpw").requirePremium(
        userId = userId,
        errorCode = "BASIC_REUSABLE_VESSEL_RESTRICTED",
        message = "Upgrade to Premium to save reusable vessels."
      )>
      <cfcatch>
        <cfset gateResult = createObject("component", "api.v1.MemberAccessGateService").init("fpw").requirePremium(
          userId = userId,
          errorCode = "BASIC_REUSABLE_VESSEL_RESTRICTED",
          message = "Upgrade to Premium to save reusable vessels."
        )>
      </cfcatch>
    </cftry>

    <cfif NOT gateResult.allowed>
      <cfset response = gateResult.response>
      <cfset statusCode = structKeyExists(response, "STATUS_CODE") ? val(response.STATUS_CODE) : 403>
    <cfelse>
      <cftry>
        <cffile action="upload" filefield="image_file" destination="#getTempDirectory()#" nameconflict="makeunique" result="uploadResult">
        <cfscript>
          uploadPath = replace(uploadResult.serverDirectory, "\\", "/", "all") & "/" & uploadResult.serverFile;
          originalName = structKeyExists(uploadResult, "clientFile") ? uploadResult.clientFile : uploadResult.serverFile;
          uploadSize = (structKeyExists(uploadResult, "fileSize") AND isNumeric(uploadResult.fileSize)) ? val(uploadResult.fileSize) : 0;
          if (uploadSize LTE 0) {
            try {
              uploadSize = val(getFileInfo(uploadPath).size);
            } catch (any ignored) {
              uploadSize = 0;
            }
          }
          fileExtension = lCase(trim(listLast(originalName, ".")));
          mimeType = lCase(trim(
            (structKeyExists(uploadResult, "contentType") ? toString(uploadResult.contentType) : "")
            & "/"
            & (structKeyExists(uploadResult, "contentSubType") ? toString(uploadResult.contentSubType) : "")
          ));
        </cfscript>

        <cfif NOT listFindNoCase("jpg,jpeg,png,webp", fileExtension)>
          <cfset response = { "SUCCESS" = false, "AUTH" = true, "MESSAGE" = "Only JPG, PNG, and WebP images are allowed.", "ERROR" = "INVALID_IMAGE_TYPE" }>
          <cfset statusCode = 400>
        <cfelseif uploadSize GT (5 * 1024 * 1024)>
          <cfset response = { "SUCCESS" = false, "AUTH" = true, "MESSAGE" = "Image must be 5MB or smaller.", "ERROR" = "IMAGE_TOO_LARGE" }>
          <cfset statusCode = 400>
        <cfelseif len(mimeType) AND NOT reFindNoCase("^image/(jpeg|pjpeg|png|webp|x-webp)$", mimeType)>
          <cfset response = { "SUCCESS" = false, "AUTH" = true, "MESSAGE" = "Only JPG, PNG, and WebP images are allowed.", "ERROR" = "INVALID_IMAGE_TYPE" }>
          <cfset statusCode = 400>
        <cfelse>
          <cftry>
            <cfset saveResult = createObject("component", "fpw.api.v1.VesselImageService").init("fpw").saveUploadedVesselImage(
              vesselId = vesselId,
              userId = userId,
              uploadPath = uploadPath,
              originalFileName = originalName,
              basePath = reReplace(cgi.script_name, "/api/v1/.*$", "", "one")
            )>
            <cfcatch>
              <cfset saveResult = createObject("component", "api.v1.VesselImageService").init("fpw").saveUploadedVesselImage(
                vesselId = vesselId,
                userId = userId,
                uploadPath = uploadPath,
                originalFileName = originalName,
                basePath = reReplace(cgi.script_name, "/api/v1/.*$", "", "one")
              )>
            </cfcatch>
          </cftry>

          <cfif saveResult.SUCCESS>
            <cfset response = {
              "SUCCESS" = true,
              "AUTH" = true,
              "MESSAGE" = saveResult.MESSAGE,
              "IMAGE" = saveResult.IMAGE
            }>
            <cfset statusCode = 200>
          <cfelse>
            <cfset response = {
              "SUCCESS" = false,
              "AUTH" = true,
              "MESSAGE" = saveResult.MESSAGE,
              "ERROR" = "IMAGE_SAVE_FAILED"
            }>
            <cfset statusCode = 400>
          </cfif>
        </cfif>

        <cfcatch>
          <cfset response = {
            "SUCCESS" = false,
            "AUTH" = true,
            "MESSAGE" = "Only JPG, PNG, and WebP images up to 5MB are allowed.",
            "ERROR" = "INVALID_IMAGE_UPLOAD"
          }>
          <cfset statusCode = 400>
        </cfcatch>
        <cffinally>
          <cfif len(uploadPath) AND fileExists(uploadPath)>
            <cftry>
              <cffile action="delete" file="#uploadPath#">
              <cfcatch></cfcatch>
            </cftry>
          </cfif>
        </cffinally>
      </cftry>
    </cfif>
  </cfif>

  <cfcatch>
    <cfset response = {
      "SUCCESS" = false,
      "AUTH" = (userId GT 0),
      "MESSAGE" = "Vessel image upload error.",
      "ERROR" = "SERVER_ERROR",
      "DETAIL" = cfcatch.message
    }>
    <cfset statusCode = 500>
  </cfcatch>
</cftry>

<cfif statusCode NEQ 200>
  <cfheader statuscode="#statusCode#">
</cfif>
<cfoutput>#serializeJSON(response)#</cfoutput>



