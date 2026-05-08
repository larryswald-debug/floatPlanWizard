(function(window) {
  "use strict";

  window.FPW = window.FPW || {};

  function roundTo2(value) {
    var n = parseFloat(value);
    if (!Number.isFinite(n)) return 0;
    return Math.round(n * 100) / 100;
  }

  function toInt(value, fallback) {
    var n = parseInt(value, 10);
    if (!Number.isFinite(n)) return (fallback !== undefined ? fallback : 0);
    return n;
  }

  function getLegField(leg, key) {
    if (!leg || typeof leg !== "object") return undefined;
    if (Object.prototype.hasOwnProperty.call(leg, key)) return leg[key];
    var upper = String(key || "").toUpperCase();
    if (Object.prototype.hasOwnProperty.call(leg, upper)) return leg[upper];
    return undefined;
  }

  function clampNumber(value, minValue, maxValue) {
    var n = parseFloat(value);
    if (!Number.isFinite(n)) return minValue;
    if (n < minValue) return minValue;
    if (n > maxValue) return maxValue;
    return n;
  }

  function parseWindRangeMph(rawValue) {
    var txt = String(rawValue === undefined || rawValue === null ? "" : rawValue).trim().toLowerCase();
    var nums = txt.match(/(\d+(\.\d+)?)/g) || [];
    var first = nums.length ? parseFloat(nums[0]) : 0;
    var second = nums.length >= 2 ? parseFloat(nums[1]) : first;
    var hasValue = !!txt.length;
    if (!Number.isFinite(first)) first = 0;
    if (!Number.isFinite(second)) second = first;
    return {
      hasValue: hasValue,
      speedMph: Math.max(0, first),
      gustMph: Math.max(0, Math.max(first, second))
    };
  }

  function parseNullableNumber(value) {
    var n = parseFloat(value);
    if (!Number.isFinite(n)) return null;
    return n;
  }

  function readWeatherField(source, keys) {
    var obj = source && typeof source === "object" ? source : {};
    var keyList = Array.isArray(keys) ? keys : [keys];
    var idx = 0;
    var key = "";
    var value = null;
    for (idx = 0; idx < keyList.length; idx += 1) {
      key = String(keyList[idx] || "");
      if (!key || !Object.prototype.hasOwnProperty.call(obj, key)) continue;
      value = obj[key];
      if (value === undefined || value === null) continue;
      if (typeof value === "string" && !value.trim()) continue;
      return value;
    }
    return null;
  }

  function parseAlertSeverityLevel(alertRow) {
    var row = alertRow && typeof alertRow === "object" ? alertRow : {};
    var severityText = String(
      row.severity !== undefined ? row.severity :
        (row.SEVERITY !== undefined ? row.SEVERITY : "")
    ).trim().toLowerCase();
    if (!severityText) return 0;
    if (severityText.indexOf("extreme") >= 0) return 3;
    if (severityText.indexOf("severe") >= 0) return 2;
    if (severityText.indexOf("moderate") >= 0) return 1;
    return 1;
  }

  function buildRouteWeatherContextFromLegs(legsInput) {
    var legs = Array.isArray(legsInput) ? legsInput : [];
    var offshoreCount = 0;
    var idx = 0;
    if (!legs.length) {
      return { offshoreShare: null, legCount: 0, offshoreCount: 0 };
    }
    for (idx = 0; idx < legs.length; idx += 1) {
      if (toInt(getLegField(legs[idx], "is_offshore"), 0) > 0) offshoreCount += 1;
    }
    return {
      offshoreShare: offshoreCount / legs.length,
      legCount: legs.length,
      offshoreCount: offshoreCount
    };
  }

  function normalizeWeatherEnvelope(payload, zip) {
    var root = payload && typeof payload === "object" ? payload : {};
    var data = (root.DATA && typeof root.DATA === "object") ? root.DATA : root;
    var forecast = Array.isArray(data.FORECAST) ? data.FORECAST : (Array.isArray(data.forecast) ? data.forecast : []);
    var alerts = Array.isArray(data.ALERTS) ? data.ALERTS : (Array.isArray(data.alerts) ? data.alerts : []);
    var marine = (data.MARINE && typeof data.MARINE === "object") ? data.MARINE : ((data.marine && typeof data.marine === "object") ? data.marine : {});
    var surface = (data.surface && typeof data.surface === "object") ? data.surface : ((data.SURFACE && typeof data.SURFACE === "object") ? data.SURFACE : {});
    var summary = String(
      data.SUMMARY !== undefined ? data.SUMMARY :
        (data.summary !== undefined ? data.summary : "")
    ).trim();
    return {
      zip: zip,
      fetchedAt: new Date(),
      forecast: forecast,
      alerts: alerts,
      marine: marine,
      surface: surface,
      summary: summary
    };
  }

  function computeLiveWeatherFactorPct(weatherEnvelope, routeContext) {
    var wx = weatherEnvelope && typeof weatherEnvelope === "object" ? weatherEnvelope : {};
    var context = routeContext && typeof routeContext === "object" ? routeContext : {};
    var forecast = Array.isArray(wx.forecast) ? wx.forecast : [];
    var alerts = Array.isArray(wx.alerts) ? wx.alerts : [];
    var marine = wx.marine && typeof wx.marine === "object" ? wx.marine : {};
    var surface = wx.surface && typeof wx.surface === "object" ? wx.surface : {};
    var nowForecast = forecast.length ? forecast[0] : {};
    var wind = parseWindRangeMph(
      nowForecast.windSpeed !== undefined ? nowForecast.windSpeed :
        (nowForecast.WINDSPEED !== undefined ? nowForecast.WINDSPEED : "")
    );
    var apiGust = parseNullableNumber(
      nowForecast.gustMph !== undefined ? nowForecast.gustMph :
        (nowForecast.GUSTMPH !== undefined ? nowForecast.GUSTMPH : "")
    );
    var maxWindMph = Math.max(
      wind.speedMph,
      wind.gustMph,
      (apiGust !== null && apiGust > 0 ? apiGust : 0)
    );
    var waves = (marine.waves && typeof marine.waves === "object")
      ? marine.waves
      : ((marine.WAVES && typeof marine.WAVES === "object") ? marine.WAVES : {});
    var waveFt = parseNullableNumber(
      marine.wave_height_ft !== undefined ? marine.wave_height_ft :
        (marine.WAVE_HEIGHT_FT !== undefined ? marine.WAVE_HEIGHT_FT :
          (waves.height !== undefined ? waves.height : waves.HEIGHT))
    );
    var visibilityMi = parseNullableNumber(readWeatherField(surface, ["visibility_mi", "VISIBILITY_MI"]));
    var pressureInhg = parseNullableNumber(readWeatherField(surface, ["pressure_inhg", "PRESSURE_INHG"]));
    var pressureTrend = String(readWeatherField(surface, ["pressure_trend", "PRESSURE_TREND"]) || "").trim().toLowerCase();
    var severeAlertCount = 0;
    var score = 0;
    var availableSignals = 0;
    var windContribution = 0;
    var waveContribution = 0;
    var alertContribution = 0;
    var visibilityContribution = 0;
    var pressureContribution = 0;
    var multiplier = 1;
    var explanationParts = [];
    var offshoreShare = parseNullableNumber(context.offshoreShare);
    var confidence = "low";
    var finalPct = 0;
    var idx = 0;

    for (idx = 0; idx < alerts.length; idx += 1) {
      if (parseAlertSeverityLevel(alerts[idx]) >= 2) severeAlertCount += 1;
    }

    if (wind.hasValue || maxWindMph > 0) {
      availableSignals += 1;
      if (maxWindMph >= 30) windContribution = 24;
      else if (maxWindMph >= 25) windContribution = 22;
      else if (maxWindMph >= 20) windContribution = 18;
      else if (maxWindMph >= 15) windContribution = 12;
      else if (maxWindMph >= 10) windContribution = 6;
      score += windContribution;
      explanationParts.push("Wind " + Math.round(maxWindMph) + " mph");
    }

    if (waveFt !== null && waveFt >= 0) {
      availableSignals += 1;
      if (waveFt >= 7) waveContribution = 18;
      else if (waveFt >= 5) waveContribution = 16;
      else if (waveFt >= 3) waveContribution = 12;
      else if (waveFt >= 2) waveContribution = 8;
      else if (waveFt >= 1) waveContribution = 4;
      score += waveContribution;
      explanationParts.push("Waves " + roundTo2(waveFt) + " ft");
    }

    if (alerts.length > 0) {
      availableSignals += 1;
      if (severeAlertCount > 0) alertContribution = 12;
      else if (alerts.length >= 3) alertContribution = 10;
      else if (alerts.length === 2) alertContribution = 8;
      else alertContribution = 4;
      score += alertContribution;
      explanationParts.push("Alerts " + alerts.length);
    }

    if (visibilityMi !== null && visibilityMi >= 0) {
      availableSignals += 1;
      if (visibilityMi < 1) visibilityContribution = 4;
      else if (visibilityMi < 3) visibilityContribution = 3;
      else if (visibilityMi < 5) visibilityContribution = 2;
      else if (visibilityMi < 8) visibilityContribution = 1;
      score += visibilityContribution;
      explanationParts.push("Visibility " + roundTo2(visibilityMi) + " mi");
    }

    if (pressureInhg !== null && pressureInhg > 0) {
      explanationParts.push("Pressure " + pressureInhg.toFixed(2) + " inHg");
    }

    if (pressureTrend) {
      availableSignals += 1;
      if (pressureTrend === "rapid_fall") pressureContribution = 2;
      else if (pressureTrend === "falling") pressureContribution = 1;
      score += pressureContribution;
      explanationParts.push("Trend " + pressureTrend.replace(/_/g, " "));
    }

    if (offshoreShare !== null && Number.isFinite(offshoreShare)) {
      offshoreShare = clampNumber(offshoreShare, 0, 1);
      if (offshoreShare >= 0.6) {
        multiplier = 1.1;
      } else if (offshoreShare <= 0.15) {
        multiplier = 0.95;
      }
      explanationParts.push("Offshore " + Math.round(offshoreShare * 100) + "%");
    }

    if (availableSignals <= 0) {
      return {
        available: false,
        suggestedPct: null,
        confidence: "low",
        metaText: "Suggestion unavailable",
        factorsText: "No usable live weather signals were available.",
        sourceLabel: ""
      };
    }

    if (availableSignals >= 4) confidence = "high";
    else if (availableSignals >= 2) confidence = "medium";
    else confidence = "low";

    finalPct = clampNumber(score * multiplier, 0, 60);
    finalPct = Math.round(finalPct);

    return {
      available: true,
      suggestedPct: finalPct,
      confidence: confidence,
      metaText: "Anchor ZIP " + (wx.zip || "unknown") + " using current dashboard marine weather.",
      factorsText: explanationParts.join(" · "),
      sourceLabel: "weather.cfc zip quick mode"
    };
  }

  window.FPW.RouteWeatherAssist = {
    normalizeWeatherEnvelope: normalizeWeatherEnvelope,
    computeLiveWeatherFactorPct: computeLiveWeatherFactorPct,
    buildRouteWeatherContextFromLegs: buildRouteWeatherContextFromLegs
  };
})(window);
