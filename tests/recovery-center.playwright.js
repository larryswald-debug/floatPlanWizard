// Real admin requests with fresh local fixture accounts. SMTP safety is checked before local personal mail.
async (page) => {
  const base="http://localhost:8500/fpw",dataUrl=base+"/admin/recovery-center-data.cfm";
  const fixtureUrl=base+"/tests/inactive-member-recovery-enrollment-integration-fixture.cfm?confirm=RUN_RECOVERY_ENROLLMENT_INTEGRATION";
  const get=(o,k,fallback)=>{const key=o&&Object.keys(o).find(n=>n.toLowerCase().replace(/_/g,"")===k.toLowerCase().replace(/_/g,""));return key===undefined?fallback:o[key];};
  const results=[],contexts=[],errors=[],mailIds=[];
  let prepared,cleanupVerified=false,failure="",admin,settingsBefore;
  const assert=(ok,name)=>{results.push({name,passed:!!ok});if(!ok)throw new Error(name);};
  async function fixture(action) {
    const r=await page.request.get(fixtureUrl+"&action="+action+(prepared?"&runKey="+get(prepared,"runKey"):""));
    const value=await r.json();if(!r.ok()||!get(value,"ok"))throw new Error("Fixture "+action+": "+JSON.stringify(value));return value;
  }
  async function login(member) {
    const context=await page.context().browser().newContext();contexts.push(context);const p=await context.newPage();
    await p.goto(base+"/app/login.cfm");await p.locator("#email").fill(get(member,"email"));await p.locator("#password").fill(get(prepared,"password"));
    await Promise.all([p.waitForURL(/dashboard[.]cfm/,{timeout:25000}),p.locator("#loginButton").click()]);
    return p;
  }
  async function request(action,values={},post=false,csrf) {
    const options=post?{form:{action,...values,adminCsrfToken:csrf===undefined?await admin.evaluate(()=>window.FPW_ADMIN_CSRF_TOKEN):csrf}}:{params:{action,...values}};
    const r=await (post?admin.request.post(dataUrl,options):admin.request.get(dataUrl,options));
    const body=await r.text();let value;try{value=JSON.parse(body);}catch(error){value={SUCCESS:false,MESSAGE:body};}return {status:r.status(),value,data:get(value,"DATA",{})};
  }
  async function okRequest(action,values={},post=false) {
    const r=await request(action,values,post);
    if(!get(r.value,"SUCCESS"))throw new Error(action+" "+r.status+" "+JSON.stringify(r.value));
    return r.data;
  }
  async function idle() {await admin.waitForFunction(()=>!document.querySelector("#recoveryCenter").hasAttribute("aria-busy"),{},{timeout:30000});}
  async function tab(name) {await admin.getByRole("tab",{name,exact:true}).click();await idle();if(await admin.locator("#rcStatus.is-error").count()){const action=name==="Recovery Queue"?"queue":name.toLowerCase();const d=await admin.request.get(base+"/tests/recovery-center-diagnostic.cfm?confirm=RUN_RECOVERY_CENTER_DIAGNOSTIC&action="+action);throw new Error("Tab "+name+" failed: "+await admin.locator("#rcStatus").textContent()+" diagnostic="+await d.text());}assert(true,"Tab "+name+" loads");}
  async function clickAction(name) {await admin.getByRole("button",{name,exact:true}).click();await idle();assert(!await admin.locator("#rcStatus.is-error").count(),name+" succeeds"+(await admin.locator("#rcStatus.is-error").count()?": "+await admin.locator("#rcStatus").textContent():""));}
  try {
    const anonymous=await page.request.get(base+"/admin/recovery-center.cfm");
    assert(anonymous.status()===401,"Anonymous admin page blocked");
    assert((await page.request.post(dataUrl,{form:{action:"personalSend"}})).status()===401,"Anonymous personal send blocked");
    prepared=await fixture("prepareCenter");
    const members=get(prepared,"members"),center=get(members,"center"),id=get(center,"userId");
    const ordinary=await login(get(members,"member"));
    assert((await ordinary.request.get(dataUrl+"?action=dashboard")).status()===403,"Ordinary member report access blocked");
    admin=await login(get(members,"admin"));admin.on("pageerror",e=>errors.push(e.message));
    await admin.goto(base+"/admin/recovery-center.cfm");await idle();
    const status=await admin.locator("#rcStatus").textContent();
    if(await admin.locator("#rcStatus.is-error").count()) {
      const diagnostic=await admin.request.get(base+"/tests/recovery-center-diagnostic.cfm?confirm=RUN_RECOVERY_CENTER_DIAGNOSTIC&action=dashboard");
      throw new Error("Dashboard failed: "+status+" "+await diagnostic.text());
    }
    assert(await admin.getByRole("tab").count()===6,"All six Recovery Center tabs are present");
    for(const name of ["Recovery Queue","Runs","Members","Performance","Settings","Dashboard"])await tab(name);
    const pageOne=await okRequest("queue",{page:1,pageSize:1}),pageTwo=await okRequest("queue",{page:2,pageSize:1});
    assert(get(pageOne,"rows").length===1&&get(pageTwo,"rows").length===1&&get(get(pageOne,"rows")[0],"userId")!==get(get(pageTwo,"rows")[0],"userId"),"Queue pagination returns distinct members");
    const initial=await okRequest("member",{userId:id}),before=get(initial,"member");
    assert(get(before,"contactNumber")===1&&get(before,"destinationStage")==="A","Fresh member is Contact #1 and independently Destination A");
    assert((await request("pause",{userId:id},true,"invalid")).status===403,"CSRF failure blocks state change");
    assert(!get((await request("pause",{userId:id})).value,"SUCCESS"),"GET cannot mutate recovery state");
    assert(!get((await request("personalPreview",{userId:id,subject:"Text",body:"Text",toEmail:"outside@example.test"},true)).value,"SUCCESS"),"Posted arbitrary recipient rejected");
    assert(!get((await request("personalPreview",{userId:id,subject:"Hello\nBcc: outside@example.test",body:"Text"},true)).value,"SUCCESS"),"Personal subject header injection rejected");
    await tab("Members");
    await admin.locator("#rcMemberFilter input").fill(get(center,"email"));
    await admin.locator("#rcMemberFilter button").click();await idle();
    assert(await admin.locator("#rcMembersTable tbody tr").count()===1,"Member search isolates fresh fixture");
    await admin.locator("#rcMembersTable button").click();await idle();
    assert((await admin.locator("#rcMemberContext").textContent()).includes("#1 of 3"),"Member detail labels contact separately");
    await clickAction("Pause recovery");
    assert(get(get(await okRequest("member",{userId:id}),"member"),"paused")===true,"Pause persists");
    assert(!get((await request("personalPreview",{userId:id,subject:"Test",body:"Test"},true)).value,"SUCCESS"),"Pause blocks personal follow-up");
    await clickAction("Exclude member");await clickAction("Resume recovery");
    const excluded=get(await okRequest("member",{userId:id}),"member");
    assert(get(excluded,"excluded")===true&&get(excluded,"paused")===false,"Resume preserves independent exclusion");
    assert(!get((await request("personalPreview",{userId:id,subject:"Test",body:"Test"},true)).value,"SUCCESS"),"Exclusion blocks personal follow-up");
    await clickAction("Remove exclusion");
    const after=get(await okRequest("member",{userId:id}),"member");
    assert(get(after,"recoveryStartUtc")===get(before,"recoveryStartUtc")&&get(after,"contactNumber")===1,"State controls preserve clock and contact history");
    await clickAction("Refresh eligibility");
    const refreshed=await okRequest("member",{userId:id});
    assert(get(refreshed,"evaluations").length>0,"Eligibility refresh records immutable evaluation");
    await clickAction("Preview next contact");
    assert(await admin.locator("#rcPreviewDialog").isVisible(),"Current contact preview opens");
    const srcdoc=await admin.locator("#rcPreviewFrame").getAttribute("srcdoc");
    assert(srcdoc.includes("default-src 'none'")&&!/<(?:img|script|iframe)\b/i.test(srcdoc),"Preview disables network images scripts and subframes");
    assert(!/[?&](?:t|token)=[a-zA-Z0-9_.-]{32,}/.test(srcdoc),"Preview redacts bearer tokens");
    await admin.locator("#rcPreviewClose").click();
    await tab("Settings");
    settingsBefore=await okRequest("settings");
    for(const invalid of ["0","721","1.5","-1","abc"]) {
      assert(!get((await request("settingsPreview",{firstDelayHours:invalid,stageIntervalHours:24,attributionWindowHours:24},true)).value,"SUCCESS"),"Invalid timing "+invalid+" rejected");
    }
    const values={firstDelayHours:get(settingsBefore,"firstDelayHours"),stageIntervalHours:get(settingsBefore,"stageIntervalHours"),attributionWindowHours:get(settingsBefore,"attributionWindowHours")};
    await admin.locator("#rcSettingsForm button").click();await idle();
    assert(await admin.locator("#rcSettingsReview").isVisible(),"Timing impact review shown");
    assert(await admin.locator("#rcSettingsSave").isDisabled(),"Timing confirmation required");
    await admin.locator("#rcSettingsConfirm").check();await clickAction("Save reviewed timing");
    assert(get(await okRequest("settings"),"revision")===get(settingsBefore,"revision")+1,"Confirmed same-value save persists new audited revision");
    const stale=await okRequest("settingsPreview",values,true);
    await okRequest("pause",{userId:id},true);
    assert(!get((await request("settingsSave",{reviewToken:get(stale,"reviewToken"),confirmed:"YES"},true)).value,"SUCCESS"),"Changed member impact rejects stale settings confirmation");
    await okRequest("resume",{userId:id},true);
    const reset=await request("resetPreview",{},true);
    if(get(reset.value,"SUCCESS")) {
      const unconfirmed=await request("resetCommit",{reviewToken:get(reset.data,"reviewToken"),confirmed:"NO"},true);
      assert(!get(unconfirmed.value,"SUCCESS"),"Initial reset requires explicit confirmation");
    } else assert(["RESET_ALREADY_COMPLETED","RESET_REQUIRES_EMPTY_LEDGER","ENROLLMENT_INVALID"].includes(get(reset.value,"CODE")),"Reset safely refuses unavailable cohort");
    // Never execute global reset in an ephemeral browser cohort; root validates the actual original cohort separately.
    await tab("Members");
    await admin.locator("#rcMemberFilter input").fill(get(center,"email"));await admin.locator("#rcMemberFilter button").click();await idle();await admin.locator("#rcMembersTable button").click();await idle();
    await admin.locator("#rcPersonalSubject").fill("Recovery Center local proof");
    await admin.locator("#rcPersonalBody").fill("Hello <script>alert('escaped')</script>\nA local-only personal follow-up.");
    const personalReviewResponse=admin.waitForResponse(r=>r.url().includes("/admin/recovery-center-data.cfm")&&(r.request().postData()||"").includes("action=personalPreview"));
    await admin.locator("#rcPersonalForm button").click();await idle();
    const reviewedPersonalToken=get(get(await (await personalReviewResponse).json(),"DATA"),"reviewToken");
    assert(await admin.locator("#rcPreviewDialog").isVisible(),"Personal follow-up uses actual rendered preview");
    assert((await admin.locator("#rcPersonalReviewSummary").textContent()).includes(get(center,"email")),"Personal review shows database-selected recipient");
    assert(!(await admin.locator("#rcPreviewFrame").getAttribute("srcdoc")).includes("<script>"),"Personal HTML is escaped in preview");
    await admin.locator("#rcPreviewClose").click();
    const safety=await (await admin.request.get(base+"/tests/auth-mail-safety-probe.cfm?confirm=READ_AUTH_MAIL_SAFETY")).json();
    assert(get(safety,"SAFE_LOCAL_MAIL")===true,"Actual mail transport is isolated local MailHog");
    await admin.locator("#rcPersonalConfirm").check();await clickAction("Send reviewed follow-up");
    const sentDetail=await okRequest("member",{userId:id}),messages=get(sentDetail,"messages");
    assert(messages.length===1&&get(messages[0],"status")==="SEND_ACCEPTED","Personal message is accepted once by local capture");
    assert(get(get(sentDetail,"member"),"contactNumber")===1,"Personal mail does not consume automated contact");
    const replay=await request("personalSend",{reviewToken:reviewedPersonalToken,confirmed:"YES"},true);
    assert(!get(replay.value,"SUCCESS")&&get(replay.value,"CODE")==="REVIEW_REQUIRED","Same valid personal submission token cannot replay after acceptance");
    assert(get(await okRequest("member",{userId:id}),"messages").length===1,"Valid replay creates no second message");
    const preview=await okRequest("preview",{messageId:get(messages[0],"messageId")});
    assert(!/[?&](?:t|token)=[a-zA-Z0-9_.-]{32,}/.test(JSON.stringify(preview)),"Historical message preview redacts tokens");
    await tab("Runs");assert(await admin.locator("#rcRunsTable tbody tr").count()>0,"Recorded refresh run visible");
    await admin.locator("#rcRunsTable tbody button").first().click();await idle();assert(await admin.locator("#rcRunDetail").isVisible(),"Run detail opens");
    await tab("Performance");await admin.locator("#rcPerformanceFilter select[name=days]").selectOption("7");await admin.locator("#rcPerformanceFilter button").click();await idle();
    assert(!await admin.locator("#rcStatus.is-error").count(),"7-day performance filter is supported");
    await admin.locator("#rcPerformanceFilter select[name=days]").selectOption("0");await admin.locator("#rcPerformanceFilter button").click();await idle();
    assert(!await admin.locator("#rcStatus.is-error").count(),"All-history performance filter is supported");
    await admin.setViewportSize({width:1440,height:1100});
    for(const name of ["Dashboard","Recovery Queue","Runs","Members","Performance","Settings"]){await tab(name);if(name==="Recovery Queue"){await admin.locator("#rcQueueFilter input[name=search]").fill(get(center,"email"));await admin.locator("#rcQueueFilter button").click();await idle();}await admin.screenshot({path:"/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/.codex-snapshots/20261003T165055Z-recovery-center/ui/"+name.toLowerCase().replace(/ /g,"-")+"-desktop.png",fullPage:true});}
    await admin.setViewportSize({width:390,height:844});await tab("Members");
    await admin.screenshot({path:"/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/.codex-snapshots/20261003T165055Z-recovery-center/ui/members-mobile.png",fullPage:true});
    assert(await admin.evaluate(()=>document.documentElement.scrollWidth<=window.innerWidth+1),"Mobile document has no horizontal overflow");
    assert(errors.length===0,"No Recovery Center JavaScript errors");
  } catch(error) { failure=error.message;results.push({name:failure,passed:false}); }
  finally {
    if(prepared) {
      try {
        const member=get(get(prepared,"members"),"center"),email=get(member,"email");
        // Delete only this fixture's captured message, never the rest of the local mailbox.
        const listing=await page.request.get("http://localhost:8025/api/v2/search",{params:{kind:"to",query:email}});
        if(listing.ok()) for(const item of (await listing.json()).items||[]) {
          const id=item.ID;await page.request.delete("http://localhost:8025/api/v1/messages/"+encodeURIComponent(id));mailIds.push(id);
        }
      } catch(error) {results.push({name:"Mail capture cleanup: "+error.message,passed:false});}
      try {const cleaned=await fixture("cleanup");cleanupVerified=get(cleaned,"ok")===true;assert(cleanupVerified,"Disposable database fixture cleanup succeeds");}
      catch(error){results.push({name:"Fixture cleanup: "+error.message,passed:false});}
    }
    for(const context of contexts)await context.close();
  }
  return {ok:!failure&&results.every(r=>r.passed),results,cleanupVerified,consoleErrors:errors,localMailRemoved:mailIds.length};
}
