<cfprocessingdirective pageencoding="utf-8">
<cfsetting showdebugoutput="false" requesttimeout="30">
<cfcontent type="text/html; charset=utf-8">

<cfscript>
pressTitle = "FloatPlanWizard Press & Media Kit | Boating Safety & Float Plans";
pressDescription = "Media resources for FloatPlanWizard, a boating trip-planning and float plan service created to promote safer recreational boating.";
pressCanonical = "https://floatplanwizard.com/press.cfm";
pressSocialImage = "https://floatplanwizard.com/assets/images/social/floatplanwizard-social-preview-20260602.png";
pressContactEmail = "support@floatplanwizard.com";
pressContactMailto = "mailto:" & pressContactEmail & "?subject=FloatPlanWizard%20Media%20Inquiry";
</cfscript>

<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title><cfoutput>#encodeForHtml(pressTitle)#</cfoutput></title>
  <meta name="description" content="<cfoutput>#encodeForHtmlAttribute(pressDescription)#</cfoutput>">
  <link rel="canonical" href="<cfoutput>#pressCanonical#</cfoutput>">
  <meta property="og:type" content="website">
  <meta property="og:site_name" content="FloatPlanWizard">
  <meta property="og:url" content="<cfoutput>#pressCanonical#</cfoutput>">
  <meta property="og:title" content="<cfoutput>#encodeForHtmlAttribute(pressTitle)#</cfoutput>">
  <meta property="og:description" content="<cfoutput>#encodeForHtmlAttribute(pressDescription)#</cfoutput>">
  <meta property="og:image" content="<cfoutput>#pressSocialImage#</cfoutput>">
  <meta property="og:image:secure_url" content="<cfoutput>#pressSocialImage#</cfoutput>">
  <meta property="og:image:type" content="image/png">
  <meta property="og:image:width" content="1200">
  <meta property="og:image:height" content="630">
  <meta property="og:image:alt" content="FloatPlanWizard boating trip planning and monitored float plan preview image">
  <meta name="twitter:card" content="summary_large_image">
  <meta name="twitter:title" content="<cfoutput>#encodeForHtmlAttribute(pressTitle)#</cfoutput>">
  <meta name="twitter:description" content="<cfoutput>#encodeForHtmlAttribute(pressDescription)#</cfoutput>">
  <meta name="twitter:image" content="<cfoutput>#pressSocialImage#</cfoutput>">
  <meta name="twitter:image:alt" content="FloatPlanWizard boating trip planning and monitored float plan preview image">

  <cfinclude template="includes/header_styles.cfm">
  <link rel="stylesheet" href="<cfoutput>#request.fpwBase#</cfoutput>/assets/css/press.css?v=20260607-press-media">
</head>

<body class="fpw-press-body">
  <cfinclude template="includes/top_nav.cfm">

  <main class="fpw-press-main">
    <section class="fpw-press-hero" aria-labelledby="pressKitTitle">
      <p class="fpw-press-eyebrow">Press &amp; Media</p>
      <h1 id="pressKitTitle">FloatPlanWizard Press &amp; Media Kit</h1>
      <p>
        FloatPlanWizard.com is a boating trip-planning and float plan service built to help recreational boaters
        create monitored float plans, organize trip details, and share trip information with trusted contacts.
      </p>
      <p>
        FloatPlanWizard was created by Gulf Harbors resident, longtime boater, and web developer Larry Wald to
        promote safer recreational boating by making float plans easier, more accessible, and affordable.
      </p>

      <div class="fpw-press-actions" aria-label="Press kit actions">
        <a class="fpw-press-button fpw-press-button-primary" href="<cfoutput>#request.fpwBase#</cfoutput>/assets/press/floatplanwizard-media-kit.zip" download>Download Media Kit</a>
        <a class="fpw-press-button" href="<cfoutput>#request.fpwBase#</cfoutput>/press/floatplanwizard-launches.cfm">View Launch Press Release</a>
        <a class="fpw-press-button" href="<cfoutput>#pressContactMailto#</cfoutput>">Contact Founder</a>
      </div>
    </section>

    <div class="fpw-press-grid">
      <section class="fpw-press-card" aria-labelledby="shortDescriptionTitle">
        <h2 id="shortDescriptionTitle">Short Description</h2>
        <p>
          FloatPlanWizard helps recreational boaters create monitored float plans, plan boating trips, and share
          trip details with trusted contacts.
        </p>
      </section>

      <section class="fpw-press-card" aria-labelledby="includedTitle">
        <h2 id="includedTitle">What's Included in the Media Kit</h2>
        <ul class="fpw-press-list">
          <li>Launch press release PDF</li>
          <li>One-page fact sheet</li>
          <li>FPW logo files</li>
          <li>Product screenshots</li>
          <li>Media contact information</li>
        </ul>
      </section>

      <section class="fpw-press-card" aria-labelledby="whyBuiltTitle">
        <h2 id="whyBuiltTitle">Why FloatPlanWizard Was Built</h2>
        <p>
          FloatPlanWizard was built from a sincere belief that more recreational boaters should be using float plans.
          Many boaters head out for a simple day on the water, a fishing trip, a sandbar trip, or a longer cruise
          without leaving clear trip details with someone on shore. FloatPlanWizard was created to make that process
          easier.
        </p>
        <blockquote class="fpw-press-quote">
          &ldquo;Boating safety tools only help if people actually use them. I do not want cost to be the reason someone
          skips creating a float plan. FloatPlanWizard is built to give everyday boaters an easy way to plan a trip,
          share important details, and keep trusted contacts informed.&rdquo;
        </blockquote>
      </section>

      <section class="fpw-press-card" aria-labelledby="quickFactsTitle">
        <h2 id="quickFactsTitle">Quick Facts</h2>
        <div class="fpw-press-fact-grid">
          <div class="fpw-press-fact">
            <strong>Website</strong>
            <span>https://floatplanwizard.com</span>
          </div>
          <div class="fpw-press-fact">
            <strong>Founder</strong>
            <span>Larry Wald</span>
          </div>
          <div class="fpw-press-fact">
            <strong>Location</strong>
            <span>Gulf Harbors, Florida</span>
          </div>
          <div class="fpw-press-fact">
            <strong>Category</strong>
            <span>Boating safety, float plans, recreational boating trip planning</span>
          </div>
          <div class="fpw-press-fact">
            <strong>Audience</strong>
            <span>Recreational boaters</span>
          </div>
          <div class="fpw-press-fact">
            <strong>Mission</strong>
            <span>Promote safer recreational boating by making float plans easier, more accessible, and affordable</span>
          </div>
        </div>
      </section>

      <section class="fpw-press-card" aria-labelledby="storyAnglesTitle">
        <h2 id="storyAnglesTitle">Suggested Story Angles</h2>
        <ul class="fpw-press-list">
          <li>Gulf Harbors resident launches boating safety website</li>
          <li>Local boater builds low-cost float plan tool for recreational captains</li>
          <li>FloatPlanWizard helps boaters leave better trip details before leaving the dock</li>
          <li>New boating trip-planning service focuses on safer recreational boating habits</li>
          <li>Mobile-friendly float plans for everyday boaters</li>
        </ul>
      </section>

      <section class="fpw-press-notice fpw-press-safety" aria-labelledby="safetyNoticeTitle">
        <h2 id="safetyNoticeTitle">Safety Notice</h2>
        <p>
          FloatPlanWizard is not an emergency dispatch, rescue, or distress-response service. In an emergency,
          boaters should use official emergency channels such as VHF Channel 16, DSC distress, 911, EPIRB/PLB,
          flares, or other accepted emergency methods.
        </p>
      </section>

      <section class="fpw-press-contact-card" aria-labelledby="mediaContactTitle">
        <h2 id="mediaContactTitle">Media Contact</h2>
        <p>
          Larry Wald<br>
          Owner / Developer<br>
          FloatPlanWizard.com
        </p>
        <p>
          Email: <a href="<cfoutput>#pressContactMailto#</cfoutput>"><cfoutput>#encodeForHtml(pressContactEmail)#</cfoutput></a><br>
          Website: <a href="https://floatplanwizard.com">https://floatplanwizard.com</a>
        </p>
      </section>
    </div>
  </main>

  <cfinclude template="includes/footer.cfm">
</body>
</html>
