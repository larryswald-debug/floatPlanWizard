component output=false {

  remote struct function lookup(required numeric lat, required numeric lng) returnformat="json" output=false {
    var result = { success=false };
    if (!isNumeric(arguments.lat) || !isNumeric(arguments.lng)) {
      return result;
    }

    var latNum = val(arguments.lat);
    var lngNum = val(arguments.lng);

    var latRounded = round(latNum * 100000) / 100000;
    var lngRounded = round(lngNum * 100000) / 100000;
    var latKey = replace(numberFormat(latRounded, "0.00000"), ",", "", "all");
    var lngKey = replace(numberFormat(lngRounded, "0.00000"), ",", "", "all");
    var cacheKey = "fpw:marineName:" & latKey & ":" & lngKey;

    var cached = "";
    try { cached = cacheGet(cacheKey); } catch (any e) { cached = ""; }
    if (isStruct(cached) && structKeyExists(cached, "success")) {
      return cached;
    }

    var proxyBase = buildProxyBaseUrl();
    if (!len(proxyBase)) {
      return result;
    }

    var layers = "0,1,2,3,4,5,6,7,8,9,10,11,12";
    var radii = [50, 150, 400];
    var formats = ["application/json", "text/xml"];

    for (var r=1; r <= arrayLen(radii); r++) {
      for (var f=1; f <= arrayLen(formats); f++) {
        var bbox = buildBbox3857(latNum, lngNum, radii[r]);
        var responseText = fetchFeatureInfo(proxyBase, layers, bbox, formats[f]);
        var name = parseFeatureName(responseText, formats[f]);
        if (len(name)) {
          result = { success=true, name=name };
          cachePutSafe(cacheKey, result, 86400);
          return result;
        }
      }
    }

    cachePutSafe(cacheKey, result, 60);
    return result;
  }

  private string function buildProxyBaseUrl() {
    if (!structKeyExists(cgi, "http_host")) return "";
    var scheme = (structKeyExists(cgi, "https") && lcase(cgi.https) == "on") ? "https" : "http";
    return scheme & "://" & cgi.http_host & "/fpw/api/v1/wmsProxy.cfc";
  }

  private struct function buildBbox3857(required numeric lat, required numeric lng, required numeric radiusMeters) {
    var origin = toWebMercator(lat, lng);
    return {
      minx = origin.x - radiusMeters,
      miny = origin.y - radiusMeters,
      maxx = origin.x + radiusMeters,
      maxy = origin.y + radiusMeters
    };
  }

  private struct function toWebMercator(required numeric lat, required numeric lng) {
    var originShift = 20037508.34;
    var x = lng * originShift / 180;
    var y = log(tan((90 + lat) * pi() / 360)) / (pi() / 180);
    y = y * originShift / 180;
    return { x = x, y = y };
  }

  private string function fetchFeatureInfo(required string proxyBase, required string layers, required struct bbox, required string infoFormat) {
    var params = [
      "method=tile",
      "target=noaa-charts",
      "SERVICE=WMS",
      "REQUEST=GetFeatureInfo",
      "VERSION=1.3.0",
      "CRS=EPSG:3857",
      "BBOX=" & urlEncodedFormat(bbox.minx & "," & bbox.miny & "," & bbox.maxx & "," & bbox.maxy),
      "WIDTH=256",
      "HEIGHT=256",
      "I=128",
      "J=128",
      "LAYERS=" & urlEncodedFormat(layers),
      "QUERY_LAYERS=" & urlEncodedFormat(layers),
      "INFO_FORMAT=" & urlEncodedFormat(infoFormat),
      "FEATURE_COUNT=5"
    ];

    var url = proxyBase & "?" & arrayToList(params, "&");
    var httpRes = {};

    try {
      cfhttp(url=url, method="get", timeout="12", result="httpRes") {
        cfhttpparam(type="header", name="Accept", value="application/json,text/xml,*/*");
        cfhttpparam(type="header", name="User-Agent", value="FPW-MarineName/1.0");
      }
    } catch (any e) {
      return "";
    }

    if (!structKeyExists(httpRes, "statusCode") || left(httpRes.statusCode, 3) != "200") {
      return "";
    }

    if (structKeyExists(httpRes, "fileContent")) {
      return toString(httpRes.fileContent);
    }

    return "";
  }

  private string function parseFeatureName(required string responseText, required string infoFormat) {
    if (!len(trim(responseText))) return "";
    if (findNoCase("application/json", infoFormat)) {
      var jsonName = parseFeatureNameFromJson(responseText);
      if (len(jsonName)) return jsonName;
    }
    var xmlName = parseFeatureNameFromXml(responseText);
    if (len(xmlName)) return xmlName;
    return parseFeatureNameFromHtml(responseText);
  }

  private string function parseFeatureNameFromJson(required string responseText) {
    var data = {};
    try { data = deserializeJSON(responseText); } catch (any e) { return ""; }
    return findNameInValue(data, 0);
  }

  private string function findNameInValue(required any value, required numeric depth) {
    if (depth > 4) return "";
    if (isStruct(value)) {
      var direct = findNameInStruct(value);
      if (len(direct)) return direct;
      for (var key in value) {
        var nested = findNameInValue(value[key], depth + 1);
        if (len(nested)) return nested;
      }
    } else if (isArray(value)) {
      for (var i=1; i <= arrayLen(value); i++) {
        var nextVal = findNameInValue(value[i], depth + 1);
        if (len(nextVal)) return nextVal;
      }
    }
    return "";
  }

  private string function findNameInStruct(required struct value) {
    var keys = ["name","NAME","featureName","objnam","lnnam","waterbody","feature","label","OBJNAM","LNNAME","NOBJNM"];
    for (var i=1; i <= arrayLen(keys); i++) {
      if (structKeyExists(value, keys[i])) {
        var candidate = toString(value[keys[i]]);
        candidate = trim(candidate);
        if (isMeaningfulName(candidate)) {
          return candidate;
        }
      }
    }
    return "";
  }

  private string function parseFeatureNameFromXml(required string responseText) {
    var keys = ["name","NAME","featureName","objnam","lnnam","waterbody","feature","label","OBJNAM","LNNAME","NOBJNM"];
    for (var i=1; i <= arrayLen(keys); i++) {
      var key = keys[i];
      var match = reFindNoCase('<Field[^>]*name="' & key & '"[^>]*>([^<]+)</Field>', responseText, 1, true);
      if (arrayLen(match.pos) >= 2 && match.pos[2] > 0) {
        var value = mid(responseText, match.pos[2], match.len[2]);
        value = trim(value);
        if (isMeaningfulName(value)) return value;
      }
      match = reFindNoCase("<" & key & ">([^<]+)</" & key & ">", responseText, 1, true);
      if (arrayLen(match.pos) >= 2 && match.pos[2] > 0) {
        var value2 = mid(responseText, match.pos[2], match.len[2]);
        value2 = trim(value2);
        if (isMeaningfulName(value2)) return value2;
      }
    }
    return "";
  }

  private string function parseFeatureNameFromHtml(required string responseText) {
    var preferred = pickPreferredHtmlFeatureName(responseText);
    if (len(preferred)) return preferred;
    return pickFirstHtmlName(responseText);
  }

  private string function pickPreferredHtmlFeatureName(required string responseText) {
    var blocks = reMatchNoCase("(?s)<b>dataset</b>:[\\s\\S]*?(?=<b>dataset</b>:|$)", responseText);
    if (!isArray(blocks) || !arrayLen(blocks)) return "";

    var bestName = "";
    var bestScore = -1;
    for (var i=1; i <= arrayLen(blocks); i++) {
      var block = blocks[i];
      var name = pickFirstHtmlName(block);
      if (!len(name)) continue;

      var objectType = getHtmlFieldValue(block, "objectType");
      var objectDesc = getHtmlFieldValue(block, "objectTypeDescription");
      var score = scoreFeatureType(objectDesc, objectType);
      if (score > bestScore) {
        bestScore = score;
        bestName = name;
      }
    }

    if (bestScore > 0) return bestName;
    return "";
  }

  private string function pickFirstHtmlName(required string responseText) {
    var keys = ["OBJNAM","LNNAME","NOBJNM","objnam","lnnam","waterbody","feature","label"];
    for (var i=1; i <= arrayLen(keys); i++) {
      var value = getHtmlFieldValue(responseText, keys[i]);
      if (isMeaningfulName(value)) return value;
    }
    return "";
  }

  private string function getHtmlFieldValue(required string responseText, required string key) {
    var anchor = "<b>acronym</b>: " & key;
    var anchorPos = findNoCase(anchor, responseText);
    if (anchorPos > 0) {
      var valuePos = findNoCase("<b>value</b>:", responseText, anchorPos);
      if (valuePos > 0) {
        var start = valuePos + len("<b>value</b>:");
        var endPos = find("<", responseText, start);
        if (endPos > start) {
          return trim(mid(responseText, start, endPos - start));
        }
      }
    }
    return "";
  }

  private numeric function scoreFeatureType(required string description, required string code) {
    var desc = lcase(trim(description));
    var codeUpper = ucase(trim(code));
    if (len(codeUpper)) {
      if (listFindNoCase("M_COVR,M_QUAL,MAGVAR,M_NSYS,M_NPUB", codeUpper)) return -1;
    }
    if (len(desc)) {
      if (findNoCase("coverage", desc) || findNoCase("quality", desc) || findNoCase("magnetic variation", desc)) {
        return -1;
      }
      if (
        findNoCase("sea area", desc) ||
        findNoCase("named water", desc) ||
        findNoCase("bay", desc) ||
        findNoCase("sound", desc) ||
        findNoCase("harbor", desc) ||
        findNoCase("harbour", desc) ||
        findNoCase("channel", desc) ||
        findNoCase("river", desc) ||
        findNoCase("inlet", desc) ||
        findNoCase("strait", desc) ||
        findNoCase("passage", desc) ||
        findNoCase("anchorage", desc) ||
        findNoCase("waterway", desc) ||
        findNoCase("lake", desc) ||
        findNoCase("creek", desc) ||
        findNoCase("cove", desc) ||
        findNoCase("gulf", desc) ||
        findNoCase("estuary", desc)
      ) {
        return 3;
      }
    }
    if (listFindNoCase("SEAARE,RIVR,RIVERS,CHNL,FAIRWY,HBR,HRBOR,BAY,SOUND,STRIT,INLET", codeUpper)) {
      return 2;
    }
    return 0;
  }

  private boolean function isMeaningfulName(required string value) {
    if (len(value) < 3) return false;
    var lowered = lcase(value);
    if (lowered == "null" || lowered == "unknown" || lowered == "none" || lowered == "unnamed") return false;
    return true;
  }

  private void function cachePutSafe(required string key, required struct value, required numeric ttlSeconds) {
    var ts = createTimeSpan(0,0,0,ttlSeconds);
    try { cachePut(key, value, ts, ts); } catch (any e) {}
  }

}
