component extends="fpw.api.v1.CompanionTrackingService" output="false" {
  variables.insertAttempts=0;

  // Test-only nonremote override: production API cannot select this component or inject this failure.
  public void function insertSampleRow(required numeric trackingSessionId,required struct sample) {
    variables.insertAttempts++;
    if(variables.insertAttempts EQ 2)
      throw(type="database",message="Simulated tracking storage failure on the second insert.");
    super.insertSampleRow(arguments.trackingSessionId,arguments.sample);
  }
}
