component output="false" {
  variables.messageId=0;
  public any function init(numeric messageId=0) { variables.messageId=arguments.messageId; return this; }
  public void function finalizeMessage(required numeric messageId,required string status,string acceptedAtUtc="") {}
  public numeric function beginRun(required string executionSource,required boolean dryRun,struct settings={}) { return 0; }
  public struct function prepareMessage(required struct context,required struct message) { return {messageId=variables.messageId,message=arguments.message}; }
}
