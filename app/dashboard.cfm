<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Dashboard - Float Plan Wizard</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">

    <cfinclude template="/fpw/includes/header_styles.cfm">

    <style>
        :root {
            --bg: #f4f6f8;
            --card: #ffffff;
            --primary: #0d6efd;
            --secondary: #6c757d;
            --success: #198754;
            --danger: #dc3545;
            --border: #e0e0e0;
            --text: #212529;
        }

        body.dashboard-body {
            margin: 0;
            background: var(--bg);
            color: var(--text);
            font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
            min-height: 100vh;
        }

        .dashboard-header {
            position: sticky;
            top: 0;
            z-index: 10;
            background: linear-gradient(135deg, #0d6efd, #0b5ed7);
            color: #fff;
            padding: 1rem 1.5rem;
            box-shadow: 0 2px 6px rgba(0,0,0,0.15);
        }

        .dashboard-header .header-grid {
            display: grid;
            grid-template-columns: 2fr 1fr;
            gap: 1rem;
            align-items: center;
        }

        .dashboard-header .user-info h1 {
            margin: 0;
            font-size: 1.4rem;
        }

        .dashboard-header .user-info small {
            opacity: 0.85;
        }

        .header-meta {
            display: flex;
            flex-direction: column;
            align-items: flex-end;
            gap: 0.75rem;
        }

        .dashboard-body button {
            border: none;
            border-radius: 8px;
            padding: 0.4rem 0.75rem;
            font-size: 0.85rem;
            cursor: pointer;
        }

        .weather {
            width: 100%;
            background: rgba(255,255,255,0.15);
            padding: 0.75rem;
            border-radius: 8px;
            text-align: right;
            font-size: 0.9rem;
        }

        .header-actions {
            display: flex;
            gap: 0.5rem;
        }

        .header-actions a,
        .header-actions button {
            border: 1px solid rgba(255,255,255,0.5);
            color: #fff;
            background: transparent;
            border-radius: 8px;
            padding: 0.35rem 0.85rem;
            font-size: 0.85rem;
            text-decoration: none;
            display: inline-flex;
            align-items: center;
            justify-content: center;
            transition: background 0.2s ease;
        }

        .header-actions a:hover,
        .header-actions button:hover {
            background: rgba(255,255,255,0.15);
        }

        main.dashboard-main {
            padding: 1.5rem;
        }

        #dashboardAlert {
            margin-bottom: 1rem;
        }

        .dashboard-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(320px, 1fr));
            gap: 1.25rem;
        }

        .dashboard-card {
            background: var(--card);
            border-radius: 14px;
            box-shadow: 0 8px 20px rgba(0,0,0,0.05);
            display: flex;
            flex-direction: column;
            min-height: 260px;
        }

        .dashboard-card .card-header {
            padding: 1rem 1.25rem;
            border-bottom: 1px solid var(--border);
            display: flex;
            justify-content: space-between;
            align-items: center;
        }

        .dashboard-card .card-header h2 {
            margin: 0;
            font-size: 1.1rem;
        }

        .card-actions button {
            margin-left: 0.35rem;
        }

        .dashboard-card .card-body {
            padding: 1rem 1.25rem;
            flex: 1;
            overflow-y: auto;
        }

        .dashboard-card .card-footer {
            padding: 0.75rem 1.25rem;
            border-top: 1px solid var(--border);
            text-align: right;
        }

        .dashboard-body .btn-primary { background: var(--primary); color: #fff; }
        .dashboard-body .btn-secondary { background: var(--secondary); color: #fff; }
        .dashboard-body .btn-danger { background: var(--danger); color: #fff; }

        .list-item {
            padding: 0.5rem 0;
            border-bottom: 1px dashed var(--border);
            display: flex;
            justify-content: space-between;
            gap: 0.5rem;
        }

        .list-item:last-child {
            border-bottom: none;
        }

        .list-item small {
            color: var(--secondary);
        }

        .empty {
            color: var(--secondary);
            font-style: italic;
        }

        @media (max-width: 768px) {
            .dashboard-header .header-grid {
                grid-template-columns: 1fr;
                text-align: center;
            }

            .header-meta {
                align-items: center;
            }

            .weather {
                text-align: center;
            }

            .header-actions {
                justify-content: center;
                flex-wrap: wrap;
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

        <section class="dashboard-card">
            <div class="card-header">
                <h2>Float Plans</h2>
                <div class="card-actions">
                    <button class="btn-primary">+ Add</button>
                </div>
            </div>
            <div class="card-body">
                <div class="list-item">
                    <div>
                        Chesapeake Bay Run<br />
                        <small>Active • 3 waypoints</small>
                    </div>
                    <div>
                        <button class="btn-secondary">Edit</button>
                        <button class="btn-danger">Delete</button>
                    </div>
                </div>
                <div class="list-item">
                    <div>
                        Gulf Weekend Trip<br />
                        <small>Draft</small>
                    </div>
                    <div>
                        <button class="btn-secondary">Edit</button>
                        <button class="btn-danger">Delete</button>
                    </div>
                </div>
            </div>
            <div class="card-footer">
                <button class="btn-secondary">View All</button>
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

        <section class="dashboard-card">
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

<cfinclude template="/fpw/includes/footer_scripts.cfm">

<!-- Dashboard-specific JS -->
<script src="/fpw/assets/js/app/dashboard.js"></script>

</body>
</html>
