<cfsetting showdebugoutput="false" requesttimeout="120">
<cfcontent type="text/html; charset=utf-8">
<cfinclude template="../includes/fpw_base_path.cfm">

<cfscript>
userStruct = (structKeyExists(session, "user") AND isStruct(session.user)) ? session.user : {};
isLoggedIn = structCount(userStruct) GT 0;
adminWhitelist = "admin@floatplanwizard.com,lswald@yahoo.com";
isAdmin = false;
isAuthorized = false;
sessionKey = "greatLoopBridgesImportPreview";
messageText = "";
messageType = "";
preview = {};
importResult = {};
uploadPath = "";
uploadOriginalName = "";
maxUploadBytes = 10 * 1024 * 1024;

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

function userIdFromSession(required struct u) {
  if (structKeyExists(arguments.u, "userId") AND isNumeric(arguments.u.userId)) return val(arguments.u.userId);
  if (structKeyExists(arguments.u, "USERID") AND isNumeric(arguments.u.USERID)) return val(arguments.u.USERID);
  if (structKeyExists(arguments.u, "id") AND isNumeric(arguments.u.id)) return val(arguments.u.id);
  if (structKeyExists(arguments.u, "ID") AND isNumeric(arguments.u.ID)) return val(arguments.u.ID);
  return 0;
}

function issueLabel(required struct item) {
  var rowLabel = (structKeyExists(arguments.item, "row") AND val(arguments.item.row) GT 0) ? ("Row " & val(arguments.item.row) & ": ") : "";
  var fieldLabel = (structKeyExists(arguments.item, "field") AND len(trim(toString(arguments.item.field)))) ? ("[" & trim(toString(arguments.item.field)) & "] ") : "";
  var messageLabel = structKeyExists(arguments.item, "message") ? trim(toString(arguments.item.message)) : "";
  return rowLabel & fieldLabel & messageLabel;
}

function safeDelete(required string filePath) {
  if (!len(trim(arguments.filePath))) return;
  try {
    if (fileExists(arguments.filePath)) fileDelete(arguments.filePath);
  } catch (any deleteError) {
    // Best effort temp upload cleanup only.
  }
}

function countStatus(required array rows, required string statusValue) {
  var i = 0;
  var total = 0;
  for (i = 1; i LTE arrayLen(arguments.rows); i++) {
    if (structKeyExists(arguments.rows[i], "public_status") AND arguments.rows[i].public_status EQ arguments.statusValue) {
      total++;
    }
  }
  return total;
}

function createImportService() {
  try {
    return createObject("component", "api.v1.GreatLoopBridgesImportService").init();
  } catch (any ePath) {
    return createObject("component", "fpw.api.v1.GreatLoopBridgesImportService").init();
  }
}

if (isLoggedIn) {
  if (structKeyExists(userStruct, "isAdmin") AND boolLike(userStruct.isAdmin, false)) {
    isAdmin = true;
  } else if (structKeyExists(userStruct, "ISADMIN") AND boolLike(userStruct.ISADMIN, false)) {
    isAdmin = true;
  } else if (structKeyExists(userStruct, "is_admin") AND boolLike(userStruct.is_admin, false)) {
    isAdmin = true;
  } else if (roleFromUser(userStruct) EQ "admin") {
    isAdmin = true;
  } else if (len(emailFromUser(userStruct)) AND listFindNoCase(adminWhitelist, emailFromUser(userStruct))) {
    isAdmin = true;
  }
}
isAuthorized = isLoggedIn AND isAdmin;

if (isAuthorized AND structKeyExists(form, "cancelPreview")) {
  structDelete(session, sessionKey, false);
  messageType = "info";
  messageText = "Import preview was cleared.";
}

if (isAuthorized AND structKeyExists(form, "confirmImport")) {
  if (
    !structKeyExists(session, sessionKey)
    OR !isStruct(session[sessionKey])
    OR !structKeyExists(form, "previewNonce")
    OR !structKeyExists(session[sessionKey], "nonce")
    OR trim(toString(form.previewNonce)) NEQ session[sessionKey].nonce
  ) {
    messageType = "error";
    messageText = "Import preview expired. Upload and preview the CSV again.";
  } else if (structKeyExists(session[sessionKey], "errors") AND arrayLen(session[sessionKey].errors)) {
    messageType = "error";
    messageText = "The preview has file/header errors and cannot be imported.";
  } else {
    try {
      svc = createImportService();
      importResult = svc.importRows(session[sessionKey].rows, session[sessionKey].sourceFilename, userIdFromSession(userStruct));
      if (structKeyExists(importResult, "SUCCESS") AND importResult.SUCCESS) {
        structDelete(session, sessionKey, false);
        messageType = importResult.ERRORED GT 0 ? "info" : "success";
        messageText = importResult.MESSAGE & " Inserted: " & importResult.INSERTED & ". Updated: " & importResult.UPDATED & ". Skipped: " & importResult.SKIPPED & ".";
      } else {
        messageType = "error";
        messageText = structKeyExists(importResult, "MESSAGE") ? importResult.MESSAGE : "Import failed.";
      }
    } catch (any eImport) {
      messageType = "error";
      messageText = "Import failed. Confirm the great_loop_bridges migration has been run and try again.";
    }
  }
}
</cfscript>

<cfif isAuthorized AND structKeyExists(form, "previewImport")>
  <cftry>
    <cffile action="upload" filefield="bridgesFile" destination="#getTempDirectory()#" nameconflict="makeunique" result="uploadResult">
    <cfscript>
      uploadOriginalName = structKeyExists(uploadResult, "clientFile") ? uploadResult.clientFile : "";
      if (!len(uploadOriginalName) AND structKeyExists(uploadResult, "serverFile")) {
        uploadOriginalName = uploadResult.serverFile;
      }
      uploadPath = uploadResult.serverDirectory & "/" & uploadResult.serverFile;

      if (lCase(listLast(uploadOriginalName, ".")) NEQ "csv") {
        safeDelete(uploadPath);
        messageType = "error";
        messageText = "Upload rejected. Use a Bridge_Master .csv export.";
      } else if (structKeyExists(uploadResult, "fileSize") AND isNumeric(uploadResult.fileSize) AND val(uploadResult.fileSize) GT maxUploadBytes) {
        safeDelete(uploadPath);
        messageType = "error";
        messageText = "Upload rejected. The CSV must be 10 MB or smaller.";
      } else {
        try {
          svc = createImportService();
          parseResult = svc.parseCsv(uploadPath, uploadOriginalName);
          safeDelete(uploadPath);

          parseResult.nonce = createUUID();
          parseResult.sourceFilename = parseResult.SOURCE_FILENAME;
          parseResult.sourceSheet = parseResult.SOURCE_SHEET;
          parseResult.rows = parseResult.ROWS;
          parseResult.errors = parseResult.ERRORS;
          parseResult.warnings = parseResult.WARNINGS;
          parseResult.rowCount = parseResult.ROW_COUNT;
          parseResult.validRowCount = parseResult.VALID_ROW_COUNT;
          parseResult.doNotPublishCount = countStatus(parseResult.rows, "do_not_publish");
          parseResult.planningOnlyCount = countStatus(parseResult.rows, "planning_only");
          parseResult.publishedCount = countStatus(parseResult.rows, "published");
          session[sessionKey] = parseResult;

          messageType = parseResult.SUCCESS ? "success" : "error";
          messageText = parseResult.MESSAGE;
        } catch (any eParse) {
          safeDelete(uploadPath);
          messageType = "error";
          messageText = "The CSV could not be parsed. Confirm it is a Bridge_Master CSV with the expected headers.";
        }
      }
    </cfscript>
    <cfcatch type="any">
      <cfscript>
        safeDelete(uploadPath);
        messageType = "error";
        messageText = "Upload failed. Choose a valid Bridge_Master CSV and try again.";
      </cfscript>
    </cfcatch>
  </cftry>
</cfif>

<cfscript>
if (structKeyExists(session, sessionKey) AND isStruct(session[sessionKey])) {
  preview = session[sessionKey];
}
</cfscript>

<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Great Loop Bridges Import</title>
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" crossorigin="anonymous">
  <style>
    body { font-family: Arial, sans-serif; margin: 24px; background: #f7f7f7; color: #111; }
    .wrap { max-width: 1280px; margin: 0 auto; background: #fff; border: 1px solid #ddd; border-radius: 8px; padding: 20px; }
    h1 { margin-top: 0; font-size: 24px; }
    .hint { color: #444; margin-bottom: 16px; }
    .msg { margin-bottom: 14px; padding: 12px; border-radius: 5px; }
    .msg.info { background: #edf2ff; border: 1px solid #b6c6ff; color: #13255a; }
    .msg.success { background: #e9f8ee; border: 1px solid #9dd9ad; color: #0e5522; }
    .msg.error { background: #ffecec; border: 1px solid #ffb4b4; color: #7f1d1d; }
    .panel { border: 1px solid #d8dee8; border-radius: 8px; padding: 16px; margin-bottom: 18px; background: #fff; }
    .panel h2 { font-size: 18px; margin: 0 0 12px; }
    .summary-grid { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 10px; margin-bottom: 14px; }
    .summary-card { border: 1px solid #d8dee8; background: #f8fafc; border-radius: 6px; padding: 10px; }
    .summary-card strong { display: block; font-size: 20px; line-height: 1.2; }
    .summary-card span { color: #526070; font-size: 13px; }
    table { width: 100%; border-collapse: collapse; font-size: 13px; }
    th, td { border: 1px solid #ddd; padding: 8px; text-align: left; vertical-align: top; }
    th { background: #f0f0f0; }
    .scroll-table { overflow-x: auto; }
    .actions { display: flex; gap: 10px; flex-wrap: wrap; align-items: center; }
    .btn-primary-dark { background: #111827; border-color: #111827; color: #fff; }
    .btn-primary-dark:hover { background: #1f2937; border-color: #1f2937; color: #fff; }
    .small-muted { color: #666; font-size: 13px; }
    @media (max-width: 768px) { body { margin: 12px; } .wrap { padding: 14px; } .summary-grid { grid-template-columns: repeat(2, minmax(0, 1fr)); } }
  </style>
</head>
<body>
  <div class="wrap">
    <cfinclude template="includes/admin_reports_nav.cfm">

    <h1>Great Loop Bridges Import</h1>
    <p class="hint">Preview and import Bridge_Master CSV rows. The production import path accepts CSV only; XLSX conversion is a local/dev preparation step.</p>

    <cfif NOT isAuthorized>
      <div class="msg error"><strong>Unauthorized:</strong> Admin login is required.</div>
    <cfelse>
      <cfif len(messageText)>
        <cfoutput><div class="msg #encodeForHTMLAttribute(messageType)#">#encodeForHTML(messageText)#</div></cfoutput>
      </cfif>

      <section class="panel" aria-labelledby="uploadHeading">
        <h2 id="uploadHeading">Upload Bridge_Master CSV</h2>
        <form method="post" enctype="multipart/form-data">
          <div class="mb-3">
            <label for="bridgesFile" class="form-label">Bridge_Master.csv</label>
            <input type="file" class="form-control" id="bridgesFile" name="bridgesFile" accept=".csv,text/csv" required>
            <div class="form-text">Expected headers must match the workbook Bridge_Master sheet. Maximum file size: 10 MB.</div>
          </div>
          <button type="submit" name="previewImport" value="1" class="btn btn-primary-dark">Preview Import</button>
        </form>
      </section>

      <cfif structKeyExists(preview, "rows")>
        <section class="panel" aria-labelledby="previewHeading">
          <h2 id="previewHeading">Preview Summary</h2>
          <div class="summary-grid">
            <div class="summary-card"><cfoutput><strong>#numberFormat(preview.rowCount)#</strong></cfoutput><span>Parsed rows</span></div>
            <div class="summary-card"><cfoutput><strong>#numberFormat(preview.validRowCount)#</strong></cfoutput><span>Valid rows</span></div>
            <div class="summary-card"><cfoutput><strong>#numberFormat(arrayLen(preview.warnings))#</strong></cfoutput><span>Rows skipped/errors</span></div>
            <div class="summary-card"><cfoutput><strong>#numberFormat(arrayLen(preview.errors))#</strong></cfoutput><span>File/header errors</span></div>
            <div class="summary-card"><cfoutput><strong>#numberFormat(preview.publishedCount)#</strong></cfoutput><span>Published</span></div>
            <div class="summary-card"><cfoutput><strong>#numberFormat(preview.planningOnlyCount)#</strong></cfoutput><span>Planning only</span></div>
            <div class="summary-card"><cfoutput><strong>#numberFormat(preview.doNotPublishCount)#</strong></cfoutput><span>Do not publish</span></div>
            <div class="summary-card"><cfoutput><strong>#encodeForHTML(preview.sourceSheet)#</strong></cfoutput><span>Source sheet</span></div>
          </div>
          <cfoutput><p class="small-muted">Source file: #encodeForHTML(preview.sourceFilename)#</p></cfoutput>

          <cfif arrayLen(preview.errors)>
            <div class="msg error">
              <strong>Validation errors must be fixed before import.</strong>
              <ul class="mb-0">
                <cfloop array="#preview.errors#" index="issueItem"><cfoutput><li>#encodeForHTML(issueLabel(issueItem))#</li></cfoutput></cfloop>
              </ul>
            </div>
          </cfif>

          <cfif arrayLen(preview.warnings)>
            <div class="msg info">
              <strong>Rows that will be skipped</strong>
              <ul class="mb-0">
                <cfloop array="#preview.warnings#" index="issueItem"><cfoutput><li>#encodeForHTML(issueLabel(issueItem))#</li></cfoutput></cfloop>
              </ul>
            </div>
          </cfif>

          <div class="actions mb-3">
            <form method="post">
              <cfoutput><input type="hidden" name="previewNonce" value="#encodeForHTMLAttribute(preview.nonce)#"></cfoutput>
              <button type="submit" name="confirmImport" value="1" class="btn btn-danger" <cfif arrayLen(preview.errors)>disabled</cfif>>Confirm Import</button>
            </form>
            <form method="post">
              <button type="submit" name="cancelPreview" value="1" class="btn btn-outline-secondary">Clear Preview</button>
            </form>
            <span class="small-muted">Import updates existing rows by bridge_id first, then slug. Bad rows are skipped and reported.</span>
          </div>

          <div class="scroll-table">
            <table>
              <thead>
                <tr>
                  <th>Row</th>
                  <th>Bridge</th>
                  <th>Slug</th>
                  <th>Route Segment</th>
                  <th>Waterway</th>
                  <th>State</th>
                  <th>Type</th>
                  <th>Draw</th>
                  <th>VHF</th>
                  <th>Phone</th>
                  <th>Public Status</th>
                  <th>Verification</th>
                </tr>
              </thead>
              <tbody>
                <cfloop from="1" to="#min(arrayLen(preview.rows), 40)#" index="rowIndex">
                  <cfset rowItem = preview.rows[rowIndex]>
                  <cfoutput>
                    <tr>
                      <td>#encodeForHTML(rowItem.row_number)#</td>
                      <td>#encodeForHTML(rowItem.bridge_name)#</td>
                      <td>#encodeForHTML(rowItem.slug)#</td>
                      <td>#encodeForHTML(rowItem.route_segment)#</td>
                      <td>#encodeForHTML(rowItem.waterway)#</td>
                      <td>#encodeForHTML(rowItem.state_province)#</td>
                      <td>#encodeForHTML(rowItem.bridge_type)#</td>
                      <td>#encodeForHTML(rowItem.is_drawbridge)#</td>
                      <td>#encodeForHTML(rowItem.vhf_channel)#</td>
                      <td>#encodeForHTML(rowItem.phone)#</td>
                      <td>#encodeForHTML(rowItem.public_status)#</td>
                      <td>#encodeForHTML(rowItem.verification_status)#</td>
                    </tr>
                  </cfoutput>
                </cfloop>
              </tbody>
            </table>
          </div>
          <cfif arrayLen(preview.rows) GT 40>
            <p class="small-muted mt-2"><cfoutput>Showing first 40 of #numberFormat(arrayLen(preview.rows))# parsed rows.</cfoutput></p>
          </cfif>
        </section>
      </cfif>

      <cfif structKeyExists(importResult, "ERRORS") AND arrayLen(importResult.ERRORS)>
        <section class="panel">
          <h2>Import Row Errors</h2>
          <ul>
            <cfloop array="#importResult.ERRORS#" index="issueItem"><cfoutput><li>#encodeForHTML(issueLabel(issueItem))#</li></cfoutput></cfloop>
          </ul>
        </section>
      </cfif>
    </cfif>
  </div>
</body>
</html>
