component extends="testbox.system.BaseSpec" output=false {
  public struct function runContract() {
    var checks={items=[]}; var caught={}; var contractComplete=false;
    var svc=new fpw.tests.support.GuideTripFixtureService().init("fpw");
    // Null-mileage coverage is independent of the current editorial example values.
    svc.setMissingMileageFixture(true);
    var real=new fpw.api.v1.GuideTripService().init("fpw");
    var rb=new fpw.api.v1.routeBuilder();
    var fp=new fpw.api.v1.floatplan();
    makePublic(fp,"saveFloatPlan","saveForTest"); makePublic(fp,"ensureCleanRouteInstanceForActivation","prepareForTest"); makePublic(fp,"createFreshOperationalRouteInstanceFromTemplate","cloneForTest");
    for (var name in ["saveGuideTrip","getUserRoute","routegenGetEditContext","buildFloatPlansFromRoute","removeLegFromUserRoute","addWaypointLegToUserRoute","reorderUserRouteLegs","saveRouteLegOverrideGeometry","deleteUserRoute","guideActionPreflight","listUserRoutes"])
      makePublic(rb,name,name & "Test");
    var uid=0;
    try {
      {
        var email="codex-guide-" & lCase(replace(createUUID(),"-","","all")) & "@example.test";
        queryExecute("INSERT INTO users (fName,lName,email,password,passwordCreated,created) VALUES ('Guide','Fixture',:email,:pwd,UTC_TIMESTAMP(),UTC_TIMESTAMP())",
          {email={value=email,cfsqltype="cf_sql_varchar"},pwd={value=hash(createUUID(),"SHA-256"),cfsqltype="cf_sql_varchar"}},{datasource="fpw"});
        uid=val(queryExecute("SELECT userId FROM users WHERE email=:email",{email={value=email,cfsqltype="cf_sql_varchar"}},{datasource="fpw"}).userId[1]);
        var req={template_key="fort-lauderdale-bimini",template_version=1,import_request_id=newUuid(),create_another=false};
        var draft=svc.importTrip(uid,req);
        ensure(arrayLen(draft.legs) EQ 2 AND draft.totals.missing_leg_count EQ 2 AND !draft.totals.complete,"Source mileage remains missing",checks);
        var routeId=draft.user_route_id;
        var dashboardDrafts=rb.listUserRoutesTest(uid);
        ensure(arrayLen(dashboardDrafts.PLANNING_DRAFTS) EQ 1 AND dashboardDrafts.PLANNING_DRAFTS[1].ROUTE_ID EQ routeId
          AND !dashboardDrafts.PLANNING_DRAFTS[1].TOTALS.complete,"Dashboard lists owned incomplete planning draft separately from generated routes",checks);
        ensure(!arrayLen(rb.listUserRoutesTest(uid+1000000).PLANNING_DRAFTS),"Dashboard does not expose another member planning draft",checks);
        svc.setPublicationStatus("retired");
        var retiredRejected=false;
        try { svc.importTrip(uid,{template_key="fort-lauderdale-bimini",template_version=1,import_request_id=newUuid()}); }
        catch(any e) { retiredRejected=e.type EQ "FPW.Guide.TEMPLATE_UNAVAILABLE"; }
        ensure(retiredRejected,"Retired template rejects new imports",checks);
        var retiredDraft=svc.getDraft(uid,routeId);
        ensure(!retiredDraft.can_create_another_copy,"Retired source disables another-copy control without hiding owned draft",checks);
        retiredDraft=real.saveDraft(uid,routeId,{revision=retiredDraft.revision,draft_request_id=newUuid(),trip_notes="Editable after template retirement."});
        draft=svc.getDraft(uid,routeId);
        ensure(draft.trip_notes EQ "Editable after template retirement." AND draft.source_snapshot.status EQ "published",
          "Retired template leaves existing copy editable with immutable published snapshot",checks);
        svc.setPublicationStatus("published");
        var retainedPromptRejected=false;
        try {
          real.saveDraft(uid,routeId,{revision=draft.revision,draft_request_id=newUuid(),legs=[{
            user_route_leg_id=draft.legs[1].user_route_leg_id,content_fingerprint=draft.legs[1].content_fingerprint,
            distance_nm=60,distance_method=draft.legs[1].distance_method,review_action="confirm"}]});
        } catch(any e) { retainedPromptRejected=e.type EQ "FPW.Guide.METHOD_REQUIRED"; }
        ensure(retainedPromptRejected AND real.getDraft(uid,routeId).legs[1].distance_missing,
          "A positive estimate cannot retain the imported missing-mileage explanation",checks);
        ensure(svc.importTrip(uid,req).user_route_id EQ routeId,"Import retry reuses same copy",checks);
        req.import_request_id=newUuid();
        ensure(svc.importTrip(uid,req).user_route_id EQ routeId,"Ordinary second selection preserves current copy",checks);
        var aliasReq=duplicate(req);
        req.import_request_id=newUuid(); req.create_another=true;
        var second=svc.importTrip(uid,req);
        ensure(second.user_route_id NEQ routeId,"Explicit another copy creates a distinct route",checks);
        var denied=false;
        try { real.getDraft(uid+1000000,routeId); } catch(any e) { denied=e.type EQ "FPW.Guide.COPY_UNAVAILABLE"; }
        ensure(denied,"Cross-owner draft rejected",checks);
        var savedBody={revision=draft.revision,route_name="Guide fixture",trip_notes="Two local days and two weather days.",planning_inputs={
          planning_speed_kn=20,underway_burn_us_gph=18,underway_hours_per_day=6.5,reserve_mode="percentage",reserve_pct=20,
          idle_burn_us_gph=0,idle_hours_total=0,usable_fuel_us_gal=190,performance_confirmed=true,start_date="2026-12-01"},legs=[]};
        for (var i=1;i LTE arrayLen(draft.legs);i++) arrayAppend(savedBody.legs,{user_route_leg_id=draft.legs[i].user_route_leg_id,
          content_fingerprint=draft.legs[i].content_fingerprint,distance_nm=(i EQ 1 ? 60 : ""),distance_method=(i EQ 1 ? "Constructed test-only worksheet assumption." : ""),review_action=""});
        savedBody.draft_request_id=newUuid();
        draft=real.saveDraft(uid,routeId,savedBody);
        ensure(draft.legs[1].distance_nm EQ 60 AND draft.legs[1].distance_method EQ "Constructed test-only worksheet assumption.",
          "Explicit member mileage method replaces the missing prompt",checks);
        var retriedDraft=real.saveDraft(uid,routeId,savedBody);
        ensure(retriedDraft.revision EQ draft.revision AND retriedDraft.reused,"Draft retry preserves null input without another revision",checks);
        var conflictingBody=duplicate(savedBody); conflictingBody.trip_notes="Conflicting retry";
        denied=false; try { real.saveDraft(uid,routeId,conflictingBody); } catch(any e) { denied=e.type EQ "FPW.Guide.REQUEST_CONFLICT"; }
        ensure(denied,"Draft UUID with changed content conflicts",checks);
        conflictingBody.draft_request_id=newUuid();
        denied=false; try { real.saveDraft(uid,routeId,conflictingBody); } catch(any e) { denied=e.type EQ "FPW.Guide.REVISION_CONFLICT"; }
        ensure(denied,"New draft UUID does not bypass stale revision",checks);
        var unchanged=real.saveDraft(uid,routeId,{revision=draft.revision,draft_request_id=newUuid()});
        ensure(unchanged.revision EQ draft.revision,"No-op draft save does not advance revision",checks);
        var reopened=rb.getUserRouteTest(uid,routeId);
        ensure(!isNumeric(reopened.DATA.legs[2].dist_nm) AND reopened.DATA.GUIDE_CONTEXT.totals.known_distance_nm EQ 60
          AND !reopened.DATA.GUIDE_CONTEXT.totals.complete,"My Route reopen retains null and partial estimates",checks);
        denied=false;
        try { rb.saveGuideTripTest(uid,routeId,{revision=draft.revision,save_request_id=newUuid()}); } catch(any e) { denied=e.type EQ "FPW.Guide.INCOMPLETE"; }
        ensure(denied,"Incomplete draft cannot generate saved trip",checks);
        savedBody.revision=draft.revision;
        savedBody.legs=[];
        for (var leg in draft.legs) arrayAppend(savedBody.legs,{user_route_leg_id=leg.user_route_leg_id,content_fingerprint=leg.content_fingerprint,distance_nm=60,distance_method="Constructed test-only worksheet assumption.",review_action=""});
        savedBody.draft_request_id=newUuid();
        draft=real.saveDraft(uid,routeId,savedBody);
        var saveReq={revision=draft.revision,save_request_id=newUuid()};
        var saved=rb.saveGuideTripTest(uid,routeId,saveReq);
        ensure(saved.SUCCESS AND saved.DATA.route_instance_id GT 0,"Complete estimate saves through existing generated-trip path",checks);
        var instanceId=saved.DATA.route_instance_id; var generatedId=saved.DATA.route_id;
        dashboardDrafts=rb.listUserRoutesTest(uid);
        ensure(arrayLen(dashboardDrafts.PLANNING_DRAFTS) EQ 1 AND dashboardDrafts.PLANNING_DRAFTS[1].ROUTE_ID EQ second.user_route_id,
          "Completed save leaves only unsaved copy in dashboard planning drafts",checks);
        var map=new fpw.api.v1.RouteMapGeometryService().init("fpw").buildRouteMapData(instanceId,uid);
        fileWrite(expandPath("/fpw/.codex-snapshots/bahamas-guide-20261107/backend/map-result.json"),serializeJSON(map),"utf-8");
        ensure(map.total_nm EQ 120 AND map.route_geo.guide_estimates AND arrayLen(map.route_geo.guide_geometry_sources) EQ 2
          AND map.route_geo.guide_geometry_sources[1] EQ "schematic","Saved map retains schematic lines and120nm estimate",checks);
        ensure(!real.validateReadiness(uid,instanceId).allowed,"Unreviewed complete trip cannot enter float-plan workflow",checks);
        var direct=fp.saveForTest(uid,{FLOATPLAN={route_instance_id=instanceId,floatPlanName="Guide bypass test"}});
        ensure(!direct.SUCCESS AND direct.ERROR EQ "GUIDE_REVIEW_REQUIRED","Direct Float Plan save rejects unreviewed mileage",checks);
        var activation=fp.prepareForTest(uid,0,instanceId);
        ensure(!activation.SUCCESS AND activation.ERROR EQ "GUIDE_REVIEW_REQUIRED","Activation preparation rejects unreviewed mileage before cloning",checks);
        var build=rb.buildFloatPlansFromRouteTest(userId=uid,routeInstanceId=instanceId);
        ensure(!build.SUCCESS AND build.ERROR.CODE EQ "GUIDE_REVIEW_REQUIRED","Float-plan creation uses shared review gate",checks);
        var repeatSave=rb.saveGuideTripTest(uid,routeId,saveReq);
        ensure(repeatSave.DATA.route_instance_id EQ instanceId AND repeatSave.DATA.reused,"Lost-response save retry returns same result",checks);
        var edit=rb.routegenGetEditContextTest(uid,saved.DATA.route_code);
        ensure(edit.DATA.inputs.route_type EQ "my_route" AND edit.DATA.inputs.route_id EQ routeId AND edit.DATA.GUIDE_CONTEXT.trip_notes EQ savedBody.trip_notes,"Saved edit reopens source draft and notes",checks);
        draft=real.getDraft(uid,routeId); savedBody.revision=draft.revision; savedBody.legs=[];
        for (var leg in draft.legs) arrayAppend(savedBody.legs,{user_route_leg_id=leg.user_route_leg_id,content_fingerprint=leg.content_fingerprint,distance_nm=leg.distance_nm,distance_method=leg.distance_method,review_action="confirm"});
        savedBody.draft_request_id=newUuid();
        draft=real.saveDraft(uid,routeId,savedBody);
        ensure(!real.validateReadiness(uid,instanceId).allowed,"Newer draft is visible and blocks stale saved snapshot",checks);
        denied=false;
        try { rb.saveGuideTripTest(uid,routeId,{revision=draft.revision,save_request_id=saveReq.save_request_id}); } catch(any e) { denied=e.type EQ "FPW.Guide.REQUEST_CONFLICT"; }
        ensure(denied,"Same save UUID with changed draft conflicts",checks);
        saved=rb.saveGuideTripTest(uid,routeId,{revision=draft.revision,save_request_id=newUuid()});
        ensure(saved.DATA.route_id EQ generatedId AND saved.DATA.route_instance_id EQ instanceId,"Later save updates owned generated trip",checks);
        ensure(rb.saveGuideTripTest(uid,routeId,saveReq).DATA.reused,"Save A retry remains durable after save B",checks);
        var ready=real.validateReadiness(uid,instanceId);
        ensure(ready.allowed,"Current member review permits float-plan entry",checks);
        var safe=real.getSnapshotForInstance(instanceId);
        ensure(safe.legs[1].distance_kind EQ "member_entered" AND safe.legs[1].review_status EQ "member_confirmed"
          AND safe.legs[1].geometry_kind EQ "schematic" AND !structKeyExists(safe.legs[1],"reviewed_by_user_id"),"Export snapshot preserves estimate/review distinction and strips reviewer ID",checks);
        var leg=real.getDraft(uid,routeId).legs[1];
        var plot=rb.saveRouteLegOverrideGeometryTest(uid,routeId,leg.user_route_leg_id,[
          {lat=leg.start_lat,lng=leg.start_lng},{lat=leg.end_lat,lng=leg.end_lng}]);
        ensure(plot.SUCCESS,"Member plotted geometry saves",checks);
        draft=real.getDraft(uid,routeId);
        ensure(draft.has_newer_draft AND draft.revision GT draft.generated_revision,"Geometry change advances draft revision and newer-draft status",checks);
        ensure(draft.legs[1].review_status EQ "unreviewed" AND draft.legs[1].geometry_kind EQ "member_plotted"
          AND draft.legs[1].distance_kind EQ "member_plotted","Geometry revision invalidates mileage review",checks);
        ensure(!real.validateReadiness(uid,instanceId).allowed,"Changed geometry blocks previously reviewed saved trip",checks);
        savedBody.revision=draft.revision; savedBody.legs=[];
        for (var leg in draft.legs) arrayAppend(savedBody.legs,{user_route_leg_id=leg.user_route_leg_id,content_fingerprint=leg.content_fingerprint,distance_nm=leg.distance_nm,distance_method=leg.distance_method,review_action="confirm"});
        savedBody.draft_request_id=newUuid();
        draft=real.saveDraft(uid,routeId,savedBody);
        saved=rb.saveGuideTripTest(uid,routeId,{revision=draft.revision,save_request_id=newUuid()});
        var plottedReady=real.validateReadiness(uid,instanceId); fileWrite(expandPath("/fpw/.codex-snapshots/bahamas-guide-20261107/backend/geometry-ready.json"),serializeJSON({ready=plottedReady,draft=real.getDraft(uid,routeId),normalized=queryExecute("SELECT leg_order,base_dist_nm,start_name,end_name FROM route_instance_legs WHERE route_instance_id=:id ORDER BY leg_order",{id={value=instanceId,cfsqltype="cf_sql_integer"}},{datasource="fpw"})}),"utf-8");
        ensure(plottedReady.allowed,"Reconfirmed geometry persists into updated trip",checks);
        var geo=queryExecute("SELECT COUNT(*) AS n FROM route_leg_user_overrides WHERE user_id=:uid AND route_id=:rid",
          {uid={value=uid,cfsqltype="cf_sql_integer"},rid={value=generatedId,cfsqltype="cf_sql_integer"}},{datasource="fpw"});
        ensure(val(geo.n[1]) EQ 1,"Member geometry copied to normalized saved trip",checks);
        map=new fpw.api.v1.RouteMapGeometryService().init("fpw").buildRouteMapData(instanceId,uid);
        ensure(abs(map.total_nm-draft.totals.known_distance_nm) LT 0.011 AND map.route_geo.guide_geometry_sources[1] EQ "member_plotted"
          AND map.route_geo.guide_geometry_sources[2] EQ "schematic","Saved map distinguishes member geometry and schematic leg",checks);
        savedBody.revision=draft.revision; savedBody.legs=[];
        for (var leg in draft.legs) arrayAppend(savedBody.legs,{user_route_leg_id=leg.user_route_leg_id,content_fingerprint=leg.content_fingerprint,
          distance_nm=(leg.order_index EQ 1 ? 62.5 : leg.distance_nm),distance_method=(leg.order_index EQ 1 ? "Member replacement planning allowance." : leg.distance_method),review_action="replace"});
        savedBody.draft_request_id=newUuid(); draft=real.saveDraft(uid,routeId,savedBody);
        saved=rb.saveGuideTripTest(uid,routeId,{revision=draft.revision,save_request_id=newUuid()});
        map=new fpw.api.v1.RouteMapGeometryService().init("fpw").buildRouteMapData(instanceId,uid);
        ensure(abs(map.total_nm-122.5) LT 0.011 AND draft.legs[1].distance_kind EQ "member_entered"
          AND draft.legs[1].geometry_kind EQ "member_plotted","Explicit member mileage takes precedence over plotted length",checks);
        queryExecute("INSERT INTO vessels(userId,vesselName,hailingPort,isDefaultVessel) VALUES(:uid,'Guide fixture vessel','Florida',1)",
          {uid={value=toString(uid),cfsqltype="cf_sql_varchar"}},{datasource="fpw"});
        var built=rb.buildFloatPlansFromRouteTest(userId=uid,routeInstanceId=instanceId);
        ensure(built.SUCCESS AND arrayLen(built.FLOATPLAN_IDS) EQ 1,"Reviewed guide creates a real draft Float Plan",checks);
        var cloned=fp.cloneForTest(uid,built.FLOATPLAN_IDS[1],instanceId);
        ensure(cloned.SUCCESS AND real.validateReadiness(uid,cloned.ROUTE_INSTANCE_ID).allowed,"Operational clone retains fractional mileage and current reviewed identity",checks);
        var cloneMap=new fpw.api.v1.RouteMapGeometryService().init("fpw").buildRouteMapData(cloned.ROUTE_INSTANCE_ID,uid);
        ensure(abs(cloneMap.total_nm-122.5) LT 0.011 AND cloneMap.route_geo.guide_estimates
          AND cloneMap.route_geo.guide_geometry_sources[1] EQ "member_plotted" AND cloneMap.route_geo.guide_geometry_sources[2] EQ "schematic","Operational copy map retains estimate total and mixed geometry provenance",checks);
        queryExecute("UPDATE waypoints SET latitude=CAST(latitude AS DECIMAL(10,7))+0.001 WHERE wpId=:id AND userId=:uid",
          {id={value=draft.legs[1].end_waypoint_id,cfsqltype="cf_sql_integer"},uid={value=toString(uid),cfsqltype="cf_sql_varchar"}},{datasource="fpw"});
        draft=real.getDraft(uid,routeId);
        ensure(draft.legs[1].distance_missing AND draft.legs[1].review_status EQ "unreviewed" AND !real.validateReadiness(uid,instanceId).allowed,"Endpoint change clears mileage and review",checks);
        ensure(draft.has_newer_draft AND !arrayLen(draft.legs[1].source_ids),"Endpoint change advances draft revision and clears stale source references",checks);
        runGuideLegEdits(svc,real,rb,uid,second.user_route_id,savedBody.planning_inputs,checks);
        runGuideDestinationReorder(svc,real,rb,uid,savedBody.planning_inputs,checks);
        runOwnerSuppliedSourceEstimates(svc,real,rb,uid,savedBody.planning_inputs,checks);
        runMileageAttributionChanges(real,rb,fp,uid,savedBody.planning_inputs,checks);
        rb.deleteUserRouteTest(uid,second.user_route_id);
        dashboardDrafts=rb.listUserRoutesTest(uid);
        var deletedDraftVisible=false;
        for(var listedDraft in dashboardDrafts.PLANNING_DRAFTS) if(listedDraft.ROUTE_ID EQ second.user_route_id) deletedDraftVisible=true;
        ensure(!deletedDraftVisible,"Deleted source copy disappears from dashboard planning drafts",checks);
        denied=false; try { svc.importTrip(uid,req); } catch(any e) { denied=e.type EQ "FPW.Guide.COPY_DELETED"; }
        ensure(denied,"Deleted import retry does not recreate copy",checks);
        rb.deleteUserRouteTest(uid,routeId); denied=false;
        try { svc.importTrip(uid,aliasReq); } catch(any e) { denied=e.type EQ "FPW.Guide.COPY_DELETED"; }
        ensure(denied,"Deleted copy cannot be recreated by a previously reused request alias",checks);
        throw(type="FPW.GuideTest.Complete",message="Clean up this disposable test member.");
      }
    } catch(any e) {
      if (e.type EQ "FPW.GuideTest.Complete") contractComplete=true;
      else caught={type=e.type,message=e.message,detail=e.detail,tagcontext=e.tagcontext};
    }
    if (uid GT 0) {
      var params={uid={value=uid,cfsqltype="cf_sql_integer"}};
      var routes=queryExecute("SELECT generated_route_id FROM route_instances WHERE user_id=:uid",params,{datasource="fpw"});
      queryExecute("DELETE FROM route_leg_user_overrides WHERE user_id=:uid",params,{datasource="fpw"});
      queryExecute("DELETE FROM floatplans WHERE userId=:uid",params,{datasource="fpw"});
      queryExecute("DELETE FROM route_instances WHERE user_id=:uid",params,{datasource="fpw"});
      queryExecute("DELETE FROM vessels WHERE userId=:uid",{uid={value=toString(uid),cfsqltype="cf_sql_varchar"}},{datasource="fpw"});
      for (var row in routes) queryExecute("DELETE FROM loop_routes WHERE id=:rid",{rid={value=row.generated_route_id,cfsqltype="cf_sql_integer"}},{datasource="fpw"});
      queryExecute("DELETE FROM guide_route_imports WHERE user_id=:uid",params,{datasource="fpw"});
      queryExecute("DELETE FROM user_route_legs WHERE user_route_id IN (SELECT id FROM user_routes WHERE user_id=:uid)",params,{datasource="fpw"});
      queryExecute("DELETE FROM user_routes WHERE user_id=:uid",params,{datasource="fpw"});
      queryExecute("DELETE FROM waypoints WHERE userId=:uid",{uid={value=toString(uid),cfsqltype="cf_sql_varchar"}},{datasource="fpw"});
      queryExecute("DELETE FROM product_events WHERE user_id=:uid",params,{datasource="fpw"});
      queryExecute("DELETE FROM users WHERE userId=:uid",params,{datasource="fpw"});
    }
    return {SUCCESS=structIsEmpty(caught) AND contractComplete,total=arrayLen(checks.items),checks=checks.items,cleaned_up=true,error=caught};
  }

  private void function runGuideLegEdits(required any fixtureSvc,required any svc,required any rb,required numeric userId,required numeric routeId,required struct performance,required struct results) {
    var d=arguments.svc.getDraft(arguments.userId,arguments.routeId);
    var body={revision=d.revision,draft_request_id=newUuid(),route_name="Guide leg editing fixture",
      planning_inputs=duplicate(arguments.performance),trip_notes="Leg editing fixture notes.",legs=[]};
    for (var leg in d.legs) arrayAppend(body.legs,{user_route_leg_id=leg.user_route_leg_id,content_fingerprint=leg.content_fingerprint,
      distance_nm=20,distance_method="Explicit member fixture allowance.",review_action="replace"});
    d=arguments.svc.saveDraft(arguments.userId,arguments.routeId,body);
    var prior=duplicate(d); var startWaypoint=d.legs[1].start_waypoint_id;
    var waypointResult={};
    queryExecute("INSERT INTO waypoints(name,latitude,longitude,userId,notes) VALUES ('Disposable guide editing stop C','26.5','-79.8',:uid,'Test-only point, not a navigation reference')",
      {uid={value=toString(arguments.userId),cfsqltype="cf_sql_varchar"}},{datasource="fpw",result="local.waypointResult"});
    var waypointC=val(waypointResult.generatedKey);
    var added=arguments.rb.addWaypointLegToUserRouteTest(arguments.userId,arguments.routeId,waypointC);
    ensure(added.SUCCESS,"Guide can append an owned waypoint leg",arguments.results);
    d=added.DATA.GUIDE_CONTEXT;
    ensure(arrayLen(d.legs) EQ 3 AND d.legs[3].distance_missing AND d.legs[3].review_status EQ "unreviewed"
      AND d.revision GT prior.revision,"New guide leg starts missing and unreviewed and advances draft revision",arguments.results);
    ensure(d.legs[1].content_fingerprint EQ prior.legs[1].content_fingerprint AND d.legs[1].review_status EQ prior.legs[1].review_status
      AND d.legs[2].content_fingerprint EQ prior.legs[2].content_fingerprint AND d.legs[2].review_status EQ prior.legs[2].review_status,
      "Appending guide leg preserves unchanged mileage reviews",arguments.results);
    added=arguments.rb.addWaypointLegToUserRouteTest(arguments.userId,arguments.routeId,startWaypoint);
    ensure(added.SUCCESS,"Guide can append a return leg to its owned start waypoint",arguments.results);
    d=added.DATA.GUIDE_CONTEXT;
    body={revision=d.revision,draft_request_id=newUuid(),legs=[]};
    for (var leg in d.legs) arrayAppend(body.legs,{user_route_leg_id=leg.user_route_leg_id,content_fingerprint=leg.content_fingerprint,
      distance_nm=leg.distance_missing ? 14 : leg.distance_nm,distance_method=leg.distance_missing ? "Member fixture plotted worksheet allowance." : leg.distance_method,
      review_action=leg.distance_missing ? "replace" : ""});
    d=arguments.svc.saveDraft(arguments.userId,arguments.routeId,body);
    prior=duplicate(d);
    var expectedIds=[d.legs[3].user_route_leg_id,d.legs[4].user_route_leg_id,d.legs[1].user_route_leg_id,d.legs[2].user_route_leg_id];
    var byId={}; for(var leg in d.legs) byId[toString(leg.user_route_leg_id)]=duplicate(leg);
    var reordered=arguments.rb.reorderUserRouteLegsTest(arguments.userId,arguments.routeId,expectedIds);
    ensure(reordered.SUCCESS,"Guide supports a connected leg reorder",arguments.results);
    d=reordered.DATA.GUIDE_CONTEXT;
    var stable=true;
    for(var i=1;i LTE arrayLen(d.legs);i++) {
      var key=toString(d.legs[i].user_route_leg_id);
      stable=stable AND d.legs[i].user_route_leg_id EQ expectedIds[i] AND d.legs[i].leg_key EQ byId[key].leg_key
        AND d.legs[i].content_fingerprint EQ byId[key].content_fingerprint AND d.legs[i].review_status EQ byId[key].review_status;
    }
    ensure(stable AND d.revision GT prior.revision,"Connected reorder preserves stable leg mappings and reviews while advancing revision",arguments.results);
    prior=duplicate(d);
    var rejected=arguments.rb.reorderUserRouteLegsTest(arguments.userId,arguments.routeId,[expectedIds[1],expectedIds[3],expectedIds[2],expectedIds[4]]);
    ensure(!rejected.SUCCESS AND rejected.ERROR.CODE EQ "ROUTE_CONTINUITY_INVALID","Guide destination order with consecutive duplicate stops is rejected",arguments.results);
    d=arguments.svc.getDraft(arguments.userId,arguments.routeId);
    ensure(d.revision EQ prior.revision AND d.legs[2].user_route_leg_id EQ prior.legs[2].user_route_leg_id,
      "Rejected reorder preserves guide order and revision",arguments.results);
    var removed=arguments.rb.removeLegFromUserRouteTest(arguments.userId,arguments.routeId,d.legs[2].user_route_leg_id);
    ensure(removed.SUCCESS,"Guide middle-leg removal reconnects the following endpoint pair",arguments.results);
    d=removed.DATA.GUIDE_CONTEXT;
    ensure(arrayLen(d.legs) EQ 3 AND d.legs[2].user_route_leg_id EQ prior.legs[3].user_route_leg_id
      AND d.legs[2].start_waypoint_id EQ waypointC AND d.legs[2].end_waypoint_id EQ prior.legs[3].end_waypoint_id
      AND d.legs[2].distance_missing AND d.legs[2].review_status EQ "unreviewed" AND !arrayLen(d.legs[2].source_ids)
      AND d.revision GT prior.revision,"Reconnected guide leg loses stale mileage provenance and review",arguments.results);
    ensure(d.legs[1].content_fingerprint EQ prior.legs[1].content_fingerprint AND d.legs[1].review_status EQ prior.legs[1].review_status
      AND d.legs[3].content_fingerprint EQ prior.legs[4].content_fingerprint AND d.legs[3].review_status EQ prior.legs[4].review_status,
      "Guide removal preserves unchanged neighboring reviews",arguments.results);
    prior=duplicate(d);
    removed=arguments.rb.removeLegFromUserRouteTest(arguments.userId,arguments.routeId,d.legs[3].user_route_leg_id);
    ensure(removed.SUCCESS AND arrayLen(removed.DATA.GUIDE_CONTEXT.legs) EQ 2
      AND removed.DATA.GUIDE_CONTEXT.revision GT prior.revision,"Terminal guide leg removal advances revision without inventing mileage",arguments.results);
    d=removed.DATA.GUIDE_CONTEXT;
    var expectedKeys=[d.legs[1].leg_key,d.legs[2].leg_key];
    d=arguments.svc.saveDraft(arguments.userId,arguments.routeId,{revision=d.revision,draft_request_id=newUuid(),trip_notes="Edited leg mapping persists."});
    var reopened=arguments.rb.getUserRouteTest(arguments.userId,arguments.routeId);
    ensure(reopened.SUCCESS AND reopened.DATA.GUIDE_CONTEXT.legs[1].leg_key EQ expectedKeys[1]
      AND reopened.DATA.GUIDE_CONTEXT.legs[2].leg_key EQ expectedKeys[2] AND reopened.DATA.GUIDE_CONTEXT.legs[2].distance_missing
      AND reopened.DATA.GUIDE_CONTEXT.trip_notes EQ "Edited leg mapping persists.","Edited guide planning draft reopens with stable mapping and missing mileage",arguments.results);
    body={revision=d.revision,draft_request_id=newUuid(),legs=[]};
    for(var leg in d.legs) if(leg.distance_missing) arrayAppend(body.legs,{user_route_leg_id=leg.user_route_leg_id,content_fingerprint=leg.content_fingerprint,
      distance_nm=30,distance_method="Member replacement allowance after endpoint review.",review_action="replace"});
    d=arguments.svc.saveDraft(arguments.userId,arguments.routeId,body);
    var saved=arguments.rb.saveGuideTripTest(arguments.userId,arguments.routeId,{revision=d.revision,save_request_id=newUuid()});
    var edit=arguments.rb.routegenGetEditContextTest(arguments.userId,saved.DATA.route_code);
    ensure(saved.SUCCESS AND edit.SUCCESS AND arrayLen(edit.DATA.GUIDE_CONTEXT.legs) EQ 2
      AND edit.DATA.GUIDE_CONTEXT.legs[1].leg_key EQ expectedKeys[1] AND edit.DATA.GUIDE_CONTEXT.legs[2].leg_key EQ expectedKeys[2]
      AND arguments.svc.validateReadiness(arguments.userId,saved.DATA.route_instance_id).allowed,
      "Complete edited guide saves and reopens stable reviewed leg mapping",arguments.results);
  }

  private void function runGuideDestinationReorder(required any fixtureSvc,required any svc,required any rb,required numeric userId,required struct performance,required struct results) {
    var d=arguments.fixtureSvc.importTrip(arguments.userId,{template_key="fort-lauderdale-bimini",template_version=1,import_request_id=newUuid(),create_another=true});
    var routeId=d.user_route_id; var origin=d.legs[1].start_waypoint_id; var stopB=d.legs[1].end_waypoint_id;
    var removed=arguments.rb.removeLegFromUserRouteTest(arguments.userId,routeId,d.legs[2].user_route_leg_id);
    var inserted={};
    queryExecute("INSERT INTO waypoints(name,latitude,longitude,userId,notes) VALUES ('Disposable destination reorder C','26.3','-79.6',:uid,'Synthetic test-only point')",
      {uid={value=toString(arguments.userId),cfsqltype="cf_sql_varchar"}},{datasource="fpw",result="local.inserted"});
    var stopC=val(inserted.generatedKey);
    arguments.rb.addWaypointLegToUserRouteTest(arguments.userId,routeId,stopC);
    var added=arguments.rb.addWaypointLegToUserRouteTest(arguments.userId,routeId,origin);
    d=added.DATA.GUIDE_CONTEXT;
    ensure(arrayLen(d.legs) EQ 3 AND d.legs[1].end_waypoint_id EQ stopB AND d.legs[2].end_waypoint_id EQ stopC,
      "Destination reorder fixture is A-B-C-A",arguments.results);
    var plotted=arguments.rb.saveRouteLegOverrideGeometryTest(arguments.userId,routeId,d.legs[2].user_route_leg_id,[
      {lat=d.legs[2].start_lat,lng=d.legs[2].start_lng},{lat=d.legs[2].end_lat,lng=d.legs[2].end_lng}]);
    d=arguments.svc.getDraft(arguments.userId,routeId);
    var body={revision=d.revision,draft_request_id=newUuid(),planning_inputs=duplicate(arguments.performance),legs=[]};
    for(var leg in d.legs) arrayAppend(body.legs,{user_route_leg_id=leg.user_route_leg_id,content_fingerprint=leg.content_fingerprint,
      distance_nm=20,distance_method="Disposable member planning allowance before stop reorder.",review_action="replace"});
    d=arguments.svc.saveDraft(arguments.userId,routeId,body);
    var prior=duplicate(d); var ids=[d.legs[2].user_route_leg_id,d.legs[1].user_route_leg_id,d.legs[3].user_route_leg_id];
    var swapped=arguments.rb.reorderUserRouteLegsTest(arguments.userId,routeId,ids);
    ensure(swapped.SUCCESS,"Guide destination controls reorder A-B-C-A into A-C-B-A",arguments.results);
    d=swapped.DATA.GUIDE_CONTEXT;
    ensure(d.legs[1].start_waypoint_id EQ origin AND d.legs[1].end_waypoint_id EQ stopC
      AND d.legs[2].start_waypoint_id EQ stopC AND d.legs[2].end_waypoint_id EQ stopB
      AND d.legs[3].start_waypoint_id EQ stopB AND d.legs[3].end_waypoint_id EQ origin,
      "Reordered destination starts are rewired from the original origin",arguments.results);
    var cleared=true;
    for(var i=1;i LTE 3;i++) cleared=cleared AND d.legs[i].user_route_leg_id EQ ids[i] AND d.legs[i].distance_missing
      AND d.legs[i].review_status EQ "unreviewed" AND !arrayLen(d.legs[i].source_ids) AND d.legs[i].geometry_kind EQ "schematic";
    var overrides=queryExecute("SELECT COUNT(*) AS n FROM route_leg_user_overrides WHERE user_id=:uid AND route_id=:rid",
      {uid={value=arguments.userId,cfsqltype="cf_sql_integer"},rid={value=routeId,cfsqltype="cf_sql_integer"}},{datasource="fpw"});
    ensure(cleared AND val(overrides.n[1]) EQ 0 AND d.revision GT prior.revision,
      "Changed reorder pairs clear mileage, sources, review and plotted overrides and advance revision",arguments.results);
    d=arguments.svc.saveDraft(arguments.userId,routeId,{revision=d.revision,draft_request_id=newUuid(),trip_notes="Destination order retained in draft."});
    var reopened=arguments.rb.getUserRouteTest(arguments.userId,routeId).DATA.GUIDE_CONTEXT;
    ensure(reopened.legs[1].user_route_leg_id EQ ids[1] AND reopened.legs[1].distance_missing AND reopened.legs[2].start_waypoint_id EQ stopC
      AND reopened.trip_notes EQ "Destination order retained in draft.","Reordered incomplete draft saves and reopens stable mapping",arguments.results);
    prior=duplicate(reopened);
    var invalid=arguments.rb.reorderUserRouteLegsTest(arguments.userId,routeId,[ids[3],ids[1],ids[2]]);
    d=arguments.svc.getDraft(arguments.userId,routeId);
    ensure(!invalid.SUCCESS AND invalid.ERROR.CODE EQ "ROUTE_CONTINUITY_INVALID" AND d.revision EQ prior.revision
      AND d.legs[1].user_route_leg_id EQ prior.legs[1].user_route_leg_id,
      "Adjacent duplicate origin is rejected atomically without revision or order mutation",arguments.results);
    // A distinct waypoint at the origin must also be rejected as a zero-length first pair.
    queryExecute("INSERT INTO waypoints(name,latitude,longitude,userId,notes) SELECT 'Disposable same-coordinate origin',latitude,longitude,userId,'Synthetic test-only duplicate' FROM waypoints WHERE wpId=:origin AND userId=:uid",
      {origin={value=origin,cfsqltype="cf_sql_integer"},uid={value=toString(arguments.userId),cfsqltype="cf_sql_varchar"}},{datasource="fpw",result="local.inserted"});
    var sameOrigin=val(inserted.generatedKey);
    queryExecute("UPDATE user_route_legs SET end_waypoint_id=:wp WHERE id=:leg AND user_route_id=:rid",
      {wp={value=sameOrigin,cfsqltype="cf_sql_integer"},leg={value=ids[3],cfsqltype="cf_sql_integer"},rid={value=routeId,cfsqltype="cf_sql_integer"}},{datasource="fpw"});
    prior=arguments.svc.getDraft(arguments.userId,routeId);
    invalid=arguments.rb.reorderUserRouteLegsTest(arguments.userId,routeId,[ids[3],ids[1],ids[2]]);
    d=arguments.svc.getDraft(arguments.userId,routeId);
    ensure(!invalid.SUCCESS AND d.revision EQ prior.revision AND d.legs[1].user_route_leg_id EQ prior.legs[1].user_route_leg_id,
      "Distinct destination at identical coordinates is rejected without mutation",arguments.results);
    queryExecute("UPDATE user_route_legs SET end_waypoint_id=:wp WHERE id=:leg AND user_route_id=:rid",
      {wp={value=origin,cfsqltype="cf_sql_integer"},leg={value=ids[3],cfsqltype="cf_sql_integer"},rid={value=routeId,cfsqltype="cf_sql_integer"}},{datasource="fpw"});
    queryExecute("INSERT INTO waypoints(name,latitude,longitude,userId,notes) VALUES ('Disposable unchanged destination D','26.4','-79.7',:uid,'Synthetic test-only point')",
      {uid={value=toString(arguments.userId),cfsqltype="cf_sql_varchar"}},{datasource="fpw",result="local.inserted"});
    var stopD=val(inserted.generatedKey);
    added=arguments.rb.addWaypointLegToUserRouteTest(arguments.userId,routeId,stopD);d=added.DATA.GUIDE_CONTEXT;
    arguments.rb.saveRouteLegOverrideGeometryTest(arguments.userId,routeId,d.legs[4].user_route_leg_id,[
      {lat=d.legs[4].start_lat,lng=d.legs[4].start_lng},{lat=d.legs[4].end_lat,lng=d.legs[4].end_lng}]);
    d=arguments.svc.getDraft(arguments.userId,routeId);
    body={revision=d.revision,draft_request_id=newUuid(),legs=[]};
    for(var leg in d.legs) arrayAppend(body.legs,{user_route_leg_id=leg.user_route_leg_id,content_fingerprint=leg.content_fingerprint,
      distance_nm=20,distance_method="Disposable member planning allowance after stop review.",review_action="replace"});
    d=arguments.svc.saveDraft(arguments.userId,routeId,body);prior=duplicate(d);
    swapped=arguments.rb.reorderUserRouteLegsTest(arguments.userId,routeId,[ids[2],ids[1],ids[3],d.legs[4].user_route_leg_id]);d=swapped.DATA.GUIDE_CONTEXT;
    ensure(swapped.SUCCESS AND d.legs[4].content_fingerprint EQ prior.legs[4].content_fingerprint
      AND d.legs[4].review_status EQ prior.legs[4].review_status AND d.legs[4].geometry_kind EQ "member_plotted",
      "Unchanged reorder pair retains its review and member-plotted geometry",arguments.results);
    body={revision=d.revision,draft_request_id=newUuid(),trip_notes=repeatString("Long snapshot QA. ",600),legs=[]};
    for(var leg in d.legs) if(leg.distance_missing) arrayAppend(body.legs,{user_route_leg_id=leg.user_route_leg_id,content_fingerprint=leg.content_fingerprint,
      distance_nm=25,distance_method="New member allowance for reordered endpoint pair.",review_action="replace"});
    d=arguments.svc.saveDraft(arguments.userId,routeId,body);
    var saved=arguments.rb.saveGuideTripTest(arguments.userId,routeId,{revision=d.revision,save_request_id=newUuid()});
    var snapshotQuery=queryExecute("SELECT id,routegen_inputs_json,CHAR_LENGTH(routegen_inputs_json) AS db_chars,OCTET_LENGTH(routegen_inputs_json) AS db_bytes,JSON_VALID(routegen_inputs_json) AS valid_json FROM route_instances WHERE id=:id",
      {id={value=saved.DATA.route_instance_id,cfsqltype="cf_sql_integer"}},{datasource="fpw"});
    var snapshotCheck={db_chars=snapshotQuery.db_chars[1],db_bytes=snapshotQuery.db_bytes[1],valid_json=snapshotQuery.valid_json[1],cf_chars=len(snapshotQuery.routegen_inputs_json[1]),cf_is_json=isJSON(snapshotQuery.routegen_inputs_json[1])};
    fileWrite(expandPath("/fpw/.codex-snapshots/bahamas-guide-20261107/readiness-20261109/backend/reorder-snapshot-check.json"),serializeJSON(snapshotCheck),"utf-8");
    if (!snapshotCheck.cf_is_json) fileWrite(expandPath("/fpw/.codex-snapshots/bahamas-guide-20261107/readiness-20261109/backend/reorder-invalid-snapshot.json"),snapshotQuery.routegen_inputs_json[1],"utf-8");
    ensure(snapshotCheck.db_chars GT 64000 AND snapshotCheck.cf_chars EQ snapshotCheck.db_chars AND snapshotCheck.cf_is_json,
      "Guide snapshots over64000characters are retrieved completely for saved reopen",arguments.results);
    var edit=arguments.rb.routegenGetEditContextTest(arguments.userId,saved.DATA.route_code);
    ensure(saved.SUCCESS AND edit.SUCCESS AND arrayLen(edit.DATA.GUIDE_CONTEXT.legs) EQ 4 AND edit.DATA.GUIDE_CONTEXT.legs[1].end_waypoint_id EQ stopB
      AND edit.DATA.GUIDE_CONTEXT.legs[2].end_waypoint_id EQ stopC AND arguments.svc.validateReadiness(arguments.userId,saved.DATA.route_instance_id).allowed,
      "Reordered complete guide saves and reopens reviewed destination mapping",arguments.results);
  }

  private void function runOwnerSuppliedSourceEstimates(required any missingSvc,required any svc,required any rb,required numeric userId,required struct performance,required struct results) {
    var currentSvc=new fpw.tests.support.GuideTripFixtureService().init("fpw");
    var old=arguments.missingSvc.importTrip(arguments.userId,{template_key="fort-lauderdale-bimini",template_version=1,import_request_id=newUuid(),create_another=true});
    var oldBody={revision=old.revision,draft_request_id=newUuid(),planning_inputs=duplicate(arguments.performance),legs=[]};
    for(var leg in old.legs) arrayAppend(oldBody.legs,{user_route_leg_id=leg.user_route_leg_id,content_fingerprint=leg.content_fingerprint,
      distance_nm=42,distance_method="Existing member planning allowance before editorial defaults change.",review_action="replace"});
    old=arguments.svc.saveDraft(arguments.userId,old.user_route_id,oldBody);
    var oldHashes=queryExecute("SELECT SHA2(source_snapshot_json,256) AS source_hash,SHA2(leg_state_json,256) AS leg_hash,draft_revision FROM guide_route_imports WHERE user_id=:uid AND user_route_id=:rid",
      {uid={value=arguments.userId,cfsqltype="cf_sql_integer"},rid={value=old.user_route_id,cfsqltype="cf_sql_integer"}},{datasource="fpw"});
    var reuse=currentSvc.importTrip(arguments.userId,{template_key="fort-lauderdale-bimini",template_version=1,import_request_id=newUuid()});
    var reusedHashes=queryExecute("SELECT SHA2(source_snapshot_json,256) AS source_hash,SHA2(leg_state_json,256) AS leg_hash,draft_revision FROM guide_route_imports WHERE user_id=:uid AND user_route_id=:rid",
      {uid={value=arguments.userId,cfsqltype="cf_sql_integer"},rid={value=old.user_route_id,cfsqltype="cf_sql_integer"}},{datasource="fpw"});
    ensure(reuse.user_route_id EQ old.user_route_id AND reuse.legs[1].distance_nm EQ 42
      AND reuse.legs[1].review_status EQ "member_replaced" AND !isNumeric(reuse.source_snapshot.legs[1].distance_nm)
      AND oldHashes.source_hash[1] EQ reusedHashes.source_hash[1] AND oldHashes.leg_hash[1] EQ reusedHashes.leg_hash[1]
      AND oldHashes.draft_revision[1] EQ reusedHashes.draft_revision[1],
      "Current editorial estimates do not overwrite a reused copy's old snapshot, member mileage or reviews",arguments.results);
    var d=currentSvc.importTrip(arguments.userId,{template_key="fort-lauderdale-bimini",template_version=1,import_request_id=newUuid(),create_another=true});
    var routeId=d.user_route_id;
    ensure(routeId NEQ old.user_route_id AND arrayLen(d.legs) EQ 2 AND d.legs[1].distance_nm EQ 50.3 AND d.legs[2].distance_nm EQ 50.3
      AND abs(d.totals.known_distance_nm-100.6) LT 0.00001,
      "A new current-template copy imports two50.3nm planning estimates",arguments.results);
    var label="Example route distance " & chr(8212) & " review for your trip.";
    var honest=true;
    for(var leg in d.legs) honest=honest AND leg.distance_kind EQ "source_reported_estimate" AND find(label,leg.distance_method) EQ 1
      AND findNoCase("Owner-supplied planning estimate",leg.distance_method) GT 0 AND !arrayLen(leg.source_ids)
      AND structIsEmpty(leg.source_dates) AND leg.geometry_kind EQ "schematic" AND leg.review_status EQ "unreviewed";
    ensure(honest,"Owner-supplied provenance, unspecified source dates, schematic geometry and unreviewed state transfer together",arguments.results);
    ensure(!d.planning_inputs.performance_confirmed AND !d.totals.complete,
      "Prefilled source mileage does not confirm performance or make a complete trip",arguments.results);
    var body={revision=d.revision,draft_request_id=newUuid(),planning_inputs=duplicate(arguments.performance)};
    d=arguments.svc.saveDraft(arguments.userId,routeId,body);
    var saved=arguments.rb.saveGuideTripTest(arguments.userId,routeId,{revision=d.revision,save_request_id=newUuid()});
    var readiness=arguments.svc.validateReadiness(arguments.userId,saved.DATA.route_instance_id);
    ensure(saved.SUCCESS AND !readiness.allowed AND readiness.code EQ "GUIDE_REVIEW_REQUIRED",
      "Source estimate alone does not satisfy the float-plan mileage review gate",arguments.results);
    var blocked=arguments.rb.buildFloatPlansFromRouteTest(userId=arguments.userId,routeInstanceId=saved.DATA.route_instance_id);
    ensure(!blocked.SUCCESS AND blocked.ERROR.CODE EQ "GUIDE_REVIEW_REQUIRED",
      "Actual float-plan creation rejects unreviewed owner-supplied mileage",arguments.results);
    body={revision=d.revision,draft_request_id=newUuid(),legs=[]};
    for(var leg in d.legs) arrayAppend(body.legs,{user_route_leg_id=leg.user_route_leg_id,content_fingerprint=leg.content_fingerprint,
      distance_nm=leg.distance_nm,distance_method=leg.distance_method,review_action="confirm"});
    d=arguments.svc.saveDraft(arguments.userId,routeId,body);
    ensure(d.legs[1].review_status EQ "member_confirmed" AND d.legs[2].review_status EQ "member_confirmed"
      AND d.legs[1].distance_kind EQ "source_reported_estimate" AND d.legs[2].distance_kind EQ "source_reported_estimate",
      "Member confirmation records review without relabeling owner estimates as independently verified",arguments.results);
    saved=arguments.rb.saveGuideTripTest(arguments.userId,routeId,{revision=d.revision,save_request_id=newUuid()});
    var reopened=arguments.rb.routegenGetEditContextTest(arguments.userId,saved.DATA.route_code).DATA.GUIDE_CONTEXT;
    var snapshot=arguments.svc.getSnapshotForInstance(saved.DATA.route_instance_id);
    ensure(reopened.legs[1].distance_nm EQ 50.3 AND reopened.legs[1].distance_kind EQ "source_reported_estimate"
      AND snapshot.legs[1].distance_method EQ d.legs[1].distance_method AND snapshot.legs[1].geometry_kind EQ "schematic"
      AND snapshot.source_snapshot.legs[1].distance_nm EQ 50.3 AND arguments.svc.validateReadiness(arguments.userId,saved.DATA.route_instance_id).allowed,
      "Reviewed source estimates save and reopen with original provenance and geometry meaning",arguments.results);
    body={revision=d.revision,draft_request_id=newUuid(),legs=[{user_route_leg_id=d.legs[1].user_route_leg_id,
      content_fingerprint=d.legs[1].content_fingerprint,distance_nm=55.8,distance_method="Member replacement allowance after intended-path review.",review_action=""}]};
    d=arguments.svc.saveDraft(arguments.userId,routeId,body);
    ensure(d.legs[1].distance_nm EQ 55.8 AND d.legs[1].distance_kind EQ "member_entered" AND d.legs[1].review_status EQ "unreviewed"
      AND d.legs[2].distance_nm EQ 50.3 AND d.legs[2].review_status EQ "member_confirmed"
      AND d.source_snapshot.legs[1].distance_nm EQ 50.3 AND !arguments.svc.validateReadiness(arguments.userId,saved.DATA.route_instance_id).allowed,
      "Member replacement invalidates only the edited leg and keeps the original source snapshot",arguments.results);
    d=arguments.svc.saveDraft(arguments.userId,routeId,{revision=d.revision,draft_request_id=newUuid(),legs=[{
      user_route_leg_id=d.legs[1].user_route_leg_id,content_fingerprint=d.legs[1].content_fingerprint,
      distance_nm=d.legs[1].distance_nm,distance_method=d.legs[1].distance_method,review_action="confirm"}]});
    saved=arguments.rb.saveGuideTripTest(arguments.userId,routeId,{revision=d.revision,save_request_id=newUuid()});
    reopened=arguments.rb.routegenGetEditContextTest(arguments.userId,saved.DATA.route_code).DATA.GUIDE_CONTEXT;
    ensure(reopened.legs[1].distance_nm EQ 55.8 AND reopened.legs[1].distance_kind EQ "member_entered"
      AND reopened.legs[1].review_status EQ "member_confirmed" AND reopened.legs[2].distance_kind EQ "source_reported_estimate",
      "Reviewed member replacement and unchanged source estimate remain distinct after save/reopen",arguments.results);
    d=arguments.svc.saveDraft(arguments.userId,routeId,{revision=d.revision,draft_request_id=newUuid(),legs=[{
      user_route_leg_id=d.legs[1].user_route_leg_id,content_fingerprint=d.legs[1].content_fingerprint,
      distance_nm="",distance_method="Member removed this allowance; replacement source or method is pending.",review_action=""}]});
    reopened=arguments.rb.getUserRouteTest(arguments.userId,routeId).DATA.GUIDE_CONTEXT;
    ensure(reopened.legs[1].distance_missing AND reopened.legs[1].review_status EQ "unreviewed"
      AND abs(reopened.totals.known_distance_nm-50.3) LT 0.00001 AND !reopened.totals.complete AND reopened.has_newer_draft,
      "Clearing a prefilled estimate restores incomplete totals and missing mileage on reopen",arguments.results);
  }

  private void function runMileageAttributionChanges(required any svc,required any rb,required any fp,required numeric userId,required struct performance,required struct results) {
    var importer=new fpw.tests.support.GuideTripFixtureService().init("fpw");
    var d=importer.importTrip(arguments.userId,{template_key="fort-lauderdale-bimini",template_version=1,import_request_id=newUuid(),create_another=true});
    var routeId=d.user_route_id;
    var importedMethod=d.legs[1].distance_method;
    // Seed active provenance only in this disposable copy; leave the source snapshot untouched.
    var seeded=queryExecute("SELECT leg_state_json FROM guide_route_imports WHERE user_id=:uid AND user_route_id=:rid",
      {uid={value=arguments.userId,cfsqltype="cf_sql_integer"},rid={value=routeId,cfsqltype="cf_sql_integer"}},{datasource="fpw"});
    var activeLegs=deserializeJSON(seeded.leg_state_json[1]);
    activeLegs[toString(d.legs[1].user_route_leg_id)].source_ids=["TEST_MEMBER_SOURCE"];
    activeLegs[toString(d.legs[1].user_route_leg_id)].source_dates={accessed="2026-11-09",effective="test-only"};
    queryExecute("UPDATE guide_route_imports SET leg_state_json=:j WHERE user_id=:uid AND user_route_id=:rid",
      {j={value=serializeJSON(activeLegs),cfsqltype="cf_sql_longvarchar"},uid={value=arguments.userId,cfsqltype="cf_sql_integer"},
       rid={value=routeId,cfsqltype="cf_sql_integer"}},{datasource="fpw"});
    d=arguments.svc.getDraft(arguments.userId,routeId);
    ensure(arrayLen(d.legs[1].source_ids) EQ 1 AND !structIsEmpty(d.legs[1].source_dates),
      "Disposable attribution fixture starts with nonempty active source references and dates",arguments.results);
    var body={revision=d.revision,draft_request_id=newUuid(),planning_inputs=duplicate(arguments.performance),legs=[]};
    for(var leg in d.legs) arrayAppend(body.legs,{user_route_leg_id=leg.user_route_leg_id,content_fingerprint=leg.content_fingerprint,
      distance_nm=leg.distance_nm,distance_method=leg.distance_method,review_action="confirm"});
    d=arguments.svc.saveDraft(arguments.userId,routeId,body);
    var saved=arguments.rb.saveGuideTripTest(arguments.userId,routeId,{revision=d.revision,save_request_id=newUuid()});
    var instanceId=saved.DATA.route_instance_id;
    var originalSource=queryExecute("SELECT SHA2(source_snapshot_json,256) AS source_hash FROM guide_route_imports WHERE user_id=:uid AND user_route_id=:rid",
      {uid={value=arguments.userId,cfsqltype="cf_sql_integer"},rid={value=routeId,cfsqltype="cf_sql_integer"}},{datasource="fpw"}).source_hash[1];
    var secondReview=d.legs[2].review_fingerprint;
    body={revision=d.revision,draft_request_id=newUuid(),legs=[{user_route_leg_id=d.legs[1].user_route_leg_id,
      content_fingerprint=d.legs[1].content_fingerprint,distance_nm=60,distance_method=importedMethod,review_action=""}]};
    d=arguments.svc.saveDraft(arguments.userId,routeId,body);
    ensure(d.legs[1].distance_nm EQ 60 AND d.legs[1].distance_kind EQ "member_entered" AND d.legs[1].distance_method EQ ""
      AND !arrayLen(d.legs[1].source_ids) AND structIsEmpty(d.legs[1].source_dates) AND d.legs[1].review_status EQ "unreviewed",
      "Numeric edit clears forged retained import attribution and records an unreviewed member estimate",arguments.results);
    ensure(d.legs[2].review_fingerprint EQ secondReview AND d.legs[2].review_status EQ "member_confirmed"
      AND d.source_snapshot.legs[1].distance_nm EQ 50.3 AND d.source_snapshot.legs[1].distance_method EQ importedMethod,
      "Only the edited leg loses review while immutable imported mileage and attribution remain",arguments.results);
    var retry=arguments.svc.saveDraft(arguments.userId,routeId,body);
    var reopened=arguments.rb.getUserRouteTest(arguments.userId,routeId).DATA.GUIDE_CONTEXT;
    ensure(retry.reused AND retry.revision EQ d.revision AND reopened.legs[1].distance_method EQ ""
      AND reopened.legs[1].distance_method_missing AND len(reopened.legs[1].missing_input) GT 0,
      "Blank-attribution draft retry and reopen retain the missing source requirement",arguments.results);
    ensure(!d.totals.complete AND d.totals.missing_method_count EQ 1 AND d.totals.missing_leg_count EQ 0
      AND abs(d.totals.known_distance_nm-110.3) LT 0.00001 AND isNumeric(d.totals.known_run_hours)
      AND isNumeric(d.totals.required_fuel_us_gal) AND !isNumeric(d.totals.usable_above_requirement_us_gal),
      "Attribution-pending draft keeps numeric estimates but incomplete totals and no sufficiency claim",arguments.results);
    var denied=false;
    try { arguments.rb.saveGuideTripTest(arguments.userId,routeId,{revision=d.revision,save_request_id=newUuid()}); }
    catch(any e) { denied=e.type EQ "FPW.Guide.INCOMPLETE"; }
    ensure(denied,"Missing source or method blocks complete trip save while allowing planning drafts",arguments.results);
    denied=false;
    try { arguments.svc.saveDraft(arguments.userId,routeId,{revision=d.revision,draft_request_id=newUuid(),legs=[{
      user_route_leg_id=d.legs[1].user_route_leg_id,content_fingerprint=d.legs[1].content_fingerprint,
      distance_nm=d.legs[1].distance_nm,distance_method="",review_action="confirm"}]}); }
    catch(any e) { denied=e.type EQ "FPW.Guide.METHOD_REQUIRED"; }
    ensure(denied,"Member review cannot confirm mileage without source or method",arguments.results);
    var build=arguments.rb.buildFloatPlansFromRouteTest(userId=arguments.userId,routeInstanceId=instanceId);
    var direct=arguments.fp.saveForTest(arguments.userId,{FLOATPLAN={route_instance_id=instanceId,floatPlanName="Pending attribution bypass test"}});
    var activation=arguments.fp.prepareForTest(arguments.userId,0,instanceId);
    ensure(!build.SUCCESS AND !direct.SUCCESS AND !activation.SUCCESS,
      "All three float-plan boundaries reject a newer draft with missing attribution",arguments.results);
    // Simulate a stale/forged generated context, using only this disposable fixture.
    var originalInputs=queryExecute("SELECT routegen_inputs_json FROM route_instances WHERE id=:id AND user_id=:uid",
      {id={value=instanceId,cfsqltype="cf_sql_integer"},uid={value=toString(arguments.userId),cfsqltype="cf_sql_varchar"}},{datasource="fpw"}).routegen_inputs_json[1];
    var originalGeneratedRevision=d.generated_revision;
    try {
      var forged=deserializeJSON(originalInputs); forged.guide_context=arguments.svc.snapshot(d);
      queryExecute("UPDATE route_instances SET routegen_inputs_json=:j WHERE id=:id AND user_id=:uid",
        {j={value=serializeJSON(forged),cfsqltype="cf_sql_longvarchar"},id={value=instanceId,cfsqltype="cf_sql_integer"},
         uid={value=toString(arguments.userId),cfsqltype="cf_sql_varchar"}},{datasource="fpw"});
      queryExecute("UPDATE guide_route_imports SET generated_revision=:rev WHERE user_id=:uid AND user_route_id=:rid",
        {rev={value=d.revision,cfsqltype="cf_sql_integer"},uid={value=arguments.userId,cfsqltype="cf_sql_integer"},rid={value=routeId,cfsqltype="cf_sql_integer"}},{datasource="fpw"});
      var readiness=arguments.svc.validateReadiness(arguments.userId,instanceId);
      ensure(!readiness.allowed AND readiness.code EQ "GUIDE_METHOD_REQUIRED",
        "Shared readiness explicitly rejects a forged current saved context with missing attribution",arguments.results);
    } finally {
      queryExecute("UPDATE route_instances SET routegen_inputs_json=:j WHERE id=:id AND user_id=:uid",
        {j={value=originalInputs,cfsqltype="cf_sql_longvarchar"},id={value=instanceId,cfsqltype="cf_sql_integer"},
         uid={value=toString(arguments.userId),cfsqltype="cf_sql_varchar"}},{datasource="fpw"});
      queryExecute("UPDATE guide_route_imports SET generated_revision=:rev WHERE user_id=:uid AND user_route_id=:rid",
        {rev={value=originalGeneratedRevision,cfsqltype="cf_sql_integer"},uid={value=arguments.userId,cfsqltype="cf_sql_integer"},rid={value=routeId,cfsqltype="cf_sql_integer"}},{datasource="fpw"});
    }
    d=arguments.svc.getDraft(arguments.userId,routeId);
    d=arguments.svc.saveDraft(arguments.userId,routeId,{revision=d.revision,draft_request_id=newUuid(),legs=[{
      user_route_leg_id=d.legs[1].user_route_leg_id,content_fingerprint=d.legs[1].content_fingerprint,distance_nm=60,
      distance_method="Member's revised planning allowance after intended-path review.",review_action=""}]});
    saved=arguments.rb.saveGuideTripTest(arguments.userId,routeId,{revision=d.revision,save_request_id=newUuid()});
    ensure(d.totals.complete AND d.legs[1].review_status EQ "unreviewed"
      AND !arguments.svc.validateReadiness(arguments.userId,saved.DATA.route_instance_id).allowed,
      "Supplying a method restores complete calculations but does not supply member review",arguments.results);
    d=arguments.svc.saveDraft(arguments.userId,routeId,{revision=d.revision,draft_request_id=newUuid(),legs=[{
      user_route_leg_id=d.legs[1].user_route_leg_id,content_fingerprint=d.legs[1].content_fingerprint,distance_nm=60,
      distance_method=d.legs[1].distance_method,review_action="confirm"}]});
    arguments.rb.saveGuideTripTest(arguments.userId,routeId,{revision=d.revision,save_request_id=newUuid()});
    var reviewedMemberFingerprint=d.legs[1].review_fingerprint;
    d=arguments.svc.saveDraft(arguments.userId,routeId,{revision=d.revision,draft_request_id=newUuid(),legs=[{
      user_route_leg_id=d.legs[1].user_route_leg_id,content_fingerprint=d.legs[1].content_fingerprint,
      distance_nm=61,distance_method=d.legs[1].distance_method,review_action=""}]});
    ensure(len(reviewedMemberFingerprint) AND d.legs[1].review_status EQ "unreviewed" AND !len(d.legs[1].review_fingerprint)
      AND d.legs[1].distance_kind EQ "member_entered" AND d.legs[1].distance_method EQ "" AND d.legs[1].distance_method_missing,
      "A second numeric edit also clears stale member-entered attribution",arguments.results);
    d=arguments.svc.saveDraft(arguments.userId,routeId,{revision=d.revision,draft_request_id=newUuid(),legs=[{
      user_route_leg_id=d.legs[1].user_route_leg_id,content_fingerprint=d.legs[1].content_fingerprint,
      distance_nm=62,distance_method="New member allowance entered explicitly with the 62 nm change.",review_action=""}]});
    ensure(d.legs[1].distance_method EQ "New member allowance entered explicitly with the 62 nm change."
      AND !d.legs[1].distance_method_missing AND d.legs[1].review_status EQ "unreviewed",
      "An explicitly different replacement method in the same numeric edit is retained",arguments.results);
    d=arguments.svc.saveDraft(arguments.userId,routeId,{revision=d.revision,draft_request_id=newUuid(),legs=[{
      user_route_leg_id=d.legs[1].user_route_leg_id,content_fingerprint=d.legs[1].content_fingerprint,
      distance_nm=63,distance_method=importedMethod,review_action=""}]});
    ensure(d.legs[1].distance_method EQ "" AND d.legs[1].review_status EQ "unreviewed",
      "Reposting original owner attribution after a member edit does not restore it as active provenance",arguments.results);
    d=arguments.svc.saveDraft(arguments.userId,routeId,{revision=d.revision,draft_request_id=newUuid(),legs=[{
      user_route_leg_id=d.legs[1].user_route_leg_id,content_fingerprint=d.legs[1].content_fingerprint,distance_nm=63,
      distance_method="Current member source recorded for the 63 nm planning estimate.",review_action="confirm"}]});
    saved=arguments.rb.saveGuideTripTest(arguments.userId,routeId,{revision=d.revision,save_request_id=newUuid()});
    reopened=arguments.rb.routegenGetEditContextTest(arguments.userId,saved.DATA.route_code).DATA.GUIDE_CONTEXT;
    var currentSource=queryExecute("SELECT SHA2(source_snapshot_json,256) AS source_hash FROM guide_route_imports WHERE user_id=:uid AND user_route_id=:rid",
      {uid={value=arguments.userId,cfsqltype="cf_sql_integer"},rid={value=routeId,cfsqltype="cf_sql_integer"}},{datasource="fpw"}).source_hash[1];
    ensure(reopened.legs[1].distance_nm EQ 63 AND reopened.legs[1].distance_kind EQ "member_entered"
      AND len(reopened.legs[1].distance_method) AND arguments.svc.validateReadiness(arguments.userId,saved.DATA.route_instance_id).allowed
      AND originalSource EQ currentSource,
      "Final reviewed member estimate reopens correctly while original import snapshot hash stays unchanged",arguments.results);
  }

  private void function ensure(required boolean value,required string name,required struct results) {
    arrayAppend(arguments.results.items,{name=arguments.name,passed=arguments.value});
    fileWrite(expandPath("/fpw/.codex-snapshots/bahamas-guide-20261107/backend/integration-progress.json"),serializeJSON(arguments.results),"utf-8");
    if (!arguments.value) throw(type="FPW.GuideTest.Assertion",message=arguments.name);
  }
  private string function newUuid() { return lCase(createObject("java","java.util.UUID").randomUUID().toString()); }
}
