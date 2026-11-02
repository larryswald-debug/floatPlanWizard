<cfsetting showdebugoutput="false" enablecfoutputonly="true" requesttimeout="60">
<cfcontent type="application/json; charset=utf-8" reset="true">
<cfscript>
if (!listFindNoCase("dev,development,local",application.env ?: "") || !listFindNoCase("localhost,127.0.0.1,::1",cgi.server_name)
    || val(cgi.server_port)!=8500 || !reFindNoCase("^(localhost|127[.]0[.]0[.]1|\[::1\])(:8500)?$",cgi.http_host)
    || (url.confirm ?: "")!="RUN_LOCAL_ARRIVAL_MAIL_CONTRACT") {
    cfheader(statuscode=404);
    writeOutput('{"success":false}');
    abort;
}
request.mailContractChecks=[];
function verify(required boolean condition,required string name) {
    if (!condition) throw(type="ArrivalMailContract.Assertion",message=arguments.name);
    arrayAppend(request.mailContractChecks,arguments.name);
}
function db(required string statement,struct params={}) {
    return queryExecute(statement,params,{datasource="fpw"});
}
function exerciseMail() {
    var mail=new fpw.api.v1.ArrivalOverdueMailService().init("fpw",hash(createUUID(),"SHA-256"));
    var mixer=new testbox.system.BaseSpec();
    mixer.makePublic(mail,"classifyTransportException","classifyForTest");
    mixer.makePublic(mail,"safeLabel","labelForTest");
    verify(mail.submit("",{}).reason=="LIVE_TRANSPORT_DISABLED","development transport disabled before SMTP");
    verify(mail.labelForTest("off-site https://bad.invalid")=="","untrusted label links omitted");
    verify(!find(chr(10),mail.labelForTest("Test" & chr(10) & "Vessel")),"line breaks removed from labels");
    var conn=createObject("java","java.net.ConnectException").init("fixture");
    var outer=createObject("java","java.lang.Exception").init("fixture",conn);
    verify(mail.classifyForTest({cause={rootCause=outer}}).status=="FAILED_RETRYABLE","wrapped refused connection retries");
    var timeout=createObject("java","java.net.SocketTimeoutException").init("fixture");
    verify(mail.classifyForTest({rootCause=timeout}).status=="UNKNOWN","socket timeout quarantined as ambiguous");
    var address=createObject("java","javax.mail.internet.InternetAddress").init("fixture@example.invalid");
    var smtp=createObject("java","com.sun.mail.smtp.SMTPAddressFailedException");
    var temporary=smtp.init(address,"RCPT TO",javaCast("int",450),"synthetic rejection");
    var nested=createObject("java","javax.mail.MessagingException").init("synthetic wrapper");
    nested.setNextException(temporary);
    verify(mail.classifyForTest({rootCause=nested}).status=="FAILED_RETRYABLE","temporary recipient rejection retries");
    var bad=createObject("java","com.sun.mail.smtp.SMTPAddressFailedException").init(address,"RCPT TO",javaCast("int",550),"private synthetic text");
    var outcome=mail.classifyForTest({rootCause=bad});
    verify(outcome.status=="FAILED_PERMANENT" && outcome.reason=="ADDRESS_REJECTED" && !find("private",serializeJSON(outcome)),"permanent rejection has redacted reason");
    verify(mail.classifyForTest({cause={message="unclassified fixture"}}).status=="UNKNOWN","unclassified outcome cannot retry automatically");
    var fixture={};
    transaction {
        try {
            fixture=new fpw.tests.support.CompletedContactFixture().create();
            var binds={p=fixture.planId,u=fixture.userId,id=fixture.streamId};
            var privateNotice=mail.buildNotice(fixture.planId,"2027-07-10 19:00:00","America/New_York","2027-07-10 19:01:00.000000");
            verify(find("3:00 PM (America/New_York)",privateNotice.body)>0 && find("2027-07-10 19:01:00 UTC",privateNotice.body)>0,"scheduled wall clock zone and UTC notice time");
            verify(!find("/app/follow.cfm",privateNotice.body) && !find(fixture.token,privateNotice.body) && !find(fixture.contactEmail,privateNotice.body),"invite link token and recipient omitted");
            db("UPDATE voyage_streams SET privacy_mode='public' WHERE id=:id AND owner_user_id=:u AND floatplan_id=:p",binds);
            verify(db("SELECT COUNT(*) AS n FROM voyage_streams WHERE id=:id AND owner_user_id=:u AND floatplan_id=:p AND privacy_mode='public'",binds).n[1]==1,"owned public stream exists");
            var access=new fpw.api.v1.PremiumTripAccessService().init("fpw").getTripOperationalAccess(fixture.userId,fixture.planId,false);
            verify(access.allowed,"fixture has exact active trip access " & access.reasonCode);
            var origin=new fpw.api.v1.email().getPublicBaseUrl();
            verify(len(origin)>0,"canonical origin available");
            var publicNotice=mail.buildNotice(fixture.planId,"2027-07-10 19:00:00","America/New_York","2027-07-10 19:01:00");
            verify(find("/app/follow.cfm?slug=" & urlEncodedFormat(fixture.slug),publicNotice.body)>0 && !find(fixture.token,publicNotice.body),"eligible public active stream only shares token-free slug");
            var ended=new fpw.api.v1.PremiumTripAccessService().init("fpw").endAccessForPlan(fixture.planId,"CLOSED");
            verify(ended.success,"fixture entitlement ended");
            var denied=mail.buildNotice(fixture.planId,"2027-07-10 19:00:00","America/New_York","2027-07-10 19:01:00");
            verify(!find("/app/follow.cfm",denied.body),"denied trip-specific access suppresses public link");
        } finally { transactionRollback(); }
    }
    verify(db("SELECT COUNT(*) AS n FROM users WHERE userId=:u AND email=:e",{u=fixture.userId,e=fixture.email}).n[1]==0,"disposable fixture rolled back");
}
try {
    verify(compareNoCase(db("SELECT DATABASE() AS db").db[1],"FPW")==0,"confirmed local schema");
    exerciseMail();
    writeOutput(serializeJSON({success=true,passed=arrayLen(request.mailContractChecks),checks=request.mailContractChecks}));
} catch (any failure) {
    cfheader(statuscode=500);
    writeOutput(serializeJSON({success=false,passed=arrayLen(request.mailContractChecks),type=left(failure.type,100),
        failedAssertion=(failure.type=="ArrivalMailContract.Assertion" ? failure.message : ""),frame=(arrayLen(failure.tagContext ?: []) ? failure.tagContext[1].line : 0)}));
}
</cfscript>
