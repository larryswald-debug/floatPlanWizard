component extends="testbox.system.BaseSpec" output=false {
 function run() {
  describe("Explicit beta failure evidence is bounded and best effort",function(){
   beforeEach(function(){
    if(!structKeyExists(request,"betaProgramTestRun")) throw(type="BetaTest.Scope",message="Use the local beta-program runner.");
    variables.service=new fpw.includes.ProductEventService().init("fpw");
    variables.uid=member();variables.token=lCase(createUUID());
   });
   it("records a known database failure with server identity and bounded metadata",function(){
    var r=service.recordExplicitOperationFailure(uid,"waypoint_save","database",token);
    expect(r.SUCCESS).toBeTrue();expect(r.RECORDED).toBeTrue();
    var e=events();expect(e.recordCount).toBe(1);expect(e.entity_type[1]).toBe("user");expect(val(e.entity_id[1])).toBe(uid);
    expect(e.event_source[1]).toBe("member_api");expect(e.request_correlation_id[1]).toBe(token);
    var meta=deserializeJSON(e.metadata_json[1]);
    expect(structCount(meta)).toBe(2);expect(meta.operation).toBe("waypoint_save");expect(meta.error_code).toBe("database_error");
   });
   it("deduplicates repeated failure hooks for one request and operation",function(){
    var entries=[];var capture=new fpw.includes.ProductEventService().init("fpw",{logEntries=entries});
    capture.recordExplicitOperationFailure(uid,"waypoint_savelegstops","database",token);
    var replay=capture.recordExplicitOperationFailure(uid,"waypoint_savelegstops","database",token);
    expect(replay.SUCCESS).toBeTrue();expect(replay.DUPLICATE).toBeTrue();
    expect(arrayLen(capture.getCapturedTestLogs())).toBe(0);
    expect(events().recordCount).toBe(1);
   });
   it("keeps separate operations distinct within a request",function(){
    service.recordExplicitOperationFailure(uid,"waypoint_save","database",token);
    service.recordExplicitOperationFailure(uid,"floatplan_save","database",token);
    expect(events().recordCount).toBe(2);
   });
   it("records required activity failures without copying exception details",function(){
    service.recordExplicitOperationFailure(uid,"route_generate","FPW.MemberActivity.PersistenceFailed",token);
    var meta=deserializeJSON(events().metadata_json[1]);expect(meta.error_code).toBe("activity_persistence_failed");
   });
   it("leaves ambiguous expression and template exceptions unclassified",function(){
    expect(service.recordExplicitOperationFailure(uid,"floatplan_savebasic","expression",token).SKIPPED).toBeTrue();
    expect(service.recordExplicitOperationFailure(uid,"route_generate","template",token).SKIPPED).toBeTrue();
    expect(events().recordCount).toBe(0);
   });
   it("does not misclassify validation ownership custom or application errors",function(){
    for(var type in ["FPW.MemberActivity.Ownership","FPW.MemberActivity.Invalid","custom","application","RoutegenDraftOverridePersist","validation"]) {
     expect(service.recordExplicitOperationFailure(uid,"waypoint_save",type,token).SKIPPED).toBeTrue();
    }
    expect(events().recordCount).toBe(0);
   });
   it("rejects unknown operations invalid identity and user-supplied correlation text",function(){
    expect(service.recordExplicitOperationFailure(uid,"private-route-name","database",token).SKIPPED).toBeTrue();
    expect(service.recordExplicitOperationFailure(0,"waypoint_save","database",token).SKIPPED).toBeTrue();
    expect(service.recordExplicitOperationFailure(uid,"waypoint_save","database","private@example.test").SKIPPED).toBeTrue();
    expect(events().recordCount).toBe(0);
   });
   it("generates a server UUID when a caller has no request context",function(){
    expect(service.recordExplicitOperationFailure(uid,"route_generate","database").SUCCESS).toBeTrue();
    expect(isValid("uuid",events().request_correlation_id[1])).toBeTrue();
   });
   it("rejects extra private metadata even through the generic event writer",function(){
    var r=service.recordEvent(userId=uid,eventName="critical_operation_failed",entityType="user",entityId=uid,eventSource="member_api",
     metadata={operation="waypoint_save",error_code="database_error",description="PRIVATE_TRIP"},idempotencyKey="beta-failure:" & token);
    expect(r.SUCCESS).toBeFalse();expect(events().recordCount).toBe(0);
   });
   it("rejects arbitrary error text incomplete context and foreign member entities",function(){
    var r=service.recordEvent(userId=uid,eventName="critical_operation_failed",entityType="user",entityId=uid,eventSource="member_api",
     metadata={operation="waypoint_save",error_code="private@example.test"},idempotencyKey="beta-failure:" & token);
    expect(r.SUCCESS).toBeFalse();
    r=service.recordEvent(userId=uid,eventName="critical_operation_failed",entityType="user",entityId=uid,eventSource="member_api",metadata={});
    expect(r.SUCCESS).toBeFalse();
    r=service.recordEvent(userId=uid,eventName="critical_operation_failed",entityType="user",entityId=uid+1,eventSource="member_api",metadata={operation="waypoint_save",error_code="database_error"});
    expect(r.SUCCESS).toBeFalse();expect(events().recordCount).toBe(0);
   });
   it("writes evidence after a failed business save has been rolled back",function(){
    transaction action="setsavepoint" savepoint="beta_failed_business_save";
    try {
     queryExecute("INSERT INTO waypoints(userId,name,latitude,longitude,notes) VALUES(:uid,'Disposable failed save','1','2','PRIVATE_TRIP_PAYLOAD')",params(),{datasource="fpw"});
     queryExecute("SELECT beta_failure_test_missing_column FROM waypoints WHERE userId=:uid",params(),{datasource="fpw"});
    } catch(any businessFailure) {
     transaction action="rollback" savepoint="beta_failed_business_save";
     var recorded=service.recordExplicitOperationFailure(uid,"waypoint_save",businessFailure.type,token);
     expect(recorded.SUCCESS).toBeTrue(serializeJSON({result=recorded,type=businessFailure.type}));
    }
    expect(val(queryExecute("SELECT COUNT(*) n FROM waypoints WHERE userId=:uid",params(),{datasource="fpw"}).n[1])).toBe(0);
    expect(events().recordCount).toBe(1);expect(find("PRIVATE",serializeJSON(events()))).toBe(0);
   });
   it("does not change an original domain response when event persistence fails",function(){
    var entries=[];var broken=new fpw.includes.ProductEventService().init("fpw_beta_nonexistent_datasource",{logEntries=entries});
    var response={SUCCESS=false,ERROR="ORIGINAL_SAVE_FAILURE",MESSAGE="Original response"};
    var before=serializeJSON(response);
    var r=broken.recordExplicitOperationFailure(uid,"waypoint_save","database",token);
    expect(r.SUCCESS).toBeFalse();expect(serializeJSON(response)).toBe(before);
    var logs=broken.getCapturedTestLogs();var sawFallback=false;
    for(var line in logs) if(find("FPW_CRITICAL_OPERATION_FAILED",line.text)) sawFallback=true;
    expect(sawFallback).toBeTrue();
    expect(find("PRIVATE",serializeJSON(logs))).toBe(0);expect(events().recordCount).toBe(0);
   });
   it("all three API components compile with the isolated catch hooks",function(){
    expect(isObject(new fpw.api.v1.waypoint())).toBeTrue();
    expect(isObject(new fpw.api.v1.routeBuilder())).toBeTrue();
    expect(isObject(new fpw.api.v1.floatplan())).toBeTrue();
   });
  });
 }
 private struct function params(){return {uid={value=variables.uid,cfsqltype="cf_sql_integer"}};}
 private query function events(){return queryExecute("SELECT event_name,entity_type,entity_id,event_source,request_correlation_id,metadata_json FROM product_events WHERE user_id=:uid AND event_name='critical_operation_failed'",params(),{datasource="fpw"});}
 private numeric function member(){
  var result={};
  queryExecute("INSERT INTO users(fName,lName,email,password,passwordCreated,created) VALUES('Beta','Fixture',:email,:password,UTC_TIMESTAMP(),UTC_TIMESTAMP())",
   {email={value="codex-beta-" & request.betaProgramTestRun & "-" & replace(createUUID(),"-","","all") & "@example.test",cfsqltype="cf_sql_varchar"},
    password={value=hash(createUUID(),"SHA-256"),cfsqltype="cf_sql_varchar"}},{datasource="fpw",result="result"});
  return val(result.generatedKey);
 }
}
