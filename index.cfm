

<cfprocessingdirective pageencoding="utf-8">
<cfsetting showdebugoutput="false" requesttimeout="30">

<cfscript>
function fpwJsonResponse(required struct payload, numeric statusCode = 200) {
  cfheader(statuscode = arguments.statusCode);
  cfcontent(type = "application/json; charset=utf-8", reset = true);
  writeOutput(serializeJSON(arguments.payload));
  abort;
}

function fpwGetDatasource() {
  if (structKeyExists(application, "dsn") AND len(trim(toString(application.dsn)))) {
    return trim(toString(application.dsn));
  }
  return "fpw";
}

function fpwSafeString(required any value, numeric maxLen = 255) {
  var output = "";
  if (NOT isNull(arguments.value)) {
    output = trim(toString(arguments.value));
  }
  if (arguments.maxLen GT 0 AND len(output) GT arguments.maxLen) {
    output = left(output, arguments.maxLen);
  }
  return output;
}

function fpwNormalizeEmail(required string rawEmail) {
  return lcase(trim(arguments.rawEmail));
}

function fpwIsValidEmail(required string email) {
  var e = lcase(trim(arguments.email));
  var localPart = "";
  var domainPart = "";
  var labels = [];
  var label = "";
  var tld = "";
  var i = 0;

  if (NOT len(e) OR len(e) GT 254) {
    return false;
  }

  if (reFind("\s", e)) {
    return false;
  }

  if (listLen(e, "@") NEQ 2) {
    return false;
  }

  localPart = listFirst(e, "@");
  domainPart = listLast(e, "@");

  if (NOT len(localPart) OR len(localPart) GT 64) {
    return false;
  }
  if (left(localPart, 1) EQ "." OR right(localPart, 1) EQ "." OR find("..", localPart)) {
    return false;
  }
  if (reFindNoCase("^[A-Z0-9!##$%&'*+/=?^_`{|}~.-]+$", localPart) EQ 0) {
    return false;
  }

  if (NOT len(domainPart) OR len(domainPart) GT 253) {
    return false;
  }
  if (find("..", domainPart) OR listLen(domainPart, ".") LT 2) {
    return false;
  }

  labels = listToArray(domainPart, ".");
  for (i = 1; i LTE arrayLen(labels); i = i + 1) {
    label = labels[i];
    if (NOT len(label) OR len(label) GT 63) {
      return false;
    }
    if (left(label, 1) EQ "-" OR right(label, 1) EQ "-") {
      return false;
    }
    if (reFindNoCase("^[A-Z0-9-]+$", label) EQ 0) {
      return false;
    }
  }

  tld = labels[arrayLen(labels)];
  if (
    reFindNoCase("^[A-Z]{2,24}$", tld) EQ 0
    AND
    reFindNoCase("^XN--[A-Z0-9-]{2,59}$", tld) EQ 0
  ) {
    return false;
  }

  return true;
}

function fpwClientIp() {
  var forwarded = structKeyExists(cgi, "http_x_forwarded_for") ? fpwSafeString(cgi.http_x_forwarded_for, 500) : "";
  if (len(forwarded)) {
    return fpwSafeString(listFirst(forwarded, ","), 45);
  }
  return structKeyExists(cgi, "remote_addr") ? fpwSafeString(cgi.remote_addr, 45) : "";
}

function fpwBuildUnsubscribeLink(required string email, required string baseUrl) {
  var safeBaseUrl = trim(arguments.baseUrl);
  var separator = find("?", safeBaseUrl) ? "&" : "?";
  return safeBaseUrl & separator & "email=" & urlEncodedFormat(arguments.email);
}

function fpwSendPrelaunchWelcomeEmail(required string recipientEmail, required struct mailConfig) {
  var unsubscribeLink = fpwBuildUnsubscribeLink(arguments.recipientEmail, arguments.mailConfig.unsubscribeBaseUrl);
  var fromAddress = trim(arguments.mailConfig.fromAddress);
  var fromDisplayName = trim(arguments.mailConfig.fromDisplayName);
  var fromValue = len(fromDisplayName) ? fromDisplayName & " <" & fromAddress & ">" : fromAddress;
  var replyTo = structKeyExists(arguments.mailConfig, "replyTo") ? trim(arguments.mailConfig.replyTo) : "";
  var mailAttrs = {
    to = arguments.recipientEmail,
    from = fromValue,
    subject = "Thanks for joining the FloatPlanWizard launch list",
    type = "text",
    charset = "utf-8"
  };
  var mailBody = arrayToList(
    [
      "Hello,",
      "",
      "Thank you for signing up to be notified about the upcoming launch of FloatPlanWizard.",
      "",
      "FloatPlanWizard was originally launched in 2018 and is now being completely rebuilt as a modern platform for recreational boaters who want a better way to organize trips, create detailed float plans, and keep family or friends informed while on the water.",
      "",
      "The new version is scheduled to launch in Spring 2026.",
      "",
      "Between now and launch you may receive a few brief updates about the progress of the platform and when it becomes available. These messages are limited to launch-related updates only, and your email address will never be sold or shared.",
      "",
      "If you were a member of the earlier version of FloatPlanWizard, you will receive instructions after launch explaining how to access the new platform.",
      "",
      "If you would prefer not to receive these updates, you can unsubscribe at any time using the link below:",
      "",
      "Unsubscribe:",
      unsubscribeLink,
      "",
      "Thank you again for your interest in FloatPlanWizard.",
      "",
      "- FloatPlanWizard",
      "https://FloatPlanWizard.com",
      "",
      "FloatPlanWizard",
      "United States"
    ],
    chr(10)
  );

  if (len(replyTo)) {
    mailAttrs.replyto = replyTo;
  }

  cfmail(attributeCollection = mailAttrs) {
    writeOutput(mailBody);
  }
}

// Welcome / Thank-you email configuration (prelaunch self-contained).
// Replace unsubscribeBaseUrl with the live unsubscribe endpoint when ready.
prelaunchWelcomeEmailConfig = {
  fromAddress = "no-reply@floatplanwizard.com",
  fromDisplayName = "FloatPlanWizard",
  replyTo = "",
  unsubscribeBaseUrl = "https://FloatPlanWizard.com/unsubscribe.cfm"
};

isEarlyAccessPost = structKeyExists(cgi, "request_method")
  AND ucase(cgi.request_method) EQ "POST"
  AND (
    (structKeyExists(url, "action") AND lcase(fpwSafeString(url.action, 40)) EQ "earlyaccesssignup")
    OR
    (structKeyExists(form, "action") AND lcase(fpwSafeString(form.action, 40)) EQ "earlyaccesssignup")
  );

if (isEarlyAccessPost) {
  try {
    email = structKeyExists(form, "email") ? fpwNormalizeEmail(form.email) : "";
    if (NOT fpwIsValidEmail(email)) {
      fpwJsonResponse(
        {
          "SUCCESS" = false,
          "success" = false,
          "code" = "INVALID_EMAIL",
          "message" = "Please enter a valid email address."
        },
        400
      );
    }

    source = structKeyExists(form, "source") ? fpwSafeString(form.source, 80) : "";
    if (NOT len(source) AND structKeyExists(url, "source")) {
      source = fpwSafeString(url.source, 80);
    }
    if (NOT len(source)) {
      source = "prelaunch";
    }

    referrer = structKeyExists(cgi, "http_referer") ? fpwSafeString(cgi.http_referer, 255) : "";
    userAgent = structKeyExists(cgi, "http_user_agent") ? fpwSafeString(cgi.http_user_agent, 255) : "";
    ipAddress = fpwClientIp();

    utmSource = structKeyExists(form, "utm_source") ? fpwSafeString(form.utm_source, 100) : "";
    utmMedium = structKeyExists(form, "utm_medium") ? fpwSafeString(form.utm_medium, 100) : "";
    utmCampaign = structKeyExists(form, "utm_campaign") ? fpwSafeString(form.utm_campaign, 100) : "";
    if (NOT len(utmSource) AND structKeyExists(url, "utm_source")) {
      utmSource = fpwSafeString(url.utm_source, 100);
    }
    if (NOT len(utmMedium) AND structKeyExists(url, "utm_medium")) {
      utmMedium = fpwSafeString(url.utm_medium, 100);
    }
    if (NOT len(utmCampaign) AND structKeyExists(url, "utm_campaign")) {
      utmCampaign = fpwSafeString(url.utm_campaign, 100);
    }

    dsn = fpwGetDatasource();
    existingQ = queryExecute(
      "SELECT id FROM fpw_early_access WHERE email = :email LIMIT 1",
      {
        email = { value = email, cfsqltype = "cf_sql_varchar" }
      },
      { datasource = dsn }
    );
    alreadyOnList = existingQ.recordCount GT 0;

    queryExecute(
      "
      INSERT INTO fpw_early_access (
        email, source, referrer, ip_address, user_agent, status, utm_source, utm_medium, utm_campaign
      ) VALUES (
        :email, :source, :referrer, :ip_address, :user_agent, 'active', :utm_source, :utm_medium, :utm_campaign
      )
      ON DUPLICATE KEY UPDATE
        source = VALUES(source),
        referrer = VALUES(referrer),
        ip_address = VALUES(ip_address),
        user_agent = VALUES(user_agent),
        status = 'active',
        utm_source = VALUES(utm_source),
        utm_medium = VALUES(utm_medium),
        utm_campaign = VALUES(utm_campaign),
        updated_at = CURRENT_TIMESTAMP
      ",
      {
        email = { value = email, cfsqltype = "cf_sql_varchar" },
        source = { value = source, cfsqltype = "cf_sql_varchar" },
        referrer = { value = referrer, cfsqltype = "cf_sql_varchar", null = (NOT len(referrer)) },
        ip_address = { value = ipAddress, cfsqltype = "cf_sql_varchar", null = (NOT len(ipAddress)) },
        user_agent = { value = userAgent, cfsqltype = "cf_sql_varchar", null = (NOT len(userAgent)) },
        utm_source = { value = utmSource, cfsqltype = "cf_sql_varchar", null = (NOT len(utmSource)) },
        utm_medium = { value = utmMedium, cfsqltype = "cf_sql_varchar", null = (NOT len(utmMedium)) },
        utm_campaign = { value = utmCampaign, cfsqltype = "cf_sql_varchar", null = (NOT len(utmCampaign)) }
      },
      { datasource = dsn }
    );

    if (NOT alreadyOnList) {
      try {
        fpwSendPrelaunchWelcomeEmail(email, prelaunchWelcomeEmailConfig);
      } catch (any mailErr) {
        try {
          mailErrMsg = structKeyExists(mailErr, "message") ? fpwSafeString(mailErr.message, 500) : "";
          mailErrDetail = structKeyExists(mailErr, "detail") ? fpwSafeString(mailErr.detail, 1000) : "";
          writeLog(
            file = "fpw_prelaunch_mail",
            type = "error",
            text = "Prelaunch welcome email send failed for " & email
              & (len(mailErrMsg) ? " | message: " & mailErrMsg : "")
              & (len(mailErrDetail) ? " | detail: " & mailErrDetail : "")
          );
        } catch (any logErr) {}
      }
    }

    fpwJsonResponse(
      {
        "SUCCESS" = true,
        "success" = true,
        "alreadyOnList" = alreadyOnList,
        "duplicate" = alreadyOnList,
        "message" = alreadyOnList
          ? "You are already on the early notification list."
          : "Thanks for joining FloatPlanWizard early access."
      }
    );
  } catch (any e) {
    try {
      errMsg = structKeyExists(e, "message") ? fpwSafeString(e.message, 500) : "";
      errDetail = structKeyExists(e, "detail") ? fpwSafeString(e.detail, 1000) : "";
      writeLog(
        file = "fpw_prelaunch_mail",
        type = "error",
        text = "Prelaunch signup request failed"
          & (len(errMsg) ? " | message: " & errMsg : "")
          & (len(errDetail) ? " | detail: " & errDetail : "")
      );
    } catch (any logErr) {}

    fpwJsonResponse(
      {
        "SUCCESS" = false,
        "success" = false,
        "code" = "SERVER_ERROR",
        "message" = "Unable to complete signup right now. Please try again shortly."
      },
      500
    );
  }
}

fpwShowMemberRequiredNotice = (
  structKeyExists(url, "notice")
  AND lCase(trim(toString(url.notice))) EQ "member-required"
);
</cfscript>
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>FloatPlanWizard | Boat Trip Planner, Float Plans & Shared Trip Updates</title>

<meta name="description" content="Plan safer boat trips with FloatPlanWizard: create float plans, map routes, estimate fuel, check marine weather, and share trip updates with family and friends.">

<link rel="canonical" href="https://floatplanwizard.com/">

<meta property="og:type" content="website">
<meta property="og:site_name" content="FloatPlanWizard">
<meta property="og:url" content="https://floatplanwizard.com/">
<meta property="og:title" content="FloatPlanWizard | Boat Trip Planner, Float Plans & Shared Trip Updates">
<meta property="og:description" content="Plan safer boat trips with FloatPlanWizard: create float plans, map routes, estimate fuel, check marine weather, and share trip updates with family and friends.">

<meta property="og:image" content="https://floatplanwizard.com/assets/images/social/floatplanwizard-social-preview-20260602.png">
<meta property="og:image:secure_url" content="https://floatplanwizard.com/assets/images/social/floatplanwizard-social-preview-20260602.png">
<meta property="og:image:type" content="image/png">
<meta property="og:image:width" content="1200">
<meta property="og:image:height" content="630">
<meta property="og:image:alt" content="FloatPlanWizard boating trip planning and monitored float plan preview image">
<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:title" content="FloatPlanWizard | Boat Trip Planner, Float Plans & Shared Trip Updates">
<meta name="twitter:description" content="Plan safer boat trips with FloatPlanWizard: create float plans, map routes, estimate fuel, check marine weather, and share trip updates with family and friends.">
<meta name="twitter:image" content="https://floatplanwizard.com/assets/images/social/floatplanwizard-social-preview-20260602.png">
<meta name="twitter:image:alt" content="FloatPlanWizard boating trip planning and monitored float plan preview image">

  <link rel="preconnect" href="https://cdn.jsdelivr.net" crossorigin>
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.3/font/bootstrap-icons.min.css">
  <style>
    :root {
      --bg: #07131c;
      --bg-2: #0b1d2b;
      --panel: rgba(11, 29, 43, 0.78);
      --panel-strong: rgba(8, 19, 28, 0.92);
      --line: rgba(130, 186, 226, 0.18);
      --line-strong: rgba(130, 186, 226, 0.34);
      --text: #eaf5ff;
      --muted: #a7c0d5;
      --soft: #7f9ab0;
      --accent: #47c7ff;
      --accent-2: #18f2d2;
      --accent-3: #ffc85c;
      --danger: #ff7b7b;
      --success: #7df2b7;
      --shadow: 0 24px 80px rgba(0, 0, 0, 0.4);
      --radius-xl: 28px;
      --radius-lg: 20px;
      --radius-md: 14px;
      --fpw-public-layout-max: 1480px;
      --max: var(--fpw-public-layout-max);
      --promo-strip-offset: 36px;
    }

    * { box-sizing: border-box; }
    html { scroll-behavior: smooth; }
    body {
      margin: 0;
      font-family: Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      color: var(--text);
      background:
        radial-gradient(circle at 15% 20%, rgba(24, 242, 210, 0.08), transparent 0 24%),
        radial-gradient(circle at 85% 15%, rgba(71, 199, 255, 0.12), transparent 0 28%),
        radial-gradient(circle at 50% 100%, rgba(255, 200, 92, 0.06), transparent 0 25%),
        linear-gradient(180deg, #06111a 0%, #081722 35%, #091c2a 100%);
      min-height: 100vh;
    }

    a { color: inherit; text-decoration: none; }
    img { max-width: 100%; display: block; }

    .shell {
      width: min(calc(100% - 48px), var(--max));
      margin: 0 auto;
    }

    .topbar .shell {
      width: min(calc(100% - 48px), var(--fpw-public-layout-max));
    }

    .topbar {
      position: sticky;
      top: 0;
      z-index: 30;
      background:
        linear-gradient(180deg, rgba(4, 13, 24, 0.97), rgba(4, 14, 25, 0.9));
      border-bottom: 1px solid rgba(132, 183, 216, 0.18);
      box-shadow: 0 12px 34px rgba(0, 0, 0, 0.22);
      backdrop-filter: blur(18px);
    }

    .promo-strip {
      display: none;
      border-bottom: 1px solid rgba(130, 186, 226, 0.1);
      background:
        linear-gradient(180deg, rgba(255,255,255,0.04), rgba(255,255,255,0.015));
      box-shadow: inset 0 -1px 0 rgba(255,255,255,0.02);
    }

    .promo-strip-inner {
      display: flex;
      align-items: center;
      justify-content: center;
      padding: 8px 0 7px;
      text-align: center;
    }

    .promo-strip-copy {
      margin: 0;
      color: rgba(234, 245, 255, 0.84);
      font-size: clamp(0.76rem, 1.4vw, 0.84rem);
      font-weight: 600;
      letter-spacing: 0.01em;
      line-height: 1.25;
      white-space: nowrap;
    }

    .promo-strip-copy strong {
      color: #f4fbff;
      font-weight: 700;
    }

    .topbar-inner {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 28px;
      min-height: 92px;
    }

    .brand {
      display: inline-flex;
      align-items: center;
      gap: 12px;
      min-width: 0;
    }

    .brand-mark {
      width: 52px;
      height: 52px;
      display: grid;
      place-items: center;
      color: #c8faff;
      border-radius: 50%;
      border: 1px solid rgba(35, 215, 207, 0.55);
      background:
        radial-gradient(circle, rgba(35, 215, 207, 0.18), rgba(5, 17, 30, 0.9) 68%);
      box-shadow: inset 0 0 0 1px rgba(255, 255, 255, 0.05), 0 0 26px rgba(35, 215, 207, 0.2);
    }

    .brand-mark::before {
      content: none;
    }

    .brand-mark i {
      font-size: 1.55rem;
      color: #c8faff;
      filter: drop-shadow(0 0 10px rgba(35, 215, 207, 0.55));
    }

    .brand-copy { min-width: 0; }
    .brand-name {
      color: #f1f6ff;
      font-size: clamp(1.18rem, 2vw, 1.7rem);
      font-weight: 800;
      line-height: 1;
    }
    .brand-tag {
      margin-top: 5px;
      color: var(--accent-2);
      font-size: 0.75rem;
      font-weight: 800;
      letter-spacing: 0.16em;
      text-transform: uppercase;
      white-space: nowrap;
    }

    .nav {
      display: flex;
      align-items: center;
      justify-content: flex-end;
      gap: 8px;
      flex-wrap: wrap;
    }

    .nav a {
      color: rgba(237, 245, 255, 0.9);
      border-radius: 999px;
      padding: 10px 12px;
      font-size: 0.94rem;
      line-height: 1;
      transition: color 0.18s ease, background 0.18s ease, border-color 0.18s ease;
    }

    .nav a:hover { color: #ffffff; background: rgba(255, 255, 255, 0.07); }

    .btn {
      display: inline-flex;
      align-items: center;
      justify-content: center;
      gap: 10px;
      border: 0;
      border-radius: 999px;
      cursor: pointer;
      font-weight: 700;
      font-size: 0.98rem;
      padding: 7px 11px;
      transition: transform 0.18s ease, box-shadow 0.18s ease, background 0.18s ease;
      white-space: nowrap;
    }

    .btn:hover { transform: translateY(-1px); }
    .btn-primary {
      color: #041019;
      background: linear-gradient(135deg, var(--accent-2), var(--accent));
      box-shadow: 0 18px 36px rgba(31, 202, 241, 0.22);
    }

    .btn-secondary {
      color: var(--text);
      background: rgba(130,186,226,0.08);
      border: 1px solid rgba(130,186,226,0.16);
    }

    .btn i {
      font-size: 1rem;
      line-height: 1;
    }

    .topbar .btn {
      padding: 10px 12px;
      color: #ffffff;
      background: rgba(255, 255, 255, 0.05);
      border: 1px solid rgba(132, 183, 216, 0.28);
      box-shadow: none;
      font-size: 0.94rem;
      line-height: 1;
    }

    .topbar .btn:hover {
      color: #ffffff;
      background: rgba(255, 255, 255, 0.07);
    }

    .hero {
      padding: 25px 0 0;
      position: relative;
      overflow: hidden;
    }

    .hero-grid {
      display: grid;
      grid-template-columns: 1.1fr 0.9fr;
      gap: 28px;
      align-items: stretch;
    }

    .panel {
      background: var(--panel);
      border: 1px solid var(--line);
      border-radius: var(--radius-xl);
      box-shadow: var(--shadow);
      backdrop-filter: blur(20px);
    }

    .hero-copy {
      padding: 30px;
      position: relative;
      overflow: hidden;
      min-height: 620px;
      display: flex;
      flex-direction: column;
      justify-content: center;
      background:
        radial-gradient(circle at 10% 0%, rgba(71,199,255,0.12), transparent 0 28%),
        linear-gradient(180deg, rgba(255,255,255,0.03), rgba(255,255,255,0.01));
    }

    .hero-copy::after {
      content: "";
      position: absolute;
      inset: auto -10% 0 auto;
      width: 420px;
      height: 420px;
      background: radial-gradient(circle, rgba(24,242,210,0.12), transparent 62%);
      pointer-events: none;
      filter: blur(20px);
    }

    .eyebrow {
      display: inline-flex;
      align-items: center;
      gap: 10px;
      width: fit-content;
      padding: 8px 14px;
      border-radius: 999px;
      color: var(--success);
      background: rgba(125,242,183,0.08);
      border: 1px solid rgba(125,242,183,0.16);
      font-size: 0.82rem;
      font-weight: 700;
      letter-spacing: 0.04em;
      text-transform: none;
      margin-bottom: 22px;
    }

    .eyebrow i {
      font-size: 0.95rem;
      color: #aef7d0;
    }

    h1 {
      margin: 0;
      font-size: clamp(2.4rem, 5vw, 4.8rem);
      line-height: 0.96;
      letter-spacing: -0.045em;
      max-width: 11ch;
    }

    .gradient-text {
      background: linear-gradient(135deg, #ffffff, #9be8ff 55%, #8cf2de 100%);
      -webkit-background-clip: text;
      background-clip: text;
      color: transparent;
    }

    .lead {
      margin: 20px 0 0;
      font-size: 1.12rem;
      line-height: 1.7;
      color: var(--muted);
      max-width: 62ch;
    }

    .lead-bullets {
      padding-left: 1.25rem;
      margin-bottom: 0;
    }

    .lead-bullets li {
      margin-bottom: 6px;
    }

    .lead-bullets li:last-child {
      margin-bottom: 0;
    }

    .hero-points {
      display: grid;
      grid-template-columns: repeat(3, minmax(0, 1fr));
      gap: 14px;
      margin-top: 28px;
    }

    .hero-point {
      padding: 14px;
      border-radius: 18px;
      background: rgba(130,186,226,0.06);
      border: 1px solid rgba(130,186,226,0.12);
    }

    .hero-point b {
      display: block;
      font-size: 1rem;
      margin-bottom: 6px;
    }

    .hero-point span {
      display: block;
      font-size: 0.9rem;
      color: var(--muted);
      line-height: 1.45;
    }

    .hero-point b i {
      margin-right: 8px;
      color: #afe8ff;
    }

    .hero-cta {
      display: flex;
      flex-wrap: wrap;
      gap: 14px;
      margin-top: 15px;
      margin-bottom: 15px;
      align-items: center;
    }

    .hero-copy .hero-cta {
      justify-content: center;
    }

    .hero-cta .fpw-hero-primary-cta {
      min-height: 46px;
      padding: 0.78rem 1.35rem;
      color: #ffffff;
      background:
        linear-gradient(180deg, rgba(8, 31, 52, 0.98) 0%, rgba(3, 18, 32, 0.98) 100%);
      border: 1px solid rgba(69, 224, 220, 0.82);
      font-weight: 850;
      letter-spacing: 0.01em;
      box-shadow:
        0 0 0 1px rgba(69, 224, 220, 0.1) inset,
        0 8px 22px rgba(0, 0, 0, 0.26),
        0 0 24px rgba(69, 224, 220, 0.12);
      transition:
        background-color 0.18s ease,
        border-color 0.18s ease,
        box-shadow 0.18s ease,
        color 0.18s ease,
        transform 0.18s ease;
    }

    .hero-cta .fpw-hero-primary-cta:hover,
    .hero-cta .fpw-hero-primary-cta:focus-visible {
      color: #ffffff;
      background:
        linear-gradient(180deg, rgba(10, 42, 68, 1) 0%, rgba(4, 24, 42, 1) 100%);
      border-color: #45e0dc;
      box-shadow:
        0 0 0 1px rgba(69, 224, 220, 0.18) inset,
        0 10px 26px rgba(0, 0, 0, 0.3),
        0 0 30px rgba(69, 224, 220, 0.2);
      text-decoration: none;
      transform: translateY(-1px);
      outline: none;
    }

    .hero-cta .fpw-hero-primary-cta i {
      color: #45e0dc;
    }

    .micro {
      margin-top: 14px;
      color: var(--soft);
      font-size: 0.9rem;
    }

    .hero-visual {
      padding: 22px;
      position: relative;
      min-height: 620px;
      overflow: hidden;
      background:
        linear-gradient(180deg, rgba(255,255,255,0.03), rgba(255,255,255,0.01)),
        radial-gradient(circle at 70% 10%, rgba(71,199,255,0.1), transparent 0 30%);
    }

    .fpw-hero-product-preview {
      display: flex;
      flex-direction: column;
      gap: 16px;
      isolation: isolate;
    }

    .fpw-hero-product-preview::before {
      content: "";
      position: absolute;
      inset: 0;
      z-index: -1;
      background:
        radial-gradient(circle at 82% 4%, rgba(71, 199, 255, 0.16), transparent 0 28%),
        radial-gradient(circle at 14% 78%, rgba(24, 242, 210, 0.08), transparent 0 26%);
      pointer-events: none;
    }

    .fpw-preview-header {
      display: grid;
      gap: 9px;
    }

    .fpw-preview-eyebrow {
      margin: 0;
      color: #8ff3ff;
      font-size: 0.74rem;
      font-weight: 850;
      letter-spacing: 0.12em;
      text-transform: uppercase;
    }

    .fpw-preview-header h2 {
      margin: 0;
      font-size: clamp(1.5rem, 2.2vw, 2.05rem);
      line-height: 1.05;
      letter-spacing: -0.035em;
    }

    .fpw-preview-header p:last-child {
      margin: 0;
      color: var(--muted);
      line-height: 1.45;
      font-size: 0.96rem;
    }

    .fpw-preview-tabs {
      display: grid;
      grid-template-columns: repeat(2, minmax(0, 1fr));
      gap: 8px;
    }

    .fpw-preview-tab {
      min-height: 42px;
      border: 1px solid rgba(130, 186, 226, 0.2);
      border-radius: 12px;
      background: rgba(4, 18, 31, 0.72);
      color: #d9e7f5;
      font: inherit;
      font-size: 0.86rem;
      font-weight: 800;
      line-height: 1.1;
      cursor: pointer;
      transition: border-color 0.16s ease, background-color 0.16s ease, color 0.16s ease, transform 0.16s ease;
    }

    .fpw-preview-tab:hover,
    .fpw-preview-tab:focus-visible {
      color: #ffffff;
      border-color: rgba(69, 224, 220, 0.74);
      background: rgba(9, 36, 59, 0.86);
      outline: none;
    }

    .fpw-preview-tab.is-active {
      color: #ffffff;
      border-color: rgba(69, 224, 220, 0.9);
      background: linear-gradient(180deg, rgba(13, 57, 88, 0.92), rgba(4, 28, 48, 0.92));
      box-shadow: 0 0 0 1px rgba(69, 224, 220, 0.12) inset, 0 10px 22px rgba(0, 0, 0, 0.22);
    }

    .fpw-preview-browser-frame {
      display: flex;
      flex: 1 1 auto;
      min-height: 0;
      flex-direction: column;
      border-radius: 22px;
      border: 1px solid rgba(130, 186, 226, 0.18);
      background:
        linear-gradient(180deg, rgba(3, 12, 18, 0.86), rgba(7, 19, 28, 0.9)),
        radial-gradient(circle at 80% 10%, rgba(71, 199, 255, 0.08), transparent 0 30%);
      overflow: hidden;
      box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.04), 0 30px 60px rgba(0, 0, 0, 0.34);
    }

    .fpw-preview-browser-bar {
      display: flex;
      align-items: center;
      gap: 8px;
      min-height: 38px;
      padding: 0 16px;
      border-bottom: 1px solid rgba(130, 186, 226, 0.13);
      background: rgba(1, 9, 16, 0.54);
    }

    .fpw-preview-browser-bar span {
      width: 9px;
      height: 9px;
      border-radius: 50%;
      background: rgba(130, 186, 226, 0.34);
    }

    .fpw-preview-browser-bar span:nth-child(1) {
      background: #ff5f57;
    }

    .fpw-preview-browser-bar span:nth-child(2) {
      background: #ffbd2e;
    }

    .fpw-preview-browser-bar span:nth-child(3) {
      background: #28c840;
    }

    .fpw-preview-screen {
      display: none;
      flex: 1 1 auto;
      min-height: 0;
      flex-direction: column;
    }

    .fpw-preview-screen.is-active {
      display: flex;
    }

    .fpw-preview-screen[hidden] {
      display: none;
    }

    .fpw-preview-image-wrap {
      position: relative;
      aspect-ratio: 120 / 76;
      min-height: 246px;
      background: rgba(1, 10, 18, 0.75);
      overflow: hidden;
    }

    .fpw-preview-image-wrap::after {
      content: "";
      position: absolute;
      inset: 0;
      background: linear-gradient(180deg, transparent 56%, rgba(2, 13, 23, 0.2) 100%);
      pointer-events: none;
    }

    .fpw-preview-image-wrap img {
      width: 100%;
      height: 100%;
      display: block;
      object-fit: fill;
      object-position: top left;
    }

    .fpw-preview-caption {
      display: grid;
      gap: 7px;
      padding: 15px 16px 16px;
      border-top: 1px solid rgba(130, 186, 226, 0.12);
      background: rgba(3, 15, 26, 0.76);
    }

    .fpw-preview-caption h3 {
      margin: 0;
      font-size: 1.02rem;
      letter-spacing: -0.015em;
    }

    .fpw-preview-caption p {
      margin: 0;
      color: var(--muted);
      font-size: 0.9rem;
      line-height: 1.45;
    }

    .fpw-preview-actions {
      display: flex;
      flex-wrap: wrap;
      gap: 12px;
      align-items: center;
      justify-content: space-between;
    }

    .fpw-preview-actions .btn {
      min-height: 44px;
      padding: 0.72rem 1.18rem;
      font-size: 0.94rem;
    }

    .fpw-preview-link {
      color: #aeeefb;
      font-size: 0.92rem;
      font-weight: 750;
      text-decoration: none;
    }

    .fpw-preview-link:hover,
    .fpw-preview-link:focus-visible {
      color: #ffffff;
      text-decoration: underline;
      outline: none;
    }

    .mockup {
      position: relative;
      height: 100%;
      min-height: 576px;
      border-radius: 24px;
      background:
        linear-gradient(180deg, rgba(3, 12, 18, 0.86), rgba(7, 19, 28, 0.88)),
        radial-gradient(circle at 80% 10%, rgba(71,199,255,0.08), transparent 0 30%);
      border: 1px solid rgba(130,186,226,0.18);
      overflow: hidden;
      box-shadow: inset 0 1px 0 rgba(255,255,255,0.04), 0 30px 60px rgba(0,0,0,0.35);
    }

    .mockup-top {
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 18px 20px;
      border-bottom: 1px solid rgba(130,186,226,0.12);
      color: var(--muted);
      font-size: 0.86rem;
      letter-spacing: 0.03em;
    }

    .dots { display: flex; gap: 8px; }
    .dots span {
      width: 10px; height: 10px; border-radius: 50%;
      background: rgba(130,186,226,0.26);
    }

    .mockup-body {
      padding: 18px;
      display: grid;
      grid-template-columns: 1.05fr 0.95fr;
      gap: 16px;
      height: calc(100% - 63px);
    }

    .stack { display: grid; gap: 16px; }

    .card {
      border-radius: 22px;
      border: 1px solid rgba(130,186,226,0.12);
      background: rgba(130,186,226,0.05);
      padding: 18px;
      position: relative;
      overflow: hidden;
    }

    .card h3 {
      margin: 0 0 8px;
      font-size: 1rem;
      letter-spacing: -0.02em;
    }

    .card p {
      margin: 0;
      color: var(--muted);
      font-size: 0.9rem;
      line-height: 1.55;
    }

    .route-lines {
      display: grid;
      gap: 12px;
      margin-top: 18px;
    }

    .route-line {
      display: grid;
      grid-template-columns: 14px 1fr auto;
      gap: 12px;
      align-items: center;
      font-size: 0.92rem;
    }

    .route-line i {
      width: 14px; height: 14px; border-radius: 50%;
      border: 2px solid var(--accent);
      box-shadow: 0 0 0 4px rgba(71,199,255,0.09);
    }

    .route-line small { color: var(--muted); }

    .gauge {
      height: 200px;
      border-radius: 22px;
      padding: 20px;
      display: grid;
      place-items: center;
      background:
        radial-gradient(circle at 50% 48%, rgba(71,199,255,0.12), transparent 0 32%),
        linear-gradient(180deg, rgba(130,186,226,0.06), rgba(130,186,226,0.03));
      border: 1px solid rgba(130,186,226,0.12);
      position: relative;
      overflow: hidden;
    }

    .ring {
      width: 170px;
      height: 170px;
      border-radius: 50%;
      border: 10px solid rgba(130,186,226,0.12);
      position: relative;
      display: grid;
      place-items: center;
      box-shadow: inset 0 0 40px rgba(71,199,255,0.08), 0 0 30px rgba(0,0,0,0.2);
    }

    .ring::before {
      content: "";
      position: absolute;
      inset: -10px;
      border-radius: 50%;
      border-top: 10px solid var(--accent-2);
      border-right: 10px solid var(--accent);
      border-bottom: 10px solid transparent;
      border-left: 10px solid transparent;
      transform: rotate(24deg);
      opacity: 0.9;
    }

    .ring strong {
      font-size: 2rem;
      letter-spacing: -0.04em;
      display: block;
      text-align: center;
    }

    .ring span {
      color: var(--muted);
      font-size: 0.8rem;
      letter-spacing: 0.08em;
      text-transform: uppercase;
      display: block;
      text-align: center;
      margin-top: 4px;
    }

    .waitlist-card {
      margin-top: -62px;
      position: relative;
      z-index: 10;
      overflow: hidden;
      padding: 0;
      background:
        linear-gradient(90deg, rgba(2, 16, 27, 0.96) 0%, rgba(3, 21, 33, 0.94) 42%, rgba(3, 20, 31, 0.96) 100%);
    }

    .waitlist-card::before {
      content: "";
      position: absolute;
      inset: 0;
      background:
        radial-gradient(circle at 22% 24%, rgba(53, 208, 230, 0.11), transparent 22%),
        radial-gradient(circle at 74% 58%, rgba(53, 208, 230, 0.08), transparent 20%),
        linear-gradient(90deg, rgba(53, 208, 230, 0.02), transparent 24%, transparent 76%, rgba(53, 208, 230, 0.02));
      pointer-events: none;
    }

    .waitlist-grid {
      position: relative;
      z-index: 1;
      display: grid;
      grid-template-columns: minmax(0, 2fr) minmax(280px, 350px);
      gap: 18px;
      align-items: center;
      padding: 28px 30px;
    }

    .waitlist-copy {
      max-width: none;
      align-self: stretch;
      display: grid;
      grid-template-rows: auto 1fr auto 1fr;
    }

    .waitlist-copy-body {
      grid-row: 1;
    }

    .waitlist-eyebrow {
      display: inline-flex;
      align-items: center;
      gap: 8px;
      padding: 8px 14px;
      border-radius: 999px;
      font-size: 0.76rem;
      font-weight: 700;
      letter-spacing: 0.08em;
      text-transform: uppercase;
      color: #c9f7ff;
      border: 1px solid rgba(53, 208, 230, 0.18);
      background: rgba(53, 208, 230, 0.08);
      margin-bottom: 12px;
    }

    .waitlist-eyebrow-dot {
      width: 8px;
      height: 8px;
      border-radius: 50%;
      background: #35d0e6;
      box-shadow: 0 0 14px rgba(53, 208, 230, 0.85);
    }

    .waitlist-copy h2 {
      margin: 0 0 12px;
      font-size: clamp(1.85rem, 2.2vw, 2rem);
      letter-spacing: -0.04em;
      line-height: 1.02;
    }

    .waitlist-copy .waitlist-primary {
      margin: 0;
      color: var(--muted);
      line-height: 1.5;
      max-width: none;
      font-size: 1rem;
    }

    .waitlist-copy .waitlist-secondary {
      margin: 12px 0 0;
      color: var(--soft);
      line-height: 1.45;
      max-width: none;
      font-size: 0.92rem;
    }

    .waitlist-proof {
      display: flex;
      flex-wrap: nowrap;
      width: 100%;
      align-items: center;
      justify-content: center;
      gap: clamp(10px, 1.6vw, 24px);
      margin-top: 0;
      grid-row: 3;
      align-self: center;
      white-space: nowrap;
    }

    .waitlist-proof-pill {
      display: inline-flex;
      flex: 0 0 auto;
      align-items: center;
      justify-content: flex-start;
      gap: 8px;
      padding: 0;
      color: #dcecff;
      font-size: clamp(0.945rem, 1.18vw, 1.125rem);
      font-weight: 600;
      line-height: 1.2;
      letter-spacing: -0.01em;
      white-space: nowrap;
      min-width: 0;
    }

    .waitlist-proof-icon {
      font-size: 1.02em;
      line-height: 1;
      color: #9be8ff;
    }

    .waitlist-signup-panel {
      align-self: center;
      display: grid;
      gap: 9px;
      padding: 20px;
      border-radius: 24px;
      border: 1px solid rgba(90, 183, 255, 0.22);
      background:
        linear-gradient(180deg, rgba(12, 31, 47, 0.84) 0%, rgba(7, 25, 38, 0.92) 100%);
      box-shadow: 0 0 0 1px rgba(53, 208, 230, 0.08), 0 18px 50px rgba(0, 133, 180, 0.18);
      max-width: 560px;
      margin-left: auto;
    }

    .waitlist-panel-badge {
      display: inline-flex;
      align-items: center;
      width: fit-content;
      padding: 8px 12px;
      border-radius: 999px;
      background: rgba(255, 255, 255, 0.05);
      border: 1px solid rgba(255, 255, 255, 0.08);
      color: #d4ebff;
      font-size: 0.74rem;
      font-weight: 700;
      letter-spacing: 0.02em;
    }

    .waitlist-signup-panel h3 {
      margin: 0;
      font-size: 1.45rem;
      letter-spacing: -0.03em;
      line-height: 1.12;
      color: #f5fbff;
    }

    .waitlist-signup-panel p {
      margin: 0;
      color: var(--muted);
      line-height: 1.45;
      font-size: 0.88rem;
      max-width: 38ch;
    }

    .signup {
      display: flex;
      gap: 10px;
      align-items: center;
      justify-content: flex-end;
      flex-wrap: wrap;
      width: 100%;
    }

    .signup input {
      width: min(100%, 340px);
      background: rgba(255,255,255,0.05);
      color: var(--text);
      border: 1px solid rgba(130,186,226,0.18);
      border-radius: 999px;
      padding: 15px 18px;
      font-size: 0.98rem;
      outline: none;
      box-shadow: inset 0 1px 0 rgba(255,255,255,0.03);
    }

    .signup input:focus {
      border-color: rgba(71,199,255,0.55);
      box-shadow: 0 0 0 4px rgba(71,199,255,0.12);
    }

    .waitlist-signup-panel .signup {
      width: 100%;
      flex-direction: column;
      align-items: stretch;
      justify-content: center;
      gap: 10px;
      margin-top: 4px;
    }

    .waitlist-signup-panel .signup input {
      width: 100%;
      border: 1px solid rgba(121, 158, 190, 0.18);
      background: linear-gradient(180deg, rgba(255,255,255,0.035), rgba(255,255,255,0.02));
      border-radius: 14px;
      padding: 14px 14px;
      font-size: 0.94rem;
      font-weight: 500;
    }

    .waitlist-signup-panel .signup .btn {
      width: 100%;
      border-radius: 16px;
      padding: 14px 16px;
      margin-bottom: 8px;
      font-size: 0.98rem;
      letter-spacing: -0.02em;
    }

    .status {
      margin-top: 10px;
      color: var(--soft);
      font-size: 0.92rem;
      min-height: 1.35em;
    }

    .waitlist-signup-panel .status {
      margin-top: 0;
      min-height: auto;
      font-size: 0.8rem;
      line-height: 1.35;
    }

    .waitlist-signup-tags {
      display: flex;
      flex-wrap: wrap;
      justify-content: center;
      gap: 8px;
      margin-top: 0;
    }

    .waitlist-signup-tag {
      display: inline-flex;
      align-items: center;
      justify-content: center;
      padding: 7px 10px;
      border-radius: 999px;
      border: 1px solid rgba(255, 255, 255, 0.08);
      background: rgba(255, 255, 255, 0.05);
      color: #d7eaff;
      font-size: calc(0.72rem + 2px);
      font-weight: 700;
      letter-spacing: 0.02em;
      line-height: 1;
      white-space: nowrap;
    }

    .fpw-home-access-section {
      position: relative;
      isolation: isolate;
      margin: 28px auto 10px;
      width: min(calc(100% - 48px), var(--max));
      max-width: var(--max);
      padding: 0;
      color: #eaf6ff;
    }

    .fpw-home-access-inner {
      position: relative;
      display: grid;
      grid-template-columns: minmax(0, 1fr) minmax(420px, 0.52fr);
      gap: 24px;
      min-height: 0;
      overflow: hidden;
      border: 1px solid rgba(42, 198, 224, 0.24);
      border-radius: var(--radius-xl);
      padding: 28px;
      background:
        radial-gradient(circle at 72% 55%, rgba(40, 206, 228, 0.24), transparent 34%),
        radial-gradient(circle at 14% 22%, rgba(32, 188, 212, 0.16), transparent 30%),
        linear-gradient(90deg, rgba(4, 19, 31, 0.98) 0%, rgba(4, 19, 31, 0.9) 32%, rgba(4, 19, 31, 0.58) 58%, rgba(4, 19, 31, 0.88) 100%),
        var(--fpw-access-bg);
      background-size: auto, auto, auto, 112% auto;
      background-position: center center, center center, center center, calc(360% + 200px) center;
      box-shadow:
        0 0 0 1px rgba(255, 255, 255, 0.02) inset,
        0 26px 70px rgba(0, 0, 0, 0.42);
    }

    .fpw-home-access-inner::before {
      content: "";
      position: absolute;
      inset: 0;
      z-index: -1;
      background:
        linear-gradient(180deg, rgba(2, 16, 27, 0.18), rgba(2, 16, 27, 0.78)),
        radial-gradient(circle at 58% 75%, rgba(0, 0, 0, 0.12), rgba(0, 0, 0, 0.62) 62%);
      pointer-events: none;
    }

    .fpw-home-access-copy {
      position: relative;
      z-index: 1;
      max-width: none;
    }

    .fpw-home-access-badge {
      display: inline-flex;
      align-items: center;
      gap: 8px;
      min-height: 36px;
      margin-bottom: 16px;
      padding: 0 14px;
      border: 1px solid rgba(42, 217, 237, 0.26);
      border-radius: 999px;
      background: rgba(9, 54, 72, 0.56);
      color: #d8f7ff;
      font-size: 0.78rem;
      font-weight: 900;
      letter-spacing: 0.12em;
      text-transform: uppercase;
      box-shadow: 0 10px 28px rgba(0, 0, 0, 0.2);
    }

    .fpw-home-access-badge-dot {
      width: 8px;
      height: 8px;
      border-radius: 999px;
      background: #25e4f0;
      box-shadow: 0 0 18px rgba(37, 228, 240, 0.8);
    }

    .fpw-home-access-badge-separator {
      width: auto;
      height: auto;
      background: transparent;
      color: rgba(210, 239, 248, 0.7);
    }

    .fpw-home-access-title {
      max-width: 920px;
      margin: 0 0 14px;
      color: #f2f8ff;
      font-size: 35px;
      line-height: 1.05;
      font-weight: 950;
      letter-spacing: 0;
      text-wrap: balance;
      text-shadow: 0 4px 22px rgba(0, 0, 0, 0.45);
    }

    .fpw-home-access-lede,
    .fpw-home-access-text {
      max-width: 72ch;
      margin: 0 0 12px;
      color: #bad1df;
      font-size: 1.02rem;
      line-height: 1.75;
      font-weight: 600;
    }

    .fpw-home-access-text {
      color: #a8c0d0;
    }

    .fpw-home-access-features {
      display: flex;
      flex-wrap: wrap;
      align-items: stretch;
      gap: 0;
      margin-top: 24px;
    }

    .fpw-home-access-feature {
      display: flex;
      align-items: center;
      gap: 10px;
      min-height: 44px;
      padding: 0 18px;
      border-right: 1px solid rgba(164, 218, 232, 0.24);
      color: #eff8ff;
      font-size: 0.96rem;
      font-weight: 900;
      line-height: 1.15;
      text-shadow: 0 3px 16px rgba(0, 0, 0, 0.38);
    }

    .fpw-home-access-feature:first-child {
      padding-left: 0;
    }

    .fpw-home-access-feature:last-child {
      border-right: 0;
    }

    .fpw-home-access-feature-icon {
      display: inline-flex;
      width: 34px;
      height: 34px;
      flex: 0 0 34px;
      align-items: center;
      justify-content: center;
      color: #70f0ff;
    }

    .fpw-home-access-feature-icon svg,
    .fpw-home-plan-icon svg,
    .fpw-home-trust-badges svg {
      width: 100%;
      height: 100%;
      fill: none;
      stroke: currentColor;
      stroke-width: 2.4;
      stroke-linecap: round;
      stroke-linejoin: round;
    }

    .fpw-home-pricing-card {
      position: relative;
      z-index: 2;
      align-self: center;
      border: 1px solid rgba(42, 198, 224, 0.36);
      border-radius: var(--radius-lg);
      padding: 18px;
      background:
        linear-gradient(180deg, rgba(8, 31, 48, 0.94), rgba(5, 22, 35, 0.96)),
        radial-gradient(circle at 16% 0%, rgba(38, 229, 225, 0.15), transparent 35%);
      box-shadow:
        0 24px 80px rgba(0, 0, 0, 0.52),
        0 0 40px rgba(38, 216, 236, 0.1) inset;
      backdrop-filter: blur(16px);
    }

    .fpw-home-pricing-eyebrow {
      margin-bottom: 8px;
      color: #28f0e6;
      font-size: 0.78rem;
      font-weight: 950;
      letter-spacing: 0.12em;
      text-transform: uppercase;
    }

    .fpw-home-pricing-title {
      margin: 0 0 14px;
      color: #f4f8ff;
      font-size: 1.02rem;
      line-height: 1.75;
      font-weight: 950;
      letter-spacing: 0;
    }

    .fpw-home-plan-list {
      display: grid;
      gap: 8px;
      margin: 0 0 16px;
    }

    .fpw-home-plan-row {
      position: relative;
      display: grid;
      grid-template-columns: 42px minmax(0, 1fr) auto;
      gap: 10px;
      align-items: center;
      min-height: 50px;
      border: 1px solid rgba(155, 205, 222, 0.15);
      border-radius: 14px;
      padding: 10px 14px 10px 8px;
      background: rgba(4, 20, 34, 0.62);
      box-shadow: 0 10px 28px rgba(0, 0, 0, 0.18);
    }

    .fpw-home-plan-row-featured {
      border-color: rgba(21, 239, 225, 0.82);
      background:
        linear-gradient(90deg, rgba(10, 54, 70, 0.82), rgba(4, 22, 35, 0.72));
      box-shadow:
        0 0 0 1px rgba(21, 239, 225, 0.18) inset,
        0 0 28px rgba(21, 239, 225, 0.08);
    }

    .fpw-home-plan-tag {
      position: absolute;
      top: -9px;
      right: 18px;
      border-radius: 4px;
      padding: 3px 8px;
      background: #18f5e9;
      color: #031722;
      font-size: 0.78rem;
      font-weight: 950;
      letter-spacing: 0.06em;
      text-transform: uppercase;
    }

    .fpw-home-plan-icon {
      display: inline-flex;
      width: 36px;
      height: 36px;
      align-items: center;
      justify-content: center;
      border: 1px solid rgba(112, 240, 255, 0.14);
      border-radius: 12px;
      background: rgba(24, 65, 90, 0.42);
      color: #9eddf0;
    }

    .fpw-home-plan-row-featured .fpw-home-plan-icon {
      border-color: rgba(25, 242, 232, 0.28);
      background: rgba(25, 242, 232, 0.12);
      color: #1ff4e8;
    }

    .fpw-home-plan-copy {
      display: grid;
      gap: 3px;
    }

    .fpw-home-plan-copy strong {
      color: #f3f8ff;
      font-size: 0.95rem;
      line-height: 1.05;
      font-weight: 950;
    }

    .fpw-home-plan-copy span {
      color: #b3c7d4;
      font-size: 0.96rem;
      line-height: 1.75;
      font-weight: 650;
    }

    .fpw-home-plan-price {
      white-space: nowrap;
      color: #f7fbff;
      font-size: 1.02rem;
      line-height: 1.75;
      font-weight: 950;
      letter-spacing: 0;
    }

    .fpw-home-plan-price span {
      margin-left: 2px;
      color: #d4e5ee;
      font-size: 0.78rem;
      font-weight: 800;
      letter-spacing: 0;
    }

    .fpw-home-plan-price-accent {
      color: #20f2e6;
    }

    .fpw-home-pricing-actions {
      display: grid;
      gap: 10px;
      margin-top: 12px;
    }

    .fpw-home-primary-cta,
    .fpw-home-secondary-cta {
      display: inline-flex;
      align-items: center;
      justify-content: center;
      gap: 10px;
      min-height: 42px;
      border-radius: 14px;
      text-decoration: none;
      font-size: 0.96rem;
      font-weight: 950;
      transition:
        transform 160ms ease,
        box-shadow 160ms ease,
        border-color 160ms ease,
        background 160ms ease;
    }

    .fpw-home-primary-cta {
      border: 0;
      background: linear-gradient(90deg, #27e1d1 0%, #4bc3ff 100%);
      color: #031722;
      box-shadow: 0 14px 34px rgba(33, 219, 224, 0.18);
    }

    .fpw-home-primary-cta:hover,
    .fpw-home-primary-cta:focus-visible {
      transform: translateY(-1px);
      color: #031722;
      box-shadow: 0 18px 44px rgba(33, 219, 224, 0.26);
    }

    .fpw-home-secondary-cta {
      border: 1px solid rgba(149, 200, 218, 0.17);
      background: rgba(4, 20, 34, 0.52);
      color: #23efe4;
    }

    .fpw-home-secondary-cta:hover,
    .fpw-home-secondary-cta:focus-visible {
      border-color: rgba(35, 239, 228, 0.46);
      background: rgba(8, 42, 59, 0.74);
      color: #69fbff;
      transform: translateY(-1px);
    }

    .fpw-home-trust-badges {
      display: flex;
      flex-wrap: wrap;
      gap: 10px;
    }

    .fpw-home-trust-badges span {
      display: inline-flex;
      align-items: center;
      gap: 8px;
      min-height: 30px;
      border: 1px solid rgba(178, 217, 230, 0.14);
      border-radius: 999px;
      padding: 0 10px;
      background: rgba(255, 255, 255, 0.055);
      color: #d7e5ed;
      font-size: 0.78rem;
      font-weight: 850;
    }

    .fpw-home-trust-badges svg {
      width: 18px;
      height: 18px;
      color: #a3e6f2;
    }

    @media (max-width: 1180px) {
      .fpw-home-access-inner {
        grid-template-columns: 1fr;
        min-height: 0;
        background-size: auto, auto, auto, cover;
        background-position: center center, center center, center center, center center;
      }

      .fpw-home-pricing-card {
        max-width: 720px;
        align-self: stretch;
      }
    }

    @media (max-width: 760px) {
      .fpw-home-access-section {
        width: min(calc(100% - 28px), var(--max));
      }

      .fpw-home-access-inner {
        border-radius: 22px;
        padding: 22px 18px;
      }

      .fpw-home-access-badge {
        gap: 9px;
        min-height: 40px;
        padding: 0 14px;
        font-size: 0.78rem;
        letter-spacing: 0.12em;
      }

      .fpw-home-access-badge-separator {
        height: 16px;
      }

      .fpw-home-access-title {
        font-size: 35px;
      }

      .fpw-home-access-lede,
      .fpw-home-access-text {
        font-size: 1.02rem;
      }

      .fpw-home-access-features {
        display: grid;
        gap: 12px;
        margin-top: 22px;
      }

      .fpw-home-access-feature {
        min-height: 0;
        border-right: 0;
        padding: 0;
        font-size: 0.96rem;
      }

      .fpw-home-access-feature-icon {
        width: 34px;
        height: 34px;
        flex-basis: 34px;
      }

      .fpw-home-pricing-card {
        border-radius: 24px;
        padding: 20px;
      }

      .fpw-home-plan-row {
        grid-template-columns: 48px minmax(0, 1fr);
        gap: 12px;
        padding: 13px;
      }

      .fpw-home-plan-icon {
        width: 40px;
        height: 40px;
        border-radius: 12px;
      }

      .fpw-home-plan-price {
        grid-column: 2;
        justify-self: start;
        margin-top: 4px;
      }

      .fpw-home-plan-tag {
        right: 16px;
      }

      .fpw-home-primary-cta,
      .fpw-home-secondary-cta {
        min-height: 46px;
      }
    }

    section.section {
      padding: 10px 0;
    }

    #great-loop {
      scroll-margin-top: calc(73px + var(--promo-strip-offset));
    }

    #features {
      scroll-margin-top: calc(74px + var(--promo-strip-offset));
    }

    #followers {
      scroll-margin-top: calc(74px + var(--promo-strip-offset));
    }

    #story {
      scroll-margin-top: calc(74px + var(--promo-strip-offset));
    }

    #notify {
      scroll-margin-top: calc(86px + var(--promo-strip-offset));
    }

    .section-head {
      max-width: 760px;
      margin-bottom: 28px;
    }

    .section-kicker {
      color: var(--accent-2);
      font-weight: 700;
      text-transform: uppercase;
      letter-spacing: 0.12em;
      font-size: 0.78rem;
      margin-bottom: 12px;
    }

    .section-head h2 {
      margin: 0;
      font-size: clamp(1.9rem, 3vw, 3.1rem);
      letter-spacing: -0.045em;
      line-height: 1.02;
    }

    .section-head p {
      margin: 14px 0 0;
      color: var(--muted);
      font-size: 1.04rem;
      line-height: 1.72;
    }

    .features {
      display: grid;
      grid-template-columns: repeat(4, minmax(0, 1fr));
      gap: 18px;
    }

    .feature {
      padding: 22px;
      border-radius: 22px;
      border: 1px solid var(--line);
      background: rgba(130,186,226,0.05);
      box-shadow: inset 0 1px 0 rgba(255,255,255,0.03);
    }

    .feature-icon {
      width: 48px;
      height: 48px;
      display: grid;
      place-items: center;
      border-radius: 16px;
      background: linear-gradient(145deg, rgba(71,199,255,0.16), rgba(24,242,210,0.12));
      border: 1px solid rgba(130,186,226,0.18);
      margin-bottom: 16px;
      font-size: 1.2rem;
      color: #c6eeff;
      box-shadow: inset 0 1px 0 rgba(255,255,255,0.05);
    }

    .feature h3 {
      margin: 0 0 10px;
      font-size: 1.06rem;
      letter-spacing: -0.02em;
    }

    .feature p {
      margin: 0;
      color: var(--muted);
      line-height: 1.65;
      font-size: 0.95rem;
    }

    .grid-2 {
      display: grid;
      grid-template-columns: 1.05fr 0.95fr;
      gap: 22px;
      align-items: stretch;
    }

    .loop-card, .follower-card, .story-card, .cta-card {
      padding: 28px;
    }

    .list {
      display: grid;
      gap: 14px;
      margin-top: 20px;
    }

    .list-item {
      display: grid;
      grid-template-columns: 30px 1fr;
      gap: 12px;
      align-items: start;
      padding: 14px;
      border-radius: 18px;
      background: rgba(130,186,226,0.05);
      border: 1px solid rgba(130,186,226,0.12);
    }

    .list-item .num {
      width: 30px; height: 30px; border-radius: 50%;
      background: rgba(24,242,210,0.12);
      color: var(--accent-2);
      display: grid; place-items: center;
      font-weight: 800;
      font-size: 0.84rem;
      border: 1px solid rgba(24,242,210,0.18);
    }

    .list-item strong {
      display: block;
      margin-bottom: 4px;
      font-size: 0.98rem;
    }

    .list-item span {
      display: block;
      color: var(--muted);
      line-height: 1.6;
      font-size: 0.93rem;
    }

    .map-card {
      padding: 24px;
      min-height: 100%;
      position: relative;
      overflow: hidden;
      background:
        linear-gradient(180deg, rgba(255,255,255,0.03), rgba(255,255,255,0.01)),
        radial-gradient(circle at 50% 20%, rgba(71,199,255,0.08), transparent 0 34%);
    }

    .map-frame {
      position: relative;
      min-height: 420px;
      border-radius: 24px;
      border: 1px solid rgba(130,186,226,0.18);
      background-image: url("prelaunch-great-loop-map-20260311-v2.png");
      background-size: cover;
      background-position: center center;
      overflow: hidden;
      box-shadow: inset 0 1px 0 rgba(255,255,255,0.05);
    }

    .map-frame::before {
      content: none;
    }

    .map-frame::after {
      content: none;
    }

    .route-overlay {
      position: absolute;
      inset: 0;
      width: 100%;
      height: 100%;
      pointer-events: none;
      z-index: 2;
    }

    .route-overlay .route-glow {
      fill: none;
      stroke: rgba(71,199,255,0.34);
      stroke-width: 11;
      stroke-linecap: round;
      stroke-linejoin: round;
      filter: drop-shadow(0 0 10px rgba(71,199,255,0.4));
    }

    .route-overlay .route-core {
      fill: none;
      stroke: rgba(86,221,255,0.92);
      stroke-width: 3.4;
      stroke-linecap: round;
      stroke-linejoin: round;
      stroke-dasharray: 9 11;
      filter: drop-shadow(0 0 5px rgba(71,199,255,0.55));
    }

    .route-overlay .route-node-start {
      fill: #2fe6cf;
      filter: drop-shadow(0 0 8px rgba(47,230,207,0.75));
    }

    .route-overlay .route-node-mid {
      fill: #62d7ff;
      filter: drop-shadow(0 0 8px rgba(98,215,255,0.75));
    }

    .route-overlay .route-node-end {
      fill: #ffd27a;
      filter: drop-shadow(0 0 8px rgba(255,210,122,0.75));
    }

    .route-label {
      position: absolute;
      z-index: 3;
      padding: 6px 10px;
      border-radius: 999px;
      background: rgba(7,19,28,0.86);
      border: 1px solid rgba(130,186,226,0.22);
      color: var(--text);
      font-size: 0.75rem;
      letter-spacing: 0.02em;
      box-shadow: 0 8px 22px rgba(0,0,0,0.34);
      backdrop-filter: blur(6px);
      white-space: nowrap;
    }

    .label-1 { bottom: 34px; right: 50px; }
    .label-2 { top: 92px; right: 72px; }
    .label-3 { top: 56px; left: 46%; transform: translateX(-50%); }
    .label-4 { top: 180px; left: 78px; }
    .label-5 { bottom: 122px; left: 146px; }

    .stats-row {
      display: grid;
      grid-template-columns: repeat(3, minmax(0, 1fr));
      gap: 16px;
      margin-top: 18px;
    }

    .stat {
      padding: 18px;
      border-radius: 18px;
      border: 1px solid rgba(130,186,226,0.12);
      background: rgba(130,186,226,0.05);
    }

    .stat strong {
      display: block;
      font-size: 1.5rem;
      letter-spacing: -0.04em;
      margin-bottom: 4px;
    }

    .stat span {
      color: var(--muted);
      font-size: 0.9rem;
    }

    .loop-feature-list {
      list-style: none;
      margin: 16px 0 0;
      padding: 0;
      display: grid;
      gap: 8px;
    }

    .loop-feature-item {
      display: flex;
      align-items: center;
      gap: 10px;
      color: var(--muted);
      font-weight: 400;
      line-height: 1.6;
      font-size: 0.93rem;
    }

    .loop-feature-item strong {
      font-size: 0.98rem;
      font-weight: 700;
      color: var(--text);
    }

    .loop-feature-item-icon {
      flex: 0 0 auto;
      width: 42px;
      height: 42px;
      display: grid;
      place-items: center;
      border-radius: 14px;
      background: linear-gradient(145deg, rgba(71,199,255,0.14), rgba(24,242,210,0.10));
      border: 1px solid rgba(130,186,226,0.16);
      color: #bdeeff;
      font-size: 1.1rem;
      line-height: 1;
      box-shadow: inset 0 1px 0 rgba(255,255,255,0.04);
    }

    .follower-view-card {
      padding: 20px 18px 18px;
    }

    .follower-view-card h3 {
      margin-bottom: 6px;
    }

    .follower-view-card > p {
      margin: 0;
      max-width: 30ch;
      line-height: 1.45;
      font-size: 0.88rem;
    }

    .follower-view-stats {
      display: grid;
      grid-template-columns: 1fr;
      gap: 8px;
      margin-top: 12px;
    }

    .follower-view-stats .stat {
      display: grid;
      grid-template-columns: minmax(40px, auto) 1fr;
      align-items: center;
      gap: 10px;
      padding: 10px 12px;
      border-radius: 14px;
      background: rgba(130,186,226,0.06);
    }

    .follower-view-stats .stat strong {
      font-size: 1.05rem;
      line-height: 1;
      margin: 0;
      justify-self: center;
      white-space: nowrap;
      letter-spacing: -0.02em;
    }

    .follower-view-stats .stat span {
      line-height: 1.2;
      font-size: 0.84rem;
      white-space: nowrap;
      overflow: visible;
      text-overflow: clip;
      text-align: left;
    }

    .quotes {
      display: grid;
      grid-template-columns: repeat(3, minmax(0, 1fr));
      gap: 18px;
      margin-top: 18px;
    }

    .quote {
      padding: 22px;
      border-radius: 20px;
      background: rgba(130,186,226,0.05);
      border: 1px solid rgba(130,186,226,0.12);
      color: var(--muted);
      line-height: 1.75;
      font-size: 0.96rem;
    }

    .quote strong {
      display: block;
      color: var(--text);
      margin-top: 14px;
      font-size: 0.95rem;
    }

    .story-grid {
      display: grid;
      grid-template-columns: 0.95fr 1.05fr;
      gap: 22px;
    }

    .story-layout {
      display: grid;
      grid-template-columns: 1.55fr 0.95fr;
      gap: 40px;
      align-items: start;
    }

    .story-content h2 {
      margin: 0;
      font-size: clamp(1.9rem,3vw,3rem);
      letter-spacing: -0.045em;
      line-height: 1.05;
      max-width: 22ch;
    }

    .story-content .story-founder {
      margin: 16px 0 0;
      max-width: 72ch;
      color: var(--muted);
      line-height: 1.75;
      font-size: 1.02rem;
    }

    .story-content .story-notify {
      margin: 14px 0 0;
      max-width: 70ch;
      color: var(--muted);
      line-height: 1.75;
      font-size: 1.02rem;
    }

    .story-signup {
      align-self: start;
      width: 100%;
      max-width: 460px;
    }

    .story-launch-callout {
      color: var(--soft);
      font-size: 0.84rem;
      font-weight: 700;
      letter-spacing: 0.08em;
      text-transform: uppercase;
    }

    .story-signup-form {
      display: grid;
      grid-template-columns: minmax(0, 1fr);
      gap: 12px;
      margin-top: 14px;
      justify-content: flex-start;
    }

    .story-signup-form input {
      width: 100%;
    }

    .story-signup-form .btn {
      justify-self: start;
    }

    .story-trust-line {
      margin-top: 12px;
      color: var(--text);
      font-size: 0.9rem;
      font-weight: 600;
      line-height: 1.45;
    }

    .story-signup-status {
      margin-top: 6px;
      color: var(--soft);
      font-size: 0.86rem;
      line-height: 1.4;
    }

    .fpw-live-builder-panel {
      position: relative;
      color: #eaf6ff;
    }

    .fpw-live-builder-inner {
      position: relative;
      display: grid;
      grid-template-columns: 1.55fr 0.95fr;
      gap: 40px;
      align-items: center;
      overflow: hidden;
      border: 1px solid rgba(42, 198, 224, 0.22);
      border-radius: var(--radius-xl);
      padding: 28px;
      background:
        radial-gradient(circle at 18% 12%, rgba(44, 214, 236, 0.13), transparent 30%),
        radial-gradient(circle at 76% 62%, rgba(37, 158, 190, 0.14), transparent 34%),
        linear-gradient(135deg, rgba(7, 25, 40, 0.98) 0%, rgba(8, 31, 49, 0.96) 42%, rgba(5, 22, 35, 0.98) 100%);
      box-shadow:
        0 26px 70px rgba(0, 0, 0, 0.38),
        0 0 0 1px rgba(255, 255, 255, 0.025) inset;
    }

    .fpw-live-builder-inner::before {
      content: "";
      position: absolute;
      inset: 12px;
      border: 1px solid rgba(49, 193, 222, 0.18);
      border-radius: 22px;
      pointer-events: none;
    }

    .fpw-live-builder-copy,
    .fpw-live-builder-cta {
      position: relative;
      z-index: 1;
    }

    .fpw-live-builder-badge {
      display: inline-flex;
      align-items: center;
      gap: 8px;
      min-height: 34px;
      margin-bottom: 12px;
      padding: 8px 14px;
      border: 1px solid rgba(42, 217, 237, 0.26);
      border-radius: 999px;
      background: rgba(9, 54, 72, 0.52);
      color: #d8f7ff;
      font-size: 0.78rem;
      font-weight: 700;
      letter-spacing: 0.12em;
      text-transform: uppercase;
    }

    .fpw-live-builder-dot {
      width: 8px;
      height: 8px;
      border-radius: 999px;
      background: #25e4f0;
      box-shadow: 0 0 18px rgba(37, 228, 240, 0.8);
    }

    .fpw-live-builder-badge-separator {
      width: 1px;
      height: 16px;
      background: rgba(210, 239, 248, 0.28);
    }

    .fpw-live-builder-title {
      margin: 0;
      color: #f2f8ff;
      font-size: clamp(1.9rem, 3vw, 3rem);
      line-height: 1.05;
      font-weight: 700;
      letter-spacing: -0.045em;
      text-wrap: balance;
      text-shadow: 0 4px 22px rgba(0, 0, 0, 0.38);
    }

    .fpw-live-builder-text {
      max-width: 72ch;
      margin: 16px 0 0;
      color: var(--muted);
      font-size: 1.02rem;
      line-height: 1.75;
      font-weight: 400;
    }

    .fpw-live-builder-text:last-child {
      margin-bottom: 0;
    }

    .fpw-live-builder-cta {
      border-left: 1px solid rgba(47, 190, 218, 0.32);
      padding-left: 36px;
    }

    .fpw-live-builder-cta-eyebrow {
      margin-bottom: 12px;
      color: var(--accent-2);
      font-size: 0.78rem;
      font-weight: 700;
      letter-spacing: 0.12em;
      text-transform: uppercase;
    }

    .fpw-live-builder-cta-title {
      margin: 0 0 12px;
      color: #f6fbff;
      font-size: clamp(1.45rem, 2vw, 1.9rem);
      line-height: 1.12;
      font-weight: 700;
      letter-spacing: -0.03em;
    }

    .fpw-live-builder-cta-copy {
      margin: 0 0 18px;
      max-width: 520px;
      color: var(--muted);
      font-size: 1.02rem;
      line-height: 1.55;
      font-weight: 400;
    }

    .fpw-live-builder-primary-cta,
    .fpw-live-builder-secondary-cta {
      display: inline-flex;
      align-items: center;
      justify-content: center;
      text-decoration: none;
      transition:
        transform 160ms ease,
        box-shadow 160ms ease,
        border-color 160ms ease,
        background 160ms ease;
    }

    .fpw-live-builder-primary-cta {
      gap: 10px;
      width: min(100%, 560px);
      min-height: 50px;
      border-radius: 999px;
      border: 1px solid rgba(69, 224, 220, 0.82);
      background:
        linear-gradient(180deg, rgba(8, 31, 52, 0.98) 0%, rgba(3, 18, 32, 0.98) 100%);
      color: #ffffff;
      font-size: 1rem;
      font-weight: 850;
      letter-spacing: 0.01em;
      box-shadow:
        0 0 0 1px rgba(69, 224, 220, 0.1) inset,
        0 8px 22px rgba(0, 0, 0, 0.26),
        0 0 24px rgba(69, 224, 220, 0.12);
    }

    .fpw-live-builder-primary-cta:hover,
    .fpw-live-builder-primary-cta:focus-visible {
      transform: translateY(-1px);
      color: #ffffff;
      background:
        linear-gradient(180deg, rgba(10, 42, 68, 1) 0%, rgba(4, 24, 42, 1) 100%);
      border-color: #45e0dc;
      box-shadow:
        0 0 0 1px rgba(69, 224, 220, 0.18) inset,
        0 10px 26px rgba(0, 0, 0, 0.3),
        0 0 30px rgba(69, 224, 220, 0.2);
      text-decoration: none;
      outline: none;
    }

    .fpw-live-builder-primary-cta .fpw-live-builder-button-icon,
    .fpw-live-builder-primary-cta .fpw-live-builder-arrow {
      color: #45e0dc;
    }

    .fpw-live-builder-button-icon {
      display: inline-flex;
      width: 24px;
      height: 24px;
      flex: 0 0 24px;
    }

    .fpw-live-builder-button-icon svg,
    .fpw-live-builder-trust-line svg {
      width: 100%;
      height: 100%;
      fill: none;
      stroke: currentColor;
      stroke-width: 2.5;
      stroke-linecap: round;
      stroke-linejoin: round;
    }

    .fpw-live-builder-arrow {
      font-size: 1.3em;
      line-height: 1;
    }

    .fpw-live-builder-trust-line {
      display: flex;
      align-items: center;
      gap: 10px;
      margin: 18px 0 14px;
      color: #d7e8f2;
      font-size: 0.95rem;
      line-height: 1.45;
    }

    .fpw-live-builder-trust-line span {
      display: inline-flex;
      width: 28px;
      height: 28px;
      flex: 0 0 28px;
      color: #43c7ff;
    }

    .fpw-live-builder-secondary-cta {
      gap: 8px;
      color: #27e9ef;
      font-size: 1rem;
      font-weight: 700;
    }

    .fpw-live-builder-secondary-cta:hover,
    .fpw-live-builder-secondary-cta:focus-visible {
      color: #79f9ff;
      transform: translateX(2px);
    }

    .fpw-live-builder-note {
      margin: 12px 0 0;
      color: #91aaba;
      font-size: 0.9rem;
      line-height: 1.45;
      font-weight: 400;
    }

    .signup .btn.is-loading {
      display: inline-flex;
      align-items: center;
      justify-content: center;
      pointer-events: none;
    }

    .btn-loading-indicator {
      width: 18px;
      height: 18px;
      border: 2px solid rgba(7, 19, 28, 0.2);
      border-top-color: #07131c;
      border-radius: 50%;
      animation: signupSpin 0.72s linear infinite;
    }

    @keyframes signupSpin {
      to {
        transform: rotate(360deg);
      }
    }

    .signup-panel {
      position: relative;
      min-height: 260px;
    }

    .waitlist-signup-panel.signup-panel {
      min-height: 322px;
    }

    .story-signup.signup-panel {
      min-height: 248px;
    }

    .signup-form-state {
      display: block;
    }

    .signup-success-state {
      display: none;
      border-radius: 18px;
      border: 1px solid rgba(24,242,210,0.24);
      background:
        linear-gradient(180deg, rgba(18, 61, 68, 0.22) 0%, rgba(9, 35, 44, 0.34) 100%);
      padding: 16px 16px 14px;
      box-shadow: inset 0 1px 0 rgba(255,255,255,0.04);
    }

    .signup-success-state h4 {
      margin: 0;
      font-size: 1.2rem;
      letter-spacing: -0.02em;
      color: #e8fffb;
    }

    .signup-success-state p {
      margin: 10px 0 0;
      color: var(--muted);
      line-height: 1.55;
      font-size: 0.92rem;
      max-width: none;
    }

    .signup-success-state .bonus {
      margin-top: 12px;
      padding: 10px 12px;
      border-radius: 12px;
      border: 1px solid rgba(24,242,210,0.22);
      background: rgba(24,242,210,0.1);
      color: #dcfff8;
      font-size: 0.9rem;
      line-height: 1.45;
    }

    .signup-success-state .subtle {
      margin-top: 10px;
      color: var(--soft);
      font-size: 0.84rem;
      line-height: 1.35;
    }

    .signup-panel.is-success .signup-form-state {
      display: none;
    }

    .signup-panel.is-success .signup-success-state {
      display: block;
    }

    .signup-feedback {
      margin-top: 8px;
      min-height: 1.35em;
      color: var(--soft);
      font-size: 0.84rem;
      line-height: 1.35;
    }

    .signal-box {
      display: grid;
      gap: 14px;
      margin-top: 22px;
    }

    .signal {
      display: grid;
      justify-items: center;
      align-items: center;
      gap: 10px;
      padding: 14px 16px;
      border-radius: 18px;
      background: rgba(130,186,226,0.05);
      border: 1px solid rgba(130,186,226,0.12);
    }

    .signal b {
      font-size: 0.95rem;
      text-align: center;
    }
    .pill {
      padding: 5px 11px 5px 8px;
      border-radius: 999px;
      font-size: 0.68rem;
      font-weight: 800;
      text-transform: uppercase;
      letter-spacing: 0.04em;
      white-space: nowrap;
    }

    .pill-ready { background: rgba(125,242,183,0.12); color: var(--success); }
    .pill-track { background: rgba(71,199,255,0.12); color: var(--accent); }
    .pill-loop { background: rgba(255,200,92,0.12); color: var(--accent-3); }

    @media (max-width: 1120px) {
      .hero-grid,
      .grid-2,
      .story-grid,
      .story-layout,
      .waitlist-grid,
      .mockup-body {
        grid-template-columns: 1fr;
      }

      .hero-copy,
      .hero-visual { min-height: auto; }
      .waitlist-card { margin-top: 22px; }
      .signup { justify-content: flex-start; }
      .waitlist-signup-panel {
        max-width: 100%;
        margin-left: 0;
      }
      .waitlist-signup-panel .signup {
        justify-self: start;
      }
      .fpw-live-builder-inner {
        grid-template-columns: 1fr;
      }
      .fpw-live-builder-cta {
        border-left: 0;
        border-top: 1px solid rgba(47, 190, 218, 0.26);
        padding-left: 0;
        padding-top: 22px;
      }
      .features { grid-template-columns: repeat(2, minmax(0, 1fr)); }
      .quotes { grid-template-columns: 1fr; }
    }

    @media (max-width: 780px) {
      .shell { width: min(calc(100% - 28px), var(--max)); }
      .topbar .shell { width: min(calc(100% - 28px), var(--fpw-public-layout-max)); }
      .topbar-inner { align-items: flex-start; flex-direction: column; }
      .nav { width: 100%; justify-content: flex-start; gap: 6px; }
      .nav a,
      .topbar .btn {
        padding: 9px 10px;
        font-size: 0.88rem;
      }
      .hero { padding-top: 26px; }
      #great-loop { scroll-margin-top: calc(125px + var(--promo-strip-offset)); }
      #features { scroll-margin-top: calc(126px + var(--promo-strip-offset)); }
      #followers { scroll-margin-top: calc(126px + var(--promo-strip-offset)); }
      #story { scroll-margin-top: calc(126px + var(--promo-strip-offset)); }
      #notify { scroll-margin-top: calc(138px + var(--promo-strip-offset)); }
      .hero-copy, .hero-visual, .loop-card, .follower-card, .story-card, .cta-card { padding: 22px; }
      .waitlist-grid { padding: 22px 18px; gap: 18px; }
      .waitlist-signup-panel { padding: 16px; border-radius: 20px; }
      .fpw-live-builder-inner {
        border-radius: 22px;
        padding: 22px;
      }
      .fpw-live-builder-inner::before {
        inset: 8px;
        border-radius: 16px;
      }
      .fpw-live-builder-badge {
        gap: 8px;
        min-height: 38px;
        padding: 0 13px;
        font-size: 11px;
        letter-spacing: 0.11em;
      }
      .fpw-live-builder-badge-separator {
        height: 16px;
      }
      .fpw-live-builder-title {
        font-size: clamp(1.9rem, 9vw, 3rem);
      }
      .fpw-live-builder-text,
      .fpw-live-builder-cta-copy {
        font-size: 1.02rem;
      }
      .fpw-live-builder-primary-cta {
        min-height: 50px;
        gap: 10px;
        font-size: 1rem;
      }
      .fpw-live-builder-button-icon {
        width: 24px;
        height: 24px;
        flex-basis: 24px;
      }
      .fpw-live-builder-trust-line {
        align-items: flex-start;
        font-size: 0.95rem;
      }
      .waitlist-proof { margin-top: 14px; flex-wrap: wrap; white-space: normal; justify-content: flex-start; }
      .hero-points,
      .stats-row,
      .features { grid-template-columns: 1fr; }
      h1 { max-width: 100%; }
      .signup input { width: 100%; }
      .signup .btn { width: 100%; }
      .mockup { min-height: 520px; }
      .map-frame { min-height: 340px; }
      .route-label { font-size: 0.74rem; }
    }

    .fpw-member-required-modal {
      position: fixed;
      inset: 0;
      z-index: 9999;
      display: flex;
      align-items: center;
      justify-content: center;
      padding: 24px;
      background: rgba(2, 12, 20, 0.76);
      backdrop-filter: blur(12px);
    }

    .fpw-member-required-modal[hidden] {
      display: none !important;
    }

    body.fpw-member-required-open {
      overflow: hidden;
    }

    .fpw-member-required-card {
      width: min(100%, 520px);
      overflow: hidden;
      border: 1px solid rgba(42, 198, 224, 0.28);
      border-radius: 28px;
      background:
        radial-gradient(circle at 16% 0%, rgba(37, 226, 230, 0.16), transparent 36%),
        linear-gradient(180deg, rgba(9, 31, 48, 0.98), rgba(4, 18, 30, 0.98));
      color: #eaf6ff;
      box-shadow:
        0 30px 90px rgba(0, 0, 0, 0.52),
        0 0 0 1px rgba(255, 255, 255, 0.025) inset;
    }

    .fpw-member-required-header {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 18px;
      padding: 24px 26px 0;
    }

    .fpw-member-required-eyebrow {
      color: #28f0e6;
      font-size: 0.82rem;
      font-weight: 900;
      letter-spacing: 0.16em;
      text-transform: uppercase;
    }

    .fpw-member-required-close {
      display: inline-flex;
      width: 40px;
      height: 40px;
      align-items: center;
      justify-content: center;
      border: 1px solid rgba(164, 218, 232, 0.18);
      border-radius: 999px;
      background: rgba(255, 255, 255, 0.04);
      color: #d8eaf6;
      font-size: 1.45rem;
      line-height: 1;
      cursor: pointer;
    }

    .fpw-member-required-close:hover,
    .fpw-member-required-close:focus-visible {
      border-color: rgba(35, 239, 228, 0.5);
      color: #ffffff;
      outline: none;
    }

    .fpw-member-required-body {
      padding: 22px 26px 28px;
    }

    .fpw-member-required-title {
      margin: 0 0 14px;
      color: #f2f8ff;
      font-size: clamp(1.7rem, 5vw, 2.2rem);
      line-height: 1.08;
      font-weight: 950;
      letter-spacing: -0.03em;
    }

    .fpw-member-required-message {
      margin: 0 0 24px;
      color: #b7ccda;
      font-size: 1.08rem;
      line-height: 1.45;
      font-weight: 650;
    }

    .fpw-member-required-actions {
      display: flex;
      flex-wrap: wrap;
      gap: 12px;
    }

    .fpw-member-required-action {
      display: inline-flex;
      min-height: 48px;
      align-items: center;
      justify-content: center;
      border-radius: 14px;
      padding: 0 18px;
      text-decoration: none;
      font-size: 1rem;
      font-weight: 850;
      cursor: pointer;
    }

    .fpw-member-required-action.primary {
      border: 0;
      background: linear-gradient(90deg, #27e1d1 0%, #4bc3ff 100%);
      color: #031722;
      box-shadow: 0 12px 30px rgba(33, 219, 224, 0.18);
    }

    .fpw-member-required-action.secondary {
      border: 1px solid rgba(149, 200, 218, 0.18);
      background: rgba(4, 20, 34, 0.52);
      color: #23efe4;
    }

    .fpw-member-required-action:hover,
    .fpw-member-required-action:focus-visible {
      transform: translateY(-1px);
      outline: none;
    }

    @media (max-width: 560px) {
      :root {
        --promo-strip-offset: 52px;
      }

      .promo-strip-copy {
        white-space: normal;
      }

      .fpw-member-required-modal {
        align-items: flex-end;
        padding: 16px;
      }

      .fpw-member-required-card {
        border-radius: 22px;
      }

      .fpw-member-required-header,
      .fpw-member-required-body {
        padding-left: 20px;
        padding-right: 20px;
      }

      .fpw-member-required-actions {
        display: grid;
      }
    }
  </style>
<link rel="stylesheet" href="assets/css/top-nav.css?v=20260530-nav-cta">
</head>
<body id="top">
<cfinclude template="includes/prelaunch_top_nav.cfm">

<cfif fpwShowMemberRequiredNotice>
  <cfoutput>
    <div class="fpw-member-required-modal" role="dialog" aria-modal="true" aria-labelledby="fpwMemberRequiredTitle" data-fpw-member-required-modal>
      <div class="fpw-member-required-card">
        <div class="fpw-member-required-header">
          <div class="fpw-member-required-eyebrow">Member access</div>
          <button type="button" class="fpw-member-required-close" aria-label="Close" data-fpw-member-required-close>&times;</button>
        </div>
        <div class="fpw-member-required-body">
          <h2 id="fpwMemberRequiredTitle" class="fpw-member-required-title">FloatPlanWizard member page</h2>
          <p class="fpw-member-required-message">You must be a member to view this page.</p>
          <div class="fpw-member-required-actions">
            <button type="button" class="fpw-member-required-action primary" data-fpw-member-required-login>Log In</button>
            <a class="fpw-member-required-action secondary" href="#topNavBasePath#/app/join.cfm">Create Free Account</a>
          </div>
        </div>
      </div>
    </div>
  </cfoutput>
</cfif>

  <main>
    <section class="hero">
      <div class="shell hero-grid">
        <div class="panel hero-copy">
          <div class="eyebrow"><i class="bi bi-stars" aria-hidden="true"></i>Set Sail with FloatPlanWizard</div>
          <h1><span class="gradient-text">Plan smarter.</span><br />Cruise prepared.<br />Keep everyone informed.</h1>
          <ul class="lead lead-bullets">
            <li>Shareable Trip page for family and friends</li>
            <li>Custom Route Builder. Plan your trip. Estimate your time and fuel needs.</li>
            <li>Create clear float plans with key trip and emergency details.</li>
            <li>Automatic overdue alerts help contacts act quickly if needed.</li>
          </ul>

          <div class="hero-points">
            <div class="hero-point">
              <b><i class="bi bi-life-preserver"></i>Smart Float Plans</b>
              <span>USCG-style float plans with automated monitoring. Critical information for emergencies.</span>
            </div>
            <div class="hero-point">
              <b><i class="bi bi-diagram-3"></i>Custom Route Builder</b>
              <span>Plan legs, pace, stops, timing, and fuel with tools built for real cruising.</span>
            </div>
            <div class="hero-point">
              <b><i class="bi bi-broadcast-pin"></i>Share the Trip</b>
              <span>Let family and friends stay connected during day trips, weekends, or longer voyages.</span>
            </div>
          </div>

          <div class="hero-cta">
            <a href="app/join.cfm" class="btn btn-primary fpw-hero-primary-cta">Claim Your Free Month <span class="fpw-cta-arrow" aria-hidden="true">&rarr;</span>
              </a>
            <a href="#great-loop" class="btn btn-secondary"><i class="bi bi-signpost-2"></i>Explore Great Loop Features</a>
          </div>
          <div class="micro" style="text-align:center;">
            Now live for beta launch. New members get 1 month of Premium free. No credit card required.
          </div>
        </div>

        <section class="panel hero-visual fpw-hero-product-preview" data-fpw-product-preview aria-label="FloatPlanWizard product preview">
          <div class="fpw-preview-header">
            <p class="fpw-preview-eyebrow">Product preview</p>
            <h2>See FloatPlanWizard in action</h2>
            <p>Build the route, monitor the trip, and share a private trip page with family or friends.</p>
          </div>

          <div class="fpw-preview-tabs" role="tablist" aria-label="Product preview pages">
            <button type="button" class="fpw-preview-tab is-active" id="fpw-preview-tab-route" data-preview-tab="route" role="tab" aria-selected="true" aria-controls="fpw-preview-panel-route">Route Generator</button>
            <button type="button" class="fpw-preview-tab" id="fpw-preview-tab-active-cruise" data-preview-tab="active-cruise" role="tab" aria-selected="false" aria-controls="fpw-preview-panel-active-cruise">Active Cruise</button>
            <button type="button" class="fpw-preview-tab" id="fpw-preview-tab-follow" data-preview-tab="follow" role="tab" aria-selected="false" aria-controls="fpw-preview-panel-follow">Shared Follow Page</button>
          <button type="button" class="fpw-preview-tab" id="fpw-preview-tab-dashboard" data-preview-tab="dashboard" role="tab" aria-selected="false" aria-controls="fpw-preview-panel-dashboard">Dashboard</button>
          </div>

          <div class="fpw-preview-browser-frame">
            <div class="fpw-preview-browser-bar" aria-hidden="true">
              <span></span><span></span><span></span>
            </div>

            <article class="fpw-preview-screen is-active" id="fpw-preview-panel-route" data-preview-panel="route" role="tabpanel" aria-labelledby="fpw-preview-tab-route">
              <div class="fpw-preview-image-wrap">
                <img src="<cfoutput>#topNavBasePath#</cfoutput>/assets/images/home/preview-route-generator.jpg" width="1200" height="760" loading="eager" alt="FloatPlanWizard Route Generator screen">
              </div>
              <div class="fpw-preview-caption">
                <h3>Route Generator</h3>
                <p>Plan your route, estimate timing, organize waypoints, and prepare the trip before leaving the dock.</p>
              </div>
            </article>

            <article class="fpw-preview-screen" id="fpw-preview-panel-active-cruise" data-preview-panel="active-cruise" role="tabpanel" aria-labelledby="fpw-preview-tab-active-cruise" hidden>
              <div class="fpw-preview-image-wrap">
                <img src="<cfoutput>#topNavBasePath#</cfoutput>/assets/images/home/preview-active-cruise.jpg" width="1200" height="760" loading="lazy" alt="FloatPlanWizard Active Cruise screen">
              </div>
              <div class="fpw-preview-caption">
                <h3>Active Cruise</h3>
                <p>Run the trip from one command page with progress, check-ins, monitoring status, weather, and fuel awareness.</p>
              </div>
            </article>

            <article class="fpw-preview-screen" id="fpw-preview-panel-follow" data-preview-panel="follow" role="tabpanel" aria-labelledby="fpw-preview-tab-follow" hidden>
              <div class="fpw-preview-image-wrap">
                <img src="<cfoutput>#topNavBasePath#</cfoutput>/assets/images/home/preview-follow-page.jpg" width="1200" height="760" loading="lazy" alt="FloatPlanWizard shared Follow page screen">
              </div>
              <div class="fpw-preview-caption">
                <h3>Shared Follow Page</h3>
                <p>Give family or friends a private link so they can see planned route details, stops, and trip progress updates.</p>
              </div>
            </article>

          <article class="fpw-preview-screen" id="fpw-preview-panel-dashboard" data-preview-panel="dashboard" role="tabpanel" aria-labelledby="fpw-preview-tab-dashboard" hidden>
            <div class="fpw-preview-image-wrap">
              <img src="<cfoutput>#topNavBasePath#</cfoutput>/assets/images/home/preview-dashboard.jpg" width="1200" height="760" loading="lazy" alt="FloatPlanWizard Dashboard screen">
            </div>
            <div class="fpw-preview-caption">
              <h3>Dashboard</h3>
              <p>Manage saved routes, review trip setup readiness, and open active cruise tools from one dashboard.</p>
            </div>
          </article>
          </div>

          <div class="fpw-preview-actions">
            <a class="btn btn-primary fpw-preview-primary" href="<cfoutput>#topNavBasePath#</cfoutput>/app/join.cfm">Start Free</a>
            <a class="fpw-preview-link" href="#notify">See what's included</a>
          </div>
        </section>
      </div>

      <section id="notify" class="fpw-home-access-section" style="--fpw-access-bg: url('assets/images/home/pricing-access-boat-bg.png');" aria-labelledby="fpwAccessTitle">
        <div class="fpw-home-access-inner">
          <div class="fpw-home-access-copy">
            <div class="fpw-home-access-badge">
              <span class="fpw-home-access-badge-dot" aria-hidden="true"></span>
              <span>NOW LIVE for 2026 BOATING SEASON</span>
            </div>

            <h2 id="fpwAccessTitle" class="fpw-home-access-title">
              Get 1 month of Premium for Free
            </h2>

            <p class="fpw-home-access-lede">
              Create your free FloatPlanWizard account and your first month of Premium is included — no credit card required.
            </p>

            <p class="fpw-home-access-text">
              During your free month of Premium, you'll have access to our Route Generator with Active Cruise, a private family and friends trip page with check-ins, delay updates, and trip status updates, and tools serious boaters can trust to cruise with confidence.
            </p>

            <p class="fpw-home-access-text">
              After your free month, you can stay on the free Basic plan for simple same-day float plans or upgrade only if you choose.
            </p>

            <div class="fpw-home-access-features" aria-label="FloatPlanWizard access highlights">
              <div class="fpw-home-access-feature">
                <span class="fpw-home-access-feature-icon" aria-hidden="true">
                  <svg viewBox="0 0 48 48" focusable="false">
                    <path d="M15 7h18l5 5v28a3 3 0 0 1-3 3H15a3 3 0 0 1-3-3V10a3 3 0 0 1 3-3Z"></path>
                    <path d="M32 7v7h7"></path>
                    <path d="M18 21h14"></path>
                    <path d="M18 28h14"></path>
                    <path d="M18 35h8"></path>
                  </svg>
                </span>
                <span>USCG Style Float Plan</span>
              </div>

              <div class="fpw-home-access-feature">
                <span class="fpw-home-access-feature-icon" aria-hidden="true">
                  <svg viewBox="0 0 48 48" focusable="false">
                    <path d="M8 31c4 0 4 4 8 4s4-4 8-4 4 4 8 4 4-4 8-4"></path>
                    <path d="M8 38c4 0 4 4 8 4s4-4 8-4 4 4 8 4 4-4 8-4"></path>
                    <circle cx="24" cy="17" r="9"></circle>
                    <path d="M24 10v7l5 3"></path>
                  </svg>
                </span>
                <span>Active Cruise + Shareable Trip page</span>
              </div>

              <div class="fpw-home-access-feature">
                <span class="fpw-home-access-feature-icon" aria-hidden="true">
                  <svg viewBox="0 0 48 48" focusable="false">
                    <circle cx="18" cy="16" r="7"></circle>
                    <path d="M6 39c1.7-8 6.3-12 12-12s10.3 4 12 12"></path>
                    <path d="M32 14h6a4 4 0 0 1 4 4v12a4 4 0 0 1-4 4h-8"></path>
                    <path d="M35 22v5"></path>
                    <path d="M32.5 24.5h5"></path>
                  </svg>
                </span>
                <span>NOAA Marine Weather</span>
              </div>
            </div>
          </div>

          <aside class="fpw-home-pricing-card" aria-label="Choose your access">
            <div class="fpw-home-pricing-eyebrow">CHOOSE YOUR ACCESS</div>
            <h3 class="fpw-home-pricing-title">Simple pricing for every trip.</h3>

            <div class="fpw-home-plan-list">
              <article class="fpw-home-plan-row">
                <div class="fpw-home-plan-icon" aria-hidden="true">
                  <svg viewBox="0 0 48 48" focusable="false">
                    <path d="M15 8h15l6 6v26H15z"></path>
                    <path d="M30 8v8h7"></path>
                    <path d="M20 24h12"></path>
                    <path d="M20 31h12"></path>
                  </svg>
                </div>
                <div class="fpw-home-plan-copy">
                  <strong>Free Basic</strong>
                  <span>Simple same-day float plan</span>
                </div>
                <div class="fpw-home-plan-price">$0</div>
              </article>

              <article class="fpw-home-plan-row">
                <div class="fpw-home-plan-icon" aria-hidden="true">
                  <svg viewBox="0 0 48 48" focusable="false">
                    <path d="M24 6 41 17 24 42 7 17z"></path>
                    <path d="M7 17h34"></path>
                    <path d="M17 17 24 42l7-25"></path>
                    <path d="M17 17 24 6l7 11"></path>
                  </svg>
                </div>
                <div class="fpw-home-plan-copy">
                  <strong>Premium Monthly</strong>
                  <span>Cancel anytime</span>
                </div>
                <div class="fpw-home-plan-price">$9.99<span>/mo</span></div>
              </article>

              <article class="fpw-home-plan-row fpw-home-plan-row-featured">
                <div class="fpw-home-plan-tag">BEST VALUE</div>
                <div class="fpw-home-plan-icon" aria-hidden="true">
                  <svg viewBox="0 0 48 48" focusable="false">
                    <path d="m8 37 4-24 10 10 8-14 8 14 10-10-4 24z"></path>
                    <path d="M10 42h28"></path>
                  </svg>
                </div>
                <div class="fpw-home-plan-copy">
                  <strong>Premium Annual</strong>
                  <span>Best value</span>
                </div>
                <div class="fpw-home-plan-price fpw-home-plan-price-accent">$89<span>/yr</span></div>
              </article>

              <article class="fpw-home-plan-row">
                <div class="fpw-home-plan-icon" aria-hidden="true">
                  <svg viewBox="0 0 48 48" focusable="false">
                    <rect x="9" y="11" width="30" height="29" rx="3"></rect>
                    <path d="M16 7v8"></path>
                    <path d="M32 7v8"></path>
                    <path d="M9 20h30"></path>
                    <path d="M17 27h5"></path>
                    <path d="M26 27h5"></path>
                    <path d="M17 34h5"></path>
                  </svg>
                </div>
                <div class="fpw-home-plan-copy">
                  <strong>3-Day Pass</strong>
                  <span>Great for a weekend cruise</span>
                </div>
                <div class="fpw-home-plan-price">$4.99</div>
              </article>
            </div>

            <div class="fpw-home-pricing-actions">
              <a class="fpw-home-secondary-cta" href="app/pricing.cfm">
                <span>View Full Pricing</span>
                <span aria-hidden="true">&rsaquo;</span>
              </a>
            </div>
          </aside>
        </div>
      </section>
    </section>

    <section id="features" class="section">
      <div class="shell">
        <div class="section-head"></div>

        <div class="features">
          <article class="feature">
            <div class="feature-icon"><i class="bi bi-life-preserver" aria-hidden="true"></i></div>
            <h3>Smart Float Plans</h3>
            <p>Create organized float plans with vessel details, route info, timing, contacts, and trip structure in one place.</p>
          </article>
          <article class="feature">
            <div class="feature-icon"><i class="bi bi-diagram-3" aria-hidden="true"></i></div>
            <h3>Route Builder</h3>
            <p>Build trip legs, organize stops, map out the journey, and prepare for longer cruising days with more clarity.</p>
          </article>
          <article class="feature">
            <div class="feature-icon"><i class="bi bi-people" aria-hidden="true"></i></div>
            <h3>Share the Trip</h3>
            <p>Give family and friends a private shared trip page where they can understand the trip and feel more connected.</p>
          </article>
          <article class="feature">
            <div class="feature-icon"><i class="bi bi-water" aria-hidden="true"></i></div>
            <h3>Voyage Organization</h3>
            <p>Built for day trips, overnights, weekend cruising, and ambitious journeys where planning and communication matter.</p>
          </article>
        </div>
      </div>
    </section>

    <section id="great-loop" class="section">
      <div class="shell grid-2">
        <div class="panel loop-card">
          <h2 style="margin:0;font-size:clamp(1.9rem,3vw,3rem);letter-spacing:-0.045em;line-height:1.04;">Designed with Great Loop cruisers in mind.</h2>
          <p style="margin:16px 0 0;color:var(--muted);line-height:1.75;font-size:1.02rem;">
            FloatPlanWizard is for all recreational boaters, but Great Loopers are a perfect fit. Long-distance cruising demands more preparation, better trip organization, and an easier way to keep family and friends informed throughout the voyage.
          </p>
          <div class="list">
            <div class="list-item">
              <div class="num">1</div>
              <div><strong>Great Loop route templates</strong><span>Start faster with planning tools geared toward one of boating's most iconic journeys.</span></div>
            </div>
            <div class="list-item">
              <div class="num">2</div>
              <div><strong>Leg-by-leg organization</strong><span>Break large voyages into manageable segments with clearer structure and timing.</span></div>
            </div>
            <div class="list-item">
              <div class="num">3</div>
              <div><strong>Family peace of mind</strong><span>A shared trip page makes it easier for loved ones to stay connected over a multi-stop trip.</span></div>
            </div>
            <div class="list-item">
              <div class="num">4</div>
              <div><strong>Built for repeat use</strong><span>Perfect for boaters planning seasonal loops, regional expeditions, or major cruising goals.</span></div>
            </div>
          </div>
          <div class="hero-cta" style="margin-top:22px;">
            <a href="great-loop/locks/" class="btn btn-secondary"><i class="bi bi-door-open"></i>Explore Great Loop Locks</a>
          </div>
        </div>

        <div class="panel map-card">
          <div class="map-frame"></div>
          <ul class="loop-feature-list" aria-label="Great Loop feature highlights">
            <li class="loop-feature-item">
              <span class="loop-feature-item-icon" aria-hidden="true"><i class="bi bi-signpost-2"></i></span>
              <span><strong>Route Leg Clarity:</strong> Keep each segment organized from ICW to inland rivers.</span>
            </li>
            <li class="loop-feature-item">
              <span class="loop-feature-item-icon" aria-hidden="true"><i class="bi bi-door-open"></i></span>
              <span><strong>Lock Readiness:</strong> Plan lock sequences and wait windows.</span>
            </li>
            <li class="loop-feature-item">
              <span class="loop-feature-item-icon" aria-hidden="true"><i class="bi bi-fuel-pump"></i></span>
              <span><strong>Fuel Range Confidence:</strong> Track distance-to-fuel and refill timing by leg.</span>
            </li>
            <li class="loop-feature-item">
              <span class="loop-feature-item-icon" aria-hidden="true"><i class="bi bi-cloud-sun"></i></span>
              <span><strong>Weather-Aware Timing:</strong> Adjust departure around fronts, wind, and seas.</span>
            </li>
            <li class="loop-feature-item">
              <span class="loop-feature-item-icon" aria-hidden="true"><i class="bi bi-broadcast-pin"></i></span>
              <span><strong>Shared Live Progress:</strong> Give family clear trip status with private trip updates.</span>
            </li>
          </ul>
        </div>
      </div>
    </section>

    <section id="followers" class="section">
      <div class="shell grid-2">
        <div class="panel follower-card">
          <div class="section-kicker">Keep Your Family Informed</div>
          <h2 style="margin:0;font-size:clamp(1.9rem,3vw,3rem);letter-spacing:-0.045em;line-height:1.05;">A better way to share the trip with family and friends.</h2>
          <p style="margin:16px 0 0;color:var(--muted);line-height:1.75;font-size:1.02rem;">
            One of FloatPlanWizard's strongest selling points is simple: it helps the people back home feel informed. That matters whether you are on a day cruise, a weekend run, or a long-distance Great Loop segment.
          </p>
          <div class="quotes">
            <div class="quote">"I just want an easy way to see where the trip is headed and what the plan is."<strong>Family perspective</strong></div>
            <div class="quote">"The route makes sense, the stops are clear, and I'm not guessing what's happening."<strong>Shared trip page benefit</strong></div>
            <div class="quote">"This feels more organized than texting updates one at a time."<strong>What the product promises</strong></div>
          </div>
        </div>

        <div class="panel follower-card">
          <div class="section-kicker">What they see</div>
          <div class="list" style="margin-top:0;">
            <div class="list-item">
              <div class="num">A</div>
              <div><strong>Planned route and key stops</strong><span>Clear trip structure instead of scattered updates.</span></div>
            </div>
            <div class="list-item">
              <div class="num">B</div>
              <div><strong>Trip context at a glance</strong><span>Departure, destination, and important voyage information in one place.</span></div>
            </div>
            <div class="list-item">
              <div class="num">C</div>
              <div><strong>Better confidence for loved ones</strong><span>A simple shareable experience designed to reduce uncertainty during the trip.</span></div>
            </div>
            <div class="list-item">
              <div class="num">D</div>
              <div><strong>Ideal for longer journeys</strong><span>Especially valuable for Loopers and serious cruisers covering a lot of water.</span></div>
            </div>
          </div>
          <div class="hero-cta" style="margin-top:22px;">
            <a href="app/join.cfm" class="btn btn-primary fpw-hero-primary-cta">Claim Your Free Month <span class="fpw-cta-arrow" aria-hidden="true">&rarr;</span></a>
          </div>
        </div>
      </div>
    </section>

    <section id="story" class="section fpw-live-builder-panel" aria-labelledby="fpwLiveBuilderTitle">
      <div class="shell">
        <div class="fpw-live-builder-inner">
          <div class="fpw-live-builder-copy">
            <div class="fpw-live-builder-badge">
              <span class="fpw-live-builder-dot" aria-hidden="true"></span>
              <span>LIVE NOW</span>
              <span class="fpw-live-builder-badge-separator" aria-hidden="true"></span>
              <span>2026 BOATING SEASON</span>
            </div>

            <h2 id="fpwLiveBuilderTitle" class="fpw-live-builder-title">
              Built by Boaters for Boaters
            </h2>

            <p class="fpw-live-builder-text">
              FloatPlanWizard was built by a boater who understands how much preparation matters before leaving the dock. The goal is simple: give recreational boaters a better way to organize trips, share plans, and keep family and friends informed with confidence.
            </p>

            <p class="fpw-live-builder-text">
              Create your free account and start with a simple same-day float plan, or upgrade when you need route-based planning, Active Cruise, Follow pages, and advanced monitoring tools.
            </p>
          </div>

          <aside class="fpw-live-builder-cta" aria-label="Get started with FloatPlanWizard">
            <div class="fpw-live-builder-cta-eyebrow">LIVE NOW</div>

            <h3 class="fpw-live-builder-cta-title">
              Get started today.
            </h3>

            <p class="fpw-live-builder-cta-copy">
              Create your first float plan in minutes and get the tools you need for safer, smarter boating.
            </p>

            <a class="fpw-live-builder-primary-cta" href="app/join.cfm">
              <span class="fpw-live-builder-button-icon" aria-hidden="true">
                <svg viewBox="0 0 48 48" focusable="false">
                  <path d="M24 6v18"></path>
                  <path d="M13 20h22l6 15H7z"></path>
                  <path d="M16 35c3 0 3 3 6 3s3-3 6-3 3 3 6 3"></path>
                  <path d="M18 20l3-8h6l3 8"></path>
                </svg>
              </span>
              <span>Claim Your Free Month</span>
              <span class="fpw-live-builder-arrow" aria-hidden="true">&rarr;</span>
            </a>

            <div class="fpw-live-builder-trust-line">
              <span aria-hidden="true">
                <svg viewBox="0 0 48 48" focusable="false">
                  <path d="M24 5 40 12v11c0 10-6.5 17.5-16 20-9.5-2.5-16-10-16-20V12z"></path>
                  <path d="m16 24 5 5 11-12"></path>
                </svg>
              </span>
              <strong>Secure. Private. Built for boaters.</strong>
            </div>

            <a class="fpw-live-builder-secondary-cta" href="app/pricing.cfm">
              <span>View plans and pricing</span>
              <span aria-hidden="true">&rsaquo;</span>
            </a>

            <p class="fpw-live-builder-note">
              Start free. Upgrade anytime. Cancel anytime on monthly Premium. No credit card required to join.
            </p>
          </aside>
        </div>
      </div>
    </section>
  </main>

  <cfinclude template="includes/footer.cfm">

  <script>
    (function () {
      var modal = document.querySelector('[data-fpw-member-required-modal]');
      if (!modal) return;

      var closeControls = Array.prototype.slice.call(modal.querySelectorAll('[data-fpw-member-required-close]'));
      var loginControl = modal.querySelector('[data-fpw-member-required-login]');
      var firstControl = closeControls[0] || loginControl;

      function removeNoticeParam() {
        if (!window.history || !window.history.replaceState || !window.URL) return;

        var currentUrl = new URL(window.location.href);
        if (currentUrl.searchParams.get('notice') !== 'member-required') return;

        currentUrl.searchParams.delete('notice');
        window.history.replaceState(
          {},
          document.title,
          currentUrl.pathname + currentUrl.search + currentUrl.hash
        );
      }

      function closeModal() {
        modal.setAttribute('hidden', 'hidden');
        document.body.classList.remove('fpw-member-required-open');
        removeNoticeParam();
      }

      function openLoginStrip() {
        closeModal();
        var loginToggle = document.getElementById('publicLoginToggle');
        if (loginToggle) {
          loginToggle.click();
          loginToggle.focus();
        }
      }

      document.body.classList.add('fpw-member-required-open');

      closeControls.forEach(function (control) {
        control.addEventListener('click', closeModal);
      });

      if (loginControl) {
        loginControl.addEventListener('click', function (event) {
          event.preventDefault();
          event.stopPropagation();
          openLoginStrip();
        });
      }

      modal.addEventListener('click', function (event) {
        if (event.target === modal) {
          closeModal();
        }
      });

      document.addEventListener('keydown', function (event) {
        if (event.key === 'Escape' && !modal.hasAttribute('hidden')) {
          closeModal();
        }
      });

      if (firstControl) {
        window.setTimeout(function () {
          firstControl.focus();
        }, 0);
      }
    })();

    (function () {
      const forms = [document.getElementById('waitlistForm'), document.getElementById('waitlistFormBottom')].filter(Boolean);
      if (!forms.length) {
        return;
      }

      function validateEmail(value) {
        const email = String(value || '').trim().toLowerCase();

        if (!email || email.length > 254) {
          return { valid: false, email, message: 'Please enter a valid email address.' };
        }
        if (/\s/.test(email)) {
          return { valid: false, email, message: 'Email cannot contain spaces.' };
        }

        const parts = email.split('@');
        if (parts.length !== 2) {
          return { valid: false, email, message: 'Email must include one @ symbol.' };
        }

        const local = parts[0];
        const domain = parts[1];
        if (!local || local.length > 64) {
          return { valid: false, email, message: 'Email local part is not valid.' };
        }
        if (local.startsWith('.') || local.endsWith('.') || local.includes('..')) {
          return { valid: false, email, message: 'Email local part is not valid.' };
        }
        if (!/^[a-z0-9!#$%&'*+/=?^_`{|}~.-]+$/i.test(local)) {
          return { valid: false, email, message: 'Email local part contains invalid characters.' };
        }

        if (!domain || domain.length > 253 || domain.includes('..')) {
          return { valid: false, email, message: 'Email domain is not valid.' };
        }
        const labels = domain.split('.');
        if (labels.length < 2) {
          return { valid: false, email, message: 'Email domain must include a top-level domain.' };
        }
        for (let i = 0; i < labels.length; i += 1) {
          const label = labels[i];
          if (!label || label.length > 63) {
            return { valid: false, email, message: 'Email domain labels are not valid.' };
          }
          if (label.startsWith('-') || label.endsWith('-')) {
            return { valid: false, email, message: 'Email domain labels are not valid.' };
          }
          if (!/^[a-z0-9-]+$/i.test(label)) {
            return { valid: false, email, message: 'Email domain contains invalid characters.' };
          }
        }

        const tld = labels[labels.length - 1];
        const isStandardTld = /^[a-z]{2,24}$/i.test(tld);
        const isPunycodeTld = /^xn--[a-z0-9-]{2,59}$/i.test(tld);
        if (!isStandardTld && !isPunycodeTld) {
          return { valid: false, email, message: 'Email top-level domain is not valid.' };
        }

        return { valid: true, email, message: '' };
      }

      function getUtmValues() {
        const params = new URLSearchParams(window.location.search || '');
        return {
          utm_source: (params.get('utm_source') || '').trim(),
          utm_medium: (params.get('utm_medium') || '').trim(),
          utm_campaign: (params.get('utm_campaign') || '').trim()
        };
      }

      function setButtonLoading(button, isLoading) {
        if (!button) return;

        if (!button.dataset.defaultLabel) {
          button.dataset.defaultLabel = button.innerHTML;
        }

        if (isLoading) {
          const fixedWidth = Math.ceil(button.getBoundingClientRect().width);
          button.style.width = fixedWidth + 'px';
          button.disabled = true;
          button.classList.add('is-loading');
          button.innerHTML = '<span class="btn-loading-indicator" aria-hidden="true"></span>';
          return;
        }

        button.disabled = false;
        button.classList.remove('is-loading');
        button.innerHTML = button.dataset.defaultLabel;
        button.style.width = '';
      }

      function getSignupContext(form) {
        const panel = form ? form.closest('.signup-panel') : null;
        return {
          panel,
          feedback: panel ? panel.querySelector('.signup-feedback') : null,
          success: panel ? panel.querySelector('.signup-success-state') : null
        };
      }

      function lockPanelHeight(context) {
        if (!context || !context.panel) return;
        if (context.panel.dataset.heightLocked === '1') return;
        context.panel.style.height = Math.ceil(context.panel.getBoundingClientRect().height) + 'px';
        context.panel.dataset.heightLocked = '1';
      }

      function setFeedback(context, message, tone) {
        if (!context || !context.feedback) return;
        context.feedback.textContent = message || '';
        if (tone === 'error') {
          context.feedback.style.color = 'var(--danger)';
        } else if (tone === 'success') {
          context.feedback.style.color = 'var(--success)';
        } else {
          context.feedback.style.color = 'var(--soft)';
        }
      }

      function showSuccessState(context, isDuplicate) {
        if (!context || !context.panel || !context.success) return;
        lockPanelHeight(context);
        const heading = context.success.querySelector('h4');
        const body = context.success.querySelector('p');
        const bonus = context.success.querySelector('.bonus');

        if (heading) {
          heading.textContent = isDuplicate ? "You're already on the list" : "You're on the list";
        }
        if (body) {
          body.textContent = isDuplicate
            ? "You're already on the early notification list. You'll continue receiving FloatPlanWizard launch updates and early access news."
            : "Thanks for joining early access. You'll receive FloatPlanWizard launch updates and early access news.";
        }
        if (bonus) {
          bonus.textContent = "As a thank-you for signing up early, you'll receive 2 months of premium membership free - no strings attached.";
        }

        setFeedback(context, '', 'neutral');
        context.panel.classList.add('is-success');
      }

      async function submitSignupForm(event) {
        event.preventDefault();
        const form = event.currentTarget;
        const input = form.querySelector('input[name="email"]');
        const button = form.querySelector('button[type="submit"]');
        const context = getSignupContext(form);
        if (!input || !button) return;

        const validation = validateEmail(input.value);
        if (!validation.valid) {
          setFeedback(context, validation.message || 'Please enter a valid email address.', 'error');
          input.focus();
          return;
        }
        const email = validation.email;

        setFeedback(context, '', 'neutral');
        lockPanelHeight(context);
        setButtonLoading(button, true);

        const utm = getUtmValues();
        const payload = new URLSearchParams();
        payload.set('action', 'earlyAccessSignup');
        payload.set('email', email);
        payload.set('source', 'prelaunch');
        if (utm.utm_source) payload.set('utm_source', utm.utm_source);
        if (utm.utm_medium) payload.set('utm_medium', utm.utm_medium);
        if (utm.utm_campaign) payload.set('utm_campaign', utm.utm_campaign);

        try {
          const response = await fetch(window.location.pathname + '?action=earlyAccessSignup', {
            method: 'POST',
            credentials: 'same-origin',
            headers: {
              'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
              'Accept': 'application/json'
            },
            body: payload.toString()
          });

          let result = null;
          try {
            result = await response.json();
          } catch (parseError) {
            result = null;
          }

          const isSuccess = Boolean(
            result && (
              result.success === true ||
              result.success === 'true' ||
              result.SUCCESS === true ||
              result.SUCCESS === 'true'
            )
          );

          if (!response.ok || !result || !isSuccess) {
            throw new Error(
              result && (result.message || result.MESSAGE)
                ? (result.message || result.MESSAGE)
                : 'Unable to complete signup right now. Please try again shortly.'
            );
          }

          form.reset();
          showSuccessState(context, Boolean(
            result.duplicate ||
            result.alreadyOnList ||
            result.DUPLICATE ||
            result.ALREADYONLIST
          ));
        } catch (error) {
          setFeedback(
            context,
            error && error.message ? error.message : 'Unable to complete signup right now. Please try again shortly.',
            'error'
          );
        } finally {
          setButtonLoading(button, false);
        }
      }

      forms.forEach(function (form) {
        form.addEventListener('submit', submitSignupForm);
      });
    })();

    (function () {
      const preview = document.querySelector('[data-fpw-product-preview]');
      if (!preview) return;

      const tabs = Array.from(preview.querySelectorAll('[data-preview-tab]'));
      const panels = Array.from(preview.querySelectorAll('[data-preview-panel]'));

      function activatePreview(previewName) {
        tabs.forEach(function (tab) {
          const isActive = tab.dataset.previewTab === previewName;
          tab.classList.toggle('is-active', isActive);
          tab.setAttribute('aria-selected', isActive ? 'true' : 'false');
        });

        panels.forEach(function (panel) {
          const isActive = panel.dataset.previewPanel === previewName;
          panel.classList.toggle('is-active', isActive);
          if (isActive) {
            panel.removeAttribute('hidden');
          } else {
            panel.setAttribute('hidden', '');
          }
        });
      }

      tabs.forEach(function (tab) {
        tab.addEventListener('click', function () {
          activatePreview(tab.dataset.previewTab);
        });

        tab.addEventListener('keydown', function (event) {
          if (event.key !== 'Enter' && event.key !== ' ') return;
          event.preventDefault();
          activatePreview(tab.dataset.previewTab);
        });
      });
    })();
</script>
</body>
</html>
