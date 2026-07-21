

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

schemaAtKey = chr(64);
schemaTypeKey = schemaAtKey & "type";
schemaIdKey = schemaAtKey & "id";
schemaContextKey = schemaAtKey & "context";
schemaGraphKey = schemaAtKey & "graph";

function fpwHomeSchemaRef(required string idValue) {
  var out = structNew("ordered");
  structInsert(out, schemaIdKey, arguments.idValue, true);
  return out;
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

fpwHomeCanonicalUrl = "https://floatplanwizard.com/";
fpwHomePageTitle = "FloatPlanWizard | Boat Trip Planner, Float Plans & Shared Trip Updates";
fpwHomePageDescription = "Plan safer boat trips with float plans, route planning, check-ins, shared trip pages, and overdue monitoring for recreational boaters.";
fpwHomeJsonLdText = "";
fpwHomeSchemaGraph = [];
fpwHomeSchemaOrg = structNew("ordered");
fpwHomeSchemaWebsite = structNew("ordered");
fpwHomeSchemaPage = structNew("ordered");
fpwHomeJsonLd = structNew("ordered");

structInsert(fpwHomeSchemaOrg, schemaTypeKey, "Organization", true);
structInsert(fpwHomeSchemaOrg, schemaIdKey, "https://floatplanwizard.com/##organization", true);
fpwHomeSchemaOrg["name"] = "FloatPlanWizard";
fpwHomeSchemaOrg["url"] = "https://floatplanwizard.com/";
fpwHomeSchemaOrg["logo"] = "https://floatplanwizard.com/assets/images/checkout/floatplanwizard-logo.jpg";
arrayAppend(fpwHomeSchemaGraph, fpwHomeSchemaOrg);

structInsert(fpwHomeSchemaWebsite, schemaTypeKey, "WebSite", true);
structInsert(fpwHomeSchemaWebsite, schemaIdKey, "https://floatplanwizard.com/##website", true);
fpwHomeSchemaWebsite["name"] = "FloatPlanWizard";
fpwHomeSchemaWebsite["url"] = "https://floatplanwizard.com/";
fpwHomeSchemaWebsite["description"] = fpwHomePageDescription;
fpwHomeSchemaWebsite["publisher"] = fpwHomeSchemaRef("https://floatplanwizard.com/##organization");
arrayAppend(fpwHomeSchemaGraph, fpwHomeSchemaWebsite);

structInsert(fpwHomeSchemaPage, schemaTypeKey, "WebPage", true);
structInsert(fpwHomeSchemaPage, schemaIdKey, fpwHomeCanonicalUrl & "##webpage", true);
fpwHomeSchemaPage["url"] = fpwHomeCanonicalUrl;
fpwHomeSchemaPage["name"] = fpwHomePageTitle;
fpwHomeSchemaPage["description"] = fpwHomePageDescription;
fpwHomeSchemaPage["isPartOf"] = fpwHomeSchemaRef("https://floatplanwizard.com/##website");
fpwHomeSchemaPage["publisher"] = fpwHomeSchemaRef("https://floatplanwizard.com/##organization");
arrayAppend(fpwHomeSchemaGraph, fpwHomeSchemaPage);

structInsert(fpwHomeJsonLd, schemaContextKey, "https://schema.org", true);
structInsert(fpwHomeJsonLd, schemaGraphKey, fpwHomeSchemaGraph, true);
fpwHomeJsonLdText = replace(serializeJSON(fpwHomeJsonLd), "</", "<\/", "all");
</cfscript>
<cfinclude template="includes/fpw_base_path.cfm">
<cfset landingBasePath = request.fpwBase>
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>FloatPlanWizard | Boat Trip Planner, Float Plans & Shared Trip Updates</title>

<meta name="description" content="Plan safer boat trips with float plans, route planning, check-ins, shared trip pages, and overdue monitoring for recreational boaters.">

<link rel="canonical" href="https://floatplanwizard.com/">

<meta property="og:type" content="website">
<meta property="og:site_name" content="FloatPlanWizard">
<meta property="og:url" content="https://floatplanwizard.com/">
<meta property="og:title" content="FloatPlanWizard | Boat Trip Planner, Float Plans & Shared Trip Updates">
<meta property="og:description" content="Plan safer boat trips with float plans, route planning, check-ins, shared trip pages, and overdue monitoring for recreational boaters.">

<meta property="og:image" content="https://floatplanwizard.com/assets/images/social/floatplanwizard-social-preview-20260602.png">
<meta property="og:image:secure_url" content="https://floatplanwizard.com/assets/images/social/floatplanwizard-social-preview-20260602.png">
<meta property="og:image:type" content="image/png">
<meta property="og:image:width" content="1200">
<meta property="og:image:height" content="630">
<meta property="og:image:alt" content="FloatPlanWizard boating trip planning and monitored float plan preview image">
<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:title" content="FloatPlanWizard | Boat Trip Planner, Float Plans & Shared Trip Updates">
<meta name="twitter:description" content="Plan safer boat trips with float plans, route planning, check-ins, shared trip pages, and overdue monitoring for recreational boaters.">
<meta name="twitter:image" content="https://floatplanwizard.com/assets/images/social/floatplanwizard-social-preview-20260602.png">
<meta name="twitter:image:alt" content="FloatPlanWizard boating trip planning and monitored float plan preview image">
<script type="application/ld+json"><cfoutput>#fpwHomeJsonLdText#</cfoutput></script>

  <link rel="icon" type="image/svg+xml" href="<cfoutput>#landingBasePath#</cfoutput>/assets/images/landing/fpw-logo.svg">
  <link rel="stylesheet" href="<cfoutput>#landingBasePath#</cfoutput>/assets/css/fpw-conversion-landing.css?v=20260703-preview-light">
  <link rel="stylesheet" href="<cfoutput>#landingBasePath#</cfoutput>/assets/css/top-nav.css?v=20260630-mega-weight-minus1">
  <style>
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

    /* Footer variant is selected in includes/footer.cfm. */
  </style>
<cfinclude template="includes/analytics_ga4.cfm">
<cfinclude template="includes/analytics_clarity.cfm">
<cfinclude template="includes/trustedsite.cfm">
</head>
<body id="top" class="fpw-home-page">

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
            <a class="fpw-member-required-action secondary" href="#landingBasePath#/app/join.cfm">Create Free Account</a>
          </div>
        </div>
      </div>
    </div>
  </cfoutput>
</cfif>

<cfinclude template="partials/fpw-conversion-landing.cfm">

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

      function openLoginPage() {
        closeModal();
        window.location.href = '<cfoutput>#JSStringFormat(landingBasePath)#</cfoutput>/app/login.cfm';
      }

      document.body.classList.add('fpw-member-required-open');

      closeControls.forEach(function (control) {
        control.addEventListener('click', closeModal);
      });

      if (loginControl) {
        loginControl.addEventListener('click', function (event) {
          event.preventDefault();
          event.stopPropagation();
          openLoginPage();
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
  </script>
  <script src="<cfoutput>#landingBasePath#</cfoutput>/assets/js/fpw-conversion-landing.js?v=20260703-preview-tabs"></script>

</body>
</html>
