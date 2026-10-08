async (page) => {
  const base="http://localhost:8500/fpw";
  const fixtureUrl=base+"/tests/email-auth-continuation-fixture.cfm?confirm=RUN_EMAIL_AUTH_FIXTURES";
  const runId=Date.now().toString(16).padStart(16,"0")+Math.floor(Math.random()*Number.MAX_SAFE_INTEGER).toString(16).padStart(16,"0");
  const browser=page.context().browser();
  const fixtureContext=await browser.newContext();
  const results=[];
  let members,cleanupVerified=false;
  const field=(o,k)=>o[k]===undefined ? o[k.toUpperCase()] : o[k];
  function check(value,message) { if (!value) throw new Error(message); }
  async function runCase(name,fn) {
    const context=await browser.newContext();
    const p=await context.newPage();
    try { results.push({name,passed:true,...await fn(p)}); }
    catch(error) { results.push({name,passed:false,error:error.message,url:p.url()}); }
    finally { await context.close(); }
  }
  async function login(p,path,member) {
    await p.goto(base+path);
    check(/\/app\/login\.cfm\?authIntent=[a-f0-9]{64}(?:#email-preferences)?$/.test(p.url()),"Anonymous destination did not preserve an opaque Login continuation");
    const token=new URL(p.url()).searchParams.get("authIntent");
    check(await p.locator("#loginForm").getAttribute("data-auth-intent")===token,"Login form lost intent");
    await p.locator("#email").fill(field(member,"email"));
    await p.locator("#password").fill(field(member,"password"));
    const response=p.waitForResponse(r=>r.url().includes("/auth.cfc?method=handle")&&r.request().method()==="POST");
    await p.locator("#loginButton").click();
    const auth=await (await response).json();
    check(auth.SUCCESS===true&&auth.AUTH===true,"Real login failed: "+(auth.ERROR||auth.MESSAGE||"unknown"));
    check(auth.REDIRECT_URL==="/fpw/app/dashboard.cfm?authIntent="+token,"Opaque Dashboard handoff changed");
    await p.waitForURL(base+path,{timeout:20000});
    return {anonymousStart:path,login:"/fpw/app/login.cfm?authIntent=[redacted]",handoff:"/fpw/app/dashboard.cfm?authIntent=[redacted]",final:new URL(p.url()).pathname+new URL(p.url()).search+new URL(p.url()).hash};
  }
  try {
    const setup=await fixtureContext.request.post(fixtureUrl,{data:{action:"setup",runId}});
    const body=await setup.text();
    check(setup.status()===200,"Fixture setup failed "+setup.status()+": "+body.slice(0,500));
    const data=JSON.parse(body);check(data.SUCCESS===true,"Fixture setup rejected");
    members=data.MEMBERS;
    for(const target of ["active","completed"]) {
      await runCase("correct owner "+target,async p=>{
        const member=field(members,target);
        const path=target==="active" ? "/app/active-cruise.cfm?floatPlanId="+field(member,"planId") : "/app/completed-trip.cfm?id="+field(member,"planId");
        const flow=await login(p,path,member);
        const response=await p.request.get(base+path);
        check(response.status()===200,"Owner target response "+response.status());
        check((await response.text()).includes(field(member,"marker")),"Owned trip was not rendered");
        return {...flow,status:response.status()};
      });
    }
    await runCase("account preferences fragment",async p=>{
      const path="/app/account.cfm?section=email-preferences#email-preferences";
      const flow=await login(p,path,field(members,"active"));
      check(await p.locator("#email-preferences").isVisible(),"Preferences target is not visible");
      return flow;
    });
    for(const target of ["active","completed"]) {
      await runCase("wrong owner "+target,async p=>{
        const member=field(members,target),other=field(members,target==="active"?"completed":"active");
        const path=target==="active" ? "/app/active-cruise.cfm?floatPlanId="+field(member,"planId") : "/app/completed-trip.cfm?id="+field(member,"planId");
        const flow=await login(p,path,other);
        const response=await p.request.get(base+path);
        const deniedBody=await response.text();
        const expectedStatus=target==="active" ? 200 : 404;
        check(response.status()===expectedStatus,"Wrong-owner response changed: "+response.status());
        check(!deniedBody.includes(field(member,"marker")),"Wrong owner saw trip fixture data");
        if(target==="active") {
          check(await p.getByRole("heading",{name:"This trip is not available in Active Cruise.",exact:true}).isVisible(),"Active Cruise ownership denial is missing");
          check(await p.locator("#fpwActiveCruiseV2MapPayload").count()===0,"Denied Active Cruise rendered operational map data");
          check(deniedBody.includes("Only the authenticated trip owner can view this trip."),"Owner-only denial is missing");
        }
        return {...flow,status:response.status(),denied:true,tripDataVisible:false};
      });
    }
    await runCase("malformed and injected destinations rejected",async p=>{
      const cases=[];
      for(const path of ["/app/active-cruise.cfm?floatPlanId=01","/app/active-cruise.cfm?floatPlanId=1&returnUrl=https://evil.example","/app/completed-trip.cfm?id=2147483648","/app/account.cfm?section=other"]) {
        const response=await p.request.get(base+path,{maxRedirects:0});
        const location=response.headers().location||"";
        check(response.status()===302&&location.includes("/index.cfm?notice=member-required")&&!location.includes("authIntent"),"Rejected target was preserved: "+path);
        cases.push({path,status:response.status()});
      }
      return {cases};
    });
  } finally {
    if(members) {
      const response=await fixtureContext.request.post(fixtureUrl,{data:{action:"cleanup",runId}});
      const cleanup=await response.json();
      cleanupVerified=response.status()===200&&cleanup.SUCCESS===true&&cleanup.CLEANED===true&&cleanup.REMAINING_USERS===0;
      results.push({name:"disposable cleanup",passed:cleanupVerified,...cleanup});
    }
    await fixtureContext.close();
  }
  return {ok:cleanupVerified&&results.every(item=>item.passed),results,cleanupVerified};
}
