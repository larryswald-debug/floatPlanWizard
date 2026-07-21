(function (window, document) {
  "use strict";

  var config = window.FPW_ADMIN_ENTITLEMENT_CONFIG || {};
  var state = { items: [], total: 0, limit: 50, offset: 0, activeUserId: 0, detailItems: [] };
  var els = {};
  var grantModal = null;
  var detailModal = null;
  var actionModal = null;
  var actionState = { type: "", entitlementId: 0, userId: 0, returnToDetail: false, submitted: false };

  function byId(id) { return document.getElementById(id); }
  function toInt(value) { var n = parseInt(value, 10); return isNaN(n) ? 0 : n; }
  function escapeHtml(value) { return String(value === null || value === undefined ? "" : value).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;").replace(/'/g, "&#39;"); }
  function safeValue(value) { return value === null || value === undefined ? "" : String(value); }
  function dateLabel(value) { return value ? safeValue(value) : "—"; }
  function errorMessage(data, fallback) { return data && data.ERROR && data.ERROR.MESSAGE ? data.ERROR.MESSAGE : (data && data.MESSAGE ? data.MESSAGE : fallback); }
  function showMessage(message, type) { els.message.className = "admin-message" + (message ? " " + (type || "info") : ""); els.message.textContent = message || ""; }
  async function callApi(action, payload, write) {
    var body = Object.assign({ action: action }, payload || {}); if (write) body.nonce = config.nonce || "";
    var response = await fetch(config.endpoint + "&action=" + encodeURIComponent(action), { method: "POST", credentials: "same-origin", headers: { "Content-Type": "application/json; charset=utf-8", "Accept": "application/json",
        "X-CSRF-Token": window.FPW_ADMIN_CSRF_TOKEN || "" }, body: JSON.stringify(body) });
    var data; try { data = await response.json(); } catch (err) { throw new Error("The server returned invalid JSON."); }
    if (!response.ok && (!data || data.SUCCESS !== false)) throw new Error("Request failed with HTTP " + response.status + "."); return data;
  }
  function statusBadge(value) {
    var status = safeValue(value).toLowerCase(); var cls = status === "active" ? "text-bg-success" : (status === "scheduled" ? "text-bg-info" : (status === "revoked" ? "text-bg-danger" : "text-bg-secondary"));
    return "<span class=\"badge " + cls + "\">" + escapeHtml(status || "unknown") + "</span>";
  }
  function collectFilters() { return { search: els.search.value.trim(), lifecycle: els.lifecycle.value, source: els.source.value, sort: els.sort.value, direction: els.direction.value, limit: toInt(els.limit.value) || 50, offset: state.offset }; }
  function promoLabel(item) { return item.promoCode ? escapeHtml(item.promoCode) : (item.promoHashFingerprint ? "HASH:" + escapeHtml(item.promoHashFingerprint) : "—"); }
  function rowActions(item) {
    var buttons = ["<button class=\"btn btn-sm btn-outline-primary\" data-action=\"detail\" data-user-id=\"" + item.userId + "\">Member detail</button>"];
    buttons.push("<button class=\"btn btn-sm btn-outline-secondary\" data-action=\"notes\" data-id=\"" + item.entitlementId + "\" data-user-id=\"" + item.userId + "\">Notes</button>");
    if (!item.isStripeManaged && item.effectiveStatus !== "revoked") {
      if (item.expiresAtUtc) buttons.push("<button class=\"btn btn-sm btn-outline-success\" data-action=\"extend\" data-id=\"" + item.entitlementId + "\" data-user-id=\"" + item.userId + "\">Extend</button>");
      buttons.push("<button class=\"btn btn-sm btn-outline-danger\" data-action=\"revoke\" data-id=\"" + item.entitlementId + "\" data-user-id=\"" + item.userId + "\">Revoke</button>");
    }
    return "<div class=\"d-flex flex-wrap gap-1\">" + buttons.join("") + "</div>";
  }
  function renderRows() {
    if (!state.items.length) els.tableBody.innerHTML = "<tr><td colspan=\"8\">No entitlements found.</td></tr>";
    else els.tableBody.innerHTML = state.items.map(function (item) {
      var flags = [item.isLifetime ? "Lifetime" : "", item.isTrial ? "Trial" : "", item.isComplimentary ? "Complimentary" : "", item.isStripeManaged ? "Stripe Managed" : ""].filter(Boolean).map(function (flag) { return "<span class=\"badge text-bg-light border me-1\">" + escapeHtml(flag) + "</span>"; }).join("");
      var stripe = item.isStripeManaged ? escapeHtml(item.stripeSubscriptionStatus || "") + "<div class=\"small text-muted\">" + escapeHtml(item.stripeSubscriptionId || item.stripeCustomerId || "") + "</div>" : "—";
      return "<tr class=\"" + (item.isStripeManaged ? "stripe-managed" : "") + "\"><td>" + escapeHtml(item.memberName || ("Member " + item.userId)) + "<div class=\"small text-muted\">" + escapeHtml(item.memberEmail || "") + " · ID " + item.userId + "</div></td><td>#" + item.entitlementId + " · " + escapeHtml(item.membershipLevel) + "<div>" + flags + "</div></td><td>" + statusBadge(item.effectiveStatus || item.status) + "<div class=\"small text-muted\">stored: " + escapeHtml(item.status) + "</div></td><td>" + escapeHtml(item.source) + "<div class=\"small text-muted\">" + escapeHtml(item.grantKind || "") + "</div></td><td>" + promoLabel(item) + "<div class=\"small text-muted\">" + escapeHtml(item.promoName || "") + "</div></td><td>" + escapeHtml(dateLabel(item.startsAtUtc)) + "<div class=\"small text-muted\">to " + escapeHtml(dateLabel(item.expiresAtUtc)) + "</div></td><td class=\"small\">" + stripe + "</td><td>" + rowActions(item) + "</td></tr>";
    }).join("");
    var start = state.total ? state.offset + 1 : 0, end = Math.min(state.offset + state.items.length, state.total);
    els.summary.textContent = "Showing " + start + " - " + end + " of " + state.total + " entitlement record(s)."; els.page.textContent = "Page " + (Math.floor(state.offset / state.limit) + 1); els.prev.disabled = state.offset <= 0; els.next.disabled = state.offset + state.limit >= state.total;
  }
  async function loadEntitlements() {
    showMessage("Loading entitlements...", "info");
    try { var filters = collectFilters(); state.limit = filters.limit; var data = await callApi("list", filters, false); if (!data.SUCCESS) throw new Error(errorMessage(data, "Unable to load entitlements.")); state.items = data.DATA.items || []; state.total = toInt(data.DATA.total); renderRows(); showMessage("", "info"); }
    catch (err) { state.items = []; state.total = 0; renderRows(); showMessage(err.message || "Unable to load entitlements.", "error"); }
  }
  function resetGrantForm() {
    els.grantForm.reset(); els.grantUserId.value = "0"; els.memberResults.innerHTML = ""; els.selectedMember.classList.add("d-none"); els.overlapResults.innerHTML = ""; els.grantStarts.value = new Date().toISOString().slice(0, 16); els.grantKind.value = "trial"; els.confirmOverlap.checked = false;
  }
  async function searchMembers() {
    var search = els.memberSearch.value.trim(); if (!search) { els.memberResults.innerHTML = "<div class=\"list-group-item text-muted\">Enter a name, email, or member ID.</div>"; return; }
    try { var data = await callApi("members", { search: search, limit: 25 }, false); if (!data.SUCCESS) throw new Error(errorMessage(data, "Unable to search members.")); var items = data.DATA.items || []; els.memberResults.innerHTML = items.length ? items.map(function (item) { return "<button type=\"button\" class=\"list-group-item list-group-item-action member-result\" data-user-id=\"" + item.userId + "\" data-name=\"" + escapeHtml(item.name) + "\" data-email=\"" + escapeHtml(item.email) + "\"><strong>" + escapeHtml(item.name || ("Member " + item.userId)) + "</strong><br><span class=\"small\">" + escapeHtml(item.email) + " · ID " + item.userId + " · " + item.entitlementCount + " entitlement(s)</span></button>"; }).join("") : "<div class=\"list-group-item text-muted\">No members found.</div>"; }
    catch (err) { els.memberResults.innerHTML = "<div class=\"list-group-item text-danger\">" + escapeHtml(err.message) + "</div>"; }
  }
  function selectMember(button) { var userId = toInt(button.dataset.userId); els.grantUserId.value = userId; els.selectedMember.textContent = (button.dataset.name || ("Member " + userId)) + " · " + (button.dataset.email || "") + " · ID " + userId; els.selectedMember.classList.remove("d-none"); els.memberResults.innerHTML = ""; }
  function grantPayload(includeConfirm) { return { userId: toInt(els.grantUserId.value), grantKind: els.grantKind.value, promoCodeId: toInt(els.grantPromoId.value), startsAtUtc: els.grantStarts.value, durationDays: toInt(els.grantDurationDays.value), expiresAtUtc: els.grantExpires.value, adminNotes: els.grantNotes.value.trim(), reason: els.grantReason.value.trim(), confirmOverlap: includeConfirm ? els.confirmOverlap.checked : false }; }
  async function checkOverlap() {
    var payload = grantPayload(false); if (!payload.userId) { els.overlapResults.innerHTML = "<div class=\"alert alert-warning py-2\">Select a member first.</div>"; return; }
    var expiration = payload.expiresAtUtc;
    if (["trial", "fixed_duration", "complimentary"].indexOf(payload.grantKind) !== -1 && payload.durationDays > 0) { var start = new Date(payload.startsAtUtc + "Z"); if (!isNaN(start.getTime())) expiration = new Date(start.getTime() + payload.durationDays * 86400000).toISOString().slice(0, 16); }
    try { var data = await callApi("overlap", { userId: payload.userId, startsAtUtc: payload.startsAtUtc, expiresAtUtc: expiration }, false); if (!data.SUCCESS) throw new Error(errorMessage(data, "Unable to check overlap.")); var items = data.DATA.items || []; els.overlapResults.innerHTML = items.length ? "<div class=\"alert alert-warning py-2\"><strong>Overlapping access:</strong><ul class=\"mb-0\">" + items.map(function (item) { return "<li>#" + item.entitlementId + " " + escapeHtml(item.source) + " · " + escapeHtml(dateLabel(item.startsAtUtc)) + " → " + escapeHtml(dateLabel(item.expiresAtUtc)) + "</li>"; }).join("") + "</ul></div>" : "<div class=\"alert alert-success py-2\">No overlapping active or scheduled entitlements.</div>"; }
    catch (err) { els.overlapResults.innerHTML = "<div class=\"alert alert-danger py-2\">" + escapeHtml(err.message) + "</div>"; }
  }
  async function grantEntitlement(event) {
    event.preventDefault();
    try { var data = await callApi("grant", grantPayload(true), true); if (!data.SUCCESS) { if (data.ERROR && data.ERROR.CODE === "OVERLAP_CONFIRMATION_REQUIRED") { var overlaps = data.DATA.overlaps || []; els.overlapResults.innerHTML = "<div class=\"alert alert-warning py-2\"><strong>Overlap confirmation required.</strong><ul class=\"mb-0\">" + overlaps.map(function (item) { return "<li>#" + item.entitlementId + " " + escapeHtml(item.source) + "</li>"; }).join("") + "</ul></div>"; } throw new Error(errorMessage(data, "Unable to grant entitlement.")); } grantModal.hide(); showMessage(data.MESSAGE || "Entitlement granted.", "success"); await loadEntitlements(); }
    catch (err) { showMessage(err.message, "error"); }
  }
  function detailEntitlementActions(item) {
    var actions = ["<button class=\"btn btn-sm btn-outline-secondary\" data-detail-action=\"notes\" data-id=\"" + item.entitlementId + "\">Notes</button>"];
    if (!item.isStripeManaged && item.effectiveStatus !== "revoked") { if (item.expiresAtUtc) actions.push("<button class=\"btn btn-sm btn-outline-success\" data-detail-action=\"extend\" data-id=\"" + item.entitlementId + "\">Extend</button>"); actions.push("<button class=\"btn btn-sm btn-outline-danger\" data-detail-action=\"revoke\" data-id=\"" + item.entitlementId + "\">Revoke</button>"); }
    return actions.join(" ");
  }
  function renderDetail(data) {
    var member = data.member || {}, access = data.effectiveAccess || {}, items = data.entitlements || [], redemptions = data.redemptions || [], audit = data.audit || [];
    state.detailItems = items;
    state.activeUserId = toInt(member.userId); els.detailTitle.textContent = "Member Entitlement Detail · " + (member.name || ("Member " + member.userId)); els.memberSummary.innerHTML = "<p><strong>" + escapeHtml(member.name || "") + "</strong><br>" + escapeHtml(member.email || "") + " · Member ID " + escapeHtml(member.userId) + "</p>";
    els.effectiveAccess.textContent = access.hasPremium ? ("Effective access: Premium · controlling source " + safeValue(access.premiumSource) + " · entitlement #" + safeValue(access.premiumEntitlementId) + (access.premiumExpiresAt ? " · expires " + safeValue(access.premiumExpiresAt) : " · open-ended")) : "Effective access: Basic · no currently effective Premium entitlement.";
    els.memberEntitlements.innerHTML = items.length ? items.map(function (item) { return "<tr class=\"" + (item.isStripeManaged ? "stripe-managed" : "") + "\"><td>#" + item.entitlementId + (item.isStripeManaged ? "<br><span class=\"badge text-bg-warning\">Stripe Managed</span>" : "") + "</td><td>" + statusBadge(item.effectiveStatus || item.status) + "</td><td>" + escapeHtml(item.source) + "<br><span class=\"small text-muted\">" + escapeHtml(item.grantKind || "") + "</span></td><td>" + escapeHtml(dateLabel(item.startsAtUtc)) + "<br>to " + escapeHtml(dateLabel(item.expiresAtUtc)) + "</td><td>" + escapeHtml(item.adminNotes || "") + (item.revocationReason ? "<div class=\"text-danger small\">" + escapeHtml(item.revocationReason) + "</div>" : "") + "</td><td>" + detailEntitlementActions(item) + "</td></tr>"; }).join("") : "<tr><td colspan=\"6\">No entitlement records.</td></tr>";
    els.memberRedemptions.innerHTML = redemptions.length ? redemptions.map(function (row) { return "<tr><td>" + escapeHtml(row.promoCode || (row.promoHashFingerprint ? "HASH:" + row.promoHashFingerprint : "Unknown promo")) + "</td><td>" + escapeHtml(row.result) + (row.errorCode ? " · " + escapeHtml(row.errorCode) : "") + "</td><td>" + escapeHtml(dateLabel(row.redeemedAtUtc || row.attemptedAtUtc)) + "</td></tr>"; }).join("") : "<tr><td>No promo redemption history.</td></tr>";
    els.memberAudit.innerHTML = audit.length ? audit.map(function (row) { return "<tr><td>" + escapeHtml(row.action) + "</td><td>" + escapeHtml(row.adminEmail || ("Admin " + row.adminUserId)) + "</td><td>" + escapeHtml(row.reason || "") + "</td><td>" + escapeHtml(dateLabel(row.createdAtUtc)) + "</td></tr>"; }).join("") : "<tr><td>No admin audit history.</td></tr>";
  }
  async function openDetail(userId) { try { var data = await callApi("detail", { userId: userId }, false); if (!data.SUCCESS) throw new Error(errorMessage(data, "Unable to load member detail.")); renderDetail(data.DATA); detailModal.show(); } catch (err) { showMessage(err.message, "error"); } }
  function entitlementById(id) {
    var items = (state.detailItems || []).concat(state.items || []);
    for (var i = 0; i < items.length; i++) if (toInt(items[i].entitlementId) === toInt(id)) return items[i];
    return null;
  }
  function showActionError(message) { els.actionError.textContent = message || ""; els.actionError.classList.toggle("d-none", !message); }
  function openEntitlementAction(action, id, userId, returnToDetail) {
    var item = entitlementById(id) || {};
    actionState = { type: action, entitlementId: toInt(id), userId: toInt(userId), returnToDetail: !!returnToDetail, submitted: false };
    els.actionId.value = actionState.entitlementId; els.actionUserId.value = actionState.userId; els.actionForm.reset(); showActionError("");
    els.actionExpiresWrap.classList.add("d-none"); els.actionNotesWrap.classList.add("d-none"); els.actionConfirmationWrap.classList.add("d-none");
    els.actionExpires.required = false; els.actionConfirmation.required = false; els.actionReason.value = ""; els.actionConfirmation.value = ""; els.actionNotes.value = "";
    els.actionSubmit.className = "btn btn-primary";
    if (action === "extend") {
      els.actionTitle.textContent = "Extend Entitlement #" + id; els.actionContext.textContent = "Current expiration: " + dateLabel(item.expiresAtUtc) + ". Enter the new UTC expiration and an audit reason.";
      els.actionExpiresWrap.classList.remove("d-none"); els.actionExpires.required = true; els.actionSubmit.textContent = "Extend entitlement";
    } else if (action === "revoke") {
      var confirmation = "REVOKE ENTITLEMENT " + id;
      els.actionTitle.textContent = "Revoke Entitlement #" + id; els.actionContext.textContent = "Revocation ends this internal entitlement only. It does not cancel Stripe.";
      els.actionConfirmationWrap.classList.remove("d-none"); els.actionConfirmation.required = true; els.actionConfirmationHint.textContent = "Type " + confirmation + " to confirm.";
      els.actionSubmit.textContent = "Revoke entitlement"; els.actionSubmit.className = "btn btn-danger";
    } else {
      els.actionTitle.textContent = "Edit Notes for Entitlement #" + id; els.actionContext.textContent = item.isStripeManaged ? "This Stripe-managed entitlement remains read-only except for administrative notes." : "Update administrative notes without changing access dates or status.";
      els.actionNotesWrap.classList.remove("d-none"); els.actionNotes.value = safeValue(item.adminNotes); els.actionSubmit.textContent = "Save notes";
    }
    function showActionModal() { actionModal.show(); }
    if (actionState.returnToDetail && els.detailModalElement.classList.contains("show")) {
      els.detailModalElement.addEventListener("hidden.bs.modal", showActionModal, { once: true }); detailModal.hide();
    } else showActionModal();
  }
  async function submitEntitlementAction(event) {
    event.preventDefault(); showActionError("");
    var action = actionState.type, payload = { entitlementId: actionState.entitlementId, reason: els.actionReason.value.trim() }, apiAction = action;
    if (!payload.reason) { showActionError("Reason is required."); return; }
    if (action === "extend") { payload.newExpiresAtUtc = els.actionExpires.value; if (!payload.newExpiresAtUtc) { showActionError("New expiration is required."); return; } }
    else if (action === "revoke") payload.confirmation = els.actionConfirmation.value.trim();
    else { apiAction = "notes"; payload.adminNotes = els.actionNotes.value.trim(); }
    try {
      var data = await callApi(apiAction, payload, true); if (!data.SUCCESS) throw new Error(errorMessage(data, "Unable to update entitlement."));
      var userId = actionState.userId; actionState.submitted = true;
      var hidden = new Promise(function (resolve) { els.actionModalElement.addEventListener("hidden.bs.modal", resolve, { once: true }); }); actionModal.hide(); await hidden;
      showMessage(data.MESSAGE || "Entitlement updated.", "success"); await loadEntitlements(); if (userId) await openDetail(userId);
    } catch (err) { showActionError(err.message || "Unable to update entitlement."); }
  }
  function handleAction(action, id, userId, fromDetail) { if (action === "detail") openDetail(userId); else if (action === "extend" || action === "revoke" || action === "notes") openEntitlementAction(action, id, userId, fromDetail); }
  function bind() {
    byId("grantEntitlementBtn").addEventListener("click", function () { resetGrantForm(); grantModal.show(); }); els.memberSearchBtn.addEventListener("click", searchMembers); els.memberSearch.addEventListener("keydown", function (event) { if (event.key === "Enter") { event.preventDefault(); searchMembers(); } }); els.memberResults.addEventListener("click", function (event) { var button = event.target.closest("button[data-user-id]"); if (button) selectMember(button); }); els.checkOverlap.addEventListener("click", checkOverlap); els.grantForm.addEventListener("submit", grantEntitlement); els.actionForm.addEventListener("submit", submitEntitlementAction);
    byId("entitlementFilters").addEventListener("submit", function (event) { event.preventDefault(); state.offset = 0; loadEntitlements(); }); byId("resetEntitlementFilters").addEventListener("click", function () { byId("entitlementFilters").reset(); state.offset = 0; loadEntitlements(); }); els.prev.addEventListener("click", function () { state.offset = Math.max(0, state.offset - state.limit); loadEntitlements(); }); els.next.addEventListener("click", function () { state.offset += state.limit; loadEntitlements(); });
    els.tableBody.addEventListener("click", function (event) { var button = event.target.closest("button[data-action]"); if (!button) return; handleAction(button.dataset.action, toInt(button.dataset.id), toInt(button.dataset.userId), false); }); els.memberEntitlements.addEventListener("click", function (event) { var button = event.target.closest("button[data-detail-action]"); if (!button) return; handleAction(button.dataset.detailAction, toInt(button.dataset.id), state.activeUserId, true); });
    els.actionModalElement.addEventListener("hidden.bs.modal", function () { var reopen = actionState.returnToDetail && !actionState.submitted, userId = actionState.userId; actionState.returnToDetail = false; if (reopen && userId) openDetail(userId); });
  }
  function init() {
    els = { message: byId("entitlementMessage"), search: byId("entitlementSearch"), lifecycle: byId("entitlementLifecycle"), source: byId("entitlementSource"), sort: byId("entitlementSort"), direction: byId("entitlementDirection"), limit: byId("entitlementLimit"), tableBody: byId("entitlementTableBody"), summary: byId("entitlementSummary"), prev: byId("entitlementPrev"), next: byId("entitlementNext"), page: byId("entitlementPage"), grantForm: byId("grantForm"), grantUserId: byId("grantUserId"), memberSearch: byId("memberSearch"), memberSearchBtn: byId("memberSearchBtn"), memberResults: byId("memberSearchResults"), selectedMember: byId("selectedMember"), grantKind: byId("grantKind"), grantPromoId: byId("grantPromoId"), grantStarts: byId("grantStarts"), grantDurationDays: byId("grantDurationDays"), grantExpires: byId("grantExpires"), grantNotes: byId("grantNotes"), grantReason: byId("grantReason"), confirmOverlap: byId("confirmOverlap"), checkOverlap: byId("checkOverlapBtn"), overlapResults: byId("overlapResults"), detailTitle: byId("memberDetailTitle"), memberSummary: byId("memberSummary"), effectiveAccess: byId("effectiveAccessSummary"), memberEntitlements: byId("memberEntitlementRows"), memberRedemptions: byId("memberRedemptionRows"), memberAudit: byId("memberAuditRows"), detailModalElement: byId("memberDetailModal"), actionModalElement: byId("entitlementActionModal"), actionForm: byId("entitlementActionForm"), actionId: byId("entitlementActionId"), actionUserId: byId("entitlementActionUserId"), actionTitle: byId("entitlementActionTitle"), actionContext: byId("entitlementActionContext"), actionError: byId("entitlementActionError"), actionExpiresWrap: byId("entitlementActionExpiresWrap"), actionExpires: byId("entitlementActionExpires"), actionNotesWrap: byId("entitlementActionNotesWrap"), actionNotes: byId("entitlementActionNotes"), actionConfirmationWrap: byId("entitlementActionConfirmationWrap"), actionConfirmation: byId("entitlementActionConfirmation"), actionConfirmationHint: byId("entitlementActionConfirmationHint"), actionReason: byId("entitlementActionReason"), actionSubmit: byId("entitlementActionSubmit") };
    grantModal = new window.bootstrap.Modal(byId("grantModal")); detailModal = new window.bootstrap.Modal(byId("memberDetailModal")); actionModal = new window.bootstrap.Modal(byId("entitlementActionModal")); bind(); loadEntitlements();
  }
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", init); else init();
})(window, document);

