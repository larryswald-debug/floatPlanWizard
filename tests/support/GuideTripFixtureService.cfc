component extends="fpw.api.v1.GuideTripService" output=false {
  variables.fixturePublicationStatus="published";
  variables.fixtureMissingMileage=false;
  public void function setMissingMileageFixture(required boolean enabled) { variables.fixtureMissingMileage=arguments.enabled; }
  public void function setPublicationStatus(required string status) { variables.fixturePublicationStatus=arguments.status; }
  // Test-only in-memory publication. Never changes the editorial manifest.
  public struct function getManifest(required string templateKey,required numeric templateVersion,boolean requirePublished=true) {
    var m=super.getManifest(arguments.templateKey,arguments.templateVersion,false);
    m.status=variables.fixturePublicationStatus;
    if (variables.fixtureMissingMileage) for (var leg in m.legs) {
      leg.distance_nm=""; leg.distance_kind="missing";
      leg.distance_method="Missing-mileage test fixture: enter a planning distance and its source or calculation method.";
      leg.source_ids=[]; leg.source_dates={};
    }
    if (arguments.requirePublished) validateManifest(m);
    return m;
  }
}
