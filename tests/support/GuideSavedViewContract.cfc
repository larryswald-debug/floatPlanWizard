component extends="testbox.system.BaseSpec" output=false {
 public struct function runChecks() {
  var results=[];
  var model=new fpw.api.v1.ActiveCruiseViewModelService().init("fpw");
  var voyage=new fpw.api.v1.voyage();
  makePublic(model,"enrichGuideRouteTimeline","guideTimelineForTest");
  makePublic(voyage,"buildGuideFollowCruiseTimeline","guideFollowForTest");
  var inputs={planning_speed_kn=7,underway_burn_us_gph=4,underway_hours_per_day=6,reserve_mode="percentage",reserve_pct=20,idle_burn_us_gph=1,idle_hours_total=2,usable_fuel_us_gal=190,performance_confirmed=true};
  var legs=[{order_index=1,start_name="Florida",end_name="Bimini",distance_nm=60.25,distance_method="Arithmetic test assumption"},{order_index=2,start_name="Bimini",end_name="Florida",distance_nm=60,distance_method="Arithmetic test assumption"}];
  var totals=new fpw.api.v1.GuideTripService().init("fpw").calculateTotals(legs,inputs);
  var guide={planning_inputs=inputs,totals=totals,legs=legs,trip_notes="private-notes-never-public",source_snapshot={private_marker="private-source-marker"}};
  var timeline=model.guideTimelineForTest(guide,{summary={totalNm=120},legs=[{routeLegOrder=1,fromName="Florida",toName="Bimini"},{routeLegOrder=2,fromName="Bimini",toName="Florida"}]});
  arrayAppend(results,{passed=(abs(timeline.legs[1].fuel.legFuelNeededGallons-(60.25/7*4)) LT .0000001),name="Captain uses full precision explicit guide operating point"});
  arrayAppend(results,{passed=(abs(timeline.legs[1].fuel.totalFuelGallons-(120.25/7*4+2)) LT .0000001),name="Captain includes auxiliary once from saved totals"});
  arrayAppend(results,{passed=(abs(timeline.legs[1].fuel.fuelWithReserveGallons-totals.required_fuel_us_gal) LT .0000001),name="Captain preserves saved reserve calculation"});
  var follow=voyage.guideFollowForTest(guide,{"1"={status="COMPLETED",last_update_ts=""}});
  arrayAppend(results,{passed=(abs(val(follow.summary.total_hours)-120.25/7) LT .0000001 AND val(follow.summary.fuel_burn_gph) EQ 4),name="Follow uses explicit guide inputs and precise movement time"});
  arrayAppend(results,{passed=(abs(follow.legs[1].cruise_fuel_gallons-60.25/7*4) LT .0000001 AND follow.legs[1].progress.percent_complete EQ 100),name="Follow preserves progress while estimating guide fuel"});
  arrayAppend(results,{passed=(!find("private-notes-never-public",serializeJSON(follow)) AND !find("private-source-marker",serializeJSON(follow))),name="Public Follow estimate projection omits private notes and source snapshot"});
  var dto=voyage.getOwnerPreviewViewModel({eligible=true,floatPlanId=1,routeInstanceId=2},{
    success=true,mode="preview",floatPlan={id=1},route={routeInstanceId=2},floatPlanInfo={},
    map={routeGeo={type="MultiLineString",coordinates=[[[-80,26],[-79,25]],[[-79,25],[-80,26]]],guide_estimates=true,guide_geometry_sources=["schematic","member_plotted"],private_marker="drop-me"}},
    routeTimeline=timeline});
  arrayAppend(results,{passed=(dto.SUCCESS AND dto.map.routeGeo.guide_estimates AND dto.map.routeGeo.guide_geometry_sources[2] EQ "member_plotted"),name="Owner preview adapter retains per-segment guide geometry"});
  arrayAppend(results,{passed=(!structKeyExists(dto.map.routeGeo,"private_marker") AND abs(val(dto.timeline.summary.required_fuel_est)-totals.required_fuel_us_gal) LT .0000001),name="Preview DTO projects safe precise totals without unrelated fields"});
  var normal=voyage.getOwnerPreviewViewModel({eligible=true,floatPlanId=1,routeInstanceId=2},{
    success=true,mode="preview",floatPlan={id=1},route={routeInstanceId=2},map={routeGeo={type="LineString",coordinates=[[-80,26],[-79,25]]}},routeTimeline={summary={totalNm=60},legs=[]}});
  arrayAppend(results,{passed=(normal.SUCCESS AND !structKeyExists(normal.map.routeGeo,"guide_estimates") AND normal.timeline.summary.fuel_est EQ ""),name="Ordinary preview keeps existing no-guide contract"});
  var passed=0;for(var item in results) if(item.passed) passed++;
  return {SUCCESS=passed GT 0 AND passed EQ arrayLen(results),passed=passed,total=arrayLen(results),tests=results};
 }
}
