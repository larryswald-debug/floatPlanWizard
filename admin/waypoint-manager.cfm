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

<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Admin Waypoint Manager</title>
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" crossorigin="anonymous">
  <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" crossorigin="">
  <style>
    body { font-family: Arial, sans-serif; margin: 24px; background: #f7f7f7; color: #111; }
    .wrap { max-width: 1280px; margin: 0 auto; background: #fff; border: 1px solid #ddd; border-radius: 8px; padding: 20px; }
    .admin-nav { display: flex; gap: 8px; margin-bottom: 14px; flex-wrap: wrap; }
    .admin-nav a { text-decoration: none; border: 1px solid #bbb; background: #f5f5f5; color: #222; padding: 6px 10px; border-radius: 4px; font-size: 14px; }
    .admin-nav a.active { background: #111; border-color: #111; color: #fff; }
    h1 { margin-top: 0; font-size: 24px; }
    .hint { color: #444; margin-bottom: 16px; }
    .toolbar { display: grid; gap: 10px; grid-template-columns: repeat(6, minmax(0, 1fr)); margin-bottom: 12px; }
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
    .waypoint-map-frame { height: 320px; border: 1px solid #cfd6e3; border-radius: 6px; margin-bottom: 8px; }
    .coord-actions { display: flex; justify-content: flex-end; margin-bottom: 10px; }
    .small-muted { color: #666; font-size: 12px; }
    .row-gap { row-gap: 10px; }
    @media (max-width: 1200px) {
      .toolbar { grid-template-columns: repeat(3, minmax(0, 1fr)); }
    }
    @media (max-width: 768px) {
      .toolbar { grid-template-columns: repeat(2, minmax(0, 1fr)); }
      .wrap { margin: 10px; padding: 14px; }
    }
  </style>
</head>
<body>
  <div class="wrap">
    <nav class="admin-nav" aria-label="Admin Tools">
      <a href="/fpw/admin/floatplan-cleanup.cfm">FloatPlan Cleanup</a>
      <a href="/fpw/admin/route-cleanup.cfm">Route Cleanup</a>
      <a href="/fpw/admin/fuel-calculator.cfm">Fuel Calculator</a>
      <a href="/fpw/admin/waypoint-manager.cfm" class="active">Waypoint Manager</a>
    </nav>

    <h1>Admin Waypoint Manager</h1>
    <p class="hint">Manage user waypoints with full CRUD and batch delete. Map click/drag updates waypoint coordinates.</p>

    <cfif NOT isAuthorized>
      <div class="msg error">
        <strong>Unauthorized:</strong> Admin login is required.
      </div>
    <cfelse>
      <div id="adminWaypointMessage" class="msg"></div>

      <form id="adminWaypointFilters" novalidate>
        <div class="toolbar">
          <div class="field">
            <label for="filterUserId">User ID</label>
            <input type="text" id="filterUserId" placeholder="e.g. 187">
          </div>
          <div class="field">
            <label for="filterUserEmail">User Email</label>
            <input type="text" id="filterUserEmail" placeholder="contains...">
          </div>
          <div class="field">
            <label for="filterSearch">Waypoint Search</label>
            <input type="text" id="filterSearch" placeholder="name or notes">
          </div>
          <div class="field">
            <label for="filterHasCoords">Has Coordinates</label>
            <select id="filterHasCoords">
              <option value="all">All</option>
              <option value="yes">Yes</option>
              <option value="no">No</option>
            </select>
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
          <div class="field">
            <label for="deleteMode">
              <input type="checkbox" id="deleteMode" style="margin-right:6px;">
              Unlink floatplan refs before delete
            </label>
            <div class="small-muted">Required if waypoint is in use.</div>
          </div>
        </div>
        <div class="toolbar-actions">
          <button type="submit" class="primary">Search</button>
          <button type="button" id="resetFiltersBtn">Reset</button>
          <button type="button" id="addWaypointBtn">Add Waypoint</button>
          <button type="button" id="batchDeleteBtn" class="danger">Delete Selected</button>
        </div>
      </form>

      <div class="summary-line">
        <div id="waypointSummaryLine">Loading waypoints...</div>
        <div id="selectionSummary">0 selected</div>
      </div>

      <div class="table-responsive">
        <table>
          <thead>
            <tr>
              <th style="width:40px;"><input type="checkbox" id="selectAllRows" aria-label="Select all rows"></th>
              <th style="width:70px;">ID</th>
              <th style="width:220px;">User</th>
              <th>Waypoint</th>
              <th style="width:180px;">Coordinates</th>
              <th style="width:90px;">Usage</th>
              <th>Notes</th>
              <th style="width:140px;">Actions</th>
            </tr>
          </thead>
          <tbody id="waypointTableBody">
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
    <div class="modal fade" id="adminWaypointModal" tabindex="-1" aria-labelledby="adminWaypointModalLabel" aria-hidden="true" data-bs-backdrop="static" data-bs-keyboard="false">
      <div class="modal-dialog modal-xl modal-dialog-scrollable">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title" id="adminWaypointModalLabel">Waypoint</h5>
            <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
          </div>
          <div class="modal-body">
            <form id="adminWaypointForm" novalidate>
              <input type="hidden" id="modalWaypointId" value="0">
              <div id="adminWaypointMap" class="waypoint-map-frame"></div>
              <div class="small-muted mb-2">Tip: click on map or drag marker to update latitude/longitude.</div>
              <div class="coord-actions">
                <button type="button" class="btn btn-outline-secondary btn-sm" id="clearMapPointBtn">Clear Coordinates</button>
              </div>
              <div class="row row-gap">
                <div class="col-md-4">
                  <label class="form-label" for="modalUserId">User ID *</label>
                  <input type="text" class="form-control" id="modalUserId" required>
                </div>
                <div class="col-md-8">
                  <label class="form-label" for="modalUserLookup">User Lookup</label>
                  <div class="input-group">
                    <input type="text" class="form-control" id="modalUserSearch" placeholder="Search user email/name/id">
                    <button class="btn btn-outline-secondary" type="button" id="modalLoadUsersBtn">Load</button>
                    <select class="form-select" id="modalUserLookup" style="max-width: 420px;">
                      <option value="">Select user…</option>
                    </select>
                  </div>
                </div>
              </div>
              <div class="row row-gap mt-1">
                <div class="col-md-8">
                  <label class="form-label" for="modalWaypointName">Waypoint Name *</label>
                  <input type="text" class="form-control" id="modalWaypointName" required>
                </div>
                <div class="col-md-4">
                  <label class="form-label" for="modalUsageCount">Current Usage</label>
                  <input type="text" class="form-control" id="modalUsageCount" value="0" readonly>
                </div>
              </div>
              <div class="row row-gap mt-1">
                <div class="col-md-6">
                  <label class="form-label" for="modalLatitude">Latitude</label>
                  <input type="text" class="form-control" id="modalLatitude">
                </div>
                <div class="col-md-6">
                  <label class="form-label" for="modalLongitude">Longitude</label>
                  <input type="text" class="form-control" id="modalLongitude">
                </div>
              </div>
              <div class="row row-gap mt-1">
                <div class="col-md-12">
                  <label class="form-label" for="modalNotes">Notes</label>
                  <textarea class="form-control" id="modalNotes" rows="3"></textarea>
                </div>
              </div>
            </form>
          </div>
          <div class="modal-footer">
            <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancel</button>
            <button type="button" class="btn btn-primary" id="saveWaypointBtn">Save Waypoint</button>
          </div>
        </div>
      </div>
    </div>
  </cfif>

  <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js" crossorigin="anonymous"></script>
  <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js" crossorigin=""></script>
  <script src="/fpw/assets/js/maps/leaflet-noaa-waypoint-map.js?v=20260225a"></script>
  <cfif isAuthorized>
    <script src="/fpw/assets/js/app/admin/waypoint-manager.js?v=20260225a"></script>
  </cfif>
</body>
</html>
