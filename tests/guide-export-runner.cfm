<cfsetting showdebugoutput="false" enablecfoutputonly="true" requesttimeout="120">
<cfcontent type="application/json; charset=utf-8" reset="true">
<cfheader name="Cache-Control" value="no-store">
<cfscript>
request.guideTestConfirmation="RUN_LOCAL_GUIDE_EXPORT_TESTS";
include "support/guide-test-guard.cfm";
try {
 service = new fpw.api.api_assets.FloatPlanPdfItineraryService().init("fpw");
 context = {template_key="test-bimini",template_version=1,canonical_guide_url="https://floatplanwizard.com/boating-guides/bahamas/",planning_inputs={planning_speed_kn=20,underway_burn_us_gph=18,reserve_mode="percentage",reserve_pct=20},
 trip_notes="Two local days and two weather allowance days. <script>alert(1)</script>",
 legs=[{order_index=1,start_name="Florida & staging",end_name="Bimini",distance_nm=60,distance_kind="illustrative_estimate",distance_method="Illustrative calculation input; not a measured route.",source_ids=["S8"],geometry_kind="schematic",review_status="member_confirmed",reviewed_at="2026-11-07T14:00:00Z"},
 {order_index=2,start_name="Bimini",end_name="Florida",distance_kind="missing",distance_method="Return mileage must be supplied.",source_ids=[],geometry_kind="schematic",review_status="unreviewed"}]};
 context.totals = {complete=false,known_distance_nm=60,known_run_hours=3,known_cruise_fuel_us_gal=54,missing_inputs=["Return mileage"],missing_leg_count=1};
 context.source_snapshot={verification={checked_at="2026-11-07"},stops=[{source_ids=["S8"]}],source_register_snapshot=[{id="S8",authority="Fixture source",url="https://example.invalid/record",accessed_at="2026-11-07",effective_date="Unspecified",claim="Test record only. Coordinate glyph probe: 26°05′30″N., 80°04′46″W.",verification_status="fixture"}]};
 html = service.buildGuideSupplementHtml(context,"Guide export fixture");
 checks = {
 coordinateGlyphsInHtml=find(encodeForHTML('26°05′30″N., 80°04′46″W.'),html) GT 0,
 copiedSourceRecord=find(encodeForHTML("https://example.invalid/record"),html) GT 0 AND find("Fixture source",html) GT 0,
 partialSubtotal=find("Known-leg subtotals - incomplete estimate",html) GT 0 AND find("60.0 nm",html) GT 0,
 missingInputs=find("Return mileage",html) GT 0,
 sourceDate=find("2026-11-07",html) GT 0,
 noCompleteSufficiency=find("Usable fuel above the estimated requirement:",html) EQ 0,
 estimateLabel=find("planning estimates",html) GT 0,
 missingNotZero=find("Missing - incomplete estimate",html) GT 0,
 sourceMethod=find("Illustrative calculation input",html) GT 0,
 confirmationNotVerification=find("not independent route verification",html) GT 0,
 schematicLabel=find("Schematic connection",html) GT 0,
 notesEscaped=find("<script>alert",html) EQ 0 AND find("&lt;script",html) GT 0,
 geographyEscaped=find("Florida &amp; staging",html) GT 0,
 publicSourceLink=find(encodeForHTML("https://floatplanwizard.com/boating-guides/bahamas/"),html) GT 0
 };
 slowContext=duplicate(context);
 slowContext.planning_inputs={planning_speed_kn=7,underway_burn_us_gph=4,underway_hours_per_day=6.5,reserve_mode="percentage",reserve_pct=20,idle_burn_us_gph=0,idle_hours_total=0,usable_fuel_us_gal=190,performance_confirmed=true,start_date="2026-12-01"};
 slowContext.legs[2].distance_nm=60;
 slowContext.totals=new fpw.api.v1.GuideTripService().init("fpw").calculateTotals(slowContext.legs,slowContext.planning_inputs);
 slowHtml=service.buildGuideSupplementHtml(slowContext,"Slower worksheet test");
 checks.nearestMinute=find("17 h 09 min",slowHtml) GT 0;
 checks.fuelOneDecimal=find("68.6 US gal",slowHtml) GT 0 AND find("82.3 US gal",slowHtml) GT 0;
 thirdsContext=duplicate(slowContext);
 thirdsContext.planning_inputs.planning_speed_kn=20;
 thirdsContext.planning_inputs.underway_burn_us_gph=18;
 thirdsContext.planning_inputs.reserve_mode="thirds";
 thirdsContext.planning_inputs.reserve_pct=20;
 thirdsContext.totals=new fpw.api.v1.GuideTripService().init("fpw").calculateTotals(thirdsContext.legs,thirdsContext.planning_inputs);
 thirdsHtml=service.buildGuideSupplementHtml(thirdsContext,"Thirds reserve worksheet test");
 checks.thirdsReserveDescription=find(encodeForHTML("Thirds reserve:"),thirdsHtml) GT 0 AND find(encodeForHTML("The percentage input is not used."),thirdsHtml) GT 0 AND find(encodeForHTML("20% added"),thirdsHtml) EQ 0;
 checks.thirdsReserveValues=find("54.0 US gal",thirdsHtml) GT 0 AND find("162.0 US gal",thirdsHtml) GT 0;
 memberContext=duplicate(slowContext);
 memberContext.legs[2].distance_nm=55;
 memberContext.legs[2].distance_kind="member_entered";
 memberContext.legs[2].distance_method="";
 memberContext.legs[2].source_ids=[];
 memberContext.legs[2].source_dates={};
 memberContext.legs[2].review_status="unreviewed";
 memberContext.totals=new fpw.api.v1.GuideTripService().init("fpw").calculateTotals(memberContext.legs,memberContext.planning_inputs);
 memberHtml=service.buildGuideSupplementHtml(memberContext,"Edited mileage without method");
 checks.memberEnteredLabel=find("55.0 nm - Member-entered estimate",memberHtml) GT 0;
 checks.blankMethodExplained=find("Not recorded - enter a source or method before Float Plan creation.",memberHtml) GT 0;
 checks.blankMethodIncomplete=!memberContext.totals.complete AND find("Known-leg subtotals - incomplete estimate",memberHtml) GT 0 AND find("Estimated departure requirement:",memberHtml) EQ 0;
 checks.editedNotReviewed=find("Not reviewed",memberHtml) GT 0;
 ok=true; for (key in checks) if (!checks[key]) ok=false;
 if (ok AND structKeyExists(url,"render") AND url.render EQ "1") {
   outputDirectory=expandPath("../.codex-snapshots/bahamas-guide-20261107/attribution-20261109/evidence");
   if (!directoryExists(outputDirectory)) directoryCreate(outputDirectory,true);
   cfdocument(format="PDF",filename=outputDirectory & "/guide-incomplete-estimates.pdf",overwrite=true,pagetype="letter",marginleft=".55",marginright=".55",margintop=".55",marginbottom=".55",localurl=true) {
     writeOutput(html);
   }
 }
 if (ok AND structKeyExists(url,"full") AND url.full EQ "1") {
   outputDirectory=expandPath("../.codex-snapshots/bahamas-guide-20261107/attribution-20261109/evidence");
   if (!directoryExists(outputDirectory)) directoryCreate(outputDirectory,true);
   demo=new fpw.tests.support.GuideTripDemoFixture().createDemo(attributionScenario=true);
   checks.editedDraftReopened=demo.attribution.editedDraftReopened;
   checks.originalSnapshotPreserved=demo.attribution.originalPreserved;
   checks.unaffectedReviewPreserved=demo.attribution.outboundReviewPreserved;
   checks.reviewedDraftReopened=demo.attribution.reviewedDraftReopened;
   savedLeg=demo.attribution.saved_context.legs[2];
   checks.savedTripAttribution=savedLeg.distance_nm EQ 55 AND savedLeg.distance_kind EQ "member_entered" AND find("Member supplied a 55 NM",savedLeg.distance_method) GT 0 AND savedLeg.review_status EQ "member_replaced";
   editedDraftHtml=service.buildGuideSupplementHtml(demo.attribution.incomplete_draft,"Edited planning draft - source or method missing");
   cfdocument(format="PDF",filename=outputDirectory & "/guide-edited-missing-method.pdf",overwrite=true,pagetype="letter",marginleft=".55",marginright=".55",margintop=".55",marginbottom=".55",localurl=true) {
     writeOutput(editedDraftHtml);
   }
   checks.editedDraftPdf=fileExists(outputDirectory & "/guide-edited-missing-method.pdf");
   if (!demo.floatplan.SUCCESS OR !arrayLen(demo.floatplan.FLOATPLAN_IDS)) throw(message="Disposable guide PDF fixture was not created.");
   pdfName=new fpw.api.api_assets.floatPlanUtils().init().createPDF(demo.floatplan.FLOATPLAN_IDS[1],demo.user_id);
   if (!isSimpleValue(pdfName) OR !len(toString(pdfName)) OR isBoolean(pdfName)) throw(message="The guide Float Plan PDF was not generated.");
   pdfSource=expandPath("../api/api_assets/floatPlans/user_float_plans/") & pdfName;
   fileCopy(pdfSource,outputDirectory & "/guide-official-form-with-supplement.pdf");
   checks.actualFloatPlanPdf=fileExists(outputDirectory & "/guide-official-form-with-supplement.pdf");
   standard=new fpw.tests.support.GuideTripDemoFixture().createNonguideDemo(demo.user_id);
   standardItinerary=service.getItinerary(standard.floatplan_id);
   checks.nonguideHasNoSupplement=!structKeyExists(standardItinerary,"guideSupplementHtml");
   standardPdfName=new fpw.api.api_assets.floatPlanUtils().init().createPDF(standard.floatplan_id,standard.user_id);
   if (!isSimpleValue(standardPdfName) OR !len(toString(standardPdfName)) OR isBoolean(standardPdfName)) throw(message="Standard nonguide PDF was not generated.");
   standardPdfSource=expandPath("../api/api_assets/floatPlans/user_float_plans/") & standardPdfName;
   fileCopy(standardPdfSource,outputDirectory & "/standard-nonguide-float-plan.pdf");
   checks.actualNonguidePdf=fileExists(outputDirectory & "/standard-nonguide-float-plan.pdf");
   // Retain protected evidence only; these freshly generated disposable files need no public output copy.
   fileDelete(standardPdfSource);
   fileDelete(pdfSource);
 }
 ok=true; for (key in checks) if (!checks[key]) ok=false;
 // Compile production entry points without invoking any transition or mutation.
 new fpw.api.v1.floatplan();
 new fpw.api.api_assets.floatPlanUtils();
 new fpw.api.v1.RouteMapGeometryService().init("fpw");
 cfheader(statuscode=ok ? 200 : 500);
 writeOutput(serializeJSON({SUCCESS=ok,checks=checks}));
} catch(any failure) {
 cfheader(statuscode=500);
 writeOutput(serializeJSON({SUCCESS=false,TYPE=failure.type,MESSAGE=failure.message,DETAIL=failure.detail}));
}
</cfscript>
