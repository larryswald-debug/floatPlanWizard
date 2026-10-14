async(page)=>{
 const base='http://localhost:8500/fpw', out={contextual:[],touch:[],forms:[]};
 const assert=(v,m)=>{if(!v)throw Error(m);};
 for(const [path,section] of [['/app/dashboard.cfm','route-and-trip-planning'],['/app/active-cruise.cfm','active-cruise-and-monitoring'],['/app/monitoring.cfm','active-cruise-and-monitoring'],['/app/weather.cfm','weather-and-safety'],['/boat-fuel-calculator/','calculators-and-tools']]){
   await page.goto(base+path,{waitUntil:'domcontentloaded'});
   const link=page.locator('.fpw-context-help');assert(await link.count()===1,path+' contextual link');assert((await link.getAttribute('href')).endsWith('#'+section),path+' contextual target');
   out.contextual.push({path,section});
 }
 for (const member of [false,true]) {
  for(const width of [390,320]) {
   const ctx=await page.context().browser().newContext({viewport:{width,height:844},hasTouch:true,isMobile:true,...(member?{storageState:await page.context().storageState()}: {})});
   const p=await ctx.newPage();
   try {
    for(let i=0;i<6;i++){
     await p.goto(base+'/help/');await p.locator('[data-fpw-mobile-toggle]').tap();await p.locator('#fpwHelpToggle').tap();
     const link=p.locator('#fpwHelpMenu a').nth(i),expected=await link.getAttribute('href');
     if(i===5) {await link.scrollIntoViewIfNeeded();await p.screenshot({path:'output/playwright/global-help/'+(member?'member':'anonymous')+'-touch-'+width+'.png'});}
     await Promise.all([p.waitForNavigation({waitUntil:'domcontentloaded'}),link.tap()]);
     assert(p.url()===new URL(expected,base).href,'Destination '+expected+' '+p.url());
     assert(await p.locator('#fpwHelpToggle').count()===1,'Shared Help at destination '+expected);
     out.touch.push({member,width,item:i,destination:expected});
    }
    for(const mode of ['contact','support','feedback']){
     await p.goto(base+'/app/contact.cfm?mode='+mode+'#contactForm');
     const overflow=await p.evaluate(()=>document.documentElement.scrollWidth>innerWidth);
     assert(!overflow,mode+' '+width+' page overflow');
     const clipped=await p.locator('#contactForm input:not([type=hidden]):not(#website),#category,#description').evaluateAll(ns=>ns.some(n=>{const r=n.getBoundingClientRect();return r.x<0||r.right>innerWidth;}));
     assert(!clipped,mode+' '+width+' form fields clipped');
     assert(await p.locator('#category option').count()===9,'Eight categories plus prompt');
     const form=p.locator('#contactForm');assert(await form.getAttribute('novalidate')===null,'Native validation enabled');
     await p.locator('#subject').scrollIntoViewIfNeeded();
     if(mode==='support') await p.screenshot({path:'output/playwright/global-help/'+(member?'member':'anonymous')+'-form-'+width+'.png'});
     out.forms.push({member,width,mode,containment:true});
    }
   }finally{await ctx.close();}
  }
 }
 await page.goto(base+'/help/');
 return out;
}
