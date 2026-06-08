<cfprocessingdirective pageencoding="utf-8">
<cfsetting showdebugoutput="false" requesttimeout="30">
<cfcontent type="text/html; charset=utf-8">

<cfscript>
releaseTitle = "FloatPlanWizard Launch Press Release | Safer Recreational Boating";
releaseHeading = "Gulf Harbors Resident Launches FloatPlanWizard.com to Promote Safer Recreational Boating";
releaseDescription = "Gulf Harbors resident Larry Wald launches FloatPlanWizard.com to help recreational boaters create float plans and share trip details with trusted contacts.";
releaseCanonical = "https://floatplanwizard.com/press/floatplanwizard-launches.cfm";
releaseSocialImage = "https://floatplanwizard.com/assets/images/social/floatplanwizard-social-preview-20260602.png";
pressContactEmail = "support@floatplanwizard.com";
pressContactMailto = "mailto:" & pressContactEmail & "?subject=FloatPlanWizard%20Media%20Inquiry";
</cfscript>

<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title><cfoutput>#encodeForHtml(releaseTitle)#</cfoutput></title>
  <meta name="description" content="<cfoutput>#encodeForHtmlAttribute(releaseDescription)#</cfoutput>">
  <link rel="canonical" href="<cfoutput>#releaseCanonical#</cfoutput>">
  <meta property="og:type" content="article">
  <meta property="og:site_name" content="FloatPlanWizard">
  <meta property="og:url" content="<cfoutput>#releaseCanonical#</cfoutput>">
  <meta property="og:title" content="<cfoutput>#encodeForHtmlAttribute(releaseTitle)#</cfoutput>">
  <meta property="og:description" content="<cfoutput>#encodeForHtmlAttribute(releaseDescription)#</cfoutput>">
  <meta property="og:image" content="<cfoutput>#releaseSocialImage#</cfoutput>">
  <meta property="og:image:secure_url" content="<cfoutput>#releaseSocialImage#</cfoutput>">
  <meta property="og:image:type" content="image/png">
  <meta property="og:image:width" content="1200">
  <meta property="og:image:height" content="630">
  <meta property="og:image:alt" content="FloatPlanWizard boating trip planning and monitored float plan preview image">
  <meta name="twitter:card" content="summary_large_image">
  <meta name="twitter:title" content="<cfoutput>#encodeForHtmlAttribute(releaseTitle)#</cfoutput>">
  <meta name="twitter:description" content="<cfoutput>#encodeForHtmlAttribute(releaseDescription)#</cfoutput>">
  <meta name="twitter:image" content="<cfoutput>#releaseSocialImage#</cfoutput>">
  <meta name="twitter:image:alt" content="FloatPlanWizard boating trip planning and monitored float plan preview image">

  <cfinclude template="../includes/header_styles.cfm">
  <link rel="stylesheet" href="<cfoutput>#request.fpwBase#</cfoutput>/assets/css/press.css?v=20260607-press-media">
</head>

<body class="fpw-press-body">
  <cfinclude template="../includes/top_nav.cfm">

  <main class="fpw-press-main fpw-press-release">
    <a class="fpw-press-back" href="<cfoutput>#request.fpwBase#</cfoutput>/press.cfm">Back to Press Kit</a>

    <section class="fpw-press-hero" aria-labelledby="releaseTitle">
      <p class="fpw-press-eyebrow">For Immediate Release - June 7, 2026</p>
      <h1 id="releaseTitle"><cfoutput>#encodeForHtml(releaseHeading)#</cfoutput></h1>
      <p class="fpw-press-release-lede">
        FloatPlanWizard.com has launched as a boating trip-planning and float plan service for recreational boaters.
      </p>

      <div class="fpw-press-actions" aria-label="Press release actions">
        <span class="fpw-press-button fpw-press-button-disabled" role="link" aria-disabled="true">Download PDF <small>Coming soon</small></span>
        <span class="fpw-press-button fpw-press-button-disabled" role="link" aria-disabled="true">Download Media Kit <small>Coming soon</small></span>
        <a class="fpw-press-button fpw-press-button-primary" href="<cfoutput>#pressContactMailto#</cfoutput>">Contact Founder</a>
      </div>
    </section>

    <article class="fpw-press-release-shell fpw-press-article">
      <p class="fpw-press-meta">GULF HARBORS, Fla. - June 7, 2026</p>

      <p>
        FloatPlanWizard.com, a boating trip-planning and float plan service created by Gulf Harbors resident,
        longtime boater, and web developer Larry Wald, has launched to help recreational boaters create float
        plans and share trip details with trusted contacts.
      </p>

      <p>
        FloatPlanWizard was built to promote safer recreational boating by making float plans easier, more
        accessible, and affordable. The service helps boaters organize route details before departure and gives
        trusted contacts a clearer way to follow planned trip information and updates.
      </p>

      <p>
        The service includes monitored float plans, boat trip planning tools, Active Cruise pages for underway
        trip status, Shared Trip pages for trusted contacts, marine weather access for members, mobile-friendly
        trip planning pages, and a companion app option for simplified check-ins.
      </p>

      <p>
        FloatPlanWizard is intended for recreational boaters, marinas, yacht clubs, boating safety groups, and
        boating organizations that want to encourage practical float plan habits. Membership cost is intentionally
        kept low because boating safety tools only help if people actually use them.
      </p>

      <section aria-labelledby="releaseSafetyTitle">
        <h2 id="releaseSafetyTitle">Safety Notice</h2>
        <p>
          FloatPlanWizard is not an emergency dispatch, rescue, or distress-response service. In an emergency,
          boaters should use official emergency channels such as VHF Channel 16, DSC distress, 911, EPIRB/PLB,
          flares, or other accepted emergency methods.
        </p>
      </section>

      <section aria-labelledby="aboutFpwTitle">
        <h2 id="aboutFpwTitle">About FloatPlanWizard</h2>
        <p>
          FloatPlanWizard.com is a boating trip-planning and float plan service built to help recreational
          boaters prepare routes, organize vessel and trip details, share trip information, and use planning
          tools before and during a voyage.
        </p>
      </section>

      <section aria-labelledby="releaseContactTitle">
        <h2 id="releaseContactTitle">Media Contact</h2>
        <p>
          Larry Wald<br>
          Owner / Developer<br>
          FloatPlanWizard.com<br>
          Email: <a href="<cfoutput>#pressContactMailto#</cfoutput>"><cfoutput>#encodeForHtml(pressContactEmail)#</cfoutput></a><br>
          Website: <a href="https://floatplanwizard.com">https://floatplanwizard.com</a>
        </p>
      </section>

      <div class="fpw-press-actions" aria-label="Press release footer actions">
        <a class="fpw-press-button" href="<cfoutput>#request.fpwBase#</cfoutput>/press.cfm">Back to Press Kit</a>
        <span class="fpw-press-button fpw-press-button-disabled" role="link" aria-disabled="true">Download PDF <small>Coming soon</small></span>
        <span class="fpw-press-button fpw-press-button-disabled" role="link" aria-disabled="true">Download Media Kit <small>Coming soon</small></span>
        <a class="fpw-press-button fpw-press-button-primary" href="<cfoutput>#pressContactMailto#</cfoutput>">Contact Founder</a>
      </div>
    </article>
  </main>

  <cfinclude template="../includes/footer.cfm">
</body>
</html>
