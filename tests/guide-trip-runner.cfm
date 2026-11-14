<cfsetting showdebugoutput="false">
<cfcontent type="application/json; charset=utf-8">
<cfheader name="Cache-Control" value="no-store">
<cfset request.guideTestConfirmation="RUN_LOCAL_GUIDE_CALCULATION_TESTS">
<cfinclude template="support/guide-test-guard.cfm">
<cfscript>
results=[];
function check(required boolean passed,required string name) { arrayAppend(results,{name=name,passed=passed}); }
try {
 guard=new fpw.tests.support.GuideLocalTestGuard();
 access={environment="dev",serverName="localhost",httpHost="localhost:8500",serverPort=8500,userId=123,
  confirmation="TEST_ONLY",expectedConfirmation="TEST_ONLY"};
 check(guard.validateAccess(argumentCollection=access).ALLOWED,"Authenticated local development access is eligible");
 for(environmentName in ["production","prod",""]) {
  changed=duplicate(access);changed.environment=environmentName;
  check(!guard.validateAccess(argumentCollection=changed).ALLOWED,"Nondevelopment environment denied: " & environmentName);
 }
 changed=duplicate(access);changed.userId=0;
 check(guard.validateAccess(argumentCollection=changed).STATUSCODE EQ 401,"Anonymous tests denied");
 changed=duplicate(access);changed.httpHost="floatplanwizard.com";
 check(!guard.validateAccess(argumentCollection=changed).ALLOWED,"Production Host denied");
 changed=duplicate(access);changed.serverPort=443;
 check(!guard.validateAccess(argumentCollection=changed).ALLOWED,"Nonlocal port denied");
 changed=duplicate(access);changed.confirmation="";
 check(!guard.validateAccess(argumentCollection=changed).ALLOWED,"Missing confirmation denied");
 changed=duplicate(access);changed.serverName="::1";changed.httpHost="[::1]:8500";
 check(guard.validateAccess(argumentCollection=changed).ALLOWED,"Exact IPv6 local development host supported");
 authGuard=new fpw.api.v1.AuthRequestGuardService().init();
 token=repeatString("a",64);
 check(!authGuard.validateRequest(method="GET",expectedOrigin="http://localhost:8500",candidate=token,expected=token).ALLOWED,"Authenticated GET denied");
 check(!authGuard.validateRequest(method="POST",expectedOrigin="http://localhost:8500").ALLOWED,"Missing CSRF denied");
 check(!authGuard.validateRequest(method="POST",expectedOrigin="http://localhost:8500",origin="https://foreign.invalid",candidate=token,expected=token).ALLOWED,"Unsafe origin denied");
 check(authGuard.validateRequest(method="POST",expectedOrigin="http://localhost:8500",origin="http://localhost:8500",candidate=token,expected=token).ALLOWED,"Same-origin authenticated POST with CSRF accepted");
 svc=new fpw.api.v1.GuideTripService().init("fpw");
 p={planning_speed_kn=20,underway_burn_us_gph=18,underway_hours_per_day=6.5,reserve_mode="percentage",reserve_pct=20,idle_burn_us_gph=0,idle_hours_total=0,usable_fuel_us_gal=190,performance_confirmed=true};
 total=svc.calculateTotals([{distance_nm=60,distance_method="Explicit test worksheet"},{distance_nm=60,distance_method="Explicit test worksheet"}],p);
 check(total.complete AND total.known_run_hours EQ 6 AND total.base_fuel_us_gal EQ 108,"Explicit movement arithmetic");
 check(abs(total.reserve_fuel_us_gal-21.6) LT .00001 AND abs(total.required_fuel_us_gal-129.6) LT .00001,"Percentage reserve applied once");
 check(abs(total.usable_above_requirement_us_gal-60.4) LT .00001,"Usable fuel compared to requirement");
 check(svc.reserveForBase(108,"thirds",33) EQ 54,"Thirds differs from 33 percent");
 partial=svc.calculateTotals([{distance_nm=60,distance_method="Explicit test worksheet"},{distance_nm="",distance_method=""}],p);
 check(!partial.complete AND partial.missing_leg_count EQ 1 AND partial.known_distance_nm EQ 60 AND !isNumeric(partial.usable_above_requirement_us_gal),"Missing distance is incomplete, not zero/full sufficiency");
 unattributed=svc.calculateTotals([{distance_nm=60,distance_method=""}],p);
 check(!unattributed.complete AND unattributed.missing_method_count EQ 1 AND unattributed.known_run_hours EQ 3 AND unattributed.base_fuel_us_gal EQ 54 AND !isNumeric(unattributed.usable_above_requirement_us_gal),"Missing attribution retains numeric estimates but remains incomplete");
 p.performance_confirmed=false;
 check(!svc.calculateTotals([{distance_nm=60,distance_method="Explicit test worksheet"}],p).complete,"Performance confirmation required");
 wire=svc.serializeResponse({DATA={distance_nm="",known_run_hours=""}});
 check(findNoCase('"distance_nm":null',wire) GT 0,"Missing numeric wire value is null");
 bad=false;
 try { svc.validateManifest({status="draft"}); } catch(any e) { bad=e.type EQ "FPW.Guide.TEMPLATE_UNAVAILABLE"; }
 check(bad,"Draft template cannot import");
 passed=0; for(r in results) if(r.passed) passed++;
 writeOutput(serializeJSON({SUCCESS=passed EQ arrayLen(results),passed=passed,total=arrayLen(results),tests=results}));
} catch(any e) {
 writeOutput(serializeJSON({SUCCESS=false,ERROR={type=e.type,message=e.message,detail=e.detail},tests=results}));
}
</cfscript>
