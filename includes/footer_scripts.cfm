<!-- Shared footer scripts (Bootstrap bundle + shared API helper) -->
<script
  src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js"
  integrity="sha384-YvpcrYf0tY3lHB60NNkmXc5s9fDVZLESaAA55NDzOxhy9GkcIdslK1eN7N6jIeHz"
  crossorigin="anonymous"></script>

<script>
  window.GOOGLE_MAPS_API_KEY = "<cfoutput>#encodeForJavaScript(request.googleMapsApiKey)#</cfoutput>";
</script>

<script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/app/api.js"></script>
<script src="<cfoutput>#request.fpwBase#</cfoutput>/assets/js/app/auth.js"></script>


