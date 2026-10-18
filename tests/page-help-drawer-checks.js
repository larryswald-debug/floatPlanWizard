// Run through Playwright MCP browser_run_code_unsafe.filename on the local FPW site.
// Creates fresh local fixture users, sends no mail, and removes them in finally.
async (page) => {
  const base = 'http://localhost:8500/fpw';
  const assert = (ok, message) => { if (!ok) throw Error(message); };
  const browser = page.context().browser();
  const fixtureContext = await browser.newContext();
  const fixtureUrl = base + '/tests/auth-endpoint-security-fixture.cfm?confirm=RUN_AUTH_ENDPOINT_FIXTURES';
  const runId = (Date.now().toString(16) + Math.random().toString(16).slice(2)).padEnd(32, '0').slice(0, 32);
  const cases = [
    ['/app/dashboard.cfm', '1-find-your-way-around-fpw'],
    ['/app/completed-trip.cfm', '23-view-the-completed-trip-record'],
    ['/app/active-cruise.cfm', '18-read-active-cruise'],
    ['/app/active-cruise.cfm?mode=preview', '18-read-active-cruise'],
    ['/app/monitoring.cfm', '19-check-in-and-understand-monitoring'],
    ['/app/weather.cfm', '13-use-weather-in-planning-and-underway'],
    ['/boat-fuel-calculator/', '14-use-the-linked-fuel-and-range-calculator']
  ];
  const out = { cases: [], screenshots: [], pageErrors: [], consoleErrors: [], checks: [] };
  const contexts = [];
  let created = false;
  async function ready(p, id) {
    await p.locator('#fpwHelpDrawer [data-help-source-id="' + id + '"]').waitFor({state:'visible'});
    await p.waitForFunction(() => Math.abs(document.getElementById('fpwHelpDrawer').getBoundingClientRect().right - innerWidth) < 1);
  }
  async function closed(p) { await p.locator('#fpwHelpDrawer').waitFor({state:'hidden'}); }
  async function context(options = {}) {
    const ctx = await browser.newContext({storageState: await fixtureContext.storageState(), ...options});
    contexts.push(ctx);
    return ctx;
  }
  try {
    const setup = await (await fixtureContext.request.post(fixtureUrl, {data:{action:'setup', runId}})).json();
    assert(setup.SUCCESS, 'fixture setup');
    created = true;
    out.fixtureIds = Object.values(setup.USERS).map(u => u.ID);
    const user = setup.USERS.change;
    const boot = await (await fixtureContext.request.get(base + '/api/v1/auth.cfc?method=bootstrap')).json();
    const login = await (await fixtureContext.request.post(base + '/api/v1/auth.cfc?method=handle', {
      data:{action:'login', email:user.EMAIL, password:user.PASSWORD}, headers:{'X-CSRF-Token':boot.CSRF_TOKEN, Origin:'http://localhost:8500'}
    })).json();
    assert(login.SUCCESS, 'fixture login');
    const warm = await fixtureContext.newPage();
    await warm.goto(base + '/app/dashboard.cfm', {waitUntil:'domcontentloaded'});
    await warm.locator('#welcomeOnboardingCloseBtn').click();
    await warm.locator('#welcomeOnboardingModal').waitFor({state:'hidden'});
    const manualResponse = await fixtureContext.request.get(base + '/app/user-manual.cfm');
    assert(manualResponse.status() === 200, 'original manual remains available');
    const manualHtml = await manualResponse.text();
    const source = await warm.evaluate(html => {
      const doc = new DOMParser().parseFromString(html, 'text/html');
      return {chapters: Array.from(doc.querySelectorAll('[data-manual-chapter]')).map(n => ({id:n.id, text:n.textContent.replace(/\s+/g, ' ').trim()})), images:doc.querySelectorAll('.fpw-manual-reading img').length};
    }, manualHtml);
    out.manualImages = source.images;
    for (const [width, height] of [[1440,1000], [390,844], [320,568]]) {
      const ctx = await context({viewport:{width,height}, hasTouch:width < 500, isMobile:width < 500});
      const p = await ctx.newPage();
      p.on('pageerror', error => out.pageErrors.push({url:p.url(), message:error.message}));
      p.on('console', message => { if (message.type() === 'error') out.consoleErrors.push({url:p.url(), message:message.text(), source:message.location().url}); });
      for (const [path, id] of cases) {
        const response = await p.goto(base + path, {waitUntil:'domcontentloaded'});
        const trigger = p.locator('.fpw-context-help');
        assert(await trigger.count() === 1, path + ': one existing trigger');
        await p.waitForFunction(() => document.querySelector('.fpw-context-help').getAttribute('aria-controls') === 'fpwHelpDrawer');
        if (path.includes('fuel-calculator')) {
          await p.locator('#totalNm').fill('83.7');
          await p.locator('#mostEfficientSpeedKn').fill('7.4');
          await p.locator('#fuelBurnEfficientGph').fill('3.9');
          await p.locator('#fuelPricePerGal').fill('5.23');
        }
        await p.evaluate(() => window.scrollTo({left:0, top:130, behavior:'instant'}));
        await trigger.scrollIntoViewIfNeeded();
        await trigger.focus();
        const before = await p.evaluate(() => ({url:location.href, time:performance.timeOrigin, x:scrollX, y:scrollY, fields:Array.from(document.querySelectorAll('#qaFuelCalcForm input, #qaFuelCalcForm select')).map(n=>[n.id,n.value]), styles:[document.body.style.cssText,document.documentElement.style.cssText]}));
        if (width < 500) await trigger.tap(); else await p.keyboard.press('Enter');
        await ready(p, id);
        assert(await p.locator('#fpwHelpDrawer').count() === 1, 'one drawer');
        assert(p.url() === before.url, 'page URL preserved');
        assert(await p.locator('#fpwHelpDrawer .fpw-site-header, #fpwHelpDrawer script, #fpwHelpDrawer .fpw-manual-hero').count() === 0, 'no full page chrome');
        const text = (await p.locator('[data-help-source-id="'+id+'"]').textContent()).replace(/\s+/g,' ').trim();
        assert(text === source.chapters.find(c=>c.id===id).text, path + ': unchanged chapter prose');
        const box = await p.locator('#fpwHelpDrawer').boundingBox();
        assert(Math.abs(box.width - Math.min(450,width)) < 1 && Math.abs(box.x + box.width - width) < 1, 'right aligned responsive width');
        assert(box.y === 0 && box.height <= height + 1, 'drawer vertical containment');
        assert(await p.locator('[data-help-scroll]').evaluate(n=>n.scrollWidth <= n.clientWidth + 1), 'content contained horizontally');
        await p.locator('[data-help-close]').focus();
        for (let i=0; i<9; i++) {
          await p.keyboard.press('Tab');
          assert(await p.locator('#fpwHelpDrawer').evaluate(n=>n.contains(document.activeElement)), 'focus stays in dialog');
        }
        for (let i=0; i<9; i++) {
          await p.keyboard.press('Shift+Tab');
          assert(await p.locator('#fpwHelpDrawer').evaluate(n=>n.contains(document.activeElement)), 'reverse focus stays in dialog');
        }
        const scrolled = await p.locator('[data-help-scroll]').evaluate(n=>{n.scrollTop=160;return n.scrollTop;});
        assert(scrolled > 0, 'independent content scroll');
        assert(await p.evaluate(y=>scrollY===y,before.y), path + ': background scroll preserved while open; before='+before.y+' after='+await p.evaluate(()=>scrollY));
        if (path === '/app/monitoring.cfm') {
          await p.locator('[data-help-scroll]').evaluate(n=>{n.scrollTop=0;});
          const screenshot = 'output/playwright/page-help-drawer/help-'+width+'.png';
          await p.screenshot({path:screenshot});out.screenshots.push(screenshot);
        }
        await p.keyboard.press('Escape');await closed(p);
        const after = await p.evaluate(() => ({url:location.href, time:performance.timeOrigin, x:scrollX, y:scrollY, fields:Array.from(document.querySelectorAll('#qaFuelCalcForm input, #qaFuelCalcForm select')).map(n=>[n.id,n.value]), styles:[document.body.style.cssText,document.documentElement.style.cssText]}));
        assert(JSON.stringify(after)===JSON.stringify(before), path + ': page, values, scroll and styles restored');
        assert(await trigger.evaluate(n=>n===document.activeElement), 'opener focus restored');
        await trigger.click();await ready(p,id);
        await p.locator('[data-help-close]').click();await closed(p);
        assert(await trigger.getAttribute('aria-expanded')==='false', 'ARIA closed state');
        out.cases.push({path,width,status:response.status(),chapter:id});
      }
      if (width === 1440) {
        await p.locator('.fpw-context-help').click();await ready(p,cases[6][1]);
        await p.locator('#fpwHelpDrawer .fpw-manual-back').click();await ready(p,'manualContents');
        assert(await p.locator('#fpwHelpDrawer [data-manual-toc]').count()===27, 'all contents destinations preserved');
        for (const chapter of source.chapters) {
          await p.locator('#fpwHelpDrawer [data-manual-toc][href$="#'+chapter.id+'"]').click();await ready(p,chapter.id);
          const text=(await p.locator('[data-help-source-id="'+chapter.id+'"]').textContent()).replace(/\s+/g,' ').trim();
          assert(text===chapter.text,'contents link preserves chapter '+chapter.id);
          await p.locator('#fpwHelpDrawer .fpw-manual-back').click();await ready(p,'manualContents');
        }
        const original=p.url();
        const popupPromise=ctx.waitForEvent('page');await p.locator('[data-help-full]').click();
        const popup=await popupPromise;await popup.waitForLoadState('domcontentloaded');
        assert(popup.url()===base+'/app/user-manual.cfm#manualContents' && p.url()===original,'full manual opens separately');
        await popup.close();await p.locator('[data-help-close]').click();await closed(p);
        out.checks.push('All 27 contents links and chapter text; separate full manual tab');
      }
      await ctx.close();
    }
    const special = await context({viewport:{width:390,height:360},reducedMotion:'reduce'});
    const p = await special.newPage();
    await p.goto(base+'/boat-fuel-calculator/',{waitUntil:'domcontentloaded'});
    let failed=true;
    await p.route('**/app/user-manual.cfm', route => failed ? route.fulfill({status:503,contentType:'text/plain',body:'Unavailable'}) : route.fulfill({contentType:'text/html',body:manualHtml}));
    await p.locator('.fpw-context-help').click();
    await p.waitForFunction(()=>!document.querySelector('[data-help-retry]').hidden);
    assert(p.url()===base+'/boat-fuel-calculator/','failure preserves page');
    assert(await p.locator('#fpwHelpDrawer').evaluate(n=>getComputedStyle(n).transitionDuration)==='0s','reduced motion');
    failed=false;await p.locator('[data-help-retry]').click();await ready(p,cases[6][1]);
    await p.keyboard.press('Escape');await closed(p);await p.unroute('**/app/user-manual.cfm');
    out.checks.push('Loading error, retry, reduced motion and short viewport');
    await p.reload({waitUntil:'domcontentloaded'});
    let release;
    const delayed=new Promise(resolve=>{release=resolve;});
    let requests=0;
    const fixtureHtml=manualHtml.replace('<div class="fpw-manual-chapter-body">','<div class="fpw-manual-chapter-body"><img alt="Drawer image fixture" src="../assets/press/logo.png" srcset="../assets/press/logo.png 1x"><a href="../help/">Related help fixture</a><script>window.drawerInjectedScript=true;</script>');
    await p.route('**/app/user-manual.cfm',async route=>{requests++;await delayed;await route.fulfill({contentType:'text/html',body:fixtureHtml});});
    await p.locator('.fpw-context-help').click();
    await p.waitForFunction(()=>document.querySelector('[data-help-status]').textContent.includes('Loading'));
    await p.keyboard.press('Escape');await closed(p);
    await p.locator('.fpw-context-help').click();release();await ready(p,cases[6][1]);
    assert(requests===1 && await p.locator('#fpwHelpDrawer').count()===1,'inflight reopen shares one request and one drawer');
    await p.locator('#fpwHelpDrawer .fpw-manual-back').click();await ready(p,'manualContents');
    await p.locator('#fpwHelpDrawer [href$="#'+cases[0][1]+'"]').click();await ready(p,cases[0][1]);
    await p.waitForFunction(()=>{const img=document.querySelector('#fpwHelpDrawer img');return img && img.complete && img.naturalWidth>0;});
    assert(await p.locator('#fpwHelpDrawer img').getAttribute('src')===base+'/assets/press/logo.png','relative image resolved against manual');
    assert(await p.locator('#fpwHelpDrawer img').getAttribute('srcset')===base+'/assets/press/logo.png 1x','relative srcset resolved');
    const other=p.locator('#fpwHelpDrawer a', {hasText:'Related help fixture'});
    assert(await other.getAttribute('href')===base+'/help/' && await other.getAttribute('target')==='_blank','other-page link keeps application loaded');
    assert(!await p.evaluate(()=>window.drawerInjectedScript),'documentation scripts are not executed');
    await p.locator('[data-help-close]').click();await closed(p);
    out.checks.push('Close/reopen during loading; relative image/srcset and link fixture; script exclusion');
    await special.close();
    const plain=await context({javaScriptEnabled:false});
    const nojs=await plain.newPage();await nojs.goto(base+'/boat-fuel-calculator/',{waitUntil:'domcontentloaded'});
    await nojs.locator('.fpw-context-help').click();await nojs.waitForURL(base+'/app/user-manual.cfm#'+cases[6][1]);
    out.checks.push('No-JavaScript original link fallback');await plain.close();
    out.unexpectedConsoleErrors=out.consoleErrors.filter(error=>!(
      (error.source===base+'/app/completed-trip.cfm' && error.message.includes('400')) ||
      (error.source===base+'/app/active-cruise.cfm?mode=preview' && error.message.includes('404'))
    ));
    assert(out.unexpectedConsoleErrors.length===0,'no unexpected console errors');
    assert(out.pageErrors.length===0,'no JavaScript page errors');
    out.success=true;
  } catch(error) {out.error=error.stack;out.success=false;}
  finally {
    for(const ctx of contexts) await ctx.close();
    if(created) out.cleanup=await (await fixtureContext.request.post(fixtureUrl,{data:{action:'cleanup',runId}})).json();
    await fixtureContext.close();
  }
  return out;
}
