<cfprocessingdirective pageencoding="utf-8">
<cfsetting showdebugoutput="false" requesttimeout="30">
<cfcontent type="text/html; charset=utf-8">
<cfinclude template="../../includes/fpw_base_path.cfm">
<cfparam name="bhIsItinerary" default="false">
<cfscript>
// The immutable editorial manifest is the only source for template facts and worked inputs.
bhManifest = deserializeJSON(fileRead(expandPath(request.fpwBase & "/publishing/bahamas/templates/fort-lauderdale-bimini-v1.json"), "utf-8"));
bhRegister = deserializeJSON(fileRead(expandPath(request.fpwBase & "/publishing/bahamas/sources.json"), "utf-8"));
bhSources = {};
for (bhEntry in bhRegister.sources) bhSources[bhEntry.id] = bhEntry;
bhBase = request.fpwBase;
bhHub = bhBase & "/boating-guides/bahamas/";
bhItinerary = bhHub & "itineraries/fort-lauderdale-bimini/";
bhAsset = bhBase & "/assets/images/boating-guides/bahamas/";
bhPublished = bhManifest.status EQ "published" AND structKeyExists(bhManifest, "verification") AND bhManifest.verification.publication_ready;
bhTitle = bhIsItinerary ? bhManifest.title : "Bahamas Cruising and Trip Planning Guide";
bhDescription = bhIsItinerary ? "Explore a flexible Bimini example, review its assumptions, and create an editable FPW itinerary with mileage, timing and fuel estimates." : "Compare Bahamas cruising areas, prepare for the crossing, and customize a worked trip with clear mileage, time and fuel assumptions.";
bhCanonical = bhIsItinerary ? bhManifest.canonical_url : "https://floatplanwizard.com/boating-guides/bahamas/";
bhChecked = bhManifest.verification.checked_at;
bhPageReady = true;
request.fpwTopNavActive = "resources-boating-guides";
function bhSource(required string id, required string label) {
  if (!structKeyExists(bhSources, arguments.id)) return encodeForHTML(arguments.label);
  return '<a href="' & encodeForHTMLAttribute(bhSources[arguments.id].url) & '">' & encodeForHTML(arguments.label) & '</a>';
}
function bhOne(required numeric value) { return numberFormat(arguments.value, "0.0"); }
function bhTime(required numeric hours) {
  var minutes = round(arguments.hours * 60);
  return int(minutes / 60) & " h " & numberFormat(minutes MOD 60, "00") & " min";
}
bhWorksheet = bhManifest.worksheet;
bhTemplateDistance = 0;
bhTemplateMissingLegs = 0;
for (bhMovement in bhManifest.legs) {
  if (isNull(bhMovement.distance_nm)) bhTemplateMissingLegs++;
  else bhTemplateDistance += bhMovement.distance_nm;
}
// These public comparison results use the worksheet's explicit operating assumptions;
// the personal copy still requires the member's own confirmed speed and consumption.
bhTemplateHours = bhTemplateDistance / bhWorksheet.planning_speed_kn;
bhTemplateBurn = bhTemplateHours * bhWorksheet.underway_burn_us_gph;
bhTemplateRequired = bhTemplateBurn * (1 + bhWorksheet.reserve_pct / 100);
bhWDistance = 0;
for (bhWLeg in bhWorksheet.legs) bhWDistance += bhWLeg.distance_nm;
bhWHours = bhWDistance / bhWorksheet.planning_speed_kn;
bhWBurn = bhWHours * bhWorksheet.underway_burn_us_gph;
bhWReserve = bhWBurn * bhWorksheet.reserve_pct / 100;
bhWRequired = bhWBurn + bhWReserve;
bhSlowHours = bhWDistance / bhWorksheet.slow_speed_kn;
bhSlowBurn = bhSlowHours * bhWorksheet.slow_burn_us_gph;
bhChangedDistance = bhWorksheet.legs[1].distance_nm + bhWorksheet.revised_return_distance_nm;
bhChangedHours = bhChangedDistance / bhWorksheet.planning_speed_kn;
bhChangedBurn = bhChangedHours * bhWorksheet.underway_burn_us_gph;
bhSchema = structNew("ordered");
bhSchema[chr(64) & "context"] = "https://schema.org";
bhSchema[chr(64) & "graph"] = [];
bhBreadcrumbItems = [
  {"@type":"ListItem","position":1,"name":"FloatPlanWizard","item":"https://floatplanwizard.com/"},
  {"@type":"ListItem","position":2,"name":"Cruising Guides","item":"https://floatplanwizard.com/boating-guides/"},
  {"@type":"ListItem","position":3,"name":"Bahamas Cruising and Trip Planning Guide","item":"https://floatplanwizard.com/boating-guides/bahamas/"}
];
if (bhIsItinerary) arrayAppend(bhBreadcrumbItems, {"@type":"ListItem","position":4,"name":bhTitle,"item":bhCanonical});
bhBreadcrumb = structNew("ordered");
bhBreadcrumb[chr(64) & "type"] = "BreadcrumbList";
bhBreadcrumb["itemListElement"] = bhBreadcrumbItems;
arrayAppend(bhSchema[chr(64) & "graph"], bhBreadcrumb);
bhWebPage = structNew("ordered");
bhWebPage[chr(64) & "type"] = "WebPage";
bhWebPage["url"] = bhCanonical;
bhWebPage["name"] = bhTitle;
bhWebPage["description"] = bhDescription;
arrayAppend(bhSchema[chr(64) & "graph"], bhWebPage);
bhArticle = structNew("ordered");
bhArticle[chr(64) & "type"] = "Article";
bhArticle["headline"] = bhTitle;
bhArticle["mainEntityOfPage"] = bhCanonical;
bhArticle["inLanguage"] = "en";
bhAuthor = structNew("ordered");
bhAuthor[chr(64) & "type"] = "Organization";
bhAuthor["name"] = "FloatPlanWizard";
bhAuthor["url"] = "https://floatplanwizard.com/";
bhArticle["author"] = bhAuthor;
bhArticle["publisher"] = bhAuthor;
arrayAppend(bhSchema[chr(64) & "graph"], bhArticle);
bhJsonLd = replace(serializeJSON(bhSchema), "</", "<\/", "all");
</cfscript>
<cfheader name="Cache-Control" value="no-store, max-age=0">
<cfif NOT bhPublished><cfheader name="X-Robots-Tag" value="noindex, follow"></cfif>

