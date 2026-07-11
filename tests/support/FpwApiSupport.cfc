component output="false" {

  variables.baseUrl = "http://localhost:8500/fpw";
  variables.authEmail = "";
  variables.authPassword = "";
  variables.cookieHeader = "";

  public any function init(string baseUrl="http://localhost:8500/fpw", string authEmail="", string authPassword="", boolean inheritCookie=true) output="false" {
    variables.baseUrl = reReplace(arguments.baseUrl, "/+$", "", "all");
    variables.authEmail = arguments.authEmail;
    variables.authPassword = arguments.authPassword;
    variables.cookieHeader = arguments.inheritCookie ? buildCookieHeaderFromScope() : "";
    return this;
  }

  public struct function ensureApprovedSession() output="false" {
    if (len(variables.cookieHeader)) {
      return { SUCCESS = true, COOKIE = variables.cookieHeader };
    }
    if (!len(trim(variables.authEmail)) OR !len(trim(variables.authPassword))) {
      throw(message = "No inherited session or explicit disposable test credentials were provided.");
    }
    var loginPayload = postJson("/api/v1/auth.cfc?method=handle", {
      action = "login",
      email = variables.authEmail,
      password = variables.authPassword
    }, false);
    if (!structKeyExists(loginPayload, "SUCCESS") OR loginPayload.SUCCESS NEQ true) {
      throw(message = "Unable to establish approved auth session.", detail = serializeJSON(loginPayload));
    }
    return loginPayload;
  }

  public struct function getJson(required string path) output="false" {
    ensureApprovedSession();
    return sendJsonRequest("GET", arguments.path, {});
  }

  public string function getPlain(required string path, boolean requireSession=true) output="false" {
    var httpResult = {};
    var testUserIdHeader = resolveTestUserIdHeader();
    if (arguments.requireSession) {
      ensureApprovedSession();
    }
    cfhttp(url = buildUrl(arguments.path), method = "get", result = "httpResult", charset = "utf-8") {
      if (len(variables.cookieHeader)) {
        cfhttpparam(type = "header", name = "Cookie", value = variables.cookieHeader);
      }
      if (len(testUserIdHeader)) {
        cfhttpparam(type = "header", name = "X-FPW-Test-UserId", value = testUserIdHeader);
      }
    }
    updateCookieHeader(httpResult);
    return structKeyExists(httpResult, "fileContent") ? trim(httpResult.fileContent) : "";
  }

  public struct function postJson(required string path, struct payload={}, boolean requireSession=true, boolean includeCsrf=true) output="false" {
    if (arguments.requireSession) {
      ensureApprovedSession();
    }
    return sendJsonRequest("POST", arguments.path, arguments.payload, arguments.includeCsrf);
  }

  public struct function listVessels(numeric limit=100) output="false" {
    return getJson("/api/v1/vessels.cfc?method=handle&limit=" & arguments.limit);
  }

  public struct function saveVessel(required struct vessel) output="false" {
    return postJson("/api/v1/vessel.cfc?method=handle", {
      action = "save",
      vessel = arguments.vessel
    });
  }

  public struct function canDeleteVessel(required numeric vesselId) output="false" {
    return postJson("/api/v1/vessel.cfc?method=handle", {
      action = "candelete",
      vesselId = arguments.vesselId
    });
  }

  public struct function deleteVessel(required numeric vesselId) output="false" {
    return postJson("/api/v1/vessel.cfc?method=handle", {
      action = "delete",
      vesselId = arguments.vesselId
    });
  }

  public struct function listOperators(numeric limit=100) output="false" {
    return getJson("/api/v1/operators.cfc?method=handle&limit=" & arguments.limit);
  }

  public struct function saveOperator(required struct operator) output="false" {
    return postJson("/api/v1/operator.cfc?method=handle", {
      action = "save",
      operator = arguments.operator
    });
  }

  public struct function canDeleteOperator(required numeric operatorId) output="false" {
    return postJson("/api/v1/operator.cfc?method=handle", {
      action = "candelete",
      operatorId = arguments.operatorId
    });
  }

  public struct function deleteOperator(required numeric operatorId) output="false" {
    return postJson("/api/v1/operator.cfc?method=handle", {
      action = "delete",
      operatorId = arguments.operatorId
    });
  }

  public struct function listContacts(numeric limit=100) output="false" {
    return getJson("/api/v1/contacts.cfc?method=handle&limit=" & arguments.limit);
  }

  public struct function saveContact(required struct contact) output="false" {
    return postJson("/api/v1/contact.cfc?method=handle", {
      action = "save",
      contact = arguments.contact
    });
  }

  public struct function canDeleteContact(required numeric contactId) output="false" {
    return postJson("/api/v1/contact.cfc?method=handle", {
      action = "candelete",
      contactId = arguments.contactId
    });
  }

  public struct function deleteContact(required numeric contactId) output="false" {
    return postJson("/api/v1/contact.cfc?method=handle", {
      action = "delete",
      contactId = arguments.contactId
    });
  }

  public struct function listPassengers(numeric limit=100) output="false" {
    return getJson("/api/v1/passengers.cfc?method=handle&limit=" & arguments.limit);
  }

  public struct function savePassenger(required struct passenger) output="false" {
    return postJson("/api/v1/passenger.cfc?method=handle", {
      action = "save",
      passenger = arguments.passenger
    });
  }

  public struct function canDeletePassenger(required numeric passengerId) output="false" {
    return postJson("/api/v1/passenger.cfc?method=handle", {
      action = "candelete",
      passengerId = arguments.passengerId
    });
  }

  public struct function deletePassenger(required numeric passengerId) output="false" {
    return postJson("/api/v1/passenger.cfc?method=handle", {
      action = "delete",
      passengerId = arguments.passengerId
    });
  }

  public struct function listWaypoints(numeric limit=100) output="false" {
    return getJson("/api/v1/waypoints.cfc?method=handle&limit=" & arguments.limit);
  }

  public struct function saveWaypoint(required struct waypoint) output="false" {
    return postJson("/api/v1/waypoint.cfc?method=handle", {
      action = "save",
      waypoint = arguments.waypoint
    });
  }

  public struct function canDeleteWaypoint(required numeric waypointId) output="false" {
    return postJson("/api/v1/waypoint.cfc?method=handle", {
      action = "candelete",
      waypointId = arguments.waypointId
    });
  }

  public struct function deleteWaypoint(required numeric waypointId) output="false" {
    return postJson("/api/v1/waypoint.cfc?method=handle", {
      action = "delete",
      waypointId = arguments.waypointId
    });
  }

  public struct function listFloatPlans(numeric limit=5) output="false" {
    return getJson("/api/v1/floatplans.cfc?method=handle&limit=" & arguments.limit);
  }

  public struct function bootstrapFloatPlan(numeric floatPlanId=0) output="false" {
    if (arguments.floatPlanId GT 0) {
      return getJson("/api/v1/floatplan.cfc?method=handle&action=bootstrap&id=" & arguments.floatPlanId);
    }
    return getJson("/api/v1/floatplan.cfc?method=handle&action=bootstrap");
  }

  public struct function saveFloatPlan(required struct floatPlan, array passengers=[], array contacts=[], array waypoints=[]) output="false" {
    return postJson("/api/v1/floatplan.cfc?method=handle", {
      action = "save",
      FLOATPLAN = arguments.floatPlan,
      PASSENGERS = arguments.passengers,
      CONTACTS = arguments.contacts,
      WAYPOINTS = arguments.waypoints
    });
  }

  public struct function sendFloatPlan(required numeric floatPlanId) output="false" {
    return postJson("/api/v1/floatplan.cfc?method=handle", {
      action = "send",
      floatPlanId = arguments.floatPlanId
    });
  }

  public struct function checkinFloatPlan(required numeric floatPlanId) output="false" {
    return postJson("/api/v1/floatplan.cfc?method=handle", {
      action = "checkin",
      floatPlanId = arguments.floatPlanId
    });
  }

  public struct function deleteFloatPlan(required numeric floatPlanId) output="false" {
    return postJson("/api/v1/floatplan.cfc?method=handle", {
      action = "delete",
      floatPlanId = arguments.floatPlanId
    });
  }

  public struct function routeBuilder(required string action, struct payload={}) output="false" {
    return postJson("/api/v1/routeBuilder.cfc?method=handle&action=" & arguments.action, arguments.payload);
  }

  public string function createFloatPlanPdf(required numeric floatPlanId) output="false" {
    return getPlain("/api/api_assets/floatPlanUtils.cfc?method=createPDF&floatPlanId=" & arguments.floatPlanId);
  }

  public string function getBaseUrl() output="false" {
    return variables.baseUrl;
  }

  public string function getCookieHeader() output="false" {
    return variables.cookieHeader;
  }

  private struct function sendJsonRequest(required string method, required string path, struct payload={}, boolean includeCsrf=true) output="false" {
    var httpResult = {};
    var fullUrl = buildUrl(arguments.path);
    var response = {};
    var testUserIdHeader = resolveTestUserIdHeader();
    var adminCsrfToken = arguments.includeCsrf AND structKeyExists(session, "fpwAdminCsrfToken") ? trim(toString(session.fpwAdminCsrfToken)) : "";

    if (arguments.method EQ "GET") {
      cfhttp(url = fullUrl, method = "get", result = "httpResult", charset = "utf-8") {
        if (len(variables.cookieHeader)) {
          cfhttpparam(type = "header", name = "Cookie", value = variables.cookieHeader);
        }
        if (len(testUserIdHeader)) {
          cfhttpparam(type = "header", name = "X-FPW-Test-UserId", value = testUserIdHeader);
        }
      }
    } else {
      cfhttp(url = fullUrl, method = "post", result = "httpResult", charset = "utf-8") {
        cfhttpparam(type = "header", name = "Content-Type", value = "application/json");
        if (len(variables.cookieHeader)) {
          cfhttpparam(type = "header", name = "Cookie", value = variables.cookieHeader);
        }
        if (len(testUserIdHeader)) {
          cfhttpparam(type = "header", name = "X-FPW-Test-UserId", value = testUserIdHeader);
        }
        if (len(adminCsrfToken)) {
          cfhttpparam(type = "header", name = "X-CSRF-Token", value = adminCsrfToken);
        }
        cfhttpparam(type = "body", value = serializeJSON(arguments.payload));
      }
    }

    updateCookieHeader(httpResult);
    response = parseResponse(httpResult);
    response.STATUS_CODE = structKeyExists(httpResult, "statusCode") ? httpResult.statusCode : "";
    response.HTTP_FILECONTENT = structKeyExists(httpResult, "fileContent") ? httpResult.fileContent : "";
    return response;
  }

  private string function buildUrl(required string path) output="false" {
    if (reFindNoCase("^https?://", arguments.path)) {
      return arguments.path;
    }
    if (left(arguments.path, 1) EQ "/") {
      return variables.baseUrl & arguments.path;
    }
    return variables.baseUrl & "/" & arguments.path;
  }

  private string function buildCookieHeaderFromScope() output="false" {
    var cookiePairs = [];
    if (isDefined("cookie.CFID") && len(trim(toString(cookie.CFID)))) {
      arrayAppend(cookiePairs, "CFID=" & trim(toString(cookie.CFID)));
    }
    if (isDefined("cookie.CFTOKEN") && len(trim(toString(cookie.CFTOKEN)))) {
      arrayAppend(cookiePairs, "CFTOKEN=" & trim(toString(cookie.CFTOKEN)));
    }
    if (isDefined("cookie.JSESSIONID") && len(trim(toString(cookie.JSESSIONID)))) {
      arrayAppend(cookiePairs, "JSESSIONID=" & trim(toString(cookie.JSESSIONID)));
    }
    return arrayLen(cookiePairs) ? arrayToList(cookiePairs, "; ") : "";
  }

  private string function resolveTestUserIdHeader() output="false" {
    var candidate = 0;
    if ( structKeyExists( url, "testUserId" ) AND isNumeric( url.testUserId ) ) {
      candidate = val( url.testUserId );
    }
    if (structKeyExists(session, "user") AND isStruct(session.user)) {
      if (candidate LTE 0 AND structKeyExists(session.user, "userId") AND isNumeric(session.user.userId)) {
        candidate = val(session.user.userId);
      } else if (candidate LTE 0 AND structKeyExists(session.user, "id") AND isNumeric(session.user.id)) {
        candidate = val(session.user.id);
      } else if (candidate LTE 0 AND structKeyExists(session.user, "USERID") AND isNumeric(session.user.USERID)) {
        candidate = val(session.user.USERID);
      }
    }
    return candidate GT 0 ? toString(candidate) : "";
  }

  private void function updateCookieHeader(required struct httpResult) output="false" {
    var headers = structKeyExists(arguments.httpResult, "responseHeader") ? arguments.httpResult.responseHeader : {};
    var setCookie = "";
    var cookieList = [];
    var i = 0;
    var headerName = "";
    var cookieLine = "";
    var pair = "";
    var cookieName = "";
    var cookieMatch = {};

    if (isStruct(headers)) {
      for (headerName in headers) {
        if (compareNoCase(headerName, "Set-Cookie") EQ 0) {
          setCookie = headers[headerName];
          break;
        }
      }
    }

    if (isArray(setCookie)) {
      cookieList = setCookie;
    } else if (isSimpleValue(setCookie) AND len(trim(setCookie))) {
      cookieList = listToArray(setCookie, chr(10));
    }

    if (!arrayLen(cookieList)) {
      return;
    }

    var cookieMap = {};
    if (len(variables.cookieHeader)) {
      var existingPairs = listToArray(variables.cookieHeader, ";");
      for (i = 1; i LTE arrayLen(existingPairs); i++) {
        pair = trim(existingPairs[i]);
        if (listLen(pair, "=") GTE 2) {
          cookieMap[listFirst(pair, "=")] = pair;
        }
      }
    }

    for (i = 1; i LTE arrayLen(cookieList); i++) {
      cookieLine = trim(cookieList[i]);
      if (!len(cookieLine)) {
        continue;
      }
      pair = trim(listFirst(cookieLine, ";"));
      if (listLen(pair, "=") GTE 2) {
        cookieMap[listFirst(pair, "=")] = pair;
      }
      for (cookieName in ["CFID", "CFTOKEN", "JSESSIONID"]) {
        cookieMatch = reFindNoCase("(^|[ ,;])(" & cookieName & "=[^;, ]+)", cookieLine, 1, true);
        if (arrayLen(cookieMatch.pos) GTE 3 AND cookieMatch.pos[3] GT 0) {
          cookieMap[cookieName] = mid(cookieLine, cookieMatch.pos[3], cookieMatch.len[3]);
        }
      }
    }

    variables.cookieHeader = structCount(cookieMap) ? arrayToList(structValueArray(cookieMap), "; ") : variables.cookieHeader;
  }

  private struct function parseResponse(required struct httpResult) output="false" {
    var raw = structKeyExists(arguments.httpResult, "fileContent") ? trim(arguments.httpResult.fileContent) : "";
    if (!len(raw)) {
      return {};
    }
    try {
      return deserializeJSON(raw, false);
    } catch (any err) {
      return {
        SUCCESS = false,
        MESSAGE = "Non-JSON response from API",
        RAW = raw,
        ERROR = "NON_JSON"
      };
    }
  }
}








