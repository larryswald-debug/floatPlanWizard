<cfprocessingdirective pageencoding="utf-8">
<cfinclude template="../includes/require_auth.cfm">
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Weather - Float Plan Wizard</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">

    <cfinclude template="../includes/header_styles.cfm">
    <link rel="stylesheet" href="<cfoutput>#request.fpwBase#</cfoutput>/assets/css/dashboard-console.css?v=20260526-cache-bump">
    <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" integrity="sha256-p4NxAoJBhIIN+hmNHrzRCf9tD/miZyoHS5obTRR9BMY=" crossorigin="" />

    <style>
      :root {
        --wx-bg: #03111d;
        --wx-panel: #071c2e;
        --wx-panel-2: #0a2438;
        --wx-line: rgba(126, 178, 220, 0.24);
        --wx-line-strong: rgba(126, 178, 220, 0.42);
        --wx-text: #f3f7fb;
        --wx-muted: #a9b8c8;
        --wx-muted-2: #7f91a4;
        --wx-blue: #56a8ff;
        --wx-teal: #34d2c8;
        --wx-green: #36d07f;
        --wx-yellow: #f4c542;
        --wx-orange: #ff7a1a;
        --wx-red: #f05b5b;
        --wx-radius: 8px;
        --wx-radius-sm: 5px;
        --wx-max: 1480px;
      }

      .dashboard-main {
        padding-top: 22px;
        padding-bottom: 36px;
        background:
          radial-gradient(circle at 20% 0%, rgba(42, 146, 183, 0.12), transparent 34%),
          linear-gradient(180deg, #051421 0%, #020a12 100%);
      }

      .fpw-weather-page {
        width: min(var(--wx-max), calc(100% - 48px));
        margin: 0 auto;
        color: var(--wx-text);
        font-family: inherit;
      }

      .fpw-weather-page *,
      .fpw-weather-page *::before,
      .fpw-weather-page *::after { box-sizing: border-box; }
      .fpw-weather-page h1,
      .fpw-weather-page h2,
      .fpw-weather-page h3,
      .fpw-weather-page p,
      .fpw-weather-page dl,
      .fpw-weather-page dd,
      .fpw-weather-page ul { margin: 0; }
      .fpw-weather-page h1 { font-size: 30px; line-height: 1.08; font-weight: 850; letter-spacing: 0; }
      .fpw-weather-page h2 { font-size: 15px; line-height: 1.2; text-transform: uppercase; letter-spacing: .045em; font-weight: 850; color: #cfe4ff; }
      .fpw-weather-page a { color: #8cc8ff; text-decoration: none; }
      .fpw-weather-page a:hover { color: #d6eeff; text-decoration: underline; }
      .muted { color: var(--wx-muted); }
      .dot-separator { color: var(--wx-muted-2); margin: 0 7px; }
      .d-none { display: none !important; }

      .weather-briefing-header {
        display: grid;
        grid-template-columns: 1fr auto;
        gap: 24px;
        align-items: start;
        margin-bottom: 18px;
      }
      .weather-title-row { display: flex; align-items: center; gap: 14px; }
      .weather-title-icon {
        width: 42px;
        height: 42px;
        border-radius: var(--wx-radius-sm);
        display: grid;
        place-items: center;
        font-size: 32px;
        line-height: 1;
        color: #7fc5ff;
        background: linear-gradient(135deg, rgba(31, 109, 178, .28), rgba(36, 211, 200, .16));
        border: 1px solid rgba(126, 178, 220, .24);
      }
      .weather-location-line,
      .weather-source-line {
        display: flex;
        align-items: center;
        flex-wrap: wrap;
        gap: 0;
      }
      .weather-location-line { margin-top: 7px; font-size: 17px; color: #eef6ff; }
      .weather-source-line { margin-top: 16px; color: var(--wx-muted); font-size: 14px; }
      .weather-favorite-button {
        margin-left: 8px;
        padding: 0;
        border: 0;
        background: transparent;
        color: #9fc7ef;
        font-size: 22px;
        line-height: 1;
      }
      .weather-location-controls { min-width: 430px; padding-top: 2px; }
      .weather-control-row { display: flex; align-items: center; justify-content: flex-end; gap: 10px; }
      .weather-control-row label { font-size: 14px; color: var(--wx-muted); }
      .weather-select,
      .weather-zip-input {
        height: 40px;
        border: 1px solid var(--wx-line-strong);
        background: rgba(255, 255, 255, .07);
        color: var(--wx-text);
        border-radius: var(--wx-radius-sm);
        padding: 0 12px;
        outline: none;
        font: inherit;
      }
      .weather-select { min-width: 150px; }
      .weather-zip-input { width: 118px; }
      .weather-select option { color: #0b1a2a; }
      .weather-select:focus,
      .weather-zip-input:focus { border-color: rgba(86, 168, 255, .8); box-shadow: 0 0 0 3px rgba(86, 168, 255, .15); }
      .weather-primary-button,
      .weather-secondary-button {
        min-height: 40px;
        border-radius: var(--wx-radius-sm);
        border: 1px solid rgba(86, 168, 255, .55);
        background: rgba(42, 105, 180, .34);
        color: #fff;
        padding: 0 18px;
        font-weight: 800;
        font-size: 14px;
        cursor: pointer;
        white-space: nowrap;
      }
      .weather-primary-button:hover,
      .weather-secondary-button:hover { background: rgba(42, 105, 180, .5); }
      .weather-secondary-button { width: 100%; background: rgba(255, 255, 255, .045); color: #d9ebff; }
      .weather-anchor-line { margin-top: 10px; text-align: right; font-size: 13px; color: var(--wx-muted); }

      .weather-panel {
        background: linear-gradient(135deg, rgba(38, 134, 194, .08), rgba(2, 9, 18, .18)), var(--wx-panel);
        border: 1px solid var(--wx-line);
        border-radius: var(--wx-radius);
        overflow: hidden;
      }
      .weather-panel-header { display: flex; align-items: center; gap: 9px; padding: 17px 18px 12px; }
      .weather-panel-header-wide { gap: 14px; }
      .weather-map-modal[hidden] { display: none; }
      .dashboard-body.weather-map-modal-open { overflow: hidden; }
      .weather-map-modal {
        position: fixed;
        inset: 0;
        z-index: 1200;
        display: grid;
        place-items: center;
        padding: 28px;
      }
      .weather-map-modal__backdrop {
        position: absolute;
        inset: 0;
        background: rgba(1, 8, 15, .78);
        backdrop-filter: blur(10px);
      }
      .weather-map-modal__dialog {
        position: relative;
        width: min(1180px, 100%);
        max-height: calc(100vh - 56px);
        display: grid;
        grid-template-rows: auto minmax(320px, 1fr);
        background: linear-gradient(135deg, rgba(38, 134, 194, .1), rgba(2, 9, 18, .2)), var(--wx-panel);
        border: 1px solid var(--wx-line-strong);
        border-radius: var(--wx-radius);
        overflow: hidden;
        box-shadow: 0 24px 70px rgba(0, 0, 0, .52);
      }
      .weather-map-modal__header {
        display: flex;
        justify-content: space-between;
        align-items: flex-start;
        gap: 16px;
        padding: 17px 18px 12px;
        border-bottom: 1px solid rgba(126, 178, 220, .14);
      }
      .weather-map-modal__close {
        width: 38px;
        height: 38px;
        display: inline-grid;
        place-items: center;
        border: 1px solid rgba(126, 178, 220, .3);
        border-radius: var(--wx-radius-sm);
        background: rgba(255, 255, 255, .06);
        color: var(--wx-text);
        cursor: pointer;
        font-size: 24px;
        line-height: 1;
      }
      .weather-map-modal__close:hover,
      .weather-map-modal__close:focus-visible {
        background: rgba(86, 168, 255, .18);
        outline: none;
      }
      .weather-map-canvas { width: 100%; min-height: 68vh; background: rgba(2, 10, 18, .36); }
      .weather-map-canvas .leaflet-control-layers { color: #0b1a2a; }
      .panel-icon { color: var(--wx-blue); font-size: 18px; line-height: 1; }
      .panel-kicker,
      .column-kicker { font-size: 12px; text-transform: uppercase; letter-spacing: .09em; color: #79b9ff; font-weight: 900; }
      .panel-subtitle { margin-top: 8px; color: var(--wx-muted); font-size: 13px; text-transform: none; letter-spacing: 0; font-weight: 500; }
      .panel-footnote { padding: 13px 18px 16px; color: var(--wx-muted); font-size: 12px; }

      .weather-scan-console {
        margin-bottom: 16px;
        padding: 16px 18px;
        border: 1px solid rgba(52, 210, 200, .34);
        border-radius: var(--wx-radius);
        background: linear-gradient(135deg, rgba(52, 210, 200, .1), rgba(86, 168, 255, .07)), var(--wx-panel);
        color: var(--wx-text);
      }
      .weather-scan-console__head { display: flex; align-items: center; gap: 14px; }
      .weather-scan-console__pulse {
        position: relative;
        width: 38px;
        height: 38px;
        flex: 0 0 auto;
        border: 1px solid rgba(52, 210, 200, .58);
        border-radius: 50%;
        background: rgba(52, 210, 200, .08);
      }
      .weather-scan-console__pulse::before,
      .weather-scan-console__pulse::after {
        content: "";
        position: absolute;
        inset: 9px;
        border-radius: 50%;
        border: 1px solid rgba(86, 168, 255, .5);
      }
      .weather-scan-console__pulse::after {
        inset: 5px;
        animation: weatherScanPulse 1.8s ease-in-out infinite;
      }
      .weather-scan-console__title { font-size: 16px; font-weight: 900; color: #fff; }
      .weather-scan-console__subtitle { margin-top: 4px; color: var(--wx-muted); font-size: 13px; }
      .weather-scan-console__timer {
        margin-left: auto;
        min-width: 84px;
        padding: 8px 10px;
        border: 1px solid rgba(126, 178, 220, .18);
        border-radius: var(--wx-radius-sm);
        background: rgba(2, 10, 18, .24);
        text-align: right;
      }
      .weather-scan-console__timer span { display: block; color: var(--wx-muted); font-size: 12px; }
      .weather-scan-console__timer strong { display: block; margin-top: 2px; color: #dff8ff; font-size: 18px; line-height: 1; }
      .weather-scan-console__status {
        margin-top: 14px;
        padding: 11px 12px;
        border: 1px solid rgba(126, 178, 220, .14);
        border-radius: var(--wx-radius-sm);
        background: rgba(255, 255, 255, .04);
      }
      .weather-scan-console__label { display: block; color: var(--wx-muted); font-size: 12px; font-weight: 800; }
      .weather-scan-console__status strong { display: block; margin-top: 3px; color: #fff; font-size: 14px; }
      .weather-scan-console__checklist {
        display: grid;
        grid-template-columns: repeat(3, minmax(0, 1fr));
        gap: 8px;
        margin-top: 14px;
        padding: 0;
        list-style: none;
      }
      .weather-scan-console__checklist li {
        min-height: 34px;
        display: flex;
        align-items: center;
        gap: 8px;
        min-width: 0;
        padding: 7px 9px;
        border: 1px solid rgba(126, 178, 220, .14);
        border-radius: var(--wx-radius-sm);
        background: rgba(2, 10, 18, .2);
        color: var(--wx-muted);
        font-size: 12px;
        line-height: 1.25;
      }
      .weather-scan-console__checklist li::before {
        content: "";
        width: 14px;
        height: 14px;
        flex: 0 0 auto;
        border: 1px solid rgba(126, 178, 220, .45);
        border-radius: 50%;
      }
      .weather-scan-console__checklist li.is-active { border-color: rgba(52, 210, 200, .55); color: #fff; }
      .weather-scan-console__checklist li.is-active::before { border-color: rgba(52, 210, 200, .9); background: rgba(52, 210, 200, .2); }
      .weather-scan-console__checklist li.is-done { color: #dff8ff; }
      .weather-scan-console__checklist li.is-done::before { content: "✓"; display: grid; place-items: center; border-color: rgba(54, 208, 127, .8); background: rgba(54, 208, 127, .18); color: #bfffdc; font-size: 10px; font-weight: 900; }
      .weather-scan-console__message {
        margin-top: 12px;
        padding: 10px 12px;
        border: 1px solid rgba(244, 197, 66, .3);
        border-radius: var(--wx-radius-sm);
        background: rgba(244, 197, 66, .08);
        color: #ffe9a6;
        font-size: 13px;
        line-height: 1.4;
      }
      .weather-scan-console__message--extended { border-color: rgba(86, 168, 255, .28); background: rgba(86, 168, 255, .08); color: #d7e9fb; }
      .weather-scan-console__skeletons { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 8px; margin-top: 14px; }
      .weather-scan-console__skeleton-card {
        position: relative;
        min-height: 56px;
        overflow: hidden;
        border: 1px solid rgba(126, 178, 220, .12);
        border-radius: var(--wx-radius-sm);
        background: rgba(255, 255, 255, .035);
      }
      .weather-scan-console__skeleton-card::after {
        content: "";
        position: absolute;
        top: 0;
        bottom: 0;
        width: 45%;
        background: linear-gradient(90deg, transparent, rgba(255, 255, 255, .09), transparent);
        animation: weatherScanSweep 1.6s linear infinite;
      }
      .weather-scan-console.is-error { border-color: rgba(244, 197, 66, .55); background: linear-gradient(135deg, rgba(244, 197, 66, .1), rgba(86, 168, 255, .05)), var(--wx-panel); }
      .weather-scan-console__sr {
        position: absolute;
        width: 1px;
        height: 1px;
        padding: 0;
        margin: -1px;
        overflow: hidden;
        clip: rect(0, 0, 0, 0);
        white-space: nowrap;
        border: 0;
      }
      .weather-marine-hydration-badge {
        display: inline-flex;
        align-items: center;
        gap: 8px;
        min-height: 28px;
        margin: -2px 0 14px;
        padding: 4px 10px;
        border: 1px solid rgba(52, 210, 200, .36);
        border-radius: var(--wx-radius-sm);
        color: #dff8ff;
        background: rgba(52, 210, 200, .1);
        font-size: 13px;
        font-weight: 800;
      }
      .weather-marine-hydration-badge::before {
        content: "";
        width: 8px;
        height: 8px;
        border-radius: 50%;
        background: var(--wx-teal);
        animation: weatherScanPulse 1.8s ease-in-out infinite;
      }
      @keyframes weatherScanPulse {
        0%, 100% { opacity: .45; transform: scale(.9); }
        50% { opacity: 1; transform: scale(1.08); }
      }
      @keyframes weatherScanSweep {
        0% { left: -55%; }
        100% { left: 110%; }
      }
      @media (prefers-reduced-motion: reduce) {
        .weather-scan-console__pulse::after,
        .weather-scan-console__skeleton-card::after,
        .weather-marine-hydration-badge::before { animation: none; }
      }
      @media (max-width: 760px) {
        .weather-scan-console__head { align-items: flex-start; flex-direction: column; }
        .weather-scan-console__timer { width: 100%; margin-left: 0; text-align: left; }
        .weather-scan-console__checklist { grid-template-columns: 1fr; }
        .weather-scan-console__skeletons { display: none; }
      }
      .weather-error-box { margin-bottom: 14px; padding: 12px 14px; border: 1px solid rgba(244, 197, 66, .55); border-radius: var(--wx-radius-sm); color: #ffe9a6; background: rgba(244, 197, 66, .12); }

      .marine-risk-panel {
        display: grid;
        grid-template-columns: 265px 1fr;
        gap: 24px;
        padding: 22px 34px 14px;
        margin-bottom: 16px;
        border: 1px solid rgba(255, 122, 26, .85);
        border-radius: var(--wx-radius);
        background: linear-gradient(90deg, rgba(255, 122, 26, .09), rgba(5, 29, 48, .86) 34%, rgba(4, 19, 32, .88)), var(--wx-panel);
      }
      .marine-risk-main { display: flex; gap: 20px; align-items: center; border-right: 1px solid var(--wx-line-strong); padding-right: 28px; }
      .marine-risk-icon { width: 58px; height: 58px; display: grid; place-items: center; font-size: 42px; color: var(--wx-orange); }
      .marine-risk-label-block .panel-kicker { color: var(--wx-orange); }
      .marine-risk-value { margin-top: 5px; font-size: 32px; line-height: 1; color: var(--wx-orange); font-weight: 900; }
      .marine-risk-subtext { margin-top: 8px; font-size: 14px; color: #fff; }
      .marine-risk-why { display: grid; grid-template-columns: 52px repeat(4, 1fr); align-items: center; gap: 18px; }
      .marine-risk-why-title { color: #fff; font-weight: 800; }
      .marine-risk-factor { display: flex; align-items: center; gap: 12px; min-width: 0; font-size: 14px; }
      .risk-factor-icon { width: 30px; height: 30px; border-radius: 50%; display: grid; place-items: center; flex: 0 0 auto; color: var(--wx-blue); font-size: 18px; background: rgba(86, 168, 255, .09); }
      .risk-factor-icon.risk-ok { color: var(--wx-green); border: 1px solid rgba(54, 208, 127, .7); }
      .marine-risk-recommendation { grid-column: 1 / -1; margin-top: 12px; padding-top: 12px; border-top: 1px solid rgba(126, 178, 220, .18); color: var(--wx-muted); text-align: center; font-size: 13px; }
      .marine-risk-recommendation span:first-child { color: #fff; margin-right: 8px; }

      .weather-summary-grid { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 14px; align-items: stretch; margin-bottom: 14px; }
      .weather-summary-grid > .weather-panel { height: 100%; }
      .conditions-hero { display: grid; grid-template-columns: 58px 1fr auto; gap: 12px; align-items: center; padding: 8px 18px 14px; border-bottom: 1px solid rgba(126, 178, 220, .14); }
      .conditions-symbol { font-size: 42px; color: var(--wx-yellow); line-height: 1; }
      .condition-label { font-size: 14px; color: #fff; font-weight: 800; }
      .conditions-temp-block { text-align: right; }
      .conditions-temp { font-size: 28px; line-height: 1; font-weight: 900; }
      .major-reading { padding: 5px 18px 0; font-size: 32px; line-height: 1; font-weight: 900; }
      .major-unit { margin-left: 4px; font-size: 16px; font-weight: 800; }
      .major-subtext { padding: 6px 18px 15px; color: #fff; font-size: 14px; }
      .tide-rising,
      .good-icon { color: var(--wx-green); }
      .weather-stat-list { padding: 0 18px; }
      .weather-stat-list > div { display: grid; grid-template-columns: minmax(88px, 1fr) auto; gap: 12px; align-items: baseline; padding: 8px 0; border-top: 1px solid rgba(126, 178, 220, .12); font-size: 14px; }
      .weather-stat-list dt { color: var(--wx-muted); }
      .weather-stat-list dd { text-align: right; color: #fff; }
      .stat-subvalue { display: block; margin-top: 2px; color: var(--wx-muted); font-size: 12px; }
      .status-badge,
      .risk-badge { display: inline-flex; align-items: center; justify-content: center; min-width: 58px; min-height: 22px; padding: 2px 9px; border-radius: var(--wx-radius-sm); border: 1px solid transparent; font-size: 12px; font-weight: 800; line-height: 1.1; }
      .badge-info { color: #dff8ff; background: rgba(52, 210, 200, .18); border-color: rgba(52, 210, 200, .38); }
      .weather-note-box { margin: 16px 18px 18px; padding: 13px 14px; border-radius: var(--wx-radius-sm); background: rgba(86, 168, 255, .08); border: 1px solid rgba(126, 178, 220, .12); color: #d7e9fb; font-size: 14px; line-height: 1.45; }
      .alert-status-block { display: flex; align-items: center; gap: 16px; padding: 11px 18px 16px; }
      .alert-check-icon { width: 44px; height: 44px; display: grid; place-items: center; border-radius: 50%; border: 2px solid rgba(54, 208, 127, .76); color: var(--wx-green); font-size: 24px; font-weight: 900; }
      .alert-status-value { font-size: 25px; line-height: 1; font-weight: 900; }
      .watched-conditions { padding: 0 18px 14px; color: var(--wx-muted); font-size: 13px; }
      .watched-title { margin-bottom: 8px; color: #cfe4ff; }
      .watched-conditions ul { list-style: none; padding: 0; }
      .weather-alert-types-list { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 0 18px; }
      .watched-conditions li { position: relative; padding: 4px 0 4px 18px; }
      .watched-conditions li::before { content: "*"; position: absolute; left: 0; color: #cfe4ff; font-size: 10px; }
      .panel-link { display: block; margin: 0 18px 18px; padding-top: 13px; border-top: 1px solid rgba(126, 178, 220, .13); font-size: 13px; }
      .weather-alerts-action { width: calc(100% - 36px); text-align: left; border: 0; border-top: 1px solid rgba(126, 178, 220, .13); background: transparent; color: var(--wx-teal); font: inherit; font-weight: 800; cursor: pointer; }
      .weather-alerts-action:focus-visible { outline: 2px solid rgba(52, 210, 200, .7); outline-offset: 3px; }
      .weather-alert-highest { margin-top: 5px; color: var(--wx-orange); font-size: 13px; font-weight: 800; }
      .weather-alert-checked { margin: 0 18px 14px; padding: 9px 12px; border: 1px solid rgba(126, 178, 220, .15); border-radius: var(--wx-radius-sm); background: rgba(86, 168, 255, .08); color: var(--wx-muted); font-size: 13px; }
      .weather-alert-active-now { padding: 0 18px 14px; color: var(--wx-muted); font-size: 13px; }
      .weather-alert-active-now ul { list-style: none; margin: 0; padding: 0; }
      .weather-alert-active-now li { display: grid; grid-template-columns: auto minmax(0, 1fr) auto; gap: 8px; align-items: baseline; padding: 3px 0; }
      .weather-alert-dot { width: 8px; height: 8px; border-radius: 50%; background: var(--wx-blue); }
      .weather-alert-dot.alert-risk-high { background: var(--wx-orange); }
      .weather-alert-dot.alert-risk-caution { background: var(--wx-yellow); }
      .weather-alert-dot.alert-risk-low { background: var(--wx-blue); }
      .weather-alert-mini-name { min-width: 0; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; color: #e9f4ff; }
      .weather-alert-mini-expire { color: var(--wx-muted-2); white-space: nowrap; }
      .weather-alert-source-note { margin: 0 18px 18px; color: var(--wx-muted-2); font-size: 12px; }
      .weather-alerts-row { margin-bottom: 14px; }
      .weather-alerts-card { width: 100%; }
      .weather-alerts-card-inner { display: grid; grid-template-columns: minmax(220px, .9fr) minmax(280px, 1.3fr) minmax(260px, 1fr); gap: 18px; align-items: start; padding: 0 18px 18px; }
      .weather-alerts-card-inner .alert-status-block,
      .weather-alerts-card-inner .weather-alert-checked,
      .weather-alerts-card-inner .watched-conditions,
      .weather-alerts-card-inner .weather-alert-active-now,
      .weather-alerts-card-inner .weather-alert-source-note { padding-left: 0; padding-right: 0; margin-left: 0; margin-right: 0; }
      .weather-alerts-card-inner .alert-status-block { padding-top: 0; }
      .weather-alerts-card-inner .weather-alerts-action { width: 100%; margin-left: 0; margin-right: 0; }

      .weather-alerts-panel { margin-bottom: 14px; }
      .weather-alerts-panel[hidden] { display: none !important; }
      .weather-alerts-panel-header { display: flex; align-items: center; justify-content: space-between; gap: 14px; padding: 16px 18px 12px; border-bottom: 1px solid rgba(126, 178, 220, .13); cursor: pointer; }
      .weather-alerts-panel-title { min-width: 0; flex: 1 1 auto; }
      .weather-alerts-panel-toggle { display: inline-flex; align-items: center; justify-content: center; width: 30px; height: 30px; border: 1px solid rgba(126, 178, 220, .32); border-radius: 999px; background: rgba(86, 168, 255, .08); color: #dff8ff; font: inherit; font-size: 15px; font-weight: 900; line-height: 1; cursor: pointer; flex: 0 0 auto; }
      .weather-alerts-panel-toggle:focus-visible { outline: 2px solid rgba(52, 210, 200, .7); outline-offset: 2px; }
      .weather-alerts-panel-chevron { display: inline-block; transition: transform 150ms ease; }
      .weather-alerts-panel-toggle[aria-expanded="true"] .weather-alerts-panel-chevron { transform: rotate(90deg); }
      .weather-alerts-panel-body[hidden] { display: none !important; }
      .weather-section-kicker { margin: 0 0 4px; color: var(--wx-blue); font-size: 12px; font-weight: 900; letter-spacing: .08em; text-transform: uppercase; }
      .weather-alerts-panel-header h2 { margin: 0; font-size: 16px; line-height: 1.3; }
      .weather-alerts-count { display: inline-flex; align-items: center; justify-content: center; min-height: 24px; padding: 2px 9px; border: 1px solid rgba(126, 178, 220, .32); border-radius: var(--wx-radius-sm); background: rgba(86, 168, 255, .1); color: #fff; font-size: 12px; font-weight: 800; white-space: nowrap; }
      .weather-alerts-panel-state { padding: 16px 18px; color: var(--wx-muted); }
      .weather-alerts-panel-state strong { display: block; margin-bottom: 4px; color: #fff; }
      .weather-alerts-list { display: grid; gap: 8px; padding: 12px 18px 18px; }
      .weather-alert-row { overflow: hidden; border: 1px solid rgba(126, 178, 220, .18); border-radius: var(--wx-radius-sm); background: rgba(7, 35, 55, .72); }
      .weather-alert-row__main { display: grid; grid-template-columns: minmax(220px, 1.15fr) minmax(380px, 2fr) auto; gap: 14px; align-items: start; padding: 12px 14px; border-left: 4px solid var(--wx-blue); }
      .weather-alert-row.alert-risk-high .weather-alert-row__main { border-left-color: var(--wx-orange); }
      .weather-alert-row.alert-risk-caution .weather-alert-row__main { border-left-color: var(--wx-yellow); }
      .weather-alert-row h3 { margin: 0; color: #fff; font-size: 15px; }
      .weather-alert-row p { margin: 5px 0 0; color: var(--wx-muted); font-size: 13px; line-height: 1.4; }
      .weather-alert-meta-grid { display: grid; grid-template-columns: repeat(6, minmax(72px, 1fr)); gap: 10px; margin: 0; }
      .weather-alert-meta-grid dt { color: var(--wx-muted-2); font-size: 11px; font-weight: 800; }
      .weather-alert-meta-grid dd { margin: 2px 0 0; color: #fff; font-size: 12px; line-height: 1.3; }
      .weather-alert-meta-grid .weather-alert-area { grid-column: span 2; }
      .weather-alert-row__actions { display: flex; gap: 8px; justify-content: flex-end; white-space: nowrap; }
      .weather-alert-detail-btn,
      .weather-alert-official-link { display: inline-flex; align-items: center; justify-content: center; min-height: 31px; padding: 5px 10px; border: 1px solid rgba(126, 178, 220, .24); border-radius: var(--wx-radius-sm); background: rgba(255, 255, 255, .035); color: #e9f4ff; font: inherit; font-size: 12px; font-weight: 800; text-decoration: none; cursor: pointer; }
      .weather-alert-official-link { color: var(--wx-blue); }
      .weather-alert-detail-btn:focus-visible,
      .weather-alert-official-link:focus-visible { outline: 2px solid rgba(52, 210, 200, .7); outline-offset: 2px; }
      .weather-alert-detail { margin: 0 14px 14px; padding: 12px; border: 1px solid rgba(126, 178, 220, .14); border-radius: var(--wx-radius-sm); background: rgba(4, 19, 32, .55); }
      .weather-alert-detail-grid { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 12px; }
      .weather-alert-detail h4 { margin: 0 0 4px; color: #dff8ff; font-size: 12px; letter-spacing: .05em; text-transform: uppercase; }
      .weather-alert-detail p { margin: 0; color: var(--wx-muted); font-size: 13px; line-height: 1.45; }
      .weather-alert-detail-wide { grid-column: 1 / -1; }
      .weather-alert-disclaimer { margin-top: 12px; padding-top: 10px; border-top: 1px solid rgba(126, 178, 220, .12); color: var(--wx-muted-2); font-size: 12px; }

      .weather-main-grid { display: grid; grid-template-columns: minmax(0, 1.45fr) minmax(390px, 1fr); gap: 14px; margin-bottom: 14px; }
      .forecast-summary-line { color: var(--wx-muted); font-size: 13px; text-transform: none; letter-spacing: 0; font-weight: 500; }
      .forecast-summary-line span { color: var(--wx-muted-2); margin: 0 7px; }
      .weather-table-wrap { overflow-x: auto; }
      .weather-forecast-table { width: 100%; min-width: 690px; border-collapse: collapse; font-size: 14px; }
      .weather-forecast-table th,
      .weather-forecast-table td { padding: 9px 18px; text-align: left; white-space: nowrap; }
      .weather-forecast-table th { background: rgba(86, 168, 255, .1); color: #fff; font-weight: 800; border-top: 1px solid rgba(126, 178, 220, .1); border-bottom: 1px solid rgba(126, 178, 220, .16); }
      .weather-forecast-table td { border-bottom: 1px solid rgba(126, 178, 220, .1); color: #e9f4ff; }
      .weather-forecast-table tbody tr:hover { background: rgba(255, 255, 255, .035); }
      .risk-high { color: var(--wx-orange); background: rgba(255, 122, 26, .13); border-color: rgba(255, 122, 26, .85); }
      .risk-caution { color: var(--wx-yellow); background: rgba(244, 197, 66, .12); border-color: rgba(244, 197, 66, .72); }
      .risk-good { color: var(--wx-green); background: rgba(54, 208, 127, .12); border-color: rgba(54, 208, 127, .72); }
      .risk-low { color: var(--wx-teal); background: rgba(52, 210, 200, .12); border-color: rgba(52, 210, 200, .5); }

      .tide-chart-header { justify-content: space-between; align-items: start; }
      .weather-toggle-group { display: inline-flex; border: 1px solid rgba(126, 178, 220, .2); border-radius: var(--wx-radius-sm); overflow: hidden; background: rgba(255, 255, 255, .04); }
      .weather-toggle-group button { height: 32px; padding: 0 14px; border: 0; border-right: 1px solid rgba(126, 178, 220, .14); background: transparent; color: var(--wx-muted); font: inherit; font-size: 13px; cursor: pointer; }
      .weather-toggle-group button:last-child { border-right: 0; }
      .weather-toggle-group .toggle-active { background: rgba(86, 168, 255, .32); color: #fff; font-weight: 800; }
      .tide-chart-area { padding: 0 16px; }
      .fpw-wx__tideGraph { display: block; border: 0; background: transparent; padding: 0; }
      .fpw-wx__tideTitle { display: none; }
      .fpw-wx__tideSvg { display: block; width: 100%; min-height: 230px; height: auto; background: rgba(2, 10, 18, .28); border: 1px solid rgba(126, 178, 220, .14); border-radius: var(--wx-radius-sm); }
      .fpw-wx__tideAxis { display: flex; justify-content: space-between; color: var(--wx-muted); font-size: 12px; padding: 7px 2px 0; }
      .fpw-wx__tideEmpty { color: var(--wx-muted); padding: 14px 0; }
      .fpw-wx__tideAxisLine { stroke: rgba(214, 236, 255, .5); stroke-width: 1; }
      .fpw-wx__tideAxisTick { stroke: rgba(214, 236, 255, .45); stroke-width: 1; }
      .fpw-wx__tideAxisLabel { fill: #d4e6f8; font-size: 11px; }
      .fpw-wx__tideAxisLabel.y { text-anchor: end; }
      .fpw-wx__tideAxisLabel.x { text-anchor: middle; }
      .fpw-wx__tideGuide { stroke: rgba(52, 210, 200, .5); stroke-dasharray: 2 3; }
      .fpw-wx__tideNowHalo { fill: rgba(52, 210, 200, .18); }
      .fpw-wx__tideNowDot { fill: #b8f8ff; stroke: rgba(52, 210, 200, .85); }
      .fpw-wx__tideExtDot { fill: #ffc24c; }
      .fpw-wx__tideExtLabel { fill: #fff0b8; font-size: 11px; font-weight: 800; }
      .tide-summary-boxes { display: grid; grid-template-columns: repeat(4, 1fr); gap: 6px; padding: 0 18px 14px; }
      .tide-summary-boxes > div { padding: 12px 10px; border: 1px solid rgba(126, 178, 220, .14); border-radius: var(--wx-radius-sm); background: rgba(86, 168, 255, .07); text-align: center; }
      .tide-summary-boxes span,
      .tide-summary-boxes small { display: block; color: var(--wx-muted); }
      .tide-summary-boxes strong { display: block; margin: 6px 0 2px; color: #fff; }
      .tide-summary-boxes small { color: #75c3ff; }
      .tide-planning-note { margin-top: 0; }
      .tide-planning-note strong { display: block; margin-bottom: 4px; color: #8cc8ff; }

      .weather-lower-grid { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 14px; margin-bottom: 14px; }
      .source-detail-list { padding: 0 18px 18px; }
      .source-detail-list > div { display: grid; grid-template-columns: 160px 1fr; gap: 16px; padding: 5px 0; border-bottom: 1px solid rgba(126, 178, 220, .09); font-size: 13px; }
      .source-detail-list dt { color: var(--wx-muted); }
      .source-detail-list dd { color: #eaf5ff; }
      .source-cache-table-wrap { margin: 0 18px 18px; overflow-x: auto; border: 1px solid rgba(126, 178, 220, .12); border-radius: var(--wx-radius-sm); }
      .source-cache-table { width: 100%; min-width: 520px; border-collapse: collapse; font-size: 12px; }
      .source-cache-table th, .source-cache-table td { padding: 8px 10px; text-align: left; border-bottom: 1px solid rgba(126, 178, 220, .09); vertical-align: top; }
      .source-cache-table th { color: #d7eaff; background: rgba(86, 168, 255, .08); font-weight: 800; }
      .source-cache-table td { color: #eaf5ff; }
      .source-cache-table .muted { color: var(--wx-muted); }
      .zone-forecast-cache-meta { margin-top: 12px; color: var(--wx-muted); font-size: 13px; }
      .map-layers-panel { align-self: stretch; display: flex; flex-direction: column; }
      .map-layer-header { justify-content: space-between; align-items: center; }
      .map-layers-panel p { padding: 2px 18px 12px; color: var(--wx-muted); line-height: 1.4; font-size: 14px; }
      .map-layer-section-label { padding: 0 18px 6px; color: #cfe4ff; font-size: 12px; font-weight: 850; letter-spacing: .06em; text-transform: uppercase; }
      .map-layer-list { margin: 0 18px 14px; padding: 0; list-style: none; color: #eaf5ff; font-size: 14px; display: grid; grid-auto-flow: column; grid-template-rows: repeat(2, auto); grid-template-columns: repeat(3, minmax(0, 1fr)); column-gap: 18px; row-gap: 2px; }
      .map-layer-list li { position: relative; padding: 4px 0 4px 22px; }
      .map-layer-list li::before { content: "✓"; position: absolute; left: 0; color: var(--wx-green); }
      @media (max-width: 640px) {
        .map-layer-list { grid-auto-flow: row; grid-template-rows: none; grid-template-columns: 1fr; }
      }
      .weather-map-preview-button {
        display: block;
        width: calc(100% - 36px);
        margin: auto;
        padding: 0;
        border: 1px solid rgba(86, 168, 255, .34);
        border-radius: var(--wx-radius-sm);
        background: rgba(86, 168, 255, .06);
        color: var(--wx-text);
        cursor: pointer;
        overflow: hidden;
        text-align: left;
      }
      .weather-map-preview-button:hover,
      .weather-map-preview-button:focus-visible {
        border-color: rgba(86, 168, 255, .7);
        box-shadow: 0 0 0 3px rgba(86, 168, 255, .12);
        outline: none;
      }
      .weather-map-preview {
        position: relative;
        display: grid;
        grid-template-columns: 50px minmax(0, 1fr);
        gap: 12px;
        align-items: center;
        min-height: 68px;
        padding: 12px 14px;
        background:
          linear-gradient(90deg, rgba(86, 168, 255, .06) 1px, transparent 1px),
          linear-gradient(0deg, rgba(86, 168, 255, .06) 1px, transparent 1px),
          rgba(2, 10, 18, .22);
        background-size: 24px 24px, 24px 24px, auto;
      }
      .weather-map-preview__icon {
        position: relative;
        width: 42px;
        height: 42px;
        display: block;
        border: 1px solid rgba(126, 178, 220, .2);
        border-radius: var(--wx-radius-sm);
        background:
          linear-gradient(90deg, rgba(52, 210, 200, .12) 1px, transparent 1px),
          linear-gradient(0deg, rgba(52, 210, 200, .12) 1px, transparent 1px),
          rgba(3, 17, 29, .72);
        background-size: 12px 12px, 12px 12px, auto;
      }
      .weather-map-preview__icon::before,
      .weather-map-preview__icon::after {
        content: "";
        position: absolute;
        pointer-events: none;
      }
      .weather-map-preview__icon::before {
        inset: 10px 7px;
        border: 1px solid rgba(126, 178, 220, .24);
        border-radius: 50%;
        transform: rotate(-12deg);
      }
      .weather-map-preview__icon::after {
        left: 7px;
        right: 7px;
        top: 21px;
        height: 2px;
        background: linear-gradient(90deg, transparent, rgba(52, 210, 200, .65), rgba(86, 168, 255, .4), transparent);
        transform: rotate(-10deg);
      }
      .weather-map-preview__copy {
        position: relative;
        z-index: 1;
        min-width: 0;
      }
      .weather-map-preview__label {
        position: relative;
        z-index: 1;
        display: block;
        color: #eaf5ff;
        font-weight: 850;
        line-height: 1.2;
      }
      .weather-map-preview__helper {
        display: block;
        margin-top: 4px;
        color: var(--wx-muted);
        font-size: 12px;
        line-height: 1.35;
      }
      .best-window-panel { padding-bottom: 18px; }
      .best-window-panel .weather-panel-header h2 { color: #69dd9f; }
      .best-window-time { padding: 10px 18px 0; color: var(--wx-green); font-size: 24px; line-height: 1.1; font-weight: 900; }
      .best-window-panel p { padding: 12px 18px; color: #e4f1ff; line-height: 1.45; font-size: 14px; }
      .best-window-divider { height: 1px; margin: 6px 18px 16px; background: rgba(126, 178, 220, .22); }
      .watch-after-block { display: grid; grid-template-columns: 1fr 52px; gap: 14px; align-items: center; padding: 0 18px; }
      .watch-label { color: var(--wx-muted); margin-bottom: 5px; }
      .watch-after-block strong { color: #fff; }
      .watch-after-block p { padding: 8px 0 0; }
      .watch-icon { width: 52px; height: 52px; border-radius: 50%; display: grid; place-items: center; color: #91c9ff; font-size: 30px; border: 1px solid rgba(126, 178, 220, .32); background: rgba(86, 168, 255, .07); }

      .zone-forecast-panel { margin-bottom: 14px; }
      .zone-forecast-body { padding: 18px 24px 20px; }
      .zone-forecast-meta { color: var(--wx-muted); font-size: 14px; }
      .zone-forecast-unavailable { color: var(--wx-muted); line-height: 1.45; }
      .zone-forecast-synopsis { margin-bottom: 16px; padding: 14px 16px; border: 1px solid rgba(126, 178, 220, .14); border-radius: var(--wx-radius-sm); background: rgba(86, 168, 255, .06); }
      .zone-forecast-synopsis h3,
      .zone-forecast-period h3 { margin-bottom: 7px; color: #d7eaff; font-size: 14px; text-transform: none; letter-spacing: 0; }
      .zone-forecast-synopsis p,
      .zone-forecast-period p { color: #e4f1ff; font-size: 14px; line-height: 1.5; }
      .zone-forecast-periods { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 12px; }
      .zone-forecast-period { padding: 14px 16px; border: 1px solid rgba(126, 178, 220, .14); border-radius: var(--wx-radius-sm); background: rgba(2, 10, 18, .22); }
      .zone-forecast-source { margin-top: 16px; padding-top: 13px; border-top: 1px solid rgba(126, 178, 220, .13); color: var(--wx-muted); font-size: 13px; }

      .active-cruise-weather-panel { padding: 0 0 18px; }
      .active-cruise-weather-header { display: flex; align-items: center; justify-content: space-between; gap: 18px; padding: 18px 24px 12px; border-bottom: 1px solid rgba(126, 178, 220, .14); }
      .active-cruise-weather-header h2 { color: #d7eaff; }
      .active-cruise-weather-header h2::before { content: "▰"; margin-right: 9px; color: #8cc8ff; }
      .active-cruise-weather-header h2 span { color: var(--wx-muted); font-weight: 700; }
      .active-route-label { display: flex; align-items: center; gap: 10px; color: var(--wx-muted); font-size: 13px; }
      .active-route-label strong { color: #fff; }
      .mini-action-link { display: inline-flex; min-height: 28px; align-items: center; padding: 0 10px; border-radius: var(--wx-radius-sm); border: 1px solid rgba(86, 168, 255, .35); background: rgba(86, 168, 255, .08); font-size: 12px; }
      .active-cruise-weather-grid { display: grid; grid-template-columns: 1.1fr .65fr 1fr 1.2fr .95fr; gap: 20px; align-items: stretch; padding: 22px 24px 0; }
      .active-weather-column { min-width: 0; padding-right: 20px; border-right: 1px solid rgba(126, 178, 220, .18); }
      .active-weather-column:nth-last-child(2) { border-right: 0; }
      .compact-detail-list { margin-top: 12px; }
      .compact-detail-list > div { display: grid; grid-template-columns: 72px 1fr; gap: 12px; padding: 4px 0; font-size: 14px; }
      .compact-detail-list dt { color: var(--wx-muted); }
      .compact-detail-list dd { color: #fff; }
      .active-weather-visual { display: flex; flex-direction: column; align-items: center; justify-content: space-between; }
      .active-weather-sun { font-size: 42px; color: var(--wx-yellow); line-height: 1; }
      .impact-list { list-style: none; padding: 10px 0 0; color: #eaf5ff; font-size: 14px; }
      .impact-list li { position: relative; padding: 4px 0 4px 22px; }
      .impact-list li::before { content: "✓"; position: absolute; left: 0; color: var(--wx-green); }
      .active-weather-column p { margin-top: 12px; color: #eaf5ff; font-size: 14px; line-height: 1.45; }
      .active-weather-detail-card { padding: 18px; border-radius: var(--wx-radius-sm); border: 1px solid rgba(126, 178, 220, .18); background: rgba(86, 168, 255, .08); color: #fff; }
      .full-width-button { display: flex; align-items: center; justify-content: center; margin-top: 15px; min-height: 44px; height: auto; text-align: center; line-height: 1.25; }
      .active-cruise-empty-state { margin: 18px 24px 0; padding: 14px 16px; border: 1px dashed rgba(126, 178, 220, .32); border-radius: var(--wx-radius-sm); color: var(--wx-muted); }

      .weather-page-footer { display: flex; align-items: center; flex-wrap: wrap; gap: 0; padding: 18px 8px 0; color: var(--wx-muted-2); font-size: 12px; }
      .weather-version { margin-left: auto; }

      @media (max-width: 1180px) {
        .fpw-weather-page { width: min(100% - 28px, var(--wx-max)); }
        .weather-briefing-header { grid-template-columns: 1fr; }
        .weather-location-controls { min-width: 0; }
        .weather-control-row,
        .weather-anchor-line { justify-content: flex-start; text-align: left; }
        .marine-risk-panel { grid-template-columns: 1fr; padding: 20px; }
        .marine-risk-main { border-right: 0; border-bottom: 1px solid var(--wx-line-strong); padding: 0 0 18px; }
        .marine-risk-why { grid-template-columns: repeat(2, minmax(0, 1fr)); }
        .marine-risk-why-title { grid-column: 1 / -1; }
        .weather-summary-grid { grid-template-columns: repeat(2, minmax(0, 1fr)); }
        .weather-alerts-card-inner { grid-template-columns: 1fr 1fr; }
        .weather-alerts-active-column { grid-column: 1 / -1; }
        .weather-main-grid { grid-template-columns: 1fr; }
        .weather-alert-row__main { grid-template-columns: 1fr; }
        .weather-alert-row__actions { justify-content: flex-start; }
        .weather-lower-grid { grid-template-columns: 1fr 1fr; }
        .best-window-panel { grid-column: 1 / -1; }
        .active-cruise-weather-grid { grid-template-columns: repeat(2, 1fr); }
        .active-weather-column { border-right: 0; padding-right: 0; }
        .active-weather-detail-card { grid-column: 1 / -1; }
      }

      @media (max-width: 760px) {
        .fpw-weather-page { width: min(100% - 28px, var(--wx-max)); }
        .fpw-weather-page h1 { font-size: 25px; }
        .weather-title-row { align-items: flex-start; }
        .weather-title-icon { width: 36px; height: 36px; font-size: 28px; }
        .weather-location-line,
        .weather-source-line { font-size: 13px; }
        .weather-control-row { display: grid; grid-template-columns: 1fr; gap: 8px; }
        .weather-select,
        .weather-zip-input,
        .weather-primary-button { width: 100%; }
        .marine-risk-panel { padding: 18px; }
        .marine-risk-main { align-items: flex-start; }
        .marine-risk-value { font-size: 28px; }
        .marine-risk-why { grid-template-columns: 1fr; gap: 14px; }
        .marine-risk-recommendation { text-align: left; }
        .weather-summary-grid,
        .weather-lower-grid { grid-template-columns: 1fr; }
        .weather-alerts-card-inner { grid-template-columns: 1fr; }
        .weather-alert-types-list { grid-template-columns: 1fr; }
        .weather-alerts-active-column { grid-column: auto; }
        .best-window-panel { grid-column: auto; }
        .conditions-hero { grid-template-columns: 52px 1fr; }
        .conditions-temp-block { grid-column: 1 / -1; text-align: left; }
        .weather-map-modal { padding: 12px; }
        .weather-map-modal__dialog { max-height: calc(100vh - 24px); grid-template-rows: auto minmax(280px, 1fr); }
        .weather-panel-header-wide,
        .weather-map-modal__header,
        .tide-chart-header,
        .active-cruise-weather-header { flex-direction: column; align-items: flex-start; }
        .weather-map-modal__close { position: absolute; top: 12px; right: 12px; }
        .weather-map-canvas { min-height: 72vh; }
        .tide-summary-boxes { grid-template-columns: repeat(2, 1fr); }
        .source-detail-list > div { grid-template-columns: 1fr; gap: 2px; }
        .active-route-label { align-items: flex-start; flex-direction: column; }
        .zone-forecast-periods { grid-template-columns: 1fr; }
        .active-cruise-weather-grid { grid-template-columns: 1fr; }
        .weather-page-footer { display: block; line-height: 1.7; }
        .weather-page-footer .dot-separator { display: none; }
        .weather-version { display: block; margin-left: 0; margin-top: 8px; }
        .weather-alerts-panel-header { flex-direction: column; }
        .weather-alert-active-now li { grid-template-columns: auto minmax(0, 1fr); }
        .weather-alert-mini-expire { grid-column: 2; }
        .weather-alert-meta-grid { grid-template-columns: repeat(2, minmax(0, 1fr)); }
        .weather-alert-meta-grid .weather-alert-area { grid-column: 1 / -1; }
        .weather-alert-row__actions { flex-direction: column; }
        .weather-alert-detail-grid { grid-template-columns: 1fr; }
      }

      @media (max-width: 460px) {
        .weather-panel-header { padding-left: 14px; padding-right: 14px; }
        .weather-stat-list,
        .source-detail-list { padding-left: 14px; padding-right: 14px; }
        .weather-stat-list > div { grid-template-columns: 1fr; gap: 3px; }
        .weather-stat-list dd { text-align: left; }
        .weather-note-box,
        .panel-link,
        .map-layers-panel p,
        .map-layer-list,
        .weather-map-preview-button,
        .best-window-time,
        .best-window-panel p,
        .watch-after-block { margin-left: 14px; margin-right: 14px; }
        .tide-summary-boxes { grid-template-columns: 1fr; }
        .weather-forecast-table { min-width: 720px; }
      }
    </style>
</head>
<body class="dashboard-body" data-fpw-page="weather">

<cfset request.fpwTopNavActive = "weather">
<cfinclude template="../includes/top_nav.cfm">

<main class="fpw-weather-page fpw-layout-rail" id="fpwWeatherPage">
  <div id="weatherLoading" class="weather-scan-console d-none" aria-labelledby="weatherScanTitle">
    <div class="weather-scan-console__head">
      <div class="weather-scan-console__pulse" aria-hidden="true"></div>
      <div>
        <div class="weather-scan-console__title" id="weatherScanTitle">Building your boating weather briefing</div>
        <div class="weather-scan-console__subtitle" id="weatherScanLocation">Checking your selected weather location</div>
      </div>
      <div class="weather-scan-console__timer" aria-hidden="true">
        <span>Elapsed</span>
        <strong id="weatherScanElapsed">0s</strong>
      </div>
    </div>
    <div class="weather-scan-console__status">
      <span class="weather-scan-console__label">Current scan</span>
      <strong id="weatherScanStep">Resolving weather location…</strong>
    </div>
    <div id="weatherScanLiveStatus" class="weather-scan-console__sr" role="status" aria-live="polite" aria-atomic="true">Resolving weather location…</div>
    <ol class="weather-scan-console__checklist" aria-label="Weather briefing progress">
      <li data-weather-scan-step="0" class="is-active">Resolving weather location…</li>
      <li data-weather-scan-step="1">Checking cached marine conditions…</li>
      <li data-weather-scan-step="2">Requesting latest forecast…</li>
      <li data-weather-scan-step="3">Reading coastal forecast and marine conditions…</li>
      <li data-weather-scan-step="4">Checking advisories…</li>
      <li data-weather-scan-step="5">Loading wind, wave, and tide context…</li>
      <li data-weather-scan-step="6">Preparing your boating weather briefing…</li>
    </ol>
    <div id="weatherScanSlowMessage" class="weather-scan-console__message d-none">Fresh NOAA/NWS marine data can take a few seconds.</div>
    <div id="weatherScanExtendedMessage" class="weather-scan-console__message weather-scan-console__message--extended d-none">Still working. Your briefing will appear automatically when the weather data returns.</div>
    <div class="weather-scan-console__skeletons" aria-hidden="true">
      <div class="weather-scan-console__skeleton-card"></div>
      <div class="weather-scan-console__skeleton-card"></div>
      <div class="weather-scan-console__skeleton-card"></div>
    </div>
  </div>
  <div id="weatherMarineHydrationBadge" class="weather-marine-hydration-badge d-none" role="status" aria-live="polite">Updating detailed marine context…</div>
  <div id="weatherError" class="weather-error-box d-none" role="alert"></div>

  <section class="weather-briefing-header">
    <div class="weather-briefing-title-block">
      <div class="weather-title-row">
        <div class="weather-title-icon" aria-hidden="true">≋</div>
        <div>
          <h1>Marine Weather Briefing</h1>
          <div class="weather-location-line">
            <span id="weatherResolvedLocation">—</span>
            <span class="dot-separator">&bull;</span>
            <span><span id="weatherLocationDetailLabel">ZIP</span> <span id="weatherZipDisplay">—</span></span>
            <button type="button" class="weather-favorite-button" aria-label="Favorite location">☆</button>
          </div>
        </div>
      </div>
      <div class="weather-source-line">
        <span id="weatherProviderBadge">NOAA/NWS</span>
        <span class="dot-separator">&bull;</span>
        <span id="weatherUpdatedAt">Updated —</span>
        <span class="dot-separator">&bull;</span>
        <span>METAR <span id="weatherMetarStation">—</span></span>
        <span class="dot-separator">&bull;</span>
        <span>Tide: <span id="weatherTideStationShort">—</span></span>
      </div>
    </div>

    <div class="weather-location-controls">
      <div class="weather-control-row">
        <label for="weatherLocationMode">Location</label>
        <select id="weatherLocationMode" class="weather-select" aria-describedby="weatherLocationModeHelp">
          <option value="zip" selected>Home Port / ZIP</option>
          <option value="coords">Coordinates</option>
        </select>
        <span id="weatherLocationModeHelp" class="d-none">Temporary weather lookup mode</span>
        <div id="weatherZipBlock">
          <label for="weatherZip" class="d-none">ZIP</label>
          <input id="weatherZip" type="text" inputmode="numeric" pattern="[0-9]{5}" maxlength="5" class="weather-zip-input" aria-describedby="weatherZipHelp" />
          <span id="weatherZipHelp" class="d-none">Temporary ZIP lookup</span>
        </div>
        <div id="weatherCoordsBlock" class="d-none">
          <label for="weatherLat" class="d-none">Latitude</label>
          <input id="weatherLat" type="text" inputmode="decimal" class="weather-zip-input" placeholder="27.9506" aria-describedby="weatherCoordsHelp" />
        </div>
        <div id="weatherCoordsLonBlock" class="d-none">
          <label for="weatherLon" class="d-none">Longitude</label>
          <input id="weatherLon" type="text" inputmode="decimal" class="weather-zip-input" placeholder="-82.4572" aria-describedby="weatherCoordsHelp" />
          <span id="weatherCoordsHelp" class="d-none">Temporary coordinate lookup</span>
        </div>
        <button type="button" id="weatherRefreshBtn" class="weather-primary-button">Update</button>
      </div>
      <div class="weather-anchor-line" id="weatherAnchorMeta">Anchor: —</div>
    </div>
  </section>

  <section class="marine-risk-panel marine-risk-high" id="weatherMarineRiskPanel">
    <div class="marine-risk-main">
      <div class="marine-risk-icon" aria-hidden="true">⬟</div>
      <div class="marine-risk-label-block">
        <div class="panel-kicker">Marine Risk</div>
        <div class="marine-risk-value" id="weatherRiskValue">—</div>
        <div class="marine-risk-subtext" id="weatherRiskSubtext">Use caution for small craft</div>
      </div>
    </div>
    <div class="marine-risk-why">
      <div class="marine-risk-why-title">Why:</div>
      <div class="marine-risk-factor">
        <div class="risk-factor-icon" aria-hidden="true">≋</div>
        <div><div id="weatherRiskWind">Wind —</div><div class="muted" id="weatherRiskGusts">Gusts —</div></div>
      </div>
      <div class="marine-risk-factor">
        <div class="risk-factor-icon" aria-hidden="true">≈</div>
        <div><div id="weatherRiskSeas">Seas —</div><div class="muted" id="weatherRiskSeasNote">—</div></div>
      </div>
      <div class="marine-risk-factor">
        <div class="risk-factor-icon" aria-hidden="true">◉</div>
        <div><div id="weatherRiskVisibility">Visibility —</div><div class="muted" id="weatherRiskVisibilityNote">—</div></div>
      </div>
      <div class="marine-risk-factor">
        <div class="risk-factor-icon risk-ok" aria-hidden="true">✓</div>
        <div><div>Alerts</div><div class="muted" id="weatherRiskAlerts">—</div></div>
      </div>
    </div>
    <div class="marine-risk-recommendation"><span>Recommendation:</span><span id="weatherRiskRecommendation">Conditions are manageable near shore but may be uncomfortable for smaller boats or exposed water.</span></div>
  </section>

  <section class="weather-summary-grid">
    <article class="weather-panel conditions-now-panel">
      <header class="weather-panel-header"><span class="panel-icon">☀</span><h2>Conditions Now</h2></header>
      <div class="conditions-hero">
        <div class="conditions-symbol" id="weatherConditionIcon">☀</div>
        <div><div class="condition-label" id="weatherConditionText">—</div></div>
        <div class="conditions-temp-block"><div class="conditions-temp" id="weatherCurrentTemp">—</div><div class="muted">Feels like <span id="weatherFeelsLike">—</span></div></div>
      </div>
      <dl class="weather-stat-list">
        <div><dt>Wind</dt><dd id="weatherCurrentWind">—</dd></div>
        <div><dt>Gusts</dt><dd id="weatherCurrentGusts">—</dd></div>
        <div><dt>Pressure</dt><dd id="weatherPressure">—</dd></div>
        <div><dt>Visibility</dt><dd id="weatherVisibility">—</dd></div>
        <div><dt>Humidity</dt><dd id="weatherHumidity">—</dd></div>
        <div><dt>Dew Point</dt><dd id="weatherDewPoint">—</dd></div>
      </dl>
      <footer class="panel-footnote">Observed <span id="weatherObservedAt">—</span> (<span id="weatherObservedStation">—</span>)</footer>
    </article>

    <article class="weather-panel waves-panel">
      <header class="weather-panel-header"><span class="panel-icon">≋</span><h2>Waves / Seas</h2></header>
      <div class="major-reading"><span id="weatherWaveHeight">—</span><span class="major-unit">ft</span></div>
      <div class="major-subtext" id="weatherWaveTrendTop">—</div>
      <dl class="weather-stat-list">
        <div><dt>Period</dt><dd><span id="weatherWavePeriod">—</span></dd></div>
        <div><dt>Direction</dt><dd id="weatherWaveDirection">—</dd></div>
        <div><dt>Wave Level</dt><dd><span class="status-badge badge-info" id="weatherWaveLevel">—</span></dd></div>
        <div><dt>Trend</dt><dd id="weatherWaveTrend">—</dd></div>
      </dl>
      <div class="weather-note-box" id="weatherWaveNote">Short-period light chop. Manageable nearshore.</div>
    </article>

    <article class="weather-panel tide-now-panel">
      <header class="weather-panel-header"><span class="panel-icon">≋</span><h2>Tide Now</h2></header>
      <div class="major-reading"><span id="weatherCurrentTide">—</span><span class="major-unit">ft</span></div>
      <div class="major-subtext tide-rising" id="weatherTideDirection">—</div>
      <dl class="weather-stat-list">
        <div><dt>Next High</dt><dd><span id="weatherNextHighTideHeight">—</span><span class="stat-subvalue" id="weatherNextHighTideTime">—</span></dd></div>
        <div><dt>Next Low</dt><dd><span id="weatherNextLowTideHeight">—</span><span class="stat-subvalue" id="weatherNextLowTideTime">—</span></dd></div>
        <div><dt>Trend</dt><dd id="weatherTideTrend">—</dd></div>
        <div><dt>Station</dt><dd id="weatherTideStation">—</dd></div>
      </dl>
    </article>

  </section>

  <section class="weather-alerts-row">
    <article class="weather-panel marine-alerts-panel weather-alerts-card">
      <header class="weather-panel-header"><span class="panel-icon alert-icon">⚠</span><h2>Marine Alerts</h2></header>
      <div class="weather-alerts-card-inner">
        <div class="weather-alerts-status-column">
          <div class="alert-status-block"><div class="alert-check-icon" id="weatherAlertIcon" aria-hidden="true">✓</div><div><div class="alert-status-value" id="weatherAlertStatus">—</div><div class="muted" id="weatherAlertSummary">—</div><div class="weather-alert-highest" id="weatherAlertHighest">—</div></div></div>
          <div class="weather-alert-checked">Last checked: <span id="weatherAlertsCheckedAt">—</span></div>
        </div>
        <div class="weather-alerts-watch-column">
          <div class="watched-conditions">
            <div class="watched-title">Alert Types Watched:</div>
            <ul class="weather-alert-types-list"><li>Small Craft Advisory</li><li>Gale Warning</li><li>Special Marine Warning</li><li>Thunderstorm Warning</li><li>Dense Fog Advisory</li><li>Coastal Flood Advisory</li></ul>
          </div>
        </div>
        <div class="weather-alerts-active-column">
          <div class="weather-alert-active-now">
            <div class="watched-title">Active Now:</div>
            <ul id="weatherAlertsActiveNow"><li>—</li></ul>
          </div>
          <button type="button" id="weatherDetailsLink" class="panel-link weather-alerts-action" aria-controls="activeNoaaAlertsPanel" aria-expanded="false">View active NOAA alerts</button>
          <div class="weather-alert-source-note">Data from NOAA/NWS. Review official alerts before departure.</div>
        </div>
      </div>
    </article>
  </section>

  <section id="activeNoaaAlertsPanel" class="weather-panel weather-alerts-panel d-none" hidden>
    <div class="weather-alerts-panel-header" id="activeNoaaAlertsHeader">
      <button type="button" id="activeNoaaAlertsToggle" class="weather-alerts-panel-toggle" aria-expanded="false" aria-controls="activeNoaaAlertsBody" aria-label="Show active NOAA alerts"><span class="weather-alerts-panel-chevron" aria-hidden="true">&gt;</span></button>
      <div class="weather-alerts-panel-title">
        <p class="weather-section-kicker">NOAA / NWS Alert Details</p>
        <h2 id="weatherAlertsPanelTitle">Active NOAA Alerts</h2>
      </div>
      <span id="weatherAlertsPanelBadge" class="weather-alerts-count">—</span>
    </div>
    <div id="activeNoaaAlertsBody" class="weather-alerts-panel-body" hidden>
      <div id="weatherAlertsPanelState" class="weather-alerts-panel-state"></div>
      <div id="activeNoaaAlertsList" class="weather-alerts-list"></div>
    </div>
  </section>

  <section class="weather-main-grid">
    <article class="weather-panel next-hours-panel">
      <header class="weather-panel-header weather-panel-header-wide"><div><h2>Next 12 Hours</h2></div><div class="forecast-summary-line" id="weatherHourlySummary">—</div></header>
      <div class="weather-table-wrap">
        <table class="weather-forecast-table">
          <thead><tr><th>Time</th><th>Wind</th><th>Gusts</th><th>Seas (ft)</th><th>Rain %</th><th>Temp</th><th>Sky</th><th>Marine Risk</th></tr></thead>
          <tbody id="weatherHourlyRows"><tr><td colspan="8">Weather forecast unavailable.</td></tr></tbody>
        </table>
      </div>
    </article>

    <article class="weather-panel tide-chart-panel">
      <header class="weather-panel-header tide-chart-header">
        <div><h2>Tide &amp; Water Level</h2><div class="panel-subtitle">Station: <span id="weatherTideChartStation">—</span></div></div>
        <div class="weather-toggle-group" aria-label="Tide chart range"><button type="button" class="toggle-active" data-tide-range="today" aria-pressed="true">Today</button><button type="button" data-tide-range="tomorrow" aria-pressed="false">Tomorrow</button></div>
      </header>
      <div class="tide-chart-area" id="weatherTideChart">
        <div id="tideGraph" class="fpw-wx__tideGraph d-none" aria-label="Tide graph">
          <div class="fpw-wx__tideTitle"><span id="tideGraphTitle">Tide (ft)</span><span id="tideGraphNowValue" class="fpw-wx__tideNow">Now —</span><span id="tideGraphStation" class="fpw-wx__muted"></span></div>
          <svg id="tideGraphSvg" class="fpw-wx__tideSvg" viewBox="0 0 320 180" preserveAspectRatio="xMidYMid meet" aria-hidden="true"></svg>
          <div class="fpw-wx__tideAxis"><span id="tideGraphStart">—</span><span class="fpw-wx__tideAxisCenter" aria-hidden="true"></span><span id="tideGraphEnd">—</span></div>
          <div id="tideGraphEmpty" class="fpw-wx__tideEmpty d-none">Tide data unavailable.</div>
        </div>
      </div>
      <div class="tide-summary-boxes">
        <div><span id="weatherTideSummaryCurrentLabel">Current</span><strong id="weatherTideSummaryCurrent">—</strong><small id="weatherTideSummaryCurrentTrend">—</small></div>
        <div><span>High</span><strong id="weatherTideSummaryHighTime">—</strong><small id="weatherTideSummaryHighHeight">—</small></div>
        <div><span>Low</span><strong id="weatherTideSummaryLowTime">—</strong><small id="weatherTideSummaryLowHeight">—</small></div>
        <div><span>Next High</span><strong id="weatherTideSummaryNextHighTime">—</strong><small id="weatherTideSummaryNextHighHeight">—</small></div>
      </div>
      <div class="weather-note-box tide-planning-note"><strong>Planning Note</strong><span id="weatherTidePlanningNote">Shallow-water routes may be more favorable before the tide falls tonight.</span></div>
    </article>
  </section>

  <section class="weather-lower-grid">
    <article class="weather-panel source-details-panel">
      <header class="weather-panel-header"><h2>Source &amp; Station Details</h2></header>
      <dl class="source-detail-list">
        <div><dt>Weather Source</dt><dd id="weatherSourceName">—</dd></div>
        <div><dt>Forecast Type</dt><dd id="weatherForecastType">—</dd></div>
        <div><dt>Resolved Location</dt><dd id="weatherSourceResolvedLocation">—</dd></div>
        <div><dt>Anchor (lat, lon)</dt><dd id="weatherSourceAnchor">—</dd></div>
        <div><dt>ZIP</dt><dd id="weatherSourceZip">—</dd></div>
        <div><dt>Observation Station</dt><dd id="weatherSourceObservationStation">—</dd></div>
        <div><dt>Tide Station</dt><dd id="weatherSourceTideStation">—</dd></div>
        <div><dt>Provider Updated</dt><dd id="weatherSourceDataUpdated">—</dd></div>
        <div><dt>FPW Cache</dt><dd id="weatherSourceCacheStatus">—</dd></div>
      </dl>
    </article>

    <article class="weather-panel map-layers-panel">
      <header class="weather-panel-header map-layer-header"><h2>NOAA Weather Map</h2></header>
      <p>NOAA nowCOAST layers are available for this location.</p>
      <div class="map-layer-section-label">Available layers</div>
      <ul class="map-layer-list" id="weatherMapLayerList"><li>No map layers delivered for this location.</li></ul>
      <button type="button" class="weather-map-preview-button" id="weatherMapLayersButton" aria-label="Open NOAA map. View radar and marine warning layers in a full-screen map.">
        <span class="weather-map-preview" aria-hidden="true">
          <span class="weather-map-preview__icon"></span>
          <span class="weather-map-preview__copy">
            <span class="weather-map-preview__label">Open NOAA Map</span>
            <span class="weather-map-preview__helper">View radar and marine warning layers in a full-screen map.</span>
          </span>
        </span>
      </button>
    </article>
    <!-- Launch placeholder hidden. -->
  </section>

  <section class="weather-panel zone-forecast-panel" id="weatherZoneForecastPanel">
    <header class="active-cruise-weather-header zone-forecast-header">
      <div>
        <h2>NOAA Zone Area Forecast</h2>
        <div class="zone-forecast-meta" id="weatherZoneForecastMeta">—</div>
      </div>
      <div class="active-route-label"><span id="weatherZoneForecastOffice">Source: NOAA/NWS Coastal Waters Forecast</span></div>
    </header>
    <div class="zone-forecast-body">
      <div class="zone-forecast-unavailable" id="weatherZoneForecastUnavailable">NOAA coastal marine zone forecast is not available for this location.</div>
      <div id="weatherZoneForecastContent" class="d-none">
        <div class="zone-forecast-synopsis" id="weatherZoneForecastSynopsisBlock">
          <h3>Synopsis</h3>
          <p id="weatherZoneForecastSynopsis">—</p>
        </div>
        <div class="zone-forecast-periods" id="weatherZoneForecastPeriods"></div>
        <div class="zone-forecast-cache-meta" id="weatherZoneForecastCacheMeta">Provider updated: — • Cache: — • Expires: —</div>
        <div class="zone-forecast-source" id="weatherZoneForecastSource">Source: NOAA/NWS Coastal Waters Forecast</div>
      </div>
    </div>
  </section>

  <footer class="weather-page-footer">
    <span>Weather data provided by NOAA/NWS</span><span class="dot-separator">&bull;</span><span>Marine forecasts and tides from NOAA nowCOAST</span><span class="dot-separator">&bull;</span><span>Times in <span id="weatherTimezoneLabel">—</span></span><span class="weather-version" id="weatherVersionLabel"></span>
  </footer>
</main>

<cfinclude template="../includes/footer.cfm">

<div class="weather-map-modal" id="weatherMapModal" hidden aria-hidden="true">
  <div class="weather-map-modal__backdrop" data-weather-map-close></div>
  <section class="weather-map-modal__dialog" role="dialog" aria-modal="true" aria-labelledby="weatherMapModalTitle">
    <header class="weather-map-modal__header">
      <div>
        <h2 id="weatherMapModalTitle">NOAA Weather Map</h2>
        <div class="panel-subtitle">Optional NOAA weather overlays for the selected location.</div>
      </div>
      <button type="button" class="weather-map-modal__close" id="weatherMapModalClose" aria-label="Close NOAA weather map">&times;</button>
    </header>
    <div id="weatherLeafletMap" class="weather-map-canvas" aria-label="NOAA weather overlay map"></div>
  </section>
</div>

<cfinclude template="../includes/footer_scripts.cfm">
<script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js" integrity="sha256-20nQCchB9co0qIjJZRGuk2/Z9VM+kNiyxNV1lvTlZBo=" crossorigin=""></script>
<script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/maps/fpw-weather-overlays.js?v=20260526-cache-bump"></script>
<script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/app/dashboard/utils.js?v=20260526-cache-bump"></script>
<script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/app/dashboard.js?v=20260526-cache-bump"></script>

</body>
</html>
