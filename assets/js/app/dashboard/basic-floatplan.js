(function (window, document) {
  "use strict";

  window.FPW = window.FPW || {};
  window.FPW.DashboardModules = window.FPW.DashboardModules || {};

  var utils = window.FPW.DashboardUtils || {};
  var state = window.FPW.DashboardState || {};
  var BASE_PATH = window.FPW_BASE || "";
  var LAUNCH_TRIAL_PATH = BASE_PATH + "/app/start-trial.cfm?offer=launch_trial";
	  var TIMEZONES = [
    "UTC",
    "US/Eastern",
    "US/Central",
    "US/Mountain",
    "US/Pacific",
    "US/Alaska",
    "US/Hawaii",
    "America/Puerto_Rico",
    "America/Chicago",
    "America/Denver",
    "America/Los_Angeles",
    "America/New_York",
    "America/Phoenix",
    "America/Anchorage",
	    "Pacific/Honolulu"
	  ];
  var BASIC_LOCKED_PANEL_SELECTOR = "#vesselsPanel.fpw-basic-locked-panel, #operatorsPanel.fpw-basic-locked-panel, #contactsPanel.fpw-basic-locked-panel, #waypointsPanel.fpw-basic-locked-panel";

  var modal = null;
  var initialized = false;
  var basicMode = false;
  var panelContainer = null;
  var lastSentSummary = null;
  var draftState = {
    loaded: false,
    loading: false,
    current: null,
    latest: null,
    error: ""
  };
  var dom = {};

  function pick(obj, keys, fallback) {
    if (utils && typeof utils.pick === "function") {
      return utils.pick(obj, keys, fallback);
    }
    if (!obj) return fallback;
    for (var i = 0; i < keys.length; i += 1) {
      if (obj[keys[i]] !== undefined && obj[keys[i]] !== null && String(obj[keys[i]]).length) {
        return obj[keys[i]];
      }
    }
    return fallback;
  }

  function escapeHtml(value) {
    if (utils && typeof utils.escapeHtml === "function") {
      return utils.escapeHtml(value);
    }
    if (value === undefined || value === null) return "";
    return String(value)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
      .replace(/'/g, "&#39;");
  }

  function toInt(value) {
    var parsed = parseInt(value, 10);
    return Number.isFinite(parsed) ? parsed : 0;
  }

  function getMessage(error, fallback) {
    if (error && error.MESSAGE) return String(error.MESSAGE);
    if (error && error.message) return String(error.message);
    if (error && error.ERROR && error.ERROR.MESSAGE) return String(error.ERROR.MESSAGE);
    return fallback || "Request failed.";
  }

  function getErrorCode(error) {
    if (error && typeof error.ERROR === "string") return String(error.ERROR);
    if (error && typeof error.errorCode === "string") return String(error.errorCode);
    if (error && error.ERROR && error.ERROR.CODE) return String(error.ERROR.CODE);
    return "";
  }

  function getUsPhoneDigits(value) {
    var digits = String(value || "").replace(/\D/g, "");
    if (digits.length === 11 && digits.charAt(0) === "1") {
      digits = digits.substring(1);
    }
    return digits;
  }

  function formatUsPhoneInput(value) {
    var digits = getUsPhoneDigits(value).substring(0, 10);
    if (digits.length <= 3) return digits;
    if (digits.length <= 6) return "(" + digits.substring(0, 3) + ") " + digits.substring(3);
    return "(" + digits.substring(0, 3) + ") " + digits.substring(3, 6) + "-" + digits.substring(6);
  }

  function isValidOptionalUsPhone(value) {
    var raw = String(value || "").trim();
    if (!raw) return true;
    return getUsPhoneDigits(raw).length === 10;
  }

  function getTimeZoneOffset(timeZone, date) {
    if (!timeZone || !date) return 0;
    try {
      var formatter = new Intl.DateTimeFormat("en-US", {
        timeZone: timeZone,
        year: "numeric",
        month: "2-digit",
        day: "2-digit",
        hour: "2-digit",
        minute: "2-digit",
        second: "2-digit",
        hour12: false
      });
      var parts = formatter.formatToParts(date);
      var values = {};
      parts.forEach(function (part) {
        if (part.type !== "literal") {
          values[part.type] = part.value;
        }
      });
      return Date.UTC(
        parseInt(values.year, 10),
        parseInt(values.month, 10) - 1,
        parseInt(values.day, 10),
        parseInt(values.hour, 10),
        parseInt(values.minute, 10),
        parseInt(values.second, 10)
      ) - date.getTime();
    } catch (err) {
      return 0;
    }
  }

  function parseDateTimeInTimeZone(value, timeZone) {
    var raw = String(value || "").trim();
    var match = null;
    var utcDate = null;
    var offset = 0;
    if (!raw) return null;
    if (/^\d{4}-\d{2}-\d{2} \d{2}:\d{2}/.test(raw)) {
      raw = raw.replace(" ", "T");
    }
    match = raw.match(/^(\d{4})-(\d{2})-(\d{2})(?:T(\d{2}):(\d{2})(?::(\d{2}))?)?/);
    if (!match) {
      utcDate = new Date(raw);
      return Number.isNaN(utcDate.getTime()) ? null : utcDate;
    }
    utcDate = new Date(Date.UTC(
      parseInt(match[1], 10),
      parseInt(match[2], 10) - 1,
      parseInt(match[3], 10),
      parseInt(match[4] || "0", 10),
      parseInt(match[5] || "0", 10),
      parseInt(match[6] || "0", 10)
    ));
    if (!timeZone) return utcDate;
    offset = getTimeZoneOffset(timeZone, utcDate);
    return new Date(utcDate.getTime() - offset);
  }

  function toClientUtcIso(value, timeZone) {
    var parsed = parseDateTimeInTimeZone(value, timeZone);
    return parsed && !Number.isNaN(parsed.getTime()) ? parsed.toISOString() : "";
  }

  function showUpgradeMessage(message, tone) {
    var el = document.getElementById("basicPremiumUpgradeMessage");
    if (el) {
      el.textContent = message || "";
      el.classList.remove("fpw-basic-upgrade-message--error", "fpw-basic-upgrade-message--success");
      if (tone === "danger" || tone === "error") {
        el.classList.add("fpw-basic-upgrade-message--error");
      } else if (tone === "success") {
        el.classList.add("fpw-basic-upgrade-message--success");
      }
      return;
    }
    if (message && utils && typeof utils.showDashboardAlert === "function") {
      utils.showDashboardAlert(message, tone || "info");
    }
  }

  function setUpgradeButtonsBusy(isBusy) {
    var buttons = document.querySelectorAll("[data-basic-premium-upgrade]");
    Array.prototype.forEach.call(buttons, function (button) {
      button.disabled = !!isBusy;
      button.setAttribute("aria-disabled", isBusy ? "true" : "false");
    });
  }

  function getCheckoutUrl(payload) {
    return payload && (payload.checkoutUrl || payload.CHECKOUT_URL)
      ? String(payload.checkoutUrl || payload.CHECKOUT_URL)
      : "";
  }

  function startPremiumCheckout(interval, trigger) {
    var intervalValue = String(interval || "").trim().toLowerCase();
    if (intervalValue !== "monthly" && intervalValue !== "yearly") {
      showUpgradeMessage("Choose monthly or yearly Premium billing.", "danger");
      return;
    }
    setUpgradeButtonsBusy(true);
    if (trigger) {
      trigger.textContent = "Opening...";
    }
    showUpgradeMessage("Opening Premium free trial...", "info");
    window.location.href = LAUNCH_TRIAL_PATH;
  }

	  function cacheDom() {
    dom.modalEl = document.getElementById("basicFloatPlanModal");
    dom.form = document.getElementById("basicFloatPlanForm");
    dom.message = document.getElementById("basicFloatPlanMessage");
    dom.sentState = document.getElementById("basicFloatPlanSentState");
	    dom.planId = document.getElementById("basicFloatPlanId");
	    dom.planName = document.getElementById("basicPlanName");
	    dom.vesselName = document.getElementById("basicPlanVesselName");
	    dom.operatorName = document.getElementById("basicPlanOperatorName");
	    dom.captainName = document.getElementById("basicPlanCaptainName");
	    dom.email = document.getElementById("basicPlanEmail");
	    dom.authorityId = document.getElementById("basicAuthorityId");
	    dom.rescuePhone = document.getElementById("basicRescuePhone");
	    dom.departingFrom = document.getElementById("basicDepartingFrom");
	    dom.departureTime = document.getElementById("basicDepartureTime");
	    dom.departureTimezone = document.getElementById("basicDepartureTimezone");
	    dom.destination = document.getElementById("basicDestination");
	    dom.returnTime = document.getElementById("basicReturnTime");
	    dom.returnTimezone = document.getElementById("basicReturnTimezone");
	    dom.notes = document.getElementById("basicNotes");
	    dom.passengers = document.getElementById("basicPassengerOptions");
	    dom.contactName = document.getElementById("basicContactName");
	    dom.contactEmail = document.getElementById("basicContactEmail");
	    dom.contactPhone = document.getElementById("basicContactPhone");
    dom.contactError = document.getElementById("basicContactError");
    dom.saveBtn = document.getElementById("basicFloatPlanSaveBtn");
    dom.sendBtn = document.getElementById("basicFloatPlanSendBtn");
	    return !!(dom.modalEl && dom.form);
	  }

	  function setReusablePanelLocks(enabled) {
	    [
	      {
	        panelId: "vesselsPanel",
	        buttonId: "addVesselBtn",
	        message: "Basic float plans use one-time vessel details. Upgrade to Premium to save reusable vessels."
	      },
	      {
	        panelId: "operatorsPanel",
	        buttonId: "addOperatorBtn",
	        message: "Basic float plans use one-time operator details. Upgrade to Premium to save reusable operators."
	      },
	      {
	        panelId: "contactsPanel",
	        buttonId: "addContactBtn",
	        message: "Basic float plans use one-time notification contacts. Upgrade to Premium to save reusable contacts."
	      },
	      {
	        panelId: "waypointsPanel",
	        buttonId: "addWaypointBtn",
	        message: "Basic float plans use the destination field for one-time trip stops. Upgrade to Premium to save reusable waypoints."
	      }
	    ].forEach(function (item) {
	      var panel = document.getElementById(item.panelId);
	      var button = document.getElementById(item.buttonId);
	      var note = panel ? panel.querySelector("[data-basic-lock-note]") : null;
	      if (!panel) return;
	      panel.classList.toggle("fpw-basic-locked-panel", !!enabled);
	      panel.setAttribute("aria-disabled", enabled ? "true" : "false");
	      if (button) {
	        button.disabled = !!enabled;
	        button.setAttribute("aria-disabled", enabled ? "true" : "false");
	      }
	      if (enabled && !note) {
	        note = document.createElement("p");
	        note.className = "fpw-basic-lock-note";
	        note.setAttribute("data-basic-lock-note", "true");
	        note.textContent = item.message;
	        panel.appendChild(note);
	      } else if (!enabled && note) {
	        note.remove();
	      }
	    });
	  }

  function getLockedReusablePanel(target) {
    if (!basicMode || !target || !target.closest) return null;
    return target.closest(BASIC_LOCKED_PANEL_SELECTOR);
  }

  function blockLockedReusablePanelEvent(event, panel) {
    var note = panel ? panel.querySelector("[data-basic-lock-note]") : null;
    var message = note
      ? note.textContent
      : "Basic float plans use one-time details. Upgrade to Premium to manage reusable saved items.";
    event.preventDefault();
    event.stopPropagation();
    if (typeof event.stopImmediatePropagation === "function") {
      event.stopImmediatePropagation();
    }
    if (utils && typeof utils.showDashboardAlert === "function") {
      utils.showDashboardAlert(message, "warning");
    }
  }

	  function setBasicMode(enabled) {
    var title = document.getElementById("expeditionTimelineTitle");
    var subtitle = document.querySelector("#expeditionTimelinePanel .fpw-routes-workspace-subtitle");
    var openBtn = document.getElementById("openRouteBuilderBtn");
    basicMode = !!enabled;
    if (document.body) {
      document.body.classList.toggle("fpw-basic-member-mode", basicMode);
    }
    if (title) {
      title.textContent = basicMode ? "Basic Float Plan" : "Routes";
    }
    if (subtitle) {
      subtitle.textContent = basicMode
        ? "Create and send a one-day operational float plan without saving a reusable route."
        : "Create and manage your saved boating routes.";
    }
	    if (openBtn) {
      openBtn.classList.toggle("d-none", basicMode);
      if (basicMode) {
        openBtn.removeAttribute("data-basic-floatplan-open");
        openBtn.classList.remove("fpw-basic-open-btn");
        openBtn.setAttribute("aria-label", "Basic Float Plan actions are available in the Basic panel");
      } else {
        openBtn.textContent = "+ Create Route";
        openBtn.classList.remove("d-none");
        openBtn.removeAttribute("data-basic-floatplan-open");
        openBtn.classList.remove("fpw-basic-open-btn");
        openBtn.setAttribute("aria-label", "Create Route");
	      }
	    }
	    setReusablePanelLocks(basicMode);
	  }

  function formatDisplayDate(value) {
    if (!value) return "Not provided";
    var date = new Date(value);
    if (!Number.isNaN(date.getTime())) {
      return date.toLocaleString([], {
        month: "short",
        day: "numeric",
        hour: "numeric",
        minute: "2-digit"
      });
    }
    return String(value);
  }

  function getCurrentBasicPlan() {
    return draftState.current || draftState.latest || null;
  }

  function getBasicPlanState(plan) {
    return String((plan && (plan.STATE || plan.STATUS)) || "").trim().toLowerCase();
  }

  function buildPrimaryActionHtml() {
    var plan = getCurrentBasicPlan();
    if (plan && getBasicPlanState(plan) === "draft") {
      return '<button type="button" class="btn-primary" data-basic-floatplan-resume data-basic-floatplan-id="' + escapeHtml(plan.FLOATPLANID || "") + '">Resume Draft</button>';
    }
    if (plan && getBasicPlanState(plan) === "active") {
      return "";
    }
    return '<button type="button" class="btn-primary" data-basic-floatplan-open>Create Basic Float Plan</button>';
  }

  function buildDraftPanelHtml() {
    var draft = getCurrentBasicPlan();
    var planState = getBasicPlanState(draft);
    var waypointSummary = draft && draft.WAYPOINT_SUMMARY ? draft.WAYPOINT_SUMMARY : "";
    var downloadUrl = "";
    if (draftState.loading) {
      return ""
        + '<div class="fpw-basic-draft-card" role="status">'
        + '  <span class="fpw-basic-kicker">Basic float plan</span>'
        + '  <h4>Checking for Basic plans...</h4>'
        + '  <p>Looking for saved route-less Basic float plans and active Basic monitoring.</p>'
        + '</div>';
    }
    if (draftState.error) {
      return ""
        + '<div class="fpw-basic-draft-card" role="status">'
        + '  <span class="fpw-basic-kicker">Basic float plan</span>'
        + '  <h4>Draft lookup unavailable</h4>'
        + '  <p>' + escapeHtml(draftState.error) + '</p>'
        + '</div>';
    }
    if (!draft) return "";
    if (planState === "active") {
      if (window.Api && typeof window.Api.getBasicFloatPlanPdfDownloadUrl === "function") {
        downloadUrl = window.Api.getBasicFloatPlanPdfDownloadUrl(draft.FLOATPLANID || 0);
      }
      return ""
        + '<div class="fpw-basic-sent-card" role="status">'
        + '  <span class="fpw-basic-kicker">Basic monitoring active</span>'
        + '  <h4>' + escapeHtml(draft.NAME || "Basic Float Plan Sent") + '</h4>'
        + '  <p>Your one-day Basic float plan has been sent. Basic monitoring is active.</p>'
        + '  <dl>'
        + '    <div><dt>Departure</dt><dd>' + escapeHtml(draft.DEPARTING_FROM || "Not provided") + '</dd></div>'
        + '    <div><dt>Return</dt><dd>' + escapeHtml(draft.RETURNING_TO || "Not provided") + '</dd></div>'
        + '    <div><dt>Return Time</dt><dd>' + escapeHtml(formatDisplayDate(draft.RETURN_TIME)) + '</dd></div>'
        + '    <div><dt>Stops</dt><dd>' + escapeHtml(waypointSummary || ((draft.WAYPOINT_COUNT || 0) + " stop(s)")) + '</dd></div>'
        + '    <div><dt>Contacts</dt><dd>' + escapeHtml(draft.CONTACT_COUNT || 0) + '</dd></div>'
        + '    <div><dt>Monitoring</dt><dd>' + escapeHtml(draft.MONITORING_MODE || "basic") + '</dd></div>'
        + '  </dl>'
        + '  <div class="fpw-basic-draft-actions">'
        + (downloadUrl ? '    <a class="btn-secondary" href="' + escapeHtml(downloadUrl) + '" download>Download Float Plan PDF</a>' : '')
        + '    <button type="button" class="btn-secondary" data-basic-floatplan-close data-basic-floatplan-id="' + escapeHtml(draft.FLOATPLANID || "") + '">Close Basic Float Plan</button>'
        + '  </div>'
        + '  <p class="fpw-basic-upgrade-note">Upgrade to Premium for saved routes, Active Cruise, Follow Page sharing, multi-day trips, and advanced monitoring.</p>'
        + '</div>';
    }
    return ""
      + '<div class="fpw-basic-draft-card" role="status">'
      + '  <span class="fpw-basic-kicker">Saved draft</span>'
      + '  <h4>' + escapeHtml(draft.NAME || "Basic Float Plan Draft") + '</h4>'
      + '  <p>Your latest Basic draft is saved and ready to resume.</p>'
      + '  <dl>'
      + '    <div><dt>Departure</dt><dd>' + escapeHtml(draft.DEPARTING_FROM || "Not provided") + '</dd></div>'
      + '    <div><dt>Return</dt><dd>' + escapeHtml(draft.RETURNING_TO || "Not provided") + '</dd></div>'
      + '    <div><dt>Last Saved</dt><dd>' + escapeHtml(formatDisplayDate(draft.LAST_UPDATE)) + '</dd></div>'
	      + '    <div><dt>Stops</dt><dd>' + escapeHtml(waypointSummary || ((draft.WAYPOINT_COUNT || 0) + " stop(s)")) + '</dd></div>'
      + '    <div><dt>Contacts</dt><dd>' + escapeHtml(draft.CONTACT_COUNT || 0) + '</dd></div>'
      + '    <div><dt>Status</dt><dd>Draft</dd></div>'
      + '  </dl>'
      + '  <div class="fpw-basic-draft-actions">'
      + '    <button type="button" class="btn-primary" data-basic-floatplan-resume data-basic-floatplan-id="' + escapeHtml(draft.FLOATPLANID || "") + '">Resume Draft</button>'
      + (draft.IS_SENDABLE === false ? '' : '    <button type="button" class="btn-secondary" data-basic-floatplan-send-draft data-basic-floatplan-id="' + escapeHtml(draft.FLOATPLANID || "") + '">Send Float Plan</button>')
      + '  </div>'
      + '</div>';
  }

  function renderPanel(container, payload) {
    panelContainer = container || panelContainer;
    setBasicMode(true);
    if (!panelContainer) return;
    panelContainer.innerHTML = ""
      + '<article class="fpw-basic-floatplan-panel">'
      + '  <div class="fpw-basic-floatplan-main">'
      + '    <span class="fpw-basic-kicker">Basic member flow</span>'
      + '    <h3>Basic Float Plan</h3>'
	      + '    <p>Create a simple one-day float plan with up to 2 saved waypoints. Perfect for sandbar trips, lunch runs, fishing trips, and getting back before dark.</p>'
      + '    <div class="fpw-basic-action-row">'
      + '      ' + buildPrimaryActionHtml()
      + '    </div>'
      + '  </div>'
      + '  <aside class="fpw-basic-upgrade-card" aria-label="Premium upgrade information">'
      + '    <h4>Premium unlocks route-first cruising</h4>'
      + '    <ul>'
      + '      <li>Saved routes and My Routes</li>'
      + '      <li>Multi-day trips and expanded waypoints</li>'
      + '      <li>Active Cruise and Follow Page sharing</li>'
      + '      <li>Advanced monitoring</li>'
      + '    </ul>'
      + '    <div class="fpw-basic-draft-actions fpw-basic-upgrade-actions">'
      + '      <button type="button" class="btn-primary" data-basic-premium-upgrade="monthly">Upgrade Monthly</button>'
      + '      <button type="button" class="btn-secondary" data-basic-premium-upgrade="yearly">Upgrade Yearly</button>'
      + '    </div>'
      + '    <p id="basicPremiumUpgradeMessage" class="fpw-basic-upgrade-note" aria-live="polite"></p>'
      + '  </aside>'
      + buildDraftPanelHtml()
      + (lastSentSummary ? buildSentPanelHtml(lastSentSummary) : "")
      + '</article>';

    if (!draftState.loaded && !draftState.loading) {
      loadDraftsForPanel();
    }
  }

  function loadDraftsForPanel() {
    if (!window.Api || typeof window.Api.getBasicFloatPlanCurrent !== "function") {
      draftState.loaded = true;
      draftState.loading = false;
      draftState.current = null;
      draftState.latest = null;
      draftState.error = "Basic draft lookup is unavailable.";
      if (panelContainer) renderPanel(panelContainer);
      return;
    }
    draftState.loading = true;
    draftState.error = "";
    window.Api.getBasicFloatPlanCurrent()
      .then(function (payload) {
        if (!payload || payload.SUCCESS !== true) {
          throw payload || { MESSAGE: "Unable to load Basic float plan state." };
        }
        draftState.current = payload.HAS_BASIC_PLAN ? (payload.BASIC_PLAN || null) : null;
        draftState.latest = (payload.STATE === "draft") ? draftState.current : null;
        draftState.loaded = true;
      })
      .catch(function (err) {
        draftState.current = null;
        draftState.latest = null;
        draftState.error = getMessage(err, "Unable to load Basic float plan state.");
        draftState.loaded = true;
      })
      .finally(function () {
        draftState.loading = false;
        if (panelContainer) renderPanel(panelContainer);
      });
  }

  function buildSentPanelHtml(summary) {
    return ""
      + '<div class="fpw-basic-sent-card" role="status">'
      + '  <span class="fpw-basic-kicker">Basic monitoring active</span>'
      + '  <h4>Basic Float Plan Sent</h4>'
      + '  <p>Your one-day float plan has been sent. Basic monitoring is active.</p>'
      + '  <dl>'
      + '    <div><dt>Departure</dt><dd>' + escapeHtml(summary.departure || "Not provided") + '</dd></div>'
      + '    <div><dt>Return</dt><dd>' + escapeHtml(summary.returning || "Not provided") + '</dd></div>'
      + '    <div><dt>Monitoring</dt><dd>Basic</dd></div>'
      + '  </dl>'
      + '</div>';
  }

  function populateTimezones() {
    var detected = "";
    try {
      detected = Intl.DateTimeFormat().resolvedOptions().timeZone || "";
    } catch (err) {
      detected = "";
    }
    if (detected && TIMEZONES.indexOf(detected) === -1) {
      TIMEZONES.push(detected);
    }
    [dom.departureTimezone, dom.returnTimezone].forEach(function (selectEl) {
      if (!selectEl) return;
      selectEl.innerHTML = '<option value="">Select timezone</option>' + TIMEZONES.map(function (tz) {
        return '<option value="' + escapeHtml(tz) + '">' + escapeHtml(tz) + '</option>';
      }).join("");
      if (detected) {
        selectEl.value = detected;
      }
    });
  }

  function formatDateTimeLocal(dateValue) {
    var date = dateValue instanceof Date ? dateValue : new Date();
    var pad = function (value) { return String(value).padStart(2, "0"); };
    return date.getFullYear() + "-"
      + pad(date.getMonth() + 1) + "-"
      + pad(date.getDate()) + "T"
      + pad(date.getHours()) + ":"
      + pad(date.getMinutes());
  }

  function setDefaultValues() {
    var now = new Date();
    var depart = new Date(now.getTime() + 60 * 60 * 1000);
    var ret = new Date(now.getTime() + 8 * 60 * 60 * 1000);
    var user = state.currentUser || {};
    var profile = user.PROFILE || user.profile || {};
	    if (dom.planId) dom.planId.value = "0";
	    if (dom.planName) dom.planName.value = "Basic Float Plan - " + now.toLocaleDateString();
	    if (dom.vesselName) dom.vesselName.value = "";
	    if (dom.operatorName) dom.operatorName.value = "";
	    if (dom.captainName) dom.captainName.value = "";
	    if (dom.email) dom.email.value = pick(user, ["EMAIL", "email", "USERNAME", "username"], pick(profile, ["EMAIL", "email"], ""));
	    if (dom.departureTime) dom.departureTime.value = formatDateTimeLocal(depart);
	    if (dom.returnTime) dom.returnTime.value = formatDateTimeLocal(ret);
	    if (dom.departingFrom) dom.departingFrom.value = "";
	    if (dom.destination) dom.destination.value = "";
	    if (dom.authorityId) dom.authorityId.value = "";
	    if (dom.rescuePhone) dom.rescuePhone.value = "";
	    if (dom.contactName) dom.contactName.value = "";
	    if (dom.contactEmail) dom.contactEmail.value = "";
	    if (dom.contactPhone) dom.contactPhone.value = "";
	    if (dom.notes) dom.notes.value = "";
  }

  function currentList(stateKey) {
    var bucket = state[stateKey] || {};
    return Array.isArray(bucket.all) ? bucket.all : [];
  }

  function storeList(stateKey, list) {
    state[stateKey] = state[stateKey] || {};
    state[stateKey].all = Array.isArray(list) ? list : [];
  }

  function ensureList(stateKey, apiFn, responseKeys) {
    var existing = currentList(stateKey);
    if (existing.length) return Promise.resolve(existing);
    if (!apiFn) return Promise.resolve([]);
    return apiFn({ limit: 200 }).then(function (data) {
      var list = [];
      if (utils.ensureAuthResponse && !utils.ensureAuthResponse(data)) {
        return [];
      }
      if (!data || data.SUCCESS !== true) {
        throw data || { MESSAGE: "Unable to load dashboard data." };
      }
      for (var i = 0; i < responseKeys.length; i += 1) {
        if (Array.isArray(data[responseKeys[i]])) {
          list = data[responseKeys[i]];
          break;
        }
      }
      storeList(stateKey, list);
      return list;
    });
  }

	  function renderSelect(selectEl, list, idKeys, labelKeys, emptyText) {
    if (!selectEl) return;
    if (!list.length) {
      selectEl.innerHTML = '<option value="">' + escapeHtml(emptyText) + '</option>';
      return;
    }
    selectEl.innerHTML = '<option value="">Select</option>' + list.map(function (item) {
      var id = pick(item, idKeys, "");
      var label = pick(item, labelKeys, "Unnamed");
      return '<option value="' + escapeHtml(id) + '">' + escapeHtml(label) + '</option>';
	    }).join("");
	  }

	  function renderAuthoritySelect(list) {
	    if (!dom.authorityId) return;
	    if (!list.length) {
	      dom.authorityId.innerHTML = '<option value="">No authorities available</option>';
	      return;
	    }
	    dom.authorityId.innerHTML = '<option value="">Select official emergency authority</option>' + list.map(function (item) {
	      var id = pick(item, ["AUTHORITY_ID", "authorityId", "ID"], "");
	      var name = pick(item, ["NAME", "name"], "Unnamed authority");
	      var phone = pick(item, ["PHONE", "phone"], "");
	      var area = pick(item, ["AREA", "area", "LOCATION", "location"], "");
	      var label = name + (area ? " - " + area : "");
	      return '<option value="' + escapeHtml(id) + '" data-phone="' + escapeHtml(phone) + '">' + escapeHtml(label) + '</option>';
	    }).join("");
	    updateAuthorityPhone();
	  }

	  function updateAuthorityPhone() {
	    var selected = dom.authorityId && dom.authorityId.selectedOptions && dom.authorityId.selectedOptions.length
	      ? dom.authorityId.selectedOptions[0]
	      : null;
	    if (dom.rescuePhone) {
	      dom.rescuePhone.value = selected ? (selected.getAttribute("data-phone") || "") : "";
	    }
	  }

  function renderCheckboxList(container, list, idKeys, labelKeys, name, emptyText, extraLabelFn) {
    if (!container) return;
    if (!list.length) {
      container.innerHTML = '<p class="fpw-basic-options-empty">' + escapeHtml(emptyText) + '</p>';
      return;
    }
    container.innerHTML = list.map(function (item, index) {
      var id = pick(item, idKeys, "");
      var label = pick(item, labelKeys, "Unnamed");
      var extra = typeof extraLabelFn === "function" ? extraLabelFn(item) : "";
      var disabled = extra && extra.indexOf("No email") !== -1 ? " disabled" : "";
      return ""
        + '<label class="fpw-basic-option">'
        + '  <input type="checkbox" name="' + escapeHtml(name) + '" value="' + escapeHtml(id) + '" data-label="' + escapeHtml(label) + '"' + disabled + '>'
        + '  <span><strong>' + escapeHtml(label) + '</strong>' + (extra ? '<small>' + escapeHtml(extra) + '</small>' : '') + '</span>'
        + '</label>';
    }).join("");
  }

	  function loadFormData() {
    if (!window.Api) {
      return Promise.reject({ MESSAGE: "Dashboard API is unavailable." });
    }
	    setMessage("Loading Basic float plan options...", "info");
	    return Promise.all([
	      ensureList("passengerState", window.Api.getPassengers, ["PASSENGERS", "passengers"]),
	      ensureList("basicAuthorityState", window.Api.getBasicRescueAuthorities, ["AUTHORITIES", "authorities"])
	    ]).then(function (lists) {
	      renderCheckboxList(dom.passengers, lists[0], ["PASSENGERID", "ID"], ["PASSENGERNAME", "NAME"], "basicPassenger", "No passengers saved");
	      renderAuthoritySelect(lists[1]);
	      setMessage("", "info");
	      return lists;
	    });
	  }

  function normalizeDateTimeInput(value) {
    if (!value) return "";
    var raw = String(value);
    var date = new Date(raw);
    if (!Number.isNaN(date.getTime())) {
      return formatDateTimeLocal(date);
    }
    if (/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}/.test(raw)) {
      return raw.substring(0, 16);
    }
    if (/^\d{4}-\d{2}-\d{2} \d{2}:\d{2}/.test(raw)) {
      return raw.replace(" ", "T").substring(0, 16);
    }
    return raw;
  }

  function setValue(field, value) {
    if (!field) return;
    field.value = value === undefined || value === null ? "" : String(value);
  }

  function selectionIds(list, keys) {
    if (!Array.isArray(list)) return [];
    return list.map(function (item) {
      return String(toInt(pick(item, keys, 0)));
    }).filter(function (id) {
      return id !== "0";
    });
  }

  function setCheckedValues(name, ids) {
    var idMap = {};
    var inputs = dom.form ? dom.form.querySelectorAll('input[name="' + name + '"]') : [];
    ids.forEach(function (id) {
      idMap[String(id)] = true;
    });
    Array.prototype.forEach.call(inputs, function (input) {
      input.checked = !!idMap[String(input.value)];
    });
  }

	  function hydrateDraft(payload) {
	    var plan = payload && payload.FLOATPLAN ? payload.FLOATPLAN : {};
	    var details = payload && payload.BASIC_DETAILS ? payload.BASIC_DETAILS : {};
	    setValue(dom.planId, pick(plan, ["FLOATPLANID", "floatPlanId"], "0"));
	    setValue(dom.planName, pick(plan, ["NAME", "floatPlanName"], ""));
	    setValue(dom.vesselName, pick(details, ["VESSEL_NAME", "vesselName"], ""));
	    setValue(dom.operatorName, pick(details, ["OPERATOR_NAME", "operatorName"], ""));
	    setValue(dom.captainName, pick(details, ["CAPTAIN_NAME", "captainName"], ""));
	    setValue(dom.email, pick(details, ["CAPTAIN_EMAIL", "captainEmail"], pick(plan, ["EMAIL", "email"], "")));
	    setValue(dom.authorityId, pick(details, ["AUTHORITY_ID", "authorityId"], pick(plan, ["RESCUE_CENTERID", "rescueCenterId"], "")));
	    updateAuthorityPhone();
	    if (dom.rescuePhone && !dom.rescuePhone.value) {
	      setValue(dom.rescuePhone, pick(details, ["AUTHORITY_PHONE_SNAPSHOT", "authorityPhoneSnapshot"], pick(plan, ["RESCUE_AUTHORITY_PHONE", "rescueAuthorityPhone"], "")));
	    }
	    setValue(dom.departingFrom, pick(details, ["LAUNCH_LOCATION", "launchLocation"], pick(plan, ["DEPARTING_FROM", "departingFrom"], "")));
	    setValue(dom.departureTime, normalizeDateTimeInput(pick(plan, ["DEPARTURE_TIME", "departureTime"], "")));
	    setValue(dom.departureTimezone, pick(plan, ["DEPARTURE_TIMEZONE", "departureTimezone"], ""));
	    setValue(dom.destination, pick(details, ["DESTINATION_LOCATION", "destinationLocation"], pick(plan, ["RETURNING_TO", "returningTo"], "")));
	    setValue(dom.returnTime, normalizeDateTimeInput(pick(plan, ["RETURN_TIME", "returnTime"], "")));
	    setValue(dom.returnTimezone, pick(plan, ["RETURN_TIMEZONE", "returnTimezone"], ""));
	    setValue(dom.notes, pick(plan, ["NOTES", "notes"], ""));
	    setValue(dom.contactName, pick(details, ["NOTIFICATION_CONTACT_NAME", "notificationContactName"], ""));
	    setValue(dom.contactEmail, pick(details, ["NOTIFICATION_CONTACT_EMAIL", "notificationContactEmail"], ""));
	    setValue(dom.contactPhone, formatUsPhoneInput(pick(details, ["NOTIFICATION_CONTACT_PHONE", "notificationContactPhone"], "")));
	    setCheckedValues("basicPassenger", selectionIds(payload.PLAN_PASSENGERS, ["PASSENGERID", "passengerId"]));
	  }

  function setMessage(message, type) {
    if (!dom.message) return;
    dom.message.textContent = message || "";
    dom.message.classList.add("d-none");
    dom.message.classList.remove("alert-success", "alert-danger", "alert-warning", "alert-info");
    if (!message) return;
    dom.message.classList.remove("d-none");
    dom.message.classList.add("alert-" + (type || "info"));
  }

  function setSaving(isSaving, actionLabel) {
    if (dom.saveBtn) {
      dom.saveBtn.disabled = !!isSaving;
      dom.saveBtn.textContent = isSaving && actionLabel === "save" ? "Saving..." : "Save Draft";
    }
    if (dom.sendBtn) {
      dom.sendBtn.disabled = !!isSaving;
      dom.sendBtn.textContent = isSaving && actionLabel === "send" ? "Sending..." : "Save & Send";
    }
  }

  function clearValidation() {
    var fields = dom.form ? dom.form.querySelectorAll(".is-invalid") : [];
    for (var i = 0; i < fields.length; i += 1) {
      fields[i].classList.remove("is-invalid");
    }
    if (dom.contactError) {
      dom.contactError.classList.add("d-none");
    }
  }

  function markInvalid(field) {
    if (field) {
      field.classList.add("is-invalid");
    }
  }

  function selectedCheckboxes(name) {
    if (!dom.form) return [];
    return Array.prototype.slice.call(dom.form.querySelectorAll('input[name="' + name + '"]:checked:not(:disabled)'));
  }

  function validateForm() {
    var valid = true;
    var departureDate = null;
    var returnDate = null;
    clearValidation();

	    [
	      dom.planName,
	      dom.vesselName,
	      dom.operatorName,
	      dom.captainName,
	      dom.email,
	      dom.authorityId,
	      dom.departingFrom,
	      dom.destination,
	      dom.departureTime,
	      dom.departureTimezone,
	      dom.returnTime,
	      dom.returnTimezone,
	      dom.contactName,
	      dom.contactEmail
	    ].forEach(function (field) {
      if (!field || !String(field.value || "").trim()) {
        markInvalid(field);
        valid = false;
      }
    });

	    if (dom.email && dom.email.value && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(dom.email.value.trim())) {
	      markInvalid(dom.email);
	      valid = false;
	    }
	    if (dom.contactEmail && dom.contactEmail.value && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(dom.contactEmail.value.trim())) {
	      markInvalid(dom.contactEmail);
	      valid = false;
	    }
	    if (dom.contactPhone && dom.contactPhone.value.trim() && !isValidOptionalUsPhone(dom.contactPhone.value)) {
	      markInvalid(dom.contactPhone);
	      if (dom.contactError) {
	        dom.contactError.textContent = "Enter a notification contact name, valid email, and a valid US phone number.";
	        dom.contactError.classList.remove("d-none");
	      }
	      valid = false;
	    }

    if (dom.departureTime && dom.returnTime && dom.departureTime.value && dom.returnTime.value) {
      departureDate = new Date(dom.departureTime.value);
      returnDate = new Date(dom.returnTime.value);
      if (
        Number.isNaN(departureDate.getTime())
        || Number.isNaN(returnDate.getTime())
        || returnDate.getTime() <= departureDate.getTime()
        || (returnDate.getTime() - departureDate.getTime()) > 24 * 60 * 60 * 1000
      ) {
        markInvalid(dom.returnTime);
        valid = false;
      }
    }

	    if (!dom.contactName || !dom.contactName.value.trim() || !dom.contactEmail || !dom.contactEmail.value.trim()) {
	      if (dom.contactError) {
	        dom.contactError.textContent = "Enter a notification contact name and valid email.";
	        dom.contactError.classList.remove("d-none");
	      }
      valid = false;
    }

    if (!valid && !dom.message.textContent) {
      setMessage("Please complete the required Basic float plan fields.", "warning");
    }
    return valid;
  }

  function buildPayload() {
    var departureTime = dom.departureTime ? dom.departureTime.value : "";
    var departureTimezone = dom.departureTimezone ? dom.departureTimezone.value : "";
    var returnTime = dom.returnTime ? dom.returnTime.value : "";
    var returnTimezone = dom.returnTimezone ? dom.returnTimezone.value : "";

    return {
      action: "savebasic",
	      FLOATPLAN: {
	        FLOATPLANID: toInt(dom.planId ? dom.planId.value : 0),
	        NAME: dom.planName ? dom.planName.value.trim() : "",
	        VESSELID: 0,
	        OPERATORID: 0,
	        OPERATOR_HAS_PFD: true,
	        EMAIL: dom.email ? dom.email.value.trim() : "",
	        RESCUE_CENTERID: toInt(dom.authorityId ? dom.authorityId.value : 0),
	        DEPARTING_FROM: dom.departingFrom ? dom.departingFrom.value.trim() : "",
	        DEPARTURE_TIME: departureTime,
	        DEPARTURE_TIMEZONE: departureTimezone,
	        DEPARTURE_TIME_UTC: toClientUtcIso(departureTime, departureTimezone),
	        RETURNING_TO: dom.departingFrom ? dom.departingFrom.value.trim() : "",
	        RETURN_TIME: returnTime,
	        RETURN_TIMEZONE: returnTimezone,
	        RETURN_TIME_UTC: toClientUtcIso(returnTime, returnTimezone),
        FOOD_DAYS_PER_PERSON: "1",
        WATER_DAYS_PER_PERSON: "1",
	        ROUTE_INSTANCE_ID: 0,
	        NOTES: dom.notes ? dom.notes.value.trim() : ""
	      },
	      BASIC_DETAILS: {
	        VESSEL_NAME: dom.vesselName ? dom.vesselName.value.trim() : "",
	        OPERATOR_NAME: dom.operatorName ? dom.operatorName.value.trim() : "",
	        CAPTAIN_NAME: dom.captainName ? dom.captainName.value.trim() : "",
	        CAPTAIN_EMAIL: dom.email ? dom.email.value.trim() : "",
	        NOTIFICATION_CONTACT_NAME: dom.contactName ? dom.contactName.value.trim() : "",
	        NOTIFICATION_CONTACT_EMAIL: dom.contactEmail ? dom.contactEmail.value.trim() : "",
	        NOTIFICATION_CONTACT_PHONE: dom.contactPhone ? formatUsPhoneInput(dom.contactPhone.value).trim() : "",
	        LAUNCH_LOCATION: dom.departingFrom ? dom.departingFrom.value.trim() : "",
	        DESTINATION_LOCATION: dom.destination ? dom.destination.value.trim() : "",
	        AUTHORITY_ID: toInt(dom.authorityId ? dom.authorityId.value : 0)
	      },
	      PASSENGERS: selectedCheckboxes("basicPassenger").map(function (input) {
	        return { PASSENGERID: toInt(input.value), HAS_PFD: true };
	      }),
	      CONTACTS: [],
	      WAYPOINTS: []
    };
  }

  function saveDraft() {
    if (!validateForm()) {
      return Promise.reject({ MESSAGE: "Basic float plan validation failed." });
    }
    setSaving(true, "save");
    setMessage("Saving Basic float plan draft...", "info");
    return window.Api.saveBasicFloatPlan(buildPayload())
      .then(function (payload) {
        if (!payload || payload.SUCCESS !== true) {
          throw payload || { MESSAGE: "Unable to save Basic float plan." };
        }
        if (dom.planId) {
          dom.planId.value = payload.FLOATPLANID || payload.floatPlanId || payload.FLOATPLAN_ID || "0";
        }
        draftState.loaded = false;
        draftState.current = null;
        draftState.latest = null;
        if (panelContainer) {
          loadDraftsForPanel();
        }
        setMessage("Basic float plan draft saved.", "success");
        return payload;
      })
      .catch(function (err) {
        setMessage(getMessage(err, "Unable to save Basic float plan."), "danger");
        throw err;
      })
      .finally(function () {
        setSaving(false, "save");
      });
  }

  function showSentState(payload) {
    lastSentSummary = null;
    if (dom.form) dom.form.classList.add("d-none");
    if (dom.sentState) dom.sentState.classList.remove("d-none");
    if (dom.saveBtn) dom.saveBtn.classList.add("d-none");
    if (dom.sendBtn) dom.sendBtn.classList.add("d-none");
    draftState.loaded = false;
    draftState.current = null;
    draftState.latest = null;
    setMessage(getMessage(payload, "Basic float plan sent. Basic monitoring is active."), "success");
    if (panelContainer) {
      loadDraftsForPanel();
    }
  }

  function saveAndSend() {
    var planId = 0;
    if (!validateForm()) return;
    setSaving(true, "send");
    setMessage("Saving and sending Basic float plan...", "info");
    window.Api.saveBasicFloatPlan(buildPayload())
      .then(function (payload) {
        if (!payload || payload.SUCCESS !== true) {
          throw payload || { MESSAGE: "Unable to save Basic float plan." };
        }
        planId = toInt(payload.FLOATPLANID || payload.floatPlanId || payload.FLOATPLAN_ID || 0);
        if (dom.planId) dom.planId.value = planId;
        if (planId <= 0) {
          throw { MESSAGE: "Saved Basic float plan id is unavailable." };
        }
        return window.Api.sendBasicFloatPlan(planId);
      })
      .then(function (payload) {
        if (!payload || payload.SUCCESS !== true) {
          throw payload || { MESSAGE: "Unable to send Basic float plan." };
        }
        showSentState(payload);
        if (window.FPWAnalytics && typeof window.FPWAnalytics.track === "function") {
          window.FPWAnalytics.track("float_plan_created", {
            plan_type: "basic",
            source: "basic_float_plan",
            sent: true
          });
          window.FPWAnalytics.track("active_cruise_started", {
            plan_type: "basic",
            source: "basic_float_plan"
          });
        }
      })
      .catch(function (err) {
        setMessage(getMessage(err, "Unable to send Basic float plan."), "danger");
      })
      .finally(function () {
        setSaving(false, "send");
      });
  }

  function sendSavedDraft(trigger, draftId) {
    var planId = toInt(draftId);
    var originalText = trigger ? trigger.textContent : "";
    if (planId <= 0 || !window.Api || typeof window.Api.sendBasicFloatPlan !== "function") {
      draftState.error = "Saved Basic draft cannot be sent from this page.";
      if (panelContainer) renderPanel(panelContainer);
      return;
    }
    if (trigger) {
      trigger.disabled = true;
      trigger.textContent = "Sending...";
    }
    window.Api.sendBasicFloatPlan(planId)
      .then(function (payload) {
        if (!payload || payload.SUCCESS !== true) {
          throw payload || { MESSAGE: "Unable to send Basic float plan." };
        }
        lastSentSummary = null;
        draftState.loaded = false;
        draftState.current = null;
        draftState.latest = null;
        loadDraftsForPanel();
        if (window.FPWAnalytics && typeof window.FPWAnalytics.track === "function") {
          window.FPWAnalytics.track("float_plan_created", {
            plan_type: "basic",
            source: "basic_saved_draft",
            sent: true
          });
          window.FPWAnalytics.track("active_cruise_started", {
            plan_type: "basic",
            source: "basic_saved_draft"
          });
        }
      })
      .catch(function (err) {
        draftState.error = getMessage(err, "Unable to send Basic float plan.");
        draftState.loaded = true;
        if (panelContainer) renderPanel(panelContainer);
      })
      .finally(function () {
        if (trigger) {
          trigger.disabled = false;
          trigger.textContent = originalText || "Send Float Plan";
        }
      });
  }

  function closeBasicPlan(trigger, draftId) {
    var planId = toInt(draftId);
    var originalText = trigger ? trigger.textContent : "";
    if (planId <= 0 || !window.Api || typeof window.Api.closeBasicFloatPlan !== "function") {
      draftState.error = "Active Basic float plan cannot be closed from this page.";
      draftState.loaded = true;
      if (panelContainer) renderPanel(panelContainer);
      return;
    }
    if (!window.confirm("Close this Basic Float Plan? This will end basic monitoring for this trip. You can create a new Basic Float Plan after this one is closed.")) {
      return;
    }
    if (trigger) {
      trigger.disabled = true;
      trigger.textContent = "Closing...";
    }
    window.Api.closeBasicFloatPlan(planId)
      .then(function (payload) {
        if (!payload || payload.SUCCESS !== true) {
          throw payload || { MESSAGE: "Unable to close Basic float plan." };
        }
        lastSentSummary = null;
        draftState.loaded = false;
        draftState.current = null;
        draftState.latest = null;
        loadDraftsForPanel();
      })
      .catch(function (err) {
        draftState.error = getMessage(err, "Unable to close Basic float plan.");
        draftState.loaded = true;
        if (panelContainer) renderPanel(panelContainer);
      })
      .finally(function () {
        if (trigger) {
          trigger.disabled = false;
          trigger.textContent = originalText || "Close Basic Float Plan";
        }
      });
  }

  function resetFormForOpen(draftId) {
    if (dom.form) {
      dom.form.reset();
      dom.form.classList.remove("d-none");
    }
    if (dom.sentState) dom.sentState.classList.add("d-none");
    if (dom.saveBtn) dom.saveBtn.classList.remove("d-none");
    if (dom.sendBtn) dom.sendBtn.classList.remove("d-none");
    clearValidation();
    setMessage("", "info");
    populateTimezones();
    setDefaultValues();
    if (dom.planId && toInt(draftId) > 0) {
      dom.planId.value = String(toInt(draftId));
    }
  }

  function openModal(draftId) {
    var planId = toInt(draftId);
    if (!initialized) init();
    if (!dom.modalEl) return;
    resetFormForOpen(planId);
    if (modal) {
      modal.show();
    }
    loadFormData()
      .then(function () {
        if (planId <= 0) return null;
        if (!window.Api || typeof window.Api.getBasicFloatPlanDraft !== "function") {
          throw { MESSAGE: "Basic draft lookup is unavailable." };
        }
        setMessage("Loading saved Basic draft...", "info");
        return window.Api.getBasicFloatPlanDraft(planId).then(function (payload) {
          if (!payload || payload.SUCCESS !== true) {
            throw payload || { MESSAGE: "Unable to load Basic draft." };
          }
          hydrateDraft(payload);
          setMessage("Basic float plan draft loaded.", "success");
          return payload;
        });
      })
      .catch(function (err) {
        setMessage(getMessage(err, "Unable to load Basic float plan options."), "danger");
      });
  }

  function handleDocumentClick(event) {
    var lockedPanel = getLockedReusablePanel(event.target);
    if (lockedPanel) {
      blockLockedReusablePanelEvent(event, lockedPanel);
      return;
    }
    var target = event.target && event.target.closest
      ? event.target.closest("[data-basic-floatplan-open], [data-basic-floatplan-resume], [data-basic-floatplan-send-draft], [data-basic-floatplan-close], [data-basic-premium-upgrade], #openRouteBuilderBtn")
      : null;
    if (!target) return;
    if (target.id === "openRouteBuilderBtn" && !basicMode) return;
    event.preventDefault();
    event.stopPropagation();
    if (typeof event.stopImmediatePropagation === "function") {
      event.stopImmediatePropagation();
    }
    if (target.hasAttribute("data-basic-floatplan-send-draft")) {
      sendSavedDraft(target, target.getAttribute("data-basic-floatplan-id") || 0);
      return;
    }
    if (target.hasAttribute("data-basic-floatplan-close")) {
      closeBasicPlan(target, target.getAttribute("data-basic-floatplan-id") || 0);
      return;
    }
    if (target.hasAttribute("data-basic-premium-upgrade")) {
      startPremiumCheckout(target.getAttribute("data-basic-premium-upgrade") || "", target);
      return;
    }
    openModal(target.getAttribute("data-basic-floatplan-id") || 0);
  }

  function handleDocumentKeydown(event) {
    var lockedPanel = getLockedReusablePanel(event.target);
    if (!lockedPanel || (event.key !== "Enter" && event.key !== " ")) return;
    blockLockedReusablePanelEvent(event, lockedPanel);
  }

	  function handleFormInput(event) {
	    var target = event.target;
	    if (!target) return;
	    if (target === dom.contactPhone) {
	      var formattedPhone = formatUsPhoneInput(target.value);
	      if (target.value !== formattedPhone) {
	        target.value = formattedPhone;
	      }
	    }
	    target.classList.remove("is-invalid");
	    if ((target === dom.contactName || target === dom.contactEmail || target === dom.contactPhone) && dom.contactError) {
	      dom.contactError.classList.add("d-none");
	    }
	    if (target === dom.authorityId) {
	      updateAuthorityPhone();
	    }
	  }

  function init() {
    if (initialized) return;
    if (!cacheDom()) return;
    initialized = true;
    if (window.bootstrap && window.bootstrap.Modal) {
      modal = new window.bootstrap.Modal(dom.modalEl);
    }
    populateTimezones();
    document.addEventListener("click", handleDocumentClick, true);
    document.addEventListener("keydown", handleDocumentKeydown, true);
	    if (dom.form) {
	      dom.form.addEventListener("input", handleFormInput);
	      dom.form.addEventListener("change", handleFormInput);
	    }
	    if (dom.authorityId) {
	      dom.authorityId.addEventListener("change", updateAuthorityPhone);
	    }
    if (dom.saveBtn) {
      dom.saveBtn.addEventListener("click", function () {
        saveDraft().catch(function () {});
      });
    }
    if (dom.sendBtn) {
      dom.sendBtn.addEventListener("click", saveAndSend);
    }
  }

  window.FPW.DashboardModules.basicFloatPlan = {
    init: init,
    open: openModal,
    renderPanel: renderPanel,
    setBasicMode: setBasicMode,
    isBasicMode: function () {
      return basicMode;
    }
  };
})(window, document);
