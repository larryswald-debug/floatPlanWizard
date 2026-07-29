component output="false" {

  public any function init(string cacheName = "fpwWeatherRewriteCache") {
    variables.cacheName = arguments.cacheName;
    return this;
  }

  public struct function get(required string key) {
    ensureCache();

    var result = {
      "found" = false,
      "hit" = false,
      "stale" = false,
      "value" = javacast("null", ""),
      "ageSeconds" = javacast("null", ""),
      "createdAtUtc" = "",
      "expiresAtUtc" = ""
    };

    if (!structKeyExists(application[variables.cacheName], arguments.key)) {
      return result;
    }

    var entry = application[variables.cacheName][arguments.key];
    result.found = true;
    result.value = duplicate(entry.value);
    result.createdAtUtc = entry.createdAtUtc;
    result.expiresAtUtc = entry.expiresAtUtc;
    result.ageSeconds = dateDiff("s", entry.createdAt, now());
    result.stale = now() GT entry.expiresAt;
    result.hit = !result.stale;

    return result;
  }

  public void function put(required string key, required any value, numeric ttlSeconds = 300) {
    ensureCache();

    application[variables.cacheName][arguments.key] = {
      "value" = duplicate(arguments.value),
      "createdAt" = now(),
      "expiresAt" = dateAdd("s", max(1, int(arguments.ttlSeconds)), now()),
      "createdAtUtc" = isoUtc(now()),
      "expiresAtUtc" = isoUtc(dateAdd("s", max(1, int(arguments.ttlSeconds)), now()))
    };
  }

  public struct function remember(required string key, numeric ttlSeconds = 300, required any producer) {
    var cached = get(arguments.key);
    if (cached.hit) {
      return {
        "value" = cached.value,
        "cache" = {
          "key" = arguments.key,
          "status" = "hit",
          "ageSeconds" = cached.ageSeconds,
          "createdAtUtc" = cached.createdAtUtc,
          "expiresAtUtc" = cached.expiresAtUtc
        }
      };
    }

    var value = arguments.producer();
    put(arguments.key, value, arguments.ttlSeconds);

    return {
      "value" = value,
      "cache" = {
        "key" = arguments.key,
        "status" = cached.found ? "refresh" : "miss",
        "ageSeconds" = 0,
        "createdAtUtc" = isoUtc(now()),
        "expiresAtUtc" = isoUtc(dateAdd("s", max(1, int(arguments.ttlSeconds)), now()))
      }
    };
  }

  public struct function entrySummary(required string key) {
    var cached = get(arguments.key);
    return {
      "key" = arguments.key,
      "hit" = cached.hit,
      "stale" = cached.stale,
      "ageSeconds" = cached.ageSeconds,
      "createdAtUtc" = cached.createdAtUtc,
      "expiresAtUtc" = cached.expiresAtUtc
    };
  }

  private void function ensureCache() {
    if (!structKeyExists(application, variables.cacheName) || !isStruct(application[variables.cacheName])) {
      application[variables.cacheName] = {};
    }
  }

  private string function isoUtc(required date value) {
    return dateTimeFormat(dateConvert("local2Utc", arguments.value), "yyyy-mm-dd'T'HH:nn:ss'Z'");
  }
}
