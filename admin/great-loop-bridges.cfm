<cfsetting showdebugoutput="false" requesttimeout="30">
<cfcontent type="text/html; charset=utf-8">
<cfinclude template="../includes/fpw_base_path.cfm">

<cfscript>
userStruct = (structKeyExists(session, "user") AND isStruct(session.user)) ? session.user : {};
isLoggedIn = structCount(userStruct) GT 0;
adminWhitelist = "admin@floatplanwizard.com,lswald@yahoo.com";
isAdmin = false;
isAuthorized = false;

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

function urlValue(required string keyName) {
  return structKeyExists(url, arguments.keyName) ? trim(toString(url[arguments.keyName])) : "";
}

function selectedAttr(any leftValue, any rightValue) {
  return compareNoCase(trim(toString(arguments.leftValue)), trim(toString(arguments.rightValue))) EQ 0 ? " selected" : "";
}

function checkedAttr(any value) {
  return boolLike(arguments.value, false) ? " checked" : "";
}

function displayText(any value, string fallback="") {
  var txt = isNull(arguments.value) ? "" : trim(toString(arguments.value));
  return len(txt) ? txt : arguments.fallback;
}

function statusLabel(any value) {
  var txt = trim(toString(arguments.value));
  if (txt EQ "published") return "Published";
  if (txt EQ "planning_only") return "Planning only";
  if (txt EQ "admin_review") return "Admin review";
  if (txt EQ "do_not_publish") return "Do not publish";
  return len(txt) ? txt : "Unknown";
}

function pageUrl(required numeric offsetValue) {
  var params = duplicate(url);
  params.offset = max(0, val(arguments.offsetValue));
  return request.fpwBase & "/admin/great-loop-bridges.cfm?" & structToQueryString(params);
}

function structToQueryString(required struct values) {
  var parts = [];
  var keys = structKeyArray(arguments.values);
  var i = 0;
  var keyName = "";
  arraySort(keys, "textnocase");
  for (i = 1; i LTE arrayLen(keys); i++) {
    keyName = keys[i];
    if (len(trim(toString(arguments.values[keyName])))) {
      arrayAppend(parts, urlEncodedFormat(keyName) & "=" & urlEncodedFormat(toString(arguments.values[keyName])));
    }
  }
  return arrayToList(parts, "&");
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

filters = {
  "q" = urlValue("q"),
  "routeSegment" = urlValue("routeSegment"),
  "routeVariant" = urlValue("routeVariant"),
  "waterway" = urlValue("waterway"),
  "stateProvince" = urlValue("stateProvince"),
  "bridgeType" = urlValue("bridgeType"),
  "verificationStatus" = urlValue("verificationStatus"),
  "publicStatus" = urlValue("publicStatus"),
  "drawbridgeOnly" = urlValue("drawbridgeOnly"),
  "airDraftConcern" = urlValue("airDraftConcern"),
  "hasContact" = urlValue("hasContact"),
  "hasCoordinates" = urlValue("hasCoordinates"),
  "missingCoordinates" = urlValue("missingCoordinates"),
  "missingDrawbridgeContact" = urlValue("missingDrawbridgeContact"),
  "imageStatus" = urlValue("imageStatus"),
  "missingImage" = urlValue("missingImage"),
  "doNotPublish" = urlValue("doNotPublish"),
  "limit" = len(urlValue("limit")) ? urlValue("limit") : "50",
  "offset" = len(urlValue("offset")) ? urlValue("offset") : "0"
};
if (!len(filters.imageStatus) AND len(filters.missingImage)) {
  filters.imageStatus = "no_image";
}

bridgeRows = [];
stats = {};
facets = {};
searchResult = { "SUCCESS" = false, "MESSAGE" = "", "ROWS" = [], "TOTAL" = 0, "LIMIT" = val(filters.limit), "OFFSET" = val(filters.offset) };

if (isAuthorized) {
  try {
    try {
      bridgeSvc = createObject("component", "api.v1.GreatLoopBridgesService").init();
    } catch (any svcPathError) {
      bridgeSvc = createObject("component", "fpw.api.v1.GreatLoopBridgesService").init();
    }
    stats = bridgeSvc.getStats();
    facets = bridgeSvc.getAdminFacets();
    searchResult = bridgeSvc.searchAdminBridges(filters);
    bridgeRows = searchResult.ROWS;
  } catch (any eService) {
    searchResult = { "SUCCESS" = false, "MESSAGE" = "Bridge admin data could not be loaded.", "ROWS" = [], "TOTAL" = 0, "LIMIT" = val(filters.limit), "OFFSET" = val(filters.offset) };
  }
}
</cfscript>

<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Great Loop Bridges Admin</title>
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" crossorigin="anonymous">
  <style>
    body { font-family: Arial, sans-serif; margin: 24px; background: #f7f7f7; color: #111; }
    .wrap { max-width: 1480px; margin: 0 auto; background: #fff; border: 1px solid #ddd; border-radius: 8px; padding: 20px; }
    h1 { margin-top: 0; font-size: 24px; }
    .hint { color: #444; margin-bottom: 16px; }
    .summary-grid { display: grid; gap: 10px; grid-template-columns: repeat(4, minmax(0, 1fr)); margin-bottom: 14px; }
    .summary-card { border: 1px solid #d8dee8; background: #f8fafc; border-radius: 6px; padding: 10px; }
    .summary-card strong { display: block; font-size: 22px; }
    .summary-card span { color: #526070; font-size: 13px; }
    .toolbar { display: grid; gap: 10px; grid-template-columns: repeat(4, minmax(0, 1fr)); margin-bottom: 12px; }
    .toolbar .field { display: flex; flex-direction: column; gap: 6px; }
    .toolbar label { font-weight: 700; font-size: 13px; color: #333; }
    .toolbar input, .toolbar select { border: 1px solid #bbb; border-radius: 4px; font-size: 14px; padding: 8px; }
    .check-row { display: flex; gap: 14px; flex-wrap: wrap; margin: 8px 0 14px; }
    .check-row label { font-size: 14px; color: #333; }
    .actions { display: flex; gap: 8px; flex-wrap: wrap; margin-bottom: 14px; }
    table { width: 100%; border-collapse: collapse; font-size: 13px; }
    th, td { border: 1px solid #ddd; padding: 8px; text-align: left; vertical-align: top; }
    th { background: #f0f0f0; }
    td.num { text-align: right; white-space: nowrap; font-family: Consolas, Menlo, Monaco, monospace; }
    .badge-soft { display: inline-block; border: 1px solid #c8d0db; border-radius: 999px; padding: 2px 8px; background: #f8fafc; font-size: 12px; }
    .badge-soft.ok { background: #e9f8ee; border-color: #9dd9ad; color: #0e5522; }
    .badge-soft.warn { background: #fff7ed; border-color: #fed7aa; color: #9a3412; }
    .badge-soft.danger { background: #ffecec; border-color: #ffb4b4; color: #7f1d1d; }
    .bridge-image-cell { width: 96px; }
    .bridge-admin-thumb { display: block; width: 72px; height: 48px; object-fit: cover; border: 1px solid #c8d0db; border-radius: 6px; background: #eef2f7; }
    .bridge-image-status { display: block; margin-top: 5px; color: #526070; font-size: 12px; white-space: nowrap; }
    .msg { margin-bottom: 12px; padding: 10px; border-radius: 4px; }
    .msg.error { background: #ffecec; border: 1px solid #ffb4b4; color: #7f1d1d; }
    .pager { display: flex; justify-content: flex-end; align-items: center; gap: 8px; margin-top: 10px; }
    @media (max-width: 1100px) { .toolbar, .summary-grid { grid-template-columns: repeat(2, minmax(0, 1fr)); } }
    @media (max-width: 700px) { body { margin: 12px; } .wrap { padding: 14px; } .toolbar, .summary-grid { grid-template-columns: 1fr; } }
  </style>
</head>
<body>
  <div class="wrap">
    <cfinclude template="includes/admin_reports_nav.cfm">

    <h1>Great Loop Bridges</h1>
    <p class="hint">Search, filter, review, and edit Great Loop bridge planning records. Public pages never show rows marked do not publish.</p>

    <cfif NOT isAuthorized>
      <div class="msg error"><strong>Unauthorized:</strong> Admin login is required.</div>
    <cfelse>
      <cfif NOT searchResult.SUCCESS AND len(searchResult.MESSAGE)>
        <div class="msg error"><cfoutput>#encodeForHTML(searchResult.MESSAGE)#</cfoutput></div>
      </cfif>

      <div class="actions">
        <a class="btn btn-dark" href="<cfoutput>#request.fpwBase#</cfoutput>/admin/great-loop-bridge-import.cfm">Import Bridge CSV</a>
      </div>

      <div class="summary-grid">
        <div class="summary-card"><strong><cfoutput>#numberFormat(stats.TOTAL_ROWS)#</cfoutput></strong><span>Total rows</span></div>
        <div class="summary-card"><strong><cfoutput>#numberFormat(stats.PUBLISHED_ROWS)#</cfoutput></strong><span>Published</span></div>
        <div class="summary-card"><strong><cfoutput>#numberFormat(stats.PLANNING_ONLY_ROWS)#</cfoutput></strong><span>Planning only</span></div>
        <div class="summary-card"><strong><cfoutput>#numberFormat(stats.DO_NOT_PUBLISH_ROWS)#</cfoutput></strong><span>Do not publish</span></div>
        <div class="summary-card"><strong><cfoutput>#numberFormat(stats.MISSING_COORDINATES_ROWS)#</cfoutput></strong><span>Missing coordinates</span></div>
        <div class="summary-card"><strong><cfoutput>#numberFormat(stats.DRAWBRIDGE_MISSING_CONTACT_ROWS)#</cfoutput></strong><span>Drawbridges missing contact</span></div>
        <div class="summary-card"><strong><cfoutput>#numberFormat(stats.APPROVED_IMAGE_ROWS)#</cfoutput></strong><span>Approved local images</span></div>
        <div class="summary-card"><strong><cfoutput>#numberFormat(searchResult.TOTAL)#</cfoutput></strong><span>Filtered rows</span></div>
      </div>

      <form method="get" action="<cfoutput>#request.fpwBase#</cfoutput>/admin/great-loop-bridges.cfm">
        <div class="toolbar">
          <div class="field"><label for="q">Search</label><input type="text" id="q" name="q" value="<cfoutput>#encodeForHTMLAttribute(filters.q)#</cfoutput>"></div>
          <div class="field">
            <label for="routeSegment">Route Segment</label>
            <select id="routeSegment" name="routeSegment"><option value="">All</option><cfloop array="#facets.routeSegments#" index="opt"><cfoutput><option value="#encodeForHTMLAttribute(opt.value)#"#selectedAttr(filters.routeSegment, opt.value)#>#encodeForHTML(opt.label)#</option></cfoutput></cfloop></select>
          </div>
          <div class="field">
            <label for="waterway">Waterway</label>
            <select id="waterway" name="waterway"><option value="">All</option><cfloop array="#facets.waterways#" index="opt"><cfoutput><option value="#encodeForHTMLAttribute(opt.value)#"#selectedAttr(filters.waterway, opt.value)#>#encodeForHTML(opt.label)#</option></cfoutput></cfloop></select>
          </div>
          <div class="field">
            <label for="stateProvince">State / Province</label>
            <select id="stateProvince" name="stateProvince"><option value="">All</option><cfloop array="#facets.states#" index="opt"><cfoutput><option value="#encodeForHTMLAttribute(opt.value)#"#selectedAttr(filters.stateProvince, opt.value)#>#encodeForHTML(opt.label)#</option></cfoutput></cfloop></select>
          </div>
          <div class="field">
            <label for="bridgeType">Bridge Type</label>
            <select id="bridgeType" name="bridgeType"><option value="">All</option><cfloop array="#facets.bridgeTypes#" index="opt"><cfoutput><option value="#encodeForHTMLAttribute(opt.value)#"#selectedAttr(filters.bridgeType, opt.value)#>#encodeForHTML(opt.label)#</option></cfoutput></cfloop></select>
          </div>
          <div class="field">
            <label for="publicStatus">Public Status</label>
            <select id="publicStatus" name="publicStatus"><option value="">All</option><cfloop array="#facets.publicStatuses#" index="opt"><cfoutput><option value="#encodeForHTMLAttribute(opt.value)#"#selectedAttr(filters.publicStatus, opt.value)#>#encodeForHTML(opt.label)#</option></cfoutput></cfloop></select>
          </div>
          <div class="field">
            <label for="verificationStatus">Verification Status</label>
            <select id="verificationStatus" name="verificationStatus"><option value="">All</option><cfloop array="#facets.verificationStatuses#" index="opt"><cfoutput><option value="#encodeForHTMLAttribute(opt.value)#"#selectedAttr(filters.verificationStatus, opt.value)#>#encodeForHTML(opt.label)#</option></cfoutput></cfloop></select>
          </div>
          <div class="field">
            <label for="imageStatus">Image</label>
            <select id="imageStatus" name="imageStatus">
              <option value=""<cfoutput>#selectedAttr(filters.imageStatus, "")#</cfoutput>>All</option>
              <option value="has_image"<cfoutput>#selectedAttr(filters.imageStatus, "has_image")#</cfoutput>>Has image</option>
              <option value="no_image"<cfoutput>#selectedAttr(filters.imageStatus, "no_image")#</cfoutput>>No image</option>
            </select>
          </div>
          <div class="field">
            <label for="limit">Rows Per Page</label>
            <select id="limit" name="limit"><option value="50"#selectedAttr(filters.limit, 50)#>50</option><option value="100"#selectedAttr(filters.limit, 100)#>100</option><option value="200"#selectedAttr(filters.limit, 200)#>200</option></select>
          </div>
        </div>
        <div class="check-row">
          <label><input type="checkbox" name="drawbridgeOnly" value="1"<cfoutput>#checkedAttr(filters.drawbridgeOnly)#</cfoutput>> Drawbridge only</label>
          <label><input type="checkbox" name="airDraftConcern" value="1"<cfoutput>#checkedAttr(filters.airDraftConcern)#</cfoutput>> Air-draft concern</label>
          <label><input type="checkbox" name="hasContact" value="1"<cfoutput>#checkedAttr(filters.hasContact)#</cfoutput>> Has VHF/phone</label>
          <label><input type="checkbox" name="hasCoordinates" value="1"<cfoutput>#checkedAttr(filters.hasCoordinates)#</cfoutput>> Has coordinates</label>
          <label><input type="checkbox" name="missingCoordinates" value="1"<cfoutput>#checkedAttr(filters.missingCoordinates)#</cfoutput>> Missing coordinates</label>
          <label><input type="checkbox" name="missingDrawbridgeContact" value="1"<cfoutput>#checkedAttr(filters.missingDrawbridgeContact)#</cfoutput>> Drawbridge missing contact</label>
          <label><input type="checkbox" name="doNotPublish" value="1"<cfoutput>#checkedAttr(filters.doNotPublish)#</cfoutput>> Do not publish</label>
        </div>
        <div class="actions">
          <button type="submit" class="btn btn-dark">Apply Filters</button>
          <a class="btn btn-outline-secondary" href="<cfoutput>#request.fpwBase#</cfoutput>/admin/great-loop-bridges.cfm">Clear Filters</a>
        </div>
      </form>

      <div class="table-responsive">
        <table>
          <thead>
            <tr>
              <th>ID</th>
              <th>Image</th>
              <th>Bridge</th>
              <th>Route / Waterway</th>
              <th>Location</th>
              <th>Type</th>
              <th>Closed Clearance</th>
              <th>Contact</th>
              <th>Status</th>
              <th>Data Flags</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            <cfif NOT arrayLen(bridgeRows)>
              <tr><td colspan="11">No bridge rows match the current filters.</td></tr>
            <cfelse>
              <cfloop array="#bridgeRows#" index="bridgeItem">
                <cfset bridgeImage = bridgeSvc.getBridgeImageAsset(bridgeItem, request.fpwBase)>
                <cfset bridgeImageAlt = displayText(bridgeItem.bridge_name, "Bridge") & " image thumbnail">
                <tr>
                  <td class="num"><cfoutput>#encodeForHTML(bridgeItem.id)#</cfoutput></td>
                  <td class="bridge-image-cell">
                    <cfif bridgeImage.hasImage>
                      <img class="bridge-admin-thumb" src="<cfoutput>#encodeForHTMLAttribute(bridgeImage.thumbnailUrl)#</cfoutput>" alt="<cfoutput>#encodeForHTMLAttribute(bridgeImageAlt)#</cfoutput>" loading="lazy" decoding="async">
                      <span class="bridge-image-status"><cfif bridgeImage.hasThumbnail>Has image<cfelse>Source image</cfif></span>
                    <cfelseif val(bridgeItem.image_allowed_for_fpw) EQ 1 AND len(trim(toString(bridgeItem.local_image_path)))>
                      <span class="badge-soft warn">Missing file</span>
                    <cfelse>
                      <span class="badge-soft">No image</span>
                    </cfif>
                  </td>
                  <td><strong><cfoutput>#encodeForHTML(bridgeItem.bridge_name)#</cfoutput></strong><br><small><cfoutput>#encodeForHTML(bridgeItem.slug)#</cfoutput></small></td>
                  <td><cfoutput>#encodeForHTML(displayText(bridgeItem.route_segment, "Route not set"))#<br>#encodeForHTML(displayText(bridgeItem.waterway, "Waterway not set"))#</cfoutput></td>
                  <td><cfoutput>#encodeForHTML(displayText(bridgeItem.nearest_city, "City not set"))#<cfif len(bridgeItem.state_province)>, #encodeForHTML(bridgeItem.state_province)#</cfif><cfif len(bridgeItem.mile_marker)><br>MM #encodeForHTML(bridgeItem.mile_marker)#</cfif></cfoutput></td>
                  <td><cfoutput>#encodeForHTML(displayText(bridgeItem.bridge_type, "Type not set"))#</cfoutput><br><cfif val(bridgeItem.is_drawbridge) EQ 1><span class="badge-soft warn">Drawbridge</span></cfif></td>
                  <td><cfoutput>#encodeForHTML(displayText(bridgeItem.vertical_clearance_closed_ft, "Not verified"))#</cfoutput></td>
                  <td><cfoutput>VHF: #encodeForHTML(displayText(bridgeItem.vhf_channel, "Not verified"))#<br>Phone: #encodeForHTML(displayText(bridgeItem.phone, "Not verified"))#</cfoutput></td>
                  <td>
                    <span class="badge-soft<cfif bridgeItem.public_status EQ 'published'> ok<cfelseif bridgeItem.public_status EQ 'do_not_publish'> danger<cfelseif bridgeItem.public_status EQ 'planning_only'> warn</cfif>"><cfoutput>#encodeForHTML(statusLabel(bridgeItem.public_status))#</cfoutput></span><br>
                    <small><cfoutput>#encodeForHTML(displayText(bridgeItem.verification_status, "Verification not set"))#</cfoutput></small>
                  </td>
                  <td>
                    <cfif isNumeric(bridgeItem.latitude) AND isNumeric(bridgeItem.longitude)><span class="badge-soft ok">Coords</span><cfelse><span class="badge-soft warn">No coords</span></cfif>
                    <cfif val(bridgeItem.image_allowed_for_fpw) EQ 1 AND len(trim(toString(bridgeItem.local_image_path)))><span class="badge-soft ok">Image approved</span><cfelse><span class="badge-soft">No image</span></cfif>
                  </td>
                  <td><a class="btn btn-sm btn-outline-dark" href="<cfoutput>#request.fpwBase#/admin/great-loop-bridge-edit.cfm?id=#encodeForURL(bridgeItem.id)#</cfoutput>">Edit</a></td>
                </tr>
              </cfloop>
            </cfif>
          </tbody>
        </table>
      </div>

      <cfset prevOffset = max(0, val(searchResult.OFFSET) - val(searchResult.LIMIT))>
      <cfset nextOffset = val(searchResult.OFFSET) + val(searchResult.LIMIT)>
      <div class="pager">
        <span><cfoutput>Rows #numberFormat(val(searchResult.OFFSET) + 1)#-#numberFormat(min(val(searchResult.OFFSET) + arrayLen(bridgeRows), val(searchResult.TOTAL)))# of #numberFormat(searchResult.TOTAL)#</cfoutput></span>
        <a class="btn btn-outline-secondary btn-sm<cfif val(searchResult.OFFSET) LTE 0> disabled</cfif>" href="<cfoutput>#encodeForHTMLAttribute(pageUrl(prevOffset))#</cfoutput>">Previous</a>
        <a class="btn btn-outline-secondary btn-sm<cfif nextOffset GTE val(searchResult.TOTAL)> disabled</cfif>" href="<cfoutput>#encodeForHTMLAttribute(pageUrl(nextOffset))#</cfoutput>">Next</a>
      </div>
    </cfif>
  </div>
</body>
</html>
