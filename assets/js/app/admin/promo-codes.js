(function (window, document) {
  "use strict";

  var config = window.FPW_ADMIN_PROMO_CONFIG || {};
  var state = { items: [], total: 0, limit: 50, offset: 0, redemptions: [], redemptionTotal: 0, redemptionLimit: 50, redemptionOffset: 0 };
  var els = {};
  var promoModal = null;
  var actionModal = null;
  var actionState = { type: "", promoCodeId: 0, status: "", returnToPromo: false, submitted: false };

  function byId(id) { return document.getElementById(id); }
  function toInt(value) { var n = parseInt(value, 10); return isNaN(n) ? 0 : n; }
  function escapeHtml(value) {
    return String(value === null || value === undefined ? "" : value)
      .replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;").replace(/'/g, "&#39;");
  }
  function safeValue(value) { return value === null || value === undefined ? "" : String(value); }
  function dateForInput(value) {
    if (!value) return "";
    var raw = String(value);
    var date = new Date(/[zZ]|[+-]\d\d:?\d\d$/.test(raw) ? raw : raw + " UTC");
    return isNaN(date.getTime()) ? "" : date.toISOString().slice(0, 16);
  }
  function dateLabel(value) { return value ? safeValue(value) : "—"; }
  function errorMessage(data, fallback) { return data && data.ERROR && data.ERROR.MESSAGE ? data.ERROR.MESSAGE : (data && data.MESSAGE ? data.MESSAGE : fallback); }
  function showMessage(message, type) {
    els.message.className = "admin-message" + (message ? " " + (type || "info") : "");
    els.message.textContent = message || "";
  }
  async function callApi(action, payload, write) {
    var body = Object.assign({ action: action }, payload || {});
    if (write) body.nonce = config.nonce || "";
    var response = await fetch(config.endpoint + "&action=" + encodeURIComponent(action), {
      method: "POST", credentials: "same-origin",
      headers: { "Content-Type": "application/json; charset=utf-8", "Accept": "application/json",
        "X-CSRF-Token": window.FPW_ADMIN_CSRF_TOKEN || "" },
      body: JSON.stringify(body)
    });
    var data;
    try { data = await response.json(); } catch (err) { throw new Error("The server returned invalid JSON."); }
    if (!response.ok && (!data || data.SUCCESS !== false)) throw new Error("Request failed with HTTP " + response.status + ".");
    return data;
  }
  function statusBadge(value) {
    var status = safeValue(value).toLowerCase();
    var cls = status === "active" ? "text-bg-success" : (status === "scheduled" ? "text-bg-info" : (status === "expired" ? "text-bg-secondary" : (status === "archived" ? "text-bg-dark" : "text-bg-warning")));
    return "<span class=\"badge status-badge " + cls + "\">" + escapeHtml(status || "unknown") + "</span>";
  }
  function codeLabel(item) {
    if (item.codeAvailable && item.code) return "<span class=\"code-value\">" + escapeHtml(item.code) + "</span>";
    return "<span class=\"code-value legacy-code\" title=\"Legacy plaintext is unavailable\">HASH:" + escapeHtml(item.codeHashFingerprint || "") + "</span>";
  }
  function grantLabel(item) {
    if (item.promoType === "founder_lifetime") return "Lifetime Premium";
    if (item.promoType === "stripe_free_months") return escapeHtml(item.durationMonths || 0) + " month Stripe trial";
    if (item.adminGrantKind === "fixed_expiration") return "Through " + escapeHtml(dateLabel(item.adminGrantExpiresAtUtc));
    if (item.adminGrantKind === "lifetime") return "Lifetime Premium";
    if (item.adminGrantDurationDays) return escapeHtml(item.adminGrantKind || "internal") + " · " + escapeHtml(item.adminGrantDurationDays) + " days";
    return escapeHtml(item.adminGrantKind || item.entitlementSource || "—");
  }
  function collectFilters() {
    return { search: els.search.value.trim(), lifecycle: els.lifecycle.value, promoType: els.typeFilter.value, sort: els.sort.value, direction: els.direction.value, limit: toInt(els.limit.value) || 50, offset: state.offset };
  }
  function renderPromos() {
    if (!state.items.length) els.tableBody.innerHTML = "<tr><td colspan=\"9\">No promotions found.</td></tr>";
    else els.tableBody.innerHTML = state.items.map(function (item) {
      var stripe = [item.stripePromotionCodeId ? "Promotion: " + item.stripePromotionCodeId : "", item.stripeCouponId ? "Coupon: " + item.stripeCouponId : ""].filter(Boolean).join("<br>") || "—";
      var stateActions = item.effectiveStatus === "archived" ? "<button class=\"btn btn-sm btn-outline-success\" data-action=\"activate\" data-id=\"" + item.promoCodeId + "\">Activate</button>" :
        (item.status === "active" ? "<button class=\"btn btn-sm btn-outline-warning\" data-action=\"disable\" data-id=\"" + item.promoCodeId + "\">Deactivate</button> <button class=\"btn btn-sm btn-outline-dark\" data-action=\"archive\" data-id=\"" + item.promoCodeId + "\">Archive</button>" : "<button class=\"btn btn-sm btn-outline-success\" data-action=\"activate\" data-id=\"" + item.promoCodeId + "\">Activate</button> <button class=\"btn btn-sm btn-outline-dark\" data-action=\"archive\" data-id=\"" + item.promoCodeId + "\">Archive</button>");
      return "<tr><td>" + codeLabel(item) + "<div class=\"small text-muted\">ID " + item.promoCodeId + "</div></td>" +
        "<td>" + escapeHtml(item.internalName || "(unnamed legacy promotion)") + "<div class=\"small text-muted\">" + escapeHtml(item.publicDescription || "") + "</div></td>" +
        "<td>" + escapeHtml(item.promoType) + "<div class=\"small text-muted\">" + escapeHtml(item.runtimeSupport) + "</div></td>" +
        "<td>" + statusBadge(item.effectiveStatus || item.status) + "</td><td>" + grantLabel(item) + "</td>" +
        "<td>" + escapeHtml(item.redemptionsCount) + (item.maxRedemptions ? " / " + escapeHtml(item.maxRedemptions) : "") + (item.onePerUser ? "<div class=\"small text-muted\">one/member</div>" : "") + "</td>" +
        "<td><div>" + escapeHtml(dateLabel(item.startsAtUtc)) + "</div><div class=\"small text-muted\">to " + escapeHtml(dateLabel(item.expiresAtUtc)) + "</div></td>" +
        "<td class=\"small\">" + stripe + "</td><td><div class=\"d-flex gap-1 flex-wrap\"><button class=\"btn btn-sm btn-outline-primary\" data-action=\"edit\" data-id=\"" + item.promoCodeId + "\">Edit / Detail</button> " + stateActions + "</div></td></tr>";
    }).join("");
    var start = state.total ? state.offset + 1 : 0, end = Math.min(state.offset + state.items.length, state.total);
    els.summary.textContent = "Showing " + start + " - " + end + " of " + state.total + " promotion(s).";
    els.page.textContent = "Page " + (Math.floor(state.offset / state.limit) + 1);
    els.prev.disabled = state.offset <= 0; els.next.disabled = state.offset + state.limit >= state.total;
  }
  async function loadPromos() {
    showMessage("Loading promotions...", "info");
    try {
      var filters = collectFilters(); state.limit = filters.limit;
      var data = await callApi("list", filters, false);
      if (!data.SUCCESS) throw new Error(errorMessage(data, "Unable to load promotions."));
      state.items = data.DATA.items || []; state.total = toInt(data.DATA.total); renderPromos(); showMessage("", "info");
    } catch (err) { state.items = []; state.total = 0; renderPromos(); showMessage(err.message || "Unable to load promotions.", "error"); }
  }
  function resetForm() {
    els.form.reset(); els.formId.value = "0"; els.code.value = ""; els.code.required = true;
    els.status.value = "active"; els.type.value = "founder_lifetime"; els.onePerUser.checked = true;
    els.starts.value = new Date().toISOString().slice(0, 16); els.codeHint.textContent = "Code will be normalized to uppercase and hashed for live redemption.";
    els.detailSections.classList.add("d-none"); els.deleteBtn.classList.add("d-none"); updateTypeHelp();
  }
  function updateTypeHelp() {
    var value = els.type.value;
    els.runtimeSupport.textContent = value === "admin_grant" ? "Internal admin grant only; not publicly redeemable." : "Uses the existing public redemption behavior.";
    els.grantKind.disabled = value !== "admin_grant";
    els.grantDays.disabled = value !== "admin_grant";
    els.grantExpires.disabled = value !== "admin_grant";
    els.durationMonths.disabled = value !== "stripe_free_months";
  }
  function setForm(item) {
    els.formId.value = item.promoCodeId; els.code.value = item.code || ""; els.code.required = false;
    els.codeHint.textContent = item.codeAvailable ? "Code is stored for admin display. It becomes immutable after redemption." : "Legacy code unavailable. Leave blank to preserve its hash, or enter the exact original code to confirm it.";
    els.internalName.value = item.internalName || ""; els.description.value = item.publicDescription || ""; els.status.value = item.status || "active";
    if (["founder_lifetime", "stripe_free_months", "admin_grant"].indexOf(item.promoType) === -1) {
      var option = document.createElement("option"); option.value = item.promoType; option.textContent = item.promoType + " (legacy)"; els.type.appendChild(option);
    }
    els.type.value = item.promoType || "founder_lifetime"; els.grantKind.value = item.adminGrantKind || ""; els.durationMonths.value = item.durationMonths || ""; els.grantDays.value = item.adminGrantDurationDays || "";
    els.starts.value = dateForInput(item.startsAtUtc); els.expires.value = dateForInput(item.expiresAtUtc); els.grantExpires.value = dateForInput(item.adminGrantExpiresAtUtc);
    els.maxRedemptions.value = item.maxRedemptions || ""; els.onePerUser.checked = !!item.onePerUser; els.stripePromotion.value = item.stripePromotionCodeId || ""; els.stripeCoupon.value = item.stripeCouponId || ""; els.notes.value = item.adminNotes || ""; els.reason.value = "";
    els.deleteBtn.classList.remove("d-none"); updateTypeHelp();
  }
  function renderPromoDetail(data) {
    var redemptions = data.redemptions || [], audits = data.audit || [];
    els.detailRedemptions.innerHTML = redemptions.length ? redemptions.map(function (row) { return "<tr><td>" + escapeHtml(row.memberEmail || ("User " + row.userId)) + "</td><td>" + escapeHtml(row.result) + (row.errorCode ? " · " + escapeHtml(row.errorCode) : "") + "</td><td>" + escapeHtml(dateLabel(row.redeemedAtUtc || row.attemptedAtUtc)) + "</td></tr>"; }).join("") : "<tr><td>No redemption history.</td></tr>";
    els.detailAudit.innerHTML = audits.length ? audits.map(function (row) { return "<tr><td>" + escapeHtml(row.action) + "</td><td>" + escapeHtml(row.adminEmail || ("Admin " + row.adminUserId)) + "</td><td>" + escapeHtml(row.reason || "") + "</td><td>" + escapeHtml(dateLabel(row.createdAtUtc)) + "</td></tr>"; }).join("") : "<tr><td>No admin audit history.</td></tr>";
    els.detailSections.classList.remove("d-none");
  }
  async function openPromo(id) {
    showMessage("Loading promotion...", "info");
    try {
      var data = await callApi("get", { promoCodeId: id }, false);
      if (!data.SUCCESS) throw new Error(errorMessage(data, "Unable to load promotion."));
      resetForm(); setForm(data.DATA.promo); renderPromoDetail(data.DATA); els.modalTitle.textContent = "Edit Promo Code #" + id; promoModal.show(); showMessage("", "info");
    } catch (err) { showMessage(err.message, "error"); }
  }
  function formPayload() {
    return {
      promoCodeId: toInt(els.formId.value), code: els.code.value.trim(), internalName: els.internalName.value.trim(), publicDescription: els.description.value.trim(),
      status: els.status.value, promoType: els.type.value, adminGrantKind: els.grantKind.value, durationMonths: toInt(els.durationMonths.value), adminGrantDurationDays: toInt(els.grantDays.value),
      startsAtUtc: els.starts.value, expiresAtUtc: els.expires.value, adminGrantExpiresAtUtc: els.grantExpires.value, maxRedemptions: toInt(els.maxRedemptions.value), onePerUser: els.onePerUser.checked,
      stripePromotionCodeId: els.stripePromotion.value.trim(), stripeCouponId: els.stripeCoupon.value.trim(), entitlementType: "premium", entitlementSource: "", adminNotes: els.notes.value.trim(), reason: els.reason.value.trim()
    };
  }
  async function savePromo(event) {
    event.preventDefault();
    try {
      var data = await callApi("save", formPayload(), true);
      if (!data.SUCCESS) throw new Error(errorMessage(data, "Unable to save promotion."));
      promoModal.hide(); showMessage(data.MESSAGE || "Promotion saved.", "success"); await loadPromos();
    } catch (err) { showMessage(err.message, "error"); }
  }
  function showPromoActionError(message) { els.actionError.textContent = message || ""; els.actionError.classList.toggle("d-none", !message); }
  function openPromoAction(type, id, status, returnToPromo) {
    var label = status === "active" ? "Activate" : (status === "archived" ? "Archive" : "Deactivate");
    actionState = { type: type, promoCodeId: toInt(id), status: status || "", returnToPromo: !!returnToPromo, submitted: false };
    els.actionForm.reset(); els.actionId.value = actionState.promoCodeId; els.actionStatus.value = actionState.status; showPromoActionError("");
    els.actionConfirmationWrap.classList.add("d-none"); els.actionConfirmation.required = false; els.actionConfirmation.value = ""; els.actionReason.value = ""; els.actionSubmit.className = "btn btn-primary";
    if (type === "delete") {
      var confirmation = "DELETE PROMO " + id;
      els.actionTitle.textContent = "Delete Unused Promotion #" + id;
      els.actionContext.textContent = "Deletion is allowed only when the promotion has no redemption, entitlement, or protected audit history.";
      els.actionConfirmationWrap.classList.remove("d-none"); els.actionConfirmation.required = true; els.actionConfirmationHint.textContent = "Type " + confirmation + " to confirm.";
      els.actionSubmit.textContent = "Delete unused"; els.actionSubmit.className = "btn btn-danger";
    } else {
      els.actionTitle.textContent = label + " Promotion #" + id; els.actionContext.textContent = "Change the stored promotion status to " + status + ". This does not create or modify Stripe objects."; els.actionSubmit.textContent = label + " promotion";
    }
    function showActionModal() { actionModal.show(); }
    if (actionState.returnToPromo && els.promoModalElement.classList.contains("show")) {
      els.promoModalElement.addEventListener("hidden.bs.modal", showActionModal, { once: true }); promoModal.hide();
    } else showActionModal();
  }
  function changeState(id, status) { openPromoAction("state", id, status, false); }
  function deleteUnused() { var id = toInt(els.formId.value); if (id) openPromoAction("delete", id, "", true); }
  async function submitPromoAction(event) {
    event.preventDefault(); showPromoActionError("");
    var reason = els.actionReason.value.trim(); if (!reason) { showPromoActionError("Reason is required."); return; }
    var apiAction = actionState.type === "delete" ? "delete" : "state";
    var payload = { promoCodeId: actionState.promoCodeId, reason: reason };
    if (apiAction === "delete") payload.confirmation = els.actionConfirmation.value.trim(); else payload.status = actionState.status;
    try {
      var data = await callApi(apiAction, payload, true); if (!data.SUCCESS) throw new Error(errorMessage(data, apiAction === "delete" ? "Unable to delete promotion." : "Unable to change promotion status."));
      actionState.submitted = true;
      var hidden = new Promise(function (resolve) { els.actionModalElement.addEventListener("hidden.bs.modal", resolve, { once: true }); }); actionModal.hide(); await hidden;
      showMessage(data.MESSAGE || "Promotion updated.", "success"); await loadPromos();
    } catch (err) { showPromoActionError(err.message || "Unable to update promotion."); }
  }
  function collectRedemptionFilters() { return { search: els.redemptionSearch.value.trim(), result: els.redemptionResult.value, limit: state.redemptionLimit, offset: state.redemptionOffset }; }
  function renderRedemptions() {
    els.redemptionBody.innerHTML = state.redemptions.length ? state.redemptions.map(function (row) {
      var promo = row.promoCode || (row.promoHashFingerprint ? "HASH:" + row.promoHashFingerprint : "Unknown");
      return "<tr><td><span class=\"code-value\">" + escapeHtml(promo) + "</span><div class=\"small text-muted\">" + escapeHtml(row.promoName || "") + "</div></td><td>" + escapeHtml(row.memberName || ("User " + row.userId)) + "<div class=\"small text-muted\">" + escapeHtml(row.memberEmail || "") + "</div></td><td>" + escapeHtml(row.result) + (row.errorCode ? "<div class=\"small text-danger\">" + escapeHtml(row.errorCode) + "</div>" : "") + "</td><td>" + escapeHtml(row.entitlementId || "—") + "<div class=\"small text-muted\">" + escapeHtml(dateLabel(row.entitlementStartsAtUtc)) + " → " + escapeHtml(dateLabel(row.entitlementExpiresAtUtc)) + "</div></td><td class=\"small\">" + escapeHtml(row.stripeCheckoutSessionId || "—") + "</td><td>" + escapeHtml(dateLabel(row.attemptedAtUtc)) + "<div class=\"small text-muted\">" + escapeHtml(dateLabel(row.redeemedAtUtc)) + "</div></td></tr>";
    }).join("") : "<tr><td colspan=\"6\">No redemption history found.</td></tr>";
    var start = state.redemptionTotal ? state.redemptionOffset + 1 : 0, end = Math.min(state.redemptionOffset + state.redemptions.length, state.redemptionTotal);
    els.redemptionSummary.textContent = "Showing " + start + " - " + end + " of " + state.redemptionTotal + " redemption record(s).";
    els.redemptionPage.textContent = "Page " + (Math.floor(state.redemptionOffset / state.redemptionLimit) + 1);
    els.redemptionPrev.disabled = state.redemptionOffset <= 0; els.redemptionNext.disabled = state.redemptionOffset + state.redemptionLimit >= state.redemptionTotal;
  }
  async function loadRedemptions() {
    try { var data = await callApi("redemptions", collectRedemptionFilters(), false); if (!data.SUCCESS) throw new Error(errorMessage(data, "Unable to load redemptions.")); state.redemptions = data.DATA.items || []; state.redemptionTotal = toInt(data.DATA.total); renderRedemptions(); } catch (err) { showMessage(err.message, "error"); }
  }
  function bind() {
    els.form.addEventListener("submit", savePromo); els.type.addEventListener("change", updateTypeHelp); els.deleteBtn.addEventListener("click", deleteUnused); els.actionForm.addEventListener("submit", submitPromoAction);
    byId("newPromoBtn").addEventListener("click", function () { resetForm(); els.modalTitle.textContent = "New Promo Code"; promoModal.show(); });
    byId("promoFilters").addEventListener("submit", function (event) { event.preventDefault(); state.offset = 0; loadPromos(); });
    byId("resetPromoFilters").addEventListener("click", function () { byId("promoFilters").reset(); state.offset = 0; loadPromos(); });
    els.prev.addEventListener("click", function () { state.offset = Math.max(0, state.offset - state.limit); loadPromos(); });
    els.next.addEventListener("click", function () { state.offset += state.limit; loadPromos(); });
    els.tableBody.addEventListener("click", function (event) { var button = event.target.closest("button[data-action]"); if (!button) return; var id = toInt(button.dataset.id), action = button.dataset.action; if (action === "edit") openPromo(id); else if (action === "disable") changeState(id, "disabled"); else if (action === "archive") changeState(id, "archived"); else if (action === "activate") changeState(id, "active"); });
    els.actionModalElement.addEventListener("hidden.bs.modal", function () { var reopen = actionState.returnToPromo && !actionState.submitted; actionState.returnToPromo = false; if (reopen) promoModal.show(); });
    byId("redemptionTabBtn").addEventListener("shown.bs.tab", function () { if (!state.redemptions.length) loadRedemptions(); });
    byId("redemptionSearchBtn").addEventListener("click", function () { state.redemptionOffset = 0; loadRedemptions(); });
    els.redemptionPrev.addEventListener("click", function () { state.redemptionOffset = Math.max(0, state.redemptionOffset - state.redemptionLimit); loadRedemptions(); });
    els.redemptionNext.addEventListener("click", function () { state.redemptionOffset += state.redemptionLimit; loadRedemptions(); });
  }
  function init() {
    els = { message: byId("promoMessage"), search: byId("promoSearch"), lifecycle: byId("promoLifecycle"), typeFilter: byId("promoTypeFilter"), sort: byId("promoSort"), direction: byId("promoDirection"), limit: byId("promoLimit"), tableBody: byId("promoTableBody"), summary: byId("promoSummary"), prev: byId("promoPrev"), next: byId("promoNext"), page: byId("promoPage"), form: byId("promoForm"), formId: byId("promoCodeId"), code: byId("promoCode"), codeHint: byId("promoCodeHint"), internalName: byId("promoInternalName"), description: byId("promoDescription"), status: byId("promoStatus"), type: byId("promoType"), grantKind: byId("promoGrantKind"), durationMonths: byId("promoDurationMonths"), grantDays: byId("promoGrantDays"), starts: byId("promoStarts"), expires: byId("promoExpires"), grantExpires: byId("promoGrantExpires"), maxRedemptions: byId("promoMaxRedemptions"), onePerUser: byId("promoOnePerUser"), stripePromotion: byId("promoStripePromotion"), stripeCoupon: byId("promoStripeCoupon"), notes: byId("promoNotes"), reason: byId("promoReason"), runtimeSupport: byId("promoRuntimeSupport"), modalTitle: byId("promoModalTitle"), detailSections: byId("promoDetailSections"), detailRedemptions: byId("promoDetailRedemptions"), detailAudit: byId("promoDetailAudit"), deleteBtn: byId("deletePromoBtn"), redemptionSearch: byId("redemptionSearch"), redemptionResult: byId("redemptionResult"), redemptionBody: byId("redemptionTableBody"), redemptionSummary: byId("redemptionSummary"), redemptionPrev: byId("redemptionPrev"), redemptionNext: byId("redemptionNext"), redemptionPage: byId("redemptionPage"), promoModalElement: byId("promoModal"), actionModalElement: byId("promoActionModal"), actionForm: byId("promoActionForm"), actionId: byId("promoActionId"), actionStatus: byId("promoActionStatus"), actionTitle: byId("promoActionTitle"), actionContext: byId("promoActionContext"), actionError: byId("promoActionError"), actionConfirmationWrap: byId("promoActionConfirmationWrap"), actionConfirmation: byId("promoActionConfirmation"), actionConfirmationHint: byId("promoActionConfirmationHint"), actionReason: byId("promoActionReason"), actionSubmit: byId("promoActionSubmit") };
    promoModal = new window.bootstrap.Modal(byId("promoModal")); actionModal = new window.bootstrap.Modal(byId("promoActionModal")); bind(); loadPromos();
  }
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", init); else init();
})(window, document);

