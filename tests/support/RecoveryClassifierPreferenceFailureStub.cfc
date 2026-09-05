component output="false" {
  public boolean function isOptedOut(required string email, string optOutType="non_essential") output=false {
    throw(type="tests.PreferenceLookupFailed", message="Controlled classifier preference lookup failure.");
  }
}
