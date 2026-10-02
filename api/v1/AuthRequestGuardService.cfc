component output=false {
  public any function init() { return this; }

  public string function getOrCreateCsrfToken() {
    lock scope="session" type="exclusive" timeout=5 {
      if (!structKeyExists(session, "fpwAuthCsrfToken") || !isSimpleValue(session.fpwAuthCsrfToken)
          || !reFind("^[a-f0-9]{64}$", toString(session.fpwAuthCsrfToken))) {
        session.fpwAuthCsrfToken = newToken();
      }
      return session.fpwAuthCsrfToken;
    }
  }

  public string function rotateCsrfToken() {
    lock scope="session" type="exclusive" timeout=5 {
      session.fpwAuthCsrfToken = newToken();
      return session.fpwAuthCsrfToken;
    }
  }

  public struct function validateMutation(struct body={}) {
    var candidate = "";
    var expected = "";
    if (structKeyExists(cgi, "http_x_csrf_token") && len(trim(toString(cgi.http_x_csrf_token)))) {
      candidate = trim(toString(cgi.http_x_csrf_token));
    } else if (structKeyExists(arguments.body, "csrfToken") && isSimpleValue(arguments.body.csrfToken)) {
      candidate = trim(toString(arguments.body.csrfToken));
    } else if (structKeyExists(form, "csrfToken") && isSimpleValue(form.csrfToken)) {
      candidate = trim(toString(form.csrfToken));
    }
    lock scope="session" type="readonly" timeout=5 {
      if (structKeyExists(session, "fpwAuthCsrfToken") && isSimpleValue(session.fpwAuthCsrfToken)) {
        expected = toString(session.fpwAuthCsrfToken);
      }
    }
    return validateRequest(
      method=structKeyExists(cgi, "request_method") ? toString(cgi.request_method) : "",
      expectedOrigin=getRequestOrigin(),
      origin=structKeyExists(cgi, "http_origin") ? toString(cgi.http_origin) : "",
      referer=structKeyExists(cgi, "http_referer") ? toString(cgi.http_referer) : "",
      candidate=candidate, expected=expected
    );
  }

  // Nonremote pure validation also permits focused tests without changing the session.
  public struct function validateRequest(required string method, required string expectedOrigin,
      string origin="", string referer="", string candidate="", string expected="") {
    if (compareNoCase(arguments.method, "POST") != 0) {
      return denied(405, "METHOD_NOT_ALLOWED", "Use POST for this request.");
    }
    var target = normalizeOrigin(arguments.expectedOrigin);
    if (!len(target)) return denied(403, "ORIGIN_INVALID", "The request origin is not allowed.");
    if (len(arguments.origin) && compare(normalizeOrigin(arguments.origin), target) != 0) {
      return denied(403, "ORIGIN_INVALID", "The request origin is not allowed.");
    }
    if (len(arguments.referer) && compare(normalizeOrigin(arguments.referer, true), target) != 0) {
      return denied(403, "ORIGIN_INVALID", "The request origin is not allowed.");
    }
    if (!reFind("^[a-f0-9]{64}$", arguments.candidate)
        || !reFind("^[a-f0-9]{64}$", arguments.expected)
        || !createObject("java", "java.security.MessageDigest").isEqual(
          charsetDecode(arguments.candidate, "UTF-8"), charsetDecode(arguments.expected, "UTF-8"))) {
      return denied(403, "CSRF_INVALID", "Your session changed. Refresh and try again.");
    }
    return {ALLOWED=true, STATUSCODE=200, CODE="", MESSAGE=""};
  }

  public string function getClientIp() {
    // CF-Connecting-IP/X-Forwarded-For are not trusted until proxy restoration is verified.
    var address = structKeyExists(cgi, "remote_addr") ? lCase(trim(toString(cgi.remote_addr))) : "";
    if (!len(address) || len(address) > 45 || !reFind("^[0-9a-f:.]+$", address)) return "";
    return address;
  }

  public string function getRequestOrigin() {
    var host = structKeyExists(cgi, "http_host") ? lCase(trim(toString(cgi.http_host))) : "";
    var secure = structKeyExists(cgi, "https") && listFindNoCase("on,1,true,yes", toString(cgi.https));
    // Production uses HTTPS through Cloudflare; no forwarded header is trusted here.
    if (listFindNoCase("floatplanwizard.com,www.floatplanwizard.com", host)) secure = true;
    return normalizeOrigin((secure ? "https://" : "http://") & host);
  }

  public string function normalizeOrigin(required string value, boolean allowPath=false) {
    if (!len(arguments.value) || compare(arguments.value, trim(arguments.value)) != 0
        || find(chr(92), arguments.value) || reFind("[[:cntrl:][:space:]]", arguments.value)) return "";
    try {
      var uri = createObject("java", "java.net.URI").init(arguments.value);
      var scheme = isNull(uri.getScheme()) ? "" : lCase(toString(uri.getScheme()));
      var host = isNull(uri.getHost()) ? "" : lCase(toString(uri.getHost()));
      var path = isNull(uri.getRawPath()) ? "" : toString(uri.getRawPath());
      if (!listFind("http,https", scheme) || !len(host) || !isNull(uri.getRawUserInfo())
          || !isNull(uri.getRawFragment()) || (!arguments.allowPath && (len(path) || !isNull(uri.getRawQuery())))) return "";
      var port = uri.getPort();
      if (port > 65535 || port == 0) return "";
      if ((scheme == "http" && port == 80) || (scheme == "https" && port == 443)) port = -1;
      return scheme & "://" & host & (port == -1 ? "" : ":" & port);
    } catch (any ignored) { return ""; }
  }

  private string function newToken() {
    return lCase(binaryEncode(binaryDecode(generateSecretKey("AES", 256), "base64"), "hex"));
  }

  private struct function denied(required numeric status, required string code, required string message) {
    return {ALLOWED=false, STATUSCODE=arguments.status, CODE=arguments.code, MESSAGE=arguments.message};
  }
}
