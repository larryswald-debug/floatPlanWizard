<cfprocessingdirective pageencoding="utf-8">
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>FloatPlanWizard Help Center</title>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="description" content="Learn how to use FloatPlanWizard to plan a trip, send a float plan, monitor your cruise, share a Trip status page, and check marine weather.">
  <link rel="icon" href="data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 64 64'%3E%3Crect width='64' height='64' rx='14' fill='%2306131d'/%3E%3Cpath d='M32 10v44M10 32h44M17 17l30 30M47 17 17 47' stroke='%2321f3ee' stroke-width='5' stroke-linecap='round'/%3E%3Ccircle cx='32' cy='32' r='14' fill='none' stroke='%2367d8ff' stroke-width='5'/%3E%3Ccircle cx='32' cy='32' r='5' fill='%23ffd18a'/%3E%3C/svg%3E">

  <cfinclude template="../includes/fpw_base_path.cfm">
  <cfinclude template="../includes/header_styles.cfm">
  <link rel="stylesheet" href="<cfoutput>#request.fpwBase#</cfoutput>/assets/css/help.css?v=20260526-cache-bump">
</head>
<body class="fpw-help-body">

<cfinclude template="../includes/prelaunch_top_nav.cfm">

<main class="fpw-help" id="mainContent">
  <section class="fpw-help-hero" aria-labelledby="helpTitle">
    <div class="fpw-help-container fpw-help-hero__inner">
      <div class="fpw-help-hero__copy">
        <p class="fpw-help-kicker">FloatPlanWizard guide</p>
        <h1 id="helpTitle">FloatPlanWizard Help Center</h1>
        <p class="fpw-help-lede">Learn how to plan a trip, send a float plan, monitor your cruise, share your Trip status page, and check boating weather.</p>
      </div>

      <div class="fpw-help-search" role="search" aria-label="Search help topics">
        <label for="fpwHelpSearch">Search the manual</label>
        <div class="fpw-help-search__control">
          <input id="fpwHelpSearch" type="search" placeholder="Search check-ins, weather, Follow, Basic, Premium..." autocomplete="off" data-help-search>
          <button type="button" data-help-search-clear>Clear</button>
        </div>
        <p class="fpw-help-search__status" data-help-search-status>Search by topic, task, or boating situation.</p>
      </div>
    </div>
  </section>

  <div class="fpw-help-container fpw-help-shell">
    <aside class="fpw-help-toc" aria-label="Help table of contents">
      <div class="fpw-help-toc__panel">
        <p class="fpw-help-toc__title">Contents</p>
        <nav>
          <a href="#get-started" data-help-toc-link>Get Started</a>
          <a href="#first-trip-checklist" data-help-toc-link>First Trip Checklist</a>
          <a href="#dashboard" data-help-toc-link>Dashboard</a>
          <a href="#active-cruise" data-help-toc-link>Active Cruise</a>
          <a href="#check-ins" data-help-toc-link>Check-ins</a>
          <a href="#follow" data-help-toc-link>Follow</a>
          <a href="#monitor" data-help-toc-link>Monitor</a>
          <a href="#weather" data-help-toc-link>Weather</a>
          <a href="#faq" data-help-toc-link>Troubleshooting</a>
        </nav>
      </div>
    </aside>

    <div class="fpw-help-content">
      <div class="fpw-help-empty" data-help-empty hidden>No matching help topics found. Try a shorter search, such as "check-in", "weather", or "Follow".</div>

      <section class="fpw-help-section" id="get-started" data-help-section data-help-keywords="start account setup first trip basic premium safety emergency">
        <div class="fpw-help-card">
          <p class="fpw-help-section-label">Start here</p>
          <h2>Get Started</h2>
          <p>FloatPlanWizard helps recreational boaters prepare trip details, share a float plan, keep trip contacts informed, and review marine weather before and during a cruise.</p>
          <p>Start with the basics: create or sign in to your account, complete your boat and contact information, then choose the trip style that fits your outing.</p>

          <div class="fpw-help-grid">
            <article>
              <h3>Free Basic trips</h3>
              <p>Use a Basic Float Plan for a simple same-day trip. Basic trips are one-day plans without a saved route and include basic monitoring.</p>
            </article>
            <article>
              <h3>Premium route trips</h3>
              <p>Premium adds saved routes, Custom Route Generator, Active Cruise, Follow Page sharing, mobile check-ins, multi-day trips, and advanced monitoring.</p>
            </article>
          </div>

          <div class="fpw-help-callout fpw-help-callout-safety">
            <strong>Safety note</strong>
            <p>FloatPlanWizard is not a rescue, dispatch, or emergency response service. In an emergency, use official emergency channels first, including VHF Channel 16, DSC distress, 911, EPIRB/PLB, flares, or local emergency services.</p>
          </div>
        </div>
      </section>

      <section class="fpw-help-section" id="first-trip-checklist" data-help-section data-help-keywords="checklist first trip vessel operator contacts passengers review send">
        <div class="fpw-help-card">
          <p class="fpw-help-section-label">Practical setup</p>
          <h2>First Trip Checklist</h2>
          <ol class="fpw-help-steps">
            <li>Sign in or create your account.</li>
            <li>Add the boat, captain, operator, trip contact, and passenger details needed for your plan.</li>
            <li>Choose a Basic Float Plan for a simple same-day trip, or create a route if your membership includes route planning.</li>
            <li>Review the departure, destination, expected timing, contacts, and safety details before sending.</li>
            <li>Tell your contacts how you will communicate if your plan changes.</li>
            <li>Check current marine conditions before departure and keep using official weather sources.</li>
          </ol>

          <div class="fpw-help-callout fpw-help-callout-example">
            <strong>Example: same-day sandbar trip</strong>
            <p>For a short day trip, create a Basic Float Plan with your destination, timing, boat details, and notification contacts. Send it before you leave, then close it when the trip is finished.</p>
          </div>
        </div>
      </section>

      <section class="fpw-help-section" id="dashboard" data-help-section data-help-keywords="dashboard route workspace vessel operator contacts passengers basic float plan saved routes send review">
        <div class="fpw-help-card">
          <p class="fpw-help-section-label">Planning workspace</p>
          <h2>Dashboard</h2>
          <p>The Dashboard is your main planning workspace. It is where you manage trip setup, review current trip status, create a Basic Float Plan, and work with routes when your membership includes route tools.</p>

          <div class="fpw-help-grid">
            <article>
              <h3>Setup details</h3>
              <p>Keep your boat, operator, contacts, and passenger information current. These details help make your float plan useful to the people receiving it.</p>
            </article>
            <article>
              <h3>Routes and saved trips</h3>
              <p>Premium route tools let you create and reuse boating routes, review legs, and prepare Custom Route Generator.</p>
            </article>
            <article>
              <h3>Basic Float Plan</h3>
              <p>Basic members can create a one-day float plan for a simple trip without creating a saved route.</p>
            </article>
            <article>
              <h3>Before you send</h3>
              <p>Confirm your destination, timing, contacts, boat details, and safety information. Update anything that has changed before sending the plan.</p>
            </article>
          </div>

          <div class="fpw-help-callout fpw-help-callout-example">
            <strong>Example: Premium route-based trip</strong>
            <p>Create a route, review each leg, check the route details, then send the route-based float plan. Once the trip is active, use Active Cruise to follow the planned legs and submit check-ins.</p>
          </div>
        </div>
      </section>

      <section class="fpw-help-section" id="active-cruise" data-help-section data-help-keywords="active cruise premium route timeline leg fuel weather delay secure for night changed plan next leg">
        <div class="fpw-help-card">
          <p class="fpw-help-section-label">Underway tools</p>
          <h2>Active Cruise</h2>
          <p>Active Cruise is for Premium route-based trips after a float plan is active. It gives the captain a working view of the current leg, the cruise timeline, check-in actions, timing, fuel estimates, and weather context.</p>

          <div class="fpw-help-grid">
            <article>
              <h3>Active leg panel</h3>
              <p>Use the active leg area to see the current route segment, remaining distance, estimated arrival, adjusted speed, weather factor, and fuel estimates when available.</p>
            </article>
            <article>
              <h3>Cruise timeline</h3>
              <p>The timeline shows the route legs and lets you review selected leg details such as distance, timing, progress, status, and fuel estimates.</p>
            </article>
            <article>
              <h3>Weather checks</h3>
              <p>Use Check Conditions to review weather context while underway. Always compare FPW information with official marine forecasts and your own observations.</p>
            </article>
            <article>
              <h3>Next leg</h3>
              <p>When you are ready to move from one leg to the next, use the Active Cruise action that starts the next leg instead of treating the route as live vessel tracking.</p>
            </article>
          </div>

          <div class="fpw-help-callout fpw-help-callout-tip">
            <strong>Tip</strong>
            <p>Fuel values in Active Cruise are estimates for planning context. They depend on the route and fuel details you entered while planning.</p>
          </div>
        </div>
      </section>

      <section class="fpw-help-section" id="check-ins" data-help-section data-help-keywords="check-in on track delayed changed plan secure for the night overnight start next leg assistance">
        <div class="fpw-help-card">
          <p class="fpw-help-section-label">Trip updates</p>
          <h2>Check-ins</h2>
          <p>Check-ins let the captain update trip status during an active cruise. They help keep the trip record and monitoring view current.</p>

          <div class="fpw-help-status-list">
            <div><strong>On Track</strong><span>Use when the trip is proceeding as expected.</span></div>
            <div><strong>Delayed</strong><span>Use when you are still on the plan but running behind schedule.</span></div>
            <div><strong>Changed Plan</strong><span>Use when your route, stop, timing, or plan has changed and contacts should understand that context.</span></div>
            <div><strong>Secure for the Night</strong><span>Use when you are stopped for the night and plan to resume later.</span></div>
          </div>

          <div class="fpw-help-callout fpw-help-callout-example">
            <strong>Example: delayed 30 minutes</strong>
            <p>If weather, traffic, locks, fuel, or docking delays you, submit a Delayed check-in and include the reason. Your plan will be easier for contacts to understand.</p>
          </div>

          <div class="fpw-help-callout fpw-help-callout-example">
            <strong>Example: secure for the night</strong>
            <p>If you stop overnight, submit Secure for the Night so the trip is not treated like normal underway progress until you resume.</p>
          </div>

          <div class="fpw-help-callout fpw-help-callout-safety">
            <strong>Emergency reminder</strong>
            <p>Do not use a check-in as your first emergency call for help. Use official emergency channels first, then update FPW when it is safe to do so.</p>
          </div>
        </div>
      </section>

      <section class="fpw-help-section" id="follow" data-help-section data-help-keywords="trip status page share link family friends contacts public trip status progress privacy">
        <div class="fpw-help-card">
          <p class="fpw-help-section-label">Sharing progress</p>
          <h2>Follow</h2>
          <p>The Trip status page is a shareable trip page for family, friends, and trip contacts. It lets them see trip status, progress, timing, updates, and check-in information without signing in.</p>

          <div class="fpw-help-grid">
            <article>
              <h3>Who it is for</h3>
              <p>Share it with people who should be able to follow your trip status and understand recent updates.</p>
            </article>
            <article>
              <h3>What viewers can see</h3>
              <p>Viewers may see trip progress, timing, status, check-ins, shared posts, and location context when that information is available.</p>
            </article>
            <article>
              <h3>What viewers cannot do</h3>
              <p>Viewers cannot operate your boat, change your plan, submit captain check-ins, or replace official safety communication.</p>
            </article>
            <article>
              <h3>Privacy expectation</h3>
              <p>Treat the Follow link like a shareable trip page. Send it only to people you want viewing the trip.</p>
            </article>
          </div>

          <div class="fpw-help-callout fpw-help-callout-example">
            <strong>Example: sharing before departure</strong>
            <p>Send the Follow link to a family member before departure so they can see your trip status without logging in.</p>
          </div>

          <div class="fpw-help-callout fpw-help-callout-safety">
            <strong>Safety note</strong>
            <p>The Trip status page is informational. It is not an emergency dispatch service and may not reflect your current position.</p>
          </div>
        </div>
      </section>

      <section class="fpw-help-section" id="monitor" data-help-section data-help-keywords="monitor monitoring check-ins late missed escalated contacts notifications not live tracking gps">
        <div class="fpw-help-card">
          <p class="fpw-help-section-label">Monitoring</p>
          <h2>Monitor</h2>
          <p>Monitoring helps organize trip status around expected check-ins, recent updates, and the last GPS location shared with a check-in when available.</p>

          <div class="fpw-help-grid">
            <article>
              <h3>Expected check-ins</h3>
              <p>Use check-ins to keep your trip record current. If you are late or plans change, update the trip as soon as practical.</p>
            </article>
            <article>
              <h3>Late and missed updates</h3>
              <p>If an expected check-in is late or missed, FPW can show that status so the captain and contacts have clearer trip context.</p>
            </article>
            <article>
              <h3>Escalation language</h3>
              <p>Escalation means the missed-check-in state has moved into a more serious notification stage. It does not mean an official rescue has been started.</p>
            </article>
            <article>
              <h3>Location context</h3>
              <p>FPW may show the last GPS point shared with a check-in. It is not live vessel tracking.</p>
            </article>
          </div>

          <div class="fpw-help-callout fpw-help-callout-safety">
            <strong>Strong safety note</strong>
            <p>In an emergency, use official emergency channels first. FPW can provide trip context, but it is not a substitute for calling for help. Monitoring depends on accurate user inputs, connectivity, correct contact information, email delivery, and app availability.</p>
          </div>
        </div>
      </section>

      <section class="fpw-help-section" id="weather" data-help-section data-help-keywords="weather marine forecast conditions signed in login route weather factor noaa nws">
        <div class="fpw-help-card">
          <p class="fpw-help-section-label">Marine conditions</p>
          <h2>Weather</h2>
          <p>The Weather page is part of the signed-in FPW workspace. Sign in to use the marine weather tools, search by ZIP or coordinates, and review detailed boating conditions.</p>

          <div class="fpw-help-grid">
            <article>
              <h3>Weather briefing</h3>
              <p>Use the briefing to review marine conditions, forecast details, alerts, wind, waves, tide context, and practical planning notes when available.</p>
            </article>
            <article>
              <h3>Check Conditions</h3>
              <p>On route and Active Cruise screens, Check Conditions helps review weather context for planning and underway awareness.</p>
            </article>
            <article>
              <h3>Weather factor</h3>
              <p>When shown, the weather factor is planning context for trip timing. Treat it as an estimate, not a command to go or stay.</p>
            </article>
            <article>
              <h3>Use judgment</h3>
              <p>Compare FPW weather with official marine forecasts, local knowledge, radio updates, and current conditions before making go/no-go decisions.</p>
            </article>
          </div>

          <div class="fpw-help-callout fpw-help-callout-example">
            <strong>Example: before leaving</strong>
            <p>Before departure, sign in, check conditions for your route or boating area, then compare the result with local marine forecasts and what you observe at the dock.</p>
          </div>

          <div class="fpw-help-callout fpw-help-callout-safety">
            <strong>Weather safety</strong>
            <p>Weather data is informational. Do not rely only on FPW for boating safety decisions.</p>
          </div>
        </div>
      </section>

      <section class="fpw-help-section" id="faq" data-help-section data-help-keywords="troubleshooting faq active cruise follow contact email weather load plan changed forgot check in emergency help">
        <div class="fpw-help-card">
          <p class="fpw-help-section-label">Troubleshooting</p>
          <h2>FAQ</h2>
          <div class="fpw-help-faq">
            <details>
              <summary>I do not see Active Cruise.</summary>
              <p>Active Cruise is for Premium route-based trips. Make sure you are signed in, your membership includes Active Cruise, and your route-based float plan is active.</p>
            </details>
            <details>
              <summary>I do not see a Trip status page.</summary>
              <p>Follow Page sharing is a Premium feature for route-based trips. Open your Dashboard and use the Follow sharing action when it is available for your active trip.</p>
            </details>
            <details>
              <summary>My contact did not get an email.</summary>
              <p>Check that the contact address is correct, ask them to check spam or junk folders, and send the Follow link another way if needed.</p>
            </details>
            <details>
              <summary>My weather did not load.</summary>
              <p>Make sure you are signed in, have a working connection, and entered a valid ZIP or coordinate. If the page is slow, try again and keep using official weather sources.</p>
            </details>
            <details>
              <summary>My plan changed.</summary>
              <p>Update your trip status as soon as practical. If you are underway, use Changed Plan or another appropriate check-in so contacts understand what changed.</p>
            </details>
            <details>
              <summary>I forgot to check in.</summary>
              <p>Submit a check-in as soon as it is safe and practical. If contacts may be worried, also contact them directly using your normal communication method.</p>
            </details>
            <details>
              <summary>I need emergency help.</summary>
              <p>Use official emergency channels first: VHF Channel 16, DSC distress, 911, EPIRB/PLB, flares, or local emergency services. FPW is not a rescue, dispatch, or emergency response service.</p>
            </details>
          </div>
        </div>
      </section>
    </div>
  </div>
</main>

<cfinclude template="../includes/footer.cfm">
<cfinclude template="../includes/footer_scripts.cfm">
<script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/app/help.js?v=20260526-cache-bump"></script>

</body>
</html>
