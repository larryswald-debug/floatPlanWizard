<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Dashboard - Mobile App</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">

    <cfinclude template="/fpw/includes/header_styles.cfm">
</head>
<body class="bg-light">

<nav class="navbar navbar-expand-lg navbar-dark bg-primary mb-3">
    <div class="container-fluid">
        <div class="ms-auto d-flex gap-2">
            <a class="btn btn-outline-light btn-sm" href="/fpw/app/account.cfm">Account</a>
            <button class="btn btn-outline-light btn-sm" id="logoutButton">Logout</button>
        </div>

    </div>
</nav>

<div class="container mt-3">
    <div class="row">
        <div class="col-12">

            <div id="dashboardAlert" class="alert d-none" role="alert"></div>

            <div class="card shadow-sm">
                <div class="card-body">
                    <h1 class="h4 mb-3">Dashboard</h1>

                    <p class="text-muted small mb-3">
                        This page is protected and only visible when logged in.
                    </p>

                    <div id="userInfo">
                        <!-- JS will fill this with the current user -->
                        <p class="mb-1">
                            <strong>Name:</strong> <span id="userName">Loading…</span>
                        </p>
                        <p class="mb-0">
                            <strong>Email:</strong> <span id="userEmail">Loading…</span>
                        </p>
                    </div>
                </div>
            </div>

        </div>
    </div>
</div>




<cfinclude template="/fpw/includes/footer_scripts.cfm">

<!-- Dashboard-specific JS -->
<script src="/fpw/assets/js/app/dashboard.js"></script>

</body>
</html>
