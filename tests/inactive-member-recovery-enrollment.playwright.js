async (page) => {
  const reports=[], contexts=[], accounts=[], cleanup=[], mailCleanup=[];
  const assert=(ok,label)=>{if(!ok)throw new Error(label);reports.push(label);};
  const get=(o,k)=>o?.[k]??o?.[k.toUpperCase()]??o?.[k.toLowerCase()];
  const base='http://localhost:8500/fpw';
  let error='';
  async function signup(suffix) {
    const context=await page.context().browser().newContext();contexts.push(context);
    const p=await context.newPage();
    const a={p,context,email:'codex-activity-enrollment-'+Date.now().toString(36)+'-'+suffix+'@example.test'};
    await p.goto(base+'/app/join.cfm');
    await p.getByRole('textbox',{name:'First Name',exact:true}).fill('Enrollment');
    await p.getByRole('textbox',{name:'Last Name',exact:true}).fill('Fixture');
    await p.getByRole('textbox',{name:'Email',exact:true}).fill(a.email);
    await p.getByRole('textbox',{name:'Password',exact:true}).fill('Disposable-Enrollment-2026!');
    await p.getByRole('textbox',{name:'Confirm Password',exact:true}).fill('Disposable-Enrollment-2026!');
    await p.getByRole('checkbox').check();
    await p.getByRole('button',{name:'Start Planning My Trip'}).click();
    await p.waitForURL(/dashboard[.]cfm/,{timeout:15000});
    accounts.push(a);
    a.auth=await command(a,'prepare');
    return a;
  }
  async function raw(a,action,auth=a.auth,request=a.p.request,token=get(auth,'token')) {
    return request.post(base+'/tests/inactive-member-recovery-enrollment-command.cfm?confirm=RUN_RECOVERY_ENROLLMENT_COMMAND&action='+action+'&runKey='+(get(auth,'runKey')||''),
      {headers:token?{'X-FPW-Enrollment-Test-Token':token}:{}});
  }
  async function command(a,action,auth=a.auth,request=a.p.request) {
    const r=await raw(a,action,auth,request);
    if(r.status()!==200)throw new Error(action+' HTTP '+r.status()+': '+(await r.text()).slice(0,250));
    return r.json();
  }
  try {
    const a=await signup('owner'), b=await signup('other');
    assert(get(await command(a,'state'),'enrollments')===0,'signup and dashboard do not enroll');
    assert(get(await command(a,'preview'),'enrollable')===1,'authenticated preview reports enrollable');
    const beforeDry=await command(a,'dryRun');
    assert(get(get(beforeDry,'reasons'),'ENROLLMENT_EVIDENCE_REQUIRED')===1,'authenticated sender dry run holds unenrolled member');
    assert(get(await command(a,'state'),'enrollments')===0,'preview is read-only');
    assert((await raw(a,'preview',a.auth,a.p.request,'wrong')).status()===403,'wrong token denied');
    assert((await raw(b,'enroll',a.auth)).status()===403,'cross-member fixture denied');
    const second=await page.context().browser().newContext({storageState:await a.context.storageState()});
    contexts.push(second);
    const results=await Promise.all([command(a,'enrollConcurrent'),command(a,'enrollConcurrent',a.auth,second.request)]);
    assert(results.every(r=>get(r,'SUCCESS')===true),'both overlapping enrollment calls succeed');
    assert(results.map(r=>get(r,'CODE')).sort().join(',')==='ALREADY_ENROLLED,ENROLLED','one insertion and one existing enrollment');
    const at=get(results[0],'ENROLLMENT_UTC');
    assert(at===get(results[1],'ENROLLMENT_UTC'),'concurrent calls return identical UTC');
    const state=await command(a,'state');
    assert(get(state,'enrollments')===1,'one canonical event persisted');
    assert(get(state,'ledger')===0,'no recovery ledger claim');
    assert(get(state,'decision')==='DEFERRED_WAITING_FOR_INTERVAL','versioned canonical signup has coverage but must wait the enrollment interval');
    assert(get(await command(a,'preview'),'already_enrolled')===1,'authenticated preview reports already enrolled');
    const heldDry=await command(a,'dryRun');
    assert(get(get(heldDry,'reasons'),'DEFERRED_WAITING_FOR_INTERVAL')===1,'default sender reads separate coverage and enrollment and defers');
    assert(get(heldDry,'claimed')===0&&get(heldDry,'sent')===0,'authenticated sender dry run does not claim or send');
    assert(!/"(?:user_?id|email|name|token|recipient)"\s*:/i.test(JSON.stringify(heldDry)),'sender aggregate output excludes identities');
    const save=await a.p.request.post(base+'/api/v1/vessel.cfc?method=handle',{data:{action:'save',vessel:{VESSELNAME:'Enrollment fixture vessel',TYPE:'Power',LENGTH:'24',COLOR:'White'}}});
    assert(get(await save.json(),'SUCCESS')===true,'canonical vessel save succeeds');
    const after=await command(a,'state');
    assert(get(after,'stage')==='B','real stage advancement recognized');
    assert(get(after,'enrollment_utc')===at,'real stage advancement does not reset enrollment');
    assert(get(after,'decision')==='SUPPRESSED_RECENT_ACTIVITY','stage advancement resets inactivity while retaining signup coverage');
    assert(get(await command(a,'enroll'),'ENROLLMENT_UTC')===at,'repeated explicit enrollment retains initial time');
    assert(get(await command(b,'state'),'enrollments')===0,'other account remains unenrolled');
  } catch(e) {error=e.message;}
  finally {
    for(const a of accounts) {
      try {cleanup.push(await command(a,'cleanup'));} catch(e) {cleanup.push({ok:false,error:e.message});}
      try {
        const mail=await a.p.request.get('http://localhost:8025/api/v2/search?kind=to&query='+encodeURIComponent(a.email));
        const messages=(await mail.json()).items||[];
        let removed=0;
        for(const m of messages) {
          if(!(m.To||[]).some(to=>(to.Mailbox+'@'+to.Domain).toLowerCase()===a.email))throw new Error('Mail recipient mismatch');
          const result=await a.p.request.delete('http://localhost:8025/api/v1/messages/'+encodeURIComponent(m.ID));
          if(!result.ok())throw new Error('Mail cleanup failed'); removed++;
        }
        const check=await a.p.request.get('http://localhost:8025/api/v2/search?kind=to&query='+encodeURIComponent(a.email));
        mailCleanup.push({removed,remaining:(await check.json()).total});
      } catch(e) {mailCleanup.push({error:e.message});}
    }
    for(const c of contexts)await c.close();
  }
  return {success:!error&&cleanup.every(c=>get(c,'ok'))&&mailCleanup.every(m=>m.remaining===0),
    error,assertions:reports.length,reports,cleanup,mailCleanup};
}
