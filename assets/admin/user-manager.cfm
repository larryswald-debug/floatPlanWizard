<cfsetting showdebugoutput="false">
<cfcontent type="text/html; charset=utf-8">
<cfscript>
userStruct = (structKeyExists(session, "user") AND isStruct(session.user)) ? session.user : {};
isLoggedIn = structCount(userStruct) GT 0;
isAdmin = false;
adminWhitelist = "admin@floatplanwizard.com,lswald@yahoo.com";
roleValue = "";
emailValue = "";

function boolLike(any value, boolean defaultValue=false) {
    var txt = lCase(trim(toString(arguments.value)));
    if (!len(txt)) return arguments.defaultValue;
    if (listFindNoCase("1,true,yes,y,on", txt)) return true;
    if (listFindNoCase("0,false,no,n,off", txt)) return false;
    if (isNumeric(txt)) return (val(txt) NEQ 0);
    return arguments.defaultValue;
}

if (isLoggedIn) {
    if (structKeyExists(userStruct, "isAdmin") AND boolLike(userStruct.isAdmin, false)) {
        isAdmin = true;
    } else if (structKeyExists(userStruct, "ISADMIN") AND boolLike(userStruct.ISADMIN, false)) {
        isAdmin = true;
    } else if (structKeyExists(userStruct, "is_admin") AND boolLike(userStruct.is_admin, false)) {
        isAdmin = true;
    } else {
        if (structKeyExists(userStruct, "role")) {
            roleValue = lCase(trim(toString(userStruct.role)));
        } else if (structKeyExists(userStruct, "ROLE")) {
            roleValue = lCase(trim(toString(userStruct.ROLE)));
        }
        if (roleValue EQ "admin") {
            isAdmin = true;
        } else {
            if (structKeyExists(userStruct, "email")) {
                emailValue = lCase(trim(toString(userStruct.email)));
            } else if (structKeyExists(userStruct, "EMAIL")) {
                emailValue = lCase(trim(toString(userStruct.EMAIL)));
            }
            if (len(emailValue) AND listFindNoCase(adminWhitelist, emailValue)) {
                isAdmin = true;
            }
        }
    }
}

isAuthorized = isLoggedIn AND isAdmin;
</cfscript>
<cfinclude template="../includes/fpw_base_path.cfm">

<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Admin User Manager</title>
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" crossorigin="anonymous">
  <style>
    body { font-family: Arial, sans-serif; margin: 24px; background: #f7f7f7; color: #111; }
    .wrap { max-width: 1480px; margin: 0 auto; background: #fff; border: 1px solid #ddd; border-radius: 8px; padding: 20px; }
    h1 { margin-top: 0; font-size: 24px; }
    .hint { color: #444; margin-bottom: 16px; }
    .toolbar { display: grid; gap: 10px; grid-template-columns: repeat(4, minmax(0, 1fr)); margin-bottom: 12px; }
    .toolbar .field { display: flex; flex-direction: column; gap: 6px; }
    .toolbar label { font-weight: 700; font-size: 13px; color: #333; }
    .toolbar input, .toolbar select { border: 1px solid #bbb; border-radius: 4px; font-size: 14px; padding: 8px; }
    .toolbar-actions { display: flex; gap: 8px; flex-wrap: wrap; margin: 12px 0; }
    .toolbar-actions button { padding: 8px 12px; border-radius: 4px; border: 1px solid #666; background: #efefef; cursor: pointer; font-size: 14px; }
    .toolbar-actions button.primary { background: #111; border-color: #111; color: #fff; }
    .toolbar-actions button.danger { background: #c82333; border-color: #9f1d1d; color: #fff; }
    .summary-line { display: flex; justify-content: space-between; align-items: center; gap: 8px; flex-wrap: wrap; font-size: 14px; color: #444; margin: 8px 0 12px; }
    table { width: 100%; border-collapse: collapse; font-size: 14px; }
    th, td { border: 1px solid #ddd; padding: 8px; text-align: left; vertical-align: top; }
    th { background: #f0f0f0; }
    td.num { text-align: right; white-space: nowrap; font-family: Consolas, Menlo, Monaco, monospace; }
    td.actions { white-space: nowrap; }
    .btn-inline { padding: 4px 8px; border-radius: 4px; border: 1px solid #666; background: #efefef; cursor: pointer; font-size: 12px; }
    .btn-inline.danger { background: #c82333; border-color: #9f1d1d; color: #fff; }
    .pager { display: flex; justify-content: flex-end; align-items: center; gap: 8px; margin-top: 10px; }
    .msg { margin-bottom: 12px; padding: 10px; border-radius: 4px; display: none; }
    .msg.info { background: #edf2ff; border: 1px solid #b6c6ff; color: #13255a; display: block; }
    .msg.success { background: #e9f8ee; border: 1px solid #9dd9ad; color: #0e5522; display: block; }
    .msg.error { background: #ffecec; border: 1px solid #ffb4b4; color: #7f1d1d; display: block; }
    .small-muted { color: #666; font-size: 12px; }
    .row-gap { row-gap: 10px; }
    .address-card { border: 1px solid #d7dee8; border-radius: 6px; padding: 12px; margin-bottom: 10px; background: #fbfdff; }
    .delete-counts { max-height: 300px; overflow: auto; border: 1px solid #ddd; border-radius: 4px; }
    .delete-counts table { margin-bottom: 0; }
    @media (max-width: 1200px) {
      .toolbar { grid-template-columns: repeat(2, minmax(0, 1fr)); }
    }
    @media (max-width: 768px) {
      .toolbar { grid-template-columns: repeat(1, minmax(0, 1fr)); }
      .wrap { margin: 10px; padding: 14px; }
    }
  </style>
</head>
<body>
  <div class="wrap">
    <cfinclude template="includes/admin_reports_nav.cfm">

    <h1>Admin User Manager</h1>
    <p class="hint">Search users, update identity data, manage address/contact identity fields, and delete one disposable QA user with a preview first.</p>

    <cfif NOT isAuthorized>
      <div class="msg error">
        <strong>Unauthorized:</strong> Admin login is required.
      </div>
    <cfelse>
      <div id="adminUserMessage" class="msg"></div>

      <form id="adminUserFilters" novalidate>
        <div class="toolbar">
          <div class="field">
            <label for="filterSearch">User Search</label>
            <input type="text" id="filterSearch" placeholder="first, last, email, phone, user id">
          </div>
          <div class="field">
            <label for="filterEmail">Email</label>
            <input type="text" id="filterEmail" placeholder="contains...">
          </div>
          <div class="field">
            <label for="filterPhone">Phone</label>
            <input type="text" id="filterPhone" placeholder="mobile or address phone">
          </div>
          <div class="field">
            <label for="filterUserId">User ID</label>
            <input type="text" id="filterUserId" placeholder="e.g. 187">
          </div>
          <div class="field">
            <label for="filterLimit">Page Size</label>
            <select id="filterLimit">
              <option value="25">25</option>
              <option value="50" selected>50</option>
              <option value="100">100</option>
              <option value="200">200</option>
            </select>
          </div>
        </div>
        <div class="toolbar-actions">
          <button type="submit" class="primary">Search</button>
          <button type="button" id="resetFiltersBtn">Reset</button>
        </div>
      </form>

      <div class="summary-line">
        <div id="userSummaryLine">Loading users...</div>
      </div>

      <div class="table-responsive">
        <table>
          <thead>
            <tr>
              <th style="width:80px;">User ID</th>
              <th style="width:190px;">Name</th>
              <th style="width:240px;">Email</th>
              <th style="width:160px;">Mobile Phone</th>
              <th style="width:160px;">Address Phone</th>
              <th style="width:120px;">Created</th>
              <th style="width:120px;">Last Login</th>
              <th style="width:160px;">Actions</th>
            </tr>
          </thead>
          <tbody id="userTableBody">
            <tr><td colspan="8">Loading...</td></tr>
          </tbody>
        </table>
      </div>

      <div class="pager">
        <button type="button" id="prevPageBtn">Previous</button>
        <span id="pagerInfo">Page 1</span>
        <button type="button" id="nextPageBtn">Next</button>
      </div>
    </cfif>
  </div>

  <cfif isAuthorized>
    <div class="modal fade" id="adminUserModal" tabindex="-1" aria-labelledby="adminUserModalLabel" aria-hidden="true" data-bs-backdrop="static" data-bs-keyboard="false">
      <div class="modal-dialog modal-xl modal-dialog-scrollable">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title" id="adminUserModalLabel">User</h5>
            <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
          </div>
          <div class="modal-body">
            <form id="adminUserForm" novalidate>
              <input type="hidden" id="modalUserId" value="0">
              <div class="row row-gap">
                <div class="col-md-3">
                  <label class="form-label" for="modalUserIdDisplay">User ID</label>
                  <input type="text" class="form-control" id="modalUserIdDisplay" readonly>
                </div>
                <div class="col-md-3">
                  <label class="form-label" for="modalFirstName">First Name</label>
                  <input type="text" class="form-control" id="modalFirstName" maxlength="45">
                </div>
                <div class="col-md-3">
                  <label class="form-label" for="modalLastName">Last Name</label>
                  <input type="text" class="form-control" id="modalLastName" maxlength="45">
                </div>
                <div class="col-md-3">
                  <label class="form-label" for="modalMobilePhone">Mobile Phone</label>
                  <input type="text" class="form-control" id="modalMobilePhone" maxlength="50">
                </div>
              </div>
              <div class="row row-gap mt-1">
                <div class="col-md-6">
                  <label class="form-label" for="modalEmail">Email *</label>
                  <input type="email" class="form-control" id="modalEmail" maxlength="255" required>
                </div>
                <div class="col-md-6">
                  <label class="form-label" for="modalHostekUserId">Hostek User ID</label>
                  <input type="text" class="form-control" id="modalHostekUserId" maxlength="255">
                </div>
              </div>
              <div class="row row-gap mt-2">
                <div class="col-md-3">
                  <label class="form-label" for="modalCreated">Created</label>
                  <input type="text" class="form-control" id="modalCreated" readonly>
                </div>
                <div class="col-md-3">
                  <label class="form-label" for="modalLastLogin">Last Login</label>
                  <input type="text" class="form-control" id="modalLastLogin" readonly>
                </div>
                <div class="col-md-3">
                  <label class="form-label" for="modalLastUpdate">Last Update</label>
                  <input type="text" class="form-control" id="modalLastUpdate" readonly>
                </div>
                <div class="col-md-3">
                  <label class="form-label" for="modalPhotoFileId">Photo File ID</label>
                  <input type="text" class="form-control" id="modalPhotoFileId" readonly>
                </div>
              </div>
              <div class="row row-gap mt-1">
                <div class="col-md-3">
                  <label class="form-label" for="modalRequestReset">Request Reset</label>
                  <input type="text" class="form-control" id="modalRequestReset" readonly>
                </div>
                <div class="col-md-3">
                  <label class="form-label" for="modalResetId">Reset ID</label>
                  <input type="text" class="form-control" id="modalResetId" readonly>
                </div>
                <div class="col-md-3">
                  <label class="form-label" for="modalPasswordCreated">Password Created</label>
                  <input type="text" class="form-control" id="modalPasswordCreated" readonly>
                </div>
                <div class="col-md-3">
                  <label class="form-label" for="modalPasswordState">Password</label>
                  <input type="text" class="form-control" id="modalPasswordState" value="Not editable here" readonly>
                </div>
              </div>

              <div class="d-flex justify-content-between align-items-center mt-3">
                <h6 class="mb-0">Address / Contact Identity</h6>
                <button class="btn btn-outline-secondary btn-sm" type="button" id="addAddressBtn">Add Address Row</button>
              </div>
              <div class="small-muted mb-2">Existing address rows are updated. New rows are created when saved.</div>
              <div id="addressRows"></div>
            </form>
          </div>
          <div class="modal-footer">
            <button type="button" class="btn btn-outline-danger me-auto" id="openDeleteUserBtn">Delete User</button>
            <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancel</button>
            <button type="button" class="btn btn-primary" id="saveUserBtn">Save User</button>
          </div>
        </div>
      </div>
    </div>

    <div class="modal fade" id="deleteUserModal" tabindex="-1" aria-labelledby="deleteUserModalLabel" aria-hidden="true" data-bs-backdrop="static" data-bs-keyboard="false">
      <div class="modal-dialog modal-lg modal-dialog-scrollable">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title" id="deleteUserModalLabel">Delete User</h5>
            <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
          </div>
          <div class="modal-body">
            <div id="deleteUserSummary" class="msg info"></div>
            <div class="delete-counts mb-3" id="deleteUserCounts"></div>
            <label class="form-label" for="deleteConfirmation">Confirmation</label>
            <input type="text" class="form-control" id="deleteConfirmation" autocomplete="off" placeholder="I UNDERSTAND THIS DELETES ONE FPW USER">
            <div class="small-muted mt-2">Type the exact confirmation text before deleting.</div>
          </div>
          <div class="modal-footer">
            <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancel</button>
            <button type="button" class="btn btn-danger" id="executeDeleteUserBtn" disabled>Delete User</button>
          </div>
        </div>
      </div>
    </div>
  </cfif>

  <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js" crossorigin="anonymous"></script>
  <cfoutput>
    <script>
      window.FPW_BASE = "#JSStringFormat(request.fpwBase)#";
      window.FPW_API_BASE = "#JSStringFormat(request.fpwApiBase)#";
    </script>
  </cfoutput>
  <cfif isAuthorized>
    <script src="<cfoutput>#encodeForHTMLAttribute(request.fpwBase)#</cfoutput>/assets/js/app/admin/user-manager.js?v=20260526-cache-bump"></script>
  </cfif>
</body>
</html>
