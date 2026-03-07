<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>FPW Route Generator Tightened Mockup</title>
  <style>
    :root {
      --bg: #07111c;
      --bg2: #091827;
      --panel: rgba(16, 28, 42, 0.92);
      --panel2: rgba(20, 35, 52, 0.88);
      --line: rgba(114, 159, 214, 0.16);
      --line-strong: rgba(91, 199, 255, 0.34);
      --text: #eef6ff;
      --muted: #9db1c8;
      --soft: #7f95ac;
      --accent: #52b9ff;
      --accent2: #31d7b5;
      --warn: #ffcf67;
      --good: #34d183;
      --danger: #ff7171;
      --shadow: 0 16px 40px rgba(0,0,0,.34);
      --r-xl: 22px;
      --r-lg: 16px;
      --r-md: 12px;
    }

    * { box-sizing: border-box; }
    html, body {
      margin: 0;
      height: 100%;
      font-family: Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      color: var(--text);
      background:
        radial-gradient(circle at top left, rgba(80, 180, 255, .18), transparent 26%),
        radial-gradient(circle at top right, rgba(25, 224, 198, .08), transparent 20%),
        linear-gradient(180deg, #06101a 0%, #07131f 42%, #081522 100%);
    }

    .modal {
      width: min(1780px, calc(100vw - 18px));
      height: min(980px, calc(100vh - 18px));
      margin: 9px auto;
      background: linear-gradient(180deg, rgba(11,24,37,.96), rgba(8,20,33,.98));
      border: 1px solid rgba(91,199,255,.14);
      border-radius: 22px;
      box-shadow: var(--shadow);
      overflow: hidden;
      display: grid;
      grid-template-rows: auto auto 1fr;
    }

    .topbar {
      display: flex;
      align-items: flex-start;
      justify-content: space-between;
      gap: 16px;
      padding: 14px 18px 12px;
      border-bottom: 1px solid var(--line);
      background: linear-gradient(180deg, rgba(36,77,96,.38), rgba(8,22,34,.1));
    }

    .title {
      font-size: 28px;
      font-weight: 900;
      letter-spacing: .03em;
    }

    .subtitle {
      color: var(--muted);
      font-size: 14px;
      margin-top: 4px;
    }

    .topbar-right {
      display: flex;
      align-items: center;
      gap: 10px;
    }

    .pill {
      padding: 7px 12px;
      border-radius: 999px;
      border: 1px solid var(--line);
      background: rgba(255,255,255,.03);
      color: var(--muted);
      font-weight: 700;
      font-size: 12px;
      letter-spacing: .06em;
      text-transform: uppercase;
    }

    .close {
      width: 38px;
      height: 38px;
      display: grid;
      place-items: center;
      border-radius: 12px;
      border: 1px solid var(--line);
      background: rgba(255,255,255,.04);
      color: var(--text);
      font-weight: 900;
      font-size: 20px;
    }

    .statusbar {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 14px;
      padding: 10px 18px;
      border-bottom: 1px solid var(--line);
      color: var(--muted);
      font-size: 13px;
    }

    .body {
      min-height: 0;
      display: grid;
      grid-template-columns: 560px 1fr;
      gap: 12px;
      padding: 12px;
    }

    .panel {
      min-height: 0;
      background:
        linear-gradient(180deg, rgba(255,255,255,.028), rgba(255,255,255,.012)),
        linear-gradient(180deg, rgba(20,34,50,.9), rgba(12,22,34,.96));
      border: 1px solid var(--line);
      border-radius: var(--r-xl);
      box-shadow: inset 0 1px 0 rgba(255,255,255,.03);
      overflow: hidden;
    }

    .panel-head {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 12px;
      padding: 12px 14px;
      border-bottom: 1px solid var(--line);
      background: linear-gradient(180deg, rgba(255,255,255,.02), rgba(255,255,255,0));
    }

    .eyebrow {
      color: var(--muted);
      font-size: 11px;
      font-weight: 800;
      letter-spacing: .18em;
      text-transform: uppercase;
      margin-bottom: 3px;
    }

    .panel-title {
      font-size: 22px;
      font-weight: 850;
      line-height: 1.1;
    }

    .panel-sub {
      color: var(--muted);
      font-size: 12px;
      max-width: 260px;
      text-align: right;
    }

    .left-scroll, .right-scroll {
      min-height: 0;
      overflow: auto;
      padding: 12px;
    }

    .stack {
      display: grid;
      gap: 10px;
    }

    .section {
      border: 1px solid var(--line);
      border-radius: 16px;
      background: linear-gradient(180deg, rgba(255,255,255,.02), rgba(255,255,255,.01));
      padding: 10px;
    }

    .section-head {
      display: flex;
      align-items: baseline;
      justify-content: space-between;
      gap: 10px;
      margin-bottom: 8px;
    }

    .section-title {
      color: #d8e7f6;
      font-size: 13px;
      font-weight: 850;
      letter-spacing: .12em;
      text-transform: uppercase;
    }

    .section-note {
      color: var(--soft);
      font-size: 12px;
    }

    .grid-2, .grid-3, .grid-4, .grid-5, .grid-6 {
      display: grid;
      gap: 8px;
    }

    .grid-2 { grid-template-columns: repeat(2, 1fr); }
    .grid-3 { grid-template-columns: repeat(3, 1fr); }
    .grid-4 { grid-template-columns: repeat(4, 1fr); }
    .grid-5 { grid-template-columns: repeat(5, 1fr); }
    .grid-6 { grid-template-columns: repeat(6, 1fr); }

    .field, .mini-card, .stat, .timeline-shell {
      border: 1px solid rgba(114,159,214,.14);
      border-radius: 14px;
      background: rgba(255,255,255,.022);
    }

    .field {
      padding: 9px 10px 10px;
      min-height: 64px;
    }

    .label {
      color: var(--muted);
      font-size: 10px;
      font-weight: 800;
      letter-spacing: .16em;
      text-transform: uppercase;
      margin-bottom: 7px;
    }

    .select, .input, .toggle, .button, .compact-btn {
      width: 100%;
      border-radius: 11px;
      border: 1px solid rgba(255,255,255,.08);
      background: rgba(5,12,18,.38);
      color: var(--text);
      min-height: 40px;
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 0 12px;
      font-size: 14px;
    }

    .muted { color: var(--muted); }
    .soft { color: var(--soft); }

    .button, .compact-btn {
      cursor: pointer;
      font-weight: 700;
      justify-content: center;
      gap: 8px;
      background: linear-gradient(180deg, rgba(255,255,255,.06), rgba(255,255,255,.03));
    }

    .button.primary, .compact-btn.primary {
      background: linear-gradient(180deg, rgba(82,185,255,.22), rgba(82,185,255,.12));
      border-color: rgba(82,185,255,.28);
    }

    .button.slim, .compact-btn { min-height: 36px; }

    .toggle-wrap {
      display: flex;
      align-items: center;
      gap: 8px;
      color: var(--muted);
      font-size: 12px;
      font-weight: 700;
    }

    .toggle-pill {
      width: 42px;
      height: 22px;
      border-radius: 999px;
      border: 1px solid rgba(255,255,255,.1);
      background: rgba(255,255,255,.05);
      position: relative;
      flex: 0 0 auto;
    }

    .toggle-pill::after {
      content: "";
      position: absolute;
      top: 2px;
      left: 2px;
      width: 16px;
      height: 16px;
      border-radius: 50%;
      background: #8ea4ba;
    }

    .mini-grid {
      display: grid;
      grid-template-columns: repeat(6, 1fr);
      gap: 8px;
      margin-bottom: 8px;
    }

    .mini-card {
      min-height: 84px;
      padding: 10px 11px;
      display: flex;
      flex-direction: column;
      justify-content: space-between;
    }

    .mini-label {
      color: var(--muted);
      font-size: 10px;
      font-weight: 800;
      letter-spacing: .16em;
      text-transform: uppercase;
    }

    .mini-value {
      font-size: 28px;
      font-weight: 900;
      line-height: 1;
    }

    .mini-unit {
      color: var(--muted);
      font-size: 13px;
      font-weight: 700;
    }

    .mini-meta {
      color: var(--soft);
      font-size: 12px;
    }

    .config-grid {
      display: grid;
      grid-template-columns: repeat(5, 1fr);
      gap: 8px;
      margin-bottom: 8px;
    }

    .config-grid-bottom {
      display: grid;
      grid-template-columns: repeat(3, 1fr) 1.45fr;
      gap: 8px;
      align-items: stretch;
    }

    .weather-assist {
      border: 1px solid rgba(82,185,255,.18);
      border-radius: 14px;
      background: linear-gradient(180deg, rgba(82,185,255,.08), rgba(255,255,255,.02));
      padding: 10px;
      display: grid;
      gap: 7px;
    }

    .weather-top {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 10px;
    }

    .assist-title {
      font-size: 12px;
      font-weight: 850;
      letter-spacing: .14em;
      text-transform: uppercase;
      color: #dbeaff;
    }

    .badge {
      padding: 4px 9px;
      border-radius: 999px;
      font-size: 11px;
      font-weight: 800;
      letter-spacing: .08em;
      text-transform: uppercase;
      border: 1px solid rgba(255,255,255,.1);
      color: #dff9eb;
      background: rgba(52,209,131,.1);
    }

    .assist-row {
      display: flex;
      align-items: center;
      gap: 10px;
      flex-wrap: wrap;
    }

    .assist-value {
      font-size: 28px;
      font-weight: 900;
      line-height: 1;
    }

    .assist-copy {
      color: var(--muted);
      font-size: 12px;
      line-height: 1.35;
    }

    .assist-actions {
      display: flex;
      gap: 8px;
      flex-wrap: wrap;
    }

    .pace {
      border: 1px solid rgba(114,159,214,.14);
      border-radius: 14px;
      background: rgba(255,255,255,.022);
      padding: 10px 12px;
      display: grid;
      gap: 8px;
    }

    .pace-top {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 10px;
    }

    .slider {
      height: 10px;
      border-radius: 999px;
      background: rgba(255,255,255,.08);
      position: relative;
      overflow: hidden;
    }

    .slider::before {
      content: "";
      position: absolute;
      inset: 0 20% 0 0;
      background: linear-gradient(90deg, #fff 0%, #f6f6f6 100%);
    }

    .slider-labels {
      display: flex;
      justify-content: space-between;
      gap: 10px;
      color: var(--muted);
      font-size: 11px;
      font-weight: 700;
    }

    .timeline-shell {
      min-height: 0;
      padding: 0;
      display: grid;
      grid-template-rows: auto auto 1fr;
      overflow: hidden;
    }

    .timeline-head {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 10px;
      padding: 12px 12px 10px;
      border-bottom: 1px solid rgba(114,159,214,.14);
      background: linear-gradient(180deg, rgba(255,255,255,.02), rgba(255,255,255,0));
    }

    .timeline-actions {
      display: flex;
      gap: 8px;
      align-items: center;
    }

    .timeline-table {
      min-height: 0;
      overflow: auto;
      padding: 0 0 10px;
    }

    table {
      width: 100%;
      border-collapse: collapse;
      font-size: 13px;
    }

    thead th {
      position: sticky;
      top: 0;
      z-index: 1;
      text-align: left;
      padding: 10px 12px;
      background: rgba(12,20,31,.98);
      color: var(--muted);
      font-size: 11px;
      letter-spacing: .15em;
      text-transform: uppercase;
      border-bottom: 1px solid rgba(114,159,214,.14);
    }

    tbody td {
      padding: 12px;
      border-bottom: 1px solid rgba(114,159,214,.08);
      color: #d7e7f8;
    }

    tbody tr:nth-child(odd) td {
      background: rgba(255,255,255,.01);
    }

    .dim { color: var(--muted); }
    .good { color: #97ffd0; }
    .warn { color: #ffe2a1; }

    .myroutes-grid {
      display: grid;
      grid-template-columns: 1fr 1.15fr;
      gap: 8px;
    }

    .hint {
      color: var(--soft);
      font-size: 12px;
      line-height: 1.4;
      padding-top: 4px;
    }

    @media (max-width: 1500px) {
      .body { grid-template-columns: 470px 1fr; }
      .mini-grid { grid-template-columns: repeat(3, 1fr); }
      .config-grid { grid-template-columns: repeat(3, 1fr); }
      .config-grid-bottom { grid-template-columns: repeat(2, 1fr); }
    }

    @media (max-width: 1120px) {
      .modal { width: calc(100vw - 10px); height: calc(100vh - 10px); margin: 5px auto; }
      .body { grid-template-columns: 1fr; }
      .mini-grid { grid-template-columns: repeat(2, 1fr); }
      .grid-5, .grid-6 { grid-template-columns: repeat(2, 1fr); }
      .myroutes-grid, .grid-4, .config-grid, .config-grid-bottom { grid-template-columns: 1fr; }
    }
  </style>
</head>
<body>
  <div class="modal">
    <div class="topbar">
      <div>
        <div class="title">FPW Route Generator</div>
        <div class="subtitle">Tightened layout concept: compact controls up top, large timeline/work area below.</div>
      </div>
      <div class="topbar-right">
        <div class="pill">Draft</div>
        <div class="close">×</div>
      </div>
    </div>

    <div class="statusbar">
      <div>Simple mode plus advanced controls. Preview before generating your route.</div>
      <div>Template: Great Loop · Local live-weather assist enabled</div>
    </div>

    <div class="body">
      <section class="panel">
        <div class="panel-head">
          <div>
            <div class="eyebrow">Setup</div>
            <div class="panel-title">Start → End → Pace</div>
          </div>
          <div class="panel-sub">Tighter section spacing, fewer nested boxes, same workflow.</div>
        </div>

        <div class="left-scroll">
          <div class="stack">
            <div class="section">
              <div class="section-head">
                <div class="section-title">Template</div>
                <div class="section-note">Loaded from your FPW route library</div>
              </div>
              <div class="field">
                <div class="label">Route Template</div>
                <div class="select"><span>Select template</span><span class="muted">▾</span></div>
              </div>
            </div>

            <div class="section">
              <div class="section-head">
                <div class="section-title">Trip Basics</div>
                <div class="section-note">Core route settings</div>
              </div>
              <div class="grid-2">
                <div class="field">
                  <div class="label">Start Location</div>
                  <div class="select"><span>Select start location</span><span class="muted">▾</span></div>
                </div>
                <div class="field">
                  <div class="label">End Location</div>
                  <div class="select"><span>Select end location</span><span class="muted">▾</span></div>
                </div>
                <div class="field">
                  <div class="label">Start Date</div>
                  <div class="input"><span>03/06/2026</span></div>
                </div>
                <div class="field">
                  <div class="label">Direction</div>
                  <div class="toggle-wrap">
                    <div>Counterclockwise (CCW)</div>
                    <div class="toggle-pill"></div>
                    <div>Reverse</div>
                  </div>
                </div>
              </div>
            </div>

            <div class="section">
              <div class="section-head">
                <div class="section-title">Optional Stops</div>
                <div class="section-note">Include detours in preview/generate</div>
              </div>
              <div class="field" style="min-height:58px; display:flex; align-items:center; color:var(--soft); font-style:italic;">No optional stops available for this template.</div>
            </div>

            <div class="section">
              <div class="section-head">
                <div class="section-title">My Routes & Waypoint Builder</div>
                <div class="section-note">Compact custom-route tools</div>
              </div>

              <div class="myroutes-grid">
                <div class="stack">
                  <div class="field">
                    <div class="label">Create Route</div>
                    <div class="grid-2" style="grid-template-columns:1fr 98px; gap:8px;">
                      <div class="input"><span class="soft">Route name</span></div>
                      <div class="button slim primary">Create</div>
                    </div>
                  </div>

                  <div class="field">
                    <div class="label">Route Start Waypoint</div>
                    <div class="grid-2" style="grid-template-columns:1fr 98px; gap:8px;">
                      <div class="select"><span>Select start waypoint</span><span class="muted">▾</span></div>
                      <div class="button slim">Set Start</div>
                    </div>
                  </div>
                </div>

                <div class="stack">
                  <div class="field">
                    <div class="label">My Routes</div>
                    <div class="grid-3" style="grid-template-columns:1fr 84px 84px; gap:8px;">
                      <div class="select"><span>Select route</span><span class="muted">▾</span></div>
                      <div class="button slim">Load</div>
                      <div class="button slim">Delete</div>
                    </div>
                  </div>

                  <div class="field">
                    <div class="label">Add Leg By Waypoint</div>
                    <div class="grid-2" style="grid-template-columns:1fr 84px; gap:8px;">
                      <div class="select"><span>Select end waypoint</span><span class="muted">▾</span></div>
                      <div class="button slim">Add Leg</div>
                    </div>
                  </div>
                </div>
              </div>

              <div class="field" style="margin-top:8px; min-height:90px;">
                <div class="label">Leg Sequence</div>
                <div class="hint">Set a route start waypoint, then add legs by choosing each next waypoint. The right-side preview remains the primary work area.</div>
                <div style="margin-top:8px; padding:10px 12px; border:1px dashed rgba(114,159,214,.14); border-radius:12px; color:var(--soft);">Create or select a My Route to manage legs.</div>
              </div>
            </div>
          </div>
        </div>
      </section>

      <section class="panel">
        <div class="panel-head">
          <div>
            <div class="eyebrow">Preview</div>
            <div class="panel-title">Route Summary and Legs</div>
          </div>
          <div class="panel-sub">Compact stats and controls above. Timeline gets the bulk of the height.</div>
        </div>

        <div class="right-scroll" style="display:grid; grid-template-rows:auto auto auto 1fr; gap:8px; min-height:0;">
          <div class="mini-grid">
            <div class="mini-card">
              <div class="mini-label">Total Distance</div>
              <div><span class="mini-value">0</span> <span class="mini-unit">NM</span></div>
              <div class="mini-meta">Based on selected legs</div>
            </div>
            <div class="mini-card">
              <div class="mini-label">Estimated Days</div>
              <div><span class="mini-value">0</span></div>
              <div class="mini-meta">Pace-driven estimate</div>
            </div>
            <div class="mini-card">
              <div class="mini-label">Estimated Fuel</div>
              <div><span class="mini-value">--</span> <span class="mini-unit">gal</span></div>
              <div class="mini-meta">Required + reserve</div>
            </div>
            <div class="mini-card">
              <div class="mini-label">Fuel Cost</div>
              <div><span class="mini-value">--</span> <span class="mini-unit">USD</span></div>
              <div class="mini-meta">Fuel × price</div>
            </div>
            <div class="mini-card">
              <div class="mini-label">Locks</div>
              <div><span class="mini-value">0</span></div>
              <div class="mini-meta">Total lock count</div>
            </div>
            <div class="mini-card">
              <div class="mini-label">Offshore Legs</div>
              <div><span class="mini-value">0</span></div>
              <div class="mini-meta">Optional/open-water count</div>
            </div>
          </div>

          <div class="config-grid">
            <div class="field">
              <div class="label">Max Speed (kn)</div>
              <div class="select"><span>20</span><span class="muted">▾</span></div>
            </div>
            <div class="field">
              <div class="label">Fuel Burn @ Max (gph)</div>
              <div class="select"><span>7.2</span><span class="muted">▾</span></div>
            </div>
            <div class="field">
              <div class="label">Idle Burn (gph)</div>
              <div class="select"><span>1.2</span><span class="muted">▾</span></div>
            </div>
            <div class="field">
              <div class="label">Idle Hours (total)</div>
              <div class="select"><span>0.5</span><span class="muted">▾</span></div>
            </div>
            <div class="field">
              <div class="label">Weather Factor (%)</div>
              <div class="select"><span>0</span><span class="muted">▾</span></div>
            </div>
          </div>

          <div class="config-grid-bottom">
            <div class="field">
              <div class="label">Reserve (%)</div>
              <div class="select"><span>20</span><span class="muted">▾</span></div>
            </div>
            <div class="field">
              <div class="label">Underway Hrs / Day</div>
              <div class="select"><span>8</span><span class="muted">▾</span></div>
            </div>
            <div class="field">
              <div class="label">Fuel Price ($/gal)</div>
              <div class="input"><span class="soft">Enter price</span></div>
            </div>

            <div class="weather-assist">
              <div class="weather-top">
                <div class="assist-title">Live Weather Assist (Local)</div>
                <div class="badge">High</div>
              </div>
              <div class="assist-row">
                <div class="assist-value">6%</div>
                <div class="assist-copy">Anchor ZIP 34652 using current nearby marine weather.</div>
              </div>
              <div class="assist-copy">Wind 10 mph · Waves 0 ft · Visibility 10 mi · Advisory: none</div>
              <div class="assist-actions">
                <div class="compact-btn">Refresh</div>
                <div class="compact-btn primary">Apply Suggested</div>
              </div>
            </div>
          </div>

          <div class="pace">
            <div class="pace-top">
              <div>
                <div style="font-size:18px; font-weight:850;">Pace</div>
                <div class="soft" style="font-size:12px;">Pace applies 25%, 50%, or 100% of your max speed.</div>
              </div>
              <div class="badge" style="background:rgba(52,209,131,.08); color:#b9ffe0;">Relaxed (25%)</div>
            </div>
            <div class="slider"></div>
            <div class="slider-labels">
              <span>Relaxed</span>
              <span>Balanced</span>
              <span>Aggressive</span>
            </div>
          </div>

          <div class="timeline-shell">
            <div class="timeline-head">
              <div>
                <div class="section-title" style="font-size:13px;">Cruise Timeline</div>
                <div class="section-note">This is the area that should own most of the vertical space.</div>
              </div>
              <div class="timeline-actions">
                <div class="muted" style="font-size:12px; font-weight:700;">Max hrs/day</div>
                <div class="select" style="width:88px; min-height:36px;"><span>6.5</span><span class="muted">▾</span></div>
                <div class="button slim primary" style="width:148px;">Rebuild Timeline</div>
              </div>
            </div>

            <div class="timeline-table">
              <table>
                <thead>
                  <tr>
                    <th style="width:50px;">#</th>
                    <th>Leg</th>
                    <th style="width:120px;">Locks</th>
                    <th style="width:120px;">NM</th>
                    <th style="width:160px;">Weather</th>
                    <th style="width:130px;">Geometry</th>
                  </tr>
                </thead>
                <tbody>
                  <tr>
                    <td class="dim">1</td>
                    <td>Tarpon Springs → Carrabelle</td>
                    <td>0</td>
                    <td>168.2</td>
                    <td class="warn">Moderate</td>
                    <td class="dim">Preview</td>
                  </tr>
                  <tr>
                    <td class="dim">2</td>
                    <td>Carrabelle → Panama City</td>
                    <td>0</td>
                    <td>106.4</td>
                    <td class="good">Low</td>
                    <td class="dim">Preview</td>
                  </tr>
                  <tr>
                    <td class="dim">3</td>
                    <td>Panama City → Mobile Bay</td>
                    <td>0</td>
                    <td>177.8</td>
                    <td class="warn">Moderate</td>
                    <td class="dim">Preview</td>
                  </tr>
                  <tr>
                    <td class="dim">4</td>
                    <td>Mobile Bay → Demopolis</td>
                    <td>1</td>
                    <td>145.9</td>
                    <td class="good">Low</td>
                    <td class="dim">Preview</td>
                  </tr>
                  <tr>
                    <td class="dim">5</td>
                    <td colspan="5" class="dim">Example rows only. The goal is to show how much more room the timeline gets after compressing the controls above.</td>
                  </tr>
                  <tr>
                    <td class="dim">6</td>
                    <td>Optional stop / detour row preview</td>
                    <td>0</td>
                    <td>62.0</td>
                    <td class="warn">Watch</td>
                    <td class="dim">Preview</td>
                  </tr>
                  <tr>
                    <td class="dim">7</td>
                    <td>Another leg preview row</td>
                    <td>0</td>
                    <td>84.3</td>
                    <td class="good">Low</td>
                    <td class="dim">Preview</td>
                  </tr>
                  <tr>
                    <td class="dim">8</td>
                    <td>Arrival segment preview</td>
                    <td>1</td>
                    <td>46.1</td>
                    <td class="warn">Moderate</td>
                    <td class="dim">Preview</td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
        </div>
      </section>
    </div>
  </div>
</body>
</html>