component extends="testbox.system.BaseSpec" output="false" {
  function run() {
    describe("Inactive member recovery ledger", function() {
      it("compiles and exposes only the dedicated ledger operations", function() {
        var service=createObject("component","fpw.includes.InactiveMemberRecoveryLedgerService").init("fpw");
        expect(isObject(service)).toBeTrue();
        expect(structKeyExists(service,"claimStage")).toBeTrue();
        expect(structKeyExists(service,"retryFailedStage")).toBeTrue();
        expect(structKeyExists(service,"markSent")).toBeTrue();
        expect(structKeyExists(service,"markFailed")).toBeTrue();
        expect(structKeyExists(service,"getStageState")).toBeTrue();
        expect(structKeyExists(service,"getLastSuccessfulRecoveryUtc")).toBeTrue();
      });
      it("rejects invalid stages and nonexistent members without rows", function() {
        var service=new fpw.includes.InactiveMemberRecoveryLedgerService("fpw");
        expect(service.claimStage(1,"Z").CODE).toBe("INVALID_STAGE");
        expect(service.claimStage(2147483647,"A").CODE).toBe("MEMBER_NOT_FOUND");
        var count=queryExecute("SELECT COUNT(*) AS total FROM inactive_member_recovery_deliveries
          WHERE user_id=2147483647",{},{datasource="fpw"});
        expect(val(count.total[1])).toBe(0);
      });
      it("has the exact column, unique, foreign-key, and check contracts", function() {
        var columns=queryExecute("SELECT column_name,column_type,is_nullable FROM information_schema.columns
          WHERE table_schema=DATABASE() AND table_name='inactive_member_recovery_deliveries'",{}, {datasource="fpw"});
        expect(columns.recordCount).toBe(12);
        var uniqueIndex=queryExecute("SELECT GROUP_CONCAT(column_name ORDER BY seq_in_index) AS names
          FROM information_schema.statistics WHERE table_schema=DATABASE()
          AND table_name='inactive_member_recovery_deliveries'
          AND index_name='uq_inactive_recovery_member_stage' AND non_unique=0",{}, {datasource="fpw"});
        expect(uniqueIndex.names[1]).toBe("user_id,recovery_stage");
        var fk=queryExecute("SELECT delete_rule FROM information_schema.referential_constraints
          WHERE constraint_schema=DATABASE() AND table_name='inactive_member_recovery_deliveries'
          AND constraint_name='fk_inactive_recovery_user'",{}, {datasource="fpw"});
        expect(fk.recordCount).toBe(1);
        expect(fk.delete_rule[1]).toBe("CASCADE");
        var checks=queryExecute("SELECT COUNT(*) AS total FROM information_schema.table_constraints
          WHERE constraint_schema=DATABASE() AND table_name='inactive_member_recovery_deliveries'
          AND constraint_type='CHECK'",{}, {datasource="fpw"});
        expect(val(checks.total[1])).toBe(4);
      });
      it("keeps an empty diagnostic read free of claim identity", function() {
        var service=new fpw.includes.InactiveMemberRecoveryLedgerService("fpw");
        var state=service.getStageState(1,"A");
        expect(state.CODE).toBe("NOT_CLAIMED");
        expect(structKeyExists(state,"CLAIM_TOKEN")).toBeFalse();
        var latest=service.getLastSuccessfulRecoveryUtc(1);
        expect(latest.CODE).toBe("NO_SUCCESSFUL_RECOVERY");
        expect(latest.HAS_SENT).toBeFalse();
      });
    });
  }
}
