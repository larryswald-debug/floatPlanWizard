async (page) => {
  const reports=[],accounts=[],contexts=[],cleanup=[],mailCleanup=[],mailEvidence=[];
  const base='http://localhost:8500/fpw',run=Date.now().toString(36);
  const get=(o,k)=>o?.[k]??o?.[k.toUpperCase()]??o?.[k.toLowerCase()];
  const assert=(ok,label)=>{if(!ok)throw new Error(label);reports.push(label);};
  let error='';
  async function command(a,action) {
    const token=get(a.auth,'token');
    const r=await a.p.request.post(base+'/tests/inactive-member-recovery-readiness-command.cfm?confirm=RUN_RECOVERY_READINESS_COMMAND&action='+action+'&runKey='+(get(a.auth,'runKey')||''),
      {headers:token?{'X-FPW-Readiness-Test-Token':token}:{}});
    if(r.status()!==200)throw new Error(action+' HTTP '+r.status()+': '+(await r.text()).slice(0,300));
    return r.json();
  }
  async function post(a,family,action,payload) {
    const r=await a.p.request.post(base+'/api/v1/'+family+'.cfc?method=handle'+(['routeBuilder','floatplan'].includes(family)?'&action='+action:''),{data:{...payload,action}});
    const raw=await r.text();let json;try{json=JSON.parse(raw);}catch{throw new Error(family+' '+action+' HTTP '+r.status()+': '+raw.slice(0,300));}
    assert(get(json,'SUCCESS')===true,a.stage+' canonical '+family+' '+action+': '+JSON.stringify(json));return json;
  }
  async function mails(a) {
    const r=await a.p.request.get('http://localhost:8025/api/v2/search?kind=to&query='+encodeURIComponent(a.email));
    return (await r.json()).items||[];
  }
  const decode=body=>String(body).replace(/=\r?\n/g,'').replace(/=([A-Fa-f0-9]{2})/g,(_,h)=>String.fromCharCode(parseInt(h,16)));
  function mimeParts(m) {return [m,...(m?.Parts||[]).flatMap(mimeParts)];}
  try {
    for(const stage of ['A','B','C','D']) {
      const context=await page.context().browser().newContext();contexts.push(context);
      const p=await context.newPage();const a={context,p,stage,email:'codex-activity-readiness-'+run+'-'+stage.toLowerCase()+'@example.test'};
      await p.goto(base+'/app/join.cfm');
      await p.getByRole('textbox',{name:'First Name',exact:true}).fill('Readiness');
      await p.getByRole('textbox',{name:'Last Name',exact:true}).fill('Fixture');
      await p.getByRole('textbox',{name:'Email',exact:true}).fill(a.email);
      await p.getByRole('textbox',{name:'Password',exact:true}).fill('Disposable-Readiness-2026!');
      await p.getByRole('textbox',{name:'Confirm Password',exact:true}).fill('Disposable-Readiness-2026!');
      await p.getByRole('checkbox').check();
      await p.getByRole('button',{name:'Start Planning My Trip'}).click();
      await p.waitForURL(/dashboard[.]cfm/,{timeout:15000});accounts.push(a);
      a.auth=await command(a,'prepare');
      const birth=await command(a,'state');
      assert(Object.values(get(birth,'coverage')).every(x=>x===true),stage+' real signup has independently verified v1 coverage');
      assert(get(birth,'enrollment')==='',stage+' signup did not enroll');
      if(stage==='B')await post(a,'vessel','save',{vessel:{VESSELNAME:'Readiness Vessel',TYPE:'Power',LENGTH:'24',COLOR:'White'}});
      if(stage==='C')await post(a,'routeBuilder','createUserRoute',{route_name:'Readiness named route without legs'});
      if(stage==='D')await post(a,'floatplan','savebasic',{FLOATPLAN:{NAME:'Readiness Draft'},BASIC_DETAILS:{VESSEL_NAME:'Basic vessel',OPERATOR_NAME:'Basic operator',CAPTAIN_NAME:'Captain',CAPTAIN_EMAIL:a.email,NOTIFICATION_CONTACT_NAME:'Basic contact',NOTIFICATION_CONTACT_EMAIL:a.email,NOTIFICATION_CONTACT_PHONE:'555-0100',LAUNCH_LOCATION:'Test launch',DESTINATION_LOCATION:'Test end',AUTHORITY_ID:-1},PASSENGERS:[],WAYPOINTS:[]});
      assert(get(await command(a,'state'),'stage')===stage,stage+' verified from canonical saved state');
      assert(get(await command(a,'enroll'),'CODE')==='ENROLLED',stage+' explicitly enrolled separately');
      const before=(await mails(a)).map(m=>m.ID);
      const early=await command(a,'earlyDry');assert(get(early,'eligible')===0&&get(early,'claimed')===0,stage+' not eligible at 167h59m59s');
      const dry=await command(a,'dueDry');assert(get(dry,'eligible')===1&&get(dry,'sent')===0&&get(dry,'claimed')===0,stage+' eligible at exactly 168h dry run without claim or send');
      assert((await mails(a)).length===before.length,stage+' dry runs produced no mail');
      const sent=await command(a,'dueSend');
      assert(get(sent,'sent')===1&&get(sent,'submitted')===1&&get(sent,'claimed')===1,stage+' real orchestration and multipart transport submitted once to local MailHog: '+JSON.stringify(sent));
      const state=await command(a,'state');assert(get(state,'ledger_count')===1&&get(state,'ledger_status')==='SENT',stage+' durable SENT ledger');
      const replay=await command(a,'dueSend');assert(get(replay,'sent')===0&&get(replay,'claimed')===0,stage+' repeat invocation suppressed');
      const captured=(await mails(a)).filter(m=>!before.includes(m.ID));
      assert(captured.length===1,stage+' exactly one captured recovery message');
      const m=captured[0];
      assert((m.To||[]).length===1&&(m.To[0].Mailbox+'@'+m.To[0].Domain).toLowerCase()===a.email,stage+' only this disposable recipient');
      const full=await (await p.request.get('http://localhost:8025/api/v1/messages/'+encodeURIComponent(m.ID))).json();
      const parts=mimeParts(full.MIME||{});
      const html=parts.find(x=>/text\/html/i.test((x.Headers?.['Content-Type']||[]).join(' ')));
      const plain=parts.find(x=>/text\/plain/i.test((x.Headers?.['Content-Type']||[]).join(' ')));
      assert(!!html&&!!plain,stage+' real message has HTML and plain-text MIME parts');
      const htmlBody=decode(html.Body),textBody=decode(plain.Body);
      for(const content of [htmlBody,textBody]) {
        assert(content.includes('4347 Topsail Trail')&&content.includes('New Port Richey, FL 34652'),stage+' approved mailing address in MIME part');
        assert(/unsubscribe/i.test(content)&&/preferences/i.test(content),stage+' unsubscribe and preferences in MIME part');
      }
      const links=[...htmlBody.matchAll(/href="([^"]+)"/g)].map(x=>x[1].replace(/&amp;/g,'&'));
      const unsub=links.find(x=>/unsubscribe/i.test(x));const preferences=links.find(x=>/preferences/i.test(x));
      assert(!!unsub&&!!preferences&&unsub!==preferences,stage+' distinct unsubscribe and preferences destinations');
      mailEvidence.push({stage,subject:full.Content?.Headers?.Subject?.[0]||m.Content?.Headers?.Subject?.[0],multipart:true,address:true,distinctLinks:true});
    }
  } catch(e){error=e.message;}
  finally {
    for(const a of accounts) {
      try {
        const messages=await mails(a);let removed=0;
        for(const m of messages) {
          if(!(m.To||[]).every(to=>(to.Mailbox+'@'+to.Domain).toLowerCase()===a.email))throw new Error('Mail cleanup recipient mismatch');
          if(!(await a.p.request.delete('http://localhost:8025/api/v1/messages/'+encodeURIComponent(m.ID))).ok())throw new Error('Mail cleanup failed');removed++;
        }
        mailCleanup.push({stage:a.stage,removed,remaining:(await mails(a)).length});
      }catch(e){mailCleanup.push({stage:a.stage,error:e.message});}
      try{cleanup.push({stage:a.stage,...await command(a,'cleanup')});}catch(e){cleanup.push({stage:a.stage,ok:false,error:e.message});}
    }
    for(const c of contexts)await c.close();
  }
  return {success:!error&&accounts.length===4&&cleanup.every(x=>get(x,'ok'))&&mailCleanup.every(x=>x.remaining===0),
    error,assertions:reports.length,reports,mailEvidence,cleanup,mailCleanup};
}
