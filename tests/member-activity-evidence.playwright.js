async (page) => {
  // Execute with MCP Playwright browser_run_code_unsafe. Fresh normal signups only.
  const run = Date.now().toString(36);
  const reports = [];
  const contexts = [];
  const accounts = [];
  const get = (o,k) => o?.[k] ?? o?.[k.toUpperCase()] ?? o?.[k.toLowerCase()];
  const assert = (ok,label) => { if (!ok) throw new Error(label); };
  async function signup(suffix) {
    const context = await page.context().browser().newContext();
    contexts.push(context);
    const p = await context.newPage();
    const email = 'codex-activity-' + run + '-' + suffix + '@example.test';
    await p.goto('http://localhost:8500/fpw/app/join.cfm');
    await p.getByRole('textbox',{name:'First Name',exact:true}).fill('Activity');
    await p.getByRole('textbox',{name:'Last Name',exact:true}).fill('Evidence');
    await p.getByRole('textbox',{name:'Email',exact:true}).fill(email);
    await p.getByRole('textbox',{name:'Password',exact:true}).fill('Disposable-Activity-2026!');
    await p.getByRole('textbox',{name:'Confirm Password',exact:true}).fill('Disposable-Activity-2026!');
    await p.getByRole('checkbox').check();
    await p.getByRole('button',{name:'Start Planning My Trip'}).click();
    await p.waitForURL(/dashboard[.]cfm/, {timeout:15000});
    const account = {page:p,email};
    accounts.push(account);
    return account;
  }
  async function post(account,family,action,payload={},mode='') {
    const url = mode
      ? '/fpw/tests/member-activity-command.cfm?confirm=RUN_MEMBER_ACTIVITY_EVIDENCE_TESTS&family='+family+'&mode='+mode
      : '/fpw/api/v1/'+family+'.cfc?method=handle'+(family==='routeBuilder'||family==='floatplan'?'&action='+action:'');
    const response = await account.page.request.post('http://localhost:8500'+url,{data:{...payload,action}});
    const text = await response.text();
    try {return JSON.parse(text);} catch {throw new Error('Non-JSON '+family+' '+action+' HTTP '+response.status()+': '+text.slice(0,150));}
  }
  async function events(a) {return get(await post(a,'vessel','',{},'state'),'events').filter(e=>get(e,'event_source')==='member_api');}
  async function check(a,label,name,delta,fn,success=true,entityId) {
    const before=await events(a), result=await fn(), after=await events(a);
    assert(get(result,'SUCCESS')===success,label+' response: '+JSON.stringify(result.ERROR||result.DETAIL||result.MESSAGE||result));
    const added=after.filter(e=>!before.some(b=>get(b,'id')===get(e,'id')));
    assert(added.length===delta,label+' expected '+delta+' events, got '+added.length);
    if(delta) {
      assert(added.every(e=>get(e,'event_name')===name),label+' wrong event');
      if(entityId)assert(added.every(e=>Number(get(e,'entity_id'))===Number(entityId)),label+' wrong entity');
    }
    reports.push(label);
    return result;
  }
  let error='', cfResults={}, cleanup=[];
  try {
    const a=await signup('owner'), b=await signup('other');
    const definitions={
      vessel:{VESSELNAME:'Test Vessel',TYPE:'Power',LENGTH:'24',COLOR:'White',REGISTRATION:'Private registration',MAX_SPEED:'10.000',FUEL_CAPACITY:'80.001'},
      contact:{CONTACTNAME:'Test Contact',PHONE:'555-0100',EMAIL:'private@example.test'},
      operator:{OPERATORNAME:'Test Operator',PHONE:'555-0101',NOTES:'Private operator contents'},
      passenger:{PASSENGERNAME:'Test Passenger',PHONE:'555-0102',AGE:'32',GENDER:'Other',NOTES:'Private passenger contents'},
      waypoint:{WAYPOINTNAME:'Test Start',LATITUDE:'27.95',LONGITUDE:'-82.46',NOTES:'Private waypoint contents'}
    };
    const ids={}, foreign={};
    for(const [family,payload] of Object.entries(definitions)) {
      const event=family==='contact'?'shore_contact':family;
      const idKey=family.toUpperCase()+'ID';
      const own=await check(a,family+' creation',event+'_created',1,()=>post(a,family,'save',{[family]:payload}));
      ids[family]=Number(own[idKey]); payload[idKey]=ids[family];
      const other=await post(b,family,'save',{[family]:{...payload,[idKey]:0}});
      assert(other.SUCCESS,family+' other fixture');
      foreign[family]=Number(other[idKey]);
      await check(a,family+' unchanged save',event+'_updated',0,()=>post(a,family,'save',{[family]:payload}));
      payload[family.toUpperCase()+'NAME']+=' edited';
      const countBefore=(await events(a)).length;
      const both=await Promise.all([post(a,family,'save',{[family]:payload}),post(a,family,'save',{[family]:payload})]);
      assert(both.every(r=>r.SUCCESS),family+' concurrent responses');
      assert((await events(a)).length===countBefore+1,family+' concurrent duplicate evidence');
      reports.push(family+' concurrent identical edits');
      await check(a,family+' failed validation',event+'_updated',0,()=>post(a,family,'save',{[family]:{...payload,[family.toUpperCase()+'NAME']:''}}),false);
      await check(a,family+' cross-member denial',event+'_updated',0,()=>post(a,family,'save',{[family]:{...payload,[idKey]:foreign[family],ISDEFAULTVESSEL:1}}),false);
      for(const mode of ['before','after']) {
        await check(a,family+' '+mode+' event failure',event+'_updated',0,()=>post(a,family,'save',{[family]:{...payload,[family.toUpperCase()+'NAME']:'Rollback value'}},mode),false);
        await check(a,family+' '+mode+' domain rollback',event+'_updated',0,()=>post(a,family,'save',{[family]:payload}));
      }
    }
    const png = await a.page.evaluate(() => {
      const canvas=document.createElement('canvas');canvas.width=8;canvas.height=8;
      canvas.getContext('2d').fillRect(0,0,8,8);return canvas.toDataURL('image/png').split(',')[1];
    });
    const upload = vesselId => a.page.evaluate(async ({vesselId,png}) => {
      const bytes=Uint8Array.from(atob(png),character=>character.charCodeAt(0));
      const form=new FormData();form.append('image_file',new Blob([bytes],{type:'image/png'}),'activity-test.png');
      const r=await fetch('/fpw/api/v1/vesselImageUpload.cfm?vessel_id='+vesselId,{method:'POST',body:form});
      return r.json();
    },{vesselId,png});
    await check(a,'photo HTTP upload','vessel_updated',1,()=>upload(ids.vessel),true,ids.vessel);
    await check(a,'identical photo HTTP upload','vessel_updated',0,()=>upload(ids.vessel));
    await check(a,'cross-member photo HTTP denial','vessel_updated',0,()=>upload(foreign.vessel),false);
    await check(a,'photo HTTP removal','vessel_updated',1,()=>post(a,'vessel','removeimage',{vesselId:ids.vessel}));
    await check(a,'absent photo HTTP removal','vessel_updated',0,()=>post(a,'vessel','removeimage',{vesselId:ids.vessel}));
    const route=await check(a,'empty named route creation','user_route_created',1,()=>post(a,'routeBuilder','createUserRoute',{route_name:'Activity route'}));
    const rid=route.DATA.route_id;
    await check(a,'existing named route reuse','user_route_updated',0,()=>post(a,'routeBuilder','createUserRoute',{route_name:'Activity route'}));
    const end=await post(a,'waypoint','save',{waypoint:{WAYPOINTNAME:'Test End',LATITUDE:'27.96',LONGITUDE:'-82.45'}});
    await check(a,'route start waypoint change','user_route_updated',1,()=>post(a,'routeBuilder','setUserRouteStartWaypoint',{route_id:rid,start_waypoint_id:ids.waypoint}),true,rid);
    const leg=await check(a,'route waypoint leg addition','user_route_updated',1,()=>post(a,'routeBuilder','addWaypointLegToUserRoute',{route_id:rid,end_waypoint_id:end.WAYPOINTID}),true,rid);
    const lid=leg.DATA.legs[0].route_leg_id;
    const geometry=[{lat:27.95,lon:-82.46},{lat:27.955,lon:-82.454},{lat:27.96,lon:-82.45}];
    const geo={route_id:rid,route_leg_id:lid,points:geometry};
    await check(a,'persisted route leg geometry','user_route_updated',1,()=>post(a,'routeBuilder','saveRouteLegOverrideGeometry',geo));
    await check(a,'unchanged route leg geometry','user_route_updated',0,()=>post(a,'routeBuilder','saveRouteLegOverrideGeometry',geo));
    await check(a,'unchanged leg reorder','user_route_updated',0,()=>post(a,'routeBuilder','reorderUserRouteLegs',{route_id:rid,route_leg_ids:[lid]}));
    const genInput={route_type:'my_route',route_id:rid,route_name:'Generated activity',selected_vessel_id:ids.vessel,speed_kn:10,cruising_speed:10,underway_hours_per_day:6.5,start_date:new Date(Date.now()+86400000).toISOString().slice(0,10)};
    const gen=await check(a,'generated route creation','route_created',1,()=>post(a,'routeBuilder','routegen_generate',genInput));
    genInput.route_code=gen.ROUTE_CODE;
    await check(a,'unchanged generated route rebuild','route_updated',0,()=>post(a,'routeBuilder','routegen_update',genInput));
    genInput.route_name+=' edited';
    await check(a,'generated route saved choices','route_updated',1,()=>post(a,'routeBuilder','routegen_update',genInput),true,gen.ROUTE_INSTANCE_ID);
    for(const mode of ['before','after']) {
      await check(a,'generated route '+mode+' event failure','route_updated',0,()=>post(a,'routeBuilder','routegen_update',{...genInput,route_name:'Rollback'},mode),false);
      await check(a,'generated route '+mode+' rollback','route_updated',0,()=>post(a,'routeBuilder','routegen_update',genInput));
      await check(a,'named route '+mode+' event failure','user_route_created',0,()=>post(a,'routeBuilder','createUserRoute',{route_name:'Rollback '+mode},mode),false);
    }
    await check(a,'cross-member generated-Draft vessel denial','float_plan_created',0,()=>post(a,'routeBuilder','buildFloatPlansFromRoute',{routeInstanceId:gen.ROUTE_INSTANCE_ID,vesselId:foreign.vessel}),false);
    const draft=await check(a,'generated Draft creation','float_plan_created',1,()=>post(a,'routeBuilder','buildFloatPlansFromRoute',{routeInstanceId:gen.ROUTE_INSTANCE_ID,vesselId:ids.vessel}));
    const pid=draft.FLOATPLAN_IDS[0];
    await check(a,'existing generated Draft reuse','float_plan_created',0,()=>post(a,'routeBuilder','buildFloatPlansFromRoute',{routeInstanceId:draft.ROUTE_INSTANCE_ID,vesselId:ids.vessel}));
    const bootstrap=await (await a.page.request.get('http://localhost:8500/fpw/api/v1/floatplan.cfc?method=handle&action=bootstrap&id='+pid)).json();
    const fp={FLOATPLAN:{...bootstrap.FLOATPLAN,NOTES:'Saved private draft note'},CONTACTS:[],PASSENGERS:[],WAYPOINTS:[]};
    await check(a,'Draft saved edit','float_plan_updated',1,()=>post(a,'floatplan','save',fp),true,pid);
    await check(a,'Draft no-op save','float_plan_updated',0,()=>post(a,'floatplan','save',fp));
    fp.CONTACTS=[{CONTACTID:ids.contact}];
    await check(a,'Draft selected-contact-only save','float_plan_updated',1,()=>post(a,'floatplan','save',fp));
    await check(a,'Draft unchanged selected contacts','float_plan_updated',0,()=>post(a,'floatplan','save',fp));
    const extraContact=await post(a,'contact','save',{contact:{CONTACTNAME:'Second Contact',PHONE:'555-0144',EMAIL:'second@example.test'}});
    fp.CONTACTS.push({CONTACTID:extraContact.CONTACTID});
    await check(a,'additional selected contact','float_plan_updated',1,()=>post(a,'floatplan','save',fp));
    fp.CONTACTS.reverse();
    await check(a,'contact ordering is not activity','float_plan_updated',0,()=>post(a,'floatplan','save',fp));
    await check(a,'Draft cross-member selected contact denial','float_plan_updated',0,()=>post(a,'floatplan','save',{...fp,CONTACTS:[{CONTACTID:foreign.contact}]}),false);
    for(const mode of ['before','after']) {
      await check(a,'Draft '+mode+' event failure','float_plan_updated',0,()=>post(a,'floatplan','save',{...fp,FLOATPLAN:{...fp.FLOATPLAN,NOTES:'Rollback draft'}},mode),false);
      await check(a,'Draft '+mode+' rollback','float_plan_updated',0,()=>post(a,'floatplan','save',fp));
    }
    const basic={FLOATPLAN:{NAME:'Route-less Basic activity',NOTES:'Private basic note'},BASIC_DETAILS:{VESSEL_NAME:'Basic vessel',OPERATOR_NAME:'Basic operator',CAPTAIN_NAME:'Captain',CAPTAIN_EMAIL:a.email,NOTIFICATION_CONTACT_NAME:'Basic contact',NOTIFICATION_CONTACT_EMAIL:'private@example.test',NOTIFICATION_CONTACT_PHONE:'555-0100',LAUNCH_LOCATION:'Test launch',DESTINATION_LOCATION:'Test end',AUTHORITY_ID:-1},PASSENGERS:[],WAYPOINTS:[]};
    const basicCreated=await check(a,'route-less Basic Draft creation','float_plan_created',1,()=>post(a,'floatplan','savebasic',basic));
    basic.FLOATPLAN.FLOATPLANID=basicCreated.FLOATPLANID;
    await check(a,'Basic Draft no-op','float_plan_updated',0,()=>post(a,'floatplan','savebasic',basic));
    basic.BASIC_DETAILS.NOTIFICATION_CONTACT_PHONE='555-0199';
    await check(a,'Basic Draft selected-contact details edit','float_plan_updated',1,()=>post(a,'floatplan','savebasic',basic));
    for(const mode of ['before','after']) {
      await check(a,'Basic Draft '+mode+' event failure','float_plan_updated',0,()=>post(a,'floatplan','savebasic',{...basic,FLOATPLAN:{...basic.FLOATPLAN,NOTES:'Rollback Basic'}},mode),false);
      await check(a,'Basic Draft '+mode+' rollback','float_plan_updated',0,()=>post(a,'floatplan','savebasic',basic));
    }
    const segment={segment_id:1,geometry:[{lat:38.98,lon:-76.48},{lat:39.0,lon:-76.4}],override_fields:{}};
    await check(a,'standalone persisted segment geometry','route_segment_updated',1,()=>post(a,'routeBuilder','routegen_savesegmentoverride',segment));
    await check(a,'identical standalone segment geometry','route_segment_updated',0,()=>post(a,'routeBuilder','routegen_savesegmentoverride',segment));
    for(const mode of ['before','after']) {
      await check(a,'segment '+mode+' event failure','route_segment_updated',0,()=>post(a,'routeBuilder','routegen_savesegmentoverride',{...segment,geometry:[{lat:38.98,lon:-76.48},{lat:39.1,lon:-76.4}]},mode),false);
      await check(a,'segment '+mode+' rollback','route_segment_updated',0,()=>post(a,'routeBuilder','routegen_savesegmentoverride',segment));
    }
    await check(a,'standalone geometry removal','route_segment_updated',1,()=>post(a,'routeBuilder','routegen_clearsegmentoverride',segment));
    await check(a,'already-cleared standalone geometry','route_segment_updated',0,()=>post(a,'routeBuilder','routegen_clearsegmentoverride',segment));
    const beforeView=(await events(a)).length;
    await a.page.evaluate(()=>{window.activityBrowserOnlyGeometry=[{lat:1,lon:2},{lat:3,lon:4}];});
    await a.page.reload();
    assert((await events(a)).length===beforeView,'browser-only/page-view activity');
    reports.push('page views and browser-only state emit no evidence');
    await check(a,'successful login is not recovery activity','',0,()=>post(a,'auth','login',{email:a.email,password:'Disposable-Activity-2026!'}));
    const cf=await a.page.request.get('http://localhost:8500/fpw/tests/member-activity-evidence-runner.cfm?confirm=RUN_MEMBER_ACTIVITY_EVIDENCE_TESTS&fixtureEmail='+encodeURIComponent(a.email));
    const cfJson=await cf.json(), result=get(cfJson,'RESULTS');
    cfResults={pass:result.totalPass,fail:result.totalFail,error:result.totalError};
    const failures=[];
    const walk = value => {
      if(!value||typeof value!=='object')return;
      if(value.failMessage)failures.push({name:value.name,message:value.failMessage,detail:value.error?.Detail});
      for(const child of Object.values(value))if(typeof child==='object')walk(child);
    };
    walk(result);cfResults.failures=failures;
    assert(get(cfJson,'SUCCESS')===true,'ColdFusion integration suite');
    const retained=await events(a);
    const temporary=await check(a,'temporary owned waypoint creation','waypoint_created',1,()=>post(a,'waypoint','save',{waypoint:{WAYPOINTNAME:'Delete me'}}));
    await check(a,'whole waypoint deletion is not activity','waypoint_updated',0,()=>post(a,'waypoint','delete',{waypointId:temporary.WAYPOINTID}));
    const deletedState=await post(a,'vessel','',{},'state');
    assert(!get(get(deletedState,'owned_ids'),'waypoint').includes(Number(temporary.WAYPOINTID)),'waypoint row still exists');
    assert(get(deletedState,'events').some(e=>get(e,'event_name')==='waypoint_created'&&Number(get(e,'entity_id'))===Number(temporary.WAYPOINTID)),'deleted waypoint evidence lost');
    reports.push('durable evidence survives actual source-row deletion');
    for(const e of retained) {
      const metadata=JSON.parse(get(e,'metadata_json'));
      const creation=['vessel_created','shore_contact_created'].includes(get(e,'event_name'));
      assert(Object.keys(metadata).length===(creation?1:0),'private event metadata');
      assert(/^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:]{8}Z$/.test(get(e,'utc')),'UTC formatting');
    }
    reports.push('PII-free metadata and canonical UTC event formatting');
  } catch(e) {
    error=e.message;
  } finally {
    for(const a of accounts) {
      try {cleanup.push(await post(a,'vessel','',{},'cleanup'));} catch(e) {cleanup.push({SUCCESS:false,error:e.message,email:a.email});}
    }
    for(const context of contexts)await context.close();
  }
  return {success:!error&&cleanup.every(c=>c.SUCCESS),error,assertions:reports.length,reports,cfResults,accounts:accounts.map(a=>a.email),cleanup};
}
