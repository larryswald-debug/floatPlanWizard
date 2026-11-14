(function (window, document) {
  "use strict";
  window.FPW = window.FPW || {};
  var panel = null, draft = null, callbacks = {}, busy = false, dirty = false, saveRequestId = "", pendingSave = null, anotherRequestId = "", pendingDraftRequest = null;
  var BASE = window.FPW_BASE || "";
  var numericInputs = ["planning_speed_kn", "underway_burn_us_gph", "underway_hours_per_day", "reserve_pct", "idle_burn_us_gph", "idle_hours_total", "usable_fuel_us_gal"];
  function esc(value) { return String(value == null ? "" : value).replace(/[&<>"']/g, function (c) { return {"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]; }); }
  function number(value) { if (value === null || value === undefined || String(value).trim() === "") return null; var n = Number(value); return Number.isFinite(n) ? n : null; }
  function wire(value) {
    if (Array.isArray(value)) return value.map(wire);
    if (value && typeof value === "object") { var out = {}; Object.keys(value).forEach(function (key) { out[key.toLowerCase()] = wire(value[key]); }); return out; }
    return value;
  }
  function fmt(value, unit) { var n = number(value); return n === null ? "Not calculated" : n.toLocaleString(undefined, {minimumFractionDigits:1, maximumFractionDigits:1}) + (unit ? " " + unit : ""); }
  function time(value) { var n = number(value); if (n === null) return "Not calculated"; var minutes = Math.round(n * 60); return Math.floor(minutes / 60) + " h " + String(minutes % 60).padStart(2,"0") + " min"; }
  function uuid() { if (!window.crypto || typeof window.crypto.randomUUID !== "function") throw new Error("A current browser is required to save this trip."); return window.crypto.randomUUID(); }
  function api(action, body) {
    if (!window.Api || !window.Api.getAuthCsrfToken) return Promise.reject(new Error("Account access is unavailable. Refresh and try again."));
    return window.Api.getAuthCsrfToken().then(function (token) {
      return window.fetch(BASE + "/api/v1/routeBuilder.cfc?method=handle&action=" + encodeURIComponent(action), {
        method:"POST", credentials:"same-origin", headers:{"Content-Type":"application/json; charset=utf-8","X-CSRF-Token":token}, body:JSON.stringify(body || {})
      });
    }).then(function (response) {
      return response.json().then(function (payload) {
        if (!response.ok || !payload || payload.SUCCESS !== true) {
          var error = new Error(payload && (payload.MESSAGE || payload.ERROR && payload.ERROR.MESSAGE) || "The itinerary request could not be completed.");
          error.code = payload && payload.ERROR && payload.ERROR.CODE || "";
          throw error;
        }
        return wire(payload.DATA || {});
      });
    });
  }
  function track(name, data) {
    if (window.FPW_GUIDE_ANALYTICS_ENABLED !== true || !window.FPWAnalytics || !window.FPWAnalytics.track) return;
    window.FPWAnalytics.track(name, {template_key:data.template_key,template_version:data.template_version,outcome:"success"});
  }
  function showStatus(message, error) {
    var el = panel && panel.querySelector("[data-guide-status]");
    if (el) { el.textContent = message || ""; el.setAttribute("role", error ? "alert" : "status"); el.classList.toggle("fpw-guide-planner__error", !!error); }
  }
  function setBusy(value) {
    busy = value;
    if (panel) { panel.setAttribute("aria-busy", value ? "true" : "false"); panel.querySelectorAll("button").forEach(function (b) { b.disabled = value || (b.hasAttribute("data-guide-another") && draft && draft.can_create_another_copy === false); }); }
    syncFooter();
  }
  function inputMarkup(key, label, attrs) {
    var v = draft.planning_inputs && draft.planning_inputs[key];
    return '<label class="fpw-guide-planner__field" for="guide-' + key + '">' + label +
      '<input id="guide-' + key + '" name="' + key + '" data-guide-input="' + key + '" type="number" value="' + esc(v) + '" ' + attrs + ' class="form-control form-control-sm"></label>';
  }
  function current() {
    if (!draft || !panel) return null;
    var inputs = {};
    numericInputs.forEach(function (key) { var input = panel.querySelector('[data-guide-input="' + key + '"]'); inputs[key] = input ? number(input.value) : null; });
    inputs.reserve_mode = panel.querySelector("[data-guide-reserve]").value;
    inputs.start_date = panel.querySelector("[data-guide-date]").value;
    inputs.performance_confirmed = panel.querySelector("[data-guide-performance-confirmed]").checked;
    var legs = draft.legs.map(function (leg) {
      var row = panel.querySelector('[data-guide-leg="' + Number(leg.user_route_leg_id) + '"]');
      var nm = row ? number(row.querySelector("[data-guide-mileage]").value) : null;
      var method = row ? row.querySelector("[data-guide-method]").value.trim() : "";
      var changed = nm !== number(leg.distance_nm) || method !== String(leg.distance_method || "");
      return {user_route_leg_id:leg.user_route_leg_id,distance_nm:nm,distance_kind:nm === null ? "missing" : (changed ? "member_entered" : leg.distance_kind),
        distance_method:method,content_fingerprint:leg.content_fingerprint || "",review_action:""};
    });
    return {route_id:draft.user_route_id,revision:draft.revision,route_name:(document.getElementById("routeGenRouteName") || {}).value || draft.route_name || "",
      planning_inputs:inputs,trip_notes:panel.querySelector("[data-guide-notes]").value,legs:legs};
  }
  function totals(value) {
    var input = value.planning_inputs, speed = number(input.planning_speed_kn), burn = number(input.underway_burn_us_gph);
    var missing = value.legs.filter(function (leg) { return !(number(leg.distance_nm) > 0); }).length;
    var nm = value.legs.reduce(function (sum, leg) { return sum + (number(leg.distance_nm) > 0 ? number(leg.distance_nm) : 0); }, 0);
    var hours = speed > 0 ? nm / speed : null, cruise = hours !== null && burn > 0 ? hours * burn : null;
    var idleHours = number(input.idle_hours_total), idleBurn = number(input.idle_burn_us_gph);
    var idle = idleHours === 0 ? 0 : (idleHours > 0 && idleBurn !== null && idleBurn >= 0 ? idleHours * idleBurn : null);
    var base = cruise !== null && idle !== null ? cruise + idle : null;
    var reserve = base !== null && window.FPW.SharedFuelMath ? window.FPW.SharedFuelMath.reserveForBase(base,input.reserve_mode,input.reserve_pct) : null;
    if (input.reserve_mode === "percentage" && number(input.reserve_pct) === null) reserve = null;
    var required = base !== null && reserve !== null ? base + reserve : null;
    var missingMethods = value.legs.filter(function (leg) { return number(leg.distance_nm) > 0 && !String(leg.distance_method || "").trim(); }).length;
    var complete = !!value.legs.length && missing === 0 && missingMethods === 0 && speed > 0 && burn > 0 && number(input.underway_hours_per_day) > 0 && required !== null && input.performance_confirmed === true;
    var usable = number(input.usable_fuel_us_gal);
    return {complete:complete,missing:missing,missingMethods:missingMethods,nm:nm,hours:hours,cruise:cruise,base:base,reserve:reserve,required:required,margin:complete && usable !== null ? usable-required : null};
  }
  function updateTotals() {
    if (!panel || !draft) return;
    var value = current(), t = totals(value), box = panel.querySelector("[data-guide-totals]");
    box.innerHTML = '<h3>' + (t.complete ? "Trip estimates" : "Incomplete estimate — known-leg subtotals") + '</h3>' +
      '<dl class="fpw-guide-planner__totals"><div><dt>Planning distance</dt><dd>' + fmt(t.nm,"nm") + '</dd></div>' +
      '<div><dt>Underway time estimate</dt><dd>' + time(t.hours) + '</dd></div><div><dt>Underway fuel estimate</dt><dd>' + fmt(t.cruise,"US gal") + '</dd></div>' +
      '<div><dt>Reserve allowance</dt><dd>' + fmt(t.reserve,"US gal") + '</dd></div><div><dt>Fuel required estimate</dt><dd>' + fmt(t.required,"US gal") + '</dd></div>' +
      '<div><dt>Usable fuel above requirement</dt><dd>' + (t.complete ? fmt(t.margin,"US gal") : "Unavailable until inputs are complete") + '</dd></div></dl>' +
      '<p>' + (t.missing ? esc(t.missing + " leg(s) have missing mileage. These subtotals exclude those legs. ") : "") +
      (t.missingMethods ? esc(t.missingMethods + " leg(s) still need a mileage source or calculation method. ") : "") +
      (!value.planning_inputs.performance_confirmed ? "Confirm your explicit speed and consumption inputs. " : "") +
      (!value.planning_inputs.start_date ? "A planned start date is needed to save a trip. " : "") +
      'Time and fuel are estimates. Reserve is applied once to base consumption; local and weather days remain trip notes.</p>';
    panel.querySelectorAll("[data-guide-leg]").forEach(function (row) {
      var id = Number(row.getAttribute("data-guide-leg"));
      var original = draft.legs.find(function (leg) { return Number(leg.user_route_leg_id) === id; });
      var edited = value.legs.find(function (leg) { return Number(leg.user_route_leg_id) === id; });
      var changed = edited && original && (number(edited.distance_nm) !== number(original.distance_nm) || edited.distance_method !== String(original.distance_method || ""));
      var state = row.querySelector("[data-guide-review-state]");
      if (state) state.textContent = changed ? "Changed — member review required" : reviewLabel(original);
      var attribution = row.querySelector("[data-guide-distance-kind]");
      if (attribution && edited) attribution.textContent = distanceKindLabel(edited.distance_kind);
      var references = row.querySelector("[data-guide-source-references]");
      if (references) references.hidden = !!changed;
      var methodHint = row.querySelector("[data-guide-method-required]");
      if (methodHint) methodHint.hidden = !(edited && number(edited.distance_nm) > 0 && !edited.distance_method);
    });
    syncFooter();
  }
  function sourceReferences(leg) {
    var ids = Array.isArray(leg.source_ids) ? leg.source_ids : [];
    if (!ids.length) return "";
    var sources = draft.source_snapshot && (draft.source_snapshot.source_register_snapshot || draft.source_snapshot.sources) || [];
    if (!Array.isArray(sources)) sources = [];
    return '<details class="fpw-guide-planner__source" data-guide-source-references><summary>Copied source references (' + ids.length + ')</summary><ul>' + ids.map(function (id) {
      var source = sources.find(function (item) { return item.id === id; });
      if (!source) return '<li>' + esc(id) + '</li>';
      var url = /^https?:\/\//i.test(source.url || "") ? source.url : "";
      var label = esc(id + " · " + (source.authority || source.topic || "Source"));
      return '<li>' + (url ? '<a href="' + esc(url) + '" target="_blank" rel="noopener">' + label + '</a>' : label) +
        ' — accessed ' + esc(source.accessed_at || "date not recorded") + '; ' + esc(String(source.verification_status || "unresolved").replace(/_/g," ")) +
        (source.effective_date ? '<br>Source date/status: ' + esc(source.effective_date) : '') + '</li>';
    }).join("") + '</ul><p>Source retrieval records what was published. It does not confirm a safe route or current services.</p></details>';
  }
  function distanceKindLabel(kind) {
    return kind === "member_entered" ? "Member-entered estimate" : String(kind || "missing").replace(/_/g," ");
  }
  function reviewLabel(leg) {
    if (!leg || leg.distance_missing || !(number(leg.distance_nm) > 0)) return "Missing mileage — review required";
    if (leg.review_status === "member_confirmed") return "Member confirmed — not independently verified";
    if (leg.review_status === "member_replaced") return "Member replaced and reviewed — not independently verified";
    return "Member review required";
  }
  function syncFooter() {
    if (!draft) return;
    var draftButton = document.getElementById("routeGenSaveBtn"), tripButton = document.getElementById("routeGenGenerateBtn");
    if (draftButton) draftButton.disabled = busy;
    if (tripButton) tripButton.disabled = busy || !panel || !totals(current()).complete || !current().planning_inputs.start_date;
    ["routeGenMyRouteLoadBtn","routeGenResetBtn"].forEach(function (id) { var button=document.getElementById(id); if (button) button.disabled=busy; });
  }
  function render(data) {
    draft = wire(data); draft.legs = Array.isArray(draft.legs) ? draft.legs : [];
    draft.planning_inputs = draft.planning_inputs || {}; dirty = false;
    var checked = draft.planning_inputs.performance_confirmed === true ? " checked" : "";
    panel.innerHTML = '<header><p class="fpw-guide-planner__eyebrow">Personal guide itinerary · version ' + esc(draft.template_version) + '</p>' +
      '<h2 id="guideTripTitle">Review your planning estimates</h2><p>This personal copy keeps its original sources. Mileage, time and fuel are estimates. Member review does not independently verify a navigable route.</p><p><a href="' + BASE + '/boating-guides/bahamas/itineraries/fort-lauderdale-bimini/">Original worked example and sources</a></p></header>' +
      '<div data-guide-status role="status" aria-live="polite"></div>' +
      '<div class="fpw-guide-planner__inputs">' +
      inputMarkup("planning_speed_kn","Planning speed (knots)",'min="0.1" max="100" step="0.1"') +
      inputMarkup("underway_burn_us_gph","Total vessel underway consumption (US gal/h)",'min="0.1" max="10000" step="0.1"') +
      inputMarkup("underway_hours_per_day","Underway hours per day",'min="1" max="24" step="0.5"') +
      '<label class="fpw-guide-planner__field" for="guide-start-date">Planned start date<input id="guide-start-date" data-guide-date type="date" value="' + esc(draft.planning_inputs.start_date) + '" class="form-control form-control-sm"></label>' +
      '<label class="fpw-guide-planner__field" for="guide-reserve-mode">Reserve method<select id="guide-reserve-mode" data-guide-reserve class="form-select form-select-sm"><option value="percentage"' + (draft.planning_inputs.reserve_mode === "percentage" ? " selected" : "") + '>Percentage added to consumption</option><option value="thirds"' + (draft.planning_inputs.reserve_mode === "thirds" ? " selected" : "") + '>Thirds: reserve is 50% of consumption</option></select></label>' +
      inputMarkup("reserve_pct","Reserve percentage (percentage method)",'min="0" max="100" step="1"') +
      inputMarkup("idle_burn_us_gph","Idle consumption (US gal/h)",'min="0" max="10000" step="0.1"') +
      inputMarkup("idle_hours_total","Total idle hours",'min="0" max="10000" step="0.1"') +
      inputMarkup("usable_fuel_us_gal","Usable fuel aboard (US gal, optional)",'min="0" max="1000000" step="0.1"') + '</div>' +
      '<label class="fpw-guide-planner__confirmation"><input type="checkbox" data-guide-performance-confirmed' + checked + '> I confirm these speed and consumption inputs in knots and US gallons. They are not populated from my saved vessel.</label>' +
      '<section data-guide-totals aria-live="polite"></section>' +
      '<section aria-labelledby="guideTripLegsTitle"><h3 id="guideTripLegsTitle">Movement legs and member mileage review</h3><p>Record the source or calculation for each estimate. Leave unknown mileage empty. Confirm or replace every leg before entering the float-plan workflow.</p>' +
      draft.legs.map(function (leg, index) {
        var id = Number(leg.user_route_leg_id);
        return '<fieldset class="fpw-guide-planner__leg" data-guide-leg="' + id + '"><legend>' + esc((index+1) + ". " + leg.start_name + " → " + leg.end_name) + '</legend>' +
          '<p class="fpw-guide-planner__provenance"><span data-guide-distance-kind>' + esc(distanceKindLabel(leg.distance_kind)) + '</span> · ' + esc(leg.geometry_kind === "member_plotted" ? "Member-created geometry" : "Schematic connection; not a navigation track") + '</p>' +
          '<label for="guide-mileage-' + id + '">Planning mileage estimate (nm)<input id="guide-mileage-' + id + '" data-guide-mileage data-guide-previous-mileage="' + esc(leg.distance_nm) + '" type="number" min="0.01" max="100000" step="0.01" value="' + esc(leg.distance_nm) + '" class="form-control form-control-sm"></label>' +
          '<label for="guide-method-' + id + '">Source or calculation method<textarea id="guide-method-' + id + '" data-guide-method maxlength="2000" rows="2" class="form-control form-control-sm">' + esc(leg.distance_method) + '</textarea></label>' +
          '<p data-guide-method-required hidden>Record a new source or calculation method for this mileage before reviewing it. You can save this planning draft while the method is missing.</p>' +
          sourceReferences(leg) +
          (leg.distance_missing ? '<p>Missing input: ' + esc(leg.missing_input || "A defensible mileage estimate and its source or calculation for these endpoints.") + '</p>' : "") +
          '<p data-guide-review-state>' + esc(reviewLabel(leg)) + '</p>' +
          '<button type="button" class="btn-secondary btn-sm" data-guide-review="' + id + '">Confirm or replace this mileage</button></fieldset>';
      }).join("") + (draft.legs.length ? "" : '<p>No movement legs yet. Add an endpoint using the waypoint builder.</p>') + '</section>' +
      '<label class="fpw-guide-planner__field" for="guide-trip-notes">Trip notes: local days, weather allowance and confirmation tasks<textarea id="guide-trip-notes" data-guide-notes maxlength="12000" rows="7" class="form-control">' + esc(draft.trip_notes) + '</textarea></label>' +
      '<p>Notes do not add scheduled waiting days to the movement timeline. No plan is sent or activated by saving here.</p>' +
      '<div class="fpw-guide-planner__actions"><a class="btn-secondary btn-sm" data-guide-print href="' + BASE + '/app/guide-trip-print.cfm?routeId=' + Number(draft.user_route_id) + '" target="_blank" rel="noopener">Print saved planning summary</a>' +
      '<button type="button" class="btn-secondary btn-sm" data-guide-reload>Reload saved planning draft</button><button type="button" class="btn-secondary btn-sm" data-guide-another' + (draft.can_create_another_copy === false ? ' disabled aria-describedby="guideCopyAvailability"' : '') + '>Create another copy</button></div>' +
      (draft.can_create_another_copy === false ? '<p id="guideCopyAvailability">New imports are unavailable while this template is draft or retired. Your existing copy remains editable.</p>' : '');
    panel.hidden = false;
    updateTotals();
    if (draft.generated_route_instance_id) showStatus(draft.has_newer_draft ? "A newer planning draft is open. It has not replaced the last saved trip. Complete the inputs and Save trip to update that snapshot." : "This copy has a saved trip. Save trip after changes to update its saved estimates and review record.", false);
  }
  function saveDraft(reviewId) {
    if (!draft || busy) return Promise.resolve(null);
    var value = current(), row;
    pendingSave = null; saveRequestId = "";
    if (!panel.querySelector("input:invalid,textarea:invalid,select:invalid") && value) {
      if (reviewId) {
        row = value.legs.find(function (leg) { return Number(leg.user_route_leg_id) === Number(reviewId); });
        if (!row || !(row.distance_nm > 0) || !row.distance_method) { showStatus("Enter a positive mileage estimate and its source or calculation before confirming this leg.",true); return Promise.resolve(null); }
        var old = draft.legs.find(function (leg) { return Number(leg.user_route_leg_id) === Number(reviewId); });
        row.review_action = number(old.distance_nm) !== row.distance_nm || String(old.distance_method || "") !== row.distance_method ? "replace" : "confirm";
      }
    } else {
      var invalid = panel.querySelector(":invalid"); if (invalid) invalid.reportValidity();
      return Promise.resolve(null);
    }
    var requestHash = JSON.stringify(value);
    if (!pendingDraftRequest || pendingDraftRequest.hash !== requestHash) {
      pendingDraftRequest = {hash:requestHash,body:Object.assign({},value,{draft_request_id:uuid()})};
    }
    setBusy(true);
    showStatus("Saving planning draft…",false);
    return api("guide_savedraft",pendingDraftRequest.body).then(function (data) {
      pendingDraftRequest = null;
      render(data);
      if (callbacks.changed) callbacks.changed(data);
      track("guide_planning_draft_saved",data);
      showStatus(reviewId ? "Member mileage review recorded. This does not independently verify the route." : "Planning draft saved. Missing mileage and incomplete estimates are retained.",false);
      return data;
    }).catch(function (error) {
      showStatus(error.code === "GUIDE_REVISION_CONFLICT" ? "This itinerary changed in another tab. Reload the saved draft before reviewing or saving again." : error.message,true);
      return null;
    }).finally(function () { setBusy(false); });
  }
  function saveTrip() {
    if (!draft || busy) return Promise.resolve(null);
    var value = current();
    if (!totals(value).complete || !value.planning_inputs.start_date) {
      showStatus("Complete each mileage source, explicit performance input and planned start date before saving a trip. You can save a planning draft now.",true);
      return Promise.resolve(null);
    }
    // Retain the exact request across a lost response. A later edit starts a new save.
    var ready = pendingSave && !dirty ? Promise.resolve(draft) : saveDraft();
    return ready.then(function (saved) {
      if (!saved) return null;
      if (!pendingSave) {
        saveRequestId = uuid();
        pendingSave = {route_id:saved.user_route_id,revision:saved.revision,save_request_id:saveRequestId};
      }
      setBusy(true); showStatus("Saving trip estimates…",false);
      return api("guide_savetrip",pendingSave).then(function (data) {
        saveRequestId = ""; pendingSave = null;
        if (data.legs) render(data);
        if (callbacks.saved) callbacks.saved(data);
        track("guide_trip_saved",saved);
        showStatus("Trip saved. Review every leg's mileage before continuing into the float-plan workflow.",false);
        return data;
      }).catch(function (error) { showStatus(error.message + " Retry Save trip to reuse this save request.",true); return null; }).finally(function () { setBusy(false); });
    });
  }
  function refresh() {
    if (!draft || busy) return Promise.resolve(null);
    pendingSave = null; saveRequestId = ""; pendingDraftRequest = null;
    setBusy(true);
    var reload = callbacks.reload ? callbacks.reload() : api("guide_getdraft",{route_id:draft.user_route_id});
    return Promise.resolve(reload).then(function (data) { render(data); if (callbacks.changed) callbacks.changed(data); showStatus("Saved planning draft reloaded.",false); return data; })
      .catch(function (error) { showStatus(error.message,true); return null; }).finally(function () { setBusy(false); });
  }
  function importItinerary(context, another) {
    return api("guide_import",Object.assign({},context,{create_another:!!another})).then(function (data) {
      track("guide_template_loaded",data);
      return data;
    });
  }
  function initPanel() {
    panel = document.getElementById("guideTripPanel");
    if (!panel || panel.dataset.bound) return;
    panel.dataset.bound = "true";
    // Browser caret scrolling can leave a focused textarea beneath the panel edge.
    // Scroll its existing focus into view; never change focus during async hydration.
    panel.addEventListener("focusin",function (event) {
      var target = event.target;
      if (!target.matches("input,textarea,select,button,a")) return;
      window.requestAnimationFrame(function () {
        if (!draft || document.activeElement !== target || !panel.contains(target)) return;
        var scroller = target.closest(".rg-right-scroll");
        if (!scroller || window.getComputedStyle(scroller).overflowY === "visible" || scroller.scrollHeight <= scroller.clientHeight) scroller = target.closest(".rg-body");
        if (!scroller) return;
        var rect = target.getBoundingClientRect(), bounds = scroller.getBoundingClientRect();
        var above = rect.top - bounds.top - 18, below = rect.bottom - bounds.bottom + 18;
        if (above < 0 || rect.height > scroller.clientHeight - 36) scroller.scrollTop += above;
        else if (below > 0) scroller.scrollTop += below;
      });
    });
    panel.addEventListener("input",function (event) {
      dirty = true; saveRequestId = ""; pendingSave = null; pendingDraftRequest = null;
      if (event.target.matches("[data-guide-mileage]") && draft) {
        var legRow = event.target.closest("[data-guide-leg]");
        var methodInput = legRow && legRow.querySelector("[data-guide-method]");
        var previousMileage = number(event.target.dataset.guidePreviousMileage);
        var nextMileage = number(event.target.value);
        if (nextMileage !== previousMileage && methodInput) {
          methodInput.value = "";
          methodInput.placeholder = "Record the source or calculation for the mileage you entered.";
        }
        event.target.dataset.guidePreviousMileage = nextMileage === null ? "" : String(nextMileage);
      }
      if (event.target.matches('[data-guide-input="planning_speed_kn"],[data-guide-input="underway_burn_us_gph"]')) panel.querySelector("[data-guide-performance-confirmed]").checked = false;
      updateTotals();
    });
    panel.addEventListener("change",function () { dirty = true; saveRequestId = ""; pendingSave = null; pendingDraftRequest = null; updateTotals(); });
    panel.addEventListener("click",function (event) {
      var review = event.target.closest("[data-guide-review]");
      if (review) { saveDraft(Number(review.dataset.guideReview)); return; }
      if (event.target.closest("[data-guide-reload]")) { refresh(); return; }
      if (event.target.closest("[data-guide-print]") && dirty) { event.preventDefault(); showStatus("Save the planning draft before printing your latest changes.",true); return; }
      if (event.target.closest("[data-guide-another]")) {
        if (dirty) { showStatus("Save this planning draft before creating another copy.",true); return; }
        setBusy(true);
        if (!anotherRequestId) anotherRequestId = uuid();
        importItinerary({template_key:draft.template_key,template_version:draft.template_version,import_request_id:anotherRequestId},true)
          .then(function (data) { return callbacks.open ? callbacks.open(data.user_route_id) : null; })
          .then(function (opened) { if (opened === false) throw new Error("The copy was created but could not be opened. Retry to reopen it."); anotherRequestId = ""; })
          .catch(function (error) { showStatus(error.message + " Retry Create another copy to reuse this request.",true); }).finally(function () { setBusy(false); });
      }
    });
    var nameInput = document.getElementById("routeGenRouteName");
    if (nameInput) nameInput.addEventListener("input",function () { if (draft) { dirty = true; saveRequestId = ""; pendingSave = null; pendingDraftRequest = null; } });
    var root = document.getElementById("fpwRouteGen");
    if (root) root.addEventListener("click",function (event) {
      if (!draft || !dirty || !event.target.closest) return;
      var action = event.target.closest("[data-my-route-action],#routeGenMyRouteCreateBtn,#routeGenMyRouteDeleteBtn,#routeGenMyRouteSetStartBtn,#routeGenMyRouteAddWaypointLegBtn,#routeGenLegSaveBtn,#routeGenLegRevertBtn");
      if (action) { event.preventDefault(); event.stopImmediatePropagation(); showStatus("Save the planning draft before changing stops or geometry.",true); }
    },true);
  }
  window.FPW.GuidePlanner = {
    mount:function (data,handlers) { initPanel(); callbacks = handlers || {}; if (panel) render(data); },
    clear:function () { draft = null; dirty = false; saveRequestId = ""; pendingSave = null; anotherRequestId = ""; pendingDraftRequest = null; if (panel) { panel.hidden = true; panel.innerHTML = ""; } },
    isActive:function () { return !!draft; },
    isDirty:function () { return dirty; },
    preview:function () { updateTotals(); return Promise.resolve(draft); },
    saveDraft:saveDraft, saveTrip:saveTrip, refresh:refresh, importItinerary:importItinerary,
    calculate:totals, parseNumber:number
  };
})(window, document);
