<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Account Settings</title>
  <meta name="viewport" content="width=device-width, initial-scale=1">

  <!-- Bootstrap 5 CSS (CDN) -->
  <link
    href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css"
    rel="stylesheet"
    integrity="sha384-QWTKZyjpPEjISv5WaRU9OFeRpok6YctnYmDr5pNlyT2bRjXh0JMhjY6hW+ALEwIH"
    crossorigin="anonymous">

  <link rel="stylesheet" href="/fpw/assets/css/app.css">
</head>
<body class="bg-light">

<nav class="navbar navbar-expand-lg navbar-dark bg-primary mb-3">
  <div class="container-fluid">
    <a class="navbar-brand" href="/fpw/app/dashboard.cfm">Mobile App</a>

    <div class="ms-auto d-flex gap-2">
      <a class="btn btn-outline-light btn-sm" href="/fpw/app/dashboard.cfm">Dashboard</a>
      <button class="btn btn-outline-light btn-sm" id="logoutButton">Logout</button>
    </div>
  </div>
</nav>

<div class="container pb-5">

  <div class="row">
    <div class="col-12">
      <h1 class="h4 mb-3">Account Settings</h1>
      <div id="accountAlert" class="alert d-none" role="alert"></div>
    </div>
  </div>

  <div class="row g-3">
    <!-- Profile card -->
    <div class="col-12 col-lg-6">
      <div class="card shadow-sm">
        <div class="card-body">
          <div class="d-flex justify-content-between align-items-start">
            <div>
              <h2 class="h6 mb-1">Profile</h2>
              <p class="text-muted small mb-3">Update your name and contact info.</p>
            </div>
            <div class="text-end">
              <div class="small text-muted">Member Email</div>
              <div class="fw-semibold" id="emailDisplay">—</div>
            </div>
          </div>

          <form id="profileForm" novalidate>
            <div class="row g-2">
              <div class="col-12 col-md-6">
                <label class="form-label" for="fName">First Name</label>
                <input class="form-control" id="fName" name="fName" type="text" autocomplete="given-name">
              </div>
              <div class="col-12 col-md-6">
                <label class="form-label" for="lName">Last Name</label>
                <input class="form-control" id="lName" name="lName" type="text" autocomplete="family-name">
              </div>
              <div class="col-12">
                <label class="form-label" for="mobilePhone">Mobile Phone</label>
                <input class="form-control" id="mobilePhone" name="mobilePhone" type="tel" autocomplete="tel">
              </div>
            </div>

            <div class="mt-3 d-flex gap-2">
              <button class="btn btn-primary" type="submit" id="saveProfileBtn">Save Profile</button>
              <button class="btn btn-outline-secondary" type="button" id="refreshProfileBtn">Refresh</button>
            </div>

            <div class="mt-3 small text-muted">
              <div>Last login: <span id="lastLogin">—</span></div>
              <div>Last update: <span id="lastUpdate">—</span></div>
            </div>
          </form>
        </div>
      </div>
    </div>

    <!-- Change password card -->
    <div class="col-12 col-lg-6">
      <div class="card shadow-sm">
        <div class="card-body">
          <h2 class="h6 mb-1">Change Password</h2>
          <p class="text-muted small mb-3">Choose a strong password (8+ characters).</p>

          <form id="passwordForm" novalidate>
            <div class="mb-2">
              <label class="form-label" for="currentPassword">Current Password</label>
              <input class="form-control" id="currentPassword" name="currentPassword" type="password" autocomplete="current-password" required>
            </div>

            <div class="mb-2">
              <label class="form-label" for="newPassword">New Password</label>
              <input class="form-control" id="newPassword" name="newPassword" type="password" autocomplete="new-password" required minlength="8">
            </div>

            <div class="mb-3">
              <label class="form-label" for="confirmPassword">Confirm New Password</label>
              <input class="form-control" id="confirmPassword" name="confirmPassword" type="password" autocomplete="new-password" required minlength="8">
            </div>

            <button class="btn btn-primary" type="submit" id="changePwBtn">Change Password</button>
          </form>

          <hr class="my-4">

          <h3 class="h6 mb-1">Home Port</h3>
          <p class="text-muted small mb-2">Currently read-only (we’ll add editing next).</p>

          <div class="small">
            <div><strong>Address:</strong> <span id="homeAddress">—</span></div>
            <div><strong>City/State/Zip:</strong> <span id="homeCityStateZip">—</span></div>
            <div><strong>Phone:</strong> <span id="homePhone">—</span></div>
            <div><strong>Lat/Lng:</strong> <span id="homeLatLng">—</span></div>
          </div>

        </div>
      </div>
    </div>

  </div>
</div>


<!-- Bootstrap JS bundle -->
<script
  src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js"
  integrity="sha384-YvpcrYf0tY3lHB60NNkmXc5s9fDVZLESaAA55NDzOxhy9GkcIdslK1eN7N6jIeHz"
  crossorigin="anonymous"></script>

<script src="/fpw/assets/js/app/api.js"></script>
<script src="/fpw/assets/js/app/account.js"></script>

</body>
</html>
