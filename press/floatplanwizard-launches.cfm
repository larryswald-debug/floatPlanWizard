<cfprocessingdirective pageencoding="utf-8">
<cfsetting showdebugoutput="false" requesttimeout="30">
<cfcontent type="text/html; charset=utf-8">

<cfscript>
releaseTitle = "Solo Boater Builds FloatPlanWizard | Launch Press Release";
releaseHeading = "Solo Boater Builds FloatPlanWizard to Make Float Plans Easier and More Accessible to Recreational Boaters";
releaseDescription = "Solo boater Larry Wald built FloatPlanWizard with free membership, Basic float-plan sending, optional Premium trips, and free public boating resources.";
releaseCanonical = "https://floatplanwizard.com/press/floatplanwizard-launches.cfm";
releaseSocialImage = "https://floatplanwizard.com/assets/images/social/floatplanwizard-social-preview-20260602.png";
releasePublishedDate = "2026-06-07";
releaseModifiedDate = "2026-08-15";
pressContactEmail = "support@floatplanwizard.com";
pressContactMailto = "mailto:" & pressContactEmail & "?subject=FloatPlanWizard%20Media%20Inquiry";

releaseSchemaAtKey = chr(64);
releaseSchemaContextKey = releaseSchemaAtKey & "context";
releaseSchemaTypeKey = releaseSchemaAtKey & "type";
releaseSchema = structNew("ordered");
releaseSchemaAuthor = structNew("ordered");
releaseSchemaPublisher = structNew("ordered");

structInsert(releaseSchemaAuthor, releaseSchemaTypeKey, "Person", true);
releaseSchemaAuthor["name"] = "Larry Wald";
structInsert(releaseSchemaPublisher, releaseSchemaTypeKey, "Organization", true);
releaseSchemaPublisher["name"] = "FloatPlanWizard";
releaseSchemaPublisher["url"] = "https://floatplanwizard.com/";

structInsert(releaseSchema, releaseSchemaContextKey, "https://schema.org", true);
structInsert(releaseSchema, releaseSchemaTypeKey, "NewsArticle", true);
releaseSchema["headline"] = releaseHeading;
releaseSchema["description"] = releaseDescription;
releaseSchema["url"] = releaseCanonical;
releaseSchema["mainEntityOfPage"] = releaseCanonical;
releaseSchema["datePublished"] = releasePublishedDate;
releaseSchema["dateModified"] = releaseModifiedDate;
releaseSchema["image"] = releaseSocialImage;
releaseSchema["author"] = releaseSchemaAuthor;
releaseSchema["publisher"] = releaseSchemaPublisher;
releaseSchemaJson = replace(serializeJSON(releaseSchema), "</", "<\/", "all");
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
  <meta property="og:title" content="<cfoutput>#encodeForHtmlAttribute(releaseHeading)#</cfoutput>">
  <meta property="og:description" content="<cfoutput>#encodeForHtmlAttribute(releaseDescription)#</cfoutput>">
  <meta property="og:image" content="<cfoutput>#releaseSocialImage#</cfoutput>">
  <meta property="og:image:secure_url" content="<cfoutput>#releaseSocialImage#</cfoutput>">
  <meta property="og:image:type" content="image/png">
  <meta property="og:image:width" content="1200">
  <meta property="og:image:height" content="630">
  <meta property="og:image:alt" content="FloatPlanWizard boating trip planning and monitored float plan preview image">
  <meta property="article:published_time" content="<cfoutput>#releasePublishedDate#</cfoutput>">
  <meta property="article:modified_time" content="<cfoutput>#releaseModifiedDate#</cfoutput>">
  <meta name="twitter:card" content="summary_large_image">
  <meta name="twitter:title" content="<cfoutput>#encodeForHtmlAttribute(releaseHeading)#</cfoutput>">
  <meta name="twitter:description" content="<cfoutput>#encodeForHtmlAttribute(releaseDescription)#</cfoutput>">
  <meta name="twitter:image" content="<cfoutput>#releaseSocialImage#</cfoutput>">
  <meta name="twitter:image:alt" content="FloatPlanWizard boating trip planning and monitored float plan preview image">
  <script type="application/ld+json"><cfoutput>#releaseSchemaJson#</cfoutput></script>

  <cfinclude template="../includes/header_styles.cfm">
  <link rel="stylesheet" href="<cfoutput>#request.fpwBase#</cfoutput>/assets/css/press.css?v=20260815-membership-update">
</head>

<body class="fpw-press-body">
  <cfinclude template="../includes/top_nav.cfm">

  <main class="fpw-press-main fpw-press-release">
    <a class="fpw-press-back" href="<cfoutput>#request.fpwBase#</cfoutput>/press.cfm">Back to Press Kit</a>

    <section class="fpw-press-hero" aria-labelledby="releaseTitle">
      <p class="fpw-press-eyebrow">For Immediate Release - June 7, 2026 &bull; Updated August 15, 2026</p>
      <h1 id="releaseTitle"><cfoutput>#encodeForHtml(releaseHeading)#</cfoutput></h1>
      <p class="fpw-press-release-lede">
        A solo boater's personal safety need grew into a recreational-boating platform with free membership,
        optional Premium trips, and expanding public planning and safety resources.
      </p>

      <div class="fpw-press-actions" aria-label="Press release actions">
        <a class="fpw-press-button" href="<cfoutput>#request.fpwBase#</cfoutput>/assets/press/floatplanwizard-launch-press-release.pdf" download>Download PDF</a>
        <a class="fpw-press-button" href="<cfoutput>#request.fpwBase#</cfoutput>/assets/press/floatplanwizard-media-kit.zip" download>Download Media Kit</a>
        <a class="fpw-press-button fpw-press-button-primary" href="<cfoutput>#pressContactMailto#</cfoutput>">Contact Founder</a>
      </div>
    </section>

    <article class="fpw-press-release-shell fpw-press-article">
      <p class="fpw-press-meta">GULF HARBORS, Fla. - June 7, 2026 (updated August 15, 2026)</p>

      <p>
        FloatPlanWizard.com, a boating trip-planning and float-plan platform created by Gulf Harbors resident Larry
        Wald, launched to help recreational boaters prepare trips, send float plans, and share useful information
        with trusted contacts.
      </p>

      <p>
        Wald is a longtime recreational and solo boater with approximately 55 years on the water. He first built the
        concept because, when boating alone, he wanted a quick and practical way to tell his family or shore contact
        where he planned to go and provide useful information if he failed to return. FloatPlanWizard grew from that
        personal safety need into a broader recreational-boating planning and safety platform. Wald is also a retired
        professional web developer with approximately 30 years of professional web-development experience.
      </p>

      <section aria-labelledby="membershipModelTitle">
        <h2 id="membershipModelTitle">Free Membership with Optional Premium Trips</h2>
        <p>
          FloatPlanWizard is designed to remove cost as a barrier to basic float-plan use. Membership is free,
          including full trip planning and Basic float-plan sending, and every new member receives one complimentary
          complete Premium trip. Free members can save vessel, operator, passenger, shore-contact, waypoint, and trip
          information and maintain multiple Draft float plans.
        </p>
        <p>
          The complimentary trip is provided through one Premium Send Credit. After that credit is used, additional
          Premium trips can be purchased individually for $4.99 or obtained through
          Monthly or Annual Premium membership. Individual Premium trip access currently lasts up to 21 days.
          Premium trips add PDF and email delivery, Active Cruise, Premium monitoring, and private Trip/Follow access;
          route planning and Basic sending remain free.
        </p>
      </section>

      <section aria-labelledby="publicResourcesTitle">
        <h2 id="publicResourcesTitle">New Free Public Boating Resources</h2>
        <p>
          Since the original June launch, FloatPlanWizard has expanded its free public resources with a
          <a href="<cfoutput>#request.fpwBase#</cfoutput>/solo-boating-safety-guide/">Solo Boating Safety Guide</a>,
          a <a href="<cfoutput>#request.fpwBase#</cfoutput>/shore-contact-overdue-boater/">Shore Contact / Overdue Boater Guide</a>,
          a <a href="<cfoutput>#request.fpwBase#</cfoutput>/boat-fuel-calculator/">Boat Fuel Calculator</a>, and
          Great Loop planning libraries that include public
          <a href="<cfoutput>#request.fpwBase#</cfoutput>/great-loop/locks/">lock information</a>. These resources extend
          the platform's safety and trip-planning mission beyond registered members.
        </p>
      </section>

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
          FloatPlanWizard.com is a recreational-boating trip-planning and float-plan platform built by a solo boater.
          Free membership includes route planning, saved boating and trip information, multiple Draft float plans,
          and Basic float-plan sending. Optional Premium trips add operational, monitoring, delivery, and sharing
          features, while public guides and planning tools remain available without an account.
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
        <a class="fpw-press-button" href="<cfoutput>#request.fpwBase#</cfoutput>/assets/press/floatplanwizard-launch-press-release.pdf" download>Download PDF</a>
        <a class="fpw-press-button" href="<cfoutput>#request.fpwBase#</cfoutput>/assets/press/floatplanwizard-media-kit.zip" download>Download Media Kit</a>
        <a class="fpw-press-button fpw-press-button-primary" href="<cfoutput>#pressContactMailto#</cfoutput>">Contact Founder</a>
      </div>
    </article>
  </main>

  <cfinclude template="../includes/footer.cfm">
</body>
</html>
