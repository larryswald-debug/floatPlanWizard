<div id="fpwRouteGen" class="fpw-routegen">
  <style>
    #fpwRouteGen {
      --rg-bg: #07111c;
      --rg-bg-2: #091827;
      --rg-panel: rgba(16, 28, 42, 0.92);
      --rg-panel-2: rgba(20, 35, 52, 0.88);
      --rg-line: rgba(114, 159, 214, 0.16);
      --rg-line-strong: rgba(91, 199, 255, 0.34);
      --rg-text: #eef6ff;
      --rg-muted: #9db1c8;
      --rg-soft: #7f95ac;
      --rg-accent: #52b9ff;
      --rg-accent-2: #31d7b5;
      --rg-warn: #ffcf67;
      --rg-good: #34d183;
      --rg-danger: #ff7171;
      --rg-shadow: 0 16px 40px rgba(0, 0, 0, 0.34);
      --rg-r-xl: 22px;
      --rg-r-lg: 16px;
      --rg-r-md: 12px;
      --rg-mono: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, "Liberation Mono", "Courier New", monospace;
      color: var(--rg-text);
      font-family: Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      height: 100%;
      min-height: 0;
      background:
        radial-gradient(circle at top left, rgba(80, 180, 255, 0.18), transparent 26%),
        radial-gradient(circle at top right, rgba(25, 224, 198, 0.08), transparent 20%),
        linear-gradient(180deg, #06101a 0%, #07131f 42%, #081522 100%);
    }

    #fpwRouteGen * {
      box-sizing: border-box;
    }

    #fpwRouteGen .rg-modal {
      width: 100%;
      height: 100%;
      margin: 0;
      background: linear-gradient(180deg, rgba(11, 24, 37, 0.96), rgba(8, 20, 33, 0.98));
      border: 1px solid rgba(91, 199, 255, 0.14);
      border-radius: var(--rg-r-xl);
      box-shadow: var(--rg-shadow);
      overflow: hidden;
      display: grid;
      grid-template-rows: auto auto 1fr auto;
      min-height: 0;
    }

    #fpwRouteGen .rg-topbar {
      display: flex;
      align-items: flex-start;
      justify-content: space-between;
      gap: 16px;
      padding: 14px 18px 12px;
      border-bottom: 1px solid var(--rg-line);
      background: linear-gradient(180deg, rgba(36, 77, 96, 0.38), rgba(8, 22, 34, 0.1));
    }

    #fpwRouteGen .rg-title {
      font-size: 28px;
      font-weight: 900;
      letter-spacing: 0.03em;
      line-height: 1.1;
      margin: 0;
    }

    #fpwRouteGen .rg-subtitle {
      color: var(--rg-muted);
      font-size: 14px;
      margin-top: 4px;
      line-height: 1.35;
    }

    #fpwRouteGen .rg-topbar-right {
      display: flex;
      align-items: center;
      gap: 10px;
    }

    #fpwRouteGen .rg-pill {
      padding: 7px 12px;
      border-radius: 999px;
      border: 1px solid var(--rg-line);
      background: rgba(255, 255, 255, 0.03);
      color: var(--rg-muted);
      font-weight: 700;
      font-size: 12px;
      letter-spacing: 0.06em;
      text-transform: uppercase;
      white-space: nowrap;
    }

    #fpwRouteGen .rg-close {
      width: 38px;
      height: 38px;
      display: grid;
      place-items: center;
      border-radius: 12px;
      border: 1px solid var(--rg-line);
      background: rgba(255, 255, 255, 0.04);
      color: var(--rg-text);
      font-weight: 900;
      font-size: 20px;
      line-height: 1;
      cursor: pointer;
      padding: 0;
    }

    #fpwRouteGen .rg-error {
      margin: 10px 18px 0;
      border: 1px solid rgba(251, 113, 133, 0.5);
      border-radius: 12px;
      background: rgba(251, 113, 133, 0.13);
      color: #ffd4dc;
      padding: 8px 10px;
      font-size: 12px;
      line-height: 1.35;
    }

    #fpwRouteGen .rg-statusbar {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 14px;
      padding: 10px 18px;
      border-bottom: 1px solid var(--rg-line);
      color: var(--rg-muted);
      font-size: 13px;
      background: rgba(5, 14, 23, 0.4);
    }

    #fpwRouteGen .rg-statusbar #routeGenStatusContext {
      text-align: right;
    }

    #fpwRouteGen .rg-body {
      min-height: 0;
      display: grid;
      grid-template-columns: 560px 1fr;
      gap: 12px;
      padding: 12px;
      overflow: hidden;
    }

    #fpwRouteGen .rg-panel {
      min-height: 0;
      background:
        linear-gradient(180deg, rgba(255, 255, 255, 0.028), rgba(255, 255, 255, 0.012)),
        linear-gradient(180deg, rgba(20, 34, 50, 0.9), rgba(12, 22, 34, 0.96));
      border: 1px solid var(--rg-line);
      border-radius: var(--rg-r-xl);
      box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.03);
      overflow: hidden;
      display: grid;
      grid-template-rows: auto 1fr;
    }

    #fpwRouteGen .rg-panel-head {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 12px;
      padding: 12px 14px;
      border-bottom: 1px solid var(--rg-line);
      background: linear-gradient(180deg, rgba(255, 255, 255, 0.02), rgba(255, 255, 255, 0));
    }

    #fpwRouteGen .rg-eyebrow {
      color: var(--rg-muted);
      font-size: 11px;
      font-weight: 800;
      letter-spacing: 0.18em;
      text-transform: uppercase;
      margin-bottom: 3px;
    }

    #fpwRouteGen .rg-panel-title {
      font-size: 36px;
      font-weight: 850;
      line-height: 1.1;
      margin: 0;
    }

    #fpwRouteGen .rg-panel-sub {
      color: var(--rg-muted);
      font-size: 12px;
      max-width: 320px;
      text-align: right;
      line-height: 1.35;
    }

    #fpwRouteGen .rg-left-scroll,
    #fpwRouteGen .rg-right-scroll {
      min-height: 0;
      overflow: auto;
      padding: 12px;
    }

    #fpwRouteGen .rg-right-scroll {
      display: grid;
      grid-template-rows: auto auto auto 1fr;
      gap: 8px;
    }

    #fpwRouteGen .rg-stack {
      display: grid;
      gap: 10px;
    }

    #fpwRouteGen .rg-section {
      border: 1px solid var(--rg-line);
      border-radius: var(--rg-r-lg);
      background: linear-gradient(180deg, rgba(255, 255, 255, 0.02), rgba(255, 255, 255, 0.01));
      padding: 10px;
    }

    #fpwRouteGen .rg-section-head {
      display: flex;
      align-items: baseline;
      justify-content: space-between;
      gap: 10px;
      margin-bottom: 8px;
    }

    #fpwRouteGen .rg-section-title {
      color: #d8e7f6;
      font-size: 13px;
      font-weight: 850;
      letter-spacing: 0.12em;
      text-transform: uppercase;
    }

    #fpwRouteGen .rg-section-note {
      color: var(--rg-soft);
      font-size: 12px;
      line-height: 1.35;
    }

    #fpwRouteGen .rg-grid-2,
    #fpwRouteGen .rg-grid-3,
    #fpwRouteGen .rg-grid-4,
    #fpwRouteGen .rg-grid-5,
    #fpwRouteGen .rg-grid-6 {
      display: grid;
      gap: 8px;
      align-items: start;
    }

    #fpwRouteGen .rg-grid-2 { grid-template-columns: repeat(2, minmax(0, 1fr)); }
    #fpwRouteGen .rg-grid-3 { grid-template-columns: repeat(3, minmax(0, 1fr)); }
    #fpwRouteGen .rg-grid-4 { grid-template-columns: repeat(4, minmax(0, 1fr)); }
    #fpwRouteGen .rg-grid-5 { grid-template-columns: repeat(5, minmax(0, 1fr)); }
    #fpwRouteGen .rg-grid-6 { grid-template-columns: repeat(6, minmax(0, 1fr)); }

    #fpwRouteGen .rg-field,
    #fpwRouteGen .rg-mini-card,
    #fpwRouteGen .rg-timeline-shell {
      border: 1px solid rgba(114, 159, 214, 0.14);
      border-radius: 14px;
      background: rgba(255, 255, 255, 0.022);
    }

    #fpwRouteGen .rg-field {
      padding: 9px 10px 10px;
      min-height: 64px;
    }

    #fpwRouteGen .rg-field label {
      color: var(--rg-muted);
      font-size: 10px;
      font-weight: 800;
      letter-spacing: 0.16em;
      text-transform: uppercase;
      margin-bottom: 7px;
      display: block;
    }

    #fpwRouteGen .rg-field-note {
      color: var(--rg-soft);
      font-size: 11px;
      line-height: 1.3;
      margin-top: 6px;
    }

    #fpwRouteGen .form-select,
    #fpwRouteGen .form-control,
    #fpwRouteGen .rg-toggle {
      width: 100%;
      border-radius: 11px;
      border: 1px solid rgba(255, 255, 255, 0.08);
      background: rgba(5, 12, 18, 0.38);
      color: var(--rg-text);
      min-height: 40px;
      font-size: 14px;
      padding: 0 12px;
    }

    #fpwRouteGen .form-control:focus,
    #fpwRouteGen .form-select:focus {
      border-color: rgba(82, 185, 255, 0.48);
      box-shadow: 0 0 0 0.15rem rgba(82, 185, 255, 0.18);
      background: rgba(5, 12, 18, 0.5);
      color: var(--rg-text);
    }

    #fpwRouteGen .form-select option { color: #0b1220; }

    #fpwRouteGen .btn-secondary,
    #fpwRouteGen .btn-primary {
      border-radius: 11px;
      min-height: 36px;
      font-size: 14px;
      font-weight: 700;
      padding: 0 12px;
      border: 1px solid rgba(255, 255, 255, 0.08);
    }

    #fpwRouteGen .btn-secondary {
      background: linear-gradient(180deg, rgba(255, 255, 255, 0.06), rgba(255, 255, 255, 0.03));
      color: var(--rg-text);
    }

    #fpwRouteGen .btn-primary {
      background: linear-gradient(180deg, rgba(82, 185, 255, 0.22), rgba(82, 185, 255, 0.12));
      border-color: rgba(82, 185, 255, 0.28);
      color: var(--rg-text);
    }

    #fpwRouteGen .btn-secondary.btn-sm,
    #fpwRouteGen .btn-primary.btn-sm {
      min-height: 36px;
      line-height: 1.2;
    }

    #fpwRouteGen .rg-inline-actions {
      display: flex;
      align-items: center;
      gap: 8px;
    }

    #fpwRouteGen .rg-inline-actions .form-control,
    #fpwRouteGen .rg-inline-actions .form-select {
      flex: 1 1 auto;
      min-width: 0;
    }

    #fpwRouteGen .rg-switch-row {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 10px;
    }

    #fpwRouteGen .rg-switch-state {
      font-size: 12px;
      color: var(--rg-muted);
      line-height: 1.3;
      font-weight: 700;
    }

    #fpwRouteGen .form-check.form-switch.rg-switch {
      margin: 0;
      min-height: 0;
      padding-left: 2.8em;
      display: inline-flex;
      align-items: center;
      gap: 8px;
    }

    #fpwRouteGen .rg-switch .form-check-input {
      margin-top: 0;
      margin-left: -2.8em;
      width: 2.25em;
      height: 1.2em;
      border-color: rgba(255, 255, 255, 0.3);
      background-color: rgba(255, 255, 255, 0.18);
      cursor: pointer;
    }

    #fpwRouteGen .rg-switch .form-check-input:checked {
      background-color: rgba(45, 212, 191, 0.9);
      border-color: rgba(45, 212, 191, 1);
    }

    #fpwRouteGen .rg-switch .form-check-label {
      font-size: 12px;
      color: var(--rg-text);
      cursor: pointer;
      user-select: none;
      margin-bottom: 0;
    }

    #fpwRouteGen .rg-myroutes-grid {
      display: grid;
      grid-template-columns: 1fr 1.15fr;
      gap: 8px;
    }

    #fpwRouteGen .rg-hint {
      color: var(--rg-soft);
      font-size: 12px;
      line-height: 1.4;
      padding-top: 4px;
    }

    #fpwRouteGen .rg-mini-grid {
      display: grid;
      grid-template-columns: repeat(6, minmax(0, 1fr));
      gap: 8px;
      margin-bottom: 8px;
    }

    #fpwRouteGen .rg-mini-card {
      min-height: 84px;
      padding: 10px 11px;
      display: flex;
      flex-direction: column;
      justify-content: space-between;
    }

    #fpwRouteGen .rg-mini-label {
      color: var(--rg-muted);
      font-size: 10px;
      font-weight: 800;
      letter-spacing: 0.16em;
      text-transform: uppercase;
    }

    #fpwRouteGen .rg-mini-value {
      font-size: 28px;
      font-weight: 900;
      line-height: 1;
      font-family: var(--rg-mono);
    }

    #fpwRouteGen .rg-mini-value small {
      color: var(--rg-muted);
      font-size: 13px;
      font-weight: 700;
    }

    #fpwRouteGen .rg-mini-meta {
      color: var(--rg-soft);
      font-size: 12px;
      line-height: 1.35;
    }

    #fpwRouteGen .rg-config-grid {
      display: grid;
      grid-template-columns: repeat(5, minmax(0, 1fr));
      gap: 8px;
      margin-bottom: 8px;
    }

    #fpwRouteGen .rg-config-grid-bottom {
      display: grid;
      grid-template-columns: repeat(3, minmax(0, 1fr)) 1.45fr;
      gap: 8px;
      align-items: stretch;
      margin-bottom: 8px;
    }

    #fpwRouteGen .rg-weather-assist {
      border: 1px solid rgba(82, 185, 255, 0.18);
      border-radius: 14px;
      background: linear-gradient(180deg, rgba(82, 185, 255, 0.08), rgba(255, 255, 255, 0.02));
      padding: 10px;
      display: grid;
      gap: 7px;
      align-content: start;
    }

    #fpwRouteGen .rg-weather-top {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 10px;
    }

    #fpwRouteGen .rg-assist-title {
      font-size: 12px;
      font-weight: 850;
      letter-spacing: 0.14em;
      text-transform: uppercase;
      color: #dbeaff;
    }

    #fpwRouteGen .rg-assist-row {
      display: flex;
      align-items: center;
      gap: 10px;
      flex-wrap: wrap;
      min-width: 0;
    }

    #fpwRouteGen .rg-assist-value {
      font-size: 28px;
      font-weight: 900;
      line-height: 1;
      font-family: var(--rg-mono);
      margin: 0;
    }

    #fpwRouteGen .rg-assist-copy {
      color: var(--rg-muted);
      font-size: 12px;
      line-height: 1.35;
      margin: 0;
      min-width: 0;
      word-break: break-word;
    }

    #fpwRouteGen .rg-assist-actions {
      display: flex;
      gap: 8px;
      flex-wrap: wrap;
    }

    #fpwRouteGen .rg-assist-actions .btn-secondary,
    #fpwRouteGen .rg-assist-actions .btn-primary {
      flex: 1 1 150px;
      justify-content: center;
    }

    #fpwRouteGen .fpw-routegen__weatherassistpill {
      padding: 4px 9px;
      border-radius: 999px;
      font-size: 11px;
      font-weight: 800;
      letter-spacing: 0.08em;
      text-transform: uppercase;
      border: 1px solid rgba(255, 255, 255, 0.1);
      color: var(--rg-muted);
      background: rgba(255, 255, 255, 0.06);
      white-space: nowrap;
    }

    #fpwRouteGen .fpw-routegen__weatherassistpill--high {
      border-color: rgba(52, 209, 131, 0.22);
      background: rgba(52, 209, 131, 0.1);
      color: #dff9eb;
    }

    #fpwRouteGen .fpw-routegen__weatherassistpill--medium {
      border-color: rgba(245, 158, 11, 0.55);
      color: rgba(254, 215, 170, 0.98);
    }

    #fpwRouteGen .fpw-routegen__weatherassistpill--low {
      border-color: rgba(251, 113, 133, 0.55);
      color: rgba(254, 205, 211, 0.98);
    }

    #fpwRouteGen .rg-pace {
      border: 1px solid rgba(114, 159, 214, 0.14);
      border-radius: 14px;
      background: rgba(255, 255, 255, 0.022);
      padding: 10px 12px;
      display: grid;
      gap: 8px;
      margin-bottom: 8px;
    }

    #fpwRouteGen .rg-pace-top {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 10px;
    }

    #fpwRouteGen .rg-pace-title {
      font-size: 18px;
      font-weight: 850;
      line-height: 1.1;
    }

    #fpwRouteGen .rg-pace-desc {
      color: var(--rg-muted);
      font-size: 12px;
      line-height: 1.35;
      margin-top: 2px;
    }

    #fpwRouteGen .rg-pace-chip {
      border: 1px solid rgba(52, 209, 131, 0.3);
      background: rgba(52, 209, 131, 0.1);
      color: #dff9eb;
      border-radius: 999px;
      padding: 4px 9px;
      font-size: 11px;
      font-weight: 800;
      letter-spacing: 0.08em;
      text-transform: uppercase;
      white-space: nowrap;
      font-family: var(--rg-mono);
    }

    #fpwRouteGen #routeGenPace {
      width: 100%;
      accent-color: #ffffff;
    }

    #fpwRouteGen .rg-slider-labels {
      display: flex;
      justify-content: space-between;
      gap: 10px;
      color: var(--rg-muted);
      font-size: 11px;
      font-weight: 700;
    }

    #fpwRouteGen .rg-timeline-wrap {
      min-height: 0;
      display: grid;
      grid-template-rows: 1fr;
      gap: 8px;
    }

    #fpwRouteGen .rg-timeline-shell {
      min-height: 0;
      padding: 0;
      display: grid;
      grid-template-rows: auto auto 1fr;
      overflow: hidden;
    }

    #fpwRouteGen .rg-timeline-head {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 10px;
      padding: 12px 12px 10px;
      border-bottom: 1px solid rgba(114, 159, 214, 0.14);
      background: linear-gradient(180deg, rgba(255, 255, 255, 0.02), rgba(255, 255, 255, 0));
    }

    #fpwRouteGen .rg-timeline-actions {
      display: flex;
      gap: 8px;
      align-items: center;
      flex-wrap: wrap;
      justify-content: flex-end;
    }

    #fpwRouteGen .rg-timeline-actions label {
      margin: 0;
      color: var(--rg-muted);
      font-size: 12px;
      font-weight: 700;
      white-space: nowrap;
    }

    #fpwRouteGen .rg-timeline-actions .form-control {
      width: 88px;
      min-height: 36px;
      padding: 0 10px;
    }

    #fpwRouteGen .rg-timeline-actions .btn-secondary {
      min-height: 36px;
      white-space: nowrap;
    }

    #fpwRouteGen .rg-leg-columns {
      display: grid;
      grid-template-columns: 32px minmax(0, 1fr) 62px 78px 110px;
      gap: 8px;
      align-items: center;
      padding: 10px 12px;
      border-bottom: 1px solid rgba(114, 159, 214, 0.14);
      background: rgba(12, 20, 31, 0.98);
      color: var(--rg-muted);
      font-size: 11px;
      letter-spacing: 0.15em;
      text-transform: uppercase;
      font-weight: 900;
    }

    #fpwRouteGen .rg-leg-columns span:nth-child(1) { text-align: center; }
    #fpwRouteGen .rg-leg-columns span:nth-child(3),
    #fpwRouteGen .rg-leg-columns span:nth-child(4),
    #fpwRouteGen .rg-leg-columns span:nth-child(5) { text-align: right; }

    #fpwRouteGen .rg-leg-list {
      min-height: 0;
      overflow: auto;
      padding: 0;
      display: block;
      background: rgba(255, 255, 255, 0.01);
    }

    #fpwRouteGen .fpw-routegen__legwrap {
      display: block;
      margin-bottom: 0;
    }

    #fpwRouteGen .fpw-routegen__leg {
      display: grid;
      grid-template-columns: 32px minmax(0, 1fr) 62px 78px 110px;
      gap: 8px;
      align-items: center;
      padding: 12px;
      border-bottom: 1px solid rgba(114, 159, 214, 0.08);
      cursor: pointer;
      transition: background 0.18s ease, border-color 0.18s ease;
    }

    #fpwRouteGen .fpw-routegen__leg:hover {
      background: rgba(255, 255, 255, 0.02);
    }

    #fpwRouteGen .fpw-routegen__leg.is-selected {
      background: rgba(45, 212, 191, 0.12);
      box-shadow: inset 0 0 0 1px rgba(45, 212, 191, 0.35);
    }

    #fpwRouteGen .fpw-routegen__leg.is-expanded {
      border-color: rgba(45, 212, 191, 0.55);
      box-shadow: inset 0 0 0 1px rgba(45, 212, 191, 0.2);
    }

    #fpwRouteGen .fpw-routegen__legidx {
      text-align: center;
      color: var(--rg-muted);
      font-family: var(--rg-mono);
      font-size: 12px;
      font-weight: 800;
    }

    #fpwRouteGen .fpw-routegen__legroute {
      min-width: 0;
    }

    #fpwRouteGen .fpw-routegen__legname {
      font-size: 13px;
      font-weight: 900;
      line-height: 1.3;
      overflow-wrap: anywhere;
      color: #d7e7f8;
      display: inline-flex;
      gap: 6px;
      align-items: center;
      flex-wrap: wrap;
    }

    #fpwRouteGen .fpw-routegen__flag {
      border: 1px solid rgba(82, 185, 255, 0.36);
      background: rgba(82, 185, 255, 0.12);
      color: #dff2ff;
      border-radius: 999px;
      padding: 2px 8px;
      font-size: 10px;
      letter-spacing: 0.06em;
      text-transform: uppercase;
      font-weight: 800;
    }

    #fpwRouteGen .fpw-routegen__flag--override {
      border-color: rgba(245, 158, 11, 0.46);
      background: rgba(245, 158, 11, 0.14);
      color: #fde6b0;
    }

    #fpwRouteGen .fpw-routegen__leglocks,
    #fpwRouteGen .fpw-routegen__legnm {
      font-family: var(--rg-mono);
      font-size: 13px;
      color: #d7e7f8;
      text-align: right;
      white-space: nowrap;
    }

    #fpwRouteGen .fpw-routegen__legmapaction {
      display: flex;
      justify-content: flex-end;
    }

    #fpwRouteGen .fpw-routegen__legmapbtn {
      min-width: 110px;
      font-size: 13px;
      white-space: nowrap;
      padding: 6px 10px;
      line-height: 1.2;
    }

    #fpwRouteGen .fpw-routegen__leglockpanel {
      margin: 6px 2px 0 40px;
      border: 1px solid rgba(45, 212, 191, 0.22);
      border-radius: 12px;
      background: rgba(7, 16, 29, 0.92);
      padding: 10px;
    }

    #fpwRouteGen .fpw-routegen__leglockhead {
      display: flex;
      justify-content: space-between;
      gap: 10px;
      align-items: center;
      margin-bottom: 8px;
    }

    #fpwRouteGen .fpw-routegen__leglockheadactions,
    #fpwRouteGen .fpw-routegen__leglockinlineactions {
      display: flex;
      gap: 8px;
      flex-wrap: wrap;
      justify-content: flex-end;
    }

    #fpwRouteGen .fpw-routegen__lockstate {
      border: 1px solid rgba(114, 159, 214, 0.2);
      border-radius: 10px;
      background: rgba(255, 255, 255, 0.02);
      padding: 8px;
      color: var(--rg-muted);
      font-size: 12px;
      margin-bottom: 8px;
    }

    #fpwRouteGen .fpw-routegen__lockstate--error {
      border-color: rgba(251, 113, 133, 0.5);
      background: rgba(251, 113, 133, 0.13);
      color: #ffd4dc;
    }

    #fpwRouteGen .fpw-routegen__locksummary {
      display: grid;
      grid-template-columns: repeat(4, minmax(0, 1fr));
      gap: 8px;
      margin-bottom: 8px;
    }

    #fpwRouteGen .fpw-routegen__lockchip {
      border: 1px solid var(--rg-line);
      border-radius: 10px;
      background: rgba(255, 255, 255, 0.02);
      padding: 8px;
      display: grid;
      gap: 4px;
    }

    #fpwRouteGen .fpw-routegen__lockchip span {
      font-size: 10px;
      letter-spacing: 0.12em;
      text-transform: uppercase;
      color: var(--rg-muted);
      font-weight: 800;
    }

    #fpwRouteGen .fpw-routegen__lockchip strong {
      font-family: var(--rg-mono);
      font-size: 14px;
      color: #e5f2ff;
    }

    #fpwRouteGen .fpw-routegen__locklist {
      display: grid;
      gap: 8px;
      margin-bottom: 8px;
    }

    #fpwRouteGen .fpw-routegen__lockitem {
      border: 1px solid var(--rg-line);
      border-radius: 10px;
      background: rgba(255, 255, 255, 0.02);
      padding: 8px;
    }

    #fpwRouteGen .fpw-routegen__lockitemhead {
      display: flex;
      justify-content: space-between;
      gap: 8px;
      align-items: center;
      margin-bottom: 6px;
    }

    #fpwRouteGen .fpw-routegen__lockitemtitle {
      font-size: 13px;
      font-weight: 900;
      color: #d7e7f8;
    }

    #fpwRouteGen .fpw-routegen__lockitemcode {
      font-size: 11px;
      font-family: var(--rg-mono);
      color: var(--rg-muted);
    }

    #fpwRouteGen .fpw-routegen__lockitemmeta {
      display: grid;
      grid-template-columns: repeat(2, minmax(0, 1fr));
      gap: 4px 8px;
      color: var(--rg-muted);
      font-size: 12px;
      line-height: 1.3;
    }

    #fpwRouteGen .fpw-routegen__legtimeline {
      border-top: 1px dashed rgba(114, 159, 214, 0.2);
      padding-top: 8px;
      margin-top: 8px;
    }

    #fpwRouteGen .fpw-routegen__stops {
      margin-top: 4px;
      display: grid;
      gap: 5px;
    }

    #fpwRouteGen .fpw-routegen__stop {
      border: 1px solid var(--rg-line);
      border-radius: 12px;
      background: rgba(0, 0, 0, 0.18);
      display: flex;
      gap: 8px;
      justify-content: space-between;
      align-items: center;
      padding: 6px 7px;
    }

    #fpwRouteGen .fpw-routegen__stopinfo { min-width: 0; }

    #fpwRouteGen .fpw-routegen__stopname {
      font-size: 12px;
      font-weight: 900;
      line-height: 1.3;
    }

    #fpwRouteGen .fpw-routegen__stopdesc {
      margin-top: 2px;
      font-size: 11px;
      color: var(--rg-muted);
      line-height: 1.3;
    }

    #fpwRouteGen .fpw-routegen__stoptoggle {
      appearance: none;
      border: 1px solid var(--rg-line);
      background: rgba(255, 255, 255, 0.08);
      color: var(--rg-muted);
      border-radius: 999px;
      min-width: 56px;
      padding: 5px 10px;
      font-family: var(--rg-mono);
      font-size: 11px;
      cursor: pointer;
    }

    #fpwRouteGen .fpw-routegen__stoptoggle.is-on {
      border-color: rgba(45, 212, 191, 0.48);
      background: rgba(45, 212, 191, 0.14);
      color: rgba(167, 243, 208, 0.98);
    }

    #fpwRouteGen .fpw-routegen__myroutelegs {
      margin-top: 6px;
      border: 1px solid var(--rg-line);
      border-radius: 12px;
      background: rgba(0, 0, 0, 0.16);
      max-height: 180px;
      overflow: auto;
      display: grid;
      gap: 6px;
      padding: 6px;
    }

    #fpwRouteGen .fpw-routegen__myrouteleg {
      border: 1px solid var(--rg-line);
      border-radius: 10px;
      background: rgba(0, 0, 0, 0.2);
      padding: 7px;
      display: grid;
      grid-template-columns: 1fr auto;
      gap: 6px;
      align-items: center;
    }

    #fpwRouteGen .fpw-routegen__myroutelegname {
      font-size: 13px;
      font-weight: 800;
      line-height: 1.25;
    }

    #fpwRouteGen .fpw-routegen__myroutelegmeta {
      margin-top: 2px;
      font-size: 12px;
      color: var(--rg-muted);
      font-family: var(--rg-mono);
    }

    #fpwRouteGen .fpw-routegen__myroutelegactions {
      display: flex;
      align-items: center;
      gap: 6px;
      flex-wrap: wrap;
      justify-content: flex-end;
    }

    #fpwRouteGen .fpw-routegen__legmapdock {
      display: none;
    }

    #fpwRouteGen .fpw-routegen__legpanel {
      position: relative;
      min-height: 0;
      height: 100%;
      border: 1px solid rgba(82, 185, 255, 0.28);
      border-radius: 14px;
      background: linear-gradient(180deg, rgba(11, 24, 37, 0.96), rgba(8, 20, 33, 0.98));
      box-shadow: 0 16px 42px rgba(0, 0, 0, 0.45);
      overflow: hidden;
      display: grid;
      grid-template-rows: auto auto auto auto 1fr auto;
      opacity: 0;
      transform: translateY(8px);
      pointer-events: none;
      transition: opacity 0.2s ease, transform 0.2s ease;
    }

    #fpwRouteGen .fpw-routegen__legpanel.is-open {
      opacity: 1;
      transform: translateY(0);
      pointer-events: auto;
    }

    #fpwRouteGen .fpw-routegen__legpanelhead {
      display: flex;
      justify-content: space-between;
      align-items: flex-start;
      gap: 10px;
      padding: 12px 12px 8px;
      border-bottom: 1px solid rgba(114, 159, 214, 0.14);
      background: linear-gradient(180deg, rgba(255, 255, 255, 0.02), rgba(255, 255, 255, 0));
    }

    #fpwRouteGen .fpw-routegen__legclose {
      width: 34px;
      height: 34px;
      border-radius: 10px;
      border: 1px solid rgba(255, 255, 255, 0.16);
      background: rgba(255, 255, 255, 0.06);
      color: var(--rg-text);
      font-size: 18px;
      line-height: 1;
      padding: 0;
      cursor: pointer;
    }

    #fpwRouteGen .fpw-routegen__legclose:hover {
      background: rgba(255, 255, 255, 0.12);
    }

    #fpwRouteGen .fpw-routegen__legpanelmeta {
      padding: 8px 12px;
      font-size: 12px;
      color: var(--rg-muted);
      display: flex;
      flex-wrap: wrap;
      gap: 8px;
      align-items: center;
    }

    #fpwRouteGen .fpw-routegen__legpanelmeta strong {
      font-family: var(--rg-mono);
      color: #d7e7f8;
    }

    #fpwRouteGen .fpw-routegen__legsearch {
      padding: 0 12px 8px;
      display: grid;
      grid-template-columns: 1fr auto auto;
      gap: 8px;
      align-items: center;
    }

    #fpwRouteGen .fpw-routegen__legsearch .form-control {
      min-width: 0;
    }

    #fpwRouteGen .fpw-routegen__legmapstatus {
      padding: 0 12px;
      font-size: 12px;
      color: var(--rg-muted);
      margin-bottom: 8px;
      min-height: 18px;
    }

    #fpwRouteGen .fpw-routegen__legmap {
      min-height: 300px;
      border-radius: 12px;
      border: 1px solid var(--rg-line);
      overflow: hidden;
      background: rgba(0, 0, 0, 0.2);
      margin: 0 12px 8px;
    }

    #fpwRouteGen .fpw-routegen__legoverlay {
      position: fixed;
      inset: 0;
      z-index: 2100;
      background: rgba(3, 8, 15, 0.78);
      opacity: 0;
      visibility: hidden;
      pointer-events: none;
      transition: opacity 0.2s ease, visibility 0.2s ease;
    }

    #fpwRouteGen .fpw-routegen__legoverlay.is-open {
      opacity: 1;
      visibility: visible;
      pointer-events: auto;
    }

    body.fpw-routegen--overlay-open {
      overflow: hidden;
    }

    #fpwRouteGen .fpw-routegen__legoverlaydock {
      position: absolute;
      inset: 18px;
      min-height: 0;
    }

    #fpwRouteGen .fpw-routegen__legpanelactions {
      display: flex;
      gap: 8px;
      flex-wrap: wrap;
      justify-content: flex-end;
      padding: 0 12px 12px;
    }

    #fpwRouteGen .fpw-routegen__empty {
      border: 1px dashed var(--rg-line);
      border-radius: 10px;
      padding: 12px;
      color: var(--rg-muted);
      font-style: italic;
      font-size: 13px;
      margin: 8px;
    }

    #fpwRouteGen .rg-bottom-bar {
      padding: 8px 10px;
      border-top: 1px solid var(--rg-line);
      background: rgba(0, 0, 0, 0.3);
      display: flex;
      justify-content: space-between;
      align-items: center;
      gap: 10px;
      flex-wrap: wrap;
    }

    #fpwRouteGen .rg-hintline {
      font-size: 10px;
      color: var(--rg-muted);
      line-height: 1.35;
    }

    #fpwRouteGen .rg-actions {
      display: flex;
      gap: 6px;
      align-items: center;
      flex-wrap: wrap;
      justify-content: flex-end;
    }

    #fpwRouteGen .rg-actions .btn-primary,
    #fpwRouteGen .rg-actions .btn-secondary {
      min-width: 108px;
    }

    #fpwRouteGen .rg-hidden {
      display: none !important;
    }

    @media (max-width: 1500px) {
      #fpwRouteGen .rg-body { grid-template-columns: 470px 1fr; }
      #fpwRouteGen .rg-mini-grid { grid-template-columns: repeat(3, minmax(0, 1fr)); }
      #fpwRouteGen .rg-config-grid { grid-template-columns: repeat(3, minmax(0, 1fr)); }
      #fpwRouteGen .rg-config-grid-bottom { grid-template-columns: repeat(2, minmax(0, 1fr)); }
    }

    @media (max-width: 1120px) {
      #fpwRouteGen .rg-body { grid-template-columns: 1fr; }
      #fpwRouteGen .rg-mini-grid { grid-template-columns: repeat(2, minmax(0, 1fr)); }
      #fpwRouteGen .rg-grid-5,
      #fpwRouteGen .rg-grid-6,
      #fpwRouteGen .rg-myroutes-grid,
      #fpwRouteGen .rg-grid-4,
      #fpwRouteGen .rg-config-grid,
      #fpwRouteGen .rg-config-grid-bottom,
      #fpwRouteGen .fpw-routegen__locksummary,
      #fpwRouteGen .fpw-routegen__lockitemmeta { grid-template-columns: 1fr; }
      #fpwRouteGen .rg-panel-sub { text-align: left; max-width: none; }
      #fpwRouteGen .rg-statusbar { flex-direction: column; align-items: flex-start; }
      #fpwRouteGen .rg-statusbar #routeGenStatusContext { text-align: left; }
      #fpwRouteGen .rg-timeline-actions { justify-content: flex-start; }
      #fpwRouteGen .fpw-routegen__leglockpanel { margin-left: 0; }
      #fpwRouteGen .fpw-routegen__legsearch { grid-template-columns: 1fr; }
    }

    @media (max-width: 760px) {
      #fpwRouteGen .rg-topbar { flex-direction: column; align-items: flex-start; }
      #fpwRouteGen .rg-topbar-right { width: 100%; justify-content: flex-start; }
      #fpwRouteGen .rg-mini-grid { grid-template-columns: 1fr; }
      #fpwRouteGen .rg-leg-columns,
      #fpwRouteGen .fpw-routegen__leg {
        grid-template-columns: 26px minmax(0, 1fr) 52px 66px 90px;
        gap: 6px;
      }
      #fpwRouteGen .rg-leg-columns { padding: 8px; }
      #fpwRouteGen .fpw-routegen__leg { padding: 8px; }
      #fpwRouteGen .fpw-routegen__legmapbtn { min-width: 84px; padding: 4px 6px; }
      #fpwRouteGen .fpw-routegen__legmap { min-height: 260px; }
      #fpwRouteGen .fpw-routegen__legoverlaydock { inset: 8px; }
      #fpwRouteGen .rg-actions { width: 100%; justify-content: flex-start; }
      #fpwRouteGen .rg-actions .btn-primary,
      #fpwRouteGen .rg-actions .btn-secondary { flex: 1 1 auto; }
    }
  </style>

  <div class="rg-modal">
    <div class="rg-topbar">
      <div>
        <h1 class="rg-title">FPW Route Generator</h1>
        <div class="rg-subtitle">Tightened layout concept: compact controls up top, large timeline/work area below.</div>
      </div>
      <div class="rg-topbar-right">
        <span id="routeGenRouteCode" class="rg-pill">Draft</span>
        <button type="button" id="routeGenCloseBtn" class="rg-close" aria-label="Close">&times;</button>
      </div>
    </div>

    <div id="routeGenError" class="rg-error d-none" role="alert"></div>

    <div class="rg-statusbar">
      <span id="routeGenStatus">Waiting for required fields.</span>
      <span id="routeGenStatusContext">Template: - · Local live-weather assist enabled</span>
    </div>

    <div class="rg-body">
      <section class="rg-panel" aria-labelledby="routeGenSetupHeading">
        <div class="rg-panel-head">
          <div>
            <div class="rg-eyebrow">Setup</div>
            <h2 id="routeGenSetupHeading" class="rg-panel-title">Start -&gt; End -&gt; Pace</h2>
          </div>
          <div class="rg-panel-sub">Tighter section spacing, fewer nested boxes, same workflow.</div>
        </div>

        <div id="routeGenSetupPanelBody" class="rg-left-scroll">
          <div class="rg-stack">
            <section class="rg-section">
              <div class="rg-section-head">
                <div class="rg-section-title">Template</div>
                <div class="rg-section-note">Loaded from your FPW route library</div>
              </div>
              <div class="rg-field">
                <label for="routeGenTemplateSelect">Route Template</label>
                <select id="routeGenTemplateSelect" class="form-select form-select-sm" aria-label="Template selection"></select>
                <div id="routeGenTemplateMeta" class="rg-section-note mt-2"></div>
              </div>
            </section>

            <section class="rg-section">
              <div class="rg-section-head">
                <div class="rg-section-title">Trip Basics</div>
                <div class="rg-section-note">Core route settings</div>
              </div>
              <div class="rg-grid-2">
                <div class="rg-field">
                  <label for="routeGenStartLocation">Start Location</label>
                  <select id="routeGenStartLocation" class="form-select form-select-sm"></select>
                </div>
                <div class="rg-field">
                  <label for="routeGenEndLocation">End Location</label>
                  <select id="routeGenEndLocation" class="form-select form-select-sm"></select>
                </div>
                <div class="rg-field">
                  <label for="routeGenStartDate">Start Date</label>
                  <input id="routeGenStartDate" type="date" class="form-control form-control-sm">
                </div>
                <div class="rg-field">
                  <label for="routeGenDirectionToggle">Direction</label>
                  <div class="rg-switch-row">
                    <div id="routeGenDirectionState" class="rg-switch-state">Counterclockwise (CCW)</div>
                    <div class="form-check form-switch rg-switch">
                      <input id="routeGenDirectionToggle" class="form-check-input" type="checkbox" role="switch" aria-label="Reverse direction">
                      <label class="form-check-label" for="routeGenDirectionToggle">Reverse</label>
                    </div>
                  </div>
                  <input id="routeGenDirection" type="hidden" value="CCW">
                </div>
              </div>
            </section>

            <section class="rg-section">
              <div class="rg-section-head">
                <div class="rg-section-title">Optional Stops</div>
                <div class="rg-section-note">Include detours in preview/generate</div>
              </div>
              <div id="routeGenOptionalStops" class="fpw-routegen__stops">
                <div class="fpw-routegen__empty">No optional stops available for this template.</div>
              </div>
            </section>

            <section class="rg-section">
              <div class="rg-section-head">
                <div class="rg-section-title">My Routes &amp; Waypoint Builder</div>
                <div class="rg-section-note">Compact custom-route tools</div>
              </div>

              <div class="rg-myroutes-grid">
                <div class="rg-stack">
                  <div class="rg-field">
                    <label for="routeGenMyRouteName">Create Route</label>
                    <div class="rg-inline-actions">
                      <input id="routeGenMyRouteName" type="text" class="form-control form-control-sm" placeholder="Route name">
                      <button type="button" id="routeGenMyRouteCreateBtn" class="btn-secondary btn-sm">Create</button>
                    </div>
                  </div>

                  <div class="rg-field">
                    <label for="routeGenMyRouteStartWaypointSelect">Route Start Waypoint</label>
                    <div class="rg-inline-actions">
                      <select id="routeGenMyRouteStartWaypointSelect" class="form-select form-select-sm">
                        <option value="">Select start waypoint</option>
                      </select>
                      <button type="button" id="routeGenMyRouteSetStartBtn" class="btn-secondary btn-sm">Set Start</button>
                    </div>
                  </div>
                </div>

                <div class="rg-stack">
                  <div class="rg-field">
                    <label for="routeGenMyRouteSelect">My Routes</label>
                    <div class="rg-inline-actions">
                      <select id="routeGenMyRouteSelect" class="form-select form-select-sm">
                        <option value="">Select route</option>
                      </select>
                      <button type="button" id="routeGenMyRouteLoadBtn" class="btn-secondary btn-sm">Load</button>
                      <button type="button" id="routeGenMyRouteDeleteBtn" class="btn-secondary btn-sm">Delete</button>
                    </div>
                  </div>

                  <div class="rg-field">
                    <label for="routeGenMyRouteEndWaypointSelect">Add Leg by Waypoint</label>
                    <div class="rg-inline-actions">
                      <select id="routeGenMyRouteEndWaypointSelect" class="form-select form-select-sm">
                        <option value="">Select end waypoint</option>
                      </select>
                      <button type="button" id="routeGenMyRouteAddWaypointLegBtn" class="btn-secondary btn-sm">Add Leg</button>
                    </div>
                  </div>
                </div>
              </div>

              <div id="routeGenMyRouteStartMeta" class="rg-hint mt-2">Set a route start waypoint, then add legs by choosing each next waypoint.</div>

              <div class="rg-field mt-2">
                <label for="routeGenMyRouteLegList">Leg Sequence</label>
                <div class="rg-hint">Create or select a My Route to manage legs.</div>
              </div>
              <div id="routeGenMyRouteLegList" class="fpw-routegen__myroutelegs">
                <div class="fpw-routegen__empty">Create or select a My Route to manage legs.</div>
              </div>
            </section>
          </div>
        </div>
      </section>

      <section class="rg-panel" aria-labelledby="routeGenPreviewHeading">
        <div class="rg-panel-head">
          <div>
            <div class="rg-eyebrow">Preview</div>
            <h2 id="routeGenPreviewHeading" class="rg-panel-title">Route Summary and Legs</h2>
          </div>
          <div class="rg-panel-sub"><span id="routeGenPreviewTemplate">Template: -</span><br>Compact stats and controls above. Timeline gets the bulk of the height.</div>
        </div>

        <div class="rg-right-scroll">
          <div class="rg-mini-grid">
            <article class="rg-mini-card">
              <div class="rg-mini-label">Total Distance</div>
              <div id="routeGenTotalNm" class="rg-mini-value">0 <small>NM</small></div>
              <div class="rg-mini-meta">Based on selected legs</div>
            </article>
            <article class="rg-mini-card">
              <div class="rg-mini-label">Estimated Days</div>
              <div id="routeGenEstimatedDays" class="rg-mini-value">0</div>
              <div id="routeGenEstimatedDaysSub" class="rg-mini-meta">Pace-driven estimate</div>
            </article>
            <article class="rg-mini-card">
              <div class="rg-mini-label">Estimated Fuel</div>
              <div id="routeGenEstimatedFuel" class="rg-mini-value">-- <small>gal</small></div>
              <div id="routeGenEstimatedFuelSub" class="rg-mini-meta">Required + reserve</div>
            </article>
            <article class="rg-mini-card">
              <div class="rg-mini-label">Fuel Cost</div>
              <div id="routeGenFuelCost" class="rg-mini-value">-- <small>USD</small></div>
              <div id="routeGenFuelCostSub" class="rg-mini-meta">Fuel x price</div>
            </article>
            <article class="rg-mini-card">
              <div class="rg-mini-label">Locks</div>
              <div id="routeGenLockCount" class="rg-mini-value">0</div>
              <div class="rg-mini-meta">Total lock count</div>
            </article>
            <article class="rg-mini-card">
              <div class="rg-mini-label">Offshore Legs</div>
              <div id="routeGenOffshoreCount" class="rg-mini-value">0</div>
              <div class="rg-mini-meta">Optional/open-water count</div>
            </article>
          </div>

          <details id="routeGenAdvanced" class="mt-0" open>
            <summary id="routeGenAdvancedSummary" class="visually-hidden">Advanced controls</summary>

            <div class="rg-config-grid">
              <div class="rg-field">
                <label for="routeGenCruisingSpeed">Max Speed (kn)</label>
                <input id="routeGenCruisingSpeed" type="number" step="0.1" min="1" max="60" class="form-control form-control-sm" value="20">
              </div>
              <div class="rg-field">
                <label id="routeGenFuelBurnLabel" for="routeGenFuelBurnGph">Fuel Burn @ Max (GPH)</label>
                <input id="routeGenFuelBurnGph" type="number" step="0.1" min="0" class="form-control form-control-sm" value="">
                <div id="routeGenFuelBurnHint" class="rg-field-note">FPW derives pace and weather adjusted burn from max speed burn.</div>
                <div id="routeGenFuelBurnDerived" class="rg-field-note">Derived burn at current pace + weather: -- GPH</div>
              </div>
              <div class="rg-field">
                <label for="routeGenIdleBurnGph">Idle Burn (GPH)</label>
                <input id="routeGenIdleBurnGph" type="number" step="0.1" min="0" class="form-control form-control-sm" value="">
              </div>
              <div class="rg-field">
                <label for="routeGenIdleHoursTotal">Idle Hours (total)</label>
                <input id="routeGenIdleHoursTotal" type="number" step="0.1" min="0" class="form-control form-control-sm" value="">
              </div>
              <div class="rg-field">
                <label for="routeGenWeatherFactorPct">Weather Factor (%)</label>
                <input id="routeGenWeatherFactorPct" type="number" step="1" min="0" max="60" class="form-control form-control-sm" value="0">
              </div>
            </div>

            <div class="rg-config-grid-bottom">
              <div class="rg-field">
                <label for="routeGenReservePct">Reserve (%)</label>
                <input id="routeGenReservePct" type="number" step="1" min="0" max="100" class="form-control form-control-sm" value="20">
              </div>
              <div class="rg-field">
                <label for="routeGenUnderwayHoursPerDay">Underway Hrs / Day</label>
                <input id="routeGenUnderwayHoursPerDay" type="number" step="0.5" min="1" max="24" class="form-control form-control-sm" value="8">
              </div>
              <div class="rg-field">
                <label for="routeGenFuelPricePerGal">Fuel Price ($/gal)</label>
                <input id="routeGenFuelPricePerGal" type="number" step="0.01" min="0" class="form-control form-control-sm" value="" placeholder="Enter price">
              </div>

              <div id="routeGenWeatherAssist" class="rg-weather-assist" aria-live="polite">
                <div class="rg-weather-top">
                  <div class="rg-assist-title">Live Weather Assist (Local)</div>
                  <span id="routeGenWeatherSuggestConfidence" class="fpw-routegen__weatherassistpill">--</span>
                </div>
                <div class="rg-assist-row">
                  <p id="routeGenWeatherSuggestValue" class="rg-assist-value">Suggestion unavailable</p>
                  <p id="routeGenWeatherSuggestMeta" class="rg-assist-copy">Set a valid dashboard weather ZIP to refresh this suggestion.</p>
                </div>
                <p id="routeGenWeatherSuggestFactors" class="rg-assist-copy">No live weather data loaded.</p>
                <div class="rg-assist-actions">
                  <button type="button" id="routeGenWeatherSuggestRefreshBtn" class="btn-secondary btn-sm">Refresh Suggestion</button>
                  <button type="button" id="routeGenWeatherSuggestApplyBtn" class="btn-primary btn-sm" disabled>Apply Suggested</button>
                </div>
              </div>
            </div>

            <div class="rg-grid-2 rg-hidden">
              <div class="rg-field">
                <label for="routeGenComfortProfile">Comfort Profile</label>
                <select id="routeGenComfortProfile" class="form-select form-select-sm">
                  <option value="PREFER_INSIDE">Prefer Inside</option>
                  <option value="BALANCED">Balanced</option>
                  <option value="OFFSHORE_OK">Offshore OK</option>
                </select>
              </div>
              <div class="rg-field">
                <label for="routeGenOvernightBias">Overnight Bias</label>
                <select id="routeGenOvernightBias" class="form-select form-select-sm">
                  <option value="MARINAS">Marinas</option>
                  <option value="ANCHORAGES">Anchorages</option>
                  <option value="MIXED">Mixed</option>
                </select>
              </div>
            </div>
          </details>

          <div class="rg-pace">
            <div class="rg-pace-top">
              <div>
                <div class="rg-pace-title">Pace</div>
                <div class="rg-pace-desc">Pace applies 25%, 50%, or 100% of your max speed.</div>
              </div>
              <div id="routeGenPaceLabel" class="rg-pace-chip">Relaxed</div>
            </div>
            <input id="routeGenPace" type="range" min="0" max="2" step="1" value="0" aria-label="Pace">
            <div class="rg-slider-labels"><span>Relaxed</span><span>Balanced</span><span>Aggressive</span></div>
            <div id="routeGenPaceOverrideHint" class="rg-field-note d-none">Pace uses a percentage of max speed.</div>
            <button type="button" id="routeGenResetPaceBtn" class="btn-secondary btn-sm d-none">Reset Pace Defaults</button>
          </div>

          <div id="routeGenLegLayout" class="rg-timeline-wrap">
            <div class="rg-timeline-shell">
              <div class="rg-timeline-head">
                <div>
                  <div id="routeGenLegHeaderTitle" class="rg-section-title">Cruise Timeline</div>
                  <div class="rg-section-note"><span id="routeGenLegHeaderCalc">Calc: n/a</span> · <span id="routeGenLegCount">0 legs</span></div>
                </div>
                <div class="rg-timeline-actions">
                  <label for="routeGenTimelineMaxHours">Max hrs/day</label>
                  <input id="routeGenTimelineMaxHours" type="number" min="4" max="12" step="0.5" class="form-control form-control-sm" value="6.5">
                  <button type="button" id="routeGenTimelineRebuildBtn" class="btn-secondary btn-sm">Rebuild Timeline</button>
                </div>
              </div>

              <div class="rg-leg-columns" aria-hidden="true">
                <span>#</span>
                <span>Leg</span>
                <span>Locks</span>
                <span>NM</span>
                <span>Geometry</span>
              </div>

              <div id="routeGenLegList" class="rg-leg-list">
                <div class="fpw-routegen__empty">Pick template/start/end to see a live preview.</div>
              </div>
            </div>

            <div id="routeGenLegMapDock" class="fpw-routegen__legmapdock">
              <div id="routeGenLegMapPanel" class="fpw-routegen__legpanel" aria-live="polite">
                <div class="fpw-routegen__legpanelhead">
                  <div>
                    <div class="rg-eyebrow">Leg Geometry</div>
                    <div id="routeGenLegMapTitle" class="rg-section-title">Select a leg to edit geometry</div>
                  </div>
                  <div class="d-flex align-items-start gap-2">
                    <div id="routeGenLegMapSource" class="rg-section-note">Source: default</div>
                    <button type="button" id="routeGenLegOverlayCloseBtn" class="fpw-routegen__legclose" aria-label="Close map panel">&times;</button>
                  </div>
                </div>
                <div class="fpw-routegen__legpanelmeta">
                  <span>Computed NM:</span>
                  <strong id="routeGenLegMapNm">0.00</strong>
                  <span id="routeGenLegMapHint" class="rg-section-note">Draw or edit polyline, then save override.</span>
                </div>
                <div class="fpw-routegen__legsearch">
                  <input
                    id="routeGenLegMapSearchInput"
                    type="text"
                    class="form-control form-control-sm"
                    placeholder="Search place, marina, city..."
                    autocomplete="off">
                  <button type="button" id="routeGenLegMapSearchBtn" class="btn-secondary">Search</button>
                  <button type="button" id="routeGenLegMapSearchClearBtn" class="btn-secondary">Clear Pin</button>
                </div>
                <div id="routeGenLegMapStatus" class="fpw-routegen__legmapstatus">Open lock details on a leg, then click Edit Geometry.</div>
                <div id="routeGenLegMap" class="fpw-routegen__legmap"></div>
                <div class="fpw-routegen__legpanelactions">
                  <button type="button" id="routeGenLegClearBtn" class="btn-secondary">Clear Draw</button>
                  <button type="button" id="routeGenLegRevertBtn" class="btn-secondary">Revert to Default</button>
                  <button type="button" id="routeGenLegSaveBtn" class="btn-primary">Save Overrides</button>
                </div>
              </div>
            </div>
          </div>

          <div id="routeGenLegOverlay" class="fpw-routegen__legoverlay" aria-hidden="true">
            <div id="routeGenLegOverlayDock" class="fpw-routegen__legoverlaydock"></div>
          </div>
        </div>
      </section>
    </div>

    <div class="rg-bottom-bar">
      <div id="routeGenHintLine" class="rg-hintline">Recommended flow: Preview -&gt; Generate Route -&gt; Build Float Plans from dashboard.</div>
      <div class="rg-actions">
        <button type="button" id="routeGenPreviewBtn" class="btn-secondary">Preview</button>
        <button type="button" id="routeGenResetBtn" class="btn-secondary">Reset</button>
        <button type="button" id="routeGenCancelBtn" class="btn-secondary">Close</button>
        <button type="button" id="routeGenSaveBtn" class="btn-primary d-none">Save Route</button>
        <button type="button" id="routeGenGenerateBtn" class="btn-primary">Generate Route</button>
      </div>
    </div>
  </div>

  <div id="fpwCruiseTimeline" class="d-none" aria-hidden="true"></div>
</div>
