component output="false" {
  /**
   * Runtime capture of current production sendMultipartEmail header construction.
   * Configuration is injected only through a test getEmailConfig implementation.
   * The production mailAttrs and optional Reply-To blocks execute unchanged.
   * Bodies are the exact inputs already rendered by production public send methods.
   * No SMTP tag, attachment I/O, delivery logging, or database work is executed.
   */
  public struct function capture(required struct config, required struct message) output=false {
    if (!structKeyExists(arguments.config,"fromValue") OR !structKeyExists(arguments.config,"replyToEmail")) {
      throw(message="Shared envelope capture requires the actual email configuration.");
    }
    var testDirectory=getDirectoryFromPath(getCurrentTemplatePath());
    var testsDirectory=getDirectoryFromPath(left(testDirectory,len(testDirectory)-1));
    var repoDirectory=getDirectoryFromPath(left(testsDirectory,len(testsDirectory)-1));
    var source=fileRead(repoDirectory & "api/v1/email.cfc","utf-8");
    var matches=reMatch('(?is)<cffunction\s+name="sendMultipartEmail"[^>]*>.*?</cffunction>',source);
    if(arrayLen(matches) NEQ 1) throw(message="Shared email transport source boundary changed.");
    var productionFunction=matches[1];
    var transportStart=findNoCase("<cftry>",productionFunction);
    if(!transportStart) throw(message="Shared email transport boundary was not found.");
    var productionEnvelope=left(productionFunction,transportStart-1);
    if(!find("mailAttrs",productionEnvelope) OR !find("mailAttrs.replyto",productionEnvelope)
      OR reFindNoCase("<cfmail\b",productionEnvelope)) {
      throw(message="Shared email envelope capture refused an unexpected source shape.");
    }
    // Only the test copy's callable signature changes; the production statements do not.
    productionEnvelope=replace(productionEnvelope,'access="private"','access="public"',"one");
    productionEnvelope=replace(productionEnvelope,'returntype="void"','returntype="struct"',"one");
    var componentSource='<cfcomponent output="false">'
      & '<cffunction name="init" access="public" returntype="any" output="false"><cfargument name="config" type="struct" required="true"><cfset variables.captureConfig=duplicate(arguments.config)><cfreturn this></cffunction>'
      & '<cffunction name="getEmailConfig" access="private" returntype="struct" output="false"><cfreturn duplicate(variables.captureConfig)></cffunction>'
      & productionEnvelope
      & '<cfreturn {mailAttributes=duplicate(mailAttrs),from=mailAttrs.from,replyTo=(structKeyExists(mailAttrs,"replyto") ? mailAttrs.replyto : ""),subject=mailAttrs.subject,htmlBody=arguments.htmlBody,textBody=arguments.textBody,mode="Current production mailAttrs evaluated in ColdFusion; rendered multipart inputs captured; no SMTP"}></cffunction></cfcomponent>';
    var generatedName="SharedEmailEnvelope" & reReplace(createUUID(),"[^A-Za-z0-9]","","all");
    var generatedPath=testDirectory & generatedName & ".cfc";
    try {
      fileWrite(generatedPath,componentSource,"utf-8");
      var renderer=createObject("component","fpw.tests.support." & generatedName).init(arguments.config);
      return renderer.sendMultipartEmail(argumentCollection=arguments.message);
    } finally {
      if(fileExists(generatedPath)) fileDelete(generatedPath);
    }
  }
}
