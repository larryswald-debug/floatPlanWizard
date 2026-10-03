component output=false {
 variables.datasource="fpw";
 public any function init(string datasource="fpw") { variables.datasource=arguments.datasource; return this; }
 // Required operational settings are read on every call; a missing/corrupt singleton fails closed.
 public struct function getSettings() {
  var q=queryExecute("SELECT revision,first_delay_hours,stage_interval_hours,attribution_window_hours,
   DATE_FORMAT(updated_at_utc,'%Y-%m-%dT%H:%i:%sZ') updated_utc,
   COALESCE(DATE_FORMAT(reset_at_utc,'%Y-%m-%dT%H:%i:%sZ'),'') reset_utc,reset_cohort_count
   FROM inactive_member_recovery_settings WHERE id=1",{}, {datasource=variables.datasource});
  if(q.recordCount NEQ 1) throw(type="FPW.Recovery.Settings",message="SETTINGS_UNAVAILABLE");
  var s={revision=val(q.revision[1]),firstDelayHours=val(q.first_delay_hours[1]),
   stageIntervalHours=val(q.stage_interval_hours[1]),attributionWindowHours=val(q.attribution_window_hours[1]),
   updatedAtUtc=q.updated_utc[1],resetAtUtc=q.reset_utc[1],resetCohortCount=val(q.reset_cohort_count[1])};
  validate(s);
  if(s.revision LT 1) throw(type="FPW.Recovery.Settings",message="SETTINGS_INVALID");
  return s;
 }
 public struct function validate(required struct values) {
  var validated={};
  for(var key in ["firstDelayHours","stageIntervalHours","attributionWindowHours"]) {
   if(!structKeyExists(arguments.values,key) OR !isSimpleValue(arguments.values[key]) OR
      !reFind("^[0-9]{1,3}$",toString(arguments.values[key])) OR val(arguments.values[key]) LT 1 OR val(arguments.values[key]) GT 720)
    throw(type="FPW.Recovery.Settings",message="INVALID_TIMING_HOURS");
   validated[key]=val(arguments.values[key]);
  }
  return validated;
 }
}
