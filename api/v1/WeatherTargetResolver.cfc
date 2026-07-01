component output="false" {

  public any function init(string dsn = "") {
    variables.dsn = len(arguments.dsn) ? arguments.dsn : (structKeyExists(application, "dsn") ? application.dsn : "");
    variables.userAgent = "FloatPlanWizard Weather Rewrite Phase 1 (https://floatplanwizard.com)";
    return this;
  }

  public struct function resolve(required numeric userId, struct request = {}) {
    var result = emptyTarget();
    var latRaw = readParam(arguments.request, ["lat", "latitude"]);
    var lonRaw = readParam(arguments.request, ["lon", "lng", "longitude"]);
    var zipRaw = rereplace(readParam(arguments.request, ["zip"]), "[^0-9]", "", "all");

    if (len(latRaw) || len(lonRaw)) {
      if (!isValidCoordinatePair(latRaw, lonRaw)) {
        result.sourceType = "fallback";
        arrayAppend(result.warnings, "Invalid coordinates supplied.");
        result.reason = "INVALID_COORDINATES";
        return result;
      }
      result.sourceType = "coordinates";
      result.lat = val(latRaw);
      result.lon = val(lonRaw);
      result.displayName = decimalFormat(result.lat) & ", " & decimalFormat(result.lon);
      result.available = true;
      return result;
    }

    if (len(zipRaw) EQ 5) {
      result = resolveZip(zipRaw);
      result.sourceType = "manual ZIP";
      return result;
    }

    result = resolveHomePort(arguments.userId);
    if (result.available) {
      return result;
    }

    result.sourceType = "fallback";
    result.reason = "NO_TARGET";
    arrayAppend(result.warnings, "No home-port, ZIP, or coordinate weather target was available.");
    return result;
  }

  public struct function resolveHomePort(required numeric userId) {
    var result = emptyTarget();
    result.sourceType = "homeport";

    if (!len(variables.dsn) || arguments.userId LTE 0) {
      result.reason = "NO_USER_CONTEXT";
      arrayAppend(result.warnings, "Home-port lookup was not available.");
      return result;
    }

    try {
      var qHome = queryExecute(
        "SELECT city, state, zip, lat, lng
           FROM users_address
          WHERE userId = :userId
            AND isHomePort = 1
          ORDER BY recId DESC
          LIMIT 1",
        { "userId" = { "value" = arguments.userId, "cfsqltype" = "cf_sql_integer" } },
        { "datasource" = variables.dsn }
      );

      if (qHome.recordCount EQ 0) {
        result.reason = "NO_HOMEPORT";
        arrayAppend(result.warnings, "No home-port row was found for this user.");
        return result;
      }

      result.zip = normalizeZip(qHome.zip[1]);
      var nameParts = [];
      if (len(trim(qHome.city[1]))) {
        arrayAppend(nameParts, trim(qHome.city[1]));
      }
      if (len(trim(qHome.state[1]))) {
        arrayAppend(nameParts, trim(qHome.state[1]));
      }
      result.displayName = arrayToList(nameParts, ", ");

      if (isNumeric(qHome.lat[1]) && isNumeric(qHome.lng[1])) {
        result.lat = val(qHome.lat[1]);
        result.lon = val(qHome.lng[1]);
        result.available = true;
        if (!len(result.displayName)) {
          result.displayName = len(result.zip) ? "ZIP " & result.zip : decimalFormat(result.lat) & ", " & decimalFormat(result.lon);
        }
        return result;
      }

      if (len(result.zip) EQ 5) {
        var zipTarget = resolveZip(result.zip);
        zipTarget.sourceType = "homeport";
        if (len(result.displayName)) {
          zipTarget.displayName = result.displayName;
        }
        return zipTarget;
      }

      result.reason = "HOMEPORT_NO_COORDINATES";
      arrayAppend(result.warnings, "Home-port row did not include usable coordinates or ZIP.");
      return result;
    } catch (any err) {
      result.reason = "HOMEPORT_LOOKUP_FAILED";
      arrayAppend(result.warnings, "Home-port lookup failed.");
      return result;
    }
  }

  public struct function resolveZip(required string zip) {
    var result = emptyTarget();
    result.zip = normalizeZip(arguments.zip);
    result.displayName = "ZIP " & result.zip;

    if (len(result.zip) NEQ 5) {
      result.reason = "INVALID_ZIP";
      arrayAppend(result.warnings, "ZIP must be 5 digits.");
      return result;
    }

    try {
      var url = "https://geocoding.geo.census.gov/geocoder/locations/onelineaddress?format=json&benchmark=Public_AR_Current&address=" & urlEncodedFormat(result.zip);
      cfhttp(method="GET", url=url, result="local.http", timeout=4) {
        cfhttpparam(type="header", name="User-Agent", value=variables.userAgent);
        cfhttpparam(type="header", name="Accept", value="application/json");
      }

      if (!structKeyExists(local, "http") || val(local.http.statusCode) LT 200 || val(local.http.statusCode) GTE 300) {
        result.reason = "ZIP_GEOCODER_FAILED";
        arrayAppend(result.warnings, "ZIP resolver did not return a usable response.");
        return result;
      }

      var parsed = deserializeJSON(local.http.fileContent);
      var matches = parsed.result.addressMatches ?: [];
      if (!isArray(matches) || arrayLen(matches) EQ 0) {
        result.reason = "ZIP_NOT_FOUND";
        arrayAppend(result.warnings, "ZIP resolver did not find coordinates.");
        return result;
      }

      var firstMatch = matches[1];
      var coords = firstMatch.coordinates ?: {};
      if (!isNumeric(coords.y ?: "") || !isNumeric(coords.x ?: "")) {
        result.reason = "ZIP_NO_COORDINATES";
        arrayAppend(result.warnings, "ZIP resolver result did not include coordinates.");
        return result;
      }

      result.lat = val(coords.y);
      result.lon = val(coords.x);
      result.displayName = len(firstMatch.matchedAddress ?: "") ? firstMatch.matchedAddress : result.displayName;
      result.available = true;
      return result;
    } catch (any err) {
      result.reason = "ZIP_GEOCODER_ERROR";
      arrayAppend(result.warnings, "ZIP resolver failed.");
      return result;
    }
  }

  public struct function emptyTarget() {
    return {
      "available" = false,
      "sourceType" = "",
      "displayName" = "",
      "zip" = "",
      "lat" = javacast("null", ""),
      "lon" = javacast("null", ""),
      "timezone" = "",
      "warnings" = [],
      "reason" = ""
    };
  }

  private string function readParam(required struct source, required array names) {
    for (var name in arguments.names) {
      if (structKeyExists(arguments.source, name) && !isNull(arguments.source[name]) && len(trim(toString(arguments.source[name])))) {
        return trim(toString(arguments.source[name]));
      }
    }
    return "";
  }

  private boolean function isValidCoordinatePair(required string latRaw, required string lonRaw) {
    if (!isNumeric(arguments.latRaw) || !isNumeric(arguments.lonRaw)) {
      return false;
    }
    var lat = val(arguments.latRaw);
    var lon = val(arguments.lonRaw);
    return lat GTE -90 && lat LTE 90 && lon GTE -180 && lon LTE 180;
  }

  private string function normalizeZip(any rawZip = "") {
    var zip = rereplace(toString(arguments.rawZip), "[^0-9]", "", "all");
    return len(zip) GTE 5 ? left(zip, 5) : "";
  }
}

