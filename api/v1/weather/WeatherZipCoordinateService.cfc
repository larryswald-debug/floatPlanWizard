component output="false" {

  public any function init(string dataPath = "") {
    variables.dataPath = len(arguments.dataPath)
      ? arguments.dataPath
      : getDirectoryFromPath(getCurrentTemplatePath()) & "data/zcta2025_coordinates.csv";
    variables.source = "CENSUS_ZCTA_GAZETTEER";
    variables.sourceLabel = "U.S. Census Gazetteer ZCTA representative coordinate";
    variables.cacheKey = "fpwWeatherZipCoordinates_" & hash(variables.dataPath);
    return this;
  }

  public struct function lookup(required string zip) {
    var result = emptyResult();
    result.zip = trim(toString(arguments.zip));

    if (!reFind("^[0-9]{5}$", result.zip)) {
      result.reason = "INVALID_ZIP";
      result.zip = "";
      arrayAppend(result.warnings, "Enter a valid 5-digit ZIP code.");
      return result;
    }

    var coordinates = getIndex();
    if (!structKeyExists(coordinates, result.zip)) {
      result.reason = "ZIP_NOT_FOUND";
      result.displayName = "ZIP area " & result.zip;
      arrayAppend(result.warnings, "No approved ZIP-area coordinate was found for ZIP " & result.zip & ".");
      return result;
    }

    result.found = true;
    result.lat = coordinates[result.zip].lat;
    result.lon = coordinates[result.zip].lon;
    result.displayName = "ZIP area " & result.zip;
    result.source = variables.source;
    result.sourceLabel = variables.sourceLabel;
    result.isApproximate = true;
    arrayAppend(result.warnings, approximationWarning());
    return result;
  }

  public string function approximationWarning() {
    return "ZIP-area coordinates are approximate and may not match exact marina or home-port location.";
  }

  public struct function emptyResult() {
    return {
      "found" = false,
      "zip" = "",
      "lat" = javacast("null", ""),
      "lon" = javacast("null", ""),
      "displayName" = "",
      "source" = variables.source,
      "sourceLabel" = variables.sourceLabel,
      "isApproximate" = false,
      "warnings" = [],
      "reason" = ""
    };
  }

  private struct function getIndex() {
    if (structKeyExists(application, variables.cacheKey) && isStruct(application[variables.cacheKey])) {
      return application[variables.cacheKey];
    }

    lock name=variables.cacheKey type="exclusive" timeout=10 {
      if (!structKeyExists(application, variables.cacheKey) || !isStruct(application[variables.cacheKey])) {
        application[variables.cacheKey] = loadIndex();
      }
    }

    return application[variables.cacheKey];
  }

  private struct function loadIndex() {
    var index = {};
    if (!fileExists(variables.dataPath)) {
      return index;
    }

    var rows = listToArray(fileRead(variables.dataPath), chr(10));
    for (var i = 2; i <= arrayLen(rows); i++) {
      var line = trim(rows[i]);
      if (!len(line)) {
        continue;
      }
      var columns = listToArray(line, ",", true);
      if (arrayLen(columns) LT 3) {
        continue;
      }
      var zip = trim(columns[1]);
      var lat = trim(columns[2]);
      var lon = trim(columns[3]);
      if (reFind("^[0-9]{5}$", zip) && isValidCoordinatePair(lat, lon)) {
        index[zip] = {
          "lat" = val(lat),
          "lon" = val(lon)
        };
      }
    }

    return index;
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
}
