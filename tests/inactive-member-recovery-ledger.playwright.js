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

    const invalid=await post('claim',{stage:'Z',contactNumber:1});
    assert(get(invalid,'CODE')==='INVALID_DESTINATION_STAGE','invalid destination rejected');
    assert(get(await post('claim',{stage:'A',contactNumber:4}),'CODE')==='INVALID_CONTACT_NUMBER','contact four rejected');
    assert(get(await post('claim',{stage:'A',contactNumber:2}),'CODE')==='CONTACT_SEQUENCE_CONFLICT','contact cannot be skipped');

    const [first,second]=await Promise.all([post('claim',{stage:'A',contactNumber:1}),post('claim',{stage:'A',contactNumber:1})]);
    const pair=[get(first,'CODE'),get(second,'CODE')].sort();
    assert(JSON.stringify(pair)===JSON.stringify(['ALREADY_CLAIMED','CLAIMED']),'concurrent contact claim has one winner');
    const aClaim=get(first,'CODE')==='CLAIMED'?first:second;
    assert(get(await post('count',{contactNumber:1}),'COUNT')===1,'one contact one row');
    assert(get(await post('sent',{contactNumber:1,claim_token:'0'.repeat(64)}),'CODE')==='CLAIM_MISMATCH','wrong claim token rejected');
    const aSent=await post('sent',{contactNumber:1,claim_token:get(aClaim,'CLAIM_TOKEN')});
    assert(get(aSent,'STATUS')==='SENT','contact one accepted');
    assert(get(await post('claim',{stage:'B',contactNumber:1}),'CODE')==='ALREADY_SENT','destination change does not replay accepted contact');
    assert(get(await post('failed',{contactNumber:1,claim_token:get(aClaim,'CLAIM_TOKEN'),error_code:'SMTP_FAILED'}),'CODE')==='ALREADY_SENT','SENT cannot be downgraded');

    const b=await post('claim',{stage:'A',contactNumber:2});
    assert(get(b,'CODE')==='CLAIMED','contact two may retain destination A');
    const bFailed=await post('failed',{contactNumber:2,claim_token:get(b,'CLAIM_TOKEN'),error_code:'private-person@example.test'});
    assert(get(bFailed,'LAST_ERROR_CODE')==='RECOVERY_SEND_FAILED','private error replaced with generic code');
    assert(get(await post('claim',{stage:'A',contactNumber:2}),'CODE')==='FAILED_PREVIOUSLY','normal claim does not replay failure');
    assert(get(await post('claim',{stage:'B',contactNumber:3}),'CODE')==='CONTACT_SEQUENCE_CONFLICT','failed contact cannot be skipped');
    const bRetry=await post('retry',{stage:'B',contactNumber:2});
    assert(get(bRetry,'ATTEMPT_COUNT')===2&&get(bRetry,'DESTINATION_STAGE')==='B','retry preserves contact and refreshes destination');
    const bSent=await post('sent',{contactNumber:2,claim_token:get(bRetry,'CLAIM_TOKEN')});
    assert(get(bSent,'STATUS')==='SENT','successful retry accepts contact two');

    let c=await post('claim',{stage:'C',contactNumber:3});
    assert(get(await post('claim',{stage:'D',contactNumber:3}),'CODE')==='ALREADY_CLAIMED','uncertain contact is not replayable');
    const cState=await post('state',{contactNumber:3});
    assert(!('CLAIM_TOKEN' in cState)&&!JSON.stringify(cState).includes(email),'diagnostics exclude token and PII');
    for(let attempt=1;attempt<=3;attempt++){
      await post('failed',{contactNumber:3,claim_token:get(c,'CLAIM_TOKEN'),error_code:'SMTP_REJECTED'});
      if(attempt<3)c=await post('retry',{stage:'C',contactNumber:3});
    }
    assert(get(await post('retry',{stage:'C',contactNumber:3}),'CODE')==='RETRY_EXHAUSTED','three transport attempt cap is separate from contact number');
    const latest=await post('last');
    assert(get(latest,'LAST_SENT_AT_UTC')===get(bSent,'SENT_AT_UTC'),'latest acceptance is contact two regardless of destination');
  } catch(e) {error=e.message;}
  finally {
    try {cleanup=await post('cleanup');} catch(e){cleanup={SUCCESS:false,ERROR:e.message};}
    await context.close();
  }
  return {SUCCESS:!error&&cleanup.SUCCESS&&cleanup.LEDGER_ROWS_AFTER===0&&cleanup.DELETED_MEMBER_CLAIM_CODE==='MEMBER_NOT_FOUND',ERROR:error,REPORTS:reports,EMAIL:email,CLEANUP:cleanup};
}
