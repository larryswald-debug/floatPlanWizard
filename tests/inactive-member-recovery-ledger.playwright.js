async (page) => {
  const browser=page.context().browser();
  const context=await browser.newContext();
  const p=await context.newPage();
  const run=Date.now().toString(36);
  const email='codex-activity-ledger-'+run+'@example.test';
  const password='Disposable-Ledger-2026!';
  const reports=[];
  const assert=(ok,label)=>{if(!ok)throw new Error(label);reports.push(label);};
  const get=(o,k)=>o?.[k]??o?.[k.toUpperCase()]??o?.[k.toLowerCase()];
  const post=async(action,data={})=>{
    const response=await p.request.post('http://localhost:8500/fpw/tests/inactive-member-recovery-ledger-command.cfm?confirm=RUN_INACTIVE_RECOVERY_LEDGER_TESTS',{data:{action,...data}});
    const text=await response.text();
    try{return JSON.parse(text);}catch{throw new Error(action+' returned '+response.status()+': '+text.slice(0,200));}
  };
  let cleanup={SUCCESS:false},error='';
  try {
    await p.goto('http://localhost:8500/fpw/app/join.cfm');
    await p.getByRole('textbox',{name:'First Name',exact:true}).fill('Ledger');
    await p.getByRole('textbox',{name:'Last Name',exact:true}).fill('Fixture');
    await p.getByRole('textbox',{name:'Email',exact:true}).fill(email);
    await p.getByRole('textbox',{name:'Password',exact:true}).fill(password);
    await p.getByRole('textbox',{name:'Confirm Password',exact:true}).fill(password);
    await p.getByRole('checkbox').check();
    await p.getByRole('button',{name:'Start Planning My Trip'}).click();
    await p.waitForURL(/dashboard[.]cfm/,{timeout:15000});

    const invalid=await post('claim',{stage:'Z'});
    assert(get(invalid,'CODE')==='INVALID_STAGE','invalid stage rejected');

    const [first,second]=await Promise.all([post('claim',{stage:'A'}),post('claim',{stage:'A'})]);
    const pair=[get(first,'CODE'),get(second,'CODE')].sort();
    assert(JSON.stringify(pair)===JSON.stringify(['ALREADY_CLAIMED','CLAIMED']),'concurrent claim has one winner');
    const aClaim=get(first,'CODE')==='CLAIMED'?first:second;
    assert(get(await post('count',{stage:'A'}),'COUNT')===1,'one Stage A row after concurrent claims');
    assert(get(aClaim,'ATTEMPT_COUNT')===1,'new claim attempt count');
    assert(get(await post('sent',{stage:'A',claim_token:'0'.repeat(64)}),'CODE')==='CLAIM_MISMATCH','wrong claim token rejected');
    const aSent=await post('sent',{stage:'A',claim_token:get(aClaim,'CLAIM_TOKEN')});
    assert(get(aSent,'CODE')==='SENT'&&get(aSent,'STATUS')==='SENT','Stage A transitions to SENT');
    assert(/Z$/.test(get(aSent,'SENT_AT_UTC')),'sent timestamp is UTC text');
    assert(get(await post('claim',{stage:'A'}),'CODE')==='ALREADY_SENT','same-stage SENT suppresses claim');
    assert(get(await post('failed',{stage:'A',claim_token:get(aClaim,'CLAIM_TOKEN'),error_code:'SMTP_FAILED'}),'CODE')==='ALREADY_SENT','SENT cannot be downgraded');

    const b=await post('claim',{stage:'B'});
    assert(get(b,'CODE')==='CLAIMED','higher Stage B independently claimed');
    const bFailed=await post('failed',{stage:'B',claim_token:get(b,'CLAIM_TOKEN'),error_code:'private-person@example.test'});
    assert(get(bFailed,'CODE')==='FAILED','Stage B records definite failure');
    assert(get(bFailed,'LAST_ERROR_CODE')==='RECOVERY_SEND_FAILED','private error replaced with generic code');
    const bNormal=await post('claim',{stage:'B'});
    assert(get(bNormal,'CODE')==='FAILED_PREVIOUSLY'&&get(bNormal,'CAN_RETRY')===true,'normal claim does not replay failure');
    const bRetry2=await post('retry',{stage:'B'});
    assert(get(bRetry2,'CODE')==='FAILED_RETRY'&&get(bRetry2,'ATTEMPT_COUNT')===2,'explicit retry increments to two');
    await post('failed',{stage:'B',claim_token:get(bRetry2,'CLAIM_TOKEN'),error_code:'SMTP_TIMEOUT'});
    const bRetry3=await post('retry',{stage:'B'});
    assert(get(bRetry3,'ATTEMPT_COUNT')===3,'explicit retry increments to three');
    await post('failed',{stage:'B',claim_token:get(bRetry3,'CLAIM_TOKEN'),error_code:'SMTP_TIMEOUT'});
    assert(get(await post('retry',{stage:'B'}),'CODE')==='RETRY_EXHAUSTED','three-attempt cap enforced');

    const c=await post('claim',{stage:'C'});
    await post('failed',{stage:'C',claim_token:get(c,'CLAIM_TOKEN'),error_code:'SMTP_REJECTED'});
    const cRetry=await post('retry',{stage:'C'});
    const cSent=await post('sent',{stage:'C',claim_token:get(cRetry,'CLAIM_TOKEN')});
    assert(get(cSent,'STATUS')==='SENT'&&get(cSent,'ATTEMPT_COUNT')===2,'successful explicit retry becomes SENT');

    const d=await post('claim',{stage:'D'});
    assert(get(d,'CODE')==='CLAIMED','Stage D claim created');
    assert(get(await post('claim',{stage:'D'}),'CODE')==='ALREADY_CLAIMED','unresolved potentially-sent claim is non-replayable');

    const latest=await post('last');
    const aState=await post('state',{stage:'A'}),cState=await post('state',{stage:'C'}),dState=await post('state',{stage:'D'});
    const expected=[get(aState,'SENT_AT_UTC'),get(cState,'SENT_AT_UTC')].sort().at(-1);
    assert(get(latest,'HAS_SENT')===true&&get(latest,'LAST_SENT_AT_UTC')===expected,'cross-stage latest SENT timestamp');
    assert(!('CLAIM_TOKEN' in dState)&&!JSON.stringify(dState).includes(email),'diagnostic state excludes token and PII');
    assert(get(dState,'STATUS')==='CLAIMED'&&get(dState,'ATTEMPT_COUNT')===1,'unresolved state observable');
  } catch(e) {error=e.message;}
  finally {
    try {cleanup=await post('cleanup');} catch(e){cleanup={SUCCESS:false,ERROR:e.message};}
    await context.close();
  }
  return {SUCCESS:!error&&cleanup.SUCCESS&&cleanup.LEDGER_ROWS_AFTER===0&&cleanup.DELETED_MEMBER_CLAIM_CODE==='MEMBER_NOT_FOUND',ERROR:error,REPORTS:reports,EMAIL:email,CLEANUP:cleanup};
}
