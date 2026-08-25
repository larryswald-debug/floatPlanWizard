(function (window, document) {
  "use strict";

  var AuthUtils = window.FPW && window.FPW.AuthUtils;
  if (!AuthUtils) {
    console.error("join.js: auth-utils not loaded");
    return;
  }

  var $ = AuthUtils.$;
  var API_BASE = AuthUtils.API_BASE;
  var showAlert = function (message, type) {
    AuthUtils.showAlert("joinAlert", message, type);
  };
  var clearAlert = function () {
    AuthUtils.clearAlert("joinAlert");
  };
  var fetchJson = AuthUtils.fetchJson;
  var PHONE_ERROR_MESSAGE = "Please enter a valid US phone number or leave the phone field blank.";
  var SIGNUP_ATTRIBUTION_STORAGE_KEY = "fpw_signup_attribution";
  var SIGNUP_ATTRIBUTION_CONTENT_TYPES = {
    boat_fuel_calculator: "seo_tool",
    great_loop_locks: "seo_hub"
  };

  function normalizeSignupAttribution(value) {
    var landingKey;
    var sourceContentType;
    var ctaType;

    if (!value || typeof value !== "object" || Array.isArray(value)) return null;

    landingKey = typeof value.landing_key === "string" ? value.landing_key : "";
    sourceContentType = typeof value.source_content_type === "string" ? value.source_content_type : "";
    ctaType = typeof value.cta_type === "string" ? value.cta_type : "";

    if (
      !SIGNUP_ATTRIBUTION_CONTENT_TYPES[landingKey]
      || sourceContentType !== SIGNUP_ATTRIBUTION_CONTENT_TYPES[landingKey]
      || ctaType !== "plan_route"
    ) {
      return null;
    }

    return {
      landing_key: landingKey,
      source_content_type: sourceContentType,
      cta_type: ctaType
    };
  }

  function readSignupAttribution() {
    try {
      return normalizeSignupAttribution(JSON.parse(
        window.sessionStorage.getItem(SIGNUP_ATTRIBUTION_STORAGE_KEY) || "null"
      ));
    } catch (storageError) {
      return null;
    }
  }

  function addSignupAttribution(target, attribution) {
    if (!attribution) return target;
    target.landing_key = attribution.landing_key;
    target.source_content_type = attribution.source_content_type;
    target.cta_type = attribution.cta_type;
    return target;
  }

  function clearSignupAttribution() {
    try {
      window.sessionStorage.removeItem(SIGNUP_ATTRIBUTION_STORAGE_KEY);
    } catch (storageError) {}
  }

  function isConfirmedSignupResponse(data) {
    return !!(data && data.AUTH === true && Number(data.USERID) > 0);
  }

  function formatUsPhoneDigits(digits) {
    digits = String(digits || "").slice(0, 10);
    if (!digits.length) return "";
    if (digits.length <= 3) return "(" + digits;
    if (digits.length <= 6) return "(" + digits.slice(0, 3) + ") " + digits.slice(3);
    return "(" + digits.slice(0, 3) + ") " + digits.slice(3, 6) + "-" + digits.slice(6);
  }

  function getUsPhoneDigits(value, rawDigitsOverride) {
    var hasRawOverride = rawDigitsOverride !== undefined && String(rawDigitsOverride || "").length;
    var digits = hasRawOverride
      ? String(rawDigitsOverride || "").replace(/\D/g, "")
      : String(value || "").replace(/\D/g, "");
    if (digits.length === 11 && digits.charAt(0) === "1") {
      digits = digits.slice(1);
    }
    return digits;
  }

  function normalizeOptionalUsPhone(value, rawDigitsOverride) {
    var rawValue = String(value || "").trim();
    var hasRawOverride = rawDigitsOverride !== undefined && String(rawDigitsOverride || "").length;
    var rawDigits = hasRawOverride ? String(rawDigitsOverride || "").replace(/\D/g, "") : "";
    var digits = getUsPhoneDigits(rawValue, rawDigitsOverride);

    if (!rawValue.length && !rawDigits.length) {
      return { valid: true, value: "" };
    }
    if (digits.length !== 10) {
      return { valid: false, value: "" };
    }
    if (!/^[2-9]\d{2}[2-9]\d{6}$/.test(digits)) {
      return { valid: false, value: "" };
    }
    return { valid: true, value: formatUsPhoneDigits(digits) };
  }

  function formatUsPhoneInputValue(value) {
    var digits = String(value || "").replace(/\D/g, "");
    if (digits.length > 10 && digits.charAt(0) === "1") {
      digits = digits.slice(1);
    }
    return formatUsPhoneDigits(digits);
  }

  function setPhoneFieldError(inputEl, errorEl, message) {
    if (inputEl) {
      inputEl.classList.add("is-invalid");
    }
    if (errorEl) {
      errorEl.textContent = message || "";
    }
  }

  function clearPhoneFieldError(inputEl, errorEl) {
    if (inputEl) {
      inputEl.classList.remove("is-invalid");
    }
    if (errorEl) {
      errorEl.textContent = "";
    }
  }

  function bindOptionalUsPhoneInput(inputEl, errorEl) {
    if (!inputEl) return;
    inputEl.addEventListener("input", function () {
      inputEl.dataset.phoneRawDigits = String(inputEl.value || "").replace(/\D/g, "");
      inputEl.value = formatUsPhoneInputValue(inputEl.value);
      if (!inputEl.value || normalizeOptionalUsPhone(inputEl.value, inputEl.dataset.phoneRawDigits).valid) {
        clearPhoneFieldError(inputEl, errorEl);
      }
    });
    inputEl.addEventListener("blur", function () {
      var normalized = normalizeOptionalUsPhone(inputEl.value, inputEl.dataset.phoneRawDigits || "");
      if (normalized.valid) {
        inputEl.value = normalized.value;
        inputEl.dataset.phoneRawDigits = "";
        clearPhoneFieldError(inputEl, errorEl);
      }
    });
  }

  document.addEventListener("DOMContentLoaded", function () {
    var form = $("joinForm");
    var firstNameEl = $("firstName");
    var lastNameEl = $("lastName");
    var emailEl = $("email");
    var passwordEl = $("password");
    var confirmPasswordEl = $("confirmPassword");
    var addressEl = $("address");
    var cityEl = $("city");
    var stateEl = $("state");
    var zipEl = $("zip");
    var phoneEl = $("phone");
    var phoneErrorEl = $("phoneError");
    var websiteEl = $("website");
    var termsAcceptedEl = $("termsAccepted");
    var btn = $("joinButton");
    var btnLabel = btn ? btn.querySelector(".fpw-submit-label") : null;
    var signupAttribution = readSignupAttribution();
    var signupStartTracked = false;

    if (!form || !firstNameEl || !lastNameEl || !emailEl || !passwordEl || !confirmPasswordEl || !termsAcceptedEl || !btn) {
      console.error("join.js: required elements missing", {
        joinForm: !!form,
        firstName: !!firstNameEl,
        lastName: !!lastNameEl,
        email: !!emailEl,
        password: !!passwordEl,
        confirmPassword: !!confirmPasswordEl,
        termsAccepted: !!termsAcceptedEl,
        joinButton: !!btn
      });
      return;
    }

    form.addEventListener("submit", async function (evt) {
      evt.preventDefault();
      clearAlert();

      var firstName = (firstNameEl.value || "").trim();
      var lastName = (lastNameEl.value || "").trim();
      var email = (emailEl.value || "").trim();
      var password = passwordEl.value || "";
      var confirmPassword = confirmPasswordEl.value || "";
      var address = addressEl ? (addressEl.value || "").trim() : "";
      var city = cityEl ? (cityEl.value || "").trim() : "";
      var state = stateEl ? (stateEl.value || "").trim() : "";
      var zip = zipEl ? (zipEl.value || "").trim() : "";
      var phoneResult = normalizeOptionalUsPhone(phoneEl ? phoneEl.value : "");
      var website = websiteEl ? (websiteEl.value || "").trim() : "";
      var termsAccepted = !!termsAcceptedEl.checked;

      if (!termsAccepted) {
        showAlert("Agreeing to the Terms of Service is required.", "warning");
        return;
      }

      if (!firstName || !lastName || !email) {
        showAlert("First name, last name, and email are required.", "warning");
        return;
      }

      if (!password) {
        showAlert("Password is required.", "warning");
        return;
      }

      if (password.length < 8) {
        showAlert("Password must be at least 8 characters.", "warning");
        return;
      }

      if (!confirmPassword || password !== confirmPassword) {
        showAlert("Password and confirmation do not match.", "warning");
        return;
      }

      if (!phoneResult.valid) {
        setPhoneFieldError(phoneEl, phoneErrorEl, PHONE_ERROR_MESSAGE);
        showAlert(PHONE_ERROR_MESSAGE, "warning");
        if (phoneEl) phoneEl.focus();
        return;
      }
      if (phoneEl) {
        phoneEl.value = phoneResult.value;
      }

      btn.disabled = true;
      if (btnLabel) {
        btnLabel.textContent = "Creating Your Account…";
      } else {
        btn.textContent = "Creating Your Account…";
      }

      try {
        var payload = {
          firstName: firstName,
          lastName: lastName,
          email: email,
          password: password,
          confirmPassword: confirmPassword,
          termsAccepted: termsAccepted,
          address: address,
          city: city,
          state: state,
          zip: zip,
          phone: phoneResult.value,
          website: website
        };

        addSignupAttribution(payload, signupAttribution);

        if (!signupStartTracked) {
          signupStartTracked = true;
          if (window.FPWAnalytics && typeof window.FPWAnalytics.track === "function") {
            window.FPWAnalytics.track("signup_start", addSignupAttribution({
              method: "email",
              source: "join_page"
            }, signupAttribution));
          }
        }

        var data = await fetchJson(API_BASE + "/join.cfc?method=handle", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(payload)
        });

        var msg = (data && data.MESSAGE) ? data.MESSAGE : "User created.";
        var redirectUrl = data && (data.redirectUrl || data.REDIRECT_URL);
        var confirmedSignup = isConfirmedSignupResponse(data);

        showAlert(msg, "success");
        if (confirmedSignup) {
          if (window.FPWAnalytics && typeof window.FPWAnalytics.track === "function") {
            window.FPWAnalytics.track("sign_up", addSignupAttribution({
              method: "email",
              source: "join_page"
            }, signupAttribution));
          }
          clearSignupAttribution();
        }
        if (redirectUrl) {
          window.location.href = redirectUrl;
          return;
        }
        form.reset();
      } catch (err) {
        console.error("join error:", err);
        showAlert((err && err.MESSAGE) ? err.MESSAGE : "Request failed (see console).", "danger");
      } finally {
        btn.disabled = false;
        if (btnLabel) {
          btnLabel.textContent = "Start Planning My Trip";
        } else {
          btn.textContent = "Start Planning My Trip";
        }
      }
    });

    bindOptionalUsPhoneInput(phoneEl, phoneErrorEl);
  });

})(window, document);
