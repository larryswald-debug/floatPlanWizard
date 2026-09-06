component extends="fpw.tests.support.RecoveryOrchestrationFixture" output="false" {
  variables.testNow="";
  variables.reviewed=false;

  public string function nowUtc() {
    return len(variables.testNow) ? variables.testNow : dbUtc();
  }
  public void function setTestNow(required string atUtc) { variables.testNow=arguments.atUtc; }
  public string function dbUtc() {
    return toString(queryExecute("SELECT DATE_FORMAT(UTC_TIMESTAMP(),'%Y-%m-%dT%H:%i:%sZ') AS utc",{},{datasource="fpw"}).utc[1]);
  }
  public string function plusSeconds(required string atUtc,required numeric seconds) {
    return createObject("java","java.time.Instant").parse(arguments.atUtc).plusSeconds(javaCast("long",arguments.seconds)).toString();
  }
  public string function getEnrollmentUtc(required numeric userId) {
    return new fpw.includes.InactiveMemberRecoveryEnrollmentService().getEnrollmentUtc(arguments.userId);
  }
  public struct function getCoverageVerification(required numeric userId) {
    return variables.reviewed AND arrayFind(getCandidateIds(100),arguments.userId)
      ? {stage_history=true,activity_coverage=true,sharing_history=true,recovery_history=true} : {};
  }
  public any function dryService(boolean reviewed=false) {
    variables.reviewed=arguments.reviewed;
    return arguments.reviewed
      ? new fpw.api.v1.InactiveMemberRecoveryService(candidateSource=this,clock=this,contextProvider=this)
      : new fpw.api.v1.InactiveMemberRecoveryService(candidateSource=this,clock=this);
  }
  public numeric function enrollmentCount(required numeric userId) {
    return val(queryExecute("SELECT COUNT(*) AS n FROM product_events WHERE user_id=:id AND event_name='inactive_member_recovery_enrolled'",
      {id={value=arguments.userId,cfsqltype="cf_sql_integer"}},{datasource="fpw"}).n[1]);
  }
  public query function enrollmentRow(required numeric userId) {
    return queryExecute("SELECT * FROM product_events WHERE user_id=:id AND event_name='inactive_member_recovery_enrolled'",
      {id={value=arguments.userId,cfsqltype="cf_sql_integer"}},{datasource="fpw"});
  }
  public void function admin(required numeric userId) {
    queryExecute("INSERT INTO member_entitlements (user_id,entitlement_type,source,status,starts_at_utc,expires_at_utc,created_utc,updated_utc)
      VALUES (:id,'admin','enrollment_test','active',UTC_TIMESTAMP()-INTERVAL 1 DAY,UTC_TIMESTAMP()+INTERVAL 1 DAY,UTC_TIMESTAMP(),UTC_TIMESTAMP())",
      {id={value=arguments.userId,cfsqltype="cf_sql_integer"}},{datasource="fpw"});
  }
  // Synthetic stage/activity clock scenarios only. Enrollment is NEVER backdated.
  public void function setEvidenceClock(required numeric userId,required string eventName,required string atUtc) {
    if (!listFind("vessel_created,vessel_updated,user_route_created",arguments.eventName)
      OR !arrayFind(getCandidateIds(100),arguments.userId)) throw(message="INVALID_FIXTURE_CLOCK");
    queryExecute("UPDATE product_events SET occurred_at_utc=CAST(:at AS DATETIME)
      WHERE user_id=:id AND event_name=:name",
      {id={value=arguments.userId,cfsqltype="cf_sql_integer"},name={value=arguments.eventName,cfsqltype="cf_sql_varchar"},
       at={value=replace(replace(arguments.atUtc,"T"," "),"Z",""),cfsqltype="cf_sql_varchar"}},{datasource="fpw"});
  }
}
