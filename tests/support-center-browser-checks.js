// Run with Playwright MCP. The current page must be on local FPW; SMTP safety is checked first.
async (page) => {
  const base='http://localhost:8500/fpw', mail='http://localhost:8025';
  const endpoint=base+'/api/v1/contactUs.cfc?method=handle';
  const fixtureUrl=base+'/tests/support-center-fixture.cfm?confirm=RUN_SUPPORT_FIXTURES';
  const assert=(ok,message)=>{if(!ok) throw new Error(message);};
  const member=await page.locator('[data-fpw-member-identity]').count()>0;
  const ctx=await page.context().browser().newContext(member ? {storageState:await page.context().storageState()} : {});
  const p=await ctx.newPage(), request=ctx.request;
  const runId=await page.evaluate(()=>crypto.randomUUID().replaceAll('-',''));
  const results=[]; let setup, removedMail=0;
  const fixture=(action,fields)=>request.post(fixtureUrl,{data:{runId,action,fields},maxRedirects:0});
  const ownMail=async()=>{const r=await request.get(mail+'/api/v2/search?kind=containing&query='+runId);return (await r.json()).items||[];};
  try {
    const safety=await (await request.get(base+'/tests/auth-mail-safety-probe.cfm?confirm=READ_AUTH_MAIL_SAFETY')).json();
    assert(safety.SAFE_LOCAL_MAIL,'SMTP must be local MailHog');
    const start=await fixture('setup');assert(start.ok(),await start.text());setup=await start.json();
    await p.goto(base+'/app/contact.cfm');
    const csrf=await p.locator('[name=csrfToken]').inputValue();
    const fields={firstName:'Support',lastName:'Fixture',email:setup.EMAILS[0],subject:'Local support '+runId,category:'Other',description:'Disposable support verification '+runId,mode:'contact',website:'',csrfToken:csrf};
    async function check(name,changes,status=303,code='validation',options={}) {
      const r=await request.post(endpoint,{form:{...fields,...changes},maxRedirects:0,...options});
      assert(r.status()===status,name+': status '+r.status()+' '+(await r.text()).slice(0,180));
      const location=r.headers().location||'';
      if(status===303) assert(location.includes('code='+code),name+': '+location);
      assert(!location.includes(runId)&&!location.includes(csrf),name+': safe redirect');
      results.push({name,status:r.status()});return r;
    }
    const get=await request.get(endpoint,{maxRedirects:0});assert(get.status()===405 && get.headers().allow==='POST','GET rejected');results.push({name:'GET rejected',status:405});
    await check('missing CSRF',{csrfToken:''},403);
    const modeError=await check('CSRF error preserves mode',{csrfToken:'',mode:'support'},403);
    assert((await modeError.text()).includes('mode&#x3d;support')||(await modeError.text()).includes('mode=support'),'CSRF return link retains support mode');
    await check('stale CSRF',{csrfToken:'0'.repeat(64)},403);
    await check('cross-origin',{},403,'',{headers:{Origin:'https://untrusted.invalid'}});
    await check('cross-origin referer',{},403,'',{headers:{Referer:'https://untrusted.invalid/form'}});
    const staleContext=await page.context().browser().newContext();
    try {const stale=await staleContext.request.post(endpoint,{form:fields,maxRedirects:0});assert(stale.status()===403,'Previous session token rejected');results.push({name:'previous session CSRF',status:403});} finally {await staleContext.close();}
    const urlToken=await request.post(endpoint+'&csrfToken='+csrf,{form:{...fields,csrfToken:''},maxRedirects:0});assert(urlToken.status()===403,'URL CSRF cannot override form');results.push({name:'URL CSRF rejected',status:403});
    for(const name of ['firstName','lastName','email','subject','category','description']) await check('required '+name,{[name]:''});
    for(const [name,size] of [['firstName',80],['lastName',80],['email',254],['subject',180],['description',5000]]) await check('maximum '+name,{[name]:'x'.repeat(size+1)});
    await check('invalid email',{email:'bad-address'},303,'invalid_email');
    await check('forged category',{category:'Forged category'});
    await check('forged mode',{mode:'admin'});
    for(const name of ['email','subject','firstName','lastName']) await check('header injection '+name,{[name]:'Value\r\nBcc: injected@test.invalid'});
    await check('trailing header newline',{subject:'Subject\n'});
    const structured=await fixture('non_scalar',fields);assert(structured.status()===303 && structured.headers().location.includes('code=validation'),'structured field rejected');results.push({name:'non-scalar rejected',status:303});
    const denied=await fixture('admission_failure',fields);assert(denied.status()===503,'Unavailable admission fails closed');results.push({name:'admission unavailable',status:503});
    assert((await ownMail()).length===0,'Rejected input must not send mail');
    for(const [mode,label,prefix] of [['contact','Send Message','Contact Us'],['support','Submit Support Request','Support Request'],['feedback','Send Suggestion','Feature Suggestion']]) {
      await p.goto(base+'/app/contact.cfm?mode='+mode+'#contactForm');
      assert(await p.locator('#fpwHelpMenu [aria-current=page]').count()===1,'active contact mode');
      for(const name of ['firstName','lastName','email','subject','description']) await p.locator('#'+name).fill(fields[name]);
      await p.locator('#category').selectOption('Other');
      if (mode==='contact') await p.locator('#contactForm').evaluate(f=>f.action+='&email=forged%40test.invalid&mode=feedback&subject=forged');
      await p.getByRole('button',{name:label,exact:true}).click();
      await p.waitForURL('**/app/contact.cfm?mode='+mode+'&status=success');
      assert(await p.locator('.alert-success').count()===1,mode+' confirmation');
      results.push({name:mode+' browser form',status:200});
      const messages=await ownMail();
      const message=messages.find(m=>m.Content.Headers.Subject[0]==='Float Plan Wizard '+prefix+': '+fields.subject);
      assert(message,mode+' captured subject');
      assert(message.Content.Headers.From[0]==='noreply@floatplanwizard.com',mode+' sender');
      assert(message.Content.Headers.To[0]==='support@floatplanwizard.com',mode+' recipient');
      assert(message.Content.Headers['Reply-To'][0]===fields.email,mode+' Reply-To');
      assert(message.Content.Body.includes(fields.description)&&message.Content.Body.includes('Category: Other'),mode+' body');
    }
    const boundary={...fields,email:setup.EMAILS[9],firstName:'N'.repeat(80),lastName:'L'.repeat(80),subject:runId+'S'.repeat(148),description:runId+'D'.repeat(4968)};
    const accepted=await request.post(endpoint,{form:boundary,maxRedirects:0});assert(accepted.status()===303 && accepted.headers().location.endsWith('status=success'),'Exact length boundaries accepted');results.push({name:'exact name email subject message limits',status:303});
    const honey=await request.post(endpoint,{form:{...fields,mode:'feedback',website:'https://bot.invalid'},maxRedirects:0});assert(honey.status()===303 && honey.headers().location.endsWith('status=success'),'Honeypot safe success');results.push({name:'honeypot',status:303});
    const failure=await fixture('mail_failure',fields);assert(failure.status()===303 && failure.headers().location.endsWith('code=send_failed'),'SMTP refusal safe error: '+failure.status()+' '+failure.headers().location);results.push({name:'SMTP refusal',status:303});
    const failedPage=await request.get(base+ '/app/contact.cfm?mode=contact');assert((await failedPage.text()).includes('We could not send your message.'),'Safe SMTP flash');
    await check('combined-mode email quota',{mode:'support',email:fields.email.toUpperCase()},429);
    // Six attempts admitted so far: three browser sends, one boundary, honeypot, and SMTP failure.
    for(let i=0;i<14;i++) {
      const r=await request.post(endpoint,{form:{...fields,email:setup.EMAILS[2+Math.floor(i/5)],mode:['contact','support','feedback'][i%3],website:'bot'},maxRedirects:0});
      assert(r.status()===303 && r.headers().location.endsWith('status=success'),'IP quota admission '+i);
    }
    const ipDenied=await check('combined-mode IP quota',{email:setup.EMAILS[8],mode:'feedback'},429);
    assert(Number(ipDenied.headers()['retry-after'])>0,'Retry-After');
    assert((await ownMail()).length===4,'Only four intended support emails');
    await p.goto(base+'/app/contact.cfm?mode=feedback&status=success&code=%3Cscript%3E');
    assert(await p.locator('.alert-success').count()===0,'Query status cannot forge confirmation');
    results.push({name:'safe reflected query values',status:200});
    return {runId,audience:member ? "member" : "anonymous",checks:results,mailMessages:4,cleanupExpected:true};
  } finally {
    if(setup) {
      const messages=await ownMail();
      for(const message of messages) {assert((await request.delete(mail+'/api/v1/messages/'+message.ID)).ok(),'Mail cleanup');removedMail++;}
      const cleaned=await fixture('cleanup');assert(cleaned.ok()&&(await cleaned.json()).CLEANED,'Counter cleanup');
      assert((await ownMail()).length===0,'No fixture mail remains');
    }
    await ctx.close();
  }
}
