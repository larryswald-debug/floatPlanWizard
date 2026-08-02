const { test, expect } = require("@playwright/test");

const baseUrl = "http://localhost:8500/fpw";

function collectPageErrors(page) {
  const errors = [];
  page.on("console", (message) => {
    if (message.type() === "error") {
      errors.push(`console: ${message.text()}`);
    }
  });
  page.on("pageerror", (error) => {
    errors.push(`pageerror: ${error.message}`);
  });
  return errors;
}

test("About page renders its public content and responsive layout", async ({ page }, testInfo) => {
  const pageErrors = collectPageErrors(page);
  const viewports = [
    { name: "desktop", width: 1440, height: 1000 },
    { name: "tablet", width: 1024, height: 900 },
    { name: "mobile", width: 390, height: 844 }
  ];

  for (const viewport of viewports) {
    await page.setViewportSize({ width: viewport.width, height: viewport.height });
    const response = await page.goto(`${baseUrl}/about.cfm`, {
      waitUntil: "domcontentloaded"
    });

    expect(response && response.status()).toBe(200);
    await expect(page.locator("header.fpw-site-header")).toBeVisible();
    await expect(page.locator("footer.fpw-site-footer")).toBeAttached();
    await expect(page.locator("h1")).toHaveCount(1);
    await expect(page.getByRole("heading", {
      level: 1,
      name: "Built by a Solo Boater Who Needed a Better Way"
    })).toBeVisible();
    await expect(page.getByRole("heading", {
      level: 2,
      name: "A Tool That Came From Real Boating"
    })).toBeAttached();
    await expect(page.getByText("Larry Wald", { exact: true })).toBeAttached();

    const hasHorizontalOverflow = await page.evaluate(
      () => document.documentElement.scrollWidth > window.innerWidth
    );
    expect(hasHorizontalOverflow).toBe(false);

    await page.screenshot({
      path: testInfo.outputPath(`about-${viewport.name}-full.png`),
      fullPage: true
    });
  }

  await expect(page.getByRole("link", { name: "Create Your Free Account" }))
    .toHaveAttribute("href", "/fpw/app/join.cfm");
  await expect(page.getByRole("link", { name: "See How It Works" }))
    .toHaveAttribute("href", "/fpw/how-it-works/");
  await expect(page.getByRole("link", { name: "Start Planning Your Next Trip" }))
    .toHaveAttribute("href", "/fpw/app/join.cfm");
  await expect(page.getByRole("link", { name: "About FPW" }))
    .toHaveAttribute("href", "/fpw/about");
  expect(pageErrors).toEqual([]);
});

test("About page emits one exact metadata set and one valid entity graph", async ({ page }) => {
  const pageErrors = collectPageErrors(page);
  const response = await page.goto(`${baseUrl}/about.cfm`, {
    waitUntil: "domcontentloaded"
  });
  expect(response && response.status()).toBe(200);

  await expect(page).toHaveTitle("About FloatPlanWizard | Built by a Solo Boater");
  await expect(page.locator('meta[name="description"]')).toHaveCount(1);
  await expect(page.locator('meta[name="description"]')).toHaveAttribute(
    "content",
    "Learn why solo boater and retired web developer Larry Wald created FloatPlanWizard to make trip planning, float-plan sharing, monitoring, and family communication easier."
  );
  await expect(page.locator('meta[name="robots"]')).toHaveCount(1);
  await expect(page.locator('meta[name="robots"]')).toHaveAttribute("content", "index,follow");
  await expect(page.locator('link[rel="canonical"]')).toHaveCount(1);
  await expect(page.locator('link[rel="canonical"]')).toHaveAttribute(
    "href",
    "https://floatplanwizard.com/about"
  );
  await expect(page.locator('meta[property="og:title"]')).toHaveAttribute(
    "content",
    "Why I Built FloatPlanWizard"
  );
  await expect(page.locator('meta[property="og:url"]')).toHaveAttribute(
    "content",
    "https://floatplanwizard.com/about"
  );
  await expect(page.locator('meta[name="twitter:title"]')).toHaveAttribute(
    "content",
    "Why I Built FloatPlanWizard"
  );

  const schemaScripts = page.locator('script[type="application/ld+json"]');
  await expect(schemaScripts).toHaveCount(1);
  const graph = JSON.parse(await schemaScripts.textContent())["@graph"];
  expect(graph.map((entity) => entity["@id"])).toEqual([
    "https://floatplanwizard.com/about#webpage",
    "https://floatplanwizard.com/#organization",
    "https://floatplanwizard.com/about#larry-wald"
  ]);
  expect(new Set(graph.map((entity) => entity["@id"])).size).toBe(3);
  expect(graph.map((entity) => entity["@type"])).toEqual([
    "AboutPage",
    "Organization",
    "Person"
  ]);
  expect(await page.locator("head").textContent()).not.toContain("localhost");
  expect(pageErrors).toEqual([]);
});

test("Homepage founder section remains between steps and product preview", async ({ page }, testInfo) => {
  const pageErrors = collectPageErrors(page);

  for (const viewport of [
    { name: "desktop", width: 1440, height: 1000 },
    { name: "mobile", width: 390, height: 844 }
  ]) {
    await page.setViewportSize({ width: viewport.width, height: viewport.height });
    const response = await page.goto(`${baseUrl}/index.cfm`, {
      waitUntil: "domcontentloaded"
    });
    expect(response && response.status()).toBe(200);

    const origin = page.locator(".fpw-origin-story");
    await expect(origin).toBeVisible();
    await expect(origin.getByRole("heading", {
      level: 2,
      name: "Built by a Solo Boater, for Solo Boaters"
    })).toBeVisible();
    await expect(origin.getByText("— Larry Wald, Founder", { exact: true })).toBeVisible();
    await expect(origin.getByRole("link", { name: "Read the Story Behind FPW" }))
      .toHaveAttribute("href", "/fpw/about");

    const orderIsCorrect = await page.evaluate(() => {
      const steps = document.querySelector(".fpw-steps");
      const story = document.querySelector(".fpw-origin-story");
      const preview = document.querySelector(".fpw-product-preview");
      return Boolean(
        steps && story && preview &&
        (steps.compareDocumentPosition(story) & Node.DOCUMENT_POSITION_FOLLOWING) &&
        (story.compareDocumentPosition(preview) & Node.DOCUMENT_POSITION_FOLLOWING)
      );
    });
    expect(orderIsCorrect).toBe(true);
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)).toBe(true);

    await origin.screenshot({
      path: testInfo.outputPath(`homepage-founder-${viewport.name}.png`)
    });
  }

  const homepageGraph = JSON.parse(
    await page.locator('script[type="application/ld+json"]').textContent()
  )["@graph"];
  const organization = homepageGraph.find(
    (entity) => entity["@id"] === "https://floatplanwizard.com/#organization"
  );
  expect(organization.logo).toEqual({
    "@type": "ImageObject",
    url: "https://floatplanwizard.com/assets/images/checkout/floatplanwizard-logo.jpg"
  });
  expect(organization.founder).toEqual({
    "@id": "https://floatplanwizard.com/about#larry-wald"
  });
  expect(pageErrors).toEqual([]);
});
