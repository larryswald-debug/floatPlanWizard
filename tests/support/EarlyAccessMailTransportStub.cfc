component output="false" {
  variables.messages = [];

  public void function send(required struct mailAttributes, required string body) output=false {
    arrayAppend(variables.messages, {
      mailAttributes = duplicate(arguments.mailAttributes),
      body = arguments.body
    });
  }

  public array function getMessages() output=false {
    return duplicate(variables.messages);
  }
}
