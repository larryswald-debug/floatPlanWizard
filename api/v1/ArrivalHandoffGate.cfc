component output="false" hint="Internal plan-specific fence between checked arrival handoff and lifecycle changes." {
    // DATABASE() must be evaluated by the same datasource, never inferred from an application URL.
    private string function keyExpression() {
        return "CONCAT('fpw:arrival:', LEFT(SHA2(DATABASE(),256),24), ':', ";
    }

    // An opaque handle owns one independent JDBC session until release. queryExecute
    // by itself is not a session pin across the transaction/SMTP boundary.
    public struct function acquire(required numeric planId, string ds="fpw", numeric waitSeconds=20) {
        if (planId<=0 || fix(planId)!=planId || waitSeconds<0 || waitSeconds>30 || fix(waitSeconds)!=waitSeconds)
            throw(type="FPW.ArrivalHandoffUnavailable",message="Invalid arrival handoff parameters.");
        var conn="";
        var stmt="";
        var rows="";
        var sessionId=0;
        var mayOwn=false;
        var acquired=false;
        try {
            var source=createObject("java","coldfusion.server.ServiceFactory").getDataSourceService().getDatasource(ds);
            conn=source.getConnection();
            if (!conn.getAutoCommit())
                throw(type="FPW.ArrivalHandoffUnavailable",message="Arrival handoff requires an independent autocommit connection.");
            stmt=conn.prepareStatement("SELECT CONNECTION_ID(), " & keyExpression() & "?)");
            stmt.setQueryTimeout(javaCast("int",5));
            stmt.setLong(javaCast("int",1),javaCast("long",planId));
            rows=stmt.executeQuery();
            if (!rows.next()) throw(type="FPW.ArrivalHandoffUnavailable",message="No arrival handoff session.");
            sessionId=rows.getLong(javaCast("int",1));
            var key=rows.getString(javaCast("int",2));
            if (!len(key) || sessionId<=0) throw(type="FPW.ArrivalHandoffUnavailable",message="No arrival handoff identity.");
            rows.close();
            stmt.close();

            // Fail closed if a pooled session was returned with a stale ownership count.
            stmt=conn.prepareStatement("SELECT IS_USED_LOCK(?)");
            stmt.setQueryTimeout(javaCast("int",5));
            stmt.setString(javaCast("int",1),key);
            rows=stmt.executeQuery();
            if (!rows.next()) throw(type="FPW.ArrivalHandoffUnavailable",message="Arrival handoff ownership unavailable.");
            if (rows.getLong(javaCast("int",1))==sessionId) {
                mayOwn=true;
                throw(type="FPW.ArrivalHandoffUnavailable",message="An abandoned arrival handoff session was detected.");
            }
            rows.close();
            stmt.close();

            stmt=conn.prepareStatement("SELECT GET_LOCK(?,?)");
            stmt.setQueryTimeout(javaCast("int",waitSeconds+3));
            stmt.setString(javaCast("int",1),key);
            stmt.setInt(javaCast("int",2),javaCast("int",waitSeconds));
            mayOwn=true;
            rows=stmt.executeQuery();
            if (!rows.next()) throw(type="FPW.ArrivalHandoffUnavailable",message="Arrival handoff acquisition unavailable.");
            var granted=rows.getInt(javaCast("int",1));
            if (rows.wasNull()) throw(type="FPW.ArrivalHandoffUnavailable",message="Arrival handoff acquisition unavailable.");
            if (granted!=1) {
                mayOwn=false;
                throw(type="FPW.ArrivalHandoffBusy",message="Arrival submission is busy. Retry the operation.");
            }
            acquired=true;
            return {connection=conn,lockName=key,connectionId=sessionId};
        } catch (FPW.ArrivalHandoffBusy busy) {
            rethrow;
        } catch (any failure) {
            throw(type="FPW.ArrivalHandoffUnavailable",message="The arrival handoff fence is unavailable.");
        } finally {
            closeQuietly(rows);
            closeQuietly(stmt);
            if (!acquired && isObject(conn)) {
                if (mayOwn && sessionId>0) discardSession(conn,sessionId);
                closeQuietly(conn);
            }
        }
    }

    public void function release(required struct handle) {
        var stmt="";
        var rows="";
        var verified=false;
        try {
            stmt=handle.connection.prepareStatement("SELECT RELEASE_LOCK(?), CONNECTION_ID()");
            stmt.setQueryTimeout(javaCast("int",5));
            stmt.setString(javaCast("int",1),handle.lockName);
            rows=stmt.executeQuery();
            verified=rows.next() && rows.getInt(javaCast("int",1))==1 && rows.getLong(javaCast("int",2))==handle.connectionId;
        } catch (any failure) {
            verified=false;
        } finally {
            closeQuietly(rows);
            closeQuietly(stmt);
            if (!verified) discardSession(handle.connection,handle.connectionId);
            closeQuietly(handle.connection);
        }
        if (!verified) throw(type="FPW.ArrivalHandoffUnavailable",message="Arrival handoff release could not be verified.");
    }

    public boolean function isFree(required numeric planId, string ds="fpw") {
        if (planId<=0 || fix(planId)!=planId) throw(type="FPW.ArrivalHandoffUnavailable",message="Invalid arrival handoff plan.");
        var probe=queryExecute("SELECT IS_FREE_LOCK(" & keyExpression() & ":p)) AS is_free",
            {p={value=planId,cfsqltype="cf_sql_bigint"}},{datasource=ds,timeout=5});
        if (probe.recordCount!=1 || isNull(probe.is_free[1]))
            throw(type="FPW.ArrivalHandoffUnavailable",message="Arrival handoff availability could not be established.");
        return val(probe.is_free[1])==1;
    }

    // Caller holds the canonical plan row lock, so another compliant dispatcher
    // cannot pass its final check and acquire this gate during the fast path.
    public void function awaitHandoff(required numeric planId, string ds="fpw", numeric waitSeconds=20) {
        if (this.isFree(planId,ds)) return;
        var handle=this.acquire(planId,ds,waitSeconds);
        this.release(handle);
    }

    private void function closeQuietly(required any value) {
        if (isObject(value)) {
            try { value.close(); } catch (any ignoredClose) {}
        }
    }

    // A pool close alone may retain a named lock. If release is uncertain,
    // disconnect only this server session, never an id taken from request data.
    private void function discardSession(required any connection,required numeric sessionId) {
        var discard="";
        try {
            discard=connection.createStatement();
            discard.setQueryTimeout(javaCast("int",5));
            discard.execute("KILL CONNECTION " & int(sessionId));
        } catch (any disconnected) {
            // Killing one's own connection can itself raise a connection-closed error.
        } finally {
            closeQuietly(discard);
        }
    }
}
