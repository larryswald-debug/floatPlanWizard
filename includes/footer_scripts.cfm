<!-- Shared footer scripts (Bootstrap bundle + shared API helper) -->
<script
  src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js"
  integrity="sha384-YvpcrYf0tY3lHB60NNkmXc5s9fDVZLESaAA55NDzOxhy9GkcIdslK1eN7N6jIeHz"
  crossorigin="anonymous"></script>

<cfif NOT structKeyExists(request, "fpwApiScriptRendered")>
  <cfset request.fpwApiScriptRendered = true>
  <script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/app/api.js?v=20261001-unified-auth"></script>
</cfif>
<cfif NOT structKeyExists(request, "fpwAuthScriptRendered")>
  <cfset request.fpwAuthScriptRendered = true>
  <script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/app/auth.js?v=20261001-unified-auth"></script>
</cfif>
