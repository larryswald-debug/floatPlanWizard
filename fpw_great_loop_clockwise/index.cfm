<cfprocessingdirective pageencoding="utf-8">
<cfsetting showdebugoutput="false">
<cfheader name="Cache-Control" value="no-store">
<cfinclude template="../includes/fpw_base_path.cfm">
<cfset request.fpwTopNavActive = "explore-legs">
<cfscript>
loopAvailable = true;
try {
    try {
        loopService = createObject("component", "api.v1.GreatLoopReferenceService").init();
    } catch (any componentPathError) {
        loopService = createObject("component", "fpw.api.v1.GreatLoopReferenceService").init();
    }
    loopModel = loopService.getModel();
} catch (any loopDataError) {
    loopAvailable = false;
    writeLog(file="fpw", type="error", text="FPW_ERROR Great Loop reference: " & loopDataError.message);
}
// Presentation-only icon assignments; itinerary sections and legs come from the template.
loopSectionIcons = {
    "Illinois Waterway"="icon_lock.svg", "Mississippi River"="icon_river.svg",
    "Ohio/Tennessee Rivers & Lakes"="icon_river.svg", "Tennessee-Tombigbee (Tenn-Tom)"="icon_lock.svg",
    "Gulf Coast (Panhandle)"="icon_waves.svg", "Florida Big Bend Crossing"="icon_compass.svg",
    "Florida West Coast"="icon_sun.svg", "Okeechobee Waterway"="icon_lock.svg",
    "Florida East Coast (ICW/Atlantic)"="icon_anchor.svg", "Georgia-Carolinas (ICW)"="icon_marsh.svg",
    "North Carolina (ICW/Sounds)"="icon_marsh.svg", "Chesapeake Bay"="icon_anchor.svg",
    "Delaware Bay & New Jersey"="icon_waves.svg", "Hudson River"="icon_river.svg",
    "Erie Canal"="icon_lock.svg", "Great Lakes Return"="icon_waves.svg"
};
</cfscript>
<cfif NOT loopAvailable><cfheader statuscode="503"></cfif>
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width,initial-scale=1" />
  <title>FPW • Great Loop (Counterclockwise Legs)</title>
  <link rel="stylesheet" href="<cfoutput>#request.fpwBase#</cfoutput>/assets/css/layout.css?v=20260620-page-width">
  <link rel="stylesheet" href="<cfoutput>#request.fpwBase#</cfoutput>/assets/css/top-nav.css?v=20261028-approved-navigation">
  <link rel="stylesheet" href="assets/css/fpw_great_loop.css?v=20261028-template-locks" />
</head>
<body class="fpw-loop-page">
  <cfinclude template="../includes/top_nav.cfm">
  <main class="fpw-loop-guide" id="main-content">
    <div class="topbar">
      <div class="brand">
        <div class="badge">
          <img src="assets/img/icon_compass.svg" alt="" />
        </div>
        <div>
          <h1>THE GREAT LOOP – COUNTERCLOCKWISE LEG LIST</h1>
          <span class="sub">Browse Great Loop legs by waterway section, or search by place name, lock name, or leg number.</span>
        </div>
      </div>

      <cfif loopAvailable><div class="controls">
        <div class="input" title="Filter legs by place name, lock name, or leg number">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><circle cx="11" cy="11" r="7"/><path d="M21 21l-4.3-4.3"/></svg>
          <input id="search" type="text" aria-label="Search Great Loop legs and locks" placeholder="Search (e.g., ‘Tarpon’, ‘Erie’, ‘36’)…" autocomplete="off" />
          <button class="btn" id="clearSearch" type="button" title="Clear search">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M18 6L6 18"/><path d="M6 6l12 12"/></svg> Clear
          </button>
        </div>

        <button class="btn" id="expandAll" type="button" title="Expand all visible sections">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M8 3H5a2 2 0 0 0-2 2v3"/><path d="M16 3h3a2 2 0 0 1 2 2v3"/><path d="M8 21H5a2 2 0 0 1-2-2v-3"/><path d="M16 21h3a2 2 0 0 0 2-2v-3"/></svg> Expand
        </button>
        <button class="btn" id="collapseAll" type="button" title="Collapse all sections">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M8 3H5a2 2 0 0 0-2 2v3"/><path d="M16 3h3a2 2 0 0 1 2 2v3"/><path d="M8 21H5a2 2 0 0 1-2-2v-3"/><path d="M16 21h3a2 2 0 0 0 2-2v-3"/><path d="M9 9h6v6H9z"/></svg> Collapse
        </button>
      </div></cfif>
    </div>

    <cfif loopAvailable>
    <cfoutput>
    <div class="meta">
      <span class="pill">Total legs: <strong id="totalCount">#loopModel.totalLegs#</strong></span>
      <span class="pill" aria-live="polite" aria-atomic="true">Visible legs: <strong id="visibleCount">#loopModel.totalLegs#</strong></span>
      <span class="pill">Direction: <strong>Counterclockwise</strong></span>
      <span class="pill">Locks: <strong id="totalLocks">#loopModel.totalLocks#</strong></span>
      <span class="pill">Est. lock time: <strong id="totalLockTime">#encodeForHTML(loopModel.lockTimeLabel)#</strong></span>
    </div>
    <p class="lockEstimateNote">Legs and locks follow the active Great Loop route template. Estimated lock time includes lockage plus typical waiting time; actual waits vary.</p>

    <div class="sections">
      <cfloop from="1" to="#arrayLen(loopModel.sections)#" index="loopSectionIndex">
        <cfset loopSection = loopModel.sections[loopSectionIndex]>
        <cfset loopSectionIcon = structKeyExists(loopSectionIcons, loopSection.name) ? loopSectionIcons[loopSection.name] : "icon_compass.svg">
        <section class="section" data-open="true">
          <div class="sectionHeader" role="button" tabindex="0" aria-expanded="true" aria-controls="loop-section-#loopSectionIndex#">
            <div class="sectionHeaderLeft">
              <div class="iconTile"><img src="assets/img/#loopSectionIcon#" alt="" /></div>
              <div class="sectionTitle">
                <h2>#loopSectionIndex#. #encodeForHTML(loopSection.name)#</h2>
                <div class="mini"><span>Counterclockwise</span><span aria-hidden="true">•</span><span>#arrayLen(loopSection.legs)# #arrayLen(loopSection.legs) EQ 1 ? 'leg' : 'legs'#</span></div>
              </div>
            </div>
            <div class="sectionHeaderRight">
              <div class="count">#arrayLen(loopSection.legs)# #arrayLen(loopSection.legs) EQ 1 ? 'leg' : 'legs'#</div>
              <div class="chev" aria-hidden="true"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M6 9l6 6 6-6"/></svg></div>
            </div>
          </div>
          <div class="sectionBody" id="loop-section-#loopSectionIndex#">
            <div class="legsGrid">
              <cfloop array="#loopSection.legs#" index="loopLeg">
                <div class="legCard" data-leg="#loopLeg.number#" data-lock-count="#loopLeg.lockCount#" data-lock-minutes="#loopLeg.hasEstimate ? loopLeg.lockMinutes : ''#" data-search="#encodeForHTMLAttribute(loopLeg.searchText)#">
                  <div class="legNum">#loopLeg.number#</div>
                  <div class="legMain">
                    <p class="legTitle">#encodeForHTML(loopLeg.title)#</p>
                    <div class="legBadges">
                      <span class="badgeTag accent">LEG</span>
                      <cfif loopLeg.lockCount GT 0><span class="badgeTag good">LOCKS/WATERWAY</span></cfif>
                      <cfif loopLeg.isOffshore><span class="badgeTag warn">OFFSHORE</span></cfif>
                      <cfif loopLeg.isICW><span class="badgeTag">ICW</span></cfif>
                    </div>
                    <div class="lockSummary"><span class="lockCount">#loopLeg.lockCount# #loopLeg.lockCount EQ 1 ? 'lock' : 'locks'#</span><span class="lockTime">Est. lock time: #encodeForHTML(loopLeg.lockTimeLabel)#</span></div>
                    <cfif arrayLen(loopLeg.locks)>
                      <details class="lockDetails">
                        <summary>Lock names <span class="lockDetailContext">for leg #loopLeg.number#</span></summary>
                        <ol class="lockNames">
                          <cfloop array="#loopLeg.locks#" index="loopLock">
                            <li><span class="lockName">#encodeForHTML(loopLock.name)#</span><span class="lockDuration">#encodeForHTML(loopLock.timeLabel)#</span></li>
                          </cfloop>
                        </ol>
                      </details>
                    <cfelseif loopLeg.lockCount GT 0>
                      <p class="lockUnavailable">Lock names and time estimates are unavailable.</p>
                    </cfif>
                  </div>
                </div>
              </cfloop>
            </div>
          </div>
        </section>
      </cfloop>
    </div>
    </cfoutput>
    <cfelse>
      <p class="lockEstimateNote" role="status">The Great Loop leg list is temporarily unavailable. Please try again later.</p>
    </cfif>
  </main>
  <cfinclude template="../includes/footer.cfm">

  <script src="assets/js/fpw_great_loop.js?v=20261028-template-locks"></script>
</body>
</html>
