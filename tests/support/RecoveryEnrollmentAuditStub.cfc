component output="false" {
  variables.entries=[];variables.failAt=0;variables.calls=0;
  public any function init(numeric failAt=0) {variables.failAt=arguments.failAt;return this;}
  public void function record(required numeric actorUserId,required string action,required string targetType,
    string targetId="",required boolean success,string requestId="",struct previousValues={},struct newValues={},string reason="") {
    variables.calls++;
    if (variables.calls EQ variables.failAt) throw(message="CONTROLLED_AUDIT_FAILURE");
    arrayAppend(variables.entries,duplicate(arguments));
  }
  public array function entries() {return duplicate(variables.entries);}
}
