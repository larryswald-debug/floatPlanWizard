component output=false {
 variables.datasource="fpw";
 public any function init(string datasource="fpw") {variables.datasource=arguments.datasource;return this;}
 public struct function getState(required numeric userId) {
  var enrollment=new fpw.includes.InactiveMemberRecoveryEnrollmentService(datasource=variables.datasource).getEnrollment(arguments.userId);
  var result={paused=false,excluded=false,enrollmentEventId=enrollment.EVENT_ID,recoveryStartUtc=enrollment.ENROLLMENT_UTC,revision=0};
  var q=queryExecute("SELECT recovery_enrollment_event_id,paused,excluded,revision,
    COALESCE(DATE_FORMAT(recovery_start_at_utc,'%Y-%m-%dT%H:%i:%sZ'),'') start_utc,
    (recovery_start_at_utc IS NULL OR (recovery_start_at_utc <= UTC_TIMESTAMP(6) AND recovery_start_at_utc > '1970-01-01')) valid_clock
   FROM inactive_member_recovery_member_state WHERE user_id=:id",
   {id={value=arguments.userId,cfsqltype="cf_sql_integer"}},{datasource=variables.datasource});
  if(q.recordCount) {
   if(enrollment.EVENT_ID LTE 0 OR val(q.recovery_enrollment_event_id[1]) NEQ enrollment.EVENT_ID OR !val(q.valid_clock[1]))
    throw(type="FPW.Recovery.State",message="STATE_ENROLLMENT_INVALID");
   result.paused=val(q.paused[1]) EQ 1; result.excluded=val(q.excluded[1]) EQ 1; result.revision=val(q.revision[1]);
   if(len(q.start_utc[1])) {
    if(compare(q.start_utc[1],enrollment.ENROLLMENT_UTC) LT 0) throw(type="FPW.Recovery.State",message="STATE_CLOCK_INVALID");
    result.recoveryStartUtc=q.start_utc[1];
   }
  }
  return result;
 }
}
