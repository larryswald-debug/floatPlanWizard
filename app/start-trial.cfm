<cfinclude template="../includes/fpw_base_path.cfm">
<cfscript>
startTrialUserId = 0;
if (structKeyExists(session, "user") AND isStruct(session.user)) {
  if (structKeyExists(session.user, "userId") AND isNumeric(session.user.userId)) {
    startTrialUserId = val(session.user.userId);
  } else if (structKeyExists(session.user, "id") AND isNumeric(session.user.id)) {
    startTrialUserId = val(session.user.id);
  } else if (structKeyExists(session.user, "USERID") AND isNumeric(session.user.USERID)) {
    startTrialUserId = val(session.user.USERID);
  }
}

if (startTrialUserId LTE 0) {
  location(url = request.fpwBase & "/app/join.cfm?offer=launch_trial", addToken = false);
}
</cfscript>
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Your FloatPlanWizard Account Is Ready</title>
  <meta name="viewport" content="width=device-width, initial-scale=1">

  <cfinclude template="../includes/header_styles.cfm">
  <link rel="stylesheet" href="<cfoutput>#request.fpwBase#</cfoutput>/assets/css/dashboard-console.css?v=20260526-cache-bump">
  <link rel="stylesheet" href="<cfoutput>#request.fpwBase#</cfoutput>/assets/css/account.css?v=20260526-cache-bump">
  <style>
    .fpw-start-trial-body {
      min-height: 100vh;
      background:
        radial-gradient(circle at 12% 14%, rgba(33, 215, 211, 0.13), transparent 28rem),
        radial-gradient(circle at 86% 12%, rgba(126, 167, 255, 0.08), transparent 30rem),
        linear-gradient(135deg, #06131f 0%, #071827 45%, #05101b 100%);
      color: #f4f8fb;
    }

    .fpw-signup-success-page {
      --fpw-success-line: rgba(92, 225, 230, 0.18);
      --fpw-success-line-strong: rgba(92, 225, 230, 0.34);
      --fpw-success-text: #f4f8fb;
      --fpw-success-muted: #b7c4cf;
      --fpw-success-teal: #21d7d3;
      --fpw-success-teal-2: #17b7c8;
      --fpw-success-blue: #7ea7ff;
      --fpw-success-purple: #8c72ff;
      position: relative;
      min-height: calc(100vh - 92px);
      padding: clamp(1.9rem, 2.2vw, 2.1rem) clamp(1rem, 5vw, 5.3rem) 0.7rem;
      overflow: hidden;
      isolation: isolate;
    }

    .fpw-signup-success-page::before {
      content: "";
      position: absolute;
      inset: 0;
      z-index: -1;
      opacity: 0.2;
      background:
        linear-gradient(rgba(92, 225, 230, 0.06) 1px, transparent 1px),
        linear-gradient(90deg, rgba(92, 225, 230, 0.05) 1px, transparent 1px);
      background-size: 64px 64px;
      mask-image: radial-gradient(circle at center, black, transparent 72%);
      pointer-events: none;
    }

    .fpw-signup-success-page::after {
      content: "";
      position: absolute;
      inset: 0;
      z-index: -1;
      opacity: 0.32;
      background:
        repeating-radial-gradient(ellipse at 100% 18%, transparent 0 2.2rem, rgba(92, 225, 230, 0.045) 2.25rem 2.32rem, transparent 2.38rem 3.55rem),
        repeating-radial-gradient(ellipse at 0% 80%, transparent 0 2.6rem, rgba(92, 225, 230, 0.035) 2.68rem 2.74rem, transparent 2.8rem 4.2rem);
      pointer-events: none;
    }

    .fpw-signup-success-hero,
    .fpw-next-steps-panel,
    .fpw-safety-strip {
      position: relative;
      z-index: 1;
      max-width: 1232px;
      margin-inline: auto;
    }

    .fpw-signup-success-hero {
      display: grid;
      grid-template-columns: minmax(0, 760px) minmax(360px, 394px);
      justify-content: space-between;
      gap: clamp(2rem, 5vw, 4.9rem);
      align-items: start;
    }

    .fpw-signup-success-copy {
      padding-block: clamp(1.65rem, 2vw, 2rem) 0;
    }

    .fpw-success-badge-row {
      display: flex;
      flex-wrap: wrap;
      gap: 0.75rem;
      align-items: center;
      margin-bottom: 1.4rem;
    }

    .fpw-inline-icon,
    .fpw-card-link svg,
    .fpw-safety-link svg {
      width: 1em;
      height: 1em;
      flex: 0 0 auto;
      fill: none;
      stroke: currentColor;
      stroke-width: 2.35;
      stroke-linecap: round;
      stroke-linejoin: round;
    }

    .fpw-success-pill,
    .fpw-trial-pill {
      display: inline-flex;
      align-items: center;
      gap: 0.45rem;
      border: 1px solid var(--fpw-success-line-strong);
      border-radius: 999px;
      padding: 0.48rem 0.8rem;
      font-size: 0.78rem;
      font-weight: 800;
      line-height: 1;
      text-transform: uppercase;
      letter-spacing: 0.035em;
    }

    .fpw-success-pill {
      color: #c7fff7;
      background: rgba(20, 160, 145, 0.18);
      box-shadow: 0 0 24px rgba(33, 215, 211, 0.12);
    }

    .fpw-trial-pill {
      color: #d9d1ff;
      background: rgba(140, 114, 255, 0.18);
      border-color: rgba(140, 114, 255, 0.34);
    }

    .fpw-success-pill-icon {
      display: inline-grid;
      place-items: center;
      width: 1.05rem;
      height: 1.05rem;
      border-radius: 999px;
      color: #062326;
      background: var(--fpw-success-teal);
    }

    .fpw-headline-row {
      display: flex;
      flex-wrap: wrap;
      gap: 1rem;
      align-items: flex-start;
    }

    .fpw-headline-row .fpw-trial-pill {
      margin-top: 0.55rem;
    }

    .fpw-signup-success-copy h1 {
      max-width: 545px;
      margin: 0;
      color: var(--fpw-success-text);
      font-size: clamp(2.7rem, 3.45vw, 3.55rem);
      line-height: 0.98;
      letter-spacing: -0.05em;
      text-wrap: balance;
    }

    .fpw-signup-success-copy h1 .fpw-headline-accent {
      display: block;
      color: var(--fpw-success-teal);
      text-shadow: 0 0 30px rgba(33, 215, 211, 0.24);
    }

    .fpw-success-lede {
      max-width: 640px;
      margin: 1.35rem 0 0;
      color: #c9d6df;
      font-size: clamp(1.05rem, 1.4vw, 1.34rem);
      line-height: 1.65;
    }

    .fpw-success-lede strong {
      color: var(--fpw-success-teal);
      font-weight: 800;
    }

    .fpw-success-actions {
      display: flex;
      flex-wrap: wrap;
      gap: 0.85rem;
      margin-top: 2.15rem;
    }

    .fpw-signup-success-page .fpw-btn {
      display: inline-flex;
      align-items: center;
      justify-content: center;
      gap: 0.7rem;
      min-height: 58px;
      padding: 0.95rem 1.45rem;
      border-radius: 0.75rem;
      border: 1px solid transparent;
      font-weight: 850;
      font-size: 1rem;
      text-decoration: none;
      cursor: pointer;
      transition: transform 160ms ease, border-color 160ms ease, background 160ms ease, box-shadow 160ms ease;
    }

    .fpw-signup-success-page .fpw-btn:hover {
      transform: translateY(-1px);
      text-decoration: none;
    }

    .fpw-signup-success-page .fpw-btn-primary {
      color: #031a20;
      background: linear-gradient(135deg, var(--fpw-success-teal), var(--fpw-success-teal-2));
      border-color: rgba(255, 255, 255, 0.18);
      box-shadow: 0 18px 46px rgba(23, 183, 200, 0.22);
      min-width: 330px;
    }

    .fpw-signup-success-page .fpw-btn-primary:hover,
    .fpw-signup-success-page .fpw-btn-primary:focus-visible {
      color: #031a20;
      box-shadow: 0 22px 54px rgba(23, 183, 200, 0.3);
    }

    .fpw-signup-success-page .fpw-btn-primary:disabled {
      cursor: wait;
      opacity: 0.72;
      transform: none;
      box-shadow: none;
    }

    .fpw-signup-success-page .fpw-btn-secondary {
      color: #e8f3f8;
      background: rgba(8, 29, 44, 0.72);
      border-color: rgba(183, 196, 207, 0.28);
      min-width: 295px;
    }

    .fpw-signup-success-page .fpw-btn-secondary:hover,
    .fpw-signup-success-page .fpw-btn-secondary:focus-visible {
      color: #ffffff;
      border-color: var(--fpw-success-line-strong);
      background: rgba(11, 38, 56, 0.9);
    }

    .fpw-trial-status-panel {
      display: flex;
      align-items: center;
      gap: 0.8rem;
      max-width: 650px;
      margin-top: 1.4rem;
      padding: 1rem 1.1rem;
      border: 1px solid rgba(126, 167, 255, 0.28);
      border-radius: 0.75rem;
      color: #d9e6ef;
      background: rgba(7, 29, 48, 0.78);
    }

    .fpw-trial-status-panel strong {
      color: var(--fpw-success-teal);
    }

    .fpw-trial-status-panel.membership-message-error {
      border-color: rgba(255, 123, 123, 0.38);
      color: #ffd7d7;
    }

    .fpw-trial-status-panel.membership-message-success {
      border-color: rgba(33, 215, 211, 0.38);
      color: #d9e6ef !important;
    }

    .fpw-status-info-icon {
      display: inline-grid;
      place-items: center;
      flex: 0 0 auto;
      width: 1.7rem;
      height: 1.7rem;
      border-radius: 999px;
      border: 1px solid rgba(126, 167, 255, 0.7);
      color: var(--fpw-success-blue);
      font-weight: 900;
    }

    .fpw-premium-trust-card {
      width: 100%;
      max-width: 394px;
      height: 514px;
      min-height: 0;
      border: 1px solid var(--fpw-success-line-strong);
      border-radius: 1rem;
      padding: 1.25rem 1.6rem 1.25rem;
      background:
        radial-gradient(circle at 50% 0%, rgba(33, 215, 211, 0.15), transparent 16rem),
        rgba(7, 28, 43, 0.82);
      box-shadow: 0 28px 80px rgba(0, 0, 0, 0.32);
    }

    .fpw-trust-shield {
      display: grid;
      place-items: center;
      width: 4.35rem;
      height: 4.35rem;
      margin: 0 auto 0.95rem;
      border-radius: 999px;
      color: #cffffa;
      background: rgba(33, 215, 211, 0.18);
      border: 1px solid rgba(33, 215, 211, 0.18);
      font-weight: 900;
    }

    .fpw-trust-shield svg {
      width: 2.25rem;
      height: 2.25rem;
      stroke-width: 2;
    }

    .fpw-premium-trust-card h2 {
      margin: 0 0 1.08rem;
      text-align: center;
      font-size: clamp(1.45rem, 2vw, 1.9rem);
      line-height: 1.18;
    }

    .fpw-premium-trust-card h2 span {
      color: var(--fpw-success-teal);
    }

    .fpw-trust-list {
      display: grid;
      gap: 0;
    }

    .fpw-trust-item {
      display: grid;
      grid-template-columns: 3.4rem 1fr;
      gap: 1rem;
      padding: 0.78rem 0;
      border-top: 1px solid rgba(183, 196, 207, 0.14);
    }

    .fpw-trust-icon {
      display: grid;
      place-items: center;
      width: 3rem;
      height: 3rem;
      color: var(--fpw-success-teal);
    }

    .fpw-trust-icon svg {
      width: 2.15rem;
      height: 2.15rem;
      stroke-width: 1.9;
    }

    .fpw-trust-item h3 {
      margin: 0 0 0.35rem;
      font-size: 1rem;
      color: #ffffff;
    }

    .fpw-trust-item p {
      margin: 0;
      color: var(--fpw-success-muted);
      line-height: 1.55;
    }

    .fpw-next-steps-panel {
      margin-top: clamp(2rem, 2.4vw, 2.25rem);
      padding: 1rem clamp(1.25rem, 2vw, 1.55rem) 1.1rem;
      border: 1px solid rgba(92, 225, 230, 0.16);
      border-radius: 1rem;
      background: rgba(7, 24, 39, 0.72);
      box-shadow: 0 20px 60px rgba(0, 0, 0, 0.22);
    }

    .fpw-section-title-row {
      display: grid;
      grid-template-columns: 1fr auto 1fr;
      gap: 1.4rem;
      align-items: center;
      margin: 0.1rem 0 0.65rem;
      position: relative;
    }

    .fpw-section-title-row span {
      height: 1px;
      background: linear-gradient(90deg, transparent, rgba(33, 215, 211, 0.38), transparent);
    }

    .fpw-section-title-row h2 {
      margin: 0;
      font-size: clamp(1.3rem, 2vw, 1.8rem);
      text-align: center;
    }

    .fpw-section-anchor {
      position: absolute;
      left: 50%;
      top: 2.05rem;
      color: var(--fpw-success-teal);
      transform: translateX(-50%);
    }

    .fpw-section-anchor svg {
      width: 1.5rem;
      height: 1.5rem;
      stroke-width: 2.15;
    }

    .fpw-next-step-grid {
      display: grid;
      grid-template-columns: repeat(4, minmax(0, 1fr));
      gap: 1rem;
    }

    .fpw-next-step-card {
      display: flex;
      flex-direction: column;
      min-height: 275px;
      padding: 1.5rem 1.15rem 1.15rem;
      border: 1px solid rgba(92, 225, 230, 0.18);
      border-radius: 0.85rem;
      text-align: center;
      background: linear-gradient(180deg, rgba(12, 45, 66, 0.72), rgba(7, 24, 39, 0.82));
    }

    .fpw-next-step-icon {
      display: grid;
      place-items: center;
      width: 4.25rem;
      height: 4.25rem;
      margin: 0 auto 1rem;
      border-radius: 999px;
      color: #dffffb;
      background: rgba(33, 215, 211, 0.18);
      border: 1px solid rgba(33, 215, 211, 0.12);
    }

    .fpw-next-step-icon svg {
      width: 2.55rem;
      height: 2.55rem;
      stroke-width: 1.95;
    }

    .fpw-next-step-card h3 {
      margin: 0 0 0.7rem;
      color: #ffffff;
      font-size: 1.08rem;
      line-height: 1.25;
    }

    .fpw-next-step-card p {
      margin: 0;
      color: var(--fpw-success-muted);
      line-height: 1.52;
    }

    .fpw-card-link {
      display: inline-flex;
      align-items: center;
      justify-content: center;
      gap: 0.45rem;
      margin-top: auto;
      padding-top: 1rem;
      color: var(--fpw-success-teal);
      font-weight: 800;
      text-decoration: none;
    }

    .fpw-card-link:hover,
    .fpw-card-link:focus-visible {
      color: #ffffff;
      text-decoration: none;
    }

    .fpw-safety-strip {
      display: grid;
      grid-template-columns: auto 1fr auto;
      gap: 1rem;
      align-items: center;
      margin-top: 0.75rem;
      padding: 1rem 1.15rem;
      border: 1px solid rgba(92, 225, 230, 0.14);
      border-radius: 0.85rem;
      background: rgba(7, 24, 39, 0.72);
    }

    .fpw-safety-icon {
      display: grid;
      place-items: center;
      width: 2.25rem;
      height: 2.25rem;
      color: #c6dbff;
    }

    .fpw-safety-icon svg {
      width: 1.85rem;
      height: 1.85rem;
      stroke-width: 2;
    }

    .fpw-safety-strip strong {
      display: block;
      color: #ffffff;
      margin-bottom: 0.2rem;
    }

    .fpw-safety-strip p {
      margin: 0;
      color: var(--fpw-success-muted);
    }

    .fpw-safety-link {
      display: inline-flex;
      align-items: center;
      gap: 0.45rem;
      color: var(--fpw-success-teal);
      font-weight: 800;
      text-decoration: none;
      white-space: nowrap;
    }

    .fpw-safety-link:hover,
    .fpw-safety-link:focus-visible {
      color: #ffffff;
      text-decoration: none;
    }

    @media (max-width: 980px) {
      .fpw-signup-success-hero {
        grid-template-columns: 1fr;
      }

      .fpw-next-step-grid {
        grid-template-columns: repeat(2, minmax(0, 1fr));
      }

      .fpw-premium-trust-card {
        max-width: none;
      }
    }

    @media (max-width: 620px) {
      .fpw-signup-success-page {
        padding-inline: 1rem;
      }

      .fpw-signup-success-copy h1 {
        font-size: clamp(2.25rem, 15vw, 3.3rem);
      }

      .fpw-success-actions,
      .fpw-signup-success-page .fpw-btn {
        width: 100%;
      }

      .fpw-next-step-grid {
        grid-template-columns: 1fr;
      }

      .fpw-section-title-row {
        grid-template-columns: 1fr;
        gap: 0.7rem;
      }

      .fpw-section-title-row span {
        display: none;
      }

      .fpw-trust-item {
        grid-template-columns: 1fr;
        text-align: center;
      }

      .fpw-premium-trust-card {
        height: auto;
      }

      .fpw-trust-icon {
        margin-inline: auto;
      }

      .fpw-safety-strip {
        grid-template-columns: auto 1fr;
      }

      .fpw-safety-link {
        grid-column: 1 / -1;
        justify-content: center;
      }
    }
  </style>
</head>

<body class="dashboard-body account-body fpw-start-trial-body">

<cfinclude template="../includes/top_nav.cfm">

<main class="fpw-signup-success-page" aria-labelledby="fpwSignupSuccessTitle">
  <section class="fpw-signup-success-hero">
    <div class="fpw-signup-success-copy">
      <div class="fpw-success-badge-row">
        <span class="fpw-success-pill">
          <span class="fpw-success-pill-icon" aria-hidden="true">
            <svg class="fpw-inline-icon" viewBox="0 0 24 24" focusable="false">
              <path d="M20 6L9 17l-5-5"></path>
            </svg>
          </span>
          Account created
        </span>
      </div>

      <div class="fpw-headline-row">
        <h1 id="fpwSignupSuccessTitle">Your FloatPlanWizard <span class="fpw-headline-accent">account is ready.</span></h1>
        <span class="fpw-trial-pill">
          <svg class="fpw-inline-icon" viewBox="0 0 24 24" aria-hidden="true" focusable="false">
            <path d="M12 3l2.3 5.2 5.7.6-4.3 3.7 1.3 5.5-5-2.9-5 2.9 1.3-5.5L4 8.8l5.7-.6L12 3z"></path>
          </svg>
          Free Premium trial
        </span>
      </div>

      <p class="fpw-success-lede">
        Start your 30-day Premium trial on FloatPlanWizard to unlock powerful
        trip planning tools, monitored float plans, Active Cruise pages, shared
        trip pages, and marine weather tools. Stripe tracks the subscription,
        but billing is not collected during signup. <strong>No credit card
        required and no payment is due today.</strong>
      </p>

      <div class="fpw-success-actions">
        <button
          class="fpw-btn fpw-btn-primary fpw-trial-activate-btn"
          type="button"
          id="activateLaunchTrialBtn"
          disabled>
          <svg class="fpw-inline-icon" viewBox="0 0 24 24" aria-hidden="true" focusable="false">
            <path d="M5 3v4"></path>
            <path d="M3 5h4"></path>
            <path d="M19 13v4"></path>
            <path d="M17 15h4"></path>
            <path d="M11 6l1.5 3.5L16 11l-3.5 1.5L11 16l-1.5-3.5L6 11l3.5-1.5L11 6z"></path>
          </svg>
          Start Your Free Trial
          <svg class="fpw-inline-icon" viewBox="0 0 24 24" aria-hidden="true" focusable="false">
            <path d="M5 12h14"></path>
            <path d="M13 6l6 6-6 6"></path>
          </svg>
        </button>

        <!---
        <a class="fpw-btn fpw-btn-secondary" href="<cfoutput>#request.fpwBase#</cfoutput>/app/dashboard.cfm">
          <svg class="fpw-inline-icon" viewBox="0 0 24 24" aria-hidden="true" focusable="false">
            <rect x="3" y="3" width="7" height="7"></rect>
            <rect x="14" y="3" width="7" height="7"></rect>
            <rect x="3" y="14" width="7" height="7"></rect>
            <rect x="14" y="14" width="7" height="7"></rect>
          </svg>
          Continue to Dashboard
        </a>
        --->
      </div>

      <div class="fpw-trial-status-panel" id="startTrialMessage" role="status" aria-live="polite">
        <span class="fpw-status-info-icon" aria-hidden="true">
          <svg class="fpw-inline-icon" viewBox="0 0 24 24" focusable="false">
            <circle cx="12" cy="12" r="9"></circle>
            <path d="M12 11v5"></path>
            <path d="M12 7h.01"></path>
          </svg>
        </span>
        <span>Ready to start. <strong>No payment information</strong> is required.</span>
      </div>
    </div>

    <aside class="fpw-premium-trust-card" aria-labelledby="fpwPremiumTrustTitle">
      <div class="fpw-trust-shield" aria-hidden="true">
        <svg class="fpw-inline-icon" viewBox="0 0 24 24" focusable="false">
          <path d="M12 3l7 3v5c0 4.5-2.9 8.4-7 10-4.1-1.6-7-5.5-7-10V6l7-3z"></path>
          <path d="M9 12l2 2 4-5"></path>
        </svg>
      </div>

      <h2 id="fpwPremiumTrustTitle">
        Premium access,<br>
        <span>no credit card required</span>
      </h2>

      <div class="fpw-trust-list">
        <article class="fpw-trust-item">
          <div class="fpw-trust-icon" aria-hidden="true">
            <svg class="fpw-inline-icon" viewBox="0 0 24 24" focusable="false">
              <rect x="3" y="6" width="18" height="12" rx="2"></rect>
              <path d="M3 10h18"></path>
              <path d="M4 20L20 4"></path>
            </svg>
          </div>
          <div>
            <h3>No credit card required</h3>
            <p>Start Premium access without entering payment details.</p>
          </div>
        </article>

        <article class="fpw-trust-item">
          <div class="fpw-trust-icon" aria-hidden="true">
            <svg class="fpw-inline-icon" viewBox="0 0 24 24" focusable="false">
              <circle cx="12" cy="12" r="9"></circle>
              <path d="M12 7v5l3 2"></path>
            </svg>
          </div>
          <div>
            <h3>Premium pauses automatically</h3>
            <p>If you do not add billing, Premium pauses at the end of the trial.</p>
          </div>
        </article>

        <article class="fpw-trust-item">
          <div class="fpw-trust-icon" aria-hidden="true">
            <svg class="fpw-inline-icon" viewBox="0 0 24 24" focusable="false">
              <path d="M12 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8z"></path>
              <path d="M4 21a8 8 0 0 1 16 0"></path>
            </svg>
          </div>
          <div>
            <h3>Your free account remains active</h3>
            <p>You can continue with Basic access if you do nothing.</p>
          </div>
        </article>
      </div>
    </aside>
  </section>

  <section class="fpw-next-steps-panel" aria-labelledby="fpwNextStepsTitle">
    <div class="fpw-section-title-row">
      <span></span>
      <h2 id="fpwNextStepsTitle">What you can do next</h2>
      <span></span>
      <div class="fpw-section-anchor" aria-hidden="true">
        <svg class="fpw-inline-icon" viewBox="0 0 24 24" focusable="false">
          <circle cx="12" cy="5" r="2"></circle>
          <path d="M12 7v13"></path>
          <path d="M5 12h14"></path>
          <path d="M7 18c1.5 2 3.2 3 5 3s3.5-1 5-3"></path>
          <path d="M4 15l3 3 3-3"></path>
          <path d="M14 15l3 3 3-3"></path>
        </svg>
      </div>
    </div>

    <div class="fpw-next-step-grid">
      <article class="fpw-next-step-card">
        <div class="fpw-next-step-icon" aria-hidden="true">
          <svg class="fpw-inline-icon" viewBox="0 0 24 24" focusable="false">
            <path d="M6 6c0 3.2-3 5-3 5s-3-1.8-3-5a3 3 0 0 1 6 0z" transform="translate(3 2)"></path>
            <path d="M21 7c0 3.2-3 5-3 5s-3-1.8-3-5a3 3 0 0 1 6 0z"></path>
            <path d="M8 18c2.5-4 5.5 1 8-3"></path>
            <path d="M9 8h.01"></path>
            <path d="M18 7h.01"></path>
          </svg>
        </div>
        <h3>Build your first route</h3>
        <p>Estimate distance, fuel needs, and trip timing before leaving the dock.</p>
        <a href="<cfoutput>#request.fpwBase#</cfoutput>/app/dashboard.cfm" class="fpw-card-link">Go to Route Builder <svg viewBox="0 0 24 24" aria-hidden="true" focusable="false"><path d="M5 12h14"></path><path d="M13 6l6 6-6 6"></path></svg></a>
      </article>

      <article class="fpw-next-step-card">
        <div class="fpw-next-step-icon" aria-hidden="true">
          <svg class="fpw-inline-icon" viewBox="0 0 24 24" focusable="false">
            <rect x="7" y="4" width="10" height="16" rx="2"></rect>
            <path d="M9 4h6"></path>
            <path d="M9 9h6"></path>
            <path d="M9 13h6"></path>
            <path d="M9 17h4"></path>
          </svg>
        </div>
        <h3>Create a monitored float plan</h3>
        <p>Organize your trip details and emergency contact information.</p>
        <a href="<cfoutput>#request.fpwBase#</cfoutput>/app/dashboard.cfm" class="fpw-card-link">Create Float Plan <svg viewBox="0 0 24 24" aria-hidden="true" focusable="false"><path d="M5 12h14"></path><path d="M13 6l6 6-6 6"></path></svg></a>
      </article>

      <article class="fpw-next-step-card">
        <div class="fpw-next-step-icon" aria-hidden="true">
          <svg class="fpw-inline-icon" viewBox="0 0 24 24" focusable="false">
            <circle cx="12" cy="12" r="9"></circle>
            <circle cx="12" cy="12" r="5"></circle>
            <circle cx="12" cy="12" r="1.5"></circle>
            <path d="M18.5 5.5l-3.8 3.8"></path>
          </svg>
        </div>
        <h3>Use Active Cruise</h3>
        <p>Track underway progress and submit check-ins during the trip.</p>
        <a href="<cfoutput>#request.fpwBase#</cfoutput>/app/active-cruise.cfm" class="fpw-card-link">Open Active Cruise <svg viewBox="0 0 24 24" aria-hidden="true" focusable="false"><path d="M5 12h14"></path><path d="M13 6l6 6-6 6"></path></svg></a>
      </article>

      <article class="fpw-next-step-card">
        <div class="fpw-next-step-icon" aria-hidden="true">
          <svg class="fpw-inline-icon" viewBox="0 0 24 24" focusable="false">
            <path d="M9 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8z"></path>
            <path d="M17 11a3 3 0 1 0 0-6"></path>
            <path d="M2 21a7 7 0 0 1 14 0"></path>
            <path d="M16 15a6 6 0 0 1 6 6"></path>
          </svg>
        </div>
        <h3>Share a trip page</h3>
        <p>Let family or friends follow your trip from a shared page.</p>
        <a href="<cfoutput>#request.fpwBase#</cfoutput>/app/dashboard.cfm" class="fpw-card-link">Create Share Page <svg viewBox="0 0 24 24" aria-hidden="true" focusable="false"><path d="M5 12h14"></path><path d="M13 6l6 6-6 6"></path></svg></a>
      </article>
    </div>
  </section>

  <section class="fpw-safety-strip" aria-label="Safety and privacy note">
    <div class="fpw-safety-icon" aria-hidden="true">
      <svg class="fpw-inline-icon" viewBox="0 0 24 24" focusable="false">
        <path d="M12 3l7 3v5c0 4.5-2.9 8.4-7 10-4.1-1.6-7-5.5-7-10V6l7-3z"></path>
        <path d="M9 12l2 2 4-5"></path>
      </svg>
    </div>
    <div>
      <strong>Your safety and privacy are important to us.</strong>
      <p>Your data is secure and will never be shared without your permission.</p>
    </div>
    <a class="fpw-safety-link" href="<cfoutput>#request.fpwBase#</cfoutput>/privacy_policy.cfm">Learn more about our security <svg viewBox="0 0 24 24" aria-hidden="true" focusable="false"><path d="M5 12h14"></path><path d="M13 6l6 6-6 6"></path></svg></a>
  </section>
</main>

<cfinclude template="../includes/footer_scripts.cfm">
<script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/app/start-trial.js?v=20260709-label"></script>

</body>
</html>








