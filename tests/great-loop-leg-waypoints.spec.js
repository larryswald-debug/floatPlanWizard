const { test, expect } = require('@playwright/test');
const path = require('node:path');
const fs = require('node:fs');

// UI fault tests explicitly replace auth/save responses. The integration group
// below exercises the real endpoint with fresh, local-only disposable members.
const base = 'http://localhost:8500/fpw';
const directory = base + '/fpw_great_loop_clockwise/';
const endpoint = base + '/api/v1/waypoint.cfc?method=handle&returnFormat=json';
const csrf = 'a'.repeat(64);
const value = (object, key) => object && (object[key] ?? object[key.toUpperCase()] ?? object[key.toLowerCase()]);
const panel = (page, order) => page.locator('.fpw-routegen__leglockpanel[data-leg-order="' + order + '"]');
const button = (page, order) => panel(page, order).locator('[data-leg-action="save-waypoints"]');
const status = (page, order) => panel(page, order).locator('#loopWaypointStatus');
const row = (page, order) => page.locator('#loopTimelineLegs .fpw-routegen__leg[data-leg-order="' + order + '"]');

async function expand(page, order) {
  if ((await row(page, order).getAttribute('aria-expanded')) !== 'true') await row(page, order).click();
  await expect(button(page, order)).toBeVisible();
}
async function open(page) {
  await page.goto(directory);
  await expect(page.locator('#loopTimelineLegs .fpw-routegen__leg')).toHaveCount(56);
  await expect(button(page, 1)).toBeVisible();
}
async function mockAuth(page, authenticated = true) {
  await page.route('**/api/v1/auth.cfc?method=bootstrap*', route => route.fulfill({
    status: 200, contentType: 'application/json',
    body: JSON.stringify({ SUCCESS: true, AUTH: authenticated, CSRF_TOKEN: csrf })
  }));
}
async function captureEvents(page) {
  await page.addInitScript(() => {
    window.legWaypointEvents = [];
    window.FPWAnalytics = { track: (name, fields) => window.legWaypointEvents.push({ name, fields }) };
  });
}
function success(names, added = 2, existing = 0) {
  return { SUCCESS: true, AUTH: true, RESULT: existing === 2 ? 'already_saved' : 'saved',
    ADDED_COUNT: added, EXISTING_COUNT: existing,
    MESSAGE: existing === 2 ? 'Both locations are already in My Waypoints.' : names.join(' and ') + ' have been added to My Waypoints. You can now use them when building your route.',
    ENDPOINTS: names.map((name, index) => ({ NAME: name, STATUS: index < added ? 'added' : 'existing', WAYPOINTID: index + 1 })) };
}

test.describe('leg waypoint feedback with controlled UI responses', () => {
  for (const width of [1440, 390]) test('anonymous explanation does not save at ' + width + 'px', async ({ page }) => {
    await page.setViewportSize({ width, height: width === 390 ? 844 : 960 });
    await mockAuth(page, false);
    let writes = 0;
    await page.route('**/api/v1/waypoint.cfc*', route => { writes++; return route.abort(); });
    await open(page);
    const originalUrl = page.url();
    await button(page, 1).focus();
    await page.keyboard.press('Enter');
    const dialog = page.locator('#loopWaypointAuthDialog');
    await expect(dialog).toBeVisible();
    await expect(dialog).toContainText('Sign In to Save Waypoints');
    await expect(dialog).toContainText('Create a free FloatPlanWizard account or sign in');
    await expect(dialog.getByRole('link', { name: 'Sign In', exact: true })).toHaveAttribute('href', '/fpw/app/login.cfm');
    await expect(dialog.getByRole('link', { name: 'Start Free', exact: true })).toHaveAttribute('href', '/fpw/app/join.cfm');
    expect(page.url()).toBe(originalUrl);
    expect(writes).toBe(0);
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
    await page.keyboard.press('Escape');
    await expect(dialog).toBeHidden();
    await expect(button(page, 1)).toBeFocused();
    await expect(button(page, 1)).toBeEnabled();
  });

  test('pending state prevents repeated submission and stays with the correct leg across redraws', async ({ page }) => {
    await mockAuth(page);
    await captureEvents(page);
    const calls = [], pending = new Map();
    await page.route('**/api/v1/waypoint.cfc*', async route => {
      const body = route.request().postDataJSON();
      calls.push({ body, token: route.request().headers()['x-csrf-token'] });
      await new Promise(resolve => pending.set(body.legOrder, resolve));
      await route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify(success(body.legOrder === 3 ? ['Ottawa', 'Peoria'] : ['Peoria', 'Grafton'])) });
    });
    await open(page);
    await expand(page, 3);
    await button(page, 3).click();
    await expect.poll(() => calls.length).toBe(1);
    await expect(button(page, 3)).toBeDisabled();
    await button(page, 3).evaluate(element => { element.click(); element.click(); });
    expect(calls).toHaveLength(1);
    await expect(button(page, 3)).toHaveText('Adding Waypoints…');
    await expand(page, 4);
    await expect(button(page, 4)).toBeEnabled();
    await button(page, 4).click();
    await expect.poll(() => calls.length).toBe(2);
    pending.get(3)();
    await expect(button(page, 4)).toHaveText('Adding Waypoints…');
    expect(await status(page, 4).textContent()).not.toContain('Ottawa');
    pending.get(4)();
    await expect(status(page, 4)).toContainText('Peoria and Grafton');
    await expand(page, 3);
    await expect(status(page, 3)).toContainText('Ottawa and Peoria');
    await expect(button(page, 3)).toHaveText('Waypoints Added');
    await expect(button(page, 3)).toBeEnabled();
    await page.getByRole('button', { name: 'Recalculate timeline' }).click();
    await expect(page.locator('#loopCruiseTimeline')).not.toHaveAttribute('aria-busy', 'true');
    await expect(status(page, 3)).toContainText('Ottawa and Peoria');
    expect(calls.map(call => call.body.legOrder)).toEqual([3, 4]);
    for (const call of calls) {
      expect(Object.keys(call.body).sort()).toEqual(['action', 'legOrder', 'segmentId', 'templateCode']);
      expect(call.body.action).toBe('savelegstops');
      expect(call.body.segmentId).toBeGreaterThan(0);
      expect(call.token).toBe(csrf);
    }
    const events = await page.evaluate(() => window.legWaypointEvents.filter(event => event.name === 'great_loop_leg_waypoints_saved'));
    expect(events).toHaveLength(2);
    expect(JSON.stringify(events)).not.toMatch(/latitude|longitude|email|userid/i);
  });

  test('a failed save can be safely retried and only backend confirmation counts as saved', async ({ page }) => {
    await mockAuth(page);
    await captureEvents(page);
    let writes = 0;
    await page.route('**/api/v1/waypoint.cfc*', route => {
      writes++;
      return route.fulfill({ status: writes === 1 ? 503 : 200, contentType: 'application/json',
        body: JSON.stringify(writes === 1 ? { SUCCESS: false, AUTH: true, RESULT: 'failed', MESSAGE: 'Unable to save these stops. Please try again.' } : success(['Ottawa', 'Peoria'])) });
    });
    await open(page); await expand(page, 3); await button(page, 3).click();
    await expect(status(page, 3)).toContainText(/try again/i);
    await expect(button(page, 3)).toBeEnabled();
    expect(await page.evaluate(() => window.legWaypointEvents.filter(event => event.name === 'great_loop_leg_waypoints_saved').map(event => event.fields.result_status))).toEqual(['failed']);
    await button(page, 3).click();
    await expect(button(page, 3)).toHaveText('Waypoints Added');
    expect(writes).toBe(2);
    expect(await page.evaluate(() => window.legWaypointEvents.filter(event => event.name === 'great_loop_leg_waypoints_saved').map(event => event.fields.result_status))).toEqual(['failed', 'saved']);
  });

  test('an expired session during the write explains sign-in and never shows success', async ({ page }) => {
    await mockAuth(page);
    await page.route('**/api/v1/waypoint.cfc*', route => route.fulfill({status:401, contentType:'application/json', body:JSON.stringify({SUCCESS:false,AUTH:false,ERROR:'NOT_LOGGED_IN',MESSAGE:'Sign in again to save these stops.'})}));
    await open(page); await button(page, 1).click();
    await expect(page.locator('#loopWaypointAuthDialog')).toBeVisible();
    await expect(button(page, 1)).not.toHaveText('Waypoints Added');
    await page.keyboard.press('Escape');
    await expect(button(page, 1)).toBeEnabled();
  });

  test('partial backend failure reports the actual result and leaves retry available', async ({ page }) => {
    await mockAuth(page);
    await page.route('**/api/v1/waypoint.cfc*', route => route.fulfill({status:500, contentType:'application/json', body:JSON.stringify({SUCCESS:false,AUTH:true,RESULT:'partial',ADDED_COUNT:1,EXISTING_COUNT:0,ENDPOINTS:[{NAME:'Ottawa',STATUS:'added'},{NAME:'Peoria',STATUS:'failed'}],MESSAGE:'Ottawa was added. Peoria could not be saved. Please try again.'})}));
    await open(page); await expand(page, 3); await button(page, 3).click();
    await expect(status(page, 3)).toContainText('Ottawa was added. Peoria could not be saved.');
    await expect(button(page, 3)).toBeEnabled();
    await expect(button(page, 3)).not.toHaveText('Waypoints Added');
  });
});

test.describe('real local waypoint persistence', () => {
  test.describe.configure({ mode: 'serial' });
  test.setTimeout(60000);
  let fixture, template, routesBefore;
  const parity = [];
  const fixtureBase = base + '/tests/great-loop-leg-waypoint-fixture.cfm?confirm=RUN_GREAT_LOOP_LEG_WAYPOINT_TESTS';
  const owner = () => value(value(fixture, 'members'), 'owner');
  const other = () => value(value(fixture, 'members'), 'other');
  const headers = () => ({ 'X-FPW-Leg-Test-Token': value(fixture, 'token') });
  function fixtureUrl(action) {
    return fixtureBase + '&action=' + action + (fixture ? '&run=' + value(fixture, 'run') : '');
  }
  async function command(request, action) {
    const response = await request.post(fixtureUrl(action), { headers: fixture ? headers() : {}, data: {} });
    const data = await response.json();
    expect(response.status(), JSON.stringify(data)).toBe(200);
    expect(value(data, 'success'), JSON.stringify(data)).toBe(true);
    return data;
  }
  async function login(request, member = owner()) {
    const boot = await (await request.get(base + '/api/v1/auth.cfc?method=bootstrap')).json();
    const result = await (await request.post(base + '/api/v1/auth.cfc?method=handle', {
      headers: { 'X-CSRF-Token': value(boot, 'csrf_token') },
      data: { action: 'login', email: value(member, 'email'), password: value(fixture, 'password') }
    })).json();
    expect(value(result, 'success'), JSON.stringify(result)).toBe(true);
    expect(value(result, 'auth')).toBe(true);
    return value(result, 'csrf_token');
  }
  function payload(order) {
    const leg = value(template, 'legs').find(item => Number(value(item, 'order_index')) === order);
    return { action: 'savelegstops', templateCode: value(template, 'template_code'), legOrder: order, segmentId: Number(value(leg, 'segment_id')) };
  }
  async function save(request, order, token, extra = {}) {
    const response = await request.post(endpoint, { headers: { 'X-CSRF-Token': token }, data: { ...payload(order), ...extra } });
    return { status: response.status(), data: await response.json() };
  }
  async function points(request) {
    const response = await request.get(base + '/api/v1/waypoints.cfc?method=handle&returnFormat=json');
    const data = await response.json();
    expect(value(data, 'success'), JSON.stringify(data)).toBe(true);
    return value(data, 'waypoints');
  }
  async function remove(request, id) {
    const data = await (await request.post(endpoint, { data: { action: 'delete', waypointId: id } })).json();
    expect(value(data, 'success'), JSON.stringify(data)).toBe(true);
  }
  function counts(result, added, existing) {
    expect(value(result.data, 'success'), JSON.stringify(result)).toBe(true);
    expect(value(result.data, 'added_count')).toBe(added);
    expect(value(result.data, 'existing_count')).toBe(existing);
  }
  test.beforeAll(async ({ request }) => {
    fixture = await command(request, 'create');
    template = await (await request.post(directory + 'timeline.cfm', { data: { action: 'timeline', startDate: '2026-11-04' } })).json();
    expect(value(template, 'success')).toBe(true);
  });
  test.beforeEach(async ({ request }) => {
    await command(request, 'reset');
    routesBefore = value(await command(request, 'state'), 'routes');
  });
  test.afterEach(async ({ request }, testInfo) => {
    const routesAfter=value(await command(request,'state'),'routes');
    parity.push({test:testInfo.title,before:routesBefore,after:routesAfter,unchanged:JSON.stringify(routesBefore)===JSON.stringify(routesAfter)});
    expect(routesAfter).toEqual(routesBefore);
  });
  test.afterAll(async ({ request }) => {
    if (fixture) {
      const cleaned=await command(request,'cleanup');
      expect(value(cleaned,'remainingUsers')).toBe(0);
      if(process.env.FPW_LEG_WAYPOINT_REVIEW_DIR) fs.writeFileSync(path.join(process.env.FPW_LEG_WAYPOINT_REVIEW_DIR,'real-waypoint-parity.json'),JSON.stringify({tests:parity,cleanup:{success:value(cleaned,'success'),remainingUsers:value(cleaned,'remainingUsers')}},null,2));
    }
  });

  test('member saves both authoritative endpoints through the real button and safe replay', async ({ page, request }) => {
    await login(page.request);
    // Disposable setup is intentionally created before the no-route-change
    // baseline. Selecting picker values later must not save or alter this route.
    const vessel=await (await page.request.post(base+'/api/v1/vessel.cfc?method=handle',{data:{action:'save',vessel:{
      VESSELID:0,VESSELNAME:'Leg waypoint disposable vessel',TYPE:'Power',LENGTH:'24',
      MAX_SPEED:'20',MOST_EFFICIENT_SPEED:'12',GALLONS_PER_HOUR:'4',GPH_AT_MAX_SPEED:'7',
      FUEL_CAPACITY:'60',ISDEFAULTVESSEL:1,MAKE:'Test',MODEL:'Canonical',COLOR:'White'
    }}})).json();
    expect(value(vessel,'success'),JSON.stringify(vessel)).toBe(true);
    for(const [family,data] of [
      ['contact',{contact:{CONTACTID:0,CONTACTNAME:'Disposable shore contact',PHONE:'(727) 555-0123',EMAIL:value(owner(),'email')}}],
      ['operator',{operator:{OPERATORID:0,OPERATORNAME:'Disposable operator',PHONE:'',NOTES:''}}]
    ]) {
      const created=await (await page.request.post(base+'/api/v1/'+family+'.cfc?method=handle',{data:{action:'save',...data}})).json();
      expect(value(created,'success'),JSON.stringify(created)).toBe(true);
    }
    const createdRoute=await (await page.request.post(base+'/api/v1/routeBuilder.cfc?method=handle&action=createUserRoute',{data:{route_name:'Disposable leg waypoint selection'}})).json();
    expect(value(createdRoute,'success'),JSON.stringify(createdRoute)).toBe(true);
    const routeId=Number(value(value(createdRoute,'data'),'route_id'));
    routesBefore=value(await command(request,'state'),'routes');
    await open(page); await expand(page, 3);
    const first = page.waitForResponse(response => response.url().includes('/waypoint.cfc') && response.request().method() === 'POST');
    await button(page, 3).click();
    counts({data: await (await first).json()}, 2, 0);
    await expect(button(page, 3)).toHaveText('Waypoints Added');
    await expect(status(page, 3)).toContainText('Ottawa');
    await expect(status(page, 3)).toContainText('Peoria');
    if (process.env.FPW_LEG_WAYPOINT_REVIEW_DIR) {
      fs.mkdirSync(process.env.FPW_LEG_WAYPOINT_REVIEW_DIR,{recursive:true});
      for (const width of [1440,390]) {
        await page.setViewportSize({width,height:width===390?844:960});
        await page.mouse.move(5,width===390?830:945);
        await page.keyboard.press('Escape');
        if(width===390) {
          await expect(page.locator('[data-fpw-mobile-toggle]')).toHaveAttribute('aria-expanded','false');
          await expect.poll(()=>page.locator('#fpwPrimaryNav').evaluate(element=>element.getBoundingClientRect().left)).toBeGreaterThanOrEqual(width-1);
        }
        await panel(page,3).locator('.loop-leg-prompt').scrollIntoViewIfNeeded();
        await page.screenshot({path:path.join(process.env.FPW_LEG_WAYPOINT_REVIEW_DIR,'after-'+width+'-saved.png'),animations:'disabled'});
      }
      await page.setViewportSize({width:1440,height:960});
    }
    const saved = await points(page.request);
    expect(saved.map(item => value(item, 'waypointname')).sort()).toEqual(['Ottawa', 'Peoria']);
    const source = value(template, 'legs')[2];
    for (const [nameKey, latKey, lngKey] of [['start_name','start_lat','start_lng'],['end_name','end_lat','end_lng']]) {
      const item = saved.find(point => value(point, 'waypointname') === value(source, nameKey));
      expect(Number(value(item, 'latitude'))).toBe(Number(value(source, latKey)));
      expect(Number(value(item, 'longitude'))).toBe(Number(value(source, lngKey)));
    }
    const second = page.waitForResponse(response => response.url().includes('/waypoint.cfc') && response.request().method() === 'POST');
    await button(page, 3).click();
    counts({data: await (await second).json()}, 0, 2);
    await expect(button(page, 3)).toHaveText('Already in My Waypoints');
    await page.reload(); await expand(page, 3); await button(page, 3).click();
    await expect(button(page, 3)).toHaveText('Already in My Waypoints');
    expect(await points(page.request)).toHaveLength(2);
    expect(value(await command(request, 'state'), 'waypointEvents')).toBe(2);
    const available = await (await page.request.post(base + '/api/v1/routeBuilder.cfc?method=handle&action=listUserWaypoints&returnFormat=json', {data:{}})).json();
    expect(value(available, 'success')).toBe(true);
    const rendered = JSON.stringify(available);
    expect(rendered).toContain('Ottawa'); expect(rendered).toContain('Peoria');
    await page.goto(base + '/app/dashboard.cfm');
    await expect(page.locator('#waypointsPanel')).toContainText('Ottawa');
    await expect(page.locator('#waypointsPanel')).toContainText('Peoria');
    await expect(page.locator('#welcomeOnboardingModal')).toBeVisible();
    await page.locator('#welcomeOnboardingCloseBtn').click();
    await expect(page.locator('#welcomeOnboardingModal')).toBeHidden();
    await expect(page.locator('#waypointsList')).toBeVisible();
    if (process.env.FPW_LEG_WAYPOINT_REVIEW_DIR) await page.locator('#waypointsPanel').screenshot({path:path.join(process.env.FPW_LEG_WAYPOINT_REVIEW_DIR,'after-my-waypoints.png')});
    await page.locator('#openRouteBuilderBtn').click();
    await expect(page.locator('#routeBuilderModal')).toBeVisible();
    for(const selector of ['#routeGenMyRouteStartWaypointSelect','#routeGenMyRouteEndWaypointSelect']) {
      for(const name of ['Ottawa','Peoria']) {
        const option=page.locator(selector+' option').filter({hasText:name});
        await expect(option).toHaveCount(1);
        await expect(option).not.toHaveAttribute('disabled','');
        expect(Number(await option.getAttribute('value'))).toBeGreaterThan(0);
      }
    }
    await page.locator('#routeGenMyRouteSelect').selectOption(String(routeId));
    await expect(page.locator('#routeGenMyRouteStartWaypointSelect')).toBeEnabled();
    const start=saved.find(item=>value(item,'waypointname')==='Ottawa');
    const end=saved.find(item=>value(item,'waypointname')==='Peoria');
    await page.locator('#routeGenMyRouteStartWaypointSelect').selectOption(String(value(start,'waypointid')));
    await expect(page.locator('#routeGenMyRouteEndWaypointSelect')).toBeEnabled();
    await page.locator('#routeGenMyRouteEndWaypointSelect').selectOption(String(value(end,'waypointid')));
    await expect(page.locator('#routeGenMyRouteStartWaypointSelect')).toHaveValue(String(value(start,'waypointid')));
    await expect(page.locator('#routeGenMyRouteEndWaypointSelect')).toHaveValue(String(value(end,'waypointid')));
    if (process.env.FPW_LEG_WAYPOINT_REVIEW_DIR) await page.locator('#routeGenSetupPanelBody').screenshot({path:path.join(process.env.FPW_LEG_WAYPOINT_REVIEW_DIR,'after-planner-selected.png')});
    await page.locator('#routeGenMyRouteEndWaypointSelect').selectOption('');
    await page.locator('#routeGenMyRouteStartWaypointSelect').selectOption('');
  });

  test('each single existing endpoint is retained and adjacent legs share Peoria', async ({ page }) => {
    const token = await login(page.request);
    counts(await save(page.request, 3, token), 2, 0);
    for (const removeName of ['Peoria', 'Ottawa']) {
      const existing = await points(page.request);
      const removed = existing.find(item => value(item, 'waypointname') === removeName);
      const kept = existing.find(item => value(item, 'waypointname') !== removeName);
      await remove(page.request, value(removed, 'waypointid'));
      const result = await save(page.request, 3, token);
      counts(result, 1, 1);
      expect(value(result.data, 'message')).toContain(removeName);
      const next = await points(page.request);
      expect(value(next.find(item => value(item, 'waypointname') === value(kept, 'waypointname')), 'waypointid')).toBe(value(kept, 'waypointid'));
    }
    counts(await save(page.request, 4, token), 1, 1);
    expect((await points(page.request)).map(item => value(item, 'waypointname')).sort()).toEqual(['Grafton', 'Ottawa', 'Peoria']);
  });

  test('concurrent saves serialize per member and create each endpoint once', async ({ page, browser }) => {
    const token = await login(page.request);
    const contexts = await Promise.all([browser.newContext(), browser.newContext()]);
    try {
      const tokens = await Promise.all(contexts.map(context => login(context.request)));
      const responses = await Promise.all([save(page.request,3,token),...contexts.map((context,i)=>save(context.request,3,tokens[i]))]);
      for (const response of responses) expect(value(response.data, 'success'), JSON.stringify(response)).toBe(true);
      expect(responses.reduce((sum,response)=>sum+value(response.data,'added_count'),0)).toBe(2);
      expect(responses.reduce((sum,response)=>sum+value(response.data,'existing_count'),0)).toBe(4);
      expect(await points(page.request)).toHaveLength(2);
    } finally { await Promise.all(contexts.map(context=>context.close())); }
  });

  test('all 56 legs save both authoritative endpoints and replay without duplicates', async ({ page, request }) => {
    test.setTimeout(120000);
    const token = await login(page.request);
    const legs = value(template, 'legs');
    expect(legs).toHaveLength(56);
    expect(await points(page.request)).toHaveLength(0);
    const sourceWaypoints = new Map(), firstResults = new Map(), evidence = [];
    let totalAdded = 0, totalExisting = 0;
    for (const leg of legs) {
      const order = Number(value(leg, 'order_index'));
      const sources = ['start', 'end'].map(side => ({
        portId: Number(value(leg, side + '_port_id')),
        name: value(leg, side + '_name'),
        latitude: Number(value(leg, side + '_lat')),
        longitude: Number(value(leg, side + '_lng'))
      }));
      for (const source of sources) expect(source.portId).toBeGreaterThan(0);
      const expectedAdded = sources.filter(source => !sourceWaypoints.has(source.portId)).length;
      const result = await save(page.request, order, token);
      expect(result.status).toBe(200);
      counts(result, expectedAdded, 2 - expectedAdded);
      const endpoints = value(result.data, 'endpoints');
      expect(endpoints).toHaveLength(2);
      const recorded = sources.map((source, index) => {
        const item = endpoints[index], waypointId = Number(value(item, 'waypointid'));
        expect(value(item, 'name')).toBe(source.name);
        expect(waypointId).toBeGreaterThan(0);
        if (sourceWaypoints.has(source.portId)) {
          expect(waypointId).toBe(sourceWaypoints.get(source.portId).waypointId);
        }
        sourceWaypoints.set(source.portId, { ...source, waypointId });
        return { ...source, waypointId };
      });
      firstResults.set(order, recorded.map(item => item.waypointId));
      totalAdded += value(result.data, 'added_count');
      totalExisting += value(result.data, 'existing_count');
      evidence.push({ order, segmentId: Number(value(leg, 'segment_id')), endpoints: recorded,
        added: value(result.data, 'added_count'), existing: value(result.data, 'existing_count') });
    }
    expect(sourceWaypoints.size).toBe(56);
    expect(totalAdded).toBe(56); expect(totalExisting).toBe(56);
    const saved = await points(page.request);
    expect(saved).toHaveLength(56);
    for (const source of sourceWaypoints.values()) {
      const item = saved.find(point => Number(value(point, 'waypointid')) === source.waypointId);
      expect(item).toBeDefined();
      expect(value(item, 'waypointname')).toBe(source.name);
      expect(Number(value(item, 'latitude'))).toBe(source.latitude);
      expect(Number(value(item, 'longitude'))).toBe(source.longitude);
      expect(value(item, 'notes')).toBe('Added from Great Loop Ports Library: ' + source.name);
    }
    expect(value(await command(request, 'state'), 'waypointEvents')).toBe(56);
    for (const leg of legs) {
      const order = Number(value(leg, 'order_index'));
      const result = await save(page.request, order, token);
      expect(result.status).toBe(200);
      counts(result, 0, 2);
      expect(value(result.data, 'endpoints').map(item => Number(value(item, 'waypointid')))).toEqual(firstResults.get(order));
    }
    expect(await points(page.request)).toEqual(saved);
    expect(value(await command(request, 'state'), 'waypointEvents')).toBe(56);
    if (process.env.FPW_LEG_WAYPOINT_REVIEW_DIR) {
      fs.mkdirSync(process.env.FPW_LEG_WAYPOINT_REVIEW_DIR, { recursive: true });
      fs.writeFileSync(path.join(process.env.FPW_LEG_WAYPOINT_REVIEW_DIR, 'all-56-leg-waypoint-results.json'),
        JSON.stringify({ legs: evidence, uniqueWaypoints: saved.length, totalAdded, totalExisting,
          replay: { legs: legs.length, added: 0, existing: 112, stableWaypointIds: true }, waypointEvents: 56 }, null, 2));
    }
  });

  test('server rejects unauthenticated, CSRF, origin, identity and ownership manipulation', async ({ page, request, browser }) => {
    const anonymous = await browser.newContext();
    try { expect(value((await save(anonymous.request,3,csrf)).data,'auth')).toBe(false); }
    finally { await anonymous.close(); }
    const token = await login(page.request);
    expect((await page.request.get(endpoint+'&action=savelegstops')).status()).toBe(405);
    for(const options of [
      {data:payload(3)},
      {headers:{'X-CSRF-Token':'0'.repeat(64)},data:payload(3)},
      {headers:{'X-CSRF-Token':token,Origin:'https://unrelated.invalid'},data:payload(3)}
    ]) expect((await page.request.post(endpoint,options)).status()).toBe(403);
    for(const extra of [{userId:value(other(),'userId')},{latitude:0,longitude:0},{segmentId:999999},{legOrder:4},{templateCode:'INVALID'}]) {
      const result=await save(page.request,3,token,extra);
      expect(value(result.data,'success'),JSON.stringify(result)).toBe(false);
    }
    expect(value(await command(request,'state'),'waypoints')).toHaveLength(0);
    counts(await save(page.request,3,token),2,0);
    const otherContext=await browser.newContext();
    try {
      const otherToken=await login(otherContext.request,other());
      expect(await points(otherContext.request)).toHaveLength(0);
      counts(await save(otherContext.request,3,otherToken),2,0);
      expect(await points(otherContext.request)).toHaveLength(2);
    }finally{await otherContext.close();}
    const state=await command(request,'state');
    expect(value(state,'waypoints')).toHaveLength(4);
    expect(new Set(value(state,'waypoints').map(point=>Number(value(point,'userid'))))).toEqual(new Set([Number(value(owner(),'userId')),Number(value(other(),'userId'))]));
  });

  test('controlled database failure before first and second insert rolls back and permits retry', async ({ page, request }) => {
    const token=await login(page.request);
    for(const failAt of [1,2]) {
      const response=await page.request.post(fixtureUrl('failure')+'&failAt='+failAt,{headers:{...headers(),'X-CSRF-Token':token},data:payload(3)});
      const data=await response.json();
      expect(value(data,'success'),JSON.stringify(data)).toBe(false);
      expect(value(await command(request,'state'),'waypoints')).toHaveLength(0);
      expect(value(await command(request,'state'),'waypointEvents')).toBe(0);
    }
    counts(await save(page.request,3,token),2,0);
  });

  test('a genuinely expired session prompts sign-in without writing', async ({ page, request }) => {
    await login(page.request); await open(page); await expand(page,3);
    await command(page.request,'expire');
    let writes=0;
    page.on('request',request=>{if(request.url().includes('/waypoint.cfc')&&request.method()==='POST')writes++;});
    await button(page,3).click();
    await expect(page.locator('#loopWaypointAuthDialog')).toBeVisible();
    expect(writes).toBe(0);
    expect(value(await command(request,'state'),'waypoints')).toHaveLength(0);
  });
});
