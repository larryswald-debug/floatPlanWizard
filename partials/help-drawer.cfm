<cfif NOT structKeyExists(request, "fpwHelpDrawerRendered")>
  <cfset request.fpwHelpDrawerRendered = true>
  <cfoutput>
  <link rel="stylesheet" href="#encodeForHTMLAttribute(topNavBasePath)#/assets/css/help-drawer.css?v=20261014-1">
  <dialog id="fpwHelpDrawer" class="fpw-help-drawer" aria-labelledby="fpwHelpDrawerTitle" aria-modal="true" data-manual-url="#encodeForHTMLAttribute(topNavBasePath)#/app/user-manual.cfm">
    <header class="fpw-help-drawer__header">
      <h2 id="fpwHelpDrawerTitle">Help for this page</h2>
      <button type="button" class="fpw-help-drawer__close" data-help-close aria-label="Close page help">Close <span aria-hidden="true">&times;</span></button>
    </header>
    <div class="fpw-help-drawer__scroll" data-help-scroll tabindex="0" role="region" aria-label="Help content">
      <p class="fpw-help-drawer__status" data-help-status role="status" aria-live="polite"></p>
      <button type="button" class="fpw-help-drawer__retry" data-help-retry hidden>Try again</button>
      <div class="fpw-help-manual" data-help-content></div>
    </div>
    <footer class="fpw-help-drawer__footer">
      <a data-help-full href="#encodeForHTMLAttribute(topNavBasePath)#/app/user-manual.cfm" target="_blank" rel="noopener">Open full manual (new tab)</a>
      <p>Links to other pages open in a new tab.</p>
    </footer>
  </dialog>
  <script src="#encodeForHTMLAttribute(topNavBasePath)#/assets/js/app/help-drawer.js?v=20261014-1" defer></script>
  </cfoutput>
</cfif>
