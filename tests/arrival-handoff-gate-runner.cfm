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
checks=[];
senderName="arrivalSender" & replace(createUUID(),"-","","all");
writerName="arrivalWriter" & replace(createUUID(),"-","","all");
ready=createObject("java","java.util.concurrent.CountDownLatch").init(javaCast("int",1));
finish=createObject("java","java.util.concurrent.CountDownLatch").init(javaCast("int",1));
try {
    preflight=queryExecute("SELECT DATABASE() AS db_name,(SELECT COUNT(*) FROM floatplans WHERE floatPlanId=:p) AS owners,
        CONCAT('fpw:arrival:',LEFT(SHA2(DATABASE(),256),24),':',:p) AS lock_name",{p=probePlan},{datasource="fpw"});
    if (compareNoCase(preflight.db_name[1],"FPW")!=0 || val(preflight.owners[1])!=0) throw(type="ArrivalTest.Scope");

    // The dispatcher may never commit another caller's plan changes.
    transaction {
        worker=new fpw.api.v1.ArrivalOverdueDeliveryService().init("fpw");
        if (worker.submitClaim(0,"").state!="BUSY" || worker.dispatchCaptainReminder(probePlan).state!="BUSY")
            throw(type="ArrivalTest.NestedSubmission");
    }
    arrayAppend(checks,"shore and captain submissions defer inside a caller's transaction");

    thread action="run" name=senderName plan=probePlan ready=ready finish=finish {
        var senderGate=new fpw.api.v1.ArrivalHandoffGate();
        var started=attributes.ready;
        var proceed=attributes.finish;
        transaction {
            var handle=senderGate.acquireInTransaction(attributes.plan,"fpw",0);
            try {
                thread.transport=senderGate.submit(handle,function(){
                    var mode=queryExecute("SELECT @@session.autocommit AS enabled, CONNECTION_ID() AS id,
                        IS_USED_LOCK(:name) AS owner",{name=handle.lockName},{datasource="fpw"});
                    started.countDown();
                    if (!proceed.await(javaCast("long",12),createObject("java","java.util.concurrent.TimeUnit").SECONDS))
                        throw(type="ArrivalTest.TransportTimedOut");
                    return {autocommit=mode.enabled[1],id=mode.id[1],owner=mode.owner[1]};
                });
                thread.resumed=queryExecute("SELECT @@session.autocommit AS enabled",{},{datasource="fpw"}).enabled[1];
                transaction action="commit";
            } finally { senderGate.release(handle); }
        }
    }
    if (!ready.await(javaCast("long",8),createObject("java","java.util.concurrent.TimeUnit").SECONDS))
        throw(type="ArrivalTest.SenderDidNotEnter");
    owner=queryExecute("SELECT CONNECTION_ID() AS observer,IS_USED_LOCK(:k) AS sender",
        {k=preflight.lock_name[1]},{datasource="fpw"});
    if (val(owner.sender[1] ?: 0)<=0 || owner.sender[1]==owner.observer[1]) throw(type="ArrivalTest.LockNotVisible");
    arrayAppend(checks,"another connection observes the sender's lock after the attempt commit");

    busy=false;
    transaction {
        try {
            unexpected=gate.acquireInTransaction(probePlan,"fpw",0);
            gate.release(unexpected);
        } catch (FPW.ArrivalHandoffBusy inUse) { busy=true; }
    }
    if (!busy) throw(type="ArrivalTest.ConcurrentAcquire");
    arrayAppend(checks,"a second sender cannot acquire the plan during transport");

    thread action="run" name=writerName plan=probePlan {
        new fpw.api.v1.ArrivalHandoffGate().awaitHandoff(attributes.plan,"fpw",8);
        thread.passed=true;
    }
    waitUntil=getTickCount()+5000;
    queued=false;
    do {
        pending=queryExecute("SELECT COUNT(*) AS n FROM performance_schema.metadata_locks
            WHERE OBJECT_TYPE='USER LEVEL LOCK' AND OBJECT_NAME=:k AND LOCK_STATUS='PENDING'",
            {k=preflight.lock_name[1]},{datasource="fpw"});
        queued=val(pending.n[1])>0;
        if (!queued) sleep(20);
    } while (!queued && getTickCount()<waitUntil);
    if (!queued) throw(type="ArrivalTest.WaiterNotObserved");
    arrayAppend(checks,"a competing lifecycle writer waits for the in-flight send");
    finish.countDown();
    thread action="join" name=senderName timeout=12000;
    thread action="join" name=writerName timeout=10000;
    if (cfthread[senderName].status!="COMPLETED" || !(cfthread[writerName].passed ?: false))
        throw(type="ArrivalTest.WorkerFailed");
    sent=cfthread[senderName].transport;
    if (sent.autocommit!=1 || sent.id!=sent.owner || sent.id!=owner.sender[1] || cfthread[senderName].resumed!=0)
        throw(type="ArrivalTest.TransportScope");
    arrayAppend(checks,"transport runs in autocommit on the lock owner and result recording resumes transactionally");
    if (!gate.isFree(probePlan)) throw(type="ArrivalTest.LockLeaked");
    arrayAppend(checks,"the waiting writer completes and the next submission can acquire the plan");

    interrupted=false;
    transaction {
        afterError=gate.acquireInTransaction(probePlan,"fpw",0);
        try {
            gate.submit(afterError,function(){throw(type="ArrivalTest.InterruptedTransport");});
        } catch (ArrivalTest.InterruptedTransport expected) {
            interrupted=true;
            if (gate.canStartSubmission("fpw")) throw(type="ArrivalTest.ModeNotRestored");
        } finally { gate.release(afterError); }
    }
    if (!interrupted) throw(type="ArrivalTest.ExpectedInterruptedTransport");
    if (!gate.isFree(probePlan)) throw(type="ArrivalTest.ErrorLeakedLock");
    arrayAppend(checks,"a thrown transport error restores the transaction mode and releases the plan");
    writeOutput(serializeJSON({success=true,passed=arrayLen(checks),checks=checks}));
} catch (any failure) {
    cfheader(statuscode=500);
    writeOutput(serializeJSON({success=false,passed=arrayLen(checks),type=left(failure.type,100)}));
} finally {
    finish.countDown();
}
</cfscript>
