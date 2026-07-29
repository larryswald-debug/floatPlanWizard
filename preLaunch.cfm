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
</cfscript>
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>FloatPlanWizard | Boat Trip Planner, Float Plans & Shared Trip Updates</title>

<meta name="description" content="Plan safer boat trips with FloatPlanWizard. Create float plans, organize route details, estimate fuel needs, and share trip updates with family and friends. Join the prelaunch list.">

<link rel="canonical" href="https://floatplanwizard.com/">
  
  <link rel="preconnect" href="https://cdn.jsdelivr.net" crossorigin>
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.3/font/bootstrap-icons.min.css">
  <link rel="stylesheet" href="assets/css/layout.css?v=20260620-page-width">
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
      --max: var(--fpw-page-max, 1200px);
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
      width: min(var(--max), calc(100% - (var(--fpw-page-gutter, 32px) * 2)));
      margin: 0 auto;
    }

    .topbar {
      position: sticky;
      top: 0;
      z-index: 30;
      backdrop-filter: blur(18px);
      background: rgba(6, 17, 26, 0.68);
      border-bottom: 1px solid rgba(130, 186, 226, 0.12);
    }

    .promo-strip {
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
      gap: 20px;
      padding: 14px 0;
    }

    .brand {
      display: flex;
      align-items: center;
      gap: 14px;
      min-width: 0;
    }

    .brand-mark {
      width: 42px;
      height: 42px;
      border-radius: 14px;
      background:
        linear-gradient(145deg, rgba(71,199,255,0.24), rgba(24,242,210,0.16));
      border: 1px solid rgba(130, 186, 226, 0.24);
      display: grid;
      place-items: center;
      box-shadow: inset 0 1px 0 rgba(255,255,255,0.08), 0 8px 28px rgba(0,0,0,0.28);
      position: relative;
      overflow: hidden;
    }

    .brand-mark::before {
      content: "";
      position: absolute;
      inset: 0;
      background:
        radial-gradient(circle at 30% 30%, rgba(255,255,255,0.08), transparent 0 38%),
        linear-gradient(180deg, transparent, rgba(255,255,255,0.02));
      pointer-events: none;
    }

    .brand-mark i {
      position: relative;
      z-index: 1;
      font-size: 1.2rem;
      color: #bceaff;
      filter: drop-shadow(0 0 12px rgba(71,199,255,0.45));
    }

    .brand-copy { min-width: 0; }
    .brand-name {
      font-size: 1rem;
      font-weight: 800;
      letter-spacing: 0.02em;
    }
    .brand-tag {
      color: var(--muted);
      font-size: 0.82rem;
      margin-top: 2px;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }

    .nav {
      display: flex;
      align-items: center;
      gap: 10px;
      flex-wrap: wrap;
      justify-content: flex-end;
    }

    .nav a {
      color: var(--muted);
      padding: 10px 14px;
      border-radius: 999px;
      font-size: 0.94rem;
      transition: 0.2s ease;
    }

    .nav a:hover { color: var(--text); background: rgba(130,186,226,0.08); }

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
      font-size: clamp(1.9rem, 3.1vw, 2.8rem);
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

    footer {
      padding: 0 0 54px;
    }

    .footer-card {
      padding: 26px;
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 16px;
      flex-wrap: wrap;
      background: rgba(8,19,28,0.95);
    }

    .footer-card p {
      margin: 0;
      color: var(--muted);
      line-height: 1.6;
    }

    .footer-card .footer-copyright {
      display: block;
      margin-top: 6px;
      color: var(--soft);
      font-size: 0.84rem;
    }

    .footer-links {
      display: flex;
      gap: 12px;
      flex-wrap: wrap;
      color: var(--soft);
      font-size: 0.9rem;
      letter-spacing: 0.01em;
    }

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
      .features { grid-template-columns: repeat(2, minmax(0, 1fr)); }
      .quotes { grid-template-columns: 1fr; }
    }

    @media (max-width: 780px) {
      .shell { width: min(var(--max), calc(100% - (var(--fpw-page-gutter, 32px) * 2))); }
      .topbar-inner { align-items: flex-start; flex-direction: column; }
      .nav { width: 100%; justify-content: flex-start; }
      .hero { padding-top: 26px; }
      #great-loop { scroll-margin-top: calc(125px + var(--promo-strip-offset)); }
      #features { scroll-margin-top: calc(126px + var(--promo-strip-offset)); }
      #followers { scroll-margin-top: calc(126px + var(--promo-strip-offset)); }
      #story { scroll-margin-top: calc(126px + var(--promo-strip-offset)); }
      #notify { scroll-margin-top: calc(138px + var(--promo-strip-offset)); }
      .hero-copy, .hero-visual, .loop-card, .follower-card, .story-card, .cta-card { padding: 22px; }
      .waitlist-grid { padding: 22px 18px; gap: 18px; }
      .waitlist-signup-panel { padding: 16px; border-radius: 20px; }
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

    @media (max-width: 560px) {
      :root {
        --promo-strip-offset: 52px;
      }

      .promo-strip-copy {
        white-space: normal;
      }
    }
  </style>
<cfinclude template="includes/analytics_ga4.cfm">
<cfinclude template="includes/analytics_clarity.cfm">
</head>

<!--
  FloatPlanWizard Go-Live Homepage Markup
  Purpose:
  - Convert the existing prelaunch homepage into a live membership/signup homepage.
  - Preserve the current section flow and dark command-center design language.
  - Keep visuals mostly UI/cards/vector-style, not photography-heavy.

  Assumptions for Codex:
  - Replace href values with the real app routes if they differ.
  - Reuse existing site shell, typography, colors, buttons, and card classes where possible.
  - This is markup only; map these classes to existing/prelaunch CSS or add scoped CSS as needed.
-->

<div class="fpw-live-home">

  <!-- Top launch/member offer bar -->
  <div class="fpw-top-offer" role="region" aria-label="Launch offer">
    <div class="fpw-container fpw-top-offer__inner">
      <span class="fpw-top-offer__eyebrow">FloatPlanWizard is live</span>
      <span class="fpw-top-offer__text">Start free today. Optional Premium tools are available for longer voyages and advanced monitoring.</span>
      <a class="fpw-top-offer__link" href="/pricing.cfm">View Memberships</a>
    </div>
  </div>

  <!-- Header / Navigation -->
  <header class="fpw-header">
    <div class="fpw-container fpw-header__inner">

      <a class="fpw-brand" href="/" aria-label="FloatPlanWizard home">
        <span class="fpw-brand__mark" aria-hidden="true">☼</span>
        <span class="fpw-brand__text">
          <strong>FloatPlanWizard</strong>
          <small>Built for serious recreational boaters</small>
        </span>
      </a>

      <nav class="fpw-nav" aria-label="Primary navigation">
        <a href="/features.cfm">Features</a>
        <a href="/great-loop.cfm">Great Loop</a>
        <a href="/active-cruise.cfm">Active Cruise</a>
        <a href="/companion-app.cfm">Companion App</a>
        <a href="/pricing.cfm">Pricing</a>
        <a href="/how-it-works.cfm">How It Works</a>
      </nav>

      <div class="fpw-header__actions">
        <a class="fpw-btn fpw-btn--primary fpw-btn--small" href="/signup.cfm">Start Free</a>
        <a class="fpw-btn fpw-btn--ghost fpw-btn--small" href="/login.cfm">Sign In</a>
        <button class="fpw-menu-btn" type="button" aria-label="Open menu">
          <span aria-hidden="true">⋮⋮</span>
        </button>
      </div>

    </div>
  </header>

  <main id="mainContent">

    <!-- Hero Section -->
    <section class="fpw-hero" aria-labelledby="fpwHeroTitle">
      <div class="fpw-container fpw-hero__grid">

        <div class="fpw-hero__copy">

          <div class="fpw-status-pill">
            <span class="fpw-status-pill__dot" aria-hidden="true"></span>
            <span>FloatPlanWizard is live</span>
          </div>

          <h1 id="fpwHeroTitle">
            Plan <span>smarter.</span><br>
            Cruise prepared.<br>
            Keep everyone informed.
          </h1>

          <p class="fpw-hero__lead">
            Create organized float plans, build routes, monitor active trips, and share voyage progress with family and friends from one boating-focused platform.
          </p>

          <ul class="fpw-hero__bullets">
            <li>Create clear float plans with vessel, route, timing, passenger, and emergency details.</li>
            <li>Plan route legs, fuel stops, timing, overnight stops, and contingencies confidently.</li>
            <li>Keep trusted contacts informed with private shared trip pages and progress updates.</li>
            <li>Use active cruise monitoring, check-ins, and overdue alert workflows when underway.</li>
          </ul>

          <div class="fpw-hero__cards" aria-label="Core FloatPlanWizard capabilities">
            <article class="fpw-mini-card">
              <div class="fpw-mini-card__icon" aria-hidden="true">◉</div>
              <h2>Float Plans</h2>
              <p>USCG-style float plans with organized trip details and monitoring-ready structure.</p>
            </article>

            <article class="fpw-mini-card">
              <div class="fpw-mini-card__icon" aria-hidden="true">⌘</div>
              <h2>Route Builder</h2>
              <p>Plan legs, pace, stops, timing, and fuel with tools built for real cruising.</p>
            </article>

            <article class="fpw-mini-card">
              <div class="fpw-mini-card__icon" aria-hidden="true">≋</div>
              <h2>Share the Trip</h2>
              <p>Let family and friends follow the plan, stops, and updates without scattered texts.</p>
            </article>
          </div>

          <div class="fpw-hero__cta">
            <a class="fpw-btn fpw-btn--primary" href="/signup.cfm">Start Free</a>
            <a class="fpw-btn fpw-btn--secondary" href="/how-it-works.cfm">
              <span aria-hidden="true">▷</span>
              See How It Works
            </a>
            <a class="fpw-btn fpw-btn--text" href="/great-loop.cfm">Explore Great Loop Features</a>
          </div>

          <div class="fpw-trust-row" aria-label="Signup notes">
            <span><i aria-hidden="true">✓</i> Free plan available</span>
            <span><i aria-hidden="true">✓</i> No credit card required</span>
            <span><i aria-hidden="true">✓</i> Built by boaters</span>
          </div>

        </div>

        <!-- Hero Command Center Mockup -->
        <div class="fpw-command-shell" aria-label="Voyage command center preview">

          <div class="fpw-command-window">
            <div class="fpw-command-window__top">
              <div class="fpw-window-dots" aria-hidden="true">
                <span></span><span></span><span></span>
              </div>
              <strong>Voyage Command Center</strong>
              <span class="fpw-live-indicator">
                All Systems Go
                <i aria-hidden="true"></i>
              </span>
            </div>

            <div class="fpw-command-grid">

              <article class="fpw-command-card fpw-command-card--wide">
                <div class="fpw-card-kicker">Active Voyage</div>
                <h2>Tarpon Springs → Steinhatchee</h2>
                <div class="fpw-progress" aria-label="Voyage progress">
                  <span style="width: 37%;"></span>
                </div>
                <div class="fpw-card-meta">
                  <span>Leg 2 of 4</span>
                  <strong>37% Complete</strong>
                </div>
              </article>

              <article class="fpw-command-card fpw-command-card--status">
                <div class="fpw-card-kicker">Monitoring Status</div>
                <strong class="fpw-status-value">Monitoring Active</strong>
                <span>Next check-in due in</span>
                <b>1h 45m</b>
                <div class="fpw-radar" aria-hidden="true">
                  <span></span>
                </div>
              </article>

              <article class="fpw-command-card">
                <div class="fpw-card-kicker">Last Check-In</div>
                <strong>14 min ago</strong>
                <span>Today 9:16 AM</span>
                <em>On Track</em>
              </article>

              <article class="fpw-command-card">
                <div class="fpw-card-kicker">Next Check-In</div>
                <strong>Today 11:00 AM</strong>
                <span>In 1h 45m</span>
                <em>Expected</em>
              </article>

              <article class="fpw-command-card">
                <div class="fpw-card-kicker">Secure for Night</div>
                <strong>Yes</strong>
                <span>Until tomorrow</span>
                <em>8:00 AM</em>
              </article>

              <article class="fpw-command-card">
                <div class="fpw-card-kicker">Current Delay</div>
                <strong>15 min</strong>
                <span>Total applied</span>
                <em>Manual</em>
              </article>

              <article class="fpw-command-card">
                <div class="fpw-card-kicker">Weather Window</div>
                <strong>Favorable</strong>
                <span>Light winds ahead</span>
                <em>Checked</em>
              </article>

              <article class="fpw-command-card">
                <div class="fpw-card-kicker">Fuel Range</div>
                <strong>325 NM</strong>
                <span>Good</span>
                <em>On Plan</em>
              </article>

              <article class="fpw-command-card">
                <div class="fpw-card-kicker">Share the Trip</div>
                <strong>3 Followers</strong>
                <span>Updates active</span>
                <em>Private</em>
              </article>

              <article class="fpw-command-card">
                <div class="fpw-card-kicker">Companion App</div>
                <strong>Connected</strong>
                <span>GPS check-ins</span>
                <em>Ready</em>
              </article>

            </div>

            <div class="fpw-command-footer">
              <span>Voyage Status</span>
              <strong>On Plan</strong>
              <span>Last Updated: 9:16 AM</span>
              <span>All systems normal</span>
            </div>
          </div>

        </div>

      </div>
    </section>

    <!-- Membership / Signup Section -->
    <section class="fpw-membership" aria-labelledby="fpwMembershipTitle">
      <div class="fpw-container">

        <div class="fpw-section-header fpw-section-header--split">
          <div>
            <span class="fpw-section-kicker">Memberships are open</span>
            <h2 id="fpwMembershipTitle">Simple membership. Powerful boating tools.</h2>
            <p>Start free, then upgrade when you need advanced monitoring, Great Loop planning, companion workflows, and expanded cruise tools.</p>
          </div>
          <p class="fpw-section-note">No credit card required for the free plan.</p>
        </div>

        <div class="fpw-membership__grid">

          <article class="fpw-plan-card fpw-plan-card--free">
            <div class="fpw-plan-card__top">
              <div class="fpw-plan-card__icon" aria-hidden="true">♙</div>
              <div>
                <h3>Free</h3>
                <p>Everything you need to get started.</p>
              </div>
            </div>

            <ul class="fpw-check-list">
              <li>1 active route</li>
              <li>1 float plan</li>
              <li>Basic trip sharing</li>
              <li>Route planning tools</li>
              <li>Check-ins and monitoring basics</li>
              <li>Email support</li>
            </ul>

            <div class="fpw-plan-card__price">
              <strong>$0</strong>
              <span>/ month</span>
            </div>

            <a class="fpw-btn fpw-btn--primary fpw-btn--full" href="/signup.cfm">Start Free</a>
          </article>

          <article class="fpw-plan-card fpw-plan-card--premium">
            <div class="fpw-plan-card__top">
              <div class="fpw-plan-card__icon" aria-hidden="true">♛</div>
              <div>
                <h3>Premium</h3>
                <p>Advanced tools for serious cruisers.</p>
              </div>
            </div>

            <ul class="fpw-check-list">
              <li>Unlimited routes and float plans</li>
              <li>Advanced monitoring and alerts</li>
              <li>Companion app features</li>
              <li>Great Loop planning tools</li>
              <li>Weather and fuel planning</li>
              <li>Priority support</li>
            </ul>

            <div class="fpw-plan-card__price">
              <strong><!-- Replace with live price -->Premium</strong>
              <span>membership</span>
            </div>

            <a class="fpw-btn fpw-btn--accent fpw-btn--full" href="/pricing.cfm">Upgrade to Premium</a>
          </article>

          <aside class="fpw-member-fit-card" aria-labelledby="fpwMemberFitTitle">
            <h3 id="fpwMemberFitTitle">Built for boaters who:</h3>

            <ul class="fpw-icon-list">
              <li>
                <span aria-hidden="true">≋</span>
                <p>Cruise the ICW, inland rivers, coastal waters, or the Great Loop.</p>
              </li>
              <li>
                <span aria-hidden="true">⚓</span>
                <p>Plan day trips, overnights, weekend runs, and longer passages.</p>
              </li>
              <li>
                <span aria-hidden="true">⌬</span>
                <p>Want fuel, timing, route, stop, and check-in details organized before departure.</p>
              </li>
              <li>
                <span aria-hidden="true">👥</span>
                <p>Want family and friends to understand the trip without constant texting.</p>
              </li>
              <li>
                <span aria-hidden="true">♢</span>
                <p>Value preparation, safety, communication, and peace of mind.</p>
              </li>
            </ul>
          </aside>

        </div>

      </div>
    </section>

    <!-- Feature Grid -->
    <section class="fpw-features" aria-labelledby="fpwFeaturesTitle">
      <div class="fpw-container">

        <div class="fpw-section-header">
          <span class="fpw-section-kicker">Everything you need for a better voyage</span>
          <h2 id="fpwFeaturesTitle">Plan the trip. Monitor the voyage. Share the journey.</h2>
          <p>FloatPlanWizard combines route organization, float plans, trip monitoring, and private trip sharing in one connected workflow.</p>
        </div>

        <div class="fpw-feature-grid">

          <article class="fpw-feature-card">
            <div class="fpw-feature-card__icon" aria-hidden="true">◉</div>
            <h3>Smart Float Plans</h3>
            <p>Create organized float plans with vessel information, contacts, timing, route details, passengers, and emergency context.</p>
          </article>

          <article class="fpw-feature-card">
            <div class="fpw-feature-card__icon" aria-hidden="true">⌘</div>
            <h3>Route Builder</h3>
            <p>Build route legs, organize stops, estimate timing, plan fuel needs, and visualize your trip before leaving the dock.</p>
          </article>

          <article class="fpw-feature-card">
            <div class="fpw-feature-card__icon" aria-hidden="true">◎</div>
            <h3>Active Cruise Monitoring</h3>
            <p>Use check-ins, delays, secure-for-night status, monitoring checkpoints, and trip status updates while underway.</p>
          </article>

          <article class="fpw-feature-card">
            <div class="fpw-feature-card__icon" aria-hidden="true">👥</div>
            <h3>Share the Trip</h3>
            <p>Give family and friends a private shared trip page with the planned route, key stops, and progress updates.</p>
          </article>

          <article class="fpw-feature-card">
            <div class="fpw-feature-card__icon" aria-hidden="true">▯</div>
            <h3>Companion App</h3>
            <p>Check in from the boat, send GPS-aware updates, secure for the night, and keep monitoring data current.</p>
          </article>

          <article class="fpw-feature-card">
            <div class="fpw-feature-card__icon" aria-hidden="true">⌬</div>
            <h3>Great Loop Tools</h3>
            <p>Use planning tools for long-distance route segments, lock timing, fuel range, overnight stops, and shared progress.</p>
          </article>

          <article class="fpw-feature-card">
            <div class="fpw-feature-card__icon" aria-hidden="true">☼</div>
            <h3>Weather-Aware Timing</h3>
            <p>Plan departure timing around weather windows, fronts, wind, seas, and day-to-day cruising conditions.</p>
          </article>

          <article class="fpw-feature-card">
            <div class="fpw-feature-card__icon" aria-hidden="true">▣</div>
            <h3>Fuel Planning</h3>
            <p>Estimate distance, fuel range, refill timing, stop spacing, and leg-by-leg fuel confidence before departure.</p>
          </article>

          <article class="fpw-feature-card">
            <div class="fpw-feature-card__icon" aria-hidden="true">⚓</div>
            <h3>Lock & Leg Organization</h3>
            <p>Keep lock sequences, wait windows, bridges, marinas, anchorages, and route notes organized by leg.</p>
          </article>

          <article class="fpw-feature-card">
            <div class="fpw-feature-card__icon" aria-hidden="true">☾</div>
            <h3>Overnight & Resume</h3>
            <p>Secure for the night, preserve trip context, and resume next-day monitoring without rebuilding the voyage.</p>
          </article>

          <article class="fpw-feature-card">
            <div class="fpw-feature-card__icon" aria-hidden="true">✓</div>
            <h3>Check-Ins & Status Updates</h3>
            <p>Record on-track status, delays, assistance-needed signals, and other updates during the active trip.</p>
          </article>

          <article class="fpw-feature-card">
            <div class="fpw-feature-card__icon" aria-hidden="true">✉</div>
            <h3>Contacts & Emergency Details</h3>
            <p>Keep trusted contacts, vessel details, itinerary context, and important trip information together.</p>
          </article>

        </div>

      </div>
    </section>

    <!-- Great Loop Section -->
    <section class="fpw-great-loop" aria-labelledby="fpwGreatLoopTitle">
      <div class="fpw-container fpw-great-loop__grid">

        <div class="fpw-great-loop__copy">
          <span class="fpw-section-kicker">Built for the journey</span>
          <h2 id="fpwGreatLoopTitle">Great Loop ready.</h2>
          <p>
            From the Gulf to the Great Lakes and back again, FloatPlanWizard gives Loopers a structured way to plan route segments, organize stops, track fuel confidence, and keep family informed.
          </p>

          <ul class="fpw-check-list fpw-check-list--large">
            <li>Great Loop route templates</li>
            <li>Leg-by-leg planning with clarity</li>
            <li>Lock sequencing and wait-window notes</li>
            <li>Fuel planning and range tracking</li>
            <li>Overnight stops and secure-for-night workflows</li>
            <li>Shared progress with crew, family, and friends</li>
          </ul>

          <a class="fpw-btn fpw-btn--secondary" href="/great-loop.cfm">Explore Great Loop Features</a>
        </div>

        <div class="fpw-loop-panel" aria-label="Great Loop route preview">

          <div class="fpw-loop-map" aria-hidden="true">
            <svg viewBox="0 0 720 420" role="img" aria-label="Stylized Great Loop route map">
              <rect x="0" y="0" width="720" height="420" rx="24"></rect>

              <path class="fpw-map-land" d="M80 70 C150 35 245 30 330 55 C420 82 510 72 610 95 C665 110 700 155 690 220 C678 300 595 350 510 355 C420 360 350 338 270 370 C190 402 95 365 60 300 C25 230 30 115 80 70 Z"></path>

              <path class="fpw-map-route" d="M370 65
                C355 100 352 132 385 155
                C430 188 515 160 560 185
                C610 215 590 285 535 305
                C470 330 430 350 410 380
                C385 340 335 325 285 318
                C215 308 160 268 160 220
                C160 168 215 142 255 115
                C300 84 330 72 370 65"></path>

              <g class="fpw-map-pins">
                <circle cx="370" cy="65" r="7"></circle>
                <circle cx="560" cy="185" r="7"></circle>
                <circle cx="410" cy="380" r="7"></circle>
                <circle cx="160" cy="220" r="7"></circle>
              </g>

              <text x="390" y="80">Great Lakes</text>
              <text x="570" y="182">Atlantic</text>
              <text x="340" y="392">Gulf</text>
              <text x="115" y="220">Inland Rivers</text>
            </svg>
          </div>

          <div class="fpw-loop-stats">
            <article>
              <strong>~6,000 NM</strong>
              <span>Total loop distance</span>
            </article>
            <article>
              <strong>15+</strong>
              <span>States & provinces</span>
            </article>
            <article>
              <strong>200+</strong>
              <span>Possible stops</span>
            </article>
            <article>
              <strong>1 epic journey</strong>
              <span>Organized in FPW</span>
            </article>
          </div>

          <div class="fpw-loop-feature-list">
            <p><strong>Route Leg Clarity:</strong> Keep each segment organized from ICW to inland rivers.</p>
            <p><strong>Lock Readiness:</strong> Plan lock sequences and wait windows.</p>
            <p><strong>Fuel Range Confidence:</strong> Track distance-to-fuel and refill timing by leg.</p>
            <p><strong>Weather-Aware Timing:</strong> Adjust departure around fronts, wind, and seas.</p>
            <p><strong>Shared Live Progress:</strong> Give family clear trip status with private updates.</p>
          </div>

        </div>

      </div>
    </section>

    <!-- Companion App + Share Trip Split Section -->
    <section class="fpw-live-tools" aria-labelledby="fpwLiveToolsTitle">
      <div class="fpw-container">

        <div class="fpw-section-header">
          <span class="fpw-section-kicker">Connected while underway</span>
          <h2 id="fpwLiveToolsTitle">Simple check-ins from the boat. Clear updates back home.</h2>
        </div>

        <div class="fpw-live-tools__grid">

          <article class="fpw-companion-panel">
            <div class="fpw-phone-preview" aria-hidden="true">
              <div class="fpw-phone-preview__screen">
                <span class="fpw-phone-preview__top">FPW Companion</span>
                <div class="fpw-phone-preview__check">✓</div>
                <strong>Check-In Successful</strong>
                <span>Today 9:16 AM</span>
                <div class="fpw-phone-preview__row">
                  <span>Status</span>
                  <strong>On Track</strong>
                </div>
                <div class="fpw-phone-preview__row">
                  <span>Location</span>
                  <strong>GPS Sent</strong>
                </div>
                <button type="button">Secure for Night</button>
              </div>
            </div>

            <div>
              <span class="fpw-section-kicker">Companion App</span>
              <h3>One-tap trip updates from the boat.</h3>
              <p>Designed for real cruising conditions where marina Wi-Fi, cellular, and satellite connectivity can vary.</p>

              <ul class="fpw-check-list">
                <li>One-tap check-ins</li>
                <li>GPS location and timestamp updates</li>
                <li>Secure-for-night updates</li>
                <li>Delay or change-plan updates</li>
                <li>Works with weak-connectivity workflows</li>
              </ul>

              <a class="fpw-btn fpw-btn--secondary" href="/companion-app.cfm">Learn More</a>
            </div>
          </article>

          <article class="fpw-share-panel">
            <div>
              <span class="fpw-section-kicker">Share the Trip</span>
              <h3>Bring everyone along without constant texting.</h3>
              <p>A private shared trip page helps family, friends, and trusted contacts understand the route, plan, stops, and latest status.</p>

              <ul class="fpw-check-list">
                <li>Private trip page</li>
                <li>Real-time progress updates</li>
                <li>Planned route and key stops</li>
                <li>Check-in history</li>
                <li>Secure and private access</li>
                <li>No app required for followers</li>
              </ul>
            </div>

            <div class="fpw-shared-trip-card" aria-label="Shared trip page preview">
              <div class="fpw-shared-trip-card__top">
                <span aria-hidden="true">👥</span>
                <div>
                  <strong>Following: Summer Loop 2026</strong>
                  <small>Tarpon Springs → Chicago</small>
                </div>
              </div>

              <div class="fpw-progress" aria-label="Shared trip progress">
                <span style="width: 37%;"></span>
              </div>

              <div class="fpw-shared-trip-card__body">
                <p><strong>Latest Update</strong></p>
                <p>On the way to Steinhatchee. All systems go.</p>
                <span>14 min ago</span>
              </div>

              <a class="fpw-btn fpw-btn--secondary fpw-btn--full" href="/share-the-trip.cfm">View Trip Page Example</a>
            </div>
          </article>

        </div>

      </div>
    </section>

    <!-- Preserve Share / Family Informed Section -->
    <section class="fpw-family" aria-labelledby="fpwFamilyTitle">
      <div class="fpw-container fpw-family__grid">

        <div class="fpw-family__copy">
          <span class="fpw-section-kicker">Keep your family informed</span>
          <h2 id="fpwFamilyTitle">A better way to share the trip with family and friends.</h2>
          <p>
            One of FloatPlanWizard’s strongest selling points is simple: it helps the people back home feel informed. That matters whether you are on a day cruise, a weekend run, or a long-distance Great Loop segment.
          </p>

          <div class="fpw-quote-grid">
            <figure class="fpw-quote-card">
              <blockquote>“I just want an easy way to see where the trip is headed and what the plan is.”</blockquote>
              <figcaption>Family perspective</figcaption>
            </figure>

            <figure class="fpw-quote-card">
              <blockquote>“The route makes sense, the stops are clear, and I’m not guessing what’s happening.”</blockquote>
              <figcaption>Shared trip page benefit</figcaption>
            </figure>

            <figure class="fpw-quote-card">
              <blockquote>“This feels more organized than texting updates one at a time.”</blockquote>
              <figcaption>What the product promises</figcaption>
            </figure>
          </div>
        </div>

        <aside class="fpw-family__details" aria-labelledby="fpwFamilyDetailsTitle">
          <span class="fpw-section-kicker">What they see</span>
          <h3 id="fpwFamilyDetailsTitle">Trip clarity at a glance.</h3>

          <ol class="fpw-letter-list">
            <li>
              <span>A</span>
              <div>
                <strong>Planned route and key stops</strong>
                <p>Clear trip structure instead of scattered updates.</p>
              </div>
            </li>
            <li>
              <span>B</span>
              <div>
                <strong>Trip context at a glance</strong>
                <p>Departure, destination, timing, and important voyage information in one place.</p>
              </div>
            </li>
            <li>
              <span>C</span>
              <div>
                <strong>Better confidence for loved ones</strong>
                <p>A simple shareable experience designed to reduce uncertainty during the trip.</p>
              </div>
            </li>
            <li>
              <span>D</span>
              <div>
                <strong>Ideal for longer journeys</strong>
                <p>Especially valuable for Loopers and serious cruisers covering a lot of water.</p>
              </div>
            </li>
          </ol>

          <a class="fpw-btn fpw-btn--primary" href="/signup.cfm">Create Free Account</a>
        </aside>

      </div>
    </section>

    <!-- Built by Boaters CTA Section -->
    <section class="fpw-founder-cta" aria-labelledby="fpwFounderTitle">
      <div class="fpw-container fpw-founder-cta__grid">

        <div>
          <span class="fpw-section-kicker">Built by boaters for boaters</span>
          <h2 id="fpwFounderTitle">Built for the planning that happens before leaving the dock.</h2>
          <p>
            FloatPlanWizard was built by a boater who understands how much preparation matters. The goal is simple: give recreational boaters a better way to organize trips, share plans, monitor active cruises, and keep family and friends informed with confidence.
          </p>
          <p>
            Whether you are planning a day run, an overnight anchorage, a weekend cruise, or a Great Loop segment, FPW helps keep the important details in one place.
          </p>
        </div>

        <aside class="fpw-final-signup-card" aria-labelledby="fpwFinalSignupTitle">
          <span class="fpw-section-kicker">Start today</span>
          <h3 id="fpwFinalSignupTitle">Create your free account.</h3>
          <p>No credit card required. Upgrade anytime for Premium cruise planning and monitoring tools.</p>

          <form class="fpw-inline-signup" action="/signup.cfm" method="get">
            <label class="fpw-sr-only" for="fpwFinalEmail">Email address</label>
            <input id="fpwFinalEmail" name="email" type="email" placeholder="Email address" autocomplete="email">
            <button class="fpw-btn fpw-btn--primary" type="submit">Start Free</button>
          </form>

          <ul class="fpw-final-signup-card__notes">
            <li>Free plan available</li>
            <li>Secure and private</li>
            <li>Built for serious recreational boaters</li>
          </ul>
        </aside>

      </div>
    </section>

    <!-- Final Homepage CTA Band -->
    <section class="fpw-bottom-cta" aria-labelledby="fpwBottomCtaTitle">
      <div class="fpw-container fpw-bottom-cta__inner">
        <div>
          <h2 id="fpwBottomCtaTitle">Start planning your next adventure today.</h2>
          <p>Join boaters who want a clearer way to plan, monitor, and share their trips.</p>
        </div>

        <div class="fpw-bottom-cta__actions">
          <a class="fpw-btn fpw-btn--primary" href="/signup.cfm">Create Free Account</a>
          <a class="fpw-btn fpw-btn--secondary" href="/features.cfm">Explore Features</a>
        </div>

        <div class="fpw-bottom-cta__badges">
          <span><i aria-hidden="true">♢</i> Secure & Private</span>
          <span><i aria-hidden="true">☼</i> Built for Boaters</span>
        </div>
      </div>
    </section>

  </main>

  <!-- Footer -->
  <footer class="fpw-footer">
    <div class="fpw-container fpw-footer__grid">

      <div class="fpw-footer__brand">
        <a class="fpw-brand" href="/" aria-label="FloatPlanWizard home">
          <span class="fpw-brand__mark" aria-hidden="true">☼</span>
          <span class="fpw-brand__text">
            <strong>FloatPlanWizard</strong>
          </span>
        </a>
        <p>Plan the voyage. Share the journey. Keep everyone informed.</p>
      </div>

      <nav class="fpw-footer__nav" aria-label="Product links">
        <h3>Product</h3>
        <a href="/features.cfm">Features</a>
        <a href="/companion-app.cfm">Companion App</a>
        <a href="/pricing.cfm">Pricing</a>
        <a href="/how-it-works.cfm">How It Works</a>
      </nav>

      <nav class="fpw-footer__nav" aria-label="Resources links">
        <h3>Resources</h3>
        <a href="/help.cfm">Help Center</a>
        <a href="/blog.cfm">Blog</a>
        <a href="/great-loop.cfm">Great Loop Guide</a>
        <a href="/faq.cfm">FAQ</a>
      </nav>

      <nav class="fpw-footer__nav" aria-label="Company links">
        <h3>Company</h3>
        <a href="/about.cfm">About Us</a>
        <a href="/contact.cfm">Contact</a>
        <a href="/privacy.cfm">Privacy Policy</a>
        <a href="/terms.cfm">Terms of Service</a>
      </nav>

      <div class="fpw-footer__signup">
        <h3>Stay Connected</h3>
        <p>Get trip, planning, and boating-product updates.</p>

        <form class="fpw-footer-form" action="/subscribe.cfm" method="post">
          <label class="fpw-sr-only" for="fpwFooterEmail">Email address</label>
          <input id="fpwFooterEmail" name="email" type="email" placeholder="Enter your email" autocomplete="email">
          <button class="fpw-btn fpw-btn--primary fpw-btn--small" type="submit">Subscribe</button>
        </form>

        <div class="fpw-social-links" aria-label="Social links">
          <a href="#" aria-label="Facebook">f</a>
          <a href="#" aria-label="Instagram">◎</a>
          <a href="#" aria-label="YouTube">▶</a>
        </div>
      </div>

    </div>

    <div class="fpw-container fpw-footer__bottom">
      <p>© 2026 FloatPlanWizard. All rights reserved.</p>
      <p>Built for Great Loopers and serious recreational boaters.</p>
    </div>
  </footer>

</div>












  <script>
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
  </script>
</body>
</html>
