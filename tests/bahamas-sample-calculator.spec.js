const { test, expect } = require("@playwright/test");
const guideUrl = "http://localhost:8500/fpw/boating-guides/bahamas/itineraries/fort-lauderdale-bimini/";
const field = (page, key) => page.locator('[data-bh-sample-input="' + key + '"]');
const output = (page, key) => page.locator('[data-bh-sample-output="' + key + '"]');

async function loadGuide(page) {
  const errors = [];
  const mutations = [];
  const requests = [];
  page.on("pageerror", error => errors.push(error.message));
  page.on("request", request => {
    if (!request.url().startsWith("http://localhost:8500/")) return;
    if (!["GET", "HEAD"].includes(request.method())) mutations.push(request.url());
    if (["fetch", "xhr"].includes(request.resourceType())) requests.push(request.url());
  });
  await page.route("**/*", route => {
    const url = route.request().url();
    return url.startsWith("http://localhost:8500/") ? route.continue() : route.abort();
  });
  const response = await page.goto(guideUrl);
  expect(response.status()).toBe(200);
  await expect(field(page, "speed")).toHaveAttribute("aria-invalid", "false");
  requests.length = 0;
  return {errors, mutations, requests};
}

async function expectEstimates(page, values) {
  for (const [key, value] of Object.entries(values)) await expect(output(page, key)).toHaveText(value);
}

test("public sample uses approved mileage and existing article defaults without import controls", async ({page}) => {
  const observed = await loadGuide(page);
  await expect(page.locator("body")).toHaveClass(/bh-dark-guide/);
  await expect(page.locator(".bh-guide-hero")).toBeVisible();
  await expect(page.locator("#sample-calculator")).toHaveAttribute("data-bh-sample-distance", "100.6");
  await expect(page.locator("[data-bh-sample-input]")).toHaveCount(4);
  for (const [key, value] of Object.entries({speed:"20",burn:"18",reserve:"20",usable:"190"})) await expect(field(page,key)).toHaveValue(value);
  await expectEstimates(page,{time:"5 h 02 min",base:"90.5 US gal",reserve:"18.1 US gal",required:"108.6 US gal",margin:"81.4 US gal"});
  await expect(page.locator("[data-fpw-guide-template]")).toHaveCount(0);
  await expect(page.locator("#personal-copy")).toHaveCount(0);
  await expect(page.locator("#sample-calculator form")).toHaveCount(0);
  await expect(page.locator("#stops .bh-map img")).toHaveAttribute("src",/bimini-context\.svg$/);
  expect(observed.errors).toEqual([]);
  expect(observed.mutations).toEqual([]);
});

test("each sample assumption recalculates locally and leaves the separate worksheet unchanged", async ({page}) => {
  const observed = await loadGuide(page);
  const worksheet = await page.locator("#worksheet").innerText();
  await field(page,"speed").fill("10");
  await expectEstimates(page,{time:"10 h 04 min",base:"181.1 US gal",reserve:"36.2 US gal",required:"217.3 US gal",margin:"-27.3 US gal"});
  await field(page,"burn").fill("9");
  await expectEstimates(page,{base:"90.5 US gal",reserve:"18.1 US gal",required:"108.6 US gal",margin:"81.4 US gal"});
  await field(page,"reserve").fill("10");
  await expectEstimates(page,{reserve:"9.1 US gal",required:"99.6 US gal",margin:"90.4 US gal"});
  await field(page,"usable").fill("250");
  await expect(output(page,"margin")).toHaveText("150.4 US gal");
  expect(await page.locator("#worksheet").innerText()).toBe(worksheet);
  expect(observed.requests).toEqual([]);
  expect(observed.mutations).toEqual([]);
  expect(observed.errors).toEqual([]);
});

test("invalid values clear estimates and identify the invalid sample input", async ({page}) => {
  const observed = await loadGuide(page);
  for (const [key, value, restore] of [["speed","0","20"],["speed","","20"],["burn","-1","18"],["reserve","-1","20"],["usable","-1","190"]]) {
    await field(page,key).fill(value);
    await expect(field(page,key)).toHaveAttribute("aria-invalid","true");
    await expect(page.locator("#bhSampleError")).toBeVisible();
    for (const name of ["time","base","reserve","required","margin"]) await expect(output(page,name)).toHaveText("—");
    await field(page,key).fill(restore);
    await expect(field(page,key)).toHaveAttribute("aria-invalid","false");
    await expect(page.locator("#bhSampleError")).toBeHidden();
  }
  await field(page,"burn").fill("0");
  await field(page,"reserve").fill("0");
  await field(page,"usable").fill("0");
  await expectEstimates(page,{base:"0.0 US gal",reserve:"0.0 US gal",required:"0.0 US gal",margin:"0.0 US gal"});
  expect(observed.requests).toEqual([]);
  expect(observed.mutations).toEqual([]);
  expect(observed.errors).toEqual([]);
});

test("sample edits do not persist and a reload restores article defaults", async ({page}) => {
  const observed = await loadGuide(page);
  const storage = await page.evaluate(() => ({local:{...localStorage},session:{...sessionStorage},cookies:document.cookie}));
  await field(page,"speed").fill("7");
  await field(page,"burn").fill("4");
  await field(page,"reserve").fill("30");
  await field(page,"usable").fill("200");
  expect(await page.evaluate(() => ({local:{...localStorage},session:{...sessionStorage},cookies:document.cookie}))).toEqual(storage);
  expect(observed.requests).toEqual([]);
  await page.reload();
  await expect(field(page,"speed")).toHaveValue("20");
  await expect(field(page,"burn")).toHaveValue("18");
  await expect(field(page,"reserve")).toHaveValue("20");
  await expect(field(page,"usable")).toHaveValue("190");
  await expect(output(page,"required")).toHaveText("108.6 US gal");
  expect(observed.mutations).toEqual([]);
  expect(observed.errors).toEqual([]);
});

for (const width of [390,1440]) {
  test("sample controls remain usable inside the dark guide at " + width + "px", async ({page},testInfo) => {
    await page.setViewportSize({width,height:1000});
    const observed = await loadGuide(page);
    await page.locator("#sample-calculator").scrollIntoViewIfNeeded();
    for (const key of ["speed","burn","reserve","usable"]) {
      await expect(field(page,key)).toBeVisible();
      const bounds = await field(page,key).boundingBox();
      expect(bounds.x).toBeGreaterThanOrEqual(0);
      expect(bounds.x+bounds.width).toBeLessThanOrEqual(width);
    }
    expect(await page.evaluate(() => document.documentElement.scrollWidth)).toBeLessThanOrEqual(width);
    await field(page,"speed").focus();
    await page.keyboard.press("Tab");
    await expect(field(page,"burn")).toBeFocused();
    await page.locator("#sample-calculator").screenshot({path:testInfo.outputPath("sample-calculator-"+width+".png")});
    expect(observed.errors).toEqual([]);
    expect(observed.mutations).toEqual([]);
  });
}
