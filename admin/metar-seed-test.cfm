<cfsetting showdebugoutput="false">
<cfcontent type="text/html; charset=utf-8">

<cfscript>
function normalizeZip(required string zipVal) {
  return rereplace(trim(arguments.zipVal), "[^0-9]", "", "all");
}

function geocodeZipQuick(required string zipVal) {
  var out = { "success"=false, "zip"=normalizeZip(arguments.zipVal), "lat"=0, "lng"=0, "message"="", "source"="" };
  var svc = "";
  var res = {};
  var status = 0;
  var obj = {};
  var place = {};

  if (!reFind("^[0-9]{5}$", out.zip)) {
    out.message = "ZIP must be 5 digits.";
    return out;
  }

  try {
    svc = new http(url="https://api.zippopotam.us/us/" & out.zip, method="get", timeout=15);
    svc.addParam(type="header", name="Accept", value="application/json");
    res = svc.send().getPrefix();
    status = val(structKeyExists(res, "statusCode") ? res.statusCode : 0);

    if (status GTE 200 AND status LT 300 AND structKeyExists(res, "fileContent") AND len(trim(toString(res.fileContent)))) {
      obj = deserializeJSON(res.fileContent, false, false, true);
      if (isStruct(obj) AND structKeyExists(obj, "places") AND isArray(obj.places) AND arrayLen(obj.places) GT 0) {
        place = obj.places[1];
        if (structKeyExists(place, "latitude") AND structKeyExists(place, "longitude")) {
          out.lat = val(place.latitude);
          out.lng = val(place.longitude);
          out.success = true;
          out.source = "zippopotam";
          out.message = "OK";
          return out;
        }
      }
    }
  } catch (any eZip) {
  }

  out.message = "Unable to geocode ZIP right now.";
  return out;
}

function buildMetarCacheKey(required numeric lat, required numeric lng) {
  var latVal = round(arguments.lat * 10000000) / 10000000;
  var lngVal = round(arguments.lng * 10000000) / 10000000;
  return "metar:v2:" & numberFormat(latVal, "0.0000000") & ":" & numberFormat(lngVal, "0.0000000");
}
</cfscript>

<cfparam name="form.zip" default="11234">
<cfparam name="form.station" default="KSEED">
<cfparam name="form.altim" default="29.90">
<cfparam name="form.visib" default="10.0">
<cfparam name="form.obs_minutes_ago" default="60">
<cfparam name="form.cache_minutes_ago" default="20">

<cfset localRun = structKeyExists(form, "run_seed")>
<cfset localOut = {
  "ran"=localRun,
  "success"=false,
  "message"="",
  "zip"=normalizeZip(form.zip),
  "lat"=0,
  "lng"=0,
  "cache_key"="",
  "seed_observation_time"="",
  "cache_item_ts"=""
}>

<cfif localRun>
  <cfset geo = geocodeZipQuick(form.zip)>
  <cfif NOT geo.success>
    <cfset localOut.message = geo.message>
  <cfelse>
    <cfset localOut.lat = geo.lat>
    <cfset localOut.lng = geo.lng>
    <cfset localOut.cache_key = buildMetarCacheKey(geo.lat, geo.lng)>
    <cfset seedObsDt = dateAdd("n", -abs(int(val(form.obs_minutes_ago))), now())>
    <cfset cacheTs = dateAdd("n", -abs(int(val(form.cache_minutes_ago))), now())>
    <cfset seedPayload = {
      "success"=true,
      "source"="METAR",
      "current"={
        "station"=left(trim(toString(form.station)), 12),
        "altim"=numberFormat(val(form.altim), "0.00"),
        "visib"=numberFormat(val(form.visib), "0.0"),
        "observation_time"=dateTimeFormat(seedObsDt, "yyyy-mm-dd HH:nn:ss")
      },
      "previous"={}
    }>

    <cflock scope="application" type="exclusive" timeout="10">
      <cfif NOT structKeyExists(application, "weatherCache") OR NOT isStruct(application.weatherCache)>
        <cfset application.weatherCache = {}>
      </cfif>
      <cfset application.weatherCache[ localOut.cache_key ] = {
        "ts"=cacheTs,
        "val"=seedPayload
      }>
    </cflock>

    <cfset localOut.success = true>
    <cfset localOut.message = "Seeded prior METAR cache sample. Now fetch live weather to compute trend immediately.">
    <cfset localOut.seed_observation_time = seedPayload.current.observation_time>
    <cfset localOut.cache_item_ts = dateTimeFormat(cacheTs, "yyyy-mm-dd HH:nn:ss")>
  </cfif>
</cfif>

<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Admin METAR Trend Seed Test</title>
  <style>
    body { font-family: Arial, sans-serif; margin: 24px; background: #f7f7f7; color: #111; }
    .wrap { max-width: 1220px; margin: 0 auto; background: #fff; border: 1px solid #ddd; border-radius: 8px; padding: 20px; }
    .admin-nav { display: flex; gap: 8px; margin-bottom: 14px; flex-wrap: wrap; }
    .admin-nav a { text-decoration: none; border: 1px solid #bbb; background: #f5f5f5; color: #222; padding: 6px 10px; border-radius: 4px; font-size: 14px; }
    .admin-nav a.active { background: #111; border-color: #111; color: #fff; }
    h1 { margin-top: 0; font-size: 24px; }
    .hint { color: #444; margin-bottom: 16px; }
    .grid { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 12px; }
    .field { display: flex; flex-direction: column; gap: 6px; }
    .field label { font-size: 13px; font-weight: 700; color: #222; }
    .field input {
      border: 1px solid #bbb;
      border-radius: 4px;
      font-size: 14px;
      padding: 8px;
      background: #fff;
      color: #111;
    }
    .actions { margin-top: 14px; }
    button {
      padding: 8px 12px;
      border-radius: 4px;
      border: 1px solid #111;
      background: #111;
      color: #fff;
      cursor: pointer;
      font-size: 14px;
    }
    .msg { margin-top: 12px; padding: 10px; border-radius: 4px; }
    .msg.ok { background: #ebfff4; border: 1px solid #9fd7b2; }
    .msg.err { background: #fff0f0; border: 1px solid #e6a6a6; }
    table { width: 100%; border-collapse: collapse; margin-top: 16px; font-size: 14px; }
    th, td { border: 1px solid #ddd; padding: 8px; text-align: left; vertical-align: top; }
    th { background: #f0f0f0; width: 220px; }
    pre {
      margin-top: 16px;
      background: #111;
      color: #f4f4f4;
      padding: 12px;
      border-radius: 6px;
      overflow: auto;
      font-size: 12px;
      line-height: 1.45;
      max-height: 440px;
    }
    .stack { margin-top: 18px; }
    @media (max-width: 960px) {
      .grid { grid-template-columns: 1fr; }
    }
  </style>
</head>
<body>
  <div class="wrap">
    <nav class="admin-nav" aria-label="Admin Tools">
      <a href="/fpw/admin/floatplan-cleanup.cfm">FloatPlan Cleanup</a>
      <a href="/fpw/admin/route-cleanup.cfm">Route Cleanup</a>
      <a href="/fpw/admin/fuel-calculator.cfm">Fuel Calculator</a>
      <a href="/fpw/admin/waypoint-manager.cfm">Waypoint Manager</a>
      <a href="/fpw/admin/metar-seed-test.cfm" class="active">METAR Seed Test</a>
    </nav>

    <h1>METAR Trend Seed Test</h1>
    <p class="hint">Seeds a stale prior METAR sample in server cache, then fetches live weather API response so <code>DATA.surface.pressure_rate_per_hr</code> can populate immediately.</p>

    <form method="post" action="/fpw/admin/metar-seed-test.cfm">
      <div class="grid">
        <div class="field">
          <label for="zip">ZIP</label>
          <input id="zip" name="zip" type="text" value="<cfoutput>#encodeForHtmlAttribute(form.zip)#</cfoutput>">
        </div>
        <div class="field">
          <label for="station">Seed station id</label>
          <input id="station" name="station" type="text" value="<cfoutput>#encodeForHtmlAttribute(form.station)#</cfoutput>">
        </div>
        <div class="field">
          <label for="altim">Seed pressure (inHg)</label>
          <input id="altim" name="altim" type="number" step="0.01" value="<cfoutput>#encodeForHtmlAttribute(form.altim)#</cfoutput>">
        </div>
        <div class="field">
          <label for="visib">Seed visibility (mi)</label>
          <input id="visib" name="visib" type="number" step="0.1" value="<cfoutput>#encodeForHtmlAttribute(form.visib)#</cfoutput>">
        </div>
        <div class="field">
          <label for="obs_minutes_ago">Seed obs minutes ago</label>
          <input id="obs_minutes_ago" name="obs_minutes_ago" type="number" step="1" value="<cfoutput>#encodeForHtmlAttribute(form.obs_minutes_ago)#</cfoutput>">
        </div>
        <div class="field">
          <label for="cache_minutes_ago">Cache item minutes ago (must be >15)</label>
          <input id="cache_minutes_ago" name="cache_minutes_ago" type="number" step="1" value="<cfoutput>#encodeForHtmlAttribute(form.cache_minutes_ago)#</cfoutput>">
        </div>
      </div>

      <div class="actions">
        <button type="submit" name="run_seed" value="1">Seed Prior Sample + Fetch Live Surface</button>
      </div>
    </form>

    <cfif localOut.ran>
      <div class="msg <cfif localOut.success>ok<cfelse>err</cfif>">
        <cfoutput>#encodeForHtml(localOut.message)#</cfoutput>
      </div>

      <table>
        <tr><th>ZIP</th><td><cfoutput>#encodeForHtml(localOut.zip)#</cfoutput></td></tr>
        <tr><th>Lat</th><td><cfoutput>#localOut.lat#</cfoutput></td></tr>
        <tr><th>Lng</th><td><cfoutput>#localOut.lng#</cfoutput></td></tr>
        <tr><th>Cache key</th><td><cfoutput>#encodeForHtml(localOut.cache_key)#</cfoutput></td></tr>
        <tr><th>Seed observation_time</th><td><cfoutput>#encodeForHtml(localOut.seed_observation_time)#</cfoutput></td></tr>
        <tr><th>Cache item timestamp</th><td><cfoutput>#encodeForHtml(localOut.cache_item_ts)#</cfoutput></td></tr>
      </table>

      <cfif localOut.success>
        <div class="stack" id="liveFetchBox" data-zip="<cfoutput>#encodeForHtmlAttribute(localOut.zip)#</cfoutput>">
          <h2>Live API Result</h2>
          <p class="hint">This calls <code>/fpw/api/v1/weather.cfc?action=zip&amp;zip=...</code> using your current session and dumps <code>DATA.surface</code>.</p>
          <table>
            <tbody id="surfaceRows">
              <tr><th>Status</th><td>Fetching...</td></tr>
            </tbody>
          </table>
          <pre id="surfaceJsonDump">Fetching...</pre>
        </div>
      </cfif>
    </cfif>
  </div>

  <script>
    (function () {
      var liveBox = document.getElementById("liveFetchBox");
      if (!liveBox) return;

      var zip = liveBox.getAttribute("data-zip") || "";
      var tbody = document.getElementById("surfaceRows");
      var dumpEl = document.getElementById("surfaceJsonDump");

      function esc(v) {
        return String(v)
          .replace(/&/g, "&amp;")
          .replace(/</g, "&lt;")
          .replace(/>/g, "&gt;")
          .replace(/\"/g, "&quot;")
          .replace(/'/g, "&#39;");
      }

      function fmt(v) {
        if (v === null || v === undefined || v === "") return "";
        if (typeof v === "object") return JSON.stringify(v);
        return String(v);
      }

      function row(k, v) {
        return "<tr><th>" + esc(k) + "</th><td>" + esc(fmt(v)) + "</td></tr>";
      }

      function renderSurface(surface, statusTxt) {
        var html = row("status", statusTxt || "ok");
        if (!surface || typeof surface !== "object") {
          html += row("surface", "not returned");
        } else {
          Object.keys(surface).forEach(function (k) {
            html += row(k, surface[k]);
          });
        }
        tbody.innerHTML = html;
      }

      fetch("/fpw/api/v1/weather.cfc?action=zip&zip=" + encodeURIComponent(zip) + "&marineMode=quick", {
        credentials: "same-origin",
        headers: { "Accept": "application/json" }
      })
        .then(function (res) {
          return res.json();
        })
        .then(function (payload) {
          var data = payload && payload.DATA ? payload.DATA : {};
          var surface = data && data.surface ? data.surface : null;
          renderSurface(surface, (payload && payload.SUCCESS) ? "SUCCESS" : (payload && payload.MESSAGE ? payload.MESSAGE : "failed"));
          dumpEl.textContent = JSON.stringify(payload, null, 2);
        })
        .catch(function (err) {
          renderSurface(null, "ERROR: " + (err && err.message ? err.message : "fetch failed"));
          dumpEl.textContent = String(err && err.message ? err.message : err);
        });
    })();
  </script>
</body>
</html>
