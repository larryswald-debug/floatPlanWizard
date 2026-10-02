// /fpw/assets/js/app/auth.js
(function (window) {
  "use strict";

  var BASE_PATH = window.FPW_BASE || "";
  var LOGIN_PATH = BASE_PATH + "/index.cfm";

  function getRecoveryLoginPath() {
    var body = window.document && window.document.body;
    var candidate = body ? body.getAttribute("data-recovery-login-url") || "" : "";
    if (!candidate || typeof window.URL !== "function") return "";
    try {
      var target = new window.URL(candidate, window.location.origin);
      var idMatch = target.search.match(/&(?:routeId|routeInstanceId|floatPlanId)=([0-9]+)$/);
      if (target.origin !== window.location.origin ||
          target.pathname !== BASE_PATH + "/app/login.cfm" ||
          candidate !== target.pathname + target.search ||
          !/^\?recoveryAction=(?:(?:vessel|planner|routes|plans)|route&(?:routeId|routeInstanceId)=[1-9][0-9]{0,9}|draft&floatPlanId=[1-9][0-9]{0,9})$/.test(target.search) ||
          (idMatch && Number(idMatch[1]) > 2147483647)) return "";
      return candidate;
    } catch (err) {
      return "";
    }
  }

  function redirectToLogin() {
    var recoveryLoginPath = getRecoveryLoginPath();
    if (recoveryLoginPath) {
      window.location.href = recoveryLoginPath;
      return;
    }
    if (window.location.pathname === LOGIN_PATH) {
      window.location.reload();
      return;
    }
    window.location.href = LOGIN_PATH;
  }

  function isUnauthorizedResponse(payload) {
    return payload && payload.AUTH === false;
  }

  function ensureAuthenticated(payload) {
    if (isUnauthorizedResponse(payload)) {
      redirectToLogin();
      return false;
    }
    return true;
  }

  function handleUnauthorizedError(err) {
    if (isUnauthorizedResponse(err)) {
      redirectToLogin();
      return true;
    }
    return false;
  }

  function navigateContinuation(candidate) {
    var target = new window.URL(candidate, window.location.origin);
    var allowed = [BASE_PATH + "/app/dashboard.cfm", BASE_PATH + "/app/account.cfm"];
    if (target.origin !== window.location.origin || allowed.indexOf(target.pathname) === -1 ||
        target.hash || candidate !== target.pathname + target.search ||
        (target.search && !/^\?authIntent=[a-f0-9]{64}$/.test(target.search))) {
      throw new Error("Invalid continuation destination.");
    }
    window.location.assign(candidate);
  }

  var authRequestGeneration = 0;
  function requireAuth(intent) {
    var generation = ++authRequestGeneration;
    intent = intent || {};
    return window.Api.authBootstrap(intent).then(function (bootstrap) {
      if (generation !== authRequestGeneration) return {status: "superseded"};
      if (bootstrap.AUTH === true) {
        navigateContinuation(bootstrap.REDIRECT_URL);
        return {status: "navigating"};
      }
      var opened = window.FPWAuthModal && window.FPWAuthModal.open(Object.assign({}, intent, {bootstrap: bootstrap}));
      if (opened === false || !window.FPWAuthModal) {
        var login = new window.URL(bootstrap.LOGIN_URL, window.location.origin);
        if (login.origin === window.location.origin && login.pathname === BASE_PATH + "/app/login.cfm" &&
            /^\?authIntent=[a-f0-9]{64}$/.test(login.search)) window.location.assign(bootstrap.LOGIN_URL);
      }
      return {status: "authentication_required"};
    });
  }


  function readHandoff() {
    var raw = {};
    try { raw = JSON.parse(document.body.getAttribute("data-auth-handoff") || "{}"); } catch (err) { return {}; }
    var token = raw.token || raw.TOKEN || "";
    if (!/^[a-f0-9]{64}$/.test(token)) return {};
    var source = raw.source || raw.SOURCE || {};
    var clean = {};
    ["source_page","section","cta_type","label"].forEach(function (key) {
      if (source[key] || source[key.toUpperCase()]) clean[key] = source[key] || source[key.toUpperCase()];
    });
    return {token:token,destinationKey:raw.destinationKey || raw.DESTINATIONKEY || "",source:clean};
  }

  var continuationCompletion = null;
  function completeContinuation() {
    var handoff = readHandoff();
    if (!handoff.token) return Promise.resolve(false);
    if (!continuationCompletion) {
      continuationCompletion = window.Api.acknowledgeAuthIntent(handoff.token).then(function (result) {
        if (!result || result.SUCCESS !== true || result.AUTH !== true || result.ACKNOWLEDGED !== true) { continuationCompletion = null; return false; }
        if (window.FPWAnalytics && typeof window.FPWAnalytics.track === "function") {
          window.FPWAnalytics.track("auth_continuation_success",Object.assign({},handoff.source,{destination_key:handoff.destinationKey}));
        }
        document.body.removeAttribute("data-auth-handoff");
        var current = new window.URL(window.location.href);
        current.searchParams.delete("authIntent");
        window.history.replaceState(window.history.state,"",current.pathname + current.search + current.hash);
        document.dispatchEvent(new CustomEvent("fpw:auth:continuation-complete"));
        return true;
      }).catch(function () { continuationCompletion = null; return false; });
    }
    return continuationCompletion;
  }

  document.addEventListener("DOMContentLoaded",function () {
    var handoff = readHandoff();
    if (handoff.destinationKey === "account" && window.location.pathname === BASE_PATH + "/app/account.cfm") completeContinuation();
  });

  var exported = {
    readHandoff: readHandoff,
    completeContinuation: completeContinuation,
    requireAuth: requireAuth,
    navigateContinuation: navigateContinuation,
    continueAuthentication: function (payload) { return window.Api.authContinue(payload); },
    loginUrl: LOGIN_PATH,
    redirectToLogin: redirectToLogin,
    ensureAuthenticated: ensureAuthenticated,
    handleUnauthorizedError: handleUnauthorizedError,
    isUnauthorizedResponse: isUnauthorizedResponse
  };

  if (!window.AppAuth) {
    window.AppAuth = exported;
    return;
  }

  Object.assign(window.AppAuth, exported);

})(window);
