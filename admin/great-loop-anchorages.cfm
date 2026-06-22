<cfsetting showdebugoutput="false">
<cfcontent type="text/html; charset=utf-8">
<cfscript>
userStruct = (structKeyExists(session, "user") AND isStruct(session.user)) ? session.user : {};
isLoggedIn = structCount(userStruct) GT 0;
isAdmin = false;
adminWhitelist = "admin@floatplanwizard.com,lswald@yahoo.com";
roleValue = "";
emailValue = "";
adminNonce = "";

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
if (isAuthorized) {
    if (!structKeyExists(session, "greatLoopAnchoragesAdminNonce") OR !len(trim(toString(session.greatLoopAnchoragesAdminNonce)))) {
        session.greatLoopAnchoragesAdminNonce = createUUID();
    }
    adminNonce = session.greatLoopAnchoragesAdminNonce;
}
</cfscript>
<cfinclude template="../includes/fpw_base_path.cfm">

<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Great Loop Anchorages Admin</title>
  <link rel="icon" href="data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 64 64'%3E%3Crect width='64' height='64' rx='14' fill='%2306131d'/%3E%3Cpath d='M32 10v44M10 32h44M17 17l30 30M47 17 17 47' stroke='%2321f3ee' stroke-width='5' stroke-linecap='round'/%3E%3Ccircle cx='32' cy='32' r='14' fill='none' stroke='%2367d8ff' stroke-width='5'/%3E%3Ccircle cx='32' cy='32' r='5' fill='%23ffd18a'/%3E%3C/svg%3E">
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" crossorigin="anonymous">
  <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" integrity="sha256-p4NxAoJBhIIN+hmNHrzRCf9tD/miZyoHS5obTRR9BMY=" crossorigin="">
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
    .badge-soft { display: inline-block; border: 1px solid #c8d0db; border-radius: 999px; padding: 2px 8px; background: #f8fafc; font-size: 12px; }
    .badge-soft.ok { background: #e9f8ee; border-color: #9dd9ad; color: #0e5522; }
    .badge-soft.warn { background: #fff7ed; border-color: #fed7aa; color: #9a3412; }
    .pager { display: flex; justify-content: flex-end; align-items: center; gap: 8px; margin-top: 10px; }
    .msg { margin-bottom: 12px; padding: 10px; border-radius: 4px; display: none; }
    .msg.info { background: #edf2ff; border: 1px solid #b6c6ff; color: #13255a; display: block; }
    .msg.success { background: #e9f8ee; border: 1px solid #9dd9ad; color: #0e5522; display: block; }
    .msg.error { background: #ffecec; border: 1px solid #ffb4b4; color: #7f1d1d; display: block; }
    .small-muted { color: #666; font-size: 12px; }
    .row-gap { row-gap: 10px; }
    .coord-row { align-items: end; }
    .anchorage-map-panel { border: 1px solid #d8dee8; border-radius: 6px; padding: 10px; background: #f8fafc; }
    .anchorage-map-canvas { height: 360px; border: 1px solid #c8d0db; border-radius: 6px; background: #eef2f7; }
    textarea.form-control { min-height: 90px; }
    @media (max-width: 1200px) {
      .toolbar { grid-template-columns: repeat(2, minmax(0, 1fr)); }
    }
    @media (max-width: 768px) {
      body { margin: 12px; }
      .wrap { padding: 14px; }
      .toolbar { grid-template-columns: repeat(1, minmax(0, 1fr)); }
    }
  </style>
</head>
<body>
  <div class="wrap">
    <cfinclude template="includes/admin_reports_nav.cfm">

    <h1>Great Loop Anchorages</h1>
    <p class="hint">Create, search, filter, edit, save, and delete Great Loop anchorage rows. Public pages continue to use only published rows.</p>

    <cfif NOT isAuthorized>
      <div class="msg error">
        <strong>Unauthorized:</strong> Admin login is required.
      </div>
    <cfelse>
      <div id="greatLoopAnchoragesMessage" class="msg"></div>

      <form id="greatLoopAnchoragesFilters" novalidate>
        <div class="toolbar">
          <div class="field">
            <label for="filterSearch">Search</label>
            <input type="text" id="filterSearch" placeholder="name, city, state, waterway, notes">
          </div>
          <div class="field">
            <label for="filterLocationGroup">Location Group</label>
            <select id="filterLocationGroup"><option value="">All</option></select>
          </div>
          <div class="field">
            <label for="filterWaterway">Waterway</label>
            <select id="filterWaterway"><option value="">All</option></select>
          </div>
          <div class="field">
            <label for="filterStateProvince">State / Province</label>
            <select id="filterStateProvince"><option value="">All</option></select>
          </div>
          <div class="field">
            <label for="filterCountry">Country</label>
            <select id="filterCountry"><option value="">All</option></select>
          </div>
          <div class="field">
            <label for="filterAnchorageType">Anchorage Type</label>
            <select id="filterAnchorageType"><option value="">All</option></select>
          </div>
          <div class="field">
            <label for="filterPublicStatus">Public Status</label>
            <select id="filterPublicStatus"><option value="">All</option></select>
          </div>
          <div class="field">
            <label for="filterVerificationStatus">Verification Status</label>
            <select id="filterVerificationStatus"><option value="">All</option></select>
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
          <button type="button" id="addAnchorageBtn">New Anchorage</button>
        </div>
      </form>

      <div class="summary-line">
        <div id="greatLoopAnchoragesSummaryLine">Loading anchorages...</div>
      </div>

      <div class="table-responsive">
        <table>
          <thead>
            <tr>
              <th style="width:90px;">ID</th>
              <th style="width:220px;">Anchorage Name</th>
              <th style="width:160px;">Location Group</th>
              <th style="width:160px;">Waterway</th>
              <th style="width:130px;">City</th>
              <th style="width:90px;">State</th>
              <th style="width:90px;">Country</th>
              <th style="width:120px;">Type</th>
              <th style="width:95px;">Published</th>
              <th style="width:130px;">Verification</th>
              <th style="width:135px;">Coordinates</th>
              <th style="width:120px;">Actions</th>
            </tr>
          </thead>
          <tbody id="greatLoopAnchoragesTableBody">
            <tr><td colspan="12">Loading...</td></tr>
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
    <div class="modal fade" id="greatLoopAnchorageModal" tabindex="-1" aria-labelledby="greatLoopAnchorageModalLabel" aria-hidden="true" data-bs-backdrop="static" data-bs-keyboard="false">
      <div class="modal-dialog modal-xl modal-dialog-scrollable">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title" id="greatLoopAnchorageModalLabel">Great Loop Anchorage</h5>
            <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
          </div>
          <div class="modal-body">
            <div id="greatLoopAnchorageModalMessage" class="msg"></div>
            <form id="greatLoopAnchorageForm" novalidate>
              <input type="hidden" id="modalAnchorageId" value="">

              <div class="row row-gap">
                <div class="col-md-3">
                  <label class="form-label" for="modalAnchorageIdDisplay">Anchorage ID</label>
                  <input type="text" class="form-control" id="modalAnchorageIdDisplay" readonly>
                </div>
                <div class="col-md-6">
                  <label class="form-label" for="modalAnchorageName">Anchorage Name *</label>
                  <input type="text" class="form-control" id="modalAnchorageName" maxlength="180" required>
                </div>
                <div class="col-md-3">
                  <label class="form-label" for="modalSlug">Slug *</label>
                  <input type="text" class="form-control" id="modalSlug" maxlength="120" required>
                </div>

                <div class="col-md-4">
                  <label class="form-label" for="modalLocationGroup">Location Group *</label>
                  <input type="text" class="form-control" id="modalLocationGroup" maxlength="120" required>
                </div>
                <div class="col-md-4">
                  <label class="form-label" for="modalWaterway">Waterway</label>
                  <input type="text" class="form-control" id="modalWaterway" maxlength="120">
                </div>
                <div class="col-md-4">
                  <label class="form-label" for="modalNearestCity">Nearest City</label>
                  <input type="text" class="form-control" id="modalNearestCity" maxlength="120">
                </div>

                <div class="col-md-3">
                  <label class="form-label" for="modalStateProvince">State / Province</label>
                  <input type="text" class="form-control" id="modalStateProvince" maxlength="32">
                </div>
                <div class="col-md-3">
                  <label class="form-label" for="modalCountry">Country</label>
                  <input type="text" class="form-control" id="modalCountry" maxlength="64">
                </div>
                <div class="col-md-3">
                  <label class="form-label" for="modalAnchorageType">Anchorage Type</label>
                  <input type="text" class="form-control" id="modalAnchorageType" maxlength="80">
                </div>
                <div class="col-md-3">
                  <label class="form-label" for="modalPublicStatus">Public Status</label>
                  <input type="text" class="form-control" id="modalPublicStatus" maxlength="80">
                </div>

                <div class="col-md-3">
                  <label class="form-label" for="modalHolding">Holding</label>
                  <input type="text" class="form-control" id="modalHolding" maxlength="80">
                </div>
                <div class="col-md-3">
                  <label class="form-label" for="modalProtection">Protection</label>
                  <input type="text" class="form-control" id="modalProtection" maxlength="80">
                </div>
                <div class="col-md-3">
                  <label class="form-label" for="modalShoreAccess">Shore Access</label>
                  <input type="text" class="form-control" id="modalShoreAccess" maxlength="80">
                </div>
                <div class="col-md-3">
                  <label class="form-label" for="modalVerificationStatus">Verification Status</label>
                  <input type="text" class="form-control" id="modalVerificationStatus" maxlength="80">
                </div>

                <div class="col-md-4">
                  <label class="form-label" for="modalLatitude">Latitude</label>
                  <input type="number" step="0.0000001" class="form-control" id="modalLatitude">
                </div>
                <div class="col-md-4">
                  <label class="form-label" for="modalLongitude">Longitude</label>
                  <input type="number" step="0.0000001" class="form-control" id="modalLongitude">
                </div>
                <div class="col-md-4 d-flex align-items-end gap-2">
                  <button type="button" class="btn btn-outline-secondary w-100" id="toggleAnchorageMapBtn">Open Map</button>
                </div>

                <div class="col-12" id="anchorageMapPanel" hidden>
                  <div class="anchorage-map-panel">
                    <div id="adminAnchorageMap" class="anchorage-map-canvas" aria-label="Anchorage coordinate editor map"></div>
                    <div class="small-muted mt-2">Click the map or drag the marker to update latitude and longitude. Save the anchorage to persist changes.</div>
                  </div>
                </div>

                <div class="col-md-4">
                  <label class="form-label" for="modalSourceName">Source Name</label>
                  <input type="text" class="form-control" id="modalSourceName" maxlength="180">
                </div>
                <div class="col-md-8">
                  <label class="form-label" for="modalSourceUrl">Source URL</label>
                  <input type="url" class="form-control" id="modalSourceUrl" maxlength="500">
                </div>

                <div class="col-md-4">
                  <label class="form-label" for="modalGreatLoopRelevance">Great Loop Relevance</label>
                  <input type="text" class="form-control" id="modalGreatLoopRelevance" maxlength="120">
                </div>
                <div class="col-md-4">
                  <label class="form-label" for="modalDuplicateReviewNote">Duplicate Review Note</label>
                  <input type="text" class="form-control" id="modalDuplicateReviewNote" maxlength="80">
                </div>
                <div class="col-md-4">
                  <label class="form-label" for="modalLastReviewed">Last Reviewed</label>
                  <input type="date" class="form-control" id="modalLastReviewed">
                </div>

                <div class="col-md-4">
                  <label class="form-label" for="modalReviewedBy">Reviewed By</label>
                  <input type="text" class="form-control" id="modalReviewedBy" maxlength="100">
                </div>
                <div class="col-md-4">
                  <label class="form-label" for="modalReviewedAt">Reviewed At</label>
                  <input type="datetime-local" class="form-control" id="modalReviewedAt">
                </div>
                <div class="col-md-4 d-flex align-items-end">
                  <div class="form-check">
                    <input class="form-check-input" type="checkbox" id="modalIsPublished">
                    <label class="form-check-label" for="modalIsPublished">Published</label>
                  </div>
                </div>

                <div class="col-md-6">
                  <label class="form-label" for="modalNotes">Notes</label>
                  <textarea class="form-control" id="modalNotes"></textarea>
                </div>
                <div class="col-md-6">
                  <label class="form-label" for="modalNavWarning">Navigation Warning</label>
                  <textarea class="form-control" id="modalNavWarning"></textarea>
                </div>
                <div class="col-12">
                  <label class="form-label" for="modalReviewerNotes">Reviewer Notes</label>
                  <textarea class="form-control" id="modalReviewerNotes"></textarea>
                </div>
              </div>
            </form>
          </div>
          <div class="modal-footer">
            <button type="button" class="btn btn-outline-danger me-auto" id="deleteGreatLoopAnchorageBtn">Delete</button>
            <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancel</button>
            <button type="button" class="btn btn-primary" id="saveGreatLoopAnchorageBtn">Save Anchorage</button>
          </div>
        </div>
      </div>
    </div>
  </cfif>

  <script>
    window.FPW_GREAT_LOOP_ANCHORAGES_ADMIN = {
      endpoint: "<cfoutput>#JSStringFormat(request.fpwApiBase)#</cfoutput>/adminGreatLoopAnchorages.cfc?method=handle",
      nonce: "<cfoutput>#JSStringFormat(adminNonce)#</cfoutput>"
    };
  </script>
  <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js" crossorigin="anonymous"></script>
  <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js" integrity="sha256-20nQCchB9co0qIjJZRGuk2/Z9VM+kNiyxNV1lvTlZBo=" crossorigin=""></script>
  <script src="<cfoutput>#encodeForHTMLAttribute(request.fpwBase)#</cfoutput>/assets/js/app/admin/great-loop-anchorages.js?v=20260622-admin-crud"></script>
</body>
</html>
