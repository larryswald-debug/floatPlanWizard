(function (window) {
  "use strict";

  window.FPW = window.FPW || {};
  window.FPW.SharedFuelMath = window.FPW.SharedFuelMath || {};

  var SharedFuelMath = window.FPW.SharedFuelMath;
  var DEFAULT_MAX_HOURS_PER_DAY = 6.5;
  var DEFAULT_RESERVE_PCT = 33;
  var RESERVE_MODE_THIRDS = "thirds";
  var RESERVE_MODE_PERCENTAGE = "percentage";
  var PACE_FACTORS = {
    RELAXED: 0.25,
    BALANCED: 0.50,
    AGGRESSIVE: 1.00
  };

  function safeVal(value) {
    var n = parseFloat(value);
    if (!Number.isFinite(n)) return null;
    return n;
  }

  function clamp(value, minValue, maxValue) {
    return Math.min(maxValue, Math.max(minValue, value));
  }

  function roundTo2(value) {
    var n = parseFloat(value);
    if (!Number.isFinite(n)) return 0;
    return Math.round(n * 100) / 100;
  }

  function roundTo1(value) {
    var n = parseFloat(value);
    if (!Number.isFinite(n)) return 0;
    return Math.round(n * 10) / 10;
  }

  function formatNum(value, decimals, fallbackText) {
    var n = safeVal(value);
    var places = (typeof decimals === "number") ? decimals : 2;
    if (n === null) return (fallbackText !== undefined ? String(fallbackText) : "n/a");
    return n.toLocaleString(undefined, {
      minimumFractionDigits: places,
      maximumFractionDigits: places
    });
  }

  function formatCurrency(value, fallbackText) {
    var n = safeVal(value);
    if (n === null) return (fallbackText !== undefined ? String(fallbackText) : "--");
    return "$" + n.toLocaleString(undefined, {
      minimumFractionDigits: 2,
      maximumFractionDigits: 2
    });
  }

  function normalizePaceKey(value) {
    var key = String(value || "").trim().toUpperCase();
    if (!Object.prototype.hasOwnProperty.call(PACE_FACTORS, key)) {
      return "RELAXED";
    }
    return key;
  }

  function paceFactorForKey(value) {
    var key = normalizePaceKey(value);
    return PACE_FACTORS[key];
  }

  function normalizeMaxHoursPerDay(value) {
    var n = safeVal(value);
    if (n === null || n <= 0) n = DEFAULT_MAX_HOURS_PER_DAY;
    if (n < 4) n = 4;
    if (n > 12) n = 12;
    return Math.round(n * 2) / 2;
  }

  function normalizeReserveMode(value, reservePct) {
    var rawMode = String(value || "").trim().toLowerCase();
    var pct = safeVal(reservePct);
    if (rawMode === RESERVE_MODE_THIRDS) return RESERVE_MODE_THIRDS;
    if (rawMode === RESERVE_MODE_PERCENTAGE) return RESERVE_MODE_PERCENTAGE;
    if (pct === null) pct = DEFAULT_RESERVE_PCT;
    return Math.abs(pct - DEFAULT_RESERVE_PCT) < 0.0001
      ? RESERVE_MODE_THIRDS
      : RESERVE_MODE_PERCENTAGE;
  }

  function reserveForBase(baseFuel, reserveMode, reservePct) {
    var base = safeVal(baseFuel);
    var pct = safeVal(reservePct);
    var mode = normalizeReserveMode(reserveMode, pct);
    if (base === null || base < 0) return null;
    if (mode === RESERVE_MODE_THIRDS) return base * 0.5;
    if (pct === null) pct = DEFAULT_RESERVE_PCT;
    return base * (pct / 100);
  }

  function buildCruiseTimelineSummaryModel(timelinePayload, uiInputs) {
    var payload = (timelinePayload && typeof timelinePayload === "object") ? timelinePayload : {};
    var summary = (payload.summary && typeof payload.summary === "object") ? payload.summary : {};
    var meta = (payload.meta && typeof payload.meta === "object") ? payload.meta : {};
    var days = Array.isArray(payload.days) ? payload.days : [];
    var ui = (uiInputs && typeof uiInputs === "object") ? uiInputs : {};
    var totalNm = safeVal(summary.totalNm);
    var totalDays = safeVal(summary.totalDays);
    var totalRequiredFuel = safeVal(summary.totalRequiredFuel);
    var totalHours = null;
    var totalLocks = null;
    var totalReserveFuel = null;
    var hasHours = false;
    var hasLocks = false;
    var hasReserve = false;
    var hoursAcc = 0;
    var locksAcc = 0;
    var reserveAcc = 0;
    var hoursSource = String(meta.hoursSource || "").trim().toLowerCase();
    var effectiveSpeedKn = safeVal(meta.effectiveSpeedKn);
    var weatherPctUsed = safeVal(meta.effectiveWeatherPctMax);
    var adjSpeedKn = null;
    var maxHoursPerDay = safeVal(ui.maxHoursPerDay);
    var reservePct = safeVal(ui.reservePct);
    if (reservePct === null) {
      reservePct = safeVal(summary.reserve_pct !== undefined ? summary.reserve_pct : summary.reservePct);
    }
    if (reservePct === null) reservePct = DEFAULT_RESERVE_PCT;
    var reserveMode = normalizeReserveMode(
      ui.reserveMode || summary.reserve_mode || summary.reserveMode || meta.reserve_mode || meta.reserveMode,
      reservePct
    );
    var fuelBurnGph = safeVal(meta.fuelBurnGph);
    var weatherAdjustedBurnGph = safeVal(meta.weatherAdjustedBurnGph);
    var summaryFuelBurnGph = fuelBurnGph;
    var fuelSource = String(meta.fuelSource || "").trim();
    var fuelPricePerGal = safeVal(ui.fuelPricePerGal);
    var timelineCruiseOnly = (ui.timelineCruiseOnly === true);
    var idleBurnGph = safeVal(ui.idleBurnGph);
    var idleHoursTotal = safeVal(ui.idleHoursTotal);
    var idleFuelGallons = 0;
    var idleReserveGallons = 0;
    var summaryTotalHours = null;
    var hoursExpr = "";
    var dayExpr = "";
    var fuelExpr = "";
    var locksExpr = "";
    var calculatedDays = null;
    var displayedDays = null;
    var baseFuelByRate = null;
    var requiredFuelByRate = null;
    var baseFuelForSummary = null;
    var reserveFuelForSummary = null;
    var requiredFuelForSummary = null;
    var fuelCostEstimate = null;
    var estimatedDaysSubText = "";
    var estimatedFuelSubText = "";
    var fuelCostSubText = "";
    var rateEstimateText = "";
    var rateEstimateAbsDiff = null;
    var rateEstimatePctDiff = null;

    if (effectiveSpeedKn === null) {
      effectiveSpeedKn = safeVal(ui.effectiveSpeedKn);
    }
    if (weatherPctUsed === null) {
      weatherPctUsed = safeVal(ui.weatherFactorPct);
    }
    if (weatherAdjustedBurnGph !== null && (summaryFuelBurnGph === null || weatherAdjustedBurnGph < summaryFuelBurnGph)) {
      summaryFuelBurnGph = weatherAdjustedBurnGph;
    }

    days.forEach(function (day) {
      var h = safeVal(day.estHours);
      var l = safeVal(day.lockCount);
      var r = safeVal(day.reserveGallons);
      if (h !== null) {
        hoursAcc += h;
        hasHours = true;
      }
      if (l !== null) {
        locksAcc += l;
        hasLocks = true;
      }
      if (r !== null) {
        reserveAcc += r;
        hasReserve = true;
      }
    });

    if (hasHours) totalHours = hoursAcc;
    if (hasLocks) totalLocks = locksAcc;
    if (hasReserve) totalReserveFuel = reserveAcc;

    if (totalNm === null && days.length) {
      var distAcc = 0;
      var hasDist = false;
      days.forEach(function (day) {
        var d = safeVal(day.totalDistNm);
        if (d !== null) {
          distAcc += d;
          hasDist = true;
        }
      });
      if (hasDist) totalNm = distAcc;
    }
    if (totalDays === null && days.length) {
      totalDays = days.length;
    }
    if (totalRequiredFuel === null && days.length) {
      var reqAcc = 0;
      var hasReq = false;
      days.forEach(function (day) {
        var req = safeVal(day.requiredFuelGallons);
        if (req !== null) {
          reqAcc += req;
          hasReq = true;
        }
      });
      if (hasReq) totalRequiredFuel = reqAcc;
    }

    if (hoursSource === "weather_adjusted_speed" && effectiveSpeedKn !== null && weatherPctUsed !== null) {
      adjSpeedKn = effectiveSpeedKn * (1 - (weatherPctUsed / 100));
      if (adjSpeedKn < 0.5) adjSpeedKn = 0.5;
    } else if (totalNm !== null && totalHours !== null && totalHours > 0) {
      adjSpeedKn = totalNm / totalHours;
    }

    hoursExpr = "Dist " + formatNum(totalNm, 1) + " nm ÷ AdjSpeed " + formatNum(adjSpeedKn, 2) + " kn";
    if (hoursSource === "weather_adjusted_speed" && effectiveSpeedKn !== null && weatherPctUsed !== null) {
      hoursExpr += " (= " + formatNum(effectiveSpeedKn, 2) + " kn × (1 - effective weather " + formatNum(weatherPctUsed, 2) + "%))";
    } else if (effectiveSpeedKn !== null) {
      hoursExpr += " (raw " + formatNum(effectiveSpeedKn, 2) + " kn)";
    }
    hoursExpr += " = " + formatNum(totalHours, 2) + " h";

    if (totalHours !== null && maxHoursPerDay !== null && maxHoursPerDay > 0) {
      calculatedDays = Math.ceil(totalHours / maxHoursPerDay);
      displayedDays = (totalDays !== null ? totalDays : calculatedDays);
      dayExpr = "Max/day " + formatNum(maxHoursPerDay, 1) + " h → " + formatNum(displayedDays, 0) + " days (ceil(" + formatNum(totalHours, 2) + "/" + formatNum(maxHoursPerDay, 1) + "))";
    } else {
      displayedDays = totalDays;
      dayExpr = "Max/day " + formatNum(maxHoursPerDay, 1) + " h → " + (totalDays !== null ? (formatNum(totalDays, 0) + " days") : "n/a");
    }

    if (totalHours !== null && summaryFuelBurnGph !== null) {
      baseFuelByRate = totalHours * summaryFuelBurnGph;
      if (reservePct !== null) {
        var reserveFuelByRate = reserveForBase(baseFuelByRate, reserveMode, reservePct);
        requiredFuelByRate = baseFuelByRate + reserveFuelByRate;
        rateEstimateText = formatNum(totalHours, 2) + " h × " + formatNum(summaryFuelBurnGph, 2) + " gph = " + formatNum(baseFuelByRate, 1) + " gal + "
          + (reserveMode === RESERVE_MODE_THIRDS ? "One-Third Rule reserve" : formatNum(reservePct, 1) + "% reserve")
          + " = " + formatNum(requiredFuelByRate, 1) + " gal";
      } else {
        rateEstimateText = formatNum(totalHours, 2) + " h × " + formatNum(summaryFuelBurnGph, 2) + " gph = " + formatNum(baseFuelByRate, 1) + " gal";
      }
    }

    if (totalRequiredFuel !== null) {
      fuelExpr = "Fuel total " + formatNum(totalRequiredFuel, 1) + " gal from Cruise Timeline";
      if (requiredFuelByRate !== null) {
        rateEstimateAbsDiff = Math.abs(totalRequiredFuel - requiredFuelByRate);
        rateEstimatePctDiff = totalRequiredFuel > 0 ? (rateEstimateAbsDiff / totalRequiredFuel) : (rateEstimateAbsDiff > 0 ? Infinity : 0);
        if (rateEstimateAbsDiff <= 10 && rateEstimatePctDiff <= 0.05) {
          fuelExpr += " (rate estimate: " + rateEstimateText + ")";
        }
      }
    } else if (requiredFuelByRate !== null) {
      fuelExpr = "Fuel " + rateEstimateText;
    } else {
      fuelExpr = "Fuel n/a";
    }
    if (fuelSource) {
      fuelExpr += " [src " + fuelSource.replace(/_/g, " ") + "]";
    }

    if (totalRequiredFuel !== null) {
      requiredFuelForSummary = totalRequiredFuel;
      if (totalReserveFuel !== null) {
        reserveFuelForSummary = totalReserveFuel;
        baseFuelForSummary = totalRequiredFuel - totalReserveFuel;
        if (!Number.isFinite(baseFuelForSummary) || baseFuelForSummary < 0) baseFuelForSummary = 0;
      }
    } else if (requiredFuelByRate !== null) {
      requiredFuelForSummary = requiredFuelByRate;
      baseFuelForSummary = baseFuelByRate;
      reserveFuelForSummary = requiredFuelByRate - baseFuelByRate;
      if (!Number.isFinite(reserveFuelForSummary) || reserveFuelForSummary < 0) reserveFuelForSummary = 0;
    }

    summaryTotalHours = totalHours;
    if (timelineCruiseOnly) {
      if (idleBurnGph !== null) {
        idleBurnGph = roundTo2(clamp(idleBurnGph, 0, 1000));
      }
      if (idleHoursTotal !== null) {
        idleHoursTotal = roundTo2(Math.max(0, idleHoursTotal));
      }
      if (idleHoursTotal !== null && idleHoursTotal > 0 && totalHours !== null) {
        summaryTotalHours = roundTo2(totalHours + idleHoursTotal);
      }
      if (idleBurnGph !== null && idleBurnGph > 0 && idleHoursTotal !== null && idleHoursTotal > 0) {
        // Timeline payload remains cruise-only in this phase; add only the idle delta here.
        idleFuelGallons = roundTo1(idleBurnGph * idleHoursTotal);
        if (baseFuelForSummary !== null) {
          baseFuelForSummary = roundTo2(baseFuelForSummary + idleFuelGallons);
        } else if (requiredFuelForSummary !== null && reserveFuelForSummary !== null) {
          baseFuelForSummary = roundTo2(requiredFuelForSummary - reserveFuelForSummary + idleFuelGallons);
        }
        if (reservePct !== null) {
          idleReserveGallons = roundTo2(reserveForBase(idleFuelGallons, reserveMode, reservePct));
          reserveFuelForSummary = roundTo2((reserveFuelForSummary !== null ? reserveFuelForSummary : 0) + idleReserveGallons);
        }
        if (baseFuelForSummary !== null && reserveFuelForSummary !== null) {
          requiredFuelForSummary = roundTo2(baseFuelForSummary + reserveFuelForSummary);
        } else if (requiredFuelForSummary !== null) {
          requiredFuelForSummary = roundTo2(requiredFuelForSummary + idleFuelGallons + idleReserveGallons);
        } else {
          requiredFuelForSummary = roundTo2(idleFuelGallons + idleReserveGallons);
        }
      }
    }

    locksExpr = "Locks " + (totalLocks !== null ? formatNum(totalLocks, 0) : "n/a");

    if (requiredFuelForSummary !== null && fuelPricePerGal !== null && fuelPricePerGal > 0) {
      fuelCostEstimate = roundTo2(requiredFuelForSummary * fuelPricePerGal);
    }

    if (timelineCruiseOnly && idleHoursTotal !== null && idleHoursTotal > 0 && totalHours !== null && summaryTotalHours !== null) {
      estimatedDaysSubText = "Cruise " + formatNum(totalHours, 1, "0.0") + "h + Idle " + formatNum(idleHoursTotal, 1, "0.0") + "h = " + formatNum(summaryTotalHours, 1, "0.0") + "h";
    } else if (totalHours !== null && maxHoursPerDay !== null && maxHoursPerDay > 0) {
      estimatedDaysSubText = "ceil(" + formatNum(totalHours, 2, "0.00") + "/" + formatNum(maxHoursPerDay, 1, "0.0") + ") from Cruise Timeline";
    } else {
      estimatedDaysSubText = "Cruise Timeline estimate";
    }

    if (baseFuelForSummary !== null && reserveFuelForSummary !== null && reservePct !== null) {
      estimatedFuelSubText = "Base " + formatNum(baseFuelForSummary, 1, "0.0") + " + "
        + (reserveMode === RESERVE_MODE_THIRDS ? "One-Third Rule Reserve " : "Reserve (" + formatNum(reservePct, 0, "0") + "%) ")
        + formatNum(reserveFuelForSummary, 1, "0.0");
    } else if (requiredFuelForSummary !== null && reservePct !== null) {
      estimatedFuelSubText = reserveMode === RESERVE_MODE_THIRDS
        ? "Required fuel (includes One-Third Rule reserve)"
        : "Required fuel (includes " + formatNum(reservePct, 0, "0") + "% reserve)";
    } else if (requiredFuelForSummary !== null) {
      estimatedFuelSubText = "Required fuel from Cruise Timeline";
    } else {
      estimatedFuelSubText = "Required fuel unavailable";
    }

    if (fuelPricePerGal !== null && fuelPricePerGal > 0) {
      fuelCostSubText = "Required fuel x $" + formatNum(fuelPricePerGal, 2, "0.00") + "/gal";
    } else {
      fuelCostSubText = "Enter fuel price to estimate";
    }

    return {
      calcLine: "Calc: " + hoursExpr + " • " + dayExpr + " • " + fuelExpr + " • " + locksExpr,
      totalNm: totalNm,
      totalHours: totalHours,
      summaryTotalHours: summaryTotalHours,
      totalDays: totalDays,
      displayedDays: displayedDays,
      maxHoursPerDay: maxHoursPerDay,
      totalLocks: totalLocks,
      adjSpeedKn: adjSpeedKn,
      reservePct: reservePct,
      reserveMode: reserveMode,
      fuelBurnGph: summaryFuelBurnGph,
      weatherAdjustedBurnGph: weatherAdjustedBurnGph,
      fuelSource: fuelSource,
      totalRequiredFuel: totalRequiredFuel,
      totalReserveFuel: totalReserveFuel,
      baseFuelByRate: baseFuelByRate,
      requiredFuelByRate: requiredFuelByRate,
      baseFuelForSummary: baseFuelForSummary,
      reserveFuelForSummary: reserveFuelForSummary,
      requiredFuelForSummary: requiredFuelForSummary,
      fuelPricePerGal: fuelPricePerGal,
      fuelCostEstimate: fuelCostEstimate,
      estimatedDaysSubText: estimatedDaysSubText,
      estimatedFuelSubText: estimatedFuelSubText,
      fuelCostSubText: fuelCostSubText
    };
  }

  function buildManualSummaryModel(inputs) {
    var src = (inputs && typeof inputs === "object") ? inputs : {};
    var paceKey = normalizePaceKey(src.pace);
    var paceFactor = paceFactorForKey(paceKey);
    var distanceNm = safeVal(src.distanceNm);
    var maxSpeedKn = safeVal(src.maxSpeedKn);
    var weatherFactorPct = safeVal(src.weatherFactorPct);
    var reservePct = safeVal(src.reservePct);
    var reserveMode = normalizeReserveMode(src.reserveMode, reservePct);
    var fuelBurnGph = safeVal(src.fuelBurnGph);
    var fuelPricePerGal = safeVal(src.fuelPricePerGal);
    var maxHoursPerDay = normalizeMaxHoursPerDay(src.maxHoursPerDay);
    var idleBurnGph = safeVal(src.idleBurnGph);
    var idleHoursTotal = safeVal(src.idleHoursTotal);
    var effectiveSpeedKn = null;
    var adjustedSpeedKn = null;
    var runHours = 0;
    var displayedDays = 0;
    var payload = {};
    var model = {};

    if (distanceNm === null || distanceNm < 0) distanceNm = 0;
    if (maxSpeedKn !== null) {
      maxSpeedKn = clamp(maxSpeedKn, 0, 60);
    }
    if (weatherFactorPct !== null) {
      weatherFactorPct = clamp(weatherFactorPct, 0, 60);
    } else {
      weatherFactorPct = 0;
    }
    if (reservePct === null) reservePct = DEFAULT_RESERVE_PCT;
    reservePct = clamp(reservePct, 0, 100);
    reserveMode = normalizeReserveMode(reserveMode, reservePct);
    if (fuelBurnGph !== null) {
      fuelBurnGph = roundTo2(clamp(fuelBurnGph, 0, 1000));
    }
    if (fuelPricePerGal !== null) {
      fuelPricePerGal = roundTo2(clamp(fuelPricePerGal, 0, 1000));
      if (fuelPricePerGal <= 0) fuelPricePerGal = null;
    }
    if (idleBurnGph !== null) {
      idleBurnGph = roundTo2(clamp(idleBurnGph, 0, 1000));
    }
    if (idleHoursTotal !== null) {
      idleHoursTotal = roundTo2(Math.max(0, idleHoursTotal));
    }

    if (maxSpeedKn !== null && maxSpeedKn > 0) {
      effectiveSpeedKn = roundTo1(maxSpeedKn * paceFactor);
      adjustedSpeedKn = roundTo2(effectiveSpeedKn * (1 - (weatherFactorPct / 100)));
      if (adjustedSpeedKn < 0.5) adjustedSpeedKn = 0.5;
    }
    if (distanceNm > 0 && adjustedSpeedKn !== null && adjustedSpeedKn > 0) {
      runHours = roundTo2(distanceNm / adjustedSpeedKn);
      displayedDays = Math.ceil(runHours / maxHoursPerDay);
      if (displayedDays < 1) displayedDays = 1;
    }

    payload = {
      summary: {
        totalNm: roundTo2(distanceNm),
        totalDays: displayedDays,
        totalRequiredFuel: null
      },
      meta: {
        hoursSource: "weather_adjusted_speed",
        effectiveSpeedKn: effectiveSpeedKn,
        fuelBurnGph: fuelBurnGph,
        fuelSource: "manual_inputs",
        effectiveWeatherPctMax: weatherFactorPct
      },
      days: [
        {
          totalDistNm: roundTo2(distanceNm),
          estHours: runHours,
          lockCount: 0,
          reserveGallons: null,
          requiredFuelGallons: null,
          confidence: null
        }
      ]
    };

    model = buildCruiseTimelineSummaryModel(payload, {
      maxHoursPerDay: maxHoursPerDay,
      reservePct: reservePct,
      reserveMode: reserveMode,
      weatherFactorPct: weatherFactorPct,
      effectiveSpeedKn: effectiveSpeedKn,
      fuelPricePerGal: fuelPricePerGal
    });

    model.manual = {
      pace: paceKey,
      paceFactor: paceFactor,
      distanceNm: roundTo2(distanceNm),
      maxSpeedKn: (maxSpeedKn !== null ? roundTo2(maxSpeedKn) : null),
      effectiveSpeedKn: effectiveSpeedKn,
      adjustedSpeedKn: adjustedSpeedKn,
      weatherFactorPct: weatherFactorPct,
      fuelBurnGph: fuelBurnGph,
      reservePct: reservePct,
      reserveMode: reserveMode,
      maxHoursPerDay: maxHoursPerDay,
      fuelPricePerGal: fuelPricePerGal,
      idleBurnGph: idleBurnGph,
      idleHoursTotal: idleHoursTotal,
      idleFuelGallons: (
        idleBurnGph !== null && idleHoursTotal !== null
          ? roundTo2(idleBurnGph * idleHoursTotal)
          : 0
      )
    };

    return model;
  }

  SharedFuelMath.roundTo2 = roundTo2;
  SharedFuelMath.roundTo1 = roundTo1;
  SharedFuelMath.safeVal = safeVal;
  SharedFuelMath.formatNum = formatNum;
  SharedFuelMath.formatCurrency = formatCurrency;
  SharedFuelMath.normalizePaceKey = normalizePaceKey;
  SharedFuelMath.paceFactorForKey = paceFactorForKey;
  SharedFuelMath.normalizeMaxHoursPerDay = normalizeMaxHoursPerDay;
  SharedFuelMath.normalizeReserveMode = normalizeReserveMode;
  SharedFuelMath.reserveForBase = reserveForBase;
  SharedFuelMath.buildCruiseTimelineSummaryModel = buildCruiseTimelineSummaryModel;
  SharedFuelMath.buildManualSummaryModel = buildManualSummaryModel;
})(window);
