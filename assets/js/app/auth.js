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

  var exported = {
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
