<cfprocessingdirective pageencoding="utf-8">
<cfinclude template="../includes/fpw_base_path.cfm">
<cfheader name="Cache-Control" value="no-store">
<!--- Member prose mirrors docs/fpw-user-manual.md. Keep both versions in sync. --->
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="robots" content="noindex, nofollow">
  <meta name="description" content="The FloatPlanWizard member manual: boating information, route planning, Float Plans, check-ins, overnight timing and trip completion.">
  <title>FloatPlanWizard User Manual</title>
  <cfinclude template="../includes/header_styles.cfm">
  <link rel="stylesheet" href="<cfoutput>#request.fpwBase#</cfoutput>/assets/css/user-manual.css?v=20261004">
</head>
<body class="fpw-manual-body">
<a class="fpw-manual-skip" href="#manualMain">Skip to manual</a>
<cfset request.fpwTopNavActive = "help">
<cfinclude template="../includes/top_nav.cfm">
<main class="fpw-manual" id="manualMain">
  <header class="fpw-manual-hero">
    <p class="fpw-manual-eyebrow">FloatPlanWizard · Member guide</p>
    <h1>FloatPlanWizard User Manual</h1>
    <p>A practical guide to planning, sharing and managing your trip in the signed-in FloatPlanWizard website.</p>
<p><strong>Updated October 4, 2026.</strong> Start with Chapters 1–2 for your first trip, or use the contents to find a particular task. The instructions distinguish saving, sending, actual departure and final closure.</p>
<p>Use your actual boating information and verify locations, timing and equipment before relying on a plan. A progress estimate, map marker or submitted email is not proof of arrival or message receipt.</p>
    <div class="fpw-manual-actions">
      <a href="<cfoutput>#request.fpwBase#</cfoutput>/app/dashboard.cfm">Back to Dashboard</a>
      <a href="<cfoutput>#request.fpwBase#</cfoutput>/app/help.cfm">Help Center</a>
      <button type="button" data-manual-print hidden>Print / Save as PDF</button>
    </div>
    <p class="fpw-manual-print-note">Use your browser’s Print command to print or save the complete manual as a PDF.</p>
  </header>
  <div class="fpw-manual-search" role="search" aria-label="Search the member manual" hidden>
    <label for="manualSearch">Search this manual</label>
    <div class="fpw-manual-search-controls">
      <input id="manualSearch" type="search" maxlength="180" autocomplete="off" placeholder="Try secure night, fuel, or Basic Send…" data-manual-search>
      <button type="button" data-manual-clear>Clear</button>
    </div>
    <p data-manual-status aria-live="polite" role="status">All 27 chapters are shown.</p>
  </div>
  <div class="fpw-manual-layout">
    <aside class="fpw-manual-toc" id="manualContents">
      <nav aria-label="Manual contents"><h2>Contents</h2>
      <div class="fpw-manual-toc-group" data-manual-group><h3>Part I — Getting Started</h3><ol start="1"><li><a data-manual-toc href="#1-find-your-way-around-fpw">1. Find Your Way Around FPW</a></li><li><a data-manual-toc href="#2-complete-your-first-time-setup">2. Complete Your First-Time Setup</a></li></ol></div>
<div class="fpw-manual-toc-group" data-manual-group><h3>Part II — Set Up Your Boating Information</h3><ol start="3"><li><a data-manual-toc href="#3-add-and-maintain-your-vessels">3. Add and Maintain Your Vessels</a></li><li><a data-manual-toc href="#4-save-operators-and-captains">4. Save Operators and Captains</a></li><li><a data-manual-toc href="#5-save-passengers-and-crew">5. Save Passengers and Crew</a></li><li><a data-manual-toc href="#6-choose-and-maintain-shore-contacts">6. Choose and Maintain Shore Contacts</a></li><li><a data-manual-toc href="#7-create-and-reuse-waypoints">7. Create and Reuse Waypoints</a></li></ol></div>
<div class="fpw-manual-toc-group" data-manual-group><h3>Part III — Plan Your Trip</h3><ol start="8"><li><a data-manual-toc href="#8-create-save-and-reopen-a-route">8. Create, Save and Reopen a Route</a></li><li><a data-manual-toc href="#9-choose-your-vessel-and-planning-assumptions">9. Choose Your Vessel and Planning Assumptions</a></li><li><a data-manual-toc href="#10-use-great-loop-planning-references">10. Use Great Loop Planning References</a></li></ol></div>
<div class="fpw-manual-toc-group" data-manual-group><h3>Part IV — Build and Refine Your Route</h3><ol start="11"><li><a data-manual-toc href="#11-adjust-a-legs-path-and-distance">11. Adjust a Leg’s Path and Distance</a></li><li><a data-manual-toc href="#12-understand-the-cruise-timeline-time-and-fuel-estimates">12. Understand the Cruise Timeline, Time and Fuel Estimates</a></li><li><a data-manual-toc href="#13-use-weather-in-planning-and-underway">13. Use Weather in Planning and Underway</a></li><li><a data-manual-toc href="#14-use-the-linked-fuel-and-range-calculator">14. Use the Linked Fuel and Range Calculator</a></li></ol></div>
<div class="fpw-manual-toc-group" data-manual-group><h3>Part V — Create and Send Your Float Plan</h3><ol start="15"><li><a data-manual-toc href="#15-complete-the-six-step-float-plan-wizard">15. Complete the Six-Step Float Plan Wizard</a></li><li><a data-manual-toc href="#16-review-and-send-basic-premium-and-credits">16. Review and Send: Basic, Premium and Credits</a></li><li><a data-manual-toc href="#17-share-your-trip-and-post-voyage-updates">17. Share Your Trip and Post Voyage Updates</a></li></ol></div>
<div class="fpw-manual-toc-group" data-manual-group><h3>Part VI — Use FPW While Underway</h3><ol start="18"><li><a data-manual-toc href="#18-read-active-cruise">18. Read Active Cruise</a></li><li><a data-manual-toc href="#19-check-in-and-understand-monitoring">19. Check In and Understand Monitoring</a></li><li><a data-manual-toc href="#20-handle-delays-overnight-stops-and-multiple-legs">20. Handle Delays, Overnight Stops and Multiple Legs</a></li><li><a data-manual-toc href="#21-keep-captain-notes-and-reach-your-contacts">21. Keep Captain Notes and Reach Your Contacts</a></li></ol></div>
<div class="fpw-manual-toc-group" data-manual-group><h3>Part VII — Finish and Review Your Trip</h3><ol start="22"><li><a data-manual-toc href="#22-complete-or-cancel-your-trip">22. Complete or Cancel Your Trip</a></li><li><a data-manual-toc href="#23-view-the-completed-trip-record">23. View the Completed Trip Record</a></li></ol></div>
<div class="fpw-manual-toc-group" data-manual-group><h3>Part VIII — Account and Reference</h3><ol start="24"><li><a data-manual-toc href="#24-manage-your-profile-home-port-password-and-membership">24. Manage Your Profile, Home Port, Password and Membership</a></li><li><a data-manual-toc href="#25-use-help-and-fpw-on-smaller-screens">25. Use Help and FPW on Smaller Screens</a></li></ol></div>
<div class="fpw-manual-toc-group" data-manual-group><h3>Part IX — Common Scenarios and Troubleshooting</h3><ol start="26"><li><a data-manual-toc href="#26-worked-boating-scenarios">26. Worked Boating Scenarios</a></li><li><a data-manual-toc href="#27-troubleshooting-and-status-reference">27. Troubleshooting and Status Reference</a></li></ol></div>
      </nav>
    </aside>
    <div class="fpw-manual-reading">
      <p class="fpw-manual-empty" data-manual-empty hidden>No matching chapters. Try a shorter phrase or choose Clear to show the complete manual.</p>
      <section class="fpw-manual-chapter" data-manual-chapter id="1-find-your-way-around-fpw" aria-labelledby="chapter-title-1"><p class="fpw-manual-part">Part I — Getting Started</p><h2 id="chapter-title-1">1. Find Your Way Around FPW</h2><div class="fpw-manual-chapter-body">
<p>FloatPlanWizard helps you keep boating information together, build a route, prepare a Float Plan, share your plans with people ashore, and report your progress during an active trip.</p>
<p>Start at <strong>Dashboard</strong>. The member navigation also opens <strong>Active Cruise</strong>, <strong>Monitor</strong>, <strong>Weather</strong>, <strong>Fuel Calculator</strong>, and <strong>My Account</strong>. On a smaller screen, open the menu to see the navigation.</p>
<h3>What each workspace is for</h3>
<div class="fpw-manual-table" role="region" aria-label="Reference table" tabindex="0"><table><thead><tr><th scope="col">Workspace</th><th scope="col">Use it to</th></tr></thead><tbody><tr><td>Dashboard</td><td>Prepare boating information, work with saved routes, and open your Float Plan</td></tr><tr><td>Routes / Float Plans</td><td>Find the route workspace on Dashboard; these labels do not open two independent planning systems</td></tr><tr><td>FPW Route Generator</td><td>Assemble waypoint legs, adjust route geometry, and review time and fuel estimates</td></tr><tr><td>Float Plan Wizard</td><td>Add the people, schedule, safety details and contact selections for one route</td></tr><tr><td>Active Cruise</td><td>Check in and manage the active trip</td></tr><tr><td>Monitor</td><td>Read monitoring state, the next expected check-in, and available location history</td></tr><tr><td>Weather</td><td>Review a location's marine briefing</td></tr><tr><td>My Account</td><td>Maintain your profile, home port, password and membership</td></tr></tbody></table></div>
<p><strong>Trip Planner</strong>, <strong>Routes</strong>, and <strong>FPW Route Generator</strong> refer to connected planning work. You do not need to create the same trip in three separate editors.</p>
<p>Dashboard actions depend on the route's state. A saved route may offer <strong>Activate Route</strong>. A draft may offer <strong>Complete Float Plan</strong>. An active trip offers <strong>Open Active Cruise</strong>, with sharing and other actions when available.</p>
<p>Use <strong>Help</strong> for the shorter Help Center and this manual for complete procedures. Dashboard <strong>Tour</strong> and the generator's <strong>Guided Tour</strong> can show you the main controls.</p>
<h3>Keep these steps separate</h3>
<p><strong>Save Route</strong> saves planning work. <strong>Save Float Plan</strong> saves the details you will share. <strong>Premium Save &amp; Send</strong> sends and activates an eligible route-backed trip. <strong>On Track</strong> records actual departure when the trip has not started. <strong>Close Float Plan</strong> ends a completed trip.</p>
<p>FPW is not an emergency dispatch or rescue service. Use official emergency channels when emergency help is needed; do not wait for a check-in, email or web page to summon help.</p>
</div><a class="fpw-manual-back" href="#manualContents">Back to contents</a></section>
<section class="fpw-manual-chapter" data-manual-chapter id="2-complete-your-first-time-setup" aria-labelledby="chapter-title-2"><h2 id="chapter-title-2">2. Complete Your First-Time Setup</h2><div class="fpw-manual-chapter-body">
<p>Before building your first route, prepare your vessel, an operator, a shore contact, and at least two saved waypoints with usable coordinates. Passengers are optional for a solo outing.</p>
<ol><li>Open <strong>Dashboard</strong> and find <strong>Getting Started</strong>.</li><li>Choose <strong>Add your vessel</strong> and save your boat's details.</li><li>Choose <strong>Add a shore contact</strong> and save the person's name, phone and email.</li><li>Choose <strong>Add an operator</strong> and save the person responsible for operating the boat.</li><li>Choose <strong>Add waypoints</strong>. Save a starting location and a destination; add intermediate stops if needed.</li><li>Review <strong>Trip Setup Readiness</strong>. Follow <strong>Continue Setup</strong> for anything still missing.</li><li>Use <strong>Create My Route</strong> or <strong>+ Create Route</strong> when you are ready to plan.</li></ol>
<p>The <strong>Getting Started</strong> switch controls that setup panel. <strong>View Welcome</strong>, <strong>Explore the Dashboard</strong>, <strong>Show Me Around</strong>, and <strong>Tour</strong> offer introductory help. Hiding the panel does not delete your saved information.</p>
<h3>Set a home port and account name</h3>
<p>Open <strong>My Account</strong> to save your name and <strong>Home Port</strong>. The account name identifies the sender of your Float Plan; it does not replace the operator selected for a particular trip. Home Port helps with map and weather defaults. It is separate from a vessel's Hailing Port.</p>
<h3>Manage saved information</h3>
<p>Dashboard's <strong>Boat &amp; Trip Setup / Manage Saved Items</strong> groups your <strong>Saved Vessels</strong>, <strong>Trip Contacts</strong>, <strong>Passengers &amp; Crew</strong>, <strong>Operators</strong>, and <strong>Waypoints</strong>. Use the relevant <strong>+ Add</strong> action, or the Dashboard shortcut.</p>
<p>Choose <strong>Edit</strong> for an existing record, make the change, and save it. Choose <strong>Delete</strong> only when the record is no longer needed, then read the confirmation. A record used by a Float Plan can be protected from deletion. Follow the displayed list of references and remove those associations where editing is allowed; do not repeatedly retry deletion.</p>
<p>Saving these records prepares reusable information. It does not create a route, send a Float Plan, or notify a contact.</p>
</div><a class="fpw-manual-back" href="#manualContents">Back to contents</a></section>
<section class="fpw-manual-chapter" data-manual-chapter id="3-add-and-maintain-your-vessels" aria-labelledby="chapter-title-3"><p class="fpw-manual-part">Part II — Set Up Your Boating Information</p><h2 id="chapter-title-3">3. Add and Maintain Your Vessels</h2><div class="fpw-manual-chapter-body">
<p>Save a separate vessel record for each boat you use. You can choose the appropriate boat when planning a route and completing a Float Plan.</p>
<h3>Add a vessel</h3>
<ol><li>From Dashboard, choose <strong>Vessels → + Add</strong>, <strong>Add Vessel</strong>, or the setup prompt.</li><li>Enter the required <strong>Vessel Name</strong>, <strong>Type</strong>, <strong>Length</strong>, and <strong>Hull Color</strong>.</li><li>Complete the identification, communications, propulsion and safety information relevant to that boat.</li><li>Select <strong>Default Vessel</strong> if this should be your usual boat for route calculations.</li><li>Choose <strong>Save Vessel</strong> and wait for the saved record to appear in the list.</li></ol>
<p>Only one vessel is the default. Choosing a new default removes that designation from the previous boat; it does not delete either vessel.</p>
<h3>Vessel information to maintain</h3>
<div class="fpw-manual-table" role="region" aria-label="Reference table" tabindex="0"><table><thead><tr><th scope="col">Group</th><th scope="col">Fields</th></tr></thead><tbody><tr><td>Basic description</td><td>Vessel Name, Type, Length, Hull Color, Registration, Hailing Port, Make, Model</td></tr><tr><td>Identification</td><td>HIN, Year Built, Draft, Hull Material, Prominent Features</td></tr><tr><td>Communications</td><td>Radio Call Sign, MMSI, primary and secondary radio types, channels/frequencies monitored, Vessel/Onboard Mobile Phone, Satellite Phone</td></tr><tr><td>Primary propulsion</td><td>Propulsion details/type, Number of Engines, Primary Fuel Capacity</td></tr><tr><td>Auxiliary propulsion</td><td>Auxiliary details/type, Number of Engines, Auxiliary Fuel Capacity</td></tr><tr><td>Planning performance</td><td>Max Speed, Most Efficient speed, GPH at efficient speed, GPH at maximum speed, Total Fuel Capacity</td></tr><tr><td>Navigation equipment</td><td>Compass, Radar, GPS/DGPS, Depth Sounder, Charts, Maps, Other Navigation Equipment</td></tr><tr><td>Visual distress equipment</td><td>Electric Distress Light, Flag, Aerial Flare, Handheld Flare, Signal Mirror, Smoke</td></tr><tr><td>Audible equipment</td><td>Bell, Horn, Whistle</td></tr><tr><td>Additional safety equipment</td><td>EPIRB UIN, anchor aboard, anchor line/rode length, dewatering device, exposure suits, fire extinguisher, flashlight/searchlight, raft/dinghy</td></tr><tr><td>Other equipment</td><td>Other Equipment 1–4</td></tr></tbody></table></div>
<p>Select the available hull-material, radio and propulsion choices that match your boat. Do not select equipment merely because it appears in the form. Keep the information accurate for the vessel and supplies you will actually take.</p>
<p>The onboard mobile number belongs to this boat's record. Editing it does not change the phone number in My Account.</p>
<h3>Photo</h3>
<p>Add a JPG, PNG or WebP vessel image up to <strong>5 MB</strong>. Use <strong>Remove image</strong> to remove it. Choose a photo you are comfortable including in shareable vessel information. Confirm both the saved record and the image result if an upload error appears.</p>
<h3>Performance numbers and units</h3>
<p><strong>Current unit caution:</strong> the vessel form labels Max Speed and Most Efficient speed as <strong>KPH</strong>, while the Route Generator asks for <strong>knots (kn)</strong>. Do not assume a saved speed has been converted when it appears in the planner. Before using an estimate, verify the planner's speed values in knots. If you cannot verify them, do not rely on the resulting time or fuel estimate.</p>
<p>Fuel-burn fields use gallons per hour. Capacity fields use gallons. Use the units shown beside each field and correct invalid or negative values when the form asks you to.</p>
<h3>Edit or delete</h3>
<p>Choose <strong>Edit</strong> on the vessel, update its fields and choose <strong>Save Vessel</strong>. Recheck route assumptions after changing or selecting a vessel; a saved route should not be assumed to have adopted every later profile change.</p>
<p>Choose <strong>Delete</strong> and read the confirmation to remove an unused vessel. If a Float Plan references it, the application can block deletion and explain which plan needs attention.</p>
</div><a class="fpw-manual-back" href="#manualContents">Back to contents</a></section>
<section class="fpw-manual-chapter" data-manual-chapter id="4-save-operators-and-captains" aria-labelledby="chapter-title-4"><h2 id="chapter-title-4">4. Save Operators and Captains</h2><div class="fpw-manual-chapter-body">
<p>An <strong>Operator</strong> is a reusable person you can select for a Float Plan. Your account's sender name and the trip's operator can be different people.</p>
<ol><li>Open Dashboard <strong>Operators</strong> and choose <strong>+ Add</strong>, or use <strong>Add Operator</strong>.</li><li>Enter <strong>Name</strong>.</li><li>Add <strong>Phone</strong> and <strong>Notes</strong> if useful. A supplied phone number must pass the form's US-phone validation.</li><li>Choose <strong>Save Operator</strong>.</li><li>In the Float Plan Wizard's <strong>Basics</strong> step, select the operator for that trip.</li></ol>
<p>Save more than one operator when different people operate your boat. The primary Wizard selects one operator for the plan; it does not turn every saved operator into trip crew.</p>
<p>Use <strong>Edit</strong> to maintain a person's details. Use <strong>Delete</strong> for an unused record and follow any reference warning. There is no separate reusable Captain database that you must fill in as well.</p>
<p>The Wizard's <strong>Operator has PFD</strong> checkbox belongs to the trip review. Confirm it accurately rather than treating a saved operator record as proof of equipment aboard.</p>
</div><a class="fpw-manual-back" href="#manualContents">Back to contents</a></section>
<section class="fpw-manual-chapter" data-manual-chapter id="5-save-passengers-and-crew" aria-labelledby="chapter-title-5"><h2 id="chapter-title-5">5. Save Passengers and Crew</h2><div class="fpw-manual-chapter-body">
<p>Use <strong>Passengers &amp; Crew</strong> to maintain people you may take aboard. The saved-person form does not have separate passenger and crew roles.</p>
<ol><li>Open Dashboard <strong>Crew</strong> or <strong>Passengers &amp; Crew → + Add</strong>.</li><li>Enter <strong>Name</strong>.</li><li>Add <strong>Phone</strong>, <strong>Age</strong>, <strong>Gender</strong>, and <strong>Notes</strong> as appropriate.</li><li>Choose <strong>Save Passenger</strong>.</li><li>In the Wizard's <strong>Passengers, Crew &amp; Contacts</strong> step, open <strong>Passengers</strong> and select the people actually on this trip.</li></ol>
<p>Use the search box to find a saved person. Review the selected count and <strong>On This Trip</strong> summary; having someone in your saved list does not automatically put them on every Float Plan.</p>
<p>A solo trip can have no passengers selected. Select the operator separately in Basics.</p>
<p>Use <strong>Edit</strong> to update a saved person and <strong>Delete</strong> to remove an unused record. Removing a selection from one editable trip is different from deleting the reusable person. A reference warning may prevent deletion while a Float Plan still uses the record.</p>
</div><a class="fpw-manual-back" href="#manualContents">Back to contents</a></section>
<section class="fpw-manual-chapter" data-manual-chapter id="6-choose-and-maintain-shore-contacts" aria-labelledby="chapter-title-6"><h2 id="chapter-title-6">6. Choose and Maintain Shore Contacts</h2><div class="fpw-manual-chapter-body">
<p>A shore contact is someone you have agreed will receive your trip information and know what to do if you do not return or check in as expected.</p>
<h3>Save a contact</h3>
<ol><li>Open Dashboard <strong>Contacts / Trip Contacts</strong> and choose <strong>+ Add</strong>, or use <strong>Add Contact</strong>.</li><li>Enter <strong>Name</strong>, <strong>Phone</strong>, and <strong>Email</strong>. All three are required.</li><li>Check the email carefully and use a phone number that passes the form's US-phone validation.</li><li>Choose <strong>Save Contact</strong>.</li></ol>
<p>The form does not ask you to assign contact types such as shore, emergency or notification. Use your trip selections and the actual send confirmation to see who will receive a particular message.</p>
<h3>Select contacts for a trip</h3>
<p>In <strong>Passengers, Crew &amp; Contacts</strong> in the Wizard, open <strong>Contacts</strong>, search if needed, and select the people for this Float Plan. At least one contact is required. Review the selected count and names before sending.</p>
<p><strong>Basic Save &amp; Send</strong> in the Dashboard Wizard sends a PDF to one chosen saved contact. <strong>Premium Save &amp; Send</strong> uses the selected trip contacts with email addresses. Other notifications have their own recipient rules; a routine check-in is not a promise that everyone receives an email.</p>
<p>Talk with your contact before leaving. Explain the route, timing, normal communication method and your agreed response plan. Ask them to confirm that they can open the PDF and, when you share one separately, the Follow Link. FPW does not confirm that an email was delivered or read.</p>
<h3>Keep contacts current</h3>
<p>Use <strong>Edit</strong> to correct phone or email details. For an editable trip, review its selections and latest saved PDF before sending. Use <strong>Delete</strong> for an unused saved contact; if a Float Plan still references it, follow the application warning.</p>
<p>The <strong>Call</strong>, <strong>Text</strong> and <strong>Email</strong> shortcuts in Active Cruise open the device's communication handler when available. They do not replace confirmation that your contact received a message.</p>
</div><a class="fpw-manual-back" href="#manualContents">Back to contents</a></section>
<section class="fpw-manual-chapter" data-manual-chapter id="7-create-and-reuse-waypoints" aria-labelledby="chapter-title-7"><h2 id="chapter-title-7">7. Create and Reuse Waypoints</h2><div class="fpw-manual-chapter-body">
<p>A waypoint is a saved location. A route uses waypoints as its start, destination and intermediate leg endpoints.</p>
<h3>Save a location</h3>
<ol><li>Open Dashboard <strong>Waypoints → + Add</strong>, or choose <strong>Add Waypoint</strong>.</li><li>Click or tap the map to place the marker, or enter <strong>Latitude</strong> and <strong>Longitude</strong>.</li><li>Drag the marker if you need to adjust the location. Check the resulting coordinates.</li><li>Enter a recognizable <strong>Name</strong> of up to 45 characters. An automatically suggested name can be replaced.</li><li>Add <strong>Notes</strong> if useful, then choose <strong>Save Waypoint</strong>.</li></ol>
<p>Use decimal latitude and longitude in the coordinate fields. Confirm the marker is at your intended location before saving. A named waypoint without usable coordinates may be listed as <strong>[no coords]</strong> when building a route.</p>
<p>Save at least a starting point and a different destination for your first route. Add intermediate waypoints where you want separate legs or stops. The route builder uses the selected endpoints in order; saving a waypoint alone does not insert it into a trip.</p>
<h3>Map context and editing</h3>
<p>Use available NOAA chart and radar layers for context. Chart detail depends on zoom; radar availability depends on coverage. A marker or displayed chart layer is not a verified route between points.</p>
<p>Choose <strong>Edit</strong> to update a saved waypoint. Review existing routes separately after changing an endpoint; do not assume all saved geometry has moved to match a later waypoint edit.</p>
<p>Choose <strong>Delete</strong> for an unused waypoint and read any reference warning.</p>
<h3>Reuse a Great Loop port</h3>
<p>Open a port's detail page and choose <strong>Add to My Waypoints</strong> when signed in and valid coordinates are available. The saved record uses the port's location and source notes. Then choose it as an endpoint in <strong>My Routes &amp; Waypoint Builder</strong>.</p>
<p>Adding a port does not automatically add a leg. Check your saved waypoint list before adding it again on another visit.</p>
</div><a class="fpw-manual-back" href="#manualContents">Back to contents</a></section>
<section class="fpw-manual-chapter" data-manual-chapter id="8-create-save-and-reopen-a-route" aria-labelledby="chapter-title-8"><p class="fpw-manual-part">Part III — Plan Your Trip</p><h2 id="chapter-title-8">8. Create, Save and Reopen a Route</h2><div class="fpw-manual-chapter-body">
<p>A route describes where you intend to travel. Build it from saved waypoints, review its path and estimates, and save it before preparing the Float Plan.</p>
<p>Start with the waypoints you need: your departure point, intermediate stops, and destination. Give each waypoint a recognizable name and check its coordinates. A waypoint marked <strong>[no coords]</strong> needs attention before it can provide a useful distance estimate.</p>
<h3>Build your route</h3>
<ol><li>Open <strong>Dashboard → Routes → + Create Route</strong>. The <strong>FPW Route Generator</strong> opens. <strong>Generate Route</strong> opens the same planner.</li><li>Enter a recognizable <strong>Route Name</strong>.</li><li>Under <strong>My Routes &amp; Waypoint Builder</strong>, check the name in <strong>Create Route</strong>, then select <strong>Create</strong>. To continue an existing waypoint route, choose it under <strong>My Routes</strong> instead.</li><li>Choose <strong>Route Start Waypoint</strong>, then select <strong>Set Start</strong>.</li><li>Under <strong>Add Leg by Waypoint</strong>, choose the next stop and select <strong>Add Leg</strong>.</li><li>Repeat for each remaining stop. Each new leg begins where the previous leg ends.</li><li>Select <strong>Load</strong>.</li><li>Review the vessel, planning assumptions, leg paths, summary cards, and <strong>Cruise Timeline</strong>.</li><li>Select <strong>Save Route</strong> and wait for the success message.</li></ol>
<p>The saved route is available in your Dashboard Routes list. Creating or saving it does not send a Float Plan or begin monitoring.</p>
<p>For guided help, select <strong>Guided Tour</strong> at the top of the planner. Use <strong>Back</strong>, <strong>Next</strong>, <strong>Skip</strong>, or <strong>Done</strong> as appropriate. A step can display <strong>Waiting</strong> until its required action is complete.</p>
<h3>Reopen or change a route</h3>
<p>Select the saved route on the Dashboard and choose <strong>Edit Route</strong>. Review the existing information, make your changes, then select <strong>Save Route</strong>.</p>
<p>To change the waypoint sequence, use the <strong>Leg Sequence</strong> controls. <strong>Remove</strong> removes that leg. Removing a middle leg can change how the following leg connects and remove its previously saved path adjustment. Review the affected legs and totals afterward.</p>
<p>Choose distinct names for separate routes. Entering an existing name under <strong>Create Route</strong> can reopen an existing route; it is not a dependable way to make a copy.</p>
<h3>Know what has already been saved</h3>
<p>Some actions take effect before the bottom <strong>Save Route</strong> button:</p>
<div class="fpw-manual-table" role="region" aria-label="Reference table" tabindex="0"><table><thead><tr><th scope="col">Action</th><th scope="col">What it does</th></tr></thead><tbody><tr><td><strong>Create</strong>, <strong>Set Start</strong>, <strong>Add Leg</strong>, <strong>Remove</strong></td><td>Saves the corresponding waypoint-route change immediately.</td></tr><tr><td><strong>Save Overrides</strong></td><td>Saves the leg’s path adjustment.</td></tr><tr><td><strong>Load</strong></td><td>Loads the selected waypoint route into the planner.</td></tr><tr><td><strong>Save Route</strong></td><td>Saves the generated route and its planning assumptions.</td></tr><tr><td><strong>Close</strong></td><td>Closes the planner; it does not save unsaved planning assumptions.</td></tr><tr><td><strong>Reset</strong></td><td>Resets planning inputs or restores the opened route’s starting settings. It does not undo every earlier saved action.</td></tr></tbody></table></div>
<p><strong>My Routes → Delete</strong> removes that waypoint-route entry from the available selection. It is different from the Dashboard’s <strong>Delete</strong> or <strong>Archive</strong> action for a saved generated route.</p>
<p>If you cannot add a leg, check that a route and start waypoint are selected and that the next endpoint differs from the current one. If loading or saving fails, read the message, correct the identified issue, and wait for confirmation before closing the planner.</p>
<h3>Delete or archive a saved route</h3>
<p>From the Dashboard route's actions, choose <strong>Delete</strong> or <strong>Archive</strong> when offered, and read the confirmation. Delete can remove associated Draft data. Archive removes the route from your Routes list while retaining protected completed Premium Send history.</p>
<p>An active route cannot be deleted or archived. Complete or cancel the actual trip using the appropriate workflow first. Archive does not open a completed-trip history screen.</p>
<p>When <strong>Activate Route</strong> finds existing Drafts, its confirmation may offer to rebuild and replace them. Read that warning before continuing; activation is not a mail-send command.</p>
<p>Editing an active route can be refused if existing progress cannot be preserved. Do not treat editing as a way to reset a trip.</p>
</div><a class="fpw-manual-back" href="#manualContents">Back to contents</a></section>
<section class="fpw-manual-chapter" data-manual-chapter id="9-choose-your-vessel-and-planning-assumptions" aria-labelledby="chapter-title-9"><h2 id="chapter-title-9">9. Choose Your Vessel and Planning Assumptions</h2><div class="fpw-manual-chapter-body">
<p>Select the boat you will use under <strong>Vessel</strong>. FPW fills the corresponding speed and fuel-burn fields from its saved information. Review those values before relying on the estimates. Selecting another vessel replaces those fields.</p>
<p><strong>Check speed units carefully.</strong> The saved vessel form currently labels its speed fields <strong>KPH</strong>, while Route Generator uses <strong>kn</strong>. Do not assume that choosing a vessel converts its speed values. Check the numbers in the planner against reliable performance information for your boat, expressed in knots, before using the resulting time or fuel estimates.</p>
<p>Review these assumptions:</p>
<div class="fpw-manual-table" role="region" aria-label="Reference table" tabindex="0"><table><thead><tr><th scope="col">Input</th><th scope="col">What to enter or consider</th></tr></thead><tbody><tr><td><strong>Most Efficient Speed (kn)</strong></td><td>Your intended efficient cruising speed.</td></tr><tr><td><strong>GPH @ Efficient</strong></td><td>Fuel consumption at that speed, in gallons per hour.</td></tr><tr><td><strong>Max Speed (kn)</strong></td><td>The maximum-speed value used by the planning model.</td></tr><tr><td><strong>Fuel Burn @ Max (GPH)</strong></td><td>Fuel consumption at the entered maximum speed.</td></tr><tr><td><strong>Idle Burn (GPH)</strong> and <strong>Idle Hours (total)</strong></td><td>Expected idle consumption and total idle time.</td></tr><tr><td><strong>Weather Factor (%)</strong></td><td>The adjustment applied to estimated performance.</td></tr><tr><td><strong>Underway Hrs / Day</strong></td><td>The daily time allowance used to group the timeline.</td></tr><tr><td><strong>Reserve Method</strong></td><td>The fuel reserve convention for the estimate.</td></tr><tr><td><strong>Fuel Price ($/gal)</strong></td><td>The price used to estimate fuel cost.</td></tr></tbody></table></div>
<p>Use <strong>Pace</strong> to compare <strong>Relaxed</strong>, <strong>Efficient Speed</strong>, and <strong>Max Speed</strong>. These are calculation choices; they do not change your boat’s actual speed. Relaxed uses a fraction of maximum speed, while Efficient Speed uses the efficient-speed value you supplied.</p>
<p>Recheck the summary after changing assumptions. A blank or unavailable fuel result means the planner lacks a usable input; it does not mean the trip requires no fuel.</p>
<p>Select <strong>Save Route</strong> when you want to retain the revised planning assumptions. Departure dates, departure times, and trip timezones are entered later in the Float Plan workflow.</p>
</div><a class="fpw-manual-back" href="#manualContents">Back to contents</a></section>
<section class="fpw-manual-chapter" data-manual-chapter id="10-use-great-loop-planning-references" aria-labelledby="chapter-title-10"><h2 id="chapter-title-10">10. Use Great Loop Planning References</h2><div class="fpw-manual-chapter-body">
<p>Open the Great Loop reference libraries from the shared navigation. Use their maps, filters, and individual records to research your route.</p>
<p>The libraries provide planning information. Check record sources, review dates, and current official information before making a transit decision. A map marker or published record does not establish that a location is suitable for your boat today.</p>
<h3>Find a reference</h3>
<ol><li>Open <strong>Locks</strong>, <strong>Anchorages</strong>, <strong>Ports</strong>, or <strong>Bridges</strong>.</li><li>Enter a search term or choose a relevant filter.</li><li>Use <strong>Apply Filters</strong> for the search.</li><li>Review the results and map, then open the individual record.</li><li>Use <strong>Clear Filters</strong>, or <strong>Reset</strong> in Ports, to start a different search.</li></ol>
<p>Some dropdown changes apply immediately and clear other selections. Check the displayed filters after each change. Initial views may show featured places rather than every available record.</p>
<p>The library maps offer <strong>NOAA Nautical Charts</strong> where available. Use <strong>Map</strong> and <strong>List</strong> controls where shown to change your view.</p>
<h3>Locks</h3>
<p>Filter by <strong>State / Province</strong> or <strong>Waterway / System</strong>, or use <strong>Search Locks</strong>. Changing the state clears the waterway selection so you can choose from the relevant waterways.</p>
<p>Open a lock record to review its location, VHF channel or phone when listed, approach notes, operating notes, special instructions, and official source. Related guides provide lock-through preparation and communication guidance.</p>
<p>Check current operating arrangements separately. Missing contact information or an empty field means it has not been supplied.</p>
<h3>Anchorages</h3>
<p>Search by name, location, waterway, or descriptive information. Filters include <strong>Location Group</strong>, <strong>Waterway</strong>, <strong>State / Province</strong>, <strong>Country</strong>, <strong>Anchorage Type</strong>, and <strong>Public Status</strong>.</p>
<p>Review the record’s holding, protection, shore access, planning notes, nearby places, verification information, and source. These details help you investigate a stop; they do not confirm present holding conditions, available space, or suitability for the current weather.</p>
<h3>Ports</h3>
<p>Use <strong>Search</strong>, <strong>State / Province</strong>, <strong>Loop Segment</strong>, and <strong>Major stop candidates</strong>. Open a port to review its approach notes, services, nearby places, coordinates, and review information.</p>
<p>To reuse a port in your planning:</p>
<ol><li>Sign in and open a port with available coordinates.</li><li>Select <strong>Add to My Waypoints</strong>.</li><li>Wait for <strong>Added</strong>.</li><li>Find the saved location in Dashboard <strong>Waypoints</strong>.</li><li>Choose it as a start or leg endpoint when building your route.</li></ol>
<p>Adding the waypoint does not add it to a route automatically. Check your saved waypoints before adding the same port again on a later visit.</p>
<h3>Bridges</h3>
<p>Use the location, route, and bridge-type filters. Additional filters include <strong>Drawbridge only</strong>, <strong>Air-draft concern</strong>, <strong>Has VHF or phone</strong>, and <strong>Has coordinates</strong>.</p>
<p>Review closed and open vertical clearance, horizontal clearance, opening schedules, contact procedures, and navigation or regulatory notes. Compare the information with your vessel’s air draft and current conditions. The library does not automatically approve clearance for your boat.</p>
<p>Confirm current water levels, bridge gauges, opening restrictions, notices, and official charts before transit.</p>
</div><a class="fpw-manual-back" href="#manualContents">Back to contents</a></section>
<section class="fpw-manual-chapter" data-manual-chapter id="11-adjust-a-legs-path-and-distance" aria-labelledby="chapter-title-11"><p class="fpw-manual-part">Part IV — Build and Refine Your Route</p><h2 id="chapter-title-11">11. Adjust a Leg’s Path and Distance</h2><div class="fpw-manual-chapter-body">
<p>The default distance for a waypoint leg can be the direct distance between its endpoints. It may not follow a navigable channel or account for the bends and detours you intend to travel.</p>
<p>Use <strong>Edit Route</strong> on an individual leg to inspect and refine its path.</p>
<h3>Draw or edit a leg</h3>
<ol><li>Load or reopen the route in <strong>FPW Route Generator</strong>.</li><li>Find the leg under <strong>Leg Sequence</strong> or <strong>Cruise Timeline</strong> and select <strong>Edit Route</strong>.</li><li>In <strong>Leg Geometry</strong>, locate the start and end.</li><li>If helpful, enter a place, marina, or city in the search box and select <strong>Search</strong>.</li><li>Use the map’s line-drawing or editing controls to trace your intended path. A line needs at least two points.</li><li>Review <strong>Computed NM</strong>.</li><li>Select <strong>Save Overrides</strong> and wait for confirmation.</li><li>Recheck the leg distance, total distance, time, and fuel estimates.</li></ol>
<p>Search adds a reference pin. It does not draw the route or move your saved waypoints. <strong>Clear Pin</strong> removes the search pin.</p>
<p>A drawn line is your planning input. FPW does not establish that every part of it is safe or navigable. Compare it with appropriate charts, depths, restrictions, and local information.</p>
<h3>Clear or revert an adjustment</h3>
<p><strong>Clear Draw</strong> clears the line in the editor. Saving that cleared state can remove the leg’s adjustment.</p>
<p><strong>Revert to Default</strong> removes the applicable saved adjustment and returns to the default path or distance. Review the resulting <strong>Computed NM</strong> and route totals before continuing.</p>
<p>Geometry saves take effect when you use their save controls. Closing the planner or selecting <strong>Reset</strong> is not a universal undo.</p>
<p>If the editor reports that geometry cannot be saved, or a leg has no usable coordinates, correct the underlying route or waypoint information before relying on the estimate. On a smaller screen, scroll through the stacked planner panels; the leg’s <strong>Edit Route</strong> button still opens the geometry editor.</p>
</div><a class="fpw-manual-back" href="#manualContents">Back to contents</a></section>
<section class="fpw-manual-chapter" data-manual-chapter id="12-understand-the-cruise-timeline-time-and-fuel-estimates" aria-labelledby="chapter-title-12"><h2 id="chapter-title-12">12. Understand the Cruise Timeline, Time and Fuel Estimates</h2><div class="fpw-manual-chapter-body">
<p>The planner’s summary answers several different questions:</p>
<ul><li><strong>Total Distance</strong>: how far the planned legs cover.</li><li><strong>Total Travel Hours</strong>: the estimated travel time under the current assumptions.</li><li><strong>Estimated Fuel</strong>: estimated required fuel including the selected reserve.</li><li><strong>Adjusted Speed</strong>: speed after the planning adjustment.</li><li><strong>Fuel Cost</strong>: estimated cost using the entered price.</li><li><strong>Locks</strong> and <strong>Offshore Legs</strong>: the route information available to the planner.</li><li><strong>Expected Avg GPH</strong>: estimated average consumption.</li></ul>
<p>These are estimates, not observations of your vessel underway. Changing the route path, pace, burn rates, weather factor, idle time, or reserve can change the results.</p>
<h3>Read the timeline</h3>
<p>Select a leg row in <strong>Cruise Timeline</strong> to expand its details. Review the selected leg’s distance, hours, and locks, then the associated <strong>Day Rollup</strong>.</p>
<p><strong>Underway Hrs / Day</strong> controls the grouping. One long leg can span several days, and a day can include portions of several legs. A day total therefore need not equal the selected leg’s total.</p>
<p>GREEN, YELLOW, and RED day indicators reflect planning factors such as reserve margin and day length. They do not certify weather, navigability, or safety.</p>
<h3>Interpret lock information</h3>
<p>Where locks are mapped, <strong>Lock Navigation Details</strong> includes available lock information and <strong>Best</strong>, <strong>Typical</strong>, and <strong>Worst</strong> waiting estimates. Use <strong>Retry</strong> if retrieval fails, or <strong>Hide</strong> to collapse the details.</p>
<p><strong>No canonical lock mapping for waypoint leg</strong> means that FPW does not have a lock mapping for that leg. It does not mean there are no locks. Research the waterway separately.</p>
<p>Mapped lock delays can affect estimated time. Actual waiting and operating conditions can differ.</p>
<h3>Understand reserve and cost</h3>
<p>Idle fuel comes from <strong>Idle Burn × Idle Hours</strong>. Reserve is then calculated using the selected method.</p>
<p>With <strong>One-Third Rule</strong>, an estimated base consumption of 60 gallons produces 90 gallons required: 60 gallons of consumption plus 30 gallons reserved. It is not a 33% addition to consumption.</p>
<p>The 20% and 15% methods add their stated percentage to base consumption. <strong>Fuel Cost</strong> uses required fuel, including the reserve calculation.</p>
<p>Review your boat’s usable capacity and practical refueling opportunities independently. Save the route after changing the assumptions you intend to retain.</p>
</div><a class="fpw-manual-back" href="#manualContents">Back to contents</a></section>
<section class="fpw-manual-chapter" data-manual-chapter id="13-use-weather-in-planning-and-underway" aria-labelledby="chapter-title-13"><h2 id="chapter-title-13">13. Use Weather in Planning and Underway</h2><div class="fpw-manual-chapter-body">
<p>FPW provides three weather tools: the dedicated <strong>Marine Weather Briefing</strong>, Route Generator’s <strong>Live Weather Assist</strong>, and the <strong>Weather</strong> panel in Active Cruise. Each serves a different purpose.</p>
<p>Weather readings and suggestions are tied to the location and time shown. Check both before using them. Missing readings are not zero wind, zero waves, or an all-clear.</p>
<h3>Open a Marine Weather Briefing</h3>
<ol><li>Select <strong>Weather</strong> from the member navigation.</li><li>Under <strong>Location</strong>, choose <strong>Home Port / ZIP</strong> or <strong>Coordinates</strong>.</li><li>Review the ZIP, or enter latitude and longitude.</li><li>Select <strong>Update</strong>.</li><li>Confirm the resolved location and update time.</li></ol>
<p>A ZIP represents an approximate area and may not match your marina. For a more precise default, maintain your home-port coordinates in <strong>My Account</strong>.</p>
<p>If FPW reports missing home-port coordinates, select <strong>Update Home Port</strong> and correct them. If ZIP lookup is unavailable or the ZIP is not found, use appropriate coordinates or update the saved home port. For temporary provider failures, wait and try <strong>Update</strong> again.</p>
<p>Review the briefing in this order:</p>
<ol><li><strong>Marine Risk</strong> and its listed reasons.</li><li><strong>Conditions Now</strong>, including observation time and station.</li><li><strong>Waves / Seas</strong> and <strong>Tide Now</strong>.</li><li><strong>Marine Alerts</strong>. Select <strong>View active NOAA alerts</strong> to read the available details and instructions.</li><li><strong>Next 12 Hours</strong> for changes during your planned travel.</li><li><strong>Tide &amp; Water Level</strong>, using <strong>Today</strong> or <strong>Tomorrow</strong>.</li><li><strong>NOAA Zone Area Forecast</strong> and <strong>Source &amp; Station Details</strong>.</li></ol>
<p>Select <strong>Open NOAA Map</strong> to view the available overlays. Layer availability varies; use the listed radar, warning, wind, cloud, or other layers that are supplied for the location. Close the map to return to the briefing.</p>
<p>Check the displayed timezone, source, station, and observation times. A favorable summary is not a substitute for reviewing the relevant warnings and official marine information.</p>
<h3>Use Live Weather Assist while planning</h3>
<p>In Route Generator:</p>
<ol><li>Load the route.</li><li>Under <strong>Live Weather Assist</strong>, select <strong>Refresh Suggestion</strong> to use the route’s starting point, or enter <strong>Lat</strong> and <strong>Lng</strong> and select <strong>Lookup Point</strong>.</li><li>Review the suggested factor, confidence, and source.</li><li>Select <strong>Apply Suggested</strong> if you want that value applied to <strong>Weather Factor (%)</strong>.</li><li>Review the changed estimates, then select <strong>Save Route</strong> to retain your planning assumptions.</li></ol>
<p>Looking up weather does not apply it automatically. The suggestion represents a point, not conditions at every place and time along your trip.</p>
<h3>Check weather in Active Cruise</h3>
<ol><li>In <strong>Weather</strong>, choose the current leg’s available <strong>Start</strong> or <strong>End</strong> point.</li><li>Select <strong>Check Conditions</strong>.</li><li>Review the point, temperature, wind, gusts, waves, visibility, alerts, and calculated <strong>Weather Factor</strong>.</li><li>If appropriate and available, select <strong>Apply Weather to Route</strong>.</li></ol>
<p><strong>Apply Weather to Route</strong> saves the factor and updates the route’s estimates. <strong>Check Conditions</strong> alone does not. If the point or apply control is unavailable, read the explanation and use the dedicated Weather page for a separate lookup.</p>
</div><a class="fpw-manual-back" href="#manualContents">Back to contents</a></section>
<section class="fpw-manual-chapter" data-manual-chapter id="14-use-the-linked-fuel-and-range-calculator" aria-labelledby="chapter-title-14"><h2 id="chapter-title-14">14. Use the Linked Fuel and Range Calculator</h2><div class="fpw-manual-chapter-body">
<p>Select <strong>Fuel Calculator</strong> from the member navigation to compare an independent fuel-planning scenario.</p>
<p>The calculator does not load or update your saved vessel or route. Enter the values for the scenario you want to examine.</p>
<h3>Calculate a scenario</h3>
<ol><li>Enter <strong>Total Distance (NM)</strong>.</li><li>Enter <strong>Most Efficient Speed (kn)</strong> and <strong>GPH @ Efficient</strong>.</li><li>Enter <strong>Max Speed (kn)</strong> and <strong>Fuel Burn @ Max (GPH)</strong> when needed for your chosen <strong>Pace</strong>.</li><li>Add <strong>Idle Burn (GPH)</strong> and <strong>Idle Hours</strong> if applicable.</li><li>Review <strong>Weather Factor (%)</strong>, <strong>Underway Hrs / Day</strong>, and <strong>Reserve Method</strong>.</li><li>Enter <strong>Fuel Price ($/gal)</strong> if you want a cost estimate.</li><li>Enter <strong>Usable Fuel Capacity</strong> if you want a range estimate and capacity comparison.</li></ol>
<p>Results update as you change the inputs. There is no separate Calculate step.</p>
<p>Usable fuel is the fuel available for planning before the calculator applies reserve. It may be less than the tank’s nominal capacity.</p>
<h3>Review and retain results</h3>
<p>Read the time, fuel, speed, average GPH, cost, and <strong>Estimated Range with Reserve</strong> results. Expand <strong>Calculation Breakdown and JSON</strong> to inspect the assumptions and calculation.</p>
<p>The range estimate is based on usable capacity, reserve, adjusted speed, and burn. It does not subtract the separately entered trip idle fuel from its range allowance. Review idle consumption and other practical limits before using the range figure.</p>
<p>Use <strong>Copy Result JSON</strong> to copy an available result. This copies information to your clipboard; it does not save a vessel, route, or Float Plan in FPW.</p>
<p><strong>Reset</strong> clears the scenario and restores calculator defaults. A fresh page load does not restore an earlier scenario, so copy any result you want to retain before leaving.</p>
<p>If a result is unavailable, check the required speed and burn values, positive trip distance, and usable capacity. An unavailable result is not a zero requirement or confirmation that the trip fits your fuel supply.</p>
</div><a class="fpw-manual-back" href="#manualContents">Back to contents</a></section>
<section class="fpw-manual-chapter" data-manual-chapter id="15-complete-the-six-step-float-plan-wizard" aria-labelledby="chapter-title-15"><p class="fpw-manual-part">Part V — Create and Send Your Float Plan</p><h2 id="chapter-title-15">15. Complete the Six-Step Float Plan Wizard</h2><div class="fpw-manual-chapter-body">
<p>The Float Plan Wizard brings your route, boat, people, schedule, and safety information together. Start with a saved route and saved vessel, operator, and shore-contact records.</p>
<h3>Open and resume your plan</h3>
<ol><li>Open <strong>Dashboard → Routes</strong>.</li><li>Find the route you want to use.</li><li>Choose <strong>Activate Route</strong> if it does not yet have a Float Plan Draft.</li><li>Choose <strong>Complete Float Plan</strong> to open its Draft. Other available plan actions may read <strong>Edit Float Plan</strong> or <strong>View &amp; Send Float Plan</strong>.</li></ol>
<p>Activating a route prepares the Draft. It does not send an email.</p>
<p>The primary Dashboard Wizard has six steps. Use <strong>Next</strong> and <strong>Back</strong> to move between them. These buttons do <strong>not</strong> save automatically. Choose <strong>Save Float Plan</strong> before closing if you want to preserve your changes.</p>
<h3>Step 1 — Basics</h3>
<p>Complete these fields:</p>
<div class="fpw-manual-table" role="region" aria-label="Reference table" tabindex="0"><table><thead><tr><th scope="col">Field</th><th scope="col">What to enter</th></tr></thead><tbody><tr><td><strong>Your name / Sender name</strong></td><td>Appears when your account is missing a name. Enter at least a first or last name; it is saved to your profile.</td></tr><tr><td><strong>Float Plan Name</strong></td><td>Required. Use a name you and your contacts will recognize.</td></tr><tr><td><strong>Vessel</strong></td><td>Required. Select the saved boat for this trip.</td></tr><tr><td><strong>Operator</strong></td><td>Required. Select the saved operator.</td></tr><tr><td><strong>Operator has PFD</strong></td><td>Optional checkbox describing the operator’s equipment.</td></tr></tbody></table></div>
<p>Your account name identifies the sender. It is separate from the selected operator.</p>
<p>If the correct vessel or operator is missing, return to Dashboard to add or correct that record, then reopen the Draft. Required fields can prevent saving; closing may lose unsaved edits.</p>
<h3>Step 2 — Times &amp; Route</h3>
<p>Enter or check all six required fields:</p>
<ul><li><strong>Departing From</strong></li><li><strong>Departure Date &amp; Time</strong></li><li><strong>Departure Time Zone</strong></li><li><strong>Returning To</strong></li><li><strong>Return Date &amp; Time</strong></li><li><strong>Return Time Zone</strong></li></ul>
<p>FPW may fill missing locations from the route or home port. Check that they describe this trip correctly.</p>
<p>Choose the timezone that belongs with each entered local time. Return must be after departure, and sending requires a return time that is still in the future.</p>
<p>FPW can suggest a return time from your route. Review that suggestion against your plans. A return time you edit manually is preserved.</p>
<p>Once actual departure has been recorded, the scheduled departure cannot be changed in the Wizard.</p>
<h3>Step 3 — People &amp; Safety</h3>
<p>Choose the required <strong>Rescue Authority</strong>. Its authority information is filled from the selection. <strong>N/A - Call 911</strong> is also an available choice.</p>
<p>The other fields are optional:</p>
<div class="fpw-manual-table" role="region" aria-label="Reference table" tabindex="0"><table><thead><tr><th scope="col">Field</th><th scope="col">Purpose</th></tr></thead><tbody><tr><td><strong>Email (while underway)</strong></td><td>An email address relevant to the trip</td></tr><tr><td><strong>Food (days/person)</strong></td><td>Food supply information</td></tr><tr><td><strong>Water (days/person)</strong></td><td>Water supply information</td></tr><tr><td><strong>Notes</strong></td><td>Additional information for the Float Plan</td></tr></tbody></table></div>
<p>Review the authority and contact information before sending. Selecting an authority does not request assistance.</p>
<h3>Step 4 — Passengers, Crew &amp; Contacts</h3>
<ol><li>Open the <strong>Passengers</strong> tab.</li><li>Select the saved people coming aboard. A solo trip can have no passengers selected.</li><li>Open the <strong>Contacts</strong> tab.</li><li>Select at least one saved contact.</li><li>Review <strong>On This Trip</strong> and the selected counts.</li></ol>
<p>Use <strong>Search passengers...</strong> or <strong>Search contacts...</strong> to find a record. Selecting a row adds or removes it from the trip.</p>
<p>On smaller screens, expand the summary when you need to check the selections. Selecting a contact here does not send anything yet.</p>
<h3>Step 5 — Waypoints</h3>
<p>Review the numbered <strong>In Route</strong> summary.</p>
<p>This step shows the route’s waypoint order. It is read-only in the Dashboard Wizard. If the route itself needs correction, save your Draft and use the route-planning tools.</p>
<h3>Step 6 — Review</h3>
<ol><li>Check the sender name.</li><li>Choose <strong>Save Float Plan</strong> after making changes.</li><li>Review the PDF preview.</li><li>Check the boat, people, route, times, timezones, safety information, and contact details.</li><li>Choose a sending option only when the plan is ready.</li></ol>
<p>The preview uses saved information. Unsaved edits may not appear until you save again. The send actions save current changes before submitting the plan.</p>
<p><strong>Expected result:</strong> Saving displays <strong>Float plan saved successfully</strong> and keeps the Wizard open. You can close it and later reopen the saved Draft.</p>
<p><strong>If something needs attention:</strong> Follow the field message and return to the indicated step. Common problems are missing required records, no selected contact, invalid timing, and an unavailable PDF preview. Closing without saving can lose your latest edits.</p>
</div><a class="fpw-manual-back" href="#manualContents">Back to contents</a></section>
<section class="fpw-manual-chapter" data-manual-chapter id="16-review-and-send-basic-premium-and-credits" aria-labelledby="chapter-title-16"><h2 id="chapter-title-16">16. Review and Send: Basic, Premium and Credits</h2><div class="fpw-manual-chapter-body">
<p>Choose the option that matches what you need for this trip.</p>
<div class="fpw-manual-table" role="region" aria-label="Reference table" tabindex="0"><table><thead><tr><th scope="col"></th><th scope="col"><strong>Basic Save &amp; Send</strong></th><th scope="col"><strong>Premium Save &amp; Send</strong></th></tr></thead><tbody><tr><td>Sends the Float Plan PDF</td><td>Yes</td><td>Yes</td></tr><tr><td>Recipients</td><td>One selected saved contact</td><td>Selected plan contacts with email</td></tr><tr><td>Keeps the plan as a Draft</td><td>Yes</td><td>No; successful sending activates the trip</td></tr><tr><td>Activates monitoring and Active Cruise</td><td>No</td><td>Yes, for the eligible trip</td></tr><tr><td>Provides Private Follow access</td><td>No</td><td>Available for the eligible trip; sharing the link is separate</td></tr><tr><td>Uses a Premium Send Credit</td><td>No</td><td>One credit unless eligible membership covers the send</td></tr></tbody></table></div>
<h3>Send with Basic</h3>
<ol><li>Finish the Wizard and review the saved PDF.</li><li>Choose <strong>Basic Save &amp; Send</strong>.</li><li>Read the <strong>Send Basic Float Plan?</strong> confirmation.</li><li>Check the recipient’s name and email.</li><li>If several contacts are selected, use <strong>Choose one saved contact</strong> to select the recipient. An unusable email cannot be selected.</li><li>Choose <strong>Continue with Basic Send</strong>.</li></ol>
<p>Choose <strong>Cancel</strong> to leave the confirmation without sending. <strong>Upgrade to Premium Send</strong> starts the Premium send workflow and may send immediately when access is available; use it only when ready. If access is missing, follow the displayed credit or membership requirement.</p>
<p><strong>Expected result:</strong> FPW submits the PDF email to the chosen contact. Your saved Draft remains available. This Basic option does not start monitoring, Active Cruise, live trip updates, or Private Follow access.</p>
<h3>Send with Premium</h3>
<ol><li>Finish the Wizard and review the saved PDF and selected contacts.</li><li>Read the Premium availability message.</li><li>If access or a credit is available, choose <strong>Premium Save &amp; Send</strong>.</li><li>Wait for the result before leaving or trying again.</li><li>After success, return to Dashboard to open <strong>Active Cruise</strong> or share the Follow Link.</li></ol>
<p><strong>Expected result:</strong> FPW submits the selected contacts’ PDF emails and activates the route-backed trip. Activation and actual departure are separate: use the underway controls described in Chapter 19 when you start the trip.</p>
<p>FPW permits only one active route/Float Plan group at a time. If another trip is active, resolve that trip before sending this one.</p>
<h3>Purchase access without sending</h3>
<p>When a purchase is needed, the Review screen may offer <strong>Buy One Trip</strong>, <strong>Monthly Membership</strong>, and <strong>Annual Membership</strong>.</p>
<ol><li>Choose an available option.</li><li>Review and complete the hosted checkout.</li><li>Return to FPW and wait for credit or access confirmation.</li><li>Reopen your plan and review it.</li><li>Choose <strong>Premium Save &amp; Send</strong> when ready.</li></ol>
<p>Purchasing does <strong>not</strong> send the Draft.</p>
<p>A Premium Send Credit supplies operational access for that exact trip for <strong>21 days from the send that consumes it</strong>, not from scheduled departure. Eligible membership may independently provide access. Closing or cancelling the trip ends its operational lifecycle.</p>
<p>If checkout remains <strong>being confirmed</strong>, refresh/check <strong>My Account</strong>. Do not assume that returning from checkout means a Float Plan was sent.</p>
<p>A checkout return can occasionally display a different Wizard layout. Use <strong>Back to Dashboard</strong> and reopen the original plan from Routes. The procedures in this manual describe the current six-step Dashboard Wizard.</p>
<h3>Read the result before retrying</h3>
<p>After a confirmed Premium send, <strong>Show Original Premium Send Result</strong> displays that earlier result. It does not send another email or spend another credit.</p>
<p>A definite failed Basic request may instruct you to reopen Basic Send and start again. Follow that instruction only when the result says the request failed.</p>
<p>If FPW reports:</p>
<blockquote><p>The email was submitted, but its completion could not be confirmed. Do not resend; contact support.</p></blockquote>
<p>stop and contact support. An uncertain result is not proof that no email was submitted. Likewise, allow an <strong>already in progress</strong> request to finish rather than starting another.</p>
<p>Common blocks include missing access or credit, another active trip, a return time that has passed, no usable recipient, or unsuccessful PDF preparation.</p>
<p>Email submission is not proof of delivery or reading. Agree with your shore contacts about what they should expect and how they will respond if you are overdue.</p>
</div><a class="fpw-manual-back" href="#manualContents">Back to contents</a></section>
<section class="fpw-manual-chapter" data-manual-chapter id="17-share-your-trip-and-post-voyage-updates" aria-labelledby="chapter-title-17"><h2 id="chapter-title-17">17. Share Your Trip and Post Voyage Updates</h2><div class="fpw-manual-chapter-body">
<p>The initial Float Plan email contains the PDF. Sharing the <strong>Follow Link</strong> is a separate action.</p>
<p>Use Follow to give trusted people access to the eligible trip’s shared page. Keep the link private to the people you intend to include.</p>
<h3>Share the Follow Link</h3>
<ol><li>Open Dashboard and find your active route.</li><li>Choose <strong>Share Follow Link</strong>.</li><li>Use <strong>Open Follow Page</strong> to check the page.</li><li>Choose <strong>Copy Link</strong> to paste it into your preferred message, or <strong>Send by Text Message</strong> to open your device’s text-message handler.</li><li>Send the link to your chosen recipients.</li></ol>
<p>Opening a text-message handler does not itself confirm that the message was sent. Complete the message in that application.</p>
<p>A recipient can use a valid shared link without signing in as the captain. The page remains subject to the trip’s access and state.</p>
<h3>Explain what recipients are seeing</h3>
<p>The page can show the current leg, next stop, route progress, check-in information, conditions, map, <strong>Track Log</strong>, <strong>Cruise Timeline</strong>, photos, and <strong>Voyage Stream</strong>. A Float Plan PDF download appears when available. <strong>Open Full Map</strong> provides a larger map view.</p>
<p>Explain these limits to people ashore:</p>
<ul><li>Route-progress markers and arrival times are estimates.</li><li>FPW is not continuous live vessel tracking.</li><li>A green status is not proof of the boat’s location or condition.</li><li>The shared page does not replace your agreed check-in and emergency-response arrangements.</li></ul>
<h3>Post an owner update</h3>
<p>Sign in to FPW as the trip owner before using the composer.</p>
<ol><li>Open <strong>Follow Page</strong>.</li><li>Find <strong>Voyage Stream</strong>.</li><li>Enter an update, select a photo, or do both.</li><li>Optionally use <strong>All good</strong>, <strong>Underway</strong>, <strong>Weather delay</strong>, or <strong>Anchored safely</strong> to insert quick text.</li><li>Choose <strong>Post Update</strong>.</li></ol>
<p>You can attach one JPG, PNG, or WebP image up to <strong>5 MB</strong>. Quick tags insert text; they do not publish until you choose <strong>Post Update</strong>.</p>
<p><strong>Expected result:</strong> The update appears in the stream for people with access to the shared page.</p>
<p>Your own non-system posts have <strong>Delete</strong>. Select it and confirm <strong>Delete this post?</strong> to remove a post. There is no post-edit control.</p>
<h3>Reactions and comments</h3>
<p>Followers can select <strong>Like</strong>, <strong>Love</strong>, <strong>Boat</strong>, or <strong>Wave</strong>. They can enter a comment of up to <strong>500 characters</strong> and choose <strong>Comment</strong> or press Enter.</p>
<p>The first interaction requests a display name and optional email. A password may be requested for interaction when applicable. Do not treat that interaction prompt as a guarantee that someone holding the shared link cannot read the page.</p>
<h3>After the trip</h3>
<p>Successful completion can change the shared page to <strong>Trip Completed Safely</strong>, with limited completion information. It does not preserve the full active map, posts, and operational controls.</p>
<p>Cancelled or expired trips are not automatically shown as safely completed. If access or a PDF is unavailable, check the trip’s status and your account access. For ongoing uncertainty, contact support.</p>
</div><a class="fpw-manual-back" href="#manualContents">Back to contents</a></section>
<section class="fpw-manual-chapter" data-manual-chapter id="18-read-active-cruise" aria-labelledby="chapter-title-18"><p class="fpw-manual-part">Part VI — Use FPW While Underway</p><h2 id="chapter-title-18">18. Read Active Cruise</h2><div class="fpw-manual-chapter-body">
<p>Active Cruise is the captain’s operational view of the current active, route-backed trip. Open the active route on your Dashboard and select <strong>Open Active Cruise</strong>.</p>
<p>Check the trip name and route before making an update. Active Cruise reports the current trip state and provides check-in, timing, and route-leg controls. It requires operational access for that trip. A draft plan, a completed trip, or a plan without the required active route does not provide the same operational view.</p>
<h3>Understand the overview</h3>
<p>The main overview separates the planned schedule from reported progress:</p>
<ul><li><strong>Scheduled Departure</strong> is the planned departure time. It does not establish that you have left.</li><li><strong>Current Leg</strong> identifies the current part of the route.</li><li><strong>Distance Complete</strong> and <strong>Leg Progress</strong> are estimates based on recorded underway activity and planning assumptions.</li><li><strong>Next Stop</strong> and <strong>ETA</strong> refer to the current leg.</li><li><strong>Final Arrival</strong> in the route summary is the estimate for the entire route.</li></ul>
<p>Use the summary’s <strong>Final Arrival</strong> when checking the overall arrival estimate. Do not confuse it with the current leg’s ETA.</p>
<p>A progress percentage reaching 100% does not complete the leg or close the Float Plan. You must explicitly record leg completion and, after all legs are complete, close the plan.</p>
<h3>Read the map</h3>
<p><strong>Map Overview</strong> displays available route geometry and reported position information. Select <strong>Open Full Map</strong> for a larger view, then close the map window to return to the controls.</p>
<p>The route line is your planned route. A reported position is a location captured with a check-in. These are different kinds of information.</p>
<p>FPW is not continuous live vessel tracking. Read the position’s timestamp before treating it as current. If no position is available, the map can still show the planned route.</p>
<h3>Inspect an individual leg</h3>
<p>In <strong>Route Timeline</strong>, select a leg to expand its details. Keyboard users can focus a leg and press Enter or Space.</p>
<p>The expanded information can include departure, ETA or arrival, distance, progress, and available lock details. <strong>Selected Leg Data</strong> shows estimates such as remaining distance, time, and fuel.</p>
<p>Selecting a timeline leg only changes what you are inspecting. It does not start that leg, complete another leg, or change your operational position in the route.</p>
<h3>Adjust pace</h3>
<p>The <strong>Set Active-Trip Pace</strong> slider provides:</p>
<ul><li><strong>Relaxed</strong></li><li><strong>Efficient Speed</strong></li><li><strong>Max Speed</strong></li></ul>
<p>Changing the slider saves the selection immediately and refreshes the trip projection. There is no separate Save button. Wait for the success or error message before making another adjustment.</p>
<p>Pace, applied weather factors, and delays influence estimates. They do not prove the vessel’s actual speed, position, or arrival.</p>
</div><a class="fpw-manual-back" href="#manualContents">Back to contents</a></section>
<section class="fpw-manual-chapter" data-manual-chapter id="19-check-in-and-understand-monitoring" aria-labelledby="chapter-title-19"><h2 id="chapter-title-19">19. Check In and Understand Monitoring</h2><div class="fpw-manual-chapter-body">
<p>A check-in reports your current status to FPW. Open <strong>Active Cruise</strong>, find <strong>Check-In &amp; Route Control</strong>, and choose the status that matches the trip.</p>
<p>The four visible check-in choices are <strong>On Track</strong>, <strong>Delayed</strong>, <strong>Changed Plan</strong>, and <strong>Secure Night</strong>.</p>
<h3>Submit a check-in</h3>
<ol><li>Confirm that Active Cruise shows the correct trip.</li><li>If useful, select <strong>+ Add optional note</strong> and enter up to 500 characters.</li><li>Select the appropriate status.</li><li>Read and accept any confirmation.</li><li>Wait for the result, then check <strong>Last Check-In</strong> and <strong>Next Expected Check-In</strong>.</li></ol>
<p>The optional note accompanies the status check-in and appears in the trip’s voyage stream. Use a private captain note instead when the information should remain private.</p>
<p>The optional check-in note does not attach to <strong>Complete Current Leg / Arrived</strong>, <strong>Start Next Leg</strong>, or <strong>Close Float Plan</strong>.</p>
<h3>Choose the appropriate status</h3>
<p><strong>On Track</strong> records that the trip is underway or continuing normally. Before the first actual departure, selecting it starts the operational trip. Use it when you actually leave, not as a test before departure.</p>
<p>After a Delayed or Secure Night pause, <strong>On Track</strong> resumes the same underway leg. If the previous leg has already been completed, use <strong>Start Next Leg</strong> instead.</p>
<p><strong>Delayed</strong> reports a delay and pauses projected underway progress. Monitoring remains active. This differs from entering a number of delay minutes.</p>
<p><strong>Changed Plan</strong> reports that the plan has changed. It does not edit the route, schedule, or distributed Float Plan. The confirmation directs you to update and resend the plan if the route or schedule changed.</p>
<p><strong>Secure Night</strong> records an overnight pause. It requires confirmation and is available after the cruise has started. It moves the next expected check-in to the next Daily Start checkpoint.</p>
<p>Before actual departure, some statuses are unavailable. FPW may ask you to provide a new departure time or update and resend the plan instead.</p>
<h3>Understand location capture</h3>
<p>When submitting a routine Active Cruise check-in, your browser may request access to your location. If available, FPW can include that location with the report.</p>
<p>A location permission denial, timeout, or unavailable GPS does not prevent the status check-in from being submitted. Read the final check-in result separately from the GPS message.</p>
<p>A successful GPS capture alone is not a successful check-in. Likewise, a check-in without GPS can still update the trip and monitoring state.</p>
<p>If FPW says the check-in was submitted but the view could not refresh, refresh the page. Do not immediately repeat the check-in.</p>
<h3>Read Float Plan Monitor</h3>
<p>Open <strong>Float Plan Monitor</strong> from FPW navigation. The page is headed <strong>Monitoring Console</strong> and provides a read-only view of the active monitored trip.</p>
<p>Use it to inspect:</p>
<ul><li>Current trip and monitoring status.</li><li><strong>Next Check-In</strong> and <strong>Last Status</strong>.</li><li>The last reported location, its accuracy, and captured/received timestamps.</li><li><strong>Alert Readiness</strong>, including expected check-in and grace timing.</li><li><strong>Monitoring Audit</strong> and <strong>GPS Capture History</strong>.</li></ul>
<p>Make operational updates in Active Cruise; the Monitor is for inspection.</p>
<h3>Interpret monitoring states</h3>
<p><strong>Active</strong> means monitoring is active for the current checkpoint. <strong>Late</strong> means the expected check-in has passed. <strong>Missed</strong> means the grace period has passed. <strong>Escalated</strong> means the missed check-in has progressed to the contact-notification stage.</p>
<p>FPW evaluates these conditions and attempts the applicable notices. The status alone does not prove that an email reached its recipient.</p>
<p>A successful check-in resolves an outstanding missed or escalated monitoring condition and recalculates the next checkpoint. Always read the resulting <strong>Next Expected Check-In</strong>.</p>
<p>FPW staff are not continuously watching your trip. Your shore contact remains responsible for the agreed response. In an emergency, use official emergency channels rather than relying on an FPW status update.</p>
<h3>Which notices might be sent</h3>
<div class="fpw-manual-table" role="region" aria-label="Reference table" tabindex="0"><table><thead><tr><th scope="col">Notice</th><th scope="col">Who it is for and when it applies</th></tr></thead><tbody><tr><td>Departure reminder</td><td>The captain of an eligible active route-backed trip that has not actually started. Reminder windows are two hours to 90 minutes before departure, and 30 to 60 minutes after scheduled departure if it remains unstarted.</td></tr><tr><td>Missed check-in</td><td>The captain, after the checkpoint's grace period is exceeded and evaluated.</td></tr><tr><td>Escalation</td><td>The selected trip contacts when an unresolved missed check-in reaches escalation.</td></tr><tr><td>Safe arrival</td><td>The captain and applicable trip contacts after successful explicit closure.</td></tr><tr><td>Routine check-in / voyage update</td><td>Updates the trip or stream as described; it does not promise an email for every status or post.</td></tr></tbody></table></div>
<p>Reminders can be suppressed once the trip has actually started or finished; they are not sent indefinitely as catch-up reminders. Current timing defaults use a 60-minute grace period and an escalation interval of 120 minutes after Missed is recorded. Use the displayed <strong>Next Expected Check-In</strong> and monitoring information for your trip rather than calculating a guaranteed email-delivery time.</p>
<p>Notification processing and recipient delivery can take time or fail. If a contact needs to know promptly, communicate directly using your agreed method.</p>
</div><a class="fpw-manual-back" href="#manualContents">Back to contents</a></section>
<section class="fpw-manual-chapter" data-manual-chapter id="20-handle-delays-overnight-stops-and-multiple-legs" aria-labelledby="chapter-title-20"><h2 id="chapter-title-20">20. Handle Delays, Overnight Stops and Multiple Legs</h2><div class="fpw-manual-chapter-body">
<p>FPW has separate controls for reporting a delay, adjusting estimates, pausing overnight, and moving between route legs. Use the control that matches what actually happened.</p>
<h3>Report a delay</h3>
<p>Select <strong>Delayed</strong> when an underway trip is delayed. Add an optional check-in note if you want to explain the situation.</p>
<p>This pauses projected underway progress while monitoring remains active. When you resume the same leg, select <strong>On Track</strong>.</p>
<p>A Delayed check-in does not enter a specific number of minutes into <strong>Current Delay</strong>.</p>
<h3>Add or clear delay minutes</h3>
<p>Use <strong>Add Delay Time</strong> when you need to add a known number of minutes to the timing estimate.</p>
<ol><li>Find the timing controls in Active Cruise.</li><li>Enter a positive whole number of minutes.</li><li>Select <strong>Add Delay Time</strong>.</li><li>Wait for confirmation and review the refreshed estimates.</li></ol>
<p>Repeated additions accumulate in <strong>Current Delay</strong>.</p>
<p>Select <strong>Clear Delay</strong> to reset the manually entered delay total. This does not resume a Delayed leg, clear an overnight pause, complete a leg, or replace a check-in.</p>
<p>After changing delay minutes, check the arrival estimates and the displayed <strong>Next Expected Check-In</strong> separately.</p>
<h3>Set Daily Start Time</h3>
<p><strong>Daily Start Time</strong> is a local trip-time setting used for overnight resume planning and next-day monitoring. Its default is 08:00.</p>
<ol><li>Enter the intended time.</li><li>Select <strong>Save Daily Start Time</strong>.</li><li>Wait for confirmation.</li><li>Review the displayed overnight and next-check-in timing.</li></ol>
<p>Saving Daily Start Time does not itself start the vessel moving or record a morning check-in.</p>
<h3>Secure the vessel for the night</h3>
<p>When you stop overnight during an underway trip:</p>
<ol><li>Check the current <strong>Daily Start Time</strong>.</li><li>Add an optional status note if appropriate.</li><li>Select <strong>Secure Night</strong>.</li><li>Confirm that the vessel is secure.</li><li>Review <strong>Secure for Night</strong> and <strong>Next Expected Check-In</strong>.</li></ol>
<p>FPW pauses projected progress and sets the overnight monitoring checkpoint using the trip’s timezone. Overnight suppression ends at the stated checkpoint; it is not an indefinite suspension of monitoring.</p>
<p>The next morning, select <strong>On Track</strong> when you resume the same leg. Simply reaching Daily Start Time does not resume the leg.</p>
<h3>Complete a leg and start the next one</h3>
<p>At the actual end of the current leg:</p>
<ol><li>Select <strong>Complete Current Leg / Arrived</strong>.</li><li>Confirm that the current leg is complete.</li><li>Review the updated route state.</li><li>When ready to leave on the following leg, select <strong>Start Next Leg</strong>.</li></ol>
<p>Between these actions, the trip can show <strong>Awaiting Next Leg</strong>. Progress remains paused until you explicitly start the next leg.</p>
<p><strong>Start Next Leg</strong> is unavailable while another leg is underway, before the previous leg is completed, or when no pending leg remains.</p>
<p>If the current leg is paused and its completion control is unavailable, review the displayed reason. <strong>On Track</strong> resumes an existing paused leg; it does not substitute for completing it.</p>
<h3>Keep the clocks separate</h3>
<p>Your planned departure, actual departure, current-leg ETA, final-route arrival estimate, Daily Start Time, and next expected check-in answer different questions.</p>
<p>Changes to route estimates do not automatically establish a new check-in deadline. Use <strong>Next Expected Check-In</strong> as the operational reference and review it after each successful check-in or timing change.</p>
</div><a class="fpw-manual-back" href="#manualContents">Back to contents</a></section>
<section class="fpw-manual-chapter" data-manual-chapter id="21-keep-captain-notes-and-reach-your-contacts" aria-labelledby="chapter-title-21"><h2 id="chapter-title-21">21. Keep Captain Notes and Reach Your Contacts</h2><div class="fpw-manual-chapter-body">
<h3>Save a private captain note</h3>
<p>Use <strong>Quick Notes</strong> in Active Cruise for information you want to retain about the trip.</p>
<ol><li>Enter text in <strong>Add captain note</strong>.</li><li>Optionally select a preset such as <strong>All good</strong>, <strong>Underway</strong>, <strong>Weather delay</strong>, <strong>Anchored</strong>, <strong>Docking</strong>, <strong>Fuel</strong>, <strong>Mechanical</strong>, or <strong>Marina call</strong>.</li><li>Leave the sharing checkbox unchecked for a private note.</li><li>Select <strong>Save Note</strong>.</li><li>Wait for <strong>Private captain note saved.</strong></li></ol>
<p>The note field allows up to 1,200 characters. Saved notes show whether they are <strong>PRIVATE</strong> or <strong>POSTED</strong> and include a timestamp.</p>
<p>The current panel does not provide an edit or delete control for saved captain notes. Review the text before saving.</p>
<h3>Post a note to the trip page</h3>
<p>To share a captain note, select:</p>
<p><strong>Also post this note to the Trip status page voyage stream.</strong></p>
<p>The action changes to <strong>Save &amp; Post</strong>. After success, FPW reports that the note was saved and posted to the Trip status page.</p>
<p>A posted note is different from a private note. Posting does not send a status check-in, change the monitoring deadline, or send an email to everyone associated with the trip.</p>
<h3>Reach a contact</h3>
<p>The <strong>Shore Contact</strong> panel provides <strong>Call</strong>, <strong>Text</strong>, and <strong>Email</strong> links when the corresponding contact information is available.</p>
<p>These links open the relevant phone, messaging, or email application on your device. They do not themselves confirm that a call connected or a message was sent.</p>
<p><strong>Crew &amp; Passengers</strong> shows the captain/operator, passenger information, and notification-contact count. These panels are reference views. Use the appropriate FPW editing workflow to change the underlying contact or passenger information.</p>
</div><a class="fpw-manual-back" href="#manualContents">Back to contents</a></section>
<section class="fpw-manual-chapter" data-manual-chapter id="22-complete-or-cancel-your-trip" aria-labelledby="chapter-title-22"><p class="fpw-manual-part">Part VII — Finish and Review Your Trip</p><h2 id="chapter-title-22">22. Complete or Cancel Your Trip</h2><div class="fpw-manual-chapter-body">
<p>Successful completion and cancellation are different outcomes.</p>
<h3>Complete the trip safely</h3>
<p>Finishing the final route leg does not close the Float Plan automatically.</p>
<ol><li>At the actual end of the final leg, select <strong>Complete Current Leg / Arrived</strong>.</li><li>Confirm the leg’s completion.</li><li>Review the route and ensure every leg is complete.</li><li>Select <strong>Close Float Plan</strong>.</li><li>Confirm that the Float Plan can be closed.</li><li>Wait for the result.</li></ol>
<p><strong>Close Float Plan</strong> becomes available only after all route legs have been completed. If it is unavailable, review the reason and the route’s remaining leg states.</p>
<p>After successful closure, monitoring for that trip closes and the trip becomes eligible for its completed record.</p>
<p>Passing the planned return time does not close the trip. Neither does an ETA reaching the present time or a progress estimate reaching 100%.</p>
<h3>Understand safe-arrival notices</h3>
<p>After successful closure, FPW attempts safe-arrival notifications to the captain and applicable trip notification contacts.</p>
<p>The captain’s notice includes a link to the <strong>Completed Trip</strong> record. Where available for a route-backed trip, the shore-contact notice can include the completed Follow page.</p>
<p>Closing the trip and sending its notices are separate results. An email problem does not undo the closure, and closure does not guarantee that every recipient received an email.</p>
<h3>Cancel an active trip</h3>
<p>If the active trip should end without successful completion:</p>
<ol><li>Return to the Dashboard.</li><li>Find the active route/Float Plan group.</li><li>Select <strong>Cancel</strong>.</li><li>Read the confirmation explaining that this ends the active trip without requiring every leg to be complete.</li><li>Confirm only when cancellation is intended.</li><li>Wait for the cancellation result.</li></ol>
<p>Cancellation closes monitoring for that active group. It does not represent safe arrival and does not use the successful-completion notification path.</p>
<p>Do not use Cancel as a substitute for the final-leg and Close Float Plan workflow after completing the trip.</p>
</div><a class="fpw-manual-back" href="#manualContents">Back to contents</a></section>
<section class="fpw-manual-chapter" data-manual-chapter id="23-view-the-completed-trip-record" aria-labelledby="chapter-title-23"><h2 id="chapter-title-23">23. View the Completed Trip Record</h2><div class="fpw-manual-chapter-body">
<p>The captain’s safe-arrival email provides the verified entry to the owner’s <strong>Completed Trip</strong> page. Sign in to the owning FPW account when required.</p>
<p>The current Dashboard does not provide a verified Completed Trips or Trip History tab. Do not confuse a saved route with the completed operational trip record.</p>
<h3>Read the record</h3>
<p>The page includes:</p>
<ul><li><strong>Trip Identity:</strong> trip, vessel, departure, and destination information.</li><li><strong>Timing:</strong> planned departure, actual departure, planned return, and actual completion.</li><li><strong>Route Summary:</strong> available route details and counts.</li><li><strong>Completion Summary:</strong> completion and monitoring information.</li><li><strong>Shore Contact:</strong> available association information.</li><li><strong>Data Sources:</strong> explanation of the information available to this view.</li></ul>
<p>Planned and actual times remain separate. The record does not claim that the trip ended merely because the planned return time passed.</p>
<p>The displayed vessel name comes from the current associated vessel profile. Historical shore-contact details are limited because FPW does not present mutable contact information as a historical snapshot.</p>
<h3>Understand the read-only boundary</h3>
<p>This page is a completed record. It does not provide controls to edit, reopen, delete, or reuse the completed trip.</p>
<p>Use <strong>Back to Dashboard</strong> to return to normal planning. A new voyage should follow the normal planning workflow rather than attempting to reopen this record.</p>
<p>If the page says the completed trip was not found, confirm that you are signed in to the owning account and that the trip was successfully closed. A cancelled, active, or draft trip is not the same completed record.</p>
</div><a class="fpw-manual-back" href="#manualContents">Back to contents</a></section>
<section class="fpw-manual-chapter" data-manual-chapter id="24-manage-your-profile-home-port-password-and-membership" aria-labelledby="chapter-title-24"><p class="fpw-manual-part">Part VIII — Account and Reference</p><h2 id="chapter-title-24">24. Manage Your Profile, Home Port, Password and Membership</h2><div class="fpw-manual-chapter-body">
<p>Open <strong>My Account</strong> from the account menu, or use Dashboard <strong>Settings</strong>.</p>
<h3>Update your profile</h3>
<p>The <strong>Profile</strong> section shows your email, <strong>Last Login</strong>, and <strong>Last Update</strong>. Email is read-only here.</p>
<ol><li>Enter or update <strong>First Name</strong> and <strong>Last Name</strong>. Keep at least one name populated.</li><li>Enter <strong>Mobile Phone</strong> if wanted. When supplied, it must be a valid US phone number.</li><li>Choose <strong>Save Profile</strong>.</li><li>Wait for <strong>Profile saved.</strong></li></ol>
<p>Your account name identifies you as the Float Plan sender. It is separate from saved operator records and from a vessel’s onboard phone.</p>
<p>Use <strong>Refresh</strong> to reload the displayed profile. Save edits before refreshing or leaving.</p>
<h3>Set your home port</h3>
<p>The <strong>Home Port</strong> section contains:</p>
<div class="fpw-manual-table" role="region" aria-label="Reference table" tabindex="0"><table><thead><tr><th scope="col">Address information</th><th scope="col">Additional information</th></tr></thead><tbody><tr><td><strong>Street Address</strong>, <strong>City</strong>, <strong>State</strong>, <strong>ZIP</strong></td><td><strong>Phone</strong>, <strong>Latitude</strong>, <strong>Longitude</strong></td></tr></tbody></table></div>
<ol><li>Enter or update the home-port information.</li><li>Check the latitude and longitude if supplied.</li><li>Use a valid US phone number or leave <strong>Phone</strong> blank.</li><li>Choose <strong>Save Home Port</strong>.</li><li>Wait for <strong>Home port saved.</strong></li></ol>
<p>Home-port information helps FPW choose useful starting locations for maps, weather, and applicable planning fields. Continue to check each trip’s locations and schedule rather than relying on defaults.</p>
<h3>Change your password</h3>
<ol><li>Enter <strong>Current Password</strong>.</li><li>Enter <strong>New Password</strong>, using at least eight characters.</li><li>Repeat it in <strong>Confirm New Password</strong>.</li><li>Choose <strong>Change Password</strong>.</li><li>Wait for <strong>Password changed.</strong></li></ol>
<p>If FPW reports <strong>Current password is incorrect</strong>, check the current password and try again. The confirmation must match the new password.</p>
<p>If you cannot sign in, choose <strong>Forgot your password?</strong> on the sign-in page and request a reset link. The request screen uses a generic message; it does not confirm account existence or email delivery.</p>
<p>Reset links last <strong>60 minutes</strong>. A new request replaces the previous link, and a successfully used link cannot be used again. After resetting, sign in with the new password.</p>
<h3>Check membership and credits</h3>
<p>Open <strong>Membership &amp; Billing</strong> to review the access information shown for your account. Where available, this includes <strong>Planning tools</strong>, <strong>Basic sending</strong>, <strong>Premium Send Credits</strong>, and <strong>Exact active trip</strong>.</p>
<p>Available purchase choices can include <strong>Buy One Trip</strong>, <strong>Monthly Membership</strong>, and <strong>Annual Membership</strong>. If a button says <strong>Buy One Trip Unavailable</strong>, that purchase cannot currently be started.</p>
<p>Follow the displayed checkout result. <strong>Confirming your Premium Send Credit...</strong> or <strong>Confirming Premium access...</strong> means confirmation is still pending. Refresh/check Account if instructed. A purchase does not automatically send a Float Plan.</p>
<p>Use <strong>Manage Billing</strong> when it is available to open the hosted billing portal. Review the options and confirmations presented there.</p>
<h3>Redeem a code</h3>
<ol><li>Find the promotional-code section.</li><li>Enter your code.</li><li>Choose <strong>Redeem Code</strong>.</li><li>Follow the displayed result or checkout instructions.</li><li>Check the updated membership/access information.</li></ol>
<p>Codes can be unrecognized, inactive, expired, already used, or at their redemption limit. The displayed message explains the result. Do not assume that entering a code alone grants access.</p>
<p>Use <strong>Logout</strong> from the account menu when you finish on a shared device.</p>
</div><a class="fpw-manual-back" href="#manualContents">Back to contents</a></section>
<section class="fpw-manual-chapter" data-manual-chapter id="25-use-help-and-fpw-on-smaller-screens" aria-labelledby="chapter-title-25"><h2 id="chapter-title-25">25. Use Help and FPW on Smaller Screens</h2><div class="fpw-manual-chapter-body">
<p>Open <strong>Help</strong> from Dashboard to use the Help Center, or choose <strong>Open the complete member manual</strong> there to return to this guide.</p>
<p>In the web manual, use <strong>Search this manual</strong> to filter chapters by a topic or phrase. Choose <strong>Clear</strong> to restore all chapters. The contents links jump to individual chapters. Your browser's Find command can locate a word within the visible text.</p>
<p>Use <strong>Print / Save as PDF</strong> to open the browser's print dialog. The print view includes the whole manual, even if a search was active. Choose your printer or the browser's PDF destination.</p>
<h3>Guided help</h3>
<p>Dashboard <strong>Tour / Show Me Around</strong> introduces the workspace. The Route Generator's <strong>Guided Tour</strong> walks through naming a route, creating or selecting it, setting the start, adding legs and loading the timeline. Follow any Waiting prompt by completing the required action, then continue.</p>
<p>Use the instructions for the current Dashboard route workflow in this manual if an older help paragraph describes a different Basic flow.</p>
<h3>Phone and tablet use</h3>
<p>The website uses the same boating workflow on smaller screens. Open the mobile navigation menu, scroll through stacked forms, and expand a timeline or manifest summary when needed. Map clicks become taps; you can drag a waypoint marker.</p>
<p>Long tables and some maps have their own horizontal or vertical scrolling area. Review all required fields before saving. On a small screen, scroll back to an error message if an action does not complete.</p>
<p>Phone Call/Text links may open installed apps. A desktop browser may not have an appropriate handler.</p>
<p>If a session expires, sign in again before continuing. Check whether your earlier action was recorded before repeating a send or check-in. Unsaved form edits may need to be entered again.</p>
<p>For support, use the site's <strong>Contact Support</strong> link and describe the screen, action, time and exact message. Do not include a password or a private Follow Link in a general support description.</p>
</div><a class="fpw-manual-back" href="#manualContents">Back to contents</a></section>
<section class="fpw-manual-chapter" data-manual-chapter id="26-worked-boating-scenarios" aria-labelledby="chapter-title-26"><p class="fpw-manual-part">Part IX — Common Scenarios and Troubleshooting</p><h2 id="chapter-title-26">26. Worked Boating Scenarios</h2><div class="fpw-manual-chapter-body">
<p>The examples below explain which actions fit a situation. Use your own verified locations, equipment, conditions and timing. A practice click on <strong>On Track</strong> for a real active trip records departure; it is not a harmless preview.</p>
<h3>First simple day trip</h3>
<p>Prepare one vessel, an operator, a shore contact and two waypoints. Build and save the route, then open its Float Plan. Complete all six Wizard steps and save before reviewing the PDF. Choose Basic for PDF-only sharing or Premium when you need the eligible route-backed operational features.</p>
<p>For an activated Premium trip, use <strong>On Track</strong> when departing, complete the leg when actually arrived, and <strong>Close Float Plan</strong> after completion. Sending and departure are separate steps.</p>
<h3>Solo boater</h3>
<p>Save yourself as the operator and select that record in Basics. Leave passengers unselected if no one else is aboard. Select a shore contact, verify the timing and safety information, and agree how you will communicate. Your account sender name does not replace the operator selection.</p>
<h3>Passengers and crew</h3>
<p>Save the people you regularly take aboard. For this particular outing, select only those aboard in <strong>Passengers, Crew &amp; Contacts</strong>. Review the count, operator and saved PDF before sending. A saved name is not automatically part of the trip.</p>
<h3>Reuse saved locations</h3>
<p>Open My Routes, choose an existing route or create a named route, set its start and add the intended waypoint endpoints. <strong>Load</strong>, inspect the route and <strong>Save Route</strong>. Reusing locations does not mean today's schedule, weather or fuel assumptions are unchanged.</p>
<h3>Correct an unrealistic distance</h3>
<p>If the initial distance looks like a direct line across land or misses the waterway, open the leg's <strong>Edit Route</strong> map. Draw the intended path, inspect <strong>Computed NM</strong>, and <strong>Save Overrides</strong>. Review the revised time and fuel totals, then save the route. A search pin alone does not change the path.</p>
<h3>Compare time and fuel choices</h3>
<p>Verify the planner's speeds in knots and the boat's gallons-per-hour values. Compare pace, weather factor, idle time and reserve. Review travel hours, fuel and cost together. The linked Fuel Calculator is useful for a separate comparison, but its result is not saved back into your route.</p>
<h3>Plan for locks and bridges</h3>
<p>Review the relevant library records and current operating information. Expand any mapped lock details in the Cruise Timeline. If the route says <strong>No canonical lock mapping for waypoint leg</strong>, do not interpret a zero count as proof that there are no locks. Check clearance, schedules and communications separately; FPW is not automatically comparing bridge clearance with your boat.</p>
<h3>A lock wait makes you late</h3>
<p>While underway, <strong>Delayed</strong> reports a pause in progress. <strong>Add Delay Time</strong> adds whole minutes to the ETA adjustment; it does not submit a check-in. Read <strong>Next Expected Check-In</strong> and continue to meet monitoring expectations. Use <strong>On Track</strong> when the same leg resumes. Contact people ashore directly if the change affects their expectations.</p>
<h3>Secure overnight in the middle of a leg</h3>
<p>Review <strong>Daily Start Time</strong>, then choose <strong>Secure Night</strong> and confirm. Check the displayed overnight state and next expected check-in. The next morning, use <strong>On Track</strong> to resume the same leg when you actually get underway. Passing Daily Start does not resume the leg automatically.</p>
<h3>Stop between legs</h3>
<p>When you really reach a leg's endpoint, choose <strong>Complete Current Leg / Arrived</strong> and confirm. Check that the trip is awaiting the next leg. Choose <strong>Start Next Leg</strong> when you leave on the pending leg. Selecting another row in the timeline does not start it.</p>
<h3>Multi-day route</h3>
<p>During planning, set realistic <strong>Underway Hrs / Day</strong> and inspect each day rollup. During the trip, use explicit check-ins, actual leg completion and the appropriate overnight workflow. Review the displayed next checkpoint and accumulated manual delay. A day boundary in an estimate does not automatically change the operational leg.</p>
<h3>Keep family ashore informed</h3>
<p>Send the Float Plan PDF and separately use <strong>Share Follow Link → Send by Text Message / Copy Link</strong> for the active trip when available. Ask your contact to confirm access. Post a text/photo update from the Follow page, or deliberately publish a captain note. Explain that estimated progress and a green status are not live proof of location or safety.</p>
<h3>Finish the trip</h3>
<p>Complete the final leg, then choose <strong>Close Float Plan</strong> and confirm. Confirm the trip is closed rather than merely showing an ETA or 100% estimate. Safe-arrival notification is attempted after closure. The captain's safe-arrival email provides the completed-record link; tell your contact directly if you need immediate confirmation.</p>
<h3>Cancel instead of completing</h3>
<p>If the active trip is being abandoned, use Dashboard <strong>Cancel</strong> and read its confirmation. This ends the active route/Float Plan group without requiring every leg to be completed. It does not mean the voyage completed safely. Communicate the change directly to your contacts.</p>
<h3>Purchase a credit and return to a Draft</h3>
<p>Buy One Trip if that option is available. Wait for Account to confirm the credit; a checkout return can still show a pending confirmation. Reopen the intended plan from Dashboard and review it before choosing Premium Send. Buying a credit does not send. If a send already completed, use <strong>Show Original Premium Send Result</strong> instead of trying to send it again.</p>
<h3>Location is unavailable, or the display does not refresh</h3>
<p>A web check-in can succeed without GPS. Read its result and the last check-in time. If the action was accepted but the panel failed to refresh, refresh the page rather than repeating the check-in. A location marker and a status report answer different questions.</p>
<h3>Weather changes</h3>
<p>In the planner, refresh or look up the point-based weather suggestion, review it, then choose <strong>Apply Suggested</strong> if appropriate. Underway, choose the current leg's Start or End and <strong>Check Conditions</strong>; <strong>Apply Weather to Route</strong> is a separate action. A lookup alone does not change your route assumptions.</p>
<h3>Maintain saved boating information</h3>
<p>Edit the relevant vessel, operator, person, contact or waypoint, then save it. Reopen the affected editable plan to review its selections and PDF before sending. If deletion is blocked, read the plan-reference message instead of repeatedly pressing Delete. Do not assume a later profile edit rewrites a completed-trip record.</p>
</div><a class="fpw-manual-back" href="#manualContents">Back to contents</a></section>
<section class="fpw-manual-chapter" data-manual-chapter id="27-troubleshooting-and-status-reference" aria-labelledby="chapter-title-27"><h2 id="chapter-title-27">27. Troubleshooting and Status Reference</h2><div class="fpw-manual-chapter-body">
<h3>Common problems</h3>
<div class="fpw-manual-table" role="region" aria-label="Reference table" tabindex="0"><table><thead><tr><th scope="col">What you see</th><th scope="col">What to check or do</th></tr></thead><tbody><tr><td>No active trip in Active Cruise or Monitor</td><td>Confirm the trip has been activated and has the required route. A saved draft alone is not an active operational trip.</td></tr><tr><td>Premium trip access required or expired</td><td>Review the trip’s access status in FPW. Refreshing a page does not create or extend access.</td></tr><tr><td>Multiple active trips found</td><td>Resolve the conflicting active route/Float Plan state before relying on the operational view. Do not choose a trip by guesswork.</td></tr><tr><td>A status is unavailable before departure</td><td>Read the reason. On Track records actual departure; do not use it solely to unlock another status.</td></tr><tr><td>Location denied, unavailable, or timed out</td><td>Read the check-in result separately. A status check-in can succeed without location.</td></tr><tr><td>Check-in submitted but view did not refresh</td><td>Refresh the page and inspect Last Check-In before submitting again.</td></tr><tr><td>Map position looks old</td><td>Check the captured timestamp and accuracy. FPW is not continuous tracking.</td></tr><tr><td>ETA differs from expected arrival</td><td>Distinguish current-leg ETA from summary Final Arrival. Review pace, applied weather and delay settings.</td></tr><tr><td>Progress has reached 100%, but the trip remains open</td><td>Explicitly complete the leg. After every leg is complete, use Close Float Plan.</td></tr><tr><td>Start Next Leg is unavailable</td><td>Check whether the current leg is still underway, whether it was completed, and whether another leg remains.</td></tr><tr><td>Clear Delay did not resume the trip</td><td>Clear Delay only removes manual delay minutes. Use On Track to resume a paused existing leg.</td></tr><tr><td>Daily Start passed, but progress remains paused</td><td>Report the actual resumption with On Track. Time passing does not start the vessel.</td></tr><tr><td>A contact says no email arrived</td><td>Do not treat a trip or monitoring status as delivery confirmation. Communicate directly using your agreed contact method.</td></tr><tr><td>Completed record cannot be opened</td><td>Use the captain’s completed-trip email link and the owning account. Confirm successful closure rather than cancellation.</td></tr></tbody></table></div>
<h3>Trip states</h3>
<div class="fpw-manual-table" role="region" aria-label="Reference table" tabindex="0"><table><thead><tr><th scope="col">State</th><th scope="col">Meaning</th></tr></thead><tbody><tr><td><strong>Scheduled</strong></td><td>The operational trip has no actual-start evidence yet.</td></tr><tr><td><strong>Underway</strong></td><td>The current leg has been explicitly started or resumed.</td></tr><tr><td><strong>Delayed</strong></td><td>Underway progress is paused by a delay report; monitoring remains active.</td></tr><tr><td><strong>Secure for the Night</strong></td><td>The trip is paused overnight with a stated next checkpoint.</td></tr><tr><td><strong>Awaiting Next Leg</strong></td><td>A leg is complete and the next leg has not been started.</td></tr><tr><td><strong>Arrived</strong></td><td>Route legs are complete; review whether the Float Plan still needs closing.</td></tr><tr><td><strong>Closed / Completed</strong></td><td>The successful closure workflow has recorded completion.</td></tr><tr><td><strong>Cancelled</strong></td><td>The active trip was ended through cancellation, not successful arrival.</td></tr></tbody></table></div>
<h3>Monitoring states</h3>
<div class="fpw-manual-table" role="region" aria-label="Reference table" tabindex="0"><table><thead><tr><th scope="col">State</th><th scope="col">Meaning</th></tr></thead><tbody><tr><td><strong>Active</strong></td><td>Monitoring is active for the current expected checkpoint.</td></tr><tr><td><strong>Late</strong></td><td>The expected check-in time has passed.</td></tr><tr><td><strong>Missed</strong></td><td>The grace period has passed; captain notification becomes applicable.</td></tr><tr><td><strong>Escalated</strong></td><td>The missed condition has progressed to contact notification.</td></tr><tr><td><strong>Resolved</strong></td><td>A subsequent report resolved a missed or escalated condition.</td></tr><tr><td><strong>Closed</strong></td><td>Monitoring for the trip has ended.</td></tr></tbody></table></div>
<p>Trip progress and monitoring status are separate. A vessel can be delayed while monitoring remains active, or a trip can require a check-in even when its route estimates look reasonable. Read both the trip state and <strong>Next Expected Check-In</strong> when deciding what to do next.</p>
<h3>Setup, planning, sending and account questions</h3>
<div class="fpw-manual-table" role="region" aria-label="Reference table" tabindex="0"><table><thead><tr><th scope="col">What you see</th><th scope="col">What to check or do</th></tr></thead><tbody><tr><td>A saved record will not delete</td><td>Read which Float Plans reference it. Remove the association where editing is allowed; protected history may remain read-only.</td></tr><tr><td>No useful distance, or a waypoint marked [no coords]</td><td>Check saved coordinates and leg endpoints. Load the route and review its geometry before relying on totals.</td></tr><tr><td>Boat speed appears wrong after selecting a vessel</td><td>The vessel KPH labels and planner kn labels differ. Verify the values in knots in the planner; do not assume conversion.</td></tr><tr><td>No mapped locks</td><td>Missing mapping does not prove a lock-free route. Research the waterway and current operations separately.</td></tr><tr><td>Reset did not undo a route edit</td><td>Waypoint-route changes and saved geometry can persist immediately. Review the exact change and current saved route.</td></tr><tr><td>Wizard edits are missing</td><td>Next and Back do not autosave. Reopen the saved Draft; edits made after its last save may need reentry.</td></tr><tr><td>Review PDF is out of date</td><td>Save Float Plan after edits, then review the saved preview again.</td></tr><tr><td>Basic Send left the plan in Draft</td><td>That is expected for the Dashboard Wizard's PDF-only Basic Send; it does not activate monitoring.</td></tr><tr><td>Checkout finished, but the plan is not sent</td><td>Confirm access or credit in My Account, then review the intended Draft and send explicitly.</td></tr><tr><td>A send is already in progress or its completion is uncertain</td><td>Follow the result message. Do not assume no email was submitted; contact support when instructed.</td></tr><tr><td>A checkout return shows another Wizard layout</td><td>Return to Dashboard and reopen the intended plan in its six-step editor before following this guide.</td></tr><tr><td>Weather is blank or fails to update</td><td>Check location, coordinates/ZIP and the data timestamp. Missing values are not zero conditions. Try Update again for temporary failures.</td></tr><tr><td>A phone or password field fails validation</td><td>Follow the field message. Optional phone fields can be left blank; contact phone is required. Password confirmation must match.</td></tr><tr><td>A promotional code is rejected</td><td>Read the eligibility/expiry/redemption message. Entering a code does not itself establish access.</td></tr><tr><td>A private Follow page or its PDF is unavailable</td><td>Check that you used the intended trip link and that the trip's access/state still permits the view.</td></tr><tr><td>A Favorite, Privacy, or Text Link control does not perform the expected action</td><td>This guide does not rely on those incomplete controls. Use Dashboard Share Follow Link for working text/copy sharing, and do not assume a privacy setting changed.</td></tr></tbody></table></div>
<p>A welcome email may follow account creation. Password-reset requests use a generic message and do not confirm delivery. Profile and password changes show an on-screen result; do not wait for an unpromised email confirmation. Hosted billing receipts depend on the billing service; review its confirmation and your Account access.</p>
<p>If a plan says <strong>Closed</strong>, <strong>Cancelled</strong>, or <strong>Expired</strong>, do not assume it can be reopened or edited as an active trip. Use the available read-only information and the normal new-trip workflow.</p>
</div><a class="fpw-manual-back" href="#manualContents">Back to contents</a></section>
    </div>
  </div>
</main>
<cfinclude template="../includes/footer.cfm">
<cfinclude template="../includes/footer_scripts.cfm">
<script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/app/user-manual.js?v=20261004" defer></script>
</body>
</html>
