(function (window, document) {
  "use strict";

  var state = {
    slug: "",
    token: "",
    streamId: 0,
    stream: null,
    bootstrap: null,
    posts: [],
    followerToken: "",
    followerStorageKey: "",
    mapPayload: null,
    isOwner: false,
    timeline: {
      payload: null,
      legs: [],
      expandedLegOrder: 0
    }
  };

  var dom = {};

  function safeNum(value) {
    var n = parseFloat(value);
    if (!Number.isFinite(n)) return null;
    return n;
  }

  function toInt(value, fallback) {
    var n = parseInt(value, 10);
    return Number.isFinite(n) ? n : (fallback || 0);
  }

  function escapeHtml(value) {
    return String(value === undefined || value === null ? "" : value)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/\"/g, "&quot;")
      .replace(/'/g, "&#39;");
  }

  function apiUrl(action) {
    var base = window.FPW_BASE || "";
    return base + "/api/v1/voyage.cfc?method=handle&action=" + encodeURIComponent(action) + "&returnFormat=json";
  }

  function readSlugTokenFromUrl() {
    var params = new URLSearchParams(window.location.search || "");
    var slug = (params.get("slug") || "").trim();
    var token = (params.get("t") || "").trim();
    var streamId = toInt(params.get("stream_id"), 0);
    var parts = (window.location.pathname || "").split("/").filter(Boolean);
    var i;

    if (!slug) {
      for (i = 0; i < parts.length; i += 1) {
        if (parts[i].toLowerCase() === "follow" && parts[i + 1]) {
          slug = decodeURIComponent(parts[i + 1]);
          break;
        }
      }
    }

    return {
      slug: slug,
      token: token,
      streamId: streamId
    };
  }

  function fetchJson(action, payload) {
    return fetch(apiUrl(action), {
      method: "POST",
      credentials: "same-origin",
      headers: {
        "Content-Type": "application/json; charset=utf-8"
      },
      body: JSON.stringify(payload || {})
    })
      .then(function (res) { return res.text(); })
      .then(function (txt) {
        var json;
        try {
          json = txt ? JSON.parse(txt) : {};
        } catch (err) {
          throw new Error("Non-JSON response from voyage API.");
        }
        if (!json || json.SUCCESS === false) {
          var msg = (json && json.ERROR && json.ERROR.MESSAGE) || json.MESSAGE || "Request failed";
          throw new Error(msg);
        }
        return json;
      });
  }

  function cacheFollowerToken(token) {
    if (!state.followerStorageKey) return;
    if (!token) return;
    try {
      window.localStorage.setItem(state.followerStorageKey, token);
    } catch (err) {
      // Ignore local storage issues in viewer mode.
    }
  }

  function readCachedFollowerToken() {
    if (!state.followerStorageKey) return "";
    try {
      return window.localStorage.getItem(state.followerStorageKey) || "";
    } catch (err) {
      return "";
    }
  }

  function formatTimeLabel(input) {
    if (!input) return "n/a";
    var date = new Date(input);
    if (Number.isNaN(date.getTime())) {
      return String(input);
    }
    return date.toLocaleString([], {
      month: "short",
      day: "numeric",
      hour: "numeric",
      minute: "2-digit"
    });
  }

  function findFirstPhotoCount(posts) {
    var list = Array.isArray(posts) ? posts : [];
    var count = 0;
    list.forEach(function (post) {
      if (post && post.media_url) count += 1;
    });
    return count;
  }

  function renderHeaderAndCards(payload) {
    var stream = payload.stream || {};
    var topCards = payload.topCards || {};
    var pinned = payload.pinned || {};
    var title = stream.title || "Voyage Stream";
    var status = topCards.status || stream.status || "n/a";
    var lastCheckin = topCards.last_checkin || "n/a";
    var location = topCards.location_label || "n/a";
    var nextStop = topCards.next_stop || "n/a";
    var eta = topCards.eta || "n/a";
    var conditions = topCards.conditions || "n/a";
    var miles = safeNum(pinned.miles);
    var days = toInt(pinned.days, 0);
    var locks = toInt(pinned.locks, 0);
    var wildlife = toInt(pinned.wildlife, 0);
    var progressPct = 0;

    if (dom.shareTitle) dom.shareTitle.textContent = title;
    if (dom.tripTitle) dom.tripTitle.textContent = title;
    if (dom.shareStatusPill) dom.shareStatusPill.textContent = status;
    if (dom.shareLastCheckin) dom.shareLastCheckin.textContent = lastCheckin;
    if (dom.sharePath) dom.sharePath.textContent = "/follow/" + (stream.slug || state.slug || "");
    if (dom.shareViewerCount) dom.shareViewerCount.textContent = "0";

    if (dom.cardStatusValue) dom.cardStatusValue.textContent = status;
    if (dom.cardStatusSub) dom.cardStatusSub.textContent = "Last check-in: " + lastCheckin;
    if (dom.cardLocationValue) dom.cardLocationValue.textContent = location;
    if (dom.cardLocationSub) dom.cardLocationSub.textContent = "Heading: " + nextStop;
    if (dom.cardEtaValue) dom.cardEtaValue.textContent = eta;
    if (dom.cardEtaSub) dom.cardEtaSub.textContent = "Next stop: " + nextStop;
    if (dom.cardConditionsValue) dom.cardConditionsValue.textContent = conditions;
    if (dom.cardConditionsSub) dom.cardConditionsSub.textContent = "Based on latest stream updates";

    if (dom.overlayLeg) dom.overlayLeg.textContent = location + " to " + nextStop;
    if (dom.overlayProgress) dom.overlayProgress.textContent = (miles === null ? "n/a" : miles.toFixed(1) + " mi");
    if (dom.overlayCheckin) dom.overlayCheckin.textContent = lastCheckin;

    if (dom.pinnedUpdated) dom.pinnedUpdated.textContent = "Updated " + (pinned.updated_label || "n/a");
    if (dom.pinnedMiles) dom.pinnedMiles.textContent = (miles === null ? "0" : miles.toFixed(1));
    if (dom.pinnedDays) dom.pinnedDays.textContent = String(days);
    if (dom.pinnedLocks) dom.pinnedLocks.textContent = String(locks);
    if (dom.pinnedWildlife) dom.pinnedWildlife.textContent = String(wildlife);

    if (dom.summaryMiles) dom.summaryMiles.textContent = (miles === null ? "0" : miles.toFixed(1)) + " mi";
    if (dom.summarySub) dom.summarySub.textContent = String(days) + " days | " + String(locks) + " locks | " + String(wildlife) + " wildlife";
    if (dom.summaryMeta) dom.summaryMeta.textContent = "Confidence: route-based";

    progressPct = Math.min(100, Math.max(0, days > 0 ? Math.round((days / Math.max(days, 1)) * 100) : 0));
    if (dom.progressFill) dom.progressFill.style.width = progressPct + "%";
    if (dom.progressMarker) dom.progressMarker.style.left = progressPct + "%";
    if (dom.progressHours) dom.progressHours.textContent = (miles === null ? "n/a" : miles.toFixed(1) + " mi");
    if (dom.progressSub) dom.progressSub.textContent = "Current location: " + location;
  }

  function formatTimelineNumber(value, decimals) {
    var n = safeNum(value);
    if (n === null) return "n/a";
    return n.toFixed(Math.max(0, toInt(decimals, 0)));
  }

  function timelineValueText(value, decimals, suffix) {
    var n = safeNum(value);
    var unit = String(suffix || "").trim();
    if (n === null) return "n/a";
    return formatTimelineNumber(n, decimals) + (unit ? (" " + unit) : "");
  }

  function formatCoord(value) {
    var n = safeNum(value);
    if (n === null) return "--";
    return n.toFixed(5);
  }

  function renderLegLockDetailsHtml(leg) {
    var row = (leg && typeof leg === "object") ? leg : {};
    var details = (row.lock_details && typeof row.lock_details === "object")
      ? row.lock_details
      : ((row.lockDetails && typeof row.lockDetails === "object") ? row.lockDetails : {});
    var totals = (details.totals && typeof details.totals === "object")
      ? details.totals
      : ((details.TOTALS && typeof details.TOTALS === "object") ? details.TOTALS : {});
    var locks = Array.isArray(details.locks) ? details.locks : (Array.isArray(details.LOCKS) ? details.LOCKS : []);
    var lockCount = toInt(
      details.lock_count !== undefined
        ? details.lock_count
        : (details.LOCK_COUNT !== undefined ? details.LOCK_COUNT : row.locks),
      0
    );
    var lockMessage = String(details.lock_message || details.LOCK_MESSAGE || "").trim();
    var html = "";

    if (lockCount < 0) lockCount = 0;
    if (lockCount <= 0 && !locks.length) {
      return "";
    }

    html += '<div class="follow-timeline-locksummary">';
    html += '  <div class="follow-timeline-lockchip"><span>Locks</span><strong>' + formatTimelineNumber(lockCount, 0) + '</strong></div>';
    html += '  <div class="follow-timeline-lockchip"><span>Best</span><strong>' + formatTimelineNumber(totals.best_wait_min, 0) + ' min</strong></div>';
    html += '  <div class="follow-timeline-lockchip"><span>Typical</span><strong>' + formatTimelineNumber(totals.typical_wait_min, 0) + ' min</strong></div>';
    html += '  <div class="follow-timeline-lockchip"><span>Worst</span><strong>' + formatTimelineNumber(totals.worst_wait_min, 0) + ' min</strong></div>';
    html += '</div>';

    if (!locks.length) {
      html += '<div class="follow-timeline-lockstate">'
        + escapeHtml(lockMessage || (lockCount > 0 ? "Lock count captured for this leg; detailed mapping unavailable." : "No locks mapped for this leg."))
        + '</div>';
      return html;
    }

    html += '<div class="follow-timeline-locklist">';
    locks.forEach(function (lock) {
      var seq = toInt(lock.seq !== undefined ? lock.seq : lock.SEQ, 0);
      var code = String(lock.lock_code !== undefined ? lock.lock_code : (lock.LOCK_CODE || "")).trim();
      var name = String(lock.name !== undefined ? lock.name : (lock.NAME || code || "Lock")).trim();
      var waterway = String(lock.waterway !== undefined ? lock.waterway : (lock.WATERWAY || "")).trim();
      var stateCode = String(lock.state_code !== undefined ? lock.state_code : (lock.STATE_CODE || "")).trim();
      var countryCode = String(lock.country_code !== undefined ? lock.country_code : (lock.COUNTRY_CODE || "")).trim();
      var lockType = String(lock.lock_type !== undefined ? lock.lock_type : (lock.LOCK_TYPE || "")).trim();
      var bestWait = safeNum(lock.best_wait_min !== undefined ? lock.best_wait_min : lock.BEST_WAIT_MIN);
      var typicalWait = safeNum(lock.typical_wait_min !== undefined ? lock.typical_wait_min : lock.TYPICAL_WAIT_MIN);
      var worstWait = safeNum(lock.worst_wait_min !== undefined ? lock.worst_wait_min : lock.WORST_WAIT_MIN);
      var chamberLen = toInt(lock.chamber_length_ft !== undefined ? lock.chamber_length_ft : lock.CHAMBER_LENGTH_FT, 0);
      var chamberWid = toInt(lock.chamber_width_ft !== undefined ? lock.chamber_width_ft : lock.CHAMBER_WIDTH_FT, 0);
      var latText = formatCoord(lock.lat !== undefined ? lock.lat : lock.LAT);
      var lngText = formatCoord(lock.lng !== undefined ? lock.lng : lock.LNG);
      var notesText = String(lock.lock_notes !== undefined ? lock.lock_notes : (lock.LOCK_NOTES || "")).trim();
      var delayNotes = String(lock.delay_notes !== undefined ? lock.delay_notes : (lock.DELAY_NOTES || "")).trim();

      html += '<div class="follow-timeline-lockitem">';
      html += '  <div class="follow-timeline-lockitemhead">';
      html += '    <div class="follow-timeline-lockitemtitle">' + escapeHtml((seq > 0 ? ("#" + seq + " ") : "") + name) + '</div>';
      html += '    <div class="follow-timeline-lockitemcode">' + escapeHtml(code || "--") + '</div>';
      html += '  </div>';
      html += '  <div class="follow-timeline-lockitemmeta">';
      html += '    <span>' + escapeHtml(waterway || "Waterway not set") + '</span>';
      html += '    <span>' + escapeHtml((stateCode || "--") + (countryCode ? (", " + countryCode) : "")) + '</span>';
      html += '    <span>' + escapeHtml(lockType || "--") + '</span>';
      html += '    <span>Chamber ' + (chamberLen > 0 ? String(chamberLen) : "--") + ' x ' + (chamberWid > 0 ? String(chamberWid) : "--") + ' ft</span>';
      html += '    <span>Best/Typical/Worst: ' + formatTimelineNumber(bestWait, 0) + '/' + formatTimelineNumber(typicalWait, 0) + '/' + formatTimelineNumber(worstWait, 0) + ' min</span>';
      html += '    <span>Lat/Lng: ' + escapeHtml(latText + ", " + lngText) + '</span>';
      if (notesText) html += '    <span>Notes: ' + escapeHtml(notesText) + '</span>';
      if (delayNotes) html += '    <span>Delay notes: ' + escapeHtml(delayNotes) + '</span>';
      html += '  </div>';
      html += '</div>';
    });
    html += '</div>';
    return html;
  }

  function renderCruiseTimelineInline(timeline) {
    var payload = (timeline && typeof timeline === "object") ? timeline : {};
    var summary = (payload.summary && typeof payload.summary === "object") ? payload.summary : null;
    var meta = (payload.meta && typeof payload.meta === "object") ? payload.meta : {};
    var missing = Array.isArray(meta.missing_inputs) ? meta.missing_inputs : [];
    var totalNm;
    var totalHours;
    var totalDays;
    var totalLocks;
    var fuelEst;
    var reserveEst;
    var inputsSource;
    var maxHours;
    var speedKn;
    var summaryHtml;

    if (!dom.followTimelineSummary) return;
    state.timeline.payload = payload;

    if (!summary) {
      dom.followTimelineSummary.innerHTML = '<div class="follow-timeline-empty">Timeline not available yet.</div>';
      return;
    }

    totalNm = formatTimelineNumber(summary.total_nm, 1);
    totalHours = formatTimelineNumber(summary.total_hours, 2);
    totalDays = formatTimelineNumber(summary.total_days, 0);
    totalLocks = formatTimelineNumber(summary.total_locks, 0);
    fuelEst = formatTimelineNumber(summary.fuel_est, 1);
    reserveEst = formatTimelineNumber(summary.reserve_est, 1);
    inputsSource = String(meta.inputs_source || "default").trim() || "default";
    maxHours = formatTimelineNumber(summary.max_hours_per_day, 1);
    speedKn = formatTimelineNumber(summary.effective_speed_kn, 2);

    summaryHtml = ''
      + '<div class="follow-timeline-route-total">Route total: ' + totalDays + ' days | ' + totalNm + ' nm | ' + totalHours + ' hrs</div>'
      + '<div class="follow-timeline-chiprow">'
      + '  <div class="follow-timeline-chip"><span>Locks</span><strong>' + totalLocks + '</strong></div>'
      + '  <div class="follow-timeline-chip"><span>Max hrs/day</span><strong>' + maxHours + '</strong></div>'
      + '  <div class="follow-timeline-chip"><span>Eff speed</span><strong>' + speedKn + ' kn</strong></div>'
      + '  <div class="follow-timeline-chip"><span>Fuel + Reserve</span><strong>' + fuelEst + ' + ' + reserveEst + ' gal</strong></div>'
      + '</div>'
      + '<div class="follow-timeline-meta">Inputs: ' + escapeHtml(inputsSource)
      + (missing.length ? (' | Missing: ' + escapeHtml(missing.join(", "))) : '')
      + (meta.zero_speed_guard ? ' | zero_speed_guard=true' : '')
      + '</div>';

    dom.followTimelineSummary.innerHTML = summaryHtml;
  }

  function renderCruiseTimelineLegPane(row, timelinePayload) {
    var leg = (row && typeof row === "object") ? row : {};
    var payload = (timelinePayload && typeof timelinePayload === "object") ? timelinePayload : {};
    var summary = (payload.summary && typeof payload.summary === "object") ? payload.summary : {};
    var meta = (payload.meta && typeof payload.meta === "object") ? payload.meta : {};
    var order = toInt(leg.leg_order, 0);
    var dayBucket = toInt(leg.day_bucket, 0);
    var dayLabel = dayBucket > 0 ? String(dayBucket) : "n/a";
    var legText = String(leg.label || (String(leg.start_name || "Start") + " -> " + String(leg.end_name || "End"))).trim();
    var progress = (leg.progress && typeof leg.progress === "object") ? leg.progress : {};
    var progressPct = timelineValueText(progress.percent_complete, 0, "%");
    var lastUpdateRaw = String(progress.last_update_ts || "").trim();
    var lastUpdateText = lastUpdateRaw ? formatTimeLabel(lastUpdateRaw) : "n/a";
    var cumulativeHours = timelineValueText(leg.cumulative_hours, 2, "h");
    var maxHoursPerDay = timelineValueText(summary.max_hours_per_day, 1, "h");
    var dayFormula = "ceil(cumulative_hours / max_hours_per_day)";
    var inputsSource = String(meta.inputs_source || "default").trim() || "default";
    var missingInputs = Array.isArray(meta.missing_inputs) ? meta.missing_inputs : [];
    var formulaText = String(meta.formula || "").trim();
    var legFuelBurnGph = timelineValueText(summary.fuel_burn_gph, 1, "gph");
    var legFuelEst = timelineValueText((safeNum(summary.fuel_burn_gph) !== null && safeNum(leg.hours) !== null)
      ? (safeNum(summary.fuel_burn_gph) * safeNum(leg.hours))
      : null, 1, "gal");
    var lockDetailsHtml = renderLegLockDetailsHtml(leg);

    if (dayBucket > 0) {
      dayFormula = dayFormula + " = " + dayLabel;
    } else {
      dayFormula = dayFormula + " = n/a";
    }

    return ''
      + '<div class="follow-timeline-legpanel is-open" data-leg-order="' + String(order) + '">'
      + '  <div class="follow-timeline-legpanelhead">'
      + '    <div>'
      + '      <div class="follow-timeline-kicker">Cruise Timeline Day</div>'
      + '      <div class="follow-timeline-legpaneltitle">Day ' + escapeHtml(dayLabel) + ' | Leg ' + escapeHtml(String(order).padStart(2, "0")) + '</div>'
      + '    </div>'
      + '    <div class="follow-timeline-legpanelactions">'
      + '      <button type="button" class="btn tiny" data-timeline-action="collapse-leg" data-leg-order="' + String(order) + '">Hide</button>'
      + '    </div>'
      + '  </div>'
      + '  <div class="follow-timeline-legpanelroute">' + escapeHtml(legText) + '</div>'
      + '  <div class="follow-timeline-legpanelgrid">'
      + '    <div class="follow-timeline-legpanelchip"><span>Leg distance</span><strong>' + timelineValueText(leg.dist_nm, 1, "nm") + '</strong></div>'
      + '    <div class="follow-timeline-legpanelchip"><span>Leg hours</span><strong>' + timelineValueText(leg.hours, 2, "h") + '</strong></div>'
      + '    <div class="follow-timeline-legpanelchip"><span>Leg locks</span><strong>' + timelineValueText(leg.locks, 0, "") + '</strong></div>'
      + '    <div class="follow-timeline-legpanelchip"><span>Progress</span><strong>' + progressPct + '</strong></div>'
      + '  </div>'
      + lockDetailsHtml
      + '  <div class="follow-timeline-legpanelmeta">Day bucket: ' + escapeHtml(dayFormula) + ' | cumulative ' + escapeHtml(cumulativeHours) + ' | max/day ' + escapeHtml(maxHoursPerDay) + '</div>'
      + '  <div class="follow-timeline-legpanelmeta">Fuel est: ' + escapeHtml(legFuelEst) + ' @ ' + escapeHtml(legFuelBurnGph) + '</div>'
      + '  <div class="follow-timeline-legpanelmeta">Last update: ' + escapeHtml(lastUpdateText) + '</div>'
      + '  <div class="follow-timeline-legpanelnote">Inputs source: ' + escapeHtml(inputsSource)
      + (missingInputs.length ? (' | Missing: ' + escapeHtml(missingInputs.join(", "))) : '')
      + (formulaText ? (' | ' + escapeHtml(formulaText)) : '')
      + '</div>'
      + '</div>';
  }

  function toggleCruiseTimelineLeg(orderRaw) {
    var order = toInt(orderRaw, 0);
    if (order <= 0) return;
    if (toInt(state.timeline.expandedLegOrder, 0) === order) {
      state.timeline.expandedLegOrder = 0;
    } else {
      state.timeline.expandedLegOrder = order;
    }
    renderCruiseTimelineLegs(state.timeline.legs);
  }

  function renderCruiseTimelineLegs(legs) {
    var list = Array.isArray(legs) ? legs : [];
    var html = "";
    var expandedOrder = toInt(state.timeline.expandedLegOrder, 0);

    if (!dom.followTimelineLegList) return;
    state.timeline.legs = list;

    if (!list.length) {
      state.timeline.expandedLegOrder = 0;
      dom.followTimelineLegList.innerHTML = '<div class="follow-timeline-empty">No leg timeline available.</div>';
      return;
    }
    if (!list.some(function (row) { return toInt(row.leg_order, 0) === expandedOrder; })) {
      expandedOrder = 0;
      state.timeline.expandedLegOrder = 0;
    }

    html += '<div class="follow-timeline-legcols">'
      + '<span>#</span><span>Leg</span><span>Locks</span><span>NM</span><span>Hours</span><span>Day</span>'
      + '</div>';

    html += list.map(function (leg, idx) {
      var row = (leg && typeof leg === "object") ? leg : {};
      var order = toInt(row.leg_order, idx + 1);
      var isExpanded = (expandedOrder === order);
      var label = String(row.label || "").trim();
      var startName = String(row.start_name || "Start").trim() || "Start";
      var endName = String(row.end_name || "End").trim() || "End";
      var nm = formatTimelineNumber(row.dist_nm, 1);
      var hours = formatTimelineNumber(row.hours, 2);
      var locks = formatTimelineNumber(row.locks, 0);
      var dayBucketNum = toInt(row.day_bucket, 0);
      var dayLabel = dayBucketNum > 0 ? ("D" + String(dayBucketNum)) : "n/a";
      var progress = (row.progress && typeof row.progress === "object") ? row.progress : {};
      var pct = formatTimelineNumber(progress.percent_complete, 0);
      var lastUpdateRaw = String(progress.last_update_ts || "").trim();
      var lastUpdate = lastUpdateRaw ? formatTimeLabel(lastUpdateRaw) : "";
      var legText = label || (startName + " -> " + endName);
      var progressText = "Progress " + pct + "%";
      if (lastUpdate) {
        progressText += " | Updated " + lastUpdate;
      }

      return ''
        + '<div class="follow-timeline-legwrap" data-leg-order="' + String(order) + '">'
        + '  <div class="follow-timeline-leg ' + (isExpanded ? "is-selected is-expanded" : "") + '" role="button" tabindex="0" aria-expanded="' + (isExpanded ? "true" : "false") + '" data-leg-order="' + String(order) + '">'
        + '    <div class="follow-timeline-legidx">' + String(order).padStart(2, "0") + '</div>'
        + '    <div class="follow-timeline-legroute">'
        + '      <div class="follow-timeline-legname">' + escapeHtml(legText) + '</div>'
        + '      <div class="follow-timeline-legmeta">' + escapeHtml(progressText) + '</div>'
        + '    </div>'
        + '    <div class="follow-timeline-leglocks">' + locks + '</div>'
        + '    <div class="follow-timeline-legnm">' + nm + ' NM</div>'
        + '    <div class="follow-timeline-leghours">' + hours + ' h</div>'
        + '    <div class="follow-timeline-legday">' + dayLabel + '</div>'
        + '  </div>'
        + (isExpanded ? renderCruiseTimelineLegPane(row, state.timeline.payload || {}) : "")
        + '</div>';
    }).join("");

    dom.followTimelineLegList.innerHTML = html;
  }

  function wireCruiseTimelineInteractions() {
    if (!dom.followTimelineLegList) return;

    dom.followTimelineLegList.addEventListener("click", function (event) {
      var collapseBtn = event.target.closest('[data-timeline-action="collapse-leg"]');
      var rowEl;
      if (collapseBtn) {
        event.preventDefault();
        state.timeline.expandedLegOrder = 0;
        renderCruiseTimelineLegs(state.timeline.legs);
        return;
      }
      rowEl = event.target.closest(".follow-timeline-leg[data-leg-order]");
      if (!rowEl) return;
      event.preventDefault();
      toggleCruiseTimelineLeg(rowEl.getAttribute("data-leg-order"));
    });

    dom.followTimelineLegList.addEventListener("keydown", function (event) {
      var rowEl = event.target.closest(".follow-timeline-leg[data-leg-order]");
      if (!rowEl) return;
      if (event.key === "Enter" || event.key === " ") {
        event.preventDefault();
        toggleCruiseTimelineLeg(rowEl.getAttribute("data-leg-order"));
      }
    });
  }

  function renderMap(payloadMap) {
    var api = window.FPWFollowMap;
    var mapData = (payloadMap && typeof payloadMap === "object") ? payloadMap : {};
    var routeGeo = mapData.routeGeo || {};
    var pins = Array.isArray(mapData.pins) ? mapData.pins : [];
    var current = (mapData.current && typeof mapData.current === "object") ? mapData.current : {};

    state.mapPayload = mapData;

    if (!api || typeof api.initFollowMap !== "function") return;

    api.initFollowMap("followMap", {});
    api.renderRoute(routeGeo);
    api.renderPins(pins);
    api.fitBoundsToRoute(routeGeo, pins);

    if (current.lat !== undefined && current.lng !== undefined) {
      api.updateBoatMarker(current.lat, current.lng, current.label || "Current position");
    }
  }

  function reactionLabel(emoji) {
    if (emoji === "like") return "Like";
    if (emoji === "love") return "Love";
    if (emoji === "boat") return "Boat";
    if (emoji === "wave") return "Wave";
    return "React";
  }

  function postTag(post) {
    var authorType = String(post.author_type || "").toLowerCase();
    if (authorType === "system") {
      return '<span class="tag fpw">FPW</span>';
    }
    if (authorType === "owner") {
      return '<span class="tag">Captain</span>';
    }
    return '<span class="tag">Follower</span>';
  }

  function renderPost(post) {
    var id = toInt(post.id, 0);
    var title = String(post.title || "").trim();
    var body = String(post.body || "").trim();
    var created = formatTimeLabel(post.created_utc);
    var reactions = post.reaction_counts || {};
    var viewerReactions = post.viewer_reactions || {};
    var comments = Array.isArray(post.comments) ? post.comments : [];
    var mediaHtml = "";
    var titleHtml = "";
    var commentsHtml;

    if (!title) {
      title = body ? body.slice(0, 90) : "Update";
    }

    if (post.media_url) {
      mediaHtml = '<img class="postMedia" src="' + escapeHtml(post.media_url) + '" alt="Voyage photo" loading="lazy" />';
    }

    commentsHtml = comments.map(function (comment) {
      return ''
        + '<div class="comment">'
        + '  <div class="who">' + escapeHtml(comment.display_name || "Viewer") + '</div>'
        + '  <div class="txt">' + escapeHtml(comment.body || "") + '</div>'
        + '</div>';
    }).join("");

    titleHtml = ''
      + '<div class="postTitle">'
      + postTag(post)
      + '<b>' + escapeHtml(title) + '</b>'
      + '</div>';

    return ''
      + '<article class="post" data-post-id="' + String(id) + '">'
      + '  <div class="postHead">'
      + titleHtml
      + '    <div class="postTime">' + escapeHtml(created) + '</div>'
      + '  </div>'
      + mediaHtml
      + '  <div class="postBody">' + escapeHtml(body).replace(/\n/g, "<br />") + '</div>'
      + '  <div class="postActions">'
      + '    <div class="reactions">'
      + '      <button class="reactBtn ' + (viewerReactions.like ? "active" : "") + '" data-react="like" data-post-id="' + String(id) + '">Like <span class="count">' + String(toInt(reactions.like, 0)) + '</span></button>'
      + '      <button class="reactBtn ' + (viewerReactions.love ? "active" : "") + '" data-react="love" data-post-id="' + String(id) + '">Love <span class="count">' + String(toInt(reactions.love, 0)) + '</span></button>'
      + '      <button class="reactBtn ' + (viewerReactions.boat ? "active" : "") + '" data-react="boat" data-post-id="' + String(id) + '">Boat <span class="count">' + String(toInt(reactions.boat, 0)) + '</span></button>'
      + '      <button class="reactBtn ' + (viewerReactions.wave ? "active" : "") + '" data-react="wave" data-post-id="' + String(id) + '">Wave <span class="count">' + String(toInt(reactions.wave, 0)) + '</span></button>'
      + '    </div>'
      + '    <div class="commentBox">'
      + '      <input class="commentInput" data-comment-input="' + String(id) + '" maxlength="500" placeholder="Add a comment..." />'
      + '      <button class="btn tiny" data-comment-submit="' + String(id) + '">Comment</button>'
      + '    </div>'
      + '    <div class="comments" id="comments-' + String(id) + '">'
      + (commentsHtml || "")
      + '    </div>'
      + '  </div>'
      + '</article>';
  }

  function renderPosts(posts) {
    var list = Array.isArray(posts) ? posts : [];
    var html = "";

    state.posts = list;
    if (!dom.postsContainer) return;

    if (!list.length) {
      dom.postsContainer.innerHTML = '<div class="emptyState">No posts yet. Add the first voyage update.</div>';
      if (dom.photoCount) dom.photoCount.textContent = "0 new";
      return;
    }

    html = list.map(renderPost).join("");
    dom.postsContainer.innerHTML = html;
    if (dom.photoCount) {
      dom.photoCount.textContent = String(findFirstPhotoCount(list)) + " new";
    }
  }

  function applyReactionCounts(postId, counts, activeEmoji) {
    var article = dom.postsContainer ? dom.postsContainer.querySelector('[data-post-id="' + String(postId) + '"]') : null;
    var reactionNames = ["like", "love", "boat", "wave"];

    if (!article) return;

    reactionNames.forEach(function (name) {
      var btn = article.querySelector('[data-react="' + name + '"]');
      var countEl;
      var value = toInt(counts[name], 0);
      if (!btn) return;
      countEl = btn.querySelector(".count");
      if (countEl) countEl.textContent = String(value);
      if (name === activeEmoji) {
        btn.classList.add("active");
      }
    });
  }

  function appendCommentToUi(postId, displayName, text, pending) {
    var container = document.getElementById("comments-" + String(postId));
    var div;
    if (!container) return null;

    div = document.createElement("div");
    div.className = "comment" + (pending ? " pending" : "");
    div.innerHTML = ''
      + '<div class="who">' + escapeHtml(displayName || "You") + '</div>'
      + '<div class="txt">' + escapeHtml(text || "") + '</div>';
    container.appendChild(div);
    return div;
  }

  function ensureFollowerToken(forcePrompt) {
    var shouldPrompt = !!forcePrompt;
    var displayName;
    var email = "";
    var password = "";

    if (state.followerToken && !shouldPrompt) {
      return Promise.resolve(state.followerToken);
    }

    displayName = window.prompt("Enter a display name for reactions/comments:", "Viewer") || "";
    displayName = displayName.trim();
    if (!displayName) {
      return Promise.reject(new Error("Display name is required."));
    }

    email = (window.prompt("Optional email (leave blank to skip):", "") || "").trim();
    if (state.stream && state.stream.privacy_mode === "password") {
      password = (window.prompt("Enter stream password:", "") || "").trim();
    }

    return fetchJson("followerIdentify", {
      stream_id: state.streamId,
      display_name: displayName,
      email: email,
      password: password,
      t: state.token
    }).then(function (res) {
      state.followerToken = String(res.follower_token || "");
      cacheFollowerToken(state.followerToken);
      if (dom.followActionBtn) dom.followActionBtn.textContent = "Following";
      return state.followerToken;
    });
  }

  function onReactClick(button) {
    var postId = toInt(button.getAttribute("data-post-id"), 0);
    var emoji = String(button.getAttribute("data-react") || "").trim();
    var countEl = button.querySelector(".count");
    var currentCount = countEl ? toInt(countEl.textContent, 0) : 0;
    var wasActive = button.classList.contains("active");
    var nextCount = Math.max(0, currentCount + (wasActive ? -1 : 1));

    if (postId <= 0 || !emoji) return;

    button.classList.toggle("active", !wasActive);
    if (countEl) countEl.textContent = String(nextCount);

    ensureFollowerToken(false)
      .then(function (token) {
        return fetchJson("toggleReaction", {
          post_id: postId,
          emoji: emoji,
          follower_token: token
        });
      })
      .then(function (res) {
        applyReactionCounts(postId, res.reaction_counts || {}, res.active ? emoji : "");
        if (!res.active) {
          var btn = dom.postsContainer.querySelector('[data-post-id="' + String(postId) + '"] [data-react="' + emoji + '"]');
          if (btn) btn.classList.remove("active");
        }
      })
      .catch(function (err) {
        button.classList.toggle("active", wasActive);
        if (countEl) countEl.textContent = String(currentCount);
        window.alert((err && err.message) ? err.message : "Unable to react.");
      });
  }

  function onCommentSubmit(postId) {
    var input = dom.postsContainer ? dom.postsContainer.querySelector('[data-comment-input="' + String(postId) + '"]') : null;
    var text = input ? String(input.value || "").trim() : "";
    var pendingNode;

    if (!input || !text) return;
    if (text.length > 500) {
      window.alert("Comment must be 500 characters or less.");
      return;
    }

    input.value = "";
    pendingNode = appendCommentToUi(postId, "You", text, true);

    ensureFollowerToken(false)
      .then(function (token) {
        return fetchJson("addComment", {
          post_id: postId,
          body: text,
          follower_token: token
        });
      })
      .then(function (res) {
        var comment = (res && res.comment) ? res.comment : null;
        if (!comment) return;
        if (pendingNode && pendingNode.parentNode) {
          pendingNode.parentNode.removeChild(pendingNode);
        }
        appendCommentToUi(postId, comment.display_name || "You", comment.body || text, false);
      })
      .catch(function (err) {
        if (pendingNode && pendingNode.parentNode) {
          pendingNode.parentNode.removeChild(pendingNode);
        }
        window.alert((err && err.message) ? err.message : "Unable to post comment.");
      });
  }

  function wirePostInteractions() {
    if (!dom.postsContainer) return;

    dom.postsContainer.addEventListener("click", function (event) {
      var reactBtn = event.target.closest("[data-react]");
      var commentBtn = event.target.closest("[data-comment-submit]");
      if (reactBtn) {
        event.preventDefault();
        onReactClick(reactBtn);
        return;
      }
      if (commentBtn) {
        event.preventDefault();
        onCommentSubmit(toInt(commentBtn.getAttribute("data-comment-submit"), 0));
      }
    });

    dom.postsContainer.addEventListener("keydown", function (event) {
      var input = event.target.closest("[data-comment-input]");
      if (!input) return;
      if (event.key === "Enter" && !event.shiftKey) {
        event.preventDefault();
        onCommentSubmit(toInt(input.getAttribute("data-comment-input"), 0));
      }
    });
  }

  function loadPosts() {
    return fetchJson("listPosts", {
      stream_id: state.streamId,
      cursor: 0,
      limit: 30,
      t: state.token,
      follower_token: state.followerToken || ""
    }).then(function (res) {
      renderPosts(Array.isArray(res.posts) ? res.posts : []);
      return res;
    });
  }

  function setComposerMode() {
    var enabled = !!state.isOwner;

    if (!dom.composerText || !dom.composerPhotoUrl || !dom.composerPostBtn || !dom.composerHelp) return;

    dom.composerText.disabled = !enabled;
    dom.composerPhotoUrl.disabled = !enabled;
    dom.composerPostBtn.disabled = !enabled;

    if (enabled) {
      dom.composerHelp.textContent = "Owner posting enabled.";
      dom.composerAvatar.textContent = "OW";
      if (dom.followActionBtn) dom.followActionBtn.textContent = "Owner";
      return;
    }

    dom.composerHelp.textContent = "Viewer mode: use Follow to react and comment.";
    dom.composerAvatar.textContent = "VW";
  }

  function postAsOwner() {
    var text = dom.composerText ? String(dom.composerText.value || "").trim() : "";
    var photoUrl = dom.composerPhotoUrl ? String(dom.composerPhotoUrl.value || "").trim() : "";

    if (!state.isOwner) return;
    if (!text && !photoUrl) return;

    fetchJson("ownerCreatePost", {
      stream_id: state.streamId,
      body: text,
      media_url: photoUrl
    }).then(function () {
      if (dom.composerText) dom.composerText.value = "";
      if (dom.composerPhotoUrl) dom.composerPhotoUrl.value = "";
      return loadPosts();
    }).catch(function (err) {
      window.alert((err && err.message) ? err.message : "Unable to publish post.");
    });
  }

  function copyShareLink() {
    var url = window.location.origin + (window.FPW_BASE || "") + "/app/follow.cfm?slug=" + encodeURIComponent(state.slug || "") + "&t=" + encodeURIComponent(state.token || "");
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(url).then(function () {
        if (dom.copyLinkBtn) dom.copyLinkBtn.textContent = "Copied";
        window.setTimeout(function () {
          if (dom.copyLinkBtn) dom.copyLinkBtn.textContent = "Copy Link";
        }, 1500);
      }).catch(function () {
        window.prompt("Copy this link:", url);
      });
      return;
    }
    window.prompt("Copy this link:", url);
  }

  function bootstrapStream() {
    return fetchJson("getStreamBootstrap", {
      slug: state.slug,
      stream_id: state.streamId,
      t: state.token
    }).then(function (res) {
      state.bootstrap = res;
      state.stream = res.stream || {};
      state.streamId = toInt(state.stream.id || state.stream.stream_id || state.streamId, state.streamId);
      state.slug = state.stream.slug || state.slug;
      state.isOwner = !!state.stream.is_owner;
      state.followerStorageKey = "fpw.voyage.follower." + String(state.streamId || state.slug || "stream");
      state.followerToken = readCachedFollowerToken();

      renderHeaderAndCards(res);
      renderMap(res.map || {});
      renderCruiseTimelineInline(res.timeline || {});
      renderCruiseTimelineLegs(res.timeline && Array.isArray(res.timeline.legs) ? res.timeline.legs : []);
      setComposerMode();
      return loadPosts();
    });
  }

  function bindUi() {
    dom.shareTitle = document.getElementById("shareTitle");
    dom.shareStatusPill = document.getElementById("shareStatusPill");
    dom.sharePath = document.getElementById("sharePath");
    dom.shareLastCheckin = document.getElementById("shareLastCheckin");
    dom.shareViewerCount = document.getElementById("shareViewerCount");
    dom.copyLinkBtn = document.getElementById("copyLinkBtn");
    dom.privacyBtn = document.getElementById("privacyBtn");

    dom.tripTitle = document.getElementById("tripTitle");
    dom.cardStatusValue = document.getElementById("cardStatusValue");
    dom.cardStatusSub = document.getElementById("cardStatusSub");
    dom.cardLocationValue = document.getElementById("cardLocationValue");
    dom.cardLocationSub = document.getElementById("cardLocationSub");
    dom.cardEtaValue = document.getElementById("cardEtaValue");
    dom.cardEtaSub = document.getElementById("cardEtaSub");
    dom.cardConditionsValue = document.getElementById("cardConditionsValue");
    dom.cardConditionsSub = document.getElementById("cardConditionsSub");

    dom.overlayLeg = document.getElementById("overlayLeg");
    dom.overlayProgress = document.getElementById("overlayProgress");
    dom.overlayCheckin = document.getElementById("overlayCheckin");

    dom.progressHours = document.getElementById("progressHours");
    dom.progressSub = document.getElementById("progressSub");
    dom.progressFill = document.getElementById("progressFill");
    dom.progressMarker = document.getElementById("progressMarker");
    dom.photoCount = document.getElementById("photoCount");

    dom.summaryMiles = document.getElementById("summaryMiles");
    dom.summarySub = document.getElementById("summarySub");
    dom.summaryMeta = document.getElementById("summaryMeta");
    dom.followTimelineSection = document.getElementById("followTimelineSection");
    dom.followTimelineSummary = document.getElementById("followTimelineSummary");
    dom.followTimelineLegList = document.getElementById("followTimelineLegList");

    dom.pinnedUpdated = document.getElementById("pinnedUpdated");
    dom.pinnedMiles = document.getElementById("pinnedMiles");
    dom.pinnedDays = document.getElementById("pinnedDays");
    dom.pinnedLocks = document.getElementById("pinnedLocks");
    dom.pinnedWildlife = document.getElementById("pinnedWildlife");

    dom.followActionBtn = document.getElementById("followActionBtn");
    dom.composerAvatar = document.getElementById("composerAvatar");
    dom.composerText = document.getElementById("composerText");
    dom.composerPhotoUrl = document.getElementById("composerPhotoUrl");
    dom.composerPostBtn = document.getElementById("composerPostBtn");
    dom.composerHelp = document.getElementById("composerHelp");

    dom.postsContainer = document.getElementById("postsContainer");

    if (dom.copyLinkBtn) {
      dom.copyLinkBtn.addEventListener("click", copyShareLink);
    }

    if (dom.privacyBtn) {
      dom.privacyBtn.addEventListener("click", function () {
        window.alert("Privacy settings are managed from the owner dashboard.");
      });
    }

    if (dom.followActionBtn) {
      dom.followActionBtn.addEventListener("click", function () {
        if (state.isOwner) return;
        ensureFollowerToken(true).catch(function (err) {
          window.alert((err && err.message) ? err.message : "Unable to follow this stream.");
        });
      });
    }

    if (dom.composerPostBtn) {
      dom.composerPostBtn.addEventListener("click", postAsOwner);
    }

    document.querySelectorAll("[data-template]").forEach(function (btn) {
      btn.addEventListener("click", function () {
        if (!dom.composerText || dom.composerText.disabled) return;
        var text = String(btn.getAttribute("data-template") || "");
        dom.composerText.value = dom.composerText.value ? (dom.composerText.value + "\n" + text) : text;
        dom.composerText.focus();
      });
    });

    wirePostInteractions();
    wireCruiseTimelineInteractions();
  }

  function init() {
    var route = readSlugTokenFromUrl();
    state.slug = route.slug;
    state.token = route.token;
    state.streamId = route.streamId;

    bindUi();

    bootstrapStream().catch(function (err) {
      if (dom.postsContainer) {
        dom.postsContainer.innerHTML = '<div class="emptyState">' + escapeHtml((err && err.message) ? err.message : "Unable to load voyage stream.") + '</div>';
      }
    });
  }

  document.addEventListener("DOMContentLoaded", init);
})(window, document);
