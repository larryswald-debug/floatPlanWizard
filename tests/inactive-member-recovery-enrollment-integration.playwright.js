// Local disposable signup and admin cohort evidence. Recovery sending and production settings are never invoked.
async (page) => {
  const base="http://localhost:8500/fpw";
  const endpoint=base+"/tests/inactive-member-recovery-enrollment-integration-fixture.cfm?confirm=RUN_RECOVERY_ENROLLMENT_INTEGRATION";
  const adminUrl=base+"/admin/recovery-enrollment.cfm";
  const get=(o,k)=>o?.[k]??o?.[k.toUpperCase()]??o?.[k.toLowerCase()];
  const reports=[],contexts=[],mailCleanup=[];
  let prepared,cleanup,error="";
  const assert=(ok,label)=>{if(!ok)throw new Error(label);reports.push(label);};
  async function command(action,request=page.request) {
    const r=await request.get(endpoint+"&action="+action+(prepared?"&runKey="+get(prepared,"runKey"):""));
    const value=await r.json();if(!r.ok()||get(value,"ok")===false)throw new Error(action+": "+JSON.stringify(value));return value;
  }
  async function contextPage() {
    const c=await page.context().browser().newContext();contexts.push(c);return {c,p:await c.newPage()};
  }
  async function login(member) {
    const a=await contextPage();
    await a.p.goto(base+"/app/login.cfm");
    await a.p.locator("#email").fill(get(member,"email"));
    await a.p.locator("#password").fill(get(prepared,"password"));
    await Promise.all([a.p.waitForURL(/dashboard[.]cfm/,{timeout:20000}),a.p.locator("#loginButton").click()]);
    return a;
  }
  async function preview(a,ids) {
    await a.p.goto(adminUrl+"?action=preview&userIds="+encodeURIComponent(ids));
    await a.p.locator("#recoveryEnrollmentReport").waitFor();
    return report(a.p);
  }
  async function report(p) {
    return p.evaluate(()=>({
      mode:document.querySelector("#recoveryEnrollmentReport")?.getAttribute("data-mode"),
      scanned:Number(document.querySelector("#recoveryEnrollmentScanned")?.textContent),
      eligible:Number(document.querySelector("#recoveryEnrollmentEligible")?.textContent),
      already:Number(document.querySelector("#recoveryEnrollmentAlreadyEnrolled")?.textContent),
      newly:Number(document.querySelector("#recoveryEnrollmentNewlyEnrolled")?.textContent),
      skipped:Number(document.querySelector("#recoveryEnrollmentSkipped")?.textContent),
      failures:Number(document.querySelector("#recoveryEnrollmentFailures")?.textContent),
      text:document.querySelector("#recoveryEnrollmentMessage")?.textContent,
      token:document.querySelector('input[name="reviewToken"]')?.value,
      csrf:document.querySelector('input[name="adminCsrfToken"]')?.value,
      rows:[...document.querySelectorAll("#recoveryEnrollmentRows tr")].map(e=>({id:Number(e.dataset.userId),code:e.dataset.code,text:e.textContent,
        reason:e.cells[2]?.textContent.trim(),enrollmentUtc:e.cells[3]?.textContent.trim(),
        coverage:e.cells[4]?.textContent.trim(),errorReference:e.cells[5]?.textContent.trim()}))
    }));
  }
  async function post(a,review,extra={}) {
    return a.p.request.post(adminUrl,{form:{action:"enroll",reviewToken:review.token,adminCsrfToken:review.csrf,
      confirmation:"ENROLL REVIEWED MEMBERS",...extra}});
  }
  const memberState=(state,id)=>get(get(state,"members"),String(id));
  try {
    prepared=await command("prepare");
    const members=get(prepared,"members"),id=k=>get(get(members,k),"userId");
    const email=get(prepared,"signupEmail");
    const anonymous=await contextPage();
    assert((await anonymous.p.request.get(adminUrl)).status()===401,"anonymous admin access denied");
    const ordinary=await login(get(members,"member"));
    assert((await ordinary.p.request.get(adminUrl)).status()===403,"non-admin member cannot preview cohorts");
    const admin=await login(get(members,"admin"));
    const initial=await command("inspect");
    assert(get(memberState(initial,id("admin")),"enrollments")===0,"ordinary login does not enroll existing admin");
    assert(get(memberState(initial,id("member")),"enrollments")===0,"ordinary login does not enroll existing member");
    const selection=["A","B","C","D","already","shared","opted","invalid","deleted","admin","covered","corrupt","race"].map(id).join(",");
    const reviewed=await preview(admin,selection);
    assert(reviewed.scanned===13&&reviewed.eligible===7&&reviewed.already===1&&reviewed.skipped===5&&reviewed.failures===0,
      "actual admin page previews mixed cohort with exact counts");
    const before=await command("inspect");
    assert(get(get(before,"counts"),"events")===get(get(initial,"counts"),"events"),"GET preview writes no enrollment or coverage evidence");
    assert(reviewed.rows.find(r=>r.id===id("corrupt")).text.includes("Unverified"),"corrupt coverage remains visibly unverified");
    assert(reviewed.rows.find(r=>r.id===id("covered")).text.includes("Verified"),"canonical coverage is shown separately");
    assert((await post(admin,reviewed,{adminCsrfToken:"wrong"})).status()===403,"CSRF failure blocks enrollment");
    assert((await (await post(admin,reviewed,{reviewToken:"f".repeat(64)})).text()).includes("REVIEW_TOKEN_INVALID"),"forged review token rejected");
    assert((await (await post(admin,reviewed,{confirmation:""})).text()).includes("CONFIRMATION_REQUIRED"),"explicit confirmation required");
    assert((await (await post(admin,reviewed,{userIds:String(id("concurrent"))})).text()).includes("unsupported action or field"),"posted member IDs cannot replace reviewed selection");
    await command("optOutCandidate",admin.p.request);
    await admin.p.locator("#recoveryEnrollmentConfirm").check();
    await Promise.all([admin.p.waitForNavigation({waitUntil:"domcontentloaded"}),admin.p.locator("#recoveryEnrollmentCommit").click()]);
    const committed=await report(admin.p);
    assert(committed.mode==="enroll"&&committed.newly===6&&committed.already===1&&committed.skipped===6&&committed.failures===0,
      "actual confirmed form enrolls only still-eligible reviewed members");
    assert(committed.rows.find(r=>r.id===id("race")).text.includes("SUPPRESSED_OPTED_OUT"),"eligibility changes after preview are rechecked");
    const after=await command("inspect");
    assert(get(memberState(after,id("already")),"enrollmentUtc")===get(memberState(before,id("already")),"enrollmentUtc"),"existing enrollment timestamp retained");
    assert(get(memberState(after,id("concurrent")),"enrollments")===0,"member outside reviewed selection remains unenrolled");
    assert(get(memberState(after,id("corrupt")),"decision")==="HOLD_INCOMPLETE_COVERAGE","enrollment does not clear corrupt coverage hold");
    assert(get(memberState(after,id("A")),"decision")==="HOLD_INCOMPLETE_COVERAGE","enrollment does not grant synthetic historical coverage");
    assert(get(memberState(after,id("covered")),"decision")==="ELIGIBLE","covered account is eligible only at separately observed 168-hour boundary");
    assert(get(get(after,"counts"),"ledger")===0&&get(get(after,"counts"),"attempted")===0,"cohort commit claims and sends no recovery messages");
    assert((await (await post(admin,reviewed)).text()).includes("REVIEW_REQUIRED"),"consumed review token cannot be replayed");
    const expired=await preview(admin,String(id("concurrent")));
    await command("expireReview",admin.p.request);
    assert((await (await post(admin,expired)).text()).includes("REVIEW_EXPIRED"),"expired review cannot enroll");
    for(const input of ["",String(id("concurrent"))+","+id("concurrent"),Array.from({length:101},(_,i)=>i+1).join(",")]) {
      const invalid=await preview(admin,input);
      assert(invalid.failures===1&&invalid.scanned===0,"empty duplicate or over-limit cohort rejected");
    }
    const overlapping=await Promise.all([command("concurrent"),command("concurrent")]);
    assert(overlapping.map(r=>get(r,"CODE")).sort().join(",")==="ALREADY_ENROLLED,ENROLLED","overlapping first enrollment inserts exactly once");
    assert(get(overlapping[0],"ENROLLMENT_UTC")===get(overlapping[1],"ENROLLMENT_UTC"),"concurrent calls return identical immutable UTC");
    assert(get(memberState(await command("inspect"),id("concurrent")),"enrollments")===1,"one durable concurrent enrollment event");
    const signup=await contextPage();
    const payload={firstName:"Enrollment",lastName:"Fixture",email,password:"Disposable-Enrollment-2026!",confirmPassword:"Disposable-Enrollment-2026!",termsAccepted:true};
    const failed=await signup.p.request.post(base+"/api/v1/join.cfc?method=handle",{data:{...payload,termsAccepted:false}});
    assert(get(await failed.json(),"SUCCESS")===false,"failed signup remains a failure");
    const failedState=await command("signupState");
    assert(get(failedState,"users")===0&&get(failedState,"enrollments")===0,"failed signup creates no account or enrollment");
    await signup.p.goto(base+"/app/join.cfm");
    for(const [name,value] of [["First Name","Enrollment"],["Last Name","Fixture"],["Email",email],["Password",payload.password],["Confirm Password",payload.password]])
      await signup.p.getByRole("textbox",{name,exact:true}).fill(value);
    await signup.p.getByRole("checkbox").check();
    await Promise.all([signup.p.waitForURL(/dashboard[.]cfm/,{timeout:20000}),signup.p.getByRole("button",{name:"Start Planning My Trip"}).click()]);
    const birth=await command("signupState");
    assert(get(birth,"users")===1&&get(birth,"enrollments")===1,"real successful signup automatically persists one enrollment");
    assert(Object.values(get(birth,"coverage")).every(x=>x===true),"real signup retains independently verified canonical coverage");
    assert(get(birth,"ledger")===0,"automatic signup enrollment creates no delivery claim");
    const duplicate=await signup.p.request.post(base+"/api/v1/join.cfc?method=handle",{data:payload});
    assert(get(await duplicate.json(),"SUCCESS")===false,"duplicate signup does not create a second account");
    const repeated=await command("signupState");
    assert(get(repeated,"users")===1&&get(repeated,"enrollments")===1&&get(repeated,"enrollmentUtc")===get(birth,"enrollmentUtc"),"duplicate signup cannot duplicate or reset enrollment");
    const final=await command("inspect");
    assert(get(get(final,"counts"),"ledger")===0&&get(get(final,"counts"),"attempted")===0,"all integration paths remain recovery-send-free");
    const unauthorizedDiagnostic=await ordinary.p.request.get(endpoint+"&action=corruptEnrollmentEvidence&runKey="+get(prepared,"runKey"));
    assert(unauthorizedDiagnostic.status()===500&&get(await unauthorizedDiagnostic.json(),"error")==="FIXTURE_ADMIN_REQUIRED",
      "diagnostic fixture mutation requires its run-owned admin session");
    const diagnosticSeed=await command("corruptEnrollmentEvidence",admin.p.request);
    const failedPreview=await preview(admin,String(id("covered")));
    const failureRow=failedPreview.rows.find(r=>r.id===id("covered"));
    assert(failedPreview.scanned===1&&failedPreview.failures===1&&failedPreview.eligible===0&&failureRow?.code==="ENROLLMENT_FAILED",
      "actual admin preview shows a fail-closed enrollment error row");
    assert(failureRow.reason==="ENROLLMENT_EVIDENCE_INVALID"&&
      /^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-(?:[a-f0-9]{16}|[a-f0-9]{4}-[a-f0-9]{12})$/.test(failureRow.errorReference),
      "failure row displays a safe specific reason and UUID diagnostic reference");
    assert(failureRow.coverage==="Verified"&&failureRow.enrollmentUtc==="",
      "coverage remains independently verified despite invalid enrollment evidence");
    assert(await admin.p.getByRole("columnheader",{name:"Diagnostic reference",exact:true}).isVisible()&&
      (await admin.p.locator("#recoveryEnrollmentReport").innerText()).includes("fpw_recovery_enrollment.log"),
      "diagnostic reference column and server-log lookup guidance are visible");
    assert(!failedPreview.token&&await admin.p.locator("#recoveryEnrollmentCommit").count()===0,
      "failed preview offers no review token or enrollment commit action");
    const diagnosticAfter=await command("diagnosticCounts",admin.p.request);
    assert(get(get(diagnosticAfter,"counts"),"events")===get(get(diagnosticSeed,"counts"),"events")&&
      get(get(diagnosticAfter,"counts"),"ledger")===0&&get(get(diagnosticAfter,"counts"),"attempted")===0,
      "failed preview writes no events and claims or sends no recovery messages");
  } catch(e) {error=e.message;}
  finally {
    if(prepared) {
      try {
        const email=get(prepared,"signupEmail");
        const r=await page.request.get("http://localhost:8025/api/v2/search?kind=to&query="+encodeURIComponent(email));
        const messages=(await r.json()).items||[];
        let removed=0;
        for(const mail of messages) {
          if(!(mail.To||[]).length||!(mail.To||[]).every(to=>(to.Mailbox+"@"+to.Domain).toLowerCase()===email))throw new Error("Mail cleanup recipient mismatch");
          const subject=(mail.Content?.Headers?.Subject||[]).join(" ");
          if(!/welcome/i.test(subject))throw new Error("Unexpected non-welcome email: "+subject);
          const result=await page.request.delete("http://localhost:8025/api/v1/messages/"+encodeURIComponent(mail.ID));
          if(!result.ok())throw new Error("Mail cleanup failed");removed++;
        }
        const verify=await page.request.get("http://localhost:8025/api/v2/search?kind=to&query="+encodeURIComponent(email));
        mailCleanup.push({removed,remaining:(await verify.json()).total});
      }catch(e){mailCleanup.push({error:e.message});}
      try{cleanup=await command("cleanup");}catch(e){cleanup={ok:false,error:e.message};}
    }
    for(const c of contexts)await c.close();
  }
  return {success:!error&&get(cleanup,"ok")===true&&mailCleanup.every(x=>x.remaining===0),
    error,assertions:reports.length,reports,cleanup,mailCleanup};
}
