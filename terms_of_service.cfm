<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Terms of Service | FloatPlanWizard</title>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="description" content="Terms of Service for FloatPlanWizard.">
  <cfinclude template="includes/header_styles.cfm">
  <style>
/* =========================================================
   Float Plan Wizard Legal / Terms Page
   Site-integrated styling
   ========================================================= */

.fpw-legal-page {
  background: #06131d;
  color: #1f2933;
  font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
  line-height: 1.65;
  margin: 0;
}

/* Page header */
.fpw-legal-hero {
  background:
    radial-gradient(circle at top right, rgba(71, 190, 168, 0.24), transparent 30rem),
    linear-gradient(135deg, #102033 0%, #17324d 55%, #0f3d42 100%);
  color: #ffffff;
  padding: 3.75rem 1rem 3rem;
  border-bottom: 4px solid #47bea8;
}

.fpw-legal-container {
  width: min(var(--fpw-nav-layout-max, 1480px), calc(100% - 48px));
  max-width: none;
  margin: 0 auto;
  padding: 0;
}

.fpw-legal-kicker {
  color: #82ead7;
  text-transform: uppercase;
  letter-spacing: 0.13em;
  font-size: 0.78rem;
  font-weight: 800;
  margin-bottom: 0.75rem;
}

.fpw-legal-hero h1 {
  color: #ffffff;
  font-size: clamp(2rem, 4vw, 3.2rem);
  line-height: 1.1;
  margin: 0 0 1rem;
  font-weight: 800;
}

.fpw-legal-hero p {
  max-width: 780px;
  color: rgba(255, 255, 255, 0.86);
  font-size: 1.075rem;
  margin: 0;
}

.fpw-legal-meta {
  display: flex;
  flex-wrap: wrap;
  gap: 0.65rem;
  margin-top: 1.5rem;
}

.fpw-legal-pill {
  display: inline-flex;
  align-items: center;
  gap: 0.35rem;
  background: rgba(255, 255, 255, 0.11);
  border: 1px solid rgba(130, 234, 215, 0.32);
  color: #ffffff;
  padding: 0.48rem 0.78rem;
  border-radius: 999px;
  font-size: 0.9rem;
}

/* Main layout */
.fpw-legal-main {
  padding: 2rem 0 4rem;
}

.fpw-legal-card {
  background: #ffffff;
  border: 1px solid #d8e7e4;
  border-radius: 1.15rem;
  box-shadow: 0 18px 48px rgba(16, 32, 51, 0.1);
  padding: clamp(1.25rem, 3vw, 2.35rem);
}

/* Green legal notice - this is the shaded style */
.fpw-legal-notice {
  background: linear-gradient(180deg, #e8f8f3 0%, #f3fbf8 100%);
  border: 1px solid #b8e4d8;
  border-left: 6px solid #2fa88f;
  border-radius: 0.95rem;
  padding: 1.1rem 1.2rem;
  margin-bottom: 2rem;
  color: #183b36;
}

.fpw-legal-notice strong {
  color: #0f4f45;
}

/* More serious warning callout */
.fpw-legal-warning {
  background: linear-gradient(180deg, #eaf8f5 0%, #f7fcfa 100%);
  border: 1px solid #b8e4d8;
  border-left: 6px solid #1e8f78;
  border-radius: 0.95rem;
  padding: 1.15rem 1.2rem;
  margin: 1rem 0 1.25rem;
  color: #183b36;
}

.fpw-legal-warning strong {
  color: #0d5f51;
}

/* Table of contents */
.fpw-legal-toc {
  background: #f7fbfa;
  border: 1px solid #d8e7e4;
  border-radius: 0.95rem;
  padding: 1.25rem;
  margin-bottom: 2rem;
}

.fpw-legal-toc h2 {
  margin: 0 0 0.9rem;
  font-size: 1.15rem;
  color: #102033;
}

.fpw-legal-toc ol {
  columns: 2;
  column-gap: 2rem;
  margin: 0;
  padding-left: 1.25rem;
}

.fpw-legal-toc li {
  break-inside: avoid;
  margin-bottom: 0.45rem;
}

.fpw-legal-toc a {
  color: #176f83;
  text-decoration: none;
  font-weight: 700;
}

.fpw-legal-toc a:hover {
  color: #102033;
  text-decoration: underline;
}

/* Sections */
.fpw-legal-section {
  scroll-margin-top: 7rem;
  padding-top: 1.45rem;
  margin-top: 1.45rem;
  border-top: 1px solid #d8e7e4;
}

.fpw-legal-section:first-of-type {
  border-top: 0;
  margin-top: 0;
  padding-top: 0;
}

.fpw-legal-section h2 {
  color: #102033;
  font-size: clamp(1.32rem, 2vw, 1.72rem);
  line-height: 1.25;
  margin: 0 0 0.9rem;
  font-weight: 800;
}

.fpw-legal-section h3 {
  color: #17324d;
  font-size: 1.08rem;
  margin: 1.25rem 0 0.45rem;
  font-weight: 800;
}

.fpw-legal-section p {
  margin: 0 0 0.95rem;
}

.fpw-legal-section ul {
  margin: 0.35rem 0 1rem;
  padding-left: 1.3rem;
}

.fpw-legal-section li {
  margin-bottom: 0.45rem;
}

.fpw-legal-section a,
.fpw-legal-card a {
  color: #176f83;
  font-weight: 700;
}

.fpw-legal-section a:hover,
.fpw-legal-card a:hover {
  color: #102033;
}

/* Definition box */
.fpw-legal-definition {
  background: #f7fbfa;
  border: 1px solid #d8e7e4;
  border-radius: 0.9rem;
  padding: 1.05rem;
  margin: 1rem 0;
}

.fpw-legal-definition p:last-child {
  margin-bottom: 0;
}

/* Footer note */
.fpw-legal-footer-note {
  margin-top: 2rem;
  padding-top: 1.5rem;
  border-top: 1px solid #d8e7e4;
  color: #64748b;
  font-size: 0.95rem;
}

/* Site integration helpers */
.fpw-legal-page .container,
.fpw-legal-page .fpw-container {
  max-width: var(--fpw-nav-layout-max, 1480px);
}

.fpw-legal-page table {
  width: 100%;
  border-collapse: collapse;
}

.fpw-legal-page code {
  background: #eef6f4;
  color: #17324d;
  border-radius: 0.35rem;
  padding: 0.1rem 0.28rem;
}

/* Mobile */
@media (max-width: 760px) {
  .fpw-legal-container {
    width: min(100% - 28px, var(--fpw-nav-layout-max, 1480px));
  }

  .fpw-legal-hero {
    padding: 3rem 1rem 2.4rem;
  }

  .fpw-legal-toc ol {
    columns: 1;
  }

  .fpw-legal-card {
    border-radius: 0.95rem;
    padding: 1.15rem;
  }

  .fpw-legal-meta {
    gap: 0.5rem;
  }

  .fpw-legal-pill {
    width: 100%;
    justify-content: flex-start;
  }
}
</style>
  </head>
<body class="fpw-legal-page">
<cfinclude template="includes/top_nav.cfm">

<header class="fpw-legal-hero">
  <div class="fpw-legal-container fpw-layout-rail">
    <div class="fpw-legal-kicker">Legal</div>
    <h1>Terms of Service</h1>
    <p>
      These terms explain the rules, responsibilities, limits, and safety notices that apply when using FloatPlanWizard.
    </p>
    <div class="fpw-legal-meta" aria-label="Terms metadata">
      <span class="fpw-legal-pill">Effective date: 2026</span>
      <span class="fpw-legal-pill">FloatPlanWizard.com</span>
    </div>
  </div>
</header>

<main class="fpw-legal-main">
  <div class="fpw-legal-container fpw-layout-rail">
    <article class="fpw-legal-card">
      <div class="fpw-legal-notice">
        <strong>Safety notice:</strong>
        FloatPlanWizard is a boating trip-planning and communication tool. It is not a rescue, dispatch, emergency response, towing, or navigation service.
      </div>
    <nav class="fpw-legal-toc" aria-label="Terms of Use sections">
      <h2>Contents</h2>
      <ol>
        <li><a href="#agreement">Agreement and Acceptance</a></li>
        <li><a href="#definitions">Definitions</a></li>
        <li><a href="#age">Age Restriction</a></li>
        <li><a href="#license">Limited License</a></li>
        <li><a href="#intellectual-property">Intellectual Property</a></li>
        <li><a href="#privacy">Privacy and Data</a></li>
        <li><a href="#user-restrictions">User Restrictions</a></li>
        <li><a href="#boating-safety">Boating Safety Disclaimer</a></li>
        <li><a href="#user-content">User Content and Submitted Information</a></li>
        <li><a href="#account-security">Account Security</a></li>
        <li><a href="#subscriptions">Subscriptions and Payments</a></li>
        <li><a href="#availability">Availability and Data Security</a></li>
        <li><a href="#third-party">Third-Party Services</a></li>
        <li><a href="#support">Support</a></li>
        <li><a href="#malicious-code">Malicious Code and Security Abuse</a></li>
        <li><a href="#warranties">Disclaimers and Warranties</a></li>
        <li><a href="#termination">Termination</a></li>
        <li><a href="#arbitration">Arbitration</a></li>
        <li><a href="#liability">Limitation of Liability</a></li>
        <li><a href="#indemnification">Indemnification</a></li>
        <li><a href="#notices">Notices</a></li>
        <li><a href="#governing-law">Governing Law</a></li>
        <li><a href="#general">General Terms</a></li>
      </ol>
    </nav>

    <section id="agreement" class="fpw-legal-section">
      <h2>1. Agreement and Acceptance</h2>
      <p>
        These Terms of Use, together with any additional terms, policies, notices, disclosures,
        pricing terms, checkout terms, subscription terms, and privacy notices that apply to the
        Service, form an agreement between you and Float Plan Wizard LLC, doing business as
        FloatPlanWizard.com, referred to in these Terms as "Float Plan Wizard," the "Company,"
        "we," "us," or "our."
      </p>
      <p>
        By accessing or using the Website, creating an account, purchasing a subscription or pass,
        accepting a trial or promotional offer, using the mobile application, using the companion
        application, submitting a float plan, sending a check-in, sharing a Follow page, or otherwise
        using the Service, you agree to these Terms.
      </p>
      <p>
        If you do not agree to these Terms, you must not access or use the Service.
      </p>
    </section>

    <section id="definitions" class="fpw-legal-section">
      <h2>2. Definitions</h2>
      <div class="fpw-legal-definition">
        <p>
          <strong>"Service"</strong> means Float Plan Wizard and all related websites, applications,
          companion applications, account tools, route-planning tools, float plan tools, check-in
          features, monitoring features, weather tools, fuel-planning tools, downloadable float plan
          documents, public Follow pages, notifications, subscriptions, passes, trials, promotions,
          and other digital services provided by the Company.
        </p>
        <p>
          <strong>"User," "you," and "your"</strong> mean any person or entity that accesses or uses
          the Service, including free users, paid users, trial users, pass users, Founding Members,
          account holders, visitors, and users of the mobile or companion application.
        </p>
        <p>
          <strong>"User Content"</strong> means information, data, text, route details, vessel details,
          operator details, passenger details, contact details, float plan details, check-in details,
          GPS or location information, notes, files, or other materials that you submit, upload, enter,
          transmit, display, or otherwise provide through the Service.
        </p>
      </div>
    </section>

    <section id="age" class="fpw-legal-section">
      <h2>3. Age Restriction</h2>
      <p>
        You must be at least eighteen (18) years old to create an account, purchase a subscription
        or pass, submit a float plan, use the companion application, or otherwise use the Service.
        By using the Service, you represent and warrant that you are at least eighteen (18) years old
        and are legally able to agree to these Terms.
      </p>
    </section>

    <section id="license" class="fpw-legal-section">
      <h2>4. Limited License to Use the Service</h2>
      <p>
        Subject to your compliance with these Terms, the Company grants you a limited, personal,
        non-exclusive, non-transferable, non-sublicensable, and revocable license to access and use
        the Service for your personal, lawful, recreational boating purposes or other purposes
        expressly authorized by the Company.
      </p>
      <p>
        This license does not give you ownership of the Service, software, design, content, data,
        technology, brand, documentation, or any intellectual property used in or provided through
        the Service.
      </p>
    </section>

    <section id="intellectual-property" class="fpw-legal-section">
      <h2>5. Intellectual Property</h2>
      <p>
        The Service, including its software, design, layout, interfaces, graphics, logos, text,
        documentation, workflows, databases, features, tools, and other materials, is owned by the
        Company or its licensors and is protected by intellectual property and other laws.
      </p>
      <p>
        You may not copy, reproduce, modify, distribute, sell, lease, reverse engineer, scrape,
        harvest, create derivative works from, or otherwise exploit any portion of the Service except
        as expressly allowed by these Terms or by written permission from the Company.
      </p>
    </section>

    <section id="privacy" class="fpw-legal-section">
      <h2>6. Privacy and Data</h2>
      <p>
        Your use of the Service is also governed by our Privacy Policy, which explains how we
        collect, use, store, disclose, and protect information. The Service may collect or process
        account information, vessel information, operator information, passenger information,
        emergency or designated contact information, route information, float plan information,
        check-in information, GPS or location information, device information, payment-related
        references, email notification records, analytics information, and other information needed
        to provide and secure the Service.
      </p>
      <p>
        By using the Service, you authorize the Company to collect, use, store, process, transmit,
        display, and disclose information as described in these Terms, the Privacy Policy, and any
        applicable notices or settings.
      </p>
      <p>
        You are responsible for ensuring that you have the authority or consent needed to submit
        another person's information, including passenger, operator, captain, designated contact, or
        emergency contact information.
      </p>
    </section>

    <section id="user-restrictions" class="fpw-legal-section">
      <h2>7. User Restrictions</h2>
      <p>You agree that you will not use the Service to:</p>
      <ul>
        <li>violate any law, regulation, rule, ordinance, or third-party right;</li>
        <li>submit false, misleading, incomplete, fraudulent, or unauthorized information;</li>
        <li>create false emergency situations, false missed check-ins, false trip status updates, or false location reports;</li>
        <li>harass, mislead, spam, alarm, abuse, threaten, or improperly contact any person;</li>
        <li>publish, distribute, or exploit Service content outside the Service without permission;</li>
        <li>transfer, resell, sublicense, share, or commercially exploit account access or Service features;</li>
        <li>copy, scrape, harvest, reverse engineer, probe, scan, test, overload, damage, disable, or interfere with the Service;</li>
        <li>attempt to bypass security, membership restrictions, payment controls, rate limits, authentication, authorization, or access controls;</li>
        <li>attempt to gain unauthorized access to accounts, servers, APIs, databases, payment systems, source code, or related systems;</li>
        <li>introduce viruses, spyware, malware, ransomware, worms, trojans, keyloggers, rootkits, or other harmful code;</li>
        <li>use the Service to build, train, support, or improve a competing product or service without written permission;</li>
        <li>use the Service as a substitute for official emergency communication, rescue, dispatch, towing, Coast Guard, 911, VHF Channel 16, DSC distress, EPIRB, PLB, flares, or other accepted emergency procedures; or</li>
        <li>use the Service for commercial marine operations, passenger-for-hire operations, charter operations, towing, rescue, dispatch, insurance underwriting, professional navigation, or other professional or safety-critical services unless expressly authorized in writing by the Company.</li>
      </ul>
    </section>

    <section id="boating-safety" class="fpw-legal-section">
      <h2>8. Boating Safety; No Emergency, Rescue, Towing, Dispatch, or Navigation Service</h2>

      <div class="fpw-legal-warning">
        <strong>Float Plan Wizard is not an emergency service.</strong>
        In an emergency or distress situation, use official emergency methods immediately.
      </div>

      <p>
        Float Plan Wizard is an informational boating trip-planning, float-plan, check-in, and
        notification tool. The Service is provided to help Users organize boating trip information,
        share float plan details, record check-ins, and provide trip-related information to designated
        contacts. The Service is not an emergency service, rescue service, towing service, dispatch
        service, vessel-tracking service, professional navigation service, marine safety authority,
        insurance service, or law enforcement service.
      </p>

      <p>
        You understand and agree that Float Plan Wizard does not replace, supplement, or guarantee
        access to official emergency communication channels or emergency response resources.
        In any emergency, distress situation, suspected emergency, overdue vessel situation, unsafe
        condition, medical emergency, vessel breakdown, fire, collision, grounding, taking on water,
        person-overboard situation, or other urgent condition, you and any other affected person
        must immediately use official and accepted emergency methods, including, as applicable,
        VHF Channel 16, DSC distress alert, 911, the United States Coast Guard, local marine patrol,
        EPIRB, PLB, flares, sound signals, telephone, towing providers, marina personnel, or other
        appropriate emergency or safety resources.
      </p>

      <p>
        You remain solely responsible for all decisions before, during, and after a boating trip,
        including route selection, navigation, weather evaluation, tide and current evaluation, fuel
        planning, vessel condition, equipment readiness, crew and passenger safety, communication
        methods, legal compliance, and emergency preparedness. You shall not rely on the Service
        as the sole source of information for navigation, weather, vessel operation, trip safety,
        emergency response, or compliance with boating laws or regulations.
      </p>

      <p>
        Any route, waypoint, ETA, check-in, monitoring status, weather information, fuel estimate,
        float plan document, GPS or location information, notification, or Private Trip
        information provided through the Service is for convenience and informational purposes
        only. Such information may be incomplete, delayed, inaccurate, unavailable, interrupted, or
        affected by user error, device settings, GPS limitations, internet service, cellular coverage,
        email delivery, third-party data providers, hosting providers, software errors, or other
        conditions outside the Company's control.
      </p>

      <p>
        You understand and agree that check-in reminders, missed check-in notices, monitoring
        emails, Private Trip updates, and contact notifications are not emergency alerts and
        do not guarantee that any person, designated contact, authority, towing provider, rescue
        provider, or emergency responder will receive, review, understand, act upon, or respond to
        any information. You are solely responsible for ensuring that appropriate people know the
        trip plan, understand their role, and know when and how to contact official emergency
        services if necessary.
      </p>

      <p>
        You shall not use the Service to create, report, simulate, or imply an emergency response
        request, distress call, rescue request, towing request, law enforcement request, or dispatch
        request. Float Plan Wizard has no obligation to monitor trips in real time, contact emergency
        services, contact towing providers, verify vessel status, verify location, confirm user safety,
        or initiate any rescue, dispatch, towing, or emergency response action.
      </p>

      <p>
        To the fullest extent permitted by law, the Company disclaims liability for any loss, injury,
        death, property damage, delay, missed communication, failed notification, inaccurate location,
        inaccurate route, inaccurate weather information, inaccurate ETA, failure to check in, failure
        of a contact to respond, failure of emergency services to respond, or other harm arising from
        or related to your use of, misuse of, or reliance on the Service.
      </p>
    </section>

    <section id="user-content" class="fpw-legal-section">
      <h2>9. User Content and Submitted Information</h2>
      <p>
        You retain any rights you have in the information you submit through the Service. By
        submitting User Content, you grant the Company a limited license to use, store, process,
        transmit, display, reproduce, and disclose that information only as reasonably necessary to
        operate, provide, secure, support, maintain, and improve the Service.
      </p>
      <p>
        This includes using submitted information to create and store float plans, generate
        downloadable float plan documents, display route and trip information, process check-ins,
        provide account features, provide companion app features, send notifications, operate
        public Follow pages, provide support, prevent abuse, maintain security, and comply with
        applicable legal obligations.
      </p>
      <p>
        You represent and warrant that your User Content is accurate to the best of your knowledge,
        that you have the right to submit it, and that submitting it does not violate any law or
        third-party right.
      </p>
    </section>

    <section id="account-security" class="fpw-legal-section">
      <h2>10. Account Security</h2>
      <p>
        You are responsible for maintaining the confidentiality of your account credentials, including
        your username, password, device access, companion app pairing, and any other authentication
        method used with the Service.
      </p>
      <p>
        You are responsible for all activity that occurs under your account unless caused by the
        Company's own willful misconduct or as otherwise required by law. You agree to notify the
        Company promptly if you believe your account, password, device, companion app pairing, or
        payment-related access has been compromised.
      </p>
    </section>

    <section id="subscriptions" class="fpw-legal-section">
      <h2>11. Subscriptions, Trials, Payments, Cancellations, and Refunds</h2>
      <p>
        Float Plan Wizard may offer free access, paid subscriptions, short-term passes, promotional
        access, trials, Founding Member offers, and other membership or access plans from time to
        time. Available plans, features, prices, billing periods, trial periods, promotions, and limitations
        will be disclosed on the Website, in the mobile application, at checkout, or in other offer
        materials provided by the Company.
      </p>

      <h3>Free Tier</h3>
      <p>
        The Company may offer a free tier or free membership level with limited access to certain
        features. Free access may include restrictions on saved routes, float plans, waypoints, trip
        duration, monitoring features, Follow pages, Active Cruise features, companion app features,
        or other functionality. The Company may modify, limit, suspend, or discontinue free features
        at any time, subject to applicable law.
      </p>

      <h3>Premium Monthly Subscription</h3>
      <p>
        Premium Monthly access is a recurring monthly subscription. Unless canceled before the
        next billing date, the subscription will automatically renew each month, and the payment
        method on file with the payment processor will be charged the then-current monthly
        subscription price plus any applicable taxes or fees.
      </p>
      <p>
        Premium Monthly access is month-to-month. There is no annual contract for the monthly
        subscription. Users may cancel anytime as described below. Cancellation stops future monthly
        renewal charges but does not automatically refund amounts already charged unless otherwise
        stated by the Company or required by law.
      </p>

      <h3>Premium Annual Subscription</h3>
      <p>
        Premium Annual access is a recurring annual subscription. Unless canceled before the next
        billing date, the subscription will automatically renew each year, and the payment method on
        file with the payment processor will be charged the then-current annual subscription price
        plus any applicable taxes or fees.
      </p>
      <p>
        Annual subscriptions may provide a discounted rate compared to monthly billing.
        Cancellation stops future annual renewal charges but does not automatically refund amounts
        already charged unless otherwise stated by the Company or required by law.
      </p>

      <h3>3-Day Pass</h3>
      <p>
        The Company may offer a short-term 3-Day Pass or similar limited-duration access plan.
        Unless expressly stated otherwise at checkout, a 3-Day Pass is a one-time, non-recurring
        purchase and does not automatically renew. Access begins and ends according to the pass
        terms shown at purchase or activation. A 3-Day Pass does not create an ongoing subscription
        unless the User separately purchases or activates a recurring subscription.
      </p>

      <h3>Launch Trial or Promotional Trial</h3>
      <p>
        The Company may offer a launch trial, free trial, discounted trial, promotional trial, or other
        temporary access offer. Trial terms, duration, included features, limitations, eligibility
        requirements, and whether payment information is required will be disclosed at signup or
        checkout.
      </p>
      <p>
        If a trial does not require payment information, access will expire at the end of the trial
        period unless the User upgrades or otherwise obtains continued access.
      </p>
      <p>
        If a trial requires payment information and states that it will convert to a paid subscription,
        the User will be charged for the selected subscription plan at the end of the trial period unless
        the User cancels before the trial ends. The amount, billing period, and renewal terms will be
        disclosed before the User submits payment information.
      </p>

      <h3>Founding Member or Lifetime Offer</h3>
      <p>
        The Company may offer a limited Founding Member, lifetime Premium, early-supporter,
        invite-only, promotional, or similar one-time access offer. Unless the offer materials state
        otherwise, a Founding Member or lifetime Premium offer is limited to one account, is
        non-transferable, may not be resold, may not be publicly posted or shared, and applies only
        to the Float Plan Wizard service for the life of the Float Plan Wizard service.
      </p>
      <p>
        A Founding Member or lifetime Premium offer is not a recurring subscription and does not
        create monthly or annual renewal charges. Unless expressly stated otherwise, lifetime access
        does not include separately priced future third-party services, pass-through fees, standalone
        products, professional services, hardware, emergency services, towing services, insurance,
        or other services that the Company may later offer separately.
      </p>
      <p>
        The Company may limit Founding Member or lifetime offers by date, invitation, account,
        email address, redemption code, number of redemptions, or other eligibility criteria. The
        Company may reject, cancel, or revoke any promotional redemption that is fraudulent,
        abusive, unauthorized, transferred, resold, publicly distributed, or otherwise inconsistent
        with the offer terms.
      </p>

      <h3>Payment Processor</h3>
      <p>
        Payments may be processed by Stripe or another third-party payment processor. By
        purchasing a subscription, pass, trial, promotional offer, or other paid access, the User
        authorizes the applicable payment processor to charge the selected payment method
        according to the plan, price, billing period, taxes, fees, and renewal terms disclosed at
        checkout.
      </p>
      <p>
        The Company does not store full credit card numbers or full payment card details on its own
        servers. Payment information is handled by the payment processor according to that
        processor's own terms, privacy policy, and security practices. The Company may store limited
        payment-related records, such as customer identifiers, subscription identifiers, transaction
        references, entitlement status, billing status, and related records needed to operate the
        Service, provide support, prevent fraud, and maintain account access.
      </p>

      <h3>Access and Entitlement Confirmation</h3>
      <p>
        Paid, trial, promotional, Premium, Founding Member, or pass-based access is not guaranteed
        merely because a User visits a success page, receives a checkout redirect, or begins a checkout
        process. Access is granted only after the Company confirms the applicable payment, trial,
        promotional redemption, subscription status, pass purchase, or entitlement through its
        systems, payment processor records, verified webhook processing, or other approved
        account-access records.
      </p>
      <p>
        The Company may delay, deny, suspend, revoke, or correct access if payment fails, a
        transaction is reversed, a subscription is canceled or unpaid, a promotional code is invalid
        or misused, a trial is ineligible, a chargeback occurs, fraud is suspected, or account access
        was granted in error.
      </p>

      <h3>Cancellations</h3>
      <p>
        Users may cancel recurring subscriptions at any time through the account billing area, the
        payment processor's customer portal, or another cancellation method made available by the
        Company. For monthly subscriptions, cancellation means there is no annual contract and no
        future monthly renewal after the current paid period ends. For annual subscriptions,
        cancellation stops the next annual renewal after the current paid period ends.
      </p>
      <p>
        Unless otherwise stated or required by law, canceling a subscription does not immediately
        terminate access already paid for. The User may continue to have access through the end of
        the current billing period, trial period, pass period, or other applicable access period.
      </p>
      <p>
        Deleting an account, uninstalling the mobile application, failing to use the Service, failing to
        check in, or failing to access the Website does not automatically cancel a paid subscription
        unless the Company's billing system or payment processor confirms cancellation.
      </p>

      <h3>Refunds</h3>
      <p>
        Except where required by law or expressly stated in a specific offer, all fees, subscriptions,
        passes, promotional purchases, Founding Member purchases, and other charges are
        non-refundable once charged. The Company may, in its sole discretion, issue refunds, credits,
        extensions, or other accommodations, but doing so in one case does not require the Company
        to do so in any other case.
      </p>
      <p>
        Refund requests may be reviewed based on factors such as duplicate charges, billing error,
        technical issue, fraud, account status, promotional terms, timing of the request, amount of
        Service usage, and applicable law. Third-party payment processor fees, app store fees, taxes,
        and pass-through charges may not be refundable.
      </p>

      <h3>Price and Plan Changes</h3>
      <p>
        The Company may change plan names, features, prices, billing periods, promotions, free-tier
        limits, trial terms, pass terms, and membership benefits from time to time. Any price change
        for an existing recurring subscription will apply only as permitted by applicable law and
        payment processor rules. Continued use of the Service after the effective date of a change
        may require acceptance of the updated terms, payment terms, or plan terms.
      </p>

      <h3>Taxes and Failed Payments</h3>
      <p>
        Prices may not include applicable taxes, fees, or government charges unless stated otherwise.
        The User is responsible for any taxes or fees associated with purchases or subscriptions.
      </p>
      <p>
        If a payment fails, is declined, is disputed, is reversed, or cannot be processed, the Company
        may suspend, downgrade, limit, or terminate paid access until payment is successfully
        completed or the account is otherwise brought current.
      </p>
    </section>

    <section id="availability" class="fpw-legal-section">
      <h2>12. Availability, Data Security, and Data Loss</h2>
      <p>
        The Company uses commercially reasonable measures designed to protect the Service and
        user information. However, no website, mobile application, server, network, storage system,
        transmission, notification system, payment system, or security measure can be guaranteed
        to be completely secure, uninterrupted, or error-free.
      </p>
      <p>
        You understand that the Service may be unavailable, delayed, interrupted, inaccurate, limited,
        modified, suspended, or discontinued due to maintenance, hosting issues, third-party provider
        issues, software errors, weather-data provider issues, map provider issues, payment processor
        issues, email-delivery issues, app store issues, security events, internet service issues, cellular
        coverage limitations, device limitations, or other circumstances.
      </p>
      <p>
        You are responsible for maintaining your own records, backups, copies, and offline access to
        any information you consider important, including float plans, routes, vessel information,
        passenger information, contact information, and trip details.
      </p>
    </section>

    <section id="third-party" class="fpw-legal-section">
      <h2>13. Third-Party Services, Links, Data, and Content</h2>
      <p>
        The Service may include, rely on, or link to third-party websites, applications, payment
        processors, email providers, hosting providers, map providers, weather providers, marine data
        providers, analytics providers, app stores, towing providers, government resources, or other
        third-party services.
      </p>
      <p>
        The Company does not control and is not responsible for third-party services, content,
        policies, data, availability, accuracy, security, or practices. Your use of third-party services
        may be governed by separate terms and privacy policies.
      </p>
    </section>

    <section id="support" class="fpw-legal-section">
      <h2>14. Support</h2>
      <p>
        The Company may provide customer support by email, support forms, account tools, or other
        support methods made available by the Company. The Company does not guarantee any
        particular response time, resolution time, support channel, availability of support, or correction
        of every issue.
      </p>
      <p>
        Support is provided for the Service as offered by the Company. The Company is not
        responsible for supporting third-party devices, third-party software, third-party services,
        user-modified systems, unsupported browsers, unsupported operating systems, or conditions
        outside the Company's reasonable control.
      </p>
    </section>

    <section id="malicious-code" class="fpw-legal-section">
      <h2>15. Malicious Code and Security Abuse</h2>
      <p>
        You agree not to knowingly introduce, upload, transmit, or attempt to use any spyware,
        adware, ransomware, rootkit, keylogger, virus, trojan, worm, exploit, bot, script, scraper,
        credential stuffing tool, denial-of-service tool, or other code or mechanism designed to
        damage, disrupt, overload, access, monitor, control, copy, extract, or interfere with the Service,
        Company systems, User accounts, User Content, payment systems, or related systems.
      </p>
      <p>
        The Company may investigate, suspend, block, remove, or report activity that it reasonably
        believes is abusive, fraudulent, unlawful, harmful, unsafe, or inconsistent with these Terms.
      </p>
    </section>

    <section id="warranties" class="fpw-legal-section">
      <h2>16. Disclaimers and Warranties</h2>
      <p>
        The Service is provided on an "as is" and "as available" basis. To the fullest extent permitted
        by law, the Company disclaims all warranties, whether express, implied, statutory, or otherwise,
        including warranties of merchantability, fitness for a particular purpose, title, non-infringement,
        accuracy, availability, reliability, security, uninterrupted operation, and error-free operation.
      </p>
      <p>
        The Company does not warrant that the Service will meet your requirements, operate without
        interruption, be accurate or complete, prevent accidents, prevent emergencies, ensure safe
        navigation, ensure contact response, ensure emergency response, or be free from defects,
        errors, delays, viruses, harmful code, data loss, or security incidents.
      </p>
    </section>

    <section id="termination" class="fpw-legal-section">
      <h2>17. Termination</h2>
      <p>
        You may stop using the Service at any time. You may cancel paid subscriptions according to
        the cancellation process described in these Terms and in the applicable billing tools.
      </p>
      <p>
        The Company may suspend, limit, downgrade, or terminate your account, access, subscription,
        pass, trial, promotion, or use of the Service at any time if you violate these Terms, misuse the
        Service, create risk or possible legal exposure, fail to pay amounts due, submit false information,
        misuse promotional access, interfere with the Service, or engage in activity that the Company
        reasonably believes is unlawful, unsafe, abusive, fraudulent, or harmful.
      </p>
      <p>
        Termination does not limit any rights or remedies available to the Company and does not
        relieve you of obligations that accrued before termination.
      </p>
    </section>

    <section id="arbitration" class="fpw-legal-section">
      <h2>18. Arbitration</h2>
      <p>
        To the fullest extent permitted by law, any dispute, claim, or controversy arising out of or
        relating to these Terms or the Service shall be resolved by binding arbitration before one (1)
        neutral arbitrator, rather than in court, except for claims that may be brought in small claims
        court or claims for injunctive or equitable relief as permitted by law.
      </p>
      <p>
        The arbitration shall take place in Florida unless the parties agree otherwise or unless
        applicable consumer law requires another location or procedure. The arbitrator shall have
        authority to resolve disputes regarding the interpretation, applicability, enforceability, or
        formation of this arbitration provision, subject to applicable law.
      </p>
      <p>
        Nothing in this section prevents either party from seeking temporary or preliminary injunctive
        relief in a court of competent jurisdiction to protect intellectual property, confidential
        information, account security, system security, or to prevent unauthorized use or abuse of the
        Service.
      </p>
      <p>
        <strong>Attorney review recommended:</strong> Arbitration provisions for consumer services can be
        highly state-specific and should be reviewed before publication.
      </p>
    </section>

    <section id="liability" class="fpw-legal-section">
      <h2>19. Limitation of Liability</h2>
      <p>
        To the fullest extent permitted by law, the Company and its owners, officers, employees,
        contractors, affiliates, service providers, licensors, and agents shall not be liable for any
        indirect, incidental, consequential, special, exemplary, punitive, or enhanced damages, or for
        lost profits, lost revenue, lost data, loss of goodwill, business interruption, personal injury,
        death, property damage, vessel damage, missed communication, failed notification, inaccurate
        location, inaccurate route, inaccurate weather information, inaccurate ETA, failure to check in,
        failure of a contact to respond, or failure of emergency services to respond, arising out of or
        relating to your use of or inability to use the Service.
      </p>
      <p>
        To the fullest extent permitted by law, the Company's total liability for any claim arising out
        of or relating to the Service or these Terms shall not exceed the greater of the amount you
        paid to the Company for the Service during the three (3) months before the event giving rise
        to the claim or one hundred dollars ($100).
      </p>
      <p>
        Some jurisdictions do not allow certain limitations of liability, so some limitations may not
        apply to you.
      </p>
    </section>

    <section id="indemnification" class="fpw-legal-section">
      <h2>20. Indemnification</h2>
      <p>
        To the fullest extent permitted by law, you agree to indemnify, defend, and hold harmless
        the Company and its owners, officers, employees, contractors, affiliates, service providers,
        licensors, and agents from and against any claims, liabilities, damages, losses, costs, and
        expenses, including reasonable attorney's fees, arising out of or relating to your use or misuse
        of the Service, your User Content, your violation of these Terms, your violation of law, your
        violation of any third-party right, your boating activities, your submitted trip or contact
        information, or your failure to obtain required permission to submit another person's
        information.
      </p>
    </section>

    <section id="notices" class="fpw-legal-section">
      <h2>21. Notices</h2>
      <p>
        The Company may provide notices by posting them on the Website, displaying them in the
        Service, sending them to the email address associated with your account, or using other
        reasonable methods.
      </p>
      <p>
        Legal notices to the Company should be sent to:
      </p>
      <p>
        <strong>Float Plan Wizard LLC</strong><br>
        4347 Topsail Trail<br>
        New Port Richey, FL 34652<br>
        support@floatplanwizard.com
      </p>
    </section>

    <section id="governing-law" class="fpw-legal-section">
      <h2>22. Governing Law</h2>
      <p>
        These Terms shall be governed by and construed in accordance with the laws of the State of
        Florida, without regard to conflict-of-law principles, except to the extent that applicable law
        requires otherwise.
      </p>
      <p>
        Subject to the arbitration section above, any court proceeding arising out of or relating to
        these Terms or the Service shall be brought in a court of competent jurisdiction in Florida,
        and the parties consent to the jurisdiction and venue of such courts, except to the extent
        applicable law requires otherwise.
      </p>
    </section>

    <section id="general" class="fpw-legal-section">
      <h2>23. General Terms</h2>

      <h3>Severability</h3>
      <p>
        If any provision of these Terms is found to be invalid, unlawful, or unenforceable, that
        provision shall be limited or removed to the minimum extent necessary, and the remaining
        provisions shall remain in full force and effect.
      </p>

      <h3>No Waiver</h3>
      <p>
        The Company's failure to enforce any provision of these Terms does not waive the Company's
        right to enforce that provision or any other provision later.
      </p>

      <h3>Assignment</h3>
      <p>
        You may not assign or transfer your rights or obligations under these Terms without the
        Company's prior written consent. The Company may assign or transfer these Terms in
        connection with a merger, acquisition, sale of assets, reorganization, change of control, or
        other business transaction.
      </p>

      <h3>Changes to These Terms</h3>
      <p>
        The Company may update these Terms from time to time. Updated Terms will be posted on
        the Website or otherwise made available through the Service. Continued use of the Service
        after updated Terms become effective means you accept the updated Terms.
      </p>

      <h3>Entire Agreement</h3>
      <p>
        These Terms, together with the Privacy Policy and any additional terms, notices, disclosures,
        checkout terms, plan terms, or policies that apply to the Service, constitute the entire
        agreement between you and the Company regarding the Service and replace any prior or
        inconsistent understandings regarding the Service.
      </p>
    </section>

    <div class="fpw-legal-footer-note">
      <p>
        This page is intended as website Terms of Use copy for Float Plan Wizard. Replace bracketed
        placeholders before publishing, including the legal company name, effective date, mailing
        address, and legal/support email address.
      </p>
    </div>
  </article>
</div>
</main>

<cfinclude template="includes/footer.cfm">
<cfinclude template="includes/footer_scripts.cfm">
</body>
</html>
