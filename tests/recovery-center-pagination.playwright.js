async (page) => {
 const base="http://localhost:8500/fpw",endpoint=base+"/admin/recovery-center-data.cfm";
 const fixtureUrl=base+"/tests/inactive-member-recovery-enrollment-integration-fixture.cfm?confirm=RUN_RECOVERY_ENROLLMENT_INTEGRATION";
 const get=(o,k,f)=>{const p=o&&Object.keys(o).find(n=>n.toLowerCase().replace(/_/g,"")===k.toLowerCase().replace(/_/g,""));return p===undefined?f:o[p];};
 const result={checks:[],consoleErrors:[]};let fixture,context,admin;
 const check=(ok,name)=>{result.checks.push({name,passed:!!ok});if(!ok)throw new Error(name);};
 async function fixtureCall(action,request=page.request){const r=await request.get(fixtureUrl+"&action="+action+(fixture?"&runKey="+get(fixture,"runKey"):""));const v=await r.json();if(!r.ok()||!get(v,"ok"))throw new Error("Fixture "+action+": "+JSON.stringify(v));return v;}
 try {
  fixture=await fixtureCall("prepareCenter");const members=get(fixture,"members"),member=get(members,"center"),memberId=get(member,"userId"),adminUser=get(members,"admin");
  context=await page.context().browser().newContext({viewport:{width:1440,height:1000}});admin=await context.newPage();admin.on("pageerror",error=>result.consoleErrors.push(error.message));
  await admin.goto(base+"/app/login.cfm");await admin.locator("#email").fill(get(adminUser,"email"));await admin.locator("#password").fill(get(fixture,"password"));
  await Promise.all([admin.waitForURL(/dashboard[.]cfm/,{timeout:25000}),admin.locator("#loginButton").click()]);
  const seeded=await fixtureCall("seedCenterPagination",admin.request);const runId=get(seeded,"runId");
  const api=async(action,params={})=>{const r=await admin.request.get(endpoint,{params:{action,...params}});const v=await r.json();return {status:r.status(),value:v,data:get(v,"DATA",{})};};
  const first=await api("member",{userId:memberId,pageSize:25}),second=await api("member",{userId:memberId,pageSize:25,messagesPage:2,evaluationsPage:2,historyPage:2});
  for(const kind of ["messages","evaluations","history"]) {
   const id=kind==="messages"?"messageId":kind==="evaluations"?"evaluationId":"eventId";
   check(get(get(first.data,kind+"Pagination"),"total")>25,kind+" total exposes all persisted fixture records");
   check(get(first.data,kind).length===25&&get(second.data,kind).length>0,kind+" second page is reachable through authenticated API");
   const firstIds=get(first.data,kind).map(row=>get(row,id));check(get(second.data,kind).every(row=>!firstIds.includes(get(row,id))),kind+" pages contain distinct immutable records");
  }
  const bounded=await api("member",{userId:memberId,pageSize:999});check(get(get(bounded.data,"messagesPagination"),"pageSize")===100,"HTTP page size is bounded at100");
  for(const key of ["messagesPage","evaluationsPage","historyPage"])check((await api("member",{userId:memberId,[key]:"1 OR 1=1"})).status===400,key+" injection is rejected");
  await admin.goto(base+"/admin/recovery-center.cfm");
  const idle=()=>admin.waitForFunction(()=>!document.querySelector("#recoveryCenter").hasAttribute("aria-busy"),{},{timeout:30000});await idle();
  const tab=async name=>{await admin.getByRole("tab",{name,exact:true}).click();await idle();check(!await admin.locator("#rcStatus.is-error").count(),name+" loads with paginated data");};
  await tab("Members");await admin.locator("#rcMemberFilter input").fill(get(member,"email"));await admin.locator("#rcMemberFilter button").click();await idle();await admin.locator("#rcMembersTable button").click();await idle();
  for(const [label,target] of [["messages","#rcMemberMessages"],["evaluations","#rcMemberEvaluations"],["history","#rcTimeline"]]) {
    await admin.getByRole("button",{name:"Next "+label,exact:true}).click();await idle();
    check((await admin.locator(target+" .rc-pager").textContent()).includes("Page 2"),label+" Next control changes its independent page");
    check(!await admin.getByRole("button",{name:"Previous "+label,exact:true}).isDisabled(),label+" Previous control is enabled");
    await admin.getByRole("button",{name:"Previous "+label,exact:true}).click();await idle();
    check((await admin.locator(target+" .rc-pager").textContent()).includes("Page 1"),label+" Previous returns to first page");
  }
  await admin.screenshot({path:"/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/.codex-snapshots/20261003T165055Z-recovery-center/ui/member-history-pagination.png",fullPage:true});
  await tab("Runs");await admin.locator("#rcRunsTable").getByRole("button",{name:String(runId),exact:true}).click();await idle();
  await admin.getByRole("button",{name:"Next run evaluations",exact:true}).click();await idle();
  check(await admin.locator("#rcRunDetail tbody tr").count()===1,"Run evaluations second page reaches final record");
  check((await admin.locator("#rcRunDetail .rc-pager").textContent()).includes("26 records"),"Run evaluation pagination shows exact total");
  await tab("Settings");await admin.getByRole("button",{name:"Next audit",exact:true}).click();await idle();
  check((await admin.locator("#rcSettingsAudit .rc-pager").textContent()).includes("Page 2"),"Settings audit next page is reachable");
  await admin.getByRole("button",{name:"Previous audit",exact:true}).click();await idle();check((await admin.locator("#rcSettingsAudit .rc-pager").textContent()).includes("Page 1"),"Settings audit previous page works");
  const settings=get((await api("settings")).value,"DATA",{});check(get(settings,"resetAtUtc")==="2026-10-03T17:36:28Z"&&get(settings,"resetCohortCount")===2,"Actual reset remains unchanged");
  await tab("Performance");check((await admin.locator("#rcPeriodActivity").textContent()).includes("All-time accepted ledger contacts without message telemetry (all contacts/destinations)"),"Missing-ledger telemetry label declares all-time all-contact scope");
  check(result.consoleErrors.length===0,"No pagination JavaScript errors");
  // Native scheduler pause verification is retained as separate read-only rollout evidence.
 } catch(error){result.error=error.message;}
 finally{if(fixture){try{const cleanup=await fixtureCall("cleanup");result.cleanupConfirmed=get(cleanup,"ok");}catch(error){result.cleanupError=error.message;}}if(context)await context.close();}
 result.passed=result.checks.filter(x=>x.passed).length;result.total=result.checks.length;return result;
}
