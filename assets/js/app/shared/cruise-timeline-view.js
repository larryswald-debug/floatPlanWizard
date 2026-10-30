(function (window) {
  "use strict";
  window.FPW = window.FPW || {};
  var utils = window.FPW.DashboardUtils || {};
  // Shared presentation only. Scheduling, fuel, locks and risk remain service results.

  function escapeHtml(value) {
    if (utils.escapeHtml) return utils.escapeHtml(value);
    return String(value === undefined || value === null ? "" : value)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/\"/g, "&quot;")
      .replace(/'/g, "&#39;");
  }

  function formatNumber(value, decimals) {
    var n = parseFloat(value);
    if (!Number.isFinite(n)) return "0";
    var places = (typeof decimals === "number") ? decimals : 0;
    return n.toLocaleString(undefined, {
      minimumFractionDigits: places,
      maximumFractionDigits: places
    });
  }

  function safeVal(value) {
    var n = parseFloat(value);
    if (!Number.isFinite(n)) return null;
    return n;
  }

  function toInt(value, fallback) {
    var n = parseInt(value, 10);
    if (!Number.isFinite(n)) return (fallback !== undefined ? fallback : 0);
    return n;
  }

  function toOneDecimal(value) {
    var n = parseFloat(value);
    if (!Number.isFinite(n)) return 0;
    return Math.round(n * 10) / 10;
  }

  function toConfidenceInt(value) {
    var n = parseFloat(value);
    if (!Number.isFinite(n)) n = 0;
    n = Math.round(n);
    if (n < 0) n = 0;
    if (n > 100) n = 100;
    return n;
  }

  function coerceBool(value, fallback) {
    if (value === true || value === false) return value;
    if (value === 1 || value === "1") return true;
    if (value === 0 || value === "0") return false;
    var text = String(value === undefined || value === null ? "" : value).trim().toLowerCase();
    if (!text) return !!fallback;
    if (text === "true" || text === "yes" || text === "y" || text === "on") return true;
    if (text === "false" || text === "no" || text === "n" || text === "off") return false;
    return !!fallback;
  }

  function getLegField(leg, key) {
    if (!leg || typeof leg !== "object") return undefined;
    if (Object.prototype.hasOwnProperty.call(leg, key)) return leg[key];
    var upper = String(key || "").toUpperCase();
    if (Object.prototype.hasOwnProperty.call(leg, upper)) return leg[upper];
    return undefined;
  }

  function formatCoord(value) {
    var n = parseFloat(value);
    if (!Number.isFinite(n)) return "--";
    return formatNumber(n, 5);
  }

  function timelineRiskBadgeClass(riskColor) {
    var risk = String(riskColor || "").trim().toUpperCase();
    if (risk === "RED") return "bg-danger";
    if (risk === "YELLOW") return "bg-warning text-dark";
    return "bg-success";
  }

  function normalizeCruiseTimelineSegmentIds(segmentIds) {
    if (!Array.isArray(segmentIds)) return [];
    return segmentIds.map(function (id) {
      return toInt(id, 0);
    }).filter(function (id) {
      return id > 0;
    });
  }

  function normalizeCruiseTimelineSegmentSlices(segmentSlices) {
    if (!Array.isArray(segmentSlices)) return [];
    return segmentSlices.map(function (row) {
      var item = (row && typeof row === "object") ? row : {};
      var slice = {
        sourceId: toInt(item.source_id !== undefined ? item.source_id : item.SOURCE_ID, 0),
        routeLegId: toInt(item.route_leg_id !== undefined ? item.route_leg_id : item.ROUTE_LEG_ID, 0),
        segmentId: toInt(item.segment_id !== undefined ? item.segment_id : item.SEGMENT_ID, 0),
        orderIndex: toInt(item.order_index !== undefined ? item.order_index : item.ORDER_INDEX, 0),
        startName: String(item.start_name !== undefined ? item.start_name : (item.START_NAME || "Start")).trim() || "Start",
        endName: String(item.end_name !== undefined ? item.end_name : (item.END_NAME || "End")).trim() || "End",
        sliceDistNm: toOneDecimal(item.slice_dist_nm !== undefined ? item.slice_dist_nm : item.SLICE_DIST_NM),
        sliceHours: toOneDecimal(item.slice_hours !== undefined ? item.slice_hours : item.SLICE_HOURS),
        segmentDistNm: toOneDecimal(item.segment_dist_nm !== undefined ? item.segment_dist_nm : item.SEGMENT_DIST_NM),
        segmentHours: toOneDecimal(item.segment_hours !== undefined ? item.segment_hours : item.SEGMENT_HOURS),
        lockCount: toInt(item.lock_count !== undefined ? item.lock_count : item.LOCK_COUNT, 0),
        isSplit: coerceBool(item.is_split !== undefined ? item.is_split : item.IS_SPLIT, false)
      };
      var cruisingHours = item.segment_cruising_hours !== undefined ? item.segment_cruising_hours : item.SEGMENT_CRUISING_HOURS;
      if (safeVal(cruisingHours) !== null) slice.segmentCruisingHours = toOneDecimal(cruisingHours);
      return slice;
    }).filter(function (slice) {
      return slice.sourceId > 0 || slice.routeLegId > 0 || slice.segmentId > 0 || slice.orderIndex > 0;
    });
  }

  function normalizeCruiseTimelineDay(row, idx) {
    var item = (row && typeof row === "object") ? row : {};
    var riskColor = String(item.risk_color !== undefined ? item.risk_color : item.RISK_COLOR || "GREEN").trim().toUpperCase();
    if (!riskColor) riskColor = "GREEN";
    return {
      legIndex: toInt(item.leg_index !== undefined ? item.leg_index : item.LEG_INDEX, idx + 1),
      dateText: String(item.date !== undefined ? item.date : (item.DATE || "")).trim(),
      startName: String(item.start_name !== undefined ? item.start_name : (item.START_NAME || "Start")).trim() || "Start",
      endName: String(item.end_name !== undefined ? item.end_name : (item.END_NAME || "End")).trim() || "End",
      totalDistNm: toOneDecimal(item.total_dist_nm !== undefined ? item.total_dist_nm : item.TOTAL_DIST_NM),
      estHours: toOneDecimal(item.est_hours !== undefined ? item.est_hours : item.EST_HOURS),
      lockCount: toInt(item.lock_count !== undefined ? item.lock_count : item.LOCK_COUNT, 0),
      requiredFuelGallons: toOneDecimal(item.required_fuel_gallons !== undefined ? item.required_fuel_gallons : item.REQUIRED_FUEL_GALLONS),
      reserveGallons: toOneDecimal(item.reserve_gallons !== undefined ? item.reserve_gallons : item.RESERVE_GALLONS),
      confidence: toConfidenceInt(item.fuel_confidence_score !== undefined ? item.fuel_confidence_score : item.FUEL_CONFIDENCE_SCORE),
      riskColor: riskColor,
      badgeClass: timelineRiskBadgeClass(riskColor),
      segmentIds: normalizeCruiseTimelineSegmentIds(item.segment_ids !== undefined ? item.segment_ids : item.SEGMENT_IDS),
      segmentSlices: normalizeCruiseTimelineSegmentSlices(item.segment_slices !== undefined ? item.segment_slices : item.SEGMENT_SLICES)
    };
  }

  function normalizePayload(data) {
    var payload = (data && typeof data === "object") ? data : {};
    var summary = (payload.route_summary && typeof payload.route_summary === "object")
      ? payload.route_summary
      : (payload.ROUTE_SUMMARY && typeof payload.ROUTE_SUMMARY === "object" ? payload.ROUTE_SUMMARY : {});
    var meta = (payload.timeline_meta && typeof payload.timeline_meta === "object")
      ? payload.timeline_meta
      : (payload.TIMELINE_META && typeof payload.TIMELINE_META === "object" ? payload.TIMELINE_META : {});
    var days = Array.isArray(payload.days) ? payload.days : (Array.isArray(payload.DAYS) ? payload.DAYS : []);

    return {
      summary: {
        totalDays: toInt(summary.total_days !== undefined ? summary.total_days : summary.TOTAL_DAYS, 0),
        totalNm: toOneDecimal(summary.total_nm !== undefined ? summary.total_nm : summary.TOTAL_NM),
        totalRequiredFuel: toOneDecimal(summary.total_required_fuel !== undefined ? summary.total_required_fuel : summary.TOTAL_REQUIRED_FUEL)
      },
      meta: {
        hoursSource: String(meta.hours_source !== undefined ? meta.hours_source : (meta.HOURS_SOURCE || "")).trim().toLowerCase(),
        effectiveSpeedKn: safeVal(meta.effective_speed_kn !== undefined ? meta.effective_speed_kn : meta.EFFECTIVE_SPEED_KN),
        fuelBurnGph: safeVal(meta.fuel_burn_gph !== undefined ? meta.fuel_burn_gph : meta.FUEL_BURN_GPH),
        weatherAdjustedBurnGph: safeVal(
          meta.weather_adjusted_fuel_burn_gph !== undefined
            ? meta.weather_adjusted_fuel_burn_gph
            : (meta.WEATHER_ADJUSTED_FUEL_BURN_GPH !== undefined ? meta.WEATHER_ADJUSTED_FUEL_BURN_GPH : "")
        ),
        fuelSource: String(meta.fuel_source !== undefined ? meta.fuel_source : (meta.FUEL_SOURCE || "")).trim(),
        effectiveWeatherPctMax: safeVal(
          meta.effective_weather_pct_max !== undefined
            ? meta.effective_weather_pct_max
            : (meta.EFFECTIVE_WEATHER_PCT_MAX !== undefined ? meta.EFFECTIVE_WEATHER_PCT_MAX : "")
        )
      },
      days: days.map(function (day, idx) {
        return normalizeCruiseTimelineDay(day, idx);
      })
    };
  }

  function getEntriesForLeg(payload, leg, order) {
    var days = payload && Array.isArray(payload.days) ? payload.days : [];
    var orderNum = toInt(order, 0);
    var routeLegId = toInt(getLegField(leg, "route_leg_id"), 0);
    var segmentId = toInt(getLegField(leg, "segment_id"), 0);
    var entries = [];
    var fallbackDay = null;

    if (!days.length) return [];

    if (routeLegId > 0 || segmentId > 0 || orderNum > 0) {
      days.forEach(function (day) {
        var matchedSlice = null;
        var ids = [];
        if (!day || typeof day !== "object") return;
        if (Array.isArray(day.segmentSlices) && day.segmentSlices.length) {
          matchedSlice = day.segmentSlices.find(function (slice) {
            if (!slice || typeof slice !== "object") return false;
            if (routeLegId > 0 && toInt(slice.routeLegId, 0) === routeLegId) return true;
            if (segmentId > 0 && toInt(slice.segmentId, 0) === segmentId) return true;
            if (orderNum > 0 && toInt(slice.orderIndex, 0) === orderNum) return true;
            return false;
          }) || null;
        }
        if (matchedSlice) {
          entries.push({ day: day, slice: matchedSlice });
          return;
        }
        ids = Array.isArray(day.segmentIds) ? day.segmentIds : [];
        if ((routeLegId > 0 && ids.indexOf(routeLegId) >= 0) || (segmentId > 0 && ids.indexOf(segmentId) >= 0)) {
          fallbackDay = fallbackDay || day;
        }
      });
      if (entries.length) return entries;
      if (fallbackDay) return [{ day: fallbackDay, slice: null }];
    }

    if (orderNum > 0) {
      fallbackDay = days.find(function (day) {
        return toInt(day.legIndex, 0) === orderNum;
      }) || null;
      if (fallbackDay) return [{ day: fallbackDay, slice: null }];
      if (days[orderNum - 1]) return [{ day: days[orderNum - 1], slice: null }];
    }

    return [];
  }

  // Segment totals come from canonical timeline slices. Do not recompute hours here.
  function getLegMetrics(payload, leg, order) {
    var entries = getEntriesForLeg(payload, leg, order);
    var slice = entries.length && entries[0].slice ? entries[0].slice : null;
    return {
      startName: String(getLegField(leg, "start_name") || "Start").trim() || "Start",
      endName: String(getLegField(leg, "end_name") || "End").trim() || "End",
      distNm: slice ? slice.segmentDistNm : safeVal(getLegField(leg, "dist_nm")),
      estHours: slice ? (Number.isFinite(slice.segmentCruisingHours) ? slice.segmentCruisingHours : slice.segmentHours) : null,
      lockCount: toInt(getLegField(leg, "lock_count"), 0)
    };
  }

  function renderDayDetails(options) {
    var opts = options || {};
    var leg = opts.leg || {};
    var order = opts.order;
    var status = String(opts.status || "ready").trim().toLowerCase();
    var message = String(opts.message || "").trim();
    var payload = opts.payload && typeof opts.payload === "object" ? opts.payload : null;
    var dayEntries = getEntriesForLeg(payload, leg, order);
    var selectedLegMetrics = opts.selectedLegMetrics || getLegMetrics(payload, leg, order);
    var routeIdVal = opts.hasRoute === false ? 0 : 1;
    var html = "";
    html += '<div class="fpw-routegen__legtimeline mt-3">';
    html += '  <div class="small text-uppercase text-light opacity-75 mb-2">Cruise Timeline ' + (dayEntries.length > 1 ? "Days" : "Day") + "</div>";

    if (!routeIdVal) {
      html += '<div class="fpw-routegen__help mb-0">Generate or open a saved route to build a cruise timeline.</div>';
      html += "</div>";
      return html;
    }
    if (opts.startDateValid === false) {
      html += '<div class="alert alert-danger py-2 mb-0">Select a valid start date (yyyy-mm-dd) to build the cruise timeline.</div>';
      html += "</div>";
      return html;
    }
    if (status === "loading") {
      html += '<div class="d-flex align-items-center gap-2 text-light opacity-75 small"><span class="spinner-border spinner-border-sm" role="status" aria-hidden="true"></span><span>Building Cruise Timeline...</span></div>';
      html += "</div>";
      return html;
    }
    if (status === "error") {
      html += '<div class="alert alert-danger py-2 mb-0">' + escapeHtml(message || "Unable to build cruise timeline.") + "</div>";
      html += "</div>";
      return html;
    }
    if (status === "note") {
      html += '<div class="fpw-routegen__help mb-0">' + escapeHtml(message || "Generate or open a route to build a cruise timeline.") + "</div>";
      html += "</div>";
      return html;
    }
    if (!payload || !Array.isArray(payload.days) || !payload.days.length) {
      html += '<div class="alert alert-secondary py-2 mb-0">No timeline days generated.</div>';
      html += "</div>";
      return html;
    }
    if (!dayEntries.length) {
      html += '<div class="alert alert-secondary py-2 mb-0">No cruise timeline day is mapped to this leg yet.</div>';
      html += "</div>";
      return html;
    }

    html += '  <div class="small text-light opacity-75 mb-2">Selected leg: ' + escapeHtml(selectedLegMetrics.startName + " -> " + selectedLegMetrics.endName) + "</div>";
    html += '  <div class="row g-2 small mb-2">';
    html += '    <div class="col-sm-4">Leg distance: <strong>' + formatNumber(selectedLegMetrics.distNm, 1) + " nm</strong></div>";
    html += '    <div class="col-sm-4">Leg hours: <strong>' + (selectedLegMetrics.estHours === null ? "Unavailable" : formatNumber(selectedLegMetrics.estHours, 1) + " hrs") + "</strong></div>";
    html += '    <div class="col-sm-4">Leg locks: <strong>' + formatNumber(selectedLegMetrics.lockCount, 0) + "</strong></div>";
    html += "  </div>";
    if (dayEntries.length > 1) {
      html += '  <div class="small text-light opacity-75 mb-2">This leg spans <strong>' + formatNumber(dayEntries.length, 0) + "</strong> cruise timeline days at the current Max hrs/day setting.</div>";
    }

    dayEntries.forEach(function (entry, idx) {
      var day = entry && entry.day ? entry.day : {};
      var slice = entry && entry.slice ? entry.slice : null;
      var sliceDistNm = slice && Number.isFinite(slice.sliceDistNm) ? slice.sliceDistNm : selectedLegMetrics.distNm;
      var sliceHours = slice && Number.isFinite(slice.sliceHours) ? slice.sliceHours : selectedLegMetrics.estHours;
      var sliceLocks = slice ? toInt(slice.lockCount, 0) : selectedLegMetrics.lockCount;
      var sliceLabel = (slice && slice.isSplit) ? "Leg slice this day" : "Leg on this day";

      html += '<div class="card bg-transparent border-secondary text-light ' + (idx < dayEntries.length - 1 ? "mb-2" : "mb-0") + '">';
      html += '  <div class="card-body py-2 px-3">';
      html += '    <div class="d-flex justify-content-between align-items-center gap-2">';
      html += '      <div class="fw-semibold">Day ' + formatNumber(day.legIndex, 0) + " - " + escapeHtml(day.dateText || "--") + "</div>";
      html += '      <span class="badge ' + day.badgeClass + '">' + escapeHtml(day.riskColor || "GREEN") + "</span>";
      html += "    </div>";
      html += '    <div class="small text-light opacity-75 mb-2">' + escapeHtml(sliceLabel + ": " + selectedLegMetrics.startName + " -> " + selectedLegMetrics.endName) + "</div>";
      html += '    <div class="row g-2 small mb-1">';
      html += '      <div class="col-sm-4">Slice distance: <strong>' + formatNumber(sliceDistNm, 1) + " nm</strong></div>";
      html += '      <div class="col-sm-4">Slice hours: <strong>' + formatNumber(sliceHours, 1) + " hrs</strong></div>";
      html += '      <div class="col-sm-4">Slice locks: <strong>' + formatNumber(sliceLocks, 0) + "</strong></div>";
      html += "    </div>";
      html += '    <div class="small text-uppercase text-light opacity-75 mt-2 mb-1">Day Rollup</div>';
      html += '    <div class="small text-light opacity-75 mb-1">Grouped legs: <strong>' + formatNumber((Array.isArray(day.segmentIds) ? day.segmentIds.length : 0), 0) + "</strong></div>";
      html += '    <div class="small text-light opacity-75 mb-2">' + escapeHtml(day.startName + " -> " + day.endName) + "</div>";
      html += '    <div class="row g-2 small mb-1">';
      html += '      <div class="col-sm-4">Day distance: <strong>' + formatNumber(day.totalDistNm, 1) + " nm</strong></div>";
      html += '      <div class="col-sm-4">Grouped day hours: <strong>' + formatNumber(day.estHours, 1) + " hrs</strong></div>";
      html += '      <div class="col-sm-4">Day locks: <strong>' + formatNumber(day.lockCount, 0) + "</strong></div>";
      html += "    </div>";
      html += '    <div class="small text-light opacity-75 mb-2">Day rollup may include multiple legs based on Max hrs/day.</div>';
      html += '    <div class="row g-2 small">';
      html += '      <div class="col-sm-6">Required: <strong data-testid="required-fuel">' + (opts.fuelAvailable === false ? "Unavailable" : formatNumber(day.requiredFuelGallons, 1) + " gal") + "</strong></div>";
      html += '      <div class="col-sm-6">Reserve: <strong>' + (opts.fuelAvailable === false ? "Unavailable" : formatNumber(day.reserveGallons, 1) + " gal") + "</strong></div>";
      html += "    </div>";
      html += "  </div>";
      html += "</div>";
    });
    html += "</div>";
    return html;
  }

  function renderLockDetails(options) {
    var opts = options || {};
    var isLoading = !!opts.isLoading;
    var errorText = String(opts.errorText || "").trim();
    var details = opts.details;
    var html = "";
    var totals = details && typeof details === "object" ? (details.totals || details.TOTALS || {}) : {};
    var lockMessage = details && typeof details === "object"
      ? String(details.lock_message !== undefined ? details.lock_message : (details.LOCK_MESSAGE || "")).trim()
      : "";
    var locks = details && typeof details === "object"
      ? (Array.isArray(details.locks) ? details.locks : (Array.isArray(details.LOCKS) ? details.LOCKS : []))
      : [];
    var lockCount = parseInt(
      details && details.lock_count !== undefined
        ? details.lock_count
        : (details && details.LOCK_COUNT !== undefined ? details.LOCK_COUNT : locks.length),
      10
    );
    if (!Number.isFinite(lockCount) || lockCount < 0) lockCount = 0;
    var mappingUnavailable = opts.mappingAvailable === false;
    var delaysUnavailable = mappingUnavailable || opts.delayAvailable === false;
    var expectedLockCount = safeVal(opts.expectedLockCount);
    var lockCountText = mappingUnavailable
      ? (expectedLockCount !== null && expectedLockCount >= 0 ? formatNumber(expectedLockCount, 0) : "Unavailable")
      : formatNumber(lockCount, 0);
    if (mappingUnavailable) lockMessage = "Canonical lock mapping unavailable for this leg. This does not mean there are no locks.";

    html += '<div class="fpw-routegen__leglockhead">';
    html += '  <div class="fpw-routegen__kicker">Lock Navigation Details</div>';
    html += '  <div class="fpw-routegen__leglockheadactions">';
    html += '    <button type="button" class="btn-secondary btn-sm" data-leg-action="collapse-locks">Hide</button>';
    html += "  </div>";
    html += "</div>";

    if (isLoading) {
      html += '<div class="fpw-routegen__lockstate">Loading lock details...</div>';
      html += String(opts.timelineHtml || "");
      return html;
    }
    if (errorText) {
      html += '<div class="fpw-routegen__lockstate fpw-routegen__lockstate--error">' + escapeHtml(errorText) + "</div>";
      html += '<div class="fpw-routegen__leglockinlineactions">';
      html += '  <button type="button" class="btn-secondary btn-sm" data-leg-action="reload-locks">Retry</button>';
      html += "</div>";
      html += String(opts.timelineHtml || "");
      return html;
    }

    html += '<div class="fpw-routegen__locksummary">';
    html += '  <div class="fpw-routegen__lockchip"><span>Locks</span><strong>' + lockCountText + "</strong></div>";
    html += '  <div class="fpw-routegen__lockchip"><span>Best</span><strong>' + (delaysUnavailable ? "Unavailable" : formatNumber(parseFloat(totals.best_wait_min), 0) + " min") + "</strong></div>";
    html += '  <div class="fpw-routegen__lockchip"><span>Typical</span><strong>' + (delaysUnavailable ? "Unavailable" : formatNumber(parseFloat(totals.typical_wait_min), 0) + " min") + "</strong></div>";
    html += '  <div class="fpw-routegen__lockchip"><span>Worst</span><strong>' + (delaysUnavailable ? "Unavailable" : formatNumber(parseFloat(totals.worst_wait_min), 0) + " min") + "</strong></div>";
    html += "</div>";

    if (!locks.length) {
      html += '<div class="fpw-routegen__lockstate">' + escapeHtml(lockMessage || "No locks mapped for this leg.") + '</div>';
      html += String(opts.timelineHtml || "");
      return html;
    }

    html += '<div class="fpw-routegen__locklist">';
    locks.forEach(function (lock) {
      var seq = toInt(lock.seq !== undefined ? lock.seq : lock.SEQ, 0);
      var code = String(lock.lock_code !== undefined ? lock.lock_code : (lock.LOCK_CODE || "")).trim();
      var name = String(lock.name !== undefined ? lock.name : (lock.NAME || code || "Lock")).trim();
      var waterway = String(lock.waterway !== undefined ? lock.waterway : (lock.WATERWAY || "")).trim();
      var stateCode = String(lock.state_code !== undefined ? lock.state_code : (lock.STATE_CODE || "")).trim();
      var countryCode = String(lock.country_code !== undefined ? lock.country_code : (lock.COUNTRY_CODE || "")).trim();
      var lockType = String(lock.lock_type !== undefined ? lock.lock_type : (lock.LOCK_TYPE || "")).trim();
      var agency = String(lock.agency !== undefined ? lock.agency : (lock.AGENCY || "")).trim();
      var sourceUrl = String(lock.source_url !== undefined ? lock.source_url : (lock.SOURCE_URL || "")).trim();
      var lockNotes = String(lock.lock_notes !== undefined ? lock.lock_notes : (lock.LOCK_NOTES || "")).trim();
      var delayNotes = String(lock.delay_notes !== undefined ? lock.delay_notes : (lock.DELAY_NOTES || "")).trim();
      var bestWait = parseFloat(lock.best_wait_min !== undefined ? lock.best_wait_min : lock.BEST_WAIT_MIN);
      var typicalWait = parseFloat(lock.typical_wait_min !== undefined ? lock.typical_wait_min : lock.TYPICAL_WAIT_MIN);
      var worstWait = parseFloat(lock.worst_wait_min !== undefined ? lock.worst_wait_min : lock.WORST_WAIT_MIN);
      var chamberLen = parseInt(lock.chamber_length_ft !== undefined ? lock.chamber_length_ft : lock.CHAMBER_LENGTH_FT, 10);
      var chamberWid = parseInt(lock.chamber_width_ft !== undefined ? lock.chamber_width_ft : lock.CHAMBER_WIDTH_FT, 10);
      var latText = formatCoord(lock.lat !== undefined ? lock.lat : lock.LAT);
      var lngText = formatCoord(lock.lng !== undefined ? lock.lng : lock.LNG);

      html += '<div class="fpw-routegen__lockitem">';
      html += '  <div class="fpw-routegen__lockitemhead">';
      html += '    <div class="fpw-routegen__lockitemtitle">' + escapeHtml((seq > 0 ? ("#" + seq + " ") : "") + name) + "</div>";
      html += '    <div class="fpw-routegen__lockitemcode">' + escapeHtml(code || "--") + "</div>";
      html += "  </div>";
      html += '  <div class="fpw-routegen__lockitemmeta">';
      html += "    <span>" + escapeHtml(waterway || "Waterway not set") + "</span>";
      html += "    <span>" + escapeHtml((stateCode || "--") + (countryCode ? (", " + countryCode) : "")) + "</span>";
      html += "    <span>" + escapeHtml(lockType || "--") + "</span>";
      html += "    <span>Chamber " + (Number.isFinite(chamberLen) && chamberLen > 0 ? chamberLen : "--") + " x " + (Number.isFinite(chamberWid) && chamberWid > 0 ? chamberWid : "--") + " ft</span>";
      html += "    <span>Best/Typical/Worst: " + (delaysUnavailable ? "Unavailable" : formatNumber(bestWait, 0) + "/" + formatNumber(typicalWait, 0) + "/" + formatNumber(worstWait, 0) + " min") + "</span>";
      html += "    <span>Lat/Lng: " + latText + ", " + lngText + "</span>";
      html += "    <span>Agency: " + escapeHtml(agency || "--") + "</span>";
      if (lockNotes) html += "    <span>Notes: " + escapeHtml(lockNotes) + "</span>";
      if (delayNotes) html += "    <span>Delay notes: " + escapeHtml(delayNotes) + "</span>";
      if (sourceUrl) html += "    <span>Source: " + escapeHtml(sourceUrl) + "</span>";
      html += "  </div>";
      html += "</div>";
    });
    html += "</div>";
    html += String(opts.timelineHtml || "");
    return html;
  }

  function renderLegRows(legs, options) {
    var opts = options || {};
    var list = Array.isArray(legs) ? legs : [];
    return list.map(function (leg, idx) {
      var order = parseInt(
        leg.order_index !== undefined ? leg.order_index :
          (leg.ORDER_INDEX !== undefined ? leg.ORDER_INDEX : (idx + 1)),
        10
      );
      if (!Number.isFinite(order) || order <= 0) order = idx + 1;

      var startName = String(leg.start_name !== undefined ? leg.start_name : (leg.START_NAME !== undefined ? leg.START_NAME : "")).trim();
      var endName = String(leg.end_name !== undefined ? leg.end_name : (leg.END_NAME !== undefined ? leg.END_NAME : "")).trim();
      var nm = parseFloat(leg.dist_nm !== undefined ? leg.dist_nm : leg.DIST_NM);
      var routeLegId = toInt(leg.route_leg_id !== undefined ? leg.route_leg_id : leg.ROUTE_LEG_ID, 0);
      var segmentId = toInt(leg.segment_id !== undefined ? leg.segment_id : leg.SEGMENT_ID, 0);
      var lockCount = parseInt(
        leg.lock_count !== undefined ? leg.lock_count :
          (leg.LOCK_COUNT !== undefined ? leg.LOCK_COUNT : 0),
        10
      );
      var isOffshore = !!(leg.is_offshore || leg.IS_OFFSHORE);
      var isOptional = !!(leg.is_optional || leg.IS_OPTIONAL);
      var hasOverride = typeof opts.getHasOverride === "function" ? opts.getHasOverride(leg) : !!getLegField(leg, "has_override");
      if (!Number.isFinite(lockCount) || lockCount < 0) lockCount = 0;

      var flags = "";
      if (isOffshore) flags += '<span class="fpw-routegen__flag">Offshore</span>';
      if (isOptional) flags += '<span class="fpw-routegen__flag">Optional</span>';
      if (hasOverride) flags += '<span class="fpw-routegen__flag fpw-routegen__flag--override">Override</span>';
      var isSelected = (toInt(order, 0) === toInt(opts.selectedOrder, 0));
      var isExpanded = (toInt(order, 0) === toInt(opts.expandedOrder, 0));

      return ''
        + '<div class="fpw-routegen__legwrap" data-leg-order="' + String(order) + '">'
        + '  <div class="fpw-routegen__leg ' + (isSelected ? 'is-selected' : '') + ' ' + (isExpanded ? 'is-expanded' : '') + '"'
        + (idx === 0 ? ' data-tour="route-cruise-timeline-leg"' : '')
        + (opts.readOnlyGeometry ? ' role="button" tabindex="0" aria-expanded="' + String(isExpanded) + '"' : '')
        + ' data-leg-order="' + String(order) + '" data-route-leg-id="' + String(routeLegId) + '" data-segment-id="' + String(segmentId) + '">'
        + '    <div class="fpw-routegen__legidx">' + String(order).padStart(2, "0") + '</div>'
        + '    <div class="fpw-routegen__legroute">'
        + '      <div class="fpw-routegen__legname">' + escapeHtml((startName || "Start") + " -> " + (endName || "End")) + flags + '</div>'
        + '    </div>'
        + '    <div class="fpw-routegen__leglocks">' + formatNumber(lockCount, 0) + '</div>'
        + '    <div class="fpw-routegen__legnm">' + formatNumber(Number.isFinite(nm) ? nm : 0, 1) + ' NM</div>'
        + '    <div class="fpw-routegen__legmapaction">' + (opts.readOnlyGeometry ? '<span class="fpw-routegen__geometry-status">' + escapeHtml(typeof opts.getGeometryLabel === "function" ? opts.getGeometryLabel(leg) : "Read-only") + '</span>' : '<button type="button" class="btn-secondary btn-sm fpw-routegen__legmapbtn" data-leg-action="open-map">Edit Route</button>') + '</div>'
        + '  </div>'
        + (typeof opts.getLockPanelHtml === "function" ? opts.getLockPanelHtml(leg, order) : "")
        + '</div>';
    }).join("");
  }

  function buildSummaryModel(payload, ui) {
    var inputs = Object.assign({}, ui || {}, { timelineCruiseOnly: true });
    var presentationPayload = payload;
    // Missing public fuel inputs are unavailable, not a meaningful zero estimate.
    // Mask only presentation fields, then let the existing summary helper format them.
    if (inputs.fuelAvailable === false && payload) {
      presentationPayload = Object.assign({}, payload, {
        summary: Object.assign({}, payload.summary, { totalRequiredFuel: null }),
        meta: Object.assign({}, payload.meta, { fuelBurnGph: null, weatherAdjustedBurnGph: null }),
        days: (Array.isArray(payload.days) ? payload.days : []).map(function (day) {
          return Object.assign({}, day, { requiredFuelGallons: null, reserveGallons: null });
        })
      });
      inputs.idleBurnGph = null;
      inputs.idleHoursTotal = null;
    }
    return window.FPW.SharedFuelMath.buildCruiseTimelineSummaryModel(presentationPayload, inputs);
  }

  window.FPW.CruiseTimelineView = {
    normalizePayload: normalizePayload,
    getEntriesForLeg: getEntriesForLeg,
    getLegMetrics: getLegMetrics,
    renderDayDetails: renderDayDetails,
    renderLockDetails: renderLockDetails,
    renderLegRows: renderLegRows,
    buildSummaryModel: buildSummaryModel
  };
})(window);
