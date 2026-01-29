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
    </style>
</head>
<body class="dashboard-body">




<header class="dashboard-header">
    <div class="header-grid">
        <div class="user-info">
            <h1>Welcome, <span id="userName">Loading…</span></h1>
            <small>Email: <span id="userEmail">Loading…</span></small>
        </div>
        <div class="header-meta">
            <div class="header-actions">
                <a href="<cfoutput>#request.fpwBase#</cfoutput>/app/account.cfm">Account</a>
                <button id="logoutButton">Logout</button>
            </div>
        </div>
    </div>
</header>

<main class="dashboard-main">
    <div id="dashboardAlert" class="alert d-none" role="alert"></div>

    <div class="dashboard-grid">

        
        <section class="fpw-card fpw-alerts" aria-label="System Alerts">
            <div class="fpw-card__header">
                <div class="fpw-card__title">
                    <span class="fpw-alerts__icon" aria-hidden="true">!</span>
                    <h2>System Alerts</h2>
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
                    <div id="alertsEmpty" class="d-none">No alerts right now.</div>
                    <ul id="alertsList" class="fpw-alerts__list">
                    <li class="fpw-alert fpw-alert--critical" data-status="CRITICAL">
                        <span class="fpw-alert__stripe" aria-hidden="true"></span>
                        <div class="fpw-alert__main">
                            <div class="fpw-alert__meta">
                                <span class="fpw-badge fpw-badge--critical">CRITICAL</span>
                                <span class="fpw-alert__time">2m ago</span>
                            </div>
                            <div class="fpw-alert__title">Return window exceeded</div>
                            <div class="fpw-alert__message">Active float plan passed the expected return time.</div>
                            <div class="fpw-alert__pills">
                                <span class="fpw-pill">Provider: FPW</span>
                                <span class="fpw-pill">Code: FP-401</span>
                            </div>
                        </div>
                        <div class="fpw-alert__actions">
                            <button class="btn btn-sm btn-outline-secondary" type="button">Details</button>
                            <button class="btn btn-sm btn-primary" type="button">Dismiss</button>
                        </div>
                    </li>
                    <li class="fpw-alert fpw-alert--warning" data-status="WARNING">
                        <span class="fpw-alert__stripe" aria-hidden="true"></span>
                        <div class="fpw-alert__main">
                            <div class="fpw-alert__meta">
                                <span class="fpw-badge fpw-badge--warning">WARNING</span>
                                <span class="fpw-alert__time">35m ago</span>
                            </div>
                            <div class="fpw-alert__title">Incomplete contact info</div>
                            <div class="fpw-alert__message">Two emergency contacts are missing phone numbers.</div>
                            <div class="fpw-alert__pills">
                                <span class="fpw-pill">Provider: Contacts</span>
                            </div>
                        </div>
                        <div class="fpw-alert__actions">
                            <button class="btn btn-sm btn-outline-secondary" type="button">Dismiss</button>
                        </div>
                    </li>
                    <li class="fpw-alert fpw-alert--info" data-status="INFO">
                        <span class="fpw-alert__stripe" aria-hidden="true"></span>
                        <div class="fpw-alert__main">
                            <div class="fpw-alert__meta">
                                <span class="fpw-badge fpw-badge--info">INFO</span>
                                <span class="fpw-alert__time">Today</span>
                            </div>
                            <div class="fpw-alert__title">Weather update available</div>
                            <div class="fpw-alert__message">New marine conditions posted for New Port Richey.</div>
                            <div class="fpw-alert__pills">
                                <span class="fpw-pill">Provider: NOAA</span>
                            </div>
                        </div>
                        <div class="fpw-alert__actions">
                            <button class="btn btn-sm btn-outline-secondary" type="button">Details</button>
                            <button class="btn btn-sm btn-outline-secondary" type="button">Dismiss</button>
                        </div>
                    </li>
                    <li class="fpw-alert fpw-alert--success" data-status="SUCCESS">
                        <span class="fpw-alert__stripe" aria-hidden="true"></span>
                        <div class="fpw-alert__main">
                            <div class="fpw-alert__meta">
                                <span class="fpw-badge fpw-badge--success">SUCCESS</span>
                                <span class="fpw-alert__time">Yesterday</span>
                            </div>
                            <div class="fpw-alert__title">Float plan submitted</div>
                            <div class="fpw-alert__message">Your latest plan was delivered to all watchers.</div>
                            <div class="fpw-alert__pills">
                                <span class="fpw-pill">Provider: Dispatch</span>
                            </div>
                        </div>
                        <div class="fpw-alert__actions">
                            <button class="btn btn-sm btn-outline-secondary" type="button">Dismiss</button>
                        </div>
                    </li>
                    </ul>
                </div>

                <div class="fpw-card__footer">
                    <span>Showing latest 4 alerts</span>
                    <a class="fpw-link" href="#">Open alerts center -></a>
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
<script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/app/dashboard.js?v=20251227ak"></script>



</body>
</html>
