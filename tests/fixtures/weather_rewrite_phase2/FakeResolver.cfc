component output="false" {

  public any function init(boolean available = true, string reason = "") {
    variables.available = arguments.available;
    variables.reason = arguments.reason;
    return this;
  }

  public struct function resolve(required numeric userId, struct request = {}) {
    if (!variables.available) {
      return {
        "available" = false,
        "sourceType" = "fallback",
        "displayName" = "",
        "zip" = "",
        "lat" = javacast("null", ""),
        "lon" = javacast("null", ""),
        "timezone" = "",
        "warnings" = [len(variables.reason) ? variables.reason : "No usable weather target."],
        "reason" = len(variables.reason) ? variables.reason : "NO_TARGET"
      };
    }

    return {
      "available" = true,
      "sourceType" = "homeport",
      "displayName" = "Test Home Port",
      "zip" = "33708",
      "lat" = 27.7856,
      "lon" = -82.7814,
      "timezone" = "",
      "warnings" = [],
      "reason" = ""
    };
  }
}
