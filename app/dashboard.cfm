<!DOCTYPE html>
<!-- Updated to host the float plan wizard inside a Bootstrap modal. -->
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Dashboard - Float Plan Wizard</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">

    <cfinclude template="/fpw/includes/header_styles.cfm">
    <link rel="stylesheet" href="/fpw/assets/css/dashboard-console.css?v=1">

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

        @media (max-width: 768px) {
            .wizard-container {
                margin: 1rem;
                padding: 1rem;
            }
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
            <div class="weather">
                <strong>New Port Richey, FL</strong><br />
                ☀️ 76°F • Winds NE 8kt<br />
                Seas: 1–2 ft
            </div>
            <div class="header-actions">
                <a href="/fpw/app/account.cfm">Account</a>
                <button id="logoutButton">Logout</button>
            </div>
        </div>
    </div>
</header>

<main class="dashboard-main">
    <div id="dashboardAlert" class="alert d-none" role="alert"></div>

    <div class="dashboard-grid">

        
        <section class="dashboard-card alerts-panel" aria-label="System Alerts">
            <div class="card-header">
                <div class="card-title">
                <h2><span class="status-dot status-ok"></span>System Alerts</h2>
                <small class="card-subtitle" id="alertsSummary">Nominal</small>
                </div>
            </div>

            <div class="card-body" id="alertsBody">
                <div class="alert-tile alert-info">
                <div class="alert-top">
                    <span class="alert-dot"></span>
                    <div class="alert-name">Weather</div>
                    <div class="alert-time numeric">Now</div>
                </div>
                <div class="alert-text">No marine alerts. Wind NE 8kt • Seas 1–2ft.</div>
                </div>

                <div class="alert-tile alert-warn">
                <div class="alert-top">
                    <span class="alert-dot"></span>
                    <div class="alert-name">Data</div>
                    <div class="alert-time numeric">Action</div>
                </div>
                <div class="alert-text">2 contacts missing phone numbers.</div>
                </div>

                <div class="alert-tile alert-danger">
                <div class="alert-top">
                    <span class="alert-dot"></span>
                    <div class="alert-name">Check-in</div>
                    <div class="alert-time numeric">Overdue</div>
                </div>
                <div class="alert-text">Active float plan is past return time.</div>
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
                <p id="floatPlansMessage" class="empty">Loading float plans…</p>
                <div id="floatPlansList"></div>
            </div>
            <div class="card-footer">
                <button class="btn-secondary" type="button" id="viewAllFloatPlansBtn">View All</button>
            </div>
        </section>

        

        <section class="dashboard-card">
            <div class="card-header">
                <h2>Vessels</h2>
                <button class="btn-primary">+ Add</button>
            </div>
            <div class="card-body">
                <div class="list-item">
                    <div>
                        Sea Ray 320<br />
                        <small>Registration: FL1234AB</small>
                    </div>
                    <div>
                        <button class="btn-secondary">Edit</button>
                        <button class="btn-danger">Delete</button>
                    </div>
                </div>
            </div>
        </section>

        <section class="dashboard-card">
            <div class="card-header">
                <h2>Contacts</h2>
                <button class="btn-primary">+ Add</button>
            </div>
            <div class="card-body">
                <div class="list-item">
                    <div>
                        Abbe Wald<br />
                        <small>Emergency Contact</small>
                    </div>
                    <div>
                        <button class="btn-secondary">Edit</button>
                        <button class="btn-danger">Delete</button>
                    </div>
                </div>
            </div>
        </section>

        <section class="dashboard-card">
            <div class="card-header">
                <h2>Passengers &amp; Crew</h2>
                <button class="btn-primary">+ Add</button>
            </div>
            <div class="card-body">
                <div class="list-item">
                    <div>
                        John Smith<br />
                        <small>Crew</small>
                    </div>
                    <div>
                        <button class="btn-secondary">Edit</button>
                        <button class="btn-danger">Delete</button>
                    </div>
                </div>
            </div>
        </section>

        <section class="dashboard-card">
            <div class="card-header">
                <h2>Operators</h2>
                <button class="btn-primary">+ Add</button>
            </div>
            <div class="card-body">
                <p class="empty">No operators defined.</p>
            </div>
        </section>

        <section class="dashboard-card full-width">
            <div class="card-header">
                <h2>Waypoints</h2>
                <button class="btn-primary">+ Add</button>
            </div>
            <div class="card-body">
                <div class="list-item">
                    <div>
                        Anclote Key<br />
                        <small>28.178°N, 82.838°W</small>
                    </div>
                    <div>
                        <button class="btn-secondary">Edit</button>
                        <button class="btn-danger">Delete</button>
                    </div>
                </div>
            </div>
        </section>

        


    </div>
</main>

<div class="modal fade" id="floatPlanWizardModal" tabindex="-1" aria-labelledby="floatPlanWizardLabel" aria-hidden="true">
    <div class="modal-dialog modal-xl modal-dialog-scrollable">
        <div class="modal-content">
            <div class="modal-header">
                <h5 class="modal-title" id="floatPlanWizardLabel">Float Plan Wizard</h5>
                <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
            </div>
            <div class="modal-body wizard-body">
                <div id="wizardApp" class="wizard-container" data-init="manual">

                    <div v-if="isLoading" class="text-center py-5">
                        <div class="spinner-border text-primary" role="status"></div>
                        <p class="mt-3 mb-0">Loading wizard…</p>
                    </div>

                    <template v-else>
                        <form id="floatplanWizardForm" novalidate @submit.prevent>
                            <div class="wizard-steps mb-3">
                            <span v-for="n in totalSteps"
                                  :key="'step-badge-' + n"
                                  class="badge"
                                  :class="n === step ? 'bg-primary' : 'bg-secondary'">
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
                                <button type="button" class="btn btn-primary btn-sm" v-if="step < totalSteps" :disabled="isSaving" @click="nextStep">
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
                                <h2 class="h5 mb-0">Step 4 – Passengers & Crew</h2>
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
                        </section>

                        <!-- Step 5 -->
                        <section v-if="step === 5">
                            <div class="d-flex justify-content-between align-items-center mb-3">
                                <h2 class="h5 mb-0">Step 5 – Contacts</h2>
                                <button type="button" class="btn btn-primary btn-sm" v-if="step < totalSteps" :disabled="isSaving" @click="nextStep">
                                    {{ nextButtonLabel }}
                                </button>
                            </div>
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
                        </section>

                        <!-- Step 6 -->
                        <section v-if="step === 6">
                            <div class="d-flex justify-content-between align-items-center mb-3">
                                <h2 class="h5 mb-0">Step 6 – Waypoints</h2>
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

                        <!-- Step 7 -->
                        <section v-if="step === 7">
                            <h2 class="h5 mb-3">Step 7 – Review</h2>

                            <h3 class="h6">Review</h3>
                            <ul class="list-group small mb-3">
                                <li class="list-group-item"><strong>Plan:</strong> {{ fp.FLOATPLAN.NAME || '(no name)' }}</li>
                                <li class="list-group-item"><strong>Vessel:</strong> {{ currentVesselName }}</li>
                                <li class="list-group-item"><strong>Operator:</strong> {{ currentOperatorName }}</li>
                                <li class="list-group-item">
                                    <strong>Depart:</strong>
                                    {{ fp.FLOATPLAN.DEPARTING_FROM || '—' }},
                                    {{ fp.FLOATPLAN.DEPARTURE_TIME || '—' }}
                                    ({{ fp.FLOATPLAN.DEPARTURE_TIMEZONE || 'N/A' }})
                                </li>
                                <li class="list-group-item">
                                    <strong>Return:</strong>
                                    {{ fp.FLOATPLAN.RETURNING_TO || '—' }},
                                    {{ fp.FLOATPLAN.RETURN_TIME || '—' }}
                                    ({{ fp.FLOATPLAN.RETURN_TIMEZONE || 'N/A' }})
                                </li>
                                <li class="list-group-item">
                                    <strong>Passengers:</strong>
                                    <span v-if="fp.PASSENGERS.length === 0">(none)</span>
                                    <span v-else>{{ passengerSummary }}</span>
                                </li>
                                <li class="list-group-item">
                                    <strong>Contacts:</strong>
                                    <span v-if="fp.CONTACTS.length === 0">(none)</span>
                                    <span v-else>{{ contactSummary }}</span>
                                </li>
                                <li class="list-group-item">
                                    <strong>Waypoints:</strong>
                                    <span v-if="fp.WAYPOINTS.length === 0">(none)</span>
                                    <span v-else>{{ waypointSummary }}</span>
                                </li>
                            </ul>

                            <div class="d-flex gap-2 mb-3" v-if="fp.FLOATPLAN.FLOATPLANID">
                                <button type="button" class="btn btn-outline-danger w-100" @click="confirmDelete" :disabled="isSaving">
                                    Delete Float Plan
                                </button>
                            </div>

                            <button type="button" class="btn btn-primary w-100" @click="submitPlan" :disabled="isSaving">
                                {{ isSaving ? 'Saving…' : 'Save Float Plan' }}
                            </button>
                        </section>

                        <div class="wizard-nav">
                            <button type="button" class="btn btn-outline-secondary" :disabled="step === 1 || isSaving" @click="prevStep">
                                Back
                            </button>
                            <button type="button" class="btn btn-primary" v-if="step < totalSteps" :disabled="isSaving" @click="nextStep">
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

<cfinclude template="/fpw/includes/footer_scripts.cfm">

<script src="https://unpkg.com/vue@3/dist/vue.global.prod.js"></script>
<script src="/fpw/assets/js/app/validate.js"></script>
<script src="/fpw/assets/js/app/floatplanWizard.js"></script>

<!-- Dashboard-specific JS -->
<script src="/fpw/assets/js/app/dashboard.js"></script>



</body>
</html>
