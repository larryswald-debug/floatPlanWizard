component output="false" {

  public any function init(string dsn = "", any zipService = "") {
    variables.dsn = len(arguments.dsn) ? arguments.dsn : (structKeyExists(application, "dsn") ? application.dsn : "");
    variables.userAgent = "FloatPlanWizard Weather Rewrite Phase 1 (https://floatplanwizard.com)";
    variables.zipService = isObject(arguments.zipService) ? arguments.zipService : createObject("component", "fpw.api.v1.weather.WeatherZipCoordinateService").init();
    return this;
  }

  public struct function resolve(required numeric userId, struct request = {}) {
    var result = emptyTarget();
    var latRaw = readParam(arguments.request, ["lat", "latitude"]);
    var lonRaw = readParam(arguments.request, ["lon", "lng", "longitude"]);
    var zipRaw = readParam(arguments.request, ["zip"]);

    if (len(latRaw) || len(lonRaw)) {
      if (!isValidCoordinatePair(latRaw, lonRaw)) {
        result.sourceType = "fallback";
        arrayAppend(result.warnings, "The coordinates entered were not valid.");
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

    if (len(zipRaw)) {
      if (!isFiveDigitZip(zipRaw)) {
        return invalidZipTarget(zipRaw);
      }
      return resolveZip(trim(zipRaw));
    }

    result = resolveHomePort(arguments.userId);
    if (result.available) {
      return result;
    }

    var zipCandidate = "";
    if (len(result.zip) EQ 5) {
      zipCandidate = result.zip;
    }

    if (len(zipCandidate) EQ 5) {
      return resolveZip(zipCandidate);
    }

    if (result.reason EQ "HOMEPORT_NO_COORDINATES" || result.reason EQ "HOMEPORT_INVALID_COORDINATES" || result.reason EQ "NO_HOMEPORT") {
      return result;
    }

    result.sourceType = "fallback";
    result.reason = "NO_TARGET";
    arrayAppend(result.warnings, "No home-port coordinates or explicit coordinate weather target was available.");
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

      if (isValidCoordinatePair(qHome.lat[1], qHome.lng[1])) {
        result.lat = val(qHome.lat[1]);
        result.lon = val(qHome.lng[1]);
        result.available = true;
        if (!len(result.displayName)) {
          result.displayName = len(result.zip) ? "ZIP " & result.zip : decimalFormat(result.lat) & ", " & decimalFormat(result.lon);
        }
        result = reconcileHomePortWithZip(result);
        return result;
      }

      if ((isNumeric(qHome.lat[1]) || isNumeric(qHome.lng[1])) && !isValidCoordinatePair(qHome.lat[1], qHome.lng[1])) {
        result.reason = "HOMEPORT_INVALID_COORDINATES";
        arrayAppend(result.warnings, "Weather needs a saved home-port location with coordinates.");
        return result;
      }

      result.reason = "HOMEPORT_NO_COORDINATES";
      arrayAppend(result.warnings, "Weather needs a saved home-port location with coordinates.");
      return result;
    } catch (any err) {
      result.reason = "HOMEPORT_LOOKUP_FAILED";
      arrayAppend(result.warnings, "Home-port lookup failed.");
      return result;
    }
  }

  public struct function resolveZip(required string zip) {
    var result = emptyTarget();
    var zipLookup = variables.zipService.lookup(trim(arguments.zip));
    result.zip = zipLookup.zip;
    result.displayName = len(zipLookup.displayName) ? zipLookup.displayName : "ZIP area " & result.zip;
    result.sourceType = "zip_zcta";
    result.source = zipLookup.source ?: "";
    result.sourceLabel = zipLookup.sourceLabel ?: "";
    result.isApproximate = zipLookup.isApproximate ?: false;
    result.warnings = duplicate(zipLookup.warnings);

    if (!zipLookup.found) {
      result.reason = len(zipLookup.reason) ? zipLookup.reason : "ZIP_NOT_FOUND";
      return result;
    }

    result.lat = zipLookup.lat;
    result.lon = zipLookup.lon;
    result.available = true;
    return result;
  }

  private struct function reconcileHomePortWithZip(required struct target) {
    if (len(arguments.target.zip) NEQ 5 || !isObject(variables.zipService)) {
      return arguments.target;
    }

    var zipLookup = variables.zipService.lookup(arguments.target.zip);
    if (!zipLookup.found || !isValidCoordinatePair(toString(zipLookup.lat), toString(zipLookup.lon))) {
      return arguments.target;
    }

    var distanceMiles = haversineMiles(arguments.target.lat, arguments.target.lon, zipLookup.lat, zipLookup.lon);
    if (distanceMiles LTE 75) {
      return arguments.target;
    }

    arguments.target.lat = zipLookup.lat;
    arguments.target.lon = zipLookup.lon;
    arguments.target.sourceType = "homeport_zip_zcta";
    arguments.target.source = zipLookup.source ?: "";
    arguments.target.sourceLabel = zipLookup.sourceLabel ?: "";
    arguments.target.isApproximate = true;
    arrayAppend(arguments.target.warnings, "Saved home-port coordinates did not match the ZIP area; using approved ZIP-area coordinates.");
    arrayAppend(arguments.target.warnings, "ZIP-area coordinates are approximate and may not match exact marina or home-port location.");
    return arguments.target;
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
      "source" = "",
      "sourceLabel" = "",
      "isApproximate" = false,
      "warnings" = [],
      "reason" = ""
    };
  }

  private struct function invalidZipTarget(required string zipRaw) {
    var result = emptyTarget();
    result.sourceType = "fallback";
    result.reason = "INVALID_ZIP";
    result.zip = "";
    result.displayName = "ZIP " & trim(arguments.zipRaw);
    arrayAppend(result.warnings, "Enter a valid 5-digit ZIP code.");
    return result;
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
    if (lat EQ 0 && lon EQ 0) {
      return false;
    }
    return lat GTE -90 && lat LTE 90 && lon GTE -180 && lon LTE 180;
  }

  private string function normalizeZip(any rawZip = "") {
    var zip = rereplace(toString(arguments.rawZip), "[^0-9]", "", "all");
    return len(zip) GTE 5 ? left(zip, 5) : "";
  }

  private boolean function isFiveDigitZip(required string zipRaw) {
    return reFind("^[0-9]{5}$", trim(arguments.zipRaw)) GT 0;
  }

  private numeric function haversineMiles(required numeric lat1, required numeric lon1, required numeric lat2, required numeric lon2) {
    var radius = 3958.8;
    var dLat = radians(arguments.lat2 - arguments.lat1);
    var dLon = radians(arguments.lon2 - arguments.lon1);
    var a = sin(dLat / 2) * sin(dLat / 2) + cos(radians(arguments.lat1)) * cos(radians(arguments.lat2)) * sin(dLon / 2) * sin(dLon / 2);
    var c = 2 * atn2(sqr(a), sqr(1 - a));
    return radius * c;
  }

  private numeric function radians(required numeric deg) {
    return arguments.deg * pi() / 180;
  }

  private numeric function atn2(required numeric y, required numeric x) {
    if (arguments.x GT 0) {
      return atn(arguments.y / arguments.x);
    }
    if (arguments.x LT 0 && arguments.y GTE 0) {
      return atn(arguments.y / arguments.x) + pi();
    }
    if (arguments.x LT 0 && arguments.y LT 0) {
      return atn(arguments.y / arguments.x) - pi();
    }
    if (arguments.x EQ 0 && arguments.y GT 0) {
      return pi() / 2;
    }
    if (arguments.x EQ 0 && arguments.y LT 0) {
      return -pi() / 2;
    }
    return 0;
  }
}
