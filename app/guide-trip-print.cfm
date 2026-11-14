<cfprocessingdirective pageencoding="utf-8">
<cfsetting showdebugoutput="false" requesttimeout="30">
<cfheader name="X-Robots-Tag" value="noindex, nofollow">
<cfheader name="Referrer-Policy" value="no-referrer">
<cfheader name="Cache-Control" value="private, no-store, no-cache, must-revalidate">
<cfinclude template="../includes/require_auth.cfm">
<cfcontent type="text/html; charset=utf-8">
<cfscript>
guidePrintRouteId = structKeyExists(url,"routeId") AND isSimpleValue(url.routeId) ? toString(url.routeId) : "";
if (!reFind("^[1-9][0-9]{0,9}$",guidePrintRouteId) OR val(guidePrintRouteId) GT 2147483647) {
  cfheader(statuscode=404);
  writeOutput("Planning draft is unavailable.");
  abort;
}
try {
  guidePrintDraft = new fpw.api.v1.GuideTripService().init("fpw").getDraft(fpwRequireAuthUserId,val(guidePrintRouteId));
  guidePrintHtml = new fpw.api.api_assets.FloatPlanPdfItineraryService().init("fpw").buildGuideSupplementHtml(guidePrintDraft, "Personal planning draft");
} catch (any guidePrintError) {
  cfheader(statuscode=404);
  writeOutput("Planning draft is unavailable.");
  abort;
}
guidePrintControls = '<div class="guide-print-controls"><a href="' & encodeForHTMLAttribute(request.fpwBase & "/app/dashboard.cfm") & '">Return to Trip Planner</a> <button type="button" id="guidePrintButton">Print planning summary</button><p>This is a planning summary, not a Float Plan. It does not send or activate a trip.</p></div>';
guidePrintHtml = replace(guidePrintHtml, "<head>", '<head><title>Trip Planning Estimates | FPW</title><meta name="viewport" content="width=device-width, initial-scale=1"><meta name="robots" content="noindex,nofollow"><style>body{max-width:1040px;margin:24px auto;padding:0 20px}.guide-print-controls{margin-bottom:24px}button,a{font:inherit}button{padding:8px 12px;margin-left:12px}a:focus-visible,button:focus-visible{outline:3px solid blue}@media print{body{margin:0;padding:0;font-size:9.5pt;line-height:1.3}h2{break-after:avoid}.guide-print-controls{display:none}}@media(max-width:600px){body{padding:0 10px}table{font-size:8pt}th,td{padding:4pt;overflow-wrap:anywhere}}</style>');
guidePrintHtml = replace(guidePrintHtml, "<body>", "<body>" & guidePrintControls);
guidePrintHtml = replace(guidePrintHtml, "</body>", '<script src="' & encodeForHTMLAttribute(request.fpwBase & "/assets/js/guide-trip-print.js?v=20261107") & '"></script></body>');
writeOutput(guidePrintHtml);
</cfscript>



