// Run with Playwright MCP browser_run_code_unsafe.filename against a local /fpw/ page.
// Reuse the page's current anonymous or disposable-member session.
async (page) => {
  const base = 'http://localhost:8500/fpw';
  const assert = (ok, message) => { if (!ok) throw new Error(message); };
  const results = [];
  await page.goto(base + '/help/', {waitUntil:'domcontentloaded'});
  const member = await page.locator('[data-fpw-member-identity]').count() > 0;
  const audience = member ? 'member' : 'anonymous';
  for (const [width,height] of [[1920,1000],[1830,1000],[1536,950],[1441,900],[1440,1000],[1320,900],[1100,800],[1051,800],[1050,800],[390,844],[320,568],[1100,360],[390,360]]) {
    await page.setViewportSize({width,height});
    await page.goto(base + '/help/', {waitUntil:'domcontentloaded'});
    const mobile = width <= 1050;
    if (mobile) await page.locator('[data-fpw-mobile-toggle]').click();
    const toggle = page.locator('#fpwHelpToggle');
    const menu = page.locator('#fpwHelpMenu');
    if (mobile) await toggle.click();
    else {
      await page.mouse.move(width-10,height-10);
      await toggle.hover();
    }
    assert(await toggle.getAttribute('aria-expanded') === 'true', `${width}: expanded`);
    assert(await menu.isVisible(), `${width}: menu visible`);
    const box = await menu.boundingBox();
    assert(box.x >= -1 && box.x + box.width <= width + 1, `${width}: horizontal menu containment ${JSON.stringify(box)}`);
    if (!mobile) assert(box.y >= 0 && box.y+box.height <= height+1, `${width}: vertical menu containment ${JSON.stringify(box)}`);
    const labels = await page.locator('.fpw-primary-nav > .fpw-nav-link, .fpw-primary-nav > .fpw-dropdown > button').evaluateAll(nodes=>nodes.map(n=>{const r=n.getBoundingClientRect();return {text:n.innerText,x:r.x,right:r.right,y:r.y,width:r.width};}));
    assert(labels.every(x=>x.x>=0 && x.right<=width+1), `${width}: navigation labels visible`);
    if (!mobile) assert(labels.every((x,i)=>i===0 || x.x>=labels[i-1].right-1), `${width}: navigation overlap`);
    const links = menu.locator('[role=menuitem]');
    assert(await links.count()===6, 'Six destinations');
    assert(await links.last().locator('strong').innerText()==='User Manual', 'User Manual is last');
    assert((await links.last().getAttribute('href')).endsWith('/app/user-manual.cfm'), 'Existing User Manual destination');
    assert(!labels.some(x=>x.text==='How It Works'), 'How It Works removed from primary row');
    assert(await page.locator('#fpwResourcesMenu a[href$="/app/user-manual.cfm"]').count()===0, 'User Manual removed from Resources');
    let actionClearance = null;
    if (!mobile) {
      const actions = await page.locator('.fpw-nav-actions > a, .fpw-nav-actions > .fpw-dropdown > button').evaluateAll(ns=>ns.filter(n=>n.getClientRects().length).map(n=>n.getBoundingClientRect().x));
      actionClearance = Math.min(...actions) - Math.max(...labels.map(n=>n.right));
      if (!member) assert(actionClearance>=0, `${width}: primary navigation clear of Start Free`);
      await toggle.click();
      assert(await menu.isVisible(), `${width}: mouse click does not close hovered menu`);
      const trigger = await toggle.boundingBox();
      await page.mouse.move(trigger.x+trigger.width/2,trigger.y+trigger.height+8);
      await page.waitForTimeout(80);
      await page.mouse.move(trigger.x+trigger.width/2,box.y+8);
      await page.waitForTimeout(220);
      assert(await menu.isVisible(), `${width}: pointer can cross gap into panel`);
      await page.mouse.move(width-10,height-10);
      await page.waitForTimeout(220);
      assert(!(await menu.isVisible()) && await toggle.getAttribute('aria-expanded')==='false', `${width}: mouse leave closes menu`);
    }
    await toggle.focus();
    await page.keyboard.press('ArrowDown');
    assert(await links.nth(0).evaluate(n=>n===document.activeElement), `${width}: ArrowDown`);
    await page.keyboard.press('End');
    assert(await links.last().evaluate(n=>n===document.activeElement), `${width}: End`);
    await page.keyboard.press('Home');
    assert(await links.nth(0).evaluate(n=>n===document.activeElement), `${width}: Home`);
    await page.keyboard.press('ArrowUp');
    assert(await links.last().evaluate(n=>n===document.activeElement), `${width}: ArrowUp wraps`);
    await links.last().scrollIntoViewIfNeeded();
    const last = await links.last().boundingBox();
    assert(last.y>=0 && last.y+last.height<=height+1, `${width}: last link reachable`);
    await page.keyboard.press('Escape');
    assert(!(await menu.isVisible()) && await toggle.evaluate(n=>n===document.activeElement), `${width}: Escape focus restored`);
    await page.keyboard.press('Space');
    assert(await menu.isVisible(), `${width}: Space activation`);
    await page.keyboard.press('Enter');
    assert(!(await menu.isVisible()), `${width}: Enter toggle`);
    if (mobile) await toggle.click();
    else {
      await page.mouse.move(width-10,height-10);
      await toggle.hover();
    }
    if (mobile) {
      assert(await page.evaluate(()=>document.body.style.overflow)==='hidden', `${width}: body scroll locked`);
      await page.locator('[data-fpw-mobile-close]').click();
      assert(!(await menu.isVisible()), `${width}: drawer closes Help`);
      assert(await page.evaluate(()=>document.body.style.overflow)!=='hidden', `${width}: body scroll restored`);
    } else {
      await page.mouse.click(width-10,height-10);
      assert(!(await menu.isVisible()), `${width}: outside click`);
      const resources = page.locator('[aria-controls=fpwResourcesMenu]');
      await resources.hover();
      assert(await resources.getAttribute('aria-expanded')==='true', `${width}: Resources hover retained`);
      await page.mouse.move(width-10,height-10);
      await toggle.focus();
      assert(!(await menu.isVisible()), `${width}: Help focus does not auto-open`);
    }
    if (mobile) await page.locator('[data-fpw-mobile-toggle]').click();
    if (mobile) await toggle.click();
    else {
      await page.mouse.move(width-10,height-10);
      await toggle.hover();
    }
    if ([1920,1440,390,320].includes(width) && height>500) {
      await menu.locator('a').first().scrollIntoViewIfNeeded();
      await page.screenshot({path:`output/playwright/global-help/${audience}-${width}.png`});
    }
    results.push({audience,width,height,keyboard:true,containment:true,scrolling:true,actionClearance});
  }
  await page.setViewportSize({width:1440,height:1000});
  await page.goto(base+'/help/');
  assert(await page.locator('.fpw-help-topic').count()===9, 'Nine categories');
  assert(await page.locator('link[rel=canonical]').getAttribute('href')==='https://floatplanwizard.com/help/', 'Canonical');
  const search=page.locator('[data-help-search]');
  await search.fill('boat loan');
  assert(await page.locator('#calculators-and-tools').isVisible(), 'Category link search');
  await search.fill('no-such-help-topic-93481');
  assert(await page.locator('[data-help-empty]').isVisible(), 'No results');
  await page.locator('[data-help-search-clear]').click();
  assert(await page.locator('[data-help-section]:visible').count()===await page.locator('[data-help-section]').count(), 'Clear restores topics');
  await page.screenshot({path:`output/playwright/global-help/${audience}-directory.png`});
  return {audience,viewports:results,search:true};
}
