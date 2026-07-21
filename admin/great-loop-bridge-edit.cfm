<cfsetting showdebugoutput="false" requesttimeout="30">
<cfcontent type="text/html; charset=utf-8">
<cfinclude template="../includes/fpw_base_path.cfm">

<cfscript>
userStruct = (structKeyExists(session, "user") AND isStruct(session.user)) ? session.user : {};
isLoggedIn = structCount(userStruct) GT 0;
// Authorization is enforced centrally by Application.cfc.
isAdmin = false;
isAuthorized = false;
nonceKey = "greatLoopBridgesAdminNonce";
adminNonce = "";
bridgeId = structKeyExists(url, "id") ? val(url.id) : (structKeyExists(form, "id") ? val(form.id) : 0);
messageType = "";
messageText = "";
errors = [];
bridgeResult = { "SUCCESS" = false, "BRIDGE" = {} };
bridgeItem = {};
maxImageUploadBytes = 8 * 1024 * 1024;
uploadPath = "";
uploadOriginalName = "";

function boolLike(any value, boolean defaultValue=false) {
  var txt = lCase(trim(toString(arguments.value)));
  if (!len(txt)) return arguments.defaultValue;
  if (listFindNoCase("1,true,yes,y,on", txt)) return true;
  if (listFindNoCase("0,false,no,n,off", txt)) return false;
  if (isNumeric(txt)) return (val(txt) NEQ 0);
  return arguments.defaultValue;
}

function emailFromUser(required struct u) {
  if (structKeyExists(arguments.u, "email")) return lCase(trim(toString(arguments.u.email)));
  if (structKeyExists(arguments.u, "EMAIL")) return lCase(trim(toString(arguments.u.EMAIL)));
  return "";
}

function roleFromUser(required struct u) {
  if (structKeyExists(arguments.u, "role")) return lCase(trim(toString(arguments.u.role)));
  if (structKeyExists(arguments.u, "ROLE")) return lCase(trim(toString(arguments.u.ROLE)));
  return "";
}

function displayText(any value, string fallback="") {
  var txt = isNull(arguments.value) ? "" : trim(toString(arguments.value));
  return len(txt) ? txt : arguments.fallback;
}

function selectedAttr(any leftValue, any rightValue) {
  return compareNoCase(trim(toString(arguments.leftValue)), trim(toString(arguments.rightValue))) EQ 0 ? " selected" : "";
}

function checkedAttr(any value) {
  return boolLike(arguments.value, false) ? " checked" : "";
}

function fieldValue(required string keyName) {
  if (structKeyExists(bridgeItem, arguments.keyName) AND !isNull(bridgeItem[arguments.keyName])) {
    return trim(toString(bridgeItem[arguments.keyName]));
  }
  return "";
}

function optionText(any value) {
  var txt = trim(toString(arguments.value));
  if (txt EQ "published") return "Published";
  if (txt EQ "planning_only") return "Planning only";
  if (txt EQ "admin_review") return "Admin review";
  if (txt EQ "do_not_publish") return "Do not publish";
  return txt;
}

function safeDeleteUpload(required string filePath) {
  try {
    if (len(trim(arguments.filePath)) AND fileExists(arguments.filePath)) {
      fileDelete(arguments.filePath);
    }
  } catch (any ignored) {
  }
}

isAuthorized = structKeyExists(request, "fpwAdminAuthorization") AND request.fpwAdminAuthorization.authorized;

if (isAuthorized) {
  if (!structKeyExists(session, nonceKey) OR !len(trim(toString(session[nonceKey])))) {
    session[nonceKey] = createUUID();
  }
  adminNonce = session[nonceKey];
  try {
    try {
      bridgeSvc = createObject("component", "api.v1.GreatLoopBridgesService").init();
    } catch (any svcPathError) {
      bridgeSvc = createObject("component", "fpw.api.v1.GreatLoopBridgesService").init();
    }

    if (structKeyExists(form, "deleteBridgeImage")) {
      if (!structKeyExists(form, "adminNonce") OR trim(toString(form.adminNonce)) NEQ adminNonce) {
        messageType = "error";
        messageText = "Image delete rejected. Refresh the page and try again.";
      } else {
        imageResult = bridgeSvc.deleteBridgeImage(bridgeId, request.fpwBase);
        messageType = imageResult.SUCCESS ? "success" : "error";
        messageText = imageResult.MESSAGE;
        if (imageResult.SUCCESS) {
          bridgeItem = imageResult.BRIDGE;
        }
      }
    } else if (structKeyExists(form, "saveBridge")) {
      if (!structKeyExists(form, "adminNonce") OR trim(toString(form.adminNonce)) NEQ adminNonce) {
        messageType = "error";
        messageText = "Save rejected. Refresh the page and try again.";
      } else {
        payload = duplicate(form);
        payload.id = bridgeId;
        payload.is_drawbridge = structKeyExists(form, "is_drawbridge") ? "1" : "0";
        payload.is_fixed = structKeyExists(form, "is_fixed") ? "1" : "0";
        payload.is_railroad = structKeyExists(form, "is_railroad") ? "1" : "0";
        payload.image_allowed_for_fpw = structKeyExists(form, "image_allowed_for_fpw") ? "1" : "0";
        saveResult = bridgeSvc.updateBridge(payload);
        if (saveResult.SUCCESS) {
          messageType = "success";
          messageText = saveResult.MESSAGE;
          bridgeItem = saveResult.BRIDGE;
        } else {
          messageType = "error";
          messageText = saveResult.MESSAGE;
          errors = saveResult.ERRORS;
          bridgeItem = bridgeSvc.normalizeBridgePayload(payload);
        }
      }
    }

    if (!structCount(bridgeItem)) {
      bridgeResult = bridgeSvc.getBridgeById(bridgeId);
      if (bridgeResult.SUCCESS) {
        bridgeItem = bridgeResult.BRIDGE;
      } else {
        messageType = "error";
        messageText = "Bridge not found.";
      }
    }
  } catch (any eService) {
    messageType = "error";
    messageText = "Bridge record could not be loaded or saved.";
  }
}

textFields = [
  { "name" = "bridge_id", "label" = "Bridge ID" },
  { "name" = "bridge_name", "label" = "Bridge Name" },
  { "name" = "slug", "label" = "Slug" },
  { "name" = "route_segment", "label" = "Route Segment" },
  { "name" = "route_variant", "label" = "Route Variant" },
  { "name" = "waterway", "label" = "Waterway" },
  { "name" = "state_province", "label" = "State / Province" },
  { "name" = "nearest_city", "label" = "Nearest City" },
  { "name" = "mile_marker", "label" = "Mile Marker" },
  { "name" = "latitude", "label" = "Latitude" },
  { "name" = "longitude", "label" = "Longitude" },
  { "name" = "bridge_type", "label" = "Bridge Type" },
  { "name" = "vertical_clearance_closed_ft", "label" = "Vertical Clearance Closed ft" },
  { "name" = "vertical_clearance_open_ft", "label" = "Vertical Clearance Open ft" },
  { "name" = "horizontal_clearance_ft", "label" = "Horizontal Clearance ft" },
  { "name" = "vhf_channel", "label" = "VHF Channel" },
  { "name" = "phone", "label" = "Phone" },
  { "name" = "operator_contact", "label" = "Operator Contact" },
  { "name" = "image_license", "label" = "Image License" },
  { "name" = "local_image_path", "label" = "Local Image Path" },
  { "name" = "source_confidence", "label" = "Source Confidence" },
  { "name" = "last_verified_date", "label" = "Last Verified Date" },
  { "name" = "display_priority", "label" = "Display Priority" },
  { "name" = "verification_status", "label" = "Verification Status" }
];

longFields = [
  { "name" = "short_description", "label" = "Short Description" },
  { "name" = "air_draft_notes", "label" = "Air Draft Notes" },
  { "name" = "opening_schedule", "label" = "Opening Schedule" },
  { "name" = "navigation_notes", "label" = "Navigation Notes" },
  { "name" = "regulatory_notes", "label" = "Regulatory Notes" },
  { "name" = "source_primary_url", "label" = "Primary Source URL" },
  { "name" = "source_secondary_url", "label" = "Secondary Source URL" },
  { "name" = "image_url", "label" = "Remote Image URL Metadata" },
  { "name" = "image_source", "label" = "Image Source" },
  { "name" = "image_credit", "label" = "Image Credit" },
  { "name" = "admin_notes", "label" = "Admin Notes" }
];
</cfscript>

<cfif isAuthorized AND structKeyExists(form, "uploadBridgeImage")>
  <cfif NOT structKeyExists(form, "adminNonce") OR trim(toString(form.adminNonce)) NEQ adminNonce>
    <cfset messageType = "error">
    <cfset messageText = "Image upload rejected. Refresh the page and try again.">
  <cfelseif bridgeId LTE 0>
    <cfset messageType = "error">
    <cfset messageText = "Bridge id is required before an image can be uploaded.">
  <cfelseif NOT structKeyExists(variables, "bridgeSvc")>
    <cfset messageType = "error">
    <cfset messageText = "Bridge image service is unavailable.">
  <cfelse>
    <cftry>
      <cffile action="upload" filefield="bridgeImageFile" destination="#getTempDirectory()#" nameconflict="makeunique" result="uploadResult">
      <cfscript>
        uploadInfo = {};
        uploadSize = 0;
        uploadPath = replace(uploadResult.serverDirectory, "\", "/", "all") & "/" & uploadResult.serverFile;
        uploadOriginalName = structKeyExists(uploadResult, "clientFile") ? uploadResult.clientFile : uploadResult.serverFile;
        try {
          uploadInfo = getFileInfo(uploadPath);
          uploadSize = val(uploadInfo.size);
        } catch (any uploadInfoError) {
          uploadSize = 0;
        }

        if (uploadSize GT maxImageUploadBytes) {
          messageType = "error";
          messageText = "Image upload rejected. Maximum file size is 8 MB.";
        } else {
          imageResult = bridgeSvc.saveUploadedBridgeImage(bridgeId, uploadPath, uploadOriginalName, request.fpwBase);
          messageType = imageResult.SUCCESS ? "success" : "error";
          messageText = imageResult.MESSAGE;
          if (imageResult.SUCCESS) {
            bridgeItem = imageResult.BRIDGE;
          }
        }
        safeDeleteUpload(uploadPath);
      </cfscript>
      <cfcatch type="any">
        <cfscript>
          safeDeleteUpload(uploadPath);
          messageType = "error";
          messageText = "Image upload failed. Choose a JPG, PNG, or WEBP image and try again.";
        </cfscript>
      </cfcatch>
    </cftry>
  </cfif>
</cfif>

<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Great Loop Bridge Edit</title>
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" crossorigin="anonymous">
  <style>
    body { font-family: Arial, sans-serif; margin: 24px; background: #f7f7f7; color: #111; }
    .wrap { max-width: 1280px; margin: 0 auto; background: #fff; border: 1px solid #ddd; border-radius: 8px; padding: 20px; }
    h1 { margin-top: 0; font-size: 24px; }
    .hint { color: #444; margin-bottom: 16px; }
    .msg { margin-bottom: 14px; padding: 12px; border-radius: 5px; }
    .msg.success { background: #e9f8ee; border: 1px solid #9dd9ad; color: #0e5522; }
    .msg.error { background: #ffecec; border: 1px solid #ffb4b4; color: #7f1d1d; }
    .form-grid { display: grid; gap: 12px; grid-template-columns: repeat(3, minmax(0, 1fr)); }
    .form-grid .wide { grid-column: 1 / -1; }
    .check-row { display: flex; flex-wrap: wrap; gap: 16px; margin: 12px 0; }
    .bridge-image-panel { display: grid; grid-template-columns: 220px minmax(0, 1fr); gap: 18px; align-items: start; margin-bottom: 18px; padding: 16px; border: 1px solid #ddd; border-radius: 8px; background: #fafafa; }
    .bridge-image-preview { width: 220px; aspect-ratio: 4 / 3; overflow: hidden; border: 1px solid #d5d5d5; border-radius: 6px; background: #eef3f7; }
    .bridge-image-preview img { display: block; width: 100%; height: 100%; object-fit: cover; }
    .bridge-image-actions { display: flex; flex-wrap: wrap; gap: 10px; align-items: center; margin-top: 10px; }
    textarea.form-control { min-height: 96px; }
    .small-muted { color: #666; font-size: 13px; }
    @media (max-width: 900px) { .form-grid { grid-template-columns: repeat(2, minmax(0, 1fr)); } }
    @media (max-width: 640px) { body { margin: 12px; } .wrap { padding: 14px; } .form-grid { grid-template-columns: 1fr; } .bridge-image-panel { grid-template-columns: 1fr; } .bridge-image-preview { width: 100%; } }
  </style>
</head>
<body>
  <div class="wrap">
    <cfinclude template="includes/admin_reports_nav.cfm">

    <h1>Great Loop Bridge Edit</h1>
    <p class="hint">Edit source-backed bridge planning fields. Public display still requires a public status other than do not publish.</p>

    <cfif NOT isAuthorized>
      <div class="msg error"><strong>Unauthorized:</strong> Admin login is required.</div>
    <cfelse>
      <cfif len(messageText)>
        <div class="msg <cfoutput>#encodeForHTMLAttribute(messageType)#</cfoutput>"><cfoutput>#encodeForHTML(messageText)#</cfoutput></div>
      </cfif>
      <cfif arrayLen(errors)>
        <div class="msg error">
          <strong>Validation errors</strong>
          <ul class="mb-0">
            <cfloop array="#errors#" index="errorText"><li><cfoutput>#encodeForHTML(errorText)#</cfoutput></li></cfloop>
          </ul>
        </div>
      </cfif>

      <div class="mb-3">
        <a class="btn btn-outline-secondary" href="<cfoutput>#request.fpwBase#</cfoutput>/admin/great-loop-bridges.cfm">Back to Bridges</a>
        <cfif structCount(bridgeItem) AND len(fieldValue("slug"))>
          <a class="btn btn-outline-dark" href="<cfoutput>#request.fpwBase#/great-loop-bridge.cfm?slug=#encodeForURL(fieldValue('slug'))#</cfoutput>" target="_blank" rel="noopener">View Public Detail</a>
        </cfif>
      </div>

      <cfif structCount(bridgeItem)>
        <cfset bridgeImage = bridgeSvc.getBridgeImageAsset(bridgeItem, request.fpwBase)>
        <cfset hasBridgeImageReference = len(fieldValue("local_image_path")) GT 0>
        <cfset bridgeImageAlt = "Bridge image placeholder">
        <cfif bridgeImage.hasImage><cfset bridgeImageAlt = fieldValue("bridge_name") & " bridge image"></cfif>
        <form method="post" enctype="multipart/form-data" action="<cfoutput>#encodeForHTMLAttribute(request.fpwBase & '/admin/great-loop-bridge-edit.cfm?id=' & bridgeId)#</cfoutput>">
          <input type="hidden" name="id" value="<cfoutput>#encodeForHTMLAttribute(bridgeId)#</cfoutput>">
          <input type="hidden" name="adminNonce" value="<cfoutput>#encodeForHTMLAttribute(adminNonce)#</cfoutput>">

          <div class="bridge-image-panel">
            <div class="bridge-image-preview">
              <img src="<cfoutput>#encodeForHTMLAttribute(bridgeImage.url)#</cfoutput>" alt="<cfoutput>#encodeForHTMLAttribute(bridgeImageAlt)#</cfoutput>">
            </div>
            <div>
              <h2 class="h5 mb-2">Bridge Image</h2>
              <p class="small-muted mb-2">
                <cfif bridgeImage.hasImage>
                  Current local image: <strong><cfoutput>#encodeForHTML(bridgeImage.fileName)#</cfoutput></strong>
                <cfelseif hasBridgeImageReference>
                  Local image path is set, but the approved file was not found. Upload a replacement or delete the image reference.
                <cfelse>
                  No approved local bridge image is set. Public pages show the bridge placeholder.
                </cfif>
              </p>
              <label for="bridgeImageFile" class="form-label">Upload / Replace Image</label>
              <input type="file" class="form-control" id="bridgeImageFile" name="bridgeImageFile" accept=".jpg,.jpeg,.png,.webp,image/jpeg,image/png,image/webp">
              <div class="bridge-image-actions">
                <button type="submit" name="uploadBridgeImage" value="1" class="btn btn-outline-primary">Upload Image</button>
                <cfif bridgeImage.hasImage OR hasBridgeImageReference>
                  <button type="submit" name="deleteBridgeImage" value="1" class="btn btn-outline-danger" onclick="return confirm('Delete this bridge image? Public bridge pages will show the placeholder until a new approved image is uploaded.');">Delete Image</button>
                </cfif>
              </div>
              <p class="small-muted mt-2 mb-0">JPG, PNG, or WEBP. Maximum 8 MB. Uploading saves the source image and thumbnail; use Save Bridge for field changes.</p>
            </div>
          </div>

          <div class="form-grid">
            <div>
              <label for="public_status" class="form-label">Public Status</label>
              <select id="public_status" name="public_status" class="form-select">
                <cfloop array="#[ 'published', 'planning_only', 'admin_review', 'do_not_publish' ]#" index="statusOption">
                  <cfoutput><option value="#encodeForHTMLAttribute(statusOption)#"#selectedAttr(fieldValue("public_status"), statusOption)#>#encodeForHTML(optionText(statusOption))#</option></cfoutput>
                </cfloop>
              </select>
            </div>

            <cfloop array="#textFields#" index="fieldDef">
              <div>
                <label for="<cfoutput>#encodeForHTMLAttribute(fieldDef.name)#</cfoutput>" class="form-label"><cfoutput>#encodeForHTML(fieldDef.label)#</cfoutput></label>
                <input type="text" class="form-control" id="<cfoutput>#encodeForHTMLAttribute(fieldDef.name)#</cfoutput>" name="<cfoutput>#encodeForHTMLAttribute(fieldDef.name)#</cfoutput>" value="<cfoutput>#encodeForHTMLAttribute(fieldValue(fieldDef.name))#</cfoutput>">
              </div>
            </cfloop>

            <div class="wide check-row">
              <label><input type="checkbox" name="is_drawbridge" value="1"<cfoutput>#checkedAttr(fieldValue("is_drawbridge"))#</cfoutput>> Drawbridge / movable</label>
              <label><input type="checkbox" name="is_fixed" value="1"<cfoutput>#checkedAttr(fieldValue("is_fixed"))#</cfoutput>> Fixed bridge</label>
              <label><input type="checkbox" name="is_railroad" value="1"<cfoutput>#checkedAttr(fieldValue("is_railroad"))#</cfoutput>> Railroad bridge</label>
              <label><input type="checkbox" name="image_allowed_for_fpw" value="1"<cfoutput>#checkedAttr(fieldValue("image_allowed_for_fpw"))#</cfoutput>> Local image approved for FPW</label>
            </div>

            <cfloop array="#longFields#" index="fieldDef">
              <div class="wide">
                <label for="<cfoutput>#encodeForHTMLAttribute(fieldDef.name)#</cfoutput>" class="form-label"><cfoutput>#encodeForHTML(fieldDef.label)#</cfoutput></label>
                <textarea class="form-control" id="<cfoutput>#encodeForHTMLAttribute(fieldDef.name)#</cfoutput>" name="<cfoutput>#encodeForHTMLAttribute(fieldDef.name)#</cfoutput>"><cfoutput>#encodeForHTML(fieldValue(fieldDef.name))#</cfoutput></textarea>
              </div>
            </cfloop>
          </div>

          <p class="small-muted mt-3">Public images only render when Local Image Path points inside assets/images/great-loop-bridges/, the file exists, and Local image approved for FPW is checked.</p>
          <button type="submit" name="saveBridge" value="1" class="btn btn-dark mt-2">Save Bridge</button>
        </form>
      </cfif>
    </cfif>
  </div>
</body>
</html>




