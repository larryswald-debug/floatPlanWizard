<cfprocessingdirective pageencoding="utf-8">
<cfsetting showdebugoutput="false" requesttimeout="30">
<cfcontent type="text/html; charset=utf-8">

<cfscript>
schemaAtKey = chr(64);
schemaTypeKey = schemaAtKey & "type";
schemaIdKey = schemaAtKey & "id";
schemaContextKey = schemaAtKey & "context";
schemaGraphKey = schemaAtKey & "graph";

function fpwAboutSchemaRef(required string idValue) output=false {
  var out = structNew("ordered");
  structInsert(out, schemaIdKey, arguments.idValue, true);
  return out;
}

fpwAboutCanonicalUrl = "https://floatplanwizard.com/about";
fpwAboutPageTitle = "About FloatPlanWizard | Built by a Solo Boater";
fpwAboutPageDescription = "Learn why solo boater and retired web developer Larry Wald created FloatPlanWizard to make trip planning, float-plan sharing, monitoring, and family communication easier.";
fpwAboutSocialImage = "https://floatplanwizard.com/assets/images/social/floatplanwizard-social-preview-20260730.png";
fpwAboutJsonLdText = "";
fpwAboutSchemaGraph = [];
fpwAboutSchemaPage = structNew("ordered");
fpwAboutSchemaOrganization = structNew("ordered");
fpwAboutSchemaFounder = structNew("ordered");
fpwAboutJsonLd = structNew("ordered");

structInsert(fpwAboutSchemaPage, schemaTypeKey, "AboutPage", true);
structInsert(fpwAboutSchemaPage, schemaIdKey, fpwAboutCanonicalUrl & "##webpage", true);
fpwAboutSchemaPage["url"] = fpwAboutCanonicalUrl;
fpwAboutSchemaPage["name"] = "About FloatPlanWizard";
fpwAboutSchemaPage["description"] = "The story behind FloatPlanWizard and why it was created for solo boaters, recreational captains, and their families.";
fpwAboutSchemaPage["isPartOf"] = fpwAboutSchemaRef("https://floatplanwizard.com/##website");
fpwAboutSchemaPage["about"] = fpwAboutSchemaRef("https://floatplanwizard.com/##organization");
fpwAboutSchemaPage["mainEntity"] = fpwAboutSchemaRef("https://floatplanwizard.com/##organization");
arrayAppend(fpwAboutSchemaGraph, fpwAboutSchemaPage);

structInsert(fpwAboutSchemaOrganization, schemaTypeKey, "Organization", true);
structInsert(fpwAboutSchemaOrganization, schemaIdKey, "https://floatplanwizard.com/##organization", true);
fpwAboutSchemaOrganization["name"] = "FloatPlanWizard";
fpwAboutSchemaOrganization["url"] = "https://floatplanwizard.com/";
fpwAboutSchemaOrganization["founder"] = fpwAboutSchemaRef(fpwAboutCanonicalUrl & "##larry-wald");
arrayAppend(fpwAboutSchemaGraph, fpwAboutSchemaOrganization);

structInsert(fpwAboutSchemaFounder, schemaTypeKey, "Person", true);
structInsert(fpwAboutSchemaFounder, schemaIdKey, fpwAboutCanonicalUrl & "##larry-wald", true);
fpwAboutSchemaFounder["name"] = "Larry Wald";
fpwAboutSchemaFounder["jobTitle"] = "Founder of FloatPlanWizard";
fpwAboutSchemaFounder["description"] = "A recreational solo boater and retired professional web developer with more than 30 years of website-development experience.";
fpwAboutSchemaFounder["worksFor"] = fpwAboutSchemaRef("https://floatplanwizard.com/##organization");
arrayAppend(fpwAboutSchemaGraph, fpwAboutSchemaFounder);

structInsert(fpwAboutJsonLd, schemaContextKey, "https://schema.org", true);
structInsert(fpwAboutJsonLd, schemaGraphKey, fpwAboutSchemaGraph, true);
fpwAboutJsonLdText = replace(serializeJSON(fpwAboutJsonLd), "</", "<\/", "all");

fpwAboutUserId = 0;
if (structKeyExists(session, "user") AND isStruct(session.user)) {
  if (structKeyExists(session.user, "userId") AND isNumeric(session.user.userId)) {
    fpwAboutUserId = val(session.user.userId);
  } else if (structKeyExists(session.user, "id") AND isNumeric(session.user.id)) {
    fpwAboutUserId = val(session.user.id);
  } else if (structKeyExists(session.user, "USERID") AND isNumeric(session.user.USERID)) {
    fpwAboutUserId = val(session.user.USERID);
  } else if (structKeyExists(session.user, "ID") AND isNumeric(session.user.ID)) {
    fpwAboutUserId = val(session.user.ID);
  }
}
fpwAboutIsLoggedIn = fpwAboutUserId GT 0;
</cfscript>

<cfinclude template="includes/fpw_base_path.cfm">
<cfset fpwAboutBasePath = request.fpwBase>
<cfset fpwAboutFinalCtaHref = fpwAboutBasePath & (fpwAboutIsLoggedIn ? "/app/dashboard.cfm" : "/app/join.cfm")>

<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title><cfoutput>#encodeForHtml(fpwAboutPageTitle)#</cfoutput></title>
  <meta name="description" content="<cfoutput>#encodeForHtmlAttribute(fpwAboutPageDescription)#</cfoutput>">
  <meta name="robots" content="index,follow">
  <link rel="canonical" href="https://floatplanwizard.com/about">

  <meta property="og:type" content="website">
  <meta property="og:site_name" content="FloatPlanWizard">
  <meta property="og:title" content="Why I Built FloatPlanWizard">
  <meta property="og:description" content="FloatPlanWizard began as a one-click way for a solo boater to send a saved float plan to his family.">
  <meta property="og:url" content="https://floatplanwizard.com/about">
  <meta property="og:image" content="<cfoutput>#fpwAboutSocialImage#</cfoutput>">
  <meta property="og:image:secure_url" content="<cfoutput>#fpwAboutSocialImage#</cfoutput>">
  <meta property="og:image:type" content="image/png">
  <meta property="og:image:width" content="1200">
  <meta property="og:image:height" content="630">
  <meta property="og:image:alt" content="FloatPlanWizard boating trip planning, float-plan sharing, and check-in preview">

  <meta name="twitter:card" content="summary_large_image">
  <meta name="twitter:title" content="Why I Built FloatPlanWizard">
  <meta name="twitter:description" content="The story of how a solo boater and retired web developer created FloatPlanWizard.">
  <meta name="twitter:image" content="<cfoutput>#fpwAboutSocialImage#</cfoutput>">
  <meta name="twitter:image:alt" content="FloatPlanWizard boating trip planning, float-plan sharing, and check-in preview">

  <script type="application/ld+json"><cfoutput>#fpwAboutJsonLdText#</cfoutput></script>

  <link rel="icon" type="image/svg+xml" href="<cfoutput>#fpwAboutBasePath#</cfoutput>/assets/images/landing/fpw-logo.svg">
  <link rel="stylesheet" href="<cfoutput>#fpwAboutBasePath#</cfoutput>/assets/css/fpw-conversion-landing.css?v=20260801-origin-story-v2">
  <link rel="stylesheet" href="<cfoutput>#fpwAboutBasePath#</cfoutput>/assets/css/top-nav.css?v=20260814-featured-guides-layout-v1">
  <link rel="stylesheet" href="<cfoutput>#fpwAboutBasePath#</cfoutput>/assets/css/about.css?v=20260801-about-page-v3">
</head>

<body id="top" class="fpw-about-page">
<cfinclude template="includes/prelaunch_top_nav.cfm">

<svg class="fpw-about-symbols" aria-hidden="true" focusable="false">
  <symbol id="fpw-about-i-route" viewBox="0 0 24 24"><path d="M5 18c2.5-6 5.5 1 9-4s4-6 5-8"/><circle cx="5" cy="18" r="2"/><circle cx="19" cy="6" r="2"/></symbol>
  <symbol id="fpw-about-i-pencil" viewBox="0 0 24 24"><path d="M4 20h4.5L19.2 9.3a2.1 2.1 0 0 0 0-3l-1.5-1.5a2.1 2.1 0 0 0-3 0L4 15.5V20Z"/><path d="m13.5 6 4.5 4.5M4 15.5 8.5 20"/></symbol>
  <symbol id="fpw-about-i-send" viewBox="0 0 24 24"><path d="m3 11 18-8-8 18-2.5-7.5L3 11Z"/><path d="m10.5 13.5 5-5"/></symbol>
  <symbol id="fpw-about-i-people" viewBox="0 0 24 24"><circle cx="9" cy="8" r="3"/><path d="M3.5 19c.5-4 2.4-6 5.5-6s5 2 5.5 6"/><circle cx="17" cy="9" r="2.5"/><path d="M15 14c3.5-.4 5.4 1.3 5.8 4.5"/></symbol>
  <symbol id="fpw-about-i-compass" viewBox="0 0 24 24"><circle cx="12" cy="12" r="9"/><path d="m15.5 8.5-2.2 4.8-4.8 2.2 2.2-4.8 4.8-2.2Z"/></symbol>
  <symbol id="fpw-about-i-file" viewBox="0 0 24 24"><path d="M6 3h8l4 4v14H6V3Z"/><path d="M14 3v5h5M9 12h6M9 16h6"/></symbol>
  <symbol id="fpw-about-i-radio" viewBox="0 0 24 24"><circle cx="12" cy="12" r="2"/><path d="M7.8 7.8a6 6 0 0 0 0 8.4M16.2 7.8a6 6 0 0 1 0 8.4M4.5 4.5a10.6 10.6 0 0 0 0 15M19.5 4.5a10.6 10.6 0 0 1 0 15"/></symbol>
  <symbol id="fpw-about-i-photo" viewBox="0 0 24 24"><rect x="3" y="5" width="18" height="14" rx="2"/><circle cx="9" cy="10" r="2"/><path d="m5 17 4.5-4 3 2.5 2.5-2 4 3.5"/></symbol>
  <symbol id="fpw-about-i-shield" viewBox="0 0 24 24"><path d="M12 3 20 6v6c0 5-3.4 8-8 9-4.6-1-8-4-8-9V6l8-3Z"/><path d="m8.5 12 2.3 2.3L15.8 9"/></symbol>
  <symbol id="fpw-about-i-anchor" viewBox="0 0 24 24"><circle cx="12" cy="5" r="2"/><path d="M12 7v13M8 10h8M4 15c0 3 3.6 5 8 5s8-2 8-5M4 15l3-2M20 15l-3-2"/></symbol>
  <symbol id="fpw-about-i-wheel" viewBox="0 0 24 24"><circle cx="12" cy="12" r="5"/><circle cx="12" cy="12" r="1.5"/><path d="M12 2v5M12 17v5M2 12h5M17 12h5M5 5l3.5 3.5M15.5 15.5 19 19M19 5l-3.5 3.5M8.5 15.5 5 19"/></symbol>
</svg>

<main class="fpw-about-main">
  <section class="fpw-about-hero" aria-labelledby="fpwAboutHeroTitle">
    <div class="fpw-about-container fpw-about-hero__inner">
      <div class="fpw-about-hero__copy">
        <p class="fpw-about-eyebrow">THE STORY BEHIND FLOATPLANWIZARD</p>
        <h1 id="fpwAboutHeroTitle">Built by a Solo Boater Who Needed a Better Way</h1>
        <p class="fpw-about-hero__intro">FloatPlanWizard began as a simple way to send my family a saved float plan whenever I headed out alone. Today, it helps boaters plan trips, share their journey, and keep the people waiting at home informed.</p>
        <div class="fpw-about-actions" aria-label="About FloatPlanWizard actions">
          <a class="fpw-btn fpw-btn-primary" href="<cfoutput>#fpwAboutBasePath#</cfoutput>/app/join.cfm">Create Your Free Account</a>
          <a class="fpw-btn fpw-btn-secondary" href="<cfoutput>#fpwAboutBasePath#</cfoutput>/how-it-works/">See How It Works</a>
        </div>
      </div>

      <aside class="fpw-about-route-card" aria-label="The original FloatPlanWizard routine">
        <div class="fpw-about-route-card__head">
          <span class="fpw-about-route-card__mark" aria-hidden="true"><svg class="fpw-about-icon"><use href="#fpw-about-i-route"></use></svg></span>
          <div><span>THE ORIGINAL IDEA</span><strong>A ready-to-send plan</strong></div>
        </div>
        <div class="fpw-about-route-line" aria-hidden="true"><span></span><span></span><span></span></div>
        <ol class="fpw-about-route-list">
          <li><span>1</span><div><strong>Save Plan</strong><small>Prepare it ahead of time</small></div></li>
          <li><span>2</span><div><strong>Send Plan</strong><small>Use one click before or after leaving</small></div></li>
          <li><span>3</span><div><strong>Family Informed</strong><small>Let the people at home know</small></div></li>
        </ol>
      </aside>
    </div>
  </section>

  <section class="fpw-about-section fpw-about-why" aria-labelledby="fpwAboutWhyTitle">
    <div class="fpw-about-container fpw-about-reading-grid">
      <div class="fpw-about-section-heading">
        <span class="fpw-about-section-mark" aria-hidden="true"><svg class="fpw-about-icon"><use href="#fpw-about-i-anchor"></use></svg></span>
        <p class="fpw-about-kicker">A PERSONAL NEED</p>
        <h2 id="fpwAboutWhyTitle">Why I Built FloatPlanWizard</h2>
      </div>
      <div class="fpw-about-prose">
        <p>FloatPlanWizard began with a simple personal need.</p>
        <p>I go boating alone most of the time, and I wanted an easy, dependable way to let my family know where I planned to go, when I expected to return, and what information they would need if something did not go according to plan.</p>
        <p>I did not want to recreate the same float plan every time I used the boat. I wanted to save my information once, prepare the trip ahead of time, and send the plan when I was ready to leave.</p>
        <p class="fpw-about-short-statement">So I built it.</p>
      </div>
    </div>
  </section>

  <section class="fpw-about-section fpw-about-original" aria-labelledby="fpwAboutOriginalTitle">
    <div class="fpw-about-container">
      <div class="fpw-about-centered-heading">
        <p class="fpw-about-kicker">THE FORGOTTEN-PLAN MOMENT</p>
        <h2 id="fpwAboutOriginalTitle">The Original FloatPlanWizard</h2>
      </div>
      <div class="fpw-about-original__story fpw-about-prose">
        <p>The first version was designed for one straightforward purpose.</p>
        <p>I could save a float plan online with my vessel, contact, route, and trip information. Whenever I took the boat out, all I had to do was click a button and the float plan was sent to my family.</p>
        <p>I cannot tell you how many times I had already left the dock and suddenly realized I had forgotten to send it.</p>
        <p>Instead of turning around, rebuilding the plan, or trying to remember every detail from the boat, I could open the website, click a link, and have the saved plan sent for me. Then I would send my family a quick text letting them know it was on the way.</p>
        <p>That simple process worked. My family had the information they needed, I did not have to recreate the plan at the dock, and I could keep moving knowing someone on shore understood where I intended to be.</p>
        <p class="fpw-about-emphasis">Save the plan. Send it with one click. Let your family know.</p>
      </div>

      <ol class="fpw-about-step-grid" aria-label="The original FloatPlanWizard three-step process">
        <li>
          <span class="fpw-about-step-number">1</span>
          <span class="fpw-about-card-icon" aria-hidden="true"><svg class="fpw-about-icon"><use href="#fpw-about-i-pencil"></use></svg></span>
          <h3>Save Your Plan</h3>
          <p>Prepare the route, boat, contacts, and timing ahead of time.</p>
        </li>
        <li>
          <span class="fpw-about-step-number">2</span>
          <span class="fpw-about-card-icon" aria-hidden="true"><svg class="fpw-about-icon"><use href="#fpw-about-i-send"></use></svg></span>
          <h3>Send Before Departure</h3>
          <p>Send the saved float plan when it is time to leave.</p>
        </li>
        <li>
          <span class="fpw-about-step-number">3</span>
          <span class="fpw-about-card-icon" aria-hidden="true"><svg class="fpw-about-icon"><use href="#fpw-about-i-people"></use></svg></span>
          <h3>Keep Family Informed</h3>
          <p>Let the people waiting ashore know where you plan to be.</p>
        </li>
      </ol>
    </div>
  </section>

  <section class="fpw-about-section fpw-about-experience" aria-labelledby="fpwAboutExperienceTitle">
    <div class="fpw-about-container fpw-about-experience__grid">
      <div class="fpw-about-prose">
        <p class="fpw-about-kicker">BOATING MEETS WEB DEVELOPMENT</p>
        <h2 id="fpwAboutExperienceTitle">Built From Real Experience</h2>
        <p>FloatPlanWizard brings together two major parts of my life: boating and professional web development.</p>
        <p>For more than 30 years, I worked directly on websites, applications, databases, integrations, and the everyday problems that come with building technology people actually depend on.</p>
        <p>I spent my career working in the trenches. I learned that successful websites are not defined by how many features they contain. They work because they solve a real problem, make sense to the person using them, and remove unnecessary steps.</p>
        <p>That experience shapes every part of FloatPlanWizard.</p>
        <p>I know what works. I know what creates confusion. I know how easily a useful idea can become buried beneath too much complexity.</p>
        <p>Now that I am retired, I can build the boating website I always wanted to use—one based on practical boating needs instead of corporate deadlines, committees, or short-term trends.</p>
        <p>FloatPlanWizard is built from the perspective of someone who has spent decades creating websites and who also personally uses the product on the water.</p>
      </div>

      <aside class="fpw-about-experience-card" aria-label="Experience behind FloatPlanWizard">
        <div class="fpw-about-experience-card__item">
          <svg class="fpw-about-icon" aria-hidden="true"><use href="#fpw-about-i-compass"></use></svg>
          <span>Real boating experience</span>
        </div>
        <div class="fpw-about-experience-card__join" aria-hidden="true"><span></span><strong>+</strong><span></span></div>
        <div class="fpw-about-experience-card__item">
          <svg class="fpw-about-icon" aria-hidden="true"><use href="#fpw-about-i-wheel"></use></svg>
          <span>More than 30 years building useful websites</span>
        </div>
        <div class="fpw-about-experience-card__result">
          <strong>FloatPlanWizard</strong>
          <span>Built around a real boating need</span>
        </div>
      </aside>
    </div>
  </section>

  <section class="fpw-about-section fpw-about-platform" aria-labelledby="fpwAboutPlatformTitle">
    <div class="fpw-about-container">
      <div class="fpw-about-centered-heading fpw-about-centered-heading--light">
        <p class="fpw-about-kicker">WHAT FPW HAS BECOME</p>
        <h2 id="fpwAboutPlatformTitle">More Than a Float Plan</h2>
        <p>FloatPlanWizard has grown beyond that original one-click system. It is now a boating trip-planning, float-plan, sharing, check-in, and monitoring platform designed to help captains organize their trips and keep the people who care about them informed.</p>
      </div>

      <div class="fpw-about-feature-grid">
        <article>
          <span class="fpw-about-card-icon" aria-hidden="true"><svg class="fpw-about-icon"><use href="#fpw-about-i-route"></use></svg></span>
          <h3>Plan Your Trip</h3>
          <p>Build and save routes, organize waypoints, record vessel and passenger information, and prepare the details before departure.</p>
        </article>
        <article>
          <span class="fpw-about-card-icon" aria-hidden="true"><svg class="fpw-about-icon"><use href="#fpw-about-i-file"></use></svg></span>
          <h3>Send Your Float Plan</h3>
          <p>Share the planned route, vessel information, passengers, operators, shore contacts, departure time, and expected return details.</p>
        </article>
        <article>
          <span class="fpw-about-card-icon" aria-hidden="true"><svg class="fpw-about-icon"><use href="#fpw-about-i-radio"></use></svg></span>
          <h3>Stay Connected</h3>
          <p>Use trip check-ins and float-plan monitoring to help the captain and shore contact stay aware of the trip’s progress.</p>
        </article>
        <article>
          <span class="fpw-about-card-icon" aria-hidden="true"><svg class="fpw-about-icon"><use href="#fpw-about-i-photo"></use></svg></span>
          <h3>Share the Journey</h3>
          <p>Give invited friends and family a way to view the trip, planned route, updates, photos, and shared activity.</p>
        </article>
      </div>
    </div>
  </section>

  <section class="fpw-about-section fpw-about-solo" aria-labelledby="fpwAboutSoloTitle">
    <div class="fpw-about-container fpw-about-solo__grid">
      <div class="fpw-about-solo__visual">
        <img class="fpw-about-solo__image" src="<cfoutput>#fpwAboutBasePath#</cfoutput>/assets/images/about/solo-boater-sunset.jpg" alt="Solo boater underway at sunset" width="800" height="800" loading="lazy" decoding="async">
      </div>
      <div class="fpw-about-prose">
        <p class="fpw-about-kicker">BUILT ESPECIALLY FOR SOLO BOATERS</p>
        <h2 id="fpwAboutSoloTitle">Especially Valuable for Solo Boaters</h2>
        <p>Solo boating offers a special kind of freedom, but it also creates a responsibility.</p>
        <p>When no one else is aboard, the people waiting at home may have very little information if plans change, the boat is delayed, or communication becomes difficult.</p>
        <p>FloatPlanWizard was originally built specifically for that situation.</p>
        <p>It helps solo boaters prepare their information before leaving, send it without rebuilding the plan each time, and give family or trusted contacts a clearer picture of the trip.</p>
        <p>It is also useful for couples, families, fishing trips, day cruises, overnight trips, and any captain who wants to plan more carefully and communicate more clearly.</p>
        <p class="fpw-about-emphasis">Especially valuable for solo boaters. Useful for every captain.</p>
      </div>
    </div>
  </section>

  <section class="fpw-about-section fpw-about-mission" aria-labelledby="fpwAboutMissionTitle">
    <div class="fpw-about-container">
      <div class="fpw-about-centered-heading fpw-about-centered-heading--light">
        <p class="fpw-about-kicker">WHAT GUIDES THE WORK</p>
        <h2 id="fpwAboutMissionTitle">Our Mission</h2>
        <p>Our mission is to make thoughtful boating trip planning and float-plan sharing easier for recreational boaters.</p>
      </div>

      <div class="fpw-about-principle-grid">
        <article><span>01</span><h3>Safety Before Complexity</h3><p>A planning tool should make preparation and communication easier—not create another complicated task before departure.</p></article>
        <article><span>02</span><h3>Useful Tools Should Be Accessible</h3><p>Planning, route organization, boating information, and trip preparation should be practical for everyday recreational boaters.</p></article>
        <article><span>03</span><h3>The Captain Remains in Control</h3><p>The captain decides what to plan, what to share, who receives the information, and when a trip begins or ends.</p></article>
        <article><span>04</span><h3>Families Should Not Be Left Guessing</h3><p>The people waiting ashore should have more than a vague description of where the boat may be going.</p></article>
        <article><span>05</span><h3>Useful Technology Should Feel Simple</h3><p>Good software should handle complicated work behind the scenes while remaining clear and practical for the person using it.</p></article>
      </div>
    </div>
  </section>

  <section class="fpw-about-section fpw-about-founder" aria-labelledby="fpwAboutFounderTitle">
    <div class="fpw-about-container fpw-about-founder__grid">
      <div class="fpw-about-prose">
        <p class="fpw-about-kicker">THE FOUNDER’S PERSPECTIVE</p>
        <h2 id="fpwAboutFounderTitle">A Tool That Came From Real Boating</h2>
        <p>FloatPlanWizard was not created from a theoretical business idea.</p>
        <p>It came from an actual routine I used whenever I took my own boat out alone. I needed a better way to prepare my plan, send it quickly, and reassure my family that they had the information they might need.</p>
        <p>Sometimes that meant sending it before departure. Sometimes it meant realizing after I had already left that I had forgotten, opening the website, and sending the saved plan with a single click.</p>
        <p>That real-life convenience is still at the heart of the product.</p>
        <p>After more than three decades of building websites professionally, I now have the freedom to apply everything I learned to a project I genuinely care about. I can build it thoughtfully, improve it based on real use, and focus on what actually helps boaters.</p>
        <p>The platform has grown, but its original purpose still guides it today:</p>
        <p class="fpw-about-emphasis">Help boaters prepare for the trip, stay connected on the water, and give the people waiting at home greater peace of mind.</p>
      </div>

      <aside class="fpw-about-founder-card" aria-label="FloatPlanWizard founder">
        <div class="fpw-about-founder-card__route" aria-hidden="true"><span></span><span></span><span></span></div>
        <img class="fpw-about-founder-card__portrait" src="<cfoutput>#fpwAboutBasePath#</cfoutput>/assets/images/about/larry-wald-founder.jpeg" alt="Larry Wald, founder of FloatPlanWizard" width="112" height="112" loading="lazy" decoding="async">
        <footer>
          <strong>Larry Wald</strong>
          <span>Founder, FloatPlanWizard</span>
          <span>Solo Boater and Retired Professional Web Developer</span>
        </footer>
      </aside>
    </div>
  </section>

  <section class="fpw-about-final" aria-labelledby="fpwAboutFinalTitle">
    <div class="fpw-about-container fpw-about-final__inner">
      <span class="fpw-about-final__icon" aria-hidden="true"><svg class="fpw-about-icon"><use href="#fpw-about-i-shield"></use></svg></span>
      <h2 id="fpwAboutFinalTitle">Plan Ahead Before You Leave the Dock</h2>
      <p>Whether you are boating alone, taking family for a day cruise, fishing, or preparing for a longer journey, FloatPlanWizard helps you organize the trip and keep trusted people informed.</p>
      <p class="fpw-about-final__emphasis">Your trip should not begin with your family wondering where you are going.</p>
      <a class="fpw-btn fpw-btn-primary" href="<cfoutput>#fpwAboutFinalCtaHref#</cfoutput>">Start Planning Your Next Trip</a>
    </div>
  </section>
</main>

<cfinclude template="includes/footer.cfm">
</body>
</html>
