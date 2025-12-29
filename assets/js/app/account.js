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
    window.location.href = BASE_PATH + "/app/login.cfm";
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

    var logoutBtn = $("logoutButton");
    if (logoutBtn) logoutBtn.addEventListener("click", logout);

    loadProfile();
  });

})(window, document);
