<cfset bhIsItinerary = true>
<cfinclude template="../../_setup.cfm">
<cfinclude template="../../_head.cfm">
<cfoutput>
<nav class="bh-nav bh-nav--full-width fpw-guide-section-nav" aria-label="Worked itinerary sections">
<div class="fpw-guide-section-links">
<a href="##assumptions">Assumptions</a><a href="##sample-calculator">Sample calculator</a><a href="##stops">Stops &amp; mileage</a><a href="##enter-mileage">Review mileage</a><a href="##worksheet">Time &amp; fuel</a><a href="##flexible-days">Flexible days</a><a href="##changed-plan">Changed plan</a><a href="##sources">Sources</a>
</div>
</nav>
<section id="assumptions" aria-labelledby="assumptions-title">
<h2 id="assumptions-title">A flexible example for an experienced coastal skipper</h2>
<p>This example organizes a first Bahamas visit around a Florida staging day, an outbound movement, two local days and a return movement. Two additional days remain uncommitted for weather or a changed plan. It is a constructed itinerary, not an endorsed departure window.</p>
<div class="bh-grid"><div class="bh-panel"><h3>Make these inputs your own</h3><ul>
<li>Vessel, draft, operating limits, season, departure date and crew capability need your review.</li>
<li>Enter planning speed in <strong>knots</strong> and total-vessel consumption in <strong>US gal/h</strong>. Use the sample calculator below to explore these assumptions; review actual performance for your boat.</li>
<li>Review current charts and actual approach geometry; destination markers do not define the passage.</li>
<li>Confirm usable fuel, idle/auxiliary allowances, overnight arrangements, customs and communications.</li>
</ul></div><aside class="bh-note"><p><strong>Two distinct sets of numbers appear below.</strong></p><p>The worked example uses <strong>#bhOne(bhManifest.legs[1].distance_nm)# NM outbound and #bhOne(bhManifest.legs[2].distance_nm)# NM return</strong>: owner-supplied planning estimates for the example path and its reverse. The separate worksheet uses 60 nm each way, 120 NM total, to explain the arithmetic. The two examples use separate distances.</p><p>Every planning distance and resulting time/fuel total remains an estimate, including after review.</p></aside></div>
</section>
<section class="bh-conversion bh-conversion--strip bh-no-print" aria-labelledby="planning-cta-title">
<div><h2 id="planning-cta-title">Ready to build your own version?</h2><p>Use FPW to create your own route and adjust the stops, mileage, speed and timing for your boat.</p></div>
<a class="fpw-cta fpw-cta-primary" href="#bhBase#/app/dashboard.cfm?recoveryAction=planner">Plan Your Trip in FPW</a>
</section>
<div class="bh-photo-pair" aria-label="Dated context photographs">
<figure class="bh-photo"><img src="#bhAsset#port-everglades-960.jpg" srcset="#bhAsset#port-everglades-330.jpg 330w, #bhAsset#port-everglades-960.jpg 960w" sizes="(max-width: 700px) calc(100vw - 32px), 540px" width="960" height="720" loading="lazy" decoding="async" alt="Cruise ships and small craft in Port Everglades, photographed from above in 2017."><figcaption><strong>Florida staging context.</strong> Port Everglades, December 17, 2017. Commercial traffic belongs in departure research; this photograph does not show current conditions or the PE buoy. Photo: <a href="https://commons.wikimedia.org/wiki/File:Port_Everglades_aerial_.jpg">Port Everglades PIO</a>, <a href="https://creativecommons.org/licenses/by-sa/4.0/">CC BY-SA 4.0</a>. Wikimedia-resized copies; no crop or other alteration.</figcaption></figure>
<figure class="bh-photo"><img src="#bhAsset#alice-town-bimini-960.jpg" srcset="#bhAsset#alice-town-bimini-330.jpg 330w, #bhAsset#alice-town-bimini-960.jpg 960w" sizes="(max-width: 700px) calc(100vw - 32px), 540px" width="960" height="720" loading="lazy" decoding="async" alt="A waterfront boardwalk, palm trees and marina slips in Alice Town, Bimini, photographed in 2014."><figcaption><strong>Local-day context.</strong> Alice Town, August 17, 2014. Plan time ashore separately from movement legs; this is not a current berth or approach reference. Photo: <a href="https://commons.wikimedia.org/wiki/File:Alice_Town_Bimini_Bahamas_07.jpg">Pietro</a>, <a href="https://creativecommons.org/licenses/by-sa/4.0/">CC BY-SA 4.0</a>. Wikimedia-resized copies; no crop or other alteration.</figcaption></figure>
</div>
<section id="sample-calculator" aria-labelledby="sample-title" data-bh-sample-calculator data-bh-sample-distance="#bhTemplateDistance#">
<h2 id="sample-title">Explore the sample’s time and fuel assumptions</h2>
<p>This example keeps the sample planning mileage fixed at <strong>#bhOne(bhManifest.legs[1].distance_nm)# NM outbound and #bhOne(bhManifest.legs[2].distance_nm)# NM return</strong>, #bhOne(bhTemplateDistance)# NM total. Change the four assumptions below to see how the example estimates respond.</p>
<p id="bhSampleHelp" class="bh-meta">Sample values apply only to this page and reset when you reload it. They do not create or change routes, waypoints, vessel settings or other member data.</p>
<div class="bh-grid">
<div class="bh-panel">
<h3>Sample planning assumptions</h3>
<p><label for="bhSampleSpeed"><strong>Planning speed (knots)</strong></label><br><input id="bhSampleSpeed" type="number" min="0" step="any" required value="#bhWorksheet.planning_speed_kn#" data-bh-sample-input="speed" aria-describedby="bhSampleHelp bhSampleError"></p>
<p><label for="bhSampleBurn"><strong>Total-vessel consumption (US gal/h)</strong></label><br><input id="bhSampleBurn" type="number" min="0" step="any" required value="#bhWorksheet.underway_burn_us_gph#" data-bh-sample-input="burn" aria-describedby="bhSampleHelp bhSampleError"></p>
<p><label for="bhSampleReserve"><strong>Reserve added to base fuel (%)</strong></label><br><input id="bhSampleReserve" type="number" min="0" step="any" required value="#bhWorksheet.reserve_pct#" data-bh-sample-input="reserve" aria-describedby="bhSampleHelp bhSampleError"></p>
<p><label for="bhSampleUsable"><strong>Usable fuel aboard (US gal)</strong></label><br><input id="bhSampleUsable" type="number" min="0" step="any" required value="#bhWorksheet.usable_fuel_us_gal#" data-bh-sample-input="usable" aria-describedby="bhSampleHelp bhSampleError"></p>
<p id="bhSampleError" class="bh-note" role="alert" hidden></p>
</div>
<div class="bh-panel" aria-live="polite" aria-atomic="true">
<h3>Sample estimates for #bhOne(bhTemplateDistance)# NM</h3>
<dl>
<dt>Movement time</dt><dd><output data-bh-sample-output="time" for="bhSampleSpeed">#bhTime(bhTemplateHours)#</output></dd>
<dt>Base underway fuel</dt><dd><output data-bh-sample-output="base" for="bhSampleSpeed bhSampleBurn">#bhOne(bhTemplateBurn)# US gal</output></dd>
<dt>Added reserve</dt><dd><output data-bh-sample-output="reserve" for="bhSampleSpeed bhSampleBurn bhSampleReserve">#bhOne(bhTemplateBurn * bhWorksheet.reserve_pct / 100)# US gal</output></dd>
<dt>Total estimated fuel requirement</dt><dd><output data-bh-sample-output="required" for="bhSampleSpeed bhSampleBurn bhSampleReserve">#bhOne(bhTemplateRequired)# US gal</output></dd>
<dt>Usable fuel minus estimated requirement</dt><dd><output data-bh-sample-output="margin" for="bhSampleSpeed bhSampleBurn bhSampleReserve bhSampleUsable">#bhOne(bhWorksheet.usable_fuel_us_gal - bhTemplateRequired)# US gal</output></dd>
</dl>
<p class="bh-meta">Time = distance ÷ speed. Base fuel = time × consumption. Reserve = base fuel × reserve percentage. Total requirement = base fuel + reserve. No idle or auxiliary consumption is included.</p>
</div>
</div>
<p>These are planning estimates, not a range assurance or a departure decision. The <a href="##worksheet">separate 60 NM-per-leg worksheet</a> below keeps its original illustrative assumptions.</p>
<noscript><p class="bh-note">The initial sample estimates are shown above. Enable JavaScript to recalculate them when you change the sample values.</p></noscript>
<div class="bh-tool-cta bh-no-print">
<p>Use your own boat's speed and fuel burn to run the numbers.</p>
<a class="fpw-cta fpw-cta-primary" href="#bhBase#/boat-fuel-calculator/">Open the Fuel Calculator <span aria-hidden="true">&rarr;</span></a>
</div>
</section>
<section id="stops" aria-labelledby="stops-title">
<h2 id="stops-title">Know what each point represents</h2>
<figure class="bh-map"><p class="bh-map-help">On a narrow screen, scroll the map horizontally. <a href="#bhAsset#bimini-context.svg">Open the full port everglades and bimini reference map</a>. The table below provides the same locations.</p><div class="bh-map-scroll" role="region" tabindex="0" aria-label="Port Everglades and Bimini reference map; scroll horizontally if needed"><img src="#bhAsset#bimini-context.svg" width="1000" height="560" alt="Numbered Port Everglades and Bimini destination-reference map with a dashed schematic connection. The stop table describes both points, coordinate sources and limitations."></div><figcaption>Dashed connection = schematic relationship only. It supplies no navigable approach geometry, depth, clearance or distance. Coastlines use Natural Earth context data. The source and role of each example reference are listed below.</figcaption></figure>
<div class="bh-table-wrap" role="region" tabindex="0" aria-label="Example stop references"><table><caption>Example destination references</caption><thead><tr><th scope="col">Stop</th><th scope="col">Published coordinates &amp; role</th><th scope="col">Source and review task</th></tr></thead><tbody>
<cfset bhStopNumber = 0>
<cfloop array="#bhManifest.stops#" index="bhStop">
<cfset bhStopNumber = bhStopNumber + 1>
<tr><th scope="row">#bhStopNumber# · #encodeForHTML(bhStop.name)#</th><td><cfif structKeyExists(bhStop,'original_coordinate_text')>#encodeForHTML(bhStop.original_coordinate_text)#<cfelse>Reference pending</cfif><small>#encodeForHTML(replace(bhStop.coordinate_role,'_',' ','all'))#. Datum: #encodeForHTML(replace(bhStop.datum,'_',' ','all'))#.</small></td>
<td><cfloop array="#bhStop.source_ids#" index="bhId">#bhSource(bhId,bhSources[bhId].authority)# </cfloop>
<cfif bhStop.key EQ 'bimini'><small>Brown’s is a candidate destination, not a berth reservation or offshore approach waypoint. The source does not state coordinate datum or revision. Ask the marina about current approach conditions and review the intended path.</small>
<cfelse><small>Rounded NOAA reference published November 1, 2026; it replaces the earlier, more precise Light List value. This is not a berth or anchorage. Check current notices and review staging/harbor movements separately.</small></cfif></td></tr>
</cfloop></tbody></table></div>
<p>The selected Bimini candidate is <strong>Brown’s Marina</strong>, based on its first-party published location. This replaces the earlier Big Game Club berth candidate in this example. Brown’s page describes changing harbor sandbars and directs visitors to contact the marina. A published marina location does not validate the harbor approach.</p>
<div class="bh-table-wrap" role="region" tabindex="0" aria-label="Sample planning mileage"><table><caption>Example route distance — review for your trip.</caption><thead><tr><th scope="col">Leg</th><th scope="col">Planning mileage</th><th scope="col">Source/method and review</th></tr></thead><tbody>
<cfloop array="#bhManifest.legs#" index="bhLeg"><tr><th scope="row">#encodeForHTML(bhLeg.key EQ 'outbound' ? '1 → 2 · Outbound: Port Everglades → Brown’s Marina' : '2 → 1 · Return: Brown’s Marina → Port Everglades')#</th><td><cfif isNull(bhLeg.distance_nm)>Unset<cfelse>#bhOne(bhLeg.distance_nm)# NM estimate</cfif><small>#encodeForHTML(replace(bhLeg.distance_kind,'_',' ','all'))#</small></td><td>#encodeForHTML(bhLeg.distance_method)#<small>Review for your trip. The map connection is schematic.</small></td></tr></cfloop>
</tbody></table></div>
<div class="bh-note"><p><strong><cfif bhTemplateMissingLegs>Known-leg subtotal: #bhOne(bhTemplateDistance)# NM — incomplete.<cfelse>Example route distance total: #bhOne(bhTemplateDistance)# NM — review for your trip.</cfif></strong> The distances are owner-supplied planning estimates, not independently verified route lengths. The return uses the same example path in reverse. Measurement method, chart source and date are unspecified. Review each leg for an actual trip.</p><p>The sample calculator above uses this #bhOne(bhTemplateDistance)# NM total. <cfif bhTemplateMissingLegs EQ 0>At the worksheet’s illustrative #bhWorksheet.planning_speed_kn# kn and #bhWorksheet.underway_burn_us_gph# US gal/h, these #bhOne(bhTemplateDistance)# NM produce <strong>#bhTime(bhTemplateHours)#</strong>, <strong>#bhOne(bhTemplateBurn)# US gal</strong> base consumption and <strong>#bhOne(bhTemplateRequired)# US gal</strong> including #bhWorksheet.reserve_pct#% added reserve. These initial operating assumptions are illustrative; review actual performance for your boat.<cfelse>Missing mileage prevents a complete-trip time or fuel estimate.</cfif></p></div>
<p>#bhSource("S8","Big Game Club’s 47.6 nm published approach comparison")# describes different references and links to a chart dated 2009. It is neither a current berth-to-berth validation nor a distance for the PE buoy–Brown’s Marina pair. It stays separate from both the sample legs and the illustrative worksheet.</p>
</section>
<section id="enter-mileage" aria-labelledby="mileage-title">
<h2 id="mileage-title">Review mileage for the route you intend to travel</h2>
<p>The sample uses #bhOne(bhManifest.legs[1].distance_nm)# NM outbound and #bhOne(bhManifest.legs[2].distance_nm)# NM return, labeled “Example route distance — review for your trip.” These owner-supplied estimates have no documented measurement method, chart source or measurement date. A straight line between the reference points, the marina’s Miami distance and the separate 60 nm worksheet are not mileage sources for these legs.</p>
<ol class="bh-steps">
<li><strong>Define the movement.</strong> Check the example’s endpoints against your intended departure and arrival. The PE buoy reference excludes travel from your Florida berth. Include any staging or harbor movements, and account for changed endpoints before measuring.</li>
<li><strong>Measure a reviewed water path.</strong> In current charting or route-planning tools, plot the passage and harbor approach your skipper intends to use. Check source dates, depth/draft constraints and local information. Record that tool’s route-distance result in nautical miles; do not measure this page’s dashed schematic line. FPW does not independently validate the plotted path.</li>
<li><strong>Review the resulting estimates.</strong> Use your actual distance, speed, consumption and reserve assumptions when planning your own trip. You can use FPW’s Route Generator to build your own Bahamas route and draw its geometry independently of this guide’s sample.</li>
</ol>
<p>Review the affected leg again after changing endpoints, mileage or geometry. The sample mileage does not create or validate a navigable map line.</p>
</section>
<section id="worksheet" aria-labelledby="worksheet-title">
<h2 id="worksheet-title">Illustrative time and fuel worksheet</h2>
<p><strong>#encodeForHTML(bhWorksheet.label)#.</strong> This arithmetic example assumes #bhOne(bhWorksheet.legs[1].distance_nm)# nm for each movement. These distances are not sourced route lengths for the example’s endpoints.</p>
<div class="bh-grid"><div class="bh-panel"><h3>Explicit assumptions</h3><ul>
<li>Speed: <strong>#bhWorksheet.planning_speed_kn# kn</strong>; total-vessel underway consumption: <strong>#bhWorksheet.underway_burn_us_gph# US gal/h</strong>.</li>
<li>Nominal fuel aboard: 200 US gal; unusable: 10 US gal; usable aboard: <strong>#bhOne(bhWorksheet.usable_fuel_us_gal)# US gal</strong>.</li>
<li>Idle and auxiliary allowance: <strong>0 US gal</strong> in this illustration; add the actual allowance when applicable.</li>
<li>Reserve: <strong>#bhWorksheet.reserve_pct#% added to base consumption</strong>, applied once.</li>
<li>One knot is one nautical mile per hour. One nautical mile is 1,852 metres.</li>
</ul></div><div><h3>The calculation</h3><p>Movement time = planning distance ÷ speed.<br>Underway fuel = movement time × total-vessel consumption.<br>Reserve = base consumption × #bhWorksheet.reserve_pct#%.<br>Required quantity = base consumption + reserve.</p><p>Calculate at full precision, then display distance and fuel to one decimal and time to the nearest minute. These results are estimates and do not decide whether a crossing is safe.</p></div></div>
<div class="bh-table-wrap" role="region" tabindex="0" aria-label="Illustrative movement calculation"><table><caption>Illustrative estimates — constructed worksheet assumptions</caption><thead><tr><th scope="col">Movement</th><th scope="col">Distance estimate</th><th scope="col">Time estimate</th><th scope="col">Fuel estimate</th></tr></thead><tbody>
<cfloop array="#bhWorksheet.legs#" index="bhWLeg"><tr><th scope="row">#encodeForHTML(bhWLeg.key EQ 'outbound' ? 'Outbound illustration' : 'Return illustration')#</th><td class="bh-number">#bhOne(bhWLeg.distance_nm)# nm</td><td class="bh-number">#bhTime(bhWLeg.distance_nm / bhWorksheet.planning_speed_kn)#</td><td class="bh-number">#bhOne(bhWLeg.distance_nm / bhWorksheet.planning_speed_kn * bhWorksheet.underway_burn_us_gph)# US gal</td></tr></cfloop>
<tr><th scope="row">Local days</th><td colspan="3">Notes only; no boat excursion or fuel consumption assumed</td></tr>
<tr><th scope="row">Movement total estimate</th><td class="bh-number">#bhOne(bhWDistance)# nm</td><td class="bh-number">#bhTime(bhWHours)#</td><td class="bh-number">#bhOne(bhWBurn)# US gal</td></tr>
</tbody></table></div>
<p>Reserve estimate: #bhOne(bhWBurn)# × #bhWorksheet.reserve_pct#% = <strong>#bhOne(bhWReserve)# US gal</strong>.<br>Estimated required departure quantity: #bhOne(bhWBurn)# + #bhOne(bhWReserve)# = <strong>#bhOne(bhWRequired)# US gal</strong>.<br>Usable fuel above that calculation: #bhOne(bhWorksheet.usable_fuel_us_gal)# − #bhOne(bhWRequired)# = <strong>#bhOne(bhWorksheet.usable_fuel_us_gal - bhWRequired)# US gal</strong>.</p>
<p>The percentage is not also subtracted from capacity. These results do not include a fuel-stop assumption or an assurance of range in actual conditions.</p>
<h3>A slower operating-point comparison</h3>
<p>Independently assume #bhWorksheet.slow_speed_kn# kn and #bhWorksheet.slow_burn_us_gph# US gal/h for the same #bhOne(bhWDistance)# illustrative nm. The resulting estimate is <strong>#bhTime(bhSlowHours)#</strong>, <strong>#bhOne(bhSlowBurn)# US gal</strong> base burn and <strong>#bhOne(bhSlowBurn * (1 + bhWorksheet.reserve_pct / 100))# US gal</strong> including reserve. The consumption rate is an assumption for that operating point, not a claim about the effect of slowing every boat.</p>
<figure class="bh-figure bh-figure--compact"><img src="#bhAsset#time-fuel-comparison.svg" width="560" height="620" loading="lazy" alt="Illustrative comparison: 20 knots at 18 US gallons per hour takes 6 hours and 129.6 US gallons including reserve; 7 knots at 4 US gallons per hour takes 17 hours 9 minutes and 82.3 US gallons."><figcaption>Same illustrative mileage; independently supplied performance assumptions. Separate time and fuel scales. The visible worksheet supplies the exact values and reserve method.</figcaption></figure>
</section>
<section id="flexible-days" aria-labelledby="days-title"><h2 id="days-title">Keep the timetable flexible</h2><p>These are planning notes, not scheduled laydays or a forecast. Two local days and two additional waiting days do not guarantee a workable weather window.</p>
<ol class="bh-timeline"><cfloop array="#bhManifest.days#" index="bhDay"><li class="#listFindNoCase('local,weather',bhDay.kind) ? 'bh-flex' : ''#"><strong>#encodeForHTML(bhDay.label)#</strong>#encodeForHTML(bhDay.description)#</li></cfloop></ol>
<p>Choose a departure date only after the route, vessel, crew, current forecast, arrival conditions and alternatives have been considered together. Use the <a href="#bhHub###florida-crossing">crossing source checklist</a> and <a href="#bhHub###entry-and-return">entry/return checklist</a>.</p>
</section>
<section id="changed-plan" aria-labelledby="changed-title"><h2 id="changed-title">When the plan changes</h2>
<div class="bh-grid"><div class="bh-panel"><h3>Return delayed and mileage revised</h3><p>The return is delayed two days. After reviewing the intended path, the skipper changes the return planning allowance from #bhOne(bhWorksheet.legs[2].distance_nm)# to #bhOne(bhWorksheet.revised_return_distance_nm)# nm and records the method. In this separate illustration:</p>
<ul><li>Movement distance estimate: <strong>#bhOne(bhChangedDistance)# nm</strong></li><li>Movement time estimate: <strong>#bhTime(bhChangedHours)#</strong></li><li>Base fuel estimate: <strong>#bhOne(bhChangedBurn)# US gal</strong></li><li>Estimated quantity including reserve: <strong>#bhOne(bhChangedBurn * (1 + bhWorksheet.reserve_pct / 100))# US gal</strong></li></ul>
<p>Review the changed leg again. Reconsider accommodation, provisions, clearance validity, auxiliary fuel and shore-contact expectations.</p></div>
<div class="bh-panel"><h3>Return mileage has no defensible basis</h3><p>Treat the worksheet as incomplete. If only the illustrative outbound #bhOne(bhWorksheet.legs[1].distance_nm)# nm is known, the known portion is:</p><p class="bh-note"><strong>Known-leg subtotal: #bhOne(bhWorksheet.legs[1].distance_nm)# nm, #bhTime(bhWorksheet.legs[1].distance_nm / bhWorksheet.planning_speed_kn)#, #bhOne(bhWorksheet.legs[1].distance_nm / bhWorksheet.planning_speed_kn * bhWorksheet.underway_burn_us_gph)# US gal — incomplete; return mileage missing.</strong></p><p>This subtotal is not a complete-trip fuel requirement. Keep an unknown movement distance separate from a complete-trip estimate until it has a defensible basis.</p></div></div>
<h3>When should you review a leg again?</h3><p>Recheck a leg after changing an endpoint, coordinates, distance, geometry or stop order. Review every added leg. Editing or saving a route does not independently verify navigation.</p>
</section>
<section id="review-tasks" aria-labelledby="review-title"><h2 id="review-title">Your review before the Float Plan workflow</h2>
<ul class="bh-checklist"><li>Confirm the exact endpoint pair and current approach information for every movement.</li><li>Review or replace each leg’s owner-supplied mileage and record its actual source or calculation method; leave unknown details unspecified.</li><li>Confirm speed in knots and total-vessel US gal/h, reserve mode, usable fuel and relevant allowances.</li><li>Explicitly confirm or replace every leg’s current mileage; review again after changes.</li><li>Review the saved route and schedule before progressing into Float Plan creation.</li><li>Confirm the shore contact understands changes, expected updates and the reporting plan.</li></ul>
<div class="bh-actions"><button type="button" class="fpw-secondary-cta" data-bh-print>Print this worked example</button><a href="#bhHub#" class="fpw-secondary-cta">Back to the Bahamas guide</a></div><p class="bh-meta">This is the public example’s print view. It contains no personal trip data, continuation tokens or private route identifiers.</p>
</section>
<section class="bh-conversion bh-conversion--final bh-no-print" aria-labelledby="final-cta-title">
<p class="bh-eyebrow">READY TO BUILD YOUR OWN TRIP?</p>
<h2 id="final-cta-title">Take the next step in FloatPlanWizard.</h2>
<p>Build your own route, use your boat's real performance numbers, then create the float plan you will actually use for the trip.</p>
<div class="bh-actions">
<a class="fpw-cta fpw-cta-primary" href="#bhBase#/app/dashboard.cfm?recoveryAction=planner">Build Your Route</a>
<a class="fpw-secondary-cta" href="#bhBase#/app/dashboard.cfm?recoveryAction=plans">Create a Float Plan</a>
</div>
</section>
<section id="sources" class="bh-sources" aria-labelledby="sources-title"><h2 id="sources-title">Sources, dates and limitations</h2><p>Retrieval confirms what a source says. It does not confirm navigation, current berthing or stock. Published coordinate datum and revision are retained where stated; missing metadata remains explicitly missing.</p>
<ul><cfloop array="#['S18','S10b','S10','S10a','S8','S9','S1','S3','S3a','S3b','S5','S5a','S5b','S6','S6a','S6b','S7','S16','S16a']#" index="bhId"><li>#bhSource(bhId,bhSources[bhId].authority & ' — ' & bhSources[bhId].topic)#<small>#encodeForHTML(bhSources[bhId].claim)# Accessed #encodeForHTML(bhSources[bhId].accessed_at)#. #encodeForHTML(bhSources[bhId].effective_date)#. Status: #encodeForHTML(replace(bhSources[bhId].verification_status,'_',' ','all'))#.</small></li></cfloop></ul>
</section>
</cfoutput>
<cfinclude template="../../_footer.cfm">
