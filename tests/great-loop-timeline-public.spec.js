const {test,expect}=require('@playwright/test');
const base=(process.env.FPW_BASE_URL||'http://127.0.0.1:8500/fpw').replace(/\/$/,'');
const route='/fpw_great_loop_clockwise/';
test.use({timezoneId:'America/New_York'});
for(const width of [1440,1100,768,390]) test('public canonical timeline and controls at '+width+'px',async({page})=>{
  const errors=[];page.on('pageerror',e=>errors.push(e.message));
  await page.setViewportSize({width,height:1000});
  await page.clock.install({time:new Date('2026-10-29T11:46:00-04:00')});
  await page.goto(base+route);
  const timeline=page.locator('#loopCruiseTimeline');
  await expect(page.locator('#loopTimelineLegs .fpw-routegen__leg')).toHaveCount(56);
  await expect(page.locator('#loopTimelineDeparture')).toHaveValue('2026-10-29T12:00');
  await expect(page.locator('#loopTimelineSummary')).toContainText('Fuel n/a');
  expect(await page.locator('#loopTimelineHeading').evaluate(el=>{
    const text=document.createRange();text.selectNodeContents(el);
    const bounds=text.getBoundingClientRect();const container=el.parentElement.getBoundingClientRect();
    return bounds.left>=container.left-1&&bounds.right<=container.right+1;
  })).toBe(true);
  await expect(page.locator('#loopTimelineLegs')).toContainText('Chicago Harbor Lock');
  await expect(page.locator('#loopTimelineLegs')).toContainText('Day Rollup');
  await expect(page.locator('#loopTimelineLegs')).toContainText('Required: Unavailable');
  await page.clock.setFixedTime(new Date('2026-10-30T14:00:00-04:00'));
  await page.locator('#loopTimelineLegs .fpw-routegen__leg[data-leg-order="2"]').click();
  await expect(page.locator('#loopTimelineLegs .fpw-routegen__leg[data-leg-order="2"]')).toHaveAttribute('aria-expanded','true');
  await expect(page.locator('#loopTimelineDeparture')).toHaveValue('2026-10-29T12:00');
  await page.locator('.loop-planning-inputs > summary').click();
  await page.locator('[name=fuel_burn_gph]').fill('12');
  await page.locator('[name=fuel_burn_gph]').press('Tab');
  await expect(page.locator('#loopTimelineStatus')).toHaveText('Timeline updated.');
  await expect(page.locator('#loopTimelineLegs [data-testid=required-fuel]').first()).toContainText('gal');
  await expect(page.locator('#loopTimelineLegs .fpw-routegen__leg[data-leg-order="2"]')).toHaveClass(/is-selected/);
  await page.locator('#loopTimelineDeparture').fill('2026-12-31T18:00');
  await page.locator('#loopTimelineDeparture').press('Tab');
  await expect(timeline).not.toHaveAttribute('aria-busy','true');
  await expect(page.locator('#loopTimelineDeparture')).toHaveValue('2026-12-31T18:00');
  await page.locator('#loopTimelineLegs .fpw-routegen__leg[data-leg-order="1"]').focus();
  await page.keyboard.press('Enter');
  await expect(page.locator('#loopTimelineLegs')).toContainText('Day 1 - 2026-12-31');
  await expect(page.locator('#loopTimelineDeparture')).toHaveValue('2026-12-31T18:00');
  await expect(page.locator('.sections, .legCard')).toHaveCount(0);
  await expect(page.locator('link[rel=canonical]')).toHaveAttribute('href','https://floatplanwizard.com'+route);
  expect(await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth)).toBe(false);
  expect(errors).toEqual([]);
});
test('public planning endpoint only accepts read-only planning inputs',async({request})=>{
  const url=base+route+'timeline.cfm';
  expect((await request.get(url)).status()).toBe(405);
  for(const body of [
    {action:'timeline',startDate:'2026-10-29',routeId:1},
    {action:'timeline',startDate:'2026-10-29',inputs:{userId:1}},
    {action:'timeline',startDate:'2026-10-29',inputs:{cruising_speed:-5}},
    {action:'locks',legOrder:99999}
  ]) expect((await request.post(url,{data:body})).status()).toBe(400);
  const response=await request.post(url,{data:{action:'timeline',startDate:'2026-10-29'}});
  expect(response.status()).toBe(200);expect(response.headers()['x-robots-tag']).toContain('noindex');
  const data=await response.json();expect(data.success).toBe(true);expect(data.legs).toHaveLength(56);
  expect(data.timeline.timeline_meta.distance_source).toBe('active_template');
});
test('initial defaults cannot overwrite edits and lazy lock loading retains keyboard focus',async({page})=>{
  let release;
  let first=true;
  await page.route('**/fpw_great_loop_clockwise/timeline.cfm',async route=>{
    if(first&&route.request().postDataJSON().action==='timeline'){
      first=false;
      await new Promise(resolve=>{release=resolve;});
    }
    await route.continue();
  });
  await page.goto(base+route,{waitUntil:'domcontentloaded'});
  try{
    await expect.poll(()=>typeof release).toBe('function');
    await expect(page.locator('#loopTimelineDeparture')).toBeDisabled();
    await expect(page.locator('[name=cruising_speed]')).toBeDisabled();
  }finally{if(release)release();}
  await expect(page.locator('#loopTimelineLegs .fpw-routegen__leg')).toHaveCount(56);
  await expect(page.locator('#loopTimelineDeparture')).toBeEnabled();
  const second=page.locator('#loopTimelineLegs .fpw-routegen__leg[data-leg-order="2"]');
  await second.focus();await page.keyboard.press('Enter');
  await expect(page.locator('.fpw-routegen__leglockpanel[data-leg-order="2"] .fpw-routegen__lockchip').first()).toBeVisible();
  await expect(second).toBeFocused();
});
test('a failed recalculation hides stale dates and retains the chosen departure for retry',async({page})=>{
  await page.goto(base+route);
  await expect(page.locator('#loopTimelineLegs .fpw-routegen__leg')).toHaveCount(56);
  await page.route('**/fpw_great_loop_clockwise/timeline.cfm',async route=>{
    if(route.request().postDataJSON().action==='timeline')await route.fulfill({status:503,contentType:'application/json',body:JSON.stringify({success:false,message:'The cruise timeline is temporarily unavailable.'})});
    else await route.continue();
  });
  await page.locator('#loopTimelineDeparture').fill('2027-01-01T09:00');
  await page.locator('#loopTimelineDeparture').press('Tab');
  await expect(page.locator('#loopTimelineTable')).toBeHidden();
  await expect(page.locator('#loopTimelineStatus')).toContainText('temporarily unavailable');
  await expect(page.locator('#loopTimelineDeparture')).toHaveValue('2027-01-01T09:00');
  await page.unroute('**/fpw_great_loop_clockwise/timeline.cfm');
  await page.locator('#loopTimelineForm [type=submit]').click();
  await expect(page.locator('#loopTimelineTable')).toBeVisible();
  await expect(page.locator('#loopTimelineLegs')).toContainText('Day 1 - 2027-01-01');
});
