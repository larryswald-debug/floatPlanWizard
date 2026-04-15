<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Weather - Float Plan Wizard</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">

    <cfinclude template="../includes/header_styles.cfm">
    <link rel="stylesheet" href="<cfoutput>#request.fpwBase#</cfoutput>/assets/css/dashboard-console.css?v=20260414a">
</head>
<body class="dashboard-body" data-fpw-page="weather">

<cfset request.fpwTopNavActive = "weather">
<cfinclude template="../includes/top_nav.cfm">

<main class="dashboard-main">
    <div class="dashboard-grid dashboard-grid--reflow">
        <section class="fpw-card fpw-alerts weather-full-panel" id="weather" aria-label="System Alerts">
            <div class="fpw-card__header">
                <div class="fpw-card__title">
                    <span id="weatherProviderBadge" class="fpw-wx__badge">NOAA/NWS</span>
                    <button class="fpw-caret" type="button" data-bs-toggle="collapse" data-bs-target="#alertsCollapse" aria-expanded="true" aria-controls="alertsCollapse">
                        <span class="fpw-caret__icon" aria-hidden="true">></span>
                    </button>
                    <div class="fpw-wx__titleRow fpw-wx__titleRow--header">
                      <h3 id="weatherPanelTitle" class="fpw-wx__title d-none">—</h3>
                      <span id="weatherUpdatedAt" class="fpw-wx__pill d-none">Updated: —</span>
                      <div id="weatherSummary" class="fpw-wx__summary fpw-wx__summary--header">
                        Enter a ZIP code to load your local forecast.
                      </div>
                    </div>
                </div>
                <div class="fpw-card__actions fpw-card__actions--weather">
                    <div class="fpw-wx__topRight fpw-wx__topRight--header">
                        <div id="weatherLocationModeBlock" class="fpw-wx__zipBlock">
                          <label for="weatherLocationMode" class="fpw-wx__zipLabel">Location</label>
                          <select
                            id="weatherLocationMode"
                            class="form-select form-select-sm fpw-wx__zipInput"
                            aria-describedby="weatherLocationModeHelp"
                          >
                            <option value="zip" selected>ZIP</option>
                            <option value="coords">Coordinates</option>
                          </select>
                          <div id="weatherLocationModeHelp" class="form-text small">Temp (not saved)</div>
                        </div>

                        <div id="weatherZipBlock" class="fpw-wx__zipBlock">
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

                        <div id="weatherCoordsBlock" class="fpw-wx__zipBlock d-none">
                          <label for="weatherLat" class="fpw-wx__zipLabel">Lat</label>
                          <input
                            id="weatherLat"
                            type="text"
                            inputmode="decimal"
                            class="form-control form-control-sm fpw-wx__zipInput"
                            placeholder="27.9506"
                            aria-describedby="weatherCoordsHelp"
                          />
                        </div>

                        <div id="weatherCoordsLonBlock" class="fpw-wx__zipBlock d-none">
                          <label for="weatherLon" class="fpw-wx__zipLabel">Lon</label>
                          <input
                            id="weatherLon"
                            type="text"
                            inputmode="decimal"
                            class="form-control form-control-sm fpw-wx__zipInput"
                            placeholder="-82.4572"
                            aria-describedby="weatherCoordsHelp"
                          />
                          <div id="weatherCoordsHelp" class="form-text small">Temp (not saved)</div>
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

            <div id="alertsCollapse" class="collapse show">
                <div class="fpw-card__body">

  <section class="fpw-weather-cockpit wx-panel wx-panel--cockpit" aria-labelledby="weatherPanelTitle">
    <div id="weatherLoading" class="fpw-wx__pill d-none">Loading weather…</div>
    <div id="weatherError" class="alert alert-warning d-none mb-3" role="alert"></div>

    <div class="fpw-wx__main">
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

        <ul id="weatherAlertsList" class="fpw-wx__alertsList"></ul>
      </div>
    </div>

    <div class="fpw-wx__instruments wx-row">
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
    </div>
</main>

<cfinclude template="../includes/footer_scripts.cfm">
<script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/app/dashboard/utils.js?v=20260227c"></script>
<script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/app/dashboard.js?v=202604150035a"></script>

</body>
</html>
