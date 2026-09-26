component output="false" {

  public string function buildPath(required string basePath, required struct values) {
    var action = "";
    var keys = [];
    var allowedKeys = "recoveryAction";
    var idKey = "";
    var idValue = "";
    var key = "";

    if (!isValidBasePath(arguments.basePath) OR !structKeyExists(arguments.values, "recoveryAction")
        OR !isSimpleValue(arguments.values.recoveryAction)) return "";
    action = toString(arguments.values.recoveryAction);
    if (!listFind("vessel,planner,routes,plans,route,draft", action)) return "";

    if (compare(action, "route") EQ 0) {
      if (structKeyExists(arguments.values, "routeId") EQ structKeyExists(arguments.values, "routeInstanceId")) return "";
      idKey = structKeyExists(arguments.values, "routeId") ? "routeId" : "routeInstanceId";
      allowedKeys &= "," & idKey;
    } else if (compare(action, "draft") EQ 0) {
      idKey = "floatPlanId";
      allowedKeys &= "," & idKey;
    }
    keys = structKeyArray(arguments.values);
    for (key in keys) {
      if (!listFindNoCase(allowedKeys, key)) return "";
    }
    if (len(idKey)) {
      if (!structKeyExists(arguments.values, idKey) OR !isSimpleValue(arguments.values[idKey])) return "";
      idValue = toString(arguments.values[idKey]);
      if (!reFind("^[1-9][0-9]{0,9}$", idValue) OR reFind("[^0-9]", idValue) OR val(idValue) GT 2147483647) return "";
    }
    return arguments.basePath & "/app/dashboard.cfm?recoveryAction=" & action
      & (len(idKey) ? "&" & idKey & "=" & idValue : "");
  }

  public string function validatePath(required string path, string basePath="") {
    var prefix = arguments.basePath & "/app/dashboard.cfm?";
    var queryText = "";
    var pairs = [];
    var pair = "";
    var equalsAt = 0;
    var key = "";
    var values = {};
    var canonical = "";

    if (!isValidBasePath(arguments.basePath) OR compare(left(arguments.path, len(prefix)), prefix) NEQ 0) return "";
    queryText = mid(arguments.path, len(prefix) + 1, len(arguments.path));
    if (!len(queryText)) return "";
    pairs = listToArray(queryText, "&", true);
    for (pair in pairs) {
      equalsAt = find("=", pair);
      if (equalsAt LTE 1 OR find("=", pair, equalsAt + 1)) return "";
      key = left(pair, equalsAt - 1);
      if (structKeyExists(values, key)) return "";
      values[key] = mid(pair, equalsAt + 1, len(pair));
    }
    canonical = buildPath(arguments.basePath, values);
    return len(canonical) AND compare(canonical, arguments.path) EQ 0 ? canonical : "";
  }

  private boolean function isValidBasePath(required string basePath) {
    return !len(arguments.basePath) OR (reFind("^(/[A-Za-z0-9_-]+)+$", arguments.basePath) EQ 1
      AND !reFind("[^/A-Za-z0-9_-]", arguments.basePath));
  }
}
