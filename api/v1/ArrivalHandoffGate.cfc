component output="false" hint="Plan-specific fence between arrival email handoff and lifecycle changes." {
    private string function keyExpression() {
        return "CONCAT('fpw:arrival:', LEFT(SHA2(DATABASE(),256),24), ':', ";
    }

    // A sender must never commit a surrounding plan save or a caller's other work.
    public boolean function canStartSubmission(required string ds) {
        var row=queryExecute("SELECT @@session.autocommit AS enabled",{},{datasource=ds,timeout=5});
        return row.enabled[1]==1;
    }

    // The caller's outer CF transaction pins this ordinary datasource connection.
    // MySQL and MariaDB named locks belong to the connection and survive COMMIT.
    public struct function acquireInTransaction(required numeric planId,string ds="fpw",numeric waitSeconds=20) {
        if (planId<=0 || fix(planId)!=planId || waitSeconds<0 || waitSeconds>30 || fix(waitSeconds)!=waitSeconds)
            throw(type="FPW.ArrivalHandoffUnavailable",message="Invalid arrival handoff parameters.");
        var sessionRow=queryExecute("SELECT CONNECTION_ID() AS id,@@session.autocommit AS auto_commit,"
            & keyExpression() & ":p) AS lock_name",{p={value=planId,cfsqltype="cf_sql_bigint"}},{datasource=ds,timeout=5});
        if (sessionRow.auto_commit[1]!=0 || !len(sessionRow.lock_name[1] ?: ""))
            throw(type="FPW.ArrivalHandoffUnavailable",message="The arrival handoff requires a pinned datasource connection.");
        var handle={ds=ds,connectionId=sessionRow.id[1],lockName=sessionRow.lock_name[1]};
        var params={name=handle.lockName};
        var prior=queryExecute("SELECT IS_USED_LOCK(:name) AS owner",params,{datasource=ds,timeout=5});
        if (val(prior.owner[1] ?: 0)==handle.connectionId) {
            discardOwner(handle);
            throw(type="FPW.ArrivalHandoffUnavailable",message="An abandoned arrival handoff was detected.");
        }
        params.wait={value=waitSeconds,cfsqltype="cf_sql_integer"};
        try {
            var lockRow=queryExecute("SELECT GET_LOCK(:name,:wait) AS granted",params,{datasource=ds,timeout=waitSeconds+3});
            if (isNull(lockRow.granted[1]) || !len(toString(lockRow.granted[1])))
                throw(type="FPW.ArrivalHandoffUnavailable",message="Arrival handoff acquisition was not confirmed.");
            if (val(lockRow.granted[1])!=1)
                throw(type="FPW.ArrivalHandoffBusy",message="Arrival submission is busy. Retry the operation.");
            return handle;
        } catch (FPW.ArrivalHandoffBusy busy) {
            rethrow;
        } catch (any failure) {
            discardOwner(handle);
            throw(type="FPW.ArrivalHandoffUnavailable",message="The arrival handoff could not be acquired.");
        }
    }

    // Commit the attempt before SMTP and leave no SQL transaction open during transport.
    // The surrounding CF scope keeps the physical connection checked out until release.
    public struct function submit(required struct handle,required any transport) {
        var options={datasource=handle.ds,timeout=5};
        transaction action="commit";
        try {
            queryExecute("SET SESSION autocommit=1",{},options);
            var state=queryExecute("SELECT CONNECTION_ID() AS id, IS_USED_LOCK(:name) AS owner,
                @@session.autocommit AS auto_commit",{name=handle.lockName},options);
            if (state.id[1]!=handle.connectionId || val(state.owner[1] ?: 0)!=handle.connectionId || state.auto_commit[1]!=1)
                throw(type="FPW.ArrivalHandoffUnavailable",message="Arrival handoff ownership could not be verified before sending.");
            return arguments.transport();
        } finally {
            try {
                queryExecute("SET SESSION autocommit=0",{},options);
            } catch (any restoreError) {
                discardOwner(handle);
                rethrow;
            }
        }
    }

    public void function release(required struct handle) {
        try {
            // Only the session originally granted this lock may release it.
            var row=queryExecute("SELECT IF(CONNECTION_ID()=:id,RELEASE_LOCK(:name),NULL) AS released",
                {id=handle.connectionId,name=handle.lockName},{datasource=handle.ds,timeout=5});
            if (val(row.released[1] ?: 0)==1) return;
        } catch (any releaseError) {
            // A lost connection may already have released its lock.
        }
        discardOwner(handle);
        throw(type="FPW.ArrivalHandoffUnavailable",message="Arrival handoff release could not be verified.");
    }

    public boolean function isFree(required numeric planId,string ds="fpw") {
        if (planId<=0 || fix(planId)!=planId) throw(type="FPW.ArrivalHandoffUnavailable",message="Invalid arrival handoff plan.");
        var probe=queryExecute("SELECT IS_FREE_LOCK(" & keyExpression() & ":p)) AS is_free",
            {p={value=planId,cfsqltype="cf_sql_bigint"}},{datasource=ds,timeout=5});
        if (probe.recordCount!=1 || isNull(probe.is_free[1]) || !len(toString(probe.is_free[1])))
            throw(type="FPW.ArrivalHandoffUnavailable",message="Arrival handoff availability could not be established.");
        return val(probe.is_free[1])==1;
    }

    // Lifecycle writers hold the plan row. Once a current sender releases this lock,
    // another dispatcher cannot pass its final plan check ahead of the writer.
    public void function awaitHandoff(required numeric planId,string ds="fpw",numeric waitSeconds=20) {
        if (this.isFree(planId,ds)) return;
        transaction {
            var handle=this.acquireInTransaction(planId,ds,waitSeconds);
            this.release(handle);
        }
    }

    private void function discardOwner(required struct handle) {
        try {
            var row=queryExecute("SELECT CONNECTION_ID() AS id, IS_USED_LOCK(:name) AS owner",
                {name=handle.lockName},{datasource=handle.ds,timeout=5});
            if (row.id[1]==handle.connectionId && val(row.owner[1] ?: 0)==handle.connectionId)
                queryExecute("KILL CONNECTION " & int(handle.connectionId),{},{datasource=handle.ds,timeout=5});
        } catch (any disconnected) {
            // Killing one's own connection can itself raise a connection-closed error.
        }
    }
}
