<cfif NOT structKeyExists(variables, "bhPageReady")><cfheader statuscode="404"><cfabort></cfif>
<cfoutput><p class="bh-footer-note">Planning mileage, movement time and fuel are estimates. Member confirmation records review; it does not establish independent navigation verification. Dashed map connections are schematic. Confirm current charts, approaches, conditions, permissions and services for your actual trip.</p></cfoutput>
</div>
</main>
<cfinclude template="../../includes/footer.cfm">
<cfoutput>
<script src="#bhBase#/assets/js/fpw-action-cta.js?v=20261107-guide-itinerary-auth" defer></script>
<script src="#bhBase#/assets/js/bahamas-guide.js?v=20261107-1" defer></script>
</cfoutput>
</body>
</html>


