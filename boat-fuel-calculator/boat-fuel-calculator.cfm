<cfsetting showdebugoutput="false">
<cfcontent type="text/html; charset=utf-8">

<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Boat Fuel Calculator | FloatPlanWizard</title>

<meta name="description" content="Estimate your boat’s fuel burn, cruising range, fuel reserve, and approximate trip cost with the free boat fuel calculator from FloatPlanWizard.">

<link rel="canonical" href="https://floatplanwizard.com/boat-fuel-calculator/boat-fuel-calculator.cfm">
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.3/font/bootstrap-icons.min.css">
  <style>
    :root {
      --panel: rgba(11, 29, 43, 0.78);
      --radius-xl: 28px;
      --text: #eaf5ff;
      --muted: #a7c0d5;
      --soft: #7f9ab0;
      --accent: #47c7ff;
      --accent-2: #18f2d2;
      --line: rgba(130, 186, 226, 0.18);
      --shadow: 0 24px 80px rgba(0, 0, 0, 0.4);
    }
    * { box-sizing: border-box; }
    html { scroll-behavior: smooth; }
    a { color: inherit; text-decoration: none; }
    .shell {
      width: min(calc(100% - 32px), 1200px);
      margin: 0 auto;
    }
    .topbar {
      position: sticky;
      top: 0;
      z-index: 30;
      backdrop-filter: blur(18px);
      background: rgba(6, 17, 26, 0.68);
      border-bottom: 1px solid rgba(130, 186, 226, 0.12);
    }
    .promo-strip {
      border-bottom: 1px solid rgba(130, 186, 226, 0.1);
      background:
        linear-gradient(180deg, rgba(255,255,255,0.04), rgba(255,255,255,0.015));
      box-shadow: inset 0 -1px 0 rgba(255,255,255,0.02);
    }
    .promo-strip-inner {
      display: flex;
      align-items: center;
      justify-content: center;
      padding: 8px 0 7px;
      text-align: center;
    }
    .promo-strip-copy {
      margin: 0;
      color: rgba(234, 245, 255, 0.84);
      font-size: clamp(0.76rem, 1.4vw, 0.84rem);
      font-weight: 600;
      letter-spacing: 0.01em;
      line-height: 1.25;
      white-space: nowrap;
    }
    .promo-strip-copy strong {
      color: #f4fbff;
      font-weight: 700;
    }
    .topbar-inner {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 20px;
      padding: 14px 0;
    }
    .brand {
      display: flex;
      align-items: center;
      gap: 14px;
      min-width: 0;
    }
    .brand-mark {
      width: 42px;
      height: 42px;
      border-radius: 14px;
      background:
        linear-gradient(145deg, rgba(71,199,255,0.24), rgba(24,242,210,0.16));
      border: 1px solid rgba(130, 186, 226, 0.24);
      display: grid;
      place-items: center;
      box-shadow: inset 0 1px 0 rgba(255,255,255,0.08), 0 8px 28px rgba(0,0,0,0.28);
      position: relative;
      overflow: hidden;
    }
    .brand-mark::before {
      content: "";
      position: absolute;
      inset: 0;
      background:
        radial-gradient(circle at 30% 30%, rgba(255,255,255,0.08), transparent 0 38%),
        linear-gradient(180deg, transparent, rgba(255,255,255,0.02));
      pointer-events: none;
    }
    .brand-mark i {
      position: relative;
      z-index: 1;
      font-size: 1.2rem;
      color: #bceaff;
      filter: drop-shadow(0 0 12px rgba(71,199,255,0.45));
    }
    .brand-copy { min-width: 0; }
    .brand-name {
      font-size: 1rem;
      font-weight: 800;
      letter-spacing: 0.02em;
    }
    .brand-tag {
      color: var(--muted);
      font-size: 0.82rem;
      margin-top: 2px;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }
    .nav {
      display: flex;
      align-items: center;
      gap: 10px;
      flex-wrap: wrap;
      justify-content: flex-end;
    }
    .nav a {
      color: var(--muted);
      padding: 10px 14px;
      border-radius: 999px;
      font-size: 0.94rem;
      transition: 0.2s ease;
    }
    .nav a:hover { color: var(--text); background: rgba(130,186,226,0.08); }
    .btn {
      display: inline-flex;
      align-items: center;
      justify-content: center;
      gap: 10px;
      border: 0;
      border-radius: 999px;
      cursor: pointer;
      font-weight: 700;
      font-size: 0.98rem;
      padding: 7px 11px;
      transition: transform 0.18s ease, box-shadow 0.18s ease, background 0.18s ease;
      white-space: nowrap;
    }
    .btn:hover { transform: translateY(-1px); }
    .btn-secondary {
      color: var(--text);
      background: rgba(130,186,226,0.08);
      border: 1px solid rgba(130,186,226,0.16);
    }
    .btn i {
      font-size: 1rem;
      line-height: 1;
    }
    .panel {
      background: var(--panel);
      border: 1px solid var(--line);
      border-radius: var(--radius-xl);
      box-shadow: var(--shadow);
      backdrop-filter: blur(20px);
    }
    .fuelcalc-page {
      margin: 0;
      background:
        radial-gradient(1200px 520px at 10% -20%, rgba(53, 208, 200, 0.14), transparent 60%),
        radial-gradient(900px 480px at 95% 0%, rgba(74, 163, 255, 0.16), transparent 64%),
        linear-gradient(180deg, #041025 0%, #031020 100%);
      color: rgba(235, 244, 255, 0.94);
      font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
    }
    .fuelcalc-main { padding: 10px 0 18px; }
    .fuelcalc-main .wrap {
      max-width: 1240px;
      margin: 0 auto;
      background: linear-gradient(180deg, rgba(9, 24, 42, 0.96), rgba(5, 17, 32, 0.96));
      border: 1px solid rgba(82, 132, 204, 0.45);
      border-radius: 14px;
      padding: 20px;
      box-shadow: 0 22px 56px rgba(0, 0, 0, 0.42);
    }
    .fuelcalc-main h1 {
      margin-top: 0;
      margin-bottom: 10px;
      font-size: 34px;
      letter-spacing: 0.02em;
      color: #e8f2ff;
    }
    .fuelcalc-main .hint {
      color: rgba(206, 223, 244, 0.9);
      margin-bottom: 16px;
      font-size: 18px;
    }
    .fuelcalc-main .msg {
      margin-top: 12px;
      padding: 12px 14px;
      border-radius: 8px;
    }
    .fuelcalc-main .msg.info {
      background: rgba(42, 66, 110, 0.48);
      border: 1px solid rgba(131, 166, 224, 0.55);
      color: rgba(230, 241, 255, 0.96);
    }
    .fuelcalc-main .msg.warn {
      background: rgba(130,186,226,0.05);
      border: 1px solid rgba(130,186,226,0.12);
      color: var(--muted);
    }
    .fuelcalc-main .msg.warn strong,
    .fuelcalc-main .msg.warn ul {
      color: var(--text);
    }
    .fuelcalc-main .msg ul {
      margin: 8px 0 0 20px;
      padding: 0;
    }
    .fuelcalc-main .msg .msg-detail {
      margin-top: 8px;
    }
    .fuelcalc-main .grid {
      display: grid;
      grid-template-columns: repeat(2, minmax(0, 1fr));
      gap: 12px;
    }
    .fuelcalc-main .field {
      display: flex;
      flex-direction: column;
      gap: 6px;
    }
    .fuelcalc-main .field label {
      display: block !important;
      visibility: visible !important;
      opacity: 1 !important;
      font-size: 13px;
      font-weight: 700;
      text-transform: uppercase;
      letter-spacing: 0.08em;
      color: rgba(178, 216, 255, 0.96);
    }
    .fuelcalc-main .field input,
    .fuelcalc-main .field select {
      border: 1px solid rgba(117, 150, 205, 0.45);
      border-radius: 4px;
      font-size: 14px;
      padding: 8px;
      background: rgba(7, 20, 38, 0.88);
      color: rgba(233, 243, 255, 0.98);
    }
    .fuelcalc-main .field input[aria-invalid="true"] {
      border-color: rgba(117, 150, 205, 0.45);
      box-shadow: none;
    }
    .fuelcalc-main .field input::placeholder { color: rgba(175, 197, 230, 0.75); }
    .fuelcalc-main .field-note {
      font-size: 12px;
      color: rgba(184, 204, 236, 0.82);
      line-height: 1.4;
    }
    .fuelcalc-main .calc-actions {
      display: flex;
      gap: 8px;
      flex-wrap: wrap;
      margin-top: 14px;
    }
    .fuelcalc-main .calc-actions button {
      padding: 8px 12px;
      border-radius: 4px;
      border: 1px solid rgba(121, 151, 206, 0.55);
      background: rgba(7, 20, 38, 0.92);
      color: rgba(235, 244, 255, 0.95);
      cursor: pointer;
      font-size: 14px;
    }
    .fuelcalc-main .calc-actions button.primary {
      border-color: rgba(83, 174, 239, 0.9);
      background: linear-gradient(135deg, rgba(43, 129, 214, 0.95), rgba(57, 196, 232, 0.94));
      color: #041221;
    }
    .fuelcalc-main .cards {
      display: grid;
      grid-template-columns: repeat(3, minmax(0, 1fr));
      gap: 12px;
      margin-top: 16px;
    }
    .fuelcalc-main .card {
      background: linear-gradient(180deg, rgba(8, 25, 45, 0.92), rgba(5, 15, 30, 0.88));
      border: 1px solid rgba(88, 128, 189, 0.45);
      border-radius: 6px;
      padding: 12px;
    }
    .fuelcalc-main .card .label {
      font-size: 12px;
      text-transform: uppercase;
      letter-spacing: 0.07em;
      color: rgba(184, 204, 236, 0.82);
      margin-bottom: 6px;
    }
    .fuelcalc-main .card .value {
      font-size: 40px;
      font-weight: 800;
      line-height: 1.1;
      color: #f5fbff;
    }
    .fuelcalc-main .card .sub {
      margin-top: 4px;
      font-size: 12px;
      color: rgba(182, 204, 237, 0.86);
      line-height: 1.5;
    }
    .fuelcalc-main table {
      width: 100%;
      border-collapse: collapse;
      margin-top: 16px;
      font-size: 14px;
    }
    .fuelcalc-main th,
    .fuelcalc-main td {
      border: 1px solid rgba(85, 122, 180, 0.5);
      padding: 8px;
      text-align: left;
      vertical-align: top;
      color: rgba(226, 238, 255, 0.95);
    }
    .fuelcalc-main th { background: rgba(18, 40, 69, 0.88); }
    .fuelcalc-main td.num {
      text-align: right;
      font-family: Consolas, Menlo, Monaco, monospace;
    }
    .fuelcalc-main pre {
      margin-top: 16px;
      background: rgba(3, 11, 22, 0.95);
      border: 1px solid rgba(73, 115, 175, 0.45);
      color: #eef6ff;
      padding: 12px;
      border-radius: 6px;
      overflow: auto;
      font-size: 12px;
      line-height: 1.45;
    }
    @media (max-width: 900px) {
      .fuelcalc-main .grid,
      .fuelcalc-main .cards {
        grid-template-columns: 1fr;
      }
      .fuelcalc-main h1 { font-size: 30px; }
      .fuelcalc-main .card .value { font-size: 34px; }
    }
    @media (max-width: 780px) {
      .shell { width: min(calc(100% - 20px), 1200px); }
      .topbar-inner { align-items: flex-start; flex-direction: column; }
      .nav { width: 100%; justify-content: flex-start; }
    }
    @media (max-width: 560px) {
      .promo-strip-copy { white-space: normal; }
    }
    footer {
      padding: 0 0 27px;
    }
    .footer-card {
      padding: 26px;
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 16px;
      flex-wrap: wrap;
      background: rgba(8,19,28,0.95);
    }
    .footer-card p {
      margin: 0;
      color: var(--muted);
      line-height: 1.6;
    }
    .footer-card .footer-copyright {
      display: block;
      margin-top: 6px;
      color: var(--soft);
      font-size: 0.84rem;
    }
    .footer-links {
      display: flex;
      gap: 12px;
      flex-wrap: wrap;
      color: var(--soft);
      font-size: 0.9rem;
      letter-spacing: 0.01em;
    }
  </style>
</head>
<body class="fuelcalc-page">
  <header class="topbar">
    <div class="promo-strip">
      <div class="shell promo-strip-inner">
        <p class="promo-strip-copy">Join prelaunch &mdash; get <strong>2 months of Premium free</strong></p>
      </div>
    </div>
    <div class="shell topbar-inner">
      <a href="/preLaunch.cfm#top" class="brand" aria-label="FloatPlanWizard home">
        <div class="brand-mark"><i class="bi bi-compass-fill" aria-hidden="true"></i></div>
        <div class="brand-copy">
          <div class="brand-name">FloatPlanWizard</div>
          <div class="brand-tag">Built for serious recreational boaters</div>
        </div>
      </a>
      <nav class="nav" aria-label="Primary">
        <a href="/preLaunch.cfm#features">Features</a>
        <a href="/preLaunch.cfm#great-loop">Great Loop</a>
        <a href="/preLaunch.cfm#followers">Share the Trip</a>
        <a href="/preLaunch.cfm#story">Why FPW</a>
        <a href="/boat-fuel-calculator/boat-fuel-calculator.cfm" class="btn btn-secondary">Fuel Calculator</a>
        <a href="/preLaunch.cfm#notify" class="btn btn-secondary"><i class="bi bi-bell"></i>Get Notified</a>
      </nav>
    </div>
  </header>
  <main class="fuelcalc-main">
    <div class="wrap shell">
      <h1>Boat Fuel Calculator</h1>
     

     <!--- <div class="msg info">
        <strong>Notes</strong>
        <ul>
          <li>Manual only. No vessel lookup, route template, or saved FPW data is required.</li>
          <li>Balanced pace uses <strong>Most Efficient Speed</strong> and <strong>GPH @ Efficient</strong> when supplied.</li>
          <li>Relaxed and Aggressive use <strong>Fuel Burn @ Max</strong> and switch to the Route Generator anchored-burn model when both efficient anchors are present.</li>
          <li>Lock and offshore counts are not calculated here because this standalone page has no route geometry input.</li>
        </ul>
      </div>--->

      <form id="qaFuelCalcForm" onsubmit="return false;">
        <div class="grid">
          <div class="field">
            <label for="totalNm">Total distance (NM)</label>
            <input id="totalNm" name="totalNm" type="number" step="0.1" min="0" value="" placeholder="Enter NM">
          </div>
          <div class="field">
            <label for="pace">Pace</label>
            <select id="pace" name="pace">
              <option value="RELAXED">Relaxed</option>
              <option value="BALANCED">Efficient Speed</option>
              <option value="AGGRESSIVE">Max Speed</option>
            </select>
          </div>
          <div class="field">
            <label for="mostEfficientSpeedKn">Most Efficient Speed (kn)</label>
            <input id="mostEfficientSpeedKn" name="mostEfficientSpeedKn" type="number" step="0.1" min="1" max="60" value="" placeholder="Required" required aria-describedby="requiredEfficientInputsMsg">
          </div>
          <div class="field">
            <label for="fuelBurnEfficientGph">GPH @ Efficient</label>
            <input id="fuelBurnEfficientGph" name="fuelBurnEfficientGph" type="number" step="0.1" min="0" value="" placeholder="Required" required aria-describedby="requiredEfficientInputsMsg">
          </div>
          <div class="field">
            <label for="maxSpeedKn">Max Speed (kn)</label>
            <input id="maxSpeedKn" name="maxSpeedKn" type="number" step="0.1" min="1" max="60" value="" placeholder="Required" aria-describedby="requiredEfficientInputsMsg">
          </div>
          <div class="field">
            <label for="fuelBurnGph">Fuel Burn @ Max (GPH)</label>
            <input id="fuelBurnGph" name="fuelBurnGph" type="number" step="0.1" min="0" value="" placeholder="Required for Relaxed or Max Speed" aria-describedby="requiredEfficientInputsMsg">
            <div class="field-note">Matches the Route Generator max-speed burn input. Pace and weather adjustments are derived from this value unless Balanced pace uses the efficient inputs instead.</div>
          </div>
          <div class="field">
            <label for="idleBurnGph">Idle Burn (GPH)</label>
            <input id="idleBurnGph" name="idleBurnGph" type="number" step="0.1" min="0" value="" placeholder="Optional">
          </div>
          <div class="field">
            <label for="idleHoursTotal">Idle Hours (total)</label>
            <input id="idleHoursTotal" name="idleHoursTotal" type="number" step="0.1" min="0" value="" placeholder="Optional">
          </div>
          <div class="field">
            <label for="weatherPct">Weather Factor (%)</label>
            <input id="weatherPct" name="weatherPct" type="number" step="1" min="0" max="60" value="0">
          </div>
          <div class="field">
            <label for="reservePct">Reserve (%)</label>
            <select id="reservePct" name="reservePct">
              <option value="33" selected>Rule of Thirds - 33%</option>
              <option value="20">Standard Reserve - 20%</option>
              <option value="15">Minimum Reserve - 15%</option>
            </select>
          </div>
          <div class="field">
            <label for="underwayHoursPerDay">Underway Hrs / Day</label>
            <input id="underwayHoursPerDay" name="underwayHoursPerDay" type="number" step="0.5" min="1" max="24" value="6.5">
          </div>
          <div class="field">
            <label for="fuelPricePerGal">Fuel Price ($/gal)</label>
            <input id="fuelPricePerGal" name="fuelPricePerGal" type="number" step="0.01" min="0" value="" placeholder="Optional">
          </div>
        </div>

        <div class="calc-actions">
          <button type="button" id="resetBtn">Reset</button>
          <button type="button" id="copyJsonBtn">Copy Result JSON</button>
        </div>
      </form>

      <div id="requiredEfficientInputsMsg" class="msg warn" hidden></div>

      <div class="cards">
        <div class="card">
          <div class="label">Total Distance</div>
          <div class="value" id="cardTotalDistance">0.0 NM</div>
          <div class="sub" id="cardTotalDistanceSub">Manual distance input</div>
        </div>
        <div class="card">
          <div class="label">Total Travel Hours</div>
          <div class="value" id="cardTotalHours">-- h</div>
          <div class="sub" id="cardTotalHoursSub">Enter distance and fuel inputs.</div>
        </div>
        <div class="card">
          <div class="label">Estimated Fuel</div>
          <div class="value" id="cardEstimatedFuel">-- gal</div>
          <div class="sub" id="cardEstimatedFuelSub">Required + reserve</div>
        </div>
        <div class="card">
          <div class="label">Adjusted Speed</div>
          <div class="value" id="cardAdjustedSpeed">-- kn</div>
          <div class="sub" id="cardAdjustedSpeedSub">Pace + weather adjusted</div>
        </div>
        <div class="card">
          <div class="label">Expected Avg GPH</div>
          <div class="value" id="cardExpectedAvgGph">-- GPH</div>
          <div class="sub" id="cardExpectedAvgGphSub">Current pace + weather burn</div>
        </div>
        <div class="card">
          <div class="label">Fuel Cost</div>
          <div class="value" id="cardFuelCost">--</div>
          <div class="sub" id="cardFuelCostSub">Enter fuel price to estimate</div>
        </div>
      </div>

      <table>
        <thead>
          <tr>
            <th>Metric</th>
            <th>Value</th>
            <th>How computed</th>
          </tr>
        </thead>
        <tbody id="calcBreakdownBody"></tbody>
      </table>

      <pre id="calcJsonOut">{}</pre>
    </div>
  </main>

  <footer>
    <div class="shell">
      <div class="panel footer-card">
        <p><strong>FloatPlanWizard</strong><br />Plan the voyage. Share the journey. Keep everyone informed.<br /><span class="footer-copyright">&copy; 2026 FloatPlanWizard. All rights reserved.</span></p>
        <div class="footer-links">
          <span>Launching Spring 2026</span>
          <span>Built for Great Loopers and serious recreational boaters</span>
        </div>
      </div>
    </div>
  </footer>

  <script>
    (function () {
      var DEFAULT_MAX_SPEED_KN = 20;
      var DEFAULT_UNDERWAY_HOURS_PER_DAY = 6.5;
      var DEFAULT_RESERVE_PCT = 33;
      var LOW_SPEED_ANCHOR_KN = 3.5;
      var PACE_PRESETS = {
        RELAXED: { key: "RELAXED", label: "Relaxed", factor: 0.25 },
        BALANCED: { key: "BALANCED", label: "Efficient Speed", factor: 0.50 },
        AGGRESSIVE: { key: "AGGRESSIVE", label: "Max Speed", factor: 1.00 }
      };

      function q(id) {
        return document.getElementById(id);
      }

      function safeNum(value) {
        var n = parseFloat(value);
        return Number.isFinite(n) ? n : null;
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
        var n = safeNum(value);
        var places = (typeof decimals === "number") ? decimals : 2;
        if (n === null) return (fallbackText !== undefined ? String(fallbackText) : "--");
        return n.toLocaleString(undefined, {
          minimumFractionDigits: places,
          maximumFractionDigits: places
        });
      }

      function formatCurrency(value, fallbackText) {
        var n = safeNum(value);
        if (n === null) return (fallbackText !== undefined ? String(fallbackText) : "--");
        return "$" + n.toLocaleString(undefined, {
          minimumFractionDigits: 2,
          maximumFractionDigits: 2
        });
      }

      function normalizePaceKey(value) {
        var key = String(value || "").trim().toUpperCase();
        if (key === "BALANCED") return "BALANCED";
        if (key === "AGGRESSIVE") return "AGGRESSIVE";
        return "RELAXED";
      }

      function getPacePreset(value) {
        var key = normalizePaceKey(value);
        return PACE_PRESETS[key] || PACE_PRESETS.RELAXED;
      }

      function normalizeCruisingSpeed(value, defaultSpeedKn) {
        var speedVal = safeNum(value);
        var fallbackVal = safeNum(defaultSpeedKn);
        if (fallbackVal === null || fallbackVal <= 0) fallbackVal = DEFAULT_MAX_SPEED_KN;
        if (speedVal === null || speedVal <= 0) speedVal = fallbackVal;
        if (speedVal < 1) speedVal = 1;
        if (speedVal > 60) speedVal = 60;
        return roundTo2(speedVal);
      }

      function normalizePositiveSpeed(value) {
        var speedVal = safeNum(value);
        if (speedVal === null || speedVal <= 0) return 0;
        if (speedVal > 60) speedVal = 60;
        return roundTo2(speedVal);
      }

      function normalizeUnderwayHours(value) {
        var hoursVal = safeNum(value);
        if (hoursVal === null || hoursVal <= 0) hoursVal = DEFAULT_UNDERWAY_HOURS_PER_DAY;
        if (hoursVal < 1) hoursVal = 1;
        if (hoursVal > 24) hoursVal = 24;
        return roundTo2(hoursVal);
      }

      function normalizeFuelBurnGph(value) {
        var burnVal = safeNum(value);
        if (burnVal === null || burnVal <= 0) return 0;
        if (burnVal > 1000) burnVal = 1000;
        return roundTo2(burnVal);
      }

      function normalizeIdleHoursTotal(value) {
        var hoursVal = safeNum(value);
        if (hoursVal === null || hoursVal <= 0) return 0;
        if (hoursVal > 10000) hoursVal = 10000;
        return roundTo2(hoursVal);
      }

      function normalizeWeatherFactorPct(value) {
        var pctVal = safeNum(value);
        if (pctVal === null) return 0;
        if (pctVal < 0) pctVal = 0;
        if (pctVal > 60) pctVal = 60;
        return roundTo2(pctVal);
      }

      function normalizeReservePct(value, defaultPct) {
        var pctVal = safeNum(value);
        if (pctVal === null) pctVal = safeNum(defaultPct);
        if (pctVal === null) pctVal = DEFAULT_RESERVE_PCT;
        if (pctVal < 0) pctVal = 0;
        if (pctVal > 100) pctVal = 100;
        return roundTo2(pctVal);
      }

      function normalizeFuelPricePerGal(value) {
        var priceVal = safeNum(value);
        if (priceVal === null || priceVal <= 0) return 0;
        if (priceVal > 1000) priceVal = 1000;
        return roundTo2(priceVal);
      }

      function paceAdjustedBurnGph(maxBurnGph, paceRatio, burnExponent) {
        var maxBurnVal = normalizeFuelBurnGph(maxBurnGph);
        var ratioVal = safeNum(paceRatio);
        var expVal = safeNum(burnExponent);
        if (maxBurnVal <= 0) return 0;
        if (expVal === null || expVal < 1) expVal = 1;
        if (expVal > 6) expVal = 6;
        if (ratioVal === null || ratioVal <= 0) ratioVal = 1;
        if (ratioVal < 0.05) ratioVal = 0.05;
        if (ratioVal > 1) ratioVal = 1;
        return roundTo2(maxBurnVal * Math.pow(ratioVal, expVal));
      }

      function anchoredBurnInputsValid(maxSpeedKn, maxBurnGph, efficientSpeedKn, efficientBurnGph) {
        var maxSpeedVal = normalizeCruisingSpeed(maxSpeedKn, DEFAULT_MAX_SPEED_KN);
        var maxBurnVal = normalizeFuelBurnGph(maxBurnGph);
        var efficientSpeedVal = normalizePositiveSpeed(efficientSpeedKn);
        var efficientBurnVal = normalizeFuelBurnGph(efficientBurnGph);
        if (maxSpeedVal <= 0) return false;
        if (maxBurnVal <= 0) return false;
        if (efficientSpeedVal <= LOW_SPEED_ANCHOR_KN) return false;
        if (efficientBurnVal <= 0) return false;
        if (maxSpeedVal < efficientSpeedVal) return false;
        return true;
      }

      function anchoredBurnAtSpeedGph(effectiveSpeedKn, maxSpeedKn, maxBurnGph, efficientSpeedKn, efficientBurnGph) {
        var speedVal = safeNum(effectiveSpeedKn);
        var maxSpeedVal = normalizeCruisingSpeed(maxSpeedKn, DEFAULT_MAX_SPEED_KN);
        var maxBurnVal = normalizeFuelBurnGph(maxBurnGph);
        var efficientSpeedVal = normalizePositiveSpeed(efficientSpeedKn);
        var efficientBurnVal = normalizeFuelBurnGph(efficientBurnGph);
        var lowBurnVal = efficientBurnVal * 0.25;
        var factorVal = 0;

        if (!anchoredBurnInputsValid(maxSpeedVal, maxBurnVal, efficientSpeedVal, efficientBurnVal)) {
          return 0;
        }

        if (speedVal === null || speedVal <= LOW_SPEED_ANCHOR_KN) {
          return roundTo2(lowBurnVal);
        }
        if (speedVal < efficientSpeedVal) {
          factorVal = (speedVal - LOW_SPEED_ANCHOR_KN) / (efficientSpeedVal - LOW_SPEED_ANCHOR_KN);
          return roundTo2(lowBurnVal + ((efficientBurnVal - lowBurnVal) * factorVal));
        }
        if (speedVal <= efficientSpeedVal) {
          return roundTo2(efficientBurnVal);
        }
        if (speedVal < maxSpeedVal) {
          factorVal = (speedVal - efficientSpeedVal) / (maxSpeedVal - efficientSpeedVal);
          return roundTo2(efficientBurnVal + ((maxBurnVal - efficientBurnVal) * factorVal));
        }
        return roundTo2(maxBurnVal);
      }

      function computeEffectiveCruisingSpeed(maxSpeedKn, pace, mostEfficientSpeedKn) {
        var pacePreset = getPacePreset(pace);
        var maxSpeedVal = normalizeCruisingSpeed(maxSpeedKn, DEFAULT_MAX_SPEED_KN);
        var mostEffVal = normalizePositiveSpeed(mostEfficientSpeedKn);
        var factorVal = safeNum(pacePreset.factor);
        var effectiveSpeed = 0;

        if (pacePreset.key === "BALANCED" && mostEffVal >= 1) {
          return roundTo2(mostEffVal);
        }
        if (factorVal === null || factorVal <= 0) factorVal = 0.25;
        effectiveSpeed = maxSpeedVal * factorVal;
        if (effectiveSpeed < 1) effectiveSpeed = 1;
        return roundTo2(effectiveSpeed);
      }

      function readInputNumber(id) {
        var el = q(id);
        if (!el) return null;
        var raw = String(el.value || "").trim();
        if (!raw.length) return null;
        return safeNum(raw);
      }

      function getInputs() {
        return {
          distanceNm: readInputNumber("totalNm"),
          pace: normalizePaceKey(q("pace") ? q("pace").value : "RELAXED"),
          mostEfficientSpeedKn: readInputNumber("mostEfficientSpeedKn"),
          fuelBurnEfficientGph: readInputNumber("fuelBurnEfficientGph"),
          maxSpeedKn: readInputNumber("maxSpeedKn"),
          fuelBurnGph: readInputNumber("fuelBurnGph"),
          idleBurnGph: readInputNumber("idleBurnGph"),
          idleHoursTotal: readInputNumber("idleHoursTotal"),
          weatherPct: readInputNumber("weatherPct"),
          reservePct: readInputNumber("reservePct"),
          underwayHoursPerDay: readInputNumber("underwayHoursPerDay"),
          fuelPricePerGal: readInputNumber("fuelPricePerGal")
        };
      }

      function buildModel(inputs) {
        var pacePreset = getPacePreset(inputs.pace);
        var distanceNm = safeNum(inputs.distanceNm);
        var maxSpeedKn = (safeNum(inputs.maxSpeedKn) !== null && safeNum(inputs.maxSpeedKn) > 0)
          ? normalizeCruisingSpeed(inputs.maxSpeedKn, DEFAULT_MAX_SPEED_KN)
          : null;
        var mostEfficientSpeedKn = normalizePositiveSpeed(inputs.mostEfficientSpeedKn);
        var efficientBurnGph = normalizeFuelBurnGph(inputs.fuelBurnEfficientGph);
        var maxBurnGph = normalizeFuelBurnGph(inputs.fuelBurnGph);
        var idleBurnGph = normalizeFuelBurnGph(inputs.idleBurnGph);
        var idleHoursTotal = normalizeIdleHoursTotal(inputs.idleHoursTotal);
        var weatherPct = normalizeWeatherFactorPct(inputs.weatherPct);
        var reservePct = normalizeReservePct(inputs.reservePct, DEFAULT_RESERVE_PCT);
        var fuelPricePerGal = normalizeFuelPricePerGal(inputs.fuelPricePerGal);
        var underwayHoursPerDay = normalizeUnderwayHours(inputs.underwayHoursPerDay);
        var missingRequiredInputs = [];
        var effectiveSpeedKn = null;
        var paceRatio = null;
        var paceAdjustedBurn = null;
        var weatherAdjustedBurn = null;
        var weatherAdjustedSpeedKn = null;
        var cruiseHours = null;
        var cruiseFuelGallons = null;
        var idleFuelGallons = null;
        var baseFuelGallons = null;
        var reserveGallons = null;
        var requiredFuelGallons = null;
        var totalFuelCost = null;
        var totalTravelHours = null;
        var estimatedDays = null;
        var weatherAdj = weatherPct / 100;
        var hasRequiredInputs = false;
        var usesAnchoredBurn = false;
        var canEstimateFuel = false;
        var fuelMode = "required inputs missing";

        if (mostEfficientSpeedKn <= 0) missingRequiredInputs.push("Most Efficient Speed (kn)");
        if (efficientBurnGph <= 0) missingRequiredInputs.push("GPH @ Efficient");
        if (pacePreset.key !== "BALANCED" && (maxSpeedKn === null || maxSpeedKn <= 0)) {
          missingRequiredInputs.push("Max Speed (kn)");
        }
        if (pacePreset.key !== "BALANCED" && maxBurnGph <= 0) {
          missingRequiredInputs.push("Fuel Burn @ Max (GPH)");
        }
        hasRequiredInputs = (missingRequiredInputs.length === 0);

        if (hasRequiredInputs) {
          effectiveSpeedKn = computeEffectiveCruisingSpeed(maxSpeedKn, pacePreset.key, mostEfficientSpeedKn);
          usesAnchoredBurn = anchoredBurnInputsValid(maxSpeedKn, maxBurnGph, mostEfficientSpeedKn, efficientBurnGph);
          fuelMode = "unavailable";
        }

        if (hasRequiredInputs) {
          if (pacePreset.key === "BALANCED") {
            if (maxSpeedKn !== null && maxSpeedKn > 0 && effectiveSpeedKn > 0) {
              paceRatio = roundTo2(effectiveSpeedKn / maxSpeedKn);
            }
            if (efficientBurnGph > 0) {
              paceAdjustedBurn = roundTo2(efficientBurnGph);
              weatherAdjustedBurn = roundTo2(paceAdjustedBurn * (1 + weatherAdj));
              canEstimateFuel = true;
              fuelMode = "efficient";
            }
          } else {
            paceRatio = roundTo2(pacePreset.factor);
            if (usesAnchoredBurn) {
              paceAdjustedBurn = anchoredBurnAtSpeedGph(
                effectiveSpeedKn,
                maxSpeedKn,
                maxBurnGph,
                mostEfficientSpeedKn,
                efficientBurnGph
              );
              fuelMode = "anchored";
            } else {
              paceAdjustedBurn = paceAdjustedBurnGph(maxBurnGph, pacePreset.factor, 3.0);
              fuelMode = "pace_adjusted";
            }
            weatherAdjustedBurn = roundTo2(paceAdjustedBurn * (1 + weatherAdj));
            canEstimateFuel = true;
          }

          weatherAdjustedSpeedKn = roundTo2(effectiveSpeedKn * (1 - weatherAdj));
          if (weatherAdjustedSpeedKn < 0.5) weatherAdjustedSpeedKn = 0.5;

          if (distanceNm !== null && distanceNm > 0 && canEstimateFuel) {
            cruiseHours = roundTo2(distanceNm / weatherAdjustedSpeedKn);
            cruiseFuelGallons = roundTo2(cruiseHours * weatherAdjustedBurn);
          } else {
            cruiseHours = 0;
            cruiseFuelGallons = 0;
          }

          idleFuelGallons = (idleBurnGph > 0 && idleHoursTotal > 0)
            ? roundTo1(idleBurnGph * idleHoursTotal)
            : 0;

          baseFuelGallons = roundTo2(cruiseFuelGallons + idleFuelGallons);
          reserveGallons = roundTo2(baseFuelGallons * (reservePct / 100));
          requiredFuelGallons = roundTo2(baseFuelGallons + reserveGallons);
          totalFuelCost = (fuelPricePerGal > 0)
            ? Math.round((requiredFuelGallons * fuelPricePerGal) * 100) / 100
            : 0;
          totalTravelHours = roundTo2(cruiseHours + idleHoursTotal);

          if (totalTravelHours > 0) {
            estimatedDays = Math.ceil(totalTravelHours / underwayHoursPerDay);
            if (estimatedDays < 1) estimatedDays = 1;
          } else {
            estimatedDays = 0;
          }
        }

        return {
          inputs: {
            distanceNm: distanceNm,
            pace: pacePreset.key,
            maxSpeedKn: maxSpeedKn,
            mostEfficientSpeedKn: mostEfficientSpeedKn,
            fuelBurnEfficientGph: efficientBurnGph,
            fuelBurnGph: maxBurnGph,
            idleBurnGph: idleBurnGph,
            idleHoursTotal: idleHoursTotal,
            weatherPct: weatherPct,
            reservePct: reservePct,
            underwayHoursPerDay: underwayHoursPerDay,
            fuelPricePerGal: fuelPricePerGal
          },
          derived: {
            paceLabel: pacePreset.label,
            paceRatio: paceRatio,
            effectiveSpeedKn: effectiveSpeedKn,
            weatherAdjustedSpeedKn: weatherAdjustedSpeedKn,
            paceAdjustedBurnGph: (paceAdjustedBurn === null ? null : roundTo2(paceAdjustedBurn)),
            weatherAdjustedBurnGph: (weatherAdjustedBurn === null ? null : roundTo2(weatherAdjustedBurn)),
            cruiseHours: cruiseHours,
            cruiseFuelGallons: cruiseFuelGallons,
            idleFuelGallons: (idleFuelGallons === null ? null : roundTo2(idleFuelGallons)),
            baseFuelGallons: baseFuelGallons,
            reserveGallons: reserveGallons,
            requiredFuelGallons: requiredFuelGallons,
            totalFuelCost: (totalFuelCost === null ? null : roundTo2(totalFuelCost)),
            totalTravelHours: totalTravelHours,
            estimatedDays: estimatedDays,
            usesAnchoredBurn: usesAnchoredBurn,
            fuelMode: fuelMode,
            canEstimateFuel: canEstimateFuel,
            missingRequiredInputs: missingRequiredInputs
          }
        };
      }

      function renderRequiredEfficientInputsMessage(model) {
        var derived = model.derived || {};
        var msgEl = q("requiredEfficientInputsMsg");
        var missingRequiredInputs = derived.missingRequiredInputs || [];
        if (!msgEl) return;
        if (!missingRequiredInputs.length) {
          msgEl.hidden = true;
          msgEl.innerHTML = "";
          return;
        }
        msgEl.hidden = false;
        msgEl.innerHTML = "<strong>Required Inputs</strong>"
          + "<ul>"
          + missingRequiredInputs.map(function (label) {
            return "<li>" + label + "</li>";
          }).join("")
          + "</ul>"
          + "<div class=\"msg-detail\">This standalone calculator will not estimate fuel until all required inputs for the selected pace are entered.</div>";
      }

      function renderRequiredEfficientInputState(model) {
        var derived = model.derived || {};
        var missingRequiredInputs = derived.missingRequiredInputs || [];
        var mostEfficientMissing = missingRequiredInputs.indexOf("Most Efficient Speed (kn)") !== -1;
        var efficientBurnMissing = missingRequiredInputs.indexOf("GPH @ Efficient") !== -1;
        var maxSpeedMissing = missingRequiredInputs.indexOf("Max Speed (kn)") !== -1;
        var maxBurnMissing = missingRequiredInputs.indexOf("Fuel Burn @ Max (GPH)") !== -1;
        q("mostEfficientSpeedKn").setAttribute("aria-invalid", mostEfficientMissing ? "true" : "false");
        q("fuelBurnEfficientGph").setAttribute("aria-invalid", efficientBurnMissing ? "true" : "false");
        q("maxSpeedKn").setAttribute("aria-invalid", maxSpeedMissing ? "true" : "false");
        q("fuelBurnGph").setAttribute("aria-invalid", maxBurnMissing ? "true" : "false");
      }

      function renderCards(model) {
        var inputs = model.inputs || {};
        var derived = model.derived || {};
        var hasFuelEstimate = !!derived.canEstimateFuel;
        var hasDistance = safeNum(inputs.distanceNm) !== null && inputs.distanceNm > 0;
        var missingRequiredInputs = derived.missingRequiredInputs || [];

        q("cardTotalDistance").textContent = formatNum(inputs.distanceNm, 1, "0.0") + " NM";
        q("cardTotalDistanceSub").textContent = "Manual distance input";

        if (hasDistance && hasFuelEstimate && derived.totalTravelHours > 0) {
          q("cardTotalHours").textContent = formatNum(derived.totalTravelHours, 1, "--") + " h";
          q("cardTotalHoursSub").textContent = "Cruise " + formatNum(derived.cruiseHours, 1, "0.0")
            + "h + Idle " + formatNum(inputs.idleHoursTotal, 1, "0.0")
            + "h | " + String(derived.estimatedDays) + " day(s) @ "
            + formatNum(inputs.underwayHoursPerDay, 1, "6.5") + "h/day";
        } else {
          q("cardTotalHours").textContent = "-- h";
          q("cardTotalHoursSub").textContent = "Enter distance and fuel inputs.";
        }

        if (hasDistance && hasFuelEstimate) {
          q("cardEstimatedFuel").textContent = formatNum(derived.requiredFuelGallons, 1, "--") + " gal";
          q("cardEstimatedFuelSub").textContent = "Base " + formatNum(derived.baseFuelGallons, 1, "0.0")
            + " + Reserve (" + formatNum(inputs.reservePct, 0, "33") + "%) "
            + formatNum(derived.reserveGallons, 1, "0.0");
        } else {
          q("cardEstimatedFuel").textContent = "-- gal";
          q("cardEstimatedFuelSub").textContent = "Required + reserve";
        }

        if (hasFuelEstimate) {
          q("cardAdjustedSpeed").textContent = formatNum(derived.weatherAdjustedSpeedKn, 2, "--") + " kn";
          q("cardAdjustedSpeedSub").textContent = "Pace + weather adjusted";
          q("cardExpectedAvgGph").textContent = formatNum(derived.weatherAdjustedBurnGph, 2, "--") + " GPH";
          q("cardExpectedAvgGphSub").textContent = "Current pace + weather burn";
        } else {
          q("cardAdjustedSpeed").textContent = "-- kn";
          q("cardAdjustedSpeedSub").textContent = missingRequiredInputs.length
            ? "Waiting for the required inputs for this pace"
            : "Adjusted speed unavailable";
          q("cardExpectedAvgGph").textContent = "-- GPH";
          q("cardExpectedAvgGphSub").textContent = missingRequiredInputs.length
            ? "Complete the required inputs for this pace"
            : "Provide the burn inputs for this pace";
        }

        if (hasDistance && hasFuelEstimate && inputs.fuelPricePerGal > 0) {
          q("cardFuelCost").textContent = formatCurrency(derived.totalFuelCost, "--");
          q("cardFuelCostSub").textContent = "Required fuel x $" + formatNum(inputs.fuelPricePerGal, 2, "0.00") + "/gal";
        } else {
          q("cardFuelCost").textContent = "--";
          q("cardFuelCostSub").textContent = "Enter fuel price to estimate";
        }
      }

      function renderBreakdown(model) {
        var inputs = model.inputs || {};
        var derived = model.derived || {};
        var rows = [
          ["Pace", String(derived.paceLabel || "--"), "Route Generator pace preset"],
          ["Pace ratio", formatNum(derived.paceRatio, 2, "--"), "Relaxed=0.25, Balanced=efficient speed / max speed, Max Speed=1.00"],
          ["Max speed (kn)", formatNum(inputs.maxSpeedKn, 2, "--"), "Normalized to the Route Generator 1-60 kn range"],
          ["Most efficient speed (kn)", formatNum(inputs.mostEfficientSpeedKn, 2, "--"), "Used directly for Balanced pace when supplied"],
          ["Effective speed (kn)", formatNum(derived.effectiveSpeedKn, 2, "--"), "Balanced uses Most Efficient Speed. Other paces use max speed x pace ratio"],
          ["Weather-adjusted speed (kn)", formatNum(derived.weatherAdjustedSpeedKn, 2, "--"), "effective speed x (1 - weather factor) with a 0.5 kn floor"],
          ["Fuel mode", String(derived.fuelMode || "--"), derived.usesAnchoredBurn ? "Anchored model uses low-speed, efficient, and max-speed anchors" : "Route Generator fuel mode"],
          ["Fuel burn @ max (GPH)", formatNum(inputs.fuelBurnGph, 2, "--"), "Required for Relaxed or Max Speed"],
          ["GPH @ efficient", formatNum(inputs.fuelBurnEfficientGph, 2, "--"), "Required on this standalone calculator"],
          ["Pace-adjusted burn (GPH)", formatNum(derived.paceAdjustedBurnGph, 2, "--"), derived.usesAnchoredBurn ? "Anchored interpolation between low, efficient, and max-speed burn anchors" : "Max burn x pace ratio^3 or Balanced efficient burn"],
          ["Weather-adjusted burn (GPH)", formatNum(derived.weatherAdjustedBurnGph, 2, "--"), "pace-adjusted burn x (1 + weather factor)"],
          ["Cruise hours", formatNum(derived.cruiseHours, 2, "--"), "distance / weather-adjusted speed"],
          ["Idle fuel (gal)", formatNum(derived.idleFuelGallons, 2, "--"), "idle burn x idle hours, rounded to the Route Generator preview precision"],
          ["Base fuel (gal)", formatNum(derived.baseFuelGallons, 2, "--"), "cruise fuel + idle fuel"],
          ["Reserve fuel (gal)", formatNum(derived.reserveGallons, 2, "--"), "base fuel x reserve percent"],
          ["Required fuel (gal)", formatNum(derived.requiredFuelGallons, 2, "--"), "base fuel + reserve"],
          ["Fuel cost (USD)", formatCurrency(derived.totalFuelCost, "--"), "required fuel x price per gallon"],
          ["Estimated days", (derived.estimatedDays === null || derived.estimatedDays === undefined) ? "--" : String(derived.estimatedDays), "ceil(total travel hours / underway hours per day)"]
        ];

        q("calcBreakdownBody").innerHTML = rows.map(function (row) {
          return "<tr>"
            + "<td>" + row[0] + "</td>"
            + "<td class=\"num\">" + row[1] + "</td>"
            + "<td>" + row[2] + "</td>"
            + "</tr>";
        }).join("");
      }

      function renderJson(model) {
        q("calcJsonOut").textContent = JSON.stringify({
          route_generator_source_of_truth: {
            pace_formula: "routegenNormalizePace + routegenPaceDefaults + routegenComputeEffectiveCruisingSpeed",
            burn_formula: "calculateFuelEstimate + routegenAnchoredBurnGph",
            reserve_default_pct: DEFAULT_RESERVE_PCT
          },
          standalone_inputs: model.inputs,
          derived: model.derived,
          cards: {
            total_distance_nm: model.inputs.distanceNm,
            total_travel_hours: model.derived.totalTravelHours,
            estimated_fuel_gallons: model.derived.requiredFuelGallons,
            adjusted_speed_kn: model.derived.weatherAdjustedSpeedKn,
            expected_avg_gph: model.derived.weatherAdjustedBurnGph,
            fuel_cost_usd: model.derived.totalFuelCost
          }
        }, null, 2);
      }

      function run() {
        var model = buildModel(getInputs());
        q("maxSpeedKn").placeholder = (model.inputs && model.inputs.pace === "BALANCED") ? "" : "Required";
        renderRequiredEfficientInputsMessage(model);
        renderRequiredEfficientInputState(model);
        renderCards(model);
        renderBreakdown(model);
        renderJson(model);
      }

      function resetInputs() {
        q("totalNm").value = "";
        q("pace").value = "RELAXED";
        q("mostEfficientSpeedKn").value = "";
        q("fuelBurnEfficientGph").value = "";
        q("maxSpeedKn").value = "";
        q("fuelBurnGph").value = "";
        q("idleBurnGph").value = "";
        q("idleHoursTotal").value = "";
        q("weatherPct").value = "0";
        q("reservePct").value = "33";
        q("underwayHoursPerDay").value = "6.5";
        q("fuelPricePerGal").value = "";
        run();
      }

      q("resetBtn").addEventListener("click", resetInputs);
      q("copyJsonBtn").addEventListener("click", function () {
        var text = q("calcJsonOut").textContent || "";
        if (navigator.clipboard && navigator.clipboard.writeText) {
          navigator.clipboard.writeText(text);
        }
      });

      [
        "totalNm",
        "pace",
        "mostEfficientSpeedKn",
        "fuelBurnEfficientGph",
        "maxSpeedKn",
        "fuelBurnGph",
        "idleBurnGph",
        "idleHoursTotal",
        "weatherPct",
        "reservePct",
        "underwayHoursPerDay",
        "fuelPricePerGal"
      ].forEach(function (id) {
        var el = q(id);
        if (!el) return;
        el.addEventListener("input", run);
        el.addEventListener("change", run);
      });

      resetInputs();
    })();
  </script>
</body>
</html>
