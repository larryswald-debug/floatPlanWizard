<!DOCTYPE html>
<!-- Updated to host the float plan wizard inside a Bootstrap modal. -->
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Dashboard - Float Plan Wizard</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">

    <cfinclude template="../includes/header_styles.cfm">
    <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" integrity="sha256-p4NxAoJBhIIN+hmNHrzRCf9tD/miZyoHS5obTRR9BMY=" crossorigin="">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/leaflet.draw/1.0.4/leaflet.draw.css">
    <link rel="stylesheet" href="<cfoutput>#request.fpwBase#</cfoutput>/assets/css/dashboard-console.css?v=20260423a">
</head>
<body class="dashboard-body" data-fpw-page="dashboard">

<cfinclude template="../includes/top_nav.cfm">


<main class="dashboard-main">
    <div id="dashboardAlert" class="alert d-none" role="alert"></div>

    <div class="dashboard-grid dashboard-grid--reflow">

        <section class="dashboard-card panel-floatlike full-width mission-summary-panel" id="missionSummaryPanel" aria-labelledby="missionSummaryTitle">
            <div class="card-header">
                <div class="card-title">
                    <h2 id="missionSummaryTitle">Mission Summary</h2>
                    
                </div>
                <div class="card-actions">
                    <small id="missionSummaryUpdatedAt" class="card-subtitle">Updated just now</small>
                </div>
            </div>
            <div class="card-body">
                <div class="mission-summary-grid">
                    <article class="mission-summary-tile">
                        <div class="mission-summary-label">Active Trip</div>
                        <div class="mission-summary-value" id="missionRouteValue">No active trip</div>
                        <div class="mission-summary-meta" id="missionRouteMeta">No active trip is available.</div>
                    </article>
                    <article class="mission-summary-tile">
                        <div class="mission-summary-label">Trip Progress</div>
                        <div class="mission-summary-value" id="missionProgressValue">No data</div>
                        <div class="mission-summary-meta" id="missionProgressMeta">No active trip</div>
                    </article>
                    <article class="mission-summary-tile">
                        <div class="mission-summary-label">Float Plans</div>
                        <div class="mission-summary-value" id="missionFloatPlansValue">No plans</div>
                        <div class="mission-summary-meta" id="missionFloatPlansMeta">0 total</div>
                    </article>
                    <article class="mission-summary-tile">
                        <div class="mission-summary-label">Monitoring</div>
                        <div class="mission-summary-value" id="missionMonitoringValue">Loading…</div>
                        <div class="mission-summary-meta" id="missionMonitoringMeta">Waiting for monitored plans</div>
                    </article>
                    <article class="mission-summary-tile">
                        <div class="mission-summary-label">Weather Risk</div>
                        <div class="mission-summary-value" id="missionWeatherValue">—</div>
                        <div class="mission-summary-meta" id="missionWeatherMeta">Alerts: None</div>
                    </article>
                    <article class="mission-summary-tile">
                        <div class="mission-summary-label">Boat &amp; Trip Setup</div>
                        <div class="mission-summary-value" id="missionSetupValue">0 vessels • 0 contacts</div>
                        <div class="mission-summary-meta" id="missionSetupMeta">0 waypoints • 0 crew</div>
                    </article>
                </div>
            </div>
        </section>

        <section class="dashboard-card panel-floatlike full-width expedition-panel" id="expeditionTimelinePanel" aria-labelledby="expeditionTimelineTitle">
            <div class="card-header">
                <div class="card-title">
                    <h2 id="expeditionTimelineTitle">Routes</h2>
                </div>
                <div class="card-actions">
                    <button type="button" class="btn-primary" id="openRouteBuilderBtn">+ Add</button>
                </div>
            </div>
            <div class="card-body">
                <div id="expeditionTimelineLoading" class="expedition-state mb-3" role="status">Loading expedition timeline...</div>

                <div id="expeditionTimelineUnauthorized" class="expedition-state d-none mb-3" role="alert">
                    Session expired. Please <a href="<cfoutput>#request.fpwBase#</cfoutput>/app/login.cfm">log in</a> to view your expedition timeline.
                </div>

                <div id="expeditionTimelineError" class="expedition-state d-none mb-3" role="alert">
                    <div id="expeditionTimelineErrorText">Unable to load expedition timeline.</div>
                    <button type="button" id="expeditionTimelineRetry" class="btn-secondary mt-2">Retry</button>
                </div>

                <div id="expeditionTimelineBody" class="d-none">
                    <div id="expeditionRouteList" class="expedition-route-list mb-3"></div>
                    <div id="expeditionRouteEmpty" class="expedition-state d-none mb-3">Click <strong>+ Add</strong> to create your first expedition route.</div>
                    <div id="expeditionTimelineAccordion" class="expedition-route-overview"></div>
                </div>
            </div>
        </section>
        
        <section class="dashboard-card panel-floatlike quick-actions-panel" id="quickActionsPanel" aria-labelledby="quickActionsTitle">
            <div class="card-header">
                <div class="card-title">
                    <h2 id="quickActionsTitle">Quick Actions</h2>
                    
                </div>
            </div>
            <div class="card-body">
                <div class="quick-actions-list">
                    <button type="button" class="btn-secondary quick-action-btn" data-quick-action="generate-route">Generate Route</button>
                    <button type="button" class="btn-secondary quick-action-btn" data-quick-action="add-vessel">Add Vessel</button>
                    <button type="button" class="btn-secondary quick-action-btn" data-quick-action="add-contact">Add Contact</button>
                    <button type="button" class="btn-secondary quick-action-btn" data-quick-action="add-operator">Add Operator</button>
                    <button type="button" class="btn-secondary quick-action-btn" data-quick-action="add-waypoint">Add Waypoint</button>
                </div>
            </div>
        </section>

        <section class="dashboard-card panel-floatlike full-width setup-intro-panel" id="boatTripSetupPanel" aria-labelledby="boatTripSetupTitle">
            <div class="card-header">
                <div class="card-title">
                    <h2 id="boatTripSetupTitle">Boat &amp; Trip Setup</h2>
                    <small class="card-subtitle">Support tools remain fully available, now grouped lower on the page.</small>
                </div>
            </div>
            <div class="card-body">
                <p class="setup-intro-copy" id="setupIntroCopy">Current setup totals reflect your existing vessels, contacts, crew, operators, and waypoints.</p>
                <div class="setup-intro-stats">
                    <span id="setupMetricVessels">Vessels: 0</span>
                    <span id="setupMetricContacts">Contacts: 0</span>
                    <span id="setupMetricPassengers">Crew: 0</span>
                    <span id="setupMetricOperators">Operators: 0</span>
                    <span id="setupMetricWaypoints">Waypoints: 0</span>
                </div>
            </div>
        </section>

        

        <section class="dashboard-card panel-floatlike" id="vesselsPanel">
            <div class="card-header">
                <div class="card-title">
                    <h2>Vessels</h2>
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
                    <h2>Contacts</h2>
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
                    <h2>Passengers &amp; Crew</h2>
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
                    <h2>Operators</h2>
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
                    <h2>Waypoints</h2>
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

        <section class="dashboard-card panel-floatlike full-width next-steps-panel" id="recommendedNextStepsPanel" aria-labelledby="recommendedNextStepsTitle">
            <div class="card-header">
                <div class="card-title">
                    <h2 id="recommendedNextStepsTitle">Recommended Next Steps</h2>
                    <small class="card-subtitle">Suggestions are generated from current route, float plan, monitoring, weather, and setup data only.</small>
                </div>
            </div>
            <div class="card-body">
                <div id="nextStepsList" class="next-steps-list"></div>
                <p id="nextStepsEmpty" class="empty d-none">No immediate action items. Your core dashboard setup is in place.</p>
            </div>
        </section>

    </div>
</main>

<div class="modal fade" id="confirmModal" tabindex="-1" aria-labelledby="confirmModalLabel" aria-hidden="true" data-bs-backdrop="static" data-bs-keyboard="false">
    <div class="modal-dialog modal-dialog-centered">
        <div class="modal-content dashboard-card">
            <div class="modal-header card-header">
                <h5 class="modal-title card-title" id="confirmModalLabel">Please Confirm</h5>
                <button type="button" class="btn-close" id="routeBuilderCloseBtn" aria-label="Close"></button>
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
                    <div id="waypointMap" class="waypoint-map-frame"></div>
                    <div class="small text-muted mt-1">Tip: drag the marker or click the map to reposition.</div>
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
                        <input type="text" class="form-control" id="contactPhone" required pattern="^\+?1?\s*(?:\(\d{3}\)|\d{3})[\s.\-]?\d{3}[\s.\-]?\d{4}$" title="Use a valid US phone number">
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
                    <div class="row">
                        <div class="col-md-4 mb-3">
                            <label class="form-label" for="vesselType">Type *</label>
                            <input type="text" class="form-control" id="vesselType" required>
                            <div class="invalid-feedback" id="vesselTypeError"></div>
                        </div>
                        <div class="col-md-4 mb-3">
                            <label class="form-label" for="vesselLength">Length *</label>
                            <input type="text" class="form-control" id="vesselLength" required>
                            <div class="invalid-feedback" id="vesselLengthError"></div>
                        </div>
                        <div class="col-md-4 mb-3">
                            <label class="form-label" for="vesselColor">Hull Color *</label>
                            <input type="text" class="form-control" id="vesselColor" required>
                            <div class="invalid-feedback" id="vesselColorError"></div>
                        </div>
                    </div>
                    <div class="form-check mb-3">
                        <input class="form-check-input" type="checkbox" id="vesselIsDefault">
                        <label class="form-check-label" for="vesselIsDefault">Default Vessel - used for route calculations</label>
                    </div>
                    <div class="mb-3">
                        <label class="form-label" for="vesselRegistration">Registration</label>
                        <input type="text" class="form-control" id="vesselRegistration">
                    </div>
                    <div class="row">
                        <div class="col-md-12 mb-3">
                            <label class="form-label" for="vesselHomePort">Hailing Port</label>
                            <input type="text" class="form-control" id="vesselHomePort">
                        </div>
                    </div>
                    <div class="row">
                        <div class="col-md-3 mb-3">
                            <label class="form-label" for="vesselMaxSpeed">Max Speed (KPH)</label>
                            <input type="number" class="form-control" id="vesselMaxSpeed" min="0" step="0.01" inputmode="decimal">
                        </div>
                        <div class="col-md-3 mb-3">
                            <label class="form-label" for="vesselMostEfficientSpeed">Most Efficient Speed (KPH)</label>
                            <input type="number" class="form-control" id="vesselMostEfficientSpeed" min="0" step="0.01" inputmode="decimal">
                        </div>
                        <div class="col-md-3 mb-3">
                            <label class="form-label" for="vesselGallonsPerHour">GPH@efficient</label>
                            <input type="number" class="form-control" id="vesselGallonsPerHour" min="0" step="0.01" inputmode="decimal">
                        </div>
                        <div class="col-md-3 mb-3">
                            <label class="form-label" for="vesselGphAtMaxSpeed">GPH@max</label>
                            <input type="number" class="form-control" id="vesselGphAtMaxSpeed" min="0" step="0.01" inputmode="decimal">
                        </div>
                    </div>
                    <div class="row">
                        <div class="col-md-4 mb-3">
                            <label class="form-label" for="vesselFuelCapacity">Fuel Capacity (gal)</label>
                            <input type="number" class="form-control" id="vesselFuelCapacity" min="0" step="0.01" inputmode="decimal">
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
                            <p class="small text-muted mb-3">Trip Manifest: choose who is aboard and who receives notifications.</p>
                            <div class="fpw-manifest">
                                <div class="fpw-manifest__summary">
                                    <div class="fpw-manifest__summaryhead">
                                        <h3 class="h6 mb-0">On This Trip</h3>
                                        <button
                                            type="button"
                                            class="btn btn-outline-secondary btn-sm d-md-none"
                                            @click="manifestSummaryOpen = !manifestSummaryOpen"
                                            :aria-expanded="manifestSummaryOpen ? 'true' : 'false'">
                                            {{ manifestSummaryOpen ? 'Hide' : 'Show' }}
                                        </button>
                                    </div>
                                    <div class="fpw-manifest__summarybody" :class="{ 'is-collapsed-mobile': !manifestSummaryOpen }">
                                        <div class="fpw-manifest__group">
                                            <div class="fpw-manifest__grouphead">
                                                <span>Selected Passengers</span>
                                                <span>{{ fp.PASSENGERS.length }}</span>
                                            </div>
                                            <ul v-if="selectedPassengerDetails.length" class="fpw-manifest__selectedlist">
                                                <li v-for="item in selectedPassengerDetails" :key="'sel-passenger-'+item.id">{{ item.label }}</li>
                                            </ul>
                                            <p v-else class="small text-muted mb-0 mt-2">No passengers selected.</p>
                                        </div>

                                        <div class="fpw-manifest__group">
                                            <div class="fpw-manifest__grouphead">
                                                <span>Selected Contacts</span>
                                                <span>{{ fp.CONTACTS.length }}</span>
                                            </div>
                                            <ul v-if="selectedContactDetails.length" class="fpw-manifest__selectedlist">
                                                <li v-for="item in selectedContactDetails" :key="'sel-contact-'+item.id">{{ item.label }}</li>
                                            </ul>
                                            <p v-else class="small text-muted mb-0 mt-2">No contacts selected.</p>
                                        </div>
                                    </div>
                                </div>

                                <div class="fpw-manifest__available">
                                    <h3 class="h6 mb-2">Available Items</h3>
                                    <div class="fpw-manifest__tabs" role="tablist" aria-label="Trip manifest tabs">
                                        <button
                                            type="button"
                                            class="fpw-manifest__tabbtn"
                                            :class="{ 'is-active': manifestActiveTab === 'passengers' }"
                                            role="tab"
                                            :aria-selected="manifestActiveTab === 'passengers' ? 'true' : 'false'"
                                            @click="manifestActiveTab = 'passengers'">
                                            Passengers
                                        </button>
                                        <button
                                            type="button"
                                            class="fpw-manifest__tabbtn"
                                            :class="{ 'is-active': manifestActiveTab === 'contacts' }"
                                            role="tab"
                                            :aria-selected="manifestActiveTab === 'contacts' ? 'true' : 'false'"
                                            @click="manifestActiveTab = 'contacts'">
                                            Contacts
                                        </button>
                                    </div>

                                    <div v-if="manifestActiveTab === 'passengers'" class="fpw-manifest__tabpane" role="tabpanel" aria-label="Passengers list">
                                        <input
                                            type="search"
                                            class="form-control form-control-sm mb-2"
                                            v-model.trim="passengerSearchQuery"
                                            placeholder="Search passengers..."
                                            aria-label="Search passengers">
                                        <div class="fpw-manifest__list" role="listbox" aria-label="Available passengers">
                                            <div
                                                v-for="p in filteredPassengers"
                                                :key="'p-'+p.PASSENGERID"
                                                class="fpw-manifest__row"
                                                :class="{ 'is-selected': isPassengerSelected(p.PASSENGERID) }"
                                                role="button"
                                                tabindex="0"
                                                :aria-pressed="isPassengerSelected(p.PASSENGERID) ? 'true' : 'false'"
                                                @click="togglePassenger(p)"
                                                @keydown.enter.prevent="togglePassenger(p)"
                                                @keydown.space.prevent="togglePassenger(p)">
                                                <span class="fpw-manifest__label">{{ p.PASSENGERNAME || ('Passenger #' + p.PASSENGERID) }}</span>
                                                <span class="fpw-manifest__check" aria-hidden="true">{{ isPassengerSelected(p.PASSENGERID) ? '✓' : '' }}</span>
                                            </div>
                                            <p v-if="!filteredPassengers.length" class="small text-muted mb-0 p-2">No passengers match your search.</p>
                                        </div>
                                    </div>

                                    <div v-else class="fpw-manifest__tabpane" role="tabpanel" aria-label="Contacts list">
                                        <input
                                            type="search"
                                            class="form-control form-control-sm mb-2"
                                            v-model.trim="contactSearchQuery"
                                            placeholder="Search contacts..."
                                            aria-label="Search contacts">
                                        <div class="fpw-manifest__list" role="listbox" aria-label="Available contacts">
                                            <div
                                                v-for="c in filteredContacts"
                                                :key="'c-'+c.CONTACTID"
                                                class="fpw-manifest__row"
                                                :class="{ 'is-selected': isContactSelected(c.CONTACTID) }"
                                                role="button"
                                                tabindex="0"
                                                :aria-pressed="isContactSelected(c.CONTACTID) ? 'true' : 'false'"
                                                @click="toggleContact(c)"
                                                @keydown.enter.prevent="toggleContact(c)"
                                                @keydown.space.prevent="toggleContact(c)">
                                                <span class="fpw-manifest__label">{{ c.CONTACTNAME || ('Contact #' + c.CONTACTID) }}</span>
                                                <span class="fpw-manifest__check" aria-hidden="true">{{ isContactSelected(c.CONTACTID) ? '✓' : '' }}</span>
                                            </div>
                                            <p v-if="!filteredContacts.length" class="small text-muted mb-0 p-2">No contacts match your search.</p>
                                        </div>
                                    </div>
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

                            <p class="small text-muted mb-3">Review the route waypoints attached to this activated route.</p>
                            <div class="fpw-manifest fpw-manifest--waypoints">
                                <div class="fpw-manifest__summary">
                                    <div class="fpw-manifest__summaryhead">
                                        <h3 class="h6 mb-0">In Route ({{ fp.WAYPOINTS.length }})</h3>
                                        <button
                                            type="button"
                                            class="btn btn-outline-secondary btn-sm d-md-none"
                                            @click="mobileWaypointsSummaryOpen = !mobileWaypointsSummaryOpen"
                                            :aria-expanded="mobileWaypointsSummaryOpen ? 'true' : 'false'">
                                            {{ mobileWaypointsSummaryOpen ? 'Hide' : 'Show' }}
                                        </button>
                                    </div>
                                    <div class="fpw-manifest__summarybody" :class="{ 'is-collapsed-mobile': !mobileWaypointsSummaryOpen }">
                                        <ul v-if="selectedWaypointDetails.length" class="fpw-manifest__selectedlist">
                                            <li v-for="item in selectedWaypointDetails" :key="'sel-waypoint-'+item.id">
                                                <span class="me-2">{{ item.position }}</span>{{ item.label }}
                                            </li>
                                        </ul>
                                        <p v-else class="small text-muted mb-0 mt-2">No waypoints selected.</p>
                                    </div>
                                </div>
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
                                <div v-else-if="pdfPreviewUrl" class="border rounded fpw-pdf-preview">
                                    <iframe
                                        :src="pdfPreviewUrl"
                                        title="Float plan PDF preview"
                                        class="w-100 h-100 fpw-pdf-preview-frame"
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

<div class="modal fade" id="routeBuilderModal" tabindex="-1" aria-labelledby="routeBuilderLabel" aria-hidden="true" data-bs-backdrop="static" data-bs-keyboard="false">
    <div class="modal-dialog modal-dialog-scrollable routebuilder-modal-fullwidth">
        <div class="modal-content dashboard-card">
            <div class="modal-body card-body routebuilder-modal-body p-0">
                <h5 id="routeBuilderLabel" class="visually-hidden">Route Generator</h5>
                <cfinclude template="../includes/modals/route_generator_modal.cfm">
            </div>
        </div>
    </div>
</div>

<cfinclude template="../includes/footer_scripts.cfm">

<script src="https://unpkg.com/vue@3/dist/vue.global.prod.js"></script>
<script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js" integrity="sha256-20nQCchB9co0qIjJZRGuk2/Z9VM+kNiyxNV1lvTlZBo=" crossorigin=""></script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/leaflet.draw/1.0.4/leaflet.draw.js"></script>
<script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/maps/leaflet-noaa-waypoint-map.js?v=20260416a"></script>
<script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/app/validate.js?v=20260227c"></script>
<script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/app/floatplanWizard.js?v=20260423a"></script>
<script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/app/dashboard/utils.js?v=20260227c"></script>
<script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/app/dashboard/state.js?v=20260227c"></script>
<script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/app/dashboard/alerts.js?v=20260227c"></script>
<script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/app/dashboard/floatplans.js?v=20260423a"></script>
<script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/app/dashboard/vessels.js?v=20260302a"></script>
<script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/app/dashboard/contacts.js?v=20260301b"></script>
<script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/app/dashboard/passengers.js?v=20260301b"></script>
<script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/app/dashboard/operators.js?v=20260301b"></script>
<script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/app/dashboard/waypoints.js?v=20260301a"></script>
<script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/app/shared/fuel-math.js?v=202603191500a"></script>
<script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/app/dashboard/routebuilder.js?v=20260422b"></script>

<!-- Dashboard-specific JS -->
<script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/app/dashboard.js?v=20260423a"></script>



</body>
</html>
