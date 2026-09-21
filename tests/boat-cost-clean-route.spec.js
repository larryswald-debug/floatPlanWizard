const { test, expect } = require('@playwright/test');

const baseUrl = (process.env.FPW_BASE_URL || 'http://127.0.0.1:8500/fpw').replace(/\/$/, '');
const cleanUrl = `${baseUrl}/boat-loan-calculator/`;
const canonical = 'https://floatplanwizard.com/boat-loan-calculator/';
const title = 'Boat Loan & Ownership Cost Calculator | FloatPlanWizard';
const heading = 'Boat Loan and Ownership Cost Calculator';
const query = 'qa=route&tag=a%2Bb&tag=c%20d&empty=&encoded=%252F';

async function calculatorContent(response) {
  expect(response.status()).toBe(200);
  const body = await response.text();
  expect(body).toContain(heading);
  expect(body).toContain('id="boat-cost-app"');
  expect(body).toContain('/assets/js/boat-cost-engine.js');
  expect(body).toContain('Complete version 1.0 illustrative input packs and engine-generated results');
  expect(body).toContain('data-example-output="B.monthlyBudget">$1,418.64</td>');
  expect(body).not.toMatch(/Directory Listing For|<title>Index of /i);
  return body;
}

async function assertCanonicalRedirect(request, requestedUrl, expectedUrl) {
  const response = await request.get(requestedUrl, { maxRedirects: 0 });
  expect(response.status(), requestedUrl).toBe(301);
  const location = response.headers().location;
  expect(location, 'The canonical response supplies Location').toBeTruthy();
  const destination = new URL(location, requestedUrl);
  expect(destination.href).toBe(expectedUrl);
  expect(destination.origin).toBe(new URL(requestedUrl).origin);
  expect(destination.search).toBe(new URL(expectedUrl).search);
  expect(destination.searchParams.getAll('tag')).toEqual(['a+b', 'c d']);
  // Following one redirect must immediately return real calculator content.
  // A second canonical redirect or a directory listing is a regression.
  const final = await request.get(destination.href, { maxRedirects: 0 });
  await calculatorContent(final);
}

test.beforeEach(async ({ page }) => {
  await page.route(/https:\/\/(?:[^/]*\.)?(?:plausible\.io|google-analytics\.com|googletagmanager\.com|clarity\.ms)\//, route => route.abort());
});

test('friendly HTTP route returns the public calculator, never a directory listing', async ({ request }) => {
  const response = await request.get(cleanUrl, { maxRedirects: 0 });
  const body = await calculatorContent(response);
  expect(response.url()).toBe(cleanUrl);
  expect(body).toContain(`href="${canonical}"`);
});

test('no-slash and original CFM requests normalize once and preserve encoded repeated queries', async ({ request }) => {
  await assertCanonicalRedirect(request, `${baseUrl}/boat-loan-calculator?${query}`, `${cleanUrl}?${query}`);
  await assertCanonicalRedirect(request, `${cleanUrl}index.cfm?${query}`, `${cleanUrl}?${query}`);
});

test('generated examples are available only through the calculator include', async ({ request }) => {
  for (const suffix of ['examples.cfm', `examples.cfm?${query}`, 'examples.cfm/', 'examples.cfm/seo-remediation-not-found', `examples.cfm/nested/path?${query}`]) {
    const response = await request.get(`${cleanUrl}${suffix}`, { maxRedirects: 0 });
    expect(response.status(), suffix).toBe(404);
    expect(response.headers().location, suffix).toBeUndefined();
    const body = await response.text();
    expect(body, suffix).not.toContain('data-example-output=');
    expect(body, suffix).not.toContain('data-boat-cost-example=');
  }
  await calculatorContent(await request.get(cleanUrl, { maxRedirects: 0 }));
});

test('calculator path-info and unknown routes return real 404 responses', async ({ request }) => {
  const calculatorPath = new URL(cleanUrl).pathname;
  const suffixes = [
    'index.cfm/',
    'index.cfm/seo-remediation-not-found',
    `index.cfm/nested/path?${query}`,
    `index.cfm${calculatorPath}index.cfm`,
    `index.cfm${calculatorPath}`,
    `%69ndex.cfm${calculatorPath}index.cfm`,
    `%69ndex.cfm${calculatorPath}`,
    `index.cfm;routecheck${calculatorPath}index.cfm`,
    'INDEX.CFM/seo-remediation-not-found',
    'seo-remediation-not-found/',
    'seo-remediation-not-found.cfm'
  ];
  for (const suffix of suffixes) {
    const response = await request.get(`${cleanUrl}${suffix}`, { maxRedirects: 0 });
    expect(response.status(), suffix).toBe(404);
    expect(response.headers().location, suffix).toBeUndefined();
    const body = await response.text();
    expect(body, suffix).not.toContain('id="boat-cost-app"');
    expect(body, suffix).not.toContain('data-example-output=');
  }
});

test('canonical redirects keep either loopback hostname and its nondefault port', async ({ request }) => {
  const parsed = new URL(baseUrl);
  test.skip(!['127.0.0.1', 'localhost'].includes(parsed.hostname), 'Loopback aliases apply only to the local container.');
  for (const hostname of ['127.0.0.1', 'localhost']) {
    const hostBase = new URL(baseUrl);
    hostBase.hostname = hostname;
    const root = hostBase.href.replace(/\/$/, '');
    await assertCanonicalRedirect(request, `${root}/boat-loan-calculator?${query}`, `${root}/boat-loan-calculator/?${query}`);
  }
});

test('internal rewrite serves encoded query requests without redirecting or exposing the CFM URL', async ({ browser, request }) => {
  const requestedUrl = `${cleanUrl}?${query}`;
  const response = await request.get(requestedUrl, { maxRedirects: 0 });
  await calculatorContent(response);
  expect(response.url()).toBe(requestedUrl);
  expect(response.headers().location).toBeUndefined();
  // Disable JavaScript to isolate the HTTP routing contract from the calculator's
  // intentional history.replaceState query scrubbing before analytics startup.
  const context = await browser.newContext({ javaScriptEnabled: false });
  try {
    const page = await context.newPage();
    const documentResponse = await page.goto(requestedUrl, { waitUntil: 'domcontentloaded' });
    await calculatorContent(documentResponse);
    expect(page.url()).toBe(requestedUrl);
    expect(new URL(page.url()).searchParams.getAll('tag')).toEqual(['a+b', 'c d']);
    expect(new URL(page.url()).searchParams.get('encoded')).toBe('%2F');
    await expect(page.locator('.bc-notice')).toContainText('requires JavaScript');
    await expect(page.locator('#bc-worked-examples')).toBeVisible();
  } finally {
    await context.close();
  }
});

test('friendly browser URL loads assets and calculates while retaining privacy query cleanup', async ({ page }) => {
  const pageErrors = [];
  const failedLocalResponses = [];
  const featureAssets = new Map();
  page.on('pageerror', error => pageErrors.push(error.message));
  page.on('response', response => {
    if (!response.url().startsWith(baseUrl + '/')) return;
    if (response.status() >= 400) failedLocalResponses.push(`${response.status()} ${response.url()}`);
    const pathname = new URL(response.url()).pathname;
    if (/\/assets\/(?:js|css)\/boat-cost[^/]*\.(?:js|css)$/.test(pathname)) featureAssets.set(pathname.split('/').pop(), response.status());
  });
  const response = await page.goto(`${cleanUrl}?${query}`, { waitUntil: 'load' });
  expect(response && response.status()).toBe(200);
  await expect(page).toHaveTitle(title);
  await expect(page.getByRole('heading', { name: heading, exact: true }).first()).toBeVisible();
  await expect(page.locator('link[rel="canonical"]')).toHaveAttribute('href', canonical);
  await expect(page.locator('#bc-results')).toContainText('No estimate has been calculated');
  await expect.poll(() => page.url()).toBe(cleanUrl);
  await page.locator('[data-boat-cost-example="B"]').click();
  await expect(page.locator('#bc-results .bc-hero-value')).toHaveText('$1,418.64');
  await expect(page.locator('#bc-results')).toContainText('$34,023.72');
  expect(page.url()).toBe(cleanUrl);
  for (const file of ['boat-cost.css', 'boat-cost-bootstrap.js', 'boat-cost-engine.js', 'boat-cost-state.js', 'boat-cost-ui.js', 'boat-cost-analytics.js']) {
    expect(featureAssets.get(file), file).toBe(200);
  }
  expect(failedLocalResponses).toEqual([]);
  expect(pageErrors).toEqual([]);
});

test('shared Resources navigation uses the friendly calculator destination and loads public content', async ({ page }) => {
  await page.setViewportSize({ width: 1440, height: 900 });
  await page.goto(`${baseUrl}/index.cfm`, { waitUntil: 'domcontentloaded' });
  const navigation = page.locator('[data-fpw-nav]');
  const resources = navigation.getByRole('button', { name: 'Resources', exact: true });
  await resources.click();
  const link = navigation.locator(`a[href="${new URL(cleanUrl).pathname}"]`).filter({ hasText: 'Boat Loan & Ownership Calculator' }).filter({ visible: true });
  await expect(link).toHaveCount(1);
  await Promise.all([page.waitForURL(cleanUrl), link.click()]);
  await expect(page.getByRole('heading', { name: heading, exact: true }).first()).toBeVisible();
  await expect(page.locator('#bc-purchase-price')).toBeVisible();
  expect(await page.locator('body').textContent()).not.toContain('Directory Listing For');
});

test('Fuel Calculator and an existing clean guide still return their real pages', async ({ request }) => {
  const routes = [
    { path: '/boat-fuel-calculator/', marker: 'Free Boat Fuel Calculator', distinctive: 'qaFuelCalcForm' },
    { path: '/how-it-works/', marker: 'How It Works | FloatPlanWizard', distinctive: '<h1>How It Works</h1>' }
  ];
  for (const route of routes) {
    const response = await request.get(`${baseUrl}${route.path}?${query}`, { maxRedirects: 0 });
    const body = await response.text();
    expect(response.status(), route.path).toBe(200);
    expect(body, route.path).toContain(route.marker);
    expect(body, route.path).toContain(route.distinctive);
    expect(body, route.path).not.toMatch(/Directory Listing For|<title>Index of /i);
    expect(response.headers().location).toBeUndefined();
  }
});
