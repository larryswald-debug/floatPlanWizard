<!DOCTYPE html>
<!-- Updated to host the float plan wizard inside a Bootstrap modal. -->
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Dashboard - Float Plan Wizard</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">

    <cfinclude template="../includes/header_styles.cfm">
    <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" integrity="sha256-p4NxAoJBhIIN+hmNHrzRCf9tD/miZyoHS5obTRR9BMY=" crossorigin="">
    <link rel="stylesheet" href="<cfoutput>#request.fpwBase#</cfoutput>/assets/css/dashboard-console.css?v=1">

    <style>
        .wizard-body {
            background: #f4f6f8;
            min-height: 100%;
            color: #212529;
        }

        .wizard-container {
            max-width: 820px;
            margin: 1.5rem auto;
            background: #fff;
            border-radius: 16px;
            box-shadow: 0 8px 20px rgba(0,0,0,0.08);
            padding: 1.5rem;
        }

        .wizard-steps .badge {
            font-size: 0.85rem;
            padding: 0.35rem 0.6rem;
            margin-right: 0.35rem;
        }

        .list-group-button {
            display: flex;
            justify-content: space-between;
            align-items: center;
        }

        .wizard-nav {
            display: flex;
            justify-content: space-between;
            margin-top: 1.25rem;
        }

        .wizard-alert {
            margin-bottom: 1rem;
        }

        .wizard-alert.alert-success {
            padding-top: 0.375rem;
            padding-bottom: 0.375rem;
        }

        .wizard-alert.alert-danger {
            padding-top: 0.375rem;
            padding-bottom: 0.375rem;
        }

        @media (max-width: 768px) {
            .wizard-container {
                margin: 1rem;
                padding: 1rem;
            }
        }

        #waypointMap {
            position: relative;
            z-index: 1;
        }

        #waypointMap .radar-opacity-control {
            background: rgba(255, 255, 255, 0.92);
            padding: 0.35rem 0.5rem;
            border-radius: 0.5rem;
            box-shadow: 0 4px 12px rgba(0,0,0,0.15);
            font-size: 0.7rem;
            min-width: 140px;
        }

        #waypointMap .radar-opacity-control label {
            display: block;
            font-weight: 600;
            margin-bottom: 0.25rem;
            color: #1b1b1b;
        }

        #waypointMap .radar-opacity-control input[type="range"] {
            width: 100%;
        }

        #waypointMap .radar-opacity-control.is-disabled {
            opacity: 0.5;
            pointer-events: none;
        }

        #waypointMap .marine-poi-icon span {
            display: inline-flex;
            align-items: center;
            justify-content: center;
            width: 22px;
            height: 22px;
            border-radius: 50%;
            border: 2px solid #fff;
            color: #fff;
            font-size: 10px;
            font-weight: 600;
            box-shadow: 0 1px 4px rgba(0,0,0,0.35);
        }

        .marine-controls {
            position: relative;
            z-index: 2;
            pointer-events: auto;
        }

        .dashboard-body .btn-close {
            background-color: transparent;
            filter: none;
            opacity: 1;
            background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='16' height='16' fill='white' viewBox='0 0 16 16'%3E%3Cpath d='M1.5 1.5l13 13m0-13l-13 13' stroke='white' stroke-width='2'/%3E%3C/svg%3E");
            background-repeat: no-repeat;
            background-position: center;
            background-size: 14px 14px;
        }

        .dashboard-body .btn-close:hover {
            background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='16' height='16' fill='none' viewBox='0 0 16 16'%3E%3Cpath d='M1.5 1.5l13 13m0-13l-13 13' stroke='%2335d0c6' stroke-width='2'/%3E%3C/svg%3E");
            background-repeat: no-repeat;
            background-position: center;
            background-size: 14px 14px;
        }

        main.dashboard-main {
            max-width: 1120px;
            margin: 0 auto;
            padding: 0.5rem 20px 1.5rem;
        }

        .dashboard-header {
            padding: 0;
            border: 0;
            box-shadow: none;
            background: transparent;
        }

        .dashboard-header .header-grid {
            max-width: 1120px;
            margin: 0 auto;
            padding: 0;
        }
    
        /* ================================
           Weather Cockpit (WOW Panel)
           ================================ */
        .fpw-weather-cockpit{
            background: radial-gradient(1200px 600px at 20% 0%, rgba(45,212,191,.18), transparent 55%),
                        radial-gradient(900px 500px at 85% 15%, rgba(59,130,246,.14), transparent 60%),
                        linear-gradient(180deg, #0b1220, #070d18);
            border: 1px solid rgba(255,255,255,.08);
            border-radius: 16px;
            padding: 16px 16px 14px;
        }

        .fpw-wx__top{
            display:flex;
            gap:14px;
            justify-content:space-between;
            align-items:flex-start;
            margin-bottom:14px;
        }
        .fpw-wx__titleRow{
            display:flex;
            align-items:center;
            gap:10px;
            flex-wrap:wrap;
        }
        .fpw-wx__dot{
            width:12px;height:12px;border-radius:50%;
            box-shadow: 0 0 0 3px rgba(255,255,255,.06);
        }
        .fpw-wx__dot.ok{ background:#2dd4bf; }
        .fpw-wx__dot.warn{ background:#facc15; }
        .fpw-wx__dot.danger{ background:#ef4444; }
        .fpw-wx__title{
            font-size: 1rem;
            margin:0;
            font-weight:700;
            letter-spacing:.2px;
            color: rgba(255,255,255,.92);
        }
        .fpw-wx__badge{
            font-size:.75rem;
            font-weight:700;
            padding:.22rem .55rem;
            border-radius:999px;
            background: rgba(59,130,246,.18);
            border:1px solid rgba(59,130,246,.25);
            color: rgba(255,255,255,.9);
        }
        .fpw-wx__pill{
            font-size:.75rem;
            padding:.18rem .5rem;
            border-radius:999px;
            background: rgba(255,255,255,.08);
            border:1px solid rgba(255,255,255,.10);
            color: rgba(255,255,255,.78);
        }
        .fpw-wx__summary{
            margin-top:6px;
            color: rgba(255,255,255,.75);
            font-size:.9rem;
            line-height:1.25rem;
            max-width: 840px;
        }
        .fpw-wx__muted{ color: rgba(255,255,255,.65); }
        .fpw-wx__topRight{
            display:flex;
            gap:10px;
            align-items:flex-end;
            flex-wrap:wrap;
            justify-content:flex-end;
        }
        .fpw-wx__zipInput{
            width:110px;
            background: rgba(255,255,255,.08);
            border:1px solid rgba(255,255,255,.12);
            color: rgba(255,255,255,.92);
        }
        .fpw-wx__zipInput::placeholder{ color: rgba(255,255,255,.55); }
        .fpw-wx__zipLabel{ font-size:.75rem; color: rgba(255,255,255,.70); margin:0 0 4px; display:block; }
        .fpw-wx__updateBtn{ box-shadow: 0 10px 18px rgba(0,0,0,.22); }
        .fpw-wx__detailsBtn{ opacity:.9; }

        .fpw-wx__main{
            display:grid;
            grid-template-columns: 300px 1fr;
            gap: 14px;
        }
        @media (max-width: 992px){
            .fpw-wx__main{ grid-template-columns: 1fr; }
        }

        .fpw-wx__panel{
            background: rgba(255,255,255,.05);
            border:1px solid rgba(255,255,255,.08);
            border-radius: 14px;
            padding: 12px;
            box-shadow: 0 10px 20px rgba(0,0,0,.18);
        }
        .fpw-wx__panelHeader{
            display:flex;
            justify-content:space-between;
            align-items:center;
            margin-bottom:10px;
        }
        .fpw-wx__panelTitle{
            font-weight:800;
            font-size:.9rem;
            letter-spacing:.25px;
            color: rgba(255,255,255,.88);
        }
        .fpw-wx__panelMeta{
            font-size:.78rem;
            color: rgba(255,255,255,.65);
        }

        /* Wind dial */
        .fpw-wx__dial{ display:flex; justify-content:center; padding: 2px 0 8px; }
        .fpw-wx__compass{
            width: 248px;
            height: 248px;
            border-radius: 50%;
            position: relative;
            background:
                radial-gradient(circle at 50% 50%, rgba(255,255,255,.08), rgba(255,255,255,.02) 55%, rgba(0,0,0,.25) 100%),
                conic-gradient(from 180deg, rgba(45,212,191,.22), rgba(59,130,246,.12), rgba(239,68,68,.12), rgba(45,212,191,.22));
            border: 1px solid rgba(255,255,255,.10);
            box-shadow: inset 0 0 0 10px rgba(0,0,0,.16), 0 18px 30px rgba(0,0,0,.28);
            overflow:hidden;
        }
        .fpw-wx__compassTicks{
            position:absolute; inset:0;
            background:
                repeating-conic-gradient(
                  from 0deg,
                  rgba(255,255,255,.18) 0deg,
                  rgba(255,255,255,.18) 1deg,
                  transparent 1deg,
                  transparent 10deg
                );
            opacity:.25;
            mask: radial-gradient(circle at 50% 50%, transparent 0 64%, #000 66% 100%);
        }
        .fpw-wx__needle{
            position:absolute;
            left:50%;
            top: 22px;
            width: 2px;
            height: 96px;
            transform-origin: bottom center;
            transform: translateX(-50%) rotate(var(--dir));
            transition: transform 380ms cubic-bezier(.2,.9,.2,1);
            background: linear-gradient(#2dd4bf, rgba(45,212,191,.15));
            filter: drop-shadow(0 0 10px rgba(45,212,191,.35));
        }
        .fpw-wx__needle::after{
            content:"";
            position:absolute;
            bottom:-7px;
            left:50%;
            width: 10px;
            height: 10px;
            transform: translateX(-50%);
            border-radius: 50%;
            background: rgba(255,255,255,.85);
            box-shadow: 0 0 0 3px rgba(255,255,255,.10), 0 0 18px rgba(45,212,191,.25);
        }
        .fpw-wx__gustHalo{
            position:absolute; inset: 26px;
            border-radius:50%;
            box-shadow: inset 0 0 0 2px rgba(255,255,255,.10);
            opacity:.55;
            transition: box-shadow 240ms ease, opacity 240ms ease;
        }
        .fpw-wx__dialCenter{
            position:absolute;
            inset: 64px;
            border-radius: 50%;
            background: rgba(0,0,0,.35);
            border: 1px solid rgba(255,255,255,.10);
            display:flex;
            flex-direction:column;
            align-items:center;
            justify-content:center;
            padding: 10px;
            text-align:center;
            box-shadow: inset 0 0 0 1px rgba(255,255,255,.06);
        }
        .fpw-wx__dialSpeed{
            font-size: 2rem;
            font-weight: 900;
            letter-spacing:.4px;
            line-height: 1;
            color: rgba(255,255,255,.95);
        }
        .fpw-wx__dialSub{
            margin-top: 6px;
            font-size:.82rem;
            color: rgba(255,255,255,.75);
            display:flex;
            gap:6px;
            align-items:center;
            flex-wrap:wrap;
            justify-content:center;
        }
        .fpw-wx__dialCond{
            margin-top: 6px;
            font-size:.78rem;
            color: rgba(255,255,255,.62);
            max-width: 190px;
            line-height: 1.1rem;
        }
        .fpw-wx__cardinals span{
            position:absolute;
            font-size:.78rem;
            font-weight:800;
            color: rgba(255,255,255,.72);
            text-shadow: 0 2px 8px rgba(0,0,0,.35);
        }
        .fpw-wx__cardinals .n{ top: 10px; left: 50%; transform: translateX(-50%); }
        .fpw-wx__cardinals .s{ bottom: 10px; left: 50%; transform: translateX(-50%); }
        .fpw-wx__cardinals .e{ right: 12px; top: 50%; transform: translateY(-50%); }
        .fpw-wx__cardinals .w{ left: 12px; top: 50%; transform: translateY(-50%); }

        .fpw-wx__miniRow{
            display:grid;
            grid-template-columns: 1fr 1fr;
            gap:10px;
            margin-top:10px;
        }
        .fpw-wx__miniStat{
            background: rgba(0,0,0,.20);
            border:1px solid rgba(255,255,255,.08);
            border-radius: 12px;
            padding: 10px;
        }
        .fpw-wx__miniLabel{
            font-size:.7rem;
            color: rgba(255,255,255,.62);
            text-transform: uppercase;
            letter-spacing: .6px;
        }
        .fpw-wx__miniValue{
            font-size: .95rem;
            font-weight: 800;
            color: rgba(255,255,255,.90);
            margin-top: 2px;
        }

        /* Timeline */
        .fpw-wx__timelineGrid{ display:grid; grid-template-columns: 140px 1fr; gap: 12px; align-items:start; }
        @media (max-width: 576px){ .fpw-wx__timelineGrid{ grid-template-columns: 1fr; } }
        .fpw-wx__timelineLegend{
            display:flex;
            flex-direction:column;
            gap:8px;
            font-size:.78rem;
            color: rgba(255,255,255,.72);
            padding-top: 2px;
        }
        .fpw-wx__timelineLegend .swatch{
            display:inline-block;
            width:10px;height:10px;border-radius:3px;
            margin-right:8px;
            border:1px solid rgba(255,255,255,.15);
        }
        .swatch.wind{ background: rgba(59,130,246,.45); }
        .swatch.gust{ background: rgba(250,204,21,.48); }
        .swatch.rain{ background: rgba(45,212,191,.38); }
        .swatch.alert{ background: rgba(239,68,68,.55); }

        /* Make the 12-period cards larger + horizontally scrollable */
        .fpw-wx__timelineBars{
            overflow-x: auto;
            overflow-y: hidden;
            padding-bottom: 10px;
            scroll-snap-type: x proximity;
        }
        .fpw-wx__timelineBars::-webkit-scrollbar{ height: 10px; }
        .fpw-wx__timelineBars::-webkit-scrollbar-track{ background: rgba(255,255,255,.05); border-radius: 999px; }
        .fpw-wx__timelineBars::-webkit-scrollbar-thumb{ background: rgba(255,255,255,.14); border-radius: 999px; }
        .fpw-wx__timelineBars::-webkit-scrollbar-thumb:hover{ background: rgba(255,255,255,.22); }

        .fpw-wx__timelineStage{ position:relative; min-width: max-content; }

        .fpw-wx__bars{
            display:flex;
            gap:10px;
            padding-right: 6px;
        }
        .fpw-wx__bar{
            width: 112px;
            border-radius: 14px;
            padding: 10px 10px 9px;
            border:1px solid rgba(255,255,255,.08);
            background: rgba(0,0,0,.22);
            position:relative;
            overflow:hidden;
            min-height: 118px;
            scroll-snap-align: start;
        }
        @media (max-width: 576px){
            .fpw-wx__bar{ width: 100px; min-height: 112px; }
        }

        .fpw-wx__barTop{
            display:flex;
            justify-content:space-between;
            align-items:baseline;
            gap:8px;
        }
        .fpw-wx__barWhen{
            font-size:.74rem;
            color: rgba(255,255,255,.72);
            white-space:nowrap;
            overflow:hidden;
            text-overflow:ellipsis;
            max-width: 92px;
        }
        .fpw-wx__barTemp{
            font-weight:900;
            font-size:1.05rem;
            color: rgba(255,255,255,.92);
            white-space:nowrap;
        }
        .fpw-wx__barMeters{
            margin-top: 8px;
            display:flex;
            flex-direction:column;
            gap:7px;
        }
        .fpw-wx__meterRow{
            height: 7px;
            border-radius:999px;
            background: rgba(255,255,255,.06);
            border:1px solid rgba(255,255,255,.06);
            overflow:hidden;
        }
        .fpw-wx__meterFill{
            height:100%;
            border-radius:999px;
            width: 20%;
        }
        .fpw-wx__meterFill.wind{ background: rgba(59,130,246,.72); }
        .fpw-wx__meterFill.gust{ background: rgba(250,204,21,.78); }
        .fpw-wx__meterFill.rain{ background: rgba(45,212,191,.60); }

        .fpw-wx__barFlag{
            position:absolute;
            right:8px; top:8px;
            width:10px;height:10px;border-radius:50%;
            background: rgba(239,68,68,.85);
            box-shadow: 0 0 0 3px rgba(239,68,68,.15);
        }
        .fpw-wx__alertsEmpty{
            margin-top: 10px;
            color: rgba(255,255,255,.72);
            font-size:.85rem;
        }
        .fpw-wx__alertsList{
            list-style:none;
            padding:0;
            margin: 10px 0 0;
            display:flex;
            gap:10px;
            flex-wrap:wrap;
        }
        .fpw-wx__alertItem{
            flex: 1 1 340px;
            background: rgba(0,0,0,.18);
            border:1px solid rgba(255,255,255,.08);
            border-radius: 12px;
            padding: 10px;
        }
        .fpw-wx__alertHead{
            display:flex;
            gap:8px;
            align-items:center;
            margin-bottom: 4px;
        }
        .fpw-wx__alertBadge{
            font-size:.72rem;
            font-weight:900;
            letter-spacing:.6px;
            padding:.16rem .5rem;
            border-radius:999px;
            border:1px solid rgba(255,255,255,.12);
        }
        .fpw-wx__alertBadge.info{ background: rgba(59,130,246,.18); }
        .fpw-wx__alertBadge.warning{ background: rgba(250,204,21,.16); }
        .fpw-wx__alertBadge.critical{ background: rgba(239,68,68,.16); }
        .fpw-wx__alertTitle{
            font-weight: 800;
            color: rgba(255,255,255,.90);
            font-size: .88rem;
        }
        .fpw-wx__alertMsg{
            color: rgba(255,255,255,.70);
            font-size: .82rem;
            line-height: 1.15rem;
        }

        /* Instruments */
        .fpw-wx__instruments{
            margin-top: 14px;
            display:grid;
            grid-template-columns: repeat(4, 1fr);
            gap: 12px;
        }
        @media (max-width: 992px){ .fpw-wx__instruments{ grid-template-columns: repeat(2, 1fr);} }
        @media (max-width: 576px){ .fpw-wx__instruments{ grid-template-columns: 1fr;} }

        .fpw-wx__gauge{
            background: rgba(255,255,255,.05);
            border:1px solid rgba(255,255,255,.08);
            border-radius: 14px;
            padding: 12px;
            box-shadow: 0 10px 20px rgba(0,0,0,.18);
        }
        .fpw-wx__gaugeTop{
            display:flex;
            justify-content:space-between;
            align-items:baseline;
            gap:10px;
        }
        .fpw-wx__gaugeLabel{
            font-size:.75rem;
            color: rgba(255,255,255,.68);
            font-weight: 800;
            text-transform: uppercase;
            letter-spacing:.6px;
        }
        .fpw-wx__gaugeValue{
            font-size: 1.1rem;
            font-weight: 900;
            color: rgba(255,255,255,.92);
        }
        .fpw-wx__gaugeFoot{
            margin-top: 10px;
            font-size:.75rem;
            color: rgba(255,255,255,.62);
        }

        .fpw-wx__arc{
            margin-top: 10px;
            height: 84px;
            border-radius: 12px;
            background:
              conic-gradient(from 180deg,
                rgba(59,130,246,.65) 0deg,
                rgba(45,212,191,.65) 90deg,
                rgba(250,204,21,.68) 150deg,
                rgba(239,68,68,.70) 210deg,
                rgba(255,255,255,.06) 0deg);
            mask: radial-gradient(circle at 50% 100%, transparent 0 58%, #000 60% 100%);
            opacity:.9;
            position: relative;
            overflow:hidden;
        }
        .fpw-wx__temp{ position:relative; }
        .fpw-wx__temp .fpw-wx__arc::after{
            content:"";
            position:absolute;
            left: calc((var(--pct) * 1%) - 6px);
            bottom: 6px;
            width: 12px;
            height: 12px;
            border-radius: 50%;
            background: rgba(255,255,255,.92);
            box-shadow: 0 0 0 4px rgba(255,255,255,.12), 0 0 20px rgba(45,212,191,.22);
        }

        .fpw-wx__spikes{ margin-top: 10px; height: 84px; }
        .fpw-wx__spikeBars{
            display:flex;
            align-items:flex-end;
            gap: 4px;
            height: 84px;
        }
        .fpw-wx__spike{
            flex: 1 1 0;
            border-radius: 6px 6px 10px 10px;
            background: rgba(250,204,21,.25);
            border:1px solid rgba(255,255,255,.10);
            min-width: 6px;
            position: relative;
            overflow:hidden;
        }
        .fpw-wx__spike.hot{ background: rgba(239,68,68,.22); }
        .fpw-wx__spike.ok{ background: rgba(59,130,246,.22); }
        .fpw-wx__spike > i{
            display:block;
            width:100%;
            height: 50%;
            background: linear-gradient(180deg, rgba(255,255,255,.25), rgba(255,255,255,0));
            opacity:.35;
        }

        .fpw-wx__trend{ margin-top: 12px; display:flex; justify-content:center; }
        .fpw-wx__trendPill{
            font-size:.8rem;
            padding:.25rem .65rem;
            border-radius:999px;
            border:1px solid rgba(255,255,255,.10);
            background: rgba(0,0,0,.18);
            color: rgba(255,255,255,.82);
        }
        .fpw-wx__trendPill.up{ border-color: rgba(34,197,94,.25); background: rgba(34,197,94,.10); }
        .fpw-wx__trendPill.down{ border-color: rgba(239,68,68,.25); background: rgba(239,68,68,.10); }
        .fpw-wx__trendPill.neutral{ border-color: rgba(59,130,246,.22); background: rgba(59,130,246,.10); }

        .fpw-wx__meter{ margin-top: 12px; height: 10px; border-radius:999px; background: rgba(255,255,255,.06); border:1px solid rgba(255,255,255,.06); overflow:hidden;}
        .fpw-wx__meterFill{ height:100%; border-radius:999px; background: rgba(45,212,191,.45); }

        /* Confidence */
        .fpw-wx__confidence{
            margin-top: 12px;
            display:flex;
            align-items:center;
            gap:10px;
            padding: 10px 12px;
            border-radius: 14px;
            background: rgba(255,255,255,.04);
            border: 1px solid rgba(255,255,255,.08);
        }
        .fpw-wx__confidenceLabel{
            font-size:.78rem;
            color: rgba(255,255,255,.70);
            font-weight: 800;
            text-transform: uppercase;
            letter-spacing:.6px;
            min-width: 150px;
        }
        .fpw-wx__confidenceBarWrap{
            flex: 1 1 auto;
            height: 10px;
            border-radius:999px;
            background: rgba(255,255,255,.06);
            border:1px solid rgba(255,255,255,.06);
            overflow:hidden;
        }
        .fpw-wx__confidenceBar{
            height:100%;
            border-radius:999px;
            background: linear-gradient(90deg, rgba(34,197,94,.70), rgba(45,212,191,.70));
            transition: width 320ms ease;
        }
        .fpw-wx__confidenceBar.med{
            background: linear-gradient(90deg, rgba(250,204,21,.75), rgba(59,130,246,.55));
        }
        .fpw-wx__confidenceBar.low{
            background: linear-gradient(90deg, rgba(239,68,68,.75), rgba(250,204,21,.55));
            background-size: 22px 22px;
            animation: fpwWxStripe 1.1s linear infinite;
        }
        @keyframes fpwWxStripe{
            from{ filter: hue-rotate(0deg); }
            to{ filter: hue-rotate(10deg); }
        }
        .fpw-wx__confidenceText{
            min-width: 80px;
            text-align:right;
            font-weight: 900;
            color: rgba(255,255,255,.90);
        }
        /* Enhanced labels + float plan overlay */
        .fpw-wx__timelineStage{ position:relative; }
        .fpw-wx__planOverlay{ position:absolute; inset:0; pointer-events:none; }
        .fpw-wx__planBand{
            position:absolute;
            top:6px; bottom:6px;
            border-radius:12px;
            background: linear-gradient(90deg, rgba(45,212,191,.12), rgba(45,212,191,.06));
            border:1px solid rgba(45,212,191,.24);
            box-shadow: 0 0 0 1px rgba(0,0,0,.25) inset;
        }
        .fpw-wx__planBand:before{
            content:"";
            position:absolute; inset:0;
            border-radius:12px;
            background: linear-gradient(180deg, rgba(255,255,255,.14), transparent 40%);
            opacity:.55;
        }
        .fpw-wx__planLabel{
            position:absolute;
            top:-10px; left:10px;
            padding:4px 8px;
            border-radius:999px;
            font-size:.72rem;
            background: rgba(2,6,23,.78);
            border:1px solid rgba(45,212,191,.28);
            color: rgba(229,231,235,.94);
            letter-spacing:.2px;
            white-space:nowrap;
        }

        .fpw-wx__barMeta{
            display:flex;
            flex-direction:column;
            align-items:flex-start;
            gap:4px;
            margin-top:6px;
            font-size:.70rem;
            color: rgba(255,255,255,.70);
        }
        .fpw-wx__barMeta .chip{
            display:block;
            width:100%;
            max-width:100%;
            padding:2px 8px;
            border-radius:10px;
            border:1px solid rgba(255,255,255,.10);
            background: rgba(255,255,255,.04);
            white-space:nowrap;
            overflow:hidden;
            text-overflow:ellipsis;
            line-height:1.2;
            font-size:.78rem;
        }
        .fpw-wx__barMeta .chip b{
            color: rgba(255,255,255,.90);
            font-weight:600;
        }

        .fpw-wx__tideGraph{
            margin: 10px 0 6px;
            padding: 10px;
            border-radius: 12px;
            background: rgba(0,0,0,.20);
            border:1px solid rgba(255,255,255,.08);
        }
        .fpw-wx__tideTitle{
            display:flex;
            justify-content:space-between;
            align-items:baseline;
            font-size:.78rem;
            color: rgba(255,255,255,.80);
            margin-bottom:6px;
        }
        .fpw-wx__tideSvg{
            width:100%;
            height:84px;
            display:block;
        }
        .fpw-wx__tideAxis{
            display:flex;
            justify-content:space-between;
            font-size:.7rem;
            color: rgba(255,255,255,.60);
            margin-top:6px;
        }
        .fpw-wx__tideEmpty{
            font-size:.78rem;
            color: rgba(255,255,255,.60);
            margin-top:6px;
        }

        .fpw-wx__meterRow{
            position:relative;
            height:8px;
            border-radius:999px;
            background: rgba(255,255,255,.06);
            overflow:hidden;
        }
        .fpw-wx__meterRow .val{
            position:absolute;
            top:-18px; right:0;
            font-size:.68rem;
            color: rgba(255,255,255,.65);
        }

        .fpw-wx__spikeLabels{
            display:flex;
            justify-content:space-between;
            gap:10px;
            margin-top:8px;
            font-size:.7rem;
            color: rgba(255,255,255,.60);
        }
        .fpw-wx__arcLabels{
            display:flex;
            justify-content:space-between;
            margin-top:8px;
            font-size:.72rem;
            color: rgba(255,255,255,.65);
        }


</style>
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
                </div>
                <div class="fpw-card__actions">
                    <button class="btn btn-sm btn-outline-secondary" type="button">Mark all read</button>
                    <a class="btn btn-sm btn-primary" href="#">View all</a>
                </div>
            </div>

            <div id="alertsCollapse" class="collapse">
                <div class="fpw-card__body">

  <!-- Weather Panel (Cockpit / ZIP-based) -->
  <section class="fpw-weather-cockpit" aria-labelledby="weatherPanelTitle">

    <!-- Top Row -->
    <div class="fpw-wx__top">
      <div class="fpw-wx__topLeft">
        <div class="fpw-wx__titleRow">
          <span id="weatherStatusDot" class="fpw-wx__dot ok" aria-hidden="true"></span>
          <h3 id="weatherPanelTitle" class="fpw-wx__title">—</h3>
          <span id="weatherProviderBadge" class="fpw-wx__badge">NOAA/NWS</span>
          <span id="weatherUpdatedAt" class="fpw-wx__pill d-none">Updated: —</span>
        </div>
        <div id="weatherSummary" class="fpw-wx__summary">
          Enter a ZIP code to load your local forecast.
        </div>
      </div>

      <div class="fpw-wx__topRight">
        <div class="fpw-wx__zipBlock">
          <label for="weatherZip" class="fpw-wx__zipLabel">ZIP</label>
          <input
            id="weatherZip"
            type="text"
            inputmode="numeric"
            pattern="[0-9]{5}"
            maxlength="5"
            class="form-control form-control-sm fpw-wx__zipInput"
            value="34652"
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
            <div id="weatherWindNeedle" class="fpw-wx__needle" style="--dir: 0deg;"></div>
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
          <div class="fpw-wx__panelTitle">Next 12 periods</div>
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
            <span>Tide (ft)</span>
            <span id="tideGraphStation" class="fpw-wx__muted"></span>
          </div>
          <svg id="tideGraphSvg" class="fpw-wx__tideSvg" viewBox="0 0 320 84" preserveAspectRatio="none" aria-hidden="true"></svg>
          <div class="fpw-wx__tideAxis">
            <span id="tideGraphStart">—</span>
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
    <div class="fpw-wx__instruments">

      <!-- Temp Arc -->
      <div class="fpw-wx__gauge fpw-wx__temp" style="--pct: 50;">
        <div class="fpw-wx__gaugeTop">
          <div class="fpw-wx__gaugeLabel">Temp</div>
          <div id="weatherTempValue" class="fpw-wx__gaugeValue">—</div>
        </div>
        <div class="fpw-wx__arc" aria-hidden="true"></div>
        <div class="fpw-wx__arcLabels" aria-hidden="true">
          <span id="weatherTempLoLabel" class="fpw-wx__arcLo">—</span>
          <span id="weatherTempHiLabel" class="fpw-wx__arcHi">—</span>
        </div>
        <div class="fpw-wx__gaugeFoot">
          <span id="weatherTempHiLo" class="fpw-wx__muted">—</span>
        </div>
      </div>

      <!-- Gust Spikes -->
      <div class="fpw-wx__gauge fpw-wx__gusts">
        <div class="fpw-wx__gaugeTop">
          <div class="fpw-wx__gaugeLabel">Gusts</div>
          <div id="weatherGustValue" class="fpw-wx__gaugeValue">—</div>
        </div>
        <div class="fpw-wx__spikes" aria-label="Gust spikes">
          <div id="weatherGustSpikes" class="fpw-wx__spikeBars"></div>
          <div id="weatherGustLabels" class="fpw-wx__spikeLabels" aria-hidden="true"></div>
        </div>
        <div class="fpw-wx__gaugeFoot fpw-wx__muted">Estimated from forecast wind range for next 12 hours</div>
      </div>

      <!-- Pressure Trend (placeholder unless your API provides it later) -->
      <div class="fpw-wx__gauge fpw-wx__pressure">
        <div class="fpw-wx__gaugeTop">
          <div class="fpw-wx__gaugeLabel">Pressure</div>
          <div id="weatherPressureValue" class="fpw-wx__gaugeValue">—</div>
        </div>
        <div class="fpw-wx__trend">
          <span id="weatherPressureTrend" class="fpw-wx__trendPill neutral">—</span>
        </div>
        <div class="fpw-wx__gaugeFoot fpw-wx__muted">Hook later to buoy/station data</div>
      </div>

      <!-- Visibility (placeholder unless your API provides it later) -->
      <div class="fpw-wx__gauge fpw-wx__vis">
        <div class="fpw-wx__gaugeTop">
          <div class="fpw-wx__gaugeLabel">Visibility</div>
          <div id="weatherVisValue" class="fpw-wx__gaugeValue">—</div>
        </div>
        <div class="fpw-wx__meter" aria-hidden="true">
          <div id="weatherVisFill" class="fpw-wx__meterFill" style="width: 60%;"></div>
        </div>
        <div class="fpw-wx__gaugeFoot fpw-wx__muted">Hook later to METAR/marine obs</div>
      </div>

    </div>

    <!-- Confidence -->
    <div class="fpw-wx__confidence">
      <div class="fpw-wx__confidenceLabel">Forecast confidence</div>
      <div class="fpw-wx__confidenceBarWrap" aria-hidden="true">
        <div id="weatherConfidenceBar" class="fpw-wx__confidenceBar high" style="width: 82%;"></div>
      </div>
      <div id="weatherConfidenceText" class="fpw-wx__confidenceText">High</div>
    </div>

  </section>

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
                <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
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
                    <div id="waypointMap" style="height: 360px; width: 100%; border-radius: 8px;"></div>
                    <div class="small text-muted mt-1">Tip: drag the marker or click the map to reposition.</div>
                    <div class="border rounded p-2 mt-2 marine-controls">
                        <div class="d-flex align-items-center justify-content-between mb-1">
                            <label class="form-label mb-0">Marine Layers</label>
                            <small class="text-muted">Optional overlays</small>
                        </div>
                        <div class="row g-1 align-items-center">
                            <div class="col-md-7">
                                <div class="d-flex flex-wrap gap-2">
                                    <div class="form-check">
                                        <input class="form-check-input" type="checkbox" id="marineTypeMarina" data-marine-type="marina">
                                        <label class="form-check-label" for="marineTypeMarina">Marina</label>
                                    </div>
                                    <div class="form-check">
                                        <input class="form-check-input" type="checkbox" id="marineTypeFuel" data-marine-type="fuel">
                                        <label class="form-check-label" for="marineTypeFuel">Fuel Dock</label>
                                    </div>
                                    <div class="form-check">
                                        <input class="form-check-input" type="checkbox" id="marineTypeRamp" data-marine-type="ramp">
                                        <label class="form-check-label" for="marineTypeRamp">Boat Ramp</label>
                                    </div>
                                </div>
                            </div>
                            <div class="col-md-5">
                                <div class="form-check form-switch">
                                    <input class="form-check-input" type="checkbox" id="marineTideToggle" disabled>
                                    <label class="form-check-label" for="marineTideToggle">Tide/Current Stations</label>
                                </div>
                            </div>
                        </div>
                        <div class="mt-1 small text-muted" id="marineStatusLine" aria-live="polite">Ready</div>
                    </div>
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
                    <div class="mb-3">
                        <label class="form-label" for="vesselRegistration">Registration</label>
                        <input type="text" class="form-control" id="vesselRegistration">
                    </div>
                    <div class="row">
                        <div class="col-md-6 mb-3">
                            <label class="form-label" for="vesselType">Type *</label>
                            <input type="text" class="form-control" id="vesselType" required>
                            <div class="invalid-feedback" id="vesselTypeError"></div>
                        </div>
                        <div class="col-md-6 mb-3">
                            <label class="form-label" for="vesselLength">Length *</label>
                            <input type="text" class="form-control" id="vesselLength" required>
                            <div class="invalid-feedback" id="vesselLengthError"></div>
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
                    <div class="row">
                        <div class="col-md-6 mb-3">
                            <label class="form-label" for="vesselColor">Hull Color *</label>
                            <input type="text" class="form-control" id="vesselColor" required>
                            <div class="invalid-feedback" id="vesselColorError"></div>
                        </div>
                        <div class="col-md-6 mb-3">
                            <label class="form-label" for="vesselHomePort">Hailing Port</label>
                            <input type="text" class="form-control" id="vesselHomePort">
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
                            <p class="small text-muted">Tap to toggle each passenger.</p>
                            <div class="list-group">
                                <button
                                    v-for="p in passengers"
                                    :key="'p-'+p.PASSENGERID"
                                    type="button"
                                    class="list-group-item list-group-item-action list-group-button"
                                    @click="togglePassenger(p)">
                                    <span>{{ p.PASSENGERNAME }}</span>
                                    <span class="badge" :class="isPassengerSelected(p.PASSENGERID) ? 'bg-success' : 'bg-secondary'">
                                        {{ isPassengerSelected(p.PASSENGERID) ? 'Included' : 'Tap to add' }}
                                    </span>
                                </button>
                            </div>

                            <div class="mt-4">
                                <p class="small text-muted">Tap to include for notifications.</p>
                                <div class="list-group">
                                    <button
                                        v-for="c in contacts"
                                        :key="'c-'+c.CONTACTID"
                                        type="button"
                                        class="list-group-item list-group-item-action list-group-button"
                                        @click="toggleContact(c)">
                                        <span>{{ c.CONTACTNAME }}</span>
                                        <span class="badge" :class="isContactSelected(c.CONTACTID) ? 'bg-success' : 'bg-secondary'">
                                            {{ isContactSelected(c.CONTACTID) ? 'Included' : 'Tap to add' }}
                                        </span>
                                    </button>
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

                            <h3 class="h6">Waypoints</h3>
                            <p class="small text-muted">Tap to include; order is preserved.</p>
                            <div class="list-group mb-3">
                                <button
                                    v-for="w in waypoints"
                                    :key="'w-'+w.WAYPOINTID"
                                    type="button"
                                    class="list-group-item list-group-item-action list-group-button"
                                    @click="toggleWaypoint(w)">
                                    <span>{{ w.WAYPOINTNAME }}</span>
                                    <span class="badge" :class="isWaypointSelected(w.WAYPOINTID) ? 'bg-success' : 'bg-secondary'">
                                        {{ isWaypointSelected(w.WAYPOINTID) ? 'In Route' : 'Tap to add' }}
                                    </span>
                                </button>
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
                                <div v-else-if="pdfPreviewUrl" class="border rounded" style="height: 60vh;">
                                    <iframe
                                        :src="pdfPreviewUrl"
                                        title="Float plan PDF preview"
                                        class="w-100 h-100"
                                        style="border: 0;"
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

<cfinclude template="../includes/footer_scripts.cfm">

<script src="https://unpkg.com/vue@3/dist/vue.global.prod.js"></script>
<script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js" integrity="sha256-20nQCchB9co0qIjJZRGuk2/Z9VM+kNiyxNV1lvTlZBo=" crossorigin=""></script>
<script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/maps/leaflet-noaa-waypoint-map.js"></script>
<script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/app/validate.js"></script>
<script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/app/floatplanWizard.js?v=20251227b"></script>
<script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/app/dashboard/utils.js?v=20251227s"></script>
<script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/app/dashboard/state.js"></script>
<script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/app/dashboard/alerts.js"></script>
<script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/app/dashboard/floatplans.js?v=20251227am"></script>
<script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/app/dashboard/vessels.js"></script>
<script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/app/dashboard/contacts.js"></script>
<script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/app/dashboard/passengers.js?v=20251227r"></script>
<script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/app/dashboard/operators.js?v=20251227r"></script>
<script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/app/dashboard/waypoints.js?v=20251227ak"></script>

<!-- Dashboard-specific JS -->
<script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/app/dashboard.js?v=20260211b"></script>



</body>
</html>
