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
  <title>FloatPlanWizard — Goes Live Spring 2026</title>
  <meta name="description" content="FloatPlanWizard helps serious recreational boaters plan voyages, organize routes, and keep family and friends informed. Join the grand opening waitlist." />
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
      --max: 1200px;
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
      width: min(calc(100% - 32px), var(--max));
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
      content: "⚓";
      font-size: 20px;
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
      padding: 14px 22px;
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

    .hero {
      padding: 25px 0 20px;
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
      text-transform: camel-case;
      margin-bottom: 22px;
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

    .hero-cta {
      display: flex;
      flex-wrap: wrap;
      gap: 14px;
      margin-top: 30px;
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
      background-image: url("assets/images/prelaunch-great-loop-map-20260311-v2.png");
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
      gap: 8px;
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
      font-size: 2.0rem;
      line-height: 1;
    }

    /* Tighter, conversion-focused Follower View callout treatment */
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

    .footer-links {
      display: flex;
      gap: 16px;
      flex-wrap: wrap;
      color: var(--soft);
      font-size: 0.92rem;
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
      .shell { width: min(calc(100% - 20px), var(--max)); }
      .topbar-inner { align-items: flex-start; flex-direction: column; }
      .nav { width: 100%; justify-content: flex-start; }
      .hero { padding-top: 26px; }
      .hero-copy, .hero-visual, .loop-card, .follower-card, .story-card, .cta-card { padding: 22px; }
      .waitlist-grid { padding: 22px 18px; gap: 18px; }
      .waitlist-signup-panel { padding: 16px; border-radius: 20px; }
      .waitlist-proof { margin-top: 14px; }
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

  </style>
</head>
<body>
  <header class="topbar">
    <div class="shell topbar-inner">
      <a href="#top" class="brand" aria-label="FloatPlanWizard home">
        <div class="brand-mark"></div>
        <div class="brand-copy">
          <div class="brand-name">FloatPlanWizard</div>
          <div class="brand-tag">Pre-launch waitlist for serious recreational boaters</div>
        </div>
      </a>
      <nav class="nav" aria-label="Primary">
        <a href="#features">Features</a>
        <a href="#great-loop">Great Loop</a>
        <a href="#followers">Follower Pages</a>
        <a href="#story">Why FPW</a>
        <a href="#notify" class="btn btn-secondary">Get Notified</a>
      </nav>
    </div>
  </header>

  <main id="top">
    <section class="hero">
      <div class="shell hero-grid">
        <div class="panel hero-copy">
          <div class="eyebrow">Set Sail with FloatPlanWizard – Launching this spring</div>
          <h1><span class="gradient-text">Plan smarter.</span><br />Cruise prepared.<br />Keep everyone informed.</h1>
          <ul class="lead lead-bullets">
            <li>Build USCG-style float plans with key trip and emergency details.</li>
            <li>Plan route legs, pace, timing, fuel stops, and contingencies.</li>
            <li>Keep family and friends informed with private follower updates.</li>
   
            <li>Automatically sends overdue notices to your contacts if late.</li>
          </ul>

          <div class="hero-points">
            <div class="hero-point">
              <b>Float Plans</b>
              <span>USCG-style float plans with automated monitoring. Critical information for emergencies.</span>
            </div>
            <div class="hero-point">
              <b>Route Builder</b>
              <span>Plan legs, pace, stops, timing, and fuel with tools built for real cruising.</span>
            </div>
            <div class="hero-point">
              <b>Follower Pages</b>
              <span>Let family and friends stay connected during day trips, weekends, or longer voyages.</span>
            </div>
          </div>

          <div class="hero-cta">
            <a href="#notify" class="btn btn-primary">Join the Early Notification List</a>
            <a href="#great-loop" class="btn btn-secondary">See Great Loop Focus</a>
          </div>
          <div class="micro">Built for Great Loopers and all serious recreational boaters.</div>
        </div>

        <div class="panel hero-visual" aria-hidden="true">
          <div class="mockup">
            <div class="mockup-top">
              <div class="dots"><span></span><span></span><span></span></div>
              <div>Mission-ready Boating Dashboard</div>
            </div>
            <div class="mockup-body">
              <div class="stack">
                <div class="card">
                  <h3>Upcoming Voyage</h3>
                  <p>Organize the trip, route, departure timing, monitoring, and follower access before leaving the dock.</p>
                  <div class="route-lines">
                    <div class="route-line"><i></i><div>Tarpon Springs Departure</div><small>08:00</small></div>
                    <div class="route-line"><i></i><div>Fuel / Weather Check</div><small>10:30</small></div>
                    <div class="route-line"><i></i><div>Overnight Anchorage</div><small>17:15</small></div>
                    <div class="route-line"><i></i><div>Morning Leg Resume</div><small>07:00</small></div>
                  </div>
                </div>
                <div class="card follower-view-card">
                  <h3>Follower View</h3>
                  <p>Private trip page for family and friends to see planned route, key stops, and progress updates.</p>
                  <div class="follower-view-stats">
                    <div class="stat"><strong>24/7</strong><span>peace of mind</span></div>
                    <div class="stat"><strong>Loop</strong><span>friendly tools</span></div>
                    <div class="stat"><strong>1</strong><span>shareable trip link</span></div>
                  </div>
                </div>
              </div>
              <div class="stack">
                <div class="gauge">
                  <div class="ring">
                    <div>
                      <strong>82%</strong>
                      <span>voyage readiness</span>
                    </div>
                  </div>
                </div>
                <div class="card">
                  <h3>Route Builder Snapshot</h3>
                  <p>Visual planning tools for pace, route timing, trip structure, and long-distance cruise organization.</p>
                  <div class="signal-box">
                    <div class="signal"><b>Float Plan Status</b><span class="pill pill-ready">On Time</span></div>
                    <div class="signal"><b>Stream Enabled</b><span class="pill pill-track">Tracking</span></div>
                    <div class="signal"><b>Current Route</b><span class="pill pill-loop">Great Loop</span></div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <div class="shell">
        <div id="notify" class="panel waitlist-card">
          <div class="waitlist-grid">
            <div class="waitlist-copy">
              <div class="waitlist-copy-body">
                <div class="waitlist-eyebrow"><span class="waitlist-eyebrow-dot" aria-hidden="true"></span>Grand Opening Spring 2026</div>
                <h2>Be first to know when FloatPlanWizard goes live.</h2>
                <p class="waitlist-primary">
                  Join the pre-launch list for grand opening updates, early access news, and launch announcements built for serious recreational boaters and Great Loop cruisers.
                </p>
                <p class="waitlist-secondary">
                  From marina Wi-Fi and cellular to increasingly common Starlink-connected cruising, FloatPlanWizard is designed for modern boaters who want family and friends better informed while underway.
                </p>
                <p class="waitlist-secondary">
                  Signing up for launch notifications is free and requires no credit card. FloatPlanWizard will offer a free version at launch, with optional paid memberships available for advanced tools and features.
                </p>
              </div>
              <div class="waitlist-proof" aria-label="Launch benefits">
                <span class="waitlist-proof-pill"><span class="waitlist-proof-icon" aria-hidden="true">🛟</span><span>Better float-plan visibility</span></span>
                <span class="waitlist-proof-pill"><span class="waitlist-proof-icon" aria-hidden="true">📍</span><span>Live follower updates</span></span>
                <span class="waitlist-proof-pill"><span class="waitlist-proof-icon" aria-hidden="true">📡</span><span>Built for connected cruisers</span></span>
              </div>
            </div>
            <aside class="waitlist-signup-panel signup-panel" aria-label="Launch signup panel">
              <div class="signup-form-state">
                <div class="waitlist-panel-badge">Launch Notification</div>
                <h3>Get notified the moment FPW opens.</h3>
                <p>Designed for modern cruisers, including Great Loop boaters who rely on cellular and increasingly satellite connectivity like Starlink to stay connected underway.</p>
                <form class="signup" id="waitlistForm" novalidate>
                  <label class="sr-only" for="emailInput" style="position:absolute;left:-9999px;">Email address</label>
                  <input id="emailInput" name="email" type="email" placeholder="Enter your email address" autocomplete="email" required />
                  <button class="btn btn-primary" type="submit">Notify Me of Launch</button>
                </form>
                <div class="status">No spam. Just launch updates and early access news.</div>
                <div class="signup-feedback" id="signupStatus"></div>
                <div class="waitlist-signup-tags" aria-label="Connectivity profile">
                  <span class="waitlist-signup-tag">Great Loop Ready</span>
                  <span class="waitlist-signup-tag">Cell + Starlink</span>
                </div>
              </div>
              <div class="signup-success-state" id="signupSuccessPrimary" aria-live="polite">
                <h4>You're on the list</h4>
                <p>Thanks for joining early access. You'll receive FloatPlanWizard launch updates and early access news.</p>
                <div class="bonus">As a thank-you for signing up early, you'll receive 2 months of premium membership free - no strings attached.</div>
                <div class="subtle">Watch your inbox for launch updates.</div>
              </div>
            </aside>
          </div>
        </div>
      </div>
    </section>

    <section id="features" class="section">
      <div class="shell">
        <div class="section-head">
          <div class="section-kicker">Built for real-world boating</div>
          
        </div>

        <div class="features">
          <article class="feature">
            <div class="feature-icon">⚓</div>
            <h3>Smart Float Plans</h3>
            <p>Create organized float plans with vessel details, route info, timing, contacts, and trip structure in one place.</p>
          </article>
          <article class="feature">
            <div class="feature-icon">🧭</div>
            <h3>Route Builder</h3>
            <p>Build trip legs, organize stops, map out the journey, and prepare for longer cruising days with more clarity.</p>
          </article>
          <article class="feature">
            <div class="feature-icon">👨‍👩‍👧</div>
            <h3>Follower Pages</h3>
            <p>Give family and friends a simple private page where they can understand the trip and feel more connected.</p>
          </article>
          <article class="feature">
            <div class="feature-icon">🌊</div>
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
              <div><strong>Great Loop route templates</strong><span>Start faster with planning tools geared toward one of boating’s most iconic journeys.</span></div>
            </div>
            <div class="list-item">
              <div class="num">2</div>
              <div><strong>Leg-by-leg organization</strong><span>Break large voyages into manageable segments with clearer structure and timing.</span></div>
            </div>
            <div class="list-item">
              <div class="num">3</div>
              <div><strong>Family peace of mind</strong><span>Follower tools make it easier for loved ones to stay connected over a multi-stop trip.</span></div>
            </div>
            <div class="list-item">
              <div class="num">4</div>
              <div><strong>Built for repeat use</strong><span>Perfect for boaters planning seasonal loops, regional expeditions, or major cruising goals.</span></div>
            </div>
          </div>
        </div>

        <div class="panel map-card">
          <div class="map-frame">
          </div>
          <ul class="loop-feature-list" aria-label="Great Loop feature highlights">
            <li class="loop-feature-item"><span class="loop-feature-item-icon" aria-hidden="true">🧭</span><span><strong>Route Leg Clarity:</strong> Keep each segment organized from ICW to inland rivers.</span></li>
            <li class="loop-feature-item"><span class="loop-feature-item-icon" aria-hidden="true">🛟</span><span><strong>Lock Readiness:</strong> Plan lock sequences and wait windows.</span></li>
            <li class="loop-feature-item"><span class="loop-feature-item-icon" aria-hidden="true">⛽</span><span><strong>Fuel Range Confidence:</strong> Track distance-to-fuel and refill timing by leg.</span></li>
            <li class="loop-feature-item"><span class="loop-feature-item-icon" aria-hidden="true">🌦️</span><span><strong>Weather-Aware Timing:</strong> Adjust departure around fronts, wind, and seas.</span></li>
            <li class="loop-feature-item"><span class="loop-feature-item-icon" aria-hidden="true">📍</span><span><strong>Shared Live Progress:</strong> Give family clear trip status with follower updates.</span></li>
          </ul>
        </div>
      </div>
    </section>

    <section id="followers" class="section">
      <div class="shell grid-2">
        <div class="panel follower-card">
          <div class="section-kicker">Keep Your Family Informed</div>
          <h2 style="margin:0;font-size:clamp(1.9rem,3vw,3rem);letter-spacing:-0.045em;line-height:1.05;">A better way for family and friends to follow the trip.</h2>
          <p style="margin:16px 0 0;color:var(--muted);line-height:1.75;font-size:1.02rem;">
            One of FloatPlanWizard’s strongest selling points is simple: it helps the people back home feel informed. That matters whether you are on a day cruise, a weekend run, or a long-distance Great Loop segment.
          </p>
          <div class="quotes">
            <div class="quote">“I just want an easy way to see where the trip is headed and what the plan is.”<strong>Family perspective</strong></div>
            <div class="quote">“The route makes sense, the stops are clear, and I’m not guessing what’s happening.”<strong>Follower page benefit</strong></div>
            <div class="quote">“This feels more organized than texting updates one at a time.”<strong>What the product promises</strong></div>
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
            <a href="#notify" class="btn btn-primary">Join the Pre-Launch List</a>
          </div>
        </div>
      </div>
    </section>

    <section id="story" class="section">
      <div class="shell">
        <div class="panel story-card">
          <div class="story-layout">
            <div class="story-content">
              <h2>Built by Boaters for Boaters</h2>
              <p class="story-founder">
                FloatPlanWizard was built by a boater who understands how much preparation matters before leaving the dock. The goal is simple: give recreational boaters a better way to organize trips, share plans, and keep family and friends informed with confidence.
              </p>
              <p class="story-notify">
                Join the early notification list to be among the first to know when FloatPlanWizard opens to the public.
              </p>
            </div>
            <div class="story-signup signup-panel">
              <div class="signup-form-state">
                <div class="story-launch-callout">Grand Opening - Spring 2026</div>
                <form class="signup story-signup-form" id="waitlistFormBottom" novalidate>
                  <input id="emailInputBottom" name="email" type="email" placeholder="Email for grand opening updates" autocomplete="email" required />
                  <button class="btn btn-primary" type="submit">Notify Me of Launch</button>
                </form>
                <div class="story-trust-line">No credit card required. Free version available at launch.</div>
                <div class="status story-signup-status">No spam. Just launch updates and early access news.</div>
                <div class="signup-feedback story-signup-status" id="signupStatusBottom"></div>
              </div>
              <div class="signup-success-state" id="signupSuccessBottom" aria-live="polite">
                <h4>You're on the list</h4>
                <p>Thanks for joining early access. You'll receive FloatPlanWizard launch updates and early access news.</p>
                <div class="bonus">As a thank-you for signing up early, you'll receive 2 months of premium membership free - no strings attached.</div>
                <div class="subtle">Watch your inbox for launch updates.</div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  </main>

  <footer>
    <div class="shell">
      <div class="panel footer-card">
        <p><strong>FloatPlanWizard</strong><br />Plan the voyage. Share the journey. Keep everyone informed.</p>
        <div class="footer-links">
          <span>Going Live: Spring, 2026</span>
          <span>Built for Great Loopers</span>
          <span>Made for recreational boaters</span>
        </div>
      </div>
    </div>
  </footer>

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
          button.dataset.defaultLabel = button.textContent.trim();
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
