<cfscript>
request.fpwBase = getDirectoryFromPath(cgi.script_name);
request.fpwBase = reReplace(request.fpwBase, "/app/?$", "");
request.fpwBase = reReplace(request.fpwBase, "/$", "");
if (request.fpwBase == "/") {
    request.fpwBase = "";
}
</cfscript>
<cfparam name="url.slug" default="">
<cfparam name="url.t" default="">
<cfparam name="url.stream_id" default="0">
<cfset followFallbackPath = request.fpwBase & "/app/follow.cfm">
<cfif len(trim(url.slug))>
  <cfset followFallbackPath &= "?slug=" & urlEncodedFormat(trim(url.slug))>
  <cfif len(trim(url.t))>
    <cfset followFallbackPath &= "&t=" & urlEncodedFormat(trim(url.t))>
  </cfif>
  <cfif val(url.stream_id) GT 0>
    <cfset followFallbackPath &= "&stream_id=" & urlEncodedFormat(val(url.stream_id))>
  </cfif>
</cfif>
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width,initial-scale=1" />
  <title>FloatPlanWizard - Follow Full Map</title>

  <cfinclude template="../includes/header_styles.cfm">
  <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" integrity="sha256-p4NxAoJBhIIN+hmNHrzRCf9tD/miZyoHS5obTRR9BMY=" crossorigin="" />
  <link rel="stylesheet" href="<cfoutput>#request.fpwBase#</cfoutput>/assets/css/follow.css?v=202604141447a" />
  <style>
    html,
    body {
      margin: 0;
      min-height: 100%;
      background: #081420;
      color: #e8f1f8;
      font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
    }

    .follow-full-map-page {
      min-height: 100vh;
    }

    .follow-full-map-shell {
      min-height: 100vh;
      display: flex;
      flex-direction: column;
      gap: 12px;
      padding: 18px;
      box-sizing: border-box;
    }

    .follow-full-map-header {
      display: flex;
      align-items: flex-start;
      justify-content: space-between;
      gap: 16px;
      padding-right: 128px;
    }

    .follow-full-map-kicker {
      margin: 0 0 6px;
      font-size: 12px;
      font-weight: 700;
      letter-spacing: 0.16em;
      text-transform: uppercase;
      color: #98c4ff;
    }

    .follow-full-map-title {
      margin: 0;
      font-size: 32px;
      line-height: 1.05;
    }

    .follow-full-map-subtitle {
      margin: 6px 0 0;
      color: #bfd0de;
      font-size: 15px;
    }

    .follow-full-map-stage {
      position: relative;
      flex: 1 1 auto;
      min-height: 0;
      border-radius: 22px;
      overflow: hidden;
      border: 1px solid rgba(160, 184, 204, 0.28);
      background: #0d1d2e;
      box-shadow: 0 24px 60px rgba(0, 0, 0, 0.35);
    }

    .follow-full-map-canvas {
      height: 100%;
      min-height: calc(100vh - 140px);
      border: 0;
      border-radius: 0;
    }

    .follow-full-map-actions {
      position: fixed;
      top: 18px;
      right: 18px;
      z-index: 1200;
      display: flex;
      flex-direction: column;
      align-items: flex-end;
      gap: 8px;
    }

    .follow-full-map-close {
      width: 64px;
      height: 64px;
      border: 0;
      border-radius: 999px;
      background: rgba(7, 16, 28, 0.94);
      color: #ffffff;
      font-size: 40px;
      line-height: 1;
      cursor: pointer;
      box-shadow: 0 10px 30px rgba(0, 0, 0, 0.32);
    }

    .follow-full-map-close:hover,
    .follow-full-map-close:focus-visible {
      background: rgba(15, 34, 58, 0.98);
      outline: 2px solid #8ec5ff;
      outline-offset: 2px;
    }

    .follow-full-map-backlink {
      display: inline-flex;
      align-items: center;
      justify-content: center;
      min-height: 42px;
      padding: 0 16px;
      border-radius: 999px;
      background: rgba(7, 16, 28, 0.92);
      color: #ffffff;
      text-decoration: none;
      font-size: 14px;
      font-weight: 600;
      box-shadow: 0 10px 30px rgba(0, 0, 0, 0.24);
    }

    .follow-full-map-backlink:hover,
    .follow-full-map-backlink:focus-visible {
      color: #ffffff;
      background: rgba(15, 34, 58, 0.98);
      outline: 2px solid #8ec5ff;
      outline-offset: 2px;
    }

    .follow-full-map-status {
      position: absolute;
      left: 18px;
      bottom: 18px;
      z-index: 900;
      max-width: min(440px, calc(100% - 36px));
      padding: 12px 14px;
      border-radius: 14px;
      background: rgba(7, 16, 28, 0.86);
      color: #dfe8ef;
      font-size: 14px;
      box-shadow: 0 10px 30px rgba(0, 0, 0, 0.22);
    }

    #followFullMap .radar-opacity-control {
      background: rgba(255, 255, 255, 0.92);
      padding: 0.35rem 0.5rem;
      border-radius: 0.5rem;
      box-shadow: 0 4px 12px rgba(0,0,0,0.15);
      font-size: 0.7rem;
      min-width: 140px;
    }

    #followFullMap .radar-opacity-control label {
      display: block;
      font-weight: 600;
      margin-bottom: 0.25rem;
      color: #1b1b1b;
    }

    #followFullMap .radar-opacity-control input[type="range"] {
      width: 100%;
    }

    #followFullMap .radar-opacity-control.is-disabled {
      opacity: 0.5;
      pointer-events: none;
    }

    @media (max-width: 740px) {
      .follow-full-map-shell {
        padding: 14px;
      }

      .follow-full-map-header {
        padding-right: 0;
        gap: 10px;
      }

      .follow-full-map-title {
        font-size: 24px;
      }

      .follow-full-map-actions {
        top: 14px;
        right: 14px;
      }

      .follow-full-map-close {
        width: 56px;
        height: 56px;
        font-size: 34px;
      }

      .follow-full-map-backlink {
        font-size: 13px;
      }

      .follow-full-map-canvas {
        min-height: calc(100vh - 124px);
      }
    }
  </style>
</head>
<body class="follow-full-map-page">
  <div class="follow-full-map-actions">
    <button class="follow-full-map-close" id="closeFullMapBtn" type="button" aria-label="Close full map">&times;</button>
    <a class="follow-full-map-backlink" id="backToFollowPageLink" href="<cfoutput>#followFallbackPath#</cfoutput>">Back to Follow Page</a>
  </div>

  <div class="follow-full-map-shell">
    <header class="follow-full-map-header">
      <div>
        <p class="follow-full-map-kicker">Follow Full Map</p>
        <h1 class="follow-full-map-title" id="followFullMapTitle">Loading route map…</h1>
        <p class="follow-full-map-subtitle" id="followFullMapSubtitle">Opening the live route map in a dedicated window.</p>
      </div>
    </header>

    <main class="follow-full-map-stage">
      <div id="followFullMap" class="map-canvas follow-full-map-canvas" aria-label="Full-screen voyage route map"></div>
      <div class="follow-full-map-status" id="followFullMapStatus">Preparing the live route map.</div>
    </main>
  </div>

  <script id="followFullMapContext" type="application/json"><cfoutput>{"fpwBase":"#JSStringFormat(request.fpwBase)#","fallbackFollowUrl":"#JSStringFormat(followFallbackPath)#"}</cfoutput></script>

  <cfinclude template="../includes/footer_scripts.cfm">
  <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js" integrity="sha256-20nQCchB9co0qIjJZRGuk2/Z9VM+kNiyxNV1lvTlZBo=" crossorigin=""></script>
  <script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/maps/leaflet-noaa-waypoint-map.js?v=20260416a"></script>
  <script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/app/follow/followMap.js?v=202604131858a"></script>
  <script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/app/follow/followFullMap.js?v=20260417a"></script>
</body>
</html>
