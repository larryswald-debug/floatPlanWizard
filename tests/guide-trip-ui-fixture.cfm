<cfsetting showdebugoutput="false" enablecfoutputonly="true" requesttimeout="120">
<cfcontent type="application/json; charset=utf-8"><cfheader name="Cache-Control" value="no-store">
<cfscript>
request.guideTestConfirmation="LOCAL_GUIDE_UI_FIXTURE";
include "support/guide-test-guard.cfm";
try {
 if (structKeyExists(url,"mode") AND url.mode EQ "owned_import") {
  currentUserId=structKeyExists(session.user,"userId") ? val(session.user.userId) : val(session.user.id);
  ownedDraft=new fpw.tests.support.GuideTripFixtureService().init("fpw").importTrip(currentUserId,{
    template_key="fort-lauderdale-bimini",template_version=1,create_another=true,
    import_request_id=lCase(createObject("java","java.util.UUID").randomUUID().toString())});
  writeOutput(serializeJSON({SUCCESS=true,draft=ownedDraft,csrfToken=new fpw.api.v1.AuthRequestGuardService().init().getOrCreateCsrfToken()}));
  abort;
 }
 if(!structKeyExists(session,"guideUiFixture")) session.guideUiFixture=new fpw.tests.support.GuideTripDemoFixture().createDemo();
 if (!session.guideUiFixture.floatplan.SUCCESS) session.guideUiFixture.floatplan=new fpw.tests.support.GuideTripDemoFixture().ensureDraftPlan(session.guideUiFixture.user_id,session.guideUiFixture.saved.route_instance_id);
 session.user={userId=session.guideUiFixture.user_id,fName="Disposable",lName="Guide Demo",email=session.guideUiFixture.email};
 varToken=new fpw.api.v1.AuthRequestGuardService().init().getOrCreateCsrfToken();
 writeOutput(serializeJSON({SUCCESS=true,fixture=session.guideUiFixture,csrfToken=varToken}));
} catch(any e) { writeOutput(serializeJSON({SUCCESS=false,error={type=e.type,message=e.message,detail=e.detail,tagcontext=e.tagcontext}})); }
</cfscript>
