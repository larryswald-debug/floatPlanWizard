<!DOCTYPE html>
<!-- Updated to host the float plan wizard inside a Bootstrap modal. -->
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Dashboard - Float Plan Wizard</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">

    <cfinclude template="../includes/header_styles.cfm">
    <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" integrity="sha256-p4NxAoJBhIIN+hmNHrzRCf9tD/miZyoHS5obTRR9BMY=" crossorigin="">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/leaflet.draw/1.0.4/leaflet.draw.css">
    <link rel="stylesheet" href="<cfoutput>#request.fpwBase#</cfoutput>/assets/css/dashboard-console.css?v=20260302f">
</head>
<body class="dashboard-body">

<cfinclude template="../includes/top_nav.cfm">


<main class="dashboard-main">
    <div id="dashboardAlert" class="alert d-none" role="alert"></div>

    <div class="dashboard-grid">

        
        <section class="fpw-card fpw-alerts" aria-label="System Alerts">
            <div class="fpw-card__header">
                <div class="fpw-card__title">
                    <span class="fpw-alerts__icon" aria-hidden="true">!</span>
                    <h2>Weather</h2>
                    <button class="fpw-caret collapsed" type="button" data-bs-toggle="collapse" data-bs-target="#alertsCollapse" aria-expanded="false" aria-controls="alertsCollapse">
                        <span class="fpw-caret__icon" aria-hidden="true">></span>
                    </button>
                    <div class="fpw-wx__titleRow fpw-wx__titleRow--header">
                      <span id="weatherProviderBadge" class="fpw-wx__badge">NOAA/NWS</span>
                      <h3 id="weatherPanelTitle" class="fpw-wx__title">—</h3>
                      <span id="weatherUpdatedAt" class="fpw-wx__pill d-none">Updated: —</span>
                      <div id="weatherSummary" class="fpw-wx__summary fpw-wx__summary--header">
                        Enter a ZIP code to load your local forecast.
                      </div>
                    </div>
                </div>
                <div class="fpw-card__actions fpw-card__actions--weather">
                    <div class="fpw-wx__topRight fpw-wx__topRight--header">
                        <div class="fpw-wx__zipBlock">
                          <label for="weatherZip" class="fpw-wx__zipLabel">ZIP</label>
                          <input
                            id="weatherZip"
                            type="text"
                            inputmode="numeric"
                            pattern="[0-9]{5}"
                            maxlength="5"
                            class="form-control form-control-sm fpw-wx__zipInput"
                            aria-describedby="weatherZipHelp"
                          />
                          <div id="weatherZipHelp" class="form-text small">Temp (not saved)</div>
                        </div>

                        <button id="weatherRefreshBtn" class="btn btn-sm btn-primary fpw-wx__updateBtn" type="button">
                          Update
                        </button>

                        <a id="weatherDetailsLink" class="btn btn-sm btn-outline-secondary fpw-wx__detailsBtn d-none" href="#" target="_blank" rel="noopener">
                          Details
                        </a>
                    </div>
                </div>
            </div>

            <div id="alertsCollapse" class="collapse">
                <div class="fpw-card__body">

  <!-- Weather Panel (Cockpit / ZIP-based) -->
  <section class="fpw-weather-cockpit wx-panel wx-panel--cockpit" aria-labelledby="weatherPanelTitle">

    <!-- Loading / Error -->
    <div id="weatherLoading" class="fpw-wx__pill d-none">Loading weather…</div>
    <div id="weatherError" class="alert alert-warning d-none mb-3" role="alert"></div>

    <!-- Main Cockpit -->
    <div class="fpw-wx__main">

      <!-- Wind Dial (Hero) -->
      <div class="fpw-wx__panel fpw-wx__wind">
        <div class="fpw-wx__panelHeader">
          <div class="fpw-wx__panelTitle">Wind</div>
          <div class="fpw-wx__panelMeta">
            <span id="weatherNowWhen" class="fpw-wx__muted">Now</span>
          </div>
        </div>

        <div class="fpw-wx__dial" role="img" aria-label="Wind direction and speed">
          <div class="fpw-wx__compass">
            <div class="fpw-wx__compassTicks" aria-hidden="true"></div>
            <div id="weatherWindNeedle" class="fpw-wx__needle fpw-wx__needleDefault"></div>
            <div id="weatherGustHalo" class="fpw-wx__gustHalo" aria-hidden="true"></div>

            <div class="fpw-wx__dialCenter">
              <div id="weatherWindSpeed" class="fpw-wx__dialSpeed">—</div>
              <div class="fpw-wx__dialSub">
                <span id="weatherWindDir" class="fpw-wx__dialDir">—</span>
                <span class="fpw-wx__sep">•</span>
                <span id="weatherWindGust" class="fpw-wx__dialGust">Gust —</span>
              </div>
              <div id="weatherWindCond" class="fpw-wx__dialCond">—</div>
            </div>

            <div class="fpw-wx__cardinals" aria-hidden="true">
              <span class="n">N</span><span class="e">E</span><span class="s">S</span><span class="w">W</span>
            </div>
          </div>
        </div>

        <div class="fpw-wx__miniRow">
          <div class="fpw-wx__miniStat">
            <div class="fpw-wx__miniLabel">Risk</div>
            <div id="weatherRiskLabel" class="fpw-wx__miniValue">—</div>
          </div>
          <div class="fpw-wx__miniStat">
            <div class="fpw-wx__miniLabel">Alerts</div>
            <div id="weatherAlertLabel" class="fpw-wx__miniValue">—</div>
          </div>
        </div>
      </div>

      <!-- Risk Timeline -->
      <div class="fpw-wx__panel fpw-wx__timeline">
        <div class="fpw-wx__panelHeader">
          <div class="fpw-wx__panelTitle">Next 12 hours</div>
          <div class="fpw-wx__panelMeta">
            <span id="weatherHiLo" class="fpw-wx__muted"></span>
            <span id="weatherPlanPill" class="fpw-wx__pill d-none">Plan window: —</span>
          </div>
        </div>

        <div class="fpw-wx__timelineGrid">
          <div class="fpw-wx__timelineLegend">
            <div><span class="swatch wind"></span>Wind</div>
            <div><span class="swatch gust"></span>Gust</div>
            <div><span class="swatch rain"></span>Rain</div>
            <div><span class="swatch alert"></span>Alerts</div>
          </div>

          <div class="fpw-wx__timelineBars" aria-label="Risk timeline">
            <div class="fpw-wx__timelineStage">
              <div id="weatherPlanOverlay" class="fpw-wx__planOverlay d-none" aria-hidden="true"></div>
              <div id="weatherTimeline" class="fpw-wx__bars"></div>
            </div>
          </div>
        </div>

        <div id="tideGraph" class="fpw-wx__tideGraph d-none" aria-label="Tide graph">
          <div class="fpw-wx__tideTitle">
            <span id="tideGraphTitle">Tide (ft)</span>
            <span id="tideGraphNowValue" class="fpw-wx__tideNow">Now —</span>
            <span id="tideGraphStation" class="fpw-wx__muted"></span>
          </div>
          <svg id="tideGraphSvg" class="fpw-wx__tideSvg" viewBox="0 0 320 84" preserveAspectRatio="xMidYMid meet" aria-hidden="true"></svg>
          <div class="fpw-wx__tideAxis">
            <span id="tideGraphStart">—</span>
            <span class="fpw-wx__tideAxisCenter" aria-hidden="true"></span>
            <span id="tideGraphEnd">—</span>
          </div>
          <div id="tideGraphEmpty" class="fpw-wx__tideEmpty d-none">Tide data unavailable.</div>
        </div>

        <div id="weatherAlertsEmpty" class="fpw-wx__alertsEmpty d-none">
          No active marine alerts.
        </div>

        <ul id="weatherAlertsList" class="fpw-wx__alertsList">
          <!-- JS renders alert items (max 2) -->
        </ul>
      </div>

    </div>

    <!-- Instruments -->
    <div class="fpw-wx__instruments wx-row">

      <!-- Gust Spikes -->
      <div class="fpw-wx__gauge wx-card fpw-wx__gusts">
        <div class="fpw-wx__gaugeTop wx-card__head">
          <div class="fpw-wx__gaugeLabel">Gusts</div>
          <div id="weatherGustValue" class="fpw-wx__gaugeValue">—</div>
        </div>
        <div class="fpw-wx__spikes wx-card__viz" aria-label="Gust spikes">
          <div id="weatherGustSpikes" class="fpw-wx__spikeBars"></div>
          <div id="weatherGustLabels" class="fpw-wx__spikeLabels" aria-hidden="true"></div>
        </div>
        <div class="fpw-wx__gaugeFoot wx-card__foot fpw-wx__muted">Gust forecast for next 12 hours</div>
      </div>

      <!-- Wave Height -->
      <div class="fpw-wx__gauge wx-card cockpit-card wave-card sea-radar-card wave-calm" data-severity="calm">
        <div class="sea-radar-head wx-card__head">
          <div id="seaWaveTitleLabel" class="card-label">WAVE HEIGHT</div>
        </div>

        <div class="sea-radar-shell wx-card__viz">
          <svg class="sea-radar-svg" viewBox="0 0 760 430" aria-hidden="true">
            <defs>
              <linearGradient id="seaNeedleGlowGrad" x1="0%" y1="0%" x2="100%" y2="100%">
                <stop offset="0%" stop-color="rgba(130,244,255,.96)"></stop>
                <stop offset="100%" stop-color="rgba(39,188,255,.86)"></stop>
              </linearGradient>
              <linearGradient id="seaWaveFrontGrad" x1="0%" y1="0%" x2="100%" y2="0%">
                <stop offset="0%" stop-color="rgba(54,210,255,.18)"></stop>
                <stop offset="50%" stop-color="rgba(78,228,255,.50)"></stop>
                <stop offset="100%" stop-color="rgba(54,210,255,.18)"></stop>
              </linearGradient>
              <linearGradient id="seaWaveBackGrad" x1="0%" y1="0%" x2="100%" y2="0%">
                <stop offset="0%" stop-color="rgba(44,164,255,.14)"></stop>
                <stop offset="50%" stop-color="rgba(73,198,255,.30)"></stop>
                <stop offset="100%" stop-color="rgba(44,164,255,.14)"></stop>
              </linearGradient>
              <clipPath id="seaRadarWaveMask">
                <path d="M152 336 Q380 214 608 336 L608 398 L152 398 Z"></path>
              </clipPath>
            </defs>

            <path class="sea-radar-outer-frame" d="M96 304 A284 284 0 0 1 664 304"></path>
            <path class="sea-radar-outer-glow" d="M96 304 A284 284 0 0 1 664 304"></path>
            <path class="sea-radar-track" d="M120 304 A260 260 0 0 1 640 304"></path>

            <path class="sea-radar-zone zone-calm" d="M120 304 A260 260 0 0 1 196.15 120.15"></path>
            <path class="sea-radar-zone zone-moderate" d="M196.15 120.15 A260 260 0 0 1 380 44"></path>
            <path class="sea-radar-zone zone-rough" d="M380 44 A260 260 0 0 1 563.85 120.15"></path>
            <path class="sea-radar-zone zone-severe" d="M563.85 120.15 A260 260 0 0 1 640 304"></path>

            <g id="seaRadarTicks">
              <line class="tick major" x1="120" y1="304" x2="145" y2="304"></line>
              <line class="tick major" x1="196.15" y1="120.15" x2="213.82" y2="137.82"></line>
              <line class="tick major" x1="380" y1="44" x2="380" y2="69"></line>
              <line class="tick major" x1="563.85" y1="120.15" x2="546.18" y2="137.82"></line>
              <line class="tick major" x1="640" y1="304" x2="615" y2="304"></line>

              <line class="tick minor" x1="154.39" y1="220.96" x2="167.33" y2="226.32"></line>
              <line class="tick minor" x1="270.08" y1="82.79" x2="277.15" y2="95.04"></line>
              <line class="tick minor" x1="489.92" y1="82.79" x2="482.85" y2="95.04"></line>
              <line class="tick minor" x1="605.61" y1="220.96" x2="592.67" y2="226.32"></line>
            </g>

            <g id="seaRadarGrid">
              <path class="grid-ring" d="M166 304 A214 214 0 0 1 594 304"></path>
              <path class="grid-ring" d="M210 304 A170 170 0 0 1 550 304"></path>
              <path class="grid-ring" d="M250 304 A130 130 0 0 1 510 304"></path>
              <path class="grid-ring" d="M292 304 A88 88 0 0 1 468 304"></path>
              <line class="grid-ray" x1="380" y1="304" x2="120" y2="304"></line>
              <line class="grid-ray" x1="380" y1="304" x2="196.15" y2="120.15"></line>
              <line class="grid-ray" x1="380" y1="304" x2="380" y2="44"></line>
              <line class="grid-ray" x1="380" y1="304" x2="563.85" y2="120.15"></line>
              <line class="grid-ray" x1="380" y1="304" x2="640" y2="304"></line>
            </g>

            <g id="seaWaveLayer" clip-path="url(#seaRadarWaveMask)">
              <g id="seaWaveAmp">
                <g id="seaWaveBackTrack" class="sea-wave-track sea-wave-back-track">
                  <path class="sea-wave-back" d="M-140 338 C-92 322 -50 354 -2 338 C46 322 88 354 136 338 C184 322 226 354 274 338 C322 322 364 354 412 338 C460 322 502 354 550 338 C598 322 640 354 688 338 C736 322 778 354 826 338 L826 430 L-140 430 Z"></path>
                  <path class="sea-wave-back" d="M140 338 C188 322 230 354 278 338 C326 322 368 354 416 338 C464 322 506 354 554 338 C602 322 644 354 692 338 C740 322 782 354 830 338 C878 322 920 354 968 338 L968 430 L140 430 Z"></path>
                </g>
                <g id="seaWaveFrontTrack" class="sea-wave-track sea-wave-front-track">
                  <path class="sea-wave-front" d="M-140 346 C-92 328 -50 362 -2 346 C46 328 88 362 136 346 C184 328 226 362 274 346 C322 328 364 362 412 346 C460 328 502 362 550 346 C598 328 640 362 688 346 C736 328 778 362 826 346 L826 430 L-140 430 Z"></path>
                  <path class="sea-wave-front" d="M140 346 C188 328 230 362 278 346 C326 328 368 362 416 346 C464 328 506 362 554 346 C602 328 644 362 692 346 C740 328 782 362 830 346 C878 328 920 362 968 346 L968 430 L140 430 Z"></path>
                </g>
              </g>
            </g>

            <path class="sea-radar-bowl" d="M152 336 Q380 214 608 336 L608 398 L152 398 Z"></path>

            <g id="seaNeedle" class="sea-radar-needle">
              <line class="sea-radar-needle-line" x1="380" y1="304" x2="380" y2="44"></line>
              <circle class="sea-radar-needle-tip-glow" cx="380" cy="44" r="14"></circle>
              <circle class="sea-radar-needle-tip" cx="380" cy="44" r="8"></circle>
              <circle class="sea-radar-hub" cx="380" cy="304" r="25"></circle>
              <circle class="sea-radar-hub-core" cx="380" cy="304" r="11"></circle>
            </g>

          </svg>

          <div class="sea-radar-readout">
            <span id="wxWaveHeight">--</span>
            <span class="unit">ft</span>
          </div>
          <div class="sea-radar-current">CURRENT SEAS</div>
        </div>

        <div class="sea-radar-metrics wx-card__foot">
          <div class="sea-metric">
            <div class="m-label">BEAUFORT</div>
            <div id="seaBeaufortLevel" class="m-value">Level --</div>
          </div>
          <div class="sea-metric">
            <div class="m-label">WAVE PERIOD</div>
            <div id="seaWavePeriodValue" class="m-value">--</div>
          </div>
          <div class="sea-metric">
            <div class="m-label">DIRECTION</div>
            <div id="seaWaveDirectionValue" class="m-value">--</div>
          </div>
          <div class="sea-metric">
            <div class="m-label">TREND</div>
            <div id="seaWaveTrendValue" class="m-value">STEADY</div>
          </div>
        </div>
      </div>

      <!-- Pressure -->
      <div class="fpw-wx__gauge wx-card fpw-wx__pressure pressure-card" data-trend="steady">
        <div class="pressure-head wx-card__head">
          <div class="pressure-label">PRESSURE</div>
          <div class="pressure-readout">
            <span class="pressure-value" id="weatherPressureValue">—</span>
            <span class="pressure-unit">inHg</span>
          </div>
        </div>

        <div class="pressure-sub wx-card__value" id="weatherPressureTrendRow">
          <div class="pressure-trend">
            <span class="trend-arrow" id="weatherPressureTrend">→</span>
            <span class="trend-text" id="weatherPressureTrendLabel">Steady</span>
          </div>
          <div class="pressure-rate" id="weatherPressureRate">—</div>
        </div>

        <div class="pressure-dial-slot wx-card__viz">
          <div class="sea-radar-shell">
            <svg class="sea-radar-svg" viewBox="0 0 760 430" aria-hidden="true">
              <defs>
                <linearGradient id="pressureNeedleGlowGrad" x1="0%" y1="0%" x2="100%" y2="100%">
                  <stop offset="0%" stop-color="rgba(130,244,255,.96)"></stop>
                  <stop offset="100%" stop-color="rgba(39,188,255,.86)"></stop>
                </linearGradient>
                <linearGradient id="pressureWaveFrontGrad" x1="0%" y1="0%" x2="100%" y2="0%">
                  <stop offset="0%" stop-color="rgba(54,210,255,.18)"></stop>
                  <stop offset="50%" stop-color="rgba(78,228,255,.50)"></stop>
                  <stop offset="100%" stop-color="rgba(54,210,255,.18)"></stop>
                </linearGradient>
                <linearGradient id="pressureWaveBackGrad" x1="0%" y1="0%" x2="100%" y2="0%">
                  <stop offset="0%" stop-color="rgba(44,164,255,.14)"></stop>
                  <stop offset="50%" stop-color="rgba(73,198,255,.30)"></stop>
                  <stop offset="100%" stop-color="rgba(44,164,255,.14)"></stop>
                </linearGradient>
                <clipPath id="pressureRadarWaveMask">
                  <path d="M152 336 Q380 214 608 336 L608 398 L152 398 Z"></path>
                </clipPath>
              </defs>

              <path class="sea-radar-outer-frame" d="M96 304 A284 284 0 0 1 664 304"></path>
              <path class="sea-radar-outer-glow" d="M96 304 A284 284 0 0 1 664 304"></path>
              <path class="sea-radar-track" d="M120 304 A260 260 0 0 1 640 304"></path>

              <path class="sea-radar-zone zone-calm" d="M120 304 A260 260 0 0 1 196.15 120.15"></path>
              <path class="sea-radar-zone zone-moderate" d="M196.15 120.15 A260 260 0 0 1 380 44"></path>
              <path class="sea-radar-zone zone-rough" d="M380 44 A260 260 0 0 1 563.85 120.15"></path>
              <path class="sea-radar-zone zone-severe" d="M563.85 120.15 A260 260 0 0 1 640 304"></path>

              <g id="pressureRadarTicks">
                <line class="tick major" x1="120" y1="304" x2="145" y2="304"></line>
                <line class="tick major" x1="196.15" y1="120.15" x2="213.82" y2="137.82"></line>
                <line class="tick major" x1="380" y1="44" x2="380" y2="69"></line>
                <line class="tick major" x1="563.85" y1="120.15" x2="546.18" y2="137.82"></line>
                <line class="tick major" x1="640" y1="304" x2="615" y2="304"></line>

                <line class="tick minor" x1="154.39" y1="220.96" x2="167.33" y2="226.32"></line>
                <line class="tick minor" x1="270.08" y1="82.79" x2="277.15" y2="95.04"></line>
                <line class="tick minor" x1="489.92" y1="82.79" x2="482.85" y2="95.04"></line>
                <line class="tick minor" x1="605.61" y1="220.96" x2="592.67" y2="226.32"></line>
              </g>

              <g id="pressureRadarGrid">
                <path class="grid-ring" d="M166 304 A214 214 0 0 1 594 304"></path>
                <path class="grid-ring" d="M210 304 A170 170 0 0 1 550 304"></path>
                <path class="grid-ring" d="M250 304 A130 130 0 0 1 510 304"></path>
                <path class="grid-ring" d="M292 304 A88 88 0 0 1 468 304"></path>
                <line class="grid-ray" x1="380" y1="304" x2="120" y2="304"></line>
                <line class="grid-ray" x1="380" y1="304" x2="196.15" y2="120.15"></line>
                <line class="grid-ray" x1="380" y1="304" x2="380" y2="44"></line>
                <line class="grid-ray" x1="380" y1="304" x2="563.85" y2="120.15"></line>
                <line class="grid-ray" x1="380" y1="304" x2="640" y2="304"></line>
              </g>

              <g id="pressureWaveLayer" clip-path="url(#pressureRadarWaveMask)">
                <g id="pressureWaveAmp">
                  <g id="pressureWaveBackTrack" class="sea-wave-track sea-wave-back-track">
                    <path class="sea-wave-back" d="M-140 338 C-92 322 -50 354 -2 338 C46 322 88 354 136 338 C184 322 226 354 274 338 C322 322 364 354 412 338 C460 322 502 354 550 338 C598 322 640 354 688 338 C736 322 778 354 826 338 L826 430 L-140 430 Z"></path>
                    <path class="sea-wave-back" d="M140 338 C188 322 230 354 278 338 C326 322 368 354 416 338 C464 322 506 354 554 338 C602 322 644 354 692 338 C740 322 782 354 830 338 C878 322 920 354 968 338 L968 430 L140 430 Z"></path>
                  </g>
                  <g id="pressureWaveFrontTrack" class="sea-wave-track sea-wave-front-track">
                    <path class="sea-wave-front" d="M-140 346 C-92 328 -50 362 -2 346 C46 328 88 362 136 346 C184 328 226 362 274 346 C322 328 364 362 412 346 C460 328 502 362 550 346 C598 328 640 362 688 346 C736 328 778 362 826 346 L826 430 L-140 430 Z"></path>
                    <path class="sea-wave-front" d="M140 346 C188 328 230 362 278 346 C326 328 368 362 416 346 C464 328 506 362 554 346 C602 328 644 362 692 346 C740 328 782 362 830 346 C878 328 920 362 968 346 L968 430 L140 430 Z"></path>
                  </g>
                </g>
              </g>

              <path class="sea-radar-bowl" d="M152 336 Q380 214 608 336 L608 398 L152 398 Z"></path>

              <g id="pressureNeedle" class="sea-radar-needle">
                <line class="sea-radar-needle-line" x1="380" y1="304" x2="380" y2="44"></line>
                <circle class="sea-radar-needle-tip-glow" cx="380" cy="44" r="14"></circle>
                <circle class="sea-radar-needle-tip" cx="380" cy="44" r="8"></circle>
                <circle class="sea-radar-hub" cx="380" cy="304" r="25"></circle>
                <circle class="sea-radar-hub-core" cx="380" cy="304" r="11"></circle>
              </g>

            </svg>
          </div>
        </div>

        <div class="pressure-spark wx-card__foot" aria-hidden="true">
          <div class="spark-line" id="weatherPressureSparklineLine"></div>
        </div>
      </div>

      <!-- Visibility -->
      <div class="fpw-wx__gauge wx-card fpw-wx__vis">
        <div class="vis-horizon" id="visHorizon" data-vis-state="unknown">
          <div class="vis-hdr wx-card__head">
            <div class="vis-title">VISIBILITY</div>
            <div class="vis-readout">
              <div class="vis-value" id="visValue">— <span class="vis-unit">mi</span></div>
              <div class="vis-status" id="visStatus">UNKNOWN</div>
            </div>
          </div>

          <div class="vis-scene wx-card__viz" aria-label="Forward visibility scene">
            <div class="vis-fog" id="visFog"></div>

            <div class="vis-horizonLine"></div>

            <div class="vis-grid">
              <span class="vis-gridLine"></span><span class="vis-gridLine"></span><span class="vis-gridLine"></span>
              <span class="vis-gridLine"></span><span class="vis-gridLine"></span><span class="vis-gridLine"></span>
              <span class="vis-gridLine"></span><span class="vis-gridLine"></span>
            </div>

            <div class="vis-rangeText" id="visRangeText">Range: —</div>
          </div>

          <div class="vis-foot wx-card__foot" id="visFootnote">Based on latest METAR</div>
        </div>
      </div>

    </div>

    <!-- Confidence -->
    <div class="fpw-wx__confidence">
      <div class="fpw-wx__confidenceLabel">Forecast confidence</div>
      <div class="fpw-wx__confidenceBarWrap" aria-hidden="true">
        <div id="weatherConfidenceBar" class="fpw-wx__confidenceBar high fpw-wx__confidenceBarDefault82"></div>
      </div>
      <div id="weatherConfidenceText" class="fpw-wx__confidenceText">High</div>
    </div>

  </section>

</div>
            </div>
        </section>

        <section class="dashboard-card panel-floatlike full-width expedition-panel" id="expeditionTimelinePanel" aria-labelledby="expeditionTimelineTitle">
            <div class="card-header">
                <div class="card-title">
                    <h2 id="expeditionTimelineTitle"><span class="status-dot status-ok"></span>Expedition Timeline</h2>
                    <small id="expeditionTimelineSubtitle" class="card-subtitle">Great Loop (Counter-Clockwise)</small>
                </div>
                <div class="card-actions">
                    <button type="button" class="btn-secondary" id="openRouteBuilderBtn">Generate My Route</button>
                    <span id="expeditionTimelineSummary" class="card-subtitle numeric">Loading expedition timeline...</span>
                </div>
            </div>
            <div class="card-body">
                <div id="expeditionTimelineLoading" class="expedition-state mb-3" role="status">Loading expedition timeline...</div>

                <div id="expeditionTimelineUnauthorized" class="expedition-state d-none mb-3" role="alert">
                    Session expired. Please <a href="<cfoutput>#request.fpwBase#</cfoutput>/app/login.cfm">log in</a> to view your expedition timeline.
                </div>

                <div id="expeditionTimelineError" class="expedition-state d-none mb-3" role="alert">
                    <div id="expeditionTimelineErrorText">Unable to load expedition timeline.</div>
                    <button type="button" id="expeditionTimelineRetry" class="btn-secondary mt-2">Retry</button>
                </div>

                <div id="expeditionTimelineBody" class="d-none">
                    <div id="expeditionRouteList" class="expedition-route-list mb-3"></div>
                    <div id="expeditionRouteEmpty" class="expedition-state d-none mb-3">No routes yet. Click <strong>Generate My Route</strong> to create your first expedition route.</div>
                    <div id="expeditionTimelineAccordion" class="expedition-route-overview"></div>
                </div>
            </div>
        </section>
        
        <section class="dashboard-card hero-panel active" id="floatPlansPanel">
            <div class="card-header">
                <div class="card-title">
                    <h2><span class="status-dot status-ok"></span>Float Plans</h2>
                    <small class="card-subtitle" id="floatPlansSummary">Loading…</small>
                </div>
                <div class="card-actions">
                    <button class="btn-primary" type="button" id="addFloatPlanBtn">+ Add</button>
                </div>
            </div>
            <div class="card-body" id="floatPlansBody">
                <div class="d-flex flex-wrap align-items-center gap-2 mb-3" id="floatPlansFilterBar">
                    <div class="flex-grow-1" id="floatPlansFilterInputWrap">
                        <input type="text" id="floatPlansFilterInput" class="form-control" placeholder="Filter float plans…" autocomplete="off">
                    </div>
                    <small class="card-subtitle" id="floatPlansFilterCount">Showing 0 of 0</small>
                    <button type="button" class="btn-secondary" id="floatPlansFilterClear">Clear</button>
                </div>
                <p id="floatPlansMessage" class="empty">Loading float plans…</p>
                <div id="floatPlansList"></div>
            </div>
        </section>

        

        <section class="dashboard-card panel-floatlike" id="vesselsPanel">
            <div class="card-header">
                <div class="card-title">
                    <h2><span class="status-dot status-ok"></span>Vessels</h2>
                    <small class="card-subtitle" id="vesselsSummary">Loading…</small>
                </div>
                <div class="card-actions">
                    <button class="btn-primary" type="button" id="addVesselBtn">+ Add</button>
                </div>
            </div>
            <div class="card-body">
                <p id="vesselsMessage" class="empty">Loading vessels…</p>
                <div id="vesselsList"></div>
            </div>
        </section>

        <section class="dashboard-card panel-floatlike" id="contactsPanel">
            <div class="card-header">
                <div class="card-title">
                    <h2><span class="status-dot status-ok"></span>Contacts</h2>
                    <small class="card-subtitle" id="contactsSummary">Loading…</small>
                </div>
                <div class="card-actions">
                    <button class="btn-primary" id="addContactBtn">+ Add</button>
                </div>
            </div>
            <div class="card-body">
                <p id="contactsMessage" class="empty">Loading contacts…</p>
                <div id="contactsList"></div>
            </div>
        </section>

        <section class="dashboard-card panel-floatlike" id="passengersPanel">
            <div class="card-header">
                <div class="card-title">
                    <h2><span class="status-dot status-ok"></span>Passengers &amp; Crew</h2>
                    <small class="card-subtitle" id="passengersSummary">Loading…</small>
                </div>
                <div class="card-actions">
                    <button class="btn-primary" id="addPassengerBtn">+ Add</button>
                </div>
            </div>
            <div class="card-body">
                <p id="passengersMessage" class="empty">Loading passengers…</p>
                <div id="passengersList"></div>
            </div>
        </section>

        <section class="dashboard-card panel-floatlike" id="operatorsPanel">
            <div class="card-header">
                <div class="card-title">
                    <h2><span class="status-dot status-ok"></span>Operators</h2>
                    <small class="card-subtitle" id="operatorsSummary">Loading…</small>
                </div>
                <div class="card-actions">
                    <button class="btn-primary" id="addOperatorBtn">+ Add</button>
                </div>
            </div>
            <div class="card-body">
                <p id="operatorsMessage" class="empty">Loading operators…</p>
                <div id="operatorsList"></div>
            </div>
        </section>

        <section class="dashboard-card panel-floatlike full-width" id="waypointsPanel">
            <div class="card-header">
                <div class="card-title">
                    <h2><span class="status-dot status-ok"></span>Waypoints</h2>
                    <small class="card-subtitle" id="waypointsSummary">Loading…</small>
                </div>
                <div class="card-actions">
                    <button class="btn-primary" id="addWaypointBtn">+ Add</button>
                </div>
            </div>
            <div class="card-body">
                <p id="waypointsMessage" class="empty">Loading waypoints…</p>
                <div id="waypointsList"></div>
            </div>
        </section>

        


    </div>
</main>

<div class="modal fade" id="confirmModal" tabindex="-1" aria-labelledby="confirmModalLabel" aria-hidden="true" data-bs-backdrop="static" data-bs-keyboard="false">
    <div class="modal-dialog modal-dialog-centered">
        <div class="modal-content dashboard-card">
            <div class="modal-header card-header">
                <h5 class="modal-title card-title" id="confirmModalLabel">Please Confirm</h5>
                <button type="button" class="btn-close" id="routeBuilderCloseBtn" aria-label="Close"></button>
            </div>
            <div class="modal-body card-body">
                <p id="confirmModalMessage" class="mb-0"></p>
            </div>
            <div class="modal-footer card-footer">
                <button type="button" class="btn-secondary" data-bs-dismiss="modal">Cancel</button>
                <button type="button" class="btn-primary" id="confirmModalOk">Confirm</button>
            </div>
        </div>
    </div>
</div>

<div class="modal fade" id="alertModal" tabindex="-1" aria-labelledby="alertModalLabel" aria-hidden="true" data-bs-backdrop="static" data-bs-keyboard="false">
    <div class="modal-dialog modal-dialog-centered">
        <div class="modal-content dashboard-card">
            <div class="modal-header card-header">
                <h5 class="modal-title card-title" id="alertModalLabel">Notice</h5>
                <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
            </div>
            <div class="modal-body card-body">
                <p id="alertModalMessage" class="mb-0"></p>
            </div>
            <div class="modal-footer card-footer">
                <button type="button" class="btn-primary" data-bs-dismiss="modal">OK</button>
            </div>
        </div>
    </div>
</div>

<div class="modal fade" id="passengerModal" tabindex="-1" aria-labelledby="passengerModalLabel" aria-hidden="true" data-bs-backdrop="static" data-bs-keyboard="false">
    <div class="modal-dialog modal-lg modal-dialog-scrollable">
        <div class="modal-content dashboard-card">
            <div class="modal-header card-header">
                <h5 class="modal-title card-title" id="passengerModalLabel">Passenger/Crew</h5>
                <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
            </div>
            <div class="modal-body card-body">
                <form id="passengerForm" novalidate>
                    <input type="hidden" id="passengerId" value="0">
                    <div class="mb-3">
                        <label class="form-label" for="passengerName">Name *</label>
                        <input type="text" class="form-control" id="passengerName" required>
                        <div class="invalid-feedback" id="passengerNameError"></div>
                    </div>
                    <div class="row">
                        <div class="col-md-6 mb-3">
                            <label class="form-label" for="passengerPhone">Phone</label>
                            <input type="text" class="form-control" id="passengerPhone">
                            <div class="invalid-feedback" id="passengerPhoneError"></div>
                        </div>
                        <div class="col-md-3 mb-3">
                            <label class="form-label" for="passengerAge">Age</label>
                            <input type="text" class="form-control" id="passengerAge">
                        </div>
                        <div class="col-md-3 mb-3">
                            <label class="form-label" for="passengerGender">Gender</label>
                            <input type="text" class="form-control" id="passengerGender">
                        </div>
                    </div>
                    <div class="mb-3">
                        <label class="form-label" for="passengerNotes">Notes</label>
                        <textarea class="form-control" id="passengerNotes" rows="2"></textarea>
                    </div>
                </form>
            </div>
            <div class="modal-footer card-footer">
                <button type="button" class="btn-secondary" data-bs-dismiss="modal">Cancel</button>
                <button type="button" class="btn-primary" id="savePassengerBtn">Save Passenger</button>
            </div>
        </div>
    </div>
</div>

<div class="modal fade" id="operatorModal" tabindex="-1" aria-labelledby="operatorModalLabel" aria-hidden="true" data-bs-backdrop="static" data-bs-keyboard="false">
    <div class="modal-dialog modal-lg modal-dialog-scrollable">
        <div class="modal-content dashboard-card">
            <div class="modal-header card-header">
                <h5 class="modal-title card-title" id="operatorModalLabel">Operator</h5>
                <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
            </div>
            <div class="modal-body card-body">
                <form id="operatorForm" novalidate>
                    <input type="hidden" id="operatorId" value="0">
                    <div class="mb-3">
                        <label class="form-label" for="operatorName">Name *</label>
                        <input type="text" class="form-control" id="operatorName" required>
                        <div class="invalid-feedback" id="operatorNameError"></div>
                    </div>
                    <div class="mb-3">
                        <label class="form-label" for="operatorPhone">Phone</label>
                        <input type="text" class="form-control" id="operatorPhone">
                        <div class="invalid-feedback" id="operatorPhoneError"></div>
                    </div>
                    <div class="mb-3">
                        <label class="form-label" for="operatorNotes">Notes</label>
                        <textarea class="form-control" id="operatorNotes" rows="2"></textarea>
                    </div>
                </form>
            </div>
            <div class="modal-footer card-footer">
                <button type="button" class="btn-secondary" data-bs-dismiss="modal">Cancel</button>
                <button type="button" class="btn-primary" id="saveOperatorBtn">Save Operator</button>
            </div>
        </div>
    </div>
</div>

<div class="modal fade" id="waypointModal" tabindex="-1" aria-labelledby="waypointModalLabel" aria-hidden="true" data-bs-backdrop="static" data-bs-keyboard="false">
    <div class="modal-dialog modal-lg modal-dialog-scrollable">
        <div class="modal-content dashboard-card">
            <div class="modal-header card-header">
                <h5 class="modal-title card-title" id="waypointModalLabel">Waypoint</h5>
                <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
            </div>
            <div class="modal-body card-body">
                <form id="waypointForm" novalidate>
                    <input type="hidden" id="waypointId" value="0">
                    <div id="waypointMap" class="waypoint-map-frame"></div>
                    <div class="small text-muted mt-1">Tip: drag the marker or click the map to reposition.</div>
                    <div class="mb-3 mt-3">
                        <label class="form-label" for="waypointName">Name *</label>
                        <input type="text" class="form-control" id="waypointName" required>
                        <div class="invalid-feedback" id="waypointNameError"></div>
                    </div>
                    <div class="row">
                        <div class="col-md-6 mb-3">
                            <label class="form-label" for="waypointLatitude">Latitude</label>
                            <input type="text" class="form-control" id="waypointLatitude">
                        </div>
                        <div class="col-md-6 mb-3">
                            <label class="form-label" for="waypointLongitude">Longitude</label>
                            <input type="text" class="form-control" id="waypointLongitude">
                        </div>
                    </div>
                    <div class="mb-3">
                        <label class="form-label" for="waypointNotes">Notes</label>
                        <textarea class="form-control" id="waypointNotes" rows="2"></textarea>
                    </div>
                </form>
            </div>
            <div class="modal-footer card-footer">
                <button type="button" class="btn-secondary" data-bs-dismiss="modal">Cancel</button>
                <button type="button" class="btn-primary" id="saveWaypointBtn">Save Waypoint</button>
            </div>
        </div>
    </div>
</div>

<div class="modal fade" id="contactModal" tabindex="-1" aria-labelledby="contactModalLabel" aria-hidden="true" data-bs-backdrop="static" data-bs-keyboard="false">
    <div class="modal-dialog modal-lg modal-dialog-scrollable">
        <div class="modal-content dashboard-card">
            <div class="modal-header card-header">
                <h5 class="modal-title card-title" id="contactModalLabel">Contact</h5>
                <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
            </div>
            <div class="modal-body card-body">
                <form id="contactForm" novalidate>
                    <input type="hidden" id="contactId" value="0">
                    <div class="mb-3">
                        <label class="form-label" for="contactName">Name *</label>
                        <input type="text" class="form-control" id="contactName" required>
                        <div class="invalid-feedback" id="contactNameError"></div>
                    </div>
                    <div class="mb-3">
                        <label class="form-label" for="contactPhone">Phone *</label>
                        <input type="text" class="form-control" id="contactPhone" required pattern="^\+?1?\s*(?:\(\d{3}\)|\d{3})[\s.-]?\d{3}[\s.-]?\d{4}$" title="Use a valid US phone number">
                        <div class="invalid-feedback" id="contactPhoneError"></div>
                    </div>
                    <div class="mb-3">
                        <label class="form-label" for="contactEmail">Email *</label>
                        <input type="email" class="form-control" id="contactEmail" required>
                        <div class="invalid-feedback" id="contactEmailError"></div>
                    </div>
                </form>
            </div>
            <div class="modal-footer card-footer">
                <button type="button" class="btn-secondary" data-bs-dismiss="modal">Cancel</button>
                <button type="button" class="btn-primary" id="saveContactBtn">Save Contact</button>
            </div>
        </div>
    </div>
</div>

<div class="modal fade" id="vesselModal" tabindex="-1" aria-labelledby="vesselModalLabel" aria-hidden="true" data-bs-backdrop="static" data-bs-keyboard="false">
    <div class="modal-dialog modal-lg modal-dialog-scrollable">
        <div class="modal-content dashboard-card">
            <div class="modal-header card-header">
                <h5 class="modal-title card-title" id="vesselModalLabel">Vessel</h5>
                <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
            </div>
            <div class="modal-body card-body">
                <form id="vesselForm" novalidate>
                    <input type="hidden" id="vesselId" value="0">
                    <div class="mb-3">
                        <label class="form-label" for="vesselName">Vessel Name *</label>
                        <input type="text" class="form-control" id="vesselName" required>
                        <div class="invalid-feedback" id="vesselNameError"></div>
                    </div>
                    <div class="row">
                        <div class="col-md-4 mb-3">
                            <label class="form-label" for="vesselType">Type *</label>
                            <input type="text" class="form-control" id="vesselType" required>
                            <div class="invalid-feedback" id="vesselTypeError"></div>
                        </div>
                        <div class="col-md-4 mb-3">
                            <label class="form-label" for="vesselLength">Length *</label>
                            <input type="text" class="form-control" id="vesselLength" required>
                            <div class="invalid-feedback" id="vesselLengthError"></div>
                        </div>
                        <div class="col-md-4 mb-3">
                            <label class="form-label" for="vesselColor">Hull Color *</label>
                            <input type="text" class="form-control" id="vesselColor" required>
                            <div class="invalid-feedback" id="vesselColorError"></div>
                        </div>
                    </div>
                    <div class="form-check mb-3">
                        <input class="form-check-input" type="checkbox" id="vesselIsDefault">
                        <label class="form-check-label" for="vesselIsDefault">Default Vessel - used for route calculations</label>
                    </div>
                    <div class="mb-3">
                        <label class="form-label" for="vesselRegistration">Registration</label>
                        <input type="text" class="form-control" id="vesselRegistration">
                    </div>
                    <div class="row">
                        <div class="col-md-12 mb-3">
                            <label class="form-label" for="vesselHomePort">Hailing Port</label>
                            <input type="text" class="form-control" id="vesselHomePort">
                        </div>
                    </div>
                    <div class="row">
                        <div class="col-md-3 mb-3">
                            <label class="form-label" for="vesselMaxSpeed">Max Speed (KPH)</label>
                            <input type="number" class="form-control" id="vesselMaxSpeed" min="0" step="0.01" inputmode="decimal">
                        </div>
                        <div class="col-md-3 mb-3">
                            <label class="form-label" for="vesselMostEfficientSpeed">Most Efficient Speed (KPH)</label>
                            <input type="number" class="form-control" id="vesselMostEfficientSpeed" min="0" step="0.01" inputmode="decimal">
                        </div>
                        <div class="col-md-3 mb-3">
                            <label class="form-label" for="vesselGallonsPerHour">GPH@efficient</label>
                            <input type="number" class="form-control" id="vesselGallonsPerHour" min="0" step="0.01" inputmode="decimal">
                        </div>
                        <div class="col-md-3 mb-3">
                            <label class="form-label" for="vesselGphAtMaxSpeed">GPH@max</label>
                            <input type="number" class="form-control" id="vesselGphAtMaxSpeed" min="0" step="0.01" inputmode="decimal">
                        </div>
                    </div>
                    <div class="row">
                        <div class="col-md-4 mb-3">
                            <label class="form-label" for="vesselFuelCapacity">Fuel Capacity (gal)</label>
                            <input type="number" class="form-control" id="vesselFuelCapacity" min="0" step="0.01" inputmode="decimal">
                        </div>
                    </div>
                    <div class="row">
                        <div class="col-md-6 mb-3">
                            <label class="form-label" for="vesselMake">Make</label>
                            <input type="text" class="form-control" id="vesselMake">
                        </div>
                        <div class="col-md-6 mb-3">
                            <label class="form-label" for="vesselModel">Model</label>
                            <input type="text" class="form-control" id="vesselModel">
                        </div>
                    </div>
                </form>
            </div>
            <div class="modal-footer card-footer">
                <button type="button" class="btn-secondary" data-bs-dismiss="modal">Cancel</button>
                <button type="button" class="btn-primary" id="saveVesselBtn">Save Vessel</button>
            </div>
        </div>
    </div>
</div>

<div class="modal fade" id="floatPlanWizardModal" tabindex="-1" aria-labelledby="floatPlanWizardLabel" aria-hidden="true" data-bs-backdrop="static" data-bs-keyboard="false">
    <div class="modal-dialog modal-xl modal-dialog-scrollable">
        <div class="modal-content dashboard-card">
            <div class="modal-header card-header">
                <h5 class="modal-title card-title" id="floatPlanWizardLabel">Float Plan Wizard</h5>
                <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
            </div>
            <div class="modal-body card-body wizard-body">
                <div id="wizardApp" class="wizard-container" data-init="manual" data-contact-step="4">

                    <div v-if="isLoading" class="text-center py-5">
                        <div class="spinner-border text-primary" role="status"></div>
                        <p class="mt-3 mb-0">Loading wizard…</p>
                    </div>

                    <template v-else>
                        <form id="floatplanWizardForm" novalidate @submit.prevent>
                            <div class="wizard-steps mb-3">
                            <span v-for="n in Math.min(totalSteps, 6)"
                                  :key="'step-badge-' + n"
                                  class="badge wizard-step-badge"
                                  :class="n === step ? 'wizard-step-badge--active' : 'wizard-step-badge--inactive'">
                                Step {{ n }}
                            </span>
                        </div>

                        <div v-if="statusMessage" class="alert wizard-alert" :class="statusMessage.ok ? 'alert-success' : 'alert-danger'">
                            {{ statusMessage.message }}
                        </div>

                        <!-- Step 1 -->
                        <section v-if="step === 1">
                            <div class="d-flex justify-content-between align-items-center mb-3">
                                <h2 class="h5 mb-0">Step 1 – Basics</h2>
                                <button type="button" class="btn-primary" v-if="step < totalSteps" :disabled="isSaving" @click="nextStep">
                                    {{ nextButtonLabel }}
                                </button>
                            </div>

                            <div class="mb-3">
                                <label class="form-label">Float Plan Name *</label>
                                <input
                                    type="text"
                                    name="NAME"
                                    class="form-control"
                                    v-model="fp.FLOATPLAN.NAME"
                                    :class="{ 'is-invalid': hasError('NAME') }"
                                    :aria-invalid="hasError('NAME') ? 'true' : 'false'"
                                    @input="clearFieldError('NAME')" 
                                    required
                                    />
                                    <div class="invalid-feedback" v-if="hasError('NAME')">{{ getError('NAME') }}</div>

                                                    </div>

                            <div class="mb-3">
                                <label class="form-label">Vessel *</label>
                               <select
                                    name="VESSELID"
                                    class="form-select"
                                    v-model.number="fp.FLOATPLAN.VESSELID"
                                    :class="{ 'is-invalid': hasError('VESSELID') }"
                                    :aria-invalid="hasError('VESSELID') ? 'true' : 'false'"
                                    @change="clearFieldError('VESSELID')"
                                    >
                                    <option :value="0">Select vessel</option>
                                    <option v-for="v in vessels" :key="v.VESSELID" :value="v.VESSELID">
                                        {{ v.VESSELNAME }} &mdash; {{ v.HOMEPORT || 'Unknown port' }}
                                    </option>
                                </select>
                                <div class="invalid-feedback" v-if="hasError('VESSELID')">{{ getError('VESSELID') }}</div>
                            </div>

                            <div class="mb-3">
                                <label class="form-label">Operator *</label>
                                <select
                                    name="OPERATORID"
                                    class="form-select"
                                    v-model.number="fp.FLOATPLAN.OPERATORID"
                                    :class="{ 'is-invalid': hasError('OPERATORID') }"
                                    :aria-invalid="hasError('OPERATORID') ? 'true' : 'false'"
                                    @change="clearFieldError('OPERATORID')"
                                    >
                                    <option :value="0">Select operator</option>
                                    <option v-for="o in operators" :key="o.OPERATORID" :value="o.OPERATORID">
                                        {{ o.OPERATORNAME }}
                                    </option>
                                </select>
                                <div class="invalid-feedback" v-if="hasError('OPERATORID')">{{ getError('OPERATORID') }}</div>
                            </div>

                            <div class="form-check mb-3">
                                <input class="form-check-input" type="checkbox" id="operatorPfd" v-model="fp.FLOATPLAN.OPERATOR_HAS_PFD">
                                <label class="form-check-label" for="operatorPfd">Operator has PFD</label>
                            </div>
                        </section>

                        <!-- Step 2 -->
                        <section v-if="step === 2">
                            <div class="d-flex justify-content-between align-items-center mb-3">
                                <h2 class="h5 mb-0">Step 2 – Times & Route</h2>
                                <button type="button" class="btn btn-primary btn-sm" v-if="step < totalSteps" :disabled="isSaving" @click="nextStep">
                                    {{ nextButtonLabel }}
                                </button>
                            </div>

                            <div class="mb-3">
                                <label class="form-label">Departing From *</label>
                                <input
                                    type="text"
                                    id="departingFrom"
                                    name="DEPARTING_FROM"
                                    class="form-control"
                                    v-model="fp.FLOATPLAN.DEPARTING_FROM"
                                    :class="{ 'is-invalid': hasError('DEPARTING_FROM') }"
                                    :aria-invalid="hasError('DEPARTING_FROM') ? 'true' : 'false'"
                                    @input="clearFieldError('DEPARTING_FROM')"
                                    required
                                />
                                <div class="invalid-feedback" v-if="hasError('DEPARTING_FROM')">{{ getError('DEPARTING_FROM') }}</div>
                                </div>
                            </div>

                            <div class="mb-3">
                                <label class="form-label">Departure Date & Time *</label>
                                <input
                                    type="datetime-local"
                                    name="DEPARTURE_TIME"
                                    class="form-control"
                                    v-model="fp.FLOATPLAN.DEPARTURE_TIME"
                                    :class="{ 'is-invalid': hasError('DEPARTURE_TIME') }"
                                    :aria-invalid="hasError('DEPARTURE_TIME') ? 'true' : 'false'"
                                    @input="clearFieldError('DEPARTURE_TIME')"
                                    />
                                <div class="invalid-feedback" v-if="hasError('DEPARTURE_TIME')">{{ getError('DEPARTURE_TIME') }}</div>
                            </div>

                            <div class="mb-3">
                                <label class="form-label">Departure Time Zone *</label>
                                <select
                                    id="departureTimezone"
                                    name="DEPARTURE_TIMEZONE"
                                    class="form-select"
                                    v-model="fp.FLOATPLAN.DEPARTURE_TIMEZONE"
                                    :class="{ 'is-invalid': hasError('DEPARTURE_TIMEZONE') }"
                                    :aria-invalid="hasError('DEPARTURE_TIMEZONE') ? 'true' : 'false'"
                                    @change="clearFieldError('DEPARTURE_TIMEZONE')"
                                    required
                                >
                                    <option value="">Select time zone</option>
                                    <option v-for="tz in timezones" :key="'dep-'+tz" :value="tz">{{ tz }}</option>
                                </select>
                                <div class="invalid-feedback" v-if="hasError('DEPARTURE_TIMEZONE')">{{ getError('DEPARTURE_TIMEZONE') }}</div>
                            </div>

                            <div class="mb-3">
                                <label class="form-label">Returning To *</label>
                                 <input
                                    type="text"
                                    id="returningTo"
                                    name="RETURNING_TO"
                                    class="form-control"
                                    v-model="fp.FLOATPLAN.RETURNING_TO"
                                    :class="{ 'is-invalid': hasError('RETURNING_TO') }"
                                    :aria-invalid="hasError('RETURNING_TO') ? 'true' : 'false'"
                                    @input="clearFieldError('RETURNING_TO')"
                                    required
                                />
                                <div class="invalid-feedback" v-if="hasError('RETURNING_TO')">{{ getError('RETURNING_TO') }}</div>

                            </div>

                            <div class="mb-3">
                                <label class="form-label">Return Date & Time *</label>
                                <input
                                    type="datetime-local"
                                    name="RETURN_TIME"
                                    class="form-control"
                                    v-model="fp.FLOATPLAN.RETURN_TIME"
                                    :class="{ 'is-invalid': hasError('RETURN_TIME') }"
                                    :aria-invalid="hasError('RETURN_TIME') ? 'true' : 'false'"
                                    @input="clearFieldError('RETURN_TIME')"
                                    />
                                    <div class="invalid-feedback" v-if="hasError('RETURN_TIME')">{{ getError('RETURN_TIME') }}</div>

                            </div>

                            <div class="mb-3">
                                <label class="form-label">Return Time Zone *</label>
                                <select
                                    id="returnTimezone"
                                    name="RETURN_TIMEZONE"
                                    class="form-select"
                                    v-model="fp.FLOATPLAN.RETURN_TIMEZONE"
                                    :class="{ 'is-invalid': hasError('RETURN_TIMEZONE') }"
                                    :aria-invalid="hasError('RETURN_TIMEZONE') ? 'true' : 'false'"
                                    @change="clearFieldError('RETURN_TIMEZONE')"
                                    required
                                >
                                    <option value="">Select time zone</option>
                                    <option v-for="tz in timezones" :key="'ret-'+tz" :value="tz">{{ tz }}</option>
                                </select>
                                <div class="invalid-feedback" v-if="hasError('RETURN_TIMEZONE')">{{ getError('RETURN_TIMEZONE') }}</div>
                            </div>
                        </section>

                        <!-- Step 3 -->
                        <section v-if="step === 3">
                            <div class="d-flex justify-content-between align-items-center mb-3">
                                <h2 class="h5 mb-0">Step 3 – People & Safety</h2>
                                <button type="button" class="btn btn-primary btn-sm" v-if="step < totalSteps" :disabled="isSaving" @click="nextStep">
                                    {{ nextButtonLabel }}
                                </button>
                            </div>

                            <div class="mb-3">
                                <label class="form-label">Email (while underway)</label>
                                <input type="email" class="form-control" v-model="fp.FLOATPLAN.EMAIL">
                            </div>

                            <div class="mb-3">
                                <label class="form-label">Rescue Authority *</label>
                                <select
                                    name="RESCUE_AUTHORITY_SELECTION"
                                    class="form-select"
                                    v-model.number="selectedRescueCenterId"
                                    :class="{ 'is-invalid': hasError('RESCUE_AUTHORITY_SELECTION') }"
                                    :aria-invalid="hasError('RESCUE_AUTHORITY_SELECTION') ? 'true' : 'false'"
                                    @change="handleRescueCenterSelection($event)"
                                    required
                                >
                                    <option :value="0">Select a rescue authority</option>
                                    <option v-for="center in rescueCenters" :key="'resc-'+center.recId" :value="center.recId">
                                        {{ formatRescueCenterLabel(center) }}
                                    </option>
                                </select>
                                <div class="invalid-feedback" v-if="hasError('RESCUE_AUTHORITY_SELECTION')">
                                    {{ getError('RESCUE_AUTHORITY_SELECTION') }}
                                </div>
                                <div class="form-text">
                                    Selecting a rescue center populates the authority name and phone automatically.
                                </div>
                            </div>

                            <div class="row mb-3">
                                <div class="col-sm-6">
                                    <label class="form-label">Food (days/person)</label>
                                    <input type="text" class="form-control" v-model="fp.FLOATPLAN.FOOD_DAYS_PER_PERSON">
                                </div>
                                <div class="col-sm-6">
                                    <label class="form-label">Water (days/person)</label>
                                    <input type="text" class="form-control" v-model="fp.FLOATPLAN.WATER_DAYS_PER_PERSON">
                                </div>
                            </div>

                            <div class="mb-3">
                                <label class="form-label">Notes</label>
                                <textarea rows="2" class="form-control" v-model="fp.FLOATPLAN.NOTES"></textarea>
                            </div>

                        </section>

                        <!-- Step 4 -->
                        <section v-if="step === 4">
                            <div class="d-flex justify-content-between align-items-center mb-3">
                                <h2 class="h5 mb-0">Step 4 – Passengers, Crew & Contacts</h2>
                                <button type="button" class="btn btn-primary btn-sm" v-if="step < totalSteps" :disabled="isSaving" @click="nextStep">
                                    {{ nextButtonLabel }}
                                </button>
                            </div>
                            <p class="small text-muted mb-3">Trip Manifest: choose who is aboard and who receives notifications.</p>
                            <div class="fpw-manifest">
                                <div class="fpw-manifest__summary">
                                    <div class="fpw-manifest__summaryhead">
                                        <h3 class="h6 mb-0">On This Trip</h3>
                                        <button
                                            type="button"
                                            class="btn btn-outline-secondary btn-sm d-md-none"
                                            @click="manifestSummaryOpen = !manifestSummaryOpen"
                                            :aria-expanded="manifestSummaryOpen ? 'true' : 'false'">
                                            {{ manifestSummaryOpen ? 'Hide' : 'Show' }}
                                        </button>
                                    </div>
                                    <div class="fpw-manifest__summarybody" :class="{ 'is-collapsed-mobile': !manifestSummaryOpen }">
                                        <div class="fpw-manifest__group">
                                            <div class="fpw-manifest__grouphead">
                                                <span>Selected Passengers</span>
                                                <span class="badge bg-secondary">{{ fp.PASSENGERS.length }}</span>
                                            </div>
                                            <ul v-if="selectedPassengerDetails.length" class="fpw-manifest__selectedlist">
                                                <li v-for="item in selectedPassengerDetails" :key="'sel-passenger-'+item.id">{{ item.label }}</li>
                                            </ul>
                                            <p v-else class="small text-muted mb-0 mt-2">No passengers selected.</p>
                                        </div>

                                        <div class="fpw-manifest__group">
                                            <div class="fpw-manifest__grouphead">
                                                <span>Selected Contacts</span>
                                                <span class="badge bg-secondary">{{ fp.CONTACTS.length }}</span>
                                            </div>
                                            <ul v-if="selectedContactDetails.length" class="fpw-manifest__selectedlist">
                                                <li v-for="item in selectedContactDetails" :key="'sel-contact-'+item.id">{{ item.label }}</li>
                                            </ul>
                                            <p v-else class="small text-muted mb-0 mt-2">No contacts selected.</p>
                                        </div>
                                    </div>
                                </div>

                                <div class="fpw-manifest__available">
                                    <h3 class="h6 mb-2">Available Items</h3>
                                    <div class="fpw-manifest__tabs" role="tablist" aria-label="Trip manifest tabs">
                                        <button
                                            type="button"
                                            class="fpw-manifest__tabbtn"
                                            :class="{ 'is-active': manifestActiveTab === 'passengers' }"
                                            role="tab"
                                            :aria-selected="manifestActiveTab === 'passengers' ? 'true' : 'false'"
                                            @click="manifestActiveTab = 'passengers'">
                                            Passengers
                                        </button>
                                        <button
                                            type="button"
                                            class="fpw-manifest__tabbtn"
                                            :class="{ 'is-active': manifestActiveTab === 'contacts' }"
                                            role="tab"
                                            :aria-selected="manifestActiveTab === 'contacts' ? 'true' : 'false'"
                                            @click="manifestActiveTab = 'contacts'">
                                            Contacts
                                        </button>
                                    </div>

                                    <div v-if="manifestActiveTab === 'passengers'" class="fpw-manifest__tabpane" role="tabpanel" aria-label="Passengers list">
                                        <input
                                            type="search"
                                            class="form-control form-control-sm mb-2"
                                            v-model.trim="passengerSearchQuery"
                                            placeholder="Search passengers..."
                                            aria-label="Search passengers">
                                        <div class="fpw-manifest__list" role="listbox" aria-label="Available passengers">
                                            <div
                                                v-for="p in filteredPassengers"
                                                :key="'p-'+p.PASSENGERID"
                                                class="fpw-manifest__row"
                                                :class="{ 'is-selected': isPassengerSelected(p.PASSENGERID) }"
                                                role="button"
                                                tabindex="0"
                                                :aria-pressed="isPassengerSelected(p.PASSENGERID) ? 'true' : 'false'"
                                                @click="togglePassenger(p)"
                                                @keydown.enter.prevent="togglePassenger(p)"
                                                @keydown.space.prevent="togglePassenger(p)">
                                                <span class="fpw-manifest__label">{{ p.PASSENGERNAME || ('Passenger #' + p.PASSENGERID) }}</span>
                                                <span class="fpw-manifest__check" aria-hidden="true">{{ isPassengerSelected(p.PASSENGERID) ? '✓' : '' }}</span>
                                            </div>
                                            <p v-if="!filteredPassengers.length" class="small text-muted mb-0 p-2">No passengers match your search.</p>
                                        </div>
                                    </div>

                                    <div v-else class="fpw-manifest__tabpane" role="tabpanel" aria-label="Contacts list">
                                        <input
                                            type="search"
                                            class="form-control form-control-sm mb-2"
                                            v-model.trim="contactSearchQuery"
                                            placeholder="Search contacts..."
                                            aria-label="Search contacts">
                                        <div class="fpw-manifest__list" role="listbox" aria-label="Available contacts">
                                            <div
                                                v-for="c in filteredContacts"
                                                :key="'c-'+c.CONTACTID"
                                                class="fpw-manifest__row"
                                                :class="{ 'is-selected': isContactSelected(c.CONTACTID) }"
                                                role="button"
                                                tabindex="0"
                                                :aria-pressed="isContactSelected(c.CONTACTID) ? 'true' : 'false'"
                                                @click="toggleContact(c)"
                                                @keydown.enter.prevent="toggleContact(c)"
                                                @keydown.space.prevent="toggleContact(c)">
                                                <span class="fpw-manifest__label">{{ c.CONTACTNAME || ('Contact #' + c.CONTACTID) }}</span>
                                                <span class="fpw-manifest__check" aria-hidden="true">{{ isContactSelected(c.CONTACTID) ? '✓' : '' }}</span>
                                            </div>
                                            <p v-if="!filteredContacts.length" class="small text-muted mb-0 p-2">No contacts match your search.</p>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </section>

                        <!-- Step 5 -->
                        <section v-if="step === 5">
                            <div class="d-flex justify-content-between align-items-center mb-3">
                                <h2 class="h5 mb-0">Step 5 – Waypoints</h2>
                                <button type="button" class="btn btn-primary btn-sm" v-if="step < totalSteps" :disabled="isSaving" @click="nextStep">
                                    {{ nextButtonLabel }}
                                </button>
                            </div>

                            <p class="small text-muted mb-3">Tap to include; order is preserved.</p>
                            <div class="fpw-manifest fpw-manifest--waypoints">
                                <div class="fpw-manifest__summary">
                                    <div class="fpw-manifest__summaryhead">
                                        <h3 class="h6 mb-0">In Route ({{ fp.WAYPOINTS.length }})</h3>
                                        <button
                                            type="button"
                                            class="btn btn-outline-secondary btn-sm d-md-none"
                                            @click="mobileWaypointsSummaryOpen = !mobileWaypointsSummaryOpen"
                                            :aria-expanded="mobileWaypointsSummaryOpen ? 'true' : 'false'">
                                            {{ mobileWaypointsSummaryOpen ? 'Hide' : 'Show' }}
                                        </button>
                                    </div>
                                    <div class="fpw-manifest__summarybody" :class="{ 'is-collapsed-mobile': !mobileWaypointsSummaryOpen }">
                                        <ul v-if="selectedWaypointDetails.length" class="fpw-manifest__selectedlist">
                                            <li v-for="item in selectedWaypointDetails" :key="'sel-waypoint-'+item.id">
                                                <span class="badge bg-secondary me-2">{{ item.position }}</span>{{ item.label }}
                                            </li>
                                        </ul>
                                        <p v-else class="small text-muted mb-0 mt-2">No waypoints selected.</p>
                                    </div>
                                </div>

                                <div class="fpw-manifest__available">
                                    <h3 class="h6 mb-2">Available Waypoints</h3>
                                    <div class="fpw-manifest__tabs" role="tablist" aria-label="Waypoint tabs">
                                        <button
                                            type="button"
                                            class="fpw-manifest__tabbtn is-active"
                                            role="tab"
                                            aria-selected="true">
                                            Waypoints
                                        </button>
                                    </div>
                                    <input
                                        type="search"
                                        class="form-control form-control-sm mb-2"
                                        v-model.trim="waypointSearchQuery"
                                        placeholder="Search waypoints..."
                                        aria-label="Search waypoints">
                                    <div class="fpw-manifest__list" role="listbox" aria-label="Available waypoints">
                                        <div
                                            v-for="w in filteredWaypoints"
                                            :key="'w-'+w.WAYPOINTID"
                                            class="fpw-manifest__row"
                                            :class="{ 'is-selected': isWaypointSelected(w.WAYPOINTID) }"
                                            role="button"
                                            tabindex="0"
                                            :aria-pressed="isWaypointSelected(w.WAYPOINTID) ? 'true' : 'false'"
                                            @click="toggleWaypoint(w)"
                                            @keydown.enter.prevent="toggleWaypoint(w)"
                                            @keydown.space.prevent="toggleWaypoint(w)">
                                            <span class="fpw-manifest__label">{{ w.WAYPOINTNAME || ('Waypoint #' + w.WAYPOINTID) }}</span>
                                            <span class="fpw-manifest__check" aria-hidden="true">{{ isWaypointSelected(w.WAYPOINTID) ? '✓' : '' }}</span>
                                        </div>
                                        <p v-if="!filteredWaypoints.length" class="small text-muted mb-0 p-2">No waypoints match your search.</p>
                                    </div>
                                </div>
                            </div>
                        </section>

                        <!-- Step 6 -->
                        <section v-if="step === 6">
                            <h2 class="h5 mb-3">Step 6 – Review</h2>

                            <h3 class="h6">Review</h3>
                            <div class="mb-3">
                                <div v-if="pdfPreviewError" class="alert alert-warning small">
                                    {{ pdfPreviewError }}
                                </div>
                                <div v-else-if="pdfPreviewLoading" class="text-center py-4">
                                    <div class="spinner-border text-primary" role="status"></div>
                                    <p class="mt-2 mb-0 small">Generating PDF preview…</p>
                                </div>
                                <div v-else-if="pdfPreviewUrl" class="border rounded fpw-pdf-preview">
                                    <iframe
                                        :src="pdfPreviewUrl"
                                        title="Float plan PDF preview"
                                        class="w-100 h-100 fpw-pdf-preview-frame"
                                        loading="lazy"></iframe>
                                </div>
                                <div v-else class="alert alert-secondary small mb-0">
                                    Save this float plan to generate a PDF preview.
                                </div>
                            </div>

                            <button type="button" class="btn-primary w-100" @click="submitPlan" :disabled="isSaving">
                                {{ isSaving ? 'Saving…' : 'Save Float Plan' }}
                            </button>
                            <button type="button" class="btn-primary w-100 mt-2" @click="submitPlanAndSend" :disabled="isSaving">
                                {{ isSaving ? 'Sending...' : 'Save &amp; Send' }}
                            </button>
                        </section>

                        <div class="wizard-nav">
                            <button type="button" class="btn-secondary" :disabled="step === 1 || isSaving" @click="clearStatus(); prevStep()">
                                Back
                            </button>
                            <button type="button" class="btn-primary" v-if="fp.FLOATPLAN.FLOATPLANID && step < totalSteps" :disabled="isSaving" @click="submitPlan">
                                {{ isSaving ? 'Saving…' : 'Save Float Plan' }}
                            </button>
                            <button type="button" class="btn-primary" v-if="step < totalSteps" :disabled="isSaving" @click="nextStep">
                                {{ nextButtonLabel }}
                            </button>
                        </div>
                        </form>
                    </template>

                </div>
            </div>
        </div>
    </div>
</div>

<div class="modal fade" id="floatPlanCloneModal" tabindex="-1" aria-labelledby="floatPlanCloneLabel" aria-hidden="true" data-bs-backdrop="static" data-bs-keyboard="false">
    <div class="modal-dialog">
        <div class="modal-content dashboard-card">
            <div class="modal-header card-header">
                <h5 class="modal-title card-title" id="floatPlanCloneLabel">Float Plan Cloned</h5>
            </div>
            <div class="modal-body card-body">
                <p class="mb-0" data-clone-message>Float plan has been cloned.</p>
            </div>
            <div class="modal-footer">
                <button type="button" class="btn-primary" data-clone-ok>OK</button>
            </div>
        </div>
    </div>
</div>

<div class="modal fade" id="routeBuilderModal" tabindex="-1" aria-labelledby="routeBuilderLabel" aria-hidden="true" data-bs-backdrop="static" data-bs-keyboard="false">
    <div class="modal-dialog modal-dialog-scrollable routebuilder-modal-fullwidth">
        <div class="modal-content dashboard-card">
            <div class="modal-body card-body routebuilder-modal-body p-0">
                <h5 id="routeBuilderLabel" class="visually-hidden">Route Generator</h5>
                <cfinclude template="../includes/modals/route_generator_modal.cfm">
            </div>
        </div>
    </div>
</div>

<cfinclude template="../includes/footer_scripts.cfm">

<script src="https://unpkg.com/vue@3/dist/vue.global.prod.js"></script>
<script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js" integrity="sha256-20nQCchB9co0qIjJZRGuk2/Z9VM+kNiyxNV1lvTlZBo=" crossorigin=""></script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/leaflet.draw/1.0.4/leaflet.draw.js"></script>
<script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/maps/leaflet-noaa-waypoint-map.js?v=20260227c"></script>
<script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/app/validate.js?v=20260227c"></script>
<script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/app/floatplanWizard.js?v=20260304a"></script>
<script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/app/dashboard/utils.js?v=20260227c"></script>
<script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/app/dashboard/state.js?v=20260227c"></script>
<script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/app/dashboard/alerts.js?v=20260227c"></script>
<script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/app/dashboard/floatplans.js?v=20260227c"></script>
<script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/app/dashboard/vessels.js?v=20260302a"></script>
<script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/app/dashboard/contacts.js?v=20260301b"></script>
<script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/app/dashboard/passengers.js?v=20260301b"></script>
<script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/app/dashboard/operators.js?v=20260301b"></script>
<script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/app/dashboard/waypoints.js?v=20260301a"></script>
<script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/app/dashboard/routebuilder.js?v=20260304c"></script>

<!-- Dashboard-specific JS -->
<script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/app/dashboard.js?v=20260303b"></script>



</body>
</html>
