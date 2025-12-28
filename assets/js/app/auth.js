// /fpw/assets/js/app/auth.js
(function (window) {
  "use strict";

  var BASE_PATH = window.FPW_BASE || "";
  var LOGIN_PATH = BASE_PATH + "/app/login.cfm";

  function redirectToLogin() {
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
