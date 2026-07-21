<cfprocessingdirective pageencoding="utf-8">
<cfinclude template="../includes/require_auth.cfm">
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
<link rel="stylesheet" href="<cfoutput>#request.fpwBase#</cfoutput>/assets/css/dashboard-console.css?v=20260527-routes-collapse-final">
<link rel="stylesheet" href="<cfoutput>#request.fpwBase#</cfoutput>/assets/css/help-tour.css?v=20260526-cache-bump">
</head>
<body class="dashboard-body" data-fpw-page="dashboard">

<cfset request.fpwTopNavActive = "dashboard">
<cfinclude template="../includes/top_nav.cfm">


<div class="fpw-dashboard-shell fpw-layout-rail">
    <aside class="fpw-dashboard-sidebar" aria-label="Dashboard navigation">
        <a class="fpw-dashboard-brand" href="<cfoutput>#request.fpwBase#</cfoutput>/app/dashboard.cfm">
            <span class="fpw-dashboard-brand-mark" aria-hidden="true">
                <svg viewBox="0 0 32 32" focusable="false">
                    <circle cx="16" cy="16" r="12"></circle>
                    <path d="M16 2v28M2 16h28"></path>
                    <path d="M16 5l4 11-4 11-4-11z"></path>
                    <path d="M5 16l11-4 11 4-11 4z"></path>
                </svg>
            </span>
            <span class="fpw-dashboard-brand-text">
                <span>FloatPlan</span>
                <span>Wizard</span>
            </span>
        </a>

        <nav class="fpw-dashboard-nav" aria-label="Mission Control sections">
            <a class="fpw-dashboard-nav-item is-active" href="<cfoutput>#request.fpwBase#</cfoutput>/app/dashboard.cfm"><span class="fpw-nav-icon" aria-hidden="true"><svg viewBox="0 0 24 24" focusable="false"><path d="M4 13a8 8 0 0 1 16 0"></path><path d="M6 13v4a2 2 0 0 0 2 2h1v-8H8a2 2 0 0 0-2 2z"></path><path d="M18 13v4a2 2 0 0 1-2 2h-1v-8h1a2 2 0 0 1 2 2z"></path></svg></span><span>Dashboard</span></a>
            <a class="fpw-dashboard-nav-item" href="#expeditionTimelinePanel"><span class="fpw-nav-icon" aria-hidden="true"><svg viewBox="0 0 24 24" focusable="false"><circle cx="6" cy="7" r="2.5"></circle><circle cx="18" cy="5" r="2.5"></circle><circle cx="16" cy="18" r="2.5"></circle><path d="M8.4 6.5l7.2-1M7.9 8.7l6.3 7.1M6 9.5v5"></path><circle cx="6" cy="17" r="2.5"></circle></svg></span><span>Routes</span></a>
            <a class="fpw-dashboard-nav-item" href="#expeditionTimelinePanel"><span class="fpw-nav-icon" aria-hidden="true"><svg viewBox="0 0 24 24" focusable="false"><rect x="7" y="4" width="10" height="16" rx="1.8"></rect><path d="M9.5 4a2.5 2.5 0 0 1 5 0M9.5 9h5M9.5 13h5M9.5 17h3"></path></svg></span><span>Float Plans</span></a>
            <a class="fpw-dashboard-nav-item" href="<cfoutput>#request.fpwBase#</cfoutput>/app/monitoring.cfm"><span class="fpw-nav-icon" aria-hidden="true"><svg viewBox="0 0 24 24" focusable="false"><path d="M6 17h12l-1.4-2V10a4.6 4.6 0 0 0-9.2 0v5z"></path><path d="M10 20h4M12 5V3"></path></svg></span><span>Monitoring</span></a>
            <a class="fpw-dashboard-nav-item" href="<cfoutput>#request.fpwBase#</cfoutput>/app/weather.cfm"><span class="fpw-nav-icon" aria-hidden="true"><svg viewBox="0 0 24 24" focusable="false"><path d="M7 16.5H6a3 3 0 1 1 .8-5.9A4.8 4.8 0 0 1 16 12h1a2.5 2.5 0 0 1 0 5h-2"></path><path d="M12 16l-2 3h3l-2 3M4 6l1.5 1.5M12 2v3M20 6l-1.5 1.5"></path></svg></span><span>Weather</span></a>
            <a class="fpw-dashboard-nav-item" href="#vesselsPanel"><span class="fpw-nav-icon" aria-hidden="true"><svg viewBox="0 0 24 24" focusable="false"><path d="M7 18h10l3-5H4z"></path><path d="M9 13V7h6v6M11 7l1-3 1 3M5 20c1.2 0 1.2-1 2.4-1s1.2 1 2.4 1 1.2-1 2.4-1 1.2 1 2.4 1 1.2-1 2.4-1 1.2 1 2.4 1"></path></svg></span><span>Vessels</span></a>
            <a class="fpw-dashboard-nav-item" href="#contactsPanel"><span class="fpw-nav-icon" aria-hidden="true"><svg viewBox="0 0 24 24" focusable="false"><circle cx="9" cy="8" r="3"></circle><path d="M3.5 19a5.5 5.5 0 0 1 11 0"></path><circle cx="17" cy="9" r="2.5"></circle><path d="M14.5 17.2a4.5 4.5 0 0 1 6 1.8"></path></svg></span><span>Contacts</span></a>
            <a class="fpw-dashboard-nav-item" href="#waypointsPanel"><span class="fpw-nav-icon" aria-hidden="true"><svg viewBox="0 0 24 24" focusable="false"><path d="M12 21s7-6.1 7-12a7 7 0 0 0-14 0c0 5.9 7 12 7 12z"></path><circle cx="12" cy="9" r="2.4"></circle></svg></span><span>Waypoints</span></a>
            <a class="fpw-dashboard-nav-item" href="#passengersPanel"><span class="fpw-nav-icon" aria-hidden="true"><svg viewBox="0 0 24 24" focusable="false"><circle cx="8" cy="8" r="2.8"></circle><circle cx="16" cy="8" r="2.8"></circle><path d="M3 19a5 5 0 0 1 10 0M11 19a5 5 0 0 1 10 0"></path></svg></span><span>Crew</span></a>
            <a class="fpw-dashboard-nav-item" href="#operatorsPanel"><span class="fpw-nav-icon" aria-hidden="true"><svg viewBox="0 0 24 24" focusable="false"><circle cx="12" cy="7" r="3"></circle><path d="M6 20a6 6 0 0 1 12 0"></path><path d="M4 14a4 4 0 0 1 4-4M20 14a4 4 0 0 0-4-4"></path></svg></span><span>Operators</span></a>
            <a class="fpw-dashboard-nav-item" href="<cfoutput>#request.fpwBase#</cfoutput>/app/account.cfm"><span class="fpw-nav-icon" aria-hidden="true"><svg viewBox="0 0 24 24" focusable="false"><circle cx="12" cy="12" r="3"></circle><path d="M12 2.5v3M12 18.5v3M4.5 4.5l2.1 2.1M17.4 17.4l2.1 2.1M2.5 12h3M18.5 12h3M4.5 19.5l2.1-2.1M17.4 6.6l2.1-2.1"></path></svg></span><span>Settings</span></a>
            <a class="fpw-dashboard-nav-item" href="#recommendedNextStepsPanel"><span class="fpw-nav-icon" aria-hidden="true"><svg viewBox="0 0 24 24" focusable="false"><circle cx="12" cy="12" r="9"></circle><path d="M9.8 9a2.3 2.3 0 1 1 3.8 1.8c-.9.6-1.6 1.2-1.6 2.4M12 17h.01"></path></svg></span><span>Help</span></a>
            <button type="button" class="fpw-dashboard-nav-item fpw-dashboard-tour-trigger" data-tour-start="dashboard"><span class="fpw-nav-icon" aria-hidden="true"><svg viewBox="0 0 24 24" focusable="false"><path d="M5 5h9a5 5 0 0 1 0 10H9"></path><path d="M9 11 5 15l4 4"></path><path d="M17 5l2-2M20 9h3M18.5 13.5 21 16"></path></svg></span><span>Tour</span></button>
        </nav>
    </aside>

    <main class="fpw-dashboard-main dashboard-main">
        <div id="dashboardAlert" class="alert d-none" role="alert"></div>

        <section class="dashboard-card panel-floatlike mission-summary-panel fpw-planning-context-panel" id="missionSummaryPanel" aria-label="Dashboard planning context">
            <article class="fpw-planning-context-block fpw-planning-context-block--home">
                <span class="fpw-planning-context-icon" aria-hidden="true"><svg viewBox="0 0 24 24" focusable="false"><path d="M12 21s7-6.1 7-12a7 7 0 0 0-14 0c0 5.9 7 12 7 12z"></path><circle cx="12" cy="9" r="2.5"></circle></svg></span>
                <div class="fpw-planning-context-copy">
                    <div class="fpw-planning-context-label">HOME PORT</div>
                    <div class="fpw-planning-context-value" id="planningHomePortValue">No Home Port</div>
                    <div class="fpw-planning-context-meta d-none" id="planningHomePortMeta"></div>
                </div>
            </article>

            <article class="fpw-planning-context-block fpw-planning-context-block--vessel">
                <span class="fpw-planning-context-icon" aria-hidden="true"><svg viewBox="0 0 24 24" focusable="false"><path d="M3 16h18l-2.2 4H5.2L3 16z"></path><path d="M7 16V9h7l3 7"></path><path d="M9 12h4"></path></svg></span>
                <div class="fpw-planning-context-copy">
                    <div class="fpw-planning-context-label">DEFAULT VESSEL</div>
                    <div class="fpw-planning-context-value" id="planningDefaultVesselValue">Not set</div>
                    <div class="fpw-planning-context-meta d-none" id="planningDefaultVesselMeta"></div>
                </div>
            </article>

            <article class="fpw-planning-context-block fpw-planning-context-block--active-route">
                <span class="fpw-planning-context-icon" aria-hidden="true"><svg viewBox="0 0 24 24" focusable="false"><circle cx="6" cy="7" r="2.3"></circle><circle cx="18" cy="5" r="2.3"></circle><circle cx="16" cy="18" r="2.3"></circle><path d="M8.3 6.6l7.4-1M7.8 8.7l6.5 7.1M6 9.5v5"></path><circle cx="6" cy="17" r="2.3"></circle></svg></span>
                <div class="fpw-planning-context-copy">
                    <div class="fpw-planning-context-label">ACTIVE ROUTE</div>
                    <div class="fpw-planning-context-value" id="planningActiveRouteValue">0</div>
                    <div class="fpw-planning-context-meta fpw-planning-context-status d-none" id="planningActiveRouteMeta"><span class="fpw-planning-context-dot" aria-hidden="true"></span>Active</div>
                </div>
            </article>

            <article class="fpw-planning-context-block fpw-planning-context-block--readiness">
                <span class="fpw-planning-context-icon" aria-hidden="true"><svg viewBox="0 0 24 24" focusable="false"><path d="M4 7h3l2 2 4-5"></path><path d="M4 14h3l2 2 4-5"></path><path d="M15 8h5"></path><path d="M15 15h5"></path></svg></span>
                <div class="fpw-planning-context-copy">
                    <div class="fpw-planning-context-label">TRIP SETUP READINESS</div>
                    <div class="fpw-planning-context-value">Review Setup</div>
                    <div class="fpw-planning-context-meta">Use the setup tiles below.</div>
                </div>
            </article>
        </section>

        <section class="dashboard-card panel-floatlike next-steps-panel fpw-dashboard-next-step" id="recommendedNextStepsPanel" aria-labelledby="recommendedNextStepsTitle">
            <div class="fpw-dashboard-next-step-mark" aria-hidden="true"></div>
            <div class="card-body">
                <h2 id="recommendedNextStepsTitle">NEXT STEP</h2>
                <div id="nextStepsList" class="next-steps-list"></div>
                <p id="nextStepsEmpty" class="empty d-none">No immediate action items. Your core dashboard setup is in place.</p>
            </div>
        </section>

        <section class="dashboard-card panel-floatlike expedition-panel fpw-dashboard-section" id="expeditionTimelinePanel" aria-labelledby="expeditionTimelineTitle" data-tour-id="dashboard-route-workspace">
            <div class="card-header">
                <div class="card-title">
                    <h2 id="expeditionTimelineTitle">Routes</h2>
                    <p class="fpw-routes-workspace-subtitle">Create and manage your saved boating routes.</p>
                </div>
                <div class="card-actions">
                    <button type="button" class="btn-secondary" id="toggleRoutesPanelBtn" aria-controls="expeditionTimelinePanelBody" aria-expanded="true">Collapse</button>
                    <button type="button" class="btn-primary" id="openRouteBuilderBtn" data-tour-id="dashboard-create-route">+ Create Route</button>
                </div>
            </div>
            <div class="card-body fpw-dashboard-scroll-body" id="expeditionTimelinePanelBody">
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
                    <div id="expeditionRouteEmpty" class="expedition-state d-none mb-3">Click <strong>+ Create Route</strong> to create your first expedition route.</div>
                    <div id="expeditionTimelineAccordion" class="expedition-route-overview"></div>
                </div>
            </div>
        </section>

        <section class="dashboard-card panel-floatlike setup-intro-panel fpw-dashboard-setup" id="boatTripSetupPanel" aria-labelledby="boatTripSetupTitle">
            <div class="card-header">
                <div class="card-title">
                    <h2 id="boatTripSetupTitle">Boat &amp; Trip Setup</h2>
                </div>
            </div>
            <div class="card-body">
                <p class="setup-intro-copy" id="setupIntroCopy">Current setup totals reflect your existing vessels, contacts, crew, operators, and waypoints.</p>
                <div class="setup-intro-stats fpw-setup-grid">
                    <a class="fpw-setup-tile" href="#vesselsPanel">
                        <span class="fpw-setup-icon fpw-setup-icon-vessels" aria-hidden="true"></span>
                        <span class="fpw-setup-title">Vessels</span>
                        <span class="fpw-setup-value-row"><span class="fpw-setup-value" id="setupMetricVessels">0</span></span>
                        <span class="fpw-setup-copy">Manage your saved vessels</span>
                    </a>
                    <a class="fpw-setup-tile" href="#contactsPanel">
                        <span class="fpw-setup-icon fpw-setup-icon-contacts" aria-hidden="true"></span>
                        <span class="fpw-setup-title">Contacts</span>
                        <span class="fpw-setup-value-row"><span class="fpw-setup-value" id="setupMetricContacts">0</span></span>
                        <span class="fpw-setup-copy">Your trip contacts &amp; groups</span>
                    </a>
                    <a class="fpw-setup-tile" href="#passengersPanel">
                        <span class="fpw-setup-icon fpw-setup-icon-crew" aria-hidden="true"></span>
                        <span class="fpw-setup-title">Crew</span>
                        <span class="fpw-setup-value-row"><span class="fpw-setup-value" id="setupMetricPassengers">0</span></span>
                        <span class="fpw-setup-copy">Crew members on file</span>
                    </a>
                    <a class="fpw-setup-tile" href="#operatorsPanel">
                        <span class="fpw-setup-icon fpw-setup-icon-operators" aria-hidden="true"></span>
                        <span class="fpw-setup-title">Operators</span>
                        <span class="fpw-setup-value-row"><span class="fpw-setup-value" id="setupMetricOperators">0</span></span>
                        <span class="fpw-setup-copy">Designated boat operators</span>
                    </a>
                    <a class="fpw-setup-tile" href="#waypointsPanel">
                        <span class="fpw-setup-icon fpw-setup-icon-waypoints" aria-hidden="true"></span>
                        <span class="fpw-setup-title">Waypoints</span>
                        <span class="fpw-setup-value-row"><span class="fpw-setup-value" id="setupMetricWaypoints">0</span></span>
                        <span class="fpw-setup-copy">Saved locations &amp; markers</span>
                    </a>
                </div>
            </div>
        </section>

        <section class="fpw-dashboard-manage-heading" aria-labelledby="manageSavedItemsTitle">
            <h2 id="manageSavedItemsTitle">Manage Saved Items</h2>
        </section>

        <div class="fpw-dashboard-manage-grid">
            <section class="dashboard-card panel-floatlike fpw-manage-panel" id="vesselsPanel" data-tour-id="dashboard-vessel-setup">
                <div class="card-header">
                    <div class="card-title">
                        <h2>Saved Vessels</h2>
                        <small class="card-subtitle" id="vesselsSummary">Loading...</small>
                    </div>
                    <div class="card-actions">
                        <button class="btn-primary" type="button" id="addVesselBtn">+ Add</button>
                    </div>
                </div>
                <div class="card-body fpw-dashboard-scroll-body">
                    <p id="vesselsMessage" class="empty">Loading vessels...</p>
                    <div id="vesselsList"></div>
                </div>
            </section>

            <section class="dashboard-card panel-floatlike fpw-manage-panel" id="contactsPanel" data-tour-id="dashboard-contacts-setup">
                <div class="card-header">
                    <div class="card-title">
                        <h2>Trip Contacts</h2>
                        <small class="card-subtitle" id="contactsSummary">Loading...</small>
                    </div>
                    <div class="card-actions">
                        <button class="btn-primary" id="addContactBtn">+ Add</button>
                    </div>
                </div>
                <div class="card-body fpw-dashboard-scroll-body">
                    <p id="contactsMessage" class="empty">Loading contacts...</p>
                    <div id="contactsList"></div>
                </div>
            </section>
        </div>

        <div class="fpw-dashboard-manage-grid fpw-dashboard-manage-grid-secondary">
            <section class="dashboard-card panel-floatlike fpw-manage-panel" id="passengersPanel" data-tour-id="dashboard-passengers-setup">
                <div class="card-header">
                    <div class="card-title">
                        <h2>Passengers &amp; Crew</h2>
                        <small class="card-subtitle" id="passengersSummary">Loading...</small>
                    </div>
                    <div class="card-actions">
                        <button class="btn-primary" id="addPassengerBtn">+ Add</button>
                    </div>
                </div>
                <div class="card-body fpw-dashboard-scroll-body">
                    <p id="passengersMessage" class="empty">Loading passengers...</p>
                    <div id="passengersList"></div>
                </div>
            </section>

            <section class="dashboard-card panel-floatlike fpw-manage-panel" id="operatorsPanel" data-tour-id="dashboard-operators-setup">
                <div class="card-header">
                    <div class="card-title">
                        <h2>Operators</h2>
                        <small class="card-subtitle" id="operatorsSummary">Loading...</small>
                    </div>
                    <div class="card-actions">
                        <button class="btn-primary" id="addOperatorBtn">+ Add</button>
                    </div>
                </div>
                <div class="card-body fpw-dashboard-scroll-body">
                    <p id="operatorsMessage" class="empty">Loading operators...</p>
                    <div id="operatorsList"></div>
                </div>
            </section>
        </div>

        <section class="dashboard-card panel-floatlike fpw-manage-panel fpw-waypoints-panel" id="waypointsPanel" data-tour-id="dashboard-waypoints">
            <div class="card-header">
                <div class="card-title">
                    <h2>Waypoints</h2>
                    <small class="card-subtitle" id="waypointsSummary">Loading...</small>
                </div>
                <div class="card-actions">
                    <button class="btn-primary" id="addWaypointBtn">+ Add</button>
                </div>
            </div>
            <div class="card-body fpw-dashboard-scroll-body">
                <p id="waypointsMessage" class="empty">Loading waypoints...</p>
                <div id="waypointsList"></div>
            </div>
        </section>

        <section class="dashboard-card panel-floatlike quick-actions-panel fpw-dashboard-utility-hidden" id="quickActionsPanel" aria-labelledby="quickActionsTitle">
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
    </main>
</div>

<cfinclude template="../includes/footer.cfm">

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

<div class="modal fade" id="followShareModal" tabindex="-1" aria-labelledby="followShareModalLabel" aria-hidden="true">
    <div class="modal-dialog modal-dialog-centered">
        <div class="modal-content dashboard-card fpw-follow-share-modal">
            <div class="modal-header card-header">
                <h5 class="modal-title card-title" id="followShareModalLabel">Share Follow Link</h5>
                <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
            </div>
            <div class="modal-body card-body">
                <p class="fpw-follow-share-copy">Share this public Follow page link with family, friends, or trip contacts.</p>
                <label class="fpw-follow-share-label" for="followShareUrl">Follow Page Link</label>
                <input type="text" class="form-control fpw-follow-share-url" id="followShareUrl" readonly>
                <p class="fpw-follow-share-status" id="followShareStatus" aria-live="polite"></p>
            </div>
            <div class="modal-footer card-footer fpw-follow-share-actions">
                <a class="btn-secondary fpw-follow-share-open" id="followShareOpenLink" href="#" target="_blank" rel="noopener">Open Follow Page</a>
                <a class="btn-secondary fpw-follow-share-sms" id="followShareSmsLink" href="#">Send by Text Message</a>
                <button type="button" class="btn-primary" id="followShareCopyBtn">Copy Link</button>
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
                        <input type="text" class="form-control" id="waypointName" maxlength="45" required>
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
                            <label class="form-label" for="vesselMostEfficientSpeed">Most Efficient (KPH)</label>
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
                                    <div class="invalid-feedback d-block mb-2" v-if="hasError('CONTACTS')">
                                        {{ getError('CONTACTS') }}
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

<div class="modal fade" id="basicFloatPlanModal" tabindex="-1" aria-labelledby="basicFloatPlanLabel" aria-hidden="true" data-bs-backdrop="static" data-bs-keyboard="false">
    <div class="modal-dialog modal-xl modal-dialog-scrollable">
        <div class="modal-content dashboard-card">
            <div class="modal-header card-header">
                <h5 class="modal-title card-title" id="basicFloatPlanLabel">Basic Float Plan</h5>
                <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
            </div>
            <div class="modal-body card-body">
                <div id="basicFloatPlanMessage" class="alert d-none" role="status"></div>
                <div id="basicFloatPlanSentState" class="fpw-basic-sent-state d-none" aria-live="polite">
                    <h3>Basic Float Plan Sent</h3>
                    <p>Your one-day float plan has been sent. Basic monitoring is active.</p>
                    <p class="fpw-basic-upgrade-note">Upgrade to Premium for saved routes, Active Cruise, Follow Page sharing, multi-day trips, and advanced monitoring.</p>
                </div>

                <form id="basicFloatPlanForm" class="fpw-basic-floatplan-form" novalidate>
                    <input type="hidden" id="basicFloatPlanId" value="0">

                    <section class="fpw-basic-form-section" aria-labelledby="basicFloatPlanBasicsTitle">
                        <div class="fpw-basic-form-heading">
                            <h3 id="basicFloatPlanBasicsTitle">Trip basics</h3>
                            <p>Create a route-less, one-day Basic float plan. This does not create a saved route.</p>
                        </div>
                        <div class="row">
                            <div class="col-lg-6 mb-3">
                                <label class="form-label" for="basicPlanName">Float plan name *</label>
                                <input type="text" class="form-control" id="basicPlanName" required>
                                <div class="invalid-feedback">Float plan name is required.</div>
                            </div>
                            <div class="col-lg-3 mb-3">
                                <label class="form-label" for="basicPlanVesselName">Vessel name *</label>
                                <input type="text" class="form-control" id="basicPlanVesselName" maxlength="255" required>
                                <div class="invalid-feedback">Enter the vessel name.</div>
                            </div>
                            <div class="col-lg-3 mb-3">
                                <label class="form-label" for="basicPlanOperatorName">Operator name *</label>
                                <input type="text" class="form-control" id="basicPlanOperatorName" maxlength="255" required>
                                <div class="invalid-feedback">Enter the operator name.</div>
                            </div>
                        </div>

                        <div class="row">
                            <div class="col-lg-3 mb-3">
                                <label class="form-label" for="basicPlanCaptainName">Captain name *</label>
                                <input type="text" class="form-control" id="basicPlanCaptainName" maxlength="255" required>
                                <div class="invalid-feedback">Enter the captain name.</div>
                            </div>
                            <div class="col-lg-3 mb-3">
                                <label class="form-label" for="basicPlanEmail">Captain email *</label>
                                <input type="email" class="form-control" id="basicPlanEmail" autocomplete="email" required>
                                <div class="invalid-feedback">Enter an email address.</div>
                            </div>
                            <div class="col-lg-3 mb-3">
                                <label class="form-label" for="basicAuthorityId">Official Emergency Authority *</label>
                                <select class="form-select" id="basicAuthorityId" required>
                                    <option value="">Loading authorities...</option>
                                </select>
                                <div class="invalid-feedback">Select an official emergency authority.</div>
                            </div>
                            <div class="col-lg-3 mb-3">
                                <label class="form-label" for="basicRescuePhone">Authority phone</label>
                                <input type="tel" class="form-control" id="basicRescuePhone" inputmode="tel" readonly aria-readonly="true">
                                <div class="form-text">Phone is set from the selected authority.</div>
                            </div>
                        </div>
                    </section>

                    <section class="fpw-basic-form-section" aria-labelledby="basicFloatPlanTimingTitle">
                        <div class="fpw-basic-form-heading">
                            <h3 id="basicFloatPlanTimingTitle">Same-day timing</h3>
                            <p>Basic float plans are limited to trips up to 24 hours.</p>
                        </div>
                        <div class="row">
                            <div class="col-lg-6 mb-3">
                                <label class="form-label" for="basicDepartingFrom">Home port / launch location *</label>
                                <input type="text" class="form-control" id="basicDepartingFrom" required>
                                <div class="invalid-feedback">Enter the launch location.</div>
                            </div>
                            <div class="col-lg-6 mb-3">
                                <label class="form-label" for="basicDestination">Destination / turnaround point *</label>
                                <input type="text" class="form-control" id="basicDestination" required>
                                <div class="invalid-feedback">Enter the destination / turnaround point.</div>
                                <div class="form-text">Return to launch is implied.</div>
                            </div>
                        </div>
                        <div class="row">
                            <div class="col-lg-3 mb-3">
                                <label class="form-label" for="basicDepartureTime">Departure time *</label>
                                <input type="datetime-local" class="form-control" id="basicDepartureTime" required>
                                <div class="invalid-feedback">Enter a departure time.</div>
                            </div>
                            <div class="col-lg-3 mb-3">
                                <label class="form-label" for="basicDepartureTimezone">Departure timezone *</label>
                                <select class="form-select" id="basicDepartureTimezone" required></select>
                                <div class="invalid-feedback">Select a departure timezone.</div>
                            </div>
                            <div class="col-lg-3 mb-3">
                                <label class="form-label" for="basicReturnTime">Return time *</label>
                                <input type="datetime-local" class="form-control" id="basicReturnTime" required>
                                <div class="invalid-feedback">Return must be after departure and within 24 hours.</div>
                            </div>
                            <div class="col-lg-3 mb-3">
                                <label class="form-label" for="basicReturnTimezone">Return timezone *</label>
                                <select class="form-select" id="basicReturnTimezone" required></select>
                                <div class="invalid-feedback">Select a return timezone.</div>
                            </div>
                        </div>
                    </section>

                    <section class="fpw-basic-form-section" aria-labelledby="basicFloatPlanStopsTitle">
                        <div class="fpw-basic-form-heading">
                            <h3 id="basicFloatPlanStopsTitle">Passengers and notification</h3>
                            <p>Passengers are optional. Enter one notification contact.</p>
                        </div>
                        <div class="row">
                            <div class="col-lg-6 mb-3">
                                <label class="form-label">Passengers</label>
                                <div class="fpw-basic-options-list" id="basicPassengerOptions">
                                    <p class="fpw-basic-options-empty">Loading passengers...</p>
                                </div>
                            </div>
                            <div class="col-lg-6 mb-3">
                                <label class="form-label" for="basicContactName">Notification contact name *</label>
                                <input type="text" class="form-control mb-2" id="basicContactName" maxlength="255" required>
                                <label class="form-label" for="basicContactEmail">Notification contact email *</label>
                                <input type="email" class="form-control mb-2" id="basicContactEmail" autocomplete="email" required>
                                <label class="form-label" for="basicContactPhone">Notification contact phone</label>
                                <input type="tel" class="form-control" id="basicContactPhone" inputmode="tel" maxlength="45">
                                <div class="invalid-feedback d-block d-none" id="basicContactError">
                                    Enter a notification contact name and valid email.
                                </div>
                            </div>
                        </div>
                        <div class="mb-3">
                            <label class="form-label" for="basicNotes">Notes</label>
                            <textarea class="form-control" id="basicNotes" rows="3"></textarea>
                        </div>
                    </section>
                </form>
            </div>
            <div class="modal-footer card-footer fpw-basic-modal-footer">
                <button type="button" class="btn-secondary" data-bs-dismiss="modal">Cancel</button>
                <button type="button" class="btn-secondary" id="basicFloatPlanSaveBtn">Save Draft</button>
                <button type="button" class="btn-primary" id="basicFloatPlanSendBtn">Save &amp; Send</button>
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
<script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/maps/leaflet-noaa-waypoint-map.js?v=20260526-cache-bump"></script>
<script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/app/validate.js?v=20260526-cache-bump"></script>
<script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/app/floatplanWizard.js?v=20260526-cache-bump"></script>
<script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/app/dashboard/utils.js?v=20260526-cache-bump"></script>
<script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/app/dashboard/state.js?v=20260526-cache-bump"></script>
<script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/app/dashboard/alerts.js?v=20260526-cache-bump"></script>
<script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/app/dashboard/floatplans.js?v=20260526-cache-bump"></script>
<script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/app/dashboard/vessels.js?v=20260526-cache-bump"></script>
<script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/app/dashboard/contacts.js?v=20260526-cache-bump"></script>
<script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/app/dashboard/passengers.js?v=20260526-cache-bump"></script>
<script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/app/dashboard/operators.js?v=20260526-cache-bump"></script>
<script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/app/dashboard/waypoints.js?v=20260526-cache-bump"></script>
<script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/app/shared/fuel-math.js?v=20260526-cache-bump"></script>
<script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/app/dashboard/basic-floatplan.js?v=20260526-cache-bump"></script>
<script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/app/dashboard/routebuilder.js?v=20260526-cache-bump"></script>
<script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/app/dashboard/route-generator-tour.js?v=20260526-cache-bump"></script>
<script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/app/help-tour.js?v=20260526-cache-bump"></script>

<!-- Dashboard-specific JS -->
<script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/app/dashboard.js?v=20260527-routes-collapse-js"></script>

</body>
</html>
