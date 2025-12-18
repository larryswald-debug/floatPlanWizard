<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Float Plan Wizard</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">

    <cfinclude template="/fpw/includes/header_styles.cfm">

    <style>
        body.wizard-body {
            background: #f4f6f8;
            min-height: 100vh;
            color: #212529;
        }

        .wizard-header {
            background: linear-gradient(135deg, #0d6efd, #0b5ed7);
            color: #fff;
            padding: 1rem;
            box-shadow: 0 2px 8px rgba(0,0,0,0.15);
        }

        .wizard-header .title {
            font-size: 1.35rem;
            margin: 0;
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
<body class="wizard-body">

<header class="wizard-header">
    <div class="d-flex justify-content-between align-items-center">
        <div>
            <h1 class="title mb-0">Float Plan Wizard</h1>
            <small>Create or update a float plan in four quick steps.</small>
        </div>
        <div>
            <a href="/fpw/app/dashboard.cfm" class="btn btn-outline-light btn-sm">Back to Dashboard</a>
        </div>
    </div>
</header>

<main>
    <div id="wizardApp" class="wizard-container">

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
                <h2 class="h5 mb-3">Step 1 – Basics</h2>

                <div class="mb-3">
                    <label class="form-label">Float Plan Name *</label>
                    <input type="text" class="form-control" v-model="fp.FLOATPLAN.NAME" placeholder="Weekend Cruise" required aria-required="true">
                </div>

                <div class="mb-3">
                    <label class="form-label">Vessel *</label>
                    <select class="form-select" v-model.number="fp.FLOATPLAN.VESSELID">
                        <option :value="0">Select vessel</option>
                        <option v-for="v in vessels" :key="v.VESSELID" :value="v.VESSELID">
                            {{ v.VESSELNAME }} &mdash; {{ v.HOMEPORT || 'Unknown port' }}
                        </option>
                    </select>
                </div>

                <div class="mb-3">
                    <label class="form-label">Operator *</label>
                    <select class="form-select" v-model.number="fp.FLOATPLAN.OPERATORID">
                        <option :value="0">Select operator</option>
                        <option v-for="o in operators" :key="o.OPERATORID" :value="o.OPERATORID">
                            {{ o.OPERATORNAME }}
                        </option>
                    </select>
                </div>

                <div class="form-check mb-3">
                    <input class="form-check-input" type="checkbox" id="operatorPfd" v-model="fp.FLOATPLAN.OPERATOR_HAS_PFD">
                    <label class="form-check-label" for="operatorPfd">Operator has PFD</label>
                </div>
            </section>

            <!-- Step 2 -->
            <section v-if="step === 2">
                <h2 class="h5 mb-3">Step 2 – Times & Route</h2>

                <div class="mb-3">
                    <label class="form-label">Departing From *</label>
                    <input type="text" class="form-control" v-model="fp.FLOATPLAN.DEPARTING_FROM">
                </div>

                <div class="mb-3">
                    <label class="form-label">Departure Date & Time *</label>
                    <input type="datetime-local" class="form-control" v-model="fp.FLOATPLAN.DEPARTURE_TIME">
                </div>

                <div class="mb-3">
                    <label class="form-label">Departure Time Zone *</label>
                    <select class="form-select" v-model="fp.FLOATPLAN.DEPARTURE_TIMEZONE">
                        <option value="">Select time zone</option>
                        <option v-for="tz in timezones" :key="'dep-'+tz" :value="tz">{{ tz }}</option>
                    </select>
                </div>

                <div class="mb-3">
                    <label class="form-label">Returning To *</label>
                    <input type="text" class="form-control" v-model="fp.FLOATPLAN.RETURNING_TO">
                </div>

                <div class="mb-3">
                    <label class="form-label">Return Date & Time *</label>
                    <input type="datetime-local" class="form-control" v-model="fp.FLOATPLAN.RETURN_TIME">
                </div>

                <div class="mb-3">
                    <label class="form-label">Return Time Zone *</label>
                    <select class="form-select" v-model="fp.FLOATPLAN.RETURN_TIMEZONE">
                        <option value="">Select time zone</option>
                        <option v-for="tz in timezones" :key="'ret-'+tz" :value="tz">{{ tz }}</option>
                    </select>
                </div>
            </section>

            <!-- Step 3 -->
            <section v-if="step === 3">
                <h2 class="h5 mb-3">Step 3 – People & Safety</h2>

                <div class="mb-3">
                    <label class="form-label">Email (while underway)</label>
                    <input type="email" class="form-control" v-model="fp.FLOATPLAN.EMAIL">
                </div>

                <div class="mb-3">
                    <label class="form-label">Select Rescue Authority (optional)</label>
                    <select class="form-select" v-model="selectedRescueCenterId" @change="handleRescueCenterSelection">
                        <option value="0">Select a rescue center</option>
                        <option v-for="center in rescueCenters" :key="'resc-'+center.recId" :value="center.recId">
                            {{ formatRescueCenterLabel(center) }}
                        </option>
                    </select>
                    <div class="form-text">
                        Choosing a center will prefill the authority name and phone, but you can still edit the fields manually (manual edits will clear the dropdown selection).
                    </div>
                </div>

                <div class="mb-3">
                    <label class="form-label">Rescue Authority *</label>
                    <input type="text" class="form-control" v-model="fp.FLOATPLAN.RESCUE_AUTHORITY">
                </div>

                <div class="mb-3">
                    <label class="form-label">Rescue Authority Phone *</label>
                    <input type="text" class="form-control" v-model="fp.FLOATPLAN.RESCUE_AUTHORITY_PHONE">
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
                <h2 class="h5 mb-3">Step 4 – Passengers & Crew</h2>
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
                <h2 class="h5 mb-3">Step 5 – Contacts</h2>
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
                <h2 class="h5 mb-3">Step 6 – Waypoints</h2>

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
</main>

<cfinclude template="/fpw/includes/footer_scripts.cfm">

<script src="https://unpkg.com/vue@3/dist/vue.global.prod.js"></script>
<script src="/fpw/assets/js/app/validate.js"></script>
<script src="/fpw/assets/js/app/floatplanWizard.js"></script>

</body>
</html>
