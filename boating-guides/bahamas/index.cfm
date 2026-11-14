<cfset bhIsItinerary = false>
<cfinclude template="_setup.cfm">
<cfinclude template="_head.cfm">
<cfoutput>
<nav class="bh-nav fpw-guide-section-nav" aria-label="Bahamas guide sections">
<div class="fpw-guide-section-links">
<a href="##regions">Choose an area</a><a href="##florida-crossing">Crossing</a><a href="##entry-and-return">Entry &amp; return</a><a href="##fuel-provisioning-communications">Fuel &amp; logistics</a><a href="##worked-trip">Worked trip</a><a href="##checklist">Checklist</a>
</div>
</nav>
<section id="regions" aria-labelledby="regions-title">
<h2 id="regions-title">Start with one cruising area</h2>
<p>A first trip becomes easier to revise when it has a clear arrival area, a workable return and a few optional local days. Choose your region before building a list of distant stops. Research each actual approach, overnight arrangement and service separately.</p>
<figure class="bh-map"><p class="bh-map-help">On a narrow screen, scroll the map horizontally. <a href="#bhAsset#regional-overview.svg">Open the full bahamas regional overview</a>. The table below provides the same locations.</p><div class="bh-map-scroll" role="region" tabindex="0" aria-label="Bahamas regional overview; scroll horizontally if needed"><img src="#bhAsset#regional-overview.svg" width="1000" height="700" alt="Numbered geographic overview of Bimini, Grand Bahama, the Abacos, Berry Islands, Eleuthera and the Exumas. The equivalent regional comparison is below."></div>
<figcaption>Geographic context, north up. Natural Earth public-domain country and minor-island data; GeoNames location labels. Markers represent regional labels, not navigational waypoints. No chart depths, passages or route geometry are shown.</figcaption>
</figure>
<nav class="bh-region-links" aria-label="Regional comparisons">
<a href="##bimini" data-bh-region="bimini">1 · Bimini</a><a href="##grand-bahama" data-bh-region="grand-bahama">2 · Grand Bahama</a><a href="##abacos" data-bh-region="abacos">3 · Abacos</a><a href="##berry-islands" data-bh-region="berry-islands">4 · Berry Islands</a><a href="##eleuthera" data-bh-region="eleuthera">5 · Eleuthera</a><a href="##exumas" data-bh-region="exumas">6 · Exumas</a><a href="##andros" data-bh-region="andros">Andros</a>
</nav>
<div class="bh-table-wrap" role="region" tabindex="0" aria-label="Regional planning comparison, scroll horizontally if needed">
<table><caption>Questions to resolve before choosing a region</caption>
<thead><tr><th scope="col">Region</th><th scope="col">Planning focus</th><th scope="col">First confirmation task</th></tr></thead>
<tbody>
<tr><th scope="row">1 · Bimini</th><td>A flexible Florida crossing and local stay</td><td>Arrival reference, harbor approach, clearance and a separate berth/fuel plan</td></tr>
<tr><th scope="row">2 · Grand Bahama</th><td>Compare West End and Freeport arrival areas</td><td>Exact entry destination and current clearance/service arrangements</td></tr>
<tr><th scope="row">3 · Abacos</th><td>Choose a manageable stop cluster</td><td>Current local approaches, services and exposure along the chosen legs</td></tr>
<tr><th scope="row">4 · Berry Islands</th><td>Research Great Harbour Cay and alternatives</td><td>Access and overnight availability; do not assume Chub Cay access</td></tr>
<tr><th scope="row">5 · Eleuthera</th><td>Choose between distinct cruising areas</td><td>Approach research and local assistance where appropriate</td></tr>
<tr><th scope="row">6 · Exumas</th><td>Combine flexible legs with provisioning and park research</td><td>Mooring/anchoring rules and a plan that works without a guaranteed mooring</td></tr>
</tbody></table></div>
<div class="bh-grid"><div>
<div id="bimini" class="bh-region"><h3>1 · Bimini: separate arrival, berth and fuel</h3>
<p>The worked example starts with Port Everglades and Bimini. Treat an arrival reference, a marina destination and a confirmed berth as different things. Research the harbor approach with current charts and local information before selecting your path. #bhSource("S9","Big Game Club’s FAQ")# says its marina has no fuel; a berth there would require a separate fueling plan.</p><p><a href="#bhItinerary#">Explore the Fort Lauderdale–Bimini worked trip</a>.</p></div>
<div id="grand-bahama" class="bh-region"><h3>2 · Grand Bahama: name the arrival area</h3>
<p>West End and Freeport are different planning choices. Compare the exact arrival location, clearance arrangements and onward legs instead of entering a generic island name as a route endpoint. Begin with <a href="https://www.bahamas.com/islands/freeport-grand-bahama-island">official Grand Bahama information</a> and the chosen operator’s current instructions.</p></div>
<div id="abacos" class="bh-region"><h3>3 · Abacos: plan a cluster, then the connection</h3>
<p>Choose the stops that matter to your crew, then examine each connecting passage and the services you actually need. Keep exposed connections and alternate overnight choices visible in the plan. <a href="https://www.bahamas.com/islands/abacos">Official Abacos information</a> supports regional discovery; confirm operational details with individual facilities.</p></div>
</div><div>
<div id="berry-islands" class="bh-region"><h3>4 · Berry Islands: confirm access before counting a stop</h3>
<p>A named marina is not an assured overnight option. #bhSource("S12","Chub Cay’s visitor information")# and current membership terms require an access check. Compare <a href="https://greatharbourcay.com/marina">Great Harbour Cay’s marina information</a> with the services and arrival arrangements your boat needs.</p></div>
<div id="eleuthera" class="bh-region"><h3>5 · Eleuthera and Harbour Island: choose the actual area</h3>
<p>Do not use a single island marker as an arrival waypoint. Use <a href="https://www.bahamas.com/islands/eleuthera-harbour-island">official regional information</a> to narrow your choices, then investigate the approach, berth and local assistance for the selected destination.</p></div>
<div id="exumas" class="bh-region"><h3>6 · Exumas: keep the park plan flexible</h3>
<p>#bhSource("S14","Bahamas National Trust’s park payment policy")# does not guarantee a mooring through payment or reservation. Build an alternative into the itinerary. #bhSource("S13","Staniel Cay Yacht Club’s service information")# is a starting point for provisioning research; confirm current availability directly.</p></div>
</div></div>
<div id="andros" class="bh-region"><h3>Andros and other cruising areas</h3><p>Keep regions outside the first example as research choices, not invented route templates. <a href="https://www.bahamas.com/islands/andros">Official Andros information</a> helps identify an area to investigate. The same endpoint, approach, fuel, communications and contingency questions apply.</p></div>
</section>
<section id="florida-crossing" aria-labelledby="crossing-title">
<h2 id="crossing-title">Plan a crossing with room to wait</h2>
<div class="bh-grid"><div>
<p>Define the Florida departure reference and Bahamas destination before comparing distances. A marina-to-marina movement includes different water from an offshore-reference comparison. Do not transfer another publisher’s number onto different endpoints.</p>
<p>The Gulf Stream is a moving-water consideration. Wind, waves, current, passage duration and crew limits belong in the same decision. #bhSource("S7","NWS explains the Gulf Stream")#; consult current #bhSource("S6","NWS Miami marine products")#, #bhSource("S6a","National Hurricane Center marine products")# and #bhSource("S6b","Bahamas Department of Meteorology forecasts")# for the waters and period involved.</p>
<ul><li>Record forecast issuance and valid times, not just a screenshot.</li><li>Work back from daylight arrival and the route your skipper has reviewed.</li><li>Keep a departure delay, shortened stay and later return as real options.</li><li>Recheck the return crossing independently; the outbound decision does not approve it.</li></ul>
</div><aside class="bh-panel"><h3>A comparison is only as useful as its endpoints</h3><p>#bhSource("S8","Big Game Club publishes a 47.6 nm approach comparison")#. Its linked chart is dated 2009 and the stated offshore reference points do not define a full berth-to-berth passage. That number is not used as mileage for this guide’s personal-copy template.</p><p>The example imports owner-supplied estimates totaling #bhOne(bhTemplateDistance)# NM; review each leg for your trip. Missing mileage still remains unset if you clear a value. The separate <a href="#bhItinerary###worksheet">120 NM worksheet</a> demonstrates arithmetic only.</p></aside></div>
<figure class="bh-figure bh-figure--compact"><img src="#bhAsset#crossing-decisions.svg" width="560" height="500" loading="lazy" alt="Schematic crossing decision diagram: consider wind and waves, current, passage duration and a waiting alternative together. It supplies no forecast or course compensation."><figcaption>Original FPW schematic based on NWS Gulf Stream context. It is not to scale, a current model or an automatic crossing-safety decision.</figcaption></figure>
</section>
<section id="entry-and-return" aria-labelledby="entry-title">
<h2 id="entry-title">Prepare entry and U.S. return before departure</h2>
<p>Use the authorities’ current instructions for your vessel and everyone aboard. Keep the document checklist useful even when fees or eligibility change. No fee table is reproduced here.</p>
<div class="bh-grid"><div class="bh-panel"><h3>Bahamas arrival</h3><ol>
<li>Assemble vessel registration, identity/travel documents, crew details and the information required for your actual vessel and visit.</li>
<li>Check an appropriate port of entry in #bhSource("S1","official Bahamas boating regulations")#. Use #bhSource("S3b","Customs’ current offices and ports directory")# to confirm Bimini arrival arrangements before departure.</li>
<li>Use #bhSource("S3","Bahamas Customs’ pleasure-vessel clearance instructions")# and its #bhSource("S3a","recent-updates notice")# for the current digital application/payment process and in-person Customs approval.</li>
<li>Check current charges, permit duration, re-entry conditions and any fishing permissions directly with Customs. Keep the approved documents available.</li>
</ol><p class="bh-meta">The Customs page contains conflicting legacy/manual passages. Its newer linked August 2026 notice and September office directory were retrieved again on November 9, 2026. Historical fee-change dates and unresolved details are omitted.</p></div>
<div class="bh-panel"><h3>Returning to the United States</h3><p>#bhSource("S5","CBP’s pleasure-boat arrival guidance")# says operators returning from a foreign place must report arrival immediately. Before leaving the Bahamas, confirm the procedure for your vessel, everyone aboard and your intended U.S. arrival location.</p><p>Check #bhSource("S5a","CBP’s ROAM guidance")# for current eligibility and procedure and obtain the relevant port’s reporting alternative. The detailed ROAM and Florida reporting pages returned access errors during the November 9 check. Use #bhSource("S5b","CBP’s general information contact")# before travel to obtain the intended port’s instructions if those pages remain unavailable. A general inquiry is not an arrival report. Do not assume app eligibility, remote approval or completion of formalities.</p><h3>Activities and restrictions</h3><p>Check #bhSource("S4","official fishing guidance")# and destination-specific restrictions before planning an activity. Park rules, customs permission and a marina reservation address different requirements.</p></div></div>
</section>
<section id="fuel-provisioning-communications" aria-labelledby="logistics-title">
<h2 id="logistics-title">Make fuel, provisions and communications explicit</h2>
<div class="bh-grid"><div>
<h3>Use your boat’s operating point</h3><p>Enter speed in <strong>knots</strong> and total-vessel underway consumption in <strong>US gallons per hour</strong>. A per-engine burn rate, a speed in kilometres per hour or nominal tank capacity cannot be silently substituted. Confirm usable fuel and add realistic idle or auxiliary allowances.</p>
<p>The <a href="#bhBase#/boat-fuel-calculator/">boat fuel calculator</a> can help explore assumptions. The guide example uses a clearly stated 20% added reserve; it applies the reserve once. A calculation is not a finding that a crossing is safe or that fuel will be available.</p>
<h3>Confirm services directly</h3><p>Record the supplier, access requirements, operating hours and last confirmation for intended fuel, water and overnight stops. A facility list is a research lead. Carry a plan that does not depend on an unconfirmed delivery or berth.</p>
</div><aside class="bh-panel"><h3>Allow for the days you might wait</h3><ul class="bh-checklist"><li>Water, food, medications and waste capacity for extra days</li><li>Vessel/crew limits, draft and season-specific research</li><li>Working communications and a fallback beyond assumed mobile coverage</li><li>Documents and permission duration if the return changes</li><li>A shore contact who understands the revised plan</li></ul><p><a href="#bhBase#/shore-contact-overdue-boater/">Read the shore-contact guide</a> and agree how updates will be communicated.</p></aside></div>
</section>
<section id="worked-trip" aria-labelledby="example-title">
<h2 id="example-title">Work through one trip, including the changed plan</h2>
<div class="bh-panel"><p class="bh-eyebrow">First worked example</p><h3>Fort Lauderdale to Bimini</h3><p>A Florida staging day, outbound movement, two local days, return movement and two uncommitted weather days. Review the template’s editable owner-supplied distance estimates, keep the separate 120 NM time/fuel worksheet distinct, then see what changes when the return is delayed or longer.</p>
<div class="bh-actions"><a class="fpw-cta fpw-cta-primary" href="#bhItinerary#">Explore the worked trip</a></div>
<p>When released, <strong>Use this itinerary</strong> creates an editable personal copy in My Routes. Movement legs transfer to Trip Planner; local days and weather allowances transfer as notes. Each leg needs the member’s mileage review before the Float Plan workflow.</p></div>
</section>
<section id="checklist" aria-labelledby="checklist-title">
<h2 id="checklist-title">Before this becomes your trip</h2>
<ul class="bh-checklist"><li>Choose exact departure and destination references and research the entire intended path.</li><li>Record a source or reproducible calculation method for each leg’s planning mileage.</li><li>Enter speed in knots and total underway consumption in US gal/h; confirm usable fuel and reserve mode.</li><li>Review approach, draft, weather, daylight, clearance, overnight and service constraints.</li><li>Replace or explicitly confirm each leg’s mileage. Your review is not independent navigation verification.</li><li>Recheck affected legs after any endpoint, mileage, source or geometry change.</li><li>Keep missing values unset and partial totals labeled incomplete; save unfinished work as a planning draft.</li><li>Review the completed trip and keep shore-contact expectations current.</li></ul>
<div class="bh-actions"><button type="button" class="fpw-secondary-cta" data-bh-print>Print this guide</button></div>
</section>
<section id="sources" class="bh-sources" aria-labelledby="sources-title"><h2 id="sources-title">Sources and what was checked</h2>
<p>“Retrieved” means the source was accessible and supported the described information. It does not confirm safe passage, an available berth, fuel stock or an independently verified route. Regulatory and service facts need a fresh check before use.</p>
<ul>
<cfloop array="#['S1','S3','S3a','S3b','S5','S5a','S5b','S6','S6a','S6b','S7','S8','S9','S12','S13','S14','S16','S16a','S16b']#" index="bhId">
<li>#bhSource(bhId,bhSources[bhId].authority & ' — ' & bhSources[bhId].topic)#<small>#encodeForHTML(bhSources[bhId].claim)# Accessed #encodeForHTML(bhSources[bhId].accessed_at)#. Status: #encodeForHTML(replace(bhSources[bhId].verification_status,'_',' ','all'))#.</small></li>
</cfloop></ul>
<p>Geographic assets are original FPW renderings of <a href="https://www.naturalearthdata.com/about/terms-of-use/">Natural Earth public-domain data</a>, with <a href="https://www.geonames.org/export/">GeoNames attribution</a>. No proprietary chart image or paid tile service is used.</p>
</section>
</cfoutput>
<cfinclude template="_footer.cfm">


