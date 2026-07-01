component output="false" {

  public any function init(boolean fail = false) {
    variables.fail = arguments.fail;
    return this;
  }

  public struct function getTideBundle(required numeric lat, required numeric lon, any cache = "") {
    if (variables.fail) {
      throw(type = "FPW.Weather.FakeCoopsFailure", message = "CO-OPS fake failure");
    }

    return {
      "available" = true,
      "seasFt" = javacast("null", ""),
      "waveHeightFt" = javacast("null", ""),
      "wavePeriodSec" = javacast("null", ""),
      "waveDirectionDeg" = javacast("null", ""),
      "tideLevelFt" = 1.2,
      "tideTrend" = "Rising",
      "nextHigh" = { "timeUtc" = "2026-07-01T18:00:00Z", "heightFt" = 2.1, "type" = "H" },
      "nextLow" = { "timeUtc" = "2026-07-02T00:00:00Z", "heightFt" = 0.4, "type" = "L" },
      "tideStation" = "Fake Tide Station (8726520)",
      "waterLevelStation" = "Fake Water Station (8726520)",
      "warnings" = [],
      "sources" = [],
      "_cacheEntries" = [{
        "key" = "coops:fake",
        "status" = "hit",
        "ageSeconds" = 1,
        "createdAtUtc" = "2026-07-01T16:00:00Z",
        "expiresAtUtc" = "2026-07-01T16:15:00Z",
        "durationMs" = 0
      }]
    };
  }
}
