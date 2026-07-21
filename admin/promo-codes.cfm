<cfsetting showdebugoutput="false">
<cfcontent type="text/html; charset=utf-8">
<cfscript>
userStruct = (structKeyExists(session, "user") AND isStruct(session.user)) ? session.user : {};
isLoggedIn = structCount(userStruct) GT 0;
isAdmin = false;
// Authorization is enforced centrally by Application.cfc.

function boolLike(any value, boolean defaultValue=false) {
  var txt = lCase(trim(toString(arguments.value)));
  if (!len(txt)) return arguments.defaultValue;
  if (listFindNoCase("1,true,yes,y,on", txt)) return true;
  if (listFindNoCase("0,false,no,n,off", txt)) return false;
  if (isNumeric(txt)) return val(txt) NEQ 0;
  return arguments.defaultValue;
}

isAuthorized = structKeyExists(request, "fpwAdminAuthorization") AND request.fpwAdminAuthorization.authorized;
if (isAuthorized AND !structKeyExists(session, "adminPromoCodesNonce")) session.adminPromoCodesNonce = createUUID();
</cfscript>
<cfinclude template="../includes/fpw_base_path.cfm">
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Admin Promo Codes</title>
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" crossorigin="anonymous">
  <style>
    body { margin: 24px; background: #f7f7f7; color: #111; font-family: Arial, sans-serif; }
    .admin-wrap { max-width: 1560px; margin: 0 auto; padding: 20px; border: 1px solid #ddd; border-radius: 8px; background: #fff; }
    .filter-grid { display: grid; grid-template-columns: minmax(220px, 2fr) repeat(5, minmax(130px, 1fr)); gap: 10px; }
    .filter-grid label { display: block; margin-bottom: 4px; color: #333; font-size: 12px; font-weight: 700; }
    .toolbar-actions, .pager { display: flex; flex-wrap: wrap; align-items: center; gap: 8px; }
    .toolbar-actions { margin: 12px 0; }
    .pager { justify-content: flex-end; margin-top: 12px; }
    .admin-message { display: none; margin: 12px 0; padding: 10px; border-radius: 5px; }
    .admin-message.info, .admin-message.success, .admin-message.error { display: block; }
    .admin-message.info { background: #edf2ff; border: 1px solid #b6c6ff; color: #13255a; }
    .admin-message.success { background: #e9f8ee; border: 1px solid #9dd9ad; color: #0e5522; }
    .admin-message.error { background: #ffecec; border: 1px solid #ffb4b4; color: #7f1d1d; }
    .table th { white-space: nowrap; cursor: pointer; }
    .table td { vertical-align: top; }
    .code-value { font-family: Consolas, Menlo, monospace; font-size: 12px; }
    .legacy-code { color: #6c757d; }
    .status-badge { text-transform: capitalize; }
    .detail-panel { max-height: 260px; overflow: auto; border: 1px solid #ddd; border-radius: 5px; }
    @media (max-width: 1100px) { .filter-grid { grid-template-columns: repeat(2, minmax(0, 1fr)); } }
    @media (max-width: 640px) { body { margin: 10px; } .admin-wrap { padding: 12px; } .filter-grid { grid-template-columns: 1fr; } }
  </style>
</head>
<body>
  <div class="admin-wrap">
    <cfinclude template="includes/admin_reports_nav.cfm">
    <div class="d-flex justify-content-between align-items-start flex-wrap gap-2">
      <div>
        <h1 class="h3 mb-1">Promo Codes</h1>
        <p class="text-muted">Manage current public promo types and internal admin-grant promotions. Stripe IDs are references only.</p>
      </div>
      <cfif isAuthorized><button type="button" id="newPromoBtn" class="btn btn-primary">New Promo Code</button></cfif>
    </div>

    <cfif NOT isAuthorized>
      <div class="alert alert-danger"><strong>Unauthorized:</strong> Admin login is required.</div>
    <cfelse>
      <div id="promoMessage" class="admin-message" role="status"></div>
      <ul class="nav nav-tabs mb-3" role="tablist">
        <li class="nav-item"><button class="nav-link active" data-bs-toggle="tab" data-bs-target="#promoListPane" type="button">Promotions</button></li>
        <li class="nav-item"><button class="nav-link" data-bs-toggle="tab" data-bs-target="#redemptionPane" type="button" id="redemptionTabBtn">Redemption History</button></li>
      </ul>
      <div class="tab-content">
        <section class="tab-pane fade show active" id="promoListPane">
          <form id="promoFilters" novalidate>
            <div class="filter-grid">
              <div><label for="promoSearch">Search</label><input class="form-control" id="promoSearch" placeholder="code, name, description, Stripe ID"></div>
              <div><label for="promoLifecycle">Status / Kind</label><select class="form-select" id="promoLifecycle"><option value="">All</option><option>active</option><option>inactive</option><option>scheduled</option><option>expired</option><option>archived</option><option>lifetime</option><option>trial</option><option>complimentary</option><option>stripe</option><option>internal</option></select></div>
              <div><label for="promoTypeFilter">Promotion Type</label><select class="form-select" id="promoTypeFilter"><option value="">All</option><option value="founder_lifetime">Founder lifetime</option><option value="stripe_free_months">Stripe free months</option><option value="admin_grant">Internal admin grant</option></select></div>
              <div><label for="promoSort">Sort</label><select class="form-select" id="promoSort"><option value="updated">Updated</option><option value="code">Code</option><option value="name">Name</option><option value="type">Type</option><option value="status">Status</option><option value="starts">Starts</option><option value="expires">Expires</option><option value="redemptions">Redemptions</option><option value="created">Created</option></select></div>
              <div><label for="promoDirection">Direction</label><select class="form-select" id="promoDirection"><option value="desc">Descending</option><option value="asc">Ascending</option></select></div>
              <div><label for="promoLimit">Page Size</label><select class="form-select" id="promoLimit"><option>25</option><option selected>50</option><option>100</option><option>200</option></select></div>
            </div>
            <div class="toolbar-actions"><button class="btn btn-dark" type="submit">Search</button><button class="btn btn-outline-secondary" id="resetPromoFilters" type="button">Reset</button></div>
          </form>
          <div id="promoSummary" class="small text-muted mb-2">Loading promotions...</div>
          <div class="table-responsive"><table class="table table-sm table-bordered align-middle"><thead class="table-light"><tr><th>Code</th><th>Name</th><th>Type</th><th>Status</th><th>Grant</th><th>Redemptions</th><th>Window (UTC)</th><th>Stripe references</th><th>Actions</th></tr></thead><tbody id="promoTableBody"><tr><td colspan="9">Loading...</td></tr></tbody></table></div>
          <div class="pager"><button class="btn btn-sm btn-outline-secondary" id="promoPrev" type="button">Previous</button><span id="promoPage">Page 1</span><button class="btn btn-sm btn-outline-secondary" id="promoNext" type="button">Next</button></div>
        </section>
        <section class="tab-pane fade" id="redemptionPane">
          <div class="filter-grid mb-3"><div><label for="redemptionSearch">Search history</label><input class="form-control" id="redemptionSearch" placeholder="promo, member, email, checkout"></div><div><label for="redemptionResult">Result</label><select class="form-select" id="redemptionResult"><option value="">All</option><option value="redeemed">Redeemed</option><option value="rejected">Rejected</option><option value="checkout_created">Checkout created</option></select></div><div class="d-flex align-items-end"><button class="btn btn-dark" id="redemptionSearchBtn" type="button">Search</button></div></div>
          <div id="redemptionSummary" class="small text-muted mb-2"></div>
          <div class="table-responsive"><table class="table table-sm table-bordered"><thead class="table-light"><tr><th>Promo</th><th>Member</th><th>Result</th><th>Entitlement</th><th>Stripe checkout</th><th>Attempted / Redeemed (UTC)</th></tr></thead><tbody id="redemptionTableBody"><tr><td colspan="6">Select this tab to load history.</td></tr></tbody></table></div>
          <div class="pager"><button class="btn btn-sm btn-outline-secondary" id="redemptionPrev" type="button">Previous</button><span id="redemptionPage">Page 1</span><button class="btn btn-sm btn-outline-secondary" id="redemptionNext" type="button">Next</button></div>
        </section>
      </div>
    </cfif>
  </div>

  <cfif isAuthorized>
    <div class="modal fade" id="promoModal" tabindex="-1" aria-hidden="true" data-bs-backdrop="static">
      <div class="modal-dialog modal-xl modal-dialog-scrollable"><div class="modal-content">
        <form id="promoForm" novalidate>
          <div class="modal-header"><h2 class="modal-title h5" id="promoModalTitle">Promo Code</h2><button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button></div>
          <div class="modal-body">
            <input type="hidden" id="promoCodeId" value="0">
            <div class="alert alert-info py-2">Legacy promo plaintext cannot be recovered. Entering the exact original code can confirm its display value without changing its hash. Redeemed codes are immutable.</div>
            <div class="row g-3">
              <div class="col-md-4"><label class="form-label" for="promoCode">Code</label><input class="form-control code-value" id="promoCode" maxlength="120" autocomplete="off"><div id="promoCodeHint" class="form-text"></div></div>
              <div class="col-md-5"><label class="form-label" for="promoInternalName">Internal name</label><input class="form-control" id="promoInternalName" maxlength="160" required></div>
              <div class="col-md-3"><label class="form-label" for="promoStatus">Stored status</label><select class="form-select" id="promoStatus"><option value="active">Active</option><option value="disabled">Disabled</option><option value="archived">Archived</option></select></div>
              <div class="col-12"><label class="form-label" for="promoDescription">Customer-facing description</label><textarea class="form-control" id="promoDescription" maxlength="500" rows="2"></textarea></div>
              <div class="col-md-4"><label class="form-label" for="promoType">Promotion type</label><select class="form-select" id="promoType"><option value="founder_lifetime">Founder lifetime</option><option value="stripe_free_months">Stripe free months</option><option value="admin_grant">Internal admin grant</option></select><div id="promoRuntimeSupport" class="form-text"></div></div>
              <div class="col-md-4"><label class="form-label" for="promoGrantKind">Internal grant kind</label><select class="form-select" id="promoGrantKind"><option value="">Not applicable</option><option value="trial">Trial</option><option value="fixed_duration">Fixed duration</option><option value="fixed_expiration">Fixed expiration</option><option value="complimentary">Complimentary</option><option value="lifetime">Lifetime</option><option value="manual">Manual</option></select></div>
              <div class="col-md-2"><label class="form-label" for="promoDurationMonths">Free months</label><input class="form-control" id="promoDurationMonths" type="number" min="0" max="2"></div>
              <div class="col-md-2"><label class="form-label" for="promoGrantDays">Grant days</label><input class="form-control" id="promoGrantDays" type="number" min="0" max="36500"></div>
              <div class="col-md-4"><label class="form-label" for="promoStarts">Starts at (UTC)</label><input class="form-control" id="promoStarts" type="datetime-local" required></div>
              <div class="col-md-4"><label class="form-label" for="promoExpires">Promo expires at (UTC)</label><input class="form-control" id="promoExpires" type="datetime-local"></div>
              <div class="col-md-4"><label class="form-label" for="promoGrantExpires">Granted access expires at (UTC)</label><input class="form-control" id="promoGrantExpires" type="datetime-local"></div>
              <div class="col-md-3"><label class="form-label" for="promoMaxRedemptions">Maximum redemptions</label><input class="form-control" id="promoMaxRedemptions" type="number" min="0"></div>
              <div class="col-md-3 d-flex align-items-end"><div class="form-check mb-2"><input class="form-check-input" id="promoOnePerUser" type="checkbox" checked><label class="form-check-label" for="promoOnePerUser">One redemption per member</label></div></div>
              <div class="col-md-3"><label class="form-label" for="promoStripePromotion">Stripe promotion ID</label><input class="form-control" id="promoStripePromotion" maxlength="255"></div>
              <div class="col-md-3"><label class="form-label" for="promoStripeCoupon">Stripe coupon ID</label><input class="form-control" id="promoStripeCoupon" maxlength="255"></div>
              <div class="col-12"><label class="form-label" for="promoNotes">Administrative notes</label><textarea class="form-control" id="promoNotes" rows="3"></textarea></div>
              <div class="col-12"><label class="form-label" for="promoReason">Change reason</label><input class="form-control" id="promoReason" maxlength="500" placeholder="Required for the audit record"></div>
            </div>
            <div id="promoDetailSections" class="mt-4 d-none">
              <h3 class="h6">Redemption history</h3><div class="detail-panel"><table class="table table-sm mb-0"><tbody id="promoDetailRedemptions"></tbody></table></div>
              <h3 class="h6 mt-3">Admin audit history</h3><div class="detail-panel"><table class="table table-sm mb-0"><tbody id="promoDetailAudit"></tbody></table></div>
            </div>
          </div>
          <div class="modal-footer justify-content-between"><div><button type="button" class="btn btn-outline-danger d-none" id="deletePromoBtn">Delete unused</button></div><div><button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancel</button> <button type="submit" class="btn btn-primary">Save</button></div></div>
        </form>
      </div></div>
    </div>
    <div class="modal fade" id="promoActionModal" tabindex="-1" aria-hidden="true" data-bs-backdrop="static">
      <div class="modal-dialog"><div class="modal-content"><form id="promoActionForm" novalidate>
        <div class="modal-header"><h2 class="modal-title h5" id="promoActionTitle">Promotion Action</h2><button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button></div>
        <div class="modal-body"><input type="hidden" id="promoActionId" value="0"><input type="hidden" id="promoActionStatus" value=""><div id="promoActionContext" class="alert alert-info py-2"></div><div id="promoActionError" class="alert alert-danger py-2 d-none"></div><div id="promoActionConfirmationWrap" class="mb-3 d-none"><label class="form-label" for="promoActionConfirmation">Confirmation</label><input class="form-control" id="promoActionConfirmation" autocomplete="off"><div id="promoActionConfirmationHint" class="form-text"></div></div><div><label class="form-label" for="promoActionReason">Reason</label><input class="form-control" id="promoActionReason" maxlength="500" required></div></div>
        <div class="modal-footer"><button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancel</button><button type="submit" class="btn btn-primary" id="promoActionSubmit">Save</button></div>
      </form></div></div>
    </div>
  </cfif>
  <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js" crossorigin="anonymous"></script>
  <cfif isAuthorized>
    <cfoutput><script>window.FPW_ADMIN_PROMO_CONFIG={endpoint:#serializeJSON(request.fpwApiBase & "/adminPromoCodes.cfc?method=handle")#,nonce:#serializeJSON(session.adminPromoCodesNonce)#};</script></cfoutput>
    <script src="<cfoutput>#encodeForHtmlAttribute(request.fpwBase)#</cfoutput>/assets/js/app/admin/promo-codes.js?v=<cfoutput>#encodeForHtmlAttribute(request.fpwAdminAssetVersion)#</cfoutput>"></script>
  </cfif>
</body>
</html>





