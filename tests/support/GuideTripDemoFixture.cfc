component extends="testbox.system.BaseSpec" output=false {
 public struct function ensureDraftPlan(required numeric userId,required numeric routeInstanceId) {
  var r={};
  var vessel=queryExecute("SELECT vesselID FROM vessels WHERE userId=:uid LIMIT 1",{uid={value=toString(arguments.userId),cfsqltype="cf_sql_varchar"}},{datasource="fpw"});
  if(!vessel.recordCount) queryExecute("INSERT INTO vessels(userId,vesselName,hailingPort,isDefaultVessel,max_speed,gallons_per_hour) VALUES(:uid,'Disposable QA vessel','Florida',1,76,99)",
    {uid={value=toString(arguments.userId),cfsqltype="cf_sql_varchar"}},{datasource="fpw",result="r"});
  var rb=new fpw.api.v1.routeBuilder(); makePublic(rb,"buildFloatPlansFromRoute","buildForTest");
  return rb.buildForTest(userId=arguments.userId,routeInstanceId=arguments.routeInstanceId,mode="SINGLE_MASTER");
 }
 public struct function createDemo(boolean attributionScenario=false) {
  var svc=new fpw.tests.support.GuideTripFixtureService().init("fpw");
  var rb=new fpw.api.v1.routeBuilder(); makePublic(rb,"saveGuideTrip","saveForTest"); makePublic(rb,"buildFloatPlansFromRoute","buildForTest");
  var result={}; var email="codex-guide-demo-" & createUUID() & "@example.test";
  queryExecute("INSERT INTO users(fName,lName,email,password,passwordCreated,created) VALUES('Disposable','Guide Demo',:email,:pwd,NOW(),NOW())",
   {email={value=email,cfsqltype="cf_sql_varchar"},pwd={value=hash(createUUID(),"SHA-256"),cfsqltype="cf_sql_varchar"}},{datasource="fpw",result="result"});
  var uid=val(result.generatedKey);
  var req={template_key="fort-lauderdale-bimini",template_version=1,import_request_id=lCase(createObject("java","java.util.UUID").randomUUID().toString())};
  var draft=svc.importTrip(uid,req);
  var body={revision=draft.revision,route_name="Bahamas guide review demo",trip_notes="Disposable local QA only. Two local days and two weather days; no automatic departure or notifications.",planning_inputs={
   planning_speed_kn=20,underway_burn_us_gph=18,underway_hours_per_day=6.5,reserve_mode="percentage",reserve_pct=20,idle_burn_us_gph=0,idle_hours_total=0,usable_fuel_us_gal=190,performance_confirmed=true,start_date="2026-12-01"},legs=[]};
  for(var leg in draft.legs) arrayAppend(body.legs,{user_route_leg_id=leg.user_route_leg_id,content_fingerprint=leg.content_fingerprint,distance_nm=arguments.attributionScenario ? leg.distance_nm : 60,distance_method=arguments.attributionScenario ? leg.distance_method : "Disposable QA worksheet assumption; no navigation evidence.",review_action=arguments.attributionScenario ? "confirm" : "replace"});
  body.draft_request_id=lCase(createObject("java","java.util.UUID").randomUUID().toString());
  draft=svc.saveDraft(uid,draft.user_route_id,body);
  var attribution={};
  if (arguments.attributionScenario) {
   // Exercise a real edit with the copied method still submitted, then persist and reopen the incomplete draft.
   body.revision=draft.revision; body.legs=[];
   for(var editLeg in draft.legs) arrayAppend(body.legs,{user_route_leg_id=editLeg.user_route_leg_id,content_fingerprint=editLeg.content_fingerprint,distance_nm=editLeg.order_index EQ 2 ? 55 : editLeg.distance_nm,distance_method=editLeg.distance_method,review_action=""});
   body.draft_request_id=lCase(createObject("java","java.util.UUID").randomUUID().toString());
   svc.saveDraft(uid,draft.user_route_id,body);
   draft=svc.getDraft(uid,draft.user_route_id);
   attribution.incomplete_draft=duplicate(draft);
   attribution.editedDraftReopened=draft.legs[2].distance_nm EQ 55 AND draft.legs[2].distance_kind EQ "member_entered" AND !len(draft.legs[2].distance_method) AND !arrayLen(draft.legs[2].source_ids) AND structIsEmpty(draft.legs[2].source_dates) AND draft.legs[2].review_status EQ "unreviewed";
   attribution.originalPreserved=draft.source_snapshot.legs[2].distance_nm EQ 50.3 AND findNoCase("Owner-supplied planning estimate",draft.source_snapshot.legs[2].distance_method) GT 0;
   attribution.outboundReviewPreserved=draft.legs[1].review_status EQ "member_confirmed";
   body.revision=draft.revision; body.legs=[];
   for(var reviewedLeg in draft.legs) arrayAppend(body.legs,{user_route_leg_id=reviewedLeg.user_route_leg_id,content_fingerprint=reviewedLeg.content_fingerprint,distance_nm=reviewedLeg.distance_nm,distance_method=reviewedLeg.order_index EQ 2 ? "Member supplied a 55 NM planning allowance for this disposable QA trip; not navigation evidence." : reviewedLeg.distance_method,review_action=reviewedLeg.order_index EQ 2 ? "replace" : ""});
   body.draft_request_id=lCase(createObject("java","java.util.UUID").randomUUID().toString());
   svc.saveDraft(uid,draft.user_route_id,body);
   draft=svc.getDraft(uid,draft.user_route_id);
   attribution.reviewedDraftReopened=draft.legs[2].distance_nm EQ 55 AND draft.legs[2].distance_kind EQ "member_entered" AND find("Member supplied a 55 NM",draft.legs[2].distance_method) GT 0 AND draft.legs[2].review_status EQ "member_replaced";
  }
  var saved=rb.saveForTest(uid,draft.user_route_id,{revision=draft.revision,save_request_id=lCase(createObject("java","java.util.UUID").randomUUID().toString())});
  if (arguments.attributionScenario) attribution.saved_context=svc.getSnapshotForInstance(saved.DATA.route_instance_id);
  var built=ensureDraftPlan(uid,saved.DATA.route_instance_id);
  req.import_request_id=lCase(createObject("java","java.util.UUID").randomUUID().toString()); req.create_another=true;
  var incomplete=svc.importTrip(uid,req);
  return {user_id=uid,email=email,complete_route_id=draft.user_route_id,incomplete_route_id=incomplete.user_route_id,saved=saved.DATA,floatplan=built,attribution=attribution};
 }

 public struct function createNonguideDemo(required numeric userId) {
  var owner=queryExecute("SELECT email FROM users WHERE userId=:uid",
   {uid={value=arguments.userId,cfsqltype="cf_sql_integer"}},{datasource="fpw"});
  if (!owner.recordCount OR !findNoCase("@example.test",owner.email[1])) throw(message="Disposable PDF owner required.");
  var fp=new fpw.api.v1.floatplan();
  makePublic(fp,"saveBasicFloatPlan","saveBasicForPdfTest");
  var result=fp.saveBasicForPdfTest(arguments.userId,{
   FLOATPLAN={NAME="Standard nonguide PDF QA",DEPARTURE_TIME="2026-12-01T10:00",DEPARTURE_TIMEZONE="America/New_York",
    DEPARTURE_TIME_UTC="2026-12-01T15:00:00.000Z",RETURN_TIME="2026-12-01T12:00",RETURN_TIMEZONE="America/New_York",
    RETURN_TIME_UTC="2026-12-01T17:00:00.000Z",NOTES="Disposable local PDF verification only; no departure, activation or notifications."},
   BASIC_DETAILS={VESSEL_NAME="Standard QA vessel",OPERATOR_NAME="Disposable QA operator",CAPTAIN_NAME="Disposable QA captain",
    CAPTAIN_EMAIL=owner.email[1],NOTIFICATION_CONTACT_NAME="Disposable QA shore contact",NOTIFICATION_CONTACT_EMAIL="qa-shore@example.test",
    LAUNCH_LOCATION="QA Florida staging",DESTINATION_LOCATION="QA harbor destination",AUTHORITY_ID=-1}
  });
  if (!result.SUCCESS) throw(message="Standard nonguide draft save failed.",detail=toString(result.MESSAGE ?: result.ERROR ?: ""));
  return {user_id=arguments.userId,floatplan_id=result.FLOATPLANID};
 }
}
