<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Account Settings</title>
  <meta name="viewport" content="width=device-width, initial-scale=1">

  <cfinclude template="../includes/header_styles.cfm">
  <link rel="stylesheet" href="<cfoutput>#request.fpwBase#</cfoutput>/assets/css/dashboard-console.css?v=1">

  <style>
    body.account-body {
      padding: 0 25px;
    }

    .account-navbar {
      background: linear-gradient(135deg, rgba(14, 26, 38, 0.98), rgba(5, 12, 20, 0.98));
      border-bottom: 1px solid var(--panel-border);
      box-shadow: 0 2px 18px rgba(0,0,0,0.55);
      backdrop-filter: blur(10px);
    }

    .account-navbar .navbar-brand,
    .account-navbar .nav-link,
    .account-navbar .navbar-toggler {
      color: var(--text) !important;
      font-weight: 600;
    }

    .account-navbar .nav-link.active {
      color: var(--accent) !important;
    }

    .account-navbar .btn-outline-light {
      border-color: var(--panel-border);
      color: var(--text);
      background: rgba(255,255,255,0.04);
    }

    .account-navbar .btn-outline-light:hover {
      background: rgba(53, 208, 198, 0.12);
      border-color: var(--panel-border-strong);
      color: var(--text);
    }

    .account-body .card {
      background: var(--panel);
      border: 1px solid var(--panel-border);
      color: var(--text);
      box-shadow: var(--shadow-md);
    }

    .account-body .btn,
    .account-navbar .btn {
      border-radius: var(--radius-md);
      padding: 0.4rem 0.75rem;
      font-size: 0.85rem;
      min-height: 44px;
    }

    .account-body .btn.btn-sm,
    .account-navbar .btn.btn-sm {
      padding: 0.25rem 0.6rem;
      font-size: 0.8rem;
      min-height: 32px;
    }

    .account-body .text-muted {
      color: var(--muted) !important;
    }

    .account-body .form-control {
      background: rgba(255,255,255,0.06);
      border: 1px solid var(--panel-border);
      color: var(--text);
    }

    .account-body .form-control:focus {
      border-color: var(--accent);
      box-shadow: 0 0 0 0.2rem rgba(53, 208, 198, 0.2);
    }

    .account-body .btn-primary {
      background: rgba(53, 208, 198, 0.18);
      border-color: rgba(53, 208, 198, 0.35);
      color: var(--text);
    }

    .account-body .btn-primary:hover {
      background: rgba(53, 208, 198, 0.26);
      border-color: rgba(53, 208, 198, 0.55);
    }

    .account-body .btn-outline-primary {
      background: rgba(255,255,255,0.06);
      border-color: var(--panel-border);
      color: var(--text);
    }

    .account-body .btn-outline-primary:hover {
      background: rgba(53, 208, 198, 0.14);
      border-color: var(--panel-border-strong);
    }

    @media (max-width: 768px) {
      body.account-body {
        padding: 0 12px;
      }
    }
  </style>
</head>

<body class="dashboard-body account-body">

<nav class="navbar navbar-expand-lg mb-3 account-navbar">
  <div class="container-fluid">
    <a class="navbar-brand" href="<cfoutput>#request.fpwBase#</cfoutput>/app/dashboard.cfm">Mobile App</a>
    <button class="navbar-toggler" type="button" data-bs-toggle="collapse" data-bs-target="#mainNav"
            aria-controls="mainNav" aria-expanded="false" aria-label="Toggle navigation">
      <span class="navbar-toggler-icon"></span>
    </button>

    <div class="collapse navbar-collapse" id="mainNav">
      <ul class="navbar-nav me-auto mb-2 mb-lg-0">
        <li class="nav-item">
          <a class="nav-link" href="<cfoutput>#request.fpwBase#</cfoutput>/app/dashboard.cfm">Dashboard</a>
        </li>
        <li class="nav-item">
          <a class="nav-link active" aria-current="page" href="<cfoutput>#request.fpwBase#</cfoutput>/app/account.cfm">Account</a>
        </li>
      </ul>

      <div class="d-flex gap-2">
        <a class="btn btn-outline-light btn-sm" href="<cfoutput>#request.fpwBase#</cfoutput>/app/dashboard.cfm">Dashboard</a>
        <button class="btn btn-outline-light btn-sm" id="logoutButton" type="button">Logout</button>
      </div>
    </div>
  </div>
</nav>

<div class="container pb-5">
  <div class="row g-4">
    <div class="col-12 col-lg-7">

      <div class="card shadow-sm mb-4">
        <div class="card-body">
          <div class="d-flex justify-content-between align-items-center mb-3">
            <h1 class="h4 mb-0">Profile</h1>
            <button class="btn btn-outline-primary btn-sm" id="refreshProfileBtn" type="button">Refresh</button>
          </div>

          <dl class="row small text-muted mb-4">
            <dt class="col-sm-4">Email</dt>
            <dd class="col-sm-8" id="emailDisplay">Loading…</dd>
            <dt class="col-sm-4">Last Login</dt>
            <dd class="col-sm-8" id="lastLogin">—</dd>
            <dt class="col-sm-4">Last Update</dt>
            <dd class="col-sm-8" id="lastUpdate">—</dd>
          </dl>

          <form id="profileForm" novalidate>
            <div class="row g-3">
              <div class="col-md-6">
                <label for="fName" class="form-label">First Name</label>
                <input type="text" class="form-control" id="fName" autocomplete="given-name">
              </div>
              <div class="col-md-6">
                <label for="lName" class="form-label">Last Name</label>
                <input type="text" class="form-control" id="lName" autocomplete="family-name">
              </div>
              <div class="col-12">
                <label for="mobilePhone" class="form-label">Mobile Phone</label>
                <input type="tel" class="form-control" id="mobilePhone" autocomplete="tel">
              </div>
            </div>

            <div class="mt-4">
              <button class="btn btn-primary" type="submit" id="saveProfileBtn">Save Profile</button>
            </div>
          </form>
        </div>
      </div>

      <div class="card shadow-sm">
        <div class="card-body">
          <h2 class="h5 mb-3">Home Port</h2>
          <form id="homePortForm" novalidate>
            <div class="mb-3">
              <label for="homeAddress" class="form-label">Street Address</label>
              <input type="text" class="form-control" id="homeAddress" autocomplete="street-address">
            </div>
            <div class="row g-3">
              <div class="col-md-6">
                <label for="homeCity" class="form-label">City</label>
                <input type="text" class="form-control" id="homeCity" autocomplete="address-level2">
              </div>
              <div class="col-md-3">
                <label for="homeState" class="form-label">State</label>
                <input type="text" class="form-control" id="homeState" maxlength="2" autocomplete="address-level1">
              </div>
              <div class="col-md-3">
                <label for="homeZip" class="form-label">ZIP</label>
                <input type="text" class="form-control" id="homeZip" autocomplete="postal-code">
              </div>
            </div>
            <div class="row g-3 mt-1">
              <div class="col-md-6">
                <label for="homePhone" class="form-label">Phone</label>
                <input type="tel" class="form-control" id="homePhone" autocomplete="tel">
              </div>
              <div class="col-md-3">
                <label for="homeLat" class="form-label">Latitude</label>
                <input type="text" class="form-control" id="homeLat" inputmode="decimal">
              </div>
              <div class="col-md-3">
                <label for="homeLng" class="form-label">Longitude</label>
                <input type="text" class="form-control" id="homeLng" inputmode="decimal">
              </div>
            </div>
            <div class="mt-4">
              <button class="btn btn-outline-primary" type="submit" id="saveHomePortBtn">Save Home Port</button>
            </div>
          </form>
        </div>
      </div>

    </div>

    <div class="col-12 col-lg-5">
      <div class="card shadow-sm">
        <div class="card-body">
          <h2 class="h5 mb-3">Change Password</h2>
          <form id="passwordForm" novalidate>
            <div class="mb-3">
              <label for="currentPassword" class="form-label">Current Password</label>
              <input type="password" class="form-control" id="currentPassword" autocomplete="current-password" required>
            </div>
            <div class="mb-3">
              <label for="newPassword" class="form-label">New Password</label>
              <input type="password" class="form-control" id="newPassword" autocomplete="new-password" required>
            </div>
            <div class="mb-4">
              <label for="confirmPassword" class="form-label">Confirm New Password</label>
              <input type="password" class="form-control" id="confirmPassword" autocomplete="new-password" required>
            </div>
            <button class="btn btn-primary w-100" type="submit" id="changePwBtn">Change Password</button>
          </form>
        </div>
      </div>
    </div>
  </div>
</div>

<cfinclude template="../includes/footer_scripts.cfm">
<script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/app/account.js"></script>

</body>
</html>
