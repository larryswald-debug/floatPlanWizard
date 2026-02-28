<div id="fpwRouteGen" class="fpw-routegen">
  <style>
    .fpw-routegen {
      --rg-bg: #0b1220;
      --rg-panel: rgba(255, 255, 255, 0.06);
      --rg-panel-2: rgba(255, 255, 255, 0.085);
      --rg-line: rgba(255, 255, 255, 0.1);
      --rg-text: rgba(255, 255, 255, 0.92);
      --rg-muted: rgba(255, 255, 255, 0.7);
      --rg-subtle: rgba(255, 255, 255, 0.55);
      --rg-brand: #2dd4bf;
      --rg-warn: #f59e0b;
      --rg-danger: #fb7185;
      --rg-ok: #34d399;
      --rg-shadow: 0 18px 50px rgba(0, 0, 0, 0.45);
      --rg-radius: 16px;
      --rg-mono: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, "Liberation Mono", "Courier New", monospace;
      --rg-sans: ui-sans-serif, -apple-system, Segoe UI, Roboto, Helvetica, Arial, sans-serif;
      color: var(--rg-text);
      font-family: var(--rg-sans);
      height: 100%;
      min-height: 100%;
      background:
        radial-gradient(900px 500px at 75% 0%, rgba(45, 212, 191, 0.1), transparent 60%),
        radial-gradient(800px 450px at 10% 8%, rgba(56, 189, 248, 0.1), transparent 62%),
        linear-gradient(180deg, #08101d, #070b13 58%, #060a12);
    }

    .fpw-routegen * {
      box-sizing: border-box;
    }

    .fpw-routegen__frame {
      height: 100%;
      min-height: 100%;
      border: 1px solid var(--rg-line);
      border-radius: 18px;
      overflow: hidden;
      background:
        linear-gradient(180deg, rgba(255, 255, 255, 0.06), rgba(255, 255, 255, 0.03)),
        radial-gradient(700px 380px at 20% 0%, rgba(45, 212, 191, 0.09), transparent 64%);
      box-shadow: var(--rg-shadow);
      display: flex;
      flex-direction: column;
    }

    .fpw-routegen__topbar {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 12px;
      padding: 12px 14px;
      border-bottom: 1px solid var(--rg-line);
      background: rgba(0, 0, 0, 0.24);
    }

    .fpw-routegen__titlewrap {
      min-width: 0;
    }

    .fpw-routegen__title {
      margin: 0;
      font-size: 15px;
      letter-spacing: 0.08em;
      text-transform: uppercase;
      font-weight: 900;
    }

    .fpw-routegen__subtitle {
      margin-top: 3px;
      font-size: 12px;
      color: var(--rg-muted);
      line-height: 1.35;
    }

    .fpw-routegen__topactions {
      display: flex;
      align-items: center;
      gap: 8px;
      flex-wrap: wrap;
      justify-content: flex-end;
    }

    .fpw-routegen__pill {
      border: 1px solid var(--rg-line);
      border-radius: 999px;
      padding: 6px 10px;
      background: rgba(0, 0, 0, 0.2);
      color: var(--rg-muted);
      font-family: var(--rg-mono);
      font-size: 12px;
      white-space: nowrap;
    }

    .fpw-routegen__pill--ok {
      border-color: rgba(52, 211, 153, 0.45);
      background: rgba(52, 211, 153, 0.12);
      color: rgba(167, 243, 208, 0.96);
    }

    .fpw-routegen__iconbtn {
      appearance: none;
      border: 1px solid var(--rg-line);
      background: rgba(255, 255, 255, 0.08);
      color: var(--rg-text);
      border-radius: 10px;
      width: 38px;
      height: 38px;
      display: grid;
      place-items: center;
      cursor: pointer;
      font-size: 18px;
      line-height: 1;
      padding: 0;
    }

    .fpw-routegen__iconbtn:hover {
      background: rgba(255, 255, 255, 0.14);
    }

    .fpw-routegen__error {
      margin: 10px 14px 0;
      border: 1px solid rgba(251, 113, 133, 0.5);
      border-radius: 12px;
      background: rgba(251, 113, 133, 0.13);
      color: #ffd4dc;
      padding: 8px 10px;
      font-size: 12px;
      line-height: 1.35;
    }

    .fpw-routegen__statusbar {
      padding: 8px 14px 0;
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 10px;
      font-size: 12px;
      color: var(--rg-muted);
    }

    .fpw-routegen__statusbar .fpw-routegen__pill {
      margin-left: auto;
    }

    .fpw-routegen__content {
      display: grid;
      grid-template-columns: 1fr 2fr;
      gap: 12px;
      padding: 12px;
      flex: 1;
      min-height: 0;
      height: 100%;
      overflow: hidden;
    }

    .fpw-routegen__panel {
      border: 1px solid var(--rg-line);
      border-radius: 16px;
      background: var(--rg-panel);
      overflow: hidden;
      min-height: 0;
      height: 100%;
      display: flex;
      flex-direction: column;
    }

    .fpw-routegen__panelhdr {
      display: flex;
      justify-content: space-between;
      align-items: center;
      gap: 10px;
      padding: 12px;
      border-bottom: 1px solid var(--rg-line);
      background: rgba(0, 0, 0, 0.18);
    }

    .fpw-routegen__kicker {
      font-size: 11px;
      letter-spacing: 0.14em;
      text-transform: uppercase;
      color: var(--rg-muted);
      font-weight: 900;
      margin-bottom: 4px;
    }

    .fpw-routegen__paneltitle {
      font-size: 14px;
      font-weight: 900;
    }

    .fpw-routegen__panelbody {
      padding: 12px;
      overflow-x: hidden;
      overflow-y: auto;
      min-height: 0;
      flex: 1 1 auto;
      display: flex;
      flex-direction: column;
    }

    #routeGenSetupPanelBody {
      display: block;
      overflow-x: hidden;
      overflow-y: auto;
    }

    .fpw-routegen__section {
      border: 1px solid var(--rg-line);
      border-radius: 14px;
      background: rgba(0, 0, 0, 0.16);
      padding: 10px;
      margin-bottom: 10px;
    }

    .fpw-routegen__labelrow {
      display: flex;
      justify-content: space-between;
      align-items: center;
      gap: 8px;
      margin-bottom: 8px;
    }

    .fpw-routegen__label {
      font-size: 11px;
      letter-spacing: 0.12em;
      text-transform: uppercase;
      color: var(--rg-subtle);
      font-weight: 900;
    }

    .fpw-routegen__help {
      font-size: 12px;
      color: var(--rg-muted);
      line-height: 1.3;
    }

    .fpw-routegen__chiprow {
      display: flex;
      flex-wrap: wrap;
      gap: 8px;
    }

    .fpw-routegen__chip {
      appearance: none;
      border: 1px solid var(--rg-line);
      background: rgba(0, 0, 0, 0.16);
      color: var(--rg-muted);
      border-radius: 999px;
      padding: 8px 10px;
      font-size: 12px;
      font-weight: 900;
      letter-spacing: 0.04em;
      text-transform: uppercase;
      cursor: pointer;
    }

    .fpw-routegen__chip.is-active {
      color: var(--rg-text);
      border-color: rgba(45, 212, 191, 0.48);
      background: rgba(45, 212, 191, 0.12);
      box-shadow: inset 0 0 0 3px rgba(45, 212, 191, 0.1);
    }

    .fpw-routegen__chip[disabled] {
      opacity: 0.5;
      cursor: not-allowed;
    }

    .fpw-routegen__grid2 {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 10px;
    }

    .fpw-routegen__field {
      border: 1px solid rgba(255, 255, 255, 0.12);
      border-radius: 12px;
      background: rgba(255, 255, 255, 0.04);
      padding: 8px;
    }

    .fpw-routegen__field label {
      display: block;
      margin-bottom: 6px;
      font-size: 11px;
      letter-spacing: 0.1em;
      text-transform: uppercase;
      color: var(--rg-subtle);
      font-weight: 900;
    }

    .fpw-routegen__fuelmeta {
      margin-top: 8px;
      padding-top: 8px;
      border-top: 1px solid rgba(255, 255, 255, 0.08);
    }

    .fpw-routegen__fuelmetatitle {
      display: block;
      margin-bottom: 6px;
      font-size: 10px;
      letter-spacing: 0.08em;
      text-transform: uppercase;
      color: var(--rg-subtle);
      font-weight: 900;
    }

    .fpw-routegen__fuelderived {
      margin-top: 6px;
      font-size: 12px;
      color: var(--rg-muted);
      line-height: 1.35;
    }

    .fpw-routegen .form-select,
    .fpw-routegen .form-control {
      background: rgba(0, 0, 0, 0.2);
      border: 1px solid rgba(255, 255, 255, 0.16);
      color: var(--rg-text);
      font-size: 13px;
      border-radius: 10px;
      min-height: 36px;
      padding-top: 6px;
      padding-bottom: 6px;
    }

    .fpw-routegen .form-select:focus,
    .fpw-routegen .form-control:focus {
      border-color: rgba(45, 212, 191, 0.65);
      box-shadow: 0 0 0 0.16rem rgba(45, 212, 191, 0.22);
      background: rgba(0, 0, 0, 0.28);
      color: var(--rg-text);
    }

    .fpw-routegen .form-select option {
      color: #0b1220;
    }

    .fpw-routegen__switchrow {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 10px;
    }

    .fpw-routegen__switchstate {
      font-size: 12px;
      color: var(--rg-muted);
      line-height: 1.3;
    }

    .fpw-routegen .form-check.form-switch.fpw-routegen__switch {
      margin: 0;
      min-height: 0;
      padding-left: 2.8em;
      display: inline-flex;
      align-items: center;
      gap: 8px;
    }

    .fpw-routegen .fpw-routegen__switch .form-check-input {
      margin-top: 0;
      margin-left: -2.8em;
      width: 2.25em;
      height: 1.2em;
      border-color: rgba(255, 255, 255, 0.3);
      background-color: rgba(255, 255, 255, 0.18);
      cursor: pointer;
    }

    .fpw-routegen .fpw-routegen__switch .form-check-input:checked {
      background-color: rgba(45, 212, 191, 0.9);
      border-color: rgba(45, 212, 191, 1);
    }

    .fpw-routegen .fpw-routegen__switch .form-check-label {
      font-size: 12px;
      color: var(--rg-text);
      cursor: pointer;
      user-select: none;
    }

    .fpw-routegen__pace {
      border: 1px solid rgba(255, 255, 255, 0.12);
      border-radius: 14px;
      background: rgba(0, 0, 0, 0.16);
      padding: 10px;
      margin-top: 10px;
    }

    .fpw-routegen__pacehead {
      display: flex;
      justify-content: space-between;
      align-items: flex-start;
      gap: 10px;
      margin-bottom: 8px;
    }

    .fpw-routegen__pacetitle {
      font-weight: 900;
      font-size: 14px;
    }

    .fpw-routegen__pacedesc {
      margin-top: 3px;
      font-size: 12px;
      color: var(--rg-muted);
      line-height: 1.35;
    }

    .fpw-routegen__pacechip {
      border: 1px solid rgba(45, 212, 191, 0.45);
      background: rgba(45, 212, 191, 0.12);
      color: rgba(167, 243, 208, 0.98);
      border-radius: 999px;
      padding: 6px 10px;
      font-size: 12px;
      font-family: var(--rg-mono);
      white-space: nowrap;
    }

    .fpw-routegen__range {
      width: 100%;
      accent-color: var(--rg-brand);
    }

    .fpw-routegen__rangeticks {
      display: flex;
      justify-content: space-between;
      margin-top: 6px;
      font-size: 11px;
      color: var(--rg-muted);
      font-weight: 800;
    }

    .fpw-routegen__pacehint {
      margin-top: 8px;
      font-size: 12px;
      color: #fcd34d;
      line-height: 1.35;
    }

    .fpw-routegen__pacebtn {
      margin-top: 8px;
    }

    .fpw-routegen__drawer {
      border: 1px solid var(--rg-line);
      border-radius: 14px;
      background: rgba(0, 0, 0, 0.15);
      overflow: hidden;
    }

    .fpw-routegen__drawer > summary {
      cursor: pointer;
      list-style: none;
      padding: 10px;
      background: rgba(0, 0, 0, 0.14);
      border-bottom: 1px solid rgba(255, 255, 255, 0.08);
      display: flex;
      justify-content: space-between;
      align-items: center;
      gap: 10px;
      font-weight: 900;
      font-size: 13px;
    }

    .fpw-routegen__drawer > summary::-webkit-details-marker {
      display: none;
    }

    .fpw-routegen__drawersub {
      margin-top: 2px;
      font-size: 12px;
      color: var(--rg-muted);
      font-weight: 700;
    }

    .fpw-routegen__drawerbody {
      padding: 10px;
    }

    .fpw-routegen__stops {
      margin-top: 8px;
      display: grid;
      gap: 8px;
    }

    .fpw-routegen__stop {
      border: 1px solid var(--rg-line);
      border-radius: 12px;
      background: rgba(0, 0, 0, 0.18);
      display: flex;
      gap: 10px;
      justify-content: space-between;
      align-items: center;
      padding: 9px 10px;
    }

    .fpw-routegen__stopinfo {
      min-width: 0;
    }

    .fpw-routegen__stopname {
      font-size: 13px;
      font-weight: 900;
      line-height: 1.3;
    }

    .fpw-routegen__stopdesc {
      margin-top: 3px;
      font-size: 12px;
      color: var(--rg-muted);
      line-height: 1.3;
    }

    .fpw-routegen__stoptoggle {
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

    .fpw-routegen__stoptoggle.is-on {
      border-color: rgba(45, 212, 191, 0.48);
      background: rgba(45, 212, 191, 0.14);
      color: rgba(167, 243, 208, 0.98);
    }

    .fpw-routegen__inlineactions {
      display: flex;
      align-items: center;
      gap: 8px;
    }

    .fpw-routegen__inlineactions .form-control,
    .fpw-routegen__inlineactions .form-select {
      flex: 1 1 auto;
      min-width: 0;
    }

    .fpw-routegen__myroutelegs {
      margin-top: 8px;
      border: 1px solid var(--rg-line);
      border-radius: 12px;
      background: rgba(0, 0, 0, 0.16);
      max-height: 210px;
      overflow: auto;
      display: grid;
      gap: 6px;
      padding: 8px;
    }

    .fpw-routegen__myrouteleg {
      border: 1px solid var(--rg-line);
      border-radius: 10px;
      background: rgba(0, 0, 0, 0.2);
      padding: 8px;
      display: grid;
      grid-template-columns: 1fr auto;
      gap: 8px;
      align-items: center;
    }

    .fpw-routegen__myroutelegname {
      font-size: 13px;
      font-weight: 800;
      line-height: 1.25;
    }

    .fpw-routegen__myroutelegmeta {
      margin-top: 2px;
      font-size: 12px;
      color: var(--rg-muted);
      font-family: var(--rg-mono);
    }

    .fpw-routegen__myroutelegactions {
      display: flex;
      align-items: center;
      gap: 6px;
      flex-wrap: wrap;
      justify-content: flex-end;
    }

    .fpw-routegen__metrics {
      display: grid;
      grid-template-columns: repeat(6, minmax(0, 1fr));
      gap: 8px;
    }

    .fpw-routegen__metric {
      border: 1px solid var(--rg-line);
      border-radius: 14px;
      background: rgba(0, 0, 0, 0.16);
      padding: 10px;
      min-height: 90px;
      display: flex;
      flex-direction: column;
      justify-content: space-between;
    }

    .fpw-routegen__metriclabel {
      font-size: 10px;
      letter-spacing: 0.12em;
      text-transform: uppercase;
      color: var(--rg-subtle);
      font-weight: 900;
    }

    .fpw-routegen__metricvalue {
      font-family: var(--rg-mono);
      font-size: 22px;
      font-weight: 900;
      line-height: 1.2;
      margin-top: 4px;
    }

    .fpw-routegen__metricvalue small {
      font-size: 12px;
      color: var(--rg-muted);
      font-family: var(--rg-sans);
    }

    .fpw-routegen__metricsub {
      font-size: 12px;
      color: var(--rg-muted);
      line-height: 1.3;
    }

    .fpw-routegen__listlayout {
      margin-top: 10px;
      min-height: 0;
      display: flex;
      flex-direction: column;
      flex: 1 1 auto;
    }

    .fpw-routegen__listbox {
      border: 1px solid var(--rg-line);
      border-radius: 14px;
      background: rgba(0, 0, 0, 0.16);
      overflow: hidden;
      min-height: 0;
      height: 100%;
      flex: 1 1 auto;
      display: flex;
      flex-direction: column;
    }

    .fpw-routegen__listhdr {
      padding: 10px;
      border-bottom: 1px solid var(--rg-line);
      background: rgba(0, 0, 0, 0.18);
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 10px;
    }

    .fpw-routegen__tiny {
      font-family: var(--rg-mono);
      font-size: 12px;
      color: var(--rg-muted);
    }

    .fpw-routegen__legcols {
      padding: 8px 9px;
      border-bottom: 1px solid var(--rg-line);
      background: rgba(255, 255, 255, 0.03);
      display: grid;
      grid-template-columns: 32px minmax(0, 1fr) 62px 78px 110px;
      gap: 10px;
      align-items: center;
    }

    .fpw-routegen__legcols span {
      font-size: 10px;
      letter-spacing: 0.09em;
      text-transform: uppercase;
      color: var(--rg-subtle);
      font-weight: 900;
      line-height: 1;
    }

    .fpw-routegen__legcols span:first-child {
      text-align: center;
    }

    .fpw-routegen__legcols span:nth-child(3),
    .fpw-routegen__legcols span:nth-child(4),
    .fpw-routegen__legcols span:nth-child(5) {
      text-align: right;
    }

    .fpw-routegen__leglist {
      overflow: auto;
      min-height: 0;
      max-height: none;
      padding: 6px;
      flex: 1 1 auto;
    }

    .fpw-routegen__legwrap {
      display: block;
      margin-bottom: 4px;
    }

    .fpw-routegen__leg {
      display: grid;
      grid-template-columns: 32px minmax(0, 1fr) 62px 78px 110px;
      gap: 10px;
      align-items: center;
      padding: 9px;
      border-radius: 10px;
      border: 1px solid transparent;
      cursor: pointer;
      transition: background 0.18s ease, border-color 0.18s ease;
    }

    .fpw-routegen__leg:hover {
      background: rgba(255, 255, 255, 0.04);
      border-color: rgba(255, 255, 255, 0.08);
    }

    .fpw-routegen__leg.is-selected {
      background: rgba(45, 212, 191, 0.12);
      border-color: rgba(45, 212, 191, 0.45);
    }

    .fpw-routegen__leg.is-expanded {
      border-color: rgba(45, 212, 191, 0.55);
      box-shadow: inset 0 0 0 1px rgba(45, 212, 191, 0.15);
    }

    .fpw-routegen__legidx {
      text-align: center;
      color: var(--rg-muted);
      font-family: var(--rg-mono);
      font-size: 12px;
      font-weight: 800;
    }

    .fpw-routegen__legroute {
      min-width: 0;
    }

    .fpw-routegen__legname {
      font-size: 13px;
      font-weight: 900;
      line-height: 1.3;
      overflow-wrap: anywhere;
    }

    .fpw-routegen__leglocks {
      font-family: var(--rg-mono);
      font-size: 12px;
      color: var(--rg-muted);
      white-space: nowrap;
      text-align: right;
    }

    .fpw-routegen__legnm {
      font-family: var(--rg-mono);
      font-size: 12px;
      color: var(--rg-muted);
      white-space: nowrap;
      text-align: right;
    }

    .fpw-routegen__legmapaction {
      display: flex;
      justify-content: flex-end;
      min-width: 0;
    }

    .fpw-routegen__legmapbtn {
      min-width: 102px;
      font-size: 11px;
      white-space: nowrap;
      padding: 5px 8px;
      line-height: 1.2;
    }

    .fpw-routegen__leglockpanel {
      margin: 6px 2px 0 40px;
      border: 1px solid rgba(45, 212, 191, 0.22);
      border-radius: 12px;
      background: rgba(7, 16, 29, 0.92);
      padding: 10px;
      animation: fpwRouteGenLegSlideDown 0.18s ease;
    }

    @keyframes fpwRouteGenLegSlideDown {
      from {
        opacity: 0;
        transform: translateY(-6px);
      }
      to {
        opacity: 1;
        transform: translateY(0);
      }
    }

    .fpw-routegen__leglockhead {
      display: flex;
      justify-content: space-between;
      gap: 10px;
      align-items: center;
      margin-bottom: 8px;
    }

    .fpw-routegen__leglockheadactions {
      display: flex;
      gap: 8px;
      flex-wrap: wrap;
      justify-content: flex-end;
    }

    .fpw-routegen__leglockinlineactions {
      margin-top: 8px;
      display: flex;
      justify-content: flex-end;
    }

    .fpw-routegen__lockstate {
      border: 1px dashed rgba(255, 255, 255, 0.2);
      border-radius: 10px;
      padding: 8px 10px;
      color: var(--rg-muted);
      font-size: 12px;
      line-height: 1.35;
    }

    .fpw-routegen__lockstate--error {
      border-color: rgba(248, 113, 113, 0.45);
      color: #fecaca;
      background: rgba(127, 29, 29, 0.2);
    }

    .fpw-routegen__locksummary {
      display: grid;
      grid-template-columns: repeat(4, minmax(0, 1fr));
      gap: 8px;
      margin-bottom: 8px;
    }

    .fpw-routegen__lockchip {
      border: 1px solid rgba(255, 255, 255, 0.12);
      border-radius: 10px;
      background: rgba(255, 255, 255, 0.03);
      padding: 8px;
      display: flex;
      flex-direction: column;
      gap: 3px;
    }

    .fpw-routegen__lockchip span {
      font-size: 10px;
      letter-spacing: 0.08em;
      text-transform: uppercase;
      color: var(--rg-subtle);
      font-weight: 900;
      line-height: 1;
    }

    .fpw-routegen__lockchip strong {
      font-family: var(--rg-mono);
      font-size: 13px;
      color: var(--rg-text);
    }

    .fpw-routegen__locklist {
      display: grid;
      gap: 8px;
      max-height: 320px;
      overflow: auto;
      padding-right: 2px;
    }

    .fpw-routegen__lockitem {
      border: 1px solid rgba(255, 255, 255, 0.1);
      border-radius: 10px;
      background: rgba(255, 255, 255, 0.03);
      padding: 8px;
      display: grid;
      gap: 6px;
    }

    .fpw-routegen__lockitemhead {
      display: flex;
      justify-content: space-between;
      gap: 8px;
      align-items: center;
    }

    .fpw-routegen__lockitemtitle {
      font-size: 13px;
      font-weight: 900;
      line-height: 1.3;
    }

    .fpw-routegen__lockitemcode {
      font-family: var(--rg-mono);
      font-size: 11px;
      color: var(--rg-muted);
      white-space: nowrap;
    }

    .fpw-routegen__lockitemmeta {
      display: grid;
      grid-template-columns: repeat(2, minmax(0, 1fr));
      gap: 4px 12px;
      font-size: 12px;
      color: var(--rg-muted);
      line-height: 1.3;
    }

    .fpw-routegen__flag {
      margin-left: 8px;
      border: 1px solid rgba(245, 158, 11, 0.38);
      background: rgba(245, 158, 11, 0.14);
      color: #fde68a;
      border-radius: 999px;
      font-size: 10px;
      letter-spacing: 0.05em;
      text-transform: uppercase;
      font-weight: 900;
      padding: 3px 6px;
      vertical-align: middle;
    }

    .fpw-routegen__flag--override {
      border-color: rgba(45, 212, 191, 0.46);
      background: rgba(45, 212, 191, 0.16);
      color: #99f6e4;
    }

    .fpw-routegen__legpanel {
      margin: 0;
      border: 1px solid var(--rg-line);
      border-radius: 14px;
      background: rgba(8, 14, 24, 0.94);
      padding: 10px;
      height: 100%;
      opacity: 0;
      transform: translateY(20px) scale(0.98);
      pointer-events: none;
      display: flex;
      flex-direction: column;
      transition:
        transform 0.24s ease,
        opacity 0.2s ease,
        box-shadow 0.2s ease;
    }

    .fpw-routegen__legpanel.is-open {
      opacity: 1;
      transform: translateY(0) scale(1);
      pointer-events: auto;
      box-shadow: 0 18px 42px rgba(0, 0, 0, 0.45);
    }

    .fpw-routegen__legpanelhead {
      display: flex;
      align-items: flex-start;
      justify-content: space-between;
      gap: 10px;
      margin-bottom: 8px;
    }

    .fpw-routegen__legclose {
      border: 1px solid rgba(255, 255, 255, 0.16);
      border-radius: 10px;
      background: rgba(255, 255, 255, 0.06);
      color: var(--rg-text);
      width: 34px;
      height: 34px;
      line-height: 1;
      font-size: 20px;
      display: inline-flex;
      align-items: center;
      justify-content: center;
      cursor: pointer;
      flex: 0 0 auto;
    }

    .fpw-routegen__legclose:hover {
      background: rgba(255, 255, 255, 0.12);
    }

    .fpw-routegen__legpanelmeta {
      display: flex;
      align-items: center;
      gap: 8px;
      margin-bottom: 8px;
      font-size: 12px;
      color: var(--rg-muted);
    }

    .fpw-routegen__legpanelmeta strong {
      color: var(--rg-text);
      font-family: var(--rg-mono);
    }

    .fpw-routegen__legsearch {
      display: grid;
      grid-template-columns: minmax(0, 1fr) auto auto;
      gap: 8px;
      margin-bottom: 8px;
      align-items: center;
    }

    .fpw-routegen__legsearch .form-control {
      min-width: 0;
    }

    .fpw-routegen__legmapstatus {
      font-size: 12px;
      color: var(--rg-muted);
      margin-bottom: 8px;
      min-height: 18px;
    }

    .fpw-routegen__legmap {
      height: auto;
      min-height: 300px;
      border-radius: 12px;
      border: 1px solid var(--rg-line);
      overflow: hidden;
      background: rgba(0, 0, 0, 0.2);
      margin-bottom: 8px;
      flex: 1 1 auto;
    }

    .fpw-routegen__legmapdock {
      display: none;
    }

    .fpw-routegen__legoverlay {
      position: fixed;
      inset: 0;
      z-index: 2100;
      background: rgba(3, 8, 15, 0.78);
      opacity: 0;
      visibility: hidden;
      pointer-events: none;
      transition: opacity 0.2s ease, visibility 0.2s ease;
    }

    .fpw-routegen__legoverlay.is-open {
      opacity: 1;
      visibility: visible;
      pointer-events: auto;
    }

    body.fpw-routegen--overlay-open {
      overflow: hidden;
    }

    .fpw-routegen__legoverlaydock {
      position: absolute;
      inset: 18px;
      min-height: 0;
    }

    .fpw-routegen__legpanelactions {
      display: flex;
      gap: 8px;
      flex-wrap: wrap;
      justify-content: flex-end;
    }

    .fpw-routegen__empty {
      border: 1px dashed var(--rg-line);
      border-radius: 10px;
      padding: 12px;
      color: var(--rg-muted);
      font-style: italic;
      font-size: 13px;
    }

    .fpw-routegen__bottombar {
      padding: 10px 12px;
      border-top: 1px solid var(--rg-line);
      background: rgba(0, 0, 0, 0.3);
      display: flex;
      justify-content: space-between;
      align-items: center;
      gap: 10px;
      flex-wrap: wrap;
    }

    .fpw-routegen__hintline {
      font-size: 12px;
      color: var(--rg-muted);
      line-height: 1.35;
    }

    .fpw-routegen__actions {
      display: flex;
      gap: 8px;
      align-items: center;
      flex-wrap: wrap;
    }

    .fpw-routegen__actions .btn-primary,
    .fpw-routegen__actions .btn-secondary {
      min-width: 120px;
    }

    .fpw-routegen__actions .btn-primary[disabled],
    .fpw-routegen__actions .btn-secondary[disabled] {
      opacity: 0.7;
      cursor: not-allowed;
    }

    @media (max-width: 1200px) {
      .fpw-routegen__metrics {
        grid-template-columns: repeat(3, minmax(0, 1fr));
      }
    }

    @media (max-width: 900px) {
      .fpw-routegen__metrics {
        grid-template-columns: repeat(2, minmax(0, 1fr));
      }
    }

    @media (max-width: 1040px) {
      .fpw-routegen__content {
        grid-template-columns: 1fr;
      }

      .fpw-routegen__grid2 {
        grid-template-columns: 1fr;
      }
    }

    @media (max-width: 680px) {
      .fpw-routegen__topbar {
        flex-direction: column;
        align-items: flex-start;
      }

      .fpw-routegen__topactions {
        width: 100%;
        justify-content: flex-start;
      }

      .fpw-routegen__metrics {
        grid-template-columns: 1fr;
      }

      .fpw-routegen__actions {
        width: 100%;
      }

      .fpw-routegen__actions .btn-primary,
      .fpw-routegen__actions .btn-secondary {
        flex: 1 1 auto;
      }

      .fpw-routegen__legpanelactions {
        justify-content: stretch;
      }

      .fpw-routegen__legpanelactions .btn-primary,
      .fpw-routegen__legpanelactions .btn-secondary {
        flex: 1 1 auto;
      }

      .fpw-routegen__legcols,
      .fpw-routegen__leg {
        grid-template-columns: 26px minmax(0, 1fr) 52px 66px 90px;
        gap: 6px;
      }

      .fpw-routegen__legcols {
        padding: 8px 8px;
      }

      .fpw-routegen__leg {
        padding: 8px;
      }

      .fpw-routegen__legmapbtn {
        min-width: 84px;
        padding: 4px 6px;
      }

      .fpw-routegen__legmap {
        min-height: 260px;
      }

      .fpw-routegen__legoverlaydock {
        inset: 8px;
      }

      .fpw-routegen__legsearch {
        grid-template-columns: 1fr;
      }

      .fpw-routegen__leglockpanel {
        margin-left: 0;
      }

      .fpw-routegen__locksummary {
        grid-template-columns: 1fr 1fr;
      }

      .fpw-routegen__lockitemmeta {
        grid-template-columns: 1fr;
      }
    }
  </style>

  <div class="fpw-routegen__frame">
    <div class="fpw-routegen__topbar">
      <div class="fpw-routegen__titlewrap">
        <h1 class="fpw-routegen__title">FPW Route Generator</h1>
        <div class="fpw-routegen__subtitle">Simple mode plus advanced controls. Preview before generating your route.</div>
      </div>
      <div class="fpw-routegen__topactions">
        <button type="button" id="routeGenCloseBtn" class="fpw-routegen__iconbtn" aria-label="Close">&times;</button>
      </div>
    </div>

    <div id="routeGenError" class="fpw-routegen__error d-none" role="alert"></div>
    <div class="fpw-routegen__statusbar">
      <span id="routeGenStatus">Ready</span>
      <span id="routeGenRouteCode" class="fpw-routegen__pill">Draft</span>
    </div>

    <div class="fpw-routegen__content">
      <section class="fpw-routegen__panel">
        <div class="fpw-routegen__panelhdr">
          <div>
            <div class="fpw-routegen__kicker">Setup</div>
            <div class="fpw-routegen__paneltitle">Start -> End -> Pace</div>
          </div>
        </div>

        <div id="routeGenSetupPanelBody" class="fpw-routegen__panelbody">
          <div class="fpw-routegen__section">
            <div class="fpw-routegen__labelrow">
              <span class="fpw-routegen__label">Template</span>
              <span class="fpw-routegen__help">Templates are loaded from your FPW route library.</span>
            </div>
            <div class="fpw-routegen__field">
              <label for="routeGenTemplateSelect">Route template</label>
              <select id="routeGenTemplateSelect" class="form-select form-select-sm" aria-label="Template selection"></select>
              <div id="routeGenTemplateMeta" class="fpw-routegen__help mt-2"></div>
            </div>
          </div>

          <div class="fpw-routegen__section">
            <div class="fpw-routegen__labelrow">
              <span class="fpw-routegen__label">My Routes</span>
              <span class="fpw-routegen__help">Create waypoint-driven custom routes, then load and edit geometry.</span>
            </div>
            <div class="fpw-routegen__grid2">
              <div class="fpw-routegen__field">
                <label for="routeGenMyRouteName">Create route</label>
                <div class="fpw-routegen__inlineactions">
                  <input id="routeGenMyRouteName" type="text" class="form-control form-control-sm" placeholder="Route name">
                  <button type="button" id="routeGenMyRouteCreateBtn" class="btn-secondary btn-sm">Create</button>
                </div>
              </div>
              <div class="fpw-routegen__field">
                <label for="routeGenMyRouteSelect">My routes</label>
                <div class="fpw-routegen__inlineactions">
                  <select id="routeGenMyRouteSelect" class="form-select form-select-sm">
                    <option value="">Select route</option>
                  </select>
                  <button type="button" id="routeGenMyRouteLoadBtn" class="btn-secondary btn-sm">Load</button>
                  <button type="button" id="routeGenMyRouteDeleteBtn" class="btn-secondary btn-sm">Delete</button>
                </div>
              </div>
            </div>
            <div class="fpw-routegen__grid2 mt-2">
              <div class="fpw-routegen__field">
                <label for="routeGenMyRouteStartWaypointSelect">Route start waypoint</label>
                <div class="fpw-routegen__inlineactions">
                  <select id="routeGenMyRouteStartWaypointSelect" class="form-select form-select-sm">
                    <option value="">Select start waypoint</option>
                  </select>
                  <button type="button" id="routeGenMyRouteSetStartBtn" class="btn-secondary btn-sm">Set Start</button>
                </div>
              </div>
              <div class="fpw-routegen__field">
                <label for="routeGenMyRouteEndWaypointSelect">Add leg by waypoint</label>
                <div class="fpw-routegen__inlineactions">
                  <select id="routeGenMyRouteEndWaypointSelect" class="form-select form-select-sm">
                    <option value="">Select end waypoint</option>
                  </select>
                  <button type="button" id="routeGenMyRouteAddWaypointLegBtn" class="btn-secondary btn-sm">Add Leg</button>
                </div>
              </div>
            </div>
            <div id="routeGenMyRouteStartMeta" class="fpw-routegen__help mt-2">Set a route start waypoint, then add legs by choosing each next waypoint.</div>
            <div class="fpw-routegen__field mt-2">
              <label for="routeGenMyRouteLegList">Leg sequence</label>
              <div class="fpw-routegen__inlineactions">
                <span class="fpw-routegen__help">Click Load to render this route in the right preview panel.</span>
              </div>
            </div>
            <div id="routeGenMyRouteLegList" class="fpw-routegen__myroutelegs">
              <div class="fpw-routegen__empty">Create or select a My Route to manage legs.</div>
            </div>
          </div>

          <div class="fpw-routegen__section">
            <div class="fpw-routegen__labelrow">
              <span class="fpw-routegen__label">Trip basics</span>
              <span class="fpw-routegen__help">Adjust any value and preview refreshes automatically.</span>
            </div>

            <div class="fpw-routegen__grid2">
              <div class="fpw-routegen__field">
                <label for="routeGenStartLocation">Start location</label>
                <select id="routeGenStartLocation" class="form-select form-select-sm"></select>
              </div>
              <div class="fpw-routegen__field">
                <label for="routeGenEndLocation">End location</label>
                <select id="routeGenEndLocation" class="form-select form-select-sm"></select>
              </div>
            </div>

            <div class="fpw-routegen__grid2 mt-2">
              <div class="fpw-routegen__field">
                <label for="routeGenStartDate">Start date</label>
                <input id="routeGenStartDate" type="date" class="form-control form-control-sm">
              </div>
              <div class="fpw-routegen__field">
                <label for="routeGenDirectionToggle">Direction</label>
                <div class="fpw-routegen__switchrow">
                  <div id="routeGenDirectionState" class="fpw-routegen__switchstate">Counterclockwise (CCW)</div>
                  <div class="form-check form-switch fpw-routegen__switch">
                    <input id="routeGenDirectionToggle" class="form-check-input" type="checkbox" role="switch" aria-label="Reverse direction">
                    <label class="form-check-label" for="routeGenDirectionToggle">Reverse</label>
                  </div>
                </div>
                <input id="routeGenDirection" type="hidden" value="CCW">
              </div>
            </div>

            <div class="fpw-routegen__pace">
              <div class="fpw-routegen__pacehead">
                <div>
                  <div class="fpw-routegen__pacetitle">Pace</div>
                  <div class="fpw-routegen__pacedesc">Pace applies 25%, 50%, or 100% of your max speed.</div>
                </div>
                <div id="routeGenPaceLabel" class="fpw-routegen__pacechip">Relaxed</div>
              </div>
              <input id="routeGenPace" class="fpw-routegen__range" type="range" min="0" max="2" step="1" value="0" aria-label="Pace">
              <div class="fpw-routegen__rangeticks"><span>Relaxed</span><span>Balanced</span><span>Aggressive</span></div>
              <div id="routeGenPaceOverrideHint" class="fpw-routegen__pacehint d-none">Pace uses a percentage of max speed.</div>
              <button type="button" id="routeGenResetPaceBtn" class="btn-secondary btn-sm fpw-routegen__pacebtn d-none">Reset Pace Defaults</button>
            </div>
          </div>

          <details id="routeGenAdvanced" class="fpw-routegen__drawer">
            <summary>
              <div>
                <div>Advanced settings</div>
                <div class="fpw-routegen__drawersub">Max speed, underway hours, comfort, overnight bias, optional stops</div>
              </div>
              <div class="fpw-routegen__pill">Optional</div>
            </summary>
            <div class="fpw-routegen__drawerbody">
            <div class="fpw-routegen__grid2">
              <div class="fpw-routegen__field">
                <label for="routeGenCruisingSpeed">Max speed (kn)</label>
                <input id="routeGenCruisingSpeed" type="number" step="0.1" min="1" max="60" class="form-control form-control-sm" value="20">
              </div>
                <div class="fpw-routegen__field">
                  <label for="routeGenUnderwayHoursPerDay">Underway hours / day</label>
                  <input id="routeGenUnderwayHoursPerDay" type="number" step="0.5" min="1" max="24" class="form-control form-control-sm" value="8">
                </div>
                <div class="fpw-routegen__field">
                  <label for="routeGenComfortProfile">Comfort profile</label>
                  <select id="routeGenComfortProfile" class="form-select form-select-sm">
                    <option value="PREFER_INSIDE">Prefer Inside</option>
                    <option value="BALANCED">Balanced</option>
                    <option value="OFFSHORE_OK">Offshore OK</option>
                  </select>
                </div>
                <div class="fpw-routegen__field">
                  <label for="routeGenOvernightBias">Overnight bias</label>
                  <select id="routeGenOvernightBias" class="form-select form-select-sm">
                    <option value="MARINAS">Marinas</option>
                    <option value="ANCHORAGES">Anchorages</option>
                    <option value="MIXED">Mixed</option>
                  </select>
                </div>
                <div class="fpw-routegen__field">
                  <label id="routeGenFuelBurnLabel" for="routeGenFuelBurnGph">Fuel burn at max speed (GPH)</label>
                  <input id="routeGenFuelBurnGph" type="number" step="0.1" min="0" class="form-control form-control-sm" value="">
                  <div class="fpw-routegen__fuelmeta">
                    <div id="routeGenFuelBurnHint" class="fpw-routegen__help mt-1">FPW derives pace and weather adjusted burn from max speed burn.</div>
                    <div id="routeGenFuelBurnDerived" class="fpw-routegen__fuelderived">Derived burn at current pace + weather: -- GPH</div>
                  </div>
                </div>
                <div class="fpw-routegen__field">
                  <label for="routeGenIdleBurnGph">Idle burn (GPH)</label>
                  <input id="routeGenIdleBurnGph" type="number" step="0.1" min="0" class="form-control form-control-sm" value="">
                </div>
                <div class="fpw-routegen__field">
                  <label for="routeGenIdleHoursTotal">Idle hours (total)</label>
                  <input id="routeGenIdleHoursTotal" type="number" step="0.1" min="0" class="form-control form-control-sm" value="">
                </div>
                <div class="fpw-routegen__field">
                  <label for="routeGenWeatherFactorPct">Weather factor (%)</label>
                  <input id="routeGenWeatherFactorPct" type="number" step="1" min="0" max="60" class="form-control form-control-sm" value="0">
                </div>
                <div class="fpw-routegen__field">
                  <label for="routeGenReservePct">Reserve (%)</label>
                  <input id="routeGenReservePct" type="number" step="1" min="0" max="100" class="form-control form-control-sm" value="20">
                </div>
                <div class="fpw-routegen__field">
                  <label for="routeGenFuelPricePerGal">Fuel price ($/gal)</label>
                  <input id="routeGenFuelPricePerGal" type="number" step="0.01" min="0" class="form-control form-control-sm" value="">
                </div>
              </div>

              <div class="fpw-routegen__labelrow mt-2">
                <span class="fpw-routegen__label">Optional stops</span>
                <span class="fpw-routegen__help">Toggle detours to include them in preview/generate.</span>
              </div>
              <div id="routeGenOptionalStops" class="fpw-routegen__stops">
                <div class="fpw-routegen__empty">No optional stops available for this template.</div>
              </div>
            </div>
          </details>
        </div>
      </section>

      <section class="fpw-routegen__panel">
        <div class="fpw-routegen__panelhdr">
          <div>
            <div class="fpw-routegen__kicker">Preview</div>
            <div class="fpw-routegen__paneltitle">Route Summary and Legs</div>
          </div>
          <span id="routeGenPreviewTemplate" class="fpw-routegen__pill">Template: -</span>
        </div>
        <div class="fpw-routegen__panelbody">
          <div class="fpw-routegen__metrics">
            <div class="fpw-routegen__metric">
              <div class="fpw-routegen__metriclabel">Total distance</div>
              <div id="routeGenTotalNm" class="fpw-routegen__metricvalue">0 <small>NM</small></div>
              <div class="fpw-routegen__metricsub">Based on selected legs</div>
            </div>
            <div class="fpw-routegen__metric">
              <div class="fpw-routegen__metriclabel">Estimated days</div>
              <div id="routeGenEstimatedDays" class="fpw-routegen__metricvalue">0</div>
              <div id="routeGenEstimatedDaysSub" class="fpw-routegen__metricsub">Pace-driven estimate</div>
            </div>
            <div class="fpw-routegen__metric">
              <div class="fpw-routegen__metriclabel">Estimated fuel</div>
              <div id="routeGenEstimatedFuel" class="fpw-routegen__metricvalue">-- <small>gal</small></div>
              <div id="routeGenEstimatedFuelSub" class="fpw-routegen__metricsub">Required = base + reserve</div>
            </div>
            <div class="fpw-routegen__metric">
              <div class="fpw-routegen__metriclabel">Fuel cost</div>
              <div id="routeGenFuelCost" class="fpw-routegen__metricvalue">-- <small>USD</small></div>
              <div id="routeGenFuelCostSub" class="fpw-routegen__metricsub">Required fuel x price</div>
            </div>
            <div class="fpw-routegen__metric">
              <div class="fpw-routegen__metriclabel">Locks</div>
              <div id="routeGenLockCount" class="fpw-routegen__metricvalue">0</div>
              <div class="fpw-routegen__metricsub">Total lock count</div>
            </div>
            <div class="fpw-routegen__metric">
              <div class="fpw-routegen__metriclabel">Offshore legs</div>
              <div id="routeGenOffshoreCount" class="fpw-routegen__metricvalue">0</div>
              <div class="fpw-routegen__metricsub">Includes optional stops</div>
            </div>
          </div>

          <div id="routeGenLegLayout" class="fpw-routegen__listlayout">
            <div class="fpw-routegen__listbox">
              <div class="fpw-routegen__listhdr">
                <div class="fpw-routegen__kicker">Route path preview</div>
                <div id="routeGenLegCount" class="fpw-routegen__tiny">0 legs</div>
              </div>
              <div class="fpw-routegen__legcols" aria-hidden="true">
                <span>#</span>
                <span>Leg</span>
                <span>Locks</span>
                <span>NM</span>
                <span>Geometry</span>
              </div>
              <div id="routeGenLegList" class="fpw-routegen__leglist">
                <div class="fpw-routegen__empty">Pick template/start/end to see a live preview.</div>
              </div>
            </div>
            <div id="routeGenLegMapDock" class="fpw-routegen__legmapdock">
              <div id="routeGenLegMapPanel" class="fpw-routegen__legpanel" aria-live="polite">
                <div class="fpw-routegen__legpanelhead">
                  <div>
                    <div class="fpw-routegen__kicker">Leg Geometry</div>
                    <div id="routeGenLegMapTitle" class="fpw-routegen__paneltitle">Select a leg to edit geometry</div>
                  </div>
                  <div class="d-flex align-items-start gap-2">
                    <div id="routeGenLegMapSource" class="fpw-routegen__tiny">Source: default</div>
                    <button type="button" id="routeGenLegOverlayCloseBtn" class="fpw-routegen__legclose" aria-label="Close map panel">&times;</button>
                  </div>
                </div>
                <div class="fpw-routegen__legpanelmeta">
                  <span>Computed NM:</span>
                  <strong id="routeGenLegMapNm">0.00</strong>
                  <span id="routeGenLegMapHint" class="fpw-routegen__tiny">Draw or edit polyline, then save override.</span>
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

    <div class="fpw-routegen__bottombar">
      <div id="routeGenHintLine" class="fpw-routegen__hintline">Recommended flow: Preview -> Generate Route -> Build Float Plans from dashboard.</div>
      <div class="fpw-routegen__actions">
        <button type="button" id="routeGenPreviewBtn" class="btn-secondary">Preview</button>
        <button type="button" id="routeGenResetBtn" class="btn-secondary">Reset</button>
        <button type="button" id="routeGenCancelBtn" class="btn-secondary">Close</button>
        <button type="button" id="routeGenSaveBtn" class="btn-primary d-none">Save Route</button>
        <button type="button" id="routeGenGenerateBtn" class="btn-primary">Generate Route</button>
      </div>
    </div>
  </div>
</div>
