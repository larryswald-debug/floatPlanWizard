component output="false" {
  public any function init(required numeric userId) { variables.userId=arguments.userId; return this; }
  public array function getCandidateIds(required numeric limit) { return [variables.userId]; }
}
