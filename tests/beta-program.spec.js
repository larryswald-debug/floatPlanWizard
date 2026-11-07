const { test, expect } = require('@playwright/test');
const base = 'http://localhost:8500/fpw';
const adminUrl = base + '/admin/beta-program.cfm';
const memberUrl = base + '/app/beta.cfm';
const fixtureUrl = base + '/tests/beta-program-ui-fixture.cfm?confirm=LOCAL_BETA_UI_FIXTURE';
const field = (object, name) => object[name] ?? object[name.toUpperCase()] ?? object[name.toLowerCase()];
const normalized = value => Array.isArray(value) ? value.map(normalized) : value && typeof value === 'object'
  ? Object.fromEntries(Object.entries(value).map(([key, data]) => [key.toLowerCase(), normalized(data)])) : value;

async function fixture(page, mode) {
  const response = await page.request.post(fixtureUrl, { form: { mode } });
  expect(response.status(), await response.text()).toBe(200);
  const result = await response.json();
  expect(field(result, 'success')).toBe(true);
  return normalized(result);
}
async function report(page) {
  const response = await page.request.get(adminUrl + '?export=json');
  expect(response.status(), await response.text()).toBe(200);
  expect(response.headers()['cache-control']).toContain('no-store');
  const result = normalized(await response.json());
  expect(JSON.stringify(result)).not.toMatch(/@example|password|csrf|latitude|longitude|geometry|recipient_email/);
  return result;
}

test.describe('Founding Beta protected minimal UI', () => {
  test.describe.configure({ mode: 'serial' });
  test.setTimeout(60000);
  test.beforeEach(async ({ page }) => {
    await page.route('https://plausible.io/**', route => route.abort());
    await fixture(page, 'setup');
  });
  test.afterEach(async ({ page }) => {
    const cleaned = await fixture(page, 'cleanup');
    expect(cleaned.remainingusers).toBe(0);
  });

  test('anonymous/member access and administrator CSRF remain protected', async ({ page }) => {
    expect((await page.request.get(adminUrl)).status()).toBe(401);
    expect((await page.request.get(adminUrl + '?export=json')).status()).toBe(401);
    await fixture(page, 'member');
    expect((await page.request.get(adminUrl)).status()).toBe(403);
    expect((await page.request.get(adminUrl + '?export=json')).status()).toBe(403);
    await page.goto(memberUrl);
    await expect(page.getByText('You do not have a Founding Beta invitation.')).toBeVisible();
    expect((await fixture(page, 'state')).state.participationstatus).toBe('NONE');
    const own = (await fixture(page, 'admin')).fixture.member;
    const denied = await page.request.post(adminUrl, { form: { userId: String(own), source: 'existing_member', adminCsrfToken: 'invalid' } });
    expect(denied.status()).toBe(403);
    expect((await fixture(page, 'state')).state.participationstatus).toBe('NONE');
  });

  test('invitation requires explicit acceptance, reports once, and withdrawal preserves access', async ({ page }) => {
    await page.setViewportSize({ width: 1440, height: 1000 });
    const own = (await fixture(page, 'admin')).fixture.member;
    await page.goto(adminUrl);
    await expect(page.getByRole('heading', { name: 'Founding Beta', exact: true })).toBeVisible();
    await page.locator('input[name="userId"]').fill(String(own));
    await page.locator('select[name="source"]').selectOption('mailing_list');
    await page.getByRole('button', { name: 'Record invitation' }).click();
    await expect(page.getByRole('status')).toContainText('Invitation recorded.');
    expect((await report(page)).members.filter(member => Number(member.user_id) === own)).toHaveLength(0);
    expect((await fixture(page, 'state')).state).toMatchObject({ participationstatus: 'INVITED', accesscount: 0 });

    await fixture(page, 'member');
    await page.goto(memberUrl);
    await expect(page.getByRole('checkbox', { name: /I agree to participate/ })).not.toBeChecked();
    const csrf = await page.locator('input[name="csrfToken"]').inputValue();
    const noAgreement = await page.request.post(memberUrl, { form: { action: 'accept', csrfToken: csrf } });
    expect(noAgreement.status()).toBe(200);
    expect((await fixture(page, 'state')).state.participationstatus).toBe('INVITED');
    const badCsrf = await page.request.post(memberUrl, { form: { action: 'accept', acceptance: 'yes', csrfToken: 'invalid' } });
    expect(badCsrf.status()).toBe(403);
    expect((await fixture(page, 'state')).state.participationstatus).toBe('INVITED');
    await page.getByRole('checkbox', { name: /I agree to participate/ }).check();
    await page.getByRole('button', { name: 'Accept invitation' }).click();
    await expect(page.getByText('You are enrolled. Feedback is optional.')).toBeVisible();
    const first = (await fixture(page, 'state')).state;
    expect(first).toMatchObject({ participationstatus: 'ENROLLED', accesscount: 0 });
    expect(first.enrolledutc).toMatch(/^\d{4}-\d\d-\d\d /);
    const repeat = await page.request.post(memberUrl, { form: { action: 'accept', acceptance: 'yes', csrfToken: await page.locator('input[name="csrfToken"]').inputValue() } });
    expect(repeat.status()).toBe(200);
    expect((await fixture(page, 'state')).state).toEqual(first);

    await fixture(page, 'admin');
    const enrolled = await report(page);
    const matching = enrolled.members.filter(member => Number(member.user_id) === own);
    expect(matching).toHaveLength(1);
    expect(matching[0]).toMatchObject({ accepted_share: false, has_vessel: false, has_route: false, has_floatplan: false, unknown_evidence: true });
    expect(matching[0].evidence_reasons).toContain('NO_VERIFIED_POST_ENROLLMENT_SHARE');
    expect(enrolled.summary.enrolled).toBe(enrolled.members.length);

    await fixture(page, 'member');
    await page.setViewportSize({ width: 390, height: 844 });
    await page.goto(memberUrl);
    await page.getByRole('button', { name: 'Withdraw from beta' }).click();
    await expect(page.getByText('You have withdrawn. Your membership access is unchanged.')).toBeVisible();
    expect((await fixture(page, 'state')).state).toMatchObject({ participationstatus: 'WITHDRAWN', accesscount: 0, enrolledutc: first.enrolledutc });
    await fixture(page, 'admin');
    expect((await report(page)).members.filter(member => Number(member.user_id) === own)).toHaveLength(0);
  });
});
