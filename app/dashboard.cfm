<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Dashboard - Float Plan Wizard</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">

    <cfinclude template="/fpw/includes/header_styles.cfm">
    <cfinclude template="/fpw/includes/floatplan-wizard-styles.cfm">
    <link rel="stylesheet" href="/fpw/assets/css/dashboard-console.css?v=1">

   
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

<div class="modal fade" id="floatPlanWizardModal" tabindex="-1" aria-hidden="true">
    <div class="modal-dialog modal-xl modal-fullscreen-lg-down modal-dialog-centered">
        <div class="modal-content">
            <div class="modal-header">
                <h5 class="modal-title">Float Plan</h5>
                <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
            </div>
            <div class="modal-body">
                <cfset wizardShellClasses = "wizard-shell wizard-shell-embedded">
                <cfset wizardAutoInit = false>
                <cfinclude template="/fpw/includes/floatplan-wizard-content.cfm">
            </div>
        </div>
    </div>
</div>

<cfinclude template="/fpw/includes/footer_scripts.cfm">

<!-- Dashboard-specific JS -->
<script src="https://unpkg.com/vue@3/dist/vue.global.prod.js"></script>
<script src="/fpw/assets/js/app/validate.js"></script>
<script src="/fpw/assets/js/app/floatplanWizard.js"></script>
<script src="/fpw/assets/js/app/dashboard.js"></script>



</body>
</html>
