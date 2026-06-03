<cfsetting showdebugoutput="false">
<cfcontent type="text/html; charset=utf-8">

<!doctype html>
<html lang="en">
<head>

  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Boat Fuel Calculator | Estimate Fuel Use for Your Next Trip | FloatPlanWizard</title>

<meta name="description" content="Use FloatPlanWizard's Boat Fuel Calculator to estimate fuel usage, reserve fuel, travel time, and trip cost for your next boating trip. Plan smarter and safer before you leave the dock.">

<link rel="canonical" href="https://floatplanwizard.com/boat-fuel-calculator/boat-fuel-calculator.cfm">
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.3/font/bootstrap-icons.min.css">
  <style>
    :root {
      --fpw-public-layout-max: 1480px;
      --fuel-bg: #020914;
      --fuel-panel: rgba(7, 22, 38, 0.84);
      --fuel-panel-strong: rgba(4, 15, 28, 0.96);
      --fuel-line: rgba(126, 205, 220, 0.28);
      --fuel-line-strong: rgba(33, 243, 238, 0.62);
      --fuel-text: #f3f8ff;
      --fuel-muted: #b8c7d6;
      --fuel-soft: #87a0b6;
      --fuel-cyan: #23d7cf;
      --fuel-blue: #38bdf8;
      --fuel-radius: 18px;
    }

    * { box-sizing: border-box; }
    html { scroll-behavior: smooth; }
    a { color: inherit; text-decoration: none; }

    .fuelcalc-page {
      margin: 0;
      color: var(--fuel-text);
      font-family: Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      background:
        radial-gradient(circle at 15% 0%, rgba(35, 215, 207, 0.13), transparent 26rem),
        radial-gradient(circle at 85% 4%, rgba(56, 189, 248, 0.11), transparent 28rem),
        linear-gradient(180deg, #02070f 0%, #03111f 48%, #020914 100%);
    }

    .fuelcalc-page input,
    .fuelcalc-page select,
    .fuelcalc-page button {
      font: inherit;
    }

    .fuelcalc-page svg {
      display: block;
    }

    .fpw-fuel-page {
      position: relative;
      width: min(100% - 48px, 1480px);
      margin-inline: auto;
      padding: 28px 0 34px;
      overflow: hidden;
    }

    .fpw-fuel-page::before {
      content: "";
      position: absolute;
      inset: 0;
      pointer-events: none;
      background-image:
        linear-gradient(rgba(126, 205, 220, 0.035) 1px, transparent 1px),
        linear-gradient(90deg, rgba(126, 205, 220, 0.032) 1px, transparent 1px);
      background-size: 76px 76px;
      mask-image: radial-gradient(circle at 50% 0%, black 0%, transparent 58%);
      opacity: 0.7;
    }

    .fpw-fuel-page > * {
      position: relative;
      z-index: 1;
    }

    .fpw-fuel-hero {
      min-height: 330px;
      display: grid;
      align-items: center;
      padding: clamp(34px, 5vw, 62px) clamp(24px, 4vw, 42px);
      border-bottom: 1px solid rgba(126, 205, 220, 0.2);
      overflow: hidden;
      background:
        linear-gradient(90deg, rgba(2, 10, 20, 0.98) 0%, rgba(3, 15, 29, 0.88) 43%, rgba(3, 15, 29, 0.22) 100%),
        url("../assets/images/boat-fuel-calculator/Silent-voyage-on-calm-waters.png") center right / cover no-repeat;
    }

    .fpw-fuel-hero__content {
      max-width: 640px;
    }

    .fpw-fuel-hero h1 {
      margin: 0;
      color: #ffffff;
      font-size: clamp(3.2rem, 6.1vw, 5.4rem);
      line-height: 0.95;
      letter-spacing: 0;
      text-shadow: 0 16px 34px rgba(0, 0, 0, 0.42);
    }

    .fpw-fuel-hero__lead {
      max-width: 610px;
      margin: 20px 0 0;
      color: rgba(238, 247, 251, 0.88);
      font-size: clamp(1.12rem, 1.7vw, 1.38rem);
      line-height: 1.45;
    }

    .fpw-fuel-hero__copy {
      max-width: 610px;
      margin: 18px 0 0;
      color: rgba(184, 199, 214, 0.9);
      line-height: 1.62;
    }

    .fpw-fuel-hero__callout,
    .fpw-mini-compass {
      display: inline-flex;
      align-items: center;
    }

    .fpw-fuel-hero__callout {
      gap: 12px;
      margin: 24px 0 0;
      color: #28f3e8;
      font-weight: 850;
    }

    .fpw-mini-compass {
      width: 28px;
      height: 28px;
      color: #28f3e8;
      filter: drop-shadow(0 0 12px rgba(40, 243, 232, 0.5));
    }

    .fpw-mini-compass svg,
    .fpw-card-icon svg,
    .fpw-fuel-cta__icon svg {
      width: 100%;
      height: 100%;
      fill: none;
      stroke: currentColor;
      stroke-width: 2;
      stroke-linecap: round;
      stroke-linejoin: round;
    }

    .fpw-section-rule {
      display: grid;
      grid-template-columns: minmax(0, 1fr) auto minmax(0, 1fr);
      gap: 24px;
      align-items: center;
      margin: 28px 0 20px;
      text-align: center;
    }

    .fpw-section-rule span {
      height: 1px;
      background: linear-gradient(90deg, transparent, rgba(126, 205, 220, 0.48), transparent);
    }

    .fpw-section-rule h2,
    .fpw-panel-heading h2 {
      margin: 0;
      color: #7df7f0;
      font-size: 0.92rem;
      font-weight: 900;
      letter-spacing: 0.32em;
      text-transform: uppercase;
    }

    .fpw-why-grid,
    .fpw-results-grid,
    .fpw-fuel-education {
      display: grid;
      gap: 16px;
    }

    .fpw-why-grid {
      grid-template-columns: repeat(3, minmax(0, 1fr));
    }

    .fpw-why-card,
    .fpw-fuel-calculator-panel,
    .fpw-result-card,
    .fpw-info-card,
    .fpw-fuel-cta,
    .fpw-dev-output {
      border: 1px solid var(--fuel-line);
      background:
        linear-gradient(180deg, rgba(8, 26, 44, 0.84), rgba(3, 14, 26, 0.94));
      box-shadow: 0 18px 44px rgba(0, 0, 0, 0.28), inset 0 1px 0 rgba(255, 255, 255, 0.04);
    }

    .fpw-why-card {
      min-height: 110px;
      display: grid;
      grid-template-columns: 54px minmax(0, 1fr);
      gap: 18px;
      align-items: center;
      border-radius: 10px;
      padding: 20px 24px;
    }

    .fpw-card-icon {
      width: 48px;
      height: 48px;
      color: #28f3e8;
      filter: drop-shadow(0 0 16px rgba(40, 243, 232, 0.35));
    }

    .fpw-why-card h3,
    .fpw-info-card h2,
    .fpw-result-card h3 {
      margin: 0;
      color: #ffffff;
      line-height: 1.18;
      letter-spacing: 0;
    }

    .fpw-why-card h3 {
      font-size: 1.08rem;
    }

    .fpw-why-card p,
    .fpw-info-card p,
    .fpw-info-card li,
    .fpw-fuel-cta p {
      color: var(--fuel-muted);
      line-height: 1.5;
    }

    .fpw-why-card p {
      margin: 7px 0 0;
      font-size: 0.94rem;
    }

    .fpw-fuel-calculator-panel {
      margin-top: 20px;
      border-radius: var(--fuel-radius);
      padding: 24px 26px;
    }

    .fpw-panel-heading {
      display: grid;
      grid-template-columns: minmax(0, 1fr) auto;
      gap: 16px;
      align-items: center;
      margin-bottom: 20px;
    }

    .fpw-panel-heading::after {
      content: "";
      height: 1px;
      background: linear-gradient(90deg, rgba(35, 215, 207, 0.68), transparent);
    }

    .fpw-panel-heading p {
      grid-column: 2;
      grid-row: 1;
      margin: 0;
      color: var(--fuel-soft);
      font-size: 0.84rem;
      white-space: nowrap;
    }

    .fpw-fuel-form {
      display: grid;
      grid-template-columns: repeat(2, minmax(0, 1fr));
      gap: 32px;
    }

    .fpw-input-group {
      display: grid;
      gap: 14px;
      align-content: start;
    }

    .fpw-input-group h3 {
      display: flex;
      align-items: center;
      gap: 10px;
      margin: 0;
      padding-bottom: 8px;
      border-bottom: 1px solid rgba(126, 205, 220, 0.16);
      color: #7df7f0;
      font-size: 0.86rem;
      font-weight: 900;
      letter-spacing: 0.14em;
      text-transform: uppercase;
    }

    .fpw-field {
      position: relative;
      display: grid;
      grid-template-columns: minmax(140px, 0.72fr) minmax(0, 1fr);
      gap: 16px;
      align-items: center;
    }

    .fpw-field label {
      color: rgba(238, 247, 251, 0.9);
      font-size: 0.92rem;
      font-weight: 700;
      line-height: 1.25;
    }

    .fpw-label-row {
      display: inline-flex;
      align-items: flex-start;
      gap: 4px;
      width: fit-content;
    }

    .fpw-label-row label {
      margin: 0;
    }

    .fuelcalc-page .fpw-help {
      width: 10px;
      height: 10px;
      flex: 0 0 10px;
      display: inline-flex;
      align-items: center;
      justify-content: center;
      border: 1px solid rgba(69, 227, 255, 0.55);
      border-radius: 50%;
      padding: 0;
      color: #78f2ff;
      background: rgba(8, 22, 40, 0.9);
      font: inherit;
      font-size: 7px;
      font-weight: 800;
      line-height: 1;
      margin-top: 1px;
      cursor: pointer;
      transition: border-color 180ms ease, box-shadow 180ms ease, background 180ms ease, color 180ms ease;
    }

    .fuelcalc-page .fpw-help:hover,
    .fuelcalc-page .fpw-help:focus {
      outline: none;
      border-color: #45e3ff;
      color: #ffffff;
      background: rgba(10, 31, 55, 1);
      box-shadow: 0 0 0 3px rgba(69, 227, 255, 0.14), 0 0 16px rgba(69, 227, 255, 0.2);
    }

    .fpw-tooltip {
      position: absolute;
      left: 0;
      top: calc(100% + 8px);
      z-index: 50;
      width: min(320px, calc(100vw - 48px));
      border: 1px solid rgba(69, 227, 255, 0.35);
      border-radius: 12px;
      padding: 12px 14px;
      color: #d8e7f3;
      background: rgba(6, 18, 35, 0.98);
      box-shadow: 0 10px 28px rgba(0, 0, 0, 0.35), 0 0 24px rgba(35, 215, 207, 0.08);
      font-size: 0.86rem;
      line-height: 1.45;
      opacity: 0;
      visibility: hidden;
      transform: translateY(6px);
      transition: opacity 180ms ease, transform 180ms ease, visibility 180ms ease;
      pointer-events: none;
    }

    .fpw-tooltip.is-visible {
      opacity: 1;
      visibility: visible;
      transform: translateY(0);
      pointer-events: auto;
    }

    .fpw-field__control {
      position: relative;
      display: block;
    }

    .fpw-field input,
    .fpw-field select {
      width: 100%;
      min-height: 44px;
      border: 1px solid rgba(126, 205, 220, 0.28);
      border-radius: 6px;
      padding: 0 48px 0 12px;
      color: rgba(244, 248, 255, 0.96);
      background: rgba(3, 13, 26, 0.82);
      outline: none;
      transition: border-color 160ms ease, box-shadow 160ms ease, background 160ms ease;
    }

    .fpw-field select {
      padding-right: 32px;
    }

    .fpw-field input:focus-visible,
    .fpw-field select:focus-visible,
    .fpw-ghost-button:focus-visible,
    .fpw-fuel-cta__button:focus-visible,
    .fpw-info-card summary:focus-visible {
      border-color: var(--fuel-line-strong);
      box-shadow: 0 0 0 3px rgba(35, 215, 207, 0.18), 0 0 22px rgba(35, 215, 207, 0.18);
    }

    .fpw-field input[aria-invalid="true"] {
      border-color: rgba(255, 204, 92, 0.62);
    }

    .fpw-field input::placeholder {
      color: rgba(174, 194, 219, 0.72);
    }

    .fpw-field__unit {
      position: absolute;
      top: 50%;
      right: 12px;
      color: rgba(220, 234, 246, 0.88);
      font-size: 0.86rem;
      font-style: normal;
      font-weight: 800;
      transform: translateY(-50%);
      pointer-events: none;
    }

    .field-note {
      grid-column: 2;
      margin-top: -6px;
      color: var(--fuel-soft);
      font-size: 0.8rem;
      line-height: 1.45;
    }

    .calc-actions {
      display: flex;
      flex-wrap: wrap;
      gap: 14px;
      margin-top: 20px;
    }

    .fpw-ghost-button {
      min-height: 46px;
      display: inline-flex;
      align-items: center;
      justify-content: center;
      gap: 10px;
      border: 1px solid rgba(35, 215, 207, 0.58);
      border-radius: 7px;
      padding: 0 18px;
      color: rgba(238, 247, 251, 0.94);
      background: rgba(3, 18, 33, 0.56);
      cursor: pointer;
      transition: transform 160ms ease, border-color 160ms ease, color 160ms ease, box-shadow 160ms ease;
    }

    .fpw-ghost-button:hover {
      color: #ffffff;
      border-color: rgba(40, 243, 232, 0.82);
      transform: translateY(-1px);
    }

    .fpw-fuel-note,
    .msg.warn {
      border: 1px solid rgba(35, 215, 207, 0.58);
      border-radius: 10px;
      background: linear-gradient(135deg, rgba(8, 83, 97, 0.34), rgba(3, 18, 33, 0.74));
      color: rgba(238, 247, 251, 0.92);
    }

    .fpw-fuel-note {
      display: grid;
      grid-template-columns: 34px minmax(0, 1fr);
      gap: 16px;
      align-items: center;
      margin-top: 20px;
      padding: 14px 18px;
    }

    .fpw-fuel-note span {
      width: 30px;
      height: 30px;
      display: grid;
      place-items: center;
      border: 2px solid var(--fuel-cyan);
      border-radius: 50%;
      color: var(--fuel-cyan);
      font-weight: 900;
    }

    .fpw-fuel-note p {
      margin: 0;
      color: rgba(238, 247, 251, 0.92);
      line-height: 1.45;
    }

    .msg.warn {
      margin-top: 18px;
      padding: 14px 18px;
      color: var(--fuel-muted);
    }

    .msg.warn strong,
    .msg.warn ul {
      color: var(--fuel-text);
    }

    .msg.warn ul {
      margin: 8px 0 0 20px;
      padding: 0;
    }

    .msg.warn .msg-detail {
      margin-top: 8px;
    }

    .fpw-results-grid {
      grid-template-columns: repeat(6, minmax(0, 1fr));
    }

    .fpw-result-card {
      min-height: 142px;
      border-radius: 9px;
      padding: 18px 18px 16px;
    }

    .fpw-result-card__icon {
      display: inline-flex;
      margin-bottom: 10px;
      color: var(--fuel-cyan);
      font-size: 1.35rem;
      line-height: 1;
    }

    .fpw-result-card h3 {
      color: rgba(220, 234, 246, 0.82);
      font-size: 0.78rem;
      font-weight: 850;
      letter-spacing: 0.08em;
      text-transform: uppercase;
    }

    .fpw-result-card .value {
      display: block;
      margin-top: 14px;
      color: #ffffff;
      font-size: clamp(1.85rem, 3vw, 2.55rem);
      font-weight: 900;
      line-height: 1;
      letter-spacing: -0.02em;
    }

    .fpw-result-card .sub {
      margin-top: 10px;
      color: var(--fuel-soft);
      font-size: 0.86rem;
      line-height: 1.4;
    }

    .fpw-fuel-education {
      grid-template-columns: 1.06fr 1fr 0.94fr;
      margin-top: 24px;
    }

    .fpw-info-card {
      min-height: 210px;
      position: relative;
      overflow: hidden;
      border-radius: 10px;
      padding: 24px 26px;
    }

    .fpw-info-card::after {
      content: "";
      position: absolute;
      right: -42px;
      bottom: -56px;
      width: 190px;
      height: 150px;
      border: 1px solid rgba(35, 215, 207, 0.12);
      border-radius: 50%;
      box-shadow: inset 0 0 28px rgba(35, 215, 207, 0.08);
      pointer-events: none;
    }

    .fpw-info-card h2 {
      margin-bottom: 18px;
      color: rgba(238, 247, 251, 0.94);
      font-size: 0.94rem;
      font-weight: 900;
      letter-spacing: 0.08em;
      text-transform: uppercase;
    }

    .fpw-number-list,
    .fpw-info-card ul {
      display: grid;
      gap: 10px;
      margin: 0;
      padding: 0;
    }

    .fpw-number-list {
      list-style: none;
    }

    .fpw-number-list li {
      display: grid;
      grid-template-columns: 24px minmax(0, 1fr);
      gap: 10px;
      align-items: start;
    }

    .fpw-number-list span {
      width: 20px;
      height: 20px;
      display: grid;
      place-items: center;
      border-radius: 50%;
      color: #02212a;
      background: var(--fuel-cyan);
      font-size: 0.78rem;
      font-weight: 900;
    }

    .fpw-info-card ul {
      padding-left: 1.1rem;
    }

    .fpw-faq-card {
      display: grid;
      gap: 8px;
    }

    .fpw-faq-card details {
      border: 1px solid rgba(126, 205, 220, 0.18);
      border-radius: 7px;
      background: rgba(3, 13, 26, 0.48);
    }

    .fpw-faq-card summary {
      min-height: 36px;
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 12px;
      padding: 0 12px;
      color: rgba(238, 247, 251, 0.9);
      cursor: pointer;
      font-size: 0.84rem;
      list-style: none;
    }

    .fpw-faq-card summary::-webkit-details-marker {
      display: none;
    }

    .fpw-faq-card summary::after {
      content: ">";
      color: var(--fuel-cyan);
    }

    .fpw-faq-card details[open] summary::after {
      transform: rotate(90deg);
    }

    .fpw-faq-card details p {
      margin: 0;
      padding: 0 12px 12px;
      font-size: 0.84rem;
    }

    .fpw-dev-output {
      margin-top: 24px;
      border-radius: 10px;
      overflow: hidden;
    }

    .fpw-dev-output summary {
      min-height: 46px;
      display: inline-flex;
      align-items: center;
      gap: 8px;
      padding: 0 18px;
      color: rgba(238, 247, 251, 0.9);
      cursor: pointer;
      font-weight: 800;
      list-style: none;
    }

    .fpw-dev-output summary::-webkit-details-marker {
      display: none;
    }

    .fpw-dev-output summary::after {
      content: ">";
      color: var(--fuel-cyan);
      font-size: 1.1rem;
      line-height: 1;
      transition: transform 160ms ease;
    }

    .fpw-dev-output[open] summary::after {
      transform: rotate(90deg);
    }

    .fpw-dev-output table {
      width: 100%;
      border-collapse: collapse;
      font-size: 0.86rem;
    }

    .fpw-dev-output th,
    .fpw-dev-output td {
      border-top: 1px solid rgba(126, 205, 220, 0.16);
      padding: 10px 12px;
      color: rgba(226, 238, 255, 0.95);
      text-align: left;
      vertical-align: top;
    }

    .fpw-dev-output th {
      color: #ffffff;
      background: rgba(255, 255, 255, 0.04);
    }

    .fpw-dev-output td.num {
      text-align: right;
      font-family: Consolas, Menlo, Monaco, monospace;
    }

    .fpw-dev-output pre {
      margin: 0;
      padding: 14px;
      border-top: 1px solid rgba(126, 205, 220, 0.16);
      color: #eef6ff;
      background: rgba(2, 8, 17, 0.78);
      overflow: auto;
      font-size: 0.76rem;
      line-height: 1.45;
    }

    .fpw-fuel-cta {
      display: grid;
      grid-template-columns: auto minmax(0, 1fr) auto;
      gap: 28px;
      align-items: center;
      margin-top: 24px;
      border-color: rgba(35, 215, 207, 0.62);
      border-radius: 12px;
      padding: 24px 36px;
      background:
        radial-gradient(circle at 10% 50%, rgba(35, 215, 207, 0.16), transparent 13rem),
        radial-gradient(circle at 88% 48%, rgba(56, 189, 248, 0.12), transparent 15rem),
        linear-gradient(180deg, rgba(4, 21, 36, 0.96), rgba(3, 12, 24, 0.98));
    }

    .fpw-fuel-cta__icon {
      width: 74px;
      height: 74px;
      display: grid;
      place-items: center;
      border: 1px solid rgba(35, 215, 207, 0.42);
      border-radius: 50%;
      color: var(--fuel-cyan);
      box-shadow: 0 0 24px rgba(35, 215, 207, 0.22);
    }

    .fpw-fuel-cta h2 {
      margin: 0;
      color: #ffffff;
      font-size: clamp(1.5rem, 3vw, 2rem);
      line-height: 1.1;
    }

    .fpw-fuel-cta p {
      margin: 8px 0 0;
    }

    .fpw-fuel-cta__button {
      min-height: 52px;
      display: inline-flex;
      align-items: center;
      justify-content: center;
      gap: 12px;
      border: 1px solid rgba(127, 252, 246, 0.8);
      border-radius: 8px;
      padding: 0 32px;
      color: #041421;
      background: linear-gradient(135deg, #28f3e8, #0db7c9);
      box-shadow: 0 0 28px rgba(33, 243, 238, 0.34);
      font-weight: 900;
      white-space: nowrap;
    }

    .fpw-fuel-cta__small {
      grid-column: 3;
      margin: -12px 0 0;
      color: #28f3e8;
      text-align: center;
      font-size: 0.86rem;
      font-weight: 800;
    }

    @media (max-width: 1180px) {
      .fpw-results-grid {
        grid-template-columns: repeat(3, minmax(0, 1fr));
      }

      .fpw-fuel-education {
        grid-template-columns: 1fr;
      }
    }

    @media (max-width: 900px) {
      .fpw-fuel-page {
        width: min(100% - 28px, 1480px);
      }

      .fpw-fuel-hero {
        background:
          linear-gradient(90deg, rgba(2, 10, 20, 0.98) 0%, rgba(3, 15, 29, 0.88) 100%),
          url("../assets/images/boat-fuel-calculator/Silent-voyage-on-calm-waters.png") center right / cover no-repeat;
      }

      .fpw-why-grid,
      .fpw-fuel-form {
        grid-template-columns: 1fr;
      }

      .fpw-panel-heading {
        grid-template-columns: 1fr;
      }

      .fpw-panel-heading::after {
        grid-row: 2;
      }

      .fpw-panel-heading p {
        grid-column: 1;
        grid-row: auto;
        white-space: normal;
      }

      .fpw-fuel-cta {
        grid-template-columns: auto minmax(0, 1fr);
      }

      .fpw-fuel-cta__button,
      .fpw-fuel-cta__small {
        grid-column: 1 / -1;
        justify-self: start;
      }
    }

    @media (max-width: 640px) {
      .fpw-fuel-page {
        width: min(100% - 28px, 1480px);
        padding-top: 16px;
      }

      .fpw-fuel-hero {
        min-height: auto;
        padding: 30px 20px;
      }

      .fpw-section-rule {
        grid-template-columns: 1fr;
        gap: 10px;
      }

      .fpw-section-rule span {
        display: none;
      }

      .fpw-why-card {
        grid-template-columns: 1fr;
      }

      .fpw-fuel-calculator-panel,
      .fpw-info-card,
      .fpw-fuel-cta {
        padding: 20px;
      }

      .fpw-field {
        grid-template-columns: 1fr;
        gap: 8px;
      }

      .field-note {
        grid-column: 1;
      }

      .calc-actions {
        display: grid;
        grid-template-columns: 1fr;
      }

      .fpw-results-grid {
        grid-template-columns: 1fr;
      }

      .fpw-fuel-cta {
        grid-template-columns: 1fr;
        text-align: left;
      }

      .fpw-fuel-cta__button {
        width: 100%;
      }
    }
  </style>
<link rel="stylesheet" href="../assets/css/top-nav.css?v=20260530-nav-cta">
  <link rel="canonical" href="https://www.floatplanwizard.com/boat-fuel-calculator/" />
</head>
<body class="fuelcalc-page">
<cfset request.fpwTopNavActive = "fuel">
<cfinclude template="../includes/top_nav.cfm">
  <main class="fpw-fuel-page fuelcalc-main">
    <section class="fpw-fuel-hero" aria-labelledby="fuel-calculator-title">
      <div class="fpw-fuel-hero__content">
        <h1 id="fuel-calculator-title">Boat Fuel Calculator</h1>

        <p class="fpw-fuel-hero__lead">
          Estimate fuel needs for your next boating trip with a simple planning tool built for real recreational boaters.
        </p>

        <p class="fpw-fuel-hero__copy">
          Good fuel planning keeps you safe, extends your range, and gives you the confidence to enjoy the water.
          Account for speed, conditions, and reserve so you arrive with options&mdash;not worries.
        </p>

        <p class="fpw-fuel-hero__callout">
          <span class="fpw-mini-compass" aria-hidden="true">
            <svg viewBox="0 0 24 24" focusable="false">
              <circle cx="12" cy="12" r="7"></circle>
              <path d="M12 2v3"></path>
              <path d="M12 19v3"></path>
              <path d="M2 12h3"></path>
              <path d="M19 12h3"></path>
              <path d="M14.8 9.2 13 13l-3.8 1.8L11 11z"></path>
            </svg>
          </span>
          <span>Plan smarter. Leave with reserve.</span>
        </p>
      </div>
    </section>

    <section class="fpw-fuel-why" aria-labelledby="why-fuel-planning-title">
      <div class="fpw-section-rule">
        <span></span>
        <h2 id="why-fuel-planning-title">Why Fuel Planning Matters</h2>
        <span></span>
      </div>

      <div class="fpw-why-grid">
        <article class="fpw-why-card">
          <div class="fpw-card-icon" aria-hidden="true">
            <svg viewBox="0 0 32 32" focusable="false">
              <path d="M16 3 27 7v8c0 7-4.7 11.8-11 14-6.3-2.2-11-7-11-14V7z"></path>
              <path d="m10.8 15.8 3.2 3.2 7.4-8"></path>
            </svg>
          </div>
          <div>
            <h3>Safety First</h3>
            <p>Running out of fuel isn&rsquo;t an option. Plan ahead and stay in control.</p>
          </div>
        </article>

        <article class="fpw-why-card">
          <div class="fpw-card-icon" aria-hidden="true">
            <svg viewBox="0 0 32 32" focusable="false">
              <path d="M10 23H8a5 5 0 0 1 0-10 8 8 0 0 1 15.5-2A6 6 0 0 1 24 23h-2"></path>
              <path d="m17 14-5 8h5l-2 6 6-10h-5z"></path>
            </svg>
          </div>
          <div>
            <h3>Weather Changes Everything</h3>
            <p>Wind, current, and sea state can significantly impact fuel burn.</p>
          </div>
        </article>

        <article class="fpw-why-card">
          <div class="fpw-card-icon" aria-hidden="true">
            <svg viewBox="0 0 32 32" focusable="false">
              <path d="M8 29V4h12a4 4 0 0 1 4 4v21"></path>
              <path d="M8 13h16"></path>
              <path d="M24 10h2l3 4v10a3 3 0 0 1-3 3h-2"></path>
              <path d="M13 7h5"></path>
            </svg>
          </div>
          <div>
            <h3>Plan With Reserve</h3>
            <p>Build in reserve so you have options when conditions or plans change.</p>
          </div>
        </article>
      </div>
    </section>

    <section class="fpw-fuel-calculator-panel" aria-labelledby="fuel-planning-inputs-title">
      <div class="fpw-panel-heading">
        <h2 id="fuel-planning-inputs-title">Fuel Planning Inputs</h2>
        <p>All units are standard for recreational boating</p>
      </div>

      <form class="fpw-fuel-form" id="qaFuelCalcForm" onsubmit="return false;">
        <div class="fpw-input-group">
          <h3>Trip &amp; Speed</h3>

          <div class="field fpw-field">
            <div class="fpw-label-row">
              <label for="totalNm">Total Distance (NM)</label>
              <button type="button" class="fpw-help" aria-label="More information about Total Distance" aria-expanded="false" aria-describedby="tip-totalNm" data-tooltip-target="tip-totalNm">?</button>
            </div>
            <span class="fpw-field__control">
              <input id="totalNm" name="totalNm" type="number" inputmode="decimal" step="0.1" min="0" value="" placeholder="Enter nautical miles">
              <em class="fpw-field__unit">NM</em>
            </span>
            <div class="fpw-tooltip" id="tip-totalNm" role="tooltip">Total trip distance used to estimate total run time and fuel needed. Greater distance increases fuel use.</div>
          </div>

          <div class="field fpw-field">
            <div class="fpw-label-row">
              <label for="mostEfficientSpeedKn">Most Efficient Speed (kn)</label>
              <button type="button" class="fpw-help" aria-label="More information about Most Efficient Speed" aria-expanded="false" aria-describedby="tip-mostEfficientSpeedKn" data-tooltip-target="tip-mostEfficientSpeedKn">?</button>
            </div>
            <span class="fpw-field__control">
              <input id="mostEfficientSpeedKn" name="mostEfficientSpeedKn" type="number" inputmode="decimal" step="0.1" min="1" max="60" value="" placeholder="Required" required aria-describedby="requiredEfficientInputsMsg">
              <em class="fpw-field__unit">kn</em>
            </span>
            <div class="fpw-tooltip" id="tip-mostEfficientSpeedKn" role="tooltip">The speed where your boat burns fuel most efficiently. Used when the selected pace favors efficiency.</div>
          </div>

          <div class="field fpw-field">
            <div class="fpw-label-row">
              <label for="maxSpeedKn">Max Speed (kn)</label>
              <button type="button" class="fpw-help" aria-label="More information about Max Speed" aria-expanded="false" aria-describedby="tip-maxSpeedKn" data-tooltip-target="tip-maxSpeedKn">?</button>
            </div>
            <span class="fpw-field__control">
              <input id="maxSpeedKn" name="maxSpeedKn" type="number" inputmode="decimal" step="0.1" min="1" max="60" value="" placeholder="Required" aria-describedby="requiredEfficientInputsMsg">
              <em class="fpw-field__unit">kn</em>
            </span>
            <div class="fpw-tooltip" id="tip-maxSpeedKn" role="tooltip">Your expected higher cruising speed. Used when pace or routing assumptions call for faster travel.</div>
          </div>

          <div class="field fpw-field">
            <div class="fpw-label-row">
              <label for="idleBurnGph">Idle Burn (GPH)</label>
              <button type="button" class="fpw-help" aria-label="More information about Idle Burn" aria-expanded="false" aria-describedby="tip-idleBurnGph" data-tooltip-target="tip-idleBurnGph">?</button>
            </div>
            <span class="fpw-field__control">
              <input id="idleBurnGph" name="idleBurnGph" type="number" inputmode="decimal" step="0.1" min="0" value="" placeholder="Optional">
              <em class="fpw-field__unit">GPH</em>
            </span>
            <div class="fpw-tooltip" id="tip-idleBurnGph" role="tooltip">Fuel burned while idling, maneuvering, or waiting. If entered, it is added into the trip estimate.</div>
          </div>

          <div class="field fpw-field">
            <div class="fpw-label-row">
              <label for="weatherPct">Weather Factor (%)</label>
              <button type="button" class="fpw-help" aria-label="More information about Weather Factor" aria-expanded="false" aria-describedby="tip-weatherPct" data-tooltip-target="tip-weatherPct">?</button>
            </div>
            <span class="fpw-field__control">
              <input id="weatherPct" name="weatherPct" type="number" inputmode="decimal" step="1" min="0" max="60" value="0">
              <em class="fpw-field__unit">%</em>
            </span>
            <div class="fpw-tooltip" id="tip-weatherPct" role="tooltip">Adds a percentage buffer to account for extra burn from wind, waves, current, or rougher conditions.</div>
          </div>

          <div class="field fpw-field">
            <div class="fpw-label-row">
              <label for="underwayHoursPerDay">Underway Hrs / Day</label>
              <button type="button" class="fpw-help" aria-label="More information about Underway Hrs / Day" aria-expanded="false" aria-describedby="tip-underwayHoursPerDay" data-tooltip-target="tip-underwayHoursPerDay">?</button>
            </div>
            <span class="fpw-field__control">
              <input id="underwayHoursPerDay" name="underwayHoursPerDay" type="number" inputmode="decimal" step="0.5" min="1" max="24" value="6.5">
              <em class="fpw-field__unit">hrs</em>
            </span>
            <div class="fpw-tooltip" id="tip-underwayHoursPerDay" role="tooltip">Used to estimate how many travel days the trip may require based on your expected daily running time.</div>
          </div>

          <div class="calc-actions">
            <button class="fpw-ghost-button" type="button" id="resetBtn">
              <span aria-hidden="true">&olarr;</span>
              Reset
            </button>

            <button class="fpw-ghost-button" type="button" id="copyJsonBtn">
              <span aria-hidden="true">[]</span>
              Copy Result JSON
            </button>
          </div>
        </div>

        <div class="fpw-input-group">
          <h3>Performance &amp; Consumption</h3>

          <div class="field fpw-field">
            <div class="fpw-label-row">
              <label for="pace">Pace</label>
              <button type="button" class="fpw-help" aria-label="More information about Pace" aria-expanded="false" aria-describedby="tip-pace" data-tooltip-target="tip-pace">?</button>
            </div>
            <span class="fpw-field__control">
              <select id="pace" name="pace">
                <option value="RELAXED">Relaxed</option>
                <option value="BALANCED">Efficient Speed</option>
                <option value="AGGRESSIVE">Max Speed</option>
              </select>
            </span>
            <div class="fpw-tooltip" id="tip-pace" role="tooltip">Changes whether the estimate leans more toward efficient-speed or max-speed consumption assumptions.</div>
          </div>

          <div class="field fpw-field">
            <div class="fpw-label-row">
              <label for="fuelBurnEfficientGph">GPH @ Efficient</label>
              <button type="button" class="fpw-help" aria-label="More information about GPH @ Efficient" aria-expanded="false" aria-describedby="tip-fuelBurnEfficientGph" data-tooltip-target="tip-fuelBurnEfficientGph">?</button>
            </div>
            <span class="fpw-field__control">
              <input id="fuelBurnEfficientGph" name="fuelBurnEfficientGph" type="number" inputmode="decimal" step="0.1" min="0" value="" placeholder="Required" required aria-describedby="requiredEfficientInputsMsg">
              <em class="fpw-field__unit">GPH</em>
            </span>
            <div class="fpw-tooltip" id="tip-fuelBurnEfficientGph" role="tooltip">Fuel burned per hour at your most efficient speed. This directly affects fuel calculations for efficient pacing.</div>
          </div>

          <div class="field fpw-field">
            <div class="fpw-label-row">
              <label for="fuelBurnGph">Fuel Burn @ Max (GPH)</label>
              <button type="button" class="fpw-help" aria-label="More information about Fuel Burn @ Max" aria-expanded="false" aria-describedby="tip-fuelBurnGph" data-tooltip-target="tip-fuelBurnGph">?</button>
            </div>
            <span class="fpw-field__control">
              <input id="fuelBurnGph" name="fuelBurnGph" type="number" inputmode="decimal" step="0.1" min="0" value="" placeholder="Required for Relaxed or Max Speed" aria-describedby="requiredEfficientInputsMsg">
              <em class="fpw-field__unit">GPH</em>
            </span>
            <div class="fpw-tooltip" id="tip-fuelBurnGph" role="tooltip">Fuel burned per hour at higher cruising speed. This is used for relaxed or max-speed estimates.</div>
            <div class="field-note">Matches the Route Generator max-speed burn input. Pace and weather adjustments are derived from this value unless Efficient Speed uses the efficient inputs instead.</div>
          </div>

          <div class="field fpw-field">
            <div class="fpw-label-row">
              <label for="idleHoursTotal">Idle Hours</label>
              <button type="button" class="fpw-help" aria-label="More information about Idle Hours" aria-expanded="false" aria-describedby="tip-idleHoursTotal" data-tooltip-target="tip-idleHoursTotal">?</button>
            </div>
            <span class="fpw-field__control">
              <input id="idleHoursTotal" name="idleHoursTotal" type="number" inputmode="decimal" step="0.1" min="0" value="" placeholder="Optional">
              <em class="fpw-field__unit">hrs</em>
            </span>
            <div class="fpw-tooltip" id="tip-idleHoursTotal" role="tooltip">Optional extra hours of idling or slow maneuvering. Increases estimated fuel use.</div>
          </div>

          <div class="field fpw-field">
            <div class="fpw-label-row">
              <label for="reservePct">Reserve (%)</label>
              <button type="button" class="fpw-help" aria-label="More information about Reserve" aria-expanded="false" aria-describedby="tip-reservePct" data-tooltip-target="tip-reservePct">?</button>
            </div>
            <span class="fpw-field__control">
              <select id="reservePct" name="reservePct">
                <option value="33" selected>Rule of Thirds - 33%</option>
                <option value="20">Standard Reserve - 20%</option>
                <option value="15">Minimum Reserve - 15%</option>
              </select>
            </span>
            <div class="fpw-tooltip" id="tip-reservePct" role="tooltip">Extra fuel held back as a safety margin. Rule of Thirds is commonly used for boating trip planning.</div>
          </div>

          <div class="field fpw-field">
            <div class="fpw-label-row">
              <label for="fuelPricePerGal">Fuel Price ($/gal)</label>
              <button type="button" class="fpw-help" aria-label="More information about Fuel Price" aria-expanded="false" aria-describedby="tip-fuelPricePerGal" data-tooltip-target="tip-fuelPricePerGal">?</button>
            </div>
            <span class="fpw-field__control">
              <input id="fuelPricePerGal" name="fuelPricePerGal" type="number" inputmode="decimal" step="0.01" min="0" value="" placeholder="Optional">
              <em class="fpw-field__unit">$/gal</em>
            </span>
            <div class="fpw-tooltip" id="tip-fuelPricePerGal" role="tooltip">Used only to estimate fuel cost. It does not change the fuel burn calculation itself.</div>
          </div>

          <div class="fpw-fuel-note">
            <span aria-hidden="true">i</span>
            <p>Fuel planning is important because wind, current, sea state, idling, and speed changes all affect real-world fuel burn.</p>
          </div>
        </div>
      </form>

      <div id="requiredEfficientInputsMsg" class="msg warn" hidden></div>
    </section>

    <section class="fpw-results-section" aria-labelledby="estimated-results-title">
      <div class="fpw-section-rule">
        <span></span>
        <h2 id="estimated-results-title">Estimated Results</h2>
        <span></span>
      </div>

      <div class="fpw-results-grid cards">
        <article class="card fpw-result-card">
          <span class="fpw-result-card__icon" aria-hidden="true">~</span>
          <h3 class="label">Total Distance</h3>
          <strong class="value" id="cardTotalDistance">0.0 NM</strong>
          <p class="sub" id="cardTotalDistanceSub">Manual distance input</p>
        </article>

        <article class="card fpw-result-card">
          <span class="fpw-result-card__icon" aria-hidden="true">o</span>
          <h3 class="label">Total Travel Hours</h3>
          <strong class="value" id="cardTotalHours">-- h</strong>
          <p class="sub" id="cardTotalHoursSub">Enter distance and inputs</p>
        </article>

        <article class="card fpw-result-card">
          <span class="fpw-result-card__icon" aria-hidden="true">F</span>
          <h3 class="label">Estimated Fuel</h3>
          <strong class="value" id="cardEstimatedFuel">-- gal</strong>
          <p class="sub" id="cardEstimatedFuelSub">Required + reserve</p>
        </article>

        <article class="card fpw-result-card">
          <span class="fpw-result-card__icon" aria-hidden="true">kn</span>
          <h3 class="label">Adjusted Speed</h3>
          <strong class="value" id="cardAdjustedSpeed">-- kn</strong>
          <p class="sub" id="cardAdjustedSpeedSub">Weather adjusted</p>
        </article>

        <article class="card fpw-result-card">
          <span class="fpw-result-card__icon" aria-hidden="true">G</span>
          <h3 class="label">Expected Avg GPH</h3>
          <strong class="value" id="cardExpectedAvgGph">-- GPH</strong>
          <p class="sub" id="cardExpectedAvgGphSub">Across all running time</p>
        </article>

        <article class="card fpw-result-card">
          <span class="fpw-result-card__icon" aria-hidden="true">$</span>
          <h3 class="label">Fuel Cost</h3>
          <strong class="value" id="cardFuelCost">--</strong>
          <p class="sub" id="cardFuelCostSub">Based on fuel price</p>
        </article>
      </div>

      <details class="fpw-dev-output">
        <summary>Calculation Breakdown and JSON</summary>
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
      </details>
    </section>

    <section class="fpw-fuel-education" aria-label="Boat fuel planning information">
      <article class="fpw-info-card">
        <h2>How to Estimate Boat Fuel Usage</h2>
        <ol class="fpw-number-list">
          <li><span>1</span>Enter your trip distance and select a pace.</li>
          <li><span>2</span>Provide your boat&rsquo;s fuel burn at efficient speed.</li>
          <li><span>3</span>Adjust for weather, idling, and reserve.</li>
          <li><span>4</span>Review results and plan with confidence.</li>
        </ol>
      </article>

      <article class="fpw-info-card">
        <h2>What Affects Boat Fuel Consumption?</h2>
        <ul>
          <li>Wind direction and strength</li>
          <li>Current, tide, and water conditions</li>
          <li>Boat load, gear, and sea state</li>
          <li>Speed, throttle, and engine efficiency</li>
          <li>Idling time and route deviations</li>
        </ul>
      </article>

      <article class="fpw-info-card fpw-faq-card">
        <h2>FAQ</h2>
        <details>
          <summary>How accurate is this calculator?</summary>
          <p>It provides an estimate based on your inputs. Actual fuel use can vary with conditions, load, speed, and engine performance.</p>
        </details>
        <details>
          <summary>What is a good reserve percentage?</summary>
          <p>Many boaters plan with a meaningful reserve such as the rule of thirds, but the right reserve depends on the trip and conditions.</p>
        </details>
        <details>
          <summary>Should I plan using max speed?</summary>
          <p>For conservative planning, compare efficient cruise numbers with higher burn scenarios so you understand your margin.</p>
        </details>
        <details>
          <summary>How does weather factor work?</summary>
          <p>The weather factor increases estimated fuel use to account for wind, current, chop, and less efficient real-world operation.</p>
        </details>
      </article>
    </section>

    <section class="fpw-fuel-cta" aria-labelledby="fuel-cta-title">
      <div class="fpw-fuel-cta__icon" aria-hidden="true">
        <svg viewBox="0 0 64 64" focusable="false">
          <circle cx="32" cy="32" r="22"></circle>
          <path d="M32 8 40 32 32 56 24 32z"></path>
          <path d="M8 32 32 24 56 32 32 40z"></path>
        </svg>
      </div>

      <div>
        <h2 id="fuel-cta-title">Plan more than fuel.</h2>
        <p>Organize your route, float plan, and trusted-contact sharing with FloatPlanWizard.</p>
      </div>

      <a class="fpw-fuel-cta__button" href="../app/join.cfm">
        <span>Join For Free</span>
        <span aria-hidden="true">&rarr;</span>
      </a>

      <p class="fpw-fuel-cta__small">No credit card required.</p>
    </section>
  </main>

  <cfinclude template="../includes/footer.cfm">

  <script>
    (function () {
      var helpButtons = document.querySelectorAll(".fpw-help");
      if (!helpButtons.length) return;

      function getTooltip(button) {
        var id = button.getAttribute("data-tooltip-target");
        return id ? document.getElementById(id) : null;
      }

      function hideTooltip(button) {
        var tooltip = getTooltip(button);
        if (!tooltip) return;

        tooltip.classList.remove("is-visible");
        button.setAttribute("aria-expanded", "false");
        delete button.dataset.clickedOpen;
      }

      function hideAllTooltips(exceptButton) {
        helpButtons.forEach(function (button) {
          if (button !== exceptButton) {
            hideTooltip(button);
          }
        });
      }

      function showTooltip(button) {
        var tooltip = getTooltip(button);
        if (!tooltip) return;

        hideAllTooltips(button);
        tooltip.classList.add("is-visible");
        button.setAttribute("aria-expanded", "true");
      }

      helpButtons.forEach(function (button) {
        button.addEventListener("pointerdown", function () {
          button.dataset.pointerIntent = "true";
          window.setTimeout(function () {
            delete button.dataset.pointerIntent;
          }, 350);
        });

        button.addEventListener("mouseleave", function () {
          hideTooltip(button);
        });

        button.addEventListener("blur", function () {
          hideTooltip(button);
        });

        button.addEventListener("click", function (event) {
          event.preventDefault();
          event.stopPropagation();

          var tooltip = getTooltip(button);
          var isOpen = tooltip && tooltip.classList.contains("is-visible");
          var wasClickOpen = button.dataset.clickedOpen === "true";

          if (isOpen && wasClickOpen) {
            hideTooltip(button);
            return;
          }

          hideAllTooltips(button);
          showTooltip(button);
          button.dataset.clickedOpen = "true";
        });
      });

      document.addEventListener("click", function (event) {
        var target = event.target;
        if (!target || typeof target.closest !== "function") return;

        if (!target.closest(".fpw-help") && !target.closest(".fpw-tooltip")) {
          hideAllTooltips();
        }
      });

      document.addEventListener("keydown", function (event) {
        if (event.key === "Escape") {
          hideAllTooltips();
        }
      });
    })();
  </script>

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
