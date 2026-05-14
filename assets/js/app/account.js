// /fpw/assets/js/app/account.js
(function (window, document) {
  "use strict";

  var BASE_PATH = window.FPW_BASE || "";
  var API_BASE = window.FPW_API_BASE || (BASE_PATH + "/api/v1");

  function $(id) { return document.getElementById(id); }

  function pick(obj, keys, fallback) {
    for (var i = 0; i < keys.length; i++) {
      var k = keys[i];
      if (obj && obj[k] !== undefined && obj[k] !== null && String(obj[k]).length) return obj[k];
    }
    return fallback;
  }

  function fmtDate(val) {
    return val ? String(val) : "—";
  }

  function setText(id, value) {
    var el = $(id);
    if (el) el.textContent = value;
  }

  function setHidden(id, hidden) {
    var el = $(id);
    if (!el) return;
    if (hidden) {
      el.classList.add("d-none");
    } else {
      el.classList.remove("d-none");
    }
  }

  function companionAuthUrl(action) {
    return API_BASE + "/companionAuth.cfc?method=handle&action=" + encodeURIComponent(action);
  }

  function formatDisplayDate(value, fallback) {
    if (!value) return fallback || "—";
    var parsed = new Date(value);
    if (!isNaN(parsed.getTime())) {
      return parsed.toLocaleString();
    }
    return String(value);
  }

  function isPastDate(value) {
    if (!value) return false;
    var parsed = new Date(value);
    return !isNaN(parsed.getTime()) && parsed.getTime() <= Date.now();
  }

  function escapeHtml(value) {
    return String(value === undefined || value === null ? "" : value)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
      .replace(/'/g, "&#39;");
  }

  function ensureAuth(payload) {
    return window.AppAuth ? window.AppAuth.ensureAuthenticated(payload) : true;
  }

  function handleAuthError(err) {
    return window.AppAuth ? window.AppAuth.handleUnauthorizedError(err) : false;
  }

  function redirectToLogin() {
    if (window.AppAuth && typeof window.AppAuth.redirectToLogin === "function") {
      window.AppAuth.redirectToLogin();
      return;
    }
    window.location.href = BASE_PATH + "/index.cfm";
  }

  function populateHomePort(home) {
    home = home || {};

    var address = pick(home, ["address", "ADDRESS"], "");
    var city    = pick(home, ["city", "CITY"], "");
    var state   = pick(home, ["state", "STATE"], "");
    var zip     = pick(home, ["zip", "ZIP"], "");

    var phone   = pick(home, ["phone", "PHONE"], "");
    var lat     = pick(home, ["lat", "LAT"], "");
    var lng     = pick(home, ["lng", "LNG"], "");

    if ($("homeAddress")) $("homeAddress").value = address;
    if ($("homeCity")) $("homeCity").value = city;
    if ($("homeState")) $("homeState").value = state;
    if ($("homeZip")) $("homeZip").value = zip;
    if ($("homePhone")) $("homePhone").value = phone;
    if ($("homeLat")) $("homeLat").value = lat;
    if ($("homeLng")) $("homeLng").value = lng;
  }

  function populateProfile(profile) {
    profile = profile || {};

    var email       = pick(profile, ["email", "EMAIL"], "—");
    var fName       = pick(profile, ["fName", "FNAME", "firstName", "FIRSTNAME"], "");
    var lName       = pick(profile, ["lName", "LNAME", "lastName", "LASTNAME"], "");
    var mobilePhone = pick(profile, ["mobilePhone", "MOBILEPHONE"], "");

    var lastLogin   = pick(profile, ["lastLogin", "LASTLOGIN"], "—");
    var lastUpdate  = pick(profile, ["lastUpdate", "LASTUPDATE"], "—");

    if ($("emailDisplay")) $("emailDisplay").textContent = email;
    if ($("fName")) $("fName").value = fName;
    if ($("lName")) $("lName").value = lName;
    if ($("mobilePhone")) $("mobilePhone").value = mobilePhone;

    if ($("lastLogin")) $("lastLogin").textContent = fmtDate(lastLogin);
    if ($("lastUpdate")) $("lastUpdate").textContent = fmtDate(lastUpdate);

    var home = profile.homePort || profile.HOMEPORT || {};
    populateHomePort(home);
  }

  function getAccessFromPayload(payload) {
    if (!payload || typeof payload !== "object") return null;
    if (payload.ACCESS && typeof payload.ACCESS === "object") return payload.ACCESS;
    if (payload.access && typeof payload.access === "object") return payload.access;
    return null;
  }

  function hasPremiumAccess(access) {
    var value = access && Object.prototype.hasOwnProperty.call(access, "hasPremium")
      ? access.hasPremium
      : (access && Object.prototype.hasOwnProperty.call(access, "HASPREMIUM") ? access.HASPREMIUM : false);
    if (value === true || value === 1) return true;
    return String(value).trim().toLowerCase() === "true" || String(value).trim() === "1";
  }

  function getPremiumSource(access) {
    return String(pick(access, ["premiumSource", "PREMIUMSOURCE", "source", "SOURCE"], "") || "").trim().toLowerCase();
  }

  function getPremiumSources(access) {
    var sources = access && (access.premiumSources || access.PREMIUMSOURCES);
    if (!Array.isArray(sources)) return [];
    return sources.map(function (source) {
      return String(source || "").trim().toLowerCase();
    }).filter(function (source) {
      return !!source;
    });
  }

  function hasStripeBilling(access) {
    var value = access && Object.prototype.hasOwnProperty.call(access, "hasStripeBilling")
      ? access.hasStripeBilling
      : (access && Object.prototype.hasOwnProperty.call(access, "HASSTRIPEBILLING") ? access.HASSTRIPEBILLING : false);
    if (value === true || value === 1) return true;
    return String(value).trim().toLowerCase() === "true" || String(value).trim() === "1";
  }

  function setBillingStatus(label, statusKey) {
    var el = $("membershipBillingStatus");
    if (!el) return;
    el.textContent = label || "Unknown";
    el.className = "membership-status-badge membership-status-" + (statusKey || "unknown");
  }

  function showBillingMessage(message, tone) {
    var el = $("membershipBillingMessage");
    if (!el) return;
    el.textContent = message || "";
    el.classList.remove("membership-message-error", "membership-message-success");
    if (tone === "error" || tone === "danger") el.classList.add("membership-message-error");
    if (tone === "success") el.classList.add("membership-message-success");
  }

  function showPromoMessage(message, tone) {
    var el = $("promoCodeMessage");
    if (!el) return;
    el.textContent = message || "";
    el.classList.remove("promo-message-error", "promo-message-success");
    if (tone === "error" || tone === "danger") el.classList.add("promo-message-error");
    if (tone === "success") el.classList.add("promo-message-success");
  }

  function setBillingActionsBusy(isBusy) {
    var buttons = document.querySelectorAll("[data-membership-upgrade], #membershipManageBillingBtn");
    Array.prototype.forEach.call(buttons, function (button) {
      button.disabled = !!isBusy;
      button.setAttribute("aria-disabled", isBusy ? "true" : "false");
    });
  }

  function setPromoBusy(isBusy) {
    var input = $("promoCodeInput");
    var button = $("promoCodeRedeemBtn");
    if (input) input.disabled = !!isBusy;
    if (button) {
      button.disabled = !!isBusy;
      button.setAttribute("aria-disabled", isBusy ? "true" : "false");
      button.textContent = isBusy ? "Redeeming..." : "Redeem Code";
    }
  }

  function renderMembershipBilling(access) {
    var summary = $("membershipBillingSummary");
    var upgradeActions = $("membershipUpgradeActions");
    var portalActions = $("membershipPortalActions");
    var hasPremium = hasPremiumAccess(access);
    var premiumSource = getPremiumSource(access);
    var premiumSources = getPremiumSources(access);
    var hasStripeBillingMapping = hasStripeBilling(access) || premiumSources.indexOf("stripe_subscription") !== -1;

    if (upgradeActions) upgradeActions.classList.add("d-none");
    if (portalActions) portalActions.classList.add("d-none");
    showBillingMessage("", "info");

    if (!access) {
      setBillingStatus("Unavailable", "unknown");
      if (summary) summary.textContent = "Membership status is unavailable.";
      return;
    }

    if (!hasPremium) {
      setBillingStatus("Basic", "basic");
      if (summary) summary.textContent = "Upgrade to Premium for saved routes, multi-day trips, Active Cruise, Follow Page sharing, and advanced monitoring.";
      if (upgradeActions) upgradeActions.classList.remove("d-none");
      return;
    }

    setBillingStatus("Premium", "premium");
    if (premiumSource === "founder_lifetime") {
      if (summary) {
        summary.textContent = hasStripeBillingMapping
          ? "Founders Lifetime Premium is active. If you also have Stripe billing, manage billing separately through Stripe."
          : "Founders Lifetime Premium is active.";
      }
      if (portalActions && hasStripeBillingMapping) portalActions.classList.remove("d-none");
      return;
    }

    if (premiumSource === "stripe_subscription") {
      if (summary) summary.textContent = "Premium access is active through a Stripe subscription.";
      if (portalActions) portalActions.classList.remove("d-none");
      return;
    }

    if (summary) summary.textContent = "Premium access is active. Stripe billing management is not available for this membership source.";
  }

  function getCheckoutUrl(payload) {
    return payload && (payload.checkoutUrl || payload.CHECKOUT_URL)
      ? String(payload.checkoutUrl || payload.CHECKOUT_URL)
      : "";
  }

  function getPortalUrl(payload) {
    return payload && (payload.portalUrl || payload.PORTAL_URL)
      ? String(payload.portalUrl || payload.PORTAL_URL)
      : "";
  }

  function getErrorCode(error) {
    if (error && typeof error.ERROR === "string") return String(error.ERROR);
    if (error && typeof error.errorCode === "string") return String(error.errorCode);
    if (error && error.ERROR && error.ERROR.CODE) return String(error.ERROR.CODE);
    return "";
  }

  async function loadMembershipBilling() {
    if (!$("membershipBillingCard")) return;

    try {
      var data = window.Api && typeof window.Api.getCurrentMemberAccess === "function"
        ? await window.Api.getCurrentMemberAccess()
        : await fetchJson(API_BASE + "/me.cfc?method=handle", { method: "GET" });

      if (!ensureAuth(data)) {
        return;
      }
      if (!data || (data.SUCCESS !== true && data.success !== true)) {
        throw data || { MESSAGE: "Unable to load membership status." };
      }

      renderMembershipBilling(getAccessFromPayload(data));
    } catch (err) {
      if (handleAuthError(err)) {
        return;
      }
      setBillingStatus("Unavailable", "unknown");
      setText("membershipBillingSummary", "Membership status is unavailable.");
      showBillingMessage("Unable to load membership status.", "error");
    }
  }

  async function startPremiumUpgrade(interval, trigger) {
    var intervalValue = String(interval || "").trim().toLowerCase();
    var originalText = trigger ? trigger.textContent : "";
    if (intervalValue !== "monthly" && intervalValue !== "yearly") {
      showBillingMessage("Choose monthly or yearly Premium billing.", "error");
      return;
    }
    if (!window.Api || typeof window.Api.createPremiumCheckoutSession !== "function") {
      showBillingMessage("Premium checkout is not available yet.", "error");
      return;
    }

    setBillingActionsBusy(true);
    if (trigger) trigger.textContent = "Opening...";
    showBillingMessage("Opening Stripe-hosted checkout...", "info");

    try {
      var data = await window.Api.createPremiumCheckoutSession(intervalValue);
      var checkoutUrl = getCheckoutUrl(data);
      if (!data || (data.SUCCESS !== true && data.success !== true) || !checkoutUrl) {
        throw data || { MESSAGE: "Premium checkout is not available right now." };
      }
      window.location.href = checkoutUrl;
    } catch (err) {
      var code = getErrorCode(err).toUpperCase();
      if (code === "STRIPE_CONFIG_MISSING") {
        showBillingMessage("Premium checkout is not available yet. Please contact FPW support.", "error");
      } else if (code === "ALREADY_PREMIUM") {
        showBillingMessage("Your account already has Premium access.", "success");
        await loadMembershipBilling();
      } else if (code === "INVALID_PRICE_SELECTOR") {
        showBillingMessage("Choose monthly or yearly Premium billing.", "error");
      } else {
        showBillingMessage((err && (err.MESSAGE || err.message)) ? (err.MESSAGE || err.message) : "Premium checkout is not available right now.", "error");
      }
    } finally {
      setBillingActionsBusy(false);
      if (trigger) trigger.textContent = originalText || (intervalValue === "yearly" ? "Upgrade Yearly" : "Upgrade Monthly");
    }
  }

  async function openBillingPortal(trigger) {
    var originalText = trigger ? trigger.textContent : "";
    if (!window.Api || typeof window.Api.createBillingPortalSession !== "function") {
      showBillingMessage("Billing management is not available right now.", "error");
      return;
    }

    setBillingActionsBusy(true);
    if (trigger) trigger.textContent = "Opening...";
    showBillingMessage("Opening Stripe-hosted billing management...", "info");

    try {
      var data = await window.Api.createBillingPortalSession();
      var portalUrl = getPortalUrl(data);
      if (!data || (data.SUCCESS !== true && data.success !== true) || !portalUrl) {
        throw data || { MESSAGE: "Billing management is not available right now." };
      }
      window.location.href = portalUrl;
    } catch (err) {
      var code = getErrorCode(err).toUpperCase();
      if (code === "NO_BILLING_CUSTOMER") {
        showBillingMessage("Billing management is not available for this account yet.", "error");
      } else if (code === "STRIPE_CONFIG_MISSING") {
        showBillingMessage("Billing management is not available right now.", "error");
      } else {
        showBillingMessage((err && (err.MESSAGE || err.message)) ? (err.MESSAGE || err.message) : "Billing management is not available right now.", "error");
      }
    } finally {
      setBillingActionsBusy(false);
      if (trigger) trigger.textContent = originalText || "Manage Billing";
    }
  }

  function promoMessageForError(err) {
    var code = getErrorCode(err).toUpperCase();
    if (code === "CODE_REQUIRED") return "Enter a promo code.";
    if (code === "CODE_NOT_FOUND") return "Promo code was not recognized.";
    if (code === "CODE_DISABLED") return "Promo code is not active.";
    if (code === "CODE_NOT_STARTED") return "Promo code is not active yet.";
    if (code === "CODE_EXPIRED") return "Promo code has expired.";
    if (code === "CODE_ALREADY_REDEEMED") return "Promo code has already been used for this account.";
    if (code === "CODE_MAX_REDEMPTIONS_REACHED") return "Promo code has reached its redemption limit.";
    if (code === "PROMO_TYPE_NOT_SUPPORTED") return "Promo code type is not supported.";
    return (err && (err.MESSAGE || err.message)) ? (err.MESSAGE || err.message) : "Promo code could not be redeemed.";
  }

  async function redeemPromoCode(evt) {
    evt.preventDefault();

    var input = $("promoCodeInput");
    var code = input ? String(input.value || "").trim() : "";
    if (!code) {
      showPromoMessage("Enter a promo code.", "error");
      return;
    }
    if (!window.Api || typeof window.Api.redeemPromoCode !== "function") {
      showPromoMessage("Promo code redemption is not available right now.", "error");
      return;
    }

    setPromoBusy(true);
    showPromoMessage("Checking code...", "info");

    try {
      var data = await window.Api.redeemPromoCode(code);
      var nextAction = String((data && (data.nextAction || data.NEXTACTION)) || "").trim().toLowerCase();
      var promoType = String((data && (data.promoType || data.PROMOTYPE)) || "").trim().toLowerCase();

      if (!data || (data.SUCCESS !== true && data.success !== true)) {
        throw data || { MESSAGE: "Promo code could not be redeemed." };
      }

      if (nextAction === "stripe_checkout_required" || promoType === "stripe_free_months") {
        showPromoMessage("Launch discount recognized. Checkout activation will be completed in the next billing step.", "success");
        return;
      }

      if (promoType === "founder_lifetime" || nextAction === "founder_lifetime_redeemed") {
        if (input) input.value = "";
        showPromoMessage("Founders Lifetime Premium has been added to your account.", "success");
        await loadMembershipBilling();
        return;
      }

      showPromoMessage((data.MESSAGE || data.message) || "Promo code redeemed.", "success");
      await loadMembershipBilling();
    } catch (err) {
      if (handleAuthError(err)) {
        return;
      }
      showPromoMessage(promoMessageForError(err), "error");
    } finally {
      setPromoBusy(false);
    }
  }

  async function fetchJson(url, options) {
    options = options || {};
    options.credentials = "include";

    // If calling a CFC without explicit returnFormat, request JSON
    if (/\.cfc(\?|$)/i.test(url) && !/returnformat=/i.test(url)) {
      url += (url.indexOf('?') === -1 ? '?' : '&') + 'returnFormat=json';
    }

    var res = await fetch(url, options);
    var txt = await res.text();

    var data;
    try { data = txt ? JSON.parse(txt) : {}; }
    catch (e) { throw { MESSAGE: "API returned non-JSON", RAW: txt, status: res.status }; }

    if (!res.ok) {
      data.status = res.status;
      throw data;
    }
    return data;
  }

  async function loadProfile() {
    try {
      var data = await fetchJson(API_BASE + "/profile.cfc?method=handle", { method: "GET" });

      if (!ensureAuth(data)) {
        return;
      }
      if (!data || data.SUCCESS !== true) {
        console.error("Profile load failed:", data);
        return;
      }

      populateProfile(data.PROFILE || data.profile || {});
    } catch (err) {
      console.error("loadProfile error:", err);
      if (handleAuthError(err)) {
        return;
      }
    }
  }

  async function saveProfile(evt) {
    evt.preventDefault();

    var payload = {
      action: "update",
      // send camelCase; server currently accepts both and writes to fName/lName/mobilePhone
      fName: ($("fName").value || "").trim(),
      lName: ($("lName").value || "").trim(),
      mobilePhone: ($("mobilePhone").value || "").trim()
    };

    var btn = $("saveProfileBtn");
    if (btn) { btn.disabled = true; btn.textContent = "Saving…"; }

    try {
      var data = await fetchJson(API_BASE + "/profile.cfc?method=handle", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload)
      });

      if (!ensureAuth(data)) {
        return;
      }
      if (!data || data.SUCCESS !== true) {
        alert((data && data.MESSAGE) ? data.MESSAGE : "Save failed.");
        return;
      }

      populateProfile(data.PROFILE || {});
      alert("Profile saved.");
    } catch (err) {
      console.error("saveProfile error:", err);
      if (handleAuthError(err)) {
        return;
      }
      alert((err && err.MESSAGE) ? err.MESSAGE : "Save failed (see console).");
    } finally {
      if (btn) { btn.disabled = false; btn.textContent = "Save Profile"; }
    }
  }

  async function changePassword(evt) {
    evt.preventDefault();

    var currentPassword = ($("currentPassword").value || "").trim();
    var newPassword     = ($("newPassword").value || "").trim();
    var confirmPassword = ($("confirmPassword").value || "").trim();

    if (!currentPassword || !newPassword || !confirmPassword) {
      alert("Fill out all password fields.");
      return;
    }
    if (newPassword.length < 8) {
      alert("New password must be at least 8 characters.");
      return;
    }
    if (newPassword !== confirmPassword) {
      alert("New password and confirmation do not match.");
      return;
    }

    var btn = $("changePwBtn");
    if (btn) { btn.disabled = true; btn.textContent = "Changing…"; }

    try {
      var data = await fetchJson(API_BASE + "/profile.cfc?method=handle", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          action: "changePassword",
          currentPassword: currentPassword,
          newPassword: newPassword
        })
      });

      if (!ensureAuth(data)) {
        return;
      }
      if (!data || data.SUCCESS !== true) {
        alert((data && data.MESSAGE) ? data.MESSAGE : "Password change failed.");
        return;
      }

      $("currentPassword").value = "";
      $("newPassword").value = "";
      $("confirmPassword").value = "";
      alert("Password changed.");
    } catch (err) {
      console.error("changePassword error:", err);
      if (handleAuthError(err)) {
        return;
      }
      alert((err && err.MESSAGE) ? err.MESSAGE : "Password change failed (see console).");
    } finally {
      if (btn) { btn.disabled = false; btn.textContent = "Change Password"; }
    }
  }

  async function saveHomePort(evt) {
    evt.preventDefault();

    var payload = {
      action: "save",
      address: ($("homeAddress").value || "").trim(),
      city: ($("homeCity").value || "").trim(),
      state: ($("homeState").value || "").trim(),
      zip: ($("homeZip").value || "").trim(),
      phone: ($("homePhone").value || "").trim(),
      lat: ($("homeLat").value || "").trim(),
      lng: ($("homeLng").value || "").trim()
    };

    var btn = $("saveHomePortBtn");
    if (btn) { btn.disabled = true; btn.textContent = "Saving…"; }

    try {
      var data = await fetchJson(API_BASE + "/homeport.cfc?method=handle", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload)
      });

      if (!ensureAuth(data)) {
        return;
      }
      if (!data || data.SUCCESS !== true) {
        alert((data && data.MESSAGE) ? data.MESSAGE : "Home port save failed.");
        return;
      }

      var home = data.HOMEPORT || data.homePort || data.homeport || {};
      populateHomePort(home);
      alert("Home port saved.");
    } catch (err) {
      console.error("saveHomePort error:", err);
      if (handleAuthError(err)) {
        return;
      }
      alert((err && err.MESSAGE) ? err.MESSAGE : "Home port save failed (see console).");
    } finally {
      if (btn) { btn.disabled = false; btn.textContent = "Save Home Port"; }
    }
  }

  function getCompanionDevices(payload) {
    var devices = (payload && (payload.DEVICES || payload.devices)) || [];
    return Array.isArray(devices) ? devices : [];
  }

  function getCompanionDeviceStatus(device) {
    var revokedAt = pick(device, ["revokedAtUtc", "REVOKED_AT_UTC", "revoked_at_utc"], "");
    var expiresAt = pick(device, ["expiresAtUtc", "EXPIRES_AT_UTC", "expires_at_utc"], "");

    if (revokedAt) {
      return { label: "Revoked", key: "revoked" };
    }
    if (isPastDate(expiresAt)) {
      return { label: "Expired", key: "expired" };
    }
    return { label: "Active", key: "active" };
  }

  function showCompanionStatus(message, tone) {
    var status = $("companionDevicesStatus");
    if (!status) return;
    status.textContent = message || "";
    status.classList.remove("companion-status-error", "companion-status-success");
    if (tone === "error") status.classList.add("companion-status-error");
    if (tone === "success") status.classList.add("companion-status-success");
  }

  function renderCompanionDevices(devices) {
    var list = $("companionDevicesList");
    if (!list) return;

    list.innerHTML = "";
    setHidden("companionDevicesEmpty", devices.length > 0);

    devices.forEach(function (device) {
      var status = getCompanionDeviceStatus(device);
      var deviceId = parseInt(pick(device, ["id", "ID", "deviceId", "DEVICE_ID"], 0), 10) || 0;
      var name = pick(device, ["deviceName", "DEVICE_NAME", "device_name", "name"], "") || "Unnamed device";
      var platform = pick(device, ["platform", "PLATFORM", "devicePlatform"], "") || "Unknown platform";
      var appVersion = pick(device, ["appVersion", "APP_VERSION", "app_version"], "");
      var createdAt = pick(device, ["createdUtc", "CREATED_UTC", "created_utc"], "");
      var lastUsedAt = pick(device, ["lastUsedAtUtc", "LAST_USED_AT_UTC", "last_used_at_utc"], "");
      var expiresAt = pick(device, ["expiresAtUtc", "EXPIRES_AT_UTC", "expires_at_utc"], "");
      var revokedAt = pick(device, ["revokedAtUtc", "REVOKED_AT_UTC", "revoked_at_utc"], "");
      var platformLine = appVersion ? platform + " / " + appVersion : platform;

      var row = document.createElement("div");
      row.className = "companion-device-row";
      row.innerHTML =
        '<div class="companion-device-main">' +
          '<div class="d-flex flex-wrap align-items-center gap-2 mb-1">' +
            '<div class="companion-device-name">' + escapeHtml(name) + '</div>' +
            '<span class="companion-status-badge companion-status-' + escapeHtml(status.key) + '">' + escapeHtml(status.label) + '</span>' +
          '</div>' +
          '<div class="companion-device-meta">' + escapeHtml(platformLine) + '</div>' +
          '<dl class="companion-device-details mb-0">' +
            '<div><dt>Created</dt><dd>' + escapeHtml(formatDisplayDate(createdAt, "Unknown")) + '</dd></div>' +
            '<div><dt>Last Used</dt><dd>' + escapeHtml(formatDisplayDate(lastUsedAt, "Never")) + '</dd></div>' +
            '<div><dt>Expires</dt><dd>' + escapeHtml(formatDisplayDate(expiresAt, "Unknown")) + '</dd></div>' +
            (revokedAt ? '<div><dt>Revoked</dt><dd>' + escapeHtml(formatDisplayDate(revokedAt, "Revoked")) + '</dd></div>' : '') +
          '</dl>' +
        '</div>';

      if (status.key === "active" && deviceId > 0) {
        var actions = document.createElement("div");
        actions.className = "companion-device-actions";
        actions.innerHTML = '<button class="btn btn-outline-primary btn-sm" type="button" data-companion-revoke-device="' + String(deviceId) + '">Revoke</button>';
        row.appendChild(actions);
      }

      list.appendChild(row);
    });

    var revokeButtons = list.querySelectorAll("[data-companion-revoke-device]");
    Array.prototype.forEach.call(revokeButtons, function (button) {
      button.addEventListener("click", function () {
        revokeCompanionDevice(parseInt(button.getAttribute("data-companion-revoke-device"), 10) || 0, button);
      });
    });
  }

  async function loadCompanionDevices() {
    if (!$("companionDevicesCard")) return;
    showCompanionStatus("Loading companion devices...");

    try {
      var data = await fetchJson(companionAuthUrl("listDevices"), { method: "GET" });
      if (!ensureAuth(data)) {
        return;
      }
      if (!data || data.SUCCESS !== true) {
        showCompanionStatus((data && data.MESSAGE) ? data.MESSAGE : "Unable to load companion devices.", "error");
        return;
      }

      var devices = getCompanionDevices(data);
      renderCompanionDevices(devices);
      showCompanionStatus(devices.length ? "Companion devices loaded." : "No companion devices are paired yet.");
    } catch (err) {
      console.error("loadCompanionDevices error:", err);
      if (handleAuthError(err)) {
        return;
      }
      showCompanionStatus((err && err.MESSAGE) ? err.MESSAGE : "Unable to load companion devices.", "error");
    }
  }

  async function createCompanionPairingCode() {
    var btn = $("companionPairBtn");
    if (btn) { btn.disabled = true; btn.textContent = "Creating..."; }

    try {
      var data = await fetchJson(companionAuthUrl("createPairingCode"), {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({})
      });

      if (!ensureAuth(data)) {
        return;
      }
      if (!data || data.SUCCESS !== true) {
        alert((data && data.MESSAGE) ? data.MESSAGE : "Unable to create pairing code.");
        return;
      }

      var code = pick(data, ["PAIRING_CODE", "pairingCode"], "");
      var expiresAt = pick(data, ["EXPIRES_AT_UTC", "expiresAtUtc"], "");
      if (!code) {
        alert("Pairing code was not returned.");
        return;
      }

      setText("companionPairingCode", code);
      setText("companionPairingExpires", "Expires at " + formatDisplayDate(expiresAt, "the scheduled expiry time"));
      setText(
        "companionPairingMessage",
        "Enter this code in the Companion App. If you create another code, this page will show the newest code; older unused codes expire on their original schedule."
      );
      setHidden("companionPairingPanel", false);
      showCompanionStatus("Pairing code created.", "success");
    } catch (err) {
      console.error("createCompanionPairingCode error:", err);
      if (handleAuthError(err)) {
        return;
      }
      alert((err && err.MESSAGE) ? err.MESSAGE : "Unable to create pairing code.");
    } finally {
      if (btn) { btn.disabled = false; btn.textContent = "Pair Companion App"; }
    }
  }

  async function copyCompanionPairingCode() {
    var codeEl = $("companionPairingCode");
    var code = codeEl ? (codeEl.textContent || "").trim() : "";
    if (!code || code === "----") {
      alert("No pairing code is available to copy.");
      return;
    }
    if (!navigator.clipboard || typeof navigator.clipboard.writeText !== "function") {
      alert("Copy is not available in this browser.");
      return;
    }

    try {
      await navigator.clipboard.writeText(code);
      showCompanionStatus("Pairing code copied.", "success");
    } catch (err) {
      console.error("copyCompanionPairingCode error:", err);
      alert("Copy failed.");
    }
  }

  async function revokeCompanionDevice(deviceId, button) {
    if (!(deviceId > 0)) {
      alert("Companion device id is missing.");
      return;
    }

    var confirmed = window.confirm(
      "Revoke this companion device? It will stop being able to submit trip check-ins immediately. Pair the companion app again if you want to reconnect this device."
    );
    if (!confirmed) {
      return;
    }

    if (button) { button.disabled = true; button.textContent = "Revoking..."; }

    try {
      var data = await fetchJson(companionAuthUrl("revokeDevice"), {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          deviceId: deviceId,
          reason: "account settings revoke"
        })
      });

      if (!ensureAuth(data)) {
        return;
      }
      if (!data || data.SUCCESS !== true) {
        alert((data && data.MESSAGE) ? data.MESSAGE : "Unable to revoke companion device.");
        return;
      }

      showCompanionStatus("Companion device revoked.", "success");
      await loadCompanionDevices();
    } catch (err) {
      console.error("revokeCompanionDevice error:", err);
      if (handleAuthError(err)) {
        return;
      }
      alert((err && err.MESSAGE) ? err.MESSAGE : "Unable to revoke companion device.");
    } finally {
      if (button) { button.disabled = false; button.textContent = "Revoke"; }
    }
  }

  async function logout() {
    try {
      await fetchJson(API_BASE + "/auth.cfc?method=handle", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ action: "logout" })
      });
    } catch (e) {}
    redirectToLogin();
  }

  document.addEventListener("DOMContentLoaded", function () {
    var profileForm = $("profileForm");
    if (profileForm) profileForm.addEventListener("submit", saveProfile);

    var pwForm = $("passwordForm");
    if (pwForm) pwForm.addEventListener("submit", changePassword);

    var refreshBtn = $("refreshProfileBtn");
    if (refreshBtn) refreshBtn.addEventListener("click", loadProfile);

    var homePortForm = $("homePortForm");
    if (homePortForm) homePortForm.addEventListener("submit", saveHomePort);

    var companionPairBtn = $("companionPairBtn");
    if (companionPairBtn) companionPairBtn.addEventListener("click", createCompanionPairingCode);

    var companionRefreshBtn = $("refreshCompanionDevicesBtn");
    if (companionRefreshBtn) companionRefreshBtn.addEventListener("click", loadCompanionDevices);

    var companionCopyBtn = $("copyCompanionPairingCodeBtn");
    if (companionCopyBtn) companionCopyBtn.addEventListener("click", copyCompanionPairingCode);

    var upgradeButtons = document.querySelectorAll("[data-membership-upgrade]");
    Array.prototype.forEach.call(upgradeButtons, function (button) {
      button.addEventListener("click", function () {
        startPremiumUpgrade(button.getAttribute("data-membership-upgrade") || "", button);
      });
    });

    var manageBillingBtn = $("membershipManageBillingBtn");
    if (manageBillingBtn) manageBillingBtn.addEventListener("click", function () {
      openBillingPortal(manageBillingBtn);
    });

    var promoCodeForm = $("promoCodeForm");
    if (promoCodeForm) promoCodeForm.addEventListener("submit", redeemPromoCode);

    var logoutBtn = $("logoutButton");
    if (logoutBtn) logoutBtn.addEventListener("click", logout);

    loadProfile();
    loadMembershipBilling();
    loadCompanionDevices();
  });

})(window, document);
