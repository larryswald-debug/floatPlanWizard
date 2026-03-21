<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Account Settings</title>
  <meta name="viewport" content="width=device-width, initial-scale=1">

  <cfinclude template="../includes/header_styles.cfm">
  <link rel="stylesheet" href="<cfoutput>#request.fpwBase#</cfoutput>/assets/css/dashboard-console.css?v=2">
  <link rel="stylesheet" href="<cfoutput>#request.fpwBase#</cfoutput>/assets/css/account.css?v=1">
</head>

<body class="dashboard-body account-body">

<cfinclude template="../includes/top_nav.cfm">

<div class="account-main pb-5">
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
