async (page) => {
  const base='http://localhost:8500/fpw',run=Date.now().toString(36),accounts=[],contexts=[],cases=[],cleanup=[],reports=[];
  const get=(o,k)=>o?.[k]??o?.[k.toUpperCase()]??o?.[k.toLowerCase()];
  const check=(ok,label)=>{if(!ok)throw new Error(label);reports.push(label);};
  let error='';
  async function post(a,family,action,payload={}) {
    const r=await a.p.request.post(base+'/api/v1/'+family+'.cfc?method=handle'+(['routeBuilder','floatplan'].includes(family)?'&action='+action:''),{data:{...payload,action}});
    let body;try{body=await r.json();}catch{throw new Error(family+'/'+action+' non-JSON '+r.status());}
    if(get(body,'SUCCESS')!==true)throw new Error(a.label+' canonical '+family+'/'+action+': '+JSON.stringify(body));
    reports.push(a.label+' canonical '+family+'/'+action);return body;
  }
  async function command(a,action,extra={}) {
    const prepare=action==='prepare',path=prepare?'inactive-member-recovery-readiness-command.cfm':'recovery-share-path-command.cfm';
    const params=Object.entries({confirm:prepare?'RUN_RECOVERY_READINESS_COMMAND':'RUN_RECOVERY_SHARE_PATHS',action,runKey:get(a.auth,'runKey')||'',...extra}).map(([k,v])=>encodeURIComponent(k)+'='+encodeURIComponent(v)).join('&');
    const r=await a.p.request.post(base+'/tests/'+path+'?'+params,{headers:get(a.auth,'token')?{'X-FPW-Readiness-Test-Token':get(a.auth,'token')}:{}});
    if(r.status()!==200)throw new Error(a.label+' '+action+' HTTP '+r.status()+': '+(await r.text()).slice(0,450));
    return r.json();
  }
  async function mails(a){return (await (await a.p.request.get('http://localhost:8025/api/v2/search?kind=to&query='+encodeURIComponent(a.email))).json()).items||[];}
  async function capturedShares(a) {
    const items=await mails(a);
    const ids=await a.p.evaluate(({messages,name})=>messages.filter(m=>{
      const subject=m.subject.replace(/(\?=)\s+(=\?)/g,'$1$2').replace(/=\?[^?]+\?B\?([^?]+)\?=/gi,(_,s)=>atob(s))
        .replace(/=\?[^?]+\?Q\?([^?]+)\?=/gi,(_,s)=>s.replace(/_/g,' ').replace(/=([0-9A-F]{2})/gi,(_,h)=>String.fromCharCode(parseInt(h,16))));
      return subject.includes(name);
    }).map(m=>m.id),{name:a.name,messages:items.map(m=>({id:m.ID,subject:(m.Content?.Headers?.Subject||[]).join(' ')}))});
    return items.filter(m=>ids.includes(m.ID));
  }
  async function setup(source,mode) {
    const label=source+'/'+mode,context=await page.context().browser().newContext();contexts.push(context);
    const a={label,source,mode,context,p:await context.newPage(),email:'codex-activity-readiness-share-'+run+'-'+accounts.length+'@example.test',name:'SharePath-'+run+'-'+accounts.length};
    await a.p.goto(base+'/app/join.cfm');
    for(const [name,value] of [['First Name','Share'],['Last Name','Fixture'],['Email',a.email],['Password','Disposable-Share-2026!'],['Confirm Password','Disposable-Share-2026!']])await a.p.getByRole('textbox',{name,exact:true}).fill(value);
    await a.p.getByRole('checkbox').check();await a.p.getByRole('button',{name:'Start Planning My Trip'}).click();
    await a.p.waitForURL(/dashboard[.]cfm/,{timeout:15000});accounts.push(a);a.auth=await command(a,'prepare');
    const dep=new Date(Date.now()+36*3600000).toISOString().replace(/\.\d{3}Z$/,'Z'),ret=new Date(Date.now()+40*3600000).toISOString().replace(/\.\d{3}Z$/,'Z');
    const times={DEPARTURE_TIME:dep.slice(0,19),DEPARTURE_TIMEZONE:'UTC',DEPARTURE_TIME_UTC:dep,RETURN_TIME:ret.slice(0,19),RETURN_TIMEZONE:'UTC',RETURN_TIME_UTC:ret};
    if(source==='basic_save_send') {
      const r=await post(a,'floatplan','savebasic',{FLOATPLAN:{NAME:a.name,...times},BASIC_DETAILS:{VESSEL_NAME:'Fixture vessel',OPERATOR_NAME:'Fixture operator',CAPTAIN_NAME:'Fixture captain',CAPTAIN_EMAIL:a.email,NOTIFICATION_CONTACT_NAME:'Fixture contact',NOTIFICATION_CONTACT_EMAIL:a.email,NOTIFICATION_CONTACT_PHONE:'555-0100',LAUNCH_LOCATION:'Fixture launch',DESTINATION_LOCATION:'Fixture end',AUTHORITY_ID:-1},PASSENGERS:[],WAYPOINTS:[]});
      a.pid=get(r,'FLOATPLANID');
    } else {
      const vessel=get(await post(a,'vessel','save',{vessel:{VESSELNAME:'Fixture Vessel',TYPE:'Power',LENGTH:'24',COLOR:'White',MAX_SPEED:'10',FUEL_CAPACITY:'80'}}),'VESSELID');
      const contact=get(await post(a,'contact','save',{contact:{CONTACTNAME:'Fixture Contact',PHONE:'555-0100',EMAIL:a.email}}),'CONTACTID');
      const operator=get(await post(a,'operator','save',{operator:{OPERATORNAME:'Fixture Operator',PHONE:'555-0101'}}),'OPERATORID');
      const start=get(await post(a,'waypoint','save',{waypoint:{WAYPOINTNAME:'Fixture Start',LATITUDE:'27.95',LONGITUDE:'-82.46'}}),'WAYPOINTID');
      const end=get(await post(a,'waypoint','save',{waypoint:{WAYPOINTNAME:'Fixture End',LATITUDE:'27.96',LONGITUDE:'-82.45'}}),'WAYPOINTID');
      const route=get(get(await post(a,'routeBuilder','createUserRoute',{route_name:a.name}),'DATA'),'route_id');
      await post(a,'routeBuilder','setUserRouteStartWaypoint',{route_id:route,start_waypoint_id:start});
      const legs=get(get(await post(a,'routeBuilder','addWaypointLegToUserRoute',{route_id:route,end_waypoint_id:end}),'DATA'),'legs');
      await post(a,'routeBuilder','saveRouteLegOverrideGeometry',{route_id:route,route_leg_id:get(legs[0],'route_leg_id'),points:[{lat:27.95,lon:-82.46},{lat:27.955,lon:-82.454},{lat:27.96,lon:-82.45}]});
      const generated=await post(a,'routeBuilder','routegen_generate',{route_type:'my_route',route_id:route,route_name:a.name,selected_vessel_id:vessel,speed_kn:10,cruising_speed:10,underway_hours_per_day:6.5,start_date:dep.slice(0,10)});
      a.routeCode=get(generated,'ROUTE_CODE');
      a.pid=get(await post(a,'routeBuilder','buildFloatPlansFromRoute',{routeInstanceId:get(generated,'ROUTE_INSTANCE_ID'),vesselId:vessel}),'FLOATPLAN_IDS')[0];
      const bootstrap=await (await a.p.request.get(base+'/api/v1/floatplan.cfc?method=handle&action=bootstrap&id='+a.pid)).json();
      const plan=get(bootstrap,'FLOATPLAN');check(!!plan,a.label+' bootstrap loaded actual Draft');
      await post(a,'floatplan','save',{FLOATPLAN:{...plan,NAME:a.name,FLOATPLANID:a.pid,VESSELID:vessel,OPERATORID:operator,OPERATOR_HAS_PFD:true,EMAIL:a.email,RESCUE_CENTERID:-1,RESCUE_AUTHORITY:'N/A - Call 911',RESCUE_AUTHORITY_PHONE:'911',DO_NOT_SEND:false,...times},CONTACTS:[{CONTACTID:contact,SORT_ORDER:1}],PASSENGERS:[],WAYPOINTS:get(bootstrap,'PLAN_WAYPOINTS')?.length?get(bootstrap,'PLAN_WAYPOINTS'):get(get(bootstrap,'ROUTE_DEFAULTS'),'WAYPOINT_SELECTIONS')||[]});
    }
    check(Number(a.pid)>0,a.label+' actual owned plan ID');return a;
  }
  try {
    for(const source of ['basic_save_send','basic_review_send','premium_save_send']) {
      const modes=['success','definite','ambiguous',source==='basic_review_send'?'confirmation_failure':'partial'];
      for(const mode of modes) {
        const a=await setup(source,mode),result=await command(a,'send',{source,mode}),e=get(result,'evidence'),events=get(result,'events');
        const positive=['success','partial','confirmation_failure'].includes(mode),ambiguous=mode==='ambiguous';
        if(get(e,'SUCCESSFUL')!==positive)throw new Error(a.label+' unexpected send result: '+JSON.stringify(result));
        reports.push(a.label+' positive evidence agrees with accepted submission');
        check(get(e,'UNRESOLVED')===ambiguous,a.label+' ambiguous outcome remains unresolved');
        check(get(e,'INVALID')===false,a.label+' valid retained bindings');
        check(events.length===(ambiguous?1:2),a.label+' exact STARTED/outcome event count');
        check(events.every(x=>get(x,'entity_type')==='float_plan'&&Number(get(x,'entity_id'))===Number(a.pid)&&get(x,'event_source')===source&&get(x,'metadata_json')==='{}'),a.label+' actual entity/source identity and empty metadata');
        if(source!=='basic_review_send')check(get(get(result,'probe'),'startedAtPdf')===1,a.label+' retained STARTED exists before PDF/mail boundary');
        else check(get(get(result,'probe'),'startedAtPdf')===0,a.label+' PDF preparation precedes STARTED');
        if(source==='basic_review_send'&&ambiguous)check(get(get(result,'probe'),'startedAtTransport')===1,a.label+' STARTED precedes real SMTP submission');
        if(source==='basic_review_send'&&ambiguous)check(get(get(result,'probe'),'realSubmissionAccepted')===true,a.label+' application acknowledgement lost after real SMTP acceptance');
        if(mode==='confirmation_failure')check(get(result,'responseSuccess')===false&&get(result,'responseError')==='BASIC_REVIEW_CONFIRMATION_PENDING',a.label+' successful mail followed by rolled-back receipt confirmation');
        if(mode==='success')check(get(result,'responseSuccess')===true,a.label+' real send function succeeded');
        if(mode==='partial')check(get(result,'responseSuccess')===false&&!!get(result,'exceptionType'),a.label+' second recipient throws after first accepted submission');
        if(positive)check(get(result,'decision')==='SUPPRESSED_ALREADY_SHARED',a.label+' sharing suppresses recovery');
        if(ambiguous)check(get(result,'decision')==='HOLD_UNRESOLVED_SHARE_ATTEMPT',a.label+' ambiguous sharing holds recovery');
        if(mode==='definite') {
          check(get(e,'FAILED_COUNT')===1,a.label+' definitive failure recorded');
          const due=await command(a,'due');check(get(due,'eligible')===true&&get(due,'stage')==='D',a.label+' definitive failure allows ordinary D eligibility after 168h');
        }
        if(source==='premium_save_send'&&mode!=='success')check(String(get(result,'planStatus')).trim().toUpperCase()==='DRAFT'&&get(result,'premiumReceipts')===0&&get(result,'consumedCredits')===0,a.label+' domain transaction and credit/receipt changes rolled back');
        const expectedMail=positive||(source==='basic_review_send'&&ambiguous)?1:0;
        let captured=[];
        for(let n=0;n<40;n++){captured=await capturedShares(a);if(captured.length>=expectedMail)break;await a.p.waitForTimeout(500);}
        check(captured.length===expectedMail,a.label+' actual MailHog message count '+expectedMail);
        check(captured.every(m=>(m.To||[]).length===1&&(m.To[0].Mailbox+'@'+m.To[0].Domain).toLowerCase()===a.email),a.label+' only disposable recipient');
        if(source==='basic_review_send') {
          await post(a,'routeBuilder','deleteRoute',{routeCode:a.routeCode});
        } else {
          // Active/Premium production deletion guards are not bypassed in member code.
          // Test-only purge removes this disposable plan/receipts while retaining account evidence.
          await command(a,'purge');
        }
        const after=await command(a,'state'),ae=get(after,'evidence');
        check(get(after,'planCount')===0&&get(after,'premiumReceipts')===0&&get(after,'basicReceipts')===0,a.label+' source plan and receipts removed');
        check(get(ae,'SUCCESSFUL')===positive&&get(ae,'UNRESOLVED')===ambiguous,a.label+' retained sharing evidence survives deletion');
        if(positive)check(get(after,'decision')==='SUPPRESSED_ALREADY_SHARED',a.label+' permanent suppression survives deletion');
        if(ambiguous)check(get(after,'decision')==='HOLD_UNRESOLVED_SHARE_ATTEMPT',a.label+' unresolved HOLD survives deletion');
        cases.push({source,mode,events:events.length,mailCount:captured.length,beforeDecision:get(result,'decision'),afterDecision:get(after,'decision'),responseError:get(result,'responseError'),probe:get(result,'probe')});
      }
    }
  } catch(e){error=e.message;}
  finally {
    for(const a of accounts) {
      const item={label:a.label};
      try{Object.assign(item,await command(a,'cleanupFiles'));}catch(e){item.fileError=e.message;}
      try {
        const all=await mails(a);item.mailRemoved=0;
        for(const m of all){if(!(m.To||[]).every(t=>(t.Mailbox+'@'+t.Domain).toLowerCase()===a.email))throw new Error('MAIL_OWNER_MISMATCH');if(!(await a.p.request.delete('http://localhost:8025/api/v1/messages/'+encodeURIComponent(m.ID))).ok())throw new Error('MAIL_DELETE_FAILED');item.mailRemoved++;}
        item.mailRemaining=(await mails(a)).length;
      }catch(e){item.mailError=e.message;}
      try {
        const r=await a.p.request.post(base+'/tests/inactive-member-recovery-readiness-command.cfm?confirm=RUN_RECOVERY_READINESS_COMMAND&action=cleanup&runKey='+get(a.auth,'runKey'),{headers:{'X-FPW-Readiness-Test-Token':get(a.auth,'token')}});
        const body=await r.json();item.accountCleaned=r.ok()&&get(body,'ok')===true;item.usersRemaining=get(body,'remaining_users');if(!item.accountCleaned)item.accountError=JSON.stringify(body);
      }catch(e){item.accountError=e.message;}
      cleanup.push(item);
    }
    for(const c of contexts)await c.close();
  }
  return {success:!error&&cases.length===12&&cleanup.every(x=>x.accountCleaned&&x.mailRemaining===0&&!x.fileError),error,assertions:reports.length,cases,reports,cleanup};
}
