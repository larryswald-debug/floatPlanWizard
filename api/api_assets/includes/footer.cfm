<cfscript>
footerBasePath = "";

if (structKeyExists(request, "fpwBase")) {
  footerBasePath = trim(toString(request.fpwBase));
}

if (!len(footerBasePath) AND structKeyExists(cgi, "script_name")) {
  footerScriptName = replace(trim(toString(cgi.script_name)), "\\", "/", "all");
  footerMarkerPos = findNoCase("/app/", footerScriptName);

  if (!footerMarkerPos) {
    footerMarkerPos = findNoCase("/boat-fuel-calculator/", footerScriptName);
  }
  if (!footerMarkerPos) {
    footerMarkerPos = findNoCase("/assets/", footerScriptName);
  }

  if (footerMarkerPos GT 1) {
    footerBasePath = left(footerScriptName, footerMarkerPos - 1);
  } else if (footerMarkerPos EQ 1) {
    footerBasePath = "";
  } else {
    footerBasePath = reReplace(footerScriptName, "/[^/]+\.cfm$", "");
  }
}

footerBasePath = reReplace(footerBasePath, "/$", "");
if (footerBasePath EQ "/") {
  footerBasePath = "";
}
if (len(footerBasePath) AND left(footerBasePath, 1) NEQ "/") {
  footerBasePath = "/" & footerBasePath;
}
</cfscript>

<style>
  .fpw-site-footer,
  .fpw-site-footer * {
    box-sizing: border-box;
  }

  .fpw-site-footer {
    --fpw-footer-layout-max: var(--fpw-nav-layout-max, var(--fpw-public-layout-max, var(--fpw-max, 1480px)));
    width: 100vw;
    max-width: 100vw;
    margin-left: calc(50% - 50vw);
    margin-right: calc(50% - 50vw);
    background: #06131d;
    padding: 10px 0 34px;
    color: #dbe8f3;
    font-family: inherit;
  }

  .fpw-footer-shell {
    width: min(var(--fpw-footer-layout-max), calc(100% - 48px));
    margin: 0 auto;
    border: 1px solid rgba(89, 132, 160, 0.35);
    border-radius: 28px;
    background:
      radial-gradient(circle at top left, rgba(41, 151, 191, 0.14), transparent 34%),
      linear-gradient(180deg, rgba(11, 30, 44, 0.96), rgba(5, 17, 27, 0.98));
    box-shadow: 0 20px 60px rgba(0, 0, 0, 0.28);
    padding: 30px;
  }

  .fpw-footer-grid {
    display: grid;
    grid-template-columns: minmax(280px, 1.7fr) repeat(3, minmax(150px, 1fr));
    gap: 28px;
    align-items: start;
  }

  .fpw-footer-brand h2 {
    margin: 0 0 6px;
    color: #ffffff;
    font-size: 1.35rem;
    letter-spacing: -0.02em;
  }

  .fpw-footer-brand p,
  .fpw-footer-note,
  .fpw-footer-col a,
  .fpw-footer-bottom,
  .fpw-footer-alert {
    color: #8fa9bc;
  }

  .fpw-footer-logo-row {
    display: flex;
    gap: 14px;
    align-items: flex-start;
  }

  .fpw-footer-mark {
    width: 48px;
    height: 48px;
    border-radius: 16px;
    display: grid;
    place-items: center;
    color: #67d8ff;
    font-weight: 800;
    letter-spacing: 0.04em;
    border: 1px solid rgba(103, 216, 255, 0.45);
    background: rgba(20, 83, 114, 0.22);
    box-shadow: inset 0 0 20px rgba(103, 216, 255, 0.08);
    flex: 0 0 auto;
  }

  .fpw-footer-note {
    margin: 18px 0 0;
    font-size: 0.95rem;
  }

  .fpw-footer-col h3 {
    margin: 0 0 12px;
    color: #ffffff;
    font-size: 0.85rem;
    text-transform: uppercase;
    letter-spacing: 0.12em;
  }

  .fpw-footer-col a {
    display: block;
    padding: 6px 0;
    text-decoration: none;
    font-size: 0.95rem;
    transition: color 0.18s ease, transform 0.18s ease;
  }

  .fpw-footer-col a:hover,
  .fpw-footer-col a:focus {
    color: #67d8ff;
    transform: translateX(2px);
  }

  .fpw-footer-alert {
    margin-top: 28px;
    padding: 14px 16px;
    border-radius: 16px;
    border: 1px solid rgba(255, 184, 77, 0.35);
    background: rgba(255, 184, 77, 0.08);
    font-size: 0.9rem;
    line-height: 1.5;
  }

  .fpw-footer-alert strong {
    color: #ffd18a;
  }

  .fpw-footer-bottom {
    margin-top: 22px;
    padding-top: 18px;
    border-top: 1px solid rgba(89, 132, 160, 0.25);
    display: flex;
    justify-content: space-between;
    gap: 14px;
    flex-wrap: wrap;
    font-size: 0.9rem;
  }

  @media (max-width: 860px) {
    .fpw-footer-shell {
      width: min(100% - 28px, var(--fpw-footer-layout-max));
      padding: 24px;
      border-radius: 22px;
    }

    .fpw-footer-grid {
      grid-template-columns: 1fr 1fr;
    }

    .fpw-footer-brand {
      grid-column: 1 / -1;
    }
  }

  @media (max-width: 560px) {
    .fpw-site-footer {
      padding: 10px 0 26px;
    }

    .fpw-footer-grid {
      grid-template-columns: 1fr;
      gap: 22px;
    }

    .fpw-footer-bottom {
      display: block;
    }

    .fpw-footer-bottom span {
      display: block;
      margin-top: 6px;
    }
  }
</style>

<cfoutput>
<footer class="fpw-site-footer">
  <div class="fpw-footer-shell">
    <div class="fpw-footer-grid">
      <section class="fpw-footer-brand">
        <div class="fpw-footer-logo-row">
          <div class="fpw-footer-mark">FPW</div>
          <div>
            <h2>FloatPlanWizard</h2>
            <p>Boating trip planning, float plans, check-ins, and trip monitoring for recreational boaters.</p>
          </div>
        </div>

        <p class="fpw-footer-note">
          Built for Great Loopers, coastal cruisers, and serious recreational boaters.
        </p>
      </section>

      <nav class="fpw-footer-col" aria-label="FloatPlanWizard planning tools">
        <h3>Plan</h3>
        <a href="#footerBasePath#/app/dashboard.cfm">Dashboard</a>
        <a href="#footerBasePath#/app/weather.cfm">Marine Weather</a>
        <a href="#footerBasePath#/boat-fuel-calculator/boat-fuel-calculator.cfm">Fuel Calculator</a>
        <a href="#footerBasePath#/app/pricing.cfm">Memberships</a>
      </nav>

      <nav class="fpw-footer-col" aria-label="Account and support">
        <h3>Account</h3>
        <a href="#footerBasePath#/app/account.cfm">My Account</a>
        <a href="#footerBasePath#/app/login.cfm">Log In</a>
        <a href="#footerBasePath#/app/join.cfm">Join Free</a>
        <a href="#footerBasePath#/app/contact.cfm">Contact Support</a>
      </nav>

      <nav class="fpw-footer-col" aria-label="Legal and safety">
        <h3>Legal</h3>
        <a href="##fpwFooterEmergencyNotice">Safety Notice</a>
      </nav>
    </div>

    <div class="fpw-footer-alert" id="fpwFooterEmergencyNotice">
      <strong>Emergency notice:</strong>
      FloatPlanWizard is not a rescue, dispatch, or emergency response service.
      In an emergency, use official channels such as VHF Channel 16, DSC distress, 911, EPIRB/PLB, or local emergency services.
    </div>

    <div class="fpw-footer-bottom">
      <span>&copy; 2026 FloatPlanWizard. All rights reserved.</span>
      <span>Now live for recreational boaters.</span>
    </div>
  </div>
</footer>
<cfabort>
</cfoutput>
