// Updated to launch the float plan wizard in a modal and refresh after save.
(function (window, document) {
  "use strict";
  // Boater-first weather view: prioritize summary, alerts, and readable forecast cards.

  window.FPW = window.FPW || {};
  var utils = window.FPW.DashboardUtils || {};
  var state = window.FPW.DashboardState || {};
  var modules = window.FPW.DashboardModules || {};

  var BASE_PATH = window.FPW_BASE || "";
  var FALLBACK_LOGIN_URL = BASE_PATH + "/index.cfm";
  var WEATHER_BASE_URL = "http://localhost:8500///fpw/api/v1/weather.cfc?method=handle&action=zip&zip=";
  var tideResizeObserver = null;
  var tideLastMarine = null;
  var tideLastWrapWidth = 0;
  var weatherRequestSeq = 0;

  function getLoginUrl() {
    if (window.AppAuth && window.AppAuth.loginUrl) {
      return window.AppAuth.loginUrl;
    }
    return FALLBACK_LOGIN_URL;
  }

  function redirectToLogin() {
    if (window.AppAuth && typeof window.AppAuth.redirectToLogin === "function") {
      window.AppAuth.redirectToLogin();
      return;
    }
    window.location.href = getLoginUrl();
  }

  function populateUserInfo(user) {
    var nameEl = document.getElementById("userName");
    var emailEl = document.getElementById("userEmail");

    if (nameEl) {
      nameEl.textContent = (user && user.NAME) ? user.NAME : "";
    }

    if (emailEl) {
      emailEl.textContent = (user && user.EMAIL) ? user.EMAIL : "";
    }
  }

  function toggleHidden(el, isHidden) {
    if (!el) return;
    if (isHidden) {
      el.classList.add("d-none");
    } else {
      el.classList.remove("d-none");
    }
  }

  function setWeatherError(message) {
    var errorEl = document.getElementById("weatherError");
    if (!errorEl) return;
    errorEl.textContent = message || "We couldn't load weather right now. Please try again.";
    toggleHidden(errorEl, false);
  }

  function clearWeatherError() {
    var errorEl = document.getElementById("weatherError");
    if (!errorEl) return;
    errorEl.textContent = "";
    toggleHidden(errorEl, true);
  }

  function mapAlertSeverity(severity) {
    var normalized = (severity || "").toString().toLowerCase();
    if (normalized === "extreme" || normalized === "severe") {
      return "critical";
    }
    if (normalized === "moderate") {
      return "warning";
    }
    return "info";
  }

  function clamp(n, min, max) {
    n = parseFloat(n);
    if (isNaN(n)) return min;
    return Math.max(min, Math.min(max, n));
  }

  function compassToDegrees(dir) {
    if (!dir) return 0;
    var d = dir.toString().trim().toUpperCase();

    // Normalize common NWS values
    if (d === "CALM") return 0;
    if (d === "VAR" || d === "VARIABLE") return 0;

    var map = {
      N: 0, NNE: 22.5, NE: 45, ENE: 67.5,
      E: 90, ESE: 112.5, SE: 135, SSE: 157.5,
      S: 180, SSW: 202.5, SW: 225, WSW: 247.5,
      W: 270, WNW: 292.5, NW: 315, NNW: 337.5
    };
    if (map[d] !== undefined) return map[d];

    // Sometimes comes as "NW" etc already handled; fallback: try first 3 letters
    var t = d.replace(/[^A-Z]/g, "");
    if (map[t] !== undefined) return map[t];
    if (t.length > 3 && map[t.substring(0, 3)] !== undefined) return map[t.substring(0, 3)];
    if (t.length > 2 && map[t.substring(0, 2)] !== undefined) return map[t.substring(0, 2)];
    return 0;
  }

  function parseWindSpeed(windSpeedRaw) {
    // NWS examples: "7 mph", "5 to 10 mph", "10 to 15 mph", "15 mph"
    var txt = (windSpeedRaw || "").toString().toLowerCase();
    var nums = txt.match(/(\d+(\.\d+)?)/g) || [];
    var a = nums.length ? parseFloat(nums[0]) : 0;
    var b = (nums.length >= 2) ? parseFloat(nums[1]) : a;

    // Treat the upper end as an estimated gust
    var speed = a || 0;
    var gust = Math.max(a || 0, b || 0);

    return { speed: speed, gust: gust };
  }

  function parseApiGustMph(period) {
    if (!period) return null;
    var raw = null;
    if (period.gustMph !== undefined && period.gustMph !== null && period.gustMph !== "") {
      raw = period.gustMph;
    } else if (period.GUSTMPH !== undefined && period.GUSTMPH !== null && period.GUSTMPH !== "") {
      raw = period.GUSTMPH;
    }
    if (raw === null) return null;
    var n = parseFloat(raw);
    return Number.isFinite(n) ? n : null;
  }

  function resolveGustMph(period, parsedWind) {
    var apiGust = parseApiGustMph(period);
    if (apiGust !== null && apiGust >= 0) {
      return apiGust;
    }
    return (parsedWind && parsedWind.gust) ? parsedWind.gust : ((parsedWind && parsedWind.speed) ? parsedWind.speed : 0);
  }

  function formatTimeOfDay(iso) {
    if (!iso) return "";
    try {
      var d = new Date(iso);
      if (isNaN(d.getTime())) return "";
      var hrs = d.getHours();
      var mins = d.getMinutes();
      var ap = hrs >= 12 ? "PM" : "AM";
      var h12 = hrs % 12; if (h12 === 0) h12 = 12;
      return mins ? (h12 + ":" + String(mins).padStart(2, "0") + " " + ap) : (h12 + " " + ap);
    } catch (e) { return ""; }
  }

  function formatHourOnly(iso) {
    if (!iso) return "";
    try {
      var d = new Date(iso);
      if (isNaN(d.getTime())) return "";
      var h = d.getHours() % 12;
      return String(h === 0 ? 12 : h);
    } catch (e) { return ""; }
  }


  function abbreviateWhen(label) {
    if (!label) return "";
    var s = label.toString();

    // Common NWS names: "Tonight", "This Afternoon", "Wednesday", "Wednesday Night"
    s = s.replace(/^This\s+/i, "");
    s = s.replace(/\s+Night$/i, " N");
    s = s.replace(/\s+Afternoon$/i, " PM");
    s = s.replace(/\s+Morning$/i, " AM");
    s = s.replace(/\s+Evening$/i, " Eve");
    return s;
  }

  function inferRainPct(period) {
    // Prefer NWS probabilityOfPrecipitation.value if present
    try {
      if (period && period.probabilityOfPrecipitation && period.probabilityOfPrecipitation.value !== undefined && period.probabilityOfPrecipitation.value !== null) {
        var v = parseFloat(period.probabilityOfPrecipitation.value);
        if (!isNaN(v)) return clamp(v, 0, 100);
      }
    } catch (e) {}

    // Otherwise infer from text
    var txt = (period && (period.shortForecast || period.detailedForecast)) ? (period.shortForecast || period.detailedForecast) : "";
    txt = (txt || "").toString().toLowerCase();
    if (!txt) return 0;
    if (txt.indexOf("thunder") >= 0) return 70;
    if (txt.indexOf("rain") >= 0 || txt.indexOf("shower") >= 0) return 55;
    if (txt.indexOf("drizzle") >= 0) return 35;
    if (txt.indexOf("snow") >= 0 || txt.indexOf("sleet") >= 0) return 40;
    if (txt.indexOf("cloud") >= 0) return 10;
    return 0;
  }

  function buildMeterRow(type, pct, labelText) {
    var row = document.createElement("div");
    row.className = "fpw-wx__meterRow";

    var fill = document.createElement("div");
    fill.className = "fpw-wx__meterFill " + type;
    fill.style.width = clamp(pct, 0, 100) + "%";

    row.appendChild(fill);

    if (labelText !== undefined && labelText !== null && labelText !== "") {
      var val = document.createElement("div");
      val.className = "val";
      val.textContent = labelText;
      row.appendChild(val);
    }

    return row;
  }

  function classifyWindRisk(mph) {
    var v = parseFloat(mph) || 0;
    // Simple, marine-friendly thresholds (tune later):
    // <10 Low, 10-14 Caution, 15-19 High, >=20 Extreme
    if (v >= 20) return { level: 4, label: "Extreme", haloColor: "239,68,68", haloOpacity: 0.55 };
    if (v >= 15) return { level: 3, label: "High", haloColor: "250,204,21", haloOpacity: 0.45 };
    if (v >= 10) return { level: 2, label: "Caution", haloColor: "59,130,246", haloOpacity: 0.35 };
    return { level: 1, label: "Low", haloColor: "45,212,191", haloOpacity: 0.28 };
  }


  function renderWeatherAlerts(alerts) {
    var listEl = document.getElementById("weatherAlertsList");
    var emptyEl = document.getElementById("weatherAlertsEmpty");
    var statusDot = document.getElementById("weatherStatusDot");
    var alertLabelEl = document.getElementById("weatherAlertLabel");

    var items = Array.isArray(alerts) ? alerts : [];
    var topItems = items.slice(0, 2);

    if (alertLabelEl) {
      alertLabelEl.textContent = items.length ? (items.length + " active") : "None";
    }

    // Determine highest severity for status dot
    var worst = "ok";
    items.forEach(function (a) {
      var sev = mapAlertSeverity(a && a.severity ? a.severity : "");
      if (sev === "critical") worst = "danger";
      else if (sev === "warning" && worst !== "danger") worst = "warn";
      else if (sev === "info" && worst === "ok") worst = "ok";
    });

    if (statusDot) {
      statusDot.classList.remove("ok", "warn", "danger");
      statusDot.classList.add(worst);
    }

    if (!listEl || !emptyEl) return;

    listEl.innerHTML = "";

    if (!topItems.length) {
      toggleHidden(emptyEl, false);
      return;
    }
    toggleHidden(emptyEl, true);

    topItems.forEach(function (alert) {
      var severity = alert && alert.severity ? alert.severity : "";
      var sevClass = mapAlertSeverity(severity); // info | warning | critical
      var label = severity ? severity.toString().toUpperCase() : "INFO";
      var title = (alert && (alert.headline || alert.event)) ? (alert.headline || alert.event) : "Marine alert";
      var instruction = (alert && alert.instruction) ? alert.instruction : "";

      var li = document.createElement("li");
      li.className = "fpw-wx__alertItem";

      var head = document.createElement("div");
      head.className = "fpw-wx__alertHead";

      var badge = document.createElement("span");
      badge.className = "fpw-wx__alertBadge " + sevClass;
      badge.textContent = label;

      var titleEl = document.createElement("div");
      titleEl.className = "fpw-wx__alertTitle";
      titleEl.textContent = title;

      head.appendChild(badge);
      head.appendChild(titleEl);

      li.appendChild(head);

      if (instruction) {
        var msg = document.createElement("div");
        msg.className = "fpw-wx__alertMsg";
        msg.textContent = instruction;
        li.appendChild(msg);
      }

      listEl.appendChild(li);
    });
  }

  
  function parseDateAny(val) {
    if (!val) return null;
    if (val instanceof Date) return isNaN(val.getTime()) ? null : val;
    var s = val.toString().trim();
    if (!s) return null;

    // MySQL-ish "YYYY-MM-DD HH:MM:SS" -> "YYYY-MM-DDTHH:MM:SS"
    if (/^\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}/.test(s) && s.indexOf("T") === -1) {
      s = s.replace(" ", "T");
    }
    var d = new Date(s);
    if (!isNaN(d.getTime())) return d;

    // Epoch ms
    var n = parseInt(s, 10);
    if (!isNaN(n) && n > 1000000000) {
      d = new Date(n);
      if (!isNaN(d.getTime())) return d;
    }
    return null;
  }

  function fmtShortTime(d) {
    if (!d || isNaN(d.getTime())) return "—";
    var hrs = d.getHours();
    var mins = d.getMinutes();
    var ap = hrs >= 12 ? "PM" : "AM";
    var h12 = hrs % 12; if (h12 === 0) h12 = 12;
    return mins ? (h12 + ":" + String(mins).padStart(2, "0") + " " + ap) : (h12 + " " + ap);
  }

  function resolveActivePlanWindow() {
    var candidates = [];
    try {
      if (state) {
        if (state.activeFloatPlan) candidates.push(state.activeFloatPlan);
        if (state.selectedFloatPlan) candidates.push(state.selectedFloatPlan);
        if (state.currentFloatPlan) candidates.push(state.currentFloatPlan);
        if (state.floatPlan) candidates.push(state.floatPlan);
        if (state.floatPlanContext) candidates.push(state.floatPlanContext);
        if (state.lastOpenedFloatPlan) candidates.push(state.lastOpenedFloatPlan);
      }
      if (window.FPW && window.FPW.ActiveFloatPlan) candidates.push(window.FPW.ActiveFloatPlan);
    } catch (e) {}

    var plan = null;
    for (var i = 0; i < candidates.length; i++) {
      if (candidates[i] && typeof candidates[i] === "object") { plan = candidates[i]; break; }
    }
    if (!plan) return null;

    var dep = plan.departureTimeUTC || plan.DEPARTURETIMEUTC || plan.departureTimeUtc || plan.DEPARTURE_TIME_UTC
           || plan.departureTime || plan.DEPARTURETIME || plan.departingTime || plan.DEPARTINGTIME
           || plan.departure || plan.DEPARTURE;

    var ret = plan.returnTimeUTC || plan.RETURNTIMEUTC || plan.returnTimeUtc || plan.RETURN_TIME_UTC
           || plan.returnTime || plan.RETURNTIME || plan.returningTime || plan.RETURNINGTIME
           || plan.return || plan.RETURN;

    var depD = parseDateAny(dep);
    var retD = parseDateAny(ret);
    if (!depD || !retD) return null;

    if (retD.getTime() < depD.getTime()) { var t = depD; depD = retD; retD = t; }

    return { start: depD, end: retD, plan: plan };
  }

  function renderPlanOverlay(rows) {
    var overlay = document.getElementById("weatherPlanOverlay");
    var pill = document.getElementById("weatherPlanPill");
    if (!overlay) return;

    overlay.innerHTML = "";
    var win = resolveActivePlanWindow();
    if (!win || !rows || !rows.length) {
      overlay.classList.add("d-none");
      if (pill) pill.classList.add("d-none");
      return;
    }

    var t0 = parseDateAny(rows[0] && rows[0].startTime ? rows[0].startTime : null);
    var t1 = parseDateAny(rows[rows.length - 1] && rows[rows.length - 1].endTime ? rows[rows.length - 1].endTime : null);
    if (!t0 || !t1) {
      overlay.classList.add("d-none");
      if (pill) pill.classList.add("d-none");
      return;
    }

    var a = win.start.getTime();
    var b = win.end.getTime();
    var s = t0.getTime();
    var e = t1.getTime();

    if (b <= s || a >= e) {
      overlay.classList.add("d-none");
      if (pill) pill.classList.add("d-none");
      return;
    }

    var leftPct = ((Math.max(a, s) - s) / (e - s)) * 100;
    var rightPct = ((Math.min(b, e) - s) / (e - s)) * 100;
    var widthPct = Math.max(1, rightPct - leftPct);

    var band = document.createElement("div");
    band.className = "fpw-wx__planBand";
    band.style.left = leftPct + "%";
    band.style.width = widthPct + "%";

    var lbl = document.createElement("div");
    lbl.className = "fpw-wx__planLabel";
    lbl.textContent = "Float plan window " + fmtShortTime(win.start) + "–" + fmtShortTime(win.end);
    band.appendChild(lbl);

    overlay.appendChild(band);
    overlay.classList.remove("d-none");

    if (pill) {
      pill.textContent = "Plan window: " + fmtShortTime(win.start) + "–" + fmtShortTime(win.end);
      pill.classList.remove("d-none");
    }
  }

  function renderWeatherForecast(forecast) {
    var timelineEl = document.getElementById("weatherTimeline");
    var gustSpikesEl = document.getElementById("weatherGustSpikes");
    var gustLabelsEl = document.getElementById("weatherGustLabels");
    var tempValueEl = document.getElementById("weatherTempValue");
    var tempHiLoEl = document.getElementById("weatherTempHiLo");
    var tempLoLabelEl = document.getElementById("weatherTempLoLabel");
    var tempHiLabelEl = document.getElementById("weatherTempHiLabel");
    var nowWhenEl = document.getElementById("weatherNowWhen");
    var windSpeedEl = document.getElementById("weatherWindSpeed");
    var windDirEl = document.getElementById("weatherWindDir");
    var windNeedleEl = document.getElementById("weatherWindNeedle");
    var windGustEl = document.getElementById("weatherWindGust");
    var windCondEl = document.getElementById("weatherWindCond");
    var riskLabelEl = document.getElementById("weatherRiskLabel");
    var gustValueEl = document.getElementById("weatherGustValue");
    var gustHaloEl = document.getElementById("weatherGustHalo");

    var periods = Array.isArray(forecast) ? forecast : [];
    var rows = periods.slice(0, 12);

    // HI/LO (reuse old helper logic but also drive cockpit temp gauge)
    var hiLoEl = document.getElementById("weatherHiLo");
    var summaryEl = document.getElementById("weatherSummary");
    if (hiLoEl) {
      renderWeatherHiLow(periods, hiLoEl, summaryEl);
    }

    // Temp gauge hi/lo line
    if (tempHiLoEl && hiLoEl) {
      tempHiLoEl.textContent = hiLoEl.textContent ? ("Hi/Lo " + hiLoEl.textContent) : "—";
    }

    // If nothing, clear cockpit visuals
    if (!rows.length) {
      if (timelineEl) timelineEl.innerHTML = "";
      if (gustSpikesEl) gustSpikesEl.innerHTML = "";
      if (tempValueEl) tempValueEl.textContent = "—";
      if (nowWhenEl) nowWhenEl.textContent = "—";
      if (windSpeedEl) windSpeedEl.textContent = "—";
      if (windDirEl) windDirEl.textContent = "—";
      if (windGustEl) windGustEl.textContent = "Gust —";
      if (windCondEl) windCondEl.textContent = "—";
      if (riskLabelEl) riskLabelEl.textContent = "—";
      if (gustValueEl) gustValueEl.textContent = "—";
    if (windNeedleEl) windNeedleEl.style.setProperty("--dir", "0deg");
    if (gustHaloEl) gustHaloEl.style.boxShadow = "inset 0 0 0 2px rgba(255,255,255,.10)";
    var tempWrap = document.querySelector(".fpw-wx__temp");
    if (tempWrap) tempWrap.style.setProperty("--pct", "50");
    renderTideGraph(null);
    return;
  }

    var now = rows[0];
    var nowWhen = (now && now.name) ? now.name : formatForecastWhen(now && now.startTime ? now.startTime : "");
    if (nowWhenEl) nowWhenEl.textContent = nowWhen || "Now";

    // WIND
    var windDir = now && now.windDirection ? now.windDirection : "";
    var windSpeedRaw = now && now.windSpeed ? now.windSpeed : "";
    var wind = parseWindSpeed(windSpeedRaw);
    var speed = wind.speed;
    var gust = resolveGustMph(now, wind);

    if (windSpeedEl) windSpeedEl.textContent = speed ? (speed + " mph") : "—";
    if (windDirEl) windDirEl.textContent = windDir || "—";
    if (windGustEl) windGustEl.textContent = "Gust " + (gust ? (Math.round(gust) + " mph") : "—");
    if (windCondEl) windCondEl.textContent = (now && now.shortForecast) ? now.shortForecast : "—";

    var deg = compassToDegrees(windDir);
    if (windNeedleEl) {
      windNeedleEl.style.setProperty("--dir", deg + "deg");
    }

    // Risk label + halo intensity
    var risk = classifyWindRisk(gust || speed || 0);
    if (riskLabelEl) riskLabelEl.textContent = risk.label;

    if (gustHaloEl) {
      gustHaloEl.style.opacity = risk.haloOpacity;
      gustHaloEl.style.boxShadow = "inset 0 0 0 2px rgba(255,255,255,.10), 0 0 0 0 rgba(0,0,0,0), 0 0 0 0 rgba(0,0,0,0)";
      gustHaloEl.style.boxShadow = "inset 0 0 0 2px rgba(255,255,255,.10), 0 0 26px rgba(" + risk.haloColor + "," + risk.haloOpacity + ")";
    }

    // TEMP gauge
    var nowTemp = (now && now.temperature !== undefined && now.temperature !== null) ? parseFloat(now.temperature) : NaN;
    if (tempValueEl) tempValueEl.textContent = Number.isFinite(nowTemp) ? (Math.round(nowTemp) + "°") : "—";

    var lo = Number.POSITIVE_INFINITY;
    var hi = Number.NEGATIVE_INFINITY;
    periods.forEach(function (p) {
      var t = (p && p.temperature !== undefined && p.temperature !== null) ? parseFloat(p.temperature) : NaN;
      if (!Number.isFinite(t)) return;
      if (t < lo) lo = t;
      if (t > hi) hi = t;
    });
    if (!Number.isFinite(lo) || !Number.isFinite(hi) || lo === hi) {
      lo = 40; hi = 90;
    }
    if (tempLoLabelEl) tempLoLabelEl.textContent = Math.round(lo) + "°";
    if (tempHiLabelEl) tempHiLabelEl.textContent = Math.round(hi) + "°";
    var pct = Number.isFinite(nowTemp) ? Math.round(((nowTemp - lo) / (hi - lo)) * 100) : 50;
    pct = clamp(pct, 2, 98);
    var tempWrapEl = document.querySelector(".fpw-wx__temp");
    if (tempWrapEl) tempWrapEl.style.setProperty("--pct", pct);

    // Build timeline bars + gust spikes
    var maxGust = 0;
    rows.forEach(function (p) {
      var w = parseWindSpeed(p && p.windSpeed ? p.windSpeed : "");
      var gResolved = resolveGustMph(p, w);
      if (gResolved > maxGust) maxGust = gResolved;
      if (w.speed > maxGust) maxGust = w.speed;
    });
    if (maxGust <= 0) maxGust = 25;

    if (timelineEl) {
      timelineEl.innerHTML = "";
      rows.forEach(function (p, idx) {
        var w = parseWindSpeed(p && p.windSpeed ? p.windSpeed : "");
        var g = resolveGustMph(p, w);
        var t = (p && p.temperature !== undefined && p.temperature !== null) ? parseFloat(p.temperature) : NaN;

        var when = formatTimeOfDay(p && p.startTime ? p.startTime : "") || ((p && p.name) ? abbreviateWhen(p.name) : formatForecastWhen(p && p.startTime ? p.startTime : ""));

        var windPct = clamp(Math.round((w.speed / maxGust) * 100), 0, 100);
        var gustPct = clamp(Math.round((g / maxGust) * 100), 0, 100);

        var rainPct = inferRainPct(p);

        var bar = document.createElement("div");
        bar.className = "fpw-wx__bar";

        var top = document.createElement("div");
        top.className = "fpw-wx__barTop";

        var whenEl = document.createElement("div");
        whenEl.className = "fpw-wx__barWhen";
        whenEl.textContent = when || "—";

        var tempEl = document.createElement("div");
        tempEl.className = "fpw-wx__barTemp";
        tempEl.textContent = Number.isFinite(t) ? (Math.round(t) + "°") : "—";

        top.appendChild(whenEl);
        top.appendChild(tempEl);

        var meters = document.createElement("div");
        meters.className = "fpw-wx__barMeters";

        meters.appendChild(buildMeterRow("wind", windPct, (w.speed ? (w.speed + " mph") : "—")));
        meters.appendChild(buildMeterRow("gust", gustPct, (g ? (Math.round(g) + " mph") : "—")));
        meters.appendChild(buildMeterRow("rain", rainPct, (rainPct !== null && rainPct !== undefined ? (rainPct + "%") : "—")));

        bar.appendChild(top);
        bar.appendChild(meters);

        var meta = document.createElement("div");
        meta.className = "fpw-wx__barMeta";

        var chipW = document.createElement("span");
        chipW.className = "chip";
        chipW.innerHTML = "Wind <b>" + (w.speed ? (w.speed + " mph") : "—") + "</b>";

        var chipG = document.createElement("span");
        chipG.className = "chip";
        chipG.innerHTML = "Gust <b>" + (g ? (Math.round(g) + " mph") : "—") + "</b>";

        var chipR = document.createElement("span");
        chipR.className = "chip";
        chipR.innerHTML = "Rain <b>" + (rainPct !== null && rainPct !== undefined ? (rainPct + "%") : "—") + "</b>";

        meta.appendChild(chipW);
        meta.appendChild(chipG);
        meta.appendChild(chipR);
        bar.appendChild(meta);

        // Flag if risk is high for this period
        var r = classifyWindRisk(g || w.speed || 0);
        if (r.level >= 3) {
          var flag = document.createElement("div");
          flag.className = "fpw-wx__barFlag";
          bar.appendChild(flag);
        }

        timelineEl.appendChild(bar);
      });

      // Overlay float plan window (if available)
      renderPlanOverlay(rows);
    }

    if (gustSpikesEl) {
      gustSpikesEl.innerHTML = "";
      if (gustLabelsEl) gustLabelsEl.innerHTML = "";
      rows.forEach(function (p) {
        var w = parseWindSpeed(p && p.windSpeed ? p.windSpeed : "");
        var g = resolveGustMph(p, w);
        var hPct = clamp(Math.round((g / maxGust) * 100), 2, 100);

        var spike = document.createElement("div");
        spike.className = "fpw-wx__spike " + (g >= 18 ? "hot" : (g <= 9 ? "ok" : ""));
        spike.style.height = hPct + "%";
        spike.title = g ? (g + " mph") : "—";

        var sheen = document.createElement("i");
        spike.appendChild(sheen);

        gustSpikesEl.appendChild(spike);
      });

      if (gustLabelsEl) {
        gustLabelsEl.style.gridTemplateColumns = "repeat(" + rows.length + ", minmax(0, 1fr))";
        rows.forEach(function (p2, idx2) {
          var tick = document.createElement("span");
          tick.className = "fpw-wx__spikeLabelTick";
          tick.textContent = formatHourOnly(p2 && p2.startTime ? p2.startTime : "") || "—";
          gustLabelsEl.appendChild(tick);
        });
      }
    }

    if (gustValueEl) {
      gustValueEl.textContent = (gust || speed) ? (Math.round(gust || speed) + " mph") : "—";
    }
  }

  function ensureTideResizeObserver() {
    if (tideResizeObserver || !window.ResizeObserver) return;
    var wrap = document.getElementById("tideGraph");
    if (!wrap) return;
    tideResizeObserver = new window.ResizeObserver(function (entries) {
      if (!entries || !entries.length) return;
      var nextWidth = Math.round(entries[0].contentRect && entries[0].contentRect.width ? entries[0].contentRect.width : 0);
      if (!nextWidth) return;
      if (Math.abs(nextWidth - tideLastWrapWidth) < 2) return;
      tideLastWrapWidth = nextWidth;
      if (tideLastMarine) {
        renderTideGraph(tideLastMarine);
      }
    });
    tideResizeObserver.observe(wrap);
  }

  function renderTideGraph(marine) {
    ensureTideResizeObserver();
    var wrap = document.getElementById("tideGraph");
    var svg = document.getElementById("tideGraphSvg");
    var titleEl = document.getElementById("tideGraphTitle");
    var stationEl = document.getElementById("tideGraphStation");
    var nowEl = document.getElementById("tideGraphNowValue");
    var startEl = document.getElementById("tideGraphStart");
    var endEl = document.getElementById("tideGraphEnd");
    var emptyEl = document.getElementById("tideGraphEmpty");

    if (!wrap || !svg) return;

    tideLastMarine = marine || null;

    var marineMeta = (marine && (marine.META || marine.meta)) ? (marine.META || marine.meta) : {};
    var tide = null;
    var waterLevelCurrent = null;
    var series = [];
    var sourceType = "tide";

    if (marine) {
      tide = marine.tide || marine.TIDE || null;
      if (!tide) {
        tide = marine.waterLevel || marine.WATERLEVEL || null;
        sourceType = "waterLevel";
      }
      waterLevelCurrent = marine.waterLevelCurrent || marine.WATERLEVELCURRENT || null;
      if (!tide && waterLevelCurrent) {
        sourceType = "waterLevel";
      }
    }
    if (tide) {
      series = Array.isArray(tide.series) ? tide.series : (Array.isArray(tide.SERIES) ? tide.SERIES : []);
    }
    if (titleEl) {
      titleEl.textContent = (sourceType === "waterLevel") ? "Water Level (ft)" : "Tide (ft)";
    }
    if (!tide || !series.length) {
      svg.innerHTML = "";
      if (stationEl) {
        if (waterLevelCurrent && waterLevelCurrent.stationName) {
          var fullCurrentStation = String(waterLevelCurrent.stationName).trim();
          var stationMaxLen2 = 24;
          var shortCurrentStation = fullCurrentStation;
          if (fullCurrentStation.length > stationMaxLen2) {
            shortCurrentStation = fullCurrentStation.slice(0, stationMaxLen2 - 3).trimEnd() + "...";
          }
          stationEl.textContent = shortCurrentStation;
          stationEl.title = fullCurrentStation;
        } else {
          stationEl.textContent = "";
          stationEl.removeAttribute("title");
        }
      }
      if (nowEl) {
        if (waterLevelCurrent && waterLevelCurrent.h !== undefined && waterLevelCurrent.h !== null && !isNaN(parseFloat(waterLevelCurrent.h))) {
          nowEl.textContent = "Now " + parseFloat(waterLevelCurrent.h).toFixed(1) + " ft";
        } else {
          nowEl.textContent = "Now —";
        }
      }
      if (startEl) startEl.textContent = "—";
      if (endEl) endEl.textContent = "—";
      if (emptyEl) {
        var emptyMsg = "Tide data unavailable.";
        if (marineMeta) {
          if (marineMeta.tideUnavailable) {
            emptyMsg = marineMeta.tideUnavailable;
          } else if (marineMeta.waterLevelUnavailable) {
            emptyMsg = marineMeta.waterLevelUnavailable;
          } else if (sourceType === "waterLevel") {
            emptyMsg = "Water level data unavailable.";
          }
        }
        if (waterLevelCurrent && waterLevelCurrent.h !== undefined && waterLevelCurrent.h !== null && !isNaN(parseFloat(waterLevelCurrent.h))) {
          emptyMsg = "Current water level available; trend graph is unavailable right now.";
        }
        emptyEl.textContent = emptyMsg;
        emptyEl.classList.remove("d-none");
      }
      wrap.classList.remove("d-none");
      return;
    }

    if (emptyEl) emptyEl.classList.add("d-none");
    if (stationEl) {
      var fullStation = String(tide.stationName || tide.STATIONNAME || "").trim();
      var stationMaxLen = 24;
      var shortStation = fullStation;
      if (fullStation.length > stationMaxLen) {
        shortStation = fullStation.slice(0, stationMaxLen - 3).trimEnd() + "...";
      }
      stationEl.textContent = shortStation;
      stationEl.title = fullStation;
    }
    wrap.classList.remove("d-none");

    var minH = Number.POSITIVE_INFINITY;
    var maxH = Number.NEGATIVE_INFINITY;
    var points = [];

    function parseTideDate(raw) {
      if (!raw) return null;
      var s = String(raw).trim();
      var d = new Date(s);
      if (!isNaN(d.getTime())) return d;
      if (/^\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}/.test(s)) {
        d = new Date(s.replace(" ", "T") + "Z");
        if (!isNaN(d.getTime())) return d;
        d = new Date(s.replace(" ", "T"));
        if (!isNaN(d.getTime())) return d;
      }
      return null;
    }

    series.forEach(function (p) {
      var h = parseFloat((p && p.h !== undefined) ? p.h : (p ? p.H : NaN));
      if (!Number.isFinite(h)) return;
      if (h < minH) minH = h;
      if (h > maxH) maxH = h;
      var tRaw = p && (p.t || p.T) ? (p.t || p.T) : "";
      var dt = parseTideDate(tRaw);
      points.push({ h: h, tRaw: tRaw, dt: dt });
    });
    if (!Number.isFinite(minH) || !Number.isFinite(maxH) || minH === maxH) {
      minH = (Number.isFinite(minH) ? minH - 1 : 0);
      maxH = (Number.isFinite(maxH) ? maxH + 1 : 1);
    }

    var wrapRect = wrap.getBoundingClientRect ? wrap.getBoundingClientRect() : null;
    var wrapWidth = Math.round((wrapRect && wrapRect.width) ? wrapRect.width : (wrap.offsetWidth || wrap.clientWidth || 0));
    var w = Math.round(wrapWidth || svg.clientWidth || 320);
    var hgt = Math.round(svg.clientHeight || 84);
    tideLastWrapWidth = wrapWidth || w;
    if (w < 120) w = 320;
    if (hgt < 40) hgt = 120;
    svg.setAttribute("viewBox", "0 0 " + w + " " + hgt);
    var padTop = 8;
    var padBottom = 14;
    var padLeft = 30;
    var padRight = 30;
    var plotW = (w - padLeft - padRight);
    var plotH = (hgt - padTop - padBottom);
    var dx = (points.length > 1) ? (plotW / (points.length - 1)) : 0;
    var path = "";
    var area = "";

    points.forEach(function (p, i) {
      var v = parseFloat(p.h);
      if (!Number.isFinite(v)) v = minH;
      var x = padLeft + (dx * i);
      var y = padTop + plotH * (1 - ((v - minH) / (maxH - minH)));
      p.x = x;
      p.y = y;
      path += (i === 0 ? "M" : "L") + x.toFixed(2) + " " + y.toFixed(2) + " ";
      area += (i === 0 ? "M" : "L") + x.toFixed(2) + " " + y.toFixed(2) + " ";
    });

    var lastX = padLeft + dx * (points.length - 1);
    var areaPath = area + "L " + lastX.toFixed(2) + " " + (hgt - padBottom).toFixed(2)
      + " L " + padLeft.toFixed(2) + " " + (hgt - padBottom).toFixed(2) + " Z";

    function formatAxisHour(raw) {
      var dt = parseTideDate(raw);
      if (!dt) return "";
      var h = dt.getHours() % 12;
      return String(h === 0 ? 12 : h);
    }

    var axesOverlay = "";
    var xAxisY = (hgt - padBottom).toFixed(2);
    var yAxisX = padLeft.toFixed(2);
    axesOverlay += "<line class=\"fpw-wx__tideAxisLine\" x1=\"" + yAxisX + "\" y1=\"" + padTop.toFixed(2) + "\" x2=\"" + yAxisX + "\" y2=\"" + xAxisY + "\"/>";
    axesOverlay += "<line class=\"fpw-wx__tideAxisLine\" x1=\"" + yAxisX + "\" y1=\"" + xAxisY + "\" x2=\"" + (w - padRight).toFixed(2) + "\" y2=\"" + xAxisY + "\"/>";

    var yTicks = 4;
    var yi;
    for (yi = 0; yi <= yTicks; yi++) {
      var fracY = yi / yTicks;
      var yVal = maxH - ((maxH - minH) * fracY);
      var yPos = (padTop + (plotH * fracY));
      axesOverlay += "<line class=\"fpw-wx__tideAxisTick\" x1=\"" + (padLeft - 4).toFixed(2) + "\" y1=\"" + yPos.toFixed(2) + "\" x2=\"" + padLeft.toFixed(2) + "\" y2=\"" + yPos.toFixed(2) + "\"/>";
      axesOverlay += "<text class=\"fpw-wx__tideAxisLabel y\" x=\"" + (padLeft - 6).toFixed(2) + "\" y=\"" + (yPos + 3).toFixed(2) + "\">" + yVal.toFixed(1) + "</text>";
    }

    var xTickCount = Math.min(5, points.length);
    var xi;
    for (xi = 0; xi < xTickCount; xi++) {
      var idx = Math.round((xi * (points.length - 1)) / Math.max(1, (xTickCount - 1)));
      idx = Math.max(0, Math.min(points.length - 1, idx));
      var px = points[idx].x;
      var lbl = formatAxisHour(points[idx].tRaw);
      axesOverlay += "<line class=\"fpw-wx__tideAxisTick\" x1=\"" + px.toFixed(2) + "\" y1=\"" + xAxisY + "\" x2=\"" + px.toFixed(2) + "\" y2=\"" + (hgt - padBottom + 4).toFixed(2) + "\"/>";
      if (lbl) {
        axesOverlay += "<text class=\"fpw-wx__tideAxisLabel x\" x=\"" + px.toFixed(2) + "\" y=\"" + (hgt - 1).toFixed(2) + "\">" + lbl + "</text>";
      }
    }

    var nowMs = Date.now();
    var currentH = null;
    var currentX = null;
    var currentY = null;
    var i;
    for (i = 0; i < points.length - 1; i++) {
      var a = points[i];
      var b = points[i + 1];
      if (!a.dt || !b.dt) continue;
      var ams = a.dt.getTime();
      var bms = b.dt.getTime();
      if (bms <= ams) continue;
      if (nowMs >= ams && nowMs <= bms) {
        var r = (nowMs - ams) / (bms - ams);
        currentH = a.h + ((b.h - a.h) * r);
        currentX = a.x + ((b.x - a.x) * r);
        currentY = a.y + ((b.y - a.y) * r);
        break;
      }
    }
    if (currentH === null) {
      var nearest = null;
      points.forEach(function (pnt) {
        if (!pnt.dt) return;
        var diff = Math.abs(nowMs - pnt.dt.getTime());
        if (!nearest || diff < nearest.diff) {
          nearest = { diff: diff, p: pnt };
        }
      });
      if (nearest && nearest.p) {
        currentH = nearest.p.h;
        currentX = nearest.p.x;
        currentY = nearest.p.y;
      }
    }

    var nowOverlay = "";
    if (currentH !== null && currentX !== null && currentY !== null) {
      var tickY = currentY.toFixed(2);
      var guideStartX = padLeft.toFixed(2);
      nowOverlay = ""
        + "<line class=\"fpw-wx__tideGuide\" x1=\"" + guideStartX + "\" y1=\"" + tickY + "\" x2=\"" + (w - padRight).toFixed(2) + "\" y2=\"" + tickY + "\"/>"
        + "<circle class=\"fpw-wx__tideNowHalo\" cx=\"" + currentX.toFixed(2) + "\" cy=\"" + currentY.toFixed(2) + "\" r=\"6\"/>"
        + "<circle class=\"fpw-wx__tideNowDot\" cx=\"" + currentX.toFixed(2) + "\" cy=\"" + currentY.toFixed(2) + "\" r=\"3\"/>";
      if (nowEl) nowEl.textContent = "Now " + currentH.toFixed(1) + " ft";
    } else if (nowEl) {
      nowEl.textContent = "Now —";
    }

    var highIdx = -1;
    var lowIdx = -1;
    var highVal = Number.NEGATIVE_INFINITY;
    var lowVal = Number.POSITIVE_INFINITY;
    points.forEach(function (p, idx) {
      if (!Number.isFinite(p.h)) return;
      if (p.h > highVal) {
        highVal = p.h;
        highIdx = idx;
      }
      if (p.h < lowVal) {
        lowVal = p.h;
        lowIdx = idx;
      }
    });

    function clamp(n, min, max) {
      return Math.max(min, Math.min(max, n));
    }

    function buildExtremaLabel(pt, cls, preferAbove) {
      if (!pt) return "";
      var label = pt.h.toFixed(1) + " ft";
      var textW = Math.max(46, (label.length * 4.2));
      var tx = clamp(pt.x - (textW / 2), padLeft + 2, (w - padRight - textW - 2));
      var yOffset = preferAbove ? -7 : 11;
      var ty = pt.y + yOffset;
      if (preferAbove && ty < (padTop + 7)) ty = pt.y + 11;
      if (!preferAbove && ty > (hgt - padBottom - 2)) ty = pt.y - 7;
      return ""
        + "<circle class=\"fpw-wx__tideExtDot " + cls + "\" cx=\"" + pt.x.toFixed(2) + "\" cy=\"" + pt.y.toFixed(2) + "\" r=\"2.8\"/>"
        + "<text class=\"fpw-wx__tideExtLabel " + cls + "\" x=\"" + tx.toFixed(2) + "\" y=\"" + ty.toFixed(2) + "\">" + label + "</text>";
    }

    var extremaOverlay = "";
    if (highIdx >= 0) {
      extremaOverlay += buildExtremaLabel(points[highIdx], "high", true);
    }
    if (lowIdx >= 0) {
      var lowPreferAbove = false;
      if (highIdx >= 0 && Math.abs(points[highIdx].x - points[lowIdx].x) < 44) {
        lowPreferAbove = true;
      }
      extremaOverlay += buildExtremaLabel(points[lowIdx], "low", lowPreferAbove);
    }

    svg.innerHTML = ""
      + "<defs>"
      + "<linearGradient id=\"tideFill\" x1=\"0\" y1=\"0\" x2=\"0\" y2=\"1\">"
      + "<stop offset=\"0%\" stop-color=\"rgba(59,130,246,.45)\"/>"
      + "<stop offset=\"100%\" stop-color=\"rgba(59,130,246,0)\"/>"
      + "</linearGradient>"
      + "</defs>"
      + axesOverlay
      + "<path d=\"" + areaPath + "\" fill=\"url(#tideFill)\"/>"
      + "<path d=\"" + path + "\" fill=\"none\" stroke=\"rgba(59,130,246,.9)\" stroke-width=\"2\"/>"
      + extremaOverlay
      + nowOverlay;

    if (startEl) startEl.textContent = series[0] && (series[0].t || series[0].T) ? (series[0].t || series[0].T) : "—";
    if (endEl) endEl.textContent = series[series.length - 1] && (series[series.length - 1].t || series[series.length - 1].T) ? (series[series.length - 1].t || series[series.length - 1].T) : "—";
    wrap.classList.remove("d-none");
  }

  function renderWeatherSummary(summary, message) {
    var summaryEl = document.getElementById("weatherSummary");
    if (!summaryEl) return;
    var text = summary || message || "Forecast unavailable.";
    summaryEl.dataset.baseSummary = text;
    applySummaryDecoration(summaryEl);
  }

  function renderWeatherHiLow(forecast, hiLoEl, summaryEl) {
    if (!hiLoEl) return;
    var temps = [];
    if (Array.isArray(forecast)) {
      forecast.forEach(function (p) {
        if (p && p.temperature !== undefined && p.temperature !== null && !isNaN(parseFloat(p.temperature))) {
          temps.push(parseFloat(p.temperature));
        }
      });
    }
    if (!temps.length) {
      hiLoEl.textContent = "";
      if (summaryEl) {
        summaryEl.dataset.hi = "";
        summaryEl.dataset.lo = "";
        applySummaryDecoration(summaryEl);
      }
      return;
    }
    var hi = Math.max.apply(null, temps);
    var lo = Math.min.apply(null, temps);
    hiLoEl.textContent = hi + "° / " + lo + "°";
    if (summaryEl) {
      summaryEl.dataset.hi = hi;
      summaryEl.dataset.lo = lo;
      applySummaryDecoration(summaryEl);
    }
  }

  function renderWeatherAnchor(meta) {
    var metaEl = document.getElementById("weatherAnchorMeta");
    if (!metaEl) return;
    if (meta && meta.anchor && meta.anchor.lat !== undefined && meta.anchor.lon !== undefined) {
      var lat = parseFloat(meta.anchor.lat);
      var lon = parseFloat(meta.anchor.lon);
      if (!Number.isNaN(lat) && !Number.isNaN(lon)) {
        metaEl.textContent = "Anchor: " + lat.toFixed(2) + ", " + lon.toFixed(2);
        return;
      }
    }
    metaEl.textContent = "";
  }

  function formatForecastWhen(startTime) {
    if (!startTime) {
      return "";
    }
    var parsed = new Date(startTime);
    if (isNaN(parsed.getTime())) {
      return startTime;
    }
    try {
      return parsed.toLocaleString(undefined, {
        weekday: "short",
        hour: "numeric",
        minute: "2-digit"
      });
    } catch (e) {
      return parsed.toString();
    }
  }

  function applySummaryDecoration(summaryEl) {
    if (!summaryEl) return;
    var base = summaryEl.dataset.baseSummary || summaryEl.textContent || "";
    var dateStr = formatSummaryDate(new Date());
    var hi = summaryEl.dataset.hi;
    var lo = summaryEl.dataset.lo;
    var parts = [];
    if (base) {
      parts.push(base);
    }
    if (hi && lo) {
      parts.push( hi + "°/" + lo + "°");
    }
    if (dateStr) {
      parts.push(dateStr);
    }
    summaryEl.textContent = parts.join(" • ");
  }

  function formatSummaryDate(dateObj) {
    if (!dateObj) return "";
    try {
      return dateObj.toLocaleDateString(undefined, {
        weekday: "short",
        month: "short",
        day: "numeric"
      });
    } catch (e) {
      return "";
    }
  }

  function updateWeatherTitleDate() {
    var titleEl = document.getElementById("weatherPanelTitle");
    if (!titleEl) return;
    var dateStr = formatSummaryDate(new Date());
    titleEl.textContent = dateStr || "—";
  }


  function normalizeZip(value) {
    return (value || "")
      .toString()
      .replace(/\D/g, "")
      .slice(0, 5);
  }

  function isValidZip(zip) {
    return zip && zip.length === 5;
  }

  function weatherUrl(zip, extras) {
    var url = WEATHER_BASE_URL + encodeURIComponent(zip) + "&returnformat=json";
    if (extras) {
      url += extras;
    }
    return url;
  }

  function fetchWeatherJson(url) {
    return fetch(url, { credentials: "same-origin" })
      .then(function (response) {
        if (!response.ok) {
          throw new Error("Request failed with status " + response.status);
        }
        return response.json();
      });
  }

  function hydrateMarineTrend(zip, requestSeq) {
    return fetchWeatherJson(weatherUrl(zip, "&marineOnly=1&marineMode=full"))
      .then(function (payload) {
        if (requestSeq !== weatherRequestSeq) return;
        if (!payload || payload.SUCCESS === false) return;
        var data = payload.DATA || {};
        if (data.MARINE) {
          renderTideGraph(data.MARINE);
        }
      })
      .catch(function () {
        // Keep initial quick render if trend hydration fails.
      });
  }

  function loadWeather(zip) {
    var loadingEl = document.getElementById("weatherLoading");
    if (!loadingEl) {
      return;
    }
    weatherRequestSeq += 1;
    var requestSeq = weatherRequestSeq;

    toggleHidden(loadingEl, false);
    clearWeatherError();

    return fetchWeatherJson(weatherUrl(zip, "&marineMode=quick"))
      .then(function (payload) {
        if (requestSeq !== weatherRequestSeq) return;
        if (!payload || payload.SUCCESS === false) {
          var message = payload && payload.MESSAGE ? payload.MESSAGE : null;
          throw new Error(message || "Weather data unavailable.");
        }

        var data = payload.DATA || {};
        renderWeatherSummary(data.SUMMARY, payload.MESSAGE);
        renderWeatherAnchor(data.META);
        renderWeatherAlerts(data.ALERTS);
        renderWeatherForecast(data.FORECAST);
        renderTideGraph(data.MARINE);
        hydrateMarineTrend(zip, requestSeq);
      })
      .catch(function (err) {
        if (requestSeq !== weatherRequestSeq) return;
        renderWeatherSummary("", "");
        renderWeatherAnchor(null);
        renderWeatherAlerts([]);
        renderWeatherForecast([]);
        renderTideGraph(null);
        setWeatherError((err && err.message) ? err.message : null);
      })
      .finally(function () {
        toggleHidden(loadingEl, true);
      });
  }

  function initWeatherPanel(initialZip) {
    var refreshBtn = document.getElementById("weatherRefreshBtn");
    var zipInput = document.getElementById("weatherZip");
    if (!refreshBtn) {
      return;
    }

    updateWeatherTitleDate();

    if (zipInput && initialZip) {
      zipInput.value = normalizeZip(initialZip);
    }

    function requestWeatherFromInput(invalidZipMessage) {
      var zip = normalizeZip(zipInput ? zipInput.value : "");
      if (zipInput) {
        zipInput.value = zip;
      }

      if (!isValidZip(zip)) {
        var msg = invalidZipMessage;
        if (!msg) {
          msg = zip ? "Enter a valid 5-digit ZIP code." : "Home port ZIP is required. Update it in Account settings.";
        }
        renderWeatherSummary("", "");
        renderWeatherAnchor(null);
        renderWeatherAlerts([]);
        renderWeatherForecast([]);
        renderTideGraph(null);
        setWeatherError(msg);
        return;
      }

      loadWeather(zip);
    }

    refreshBtn.addEventListener("click", function () {
      requestWeatherFromInput();
    });

    requestWeatherFromInput("Home port ZIP is required. Update it in Account settings.");
  }

  function initDashboard() {
    if (utils.clearDashboardAlert) {
      utils.clearDashboardAlert();
    }
    if (utils.ensureConfirmModal) {
      utils.ensureConfirmModal();
    }
    if (utils.ensureAlertModal) {
      utils.ensureAlertModal();
    }

    if (modules.floatplans && modules.floatplans.init) {
      modules.floatplans.init();
    }
    if (modules.vessels && modules.vessels.init) {
      modules.vessels.init();
    }
    if (modules.contacts && modules.contacts.init) {
      modules.contacts.init();
    }
    if (modules.passengers && modules.passengers.init) {
      modules.passengers.init();
    }
    if (modules.operators && modules.operators.init) {
      modules.operators.init();
    }
    if (modules.waypoints && modules.waypoints.init) {
      modules.waypoints.init();
    }
    if (modules.alerts && modules.alerts.init) {
      modules.alerts.init();
    }
    // TODO: call /api/v1/floatplans.cfc?method=getMonitoredPlans every 60s and render counts/list.

    Api.getCurrentUser()
      .then(function (data) {
        // data.SUCCESS already checked in Api.request
        if (utils.ensureAuthResponse && !utils.ensureAuthResponse(data)) {
          return;
        }

        if (!data.USER) {
          redirectToLogin();
          return;
        }

        populateUserInfo(data.USER);
        if (utils.resolveHomePortLatLng) {
          state.homePortLatLng = utils.resolveHomePortLatLng(data.USER);
        }
        var homePortZip = "";
        if (utils.resolveHomePortZip) {
          homePortZip = utils.resolveHomePortZip(data.USER);
        }
        initWeatherPanel(homePortZip);

        var readyEvent = null;
        if (typeof Event === "function") {
          readyEvent = new Event("fpw:dashboard:user-ready");
        } else {
          readyEvent = document.createEvent("Event");
          readyEvent.initEvent("fpw:dashboard:user-ready", true, true);
        }
        document.dispatchEvent(readyEvent);
      })
      .catch(function (err) {
        console.error("Failed to load current user:", err);
        // If the API fails, assume not logged in and send to login
        redirectToLogin();
      });

    // Wire up logout
    var logoutBtn = document.getElementById("logoutButton");
    if (logoutBtn) {
      logoutBtn.addEventListener("click", function () {
        Api.logout()
          .catch(function (err) {
            console.error("Logout failed:", err);
            // Ignore errors, just send them to login
          })
          .finally(function () {
            redirectToLogin();
          });
      });
    }

  }

  window.FPW_DASHBOARD_VERSION = "20260211w";
  document.addEventListener("DOMContentLoaded", initDashboard);
})(window, document);
