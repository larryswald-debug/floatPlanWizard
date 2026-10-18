async(page)=>{
 const base='http://localhost:8500/fpw', out={contextual:[],touch:[],forms:[]};
 const assert=(v,m)=>{if(!v)throw Error(m);};
 for(const [path,section] of [
   ['/app/dashboard.cfm','1-find-your-way-around-fpw'],
   ['/app/completed-trip.cfm','23-view-the-completed-trip-record'],
   ['/app/active-cruise.cfm','18-read-active-cruise'],
   ['/app/active-cruise.cfm?mode=preview','18-read-active-cruise'],
   ['/app/monitoring.cfm','19-check-in-and-understand-monitoring'],
   ['/app/weather.cfm','13-use-weather-in-planning-and-underway'],
   ['/boat-fuel-calculator/','14-use-the-linked-fuel-and-range-calculator'],
   ['/app/fuel-calculator.cfm','14-use-the-linked-fuel-and-range-calculator']
 ]){
   await page.goto(base+path,{waitUntil:'domcontentloaded'});
   const link=page.locator('.fpw-context-help');assert(await link.count()===1,path+' contextual link');assert(await link.getAttribute('href')==='/fpw/app/user-manual.cfm#'+section,path+' contextual target');
   const originalUrl=page.url();
   await link.click();
   if(path==='/app/fuel-calculator.cfm'){
     // The older calculator retains its original direct-navigation behavior.
     await page.waitForURL(base+'/app/user-manual.cfm#'+section);
     assert(await page.locator('[id="'+section+'"]').isVisible(),path+' manual chapter visible');
   }else{
     await page.locator('#fpwHelpDrawer [data-help-source-id="'+section+'"]').waitFor({state:'visible'});
     assert(page.url()===originalUrl,path+' stays loaded');
     await page.locator('[data-help-close]').click();
     await page.locator('#fpwHelpDrawer').waitFor({state:'hidden'});
     assert(await link.evaluate(n=>n===document.activeElement),path+' focus restored');
   }
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
