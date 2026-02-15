<cfsetting showdebugoutput="false">
<cfcontent type="text/html; charset=utf-8">

<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Admin Fuel Calculator</title>
  <style>
    body { font-family: Arial, sans-serif; margin: 24px; background: #f7f7f7; color: #111; }
    .wrap { max-width: 1120px; margin: 0 auto; background: #fff; border: 1px solid #ddd; border-radius: 8px; padding: 20px; }
    .admin-nav { display: flex; gap: 8px; margin-bottom: 14px; flex-wrap: wrap; }
    .admin-nav a { text-decoration: none; border: 1px solid #bbb; background: #f5f5f5; color: #222; padding: 6px 10px; border-radius: 4px; font-size: 14px; }
    .admin-nav a.active { background: #111; border-color: #111; color: #fff; }
    h1 { margin-top: 0; font-size: 24px; }
    .hint { color: #444; margin-bottom: 16px; }
    .msg { margin-top: 12px; padding: 10px; border-radius: 4px; }
    .msg.info { background: #edf2ff; border: 1px solid #b6c6ff; }
    .grid { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 12px; }
    .field { display: flex; flex-direction: column; gap: 6px; }
    .field label { font-size: 13px; font-weight: 700; color: #222; }
    .field input, .field select {
      border: 1px solid #bbb;
      border-radius: 4px;
      font-size: 14px;
      padding: 8px;
      background: #fff;
      color: #111;
    }
    .actions { display: flex; gap: 8px; flex-wrap: wrap; margin-top: 14px; }
    button {
      padding: 8px 12px;
      border-radius: 4px;
      border: 1px solid #666;
      background: #efefef;
      cursor: pointer;
      font-size: 14px;
    }
    button.primary { background: #111; border-color: #111; color: #fff; }
    .cards { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 12px; margin-top: 16px; }
    .card {
      background: #fafafa;
      border: 1px solid #ddd;
      border-radius: 6px;
      padding: 12px;
    }
    .card .label { font-size: 12px; text-transform: uppercase; letter-spacing: 0.07em; color: #666; margin-bottom: 6px; }
    .card .value { font-size: 28px; font-weight: 800; line-height: 1.1; }
    .card .sub { margin-top: 4px; font-size: 12px; color: #666; }
    table { width: 100%; border-collapse: collapse; margin-top: 16px; font-size: 14px; }
    th, td { border: 1px solid #ddd; padding: 8px; text-align: left; vertical-align: top; }
    th { background: #f0f0f0; }
    td.num { text-align: right; font-family: Consolas, Menlo, Monaco, monospace; }
    pre {
      margin-top: 16px;
      background: #111;
      color: #f4f4f4;
      padding: 12px;
      border-radius: 6px;
      overflow: auto;
      font-size: 12px;
      line-height: 1.45;
    }
    @media (max-width: 900px) {
      .grid, .cards { grid-template-columns: 1fr; }
    }
  </style>
</head>
<body>
  <div class="wrap">
    <nav class="admin-nav" aria-label="Admin Tools">
      <a href="/fpw/admin/floatplan-cleanup.cfm">FloatPlan Cleanup</a>
      <a href="/fpw/admin/route-cleanup.cfm">Route Cleanup</a>
      <a href="/fpw/admin/fuel-calculator.cfm" class="active">Fuel Calculator</a>
    </nav>

    <h1>Admin QA Fuel Calculator</h1>
    <p class="hint">Dev-only calculator that mirrors FPW route preview formulas for Estimated Days, Estimated Fuel, and Fuel Cost.</p>

    <div class="msg info">
      <strong>Notes</strong>
      <ul>
        <li>Fuel burn input is treated as <strong>burn at max speed</strong>.</li>
        <li>Pace ratios: RELAXED=0.25, BALANCED=0.50, AGGRESSIVE=1.00.</li>
        <li>Reserve fallback: if reserve % is 0/blank, model applies 20%.</li>
        <li>Rounding behavior follows API model in <code>/api/v1/routeBuilder.cfc</code>.</li>
      </ul>
    </div>

    <form id="qaFuelCalcForm" onsubmit="return false;">
      <div class="grid">
        <div class="field">
          <label for="totalNm">Total distance (NM)</label>
          <input id="totalNm" name="totalNm" type="number" step="0.1" min="0" value="555">
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
          <input id="maxSpeedKn" name="maxSpeedKn" type="number" step="0.1" min="1" max="60" value="20">
        </div>
        <div class="field">
          <label for="underwayHoursPerDay">Underway hours / day</label>
          <input id="underwayHoursPerDay" name="underwayHoursPerDay" type="number" step="0.1" min="1" max="24" value="8">
        </div>
        <div class="field">
          <label for="fuelBurnGph">Fuel burn at max speed (GPH)</label>
          <input id="fuelBurnGph" name="fuelBurnGph" type="number" step="0.1" min="0" value="3">
        </div>
        <div class="field">
          <label for="idleBurnGph">Idle burn (GPH)</label>
          <input id="idleBurnGph" name="idleBurnGph" type="number" step="0.1" min="0" value="1">
        </div>
        <div class="field">
          <label for="idleHoursTotal">Idle hours (total)</label>
          <input id="idleHoursTotal" name="idleHoursTotal" type="number" step="0.1" min="0" value="0">
        </div>
        <div class="field">
          <label for="weatherPct">Weather factor (%)</label>
          <input id="weatherPct" name="weatherPct" type="number" step="1" min="0" max="60" value="5">
        </div>
        <div class="field">
          <label for="reservePct">Reserve (%)</label>
          <input id="reservePct" name="reservePct" type="number" step="1" min="0" max="100" value="20">
        </div>
        <div class="field">
          <label for="fuelPricePerGal">Fuel price ($/gal)</label>
          <input id="fuelPricePerGal" name="fuelPricePerGal" type="number" step="0.01" min="0" value="4.99">
        </div>
      </div>

      <div class="actions">
        <button type="button" class="primary" id="calcBtn">Calculate</button>
        <button type="button" id="exampleCaseBtn">Load Chicago QA Case</button>
        <button type="button" id="exampleAggressiveBtn">Load Aggressive Example</button>
        <button type="button" id="resetBtn">Reset</button>
        <button type="button" id="copyJsonBtn">Copy Result JSON</button>
      </div>
    </form>

    <div class="cards">
      <div class="card">
        <div class="label">Estimated days</div>
        <div class="value" id="cardEstimatedDays">0</div>
        <div class="sub" id="cardEstimatedDaysSub">Run 0.0h + Idle 0.0h = 0.0h</div>
      </div>
      <div class="card">
        <div class="label">Estimated fuel</div>
        <div class="value" id="cardEstimatedFuel">0.0 gal</div>
        <div class="sub" id="cardEstimatedFuelSub">Base 0.0 + Reserve (20%) 0.0</div>
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

  <script>
    (function () {
      function q(id) {
        return document.getElementById(id);
      }

      var paceMap = {
        RELAXED: 0.25,
        BALANCED: 0.50,
        AGGRESSIVE: 1.00
      };

      function toNum(value) {
        var n = parseFloat(value);
        return Number.isFinite(n) ? n : 0;
      }

      function round2(n) {
        return Math.round((toNum(n) * 100)) / 100;
      }

      function round1(n) {
        return Math.round((toNum(n) * 10)) / 10;
      }

      function clamp(n, minVal, maxVal) {
        return Math.min(maxVal, Math.max(minVal, n));
      }

      function formatNumber(value, decimals) {
        var n = parseFloat(value);
        if (!Number.isFinite(n)) return "0";
        var places = (typeof decimals === "number") ? decimals : 0;
        return n.toLocaleString(undefined, {
          minimumFractionDigits: places,
          maximumFractionDigits: places
        });
      }

      function formatCurrency(value) {
        var n = parseFloat(value);
        if (!Number.isFinite(n)) return "--";
        return "$" + n.toLocaleString(undefined, {
          minimumFractionDigits: 2,
          maximumFractionDigits: 2
        });
      }

      function getInputs() {
        var paceVal = String((q("pace").value || "RELAXED")).toUpperCase();
        if (!paceMap[paceVal]) paceVal = "RELAXED";

        var maxSpeedRaw = toNum(q("maxSpeedKn").value);
        if (maxSpeedRaw <= 0) maxSpeedRaw = 20;
        var maxSpeedKn = round2(clamp(maxSpeedRaw, 1, 60));

        var underwayRaw = toNum(q("underwayHoursPerDay").value);
        if (underwayRaw <= 0) underwayRaw = 8;
        var underwayHoursPerDay = clamp(underwayRaw, 1, 24);

        var fuelBurnGph = round2(clamp(toNum(q("fuelBurnGph").value), 0, 1000));
        var idleBurnGph = round2(clamp(toNum(q("idleBurnGph").value), 0, 1000));
        var idleHoursTotal = round2(clamp(toNum(q("idleHoursTotal").value), 0, 10000));
        var weatherPct = round2(clamp(toNum(q("weatherPct").value), 0, 60));
        var reservePct = round2(clamp(toNum(q("reservePct").value), 0, 100));
        var fuelPricePerGal = round2(clamp(toNum(q("fuelPricePerGal").value), 0, 1000));
        var totalNm = Math.max(0, toNum(q("totalNm").value));

        return {
          totalNm: totalNm,
          pace: paceVal,
          maxSpeedKn: maxSpeedKn,
          underwayHoursPerDay: underwayHoursPerDay,
          fuelBurnGph: fuelBurnGph,
          idleBurnGph: idleBurnGph,
          idleHoursTotal: idleHoursTotal,
          weatherPct: weatherPct,
          reservePct: reservePct,
          fuelPricePerGal: fuelPricePerGal
        };
      }

      function calculateModel(input) {
        var paceFactor = paceMap[input.pace] || 0.25;
        var weatherAdj = input.weatherPct / 100;
        var reservePctApplied = input.reservePct > 0 ? input.reservePct : 20;

        var effectiveSpeedKn = round2(input.maxSpeedKn * paceFactor);
        var weatherAdjustedSpeedKn = round2(effectiveSpeedKn * (1 - weatherAdj));
        if (weatherAdjustedSpeedKn < 0.5) weatherAdjustedSpeedKn = 0.5;

        var runHoursRaw = (input.totalNm > 0 && weatherAdjustedSpeedKn > 0)
          ? (input.totalNm / weatherAdjustedSpeedKn)
          : 0;
        var runHours = round2(runHoursRaw);
        var totalHoursRaw = runHoursRaw + input.idleHoursTotal;
        var totalHours = round2(totalHoursRaw);
        var estimatedDays = 0;
        if (totalHoursRaw > 0) {
          estimatedDays = Math.ceil(totalHoursRaw / input.underwayHoursPerDay);
          if (estimatedDays < 1) estimatedDays = 1;
        }

        // Matches routegenComputeTotals (1 decimal at this stage) before calculateFuelEstimate().
        var idleFuelGallonsPre = 0;
        if (input.idleBurnGph > 0 && input.idleHoursTotal > 0) {
          idleFuelGallonsPre = Math.round((input.idleBurnGph * input.idleHoursTotal) * 10) / 10;
        }

        var paceAdjustedBurnGph = 0;
        var weatherAdjustedBurnGph = 0;
        var cruiseHours = 0;
        var cruiseFuelGallons = 0;
        var idleFuelGallons = 0;
        var baseFuelGallons = 0;
        var reserveFuelGallons = 0;
        var requiredFuelGallons = 0;
        var fuelCostUsd = 0;

        // Mirrors calculateFuelEstimate() guard: returns zeros when distance/maxSpeed/maxBurn is not valid.
        if (input.totalNm > 0 && input.maxSpeedKn > 0 && input.fuelBurnGph > 0) {
          paceAdjustedBurnGph = round2(input.fuelBurnGph * Math.pow(paceFactor, 3));
          weatherAdjustedBurnGph = round2(paceAdjustedBurnGph * (1 + weatherAdj));
          cruiseHours = round2(input.totalNm / weatherAdjustedSpeedKn);
          cruiseFuelGallons = round2(cruiseHours * weatherAdjustedBurnGph);
          idleFuelGallons = round2(idleFuelGallonsPre);
          baseFuelGallons = round2(cruiseFuelGallons + idleFuelGallons);
          reserveFuelGallons = round2(baseFuelGallons * (reservePctApplied / 100));
          requiredFuelGallons = round2(baseFuelGallons + reserveFuelGallons);
          fuelCostUsd = input.fuelPricePerGal > 0
            ? (Math.round((requiredFuelGallons * input.fuelPricePerGal) * 100) / 100)
            : 0;
        }

        return {
          input: input,
          paceFactor: paceFactor,
          reservePctApplied: reservePctApplied,
          effectiveSpeedKn: effectiveSpeedKn,
          weatherAdjustedSpeedKn: weatherAdjustedSpeedKn,
          runHours: runHours,
          totalHours: totalHours,
          estimatedDays: estimatedDays,
          paceAdjustedBurnGph: paceAdjustedBurnGph,
          weatherAdjustedBurnGph: weatherAdjustedBurnGph,
          cruiseHours: cruiseHours,
          cruiseFuelGallons: cruiseFuelGallons,
          idleFuelGallons: idleFuelGallons,
          baseFuelGallons: baseFuelGallons,
          reserveFuelGallons: reserveFuelGallons,
          requiredFuelGallons: requiredFuelGallons,
          fuelCostUsd: fuelCostUsd
        };
      }

      function renderCards(result) {
        q("cardEstimatedDays").textContent = String(result.estimatedDays);
        q("cardEstimatedDaysSub").textContent =
          "Run " + formatNumber(result.runHours, 1)
          + "h + Idle " + formatNumber(result.input.idleHoursTotal, 1)
          + "h = " + formatNumber(result.totalHours, 1) + "h";

        q("cardEstimatedFuel").textContent = formatNumber(result.requiredFuelGallons, 1) + " gal";
        q("cardEstimatedFuelSub").textContent =
          "Base " + formatNumber(result.baseFuelGallons, 1)
          + " + Reserve (" + formatNumber(result.reservePctApplied, 0) + "%) "
          + formatNumber(result.reserveFuelGallons, 1);

        if (result.input.fuelPricePerGal > 0) {
          q("cardFuelCost").textContent = formatCurrency(result.fuelCostUsd);
          q("cardFuelCostSub").textContent = "Required fuel x $" + formatNumber(result.input.fuelPricePerGal, 2) + "/gal";
        } else {
          q("cardFuelCost").textContent = "--";
          q("cardFuelCostSub").textContent = "Enter fuel price to estimate";
        }
      }

      function renderBreakdown(result) {
        var rows = [
          ["Pace factor", formatNumber(result.paceFactor, 2), "RELAXED=0.25, BALANCED=0.50, AGGRESSIVE=1.00"],
          ["Effective speed (kn)", formatNumber(result.effectiveSpeedKn, 2), "round2(maxSpeed * paceFactor)"],
          ["Weather-adjusted speed (kn)", formatNumber(result.weatherAdjustedSpeedKn, 2), "round2(effectiveSpeed * (1 - weatherPct/100)), min 0.5"],
          ["Run hours", formatNumber(result.runHours, 2), "totalNm / weatherAdjustedSpeed"],
          ["Estimated days", formatNumber(result.estimatedDays, 0), "ceil((runHours + idleHoursTotal) / underwayHoursPerDay), min 1 when > 0"],
          ["Pace-adjusted burn (GPH)", formatNumber(result.paceAdjustedBurnGph, 2), "round2(maxBurn * paceFactor^3)"],
          ["Weather-adjusted burn (GPH)", formatNumber(result.weatherAdjustedBurnGph, 2), "round2(paceAdjustedBurn * (1 + weatherPct/100))"],
          ["Cruise fuel (gal)", formatNumber(result.cruiseFuelGallons, 2), "round2(cruiseHours * weatherAdjustedBurn)"],
          ["Idle fuel (gal)", formatNumber(result.idleFuelGallons, 2), "round1(idleBurn * idleHours) then round2"],
          ["Base fuel (gal)", formatNumber(result.baseFuelGallons, 2), "round2(cruiseFuel + idleFuel)"],
          ["Reserve fuel (gal)", formatNumber(result.reserveFuelGallons, 2), "round2(baseFuel * reservePctApplied/100)"],
          ["Required fuel (gal)", formatNumber(result.requiredFuelGallons, 2), "round2(baseFuel + reserveFuel)"],
          ["Fuel cost (USD)", formatNumber(result.fuelCostUsd, 2), "round2(requiredFuel * fuelPricePerGal) if price > 0"]
        ];

        q("calcBreakdownBody").innerHTML = rows.map(function (row) {
          return "<tr>"
            + "<td>" + row[0] + "</td>"
            + "<td class=\"num\">" + row[1] + "</td>"
            + "<td>" + row[2] + "</td>"
            + "</tr>";
        }).join("");
      }

      function renderJson(result) {
        q("calcJsonOut").textContent = JSON.stringify({
          cards: {
            estimated_days: result.estimatedDays,
            estimated_fuel_gallons: round1(result.requiredFuelGallons),
            fuel_cost_usd: result.fuelCostUsd
          },
          totals: {
            total_nm: result.input.totalNm,
            run_hours: result.runHours,
            idle_hours: result.input.idleHoursTotal,
            total_hours: result.totalHours,
            base_fuel_gallons: result.baseFuelGallons,
            reserve_fuel_gallons: result.reserveFuelGallons,
            required_fuel_gallons: result.requiredFuelGallons
          },
          model: {
            pace: result.input.pace,
            pace_factor: result.paceFactor,
            max_speed_kn: result.input.maxSpeedKn,
            effective_speed_kn: result.effectiveSpeedKn,
            weather_adjusted_speed_kn: result.weatherAdjustedSpeedKn,
            fuel_burn_gph: result.input.fuelBurnGph,
            pace_adjusted_burn_gph: result.paceAdjustedBurnGph,
            weather_adjusted_burn_gph: result.weatherAdjustedBurnGph,
            weather_pct: result.input.weatherPct,
            reserve_pct_applied: result.reservePctApplied,
            fuel_price_per_gal: result.input.fuelPricePerGal
          }
        }, null, 2);
      }

      function run() {
        var inputs = getInputs();
        var result = calculateModel(inputs);
        renderCards(result);
        renderBreakdown(result);
        renderJson(result);
      }

      function setExampleQaCase() {
        q("totalNm").value = "555";
        q("pace").value = "RELAXED";
        q("maxSpeedKn").value = "20";
        q("underwayHoursPerDay").value = "8";
        q("fuelBurnGph").value = "3";
        q("idleBurnGph").value = "1";
        q("idleHoursTotal").value = "0";
        q("weatherPct").value = "5";
        q("reservePct").value = "20";
        q("fuelPricePerGal").value = "4.99";
        run();
      }

      function setExampleAggressive() {
        q("totalNm").value = "555";
        q("pace").value = "AGGRESSIVE";
        q("maxSpeedKn").value = "20";
        q("underwayHoursPerDay").value = "8";
        q("fuelBurnGph").value = "3";
        q("idleBurnGph").value = "1";
        q("idleHoursTotal").value = "10";
        q("weatherPct").value = "5";
        q("reservePct").value = "20";
        q("fuelPricePerGal").value = "4.99";
        run();
      }

      function resetDefaults() {
        q("totalNm").value = "0";
        q("pace").value = "BALANCED";
        q("maxSpeedKn").value = "20";
        q("underwayHoursPerDay").value = "8";
        q("fuelBurnGph").value = "0";
        q("idleBurnGph").value = "0";
        q("idleHoursTotal").value = "0";
        q("weatherPct").value = "0";
        q("reservePct").value = "20";
        q("fuelPricePerGal").value = "0";
        run();
      }

      q("calcBtn").addEventListener("click", run);
      q("exampleCaseBtn").addEventListener("click", setExampleQaCase);
      q("exampleAggressiveBtn").addEventListener("click", setExampleAggressive);
      q("resetBtn").addEventListener("click", resetDefaults);
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

      setExampleQaCase();
    })();
  </script>
</body>
</html>
