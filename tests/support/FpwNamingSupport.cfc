component output="false" {

  public string function buildPrefix(required string specSlug, required string scenarioSlug) output="false" {
    var cleanSpec = sanitize(arguments.specSlug, "spec");
    var cleanScenario = sanitize(arguments.scenarioSlug, "scenario");
    return "TB_" & cleanSpec & "_" & cleanScenario & "_" & buildUtcStamp();
  }

  public string function buildName(required string prefix, string label="") output="false" {
    var trimmedLabel = trim(arguments.label);
    if (!len(trimmedLabel)) {
      return trim(arguments.prefix);
    }
    return trim(arguments.prefix) & " " & trimmedLabel;
  }

  public string function buildEmail(required string prefix, string tag="contact") output="false" {
    return sanitize(arguments.prefix, "tb") & "." & sanitize(arguments.tag, "contact") & "@example.com";
  }

  private string function buildUtcStamp() output="false" {
    var nowUtc = dateConvert("local2utc", now());
    return dateFormat(nowUtc, "yyyymmdd") & timeFormat(nowUtc, "HHmmss");
  }

  private string function sanitize(required string rawValue, string fallback="item") output="false" {
    var normalized = lCase(trim(arguments.rawValue));
    normalized = reReplace(normalized, "[^a-z0-9]+", "-", "all");
    normalized = reReplace(normalized, "^-+|-+$", "", "all");
    if (!len(normalized)) {
      normalized = trim(arguments.fallback);
    }
    return normalized;
  }
}
