const {test,expect,chromium,firefox,webkit}=require('@playwright/test');
const fs=require('node:fs');
const path=require('node:path');
const E=require('../assets/js/boat-cost-engine.js');
const S=require('../assets/js/boat-cost-state.js');
const base=process.env.FPW_BASE_URL || 'http://127.0.0.1:8500/fpw';
const url=base+'/boat-loan-calculator/';
const output=path.join(__dirname,'../output/playwright/boat-cost');
async function example(page,key='B') {await page.locator(`[data-boat-cost-example="${key}"]`).click();await expect(page.locator('#bc-results .bc-hero-value')).toBeVisible();}
async function importScenario(page,s) {const shared=S.share(s);expect(shared.ok).toBe(true);await page.goto(url+new URL(shared.url).hash);await expect(page.locator('#bc-results')).toContainText('Your boating budget');}
const f=value=>({value,status:'entered'});
function reverse(cash=false){const s=E.example('B');s.direction='budget';s.origin='user';s.budget.monthly=f(1000);s.budget.cash=f(cash?25000:10000);s.purchase.method=cash?'cash':'financed';s.purchase.down.input=f(10000);s.purchase.rate=f(0);s.purchase.term=f(120);s.purchase.tax={mode:cash?'percent':'amount',input:f(cash?6:0),treatment:'cash'};s.purchase.fees.forEach(r=>r.input=f(0));s.operating.fuel.mode='annual';s.operating.fuel.annual=f(6000);s.operating.storage.total=f(0);['insurance','maintenance','registration','seasonal'].forEach(k=>s.operating[k]=f(0));s.preparation.mode='total';s.preparation.total=f(cash?1000:0);s.reserves.initial=f(cash?2000:0);s.reserves.annual=f(1200);return s;}

test.beforeEach(async({page})=>{await page.route('https://plausible.io/**',r=>r.abort());});
test('empty financial state, static content, partial estimates and linked errors',async({page})=>{
 const errors=[];page.on('pageerror',e=>errors.push(e.message));
 await page.goto(url);await expect(page.locator('#bc-results')).toContainText('No estimate has been calculated');await expect(page.locator('#bc-purchase-price')).toHaveValue('');
 await page.locator('#bc-purchase-price').fill('12000');await page.locator('#bc-purchase-down-input').fill('0');await page.locator('#bc-purchase-rate').fill('0');await page.locator('#bc-purchase-term').fill('12');
 await page.getByRole('button',{name:'Calculate my boating budget',exact:true}).click();
 await expect(page.locator('#bc-results')).toContainText('Known monthly costs so far');await expect(page.locator('#bc-results')).toContainText('$1,000.00');await expect(page.locator('#bc-results')).toContainText('incomplete');
 await page.locator('#bc-purchase-price').fill('-2');await page.getByRole('button',{name:'Calculate my boating budget',exact:true}).click();
 await expect(page.locator('.bc-errors')).toBeFocused();await page.locator('.bc-errors a').first().click();await expect(page.locator('#bc-purchase-price')).toBeFocused();expect(errors).toEqual([]);
});

test('examples, detailed preservation, stale output, and independently edited three-scenario comparison',async({page})=>{
 const errors=[];page.on('pageerror',e=>errors.push(e.message));page.on('dialog',d=>d.accept());await page.goto(url);await example(page);
 await expect(page.locator('#bc-results .bc-hero-value')).toHaveText('$1,418.64');await expect(page.locator('#bc-results')).toContainText('$34,023.72');await expect(page.locator('#bc-operating-fuel-hours')).toHaveCount(0);await expect(page.getByRole('button',{name:'Edit fuel details',exact:true})).toBeVisible();
 await page.locator('#bc-view').selectOption('detailed');await expect(page.locator('#bc-preparation-rows-0-input')).toHaveValue('600');await page.locator('#bc-view').selectOption('quick');await expect(page.locator('#bc-results .bc-hero-value')).toHaveText('$1,418.64');
 await page.locator('#bc-purchase-price').fill('invalid');await expect(page.locator('#bc-results')).toContainText('Needs recalculation');await expect(page.getByRole('button',{name:'Print or save as PDF',exact:true})).toBeDisabled();
 await page.locator('#bc-purchase-price').fill('50000');await expect(page.locator('#bc-results .bc-warning').filter({hasText:'Needs recalculation'})).toHaveCount(0);
 await page.getByRole('button',{name:'Duplicate scenario',exact:true}).click();await page.locator('#bc-purchase-price').fill('60000');await expect(page.locator('#bc-results .bc-hero-value')).not.toHaveText('$1,418.64');
 await page.getByRole('button',{name:'Compare scenarios',exact:true}).click();await expect(page.locator('.bc-comparison')).toContainText('vs baseline');
 await page.locator('#bc-active-scenario').selectOption('0');await expect(page.locator('#bc-purchase-price')).toHaveValue('50000');
 await page.getByRole('button',{name:'Duplicate scenario',exact:true}).click();await expect(page.getByRole('button',{name:'Duplicate scenario',exact:true})).toBeDisabled();
 await page.locator('#bc-purchase-price').fill('bad');await page.getByRole('button',{name:'Calculate my boating budget',exact:true}).click();await expect(page.locator('.bc-comparison')).toContainText('Incomplete');
 await page.getByRole('button',{name:'Remove scenario',exact:true}).click();await expect(page.locator('#bc-active-scenario option')).toHaveCount(2);expect(errors).toEqual([]);
});

test('reverse financing and cash constraints, infeasibility and share import',async({page})=>{
 page.on('dialog',d=>d.accept());
 await importScenario(page,reverse());await expect(page.locator('#bc-results')).toContainText('$58,000.00');await expect(page.locator('#bc-results .bc-hero-value')).toHaveText('$1,000.00');expect(new URL(page.url()).hash).toBe('');
 await page.locator('#bc-budget-cash').fill('5000');await page.getByRole('button',{name:'Calculate my boating budget',exact:true}).click();await expect(page.locator('#bc-results')).toContainText('cash');await expect(page.locator('#bc-results')).toContainText('$5,000.00');
 await importScenario(page,reverse(true));await expect(page.locator('#bc-results')).toContainText('$20,754.72');await expect(page.locator('#bc-results')).toContainText('$25,000.00');await expect(page.locator('#bc-results .bc-hero-value')).toHaveText('$600.00');await expect(page.locator('.bc-print-only.bc-assumptions')).toContainText('budget direction');await expect(page.locator('.bc-print-only.bc-assumptions')).toContainText('Monthly spending limit: 1000 USD');await expect(page.locator('.bc-print-only.bc-assumptions')).toContainText('Available upfront cash: 25000 USD');
});

test('explicit save, reload restore, feature-only deletion, and unavailable storage',async({page})=>{
 page.on('dialog',d=>d.accept());await page.goto(url);await example(page,'H');expect(await page.evaluate(()=>localStorage.getItem('fpw.boatCost.v1'))).toBeNull();
 await page.getByRole('button',{name:'Save in this browser',exact:true}).click();await page.reload();await expect(page.locator('#bc-purchase-price')).toHaveValue('');await page.getByRole('button',{name:'Restore saved estimates',exact:true}).click();await expect(page.locator('#bc-results .bc-hero-value')).toHaveText('$730.16');
 await page.evaluate(()=>localStorage.setItem('unrelated-qa','keep'));await page.getByRole('button',{name:'Delete saved estimates',exact:true}).click();expect(await page.evaluate(()=>localStorage.getItem('unrelated-qa'))).toBe('keep');
 await page.evaluate(()=>{Storage.prototype.setItem=function(){throw new Error('blocked');};});await page.getByRole('button',{name:'Save in this browser',exact:true}).click();await expect(page.locator('.bc-live')).toContainText('blocked or full');await expect(page.locator('#bc-results .bc-hero-value')).toHaveText('$730.16');
});

test('no JavaScript retains educational content without fabricated results',async({browser})=>{
 const context=await browser.newContext({javaScriptEnabled:false});const page=await context.newPage();await page.goto(url);await expect(page.locator('.bc-notice')).toContainText('requires JavaScript');await expect(page.locator('#bc-worked-examples')).toBeVisible();expect(await page.locator('[data-example-output="B.monthlyBudget"]').innerText()).toBe('$1,418.64');await expect(page.locator('#boat-cost-app')).toBeEmpty();await context.close();
});

for (const [name,type] of [['Chromium',chromium],['Firefox',firefox],['WebKit',webkit]]) test(`${name}: 320px, keyboard labels, 200% equivalent viewport reflow and calculation`,async()=>{
 const browser=await type.launch();const page=await browser.newPage({viewport:{width:1440,height:1000}});const errors=[];page.on('pageerror',e=>errors.push(e.message));await page.route('https://plausible.io/**',r=>r.abort());await page.goto(url);await example(page);
 await expect(page.locator('#bc-results .bc-hero-value')).toHaveText('$1,418.64');await page.locator('#bc-view').focus();await page.locator('#bc-view').selectOption('detailed');await expect(page.locator('#bc-view')).toBeFocused();
 const unlabeled=await page.locator('#boat-cost-app input,#boat-cost-app select').evaluateAll(nodes=>nodes.filter(n=>!n.labels.length&&!n.getAttribute('aria-label')&&!n.getAttribute('aria-labelledby')).map(n=>n.id));expect(unlabeled).toEqual([]);
 await page.locator('#bc-purchase-price').focus();await page.keyboard.press('Tab');expect(await page.evaluate(()=>document.activeElement.id)).not.toBe('bc-purchase-price');
 await page.setViewportSize({width:320,height:900});expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1)).toBe(true);
 await page.setViewportSize({width:720,height:500});expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1)).toBe(true);
 expect(errors).toEqual([]);await browser.close();
});

test('desktop, mobile and print review artifacts',async({page})=>{
 fs.mkdirSync(output,{recursive:true});await page.setViewportSize({width:1440,height:1000});await page.goto(url);await example(page);await page.evaluate(()=>scrollTo(0,0));await page.screenshot({path:path.join(output,'desktop.png'),fullPage:false});
 await page.setViewportSize({width:320,height:900});await page.locator('#bc-results .bc-hero-value').evaluate(n=>scrollTo(0,n.getBoundingClientRect().top+scrollY-190));await page.screenshot({path:path.join(output,'mobile.png')});
 await page.setViewportSize({width:1000,height:1200});await page.evaluate(()=>window.dispatchEvent(new Event('beforeprint')));await page.emulateMedia({media:'print'});
 await expect(page.locator('.bc-education')).toBeHidden();await expect(page.locator('.bc-form')).toBeHidden();await expect(page.locator('#bc-results')).toContainText('$1,418.64');
 await page.screenshot({path:path.join(output,'print.png'),fullPage:true});await page.pdf({path:path.join(output,'print-letter.pdf'),format:'Letter',printBackground:true});await page.pdf({path:path.join(output,'print-a4.pdf'),format:'A4',printBackground:true});
});

test('basis replacement requires confirmation and quick-detail switches retain figures',async({page})=>{
 await page.goto(url);await example(page);
 page.once('dialog',d=>d.dismiss());await page.locator('#bc-purchase-down-mode').selectOption('percent');await expect(page.locator('#bc-purchase-down-mode')).toHaveValue('amount');await expect(page.locator('#bc-purchase-down-input')).toHaveValue('10000');
 page.once('dialog',d=>d.dismiss());await page.getByRole('button',{name:'Replace fuel with annual total',exact:true}).click();await expect(page.getByRole('button',{name:'Edit fuel details',exact:true})).toBeVisible();
 await page.getByRole('button',{name:'Edit fuel details',exact:true}).click();await expect(page.locator('#bc-operating-fuel-hours')).toHaveValue('100');await expect(page.locator('#bc-operating-fuel-gph')).toHaveValue('8');
 await page.locator('#bc-view').selectOption('quick');page.once('dialog',d=>d.accept());await page.locator('#bc-purchase-down-mode').selectOption('percent');await expect(page.locator('#bc-purchase-down-input')).toHaveValue('');await expect(page.locator('#bc-results')).toContainText('Needs recalculation');
});

test('missing acquisition assumptions stale an existing result and native print hides old figures',async({page})=>{
 await page.goto(url);await example(page);await page.locator('#bc-purchase-tax-input').fill('');await expect(page.locator('#bc-results')).toContainText('Needs recalculation');await page.waitForTimeout(400);await expect(page.getByRole('button',{name:'Share active scenario',exact:true})).toBeDisabled();
 await page.evaluate(()=>window.dispatchEvent(new Event('beforeprint')));await expect(page.locator('#bc-results')).not.toContainText('$1,418.64');await expect(page.locator('#bc-results')).toContainText('Estimate needs calculation');await page.evaluate(()=>window.dispatchEvent(new Event('afterprint')));await expect(page.locator('#bc-results')).toContainText('Needs recalculation');
});
