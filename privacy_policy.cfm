<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Privacy Policy | FloatPlanWizard</title>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="description" content="Privacy Policy for FloatPlanWizard.">
  <cfinclude template="includes/header_styles.cfm">
  <style>
/* =========================================================
   Float Plan Wizard Legal / Privacy Page
   Site-integrated styling
   ========================================================= */

.fpw-legal-page {
  background: #06131d;
  color: #1f2933;
  font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
  line-height: 1.65;
  margin: 0;
}

.fpw-legal-hero {
  background:
    radial-gradient(circle at top right, rgba(71, 190, 168, 0.24), transparent 30rem),
    linear-gradient(135deg, #102033 0%, #17324d 55%, #0f3d42 100%);
  color: #ffffff;
  padding: 3.75rem 1rem 3rem;
  border-bottom: 4px solid #47bea8;
}

.fpw-legal-container {
  width: min(var(--fpw-page-max, 1200px), calc(100% - (var(--fpw-page-gutter, 32px) * 2)));
  max-width: none;
  margin: 0 auto;
  padding: 0;
}

.fpw-legal-main .fpw-legal-container {
  width: min(var(--fpw-narrow-max, 860px), calc(100% - (var(--fpw-page-gutter, 32px) * 2)));
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

.fpw-legal-page .container,
.fpw-legal-page .fpw-container {
  max-width: var(--fpw-page-max, 1200px);
}

@media (max-width: 760px) {
  .fpw-legal-container {
    width: min(var(--fpw-page-max, 1200px), calc(100% - (var(--fpw-page-gutter, 32px) * 2)));
  }

  .fpw-legal-hero {
    padding: 3rem 1rem 2.4rem;
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
    <h1>Privacy Policy</h1>
    <p>
      This Privacy Policy explains how FloatPlanWizard collects, uses, stores, shares, and protects information.
    </p>
    <div class="fpw-legal-meta" aria-label="Privacy Policy metadata">
      <span class="fpw-legal-pill">Effective date: May 28, 2026</span>
      <span class="fpw-legal-pill">Float Plan Wizard LLC</span>
      <span class="fpw-legal-pill">FloatPlanWizard.com</span>
    </div>
  </div>
</header>

<main class="fpw-legal-main">
  <div class="fpw-legal-container fpw-layout-rail">
    <article class="fpw-legal-card">
      <div class="fpw-legal-notice">
        <strong>Privacy notice:</strong>
        This policy describes how FloatPlanWizard handles account, float plan, check-in, location, companion app, billing, and support information.
      </div>

<section class="fpw-legal-section" aria-label="Privacy Policy overview">

  <p>
    This Privacy Policy explains how Float Plan Wizard LLC, doing business as FloatPlanWizard.com
    ("Float Plan Wizard," "Company," "we," "us," or "our"), collects, uses, stores, shares, and protects
    information when you use Float Plan Wizard, including our website, mobile application, companion
    application, account features, route tools, float plan tools, check-in features, monitoring features,
    downloadable documents, public Follow pages, subscriptions, passes, trials, promotions, and related
    services.
  </p>

  <p>
    Float Plan Wizard is intended for users located in the United States. We do not directly target or
    market the Service to users located outside the United States.
  </p>
</section>

<section class="fpw-legal-section">
  <h2>1. Information We Collect</h2>

  <h3>Account Information</h3>
  <p>
    We may collect information you provide when creating or managing an account, including your name,
    email address, password or authentication information, account status, membership level, preferences,
    and related account records.
  </p>

  <h3>Boating, Vessel, Trip, and Float Plan Information</h3>
  <p>
    We may collect information you enter into Float Plan Wizard, including vessel information, operator
    or captain information, passenger information, designated contact information, emergency or rescue
    authority information, route details, waypoints, departure and return information, destination
    information, estimated times, notes, float plan details, fuel-planning information, weather-related
    selections, and other boating trip information.
  </p>

  <h3>Check-In, Monitoring, and Location Information</h3>
  <p>
    We may collect check-in information, including check-in status, date and time, trip status, notes,
    monitoring status, missed check-in information, and related notification records.
  </p>

  <p>
    If you choose to enable or submit location information, we may collect GPS coordinates, location
    timestamps, location accuracy, and related location details from your device or companion application.
    Location information may be unavailable, delayed, inaccurate, or incomplete depending on your device,
    settings, permissions, GPS signal, cellular coverage, internet access, or other conditions.
  </p>

  <p>
    Float Plan Wizard does not continuously track your device unless we clearly disclose that feature and
    you authorize it. For launch, location collection is intended to support user-submitted check-ins and
    related trip records, not continuous live tracking.
  </p>

  <h3>Companion App and Device Information</h3>
  <p>
    If you use the Float Plan Wizard companion application, we may collect information related to pairing,
    authentication, check-in submissions, queued or offline submissions, device platform, app version,
    operating system, permission status, submission identifiers, and related technical records needed to
    operate and secure the companion app.
  </p>

  <h3>Payment and Membership Information</h3>
  <p>
    If you purchase a subscription, pass, trial, promotional offer, Founding Member offer, or other paid
    access, payment may be processed by Stripe or another third-party payment processor. We do not store
    full credit card numbers or full payment card details on our own servers.
  </p>

  <p>
    We may store limited payment-related records, such as Stripe customer identifiers, subscription
    identifiers, price or plan identifiers, transaction references, entitlement status, billing status, promotion
    or redemption records, webhook event records, and related information needed to operate paid access,
    prevent fraud, provide support, and maintain account records.
  </p>

  <h3>Communications and Support Information</h3>
  <p>
    We may collect information when you contact us, submit a support request, respond to emails, receive
    notifications, or communicate with us. This may include your name, email address, message content,
    support history, notification records, and related communications.
  </p>

  <h3>Technical, Usage, Cookie, and Analytics Information</h3>
  <p>
    We may collect technical and usage information, including IP address, browser type, device type,
    operating system, pages viewed, referring pages, dates and times of access, session information,
    error logs, security logs, and other information about how the Service is accessed and used.
  </p>

  <p>
    We may use cookies, local storage, session storage, and similar technologies to operate the Service,
    keep users logged in, secure accounts, remember preferences, support checkout and billing flows,
    prevent abuse, and provide core website and application functionality.
  </p>

  <p>
    We may also use limited analytics tools, such as Google Analytics or similar services, to understand
    site usage and improve Float Plan Wizard. These tools may use cookies or similar technologies to
    collect general usage information.
  </p>
</section>

<section class="fpw-legal-section">
  <h2>2. How We Collect Information</h2>

  <p>We may collect information:</p>

  <ul>
    <li>directly from you when you create an account, enter trip details, create a route, create a float plan, submit a check-in, contact support, or make a purchase;</li>
    <li>from your device or browser when you use the website, mobile application, or companion application;</li>
    <li>from your device location services if you choose to allow location access;</li>
    <li>from payment processors, such as Stripe, when you purchase or manage paid access;</li>
    <li>from email, hosting, analytics, security, and other service providers used to operate the Service; and</li>
    <li>automatically through cookies, logs, analytics, and similar technologies.</li>
  </ul>
</section>

<section class="fpw-legal-section">
  <h2>3. How We Use Information</h2>

  <p>We may use information to:</p>

  <ul>
    <li>create, manage, secure, and support user accounts;</li>
    <li>provide route-planning, float-plan, check-in, monitoring, companion app, and Follow page features;</li>
    <li>generate, store, display, send, and download float plans and related trip documents;</li>
    <li>send trip-related notifications, check-in notices, monitoring notices, account notices, and service emails;</li>
    <li>share float plan or trip information with designated contacts, passengers, operators, or other recipients chosen by the user;</li>
    <li>process subscriptions, passes, trials, promotional offers, Founding Member offers, cancellations, billing status, and account entitlements;</li>
    <li>provide customer support and respond to inquiries;</li>
    <li>operate, maintain, test, secure, troubleshoot, and improve the Service;</li>
    <li>detect, prevent, and investigate fraud, abuse, unauthorized access, technical issues, and security incidents;</li>
    <li>measure usage, improve user experience, and understand how users interact with the Service;</li>
    <li>enforce our Terms of Use and other policies;</li>
    <li>comply with legal obligations, court orders, law enforcement requests, or regulatory requirements; and</li>
    <li>protect the rights, safety, property, and security of Float Plan Wizard, users, and others.</li>
  </ul>
</section>

<section class="fpw-legal-section">
  <h2>4. How Information May Be Shared</h2>

  <h3>With People You Choose</h3>
  <p>
    Float Plan Wizard is designed to help users share boating trip information. If you create a float plan,
    send a float plan, use monitoring features, submit check-ins, create a Private Trip page, or designate
    contacts, we may share relevant trip, vessel, route, passenger, contact, check-in, monitoring, and
    location information with the people or recipients you choose.
  </p>

  <p>
    You are responsible for ensuring that you have permission or authority to submit and share another
    person's information, including passenger information, operator information, designated contact
    information, or emergency contact information.
  </p>

  <h3>Public Follow Pages and Shared Links</h3>
  <p>
    Some features may allow trip information to be displayed through a public or shared Follow page.
    Anyone with access to the link may be able to view the information shown on that page. You should
    not share a Follow page link with anyone you do not want to see the displayed trip information.
  </p>

  <h3>Service Providers</h3>
  <p>
    We may share information with service providers that help us operate the Service, including hosting
    providers, email providers, payment processors, analytics providers, security providers, app stores,
    software vendors, database providers, and support tools. These providers may process information
    only as needed to provide services to us, subject to their own terms, privacy policies, and security
    practices.
  </p>

  <h3>Payment Processors</h3>
  <p>
    Payments may be handled by Stripe or another third-party payment processor. Payment processors
    may collect and process payment information according to their own terms and privacy policies.
    Float Plan Wizard does not store full credit card numbers or full payment card details on its own
    servers.
  </p>

  <h3>Legal, Safety, and Security Reasons</h3>
  <p>
    We may disclose information if we believe disclosure is necessary or appropriate to comply with law,
    respond to legal process, enforce our Terms of Use, investigate fraud or abuse, protect the security
    of the Service, protect our rights or property, or protect the rights, safety, or property of users or
    others.
  </p>

  <h3>Business Transfers</h3>
  <p>
    If Float Plan Wizard is involved in a merger, acquisition, financing, reorganization, bankruptcy, sale
    of assets, or similar business transaction, information may be transferred as part of that transaction,
    subject to applicable law.
  </p>

  <h3>No Sale of Personal Information</h3>
  <p>
    We do not sell personal information for money. We do not use personal information to provide
    emergency rescue, towing, dispatch, insurance underwriting, or professional navigation services.
  </p>
</section>

<section class="fpw-legal-section">
  <h2>5. Location Information</h2>

  <p>
    Float Plan Wizard may collect location information only when supported by the Service and allowed
    by your device settings, app permissions, or user action. Location information may include GPS
    coordinates, accuracy, timestamp, and related check-in details.
  </p>

  <p>
    Location information may be used to record check-ins, support monitoring features, display trip
    progress, provide trip context to designated contacts, maintain trip records, troubleshoot the Service,
    and improve safety-related trip-planning features.
  </p>

  <p>
    You can control mobile location permissions through your device settings. If you disable location
    access, some location-based features may not work or may be incomplete.
  </p>
</section>

<section class="fpw-legal-section">
  <h2>6. Email and Notifications</h2>

  <p>
    We may send service-related emails and notifications, including account emails, verification emails,
    billing emails, float plan emails, check-in emails, monitoring emails, support emails, security emails,
    and important service updates.
  </p>

  <p>
    Some emails are transactional or operational and are necessary to provide the Service. You may not
    be able to opt out of important account, security, billing, or trip-related transactional emails while
    using the Service.
  </p>

  <p>
    If we send marketing emails, you may opt out by using the unsubscribe link or by contacting us.
    Opting out of marketing emails does not opt you out of transactional or service-related emails.
  </p>
</section>

<section class="fpw-legal-section">
  <h2>7. Cookies and Similar Technologies</h2>

  <p>
    Float Plan Wizard may use cookies, local storage, session storage, and similar technologies to operate
    the Service, keep users logged in, secure accounts, remember user preferences, support checkout and
    billing flows, prevent abuse, and provide core website and application functionality.
  </p>

  <p>
    We may also use limited analytics tools to understand how visitors use the Website and to improve
    Float Plan Wizard. These analytics tools may use cookies or similar technologies to collect usage
    information such as pages visited, browser type, device information, approximate location, referral
    source, and general site activity.
  </p>

  <p>
    You can control cookies through your browser settings. If you disable certain cookies, some parts of
    the Service may not function properly, including login, account access, checkout, security features,
    and member tools.
  </p>
</section>

<section class="fpw-legal-section">
  <h2>8. Data Retention</h2>

  <p>
    We retain information for as long as reasonably necessary to operate the Service, maintain user
    accounts, provide trip records, support monitoring and notification features, process payments,
    resolve disputes, enforce our Terms of Use, comply with legal obligations, prevent fraud, maintain
    security, and support legitimate business purposes.
  </p>

  <p>
    Some information may be retained in backups, logs, archives, accounting records, payment records,
    security records, or legal records for a limited period after account closure or deletion.
  </p>

  <p>
    We may retain aggregated, de-identified, or anonymized information that does not reasonably identify
    a specific person.
  </p>
</section>

<section class="fpw-legal-section">
  <h2>9. Your Choices and Controls</h2>

  <p>You may have choices regarding your information, including the ability to:</p>

  <ul>
    <li>access and update account information through your account tools;</li>
    <li>edit or delete certain routes, float plans, contacts, passengers, vessels, or trip details where the Service allows;</li>
    <li>control mobile app location permissions through your device settings;</li>
    <li>control cookies through your browser settings;</li>
    <li>unsubscribe from marketing emails, if any;</li>
    <li>cancel paid subscriptions through the account billing area, Stripe customer portal, or other cancellation method we provide; and</li>
    <li>request access, correction, deletion, or other privacy assistance by contacting us.</li>
  </ul>

  <p>
    We may need to verify your identity before fulfilling certain requests. We may deny or limit requests
    where permitted by law, including when information must be retained for legal, security, fraud
    prevention, billing, dispute resolution, operational, or legitimate business reasons.
  </p>
</section>

<section class="fpw-legal-section">
  <h2>10. State Privacy Rights</h2>

  <p>
    Depending on where you live and whether applicable law applies to Float Plan Wizard, you may have
    certain privacy rights, such as the right to know what personal information is collected, the right to
    request deletion, the right to correct inaccurate information, or the right to opt out of certain uses
    of personal information.
  </p>

  <p>
    Float Plan Wizard is intended for users located in the United States. If you believe a state privacy law
    gives you a specific right regarding your personal information, you may contact us using the contact
    information below.
  </p>

  <p>
    We do not sell personal information for money. If we later use personal information for targeted
    advertising, cross-context behavioral advertising, sale, or sharing as defined by applicable privacy
    laws, we will update this Privacy Policy and provide any required choices.
  </p>
</section>

<section class="fpw-legal-section">
  <h2>11. Security</h2>

  <p>
    We use commercially reasonable administrative, technical, and organizational measures designed to
    protect the Service and user information. However, no website, mobile application, server, network,
    storage system, transmission, payment system, or security measure can be guaranteed to be completely
    secure.
  </p>

  <p>
    You are responsible for protecting your account credentials, using a secure password, keeping your
    devices secure, and notifying us promptly if you believe your account, device, password, companion
    app pairing, or payment-related access has been compromised.
  </p>
</section>

<section class="fpw-legal-section">
  <h2>12. Children's Privacy</h2>

  <p>
    Float Plan Wizard is not intended for children under eighteen (18) years old. We do not knowingly
    collect personal information from children under thirteen (13). If you believe a child has provided
    personal information to us, please contact us so we can review and take appropriate action.
  </p>
</section>

<section class="fpw-legal-section">
  <h2>13. Third-Party Links and Services</h2>

  <p>
    The Service may include links to or integrations with third-party websites, services, payment processors,
    app stores, weather providers, map providers, government resources, towing providers, analytics tools,
    or other third-party services.
  </p>

  <p>
    We are not responsible for the privacy practices, security practices, content, accuracy, availability, or
    policies of third-party services. Your use of third-party services may be governed by their own terms
    and privacy policies.
  </p>
</section>

<section class="fpw-legal-section">
  <h2>14. No Emergency, Rescue, Towing, Dispatch, or Navigation Service</h2>

  <p>
    Float Plan Wizard is an informational boating trip-planning, float-plan, check-in, and notification tool.
    The Service is not an emergency service, rescue service, towing service, dispatch service, vessel-tracking
    service, professional navigation service, marine safety authority, insurance service, or law enforcement
    service.
  </p>

  <p>
    In any emergency, distress situation, suspected emergency, overdue vessel situation, unsafe condition,
    medical emergency, vessel breakdown, fire, collision, grounding, taking on water, person-overboard
    situation, or other urgent condition, you and any other affected person must immediately use official
    and accepted emergency methods, including, as applicable, VHF Channel 16, DSC distress alert, 911,
    the United States Coast Guard, local marine patrol, EPIRB, PLB, flares, sound signals, telephone,
    towing providers, marina personnel, or other appropriate emergency or safety resources.
  </p>
</section>

<section class="fpw-legal-section">
  <h2>15. Changes to This Privacy Policy</h2>

  <p>
    We may update this Privacy Policy from time to time. When we update it, we will revise the effective
    date above. If changes are material, we may provide additional notice through the Website, the Service,
    email, account notice, or other reasonable method.
  </p>

  <p>
    Your continued use of the Service after an updated Privacy Policy becomes effective means you
    acknowledge the updated Privacy Policy.
  </p>
</section>

<section class="fpw-legal-section">
  <h2>16. Contact Us</h2>

  <p>
    If you have questions about this Privacy Policy or want to make a privacy-related request, contact us at:
  </p>

  <p>
    <strong>Float Plan Wizard LLC</strong><br>
    4347 Topsail Trail<br>
    support@floatplanwizard.com<br>
    FloatPlanWizard.com
  </p>
</section>
    </article>
  </div>
</main>

<cfinclude template="includes/footer.cfm">
<cfinclude template="includes/footer_scripts.cfm">
</body>
</html>
