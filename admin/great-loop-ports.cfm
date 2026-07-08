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
    if (!structKeyExists(session, "greatLoopPortsAdminNonce") OR !len(trim(toString(session.greatLoopPortsAdminNonce)))) {
        session.greatLoopPortsAdminNonce = createUUID();
    }
    adminNonce = session.greatLoopPortsAdminNonce;
}
</cfscript>
<cfinclude template="../includes/fpw_base_path.cfm">

<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Great Loop Ports Admin</title>
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" crossorigin="anonymous">
  <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" crossorigin="">
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
    .summary-line { display: flex; justify-content: space-between; align-items: center; gap: 8px; flex-wrap: wrap; font-size: 14px; color: #444; margin: 8px 0 12px; }
    table { width: 100%; border-collapse: collapse; font-size: 14px; }
    th, td { border: 1px solid #ddd; padding: 8px; text-align: left; vertical-align: top; }
    th { background: #f0f0f0; }
    td.num { text-align: right; white-space: nowrap; font-family: Consolas, Menlo, Monaco, monospace; }
    td.actions { white-space: nowrap; }
    .btn-inline { padding: 4px 8px; border-radius: 4px; border: 1px solid #666; background: #efefef; cursor: pointer; font-size: 12px; }
    .btn-inline.danger { border-color: #b91c1c; background: #fff1f2; color: #991b1b; }
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
    .fpw-admin-port-image-cell { width: 110px; min-width: 110px; }
    .fpw-admin-port-row-thumb,
    .fpw-admin-port-row-thumb-placeholder { width: 72px; height: 48px; border-radius: 6px; border: 1px solid #d8dee8; background: #f8fafc; }
    .fpw-admin-port-row-thumb { display: block; object-fit: cover; }
    .fpw-admin-port-row-thumb.is-hidden { display: none; }
    .fpw-admin-port-row-thumb-placeholder { display: flex; align-items: center; justify-content: center; color: #64748b; font-size: 11px; line-height: 1.1; text-align: center; }
    .fpw-admin-image-status { display: block; margin-top: 4px; color: #64748b; font-size: 11px; line-height: 1.2; }
    .port-map-frame { height: 320px; border: 1px solid #cfd6e3; border-radius: 6px; margin-bottom: 8px; }
    .coord-actions { display: flex; justify-content: flex-end; margin-bottom: 10px; }
    .port-image-preview { display: flex; gap: 14px; align-items: flex-start; flex-wrap: wrap; }
    .port-image-preview img { width: 180px; max-width: 100%; aspect-ratio: 3 / 2; object-fit: cover; border-radius: 6px; border: 1px solid #d8dee8; background: #f8fafc; }
    .port-image-empty { width: 180px; aspect-ratio: 3 / 2; border-radius: 6px; border: 1px dashed #b8c2d1; background: #f8fafc; color: #64748b; display: flex; align-items: center; justify-content: center; font-size: 13px; }
    .fpw-admin-port-image-actions { margin-top: 14px; padding-top: 12px; border-top: 1px solid #e5e7eb; }
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

    <h1>Great Loop Ports</h1>
    <p class="hint">View, search, filter, edit, and save Great Loop port table values, support metadata, service flags, tags, coordinates, and admin images.</p>

    <cfif NOT isAuthorized>
      <div class="msg error">
        <strong>Unauthorized:</strong> Admin login is required.
      </div>
    <cfelse>
      <div id="greatLoopPortsMessage" class="msg"></div>

      <form id="greatLoopPortsFilters" novalidate>
        <div class="toolbar">
          <div class="field">
            <label for="filterSearch">Search</label>
            <input type="text" id="filterSearch" placeholder="name, state, waterway, segment">
          </div>
          <div class="field">
            <label for="filterState">State / Province</label>
            <select id="filterState"><option value="">All</option></select>
          </div>
          <div class="field">
            <label for="filterLoopSegment">Loop Segment</label>
            <select id="filterLoopSegment"><option value="">All</option></select>
          </div>
          <div class="field">
            <label for="filterWaterway">Waterway</label>
            <select id="filterWaterway"><option value="">All</option></select>
          </div>
          <div class="field">
            <label for="filterQualityStatus">Data Quality</label>
            <select id="filterQualityStatus"><option value="">All</option></select>
          </div>
          <div class="field">
            <label for="filterCoordStatus">Coordinates</label>
            <select id="filterCoordStatus">
              <option value="">All</option>
              <option value="has">Has coordinates</option>
              <option value="missing">Missing/zero coordinates</option>
            </select>
          </div>
          <div class="field">
            <label for="filterImageStatus">Image Status</label>
            <select id="filterImageStatus">
              <option value="">All</option>
              <option value="has">Has image</option>
              <option value="missing">Missing image</option>
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
        </div>
        <div class="toolbar-actions">
          <button type="submit" class="primary">Search</button>
          <button type="button" id="resetFiltersBtn">Reset</button>
        </div>
      </form>

      <div class="summary-line">
        <div id="greatLoopPortsSummaryLine">Loading ports...</div>
      </div>

      <div class="table-responsive">
        <table>
          <thead>
            <tr>
              <th style="width:70px;">ID</th>
              <th style="width:230px;">Port Name</th>
              <th style="width:110px;">Image</th>
              <th style="width:150px;">State</th>
              <th style="width:190px;">Waterway</th>
              <th style="width:190px;">Loop Segment</th>
              <th style="width:180px;">Coordinates</th>
              <th style="width:130px;">Quality</th>
              <th style="width:120px;">Flags</th>
              <th style="width:130px;">Updated</th>
              <th style="width:140px;">Actions</th>
            </tr>
          </thead>
          <tbody id="greatLoopPortsTableBody">
            <tr><td colspan="11">Loading...</td></tr>
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
    <div class="modal fade" id="greatLoopPortModal" tabindex="-1" aria-labelledby="greatLoopPortModalLabel" aria-hidden="true" data-bs-backdrop="static" data-bs-keyboard="false">
      <div class="modal-dialog modal-xl modal-dialog-scrollable">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title" id="greatLoopPortModalLabel">Great Loop Port</h5>
            <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
          </div>
          <div class="modal-body">
            <div id="greatLoopPortModalMessage" class="msg"></div>
            <form id="greatLoopPortForm" novalidate>
              <input type="hidden" id="modalPortId" value="0">

              <div class="row row-gap">
                <div class="col-lg-8">
                  <div id="greatLoopPortMap" class="port-map-frame"></div>
                  <div class="small-muted mb-2">Tip: click on map or drag marker to update latitude/longitude.</div>
                  <div class="coord-actions">
                    <button type="button" class="btn btn-outline-secondary btn-sm" id="clearMapPointBtn">Clear Coordinates</button>
                  </div>
                  <div class="row row-gap">
                    <div class="col-md-2">
                      <label class="form-label" for="modalPortIdDisplay">ID</label>
                      <input type="text" class="form-control" id="modalPortIdDisplay" readonly>
                    </div>
                    <div class="col-md-6">
                      <label class="form-label" for="modalPortName">Port Name *</label>
                      <input type="text" class="form-control" id="modalPortName" maxlength="160" required>
                    </div>
                    <div class="col-md-4">
                      <label class="form-label" for="modalSlug">Slug</label>
                      <input type="text" class="form-control" id="modalSlug" readonly>
                    </div>
                    <div class="col-md-4">
                      <label class="form-label" for="modalState">State / Province</label>
                      <input type="text" class="form-control" id="modalState" maxlength="80">
                    </div>
                    <div class="col-md-2">
                      <label class="form-label" for="modalStateCode">State Code</label>
                      <input type="text" class="form-control" id="modalStateCode" maxlength="10">
                    </div>
                    <div class="col-md-3">
                      <label class="form-label" for="modalCountry">Country</label>
                      <input type="text" class="form-control" id="modalCountry" maxlength="80">
                    </div>
                    <div class="col-md-3">
                      <label class="form-label" for="modalRegion">Region</label>
                      <input type="text" class="form-control" id="modalRegion" maxlength="80">
                    </div>
                    <div class="col-md-6">
                      <label class="form-label" for="modalWaterway">Waterway</label>
                      <input type="text" class="form-control" id="modalWaterway" maxlength="160">
                    </div>
                    <div class="col-md-6">
                      <label class="form-label" for="modalLoopSegment">Loop Segment</label>
                      <input type="text" class="form-control" id="modalLoopSegment" maxlength="160">
                    </div>
                    <div class="col-md-3">
                      <label class="form-label" for="modalLatitude">Latitude</label>
                      <input type="text" class="form-control" id="modalLatitude">
                    </div>
                    <div class="col-md-3">
                      <label class="form-label" for="modalLongitude">Longitude</label>
                      <input type="text" class="form-control" id="modalLongitude">
                    </div>
                    <div class="col-md-3">
                      <label class="form-label" for="modalMileMarker">Mile Marker</label>
                      <input type="text" class="form-control" id="modalMileMarker" maxlength="80">
                    </div>
                    <div class="col-md-3">
                      <label class="form-label" for="modalPortType">Port Type</label>
                      <input type="text" class="form-control" id="modalPortType" maxlength="80">
                    </div>
                    <div class="col-md-4">
                      <label class="form-label" for="modalDataQualityStatus">Data Quality</label>
                      <select class="form-select" id="modalDataQualityStatus">
                        <option value="needs_review">Needs review</option>
                        <option value="verified">Verified</option>
                        <option value="derived_unverified">Derived unverified</option>
                        <option value="bad_coordinates">Bad coordinates</option>
                        <option value="missing_coordinates">Missing coordinates</option>
                        <option value="duplicate_name_review">Duplicate name review</option>
                      </select>
                    </div>
                    <div class="col-md-4">
                      <label class="form-label" for="modalSourceUrl">Source URL</label>
                      <input type="url" class="form-control" id="modalSourceUrl" maxlength="500">
                    </div>
                    <div class="col-md-4">
                      <label class="form-label" for="modalLastReviewedAt">Last Reviewed</label>
                      <input type="datetime-local" class="form-control" id="modalLastReviewedAt">
                    </div>
                    <div class="col-md-6 d-flex align-items-end">
                      <div class="form-check mb-2 me-4">
                        <input class="form-check-input" type="checkbox" id="modalIsMajorPort">
                        <label class="form-check-label" for="modalIsMajorPort">Major Port</label>
                      </div>
                      <div class="form-check mb-2">
                        <input class="form-check-input" type="checkbox" id="modalIsHiddenGem">
                        <label class="form-check-label" for="modalIsHiddenGem">Hidden Gem</label>
                      </div>
                    </div>
                  </div>
                </div>

                <div class="col-lg-4">
                  <label class="form-label">Port Image</label>
                  <div class="port-image-preview" id="modalImagePreview">
                    <div class="port-image-empty">No image</div>
                  </div>
                  <div class="mt-3">
                    <label class="form-label" for="modalImageFile">Upload / Replace Image</label>
                    <input type="file" class="form-control" id="modalImageFile" accept=".jpg,.jpeg,.png,.webp,image/jpeg,image/png,image/webp">
                    <div class="form-text">JPG, PNG, or WEBP. Maximum 8 MB. Saved as the current slug filename and thumbnail.</div>
                  </div>
                  <div class="fpw-admin-port-image-actions" id="modalImageActions" hidden>
                    <button type="button" class="btn btn-outline-danger btn-sm" id="deletePortImageBtn">Delete Image</button>
                    <div class="form-text">Removes the source image and thumbnail. Admin pages show no image until a new image is uploaded.</div>
                  </div>
                </div>
              </div>

              <div class="row row-gap mt-3">
                <div class="col-md-6">
                  <label class="form-label" for="modalShortDescription">Short Description</label>
                  <textarea class="form-control" id="modalShortDescription"></textarea>
                </div>
                <div class="col-md-6">
                  <label class="form-label" for="modalServicesSummary">Services Summary</label>
                  <textarea class="form-control" id="modalServicesSummary"></textarea>
                </div>
                <div class="col-md-6">
                  <label class="form-label" for="modalApproachNotes">Approach Notes</label>
                  <textarea class="form-control" id="modalApproachNotes"></textarea>
                </div>
                <div class="col-md-6">
                  <label class="form-label" for="modalSourceNotes">Source Notes</label>
                  <textarea class="form-control" id="modalSourceNotes"></textarea>
                </div>
                <div class="col-md-12">
                  <label class="form-label" for="modalTagsText">Tags</label>
                  <textarea class="form-control" id="modalTagsText" placeholder="One tag per line or comma separated"></textarea>
                </div>
              </div>

              <h6 class="mt-4 mb-2">Services</h6>
              <div class="row row-gap" id="portServicesFields">
                <div class="col-md-3"><label class="form-label" for="modalFuelAvailable">Fuel</label><select class="form-select" id="modalFuelAvailable" data-service-field="fuel_available"></select></div>
                <div class="col-md-3"><label class="form-label" for="modalDieselAvailable">Diesel</label><select class="form-select" id="modalDieselAvailable" data-service-field="diesel_available"></select></div>
                <div class="col-md-3"><label class="form-label" for="modalGasAvailable">Gas</label><select class="form-select" id="modalGasAvailable" data-service-field="gas_available"></select></div>
                <div class="col-md-3"><label class="form-label" for="modalPumpoutAvailable">Pumpout</label><select class="form-select" id="modalPumpoutAvailable" data-service-field="pumpout_available"></select></div>
                <div class="col-md-3"><label class="form-label" for="modalTransientDockageAvailable">Transient Dockage</label><select class="form-select" id="modalTransientDockageAvailable" data-service-field="transient_dockage_available"></select></div>
                <div class="col-md-3"><label class="form-label" for="modalAnchorageAvailable">Anchorage</label><select class="form-select" id="modalAnchorageAvailable" data-service-field="anchorage_available"></select></div>
                <div class="col-md-3"><label class="form-label" for="modalMooringAvailable">Mooring</label><select class="form-select" id="modalMooringAvailable" data-service-field="mooring_available"></select></div>
                <div class="col-md-3"><label class="form-label" for="modalProvisioningAvailable">Provisioning</label><select class="form-select" id="modalProvisioningAvailable" data-service-field="provisioning_available"></select></div>
                <div class="col-md-3"><label class="form-label" for="modalRestaurantsNearby">Restaurants</label><select class="form-select" id="modalRestaurantsNearby" data-service-field="restaurants_nearby"></select></div>
                <div class="col-md-3"><label class="form-label" for="modalMarineSupplyNearby">Marine Supply</label><select class="form-select" id="modalMarineSupplyNearby" data-service-field="marine_supply_nearby"></select></div>
                <div class="col-md-3"><label class="form-label" for="modalLaundryNearby">Laundry</label><select class="form-select" id="modalLaundryNearby" data-service-field="laundry_nearby"></select></div>
                <div class="col-md-3"><label class="form-label" for="modalTransportationNearby">Transportation</label><select class="form-select" id="modalTransportationNearby" data-service-field="transportation_nearby"></select></div>
              </div>
            </form>
          </div>
          <div class="modal-footer">
            <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancel</button>
            <button type="button" class="btn btn-primary" id="saveGreatLoopPortBtn">Save Port</button>
          </div>
        </div>
      </div>
    </div>
  </cfif>

  <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js" crossorigin="anonymous"></script>
  <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js" crossorigin=""></script>
  <script src="<cfoutput>#encodeForHTMLAttribute(request.fpwBase)#</cfoutput>/assets/js/maps/leaflet-noaa-waypoint-map.js?v=20260225a"></script>
  <cfoutput>
    <script>
      window.FPW_BASE = "#JSStringFormat(request.fpwBase)#";
      window.FPW_API_BASE = "#JSStringFormat(request.fpwApiBase)#";
      window.FPW_GREAT_LOOP_PORTS_ADMIN = {
        endpoint: "#JSStringFormat(request.fpwApiBase)#/adminGreatLoopPorts.cfc?method=handle",
        nonce: "#JSStringFormat(adminNonce)#"
      };
    </script>
  </cfoutput>
  <cfif isAuthorized>
    <script src="<cfoutput>#encodeForHTMLAttribute(request.fpwBase)#</cfoutput>/assets/js/app/admin/great-loop-ports.js?v=20260707-admin"></script>
  </cfif>
</body>
</html>


