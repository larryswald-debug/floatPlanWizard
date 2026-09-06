component output="false" {
  public any function init(required numeric userId,required string atUtc) {variables.userId=arguments.userId;variables.atUtc=arguments.atUtc;return this;}
  public array function getCandidateIds(required numeric batchSize) {return [variables.userId];}
  public string function nowUtc() {return variables.atUtc;}
}
