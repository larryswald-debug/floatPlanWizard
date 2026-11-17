(function (window, document) {
  "use strict";

  if (window.__FPW_AUTH_MODAL_BOUND__) return;
  window.__FPW_AUTH_MODAL_BOUND__ = true;

  var dialog = document.getElementById("fpwAuthModal");
  if (!dialog) return;
  var form = document.getElementById("fpwAuthForm");
  var email = document.getElementById("fpwAuthEmail");
  var password = document.getElementById("fpwAuthPassword");
  var website = document.getElementById("fpwAuthWebsite");
  var submit = document.getElementById("fpwAuthContinue");
  var alert = document.getElementById("fpwAuthAlert");
  var disclosureText = document.getElementById("fpwAuthDisclosureText");
  var termsLink = document.getElementById("fpwAuthTerms");
  var privacyLink = document.getElementById("fpwAuthPrivacy");
  var active = null;
  var generation = 0;
  var busy = false;
  var SOURCE_PAGES = { top_nav: true, footer: true, great_loop_trip_planning: true };
  var SECTIONS = { top_nav: true, footer: true, account: true, great_loop_menu: true, daily_decisions: true, after_planning_guide: true };
  var CTA_TYPES = { account: true, dashboard: true, plan_trip: true };
  var LABELS = { Account: true, Dashboard: true, "My Account": true, "Start Free": true, "Start Planning": true, "open FPW\'s Trip Planner workspace": true };

  function normalizedSource(value) {
    value = value || {};
    return {
      source_page: SOURCE_PAGES[value.source_page] ? value.source_page : "top_nav",
      section: SECTIONS[value.section] ? value.section : "top_nav",
      cta_type: CTA_TYPES[value.cta_type] ? value.cta_type : "account",
      label: LABELS[value.label] ? value.label : "Account"
    };
  }

  function track(name, source) {
    try {
      if (window.FPWAnalytics && typeof window.FPWAnalytics.track === "function") {
        window.FPWAnalytics.track(name, normalizedSource(source));
      }
    } catch (error) {}
  }

  function setBusy(value) {
    busy = value;
    submit.disabled = value;
    submit.textContent = value ? "Continuing…" : "Continue";
    form.setAttribute("aria-busy", value ? "true" : "false");
  }

  function showError(message) {
    alert.textContent = message;
    alert.hidden = false;
    alert.focus();
  }

  function localUrl(value, allowedPaths) {
    try {
      var parsed = new URL(value, window.location.origin);
      return parsed.origin === window.location.origin && allowedPaths.indexOf(parsed.pathname) !== -1
        ? parsed.pathname + parsed.search + parsed.hash : "";
    } catch (error) { return ""; }
  }

  function attribution(source) {
    if (source.source_page !== "great_loop_trip_planning" || source.cta_type !== "plan_trip") return null;
    return { landing_key: "great_loop_trip_planning", source_content_type: "seo_guide", cta_type: "plan_trip" };
  }

  function restoreFocus(trigger) {
    var target = trigger && trigger.isConnected && trigger.getClientRects().length ? trigger : document.querySelector("[data-fpw-mobile-toggle]");
    if (target && typeof target.focus === "function") target.focus({ preventScroll: true });
  }

  function dismiss() {
    if (!active) return;
    var previous = active;
    active = null;
    generation++;
    setBusy(false);
    form.reset();
    alert.hidden = true;
    if (dialog.open) dialog.close();
    if (previous.rootOverflow) document.documentElement.style.setProperty("overflow", previous.rootOverflow, previous.rootOverflowPriority);
    else document.documentElement.style.removeProperty("overflow");
    window.scrollTo(previous.scrollX, previous.scrollY);
    track("auth_modal_cancelled", previous.source);
    if (window.Api && typeof window.Api.dismissAuthIntent === "function") {
      Promise.resolve(window.Api.dismissAuthIntent(previous.bootstrap.INTENT_TOKEN)).catch(function () {});
    }
    restoreFocus(previous.trigger);
  }

  function open(options) {
    if (typeof dialog.showModal !== "function") return false;
    if (!options || !options.bootstrap || !options.bootstrap.INTENT_TOKEN || !options.bootstrap.DISCLOSURE) return false;
    if (active) dismiss();
    var disclosure = options.bootstrap.DISCLOSURE;
    var base = dialog.getAttribute("data-fpw-base") || "";
    var terms = localUrl(disclosure.TERMS_URL, [base + "/terms_of_service.cfm"]);
    var privacy = localUrl(disclosure.PRIVACY_URL, [base + "/privacy_policy.cfm"]);
    if (!terms || !privacy || !disclosure.REVISION || !disclosure.TEXT) return false;
    generation++;
    active = {
      bootstrap: options.bootstrap,
      destinationKey: options.destinationKey,
      context: options.context || {},
      source: normalizedSource(options.source),
      trigger: options.trigger || document.activeElement,
      scrollX: window.scrollX,
      scrollY: window.scrollY,
      rootOverflow: document.documentElement.style.getPropertyValue("overflow"),
      rootOverflowPriority: document.documentElement.style.getPropertyPriority("overflow")
    };
    form.reset();
    alert.hidden = true;
    alert.textContent = "";
    disclosureText.textContent = disclosure.TEXT;
    termsLink.href = terms;
    privacyLink.href = privacy;
    dialog.querySelector(".fpw-auth-modal__forgot").href = base + "/app/forgot-password.cfm?authIntent=" + encodeURIComponent(options.bootstrap.INTENT_TOKEN);
    setBusy(false);
    document.documentElement.style.setProperty("overflow", "hidden");
    dialog.showModal();
    email.focus();
    track("auth_modal_open", active.source);
    return true;
  }

  form.addEventListener("submit", function (event) {
    event.preventDefault();
    if (!active || busy) return;
    alert.hidden = true;
    if (!form.reportValidity()) return;
    if (!window.AppAuth || typeof window.AppAuth.continueAuthentication !== "function") {
      showError("Account access is temporarily unavailable. Please try again.");
      return;
    }
    var current = active;
    var requestGeneration = generation;
    setBusy(true);
    track("auth_continue_submit", current.source);
    window.AppAuth.continueAuthentication({
      email: email.value.trim(),
      password: password.value,
      website: website.value,
      intentToken: current.bootstrap.INTENT_TOKEN,
      disclosureRevision: current.bootstrap.DISCLOSURE.REVISION,
      attribution: attribution(current.source)
    }).then(function (response) {
      if (generation !== requestGeneration || active !== current) return;
      if (!response || response.SUCCESS !== true || response.AUTH !== true) throw response || {};
      if (!response.REDIRECT_URL || typeof window.AppAuth.navigateContinuation !== "function") throw {};
      if (window.AppAuth.navigateContinuation(response.REDIRECT_URL) === false) throw {};
      track(response.ACCOUNT_CREATED === true ? "auth_account_created" : "auth_login_success", current.source);
      password.value = "";
      active = null;
      generation++;
    }).catch(function (error) {
      if (generation !== requestGeneration || active !== current) return;
      track("auth_failure", current.source);
      if (error && error.ERROR === "CONSENT_UPDATED" && window.Api && typeof window.Api.authBootstrap === "function") {
        return window.Api.authBootstrap({ intentToken: current.bootstrap.INTENT_TOKEN }).then(function (refreshed) {
          if (generation !== requestGeneration || active !== current) return;
          var disclosure = refreshed && refreshed.DISCLOSURE;
          var base = dialog.getAttribute("data-fpw-base") || "";
          var terms = disclosure && localUrl(disclosure.TERMS_URL, [base + "/terms_of_service.cfm"]);
          var privacy = disclosure && localUrl(disclosure.PRIVACY_URL, [base + "/privacy_policy.cfm"]);
          if (!refreshed || refreshed.SUCCESS !== true || refreshed.AUTH === true || !refreshed.INTENT_TOKEN ||
              !disclosure || !disclosure.REVISION || !disclosure.TEXT || !terms || !privacy) throw {};
          current.bootstrap = refreshed;
          disclosureText.textContent = disclosure.TEXT;
          termsLink.href = terms;
          privacyLink.href = privacy;
          showError("The terms disclosure changed. Review it below and select Continue again.");
        }).catch(function () {
          if (generation === requestGeneration && active === current) {
            showError("The terms disclosure changed. Close this form and select your destination again to review the latest version.");
          }
        });
      }
      showError(error && error.MESSAGE ? error.MESSAGE : "Unable to continue. Check your email and password and try again.");
    }).finally(function () {
      if (generation === requestGeneration && active === current) setBusy(false);
    });
  });

  dialog.querySelector("[data-fpw-auth-close]").addEventListener("click", dismiss);
  dialog.addEventListener("cancel", function (event) { event.preventDefault(); dismiss(); });
  dialog.addEventListener("close", function () { if (active) dismiss(); });

  document.addEventListener("click", function (event) {
    var target = event.target && event.target.closest ? event.target.closest("[data-fpw-auth-intent]") : null;
    if (!target || event.defaultPrevented || event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return;
    var intent = target.getAttribute("data-fpw-auth-intent");
    if (["planner", "account", "dashboard"].indexOf(intent) === -1) return;
    if (!window.AppAuth || typeof window.AppAuth.requireAuth !== "function" || typeof dialog.showModal !== "function") return;
    event.preventDefault();
    window.AppAuth.requireAuth({
      destinationKey: intent,
      context: {},
      source: normalizedSource({
        source_page: target.getAttribute("data-fpw-auth-source-page"),
        section: target.getAttribute("data-fpw-auth-section"),
        cta_type: target.getAttribute("data-fpw-auth-cta-type"),
        label: target.getAttribute("data-fpw-auth-label")
      }),
      trigger: target
    }).catch(function () {
      window.location.assign(target.href);
    });
  });

  document.addEventListener("fpw:profile:updated", function (event) {
    var detail = event.detail || {};
    var profile = detail.PROFILE || {};
    Array.prototype.forEach.call(document.querySelectorAll("[data-fpw-member-identity]"), function (element) {
      var name = String(profile.displayName || profile.DISPLAYNAME ||
        (String(profile.fName || profile.FNAME || "") + " " + String(profile.lName || profile.LNAME || ""))).trim();
      var user = detail.USER || {};
      var fallbackEmail = user.email || user.EMAIL || element.getAttribute("data-fpw-member-email") || "";
      element.textContent = name || fallbackEmail || "Member";
    });
  });

  window.FPWAuthModal = { open: open, close: dismiss };
})(window, document);
