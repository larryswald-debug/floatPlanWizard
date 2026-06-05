<cfsetting showdebugoutput="false">
<cfcontent type="text/html; charset=utf-8">
<cfinclude template="../includes/fpw_base_path.cfm">

<cfscript>
userStruct = (structKeyExists(session, "user") AND isStruct(session.user)) ? session.user : {};
isLoggedIn = structCount(userStruct) GT 0;
adminWhitelist = "admin@floatplanwizard.com,lswald@yahoo.com";
isAdmin = false;
isAuthorized = false;
sessionKey = "greatLoopLocksImportPreview";
messageText = "";
messageType = "";
preview = {};
importResult = {};
uploadPath = "";
uploadOriginalName = "";
uploadMime = "";
maxUploadBytes = 5 * 1024 * 1024;

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

function issueLabel(required struct item) {
    var rowLabel = (structKeyExists(arguments.item, "row") AND val(arguments.item.row) GT 0) ? ("Row " & val(arguments.item.row) & ": ") : "";
    var fieldLabel = (structKeyExists(arguments.item, "field") AND len(trim(toString(arguments.item.field)))) ? ("[" & trim(toString(arguments.item.field)) & "] ") : "";
    var messageLabel = structKeyExists(arguments.item, "message") ? trim(toString(arguments.item.message)) : "";
    return rowLabel & fieldLabel & messageLabel;
}

function safeDelete(required string filePath) {
    if (!len(trim(arguments.filePath))) {
        return;
    }
    try {
        if (fileExists(arguments.filePath)) {
            fileDelete(arguments.filePath);
        }
    } catch (any deleteError) {
        // Best effort temp upload cleanup only.
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
        messageText = "Import preview expired. Upload and preview the workbook again.";
    } else if (structKeyExists(session[sessionKey], "errors") AND arrayLen(session[sessionKey].errors)) {
        messageType = "error";
        messageText = "The preview has validation errors and cannot be imported.";
    } else {
        try {
            svc = "";
            try {
                svc = createObject("component", "api.v1.GreatLoopLocksImportService").init();
            } catch (any ePath) {
                svc = createObject("component", "fpw.api.v1.GreatLoopLocksImportService").init();
            }
            importResult = svc.importRows(
                session[sessionKey].rows,
                session[sessionKey].sourceFilename,
                session[sessionKey].sourceSheet,
                session[sessionKey].importBatchId
            );
            if (structKeyExists(importResult, "SUCCESS") AND importResult.SUCCESS) {
                structDelete(session, sessionKey, false);
                messageType = "success";
                messageText = "Imported " & importResult.INSERTED_ROWS & " Great Loop lock rows.";
            } else {
                messageType = "error";
                messageText = structKeyExists(importResult, "MESSAGE") ? importResult.MESSAGE : "Import failed.";
            }
        } catch (any eImport) {
            messageType = "error";
            messageText = "Import failed. Confirm the great_loop_locks migration has been run and try again.";
        }
    }
}
</cfscript>

<cfif isAuthorized AND structKeyExists(form, "previewImport")>
    <cftry>
        <cffile action="upload" filefield="locksFile" destination="#getTempDirectory()#" nameconflict="makeunique" result="uploadResult">
        <cfscript>
            uploadOriginalName = structKeyExists(uploadResult, "clientFile") ? uploadResult.clientFile : "";
            if (!len(uploadOriginalName) AND structKeyExists(uploadResult, "serverFile")) {
                uploadOriginalName = uploadResult.serverFile;
            }
            uploadPath = uploadResult.serverDirectory & "/" & uploadResult.serverFile;
            uploadMime = "";
            if (structKeyExists(uploadResult, "contentType")) {
                uploadMime = uploadResult.contentType;
                if (structKeyExists(uploadResult, "contentSubType") AND len(uploadResult.contentSubType)) {
                    uploadMime &= "/" & uploadResult.contentSubType;
                }
            }

            if (lCase(listLast(uploadOriginalName, ".")) NEQ "xlsx") {
                safeDelete(uploadPath);
                messageType = "error";
                messageText = "Upload rejected. Use a .xlsx workbook.";
            } else if (structKeyExists(uploadResult, "fileSize") AND isNumeric(uploadResult.fileSize) AND val(uploadResult.fileSize) GT maxUploadBytes) {
                safeDelete(uploadPath);
                messageType = "error";
                messageText = "Upload rejected. The workbook must be 5 MB or smaller.";
            } else {
                try {
                    svc = "";
                    try {
                        svc = createObject("component", "api.v1.GreatLoopLocksImportService").init();
                    } catch (any ePath) {
                        svc = createObject("component", "fpw.api.v1.GreatLoopLocksImportService").init();
                    }
                    parseResult = svc.parseWorkbook(uploadPath, uploadOriginalName, "Locks");
                    safeDelete(uploadPath);

                    if (len(uploadMime) AND !listFindNoCase("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet,application/octet-stream,application/zip", uploadMime)) {
                        arrayAppend(parseResult.WARNINGS, {
                            "row" = 0,
                            "field" = "file",
                            "message" = "Uploaded MIME type was not the expected .xlsx type."
                        });
                    }

                    parseResult.nonce = createUUID();
                    parseResult.importBatchId = createUUID();
                    parseResult.sourceFilename = parseResult.SOURCE_FILENAME;
                    parseResult.sourceSheet = parseResult.SOURCE_SHEET;
                    parseResult.rows = parseResult.ROWS;
                    parseResult.errors = parseResult.ERRORS;
                    parseResult.warnings = parseResult.WARNINGS;
                    parseResult.rowCount = parseResult.ROW_COUNT;
                    parseResult.validRowCount = parseResult.VALID_ROW_COUNT;
                    session[sessionKey] = parseResult;

                    messageType = parseResult.SUCCESS ? "success" : "error";
                    messageText = parseResult.MESSAGE;
                } catch (any eParse) {
                    safeDelete(uploadPath);
                    messageType = "error";
                    messageText = "The workbook could not be parsed. Confirm it is a valid .xlsx workbook with a Locks sheet.";
                }
            }
        </cfscript>
        <cfcatch type="any">
            <cfscript>
                safeDelete(uploadPath);
                messageType = "error";
                messageText = "Upload failed. Choose a valid .xlsx workbook and try again.";
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
  <title>Great Loop Locks Import</title>
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
    @media (max-width: 768px) {
      body { margin: 12px; }
      .wrap { padding: 14px; }
      .summary-grid { grid-template-columns: repeat(2, minmax(0, 1fr)); }
    }
  </style>
</head>
<body>
  <div class="wrap">
    <cfinclude template="includes/admin_reports_nav.cfm">

    <h1>Great Loop Locks Import</h1>
    <p class="hint">Preview and replace the admin Great Loop locks reference table from the approved XLSX workbook. This tool does not import waypoints or change route, float plan, or map behavior.</p>

    <cfif NOT isAuthorized>
      <div class="msg error">
        <strong>Unauthorized:</strong> Admin login is required.
      </div>
    <cfelse>
      <cfif len(messageText)>
        <cfoutput>
          <div class="msg #encodeForHtmlAttribute(messageType)#">#encodeForHtml(messageText)#</div>
        </cfoutput>
      </cfif>

      <section class="panel" aria-labelledby="uploadHeading">
        <h2 id="uploadHeading">Upload Workbook</h2>
        <form method="post" enctype="multipart/form-data">
          <div class="mb-3">
            <label for="locksFile" class="form-label">Great Loop locks XLSX</label>
            <input type="file" class="form-control" id="locksFile" name="locksFile" accept=".xlsx,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" required>
            <div class="form-text">Required sheet: Locks. Maximum file size: 5 MB. Optional public-library columns are previewed when present. The upload is parsed into a preview before any database write is available.</div>
          </div>
          <button type="submit" name="previewImport" value="1" class="btn btn-primary-dark">Preview Import</button>
        </form>
      </section>

      <cfif structKeyExists(preview, "rows")>
        <section class="panel" aria-labelledby="previewHeading">
          <h2 id="previewHeading">Preview Summary</h2>
          <div class="summary-grid">
            <div class="summary-card">
              <cfoutput><strong>#encodeForHtml(preview.rowCount)#</strong></cfoutput>
              <span>Parsed rows</span>
            </div>
            <div class="summary-card">
              <cfoutput><strong>#encodeForHtml(arrayLen(preview.errors))#</strong></cfoutput>
              <span>Errors</span>
            </div>
            <div class="summary-card">
              <cfoutput><strong>#encodeForHtml(arrayLen(preview.warnings))#</strong></cfoutput>
              <span>Warnings</span>
            </div>
            <div class="summary-card">
              <cfoutput><strong>#encodeForHtml(preview.sourceSheet)#</strong></cfoutput>
              <span>Sheet</span>
            </div>
          </div>
          <cfoutput>
            <p class="small-muted">Source file: #encodeForHtml(preview.sourceFilename)#</p>
          </cfoutput>

          <cfif arrayLen(preview.errors)>
            <div class="msg error">
              <strong>Validation errors must be fixed before import.</strong>
              <ul class="mb-0">
                <cfloop array="#preview.errors#" index="issueItem">
                  <cfoutput><li>#encodeForHtml(issueLabel(issueItem))#</li></cfoutput>
                </cfloop>
              </ul>
            </div>
          </cfif>

          <cfif arrayLen(preview.warnings)>
            <div class="msg info">
              <strong>Warnings</strong>
              <ul class="mb-0">
                <cfloop array="#preview.warnings#" index="issueItem">
                  <cfoutput><li>#encodeForHtml(issueLabel(issueItem))#</li></cfoutput>
                </cfloop>
              </ul>
            </div>
          </cfif>

          <div class="actions mb-3">
            <form method="post">
              <cfoutput><input type="hidden" name="previewNonce" value="#encodeForHtmlAttribute(preview.nonce)#"></cfoutput>
              <button type="submit" name="confirmImport" value="1" class="btn btn-danger" <cfif arrayLen(preview.errors)>disabled</cfif>>Confirm Replace-All Import</button>
            </form>
            <form method="post">
              <button type="submit" name="cancelPreview" value="1" class="btn btn-outline-secondary">Clear Preview</button>
            </form>
            <span class="small-muted">Confirm deletes existing great_loop_locks rows inside a transaction, then inserts the preview rows.</span>
          </div>

          <div class="scroll-table">
            <table>
              <thead>
                <tr>
                  <th>Row</th>
                  <th>Lock Name</th>
                  <th>Latitude</th>
                  <th>Longitude</th>
                  <th>Note</th>
                  <th>City</th>
                  <th>State</th>
                  <th>Zip</th>
                  <th>Phone</th>
                  <th>VHF</th>
                  <th>Slug</th>
                  <th>Waterway</th>
                  <th>Lock System</th>
                  <th>Authority</th>
                  <th>Country</th>
                  <th>Source</th>
                  <th>Source URL</th>
                  <th>Last Reviewed</th>
                  <th>Public</th>
                  <th>Sort</th>
                </tr>
              </thead>
              <tbody>
                <cfloop array="#preview.rows#" index="rowItem">
                  <cfoutput>
                    <tr>
                      <td>#encodeForHtml(rowItem.row_number)#</td>
                      <td>#encodeForHtml(rowItem.lock_name)#</td>
                      <td>#encodeForHtml(rowItem.latitude)#</td>
                      <td>#encodeForHtml(rowItem.longitude)#</td>
                      <td>#encodeForHtml(rowItem.note)#</td>
                      <td>#encodeForHtml(rowItem.city)#</td>
                      <td>#encodeForHtml(rowItem.state)#</td>
                      <td>#encodeForHtml(rowItem.zip)#</td>
                      <td>#encodeForHtml(rowItem.phone)#</td>
                      <td>#encodeForHtml(rowItem.vhf)#</td>
                      <td>#encodeForHtml(structKeyExists(rowItem, "slug") ? rowItem.slug : "")#</td>
                      <td>#encodeForHtml(structKeyExists(rowItem, "waterway") ? rowItem.waterway : "")#</td>
                      <td>#encodeForHtml(structKeyExists(rowItem, "lock_system") ? rowItem.lock_system : "")#</td>
                      <td>#encodeForHtml(structKeyExists(rowItem, "operating_authority") ? rowItem.operating_authority : "")#</td>
                      <td>#encodeForHtml(structKeyExists(rowItem, "country") ? rowItem.country : "")#</td>
                      <td>#encodeForHtml(structKeyExists(rowItem, "source_name") ? rowItem.source_name : "")#</td>
                      <td>#encodeForHtml(structKeyExists(rowItem, "source_url") ? rowItem.source_url : "")#</td>
                      <td>#encodeForHtml(structKeyExists(rowItem, "last_reviewed_at") ? rowItem.last_reviewed_at : "")#</td>
                      <td>#encodeForHtml(structKeyExists(rowItem, "is_public") ? rowItem.is_public : "")#</td>
                      <td>#encodeForHtml(structKeyExists(rowItem, "sort_order") ? rowItem.sort_order : "")#</td>
                    </tr>
                  </cfoutput>
                </cfloop>
              </tbody>
            </table>
          </div>
        </section>
      </cfif>
    </cfif>
  </div>
</body>
</html>
