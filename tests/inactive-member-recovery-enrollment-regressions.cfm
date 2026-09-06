<cfsetting showdebugoutput="false" enablecfoutputonly="true" requesttimeout="180">
<cfcontent type="application/json; charset=utf-8" reset="true">
<cfscript>
localOnly=listFindNoCase("localhost,127.0.0.1,::1",cgi.server_name) GT 0
  AND reFindNoCase("^(localhost|127\.0\.0\.1|\[::1\])(:8500)?$",cgi.http_host) GT 0 AND val(cgi.server_port) EQ 8500;
if (!localOnly OR !structKeyExists(url,"confirm") OR url.confirm NEQ "RUN_RECOVERY_ENROLLMENT_REGRESSIONS") {
  cfheader(statuscode=404); writeOutput(serializeJSON({ok=false})); abort;
}
// These four omitted classifier specs insert delivery/claim fixture rows. Keep this run claim-free.
selected=[
  "returns MEMBER_NOT_FOUND without creating recovery state",
  "classifies an account-only member as A at the exact 168-hour boundary",
  "defers at 167 hours 59 minutes 59 seconds",
  "classifies an owned vessel with durable creation evidence as B",
  "holds a vessel stage without a verified B clock",
  "classifies a saved named route with no legs as C",
  "classifies a saved named route with persisted legs as C",
  "classifies an owned Draft as D and enforces highest-stage precedence",
  "classifies a persisted generated Draft as D",
  "permanently suppresses durable Basic sharing evidence",
  "permanently suppresses durable Premium sharing evidence",
  "keeps positive sharing suppression independent of the timing clock",
  "keeps Basic sharing suppression after its parent record is absent",
  "treats an owned initial-send timestamp as positive sharing evidence",
  "suppresses a real non-essential opt-out",
  "holds when preference lookup fails",
  "suppresses an authoritative active administrator entitlement",
  "suppresses an invalid current recipient",
  "holds duplicate normalized recipient identity",
  "suppresses an active trip without treating it as a Draft",
  "suppresses current monitoring",
  "delays for recent qualifying activity through the real policy",
  "requires explicit enrollment and never invents it from deployment time",
  "holds historical regression instead of downgrading after deletion",
  "holds future activity and inconsistent Draft lifecycle evidence",
  "holds cross-member event ownership and returns only safe evidence metadata",
  "holds cross-member update activity instead of using its timestamp",
  "does not write events or ledger rows while evaluating"
];
results=new testbox.system.TestBox(bundles="fpw.tests.specs.InactiveMemberRecoveryClassifierSpec").runRaw(testSpecs=selected).getMemento();
settings=new fpw.api.v1.InactiveMemberRecoveryService().getRunnerSettings();
writeOutput(serializeJSON({SUCCESS=results.totalFail EQ 0 AND results.totalError EQ 0,RESULTS=results,LIVE_ENABLED=settings.liveEnabled}));
</cfscript>
