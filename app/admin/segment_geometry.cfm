<cfsetting showdebugoutput="false">

<cfscript>
userStruct = (structKeyExists(session, "user") AND isStruct(session.user)) ? session.user : {};
isLoggedIn = structCount(userStruct) GT 0;
adminWhitelist = "admin@floatplanwizard.com,lswald@yahoo.com"; // TODO: move to app config.

function boolLike(any value, boolean defaultValue=false) {
    var txt = lCase(trim(toString(arguments.value)));
    if (!len(txt)) return arguments.defaultValue;
    if (listFindNoCase("1,true,yes,y,on", txt)) return true;
    if (listFindNoCase("0,false,no,n,off", txt)) return false;
    if (isNumeric(txt)) return (val(txt) NEQ 0);
    return arguments.defaultValue;
}

function emailFromUser(required struct u) {
    if (structKeyExists(arguments.u, "email")) return lCase(trim(toString(arguments.u.email)));
    if (structKeyExists(arguments.u, "EMAIL")) return lCase(trim(toString(arguments.u.EMAIL)));
    return "";
}

function roleFromUser(required struct u) {
    if (structKeyExists(arguments.u, "role")) return lCase(trim(toString(arguments.u.role)));
    if (structKeyExists(arguments.u, "ROLE")) return lCase(trim(toString(arguments.u.ROLE)));
    return "";
}

isAdmin = false;
if (isLoggedIn) {
    if (structKeyExists(userStruct, "isAdmin") AND boolLike(userStruct.isAdmin, false)) {
        isAdmin = true;
    } else if (structKeyExists(userStruct, "ISADMIN") AND boolLike(userStruct.ISADMIN, false)) {
        isAdmin = true;
    } else if (structKeyExists(userStruct, "is_admin") AND boolLike(userStruct.is_admin, false)) {
        isAdmin = true;
    } else if (roleFromUser(userStruct) EQ "admin") {
        isAdmin = true;
    } else if (len(emailFromUser(userStruct)) AND listFindNoCase(adminWhitelist, emailFromUser(userStruct))) {
        isAdmin = true;
    }
}

isAuthorized = isLoggedIn AND isAdmin;
request.fpwBase = "/fpw";
</cfscript>

<!doctype html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Segment Geometry Editor</title>

    <cfinclude template="../../includes/header_styles.cfm">

    <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/leaflet.draw/1.0.4/leaflet.draw.css">

    <style>
        .sg-page {
            min-height: 100vh;
            background:
                radial-gradient(circle at 10% 10%, rgba(35, 79, 132, 0.32), transparent 40%),
                radial-gradient(circle at 85% 15%, rgba(17, 136, 118, 0.18), transparent 35%),
                linear-gradient(160deg, #070b14 0%, #0d1728 48%, #0b1220 100%);
            color: #dce7f7;
            padding: 24px;
        }

        .sg-shell {
            max-width: 1400px;
            margin: 0 auto;
            display: grid;
            gap: 14px;
        }

        .sg-panel {
            border: 1px solid rgba(145, 175, 218, 0.2);
            border-radius: 14px;
            background: rgba(8, 16, 30, 0.78);
            box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.06), 0 14px 28px rgba(0, 0, 0, 0.3);
            backdrop-filter: blur(8px);
        }

        .sg-header {
            display: flex;
            flex-wrap: wrap;
            align-items: center;
            justify-content: space-between;
            gap: 12px;
            padding: 16px 18px;
        }

        .sg-title {
            margin: 0;
            font-size: 1.3rem;
            letter-spacing: 0.06em;
            text-transform: uppercase;
            color: #eff6ff;
        }

        .sg-subtitle {
            margin: 4px 0 0;
            color: rgba(214, 230, 255, 0.8);
            font-size: 0.9rem;
        }

        .sg-help {
            padding: 14px 18px;
            border-top: 1px solid rgba(145, 175, 218, 0.15);
            color: rgba(214, 230, 255, 0.92);
            line-height: 1.45;
            font-size: 0.95rem;
        }

        .sg-help strong {
            color: #f8fbff;
        }

        .sg-controls {
            padding: 14px 18px 16px;
            border-top: 1px solid rgba(145, 175, 218, 0.15);
            display: grid;
            grid-template-columns: 2.2fr auto auto auto 1fr;
            gap: 10px;
            align-items: center;
        }

        .sg-label {
            font-size: 0.8rem;
            letter-spacing: 0.09em;
            text-transform: uppercase;
            color: rgba(198, 220, 252, 0.75);
            margin-bottom: 4px;
        }

        .sg-select-wrap {
            display: flex;
            flex-direction: column;
        }

        .sg-select,
        .sg-input,
        .sg-btn {
            border-radius: 10px;
            border: 1px solid rgba(137, 173, 221, 0.3);
            background: rgba(12, 26, 48, 0.72);
            color: #f0f6ff;
            min-height: 40px;
            padding: 8px 12px;
            font-size: 0.95rem;
        }

        .sg-select:focus,
        .sg-input:focus,
        .sg-btn:focus {
            outline: none;
            border-color: rgba(98, 179, 255, 0.85);
            box-shadow: 0 0 0 3px rgba(70, 144, 227, 0.24);
        }

        .sg-btn {
            cursor: pointer;
            font-weight: 600;
            letter-spacing: 0.02em;
        }

        .sg-btn:hover {
            background: rgba(23, 43, 74, 0.88);
        }

        .sg-btn-save {
            background: linear-gradient(135deg, rgba(35, 106, 193, 0.95), rgba(42, 145, 225, 0.94));
            border-color: rgba(87, 173, 250, 0.7);
        }

        .sg-btn-save:hover {
            background: linear-gradient(135deg, rgba(44, 115, 202, 1), rgba(53, 153, 231, 1));
        }

        .sg-readouts {
            display: flex;
            gap: 10px;
            justify-content: flex-end;
            flex-wrap: wrap;
        }

        .sg-search-row {
            padding: 0 18px 14px;
            display: grid;
            grid-template-columns: 2.2fr auto auto;
            gap: 10px;
            align-items: end;
        }

        .sg-stat {
            min-width: 150px;
            border: 1px solid rgba(146, 177, 219, 0.2);
            border-radius: 10px;
            background: rgba(6, 15, 27, 0.78);
            padding: 8px 10px;
        }

        .sg-stat-label {
            font-size: 0.72rem;
            letter-spacing: 0.08em;
            text-transform: uppercase;
            color: rgba(189, 213, 247, 0.75);
        }

        .sg-stat-value {
            font-size: 1.1rem;
            font-weight: 700;
            color: #f6fbff;
            margin-top: 2px;
            font-family: Consolas, Menlo, Monaco, monospace;
        }

        .sg-status {
            margin: 0;
            padding: 10px 14px;
            border-radius: 10px;
            border: 1px solid rgba(131, 171, 230, 0.23);
            background: rgba(10, 22, 38, 0.75);
            color: rgba(220, 234, 255, 0.96);
            font-size: 0.93rem;
        }

        .sg-status.error {
            border-color: rgba(240, 122, 122, 0.52);
            background: rgba(59, 14, 14, 0.68);
            color: #ffd2d2;
        }

        .sg-status.success {
            border-color: rgba(95, 203, 162, 0.52);
            background: rgba(13, 52, 41, 0.7);
            color: #d0fff0;
        }

        .sg-map-wrap {
            padding: 12px;
        }

        .sg-map {
            width: 100%;
            height: 70vh;
            min-height: 480px;
            border-radius: 14px;
            border: 1px solid rgba(145, 175, 218, 0.24);
            overflow: hidden;
        }

        .leaflet-control,
        .leaflet-draw-toolbar a {
            border-radius: 8px !important;
        }

        @media (max-width: 1180px) {
            .sg-controls {
                grid-template-columns: 1fr 1fr;
            }

            .sg-search-row {
                grid-template-columns: 1fr 1fr;
            }

            .sg-readouts {
                justify-content: flex-start;
            }
        }

        @media (max-width: 720px) {
            .sg-page {
                padding: 12px;
            }

            .sg-controls {
                grid-template-columns: 1fr;
            }

            .sg-search-row {
                grid-template-columns: 1fr;
            }

            .sg-map {
                height: 64vh;
                min-height: 380px;
            }
        }
    </style>
</head>
<body>

<cfinclude template="../../includes/top_nav.cfm">

<main class="sg-page">
    <div class="sg-shell">
        <section class="sg-panel">
            <header class="sg-header">
                <div>
                    <h1 class="sg-title">Segment Geometry Editor</h1>
                    <p class="sg-subtitle">Versioned polylines for canonical loop segments with server-calculated nautical miles.</p>
                </div>
            </header>

            <div class="sg-help">
                <strong>How to use:</strong> Select a canonical segment, click <strong>Load</strong>, draw or edit one polyline that follows the real water route, then click <strong>Save</strong>. FPW stores this as a new geometry version and calculates <strong>dist_nm_calc</strong> server-side from the polyline points.
            </div>

            <cfif NOT isAuthorized>
                <div class="p-3">
                    <p class="sg-status error">Unauthorized. You must be logged in as an admin to access this page.</p>
                </div>
            <cfelse>
                <div class="sg-controls">
                    <div class="sg-select-wrap">
                        <label class="sg-label" for="segmentSelect">Segment</label>
                        <select id="segmentSelect" class="sg-select" aria-label="Segment selector">
                            <option value="">Loading segments...</option>
                        </select>
                    </div>

                    <button type="button" id="loadSegmentBtn" class="sg-btn">Load</button>
                    <button type="button" id="saveGeometryBtn" class="sg-btn sg-btn-save">Save</button>
                    <button type="button" id="clearGeometryBtn" class="sg-btn">Clear</button>

                    <div class="sg-readouts" aria-live="polite">
                        <div class="sg-stat">
                            <div class="sg-stat-label">Point Count</div>
                            <div class="sg-stat-value" id="pointCountValue">0</div>
                        </div>
                        <div class="sg-stat">
                            <div class="sg-stat-label">Computed NM</div>
                            <div class="sg-stat-value" id="computedNmValue">--</div>
                        </div>
                        <div class="sg-stat">
                            <div class="sg-stat-label">Active Version</div>
                            <div class="sg-stat-value" id="versionValue">--</div>
                        </div>
                    </div>
                </div>

                <div class="sg-search-row">
                    <div class="sg-select-wrap">
                        <label class="sg-label" for="mapSearchInput">Map / Segment Search</label>
                        <input
                            id="mapSearchInput"
                            class="sg-input"
                            type="text"
                            placeholder="Search segment parts or places (example: South Haven, Chicago Harbor)"
                            autocomplete="off">
                    </div>
                    <button type="button" id="mapSearchBtn" class="sg-btn">Search</button>
                    <button type="button" id="mapSearchClearBtn" class="sg-btn">Clear Pin</button>
                </div>

                <div class="px-3 pb-2">
                    <p id="geometryStatus" class="sg-status">Ready. Select a segment, then click Load.</p>
                </div>

                <div class="sg-map-wrap">
                    <div id="geometryMap" class="sg-map" aria-label="Segment geometry map"></div>
                </div>
            </cfif>
        </section>
    </div>
</main>

<cfinclude template="../../includes/footer_scripts.cfm">

<script>
    window.FPW_BASE = "<cfoutput>#request.fpwBase#</cfoutput>";
</script>
<script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/leaflet.draw/1.0.4/leaflet.draw.js"></script>
<cfif isAuthorized>
    <script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/app/admin/segment_geometry.js?v=1"></script>
</cfif>

</body>
</html>
