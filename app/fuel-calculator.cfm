<cfsetting showdebugoutput="false">
<cfcontent type="text/html; charset=utf-8">

<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Fuel Calculator</title>
  <style>
    .fuelcalc-page {
      margin: 0;
      background:
        radial-gradient(1200px 520px at 10% -20%, rgba(53, 208, 200, 0.14), transparent 60%),
        radial-gradient(900px 480px at 95% 0%, rgba(74, 163, 255, 0.16), transparent 64%),
        linear-gradient(180deg, #041025 0%, #031020 100%);
      color: rgba(235, 244, 255, 0.94);
    }
    .fuelcalc-main { padding: 20px 16px 36px; }
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
      font-size: 34px;
      letter-spacing: 0.02em;
      color: #e8f2ff;
    }
    .fuelcalc-main .hint {
      color: rgba(206, 223, 244, 0.9);
      margin-bottom: 16px;
      font-size: 19px;
    }
    .fuelcalc-main .msg { margin-top: 12px; padding: 10px; border-radius: 8px; }
    .fuelcalc-main .msg.info {
      background: rgba(42, 66, 110, 0.48);
      border: 1px solid rgba(131, 166, 224, 0.55);
      color: rgba(230, 241, 255, 0.96);
    }
    .fuelcalc-main .grid { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 12px; }
    .fuelcalc-main .field { display: flex; flex-direction: column; gap: 6px; }
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
    .fuelcalc-main .field input, .fuelcalc-main .field select {
      border: 1px solid rgba(117, 150, 205, 0.45);
      border-radius: 4px;
      font-size: 14px;
      padding: 8px;
      background: rgba(7, 20, 38, 0.88);
      color: rgba(233, 243, 255, 0.98);
    }
    .fuelcalc-main .field input::placeholder { color: rgba(175, 197, 230, 0.75); }
    .fuelcalc-main .calc-actions { display: flex; gap: 8px; flex-wrap: wrap; margin-top: 14px; }
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
    .fuelcalc-main .cards { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 12px; margin-top: 16px; }
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
    .fuelcalc-main .card .value { font-size: 42px; font-weight: 800; line-height: 1.1; color: #f5fbff; }
    .fuelcalc-main .card .sub { margin-top: 4px; font-size: 12px; color: rgba(182, 204, 237, 0.86); }
    .fuelcalc-main table { width: 100%; border-collapse: collapse; margin-top: 16px; font-size: 14px; }
    .fuelcalc-main th, .fuelcalc-main td {
      border: 1px solid rgba(85, 122, 180, 0.5);
      padding: 8px;
      text-align: left;
      vertical-align: top;
      color: rgba(226, 238, 255, 0.95);
    }
    .fuelcalc-main th { background: rgba(18, 40, 69, 0.88); }
    .fuelcalc-main td.num { text-align: right; font-family: Consolas, Menlo, Monaco, monospace; }
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
      .fuelcalc-main .grid, .fuelcalc-main .cards { grid-template-columns: 1fr; }
      .fuelcalc-main h1 { font-size: 30px; }
      .fuelcalc-main .card .value { font-size: 36px; }
    }
  </style>
</head>
<body class="fuelcalc-page">
  <cfinclude template="../includes/top_nav.cfm">
  <main class="fuelcalc-main">
    <div class="wrap">
    <h1>Fuel Calculator</h1>
    <p class="hint">Dev-only manual-input calculator that mirrors the Route Generator Cruise Timeline summary math.</p>

    <div class="msg info">
      <strong>Notes</strong>
      <ul>
        <li>Fuel burn input is treated as <strong>burn at max speed</strong>.</li>
        <li>Pace ratios: RELAXED=0.25, BALANCED=0.50, AGGRESSIVE=1.00.</li>
        <li>Inputs are manual only; no route/template prefill is applied.</li>
        <li>Rounding and display behavior follows the Route Generator Cruise Timeline + top-card model.</li>
      </ul>
    </div>

    <form id="qaFuelCalcForm" onsubmit="return false;">
      <div class="grid">
        <div class="field">
          <label for="totalNm">Total distance (NM)</label>
          <input id="totalNm" name="totalNm" type="number" step="0.1" min="0" value="" placeholder="Enter NM">
        </div>
        <div class="field">
          <label for="pace">Pace</label>
          <select id="pace" name="pace">
            <option value="RELAXED">RELAXED (0.25)</option>
            <option value="BALANCED">BALANCED (0.50)</option>
            <option value="AGGRESSIVE">AGGRESSIVE (1.00)</option>
          </select>
        </div>
        <div class="field">
          <label for="maxSpeedKn">Max speed (kn)</label>
          <input id="maxSpeedKn" name="maxSpeedKn" type="number" step="0.1" min="1" max="60" value="" placeholder="Enter kn">
        </div>
        <div class="field">
          <label for="underwayHoursPerDay">Underway hours / day (max)</label>
          <input id="underwayHoursPerDay" name="underwayHoursPerDay" type="number" step="0.5" min="4" max="12" value="6.5">
        </div>
        <div class="field">
          <label for="fuelBurnGph">Fuel burn at max speed (GPH)</label>
          <input id="fuelBurnGph" name="fuelBurnGph" type="number" step="0.1" min="0" value="" placeholder="Enter GPH">
        </div>
        <div class="field">
          <label for="idleBurnGph">Idle burn (GPH)</label>
          <input id="idleBurnGph" name="idleBurnGph" type="number" step="0.1" min="0" value="" placeholder="Optional">
        </div>
        <div class="field">
          <label for="idleHoursTotal">Idle hours (total)</label>
          <input id="idleHoursTotal" name="idleHoursTotal" type="number" step="0.1" min="0" value="" placeholder="Optional">
        </div>
        <div class="field">
          <label for="weatherPct">Weather factor (%)</label>
          <input id="weatherPct" name="weatherPct" type="number" step="1" min="0" max="60" value="0">
        </div>
        <div class="field">
          <label for="reservePct">Reserve (%)</label>
          <input id="reservePct" name="reservePct" type="number" step="1" min="0" max="100" value="20">
        </div>
        <div class="field">
          <label for="fuelPricePerGal">Fuel price ($/gal)</label>
          <input id="fuelPricePerGal" name="fuelPricePerGal" type="number" step="0.01" min="0" value="" placeholder="Optional">
        </div>
      </div>

      <div class="calc-actions">
        <button type="button" class="primary" id="calcBtn">Calculate</button>
        <button type="button" id="resetBtn">Reset</button>
        <button type="button" id="copyJsonBtn">Copy Result JSON</button>
      </div>
    </form>

    <div class="cards">
      <div class="card">
        <div class="label">Estimated days</div>
        <div class="value" id="cardEstimatedDays">0</div>
        <div class="sub" id="cardEstimatedDaysSub">Enter inputs and press Calculate.</div>
      </div>
      <div class="card">
        <div class="label">Estimated fuel</div>
        <div class="value" id="cardEstimatedFuel">-- gal</div>
        <div class="sub" id="cardEstimatedFuelSub">Required fuel unavailable</div>
      </div>
      <div class="card">
        <div class="label">Fuel cost</div>
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

  <script src="../assets/js/app/shared/fuel-math.js?v=20260308a"></script>
  <script>
    (function () {
      function q(id) {
        return document.getElementById(id);
      }

      var sharedFuelMath = window.FPW && window.FPW.SharedFuelMath ? window.FPW.SharedFuelMath : null;

      function safeNum(value) {
        var n = parseFloat(value);
        return Number.isFinite(n) ? n : null;
      }

      function formatNumber(value, decimals, fallback) {
        if (!sharedFuelMath || typeof sharedFuelMath.formatNum !== "function") {
          var n = safeNum(value);
          if (!Number.isFinite(n)) return (fallback !== undefined ? String(fallback) : "--");
          return n.toFixed(typeof decimals === "number" ? decimals : 2);
        }
        return sharedFuelMath.formatNum(value, decimals, fallback);
      }

      function formatCurrency(value, fallback) {
        if (!sharedFuelMath || typeof sharedFuelMath.formatCurrency !== "function") {
          var n = safeNum(value);
          if (!Number.isFinite(n)) return (fallback !== undefined ? String(fallback) : "--");
          return "$" + n.toFixed(2);
        }
        return sharedFuelMath.formatCurrency(value, fallback);
      }

      function readInputNumber(id) {
        var el = q(id);
        if (!el) return null;
        var raw = String(el.value || "").trim();
        if (!raw.length) return null;
        return safeNum(raw);
      }

      function getInputs() {
        var paceRaw = String((q("pace").value || "RELAXED")).trim().toUpperCase();
        var pace = (sharedFuelMath && typeof sharedFuelMath.normalizePaceKey === "function")
          ? sharedFuelMath.normalizePaceKey(paceRaw)
          : paceRaw;

        return {
          pace: pace,
          distanceNm: readInputNumber("totalNm"),
          maxSpeedKn: readInputNumber("maxSpeedKn"),
          maxHoursPerDay: readInputNumber("underwayHoursPerDay"),
          fuelBurnGph: readInputNumber("fuelBurnGph"),
          idleBurnGph: readInputNumber("idleBurnGph"),
          idleHoursTotal: readInputNumber("idleHoursTotal"),
          weatherFactorPct: readInputNumber("weatherPct"),
          reservePct: readInputNumber("reservePct"),
          fuelPricePerGal: readInputNumber("fuelPricePerGal")
        };
      }

      function renderCards(model) {
        var estimatedDays = safeNum(model.displayedDays);
        var requiredFuel = safeNum(model.requiredFuelForSummary);
        var fuelCost = safeNum(model.fuelCostEstimate);
        var fuelPricePerGal = safeNum(model.fuelPricePerGal);

        q("cardEstimatedDays").textContent = (estimatedDays !== null ? String(Math.max(0, Math.round(estimatedDays))) : "0");
        q("cardEstimatedDaysSub").textContent = String(model.estimatedDaysSubText || "Cruise Timeline estimate");

        if (requiredFuel !== null && requiredFuel >= 0) {
          q("cardEstimatedFuel").textContent = formatNumber(requiredFuel, 1, "--") + " gal";
        } else {
          q("cardEstimatedFuel").textContent = "-- gal";
        }
        q("cardEstimatedFuelSub").textContent = String(model.estimatedFuelSubText || "Required fuel unavailable");

        if (fuelCost !== null && fuelCost >= 0 && fuelPricePerGal !== null && fuelPricePerGal > 0) {
          q("cardFuelCost").textContent = formatCurrency(fuelCost, "--");
        } else {
          q("cardFuelCost").textContent = "--";
        }
        q("cardFuelCostSub").textContent = String(model.fuelCostSubText || "Enter fuel price to estimate");
      }

      function renderBreakdown(model) {
        var manual = (model.manual && typeof model.manual === "object") ? model.manual : {};
        var rows = [
          ["Cruise Timeline calc line", String(model.calcLine || "Calc: n/a"), "Canonical Route Generator header model"],
          ["Pace factor", formatNumber(manual.paceFactor, 2, "n/a"), "RELAXED=0.25, BALANCED=0.50, AGGRESSIVE=1.00"],
          ["Effective speed (kn)", formatNumber(manual.effectiveSpeedKn, 2, "n/a"), "max speed x pace factor"],
          ["Weather-adjusted speed (kn)", formatNumber(manual.adjustedSpeedKn, 2, "n/a"), "effective speed x (1 - weather factor)"],
          ["Cruise hours", formatNumber(model.totalHours, 2, "n/a"), "distance / weather-adjusted speed"],
          ["Estimated days", formatNumber(model.displayedDays, 0, "0"), "ceil(cruise hours / max underway hours/day)"],
          ["Base fuel (gal)", formatNumber(model.baseFuelForSummary, 2, "n/a"), "cruise hours x burn at max speed"],
          ["Reserve fuel (gal)", formatNumber(model.reserveFuelForSummary, 2, "n/a"), "base fuel x reserve percent"],
          ["Required fuel (gal)", formatNumber(model.requiredFuelForSummary, 2, "n/a"), "base fuel + reserve"],
          ["Fuel cost (USD)", formatNumber(model.fuelCostEstimate, 2, "--"), "required fuel x price/gal"]
        ];

        q("calcBreakdownBody").innerHTML = rows.map(function (row) {
          return "<tr>"
            + "<td>" + row[0] + "</td>"
            + "<td class=\"num\">" + row[1] + "</td>"
            + "<td>" + row[2] + "</td>"
            + "</tr>";
        }).join("");
      }

      function renderJson(model, inputs) {
        var manual = (model.manual && typeof model.manual === "object") ? model.manual : {};
        q("calcJsonOut").textContent = JSON.stringify({
          cards: {
            estimated_days: (safeNum(model.displayedDays) !== null ? Math.max(0, Math.round(model.displayedDays)) : 0),
            estimated_fuel_gallons: safeNum(model.requiredFuelForSummary),
            fuel_cost_usd: safeNum(model.fuelCostEstimate)
          },
          canonical_summary: {
            calc_line: String(model.calcLine || "Calc: n/a"),
            total_nm: safeNum(model.totalNm),
            total_hours: safeNum(model.totalHours),
            base_fuel_gallons: safeNum(model.baseFuelForSummary),
            reserve_fuel_gallons: safeNum(model.reserveFuelForSummary),
            required_fuel_gallons: safeNum(model.requiredFuelForSummary)
          },
          inputs: inputs,
          derived: manual
        }, null, 2);
      }

      function renderError(message) {
        q("cardEstimatedDays").textContent = "0";
        q("cardEstimatedFuel").textContent = "-- gal";
        q("cardFuelCost").textContent = "--";
        q("cardEstimatedDaysSub").textContent = String(message || "Calculation unavailable.");
        q("cardEstimatedFuelSub").textContent = "Required fuel unavailable";
        q("cardFuelCostSub").textContent = "Enter fuel price to estimate";
        q("calcBreakdownBody").innerHTML = "<tr><td>Calculator</td><td class=\"num\">Unavailable</td><td>" + String(message || "Shared fuel math helper is missing.") + "</td></tr>";
        q("calcJsonOut").textContent = JSON.stringify({ error: String(message || "Shared fuel math helper is missing.") }, null, 2);
      }

      function run() {
        if (!sharedFuelMath || typeof sharedFuelMath.buildManualSummaryModel !== "function") {
          renderError("Shared helper missing: /assets/js/app/shared/fuel-math.js");
          return;
        }
        var inputs = getInputs();
        var model = sharedFuelMath.buildManualSummaryModel(inputs);
        renderCards(model);
        renderBreakdown(model);
        renderJson(model, inputs);
      }

      function resetInputs() {
        q("totalNm").value = "";
        q("pace").value = "RELAXED";
        q("maxSpeedKn").value = "";
        q("underwayHoursPerDay").value = "6.5";
        q("fuelBurnGph").value = "";
        q("idleBurnGph").value = "";
        q("idleHoursTotal").value = "";
        q("weatherPct").value = "0";
        q("reservePct").value = "20";
        q("fuelPricePerGal").value = "";
        q("calcBreakdownBody").innerHTML = "";
        q("calcJsonOut").textContent = "{}";
        q("cardEstimatedDays").textContent = "0";
        q("cardEstimatedDaysSub").textContent = "Enter inputs and press Calculate.";
        q("cardEstimatedFuel").textContent = "-- gal";
        q("cardEstimatedFuelSub").textContent = "Required fuel unavailable";
        q("cardFuelCost").textContent = "--";
        q("cardFuelCostSub").textContent = "Enter fuel price to estimate";
      }

      q("calcBtn").addEventListener("click", run);
      q("resetBtn").addEventListener("click", resetInputs);
      q("copyJsonBtn").addEventListener("click", function () {
        var text = q("calcJsonOut").textContent || "";
        if (navigator.clipboard && navigator.clipboard.writeText) {
          navigator.clipboard.writeText(text);
        }
      });

      [
        "totalNm", "pace", "maxSpeedKn", "underwayHoursPerDay",
        "fuelBurnGph", "idleBurnGph", "idleHoursTotal", "weatherPct",
        "reservePct", "fuelPricePerGal"
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
