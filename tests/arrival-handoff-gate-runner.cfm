<cfsetting showdebugoutput="false" enablecfoutputonly="true" requesttimeout="45">
<cfcontent type="application/json; charset=utf-8" reset="true">
<cfscript>
if (!structKeyExists(application,"env") || !listFindNoCase("dev,development,local",application.env)
    || !listFindNoCase("localhost,127.0.0.1,::1",cgi.server_name) || val(cgi.server_port)!=8500
    || !reFindNoCase("^(localhost|127[.]0[.]0[.]1|\[::1\])(:8500)?$",cgi.http_host)
    || (url.confirm ?: "")!="RUN_LOCAL_ARRIVAL_HANDOFF_GATE") {
    cfheader(statuscode=404);
    writeOutput('{"success":false}');
    abort;
}
gate=new fpw.api.v1.ArrivalHandoffGate();
probePlan=1800000000+randRange(1,200000);
held={};
reacquired={};
other={};
checks=[];
try {
    preflight=queryExecute("SELECT DATABASE() AS name,(SELECT COUNT(*) FROM floatplans WHERE floatPlanId=:p) AS owners",
        {p=probePlan},{datasource="fpw"});
    if (compareNoCase(preflight.name[1],"FPW")!=0 || val(preflight.owners[1])!=0) throw(type="ArrivalTest.Scope");
    transaction {
        ambient=queryExecute("SELECT CONNECTION_ID() AS id",{},{datasource="fpw"});
        held=gate.acquire(probePlan,"fpw",0);
        if (held.connectionId==ambient.id[1]) throw(type="ArrivalTest.NotIndependent");
        arrayAppend(checks,"pinned connection independent of caller transaction");
    }
    owner=queryExecute("SELECT IS_USED_LOCK(:k) AS who",{k=held.lockName},{datasource="fpw"});
    if (val(owner.who[1])!=held.connectionId) throw(type="ArrivalTest.LostAfterCommit");
    arrayAppend(checks,"database session retains lock beyond commit");
    busy=false;
    try { other=gate.acquire(probePlan,"fpw",0); } catch (FPW.ArrivalHandoffBusy expected) { busy=true; }
    if (!busy) throw(type="ArrivalTest.ConcurrentAcquire");
    arrayAppend(checks,"second connection cannot acquire the same plan");
    writerBusy=false;
    try { gate.awaitHandoff(probePlan,"fpw",0); } catch (FPW.ArrivalHandoffBusy expected) { writerBusy=true; }
    if (!writerBusy) throw(type="ArrivalTest.WriterPassed");
    arrayAppend(checks,"lifecycle fence blocks during handoff");
    threadName="arrivalGate" & replace(createUUID(),"-","","all");
    thread action="run" name=threadName probePlan=probePlan {
        try {
            new fpw.api.v1.ArrivalHandoffGate().awaitHandoff(attributes.probePlan,"fpw",8);
            thread.passed=true;
        } catch (any workerError) {
            thread.passed=false;
        }
    }
    waitUntil=getTickCount()+5000;
    queued=false;
    do {
        pending=queryExecute("SELECT COUNT(*) AS n FROM performance_schema.metadata_locks
            WHERE OBJECT_TYPE='USER LEVEL LOCK' AND OBJECT_NAME=:k AND LOCK_STATUS='PENDING'",
            {k=held.lockName},{datasource="fpw"});
        queued=val(pending.n[1])>0;
        if (!queued) sleep(20);
    } while (!queued && getTickCount()<waitUntil);
    if (!queued) throw(type="ArrivalTest.WaiterNotObserved");
    gate.release(held);
    held={};
    thread action="join" name=threadName timeout=10000;
    if (!(cfthread[threadName].passed ?: false)) throw(type="ArrivalTest.WaiterReleaseFailed");
    arrayAppend(checks,"contended writer waits then releases its acquired fence");
    gate.awaitHandoff(probePlan,"fpw",0);
    reacquired=gate.acquire(probePlan,"fpw",0);
    arrayAppend(checks,"verified unlock permits writer and next dispatcher");
    gate.release(reacquired);
    reacquired={};
    writeOutput(serializeJSON({success=true,passed=arrayLen(checks),checks=checks}));
} catch (any failure) {
    cfheader(statuscode=500);
    writeOutput(serializeJSON({success=false,passed=arrayLen(checks),type=left(failure.type,100)}));
} finally {
    if (structKeyExists(held,"connection")) gate.release(held);
    if (structKeyExists(reacquired,"connection")) gate.release(reacquired);
    if (structKeyExists(other,"connection")) gate.release(other);
}
</cfscript>
