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
    pageContext: {},
    timeline: {
      payload: null,
      legs: [],
      expandedLegOrder: 0
    },
    loader: {
      label: "Follow Page Loading",
      percent: 0,
      message: "Preparing the shared trip view."
    }
  };

  var dom = {};
  var loaderMilestones = {
    initial: {
      label: "Follow Page Loading",
      percent: 5,
      message: "Preparing the shared trip view."
    },
    bootstrap: {
      label: "Follow Page Loading",
      percent: 18,
      message: "Requesting shared trip data."
    },
    floatPlan: {
      label: "Float Plan Loading",
      percent: 38,
      message: "Hydrating trip status and summary."
    },
    weather: {
      label: "Weather Loading",
      percent: 58,
      message: "Applying current conditions from the bootstrap payload."
    },
    route: {
      label: "Route Loading",
      percent: 78,
      message: "Rendering the route map and cruise timeline."
    },
    finalize: {
      label: "Finalizing Display",
      percent: 92,
      message: "Loading voyage stream posts."
    },
    ready: {
      label: "Finalizing Display",
      percent: 100,
      message: "Shared trip view ready."
    }
  };

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

  function clampLoaderPercent(value) {
    var n = parseInt(value, 10);
    if (!Number.isFinite(n)) return 0;
    return Math.max(0, Math.min(100, n));
  }

  function setLoaderState(label, percent, message) {
    var nextPercent = Math.max(clampLoaderPercent(percent), clampLoaderPercent(state.loader.percent));
    var nextLabel = String(label || state.loader.label || "Follow Page Loading").trim() || "Follow Page Loading";
    var nextMessage = String(message || state.loader.message || "").trim();

    state.loader.label = nextLabel;
    state.loader.percent = nextPercent;
    state.loader.message = nextMessage;

    if (document.body) {
      document.body.classList.add("follow-loading");
    }
    if (dom.loaderPhase) dom.loaderPhase.textContent = nextLabel;
    if (dom.loaderPercent) dom.loaderPercent.textContent = String(nextPercent) + "%";
    if (dom.loaderBar) dom.loaderBar.style.width = String(nextPercent) + "%";
    if (dom.loaderMessage) dom.loaderMessage.textContent = nextMessage;
  }

  function setLoaderMilestone(milestoneKey) {
    var milestone = loaderMilestones[milestoneKey];
    if (!milestone) return;
    setLoaderState(milestone.label, milestone.percent, milestone.message);
  }

  function finishLoader() {
    setLoaderMilestone("ready");
    window.requestAnimationFrame(function () {
      if (!document.body) return;
      document.body.classList.remove("follow-load-error");
      document.body.classList.remove("follow-loading");
    });
  }

  function failLoader(message) {
    var errorMessage = String(message || "Unable to load voyage stream.").trim() || "Unable to load voyage stream.";
    setLoaderState(state.loader.label, state.loader.percent, errorMessage);
    if (document.body) {
      document.body.classList.add("follow-load-error");
      document.body.classList.add("follow-loading");
    }
  }

  function readPageContext() {
    var el = document.getElementById("followPageContext");
    var parsed;
    if (!el) return {};
    try {
      parsed = JSON.parse(el.textContent || "{}");
    } catch (err) {
      return {};
    }
    return parsed && typeof parsed === "object" ? parsed : {};
  }

  function collectHookMap() {
    dom.regions = {};
    dom.fields = {};

    document.querySelectorAll("[data-fpw-region]").forEach(function (el) {
      var key = String(el.getAttribute("data-fpw-region") || "").trim();
      if (!key || dom.regions[key]) return;
      dom.regions[key] = el;
    });

    document.querySelectorAll("[data-fpw-field]").forEach(function (el) {
      var key = String(el.getAttribute("data-fpw-field") || "").trim();
      if (!key || dom.fields[key]) return;
      dom.fields[key] = el;
    });
  }

  function getBasePath() {
    return window.FPW_BASE || state.pageContext.fpwBase || "";
  }

  function apiUrl(action) {
    var base = getBasePath();
    return base + "/api/v1/voyage.cfc?method=handle&action=" + encodeURIComponent(action) + "&returnFormat=json";
  }

  function apiDownloadUrl(action, params) {
    var base = getBasePath();
    var query = new URLSearchParams();
    var values = params && typeof params === "object" ? params : {};

    query.set("method", "handle");
    query.set("action", action);
    query.set("returnFormat", "json");

    Object.keys(values).forEach(function (key) {
      var value = values[key];
      if (value === undefined || value === null || value === "") return;
      query.set(key, String(value));
    });

    return base + "/api/v1/voyage.cfc?" + query.toString();
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
    var raw = String(input).trim();
    var date = new Date(raw);

    if (Number.isNaN(date.getTime())) {
      return raw;
    }
    return date.toLocaleString([], {
      month: "short",
      day: "numeric",
      hour: "numeric",
      minute: "2-digit"
    });
  }

  function formatSidebarLastCheckinLabel(input) {
    var raw = String(input || "").trim();
    var date = null;
    var monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    var hours;
    var displayHour;
    var minutes;
    var suffix;

    date = raw ? new Date(raw) : null;

    if (!date || Number.isNaN(date.getTime())) {
      return "";
    }

    hours = date.getHours();
    displayHour = hours % 12;
    if (displayHour === 0) displayHour = 12;
    minutes = String(date.getMinutes());
    if (minutes.length < 2) minutes = "0" + minutes;
    suffix = hours >= 12 ? "PM" : "AM";

    return monthNames[date.getMonth()] + " " + date.getDate() + ", " + date.getFullYear() + " " + displayHour + ":" + minutes + " " + suffix;
  }

  function formatJourneyCheckinValue(input) {
    var raw = String(input || "").trim();
    var prefix = "Checked in at ";
    var converted = "";

    if (raw.indexOf(prefix) !== 0) {
      return raw;
    }

    converted = formatSidebarLastCheckinLabel(raw.slice(prefix.length));
    return converted ? (prefix + converted) : raw;
  }

  function isAwaitingDepartureState(body, topCards, timeline) {
    var tripSummaryMode = String(body && body.trip_summary_mode ? body.trip_summary_mode : "").trim();
    var journeySubtitle = String(body && body.journey_subtitle ? body.journey_subtitle : "").trim();
    var etaUtc = String(topCards && topCards.eta_utc ? topCards.eta_utc : "").trim();
    var summary = (timeline && typeof timeline === "object" && timeline.summary && typeof timeline.summary === "object")
      ? timeline.summary
      : {};
    var legs = Array.isArray(timeline && timeline.legs) ? timeline.legs : [];
    var completedLegs = toInt(summary.completed_legs, 0);
    var hasPendingLeg = false;
    var i;
    var leg = null;
    var legOrder = 0;
    var legProgress = null;

    if (/awaiting departure/i.test(tripSummaryMode) || /awaiting departure/i.test(journeySubtitle)) {
      return true;
    }
    if (completedLegs <= 0 || etaUtc) {
      return false;
    }

    for (i = 0; i < legs.length; i += 1) {
      leg = legs[i] && typeof legs[i] === "object" ? legs[i] : null;
      if (!leg) continue;
      legOrder = toInt(leg.leg_order, 0);
      legProgress = safeNum(leg.progress && leg.progress.percent_complete);
      if (legOrder > completedLegs && (legProgress === null || legProgress < 100)) {
        hasPendingLeg = true;
        break;
      }
    }

    return hasPendingLeg;
  }

  function updateSidebarLastCheckinFromPosts(posts) {
    var sidebar = state.bootstrap && state.bootstrap.sidebar ? state.bootstrap.sidebar : {};
    var list = Array.isArray(posts) ? posts : [];
    var latestPost = list.length ? list[0] : null;
    var label = formatSidebarLastCheckinLabel(sidebar.last_checkin_utc || "");

    if (label) {
      setHookText("trip-card-last-checkin", label);
      return;
    }

    label = formatSidebarLastCheckinLabel(latestPost && latestPost.created_utc ? latestPost.created_utc : "");

    if (!label) return;
    setHookText("trip-card-last-checkin", label);
  }

  function findFirstPhotoCount(posts) {
    var list = Array.isArray(posts) ? posts : [];
    var count = 0;
    list.forEach(function (post) {
      if (post && post.media_url) count += 1;
    });
    return count;
  }

  function getHookField(name) {
    if (!dom.fields) return null;
    return dom.fields[name] || null;
  }

  function setHookText(name, value) {
    var el = getHookField(name);
    if (!el) return;
    if (value === undefined || value === null || value === "") return;
    el.textContent = String(value);
  }

  function setHookHidden(name, hidden) {
    var el = getHookField(name);
    if (!el) return;
    el.hidden = !!hidden;
  }

  function setHookHTML(name, html) {
    var el = getHookField(name);
    if (!el) return;
    if (html === undefined || html === null || html === "") return;
    el.innerHTML = String(html);
  }

  function setHookWidth(name, percent) {
    var el = getHookField(name);
    var value = safeNum(percent);
    if (!el || value === null) return;
    el.style.width = Math.max(0, Math.min(100, value)) + "%";
  }

  function getPublicAuthority(payload) {
    var authority = payload && payload.publicAuthority;
    return (authority && typeof authority === "object") ? authority : {};
  }

  function getAuthoritySection(payload, sectionName) {
    var authority = getPublicAuthority(payload);
    var section = authority[String(sectionName || "")];
    return (section && typeof section === "object") ? section : {};
  }

  function authorityText(value) {
    return String(value === undefined || value === null ? "" : value).trim();
  }

  function formatProgressLabel(value) {
    var n = safeNum(value);
    if (n === null) return "";
    return n.toFixed(1) + "%";
  }

  function authorityLocalLabel(localLabel, utcValue, fallback) {
    var label = authorityText(localLabel);
    if (label) return label;
    label = formatSidebarLastCheckinLabel(utcValue || "");
    return label || authorityText(fallback);
  }

  function isScheduledTrip(payload) {
    var body = payload && payload.body ? payload.body : {};
    var topCards = payload && payload.topCards ? payload.topCards : {};
    var tripState = getAuthoritySection(payload, "tripState");
    var code = authorityText(tripState.code).toLowerCase();
    var label = authorityText(tripState.label).toLowerCase();
    var fallbackText = [
      authorityText(topCards.status),
      authorityText(topCards.voyage_progress_status),
      authorityText(body.journey_subtitle),
      authorityText(body.trip_summary_mode),
      authorityText(body.family_confidence_subtitle)
    ].join(" ");

    return code === "scheduled"
      || label === "scheduled"
      || /scheduled departure pending|trip is scheduled/i.test(fallbackText);
  }

  function scheduledDepartureMeta(body) {
    var meta = String(body && body.journey_departed_meta ? body.journey_departed_meta : "").trim();
    if (!meta) return "Scheduled departure pending";
    return /^Scheduled departure:/i.test(meta) ? meta : ("Scheduled departure: " + meta);
  }

  function firstPlannedLegMeta(fromName, toName) {
    var from = authorityText(fromName);
    var to = authorityText(toName);
    if (from && to) return "First planned leg: " + from + " to " + to;
    if (to) return "First planned leg ends at " + to;
    if (from) return "First planned leg starts at " + from;
    return "First planned leg after scheduled departure";
  }

  function firstPlannedStopMeta(stopName) {
    var stop = authorityText(stopName);
    return stop ? ("First planned stop: " + stop + " after departure") : "First planned stop after departure";
  }

  function renderPhase5StreamShell(payload) {
    var pinned = payload.pinned || {};
    var topCards = payload.topCards || {};
    var body = payload.body || {};
    var sidebar = payload.sidebar || {};
    var timeline = payload.timeline || {};
    var map = payload.map || {};
    var authorityProgress = getAuthoritySection(payload, "progress");
    var authorityCurrentLeg = getAuthoritySection(payload, "currentLeg");
    var authorityTiming = getAuthoritySection(payload, "timing");
    var authorityMonitoring = getAuthoritySection(payload, "monitoring");
    var summary = timeline.summary || {};
    var legs = Array.isArray(timeline.legs) ? timeline.legs : [];
    var updatedLabel = authorityLocalLabel(authorityMonitoring.lastCheckinLocalLabel, authorityMonitoring.lastCheckinUtc || topCards.last_checkin_utc, "—");
    var nextStop = authorityText(authorityCurrentLeg.toName) || String(topCards.next_stop || map.next_stop_label || "").trim();
    var etaUtc = authorityText(authorityTiming.etaUtc) || String(topCards.eta_utc || "").trim();
    var realLastCheckinUtc = authorityText(authorityMonitoring.lastCheckinUtc) || String(sidebar.last_checkin_utc || "").trim();
    var fallbackLastCheckinUtc = String(topCards.last_checkin_utc || "").trim();
    var lastCheckinLabel = authorityLocalLabel(authorityMonitoring.lastCheckinLocalLabel, realLastCheckinUtc || fallbackLastCheckinUtc, "—");
    var lastCheckinMeta = realLastCheckinUtc ? (String(body.journey_checkin_meta || "").trim() || "—") : "—";
    var nextStopEtaLabel = "—";
    var locationLabel = authorityText(authorityCurrentLeg.fromName) || String(topCards.location_label || (map.current && map.current.label ? map.current.label : "") || "").trim();
    var checkinMeta = String(body.journey_checkin_meta || "").trim();
    var cardCheckinMeta = checkinMeta.replace(/\s*Next update expected tomorrow morning\.\s*/i, "").trim();
    var isAwaitingDeparture = isAwaitingDepartureState(body, topCards, timeline);
    var isScheduled = isScheduledTrip(payload);
    var activeLeg = findActiveTimelineLeg(
      legs,
      locationLabel,
      String(topCards.next_stop || "").trim(),
      summary,
      isAwaitingDeparture
    );
    var completedLegs = toInt(summary && summary.completed_legs, 0);
    var hasActiveLeg = !!activeLeg && completedLegs < legs.length;
    var effectiveSpeed = safeNum(summary.effective_speed_kn);
    var currentStopValue = locationLabel || "—";
    var currentStopMeta = "—";
    var isOvernightState = /overnight|secure for the night/i.test(checkinMeta);
    var activeLegDistanceNm = safeNum(activeLeg && activeLeg.dist_nm);
    var activeLegProgressPct = safeNum(authorityProgress.legProgressPercent);
    var pinnedMilesTodayNm = safeNum(authorityTiming.milesTodayNm);
    var pinnedHoursToday = safeNum(authorityTiming.hoursToday);
    var milesTodayLabel = "—";
    var hoursUnderwayLabel = "—";
    var hoursUnderwayTotal = 0;
    if (activeLegProgressPct === null) {
      activeLegProgressPct = safeNum(activeLeg && activeLeg.progress ? activeLeg.progress.percent_complete : null);
    }
    if (pinnedMilesTodayNm === null) {
      pinnedMilesTodayNm = safeNum(pinned.miles_today_nm);
    }
    if (pinnedHoursToday === null) {
      pinnedHoursToday = safeNum(pinned.hours_today);
    }
    if (pinnedMilesTodayNm !== null) {
      milesTodayLabel = pinnedMilesTodayNm.toFixed(1);
    } else if (activeLegDistanceNm !== null && activeLegProgressPct !== null) {
      milesTodayLabel = (activeLegDistanceNm * Math.max(0, activeLegProgressPct) / 100).toFixed(1);
    }
    if (pinnedHoursToday !== null) {
      hoursUnderwayLabel = pinnedHoursToday.toFixed(1);
    } else {
      legs.forEach(function (leg) {
        var legHours = safeNum(leg && leg.hours);
        var legProgressPct = safeNum(leg && leg.progress ? leg.progress.percent_complete : null);
        var clampedProgressPct = 0;
        if (legHours === null || legProgressPct === null || legProgressPct <= 0) return;
        clampedProgressPct = Math.max(0, Math.min(100, legProgressPct));
        hoursUnderwayTotal += legHours * clampedProgressPct / 100;
      });
      hoursUnderwayLabel = hoursUnderwayTotal.toFixed(1);
    }
    nextStopEtaLabel = authorityLocalLabel(authorityTiming.etaLocalLabel, etaUtc, "—");
    if (isScheduled) {
      updatedLabel = "Scheduled";
      milesTodayLabel = "—";
      hoursUnderwayLabel = "—";
      currentStopValue = "Trip scheduled";
      currentStopMeta = firstPlannedLegMeta(locationLabel, nextStop);
      nextStopEtaLabel = firstPlannedStopMeta(nextStop);
    }

    setHookText("stream-glance-updated", updatedLabel);
    setHookText("stream-glance-miles", milesTodayLabel);
    setHookText("stream-glance-hours", hoursUnderwayLabel);
    if (isScheduled) {
      currentStopValue = "Trip scheduled";
      currentStopMeta = firstPlannedLegMeta(locationLabel, nextStop);
    } else if (isOvernightState && locationLabel && cardCheckinMeta) {
      currentStopValue = locationLabel;
      currentStopMeta = cardCheckinMeta;
    } else if (isAwaitingDeparture) {
      currentStopValue = locationLabel || "—";
      currentStopMeta = "Awaiting departure for the next leg.";
    } else if (hasActiveLeg && nextStop && effectiveSpeed !== null && effectiveSpeed > 0) {
      currentStopValue = "Underway to " + nextStop;
      currentStopMeta = "Making way at " + String(effectiveSpeed) + " kn";
    } else if (locationLabel || cardCheckinMeta) {
      currentStopValue = locationLabel || "—";
      currentStopMeta = cardCheckinMeta || "—";
    }
    if (!isScheduled && !isAwaitingDeparture && activeLegProgressPct !== null) {
      currentStopMeta = "Current leg " + formatProgressLabel(activeLegProgressPct) + " complete";
    }
    setHookText("stream-glance-checkin", currentStopValue);
    setHookText("stream-glance-checkin-meta", currentStopMeta);
    setHookText("stream-glance-next-stop", nextStop);
    setHookText("stream-glance-next-stop-meta", isScheduled ? nextStopEtaLabel : (isAwaitingDeparture ? "Awaiting departure" : (nextStopEtaLabel === "—" ? "—" : ("ETA " + nextStopEtaLabel))));
  }

  function formatDayCountLabel(days) {
    var dayCount = toInt(days, 0);
    return String(dayCount) + " " + (dayCount === 1 ? "day" : "days");
  }

  function findRecentMediaPosts(posts) {
    return (Array.isArray(posts) ? posts : []).filter(function (post) {
      return !!String((post && (post.media_thumb_url || post.media_url)) || "").trim();
    }).slice(0, 3);
  }

  function renderLatestPhotoRow(posts) {
    var rowEl = getHookField("latest-photos-row");
    var mediaPosts = findRecentMediaPosts(posts);

    if (!rowEl) return;

    rowEl.innerHTML = "";
    mediaPosts.forEach(function (post) {
      var src = String((post.media_thumb_url || post.media_url) || "").trim();
      var photoEl;
      if (!src) return;
      photoEl = document.createElement("div");
      photoEl.className = "photo";
      photoEl.setAttribute("aria-label", "Shared voyage photo");
      photoEl.style.backgroundImage = 'url("' + src.replace(/"/g, '\\"') + '")';
      photoEl.style.backgroundSize = "cover";
      photoEl.style.backgroundPosition = "center";
      photoEl.style.backgroundRepeat = "no-repeat";
      rowEl.appendChild(photoEl);
    });
  }

  function renderPhase6LowerCards(payload, posts) {
    var body = payload.body || {};
    var topCards = payload.topCards || {};
    var pinned = payload.pinned || {};
    var map = payload.map || {};
    var timeline = payload.timeline || {};
    var authorityProgress = getAuthoritySection(payload, "progress");
    var authorityCurrentLeg = getAuthoritySection(payload, "currentLeg");
    var authorityTiming = getAuthoritySection(payload, "timing");
    var authorityTripState = getAuthoritySection(payload, "tripState");
    var authorityMonitoring = getAuthoritySection(payload, "monitoring");
    var summary = timeline.summary || {};
    var legs = Array.isArray(timeline.legs) ? timeline.legs : [];
    var miles = safeNum(pinned.miles);
    var pinnedMilesTodayNm = safeNum(authorityTiming.milesTodayNm);
    var totalHoursText = timelineValueText(summary.total_hours, 1, "h");
    var completedMilesNm = 0;
    var photoCount = findRecentMediaPosts(posts).length;
    var currentLocation = authorityText(authorityCurrentLeg.fromName) || String(map.current && map.current.label ? map.current.label : topCards.location_label || "").trim();
    var currentLegLabel = authorityText(authorityCurrentLeg.label);
    var nextStop = authorityText(authorityCurrentLeg.toName) || String(topCards.next_stop || "").trim();
    var etaUtc = authorityText(authorityTiming.etaUtc) || String(topCards.eta_utc || "").trim();
    var etaLabel = "—";
    var isAwaitingDeparture = isAwaitingDepartureState(body, topCards, timeline);
    var isScheduled = isScheduledTrip(payload);
    var progressPct = safeNum(authorityProgress.routeProgressPercent);
    var publicHealthLabel = authorityText(authorityMonitoring.publicHealthLabel);
    var tripStateLabel = authorityText(authorityTripState.label);
    if (pinnedMilesTodayNm === null) {
      pinnedMilesTodayNm = safeNum(pinned.miles_today_nm);
    }
    if (isScheduled && progressPct === null) {
      progressPct = 0;
    } else if (progressPct === null) {
      progressPct = computeJourneyProgressPct(summary, legs, currentLocation, nextStop, isAwaitingDeparture);
    }

    legs.forEach(function (leg) {
      var legProgress = safeNum(leg && leg.progress ? leg.progress.percent_complete : null);
      var legDistanceNm = safeNum(leg && leg.dist_nm);
      if (legProgress === null || legDistanceNm === null) return;
      if (legProgress >= 100) {
        completedMilesNm += legDistanceNm;
      }
    });
    etaLabel = authorityLocalLabel(authorityTiming.etaLocalLabel, etaUtc, "—");

    setHookText("today-progress-metric", isScheduled ? "—" : ((pinnedMilesTodayNm === null ? completedMilesNm : pinnedMilesTodayNm).toFixed(1) + " nm"));
    setHookText("today-progress-location", isScheduled ? "Trip scheduled" : (currentLegLabel ? ("Current leg: " + currentLegLabel) : ("Current location: " + currentLocation)));
    setHookText("today-progress-eta", isScheduled ? firstPlannedLegMeta(currentLocation, nextStop) : (isAwaitingDeparture ? "Awaiting departure" : (etaLabel === "—" ? "—" : ("Estimated arrival: " + etaLabel))));
    setHookWidth("today-progress-fill", progressPct);
    setHookText("latest-photos-count", String(photoCount) + " recent " + (photoCount === 1 ? "moment" : "moments") + " shared");
    setHookText("trip-summary-metric", totalHoursText === "n/a" ? "n/a" : (totalHoursText + " total"));
    setHookText("trip-summary-distance", miles === null ? "0" : miles.toFixed(1) + " mi");
    setHookText("trip-summary-confidence", body.trip_summary_confidence);
    setHookText("trip-summary-mode", tripStateLabel ? ("Trip state: " + tripStateLabel) : (isAwaitingDeparture ? "Trip mode: Awaiting departure" : body.trip_summary_mode));
    setHookText("trip-summary-safety", isScheduled ? body.trip_summary_safety : (publicHealthLabel ? ("Health: " + publicHealthLabel) : body.trip_summary_safety));
    renderLatestPhotoRow(posts);
  }

  function setHookCardBody(name, strongText, smallText) {
    var card = getHookField(name);
    var strongEl;
    var smallEl;
    if (!card) return;
    strongEl = card.querySelector("strong");
    smallEl = card.querySelector("small");
    if (strongEl && strongText !== undefined && strongText !== null && strongText !== "") {
      strongEl.textContent = String(strongText);
    }
    if (smallEl && smallText !== undefined && smallText !== null && smallText !== "") {
      smallEl.textContent = String(smallText);
    }
  }

  function renderPhase7TimelineSummary(payload) {
    var body = payload.body || {};
    var timeline = payload.timeline || {};
    var summary = timeline.summary || {};
    var totalHoursText = timelineValueText(summary.total_hours, 1, "h");
    var totalNm = formatTimelineNumber(summary.total_nm, 1);
    var speedKn = formatTimelineNumber(summary.effective_speed_kn, 1);
    var fuelEst = formatTimelineNumber(summary.fuel_est, 1);
    var reserveEst = formatTimelineNumber(summary.reserve_est, 1);

    setHookCardBody(
      "timeline-route-total",
      totalHoursText === "n/a" ? "n/a" : (totalHoursText + " planned"),
      totalNm + " nm on route"
    );
    setHookCardBody("timeline-eff-speed", speedKn + " kn");
    setHookCardBody("timeline-fuel-reserve", fuelEst + " + " + reserveEst + " gal");
    setHookText("timeline-next-update", body.timeline_next_update);
  }

  function findActiveTimelineLeg(legs, currentLabel, nextStopLabel, summary, awaitingDeparture) {
    var list = Array.isArray(legs) ? legs : [];
    var currentName = String(currentLabel || "").trim().toLowerCase();
    var nextName = String(nextStopLabel || "").trim().toLowerCase();
    var completedLegs = toInt(summary && summary.completed_legs, 0);
    var i;
    var leg = null;
    var legStartName = "";
    var legEndName = "";

    if (!list.length) return null;
    if (awaitingDeparture) return null;

    if (nextName && nextName !== "n/a") {
      for (i = 0; i < list.length; i += 1) {
        leg = list[i] && typeof list[i] === "object" ? list[i] : null;
        if (!leg) continue;
        legStartName = String(leg.start_name || "").trim().toLowerCase();
        legEndName = String(leg.end_name || "").trim().toLowerCase();
        if (currentName && legStartName === currentName && legEndName === nextName) {
          return leg;
        }
      }

      for (i = 0; i < list.length; i += 1) {
        leg = list[i] && typeof list[i] === "object" ? list[i] : null;
        if (!leg) continue;
        legEndName = String(leg.end_name || "").trim().toLowerCase();
        if (legEndName === nextName) {
          return leg;
        }
      }
    }

    if (completedLegs >= list.length) {
      return list[list.length - 1];
    }

    return list[0];
  }

  function computeJourneyProgressPct(summary, legs, currentLabel, nextStopLabel, awaitingDeparture) {
    var list = Array.isArray(legs) ? legs : [];
    var totalLegs = list.length;
    var completedLegs = toInt(summary && summary.completed_legs, 0);
    var activeLeg = findActiveTimelineLeg(list, currentLabel, nextStopLabel, summary, awaitingDeparture);
    var activeProgress = safeNum(activeLeg && activeLeg.progress ? activeLeg.progress.percent_complete : 0);

    if (!totalLegs) return null;
    if (completedLegs >= totalLegs) return 100;
    if (activeProgress === null) activeProgress = 0;

    return ((completedLegs + (activeProgress / 100)) / totalLegs) * 100;
  }

  function renderPhase3Shell(payload) {
    var body = payload.body || {};
    var stream = payload.stream || {};
    var sidebar = payload.sidebar || {};
    var topCards = payload.topCards || {};
    var map = payload.map || {};
    var timeline = payload.timeline || {};
    var authorityProgress = getAuthoritySection(payload, "progress");
    var authorityCurrentLeg = getAuthoritySection(payload, "currentLeg");
    var authorityTiming = getAuthoritySection(payload, "timing");
    var authorityMonitoring = getAuthoritySection(payload, "monitoring");
    var authorityTripState = getAuthoritySection(payload, "tripState");
    var summary = timeline.summary || {};
    var legs = Array.isArray(timeline.legs) ? timeline.legs : [];
    var title = String(stream.title || "").trim();
    var publicHealthLabel = authorityText(authorityMonitoring.publicHealthLabel);
    var publicHealthVariant = authorityText(authorityMonitoring.publicHealthVariant).toLowerCase();
    var tripStateLabel = authorityText(authorityTripState.label);
    var tripStateHelper = authorityText(authorityTripState.helperText);
    var status = publicHealthLabel || String(topCards.status || stream.status || "").trim();
    var voyageProgressStatus = publicHealthLabel || String(topCards.voyage_progress_status || status || "").trim();
    var voyageProgressStatusVariant = publicHealthVariant || String(topCards.voyage_progress_status_variant || "good").trim().toLowerCase();
    var lastCheckinUtc = authorityText(authorityMonitoring.lastCheckinUtc) || String(topCards.last_checkin_utc || "").trim();
    var realCheckInUtc = authorityText(authorityMonitoring.lastCheckinUtc) || String(sidebar.last_checkin_utc || "").trim();
    var lastCheckinLabel = authorityLocalLabel(authorityMonitoring.lastCheckinLocalLabel, lastCheckinUtc, "");
    var realCheckInLabel = authorityLocalLabel(authorityMonitoring.lastCheckinLocalLabel, realCheckInUtc, "");
    var sidebarLastCheckin = realCheckInLabel || lastCheckinLabel || "—";
    var shareSlug = String(stream.slug || state.slug || "").trim();
    var nextStop = authorityText(authorityCurrentLeg.toName) || String(topCards.next_stop || map.next_stop_label || "").trim();
    var conditions = String(topCards.conditions || "").trim();
    var legWeather = payload.legWeather || {};
    var weatherConditions = legWeather.conditions || {};
    var startWeather = legWeather.start || {};
    var endWeather = legWeather.end || {};
    var currentLocation = authorityText(authorityCurrentLeg.fromName) || String(map.current && map.current.label ? map.current.label : "").trim();
    var completedLegs = toInt(summary.completed_legs, 0);
    var isAwaitingDeparture = isAwaitingDepartureState(body, topCards, timeline);
    var isScheduled = isScheduledTrip(payload);
    var activeLeg = findActiveTimelineLeg(legs, currentLocation, nextStop, summary, isAwaitingDeparture);
    var activeLegLabel = authorityText(authorityCurrentLeg.label) || String(activeLeg && activeLeg.label ? activeLeg.label : "").trim();
    var activeLegStartName = String(activeLeg && activeLeg.start_name ? activeLeg.start_name : currentLocation).trim();
    var activeLegEndName = String(activeLeg && activeLeg.end_name ? activeLeg.end_name : nextStop).trim();
    var effectiveSpeedKn = safeNum(summary.effective_speed_kn);
    var progressPct = safeNum(authorityProgress.routeProgressPercent);
    var legProgressPct = safeNum(authorityProgress.legProgressPercent);
    var departedLocalMeta = String(body.journey_departed_meta || "").trim() || formatSidebarLastCheckinLabel(body.journey_departed_meta_utc || "") || "—";
    var nextStopLocalEta = authorityLocalLabel(authorityTiming.etaLocalLabel, authorityTiming.etaUtc || topCards.eta_utc, "—");
    var finalArrivalLabel = authorityLocalLabel(authorityTiming.finalArrivalLocalLabel, authorityTiming.finalArrivalUtc, "");
    var routeProgressLabel = "";
    var legProgressLabel = "";
    var journeySubtitleText = "";
    var currentLegMetaText = "";
    if (isScheduled && progressPct === null) {
      progressPct = 0;
    } else if (progressPct === null) {
      progressPct = computeJourneyProgressPct(summary, legs, currentLocation, nextStop, isAwaitingDeparture);
    }
    routeProgressLabel = formatProgressLabel(progressPct);
    legProgressLabel = formatProgressLabel(legProgressPct);
    var startSummary = String(startWeather.summary || "").trim();
    var endSummary = String(endWeather.summary || "").trim();
    var startSummaryLine = startSummary ? (activeLegStartName ? "Start · " + activeLegStartName + " · " + startSummary : startSummary) : "";
    var endSummaryLine = endSummary ? (activeLegEndName ? "End · " + activeLegEndName + " · " + endSummary : endSummary) : "";
    var conditionsFallbackCopy = String(weatherConditions.meta || body.card_conditions_copy || "").trim();
    var conditionsTitle = String(weatherConditions.headline || conditions).trim();
    var voyageProgressStatusCopy = String(body.voyage_progress_status_copy || body.card_status_copy || "").trim();
    var conditionsValue = "";
    var conditionsCopy = "";

    if (endSummaryLine) {
      conditionsValue = endSummaryLine;
      conditionsCopy = startSummaryLine || conditionsFallbackCopy;
    } else if (startSummaryLine) {
      conditionsValue = conditionsFallbackCopy || String(topCards.conditions || "").trim();
      conditionsCopy = startSummaryLine;
    } else {
      conditionsValue = String(topCards.conditions || "").trim();
      conditionsCopy = String(body.card_conditions_copy || "").trim();
    }
    if (isScheduled) {
      status = "Scheduled";
      voyageProgressStatus = "Scheduled";
      voyageProgressStatusVariant = "good";
      lastCheckinLabel = "";
      realCheckInLabel = "";
      sidebarLastCheckin = "—";
      nextStopLocalEta = firstPlannedStopMeta(nextStop);
      finalArrivalLabel = "";
      legProgressLabel = "";
      conditionsTitle = "Monitoring pending";
      conditionsValue = "";
      conditionsCopy = "Monitoring starts at scheduled departure.";
    }

    setHookText("trip-card-title", title);
    setHookText("trip-card-status-pill", status);
    if (shareSlug) {
      setHookText("trip-card-share-link", "/follow/" + shareSlug);
    }
    setHookText("trip-card-last-checkin", sidebarLastCheckin);
    setHookText("trip-card-viewer-count", sidebar.viewer_count);
    setHookText("trip-card-vessel", sidebar.vessel_name);
    setHookText("trip-card-privacy", sidebar.privacy_label);
    setHookText("trip-card-monitoring", sidebar.monitoring_summary);
    setHookHTML("trip-card-monitor-state-text", sidebar.monitor_state_text_html);
    setHookText("trip-card-monitor-state-pill", sidebar.monitor_state_label);

    setHookText("page-title", title);
    setHookText("page-subtitle", body.page_subtitle);
    if (!isScheduled && lastCheckinLabel) {
      setHookText("live-chip", "Live now · Updated " + lastCheckinLabel);
    }

    journeySubtitleText = isAwaitingDeparture ? "Awaiting departure from the current stop." : body.journey_subtitle;
    if (tripStateLabel || routeProgressLabel) {
      journeySubtitleText = (tripStateLabel ? ("Trip state: " + tripStateLabel) : "") + (routeProgressLabel ? ((tripStateLabel ? " · " : "") + "Route progress " + routeProgressLabel) : "");
    }
    setHookText("journey-subtitle", journeySubtitleText);
    setHookText("journey-status-pill", voyageProgressStatus);
    if (dom.journeyStatusPill) {
      dom.journeyStatusPill.classList.toggle("warning", voyageProgressStatusVariant === "warning");
      dom.journeyStatusPill.classList.toggle("danger", voyageProgressStatusVariant === "danger");
      dom.journeyStatusPill.classList.toggle("good", voyageProgressStatusVariant !== "danger" && voyageProgressStatusVariant !== "warning");
    }
    setHookWidth("journey-progress-fill", progressPct);
    setHookText("journey-departed-value", isScheduled ? "Trip scheduled" : body.journey_departed_value);
    setHookText("journey-departed-meta", isScheduled ? scheduledDepartureMeta(body) : departedLocalMeta);
    setHookText("journey-current-leg-value", isScheduled ? "Trip scheduled" : (isAwaitingDeparture ? "Awaiting Departure" : activeLegLabel));
    if (isScheduled) {
      setHookText("journey-current-leg-meta", firstPlannedLegMeta(currentLocation, nextStop));
    } else if (isAwaitingDeparture) {
      setHookText("journey-current-leg-meta", "Next leg has not started yet.");
    } else if (legProgressLabel) {
      currentLegMetaText = "Current leg " + legProgressLabel + " complete";
      if (nextStopLocalEta !== "—") {
        currentLegMetaText += " · ETA " + nextStopLocalEta;
      }
      setHookText("journey-current-leg-meta", currentLegMetaText);
    } else if (activeLeg && completedLegs < legs.length && effectiveSpeedKn !== null && effectiveSpeedKn > 0) {
      setHookText("journey-current-leg-meta", "Making way at " + String(effectiveSpeedKn) + " kn");
    }
    setHookText("journey-next-stop-value", isScheduled ? "Trip scheduled" : nextStop);
    setHookText("journey-next-stop-meta", isScheduled ? firstPlannedStopMeta(nextStop) : nextStopLocalEta);
    setHookText("journey-checkin-value", isScheduled ? "No check-ins yet" : (realCheckInLabel ? ("Checked in at " + realCheckInLabel) : "Checked in at --"));
    setHookText("journey-checkin-meta", isScheduled ? "First check-in expected at scheduled departure." : (authorityText(authorityMonitoring.nextExpectedCheckinLocalLabel) ? ("Next expected: " + authorityText(authorityMonitoring.nextExpectedCheckinLocalLabel)) : body.journey_checkin_meta));

    setHookText("card-status-title", voyageProgressStatus);
    setHookText("card-status-value", isScheduled ? "—" : (lastCheckinLabel || "—"));
    setHookText("card-status-copy", isScheduled ? "Trip state: Scheduled. The trip is scheduled and has not started yet." : (tripStateLabel ? ("Trip state: " + tripStateLabel + (tripStateHelper ? (". " + tripStateHelper) : "")) : voyageProgressStatusCopy));
    if (dom.statusDot) {
      dom.statusDot.classList.toggle("warning", voyageProgressStatusVariant === "warning");
      dom.statusDot.classList.toggle("danger", voyageProgressStatusVariant === "danger");
    }
    setHookText("card-location-title", isScheduled ? "Trip scheduled" : (currentLocation || String(topCards.location_label || "").trim()));
    setHookText("card-location-value", isScheduled ? (currentLocation || "Scheduled departure") : nextStop);
    setHookText("card-location-copy", isScheduled ? firstPlannedLegMeta(currentLocation, nextStop) : (isAwaitingDeparture ? "The trip is paused at the current stop and awaiting the next departure." : body.card_location_copy));
    setHookText("card-destination-title", isScheduled ? "Trip scheduled" : nextStop);
    setHookText("card-destination-value", isScheduled ? (nextStop || topCards.next_stop) : topCards.next_stop);
    setHookText("card-destination-copy", isScheduled ? firstPlannedStopMeta(nextStop) : (finalArrivalLabel ? ("Final route arrival: " + finalArrivalLabel) : body.card_destination_copy));
    setHookText("card-arrival-title", isScheduled ? "Trip scheduled" : nextStopLocalEta);
    setHookText("card-arrival-value", isScheduled ? "No live ETA yet" : nextStop);
    setHookText("card-arrival-copy", isScheduled ? "Arrival estimates appear after the trip is underway." : (isAwaitingDeparture ? "Departure has not started for the next leg yet." : body.card_arrival_copy));
    setHookText("card-conditions-title", conditionsTitle);
    setHookHidden("card-conditions-value", isScheduled);
    if (!isScheduled) {
      setHookText("card-conditions-value", conditionsValue);
    }
    setHookText("card-conditions-copy", conditionsCopy);
    setHookText("family-confidence-subtitle", body.family_confidence_subtitle);
  }

  function renderHeaderAndCards(payload) {
    var stream = payload.stream || {};
    var topCards = payload.topCards || {};
    var pinned = payload.pinned || {};
    var authorityProgress = getAuthoritySection(payload, "progress");
    var authorityCurrentLeg = getAuthoritySection(payload, "currentLeg");
    var authorityTiming = getAuthoritySection(payload, "timing");
    var authorityMonitoring = getAuthoritySection(payload, "monitoring");
    var title = stream.title || "Voyage Stream";
    var isScheduled = isScheduledTrip(payload);
    var status = isScheduled ? "Scheduled" : (authorityText(authorityMonitoring.publicHealthLabel) || topCards.status || stream.status || "n/a");
    var lastCheckin = isScheduled ? "—" : authorityLocalLabel(authorityMonitoring.lastCheckinLocalLabel, authorityMonitoring.lastCheckinUtc || topCards.last_checkin_utc, "n/a");
    var location = authorityText(authorityCurrentLeg.fromName) || topCards.location_label || "n/a";
    var nextStop = authorityText(authorityCurrentLeg.toName) || topCards.next_stop || "n/a";
    var eta = isScheduled ? "—" : authorityLocalLabel(authorityTiming.etaLocalLabel, authorityTiming.etaUtc || topCards.eta_utc, "—");
    var conditions = topCards.conditions || "n/a";
    var miles = safeNum(pinned.miles);
    var days = toInt(pinned.days, 0);
    var locks = toInt(pinned.locks, 0);
    var wildlife = toInt(pinned.wildlife, 0);
    var progressPct = safeNum(authorityProgress.routeProgressPercent);
    var progressLabel = "";

    renderPhase3Shell(payload);
    renderPhase5StreamShell(payload);
    renderPhase6LowerCards(payload, state.posts);
    renderPhase7TimelineSummary(payload);
    renderTrackLog(payload);
    renderFloatPlanDownload(payload);

    if (dom.shareTitle) dom.shareTitle.textContent = title;
    if (dom.tripTitle) dom.tripTitle.textContent = title;
    if (dom.shareStatusPill) dom.shareStatusPill.textContent = status;
    if (dom.shareLastCheckin) dom.shareLastCheckin.textContent = lastCheckin;
    if (dom.sharePath) dom.sharePath.textContent = "/follow/" + (stream.slug || state.slug || "");
    if (dom.shareViewerCount) dom.shareViewerCount.textContent = "0";

    if (dom.cardStatusValue) dom.cardStatusValue.textContent = status;
    if (dom.cardStatusSub) dom.cardStatusSub.textContent = isScheduled ? "Monitoring starts at scheduled departure." : ("Last check-in: " + lastCheckin);
    if (dom.cardLocationValue) dom.cardLocationValue.textContent = location;
    if (dom.cardLocationSub) dom.cardLocationSub.textContent = isScheduled ? firstPlannedLegMeta(location, nextStop) : ("Heading: " + nextStop);
    if (dom.cardEtaValue) dom.cardEtaValue.textContent = isScheduled ? "Trip scheduled" : eta;
    if (dom.cardEtaSub) dom.cardEtaSub.textContent = isScheduled ? firstPlannedStopMeta(nextStop) : ("Next stop: " + nextStop);
    if (dom.cardConditionsValue) {
      dom.cardConditionsValue.hidden = isScheduled;
      dom.cardConditionsValue.textContent = isScheduled ? "" : conditions;
    }
    if (dom.cardConditionsSub) dom.cardConditionsSub.textContent = isScheduled ? "Monitoring starts at scheduled departure." : "Based on latest stream updates";

    if (dom.overlayLeg) dom.overlayLeg.textContent = isScheduled ? firstPlannedLegMeta(location, nextStop) : (authorityText(authorityCurrentLeg.label) || (location + " to " + nextStop));
    if (dom.overlayProgress) dom.overlayProgress.textContent = isScheduled ? "Scheduled" : (miles === null ? "n/a" : miles.toFixed(1) + " mi");
    if (dom.overlayCheckin) dom.overlayCheckin.textContent = lastCheckin;

    if (dom.pinnedUpdated) dom.pinnedUpdated.textContent = isScheduled ? "Scheduled" : ("Updated " + lastCheckin);
    if (dom.pinnedMiles) dom.pinnedMiles.textContent = (miles === null ? "0" : miles.toFixed(1));
    if (dom.pinnedDays) dom.pinnedDays.textContent = String(days);
    if (dom.pinnedLocks) dom.pinnedLocks.textContent = String(locks);
    if (dom.pinnedWildlife) dom.pinnedWildlife.textContent = String(wildlife);

    if (dom.summaryMiles) dom.summaryMiles.textContent = (miles === null ? "0" : miles.toFixed(1)) + " mi";
    if (dom.summarySub) dom.summarySub.textContent = String(days) + " days | " + String(locks) + " locks | " + String(wildlife) + " wildlife";
    if (dom.summaryMeta) dom.summaryMeta.textContent = "Confidence: route-based";

    if (progressPct === null) {
      progressPct = Math.min(100, Math.max(0, days > 0 ? Math.round((days / Math.max(days, 1)) * 100) : 0));
    }
    progressLabel = formatProgressLabel(progressPct);
    if (dom.progressFill) dom.progressFill.style.width = progressPct + "%";
    if (dom.progressMarker) dom.progressMarker.style.left = progressPct + "%";
    if (dom.progressHours) dom.progressHours.textContent = isScheduled ? "Scheduled" : (progressLabel || (miles === null ? "n/a" : miles.toFixed(1) + " mi"));
    if (dom.progressSub) dom.progressSub.textContent = isScheduled ? firstPlannedLegMeta(location, nextStop) : ("Current leg: " + (authorityText(authorityCurrentLeg.label) || (location + " to " + nextStop)));
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

  function formatTrackLogCount(count) {
    var n = toInt(count, 0);
    return n + " " + (n === 1 ? "check-in" : "check-ins");
  }

  function buildFloatPlanPdfDownloadUrl(payload) {
    var stream = payload && payload.stream && typeof payload.stream === "object" ? payload.stream : {};
    var slug = String(stream.slug || state.slug || "").trim();
    var streamId = toInt(stream.id || stream.stream_id || state.streamId, 0);
    var params = {};

    if (slug) {
      params.slug = slug;
    } else if (streamId > 0) {
      params.stream_id = streamId;
    } else {
      return "";
    }

    if (state.token) {
      params.t = state.token;
    }

    return apiDownloadUrl("downloadFloatPlanPdf", params);
  }

  function renderFloatPlanDownload(payload) {
    var link = getHookField("float-plan-download-action");
    var meta = getHookField("float-plan-meta");
    var href = buildFloatPlanPdfDownloadUrl(payload);

    if (!link) return;

    link.removeAttribute("href");
    link.removeAttribute("download");
    link.classList.add("is-disabled");
    link.setAttribute("aria-disabled", "true");
    link.textContent = "Float plan PDF unavailable";
    if (meta) {
      meta.textContent = "PDF unavailable";
    }

    if (!href) return;

    link.href = href;
    link.classList.remove("is-disabled");
    link.removeAttribute("aria-disabled");
    link.textContent = "Download PDF";
    if (meta) {
      meta.textContent = "PDF";
    }
  }

  function parsePdfErrorMessage(text) {
    var fallback = "Unable to download float plan PDF.";
    var parsed;

    try {
      parsed = text ? JSON.parse(text) : {};
    } catch (ignoreErr) {
      return fallback;
    }

    if (parsed && parsed.MESSAGE) {
      return String(parsed.MESSAGE);
    }

    return fallback;
  }

  function getPdfDownloadFileName(disposition) {
    var value = String(disposition || "");
    var match = value.match(/filename\*?=(?:UTF-8'')?("?)([^";]+)\1/i);
    var fileName = match && match[2] ? decodeURIComponent(match[2]) : "";

    return fileName || "float-plan.pdf";
  }

  function triggerBlobDownload(blob, fileName) {
    var objectUrl;
    var link;

    if (!window.URL || typeof window.URL.createObjectURL !== "function") {
      window.alert("Unable to download float plan PDF.");
      return;
    }

    objectUrl = window.URL.createObjectURL(blob);
    link = document.createElement("a");
    link.href = objectUrl;
    link.download = fileName || "float-plan.pdf";
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);

    window.setTimeout(function () {
      window.URL.revokeObjectURL(objectUrl);
    }, 1000);
  }

  function handleFloatPlanPdfDownload(event) {
    var link = event.currentTarget;
    var href = link ? String(link.href || "") : "";
    var originalText = link ? (link.textContent || "Download PDF") : "Download PDF";

    if (!link || link.classList.contains("is-disabled") || link.getAttribute("aria-disabled") === "true") {
      return;
    }

    event.preventDefault();

    if (!href) {
      window.alert("Unable to download float plan PDF.");
      return;
    }

    link.setAttribute("aria-busy", "true");
    link.textContent = "Preparing PDF...";

    fetch(href, {
      method: "GET",
      credentials: "same-origin",
      headers: {
        Accept: "application/pdf, application/json;q=0.9, */*;q=0.8"
      }
    })
      .then(function (res) {
        var contentType = String(res.headers.get("Content-Type") || "").toLowerCase();
        var disposition = res.headers.get("Content-Disposition") || "";

        if (!res.ok || contentType.indexOf("application/pdf") === -1) {
          return res.text().then(function (text) {
            throw new Error(parsePdfErrorMessage(text));
          });
        }

        return res.blob().then(function (blob) {
          triggerBlobDownload(blob, getPdfDownloadFileName(disposition));
        });
      })
      .catch(function (err) {
        window.alert((err && err.message) ? err.message : "Unable to download float plan PDF.");
      })
      .then(function () {
        link.removeAttribute("aria-busy");
        link.textContent = originalText;
      });
  }

  function appendTrackLogText(parent, className, value) {
    var el = document.createElement("span");
    el.className = className;
    el.textContent = String(value || "");
    parent.appendChild(el);
    return el;
  }

  function focusTrackLogEntry(row, lat, lng, label) {
    var api = window.FPWFollowMap;
    var list = getHookField("track-log-list");
    var focused = false;

    if (!api || typeof api.focusPoint !== "function") return;

    focused = api.focusPoint(lat, lng, label);
    if (!focused || !list) return;

    list.querySelectorAll(".follow-track-log-row.is-selected").forEach(function (el) {
      el.classList.remove("is-selected");
    });
    row.classList.add("is-selected");
  }

  function renderTrackLog(payload) {
    var trackLog = (payload && payload.trackLog && typeof payload.trackLog === "object") ? payload.trackLog : {};
    var entries = Array.isArray(trackLog.entries) ? trackLog.entries : [];
    var list = getHookField("track-log-list");
    var countEl = getHookField("track-log-count");
    var count = toInt(trackLog.count, entries.length);

    if (countEl) {
      countEl.textContent = formatTrackLogCount(count || entries.length);
    }
    if (!list) return;

    while (list.firstChild) {
      list.removeChild(list.firstChild);
    }

    if (!entries.length) {
      var empty = document.createElement("div");
      empty.className = "follow-track-log-empty";
      empty.textContent = "No check-ins shared yet.";
      list.appendChild(empty);
      return;
    }

    entries.forEach(function (entry, index) {
      var rowData = (entry && typeof entry === "object") ? entry : {};
      var statusLabel = String(rowData.statusLabel || rowData.status || "Check-in").trim();
      var occurredLabel = String(rowData.occurredAtLocalLabel || rowData.occurredAtUtc || "").trim();
      var sourceLabel = String(rowData.sourceLabel || "").trim();
      var lat = safeNum(rowData.latitude);
      var lng = safeNum(rowData.longitude);
      var hasGps = !!rowData.hasGps && lat !== null && lng !== null;
      var coordLabel = String(rowData.coordinateLabel || "").trim() || (hasGps ? (formatCoord(lat) + ", " + formatCoord(lng)) : "No GPS attached");
      var row = document.createElement(hasGps ? "button" : "div");
      var mapLabel = statusLabel + (occurredLabel ? (" check-in from " + occurredLabel) : " check-in");

      row.className = "follow-track-log-row " + (hasGps ? "has-gps" : "no-gps");
      row.setAttribute("data-track-log-index", String(index));

      if (hasGps) {
        row.type = "button";
        row.setAttribute("aria-label", "Show " + mapLabel + " on map");
        row.addEventListener("click", function () {
          focusTrackLogEntry(row, lat, lng, mapLabel);
        });
      }

      appendTrackLogText(row, "follow-track-log-status", statusLabel);
      appendTrackLogText(row, "follow-track-log-time", occurredLabel || "Time unavailable");
      appendTrackLogText(row, "follow-track-log-coords", hasGps ? coordLabel : "No GPS attached");
      if (sourceLabel) {
        appendTrackLogText(row, "follow-track-log-source", sourceLabel);
      }

      list.appendChild(row);
    });
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
    state.timeline.payload = payload;
  }

  function renderCruiseTimelineLegPane(row, timelinePayload) {
    var leg = (row && typeof row === "object") ? row : {};
    var payload = (timelinePayload && typeof timelinePayload === "object") ? timelinePayload : {};
    var summary = (payload.summary && typeof payload.summary === "object") ? payload.summary : {};
    var meta = (payload.meta && typeof payload.meta === "object") ? payload.meta : {};
    var order = toInt(leg.leg_order, 0);
    var legText = String(leg.label || (String(leg.start_name || "Start") + " -> " + String(leg.end_name || "End"))).trim();
    var progress = (leg.progress && typeof leg.progress === "object") ? leg.progress : {};
    var progressPct = timelineValueText(progress.percent_complete, 0, "%");
    var lastUpdateRaw = String(progress.last_update_ts || "").trim();
    var lastUpdateText = lastUpdateRaw ? formatTimeLabel(lastUpdateRaw) : "n/a";
    var cumulativeHours = timelineValueText(leg.cumulative_hours, 1, "h");
    var legHours = timelineValueText(leg.hours, 1, "h");
    var maxHoursPerDay = timelineValueText(summary.max_hours_per_day, 1, "h");
    var inputsSource = String(meta.inputs_source || "default").trim() || "default";
    var missingInputs = Array.isArray(meta.missing_inputs) ? meta.missing_inputs : [];
    var legFuelBurnGph = timelineValueText(summary.fuel_burn_gph, 1, "gph");
    var legFuelEst = timelineValueText((safeNum(summary.fuel_burn_gph) !== null && safeNum(leg.hours) !== null)
      ? (safeNum(summary.fuel_burn_gph) * safeNum(leg.hours))
      : null, 1, "gal");
    var lockDetailsHtml = renderLegLockDetailsHtml(leg);

    return ''
      + '<div class="follow-timeline-legpanel is-open" data-leg-order="' + String(order) + '">'
      + '  <div class="follow-timeline-legpanelhead">'
      + '    <div>'
      + '      <div class="follow-timeline-kicker">Cruise Timeline Day</div>'
      + '      <div class="follow-timeline-legpaneltitle">Cumulative ' + escapeHtml(cumulativeHours) + ' | Leg ' + escapeHtml(String(order).padStart(2, "0")) + '</div>'
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
      + '  <div class="follow-timeline-legpanelmeta">Cumulative: ' + escapeHtml(cumulativeHours) + ' | Leg: ' + escapeHtml(legHours) + ' | Max/day: ' + escapeHtml(maxHoursPerDay) + '</div>'
      + '  <div class="follow-timeline-legpanelmeta">Fuel est: ' + escapeHtml(legFuelEst) + ' @ ' + escapeHtml(legFuelBurnGph) + '</div>'
      + '  <div class="follow-timeline-legpanelmeta">Last update: ' + escapeHtml(lastUpdateText) + '</div>'
      + '  <div class="follow-timeline-legpanelnote">Inputs source: ' + escapeHtml(inputsSource)
      + (missingInputs.length ? (' | Missing: ' + escapeHtml(missingInputs.join(", "))) : '')
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
      + '<span>#</span><span>Leg</span><span>Locks</span><span>NM</span><span>Hours</span><span>Cum h</span>'
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
      var cumulativeHours = timelineValueText(row.cumulative_hours, 1, "h");
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
        + '    <div class="follow-timeline-legday">' + cumulativeHours + '</div>'
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

  function streamAuthorLabel(post) {
    var authorType = String(post && post.author_type ? post.author_type : "").toLowerCase();
    if (authorType === "system") return "FPW";
    if (authorType === "owner") return "Captain";
    return "Follower";
  }

  function streamAvatarLabel(post) {
    var authorType = String(post && post.author_type ? post.author_type : "").toLowerCase();
    if (authorType === "system") return "FP";
    if (authorType === "owner") return "OW";
    return "VW";
  }

  function renderStreamFeedMeta(post) {
    var created = formatTimeLabel(post && post.created_utc);
    var locationLabel = String(post && post.location_label ? post.location_label : "").trim();
    if (locationLabel) {
      return created + " · " + locationLabel;
    }
    return created;
  }

  function renderStreamComments(comments) {
    var list = Array.isArray(comments) ? comments : [];

    return list.map(function (comment) {
      var displayName = String(comment && comment.display_name ? comment.display_name : "Viewer").trim() || "Viewer";
      var created = formatTimeLabel(comment && comment.created_utc);
      var body = String(comment && comment.body ? comment.body : "").trim();
      var meta = displayName + (created && created !== "n/a" ? (" · " + created) : "");

      return ''
        + '<div class="feed-comment">'
        + '  <div class="feed-meta">' + escapeHtml(meta) + '</div>'
        + '  <p>' + escapeHtml(body).replace(/\n/g, "<br />") + '</p>'
        + '</div>';
    }).join("");
  }

  function renderStreamMedia(post) {
    var mediaSrc = String((post && (post.media_thumb_url || post.media_url)) || "").trim();
    var mediaLink = String((post && post.media_url) || mediaSrc).trim();

    if (!mediaSrc) return "";

    return ''
      + '<div class="feed-media">'
      + '  <a href="' + escapeHtml(mediaLink) + '" target="_blank" rel="noopener noreferrer">'
      + '    <img src="' + escapeHtml(mediaSrc) + '" alt="Voyage photo" loading="lazy" />'
      + '  </a>'
      + '</div>';
  }

  function renderStreamReactions(postId, reactions, viewerReactions) {
    var counts = reactions || {};
    var active = viewerReactions || {};
    var reactionNames = ["like", "love", "boat", "wave"];

    return reactionNames.map(function (name) {
      return ''
        + '<button type="button" class="reaction reactBtn ' + (active[name] ? "active" : "") + '" data-react="' + name + '" data-post-id="' + String(postId) + '">'
        + escapeHtml(reactionLabel(name))
        + ' <span class="count">' + String(toInt(counts[name], 0)) + '</span>'
        + '</button>';
    }).join("");
  }

  function renderPost(post) {
    var id = toInt(post.id, 0);
    var title = String(post.title || "").trim();
    var body = String(post.body || "").trim();
    var reactions = post.reaction_counts || {};
    var viewerReactions = post.viewer_reactions || {};
    var comments = Array.isArray(post.comments) ? post.comments : [];
    var authorLabel = streamAuthorLabel(post);
    var avatarLabel = streamAvatarLabel(post);
    var metaText = renderStreamFeedMeta(post);
    var mediaHtml = renderStreamMedia(post);
    var commentsHtml;
    var deleteButtonHtml = "";
    var bodyHtml = "";

    if (!title) {
      title = body ? body.slice(0, 90) : "Update";
    }

    commentsHtml = renderStreamComments(comments);
    if (
      state.isOwner
      && String(post.author_type || "").toLowerCase() === "owner"
      && String(post.post_type || "").toLowerCase() !== "system_event"
      && !String(post.event_type || "").trim()
    ) {
      deleteButtonHtml = '<button type="button" class="reaction" data-owner-delete-post="' + String(id) + '">Delete</button>';
    }
    if (body) {
      bodyHtml = '  <p>' + escapeHtml(body).replace(/\n/g, "<br />") + '</p>';
    }

    return ''
      + '<article class="feed-card" data-post-id="' + String(id) + '">'
      + '  <div class="feed-head">'
      + '    <div class="feed-left">'
      + '      <div class="avatar">' + escapeHtml(avatarLabel) + '</div>'
      + '      <div>'
      + '        <div class="feed-title">' + escapeHtml(title) + '</div>'
      + '        <div class="feed-meta">' + escapeHtml(metaText) + '</div>'
      + '      </div>'
      + '    </div>'
      + '    <div class="feed-flag">' + escapeHtml(authorLabel) + '</div>'
      + '  </div>'
      + mediaHtml
      + bodyHtml
      + '  <div class="reactions">' + renderStreamReactions(id, reactions, viewerReactions) + deleteButtonHtml + '</div>'
      + '  <div id="comments-' + String(id) + '">' + (commentsHtml || "") + '</div>'
      + '  <div class="commentBox">'
      + '    <input class="commentInput" type="text" data-comment-input="' + String(id) + '" maxlength="500" placeholder="Add a comment..." />'
      + '    <button type="button" class="reaction" data-comment-submit="' + String(id) + '">Comment</button>'
      + '  </div>'
      + '</article>';
  }

  function renderPosts(posts) {
    var list = Array.isArray(posts) ? posts : [];
    var html = "";

    state.posts = list;
    updateSidebarLastCheckinFromPosts(list);
    renderPhase6LowerCards(state.bootstrap || {}, list);
    if (!dom.postsContainer) return;

    if (!list.length) {
      dom.postsContainer.innerHTML = '<div class="feed-card"><p>No posts yet. Add the first voyage update.</p></div>';
      if (dom.photoCount) dom.photoCount.textContent = "0 new";
      return;
    }

    html = list.map(renderPost).join("");
    dom.postsContainer.innerHTML = html;
    if (dom.photoCount) {
      dom.photoCount.textContent = String(findFirstPhotoCount(list)) + " new";
    }
  }

  function normalizeCreatedPostPayload(payload) {
    var source = payload || {};
    var post = source.post || source.POST || {};
    var postId = toInt(post.id || source.post_id || source.POST_ID, 0);

    if (postId <= 0) return null;

    return {
      id: postId,
      stream_id: toInt(post.stream_id, state.streamId),
      author_type: String(post.author_type || "owner"),
      author_user_id: toInt(post.author_user_id, 0),
      follower_id: toInt(post.follower_id, 0),
      title: String(post.title || ""),
      body: String(post.body || ""),
      post_type: String(post.post_type || (String(post.media_url || "").trim() ? "photo" : "text")),
      event_type: String(post.event_type || ""),
      location_label: String(post.location_label || ""),
      lat: post.lat || "",
      lng: post.lng || "",
      media_url: String(post.media_url || ""),
      media_thumb_url: String(post.media_thumb_url || ""),
      created_utc: String(post.created_utc || ""),
      reaction_counts: post.reaction_counts || { like: 0, love: 0, boat: 0, wave: 0 },
      viewer_reactions: post.viewer_reactions || {},
      comments: Array.isArray(post.comments) ? post.comments : []
    };
  }

  function mergePostIntoList(newPost, posts) {
    var list = Array.isArray(posts) ? posts.slice() : [];
    var postId = toInt(newPost && newPost.id, 0);

    if (postId <= 0) return list;

    list = list.filter(function (post) {
      return toInt(post && post.id, 0) !== postId;
    });
    list.unshift(newPost);
    return list;
  }

  function prependPostToUi(newPost) {
    var list = mergePostIntoList(newPost, state.posts);
    var hasRenderedPosts = false;
    var existing = null;

    state.posts = list;
    updateSidebarLastCheckinFromPosts(list);
    renderPhase6LowerCards(state.bootstrap || {}, list);
    if (dom.photoCount) {
      dom.photoCount.textContent = String(findFirstPhotoCount(list)) + " new";
    }
    if (!dom.postsContainer) return;

    existing = dom.postsContainer.querySelector('[data-post-id="' + String(newPost.id) + '"]');
    if (existing && existing.parentNode) {
      existing.parentNode.removeChild(existing);
    }

    hasRenderedPosts = !!dom.postsContainer.querySelector("[data-post-id]");
    if (!hasRenderedPosts) {
      dom.postsContainer.innerHTML = renderPost(newPost);
      return;
    }

    dom.postsContainer.insertAdjacentHTML("afterbegin", renderPost(newPost));
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
    var metaText = String(displayName || "You").trim() || "You";
    if (!container) return null;

    div = document.createElement("div");
    div.className = "feed-comment" + (pending ? " pending" : "");
    div.innerHTML = ''
      + '<div class="feed-meta">' + escapeHtml(metaText) + '</div>'
      + '<p>' + escapeHtml(text || "") + '</p>';
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
      state.followerToken = String(res.follower_token || res.FOLLOWER_TOKEN || "");
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

    (state.isOwner ? Promise.resolve("") : ensureFollowerToken(false))
      .then(function (token) {
        var payload = {
          post_id: postId,
          emoji: emoji
        };
        if (!state.isOwner) {
          payload.follower_token = token;
        }
        return fetchJson("toggleReaction", {
          post_id: payload.post_id,
          emoji: payload.emoji,
          follower_token: payload.follower_token
        });
      })
      .then(function (res) {
        var reactionCounts = res.reaction_counts || res.REACTION_COUNTS || {};
        var isActive = !!(res.active || res.ACTIVE);
        applyReactionCounts(postId, reactionCounts, isActive ? emoji : "");
        if (!isActive) {
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

    (state.isOwner ? Promise.resolve("") : ensureFollowerToken(false))
      .then(function (token) {
        var payload = {
          post_id: postId,
          body: text
        };
        if (!state.isOwner) {
          payload.follower_token = token;
        }
        return fetchJson("addComment", {
          post_id: payload.post_id,
          body: payload.body,
          follower_token: payload.follower_token
        });
      })
      .then(function (res) {
        var comment = (res && (res.comment || res.COMMENT)) ? (res.comment || res.COMMENT) : null;
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

  function onOwnerDeletePost(postId) {
    var article = dom.postsContainer ? dom.postsContainer.querySelector('[data-post-id="' + String(postId) + '"]') : null;

    if (!state.isOwner || postId <= 0) return;
    if (!window.confirm("Delete this post?")) return;
    if (article) article.style.opacity = "0.55";

    fetchJson("ownerDeletePost", {
      post_id: postId
    }).then(function () {
      return loadPosts();
    }).catch(function (err) {
      if (article) article.style.opacity = "";
      window.alert((err && err.message) ? err.message : "Unable to delete post.");
    });
  }

  function wirePostInteractions() {
    if (!dom.postsContainer) return;

    dom.postsContainer.addEventListener("click", function (event) {
      var reactBtn = event.target.closest("[data-react]");
      var commentBtn = event.target.closest("[data-comment-submit]");
      var deleteBtn = event.target.closest("[data-owner-delete-post]");
      if (deleteBtn) {
        event.preventDefault();
        onOwnerDeletePost(toInt(deleteBtn.getAttribute("data-owner-delete-post"), 0));
        return;
      }
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

  function loadPosts(preservePost) {
    return fetchJson("listPosts", {
      stream_id: state.streamId,
      cursor: 0,
      limit: 30,
      t: state.token,
      follower_token: state.followerToken || ""
    }).then(function (res) {
      var posts = Array.isArray(res.posts) ? res.posts : [];
      if (preservePost) {
        posts = mergePostIntoList(preservePost, posts);
        res.posts = posts;
      }
      renderPosts(posts);
      return res;
    });
  }

  function setComposerMode() {
    var enabled = !!state.isOwner;

    if (!dom.composerText || !dom.composerPhotoUrl || !dom.composerPostBtn) return;

    dom.composerText.disabled = !enabled;
    dom.composerPhotoUrl.disabled = !enabled;
    dom.composerPostBtn.disabled = !enabled;

    if (enabled) {
      if (dom.composerHelp) dom.composerHelp.textContent = "Owner posting enabled.";
      if (dom.composerAvatar) dom.composerAvatar.textContent = "OW";
      if (dom.followActionBtn) dom.followActionBtn.textContent = "Owner";
      return;
    }

    if (dom.composerHelp) dom.composerHelp.textContent = "Viewer mode: use Follow to react and comment.";
    if (dom.composerAvatar) dom.composerAvatar.textContent = "VW";
  }

  function postAsOwner() {
    var text = dom.composerText ? String(dom.composerText.value || "").trim() : "";
    var mediaFile = (dom.composerPhotoUrl && dom.composerPhotoUrl.files && dom.composerPhotoUrl.files[0]) ? dom.composerPhotoUrl.files[0] : null;
    var mime = String(mediaFile && mediaFile.type ? mediaFile.type : "").toLowerCase();
    var fileName = String(mediaFile && mediaFile.name ? mediaFile.name : "");
    var createPromise;

    if (!state.isOwner) return;
    if (!text && !mediaFile) return;
    if (mediaFile && mediaFile.size > (5 * 1024 * 1024)) {
      window.alert("Image must be 5MB or smaller.");
      return;
    }
    if (mediaFile && ((mime && !/^image\/(jpeg|pjpeg|png|webp|x-webp)$/i.test(mime)) || !/\.(jpe?g|png|webp)$/i.test(fileName))) {
      window.alert("Only JPG, PNG, and WebP images are allowed.");
      return;
    }

    if (mediaFile) {
      var formData = new FormData();
      var uploadUrl = getBasePath() + "/api/v1/voyageUpload.cfm";
      formData.append("stream_id", String(state.streamId));
      formData.append("body", text);
      formData.append("media_file", mediaFile);
      createPromise = fetch(uploadUrl, {
        method: "POST",
        credentials: "same-origin",
        body: formData
      }).then(function (res) {
        return res.text().then(function (txt) {
          return { ok: res.ok, status: res.status, text: txt };
        });
      }).then(function (txt) {
        var json;
        if (!txt.ok) {
          try {
            json = txt.text ? JSON.parse(txt.text) : {};
          } catch (err) {
            json = {};
          }
          throw new Error((json.ERROR && json.ERROR.MESSAGE) || json.MESSAGE || "Unable to publish post.");
        }
        if (!String(txt.text || "").trim()) {
          return {};
        }
        try {
          json = txt.text ? JSON.parse(txt.text) : {};
        } catch (err) {
          json = {};
        }
        if (json && (json.SUCCESS === false || json.success === false)) {
          throw new Error((json.ERROR && json.ERROR.MESSAGE) || json.MESSAGE || "Unable to publish post.");
        }
        return json;
      });
    } else {
      createPromise = fetchJson("ownerCreatePost", {
        stream_id: state.streamId,
        body: text,
        media_url: ""
      });
    }

    createPromise.then(function (createRes) {
      var createdPost = mediaFile ? normalizeCreatedPostPayload(createRes) : null;

      if (mediaFile && createdPost) {
        prependPostToUi(createdPost);
        if (dom.composerText) dom.composerText.value = "";
        if (dom.composerPhotoUrl) dom.composerPhotoUrl.value = "";
        loadPosts(createdPost).catch(function () {});
        return null;
      }

      return loadPosts().then(function (res) {
        if (dom.composerText) dom.composerText.value = "";
        if (dom.composerPhotoUrl) dom.composerPhotoUrl.value = "";
        return res;
      });
    }).catch(function (err) {
      window.alert((err && err.message) ? err.message : "Unable to publish post.");
    });
  }

  function applyComposerTemplate(text) {
    var value = String(text || "").trim();
    if (!value) return;
    if (!dom.composerText || dom.composerText.disabled) return;
    dom.composerText.value = dom.composerText.value
      ? (dom.composerText.value + "\n" + value)
      : value;
    dom.composerText.focus();
  }

  function copyShareLink() {
    var url = window.location.origin + getBasePath() + "/app/follow.cfm?slug=" + encodeURIComponent(state.slug || "") + "&t=" + encodeURIComponent(state.token || "");
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

  function buildFollowContextUrl(pagePath) {
    var params = new URLSearchParams();
    var relativePath = String(pagePath || "").trim() || "/app/follow.cfm";

    if (state.slug) {
      params.set("slug", state.slug);
    }
    if (state.token) {
      params.set("t", state.token);
    }
    if (state.streamId > 0) {
      params.set("stream_id", String(state.streamId));
    }

    return window.location.origin + getBasePath() + relativePath + (params.toString() ? ("?" + params.toString()) : "");
  }

  function openFullMapWindow() {
    var targetUrl = buildFollowContextUrl("/app/follow-full-map.cfm");
    var featureParts = [
      "popup=yes",
      "left=0",
      "top=0",
      "width=" + String(window.screen && window.screen.availWidth ? window.screen.availWidth : 1440),
      "height=" + String(window.screen && window.screen.availHeight ? window.screen.availHeight : 900)
    ];
    var popup = null;

    try {
      popup = window.open("", "_blank", featureParts.join(","));
    } catch (err) {
      popup = null;
    }

    if (popup && !popup.closed) {
      try {
        popup.opener = null;
      } catch (ignoreErr) {}
      popup.location = targetUrl;
      return targetUrl;
    }

    featureParts.unshift("noopener");
    window.open(targetUrl, "_blank", featureParts.join(","));
    return targetUrl;
  }

  function bootstrapStream() {
    setLoaderMilestone("bootstrap");
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

      setLoaderMilestone("floatPlan");
      renderHeaderAndCards(res);
      setLoaderMilestone("weather");
      renderMap(res.map || {});
      setLoaderMilestone("route");
      renderCruiseTimelineInline(res.timeline || {});
      renderCruiseTimelineLegs(res.timeline && Array.isArray(res.timeline.legs) ? res.timeline.legs : []);
      setComposerMode();
      setLoaderMilestone("finalize");
      return loadPosts().then(function (postsRes) {
        finishLoader();
        return postsRes;
      });
    });
  }

  function bindUi() {
    collectHookMap();

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
    dom.followTimelineSummary = getHookField("timeline-route-total");
    dom.followTimelineLegList = getHookField("timeline-events");

    dom.pinnedUpdated = document.getElementById("pinnedUpdated");
    dom.pinnedMiles = document.getElementById("pinnedMiles");
    dom.pinnedDays = document.getElementById("pinnedDays");
    dom.pinnedLocks = document.getElementById("pinnedLocks");
    dom.pinnedWildlife = document.getElementById("pinnedWildlife");

    dom.followActionBtn = document.getElementById("followActionBtn");
    dom.composerAvatar = document.getElementById("composerAvatar");
    dom.composerText = document.getElementById("composerText") || getHookField("stream-composer-text");
    dom.composerPhotoUrl = document.getElementById("composerPhotoUrl") || getHookField("stream-composer-photo-url");
    dom.composerPostBtn = document.getElementById("composerPostBtn") || getHookField("stream-composer-post");
    dom.composerHelp = document.getElementById("composerHelp");
    dom.postsContainer = document.getElementById("postsContainer") || getHookField("stream-feed");
    dom.loader = document.getElementById("followLoader");
    dom.loaderPhase = document.getElementById("followLoaderPhase");
    dom.loaderPercent = document.getElementById("followLoaderPercent");
    dom.loaderBar = document.getElementById("followLoaderBar");
    dom.loaderMessage = document.getElementById("followLoaderMessage");
    dom.journeyStatusPill = getHookField("journey-status-pill");
    dom.statusDot = document.querySelector(".status-dot");
    dom.openFullMapBtn = document.getElementById("openFullMapBtn");

    if (dom.copyLinkBtn) {
      dom.copyLinkBtn.addEventListener("click", copyShareLink);
    }

    if (dom.privacyBtn) {
      dom.privacyBtn.addEventListener("click", function () {
        window.alert("Privacy settings are managed from the owner dashboard.");
      });
    }

    if (dom.openFullMapBtn) {
      dom.openFullMapBtn.addEventListener("click", function () {
        openFullMapWindow();
      });
    }

    dom.floatPlanDownloadAction = getHookField("float-plan-download-action");
    if (dom.floatPlanDownloadAction) {
      dom.floatPlanDownloadAction.addEventListener("click", handleFloatPlanPdfDownload);
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
        applyComposerTemplate(String(btn.getAttribute("data-template") || ""));
      });
    });

    if (dom.regions && dom.regions["voyage-stream"]) {
      dom.regions["voyage-stream"].querySelectorAll(".quick-tag").forEach(function (tagEl) {
        tagEl.addEventListener("click", function () {
          applyComposerTemplate(tagEl.textContent || "");
        });
      });
    }

    wirePostInteractions();
    wireCruiseTimelineInteractions();
  }

  function init() {
    var route = readSlugTokenFromUrl();
    state.pageContext = readPageContext();
    state.slug = route.slug;
    state.token = route.token;
    state.streamId = route.streamId;

    bindUi();
    setLoaderMilestone("initial");

    bootstrapStream().catch(function (err) {
      var errorMessage = (err && err.message) ? err.message : "Unable to load voyage stream.";
      if (dom.postsContainer) {
        dom.postsContainer.innerHTML = '<div class="emptyState">' + escapeHtml(errorMessage) + '</div>';
      }
      failLoader(errorMessage);
    });
  }

  document.addEventListener("DOMContentLoaded", init);
})(window, document);
