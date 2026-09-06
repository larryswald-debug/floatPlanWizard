component output="false" {
  public any function init() output=false {variables.pdf=new fpw.api.api_assets.floatPlanUtils();return this;}
  // Test-only boundary probe. Normal creation uses the real owner-authorized PDF builder.
  public any function createPDF(required numeric floatPlanId,required numeric userId) output=false {
    if (!structKeyExists(request,"recoveryShareProbe")) throw(message="LOCAL_SHARE_PROBE_REQUIRED");
    var probe=request.recoveryShareProbe;
    var q=queryExecute("SELECT COUNT(*) AS n FROM product_events WHERE user_id=:uid AND entity_id=:pid
      AND event_name='recovery_share_started' AND event_source=:source",
      {uid={value=arguments.userId,cfsqltype="cf_sql_integer"},pid={value=arguments.floatPlanId,cfsqltype="cf_sql_integer"},
       source={value=probe.source,cfsqltype="cf_sql_varchar"}},{datasource="fpw"});
    probe.startedAtPdf=val(q.n[1]);
    if (probe.mode EQ "definite" AND probe.source NEQ "basic_review_send") return "";
    var name=variables.pdf.createPDF(arguments.floatPlanId,arguments.userId);
    if (!isSimpleValue(name) OR !len(trim(toString(name)))) throw(message="REAL_PDF_REQUIRED");
    var actual=variables.pdf.getPdfPath(name);
    if (fileExists(actual)) arrayAppend(probe.files,actual);
    var original=reReplace(actual,"_readonly[.]pdf$",".pdf");
    if (original NEQ actual AND fileExists(original)) arrayAppend(probe.files,original);
    return name;
  }
  public string function getPdfPath(required string fileName) output=false {
    var actual=variables.pdf.getPdfPath(arguments.fileName);
    var probe=request.recoveryShareProbe;
    if (probe.mode EQ "ambiguous" AND probe.source NEQ "basic_review_send") return actual & ".missing";
    if (probe.mode EQ "definite" AND probe.source EQ "basic_review_send") {
      // Existing file passes the service existence gate; real email validation rejects non-PDF extension.
      var invalid=actual & ".invalid";
      fileCopy(actual,invalid);
      arrayAppend(probe.files,invalid);
      return invalid;
    }
    return actual;
  }
}
