component extends="fpw.tests.support.RecoveryEnrollmentFixture" output="false" {
  // New isolated SQL accounts for service-level failure/corruption tests only.
  // Browser E2E uses the real signup controller, never this constructor.
  public struct function fresh(any eventService="") {
    var inserted={};
    var email=variables.prefix & "-birth-" & (arrayLen(variables.ids)+1) & "@example.test";
    var member={};
    transaction {
      queryExecute("INSERT INTO users (fName,lName,email,password,passwordCreated,created)
        VALUES ('Readiness','Fixture',:email,:password,UTC_TIMESTAMP(),UTC_TIMESTAMP())",
        {email={value=email,cfsqltype="cf_sql_varchar"},password={value=hash(createUUID(),"SHA-256"),cfsqltype="cf_sql_varchar"}},
        {datasource="fpw",result="inserted"});
      var id=val(inserted.generatedKey);arrayAppend(variables.ids,id);
      member={userId=id,email=email,planId=0,routeId=0,vesselId=0};variables.records[toString(id)]=member;
      new fpw.includes.InactiveMemberRecoveryCoverageService(eventService=arguments.eventService)
        .recordSignupInCurrentTransaction(id,{signup_method="password",account_tier="basic"});
    }
    return duplicate(member);
  }
  public numeric function draft(required numeric userId) {
    var inserted={};
    transaction {
      queryExecute("INSERT INTO floatplans (userId,floatPlanName,dateCreated,lastUpdate,status,lastUpdateStatus,route_origin,is_reusable,is_visible_in_route_library)
        VALUES (:id,'Readiness fixture',UTC_TIMESTAMP(),UTC_TIMESTAMP(),'DRAFT',UTC_TIMESTAMP(),'basic_manual',1,1)",
        {id={value=arguments.userId,cfsqltype="cf_sql_integer"}},{datasource="fpw",result="inserted"});
      new fpw.includes.ProductEventService().recordRequiredMemberActivity(arguments.userId,"float_plan_created",val(inserted.generatedKey));
    }
    variables.records[toString(arguments.userId)].planId=val(inserted.generatedKey);
    return val(inserted.generatedKey);
  }
  public any function dueSender(any classifier="") {
    return new fpw.api.v1.InactiveMemberRecoveryService(liveEnabled=true,candidateSource=this,clock=this,
      classifier=arguments.classifier,transport=this);
  }
  public numeric function basicDraft(required numeric userId) {
    var id=draft(arguments.userId);
    var params={id={value=id,cfsqltype="cf_sql_integer"}};
    queryExecute("UPDATE floatplans SET vesselId=0,operatorId=NULL,route_instance_id=NULL,route_day_number=NULL,
      route_origin='basic_float_plan',is_reusable=0,is_visible_in_route_library=0 WHERE floatplanId=:id",params,{datasource="fpw"});
    queryExecute("INSERT INTO floatplan_basic_details (floatplan_id,vessel_name,operator_name,captain_name,captain_email,
      notification_contact_name,notification_contact_email,launch_location,destination_location,authority_name_snapshot,authority_phone_snapshot,created_at,updated_at)
      VALUES (:id,'Fixture vessel','Fixture operator','Fixture captain','fixture@example.test','Fixture contact','contact@example.test',
        'Fixture launch','Fixture destination','N/A - Not Applicable','',UTC_TIMESTAMP(),UTC_TIMESTAMP())",params,{datasource="fpw"});
    return id;
  }
  public void function cleanup() {
    if (arrayLen(variables.ids)) {
      queryExecute("DELETE bd FROM floatplan_basic_details bd JOIN floatplans fp ON fp.floatplanId=bd.floatplan_id WHERE fp.userId IN (:ids)",
        {ids={value=arrayToList(variables.ids),cfsqltype="cf_sql_integer",list=true}},{datasource="fpw"});
    }
    super.cleanup();
  }
}
