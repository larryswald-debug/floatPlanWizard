<cfprocessingdirective pageencoding="utf-8">
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Account Settings</title>
  <meta name="viewport" content="width=device-width, initial-scale=1">

  <cfinclude template="../includes/header_styles.cfm">
  <link rel="stylesheet" href="<cfoutput>#request.fpwBase#</cfoutput>/assets/css/dashboard-console.css?v=2">
  <link rel="stylesheet" href="<cfoutput>#request.fpwBase#</cfoutput>/assets/css/account.css?v=20260521-site-rail">
</head>

<body class="dashboard-body account-body">

<cfset request.fpwTopNavActive = "account">
<cfinclude template="../includes/top_nav.cfm">

<div class="account-main fpw-layout-rail pb-5">
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
      <div class="card shadow-sm mb-4" id="membershipBillingCard">
        <div class="card-body">
          <div class="d-flex flex-wrap justify-content-between align-items-start gap-3 mb-3">
            <div>
              <h2 class="h5 mb-1">Membership &amp; Billing</h2>
              <p class="small text-muted mb-0" id="membershipBillingSummary">Checking membership status...</p>
            </div>
            <span class="membership-status-badge" id="membershipBillingStatus">Loading</span>
          </div>

          <div class="membership-billing-actions d-none" id="membershipUpgradeActions">
            <button class="btn btn-primary btn-sm" type="button" data-membership-upgrade="monthly">Upgrade Monthly</button>
            <button class="btn btn-outline-primary btn-sm" type="button" data-membership-upgrade="yearly">Upgrade Yearly</button>
          </div>

          <div class="membership-billing-actions d-none" id="membershipPortalActions">
            <button class="btn btn-primary btn-sm" type="button" id="membershipManageBillingBtn">Manage Billing</button>
          </div>

          <p class="small text-muted mt-3 mb-0" id="membershipBillingMessage" aria-live="polite"></p>

          <div class="membership-promo-panel mt-4" id="membershipPromoPanel">
            <h3 class="h6 mb-1">Redeem Launch or Founder Code</h3>
            <p class="small text-muted mb-3">Enter a Memorial Day launch or Founder code. Launch trial codes open secure Stripe Checkout, and no credit card is required to start.</p>
            <form id="promoCodeForm" novalidate>
              <label class="visually-hidden" for="promoCodeInput">Launch or Founder code</label>
              <div class="membership-promo-input-group">
                <input type="text" class="form-control" id="promoCodeInput" autocomplete="off" autocapitalize="characters" spellcheck="false" placeholder="Enter code">
                <button class="btn btn-outline-primary btn-sm" id="promoCodeRedeemBtn" type="submit">Redeem Code</button>
              </div>
            </form>
            <p class="small text-muted mt-2 mb-0" id="promoCodeMessage" aria-live="polite"></p>
          </div>
        </div>
      </div>

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

    <div class="col-12">
      <div class="card shadow-sm" id="companionDevicesCard">
        <div class="card-body">
          <div class="d-flex flex-wrap justify-content-between align-items-start gap-3 mb-3">
            <div>
              <h2 class="h5 mb-1">Companion Devices</h2>
              <p class="small text-muted mb-0">Pair and manage devices that can use the FPW Companion App.</p>
            </div>
            <div class="d-flex flex-wrap gap-2">
              <button class="btn btn-outline-primary btn-sm" id="refreshCompanionDevicesBtn" type="button">Refresh</button>
              <button class="btn btn-primary btn-sm" id="companionPairBtn" type="button">Pair Companion App</button>
            </div>
          </div>

          <div class="companion-safety-note mb-4" role="note">
            <p class="mb-1">Only pair devices you control. The Companion App can submit trip check-ins for your active float plan.</p>
            <p class="mb-1">Pairing codes are single-use and expire in 10 minutes. Do not share a pairing code with anyone.</p>
            <p class="mb-1">If a phone is lost, stolen, replaced, or no longer yours, revoke it immediately.</p>
            <p class="mb-0">Bearer tokens are never shown here.</p>
          </div>

          <div id="companionPairingPanel" class="companion-pairing-panel d-none mb-4" aria-live="polite">
            <div class="d-flex flex-wrap justify-content-between align-items-center gap-3">
              <div>
                <div class="small text-muted mb-1">Manual pairing code</div>
                <div class="companion-pairing-code" id="companionPairingCode">----</div>
              </div>
              <button class="btn btn-outline-primary btn-sm" id="copyCompanionPairingCodeBtn" type="button">Copy Code</button>
            </div>
            <div class="small text-muted mt-3" id="companionPairingExpires">Expires at --</div>
            <p class="small text-muted mb-0 mt-2" id="companionPairingMessage">
              Enter this code in the Companion App. QR pairing can be added later, but is not enabled in this phase.
            </p>
          </div>

          <div id="companionDevicesStatus" class="small text-muted mb-3" aria-live="polite">Loading companion devices...</div>
          <div id="companionDevicesEmpty" class="companion-empty-state d-none">No companion devices are paired yet.</div>
          <div id="companionDevicesList" class="companion-device-list"></div>
        </div>
      </div>
    </div>
  </div>
</div>

<cfinclude template="../includes/footer.cfm">

<cfinclude template="../includes/footer_scripts.cfm">
<script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/app/account.js"></script>

</body>
</html>
